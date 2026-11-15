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
const FREAR_TEMPO := 0.5  # s de freada com os jatos para a frente antes de desligar o voo (a 30 m/s ou mais)
const FREAR_TEMPO_MIN := 0.25  # a freada quando já está devagar
const FREAR_FORCA := 2.8  # quanto do embalo a freada tira por segundo (exponencial)
const ANDAR_ABAIXADO := 1.6  # m/s andando abaixado
const SENTAR_SEGURAR := 0.6  # s segurando o botão de abaixar para sentar
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
const CALOR_PAIRAR := 1.5  # %/s: mais de um minuto parado no ar
const ANDAR_MIRANDO := 3.0
const ALCANCE_MIRA := 3000.0

# --- voo (física de planador com motor) ---
const G_VOO := 9.8
const VOO_ALVO := 18.0  # 65 km/h: o vale tem 2 km, atravessar leva ~110 s (eram 30 m/s, pedido do usuário em 2026-11-15)
const FREIO_AR := 10.0  # m/s² segurando o analógico para trás no voo
const PULO_SEGURA := 22.0  # m/s² a mais enquanto segura o pulo (os jatos estendem a subida)
const PULO_SEGURA_TEMPO := 0.32  # por quanto tempo segurar o pulo ajuda
const IGNICAO_TEMPO := 0.16  # pausa ao ligar os jatos no ar, antes do empurrão
const IGNICAO_EMPURRAO := 9.0  # m/s do empurrão depois da pausa, para onde a câmera aponta
const CALOR_IGNICAO := 4.0  # ligar os jatos no ar esquenta um pouco
const MERGULHO_VEL := 42.0  # m/s de descida no mergulho com impacto
const MERGULHO_ALTURA_MIN := 2.5  # abaixo disso o mergulho não arma
const RECUPERA_SUPER := 1.4  # s para se recompor depois de cair superaquecido
const CURVA_INCLINADA := 0.7  # inclinar para o lado da curva vira até 1,7× mais rápido
const ARRANCADA_ALVO := 28.0  # 100 km/h, analógico esquerdo todo para a frente
const FREIO_ALVO := 10.0
const EMPUXO_MAX := 9.0  # m/s²; acima de ~45° de subida a velocidade cai
const EMPUXO_ARRANCADA := 18.0
const EMPUXO_GANHO := 1.4
const ARRASTO := 0.0045  # o mergulho chega perto de 47 m/s
const VEL_TOPO := 47.0  # velocidade de referência do mergulho (giro, câmera)
const SUSTENTACAO := 2.6  # quanto a velocidade gira para o nariz por segundo
const GIRO_LENTO := 2.8  # rad/s em baixa velocidade
const GIRO_RAPIDO := 1.3  # rad/s a 70 m/s
const ESTOL := 12.0  # abaixo disso, planando, o nariz cai
const LATERAL := 7.0  # m/s² de deslize com o analógico esquerdo
const IGNICAO_IMPULSO := 4.0  # ligar o voo parado no ar dá um empurrão para cima
const TETO := 900.0  # acima disso o motor perde força
const TETO_FAIXA := 200.0

# --- calor (% por segundo) ---
const CALOR_DECOLAGEM := 6.0  # de uma vez
const CALOR_VOO := 1.1  # enche em ~90 s de voo reto (pedido do usuário, 2026-11-15: voar bem mais; eram 25 s)
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
