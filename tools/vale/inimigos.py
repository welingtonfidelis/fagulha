# Os robôs inimigos de Fagulha (2026-11-20), do próprio projeto, feitos por script como o robô do jogador.
# Três famílias de máquina comum (a Lata, o Guarda e o Barril) e três chefes (o Colosso, a Lâmina e o
# Artilheiro), aprovadas pelo usuário na folha de `tools/vale/inimigos_estudo.py`.
#
#   blender -b --factory-startup -P tools/vale/inimigos.py -- assets/vale/inimigos
#
# Cada robô sai num .glb com as juntas como nós vazios (o jogo gira as juntas; não há esqueleto nem
# animação gravada): raiz > tronco > cabeca, ombroE/D > cotoveloE/D > bocaE/D, quadrilE/D > joelhoE/D
# (o Artilheiro tem também quadrilE2/D2 > joelhoE2/D2). De frente para -Y aqui, +Z na Godot; a esquerda
# do robô é +X. O braço pende reto para baixo: o cano e a lâmina seguem o eixo do braço, como no jogador.
# As armas são peças com nome `arma_canhao*`, `arma_lamina*` e `arma_misseis*`; o jogo mostra a que vale.
# Materiais: placa, placa_clara, escuro, grafite, aco, lente, boca, missil (o jogo pinta por nome).
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
PASTA = os.path.abspath(argv[0])
os.makedirs(PASTA, exist_ok=True)
R = math.radians
scene = bpy.context.scene
col = scene.collection


def mat(nome, cor, luz=0.0):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = cor + (1,)
    p.inputs["Roughness"].default_value = 0.55
    if luz > 0.0:
        p.inputs["Emission Color"].default_value = cor + (1,)
        p.inputs["Emission Strength"].default_value = luz
    return m


def _m(centro, rot):
    return Matrix.Translation(centro) @ Matrix.Rotation(R(rot[2]), 4, "Z") @ Matrix.Rotation(R(rot[1]), 4, "Y") \
        @ Matrix.Rotation(R(rot[0]), 4, "X")


class Robo:
    def __init__(self, nome, e=1.0):
        for ob in list(bpy.data.objects):
            bpy.data.objects.remove(ob)
        for m in list(bpy.data.materials):
            bpy.data.materials.remove(m)
        self.nome = nome
        self.e = e
        self.M = {
            "placa": mat("placa", (0.3, 0.3, 0.3)), "placa_clara": mat("placa_clara", (0.5, 0.5, 0.5)),
            "escuro": mat("escuro", (0.035, 0.04, 0.045)), "grafite": mat("grafite", (0.10, 0.11, 0.12)),
            "aco": mat("aco", (0.32, 0.33, 0.34)), "lente": mat("lente", (1.0, 0.3, 0.1), 4.0),
            "boca": mat("boca", (1.0, 0.6, 0.2), 2.0), "missil": mat("missil", (0.8, 0.1, 0.05)),
        }
        self.J = {}
        self.modelo = bpy.data.objects.new("modelo", None)
        col.objects.link(self.modelo)
        bpy.context.view_layer.update()
        self.n = 0

    def p(self, c):
        return (c[0] * self.e, c[1] * self.e, c[2] * self.e)

    def junta(self, nome, loc, pai=None):
        j = bpy.data.objects.new(nome, None)
        j.empty_display_size = 0.05
        j.location = self.p(loc)
        col.objects.link(j)
        bpy.context.view_layer.update()
        dono = self.J[pai] if pai else self.modelo
        j.parent = dono
        j.matrix_parent_inverse = dono.matrix_world.inverted()
        bpy.context.view_layer.update()
        self.J[nome] = j
        return j

    def _malha(self, nome, bm, m, pai, bevel, segs):
        me = bpy.data.meshes.new(nome)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(self.M[m])
        self.n += 1
        ob = bpy.data.objects.new("%s_%d" % (nome, self.n), me)
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
        bpy.context.view_layer.update()
        dono = self.J[pai]
        ob.parent = dono
        ob.matrix_parent_inverse = dono.matrix_world.inverted()
        return ob

    def cx(self, pai, c, t, m, base=(1, 1), topo=(1, 1), rot=(0, 0, 0), bevel=0.02, segs=2, nome="p"):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            f = topo if v.co.z > 0 else base
            v.co.x *= t[0] * f[0] * self.e
            v.co.y *= t[1] * f[1] * self.e
            v.co.z *= t[2] * self.e
        bmesh.ops.transform(bm, matrix=_m(self.p(c), rot), verts=bm.verts)
        return self._malha(nome, bm, m, pai, bevel * self.e, segs)

    def ci(self, pai, c, r1, r2, comp, m, rot=(0, 0, 0), segs=14, bevel=0.01, nome="p"):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1 * self.e, radius2=r2 * self.e,
                              depth=comp * self.e, matrix=_m(self.p(c), rot))
        return self._malha(nome, bm, m, pai, bevel * self.e, 1)

    def es(self, pai, c, raios, m, u=16, v=10, nome="p"):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
        for vv in bm.verts:
            vv.co.x *= raios[0] * self.e
            vv.co.y *= raios[1] * self.e
            vv.co.z *= raios[2] * self.e
        bmesh.ops.transform(bm, matrix=Matrix.Translation(self.p(c)), verts=bm.verts)
        return self._malha(nome, bm, m, pai, 0, 1)

    # ---- as armas, no eixo do braço (o braço pende para baixo; apontando, o ombro gira 90°) ----
    def canhao(self, lado, x, z_luva, duplo=False, tam=1.0):
        """Cano que sai por baixo da luva. `z_luva` é a base da luva; a boca fica na junta `boca<lado>`."""
        pai = "cotovelo" + lado
        for dx in ((-0.055, 0.055) if duplo else (0.0,)):
            self.ci(pai, (x + dx * tam, 0, z_luva - 0.07 * tam), 0.05 * tam, 0.045 * tam, 0.16 * tam, "aco", segs=12, nome="arma_canhao")
            self.ci(pai, (x + dx * tam, 0, z_luva - 0.155 * tam), 0.03 * tam, 0.03 * tam, 0.012 * tam, "boca", segs=10, bevel=0, nome="arma_canhao")
        self.cx(pai, (x, 0, z_luva + 0.02 * tam), (0.2 * tam if duplo else 0.14 * tam, 0.14 * tam, 0.05 * tam), "grafite", bevel=0.015, nome="arma_canhao")

    def punho_lamina(self, lado, x, z_luva, tam=1.0):
        """O emissor da lâmina (a lâmina de luz é do jogo, e só aparece no golpe)."""
        pai = "cotovelo" + lado
        self.cx(pai, (x, 0, z_luva - 0.03 * tam), (0.09 * tam, 0.13 * tam, 0.08 * tam), "aco", base=(0.7, 0.7), bevel=0.015, nome="arma_lamina")
        self.cx(pai, (x, 0, z_luva - 0.075 * tam), (0.03 * tam, 0.09 * tam, 0.012 * tam), "boca", bevel=0, nome="arma_lamina")

    def misseis(self, x, z, y=0.05, tam=1.0, lado=1.0):
        self.cx("tronco", (x, y, z), (0.3 * tam, 0.36 * tam, 0.26 * tam), "grafite", rot=(-12, 0, lado * 4), bevel=0.03, nome="arma_misseis")
        for i in (-1, 1):
            for j in (-1, 1):
                self.ci("tronco", (x + i * 0.07 * tam, y - 0.17 * tam, z + j * 0.06 * tam + 0.035 * tam), 0.04 * tam, 0.04 * tam, 0.04 * tam,
                        "missil" if (i + j) != 0 else "escuro", rot=(78, 0, 0), segs=10, bevel=0, nome="arma_misseis")

    def exportar(self):
        for ob in bpy.data.objects:
            ob.select_set(True)
        caminho = os.path.join(PASTA, self.nome + ".glb")
        bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB", use_selection=True, export_apply=True,
                                  export_yup=True, export_animations=False)
        print("exportado", caminho, len(bpy.data.objects), "objetos")


# ---------------------------------------------------------------- A Lata (e o Colosso)
def lata(nome, e=1.0, chefe=False):
    r = Robo(nome, e)
    r.junta("raiz", (0, 0, 0.62))
    r.junta("tronco", (0, 0, 0.75), "raiz")
    r.junta("cabeca", (0, 0, 1.35), "tronco")
    for lado, s in (("E", 1), ("D", -1)):
        r.junta("ombro" + lado, (s * 0.52, 0, 1.24), "tronco")
        r.junta("cotovelo" + lado, (s * 0.57, 0, 0.92), "ombro" + lado)
        r.junta("boca" + lado, (s * 0.57, 0, 0.36 if not chefe else 0.3), "cotovelo" + lado)
        r.junta("quadril" + lado, (s * 0.2, 0, 0.6), "raiz")
        r.junta("joelho" + lado, (s * 0.2, 0, 0.36), "quadril" + lado)
        q, jo, om, co = "quadril" + lado, "joelho" + lado, "ombro" + lado, "cotovelo" + lado
        r.ci(q, (s * 0.2, 0, 0.48), 0.085, 0.085, 0.26, "grafite")
        r.cx(jo, (s * 0.2, -0.07, 0.36), (0.2, 0.08, 0.2), "placa_clara", bevel=0.04)
        r.ci(jo, (s * 0.2, 0, 0.24), 0.085, 0.085, 0.26, "grafite")
        r.cx(jo, (s * 0.22, -0.04, 0.07), (0.26, 0.4, 0.14), "escuro", topo=(0.8, 0.7), bevel=0.04)
        r.es(om, (s * 0.52, 0, 1.24), (0.16, 0.16, 0.16), "escuro")
        if chefe:
            r.cx(om, (s * 0.62, 0.02, 1.42), (0.4, 0.44, 0.26), "placa", rot=(0, s * -18, 0), bevel=0.06)
        else:
            r.cx(om, (s * 0.55, 0, 1.3), (0.26, 0.32, 0.12), "placa", rot=(0, s * -14, 0), bevel=0.04)
        r.ci(om, (s * 0.57, 0, 1.07), 0.075, 0.075, 0.28, "grafite")
        r.ci(co, (s * 0.57, 0, 0.86), 0.07, 0.07, 0.16, "grafite")
        if chefe:
            r.cx(co, (s * 0.57, 0, 0.62), (0.3, 0.34, 0.34), "placa", bevel=0.06)
            r.canhao(lado, s * 0.57, 0.45, duplo=True, tam=1.2)
        else:
            r.cx(co, (s * 0.57, 0, 0.66), (0.22, 0.26, 0.28), "placa_clara", base=(0.85, 0.85), bevel=0.05)
    r.cx("raiz", (0, 0, 0.66), (0.5, 0.32, 0.18), "escuro", bevel=0.04)
    r.cx("tronco", (0, 0, 1.04), (0.8, 0.52, 0.62), "placa", base=(0.78, 0.86), bevel=0.07, segs=3)
    r.cx("tronco", (0, -0.265, 1.1), (0.42, 0.03, 0.3), "placa_clara", bevel=0.03)
    for k in range(3):
        r.cx("tronco", (0, -0.285, 1.02 + k * 0.08), (0.3, 0.015, 0.03), "escuro", bevel=0)
    r.ci("tronco", (0, 0, 1.36), 0.2, 0.2, 0.06, "escuro")
    r.es("cabeca", (0, 0, 1.4), (0.27, 0.27, 0.21), "placa_clara")
    r.ci("cabeca", (0, -0.235, 1.43), 0.115, 0.115, 0.08, "escuro", rot=(90, 0, 0))
    r.ci("cabeca", (0, -0.275, 1.43), 0.08, 0.08, 0.02, "lente", rot=(90, 0, 0), bevel=0)
    r.ci("cabeca", (0.14, 0.05, 1.68), 0.012, 0.012, 0.26, "aco", segs=8, bevel=0)
    r.es("cabeca", (0.14, 0.05, 1.82), (0.03, 0.03, 0.03), "lente", u=8, v=6)
    if chefe:
        r.ci("tronco", (0, -0.29, 0.86), 0.09, 0.09, 0.03, "lente", rot=(90, 0, 0), bevel=0)
        r.cx("tronco", (0, 0.3, 1.2), (0.5, 0.2, 0.5), "grafite", bevel=0.05)
    else:
        r.canhao("D", -0.57, 0.52)
        r.punho_lamina("D", -0.57, 0.52)
        r.misseis(0.5, 1.5, lado=1.0)
        r.misseis(-0.5, 1.5, lado=-1.0)
    r.junta("bocaM", (0.5, -0.24, 1.52), "tronco")
    r.exportar()


# ---------------------------------------------------------------- O Guarda (e a Lâmina)
def guarda(nome, e=1.0, chefe=False):
    r = Robo(nome, e)
    r.junta("raiz", (0, 0, 1.0))
    r.junta("tronco", (0, 0, 1.14), "raiz")
    r.junta("cabeca", (0, 0, 1.68), "tronco")
    for lado, s in (("E", 1), ("D", -1)):
        r.junta("ombro" + lado, (s * 0.5, 0, 1.58), "tronco")
        r.junta("cotovelo" + lado, (s * 0.5, 0, 1.22), "ombro" + lado)
        r.junta("boca" + lado, (s * 0.5, 0, 0.72), "cotovelo" + lado)
        r.junta("quadril" + lado, (s * 0.2, -0.1, 1.0), "raiz")
        r.junta("joelho" + lado, (s * 0.2, 0.12, 0.56), "quadril" + lado)
        q, jo, om, co = "quadril" + lado, "joelho" + lado, "ombro" + lado, "cotovelo" + lado
        r.cx(q, (s * 0.2, 0.0, 0.78), (0.15, 0.18, 0.52), "placa", rot=(24, 0, 0), bevel=0.04)
        r.ci(jo, (s * 0.2, 0.12, 0.56), 0.07, 0.07, 0.17, "escuro", rot=(0, 90, 0))
        r.cx(jo, (s * 0.2, 0.05, 0.32), (0.1, 0.12, 0.54), "grafite", rot=(-22, 0, 0))
        r.cx(jo, (s * 0.2, -0.12, 0.05), (0.17, 0.36, 0.1), "escuro", topo=(0.8, 0.6), bevel=0.03)
        r.cx(om, (s * 0.5, 0.0, 1.62), (0.28, 0.36, 0.2), "placa", rot=(0, s * -16, 0), topo=(0.8, 0.8), bevel=0.05)
        r.cx(om, (s * 0.5, 0.0, 1.38), (0.1, 0.1, 0.3), "grafite")
        r.cx(co, (s * 0.5, 0.0, 1.1), (0.09, 0.09, 0.26), "grafite")
        r.cx(co, (s * 0.5, 0.0, 0.92), (0.17, 0.22, 0.26), "placa_clara", bevel=0.04)
        if chefe:
            r.punho_lamina(lado, s * 0.5, 0.79, tam=1.2)
            r.cx("tronco", (s * 0.3, 0.26, 1.78), (0.05, 0.4, 0.62), "placa_clara", rot=(-34, 0, s * 16), topo=(1, 0.3), bevel=0.02)
        r.cx("tronco", (s * 0.16, 0.2, 1.62), (0.05, 0.3, 0.4), "grafite", rot=(-28, 0, s * 10), topo=(1, 0.4), bevel=0.02)
    r.cx("raiz", (0, 0, 1.04), (0.38, 0.24, 0.16), "escuro", bevel=0.04)
    r.ci("tronco", (0, 0, 1.16), 0.1, 0.1, 0.12, "grafite")
    r.cx("tronco", (0, 0, 1.44), (0.72, 0.38, 0.48), "placa", base=(0.5, 0.8), bevel=0.06, segs=3)
    r.cx("tronco", (0, -0.19, 1.48), (0.3, 0.03, 0.26), "placa_clara", base=(0.6, 1), bevel=0.03)
    r.cx("cabeca", (0, -0.02, 1.78), (0.44, 0.32, 0.17), "grafite", base=(0.85, 0.9), bevel=0.05)
    r.cx("cabeca", (0, -0.17, 1.78), (0.36, 0.03, 0.05), "lente", bevel=0.01, segs=1)
    if chefe:
        r.cx("cabeca", (0, 0.02, 1.95), (0.06, 0.3, 0.22), "placa_clara", topo=(1, 0.4), bevel=0.02)
    else:
        r.canhao("D", -0.5, 0.79)
        r.punho_lamina("D", -0.5, 0.79)
        r.misseis(0.34, 1.86, y=0.16, tam=0.85, lado=1.0)
        r.misseis(-0.34, 1.86, y=0.16, tam=0.85, lado=-1.0)
    r.junta("bocaM", (0.34, -0.02, 1.88), "tronco")
    r.exportar()


# ---------------------------------------------------------------- O Barril (e o Artilheiro)
def barril(nome, e=1.0, chefe=False):
    r = Robo(nome, e)
    r.junta("raiz", (0, 0, 0.55))
    r.junta("tronco", (0, 0, 0.6), "raiz")
    r.junta("cabeca", (0, 0, 1.3), "tronco")
    pernas = [("E", 0.2, 0.0), ("D", -0.2, 0.0)] if not chefe else [("E", 0.3, -0.16), ("D", -0.3, -0.16), ("E2", 0.3, 0.2), ("D2", -0.3, 0.2)]
    for lado, x, y in pernas:
        r.junta("quadril" + lado, (x, y, 0.55), "raiz")
        r.junta("joelho" + lado, (x, y, 0.3), "quadril" + lado)
        r.ci("quadril" + lado, (x, y, 0.43), 0.065, 0.065, 0.26, "grafite")
        r.ci("joelho" + lado, (x, y, 0.3), 0.09, 0.09, 0.1, "escuro")
        r.ci("joelho" + lado, (x, y, 0.18), 0.065, 0.065, 0.24, "grafite")
        r.cx("joelho" + lado, (x, y - 0.05, 0.05), (0.24, 0.32, 0.1), "escuro", topo=(0.7, 0.7), bevel=0.04)
    r.ci("tronco", (0, 0, 0.98), 0.38, 0.43, 0.86, "placa", segs=20, bevel=0.05)
    r.ci("tronco", (0, 0, 0.72), 0.445, 0.445, 0.07, "escuro", segs=20)
    r.ci("tronco", (0, 0, 1.24), 0.41, 0.41, 0.05, "escuro", segs=20)
    r.ci("tronco", (0, -0.4, 1.0), 0.17, 0.17, 0.1, "escuro", rot=(90, 0, 0), segs=16)
    r.ci("tronco", (0, -0.45, 1.0), 0.12, 0.12, 0.02, "lente", rot=(90, 0, 0), bevel=0, segs=16)
    r.es("cabeca", (0, 0, 1.4), (0.38, 0.38, 0.15), "grafite")
    r.cx("cabeca", (0, 0, 1.58), (0.26, 0.05, 0.05), "aco", bevel=0.02)
    for lado, s in (("E", 1), ("D", -1)):
        r.cx("cabeca", (s * 0.11, 0, 1.52), (0.04, 0.05, 0.12), "aco", bevel=0.01)
        r.junta("ombro" + lado, (s * 0.47, 0, 1.04), "tronco")
        r.junta("cotovelo" + lado, (s * 0.52, 0, 0.84), "ombro" + lado)
        r.junta("boca" + lado, (s * 0.52, 0, 0.3), "cotovelo" + lado)
        r.es("ombro" + lado, (s * 0.47, 0, 1.04), (0.11, 0.11, 0.11), "escuro")
        r.ci("ombro" + lado, (s * 0.52, 0, 0.93), 0.06, 0.06, 0.2, "grafite")
        r.ci("cotovelo" + lado, (s * 0.52, 0, 0.76), 0.055, 0.055, 0.16, "grafite")
        r.cx("cotovelo" + lado, (s * 0.52, 0, 0.58), (0.2, 0.24, 0.24), "placa_clara", base=(0.85, 0.85), bevel=0.05)
    if chefe:
        for s in (-1, 1):
            r.misseis(s * 0.36, 1.66, y=0.05, tam=1.0, lado=s)
            r.misseis(s * 0.66, 1.3, y=0.05, tam=0.9, lado=s)
        r.ci("tronco", (0, -0.52, 0.72), 0.07, 0.08, 0.34, "aco", rot=(90, 0, 0))
        r.ci("tronco", (0, -0.7, 0.72), 0.05, 0.05, 0.02, "boca", rot=(90, 0, 0), bevel=0)
        r.junta("bocaM", (0.36, -0.2, 1.7), "tronco")
    else:
        r.canhao("D", -0.52, 0.46)
        r.punho_lamina("D", -0.52, 0.46)
        r.misseis(0.0, 1.66, y=0.04, tam=0.95)
        r.junta("bocaM", (0.0, -0.2, 1.7), "tronco")
    r.exportar()


lata("lata")
guarda("guarda")
barril("barril")
lata("colosso", e=1.72, chefe=True)
guarda("lamina", e=1.55, chefe=True)
barril("artilheiro", e=1.75, chefe=True)
