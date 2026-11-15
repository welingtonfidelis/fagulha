# Maquetes das ruínas do vale (2026-11-15): três ideias para o usuário escolher.
# Pedra clara gasta, tomada pelo musgo, com restos de metal das máquinas antigas. Formas simples, no estilo do vale.
# blender -b --factory-startup -P tools/vale/ruinas.py -- <saida.png> [escala]
import math
import os
import sys

import blf
import bmesh
import bpy
import imbuf
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SAIDA = os.path.abspath(argv[0])
ESC = float(argv[1]) if len(argv) > 1 else 1.0
PW, PH = int(560 * ESC), int(560 * ESC)
TMP = os.path.join(os.path.dirname(SAIDA), "_paineis")
os.makedirs(TMP, exist_ok=True)
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)
scene = bpy.context.scene
col = scene.collection


def mat_pbr(nome, cor, metal=0.0, rug=0.6):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = cor + (1,)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rug
    return m


def mat_luz(nome, cor, forca):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    p.inputs["Emission Color"].default_value = cor + (1,)
    p.inputs["Emission Strength"].default_value = forca
    return m


CASCO = mat_pbr("casco", (0.13, 0.15, 0.17), 0.3, 0.6)
CASCO2 = mat_pbr("casco_claro", (0.33, 0.31, 0.26), 0.1, 0.7)
FERRUGEM = mat_pbr("ferrugem", (0.28, 0.13, 0.07), 0.2, 0.8)
JUNTA = mat_pbr("junta", (0.04, 0.045, 0.05), 0.5, 0.45)
MUSGO = mat_pbr("musgo", (0.13, 0.26, 0.08), 0.0, 0.95)
LENTE = mat_luz("lente", (1.0, 0.05, 0.07), 2.2)
ROBO = mat_pbr("robo", (0.55, 0.55, 0.52), 0.0, 0.8)
CHAO = mat_pbr("chao", (0.20, 0.30, 0.14), 0.0, 1.0)


def obj(nome, bm, material, pos=(0, 0, 0), liso=True):
    me = bpy.data.meshes.new(nome)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    if liso:
        me.shade_smooth()
    ob = bpy.data.objects.new(nome, me)
    ob.location = pos
    col.objects.link(ob)
    return ob


def elips(bm, c, r, seg=20, aneis=12, corte=None):
    """Elipsoide; com corte = z mínimo (em unidades do raio, -1 a 1) vira cúpula."""
    geo = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=aneis, radius=1.0)
    vs = geo["verts"]
    if corte is not None:
        for v in vs:
            if v.co.z < corte:
                v.co.z = corte
    for v in vs:
        v.co = Vector((v.co.x * r[0] + c[0], v.co.y * r[1] + c[1], v.co.z * r[2] + c[2]))


def tubo(bm, pontos, raios, lados=8):
    pontos = [Vector(p) for p in pontos]
    aneis = []
    for i, p in enumerate(pontos):
        d = (pontos[min(i + 1, len(pontos) - 1)] - pontos[max(i - 1, 0)]).normalized()
        a = d.orthogonal().normalized()
        b = d.cross(a)
        aneis.append([bm.verts.new(p + (a * math.cos(math.tau * k / lados) + b * math.sin(math.tau * k / lados)) * raios[i])
                      for k in range(lados)])
    for i in range(len(aneis) - 1):
        for k in range(lados):
            k2 = (k + 1) % lados
            bm.faces.new((aneis[i][k], aneis[i][k2], aneis[i + 1][k2], aneis[i + 1][k]))
    bm.faces.new(aneis[-1])
    bm.faces.new(aneis[0][::-1])


def toro(bm, c, eixo, R_, r, seg=24, lados=8):
    eixo = Vector(eixo).normalized()
    a = eixo.orthogonal().normalized()
    b = eixo.cross(a)
    aneis = []
    for i in range(seg):
        t = math.tau * i / seg
        fora = a * math.cos(t) + b * math.sin(t)
        centro = Vector(c) + fora * R_
        aneis.append([bm.verts.new(centro + (fora * math.cos(math.tau * k / lados) + eixo * math.sin(math.tau * k / lados)) * r)
                      for k in range(lados)])
    for i in range(seg):
        i2 = (i + 1) % seg
        for k in range(lados):
            k2 = (k + 1) % lados
            bm.faces.new((aneis[i][k], aneis[i][k2], aneis[i2][k2], aneis[i2][k]))


def caixa(bm, c, t):
    geo = bmesh.ops.create_cube(bm, size=1.0)
    for v in geo["verts"]:
        v.co = Vector((v.co.x * t[0] + c[0], v.co.y * t[1] + c[1], v.co.z * t[2] + c[2]))


def lente(pos, raio, olhando=(0, -1, 0)):
    o = Vector(olhando).normalized()
    bm = bmesh.new()
    toro(bm, Vector(pos) - o * raio * 0.1, o, raio * 1.25, raio * 0.3, 20, 8)
    obj("aro", bm, JUNTA)
    bm = bmesh.new()
    elips(bm, pos, (raio, raio, raio), 14, 10)
    obj("lente", bm, LENTE)


def robo_ref(x, y=0.0):
    """Boneco de 1,2 m para a escala (o robô do jogador)."""
    bm = bmesh.new()
    elips(bm, (x, y, 0.98), (0.20, 0.19, 0.20))
    elips(bm, (x, y, 0.58), (0.17, 0.13, 0.20))
    for s in (1, -1):
        tubo(bm, [(x + s * 0.09, y, 0.42), (x + s * 0.09, y, 0.0)], [0.07, 0.08])
        tubo(bm, [(x + s * 0.22, y, 0.70), (x + s * 0.26, y, 0.36)], [0.055, 0.07])
    return obj("robo_ref", bm, ROBO)


PEDRA = mat_pbr("pedra", (0.46, 0.44, 0.38), 0.0, 0.9)
PEDRA2 = mat_pbr("pedra_escura", (0.30, 0.29, 0.27), 0.0, 0.95)
import random
rnd = random.Random(4)


def bloco(c, t, material=None, giro=0.0):
    bm = bmesh.new()
    caixa(bm, (0, 0, 0), t)
    o = obj("bloco", bm, material or PEDRA, liso=False)
    o.location = c
    o.rotation_euler = (rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), giro)
    return o


def musgo_em(c, r):
    bm = bmesh.new()
    elips(bm, c, r, 12, 8, corte=0.0)
    obj("musgo", bm, MUSGO)


def coluna(x, y, alt, raio=0.32, caida=False):
    bm = bmesh.new()
    if caida:
        tubo(bm, [(x, y, raio), (x + alt * 0.8, y + alt * 0.5, raio)], [raio, raio * 0.92], 10)
    else:
        tubo(bm, [(x, y, 0), (x, y, alt)], [raio * 1.05, raio * 0.9], 10)
    obj("coluna", bm, PEDRA)
    if not caida:
        bloco((x, y, 0.12), (raio * 2.6, raio * 2.6, 0.24), PEDRA2)


# ---------- 1. Arcos: um aqueduto partido ----------
def arcos(x0):
    for k in range(4):
        cx = x0 - 6 + k * 4.0
        inteiro = k in (0, 1)
        for lado in (-1.4, 1.4):
            alt = 4.2 if (inteiro or lado < 0) else rnd.uniform(1.6, 2.8)
            bloco((cx + lado, 0, alt / 2), (0.9, 1.3, alt))
        if inteiro:
            bm = bmesh.new()
            n = 9
            for i in range(n):
                a0 = math.pi * i / n
                a1 = math.pi * (i + 1) / n
                p0 = (cx + math.cos(a0) * 1.4, 0, 4.2 + math.sin(a0) * 1.4)
                p1 = (cx + math.cos(a1) * 1.4, 0, 4.2 + math.sin(a1) * 1.4)
                tubo(bm, [p0, p1], [0.42, 0.42], 4)
            obj("arco", bm, PEDRA, liso=False)
            bloco((cx, 0, 6.05), (4.0, 1.3, 0.5), PEDRA2)
            musgo_em((cx, 0, 6.3), (1.9, 0.62, 0.22))
    for (bx, by, s) in [(x0 + 3.5, -1.8, 0.9), (x0 + 5.2, 1.2, 0.7), (x0 + 1.2, 2.0, 0.6), (x0 + 6.4, -0.6, 1.1)]:
        bloco((bx, by, s * 0.3), (s * 1.4, s, s * 0.6), PEDRA2, rnd.uniform(0, 3))
    musgo_em((x0 + 4.6, 0.2, 0.0), (2.6, 2.0, 0.25))


# ---------- 2. Torre caída ----------
def torre(x0):
    n = 14
    for i in range(n):
        a = math.tau * i / n
        alt = 5.6 if 2 <= i <= 6 else (rnd.uniform(0.8, 2.4) if i not in (9, 10) else 0.0)
        if alt <= 0:
            continue
        o = bloco((x0 + math.cos(a) * 3.2, math.sin(a) * 3.2, alt / 2), (1.5, 0.8, alt), None, a + math.pi / 2)
    # o topo caído ao lado
    bm = bmesh.new()
    tubo(bm, [(x0 + 5.5, -3.5, 1.4), (x0 + 8.6, -5.2, 1.0)], [1.9, 1.6], 12)
    obj("topo", bm, PEDRA2, liso=False)
    musgo_em((x0 + 7.0, -4.3, 2.2), (1.9, 1.4, 0.5))
    musgo_em((x0 - 1.0, 2.6, 5.5), (2.2, 1.2, 0.35))
    # o núcleo de máquina no meio: um anel de metal apagado
    bm = bmesh.new()
    toro(bm, (x0, 0, 0.5), (0, 0, 1), 1.5, 0.28, 24, 8)
    obj("anel", bm, CASCO)
    bm = bmesh.new()
    elips(bm, (x0, 0, 0.55), (0.5, 0.5, 0.5))
    obj("nucleo", bm, JUNTA)


# ---------- 3. Pátio das máquinas ----------
def patio(x0):
    for (cx, cy, w, d, h) in [(x0, -5.0, 11.0, 0.8, 1.6), (x0 - 5.5, -1.0, 0.8, 8.0, 1.1), (x0 + 5.5, -2.5, 0.8, 5.0, 2.2), (x0 - 2.5, 4.0, 5.0, 0.8, 0.8)]:
        bloco((cx, cy, h / 2), (w, d, h))
    for (cx, cy, alt, caida) in [(x0 - 3.5, -3.0, 3.6, False), (x0 + 3.5, -3.0, 2.2, False), (x0 - 3.5, 2.0, 1.2, False), (x0 + 2.5, 2.0, 3.0, True)]:
        coluna(cx, cy, alt, 0.36, caida)
    # o berço: uma plataforma redonda com três braços, onde as máquinas dormem
    bm = bmesh.new()
    tubo(bm, [(x0, -0.5, 0), (x0, -0.5, 0.35)], [2.4, 2.2], 20)
    obj("plataforma", bm, PEDRA2)
    bm = bmesh.new()
    toro(bm, (x0, -0.5, 0.42), (0, 0, 1), 1.7, 0.16, 28, 8)
    obj("anel", bm, CASCO)
    for k in range(3):
        a = math.tau * k / 3 + 0.5
        bm = bmesh.new()
        tubo(bm, [(x0 + math.cos(a) * 1.9, -0.5 + math.sin(a) * 1.9, 0.35), (x0 + math.cos(a) * 2.3, -0.5 + math.sin(a) * 2.3, 1.9),
                  (x0 + math.cos(a) * 1.5, -0.5 + math.sin(a) * 1.5, 2.6)], [0.16, 0.12, 0.07], 7)
        obj("braco", bm, FERRUGEM)
    lente((x0, -0.5, 0.62), 0.16, (0, 0, 1))
    musgo_em((x0 - 5.5, -1.0, 1.1), (0.6, 3.6, 0.25))
    musgo_em((x0 + 1.0, -5.0, 1.6), (4.0, 0.6, 0.25))


X = (0.0, 60.0, 120.0)
arcos(X[0])
robo_ref(X[0] + 4.2, -3.2)
torre(X[1])
robo_ref(X[1] + 2.4, -5.8)
patio(X[2])
robo_ref(X[2] + 3.6, 4.6)
bm = bmesh.new()
caixa(bm, (60, 0, -0.01), (400, 400, 0.02))
chao = obj("chao", bm, CHAO, liso=False)


def luz(nome, tipo, energia, rot=None, cor=(1, 1, 1)):
    d = bpy.data.lights.new(nome, tipo)
    d.energy = energia
    d.color = cor
    o = bpy.data.objects.new(nome, d)
    if rot:
        o.rotation_euler = [math.radians(a) for a in rot]
    col.objects.link(o)
    return o


luz("sol", "SUN", 3.6, (52, 0, -35), (1.0, 0.95, 0.86))
luz("ceu", "SUN", 1.0, (50, 0, 150), (0.7, 0.82, 1.0))
world = bpy.data.worlds.new("ceu")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.56, 0.72, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = PW
scene.render.resolution_y = PH
try:
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.eevee.taa_render_samples = 40
except Exception as e:
    print("eevee", e)
cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
col.objects.link(cam)
scene.camera = cam


def mirar(loc, alvo, orto=None, lente_mm=45):
    cam.location = loc
    cam.rotation_euler = (Vector(alvo) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    if orto:
        cam_d.type = "ORTHO"
        cam_d.ortho_scale = orto
    else:
        cam_d.type = "PERSP"
        cam_d.lens = lente_mm


def render(nome):
    caminho = os.path.join(TMP, nome + ".png")
    scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    return caminho


PAINEIS = []
mirar((X[0] - 9.0, -17.0, 6.5), (X[0] + 0.5, 0, 2.6), lente_mm=40)
PAINEIS.append(render("r1"))
mirar((X[1] - 10.0, -15.0, 7.5), (X[1] + 2.0, -1.0, 2.2), lente_mm=40)
PAINEIS.append(render("r2"))
mirar((X[2] - 9.0, -15.0, 8.5), (X[2], -0.5, 1.2), lente_mm=40)
PAINEIS.append(render("r3"))

G, TOPO, BASE = int(16 * ESC), int(48 * ESC), int(104 * ESC)
W = 3 * PW + 4 * G
H = G + TOPO + PH + BASE + G
tela = np.zeros((H, W, 4), np.float32)
tela[..., :3] = (0.09, 0.10, 0.11)
tela[..., 3] = 1
for k in range(3):
    x0 = G + k * (PW + G)
    im = bpy.data.images.load(PAINEIS[k])
    tela[G + BASE:G + BASE + PH, x0:x0 + PW] = np.array(im.pixels[:], np.float32).reshape(PH, PW, 4)
out = bpy.data.images.new("folha", W, H, alpha=False)
out.pixels[:] = tela.ravel()
out.filepath_raw = SAIDA
out.file_format = "PNG"
out.save()
TEXTOS = [
    ("1. Os Arcos", ["Um aqueduto partido cruzando a mata.", "Dá para voar por baixo dos arcos e", "pousar em cima do que sobrou."]),
    ("2. A Torre Caída", ["Meia torre de pé, o topo tombado ao lado.", "No meio, o núcleo apagado de uma máquina.", "Bom mirante: dá para subir por dentro."]),
    ("3. O Pátio das Máquinas", ["Muros baixos, colunas e o berço onde as", "máquinas dormem (com a lente acesa).", "É daqui que elas saem para patrulhar."]),
]
fb = blf.load("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
fr = blf.load("/System/Library/Fonts/Supplemental/Arial.ttf")
ib = imbuf.load(SAIDA)
with blf.bind_imbuf(fb, ib), blf.bind_imbuf(fr, ib):
    for k, (titulo, linhas) in enumerate(TEXTOS):
        x0 = G + k * (PW + G)
        blf.size(fb, int(26 * ESC))
        blf.color(fb, 0.95, 0.95, 0.92, 1)
        blf.position(fb, x0, H - G - int(34 * ESC), 0)
        blf.draw_buffer(fb, titulo)
        blf.size(fr, int(18 * ESC))
        blf.color(fr, 0.80, 0.82, 0.84, 1)
        for i, l in enumerate(linhas):
            blf.position(fr, x0, G + BASE - int(30 * ESC) - i * int(25 * ESC), 0)
            blf.draw_buffer(fr, l)
imbuf.write(ib, filepath=SAIDA)
print("ok", SAIDA, W, H)
