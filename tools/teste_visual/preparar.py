# Teste visual: reduz os triângulos dos modelos do Poly Haven e exporta GLB para a Godot.
# blender -b --factory-startup -P tools/teste_visual/preparar.py -- <vendor/polyhaven> <assets/teste_visual>
import glob
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
ORIGEM, DESTINO = argv[0], argv[1]
os.makedirs(DESTINO, exist_ok=True)

# alvo de triângulos por modelo (por material quando dito)
ALVOS = {
    "coastal_cliff_01": 70000,
    "mountainside": 45000,
    "rock_face_01": 20000,
    "rock_face_02": 25000,
    "rock_moss_set_01": 6000,
    "rock_moss_set_02": 6000,
    "boulder_01": 6000,
    "root_cluster_01": 7000,
    "anthurium_botany_01": 4000,
    "pachira_aquatica_01": 6000,
    "calathea_orbifolia_01": 5000,
    "fern_02": 3000,
    "shrub_02": 6000,
    "island_tree_02": {"island_tree_02": 9000, "island_tree_02_branches": 18000, "island_tree_02_leaves": 90000},
}
# versões leves para a mata em quantidade (nome_saida: (modelo, alvos))
LEVES = {
    "island_tree_02_leve": ("island_tree_02", {"island_tree_02": 2500, "island_tree_02_branches": 4500, "island_tree_02_leaves": 22000}),
}


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def decimar(ob, alvo):
    t = tris(ob)
    if t <= alvo:
        return
    md = ob.modifiers.new("dec", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = max(0.01, alvo / t)
    md.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=md.name)


TAREFAS = []
for g in sorted(glob.glob(os.path.join(ORIGEM, "*", "*.gltf"))):
    nome = os.path.basename(os.path.dirname(g))
    if nome in ALVOS:
        TAREFAS.append((g, nome, ALVOS[nome]))
    for saida_nome, (modelo, alvos) in LEVES.items():
        if modelo == nome:
            TAREFAS.append((g, saida_nome, alvos))
SO = os.environ.get("SO")
for g, nome, alvo in TAREFAS:
    if SO and nome not in SO.split(","):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=g)
    malhas = [ob for ob in bpy.context.scene.objects if ob.type == "MESH"]
    antes = sum(tris(ob) for ob in malhas)
    if isinstance(alvo, dict):
        # separa por material e reduz cada parte com o seu alvo
        for ob in malhas:
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.separate(type="MATERIAL")
            bpy.ops.object.mode_set(mode="OBJECT")
        for ob in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
            mat = ob.data.materials[0].name if ob.data.materials else ""
            decimar(ob, alvo.get(mat, 20000))
    else:
        for ob in malhas:
            decimar(ob, int(alvo * tris(ob) / max(1, antes)))
    depois = sum(tris(ob) for ob in bpy.context.scene.objects if ob.type == "MESH")
    saida = os.path.join(DESTINO, nome + ".glb")
    bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", export_image_format="AUTO",
                              export_apply=True, export_yup=True)
    print("PRONTO %-24s %8d -> %7d tris  %.1f MB" % (nome, antes, depois, os.path.getsize(saida) / 1e6), flush=True)
