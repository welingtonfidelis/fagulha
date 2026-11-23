# Peças trocáveis do robô (ideia do usuário, 2026-11-22): cabeça, tronco, braço esquerdo, braço direito, perna
# esquerda e perna direita. Só visuais: o esqueleto é o do robo_v2.py (juntas no mesmo lugar, mesmos comprimentos),
# então o jogo anima igual. Cada conjunto tem forma e cores próprias (o usuário pediu peças bem diferentes umas
# das outras), feito das nossas formas simples; as referências escolhidas por ele só dão o tema (besouro, gato,
# urso...), nada é copiado delas.
#
# O que toda peça mantém, porque o jogo usa:
#   cabeça: o visor e os olhos de tela nas juntas olhoE/olhoD (piscam e fazem as caras);
#   tronco: o núcleo de calor (material "calor", acende com o calor do voo);
#   braço: a mão com os dedos na junta dedos (fecham para mirar e golpear) e o cano na boca da luva (o tiro sai dali);
#   perna: a sola no chão e o jato do pé (brasa_pe e chama_pe ficam os do robo_v2).
# As costas (mochila, jatos, abas, casulos) não trocam.
#
# Folha de prova:  [FOLHA=conjuntos|rabos] [PECAS=besouro,gato,...] blender -b --factory-startup -P tools/vale/robo_pecas.py -- <saida.png> [escala]
# Miniaturas da aba Corpo:  MINIATURAS=assets/vale/corpo/pecas [PECAS=...] blender -b --factory-startup -P tools/vale/robo_pecas.py -- x.png
import math
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
_fonte = open(os.path.join(AQUI, "robo_v2.py"), encoding="utf-8").read()
_fonte = _fonte.split("# ---- fim do corpo:")[0]
exec(compile(_fonte, os.path.join(AQUI, "robo_v2.py"), "exec"))  # noqa: S102 (o esqueleto, os materiais e as peças atuais)

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

LADOS = ((1, "E"), (-1, "D"))
FIXAS = {"pescoco", "cintura", "lamina", "brasa_pe", "chama_pe"}


# ---------- a que peça pertence cada malha do robô atual ----------
def _peca_de(ob):
    if ob.type != "MESH" or ob.parent is None or ob.name.split(".")[0] in FIXAS:
        return None
    p = ob.parent.name.split(".")[0]
    if p in ("cabeca", "olhoE", "olhoD"):
        return "cabeca"
    if p in ("tronco", "raiz"):
        return "tronco"
    for lado in "ED":
        if p in ("ombro" + lado, "cotovelo" + lado, "luva" + lado, "punho" + lado, "dedos" + lado, "boca" + lado):
            return "braco" + lado
        if p in ("quadril" + lado, "joelho" + lado, "tornozelo" + lado):
            return "perna" + lado
    return None


ATUAIS = {}
for _ob in list(bpy.data.objects):
    _p = _peca_de(_ob)
    if _p:
        ATUAIS.setdefault(_p, []).append(_ob)


# ---------- formas que faltavam ----------
def tubo(nome, pts, raios, mat, pai, segs=10, bevel=0):
    """Um tubo que afina pelos pontos (chifres, garras, orelhas, rabo). Fecha a ponta se o último raio for ~0."""
    bm = bmesh.new()
    pts = [Vector(p) for p in pts]
    aneis = []
    for i, (p, r) in enumerate(zip(pts, raios)):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = Vector((1, 0, 0)) if abs(t.x) < 0.9 else Vector((0, 1, 0))
        n1 = t.cross(a).normalized()
        n2 = t.cross(n1).normalized()
        if r < 0.0015:
            aneis.append([bm.verts.new(p)])
            continue
        aneis.append([bm.verts.new(p + (n1 * math.cos(k * 2 * math.pi / segs) + n2 * math.sin(k * 2 * math.pi / segs)) * r)
                      for k in range(segs)])
    for a, b in zip(aneis, aneis[1:]):
        if len(b) == 1:
            for k in range(segs):
                bm.faces.new((a[k], a[(k + 1) % segs], b[0]))
        else:
            for k in range(segs):
                bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    if len(aneis[0]) > 1:
        bm.faces.new(list(reversed(aneis[0])))
    if len(aneis[-1]) > 1:
        bm.faces.new(aneis[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return malha(nome, bm, mat, pai, bevel, 1)


def arco(p0, p1, curva, n=6):
    """Pontos de p0 a p1 envergados `curva` para cima/frente (um vetor somado no meio)."""
    p0, p1, c = Vector(p0), Vector(p1), Vector(curva)
    return [p0.lerp(p1, i / (n - 1)) + c * (4 * (i / (n - 1)) * (1 - i / (n - 1))) for i in range(n)]




def sobre_elipse(dx, centro, raios, angulos, folga=0.004):
    """Pontos sobre a superfície de um elipsoide (para listras e costuras que acompanham a cabeça)."""
    cx, cy, cz = centro
    rx, ry, rz = raios
    f = math.sqrt(max(0.0, 1.0 - (dx / rx) ** 2))
    return [(cx + dx, cy + (ry * f + folga) * math.sin(a), cz + (rz * f + folga) * math.cos(a)) for a in angulos]


# ---------- pedaços que toda peça repete (o jogo depende deles) ----------
_CORES = {}


def cor(nome, rgb, metal=0.1, rug=0.5):
    """A cor própria de um conjunto. O nome começa com o da família (placa_, detalhe_, laranja_) para o jogo
    tratar igual às cores do robô."""
    if nome not in _CORES:
        _CORES[nome] = mat_pbr(nome, rgb, metal, rug)
    return _CORES[nome]


def casco(mat=None, tam=(0.43, 0.40, 0.39)):
    """O capacete do robô atual, para os conjuntos que mantêm a cabeça quadrada."""
    return caixa("cabeca_p", (0, 0.015, 0.93), tam, mat or BRANCA, cabeca, base=(0.8, 0.86), topo=(0.8, 0.84), bevel=0.14, segs=3)


def rosto(visor="padrao", olhos="padrao"):
    """O visor escuro e os olhos de tela. A frente do visor fica sempre em y -0,20, onde estão as juntas
    olhoE/olhoD (o jogo achata os olhos para piscar e os inclina para as caras)."""
    if visor == "padrao":
        caixa("visor", (0, -0.15, 0.915), (0.33, 0.10, 0.22), VIDRO, cabeca, base=(0.8, 1), bevel=0.045, segs=3)
    elif visor == "faixa":  # uma faixa larga e baixa
        caixa("visor", (0, -0.15, 0.925), (0.38, 0.10, 0.15), VIDRO, cabeca, bevel=0.04, segs=3)
    elif visor == "redondo":  # tela de cantos bem redondos
        caixa("visor", (0, -0.15, 0.92), (0.31, 0.10, 0.2), VIDRO, cabeca, bevel=0.07, segs=4)
    elif visor == "pequeno":
        caixa("visor", (0, -0.15, 0.94), (0.27, 0.10, 0.15), VIDRO, cabeca, bevel=0.04, segs=3)
    for s, lado in LADOS:
        jo = J["olho" + lado]
        if olhos == "redondo":
            cil("olho", (s * 0.068, -0.2015, 0.925), 0.043, 0.043, 0.006, OLHOS, jo, rot=(90, 0, 0), segs=18, bevel=0)
        elif olhos == "baixo":  # mais largos que altos, de pálpebra baixa
            caixa("olho", (s * 0.07, -0.2015, 0.925), (0.062, 0.006, 0.046), OLHOS, jo, bevel=0)
        else:
            caixa("olho", (s * 0.066, -0.2015, 0.925), (0.038, 0.006, 0.085), OLHOS, jo, bevel=0)


def nucleo(y=-0.094, z=0.585, aro=None, anel=None):
    cil("aro_nucleo", (0, y, z), 0.052, 0.052, 0.03, aro or AZUL, tronco, rot=(90, 0, 0), segs=8, bevel=0.006)
    cil("aro_laranja", (0, y - 0.012, z), 0.04, 0.04, 0.012, anel or LARANJA, tronco, rot=(90, 0, 0), segs=8, bevel=0)
    cil("nucleo", (0, y - 0.018, z), 0.026, 0.026, 0.008, CALOR, tronco, rot=(90, 0, 0), segs=8, bevel=0)


def pelve(placa=None):
    caixa("pelve", (0, 0, 0.42), (0.16, 0.13, 0.09), JUNTA, raiz, base=(0.7, 0.9), bevel=0.02)
    caixa("placa_frente", (0, -0.065, 0.415), (0.075, 0.03, 0.09), placa or BRANCA, raiz, base=(0.6, 1), bevel=0.01)


def cano(s, lado, base=None):
    lu = J["luva" + lado]
    caixa("cano_base", (s * 0.262, -0.086, 0.435), (0.062, 0.034, 0.10), base or JUNTA, lu, topo=(0.8, 1), bevel=0.008)
    cil("cano", (s * 0.262, -0.092, 0.365), 0.022, 0.022, 0.06, BOCAL, lu, segs=8, bevel=0.003)
    cil("luz_arma", (s * 0.262, -0.092, 0.3335), 0.014, 0.014, 0.004, OLHOS, lu, segs=8, bevel=0)


def rotativo(s, lado, mat):
    """Três canos finos em volta da boca da luva (o tiro continua saindo do meio)."""
    lu = J["luva" + lado]
    cx, cy = s * 0.262, -0.092
    cil("cano_base", (cx, cy + 0.004, 0.43), 0.036, 0.036, 0.09, mat, lu, segs=12, bevel=0.006)
    cil("cano_aro", (cx, cy, 0.383), 0.038, 0.038, 0.012, JUNTA, lu, segs=12, bevel=0.003)
    for k in range(3):
        a = k * 2 * math.pi / 3 + math.pi / 2
        x, y = cx + math.cos(a) * 0.019, cy + math.sin(a) * 0.019
        cil("cano", (x, y, 0.357), 0.01, 0.01, 0.05, BOCAL, lu, segs=8, bevel=0.002)
        cil("luz_arma", (x, y, 0.3315), 0.006, 0.006, 0.003, OLHOS, lu, segs=8, bevel=0)


def mao(s, lado, estilo="padrao", mat=None, unha=None):
    """A mão: palma no punho, três dedos na junta dedos (o jogo fecha) e o polegar."""
    pu, de = J["punho" + lado], J["dedos" + lado]
    x = s * 0.265
    mat = mat or JUNTA
    if estilo == "pata":  # patinha: palma redonda, dedos redondos e unhas curtinhas
        esfera("mao", (x, -0.015, 0.315), (0.056, 0.06, 0.036), mat, pu, u=16, v=10)
        for dx in (-0.033, 0.0, 0.033):
            esfera("dedo", (x + dx, -0.03, 0.276), (0.02, 0.025, 0.026), mat, de, u=12, v=8)
            esfera("unha", (x + dx, -0.052, 0.266), (0.008, 0.009, 0.009), unha or JUNTA, de, u=8, v=6)
        esfera("polegar", (s * 0.213, -0.03, 0.302), (0.019, 0.023, 0.024), mat, pu, u=12, v=8)
    elif estilo == "pata_grande":  # pata de felino grande: palma larga, quatro dedos redondos e unhas curtinhas
        esfera("mao", (x, -0.015, 0.315), (0.066, 0.068, 0.042), mat, pu, u=18, v=10)
        for dx in (-0.039, -0.013, 0.013, 0.039):
            esfera("dedo", (x + dx, -0.032, 0.272), (0.018, 0.025, 0.027), mat, de, u=12, v=8)
            esfera("unha", (x + dx, -0.055, 0.262), (0.008, 0.009, 0.009), unha or JUNTA, de, u=8, v=6)
        esfera("polegar", (s * 0.205, -0.03, 0.302), (0.02, 0.025, 0.026), mat, pu, u=12, v=8)
    elif estilo == "pata_urso":  # mãozona de dedos grossos e unhas curtas e rombudas
        casca("mao", (x, -0.012, 0.315), (0.12, 0.125, 0.065), mat, pu, bevel=0.02)
        for dx in (-0.038, 0.0, 0.038):
            casca("dedo", (x + dx, -0.03, 0.27), (0.036, 0.056, 0.058), mat, de, bevel=0.012)
            cil("unha", (x + dx, -0.062, 0.25), 0.011, 0.007, 0.026, unha or JUNTA, de, rot=(150, 0, 0), segs=8, bevel=0)
        casca("polegar", (s * 0.196, -0.03, 0.298), (0.034, 0.05, 0.055), mat, pu, bevel=0.012)
    elif estilo == "punho":
        caixa("mao", (x, -0.012, 0.316), (0.115, 0.125, 0.062), mat, pu, bevel=0.02)
        for dx in (-0.037, 0.0, 0.037):
            caixa("dedo", (x + dx, -0.03, 0.262), (0.033, 0.058, 0.066), mat, de, base=(0.85, 0.75), bevel=0.01)
        caixa("polegar", (s * 0.198, -0.03, 0.298), (0.032, 0.05, 0.055), mat, pu, bevel=0.01)
    else:
        caixa("mao", (x, -0.012, 0.318), (0.10, 0.11, 0.055), mat, pu, bevel=0.018)
        for dx in (-0.032, 0.0, 0.032):
            caixa("dedo", (x + dx, -0.03, 0.268), (0.026, 0.05, 0.06), mat, de, base=(0.8, 0.7), bevel=0.008)
        caixa("polegar", (s * 0.205, -0.03, 0.30), (0.026, 0.045, 0.05), mat, pu, bevel=0.008)


def coxa(s, lado, r=0.04, mat=None, placa=None):
    qu = J["quadril" + lado]
    cil("coxa", (s * 0.09, 0, 0.33), r, r * 0.9, 0.13, mat or JUNTA, qu, segs=10)
    if placa:
        caixa("placa_coxa", (s * 0.10, -0.03, 0.345), (0.085, 0.04, 0.09), placa, qu, base=(0.8, 1), bevel=0.012)


def sola(s, lado, larg=0.155, comp=0.255, y=-0.04):
    caixa("sola", (s * 0.10, y, 0.011), (larg, comp, 0.022), JUNTA, J["tornozelo" + lado], bevel=0.004)


RABO = []  # juntas do rabo do conjunto montado, da raiz para a ponta
RABO_PTS = []


def cauda(pts, raios, mat, listra=None, ponta=None, ponta_mat=None):
    """Rabo em gomos, cada um na sua junta (rabo0 presa na raiz, rabo1 filha da rabo0...), para o jogo
    balançar parado e esticar para trás correndo e voando. Uma bola em cada dobra esconde a emenda."""
    pai = raiz
    RABO_PTS[:] = [Vector(p) for p in pts]
    for i in range(len(pts) - 1):
        j = junta("rabo%d" % i, pts[i], pai)
        RABO.append(j)
        tubo("rabo", [pts[i], pts[i + 1]], (raios[i], raios[i + 1]), mat, j, segs=10)
        if i > 0:
            esfera("dobra_rabo", pts[i], (raios[i],) * 3, mat, j, u=12, v=8)
        if listra and i % 2 == 1:
            meio = (Vector(pts[i]) + Vector(pts[i + 1])) / 2
            d = (Vector(pts[i + 1]) - Vector(pts[i])).normalized()
            rq = d.to_track_quat("Z", "Y").to_euler()
            r = (raios[i] + raios[i + 1]) / 2 + 0.002
            cil("listra_rabo", tuple(meio), r, r, 0.016, listra, j, rot=tuple(math.degrees(a) for a in rq), segs=10, bevel=0)
        pai = j
    if ponta:
        esfera("ponta_rabo", pts[-1], ponta, ponta_mat or mat, pai, u=12, v=8)
    # a ponta do rabo: o jogo mede o último gomo por ela
    junta("rabo_ponta", pts[-1], pai)


def faldas(mat, borda=None, alt=0.09, z=0.385):
    """Placas penduradas na cintura: frente, trás e lados, fora do caminho das pernas (elas balançam em x ±0,09)."""
    for nome, c, tam, rot in (("falda", (0, -0.082, z), (0.085, 0.016, alt), (-12, 0, 0)),
                              ("falda", (0, 0.082, z), (0.085, 0.016, alt), (12, 0, 0)),
                              ("falda", (0.152, 0, z), (0.016, 0.1, alt), (0, -12, 0)),
                              ("falda", (-0.152, 0, z), (0.016, 0.1, alt), (0, 12, 0))):
        caixa(nome, c, tam, mat, raiz, base=(1.15, 1.15), rot=rot, bevel=0.005)
        if borda:
            cb = (c[0] * 1.06, c[1] * 1.06, z - alt / 2 + 0.008)
            caixa("falda_borda", cb, (tam[0] * 1.2 + 0.004, tam[1] * 1.2 + 0.004, 0.014), borda, raiz, rot=rot, bevel=0.003)


def coracao(centro, tam, mat, pai):
    """Um coração de frente (virado para -y)."""
    x, y, z = centro
    for s in (1, -1):
        esfera("coracao", (x + s * tam * 0.26, y, z + tam * 0.12), (tam * 0.3, tam * 0.12, tam * 0.3), mat, pai, u=12, v=8)
    caixa("coracao", (x, y, z - tam * 0.14), (tam * 0.46, tam * 0.2, tam * 0.46), mat, pai, rot=(0, 45, 0), bevel=0.002)


# =====================================================================================================
# Os conjuntos. Cada um tem cabeca(), tronco_(), braco(s, lado) e perna(s, lado), e cores próprias.
# =====================================================================================================

class Besouro:
    """Besouro: cabeça redonda com carapaça verde e costura, chifre grande de ponta dupla, mandíbulas douradas
    em volta do visor; peito de placas verdes e anéis dourados na barriga; ombreiras de casco com esporão;
    antebraço redondo com canhão de três canos; canelas redondas e pés de três dedos."""
    nome = "Besouro"

    @staticmethod
    def cores():
        return cor("detalhe_besouro", (0.03, 0.17, 0.10), 0.3, 0.35), cor("laranja_besouro", (0.80, 0.52, 0.10), 0.35, 0.35)

    @staticmethod
    def cabeca():
        V, O = Besouro.cores()
        # capacete chanfrado todo verde (redondo, com tampa ou frisos, parecia cebola e melancia)
        casco(V, (0.44, 0.41, 0.39))
        caixa("costura", (0, 0.03, 1.127), (0.014, 0.3, 0.012), JUNTA, cabeca, bevel=0.003)
        caixa("testa", (0, -0.148, 1.05), (0.34, 0.12, 0.045), O, cabeca, topo=(0.86, 0.8), rot=(-10, 0, 0), bevel=0.014)
        for s in (1, -1):
            caixa("placa_lado", (s * 0.176, -0.02, 0.94), (0.03, 0.2, 0.17), O, cabeca, base=(1, 0.55), rot=(-18, 0, 0), bevel=0.01)
        rosto("faixa")
        cil("anel_chifre", (0, -0.135, 1.065), 0.05, 0.056, 0.03, O, cabeca, rot=(-28, 0, 0), segs=14, bevel=0.004)
        tubo("chifre", [(0, -0.13, 1.06), (0, -0.165, 1.12), (0, -0.17, 1.2), (0, -0.14, 1.27), (0, -0.085, 1.315), (0, -0.03, 1.335)],
             (0.064, 0.056, 0.046, 0.036, 0.027, 0.02), V, cabeca, segs=12)
        for s in (1, -1):
            tubo("ponta_chifre", [(0, -0.035, 1.334), (s * 0.028, -0.005, 1.35), (s * 0.045, 0.02, 1.375)], (0.02, 0.016, 0.011), O, cabeca, segs=8)
            tubo("mandibula", arco((s * 0.175, -0.10, 0.865), (s * 0.075, -0.215, 0.81), (s * 0.02, -0.02, -0.012), 5),
                 (0.026, 0.023, 0.019, 0.014, 0.009), O, cabeca, segs=8)

    @staticmethod
    def tronco_():
        V, O = Besouro.cores()
        pelve(O)
        esfera("tronco_p", (0, 0, 0.585), (0.145, 0.105, 0.105), BRANCA, tronco)
        for s in (1, -1):
            casca("peitoral", (s * 0.062, -0.072, 0.618), (0.11, 0.05, 0.085), V, tronco, rot=(0, 0, s * -12), bevel=0.02)
        nucleo(y=-0.098, z=0.548, aro=O, anel=V)
        for k, z in enumerate((0.5, 0.478)):
            cil("anel", (0, 0, z), 0.088 - k * 0.008, 0.09 - k * 0.008, 0.018, O, tronco, segs=16, bevel=0.003)
        cil("gola", (0, 0.005, 0.682), 0.1, 0.11, 0.026, V, tronco, segs=14, bevel=0.005)

    @staticmethod
    def braco(s, lado):
        V, O = Besouro.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        esfera("ombro_p", (s * 0.232, 0, 0.66), (0.088, 0.094, 0.072), V, om)
        esfera("ombro_baixo", (s * 0.226, 0, 0.628), (0.07, 0.078, 0.05), BRANCA, om)
        tubo("esporao", arco((s * 0.25, 0.0, 0.715), (s * 0.31, 0.02, 0.79), (s * -0.01, 0, 0.01), 4), (0.026, 0.02, 0.014, 0.008), O, om, segs=8)
        cil("braco", (s * 0.228, 0, 0.57), 0.028, 0.028, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        cil("antebraco", (s * 0.262, -0.005, 0.43), 0.066, 0.06, 0.17, BRANCA, lu, segs=16, bevel=0.012)
        for z in (0.5, 0.37):
            cil("faixa_luva", (s * 0.262, -0.005, z), 0.07, 0.07, 0.018, O, lu, segs=16, bevel=0.003)
        rotativo(s, lado, V)
        mao(s, lado)

    @staticmethod
    def perna(s, lado):
        V, O = Besouro.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.042)
        esfera("joelho_p", (s * 0.097, -0.035, 0.258), (0.058, 0.055, 0.05), V, jo)
        cil("bota", (s * 0.10, 0, 0.155), 0.078, 0.064, 0.17, BRANCA, jo, segs=16, bevel=0.015)
        cil("faixa_bota", (s * 0.10, 0, 0.2), 0.071, 0.071, 0.016, O, jo, segs=16, bevel=0.003)
        caixa("pe", (s * 0.10, -0.02, 0.045), (0.14, 0.2, 0.06), V, to, topo=(0.8, 0.75), bevel=0.02)
        for dx in (-0.045, 0.0, 0.045):
            tubo("dedo_pe", arco((s * 0.10 + dx, -0.1, 0.038), (s * 0.10 + dx * 1.2, -0.168, 0.018), (0, 0, 0.01), 4),
                 (0.026, 0.024, 0.021, 0.018), O, to, segs=10)
        tubo("calcanhar", arco((s * 0.10, 0.06, 0.04), (s * 0.10, 0.12, 0.016), (0, 0, 0.008), 3), (0.022, 0.016, 0.01), O, to, segs=8)
        sola(s, lado, larg=0.14, comp=0.2, y=-0.02)


class Gato:
    """Gato: cabeça larga e redonda com bochechas, focinho com nariz e bigodes, orelhas cor de gengibre e listras
    na testa, tela redonda com olhos redondos; tronco fino de cintura marcada, coleira com guizo e rabo listrado;
    braços finos de ombro redondo e luvas de patinha; canelas finas e pés de pata."""
    nome = "Gato"

    @staticmethod
    def cores():
        return cor("detalhe_gato", (0.92, 0.27, 0.02), 0.05, 0.5), cor("placa_gato", (0.92, 0.76, 0.52), 0.05, 0.55)

    @staticmethod
    def cabeca():
        G, C = Gato.cores()
        CAB = ((0, 0.015, 0.93), (0.225, 0.2, 0.19))
        esfera("cabeca_p", CAB[0], CAB[1], BRANCA, cabeca)
        rosto("redondo", "redondo")
        esfera("focinho", (0, -0.13, 0.805), (0.085, 0.07, 0.05), C, cabeca, u=18, v=10)
        caixa("nariz", (0, -0.196, 0.825), (0.036, 0.018, 0.022), G, cabeca, base=(0.45, 1), bevel=0.006)
        for s in (1, -1):
            esfera("bochecha", (s * 0.16, -0.06, 0.845), (0.075, 0.075, 0.065), BRANCA, cabeca, u=18, v=10)
            caixa("orelha_gato", (s * 0.125, 0.02, 1.13), (0.14, 0.06, 0.19), G, cabeca, topo=(0.1, 0.42), rot=(-6, s * 18, 0), bevel=0.02)
            caixa("orelha_dentro", (s * 0.123, -0.014, 1.12), (0.085, 0.012, 0.125), C, cabeca, topo=(0.1, 0.8), rot=(-6, s * 18, 0), bevel=0.004)
            for k in range(3):
                tubo("bigode", [(s * 0.075, -0.18, 0.80 + k * 0.016), (s * 0.21, -0.16, 0.79 + k * 0.028)], (0.0045, 0.003), JUNTA, cabeca, segs=5)
        for dx in (-0.05, 0.0, 0.05):
            tubo("listra", sobre_elipse(dx, *CAB, [-0.78 + k * 0.12 for k in range(5)], 0.002), [0.013] * 5, G, cabeca, segs=6)

    @staticmethod
    def tronco_():
        G, C = Gato.cores()
        pelve(C)
        casca("tronco_p", (0, 0, 0.575), (0.24, 0.19, 0.19), BRANCA, tronco, base=(0.62, 0.8), bevel=0.04)
        esfera("peito", (0, -0.07, 0.61), (0.075, 0.04, 0.06), C, tronco, u=16, v=10)
        nucleo(y=-0.08, z=0.545, aro=G, anel=C)
        cil("coleira", (0, 0, 0.678), 0.098, 0.098, 0.026, G, tronco, segs=16, bevel=0.005)
        esfera("guizo", (0, -0.104, 0.655), (0.024, 0.024, 0.024), cor("laranja_ouro", (0.85, 0.62, 0.12), 0.4, 0.35), tronco, u=12, v=8)
        cauda([(0, 0.06, 0.43), (0, 0.15, 0.39), (0.02, 0.24, 0.37), (0.06, 0.31, 0.4), (0.1, 0.34, 0.47), (0.13, 0.33, 0.54)],
              (0.025, 0.023, 0.021, 0.02, 0.019, 0.017), BRANCA, listra=G, ponta=(0.025, 0.025, 0.03), ponta_mat=G)

    @staticmethod
    def braco(s, lado):
        G, C = Gato.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        esfera("ombro_p", (s * 0.222, 0, 0.648), (0.068, 0.07, 0.06), BRANCA, om, u=20, v=12)
        cil("ombro_listra", (s * 0.222, 0, 0.67), 0.058, 0.04, 0.016, G, om, segs=14, bevel=0.003)
        cil("braco", (s * 0.228, 0, 0.57), 0.024, 0.024, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        casca("antebraco", (s * 0.262, -0.005, 0.44), (0.1, 0.11, 0.15), BRANCA, lu, topo=(0.85, 0.85), bevel=0.03)
        for z in (0.47, 0.425):
            caixa("listra_luva", (s * 0.262, -0.005, z), (0.096, 0.106, 0.014), G, lu, bevel=0.004)
        cano(s, lado, G)
        mao(s, lado, "pata", mat=C, unha=G)

    @staticmethod
    def perna(s, lado):
        G, C = Gato.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.034)
        esfera("joelho_p", (s * 0.097, -0.045, 0.257), (0.038, 0.034, 0.038), G, jo, u=14, v=10)
        casca("bota", (s * 0.10, 0.0, 0.16), (0.1, 0.12, 0.16), BRANCA, jo, base=(1.15, 1.08), bevel=0.03)
        caixa("listra_bota", (s * 0.10, 0.0, 0.19), (0.098, 0.118, 0.014), G, jo, bevel=0.004)
        casca("pe", (s * 0.10, -0.035, 0.05), (0.15, 0.22, 0.08), BRANCA, to, topo=(0.8, 0.7), bevel=0.02)
        for dx in (-0.042, 0.0, 0.042):
            esfera("dedo_pe", (s * 0.10 + dx, -0.145, 0.034), (0.026, 0.032, 0.03), C, to, u=12, v=8)
        sola(s, lado, comp=0.23, y=-0.035)


class Urso:
    """Urso: cabeça marrom com focinho creme e nariz, orelhas redondas e olhos baixos num visor pequeno; peito
    marrom com barriga creme; ombros e manoplas grandes com mãozona de unhas curtas; pernas grossas e patas
    creme de dedos redondos."""
    nome = "Urso"

    @staticmethod
    def cores():
        return cor("placa_urso", (0.17, 0.075, 0.03), 0.05, 0.6), cor("detalhe_urso", (0.8, 0.6, 0.36), 0.05, 0.55)

    @staticmethod
    def cabeca():
        M, C = Urso.cores()
        casco(M, (0.45, 0.41, 0.39))
        rosto("pequeno", "baixo")
        casca("focinho", (0, -0.17, 0.81), (0.17, 0.11, 0.09), C, cabeca, bevel=0.03)
        esfera("nariz", (0, -0.227, 0.842), (0.034, 0.02, 0.024), JUNTA, cabeca, u=14, v=8)
        for s in (1, -1):
            cil("orelha_urso", (s * 0.155, 0.04, 1.105), 0.065, 0.065, 0.04, M, cabeca, rot=(90, 0, 0), segs=16, bevel=0.012)
            cil("orelha_dentro", (s * 0.155, 0.018, 1.108), 0.036, 0.036, 0.008, C, cabeca, rot=(90, 0, 0), segs=14, bevel=0)

    @staticmethod
    def tronco_():
        M, C = Urso.cores()
        pelve(C)
        caixa("tronco_p", (0, 0, 0.578), (0.30, 0.21, 0.2), M, tronco, base=(0.72, 0.84), bevel=0.04)
        esfera("barriga", (0, -0.075, 0.565), (0.105, 0.045, 0.095), C, tronco, u=20, v=12)
        nucleo(y=-0.112, z=0.575, aro=M)
        cil("gola", (0, 0.005, 0.683), 0.11, 0.12, 0.03, M, tronco, segs=14, bevel=0.008)

    @staticmethod
    def braco(s, lado):
        M, C = Urso.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        casca("ombro_p", (s * 0.228, 0, 0.65), (0.14, 0.15, 0.12), M, om, topo=(0.8, 0.85), bevel=0.03)
        cil("braco", (s * 0.228, 0, 0.57), 0.032, 0.032, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        casca("antebraco", (s * 0.264, -0.005, 0.425), (0.135, 0.15, 0.18), M, lu, base=(1.25, 1.2), topo=(0.85, 0.85), bevel=0.03)
        caixa("faixa_luva", (s * 0.258, -0.005, 0.508), (0.1, 0.115, 0.022), C, lu, bevel=0.006)
        cano(s, lado)
        mao(s, lado, "pata_urso", mat=M, unha=C)

    @staticmethod
    def perna(s, lado):
        M, C = Urso.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.05, mat=M)
        casca("bota", (s * 0.10, 0.0, 0.16), (0.135, 0.155, 0.17), M, jo, base=(1.25, 1.2), bevel=0.03)
        caixa("faixa_bota", (s * 0.10, 0.0, 0.215), (0.13, 0.15, 0.02), C, jo, bevel=0.005)
        casca("pe", (s * 0.10, -0.035, 0.05), (0.17, 0.24, 0.075), C, to, topo=(0.84, 0.7), bevel=0.02)
        for dx in (-0.05, 0.0, 0.05):
            esfera("dedo_pe", (s * 0.10 + dx, -0.155, 0.036), (0.03, 0.034, 0.032), C, to, u=12, v=8)
            cil("unha", (s * 0.10 + dx, -0.188, 0.028), 0.01, 0.006, 0.022, JUNTA, to, rot=(105, 0, 0), segs=8, bevel=0)
        sola(s, lado, larg=0.17, comp=0.25)


def faixa_arco(nome, centro, r0, r1, alt, ang0, ang1, esp, mat, pai, segs=14, bevel=0.004):
    """Uma faixa grossa em arco, como um pedaço de cone: raio r0 embaixo (em z do centro) e r1 em cima (z + alt),
    de ang0 a ang1 graus no plano xy a partir de +x (as costas são 90, a frente -90)."""
    cx, cy, cz = centro
    bm = bmesh.new()
    an = []
    for k in range(segs + 1):
        a = math.radians(ang0 + (ang1 - ang0) * k / segs)
        c, s_ = math.cos(a), math.sin(a)
        an.append([bm.verts.new((cx + c * r, cy + s_ * r, cz + z)) for r, z in ((r0, 0), (r1, alt), (r1 - esp, alt), (r0 - esp, 0))])
    for k in range(segs):
        a, b = an[k], an[k + 1]
        for i in range(4):
            bm.faces.new((a[i], b[i], b[(i + 1) % 4], a[(i + 1) % 4]))
    bm.faces.new(an[0])
    bm.faces.new(list(reversed(an[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return malha(nome, bm, mat, pai, bevel, 1)


def placa_inclinada(nome, centro, tam, ang_y, mat, pai, listras=None, listra_mat=None, casca_=False, **k):
    """Uma placa girada em y (as ombreiras penduradas) e, se pedir, listras horizontais que giram junto."""
    (casca if casca_ else caixa)(nome, centro, tam, mat, pai, rot=(0, ang_y, 0), **k)
    if listras:
        a = math.radians(ang_y)
        lado = 1 if centro[0] > 0 else -1
        for dz in listras:
            c = (centro[0] + dz * math.sin(a) + lado * tam[0] * 0.5 * math.cos(a), centro[1], centro[2] + dz * math.cos(a))
            caixa(nome + "_listra", c, (0.008, tam[1] * 1.02, 0.012), listra_mat, pai, rot=(0, ang_y, 0), bevel=0.003)


class Cachorro:
    """Cachorro: orelhas caídas azuis, focinho com nariz, coleira com plaquinha de osso, colete azul no peito,
    bazuca no antebraço, punhos fechados, pés de pata com dedos amarelos e rabinho curto que abana."""
    nome = "Cachorro"

    @staticmethod
    def cores():
        return cor("detalhe_cachorro", (0.03, 0.2, 0.75), 0.1, 0.45), cor("laranja_cachorro", (0.98, 0.72, 0.08), 0.1, 0.45)

    @staticmethod
    def cabeca():
        A, Y = Cachorro.cores()
        casco(BRANCA, (0.43, 0.40, 0.39))
        rosto("faixa", "redondo")
        caixa("testa", (0, -0.15, 1.05), (0.3, 0.11, 0.04), A, cabeca, topo=(0.86, 0.8), rot=(-10, 0, 0), bevel=0.014)
        casca("focinho", (0, -0.165, 0.80), (0.17, 0.11, 0.085), BRANCA, cabeca, topo=(0.85, 0.9), bevel=0.03)
        esfera("nariz", (0, -0.222, 0.83), (0.034, 0.022, 0.026), JUNTA, cabeca, u=14, v=8)
        for s in (1, -1):
            casca("orelha_cao", (s * 0.228, 0.0, 0.9), (0.05, 0.13, 0.22), A, cabeca, base=(0.9, 0.85), topo=(1, 0.8), rot=(0, -s * 10, 0), bevel=0.02)
        caixa("crista", (0, 0.03, 1.122), (0.05, 0.26, 0.02), A, cabeca, bevel=0.008)

    @staticmethod
    def tronco_():
        A, Y = Cachorro.cores()
        pelve(A)
        casca("tronco_p", (0, 0, 0.575), (0.27, 0.2, 0.19), BRANCA, tronco, base=(0.66, 0.82), bevel=0.035)
        casca("colete", (0, -0.012, 0.6), (0.24, 0.19, 0.12), A, tronco, base=(0.92, 0.95), bevel=0.03)
        nucleo(y=-0.108, z=0.585, aro=Y, anel=A)
        cil("coleira", (0, 0, 0.684), 0.1, 0.1, 0.026, A, tronco, segs=16, bevel=0.005)
        # plaquinha de osso pendurada na coleira
        caixa("osso", (0, -0.108, 0.652), (0.036, 0.012, 0.014), Y, tronco, bevel=0.004)
        for dx in (-0.019, 0.019):
            for dz in (-0.007, 0.007):
                esfera("osso", (dx, -0.108, 0.652 + dz), (0.009, 0.008, 0.009), Y, tronco, u=10, v=6)
        cauda([(0, 0.06, 0.43), (0, 0.14, 0.415), (0, 0.215, 0.45), (0, 0.255, 0.52), (0, 0.262, 0.585)],
              (0.03, 0.029, 0.027, 0.024, 0.02), A, ponta=(0.032, 0.032, 0.036), ponta_mat=BRANCA)

    @staticmethod
    def braco(s, lado):
        A, Y = Cachorro.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        casca("ombro_p", (s * 0.222, 0, 0.648), (0.12, 0.135, 0.1), A, om, topo=(0.8, 0.85), bevel=0.03)
        cil("braco", (s * 0.228, 0, 0.57), 0.028, 0.028, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        casca("antebraco", (s * 0.262, -0.005, 0.44), (0.11, 0.12, 0.15), BRANCA, lu, base=(1.15, 1.15), topo=(0.9, 0.9), bevel=0.03)
        caixa("faixa_luva", (s * 0.262, -0.005, 0.505), (0.1, 0.11, 0.02), Y, lu, bevel=0.005)
        # a bazuca: um tubo grosso sobre o antebraço, a boca no mesmo lugar do cano
        x = s * 0.262
        cil("cano_base", (x, -0.094, 0.445), 0.036, 0.036, 0.13, A, lu, segs=14, bevel=0.006)
        cil("cano_anel", (x, -0.094, 0.47), 0.039, 0.039, 0.014, Y, lu, segs=14, bevel=0.003)
        cil("cano", (x, -0.093, 0.36), 0.031, 0.026, 0.05, BOCAL, lu, segs=12, bevel=0.003)
        cil("luz_arma", (x, -0.092, 0.3335), 0.017, 0.017, 0.004, OLHOS, lu, segs=10, bevel=0)
        mao(s, lado, "punho")

    @staticmethod
    def perna(s, lado):
        A, Y = Cachorro.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.04, placa=BRANCA)
        esfera("joelho_p", (s * 0.097, -0.05, 0.258), (0.05, 0.04, 0.048), A, jo, u=16, v=10)
        casca("bota", (s * 0.10, 0.0, 0.158), (0.12, 0.14, 0.17), BRANCA, jo, base=(1.22, 1.18), bevel=0.03)
        caixa("faixa_bota", (s * 0.10, 0.0, 0.1), (0.14, 0.16, 0.02), A, jo, bevel=0.005)
        casca("pe", (s * 0.10, -0.035, 0.05), (0.16, 0.23, 0.08), A, to, topo=(0.82, 0.7), bevel=0.02)
        for dx in (-0.05, -0.017, 0.017, 0.05):
            esfera("dedo_pe", (s * 0.10 + dx, -0.148, 0.036), (0.022, 0.03, 0.028), Y, to, u=12, v=8)
        sola(s, lado, larg=0.16, comp=0.24, y=-0.035)


class Caldeira:
    """Caldeira: cabeça de tambor de cobre com chaminé, manômetro e rebites; peito de tanque deitado com tampas
    de latão e canos até os ombros; pistões nos braços; boca de trombone no cano; botas de ferro rebitadas."""
    nome = "Caldeira"

    @staticmethod
    def cores():
        return cor("placa_caldeira", (0.5, 0.08, 0.05), 0.35, 0.45), cor("laranja_caldeira", (0.78, 0.56, 0.22), 0.75, 0.32)

    @staticmethod
    def cabeca():
        V, L = Caldeira.cores()
        cil("cabeca_p", (0, 0.015, 0.925), 0.205, 0.205, 0.36, V, cabeca, segs=24, bevel=0.03)
        for z in (0.765, 1.088):
            cil("aro", (0, 0.015, z), 0.212, 0.212, 0.028, L, cabeca, segs=24, bevel=0.005)
            for k in range(10):
                a = math.radians(-90 + 36 * k + 18)
                esfera("rebite", (0.217 * math.cos(a), 0.015 + 0.217 * math.sin(a), z), (0.009,) * 3, L, cabeca, u=8, v=6)
        cil("tampa", (0, 0.015, 1.112), 0.17, 0.12, 0.03, L, cabeca, segs=24, bevel=0.008)
        caixa("moldura", (0, -0.148, 0.935), (0.31, 0.1, 0.19), L, cabeca, bevel=0.025)
        rosto("pequeno", "baixo")
        # chaminé atrás, com um anel e a boca escura
        cil("chamine", (0.07, 0.07, 1.2), 0.036, 0.042, 0.15, JUNTA, cabeca, segs=12, bevel=0.004)
        cil("anel_chamine", (0.07, 0.07, 1.27), 0.05, 0.05, 0.024, L, cabeca, segs=12, bevel=0.004)
        # manômetro do lado esquerdo
        cil("manometro", (0.212, -0.04, 0.97), 0.045, 0.045, 0.03, L, cabeca, rot=(0, 90, 0), segs=16, bevel=0.004)
        cil("mostrador", (0.228, -0.04, 0.97), 0.036, 0.036, 0.004, BRANCA, cabeca, rot=(0, 90, 0), segs=16, bevel=0)
        caixa("ponteiro", (0.231, -0.03, 0.978), (0.003, 0.028, 0.005), JUNTA, cabeca, rot=(40, 0, 0), bevel=0)

    @staticmethod
    def tronco_():
        V, L = Caldeira.cores()
        pelve(L)
        cil("tronco_p", (0, 0, 0.578), 0.105, 0.105, 0.24, V, tronco, rot=(0, 90, 0), segs=20, bevel=0.01)
        for s in (1, -1):
            esfera("tampa_tanque", (s * 0.12, 0, 0.578), (0.035, 0.1, 0.1), L, tronco, u=20, v=10)
            cil("cinta", (s * 0.06, 0, 0.578), 0.11, 0.11, 0.018, L, tronco, rot=(0, 90, 0), segs=20, bevel=0.003)
            tubo("cano_vapor", arco((s * 0.07, -0.06, 0.66), (s * 0.165, -0.02, 0.665), (0, -0.01, 0.05), 5), (0.016,) * 5, L, tronco, segs=8)
        nucleo(y=-0.098, z=0.585, aro=L, anel=V)
        cil("gola", (0, 0.005, 0.683), 0.1, 0.11, 0.03, JUNTA, tronco, segs=14, bevel=0.006)

    @staticmethod
    def braco(s, lado):
        V, L = Caldeira.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        esfera("ombro_p", (s * 0.225, 0, 0.648), (0.085, 0.09, 0.07), L, om, u=20, v=12)
        cil("ombro_aro", (s * 0.225, 0, 0.63), 0.09, 0.095, 0.03, V, om, segs=18, bevel=0.006)
        cil("braco", (s * 0.228, 0, 0.57), 0.026, 0.026, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        # o pistão: camisa grossa em cima, haste de latão embaixo
        cil("pistao", (s * 0.265, 0.035, 0.6), 0.02, 0.02, 0.05, V, om, rot=(0, s * -20, 0), segs=10, bevel=0.003)
        cil("haste", (s * 0.252, 0.035, 0.56), 0.008, 0.008, 0.05, L, om, rot=(0, s * -20, 0), segs=8, bevel=0)
        cil("antebraco", (s * 0.262, -0.005, 0.43), 0.068, 0.062, 0.17, V, lu, segs=18, bevel=0.012)
        for z in (0.505, 0.36):
            cil("cinta_luva", (s * 0.262, -0.005, z), 0.072, 0.072, 0.016, L, lu, segs=18, bevel=0.003)
        caixa("cano_base", (s * 0.262, -0.086, 0.435), (0.056, 0.034, 0.10), JUNTA, lu, topo=(0.8, 1), bevel=0.008)
        cil("cano", (s * 0.262, -0.092, 0.37), 0.03, 0.016, 0.07, L, lu, segs=14, bevel=0.003)
        cil("luz_arma", (s * 0.262, -0.092, 0.3355), 0.02, 0.02, 0.004, OLHOS, lu, segs=12, bevel=0)
        mao(s, lado, "punho")

    @staticmethod
    def perna(s, lado):
        V, L = Caldeira.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.045)
        esfera("joelho_p", (s * 0.097, -0.04, 0.258), (0.05, 0.05, 0.05), L, jo, u=16, v=10)
        cil("bota", (s * 0.10, 0, 0.155), 0.072, 0.064, 0.17, V, jo, segs=18, bevel=0.012)
        cil("cinta_bota", (s * 0.10, 0, 0.21), 0.075, 0.075, 0.018, L, jo, segs=18, bevel=0.003)
        caixa("pe", (s * 0.10, -0.04, 0.048), (0.16, 0.25, 0.075), JUNTA, to, topo=(0.85, 0.7), bevel=0.02)
        caixa("biqueira", (s * 0.10, -0.135, 0.045), (0.14, 0.06, 0.06), L, to, topo=(0.85, 0.6), bevel=0.014)
        for dx in (-0.055, 0.055):
            for dy in (-0.07, 0.03):
                esfera("rebite", (s * 0.10 + dx, dy, 0.078), (0.009,) * 3, L, to, u=8, v=6)
        sola(s, lado, larg=0.165)


class Majestade:
    """Majestade: coroa dourada de pontas com bolinhas, gola franzida, faldas roxas de barra dourada, ombros
    bufantes, luvas brancas e botas de bico fino com salto dourado."""
    nome = "Majestade"

    @staticmethod
    def cores():
        return cor("placa_majestade", (0.3, 0.06, 0.45), 0.15, 0.4), cor("laranja_majestade", (0.85, 0.65, 0.15), 0.65, 0.3)

    @staticmethod
    def cabeca():
        R_, O = Majestade.cores()
        casco(BRANCA, (0.43, 0.40, 0.39))
        rosto("redondo", "padrao")
        caixa("testa", (0, -0.15, 1.045), (0.3, 0.11, 0.035), R_, cabeca, topo=(0.86, 0.8), rot=(-10, 0, 0), bevel=0.012)
        for s in (1, -1):
            cil("brinco", (s * 0.205, 0.0, 0.9), 0.05, 0.05, 0.03, R_, cabeca, rot=(0, 90, 0), segs=16, bevel=0.006)
            esfera("joia", (s * 0.222, 0.0, 0.9), (0.012, 0.024, 0.024), O, cabeca, u=12, v=8)
        cil("coroa", (0, 0.015, 1.1), 0.125, 0.13, 0.06, O, cabeca, segs=20, bevel=0.006)
        for k in range(7):
            a = math.radians(-90 + k * 360 / 7)
            x, y = 0.128 * math.cos(a), 0.015 + 0.128 * math.sin(a)
            tubo("ponta_coroa", [(x, y, 1.125), (x, y, 1.165), (x, y, 1.19)], (0.024, 0.016, 0.006), O, cabeca, segs=8)
            esfera("bolinha", (x, y, 1.195), (0.014,) * 3, O, cabeca, u=10, v=6)
        esfera("gema", (0, -0.118, 1.1), (0.024, 0.014, 0.024), cor("detalhe_majestade_gema", (0.05, 0.45, 0.7), 0.1, 0.15), cabeca, u=12, v=8)

    @staticmethod
    def tronco_():
        R_, O = Majestade.cores()
        pelve(O)
        casca("tronco_p", (0, 0, 0.575), (0.26, 0.2, 0.19), R_, tronco, base=(0.62, 0.82), bevel=0.035)
        caixa("peitilho", (0, -0.092, 0.6), (0.1, 0.02, 0.13), BRANCA, tronco, base=(0.5, 1), bevel=0.01)
        nucleo(y=-0.104, z=0.585, aro=O, anel=R_)
        for k in range(14):
            a = 2 * math.pi * k / 14
            esfera("gola_franzida", (0.098 * math.cos(a), 0.098 * math.sin(a), 0.698), (0.034, 0.034, 0.028), BRANCA, tronco, u=12, v=8)
        faldas(R_, borda=O, alt=0.1)

    @staticmethod
    def braco(s, lado):
        R_, O = Majestade.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        esfera("ombro_p", (s * 0.225, 0, 0.645), (0.1, 0.105, 0.085), R_, om, u=24, v=14)
        cil("ombro_aro", (s * 0.225, 0, 0.61), 0.094, 0.094, 0.016, O, om, segs=20, bevel=0.004)
        for dy in (-0.05, 0.0, 0.05):
            tubo("gomo_bufante", arco((s * 0.25, dy, 0.73), (s * 0.31, dy, 0.6), (s * 0.04, 0, 0.01), 5), (0.009,) * 5, O, om, segs=6)
        cil("braco", (s * 0.228, 0, 0.57), 0.026, 0.026, 0.10, BRANCA, om, rot=(0, s * -20, 0), segs=8)
        casca("antebraco", (s * 0.262, -0.005, 0.435), (0.1, 0.115, 0.16), BRANCA, lu, base=(1.1, 1.1), bevel=0.03)
        cil("punho_renda", (s * 0.262, -0.005, 0.36), 0.075, 0.068, 0.03, O, lu, segs=18, bevel=0.005)
        cano(s, lado, R_)
        mao(s, lado, mat=BRANCA)

    @staticmethod
    def perna(s, lado):
        R_, O = Majestade.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.036, mat=BRANCA)
        esfera("joelho_p", (s * 0.097, -0.045, 0.255), (0.04, 0.03, 0.04), O, jo, u=14, v=10)
        casca("bota", (s * 0.10, 0.0, 0.16), (0.11, 0.13, 0.17), R_, jo, base=(1.1, 1.05), topo=(1.15, 1.15), bevel=0.03)
        cil("cano_bota", (s * 0.10, 0.0, 0.238), 0.07, 0.074, 0.022, O, jo, segs=18, bevel=0.005)
        casca("pe", (s * 0.10, -0.05, 0.055), (0.13, 0.25, 0.07), R_, to, topo=(0.7, 0.6), base=(1, 1), bevel=0.02)
        tubo("bico_pe", arco((s * 0.10, -0.15, 0.045), (s * 0.10, -0.205, 0.06), (0, 0, 0.01), 4), (0.032, 0.026, 0.016, 0.006), R_, to, segs=10)
        caixa("salto", (s * 0.10, 0.06, 0.035), (0.07, 0.05, 0.07), O, to, base=(0.8, 0.8), bevel=0.01)
        sola(s, lado, larg=0.13, comp=0.2, y=-0.06)


class Lucano:
    """Lucano (besouro-veado): pinças grandes de prata na testa, curvadas uma para a outra, de pontas redondas;
    placas lilás em V no peito; ombreiras dobradas como asa; barbatana fixa por fora do antebraço; pés de bico."""
    nome = "Lucano"

    @staticmethod
    def cores():
        return (cor("placa_lucano", (0.11, 0.12, 0.14), 0.5, 0.35), cor("detalhe_lucano", (0.55, 0.42, 0.88), 0.2, 0.35),
                cor("laranja_lucano", (0.75, 0.77, 0.8), 0.85, 0.22))

    @staticmethod
    def cabeca():
        G, L, P = Lucano.cores()
        casco(G, (0.42, 0.40, 0.38))
        rosto("faixa", "baixo")
        caixa("testa", (0, -0.15, 1.045), (0.33, 0.12, 0.04), L, cabeca, topo=(0.86, 0.8), rot=(-10, 0, 0), bevel=0.014)
        for s in (1, -1):
            caixa("placa_lado", (s * 0.176, -0.02, 0.92), (0.03, 0.2, 0.2), L, cabeca, base=(1, 0.5), rot=(-18, 0, 0), bevel=0.01)
            cil("base_pinca", (s * 0.1, -0.1, 1.075), 0.044, 0.048, 0.03, P, cabeca, rot=(-20, s * 12, 0), segs=12, bevel=0.004)
            pts = arco((s * 0.1, -0.1, 1.08), (s * 0.035, -0.2, 1.31), (s * 0.075, 0.0, 0.0), 6)
            tubo("pinca", pts, (0.038, 0.034, 0.03, 0.025, 0.02, 0.017), P, cabeca, segs=12)
            esfera("ponta_pinca", tuple(pts[-1]), (0.019,) * 3, P, cabeca, u=12, v=8)
            m = pts[3]
            esfera("dente_pinca", (m.x - s * 0.026, m.y, m.z), (0.016,) * 3, P, cabeca, u=10, v=6)

    @staticmethod
    def tronco_():
        G, L, P = Lucano.cores()
        pelve(L)
        casca("tronco_p", (0, 0, 0.575), (0.27, 0.2, 0.19), G, tronco, base=(0.6, 0.82), bevel=0.035)
        for s in (1, -1):
            caixa("placa_v", (s * 0.06, -0.095, 0.6), (0.06, 0.02, 0.15), L, tronco, base=(0.5, 1), rot=(0, s * 22, 0), bevel=0.008)
        nucleo(y=-0.104, z=0.585, aro=P, anel=L)
        cil("gola", (0, 0.005, 0.682), 0.1, 0.11, 0.026, P, tronco, segs=14, bevel=0.005)

    @staticmethod
    def braco(s, lado):
        G, L, P = Lucano.cores()
        om, co, lu = J["ombro" + lado], J["cotovelo" + lado], J["luva" + lado]
        caixa("ombro_p", (s * 0.22, 0, 0.648), (0.11, 0.13, 0.1), G, om, topo=(0.75, 0.8), bevel=0.025)
        caixa("ombro_asa", (s * 0.255, 0.01, 0.675), (0.1, 0.15, 0.025), L, om, base=(1, 1), topo=(0.8, 0.6), rot=(0, -s * 25, 0), bevel=0.01)
        cil("braco", (s * 0.228, 0, 0.57), 0.026, 0.026, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        casca("antebraco", (s * 0.262, -0.005, 0.435), (0.11, 0.12, 0.16), G, lu, base=(1.12, 1.12), topo=(0.9, 0.9), bevel=0.028)
        caixa("faixa_luva", (s * 0.262, -0.005, 0.5), (0.1, 0.11, 0.016), P, lu, bevel=0.004)
        # a barbatana fica na junta do cotovelo, que não torce: sempre do lado de fora
        caixa("barbatana", (s * 0.338, 0.02, 0.44), (0.014, 0.13, 0.17), L, co, base=(1, 0.45), topo=(1, 1.15), rot=(-14, 0, 0), bevel=0.012)
        cano(s, lado, P)
        mao(s, lado)

    @staticmethod
    def perna(s, lado):
        G, L, P = Lucano.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.036, placa=G)
        tubo("joelho_p", arco((s * 0.097, -0.04, 0.24), (s * 0.097, -0.085, 0.31), (0, -0.01, 0), 4), (0.034, 0.028, 0.02, 0.012), L, jo, segs=10)
        esfera("ponta_joelho", (s * 0.097, -0.085, 0.31), (0.012,) * 3, L, jo, u=10, v=6)
        casca("bota", (s * 0.10, 0.0, 0.158), (0.1, 0.12, 0.17), G, jo, base=(1.25, 1.2), bevel=0.028)
        caixa("faixa_bota", (s * 0.10, 0.0, 0.2), (0.105, 0.125, 0.016), P, jo, bevel=0.004)
        casca("pe", (s * 0.10, -0.045, 0.05), (0.14, 0.25, 0.075), G, to, topo=(0.7, 0.55), bevel=0.02)
        caixa("bico", (s * 0.10, -0.15, 0.04), (0.1, 0.06, 0.05), L, to, topo=(0.6, 0.5), base=(0.8, 1), bevel=0.012)
        sola(s, lado, larg=0.14)


class Cavaleiro:
    """Cavaleiro: elmo prateado com penacho azul, nasal dourado entre os olhos e viseira de testa; peitoral com
    faldas azuis; ombreiras em três camadas; escudo só no braço esquerdo; grevas com joelheira e pés de lâminas."""
    nome = "Cavaleiro"

    @staticmethod
    def cores():
        return (cor("placa_cavaleiro", (0.7, 0.72, 0.76), 0.8, 0.28), cor("detalhe_cavaleiro", (0.06, 0.13, 0.52), 0.15, 0.4),
                cor("laranja_cavaleiro", (0.85, 0.64, 0.18), 0.7, 0.3))

    @staticmethod
    def cabeca():
        P, A, O = Cavaleiro.cores()
        casco(P, (0.43, 0.41, 0.39))
        rosto("padrao", "padrao")
        caixa("aba_testa", (0, -0.17, 1.035), (0.34, 0.08, 0.035), O, cabeca, topo=(0.9, 0.8), rot=(-8, 0, 0), bevel=0.01)
        caixa("nasal", (0, -0.207, 0.95), (0.026, 0.018, 0.17), O, cabeca, base=(0.6, 1), bevel=0.006)
        for s in (1, -1):
            caixa("bochecheira", (s * 0.165, -0.12, 0.84), (0.06, 0.13, 0.13), P, cabeca, base=(0.8, 0.7), rot=(0, 0, -s * 10), bevel=0.02)
        tubo("penacho", arco((0, -0.12, 1.1), (0, 0.2, 1.06), (0, 0.0, 0.14), 8), (0.03, 0.045, 0.052, 0.054, 0.05, 0.044, 0.034, 0.02), A, cabeca, segs=14)
        caixa("base_penacho", (0, 0.03, 1.123), (0.04, 0.26, 0.02), O, cabeca, bevel=0.006)

    @staticmethod
    def tronco_():
        P, A, O = Cavaleiro.cores()
        pelve(O)
        casca("tronco_p", (0, 0, 0.578), (0.28, 0.21, 0.19), P, tronco, base=(0.66, 0.82), bevel=0.035)
        caixa("peito_frente", (0, -0.095, 0.6), (0.18, 0.03, 0.13), P, tronco, base=(0.6, 1), bevel=0.02)
        caixa("losango", (0, -0.104, 0.585), (0.1, 0.014, 0.1), A, tronco, rot=(0, 45, 0), bevel=0.006)
        nucleo(y=-0.114, z=0.585, aro=O, anel=A)
        cil("gola", (0, 0.005, 0.683), 0.105, 0.115, 0.032, O, tronco, segs=16, bevel=0.006)
        faldas(A, borda=O, alt=0.1)

    @staticmethod
    def braco(s, lado):
        P, A, O = Cavaleiro.cores()
        om, co, lu = J["ombro" + lado], J["cotovelo" + lado], J["luva" + lado]
        casca("ombro_p", (s * 0.222, 0, 0.665), (0.14, 0.15, 0.08), P, om, topo=(0.75, 0.8), bevel=0.025)
        for k, (dx, z, ang, mat) in enumerate(((0.024, 0.628, 18, A), (0.044, 0.598, 30, P))):
            caixa("lame", (s * (0.222 + dx), 0, z), (0.13 - k * 0.012, 0.15 - k * 0.01, 0.035), mat, om, rot=(0, -s * ang, 0), bevel=0.01)
            caixa("lame_borda", (s * (0.222 + dx + 0.012), 0, z - 0.016), (0.12 - k * 0.012, 0.152 - k * 0.01, 0.01), O, om, rot=(0, -s * ang, 0), bevel=0.003)
        cil("braco", (s * 0.228, 0, 0.57), 0.026, 0.026, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        caixa("antebraco", (s * 0.262, -0.005, 0.43), (0.11, 0.125, 0.17), P, lu, base=(1.18, 1.15), topo=(0.88, 0.88), bevel=0.025)
        caixa("faixa_luva", (s * 0.262, -0.005, 0.508), (0.09, 0.105, 0.018), O, lu, bevel=0.004)
        cano(s, lado, A)
        mao(s, lado, "punho", mat=P)
        if lado == "E":
            # o escudo, na junta do cotovelo (não torce), virado para fora
            x = s * 0.35
            caixa("escudo_borda", (x - s * 0.004, -0.005, 0.43), (0.018, 0.19, 0.27), O, co, base=(1, 0.32), bevel=0.012)
            caixa("escudo", (x + s * 0.006, -0.005, 0.432), (0.014, 0.165, 0.245), A, co, base=(1, 0.3), bevel=0.01)
            caixa("escudo_estrela", (x + s * 0.016, -0.005, 0.47), (0.008, 0.05, 0.05), O, co, rot=(45, 0, 0), bevel=0.004)
            caixa("escudo_faixa", (x + s * 0.015, -0.005, 0.47), (0.006, 0.15, 0.014), O, co, bevel=0.002)

    @staticmethod
    def perna(s, lado):
        P, A, O = Cavaleiro.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.04, placa=P)
        esfera("joelheira", (s * 0.097, -0.055, 0.262), (0.05, 0.034, 0.055), O, jo, u=18, v=10)
        esfera("joelheira_ponta", (s * 0.097, -0.088, 0.262), (0.016, 0.012, 0.016), P, jo, u=10, v=6)
        caixa("bota", (s * 0.10, 0.0, 0.158), (0.12, 0.14, 0.17), P, jo, base=(1.2, 1.18), bevel=0.028)
        caixa("greva", (s * 0.10, -0.072, 0.17), (0.07, 0.02, 0.14), A, jo, base=(0.8, 1), bevel=0.008)
        caixa("pe", (s * 0.10, -0.02, 0.048), (0.15, 0.16, 0.07), P, to, topo=(0.85, 0.8), bevel=0.02)
        for k, y in enumerate((-0.1, -0.135, -0.165)):
            caixa("lamina_pe", (s * 0.10, y, 0.044 - k * 0.006), (0.13 - k * 0.012, 0.045, 0.05 - k * 0.008), O if k == 2 else P, to, topo=(0.9, 0.7), bevel=0.01)
        sola(s, lado)


class Enfermeira:
    """Enfermeira: touca branca com coração, fones de escuta nos lados; avental branco com bolso de coração no
    peito rosa; antebraços de cápsula (meio rosa, meio branco); luvas brancas; botinhas rosa de bico redondo."""
    nome = "Enfermeira"

    @staticmethod
    def cores():
        return cor("placa_enfermeira", (0.9, 0.28, 0.5), 0.05, 0.45), cor("detalhe_enfermeira", (0.1, 0.6, 0.45), 0.05, 0.4)

    @staticmethod
    def cabeca():
        R_, M = Enfermeira.cores()
        casco(R_, (0.42, 0.40, 0.39))
        rosto("redondo", "padrao")
        casca("touca", (0, -0.02, 1.12), (0.27, 0.19, 0.075), BRANCA, cabeca, topo=(0.8, 0.75), rot=(-12, 0, 0), bevel=0.025)
        caixa("touca_faixa", (0, -0.03, 1.098), (0.275, 0.2, 0.016), M, cabeca, rot=(-12, 0, 0), bevel=0.005)
        coracao((0, -0.135, 1.13), 0.075, R_, cabeca)
        for s in (1, -1):
            cil("fone", (s * 0.205, 0.0, 0.9), 0.052, 0.052, 0.035, M, cabeca, rot=(0, 90, 0), segs=18, bevel=0.008)
            cil("fone_luz", (s * 0.224, 0.0, 0.9), 0.024, 0.024, 0.006, BRANCA, cabeca, rot=(0, 90, 0), segs=14, bevel=0)

    @staticmethod
    def tronco_():
        R_, M = Enfermeira.cores()
        pelve(M)
        casca("tronco_p", (0, 0, 0.575), (0.25, 0.19, 0.19), R_, tronco, base=(0.62, 0.8), bevel=0.04)
        caixa("avental", (0, -0.088, 0.565), (0.17, 0.02, 0.19), BRANCA, tronco, base=(1.2, 1), topo=(0.9, 1), bevel=0.012)
        for s in (1, -1):
            caixa("alca", (s * 0.07, -0.02, 0.66), (0.03, 0.17, 0.014), BRANCA, tronco, rot=(0, s * 10, 0), bevel=0.004)
        nucleo(y=-0.1, z=0.6, aro=M, anel=BRANCA)
        caixa("bolso", (0, -0.1, 0.505), (0.1, 0.012, 0.05), BRANCA, tronco, bevel=0.006)
        coracao((0, -0.108, 0.506), 0.034, R_, tronco)
        caixa("falda", (0, -0.084, 0.385), (0.1, 0.016, 0.08), BRANCA, raiz, base=(1.2, 1), rot=(-12, 0, 0), bevel=0.006)
        caixa("falda_borda", (0, -0.093, 0.35), (0.12, 0.02, 0.012), M, raiz, rot=(-12, 0, 0), bevel=0.003)

    @staticmethod
    def braco(s, lado):
        R_, M = Enfermeira.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        esfera("ombro_p", (s * 0.222, 0, 0.648), (0.075, 0.08, 0.065), R_, om, u=22, v=12)
        cil("ombro_aro", (s * 0.222, 0, 0.615), 0.07, 0.07, 0.016, M, om, segs=18, bevel=0.004)
        cil("braco", (s * 0.228, 0, 0.57), 0.024, 0.024, 0.10, BRANCA, om, rot=(0, s * -20, 0), segs=8)
        # a cápsula: metade rosa em cima, metade branca embaixo, um anel verde no meio
        x, y = s * 0.262, -0.005
        cil("antebraco", (x, y, 0.47), 0.058, 0.058, 0.07, R_, lu, segs=20, bevel=0)
        esfera("capsula_topo", (x, y, 0.505), (0.058, 0.058, 0.03), R_, lu, u=20, v=10)
        cil("antebraco_b", (x, y, 0.4), 0.058, 0.058, 0.07, BRANCA, lu, segs=20, bevel=0)
        esfera("capsula_fundo", (x, y, 0.365), (0.058, 0.058, 0.03), BRANCA, lu, u=20, v=10)
        cil("capsula_anel", (x, y, 0.435), 0.061, 0.061, 0.014, M, lu, segs=20, bevel=0.003)
        cano(s, lado, M)
        mao(s, lado, "pata", mat=BRANCA, unha=R_)

    @staticmethod
    def perna(s, lado):
        R_, M = Enfermeira.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.034, mat=BRANCA)
        esfera("joelho_p", (s * 0.097, -0.042, 0.257), (0.036, 0.03, 0.036), M, jo, u=14, v=10)
        cil("meia", (s * 0.10, 0, 0.21), 0.05, 0.05, 0.07, BRANCA, jo, segs=16, bevel=0.006)
        casca("bota", (s * 0.10, 0.0, 0.135), (0.11, 0.13, 0.12), R_, jo, base=(1.18, 1.14), bevel=0.03)
        caixa("faixa_bota", (s * 0.10, 0.0, 0.19), (0.104, 0.124, 0.016), M, jo, bevel=0.004)
        casca("pe", (s * 0.10, -0.035, 0.05), (0.15, 0.22, 0.08), R_, to, topo=(0.8, 0.7), bevel=0.02)
        esfera("bico_pe", (s * 0.10, -0.13, 0.042), (0.06, 0.045, 0.04), BRANCA, to, u=16, v=10)
        sola(s, lado, comp=0.23, y=-0.035)


class Samurai:
    """Samurai: elmo índigo com sol dourado na frente, aba e abas viradas dos lados e o protetor de nuca em três
    degraus; peito amarrado com cordões; faldas; ombreiras retas penduradas; caneleiras de talas e pés de tabi."""
    nome = "Samurai"

    @staticmethod
    def cores():
        return (cor("placa_samurai", (0.07, 0.1, 0.32), 0.25, 0.35), cor("laranja_samurai", (0.85, 0.62, 0.15), 0.7, 0.3),
                cor("detalhe_samurai", (0.62, 0.09, 0.07), 0.05, 0.55))

    @staticmethod
    def cabeca():
        I, O, V = Samurai.cores()
        casco(I, (0.42, 0.40, 0.39))
        rosto("faixa", "baixo")
        for i in range(3):
            faixa_arco("nuca", (0, 0.015, 0.84 - i * 0.04), 0.225 + i * 0.022, 0.205 + i * 0.022, 0.05, -25, 205, 0.016, I if i != 1 else V, cabeca, segs=16)
        caixa("aba_testa", (0, -0.16, 1.035), (0.36, 0.1, 0.022), O, cabeca, topo=(0.9, 0.8), rot=(-14, 0, 0), bevel=0.008)
        for s in (1, -1):
            caixa("aba_lado", (s * 0.2, -0.13, 0.93), (0.03, 0.09, 0.12), I, cabeca, rot=(0, 0, s * 35), bevel=0.012)
            caixa("aba_lado_borda", (s * 0.208, -0.17, 0.93), (0.032, 0.012, 0.124), O, cabeca, rot=(0, 0, s * 35), bevel=0.004)
        # o sol: um disco dourado com raios curtos, de pé na frente do elmo
        cil("sol", (0, -0.165, 1.14), 0.05, 0.05, 0.018, O, cabeca, rot=(90, 0, 0), segs=20, bevel=0.004)
        for k in range(8):
            a = k * math.pi / 4
            caixa("raio_sol", (0.072 * math.cos(a), -0.165, 1.14 + 0.072 * math.sin(a)), (0.02, 0.012, 0.022), O, cabeca,
                  rot=(0, -math.degrees(a), 0), topo=(0.4, 1), bevel=0.003)
        cil("haste_sol", (0, -0.16, 1.07), 0.012, 0.012, 0.06, O, cabeca, segs=8, bevel=0)

    @staticmethod
    def tronco_():
        I, O, V = Samurai.cores()
        pelve(V)
        casca("tronco_p", (0, 0, 0.578), (0.28, 0.21, 0.19), I, tronco, base=(0.66, 0.84), bevel=0.035)
        caixa("peito_alto", (0, -0.09, 0.64), (0.2, 0.03, 0.05), BRANCA, tronco, bevel=0.01)
        for z in (0.55, 0.52, 0.49):
            caixa("cordao", (0, -0.096, z), (0.2, 0.014, 0.01), V, tronco, base=(0.9, 1), bevel=0.003)
        nucleo(y=-0.1, z=0.588, aro=O, anel=V)
        cil("gola", (0, 0.005, 0.683), 0.1, 0.11, 0.026, V, tronco, segs=14, bevel=0.005)
        faldas(I, borda=O, alt=0.11)

    @staticmethod
    def braco(s, lado):
        I, O, V = Samurai.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        esfera("ombro_p", (s * 0.222, 0, 0.652), (0.07, 0.085, 0.06), I, om, u=18, v=10)
        placa_inclinada("sode", (s * 0.29, 0, 0.6), (0.02, 0.17, 0.15), -s * 14, I, om, listras=(-0.045, 0.0, 0.045), listra_mat=V, bevel=0.008)
        caixa("sode_alto", (s * 0.276, 0, 0.678), (0.03, 0.18, 0.02), O, om, rot=(0, -s * 14, 0), bevel=0.004)
        cil("braco", (s * 0.228, 0, 0.57), 0.026, 0.026, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        casca("antebraco", (s * 0.262, -0.005, 0.435), (0.1, 0.12, 0.16), I, lu, base=(1.12, 1.12), bevel=0.028)
        for z in (0.49, 0.44, 0.39):
            caixa("faixa_luva", (s * 0.262, -0.005, z), (0.104, 0.124, 0.01), O, lu, bevel=0.003)
        cano(s, lado, V)
        mao(s, lado)

    @staticmethod
    def perna(s, lado):
        I, O, V = Samurai.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.04)
        esfera("joelho_p", (s * 0.097, -0.05, 0.26), (0.045, 0.035, 0.045), O, jo, u=16, v=10)
        casca("bota", (s * 0.10, 0.0, 0.158), (0.11, 0.13, 0.17), I, jo, base=(1.2, 1.15), bevel=0.028)
        for dx in (-0.032, 0.0, 0.032):
            caixa("tala", (s * 0.10 + dx, -0.076, 0.165), (0.016, 0.012, 0.13), O, jo, base=(1, 1), bevel=0.004)
        cil("amarra", (s * 0.10, 0, 0.095), 0.078, 0.078, 0.014, V, jo, segs=16, bevel=0.003)
        # tabi: o dedão separado dos outros dedos
        casca("pe", (s * 0.10, -0.01, 0.05), (0.14, 0.17, 0.08), BRANCA, to, topo=(0.85, 0.8), bevel=0.02)
        casca("dedos_pe", (s * 0.10 + s * 0.017, -0.125, 0.042), (0.095, 0.08, 0.06), BRANCA, to, topo=(0.8, 0.7), bevel=0.018)
        esfera("dedao", (s * 0.10 - s * 0.05, -0.13, 0.04), (0.026, 0.04, 0.03), BRANCA, to, u=14, v=8)
        caixa("tira", (s * 0.10 - s * 0.028, -0.09, 0.075), (0.012, 0.07, 0.012), V, to, rot=(0, 0, s * 20), bevel=0.003)
        sola(s, lado, larg=0.15)


class Marinheiro:
    """Marinheiro: boina marinha com fitas vermelhas atrás e âncora; gola em V com nó de lenço vermelho e listras
    no peito branco; punhos listrados; calças boca de sino e sapatos escuros."""
    nome = "Marinheiro"

    @staticmethod
    def cores():
        return (cor("placa_marinheiro", (0.02, 0.035, 0.13), 0.1, 0.45), cor("detalhe_marinheiro", (0.78, 0.08, 0.07), 0.05, 0.45),
                cor("laranja_marinheiro", (0.85, 0.66, 0.2), 0.6, 0.35))

    @staticmethod
    def cabeca():
        N, V, O = Marinheiro.cores()
        casco(BRANCA, (0.43, 0.40, 0.39))
        rosto("padrao", "padrao")
        cil("boina_faixa", (0, 0.015, 1.085), 0.17, 0.175, 0.05, N, cabeca, segs=24, bevel=0.008)
        cil("boina", (0, 0.03, 1.13), 0.2, 0.17, 0.04, N, cabeca, rot=(-6, 0, 0), segs=24, bevel=0.015)
        esfera("pompom", (0, 0.03, 1.16), (0.03, 0.03, 0.022), V, cabeca, u=12, v=8)
        # âncora na faixa da frente
        caixa("ancora", (0, -0.163, 1.088), (0.008, 0.006, 0.04), O, cabeca, rot=(-10, 0, 0), bevel=0)
        caixa("ancora_trave", (0, -0.165, 1.1), (0.026, 0.006, 0.006), O, cabeca, rot=(-10, 0, 0), bevel=0)
        tubo("ancora_braco", arco((-0.02, -0.162, 1.078), (0.02, -0.162, 1.078), (0, -0.002, -0.014), 5), (0.004,) * 5, O, cabeca, segs=6)
        for s in (1, -1):
            tubo("fita", arco((s * 0.02, 0.17, 1.08), (s * 0.05, 0.25, 0.92), (0, 0.02, 0.0), 5), (0.012,) * 5, V, cabeca, segs=6)

    @staticmethod
    def tronco_():
        N, V, O = Marinheiro.cores()
        pelve(N)
        casca("tronco_p", (0, 0, 0.575), (0.27, 0.2, 0.19), BRANCA, tronco, base=(0.66, 0.82), bevel=0.035)
        for z in (0.51, 0.535):
            caixa("listra", (0, 0, z), (0.245, 0.19, 0.01), N, tronco, bevel=0.004)
        for s in (1, -1):
            caixa("gola_v", (s * 0.055, -0.094, 0.645), (0.09, 0.02, 0.025), N, tronco, rot=(0, -s * 38, 0), bevel=0.004)
            caixa("gola_ombro", (s * 0.09, -0.02, 0.678), (0.05, 0.17, 0.02), N, tronco, bevel=0.004)
            caixa("lenco_ponta", (s * 0.016, -0.11, 0.6), (0.022, 0.012, 0.05), V, tronco, topo=(1, 1), base=(0.3, 1), rot=(0, -s * 18, 0), bevel=0.004)
        esfera("lenco_no", (0, -0.112, 0.628), (0.022, 0.016, 0.018), V, tronco, u=12, v=8)
        nucleo(y=-0.1, z=0.545, aro=N, anel=V)
        cil("gola", (0, 0.005, 0.683), 0.1, 0.11, 0.026, N, tronco, segs=14, bevel=0.005)

    @staticmethod
    def braco(s, lado):
        N, V, O = Marinheiro.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        casca("ombro_p", (s * 0.218, 0, 0.645), (0.11, 0.125, 0.1), BRANCA, om, topo=(0.8, 0.85), bevel=0.03)
        caixa("ombro_listra", (s * 0.27, 0, 0.64), (0.014, 0.11, 0.05), N, om, bevel=0.004)
        cil("braco", (s * 0.228, 0, 0.57), 0.026, 0.026, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        casca("antebraco", (s * 0.262, -0.005, 0.435), (0.11, 0.125, 0.16), N, lu, base=(1.18, 1.15), bevel=0.028)
        for z in (0.385, 0.365):
            caixa("punho_listra", (s * 0.262, -0.005, z), (0.124, 0.14, 0.008), BRANCA, lu, bevel=0.002)
        cano(s, lado, V)
        mao(s, lado, "punho", mat=BRANCA)

    @staticmethod
    def perna(s, lado):
        N, V, O = Marinheiro.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.042, mat=N)
        cil("boca_de_sino", (s * 0.10, 0, 0.155), 0.088, 0.058, 0.19, N, jo, segs=20, bevel=0.01)
        cil("barra", (s * 0.10, 0, 0.068), 0.09, 0.09, 0.016, BRANCA, jo, segs=20, bevel=0.003)
        caixa("pe", (s * 0.10, -0.035, 0.04), (0.14, 0.24, 0.06), JUNTA, to, topo=(0.85, 0.7), bevel=0.022)
        esfera("bico_pe", (s * 0.10, -0.12, 0.04), (0.065, 0.06, 0.035), JUNTA, to, u=16, v=8)
        caixa("fivela", (s * 0.10, -0.1, 0.07), (0.04, 0.012, 0.022), O, to, rot=(-30, 0, 0), bevel=0.003)
        sola(s, lado, larg=0.15, comp=0.24, y=-0.035)


class Sabre:
    """Dente-de-sabre: cabeça larga ocre com testa listrada, orelhas curtas e focinho creme com dois presões
    curtos de ponta redonda; peito creme; antebraços grossos listrados com patas grandes; rabo curto."""
    nome = "Dente-de-sabre"

    @staticmethod
    def cores():
        return (cor("placa_sabre", (0.66, 0.3, 0.05), 0.05, 0.5), cor("detalhe_sabre", (0.2, 0.08, 0.02), 0.05, 0.55),
                cor("laranja_sabre", (0.9, 0.8, 0.6), 0.05, 0.45))

    @staticmethod
    def cabeca():
        O, M, C = Sabre.cores()
        casco(O, (0.46, 0.41, 0.37))
        rosto("faixa", "baixo")
        casca("focinho", (0, -0.165, 0.81), (0.2, 0.11, 0.09), C, cabeca, topo=(0.85, 0.9), bevel=0.03)
        esfera("nariz", (0, -0.222, 0.845), (0.034, 0.02, 0.022), M, cabeca, u=14, v=8)
        for s in (1, -1):
            # o presão: curto e levemente curvo, de ponta redonda (era o dobro e ficou feio, pedido de 2026-11-23)
            pts = arco((s * 0.05, -0.19, 0.79), (s * 0.046, -0.198, 0.728), (0, -0.007, 0), 5)
            tubo("presa", pts, (0.013, 0.0125, 0.0115, 0.0102, 0.0088), C, cabeca, segs=10)
            esfera("ponta_presa", tuple(pts[-1]), (0.0088,) * 3, C, cabeca, u=10, v=6)
            caixa("orelha_sabre", (s * 0.15, 0.03, 1.11), (0.09, 0.05, 0.08), O, cabeca, topo=(0.35, 0.6), rot=(-8, s * 20, 0), bevel=0.018)
            caixa("orelha_dentro", (s * 0.148, 0.0, 1.104), (0.05, 0.01, 0.05), C, cabeca, topo=(0.35, 0.8), rot=(-8, s * 20, 0), bevel=0.004)
            for k in range(2):
                caixa("listra_rosto", (s * 0.214, -0.06 + k * 0.06, 0.95), (0.012, 0.025, 0.1 - k * 0.02), M, cabeca, rot=(-25, 0, 0), bevel=0.004)
        for dx in (-0.045, 0.0, 0.045):
            caixa("listra_testa", (dx, -0.08, 1.11), (0.022, 0.14, 0.012), M, cabeca, rot=(-30, 0, 0), topo=(0.6, 1), bevel=0.004)

    @staticmethod
    def tronco_():
        O, M, C = Sabre.cores()
        pelve(M)
        casca("tronco_p", (0, 0, 0.578), (0.28, 0.21, 0.2), O, tronco, base=(0.62, 0.8), bevel=0.04)
        esfera("peito", (0, -0.07, 0.6), (0.1, 0.045, 0.08), C, tronco, u=18, v=10)
        nucleo(y=-0.1, z=0.575, aro=M, anel=C)
        for s in (1, -1):
            for k in range(3):
                caixa("listra", (s * 0.128, 0.0, 0.64 - k * 0.05), (0.012, 0.12, 0.016), M, tronco, rot=(0, -s * 15, 0), bevel=0.003)
        cil("gola", (0, 0.005, 0.683), 0.105, 0.115, 0.03, C, tronco, segs=14, bevel=0.008)
        cauda([(0, 0.06, 0.43), (0, 0.13, 0.41), (0, 0.2, 0.42), (0, 0.255, 0.46)], (0.034, 0.031, 0.028, 0.025), O,
              listra=M, ponta=(0.03, 0.03, 0.032), ponta_mat=M)

    @staticmethod
    def braco(s, lado):
        O, M, C = Sabre.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        casca("ombro_p", (s * 0.222, 0, 0.648), (0.13, 0.14, 0.11), O, om, topo=(0.8, 0.85), bevel=0.03)
        for k in range(2):
            caixa("listra_ombro", (s * (0.27 + k * 0.004), 0, 0.665 - k * 0.04), (0.014, 0.1, 0.014), M, om, bevel=0.003)
        cil("braco", (s * 0.228, 0, 0.57), 0.03, 0.03, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        casca("antebraco", (s * 0.264, -0.005, 0.43), (0.13, 0.14, 0.17), O, lu, base=(1.2, 1.18), topo=(0.85, 0.85), bevel=0.03)
        for z in (0.48, 0.43):
            caixa("listra_luva", (s * 0.264, -0.005, z), (0.15, 0.155, 0.014), M, lu, rot=(0, 0, 0), bevel=0.003)
        cano(s, lado, M)
        mao(s, lado, "pata_grande", mat=C, unha=M)

    @staticmethod
    def perna(s, lado):
        O, M, C = Sabre.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.045, mat=O)
        casca("bota", (s * 0.10, 0.0, 0.16), (0.125, 0.15, 0.17), O, jo, base=(1.22, 1.2), bevel=0.03)
        for z in (0.2, 0.15):
            caixa("listra_bota", (s * 0.10, 0.0, z), (0.135, 0.165, 0.014), M, jo, bevel=0.003)
        casca("pe", (s * 0.10, -0.035, 0.05), (0.17, 0.23, 0.08), O, to, topo=(0.8, 0.7), bevel=0.02)
        for dx in (-0.05, 0.0, 0.05):
            esfera("dedo_pe", (s * 0.10 + dx, -0.15, 0.036), (0.03, 0.035, 0.032), C, to, u=12, v=8)
        sola(s, lado, larg=0.17, comp=0.24)


class Solar:
    """Solar: cabeça sextavada laranja-terra com um sol de raios dourados atrás, peito de painel solar azul-escuro
    com moldura dourada, painéis solares em cima dos ombros e joelheiras sextavadas."""
    nome = "Solar"

    @staticmethod
    def cores():
        return (cor("placa_solar", (0.75, 0.22, 0.035), 0.1, 0.45), cor("detalhe_solar", (0.03, 0.06, 0.2), 0.55, 0.18),
                cor("laranja_solar", (0.9, 0.7, 0.2), 0.65, 0.3))

    @staticmethod
    def cabeca():
        T, A, O = Solar.cores()
        cil("cabeca_p", (0, 0.015, 0.925), 0.218, 0.218, 0.37, T, cabeca, segs=6, bevel=0.03)
        cil("tampo", (0, 0.015, 1.115), 0.16, 0.12, 0.03, O, cabeca, segs=6, bevel=0.006)
        rosto("faixa", "padrao")
        # o sol atrás da cabeça: um aro dourado e raios em ponta, como uma coroa de chamas
        cx, cy, cz = 0.0, 0.1, 0.93
        aro = [(cx + 0.245 * math.cos(math.radians(a)), cy, cz + 0.245 * math.sin(math.radians(a))) for a in range(-40, 225, 15)]
        tubo("aro_sol", aro, (0.016,) * len(aro), O, cabeca, segs=8)
        for k in range(11):
            a = math.radians(-30 + k * 24)
            caixa("raio", (cx + 0.29 * math.cos(a), cy, cz + 0.29 * math.sin(a)), (0.05, 0.016, 0.08), O, cabeca,
                  topo=(0.12, 1), rot=(0, 90 - math.degrees(a), 0), bevel=0.006)

    @staticmethod
    def tronco_():
        T, A, O = Solar.cores()
        pelve(O)
        casca("tronco_p", (0, 0, 0.575), (0.27, 0.2, 0.19), T, tronco, base=(0.66, 0.82), bevel=0.035)
        caixa("moldura_painel", (0, -0.09, 0.59), (0.21, 0.03, 0.15), O, tronco, base=(0.85, 1), bevel=0.008)
        caixa("painel", (0, -0.099, 0.59), (0.19, 0.03, 0.13), A, tronco, base=(0.85, 1), bevel=0.004)
        for dx in (-0.064, 0.064):
            caixa("linha_painel", (dx, -0.114, 0.59), (0.005, 0.004, 0.13), O, tronco, bevel=0)
        nucleo(y=-0.108, z=0.585, aro=O, anel=A)
        cil("gola", (0, 0.005, 0.683), 0.1, 0.11, 0.026, O, tronco, segs=6, bevel=0.005)

    @staticmethod
    def braco(s, lado):
        T, A, O = Solar.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        casca("ombro_p", (s * 0.22, 0, 0.64), (0.115, 0.13, 0.095), T, om, topo=(0.8, 0.85), bevel=0.028)
        caixa("painel_ombro_moldura", (s * 0.232, 0, 0.696), (0.16, 0.18, 0.012), O, om, rot=(0, -s * 14, 0), bevel=0.004)
        caixa("painel_ombro", (s * 0.232, 0, 0.704), (0.145, 0.165, 0.008), A, om, rot=(0, -s * 14, 0), bevel=0.002)
        cil("braco", (s * 0.228, 0, 0.57), 0.026, 0.026, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        casca("antebraco", (s * 0.262, -0.005, 0.435), (0.115, 0.13, 0.16), T, lu, base=(1.15, 1.12), bevel=0.028)
        caixa("faixa_luva", (s * 0.262, -0.005, 0.5), (0.1, 0.115, 0.018), O, lu, bevel=0.004)
        cano(s, lado, A)
        mao(s, lado)

    @staticmethod
    def perna(s, lado):
        T, A, O = Solar.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.04, placa=T)
        cil("joelho_p", (s * 0.097, -0.055, 0.262), 0.045, 0.045, 0.025, A, jo, rot=(90, 0, 0), segs=6, bevel=0.004)
        cil("joelho_aro", (s * 0.097, -0.048, 0.262), 0.052, 0.052, 0.012, O, jo, rot=(90, 0, 0), segs=6, bevel=0.002)
        casca("bota", (s * 0.10, 0.0, 0.158), (0.12, 0.14, 0.17), T, jo, base=(1.22, 1.18), bevel=0.028)
        caixa("faixa_bota", (s * 0.10, 0.0, 0.2), (0.125, 0.145, 0.016), A, jo, bevel=0.004)
        casca("pe", (s * 0.10, -0.04, 0.05), (0.15, 0.25, 0.075), T, to, topo=(0.82, 0.66), bevel=0.02)
        caixa("bico", (s * 0.10, -0.15, 0.042), (0.125, 0.05, 0.05), O, to, topo=(0.85, 0.6), bevel=0.012)
        sola(s, lado)


# ---------- os conjuntos dos robôs achados (2026-11-23): abrem acordando o robô, não por nível ----------
def meia_lua(nome, centro, r, esp, s, mat, pai, segs=12):
    """Meio disco de frente (virado para -y), do lado s: os dois lados juntos fazem um olho redondo só, e cada
    metade fica na junta do seu olho (o jogo pisca e inclina cada uma)."""
    bm = bmesh.new()
    x0, y0, z0 = centro
    frente, tras = [], []
    for k in range(segs + 1):
        a = -math.pi / 2 + k * math.pi / segs
        x, z = x0 + s * r * math.cos(a), z0 + r * math.sin(a)
        frente.append(bm.verts.new((x, y0 - esp / 2, z)))
        tras.append(bm.verts.new((x, y0 + esp / 2, z)))
    f = bm.faces.new(frente if s < 0 else list(reversed(frente)))
    bm.faces.new(list(reversed(tras)) if s < 0 else tras)
    anel = list(range(segs + 1))
    for k in anel[:-1]:
        bm.faces.new((frente[k], frente[k + 1], tras[k + 1], tras[k]))
    bm.faces.new((frente[-1], frente[0], tras[0], tras[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    del f
    return malha(nome, bm, mat, pai, 0, 1)


class Mergulhador:
    """Mergulhador: o robô da comporta da Represa. O mesmo jeito do robô de hoje em amarelo e verde-petróleo,
    escotilha redonda de aro cinza com parafusos no lugar do visor, sem crista nem antena; dois cilindros de ar
    nas costas; pés de pato."""
    nome = "Mergulhador"

    @staticmethod
    def cores():
        return (cor("placa_mergulhador", (0.62, 0.40, 0.03), 0.0, 0.45), cor("detalhe_mergulhador", (0.01, 0.13, 0.15), 0.05, 0.4),
                cor("laranja_mergulhador", (0.55, 0.56, 0.55), 0.0, 0.45))

    @staticmethod
    def cabeca():
        Y, T, M = Mergulhador.cores()
        casco(Y)
        # a escotilha: o vidro redondo sai um pouco à frente do aro, e os olhos de tela ficam na frente do vidro
        cil("aro_escotilha", (0, -0.163, 0.925), 0.15, 0.15, 0.04, M, cabeca, rot=(90, 0, 0), segs=20, bevel=0.008)
        cil("visor", (0, -0.172, 0.925), 0.125, 0.125, 0.044, VIDRO, cabeca, rot=(90, 0, 0), segs=20, bevel=0.006)
        for k in range(6):
            a = k * math.pi / 3.0
            cil("parafuso", (math.cos(a) * 0.138, -0.186, 0.925 + math.sin(a) * 0.138), 0.009, 0.009, 0.01, JUNTA, cabeca,
                rot=(90, 0, 0), segs=6, bevel=0)
        for s, lado in LADOS:
            caixa("olho", (s * 0.06, -0.2015, 0.928), (0.032, 0.006, 0.07), OLHOS, J["olho" + lado], bevel=0)
            caixa("placa_lado", (s * 0.172, -0.03, 0.945), (0.03, 0.16, 0.17), T, cabeca, base=(1, 0.45), rot=(-22, 0, 0), bevel=0.01)
            cil("orelha", (s * 0.175, 0.075, 0.87), 0.045, 0.045, 0.03, JUNTA, cabeca, rot=(0, 90, 0), segs=8, bevel=0.006)
            cil("orelha_luz", (s * 0.192, 0.075, 0.87), 0.022, 0.022, 0.006, M, cabeca, rot=(0, 90, 0), segs=8, bevel=0)
        caixa("queixo", (0, -0.14, 0.785), (0.22, 0.10, 0.04), Y, cabeca, base=(0.75, 0.9), bevel=0.014)
        # o engate da mangueira, atrás do capacete
        cil("engate", (0.07, 0.205, 0.86), 0.026, 0.026, 0.03, M, cabeca, rot=(90, 0, 0), segs=10, bevel=0.004)
        cil("engate_boca", (0.07, 0.222, 0.86), 0.016, 0.016, 0.01, JUNTA, cabeca, rot=(90, 0, 0), segs=8, bevel=0)

    @staticmethod
    def tronco_():
        Y, T, M = Mergulhador.cores()
        pelve(Y)
        caixa("tronco_p", (0, 0, 0.575), (0.27, 0.20, 0.19), Y, tronco, base=(0.66, 0.82), bevel=0.035, segs=2)
        caixa("gola", (0, 0.005, 0.677), (0.19, 0.16, 0.028), T, tronco, bevel=0.01)
        nucleo(aro=T, anel=M)
        for s in (1, -1):
            caixa("ombro_laranja", (s * 0.15, 0, 0.652), (0.05, 0.10, 0.03), M, tronco, bevel=0.008)
            # os dois cilindros de ar, por fora da mochila (que não troca)
            cil("cilindro_ar", (s * 0.125, 0.16, 0.60), 0.036, 0.036, 0.2, M, tronco, segs=12, bevel=0.012)
            cil("valvula", (s * 0.125, 0.16, 0.715), 0.016, 0.02, 0.03, JUNTA, tronco, segs=8, bevel=0)
            cil("cinta_ar", (s * 0.125, 0.16, 0.56), 0.039, 0.039, 0.016, T, tronco, segs=12, bevel=0.003)

    @staticmethod
    def braco(s, lado):
        Y, T, M = Mergulhador.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        caixa("ombro_p", (s * 0.218, 0, 0.642), (0.115, 0.135, 0.105), Y, om, topo=(0.75, 0.8), bevel=0.028, segs=2)
        caixa("ombro_azul", (s * 0.278, 0, 0.635), (0.012, 0.075, 0.055), T, om, bevel=0.004)
        cil("braco", (s * 0.228, 0, 0.57), 0.028, 0.028, 0.10, JUNTA, om, rot=(0, s * -20, 0), segs=8)
        caixa("antebraco", (s * 0.262, -0.005, 0.43), (0.12, 0.135, 0.17), Y, lu, base=(1.22, 1.2), topo=(0.85, 0.85), bevel=0.028, segs=2)
        caixa("faixa_luva", (s * 0.258, -0.005, 0.512), (0.085, 0.10, 0.018), M, lu, bevel=0.005)
        caixa("bracelete", (s * 0.338, -0.005, 0.41), (0.016, 0.095, 0.11), T, lu, base=(1, 0.7), bevel=0.005)
        cano(s, lado)
        mao(s, lado)

    @staticmethod
    def perna(s, lado):
        Y, T, M = Mergulhador.cores()
        qu, jo, to = J["quadril" + lado], J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, placa=Y)
        caixa("joelho_p", (s * 0.097, -0.062, 0.262), (0.075, 0.04, 0.075), T, jo, topo=(0.65, 1), bevel=0.012)
        caixa("bota", (s * 0.10, 0.0, 0.158), (0.12, 0.145, 0.17), Y, jo, base=(1.25, 1.2), bevel=0.028, segs=2)
        caixa("faixa_bota", (s * 0.10, 0.088, 0.17), (0.06, 0.012, 0.09), M, jo, bevel=0.004)
        caixa("pe", (s * 0.10, -0.04, 0.05), (0.15, 0.25, 0.07), Y, to, topo=(0.82, 0.66), bevel=0.02)
        caixa("bico", (s * 0.10, -0.15, 0.04), (0.125, 0.05, 0.05), T, to, topo=(0.85, 0.6), bevel=0.012)
        caixa("pe_de_pato", (s * 0.10, -0.24, 0.022), (0.19, 0.17, 0.02), T, to, bevel=0.006)
        sola(s, lado)


class Antigo:
    """Antigo: o robô de peças de antes (robo_v1), redesenhado no tamanho de hoje. Casco creme bem arredondado,
    visor escuro largo com um olho redondo só (metade em cada junta de olho), orelhas verde-água e antena de
    bolinha; juntas e ombros cinza-ardósia; cinto verde-água; antebraços e botas creme com punho verde-água."""
    nome = "Antigo"

    @staticmethod
    def cores():
        return (cor("placa_antigo", (0.62, 0.58, 0.48), 0.0, 0.55), cor("detalhe_antigo", (0.17, 0.46, 0.40), 0.05, 0.45),
                cor("placa_antigo_cinza", (0.085, 0.10, 0.12), 0.1, 0.5))

    @staticmethod
    def cabeca():
        C, T, G = Antigo.cores()
        casca("cabeca_p", (0, 0.015, 0.935), (0.44, 0.40, 0.40), C, cabeca, base=(0.92, 0.92), topo=(0.9, 0.9), bevel=0.15)
        caixa("visor", (0, -0.15, 0.925), (0.34, 0.10, 0.165), VIDRO, cabeca, bevel=0.06, segs=4)
        for s, lado in LADOS:
            meia_lua("olho", (0, -0.2015, 0.925), 0.05, 0.006, s, OLHOS, J["olho" + lado])
            casca("orelha_antigo", (s * 0.232, 0.0, 0.93), (0.034, 0.075, 0.13), T, cabeca, bevel=0.016)
            cil("orelha_base", (s * 0.218, 0.0, 0.93), 0.04, 0.04, 0.012, G, cabeca, rot=(0, 90, 0), segs=12, bevel=0.003)
        cil("antena", (0.075, 0.06, 1.2), 0.006, 0.005, 0.15, G, cabeca, segs=6, bevel=0)
        esfera("ponta_antena", (0.075, 0.06, 1.285), (0.018, 0.018, 0.018), T, cabeca, u=12, v=8)

    @staticmethod
    def tronco_():
        C, T, G = Antigo.cores()
        caixa("pelve", (0, 0, 0.42), (0.17, 0.135, 0.09), G, raiz, base=(0.72, 0.9), bevel=0.022)
        casca("tronco_p", (0, 0, 0.58), (0.27, 0.2, 0.2), C, tronco, base=(0.8, 0.86), bevel=0.05)
        caixa("cinto", (0, 0, 0.505), (0.25, 0.19, 0.022), T, tronco, bevel=0.007)
        nucleo(y=-0.1, z=0.595, aro=G, anel=G)
        cil("gola", (0, 0.005, 0.683), 0.095, 0.105, 0.024, G, tronco, segs=16, bevel=0.005)

    @staticmethod
    def braco(s, lado):
        C, T, G = Antigo.cores()
        om, lu = J["ombro" + lado], J["luva" + lado]
        casca("ombro_p", (s * 0.222, 0, 0.645), (0.1, 0.11, 0.095), G, om, topo=(0.85, 0.85), bevel=0.03)
        cil("braco", (s * 0.228, 0, 0.57), 0.026, 0.026, 0.10, G, om, rot=(0, s * -20, 0), segs=10)
        casca("antebraco", (s * 0.262, -0.005, 0.44), (0.11, 0.125, 0.155), C, lu, base=(1.1, 1.1), bevel=0.035)
        caixa("punho_antigo", (s * 0.262, -0.005, 0.37), (0.13, 0.145, 0.024), T, lu, bevel=0.007)
        cano(s, lado, G)
        mao(s, lado, mat=G)

    @staticmethod
    def perna(s, lado):
        C, T, G = Antigo.cores()
        jo, to = J["joelho" + lado], J["tornozelo" + lado]
        coxa(s, lado, r=0.042, mat=G)
        casca("joelho_p", (s * 0.097, -0.05, 0.262), (0.07, 0.05, 0.06), T, jo, bevel=0.018)
        casca("bota", (s * 0.10, 0.0, 0.158), (0.12, 0.14, 0.17), C, jo, base=(1.12, 1.08), bevel=0.04)
        casca("pe", (s * 0.10, -0.035, 0.045), (0.15, 0.24, 0.07), G, to, topo=(0.85, 0.8), bevel=0.025)
        sola(s, lado, comp=0.24, y=-0.035)


CONJUNTOS = {"besouro": Besouro, "gato": Gato, "urso": Urso, "cachorro": Cachorro, "caldeira": Caldeira,
             "majestade": Majestade, "lucano": Lucano, "cavaleiro": Cavaleiro, "enfermeira": Enfermeira,
             "samurai": Samurai, "marinheiro": Marinheiro, "sabre": Sabre, "solar": Solar,
             "mergulhador": Mergulhador, "antigo": Antigo}
SLOTS = ("cabeca", "tronco", "bracoE", "bracoD", "pernaE", "pernaD")


# ---------- montar: esconde a peça atual e põe a nova ----------
FEITAS = []


def repouso():
    for e in [raiz, tronco, cabeca, costas] + list(J.values()):
        e.rotation_euler = (0, 0, 0)
    raiz.location = (0, 0, 0.42)
    for j in RABO:
        j.rotation_mode = "QUATERNION"
        j.rotation_quaternion = (1, 0, 0, 0)
    atualizar()


def montar(m):
    """m: {slot: conjunto ou None (a atual)}."""
    repouso()
    for ob in FEITAS:
        bpy.data.objects.remove(ob)
    FEITAS.clear()
    RABO.clear()
    RABO_PTS.clear()
    for slot in SLOTS:
        for ob in ATUAIS.get(slot, []):
            ob.hide_render = m.get(slot) is not None
    antes = set(bpy.data.objects)
    for slot in SLOTS:
        c = m.get(slot)
        if c is None:
            continue
        if slot == "cabeca":
            c.cabeca()
        elif slot == "tronco":
            c.tronco_()
        elif slot.startswith("braco"):
            c.braco(1 if slot[-1] == "E" else -1, slot[-1])
        else:
            c.perna(1 if slot[-1] == "E" else -1, slot[-1])
    FEITAS.extend(o for o in bpy.data.objects if o not in antes)


def inteiro(c):
    return {s: c for s in SLOTS}


# ---------- poses (as mesmas do robo_v2.py) e o rabo ----------
def _angulo(v):
    return math.atan2(v.z, v.y)


def pose_rabo(modo, fase=0.0, alvo=None, sobra=0.25):
    """O que o jogo vai fazer com o rabo: 'balanco' (parado: cada gomo vira para o lado um pouco depois do
    anterior, uma onda da raiz para a ponta) e 'esticado' (correndo e voando: o primeiro gomo aponta para `alvo`,
    na base da raiz, e os outros desdobram até sobrar só `sobra` da curva, para a ponta ainda virar um pouco).
    Os gomos giram nos eixos do repouso; é assim que a junta de cada um foi criada."""
    if not RABO:
        return
    dirs = [RABO_PTS[i + 1] - RABO_PTS[i] for i in range(len(RABO))]
    for i, j in enumerate(RABO):
        j.rotation_mode = "QUATERNION"
        if modo == "balanco":
            d = dirs[i]
            eixo = Vector((0, d.z, -d.y)).normalized()
            j.rotation_quaternion = Quaternion(eixo, math.radians(20) * math.sin(fase - i * 0.8))
        elif modo == "esticado":
            if i == 0:
                ang = _angulo(Vector(alvo)) - _angulo(dirs[0])
            else:
                ang = (1 - sobra) * (_angulo(dirs[i - 1]) - _angulo(dirs[i]))
            j.rotation_quaternion = Quaternion((1, 0, 0), ang)
    atualizar()


def _basico():
    for s, lado in LADOS:
        J["pod" + lado].rotation_euler = (math.radians(14), math.radians(s * 10), 0)
    for ob in LAMINAS:
        ob.hide_render = True


def de_pe(fase=None):
    repouso()
    _basico()
    for s, lado in LADOS:
        J["cotovelo" + lado].rotation_euler = (math.radians(-12), 0, 0)
        J["luva" + lado].rotation_euler = (0, 0, math.radians(s * 90))
    for ob in CHAMAS:
        ob.hide_render = True
    if fase is not None:
        pose_rabo("balanco", fase)
    atualizar()


def correndo():
    repouso()
    _basico()
    R_ = math.radians
    raiz.rotation_euler = (R_(12), 0, 0)
    J["quadrilE"].rotation_euler = (R_(-38), 0, 0)
    J["joelhoE"].rotation_euler = (R_(22), 0, 0)
    J["quadrilD"].rotation_euler = (R_(28), 0, 0)
    J["joelhoD"].rotation_euler = (R_(55), 0, 0)
    J["ombroE"].rotation_euler = (R_(32), R_(-8), 0)
    J["ombroD"].rotation_euler = (R_(-34), R_(8), 0)
    for s, lado in LADOS:
        J["cotovelo" + lado].rotation_euler = (R_(-50), 0, 0)
        J["luva" + lado].rotation_euler = (0, 0, R_(s * 90))
    for ob in CHAMAS:
        ob.hide_render = True
    # para trás e um pouco para cima no mundo, na base da raiz inclinada 12 graus
    pose_rabo("esticado", alvo=Matrix.Rotation(R_(-12), 3, "X") @ Vector((0, 1, 0.12)))
    atualizar()


def voando():
    repouso()
    _basico()
    R_ = math.radians
    raiz.rotation_euler = (R_(72), 0, 0)
    cabeca.rotation_euler = (R_(-55), 0, 0)
    for s, lado in LADOS:
        J["ombro" + lado].rotation_euler = (R_(18), R_(-s * 14), 0)
        J["cotovelo" + lado].rotation_euler = (R_(-10), 0, 0)
        J["quadril" + lado].rotation_euler = (R_(6), R_(-s * 3), 0)
        J["joelho" + lado].rotation_euler = (R_(18), 0, 0)
        J["tornozelo" + lado].rotation_euler = (R_(40), 0, 0)
        J["aleta" + lado].rotation_euler = (0, 0, R_(-s * 55))
        J["luva" + lado].rotation_euler = (0, 0, R_(s * 90))
    for ob in CHAMAS:
        ob.hide_render = False
    pose_rabo("esticado", alvo=Matrix.Rotation(R_(-72), 3, "X") @ Vector((0, 1, 0.2)))
    atualizar()


# ---------- folhas de prova ----------
if __name__ == "__main__":
    import blf
    import imbuf
    import numpy as np

    pedidos = [k for k in os.environ.get("PECAS", "").split(",") if k] or list(CONJUNTOS)
    # ---------- para o jogo: EXPORTAR=<pasta> grava <pasta>/<conjunto>.glb ----------
    # Cada arquivo leva o esqueleto inteiro (as juntas vazias, nos mesmos lugares do robo_v2) e só as peças do
    # conjunto, cada uma presa na sua junta; o jogo (Corpo.enxertar) passa cada peça para a junta igual do robô.
    PASTA_GLB = os.environ.get("EXPORTAR_PECAS")
    if PASTA_GLB:
        os.makedirs(PASTA_GLB, exist_ok=True)

        def _do_esqueleto(ob):
            p = ob
            while p is not None and p != raiz:
                p = p.parent
            return p == raiz

        for chave in pedidos:
            montar(inteiro(CONJUNTOS[chave]))
            repouso()
            bpy.ops.object.select_all(action="DESELECT")
            for ob in scene.objects:
                if (ob.type == "EMPTY" and _do_esqueleto(ob)) or ob in FEITAS:
                    ob.select_set(True)
            saida = os.path.join(PASTA_GLB, chave + ".glb")
            # sem UV: o jogo pinta as peças pela cor do material (e o arquivo fica um quarto menor)
            bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", use_selection=True, export_apply=True,
                                      export_yup=True, export_lights=False, export_cameras=False, export_texcoords=False)
            print("exportado", saida)
        os._exit(0)

    pedidos = [k for k in os.environ.get("PECAS", "").split(",") if k] or list(CONJUNTOS)
    modo_folha = os.environ.get("FOLHA", "conjuntos")
    for d, alvo, en, tam, tinta in (((-3.0, -3.5, 3.8), (0, 0, 1.3), 600, 2.5, (1.0, 0.95, 0.88)),
                                    ((3.5, -2.5, 1.8), (0, 0, 1.3), 260, 3.0, (0.85, 0.9, 1.0)),
                                    ((0.5, 4.0, 3.5), (0, 0, 1.6), 650, 2.0, (1, 1, 1))):
        ld = bpy.data.lights.new("luz", "AREA")
        ld.energy, ld.size, ld.color = en * 0.25, tam * 0.5, tinta
        lo = bpy.data.objects.new("luz", ld)
        lo.location = tuple(c * 0.5 for c in d)
        lo.rotation_euler = (Vector(alvo) * 0.5 - Vector(d) * 0.5).to_track_quat("-Z", "Y").to_euler()
        col.objects.link(lo)
    world = bpy.data.worlds.new("estudio")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.16, 0.17, 0.18, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = PW, PH
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.eevee.taa_render_samples = 32
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    col.objects.link(cam)
    scene.camera = cam
    cam_d.lens = 100

    def foto(loc, alvo, nome):
        cam.location = loc
        cam.rotation_euler = (Vector(alvo) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        caminho = os.path.join(TMP, nome + ".png")
        scene.render.filepath = caminho
        bpy.ops.render.render(write_still=True)
        return caminho

    # ---------- retratos para a tela do cilindro: RETRATOS=<pasta> grava <pasta>/<conjunto>.png ----------
    PASTA_RET = os.environ.get("RETRATOS")
    if PASTA_RET:
        os.makedirs(PASTA_RET, exist_ok=True)
        scene.render.film_transparent = True
        scene.render.resolution_x = scene.render.resolution_y = int(320 * ESC)
        cam_d.lens = 95
        for chave in [""] + pedidos:
            montar(inteiro(CONJUNTOS[chave]) if chave else {})
            de_pe()
            cam.location = (-1.05, -2.65, 1.08)
            cam.rotation_euler = (Vector((0, 0, 0.9)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(PASTA_RET, (chave or "atual") + ".png")
            bpy.ops.render.render(write_still=True)
        os._exit(0)

    # ---------- miniaturas para a aba Corpo: MINIATURAS=<pasta> grava <pasta>/<conjunto|atual>_<vaga>.png ----------
    # Cada vaga sozinha (as outras malhas escondidas), câmera ortográfica de três quartos pela frente, do lado da vaga;
    # o tronco dos conjuntos de rabo é visto de três quartos por trás, para o rabo aparecer (§146).
    PASTA_MIN = os.environ.get("MINIATURAS")
    if PASTA_MIN:
        os.makedirs(PASTA_MIN, exist_ok=True)
        scene.render.film_transparent = True
        scene.render.resolution_x = scene.render.resolution_y = 160
        cam_d.type = "ORTHO"
        COM_RABO = {"gato", "cachorro", "sabre"}
        for chave in [""] + pedidos:
            cls = CONJUNTOS[chave] if chave else None
            for slot in SLOTS:
                montar({slot: cls} if cls else {})
                de_pe()
                mostrar = [o for o in FEITAS if o.type == "MESH"] if cls else list(ATUAIS.get(slot, []))
                guarda = {}
                for o in bpy.data.objects:
                    if o.type == "MESH":
                        guarda[o.name] = o.hide_render
                        o.hide_render = o not in mostrar
                bpy.context.view_layer.update()
                pts = []
                for o in mostrar:
                    pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
                mn = Vector((min(q.x for q in pts), min(q.y for q in pts), min(q.z for q in pts)))
                mx = Vector((max(q.x for q in pts), max(q.y for q in pts), max(q.z for q in pts)))
                lado = 0.38 if slot.endswith("E") else -0.38
                vista = Vector((lado, -1.0, 0.28))
                if slot == "tronco" and chave in COM_RABO:
                    vista = Vector((-0.75, 0.85, 0.35))
                vista.normalize()
                cam.location = (mn + mx) * 0.5 + vista * 4.0
                cam.rotation_euler = (-vista).to_track_quat("-Z", "Y").to_euler()
                cam_d.ortho_scale = max(mx - mn) * 1.18
                scene.render.filepath = os.path.join(PASTA_MIN, "%s_%s.png" % (chave or "atual", slot))
                bpy.ops.render.render(write_still=True)
                for nome_o, h in guarda.items():
                    bpy.data.objects[nome_o].hide_render = h
        os._exit(0)

    FRENTE = ((-2.6, -4.2, 1.1), (0, 0, 0.56))
    TRAS = ((1.9, 4.5, 1.3), (0, 0, 0.58))
    LADO = ((5.0, 0.4, 0.9), (0, 0.05, 0.5))
    PAINEIS = []
    if modo_folha == "rabos":
        # uma linha por conjunto de rabo: parado, balançando para um lado e para o outro (de cima, por trás),
        # correndo e voando
        COLS = 5
        CIMA = ((1.2, 3.4, 3.4), (0, 0.15, 0.48))
        VOO = ((5.0, 0.6, 1.0), (0, 0.1, 0.42))
        for chave in pedidos:
            c = CONJUNTOS[chave]
            montar(inteiro(c))
            de_pe()
            PAINEIS.append(("%s parado" % c.nome, foto(*LADO, chave + "_parado")))
            de_pe(fase=math.pi / 2)
            PAINEIS.append(("balança para um lado", foto(*CIMA, chave + "_balanco1")))
            de_pe(fase=-math.pi / 2)
            PAINEIS.append(("e para o outro", foto(*CIMA, chave + "_balanco2")))
            correndo()
            PAINEIS.append(("correndo", foto(*LADO, chave + "_correndo")))
            voando()
            PAINEIS.append(("voando", foto(*VOO, chave + "_voando")))
    elif modo_folha in ("frentes", "costas"):
        # todos numa vista só; de frente vêm também o robô atual e duas misturas de peças
        cam_ = FRENTE if modo_folha == "frentes" else TRAS
        if modo_folha == "frentes":
            montar({})
            de_pe()
            PAINEIS.append(("Atual", foto(*cam_, "atual")))
        for chave in pedidos:
            c = CONJUNTOS[chave]
            montar(inteiro(c))
            de_pe()
            PAINEIS.append((c.nome, foto(*cam_, chave + "_" + modo_folha)))
        if modo_folha == "frentes" and len(pedidos) == len(CONJUNTOS):
            K = CONJUNTOS
            for k, m in enumerate(({"cabeca": K["gato"], "tronco": K["enfermeira"], "bracoE": K["cachorro"], "bracoD": K["cachorro"],
                                    "pernaE": K["urso"], "pernaD": K["urso"]},
                                   {"cabeca": K["lucano"], "tronco": K["solar"], "bracoE": K["cavaleiro"], "bracoD": K["samurai"],
                                    "pernaE": K["besouro"], "pernaD": K["besouro"]})):
                montar(m)
                de_pe()
                PAINEIS.append(("Misturado", foto(*cam_, "mistura%d" % k)))
        COLS = (len(PAINEIS) + 1) // 2
    else:
        # colunas: os conjuntos (até 5 por bloco); em cada bloco, uma linha de frente e outra de costas
        COLS = min(5, len(pedidos))
        for b0 in range(0, len(pedidos), COLS):
            bloco = pedidos[b0:b0 + COLS]
            for vista, cam_ in (("frente", FRENTE), ("costas", TRAS)):
                for chave in bloco:
                    c = CONJUNTOS[chave]
                    montar(inteiro(c))
                    de_pe()
                    PAINEIS.append((c.nome if vista == "frente" else c.nome + " (costas)", foto(*cam_, chave + "_" + vista)))
                for _ in range(COLS - len(bloco)):
                    PAINEIS.append(("", None))

    LIN = (len(PAINEIS) + COLS - 1) // COLS
    G, TOPO = int(16 * ESC), int(46 * ESC)
    W = COLS * PW + (COLS + 1) * G
    H = LIN * (PH + TOPO + G) + G
    tela = np.zeros((H, W, 4), np.float32)
    tela[..., :3] = (0.09, 0.10, 0.11)
    tela[..., 3] = 1
    for k, (_, png) in enumerate(PAINEIS):
        if png is None:
            continue
        im = bpy.data.images.load(png)
        px = np.array(im.pixels[:], np.float32).reshape(PH, PW, 4)
        c, r = k % COLS, k // COLS
        x0 = G + c * (PW + G)
        y0 = G + (LIN - 1 - r) * (PH + TOPO + G)
        tela[y0:y0 + PH, x0:x0 + PW] = px
    out = bpy.data.images.new("folha", W, H, alpha=False)
    out.pixels[:] = tela.ravel()
    out.filepath_raw = SAIDA
    out.file_format = "PNG"
    out.save()
    ib = imbuf.load(SAIDA)
    fb = blf.load("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
    with blf.bind_imbuf(fb, ib):
        for k, (rot, _) in enumerate(PAINEIS):
            c, r = k % COLS, k // COLS
            blf.size(fb, int(22 * ESC))
            blf.color(fb, 0.95, 0.95, 0.92, 1)
            blf.position(fb, G + c * (PW + G), G + (LIN - 1 - r) * (PH + TOPO + G) + PH + int(14 * ESC), 0)
            blf.draw_buffer(fb, rot)
    imbuf.write(ib, filepath=SAIDA)
    print("ok", SAIDA, W, H)
