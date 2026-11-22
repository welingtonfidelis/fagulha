# Folha com as peças baixadas do OpenGameArt para o vilarejo (Projects/others/bibliotecas/oga-vilarejo), cada uma
# com o robô de 1,2 m ao lado, para ver o tamanho e a cara delas antes de escolher. Nada daqui vai ao jogo.
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/arte/vilarejo_pecas_oga.py \
#       -- [pasta das peças] [pasta de saída]
import math
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ dentro de tools/arte
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_arte as ba  # noqa: E402
import importar_3ds  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

arg = ba.argumentos()
LIB = os.path.abspath(arg[0]) if arg else os.path.join(os.path.dirname(ba.RAIZ), "bibliotecas", "oga-vilarejo")
PASTA = os.path.abspath(arg[1]) if len(arg) > 1 else os.path.join(ba.RAIZ, "tools", "capturas", "vilarejo")
ba.limpar()


def _de_blend(caminho):
    with bpy.data.libraries.load(caminho, link=False) as (de, para):
        para.objects = list(de.objects)
    objs = [o for o in para.objects if o is not None and o.type == "MESH"]
    for o in objs:
        ba.cena().collection.objects.link(o)
    return objs


def _importar(caminho):
    """Devolve (malhas, raízes): as raízes são os objetos novos sem pai, vazios incluídos."""
    antes = set(bpy.data.objects)
    ext = caminho.lower().rsplit(".", 1)[-1]
    if ext == "blend":
        objs = _de_blend(caminho)
        return objs, [o for o in objs if o.parent is None or o.parent not in objs]
    if ext == "3ds":
        objs = importar_3ds.importar(caminho)
        return objs, objs
    if ext in ("glb", "gltf"):
        bpy.ops.import_scene.gltf(filepath=caminho)
    elif ext == "fbx":
        bpy.ops.import_scene.fbx(filepath=caminho)
    elif ext == "obj":
        bpy.ops.wm.obj_import(filepath=caminho)
    novos = [o for o in bpy.data.objects if o not in antes]
    malhas = [o for o in novos if o.type == "MESH"]
    # alguns .fbx trazem o material com alfa zero e a peça some na foto
    for o in malhas:
        for sl in o.material_slots:
            m = sl.material
            if m and m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "BSDF_PRINCIPLED":
                        n.inputs["Alpha"].default_value = 1.0
    return malhas, [o for o in novos if o.parent is None]


def _material_tex(png):
    m = bpy.data.materials.new("tex_" + os.path.basename(png))
    m.use_nodes = True
    t = m.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(png, check_existing=True)
    m.node_tree.links.new(t.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def _com_textura(objs, texturas):
    """Põe a textura difusa nas peças que vieram sem ela (alguns .obj, .fbx e .blend antigos não acham a imagem).
    `texturas`: [(pedaço do nome do material, png), ...]; o pedaço "" vale para o resto."""
    for o in objs:
        if not o.material_slots:
            o.data.materials.append(None)
        for slot in o.material_slots:
            m = slot.material
            if m and m.use_nodes and any(n.type == "TEX_IMAGE" and n.image for n in m.node_tree.nodes):
                continue
            nome = (m.name if m else "").lower()
            png = next((p for pedaco, p in texturas if pedaco and pedaco in nome), None)
            png = png or next((p for pedaco, p in texturas if not pedaco), None)
            if png:
                slot.material = _material_tex(png)


def _caixa(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def _arrumar(objs, raizes, escala, espalhar):
    """Junta as peças num vazio, na escala pedida, com a base no chão e o centro no zero. Com `espalhar`,
    põe cada peça solta em fila (os pacotes de várias peças vêm todas no mesmo lugar)."""
    raiz = bpy.data.objects.new("_raiz", None)
    ba.cena().collection.objects.link(raiz)
    for o in raizes:
        o.parent = raiz
    raiz.scale = (escala, escala, escala)
    if espalhar:
        x = 0.0
        for o in raizes:
            lo, hi = _caixa([m for m in objs if m == o or o in m.parent_recursive] or [o])
            o.location.x += (x - lo.x) / escala
            x += (hi.x - lo.x) + 0.6
    lo, hi = _caixa(objs)
    raiz.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
    return raiz


# (legenda, arquivo relativo à pasta, escala até metros, texturas para quem veio sem, espalhar as peças)
PECAS = [
    ("Casa velha pequena · CC-BY 3.0 (Vinrax)", "casa-velha/House.blend", 1.0,
     [("", "casa-velha/tex/house_tex.png")], False),
    ("Muros destruídos · CC-BY 3.0 (LFA)", "muros-destruidos/destroyedWalls_UV1.obj", 0.1,
     [("", "muros-destruidos/wall.bmp")], False),
    ("Celeiro velho · CC0 (carlosjorgereis)", "celeiro-velho/celeiro.glb", 1.0,
     [("straw", "celeiro-velho/textures/straw diffuse.png"), ("palha", "celeiro-velho/textures/straw diffuse.png"),
      ("", "celeiro-velho/textures/madeira diffuse Color.png")], False),
    ("Cerca velha · CC0 (carlosjorgereis)", "cerca-velha/cerca.glb", 1.0, [("", "cerca-velha/diffuse.png")], False),
    ("Cerca de metal velha · CC0 (Paul Wortmann)", "cerca-metal/old_metal_fence/obj export/fence_metal_1_001.obj",
     1.0, [("", "cerca-metal/old_metal_fence/textures/fence_metal_1_001_d.png")], False),
    ("Calçamento com muro · CC-BY 3.0 (twochch)", "calcamento/path to the house/path to the house.3ds", 0.001, None,
     False),
    ("Ruas modulares · CC0 (Quaternius)", "ruas-quaternius/Street Pack by @Quaternius/FBX/Streets_all.fbx", 1.0, None,
     False),
]
EXTRA = os.path.join(LIB, "_pecas_extra.txt")  # linhas "legenda|arquivo|escala|textura|espalhar" para os que faltarem
if os.path.exists(EXTRA):
    for linha in open(EXTRA, encoding="utf-8"):
        p = [x.strip() for x in linha.split("|")]
        if len(p) == 5:
            PECAS.append((p[0], p[1], float(p[2]), [("", p[3])] if p[3] else None, p[4] == "1"))
ESCALAS = {}  # legenda -> escala, para acertar as que vierem em polegadas ou centímetros

E = ba.Estudio(os.path.join(PASTA, "_paineis_oga"))
E.robo(pos=(0, 0, 0))
robo_raiz = E.robo_objs[-1]
paineis = []
grupos = []
for k, (leg, rel, esc, tex, espalhar) in enumerate(PECAS):
    caminho = os.path.join(LIB, rel)
    if not os.path.exists(caminho):
        print("falta", caminho)
        continue
    objs, raizes = _importar(caminho)
    if not objs:
        print("não abriu", caminho)
        continue
    if tex:
        _com_textura(objs, [(pedaco, os.path.join(LIB, png)) for pedaco, png in tex])
    raiz = _arrumar(objs, raizes, ESCALAS.get(leg, esc), espalhar)
    lo, hi = _caixa(objs)
    tam = hi - lo
    mats = sorted({sl.material.name for o in objs for sl in o.material_slots if sl.material})
    print("%s: %.2f x %.2f x %.2f m, %d objetos, %d triângulos, materiais %s" % (
        leg, tam.x, tam.y, tam.z, len(objs), ba.triangulos(objs), mats))
    grupos.append((leg, raiz, objs, lo, hi))

for leg, raiz, objs, lo, hi in grupos:
    for _, r2, o2, _, _ in grupos:
        for o in o2:
            o.hide_render = r2 is not raiz
    tam = hi - lo
    # o robô à esquerda da quina mais perto da câmera, um pouco recuado
    robo_raiz.location.x = lo.x - 0.8
    robo_raiz.location.y = lo.y + 0.3
    a = Vector((lo.x - 1.2, lo.y - 0.2, 0.0))
    b = Vector((hi.x, hi.y, max(hi.z, 1.2)))
    centro = (a + b) / 2
    raio = (b - a).length / 2
    # lente de 40 mm na foto de 1280 x 800: 31° na vertical; a esfera em volta de tudo cabe com folga
    d = raio / math.sin(math.radians(15.0)) * 0.78
    loc = tuple(centro + Vector((-0.6, -0.75, 0.36)).normalized() * d)
    nome = "oga_%d" % len(paineis)
    txt = "%s · %.1f × %.1f × %.1f m" % (leg, tam.x, tam.y, tam.z)
    paineis.append((txt, E.foto(nome, loc, tuple(centro), lente=40)))

ba.folha(paineis, os.path.join(PASTA, "oga_pecas.png"), colunas=2,
         titulo="Peças do OpenGameArt para o vilarejo, como vieram (texturas originais), com o robô de 1,2 m")
