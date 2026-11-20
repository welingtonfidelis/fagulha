# O pássaro pequeno do vale (2026-11-20), feito a partir da "bird basemesh" do OpenGameArt (CC0, por vk e
# FacadeGaikan; https://opengameart.org/content/bird-basemesh): uma ave branca, inteiriça e sem animação.
# Aqui ela é pintada (penas, peito claro, bico e pernas, olhos), as asas viram peças à parte com a dobradiça
# na raiz, e tudo sai com os nomes que o jogo espera: corpo, asaE, asaD, olhos; materiais pena, pena_clara,
# bico e pelo_escuro (o jogo pinta por esses nomes).
#   blender -b --factory-startup --disable-autoexec <bird.blend> -P tools/vale/passaro_base.py -- assets/vale/passaro.glb
import sys

import bmesh
import bpy
from mathutils import Vector

saida = sys.argv[sys.argv.index("--") + 1]
COMP = 0.34  # comprimento do pássaro pronto, do bico à cauda, em metros

for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
velha = [o for o in bpy.data.objects if o.type == "MESH"][0]
# a malha com o espelho aplicado, já no lugar do mundo, num objeto novo ligado à cena
dg = bpy.context.evaluated_depsgraph_get()
me0 = bpy.data.meshes.new_from_object(velha.evaluated_get(dg))
me0.transform(velha.matrix_world)
bpy.data.objects.remove(velha)
ave = bpy.data.objects.new("corpo", me0)
bpy.context.scene.collection.objects.link(ave)
bpy.context.view_layer.objects.active = ave
ave.select_set(True)


def mat(nome, cor):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = cor + (1,)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    return m


ave.data.materials.clear()
for nome, cor in (("pena", (0.36, 0.25, 0.16)), ("pena_clara", (0.82, 0.74, 0.6)), ("bico", (0.9, 0.55, 0.12)), ("pelo_escuro", (0.03, 0.03, 0.04))):
    ave.data.materials.append(mat(nome, cor))

vs = [v.co for v in ave.data.vertices]
y_bico = min(v.y for v in vs)
y_cauda = max(v.y for v in vs)
z_pe = min(v.z for v in vs)
comp = y_cauda - y_bico
bm = bmesh.new()
bm.from_mesh(ave.data)
asas = {1: [], -1: []}
for f in bm.faces:
    c = f.calc_center_median()
    n = f.normal
    if abs(c.x) > 0.21:
        f.material_index = 0
        asas[1 if c.x > 0 else -1].append(f)
    elif c.y < y_bico + comp * 0.09:
        f.material_index = 2  # o bico
    elif c.z < z_pe + 0.33 and abs(c.x) < 0.2 and f.calc_area() < 0.03:
        f.material_index = 2  # pernas e pés
    elif n.z < -0.2 and c.y < y_bico + comp * 0.72:
        f.material_index = 1  # o peito e a barriga, por baixo
    else:
        f.material_index = 0
pecas = {}
bm.to_mesh(ave.data)
bm.free()
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
for lado, nome in ((1, "asaE"), (-1, "asaD")):
    for p in ave.data.polygons:
        c = p.center
        p.select = abs(c.x) > 0.21 and (c.x > 0) == (lado > 0)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    nova = [o for o in bpy.context.selected_objects if o != ave][0]
    nova.name = nome
    nova.select_set(False)
    pecas[nome] = nova
ave.name = "corpo"
# a dobradiça de cada asa: a raiz, onde ela encosta no corpo
for lado, nome in ((1, "asaE"), (-1, "asaD")):
    o = pecas[nome]
    raiz = [o.matrix_world @ v.co for v in o.data.vertices if abs(v.co.x) < 0.32]
    centro = sum(raiz, Vector()) / max(1, len(raiz))
    centro.x = 0.2 * lado
    bpy.context.scene.cursor.location = centro
    bpy.context.view_layer.objects.active = o
    for q in bpy.data.objects:
        q.select_set(q == o)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
# os olhos: duas contas escuras nos lados da cabeça
cab = [v.co for v in ave.data.vertices if v.co.y < y_bico + comp * 0.22]
z_olho = sum(v.z for v in cab) / len(cab) + 0.03
y_olho = y_bico + comp * 0.15
larg = max(abs(v.x) for v in cab if abs(v.y - y_olho) < comp * 0.05)
bm2 = bmesh.new()
for lado in (1, -1):
    bmesh.ops.create_icosphere(bm2, subdivisions=1, radius=0.035, matrix=__import__("mathutils").Matrix.Translation((lado * larg * 0.86, y_olho, z_olho)))
me = bpy.data.meshes.new("olhos")
bm2.to_mesh(me)
bm2.free()
me.materials.append(bpy.data.materials["pelo_escuro"])
olhos = bpy.data.objects.new("olhos", me)
bpy.context.scene.collection.objects.link(olhos)
# tudo no tamanho do jogo, com os pés no chão; as asas e os olhos pendurados no corpo
esc = COMP / comp
for o in [ave, olhos] + list(pecas.values()):
    o.location = (o.location - Vector((0, (y_bico + y_cauda) * 0.5, z_pe))) * esc if o != ave and o != olhos else o.location
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
