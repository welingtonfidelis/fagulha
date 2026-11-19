class_name InimigosVale
extends Node
## As máquinas agressivas espalhadas pelo vale, fora da clareira: poucos mechas sorteados (Mecha), duas duplas, seis
## sozinhos e dois grandes. Elas guardam o estado (uma desligada continua desligada), então ficam sempre criadas;
## longe do robô só param de pensar. O mergulho com impacto do robô é repassado a todas.
## Uso: defina mapa, alvo e pintar; depois add_child.

const ACORDA := 230.0
const DORME := 290.0
## O vale é para ter muita paz e, de vez em quando, uma briga (pedido do usuário): poucos mechas, longe uns dos
## outros. [lugar, quantos, grande]
const LUGARES: Array = [
	# o leste e o sudeste ficam sem máquinas hostis (decisão do usuário, 2026-11-18): as que moravam lá
	# foram para as faixas novas do oeste, do noroeste e do sudoeste
	# 2026-11-19, para a luta não ficar no caminho do sossego: a dupla dos Arcos foi para o Pátio das Máquinas
	# (de -705, 60); o que ficava entre a base e a cachoeira (-250, -330) foi para o oeste; e o grande da
	# Torre Caída (-655, 462) ficou a uns 125 m da peça das molas
	[Vector2(-680, 190), 2, false], [Vector2(-1180, -320), 2, false],
	[Vector2(-560, 300), 1, false], [Vector2(-1050, 780), 1, false], [Vector2(150, 620), 1, false],
	[Vector2(-860, -430), 1, false], [Vector2(-480, -60), 1, false], [Vector2(-880, -1130), 1, false],
	[Vector2(-750, 500), 1, true], [Vector2(-1150, 420), 1, true],
]

var mapa: Vale
var alvo: Armadura
var pintar: Callable
var todas: Array[Node3D] = []

var _t := 0.0


func _ready() -> void:
	var k := 0
	var grandes := 0
	for l: Array in LUGARES:
		var c := _chao(l[0], 30.0)
		for i in int(l[1]):
			var mc := Mecha.new()
			mc.mapa = mapa
			mc.alvo = alvo
			mc.casa = c + Vector3(i * 7.0, 0, 0)
			mc.semente = 700 + k
			mc.chefe = l[2]
			add_child(mc)
			todas.append(mc)
			k += 1
			if l[2]:
				grandes += 1
	if alvo:
		alvo.golpe_chao.connect(func(onde: Vector3) -> void: get_tree().call_group("maquinas", "levar_impacto", onde))
	print("inimigos do vale: %d mechas (%d grandes)" % [todas.size(), grandes])


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
