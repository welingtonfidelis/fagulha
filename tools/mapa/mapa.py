# Maquete do mapa feito à mão (2026-11-14). As formas são postas à mão (contorno da ilha, cânions por
# linhas, lago, terras altas, pilares); o script só transforma isso num mapa de alturas e numa imagem.
# O mesmo mapa de alturas (mapa_alturas.npy, um ponto a cada 4 m) é a base do mundo no jogo.
# blender -b --factory-startup -P tools/mapa/mapa.py -- <pasta_de_saida>
import math
import os
import sys

import blf
import bpy
import imbuf
import numpy as np

SAIDA = sys.argv[sys.argv.index("--") + 1]
os.makedirs(SAIDA, exist_ok=True)
N = 1025  # 1025 pontos = 1024 quadrados de 4 m
KM = 4.0  # lado do mundo
PX = KM * 1000.0 / (N - 1)

lin = np.arange(N) * KM / (N - 1)
X, Y = np.meshgrid(lin, lin)  # km; Y cresce para o norte


def ondas(x, y, f, s):
    return (np.sin(x * f + s) * np.cos(y * f * 1.3 + s * 2.1) + np.sin((x + y) * f * 0.7 + s * 3.3) * 0.6
            + np.sin(x * f * 2.3 - y * f * 1.9 + s) * 0.35) / 1.95


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def dist_linha(pontos):
    """Distância (m) de cada ponto do mapa à linha, e a posição 0..1 ao longo dela."""
    xw = X + 0.045 * ondas(X, Y, 11.0, 2.0)
    yw = Y + 0.045 * ondas(Y, X, 12.0, 6.0)
    melhor = np.full(X.shape, 1e9)
    onde = np.zeros(X.shape)
    comp = [math.dist(pontos[i], pontos[i + 1]) for i in range(len(pontos) - 1)]
    total = sum(comp)
    acum = 0.0
    for i in range(len(pontos) - 1):
        ax, ay = pontos[i]
        bx, by = pontos[i + 1]
        dx, dy = bx - ax, by - ay
        t = np.clip(((xw - ax) * dx + (yw - ay) * dy) / (dx * dx + dy * dy), 0, 1)
        d = np.hypot(xw - (ax + t * dx), yw - (ay + t * dy)) * 1000.0
        m = d < melhor
        melhor = np.where(m, d, melhor)
        onde = np.where(m, (acum + t * comp[i]) / total, onde)
        acum += comp[i]
    return melhor, onde


# ------------------------------------------------------------------ o desenho à mão (km)
LAGO = (1.72, 2.22, 0.30)  # x, y, raio
NIVEL_LAGO = 40.0
CANIONS = {
    # nome: (linha, largura do fundo em m, altura do fundo no começo e no fim)
    "garganta": ([(1.76, 1.95), (1.92, 1.55), (1.62, 1.12), (1.76, 0.72), (1.56, 0.34), (1.60, 0.05)], 42, 30, 2),
    "fenda_oeste": ([(0.45, 2.52), (0.95, 2.34), (1.40, 2.26)], 24, 150, 132),
    "rio_alto": ([(2.95, 3.05), (2.50, 2.66), (2.03, 2.41)], 22, 330, 140),
    "braco_leste": ([(3.45, 1.62), (2.70, 1.38), (1.98, 1.47)], 30, 46, 24),
}
VALE_PILARES = (1.63, 1.10, 0.20)  # alarga a garganta aqui
PILARES = [(1.56, 1.16, 16, 150), (1.68, 1.08, 20, 185), (1.60, 1.00, 14, 120), (1.74, 1.17, 13, 105), (1.52, 1.05, 12, 92),
           (1.86, 1.66, 15, 160), (1.72, 0.58, 14, 130), (1.60, 2.02, 16, 120), (1.95, 2.24, 14, 100), (2.42, 1.42, 13, 120)]
LOCAIS = [
    (1, "Platô da Chegada", 1.38, 0.86),
    (2, "A Garganta", 1.80, 1.50),
    (3, "Vale dos Pilares", 1.63, 1.10),
    (4, "Lago Suspenso", 1.72, 2.22),
    (5, "Queda do Véu", 1.47, 2.25),
    (6, "Terras Altas", 2.95, 3.00),
    (7, "Bosque Colossal", 0.85, 1.50),
    (8, "Braço Leste", 2.75, 1.40),
    (9, "Costa dos Paredões", 1.58, 0.22),
]
RUINAS = [("Arco", 1.76, 0.72), ("Anel", 1.93, 2.33), ("Tubo", 2.95, 1.47), ("Farol antigo", 0.80, 1.02), ("Ponte caída", 2.25, 2.52)]

# ------------------------------------------------------------------ alturas
ang = np.arctan2(Y - 2.0, X - 2.0)
raio = np.hypot(X - 2.0, Y - 2.0)
contorno = 1.72 + 0.16 * np.sin(ang * 3 + 0.6) + 0.10 * np.sin(ang * 5 + 2.0) + 0.06 * np.sin(ang * 9 + 1.1) + 0.05 * ondas(X, Y, 9, 4)
# andares: o platô varia de ~90 a ~230 m e é cortado em degraus de 55 m (paredões entre os andares)
h = 160 + 75 * ondas(X, Y, 1.5, 1.0) + 22 * ondas(X, Y, 4.2, 5.0)
h += 330 * np.exp(-((X - 2.95) ** 2 + (Y - 3.0) ** 2) / (2 * 0.48 ** 2))  # terras altas
q = h / 55.0 + 0.12 * ondas(X, Y, 9.0, 3.0)
h = 55.0 * (np.floor(q) + suave(0.36, 0.64, q - np.floor(q))) + 6 * ondas(X, Y, 8.0, 7.0)
h += 60 * np.exp(-((X - 0.85) ** 2 + (Y - 1.5) ** 2) / (2 * 0.38 ** 2))  # morro do bosque
dl = np.hypot(X - LAGO[0], Y - LAGO[1])
h = np.where(dl < LAGO[2] * 1.5, np.minimum(h, NIVEL_LAGO - 12 + suave(LAGO[2] * 0.94, LAGO[2] * 1.12, dl) * 200), h)
plato = h.copy()
rio = np.zeros(X.shape, bool)
agua = np.full(X.shape, -1000.0)
for nome, (linha, larg, f0, f1) in CANIONS.items():
    d, t = dist_linha(linha)
    w = np.full(X.shape, float(larg))
    if nome == "garganta":
        w = w + 150 * np.exp(-((X - VALE_PILARES[0]) ** 2 + (Y - VALE_PILARES[1]) ** 2) / (2 * VALE_PILARES[2] ** 2))
    fundo = f0 + (f1 - f0) * t
    w = w * (1 + 0.45 * ondas(X, Y, 14, 2.0))
    h = np.minimum(h, fundo + np.maximum(0, d - w) * 6.5)
    leito = (d < np.minimum(w * 0.35, 14)) & (plato > fundo + 4)
    h = np.where(leito, h - 1.6, h)
    agua = np.where(leito, fundo - 0.5, agua)
    rio |= leito
for (px, py, r, alt) in PILARES:
    dp = np.hypot(X - px, Y - py) * 1000
    h = np.maximum(h, np.where(dp < r * 1.4, 20 + alt * (1 - suave(r * 0.8, r * 1.3, dp)), -99))
# costa: paredão curto e mar
fora = raio - contorno
h = np.where(fora > 0, np.minimum(h, 120 - fora * 1000 * 4.0), h)
h = np.maximum(h, -30)
mar = h < 0.5
lago = (dl < LAGO[2] * 1.4) & (h < NIVEL_LAGO) & ~mar
agua = np.where(lago, NIVEL_LAGO, agua)
agua = np.where(mar, 0.0, agua)
# para o jogo: linha 0 = norte (z = -2048), x cresce para leste; metros
JOGO = os.environ.get("JOGO")
if JOGO:
    import json
    os.makedirs(JOGO, exist_ok=True)
    h[::-1].astype("<f4").tofile(os.path.join(JOGO, "alturas.bin"))
    agua[::-1].astype("<f4").tofile(os.path.join(JOGO, "agua.bin"))

    def mundo(px, py):
        return [round((px - KM / 2) * 1000, 1), round(-(py - KM / 2) * 1000, 1)]

    dados = {"n": N, "esp": PX, "nivel_lago": NIVEL_LAGO, "lago": mundo(LAGO[0], LAGO[1]) + [LAGO[2] * 1000],
             "locais": [{"nome": nome, "p": mundo(px, py)} for _, nome, px, py in LOCAIS],
             "ruinas": [{"nome": nome, "p": mundo(px, py)} for nome, px, py in RUINAS],
             "quedas": [{"de": mundo(*CANIONS[k][0][-1]), "alto": CANIONS[k][3]} for k in ("fenda_oeste", "rio_alto")],
             "bosque": mundo(0.85, 1.5), "pilares": [mundo(px, py) + [r, alt] for px, py, r, alt in PILARES]}
    json.dump(dados, open(os.path.join(JOGO, "dados.json"), "w"), ensure_ascii=False, indent=1)

# ------------------------------------------------------------------ pintura
gy, gx = np.gradient(h, PX)
incl = np.degrees(np.arctan(np.hypot(gx, gy)))


def cor(r, g, b):
    return np.array([r, g, b]) / 255.0


img = np.zeros(X.shape + (3,))
mata = suave(-0.15, 0.35, ondas(X, Y, 5.0, 8.0) + 0.25 * ondas(X, Y, 15, 3))
img[:] = cor(64, 92, 46)
img = img * (1 - mata[..., None]) + cor(30, 58, 36) * mata[..., None]
alto = suave(330, 450, h)[..., None]
img = img * (1 - alto) + cor(120, 118, 104) * alto
rocha = suave(30, 48, incl)[..., None]
img = img * (1 - rocha) + cor(82, 84, 92) * rocha
fundo_c = ((plato - h) > 35)[..., None] & ~rocha.astype(bool)
img = np.where(fundo_c & (rocha < 0.3), cor(36, 66, 44), img)
luz = np.array([-0.55, 0.55, 0.63])
nrm = np.stack([-gx * 1.6, -gy * 1.6, np.ones_like(h)], -1)
nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
sombra = np.clip(nrm @ luz, 0, 1)
img *= (0.38 + 0.80 * sombra)[..., None]
prof = np.clip(-h / 30, 0, 1)[..., None]
img = np.where(mar[..., None], cor(40, 78, 96) * (1 - prof) + cor(18, 36, 54) * prof, img)
img = np.where(lago[..., None], cor(52, 110, 118), img)
img = np.where((rio & ~mar & ~lago)[..., None], cor(70, 130, 140), img)


def disco(px, py, r_px, c):
    yy, xx = np.ogrid[:N, :N]
    cx, cy = px / KM * N, py / KM * N
    img[(xx - cx) ** 2 + (yy - cy) ** 2 < r_px ** 2] = c


for n, nome, px, py in LOCAIS:
    disco(px, py, 13, cor(18, 20, 24))
    disco(px, py, 11, cor(238, 232, 214))
for nome, px, py in RUINAS:
    disco(px, py, 7, cor(18, 20, 24))
    disco(px, py, 5, cor(255, 150, 60))
# régua de 500 m
img[N - 34:N - 29, 30:30 + int(500 / PX)] = cor(238, 232, 214)

# ------------------------------------------------------------------ folha com legenda
N = 1025
LARG = N + 380
folha = np.zeros((N, LARG, 4), np.float32)
folha[..., :3] = cor(20, 23, 27)
folha[..., 3] = 1
folha[:, :N, :3] = img[::-1][::-1]  # linha 0 = sul (o Blender grava de baixo para cima)
saida_png = os.path.join(SAIDA, "maquete_mapa.png")
im = bpy.data.images.new("mapa", LARG, N, alpha=False)
im.pixels[:] = folha.ravel()
im.filepath_raw = saida_png
im.file_format = "PNG"
im.save()
ib = imbuf.load(saida_png)
fb = blf.load("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
fr = blf.load("/System/Library/Fonts/Supplemental/Arial.ttf")


def txt(f, x, y, s, tam, c):
    blf.size(f, tam)
    blf.color(f, c[0], c[1], c[2], 1.0)
    blf.position(f, x, y, 0)
    blf.draw_buffer(f, s)


with blf.bind_imbuf(fb, ib), blf.bind_imbuf(fr, ib):
    for n, nome, px, py in LOCAIS:
        txt(fb, px / KM * N - 5, py / KM * N - 6, str(n), 16, (0.07, 0.08, 0.09))
    x0 = N + 28
    y = N - 50
    txt(fb, x0, y, "Maquete do mapa", 24, (0.95, 0.94, 0.9))
    y -= 26
    txt(fr, x0, y, "4 × 4 km · feito à mão", 15, (0.7, 0.72, 0.72))
    y -= 44
    for n, nome, px, py in LOCAIS:
        txt(fb, x0, y, "%d" % n, 17, (0.93, 0.91, 0.84))
        txt(fr, x0 + 26, y, nome, 17, (0.9, 0.9, 0.88))
        y -= 28
    y -= 16
    txt(fb, x0, y, "Ruínas antigas (pontos laranja)", 15, (1.0, 0.6, 0.25))
    y -= 26
    for nome, px, py in RUINAS:
        txt(fr, x0 + 12, y, "· " + nome, 15, (0.85, 0.85, 0.83))
        y -= 23
    y -= 16
    for linha in ["Verde-escuro: mata fechada", "Cinza: paredões e rocha", "Azul-claro: rios e lago", "Régua no alto: 500 m"]:
        txt(fr, x0, y, linha, 14, (0.65, 0.67, 0.67))
        y -= 22
imbuf.write(ib, filepath=saida_png)
print("MAPA OK", saida_png, "altura máx %.0f m" % h.max())
