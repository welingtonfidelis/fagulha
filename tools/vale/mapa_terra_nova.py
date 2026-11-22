# Relevo da terra nova do noroeste (2026-11-21): o contorno que o usuário desenhou por cima do esboço (um braço
# ao norte e outro a oeste, separados da ilha de hoje por um canal), com a Montanha do Degelo na ponta do
# noroeste: neve no alto, um circo glacial com um lago, dois rios de degelo que descem em degraus de cachoeira
# até o mar, o Lago Turquesa no caminho do rio do leste e mata boreal nos pés. O resto da terra nova fica com
# relevo e campo simples, para ser preenchido depois. Duas pontes de terra largas atravessam o canal até a ilha
# de hoje (tools/vale/pontes_de_terra.py, 2026-11-21), com uma lagoa de água do mar entre elas.
# Grava o que o jogo usa em assets/vale/mapa/ (terra_nova_*.bin e terra_nova_rios.json) e a maquete vista de
# cima em docs/mapa/terra_nova_v1.png.
#   /usr/bin/python3 tools/vale/mapa_terra_nova.py
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage
from scipy.spatial import cKDTree

import pontes_de_terra  # as pontes de terra até a ilha de hoje (o mesmo relevo nas duas grades)

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# o que o jogo usa sai do juntador das duas terras (tools/vale/mapa_mundo.py): ele roda este arquivo com
# MAPA_SAIDA numa pasta à parte e grava em assets/vale/mapa/ o mundo unido. Rodado sozinho, este arquivo chama
# o juntador, que refaz tudo
SAIDA = os.environ.get("MAPA_SAIDA")
if SAIDA is None:
    import subprocess
    import sys
    sys.exit(subprocess.call([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "mapa_mundo.py")]))
P = 4.0
X0, Z0 = -3900.0, -3900.0  # o canto da grade; os blocos de 200 m alinham com a ilha de hoje (±1500)
NX, NZ = 1151, 1101  # x de -3900 a 700, z de -3900 a 500
META_VELHA = 1500.0  # a ilha de hoje é o quadrado de ±1500 m (outro arquivo)
FUNDO = -14.0
PICO = (-2820.0, -2860.0)
ALTURA_PICO = 820.0

zz, xx = np.mgrid[0:NZ, 0:NX].astype(float)
xx = X0 + xx * P
zz = Z0 + zz * P


def ruido(escala, semente):
    r = np.random.default_rng(semente)
    gx = int(NX * P / escala) + 3
    gz = int(NZ * P / escala) + 3
    grade = r.random((gz, gx))
    cx = np.arange(NX) * P / escala
    cz = np.arange(NZ) * P / escala
    ix, iz = cx.astype(int), cz.astype(int)
    fx, fz = cx - ix, cz - iz
    fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
    a, b = grade[np.ix_(iz, ix)], grade[np.ix_(iz, ix + 1)]
    c, d = grade[np.ix_(iz + 1, ix)], grade[np.ix_(iz + 1, ix + 1)]
    fx, fz = fx[None, :], fz[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fz) + (c * (1 - fx) + d * fx) * fz


def fbm(escala, semente, oit=4):
    t = np.zeros((NZ, NX))
    amp, soma = 1.0, 0.0
    for o in range(oit):
        t += ruido(escala / (2 ** o), semente + o * 13) * amp
        soma += amp
        amp *= 0.5
    return t / soma


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def borrar(a, raio):
    k = 2 * raio + 1
    b = np.pad(a, raio, mode="edge")
    c = np.cumsum(np.cumsum(b, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def grade_px(x, z):
    return ((x - X0) / P, (z - Z0) / P)


def amostra(a, x, z):
    """Valor da grade no ponto (bilinear)."""
    fx = np.clip((np.asarray(x) - X0) / P, 0, NX - 1.001)
    fz = np.clip((np.asarray(z) - Z0) / P, 0, NZ - 1.001)
    ix, iz = fx.astype(int), fz.astype(int)
    tx, tz = fx - ix, fz - iz
    return (a[iz, ix] * (1 - tx) + a[iz, ix + 1] * tx) * (1 - tz) + (a[iz + 1, ix] * (1 - tx) + a[iz + 1, ix + 1] * tx) * tz


def curva(pontos, passo=4.0, amp=0.0, onda=200.0, semente=1):
    """Linha suave (Catmull-Rom) pelos pontos, com um serpentear leve, um ponto a cada `passo` metros."""
    p = np.array(pontos, float)
    p = np.vstack([p[0] * 2 - p[1], p, p[-1] * 2 - p[-2]])
    fino = []
    for i in range(1, len(p) - 2):
        a, b, c, d = p[i - 1], p[i], p[i + 1], p[i + 2]
        n = max(2, int(np.linalg.norm(c - b) / 1.0))
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            fino.append(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3))
    fino.append(p[-2])
    fino = np.array(fino)
    seg = np.linalg.norm(np.diff(fino, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    alvo = np.arange(0, s[-1], passo)
    xs = np.interp(alvo, s, fino[:, 0])
    zs = np.interp(alvo, s, fino[:, 1])
    if amp > 0:
        dx, dz = np.gradient(xs), np.gradient(zs)
        nrm = np.hypot(dx, dz) + 1e-6
        r = np.random.default_rng(semente)
        f1, f2 = r.random() * 6.28, r.random() * 6.28
        firme = np.clip(alvo / 120.0, 0, 1) * np.clip((alvo[-1] - alvo) / 120.0, 0, 1)
        off = amp * (np.sin(alvo / onda * 6.28 + f1) * 0.7 + np.sin(alvo / onda * 6.28 * 2.3 + f2) * 0.3) * firme
        xs, zs = xs - dz / nrm * off, zs + dx / nrm * off
    return np.stack([xs, zs], 1)


def perto_da_linha(linha, alcance):
    """Distância de cada ponto da grade à linha e o comprimento andado até o ponto mais perto."""
    seg = np.linalg.norm(np.diff(linha, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    fina_s = np.arange(0, s[-1], 1.0)
    fina = np.stack([np.interp(fina_s, s, linha[:, 0]), np.interp(fina_s, s, linha[:, 1])], 1)
    arv = cKDTree(fina)
    d, i = arv.query(np.stack([xx.ravel(), zz.ravel()], 1), distance_upper_bound=alcance)
    d = d.reshape(NZ, NX)
    i = np.where(np.isfinite(d.ravel()), i, 0).reshape(NZ, NX)
    return np.where(np.isfinite(d), d, 1e9), fina_s[np.clip(i, 0, len(fina_s) - 1)]


# ---------- o contorno (o mesmo do esboço aprovado) ----------
contorno = [(700, -1700), (950, -2300), (900, -3250), (300, -3550), (-500, -3420), (-1300, -3600), (-2200, -3480), (-3000, -3560),
            (-3550, -3100), (-3600, -2300), (-3420, -1500), (-3560, -700), (-3380, -100), (-3000, 160), (-2400, 60), (-1950, 140),
            (-1760, -400), (-1820, -1000), (-1760, -1640), (-1200, -1720), (-400, -1670), (200, -1740)]
LADO_CANAL = set(range(16, 22))


def quebrar(pts, n=16, amp=90.0, sem=5):
    r = np.random.default_rng(sem)
    out = []
    for i in range(len(pts)):
        a, b = np.array(pts[i], float), np.array(pts[(i + 1) % len(pts)], float)
        d = b - a
        nrm = np.array([-d[1], d[0]]) / (np.linalg.norm(d) + 1e-6)
        f1, f2 = r.random() * 6.28, r.random() * 6.28
        k = 0.35 if i in LADO_CANAL else 1.0
        for j in range(n):
            t = j / n
            off = amp * k * (math.sin(t * 6.28 * 0.9 + f1) * 0.7 + math.sin(t * 6.28 * 2.7 + f2) * 0.25 + (r.random() - 0.5) * 0.25) * math.sin(math.pi * t)
            out.append(tuple(a + d * t + nrm * off))
    return out


TRACO = [(-300, -3900), (-331, -3517), (-736, -3226), (-576, -2952), (-533, -2590), (-229, -2590), (-271, -2286), (119, -1850), (300, -1550)]


def quebrar_linha(pts, n=10, amp=35.0, sem=9):
    # cantos arredondados (Chaikin, duas vezes) e ondas suaves para os lados: a costa do corte não fica reta,
    # nem em quina, nem em zigue-zague
    linha = [np.array(p, float) for p in pts]
    for _ in range(2):
        nova = [linha[0]]
        for i in range(len(linha) - 1):
            nova += [linha[i] * 0.75 + linha[i + 1] * 0.25, linha[i] * 0.25 + linha[i + 1] * 0.75]
        nova.append(linha[-1])
        linha = nova
    r = np.random.default_rng(sem)
    out = []
    for i in range(len(linha) - 1):
        a_, b_ = linha[i], linha[i + 1]
        dd = b_ - a_
        nr = np.array([-dd[1], dd[0]]) / (np.linalg.norm(dd) + 1e-6)
        f1, f2 = r.random() * 6.28, r.random() * 6.28
        k = min(1.0, np.linalg.norm(dd) / 200.0)
        for j in range(n):
            t = j / n
            off = amp * k * (math.sin(t * 6.28 * 0.7 + f1) * 0.75 + math.sin(t * 6.28 * 1.9 + f2) * 0.25) * math.sin(math.pi * t)
            out.append(tuple(a_ + dd * t + nr * off))
    out.append(tuple(linha[-1]))
    return out


mascara = Image.new("L", (NX, NZ), 0)
ImageDraw.Draw(mascara).polygon([grade_px(*p) for p in quebrar(contorno)], fill=255)
corte = quebrar_linha(TRACO, n=8, amp=45.0) + [(2000, -1550), (2000, -4300), (-300, -4300)]
ImageDraw.Draw(mascara).polygon([grade_px(*p) for p in corte], fill=0)
terra = np.asarray(mascara) > 127
s = (ndimage.distance_transform_edt(terra) - ndimage.distance_transform_edt(~terra)) * P  # metros terra adentro
s += (fbm(150, 201, 3) - 0.5) * 70
# longe da ilha de hoje (o canal fica com pelo menos 300 m) e da borda dos dados
d_quad = np.hypot(np.maximum(np.abs(xx) - META_VELHA, 0), np.maximum(np.abs(zz) - META_VELHA, 0))
s = np.minimum(s, d_quad - 170.0)
borda = np.minimum.reduce([xx - X0, X0 + (NX - 1) * P - xx, zz - Z0, Z0 + (NZ - 1) * P - zz])
s = np.minimum(s, borda - 160.0)

# ---------- a montanha ----------
dpx, dpz = xx - PICO[0], zz - PICO[1]
d_pico = np.hypot(dpx, dpz)
ang = np.arctan2(dpz, dpx)
# a base não é um círculo: esporões saem em estrela
d_ef = d_pico / (1 + 0.16 * np.sin(5 * ang + 0.7) + 0.08 * np.sin(9 * ang + 2.0) + 0.05 * np.sin(3 * ang + 4.1))
m = np.clip(1 - d_ef / 1500.0, 0, 1)
montanha = ALTURA_PICO * m ** 2.6
# cristas afiadas (arestas) e grotas, mais fortes perto do cume
crista = (1 - np.abs(2 * fbm(240, 211, 5) - 1)) ** 2.5
grota = np.abs(2 * fbm(120, 215, 4) - 1)
montanha += (crista - 0.35) * 190 * m ** 0.9 - (1 - grota) ** 3 * 60 * m ** 0.7


def crista_linha(pontos, alturas, largura, pot=1.6):
    linha = curva(pontos, 6.0)
    d, sv = perto_da_linha(linha, largura * 1.2)
    t = sv / max(1.0, sv.max())
    alt = np.interp(t, np.linspace(0, 1, len(alturas)), alturas)
    return np.clip(1 - d / largura, 0, 1) ** pot * alt


# a serra que segue pelo norte (entre o rio do leste e o mar), o esporão do sul e o do sudeste
serras = crista_linha([(-2650, -3050), (-2100, -3230), (-1500, -3260), (-1000, -3330), (-650, -3330)], [560, 420, 260, 170, 90], 420)
serras = np.maximum(serras, crista_linha([(-2900, -2500), (-3150, -2000), (-3200, -1500), (-3250, -1000)], [520, 330, 190, 90], 380))
serras = np.maximum(serras, crista_linha([(-2620, -2420), (-2420, -2150), (-2250, -1950), (-2050, -1800)], [430, 260, 150, 70], 300))
serras *= 0.8 + 0.4 * fbm(120, 221)
# as serras também ganham cristas e grotas (lisas, de longe pareciam rampas de massa)
forca = np.clip(serras / 250.0, 0, 1)
serras += (crista - 0.35) * 150 * forca - (1 - grota) ** 3 * 55 * forca + (fbm(45, 223, 3) - 0.5) * 30 * forca
# o resto da terra nova: colinas baixas e campo, para preencher depois
colinas = 10 + fbm(340, 231) * 34 + fbm(90, 233) * 7
alto = np.maximum(colinas, np.maximum(montanha, serras) + colinas * 0.4)

# o circo glacial: uma bacia na face leste-sudeste, com o lago no fundo e a geleira atrás
CIRCO = (-2470.0, -2640.0)
d_circo = np.hypot(xx - CIRCO[0], zz - CIRCO[1])
TARN_R = 75.0
chao_circo = float(amostra(alto, CIRCO[0], CIRCO[1])) - 70.0
bacia = 1 - suave(120, 340, d_circo + (fbm(70, 241, 3) - 0.5) * 60)
fundo_circo = chao_circo + (d_circo / 340.0) ** 2 * 240
alto = alto * (1 - bacia) + np.minimum(alto, fundo_circo) * bacia
TARN_NIVEL = chao_circo + 2.0

# ---------- a costa ----------
# perto da montanha a terra cai no mar em falésia; no resto, praia
falesia = np.clip((montanha + serras) / 200.0, 0, 1) * suave(0.45, 0.6, fbm(130, 261, 3) + 0.15)
praia = np.clip(s * 0.10, FUNDO, 3.2)
dentro = praia + (alto - 3.2) * suave(26, 140, s)
parede = FUNDO + (alto - FUNDO) * suave(-10, 18, s)
h = np.where(s < 0, np.maximum(FUNDO, s * 0.12), dentro)
h = h * (1 - falesia) + np.where(s < -10, np.maximum(FUNDO, s * 0.12), parede) * falesia
h = np.maximum(h, FUNDO)
# a praia da ponta leste (área A, pedido do usuário em 2026-11-21): areia larga e quase chata ao longo da costa,
# dunas baixas atrás, e o mar raso por um bom trecho (água clara antes de ficar funda)
PONTA_A = (150.0, -1790.0)
praia_a = 1 - suave(650, 1050, np.hypot(xx - PONTA_A[0], zz - PONTA_A[1]) + (fbm(160, 263, 3) - 0.5) * 220)
duna = (fbm(38, 265, 3) - 0.35) * 7.0 + (fbm(14, 267, 2) - 0.5) * 1.6
faixa_duna = suave(80, 115, s) * (1 - suave(175, 240, s))
h_a = np.where(s < 0, np.maximum(FUNDO, s * 0.045), np.minimum(s * 0.036, 3.2) + np.maximum(duna, 0) * faixa_duna)
h_a = h_a + (alto - h_a) * suave(190, 340, s) * (alto > h_a)
h = h * (1 - praia_a) + h_a * praia_a
h = np.maximum(h, FUNDO)
alto_sem_costa = alto
alto = h  # os rios cavam a terra já com a costa


# ---------- os rios de degelo ----------
LAGOS = []
RIOS = []


SOLEIRA = 26.0  # m além da margem de um lago até a beira da queda da saída (o espelho do jogo passa 18 m da margem)


def soleira(linha, niv, quedas, quedas_k, cx, cz, raio, nivel, k_de):
    """A saída de um lago: o rio sai no nível dele por um canal com soleira e só cai SOLEIRA metros além da margem
    (pedido do usuário, 2026-11-22: o espelho d'água dos lagos passa 18 m da margem, e na saída ele ficava solto em
    cima da queda, com a água cortada; no Turquesa a água ainda descia 16 m numa rampa, sem cortina). As quedas que
    caíam antes saem; a da soleira entra no fim do canal."""
    dl = np.hypot(linha[:, 0] - cx, linha[:, 1] - cz)
    fora = np.nonzero((np.arange(len(linha)) >= k_de) & (dl >= raio + SOLEIRA))[0]
    if len(fora) == 0:
        return
    k2 = int(fora[0])
    for j in reversed(range(len(quedas_k))):
        if k_de <= quedas_k[j] <= k2:
            quedas_k.pop(j)
            quedas.pop(j)
    niv[k_de:k2] = nivel
    if nivel - niv[k2] > 2.5:
        quedas.append([float(linha[k2, 0]), float(linha[k2, 1]), float(nivel), float(niv[k2])])
        quedas_k.append(k2)


def rio(nome, pontos, meia_canal, meia_fita, lago=None, semente=1, inicio=None, saida=None):
    """Um rio do alto até o mar: o nível segue o chão em degraus (trechos quase chatos e quedas), cavando um
    cânion onde o chão desce rápido. Cava o leito e o vale na grade e devolve o curso."""
    global alto
    linha = curva(pontos, 4.0, amp=26.0, onda=230.0, semente=semente)
    chao = borrar(alto, 3)
    g = amostra(chao, linha[:, 0], linha[:, 1])
    sv = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(linha, axis=0), axis=1))])
    # a foz: o primeiro ponto em que o chão (com a costa) chega ao mar
    terra_s = amostra(s, linha[:, 0], linha[:, 1])
    foz = int(np.argmax(terra_s < 0)) if (terra_s < 0).any() else len(linha) - 1
    if inicio is not None:
        g[0] = min(g[0], inicio + 1.5)
    g = np.minimum.accumulate(g)  # o chão nunca sobe rio abaixo
    niv = np.zeros(len(linha))
    n = inicio if inicio is not None else g[0] - 1.5
    degrau = 60.0  # a maior queda d'água de uma vez
    inicio_degrau = 0
    i = 0
    quedas = []
    quedas_k = []  # o ponto da linha em que cada queda cai (a beira fica entre ele e o anterior)
    while i < len(linha):
        # o trecho do degrau: anda até o chão cair `degrau` metros abaixo da água; a água fica no nível do fim
        j = i
        while j < len(linha) - 1 and g[j + 1] > g[i] - degrau and (sv[j + 1] - sv[i]) < 260:
            j += 1
        fim = g[j] - 1.5
        # onde o chão desce devagar (até 16%) a água segue o chão, em corredeira; mais íngreme, vira degrau:
        # um trecho quase chato num cânion e uma queda no começo dele
        if g[i] - g[j] < 8.0 or (g[i] - g[j]) < 0.16 * max(1.0, sv[j] - sv[i]):
            for k in range(i, j + 1):
                niv[k] = min(n - 0.004 * (sv[k] - sv[max(i, k - 1)]), g[k] - 1.5)
                n = niv[k]
        else:
            if (i > 0 or inicio is not None) and n - fim > 2.5:
                quedas.append([float(linha[i, 0]), float(linha[i, 1]), float(n), float(fim)])
                quedas_k.append(i)
            n = fim
            for k in range(i, j + 1):
                niv[k] = n - 0.002 * (sv[k] - sv[i])
            n = niv[j]
        i = j + 1
    niv = np.maximum(niv, 0.05)
    niv[foz:] = 0.05
    if inicio is not None:
        niv[0] = inicio  # a fita começa no nível do lago de onde o rio sai
    # o lago no caminho: o nível do rio fica parado nele
    if lago is not None:
        lx, lz, lr = lago
        dl = np.hypot(linha[:, 0] - lx, linha[:, 1] - lz)
        dentro = dl < lr
        if dentro.any():
            k0 = int(np.argmax(dentro))
            nivel_lago = float(niv[k0])
            k1 = len(dl) - 1 - int(np.argmax(dentro[::-1]))
            niv[k0:k1 + 1] = nivel_lago
            niv[k1 + 1:] = np.minimum(niv[k1 + 1:], nivel_lago)
            LAGOS.append({"x": lx, "z": lz, "raio": lr, "nivel": nivel_lago})
            soleira(linha, niv, quedas, quedas_k, lx, lz, lr, nivel_lago, k1 + 1)
    if saida is not None and inicio is not None:
        soleira(linha, niv, quedas, quedas_k, saida[0], saida[1], saida[2], inicio, 0)
    ordem = np.argsort(quedas_k, kind="stable")
    quedas = [quedas[o] for o in ordem]
    quedas_k = [quedas_k[o] for o in ordem]
    # cava. O fundo do vale acompanha o chão alisado rio abaixo (contínuo, sem os degraus); a água corre num
    # cânion cortado nele, que vai fundo onde o chão desce rápido e termina em cada queda
    piso = np.maximum(ndimage.gaussian_filter1d(g, 15), niv + 0.6)
    d, sl = perto_da_linha(linha, 240.0)
    nl = np.interp(sl, sv, niv)
    # nas quedas o nível é um degrau na beira: até ela a água fica no nível de cima, depois no de baixo (com a
    # linha reta entre os dois a água virava uma rampa que entrava no chão no meio da queda; o jogo pendura uma
    # cortina na beira, `TerraNova._cortina`). Logo depois do pé, um poço mais fundo e mais largo
    poco = np.zeros_like(sl)
    for k in quedas_k:
        nl = np.where((sl >= sv[k - 1]) & (sl < sv[k]), niv[k - 1], nl)
        dd = sl - sv[k]
        poco = np.maximum(poco, np.clip((niv[k - 1] - niv[k]) * 0.15, 2.0, 5.0) * (1 - suave(6, 34, dd)) * (dd > -1.0))
    pl = np.interp(sl, sv, piso)
    frac = np.clip(sl / max(1.0, sv[foz]), 0, 1)
    larg = meia_canal * (0.6 + 0.4 * frac) * (1 + 0.12 * poco)
    # fundo de verdade: de 2,4 m no alto a 3,8 m perto do mar (era de 1,2 a 1,8, raso demais; pedido do usuário,
    # 2026-11-22), mais o poço das quedas
    fundura = 2.4 + 1.4 * frac + poco
    leito = nl - fundura * (1 - (np.clip(d / larg, 0, 1)) ** 2)
    # (era 3 de inclinação: na grade de 4 m a parede virava um pente de listras em pé)
    parede = nl + 0.6 + np.maximum(0, d - larg - 2.0) * 1.7
    # a encosta do vale: suave na planície, íngreme na montanha, e nunca um plano liso (o relevo de antes
    # aparece por cima dela, aos poucos)
    lado = np.maximum(0, d - larg - 10.0)
    encosta = pl + 0.6 + lado * (0.25 + 1.9 * np.clip((alto - pl) / 50.0, 0, 1)) + (fbm(60, 301 + semente, 3) - 0.5) * np.clip(lado / 30.0, 0, 1) * 24.0
    vale = np.where(d < larg, leito, np.minimum(parede, encosta))
    perto = (d < 240) & (sl < sv[foz] + 30)
    nova = np.minimum(alto, vale)
    nova = alto + (nova - alto) * (1 - suave(170, 240, d))
    # na foz o vale se desfaz no mar
    some = suave(sv[foz] - 40, sv[foz] + 6, sl)
    alto = np.where(perto, nova * (1 - some) + alto * some, alto)
    # o leito e as margens seguram a água (pedido do usuário, 2026-11-22: onde o rio corria encosta abaixo de
    # lado, a margem de baixo ficava mais baixa que a água e a fita aparecia solta, com o vazio embaixo). No
    # canal o chão é o leito, cavado ou aterrado; da beira do canal até passar a fita, a margem fica acima do
    # nível e depois desce para o chão de fora. Fora disso: os lagos e a foz
    no_lago = np.zeros_like(d, bool)
    for lg in LAGOS + [{"x": CIRCO[0], "z": CIRCO[1], "raio": TARN_R}]:
        # (só dentro do lago: o canal da saída, que passa da margem até a soleira, também tem leito e margem)
        no_lago |= np.hypot(xx - lg["x"], zz - lg["z"]) < lg["raio"] - 2.0
    trecho = (d < 200) & (sl > 3.0) & (sl < sv[foz] - 35.0) & ~no_lago
    alto = np.where(trecho & (d < larg), leito, alto)
    beira = meia_fita + 3.0
    margem = nl + np.clip((d - larg) * 0.4, 0, 0.7) + np.maximum(0, d - larg - 2.0) * 0.05 - np.maximum(0, d - beira) * 0.9
    alto = np.where(trecho & (d >= larg) & (margem > alto), margem, alto)
    fim_fita = min(len(linha) - 1, foz + 6)
    # na linha que vai para o jogo, um ponto a mais um palmo antes de cada queda, no nível de cima: o nível da
    # água (`Curso.nivel`) vira um degrau na beira, como no chão
    pts_j = [list(map(float, p)) for p in linha[:fim_fita + 1]]
    niv_j = [float(x) for x in niv[:fim_fita + 1]]
    for k in sorted(quedas_k, reverse=True):
        if 0 < k <= fim_fita:
            u = linha[k] - linha[k - 1]
            u = u / max(1e-6, np.linalg.norm(u))
            pts_j.insert(k, [float(linha[k, 0] - u[0] * 0.08), float(linha[k, 1] - u[1] * 0.08)])
            niv_j.insert(k, float(niv[k - 1]))
    RIOS.append({"nome": nome, "pts": np.round(pts_j, 2).tolist(), "niv": np.round(niv_j, 3).tolist(),
                 "canal": meia_canal, "faixa": meia_fita, "quedas": quedas})
    return d, sl, larg


# o rio do leste: do lago do circo, pelo Lago Turquesa, até o mar do leste
LAGO_TURQUESA = (-1480.0, -2745.0, 160.0)
d_r1, s_r1, l_r1 = rio("leste", [(CIRCO[0] + 72, CIRCO[1] - 18), (-2300, -2690), (-2100, -2740), (-1850, -2700), (LAGO_TURQUESA[0], LAGO_TURQUESA[1]),
                                 (-1250, -2790), (-1000, -2700), (-750, -2790), (-560, -2770), (-420, -2770)], 7.0, 16.0, LAGO_TURQUESA, 3, TARN_NIVEL,
                                 (CIRCO[0], CIRCO[1], TARN_R))
# o rio do sul: da neve da face sul, braço do oeste abaixo, até o mar do sul
d_r2, s_r2, l_r2 = rio("sul", [(-2915, -2380), (-2860, -2150), (-2760, -1900), (-2800, -1600), (-2700, -1300), (-2760, -1000), (-2640, -700),
                               (-2700, -400), (-2620, -100), (-2600, 120), (-2600, 320)], 6.0, 14.0, None, 7)

# as bacias dos lagos: fundo em tigela e a margem sempre acima da água (menos onde o rio passa)
LAGOS.insert(0, {"x": CIRCO[0], "z": CIRCO[1], "raio": TARN_R, "nivel": TARN_NIVEL})
for lg in LAGOS:
    dl = np.hypot(xx - lg["x"], zz - lg["z"]) + (fbm(50, 251, 3) - 0.5) * 30
    nv = lg["nivel"]
    r = lg["raio"]
    no_rio = np.minimum(d_r1, d_r2) < 14
    fora = np.maximum(0, dl - r)
    # a encosta que desce até a água nunca é parede (o relevo alto em volta cortado no raio do lago virava um
    # muro listrado), e a margem é uma borda estreita que desce para fora em rampa (era um anel de 60 m na
    # altura do lago, e onde o rio tinha cavado o vale embaixo o lago ficava num pedestal)
    rampa = nv + 1.0 + fora * (0.8 + fbm(70, 253, 3) * 0.5)
    alto = np.where(dl < r + 320, np.minimum(alto, rampa), alto)
    borda = nv + 1.0 + fora * 0.08 - np.maximum(0, fora - 14.0) * 1.1
    alto = np.where((dl > r) & ~no_rio, np.maximum(alto, borda), alto)
    dentro = dl < r
    # o fundo desce com o tamanho do lago: uns 9 m no lago do circo, uns 16 m no Turquesa (era 7,8 m em todos;
    # pedido do usuário, 2026-11-22), com uma beira rasa e o meio fundo
    alto = np.where(dentro, np.minimum(alto, nv - 0.8 - min(16.0, 3.0 + r * 0.08) * (1 - np.clip(dl / r, 0, 1) ** 1.6)), alto)

# ---------- as fontes quentes (área B, pedido do usuário em 2026-11-21) ----------
# Uma bacia rasa no campo a leste do rio do sul: o Olho Azul no meio (a fonte grande, azul no fundo e laranja na
# beira), um monte de sínter de onde a água desce em poças de degrau, fontes médias espalhadas e respiros que só
# soltam vapor. Em volta das águas o chão é mineral branco e laranja; no resto da bacia, brejo.
FONTES_C = (-2150.0, -560.0)
FONTES = []  # {"x", "z", "raio", "nivel", "forca"}
RESPIROS = []  # {"x", "z"}
df = np.hypot(xx - FONTES_C[0], zz - FONTES_C[1]) + (fbm(60, 301, 3) - 0.5) * 110
bacia_f = 1 - suave(170, 300, df)
media_f = float(np.median(alto[(df > 260) & (df < 340)]))
piso_f = media_f - 3.5 + (fbm(28, 303, 3) - 0.5) * 1.0
alto = alto * (1 - bacia_f) + piso_f * bacia_f
# o monte de sínter: uma corcova branca de uns 7 m
MONTE = (FONTES_C[0] - 120.0, FONTES_C[1] + 30.0)
dm = np.hypot(xx - MONTE[0], zz - MONTE[1]) + (fbm(25, 305, 3) - 0.5) * 14
monte = 7.0 * (1 - suave(8, 70, dm)) ** 1.3
alto = alto + monte * bacia_f
rng_f = np.random.default_rng(311)


def fonte(x, z, r, forca):
    FONTES.append({"x": round(x, 2), "z": round(z, 2), "raio": r, "nivel": round(float(amostra(alto, x, z)) + 0.15, 3), "forca": forca})


fonte(FONTES_C[0], FONTES_C[1], 24.0, 1.0)  # o Olho Azul
for dx, dz, r in [(-95, 85, 11.0), (75, -85, 9.0), (115, 70, 7.0), (-35, -125, 10.0), (150, -20, 6.0)]:
    fonte(FONTES_C[0] + dx, FONTES_C[1] + dz, r, 0.7)
fonte(MONTE[0], MONTE[1], 4.0, 0.9)  # a do alto do monte, de onde a água desce
# os degraus: duas fileiras descendo do monte, uma para o meio da bacia e outra para o sul
for ang, n in [(0.25, 5), (1.75, 4)]:
    d = 10.0
    for k in range(n):
        r = 5.6 - k * 0.35
        a = ang + rng_f.uniform(-0.12, 0.12)
        fonte(MONTE[0] + math.cos(a) * d, MONTE[1] + math.sin(a) * d, r, 0.45)
        d += 2 * r + 1.6
# a borda de cada poça (a sínter que represa a água) e a saia em volta; depois a tigela de dentro
for f in FONTES:
    d = np.hypot(xx - f["x"], zz - f["z"])
    perto = d < f["raio"] + 14
    nv, r = f["nivel"], f["raio"]
    beira = (d > r - 0.6) & (d < r + 2.6 + (fbm(9, 307, 2) - 0.5) * 1.4)
    alto = np.where(perto & beira, np.maximum(alto, nv + 0.3), alto)
    saia = (d >= r + 2.0) & perto
    alto = np.where(saia, np.maximum(alto, nv + 0.3 - (d - r - 2.0) * 0.14), alto)
for f in FONTES:
    d = np.hypot(xx - f["x"], zz - f["z"])
    nv, r = f["nivel"], f["raio"]
    alto = np.where(d < r, np.minimum(alto, nv - 0.4 - (1.2 + 0.06 * r) * (1 - (d / r) ** 2)), alto)
# os respiros: montinhos de mineral com um furo, longe das poças
while len(RESPIROS) < 7:
    a = rng_f.uniform(0, 2 * math.pi)
    rr = rng_f.uniform(30, 160)
    x, z = FONTES_C[0] + math.cos(a) * rr, FONTES_C[1] + math.sin(a) * rr
    if all(math.hypot(x - f["x"], z - f["z"]) > f["raio"] + 14 for f in FONTES) and all(math.hypot(x - q["x"], z - q["z"]) > 30 for q in RESPIROS):
        RESPIROS.append({"x": round(x, 2), "z": round(z, 2)})
        d = np.hypot(xx - x, zz - z)
        alto = alto + 0.7 * (1 - suave(0.5, 3.5, d)) - 0.5 * (1 - suave(0, 0.8, d))
# a distância até a beira da água mais perto (para a cobertura)
dist_fonte = np.full((NZ, NX), 1e9)
raio_perto = np.zeros((NZ, NX))
for f in FONTES:
    d = np.hypot(xx - f["x"], zz - f["z"]) - f["raio"]
    menor = d < dist_fonte
    raio_perto = np.where(menor, f["raio"], raio_perto)
    dist_fonte = np.minimum(dist_fonte, d)
dist_respiro = np.full((NZ, NX), 1e9)
for q in RESPIROS:
    dist_respiro = np.minimum(dist_respiro, np.hypot(xx - q["x"], zz - q["z"]))

h = np.maximum(alto, FUNDO)
# as pontes de terra até a ilha de hoje (o mesmo relevo que tools/vale/mapa_3km.py usa do lado de lá)
subiu_pontes = pontes_de_terra.aplicar_altura(h, X0, Z0)

# ---------- cobertura: 0 campo, 1 mata, 2 mata fechada, 3 flores, 4 areia, 5 neve, 6 pedra, 7 campina alpina,
# 8 cascalho do rio, 9 duna (areia com capim ralo), 10 sínter, 11 esteira laranja, 12 brejo ----------
inclin = np.hypot(np.gradient(h, axis=0), np.gradient(h, axis=1)) / P
boreal = 1 - suave(1550, 2200, d_pico + (fbm(300, 271) - 0.5) * 500)
linha_neve = 410 + (fbm(160, 273) - 0.5) * 140 - bacia * 110
linha_arvore = 240 + (fbm(140, 275) - 0.5) * 80
cob = np.zeros((NZ, NX), dtype=np.uint8)
mata_r = fbm(200, 281) + fbm(55, 283) * 0.35
clareiras = fbm(90, 285, 3)
floresta = (boreal > 0.35) & (h > 6) & (h < linha_arvore) & (mata_r + boreal * 0.35 > 0.62) & (clareiras > 0.36)
cob[floresta] = 2
cob[floresta & (mata_r + boreal * 0.35 < 0.72)] = 1
campina_flor = (boreal > 0.35) & (h > 6) & (h < linha_arvore) & (clareiras < 0.30) & (fbm(70, 287, 3) > 0.5)
cob[campina_flor] = 3
cob[(h >= linha_arvore - 30) & (h < linha_neve) & (boreal > 0.2)] = 7
cob[(h >= linha_arvore - 30) & (h < linha_neve) & (boreal > 0.2) & (fbm(45, 289, 3) > 0.62)] = 6  # pedra solta (tálus)
cob[(h >= linha_neve)] = 5
cob[(inclin > 1.0) & (h > 20)] = 6
cob[(inclin > 1.25) & (h > 5)] = 6
# o leito dos rios: cascalho claro nas margens
for d_r, s_r, l_r in [(d_r1, s_r1, l_r1), (d_r2, s_r2, l_r2)]:
    cob[(d_r < l_r + 5 + fbm(40, 291, 3) * 6) & (h > 0.3) & (h < linha_neve)] = 8
cob[(h < 2.6)] = 4
# a praia da ponta: areia larga até o pé das dunas, e as dunas com capim ralo (9)
cob[(praia_a > 0.45) & (s > -2) & (s < 98) & (h < 3.8)] = 4
cob[(praia_a > 0.45) & (s >= 98) & (s < 215) & (h < 10)] = 9
cob[(h >= linha_neve) & (inclin > 1.1)] = 6
# as fontes quentes: brejo na bacia (12), sínter branca perto da água e no monte (10), esteira laranja de
# bactéria rente à água (11)
rf = fbm(14, 309, 3) - 0.5
# a esteira laranja escorre em raios para fora da água (como nas fontes grandes de verdade)
ang_f = np.arctan2(zz - FONTES_C[1], xx - FONTES_C[0])
raios_f = np.sin(ang_f * 23 + rf * 6) * 0.5 + 0.5
sinter = ((dist_fonte < 8 + raio_perto * 0.9 + rf * 10) | (monte > 0.8) | (dist_respiro < 7 + rf * 4)) & (bacia_f > 0.05)
esteira = (dist_fonte < 2.5 + raio_perto * (0.25 + 0.3 * raios_f) + rf * 3) & (bacia_f > 0.05)
manchas_brejo = fbm(70, 313, 3) + rf * 0.3
cob[(bacia_f > 0.25) & (manchas_brejo > 0.5) & ~sinter] = 12
cob[sinter] = 10
cob[esteira] = 11
pontes_de_terra.aplicar_cobertura(cob, subiu_pontes, X0, Z0)
regiao = (np.clip(boreal, 0, 1) * 255).astype(np.uint8)

# ---------- o relevo para os blocos de longe: na beira dos rios e lagos, o mais baixo da vizinhança. Os blocos
# de longe pegam um ponto a cada 8, 20 ou 40 m e passavam por cima dos cânions estreitos, escondendo a água ----------
perto_agua = np.zeros((NZ, NX), dtype=bool)
for d_r, s_r, l_r in [(d_r1, s_r1, l_r1), (d_r2, s_r2, l_r2)]:
    perto_agua |= d_r < l_r + 26
for lg in LAGOS:
    perto_agua |= np.hypot(xx - lg["x"], zz - lg["z"]) < lg["raio"] + 30
for f in FONTES:
    perto_agua |= np.hypot(xx - f["x"], zz - f["z"]) < f["raio"] + 6
h_longe = np.where(perto_agua, ndimage.minimum_filter(h, size=11), h)

os.makedirs(SAIDA, exist_ok=True)
h.astype(np.float32).tofile(SAIDA + "/terra_nova_alturas.bin")
h_longe.astype(np.float32).tofile(SAIDA + "/terra_nova_alturas_longe.bin")
np.stack([cob, regiao], -1).astype(np.uint8).tofile(SAIDA + "/terra_nova_cobertura.bin")
with open(SAIDA + "/terra_nova_rios.json", "w") as f:
    json.dump({"x0": X0, "z0": Z0, "passo": P, "nx": NX, "nz": NZ, "pico": [PICO[0], float(h.max()), PICO[1]],
               "rios": RIOS, "lagos": LAGOS, "fontes": FONTES, "respiros": RESPIROS}, f)

# ---------- a maquete ----------
cor = np.zeros((NZ, NX, 3))
cor[:] = (0.50, 0.70, 0.36)
cor[cob == 0] = np.stack([0.50 + fbm(50, 51) * 0.1, 0.70 + fbm(50, 52) * 0.06, np.full((NZ, NX), 0.36)], -1)[cob == 0]
boreal_c = boreal[..., None]
cor = np.where((cob == 0)[..., None], cor * (1 - boreal_c * 0.25) + np.array([0.30, 0.52, 0.34]) * boreal_c * 0.25, cor)
cor[cob == 1] = (0.20, 0.40, 0.24)
cor[cob == 2] = (0.10, 0.26, 0.20)
pont = np.random.default_rng(7).random((NZ, NX))
cor[(cob == 1) & (pont > 0.86)] = (0.85, 0.65, 0.20)  # álamos dourados
cor[cob == 3] = (0.55, 0.70, 0.40)
cor[(cob == 3) & (pont > 0.8)] = (0.85, 0.45, 0.70)
cor[cob == 7] = (0.56, 0.60, 0.42)
cor[cob == 6] = (0.55, 0.55, 0.56)
cor[cob == 5] = (0.93, 0.95, 0.98)
cor[cob == 8] = (0.74, 0.72, 0.66)
cor[cob == 4] = (0.90, 0.84, 0.64)
cor[cob == 9] = (0.80, 0.78, 0.55)
cor[cob == 10] = (0.92, 0.90, 0.84)
cor[cob == 11] = (0.85, 0.50, 0.15)
cor[cob == 12] = (0.36, 0.38, 0.20)
mar = h < 0.0
raso = np.clip(-h / 14.0, 0, 1)[..., None]
cor = np.where(mar[..., None], np.array([0.42, 0.74, 0.76]) * (1 - raso) + np.array([0.12, 0.33, 0.50]) * raso, cor)
for rr in RIOS:
    pts = np.array(rr["pts"])
    niv = np.array(rr["niv"])
    for (x, z), n in zip(pts, niv):
        if n > 0.1:
            ix, iz = int((x - X0) / P), int((z - Z0) / P)
            k = int(rr["canal"] / P) + 1
            cor[max(0, iz - k):iz + k + 1, max(0, ix - k):ix + k + 1] = (0.25, 0.70, 0.72)
for lg in LAGOS:
    dl = np.hypot(xx - lg["x"], zz - lg["z"])
    cor[(dl < lg["raio"] + 20) & (h < lg["nivel"])] = (0.22, 0.66, 0.70)
for f in FONTES:
    dl = np.hypot(xx - f["x"], zz - f["z"]) / f["raio"]
    cor[dl < 1] = (0.20, 0.55, 0.70)
    cor[dl < 0.5] = (0.08, 0.25, 0.60)
luz = np.clip(1.0 - (np.gradient(h, axis=1) + np.gradient(h, axis=0)) / P * 0.75, 0.5, 1.45)
cor *= np.where(mar, 1.0, luz)[..., None]
nivel = (np.floor(h / 50) != np.floor(np.roll(h, 1, 0) / 50)) | (np.floor(h / 50) != np.floor(np.roll(h, 1, 1) / 50))
cor[nivel & ~mar & (h > 40)] *= 0.85
velho = (np.abs(xx) <= META_VELHA) & (np.abs(zz) <= META_VELHA)
cor[velho] = cor[velho] * 0.35 + 0.25
img = Image.fromarray((np.clip(cor, 0, 1) * 255).astype(np.uint8))
d = ImageDraw.Draw(img)
fonte = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 22)
fp = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 16)


def nome(x, z, t, f=fonte, c=(255, 255, 255)):
    px, pz = grade_px(x, z)
    w = d.textlength(t, font=f)
    d.text((px - w / 2, pz), t, font=f, fill=c, stroke_width=3, stroke_fill=(15, 20, 30))


nome(PICO[0], PICO[1] - 60, "Montanha do Degelo (%d m)" % h.max())
nome(CIRCO[0] + 60, CIRCO[1] + 50, "circo e lago", fp)
nome(LAGO_TURQUESA[0], LAGO_TURQUESA[1] + 160, "Lago Turquesa", fp)
nome(-1000, -2500, "rio do leste", fp)
nome(-2450, -900, "rio do sul", fp)
nome(-500, -1900, "navio encalhado", fp, (255, 230, 170))
nome(FONTES_C[0], FONTES_C[1] + 200, "fontes quentes", fp, (255, 230, 170))
nome(0, 0, "ilha de hoje", fonte, (230, 230, 230))
for q in RIOS:
    for qx, qz, a_, b_ in q["quedas"]:
        px, pz = grade_px(qx, qz)
        d.ellipse((px - 3, pz - 3, px + 3, pz + 3), fill=(255, 255, 255))
img.save(RAIZ + "/docs/mapa/terra_nova_v1.png")
print("ok: pico %.0f m, terra nova %.1f km², lagos %s" % (h.max(), (h > 0).sum() * P * P / 1e6, [(round(l["nivel"]), l["raio"]) for l in LAGOS]))
print("fontes quentes: piso %.1f m, %d poças, %d respiros: %s" % (media_f - 3.5, len(FONTES), len(RESPIROS), [(f["raio"], f["nivel"]) for f in FONTES]))
for q in RIOS:
    nv = q["niv"]
    print("  perfil %s:" % q["nome"], [round(nv[k]) for k in range(0, len(nv), 40)])
for q in RIOS:
    print("rio %s: %.1f km, nasce a %.0f m, %d quedas: %s" % (q["nome"], len(q["pts"]) * 4 / 1000, q["niv"][0], len(q["quedas"]), [round(a - b) for _, _, a, b in q["quedas"]]))
