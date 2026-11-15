# Sentinela (máquina agressiva do vale) em peças para o jogo animar por código.
# blender -b --factory-startup -P tools/vale/sentinela.py -- <assets/vale>
# Peças (Z para cima no Blender = Y no jogo; frente = -Y no Blender):
#   cabeca  origem no centro da cabeça; filhas: musgo, cinta, aro, lente, pescoco, antena
#   coxa    tubo de comprimento 1 da origem até +Z (o jogo estica e aponta)
#   canela  idem, mais fino
#   joelho  esfera na origem
#   pe      sapata com a origem no chão
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

DEST = sys.argv[sys.argv.index("--") + 1]
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)
col = bpy.context.scene.collection


def mat(nome):
    return bpy.data.materials.get(nome) or bpy.data.materials.new(nome)


def obj(nome, bm, material, pai=None, liso=True):
    me = bpy.data.meshes.new(nome)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat(material))
    if liso:
        me.shade_smooth()
    ob = bpy.data.objects.new(nome, me)
    col.objects.link(ob)
    if pai is not None:
        ob.parent = pai
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



bm = bmesh.new()
elips(bm, (0, 0, 0), (0.62, 0.70, 0.36))
cabeca = obj("cabeca", bm, "casco")
bm = bmesh.new()
elips(bm, (0, 0.08, 0.10), (0.55, 0.58, 0.34), corte=0.2)
obj("musgo", bm, "musgo", cabeca)
bm = bmesh.new()
toro(bm, (0, 0, -0.12), (0, 0, 1), 0.60, 0.07, 28, 8)
obj("cinta", bm, "ferrugem", cabeca)
bm = bmesh.new()
toro(bm, (0, -0.645, -0.02), (0, -1, 0), 0.21, 0.05, 20, 8)
obj("aro", bm, "junta", cabeca)
bm = bmesh.new()
elips(bm, (0, -0.66, -0.02), (0.17, 0.17, 0.17), 14, 10)
obj("lente", bm, "lente", cabeca)
bm = bmesh.new()
tubo(bm, [(0, 0, -0.3), (0, 0, -0.62)], [0.22, 0.16])
obj("pescoco", bm, "junta", cabeca)
bm = bmesh.new()
tubo(bm, [(0.3, 0.3, 0.3), (0.42, 0.42, 1.0)], [0.02, 0.008], 5)
obj("antena", bm, "junta", cabeca)
bm = bmesh.new()
tubo(bm, [(0, 0, 0), (0, 0, 1)], [0.10, 0.075])
obj("coxa", bm, "casco_claro")
bm = bmesh.new()
tubo(bm, [(0, 0, 0), (0, 0, 1)], [0.07, 0.05])
obj("canela", bm, "casco_claro")
bm = bmesh.new()
elips(bm, (0, 0, 0), (0.13, 0.13, 0.13), 12, 8)
obj("joelho", bm, "junta")
bm = bmesh.new()
elips(bm, (0, 0, 0.07), (0.20, 0.20, 0.09), 12, 8)
obj("pe", bm, "junta")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(DEST, "sentinela.glb"), export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True)
print("FEITO sentinela", flush=True)
