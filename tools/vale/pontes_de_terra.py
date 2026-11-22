# As pontes de terra entre a ilha de hoje e a terra nova (pedido do usuário, 2026-11-21): duas faixas largas que
# atravessam o canal, uma no oeste (do braço do oeste até a costa oeste da ilha, ao norte do Casco Encalhado) e
# outra no canto do noroeste (do pé do braço do norte até o morro do Observatório). Abrem nas pontas, onde
# encostam nas costas, e afinam no meio; a beira é torta em duas escalas (curvas grandes e enseadas pequenas),
# com praia em volta, colinas baixas e manchas de mata no meio, e umas ilhotas por perto. O canal entre as duas
# vira uma lagoa de água do mar. Esboço aprovado: a proposta "do meio" (2026-11-21).
#
# As duas grades usam este arquivo: tools/vale/mapa_3km.py (a ilha de hoje, ±1500 m) e
# tools/vale/mapa_terra_nova.py (fora do quadrado). O relevo das pontes é feito uma vez, numa grade própria de
# 4 m alinhada às duas, e cada gerador copia o pedaço que cai na sua; assim as duas têm o mesmo valor na borda
# do quadrado e a emenda não abre degrau.
import math

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

P = 4.0
FUNDO = -14.0
# a região das pontes (x de -2800 a -400, z de -2700 a 800); o canto cai na grade das duas (passos de 4 m a
# partir de -3900 e de -1500)
RX0, RZ0 = -2800.0, -2700.0
RNX, RNZ = 601, 876
ALTO = 18.0  # as colinas do meio das pontes
SUAVE = 3.0  # a junção com o chão de hoje (máximo suave, em metros)

# a linha do meio de cada ponte, de uma costa à outra (as pontas entram uns 200 m em cada terra), a meia
# largura no meio e nas pontas
PONTES = [
    ([(-2080, -110), (-1880, -60), (-1680, -170), (-1470, -270), (-1270, -230), (-1060, -280)], 165.0, 310.0),
    ([(-1960, -2000), (-1800, -1720), (-1600, -1540), (-1380, -1440), (-1140, -1270), (-1020, -1180)], 175.0, 300.0),
]
# (ao sul de z 500 e a oeste de x -1500 não há grade nenhuma, só o fundo do mar: a encosta de uma ilhota ali
# acabava num corte reto debaixo d'água)
ILHOTAS = [(-1500, -760, 70), (-1610, -560, 38), (-1420, 330, 55), (-1330, 540, 30), (-1240, -1640, 45)]
# as fontes quentes ficam como estão: as pontes não chegam perto delas
FONTES_C = (-2150.0, -560.0)
FONTES_LIVRE = 330.0

_zz, _xx = np.mgrid[0:RNZ, 0:RNX].astype(float)
_xx = _xx * P + RX0
_zz = _zz * P + RZ0


def _ruido(escala, semente):
    r = np.random.default_rng(semente)
    gx, gz = int(RNX * P / escala) + 3, int(RNZ * P / escala) + 3
    grade = r.random((gz, gx))
    cx, cz = np.arange(RNX) * P / escala, np.arange(RNZ) * P / escala
    ix, iz = cx.astype(int), cz.astype(int)
    fx, fz = cx - ix, cz - iz
    fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
    a, b = grade[np.ix_(iz, ix)], grade[np.ix_(iz, ix + 1)]
    c, d = grade[np.ix_(iz + 1, ix)], grade[np.ix_(iz + 1, ix + 1)]
    fx, fz = fx[None, :], fz[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fz) + (c * (1 - fx) + d * fx) * fz


def _fbm(escala, semente):
    return _ruido(escala, semente) * 0.55 + _ruido(escala / 2.3, semente + 1) * 0.3 + _ruido(escala / 5.1, semente + 2) * 0.15


def _suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def _linha(pts):
    """Distância à linha quebrada e a fração andada (0 a 1) até o ponto mais perto dela."""
    seg = [math.dist(a, b) for a, b in zip(pts[:-1], pts[1:])]
    tot = sum(seg)
    d = np.full((RNZ, RNX), 1e9)
    fr = np.zeros((RNZ, RNX))
    acc = 0.0
    for (ax, az), (bx, bz), c in zip(pts[:-1], pts[1:], seg):
        vx, vz = bx - ax, bz - az
        t = np.clip(((_xx - ax) * vx + (_zz - az) * vz) / (vx * vx + vz * vz), 0, 1)
        dd = np.hypot(_xx - ax - t * vx, _zz - az - t * vz)
        perto = dd < d
        d = np.where(perto, dd, d)
        fr = np.where(perto, (acc + t * c) / tot, fr)
        acc += c
    return d, fr


_campo = None


def campo():
    """O relevo das pontes na grade da região: (altura, quanto é miolo de ponte 0..1, cobertura das pontes)."""
    global _campo
    if _campo is not None:
        return _campo
    terra = np.zeros((RNZ, RNX), bool)
    miolo = np.zeros((RNZ, RNX))
    torto = (_fbm(320, 51) - 0.5) * 220 + (_fbm(90, 52) - 0.5) * 70
    for pts, meio, ponta in PONTES:
        d, fr = _linha(pts)
        w = meio + (ponta - meio) * (np.abs(fr - 0.5) * 2) ** 2.2
        terra |= d < w + torto
        # as colinas só no meio do canal; nas pontas, dentro das terras de hoje, a ponte fica baixa e o chão
        # de hoje manda
        miolo = np.maximum(miolo, (d < w + torto + 160) * _suave(0.0, 0.3, fr) * (1 - _suave(0.7, 1.0, fr)))
    for x, z, r in ILHOTAS:
        terra |= np.hypot(_xx - x, _zz - z) < r + (_fbm(60, int(-x)) - 0.5) * 50
        miolo = np.maximum(miolo, np.hypot(_xx - x, _zz - z) < r + 80)
    # metros terra adentro (negativo no mar), com a beira torta mais uma vez, fina
    s = (ndimage.distance_transform_edt(terra) - ndimage.distance_transform_edt(~terra)) * P
    s += (_fbm(140, 53) - 0.5) * 90
    # da praia para dentro: a areia sobe devagar até 2,8 m e o mar desce com ela; para dentro, colinas
    praia = np.minimum(s * 0.10, 2.8)
    colinas = ALTO * (0.35 + 1.3 * _fbm(220, 57) ** 1.6) + 6.0 * (_fbm(70, 59) - 0.5)
    h = praia + np.maximum(colinas - 2.8, 0) * np.clip((s - 20) / 160, 0, 1) * miolo
    # perto das fontes quentes, nada de ponte
    livre = _suave(FONTES_LIVRE - 80, FONTES_LIVRE, np.hypot(_xx - FONTES_C[0], _zz - FONTES_C[1]))
    h = FUNDO - 40 + (h - FUNDO + 40) * livre
    # a cobertura: areia na beira, campo, e manchas de mata (1) e mata fechada (2)
    mata = _fbm(240, 61)
    cob = np.where(mata > 0.58, 2, np.where(mata > 0.47, 1, 0)).astype(np.uint8)
    cob[h < 2.6] = 4
    _campo = (h, cob)
    return _campo


def _pedaco(x0, z0, nz, nx):
    """O pedaço comum entre a região das pontes e uma grade de 4 m com canto (x0, z0): (fatia da grade, fatia
    da região)."""
    ox, oz = (RX0 - x0) / P, (RZ0 - z0) / P
    assert ox == int(ox) and oz == int(oz), "a grade não está alinhada às pontes"
    ox, oz = int(ox), int(oz)
    gx0, gz0 = max(ox, 0), max(oz, 0)
    gx1, gz1 = min(ox + RNX, nx), min(oz + RNZ, nz)
    if gx1 <= gx0 or gz1 <= gz0:
        return None, None
    return (slice(gz0, gz1), slice(gx0, gx1)), (slice(gz0 - oz, gz1 - oz), slice(gx0 - ox, gx1 - ox))


def aplicar_altura(h, x0, z0):
    """Junta as pontes ao relevo `h` (grade de 4 m com canto x0, z0), no lugar. Devolve onde a terra subiu."""
    hp, _ = campo()
    g, r = _pedaco(x0, z0, *h.shape)
    subiu = np.zeros(h.shape, bool)
    if g is None:
        return subiu
    a, b = h[g], hp[r]
    # máximo suave: a beira da ponte encosta no chão de hoje sem quina
    k = np.clip(SUAVE - np.abs(a - b), 0, None) / SUAVE
    novo = np.maximum(np.maximum(a, b) + k * k * SUAVE * 0.25, FUNDO)
    subiu[g] = novo > a + 0.3
    h[g] = novo
    return subiu


def aplicar_cobertura(cob, subiu, x0, z0):
    """A cobertura das pontes onde a terra subiu (`cob` só com o código: areia, campo ou mata)."""
    _, cp = campo()
    g, r = _pedaco(x0, z0, *cob.shape)
    if g is None:
        return
    pedaco = cob[g]
    s = subiu[g]
    pedaco[s] = cp[r][s]
    cob[g] = pedaco
