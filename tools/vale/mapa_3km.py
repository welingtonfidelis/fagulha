# Relevo da ilha de 3 km (2026-11-18): a ilha atual de 2 km fica no meio, como está, e ganha em volta a
# costa orgânica e as regiões novas (Costa Quebrada, Encostas do Dique, Cabo do Vento, Arquipélago Raso,
# a chapada da Fenda Escura). Lê o relevo de 2 km em docs/mapa/2km/ (501 x 501, 4 m) e grava o que o jogo
# usa em assets/vale/mapa/ (751 x 751, 4 m) e a maquete vista de cima em docs/mapa/.
#   /usr/bin/python3 tools/vale/mapa_3km.py
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import pontes_de_terra  # as pontes de terra até a terra nova (o mesmo relevo nas duas grades)

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# o que o jogo usa sai do juntador das duas terras (tools/vale/mapa_mundo.py): ele roda este arquivo com
# MAPA_SAIDA numa pasta à parte e grava em assets/vale/mapa/ o mundo unido. Rodado sozinho, este arquivo chama
# o juntador, que refaz tudo
SAIDA = os.environ.get("MAPA_SAIDA")
if SAIDA is None:
    import subprocess
    import sys
    sys.exit(subprocess.call([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "mapa_mundo.py")]))
N = 751
P = 4.0
META = 1500.0
VN = 501
VMETA = 1000.0
FUNDO = -14.0  # o fundo do mar do jogo

zz, xx = np.mgrid[0:N, 0:N].astype(float)
xx = xx * P - META
zz = zz * P - META


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


def fbm(escala, semente, oit=4):
    t = np.zeros((N, N))
    amp, soma = 1.0, 0.0
    for o in range(oit):
        t += ruido(escala / (2 ** o), semente + o * 13) * amp
        soma += amp
        amp *= 0.5
    return t / soma


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def morro(cx, cz, raio, pot=2.0):
    d = np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2) / raio
    return np.clip(1 - d, 0, 1) ** pot


def dist_linha(pontos):
    """Distância à linha quebrada e a posição ao longo dela (0 a 1)."""
    melhor = np.full((N, N), 1e9)
    onde = np.zeros((N, N))
    comp = [math.dist(a, b) for a, b in zip(pontos[:-1], pontos[1:])]
    total, ac = sum(comp), 0.0
    for (ax, az), (bx, bz), c in zip(pontos[:-1], pontos[1:], comp):
        vx, vz = bx - ax, bz - az
        t = np.clip(((xx - ax) * vx + (zz - az) * vz) / (vx * vx + vz * vz), 0, 1)
        d = np.sqrt((xx - ax - vx * t) ** 2 + (zz - az - vz * t) ** 2)
        perto = d < melhor
        onde = np.where(perto, (ac + t * c) / total, onde)
        melhor = np.where(perto, d, melhor)
        ac += c
    return melhor, onde


def borrar(a, raio):
    """Média numa janela quadrada de lado 2*raio+1 (em pontos)."""
    k = 2 * raio + 1
    b = np.pad(a, raio, mode="edge")
    c = np.cumsum(np.cumsum(b, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def maior_perto(a, raio):
    """O maior valor numa janela quadrada de lado 2*raio+1 (em pontos)."""
    for eixo in (0, 1):
        m = a.copy()
        for k in range(1, raio + 1):
            m = np.maximum(m, np.roll(a, k, eixo))
            m = np.maximum(m, np.roll(a, -k, eixo))
        a = m
    return a


# ---------- a ilha de hoje, no meio ----------
velho = np.fromfile(RAIZ + "/docs/mapa/2km/alturas.bin", dtype=np.float32).reshape(VN, VN).astype(float)
vcob = np.fromfile(RAIZ + "/docs/mapa/2km/cobertura.bin", dtype=np.uint8).reshape(VN, VN)
ix = np.clip(((xx + VMETA) / P).round().astype(int), 0, VN - 1)
iz = np.clip(((zz + VMETA) / P).round().astype(int), 0, VN - 1)
velho_e = velho[iz, ix]  # fora dos 2 km, repete o valor da borda
vcob_e = vcob[iz, ix]
fora = np.maximum(np.abs(xx), np.abs(zz)) - VMETA  # metros para fora do mapa antigo
t_fora = suave(0.0, 300.0, fora + (fbm(200, 61) - 0.5) * 160)
# fora dos 2 km o valor repetido da borda é alisado, para não deixar listras
base = np.where(fora > 0, borrar(velho_e, 14), velho_e)
# perto do mar antigo, a terra baixa (a praia de hoje) cede lugar à terra nova onde ela for mais alta
perto_mar = suave(0.0, 0.08, borrar((velho_e < 0.5).astype(float), 30))
firme = 1 - perto_mar * (1 - suave(4.0, 16.0, base))  # 1: vale a ilha de hoje

# ---------- a costa nova ----------
ang = np.arctan2(zz, xx)  # 0 leste, +90° sul
r = np.sqrt(xx * xx + zz * zz)
p = 2.7
R = 1290.0 / (np.abs(np.cos(ang)) ** p + np.abs(np.sin(ang)) ** p) ** (1 / p)
R += 70 * np.sin(ang * 3 + 0.7) + 50 * np.sin(ang * 5 + 2.1) + 30 * np.sin(ang * 9 + 4.0)
# o leste e o sudeste recuam, para as ilhotas caberem no mar
graus = np.degrees(ang)
R -= 190 * suave(-28, 8, graus) * (1 - suave(52, 80, graus))
s = R - r  # metros terra adentro
s += (fbm(260, 71) - 0.5) * 230
# Costa Quebrada: o sudeste recortado em baías e pontas
quebrada = suave(-5, 25, graus) * (1 - suave(72, 100, graus))
s += (fbm(150, 73, 3) - 0.5) * 260 * quebrada


def baia(cx, cz, raio):
    global s
    s = np.minimum(s, np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2) - raio)


def ilhota(cx, cz, raio):
    global s
    d = np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2) + (fbm(60, int(cx + cz) % 97 + 3, 3) - 0.5) * 50
    s = np.maximum(s, raio - d)


# a baía da Foz do Riacho continua sendo mar, alargando para o sul
d_foz, t_foz = dist_linha([(330, 600), (395, 800), (330, 1040), (450, 1500)])
s = np.minimum(s, d_foz - (105 + 170 * t_foz + (fbm(140, 77, 3) - 0.5) * 120))
baia(960, 1010, 150)  # a baía do cais
baia(1140, 520, 120)
baia(-1300, 330, 190)  # enseada do oeste
baia(-250, -1350, 200)  # enseada do norte
baia(-1180, -1080, 170)  # enseada do noroeste
baia(-330, 1380, 160)  # enseada do sul
# Cabo do Vento: a ponta nordeste avança
d_cabo, t_cabo = dist_linha([(820, -900), (1080, -1090), (1310, -1290)])
s = np.maximum(s, 300 - 190 * t_cabo - d_cabo + (fbm(130, 75, 3) - 0.5) * 110)
# Arquipélago Raso
ILHOTAS = [(1265, 640, 78), (1330, 905, 52), (1180, 1150, 64)]
for cx, cz, raio in ILHOTAS:
    ilhota(cx, cz, raio)

# ---------- o relevo novo ----------
alto = 15 + fbm(300, 1) * 22 + fbm(70, 5) * 5
# a serra continua para o norte e o oeste
serra = morro(-560, -620, 620, 1.5) * 230 + morro(-680, -740, 240, 1.2) * 90 + morro(-300, -760, 300, 1.4) * 70
alto += serra * (0.75 + 0.5 * fbm(90, 9))
# Cabo do Vento: sobe até o penhasco da ponta
cabo = morro(1230, -1240, 560, 0.9)
alto += cabo * 58
# Encostas do Dique: pedra quebrada descendo para o mar do leste
dique = suave(640, 800, xx) * suave(-700, -560, zz) * (1 - suave(-120, 10, zz))
crista = np.abs(fbm(110, 81, 4) - 0.5) * 2
alto += dique * (26 * (1 - suave(760, 1180, xx)) + (1 - crista) * 20)
# a lagoa da represa e o córrego que sai dela para o mar. A lagoa fica toda em terra nova (na primeira
# versão encostava na costa antiga, que é mais baixa, e a água vazaria para o oeste). Nível 26 m; a represa
# fecha a garganta do leste e o córrego nasce ao pé dela, a 12 m, e desce 6% até o mar.
LAGOA = (1010, -335, 80)
LAGOA_NIVEL = 26.0
REPRESA_X = 1102.0
d_lag = np.sqrt((xx - LAGOA[0]) ** 2 + (zz - LAGOA[1]) ** 2)
# o morro em volta: a borda da lagoa fica bem acima da água em toda a volta
borda_lag = suave(LAGOA[2] + 150, LAGOA[2] + 20, d_lag)
alto = np.maximum(alto, (LAGOA_NIVEL + 12 + fbm(80, 83) * 10) * borda_lag)
bacia = 1 - suave(LAGOA[2] - 26, LAGOA[2] + 8, d_lag)
# (o meio descia 7 m; agora 14, com a beira rasa igual: pedido do usuário, 2026-11-22, "tudo é muito raso")
alto = alto * (1 - bacia) + (LAGOA_NIVEL - 14.0 + 12.0 * suave(25, LAGOA[2], d_lag)) * bacia
CORREGO = [(REPRESA_X + 2, -333), (1150, -318), (1200, -338), (1250, -300), (1300, -285), (1380, -270)]
d_cor, t_cor = dist_linha(CORREGO)
leito = 12.0 * (1 - np.clip(t_cor / 0.72, 0, 1)) ** 1.15 - 1.0
vale_c = 1 - suave(7, 60, d_cor)
alto = np.where(xx > REPRESA_X, alto * (1 - vale_c) + np.minimum(alto, leito + 2.0) * vale_c, alto)
# a garganta onde a represa fica: entre a lagoa e o pé da represa o chão desce da lagoa ao córrego
garganta = (xx > LAGOA[0] + 40) & (xx <= REPRESA_X) & (np.abs(zz + 335) < 26)
alto = np.where(garganta, np.minimum(alto, LAGOA_NIVEL - 3.0), alto)
# Costa Quebrada: terra baixa, com degraus de pedra
alto = alto * (1 - quebrada * 0.45 * suave(350, 600, zz + xx * 0.3))
# a chapada do sudoeste, que a Fenda Escura corta
chapada = suave(0.25, 0.6, morro(-830, 1090, 520, 0.8) + (fbm(160, 91) - 0.5) * 0.3)
alto = alto * (1 - chapada) + (58 + fbm(90, 92) * 6) * chapada
FENDA = [(-1090, 960), (-960, 1010), (-860, 1100), (-730, 1120), (-610, 1200), (-520, 1300)]
d_fen, t_fen = dist_linha(FENDA)
piso = 6.0 - 5.0 * t_fen
alto = np.where(d_fen < 60, np.minimum(alto, piso + (alto - piso) * suave(7, 30, d_fen)), alto)

# da praia para dentro; nos penhascos a terra já começa alta
penhasco = np.clip(cabo * 1.6 + dique * suave(1000, 1150, xx) * 0.7 + chapada * 0.9 + quebrada * suave(0.52, 0.62, fbm(120, 95)) * 0.6, 0, 1)
praia = np.clip(s * 0.10, FUNDO, 3.2)
dentro = praia + (alto - 3.2) * suave(26, 120, s)
parede = FUNDO + (alto - FUNDO) * suave(-10, 16, s)
novo = np.where(s < 0, np.maximum(FUNDO, s * 0.12), dentro)
novo = novo * (1 - penhasco) + np.where(s < -10, np.maximum(FUNDO, s * 0.12), parede) * penhasco
# piscinas naturais na Costa Quebrada: bacias rasas logo atrás da linha da costa
pocas = quebrada * suave(0.52, 0.60, fbm(70, 97, 3)) * suave(8, 30, s) * (1 - suave(110, 170, s))  # eram poucas: só uma aparecia
# o fundo acompanha o tamanho: piscina pequena é rasa (0,7 m); no meio de uma grande chega a uns 7 m
# (o usuário achou o lago grande perto do cais raso demais para o tamanho dele, 2026-11-19)
miolo = suave(0.35, 0.95, borrar(pocas, 9))
novo = novo * (1 - pocas) + (-0.7 - 6.5 * miolo) * pocas
# o fundo raso entre as ilhotas e a costa (bancos de areia)
for cx, cz, raio in ILHOTAS:
    banco = morro(cx, cz, 330, 1.0)
    novo = np.where(novo < 0, np.maximum(novo, -14 + 12.5 * banco), novo)

# junto da terra de hoje a terra nova não pode nascer muito mais alta: sobe aos poucos, sem degrau
# (medido: sem isto as Encostas e a chapada subiam 45 m em 60 m, um paredão reto ao longo da costa antiga)
novidade = suave(0.12, 0.92, borrar(borrar((base < 4.0).astype(float), 40), 20))
vizinho = np.maximum(base, borrar(np.maximum(base, 0.0), 25))
novo = np.minimum(novo, vizinho + 4.0 + 75.0 * novidade ** 1.5 + 400.0 * t_fora ** 2)
sobe = base + np.clip(novo - base, 0, None) * (1 - firme)  # dentro dos 2 km a terra nova só levanta, nunca cava
h = sobe * (1 - t_fora) + novo * t_fora
# onde o chão ficou como está hoje (menos a faixa colada na borda antiga, cuja cobertura era a última linha
# dos dados e deixava árvores em fila)
velho_vale = (fora <= -40) & (np.abs(h - velho_e) < 1.5)
# a fenda também corta o que sobrou do mapa antigo no caminho
h = np.where(d_fen < 60, np.minimum(h, piso + (h - piso) * suave(7, 30, d_fen)), h)
h = np.maximum(h, FUNDO)
# as pontes de terra do oeste e do noroeste (2026-11-21), que levam à terra nova
subiu_pontes = pontes_de_terra.aplicar_altura(h, -META, -META)

# ---------- cobertura: 0 campo, 1 mata, 2 mata fechada, 3 flores, 4 areia ----------
mata = fbm(220, 41) + fbm(60, 43) * 0.4
fechada = morro(60, -1050, 520, 0.7) * (0.8 + 0.4 * fbm(160, 45))
sem_mata = cabo * 1.4 + quebrada * 0.5 + dique * 0.35 + (s < 60) * 1.0
arv = (mata + fechada * 0.9 + morro(-1200, 0, 420, 0.8) * 0.3 - sem_mata) > 0.74
cob = np.zeros((N, N), dtype=np.uint8)
cob[arv] = 1
cob[arv & (fechada > 0.3)] = 2
cob[velho_vale] = vcob_e[velho_vale]
# a mata de hoje continua pela terra nova ao lado dela (senão acabava numa linha reta, onde era a costa)
vizinha = borrar(borrar(((vcob_e == 1) | (vcob_e == 2)).astype(float) * (fora <= 0), 22), 10)
antiga_areia = (cob == 4) & (h > 3.4)
cob[antiga_areia] = 0  # areia antiga que ficou longe do mar vira campo
# (a faixa de areia antiga conta como terra nova: era ela que deixava a linha reta)
cob[(vizinha * (0.4 + 1.5 * fbm(110, 47)) > 0.2) & (~velho_vale | antiga_areia) & (s > 50) & (cob == 0)] = 1
cob[(h < 2.6) & (h > FUNDO + 0.05)] = 4
cob[(h <= FUNDO + 0.05)] = 4  # o fundo do mar é areia (com campo, o mar mudava de cor na borda dos dados)
inclin = np.hypot(np.gradient(h, axis=0), np.gradient(h, axis=1)) / P
cob[(inclin > 0.9) & (cob != 4)] = np.where(velho_vale, cob, 0)[(inclin > 0.9) & (cob != 4)]
pontes_de_terra.aplicar_cobertura(cob, subiu_pontes, -META, -META)

h.astype(np.float32).tofile(SAIDA + "/alturas.bin")
cob.tofile(SAIDA + "/cobertura.bin")

# ---------- a maquete ----------
cor = np.zeros((N, N, 3))
cor[:] = np.stack([0.50 + fbm(50, 51) * 0.12, 0.70 + fbm(50, 52) * 0.08, 0.36 + fbm(50, 53) * 0.06], -1)
pont = np.random.default_rng(7).random((N, N))
cor[cob == 1] = (0.22, 0.44, 0.22)
cor[cob == 2] = (0.11, 0.30, 0.20)
cor[((cob == 1) | (cob == 2)) & (pont > 0.7)] *= 0.82
cor[cob == 3] = (0.62, 0.72, 0.40)
cor[(cob == 3) & (pont > 0.84)] = (0.95, 0.55, 0.70)
cor[(cob == 3) & (pont < 0.10)] = (0.98, 0.86, 0.35)
rocha = (inclin > 0.75) & (h > 3)
cor[rocha] = (0.60, 0.61, 0.60)
cor[cob == 4] = (0.90, 0.84, 0.64)
mar = h < 0.0
raso = np.clip(-h / 14.0, 0, 1)[..., None]
cor = np.where(mar[..., None], np.array([0.42, 0.74, 0.76]) * (1 - raso) + np.array([0.12, 0.33, 0.50]) * raso, cor)
agua_doce = ((d_lag < LAGOA[2] - 4) & (h < LAGOA_NIVEL)) | ((d_cor < 5) & (xx > REPRESA_X) & ~mar)
cor[agua_doce] = (0.28, 0.55, 0.76)
luz = np.clip(1.0 - (np.gradient(h, axis=1) + np.gradient(h, axis=0)) / P * 0.75, 0.55, 1.4)
cor *= np.where(mar, 1.0, luz)[..., None]
nivel = (np.floor(h / 25) != np.floor(np.roll(h, 1, 0) / 25)) | (np.floor(h / 25) != np.floor(np.roll(h, 1, 1) / 25))
cor[nivel & ~mar & (h > 20)] *= 0.86

K = 2  # pixels por ponto
img = Image.fromarray((np.clip(cor, 0, 1) * 255).astype(np.uint8)).resize((N * K, N * K), Image.LANCZOS)
d = ImageDraw.Draw(img)
fonte = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
f_reg, f_lug, f_peq = ImageFont.truetype(fonte, 30), ImageFont.truetype(fonte, 22), ImageFont.truetype(fonte, 18)


def px(x, z):
    return ((x + META) / P * K, (z + META) / P * K)


# o contorno do mapa de hoje
a, b = px(-VMETA, -VMETA), px(VMETA, VMETA)
for i in range(0, int(b[0] - a[0]), 18):
    for (x0, y0, x1, y1) in ((a[0] + i, a[1], a[0] + i + 9, a[1]), (a[0] + i, b[1], a[0] + i + 9, b[1]), (a[0], a[1] + i, a[0], a[1] + i + 9), (b[0], a[1] + i, b[0], a[1] + i + 9)):
        d.line((x0, y0, x1, y1), fill=(255, 255, 255), width=2)

REGIOES = [("Mata Fechada", 140, -600, 0), ("Serra do Mirante", -564, -700, 0), ("Platô das Flores", 640, 60, 0), ("Campos do Sul", -100, 480, 0),
           ("Clareira", 0, -40, 0), ("COSTA QUEBRADA", 800, 700, 1), ("ENCOSTAS DO DIQUE", 960, -520, 1), ("CABO DO VENTO", 1120, -1060, 1),
           ("ARQUIPÉLAGO RASO", 1150, 1340, 1), ("Chapada do Sudoeste", -830, 990, 1)]
LUGARES = [("Cachoeira", -290, -485, 0), ("O Sumidouro", -312, -600, 0), ("A Fundição", -580, -270, 0), ("As Colunas", 420, -600, 0),
           ("A Árvore-Mãe", 660, 110, 0), ("O Anel", -190, 600, 0), ("Foz do Riacho", 327, 589, 0), ("Os Arcos", -730, 30, 0),
           ("O Pátio das Máquinas", -680, 170, 0), ("A Torre Caída", -640, 440, 0), ("Base", -4, 44, 0),
           ("O Cais Submerso", 930, 960, 1), ("A Ilha do Relé", 1265, 640, 1), ("A Represa Rachada", 1102, -335, 1),
           ("O Farol Apagado", 1300, -1290, 1), ("O Sono dos Gigantes", 470, 400, 1), ("A Fenda Escura", -800, 1110, 1)]
for nome, x, z, novo_l in REGIOES:
    cx, cy = px(x, z)
    w = d.textlength(nome, font=f_reg)
    d.text((cx - w / 2, cy - 15), nome, font=f_reg, fill=(255, 226, 140) if novo_l else (255, 255, 255), stroke_width=4, stroke_fill=(10, 14, 26))
for nome, x, z, novo_l in LUGARES:
    cx, cy = px(x, z)
    c = (255, 150, 60) if novo_l else (255, 255, 255)
    d.regular_polygon((cx, cy, 8), 4, rotation=45, fill=c, outline=(10, 14, 26))
    w = d.textlength(nome, font=f_lug)
    d.text((cx - w / 2, cy + 10), nome, font=f_lug, fill=c, stroke_width=3, stroke_fill=(10, 14, 26))
d.line((40, N * K - 50, 40 + 500 / P * K, N * K - 50), fill=(255, 255, 255), width=5)
d.text((40, N * K - 42), "500 m · norte para cima · tracejado: o mapa de hoje · em laranja e amarelo: o que é novo", font=f_peq, fill=(255, 255, 255), stroke_width=3, stroke_fill=(10, 14, 26))
img.save(RAIZ + "/docs/mapa/maquete_3km_v1.png")
terra = (h > 0).sum() * P * P / 1e6
print("ok: altura máx %.0f m, terra %.2f km² (hoje %.2f km²)" % (h.max(), terra, ((velho > 0).sum() * 16) / 1e6))
