#!/usr/bin/env python3
"""Sons feitos por síntese (sem gravação): os passos do robô e os bipes do drone colega.
Uso: python3 tools/sons_sinteticos.py   (grava em assets/sons/)

Passos: as pisadas gravadas de metal soavam como salto alto (um estalo agudo e seco). Um robô pequeno
pisando no capim é um baque grave e curto, com o zumbido do motor da junta antes e um chiado baixo.
Bipes: frases curtas de assobios e trinados, no espírito dos robozinhos de filme, compostas aqui."""
import math, os, random, struct, wave

TAXA = 44100
PASTA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sons")


def grava(nome, amostras, pico=0.7):
    m = max(1e-6, max(abs(a) for a in amostras))
    with wave.open(os.path.join(PASTA, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, a / m * pico)) * 32767)) for a in amostras))


def passa_baixa(x, corte):
    k = 1.0 - math.exp(-2.0 * math.pi * corte / TAXA)
    y, s = [], 0.0
    for a in x:
        s += (a - s) * k
        y.append(s)
    return y


def passo(rng):
    n = int(TAXA * 0.26)
    som = [0.0] * n
    # o motor da junta: um zumbido curto que sobe, antes de o pé bater
    t0, dur = 0.0, rng.uniform(0.055, 0.075)
    f0, f1 = rng.uniform(230, 290), rng.uniform(380, 470)
    fase = 0.0
    for i in range(int(dur * TAXA)):
        u = i / (dur * TAXA)
        fase += 2 * math.pi * (f0 + (f1 - f0) * u) / TAXA
        serra = (fase / math.pi % 2.0) - 1.0
        som[i] += 0.16 * math.sin(math.pi * u) * (0.6 * math.sin(fase) + 0.4 * serra)
    # o baque: grave, cai de tom e some depressa
    ini = int(dur * TAXA * 0.85)
    fb = rng.uniform(78, 96)
    fase = 0.0
    for i in range(n - ini):
        t = i / TAXA
        fase += 2 * math.pi * (fb * (0.55 + 0.45 * math.exp(-t * 28.0))) / TAXA
        som[ini + i] += 0.95 * math.exp(-t * 26.0) * math.sin(fase)
    # o corpo de metal: um toque abafado, bem mais baixo que o baque
    fm = rng.uniform(310, 380)
    for i in range(n - ini):
        t = i / TAXA
        som[ini + i] += 0.14 * math.exp(-t * 45.0) * math.sin(2 * math.pi * fm * t)
    # o capim: chiado curto e escuro
    ruido = passa_baixa([rng.uniform(-1, 1) for _ in range(n - ini)], 1400.0)
    for i in range(n - ini):
        t = i / TAXA
        som[ini + i] += 0.22 * math.exp(-t * 30.0) * ruido[i]
    return passa_baixa(som, 3200.0)


def bipes(rng, notas):
    som = []
    for _ in range(notas):
        tipo = rng.choice(["nota", "sobe", "desce", "trinado", "sobe", "nota"])
        dur = rng.uniform(0.05, 0.15)
        f0 = rng.choice([620, 780, 930, 1170, 1400, 1760, 2090, 2630])
        f1 = f0
        if tipo == "sobe":
            f1 = f0 * rng.uniform(1.4, 2.2)
        elif tipo == "desce":
            f1 = f0 / rng.uniform(1.4, 2.0)
        n = int(dur * TAXA)
        fase = 0.0
        for i in range(n):
            u = i / n
            f = f0 + (f1 - f0) * u
            if tipo == "trinado":
                f *= 1.0 + 0.16 * (1.0 if math.sin(2 * math.pi * 38.0 * i / TAXA) > 0 else -1.0)
            fase += 2 * math.pi * f / TAXA
            env = min(1.0, u * 14.0) * min(1.0, (1.0 - u) * 10.0)
            som.append(env * (0.82 * math.sin(fase) + 0.18 * math.sin(2.0 * fase)))
        som += [0.0] * int(rng.uniform(0.012, 0.05) * TAXA)
    return som + [0.0] * int(0.03 * TAXA)


def obturador(rng):
    """A foto do álbum (1.1): o clique duplo da cortina de uma câmera pequena e um zumbido curto de avanço."""
    n = int(TAXA * 0.32)
    som = [0.0] * n
    for t0, forca, corte in ((0.0, 1.0, 5200), (0.055, 0.7, 3800)):
        ruido = [rng.uniform(-1, 1) for _ in range(int(TAXA * 0.03))]
        ruido = passa_baixa(ruido, corte)
        for i, a in enumerate(ruido):
            env = math.exp(-i / (TAXA * 0.004))
            som[int(t0 * TAXA) + i] += a * env * forca
        # a batida seca da lâmina
        for i in range(int(TAXA * 0.012)):
            som[int(t0 * TAXA) + i] += math.sin(2 * math.pi * 1900 * i / TAXA) * math.exp(-i / (TAXA * 0.002)) * 0.4 * forca
    # o motorzinho que avança: um zumbido baixo que sobe e some
    t0, dur = 0.1, 0.17
    fase = 0.0
    for i in range(int(dur * TAXA)):
        u = i / (dur * TAXA)
        fase += 2 * math.pi * (180 + 120 * u) / TAXA
        env = math.sin(math.pi * u) ** 1.5
        som[int(t0 * TAXA) + i] += (math.sin(fase) + 0.4 * math.sin(3 * fase)) * env * 0.12
    return som


if __name__ == "__main__":
    import sys
    if "foto" in sys.argv[1:]:
        grava("foto", obturador(random.Random(7)), 0.55)
        sys.exit(0)
    rng = random.Random(41)
    for k in range(1, 7):
        grava("passo_%d" % k, passo(rng), 0.6)
    for k, notas in enumerate([4, 6, 3, 7, 5, 2], 1):
        grava("drone_%d" % k, bipes(random.Random(100 + k), notas), 0.5)
    print("sons sintéticos gravados em", PASTA)
