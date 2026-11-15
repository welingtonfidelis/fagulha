# Maquetes das máquinas agressivas do vale (2026-11-14): três conceitos para o usuário escolher.
# Máquinas antigas, de metal gasto e tomadas pelo musgo, com uma lente vermelha. Formas simples, no estilo do vale.
# blender -b --factory-startup -P tools/vale/maquinas.py -- <saida.png> [escala]
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


# ---------- 1. Zangão: voador pequeno ----------
def zangao(x0):
    z = 1.9
    bm = bmesh.new()
    elips(bm, (x0, 0.05, z), (0.30, 0.46, 0.25))
    obj("corpo", bm, CASCO)
    bm = bmesh.new()
    elips(bm, (x0, 0.12, z + 0.06), (0.25, 0.36, 0.23), corte=0.25)
    obj("musgo", bm, MUSGO)
    lente((x0, -0.40, z - 0.02), 0.11)
    for s in (1, -1):
        bm = bmesh.new()
        toro(bm, (x0 + s * 0.62, 0.05, z + 0.05), (0, 0, 1), 0.27, 0.045)
        obj("duto", bm, CASCO2)
        bm = bmesh.new()
        tubo(bm, [(x0 + s * 0.25, 0.05, z + 0.02), (x0 + s * 0.62, 0.05, z + 0.05)], [0.05, 0.035])
        tubo(bm, [(x0 + s * 0.62, 0.05, z + 0.0), (x0 + s * 0.62, 0.05, z + 0.11)], [0.05, 0.03])
        caixa(bm, (x0 + s * 0.62, 0.05, z + 0.05), (0.5, 0.03, 0.012))
        caixa(bm, (x0 + s * 0.62, 0.05, z + 0.05), (0.03, 0.5, 0.012))
        obj("braco", bm, JUNTA)
    bm = bmesh.new()
    tubo(bm, [(x0, 0.45, z + 0.02), (x0, 0.85, z + 0.16)], [0.06, 0.015])
    caixa(bm, (x0, 0.74, z + 0.26), (0.02, 0.22, 0.22))
    obj("cauda", bm, FERRUGEM)
    bm = bmesh.new()
    tubo(bm, [(x0 - 0.1, -0.2, z - 0.2), (x0 - 0.1, -0.42, z - 0.27)], [0.035, 0.028])
    tubo(bm, [(x0 + 0.1, -0.2, z - 0.2), (x0 + 0.1, -0.42, z - 0.27)], [0.035, 0.028])
    obj("canos", bm, JUNTA)


# ---------- 2. Sentinela: torre andante ----------
def sentinela(x0):
    zc = 2.75
    bm = bmesh.new()
    elips(bm, (x0, 0, zc), (0.62, 0.70, 0.36))
    obj("cabeca", bm, CASCO)
    bm = bmesh.new()
    elips(bm, (x0, 0.08, zc + 0.10), (0.55, 0.58, 0.34), corte=0.2)
    obj("musgo", bm, MUSGO)
    bm = bmesh.new()
    toro(bm, (x0, 0, zc - 0.12), (0, 0, 1), 0.60, 0.07, 28, 8)
    obj("cinta", bm, FERRUGEM)
    lente((x0, -0.66, zc - 0.02), 0.17)
    bm = bmesh.new()
    tubo(bm, [(x0, 0, zc - 0.3), (x0, 0, zc - 0.62)], [0.22, 0.16])
    obj("pescoco", bm, JUNTA)
    for k in range(3):
        ang = math.radians(90 + 120 * k)  # uma perna para trás, duas para a frente
        d = Vector((math.cos(ang), math.sin(ang), 0))
        quadril = Vector((x0, 0, zc - 0.55)) + d * 0.18
        joelho = Vector((x0, 0, 2.05)) + d * 1.15
        pe = Vector((x0, 0, 0.0)) + d * 1.45
        bm = bmesh.new()
        tubo(bm, [quadril, joelho], [0.10, 0.075])
        tubo(bm, [joelho, pe + Vector((0, 0, 0.12))], [0.07, 0.05])
        obj("perna", bm, CASCO2)
        bm = bmesh.new()
        elips(bm, joelho, (0.13, 0.13, 0.13), 12, 8)
        elips(bm, pe + Vector((0, 0, 0.07)), (0.20, 0.20, 0.09), 12, 8)
        obj("junta", bm, JUNTA)
    bm = bmesh.new()
    tubo(bm, [(x0 + 0.3, 0.3, zc + 0.3), (x0 + 0.42, 0.42, zc + 1.0)], [0.02, 0.008], 5)
    obj("antena", bm, JUNTA)


# ---------- 3. Carrapato: rasteiro que investe ----------
def carrapato(x0, y0=0.0, giro=0.0):
    pecas = []
    bm = bmesh.new()
    elips(bm, (0, 0.04, 0.26), (0.40, 0.52, 0.30), corte=-0.25)
    pecas.append(obj("casco", bm, CASCO))
    bm = bmesh.new()
    elips(bm, (0, 0.12, 0.30), (0.33, 0.40, 0.29), corte=0.3)
    pecas.append(obj("musgo", bm, MUSGO))
    bm = bmesh.new()
    caixa(bm, (0, -0.50, 0.24), (0.46, 0.10, 0.22))
    caixa(bm, (0, -0.57, 0.16), (0.30, 0.08, 0.10))
    pecas.append(obj("ariete", bm, FERRUGEM, liso=False))
    for s in (1, -1):
        for y in (-0.26, 0.30):
            bm = bmesh.new()
            ombro = Vector((s * 0.30, y, 0.22))
            joelho = Vector((s * 0.58, y + (0.06 if y < 0 else -0.06) * -1, 0.36))
            pe = Vector((s * 0.66, y, 0.0))
            tubo(bm, [ombro, joelho], [0.06, 0.05], 7)
            tubo(bm, [joelho, pe], [0.05, 0.03], 7)
            pecas.append(obj("perna", bm, CASCO2))
            bm = bmesh.new()
            elips(bm, joelho, (0.075, 0.075, 0.075), 10, 8)
            pecas.append(obj("junta", bm, JUNTA))
    for p in pecas:
        p.matrix_world = Matrix.Translation((x0, y0, 0)) @ Matrix.Rotation(giro, 4, "Z")
    bpy.context.view_layer.update()
    M = Matrix.Translation((x0, y0, 0)) @ Matrix.Rotation(giro, 4, "Z")
    bm = bmesh.new()
    olho = M @ Vector((0, -0.47, 0.42))
    dirv = (M.to_3x3() @ Vector((0, -1, 0)))
    toro(bm, olho - dirv * 0.007, dirv, 0.09, 0.022, 16, 6)
    obj("aro", bm, JUNTA)
    bm = bmesh.new()
    elips(bm, olho, (0.07, 0.07, 0.07), 12, 8)
    obj("lente", bm, LENTE)


X = (0.0, 30.0, 60.0)
zangao(X[0])
robo_ref(X[0] + 1.3)
sentinela(X[1])
robo_ref(X[1] + 2.3)
carrapato(X[2] - 0.2, 0.0, 0.0)
carrapato(X[2] - 1.5, 0.9, 0.5)
carrapato(X[2] + 0.9, 1.2, -0.4)
robo_ref(X[2] + 1.5, -0.2)
bm = bmesh.new()
caixa(bm, (30, 0, -0.01), (200, 200, 0.02))
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
mirar((X[0] - 2.6, -4.2, 2.5), (X[0] + 0.35, 0, 1.45))
PAINEIS.append(render("m1"))
mirar((X[1] - 5.2, -8.4, 3.3), (X[1] + 0.5, 0, 1.6))
PAINEIS.append(render("m2"))
mirar((X[2] - 3.0, -4.6, 2.2), (X[2] + 0.1, 0.3, 0.45))
PAINEIS.append(render("m3"))
# silhuetas com o robô ao lado
PRETO = bpy.data.materials.new("silhueta")
PRETO.use_nodes = True
PRETO.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
PRETO.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
scene.view_layers[0].material_override = PRETO
chao.hide_render = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.82, 0.82, 0.80, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
scene.view_settings.look = "None"
scene.render.resolution_y = int(PH * 0.62)
PH2 = scene.render.resolution_y
for k, (cx, larg, cz) in enumerate(((X[0] + 0.5, 4.2, 1.2), (X[1] + 0.6, 6.6, 1.9), (X[2] + 0.2, 4.6, 1.3))):
    mirar((cx, -40, cz), (cx, 0, cz), orto=larg)
    PAINEIS.append(render("s%d" % (k + 1)))

# ---------- folha ----------
G, TOPO, BASE = int(16 * ESC), int(48 * ESC), int(104 * ESC)
W = 3 * PW + 4 * G
H = G + TOPO + PH + G + PH2 + BASE + G
tela = np.zeros((H, W, 4), np.float32)
tela[..., :3] = (0.09, 0.10, 0.11)
tela[..., 3] = 1
for k in range(3):
    x0 = G + k * (PW + G)
    im = bpy.data.images.load(PAINEIS[k])
    tela[G + BASE + PH2 + G:G + BASE + PH2 + G + PH, x0:x0 + PW] = np.array(im.pixels[:], np.float32).reshape(PH, PW, 4)
    im = bpy.data.images.load(PAINEIS[3 + k])
    tela[G + BASE:G + BASE + PH2, x0:x0 + PW] = np.array(im.pixels[:], np.float32).reshape(PH2, PW, 4)
out = bpy.data.images.new("folha", W, H, alpha=False)
out.pixels[:] = tela.ravel()
out.filepath_raw = SAIDA
out.file_format = "PNG"
out.save()
TEXTOS = [
    ("1. Zangão", ["Voador pequeno (0,9 m), anda em dupla.", "Patrulha a 3–6 m do chão e dá rajadas", "lentas. Frágil: dois ou três tiros."]),
    ("2. Sentinela", ["Torre andante (3,2 m), sozinha e lenta.", "Vê de longe, avisa com o farol e dá um", "tiro forte. Dá para evitar voando baixo."]),
    ("3. Carrapato", ["Rasteiro (0,6 m), anda em trio.", "Corre no capim e investe com o aríete.", "Não alcança quem está no ar."]),
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
        blf.size(fr, int(15 * ESC))
        blf.color(fr, 0.2, 0.2, 0.2, 1)
        blf.position(fr, x0 + int(10 * ESC), G + BASE + int(8 * ESC), 0)
        blf.draw_buffer(fr, "ao lado do robô (1,2 m)")
imbuf.write(ib, filepath=SAIDA)
print("ok", SAIDA, W, H)
