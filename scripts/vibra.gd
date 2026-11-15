class_name Vibra
extends Node
## A vibração do controle: cada ação do robô dá um tranco próprio. `fraco` é o motor leve (zumbido) e
## `forte` o motor pesado (pancada), de 0 a 1. Uso: crie o nó, atribua `armadura` e chame `iniciar()`;
## ligue `ao_atirar` em Tiro.disparou.

const AJUSTE := {
	# ação: [fraco, forte, segundos]
	"decolagem": [0.5, 0.75, 0.45],
	"pulo_duplo": [0.45, 0.15, 0.12],
	"esquiva": [0.5, 0.2, 0.14],
	"pouso_leve": [0.2, 0.3, 0.1],
	"pouso_pesado": [0.4, 0.9, 0.28],
	"golpe_chao": [0.7, 1.0, 0.5],
	"levar_golpe": [0.6, 0.85, 0.3],
	"tiro": [0.35, 0.0, 0.06],
	"superaquecer": [0.8, 0.5, 0.6],
	"pane": [0.3, 1.0, 0.8],
	"religar": [0.3, 0.0, 0.15],
}
const ARRANCADA := 0.28  # zumbido contínuo do motor leve enquanto a arrancada dura
const FREADA := 0.4

## Para os testes: o nome de cada tranco, na ordem.
static var registro: Array[String] = []
## A pausa ou as opções podem desligar.
static var ligada := true

var armadura: Armadura
var _estado_antes: int = Armadura.Estado.CHAO
var _impulso_antes := 0.0
var _continuo := 0.0


func iniciar() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	armadura.estado_mudou.connect(_ao_mudar_estado)
	armadura.golpe_chao.connect(func(_onde: Vector3) -> void: tranco("golpe_chao"))
	armadura.levou_golpe.connect(func() -> void: tranco("levar_golpe"))
	armadura.superaqueceu.connect(func() -> void: tranco("superaquecer"))
	armadura.entrou_pane.connect(func() -> void: tranco("pane"))
	armadura.religou.connect(func() -> void: tranco("religar"))
	_estado_antes = armadura.estado


func ao_atirar(_origem: Vector3, _alvo: Vector3) -> void:
	tranco("tiro")


func tranco(nome: String) -> void:
	registro.append(nome)
	if not ligada:
		return
	var a: Array = AJUSTE[nome]
	for c in Input.get_connected_joypads():
		Input.start_joy_vibration(c, a[0], a[1], a[2])


func _ao_mudar_estado(novo: int) -> void:
	var antes := _estado_antes
	_estado_antes = novo
	match novo:
		Armadura.Estado.DECOLAGEM:
			tranco("decolagem")
		Armadura.Estado.POUSO:
			tranco("pouso_pesado")
		Armadura.Estado.CHAO:
			if antes in [Armadura.Estado.AR, Armadura.Estado.VOO, Armadura.Estado.PLANAR, Armadura.Estado.PAIRAR]:
				tranco("pouso_leve")


func _process(delta: float) -> void:
	if armadura == null:
		return
	# na pausa o controle fica quieto
	if get_tree().paused:
		if _continuo > 0.0:
			_continuo = 0.0
			for c in Input.get_connected_joypads():
				Input.stop_joy_vibration(c)
		return
	# pulo duplo e esquiva: o mesmo gatilho do som (o impulso cruza 0,9 vindo de baixo de 0,5)
	var impulso := armadura.impulso
	if _impulso_antes < 0.5 and impulso >= 0.9:
		tranco("esquiva" if armadura.esquivando > 0.0 else "pulo_duplo")
	_impulso_antes = impulso
	# zumbido contínuo: arrancada e freada no ar (renovado em pedaços curtos, para parar sozinho)
	var alvo := 0.0
	if armadura.arrancada:
		alvo = ARRANCADA
	elif armadura.estado == Armadura.Estado.FREAR:
		alvo = FREADA
	_continuo = move_toward(_continuo, alvo, delta * 2.0)
	if ligada and _continuo > 0.02 and Engine.get_process_frames() % 6 == 0:
		for c in Input.get_connected_joypads():
			Input.start_joy_vibration(c, _continuo, _continuo * 0.35, 0.15)
