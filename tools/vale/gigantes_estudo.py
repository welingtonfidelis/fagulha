# Estudo dos gigantes do Sono dos Gigantes (2026-11-20): robôs colossais de construção, do próprio projeto,
# para o lugar dos mechas de pacote deitados. É só uma folha para discutir: nada daqui vai ao jogo.
# Folha:  blender -b --factory-startup -P tools/vale/gigantes_estudo.py -- /caminho/folha.png
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


def mat(nome, cor, metal=0.0, rug=0.6, luz=0.0):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = cor + (1,)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rug
    if luz:
        p.inputs["Emission Color"].default_value = cor + (1,)
        p.inputs["Emission Strength"].default_value = luz
    return m


AMARELO = mat("amarelo", (0.62, 0.42, 0.03))
AMARELO_VELHO = mat("amarelo_velho", (0.50, 0.38, 0.12))
LARANJA = mat("laranja", (0.62, 0.20, 0.03))
BRANCO = mat("branco", (0.55, 0.54, 0.50))
PRETO = mat("preto", (0.03, 0.03, 0.035))
GRAFITE = mat("grafite", (0.10, 0.11, 0.12), 0.2)
ACO = mat("aco", (0.30, 0.31, 0.32), 0.6, 0.45)
VIDRO = mat("vidro", (0.03, 0.08, 0.10), 0.0, 0.15)
FERRUGEM = mat("ferrugem", (0.28, 0.12, 0.05))
LENTE = mat("lente", (1.0, 0.6, 0.15), luz=3.0)
VERDE = mat("verde", (0.12, 0.30, 0.08), 0.0, 0.9)
TERRA = mat("terra", (0.16, 0.20, 0.10), 0.0, 0.95)
AZUL = mat("azul", (0.01, 0.08, 0.4))


def _m(c, rot):
    return Matrix.Translation(c) @ Matrix.Rotation(R(rot[2]), 4, "Z") @ Matrix.Rotation(R(rot[1]), 4, "Y") \
        @ Matrix.Rotation(R(rot[0]), 4, "X")


def _malha(bm, m, pai, bevel, segs=2):
    me = bpy.data.meshes.new("p")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(m)
    ob = bpy.data.objects.new("p", me)
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


class G:
    """Um gigante montado de pé na origem do grupo dele (de frente para -Y), em unidades de ~2 = a altura."""

    def __init__(self, pai):
        self.pai = pai

    def cx(self, c, t, m, base=(1, 1), topo=(1, 1), rot=(0, 0, 0), bevel=0.02):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            f = topo if v.co.z > 0 else base
            v.co.x *= t[0] * f[0]
            v.co.y *= t[1] * f[1]
            v.co.z *= t[2]
        bmesh.ops.transform(bm, matrix=_m(c, rot), verts=bm.verts)
        return _malha(bm, m, self.pai, bevel)

    def ci(self, c, r1, r2, comp, m, rot=(0, 0, 0), segs=18, bevel=0.01):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=comp, matrix=_m(c, rot))
        return _malha(bm, m, self.pai, bevel, 1)

    def faixa(self, c, comp, alt, eixo="x", n=7, y=0.0):
        """Faixa de perigo: quadros pretos e amarelos alternados."""
        for k in range(n):
            d = (k - (n - 1) / 2) * comp / n
            p = (c[0] + d, c[1], c[2]) if eixo == "x" else (c[0], c[1] + d, c[2])
            t = (comp / n, 0.012, alt) if eixo == "x" else (0.012, comp / n, alt)
            self.cx(p, t, PRETO if k % 2 == 0 else AMARELO, bevel=0)

    def esteira(self, x, comp=0.62, alt=0.3, larg=0.26):
        """Uma esteira de trator no lugar do pé."""
        self.cx((x, 0, alt * 0.5), (larg, comp, alt), PRETO, base=(1, 0.8), topo=(1, 0.86), bevel=0.06)
        for k in range(3):
            self.ci((x, -comp * 0.3 + k * comp * 0.3, alt * 0.5), alt * 0.3, alt * 0.3, larg + 0.03, GRAFITE, rot=(0, 90, 0), segs=10)

    def pernas(self, x=0.27, m=AMARELO):
        for s in (-1, 1):
            self.esteira(s * x)
            self.cx((s * x, 0.02, 0.48), (0.2, 0.24, 0.4), GRAFITE, bevel=0.03)
            self.ci((s * x, 0.02, 0.68), 0.12, 0.12, 0.24, PRETO, rot=(0, 90, 0), segs=12)
            self.cx((s * x, 0.0, 0.84), (0.24, 0.3, 0.3), m, base=(0.85, 0.85), bevel=0.04)
        self.cx((0, 0, 0.98), (0.7, 0.4, 0.16), GRAFITE, bevel=0.04)

    def cabine(self, z, capacete=BRANCO, larg=0.36):
        """A cabeça é uma cabine de operador vazia, com capacete de obra por cima."""
        self.cx((0, -0.02, z), (larg, 0.34, 0.26), GRAFITE, bevel=0.04)
        self.cx((0, -0.19, z + 0.01), (larg - 0.08, 0.02, 0.15), VIDRO, bevel=0.01)
        self.cx((0, -0.02, z + 0.16), (larg + 0.06, 0.42, 0.1), capacete, topo=(0.8, 0.8), bevel=0.04)
        self.cx((0, -0.24, z + 0.115), (larg + 0.04, 0.12, 0.025), capacete, bevel=0.01)
        self.ci((0.1, -0.205, z - 0.085), 0.03, 0.03, 0.02, LENTE, rot=(90, 0, 0), segs=10, bevel=0)

    def braco(self, s, z, m=AMARELO):
        self.ci((s * 0.56, 0, z), 0.15, 0.15, 0.2, PRETO, rot=(0, 90, 0), segs=14)
        self.cx((s * 0.62, 0, z - 0.3), (0.2, 0.24, 0.5), m, bevel=0.04)
        self.ci((s * 0.62, 0, z - 0.58), 0.1, 0.1, 0.22, PRETO, rot=(0, 90, 0), segs=12)


# ---------------------------------------------------------------- 1. A Escavadeira
def escavadeira(pai):
    g = G(pai)
    g.pernas()
    g.cx((0, 0, 1.4), (0.92, 0.56, 0.7), AMARELO, base=(0.82, 0.9), bevel=0.06)
    g.faixa((0, -0.285, 1.14), 0.7, 0.07)
    g.cx((0, 0.32, 1.42), (0.6, 0.16, 0.5), GRAFITE, bevel=0.04)  # o motor nas costas
    for k in range(4):
        g.cx((-0.2 + k * 0.13, 0.405, 1.42), (0.05, 0.01, 0.36), PRETO, bevel=0)
    g.ci((0.3, 0.3, 1.86), 0.04, 0.04, 0.3, ACO, segs=8)  # escapamento
    g.cabine(1.9)
    g.braco(1, 1.6)
    g.cx((0.62, -0.04, 0.78), (0.22, 0.3, 0.3), AMARELO, base=(0.8, 0.8), bevel=0.05)  # mão esquerda: um punho
    # o braço direito é a lança: dois trechos, pistões e a caçamba de dentes
    g.ci((-0.56, 0, 1.6), 0.15, 0.15, 0.2, PRETO, rot=(0, 90, 0), segs=14)
    g.cx((-0.62, -0.26, 1.72), (0.16, 0.74, 0.2), AMARELO, rot=(24, 0, 0), bevel=0.04)
    g.ci((-0.62, -0.6, 1.87), 0.1, 0.1, 0.2, PRETO, rot=(0, 90, 0), segs=12)
    g.cx((-0.62, -0.74, 1.5), (0.13, 0.16, 0.8), AMARELO, rot=(-20, 0, 0), bevel=0.03)
    g.ci((-0.62, -0.42, 1.52), 0.03, 0.03, 0.62, ACO, rot=(60, 0, 0), segs=8)  # pistão
    g.cx((-0.62, -0.9, 1.02), (0.34, 0.3, 0.26), FERRUGEM, base=(0.9, 0.5), rot=(20, 0, 0), bevel=0.03)
    for k in range(4):
        g.cx((-0.74 + k * 0.08, -1.02, 0.9), (0.04, 0.1, 0.05), ACO, rot=(35, 0, 0), bevel=0.01)


# ---------------------------------------------------------------- 2. O Guindaste
def guindaste(pai):
    g = G(pai)
    g.pernas(m=LARANJA)
    g.cx((0, 0, 1.36), (0.74, 0.5, 0.62), LARANJA, base=(0.7, 0.85), bevel=0.06)
    g.faixa((0, -0.255, 1.1), 0.5, 0.07)
    g.cx((0, 0.42, 1.22), (0.6, 0.34, 0.34), GRAFITE, bevel=0.05)  # o contrapeso
    g.cx((0, 0.42, 1.44), (0.5, 0.26, 0.1), FERRUGEM, bevel=0.03)
    g.cabine(1.82, capacete=AMARELO, larg=0.32)
    g.braco(1, 1.54, LARANJA)
    g.cx((0.62, -0.04, 0.74), (0.2, 0.26, 0.28), LARANJA, base=(0.8, 0.8), bevel=0.05)
    # a lança treliçada sai do ombro direito e sobe; do topo desce o cabo com o gancho
    g.ci((-0.5, 0, 1.56), 0.15, 0.15, 0.2, PRETO, rot=(0, 90, 0), segs=14)
    a = Vector((-0.6, 0.0, 1.6))
    b = Vector((-0.6, -0.95, 2.75))
    d = b - a
    ang = math.degrees(math.atan2(-d.y, d.z))
    for dx, dy in ((-0.06, -0.06), (0.06, -0.06), (-0.06, 0.06), (0.06, 0.06)):
        g.cx(tuple((a + b) / 2 + Vector((dx, dy * 0.8, dy * 0.6))), (0.025, 0.025, d.length), ACO, rot=(ang, 0, 0), bevel=0)
    for k in range(7):
        p = a + d * ((k + 0.5) / 7)
        g.cx(tuple(p), (0.15, 0.02, 0.15), ACO, rot=(ang + (45 if k % 2 else -45), 0, 0), bevel=0)
    g.ci(tuple(b), 0.05, 0.05, 0.16, PRETO, rot=(0, 90, 0), segs=10)
    g.ci((b.x, b.y, b.z - 0.55), 0.008, 0.008, 1.1, PRETO, segs=6, bevel=0)
    g.cx((b.x, b.y, b.z - 1.14), (0.1, 0.07, 0.12), AMARELO, bevel=0.02)
    g.cx((b.x, b.y - 0.02, b.z - 1.26), (0.03, 0.12, 0.12), ACO, base=(1, 0.3), bevel=0.01)
    g.ci((-0.6, 0.2, 2.0), 0.006, 0.006, 1.0, PRETO, rot=(-52, 0, 0), segs=6, bevel=0)  # o cabo de sustentação


# ---------------------------------------------------------------- 3. A Betoneira
# Refeita em 2026-11-20: na primeira o tambor subia por trás da cabeça e parecia a cabeça do robô.
#  - "mochila": tronco de chapa como os outros, cabeça bem acima, e o tambor baixo nas costas, abaixo dos ombros;
#  - "barriga": o tambor É o tronco, deitado num berço de vigas, com a cabine em cima, à frente.
def _tambor(g, c, incl, r=0.4, comp=0.9):
    """O tambor em pera, com as faixas, a boca e a calha. `incl` é quanto ele deita para trás."""
    eixo = Vector((0, math.sin(R(incl)), math.cos(R(incl))))
    g.ci(c, r, r * 0.62, comp, BRANCO, rot=(-incl, 0, 0), segs=20, bevel=0.03)
    for k in (-0.28, 0.0, 0.26):
        rr = r * (1.03 - (0.19 * (k + 0.5)) if k > 0 else 1.03 - 0.19 * (k + 0.5))
        p = Vector(c) + eixo * (k * comp)
        g.ci(tuple(p), rr, rr * 0.97, 0.07, LARANJA, rot=(-incl, 0, 0), segs=20, bevel=0)
    boca = Vector(c) + eixo * (comp * 0.56)
    g.ci(tuple(boca), r * 0.7, r * 0.5, 0.14, GRAFITE, rot=(-incl, 0, 0), segs=16)
    g.cx(tuple(boca + Vector((0, 0.26, -0.2))), (0.16, 0.5, 0.05), ACO, rot=(-38, 0, 0), bevel=0.01)
    fundo = Vector(c) - eixo * (comp * 0.5)
    g.ci(tuple(fundo), r * 0.6, r * 0.98, 0.06, GRAFITE, rot=(-incl, 0, 0), segs=20)


def betoneira(pai, variante="mochila"):
    g = G(pai)
    g.pernas(x=0.3, m=AMARELO_VELHO)
    if variante == "mochila":
        g.cx((0, 0, 1.4), (0.9, 0.5, 0.7), AMARELO_VELHO, base=(0.84, 0.9), bevel=0.06)
        g.cx((0, -0.255, 1.48), (0.46, 0.02, 0.3), BRANCO, bevel=0.02)
        g.faixa((0, -0.26, 1.14), 0.7, 0.07)
        # o berço nas costas e o tambor baixo, com a boca para cima e para trás, sem passar dos ombros
        for s in (-1, 1):
            g.cx((s * 0.3, 0.42, 1.12), (0.07, 0.4, 0.07), GRAFITE, bevel=0.01)
            g.cx((s * 0.3, 0.56, 1.3), (0.07, 0.07, 0.42), GRAFITE, rot=(28, 0, 0), bevel=0.01)
        _tambor(g, (0, 0.6, 1.36), 52, r=0.36, comp=0.8)
        z_cab, z_omb = 1.92, 1.6
    else:
        # o berço: duas vigas dos quadris aos ombros, e o tambor deitado entre elas
        for s in (-1, 1):
            g.cx((s * 0.46, 0.0, 1.36), (0.1, 0.34, 0.72), AMARELO_VELHO, bevel=0.03)
            g.ci((s * 0.46, 0.0, 1.4), 0.1, 0.1, 0.12, PRETO, rot=(0, 90, 0), segs=12)
        g.cx((0, 0, 1.04), (0.86, 0.5, 0.14), AMARELO_VELHO, bevel=0.04)
        g.faixa((0, -0.255, 1.04), 0.7, 0.07)
        _tambor(g, (0, 0.06, 1.42), 66, r=0.4, comp=0.92)
        g.cx((0, -0.1, 1.76), (1.02, 0.3, 0.1), AMARELO_VELHO, bevel=0.03)  # a travessa dos ombros
        z_cab, z_omb = 1.94, 1.66
    # a cabine fica à frente, numa base própria, bem separada do tambor
    g.cx((0, -0.1, z_cab - 0.16), (0.24, 0.24, 0.1), GRAFITE, bevel=0.02)
    cab = G(pai)
    cab.cabine(z_cab, capacete=LARANJA)
    for ob in list(pai.children)[-5:]:
        ob.location.y -= 0.1
    for s in (-1, 1):
        g.braco(s, z_omb, AMARELO_VELHO)
        # as mãos são rolos compactadores
        g.cx((s * 0.62, -0.06, z_omb - 0.68), (0.08, 0.3, 0.12), GRAFITE, bevel=0.02)
        g.ci((s * 0.62, -0.12, z_omb - 0.78), 0.13, 0.13, 0.34, ACO, rot=(0, 90, 0), segs=16)


# ---------------------------------------------------------------- 4. O Bate-estaca
def bate_estaca(pai):
    g = G(pai)
    g.pernas(m=AMARELO)
    g.cx((0, 0, 1.4), (0.8, 0.54, 0.7), BRANCO, base=(0.9, 0.9), topo=(0.8, 0.85), bevel=0.06)
    g.cx((0, -0.275, 1.46), (0.5, 0.02, 0.34), AMARELO, bevel=0.02)
    g.faixa((0, -0.29, 1.14), 0.62, 0.07)
    g.cabine(1.9, capacete=AMARELO)
    g.braco(1, 1.6)
    g.cx((0.62, -0.02, 0.84), (0.26, 0.3, 0.2), GRAFITE, bevel=0.04)  # a mão esquerda é uma garra
    for k in (-1, 1):
        g.cx((0.62 + k * 0.09, -0.04, 0.68), (0.05, 0.2, 0.2), ACO, base=(1, 0.5), bevel=0.01)
    # o braço direito é a torre do bate-estaca: a guia, o martelo e a estaca
    g.ci((-0.56, 0, 1.6), 0.15, 0.15, 0.2, PRETO, rot=(0, 90, 0), segs=14)
    g.cx((-0.66, -0.1, 1.5), (0.1, 0.1, 1.9), ACO, bevel=0.01)
    g.cx((-0.66, -0.1, 2.48), (0.2, 0.2, 0.08), GRAFITE, bevel=0.02)
    g.cx((-0.66, -0.22, 1.9), (0.22, 0.2, 0.4), LARANJA, bevel=0.04)
    g.faixa((-0.66, -0.325, 1.74), 0.2, 0.06, n=4)
    g.ci((-0.66, -0.22, 1.2), 0.06, 0.06, 1.0, FERRUGEM, segs=10)
    g.ci((-0.66, -0.22, 0.64), 0.06, 0.0, 0.14, FERRUGEM, segs=10, bevel=0)


def jogador(pai, x, e):
    """O robô do jogador (1,2 m), na escala de um gigante de 60 m: um pontinho."""
    g = G(pai)
    g.cx((x, 0, 0.6 * e), (0.4 * e, 0.4 * e, 1.2 * e), AZUL, bevel=0)


def grupo(nome):
    o = bpy.data.objects.new(nome, None)
    col.objects.link(o)
    return o


FEITOS = [("A Escavadeira", escavadeira), ("O Guindaste", guindaste), ("A Betoneira", betoneira), ("O Bate-estaca", bate_estaca)]
G_PE = grupo("de_pe")
for k, (_, f) in enumerate(FEITOS):
    sub = grupo("pe%d" % k)
    sub.parent = G_PE
    f(sub)
    sub.location = ((k - 1.5) * 2.3, 0, 0)

# a cena do lugar: um deitado de lado, meio enterrado, e um de pé, enterrado até a cintura, com mato
G_CENA = grupo("cena")
deitado = grupo("deitado")
deitado.parent = G_CENA
escavadeira(deitado)
deitado.rotation_euler = (R(-90), R(8), R(24))
deitado.location = (-1.6, 0.4, 0.2)
enterrado = grupo("enterrado")
enterrado.parent = G_CENA
guindaste(enterrado)
enterrado.rotation_euler = (R(4), R(-6), R(-30))
enterrado.location = (1.9, 0.6, -1.0)
gc = G(G_CENA)
import random
random.seed(4)
for k in range(46):
    x, y = random.uniform(-4.2, 4.2), random.uniform(-2.2, 2.6)
    s = random.uniform(0.12, 0.32)
    gc.ci((x, y, s * 0.9), s * 0.6, 0.0, s * 1.8, VERDE, segs=6, bevel=0)
for (x, y, z, s) in ((-1.9, 0.2, 0.62, 0.2), (-1.2, 0.7, 0.5, 0.16), (-2.3, 0.5, 0.56, 0.14), (1.9, 0.5, 1.0, 0.14), (1.6, 0.3, 0.45, 0.2)):
    gc.ci((x, y, z + s), s * 0.7, 0.0, s * 2.0, VERDE, segs=6, bevel=0)
jogador(G_CENA, -0.2, 2.0 / 60.0)
jogador(G_PE, 4.6, 2.0 / 60.0)
GRUPOS = [G_PE, G_CENA]


def so(g):
    for x in GRUPOS:
        x.location = (0, 0, 0) if x is g else (0, 0, -500)
    bpy.context.view_layer.update()


chao = bpy.data.objects.new("chao", bpy.data.meshes.new("chao"))
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60.0)
bm.to_mesh(chao.data)
bm.free()
MAT_CHAO = mat("chao", (0.13, 0.14, 0.15), 0.0, 0.9)
chao.data.materials.append(MAT_CHAO)
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
SO_BETONEIRA = os.environ.get("BETONEIRA") == "1"
if SO_BETONEIRA:
    G_B = grupo("betoneiras")
    GRUPOS.append(G_B)
    for k, var in enumerate(("mochila", "barriga")):
        sub = grupo("bet_" + var)
        sub.parent = G_B
        betoneira(sub, var)
        sub.location = ((k - 0.5) * 2.6, 0, 0)
    ref = grupo("ref")
    ref.parent = G_B
    escavadeira(ref)
    ref.location = (4.2, 0, 0)
    so(G_B)
    mirar((-3.0, -11.0, 2.6), (0.9, 0, 1.25), lente=58)
    PAINEIS.append(("Betoneira refeita · 1: tambor de mochila   ·   2: tambor no tronco   (à direita, a Escavadeira para comparar)", render("b_frente")))
    mirar((3.6, 11.0, 2.8), (0.6, 0, 1.25), lente=58)
    PAINEIS.append(("De costas", render("b_costas")))
    mirar((-30, 0.0, 1.3), (0, 0.0, 1.3), orto=6.5)
    ref.location = (4.2, 0, -500)
    list(G_B.children)[1].location.z = -500
    bpy.context.view_layer.update()
    PAINEIS.append(("2 · tambor no tronco, de lado", render("b_lado1")))
    list(G_B.children)[1].location.z = 0
    list(G_B.children)[0].location.z = -500
    bpy.context.view_layer.update()
    PAINEIS.append(("1 · tambor de mochila, de lado", render("b_lado2")))
    GRUPOS_FEITOS = True
if not SO_BETONEIRA:
    so(G_PE)
    mirar((-3.2, -16.0, 3.0), (0.2, 0, 1.3), lente=58)
    PAINEIS.append(("Quatro gigantes de obra: a Escavadeira, o Guindaste, a Betoneira e o Bate-estaca", render("g_frente")))
    mirar((3.6, 16.0, 3.2), (0.0, 0, 1.3), lente=58)
    PAINEIS.append(("De costas (o motor, o contrapeso, o tambor)", render("g_costas")))
    mirar((0.2, -30, 1.35), (0.2, 0, 1.35), orto=10.5)
    PAINEIS.append(("De frente, com o robô do jogador na escala de um gigante de 60 m (o risco azul à direita)", render("g_orto")))
    so(G_CENA)
    MAT_CHAO.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.10, 0.20, 0.06, 1)
    mirar((-5.5, -9.5, 3.4), (0.0, 0.2, 0.8), lente=42)
    PAINEIS.append(("No lugar: um deitado de lado e um de pé, enterrado até a cintura, com mato por cima", render("g_cena")))


G_, TOPO = 16, 46
W = 2 * PW + 3 * G_
H = 2 * (PH + TOPO) + 3 * G_
tela = np.zeros((H, W, 4), np.float32)
tela[..., :3] = (0.09, 0.10, 0.11)
tela[..., 3] = 1
for k, (_, png) in enumerate(PAINEIS):
    im = bpy.data.images.load(png)
    px = np.array(im.pixels[:], np.float32).reshape(PH, PW, 4)
    c, r = k % 2, k // 2
    x0 = G_ + c * (PW + G_)
    y0 = G_ + (1 - r) * (PH + TOPO + G_)
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
        blf.size(fb, 22)
        blf.color(fb, 0.95, 0.95, 0.92, 1)
        blf.position(fb, G_ + c * (PW + G_), G_ + (1 - r) * (PH + TOPO + G_) + PH + 14, 0)
        blf.draw_buffer(fb, titulo)
imbuf.write(ib, filepath=SAIDA)
print("ok", SAIDA, W, H)
