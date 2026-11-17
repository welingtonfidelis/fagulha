class_name MaquinaPacote
extends Vigia
## As máquinas de pacote da Fundição (doc §69), com o corpo de MechPacote:
## - "stan": o minichefe bípede, alto e magro; atira dois tiros pesados de longe.
## - "trilobite": o segundo minichefe, um disco blindado sobre pernas; corre para cima do robô e bate forte.
## - "quadshell": um tipo comum novo, pequeno e de quatro patas; rodeia o robô atirando de dois em dois.

const TITULOS := {"stan": "Stan", "trilobite": "Trilobite", "quadshell": "QuadShell"}

var tipo := "quadshell"


func _init() -> void:
	motor = "carrapato_loop"


func _montar_corpo() -> void:
	match tipo:
		"stan":
			altura_m = 4.2
			chefe = true
			tipo_tiro = "pesado"
			rajada = 2
			dist_tiro = 26.0
			tempo_tiro = 3.0
			vel_caca = 3.2
			calor_tiro = 12.0
			espalha = 0.03
		"trilobite":
			altura_m = 2.7
			chefe = true
			corpo_a_corpo = true
			dist_tiro = 3.2
			tempo_tiro = 1.9
			vel_caca = 6.2
			forca_golpe = 10.0
			calor_tiro = 10.0
		_:
			altura_m = 1.3
			tipo_tiro = "bala"
			rajada = 2
			dist_tiro = 18.0
			tempo_tiro = 2.2
			vel_caca = 5.0
			rodeia = true
			calor_tiro = 34.0
			espalha = 0.04
	_acerto.position.y = altura_m * 0.55
	_fumaca.position.y = altura_m * 0.5
	var v := MechPacote.montar(tipo, altura_m, (mapa as Clareira)._tex if mapa is Clareira else null)
	mech = v
	v.chao = func(x: float, z: float) -> float: return mapa.altura(x, z)
	_corpo.add_child(v)


func raio_acerto() -> float:
	return maxf(1.1, altura_m * 0.55)
