# Etapa 2 do vilarejo da terra nova (2026-11-22): a folha de estudo com quatro ideias bem diferentes dos restos
# de um pequeno vilarejo, onde morava a gente que se foi. Só a folha para o usuário escolher; nada daqui vai ao
# jogo. Formas em bloco e cor chapada (a forma final e a pintura vêm depois da escolha).
#
# O programa é o mesmo nas quatro (proposta do game design): quatro casas, a escola, a oficina dos robôs de
# ajuda, a estufa da horta, a casa de energia e a pracinha com o chafariz seco, os três postes que acendem e o
# robô de ajuda desligado no banco. Muda a arquitetura e o jeito de arrumar:
#   1 · casas de laje em volta da caixa d'água;
#   2 · socalcos de pedra descendo a encosta até o rio, com a roda d'água;
#   3 · casas redondas em roda, em volta do cata-vento;
#   4 · a oficina de telhado em dente de serra, com a fila de sobrados e a chaminé.
# Vale sem gente e sem estrada: nada de rua nem trilha, as casas ficam soltas no capim.
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
#       -P tools/arte/vilarejo_estudo.py -- [pasta de saída, padrão tools/capturas/vilarejo]
import math
import os
import random
import sys

sys.dont_write_bytecode = True  # sem __pycache__ dentro de tools/arte
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_arte as ba  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

arg = ba.argumentos()
PASTA = os.path.abspath(arg[0]) if arg else os.path.join(ba.RAIZ, "tools", "capturas", "vilarejo")
R = ba.R
ba.limpar()
# as cores em sRGB, nos números da tabela do jogo (scripts/vale/clareira.gd)
CONCRETO = ba.material("concreto", (0.47, 0.46, 0.43), rug=0.9)
TINTA = ba.material("tinta_velha", (0.30, 0.165, 0.13), rug=0.8)
LATA_VERDE = ba.material("lata_verde", (0.18, 0.27, 0.19), metal=0.3)
LATA_AZUL = ba.material("lata_azul", (0.15, 0.24, 0.31), metal=0.3)
LATA_OCRE = ba.material("lata_ocre", (0.42, 0.31, 0.13), metal=0.3)
VIDRO = ba.material("vidro_velho", (0.30, 0.46, 0.44), rug=0.25)
JUNTA = ba.material("junta", (0.05, 0.055, 0.06))
MUSGO = ba.material("musgo", (0.13, 0.26, 0.08), rug=0.95)
PEDRA = ba.material("rocha", (0.33, 0.34, 0.37), rug=0.9)
MADEIRA = ba.material("madeira_deriva", (0.33, 0.30, 0.27), rug=0.9)
TRONCO = ba.material("tronco", (0.17, 0.12, 0.085), rug=0.9)
CASCA = ba.material("casca_clara", (0.70, 0.68, 0.60), rug=0.9)
PINHO = ba.material("folha_escura", (0.05, 0.16, 0.10), rug=0.9)
ALAMO = ba.material("q_folha_amarela", (0.58, 0.46, 0.12), rug=0.9)
TERRA = ba.material("_terreno", (0.09, 0.13, 0.06), rug=0.95)
AGUA = ba.material("_agua", (0.10, 0.22, 0.28), rug=0.2)
ROBO_AJUDA = ba.material("tinta_branca", (0.44, 0.43, 0.40), rug=0.7)
E_ = 0.25  # espessura das paredes


def no(nome, pos=(0, 0, 0), giro=0.0, pai=None):
    """Um nó vazio: o lugar e o giro de uma casa ou de uma ideia inteira."""
    e = bpy.data.objects.new(nome, None)
    ba.cena().collection.objects.link(e)
    e.location = pos
    e.rotation_euler = (0, 0, R(giro))
    if pai:
        e.parent = pai
    return e


def parede(nome, comp, alt, pos, giro, mat, pai, furos=(), quebras=()):
    """Uma parede de `comp` m (no X dela) e `alt` m, com furos [(x, z do pé, largura, altura)] e quebras na borda
    de cima [(x, largura, fundo, inclinação)]."""
    w = ba.caixa(nome, (comp, E_, alt), pos=pos, rot=(0, 0, giro), mat=mat, chanfro=0.03, segs=2, pai=pai,
                 base=True)
    for i, (x, z0, lg, a) in enumerate(furos):
        ba.recorte(w, ba.caixa(nome + "_f%d" % i, (lg, E_ * 4, a), pos=(x, 0, z0 + a / 2), chanfro=0.0, pai=w))
    for i, (x, lg, f, inc) in enumerate(quebras):
        ba.recorte(w, ba.caixa(nome + "_q%d" % i, (lg, E_ * 4, f * 2), pos=(x, 0, alt), rot=(0, inc, 0),
                               chanfro=0.0, pai=w))
    return w


def _quebras(rnd, comp, alt, chance):
    q = []
    while rnd.random() < chance and len(q) < 2:
        q.append((rnd.uniform(-comp * 0.35, comp * 0.35), rnd.uniform(1.2, comp * 0.45), rnd.uniform(0.5, alt * 0.45),
                  rnd.uniform(-35, 35)))
    return q


def caixa_de_casa(nome, pos, giro, tam, mat, pai, semente, quebra=0.5, porta=1.0, andares=1):
    """Quatro paredes com porta na frente (-Y) e janelas vazadas; a borda de cima quebrada aqui e ali. Devolve o
    nó da casa (origem no meio do chão)."""
    rnd = random.Random(semente)
    L, F, A = tam
    r = no(nome, pos, giro, pai)
    pe = 0.9 if andares == 1 else 0.9
    jan = []
    for k in range(andares):
        z = pe + k * 2.9
        jan.append(z)
    xp = rnd.uniform(-L * 0.2, L * 0.2)
    furos_f = [(xp, 0.0, porta, 2.1)] + [(x, z, 1.1, 1.1) for z in jan[1:] for x in (-L * 0.25, L * 0.25)]
    if L > 4.5:
        furos_f.append((xp + (1.6 if xp < 0 else -1.6), jan[0], 1.1, 1.1))
    parede(nome + "_frente", L, A, (0, -F / 2 + E_ / 2, 0), 0, mat, r, furos_f, _quebras(rnd, L, A, quebra))
    parede(nome + "_costas", L, A, (0, F / 2 - E_ / 2, 0), 180, mat, r,
           [(x, z, 1.1, 1.1) for z in jan for x in (-L * 0.22, L * 0.22)], _quebras(rnd, L, A, quebra))
    for s in (-1, 1):
        parede(nome + "_lado%d" % s, F - 2 * E_, A, (s * (L / 2 - E_ / 2), 0, 0), 90 * s, mat, r,
               [(0, z, 1.1, 1.1) for z in jan], _quebras(rnd, F, A, quebra))
    return r


def laje(nome, L, F, A, estado, pai, mat=CONCRETO):
    """O teto chato: inteira, meia (metade de pé, metade caída lá dentro) ou caida (inteira, apoiada no chão)."""
    if estado == "inteira":
        return [ba.caixa(nome, (L + 0.3, F + 0.3, 0.22), pos=(0, 0, A), mat=mat, chanfro=0.03, pai=pai, base=True)]
    if estado == "meia":
        return [ba.caixa(nome + "_a", (L + 0.3, F * 0.5, 0.22), pos=(0, F * 0.25 + 0.15, A), mat=mat, pai=pai,
                         base=True),
                ba.caixa(nome + "_b", (L - 0.6, F * 0.55, 0.22), pos=(0, -F * 0.12, A * 0.5), rot=(-38, 4, 0),
                         mat=mat, pai=pai)]
    if estado == "caida":
        return [ba.caixa(nome, (L - 0.7, F - 0.7, 0.22), pos=(0, 0.3, A * 0.4), rot=(-24, 6, 0), mat=mat, pai=pai)]
    return []


def prisma(nome, larg, fundo, alt, pos, rot=(0, 0, 0), mat=None, pai=None):
    """Prisma de seção triangular: base `larg` em X, ponta `alt` m acima, comprido `fundo` em Y (a empena)."""
    bm = bmesh.new()
    pts = [(-larg / 2, 0), (larg / 2, 0), (0, alt)]
    a = [bm.verts.new((x, -fundo / 2, z)) for x, z in pts]
    b = [bm.verts.new((x, fundo / 2, z)) for x, z in pts]
    bm.faces.new(a[::-1])
    bm.faces.new(b)
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return ba._objeto(nome, bm, mat, pai, 0.03, 2, pos, rot)


def duas_aguas(nome, L, F, A, estado, pai, mat=TINTA, parede_mat=PEDRA, inclinacao=34.0):
    """Telhado de duas águas com a cumeeira em X e as empenas nas paredes do lado. estado: inteiro, meio (uma
    água caiu), aberto (só as empenas e uma viga)."""
    a = R(inclinacao)
    h = (F / 2) * math.tan(a)
    for s in (-1, 1):
        prisma(nome + "_empena%d" % s, F, E_, h, (s * (L / 2 - E_ / 2), 0, A), rot=(0, 0, 90), mat=parede_mat, pai=pai)
    ba.caixa(nome + "_cumeeira", (L + 0.4, 0.2, 0.2), pos=(0, 0, A + h), mat=MADEIRA, chanfro=0.02, pai=pai)
    lado = (F / 2) / math.cos(a) + 0.35
    aguas = {"inteiro": (-1, 1), "meio": (1,), "aberto": ()}[estado]
    for s in aguas:
        ba.caixa(nome + "_agua%d" % s, (L + 0.5, lado, 0.14), pos=(0, s * F / 4, A + h / 2 + 0.1),
                 rot=(s * inclinacao, 0, 0), mat=mat, chanfro=0.02, pai=pai)
    if estado == "meio":  # a água que caiu, apoiada lá dentro
        ba.caixa(nome + "_caida", (L - 0.6, lado * 0.9, 0.14), pos=(0, -F * 0.18, A * 0.45), rot=(-52, 5, 0),
                 mat=mat, pai=pai)


def pinheiro(nome, pos, alt, pai):
    ba.cilindro(nome + "_tronco", alt * 0.035, alt * 0.35, pos=pos, mat=TRONCO, base=True, lados=8, pai=pai)
    for k in range(3):
        r = alt * (0.26 - k * 0.06)
        ba.cilindro(nome + "_copa%d" % k, r, alt * 0.42, pos=(pos[0], pos[1], pos[2] + alt * (0.18 + k * 0.24)),
                    raio_topo=0.05, mat=PINHO, base=True, lados=9, pai=pai)


def alamo(nome, pos, alt, pai):
    ba.cilindro(nome + "_tronco", alt * 0.03, alt * 0.55, pos=pos, mat=CASCA, base=True, lados=8, pai=pai)
    ba.esfera(nome + "_copa", alt * 0.2, pos=(pos[0], pos[1], pos[2] + alt * 0.62), escala=(1.0, 1.0, 1.9),
              mat=ALAMO, gomos=10, aneis=7, pai=pai)


def mata(prefixo, centro, raio, n, semente, pai, alamos=0.4, fora=0.0):
    """Árvores soltas num anel (de `fora` até `raio` do centro)."""
    rnd = random.Random(semente)
    for k in range(n):
        ang = rnd.uniform(0, math.tau)
        d = rnd.uniform(fora, raio)
        p = (centro[0] + math.cos(ang) * d, centro[1] + math.sin(ang) * d, centro[2] if len(centro) > 2 else 0.0)
        if rnd.random() < alamos:
            alamo("%s_%d" % (prefixo, k), p, rnd.uniform(8, 13), pai)
        else:
            pinheiro("%s_%d" % (prefixo, k), p, rnd.uniform(9, 16), pai)


def poste(nome, pos, pai):
    """O poste da praça que acende quando o robô passa rente."""
    ba.cilindro(nome, 0.09, 4.2, pos=pos, mat=JUNTA, base=True, lados=10, pai=pai)
    ba.caixa(nome + "_braco", (0.7, 0.08, 0.08), pos=(pos[0] + 0.3, pos[1], pos[2] + 4.1), mat=JUNTA, pai=pai)
    ba.caixa(nome + "_lampada", (0.32, 0.32, 0.22), pos=(pos[0] + 0.62, pos[1], pos[2] + 3.92), mat=LATA_OCRE,
             pai=pai)


def chafariz(nome, pos, pai):
    ba.cilindro(nome + "_bacia", 1.9, 0.55, pos=pos, mat=CONCRETO, base=True, lados=28, pai=pai)
    ba.recorte(bpy.data.objects[nome + "_bacia"], ba.cilindro(nome + "_oco", 1.65, 0.6,
                                                              pos=(pos[0], pos[1], pos[2] + 0.2), base=True, pai=pai))
    ba.cilindro(nome + "_coluna", 0.22, 1.5, pos=pos, mat=CONCRETO, base=True, lados=12, pai=pai)
    ba.cilindro(nome + "_prato", 0.7, 0.14, pos=(pos[0], pos[1], pos[2] + 1.45), mat=CONCRETO, base=True, pai=pai)


def banco_e_robo(nome, pos, giro, pai):
    """O banco da praça com o robô de ajuda desligado, sentado, com musgo no alto (só o volume, no estudo)."""
    b = no(nome, pos, giro, pai)
    ba.caixa(nome + "_assento", (1.9, 0.55, 0.08), pos=(0, 0, 0.45), mat=MADEIRA, pai=b)
    ba.caixa(nome + "_encosto", (1.9, 0.08, 0.5), pos=(0, 0.26, 0.75), rot=(-10, 0, 0), mat=MADEIRA, pai=b)
    for s in (-1, 1):
        ba.caixa(nome + "_pe%d" % s, (0.08, 0.5, 0.45), pos=(s * 0.85, 0, 0), mat=JUNTA, base=True, pai=b)
    ba.caixa(nome + "_robo_corpo", (0.55, 0.42, 0.62), pos=(0.3, 0.02, 0.49), rot=(-8, 0, 6), mat=ROBO_AJUDA,
             base=True, pai=b)
    ba.esfera(nome + "_robo_cabeca", 0.22, pos=(0.36, -0.02, 1.28), rot=(20, 0, 15), mat=ROBO_AJUDA, pai=b)
    ba.esfera(nome + "_robo_musgo", 0.2, pos=(0.38, 0.0, 1.38), escala=(1.1, 1.1, 0.45), mat=MUSGO, pai=b)


def estufa(nome, pos, giro, pai, L=9.0, F=4.5, A=2.4, semente=0):
    """A estufa da horta: armação de ferro e quase todo o vidro quebrado; canteiros dentro e fora."""
    rnd = random.Random(semente)
    r = no(nome, pos, giro, pai)
    ba.caixa(nome + "_mureta", (L, F, 0.5), mat=CONCRETO, base=True, pai=r)
    ba.recorte(bpy.data.objects[nome + "_mureta"], ba.caixa(nome + "_mureta_oco", (L - 0.4, F - 0.4, 1.0),
                                                            pos=(0, 0, 0.3), base=True, pai=r))
    n = int(L / 1.5)
    for k in range(n + 1):
        x = -L / 2 + k * L / n
        for s in (-1, 1):
            ba.caixa(nome + "_pilar%d_%d" % (k, s), (0.08, 0.08, A), pos=(x, s * F / 2, 0.5), mat=JUNTA, base=True,
                     pai=r)
        ba.caixa(nome + "_arco%d" % k, (0.08, F, 0.08), pos=(x, 0, A + 1.25), mat=JUNTA, pai=r)
        for s in (-1, 1):
            ba.caixa(nome + "_caibro%d_%d" % (k, s), (0.08, F * 0.56, 0.08), pos=(x, s * F * 0.25, A + 0.95),
                     rot=(-s * 32, 0, 0), mat=JUNTA, pai=r)
    for k in range(n):
        if rnd.random() < 0.3:  # o pouco vidro que sobrou
            s = rnd.choice((-1, 1))
            ba.caixa(nome + "_vidro%d" % k, (L / n - 0.1, F * 0.54, 0.03), pos=(-L / 2 + (k + 0.5) * L / n,
                                                                              s * F * 0.25, A + 0.95),
                     rot=(-s * 32, 0, 0), mat=VIDRO, pai=r)
    for k in range(3):
        ba.esfera(nome + "_mato%d" % k, rnd.uniform(0.6, 1.0), pos=(rnd.uniform(-L / 3, L / 3), rnd.uniform(-1, 1), 0.6),
                  escala=(1.4, 1.0, 0.8), mat=MUSGO, gomos=10, aneis=6, pai=r)
    return r


def canteiros(nome, pos, giro, n, pai):
    r = no(nome, pos, giro, pai)
    for k in range(n):
        ba.caixa(nome + "_%d" % k, (1.2, 5.0, 0.35), pos=(k * 1.9, 0, 0), mat=MADEIRA, base=True, pai=r)
        ba.esfera(nome + "_mato%d" % k, 0.55, pos=(k * 1.9, 0, 0.45), escala=(1.0, 4.0, 0.7), mat=MUSGO, gomos=8,
                  aneis=6, pai=r)
    return r


def paineis(nome, pos, giro, n, pai, caidos=(1,)):
    """Uma fileira de painéis solares em armação; os de `caidos` estão no chão."""
    r = no(nome, pos, giro, pai)
    for k in range(n):
        x = k * 1.9
        if k in caidos:
            ba.caixa(nome + "_%d" % k, (1.7, 1.1, 0.05), pos=(x, -0.6, 0.25), rot=(70, 0, 12), mat=LATA_AZUL, pai=r)
            continue
        ba.caixa(nome + "_pe%d" % k, (0.08, 0.08, 1.0), pos=(x, 0.4, 0), mat=JUNTA, base=True, pai=r)
        ba.caixa(nome + "_%d" % k, (1.7, 1.1, 0.05), pos=(x, 0, 0.95), rot=(30, 0, 0), mat=LATA_AZUL, pai=r)
    return r


IDEIAS = []  # (raiz, título, centro, câmera do chão, alvo do chão)

# ================================================================ 1 · casas de laje em volta da caixa d'água
g = no("ideia1", (0, 0, 0))
# a caixa d'água no meio da praça: o marco que se vê do voo
for sx in (-1, 1):
    for sy in (-1, 1):
        ba.caixa("cx_perna%d%d" % (sx, sy), (0.55, 0.55, 14.0), pos=(sx * 1.8, sy * 1.8, 0), mat=CONCRETO, base=True,
                 topo=(0.75, 0.75), pai=g)
for z in (5.0, 10.0):
    for k, (dx, dy, rz) in enumerate(((0, -1.6, 0), (0, 1.6, 0), (-1.6, 0, 90), (1.6, 0, 90))):
        ba.caixa("cx_cinta%d_%d" % (k, z), (3.8, 0.3, 0.3), pos=(dx, dy, z), rot=(0, 0, rz), mat=CONCRETO, pai=g)
ba.cilindro("cx_tanque", 3.0, 3.6, pos=(0, 0, 14.0), mat=CONCRETO, base=True, lados=32, pai=g)
ba.cilindro("cx_tampa", 3.2, 1.0, pos=(0, 0, 17.6), raio_topo=0.4, mat=LATA_VERDE, base=True, lados=32, pai=g)
ba.caixa("cx_escada", (0.5, 0.06, 17.6), pos=(0, -3.05, 0), rot=(-3, 0, 0), mat=JUNTA, base=True, pai=g)
ba.cilindro("praca1_borda", 10.0, 0.35, mat=CONCRETO, base=True, lados=48, pai=g)
ba.recorte(bpy.data.objects["praca1_borda"], ba.cilindro("praca1_oco", 9.6, 1.0, pos=(0, 0, -0.2), base=True, pai=g))
chafariz("chafariz1", (5.0, -4.0, 0), g)
for k, a in enumerate((30, 150, 270)):
    poste("poste1_%d" % k, (math.cos(R(a)) * 7.5, math.sin(R(a)) * 7.5, 0), g)
banco_e_robo("banco1", (-5.5, -4.5, 0), 40, g)
# as casas soltas em volta, cada uma virada mais ou menos para a praça
CASAS1 = [  # nome, ângulo, distância, tamanho, teto, painéis
    ("escola1", 250, 27, (10.0, 7.0, 3.2), "meia", True),
    ("oficina1", 320, 30, (9.0, 8.0, 3.6), "inteira", True),
    ("casa1a", 20, 26, (6.0, 6.5, 3.0), "caida", False),
    ("casa1b", 80, 31, (6.5, 6.0, 3.0), "inteira", True),
    ("casa1c", 135, 25, (5.5, 6.5, 3.0), "", False),
    ("casa1d", 185, 32, (6.0, 7.0, 3.0), "meia", False),
]
for k, (nome, ang, d, tam, teto, pn) in enumerate(CASAS1):
    p = (math.cos(R(ang)) * d, math.sin(R(ang)) * d, 0)
    giro = ang + 90 + random.Random(k).uniform(-18, 18)
    c = caixa_de_casa(nome, p, giro, tam, CONCRETO, g, k, porta=3.0 if nome.startswith("oficina") else 1.0)
    laje(nome + "_laje", tam[0], tam[1], tam[2], teto, c)
    if pn and teto == "inteira":
        paineis(nome + "_painel", (-tam[0] / 2 + 1.0, 0.5, tam[2] + 0.22), 0, int(tam[0] / 2.2), c, caidos=(1,))
    if teto in ("", "caida"):
        pinheiro(nome + "_arvore", (0.6, 0.8, 0), 11.0, c)  # a árvore que cresceu dentro
estufa("estufa1", (36, -20, 0), 35, g, semente=1)
canteiros("canteiros1", (26, -30, 0), 35, 4, g)
paineis("energia1", (-32, 22, 0), -30, 6, g, caidos=(2, 4))
mata("mata1", (0, 0, 0), 55, 22, 11, g, alamos=0.45, fora=38)
IDEIAS.append((g, "1 · Casas de laje e a caixa d'água", Vector((0, 0, 0)), (6.0, -18.0, 1.6), (0, 2, 5.5),
               (2.0, -12.0, 0)))

# ================================================================ 2 · socalcos de pedra até o rio, com a roda d'água
g = no("ideia2", (300, 0, 0))
DEGRAUS = [(-22, 2.5), (-6, 5.0), (10, 7.5)]  # onde cada degrau começa (y, antes da curva) e a altura dele


def curva(x):
    """Quanto a linha de nível foge da reta em x: os socalcos seguem a encosta."""
    return 4.0 * math.sin(x / 19.0) + 1.8 * math.sin(x / 7.5 + 1.3)


def rio_y(x):
    return -34.0 + 3.0 * math.sin(x / 23.0 + 0.6)


def chao2(x, y):
    yy = y - curva(x)
    h = 0.0
    for y0, hk in DEGRAUS:
        if yy >= y0:
            h = hk
    if yy > 26:
        h = 7.5 + (yy - 26) * 0.09
    if abs(y - rio_y(x)) < 6.5:  # o leito do rio
        h = -0.9
    return h


bm = bmesh.new()
NX, NY = 140, 110
vs = [[bm.verts.new((-70 + i, -50 + j, chao2(-70 + i, -50 + j))) for i in range(NX + 1)] for j in range(NY + 1)]
for j in range(NY):
    for i in range(NX):
        bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
t = ba._objeto("terreno2", bm, TERRA, g, 0.0, 1, (0, 0, 0), (0, 0, 0))
t["terreno"] = True
t["liso"] = True
agua = ba.caixa("agua2", (140, 110, 0.1), pos=(0, 5, -0.35), mat=AGUA, chanfro=0.0, pai=g)
agua["terreno"] = True
# os muros de arrimo seguem a curva em pedaços de 6 m; alguns caíram
rnd = random.Random(21)
for k, (y0, hk) in enumerate(DEGRAUS):
    baixo = 0.0 if k == 0 else DEGRAUS[k - 1][1]
    for i in range(18):
        x0, x1 = -54 + i * 6, -48 + i * 6
        if rnd.random() < 0.12:
            continue  # caiu
        p0, p1 = Vector((x0, y0 + curva(x0))), Vector((x1, y0 + curva(x1)))
        meio = (p0 + p1) / 2
        ang = math.degrees(math.atan2(p1.y - p0.y, p1.x - p0.x))
        alt = hk - baixo + 0.7 - (rnd.uniform(0.3, 1.4) if rnd.random() < 0.3 else 0.0)
        ba.caixa("arrimo%d_%d" % (k, i), ((p1 - p0).length + 0.3, 0.7, alt), pos=(meio.x, meio.y - 0.2, baixo),
                 rot=(0, 0, ang), mat=PEDRA, chanfro=0.05, base=True, pai=g)


def no_degrau(k, x, dy=0.0):
    """Um ponto no meio do degrau k (0 a 2), em x, com o chão dele."""
    y0 = DEGRAUS[k][0]
    y1 = DEGRAUS[k + 1][0] if k + 1 < len(DEGRAUS) else 26
    return (x, (y0 + y1) / 2 + curva(x) + dy, DEGRAUS[k][1])


# a casa de energia na margem, com a roda d'água parada no canal
xe = 14
ce = caixa_de_casa("energia2", (xe, rio_y(xe) + 9.5, 0), 0, (4.5, 4.0, 3.2), CONCRETO, g, 31, quebra=0.2)
laje("energia2_laje", 4.5, 4.0, 3.2, "inteira", ce)
yr = rio_y(xe) + 6.3
ba.cilindro("roda2", 2.6, 0.5, pos=(xe, yr, 1.2), rot=(0, 90, 0), mat=MADEIRA, lados=24, pai=g)
ba.recorte(bpy.data.objects["roda2"], ba.cilindro("roda2_oco", 2.1, 1.0, pos=(xe, yr, 1.2), rot=(0, 90, 0), pai=g))
for k in range(8):
    ba.caixa("roda2_pa%d" % k, (0.5, 0.12, 5.0), pos=(xe, yr, 1.2), rot=(k * 22.5, 0, 0), mat=MADEIRA, pai=g)
CASAS2 = [  # nome, degrau, x, giro, tamanho, telhado
    ("casa2a", 0, -30, 4, (6.0, 5.5, 2.8), "meio"),
    ("casa2b", 0, -12, -6, (5.5, 5.0, 2.8), "aberto"),
    ("escola2", 1, -24, 3, (10.0, 6.5, 3.1), "meio"),
    ("casa2c", 1, 16, -8, (6.0, 5.5, 2.8), "inteiro"),
    ("oficina2", 2, -4, 2, (9.0, 7.0, 3.6), "meio"),
    ("casa2d", 2, 24, 7, (5.5, 5.5, 2.8), "aberto"),
]
for k, (nome, dg, x, giro, tam, tel) in enumerate(CASAS2):
    c = caixa_de_casa(nome, no_degrau(dg, x, 1.5), giro + math.degrees(math.atan(math.cos(x / 19.0) * 4 / 19.0)),
                      tam, PEDRA, g, 40 + k, quebra=0.35, porta=3.0 if nome.startswith("oficina") else 1.0)
    duas_aguas(nome + "_tel", tam[0], tam[1], tam[2], tel, c)
    if tel == "aberto":
        alamo(nome + "_arvore", (0.4, 0.3, 0), 10.0, c)
# a pracinha no degrau do meio
chafariz("chafariz2", no_degrau(1, 2, -1.0), g)
for k, x in enumerate((-6, 2, 10)):
    poste("poste2_%d" % k, no_degrau(1, x, -4.5 if k != 1 else 4.5), g)
banco_e_robo("banco2", no_degrau(1, 6.5, -4.0), 0, g)
estufa("estufa2", no_degrau(0, 26, 0.5), -4, g, semente=2)
canteiros("canteiros2", no_degrau(0, -4, -2.0), 90, 3, g)
for k in range(10):  # álamos na beira do rio, pinheiros no alto
    x = -50 + k * 11 + random.Random(k).uniform(-3, 3)
    alamo("alamo2_%d" % k, (x, rio_y(x) + random.Random(k + 9).choice((-8.5, 8.5)), 0), random.Random(k).uniform(9, 12),
          g)
mata("mata2", (0, 48, 9.5), 48, 18, 12, g, alamos=0.1, fora=8)
IDEIAS.append((g, "2 · Socalcos de pedra até o rio", Vector((300, 0, 4)), (300.5, -34.0, 2.2), (301, 2, 6.0),
               (300.0, -24.0, 0)))

# ================================================================ 3 · casas redondas em roda, em volta do cata-vento
g = no("ideia3", (600, 0, 0))


def casa_redonda(nome, pos, giro, raio, alt, teto, pai, semente, porta=1.0):
    rnd = random.Random(semente)
    r = no(nome, pos, giro, pai)
    m = ba.cilindro(nome + "_muro", raio, alt, mat=CONCRETO, base=True, lados=28, chanfro=0.03, pai=r)
    ba.recorte(m, ba.cilindro(nome + "_oco", raio - E_, alt + 1, pos=(0, 0, -0.5), base=True, pai=r))
    ba.recorte(m, ba.caixa(nome + "_porta", (porta, 1.5, 2.1), pos=(0, -raio, 1.05), pai=r))
    for k, a in enumerate((60, 140, 220, 300)):
        ba.recorte(m, ba.caixa(nome + "_jan%d" % k, (1.0, 1.5, 1.0), pos=(math.cos(R(a - 90)) * raio,
                                                                       math.sin(R(a - 90)) * raio, 1.5),
                               rot=(0, 0, a), pai=r))
    if rnd.random() < 0.7:
        ba.recorte(m, ba.caixa(nome + "_quebra", (rnd.uniform(2, 3.5), 2.0, 1.6),
                               pos=(math.cos(R(rnd.uniform(0, 360))) * raio, math.sin(R(rnd.uniform(0, 360))) * raio,
                                    alt), rot=(0, rnd.uniform(-30, 30), rnd.uniform(0, 180)), pai=r))
    if teto == "inteiro":
        ba.cilindro(nome + "_teto", raio + 0.5, raio * 0.75, pos=(0, 0, alt), raio_topo=0.15, mat=TINTA, base=True,
                    lados=28, pai=r)
    elif teto == "caido":
        ba.cilindro(nome + "_teto", raio + 0.4, raio * 0.75, pos=(0.5, 0.6, alt * 0.35), rot=(28, -12, 0),
                    raio_topo=0.15, mat=TINTA, base=True, lados=28, pai=r)
    else:
        pinheiro(nome + "_arvore", (0.3, 0.2, 0), 12.0, r)
    return r


ba.cilindro("praca3_borda", 11.0, 0.35, mat=CONCRETO, base=True, lados=56, pai=g)
ba.recorte(bpy.data.objects["praca3_borda"], ba.cilindro("praca3_oco", 10.6, 1.0, pos=(0, 0, -0.2), base=True, pai=g))
# o cata-vento de eixo em pé no meio da praça, com uma pá caída no chão
ba.cilindro("catavento_mastro", 0.36, 20.0, mat=CONCRETO, base=True, lados=16, pai=g, raio_topo=0.24)
for k in range(3):
    a = R(k * 120)
    if k == 2:
        ba.caixa("catavento_pa_caida", (0.16, 0.8, 9.0), pos=(4.5, -5.0, 0.2), rot=(84, 0, 40), mat=LATA_OCRE, pai=g)
    else:
        ba.caixa("catavento_pa%d" % k, (0.16, 0.8, 9.0), pos=(math.cos(a) * 2.2, math.sin(a) * 2.2, 14.5),
                 rot=(0, 0, k * 120 + 90), mat=LATA_OCRE, pai=g)
    for z in (10.5, 18.5):
        ba.caixa("catavento_braco%d_%d" % (k, int(z)), (2.2, 0.12, 0.12),
                 pos=(math.cos(a) * 1.1, math.sin(a) * 1.1, z), rot=(0, 0, k * 120), mat=JUNTA, pai=g)
for k, a in enumerate((90, 210, 330)):
    poste("poste3_%d" % k, (math.cos(R(a)) * 8.0, math.sin(R(a)) * 8.0, 0), g)
banco_e_robo("banco3", (math.cos(R(30)) * 7.0, math.sin(R(30)) * 7.0, 0), 30 + 90, g)
CASAS3 = [  # nome, ângulo, raio, altura, teto
    ("escola3", 270, 5.0, 3.0, "caido"), ("oficina3", 330, 4.5, 3.4, "inteiro"), ("casa3a", 30, 3.3, 2.7, "sem"),
    ("casa3b", 80, 3.3, 2.7, "inteiro"), ("casa3c", 135, 3.5, 2.7, "caido"), ("casa3d", 190, 3.2, 2.7, "inteiro"),
]
for k, (nome, ang, raio, alt, teto) in enumerate(CASAS3):
    p = (math.cos(R(ang)) * 25, math.sin(R(ang)) * 25, 0)
    casa_redonda(nome, p, ang + 90, raio, alt, teto, g, 60 + k, porta=2.6 if nome.startswith("oficina") else 1.0)
for k in range(6):  # os canteiros em raios, entre as casas
    a = R(k * 60 + 15)
    canteiros("canteiros3_%d" % k, (math.cos(a) * 15, math.sin(a) * 15, 0), k * 60 + 15, 1, g)
estufa("estufa3", (38, 6, 0), 100, g, semente=3)
mata("mata3", (0, 0, 0), 56, 22, 13, g, alamos=0.6, fora=40)
IDEIAS.append((g, "3 · Casas redondas em volta do cata-vento", Vector((600, 0, 0)), (607.0, -24.0, 1.8),
               (600, 0, 8.0), (603.0, -14.0, 0)))

# ================================================================ 4 · a oficina em dente de serra e a fila de sobrados
g = no("ideia4", (900, 0, 0))
# o galpão: 24 x 14 m, quatro dentes de serra (um caiu), a porta grande e a chaminé
gal = caixa_de_casa("galpao4", (0, 14, 0), 180, (24.0, 14.0, 5.0), CONCRETO, g, 70, quebra=0.3, porta=5.0)
for k in range(4):
    x0 = -12 + k * 6
    if k == 2:
        ba.caixa("galpao4_dente_caido", (6.2, 13.0, 0.18), pos=(x0 + 3, 0.5, 1.6), rot=(8, 22, 0), mat=LATA_OCRE,
                 pai=gal)
        continue
    a = math.degrees(math.atan2(2.2, 6.0))
    ba.caixa("galpao4_dente%d" % k, (6.0 / math.cos(R(a)) + 0.1, 14.3, 0.18), pos=(x0 + 3, 0, 6.1), rot=(0, -a, 0),
             mat=LATA_OCRE, pai=gal)
    ba.caixa("galpao4_vidro%d" % k, (0.08, 14.0, 2.1), pos=(x0 + 6, 0, 6.05), mat=VIDRO, pai=gal)
ba.cilindro("galpao4_chamine", 0.8, 19.0, pos=(-14.5, 19, 0), raio_topo=0.55, mat=CONCRETO, base=True, lados=18,
            pai=g)
pinheiro("galpao4_arvore", (3.0, 14.5, 0), 13.0, g)  # cresceu onde o dente caiu
# a fila de sobrados, geminados, numa curva de frente para o pátio
for k in range(5):
    a = R(-24 + k * 12)
    p = (math.sin(a) * 40, -28 + (1 - math.cos(a)) * 40, 0)
    c = caixa_de_casa("sobrado4_%d" % k, p, math.degrees(a) + 180, (5.2, 7.5, 5.8), TINTA if k % 2 else CONCRETO, g,
                      80 + k, quebra=0.45, andares=2)
    laje("sobrado4_%d_laje" % k, 5.2, 7.5, 5.8, ("inteira", "", "meia", "", "caida")[k], c)
esc = caixa_de_casa("escola4", (-27, -4, 0), 75, (10.0, 7.0, 3.2), CONCRETO, g, 90)
duas_aguas("escola4_tel", 10.0, 7.0, 3.2, "meio", esc, mat=LATA_VERDE, parede_mat=CONCRETO, inclinacao=24)
estufa("estufa4", (26, -6, 0), -70, g, semente=4)
canteiros("canteiros4", (19, -16, 0), -70, 3, g)
paineis("energia4", (-12, 30, 0), 0, 8, g, caidos=(3, 6))
chafariz("chafariz4", (2, -6, 0), g)
for k, x in enumerate((-8, 2, 12)):
    poste("poste4_%d" % k, (x, -1 if k != 1 else -12, 0), g)
banco_e_robo("banco4", (6.5, -7.5, 0), -15, g)
mata("mata4", (0, 0, 0), 58, 20, 14, g, alamos=0.3, fora=42)
IDEIAS.append((g, "4 · A oficina em dente de serra e os sobrados", Vector((900, 0, 2)), (904.0, -20.0, 1.6),
               (900, 12, 6.0), (902.0, -15.0, 0)))

ba.acabar()

# ---------------------------------------------------------------- fotos
E = ba.Estudio(os.path.join(PASTA, "_paineis_estudo"), largura=1120, altura=700)
E.chao.scale = (40, 40, 1)
ba.cena().view_settings.exposure = 0.7  # o estudo é para ler a forma: mais claro que a luz do jogo
for _, _, _, _, _, onde_robo in IDEIAS:
    E.robo(pos=onde_robo)
bpy.context.view_layer.update()
TERRENO = [o for o in ba.cena().objects if o.get("terreno")]


def altura_de(raiz):
    """A altura do que está na ideia (sem terreno nem cortadores), para o tamanho de longe."""
    zs = []
    for o in raiz.children_recursive:
        if o.type == "MESH" and not o.get("terreno") and not o.get("ajudante"):
            zs += [(o.matrix_world @ Vector(c)).z for c in o.bound_box]
    return max(zs) - min(min(zs), 0.0)


linhas = [[], [], [], [], []]
for k, (raiz, titulo, c, cam_chao, alvo_chao, _) in enumerate(IDEIAS):
    n = titulo.split(" · ")[0]
    linhas[0].append(("%s · De cima" % titulo, E.foto("i%d_cima" % k, (c.x, c.y + 0.01, 160), (c.x, c.y, 0),
                                                       orto=112)))
    linhas[1].append(("%s · No voo, chegando" % n, E.foto("i%d_voo" % k, (c.x - 56, c.y - 74, c.z + 36),
                                                          (c.x, c.y, c.z + 3), lente=32)))
    linhas[2].append(("%s · Do chão, com o robô" % n, E.foto("i%d_chao" % k, cam_chao, alvo_chao, lente=24)))
    for o in TERRENO:
        o.hide_render = True
    sil = E.silhueta("i%d_sil" % k, (c.x, c.y - 420, c.z + 14), (c.x, c.y, c.z + 6), lente=110)
    for o in TERRENO:
        o.hide_render = False
    linhas[3].append(("%s · Em silhueta, de longe" % n, sil))
    linhas[4].append(("%s · A 600 m, do tamanho que o jogo mostra" % n,
                      E.longe(sil, altura_de(raiz), 600.0, nome="i%d_600m" % k)))
ba.folha([p for linha in linhas for p in linha], os.path.join(PASTA, "vilarejo_estudo.png"), colunas=4,
         titulo="Restos do vilarejo: quatro ideias (o mesmo programa: 4 casas, escola, oficina, estufa, energia e a "
                "praça com 3 postes e o robô no banco) · robô de 1,2 m em cada uma")
