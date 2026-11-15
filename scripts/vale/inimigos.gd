class_name InimigosVale
extends Node
## As máquinas agressivas espalhadas pelo vale, fora da clareira: Zangões em dupla, Carrapatos em trio e
## mais Sentinelas. Elas guardam o estado (uma desligada continua desligada), então ficam sempre criadas;
## longe do robô só param de pensar. O mergulho com impacto do robô é repassado a todas.
## Uso: defina mapa, alvo e pintar; depois add_child.

const ACORDA := 230.0
const DORME := 290.0
const DUPLAS: Array[Vector2] = [Vector2(-705, 60), Vector2(-620, 420), Vector2(-690, 150), Vector2(480, -430), Vector2(300, 610), Vector2(-250, -330)]
const TRIOS: Array[Vector2] = [Vector2(-668, 196), Vector2(-748, 6), Vector2(560, 180), Vector2(-120, 500), Vector2(260, -640), Vector2(720, -260)]
const TORRES: Array[Vector2] = [Vector2(-655, 462), Vector2(610, 60), Vector2(-380, 640)]

var mapa: Vale
var alvo: Armadura
var pintar: Callable
var todas: Array[Node3D] = []

var _t := 0.0


func _ready() -> void:
	var k := 0
	for d in DUPLAS:
		var c := _chao(d, 20.0)
		for i in 2:
			var z := Zangao.new()
			z.mapa = mapa
			z.alvo = alvo
			z.casa = c + Vector3(i * 6.0 - 3.0, 0, 0)
			z.semente = 300 + k
			add_child(z)
			todas.append(z)
			k += 1
	for d in TRIOS:
		var c := _chao(d, 30.0)
		for i in 3:
			var cr := Carrapato.new()
			cr.mapa = mapa
			cr.alvo = alvo
			cr.casa = c + Vector3(cos(i * 2.1) * 4.0, 0, sin(i * 2.1) * 4.0)
			cr.semente = 400 + k
			add_child(cr)
			todas.append(cr)
			k += 1
	for d in TORRES:
		var c := _chao(d, 30.0)
		var s := Sentinela.new()
		s.mapa = mapa
		s.alvo = alvo
		s.casa = c
		s.semente = 500 + k
		s.pintar = pintar
		add_child(s)
		todas.append(s)
		k += 1
	if alvo:
		alvo.golpe_chao.connect(func(onde: Vector3) -> void: get_tree().call_group("maquinas", "levar_impacto", onde))
	print("inimigos do vale: %d zangões, %d carrapatos, %d sentinelas" % [DUPLAS.size() * 2, TRIOS.size() * 3, TORRES.size()])


## O ponto pedido, ou o chão bom mais perto dele (fora d'água, pouco inclinado).
func _chao(p: Vector2, busca: float) -> Vector3:
	var melhor := p
	var achou := false
	for r: float in [0.0, busca * 0.33, busca * 0.66, busca]:
		for a in 8:
			var q: Vector2 = p + Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0)) * r
			if mapa.agua(q.x, q.y) == -INF and mapa.normal_em(q.x, q.y).y > 0.9 and mapa.altura(q.x, q.y) > Vale.MAR + 2.0:
				melhor = q
				achou = true
				break
		if achou:
			break
	return Vector3(melhor.x, mapa.altura(melhor.x, melhor.y), melhor.y)


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.4 or alvo == null:
		return
	_t = 0.0
	var a := alvo.global_position
	for m in todas:
		var d := Vector2(m.global_position.x - a.x, m.global_position.z - a.z).length()
		if m.process_mode == Node.PROCESS_MODE_DISABLED and d < ACORDA:
			m.process_mode = Node.PROCESS_MODE_INHERIT
		elif m.process_mode != Node.PROCESS_MODE_DISABLED and d > DORME:
			m.process_mode = Node.PROCESS_MODE_DISABLED
