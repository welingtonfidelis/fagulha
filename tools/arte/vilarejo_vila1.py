# Etapa 3 do vilarejo da terra nova (2026-11-22): a ideia 1 que o usuário escolheu na folha de estudo (casas de
# laje em volta da caixa d'água), com mais casas (nove, além da escola e da oficina) e tudo gasto pelo tempo: lajes
# pela metade com os ferros à mostra, reboco descascado, escorridos de chuva, paredes tombadas, árvores crescendo
# dentro das casas, a caixa d'água enferrujada com degraus faltando, a praça rachada com capim entre as lajotas,
# postes de luz caídos com os fios no chão. Vila pequena numa ilha: nada de prédio, nada de cidade. Os restos das
# ruas ficam só dentro da vila: o anel de asfalto em volta da praça e as ruelas até algumas casas, em placas
# rachadas e afundadas, com capim nas falhas, o meio-fio solto e os bueiros; as ruelas somem no mato.
#
# Ainda em cor chapada (a pintura vem depois da forma aprovada); nada daqui vai ao jogo. Usa peças do OpenGameArt
# baixadas em Projects/others/bibliotecas/oga-vilarejo, repintadas nas cores do jogo: a cerca de madeira e a
# grade de ferro (CC0) e o calçamento com mureta (CC-BY 3.0, twochch).
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
#       -P tools/arte/vilarejo_vila1.py -- [--pintar] [pasta de saída, padrão tools/capturas/vilarejo]
#
# Sem --pintar sai a folha da forma (vila1_forma.png). Com --pintar, cada casa e cada área vira uma malha só com a
# textura assada (sujeira, escorridos, bordas gastas), exportada em <saída>/vila1_glb/<grupo>.glb, e saem a folha
# pintada (vila1_pintura.png) e as tomadas (vila1_glb/tomadas.json) para a vitrine do jogo, tools/arte/vitrine_vila.gd.
# O mato e as árvores (ainda provisórias) e o calçamento baixado (com a textura dele) vão sem assar.
import json
import math
import os
import random
import re
import sys
import time

sys.dont_write_bytecode = True  # sem __pycache__ dentro de tools/arte
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_arte as ba  # noqa: E402
import importar_3ds  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

arg = ba.argumentos()
PINTAR = "--pintar" in arg
arg = [a for a in arg if not a.startswith("--")]
PASTA = os.path.abspath(arg[0]) if arg else os.path.join(ba.RAIZ, "tools", "capturas", "vilarejo")
OGA = os.path.join(os.path.dirname(ba.RAIZ), "bibliotecas", "oga-vilarejo")
R = ba.R
ba.limpar()

# as cores em sRGB, nos números da tabela do jogo (scripts/vale/clareira.gd) e, as novas, desbotadas de sol
CONCRETO = ba.material("concreto", (0.47, 0.46, 0.43), rug=0.9)
SUJO = ba.material("concreto_sujo", (0.25, 0.245, 0.22), rug=0.95)
TINTA = ba.material("tinta_velha", (0.36, 0.20, 0.16), rug=0.85)
AZUL = ba.material("tinta_azul_desbotada", (0.33, 0.41, 0.45), rug=0.85)
AMARELA = ba.material("tinta_amarela_desbotada", (0.58, 0.50, 0.31), rug=0.85)
VERDE = ba.material("tinta_verde_desbotada", (0.36, 0.43, 0.33), rug=0.85)
FIBRO = ba.material("fibrocimento", (0.52, 0.53, 0.52), rug=0.9)
LATA_VERDE = ba.material("lata_verde", (0.18, 0.27, 0.19), metal=0.3)
LATA_OCRE = ba.material("lata_ocre", (0.42, 0.31, 0.13), metal=0.3)
LATA_AZUL = ba.material("lata_azul", (0.15, 0.24, 0.31), metal=0.3)
FERRUGEM = ba.material("ferrugem", (0.28, 0.13, 0.07), rug=0.85)
VIDRO = ba.material("vidro_velho", (0.30, 0.46, 0.44), rug=0.25)
JUNTA = ba.material("junta", (0.05, 0.055, 0.06))
MUSGO = ba.material("musgo", (0.13, 0.26, 0.08), rug=0.95)
CAPIM = ba.material("capim_seco", (0.40, 0.37, 0.17), rug=0.95)
PEDRA = ba.material("rocha", (0.33, 0.34, 0.37), rug=0.9)
PEDRA_CLARA = ba.material("pedra_clara", (0.44, 0.43, 0.40), rug=0.9)
MADEIRA = ba.material("madeira_deriva", (0.33, 0.30, 0.27), rug=0.9)
TRONCO = ba.material("tronco", (0.17, 0.12, 0.085), rug=0.9)
CASCA = ba.material("casca_clara", (0.70, 0.68, 0.60), rug=0.9)
PINHO = ba.material("folha_escura", (0.05, 0.16, 0.10), rug=0.9)
ALAMO = ba.material("q_folha_amarela", (0.58, 0.46, 0.12), rug=0.9)
ROBO_AJUDA = ba.material("tinta_branca", (0.44, 0.43, 0.40), rug=0.7)
ASFALTO = ba.material("asfalto_velho", (0.21, 0.21, 0.205), rug=0.95)
REMENDO = ba.material("asfalto_remendo", (0.29, 0.285, 0.27), rug=0.95)
E_ = 0.25  # espessura das paredes

G = None  # o nó da vila inteira
TAM = {}  # nome da casa -> (L, F, A)
PORTA = {}  # nome da casa -> (x da porta, se tem muro na frente)
OCUPADO = []  # (x, y, raio) do que já está no chão, para o mato e o entulho não caírem dentro


# ---------------------------------------------------------------- peças básicas

def no(nome, pos=(0, 0, 0), giro=0.0, pai=None, rot=None):
    """Um nó vazio: o lugar e o giro de uma casa ou de um grupo."""
    e = bpy.data.objects.new(nome, None)
    ba.cena().collection.objects.link(e)
    e.location = pos
    e.rotation_euler = ba._rot(rot) if rot else (0, 0, R(giro))
    if pai:
        e.parent = pai
    return e


def plano(nome, pai, pts, y, mat):
    """Um polígono chapado no plano XZ (a face da parede), `y` à frente dela: mancha, reboco caído, escorrido."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z)) for x, z in pts]
    bm.faces.new(vs)
    return ba._objeto(nome, bm, mat, pai, 0.0, 0, (0, 0, 0), (0, 0, 0))


def mancha(nome, pai, x, z, rx, rz, mat, rnd, y):
    pts = []
    for k in range(10):
        a = math.tau * k / 10
        f = rnd.uniform(0.7, 1.15)
        pts.append((x + math.cos(a) * rx * f, z + math.sin(a) * rz * f))
    return plano(nome, pai, pts, y, mat)


def chapa_torta(nome, pai, cantos, mat, rnd, n=(8, 4), espessura=0.04):
    """Uma chapa de lata pelos quatro cantos (atrás-esquerda, atrás-direita, frente-direita, frente-esquerda),
    que pode ficar torcida; uma ondinha de amassado no meio."""
    a, b, c, d = [Vector(x) for x in cantos]
    bm = bmesh.new()
    vs = []
    for j in range(n[1] + 1):
        v = j / n[1]
        linha = []
        for i in range(n[0] + 1):
            u = i / n[0]
            p = (a.lerp(b, u)).lerp(d.lerp(c, u), v)
            p.z += math.sin(u * math.pi * 3.0) * 0.03 - math.sin(u * math.pi) * math.sin(v * math.pi) * 0.12
            linha.append(bm.verts.new(p))
        vs.append(linha)
    for j in range(n[1]):
        for i in range(n[0]):
            bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
    ob = ba._objeto(nome, bm, mat, pai, 0.0, 0, (0, 0, 0), (0, 0, 0))
    ba.chapa(ob, espessura)
    return ob


def ferro(nome, pai, p, d, comp, queda, rnd):
    """Um vergalhão enferrujado saindo da beira quebrada do concreto, na direção `d` (x, y), caindo na ponta."""
    x, y, z = p
    dx, dy = d
    return ba.tubo(nome, [(x - dx * 0.08, y - dy * 0.08, z),
                          (x + dx * comp * 0.6, y + dy * comp * 0.6, z + rnd.uniform(-0.03, 0.06)),
                          (x + dx * comp, y + dy * comp, z - queda)], raio=0.012, mat=FERRUGEM, curva=0.08, pai=pai,
                   passos=4)


def entulho(nome, pos, pai, rnd, n, espalha=1.2, mat=CONCRETO):
    """Uma pilha de pedaços de parede e de laje."""
    for k in range(n):
        t = (rnd.uniform(0.25, 0.7), rnd.uniform(0.2, 0.5), rnd.uniform(0.08, 0.3))
        p = (pos[0] + rnd.uniform(-espalha, espalha), pos[1] + rnd.uniform(-espalha, espalha), t[2] * 0.3)
        ba.caixa("%s_%d" % (nome, k), t, pos=p, rot=(rnd.uniform(-25, 25), rnd.uniform(-25, 25), rnd.uniform(0, 180)),
                 mat=mat, chanfro=0.02, segs=1, pai=pai)


def tufo(nome, pos, pai, rnd, alto=0.6):
    """Capim seco que cresceu nas rachaduras: um punhado de folhas finas, abertas."""
    for k in range(rnd.randint(4, 7)):
        h = alto * rnd.uniform(0.6, 1.25)
        ba.cilindro("%s_%d" % (nome, k), rnd.uniform(0.035, 0.07), h,
                    pos=(pos[0] + rnd.uniform(-0.12, 0.12), pos[1] + rnd.uniform(-0.12, 0.12), pos[2]),
                    rot=(rnd.uniform(-22, 22), rnd.uniform(-22, 22), 0), raio_topo=0.0, lados=5, chanfro=0.0,
                    mat=CAPIM, base=True, pai=pai)


def arbusto(nome, pos, pai, rnd, r=0.8):
    ba.esfera(nome, r, pos=(pos[0], pos[1], pos[2] + r * 0.35), escala=(1.3, 1.0, 0.75),
              rot=(0, 0, rnd.uniform(0, 180)), mat=MUSGO, gomos=10, aneis=6, pai=pai)


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


# ---------------------------------------------------------------- peças do OpenGameArt, repintadas

def peca_oga(rel, mat, escala=1.0):
    """Abre uma peça baixada, junta tudo numa malha só com a base no chão e o meio no zero, na escala pedida,
    pintada com `mat` (ou, com mat=None, com os materiais que vieram). Devolve a malha (para fazer cópias) ou
    None se a pasta não estiver aqui."""
    caminho = os.path.join(OGA, rel)
    if not os.path.exists(caminho):
        print("sem a peça", caminho)
        return None
    antes = set(bpy.data.objects)
    ext = rel.lower().rsplit(".", 1)[-1]
    if ext == "3ds":
        importar_3ds.importar(caminho)
    elif ext == "glb":
        bpy.ops.import_scene.gltf(filepath=caminho)
    elif ext == "obj":
        bpy.ops.wm.obj_import(filepath=caminho)
    novos = [o for o in bpy.data.objects if o not in antes]
    bpy.context.view_layer.update()
    bm = bmesh.new()
    mats = []
    for o in novos:
        if o.type != "MESH":
            continue
        tmp = bmesh.new()
        tmp.from_mesh(o.data)
        tmp.transform(o.matrix_world)
        if mat is None:  # os índices de material passam a apontar para a lista da malha juntada
            for f in tmp.faces:
                m = o.material_slots[f.material_index].material if o.material_slots else None
                if m not in mats:
                    mats.append(m)
                f.material_index = mats.index(m)
        me_tmp = bpy.data.meshes.new("_tmp")
        tmp.to_mesh(me_tmp)
        tmp.free()
        bm.from_mesh(me_tmp)  # soma à malha que já está no bmesh
        bpy.data.meshes.remove(me_tmp)
    for o in novos:
        bpy.data.objects.remove(o)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    meio = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=-meio)
    bmesh.ops.scale(bm, verts=bm.verts[:], vec=(escala, escala, escala))
    if mat is not None:
        for f in bm.faces:
            f.material_index = 0
    me = bpy.data.meshes.new(os.path.basename(rel).rsplit(".", 1)[0])
    bm.to_mesh(me)
    bm.free()
    for m in ([mat] if mat is not None else mats):
        me.materials.append(m)
    print("peça %s: %d vértices, %.2f x %.2f x %.2f m" % (rel, len(me.vertices), (max(xs) - min(xs)) * escala,
                                                         (max(ys) - min(ys)) * escala, (max(zs) - min(zs)) * escala))
    return me


def copia(nome, me, pos, rot, pai):
    ob = bpy.data.objects.new(nome, me)
    ba.cena().collection.objects.link(ob)
    ob.location = pos
    ob.rotation_euler = ba._rot(rot)
    ob.parent = pai
    ob["acabado"] = True  # a malha já vem pronta
    return ob


# ---------------------------------------------------------------- as casas

def parede(nome, comp, alt, pos, giro, mat, pai, furos=(), quebras=(), tomba=0.0):
    """Uma parede de `comp` m (no X dela) e `alt` m, com furos [(x, z do pé, largura, altura)] e quebras na borda de
    cima [(x, largura, fundo, inclinação)]. O -Y dela é sempre o lado de fora. `tomba` deita a parede para fora."""
    w = ba.caixa(nome, (comp, E_, alt), pos=pos, rot=(tomba, 0, giro), mat=mat, chanfro=0.03, segs=2, pai=pai,
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
        q.append((rnd.uniform(-comp * 0.35, comp * 0.35), rnd.uniform(1.2, comp * 0.45),
                  rnd.uniform(0.5, alt * 0.45), rnd.uniform(-35, 35)))
    return q


def gastar(w, nome, comp, alt, furos, quebras, rnd, pintada, com_teto):
    """O tempo na parede: reboco caído (mostra o concreto por baixo da tinta), escorridos de chuva embaixo da
    laje e musgo no pé."""
    y = -E_ / 2 - 0.008

    def livre(x, z, rx, rz):
        if abs(x) + rx > comp / 2 - 0.15 or z - rz < 0.15:
            return False
        if z + rz > (alt * 0.5 if quebras else alt - 0.3):
            return False
        for fx, fz, lg, a in furos:
            if abs(x - fx) < lg / 2 + rx + 0.1 and fz - rz - 0.1 < z < fz + a + rz + 0.1:
                return False
        return True

    n, tent = 0, 0
    alvo = rnd.randint(2, 4) if pintada else rnd.randint(1, 2)
    while n < alvo and tent < 60:
        tent += 1
        rx, rz = rnd.uniform(0.25, 0.85), rnd.uniform(0.18, 0.55)
        x, z = rnd.uniform(-comp / 2, comp / 2), rnd.uniform(0.3, alt - 0.3)
        if livre(x, z, rx, rz):
            mancha("%s_desc%d" % (nome, n), w, x, z, rx, rz, CONCRETO if pintada else SUJO, rnd, y)
            n += 1
    if com_teto and not quebras:
        for k in range(rnd.randint(2, 4)):
            x = rnd.uniform(-comp / 2 + 0.3, comp / 2 - 0.3)
            ce = rnd.uniform(0.7, 1.9)
            for fx, fz, lg, a in furos:  # não escorre por cima de porta e janela
                if abs(x - fx) < lg / 2 + 0.25:
                    ce = min(ce, alt - (fz + a) - 0.05)
            if ce > 0.3:
                lg = rnd.uniform(0.12, 0.35)
                plano("%s_esc%d" % (nome, k), w, [(x - lg / 2, alt - 0.01), (x + lg / 2, alt - 0.01),
                                                 (x + lg * 0.12, alt - ce), (x - lg * 0.2, alt - ce * 0.85)],
                      y - 0.003, SUJO)
    for k in range(rnd.randint(0, 2)):
        rx = rnd.uniform(0.3, 0.9)
        x = rnd.uniform(-comp / 2 + rx, comp / 2 - rx)
        if all(not (abs(x - fx) < lg / 2 + rx and fz < 0.5) for fx, fz, lg, a in furos):
            mancha("%s_musgo%d" % (nome, k), w, x, 0.1, rx, 0.24, MUSGO, rnd, y - 0.005)


def casa(nome, ang, d, tam, estado, cor, semente, extras=(), porta=1.0, xporta=None, janelas=None, desvio=None):
    """Uma casa de laje no anel em volta da praça (ângulo e distância do meio), com a porta virada para a praça.
    estado: inteira, puxadinho (laje com a obra de cima parada), alpendre (varanda caindo), meia (metade da laje
    caiu lá dentro), caida (a laje inteira caiu) ou sem_teto (sem laje, uma parede tombada e uma árvore)."""
    rnd = random.Random(semente)
    L, F, A = tam
    TAM[nome] = tam
    pos = (math.cos(R(ang)) * d, math.sin(R(ang)) * d, 0.0)
    giro = ang - 90 + (rnd.uniform(-15, 15) if desvio is None else desvio)
    r = no(nome, pos, giro, G)
    OCUPADO.append((pos[0], pos[1], max(L, F) * 0.75 + 1.0))
    mat = cor or CONCRETO
    xp = rnd.uniform(-L * 0.18, L * 0.18) if xporta is None else xporta
    PORTA[nome] = (xp, "muro" in extras)
    alto_porta = 2.1 if porta < 2 else 2.9
    if janelas is None:
        janelas = [(xp + (1.7 if xp < 0 else -1.7), 0.9, 1.1, 1.1)] if L > 4.5 else []
    furos = {"frente": [(xp, 0.0, porta, alto_porta)] + list(janelas),
             "costas": [(x, 0.9, 1.1, 1.1) for x in (-L * 0.22, L * 0.22)],
             "lado-1": [(0.0, 0.9, 1.1, 1.1)], "lado1": [(0.0, 0.9, 1.1, 1.1)]}
    chance = {"inteira": 0.0, "puxadinho": 0.0, "alpendre": 0.0, "meia": 0.6, "caida": 0.65,
              "sem_teto": 0.85}[estado]
    paredes = {"frente": (L, (0, -F / 2 + E_ / 2, 0), 0), "costas": (L, (0, F / 2 - E_ / 2, 0), 180),
               "lado-1": (F - 2 * E_, (-(L / 2 - E_ / 2), 0, 0), -90),
               "lado1": (F - 2 * E_, (L / 2 - E_ / 2, 0, 0), 90)}
    com_teto = estado in ("inteira", "puxadinho", "alpendre")
    for chave, (comp, p, gz) in paredes.items():
        # embaixo de laje a parede não quebra em cima (a laje ficaria no ar); na meia, só a frente quebra
        pode = estado in ("caida", "sem_teto") or (estado == "meia" and chave == "frente")
        q = _quebras(rnd, comp, A, chance) if pode else []
        tomba = 80.0 if estado == "sem_teto" and chave == "lado1" else 0.0
        w = parede("%s_%s" % (nome, chave), comp, A, p, gz, mat, r, furos[chave], q, tomba)
        gastar(w, "%s_%s" % (nome, chave), comp, A, furos[chave], q, rnd, cor is not None,
               com_teto or (estado == "meia" and chave == "costas"))

    # o teto
    if com_teto:
        lj = ba.caixa(nome + "_laje", (L + 0.3, F + 0.3, 0.22), pos=(0, 0, A), mat=CONCRETO, chanfro=0.03, pai=r,
                      base=True)
        qx, qy = rnd.choice((-1, 1)), rnd.choice((-1, 1))
        cx, cy = qx * (L / 2 + 0.15), qy * (F / 2 + 0.15)
        ba.recorte(lj, ba.caixa(nome + "_lasca", (1.5, 1.5, 0.8), pos=(cx, cy, A + 0.11), rot=(0, 0, 45),
                                chanfro=0.0, pai=r))
        for k, t in enumerate((0.2, 0.45, 0.7)):  # os ferros da quina lascada
            p = (cx - qx * 1.06 * (1 - t), cy - qy * 1.06 * t, A + 0.1)
            ferro("%s_ferro_q%d" % (nome, k), r, p, (qx * 0.7, qy * 0.7), rnd.uniform(0.25, 0.45),
                  rnd.uniform(0.05, 0.3), rnd)
        for k in range(rnd.randint(2, 4)):  # o mato que cresce em cima
            arbusto("%s_mato_laje%d" % (nome, k), (rnd.uniform(-L / 3, L / 3), rnd.uniform(-F / 3, F / 3), A + 0.18),
                    r, rnd, rnd.uniform(0.35, 0.7))
        for k in range(3):
            tufo("%s_capim_laje%d" % (nome, k), (rnd.uniform(-L / 2.5, L / 2.5), rnd.uniform(-F / 2.5, F / 2.5),
                                                  A + 0.22), r, rnd, 0.5)
    elif estado == "meia":
        ba.caixa(nome + "_laje_a", (L + 0.3, F * 0.5, 0.22), pos=(0, F * 0.25 + 0.15, A), mat=CONCRETO, pai=r,
                 base=True)
        caida = ba.caixa(nome + "_laje_b", (L - 0.6, F * 0.55, 0.22), pos=(0, -F * 0.12, A * 0.48),
                         rot=(-38, 5, 0), mat=CONCRETO, pai=r)
        ba.recorte(caida, ba.caixa(nome + "_laje_b_q", (1.6, 1.6, 1.0), pos=(L * 0.3, -F * 0.3, A * 0.3),
                                   rot=(0, 0, 40), chanfro=0.0, pai=r))
        x = -L / 2 + 0.2
        k = 0
        while x < L / 2 - 0.1:  # os ferros da beira quebrada, caindo
            ferro("%s_ferro%d" % (nome, k), r, (x, 0.15, A + 0.11), (0, -1), rnd.uniform(0.3, 0.75),
                  rnd.uniform(0.1, 0.55), rnd)
            x += rnd.uniform(0.28, 0.45)
            k += 1
        entulho(nome + "_entulho", (rnd.uniform(-1, 1), -F * 0.2, 0), r, rnd, 9)
        for k in range(2):
            arbusto("%s_mato_laje%d" % (nome, k), (rnd.uniform(-L / 3, L / 3), F * 0.3, A + 0.18), r, rnd, 0.45)
    elif estado == "caida":
        ba.caixa(nome + "_laje", (L - 0.7, F - 0.7, 0.22), pos=(0, 0.3, A * 0.42), rot=(-24, 6, 0), mat=CONCRETO,
                 pai=r)
        for k in range(5):  # os ferros da beira que ficou presa no alto
            ferro("%s_ferro%d" % (nome, k), r, (-L / 2 + 0.6 + k * (L - 1.2) / 4, F / 2 - 0.35, A - 0.05), (0, -1),
                  rnd.uniform(0.3, 0.6), rnd.uniform(0.2, 0.5), rnd)
        entulho(nome + "_entulho", (0, -F * 0.25, 0), r, rnd, 8)
        alamo(nome + "_arvore", (L * 0.18, -F * 0.2, 0), 7.5, r)
    elif estado == "sem_teto":
        pinheiro(nome + "_arvore", (-L * 0.1, 0.4, 0), 10.5, r)
        entulho(nome + "_entulho", (0, -0.5, 0), r, rnd, 12, espalha=1.6)
        entulho(nome + "_entulho_fora", (L / 2 + 1.2, F * 0.2, 0), r, rnd, 6)
        for k in range(4):
            tufo("%s_capim%d" % (nome, k), (rnd.uniform(-L / 3, L / 3), rnd.uniform(-F / 3, F / 3), 0), r, rnd, 0.8)

    if estado == "puxadinho":  # a obra do andar de cima, parada no meio: pilares com os ferros esperando
        z = A + 0.22
        for sx in (-1, 1):
            for sy in (-1, 1):
                px, py = sx * (L / 2 - 0.3), sy * (F / 2 - 0.3)
                h = rnd.uniform(0.9, 1.5)
                ba.caixa("%s_pilar%d%d" % (nome, sx, sy), (0.25, 0.25, h), pos=(px, py, z), mat=CONCRETO, base=True,
                         chanfro=0.015, pai=r)
                for j, (ox, oy) in enumerate(((-0.08, -0.08), (0.08, -0.08), (-0.08, 0.08), (0.08, 0.08))):
                    a = rnd.uniform(0, math.tau)
                    ba.tubo("%s_ferro_p%d%d_%d" % (nome, sx, sy, j),
                            [(px + ox, py + oy, z + h - 0.05), (px + ox, py + oy, z + h + 0.35),
                             (px + ox + math.cos(a) * 0.2, py + oy + math.sin(a) * 0.2, z + h + 0.55)],
                            raio=0.012, mat=FERRUGEM, curva=0.08, pai=r, passos=4)
        ba.caixa(nome + "_mureta", (L * 0.5, 0.15, 0.7), pos=(-L * 0.15, F / 2 - 0.3, z), mat=CONCRETO, base=True,
                 chanfro=0.01, pai=r)
        for k in range(7):  # os blocos que sobraram, empilhados
            ba.caixa("%s_bloco%d" % (nome, k), (0.39, 0.19, 0.19),
                     pos=(L * 0.2 + (k % 3) * 0.42, -F * 0.15, z + (k // 3) * 0.2), rot=(0, 0, rnd.uniform(-6, 6)),
                     mat=PEDRA_CLARA, base=True, chanfro=0.01, pai=r)
        extras = tuple(extras) + ("caixa_tombada",)
    if estado == "alpendre":  # a varanda: um pilar caiu e a telha de lata pende até perto do chão
        ba.caixa(nome + "_pilar_a", (0.2, 0.2, 2.42), pos=(-L * 0.38, -F / 2 - 2.0, 0), mat=CONCRETO, base=True,
                 pai=r)
        ba.caixa(nome + "_pilar_b", (0.2, 0.2, 2.6), pos=(L * 0.42, -F / 2 - 2.5, 0.12), rot=(0, 86, 14),
                 mat=CONCRETO, pai=r)
        x0, x1 = -L * 0.47, L * 0.2  # só a parte da esquerda sobrou; o resto voou
        chapa_torta(nome + "_telha", r, [(x0, -F / 2 + 0.05, A - 0.12), (x1, -F / 2 + 0.05, A - 0.5),
                                         (x1, -F / 2 - 2.0, 0.55), (x0, -F / 2 - 2.0, 2.45)], LATA_OCRE, rnd)
        chapa_torta(nome + "_telha_chao", r, [(L * 0.25, -F / 2 - 3.6, 0.03), (L * 0.25 + 1.6, -F / 2 - 3.2, 0.03),
                                              (L * 0.25 + 1.3, -F / 2 - 4.9, 0.25), (L * 0.25 - 0.2, -F / 2 - 5.1, 0.03)],
                    LATA_OCRE, rnd, n=(4, 4))

    # o que sobrou em volta
    if "porta_caida" in extras:
        ba.caixa(nome + "_porta", (0.85, 0.045, 2.0), pos=(xp + 0.4, -F / 2 - 1.25, 0.03),
                 rot=(90, 0, rnd.uniform(-25, 25)), mat=MADEIRA, chanfro=0.008, pai=r)
    if "janela" in extras and janelas:
        jx, jz, jl, ja = janelas[0]
        ba.moldura(nome + "_janela", jl + 0.04, ja + 0.04, 0.07, 0.06, pos=(jx + 0.15, -F / 2 - 0.12, jz + ja / 2 - 0.2),
                   rot=(10, 26, 0), mat=MADEIRA, pai=r)
    if "tabuas" in extras and janelas:
        jx, jz, jl, ja = janelas[0]
        for k, (dz, inc) in enumerate(((0.2, 6), (0.55, -5))):  # a terceira tábua caiu
            ba.caixa("%s_tabua%d" % (nome, k), (jl + 0.35, 0.035, 0.16), pos=(jx, -F / 2 - 0.03, jz + dz),
                     rot=(0, inc, 0), mat=MADEIRA, chanfro=0.006, pai=r)
        ba.caixa(nome + "_tabua_chao", (jl + 0.35, 0.035, 0.16), pos=(jx + 0.3, -F / 2 - 0.6, 0.03),
                 rot=(90, 0, 15), mat=MADEIRA, chanfro=0.006, pai=r)
    if "calha" in extras and com_teto:
        ba.tubo(nome + "_calha", [(L / 2 + 0.15, -F / 2 - 0.15, A + 0.02), (L / 2 - 1.4, -F / 2 - 0.25, A - 0.15),
                                  (L / 2 - 2.3, -F / 2 - 0.65, 0.5), (L / 2 - 2.5, -F / 2 - 0.8, 0.03)],
                raio=0.05, mat=FERRUGEM, curva=0.3, pai=r)
    if "antena" in extras and com_teto:
        an = no(nome + "_antena", (L * 0.25, F * 0.2, A + 0.22), pai=r, rot=(24, 0, 30))
        ba.cilindro(nome + "_antena_haste", 0.02, 2.2, mat=FERRUGEM, base=True, lados=6, chanfro=0.0, pai=an)
        for k in range(3):
            ba.caixa("%s_antena_v%d" % (nome, k), (0.9 - k * 0.2, 0.02, 0.02), pos=(0, 0, 1.6 + k * 0.25),
                     rot=(0, 0, k * 7), mat=FERRUGEM, chanfro=0.0, pai=an)
    if "caixa_tombada" in extras and com_teto:  # a caixa d'água pequena, de fibrocimento, deitada na laje
        ba.cilindro(nome + "_caixinha", 0.55, 0.9, pos=(-L * 0.25, F * 0.12, A + 0.22 + 0.55), rot=(90, 0, 35),
                    mat=FIBRO, lados=18, pai=r)
        ba.cilindro(nome + "_caixinha_tampa", 0.6, 0.05, pos=(-L * 0.05, -F * 0.2, A + 0.24), rot=(4, 3, 0),
                    mat=FIBRO, lados=18, pai=r)
    if "muro" in extras:  # o muro baixo da frente, quebrado, com o portão de ferro caído no vão
        ym = -F / 2 - 3.0
        lm = L + 2.0
        w = parede(nome + "_muro", lm, 1.1, (0, ym, 0), 0, cor or CONCRETO, r,
                   [(xp, 0.0, 1.3, 1.5)], [(xp + lm * 0.3, 1.6, 0.6, 20)])
        gastar(w, nome + "_muro", lm, 1.1, [(xp, 0.0, 1.3, 1.5)], [(0, 1, 1, 0)], rnd, cor is not None, False)
        g = no(nome + "_portao", (xp + 0.2, ym - 0.9, 0.04), pai=r, rot=(88, 0, 12))
        for k in range(7):
            ba.caixa("%s_portao_b%d" % (nome, k), (0.025, 0.025, 1.0), pos=(-0.6 + k * 0.2, 0, 0.5), mat=FERRUGEM,
                     chanfro=0.0, pai=g)
        for z in (0.1, 0.9):
            ba.caixa("%s_portao_t%d" % (nome, z * 10), (1.25, 0.03, 0.04), pos=(0, 0, z), mat=FERRUGEM,
                     chanfro=0.0, pai=g)
    if "carrinho" in extras:  # o carrinho de mão tombado
        c = no(nome + "_carrinho", (L / 2 + 1.5, -F / 2 - 1.0, 0.35), pai=r, rot=(0, 75, 20))
        ba.caixa(nome + "_carrinho_caixa", (0.8, 0.6, 0.3), pos=(0, 0, 0), topo=(1.2, 1.2), mat=FERRUGEM,
                 chanfro=0.01, pai=c)
        ba.cilindro(nome + "_carrinho_roda", 0.18, 0.08, pos=(0.55, 0, -0.1), rot=(90, 0, 0), mat=JUNTA, pai=c)
    if "tambores" in extras:
        bx = -L / 2 - 1.1
        for k in range(2):
            ba.cilindro("%s_tambor%d" % (nome, k), 0.3, 0.88, pos=(bx, F * 0.1 + k * 0.65, 0), mat=FERRUGEM,
                        base=True, lados=16, pai=r)
        ba.cilindro(nome + "_tambor_deitado", 0.3, 0.88, pos=(bx - 0.5, F * 0.1 - 1.0, 0.3), rot=(90, 0, 70),
                    mat=FERRUGEM, lados=16, pai=r)
    if "trepadeira" in extras:  # a planta subindo pela quina da frente
        for k in range(5):
            ba.esfera("%s_trepa%d" % (nome, k), rnd.uniform(0.3, 0.5),
                      pos=(L / 2 + 0.05, -F / 2 - 0.08, 0.3 + k * 0.5), escala=(1.0, 0.6, 1.4), mat=MUSGO,
                      gomos=8, aneis=6, pai=r)
    if "arvore_laje" in extras and com_teto:
        alamo(nome + "_arvore_laje", (L * 0.2, F * 0.1, A + 0.22), 4.2, r)
    if "portao" in extras:  # o portão de enrolar da oficina, emperrado no meio e amassado
        pt = ba.caixa(nome + "_portao_lata", (porta - 0.1, 0.06, 1.5), pos=(xp, -F / 2 - 0.08, alto_porta - 0.75),
                      rot=(9, 2, 0), mat=LATA_VERDE, chanfro=0.006, pai=r)
        ba.subdividir(pt, 6)
        ba.amassar(pt, (0.5, 0.0, -0.4), 0.7, 0.18, direcao=(0, 1, 0))
    if "carcaca" in extras:  # um robô de ajuda deitado na porta da oficina, com musgo nas costas
        c = no(nome + "_robo", (xp + 2.4, -F / 2 - 1.6, 0.26), pai=r, rot=(84, 0, 35))
        ba.caixa(nome + "_robo_corpo", (0.55, 0.42, 0.62), mat=ROBO_AJUDA, pai=c)
        ba.esfera(nome + "_robo_cabeca", 0.22, pos=(0.05, 0.05, 0.55), mat=ROBO_AJUDA, pai=c)
        ba.esfera(nome + "_robo_musgo", 0.3, pos=(0, 0.2, 0.05), escala=(1.0, 0.5, 1.3), mat=MUSGO, pai=c)
    return r


# ---------------------------------------------------------------- a praça e a caixa d'água

def caixa_dagua(pai):
    """A caixa d'água de 17,6 m, o marco que se vê do voo: um pouco torta, a ferrugem escorrendo do tanque, uma
    cinta caída, a escada sem os degraus de baixo e um pedaço da tampa no chão."""
    rnd = random.Random(31)
    t = no("torre", (0, 0, 0), pai=pai, rot=(1.3, -0.9, 0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            ba.caixa("cx_perna%d%d" % (sx, sy), (0.55, 0.55, 14.0), pos=(sx * 1.8, sy * 1.8, 0), mat=CONCRETO,
                     base=True, topo=(0.75, 0.75), pai=t)
    for z in (5.0, 10.0):
        for k, (dx, dy, rz) in enumerate(((0, -1.6, 0), (0, 1.6, 0), (-1.6, 0, 90), (1.6, 0, 90))):
            if z == 10.0 and k == 2:
                continue  # esta caiu: está no chão
            ba.caixa("cx_cinta%d_%d" % (k, z), (3.8, 0.3, 0.3), pos=(dx, dy, z), rot=(0, 0, rz), mat=CONCRETO, pai=t)
    ba.caixa("cx_cinta_caida", (2.6, 0.3, 0.3), pos=(-3.6, 1.2, 0.15), rot=(0, 4, 63), mat=CONCRETO, pai=pai)
    ba.caixa("cx_cinta_caida2", (1.1, 0.3, 0.3), pos=(-4.2, -0.6, 0.12), rot=(8, 0, 20), mat=CONCRETO, pai=pai)
    tq = ba.cilindro("cx_tanque", 3.0, 3.6, pos=(0, 0, 14.0), mat=CONCRETO, base=True, lados=40, pai=t)
    ba.recorte(tq, ba.caixa("cx_racha", (1.0, 0.06, 2.2), pos=(2.95, 0.6, 15.6), rot=(0, 8, 11), chanfro=0.0, pai=t))
    ba.cilindro("cx_faixa_suja", 3.02, 0.6, pos=(0, 0, 14.0), mat=SUJO, base=True, lados=40, chanfro=0.0, pai=t)
    for k in range(16):  # a ferrugem escorrendo da borda da tampa
        a = rnd.uniform(0, 360)
        comp = rnd.uniform(0.6, 2.6)
        ba.caixa("cx_ferrugem%d" % k, (rnd.uniform(0.12, 0.4), 0.02, comp),
                 pos=(math.cos(R(a)) * 3.02, math.sin(R(a)) * 3.02, 17.6 - comp / 2), rot=(0, 0, a + 90),
                 mat=FERRUGEM, chanfro=0.0, pai=t)
    tampa = ba.cilindro("cx_tampa", 3.2, 1.0, pos=(0, 0, 17.6), raio_topo=0.4, mat=LATA_VERDE, base=True, lados=40,
                        pai=t)
    ba.recorte(tampa, ba.caixa("cx_tampa_buraco", (1.6, 1.4, 1.2), pos=(2.3, -1.4, 17.9), rot=(0, 0, 30),
                               chanfro=0.0, pai=t))
    pedaco = ba.caixa("cx_tampa_pedaco", (1.5, 1.2, 0.03), pos=(3.6, -4.2, 0.2), rot=(14, -8, 40), mat=LATA_VERDE,
                      chanfro=0.004, pai=pai)
    ba.subdividir(pedaco, 5)
    ba.amassar(pedaco, (0.3, 0.2, 0), 0.6, 0.18, direcao=(0, 0, 1))
    # a escada: dois corrimãos e os degraus, faltando os de baixo e alguns pelo caminho; o pé do corrimão entortou
    for s in (-1, 1):
        ba.caixa("cx_escada_corr%d" % s, (0.05, 0.05, 15.6), pos=(s * 0.25, -3.1, 2.0), mat=FERRUGEM, base=True,
                 chanfro=0.0, pai=t)
    ba.tubo("cx_escada_pe", [(0.25, -3.1, 2.05), (0.25, -3.15, 1.2), (0.55, -3.7, 0.4)], raio=0.025, mat=FERRUGEM,
            curva=0.2, pai=t)
    z = 2.3
    while z < 17.4:
        if rnd.random() > 0.14:
            ba.caixa("cx_degrau%d" % int(z * 10), (0.5, 0.04, 0.04), pos=(0, -3.1, z), mat=FERRUGEM, chanfro=0.0,
                     pai=t)
        z += 0.34
    for k in range(3):
        ba.caixa("cx_degrau_chao%d" % k, (0.5, 0.04, 0.04), pos=(rnd.uniform(-0.8, 0.8), -3.6 - k * 0.3, 0.02),
                 rot=(0, 0, rnd.uniform(0, 180)), mat=FERRUGEM, chanfro=0.0, pai=pai)
    for sx in (-1, 1):
        for sy in (-1, 1):
            tufo("cx_capim%d%d" % (sx, sy), (sx * 1.8 + rnd.uniform(-0.6, 0.6), sy * 1.8 + rnd.uniform(-0.6, 0.6), 0),
                 pai, rnd, 0.9)
    arbusto("cx_mato", (-1.2, 1.5, 0), pai, rnd, 1.1)


def poste(nome, pos, pai, tomba=0.0, dire=0.0):
    """O poste da praça (acende quando o robô passa rente). `tomba` graus para o lado `dire`."""
    p = no(nome, pos, pai=pai, rot=(tomba, 0, dire))
    ba.cilindro(nome + "_haste", 0.09, 4.2, mat=JUNTA, base=True, lados=10, pai=p)
    ba.caixa(nome + "_braco", (0.7, 0.08, 0.08), pos=(0.3, 0, 4.1), mat=JUNTA, pai=p)
    ba.caixa(nome + "_lampada", (0.32, 0.32, 0.22), pos=(0.62, 0, 3.92), mat=LATA_OCRE, pai=p)
    ba.caixa(nome + "_ferrugem", (0.2, 0.2, 0.5), pos=(0, 0, 0), mat=FERRUGEM, base=True, chanfro=0.0, pai=p)


def banco(nome, pos, giro, pai, quebrado=False, robo=False):
    b = no(nome, pos, giro, pai)
    if quebrado:  # um pé quebrou: o assento desceu de um lado
        ba.caixa(nome + "_assento", (1.9, 0.55, 0.08), pos=(0, 0, 0.27), rot=(0, 13, 0), mat=MADEIRA, pai=b)
        ba.caixa(nome + "_encosto", (1.9, 0.08, 0.5), pos=(-0.3, 0.6, 0.06), rot=(-82, 0, 8), mat=MADEIRA, pai=b)
        ba.caixa(nome + "_pe", (0.08, 0.5, 0.45), pos=(-0.85, 0, 0), mat=JUNTA, base=True, pai=b)
        ba.caixa(nome + "_pe_caido", (0.08, 0.5, 0.45), pos=(1.3, -0.5, 0.04), rot=(90, 0, 30), mat=JUNTA, pai=b)
        return b
    ba.caixa(nome + "_assento", (1.9, 0.55, 0.08), pos=(0, 0, 0.45), mat=MADEIRA, pai=b)
    ba.caixa(nome + "_encosto", (1.9, 0.08, 0.5), pos=(0, 0.26, 0.75), rot=(-10, 0, 0), mat=MADEIRA, pai=b)
    for s in (-1, 1):
        ba.caixa(nome + "_pe%d" % s, (0.08, 0.5, 0.45), pos=(s * 0.85, 0, 0), mat=JUNTA, base=True, pai=b)
    if robo:  # o robô de ajuda, desligado, sentado; musgo no alto da cabeça
        ba.caixa(nome + "_robo_corpo", (0.55, 0.42, 0.62), pos=(0.3, 0.02, 0.49), rot=(-8, 0, 6), mat=ROBO_AJUDA,
                 base=True, pai=b)
        ba.esfera(nome + "_robo_cabeca", 0.22, pos=(0.36, -0.02, 1.28), rot=(20, 0, 15), mat=ROBO_AJUDA, pai=b)
        ba.esfera(nome + "_robo_musgo", 0.2, pos=(0.38, 0.0, 1.38), escala=(1.1, 1.1, 0.45), mat=MUSGO, pai=b)
    return b


def praca(pai):
    """A praça redonda: a borda quebrada em três lugares, as lajotas rachadas e afundadas, capim nas falhas, o
    chafariz seco e rachado, os três postes (um torto) e os bancos (um quebrado, um com o robô)."""
    rnd = random.Random(5)
    borda = ba.cilindro("praca_borda", 10.0, 0.35, mat=CONCRETO, base=True, lados=56, pai=pai)
    ba.recorte(borda, ba.cilindro("praca_oco", 9.6, 1.0, pos=(0, 0, -0.2), base=True, pai=pai))
    for k, a in enumerate((62, 205, 298)):
        ba.recorte(borda, ba.caixa("praca_falha%d" % k, (1.0, 1.3, 1.0), pos=(math.cos(R(a)) * 9.8,
                                                                             math.sin(R(a)) * 9.8, 0.4),
                                   rot=(0, 0, a), chanfro=0.0, pai=pai))
        ba.caixa("praca_borda_caida%d" % k, (1.0, 0.36, 0.3), pos=(math.cos(R(a)) * 10.8, math.sin(R(a)) * 10.8, 0.1),
                 rot=(rnd.uniform(-10, 10), rnd.uniform(-20, 20), a + 90 + rnd.uniform(-30, 30)), mat=CONCRETO,
                 pai=pai)
    passo = 1.8
    n = int(9.4 / passo) + 1
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            x, y = i * passo, j * passo
            if math.hypot(x, y) > 9.0 or (abs(x) < 2.5 and abs(y) < 2.5) or math.hypot(x - 5.0, y + 4.0) < 2.3:
                continue
            if rnd.random() < 0.16:  # a lajota que sumiu: capim no lugar
                tufo("lajota_capim%d_%d" % (i, j), (x, y, 0), pai, rnd, 0.55)
                continue
            ba.caixa("lajota%d_%d" % (i, j), (passo - 0.07, passo - 0.07, 0.1),
                     pos=(x, y, rnd.uniform(-0.04, 0.03)),
                     rot=(rnd.uniform(-1.6, 1.6), rnd.uniform(-1.6, 1.6), rnd.uniform(-2.5, 2.5)),
                     mat=PEDRA_CLARA if rnd.random() < 0.3 else CONCRETO, chanfro=0.02, segs=1, base=True, pai=pai)
            if rnd.random() < 0.25:
                tufo("lajota_fresta%d_%d" % (i, j), (x + passo / 2, y + rnd.uniform(-0.6, 0.6), 0), pai, rnd, 0.35)
    # o chafariz: seco, rachado, um pedaço da bacia caiu e o prato entortou
    cx, cy = 5.0, -4.0
    bacia = ba.cilindro("chafariz_bacia", 1.9, 0.55, pos=(cx, cy, 0), mat=CONCRETO, base=True, lados=32, pai=pai)
    ba.recorte(bacia, ba.cilindro("chafariz_oco", 1.65, 0.6, pos=(cx, cy, 0.2), base=True, pai=pai))
    ba.recorte(bacia, ba.caixa("chafariz_racha", (0.9, 0.5, 0.8), pos=(cx + 1.8, cy - 0.5, 0.45), rot=(0, 0, 20),
                               chanfro=0.0, pai=pai))
    ba.caixa("chafariz_pedaco", (0.8, 0.25, 0.45), pos=(cx + 2.6, cy - 0.9, 0.12), rot=(70, 0, 30), mat=CONCRETO,
             pai=pai)
    ba.cilindro("chafariz_coluna", 0.22, 1.5, pos=(cx, cy, 0), mat=CONCRETO, base=True, lados=12, pai=pai)
    ba.cilindro("chafariz_prato", 0.7, 0.14, pos=(cx + 0.1, cy, 1.42), rot=(9, 6, 0), mat=CONCRETO, base=True,
                pai=pai)
    arbusto("chafariz_mato", (cx - 0.5, cy + 0.4, 0.2), pai, rnd, 0.7)
    tufo("chafariz_capim", (cx + 0.6, cy - 0.3, 0.2), pai, rnd, 0.7)
    poste("poste_0", (math.cos(R(30)) * 7.5, math.sin(R(30)) * 7.5, 0), pai)
    poste("poste_1", (math.cos(R(150)) * 7.5, math.sin(R(150)) * 7.5, 0), pai)
    poste("poste_2", (math.cos(R(270)) * 7.5, math.sin(R(270)) * 7.5, 0), pai, tomba=14, dire=200)
    banco("banco_robo", (-5.5, -4.5, 0), 40, pai, robo=True)
    banco("banco_b", (-6.4, 3.6, 0), 120, pai)
    banco("banco_c", (3.2, 6.8, 0), 200, pai, quebrado=True)


def postes_de_luz(pai):
    """A linha de postes de madeira que trazia a luz da casa de energia: os fios caem em barriga; um poste
    entortou e o último caiu com o fio no chão."""
    rnd = random.Random(9)
    pts = []
    for k, a in enumerate((128, 108, 88, 68, 48)):
        x, y = math.cos(R(a)) * 35.0, math.sin(R(a)) * 35.0
        tomba = {2: 17.0, 4: 87.0}.get(k, rnd.uniform(-3, 3))
        dire = a + 90 if k != 4 else a - 30
        p = no("pl_%d" % k, (x, y, 0), pai=pai, rot=(tomba, 0, dire))
        ba.cilindro("pl_%d_haste" % k, 0.13, 7.0, mat=TRONCO, base=True, lados=10, pai=p)
        ba.caixa("pl_%d_cruzeta" % k, (1.5, 0.1, 0.1), pos=(0, 0, 6.6), mat=MADEIRA, pai=p)
        for s in (-1, 1):
            ba.cilindro("pl_%d_isolador%d" % (k, s), 0.05, 0.12, pos=(s * 0.65, 0, 6.65), mat=VIDRO, base=True,
                        lados=8, pai=p)
        OCUPADO.append((x, y, 1.0))
        bpy.context.view_layer.update()
        pts.append([p.matrix_world @ Vector((s * 0.65, 0, 6.77)) for s in (-1, 1)])
    for k in range(len(pts) - 1):
        for s in range(2):
            a, b = pts[k][s], pts[k + 1][s]
            if k == 1 and s == 0:  # um fio arrebentou: os dois pedaços pendem dos postes
                ba.cabo("pl_fio%d_%da" % (k, s), a, a.lerp(b, 0.3) + Vector((0, 0, -5.5)), 0.4, 0.012, JUNTA, chao=0.0)
                ba.cabo("pl_fio%d_%db" % (k, s), b, b.lerp(a, 0.25) + Vector((0, 0, -6.5)), 0.4, 0.012, JUNTA,
                        chao=0.0)
                continue
            ba.cabo("pl_fio%d_%d" % (k, s), a, b, 0.9 if k < 3 else 3.0, 0.012, JUNTA, chao=0.0)


def parquinho(pos, giro, pai):
    """O parquinho da escola: o balanço (um assento caiu de um lado; a corrente do outro arrebentou) e o
    escorregador enferrujado."""
    p = no("parquinho", pos, giro, pai)
    OCUPADO.append((pos[0], pos[1], 4.5))
    for x in (-1.7, 1.7):
        for s in (-1, 1):
            ba.tubo("balanco_perna%d%d" % (x > 0, s), [(x, s * 1.0, 0), (x, 0, 2.5)], raio=0.045, mat=FERRUGEM,
                    curva=0.0, pai=p)
    ba.tubo("balanco_trave", [(-1.75, 0, 2.5), (1.75, 0, 2.5)], raio=0.05, mat=FERRUGEM, curva=0.0, pai=p)
    for s in (-1, 1):  # o primeiro assento, inteiro
        ba.cabo("balanco_a_corrente%d" % s, (-0.75 + s * 0.2, 0, 2.45), (-0.75 + s * 0.2, 0, 0.52), 0.0, 0.01,
                JUNTA, pai=p)
    ba.caixa("balanco_a_assento", (0.48, 0.2, 0.035), pos=(-0.75, 0, 0.5), mat=MADEIRA, pai=p)
    ba.cabo("balanco_b_corrente", (0.55, 0, 2.45), (0.55, 0, 0.62), 0.0, 0.01, JUNTA, pai=p)
    ba.cabo("balanco_b_toco", (0.95, 0, 2.45), (0.97, 0.05, 1.9), 0.0, 0.01, JUNTA, pai=p)
    ba.caixa("balanco_b_assento", (0.48, 0.2, 0.035), pos=(0.62, 0, 0.38), rot=(0, 72, 0), mat=MADEIRA, pai=p)
    # o escorregador
    ex = 4.2
    for s in (-1, 1):
        ba.caixa("escorr_corr%d" % s, (0.05, 0.05, 1.9), pos=(ex + s * 0.25, 1.4, 0), rot=(-10, 0, 0),
                 mat=FERRUGEM, base=True, chanfro=0.0, pai=p)
    for k in range(5):
        if k == 2:
            continue  # o degrau do meio caiu
        ba.caixa("escorr_degrau%d" % k, (0.5, 0.05, 0.04), pos=(ex, 1.35 - k * 0.07, 0.3 + k * 0.33), mat=FERRUGEM,
                 chanfro=0.0, pai=p)
    ba.caixa("escorr_topo", (0.65, 0.6, 0.05), pos=(ex, 0.95, 1.75), mat=FERRUGEM, chanfro=0.005, pai=p)
    rampa = ba.caixa("escorr_rampa", (0.55, 3.3, 0.04), pos=(ex, -0.5, 0.95), rot=(-32, 0, 0), mat=LATA_OCRE,
                     chanfro=0.005, pai=p)
    ba.recorte(rampa, ba.caixa("escorr_furo", (0.3, 0.6, 0.3), pos=(ex + 0.1, -0.9, 0.7), rot=(-32, 0, 20),
                               chanfro=0.0, pai=p))
    rnd = random.Random(14)
    for k in range(5):
        tufo("parquinho_capim%d" % k, (rnd.uniform(-2, 5), rnd.uniform(-1.5, 1.5), 0), p, rnd, 0.7)


def estufa(nome, pos, giro, pai, L=9.0, F=4.5, A=2.4, semente=0):
    """A estufa da horta: armação de ferro e quase todo o vidro quebrado; mato dentro."""
    rnd = random.Random(semente)
    r = no(nome, pos, giro, pai)
    OCUPADO.append((pos[0], pos[1], L * 0.6))
    m = ba.caixa(nome + "_mureta", (L, F, 0.5), mat=CONCRETO, base=True, pai=r)
    ba.recorte(m, ba.caixa(nome + "_mureta_oco", (L - 0.4, F - 0.4, 1.0), pos=(0, 0, 0.3), base=True, pai=r))
    n = int(L / 1.5)
    for k in range(n + 1):
        x = -L / 2 + k * L / n
        torto = k == 2
        for s in (-1, 1):
            ba.caixa(nome + "_pilar%d_%d" % (k, s), (0.08, 0.08, A), pos=(x, s * F / 2, 0.5),
                     rot=(0, 9 if torto else 0, 0), mat=FERRUGEM, base=True, pai=r)
        if torto:
            continue  # o arco desse vão caiu
        ba.caixa(nome + "_arco%d" % k, (0.08, F, 0.08), pos=(x, 0, A + 1.25), mat=FERRUGEM, pai=r)
        for s in (-1, 1):
            ba.caixa(nome + "_caibro%d_%d" % (k, s), (0.08, F * 0.56, 0.08), pos=(x, s * F * 0.25, A + 0.95),
                     rot=(-s * 32, 0, 0), mat=FERRUGEM, pai=r)
    for k in range(n):
        if rnd.random() < 0.3:
            s = rnd.choice((-1, 1))
            ba.caixa(nome + "_vidro%d" % k, (L / n - 0.1, F * 0.54, 0.03), pos=(-L / 2 + (k + 0.5) * L / n,
                                                                              s * F * 0.25, A + 0.95),
                     rot=(-s * 32, 0, 0), mat=VIDRO, pai=r)
    for k in range(4):
        arbusto(nome + "_mato%d" % k, (rnd.uniform(-L / 3, L / 3), rnd.uniform(-1, 1), 0.5), r, rnd,
                rnd.uniform(0.6, 1.0))
    entulho(nome + "_cacos", (L * 0.3, -F / 2 - 1.0, 0), r, rnd, 5, espalha=0.8, mat=VIDRO)
    return r


def paineis(nome, pos, giro, n, pai, caidos=(1,)):
    """A casa de energia: a fileira de painéis solares; os de `caidos` estão no chão."""
    r = no(nome, pos, giro, pai)
    OCUPADO.append((pos[0] + 5, pos[1], 7.0))
    for k in range(n):
        x = k * 1.9
        if k in caidos:
            ba.caixa(nome + "_%d" % k, (1.7, 1.1, 0.05), pos=(x, -0.6, 0.25), rot=(70, 0, 12), mat=LATA_AZUL, pai=r)
            continue
        ba.caixa(nome + "_pe%d" % k, (0.08, 0.08, 1.0), pos=(x, 0.4, 0), mat=FERRUGEM, base=True, pai=r)
        ba.caixa(nome + "_%d" % k, (1.7, 1.1, 0.05), pos=(x, 0, 0.95), rot=(30, 0, 0), mat=LATA_AZUL, pai=r)
    return r


# ---------------------------------------------------------------- os restos das ruas

def polar(a, r):
    return Vector((math.cos(R(a)) * r, math.sin(R(a)) * r))


def _suave(a, b, t):
    x = min(1.0, max(0.0, (t - a) / (b - a)))
    return x * x * (3 - 2 * x)


def _encolhe(pts, g):
    """Puxa os cantos para o meio: a fresta entre as placas."""
    m = sum(pts, Vector((0, 0))) / len(pts)
    return [p + (m - p).normalized() * min(g, (m - p).length * 0.3) for p in pts]


def _placa(nome, pai, pts, z, mat, rnd, inclina=1.6, alt=0.1):
    """Uma placa de asfalto: o polígono `pts` [(x, y)] com o topo em `z`, um pouco torta."""
    m = sum(pts, Vector((0, 0))) / len(pts)
    bm = bmesh.new()
    cima = [bm.verts.new((p.x - m.x, p.y - m.y, 0.0)) for p in pts]
    baixo = [bm.verts.new((p.x - m.x, p.y - m.y, -alt)) for p in pts]
    bm.faces.new(cima)
    bm.faces.new(baixo[::-1])
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((baixo[i], baixo[j], cima[j], cima[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return ba._objeto(nome, bm, mat, pai, 0.015, 1, (m.x, m.y, z),
                      (rnd.uniform(-inclina, inclina), rnd.uniform(-inclina, inclina), rnd.uniform(-1, 1)))


def rua(nome, pai, eixo, larg, rnd, passo=2.2, falta=0.14, fecha=False, some=0.0, meio_fio=(), aberturas=()):
    """Os restos de uma rua de asfalto ao longo de `eixo` [(x, y), ...]: placas rachadas, afundadas e algumas
    levantadas pela raiz; as que faltam viram capim, a beira foi comida pelo mato. `meio_fio`: os lados (-1, 1)
    que têm meio-fio, com pedras faltando e outras soltas na grama (menos nas `aberturas` [(x, y, raio)]).
    `some` (0 a 1) faz a rua ir sumindo no mato até a ponta."""
    eixo = [Vector((p[0], p[1])) for p in eixo]
    if fecha:
        eixo = eixo + [eixo[0]]
    acum = [0.0]
    for a, b in zip(eixo, eixo[1:]):
        acum.append(acum[-1] + (b - a).length)
    total = acum[-1]
    n = max(1, round(total / passo))

    def ponto(d):
        for k in range(len(eixo) - 1):
            if d <= acum[k + 1] or k == len(eixo) - 2:
                seg = eixo[k + 1] - eixo[k]
                return eixo[k] + seg * ((d - acum[k]) / max(seg.length, 1e-6)), seg.normalized()

    # a grade das placas: duas por largura, os cantos mexidos (as rachaduras nunca são retas)
    V = []
    for i in range(n + 1):
        if fecha and i == n:
            V.append(V[0])
            break
        P, T = ponto(total * i / n)
        N = Vector((-T.y, T.x))
        linha = []
        for j, w in enumerate((-larg / 2, rnd.uniform(-0.3, 0.3) * larg / 3.4, larg / 2)):
            w += (rnd.uniform(0, 0.08), 0.0, -rnd.uniform(0, 0.08))[j]
            ao_longo = rnd.uniform(-0.35, 0.35) if (fecha or 0 < i < n) else 0.0
            linha.append(P + N * w + T * ao_longo)
        V.append(linha)

    def fim(i):
        return 0.0 if fecha else _suave(0.3, 1.0, (i + 0.5) / n) * some

    for i in range(n):
        for j in range(2):
            c = [V[i][j].copy(), V[i + 1][j].copy(), V[i + 1][j + 1].copy(), V[i][j + 1].copy()]
            meio = sum(c, Vector((0, 0))) / 4
            tag = "%s_%d_%d" % (nome, i, j)
            if rnd.random() < falta + fim(i) * 0.85:  # a placa que sumiu: capim no lugar
                tufo(tag + "_capim", (meio.x, meio.y, 0), pai, rnd, rnd.uniform(0.45, 0.85))
                if rnd.random() < 0.2:
                    arbusto(tag + "_mato", (meio.x, meio.y, 0), pai, rnd, rnd.uniform(0.45, 0.8))
                continue
            if rnd.random() < 0.3 + fim(i) * 0.6:  # a beira comida pelo mato
                (k0, k1), (o0, o1) = ((0, 1), (3, 2)) if j == 0 else ((3, 2), (0, 1))
                f = rnd.uniform(0.15, 0.6)
                c[k0] = c[k0].lerp(c[o0], f * rnd.uniform(0.6, 1.0))
                c[k1] = c[k1].lerp(c[o1], f * rnd.uniform(0.6, 1.0))
            pecas = [c]
            if rnd.random() < 0.6:  # rachou de través
                a, b = c[0].lerp(c[1], rnd.uniform(0.3, 0.7)), c[3].lerp(c[2], rnd.uniform(0.3, 0.7))
                pecas = [[c[0], a, b, c[3]], [a, c[1], c[2], b]]
            if rnd.random() < 0.45:  # e no comprido, num dos pedaços
                k = rnd.randrange(len(pecas))
                q = pecas[k]
                a, b = q[0].lerp(q[3], rnd.uniform(0.35, 0.65)), q[1].lerp(q[2], rnd.uniform(0.35, 0.65))
                pecas[k:k + 1] = [[q[0], q[1], b, a], [a, b, q[2], q[3]]]
            for k, pc in enumerate(pecas):
                pc = _encolhe(pc, rnd.uniform(0.03, 0.1))
                if rnd.random() < 0.07:  # a raiz levantou a placa
                    _placa("%s_%d" % (tag, k), pai, pc, 0.09, ASFALTO, rnd, inclina=rnd.uniform(5, 8))
                    m = sum(pc, Vector((0, 0))) / len(pc)
                    tufo(tag + "_raiz%d" % k, (m.x + rnd.uniform(-0.6, 0.6), m.y + rnd.uniform(-0.6, 0.6), 0.05),
                         pai, rnd, 0.7)
                    continue
                _placa("%s_%d" % (tag, k), pai, pc, rnd.uniform(0.015, 0.05),
                       REMENDO if rnd.random() < 0.1 else ASFALTO, rnd)
            if rnd.random() < 0.35:  # capim na fresta
                q = rnd.choice(c)
                tufo(tag + "_fresta", (q.x, q.y, 0.02), pai, rnd, rnd.uniform(0.3, 0.55))

    # o meio-fio: pedras de 1 m na beira, umas faltando, outras soltas na grama
    for lado in meio_fio:
        j = 0 if lado < 0 else 2
        for i in range(n):
            a, b = V[i][j], V[i + 1][j]
            seg = b - a
            T = seg.normalized()
            N = Vector((-T.y, T.x)) * lado
            ang = math.degrees(math.atan2(T.y, T.x))
            m = max(1, round(seg.length / 1.0))
            comp = seg.length / m - 0.04
            for k in range(m):
                p = a.lerp(b, (k + 0.5) / m)
                if any((p - Vector((x, y))).length < r for x, y, r in aberturas):
                    continue
                if rnd.random() < 0.22 + fim(i) * 0.7:
                    continue
                tag = "%s_meiofio%d_%d_%d" % (nome, j, i, k)
                if rnd.random() < 0.14:
                    q = p + N * rnd.uniform(0.35, 0.9) + T * rnd.uniform(-0.3, 0.3)
                    ba.caixa(tag, (comp, 0.14, 0.3), pos=(q.x, q.y, 0.07),
                             rot=(rnd.choice((-1, 1)) * rnd.uniform(75, 95), 0, ang + rnd.uniform(-35, 35)),
                             mat=CONCRETO, chanfro=0.015, segs=1, pai=pai)
                    continue
                q = p + N * 0.08
                ba.caixa(tag, (comp, 0.14, 0.3), pos=(q.x, q.y, -0.12 + rnd.uniform(-0.05, 0.03)),
                         rot=(rnd.uniform(-5, 5), rnd.uniform(-2, 2), ang + rnd.uniform(-3, 3)), mat=CONCRETO,
                         base=True, chanfro=0.015, segs=1, pai=pai)


def bueiro(nome, p, pai, aberto=False):
    """O bueiro: o asfalto afundou em volta e o aro de concreto ficou para cima. O aberto tem a tampa caída do
    lado."""
    OCUPADO.append((p.x, p.y, 0.9))
    ba.caixa(nome + "_aro", (0.95, 0.95, 0.16), pos=(p.x, p.y, -0.06), mat=CONCRETO, base=True, chanfro=0.02, segs=1,
             pai=pai)
    if aberto:
        ba.cilindro(nome + "_buraco", 0.33, 0.01, pos=(p.x, p.y, 0.1), mat=JUNTA, base=True, lados=20, chanfro=0.0,
                    pai=pai)
        ba.cilindro(nome + "_tampa", 0.35, 0.04, pos=(p.x + 0.75, p.y + 0.35, 0.07), rot=(13, -7, 0), mat=FERRUGEM,
                    lados=20, chanfro=0.008, pai=pai)
    else:
        ba.cilindro(nome + "_tampa", 0.35, 0.03, pos=(p.x, p.y, 0.1), mat=FERRUGEM, base=True, lados=20,
                    chanfro=0.008, pai=pai)


def boca_de_lobo(nome, p, giro, pai):
    """A grade de ferro da boca de lobo, rente ao meio-fio, com o aro de concreto."""
    b = no(nome, (p.x, p.y, 0.0), giro, pai)
    ba.caixa(nome + "_aro", (1.1, 0.55, 0.14), pos=(0, 0, -0.05), mat=CONCRETO, base=True, chanfro=0.015, segs=1,
             pai=b)
    ba.caixa(nome + "_fundo", (0.95, 0.4, 0.01), pos=(0, 0, 0.09), mat=JUNTA, base=True, chanfro=0.0, pai=b)
    for k in range(6):
        ba.caixa("%s_barra%d" % (nome, k), (0.04, 0.4, 0.03), pos=(-0.4 + k * 0.16, 0, 0.09), mat=FERRUGEM,
                 base=True, chanfro=0.0, pai=b)


# ================================================================ a vila
G = no("vila1")
caixa_dagua(G)
praca(G)
OCUPADO.append((0, 0, 11.0))

CASAS = [  # nome, ângulo, distância, tamanho (L, F, A), estado, cor, extras
    ("casa_a", 20, 26, (6.0, 6.5, 3.0), "caida", None, ("porta_caida", "trepadeira")),
    ("casa_b", 78, 29, (6.5, 6.0, 3.0), "puxadinho", AZUL, ("calha", "tabuas")),
    ("casa_c", 133, 25, (5.5, 6.5, 3.0), "sem_teto", None, ("carrinho",)),
    ("casa_d", 186, 30, (6.0, 7.0, 3.0), "meia", TINTA, ("janela", "muro")),
    ("casa_e", 48, 43, (6.5, 6.5, 3.0), "alpendre", AMARELA, ("antena",)),
    ("casa_f", 104, 42, (5.5, 6.0, 2.9), "inteira", None, ("arvore_laje", "porta_caida")),
    ("casa_g", 160, 44, (7.0, 6.0, 3.0), "inteira", VERDE, ("antena", "caixa_tombada", "tambores")),
    ("casa_h", 216, 42, (6.0, 6.0, 3.0), "caida", AZUL, ("janela", "trepadeira")),
    ("casa_i", 356, 40, (6.0, 6.5, 3.0), "meia", AMARELA, ("muro", "calha")),
]
for k, (nome, ang, d, tam, estado, cor, extras) in enumerate(CASAS):
    casa(nome, ang, d, tam, estado, cor, 100 + k, extras)
# a escola (janelas grandes, metade da laje caiu) e a oficina dos robôs de ajuda (o portão emperrado)
casa("escola", 250, 27, (11.0, 7.5, 3.4), "meia", AMARELA, 7, ("tabuas",), porta=1.4, xporta=0.0, desvio=0.0,
     janelas=[(-3.9, 0.9, 1.7, 1.3), (-1.8, 0.9, 1.7, 1.3), (1.8, 0.9, 1.7, 1.3), (3.9, 0.9, 1.7, 1.3)])
casa("oficina", 320, 30, (10.0, 8.0, 3.8), "inteira", None, 8, ("tambores", "portao", "carcaca", "calha"),
     porta=3.4, xporta=-1.5)
bpy.context.view_layer.update()
_esc = bpy.data.objects["escola"]
parquinho(tuple(_esc.matrix_world @ Vector((9.5, -5.0, 0))), 160, G)
estufa("estufa", (42, -27, 0), 35, G, semente=1)
paineis("energia", (-31, 38, 0), -40, 6, G, caidos=(2, 4))
postes_de_luz(G)

# ---------------------------------------------------------------- as peças baixadas, repintadas
CERCA = peca_oga("cerca-velha/cerca.glb", MADEIRA)
GRADE = peca_oga("cerca-metal/old_metal_fence/obj export/fence_metal_1_001.obj", FERRUGEM)
# o calçamento fica com a textura de pedra dele, senão em cor chapada vira tábua
CALCADA = peca_oga("calcamento/path to the house/path to the house.3ds", None, escala=0.0012)
# os canteiros da horta, com a cerca de madeira: um lance caiu, outro entortou, um sumiu
hortas = no("hortas", (33, -39, 0), 35, G)
OCUPADO.append((33, -39, 5.5))
rnd = random.Random(21)
for k in range(4):
    ba.caixa("canteiro%d" % k, (1.2, 5.0, 0.35), pos=(k * 1.9, 0, 0), mat=MADEIRA, base=True, pai=hortas)
    arbusto("canteiro_mato%d" % k, (k * 1.9, rnd.uniform(-1.5, 1.5), 0.3), hortas, rnd, 0.55)
    tufo("canteiro_capim%d" % k, (k * 1.9, rnd.uniform(-2, 2), 0.35), hortas, rnd, 0.6)
if CERCA:
    for k, (x, estado) in enumerate(((-0.4, "ok"), (1.65, "torta"), (3.7, "sumiu"), (5.75, "caida"))):
        if estado == "sumiu":
            continue
        rot = {"ok": (0, 0, 0), "torta": (22, 0, 4), "caida": (86, 0, 10)}[estado]
        copia("cerca%d" % k, CERCA, (x, -3.3, 0.06 if estado == "caida" else 0), rot, hortas)
    copia("cerca_lado", CERCA, (-1.5, -2.2, 0), (0, 0, 90), hortas)
# a grade de ferro na frente da escola: um lance em pé, um inclinado, um no chão
if GRADE:
    esc = bpy.data.objects["escola"]
    for k, (x, rot) in enumerate(((-3.6, (0, 0, 90)), (0.0, (0, -18, 90)), (3.6, (0, -86, 90)))):
        copia("grade%d" % k, GRADE, (x, -3.75 - 2.6, 0.05 if k == 2 else 0), rot, esc)
# a ruela de pedra da praça até a escola, com a mureta; falta um pedaço e outro afundou
if CALCADA:
    u = Vector((math.cos(R(250)), math.sin(R(250)), 0))
    for k, rr in enumerate((12.4, 14.85, 17.3, 19.75, 22.2)):
        if k == 0:
            continue  # aqui passa a rua da praça
        if k == 2:
            tufo("ruela_falha", tuple(u * rr), G, rnd, 0.7)
            continue
        p = u * rr
        afunda = k == 4
        copia("ruela%d" % k, CALCADA, (p.x, p.y, -0.12 if afunda else -0.02), (0, 3 if afunda else 0, 250 + (5 if afunda else 0)),
              G)

# ---------------------------------------------------------------- os restos das ruas
# o anel de asfalto em volta da praça (a borda da praça faz o meio-fio de dentro) e as ruelas: três que saem
# para as casas de trás e somem no mato, e as entradas da casa do muro, da casa do portão e da oficina
bpy.context.view_layer.update()


def porta_mundo(nome):
    xp, muro = PORTA[nome]
    L, F, A = TAM[nome]
    return (bpy.data.objects[nome].matrix_world @ Vector((xp, -F / 2 - (3.2 if muro else 0.25), 0))).to_2d()


def angulo(p):
    return math.degrees(math.atan2(p.y, p.x))


RUA_R, RUA_L = 11.75, 3.4  # o meio e a largura do anel: de 10,05 m (a borda da praça) a 13,45 m
RUELAS = []  # (nome, eixo, largura, some, lados do meio-fio)
for nome_r, a, rs, desvios, larg, some, lados in (("ruela_e", 48, (20, 27, 33), (-1.0, 1.5, 3.0), 3.0, 0.8, (-1, 1)),
                                                 ("ruela_g", 160, (21, 29, 36), (-2.0, 1.0, 3.0), 3.0, 0.8, (-1,))):
    RUELAS.append((nome_r, [polar(a, RUA_R + RUA_L / 2 + 0.05)] + [polar(a + d, r) for r, d in zip(rs, desvios)], larg,
                   some, lados))
for nome_r, casa_r, larg, some, lados in (("ruela_i", "casa_i", 2.8, 0.45, (-1, 1)), ("entrada_d", "casa_d", 2.4, 0.3, ()),
                                         ("entrada_oficina", "oficina", 3.8, 0.25, ())):
    fim_p = porta_mundo(casa_r)
    a = angulo(fim_p)
    eixo = [polar(a, RUA_R + RUA_L / 2 + 0.05)]
    if fim_p.length > 28:
        eixo.append(polar(a + 1.2, (RUA_R + fim_p.length) / 2))
    RUELAS.append((nome_r, eixo + [fim_p], larg, some, lados))
rnd = random.Random(41)
bocas = [(e[0].x, e[0].y, lg / 2 + 0.3) for _, e, lg, _, _ in RUELAS] + [tuple(polar(250, RUA_R + RUA_L / 2)) + (1.5,)]
rua("rua_praca", G, [polar(a, RUA_R) for a in range(0, 360, 5)], RUA_L, rnd, fecha=True, meio_fio=(-1,),  # o -1 é o lado de fora do anel
    aberturas=bocas)
for nome_r, eixo, larg, some, lados in RUELAS:
    rua(nome_r, G, eixo, larg, rnd, falta=0.16, some=some, meio_fio=lados)
bueiro("bueiro_aberto", polar(96, 11.1), G, aberto=True)
bueiro("bueiro_a", polar(205, 11.9), G)
bueiro("bueiro_b", polar(302, 12.1), G)
boca_de_lobo("boca_lobo_a", polar(86, 13.1), 86 + 90, G)
boca_de_lobo("boca_lobo_b", polar(232, 13.1), 232 + 90, G)

# ---------------------------------------------------------------- o mato tomando conta, entre as casas
rnd = random.Random(77)


def livre(x, y, folga=0.0):
    return all(math.hypot(x - ox, y - oy) > orr + folga for ox, oy, orr in OCUPADO)


n_tufo = n_arb = n_ent = 0
tent = 0
while (n_tufo < 70 or n_arb < 26 or n_ent < 6) and tent < 3000:
    tent += 1
    a, d = rnd.uniform(0, math.tau), rnd.uniform(11.5, 50.0)
    x, y = math.cos(a) * d, math.sin(a) * d
    if not livre(x, y):
        continue
    if n_tufo < 70:
        tufo("capim%d" % n_tufo, (x, y, 0), G, rnd, rnd.uniform(0.5, 1.0))
        n_tufo += 1
    elif n_arb < 26:
        arbusto("arbusto%d" % n_arb, (x, y, 0), G, rnd, rnd.uniform(0.6, 1.3))
        OCUPADO.append((x, y, 1.0))
        n_arb += 1
    else:
        entulho("entulho%d" % n_ent, (x, y, 0), G, rnd, 5)
        OCUPADO.append((x, y, 1.2))
        n_ent += 1
# algumas árvores no meio da vila e a mata em volta
for k, (a, d) in enumerate(((60, 19), (115, 34), (200, 20), (285, 40), (338, 24), (12, 47))):
    x, y = math.cos(R(a)) * d, math.sin(R(a)) * d
    if k % 2:
        pinheiro("arvore_vila%d" % k, (x, y, 0), 9.0 + k, G)
    else:
        alamo("arvore_vila%d" % k, (x, y, 0), 8.0 + k * 0.5, G)
for k in range(30):
    a, d = rnd.uniform(0, math.tau), rnd.uniform(56, 78)
    x, y = math.cos(a) * d, math.sin(a) * d
    if rnd.random() < 0.45:
        alamo("mata%d" % k, (x, y, 0), rnd.uniform(8, 13), G)
    else:
        pinheiro("mata%d" % k, (x, y, 0), rnd.uniform(9, 16), G)

ba.acabar()
print("objetos:", len([o for o in bpy.data.objects if o.type in ("MESH", "CURVE")]))

# ---------------------------------------------------------------- a pintura (com --pintar)
MATO = (CAPIM, TRONCO, CASCA, PINHO, ALAMO)
ENCARDIDO = (0.10, 0.095, 0.08)  # os escorridos de chuva no concreto (no lugar da cor de ferrugem do assar)
AREAS = (("cx_", "torre"), ("praca", "praca"), ("lajota", "praca"), ("chafariz", "praca"), ("poste_", "praca"),
         ("banco_", "praca"), ("rua_", "ruas"), ("ruela_", "ruas"), ("entrada_", "ruas"), ("bueiro", "ruas"),
         ("boca_lobo", "ruas"), ("pl_", "postes_luz"), ("entulho", "entulho"))
TEX = {"torre": 2048, "praca": 2048, "ruas": 2048, "escola": 2048, "oficina": 2048, "entulho": 512}
CASA = dict(ferrugem=0.5, cor_ferrugem=ENCARDIDO, sujeira=0.5)  # gastas pelo tempo: escorridos fortes
JEITO = {"ruas": dict(ferrugem=0.0, sujeira=0.45, borda=0.3, degrade=0.0),
         "praca": dict(ferrugem=0.25, cor_ferrugem=ENCARDIDO, degrade=0.08),
         "torre": dict(ferrugem=0.45, degrade=0.3),
         "entulho": dict(ferrugem=0.2, cor_ferrugem=ENCARDIDO, degrade=0.0)}
GLB = os.path.join(PASTA, "vila1_glb")


def grupo_de(o):
    """Em que malha pintada a peça entra: a casa (ou a área) de cima dela, o mato à parte."""
    m = o.active_material
    if m in MATO or (m == MUSGO and "musgo" not in o.name):  # o musgo das paredes fica na parede
        return "mato"
    if re.match(r"ruela\d$", o.name):
        return "ruela_pedra"
    t = o
    while t.parent is not None and t.parent != G:
        t = t.parent
    if t.name in TAM or t.name in ("torre", "parquinho", "estufa", "energia", "hortas"):
        return t.name
    for prefixo, grupo in AREAS:
        if t.name.startswith(prefixo):
            return grupo
    return "soltos"


if PINTAR:
    os.makedirs(GLB, exist_ok=True)
    grupos = {}
    for o in ba.pecas(list(G.children_recursive)):
        grupos.setdefault(grupo_de(o), []).append(o)
    print("grupos:", {k: len(v) for k, v in sorted(grupos.items())})
    inicio = time.time()
    for nome_g, objs in sorted(grupos.items()):
        t0 = time.time()
        if nome_g == "ruela_pedra":  # a peça baixada fica com a textura de pedra dela
            ba.exportar(os.path.join(GLB, nome_g + ".glb"), objs)
            continue
        tri = ba.triangulos(objs)
        ob = ba.juntar("g_" + nome_g, objs)
        ob.parent = G  # G está na origem, sem giro: nada sai do lugar
        if nome_g != "mato":  # o mato e as árvores ainda são provisórios: vão com as cores chapadas
            ba.uv_auto(ob)
            ba.assar(ob, os.path.join(GLB, nome_g + ".png"), tam=TEX.get(nome_g, 1024),
                     **JEITO.get(nome_g, CASA if nome_g in TAM else {}))
        ba.exportar(os.path.join(GLB, nome_g + ".glb"), [ob])
        print("pintura %s: %d triângulos, %.0f s" % (nome_g, tri, time.time() - t0))
    print("pintura: %.1f min" % ((time.time() - inicio) / 60))

# ---------------------------------------------------------------- fotos
E = ba.Estudio(os.path.join(PASTA, "_paineis_vila1" + ("_pintura" if PINTAR else "")), largura=1120, altura=700)
E.chao.scale = (40, 40, 1)
ba.cena().view_settings.exposure = 0.7  # para ler a forma: mais claro que a luz do jogo
ROBO = E.robo(pos=(2.0, -12.0, 0.0))


def robo_em(p):
    ROBO.location.x, ROBO.location.y = p[0], p[1]


def perto(nome, lado=(0, -1), dist=8.0, lat=3.0, alt=2.0, alvo_z=1.6):
    """Câmera, alvo e lugar do robô para uma casa, olhando do `lado` dela (coordenadas da casa)."""
    r = bpy.data.objects[nome]
    L, F, A = TAM[nome]
    m = r.matrix_world
    d = Vector((lado[0], lado[1], 0)).normalized()
    pp = Vector((-d.y, d.x, 0))
    ext = abs(d.x) * L / 2 + abs(d.y) * F / 2
    cam = m @ (d * (ext + dist) + pp * lat + Vector((0, 0, alt)))
    alvo = m @ (d * ext * 0.2 + Vector((0, 0, alvo_z)))
    robo = m @ (d * (ext + 1.9) + pp * (lat * 0.3 + 0.9))
    return cam, alvo, robo


def altura_vila():
    zs = []
    for o in G.children_recursive:
        if o.type in ("MESH", "CURVE") and not o.get("ajudante") and not o.hide_render:
            zs += [(o.matrix_world @ Vector(c)).z for c in o.bound_box]
    return max(zs) - min(min(zs), 0.0)


P = []
TOMADAS = []  # as mesmas fotos, para a vitrine do jogo repetir na luz do vale


def foto(legenda, nome, loc, alvo, lente=50.0, orto=None):
    TOMADAS.append(dict(nome=nome, legenda=legenda, cam=list(loc), alvo=list(alvo), lente=lente, orto=orto,
                        robo=list(ROBO.location)))
    P.append((legenda, E.foto(nome, tuple(loc), tuple(alvo), lente=lente, orto=orto)))


def chao(v, z):
    return tuple(v.to_3d() + Vector((0, 0, z)))


robo_em((2.0, -12.0))
foto("De cima: 9 casas, a escola, a oficina, a estufa, a energia, a praça e os restos das ruas", "v_cima",
     (0, 0.01, 200), (0, 0, 0), orto=150)
foto("No voo, chegando", "v_voo", (-70, -92, 44), (0, 0, 3), lente=30)
foto("Do chão, na praça: a caixa d'água torta, as lajotas rachadas", "v_praca", (7.0, -19.0, 1.6), (0, 2, 5.5),
     lente=22)
u = Vector((math.cos(R(250)), math.sin(R(250)), 0))
pu = Vector((-u.y, u.x, 0))
robo_em(u * 15.5 + pu * -0.7)
foto("A rua da praça e a ruela de pedra até a escola (falta um pedaço)", "v_ruela",
     u * 8.0 + pu * 1.3 + Vector((0, 0, 1.7)), u * 27.0 + Vector((0, 0, 2.0)), lente=24)
robo_em(polar(104, 12.5))
foto("Os restos da rua em volta da praça: o asfalto rachado, o meio-fio solto, o bueiro aberto", "v_rua",
     chao(polar(122, 11.2), 1.6), chao(polar(76, 12.6), 0.6), lente=24)
robo_em(polar(47.5, 18.5))
foto("A ruela que sai da praça e some no mato, perto do poste caído", "v_rua_some", chao(polar(46, 11.6), 1.8),
     chao(polar(50, 33.0), 0.3), lente=26)
for nome_foto, casa_nome, kw, legenda in (
        ("v_meia", "casa_d", dict(dist=7.5, lat=3.5, alt=5.2, alvo_z=1.8),
         "Metade da laje caiu: os ferros à mostra, o muro e o portão no chão"),
        ("v_puxadinho", "casa_b", dict(dist=9.0, lat=-3.5, alt=3.2, alvo_z=2.6),
         "O puxadinho que ninguém terminou; a caixinha d'água tombada"),
        ("v_sem_teto", "casa_c", dict(lado=(1, -0.7), dist=7.5, lat=0.0, alt=2.4),
         "Sem teto: a parede tombou e um pinheiro cresceu dentro"),
        ("v_alpendre", "casa_e", dict(dist=8.5, lat=2.5, alt=1.9), "A varanda: o pilar caiu e a telha pende"),
        ("v_oficina", "oficina", dict(dist=9.5, lat=2.5), "A oficina: o portão emperrado e um robô de ajuda no chão"),
        ("v_escola", "escola", dict(dist=14.0, lat=4.0, alt=2.6), "A escola, a grade caída e o parquinho")):
    cam, alvo, rb = perto(casa_nome, **kw)
    robo_em(rb)
    foto(legenda, nome_foto, cam, alvo, lente=26)
robo_em((2.2, -6.6))
foto("O pé da caixa d'água: a escada sem os degraus de baixo", "v_torre", (5.5, -10.5, 1.5), (0, -1.5, 4.8),
     lente=20)
robo_em((2.0, -12.0))
sil = E.silhueta("v_sil", (0, -420, 14), (0, 0, 6), lente=110)
P.append(("Em silhueta, de longe", sil))
P.append(("A 600 m, do tamanho que o jogo mostra", E.longe(sil, altura_vila(), 600.0, nome="v_600m")))
if PINTAR:
    with open(os.path.join(GLB, "tomadas.json"), "w", encoding="utf-8") as f:
        json.dump(TOMADAS, f, ensure_ascii=False, indent=1)
    ba.folha(P, os.path.join(PASTA, "vila1_pintura.png"), colunas=2,
             titulo="Vila 1, pintada: sujeira, escorridos e bordas gastas assados na textura · robô de 1,2 m")
else:
    ba.folha(P, os.path.join(PASTA, "vila1_forma.png"), colunas=2,
             titulo="Vila 1, a forma: casas de laje em volta da caixa d'água, gastas pelo tempo · robô de 1,2 m")
