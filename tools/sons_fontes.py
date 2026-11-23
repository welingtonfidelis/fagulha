#!/usr/bin/env python3
"""Sons das fontes quentes (área B), feitos por síntese, 2026-11-22.
Uso: /usr/bin/python3 tools/sons_fontes.py   (grava em assets/sons/; precisa de numpy)

O game designer notou que as fontes não tinham som. Todos mono, para o som 3D apontar de onde vem:
  - fonte_borbulha_loop: o borbulhar baixo de uma poça quente. Bolhas graves e médias em punhados, um ronco
    leve de água mexendo por baixo. 14 s; as bolhas que passam do fim voltam pelo começo e o ronco é filtrado
    no laço inteiro (FFT), então emenda sem estalo.
  - respiro_loop: o chiado do vapor saindo de um furo no chão. Ruído agudo que respira devagar. 9 s, em laço.
  - geiser: o gêiser pequeno. O gorgolejo que cresce, o jato que ronca e chia, os respingos e o fim. 13 s.
  - lama_1 a lama_3: o "blop" de uma bolha de lama grossa que estoura devagar.

Usa as peças de tools/sons_agua.py (bolha, ruído moldado, filtros)."""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sons_agua as sa  # noqa: E402

SR = sa.SR
rng = np.random.default_rng(3011)


def bolha_mono(alvo, quando, f0, forca, sobe=None, vida=None, circular=False):
    onda = sa.bolha(f0, forca, sobe, vida)
    n = len(alvo)
    idx = int(quando * SR) + np.arange(len(onda))
    if circular:
        idx %= n
    else:
        ok = idx < n
        idx, onda = idx[ok], onda[ok]
    np.add.at(alvo, idx, onda)


def borbulha():
    dura = 14.0
    n = int(dura * SR)
    t = np.arange(n) / SR

    # o ronco por baixo: água mexendo, grave e abafado
    def forma(f):
        return (1.0 / (1.0 + (f / 260.0) ** 4)) * (f / (f + 35.0)) ** 3
    ronco = sa.ruido_moldado(n, forma) * (1.0 + 0.3 * np.sin(2 * np.pi * 3 * t / dura) + 0.15 * np.sin(2 * np.pi * 5 * t / dura + 1.1))
    som = ronco * 0.16
    # punhados de bolhas, de vez em quando; às vezes um bolhão
    k = 0.0
    while k < dura:
        quantas = int(rng.integers(3, 9))
        for _ in range(quantas):
            q = k + rng.uniform(0, 0.5) ** 1.4
            f0 = np.exp(rng.uniform(np.log(150.0), np.log(520.0)))
            bolha_mono(som, q, f0, rng.uniform(0.25, 0.6), circular=True)
        if rng.random() < 0.35:
            bolha_mono(som, k + 0.2, rng.uniform(85.0, 130.0), 0.8, sobe=0.7, vida=0.06, circular=True)
        k += rng.uniform(0.45, 1.3)
    return som


def respiro():
    dura = 9.0
    n = int(dura * SR)
    t = np.arange(n) / SR

    def forma(f):
        return np.exp(-((np.log(np.maximum(f, 1.0)) - np.log(3600.0)) / 0.55) ** 2) + 0.25 * np.exp(-((np.log(np.maximum(f, 1.0)) - np.log(900.0)) / 0.5) ** 2)
    chiado = sa.ruido_moldado(n, forma)
    respira = 1.0 + 0.28 * np.sin(2 * np.pi * 2 * t / dura + 0.3) + 0.12 * np.sin(2 * np.pi * 7 * t / dura + 2.0)
    return chiado * respira


def geiser():
    dura = 13.0
    n = int(dura * SR)
    t = np.arange(n) / SR
    som = np.zeros(n)
    # 0 a 3,5 s: o gorgolejo que cresce (bolhas graves cada vez mais juntas)
    q = 0.05
    while q < 3.6:
        f0 = np.exp(rng.uniform(np.log(70.0), np.log(260.0)))
        bolha_mono(som, q, f0, 0.35 + 0.5 * q / 3.6, sobe=rng.uniform(0.4, 0.9), vida=rng.uniform(0.03, 0.07))
        q += rng.uniform(0.04, 0.32) * (1.15 - q / 3.6)
    # o jato: ruído largo que entra rápido em 3,5 s, ronca até uns 9 s e some até 11,5
    entra = np.clip((t - 3.45) / 0.25, 0, 1)
    sai = np.clip((11.5 - t) / 2.6, 0, 1) ** 1.5
    env = entra * sai * (1.0 + 0.12 * np.sin(2 * np.pi * 1.7 * t) + 0.08 * np.sin(2 * np.pi * 3.1 * t + 0.6))
    def forma_jato(f):
        return (f / (f + 120.0)) ** 2 / (1.0 + (f / 5200.0) ** 3)
    jato = sa.ruido_moldado(n, forma_jato)
    def forma_ronco(f):
        return (1.0 / (1.0 + (f / 180.0) ** 4)) * (f / (f + 30.0)) ** 3
    ronco = sa.ruido_moldado(n, forma_ronco)
    som += (0.55 * jato + 0.5 * ronco) * env
    # os respingos que caem em volta (estalinhos de água)
    for _ in range(260):
        q = rng.uniform(4.2, 11.8)
        f0 = np.exp(rng.uniform(np.log(900.0), np.log(3200.0)))
        bolha_mono(som, q, f0, 0.12 * rng.uniform(0.4, 1.0) * min(1.0, (11.8 - q) / 3.0), sobe=1.6, vida=0.004)
    # o fim: uns goles que voltam para o furo
    for q in (11.6, 11.9, 12.3):
        bolha_mono(som, q, rng.uniform(90.0, 150.0), 0.5, sobe=0.6, vida=0.06)
    som = sa.passa_alta(som, 30.0)
    k = int(0.25 * SR)
    som[-k:] *= np.linspace(1, 0, k)
    return som


def lama(qual):
    dura = 1.1
    n = int(dura * SR)
    t = np.arange(n) / SR
    som = np.zeros(n)
    f0 = [72.0, 95.0, 120.0][qual]
    # a bolha grossa que incha (tom subindo devagar) e o estouro mole
    bolha_mono(som, 0.02, f0, 1.0, sobe=0.35, vida=0.09)
    estouro = rng.standard_normal(n) * np.exp(-np.maximum(t - 0.28, 0) / 0.02) * (t > 0.28)
    som += 0.35 * sa.passa_baixa(sa.passa_baixa(estouro, 900.0), 900.0) / 0.2
    bolha_mono(som, 0.3, f0 * 2.2, 0.35, sobe=0.8, vida=0.03)
    som = sa.passa_baixa(sa.passa_alta(som, 35.0), 1800.0)
    fim = int(np.max(np.nonzero(np.abs(som) > 1e-4)) + 0.04 * SR)
    som = som[:min(n, fim)]
    som[-int(0.03 * SR):] *= np.linspace(1, 0, int(0.03 * SR))
    return som


if __name__ == "__main__":
    sa.grava("fonte_borbulha_loop", borbulha(), rms_db=-21.0)
    sa.grava("respiro_loop", respiro(), rms_db=-22.0)
    sa.grava("geiser", geiser(), pico_db=-1.0)
    for i in range(3):
        sa.grava("lama_%d" % (i + 1), lama(i), pico_db=-3.0)
