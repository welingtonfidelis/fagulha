# Exemplo da caixa de arte, etapa 2 (a folha de estudo): quatro ideias bem diferentes de uma caixa de força
# velha, das que a gente que morava na ilha deixou perto das Torres do Vento. Só a folha para escolher; nada
# daqui vai ao jogo. A ideia 1 é a que tools/arte/exemplo_caixa_forca.py faz de verdade.
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
#       -P tools/arte/exemplo_caixa_forca_estudo.py -- [pasta de saída, padrão tools/capturas/arte]
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ dentro de tools/arte
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_arte as ba  # noqa: E402
import bpy  # noqa: E402

arg = ba.argumentos()
PASTA = os.path.abspath(arg[0]) if arg else os.path.join(ba.RAIZ, "tools", "capturas", "arte")
R = ba.R
ba.limpar()
# as cores em sRGB, nos números da tabela do jogo (scripts/vale/clareira.gd)
CONCRETO = ba.material("concreto", (0.47, 0.46, 0.43), rug=0.9)
LATA = ba.material("lata_verde", (0.18, 0.27, 0.19), metal=0.3, rug=0.6)
JUNTA = ba.material("junta", (0.05, 0.055, 0.06), rug=0.7)
OCRE = ba.material("lata_ocre", (0.42, 0.31, 0.13), rug=0.6)


def grupo(nome, x):
    g = bpy.data.objects.new(nome, None)
    ba.cena().collection.objects.link(g)
    g.location = (x, 0, 0)
    return g


GRUPOS = []

# 1 · caixa alta com aba de chuva, num pé de concreto
g = grupo("ideia1", -2.4)
GRUPOS.append(g)
ba.caixa("pe1", (0.62, 0.44, 0.38), mat=CONCRETO, base=True, chanfro=0.02, pai=g)
ba.caixa("arm1", (0.52, 0.28, 0.70), pos=(0, 0.02, 0.38), mat=LATA, base=True, pai=g)
ba.caixa("aba1", (0.64, 0.42, 0.03), pos=(0, 0.0, 1.11), rot=(8, 0, 0), mat=LATA, pai=g)
ba.tubo("conduite1", [(-0.26, 0.04, 0.5), (-0.32, 0.04, 0.5), (-0.32, 0.04, 0.0)], 0.02, JUNTA, pai=g)
ba.cabo("cabo1", (0.27, 0.06, 0.46), (0.85, -0.35, 0.0), 0.22, 0.011, JUNTA, pai=g)

# 2 · armário baixo de duas portas, sobre dois blocos
g = grupo("ideia2", -0.8)
GRUPOS.append(g)
for s in (-1, 1):
    ba.caixa("bloco2_%d" % s, (0.22, 0.36, 0.16), pos=(s * 0.33, 0, 0), mat=CONCRETO, base=True, pai=g)
ba.caixa("arm2", (0.96, 0.34, 0.62), pos=(0, 0, 0.16), mat=LATA, base=True, pai=g)
ba.caixa("teto2", (1.02, 0.40, 0.04), pos=(0, 0, 0.80), mat=LATA, pai=g)
for k in range(6):
    ba.caixa("grade2_%d" % k, (0.30, 0.02, 0.012), pos=(0.22, -0.18, 0.30 + k * 0.04), mat=JUNTA, pai=g)
ba.caixa("placa2", (0.09, 0.006, 0.09), pos=(-0.25, -0.172, 0.55), rot=(0, 45, 0), mat=OCRE, pai=g)

# 3 · poste fino com um tambor no alto e o cabo descendo
g = grupo("ideia3", 0.8)
GRUPOS.append(g)
ba.caixa("poste3", (0.16, 0.16, 1.9), mat=CONCRETO, base=True, topo=(0.75, 0.75), pai=g)
ba.caixa("cruzeta3", (0.56, 0.05, 0.05), pos=(0.0, 0, 1.78), mat=JUNTA, pai=g)
ba.cilindro("tambor3", 0.2, 0.22, pos=(0, -0.19, 1.35), rot=(90, 0, 0), mat=LATA, pai=g)
ba.cilindro("tampa3", 0.215, 0.03, pos=(0, -0.31, 1.35), rot=(90, 0, 0), mat=LATA, pai=g)
ba.cabo("cabo3", (0.0, -0.19, 1.14), (0.55, -0.45, 0.0), 0.1, 0.012, JUNTA, pai=g)

# 4 · a caixa caída de lado, meio enterrada, com a aba solta
g = grupo("ideia4", 2.4)
GRUPOS.append(g)
ba.caixa("arm4", (0.52, 0.28, 0.70), pos=(0, 0, 0.08), rot=(0, 72, 10), mat=LATA, pai=g)
ba.caixa("pe4", (0.62, 0.44, 0.30), pos=(-0.1, 0.34, 0), rot=(0, 0, 15), mat=CONCRETO, base=True, pai=g)
ba.caixa("aba4", (0.64, 0.42, 0.03), pos=(0.5, -0.3, 0.03), rot=(4, -6, 30), mat=LATA, pai=g)
ba.cabo("cabo4", (0.25, 0.0, 0.18), (0.8, 0.3, 0.0), 0.05, 0.012, JUNTA, pai=g)

ba.acabar()
E = ba.Estudio(os.path.join(PASTA, "_paineis_estudo"))
E.robo(pos=(3.9, 0.05, 0.0))
FRENTE = ((0.75, -12.0, 0.85), (0.75, 0.0, 0.85))
PAINEIS = [("1 · De frente, em cor", E.foto("e_frente", *FRENTE, orto=7.4))]
sil_frente = E.silhueta("e_sil_frente", *FRENTE, orto=7.4)
tres_quartos = E.foto("e_3q", (-3.6, -7.6, 2.6), (0.6, 0.0, 0.7), lente=40)
# de lado: cada ideia gira 90° no lugar, com a esquerda dela para a câmera
for g in GRUPOS:
    g.rotation_euler.z = R(-90)
for o in E.robo_objs:
    if o.parent is None:
        o.rotation_euler.z = R(-90)
bpy.context.view_layer.update()
PAINEIS.append(("2 · De lado, em cor", E.foto("e_lado", *FRENTE, orto=7.4)))
PAINEIS.append(("3 · Em silhueta, de frente", sil_frente))
PAINEIS.append(("4 · Em silhueta, de lado", E.silhueta("e_sil_lado", *FRENTE, orto=7.4)))
PAINEIS.append(("5 · Em 3/4", tres_quartos))
PAINEIS.append(("6 · Do tamanho que o jogo mostra a 50 m", E.longe(sil_frente, 1.9)))
ba.folha(PAINEIS, os.path.join(PASTA, "caixa_forca_estudo.png"), colunas=2,
         titulo="Caixa de força velha: 1 alta com aba · 2 armário baixo · 3 poste com tambor · 4 caída e "
                "enterrada · robô de 1,2 m à direita")
