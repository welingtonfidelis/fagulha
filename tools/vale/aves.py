# As aves do jogo, todas da "bird basemesh" do OpenGameArt (CC0, por vk e FacadeGaikan;
# https://opengameart.org/content/bird-basemesh): uma ave branca, inteiriça e sem animação. O pássaro pequeno do vale
# (2026-11-20, antes tools/vale/passaro_base.py) e as aves da Montanha do Degelo (2026-11-22, doc §137.14), o lagópode e
# o corvo. A malha é a mesma; o que muda é a forma (cada espécie deforma os vértices por uma conta só, igual em todas
# as peças) e a pintura. Sai com os nomes que o jogo espera: corpo, asaE e asaD (com a dobradiça na raiz), pernas (com
# a junta no quadril: o jogo recolhe os pés no voo) e olhos; os materiais têm os nomes da Clareira.
#   blender -b --factory-startup --disable-autoexec <bird.blend> -P tools/vale/aves.py -- passaro assets/vale/passaro.glb
#   blender -b --factory-startup --disable-autoexec <bird.blend> -P tools/vale/aves.py -- lagopode assets/vale/lagopode.glb
#   blender -b --factory-startup --disable-autoexec <bird.blend> -P tools/vale/aves.py -- corvo assets/vale/corvo.glb
import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
ESPECIE = args[0]
saida = args[1]
COMP = 0.34  # do bico à ponta da cauda, em metros; o jogo aumenta com a escala de cada bando


def suave(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def janela(x, a, b, borda=0.12):
    """1 entre a e b, caindo suave nas pontas."""
    return suave(a - borda, a + borda, x) * (1.0 - suave(b - borda, b + borda, x))


FLANCO = 0.3  # até aqui é corpo; dali para fora, asa (que só anda junto com o flanco)


def _largura(co, s, envergadura=1.0):
    ax = abs(co.x)
    if ax <= FLANCO:
        return co.x * s
    return math.copysign(FLANCO * s + (ax - FLANCO) * envergadura, co.x)


def eh_asa(c):
    """A asa é só o que sai do lado do corpo no alto e na frente (até 2026-11-22 a peça levava junto os dedos dos pés
    e as pontas da cauda, que giravam para fora quando a asa dobrava)."""
    return abs(c.x) > 0.21 and c.z > 0.9 and c.y < 0.3


def eh_perna(c, area):
    """As pernas e os pés: as faces miúdas embaixo da barriga (a barriga tem faces maiores; a cauda fica atrás)."""
    return c.z < 0.69 and area < 0.004 and c.y < 0.4 and abs(c.x) < 0.35


def identidade(co):
    return co.copy()


def deformar_lagopode(co):
    """Roliço, de cabeça redonda, bico curto, cauda curta e pernas curtas (de pena até o pé)."""
    p = co.copy()
    s = 1.0 + 0.8 * janela(p.y, -0.5, 0.25) + 0.35 * janela(p.y, -0.8, -0.45)
    if co.z < 0.8:  # as pernas e os pés abrem menos que a barriga
        s = 1.0 + (s - 1.0) * 0.45
    p.x = _largura(p, s, 0.65)
    if p.y < -0.66:  # o bico, curto
        p.y = -0.66 + (p.y + 0.66) * 0.45
    t = suave(0.1, 0.45, co.y)  # a cauda, puxada para perto da raiz
    p.y = p.y + ((0.2 + (co.y - 0.2) * 0.42) - co.y) * t
    p.z = p.z + ((1.0 + (co.z - 1.0) * 0.5) - co.z) * t
    if co.z < 0.8 and abs(co.x) < FLANCO:  # pernas curtas
        p.z = 0.8 - (0.8 - co.z) * 0.55
    # a barriga mais funda
    if 0.75 < co.z < 1.05 and abs(co.x) < FLANCO:
        p.z -= 0.05 * janela(co.y, -0.4, 0.2)
    return p


def deformar_corvo(co):
    """Maior e mais pesado: bico grosso e comprido, cabeça um pouco maior, cauda em cunha, asas mais longas."""
    p = co.copy()
    s = 1.12 + 0.12 * janela(p.y, -0.8, -0.45)
    p.x = _largura(p, s, 1.15)
    if co.y < -0.6:  # o bico grosso
        k = suave(-0.6, -0.72, co.y)
        p.x *= 1.0 + 0.45 * k
        p.z = 1.62 + (p.z - 1.62) * (1.0 + 0.4 * k)
        p.y = -0.6 + (co.y + 0.6) * 1.25
    if co.y > 0.5 and abs(co.x) < FLANCO + 0.1:  # a cauda abre em cunha na ponta
        p.x *= 1.0 + 0.6 * suave(0.5, 1.04, co.y)
    return p


ESPECIES = {
    # (materiais na ordem dos índices, deformação)
    "passaro": (("pena", "pena_clara", "bico", "pelo_escuro"), identidade),
    "lagopode": (("lagopode", "lagopode_branco", "bico_escuro", "pelo_escuro", "lagopode_escuro", "lagopode_crista"), deformar_lagopode),
    "corvo": (("corvo", "corvo", "bico_escuro", "pelo_escuro"), deformar_corvo),
}
CORES = {  # só para ver no Blender: no jogo vale a cor da Clareira com esse nome
    "lagopode": (0.42, 0.37, 0.30), "lagopode_branco": (0.9, 0.9, 0.88), "lagopode_escuro": (0.2, 0.17, 0.14),
    "lagopode_crista": (0.75, 0.1, 0.06), "bico_escuro": (0.03, 0.03, 0.035), "pelo_escuro": (0.03, 0.03, 0.04),
    "corvo": (0.05, 0.055, 0.07), "pena": (0.36, 0.25, 0.16), "pena_clara": (0.82, 0.74, 0.6), "bico": (0.9, 0.55, 0.12),
}
OLHO_Y = {"passaro": 0.15, "lagopode": 0.2, "corvo": 0.17}  # onde fica o olho, do bico para trás (fração do comprimento)
NOMES_MAT, deformar = ESPECIES[ESPECIE]

for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
velha = [o for o in bpy.data.objects if o.type == "MESH"][0]
dg = bpy.context.evaluated_depsgraph_get()
me0 = bpy.data.meshes.new_from_object(velha.evaluated_get(dg))
me0.transform(velha.matrix_world)
me0.transform(Matrix.Rotation(math.pi, 4, "Z"))  # a cabeça em -Y (ver passaro_base.py)
bpy.data.objects.remove(velha)
ave = bpy.data.objects.new("corpo", me0)
bpy.context.scene.collection.objects.link(ave)
bpy.context.view_layer.objects.active = ave
ave.select_set(True)


def mat(nome):
    if nome in bpy.data.materials:
        return bpy.data.materials[nome]
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = CORES[nome] + (1,)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    return m


ave.data.materials.clear()
indice = {}
for nome in NOMES_MAT:
    if nome not in indice:
        ave.data.materials.append(mat(nome))
        indice[nome] = len(ave.data.materials) - 1


def I(i):
    return indice[NOMES_MAT[i]]


# a pintura, na forma original (as regras do passaro_base.py)
vs = [v.co for v in ave.data.vertices]
y_bico = min(v.y for v in vs)
y_cauda = max(v.y for v in vs)
z_pe = min(v.z for v in vs)
comp = y_cauda - y_bico
sorte = random.Random(7)
bm = bmesh.new()
bm.from_mesh(ave.data)
for f in bm.faces:
    c = f.calc_center_median()
    n = f.normal
    if eh_perna(c, f.calc_area()):
        f.material_index = I(1) if ESPECIE == "lagopode" else I(2)  # pés: de pena branca no lagópode
    elif eh_asa(c):
        f.material_index = I(1) if ESPECIE == "lagopode" else I(0)  # o lagópode tem a asa branca
    elif c.y < y_bico + comp * 0.09:
        f.material_index = I(2)
    elif n.z < -0.2 and c.y < y_bico + comp * 0.72:
        f.material_index = I(1)
    elif ESPECIE == "lagopode" and c.y > y_cauda - comp * 0.3:
        f.material_index = I(2)  # a cauda preta
    elif ESPECIE == "lagopode":
        f.material_index = I(4) if sorte.random() < 0.38 else I(0)  # o dorso pintado de escuro e pardo
    else:
        f.material_index = I(0)
bm.to_mesh(ave.data)
bm.free()

# as asas viram peças à parte (separadas na forma original, como no pássaro)
raizes = {}
pecas = {}
for lado, nome in ((1, "asaE"), (-1, "asaD")):
    for p in ave.data.polygons:
        c = p.center
        p.select = eh_asa(c) and (c.x > 0) == (lado > 0)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    nova = [o for o in bpy.context.selected_objects if o != ave][0]
    nova.name = nome
    nova.select_set(False)
    pecas[nome] = nova
    raiz = [v.co.copy() for v in nova.data.vertices if abs(v.co.x) < 0.32]
    centro = sum(raiz, Vector()) / max(1, len(raiz))
    centro.x = 0.2 * lado
    raizes[nome] = deformar(centro)
# as pernas: uma peça só, com a junta no quadril (o alto delas, no meio)
for p in ave.data.polygons:
    p.select = eh_perna(p.center, p.area)
print("FACES_PERNAS", sum(1 for p in ave.data.polygons if p.select))
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
nova = [o for o in bpy.context.selected_objects if o != ave][0]
nova.name = "pernas"
nova.select_set(False)
pecas["pernas"] = nova
z_topo = max(v.co.z for v in nova.data.vertices)
topo = [v.co.copy() for v in nova.data.vertices if v.co.z > z_topo - 0.04]
quadril = sum(topo, Vector()) / max(1, len(topo))
quadril.x = 0.0
raizes["pernas"] = deformar(quadril)
ave.name = "corpo"
# os buracos que as pernas deixam na barriga: fechados com a cor dela, para não aparecerem com os pés recolhidos
bm = bmesh.new()
bm.from_mesh(ave.data)
bordas = [e for e in bm.edges if e.is_boundary and all(v.co.z < 0.8 and abs(v.co.x) < 0.35 for v in e.verts)]
tampas = bmesh.ops.holes_fill(bm, edges=bordas, sides=0)["faces"]
for f in tampas:
    f.material_index = I(1)
print("TAMPAS", len(bordas), len(tampas))
bm.to_mesh(ave.data)
bm.free()

# a forma da espécie: a mesma conta no corpo e nas asas, então elas continuam encostadas
for o in [ave] + list(pecas.values()):
    for v in o.data.vertices:
        v.co = deformar(v.co)
    o.data.update()
for nome, o in pecas.items():
    bpy.context.scene.cursor.location = raizes[nome]
    bpy.context.view_layer.objects.active = o
    for q in bpy.data.objects:
        q.select_set(q == o)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

todos = [o.matrix_world @ v.co for o in [ave] + list(pecas.values()) for v in o.data.vertices]
y_bico = min(v.co.y for v in ave.data.vertices)
y_cauda = max(v.y for v in todos)
z_pe = min(v.z for v in todos)  # os pés (na peça das pernas)
comp = y_cauda - y_bico

# os olhos (contas escuras) e, no lagópode, a crista vermelha em cima deles
cab = [v.co for v in ave.data.vertices if v.co.y < y_bico + comp * 0.22]
z_olho = sum(v.z for v in cab) / len(cab) + 0.03
y_olho = y_bico + comp * OLHO_Y[ESPECIE]
larg = max(abs(v.x) for v in cab if abs(v.y - y_olho) < comp * 0.06)
bm2 = bmesh.new()
for lado in (1, -1):
    bmesh.ops.create_icosphere(bm2, subdivisions=1, radius=0.035, matrix=Matrix.Translation((lado * larg * 0.86, y_olho, z_olho)))
me = bpy.data.meshes.new("olhos")
me.materials.append(mat("pelo_escuro"))
if ESPECIE == "lagopode":
    me.materials.append(mat("lagopode_crista"))
    n0 = len(bm2.faces)
    for lado in (1, -1):
        m = Matrix.Translation((lado * larg * 0.8, y_olho, z_olho + 0.06)) @ Matrix.Diagonal((0.6, 1.5, 0.55, 1.0))
        bmesh.ops.create_icosphere(bm2, subdivisions=1, radius=0.045, matrix=m)
    for i, f in enumerate(bm2.faces):
        f.material_index = 1 if i >= n0 else 0
bm2.to_mesh(me)
bm2.free()
olhos = bpy.data.objects.new("olhos", me)
bpy.context.scene.collection.objects.link(olhos)

# tudo no tamanho do jogo, com os pés no chão; as asas e os olhos pendurados no corpo
esc = COMP / comp
for o in bpy.data.objects:
    o.select_set(False)
raiz_cena = bpy.data.objects.new("raiz_tmp", None)
bpy.context.scene.collection.objects.link(raiz_cena)
for o in [ave, olhos] + list(pecas.values()):
    mw = o.matrix_world.copy()
    o.parent = raiz_cena
    o.matrix_world = mw
raiz_cena.location = Vector((0, -(y_bico + y_cauda) * 0.5 * esc, -z_pe * esc))
raiz_cena.scale = (esc, esc, esc)
bpy.context.view_layer.update()
for o in [ave, olhos] + list(pecas.values()):
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
bpy.data.objects.remove(raiz_cena)
bpy.context.view_layer.update()
for o in [ave, olhos] + list(pecas.values()):
    for q in bpy.data.objects:
        q.select_set(q == o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=(o in (ave, olhos)), rotation=True, scale=True)
for o in [olhos] + list(pecas.values()):
    mw = o.matrix_world.copy()
    o.parent = ave
    o.matrix_world = mw
for o in bpy.data.objects:
    o.select_set(True)
    if o.type == "MESH":
        for p in o.data.polygons:
            p.use_smooth = False
print("PECAS", [(o.name, tuple(round(x, 3) for x in o.location), tuple(round(x, 3) for x in o.dimensions), len(o.data.polygons)) for o in bpy.data.objects])
bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
print("EXPORTADO", saida)
