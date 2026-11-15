# Maquete do vale maior (2026-11-15): mapa visto de cima, 2 km × 2 km, com a clareira atual no meio.
# Lugares pedidos pelo usuário: serra com vista, platô de flores perto da praia, mata fechada com cachoeira
# e ruínas tomadas pelo mato. Sem estradas.
# blender -b --factory-startup -P tools/vale/mapa_vale.py -- <saida.png>
import math
import sys

import blf
import bpy
import imbuf
import numpy as np

SAIDA = sys.argv[sys.argv.index("--") + 1]
N = 1000  # pixels de lado; x cresce para leste, z cresce para sul (como no jogo)
E = 2.0  # metros por pixel (mapa de 2 km)
META = N // 2
rng = np.random.default_rng(7)


def ruido(escala, semente):
    """Ruído de valor suave, 0 a 1, com `escala` metros por célula."""
    r = np.random.default_rng(semente)
    g = int(N * E / escala) + 3
    grade = r.random((g, g))
    c = np.arange(N) * E / escala
    i = c.astype(int)
    f = c - i
    f = f * f * (3 - 2 * f)
    a = grade[np.ix_(i, i)]
    b = grade[np.ix_(i, i + 1)]
    cc = grade[np.ix_(i + 1, i)]
    d = grade[np.ix_(i + 1, i + 1)]
    fx = f[None, :]
    fz = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fz) + (cc * (1 - fx) + d * fx) * fz


def fbm(escala, semente, oit=4):
    t = np.zeros((N, N))
    amp, soma = 1.0, 0.0
    for o in range(oit):
        t += ruido(escala / (2 ** o), semente + o * 13) * amp
        soma += amp
        amp *= 0.5
    return t / soma


zz, xx = np.mgrid[0:N, 0:N].astype(float)
xx = (xx - META) * E
zz = (zz - META) * E


def morro(cx, cz, raio, pot=2.0):
    d = np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2) / raio
    return np.clip(1 - d, 0, 1) ** pot


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ---------- relevo ----------
h = 14 + fbm(260, 1) * 22 + fbm(60, 5) * 5
# serra a noroeste, com um cume e uma crista
serra = morro(-560, -620, 620, 1.5) * 230 + morro(-680, -740, 240, 1.2) * 90 + morro(-300, -760, 300, 1.4) * 70
h += serra * (0.75 + 0.5 * fbm(90, 9))
# degrau da cachoeira: a serra desce num paredão para a mata a nordeste
# platô de flores a leste: topo chato a 30 m, com borda de falésia baixa
dp = np.sqrt(((xx - 640) / 1.3) ** 2 + (zz - 120) ** 2) + (fbm(140, 21) - 0.5) * 150
plato = 1 - suave(250, 300, dp)
h = h * (1 - plato) + (38 + fbm(60, 22) * 3.0) * plato
# o mar: a terra afunda para o sul e para o leste
costa = np.maximum(suave(540, 940, zz + (fbm(280, 31) - 0.5) * 340 + xx * 0.25), suave(790, 1000, xx + (fbm(240, 33) - 0.5) * 170))
h -= costa * 60 * (1 - plato * 0.75)
# a clareira do jogo fica como está: campo aberto e baixo no meio
clareira = morro(0, 10, 150, 0.8)
h = h * (1 - clareira * 0.55) + 19.5 * clareira * 0.55

# ---------- riacho: desce a serra, cai na cachoeira, cruza a clareira e sai no mar ----------
RIACHO = [(-520, -660), (-380, -600), (-300, -520), (-260, -380), (-180, -200), (-96, -70), (-60, -48), (-34, -40), (-12, -22),
          (8, -18), (26, -6), (34, -2), (70, 60), (150, 190), (260, 380), (320, 560), (340, 760), (350, 900)]
CACHOEIRA = (-300, -520)
dist_rio = np.full((N, N), 1e9)
for (ax, az), (bx, bz) in zip(RIACHO[:-1], RIACHO[1:]):
    vx, vz = bx - ax, bz - az
    t = np.clip(((xx - ax) * vx + (zz - az) * vz) / (vx * vx + vz * vz), 0, 1)
    dist_rio = np.minimum(dist_rio, np.sqrt((xx - ax - vx * t) ** 2 + (zz - az - vz * t) ** 2))
lagoa = np.sqrt((xx - 34) ** 2 + (zz + 2) ** 2) < 14
poco = np.sqrt((xx - CACHOEIRA[0] - 16) ** 2 + (zz - CACHOEIRA[1] - 26) ** 2) < 26

# ---------- cobertura ----------
mata = fbm(220, 41) + fbm(60, 43) * 0.4
fechada = (morro(60, -600, 520, 0.7) + morro(-280, -480, 260, 0.9)) * (0.75 + 0.5 * fbm(160, 45))  # mata fechada ao norte, em volta da cachoeira
ruinas_m = morro(-660, 300, 300, 0.8)
aberto = np.maximum(clareira * 1.2, plato * 1.5) + morro(-100, 520, 320, 1.0) * 0.5 + morro(300, -150, 240, 1.0) * 0.35
arvores = (mata + fechada * 0.9 + ruinas_m * 0.35 - aberto - costa * 1.2) > 0.72
arv_fechada = arvores & (fechada > 0.35)
mar = h < 0
praia = (h >= 0) & (h < 3.2)
rocha = (serra > 150) | ((np.abs(np.gradient(h, axis=0)) + np.abs(np.gradient(h, axis=1))) / E > 1.7)

cor = np.zeros((N, N, 3))
campo = np.stack([0.50 + fbm(50, 51) * 0.12, 0.70 + fbm(50, 52) * 0.08, 0.36 + fbm(50, 53) * 0.06], -1)
cor[:] = campo
cor[arvores] = (0.20, 0.42, 0.22)
cor[arv_fechada] = (0.10, 0.28, 0.20)
pont = rng.random((N, N))
cor[arvores & (pont > 0.72)] *= 0.8  # copas
cor[rocha & ~arvores] = (0.62, 0.63, 0.62)
cor[praia] = (0.90, 0.84, 0.64)
fundo = np.clip(-h / 60, 0, 1)[..., None]
cor = np.where(mar[..., None], np.array([0.30, 0.62, 0.70]) * (1 - fundo) + np.array([0.10, 0.30, 0.48]) * fundo, cor)
# flores no platô
flor = (plato > 0.6) & ~mar
cor[flor & (pont > 0.86)] = (0.95, 0.55, 0.70)
cor[flor & (pont < 0.10)] = (0.98, 0.86, 0.35)
cor[flor & (pont > 0.45) & (pont < 0.50)] = (0.75, 0.55, 0.95)
# água doce
cor[(dist_rio < 5.0) & ~mar] = (0.32, 0.60, 0.78)
cor[lagoa | poco] = (0.26, 0.52, 0.72)
# luz de relevo
gx = np.gradient(h, axis=1) / E
gz = np.gradient(h, axis=0) / E
luz = np.clip(1.0 - (gx * 0.6 + gz * 0.6) * 0.16, 0.6, 1.35)
cor *= np.where(mar, 1.0, luz)[..., None]
# curvas de nível a cada 25 m
nivel = (np.floor(h / 50) != np.floor(np.roll(h, 1, 0) / 50)) | (np.floor(h / 50) != np.floor(np.roll(h, 1, 1) / 50))
cor[nivel & ~mar & (h > 24)] *= 0.82


def px(x, z):
    return int(x / E + META), int(z / E + META)


def bloco(x, z, w, d, c):
    """Retângulo com canto em (x, z) e lados w × d, tudo em metros."""
    a, b = px(x, z)
    cor[b:b + max(1, int(d / E)), a:a + max(1, int(w / E))] = c


# ruínas: muros quebrados e um arco, entre as árvores
for (rx, rz, w, d) in [(-720, 240, 70, 8), (-720, 248, 8, 60), (-676, 284, 8, 26), (-644, 220, 46, 8), (-612, 336, 76, 8),
                       (-580, 300, 8, 36), (-700, 356, 30, 8), (-636, 380, 8, 30), (-744, 320, 14, 14), (-600, 244, 14, 14),
                       (-560, 380, 40, 8), (-770, 400, 8, 40), (-690, 430, 60, 8)]:
    bloco(rx, rz, w, d, (0.78, 0.76, 0.70))
# cachoeira
a, b = px(*CACHOEIRA)
cor[b - 2:b + 14, a + 3:a + 8] = (0.95, 0.98, 1.0)
# a área que já existe no jogo: quadrado tracejado de 320 m
for k in range(-160, 160, 20):
    for (x0, z0, w, d) in [(k, -160, 12, 4), (k, 156, 12, 4), (-160, k, 4, 12), (156, k, 4, 12)]:
        bloco(x0, z0, w, d, (1.0, 1.0, 1.0))

# ---------- dados para o jogo: relevo e cobertura, um ponto a cada 4 m (501 × 501) ----------
if len(sys.argv) > sys.argv.index("--") + 2:
    import os
    pasta = sys.argv[sys.argv.index("--") + 2]
    os.makedirs(pasta, exist_ok=True)
    idx = np.minimum(np.arange(501) * 2, N - 1)
    hj = np.maximum(h, -14.0)[np.ix_(idx, idx)].astype("<f4")  # o fundo do mar não passa de 14 m
    cob = np.zeros((N, N), np.uint8)  # 0 campo, 1 mata, 2 mata fechada, 3 flores, 4 areia
    cob[arvores] = 1
    cob[arv_fechada] = 2
    cob[flor] = 3
    cob[praia | mar] = 4
    hj.tofile(os.path.join(pasta, "alturas.bin"))
    cob[np.ix_(idx, idx)].tofile(os.path.join(pasta, "cobertura.bin"))
    print("dados em", pasta, "altura de %.1f a %.1f" % (hj.min(), hj.max()))

# ---------- folha: mapa + legenda ----------
LARG = 430
tela = np.zeros((N + 40, N + LARG + 60, 4), np.float32)
tela[..., :3] = (0.09, 0.10, 0.11)
tela[..., 3] = 1
tela[20:20 + N, 20:20 + N, :3] = np.clip(cor, 0, 1)[::-1]
H, W = tela.shape[:2]
out = bpy.data.images.new("mapa", W, H, alpha=False)
out.pixels[:] = tela.ravel()
out.filepath_raw = SAIDA
out.file_format = "PNG"
out.save()
LUGARES = [
    (1, -640, -700, "Serra do Mirante", "O ponto mais alto, com vista do vale inteiro e do mar."),
    (2, -230, -500, "Cachoeira", "O riacho cai da serra num poço, no meio da mata fechada."),
    (3, 160, -620, "Mata fechada", "Árvores altas e juntas, luz filtrada, pouco capim."),
    (4, 0, 110, "Clareira", "A área que já existe (quadrado tracejado, 320 m): campo, lagoa, bichos."),
    (5, 640, 120, "Platô das flores", "Campo alto e chato, florido, acima da praia."),
    (6, 560, 560, "Praia", "Areia e mar raso. O riacho deságua aqui."),
    (7, -650, 320, "Ruínas", "Muros e arcos tomados pelo mato. De onde as máquinas vêm."),
    (8, -100, 540, "Campos do sul", "Capim aberto e ondulado até o mar; bom para correr e voar baixo."),
]
fb = blf.load("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
fr = blf.load("/System/Library/Fonts/Supplemental/Arial.ttf")
ib = imbuf.load(SAIDA)
with blf.bind_imbuf(fb, ib), blf.bind_imbuf(fr, ib):
    for n, x, z, nome, desc in LUGARES:
        ax, bz = int(20 + x / E + META), int(20 + (N - (z / E + META)))
        for dx, dy, c in ((2, -2, (0, 0, 0, 1)), (0, 0, (1, 1, 1, 1))):
            blf.size(fb, 34)
            blf.color(fb, *c)
            blf.position(fb, ax - 10 + dx, bz - 12 + dy, 0)
            blf.draw_buffer(fb, str(n))
    x0 = N + 50
    y = H - 60
    blf.size(fb, 30)
    blf.color(fb, 0.95, 0.95, 0.92, 1)
    blf.position(fb, x0, y, 0)
    blf.draw_buffer(fb, "O vale maior (maquete)")
    y -= 34
    blf.size(fr, 17)
    blf.color(fr, 0.75, 0.78, 0.80, 1)
    blf.position(fr, x0, y, 0)
    blf.draw_buffer(fr, "2 km × 2 km · norte para cima · sem estradas")
    y -= 50
    for n, x, z, nome, desc in LUGARES:
        blf.size(fb, 22)
        blf.color(fb, 0.95, 0.95, 0.92, 1)
        blf.position(fb, x0, y, 0)
        blf.draw_buffer(fb, "%d. %s" % (n, nome))
        y -= 26
        blf.size(fr, 16)
        blf.color(fr, 0.78, 0.80, 0.82, 1)
        palavras, linha = desc.split(" "), ""
        for p in palavras:
            if len(linha) + len(p) > 46:
                blf.position(fr, x0, y, 0)
                blf.draw_buffer(fr, linha)
                y -= 21
                linha = ""
            linha += p + " "
        blf.position(fr, x0, y, 0)
        blf.draw_buffer(fr, linha)
        y -= 40
    blf.size(fr, 15)
    blf.color(fr, 0.6, 0.62, 0.64, 1)
    for i, l in enumerate(["Curvas de nível a cada 50 m.", "Verde-escuro: mata. Verde-claro: campo.", "Azul-claro: riacho, lagoa e poço."]):
        blf.position(fr, x0, 90 - i * 22, 0)
        blf.draw_buffer(fr, l)
imbuf.write(ib, filepath=SAIDA)
print("ok", SAIDA, W, H, "altura max %.0f" % h.max())
