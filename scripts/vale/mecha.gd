class_name Mecha
extends Vigia
## Mecha: um mech modular sorteado (Mech00Visual). O corpo, a cor, as armas e os equipamentos saem da
## semente, e o jeito de lutar sai do que ele carrega: com espada ou martelo chega junto e bate; com arma de
## mão ou braço-canhão é um atirador como o Vigia; com canhão ou mísseis nas costas atira de mais longe e
## mais devagar. Cada placa de armadura faz aguentar um tiro a mais, e os de corpo grande são mais lentos.

var ficha := {}
var arma_forcada := ""  # "corpo", "bala", "pesado" ou "missil" (Mech00Visual.forcar); "" sorteia
var chefe := false  # mech grande (3 m), no lugar das antigas Sentinelas: aguenta o dobro e bate mais forte


func _init() -> void:
	altura_m = 1.9
	motor = "carrapato_loop"


func _montar_corpo() -> void:
	if chefe:
		altura_m = 3.0
		_acerto.position.y = altura_m * 0.6
		_fumaca.position.y = altura_m * 0.5
	Mech00Visual.forcar = arma_forcada
	var v := Mech00Visual.montar(semente, altura_m, (mapa as Clareira)._tex if mapa is Clareira else null)
	Mech00Visual.forcar = ""
	mech = v
	v.chao = func(x: float, z: float) -> float: return mapa.altura(x, z)
	_corpo.add_child(v)
	ficha = v.ficha
	var porte: float = ficha["porte"]
	match String(ficha["arma"]):
		"corpo":
			corpo_a_corpo = true
			dist_tiro = 2.2
			tempo_tiro = 1.7
			vel_caca = 5.4
			forca_golpe = 8.0 if String(ficha["mao"]) == "Core_Hammer" else 6.0
		"costas":
			dist_tiro = 30.0
			vel_caca = 3.2
			match String(ficha["costas"]):
				"Attach_Back_Missiles_00", "Attach_Back_Missiles_01":
					# mísseis: lentos, viram para o robô e estouram; dá para fugir deles
					tipo_tiro = "missil"
					rajada = 2 if String(ficha["costas"]) == "Attach_Back_Missiles_00" else 1
					tempo_tiro = 5.0
					espalha = 0.12
				_:
					tipo_tiro = "pesado"
					rajada = 2 if String(ficha["costas"]) == "Attach_Back_2Gun" else 1
					tempo_tiro = 3.2
					espalha = 0.03
		_:
			dist_tiro = 18.0
			vel_caca = 4.2
			match String(ficha["mao"]):
				"Attach_Gun_01":
					tipo_tiro = "bala"  # metralha: rajada de três
					rajada = 3
					tempo_tiro = 2.6
					espalha = 0.045
				"Attach_Gun_02", "canhão":
					tipo_tiro = "pesado"
					tempo_tiro = 2.4
					espalha = 0.025
				_:
					tipo_tiro = "bala"  # fuzil: um tiro certeiro
					tempo_tiro = 1.6
					espalha = 0.018
	vel_caca *= 1.0 - 0.18 * porte
	calor_tiro = [34.0, 26.0, 21.0][clampi(int(ficha["armaduras"]), 0, 2)]
	if chefe:
		calor_tiro *= 0.5
		forca_golpe *= 1.3
		vel_caca *= 0.8
		dist_tiro *= 1.5 if not corpo_a_corpo else 1.6
