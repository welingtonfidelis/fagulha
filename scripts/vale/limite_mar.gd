class_name LimiteMar
extends Node
## O mar tem fim para o robô (pedido do usuário): longe demais da costa o sinal enfraquece, ele entra em
## pane e volta para a praia mais perto. Quem cria passa `armadura`, `mapa` e, se houver, `hud`.

# As distâncias são até a terra mais perto (qualquer praia ou ilhota), não até o meio da ilha.
# Eram 150 e 260 m; o usuário pediu mais folga (2026-11-18).
const AVISO := 350.0  # metros da costa em que o aviso aparece
const PANE := 550.0  # metros da costa em que o robô desliga

var armadura: Armadura
var mapa: Vale
var hud: Hud
var avisos := 0
var panes := 0

var _t := 0.0
var _avisado := false
var _d_antes := 0.0


func _physics_process(delta: float) -> void:
	if armadura == null or mapa == null or armadura.em_pane:
		return
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	var p := armadura.global_position
	var d := mapa.distancia_da_costa(p.x, p.z)
	# voltando para a costa (a distância cai pelo menos 1 m/s) não há aviso nem pane: o usuário via "sinal
	# fraco" mesmo voando de volta para a ilha (2026-11-18)
	var voltando := d < _d_antes - 0.25
	_d_antes = d
	if d < AVISO * 0.7 or voltando:
		_avisado = false
	elif d >= AVISO and not _avisado:
		_avisado = true
		avisos += 1
		if hud:
			hud.avisar("sinal fraco", "longe demais da costa: volte")
	if d >= PANE and not voltando:
		panes += 1
		_avisado = false
		armadura.pane_forcada(mapa.praia_perto(p.x, p.z))
