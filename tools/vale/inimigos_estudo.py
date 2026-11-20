# Estudo dos robôs inimigos (2026-11-20): três famílias para as máquinas comuns e três chefes, feitos por
# script como o robô do jogador (tools/vale/robo_v2.py). É só uma folha para discutir: nada daqui vai ao jogo.
# Folha:  blender -b --factory-startup -P tools/vale/inimigos_estudo.py -- /caminho/folha.png
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
PW, PH = 1280, 800
TMP = os.path.join(os.path.dirname(SAIDA), "_paineis")
os.makedirs(TMP, exist_ok=True)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)
scene = bpy.context.scene
col = scene.collection
R = math.radians


def mat_pbr(nome, cor, metal=0.0, rug=0.5):
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


ESCURO = mat_pbr("escuro", (0.035, 0.04, 0.045), 0.2, 0.55)
GRAFITE = mat_pbr("grafite", (0.10, 0.11, 0.12), 0.2, 0.5)
ACO = mat_pbr("aco", (0.32, 0.33, 0.34), 0.6, 0.4)
OLIVA = mat_pbr("oliva", (0.20, 0.25, 0.10), 0.0, 0.55)
OLIVA_CLARO = mat_pbr("oliva_claro", (0.36, 0.40, 0.20), 0.0, 0.55)
FERRUGEM = mat_pbr("ferrugem", (0.42, 0.12, 0.04), 0.0, 0.55)
FERRUGEM_CLARA = mat_pbr("ferrugem_clara", (0.60, 0.26, 0.08), 0.0, 0.55)
MOSTARDA = mat_pbr("mostarda", (0.62, 0.42, 0.04), 0.0, 0.5)
CREME = mat_pbr("creme", (0.62, 0.58, 0.44), 0.0, 0.55)
BRANCO = mat_pbr("branco", (0.55, 0.56, 0.56), 0.0, 0.45)
AZUL = mat_pbr("azul", (0.008, 0.07, 0.36), 0.05, 0.4)
AMBAR = mat_luz("ambar", (1.0, 0.55, 0.12), 5.0)
VERMELHO = mat_luz("vermelho", (1.0, 0.12, 0.06), 5.0)
CIANO = mat_luz("ciano", (0.35, 0.9, 1.0), 4.0)
LAMINA = mat_luz("lamina", (1.0, 0.35, 0.1), 5.0)
BOCA = mat_luz("boca", (1.0, 0.6, 0.2), 2.5)


def malha(nome, bm, mat, pai, bevel=0.018, segs=2):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nome, me)
    col.objects.link(ob)
    if bevel:
        md = ob.modifiers.new("bisel", "BEVEL")
        md.width = bevel
        md.segments = segs
        md.limit_method = "ANGLE"
    try:
        me.shade_smooth_by_angle(angle=R(28))
    except Exception:
        pass
    ob.parent = pai
    return ob


def _m(centro, rot):
    return Matrix.Translation(centro) @ Matrix.Rotation(R(rot[2]), 4, "Z") @ Matrix.Rotation(R(rot[1]), 4, "Y") \
        @ Matrix.Rotation(R(rot[0]), 4, "X")


class Robo:
    """Um robô montado em volta de (ox, 0, 0), com tudo multiplicado por `e`. De frente para -Y."""

    def __init__(self, grupo, ox, e=1.0):
        self.pai = grupo
        self.ox = ox
        self.e = e

    def p(self, c):
        return (self.ox + c[0] * self.e, c[1] * self.e, c[2] * self.e)

    def cx(self, c, t, mat, base=(1, 1), topo=(1, 1), rot=(0, 0, 0), bevel=0.02, segs=2):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            f = topo if v.co.z > 0 else base
            v.co.x *= t[0] * f[0] * self.e
            v.co.y *= t[1] * f[1] * self.e
            v.co.z *= t[2] * self.e
        bmesh.ops.transform(bm, matrix=_m(self.p(c), rot), verts=bm.verts)
        return malha("cx", bm, mat, self.pai, bevel * self.e, segs)

    def ci(self, c, r1, r2, comp, mat, rot=(0, 0, 0), segs=18, bevel=0.01):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1 * self.e, radius2=r2 * self.e,
                              depth=comp * self.e, matrix=_m(self.p(c), rot))
        return malha("ci", bm, mat, self.pai, bevel * self.e, 1)

    def es(self, c, raios, mat, u=24, v=14):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
        for vv in bm.verts:
            vv.co.x *= raios[0] * self.e
            vv.co.y *= raios[1] * self.e
            vv.co.z *= raios[2] * self.e
        bmesh.ops.transform(bm, matrix=Matrix.Translation(self.p(c)), verts=bm.verts)
        return malha("es", bm, mat, self.pai, 0, 1)

    # ---- as armas são as do jogador: cano na luva, lâmina no pulso, casulo de mísseis no ombro ----
    def canhao(self, x, z, y=-0.06, duplo=False, tam=1.0):
        for dx in ((-0.05, 0.05) if duplo else (0.0,)):
            self.ci((x + dx * tam, y - 0.2 * tam, z), 0.045 * tam, 0.05 * tam, 0.3 * tam, ACO, rot=(90, 0, 0), segs=12)
            self.ci((x + dx * tam, y - 0.36 * tam, z), 0.03 * tam, 0.03 * tam, 0.02 * tam, BOCA, rot=(90, 0, 0), segs=12, bevel=0)

    def lamina(self, x, z, comp=0.8, y=-0.1):
        self.cx((x, y - comp * 0.5, z), (0.035, comp, 0.11), LAMINA, topo=(1, 1), bevel=0.015, segs=1)
        self.cx((x, y + 0.02, z), (0.08, 0.1, 0.16), ACO)

    def misseis(self, x, z, y=0.05, tam=1.0, lado=1.0):
        self.cx((x, y, z), (0.3 * tam, 0.36 * tam, 0.26 * tam), GRAFITE, rot=(-12, 0, lado * 4), bevel=0.03)
        for i in (-1, 1):
            for j in (-1, 1):
                self.ci((x + i * 0.07 * tam, y - 0.17 * tam, z + j * 0.06 * tam + 0.035 * tam), 0.04 * tam, 0.04 * tam, 0.04 * tam,
                        VERMELHO if (i + j) != 0 else ESCURO, rot=(78, 0, 0), segs=10, bevel=0)


def grupo(nome):
    g = bpy.data.objects.new(nome, None)
    col.objects.link(g)
    return g


# ---------------------------------------------------------------- Família A: a Lata
def lata(g, ox, arma, e=1.0, chefe=False):
    r = Robo(g, ox, e)
    for s in (-1, 1):
        r.cx((s * 0.22, -0.04, 0.07), (0.26, 0.4, 0.14), ESCURO, topo=(0.8, 0.7), bevel=0.04)
        r.ci((s * 0.2, 0, 0.36), 0.085, 0.085, 0.46, GRAFITE)
        r.cx((s * 0.2, -0.07, 0.38), (0.2, 0.08, 0.2), OLIVA_CLARO, bevel=0.04)
        r.es((s * 0.52, 0, 1.24), (0.16, 0.16, 0.16), ESCURO)
        r.cx((s * 0.55, 0, 1.3), (0.26, 0.32, 0.12), OLIVA, rot=(0, s * -14, 0), bevel=0.04)
        r.ci((s * 0.57, 0, 0.98), 0.075, 0.075, 0.4, GRAFITE)
        r.cx((s * 0.57, -0.02, 0.68), (0.22, 0.28, 0.26), OLIVA_CLARO, base=(0.85, 0.85), bevel=0.05)
    r.cx((0, 0, 0.66), (0.5, 0.32, 0.18), ESCURO, bevel=0.04)
    r.cx((0, 0, 1.04), (0.8, 0.52, 0.62), OLIVA, base=(0.78, 0.86), bevel=0.07, segs=3)
    r.cx((0, -0.265, 1.1), (0.42, 0.03, 0.3), OLIVA_CLARO, bevel=0.03)
    for k in range(3):
        r.cx((0, -0.285, 1.02 + k * 0.08), (0.3, 0.015, 0.03), ESCURO, bevel=0)
    r.ci((0, 0, 1.36), 0.2, 0.2, 0.06, ESCURO)
    r.es((0, 0, 1.4), (0.27, 0.27, 0.21), OLIVA_CLARO)
    r.ci((0, -0.235, 1.43), 0.115, 0.115, 0.08, ESCURO, rot=(90, 0, 0))
    r.ci((0, -0.275, 1.43), 0.08, 0.08, 0.02, AMBAR, rot=(90, 0, 0), bevel=0)
    r.ci((0.14, 0.05, 1.68), 0.012, 0.012, 0.26, ACO, segs=8, bevel=0)
    r.es((0.14, 0.05, 1.82), (0.03, 0.03, 0.03), AMBAR)
    if chefe:
        # o Colosso: ombros de torre, peito com núcleo aceso e dois canos em cada luva
        for s in (-1, 1):
            r.cx((s * 0.62, 0.02, 1.42), (0.4, 0.44, 0.26), OLIVA, rot=(0, s * -18, 0), bevel=0.06)
            r.cx((s * 0.62, -0.02, 0.66), (0.3, 0.36, 0.32), OLIVA, bevel=0.06)
            r.canhao(s * 0.62, 0.66, duplo=True, tam=1.25)
        r.ci((0, -0.29, 0.86), 0.09, 0.09, 0.03, AMBAR, rot=(90, 0, 0), bevel=0)
        r.cx((0, 0.3, 1.2), (0.5, 0.2, 0.5), GRAFITE, bevel=0.05)
        return
    if arma == "canhao":
        r.canhao(0.57, 0.68)
    elif arma == "lamina":
        r.lamina(0.57, 0.66)
    else:
        r.misseis(0.5, 1.5, lado=1.0)
        r.misseis(-0.5, 1.5, lado=-1.0)


# ---------------------------------------------------------------- Família B: o Guarda
def guarda(g, ox, arma, e=1.0, chefe=False):
    r = Robo(g, ox, e)
    for s in (-1, 1):
        r.cx((s * 0.2, -0.12, 0.05), (0.17, 0.36, 0.1), ESCURO, topo=(0.8, 0.6), bevel=0.03)
        r.cx((s * 0.2, 0.05, 0.32), (0.1, 0.12, 0.54), GRAFITE, rot=(-22, 0, 0))
        r.cx((s * 0.2, 0.0, 0.78), (0.15, 0.18, 0.52), FERRUGEM, rot=(24, 0, 0), bevel=0.04)
        r.ci((s * 0.2, 0.12, 0.56), 0.07, 0.07, 0.17, ESCURO, rot=(0, 90, 0))
        r.cx((s * 0.5, 0.0, 1.62), (0.28, 0.36, 0.2), FERRUGEM, rot=(0, s * -16, 0), topo=(0.8, 0.8), bevel=0.05)
        r.cx((s * 0.5, 0.0, 1.28), (0.1, 0.1, 0.5), GRAFITE)
        r.cx((s * 0.5, -0.06, 0.94), (0.17, 0.32, 0.2), FERRUGEM_CLARA, bevel=0.04)
    r.cx((0, 0, 1.04), (0.38, 0.24, 0.16), ESCURO, bevel=0.04)
    r.ci((0, 0, 1.16), 0.1, 0.1, 0.12, GRAFITE)
    r.cx((0, 0, 1.44), (0.72, 0.38, 0.48), FERRUGEM, base=(0.5, 0.8), bevel=0.06, segs=3)
    r.cx((0, -0.19, 1.48), (0.3, 0.03, 0.26), FERRUGEM_CLARA, base=(0.6, 1), bevel=0.03)
    r.cx((0, -0.02, 1.78), (0.44, 0.32, 0.17), GRAFITE, base=(0.85, 0.9), bevel=0.05)
    r.cx((0, -0.17, 1.78), (0.36, 0.03, 0.05), VERMELHO, bevel=0.01, segs=1)
    for s in (-1, 1):
        r.cx((s * 0.16, 0.2, 1.62), (0.05, 0.3, 0.4), GRAFITE, rot=(-28, 0, s * 10), topo=(1, 0.4), bevel=0.02)
    if chefe:
        # a Lâmina: duas lâminas compridas e uma crista de aletas nas costas
        for s in (-1, 1):
            r.lamina(s * 0.5, 0.92, comp=1.15)
            r.cx((s * 0.3, 0.26, 1.78), (0.05, 0.4, 0.62), FERRUGEM_CLARA, rot=(-34, 0, s * 16), topo=(1, 0.3), bevel=0.02)
        r.cx((0, 0.02, 1.95), (0.06, 0.3, 0.22), FERRUGEM_CLARA, topo=(1, 0.4), bevel=0.02)
        return
    if arma == "canhao":
        r.canhao(0.5, 0.94)
    elif arma == "lamina":
        r.lamina(0.5, 0.92)
    else:
        r.misseis(0.34, 1.86, y=0.16, tam=0.85, lado=1.0)
        r.misseis(-0.34, 1.86, y=0.16, tam=0.85, lado=-1.0)


# ---------------------------------------------------------------- Família C: o Barril
def barril(g, ox, arma, e=1.0, chefe=False):
    r = Robo(g, ox, e)
    pernas = ((-0.2, 0.0), (0.2, 0.0)) if not chefe else ((-0.3, -0.16), (0.3, -0.16), (-0.3, 0.2), (0.3, 0.2))
    for (x, y) in pernas:
        r.ci((x, y, 0.3), 0.065, 0.065, 0.5, GRAFITE)
        r.ci((x, y, 0.5), 0.09, 0.09, 0.1, ESCURO)
        r.cx((x, y - 0.05, 0.05), (0.24, 0.32, 0.1), ESCURO, topo=(0.7, 0.7), bevel=0.04)
    r.ci((0, 0, 0.98), 0.38, 0.43, 0.86, MOSTARDA, segs=24, bevel=0.05)
    r.ci((0, 0, 0.72), 0.445, 0.445, 0.07, ESCURO, segs=24)
    r.ci((0, 0, 1.24), 0.41, 0.41, 0.05, ESCURO, segs=24)
    r.es((0, 0, 1.4), (0.38, 0.38, 0.15), GRAFITE)
    r.ci((0, -0.4, 1.0), 0.17, 0.17, 0.1, ESCURO, rot=(90, 0, 0))
    r.ci((0, -0.45, 1.0), 0.12, 0.12, 0.02, CIANO, rot=(90, 0, 0), bevel=0)
    r.cx((0, 0, 1.58), (0.26, 0.05, 0.05), ACO, bevel=0.02)
    for s in (-1, 1):
        r.cx((s * 0.11, 0, 1.52), (0.04, 0.05, 0.12), ACO, bevel=0.01)
        r.es((s * 0.47, 0, 1.04), (0.11, 0.11, 0.11), ESCURO)
        r.ci((s * 0.52, 0, 0.82), 0.06, 0.06, 0.36, GRAFITE)
        r.cx((s * 0.52, -0.02, 0.58), (0.2, 0.26, 0.22), CREME, base=(0.85, 0.85), bevel=0.05)
    if chefe:
        # o Artilheiro: quatro pernas, quatro casulos de mísseis e um cano grosso no lugar do olho de baixo
        for s in (-1, 1):
            r.misseis(s * 0.36, 1.66, y=0.05, tam=1.0, lado=s)
            r.misseis(s * 0.66, 1.3, y=0.05, tam=0.9, lado=s)
        r.ci((0, -0.52, 0.72), 0.07, 0.08, 0.34, ACO, rot=(90, 0, 0))
        r.ci((0, -0.7, 0.72), 0.05, 0.05, 0.02, BOCA, rot=(90, 0, 0), bevel=0)
        return
    if arma == "canhao":
        r.canhao(0.52, 0.58)
    elif arma == "lamina":
        r.lamina(0.52, 0.56, comp=0.7)
    else:
        r.misseis(0.0, 1.66, y=0.04, tam=0.95)


# ---------------------------------------------------------------- o robô do jogador, só para a escala
def jogador(g, ox):
    r = Robo(g, ox, 1.0)
    for s in (-1, 1):
        r.cx((s * 0.1, -0.02, 0.07), (0.15, 0.22, 0.14), AZUL, bevel=0.04)
        r.ci((s * 0.09, 0, 0.26), 0.04, 0.04, 0.26, ESCURO)
        r.ci((s * 0.2, 0, 0.5), 0.035, 0.035, 0.2, ESCURO)
        r.cx((s * 0.22, -0.01, 0.36), (0.13, 0.16, 0.16), BRANCO, bevel=0.04)
    r.cx((0, 0, 0.52), (0.3, 0.22, 0.3), BRANCO, base=(0.8, 0.9), bevel=0.05)
    r.cx((0, 0.015, 0.93), (0.43, 0.40, 0.39), BRANCO, base=(0.8, 0.86), topo=(0.8, 0.84), bevel=0.12, segs=3)
    r.cx((0, -0.19, 0.93), (0.32, 0.03, 0.2), ESCURO, bevel=0.03)
    for s in (-1, 1):
        r.cx((s * 0.07, -0.21, 0.94), (0.04, 0.01, 0.08), CIANO, bevel=0)
    r.cx((0, 0.0, 1.13), (0.1, 0.3, 0.03), AZUL, bevel=0.01)


G_A, G_B, G_C, G_CH, G_ESC = grupo("A"), grupo("B"), grupo("C"), grupo("chefes"), grupo("escala")
for g, fam in ((G_A, lata), (G_B, guarda), (G_C, barril)):
    fam(g, -1.55, "canhao")
    fam(g, 0.0, "lamina")
    fam(g, 1.55, "misseis")
    jogador(g, 2.75)
lata(G_CH, -3.0, "", e=1.72, chefe=True)
barril(G_CH, 0.0, "", e=1.75, chefe=True)
guarda(G_CH, 3.0, "", e=1.55, chefe=True)
jogador(G_CH, 4.9)
jogador(G_ESC, -5.2)
lata(G_ESC, -4.0, "canhao")
guarda(G_ESC, -2.6, "canhao")
barril(G_ESC, -1.2, "canhao")
lata(G_ESC, 0.8, "", e=1.72, chefe=True)
barril(G_ESC, 3.4, "", e=1.75, chefe=True)
guarda(G_ESC, 5.8, "", e=1.55, chefe=True)
GRUPOS = [G_A, G_B, G_C, G_CH, G_ESC]


def so(g):
    for x in GRUPOS:
        x.location = (0, 0, 0) if x is g else (0, 0, -500)
    bpy.context.view_layer.update()


# ---------- chão, luz e câmera ----------
chao = bpy.data.objects.new("chao", bpy.data.meshes.new("chao"))
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60.0)
bm.to_mesh(chao.data)
bm.free()
chao.data.materials.append(mat_pbr("chao", (0.13, 0.14, 0.15), 0.0, 0.9))
col.objects.link(chao)


def luz(nome, tipo, loc, alvo, energia, tam=1.0, cor=(1, 1, 1)):
    d = bpy.data.lights.new(nome, tipo)
    d.energy = energia
    d.color = cor
    if tipo == "AREA":
        d.size = tam
    o = bpy.data.objects.new(nome, d)
    o.location = loc
    o.rotation_euler = (Vector(alvo) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    col.objects.link(o)
    return o


luz("sol", "SUN", (-4, -6, 9), (0, 0, 1), 3.2, cor=(1.0, 0.96, 0.9))
luz("preenche", "AREA", (7, -7, 4), (0, 0, 1.5), 2600, 9.0, (0.8, 0.88, 1.0))
luz("recorte", "AREA", (1, 8, 7), (0, 0, 2), 4200, 8.0)
world = bpy.data.worlds.new("estudio")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.2, 0.22, 0.25, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = PW
scene.render.resolution_y = PH
try:
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.eevee.taa_render_samples = 48
    scene.eevee.use_raytracing = True
except Exception as ex:
    print("eevee", ex)
cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
col.objects.link(cam)
scene.camera = cam


def mirar(loc, alvo, lente=50, orto=None):
    cam.location = loc
    cam.rotation_euler = (Vector(alvo) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    if orto:
        cam_d.type = "ORTHO"
        cam_d.ortho_scale = orto
    else:
        cam_d.type = "PERSP"
        cam_d.lens = lente


def render(nome):
    caminho = os.path.join(TMP, nome + ".png")
    scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    return caminho


PAINEIS = []
for g, nome, titulo in ((G_A, "a", "A · A Lata: atirador, lâmina e mísseis (1,8 m)"),
                        (G_B, "b", "B · O Guarda: atirador, lâmina e mísseis (1,9 m)"),
                        (G_C, "c", "C · O Barril: atirador, lâmina e mísseis (1,6 m)")):
    so(g)
    mirar((-2.4, -9.6, 2.2), (0.5, 0, 0.9), lente=58)
    PAINEIS.append((titulo, render(nome)))
so(G_CH)
mirar((-4.4, -17.5, 3.8), (0.7, 0, 1.6), lente=58)
PAINEIS.append(("Chefes (3 m): o Colosso, o Artilheiro e a Lâmina", render("chefes")))
so(G_ESC)
mirar((0.3, -30, 1.7), (0.3, 0, 1.7), orto=13.5)
PAINEIS.append(("Escala, de frente: jogador (1,2 m), os três comuns e os três chefes", render("escala")))
mirar((30, -30, 20), (0.3, 0, 1.4), orto=13.5)
PAINEIS.append(("Os mesmos, de cima e de lado", render("escala2")))

# ---------- folha ----------
G, TOPO = 16, 46
W = 2 * PW + 3 * G
H = 3 * (PH + TOPO) + 4 * G
tela = np.zeros((H, W, 4), np.float32)
tela[..., :3] = (0.09, 0.10, 0.11)
tela[..., 3] = 1
for k, (_, png) in enumerate(PAINEIS):
    im = bpy.data.images.load(png)
    px = np.array(im.pixels[:], np.float32).reshape(PH, PW, 4)
    c, r = k % 2, k // 2
    x0 = G + c * (PW + G)
    y0 = G + (2 - r) * (PH + TOPO + G)
    tela[y0:y0 + PH, x0:x0 + PW] = px
out = bpy.data.images.new("folha", W, H, alpha=False)
out.pixels[:] = tela.ravel()
out.filepath_raw = SAIDA
out.file_format = "PNG"
out.save()
fb = blf.load("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
ib = imbuf.load(SAIDA)
with blf.bind_imbuf(fb, ib):
    for k, (titulo, _) in enumerate(PAINEIS):
        c, r = k % 2, k // 2
        blf.size(fb, 24)
        blf.color(fb, 0.95, 0.95, 0.92, 1)
        blf.position(fb, G + c * (PW + G), G + (2 - r) * (PH + TOPO + G) + PH + 14, 0)
        blf.draw_buffer(fb, titulo)
imbuf.write(ib, filepath=SAIDA)
print("ok", SAIDA, W, H)
