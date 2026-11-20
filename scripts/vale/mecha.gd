class_name Mecha
extends Vigia
## Mecha: um robô inimigo sorteado (InimigoVisual): a família (Lata, Guarda ou Barril), a cor e a arma saem
## da semente, e o jeito de lutar sai da arma: com a lâmina chega junto e bate em arco; com o cano na luva é
## um atirador, de braço estendido; com mísseis nos ombros atira de mais longe e mais devagar. Os chefes
## (3 m) são três: o Colosso (dois canos pesados), a Lâmina (duas lâminas) e o Artilheiro (mísseis).

var ficha := {}
var arma_forcada := ""  # "corpo", "bala", "pesado" ou "missil" (InimigoVisual.forcar); "" sorteia


func _init() -> void:
	altura_m = 1.9
	motor = "carrapato_loop"


func _montar_corpo() -> void:
	if chefe:
		altura_m = 3.0
		_acerto.position.y = altura_m * 0.6
		_fumaca.position.y = altura_m * 0.5
	InimigoVisual.forcar = arma_forcada
	var v := InimigoVisual.montar(semente, altura_m, (mapa as Clareira)._tex if mapa is Clareira else null, chefe)
	InimigoVisual.forcar = ""
	if not chefe:
		# cada família tem a sua altura: o Barril é baixo, o Guarda é o mais alto
		altura_m = {"lata": 1.8, "guarda": 1.9, "barril": 1.6}[String(v.ficha["modelo"])]
		v.modelo.scale *= altura_m / v.altura
		v._esc *= altura_m / v.altura
		v.altura = altura_m
		_acerto.position.y = altura_m * 0.6
		_fumaca.position.y = altura_m * 0.5
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
			forca_golpe = 6.0
		"costas":
			# mísseis: lentos, viram para o robô e estouram; dá para fugir deles
			dist_tiro = 30.0
			vel_caca = 3.2
			tipo_tiro = "missil"
			rajada = 2 if String(ficha["costas"]) == "misseis2" else 1
			tempo_tiro = 5.0
			espalha = 0.12
		_:
			dist_tiro = 18.0
			vel_caca = 4.2
			match String(ficha["mao"]):
				"metralha":
					tipo_tiro = "bala"  # rajada de três
					rajada = 3
					tempo_tiro = 2.6
					espalha = 0.045
				"canhao":
					tipo_tiro = "pesado"
					rajada = 2 if String(ficha["modelo"]) == "colosso" else 1
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
