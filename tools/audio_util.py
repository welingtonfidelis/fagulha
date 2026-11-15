"""Ferramentas pequenas de áudio só com a biblioteca padrão: ler e gravar WAV de 16 bits, cortar,
fechar laço com crossfade, filtrar, misturar e normalizar. Usado por tools/montar_sons.py.

Um som é uma lista de canais; cada canal é uma lista de floats entre -1 e 1. Taxa fixa de 44,1 kHz.
"""

import array
import math
import struct
import wave

SR = 44100
TAU = 2.0 * math.pi


def ler(caminho):
    """Lê um WAV PCM de 16 bits (mono ou estéreo) e devolve os canais em float."""
    with wave.open(caminho, "rb") as w:
        nc, larg, taxa, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        bruto = w.readframes(n)
    if larg != 2:
        raise ValueError("%s: esperava 16 bits, veio %d" % (caminho, larg * 8))
    a = array.array("h")
    a.frombytes(bruto)
    canais = [[x / 32768.0 for x in a[c::nc]] for c in range(nc)]
    if taxa != SR:
        canais = [reamostrar(c, taxa) for c in canais]
    return canais


def gravar(caminho, canais, pico_db=-3.0, normalizar=True):
    """Grava em 16 bits. Com `normalizar`, o pico vai para `pico_db`."""
    n = min(len(c) for c in canais)
    if normalizar:
        p = max(max(abs(x) for x in c[:n]) for c in canais) or 1.0
        g = (10.0 ** (pico_db / 20.0)) / p
    else:
        g = 1.0
    a = array.array("h", bytes(2 * n * len(canais)))
    for i, c in enumerate(canais):
        a[i::len(canais)] = array.array("h", [max(-32768, min(32767, int(x * g * 32767.0))) for x in c[:n]])
    with wave.open(caminho, "wb") as w:
        w.setnchannels(len(canais))
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(a.tobytes())
    return n / SR


def reamostrar(canal, taxa):
    """Reamostragem linear para SR."""
    passo = taxa / SR
    n = int(len(canal) / passo) - 1
    out = []
    for i in range(max(n, 0)):
        p = i * passo
        k = int(p)
        f = p - k
        out.append(canal[k] * (1.0 - f) + canal[k + 1] * f)
    return out


def mono(canais):
    if len(canais) == 1:
        return [canais[0]]
    n = min(len(c) for c in canais)
    return [[(canais[0][i] + canais[1][i]) * 0.5 for i in range(n)]]


def estereo(canais):
    return canais if len(canais) == 2 else [canais[0], list(canais[0])]


def corte(canais, ini, fim=None):
    a = int(ini * SR)
    b = None if fim is None else int(fim * SR)
    return [c[a:b] for c in canais]


def duracao(canais):
    return len(canais[0]) / SR


def ganho(canais, db):
    g = 10.0 ** (db / 20.0)
    return [[x * g for x in c] for c in canais]


def rms_db(canais, ini=0.0, fim=None):
    c = corte(canais, ini, fim)
    s = 0.0
    n = 0
    for ch in c:
        for x in ch:
            s += x * x
        n += len(ch)
    return 10.0 * math.log10(s / n + 1e-12) if n else -120.0


def pico_db(canais):
    p = max(max(abs(x) for x in c) for c in canais if c)
    return 20.0 * math.log10(p + 1e-9)


def perfil(canais, janela=1.0):
    """RMS em dB por janela, para ver onde o som é estável ou onde tem um estalo."""
    m = mono(canais)[0]
    passo = int(janela * SR)
    out = []
    for i in range(0, len(m) - passo + 1, passo):
        s = sum(x * x for x in m[i:i + passo]) / passo
        out.append(10.0 * math.log10(s + 1e-12))
    return out


def fade(canais, entrada=0.0, saida=0.0):
    ne, ns = int(entrada * SR), int(saida * SR)
    out = []
    for c in canais:
        c = list(c)
        n = len(c)
        for i in range(min(ne, n)):
            c[i] *= i / ne
        for i in range(min(ns, n)):
            c[n - 1 - i] *= i / ns
        out.append(c)
    return out


def laco(canais, cruza=1.0):
    """Fecha o laço: os últimos `cruza` segundos se fundem no começo (potência constante).
    O resultado fica `cruza` segundos mais curto."""
    k = int(cruza * SR)
    out = []
    for c in canais:
        n = len(c)
        if n < 3 * k:
            raise ValueError("som curto demais para cruzar %.2f s" % cruza)
        corpo = list(c[:n - k])
        cauda = c[n - k:]
        for i in range(k):
            t = i / k
            corpo[i] = corpo[i] * math.sin(t * math.pi * 0.5) + cauda[i] * math.cos(t * math.pi * 0.5)
        out.append(corpo)
    return out


def passa_baixa(canais, hz, vezes=1):
    a = 1.0 - math.exp(-TAU * hz / SR)
    out = []
    for c in canais:
        for _ in range(vezes):
            y = 0.0
            novo = []
            for x in c:
                y += a * (x - y)
                novo.append(y)
            c = novo
        out.append(c)
    return out


def passa_alta(canais, hz, vezes=1):
    baixo = passa_baixa(canais, hz, vezes)
    return [[x - b for x, b in zip(c, lb)] for c, lb in zip(canais, baixo)]


def mistura(*partes):
    """Soma sons (canais, dB, atraso em segundos). Tudo vira estéreo se algum for estéreo."""
    st = any(len(p[0]) == 2 for p in partes)
    nc = 2 if st else 1
    fim = max(int(p[2] * SR) + len(p[0][0]) for p in partes)
    out = [[0.0] * fim for _ in range(nc)]
    for canais, db, atraso in partes:
        g = 10.0 ** (db / 20.0)
        src = estereo(canais) if st else mono(canais)
        o = int(atraso * SR)
        for ch in range(nc):
            d = out[ch]
            for i, x in enumerate(src[ch]):
                d[o + i] += x * g
    return out


def tom(canais, fator):
    """Muda o tom e a duração juntos (fator 2 = uma oitava acima, metade do tempo)."""
    out = []
    for c in canais:
        n = int((len(c) - 1) / fator)
        novo = []
        for i in range(n):
            p = i * fator
            k = int(p)
            f = p - k
            novo.append(c[k] * (1.0 - f) + c[k + 1] * f)
        out.append(novo)
    return out


def aparar(canais, limiar_db=-45.0, folga=0.01):
    """Tira o silêncio do começo e do fim."""
    m = mono(canais)[0]
    lim = 10.0 ** (limiar_db / 20.0)
    a = 0
    while a < len(m) and abs(m[a]) < lim:
        a += 1
    b = len(m) - 1
    while b > a and abs(m[b]) < lim:
        b -= 1
    f = int(folga * SR)
    a = max(0, a - f)
    b = min(len(m), b + f)
    return [c[a:b] for c in canais]


def nivelar(canais, alvo_db):
    """Leva o RMS para `alvo_db`. Os picos que passariam de -1 dB são arredondados (não cortados
    a seco), para um estalo isolado não segurar o volume do som inteiro."""
    out = ganho(canais, alvo_db - rms_db(canais))
    if pico_db(out) <= -1.0:
        return out
    joelho, teto = 0.6, 0.89
    sobra = teto - joelho
    res = []
    for c in out:
        novo = []
        for x in c:
            a = abs(x)
            if a > joelho:
                a = joelho + sobra * math.tanh((a - joelho) / sobra)
                x = a if x > 0 else -a
            novo.append(x)
        res.append(novo)
    return res
