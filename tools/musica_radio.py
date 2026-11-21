# As músicas do rádio da base (1.1, doc §136): três faixas de um minuto e pouco, feitas por síntese, que o rádio
# da bancada toca em fila quando o jogador liga. Mais "música de rádio" que os temas do passeio: compasso,
# baixo, bateria macia, acordes e uma melodia que volta.
#   /usr/bin/python3 tools/musica_radio.py  ->  assets/sons/radio_{manha,tarde,noite}.wav (mono, 22.050 Hz, 16 bits)
import os
import wave

import numpy as np

SR = 22050
PASTA = os.path.join(os.path.dirname(__file__), "..", "assets", "sons")


def hz(nota):
    return 440.0 * 2 ** ((nota - 69) / 12.0)


class Faixa:
    def __init__(self, dura, semente):
        self.n = int(dura * SR)
        self.som = np.zeros(self.n)
        self.rng = np.random.default_rng(semente)

    def _somar(self, quando, onda):
        i0 = int(quando * SR)
        if i0 >= self.n or i0 < 0:
            return
        fim = min(self.n, i0 + len(onda))
        self.som[i0:fim] += onda[:fim - i0]

    def piano(self, nota, quando, dura, forca):
        """Piano elétrico: seno com o segundo harmônico que some depressa e um tremolo leve."""
        t = np.arange(int((dura + 0.6) * SR)) / SR
        f = hz(nota)
        env = (1 - np.exp(-t / 0.004)) * np.exp(-t / 0.9) * np.clip((dura + 0.6 - t) / 0.4, 0, 1)
        onda = np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.15) \
            + 0.12 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / 0.08)
        onda *= 1 + 0.12 * np.sin(2 * np.pi * 4.2 * t)
        self._somar(quando, onda * env * forca)

    def corda(self, nota, quando, forca, dura=1.6):
        """Corda dedilhada (Karplus-Strong)."""
        f = hz(nota)
        p = max(2, int(SR / f))
        n = int(dura * SR)
        buf = self.rng.uniform(-1, 1, p)
        saida = np.zeros(n)
        for i in range(n):
            saida[i] = buf[i % p]
            buf[i % p] = 0.5 * (buf[i % p] + buf[(i + 1) % p]) * 0.996
        self._somar(quando, saida * forca)

    def baixo(self, nota, quando, dura, forca):
        t = np.arange(int(dura * SR)) / SR
        f = hz(nota)
        env = (1 - np.exp(-t / 0.01)) * np.exp(-t / (dura * 0.8)) * np.clip((dura - t) / 0.05, 0, 1)
        onda = np.tanh(1.6 * (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)))
        self._somar(quando, onda * env * forca)

    def sino(self, nota, quando, dura, forca):
        t = np.arange(int(dura * SR)) / SR
        f = hz(nota)
        env = (1 - np.exp(-t / 0.003)) * np.exp(-t / (dura * 0.35))
        onda = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-t / 0.3) \
            + 0.15 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t / 0.12)
        self._somar(quando, onda * env * forca)

    def sopro(self, nota, quando, dura, forca):
        t = np.arange(int(dura * SR)) / SR
        f = hz(nota)
        vib = 1 + 0.005 * np.sin(2 * np.pi * 5.0 * t) * np.clip(t / 0.4, 0, 1)
        env = np.clip(t / 0.06, 0, 1) * np.clip((dura - t) / 0.15, 0, 1)
        fase = 2 * np.pi * np.cumsum(f * vib) / SR
        self._somar(quando, (np.sin(fase) + 0.2 * np.sin(2 * fase) + 0.05 * np.sin(3 * fase)) * env * forca)

    def tapete(self, notas, quando, dura, forca):
        t = np.arange(int(dura * SR)) / SR
        env = np.clip(t / 0.8, 0, 1) * np.clip((dura - t) / 0.8, 0, 1)
        for nota in notas:
            f = hz(nota)
            self._somar(quando, (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.004 * t)) * env * forca / len(notas))

    def bumbo(self, quando, forca):
        t = np.arange(int(0.35 * SR)) / SR
        f = 45 + 80 * np.exp(-t / 0.04)
        fase = 2 * np.pi * np.cumsum(f) / SR
        self._somar(quando, np.sin(fase) * np.exp(-t / 0.12) * forca)

    def chimbal(self, quando, forca):
        n = int(0.06 * SR)
        r = self.rng.uniform(-1, 1, n)
        r = np.diff(r, prepend=0)  # tira o grave: fica só o chiado
        self._somar(quando, r * np.exp(-np.arange(n) / SR / 0.018) * forca)

    def caixa(self, quando, forca):
        n = int(0.2 * SR)
        t = np.arange(n) / SR
        r = self.rng.uniform(-1, 1, n)
        onda = 0.6 * r * np.exp(-t / 0.06) + 0.5 * np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.05)
        self._somar(quando, onda * forca)

    def gravar(self, nome, cauda=3.0):
        s = self.som.copy()
        k = int(cauda * SR)
        s[-k:] *= np.linspace(1, 0, k) ** 1.5
        eco = np.zeros_like(s)
        for atraso, g in ((0.27, 0.22), (0.49, 0.12)):
            d = int(atraso * SR)
            eco[d:] += s[:-d] * g
        s = s + eco
        s = s / max(1e-6, np.max(np.abs(s))) * 0.85
        caminho = os.path.join(PASTA, nome + ".wav")
        with wave.open(caminho, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((s * 32767).astype(np.int16).tobytes())
        print(caminho, "%.1f s" % (len(s) / SR))


# ---------------------------------------------------------------- as faixas

def frase(rng, escala, n, base, de=0):
    """Uma frase de melodia: passos curtos na escala, voltando para perto do começo."""
    i = de
    notas = []
    for _ in range(n):
        i = int(np.clip(i + rng.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(escala) - 1))
        notas.append(base + escala[i])
    return notas


def manha():
    """Manhã: 88 bpm, dó maior, piano elétrico, baixo e bateria macia; melodia de sopro."""
    bpm = 88
    b = 60 / bpm
    acordes = [[48, 52, 55, 59], [45, 48, 52, 55], [41, 45, 48, 52], [43, 47, 50, 53]]  # C7M Am7 F7M G7
    compassos = 28
    f = Faixa(compassos * 4 * b + 3.0, 11)
    escala = [0, 2, 4, 7, 9, 12, 14, 16]
    a = frase(f.rng, escala, 8, 72, 2)
    bb = frase(f.rng, escala, 8, 72, 4)
    for c in range(compassos):
        t0 = c * 4 * b
        ac = acordes[c % 4]
        for nota in ac[1:]:
            f.piano(nota + 12, t0, 2 * b, 0.12)
            f.piano(nota + 12, t0 + 2.5 * b, 1.2 * b, 0.08)
        f.baixo(ac[0] - 12, t0, 1.4 * b, 0.34)
        f.baixo(ac[0] - 12 + (7 if c % 2 else 0), t0 + 2 * b, 1.4 * b, 0.28)
        if 2 <= c < compassos - 2:
            f.bumbo(t0, 0.5)
            f.bumbo(t0 + 2.5 * b, 0.35)
            f.caixa(t0 + b, 0.12)
            f.caixa(t0 + 3 * b, 0.12)
            for k in range(8):
                f.chimbal(t0 + k * b * 0.5, 0.05 if k % 2 else 0.08)
        if 4 <= c < 12 or 16 <= c < 24:
            mel = a if (c // 2) % 2 == 0 else bb
            for k in range(4):
                nota = mel[(c % 2) * 4 + k]
                f.sopro(nota, t0 + k * b, b * (0.9 if k < 3 else 1.6), 0.16)
    f.gravar("radio_manha")


def tarde():
    """Tarde: 76 bpm, lá menor, violão dedilhado e baixo; melodia de sino."""
    bpm = 76
    b = 60 / bpm
    acordes = [[45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [48, 55, 60, 64, 67], [43, 50, 55, 59, 62]]  # Am F C G
    compassos = 24
    f = Faixa(compassos * 4 * b + 3.0, 23)
    padrao = [0, 2, 3, 4, 3, 2, 1, 2]
    escala = [0, 3, 5, 7, 10, 12, 15]
    mel = frase(f.rng, escala, 16, 69, 3)
    for c in range(compassos):
        t0 = c * 4 * b
        ac = acordes[c % 4]
        for k, i in enumerate(padrao):
            f.corda(ac[i], t0 + k * b * 0.5, 0.22 if k % 2 == 0 else 0.16)
        f.baixo(ac[0] - 12, t0, 2.5 * b, 0.3)
        f.baixo(ac[0] - 12, t0 + 3 * b, 0.9 * b, 0.22)
        if 2 <= c < compassos - 2:
            f.bumbo(t0, 0.32)
            f.bumbo(t0 + 2 * b, 0.25)
            for k in range(4):
                f.chimbal(t0 + k * b + b * 0.5, 0.05)
        if 4 <= c < 20:
            for k in range(2):
                nota = mel[(c * 2 + k) % len(mel)]
                f.sino(nota, t0 + k * 2 * b, 2.4 * b, 0.2)
    f.gravar("radio_tarde")


def noite():
    """Noite: 64 bpm, ré maior com sétima, tapete e caixinha de música; quase sem bateria."""
    bpm = 64
    b = 60 / bpm
    acordes = [[50, 54, 57, 61], [47, 50, 54, 57], [43, 47, 50, 54], [45, 49, 52, 55]]  # D7M Bm7 G7M A7
    compassos = 20
    f = Faixa(compassos * 4 * b + 4.0, 37)
    escala = [0, 2, 4, 7, 9, 11, 12, 14]
    mel = frase(f.rng, escala, 24, 74, 2)
    for c in range(compassos):
        t0 = c * 4 * b
        ac = acordes[c % 4]
        f.tapete([n + 12 for n in ac], t0, 4 * b + 0.6, 0.22)
        f.baixo(ac[0] - 12, t0, 3.5 * b, 0.22)
        for k in range(4):
            f.piano(ac[k % 4] + 12, t0 + k * b, 0.9 * b, 0.06)
        if 2 <= c < compassos - 2:
            f.bumbo(t0, 0.18)
        if 2 <= c < compassos - 2:
            for k in range(3):
                nota = mel[(c * 3 + k) % len(mel)]
                f.sino(nota + 12, t0 + k * b * 1.33, 2.0 * b, 0.13)
    f.gravar("radio_noite")


if __name__ == "__main__":
    manha()
    tarde()
    noite()
