# Os gigantes do Sono dos Gigantes (2026-11-20): robôs colossais de obra, do próprio projeto, no lugar dos
# mechas de pacote. Três modelos (a Escavadeira, o Guindaste e o Bate-estaca), aprovados pelo usuário na
# folha de `tools/vale/gigantes_estudo.py` (a Betoneira saiu). São estáticos: o jogo os deita ou enterra.
#
#   blender -b --factory-startup -P tools/vale/gigantes.py -- assets/vale/gigantes
#
# Saem de pé, com os pés na origem, de frente para -Y (+Z na Godot). O corpo tem 2,06 unidades de altura
# (até o capacete); a lança do guindaste e a torre do bate-estaca passam disso. Materiais: amarelo,
# amarelo_velho, laranja, branco, preto, grafite, aco, vidro, ferrugem, lente (o jogo pinta por nome,
# desbotado, com ferrugem e musgo).
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
PASTA = os.path.abspath(argv[0])
os.makedirs(PASTA, exist_ok=True)
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



for nome, feito in (("escavadeira", escavadeira), ("guindaste", guindaste), ("bate_estaca", bate_estaca)):
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    raiz = bpy.data.objects.new("modelo", None)
    col.objects.link(raiz)
    feito(raiz)
    n = 0
    for ob in bpy.data.objects:
        ob.select_set(True)
        if ob.type == "MESH":
            n += 1
            ob.name = "%s_%02d" % (nome, n)
    caminho = os.path.join(PASTA, nome + ".glb")
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_animations=False)
    print("exportado", caminho, n, "peças")
