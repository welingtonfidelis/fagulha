class_name Ajustes
extends RefCounted
## Os números do movimento, do calor e da câmera, juntos para afinar com o usuário (doc §5.1).

# --- chão ---
const ANDAR := 3.0  # m/s
const CORRER := 9.0
const ACEL_CHAO := 20.0  # m/s² para ganhar velocidade (tem peso: leva um instante)
const FREIO_CHAO := 34.0  # m/s² para parar ou inverter
const ARRASTO_QUEDA := 10.0  # m/s² que o ar tira da velocidade de lado, caindo acima da de corrida
const QUEDA_PESADA := 1.3  # gravidade multiplicada quando o motor é desligado ou trava no voo
const SOLTAR_CORTE := 0.6  # fração da velocidade de lado que sobra ao desligar o voo
const ESQUIVA_SALTO := 3.2  # m/s para cima no arranque de jato dado no chão
const ESQUIVA_FREIO := 3.0  # 1/s: quanto o arranque perde enquanto dura
const ACEL_AR := 6.0
const GRAVIDADE := 22.0  # pesada: armadura de 2,6 m
const PULO := 8.5
const SEGURAR_DECOLAGEM := 0.22  # segundos segurando o pulo para virar decolagem
const DECOLAGEM_IMPULSO := 21.0  # sobe ~24 m (pedido do usuário em 2026-11-14: o salto de decolagem maior)
const DECOLAGEM_TEMPO := 0.85
const DECOLAGEM_GRACA := 1.6  # depois de decolar, o voo não aponta abaixo do horizonte por este tempo

# --- pulo duplo, esquiva e pairar ---
const PULO_DUPLO := 9.5  # m/s para cima no segundo pulo
const CALOR_PULO_DUPLO := 3.0
const SEGURAR_VOO := 0.22  # segurando o pulo no ar, liga o voo
const ESQUIVA_VEL := 18.0
const ESQUIVA_TEMPO := 0.28
const ESQUIVA_ESPERA := 0.55
const CALOR_ESQUIVA := 5.0
const PAIRAR_VEL := 5.0  # deslize com o analógico pairando
const PAIRAR_FREIO := 32.0  # m/s² para parar no ar
const CALOR_PAIRAR := 4.0  # %/s
const ANDAR_MIRANDO := 3.0
const ALCANCE_MIRA := 3000.0

# --- voo (física de planador com motor) ---
const G_VOO := 9.8
const VOO_ALVO := 30.0  # 108 km/h
const ARRANCADA_ALVO := 45.0
const FREIO_ALVO := 18.0
const EMPUXO_MAX := 9.0  # m/s²; acima de ~45° de subida a velocidade cai
const EMPUXO_ARRANCADA := 18.0
const EMPUXO_GANHO := 1.4
const ARRASTO := 0.002  # mergulho sem motor chega perto de 70 m/s
const SUSTENTACAO := 2.6  # quanto a velocidade gira para o nariz por segundo
const GIRO_LENTO := 2.8  # rad/s em baixa velocidade
const GIRO_RAPIDO := 1.3  # rad/s a 70 m/s
const ESTOL := 12.0  # abaixo disso, planando, o nariz cai
const LATERAL := 7.0  # m/s² de deslize com o analógico esquerdo
const IGNICAO_IMPULSO := 4.0  # ligar o voo parado no ar dá um empurrão para cima
const TETO := 900.0  # acima disso o motor perde força
const TETO_FAIXA := 200.0

# --- calor (% por segundo) ---
const CALOR_DECOLAGEM := 15.0  # de uma vez
const CALOR_VOO := 4.0  # enche em 25 s de voo reto (pedido do usuário, 2026-11-14)
const CALOR_SUBIDA := 2.0  # subida inteira na vertical = 3× mais
const CALOR_ARRANCADA := 3.0  # multiplicador
const ESFRIA_VOO_MERGULHO := 6.0  # motor em marcha lenta apontando para baixo
const ESFRIA_CHAO := 25.0
const ESFRIA_AR := 12.0
const ESFRIA_PLANAR := 10.0
const ESFRIA_MERGULHO := 16.0
const ESFRIA_AGUA := 45.0  # rasante, quase na hora
const ESFRIA_SUPER_AR := 8.34  # superaquecido no ar: 12 s para esfriar
const ESFRIA_SUPER_CHAO := 20.0  # superaquecido no chão: 5 s
const ESFRIA_CHUVA := 6.0  # a chuva ajuda a esfriar
const QUEDA_TOQUE := 2.2  # metros de queda (ou qualquer chegada de voo) para o pouso mais leve, só um toque
const QUEDA_LEVE := 3.0  # metros de queda para o pouso com estilo leve
const PANE_GOLPES := 3  # acertos de máquina seguidos que desligam o robô
const AVARIA_SARA := 25.0  # segundos sem levar golpe para um acerto sarar
const GOLPE_CALOR := 35.0  # calor que cada acerto soma
const PANE_TEMPO := 5.0  # segundos reais desligado (a tela escurece e o dia avança)
const PANE_HORAS := 3.0  # horas do dia que passam na pane
const PANE_GRACA := 12.0  # segundos depois de religar em que as máquinas não o enxergam
const QUEDA_HEROI := 12.0  # metros de queda para o pouso de herói
const RASANTE_ALTURA := 8.0  # metros acima da água
const MERGULHO_Y := -0.35  # nariz mais para baixo que isso conta como mergulho
const RELIGA_EM := 0.5  # superaquecido, só religa depois de esfriar tudo

# --- câmera ---
const CAM_DIST_CHAO := 3.8
const CAM_DIST_VOO := 5.2
const FOV_CHAO := 70.0
const FOV_MAX := 90.0
const SENS_MOUSE := 0.0025
const SENS_ANALOGICO := 2.8  # rad/s com o analógico no fim
const CAM_DIST_MIRA := 2.4
const FOV_MIRA := 56.0
const SENS_MIRANDO := 0.6  # sensibilidade mirando (multiplica)
