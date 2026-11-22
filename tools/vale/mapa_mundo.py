# O mapa do mundo inteiro (2026-11-21): roda os dois geradores (tools/vale/mapa_3km.py, a ilha de hoje, e
# tools/vale/mapa_terra_nova.py, a terra nova), junta as duas grades na grade do mundo, une as duas terras numa
# só com costa natural (tools/vale/terra_unida.py) e grava o que o jogo usa em assets/vale/mapa/ nas mesmas
# duas grades de antes (a da ilha de hoje, ±1500 m, e a da terra nova), com o mesmo valor onde elas se
# encontram. A maquete do mundo vai para docs/mapa/mundo_v1.png.
#   /usr/bin/python3 tools/vale/mapa_mundo.py   (rodar um dos dois geradores sozinho também chama este)
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import terra_unida as tu

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
DESTINO = RAIZ + "/assets/vale/mapa"
VN = 751  # a grade da ilha de hoje: 751 x 751, de -1500 a 1500
V0 = 600  # onde ela começa na grade do mundo
TNX, TNZ = 1151, 1101  # a da terra nova: x de -3900 a 700, z de -3900 a 500 (começa no canto do mundo)

# as duas terras como os geradores fazem, numa pasta à parte
base = tempfile.mkdtemp(prefix="mapa_mundo_")
for g in ("mapa_3km.py", "mapa_terra_nova.py"):
    r = subprocess.run([sys.executable, os.path.join(AQUI, g)], env=dict(os.environ, MAPA_SAIDA=base))
    if r.returncode != 0:
        shutil.rmtree(base, ignore_errors=True)
        sys.exit("o gerador %s falhou" % g)
velho = np.fromfile(base + "/alturas.bin", np.float32).reshape(VN, VN)
vcob = np.fromfile(base + "/cobertura.bin", np.uint8).reshape(VN, VN)
tn = np.fromfile(base + "/terra_nova_alturas.bin", np.float32).reshape(TNZ, TNX)
tn_longe = np.fromfile(base + "/terra_nova_alturas_longe.bin", np.float32).reshape(TNZ, TNX)
tcob = np.fromfile(base + "/terra_nova_cobertura.bin", np.uint8).reshape(TNZ, TNX, 2)
with open(base + "/terra_nova_rios.json") as f:
    info = json.load(f)

# a grade do mundo: o fundo do mar, a terra nova e, por cima, a ilha de hoje
N = tu.N
h = np.full((N, N), tu.FUNDO)
cob = np.full((N, N), 4, np.uint8)
h[:TNZ, :TNX] = tn
cob[:TNZ, :TNX] = tcob[..., 0]
h[V0:V0 + VN, V0:V0 + VN] = velho
cob[V0:V0 + VN, V0:V0 + VN] = vcob

hn, cn, mudou, nova = tu.juntar(h, cob, info["rios"], info["lagos"], info["fontes"])
hn, mudou = tu.aprofundar(h, hn)
cn = np.where((hn < 0) & (cn != 4) & ~np.isin(cn, [6, 8]), 4, cn).astype(np.uint8)

# de volta às duas grades
v_h = hn[V0:V0 + VN, V0:V0 + VN].astype(np.float32)
v_c = cn[V0:V0 + VN, V0:V0 + VN].copy()
v_c[v_c > 4] = 0  # a ilha de hoje só conhece campo, mata, mata fechada, flores e areia (a pedra sai da inclinação)
t_h = hn[:TNZ, :TNX].astype(np.float32)
t_mudou = mudou[:TNZ, :TNX]
t_longe = np.where(t_mudou, t_h, tn_longe).astype(np.float32)
t_c = tcob.copy()
t_c[..., 0] = cn[:TNZ, :TNX]
os.makedirs(DESTINO, exist_ok=True)
v_h.tofile(DESTINO + "/alturas.bin")
v_c.tofile(DESTINO + "/cobertura.bin")
t_h.tofile(DESTINO + "/terra_nova_alturas.bin")
t_longe.tofile(DESTINO + "/terra_nova_alturas_longe.bin")
t_c.tofile(DESTINO + "/terra_nova_cobertura.bin")
shutil.copy(base + "/terra_nova_rios.json", DESTINO + "/terra_nova_rios.json")
shutil.rmtree(base, ignore_errors=True)

# ---------- a maquete do mundo ----------
gx, gz = np.gradient(hn, axis=1), np.gradient(hn, axis=0)
luz = np.clip(1 + (-gx - gz) * 0.035 * 3, 0.55, 1.35)
cor = np.zeros((N, N, 3))
for lim, c in [(-1e9, (0.36, 0.58, 0.34)), (67.5, (0.30, 0.46, 0.27)), (120, (0.48, 0.45, 0.40)), (420, (0.93, 0.94, 0.96))]:
    cor[hn >= lim] = c
cor[(cn == 1) & (hn < 120)] = (0.25, 0.42, 0.22)
cor[(cn == 2) & (hn < 120)] = (0.17, 0.33, 0.16)
cor[cn == 5] = (0.93, 0.94, 0.96)
cor[cn == 6] = (0.48, 0.47, 0.45)
cor[(cn == 4) & (hn < 4)] = (0.86, 0.80, 0.62)
cor = cor * luz[..., None]
fundo = np.clip(-hn / 40, 0, 1)[..., None]
agua = np.array([0.55, 0.80, 0.88]) * (1 - fundo) + np.array([0.30, 0.55, 0.72]) * fundo
cor = np.where((hn < 0)[..., None], agua, cor)
img = Image.fromarray((np.clip(cor, 0, 1) * 255).astype(np.uint8))
d = ImageDraw.Draw(img)
fonte = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 16)
for nome, x, z in tu.LUGARES:
    p = ((x - tu.W0) / tu.P, (z - tu.W0) / tu.P)
    d.ellipse((p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4), fill=(20, 90, 95), outline=(255, 255, 255), width=2)
    d.text((p[0] + 7, p[1] - 9), nome, fill=(20, 30, 30), font=fonte, stroke_width=2, stroke_fill=(255, 255, 255))
img.save(RAIZ + "/docs/mapa/mundo_v1.png")
print("mundo: terra %.2f km² (antes %.2f km²), %d pontos mudaram" % ((hn > 0).sum() * 16e-6, (h > 0).sum() * 16e-6, mudou.sum()))
