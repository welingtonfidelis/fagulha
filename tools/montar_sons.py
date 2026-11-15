"""Monta os sons do jogo a partir das gravações baixadas (tools/sons_brutos/, fora do git).

Passos (da pasta do projeto):
  1. extrair os pacotes em tools/sons_brutos/x/<pasta> (ver docs/JOGO-VOO.md §38);
  2. decodificar para WAV: godot --headless --path . -s tools/decodificar_sons.gd -- <entrada> <dec>/<pasta>
     (os .flac do pacote do Yo Frankie vão com afconvert, direto para <dec>/yofrankie__*.wav);
  3. python3 -I tools/montar_sons.py <dec>

Saída: assets/sons/*.wav. Os três toques de aviso (alarme_calor, marcar, religar) continuam vindo
do tools/gerar_sons.py: não rode aquele script inteiro de novo, ele cobriria as gravações.
Os créditos de cada gravação estão em CREDITOS.md.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_util as A

DEC = sys.argv[1]
SAIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sons")


def abre(*partes):
    return A.ler(os.path.join(DEC, *partes))


def salva(nome, canais, rms=None, pico=-3.0):
    """Com `rms`, nivela pelo volume médio (mantém o equilíbrio com os dB do código)."""
    if rms is not None:
        canais = A.nivelar(canais, rms)
        seg = A.gravar(os.path.join(SAIDA, nome + ".wav"), canais, normalizar=False)
    else:
        seg = A.gravar(os.path.join(SAIDA, nome + ".wav"), canais, pico_db=pico)
    print("%-22s %6.2f s  %d canal(is)  rms %6.1f  pico %6.1f" % (
        nome, seg, len(canais), A.rms_db(canais), A.pico_db(canais)))


def kenney(nome):
    return abre("scifi", "Audio__%s.wav" % nome)


def sfx(nome):
    return abre("sfx100", "sfx100v2_%s.wav" % nome)


def natureza(pasta, nome):
    return abre("Nature Sounds Pack__%s__%s.wav" % (pasta, nome))


# ------------------------------------------------------------------ o vale

def ambiente():
    # Mata de dia: pássaros gravados (30 s) e, por baixo, um fundo de floresta (44 s). Os dois laços
    # têm durações diferentes, então a soma demora minutos para se repetir.
    salva("mata_dia_loop", A.laco(A.passa_alta(abre("soltos", "birds-isaiah658_0.wav"), 180.0), 2.0), rms=-24.0)
    salva("mata_fundo_loop", A.laco(A.corte(abre("soltos", "Forest_Ambience.wav"), 0.2, 44.4), 1.5), rms=-26.0)
    # Noite: grilos gravados.
    salva("mata_noite_loop", A.laco(abre("soltos", "crickets_1.wav"), 0.6), rms=-23.0)
    # Chuva: 45 s gravados numa janela.
    salva("chuva_loop", A.laco(abre("chuva", "3.wav"), 2.0), rms=-18.0)
    # Trovões: um longo (gravado com a chuva) e um curto.
    longo = A.corte(abre("soltos", "rain-thunder.wav"), 20.6, 36.0)
    salva("trovao", A.fade(longo, 0.15, 5.0), rms=-21.0)
    salva("trovao_2", A.fade(sfx("thunder_01"), 0.05, 1.0), rms=-23.0)
    # Água: riacho e cachoeira gravados num acampamento, e o rio do Yo Frankie para o trecho largo.
    salva("riacho_loop", A.laco(A.mono(abre("riacho", "stream-waterfall__stream1.wav")), 1.5), rms=-19.0)
    salva("rio_loop", A.laco(A.mono(abre("yofrankie__amb_river.wav")), 1.5), rms=-19.0)
    salva("cachoeira_loop", A.laco(A.mono(A.corte(abre("riacho", "stream-waterfall__waterfall3.wav"), 0.5)), 2.0),
        rms=-17.0)
    # Vento do voo: 49 s de vento de verdade, com as rajadas dele.
    salva("vento_loop", A.laco(abre("soltos", "wind-01_0.wav"), 2.0), rms=-18.0)
    # Cavernas: vento grave e goteira (o primeiro minuto da faixa).
    salva("caverna_loop", A.laco(A.corte(abre("soltos", "dungeon_ambient_1_0.wav"), 0.0, 62.0), 2.0), rms=-22.0)
    # Folhagem ao atravessar as copas.
    for i, n in enumerate(["Foliage03", "Foliage04", "Foliage05", "Foliage06"], 1):
        salva("folhagem_%d" % i, A.fade(A.mono(A.aparar(natureza("Foliage", n))), 0.005, 0.08), rms=-22.0)


# ------------------------------------------------------------------ a armadura

def armadura():
    foguete = A.mono(abre("soltos", "rocket_engine.001.wav"))
    # Motor: o ronco grave do foguete com o chiado de um propulsor por cima.
    chiado = A.mono(kenney("thrusterFire_003"))
    motor = A.mistura((A.corte(foguete, 0.3, 5.3), 0.0, 0.0), (A.corte(chiado, 0.0, 5.0), -5.0, 0.0))
    salva("motor_loop", A.laco(motor, 0.6), rms=-13.0)
    # Arrancada: o mesmo foguete mais agudo e sem os graves, com outro propulsor.
    rasgo = A.passa_alta(A.tom(foguete, 1.35), 300.0)
    chiado2 = A.tom(A.mono(kenney("thrusterFire_001")), 1.2)
    n = min(A.duracao(rasgo), A.duracao(chiado2)) - 0.05
    arr = A.mistura((A.corte(rasgo, 0.0, n), 0.0, 0.0), (A.corte(chiado2, 0.0, n), -2.0, 0.0))
    salva("arrancada_loop", A.laco(arr, 0.5), rms=-16.0)
    # Decolagem: turbina de jato subindo.
    salva("decolagem", A.fade(A.mono(A.corte(abre("soltos", "engine_takeoff.wav"), 0.0, 2.6)), 0.03, 0.9), rms=-14.0)
    # Pulo duplo e esquiva: um sopro de ar com um estouro curto de propulsor.
    estouro = A.fade(A.corte(chiado, 1.0, 1.32), 0.01, 0.22)
    sopro_curto = A.mono(A.aparar(sfx("air_03")))
    salva("pulo_duplo", A.mistura((sopro_curto, 0.0, 0.0), (estouro, -3.0, 0.0)), rms=-20.0)
    sopro = A.fade(A.corte(A.mono(A.aparar(sfx("air_02"))), 0.0, 0.55), 0.01, 0.3)
    salva("esquiva", A.mistura((sopro, 0.0, 0.0), (A.tom(estouro, 1.25), -4.0, 0.0)), rms=-17.0)
    # Pousos: metal no capim; o pesado ganha um baque grave.
    passo = A.mono(abre("passos", "metal_steps_07.wav"))
    capim = A.mono(A.aparar(natureza("Footstep", "FootstepGrass04")))
    salva("pouso_leve", A.fade(A.mistura((passo, 0.0, 0.0), (A.nivelar(capim, -26.0), 0.0, 0.0)), 0.0, 0.1), rms=-19.0)
    baque = A.mono(abre("soltos", "thud3.wav"))
    grave = A.fade(A.passa_baixa(A.mono(kenney("lowFrequency_explosion_001")), 220.0), 0.0, 0.3)
    capim2 = A.mono(A.aparar(natureza("Footstep", "FootstepGrass05")))
    metal = A.mono(kenney("impactMetal_001"))
    salva("pouso_pesado", A.mistura((A.tom(baque, 0.8), 0.0, 0.0), (grave, -6.0, 0.0),
        (A.nivelar(capim2, -24.0), 0.0, 0.02), (metal, -12.0, 0.0)), rms=-18.0)
    # Golpe no chão (o mergulho): o baque grave inteiro, pedra e metal.
    pedra = A.mono(A.aparar(sfx("stones_02")))
    salva("golpe_chao", A.mistura((A.mono(kenney("lowFrequency_explosion_000")), 0.0, 0.0),
        (A.tom(baque, 0.6), -2.0, 0.0), (pedra, -8.0, 0.03), (A.tom(metal, 0.7), -10.0, 0.0)), rms=-17.0)
    # Motor apagando: uma máquina de verdade perdendo o giro.
    salva("motor_apaga", A.fade(A.mono(A.aparar(abre("soltos", "MachinePowerOff.wav"))), 0.01, 0.3), rms=-18.0)
    # Passos: seis pisadas de metal diferentes, cada uma com um pouco de capim.
    capins = ["FootstepGrass01", "FootstepGrass02", "FootstepGrass03", "FootstepGrass09"]
    for i, k in enumerate([3, 6, 9, 14, 18, 22], 1):
        p = A.mono(abre("passos", "metal_steps_%02d.wav" % k))
        g = A.mono(A.aparar(natureza("Footstep", capins[i % len(capins)])))
        salva("passo_%d" % i, A.fade(A.mistura((A.nivelar(p, -24.0), 0.0, 0.0), (A.nivelar(g, -30.0), 0.0, 0.0)),
            0.0, 0.05), rms=-25.0)
    # Tiro da mão: três variações.
    for i in range(3):
        salva("tiro_%d" % (i + 1), A.fade(A.mono(A.aparar(kenney("laserLarge_00%d" % i))), 0.0, 0.1), rms=-18.0)


# ------------------------------------------------------------------ as máquinas

def maquinas():
    # Tiro acertando lataria.
    for i, k in enumerate([0, 2, 4], 1):
        salva("impacto_%d" % i, A.mono(A.aparar(kenney("impactMetal_00%d" % k))), rms=-20.0)
    # Máquina desligando: a mesma gravação do motor, mais aguda (as pequenas) e mais grave (o Sentinela).
    apaga = A.mono(A.aparar(abre("soltos", "MachinePowerOff.wav")))
    salva("maquina_desliga", A.fade(A.tom(apaga, 1.35), 0.01, 0.25), rms=-19.0)
    salva("sentinela_desliga", A.fade(A.tom(apaga, 0.7), 0.01, 0.4), rms=-18.0)
    # Zangão: zumbido de rotor e tiro pequeno.
    salva("zangao_loop", A.laco(A.mono(kenney("engineCircular_002")), 0.4), rms=-17.0)
    for i, k in enumerate([0, 2], 1):
        salva("tiro_zangao_%d" % i, A.mono(A.aparar(kenney("laserSmall_00%d" % k))), rms=-20.0)
    # Carrapato: motorzinho de máquina.
    salva("carrapato_loop", A.laco(A.mono(sfx("loop_machine_01")), 0.5), rms=-19.0)
    # Sentinela: ronco grave parado, pisada pesada e o disparo.
    salva("sentinela_loop", A.laco(A.mono(kenney("spaceEngineLow_000")), 0.4), rms=-18.0)
    baque = A.mono(abre("soltos", "thud2.wav"))
    metal = A.mono(kenney("impactMetal_003"))
    salva("sentinela_passo", A.mistura((A.tom(baque, 0.7), 0.0, 0.0), (A.tom(metal, 0.6), -9.0, 0.0)), rms=-19.0)
    salva("tiro_sentinela", A.fade(A.tom(A.mono(A.aparar(kenney("laserLarge_003"))), 0.75), 0.0, 0.15), rms=-17.0)


if __name__ == "__main__":
    quais = sys.argv[2:] or ["ambiente", "armadura", "maquinas"]
    for q in quais:
        globals()[q]()
