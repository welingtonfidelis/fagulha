# O robô do jogo desde 2026-11-19: o robô de peças redesenhado. Placas de armadura com cantos chanfrados,
# cabeça grande com visor escuro e olhos de tela, luvas e botas grandes, juntas pretas; branco, azul e laranja.
# Mesmos nomes de juntas do robo.py (o robô anterior), então o jogo anima igual; as juntas mudaram de lugar.
# Folha de estudo:  blender -b --factory-startup -P tools/vale/robo_v2.py -- <saida.png> [escala]
# Para o jogo:      EXPORTAR=assets/vale/robo_v2.glb blender -b --factory-startup -P tools/vale/robo_v2.py -- /tmp/x.png
import math
import os
import sys

import blf
import bmesh
import bpy
import imbuf
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SAIDA = os.path.abspath(argv[0])
ESC = float(argv[1]) if len(argv) > 1 else 1.0
PW, PH = int(540 * ESC), int(720 * ESC)
TMP = os.path.join(os.path.dirname(SAIDA), "_paineis")
os.makedirs(TMP, exist_ok=True)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)
scene = bpy.context.scene
col = scene.collection
R = math.radians


# ---------- materiais ----------
def mat_pbr(nome, cor, metal=0.0, rug=0.5):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = cor + (1,)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rug
    return m


def mat_luz(nome, cor, forca):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.02, 0.02, 0.02, 1)
    p.inputs["Emission Color"].default_value = cor + (1,)
    p.inputs["Emission Strength"].default_value = forca
    return m


ESCURA = mat_pbr("velho_escura", (0.075, 0.085, 0.10), 0.2, 0.5)
CLARA = mat_pbr("velho_clara", (0.44, 0.41, 0.34), 0.05, 0.65)
DETALHE = mat_pbr("velho_detalhe", (0.10, 0.30, 0.27), 0.1, 0.55)
TRAJE = mat_pbr("traje", (0.03, 0.032, 0.036), 0.0, 0.85)
SUAVE = False
BOCAL = mat_pbr("bocal", (0.10, 0.08, 0.07), 0.9, 0.3)
CALOR = mat_luz("calor", (1.0, 0.42, 0.10), 2.0)
VISEIRA = mat_luz("viseira", (0.45, 0.85, 0.90), 2.5)
CHAMA = mat_luz("chama", (1.0, 0.50, 0.18), 7.0)
PESSOA = mat_pbr("pessoa", (0.5, 0.5, 0.5), 0.0, 0.9)


# ---------- peças ----------
def atualizar():
    bpy.context.view_layer.update()


def junta(nome, loc, pai=None):
    e = bpy.data.objects.new(nome, None)
    e.empty_display_size = 0.05
    e.location = loc
    col.objects.link(e)
    atualizar()
    if pai is not None:
        e.parent = pai
        e.matrix_parent_inverse = pai.matrix_world.inverted()
    atualizar()
    return e


def prender(ob, pai):
    ob.parent = pai
    ob.matrix_parent_inverse = pai.matrix_world.inverted()


def malha(nome, bm, mat, pai, bevel=0.018, segs=2):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nome, me)
    col.objects.link(ob)
    if bevel:
        md = ob.modifiers.new("bisel", "BEVEL")
        md.width = bevel
        md.segments = segs
        md.limit_method = "ANGLE"
    if SUAVE:
        sb = ob.modifiers.new("sub", "SUBSURF")
        sb.levels = 1
        sb.render_levels = 1
    try:
        me.shade_smooth_by_angle(angle=R(28))
    except Exception:
        pass
    atualizar()
    prender(ob, pai)
    return ob


def caixa(nome, centro, tam, mat, pai, base=(1, 1), topo=(1, 1), rot=(0, 0, 0), bevel=0.018, segs=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        f = topo if v.co.z > 0 else base
        v.co.x *= tam[0] * f[0]
        v.co.y *= tam[1] * f[1]
        v.co.z *= tam[2]
    m = Matrix.Translation(centro) @ Matrix.Rotation(R(rot[2]), 4, "Z") @ Matrix.Rotation(R(rot[1]), 4, "Y") \
        @ Matrix.Rotation(R(rot[0]), 4, "X")
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return malha(nome, bm, mat, pai, bevel, segs)


def cil(nome, centro, r1, r2, comp, mat, pai, rot=(0, 0, 0), segs=16, bevel=0.01):
    bm = bmesh.new()
    m = Matrix.Translation(centro) @ Matrix.Rotation(R(rot[2]), 4, "Z") @ Matrix.Rotation(R(rot[1]), 4, "Y") \
        @ Matrix.Rotation(R(rot[0]), 4, "X")
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=comp, matrix=m)
    return malha(nome, bm, mat, pai, bevel, 1)


# ---------- esqueleto (de frente para -Y; esquerda do robô = +X) ----------
raiz = junta("raiz", (0, 0, 0.42))
tronco = junta("tronco", (0, 0, 0.46), raiz)
cabeca = junta("cabeca", (0, 0, 0.70), tronco)
costas = junta("costas", (0, 0.11, 0.58), tronco)
J = {}
for s, lado in ((1, "E"), (-1, "D")):
    J["ombro" + lado] = junta("ombro" + lado, (s * 0.20, 0, 0.63), tronco)
    J["cotovelo" + lado] = junta("cotovelo" + lado, (s * 0.25, 0, 0.51), J["ombro" + lado])
    # a luva gira em torno do antebraço (o jogo torce 90 graus em descanso e destorce para mirar e atirar)
    J["luva" + lado] = junta("luva" + lado, (s * 0.262, -0.005, 0.50), J["cotovelo" + lado])
    J["punho" + lado] = junta("punho" + lado, (s * 0.265, -0.01, 0.345), J["luva" + lado])
    # os dedos dobram em torno da linha dos nós (o jogo fecha a mão para mirar, atirar e golpear)
    J["dedos" + lado] = junta("dedos" + lado, (s * 0.265, -0.03, 0.295), J["punho" + lado])
    # a ponta do cano da luva: é daqui que o tiro sai
    J["boca" + lado] = junta("boca" + lado, (s * 0.262, -0.092, 0.33), J["luva" + lado])
    J["quadril" + lado] = junta("quadril" + lado, (s * 0.085, 0, 0.40), raiz)
    J["joelho" + lado] = junta("joelho" + lado, (s * 0.095, 0, 0.25), J["quadril" + lado])
    J["tornozelo" + lado] = junta("tornozelo" + lado, (s * 0.10, 0, 0.07), J["joelho" + lado])
    J["pod" + lado] = junta("pod" + lado, (s * 0.08, 0.15, 0.60), costas)
    J["aleta" + lado] = junta("aleta" + lado, (s * 0.10, 0.15, 0.62), costas)
    for i in range(3):
        J["aleta%s%d" % (lado, i)] = junta("aleta%s%d" % (lado, i), (s * 0.10, 0.15, 0.62), J["aleta" + lado])

CHAMAS = []

def casca(*a, **k):
    global SUAVE
    SUAVE = True
    ob = caixa(*a, **k)
    SUAVE = False
    return ob



# VARIANTE=mergulhador faz o robô da Represa (robo_v3.glb): o mesmo corpo em amarelo e verde-petróleo, com
# escotilha redonda no lugar do visor, sem crista nem antena, dois cilindros de ar nas costas e pés de pato.
MERG = os.environ.get("VARIANTE") == "mergulhador"
# VARIANTE=<inimigo> faz um dos inimigos (2026-11-20, ideia do usuário): o nosso robô com outra pintura e outras
# peças, o mesmo esqueleto (o jogo anima igual ao robô do jogador). Cinco comuns e três chefes; sem jatos nem
# abas nas costas (eles não voam). Cores: placa, detalhe, faixas e olhos.
VAR = os.environ.get("VARIANTE", "")
INIMIGOS = {
    "sentinela": ((0.17, 0.18, 0.19), (0.42, 0.05, 0.03), (0.85, 0.42, 0.04), (1.0, 0.16, 0.06)),
    "espadachim": ((0.09, 0.09, 0.11), (0.50, 0.03, 0.09), (0.75, 0.75, 0.72), (1.0, 0.08, 0.22)),
    "couraca": ((0.23, 0.24, 0.15), (0.10, 0.10, 0.09), (0.85, 0.52, 0.04), (1.0, 0.5, 0.08)),
    "batedor": ((0.60, 0.45, 0.05), (0.07, 0.07, 0.08), (0.12, 0.12, 0.12), (1.0, 0.22, 0.08)),
    "artilheiro": ((0.11, 0.19, 0.21), (0.48, 0.18, 0.03), (0.85, 0.42, 0.04), (1.0, 0.32, 0.04)),
    "capataz": ((0.07, 0.07, 0.08), (0.55, 0.36, 0.06), (0.60, 0.05, 0.03), (1.0, 0.12, 0.04)),
    "canhoneiro": ((0.30, 0.09, 0.05), (0.09, 0.09, 0.10), (0.85, 0.62, 0.14), (1.0, 0.45, 0.06)),
    "guardiao": ((0.19, 0.19, 0.23), (0.28, 0.07, 0.42), (0.85, 0.70, 0.28), (0.85, 0.2, 1.0)),
}
CHEFES = ("capataz", "canhoneiro", "guardiao")
INIM = VAR in INIMIGOS
_PAL = INIMIGOS.get(VAR)
BRANCA = mat_pbr("placa_clara", _PAL[0] if INIM else ((0.62, 0.40, 0.03) if MERG else (0.50, 0.51, 0.51)), 0.25 if INIM else 0.0, 0.45)
AZUL = mat_pbr("detalhe", _PAL[1] if INIM else ((0.01, 0.13, 0.15) if MERG else (0.008, 0.07, 0.36)), 0.05, 0.4)
LARANJA = mat_pbr("laranja", _PAL[2] if INIM else ((0.55, 0.56, 0.55) if MERG else (0.9, 0.2, 0.01)), 0.0, 0.45)
JUNTA = mat_pbr("placa_escura", (0.035, 0.04, 0.045), 0.1, 0.6)
VIDRO = mat_pbr("vidro", (0.008, 0.012, 0.02), 0.0, 0.12)
OLHOS = mat_luz("olhos", _PAL[3] if INIM else (0.35, 0.9, 1.0), 2.6 if INIM else 2.2)
LAMINA = mat_luz("lamina", (1.0, 0.22, 0.08) if INIM else (0.1, 0.8, 1.0), 3.0)


def esfera(nome, centro, raios, mat, pai, u=28, v=16):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for vv in bm.verts:
        vv.co.x *= raios[0]
        vv.co.y *= raios[1]
        vv.co.z *= raios[2]
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centro), verts=bm.verts)
    return malha(nome, bm, mat, pai, 0, 1)


# ---- v2: placas de armadura com cantos chanfrados, cabeça grande, luvas e botas grandes, juntas pretas ----
P = dict(bevel=0.022, segs=2)
caixa("pelve", (0, 0, 0.42), (0.16, 0.13, 0.09), JUNTA, raiz, base=(0.7, 0.9), bevel=0.02)
caixa("placa_frente", (0, -0.065, 0.415), (0.075, 0.03, 0.09), BRANCA, raiz, base=(0.6, 1), bevel=0.01)
cil("cintura", (0, 0, 0.475), 0.06, 0.07, 0.04, JUNTA, tronco, segs=10)
caixa("tronco_p", (0, 0, 0.575), (0.27, 0.20, 0.19), BRANCA, tronco, base=(0.66, 0.82), bevel=0.035, segs=2)
caixa("gola", (0, 0.005, 0.677), (0.19, 0.16, 0.028), AZUL, tronco, bevel=0.01)
cil("aro_nucleo", (0, -0.094, 0.585), 0.052, 0.052, 0.03, AZUL, tronco, rot=(90, 0, 0), segs=8, bevel=0.006)
cil("aro_laranja", (0, -0.106, 0.585), 0.04, 0.04, 0.012, LARANJA, tronco, rot=(90, 0, 0), segs=8, bevel=0)
cil("nucleo", (0, -0.112, 0.585), 0.026, 0.026, 0.008, CALOR, tronco, rot=(90, 0, 0), segs=8, bevel=0)
cil("pescoco", (0, 0, 0.705), 0.045, 0.045, 0.04, JUNTA, tronco, segs=10)
caixa("mochila", (0, 0.125, 0.585), (0.19, 0.08, 0.17), BRANCA, costas, base=(0.8, 0.9), bevel=0.025)
caixa("mochila_azul", (0, 0.168, 0.615), (0.11, 0.012, 0.07), AZUL, costas, bevel=0.006)
caixa("radiador", (0, 0.176, 0.615), (0.07, 0.006, 0.04), CALOR, costas, bevel=0)
for s, lado in ((1, "E"), (-1, "D")):
    caixa("estabilizador", (s * 0.07, 0.165, 0.53), (0.055, 0.055, 0.10), BRANCA, costas, base=(1.15, 1.15), rot=(-18, 0, 0), bevel=0.012)
    cil("bocal_estab", (s * 0.07, 0.183, 0.476), 0.026, 0.02, 0.02, BOCAL, costas, rot=(-18, 0, 0), segs=8, bevel=0)
    cil("brasa_estab", (s * 0.07, 0.186, 0.466), 0.017, 0.017, 0.004, CALOR, costas, rot=(-18, 0, 0), segs=8, bevel=0)
    CHAMAS.append(cil("chama_estab", (s * 0.07, 0.204, 0.41), 0.016, 0.0, 0.11, CHAMA, costas, rot=(162, 0, 0), bevel=0, segs=10))
    caixa("aba", (s * 0.108, 0.176, 0.585), (0.05, 0.012, 0.14), AZUL, J["aleta" + lado], base=(0.6, 1), bevel=0.005)
    caixa("ombro_laranja", (s * 0.15, 0, 0.652), (0.05, 0.10, 0.03), LARANJA, tronco, bevel=0.008)
# cabeça: capacete de placas, aberto na frente para o visor escuro com o rosto de tela
CASCO = caixa("cabeca_p", (0, 0.015, 0.93), (0.43, 0.40, 0.39), BRANCA, cabeca, base=(0.8, 0.86), topo=(0.8, 0.84), bevel=0.14, segs=3)
if MERG:
    # a escotilha: um aro de metal em volta de um vidro redondo
    cil("visor", (0, -0.185, 0.925), 0.125, 0.125, 0.05, VIDRO, cabeca, rot=(90, 0, 0), segs=16, bevel=0.006)
    cil("aro_escotilha", (0, -0.175, 0.925), 0.15, 0.15, 0.04, LARANJA, cabeca, rot=(90, 0, 0), segs=16, bevel=0.008)
    for k in range(6):
        ang = k * math.pi / 3.0
        cil("parafuso", (math.cos(ang) * 0.138, -0.198, 0.925 + math.sin(ang) * 0.138), 0.009, 0.009, 0.01, JUNTA, cabeca, rot=(90, 0, 0), segs=6, bevel=0)
else:
    caixa("visor", (0, -0.15, 0.915), (0.33, 0.10, 0.22), VIDRO, cabeca, base=(0.8, 1), bevel=0.045, segs=3)
    caixa("testa", (0, -0.15, 1.05), (0.33, 0.12, 0.04), BRANCA, cabeca, base=(1, 1), topo=(0.86, 0.8), rot=(-10, 0, 0), bevel=0.014)
caixa("queixo", (0, -0.14, 0.785), (0.22, 0.10, 0.04), BRANCA, cabeca, base=(0.75, 0.9), bevel=0.014)
bm = bmesh.new()
_fila = []
for k in range(25):
    ang = R(-42 + k * 5.0)
    y, z = 0.015 + 0.27 * math.sin(ang), 0.93 + 0.27 * math.cos(ang)
    _fila.append((bm.verts.new((-0.038, y, z)), bm.verts.new((0.038, y, z))))
for k in range(24):
    bm.faces.new((_fila[k][0], _fila[k][1], _fila[k + 1][1], _fila[k + 1][0]))
crista = malha("crista", bm, AZUL, cabeca, 0, 1)
md = crista.modifiers.new("cola", "SHRINKWRAP")
md.target = CASCO
md.wrap_method = "NEAREST_SURFACEPOINT"
md.wrap_mode = "ABOVE_SURFACE"
md.offset = 0.009
md = crista.modifiers.new("grossura", "SOLIDIFY")
md.thickness = 0.018
md.offset = 0.0
if MERG:
    bpy.data.objects.remove(crista)
for s in (1, -1):
    # cada olho tem a junta dele, no meio: o jogo achata para piscar e inclina para as expressões
    J["olho" + ("E" if s > 0 else "D")] = junta("olho" + ("E" if s > 0 else "D"), (s * 0.066, -0.2015, 0.925), cabeca)
    if MERG:
        # olhos menores, dentro da escotilha
        J["olho" + ("E" if s > 0 else "D")].location.x = s * 0.048
        J["olho" + ("E" if s > 0 else "D")].location.y = -0.2115
        atualizar()
        caixa("olho", (s * 0.048, -0.2115, 0.93), (0.03, 0.006, 0.065), OLHOS, J["olho" + ("E" if s > 0 else "D")], bevel=0)
    else:
        caixa("olho", (s * 0.066, -0.2015, 0.925), (0.038, 0.006, 0.085), OLHOS, J["olho" + ("E" if s > 0 else "D")], bevel=0)
    caixa("placa_lado", (s * 0.172, -0.03, 0.945), (0.03, 0.16, 0.17), AZUL, cabeca, base=(1, 0.45), rot=(-22, 0, 0), bevel=0.01)
    cil("orelha", (s * 0.175, 0.075, 0.87), 0.045, 0.045, 0.03, JUNTA, cabeca, rot=(0, 90, 0), segs=8, bevel=0.006)
    cil("orelha_luz", (s * 0.192, 0.075, 0.87), 0.022, 0.022, 0.006, LARANJA, cabeca, rot=(0, 90, 0), segs=8, bevel=0)
if MERG:
    # os dois cilindros de ar, por fora da mochila, e a mangueira até o capacete
    for s in (1, -1):
        cil("cilindro_ar", (s * 0.125, 0.16, 0.60), 0.036, 0.036, 0.2, LARANJA, costas, segs=10, bevel=0.012)
        cil("valvula", (s * 0.125, 0.16, 0.715), 0.016, 0.02, 0.03, JUNTA, costas, segs=8, bevel=0)
    caixa("mangueira", (0.09, 0.13, 0.80), (0.025, 0.025, 0.2), JUNTA, costas, rot=(18, 0, 0), bevel=0.008)
else:
    cil("antena", (0.12, 0.10, 1.16), 0.006, 0.004, 0.09, JUNTA, cabeca, segs=6, bevel=0)
    caixa("ponta_antena", (0.12, 0.10, 1.21), (0.02, 0.02, 0.02), LARANJA, cabeca, bevel=0.005)

LAMINAS = []
for s, lado in ((1, "E"), (-1, "D")):
    om, co, pu = J["ombro" + lado], J["luva" + lado], J["punho" + lado]
    luva = []
    qu, jo, to = J["quadril" + lado], J["joelho" + lado], J["tornozelo" + lado]
    caixa("ombro_p", (s * 0.218, 0, 0.642), (0.115, 0.135, 0.105), BRANCA, om, topo=(0.75, 0.8), bevel=0.028, segs=2)
    caixa("ombro_azul", (s * 0.278, 0, 0.635), (0.012, 0.075, 0.055), AZUL, om, bevel=0.004)
    cil("braco", (s * 0.228, 0, 0.57), 0.028, 0.028, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
    # a luva grande: abre para a mão; a placa azul de fora é o bracelete da arma
    luva.append(caixa("antebraco", (s * 0.262, -0.005, 0.43), (0.12, 0.135, 0.17), BRANCA, co, base=(1.22, 1.2), topo=(0.85, 0.85), bevel=0.028, segs=2))
    luva.append(caixa("faixa_luva", (s * 0.258, -0.005, 0.512), (0.085, 0.10, 0.018), LARANJA, co, bevel=0.005))
    luva.append(caixa("bracelete", (s * 0.338, -0.005, 0.41), (0.016, 0.095, 0.11), AZUL, co, base=(1, 0.7), bevel=0.005))
    # o cano da luva: um bloco sobre as costas do antebraço com a boca virada para a mão (com o braço
    # erguido para mirar, fica por cima do punho fechado, apontando para a frente)
    caixa("cano_base", (s * 0.262, -0.086, 0.435), (0.062, 0.034, 0.10), JUNTA, co, topo=(0.8, 1), bevel=0.008)
    cil("cano", (s * 0.262, -0.092, 0.365), 0.022, 0.022, 0.06, BOCAL, co, segs=8, bevel=0.003)
    cil("luz_arma", (s * 0.262, -0.092, 0.3335), 0.014, 0.014, 0.004, OLHOS, co, segs=8, bevel=0)
    luva.append(caixa("mao", (s * 0.265, -0.012, 0.318), (0.10, 0.11, 0.055), JUNTA, pu, bevel=0.018))
    for dx in (-0.032, 0.0, 0.032):
        luva.append(caixa("dedo", (s * 0.265 + dx, -0.03, 0.268), (0.026, 0.05, 0.06), JUNTA, J["dedos" + lado], base=(0.8, 0.7), bevel=0.008))
    luva.append(caixa("polegar", (s * 0.205, -0.03, 0.30), (0.026, 0.045, 0.05), JUNTA, pu, bevel=0.008))
    if s < 0:
        LAMINAS.append(caixa("lamina", (s * 0.265, -0.07, 0.17), (0.012, 0.04, 0.34), LAMINA, pu, base=(1, 0.2), bevel=0))
        luva.append(LAMINAS[-1])
    cil("coxa", (s * 0.09, 0, 0.33), 0.04, 0.036, 0.13, JUNTA, qu, segs=8)
    caixa("placa_coxa", (s * 0.10, -0.03, 0.345), (0.085, 0.04, 0.09), BRANCA, qu, base=(0.8, 1), bevel=0.012)
    caixa("joelho_p", (s * 0.097, -0.062, 0.262), (0.075, 0.04, 0.075), AZUL, jo, topo=(0.65, 1), bevel=0.012)
    caixa("bota", (s * 0.10, 0.0, 0.158), (0.12, 0.145, 0.17), BRANCA, jo, base=(1.25, 1.2), bevel=0.028, segs=2)
    caixa("faixa_bota", (s * 0.10, 0.088, 0.17), (0.06, 0.012, 0.09), LARANJA, jo, bevel=0.004)
    caixa("pe", (s * 0.10, -0.04, 0.05), (0.15, 0.25, 0.07), BRANCA, to, topo=(0.82, 0.66), bevel=0.02)
    caixa("bico", (s * 0.10, -0.15, 0.04), (0.125, 0.05, 0.05), AZUL, to, topo=(0.85, 0.6), bevel=0.012)
    if MERG:
        caixa("pe_de_pato", (s * 0.10, -0.24, 0.022), (0.19, 0.17, 0.02), AZUL, to, base=(1, 1), topo=(1, 1), bevel=0.006)
    caixa("sola", (s * 0.10, -0.04, 0.011), (0.155, 0.255, 0.022), JUNTA, to, bevel=0.004)
    cil("brasa_pe", (s * 0.10, 0.02, 0.0015), 0.038, 0.038, 0.004, CALOR, to, bevel=0, segs=8)
    CHAMAS.append(cil("chama_pe", (s * 0.10, 0.02, -0.15), 0.042, 0.0, 0.30, CHAMA, to, rot=(180, 0, 0), bevel=0, segs=12))

# ---------- os inimigos (VARIANTE=<inimigo>) ----------
def _tirar(*nomes):
    for ob in list(bpy.data.objects):
        if ob.name.split(".")[0] in nomes:
            bpy.data.objects.remove(ob)


def _olhos(forma):
    for lado in "ED":
        for ch in list(J["olho" + lado].children):
            bpy.data.objects.remove(ch)
    for s, lado in ((1, "E"), (-1, "D")):
        jo = J["olho" + lado]
        if forma == "fenda":  # uma fenda só, de lado a lado (metade em cada junta)
            caixa("olho", (s * 0.064, -0.2015, 0.935), (0.128, 0.006, 0.03), OLHOS, jo, bevel=0)
        elif forma == "bravo":  # inclinados para o meio
            caixa("olho", (s * 0.072, -0.2015, 0.93), (0.075, 0.006, 0.034), OLHOS, jo, rot=(0, s * 24, 0), bevel=0)
        elif forma == "pontos":  # dois pontos atrás da grade
            caixa("olho", (s * 0.06, -0.2015, 0.94), (0.042, 0.006, 0.042), OLHOS, jo, bevel=0)
        elif forma == "redondo":
            cil("olho", (s * 0.072, -0.2015, 0.93), 0.05, 0.05, 0.006, OLHOS, jo, rot=(90, 0, 0), segs=18, bevel=0)
        elif forma == "monoculo":
            if s > 0:
                cil("olho", (0.058, -0.2015, 0.935), 0.072, 0.072, 0.006, OLHOS, jo, rot=(90, 0, 0), segs=20, bevel=0)
                cil("aro_monoculo", (0.058, -0.194, 0.935), 0.09, 0.09, 0.016, LARANJA, jo, rot=(90, 0, 0), segs=20, bevel=0.003)
            else:
                caixa("olho", (-0.085, -0.2015, 0.915), (0.05, 0.006, 0.022), OLHOS, jo, bevel=0)
        elif forma == "triplo":  # três luzes em V (o chefe de capa)
            caixa("olho", (s * 0.075, -0.2015, 0.945), (0.05, 0.006, 0.026), OLHOS, jo, rot=(0, s * 18, 0), bevel=0)
            if s > 0:
                caixa("olho", (0.0, -0.2015, 0.9), (0.03, 0.006, 0.03), OLHOS, jo, bevel=0)


def _ombreiras(camadas, mat):
    for s, lado in ((1, "E"), (-1, "D")):
        om = J["ombro" + lado]
        for c in range(camadas):
            caixa("ombreira", (s * (0.24 + c * 0.03), 0, 0.70 - c * 0.05), (0.18 + c * 0.02, 0.2 - c * 0.02, 0.055),
                  mat if c == 0 else BRANCA, om, topo=(0.8, 0.85), rot=(0, -s * (16 + c * 12), 0), bevel=0.016)


def _casulos(n):  # lança-mísseis nas costas, com as pontas aparecendo
    for s, lado in ((1, "E"), (-1, "D")):
        pai = J["pod" + lado]
        caixa("casulo", (s * 0.12, 0.19, 0.67), (0.10, 0.11, 0.15), AZUL, pai, topo=(0.9, 0.9), bevel=0.016)
        for kx in range(n):
            for ky in range(2):
                cil("missil", (s * 0.12 + (kx - (n - 1) * 0.5) * 0.042, 0.19 + (ky - 0.5) * 0.045, 0.755),
                    0.016, 0.003, 0.04, LARANJA, pai, segs=8, bevel=0)


def _canhoes(lados, grosso):
    for s, lado in lados:
        lu = J["luva" + lado]
        cil("canhao", (s * 0.262, -0.105, 0.40), grosso, grosso, 0.2, BOCAL, lu, segs=12, bevel=0.006)
        cil("boca_canhao", (s * 0.262, -0.105, 0.295), grosso * 1.2, grosso * 1.2, 0.03, AZUL, lu, segs=12, bevel=0.004)
        cil("luz_canhao", (s * 0.262, -0.105, 0.279), grosso * 0.6, grosso * 0.6, 0.004, OLHOS, lu, segs=12, bevel=0)


def _emissor(lados):  # a base da lâmina de luz (a lâmina é do jogo)
    for s, lado in lados:
        caixa("emissor", (s * 0.262, -0.09, 0.41), (0.05, 0.035, 0.13), AZUL, J["luva" + lado], topo=(0.8, 1), bevel=0.008)
        caixa("emissor_luz", (s * 0.262, -0.108, 0.36), (0.03, 0.006, 0.05), LAMINA, J["luva" + lado], bevel=0)


if INIM:
    # eles não voam: saem os jatos das costas, as abas e as chamas
    _tirar("estabilizador", "bocal_estab", "brasa_estab", "chama_estab", "aba", "radiador", "mochila_azul", "chama_pe", "brasa_pe",
           "antena", "ponta_antena", "aro_laranja")
    CHAMAS.clear()
    if VAR not in ("espadachim", "guardiao"):
        bpy.data.objects.remove(crista)
    if VAR == "sentinela":
        _olhos("fenda")
        for s in (1, -1):
            cil("antena_lado", (s * 0.19, 0.03, 1.04), 0.008, 0.005, 0.17, JUNTA, cabeca, rot=(0, s * -14, 0), segs=6, bevel=0)
            caixa("ponta_antena", (s * 0.21, 0.03, 1.125), (0.018, 0.018, 0.018), OLHOS, cabeca, bevel=0)
        caixa("faixa_peito", (0, -0.1, 0.6), (0.05, 0.02, 0.15), AZUL, tronco, bevel=0.005)
    elif VAR == "espadachim":
        _olhos("bravo")
        caixa("pluma", (0, 0.07, 1.16), (0.026, 0.30, 0.10), AZUL, cabeca, topo=(1, 0.55), rot=(-14, 0, 0), bevel=0.008)
        _emissor(((-1, "D"),))
        for s, lado in ((1, "E"), (-1, "D")):
            caixa("ombreira", (s * 0.235, 0.02, 0.69), (0.12, 0.2, 0.04), AZUL, J["ombro" + lado], topo=(0.6, 0.9), rot=(-20, -s * 22, 0), bevel=0.012)
    elif VAR == "couraca":
        _olhos("pontos")
        for k in range(5):
            caixa("grade", (-0.12 + k * 0.06, -0.207, 0.915), (0.018, 0.014, 0.21), BRANCA, cabeca, bevel=0.004)
        _ombreiras(1, AZUL)
        for s in (1, -1):
            caixa("peitoral", (s * 0.08, -0.098, 0.6), (0.1, 0.03, 0.15), AZUL, tronco, base=(0.85, 1), bevel=0.01)
        for s, lado in ((1, "E"), (-1, "D")):
            caixa("caneleira", (s * 0.10, -0.085, 0.16), (0.11, 0.03, 0.15), AZUL, J["joelho" + lado], bevel=0.01)
    elif VAR == "batedor":
        _olhos("redondo")
        cil("haste", (0.13, 0.08, 1.17), 0.006, 0.006, 0.14, JUNTA, cabeca, segs=6, bevel=0)
        cil("prato", (0.13, 0.07, 1.25), 0.055, 0.02, 0.025, LARANJA, cabeca, rot=(28, 0, 0), segs=14, bevel=0.003)
        caixa("radio", (0.0, 0.18, 0.62), (0.12, 0.05, 0.12), AZUL, costas, bevel=0.01)
        cil("antena_radio", (0.045, 0.19, 0.8), 0.005, 0.003, 0.26, JUNTA, costas, segs=6, bevel=0)
        for s, lado in ((1, "E"), (-1, "D")):
            caixa("faixa_braco", (s * 0.228, 0, 0.6), (0.05, 0.05, 0.03), AZUL, J["ombro" + lado], bevel=0.004)
    elif VAR == "artilheiro":
        _olhos("monoculo")
        _casulos(2)
        _canhoes(((-1, "D"),), 0.035)
    elif VAR == "capataz":
        _olhos("bravo")
        for s in (1, -1):
            caixa("chifre", (s * 0.22, 0.02, 1.07), (0.06, 0.06, 0.13), LARANJA, cabeca, topo=(0.75, 0.75), rot=(0, s * 35, 0), bevel=0.01)
            caixa("chifre", (s * 0.27, 0.02, 1.17), (0.045, 0.045, 0.11), LARANJA, cabeca, topo=(0.3, 0.3), rot=(0, s * 8, 0), bevel=0.006)
        _ombreiras(2, AZUL)
        _emissor(((1, "E"), (-1, "D")))
        for s in (1, -1):
            caixa("peitoral", (s * 0.08, -0.098, 0.6), (0.1, 0.03, 0.15), AZUL, tronco, base=(0.85, 1), bevel=0.01)
    elif VAR == "canhoneiro":
        _olhos("fenda")
        for dx in (-0.09, 0.0, 0.09):
            caixa("coroa", (dx, -0.06, 1.13), (0.04, 0.035, 0.1 if dx == 0 else 0.075), LARANJA, cabeca, topo=(0.4, 0.6), rot=(-12, 0, 0), bevel=0.006)
        _ombreiras(1, AZUL)
        _casulos(3)
        _canhoes(((1, "E"), (-1, "D")), 0.05)
    elif VAR == "guardiao":
        _olhos("triplo")
        caixa("pluma", (0, 0.12, 1.2), (0.03, 0.42, 0.13), LARANJA, cabeca, topo=(1, 0.5), rot=(-18, 0, 0), bevel=0.008)
        _ombreiras(2, AZUL)
        _emissor(((-1, "D"),))
        for k in (-1, 0, 1):
            caixa("capa", (k * 0.078, 0.2, 0.38), (0.075, 0.02, 0.42), AZUL, costas, base=(1.15, 1), topo=(0.9, 1), rot=(10, 0, k * -5), bevel=0.008)
            caixa("capa_borda", (k * 0.078, 0.212, 0.18), (0.08, 0.02, 0.03), LARANJA, costas, rot=(10, 0, k * -5), bevel=0.004)

# ---- fim do corpo: tools/vale/robo_pecas.py executa este arquivo até esta linha ----
# pessoa de referência (1,75 m), escondida fora do painel de escala
pessoa = bpy.data.objects.new("pessoa_raiz", None)
col.objects.link(pessoa)
PESSOA_OBJS = []
for nome, c, r1, r2, comp in (("perna_e", (1.10, 0, 0.45), 0.075, 0.06, 0.90), ("perna_d", (0.90, 0, 0.45), 0.075, 0.06, 0.90),
                             ("corpo", (1.0, 0, 1.18), 0.15, 0.20, 0.62), ("braco_e", (1.24, 0, 1.12), 0.05, 0.045, 0.62),
                             ("braco_d", (0.76, 0, 1.12), 0.05, 0.045, 0.62)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=r1, radius2=r2, depth=comp, matrix=Matrix.Translation(c))
    PESSOA_OBJS.append(malha(nome, bm, PESSOA, pessoa, 0.02, 2))
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.115, matrix=Matrix.Translation((1.0, 0, 1.63)))
PESSOA_OBJS.append(malha("cabeca_p", bm, PESSOA, pessoa, 0, 1))
PESSOA_OBJS[-1].scale = (1, 1, 1)

# ---------- vitrine dos inimigos (VITRINE=pasta): duas fotos, de pé e golpeando ----------
VITRINE = os.environ.get("VITRINE")

# ---------- exportar para a Godot (EXPORTAR=caminho.glb) ----------
EXPORTAR = os.environ.get("EXPORTAR")
if EXPORTAR:
    bpy.ops.object.select_all(action="DESELECT")
    fora = set(PESSOA_OBJS) | {pessoa} | set(LAMINAS)
    for ob in list(scene.objects):
        if ob not in fora:
            ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=EXPORTAR, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_lights=False, export_cameras=False)
    print("exportado", EXPORTAR)
    os._exit(0)

# ---------- luz e mundo ----------
def luz(nome, tipo, loc, alvo, energia, tam=1.0, cor=(1, 1, 1)):
    d = bpy.data.lights.new(nome, tipo)
    d.energy = energia
    d.color = cor
    if tipo == "AREA":
        d.size = tam
    o = bpy.data.objects.new(nome, d)
    o.location = loc
    o.rotation_euler = (Vector(alvo) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    col.objects.link(o)
    return o


luz("chave", "AREA", (-3.0, -3.5, 3.8), (0, 0, 1.3), 600, 2.5, (1.0, 0.95, 0.88))
luz("preenche", "AREA", (3.5, -2.5, 1.8), (0, 0, 1.3), 260, 3.0, (0.85, 0.9, 1.0))
luz("recorte", "AREA", (0.5, 4.0, 3.5), (0, 0, 1.6), 650, 2.0)
world = bpy.data.worlds.new("estudio")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.16, 0.17, 0.18, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = PW
scene.render.resolution_y = PH
try:
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.eevee.taa_render_samples = 48
    scene.eevee.use_raytracing = True
except Exception as e:
    print("eevee", e)

cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
col.objects.link(cam)
scene.camera = cam


def mirar(loc, alvo, orto=None, lente=50, k=0.5):
    loc = tuple(c * k for c in loc)
    alvo = tuple(c * k for c in alvo)
    if orto:
        orto = orto * k
    cam.location = loc
    cam.rotation_euler = (Vector(alvo) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    if orto:
        cam_d.type = "ORTHO"
        cam_d.ortho_scale = orto
    else:
        cam_d.type = "PERSP"
        cam_d.lens = lente


# ---------- poses ----------
TODAS = [raiz, tronco, cabeca, costas] + list(J.values())


def pose(nome):
    for e in TODAS:
        e.rotation_euler = (0, 0, 0)
    raiz.location = (0, 0, 0.42)
    calor = 2.0
    voando = False
    if nome == "pe":
        for lado in "ED":
            J["cotovelo" + lado].rotation_euler = (R(-12), 0, 0)
    elif nome == "voo":
        voando, calor = True, 9.0
        raiz.rotation_euler = (R(72), 0, 0)
        cabeca.rotation_euler = (R(-55), 0, 0)
        for s, lado in ((1, "E"), (-1, "D")):
            J["ombro" + lado].rotation_euler = (R(18), R(-s * 14), 0)
            J["cotovelo" + lado].rotation_euler = (R(-10), 0, 0)
            J["quadril" + lado].rotation_euler = (R(6), R(-s * 3), 0)
            J["joelho" + lado].rotation_euler = (R(18), 0, 0)
            J["tornozelo" + lado].rotation_euler = (R(40), 0, 0)
            J["aleta" + lado].rotation_euler = (0, 0, R(-s * 55))
    elif nome == "acao":
        tronco.rotation_euler = (0, 0, R(-22))
        cabeca.rotation_euler = (0, 0, R(14))
        J["ombroD"].rotation_euler = (R(-78), 0, R(-12))
        J["dedosD"].rotation_euler = (R(100), 0, 0)
        J["cotoveloD"].rotation_euler = (R(-10), 0, 0)
        J["ombroE"].rotation_euler = (R(22), R(-12), 0)
        J["cotoveloE"].rotation_euler = (R(-35), 0, 0)
        J["quadrilE"].rotation_euler = (R(-18), 0, 0)
        J["joelhoE"].rotation_euler = (R(20), 0, 0)
        J["quadrilD"].rotation_euler = (R(16), 0, 0)
        J["joelhoD"].rotation_euler = (R(14), 0, 0)
    if nome in ("pe", "voo"):
        for s, lado in ((1, "E"), (-1, "D")):
            J["luva" + lado].rotation_euler = (0, 0, R(s * 90))
    for s_, lado in ((1, "E"), (-1, "D")):
        J["pod" + lado].rotation_euler = (R(14), R(s_ * 10), 0)
    CALOR.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = calor
    for ch in CHAMAS:
        ch.hide_render = not voando
    for l in LAMINAS:
        l.hide_render = nome != "acao"
    atualizar()


def mostrar_pessoa(sim):
    for o in PESSOA_OBJS:
        o.hide_render = not sim


PRETO = bpy.data.materials.new("silhueta")
PRETO.use_nodes = True
PRETO.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
PRETO.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
PRETO.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.0


def render(nome):
    caminho = os.path.join(TMP, nome + ".png")
    scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    return caminho


if VITRINE:
    mostrar_pessoa(False)
    pose("pe")
    for l in LAMINAS:
        l.hide_render = True
    mirar((-5.2, -8.4, 2.2), (0, 0, 1.05), lente=60)
    scene.render.filepath = os.path.join(VITRINE, VAR + "_1.png")
    bpy.ops.render.render(write_still=True)
    pose("acao")
    for l in LAMINAS:
        l.hide_render = VAR not in ("espadachim", "capataz", "guardiao")
    mirar((-2.4, -4.0, 1.9), (-0.15, -0.2, 1.2), lente=50)
    scene.render.filepath = os.path.join(VITRINE, VAR + "_2.png")
    bpy.ops.render.render(write_still=True)
    os._exit(0)

PAINEIS = []
mostrar_pessoa(False)
pose("pe")
mirar((0, -10, 1.32), (0, 0, 1.32), orto=3.0)
PAINEIS.append(("Frente", render("frente")))
mirar((10, 0, 1.32), (0, 0, 1.32), orto=3.0)
PAINEIS.append(("Lado", render("lado")))
mirar((0, 10, 1.32), (0, 0, 1.32), orto=3.0)
PAINEIS.append(("Costas", render("costas")))
pose("voo")
mirar((-4.4, -3.0, 2.6), (0, 0.3, 0.95), lente=42)
PAINEIS.append(("Em voo: jatos, estabilizadores e abas", render("voo")))
pose("acao")
mirar((-2.4, -4.0, 1.9), (-0.15, -0.2, 1.2), lente=50)
PAINEIS.append(("Lâmina curta no pulso", render("acao")))
pose("pe")
mostrar_pessoa(True)
scene.view_layers[0].material_override = PRETO
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.82, 0.82, 0.80, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
mirar((0.45, -10, 0.95), (0.45, 0, 0.95), orto=2.2, k=1.0)
scene.view_settings.look = "None"
PAINEIS.append(("Silhueta e escala", render("silhueta")))
scene.view_layers[0].material_override = None

# ---------- folha ----------
G, TOPO = int(16 * ESC), int(46 * ESC)
W = 3 * PW + 4 * G
H = 2 * (PH + TOPO) + 3 * G
img = imbuf.new((W, H))
fb = blf.load("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
fr = blf.load("/System/Library/Fonts/Supplemental/Arial.ttf")
# imbuf não tem "colar"; montamos com numpy a partir dos PNGs via bpy.data.images
import numpy as np

tela = np.zeros((H, W, 4), np.float32)
tela[..., :3] = (0.09, 0.10, 0.11)
tela[..., 3] = 1
for k, (rot, cam_png) in enumerate(PAINEIS):
    im = bpy.data.images.load(cam_png)
    px = np.array(im.pixels[:], np.float32).reshape(PH, PW, 4)
    c, r = k % 3, k // 3
    x0 = G + c * (PW + G)
    y0 = G + (1 - r) * (PH + TOPO + G)  # numpy de baixo para cima (como o Blender)
    tela[y0:y0 + PH, x0:x0 + PW] = px
out = bpy.data.images.new("folha", W, H, alpha=False)
out.pixels[:] = tela.ravel()
out.filepath_raw = SAIDA
out.file_format = "PNG"
out.save()
ib = imbuf.load(SAIDA)
with blf.bind_imbuf(fb, ib), blf.bind_imbuf(fr, ib):
    for k, (rot, _) in enumerate(PAINEIS):
        c, r = k % 3, k // 3
        x0 = G + c * (PW + G)
        ytexto = G + (1 - r) * (PH + TOPO + G) + PH + int(14 * ESC)
        blf.size(fb, int(22 * ESC))
        blf.color(fb, 0.95, 0.95, 0.92, 1)
        blf.position(fb, x0, ytexto, 0)
        blf.draw_buffer(fb, rot)
    # anotações no painel de escala
    x0 = G + 2 * (PW + G)
    y0 = G
    blf.size(fr, int(17 * ESC))
    blf.color(fr, 0.15, 0.15, 0.15, 1)
    for txt, dx in (("robô 1,2 m", 0.22), ("pessoa 1,75 m", 0.62)):
        blf.position(fr, x0 + int(PW * dx), y0 + int(10 * ESC), 0)
        blf.draw_buffer(fr, txt)
imbuf.write(ib, filepath=SAIDA)
print("ok", SAIDA, W, H)
