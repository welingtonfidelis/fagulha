# O desenho das crianças da escola: o Faísca de giz de cera, com elas, o sol e o lago. Material próprio.
import math, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
random.seed(7); np.random.seed(7)
W, H = 700, 500
saida = sys.argv[1]
# papel creme com fibras
papel = np.ones((H, W, 3)) * np.array([246, 240, 226]) / 255.0
ruido = np.random.rand(H, W)
ruido = np.array(Image.fromarray((ruido * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))) / 255.0
papel *= (0.96 + 0.06 * ruido)[..., None]
yy, xx = np.mgrid[0:H, 0:W]
borda = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy)) / 40.0
papel *= (0.93 + 0.07 * np.clip(borda, 0, 1))[..., None]
camada = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(camada)

def tremido(pts, amp=1.6):
    return [(x + random.uniform(-amp, amp), y + random.uniform(-amp, amp)) for x, y in pts]

def risco(pts, cor, larg=7, passes=3):
    for k in range(passes):
        q = tremido(pts, 1.8)
        d.line(q, fill=cor + (215,), width=max(2, larg - k * 2), joint="curve")

def arco(cx, cy, rx, ry, a0, a1, n=28):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

def pintar(pts, cor, larg=5, passo=7, ang=35):
    # rabiscos de preencher dentro de um polígono (a criança pinta pra lá e pra cá)
    mascara = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mascara).polygon(pts, fill=255)
    m = np.array(mascara) > 0
    tmp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dt = ImageDraw.Draw(tmp)
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    diag = int(max(max(xs) - min(xs), max(ys) - min(ys)) * 1.6) + 20
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    for t in range(-diag, diag, passo):
        a = (cx + ca * -diag - sa * t, cy + sa * -diag + ca * t)
        b = (cx + ca * diag - sa * t, cy + sa * diag + ca * t)
        dt.line(tremido([a, b], 2.0), fill=cor + (150,), width=larg)
    arr = np.array(tmp)
    arr[~m] = 0
    camada.alpha_composite(Image.fromarray(arr))

AMARELO = (247, 196, 40); LARANJA = (240, 128, 36); VERMELHO = (214, 58, 52); AZUL = (52, 120, 214)
TURQUESA = (40, 186, 196); VERDE = (76, 168, 70); MARROM = (130, 86, 50); CINZA = (120, 124, 132); ROXO = (140, 84, 190)
PRETO = (52, 48, 56); ROSA = (236, 118, 160)

# o chão e o lago turquesa
risco([(0, 410), (120, 404), (260, 412), (420, 402), (560, 410), (700, 404)], VERDE, 8)
for x in range(10, 700, 26):
    risco([(x, 410), (x + 5, 396)], VERDE, 4, 1)
pintar([(470, 430), (520, 418), (610, 420), (670, 436), (640, 460), (540, 466), (480, 452)], TURQUESA, 6, 8, -10)
risco(arco(570, 441, 100, 23, 0, 360, 40), TURQUESA, 6)
# o sol
pintar(arco(78, 74, 40, 40, 0, 360, 30), AMARELO, 7, 7, 20)
risco(arco(78, 74, 40, 40, 0, 360, 30), LARANJA, 6)
for k in range(10):
    a = math.radians(k * 36 + 8)
    risco([(78 + 52 * math.cos(a), 74 + 52 * math.sin(a)), (78 + 74 * math.cos(a), 74 + 74 * math.sin(a))], AMARELO, 6, 2)
# uma nuvem
risco(arco(600, 170, 30, 18, 180, 360) + arco(646, 174, 26, 20, 220, 380), AZUL, 5, 2)
# a casinha da escola, de teto reto, ao fundo à esquerda
pintar([(40, 400), (40, 300), (150, 300), (150, 400)], (236, 210, 150), 6, 9, 60)
risco([(40, 400), (40, 300), (150, 300), (150, 400)], MARROM, 6)
risco([(30, 300), (160, 300)], VERMELHO, 9)
pintar([(78, 400), (78, 352), (110, 352), (110, 400)], MARROM, 5, 7, 90)
pintar([(52, 318), (52, 342), (70, 342), (70, 318)], AZUL, 4, 6, 0)
pintar([(120, 318), (120, 342), (138, 342), (138, 318)], AZUL, 4, 6, 0)

# o Faísca no meio: cabeça redonda-quadrada, olhões, antena com a faísca, corpo, braços para cima
cx = 340
pintar([(cx - 62, 248), (cx + 62, 248), (cx + 62, 360), (cx - 62, 360)], LARANJA, 7, 8, 40)
risco([(cx - 62, 248), (cx + 62, 248), (cx + 62, 360), (cx - 62, 360), (cx - 62, 248)], MARROM, 6)
pintar(arco(cx, 300, 22, 22, 0, 360, 20), AMARELO, 5, 6, 0)  # o coração aceso no peito
risco(arco(cx, 300, 22, 22, 0, 360, 20), VERMELHO, 4, 2)
pintar([(cx - 52, 150), (cx + 52, 150), (cx + 56, 236), (cx - 56, 236)], (190, 196, 206), 7, 8, -30)
risco([(cx - 52, 150), (cx + 52, 150), (cx + 56, 236), (cx - 56, 236), (cx - 52, 150)], PRETO, 6)
for ex in (-24, 24):
    pintar(arco(cx + ex, 186, 15, 17, 0, 360, 18), (255, 255, 255), 5, 5, 0)
    risco(arco(cx + ex, 186, 15, 17, 0, 360, 18), PRETO, 5, 2)
    pintar(arco(cx + ex + 3, 189, 6, 7, 0, 360, 12), PRETO, 4, 4, 0)
risco(arco(cx, 208, 22, 12, 20, 160, 14), PRETO, 5, 2)  # o sorriso
risco([(cx, 150), (cx + 4, 118)], PRETO, 5, 2)  # a antena
for k in range(8):  # a faísca da antena
    a = math.radians(k * 45)
    risco([(cx + 4 + 8 * math.cos(a), 108 + 8 * math.sin(a)), (cx + 4 + 24 * math.cos(a), 108 + 24 * math.sin(a))], LARANJA if k % 2 else AMARELO, 5, 2)
risco([(cx - 62, 268), (cx - 100, 236), (cx - 120, 196)], CINZA, 8)  # braços para cima
risco([(cx + 62, 268), (cx + 100, 236), (cx + 120, 196)], CINZA, 8)
for hx in (cx - 120, cx + 120):
    risco(arco(hx, 188, 10, 10, 0, 360, 12), CINZA, 6, 2)
risco([(cx - 34, 360), (cx - 34, 404)], CINZA, 9)  # as pernas
risco([(cx + 34, 360), (cx + 34, 404)], CINZA, 9)
risco([(cx - 56, 406), (cx - 22, 406)], PRETO, 9)
risco([(cx + 22, 406), (cx + 56, 406)], PRETO, 9)
# faíscas em volta (ele soltava faísca quando ria)
for (sx, sy, r) in [(232, 150, 14), (450, 136, 12), (210, 250, 10), (474, 240, 13), (262, 96, 9), (420, 92, 10)]:
    for k in range(4):
        a = math.radians(k * 45 + 22)
        risco([(sx - r * math.cos(a), sy - r * math.sin(a)), (sx + r * math.cos(a), sy + r * math.sin(a))], AMARELO if k % 2 else LARANJA, 4, 2)

# as crianças de mãos dadas, à direita do Faísca
def crianca(x, cor, cabelo, saia=False):
    risco(arco(x, 300, 15, 16, 0, 360, 16), MARROM if cabelo == MARROM else PRETO, 5, 2)
    risco(arco(x, 292, 16, 10, 190, 350, 10), cabelo, 7, 2)
    risco([(x - 5, 300), (x - 5, 301)], PRETO, 4, 1); risco([(x + 5, 300), (x + 5, 301)], PRETO, 4, 1)
    risco(arco(x, 304, 7, 5, 20, 160, 8), VERMELHO, 3, 1)
    if saia:
        pintar([(x, 318), (x + 22, 368), (x - 22, 368)], cor, 5, 6, 70)
        risco([(x, 318), (x + 22, 368), (x - 22, 368), (x, 318)], cor, 5, 2)
    else:
        pintar([(x - 13, 318), (x + 13, 318), (x + 13, 362), (x - 13, 362)], cor, 5, 6, 70)
        risco([(x - 13, 318), (x + 13, 318), (x + 13, 362), (x - 13, 362), (x - 13, 318)], cor, 5, 2)
    risco([(x - 7, 366), (x - 9, 404)], PRETO, 5, 2)
    risco([(x + 7, 366), (x + 9, 404)], PRETO, 5, 2)
    return (x - 13, 332), (x + 13, 332)

maos = []
for x, cor, cab, saia in [(520, VERMELHO, AMARELO, True), (580, AZUL, MARROM, False), (640, ROXO, PRETO, True)]:
    maos.append(crianca(x, cor, cab, saia))
for i in range(len(maos) - 1):
    risco([maos[i][1], (maos[i][1][0] + 17, 340), maos[i + 1][0]], ROSA, 4, 2)

# FAÍSCA em letras de forma, com risco de giz
def letra(ch, x, y, h=58, cor=AZUL):
    w = h * 0.62
    if ch == "F":
        risco([(x, y + h), (x, y), (x + w, y)], cor); risco([(x, y + h * 0.48), (x + w * 0.75, y + h * 0.48)], cor)
    elif ch == "A":
        risco([(x, y + h), (x + w / 2, y), (x + w, y + h)], cor); risco([(x + w * 0.22, y + h * 0.6), (x + w * 0.78, y + h * 0.6)], cor)
    elif ch == "I":
        risco([(x + w / 2, y), (x + w / 2, y + h)], cor); risco([(x + w * 0.62, y - 22), (x + w * 0.38, y - 10)], cor, 5, 2)
    elif ch == "S":
        risco(arco(x + w / 2, y + h * 0.25, w / 2, h * 0.25, 340, 90 + 180 - 360 + 360 - 0, 1), cor, 1, 1)
        pts = arco(x + w / 2, y + h * 0.25, w / 2, h * 0.25, -20, -270 + 0, 16)
        pts = arco(x + w / 2, y + h * 0.25, w / 2, h * 0.25, 330, 90 + 0, 16)
        top = arco(x + w / 2, y + h * 0.25, w / 2, h * 0.25, -30, -270, 16)
        bot = arco(x + w / 2, y + h * 0.75, w / 2, h * 0.25, -90, 150, 16)
        risco(top + bot, cor)
    elif ch == "C":
        risco(arco(x + w / 2 + 4, y + h / 2, w / 2 + 4, h / 2, -50, -310, 22), cor)
    return x + w + 22

x = 214
for ch in "FAISCA":
    x = letra(ch, x, 22 if ch != "I" else 22)
img = Image.fromarray((np.clip(papel, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
# a cera falha no grão do papel
graos = np.random.rand(H, W)
arr = np.array(camada).astype(np.float32)
arr[..., 3] *= np.where(graos > 0.82, 0.35, 1.0)
img.alpha_composite(Image.fromarray(arr.clip(0, 255).astype(np.uint8)))
img.convert("RGB").resize((560, 400), Image.LANCZOS).save(saida)
print("ok", saida)
