# Robô pequeno do novo rumo (2026-11-14): 1,2 m, jatos fortes nos pés e fracos nas mãos (as mãos são a arma).
# Mesmas juntas da armadura, então o jogo anima igual.
# blender -b --factory-startup -P tools/vale/robo.py -- <saida.png> [escala]
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


ESCURA = mat_pbr("placa_escura", (0.075, 0.085, 0.10), 0.2, 0.5)
CLARA = mat_pbr("placa_clara", (0.44, 0.41, 0.34), 0.05, 0.65)
DETALHE = mat_pbr("detalhe", (0.10, 0.30, 0.27), 0.1, 0.55)
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
        me.shade_smooth_by_angle(angle=R(35))
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
raiz = junta("raiz", (0, 0, 0.50))
tronco = junta("tronco", (0, 0, 0.56), raiz)
cabeca = junta("cabeca", (0, 0, 0.82), tronco)
costas = junta("costas", (0, 0.12, 0.70), tronco)
J = {}
for s, lado in ((1, "E"), (-1, "D")):
    J["ombro" + lado] = junta("ombro" + lado, (s * 0.205, 0, 0.765), tronco)
    J["cotovelo" + lado] = junta("cotovelo" + lado, (s * 0.245, 0, 0.61), J["ombro" + lado])
    J["punho" + lado] = junta("punho" + lado, (s * 0.255, -0.01, 0.45), J["cotovelo" + lado])
    J["quadril" + lado] = junta("quadril" + lado, (s * 0.09, 0, 0.48), raiz)
    J["joelho" + lado] = junta("joelho" + lado, (s * 0.095, 0, 0.28), J["quadril" + lado])
    J["tornozelo" + lado] = junta("tornozelo" + lado, (s * 0.095, 0, 0.08), J["joelho" + lado])
    # o jogo espera estas juntas (propulsor das costas e aletas da armadura antiga); aqui ficam vazias
    J["pod" + lado] = junta("pod" + lado, (s * 0.08, 0.16, 0.74), costas)
    J["aleta" + lado] = junta("aleta" + lado, (s * 0.10, 0.16, 0.78), costas)
    for i in range(3):
        J["aleta%s%d" % (lado, i)] = junta("aleta%s%d" % (lado, i), (s * 0.10, 0.16, 0.78), J["aleta" + lado])

CHAMAS = []

def casca(*a, **k):
    global SUAVE
    SUAVE = True
    ob = caixa(*a, **k)
    SUAVE = False
    return ob


# ---- robô pequeno (1,2 m): cabeça grande com visor de uma luz só, antebraços e botas largos ----
casca("pelve", (0, 0, 0.50), (0.22, 0.17, 0.12), ESCURA, raiz, base=(0.75, 0.9), bevel=0.03)
casca("tronco_p", (0, 0, 0.68), (0.30, 0.22, 0.26), CLARA, tronco, base=(0.78, 0.9), bevel=0.06, segs=3)
cil("cintura", (0, 0, 0.555), 0.085, 0.10, 0.06, TRAJE, tronco, segs=12)
cil("aro_nucleo", (0, -0.112, 0.70), 0.052, 0.052, 0.03, ESCURA, tronco, rot=(90, 0, 0), segs=16, bevel=0.005)
cil("nucleo", (0, -0.13, 0.70), 0.034, 0.034, 0.012, CALOR, tronco, rot=(90, 0, 0), segs=16, bevel=0)
casca("faixa_peito", (0, -0.105, 0.60), (0.20, 0.03, 0.035), DETALHE, tronco, bevel=0.008)
cil("pescoco", (0, 0, 0.83), 0.055, 0.05, 0.05, TRAJE, tronco, segs=12)
casca("mochila", (0, 0.135, 0.70), (0.19, 0.09, 0.21), ESCURA, costas, base=(0.85, 0.9), bevel=0.03)
caixa("radiador", (0, 0.183, 0.71), (0.11, 0.01, 0.12), CALOR, costas, bevel=0)
for k in range(4):
    caixa("grade", (0, 0.19, 0.665 + k * 0.03), (0.125, 0.012, 0.008), ESCURA, costas, bevel=0)
# cabeça
casca("cabeca_p", (0, 0.0, 1.00), (0.34, 0.31, 0.29), CLARA, cabeca, base=(0.88, 0.92), topo=(0.82, 0.86), bevel=0.11, segs=4)
casca("visor", (0, -0.125, 0.995), (0.25, 0.08, 0.125), ESCURA, cabeca, base=(0.9, 1), bevel=0.035, segs=3)
cil("olho", (0, -0.171, 0.997), 0.034, 0.034, 0.012, VISEIRA, cabeca, rot=(90, 0, 0), segs=16, bevel=0)
casca("orelha_e", (0.178, 0.0, 1.0), (0.03, 0.10, 0.10), DETALHE, cabeca, bevel=0.012)
casca("orelha_d", (-0.178, 0.0, 1.0), (0.03, 0.10, 0.10), DETALHE, cabeca, bevel=0.012)
cil("antena", (0.10, 0.08, 1.20), 0.007, 0.004, 0.14, ESCURA, cabeca, segs=6, bevel=0)
casca("ponta_antena", (0.10, 0.08, 1.275), (0.022, 0.022, 0.022), DETALHE, cabeca, bevel=0.008)

for s, lado in ((1, "E"), (-1, "D")):
    om, co, pu = J["ombro" + lado], J["cotovelo" + lado], J["punho" + lado]
    qu, jo, to = J["quadril" + lado], J["joelho" + lado], J["tornozelo" + lado]
    casca("ombro_p", (s * 0.21, 0, 0.77), (0.105, 0.12, 0.105), ESCURA, om, bevel=0.035, segs=3)
    cil("braco", (s * 0.228, 0, 0.685), 0.034, 0.032, 0.15, TRAJE, om, rot=(0, s * -14, 0), segs=10)
    # antebraço largo, abrindo para a mão (onde fica o jato)
    casca("antebraco", (s * 0.252, -0.005, 0.525), (0.10, 0.11, 0.17), CLARA, co, base=(1.18, 1.18), bevel=0.03, segs=3)
    casca("aro_punho", (s * 0.255, -0.008, 0.452), (0.118, 0.128, 0.03), DETALHE, co, bevel=0.01)
    casca("mao", (s * 0.256, -0.012, 0.405), (0.085, 0.10, 0.075), ESCURA, pu, bevel=0.028, segs=3)
    cil("brasa_mao", (s * 0.256, -0.012, 0.365), 0.027, 0.027, 0.006, CALOR, pu, bevel=0, segs=12)
    ch = cil("chama_panturrilha_mao", (s * 0.256, -0.012, 0.29), 0.026, 0.0, 0.15, CHAMA, pu, rot=(180, 0, 0), bevel=0, segs=10)
    CHAMAS.append(ch)
    cil("coxa", (s * 0.092, 0, 0.38), 0.042, 0.038, 0.20, TRAJE, qu, segs=10)
    casca("joelho_p", (s * 0.095, -0.03, 0.285), (0.075, 0.06, 0.07), DETALHE, jo, bevel=0.02)
    # bota larga, abrindo para o pé (o jato forte)
    casca("bota", (s * 0.095, 0.0, 0.17), (0.115, 0.135, 0.19), CLARA, jo, base=(1.2, 1.22), bevel=0.035, segs=3)
    casca("pe", (s * 0.095, -0.022, 0.04), (0.135, 0.20, 0.075), ESCURA, to, topo=(0.9, 0.8), bevel=0.025, segs=3)
    cil("brasa_pe", (s * 0.095, 0.01, 0.0025), 0.04, 0.04, 0.005, CALOR, to, bevel=0, segs=12)
    ch = cil("chama_pe", (s * 0.095, 0.01, -0.15), 0.042, 0.0, 0.30, CHAMA, to, rot=(180, 0, 0), bevel=0, segs=12)
    CHAMAS.append(ch)

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

# ---------- exportar para a Godot (EXPORTAR=caminho.glb) ----------
EXPORTAR = os.environ.get("EXPORTAR")
if EXPORTAR:
    bpy.ops.object.select_all(action="DESELECT")
    fora = set(PESSOA_OBJS) | {pessoa}
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
    raiz.location = (0, 0, 0.50)
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
    elif nome == "planar":
        calor = 3.5
        raiz.rotation_euler = (R(64), 0, 0)
        cabeca.rotation_euler = (R(-48), 0, 0)
        for s, lado in ((1, "E"), (-1, "D")):
            J["ombro" + lado].rotation_euler = (R(8), R(-s * 42), 0)
            J["cotovelo" + lado].rotation_euler = (R(-8), 0, 0)
            J["quadril" + lado].rotation_euler = (R(4), R(-s * 9), 0)
            J["joelho" + lado].rotation_euler = (R(10), 0, 0)
            J["tornozelo" + lado].rotation_euler = (R(35), 0, 0)
            J["aleta" + lado].rotation_euler = (0, R(-s * 78), 0)
            for i in range(3):
                J["aleta%s%d" % (lado, i)].rotation_euler = (R(i * 10), R(-s * i * 9), 0)
    for s_, lado in ((1, "E"), (-1, "D")):
        J["pod" + lado].rotation_euler = (R(14), R(s_ * 10), 0)
    CALOR.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = calor
    for ch in CHAMAS:
        ch.hide_render = not voando
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
mirar((-4.6, -2.2, 2.4), (0, 0.05, 1.25), lente=40)
PAINEIS.append(("Em voo (motor ligado)", render("voo")))
pose("planar")
mirar((2.2, 3.6, 4.3), (0, 0.2, 1.2), lente=40)
PAINEIS.append(("Planando (aletas abertas)", render("planar")))
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
