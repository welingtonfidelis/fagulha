# Exemplo da caixa de arte, etapas 3 a 6: a ideia 1 da folha de estudo (exemplo_caixa_forca_estudo.py), uma
# caixa de força velha num pé de concreto, com aba de chuva, conduíte e um cabo solto até o chão. Mostra o uso
# de cada função de tools/arte/blender_arte.py. É uma peça de teste: não está no jogo.
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
#       -P tools/arte/exemplo_caixa_forca.py -- [pasta de saída, padrão tools/capturas/arte]
#
# Sai na pasta:
#   caixa_forca_modelo.png    vistas, silhuetas e as silhuetas a 25 m e a 50 m (cores simples, no Blender)
#   caixa_forca_giro.png      o giro em 8 ângulos
#   caixa_forca_pintada.png   as vistas com a textura pintada (no Blender)
#   caixa_forca_simples.glb   uma malha, com os materiais pelo nome do jogo (o caminho simples)
#   caixa_forca.glb           uma malha, com a textura pintada (o caminho de artista) e a textura em .png
#   pedra_teste.glb           a pedra ao lado, feita com ba.rocha (material "rocha")
# Depois, na luz do jogo:
#   godot --path . -s tools/arte/vitrine_arte.gd -- tools/capturas/arte/caixa_forca.glb \
#       tools/capturas/arte/caixa_forca_simples.glb tools/capturas/arte/pedra_teste.glb --nome caixa_forca
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ dentro de tools/arte
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_arte as ba  # noqa: E402
import bpy  # noqa: E402

arg = ba.argumentos()
PASTA = os.path.abspath(arg[0]) if arg else os.path.join(ba.RAIZ, "tools", "capturas", "arte")
ba.limpar()
# as cores em sRGB, nos números da tabela do jogo (scripts/vale/clareira.gd)
CONCRETO = ba.material("concreto", (0.47, 0.46, 0.43), rug=0.9)
LATA = ba.material("lata_verde", (0.18, 0.27, 0.19), metal=0.3, rug=0.6)
JUNTA = ba.material("junta", (0.05, 0.055, 0.06), metal=0.2, rug=0.7)
FERRUGEM = ba.material("ferrugem", (0.28, 0.13, 0.07), rug=0.85)
VIDRO = ba.material("vidro_velho", (0.30, 0.46, 0.44), rug=0.25)
OCRE = ba.material("lata_ocre", (0.42, 0.31, 0.13), rug=0.6)
MUSGO = ba.material("musgo", (0.13, 0.26, 0.08), rug=0.95)
ROCHA = ba.material("rocha", (0.33, 0.34, 0.37), rug=0.9)

# ---------------------------------------------------------------- etapa 4: a forma

# o pé de concreto, meio enterrado, com uma quina lascada
pe = ba.caixa("pe", (0.62, 0.44, 0.44), pos=(0, 0, -0.06), mat=CONCRETO, chanfro=0.03, segs=3, topo=(0.93, 0.9),
              base=True)
ba.subdividir(pe, 3)
ba.tremer(pe, 0.007, 2.5, 1)
ba.recorte(pe, ba.caixa("lasca", (0.15, 0.15, 0.15), pos=(0.31, -0.22, 0.37), rot=(35, 20, 45)))

# o armário inteiro pende 1,2° para a direita, girando no pé dele
ar = bpy.data.objects.new("armario_raiz", None)
ba.cena().collection.objects.link(ar)
ar.location = (0, 0.02, 0.38)
ar.rotation_euler = ba._rot((0, 1.2, 0))

arm = ba.caixa("armario", (0.52, 0.28, 0.70), mat=LATA, chanfro=0.012, segs=3, base=True, pai=ar)
ba.subdividir(arm, 4)
ba.amassar(arm, (0.13, -0.14, 0.18), 0.12, 0.012)  # a porta, embaixo à direita
ba.amassar(arm, (-0.26, 0.05, 0.58), 0.10, 0.008)  # a lateral esquerda
ba.tremer(arm, 0.0015, 4.0, 2)
# a fresta em volta da porta e o vão da janelinha de leitura
ba.recorte(arm, ba.moldura("fresta", 0.46, 0.62, 0.008, 0.03, pos=(0, -0.14, 0.35), pai=ar))
ba.recorte(arm, ba.caixa("vao", (0.15, 0.03, 0.09), pos=(0, -0.14, 0.53), chanfro=0.0, pai=ar))
ba.caixa("vidro", (0.15, 0.004, 0.09), pos=(0, -0.127, 0.53), mat=VIDRO, chanfro=0.0, pai=ar)
ba.moldura("aro_janela", 0.175, 0.115, 0.014, 0.012, pos=(0, -0.146, 0.53), mat=LATA, chanfro=0.003, pai=ar)
# dobradiças (a de cima afrouxou), a maçaneta com a alavanca caída e a placa de aviso
ba.cilindro("dobradica_a", 0.011, 0.07, pos=(-0.232, -0.146, 0.16), mat=JUNTA, pai=ar)
ba.cilindro("dobradica_b", 0.011, 0.07, pos=(-0.233, -0.148, 0.54), rot=(0, 4, 0), mat=JUNTA, pai=ar)
ba.cilindro("macaneta", 0.018, 0.02, pos=(0.19, -0.152, 0.36), rot=(90, 0, 0), mat=JUNTA, pai=ar)
ba.caixa("alavanca", (0.012, 0.012, 0.07), pos=(0.19, -0.166, 0.33), rot=(0, 12, 0), mat=JUNTA, chanfro=0.003,
         pai=ar)
ba.caixa("placa", (0.08, 0.004, 0.08), pos=(0, -0.143, 0.22), rot=(0, 45, 0), mat=OCRE, chanfro=0.002, pai=ar)
# venezianas na lateral direita, uma a uma (inclinadas para a chuva escorrer)
for k in range(5):
    ba.caixa("veneziana_%d" % k, (0.028, 0.15, 0.008), pos=(0.268, 0.03, 0.14 + k * 0.032), rot=(0, 35, 0),
             mat=LATA, chanfro=0.002, pai=ar)
# a aba de chuva, caída para a frente, com a quina da frente entortada, e as duas cantoneiras
aba = ba.caixa("aba", (0.64, 0.42, 0.03), pos=(0, -0.02, 0.735), rot=(8, 0, 0), mat=LATA, chanfro=0.008, pai=ar)
ba.subdividir(aba, 6)
ba.amassar(aba, (0.30, -0.20, 0.0), 0.18, 0.03, direcao=(0, 0, -1))
for s in (-1, 1):
    ba.caixa("cantoneira_%d" % s, (0.025, 0.30, 0.03), pos=(s * 0.22, 0.0, 0.712), mat=LATA, chanfro=0.004, pai=ar)
# o conduíte que desce pela esquerda até o chão, com a bucha na parede e a abraçadeira no concreto
ba.cilindro("bucha", 0.028, 0.02, pos=(-0.265, 0.04, 0.12), rot=(0, 90, 0), mat=JUNTA, pai=ar)
ba.tubo("conduite", [(-0.26, 0.04, 0.12), (-0.32, 0.04, 0.12), (-0.32, 0.04, -0.47)], 0.02, JUNTA, curva=0.05, pai=ar)
ba.cilindro("abracadeira", 0.026, 0.016, pos=(-0.32, 0.04, -0.2), mat=FERRUGEM, pai=ar)
ba.caixa("aba_abracadeira", (0.03, 0.02, 0.016), pos=(-0.297, 0.04, -0.2), mat=FERRUGEM, chanfro=0.002, pai=ar)
# o passa-cabo na lateral direita e o cabo solto, caindo em barriga até deitar no chão
ba.cilindro("passa_cabo", 0.016, 0.02, pos=(0.262, 0.06, 0.08), rot=(0, 90, 0), mat=JUNTA, pai=ar)
bpy.context.view_layer.update()
saida_cabo = ar.matrix_world @ ba.Vector((0.275, 0.06, 0.08))
ba.limpo(ba.cabo("cabo", saida_cabo, (0.88, -0.38, 0.0), caimento=0.22, raio=0.011, mat=JUNTA))  # borracha: não enferruja na pintura
# o musgo agarrado na quina do pé, uma forma orgânica (esqueleto de linhas com pele)
musgo = ba.organico("musgo", [(0, 0, 0.0), (0.08, -0.02, 0.02), (-0.02, 0.09, 0.015), (0.03, 0.05, 0.05)],
                    [(0, 1), (0, 2), (0, 3)], [0.06, 0.04, 0.035, 0.03], mat=MUSGO, voxel=0.012,
                    pos=(-0.31, -0.22, -0.01))
ba.relevo(musgo, ((0.05, 0.012), (0.02, 0.004)), semente=3)
# uma pedra ao lado (exportada à parte)
pedra = ba.rocha("pedra_teste", (0.36, 0.30, 0.24), semente=5, mat=ROCHA, pos=(-0.66, -0.2, 0.0), rot=(0, 0, 25))

ba.acabar()

# ---------------------------------------------------------------- fotos (cores simples)
E = ba.Estudio(os.path.join(PASTA, "_paineis_caixa"))
E.robo(pos=(-1.25, 0.05, 0.0))
CENTRO = (-0.3, 0.0, 0.62)
paineis = E.vistas("m", CENTRO, 4.4)
FRENTE = ((-0.3, -9.0, 0.62), (-0.3, 0.0, 0.62))
sil = E.silhueta("m_sil_frente", *FRENTE, orto=2.9)
paineis.append(("Em silhueta, de frente", sil))
paineis.append(("Em silhueta, de lado", E.silhueta("m_sil_lado", (9.0, 0.0, 0.62), (0.0, 0.0, 0.62), orto=2.9,
                                                     com_robo=False)))
paineis.append(("Do tamanho que o jogo mostra a 25 m", E.longe(sil, 1.2, 25.0, nome="m_sil_25m")))
paineis.append(("A 50 m", E.longe(sil, 1.2, 50.0, nome="m_sil_50m")))
ba.folha(paineis, os.path.join(PASTA, "caixa_forca_modelo.png"), colunas=2,
         titulo="Caixa de força velha (ideia 1): cores simples, com o robô de 1,2 m e uma pedra feita com ba.rocha")
ba.cena().render.resolution_percentage = 50
giro = E.giro("m", (0.0, 0.0, 0.6), 2.6, n=8)
ba.cena().render.resolution_percentage = 100
ba.folha(giro, os.path.join(PASTA, "caixa_forca_giro.png"), colunas=4, titulo="O giro em 8 ângulos")

# ---------------------------------------------------------------- etapa 6: pronto para o jogo
ba.exportar(os.path.join(PASTA, "pedra_teste.glb"), [pedra])
print("triângulos da pedra:", ba.triangulos([pedra]))
pedra["referencia"] = True  # fica de fora da caixa
caixa = ba.juntar("caixa_forca")
print("triângulos da caixa:", ba.triangulos([caixa]))
ba.exportar(os.path.join(PASTA, "caixa_forca_simples.glb"), [caixa])
# etapa 5, o caminho de artista: as UVs, a textura pintada e o .glb com ela
ba.uv_auto(caixa)
ba.assar(caixa, os.path.join(PASTA, "caixa_forca_pintura.png"), tam=1024)
ba.exportar(os.path.join(PASTA, "caixa_forca.glb"), [caixa])
ba.folha(E.vistas("p", CENTRO, 4.4), os.path.join(PASTA, "caixa_forca_pintada.png"), colunas=2,
         titulo="Com a textura pintada (no Blender; a luz do jogo é a da vitrine)")
