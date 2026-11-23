#!/usr/bin/env python3
"""Sons do tiro que bate na água, feitos por síntese (sem gravação), 2026-11-23.
Uso: /usr/bin/python3 tools/sons_tiro_agua.py   (grava em assets/sons/; precisa de numpy)

Usa as peças de tools/sons_agua.py (bolhas, filtros). Mono: tocam num ponto do mundo (AudioStreamPlayer3D).
  - agua_tiro_1 a 3: o laser na lâmina. Um "plic" claro do respingo, o chiado do vapor (o laser é energia)
    e umas bolhinhas. Curto (0,6 s): a rajada toca um a cada tiro.
  - agua_estouro_1 e 2: canhão, míssil e granada na água. O baque grave, o rugido da coluna que sobe e a chuva
    da água caindo de volta, com bolhas no fim (2,4 s)."""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sons_agua as sa  # noqa: E402

SR = sa.SR
rng = np.random.default_rng(2311)


def _mono(som):
    return np.mean(np.atleast_2d(som), axis=0)


def tiro(semente):
    r = np.random.default_rng(semente)
    dura = 0.65
    n = int(dura * SR)
    t = np.arange(n) / SR
    # o plic: estouro curto e claro do respingo
    plic = r.standard_normal(n) * np.exp(-t / 0.018) * (1 - np.exp(-t / 0.0008))
    plic = sa.passa_alta(sa.passa_baixa(plic, 5200.0), 500.0)
    plic /= max(1e-9, np.max(np.abs(plic)))
    # o tom da gota que bate (um seno que sobe rápido, como a bolha que se fecha)
    f = 900.0 * r.uniform(0.85, 1.2) * (1.0 + 1.6 * t / 0.05)
    gota = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.022) * np.minimum(1.0, t / 0.002)
    # o chiado do vapor: ruído agudo que entra logo depois e some em meio segundo
    chiado = sa.passa_alta(r.standard_normal(n), 3200.0)
    chiado = sa.passa_baixa(chiado, 9000.0) * np.exp(-np.maximum(0.0, t - 0.03) / 0.16) * np.minimum(1.0, t / 0.03)
    chiado /= max(1e-9, np.max(np.abs(chiado)))
    som = 0.9 * plic + 0.45 * gota + 0.32 * chiado
    for _ in range(4):
        quando = 0.03 + r.uniform(0.0, 0.25)
        b = sa.bolha(float(np.exp(r.uniform(np.log(700.0), np.log(1700.0)))), 0.35 * r.uniform(0.5, 1.0))
        i0 = int(quando * SR)
        som[i0:i0 + len(b)] += b[: max(0, n - i0)]
    k = int(0.12 * SR)
    som[-k:] *= np.linspace(1, 0, k) ** 2
    return sa.passa_alta(som, 60.0)


def estouro(semente):
    r = np.random.default_rng(semente)
    dura = 2.4
    n = int(dura * SR)
    t = np.arange(n) / SR
    # o baque: grave que cai de tom (a água empurrada de uma vez)
    fase = 2 * np.pi * np.cumsum(34.0 + 48.0 * np.exp(-t / 0.09)) / SR
    baque = np.sin(fase) * np.exp(-t / 0.3) * (1 - np.exp(-t / 0.003))
    # o rugido da coluna que sobe: ruído largo, forte no começo
    rugido = sa.passa_baixa(sa.passa_baixa(r.standard_normal(n), 2600.0), 2600.0)
    rugido = rugido * np.exp(-t / 0.42) * (1 - np.exp(-t / 0.012))
    rugido /= max(1e-9, np.max(np.abs(rugido)))
    # a chuva da água que cai de volta: chiado claro que cresce e some, com pingos soltos
    chuva = sa.passa_alta(sa.passa_baixa(r.standard_normal(n), 7000.0), 1500.0)
    env = np.clip((t - 0.35) / 0.35, 0, 1) * np.exp(-np.maximum(0.0, t - 0.7) / 0.5)
    chuva = chuva * env
    chuva /= max(1e-9, np.max(np.abs(chuva)))
    som = 1.0 * baque + 0.75 * rugido + 0.42 * chuva
    for _ in range(60):  # os pingos grossos
        quando = 0.45 + r.exponential(0.35)
        if quando > dura - 0.1:
            continue
        b = sa.bolha(float(np.exp(r.uniform(np.log(900.0), np.log(2600.0)))), 0.16 * r.uniform(0.4, 1.0),
                     vida=0.006)
        i0 = int(quando * SR)
        som[i0:i0 + len(b)] += b[: max(0, n - i0)]
    for _ in range(14):  # as bolhas grandes no fim
        quando = 0.25 + r.uniform(0.0, 1.2)
        b = sa.bolha(float(np.exp(r.uniform(np.log(180.0), np.log(520.0)))), 0.3 * r.uniform(0.5, 1.0))
        i0 = int(quando * SR)
        som[i0:i0 + len(b)] += b[: max(0, n - i0)]
    k = int(0.4 * SR)
    som[-k:] *= np.linspace(1, 0, k) ** 2
    return sa.passa_alta(som, 22.0)


if __name__ == "__main__":
    for i in range(3):
        sa.grava("agua_tiro_%d" % (i + 1), _mono(tiro(40 + i)), pico_db=-2.0)
    for i in range(2):
        sa.grava("agua_estouro_%d" % (i + 1), _mono(estouro(70 + i)), pico_db=-1.0)
