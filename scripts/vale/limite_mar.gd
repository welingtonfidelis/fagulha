class_name LimiteMar
extends Node
## O mar tem fim para o robô (pedido do usuário): longe demais da costa o sinal enfraquece, ele entra em
## pane e volta para a praia mais perto. Quem cria passa `armadura`, `mapa` e, se houver, `hud`.

const AVISO := 150.0  # metros da costa em que o aviso aparece
const PANE := 260.0  # metros da costa em que o robô desliga

var armadura: Armadura
var mapa: Vale
var hud: Hud
var avisos := 0
var panes := 0

var _t := 0.0
var _avisado := false


func _physics_process(delta: float) -> void:
	if armadura == null or mapa == null or armadura.em_pane:
		return
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	var p := armadura.global_position
	var d := mapa.distancia_da_costa(p.x, p.z)
	if d < AVISO * 0.7:
		_avisado = false
	elif d >= AVISO and not _avisado:
		_avisado = true
		avisos += 1
		if hud:
			hud.avisar("sinal fraco", "longe demais da costa: volte")
	if d >= PANE:
		panes += 1
		_avisado = false
		armadura.pane_forcada(mapa.praia_perto(p.x, p.z))
