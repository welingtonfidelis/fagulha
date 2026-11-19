# Árvores e plantas dos pacotes do Quaternius (CC0) para o vale: escolhe os modelos, acerta a escala, dá aos
# materiais os nomes que o jogo conhece (as texturas ficam em assets/vale/q/ e os shaders são os do vale) e
# grava um .glb por modelo, mais a versão de longe das árvores (malha reduzida).
# blender -b --factory-startup -P tools/vale/pacotes.py -- <pasta others> <assets/vale/q>
import bpy, sys, os

OUTROS, SAIDA = sys.argv[sys.argv.index("--") + 1:][:2]
ARV = os.path.join(OUTROS, "Textured Stylized Trees - May 2020", "FBX")
KIT = os.path.join(OUTROS, "Stylized Nature MegaKit[Standard]", "glTF")

# nome no jogo: (arquivo, altura alvo em metros; 0 = como veio)
ARVORES = {
    # (as outras árvores, pinheiros e secas vêm do MegaKit: tools/vale/pacotes_mata.py)
    "q_arvore_b": ("Tree_4", 10.5),
    "q_betula_a": ("Birch_1", 11.5), "q_betula_b": ("Birch_4", 12.5), "q_betula_c": ("Birch_8", 10.5),
}
PLANTAS = {
    "q_samambaia": ("Fern_1", 0), "q_planta_a": ("Plant_1", 0), "q_planta_b": ("Plant_1_Big", 0), "q_planta_c": ("Plant_7", 0),
    "q_planta_d": ("Plant_7_Big", 0), "q_flor_a": ("Flower_3_Group", 0), "q_flor_b": ("Flower_3_Single", 0),
    "q_flor_c": ("Flower_4_Group", 0), "q_flor_d": ("Flower_4_Single", 0), "q_cogumelo": ("Mushroom_Common", 0),
    "q_moita": ("Bush_Common", 0), "q_moita_flor": ("Bush_Common_Flowers", 0), "q_trevo": ("Clover_1", 0),
    "q_pedra_a": ("Rock_Medium_1", 0), "q_pedra_b": ("Rock_Medium_2", 0), "q_pedra_c": ("Rock_Medium_3", 0),
    "q_seixo_a": ("Pebble_Round_1", 0), "q_seixo_b": ("Pebble_Round_3", 0),
}
# material do pacote -> material do jogo
MATS = {"Bark": "q_casca", "Birch_Bark": "q_casca_betula", "Tree_Leaves": "q_folha", "Birch_Leaves": "q_folha_betula",
        "Pine_Leaves": "q_folha_pinheiro"}
IMAGENS = {"Leaves": "q_planta", "Flowers": "q_flor", "Mushrooms": "q_cogumelo", "Rocks_Diffuse": "q_pedra",
           "PathRocks_Diffuse": "q_seixo", "Grass": "q_capim", "Leaves_TwistedTree_C": "q_moita", "Leaves_NormalTree_C": "q_moita"}


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def nome_do_material(m):
    base = m.name.split(".")[0]
    if base in MATS:
        return MATS[base]
    if m.node_tree:
        for nd in m.node_tree.nodes:
            if nd.type == "TEX_IMAGE" and nd.image:
                img = os.path.splitext(nd.image.name)[0]
                if img in IMAGENS and "Normal" not in img:
                    return IMAGENS[img]
    return "q_" + base.lower()


def preparar(alvo):
    malhas = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(o.type == "MESH")
    bpy.context.view_layer.objects.active = malhas[0]
    if len(malhas) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if alvo > 0:
        k = alvo / max(0.01, o.dimensions.z)
        o.scale = (k, k, k)
        bpy.ops.object.transform_apply(scale=True)
    usados = {}
    for i, m in enumerate(o.data.materials):
        novo = nome_do_material(m)
        m.name = novo + "__tmp%d" % i
        usados[i] = novo
    for i, m in enumerate(o.data.materials):
        # materiais simples, sem imagem: o jogo troca pelo shader dele
        m.use_nodes = False
        m.name = usados[i]
    for outro in list(bpy.data.objects):
        if outro != o:
            bpy.data.objects.remove(outro)
    return o


def gravar(nome):
    bpy.ops.export_scene.gltf(filepath=os.path.join(SAIDA, nome + ".glb"), export_format="GLB", export_image_format="NONE",
                              export_apply=True, export_animations=False, export_yup=True)


def tri(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


for nome, (arq, alvo) in ARVORES.items():
    limpar()
    bpy.ops.import_scene.fbx(filepath=os.path.join(ARV, arq + ".fbx"))
    o = preparar(alvo)
    perto = tri(o)
    gravar(nome)
    mod = o.modifiers.new("reduz", "DECIMATE")
    mod.ratio = 0.22
    bpy.ops.object.modifier_apply(modifier=mod.name)
    gravar(nome + "_longe")
    print("ARVORE %s (%s): %d triângulos perto, %d longe, %.1f m, materiais %s" % (nome, arq, perto, tri(o), o.dimensions.z, [m.name for m in o.data.materials]))

for nome, (arq, alvo) in PLANTAS.items():
    limpar()
    bpy.ops.import_scene.gltf(filepath=os.path.join(KIT, arq + ".gltf"))
    o = preparar(alvo)
    gravar(nome)
    print("PLANTA %s (%s): %d triângulos, %s m, materiais %s" % (nome, arq, tri(o), [round(v, 2) for v in o.dimensions], [m.name for m in o.data.materials]))
