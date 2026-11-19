# Teste da mata (2026-11-18): os modelos do Stylized Nature MegaKit que o jogo ainda não usava. Tufos de capim
# (folhas modeladas, sem textura: a cor vem do shader do capim), árvores de tronco torto (com a casca reduzida,
# que no pacote passa de 7 mil triângulos, e a versão de longe) e pétalas soltas.
# blender -b --factory-startup -P tools/vale/pacotes_mata.py -- <pasta others> <assets/vale/q>
import bpy, bmesh, random, sys, os
from mathutils import Vector

OUTROS, SAIDA = sys.argv[sys.argv.index("--") + 1:][:2]
KIT = os.path.join(OUTROS, "Stylized Nature MegaKit[Standard]", "glTF")

# nome no jogo: (arquivo, altura alvo em metros)
# (os outros três tufos do pacote, Common_Tall e os dois Wispy, têm de 326 a 622 triângulos: pesados demais para
# o campo inteiro)
CAPIM = {"q_capim_a": ("Grass_Common_Short", 0.50)}
TORTAS = {"q_torta_a": ("TwistedTree_1", 11.5), "q_torta_b": ("TwistedTree_3", 12.5), "q_torta_c": ("TwistedTree_5", 10.5),
          "q_torta_d": ("TwistedTree_2", 12.0), "q_torta_e": ("TwistedTree_4", 11.0)}
# as árvores de folha larga do pacote, no lugar das de copa "de bloco" (2026-11-19)
COMUNS = {"q_comum_a": ("CommonTree_1", 9.5), "q_comum_b": ("CommonTree_2", 10.5), "q_comum_c": ("CommonTree_3", 11.0),
          "q_comum_d": ("CommonTree_4", 10.0), "q_comum_e": ("CommonTree_5", 9.0)}
# pinheiros e árvores secas do mesmo pacote (os de antes vinham do Textured Stylized Trees)
PINHOS = {"q_pinheiro_n_a": ("Pine_1", 13.0), "q_pinheiro_n_b": ("Pine_2", 12.0), "q_pinheiro_n_c": ("Pine_3", 14.5),
          "q_pinheiro_n_d": ("Pine_4", 15.0), "q_pinheiro_n_e": ("Pine_5", 13.5)}
SECAS = {"q_seca_a": ("DeadTree_1", 8.5), "q_seca_b": ("DeadTree_2", 9.5), "q_seca_c": ("DeadTree_3", 10.0),
         "q_seca_d": ("DeadTree_4", 9.0), "q_seca_e": ("DeadTree_5", 10.5)}
# miúdos: (arquivo, altura alvo ou 0, triângulos no máximo ou 0)
MIUDOS = {"q_capim_alto": ("Grass_Common_Tall", 0.85, 0), "q_trevo_b": ("Clover_2", 0, 0), "q_orelha": ("Mushroom_Laetiporus", 0, 500),
          "q_laje_a": ("RockPath_Round_Small_1", 0, 160), "q_laje_b": ("RockPath_Round_Small_2", 0, 160),
          "q_laje_c": ("RockPath_Round_Small_3", 0, 160), "q_laje_d": ("RockPath_Round_Thin", 0, 260),
          "q_laje_e": ("RockPath_Round_Wide", 0, 320), "q_laje_f": ("RockPath_Square_Small_1", 0, 160),
          "q_laje_g": ("RockPath_Square_Small_2", 0, 160), "q_laje_h": ("RockPath_Square_Small_3", 0, 160),
          "q_laje_i": ("RockPath_Square_Thin", 0, 260), "q_laje_j": ("RockPath_Square_Wide", 0, 320),
          "q_seixo_c": ("Pebble_Round_2", 0, 0), "q_seixo_d": ("Pebble_Round_4", 0, 0), "q_seixo_e": ("Pebble_Round_5", 0, 0),
          "q_seixo_f": ("Pebble_Square_1", 0, 0), "q_seixo_g": ("Pebble_Square_2", 0, 0), "q_seixo_h": ("Pebble_Square_3", 0, 0),
          "q_seixo_i": ("Pebble_Square_4", 0, 0), "q_seixo_j": ("Pebble_Square_5", 0, 0), "q_seixo_k": ("Pebble_Square_6", 0, 0)}
PETALAS = {"q_petala_a": "Petal_1", "q_petala_b": "Petal_3", "q_petala_c": "Petal_5"}
MATS = {"Grass": "q_capim", "Bark_TwistedTree": "q_casca_torta", "Leaves_TwistedTree": "q_folha_torta", "Bark_NormalTree": "q_casca_comum",
        "Leaves_NormalTree": "q_folha_comum", "Leaves_Pine": "q_folha_pinho", "Bark_DeadTree": "q_casca_seca",
        "PathRocks": "q_seixo", "Mushrooms": "q_cogumelo", "Leaves": "q_planta", "Flowers": "q_flor"}


def abrir(arq):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(KIT, arq + ".gltf"))
    malhas = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(o.type == "MESH")
    bpy.context.view_layer.objects.active = malhas[0]
    if len(malhas) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for outro in list(bpy.data.objects):
        if outro != o:
            bpy.data.objects.remove(outro)
    return o


def altura(o, alvo):
    k = alvo / max(0.01, o.dimensions.z)
    o.scale = (k, k, k)
    bpy.ops.object.transform_apply(scale=True)


def materiais(o):
    nomes = [MATS.get(m.name.split(".")[0], "q_" + m.name.split(".")[0].lower()) for m in o.data.materials]
    for i, m in enumerate(o.data.materials):
        m.use_nodes = False
        m.name = "tmp%d" % i
    for i, m in enumerate(o.data.materials):
        m.name = nomes[i]
    return nomes


def reduzir(o, quanto):
    bpy.context.view_layer.objects.active = o
    # o glTF chega com os vértices separados nas costuras; sem juntar, o redutor para cedo
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.object.mode_set(mode="OBJECT")
    mod = o.modifiers.new("reduz", "DECIMATE")
    mod.ratio = quanto
    bpy.ops.object.modifier_apply(modifier=mod.name)


CRESCE = 1.6  # quanto a placa que fica pode crescer


def ralear(o, fica):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    falta = set(bm.verts)
    ilhas = []
    while falta:
        pilha = [falta.pop()]
        ilha = list(pilha)
        while pilha:
            for e in pilha.pop().link_edges:
                for w in e.verts:
                    if w in falta:
                        falta.discard(w)
                        pilha.append(w)
                        ilha.append(w)
        ilhas.append(ilha)
    ilhas.sort(key=lambda il: (round(il[0].co.x, 3), round(il[0].co.y, 3), round(il[0].co.z, 3)))
    rng = random.Random(3)
    fora = []
    for il in ilhas:
        if rng.random() > fica:
            fora.extend(il)
            continue
        c = sum((v.co for v in il), Vector()) / len(il)
        for v in il:
            v.co = c + (v.co - c) * min(CRESCE, fica ** -0.5)
    bmesh.ops.delete(bm, geom=fora, context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    print("  folhas: %d placas, ficam %d%%" % (len(ilhas), round(fica * 100)))


def gravar(nome):
    bpy.ops.export_scene.gltf(filepath=os.path.join(SAIDA, nome + ".glb"), export_format="GLB", export_image_format="NONE",
                              export_apply=True, export_animations=False, export_yup=True)


def tri(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


for nome, (arq, alvo) in CAPIM.items():
    o = abrir(arq)
    altura(o, alvo)
    materiais(o)
    gravar(nome)
    print("CAPIM %s (%s): %d triângulos, %s m" % (nome, arq, tri(o), [round(v, 2) for v in o.dimensions]))

def arvore(nome, arq, alvo, passos, com_sombra=True):
    """passos: [(sufixo, triângulos de casca que ficam (ou fração, se <= 1), placas de folha que ficam (idem))]"""
    o = abrir(arq)
    altura(o, alvo)
    materiais(o)
    antes = tri(o)
    # a casca é reduzida; as folhas são placas soltas (mais de mil por árvore, uma por cima da outra: pesou
    # uns 20% no fps), então uma parte sai e as que ficam crescem para a copa não rarear
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    partes = [p for p in bpy.data.objects if p.type == "MESH"]
    for sufixo, casca, folhas in passos:
        for p in partes:
            for q in bpy.data.objects:
                q.select_set(q == p)
            if p.data.materials[0].name.startswith("q_casca"):
                reduzir(p, casca if casca <= 1.0 else min(1.0, casca / tri(p)))
            else:
                fica = folhas if folhas <= 1.0 else min(1.0, folhas / (tri(p) / 2.0))
                if fica < 1.0:
                    ralear(p, fica)
        for q in bpy.data.objects:
            q.select_set(q.type == "MESH")
        bpy.context.view_layer.objects.active = partes[0]
        gravar(nome + sufixo)
        print("ARVORE %s%s (%s): %d de %d triângulos %s" % (nome, sufixo, arq, sum(tri(p) for p in partes), antes,
              [(p.data.materials[0].name, tri(p)) for p in partes]))
    if not com_sombra:
        return
    forma_de_sombra(nome, partes)


def forma_de_sombra(nome, partes):
    # a forma da sombra: a copa vira um casco fechado e a casca fica com uns 60 triângulos. A sombra das placas
    # de folha (recorte, uma por cima da outra) custava uns 20% do fps; o jogo desenha esta só no mapa de sombra
    mat_sombra = bpy.data.materials.new("q_sombra")
    for p in partes:
        if p.data.materials[0].name.startswith("q_casca"):
            reduzir(p, min(1.0, 60.0 / tri(p)))
        else:
            bm = bmesh.new()
            bm.from_mesh(p.data)
            casco = bmesh.ops.convex_hull(bm, input=bm.verts)
            fica = set(casco["geom"])
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if v not in fica], context="VERTS")
            # um pouco menor que a copa, para a sombra não ficar mais gorda que a árvore
            c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
            for v in bm.verts:
                v.co = c + (v.co - c) * 0.9
            bm.to_mesh(p.data)
            bm.free()
            if tri(p) > 90:
                reduzir(p, 90.0 / tri(p))
        p.data.materials[0] = mat_sombra
    gravar(nome + "_sombra")
    print("  sombra: %d triângulos" % sum(tri(p) for p in partes))


for nome, (arq, alvo) in TORTAS.items():
    arvore(nome, arq, alvo, [("", 0.2, 0.5), ("_longe", 0.2, 0.45)])

CRESCE = 1.3
for nome, (arq, alvo) in COMUNS.items():
    arvore(nome, arq, alvo, [("", 900, 450), ("_longe", 220, 170)])

for nome, (arq, alvo) in PINHOS.items():
    arvore(nome, arq, alvo, [("", 500, 400), ("_longe", 90, 160)])

# a árvore seca é só casca (opaca): não precisa de forma de sombra
for nome, (arq, alvo) in SECAS.items():
    arvore(nome, arq, alvo, [("", 1100, 1.0), ("_longe", 260, 1.0)], False)

# as bétulas vêm do outro pacote (tools/vale/pacotes.py); aqui só ganham a forma de sombra
for nome in ["q_betula_a", "q_betula_b", "q_betula_c"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SAIDA, nome + ".glb"))
    o = [x for x in bpy.data.objects if x.type == "MESH"][0]
    for q in bpy.data.objects:
        q.select_set(q == o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    forma_de_sombra(nome, [x for x in bpy.data.objects if x.type == "MESH"])

for nome, (arq, alvo, teto) in MIUDOS.items():
    o = abrir(arq)
    if alvo > 0:
        altura(o, alvo)
    materiais(o)
    antes = tri(o)
    if teto > 0 and antes > teto:
        reduzir(o, teto / antes)
    gravar(nome)
    print("MIUDO %s (%s): %d de %d triângulos, %s m" % (nome, arq, tri(o), antes, [round(v, 2) for v in o.dimensions]))

for nome, arq in PETALAS.items():
    o = abrir(arq)
    # a pétala no meio da própria malha, para girar em torno de si no ar
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    o.location = (0, 0, 0)
    bpy.ops.object.transform_apply(location=True)
    materiais(o)
    gravar(nome)
    print("PETALA %s (%s): %d triângulos, %s m" % (nome, arq, tri(o), [round(v, 2) for v in o.dimensions]))
