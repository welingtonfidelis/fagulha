# As armas que saem do punho (ideia do usuário, 2026-11-23, rascunho 7 aprovado): ao mirar ou atirar, a mão fecha e
# entra no antebraço, e a arma sai pela boca do punho no lugar dela. Pistola de um cano com boca de latão (a de
# sempre; no tiro duplo, uma em cada braço), rajada de seis canos que giram com anéis laranja, precisão de dois
# trilhos com luz amarela e aletas em X que abrem no fim, canhão octogonal de boca larga com placas azuis.
#
# Cada arma é um nó "arma_<nome>_<lado>" no meio da boca do punho, no espaço do modelo (o mesmo do robo_v2.glb):
# o jogo prende o nó na junta da luva e anda com ele ao longo do braço para a arma entrar e sair. Dentro dele:
# "boca_arma" (de onde o tiro sai), "giro" (os canos da rajada) e "aletas" (as da precisão). "vao_<lado>" é a
# boca escura do punho, que aparece quando a mão entra. Os dois ficam na ponta do antebraço de fábrica (z 0,345); o jogo
# os leva até a ponta de cada conjunto (`PUNHO_FIM`, medido por tools/vale/medir_punhos.py).
#
# Para o jogo:  EXPORTAR=assets/vale/armas.glb blender -b --factory-startup -P tools/vale/robo_armas.py -- /tmp/x.png
# Folha de prova (as armas no robô, mirando): blender -b --factory-startup -P tools/vale/robo_armas.py -- <saida.png>
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
_fonte = open(os.path.join(AQUI, "robo_v2.py"), encoding="utf-8").read()
_fonte = _fonte.split("# ---- fim do corpo:")[0]
exec(compile(_fonte, os.path.join(AQUI, "robo_v2.py"), "exec"))  # noqa: S102 (o esqueleto e os materiais)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

FURO = mat_pbr("furo", (0.004, 0.004, 0.005), 0.0, 0.9)
VAO = mat_pbr("vao_punho", (0.012, 0.013, 0.015), 0.0, 0.8)
LATAO = mat_pbr("latao", (0.75, 0.5, 0.14), 0.3, 0.4)
LUZ = mat_luz("luz_precisao", (1.0, 0.82, 0.1), 2.2)
Z0 = 0.345  # a boca do punho (onde a mão encaixa)
YC = -0.012  # o meio da boca do punho
X0 = {"D": -0.265, "E": 0.265}


def no_vazio(nome, loc, pai=None):
    e = bpy.data.objects.new(nome, None)
    e.empty_display_size = 0.02
    e.location = loc
    col.objects.link(e)
    atualizar()
    if pai is not None:
        prender(e, pai)
    return e


def placa(nome, pts, esp, mat, pai, bev=0.002):
    """Uma placa plana com o contorno `pts` (convexo), com a espessura `esp` ao longo da normal dela."""
    pts = [Vector(p) for p in pts]
    n = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized() * (esp * 0.5)
    bm = bmesh.new()
    a = [bm.verts.new(p - n) for p in pts]
    b = [bm.verts.new(p + n) for p in pts]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    k = len(pts)
    for i in range(k):
        j = (i + 1) % k
        bm.faces.new([a[i], a[j], b[j], b[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return malha(nome, bm, mat, pai, bev, 2)


def oito(nome, c, za, zb, r, mat, pai, bev=0.003):
    return cil(nome, (c[0], c[1], (za + zb) * 0.5), r, r, abs(zb - za), mat, pai, rot=(0, 0, 22.5), segs=8, bevel=bev)


def redondo(nome, c, za, zb, r, mat, pai, segs=16, bev=0.002):
    return cil(nome, (c[0], c[1], (za + zb) * 0.5), r, r, abs(zb - za), mat, pai, segs=segs, bevel=bev)


def caixa_z(nome, c, w, h, za, zb, mat, pai, bev=0.01):
    return caixa(nome, (c[0], c[1], (za + zb) * 0.5), (w, h, abs(zb - za)), mat, pai, bevel=bev)


def armar(nome, lado):
    x0 = X0[lado]
    c = (x0, YC)
    no = no_vazio("arma_%s_%s" % (nome, lado), (x0, YC, Z0))
    if nome == "pistola":
        caixa_z("arma_corpo", c, 0.068, 0.074, 0.375, 0.295, JUNTA, no, 0.014)
        redondo("arma_cano", c, 0.295, 0.25, 0.021, JUNTA, no)
        redondo("arma_aro", c, 0.254, 0.243, 0.0235, LATAO, no)
        redondo("arma_furo", c, 0.2435, 0.2415, 0.0135, FURO, no, bev=0)
        caixa_z("arma_mira", (x0, YC - 0.043), 0.013, 0.016, 0.33, 0.302, LARANJA, no, 0.003)
        ponta = 0.242
    elif nome == "rajada":
        redondo("arma_cubo", c, 0.38, 0.325, 0.038, JUNTA, no, segs=20, bev=0.004)
        redondo("arma_anel", c, 0.328, 0.317, 0.041, LARANJA, no, segs=20)
        giro = no_vazio("giro", (x0, YC, Z0), no)  # gira em torno do braço enquanto atira
        redondo("arma_eixo", c, 0.325, 0.212, 0.009, FURO, giro, segs=12, bev=0)
        for k in range(6):
            a = R(30 + 60 * k)
            bc = (x0 + 0.021 * math.cos(a), YC - 0.021 * math.sin(a))
            redondo("arma_cano", bc, 0.325, 0.205, 0.0085, JUNTA, giro, segs=12, bev=0.0015)
            redondo("arma_furo", bc, 0.2058, 0.2038, 0.0055, FURO, giro, segs=12, bev=0)
        redondo("arma_anel2", c, 0.238, 0.226, 0.034, LARANJA, giro, segs=20)
        ponta = 0.204
    elif nome == "precisao":
        caixa_z("arma_base", c, 0.05, 0.05, 0.375, 0.315, JUNTA, no, 0.01)
        for sx in (-1, 1):
            xr = x0 + sx * 0.0135
            caixa_z("arma_trilho", (xr, YC), 0.013, 0.02, 0.33, 0.13, JUNTA, no, 0.003)
            caixa_z("arma_faixa", (xr, YC - 0.0105), 0.006, 0.003, 0.31, 0.15, AZUL, no, 0.0008)
        caixa_z("arma_luz", c, 0.009, 0.008, 0.305, 0.25, LUZ, no, 0.0)
        aletas = no_vazio("aletas", (x0, YC, 0.31), no)  # abrem no fim da saída
        for k in range(4):
            a = R(45 + 90 * k)
            u = Vector((math.cos(a), -math.sin(a), 0))
            o = Vector((x0, YC, 0))
            P = lambda r, z: tuple(o + u * r + Vector((0, 0, z)))  # noqa: E731
            placa("arma_aleta", [P(0.024, 0.272), P(0.024, 0.312), P(0.068, 0.343), P(0.068, 0.322)], 0.006, JUNTA, aletas)
            placa("arma_aleta_ponta", [P(0.068, 0.322), P(0.068, 0.343), P(0.086, 0.355), P(0.086, 0.335)], 0.006,
                  LARANJA, aletas)
        ponta = 0.13
    elif nome == "canhao":
        oito("arma_corpo", c, 0.385, 0.27, 0.05, JUNTA, no, 0.006)
        oito("arma_boca", c, 0.27, 0.235, 0.056, JUNTA, no, 0.005)
        oito("arma_furo", c, 0.2352, 0.2332, 0.034, FURO, no, 0)
        for sx in (-1, 1):
            caixa("arma_placa", (x0 + sx * 0.06, YC - 0.004, 0.338), (0.012, 0.08, 0.07), AZUL, no,
                  rot=(0, -sx * 22, 0), bevel=0.005)
        ponta = 0.234
    no_vazio("boca_arma", (x0, YC, ponta), no)
    return no


RAIZES = [armar("pistola", "D"), armar("pistola", "E"), armar("rajada", "D"), armar("precisao", "D"),
          armar("canhao", "D")]
for lado in "DE":
    v = no_vazio("vao_" + lado, (X0[lado], YC, Z0))
    # a placa fica logo por fora da ponta do antebraço (o jogo a leva até a ponta de cada conjunto)
    caixa("vao", (X0[lado], YC, Z0 - 0.0035), (0.086, 0.096, 0.006), VAO, v, bevel=0.012)
    RAIZES.append(v)


def descendentes(o):
    out = [o]
    for f in o.children:
        out += descendentes(f)
    return out


EXPORTAR = os.environ.get("EXPORTAR")
if EXPORTAR:
    bpy.ops.object.select_all(action="DESELECT")
    for r in RAIZES:
        for o in descendentes(r):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=EXPORTAR, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_lights=False, export_cameras=False)
    print("exportado", EXPORTAR)
    sys.stdout.flush()
    os._exit(0)
sys.stdout.flush()
os._exit(0)
