"""Gera os sons da armadura por síntese (só biblioteca padrão do Python 3).

Uso (da pasta do projeto):  python3 tools/gerar_sons.py
Saída: assets/sons/*.wav (mono, 44,1 kHz, 16 bits, pico em -3 dB).

Os laços (vento, motor, arrancada, cachoeira) saem com crossfade: o fim se funde no começo,
então o laço fecha sem emenda audível. Tom adulto, de ficção científica: nada de fofo.
Para ajustar um som, mude a função dele e rode de novo.
"""

import math
import os
import random
import struct
import wave

SR = 44100
PASTA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sons")
PICO_DB = -3.0
TAU = 2.0 * math.pi


# --- blocos básicos ---------------------------------------------------------

def amostras(seg):
    return int(round(SR * seg))


def ruido(n, semente):
    r = random.Random(semente)
    return [r.uniform(-1.0, 1.0) for _ in range(n)]


def passa_baixa(sinal, corte):
    """Filtro de um polo (6 dB por oitava). Passe duas vezes para cair mais rápido."""
    rc = 1.0 / (TAU * corte)
    a = (1.0 / SR) / (rc + 1.0 / SR)
    y = 0.0
    out = []
    for x in sinal:
        y += a * (x - y)
        out.append(y)
    return out


def passa_baixa_varre(sinal, corte0, corte1):
    """Passa-baixa cujo corte vai de corte0 a corte1 Hz ao longo do sinal."""
    out = []
    y = 0.0
    n = max(len(sinal) - 1, 1)
    for i, x in enumerate(sinal):
        c = corte0 + (corte1 - corte0) * i / n
        rc = 1.0 / (TAU * c)
        a = (1.0 / SR) / (rc + 1.0 / SR)
        y += a * (x - y)
        out.append(y)
    return out


def passa_alta(sinal, corte):
    baixo = passa_baixa(sinal, corte)
    return [x - b for x, b in zip(sinal, baixo)]


def tom(n, f0, f1, pesos):
    """Tom com harmônicos; a frequência vai de f0 a f1 em linha reta. pesos[k] é o harmônico k+1."""
    out = [0.0] * n
    fase = 0.0
    den = max(n - 1, 1)
    for i in range(n):
        fase += (f0 + (f1 - f0) * i / den) / SR
        s = 0.0
        for k, w in enumerate(pesos, 1):
            s += w * math.sin(TAU * k * fase)
        out[i] = s
    return out


def envelope(n, ataque, queda):
    """Sobe linear no ataque (segundos) e cai exponencial com a constante `queda` (segundos)."""
    a = max(amostras(ataque), 1)
    out = []
    for i in range(n):
        t = i / SR
        out.append(i / a if i < a else math.exp(-(t - ataque) / queda))
    return out


def rampa(n, fim_do_ataque=0.1):
    """Sobe de 0 a 1 em fim_do_ataque segundos e fica em 1."""
    a = max(amostras(fim_do_ataque), 1)
    return [min(1.0, i / a) for i in range(n)]


def porta(n, trechos, fade=0.004):
    """Liga o sinal só nos trechos (início, fim) em segundos, com pequenas rampas nas bordas."""
    g = [0.0] * n
    f = amostras(fade)
    for ini, fim in trechos:
        a = amostras(ini)
        b = min(n, amostras(fim))
        for i in range(a, b):
            g[i] = max(0.0, min(1.0, (i - a) / f, (b - 1 - i) / f))
    return g


def mult(sinal, ganho):
    return [x * g for x, g in zip(sinal, ganho)]


def unitario(sinal):
    """Escala para pico 1 (para misturar camadas com pesos previsíveis)."""
    pico = max((abs(x) for x in sinal), default=0.0) or 1.0
    return [x / pico for x in sinal]


def soma(*partes):
    """partes: (sinal, ganho). Todos com o mesmo tamanho."""
    n = len(partes[0][0])
    out = [0.0] * n
    for sinal, g in partes:
        for i in range(n):
            out[i] += sinal[i] * g
    return out


def coloca(total, sinal, inicio, ganho=1.0):
    """Soma `sinal` dentro de `total` a partir de `inicio` segundos."""
    s = amostras(inicio)
    for i, x in enumerate(sinal):
        j = s + i
        if j < len(total):
            total[j] += x * ganho
    return total


def laco(sinal_extra, dur, cruzamento=0.25):
    """Recebe dur + cruzamento segundos e devolve dur segundos que emendam.

    O começo (equal-power) se funde com a cauda que passou do fim, então o último quadro
    cai no primeiro sem salto.
    """
    L = amostras(dur)
    X = amostras(cruzamento)
    out = list(sinal_extra[:L])
    for i in range(X):
        g_ini = math.sin(0.5 * math.pi * i / X)
        g_fim = math.cos(0.5 * math.pi * i / X)
        out[i] = sinal_extra[i] * g_ini + sinal_extra[i + L] * g_fim
    return out


def normaliza(sinal, pico_db=PICO_DB):
    pico = max((abs(x) for x in sinal), default=0.0)
    if pico == 0:
        return sinal
    alvo = 10 ** (pico_db / 20.0)
    return [x * alvo / pico for x in sinal]


def grava(nome, sinal, laco_=False, pico_db=PICO_DB):
    if not laco_:
        # Bordas com 4 ms de rampa evitam estalo no início e no fim do toque.
        f = min(amostras(0.004), len(sinal) // 2)
        sinal = list(sinal)
        for i in range(f):
            sinal[i] *= i / f
            sinal[-1 - i] *= i / f
    sinal = normaliza(sinal, pico_db)
    os.makedirs(PASTA, exist_ok=True)
    caminho = os.path.join(PASTA, nome + ".wav")
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in sinal))
    print(f"{nome + '.wav':24s} {len(sinal) / SR:5.2f} s")


# --- laços -------------------------------------------------------------------

def vento():
    dur = 4.0
    n = amostras(dur + 0.25)
    r = ruido(n, 11)
    corpo = passa_alta(passa_baixa(passa_baixa(r, 900), 900), 120)
    # Rajadas lentas: ciclos inteiros em 4 s, então o laço fecha certinho.
    rajada = [0.62 + 0.25 * math.sin(TAU * 0.25 * i / SR) + 0.13 * math.sin(TAU * 0.5 * i / SR + 1.0)
              for i in range(n)]
    grava("vento_loop", laco(mult(corpo, rajada), dur), True)


def motor():
    dur = 3.0
    n = amostras(dur + 0.25)
    # Base de 55 Hz (165 ciclos em 3 s) com harmônicos caindo devagar.
    turbina = tom(n, 55.0, 55.0, [1.0 / k ** 1.1 for k in range(1, 9)])
    chiado = passa_baixa(passa_baixa(ruido(n, 12), 380), 380)
    pulso = [0.85 + 0.15 * math.sin(TAU * 6.0 * i / SR) for i in range(n)]  # 18 ciclos em 3 s
    mistura = soma((unitario(turbina), 1.0), (unitario(chiado), 0.35))
    grava("motor_loop", laco(mult(mistura, pulso), dur), True)


def arrancada():
    dur = 3.0
    n = amostras(dur + 0.25)
    # Mais aguda e rasgada: harmônicos até o 12º e um chiado mais agudo.
    rasgo = tom(n, 165.0, 165.0, [1.0 / k ** 0.8 for k in range(1, 13)])
    chiado = passa_alta(passa_baixa(passa_baixa(ruido(n, 13), 3200), 3200), 1100)
    tremor = [0.8 + 0.2 * math.sin(TAU * 8.0 * i / SR) for i in range(n)]  # 24 ciclos em 3 s
    mistura = soma((unitario(rasgo), 1.0), (unitario(chiado), 0.45))
    grava("arrancada_loop", laco(mult(mistura, tremor), dur), True)


def cachoeira():
    dur = 4.0
    n = amostras(dur + 0.25)
    corpo = passa_baixa(passa_baixa(ruido(n, 14), 1800), 1800)
    grave = passa_baixa(passa_baixa(ruido(n, 15), 180), 180)
    oscila = [0.88 + 0.12 * math.sin(TAU * 1.0 * i / SR) for i in range(n)]  # 4 ciclos em 4 s
    mistura = soma((unitario(corpo), 0.7), (unitario(grave), 1.0))
    grava("cachoeira_loop", laco(mult(mistura, oscila), dur), True)


# --- toques -------------------------------------------------------------------

def decolagem():
    n = amostras(1.2)
    estouro = passa_baixa(mult(ruido(n, 21), envelope(n, 0.001, 0.035)), 2600)
    subida_env = [min(1.0, i / amostras(0.1)) * (1.0 - 0.3 * i / n) for i in range(n)]
    subida = mult(tom(n, 90.0, 260.0, [1.0 / k ** 1.3 for k in range(1, 7)]), subida_env)
    sopro = mult(passa_baixa_varre(ruido(n, 22), 500.0, 2400.0), subida_env)
    grava("decolagem", soma((unitario(estouro), 0.9), (unitario(subida), 0.8), (unitario(sopro), 0.35)))


def pulo_duplo():
    n = amostras(0.3)
    sopro = mult(passa_baixa_varre(ruido(n, 31), 500.0, 2600.0), envelope(n, 0.02, 0.07))
    tom_ = mult(tom(n, 320.0, 520.0, [1.0, 0.3]), envelope(n, 0.01, 0.1))
    grava("pulo_duplo", soma((unitario(sopro), 1.0), (unitario(tom_), 0.35)))


def esquiva():
    n = amostras(0.3)
    varredura = passa_alta(passa_baixa_varre(ruido(n, 32), 300.0, 1800.0), 200.0)
    grava("esquiva", mult(unitario(varredura), envelope(n, 0.03, 0.12)))


def pouso_leve():
    n = amostras(0.4)
    baque = mult(tom(n, 110.0, 60.0, [1.0, 0.5]), envelope(n, 0.003, 0.08))
    poeira = mult(passa_baixa(passa_baixa(ruido(n, 41), 400), 400), envelope(n, 0.001, 0.02))
    grava("pouso_leve", soma((unitario(baque), 1.0), (unitario(poeira), 0.5)))


def pouso_pesado():
    n = amostras(0.6)
    baque = mult(tom(n, 70.0, 30.0, [1.0, 0.6, 0.3]), envelope(n, 0.005, 0.22))
    impacto = mult(passa_baixa(passa_baixa(ruido(n, 51), 300), 300), envelope(n, 0.002, 0.05))
    grava("pouso_pesado", soma((unitario(baque), 1.0), (unitario(impacto), 0.8)))


def alarme_calor():
    n = amostras(0.5)
    bipe = porta(n, [(0.0, 0.16), (0.22, 0.38)])
    tom_ = tom(n, 960.0, 960.0, [1.0, 0.25, 0.1])
    grava("alarme_calor", mult(unitario(tom_), bipe))


def motor_apaga():
    n = amostras(0.8)
    queda = [1.0 - i / n for i in range(n)]
    turbina = mult(tom(n, 260.0, 45.0, [1.0 / k ** 1.1 for k in range(1, 9)]), queda)
    chiado = mult(passa_baixa_varre(ruido(n, 61), 2000.0, 200.0), queda)
    grava("motor_apaga", soma((unitario(turbina), 1.0), (unitario(chiado), 0.4)))


def religar():
    n = amostras(0.6)
    subida = [(i / n) ** 1.5 for i in range(n)]
    turbina = mult(tom(n, 50.0, 210.0, [1.0 / k ** 1.1 for k in range(1, 9)]), subida)
    chiado = mult(passa_baixa_varre(ruido(n, 71), 300.0, 2500.0), [(i / n) ** 2 for i in range(n)])
    grava("religar", soma((unitario(turbina), 1.0), (unitario(chiado), 0.3)))


def marcar():
    n = amostras(0.12)
    tom_ = mult(tom(n, 1500.0, 1500.0, [1.0, 0.2]), envelope(n, 0.002, 0.03))
    grava("marcar", tom_)


# --- ambiente do vale -------------------------------------------------------
# Mata (dia e noite), chuva, riacho e trovão. Pico em -6 dB; os laços usam o mesmo crossfade.

PICO_AMBIENTE_DB = -6.0


def estalo(f, amp, dur_s, tau_s):
    """Um estalo curto (gota ou borbulha): senoide que cai exponencialmente."""
    m = amostras(dur_s)
    return [amp * math.exp(-i / SR / tau_s) * math.sin(TAU * f * i / SR) for i in range(m)]


def nota_de_pio(f0, f1, dur, vibrato, fundo, pesos=(1.0, 0.2)):
    """Nota de pássaro: glissando de f0 a f1, com vibrato, e queda rápida."""
    n = amostras(dur)
    out = [0.0] * n
    fase = 0.0
    fim = max(n - 1, 1)
    for i in range(n):
        f = f0 + (f1 - f0) * i / fim
        f *= 1.0 + fundo * math.sin(TAU * vibrato * i / SR)
        fase += f / SR
        s = 0.0
        for k, w in enumerate(pesos, 1):
            s += w * math.sin(TAU * k * fase)
        out[i] = s
    return mult(out, envelope(n, 0.008, dur * 0.25))


def pio_trinado(total, inicio, f_base, rng):
    """Trinado curto: 4 a 6 notas alternando duas alturas, com glissando e vibrato."""
    t = inicio
    for k in range(rng.randint(4, 6)):
        f0 = f_base * (1.0 if k % 2 == 0 else 1.18) * rng.uniform(0.97, 1.03)
        f1 = f0 * rng.uniform(1.02, 1.12)
        dur = rng.uniform(0.045, 0.075)
        coloca(total, nota_de_pio(f0, f1, dur, rng.uniform(22.0, 38.0), 0.015), t, 1.0)
        t += dur + rng.uniform(0.012, 0.03)
    return t


def mata_dia():
    dur = 12.0
    n = amostras(dur + 0.25)
    # Brisa: ruído filtrado, ondulando devagar (ciclos inteiros em 12 s, então o laço fecha bem).
    brisa = passa_alta(passa_baixa(passa_baixa(ruido(n, 201), 900), 900), 150)
    ondula = [0.62 + 0.25 * math.sin(TAU * (4.0 / dur) * i / SR) + 0.13 * math.sin(TAU * (2.0 / dur) * i / SR + 1.0)
              for i in range(n)]
    # Pios esparsos em alturas diferentes, longe das bordas do laço.
    rng = random.Random(202)
    pios = [0.0] * n
    for inicio, f_base in zip([0.8, 2.4, 3.7, 5.5, 7.1, 8.9, 10.5],
                              [2600.0, 3300.0, 2200.0, 3800.0, 2900.0, 3500.0, 2400.0]):
        pio_trinado(pios, inicio, f_base * rng.uniform(0.95, 1.05), rng)
    mistura = soma((mult(unitario(brisa), ondula), 1.0), (unitario(pios), 0.3))
    grava("mata_dia_loop", laco(mistura, dur), True, PICO_AMBIENTE_DB)


def grilo(total, inicio, dur, f, taxa, ganho):
    """Grilo: tom agudo cortado em pulsos rápidos (taxa por segundo), com as pontas suaves."""
    n = amostras(dur)
    a = amostras(0.05)
    out = []
    for i in range(n):
        t = i / SR
        pulso = max(0.0, math.sin(TAU * taxa * t))
        env = min(1.0, i / a, (n - 1 - i) / a)
        out.append(pulso * pulso * math.sin(TAU * f * t) * env)
    return coloca(total, out, inicio, ganho)


def coruja(total, inicio, ganho):
    """Duas notas graves de coruja ("hu-ôôô"), abafadas para soar distantes."""
    buf = [0.0] * amostras(1.6)
    coloca(buf, nota_de_pio(430.0, 415.0, 0.4, 4.0, 0.01, pesos=(1.0, 0.15)), 0.0, 1.0)
    coloca(buf, nota_de_pio(400.0, 372.0, 0.9, 3.5, 0.01, pesos=(1.0, 0.12)), 0.45, 0.85)
    buf = passa_baixa(passa_baixa(buf, 1400.0), 1400.0)
    return coloca(total, unitario(buf), inicio, ganho)


def mata_noite():
    dur = 10.0
    n = amostras(dur + 0.25)
    # Brisa mais grave e baixa, ondulando de leve (3 ciclos em 10 s).
    brisa = passa_alta(passa_baixa(passa_baixa(ruido(n, 301), 520), 520), 80)
    ondula = [0.5 + 0.2 * math.sin(TAU * (3.0 / dur) * i / SR) for i in range(n)]
    # Grilos: pequenos coros de pulsos agudos, em momentos sorteados, sem passar do laço.
    rng = random.Random(302)
    grilos = [0.0] * n
    for _ in range(7):
        d = rng.uniform(0.9, 1.6)
        grilo(grilos, rng.uniform(0.2, 9.6 - d), d, rng.uniform(4000.0, 5000.0), rng.uniform(22.0, 34.0), 1.0)
    # Coruja distante, duas vezes.
    corujas = [0.0] * n
    coruja(corujas, 3.0, 1.0)
    coruja(corujas, 7.4, 0.7)
    mistura = soma((mult(unitario(brisa), ondula), 1.0), (unitario(grilos), 0.22), (unitario(corujas), 0.35))
    grava("mata_noite_loop", laco(mistura, dur), True, PICO_AMBIENTE_DB)


def riacho():
    dur = 6.0
    n = amostras(dur + 0.25)
    # Água corrente: ruído em banda média; a força oscila em 3 ciclos por laço.
    corpo = passa_alta(passa_baixa(passa_baixa(ruido(n, 401), 2600), 2600), 350)
    forca = [0.85 + 0.15 * math.sin(TAU * (3.0 / dur) * i / SR) for i in range(n)]
    # Borbulhas: estalos curtos de subida suave, espalhados.
    rng = random.Random(402)
    bolhas = [0.0] * n
    for _ in range(60):
        f = rng.uniform(1400.0, 3200.0)
        coloca(bolhas, estalo(f, rng.uniform(0.2, 0.6), 0.03, 0.004), rng.uniform(0.0, dur - 0.05), 1.0)
    mistura = soma((mult(unitario(corpo), forca), 1.0), (unitario(bolhas), 0.25))
    grava("riacho_loop", laco(mistura, dur), True, PICO_AMBIENTE_DB)


def chuva():
    dur = 6.0
    n = amostras(dur + 0.25)
    # Chuva constante: ruído largo, mais forte nos agudos que o riacho.
    corpo = passa_alta(passa_baixa(ruido(n, 501), 7000), 250)
    # Gotas: estalos curtos e claros, sem ritmo.
    rng = random.Random(502)
    gotas = [0.0] * n
    for _ in range(420):
        f = rng.uniform(2500.0, 6000.0)
        coloca(gotas, estalo(f, rng.uniform(0.15, 0.5), 0.012, 0.0015), rng.uniform(0.0, dur - 0.02), 1.0)
    mistura = soma((unitario(corpo), 1.0), (unitario(gotas), 0.3))
    grava("chuva_loop", laco(mistura, dur), True, PICO_AMBIENTE_DB)


def trovao():
    dur = 3.5
    n = amostras(dur)
    ts = [i / SR for i in range(n)]
    # Dois rolos: o primeiro estoura e some; o segundo chega depois, mais baixo.
    rolo = [min(1.0, t / 0.04) * math.exp(-t / 0.9)
            + (0.7 * min(1.0, (t - 1.1) / 0.1) * math.exp(-(t - 1.1) / 0.8) if t > 1.1 else 0.0)
            for t in ts]
    fim = [min(1.0, (n - 1 - i) / amostras(0.3)) for i in range(n)]
    grave = mult(passa_baixa(passa_baixa(passa_baixa(ruido(n, 601), 160), 160), 160), rolo)
    sub = mult(tom(n, 48.0, 36.0, [1.0, 0.4]), [math.exp(-t / 0.8) * min(1.0, t / 0.03) for t in ts])
    mistura = mult(soma((unitario(grave), 1.0), (unitario(sub), 0.5)), fim)
    grava("trovao", mistura, False, PICO_AMBIENTE_DB)


def ambiente():
    mata_dia()
    mata_noite()
    riacho()
    chuva()
    trovao()


def main():
    vento()
    motor()
    arrancada()
    cachoeira()
    decolagem()
    pulo_duplo()
    esquiva()
    pouso_leve()
    pouso_pesado()
    alarme_calor()
    motor_apaga()
    religar()
    marcar()


if __name__ == "__main__":
    main()
    ambiente()
