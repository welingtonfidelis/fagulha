# Natureza do vale (floresta temperada, estilo de formas simples): carvalho, bétula, pinheiro, arbusto,
# pedras e o cervo. Só as formas; as cores e a luz em faixas vêm dos shaders na Godot.
# blender -b --factory-startup -P tools/vale/natureza.py -- <assets/vale>
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
    return bpy.data.materials.get(nome) or bpy.data.materials.new(nome)


def limpar():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)


def objeto(nome, bm, material, liso=True, pos=(0, 0, 0), pai=None):
    me = bpy.data.meshes.new(nome)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat(material))
    if liso:
        me.shade_smooth()
    ob = bpy.data.objects.new(nome, me)
    ob.location = pos
    bpy.context.scene.collection.objects.link(ob)
    if pai is not None:
        bpy.context.view_layer.update()
        ob.parent = pai
        ob.matrix_parent_inverse = pai.matrix_world.inverted()
    bpy.context.view_layer.update()
    return ob


def exportar(nome):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(DEST, nome + ".glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    tris = sum(len(p.vertices) - 2 for ob in bpy.data.objects if ob.type == "MESH" for p in ob.data.polygons)
    print("FEITO", nome, tris, "tris", flush=True)


def tubo(bm, pontos, raios, lados=7, tampa=True):
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
    if tampa:
        bm.faces.new(aneis[-1])
        bm.faces.new(aneis[0][::-1])


def bola(bm, centro, raio, esc=(1, 1, 1), sub=2, ruido=0.2, semente=0.0):
    geo = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    d = Vector((semente, semente * 1.7, semente * 0.6))
    for v in geo["verts"]:
        n = v.co.normalized()
        r = raio * (1.0 + ruido * noise.noise(n * 1.6 + d))
        v.co = Vector((n.x * r * esc[0], n.y * r * esc[1], n.z * r * esc[2])) + Vector(centro)


def carvalho(nome, semente, altura=9.0, longe=False):
    limpar()
    rng = random.Random(semente)
    bt, bf = bmesh.new(), bmesh.new()
    r0 = altura * 0.045
    topo = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), altura * 0.42))
    tubo(bt, [Vector((0, 0, -0.3)), Vector((0, 0, altura * 0.08)), topo * 0.6 + Vector((0, 0, altura * 0.1)), topo],
         [r0 * 1.7, r0 * 1.1, r0 * 0.9, r0 * 0.7], 5 if longe else 8)
    n = 4 if longe else 7
    for k in range(n):
        ang = math.tau * k / n + rng.uniform(-0.3, 0.3)
        dist = altura * rng.uniform(0.16, 0.30)
        c = topo + Vector((math.cos(ang) * dist, math.sin(ang) * dist, altura * rng.uniform(0.10, 0.30)))
        if not longe:
            tubo(bt, [topo - Vector((0, 0, 0.3)), c - Vector((0, 0, altura * 0.05))], [r0 * 0.5, r0 * 0.2], 5)
        bola(bf, c, altura * rng.uniform(0.20, 0.27), (1, 1, 0.78), 1 if longe else 3, 0.22, semente + k)
    bola(bf, topo + Vector((0, 0, altura * 0.38)), altura * 0.26, (1, 1, 0.8), 1 if longe else 3, 0.22, semente + 9)
    objeto("tronco", bt, "tronco")
    objeto("copa", bf, "folha")
    exportar(nome)


def betula(nome, semente, altura=11.0, longe=False):
    limpar()
    rng = random.Random(semente)
    bt, bf = bmesh.new(), bmesh.new()
    r0 = altura * 0.022
    inc = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))
    pts = [Vector((0, 0, -0.2)), inc * 0.3 + Vector((0, 0, altura * 0.4)), inc + Vector((0, 0, altura * 0.8))]
    tubo(bt, pts, [r0 * 1.4, r0, r0 * 0.5], 5 if longe else 7)
    for k in range(3 if longe else 5):
        t = 0.5 + 0.12 * k
        c = pts[1].lerp(pts[2], (t - 0.4) / 0.4) + Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), 0))
        bola(bf, c, altura * rng.uniform(0.11, 0.15), (1, 1, 1.25), 1 if longe else 3, 0.25, semente + k)
    objeto("tronco", bt, "casca_clara")
    objeto("copa", bf, "folha_clara")
    exportar(nome)


def pinheiro(nome, semente, altura=14.0, longe=False):
    limpar()
    rng = random.Random(semente)
    bt, bf = bmesh.new(), bmesh.new()
    tubo(bt, [Vector((0, 0, -0.3)), Vector((0, 0, altura * 0.45))], [altura * 0.03, altura * 0.012], 5 if longe else 7)
    n = 3 if longe else 5
    for k in range(n):
        t = k / n
        z = altura * (0.18 + 0.72 * t)
        r = altura * 0.21 * (1 - t * 0.78)
        h = altura * 0.34 * (1 - t * 0.35)
        geo = bmesh.ops.create_cone(bf, cap_ends=True, segments=6 if longe else 9, radius1=r, radius2=0.0, depth=h,
                                    matrix=Matrix.Translation((0, 0, z + h * 0.5)))
        for v in geo["verts"]:
            if v.co.z < z + 0.01:
                a = math.atan2(v.co.y, v.co.x)
                v.co.z -= r * 0.25 * (0.6 + 0.4 * math.sin(a * 3 + semente + k))  # saia irregular
    objeto("tronco", bt, "tronco")
    objeto("copa", bf, "folha_escura")
    exportar(nome)


def arbusto(nome, semente):
    limpar()
    rng = random.Random(semente)
    bf = bmesh.new()
    for k in range(4):
        bola(bf, (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(0.3, 0.6)), rng.uniform(0.45, 0.7), (1, 1, 0.8), 3, 0.25, semente + k)
    objeto("copa", bf, "folha")
    exportar(nome)


def pedra(nome, semente, esc):
    limpar()
    rng = random.Random(semente)
    bm = bmesh.new()
    geo = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    planos = [(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.4, 1))).normalized(), rng.uniform(0.55, 0.85)) for _ in range(8)]
    d = Vector((semente * 2.1, semente, semente * 0.4))
    for v in geo["verts"]:
        n = v.co.normalized()
        p = n * (1.0 + 0.22 * noise.noise(n * 1.3 + d))
        for nrm, dist in planos:
            sobra = p.dot(nrm) - dist
            if sobra > 0:
                p -= nrm * sobra
        v.co = Vector((p.x * esc[0], p.y * esc[1], p.z * esc[2]))
    objeto("pedra", bm, "rocha", liso=False)
    exportar(nome)


def cervo(nome):
    """Cervo de formas simples, de frente para -Y. Peças separadas com a origem na junta, para animar por código:
    corpo (raiz), pescoco > cabeca, perna_fe, perna_fd, perna_te, perna_td, cauda. As peças de detalhe (barriga,
    espelho, rosto, chifres, canelas) são filhas dessas e acompanham o movimento."""
    limpar()
    bm = bmesh.new()
    bola(bm, (0, 0, 0), 1.0, (0.20, 0.50, 0.235), 3, 0.03, 1.0)
    bola(bm, (0, -0.30, 0.05), 1.0, (0.195, 0.25, 0.265), 3, 0.03, 2.0)  # peito
    bola(bm, (0, 0.32, 0.035), 1.0, (0.205, 0.26, 0.255), 3, 0.03, 3.0)  # garupa
    bola(bm, (0, -0.34, 0.17), 1.0, (0.10, 0.17, 0.10), 2, 0.0, 3.5)  # cernelha
    corpo = objeto("corpo", bm, "pelo", pos=(0, 0, 0.88))
    bm = bmesh.new()
    bola(bm, (0, 0.03, -0.09), 1.0, (0.165, 0.42, 0.17), 3, 0.0, 1.5)
    objeto("barriga", bm, "pelo_claro", pos=(0, 0, 0.88), pai=corpo)
    bm = bmesh.new()
    bola(bm, (0, 0.505, 0.02), 1.0, (0.115, 0.07, 0.15), 2, 0.0, 1.7)
    objeto("espelho", bm, "pelo_claro", pos=(0, 0, 0.88), pai=corpo)
    bm = bmesh.new()
    tubo(bm, [Vector((0, 0.06, -0.10)), Vector((0, -0.10, 0.20)), Vector((0, -0.17, 0.42))], [0.155, 0.10, 0.075], 9)
    pescoco = objeto("pescoco", bm, "pelo", pos=(0, -0.44, 0.98), pai=corpo)
    bm = bmesh.new()
    bola(bm, (0, -0.07, 0.02), 1.0, (0.078, 0.14, 0.085), 3, 0.02, 4.0)
    bola(bm, (0, -0.21, -0.015), 1.0, (0.046, 0.09, 0.048), 2, 0.0, 5.0)  # focinho
    for s in (1, -1):
        bola(bm, (s * 0.105, 0.035, 0.10), 1.0, (0.022, 0.045, 0.085), 2, 0.0, 6.0)  # orelha
    cabeca = objeto("cabeca", bm, "pelo", pos=(0, -0.62, 1.42), pai=pescoco)
    bm = bmesh.new()
    for s in (1, -1):
        bola(bm, (s * 0.067, -0.10, 0.045), 1.0, (0.016, 0.02, 0.02), 1, 0.0, 6.5)  # olho
    bola(bm, (0, -0.295, -0.01), 1.0, (0.027, 0.02, 0.023), 1, 0.0, 6.7)  # nariz
    objeto("rosto", bm, "pelo_escuro", pos=(0, -0.62, 1.42), pai=cabeca)
    bm = bmesh.new()
    bola(bm, (0, -0.225, -0.045), 1.0, (0.036, 0.06, 0.022), 1, 0.0, 6.9)  # queixo claro
    objeto("queixo", bm, "pelo_claro", pos=(0, -0.62, 1.42), pai=cabeca)
    bm = bmesh.new()
    for s in (1, -1):
        base = Vector((s * 0.04, 0.0, 0.07))
        p1 = base + Vector((s * 0.10, 0.04, 0.20))
        p2 = p1 + Vector((s * 0.06, 0.02, 0.20))
        tubo(bm, [base, p1, p2], [0.016, 0.012, 0.005], 5)
        tubo(bm, [p1, p1 + Vector((s * 0.02, -0.12, 0.10))], [0.011, 0.004], 5)
        tubo(bm, [base.lerp(p1, 0.5), base.lerp(p1, 0.5) + Vector((0, -0.10, 0.06))], [0.011, 0.004], 5)
    objeto("chifres", bm, "chifre", pos=(0, -0.62, 1.42), pai=cabeca)
    for nome_p, x, y in (("perna_fe", 0.10, -0.30), ("perna_fd", -0.10, -0.30), ("perna_te", 0.10, 0.32), ("perna_td", -0.10, 0.32)):
        tras = y > 0
        bm = bmesh.new()
        tubo(bm, [Vector((0, 0, 0.04)), Vector((0, 0.02 if tras else 0.0, -0.36)), Vector((0, 0, -0.50))], [0.07, 0.038, 0.03], 8)
        if tras:
            bola(bm, (0, 0.035, -0.07), 1.0, (0.066, 0.125, 0.20), 2, 0.0, 7.2)  # coxa
        else:
            bola(bm, (0, 0.0, -0.05), 1.0, (0.056, 0.085, 0.155), 2, 0.0, 7.3)  # ombro
        perna = objeto(nome_p, bm, "pelo", pos=(x, y, 0.80), pai=corpo)
        bm = bmesh.new()
        tubo(bm, [Vector((0, 0, -0.46)), Vector((0, 0, -0.74))], [0.031, 0.024], 7)
        bola(bm, (0, -0.015, -0.76), 1.0, (0.034, 0.045, 0.03), 1, 0.0, 7.0)  # casco
        objeto("canela_" + nome_p[-2:], bm, "pelo_escuro", pos=(x, y, 0.80), pai=perna)
    bm = bmesh.new()
    bola(bm, (0, 0.04, -0.03), 1.0, (0.04, 0.05, 0.07), 1, 0.0, 8.0)
    objeto("cauda", bm, "pelo_claro", pos=(0, 0.54, 0.95), pai=corpo)
    exportar(nome)


def passaro(nome):
    """Pássaro pequeno (~0,3 m), de frente para -Y, pés no chão (z = 0). Peças: corpo (raiz), asaE e asaD com a
    origem no ombro (a asa aberta aponta para o lado; fechar = girar para trás junto do corpo)."""
    limpar()
    bm = bmesh.new()
    bola(bm, (0, 0, 0.095), 1.0, (0.05, 0.10, 0.055), 2, 0.0, 1.0)
    bola(bm, (0, -0.09, 0.145), 1.0, (0.038, 0.042, 0.038), 2, 0.0, 2.0)  # cabeça
    bola(bm, (0, 0.15, 0.085), 1.0, (0.028, 0.085, 0.010), 1, 0.0, 3.0)  # cauda
    corpo = objeto("corpo", bm, "pena", pos=(0, 0, 0))
    bm = bmesh.new()
    bola(bm, (0, -0.035, 0.078), 1.0, (0.044, 0.072, 0.045), 2, 0.0, 4.0)
    objeto("peito", bm, "pena_clara", pos=(0, 0, 0), pai=corpo)
    bm = bmesh.new()
    tubo(bm, [Vector((0, -0.122, 0.143)), Vector((0, -0.168, 0.136))], [0.012, 0.002], 5)
    for s in (1, -1):
        tubo(bm, [Vector((s * 0.02, 0.0, 0.055)), Vector((s * 0.022, -0.005, 0.0))], [0.005, 0.004], 4)
    objeto("bico", bm, "bico", pos=(0, 0, 0), pai=corpo)
    bm = bmesh.new()
    for s in (1, -1):
        bola(bm, (s * 0.03, -0.105, 0.155), 0.008, (1, 1, 1), 1, 0.0, 5.0)
    objeto("olhos", bm, "pelo_escuro", pos=(0, 0, 0), pai=corpo)
    for lado, s in (("E", 1), ("D", -1)):
        bm = bmesh.new()
        bola(bm, (s * 0.095, 0.025, 0.0), 1.0, (0.10, 0.058, 0.008), 2, 0.0, 6.0)
        bola(bm, (s * 0.15, 0.05, 0.0), 1.0, (0.06, 0.04, 0.006), 1, 0.0, 7.0)  # ponta
        objeto("asa" + lado, bm, "pena", pos=(s * 0.042, -0.02, 0.125), pai=corpo)
    exportar(nome)


def coelho(nome):
    """Coelho (~0,38 m), de frente para -Y, pés no chão. Peças: corpo (raiz), cabeca > orelhas, perna_t (as duas
    patas de trás juntas, origem no quadril), cauda."""
    limpar()
    bm = bmesh.new()
    bola(bm, (0, 0.0, 0.115), 1.0, (0.072, 0.13, 0.085), 3, 0.02, 1.0)
    bola(bm, (0, 0.085, 0.125), 1.0, (0.082, 0.095, 0.098), 3, 0.02, 2.0)  # garupa
    for s in (1, -1):
        tubo(bm, [Vector((s * 0.04, -0.09, 0.08)), Vector((s * 0.04, -0.105, 0.0))], [0.022, 0.016], 6)  # patas da frente
    corpo = objeto("corpo", bm, "pelo_coelho", pos=(0, 0, 0))
    bm = bmesh.new()
    bola(bm, (0, -0.035, 0.015), 1.0, (0.05, 0.065, 0.05), 3, 0.0, 3.0)
    cabeca = objeto("cabeca", bm, "pelo_coelho", pos=(0, -0.12, 0.175), pai=corpo)
    bm = bmesh.new()
    for s in (1, -1):
        bola(bm, (s * 0.022, 0.012, 0.075), 1.0, (0.014, 0.02, 0.075), 2, 0.0, 4.0)
    objeto("orelhas", bm, "pelo_coelho", pos=(0, -0.13, 0.225), pai=cabeca)
    bm = bmesh.new()
    for s in (1, -1):
        bola(bm, (s * 0.043, -0.055, 0.03), 0.009, (1, 1, 1), 1, 0.0, 5.0)
    bola(bm, (0, -0.098, 0.012), 0.008, (1, 1, 1), 1, 0.0, 5.5)
    objeto("rosto", bm, "pelo_escuro", pos=(0, -0.12, 0.175), pai=cabeca)
    bm = bmesh.new()
    for s in (1, -1):
        bola(bm, (s * 0.062, -0.01, -0.045), 1.0, (0.024, 0.075, 0.03), 2, 0.0, 6.0)
    objeto("perna_t", bm, "pelo_coelho", pos=(0, 0.10, 0.075), pai=corpo)
    bm = bmesh.new()
    bola(bm, (0, 0.0, 0.0), 0.036, (1, 1, 1), 1, 0.0, 7.0)
    objeto("cauda", bm, "pelo_claro", pos=(0, 0.175, 0.135), pai=corpo)
    exportar(nome)


def peixe(nome):
    """Peixe (~0,45 m), de frente para -Y, origem no meio do corpo. Peças: corpo (raiz) e cauda (origem na base)."""
    limpar()
    bm = bmesh.new()
    bola(bm, (0, 0, 0), 1.0, (0.042, 0.17, 0.06), 2, 0.0, 1.0)
    bola(bm, (0, 0.02, 0.06), 1.0, (0.006, 0.07, 0.03), 1, 0.0, 2.0)  # dorsal
    corpo = objeto("corpo", bm, "peixe", pos=(0, 0, 0))
    bm = bmesh.new()
    bola(bm, (0, 0.06, 0), 1.0, (0.007, 0.07, 0.062), 1, 0.0, 3.0)
    objeto("cauda", bm, "peixe", pos=(0, 0.15, 0), pai=corpo)
    exportar(nome)


carvalho("carvalho_a", 3)
carvalho("carvalho_b", 11, 11.5)
carvalho("carvalho_a_longe", 3, longe=True)
carvalho("carvalho_b_longe", 11, 11.5, longe=True)
betula("betula", 5)
betula("betula_longe", 5, longe=True)
pinheiro("pinheiro", 7)
pinheiro("pinheiro_longe", 7, longe=True)
arbusto("arbusto", 2)
pedra("pedra_a", 1, (1.0, 0.85, 0.6))
pedra("pedra_b", 2, (1.4, 0.8, 0.5))
pedra("pedra_alta", 3, (0.7, 0.65, 1.3))
cervo("cervo")
passaro("passaro")
coelho("coelho")
peixe("peixe")
