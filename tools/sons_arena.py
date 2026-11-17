#!/usr/bin/env python3
"""Sons da Fundição e das armas, feitos por síntese (sem gravação).
Uso: python3 tools/sons_arena.py   (grava em assets/sons/)

Lasers: um "piu" que cai de tom, diferente por arma. Explosão: baque grave com ruído que escurece.
Espada: zumbido que varre. E os avisos da arena, das caixas e da roda de armas."""
import math, os, random, struct, wave

TAXA = 44100
PASTA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sons")
rng = random.Random(77)


def grava(nome, amostras, pico=0.7):
    m = max(1e-6, max(abs(a) for a in amostras))
    with wave.open(os.path.join(PASTA, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, a / m * pico)) * 32767)) for a in amostras))


def passa_baixa(x, corte):
    y, s = [], 0.0
    for i, a in enumerate(x):
        c = corte(i / TAXA) if callable(corte) else corte
        s += (a - s) * (1.0 - math.exp(-2.0 * math.pi * c / TAXA))
        y.append(s)
    return y


def tom(dur, freq, env, forma="seno", vibrato=0.0):
    """freq e env são funções do tempo (s)."""
    n = int(dur * TAXA)
    out, fase = [], 0.0
    for i in range(n):
        t = i / TAXA
        f = freq(t) * (1.0 + vibrato * math.sin(2 * math.pi * 30.0 * t))
        fase += 2 * math.pi * f / TAXA
        if forma == "serra":
            v = (fase / math.pi % 2.0) - 1.0
        elif forma == "quadrada":
            v = 1.0 if math.sin(fase) > 0 else -1.0
        else:
            v = math.sin(fase)
        out.append(v * env(t))
    return out


def ruido(dur, env, corte):
    n = int(dur * TAXA)
    return [a * env(i / TAXA) for i, a in enumerate(passa_baixa([rng.uniform(-1, 1) for _ in range(n)], corte))]


def soma(*faixas):
    n = max(len(f) for f in faixas)
    out = [0.0] * n
    for f in faixas:
        for i, a in enumerate(f):
            out[i] += a
    return out


def desloca(faixa, seg):
    return [0.0] * int(seg * TAXA) + faixa


def laser(dur, f0, f1, queda, corpo=0.0, chiado=0.25):
    a = tom(dur, lambda t: f1 + (f0 - f1) * math.exp(-t * queda), lambda t: math.exp(-t * 5.0 / dur) * min(1.0, t * 400.0), "serra")
    b = tom(dur, lambda t: (f1 + (f0 - f1) * math.exp(-t * queda)) * 0.5, lambda t: corpo * math.exp(-t * 4.0 / dur))
    c = ruido(dur * 0.4, lambda t: chiado * math.exp(-t * 30.0), 6000.0)
    return passa_baixa(soma(a, b, c), 7000.0)


def explosao(dur, grave):
    baque = tom(dur, lambda t: grave * (0.45 + 0.55 * math.exp(-t * 9.0)), lambda t: math.exp(-t * 4.5))
    estalo = ruido(0.08, lambda t: 1.1 * math.exp(-t * 60.0), 5000.0)
    corpo = ruido(dur, lambda t: 0.9 * math.exp(-t * 3.2), lambda t: 2400.0 * math.exp(-t * 3.0) + 120.0)
    return soma(baque, estalo, corpo)


def notas(lista, dur, forma="seno", decai=7.0, passo=None):
    passo = passo or dur * 0.8
    faixas = []
    for i, f in enumerate(lista):
        faixas.append(desloca(soma(tom(dur, lambda t, f=f: f, lambda t: math.exp(-t * decai) * min(1.0, t * 300.0), forma),
                                  tom(dur, lambda t, f=f: f * 2.0, lambda t: 0.25 * math.exp(-t * decai * 1.5))), i * passo))
    return soma(*faixas)


# --- armas
grava("laser_pistola", laser(0.2, 1900.0, 520.0, 22.0, 0.35), 0.62)
grava("laser_rajada", laser(0.1, 2600.0, 1100.0, 40.0, 0.1, 0.2), 0.5)
grava("laser_precisao", soma(laser(0.42, 3400.0, 300.0, 16.0, 0.5, 0.4), ruido(0.4, lambda t: 0.2 * math.exp(-t * 7.0), 1200.0)), 0.7)
grava("laser_duplo", laser(0.18, 2200.0, 640.0, 26.0, 0.3), 0.6)
grava("canhao_tiro", soma(laser(0.5, 900.0, 90.0, 9.0, 0.9, 0.5), explosao(0.5, 70.0)), 0.8)
grava("canhao_carga", passa_baixa(tom(1.15, lambda t: 110.0 + 420.0 * (t / 1.15) ** 2, lambda t: 0.25 + 0.75 * (t / 1.15), "serra", 0.03), 2600.0), 0.45)
grava("missil_sai", soma(ruido(0.9, lambda t: math.exp(-t * 2.6) * min(1.0, t * 30.0), lambda t: 700.0 + 3800.0 * min(1.0, t * 2.2)),
                         tom(0.9, lambda t: 140.0 + 260.0 * t, lambda t: 0.5 * math.exp(-t * 3.0), "serra")), 0.6)
grava("granada_sai", soma(tom(0.22, lambda t: 240.0 * math.exp(-t * 14.0) + 60.0, lambda t: math.exp(-t * 16.0)),
                          ruido(0.12, lambda t: 0.5 * math.exp(-t * 40.0), 1800.0)), 0.62)
grava("explosao_1", explosao(1.3, 62.0), 0.85)
grava("explosao_2", explosao(1.1, 78.0), 0.85)
for k, (f0, f1) in enumerate([(210.0, 520.0), (560.0, 230.0)]):
    grava("espada_%d" % (k + 1), soma(
        passa_baixa(tom(0.26, lambda t, f0=f0, f1=f1: f0 + (f1 - f0) * (t / 0.26), lambda t: math.sin(math.pi * t / 0.26) ** 0.7, "serra", 0.05), 2400.0),
        ruido(0.26, lambda t: 0.55 * math.sin(math.pi * t / 0.26) ** 2, lambda t: 900.0 + 5000.0 * math.sin(math.pi * t / 0.26))), 0.6)
grava("trava", tom(0.07, lambda t: 1760.0, lambda t: math.exp(-t * 40.0) * min(1.0, t * 800.0), "quadrada"), 0.3)
grava("sem_municao", soma(ruido(0.05, lambda t: math.exp(-t * 90.0), 3000.0), tom(0.06, lambda t: 180.0, lambda t: 0.6 * math.exp(-t * 60.0))), 0.45)
# --- roda, caixas, nível
grava("roda_abre", tom(0.14, lambda t: 420.0 + 500.0 * t / 0.14, lambda t: math.sin(math.pi * t / 0.14)), 0.3)
grava("roda_troca", soma(tom(0.05, lambda t: 1200.0, lambda t: math.exp(-t * 60.0), "quadrada"), desloca(tom(0.09, lambda t: 1800.0, lambda t: math.exp(-t * 35.0)), 0.05)), 0.35)
grava("caixa_sai", soma(tom(0.3, lambda t: 300.0, lambda t: math.exp(-t * 18.0)), tom(0.3, lambda t: 742.0, lambda t: 0.6 * math.exp(-t * 14.0)),
                        ruido(0.1, lambda t: 0.6 * math.exp(-t * 40.0), 2500.0)), 0.55)
grava("caixa_pega", notas([660.0, 880.0, 1320.0], 0.3, passo=0.07), 0.5)
grava("nivel", notas([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.7, decai=4.0, passo=0.09), 0.6)
grava("fabricou", notas([440.0, 554.0, 659.0], 0.5, decai=5.0, passo=0.08), 0.5)
# --- arena
grava("onda_comeca", soma(tom(0.5, lambda t: 392.0, lambda t: min(1.0, t * 20.0) * (1.0 if t < 0.42 else 0.0), "quadrada"),
                          desloca(tom(0.7, lambda t: 523.0, lambda t: min(1.0, t * 20.0) * math.exp(-t * 2.5), "quadrada"), 0.5)), 0.32)
grava("onda_vencida", notas([523.0, 784.0, 1047.0], 0.9, decai=3.0, passo=0.12), 0.55)
buzina = lambda: passa_baixa(soma(tom(0.55, lambda t: 98.0, lambda t: min(1.0, t * 15.0) * (1.0 if t < 0.45 else math.exp(-(t - 0.45) * 30.0)), "serra"),
                                  tom(0.55, lambda t: 147.0, lambda t: 0.6 * min(1.0, t * 15.0) * (1.0 if t < 0.45 else math.exp(-(t - 0.45) * 30.0)), "serra")), 1500.0)
grava("chefe_aviso", soma(buzina(), desloca(buzina(), 0.75), desloca(buzina(), 1.5)), 0.7)
grava("porta_abre", soma(ruido(1.6, lambda t: 0.7 * math.sin(math.pi * t / 1.6), lambda t: 500.0 + 300.0 * math.sin(t * 9.0)),
                         tom(1.6, lambda t: 62.0 + 10.0 * math.sin(t * 23.0), lambda t: 0.8 * math.sin(math.pi * t / 1.6), "serra"),
                         desloca(explosao(0.5, 55.0), 1.45)), 0.7)
grava("chefe_cai", soma(explosao(1.6, 48.0), desloca(notas([330.0, 262.0, 196.0], 0.6, "serra", 4.0, 0.16), 0.2)), 0.8)
grava("perdeu", notas([392.0, 330.0, 262.0, 196.0], 0.6, "seno", 4.0, 0.16), 0.5)
print("sons da arena gravados em", PASTA)
