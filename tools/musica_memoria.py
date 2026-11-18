# A música das memórias (2026-11-18): um tema lento e leve, feito por síntese, que volta ao começo sem emenda.
#   /usr/bin/python3 tools/musica_memoria.py  ->  assets/sons/memoria_loop.wav (mono, 22.050 Hz, 16 bits, 38,4 s)
import os
import wave

import numpy as np

SR = 22050
BATIDA = 1.2  # segundos por tempo (50 por minuto)
COMPASSOS = [("D", [62, 66, 69, 74]), ("Bm", [59, 62, 66, 71]), ("G", [55, 59, 62, 67]), ("A", [57, 61, 64, 69]),
             ("D", [62, 66, 69, 74]), ("F#m", [54, 61, 66, 69]), ("G", [55, 59, 62, 67]), ("A", [57, 64, 69, 73])]
DUR = len(COMPASSOS) * 4 * BATIDA
N = int(DUR * SR)
som = np.zeros(N)


def hz(nota):
    return 440.0 * 2 ** ((nota - 69) / 12.0)


def tocar(nota, quando, dura, forca, brilho=0.25):
    """Uma nota de sino macio: ataque curto, cauda longa. Dá a volta no fim do arquivo (o laço não estala)."""
    n = int(dura * SR)
    t = np.arange(n) / SR
    f = hz(nota)
    env = (1 - np.exp(-t / 0.02)) * np.exp(-t / (dura * 0.32))
    onda = np.sin(2 * np.pi * f * t) + brilho * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.5) + 0.08 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / 0.25)
    i0 = int(quando * SR)
    idx = (i0 + np.arange(n)) % N
    np.add.at(som, idx, onda * env * forca)


def tapete(notas, quando, dura, forca):
    """O acorde de fundo: senos puros que entram e saem devagar."""
    n = int(dura * SR)
    t = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(t / dura, 0, 1)) ** 1.5
    i0 = int(quando * SR)
    idx = (i0 + np.arange(n)) % N
    for nota in notas:
        f = hz(nota - 12)
        np.add.at(som, idx, (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 1.003 * t)) * env * forca)


rng = np.random.default_rng(11)
for c, (_, notas) in enumerate(COMPASSOS):
    t0 = c * 4 * BATIDA
    tapete(notas[:3], t0 - 0.6, 4 * BATIDA + 1.6, 0.05)
    # arpejo: sobe devagar, com um respiro no quarto tempo
    ordem = [0, 2, 1, 3, 2, 1] if c % 2 == 0 else [0, 1, 2, 3, 1, 2]
    for k, i in enumerate(ordem):
        tocar(notas[i], t0 + k * BATIDA * 0.5 + rng.uniform(-0.012, 0.012), 3.4, 0.2 * (1.0 if k == 0 else 0.72))
    # a melodia: uma nota longa por compasso, uma oitava acima, e às vezes uma segunda
    tocar(notas[3] + (12 if c in (1, 5) else 0), t0 + BATIDA * 2.0, 5.0, 0.16, 0.12)
    if c in (3, 7):
        tocar(notas[2] + 12, t0 + BATIDA * 3.0, 4.0, 0.12, 0.12)

som /= np.abs(som).max() * 1.25
os.makedirs("assets/sons", exist_ok=True)
with wave.open("assets/sons/memoria_loop.wav", "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((som * 32767).astype(np.int16).tobytes())
print("ok: %.1f s" % DUR)
