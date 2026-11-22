#!/usr/bin/env python3
"""Sons de debaixo d'água, feitos por síntese (sem gravação), 2026-11-22.
Uso: /usr/bin/python3 tools/sons_agua.py   (grava em assets/sons/; precisa de numpy)

O usuário notou que, mergulhado, ainda se ouviam os grilos e os pássaros da mata. Debaixo d'água o SomAmbiente
abafa a natureza e toca estes:
  - agua_fundo_loop: o ambiente contínuo. Um ronco grave e abafado que respira devagar, um chiado leve de água
    e umas bolhinhas longe. Estéreo, 22.050 Hz, 24 s. O ruído é filtrado no domínio da frequência (FFT do
    laço inteiro), então já sai periódico; as ondulações de volume dão um número inteiro de voltas no laço e
    as bolhas que passam do fim voltam pelo começo. Por isso o laço emenda sem estalo.
  - bolhas_1 a bolhas_4: punhados de bolhas que sobem, tocados de vez em quando por cima do ambiente.
  - mergulho: o "splash" abafado da entrada na água: um baque grave, a espuma de bolhas e um chiado que some.

Uma bolha é um seno curto cuja frequência sobe enquanto some (a bolha encolhe ao subir); bolha menor, tom mais
agudo e vida mais curta."""
import os
import wave

import numpy as np

SR = 22050
PASTA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sons")
rng = np.random.default_rng(2611)


def grava(nome, som, pico_db=-1.0, rms_db=None):
    """Mono (1D) ou estéreo (2 x n). Com `rms_db`, leva o RMS a esse valor; senão leva o pico a `pico_db`."""
    s = np.atleast_2d(np.asarray(som, dtype=np.float64))
    if rms_db is not None:
        s = s * (10 ** (rms_db / 20) / max(1e-12, np.sqrt(np.mean(s ** 2))))
    else:
        s = s * (10 ** (pico_db / 20) / max(1e-12, np.max(np.abs(s))))
    p = np.max(np.abs(s))
    if p > 0.95:  # nunca corta a seco
        s = s * (0.95 / p)
    with wave.open(os.path.join(PASTA, nome + ".wav"), "wb") as w:
        w.setnchannels(s.shape[0])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((s.T * 32767).astype("<i2").tobytes())
    rms = 20 * np.log10(np.sqrt(np.mean(s ** 2)) + 1e-12)
    print("ok %-18s %.2f s  %d canal(is)  rms %.1f dB  pico %.1f dB" % (nome + ".wav", s.shape[1] / SR, s.shape[0], rms,
                                                                       20 * np.log10(np.max(np.abs(s)) + 1e-12)))
    return s


def ruido_moldado(n, forma):
    """Ruído branco de n amostras com o espectro multiplicado por forma(f) (f em Hz). Sai periódico em n."""
    espectro = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    x = np.fft.irfft(espectro * forma(f), n)
    return x / max(1e-12, np.std(x))


def passa_baixa(x, hz):
    """Passa-baixa de um polo, para dar corpo a sons curtos (não usar nos laços: não é circular)."""
    a = 1.0 - np.exp(-2 * np.pi * hz / SR)
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s += a * (v - s)
        y[i] = s
    return y


def bolha(f0, forca, sobe=None, vida=None):
    """Uma bolha: seno curto que sobe de tom e some. f0 em Hz; vida é a constante de queda, em s."""
    if vida is None:
        vida = float(np.clip(0.014 * (600.0 / f0) ** 0.8, 0.004, 0.04))
    if sobe is None:
        sobe = rng.uniform(0.6, 1.4)
    n = int(vida * 7 * SR)
    t = np.arange(n) / SR
    f = f0 * (1.0 + sobe * t / (vida * 7))
    fase = 2 * np.pi * np.cumsum(f) / SR
    # ataque de 2,5 ms em curva de seno: começando a seco, cada bolha estalava (risca de alto a baixo no espectro)
    ataque = 0.0025
    env = np.exp(-t / vida) * np.where(t < ataque, np.sin(0.5 * np.pi * np.minimum(t / ataque, 1.0)) ** 2, 1.0)
    return forca * np.sin(fase) * env


def passa_alta(x, hz):
    return x - passa_baixa(x, hz)


def somar(alvo, quando, onda, ganho_e=1.0, ganho_d=1.0, circular=False):
    """Soma `onda` em `alvo` (2 x n) a partir de `quando` (s). Circular: o que passa do fim volta ao começo."""
    n = alvo.shape[1]
    i0 = int(quando * SR)
    idx = i0 + np.arange(len(onda))
    if circular:
        idx %= n
    else:
        ok = idx < n
        idx, onda = idx[ok], onda[ok]
    np.add.at(alvo[0], idx, onda * ganho_e)
    np.add.at(alvo[1], idx, onda * ganho_d)


def pan(p):
    """-1 esquerda, 1 direita: ganhos de potência constante."""
    a = (p + 1) * np.pi / 4
    return np.cos(a), np.sin(a)


def punhado(alvo, quando, quantas, espalha, f_min, f_max, forca, circular=False):
    """Algumas bolhas juntas, cada uma num tom e num lado."""
    lado = rng.uniform(-0.6, 0.6)
    for _ in range(quantas):
        t = quando + rng.uniform(0, espalha) ** 1.3
        f0 = np.exp(rng.uniform(np.log(f_min), np.log(f_max)))
        e, d = pan(float(np.clip(lado + rng.uniform(-0.25, 0.25), -1, 1)))
        somar(alvo, t, bolha(f0, forca * rng.uniform(0.45, 1.0)), e, d, circular)


# ---------------------------------------------------------------- ambiente de fundo (laço)

def agua_fundo():
    dura = 24.0
    n = int(dura * SR)
    t = np.arange(n) / SR
    voltas = lambda k: 2 * np.pi * k * t / dura  # noqa: E731  (k voltas inteiras no laço: emenda sem degrau)

    # o ronco: ruído com o peso entre 50 e 250 Hz, um calombo perto de 90 Hz e quase nada acima de 500 Hz
    def forma_ronco(f):
        corpo = 1.0 / (1.0 + (f / 210.0) ** 4)
        sub = (f / (f + 28.0)) ** 3  # corta o que é grave demais para ouvir
        calombo = 1.0 + 1.6 * np.exp(-((f - 90.0) / 35.0) ** 2)
        return corpo * sub * calombo

    meio = ruido_moldado(n, forma_ronco)
    lados = [ruido_moldado(n, forma_ronco) for _ in range(2)]
    respira = 1.0 + 0.22 * np.sin(voltas(3) + 0.4) + 0.12 * np.sin(voltas(7) + 2.1)  # a pressão que vai e volta
    ronco = [(0.8 * meio + 0.45 * lados[c]) * respira for c in range(2)]

    # o zumbido de fundo: dois graves bem baixos que batem devagar (frequências com voltas inteiras no laço)
    zum = 0.18 * np.sin(2 * np.pi * (1320 / dura) * t) + 0.12 * np.sin(2 * np.pi * (1322 / dura) * t + 1.0) \
        + 0.07 * np.sin(2 * np.pi * (1983 / dura) * t + 0.3)

    # o chiado da água: ruído entre 400 Hz e 2,5 kHz, baixo, que respira em outro ritmo
    def forma_chiado(f):
        return np.exp(-((np.log(np.maximum(f, 1.0)) - np.log(1000.0)) / 0.75) ** 2)

    chiado_d = 1.0 + 0.35 * np.sin(voltas(5) + 1.3)
    chiado_e = 1.0 + 0.35 * np.sin(voltas(5) + 2.4)
    chiado = [ruido_moldado(n, forma_chiado) * 0.11 * chiado_e, ruido_moldado(n, forma_chiado) * 0.11 * chiado_d]

    som = np.zeros((2, n))
    for c in range(2):
        som[c] = ronco[c] + zum + chiado[c]
    # umas bolhinhas longe, espalhadas; as do fim dão a volta e caem no começo
    base = np.sqrt(np.mean(som ** 2))
    for k in range(11):
        quando = (k + rng.uniform(0.1, 0.9)) * dura / 11
        punhado(som, quando, int(rng.integers(2, 6)), 0.5, 380.0, 1300.0, base * 0.55, circular=True)
    return som


# ---------------------------------------------------------------- bolhas soltas

def bolhas(qual):
    dura = 1.2
    n = int(dura * SR)
    som = np.zeros((2, n))
    cfg = [(5, 0.35, 420.0, 1100.0), (8, 0.6, 350.0, 1250.0), (3, 0.2, 280.0, 700.0), (11, 0.8, 450.0, 1400.0)][qual]
    punhado(som, 0.01, cfg[0], cfg[1], cfg[2], cfg[3], 1.0)
    if qual == 2:  # um bolhão grave no meio
        somar(som, 0.12, bolha(190.0, 1.0, sobe=0.9, vida=0.045), 0.8, 0.6)
    fim = int(np.max(np.nonzero(np.max(np.abs(som), axis=0) > 1e-4)) + 0.05 * SR)
    som = som[:, :min(n, fim)]
    som[:, -int(0.03 * SR):] *= np.linspace(1, 0, int(0.03 * SR))
    # o passa-alta tira o grave que sobra das bolhas curtas (a primeira meia onda é maior que as outras)
    return np.array([passa_baixa(passa_alta(c, 90.0), 2600.0) for c in som])


# ---------------------------------------------------------------- mergulho (entrada na água)

def mergulho():
    dura = 1.9
    n = int(dura * SR)
    t = np.arange(n) / SR
    som = np.zeros((2, n))
    # o rompimento da lâmina: um chiado curto e já escurecido (é o que se ouve de dentro)
    rasgo = rng.standard_normal(n) * np.exp(-t / 0.035) * (1 - np.exp(-t / 0.002))
    rasgo = passa_baixa(passa_baixa(rasgo, 1800.0), 1800.0)
    # o baque: um grave que cai de tom
    fase = 2 * np.pi * np.cumsum(38.0 + 34.0 * np.exp(-t / 0.08)) / SR
    baque = np.sin(fase) * np.exp(-t / 0.16) * (1 - np.exp(-t / 0.004))
    # o corpo do ronco, que entra junto e some
    ronco = passa_baixa(passa_baixa(rng.standard_normal(n), 320.0), 320.0) * np.exp(-t / 0.4) * (1 - np.exp(-t / 0.01))
    ronco /= max(1e-9, np.max(np.abs(ronco)))
    # a espuma: o chiado das bolhas miúdas, que sobe rápido e some em meio segundo
    espuma = passa_baixa(rng.standard_normal(n), 1500.0) - passa_baixa(rng.standard_normal(n), 300.0) * 0.5
    espuma = espuma * np.exp(-t / 0.32) * (1 - np.exp(-t / 0.03))
    espuma /= max(1e-9, np.max(np.abs(espuma)))
    for c in range(2):
        som[c] += 0.55 * rasgo / max(1e-9, np.max(np.abs(rasgo))) + 0.9 * baque + 0.5 * ronco + 0.35 * espuma
    # as bolhas: muitas logo depois da batida, cada vez mais raras
    for _ in range(46):
        quando = 0.02 + min(1.4, rng.exponential(0.22))
        f0 = np.exp(rng.uniform(np.log(260.0), np.log(1150.0)))
        e, d = pan(rng.uniform(-0.7, 0.7))
        somar(som, quando, bolha(f0, 0.42 * np.exp(-quando / 0.5) * rng.uniform(0.5, 1.0)), e, d)
    for quando, f0 in ((0.05, 170.0), (0.11, 230.0), (0.2, 205.0)):  # bolhões do ar que entrou com o robô
        somar(som, quando, bolha(f0, 0.5, sobe=0.8, vida=0.05), 0.7, 0.7)
    som = np.array([passa_baixa(passa_alta(c, 25.0), 2400.0) for c in som])
    k = int(0.35 * SR)
    som[:, -k:] *= np.linspace(1, 0, k) ** 2
    return som


if __name__ == "__main__":
    grava("agua_fundo_loop", agua_fundo(), rms_db=-20.0)
    for i in range(4):
        grava("bolhas_%d" % (i + 1), bolhas(i), pico_db=-3.0)
    grava("mergulho", mergulho(), pico_db=-1.0)
