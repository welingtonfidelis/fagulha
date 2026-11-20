# As músicas do passeio (2026-11-19): três temas curtos e leves, feitos por síntese, que tocam de vez em quando
# (ao chegar a um lugar novo, ao amanhecer e num voo alto). Não são laços: começam, dizem o que têm e somem.
#   /usr/bin/python3 tools/musica_passeio.py  ->  assets/sons/musica_{lugar,amanhecer,voo}.wav (mono, 22.050 Hz, 16 bits)
import os
import wave

import numpy as np

SR = 22050


def hz(nota):
    return 440.0 * 2 ** ((nota - 69) / 12.0)


class Faixa:
    def __init__(self, dura):
        self.n = int(dura * SR)
        self.som = np.zeros(self.n)

    def _somar(self, quando, onda):
        i0 = int(quando * SR)
        if i0 >= self.n:
            return
        fim = min(self.n, i0 + len(onda))
        self.som[i0:fim] += onda[:fim - i0]

    def sino(self, nota, quando, dura, forca, brilho=0.25):
        """Nota de sino macio: ataque curto, cauda longa."""
        t = np.arange(int(dura * SR)) / SR
        f = hz(nota)
        env = (1 - np.exp(-t / 0.015)) * np.exp(-t / (dura * 0.3))
        onda = np.sin(2 * np.pi * f * t) + brilho * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.5) \
            + 0.07 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / 0.25)
        self._somar(quando, onda * env * forca)

    def tapete(self, notas, quando, dura, forca):
        """Acorde de fundo: senos que entram e saem devagar, com um leve batimento."""
        t = np.arange(int(dura * SR)) / SR
        env = np.sin(np.pi * np.clip(t / dura, 0, 1)) ** 1.4
        for nota in notas:
            f = hz(nota)
            self._somar(quando, (np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * f * 1.003 * t)) * env * forca / len(notas))

    def sopro(self, nota, quando, dura, forca):
        """Nota longa e aérea (flauta de seno com vibrato)."""
        t = np.arange(int(dura * SR)) / SR
        f = hz(nota)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 4.6 * t) * np.clip(t / 0.6, 0, 1)
        env = np.clip(t / 0.25, 0, 1) * np.clip((dura - t) / 0.6, 0, 1)
        self._somar(quando, (np.sin(2 * np.pi * f * vib * t) + 0.18 * np.sin(2 * np.pi * 2 * f * vib * t)) * env * forca)

    def gravar(self, caminho, cauda=4.0):
        s = self.som.copy()
        k = int(cauda * SR)
        s[-k:] *= np.linspace(1, 0, k) ** 1.5
        # um eco curto, para não soar seco
        eco = np.zeros_like(s)
        for atraso, g in ((0.31, 0.28), (0.53, 0.18), (0.83, 0.1)):
            d = int(atraso * SR)
            eco[d:] += s[:-d] * g
        s = s + eco
        s = s / max(1e-9, np.max(np.abs(s))) * 0.7
        with wave.open(caminho, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((s * 32767).astype(np.int16).tobytes())
        print("ok", caminho, "%.1f s" % (len(s) / SR))


RAIZ = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sons")

# --- lugar novo: curto e claro, um arpejo que sobe e pousa (ré maior)
b = 0.62
f = Faixa(26.0)
acordes = [[62, 66, 69, 74], [57, 64, 69, 73], [59, 62, 66, 71], [55, 59, 62, 67], [57, 61, 64, 69], [62, 66, 69, 74]]
t = 0.4
for i, ac in enumerate(acordes):
    f.tapete([n - 12 for n in ac[:3]], t, b * 4.6, 0.5)
    ordem = [0, 1, 2, 3, 2, 1] if i % 2 == 0 else [0, 2, 1, 3, 2, 3]
    for k, j in enumerate(ordem):
        f.sino(ac[j], t + k * b * 0.66, 2.6, 0.5 if k else 0.7)
    t += b * 4
for k, n in enumerate([74, 78, 81, 86]):
    f.sino(n, t + k * 0.42, 4.5, 0.55)
f.tapete([50, 57, 62, 66], t, 6.0, 0.6)
f.gravar(os.path.join(RAIZ, "musica_lugar.wav"))

# --- amanhecer: lento e morno, notas longas de sopro sobre um tapete (sol maior)
b = 1.5
f = Faixa(46.0)
acordes = [[55, 59, 62], [52, 55, 59], [48, 52, 55], [50, 54, 57], [55, 59, 62], [52, 55, 59], [48, 52, 55], [50, 57, 62]]
melodia = [(74, 0, 3), (71, 3, 1), (67, 4, 3), (69, 7, 1), (72, 8, 2), (71, 10, 2), (69, 12, 3), (66, 15, 1),
           (74, 16, 2), (76, 18, 2), (79, 20, 3), (76, 23, 1), (72, 24, 2), (74, 26, 2), (71, 28, 4)]
t0 = 0.6
for i, ac in enumerate(acordes):
    f.tapete(ac + [ac[0] + 12], t0 + i * 4 * b * 0.58, 4 * b * 0.72, 0.7)
for nota, quando, dura in melodia:
    f.sopro(nota, t0 + quando * b * 0.58, dura * b * 0.62, 0.34)
    f.sino(nota + 12, t0 + quando * b * 0.58, 3.0, 0.12)
f.gravar(os.path.join(RAIZ, "musica_amanhecer.wav"), 6.0)

# --- voo alto: arejado e em movimento, arpejos de seis notas (lá maior)
b = 0.36
f = Faixa(42.0)
acordes = [[57, 61, 64, 69], [54, 57, 61, 66], [50, 54, 57, 62], [52, 56, 59, 64]] * 2 + [[57, 61, 64, 69]]
t = 0.3
for i, ac in enumerate(acordes):
    f.tapete([n - 12 for n in ac[:3]] + [ac[0]], t, b * 12.5, 0.55)
    for rep in range(2):
        for k, j in enumerate([0, 2, 1, 3, 2, 1]):
            f.sino(ac[j] + 12, t + (rep * 6 + k) * b, 1.9, 0.34 if k else 0.5, 0.18)
    if i % 2 == 0:
        f.sopro(ac[3] + 12, t + b * 2, b * 9, 0.22)
    else:
        f.sopro(ac[2] + 12, t + b * 2, b * 9, 0.2)
    t += b * 12
f.gravar(os.path.join(RAIZ, "musica_voo.wav"), 5.0)

# --- vista: um laço calmo para o modo de apreciar a vista (fá maior); as notas dão a volta no fim, sem emenda
b = 1.25
dur = 16 * 4 * b * 0.5
f = Faixa(dur)
n_total = f.n


def volta(faixa, quando, onda):
    i0 = int(quando * SR)
    idx = (i0 + np.arange(len(onda))) % faixa.n
    np.add.at(faixa.som, idx, onda)


f._somar = lambda quando, onda, _f=f: volta(_f, quando, onda)
acordes = [[53, 57, 60, 64], [48, 52, 55, 60], [50, 53, 57, 60], [48, 55, 58, 64]] * 2
passo = dur / len(acordes)
for i, ac in enumerate(acordes):
    t = i * passo
    f.tapete(ac[:3] + [ac[0] + 12], t, passo * 1.25, 0.8)
    for k, j in enumerate([3, 1, 2] if i % 2 == 0 else [2, 3, 1]):
        f.sino(ac[j] + 12, t + 0.4 + k * passo / 3.2, 4.0, 0.33 if k else 0.45, 0.15)
    if i % 4 == 2:
        f.sopro(ac[3] + 12, t + passo * 0.3, passo * 0.9, 0.16)
s2 = f.som / max(1e-9, np.max(np.abs(f.som))) * 0.62
with wave.open(os.path.join(RAIZ, "musica_vista.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((s2 * 32767).astype(np.int16).tobytes())
print("ok musica_vista.wav %.1f s (laço)" % dur)
