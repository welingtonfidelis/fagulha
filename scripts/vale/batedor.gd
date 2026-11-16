class_name Batedor
extends Vigia
## Batedor: o Stan do pacote, magro e alto (1,5 m). Anda em dupla. Vendo o robô, corre em volta dele a uns
## 14 m, para, avisa e atira; é mais rápido que o Vigia e aguenta menos: dois tiros do robô desligam.
## Ficou no lugar do Zangão, o voador, que saiu do jogo (pedido do usuário: todas as máquinas no chão).


func _init() -> void:
	modelo = "stan"
	altura_m = 1.5
	vel_caca = 6.5
	dist_tiro = 14.0
	tempo_tiro = 2.6
	calor_tiro = 50.0
	rodeia = true
	motor = "zangao_loop"
