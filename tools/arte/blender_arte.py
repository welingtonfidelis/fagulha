# Caixa de ferramentas de arte do Fagulha para o Blender (2026-11-22).
#
# Funções comuns para fazer modelos nossos, sob medida, no caminho de artista do agente artista-3d
# (.claude/agents/artista-3d.md):
#   - peças: caixa, cilindro, esfera, moldura (um aro), com chanfro e normais pesadas no fim (acabar);
#   - modificadores: recorte (boolean), repetir (array), chapa (solidify), colar (shrinkwrap);
#   - mexer na malha: subdividir, amassar, tremer;
#   - cabos caindo em barriga (cabo), canos com curvas (tubo), formas orgânicas (organico, relevo) e rochas (rocha);
#   - aplicar, juntar, uv_auto, assar (a textura pintada no Cycles), exportar (.glb) e triangulos; limpo marca
#     o que não enferruja nem encarde na pintura (borracha, plástico, vidro);
#   - fotos de estudo (Estudio): vistas, giro, silhueta, silhueta de longe e a folha com os painéis.
#
# Uso, num script em tools/arte/ (ver exemplo_caixa_forca.py e exemplo_caixa_forca_estudo.py):
#   import os, sys
#   sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
#   import blender_arte as ba
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/arte/<script>.py -- <saída>
#
# Convenções do jogo: metros reais, origem no pé, frente para -Y (vira +Z na Godot), Z para cima. Os materiais
# levam os nomes que o jogo conhece (Clareira.material: concreto, lata_verde, ferrugem, junta, vidro_velho...)
# ou, no caminho pintado, uma textura só (tools/arte/vitrine_arte.gd põe no shader vale_base).
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector, noise

R = math.radians
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))  # a pasta do jogo
ROBO = os.path.join(RAIZ, "assets", "vale", "robo_v2.glb")
ALTURA_ROBO = 1.2
FONTE = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
# a câmera do jogo no chão: 70° na vertical (Ajustes.FOV_CHAO), numa tela de 1080 linhas
FOV_JOGO = 70.0
TELA_JOGO = 1080


def argumentos():
    """O que vem depois de `--` na linha de comando."""
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def cena():
    return bpy.context.scene


def limpar():
    """Esvazia a cena (objetos, malhas, curvas, materiais, luzes, câmeras, imagens e texturas)."""
    for colecao in (bpy.data.objects, bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.lights,
                    bpy.data.cameras, bpy.data.textures, bpy.data.images):
        for item in list(colecao):
            try:
                colecao.remove(item)
            except Exception:
                pass
    _MATS.clear()
    return cena()


# ---------------------------------------------------------------- materiais

_MATS = {}


def linear(c):
    """Cor sRGB (como as do jogo, `Color(...)` no GDScript) para a linear do Blender."""
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c[:3])


def material(nome, cor, metal=0.0, rug=0.65, emissao=0.0, srgb=True):
    """Material simples (Principled). Use os nomes que o jogo conhece: no caminho simples o jogo troca cada um
    pelo dele (Clareira.material); no caminho pintado a cor daqui vira a base da textura. `cor` vem em sRGB,
    nos mesmos números da tabela do jogo (scripts/vale/clareira.gd); `srgb=False` para cor já linear."""
    if nome in _MATS:
        return _MATS[nome]
    cor = linear(cor) if srgb else tuple(cor[:3])
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (cor[0], cor[1], cor[2], 1.0)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rug
    if emissao > 0.0:
        p.inputs["Emission Color"].default_value = (cor[0], cor[1], cor[2], 1.0)
        p.inputs["Emission Strength"].default_value = emissao
    m.diffuse_color = (cor[0], cor[1], cor[2], 1.0)
    _MATS[nome] = m
    return m


def cor_de(m):
    p = m.node_tree.nodes.get("Principled BSDF") if m.use_nodes else None
    c = p.inputs["Base Color"].default_value if p else m.diffuse_color
    return (c[0], c[1], c[2])


# ---------------------------------------------------------------- peças

def _rot(rot):
    return Euler((R(rot[0]), R(rot[1]), R(rot[2])), "XYZ")


def _objeto(nome, bm, mat, pai, chanfro, segs, pos, rot):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    if mat:
        me.materials.append(mat)
    ob = bpy.data.objects.new(nome, me)
    cena().collection.objects.link(ob)
    ob["chanfro"] = chanfro
    ob["segs"] = segs
    ob.location = pos
    ob.rotation_euler = _rot(rot)
    if pai:
        ob.parent = pai
    return ob


def caixa(nome, tam, pos=(0, 0, 0), rot=(0, 0, 0), mat=None, chanfro=0.015, segs=3, pai=None, topo=(1.0, 1.0),
          base=False):
    """Caixa de `tam` (x, y, z) metros. `topo` afina a face de cima (fração de x e de y). Com `base`, a origem
    fica na face de baixo (para o que pousa no chão). O chanfro entra no fim, em `acabar`."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x *= topo[0]
            v.co.y *= topo[1]
        v.co.x *= tam[0]
        v.co.y *= tam[1]
        v.co.z = v.co.z * tam[2] + (tam[2] * 0.5 if base else 0.0)
    return _objeto(nome, bm, mat, pai, chanfro, segs, pos, rot)


def cilindro(nome, raio, altura, pos=(0, 0, 0), rot=(0, 0, 0), mat=None, lados=24, chanfro=0.006, segs=2, pai=None,
             raio_topo=None, base=False):
    """Cilindro em pé (eixo Z) de `altura` m; `raio_topo` faz cone. Com `base`, a origem fica embaixo."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=lados, radius1=raio,
                          radius2=raio if raio_topo is None else raio_topo, depth=altura)
    if base:
        for v in bm.verts:
            v.co.z += altura * 0.5
    return _objeto(nome, bm, mat, pai, chanfro, segs, pos, rot)


def moldura(nome, largura, altura, aba, fundo, pos=(0, 0, 0), rot=(0, 0, 0), mat=None, chanfro=0.0, segs=2,
            pai=None):
    """Um aro retangular em pé, de frente para -Y: `largura` x `altura` por fora, `aba` de largura da faixa e
    `fundo` de espessura em Y. Serve de moldura (porta, janela, placa) ou, num `recorte`, cava a fresta em volta
    de uma porta."""
    bm = bmesh.new()
    ext = [(-largura / 2, -altura / 2), (largura / 2, -altura / 2), (largura / 2, altura / 2), (-largura / 2, altura / 2)]
    li, ai = largura / 2 - aba, altura / 2 - aba
    inn = [(-li, -ai), (li, -ai), (li, ai), (-li, ai)]
    frente = [bm.verts.new((x, -fundo / 2, z)) for x, z in ext] + [bm.verts.new((x, -fundo / 2, z)) for x, z in inn]
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((frente[i], frente[j], frente[4 + j], frente[4 + i]))
    res = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    for v in [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]:
        v.co.y += fundo
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _objeto(nome, bm, mat, pai, chanfro, segs, pos, rot)


def esfera(nome, raio, pos=(0, 0, 0), rot=(0, 0, 0), mat=None, gomos=24, aneis=14, escala=(1, 1, 1), pai=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=gomos, v_segments=aneis, radius=raio)
    for v in bm.verts:
        v.co.x *= escala[0]
        v.co.y *= escala[1]
        v.co.z *= escala[2]
    ob = _objeto(nome, bm, mat, pai, 0.0, 0, pos, rot)
    ob["liso"] = True
    return ob


# ---------------------------------------------------------------- modificadores

def recorte(alvo, cortador):
    """Tira `cortador` de `alvo` (boolean exato). O cortador some do render e da exportação."""
    md = alvo.modifiers.new("recorte", "BOOLEAN")
    md.operation = "DIFFERENCE"
    md.solver = "EXACT"
    md.object = cortador
    # as paredes do corte ficam com a pintura da peça (sem isso, o corte deixa um espaço de material vazio)
    if cortador.type == "MESH" and alvo.data.materials:
        cortador.data.materials.clear()
        cortador.data.materials.append(alvo.data.materials[0])
    cortador.hide_render = True
    cortador.display_type = "WIRE"
    cortador["ajudante"] = True
    return md


def repetir(ob, n, passo):
    """`n` cópias da peça, cada uma deslocada `passo` (x, y, z) metros."""
    md = ob.modifiers.new("repete", "ARRAY")
    md.count = n
    md.use_relative_offset = False
    md.use_constant_offset = True
    md.constant_offset_displace = passo
    return md


def chapa(ob, espessura, para_fora=True):
    """Dá espessura a uma superfície (chapa, folha, toldo)."""
    md = ob.modifiers.new("chapa", "SOLIDIFY")
    md.thickness = espessura
    md.offset = 1.0 if para_fora else -1.0
    return md


def colar(ob, alvo, folga=0.002):
    """Cola a peça na superfície de `alvo` (placas, remendos)."""
    md = ob.modifiers.new("cola", "SHRINKWRAP")
    md.target = alvo
    md.offset = folga
    return md


def acabar(objs=None, angulo=30.0):
    """O acabamento de toda peça dura, no fim da pilha (depois dos recortes e repetições): chanfro em toda aresta
    mais fechada que `angulo` (pega a luz e acende o brilho de borda do jogo) e normais pesadas pela face (as
    faces grandes ficam lisas). Peças `liso` ou `organico` só ganham sombreado suave."""
    for ob in objs or list(cena().objects):
        if ob.type != "MESH" or ob.get("ajudante") or ob.get("referencia") or ob.get("acabado"):
            continue
        me = ob.data
        if ob.get("liso") or ob.get("organico"):
            if not ob.get("facetas"):
                for p in me.polygons:
                    p.use_smooth = True
            ob["acabado"] = True
            continue
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=R(angulo))
        ch = float(ob.get("chanfro", 0.0))
        if ch > 0.0:
            b = ob.modifiers.new("chanfro", "BEVEL")
            b.width = ch
            b.segments = int(ob.get("segs", 3))
            b.limit_method = "ANGLE"
            b.angle_limit = R(angulo)
            b.harden_normals = True
            b.miter_outer = "MITER_ARC"
            b.use_clamp_overlap = True
        w = ob.modifiers.new("normais", "WEIGHTED_NORMAL")
        w.keep_sharp = True
        w.weight = 50
        ob["acabado"] = True
    _conferir_chanfros(objs)


def _tamanho(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = [Vector(c) for c in ob.evaluated_get(dg).bound_box]
    return max((max(p[i] for p in pts) - min(p[i] for p in pts)) for i in range(3))


def _conferir_chanfros(objs=None):
    """O chanfro em cima de um recorte às vezes estoura (um vértice voa quilômetros). Mede cada peça recortada
    com e sem o chanfro: se ele cresce a peça, tenta a quina reta e, se nem assim, tira o chanfro e avisa."""
    for ob in objs or list(cena().objects):
        b = ob.modifiers.get("chanfro") if ob.type == "MESH" else None
        if b is None or not any(m.type == "BOOLEAN" for m in ob.modifiers):
            continue
        b.show_viewport = False
        bpy.context.view_layer.update()
        sem = _tamanho(ob)
        b.show_viewport = True
        bpy.context.view_layer.update()
        if _tamanho(ob) <= sem * 1.05 + 0.05:
            continue
        b.miter_outer = "MITER_SHARP"
        bpy.context.view_layer.update()
        if _tamanho(ob) <= sem * 1.05 + 0.05:
            print("acabar: o chanfro de %s estourava com a quina em arco; ficou reta" % ob.name)
            continue
        ob.modifiers.remove(b)
        print("acabar: o chanfro de %s estourava; ficou sem chanfro" % ob.name)


# ---------------------------------------------------------------- mexer na malha

def subdividir(ob, cortes=4):
    """Corta as arestas em `cortes` para ter vértices onde amassar."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cortes, use_grid_fill=True)
    bm.to_mesh(ob.data)
    bm.free()


def amassar(ob, centro, raio, fundo, direcao=None):
    """Um amassado: os vértices a menos de `raio` m de `centro` (coordenada local) afundam até `fundo` m, com
    queda suave. Sem `direcao`, afunda contra a normal de cada vértice."""
    c = Vector(centro)
    me = ob.data
    for v in me.vertices:
        d = (v.co - c).length
        if d < raio:
            t = 1.0 - d / raio
            t = t * t * (3.0 - 2.0 * t)
            dirv = Vector(direcao).normalized() if direcao else -v.normal
            v.co += dirv * fundo * t
    me.update()


def tremer(ob, forca=0.004, escala=3.0, semente=0):
    """Tira a perfeição de régua: cada vértice anda um pouco num ruído suave (nada fica reto de verdade)."""
    off = Vector((semente * 17.3, semente * 5.1, semente * 11.7))
    me = ob.data
    for v in me.vertices:
        v.co += noise.noise_vector(v.co * escala + off) * forca
    me.update()


# ---------------------------------------------------------------- cabos

def cabo(nome, a, b, caimento=0.15, raio=0.012, mat=None, pontos=28, pai=None, chao=0.0):
    """Cabo ou tubo flexível de `a` a `b`, caindo em barriga (`caimento` m no meio). O que passaria do chão
    (`chao`) deita nele. Vira malha em `aplicar`/`juntar`."""
    a, b = Vector(a), Vector(b)
    cv = bpy.data.curves.new(nome, "CURVE")
    cv.dimensions = "3D"
    cv.bevel_depth = raio
    cv.bevel_resolution = 3
    cv.use_fill_caps = True
    sp = cv.splines.new("POLY")
    sp.points.add(pontos - 1)
    for i in range(pontos):
        t = i / (pontos - 1)
        p = a.lerp(b, t)
        p.z -= caimento * 4.0 * t * (1.0 - t)
        p.z = max(p.z, chao + raio)
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
    if mat:
        cv.materials.append(mat)
    ob = bpy.data.objects.new(nome, cv)
    cena().collection.objects.link(ob)
    ob["liso"] = True
    if pai:
        ob.parent = pai
    return ob


def tubo(nome, pontos, raio=0.02, mat=None, curva=0.05, pai=None, passos=6):
    """Tubo rígido (conduíte, cano) pelos `pontos`, com as quinas arredondadas em `curva` m de raio."""
    pts = [Vector(p) for p in pontos]
    linha = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        r = min(curva, (b - a).length * 0.45, (c - b).length * 0.45)
        p0 = b + (a - b).normalized() * r
        p1 = b + (c - b).normalized() * r
        for k in range(passos + 1):
            t = k / passos
            linha.append(p0 * (1 - t) ** 2 + b * 2 * t * (1 - t) + p1 * t * t)
    linha.append(pts[-1])
    cv = bpy.data.curves.new(nome, "CURVE")
    cv.dimensions = "3D"
    cv.bevel_depth = raio
    cv.bevel_resolution = 3
    cv.use_fill_caps = True
    sp = cv.splines.new("POLY")
    sp.points.add(len(linha) - 1)
    for i, p in enumerate(linha):
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
    if mat:
        cv.materials.append(mat)
    ob = bpy.data.objects.new(nome, cv)
    cena().collection.objects.link(ob)
    ob["liso"] = True
    if pai:
        ob.parent = pai
    return ob


# ---------------------------------------------------------------- orgânicos

def _ajudante_vazio(nome, pos):
    e = bpy.data.objects.new(nome, None)
    e.location = pos
    cena().collection.objects.link(e)
    e["ajudante"] = True
    return e


def organico(nome, nos, ligacoes, raios, mat=None, voxel=0.02, suave=1, pos=(0, 0, 0), pai=None):
    """Forma orgânica de um esqueleto de linhas: `nos` (pontos), `ligacoes` (pares de índices) e `raios` (um por
    nó, a grossura ali). Pele (Skin), Remesh de voxel (`voxel` m) e Subdivision (`suave` níveis)."""
    me = bpy.data.meshes.new(nome)
    me.from_pydata([Vector(p) for p in nos], ligacoes, [])
    me.update()
    if mat:
        me.materials.append(mat)
    ob = bpy.data.objects.new(nome, me)
    cena().collection.objects.link(ob)
    ob.location = pos
    if pai:
        ob.parent = pai
    sk = ob.modifiers.new("pele", "SKIN")
    sk.use_smooth_shade = True
    for i, r in enumerate(raios):
        sv = me.skin_vertices[0].data[i]
        sv.radius = (r, r) if not isinstance(r, (tuple, list)) else tuple(r)
        sv.use_root = i == 0
    rm = ob.modifiers.new("voxel", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    rm.use_smooth_shade = True
    if suave > 0:
        ss = ob.modifiers.new("suave", "SUBSURF")
        ss.levels = suave
        ss.render_levels = suave
    ob["organico"] = True
    return ob


def relevo(ob, camadas=((0.35, 0.04), (0.12, 0.012)), semente=0, alisar=0.5):
    """Relevo de ruído em várias escalas: cada camada é (tamanho do grão em m, força em m). `alisar` passa um
    Smooth leve por cima, para tirar o chiado."""
    ref = _ajudante_vazio(ob.name + "_ruido", (semente * 7.31, semente * 3.17, semente * 5.23))
    for i, (grao, forca) in enumerate(camadas):
        tx = bpy.data.textures.new("%s_ruido%d" % (ob.name, i), "CLOUDS")
        tx.noise_scale = grao
        tx.noise_depth = 2
        tx.noise_basis = "ORIGINAL_PERLIN" if i % 2 == 0 else "IMPROVED_PERLIN"
        md = ob.modifiers.new("relevo%d" % i, "DISPLACE")
        md.texture = tx
        md.strength = forca
        md.mid_level = 0.5
        md.texture_coords = "OBJECT"
        md.texture_coords_object = ref
    if alisar > 0.0:
        sm = ob.modifiers.new("alisa", "SMOOTH")
        sm.factor = alisar
        sm.iterations = 2


def rocha(nome, tam=(1.0, 0.9, 0.7), semente=0, mat=None, facetas=7.0, pos=(0, 0, 0), rot=(0, 0, 0), pai=None):
    """Rocha: uma bola deformada, Remesh de voxel, relevo em duas escalas e, com `facetas` (graus), Decimate
    planar, que dá as faces largas que combinam com a luz pintada. Fica com a base achatada no z = 0."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.5)
    off = Vector((semente * 3.7, semente * 1.9, semente * 2.3))
    for v in bm.verts:
        v.co += v.co.normalized() * noise.noise(v.co * 1.6 + off) * 0.22
        v.co.x *= tam[0]
        v.co.y *= tam[1]
        v.co.z *= tam[2]
        v.co.z = max(v.co.z + tam[2] * 0.42, 0.0)  # a base achatada, enterrada no chão
    ob = _objeto(nome, bm, mat, pai, 0.0, 0, pos, rot)
    grande = max(tam)
    rm = ob.modifiers.new("voxel", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = grande / 45.0
    relevo(ob, ((grande * 0.5, grande * 0.10), (grande * 0.16, grande * 0.03)), semente, alisar=0.3)
    if facetas:
        dc = ob.modifiers.new("facetas", "DECIMATE")
        dc.decimate_type = "DISSOLVE"
        dc.angle_limit = R(facetas)
        ob["facetas"] = True
    ob["organico"] = True
    return ob


# ---------------------------------------------------------------- aplicar, juntar, exportar

def aplicar(ob):
    """Grava os modificadores na malha (uma curva vira malha). Devolve o objeto novo, com o mesmo nome."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    nome = ob.name
    novo = bpy.data.objects.new(nome + "_ap", me)
    cena().collection.objects.link(novo)
    novo.parent = ob.parent
    novo.matrix_parent_inverse = ob.matrix_parent_inverse.copy()
    novo.matrix_basis = ob.matrix_basis.copy()
    for k in ob.keys():
        novo[k] = ob[k]
    novo["acabado"] = True
    # os filhos passam para o novo no mesmo lugar. A conta é feita com a matrix_world do velho: a do novo só vale
    # depois da próxima avaliação da cena, e usá-la aqui girava o filho duas vezes (o reboco voava da parede)
    w_pai = ob.matrix_world.copy()
    for filho in list(ob.children):
        mw = filho.matrix_world.copy()
        filho.parent = novo
        filho.matrix_parent_inverse.identity()
        filho.matrix_basis = w_pai.inverted() @ mw
    bpy.data.objects.remove(ob)
    novo.name = nome
    return novo


def pecas(objs=None):
    """As peças de verdade da cena: sem cortadores, ajudantes e referências (o robô, o chão)."""
    return [o for o in (objs or cena().objects) if o.type in ("MESH", "CURVE")
            and not o.get("ajudante") and not o.get("referencia")]


def limpo(*objs):
    """Marca peças que não enferrujam nem encardem na pintura (assar): borracha, plástico, vidro. Pela peça,
    não pelo material: o cabo de borracha e a dobradiça podem dividir o material "junta"."""
    for o in objs:
        o["limpo"] = True
    return objs[0] if len(objs) == 1 else objs


def juntar(nome, objs=None):
    """Aplica e junta as peças numa malha só (para assar a textura e para o jogo ter um nó só). A marca de
    `limpo` vira o atributo de vértice "limpo", que o assar lê."""
    feitos = [aplicar(o) for o in pecas(objs)]
    # a peça aplicada por último ainda não tem a matrix_world calculada: sem isto ela vai parar na origem
    bpy.context.view_layer.update()
    for o in feitos:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
        at = o.data.attributes.new("limpo", "FLOAT", "POINT")
        at.data.foreach_set("value", [1.0 if o.get("limpo") else 0.0] * len(o.data.vertices))
    alvo = feitos[0]
    with bpy.context.temp_override(active_object=alvo, object=alvo, selected_objects=feitos,
                                   selected_editable_objects=feitos):
        bpy.ops.object.join()
    alvo.name = nome
    alvo.data.name = nome
    return alvo


def uv_auto(ob, angulo=66.0, margem=0.004):
    """Abre as UVs por projeção automática (Smart UV Project)."""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=R(angulo), island_margin=margem)
    bpy.ops.object.mode_set(mode="OBJECT")


def triangulos(objs=None):
    dg = bpy.context.evaluated_depsgraph_get()
    total = 0
    for o in pecas(objs):
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        total += len(me.loop_triangles)
        ev.to_mesh_clear()
    return total


def exportar(caminho, objs=None):
    """Grava as peças num .glb (aplicando os modificadores), sem cortadores nem referências."""
    os.makedirs(os.path.dirname(os.path.abspath(caminho)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in pecas(objs):
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
    print("exportado", caminho)


# ---------------------------------------------------------------- a textura pintada

class _Nos:
    """Montador de nós de shader (contas de cor e de número), para o material de bake."""

    def __init__(self, arvore):
        self.t = arvore
        self.n = arvore.nodes
        self.l = arvore.links

    def no(self, tipo, **props):
        x = self.n.new(tipo)
        for k, v in props.items():
            setattr(x, k, v)
        return x

    def liga(self, saida, entrada):
        if isinstance(saida, (int, float)):
            entrada.default_value = saida
        elif isinstance(saida, tuple):
            entrada.default_value = saida if len(entrada.default_value) == len(saida) else (*saida, 1.0)[:len(entrada.default_value)]
        else:
            self.l.new(saida, entrada)

    def vet(self, op, a, b=None, escala=None):
        x = self.no("ShaderNodeVectorMath", operation=op)
        self.liga(a, x.inputs[0])
        if b is not None:
            self.liga(b, x.inputs[1])
        if escala is not None:
            self.liga(escala, x.inputs["Scale"])
        return x.outputs[1] if op in ("DOT_PRODUCT", "LENGTH", "DISTANCE") else x.outputs[0]

    def num(self, op, a, b=None, limita=False):
        x = self.no("ShaderNodeMath", operation=op, use_clamp=limita)
        self.liga(a, x.inputs[0])
        if b is not None:
            self.liga(b, x.inputs[1])
        return x.outputs[0]

    def faixa(self, valor, de0, de1, para0=0.0, para1=1.0, suave=True):
        x = self.no("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP" if suave else "LINEAR", clamp=True)
        self.liga(valor, x.inputs["Value"])
        x.inputs["From Min"].default_value = de0
        x.inputs["From Max"].default_value = de1
        x.inputs["To Min"].default_value = para0
        x.inputs["To Max"].default_value = para1
        return x.outputs["Result"]

    def mistura(self, a, b, t):
        """a + (b - a) * t, em cor (vetor)."""
        return self.vet("ADD", a, self.vet("SCALE", self.vet("SUBTRACT", b, a), escala=t))


def assar(ob, png, tam=1024, oclusao=0.55, borda=0.45, degrade=0.25, ferrugem=0.3, sujeira=0.35, amostras=24,
          raio_borda=0.012, dist_oclusao=0.3, cor_ferrugem=(0.20, 0.075, 0.03), cor_sujeira=(0.055, 0.045, 0.03),
          materiais_limpos=("vidro_velho",)):
    """Assa a textura pintada de `ob` (uma malha só, com UV; ver juntar e uv_auto) em `png` e troca os materiais
    por um só, com a textura. A pintura junta, sobre a cor de cada material:
      - `oclusao`: o escuro nas frestas (nó Ambient Occlusion, distância `dist_oclusao` m);
      - `borda`: a borda clara nas arestas, como tinta gasta (nó Bevel de raio `raio_borda` m contra a normal);
      - `degrade`: mais escuro embaixo, mais claro em cima;
      - `ferrugem`: manchas escorridas (ruído esticado na vertical), mais embaixo e nas frestas;
      - `sujeira`: o encardido das frestas.
    Os materiais de `materiais_limpos` e as peças marcadas com `limpo` levam só a oclusão e o degradê. Tudo é
    assado como EMIT no Cycles."""
    sc = cena()
    motor = sc.render.engine
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = amostras
    sc.render.bake.margin = 8
    img = bpy.data.images.new(ob.name + "_pintura", tam, tam, alpha=False)
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    zmin = min(p.z for p in pts)
    zmax = max(p.z for p in pts)
    copias = []
    for i, m in enumerate(list(ob.data.materials)):
        if m is None:
            print("assar: o espaço de material %d de %s está vazio; vai cinza" % (i, ob.name))
            m = material("_sem_material", (0.3, 0.3, 0.3))
        mb = m.copy()
        mb.name = m.name + "_bake"
        ob.data.materials[i] = mb
        copias.append((i, m, mb))
        limpo = m.name in materiais_limpos
        n = _Nos(mb.node_tree)
        for x in list(n.n):
            n.n.remove(x)
        saida = n.no("ShaderNodeOutputMaterial")
        emi = n.no("ShaderNodeEmission")
        n.liga(emi.outputs[0], saida.inputs["Surface"])
        base = cor_de(m)
        geo = n.no("ShaderNodeNewGeometry")
        ao = n.no("ShaderNodeAmbientOcclusion", samples=16)
        ao.inputs["Distance"].default_value = dist_oclusao
        bev = n.no("ShaderNodeBevel", samples=8)
        bev.inputs["Radius"].default_value = raio_borda
        # a aresta: quanto a normal arredondada foge da normal da face
        aresta = n.faixa(n.num("SUBTRACT", 1.0, n.vet("DOT_PRODUCT", bev.outputs[0], geo.outputs["Normal"])),
                         0.01, 0.12)
        z = n.no("ShaderNodeSeparateXYZ")
        n.liga(geo.outputs["Position"], z.inputs[0])
        alto = n.faixa(z.outputs["Z"], zmin, zmax, suave=False)
        fresta = n.num("SUBTRACT", 1.0, ao.outputs["AO"])
        cor = n.vet("SCALE", base, escala=n.num("ADD", 1.0 - oclusao, n.num("MULTIPLY", ao.outputs["AO"], oclusao)))
        cor = n.vet("SCALE", cor, escala=n.faixa(alto, 0.0, 1.0, 1.0 - degrade, 1.0 + degrade * 0.35, suave=False))
        if not limpo:
            # o que juntar marcou como limpo (borracha, plástico) não gasta, não enferruja e não encarde
            marca = n.no("ShaderNodeAttribute", attribute_name="limpo")
            sujo = n.num("SUBTRACT", 1.0, marca.outputs["Fac"], limita=True)
            clara = n.vet("ADD", n.vet("SCALE", cor, escala=1.55), (0.035, 0.032, 0.028))
            cor = n.mistura(cor, clara, n.num("MULTIPLY", n.num("MULTIPLY", aresta, borda), sujo))
            # ferrugem escorrida: ruído esticado na vertical, mais forte embaixo e nas frestas
            esticado = n.no("ShaderNodeMapping")
            n.liga(geo.outputs["Position"], esticado.inputs["Vector"])
            esticado.inputs["Scale"].default_value = (9.0, 9.0, 1.6)
            ruido = n.no("ShaderNodeTexNoise")
            ruido.inputs["Scale"].default_value = 1.0
            ruido.inputs["Detail"].default_value = 6.0
            ruido.inputs["Roughness"].default_value = 0.62
            n.liga(esticado.outputs[0], ruido.inputs["Vector"])
            mancha = n.faixa(ruido.outputs["Fac"], 0.52, 0.68)
            peso = n.num("ADD", n.num("MULTIPLY", n.num("SUBTRACT", 1.0, alto), 0.7), n.num("MULTIPLY", fresta, 1.4))
            cor = n.mistura(cor, cor_ferrugem, n.num("MULTIPLY", n.num("MULTIPLY", mancha, peso, limita=True),
                                                    n.num("MULTIPLY", sujo, ferrugem)))
            cor = n.mistura(cor, cor_sujeira, n.num("MULTIPLY", n.faixa(n.num("MULTIPLY", fresta, sujeira * 2.2), 0.0, 1.0),
                                                   sujo))
        n.liga(cor, emi.inputs["Color"])
        tex = n.no("ShaderNodeTexImage")
        tex.image = img
        tex.select = True
        n.n.active = tex
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.bake(type="EMIT", use_clear=True, margin=8)
    img.filepath_raw = os.path.abspath(png)
    img.file_format = "PNG"
    img.save()
    # o material final: só a textura (o jogo lê a cor dela)
    final = bpy.data.materials.new("pintura_" + ob.name)
    final.use_nodes = True
    p = final.node_tree.nodes["Principled BSDF"]
    t = final.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = img
    final.node_tree.links.new(t.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.85
    ob.data.materials.clear()
    ob.data.materials.append(final)
    for pol in ob.data.polygons:
        pol.material_index = 0
    for _, _, mb in copias:
        bpy.data.materials.remove(mb)
    sc.render.engine = motor
    print("assado", png)
    return final


# ---------------------------------------------------------------- imagens

def ler_png(caminho):
    """Uma imagem como matriz numpy (altura, largura, 4), de cima para baixo."""
    im = bpy.data.images.load(caminho, check_existing=False)
    w, h = im.size
    px = np.array(im.pixels[:], np.float32).reshape(h, w, 4)[::-1].copy()
    bpy.data.images.remove(im)
    return px


def gravar_png(px, caminho):
    h, w = px.shape[:2]
    im = bpy.data.images.new(os.path.basename(caminho), w, h, alpha=True)
    im.pixels[:] = np.ascontiguousarray(px[::-1]).ravel()
    im.filepath_raw = caminho
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    return caminho


def folha(paineis, saida, colunas=2, fundo=(0.09, 0.10, 0.11), titulo=None):
    """Junta os painéis [(legenda, png), ...] numa folha, com a legenda em cima de cada um e um título geral."""
    imgs = [(leg, ler_png(p)) for leg, p in paineis]
    pw = max(i.shape[1] for _, i in imgs)
    ph = max(i.shape[0] for _, i in imgs)
    g, topo, cab = 16, 40, (56 if titulo else 0)
    linhas = (len(imgs) + colunas - 1) // colunas
    W = colunas * pw + (colunas + 1) * g
    H = cab + linhas * (ph + topo) + (linhas + 1) * g
    tela = np.zeros((H, W, 4), np.float32)
    tela[..., :3] = fundo
    tela[..., 3] = 1.0
    posicoes = []
    for k, (leg, im) in enumerate(imgs):
        c, r = k % colunas, k // colunas
        x0 = g + c * (pw + g)
        y0 = cab + g + r * (ph + topo + g) + topo
        tela[y0:y0 + im.shape[0], x0:x0 + im.shape[1]] = im
        posicoes.append((leg, x0, y0))
    gravar_png(tela, saida)
    try:
        import blf
        import imbuf
        fb = blf.load(FONTE) if os.path.exists(FONTE) else 0
        ib = imbuf.load(saida)
        with blf.bind_imbuf(fb, ib):
            blf.color(fb, 0.95, 0.95, 0.92, 1.0)
            if titulo:
                blf.size(fb, 30)
                blf.position(fb, g, H - 42, 0)
                blf.draw_buffer(fb, titulo)
            blf.size(fb, 21)
            for leg, x0, y0 in posicoes:
                blf.position(fb, x0, H - y0 + 12, 0)
                blf.draw_buffer(fb, leg)
        imbuf.write(ib, filepath=saida)
    except Exception as ex:  # sem texto, a folha ainda serve
        print("folha sem legendas:", ex)
    print("folha", saida, W, H)
    return saida


# ---------------------------------------------------------------- estúdio de fotos

class Estudio:
    """Luz, câmera, chão e o robô de 1,2 m para comparar. A luz imita a do jogo: sol quente e sombra azulada."""

    def __init__(self, pasta, largura=1280, altura=800, chao=True):
        self.pasta = pasta
        os.makedirs(pasta, exist_ok=True)
        sc = cena()
        sc.render.engine = "BLENDER_EEVEE"
        sc.render.resolution_x = largura
        sc.render.resolution_y = altura
        sc.render.film_transparent = False
        try:
            sc.view_settings.view_transform = "AgX"
            sc.view_settings.look = "AgX - Medium High Contrast"
            sc.eevee.taa_render_samples = 48
            sc.eevee.use_raytracing = True
        except Exception as ex:
            print("eevee", ex)
        mundo = bpy.data.worlds.new("estudio")
        sc.world = mundo
        mundo.use_nodes = True
        fundo = mundo.node_tree.nodes["Background"]
        fundo.inputs["Color"].default_value = (0.36, 0.42, 0.62, 1.0)
        fundo.inputs["Strength"].default_value = 0.55
        sol = bpy.data.lights.new("sol", "SUN")
        sol.energy = 3.2
        sol.color = (1.0, 0.9, 0.74)
        sol.angle = R(2.0)
        so = bpy.data.objects.new("sol", sol)
        so.rotation_euler = Euler((R(48), 0, R(-35)), "XYZ")
        so["referencia"] = True
        sc.collection.objects.link(so)
        cam_d = bpy.data.cameras.new("cam")
        self.cam = bpy.data.objects.new("cam", cam_d)
        self.cam["referencia"] = True
        sc.collection.objects.link(self.cam)
        sc.camera = self.cam
        self.chao = None
        if chao:
            bm = bmesh.new()
            bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=40.0)
            me = bpy.data.meshes.new("chao")
            bm.to_mesh(me)
            bm.free()
            me.materials.append(material("_chao_estudio", (0.09, 0.13, 0.06), rug=0.95))
            self.chao = bpy.data.objects.new("chao", me)
            self.chao["referencia"] = True
            sc.collection.objects.link(self.chao)
        self._preto = None
        self.robo_objs = []

    def robo(self, pos=(1.0, 0.0, 0.0), virado=0.0):
        """Põe o robô do jogador (assets/vale/robo_v2.glb, 1,2 m) ao lado, para comparar o tamanho."""
        antes = set(bpy.data.objects)
        try:
            bpy.ops.import_scene.gltf(filepath=ROBO)
            novos = [o for o in bpy.data.objects if o not in antes]
            # as chamas dos jatos ficam embaixo dos pés: fora, senão contam na altura e o robô flutua
            for o in [o for o in novos if o.name.startswith("chama")]:
                novos.remove(o)
                bpy.data.objects.remove(o)
        except Exception as ex:
            print("robô de referência não abriu:", ex)
            novos = []
        if not novos:
            corpo = cilindro("_robo", 0.22, 0.75, pos=(0, 0, 0.0), mat=material("_robo", (0.5, 0.55, 0.6)),
                             base=True, chanfro=0.0)
            cabeca = esfera("_robo_cabeca", 0.2, pos=(0, 0, 0.98), mat=material("_robo", (0.5, 0.55, 0.6)))
            novos = [corpo, cabeca]
        raiz = bpy.data.objects.new("_robo_raiz", None)
        cena().collection.objects.link(raiz)
        for o in novos:
            if o.parent is None:
                o.parent = raiz
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for o in novos if o.type == "MESH" for c in o.bound_box]
        if pts:
            zmin = min(p.z for p in pts)
            alt = max(p.z for p in pts) - zmin
            esc = ALTURA_ROBO / max(alt, 0.01)
            raiz.scale = (esc, esc, esc)
            raiz.location = (pos[0], pos[1], pos[2] - zmin * esc)
        raiz.rotation_euler = Euler((0, 0, R(virado)), "XYZ")
        for o in novos + [raiz]:
            o["referencia"] = True
        self.robo_objs = novos + [raiz]
        return raiz

    def mirar(self, loc, alvo, lente=50.0, orto=None):
        self.cam.location = loc
        self.cam.rotation_euler = (Vector(alvo) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        if orto:
            self.cam.data.type = "ORTHO"
            self.cam.data.ortho_scale = orto
        else:
            self.cam.data.type = "PERSP"
            self.cam.data.lens = lente

    def foto(self, nome, loc, alvo, lente=50.0, orto=None):
        self.mirar(loc, alvo, lente, orto)
        caminho = os.path.join(self.pasta, nome + ".png")
        cena().render.filepath = caminho
        bpy.ops.render.render(write_still=True)
        return caminho

    def vistas(self, prefixo, centro, distancia, altura=None, lente=50.0):
        """Frente, lado, costas e 3/4, todas mirando o `centro`: [(legenda, png), ...]."""
        c = Vector(centro)
        h = c.z if altura is None else altura
        lista = [("De frente", (0, -1)), ("De lado (a esquerda dele)", (1, 0)), ("De costas", (0, 1)),
                 ("Em 3/4", (-0.72, -0.72))]
        saida = []
        for k, (leg, (dx, dy)) in enumerate(lista):
            loc = (c.x + dx * distancia, c.y + dy * distancia, h + distancia * 0.18)
            saida.append((leg, self.foto("%s_%d" % (prefixo, k), loc, c, lente)))
        return saida

    def giro(self, prefixo, centro, distancia, n=8, altura=None, lente=50.0):
        """`n` fotos em volta do `centro`, começando de frente."""
        c = Vector(centro)
        h = c.z + distancia * 0.2 if altura is None else altura
        saida = []
        for k in range(n):
            a = -math.pi / 2 + k * 2 * math.pi / n
            loc = (c.x + math.cos(a) * distancia, c.y + math.sin(a) * distancia, h)
            saida.append(("%d°" % round(k * 360 / n), self.foto("%s_g%d" % (prefixo, k), loc, c, lente)))
        return saida

    def silhueta(self, nome, loc, alvo, lente=50.0, orto=None, com_robo=True):
        """A forma em preto num fundo claro, sem luz nem cor (o chão some)."""
        sc = cena()
        if self._preto is None:
            self._preto = bpy.data.materials.new("_silhueta")
            self._preto.use_nodes = True
            nt = self._preto.node_tree
            for x in list(nt.nodes):
                nt.nodes.remove(x)
            em = nt.nodes.new("ShaderNodeEmission")
            em.inputs["Color"].default_value = (0, 0, 0, 1)
            out = nt.nodes.new("ShaderNodeOutputMaterial")
            nt.links.new(em.outputs[0], out.inputs["Surface"])
        escondidos = []
        for o in sc.objects:
            if (o == self.chao or (not com_robo and o in self.robo_objs)) and not o.hide_render:
                o.hide_render = True
                escondidos.append(o)
        sc.view_layers[0].material_override = self._preto
        sc.render.film_transparent = True
        bruta = self.foto(nome + "_bruta", loc, alvo, lente, orto)
        sc.render.film_transparent = False
        sc.view_layers[0].material_override = None
        for o in escondidos:
            o.hide_render = False
        px = ler_png(bruta)
        a = px[..., 3:4]
        claro = np.array((0.93, 0.92, 0.88), np.float32)
        px[..., :3] = claro * (1.0 - a)
        px[..., 3] = 1.0
        caminho = os.path.join(self.pasta, nome + ".png")
        gravar_png(px, caminho)
        return caminho

    def longe(self, png_silhueta, altura_m, distancia=50.0, nome=None):
        """A silhueta do tamanho em que o jogo a mostra a `distancia` m (câmera de 70° numa tela de 1080
        linhas), ampliada de volta em pixels grandes: dá para dizer o que é?"""
        px = ler_png(png_silhueta)
        escuro = px[..., 0] < 0.5
        linhas = np.where(escuro.any(axis=1))[0]
        if len(linhas) == 0:
            return png_silhueta
        alto_px = linhas[-1] - linhas[0] + 1
        alvo = altura_m / (2.0 * distancia * math.tan(R(FOV_JOGO) / 2.0)) * TELA_JOGO
        f = max(1, int(round(alto_px / max(alvo, 1.0))))
        h, w = px.shape[:2]
        h2, w2 = h // f, w // f
        peq = px[:h2 * f, :w2 * f].reshape(h2, f, w2, f, 4).mean(axis=(1, 3))
        grande = np.repeat(np.repeat(peq, f, axis=0), f, axis=1)
        saida = np.ones_like(px)
        saida[..., :3] = 0.93
        saida[:h2 * f, :w2 * f] = grande
        caminho = os.path.join(self.pasta, (nome or os.path.basename(png_silhueta)[:-4] + "_longe") + ".png")
        gravar_png(saida, caminho)
        print("a %d m: %.0f px de altura na tela do jogo" % (distancia, alvo))
        return caminho
