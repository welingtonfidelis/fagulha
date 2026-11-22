# A ilha de hoje e a terra nova numa terra só (pedido do usuário, 2026-11-21: "o formato das ilhas está muito
# artificial"; o rascunho 5, de costa natural, foi aprovado: "ficou bem melhor, vamos seguir nesse formato").
# Trabalha na grade do mundo (4 m, x e z de -3900 a 1500), já com as duas terras e as pontes de terra:
#  1. o canal entre as duas vira terra (um fechamento de 360 m, só onde as duas estão perto), menos a baía do
#     norte (o Navio, a praia da área A e as Torres continuam de frente para o mar), a enseada do sudoeste (o
#     Casco) e um lago no meio;
#  2. a costa ganha forma em três escalas (curvas grandes, enseadas e pontas, recorte miúdo), mais forte na
#     costa de montanha; perto dos lugares, dos rios e dos lagos ela fica onde está, e a costa da ilha de hoje
#     só muda perto do canal que virou terra (a de lá já era torta);
#  3. fiordes na costa da montanha, baías na costa de fora (que era quase reta) e umas ilhas soltas.
# O relevo: o que era terra fica (descendo até a costa nova onde ela entrou: em praia na planície, em parede
# na montanha); a terra nova é baixa perto das duas terras e ganha colinas no meio; o mar acompanha a costa
# nova. Quem chama é tools/vale/mapa_mundo.py.
import math

import numpy as np
from scipy import ndimage

P = 4.0
W0 = -3900.0
N = 1351  # x e z de -3900 a 1500
FUNDO = -14.0
META = 1500.0  # a ilha de hoje é o quadrado de ±1500 m
TN_X1, TN_Z1 = 700.0, 500.0  # onde acaba a grade da terra nova (a leste e ao sul)

zz, xx = np.mgrid[0:N, 0:N].astype(float)
xx = xx * P + W0
zz = zz * P + W0

# os lugares que a costa não mexe (nome, x, z)
LUGARES = [("Torres do Vento", 195, -1178), ("Observatório", -700, -1088), ("Casco Encalhado", -1206, 322),
           ("Fontes Quentes", -2150, -560), ("Navio", -450, -1713), ("Clareira", 0, -40), ("Farol", 1338, -1338),
           ("Cais", 806, 902), ("Ilha do Relé", 1282, 648), ("Gigantes", 470, 400), ("Montanha do Degelo", -2820, -2860)]
TORRES = [(-10, -1172), (128, -1186), (262, -1168), (396, -1182), (534, -1166)]
PRAIA_A = (150.0, -1790.0)  # a ponta da praia da área A

# os cortes (linha do meio da boca até o fundo, meia largura na boca e no fundo)
CORTES = [
    ([(-3900, -2330), (-3600, -2360), (-3380, -2290), (-3250, -2310)], 150, 30),  # fiorde do oeste (o fundo fica a 340 m da nascente do rio do sul)
    ([(-2330, -3900), (-2380, -3560), (-2310, -3380), (-2420, -3180)], 130, 30),  # fiorde do norte
    ([(-1500, -3900), (-1560, -3600), (-1700, -3420), (-1760, -3250)], 260, 50),  # baía do norte da terra nova
    ([(-3900, -1180), (-3560, -1150), (-3300, -1030), (-3120, -1060)], 300, 40),  # baía do oeste
    ([(-3900, -420), (-3620, -380), (-3450, -300)], 170, 30),  # enseada do sudoeste da terra nova
    ([(820, -1340), (900, -1190), (990, -1090)], 170, 40),  # a boca da baía do norte, mais aberta
]
ILHAS = [(-3640, -1680, 70), (-3600, -820, 45), (-2050, -3680, 60), (-2700, 330, 80), (-2480, 380, 40),
         (-3300, 300, 55), (-1820, -3700, 35)]


def ruido(escala, semente):
    r = np.random.default_rng(semente)
    g = int(N * P / escala) + 3
    grade = r.random((g, g))
    c = np.arange(N) * P / escala
    i = c.astype(int)
    f = c - i
    f = f * f * (3 - 2 * f)
    a, b = grade[np.ix_(i, i)], grade[np.ix_(i, i + 1)]
    cc, d = grade[np.ix_(i + 1, i)], grade[np.ix_(i + 1, i + 1)]
    fx, fz = f[None, :], f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fz) + (cc * (1 - fx) + d * fx) * fz


def fbm(e, s):
    return ruido(e, s) * 0.55 + ruido(e / 2.3, s + 1) * 0.3 + ruido(e / 5.1, s + 2) * 0.15


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def distancia_com_sinal(m):
    """Metros terra adentro (negativo no mar)."""
    return (ndimage.distance_transform_edt(m) - ndimage.distance_transform_edt(~m)) * P


def linha(pts):
    """Distância à linha quebrada e a fração andada (0 a 1) até o ponto mais perto dela."""
    seg = [math.dist(a, b) for a, b in zip(pts[:-1], pts[1:])]
    tot = sum(seg)
    d = np.full((N, N), 1e9)
    fr = np.zeros((N, N))
    acc = 0.0
    for (ax, az), (bx, bz), c in zip(pts[:-1], pts[1:], seg):
        vx, vz = bx - ax, bz - az
        t = np.clip(((xx - ax) * vx + (zz - az) * vz) / (vx * vx + vz * vz), 0, 1)
        dd = np.hypot(xx - ax - t * vx, zz - az - t * vz)
        p = dd < d
        d = np.where(p, dd, d)
        fr = np.where(p, (acc + t * c) / tot, fr)
        acc += c
    return d, fr


def _dist_pontos(pts):
    """Distância (m) até uma linha de muitos pontos (os rios): a linha vai para a grade e a distância sai dela."""
    marca = np.zeros((N, N), bool)
    for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
        n = max(int(math.dist((ax, az), (bx, bz)) / 2.0), 1)
        for t in np.linspace(0, 1, n + 1):
            i, j = int(round((ax + (bx - ax) * t - W0) / P)), int(round((az + (bz - az) * t - W0) / P))
            if 0 <= i < N and 0 <= j < N:
                marca[j, i] = True
    return ndimage.distance_transform_edt(~marca) * P


def juntar(h, cob, rios, lagos, fontes, pontos=()):
    """`h` e `cob` (só o código) na grade do mundo; `rios`, `lagos` e `fontes` da terra nova (o json); `pontos`:
    (x, z) de itens que a costa deve deixar onde estão. Devolve (altura, cobertura, onde mudou, onde virou terra)."""
    h = h.astype(float)
    L0 = h > 0
    quad = (np.abs(xx) <= META) & (np.abs(zz) <= META)
    dv = ndimage.distance_transform_edt(~(L0 & quad)) * P
    dt = ndimage.distance_transform_edt(~(L0 & ~quad)) * P
    entre = (dv < 800) & (dt < 800)
    # 1. o canal vira terra
    rf = 360.0
    dil = ndimage.distance_transform_edt(~L0) * P <= rf
    fecha = ndimage.distance_transform_edt(dil) * P > rf
    enche = fecha & ~L0 & entre
    nb = (xx > -640 + (fbm(300, 5) - 0.5) * 260) & (zz < -1300) & (zz > -1850)
    sw = (zz > -40 + (fbm(300, 6) - 0.5) * 240) & (xx > -1900) & (xx < -1100)
    lago = (np.hypot((xx + 1730) * 0.8, zz + 1120) - 120 + (fbm(90, 7) - 0.5) * 110 + (fbm(35, 8) - 0.5) * 30 < 0) | \
           (np.hypot(xx + 1600, (zz + 1010) * 1.3) - 70 + (fbm(90, 9) - 0.5) * 70 < 0)
    L1 = L0 | (enche & ~nb & ~sw)
    L1 &= ~(lago & ~L0 | lago & (h < 30) & ~quad)
    encheu = L1 & ~L0
    # 2. a costa em três escalas
    S0 = distancia_com_sinal(L0)
    S1 = distancia_com_sinal(L1)
    prot = np.ones((N, N))
    for _, x, z in LUGARES:
        prot = np.minimum(prot, suave(140, 320, np.hypot(xx - x, zz - z)))
    for x, z in TORRES:
        prot = np.minimum(prot, suave(100, 240, np.hypot(xx - x, zz - z)))
    prot = np.minimum(prot, suave(550, 850, np.hypot(xx - PRAIA_A[0], zz - PRAIA_A[1])))
    perto_agua_doce = np.ones((N, N))
    for r in rios:
        perto_agua_doce = np.minimum(perto_agua_doce, suave(r["faixa"] + 150, r["faixa"] + 300, _dist_pontos(r["pts"])))
    for lg in lagos:
        perto_agua_doce = np.minimum(perto_agua_doce, suave(lg["raio"] + 100, lg["raio"] + 250, np.hypot(xx - lg["x"], zz - lg["z"])))
    for f in fontes:
        perto_agua_doce = np.minimum(perto_agua_doce, suave(f["raio"] + 60, f["raio"] + 160, np.hypot(xx - f["x"], zz - f["z"])))
    prot = np.minimum(prot, perto_agua_doce)
    for x, z in pontos:
        prot = np.minimum(prot, suave(50, 150, np.hypot(xx - x, zz - z)))
    # a costa da ilha de hoje já era torta: só muda perto do canal que virou terra
    d_encheu = ndimage.distance_transform_edt(~encheu) * P
    calma = np.where(quad, 1 - suave(250, 550, d_encheu), 1.0)
    calma = ndimage.gaussian_filter(calma, 12)
    rocha = suave(40, 200, ndimage.gaussian_filter(np.maximum(h, 0), 25))  # costa de montanha: recorte mais forte
    amp = prot * calma * (1 - 0.45 * rocha)
    torto = (fbm(800, 11) - 0.5) * 300 + (fbm(260, 13) - 0.5) * 140 + (fbm(70, 15) - 0.5) * (30 + 50 * rocha)
    S2 = S1 + torto * amp * (1 - suave(350, 500, np.abs(S1)))
    # 3. fiordes, baías e ilhas
    for pts, boca, ponta in CORTES:
        d, fr = linha(pts)
        w = boca * (1 - fr) ** 0.9 + ponta * fr
        S2 = np.minimum(S2, d - w + (fbm(110, 23) - 0.5) * 60)
    for x, z, r in ILHAS:
        S2 = np.maximum(S2, r - np.hypot(xx - x, zz - z) + (fbm(50, int(-x)) - 0.5) * 40)
    # fora das grades só há fundo do mar: a costa para 120 m antes delas
    S2 = np.minimum(S2, np.minimum(xx + 3900, zz + 3900) - 130)
    S2 = np.where(xx < -META, np.minimum(S2, TN_Z1 - 120 - zz), S2)
    S2 = np.where(zz < -META, np.minimum(S2, TN_X1 - 120 - xx), S2)
    L2 = S2 > 0
    sp = np.maximum(S2, 0)

    # o relevo da terra nova: baixa perto das duas terras, colinas no meio
    d_L0 = ndimage.distance_transform_edt(~L0) * P
    morro = 22 * (0.3 + 1.3 * fbm(260, 31) ** 1.6) + 6 * (fbm(70, 33) - 0.5)
    # (da praia o chão sobe devagar, para não ficar rente ao mar: abaixo de 4,5 m o chão da ilha de hoje é areia)
    gen = np.minimum(sp * 0.10, 2.8) + np.minimum(np.maximum(sp - 28, 0) * 0.04, 6.0) + \
        np.maximum(morro - 2.8, 0) * np.clip((S2 - 20) / 160, 0, 1) * suave(0, 160, d_L0)
    # onde a costa entrou na terra o chão desce até ela: em praia na planície, em parede na montanha
    ingreme = suave(30, 160, h)
    # a parede de pedra não é lisa: esporões e grotas (ruído em crista) e o relevo miúdo da montanha que estava ali
    crista = 1 - np.abs(2 * fbm(60, 45) - 1)
    miudo = h - ndimage.gaussian_filter(h, 6)
    parede = 0.5 + sp * 1.5 * (0.7 + 0.6 * fbm(120, 41)) + (crista - 0.5) * np.minimum(sp, 120) * 0.6 + miudo
    teto = (np.minimum(sp * 0.1, 2.8) + np.maximum(sp - 28, 0) * 0.1) * (1 - ingreme) + parede * ingreme + (sp / 120) ** 2 * 60
    entrou = suave(4, 20, S0 - S2)
    velha = h + (np.minimum(h, teto) - h) * entrou
    # a praia antiga que ficou terra adentro, na beira do canal, sobe ao chão da terra nova
    # (e onde o mar se afastou: a praia das pontes de terra, na beira da antiga lagoa)
    afastou = suave(20, 60, S2 - S0)
    perto_canal = np.maximum(1 - suave(40, 120, d_encheu), afastou)
    velha = np.maximum(velha, gen * perto_canal)
    terra = np.where(L0, velha, gen)
    # o mar: mais raso onde a costa chegou perto, mais fundo onde ela recuou, em rampa até o fundo
    alvo = np.maximum(FUNDO, S2 * (0.12 + 0.28 * rocha))
    chegou = suave(4, 20, S2 - S0)
    recuou = suave(4, 20, S0 - S2)
    mar = h + (np.maximum(h, alvo) - h) * chegou + (np.minimum(h, alvo) - h) * recuou
    mar = np.where(chegou > 0, np.minimum(mar, -0.05), mar)
    mar = np.where(L0, alvo, mar)
    hn = np.where(L2, np.maximum(terra, 0.05), mar)
    # a borda das mudanças, alisada (longe dos rios e lagos, que têm leito cavado)
    mudou = np.abs(hn - h) > 0.02
    alisa = ndimage.gaussian_filter(ndimage.binary_dilation(mudou, iterations=6).astype(float), 2) * perto_agua_doce
    hn = hn + (ndimage.gaussian_filter(hn, 1.5) - hn) * alisa
    hn = np.maximum(hn, FUNDO)
    # a emenda das duas grades no fundo do mar (z = -1500 ao norte e x = -1500 a oeste): o mar raso da terra
    # nova encostava no fundo de 14 m da ilha de hoje num degrau de até 6 m, que do alto se via como uma linha
    # reta na baía do Navio; ali o fundo é alisado na direção que cruza a emenda
    mar_ = hn < 0
    raso = np.minimum(hn, 0)
    for liso, banda in [(ndimage.gaussian_filter1d(raso, 40, axis=0), (1 - suave(0, 240, np.abs(zz + META))) * (xx >= -META) * (xx <= TN_X1)),
                        (ndimage.gaussian_filter1d(raso, 40, axis=1), (1 - suave(0, 240, np.abs(xx + META))) * (zz >= -META) * (zz <= TN_Z1))]:
        hn = np.where(mar_ & (banda > 0), np.minimum(hn + (liso - hn) * banda, -0.05), hn)
    mudou = np.abs(hn - h) > 0.02

    # a cobertura
    cn = cob.copy()
    nova = L2 & ~L0
    mata = fbm(240, 61)
    nova |= L0 & L2 & (cob == 4) & (h < 4) & (S2 > 40) & (perto_canal > 0.5)
    cn[nova] = np.where(mata[nova] > 0.58, 2, np.where(mata[nova] > 0.47, 1, 0))
    inclin = np.hypot(np.gradient(hn, axis=0), np.gradient(hn, axis=1)) / P
    m = mudou & (hn > 2.6) & (inclin > 0.9)
    cn[m] = 6
    m = mudou & (((hn < 2.6) & (inclin < 0.6)) | (hn <= 0))
    cn[m] = 4
    return hn, cn, mudou, nova


# ---------- o fundo do mar e das lagoas de nível do mar (pedido do usuário, 2026-11-22) ----------
# "tudo é muito raso, até o mar... é tudo reto sem afundar": o fundo parava em 14 m a uns 100 m da praia e
# dali para fora era uma planície. Agora a beira continua igual (a praia e a água de nadar) e o fundo segue
# descendo: uns 15 m a 100 m da terra, 25 m a 150 m e o fundo de 40 m a uns 190 m. As lagoas fechadas que ficam
# no nível do mar (a do meio das terras) descem em tigela até uns 16 m. Fora das grades do jogo o fundo é o
# FUNDO_FUNDO (`TerraNova.FUNDO`), e perto delas o fundo desce até ele.
FUNDO_FUNDO = -40.0


def aprofundar(h, hn):
    agua = hn < 0
    rot, _ = ndimage.label(agua)
    da_borda = set(np.unique(np.concatenate([rot[0], rot[-1], rot[:, 0], rot[:, -1]]).tolist())) - {0}
    mar = np.isin(rot, list(da_borda))
    # só as lagoas grandes (a do meio das terras); as piscinas naturais da costa continuam rasas, de nadar
    tam = np.bincount(rot.ravel())
    lagoa = agua & ~mar & (tam[rot] >= 1500)
    dist = ndimage.distance_transform_edt(agua) * P  # até a terra mais perto
    perfil = -(0.10 * dist + 0.10 * np.maximum(0, dist - 50) + 0.20 * np.maximum(0, dist - 150))
    perfil = np.maximum(perfil * (0.85 + 0.3 * fbm(420, 71)), FUNDO_FUNDO)
    novo = np.where(mar, np.minimum(hn, perfil), hn)
    tigela = np.maximum(-(0.14 * dist) * (0.85 + 0.3 * fbm(160, 73)), -16.0)
    novo = np.where(lagoa, np.minimum(novo, tigela), novo)
    # perto do que fica fora das grades do jogo (os dois cantos sem grade e a beira do mundo) o fundo chega no
    # FUNDO_FUNDO, sem degrau
    coberto = ~(((xx > TN_X1) & (zz < -META)) | ((xx < -META) & (zz > TN_Z1)))
    coberto[0, :] = coberto[-1, :] = coberto[:, 0] = coberto[:, -1] = False
    d_borda = ndimage.distance_transform_edt(coberto) * P
    k = suave(0, 80, d_borda)
    novo = np.where(mar, np.minimum(novo, FUNDO_FUNDO * (1 - k) + novo * k), novo)
    novo = ndimage.gaussian_filter(novo, 1.2) * mar + novo * ~mar  # sem quina no fundo
    novo = np.where(mar, np.minimum(novo, -0.05), novo)
    novo = np.where(mar & (hn >= -0.3), hn, novo)  # a lâmina da beira fica como estava
    return novo, np.abs(novo - h) > 0.02
