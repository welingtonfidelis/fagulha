# Arte do estilo pintado e sério: árvores de selva, moita, rochas talhadas e o arco de pedra.
# Só as formas; as cores vêm dos shaders na Godot (folha_estilo e terreno_estilo).
# blender -b --factory-startup -P tools/estilo/gerar.py -- <assets/estilo>
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

DEST = sys.argv[sys.argv.index("--") + 1]
os.makedirs(DEST, exist_ok=True)


def mat(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    return m


def limpar():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)


def objeto(nome, bm, material, liso=True):
    me = bpy.data.meshes.new(nome)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat(material))
    if liso:
        me.shade_smooth()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def exportar(nome):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(DEST, nome + ".glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    tris = sum(len(p.vertices) - 2 for ob in bpy.data.objects if ob.type == "MESH" for p in ob.data.polygons)
    print("FEITO", nome, tris, "tris", flush=True)


def tubo(bm, pontos, raios, lados=7):
    """Tubo ao longo de pontos (lista de Vector) com um raio por ponto."""
    aneis = []
    for i, p in enumerate(pontos):
        d = (pontos[min(i + 1, len(pontos) - 1)] - pontos[max(i - 1, 0)]).normalized()
        a = d.orthogonal().normalized()
        b = d.cross(a)
        anel = []
        for k in range(lados):
            ang = math.tau * k / lados
            r = raios[i] * (1.0 + 0.12 * noise.noise(p * 0.7 + Vector((k, 0, 0))))
            anel.append(bm.verts.new(p + (a * math.cos(ang) + b * math.sin(ang)) * r))
        aneis.append(anel)
    for i in range(len(aneis) - 1):
        for k in range(lados):
            k2 = (k + 1) % lados
            bm.faces.new((aneis[i][k], aneis[i][k2], aneis[i + 1][k2], aneis[i + 1][k]))
    bm.faces.new(aneis[-1])


def copa(bm, centro, raio, achatar, rng, sub=3):
    """Massa de folhas: icosfera amassada por ruído, mais larga que alta."""
    geo = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    desloc = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))
    for v in geo["verts"]:
        n = v.co.normalized()
        r = 1.0 + 0.28 * noise.noise(n * 1.7 + desloc) + 0.12 * noise.noise(n * 4.0 + desloc)
        if n.z < -0.2:
            r *= 0.75  # barriga mais reta embaixo
        v.co = Vector((n.x * r * raio, n.y * r * raio, n.z * r * raio * achatar)) + centro


def arvore(nome, semente, altura, abertura, colossal=False, longe=False):
    limpar()
    rng = random.Random(semente)
    bt = bmesh.new()
    bf = bmesh.new()
    r0 = altura * (0.06 if not colossal else 0.075)
    # tronco torto
    pts, rs = [], []
    inclina = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)) * altura * 0.12
    n = 7
    for i in range(n):
        t = i / (n - 1)
        p = Vector((0, 0, altura * 0.62 * t)) + inclina * t * t + Vector((math.sin(t * 3 + semente), math.cos(t * 2.3 + semente), 0)) * r0 * 0.6 * t
        pts.append(p)
        rs.append(r0 * (1.9 if i == 0 else 1.25 if i == 1 else 1.0 - 0.45 * t))
    pts[0].z = -altura * 0.04
    tubo(bt, pts, rs, 4 if longe else 8)
    topo = pts[-1]
    # raízes em sapopema
    for k in range(0 if longe else (5 if colossal else 4)):
        ang = math.tau * k / (5 if colossal else 4) + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        tubo(bt, [d * r0 * 0.6 + Vector((0, 0, altura * 0.12)), d * r0 * 1.7 + Vector((0, 0, altura * 0.035)), d * r0 * 3.0 + Vector((0, 0, -altura * 0.03))],
             [r0 * 0.5, r0 * 0.36, r0 * 0.14], 5)
    # galhos e copas
    galhos = 6 if colossal else 5
    for k in range(galhos):
        ang = math.tau * k / galhos + rng.uniform(-0.4, 0.4)
        d = Vector((math.cos(ang), math.sin(ang), 0))
        alcance = abertura * rng.uniform(0.55, 1.0)
        sobe = altura * rng.uniform(0.18, 0.34)
        meio = topo + d * alcance * 0.5 + Vector((0, 0, sobe * 0.75))
        fim = topo + d * alcance + Vector((0, 0, sobe))
        if not longe:
            tubo(bt, [topo - Vector((0, 0, altura * 0.05)), meio, fim], [rs[-1] * 0.9, rs[-1] * 0.55, rs[-1] * 0.25], 6)
        copa(bf, fim + Vector((0, 0, altura * 0.05)), abertura * rng.uniform(0.42, 0.6), rng.uniform(0.38, 0.5), rng, 1 if longe else 3)
    copa(bf, topo + Vector((0, 0, altura * 0.36)), abertura * 0.62, 0.45, rng, 1 if longe else 3)
    objeto("tronco", bt, "tronco")
    objeto("copa", bf, "folha")
    exportar(nome)


def moita(nome, semente):
    limpar()
    rng = random.Random(semente)
    bf = bmesh.new()
    for k in range(4):
        copa(bf, Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), rng.uniform(0.4, 0.9))), rng.uniform(0.7, 1.1), 0.7, rng)
    objeto("moita", bf, "folha")
    exportar(nome)


def rocha(nome, semente, escala, cortes=7):
    """Pedra talhada: esfera amassada e cortada por planos (faces chapadas)."""
    limpar()
    rng = random.Random(semente)
    bm = bmesh.new()
    geo = bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    desloc = Vector((semente * 3.1, semente * 1.7, semente * 0.9))
    planos = []
    for k in range(cortes):
        nrm = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.6, 1))).normalized()
        planos.append((nrm, rng.uniform(0.55, 0.85)))
    for v in geo["verts"]:
        n = v.co.normalized()
        p = n * (1.0 + 0.25 * noise.noise(n * 1.3 + desloc))
        for nrm, dist in planos:
            sobra = p.dot(nrm) - dist
            if sobra > 0:
                p -= nrm * sobra
        v.co = Vector((p.x * escala[0], p.y * escala[1], p.z * escala[2]))
    objeto("rocha", bm, "rocha", liso=False)
    exportar(nome)


def arco(nome):
    """Ponte de pedra natural: 130 m de vão, mais grossa nas pontas."""
    limpar()
    bm = bmesh.new()
    lados = 8
    aneis = []
    n = 26
    for i in range(n):
        t = i / (n - 1)
        x = -66 + 132 * t
        y_alt = 9.0 * math.sin(t * math.pi) - 4.0
        grosso = 1.0 + 1.3 * abs(t - 0.5) ** 1.6 * 2.0
        anel = []
        for k in range(lados):
            ang = math.tau * k / lados + 0.4
            c, s = math.cos(ang), math.sin(ang)
            # perfil meio quadrado
            px = 9.0 * grosso * (abs(c) ** 0.6) * (1 if c >= 0 else -1)
            pz = 6.5 * grosso * (abs(s) ** 0.6) * (1 if s >= 0 else -1)
            ru = 1.0 + 0.22 * noise.noise(Vector((x * 0.06, k * 1.3, 2.0))) + 0.1 * noise.noise(Vector((x * 0.21, k * 2.1, 7.0)))
            anel.append(bm.verts.new(Vector((x, px * ru, y_alt + pz * ru))))
        aneis.append(anel)
    for i in range(n - 1):
        for k in range(lados):
            k2 = (k + 1) % lados
            bm.faces.new((aneis[i][k], aneis[i][k2], aneis[i + 1][k2], aneis[i + 1][k]))
    bm.faces.new(aneis[0][::-1])
    bm.faces.new(aneis[-1])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    for v in bm.verts:
        v.co += Vector((0, noise.noise(v.co * 0.11) * 1.6, noise.noise(v.co * 0.09 + Vector((5, 5, 5))) * 1.6))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    objeto("arco", bm, "rocha", liso=False)
    exportar(nome)


arvore("arvore_a", 3, 17.0, 8.0)
arvore("arvore_b", 8, 22.0, 10.5)
arvore("arvore_c", 15, 13.0, 7.0)
arvore("arvore_a_longe", 3, 17.0, 8.0, longe=True)
arvore("arvore_b_longe", 8, 22.0, 10.5, longe=True)
arvore("arvore_c_longe", 15, 13.0, 7.0, longe=True)
arvore("arvore_colossal", 21, 46.0, 24.0, colossal=True)
moita("moita", 4)
rocha("rocha_a", 1, (1.0, 0.8, 0.7))
rocha("rocha_b", 2, (1.3, 0.7, 0.55))
rocha("rocha_laje", 3, (1.6, 1.1, 0.35), cortes=9)
rocha("rocha_ponta", 4, (0.7, 0.6, 1.5), cortes=9)
arco("arco")
