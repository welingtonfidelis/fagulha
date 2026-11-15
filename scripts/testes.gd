class_name Testes
extends Node
## `godot --headless --path . -- --teste`: confere chão, pulo, decolagem, voo, arrancada, planar,
## mergulho, água, superaquecimento, teto, pouso, batida e os botões do controle. Termina com "VOO OK".

var m: Node
var a: Armadura
var cam: CameraVoo
var falhas := 0
var pontos := 0


func rodar(main: Node) -> void:
	m = main
	a = main.armadura
	cam = main.camera
	await _esperar(0.3)
	await _chao()
	await _pulo_e_decolagem()
	await _pulo_duplo_e_esquiva()
	await _pairar_e_mirar()
	await _voo_e_arrancada()
	await _planar_e_mergulho()
	await _agua()
	await _superaquecer()
	await _teto()
	await _pouso_e_batida()
	await _controle()
	print("")
	if falhas == 0:
		print("VOO OK (%d pontos)" % pontos)
	else:
		print("VOO FALHOU: %d de %d pontos" % [falhas, pontos])
	get_tree().quit(1 if falhas > 0 else 0)


func _ok(cond: bool, texto: String) -> void:
	pontos += 1
	if cond:
		print("  ok      ", texto)
	else:
		falhas += 1
		print("  FALHOU  ", texto)


func _esperar(seg: float) -> void:
	for i in roundi(seg * 60.0):
		await get_tree().physics_frame


func _soltar_tudo() -> void:
	for acao in ["frente", "tras", "esquerda", "direita", "pular", "correr", "soltar", "correr_alternar", "mirar", "marcar", "atirar"]:
		Input.action_release(acao)


func _apertar(acao: String) -> void:
	Input.action_press(acao)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(acao)


func _hv() -> float:
	return Vector2(a.velocity.x, a.velocity.z).length()


func _chao() -> void:
	print("chão")
	a.recomecar()
	await _esperar(1.0)
	_ok(a.estado == Armadura.Estado.CHAO and a.is_on_floor(), "começa de pé no chão (%s)" % a.nome_estado())
	_ok(m.ilha.agua(a.global_position.x, a.global_position.z) == -INF, "começa fora d'água")
	cam.yaw = m.ilha.rumo_livre(a.global_position, 30.0)
	Input.action_press("frente")
	await _esperar(2.0)
	_ok(absf(_hv() - Ajustes.ANDAR) < 0.6, "anda a ~3 m/s (%.1f)" % _hv())
	Input.action_press("correr")
	await _esperar(1.5)
	_ok(absf(_hv() - Ajustes.CORRER) < 1.0, "corre a ~9 m/s (%.1f)" % _hv())
	_soltar_tudo()
	await _esperar(1.0)
	_ok(_hv() < 0.5, "para quando solta (%.1f)" % _hv())


func _pulo_e_decolagem() -> void:
	print("pulo e decolagem")
	a.recomecar()
	await _esperar(0.5)
	await _apertar("pular")
	await _esperar(0.1)
	_ok(a.estado == Armadura.Estado.AR, "toque no pulo pula (%s)" % a.nome_estado())
	await _esperar(1.5)
	_ok(a.estado == Armadura.Estado.CHAO and a.calor < 1.0, "pulo curto volta ao chão sem aquecer (calor %d)" % a.calor)
	var chao := a.global_position.y
	cam.pitch = 0.0
	Input.action_press("pular")
	await _esperar(0.45)
	Input.action_release("pular")
	_ok(a.estado == Armadura.Estado.DECOLAGEM or a.estado == Armadura.Estado.VOO, "segurar o pulo decola (%s)" % a.nome_estado())
	_ok(a.calor >= 14.0, "decolagem esquenta ~15%% (%.0f)" % a.calor)
	await _esperar(0.75)
	_ok(a.global_position.y - chao > 12.0, "sobe mais de 12 m em ~1 s (%.1f m)" % (a.global_position.y - chao))
	_ok(a.estado == Armadura.Estado.VOO, "depois da decolagem entra no voo (%s)" % a.nome_estado())
	# decolar com a câmera olhando para baixo não pode bater no chão
	a.recomecar()
	cam.yaw = m.ilha.rumo_livre(a.global_position, 30.0)
	await _esperar(0.5)
	cam.pitch = -0.25
	var chao2 := a.global_position.y
	Input.action_press("pular")
	await _esperar(0.45)
	Input.action_release("pular")
	await _esperar(2.4)
	_ok(a.estado == Armadura.Estado.VOO and a.altura_do_chao() > 8.0, "decolar olhando para baixo segue voando (%s, %.1f m do chão, subiu %.1f m)" % [a.nome_estado(), a.altura_do_chao(), a.global_position.y - chao2])
	a.calor = 0.0


func _pulo_duplo_e_esquiva() -> void:
	print("pulo duplo e esquiva")
	a.recomecar()
	await _esperar(0.6)
	var y0 := a.global_position.y
	await _apertar("pular")
	var max1 := y0
	for i in 70:
		await get_tree().physics_frame
		max1 = maxf(max1, a.global_position.y)
	await _esperar(0.8)
	_ok(a.estado == Armadura.Estado.CHAO, "pulo simples volta ao chão (%s)" % a.nome_estado())
	y0 = a.global_position.y
	await _apertar("pular")
	await _esperar(0.25)
	await _apertar("pular")
	_ok(a.velocity.y > Ajustes.PULO_DUPLO - 1.0, "X no ar dá o pulo duplo (%.1f m/s)" % a.velocity.y)
	_ok(a.calor >= 2.5, "pulo duplo esquenta um pouco (%.1f)" % a.calor)
	var max2 := y0
	for i in 90:
		await get_tree().physics_frame
		max2 = maxf(max2, a.global_position.y)
	_ok(max2 - y0 > (max1 - y0) + 1.5, "pulo duplo sobe mais (%.1f m contra %.1f m)" % [max2 - y0, max1 - y0])
	await _esperar(1.0)
	await _apertar("pular")
	await _esperar(0.2)
	await _apertar("pular")
	await _esperar(0.3)
	var vy := a.velocity.y
	await _apertar("pular")
	_ok(a.estado == Armadura.Estado.AR and a.velocity.y <= vy + 0.1, "só um pulo duplo por pulo")
	await _esperar(1.5)
	await _apertar("pular")
	await _esperar(0.2)
	Input.action_press("pular")
	await _esperar(0.4)
	Input.action_release("pular")
	_ok(a.estado == Armadura.Estado.VOO, "pulo duplo segurado liga o voo (%s)" % a.nome_estado())
	# esquiva
	a.recomecar()
	cam.yaw = m.ilha.rumo_livre(a.global_position, 30.0)
	await _esperar(0.6)
	var p0 := a.global_position
	Input.action_press("frente")
	await _apertar("soltar")
	_ok(a.esquivando > 0.0 and a.calor > 3.5, "O no chão esquiva e esquenta ~5%% (%.1f)" % a.calor)
	await _esperar(0.3)
	Input.action_release("frente")
	var andou := Vector2(a.global_position.x - p0.x, a.global_position.z - p0.z).length()
	_ok(andou > 3.5, "a esquiva lança uns metros (%.1f m em 0,33 s)" % andou)
	await _apertar("soltar")
	_ok(a.esquivando <= 0.0, "esquiva logo em seguida espera a recarga")
	await _esperar(0.6)
	await _apertar("soltar")
	_ok(a.esquivando > 0.0, "depois da recarga esquiva de novo")
	await _esperar(0.5)


func _pairar_e_mirar() -> void:
	print("pairar e mirar")
	a.calor = 0.0
	_voo_reto(600.0, 0.0, Armadura.Estado.VOO, 30.0)
	await _esperar(0.3)
	Input.action_press("mirar")
	await _esperar(0.2)
	_ok(a.estado == Armadura.Estado.PAIRAR, "L2 no voo freia e paira (%s)" % a.nome_estado())
	await _esperar(1.5)
	_ok(a.velocity.length() < 1.0, "pairando fica parado (%.1f m/s)" % a.velocity.length())
	var y := a.global_position.y
	var c := a.calor
	await _esperar(2.0)
	_ok(absf(a.global_position.y - y) < 1.5, "pairando segura a altura (%.2f m)" % (a.global_position.y - y))
	_ok(a.calor - c > 6.0 and a.calor - c < 10.0, "pairar esquenta devagar (%.1f em 2 s)" % (a.calor - c))
	_ok(cam.cam.fov < 64.0, "a câmera fecha para mirar (campo de visão %.0f°)" % cam.cam.fov)
	Input.action_press("direita")
	await _esperar(1.0)
	_ok(_hv() > 3.5, "o analógico desliza pairando (%.1f m/s)" % _hv())
	Input.action_release("direita")
	await _apertar("pular")
	await _esperar(0.1)
	_ok(a.estado == Armadura.Estado.VOO, "X pairando liga o voo (%s)" % a.nome_estado())
	Input.action_release("mirar")
	await _esperar(0.3)
	Input.action_press("mirar")
	await _esperar(0.2)
	_ok(a.estado == Armadura.Estado.PAIRAR, "L2 de novo paira")
	Input.action_release("mirar")
	await _esperar(0.4)
	_ok(a.estado == Armadura.Estado.PAIRAR, "soltar o L2 continua no voo parado (%s)" % a.nome_estado())
	await _apertar("soltar")
	Input.action_release("soltar")
	await _esperar(0.1)
	_ok(a.estado == Armadura.Estado.AR, "O no voo parado desliga o propulsor e cai (%s)" % a.nome_estado())
	Input.action_press("mirar")
	await _esperar(0.1)
	a.calor = 99.5
	await _esperar(0.4)
	_ok(a.superaquecido and a.estado == Armadura.Estado.AR, "superaquecer pairando trava o motor e cai (%s)" % a.nome_estado())
	Input.action_release("mirar")
	a.superaquecido = false
	a.calor = 0.0
	# mirar no chão
	a.recomecar()
	cam.yaw = m.ilha.rumo_livre(a.global_position, 30.0)
	await _esperar(0.6)
	Input.action_press("mirar")
	await _esperar(0.6)
	_ok(a.mirando_agora() and cam.cam.fov < 62.0, "L2 no chão mira por cima do ombro (%.0f°)" % cam.cam.fov)
	Input.action_press("frente")
	Input.action_press("correr")
	await _esperar(1.2)
	_ok(_hv() < Ajustes.ANDAR_MIRANDO + 0.4, "mirando anda devagar (%.1f m/s)" % _hv())
	Input.action_release("frente")
	Input.action_release("correr")
	cam.pitch = -0.08
	await _esperar(0.4)
	await _apertar("marcar")
	_ok(a.tem_marcador, "R2 mirando marca um ponto (a %.0f m)" % a.global_position.distance_to(a.marcador))
	Input.action_release("mirar")
	await _esperar(0.3)


func _voo_reto(alt: float, yaw: float, estado: int, vel := 30.0) -> void:
	cam.yaw = yaw
	cam.pitch = 0.0
	var dir := -Basis(Vector3.UP, yaw).z
	a.teleportar(Vector3(0, alt, 0), estado, dir * vel)


func _voo_e_arrancada() -> void:
	print("voo e arrancada")
	a.calor = 0.0
	a.superaquecido = false
	_voo_reto(600.0, 0.0, Armadura.Estado.VOO, 20.0)
	var y0 := a.global_position.y
	await _esperar(6.0)
	var v := a.velocity.length()
	_ok(absf(v - Ajustes.VOO_ALVO) < 3.0, "voo reto chega a ~30 m/s (%.1f)" % v)
	_ok(absf(a.global_position.y - y0) < 25.0, "mantém a altura com a mira no horizonte (%.1f m)" % (a.global_position.y - y0))
	_ok(a.calor > 22.0 and a.calor < 38.0, "6 s de voo reto esquentam ~30%% (%.0f)" % a.calor)
	var c0 := a.calor
	Input.action_press("correr")
	await _esperar(3.0)
	v = a.velocity.length()
	_ok(v > 40.0, "arrancada passa de 40 m/s (%.1f)" % v)
	_ok(a.calor - c0 > 35.0, "arrancada esquenta 3× (%.0f em 3 s)" % (a.calor - c0))
	Input.action_release("correr")
	await _apertar("correr_alternar")
	_ok(a.arrancada, "L3 liga a arrancada")
	await _apertar("correr_alternar")
	await _esperar(0.1)
	_ok(not a.arrancada, "L3 de novo desliga")


func _planar_e_mergulho() -> void:
	print("planar e mergulho")
	a.calor = 60.0
	_voo_reto(700.0, 1.0, Armadura.Estado.VOO, 30.0)
	await _esperar(0.2)
	await _apertar("pular")
	_ok(a.estado == Armadura.Estado.PLANAR, "X no voo passa a planar (%s)" % a.nome_estado())
	cam.pitch = -0.2
	var y0 := a.global_position.y
	await _esperar(3.0)
	_ok(a.calor < 60.0 - 25.0, "planar esfria ~10%%/s (%.0f)" % a.calor)
	_ok(a.global_position.y < y0, "planando perde altura (%.1f m)" % (a.global_position.y - y0))
	_ok(a.velocity.length() > 15.0, "planando mantém velocidade (%.1f)" % a.velocity.length())
	_ok(visual_aletas() > 0.9, "aletas abertas ao planar")
	await _apertar("pular")
	_ok(a.estado == Armadura.Estado.VOO, "X de novo liga o motor (%s)" % a.nome_estado())
	await _apertar("pular")
	a.calor = 80.0
	cam.pitch = -1.15
	await _esperar(5.0)
	_ok(a.velocity.length() > 50.0, "mergulho planando passa de 50 m/s (%.1f)" % a.velocity.length())
	_ok(a.calor < 80.0 - 60.0, "mergulho esfria mais rápido (%.0f)" % a.calor)


func visual_aletas() -> float:
	return a.visual.abertura_aletas if a.visual else 1.0


func _agua() -> void:
	print("água")
	var il: Ilha = m.ilha
	cam.yaw = 0.0
	cam.pitch = 0.0
	var p := Vector3(il.lago_centro.x, il.lago_nivel + 4.0, il.lago_centro.y + 60.0)
	a.teleportar(p, Armadura.Estado.VOO, Vector3(0, 0, -30))
	a.calor = 80.0
	await _esperar(0.5)
	_ok(a.na_agua, "rasante no lago conta como água")
	_ok(a.calor < 62.0, "a água esfria quase na hora (80 → %.0f em 0,5 s)" % a.calor)


func _superaquecer() -> void:
	print("superaquecimento, queda e pouso")
	a.superaquecido = false
	_voo_reto(600.0, 2.0, Armadura.Estado.VOO, 30.0)
	a.calor = 98.0
	Input.action_press("correr")
	await _esperar(0.5)
	Input.action_release("correr")
	_ok(a.superaquecido, "passa de 100% e superaquece")
	_ok(a.estado == Armadura.Estado.AR, "o motor trava e o robô cai (%s)" % a.nome_estado())
	await _apertar("pular")
	_ok(a.estado == Armadura.Estado.AR, "superaquecido, X não religa nem dá pulo duplo")
	await _esperar(5.5)
	_ok(a.superaquecido and a.calor > 40.0 and a.calor < 62.0, "no ar esfria devagar: ~50%% depois de 6 s (%.0f)" % a.calor)
	var pousou := false
	for i in 400:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.POUSO or a.estado == Armadura.Estado.CHAO:
			pousou = true
			break
	_ok(pousou and a.pouso_forca > 0.9, "sem recuperar o voo, pousa em estilo herói (força %.1f, queda de %.0f m)" % [a.pouso_forca, a.queda_altura])
	await _esperar(3.4)
	_ok(not a.superaquecido, "no chão termina de esfriar rápido e libera (calor %.0f)" % a.calor)
	# 12 s no ar para esfriar tudo
	_voo_reto(900.0, 2.0, Armadura.Estado.VOO, 30.0)
	a.calor = 99.9
	await _esperar(0.3)
	var t := 0.0
	while a.superaquecido and t < 16.0:
		await _esperar(0.25)
		t += 0.25
		if a.global_position.y < 400.0:
			a.global_position.y += 400.0  # mantém no ar
	_ok(t > 10.5 and t < 13.0, "superaquecido no ar libera em ~12 s (%.1f s)" % t)
	await _apertar("pular")
	await _esperar(0.3)
	_ok(a.estado == Armadura.Estado.VOO, "depois de esfriar, segurar ou apertar X volta a voar (%s)" % a.nome_estado())
	# soltar perto do chão: queda com estilo leve
	var il: Ilha = m.ilha
	a.calor = 0.0
	a.teleportar(il.spawn + Vector3(0, 7.0, 0), Armadura.Estado.VOO, Vector3.ZERO)
	cam.pitch = 0.0
	await _esperar(0.1)
	await _apertar("soltar")
	var leve := false
	for i in 200:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.POUSO or a.estado == Armadura.Estado.CHAO:
			leve = a.pouso_forca > 0.4 and a.pouso_forca < 0.6
			break
	_ok(leve, "soltar o voo perto do chão cai com estilo leve (força %.1f, queda de %.1f m)" % [a.pouso_forca, a.queda_altura])
	await _esperar(1.0)


func _teto() -> void:
	print("teto")
	a.calor = 0.0
	_voo_reto(1080.0, 0.0, Armadura.Estado.VOO, 30.0)
	cam.pitch = 0.9
	for i in 8:
		await _esperar(1.0)
		a.calor = 0.0
	_ok(a.global_position.y < Ajustes.TETO + Ajustes.TETO_FAIXA + 60.0, "não passa muito do teto (%.0f m)" % a.global_position.y)


func _pouso_e_batida() -> void:
	print("pouso e batida")
	var il: Ilha = m.ilha
	a.calor = 0.0
	cam.yaw = il.spawn_yaw
	cam.pitch = -0.5
	var s := il.spawn
	a.teleportar(s + Vector3(0, 25, 0), Armadura.Estado.VOO, Vector3.ZERO)
	var pousou := false
	for i in 8:
		await _esperar(0.5)
		if a.estado == Armadura.Estado.CHAO or a.estado == Armadura.Estado.POUSO:
			pousou = true
			break
	_ok(pousou, "mergulhando para o chão, pousa (%s)" % a.nome_estado())
	await _esperar(1.0)
	_ok(a.estado == Armadura.Estado.CHAO, "depois do pouso fica de pé (%s)" % a.nome_estado())
	# soltar do voo
	_voo_reto(600.0, 0.0, Armadura.Estado.VOO, 30.0)
	await _esperar(0.2)
	await _apertar("soltar")
	_ok(a.estado == Armadura.Estado.AR, "O / C solta do voo (%s)" % a.nome_estado())
	# batida numa árvore: voa reto contra a copa
	var k := _arvore_em_plano(il)
	var base := il.arv_pos[k]
	var esc := il.arv_escala[k]
	var alvo_y := base.y + (9.0 if il.arv_tipo[k] == 0 else 8.5) * esc
	var de := base + Vector3(-45, 0, 0)
	cam.yaw = -PI * 0.5  # olhando para +X
	cam.pitch = 0.0
	a.teleportar(Vector3(de.x, alvo_y - 1.28, de.z), Armadura.Estado.VOO, Vector3(32, 0, 0))
	var bateu := false
	for i in 120:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.AR:
			bateu = true
			break
	_ok(bateu, "bater de frente numa árvore derruba do voo (%s, x %.0f de %.0f)" % [a.nome_estado(), a.global_position.x, base.x])


func _arvore_em_plano(il: Ilha) -> int:
	# uma árvore sem vizinhas a oeste (50 m), em chão quase plano; procura pela grade da ilha
	var cel_tam := Ilha.CELULA_ARVORE
	for i in il.arv_pos.size():
		var p := il.arv_pos[i]
		if il.normal_em(p.x, p.z).y < 0.97 or il.normal_em(p.x - 25.0, p.z).y < 0.95:
			continue
		var livre := true
		for cx in range(floori((p.x - 52.0) / cel_tam), floori(p.x / cel_tam) + 1):
			for cz in range(floori((p.z - 8.0) / cel_tam), floori((p.z + 8.0) / cel_tam) + 1):
				var cel := Vector2i(cx, cz)
				if not il._grade_arv.has(cel):
					continue
				var lista: PackedInt32Array = il._grade_arv[cel]
				for k in lista:
					if k == i:
						continue
					var q := il.arv_pos[k]
					if q.x < p.x - 1.0 and q.x > p.x - 50.0 and absf(q.z - p.z) < 7.5:
						livre = false
						break
		if livre:
			return i
	return 0


func _controle() -> void:
	print("controle")
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	Input.parse_input_event(ev)
	# o evento entra no começo do próximo quadro; vindo de um quadro de física, espera dois
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(Input.is_action_pressed("pular"), "X do controle pula")
	ev = ev.duplicate() as InputEventJoypadButton
	ev.pressed = false
	Input.parse_input_event(ev)
	for par in [["mirar", JOY_AXIS_TRIGGER_LEFT], ["atirar", JOY_AXIS_TRIGGER_RIGHT]]:
		var g := InputEventJoypadMotion.new()
		g.axis = par[1]
		g.axis_value = 1.0
		Input.parse_input_event(g)
		await get_tree().process_frame
		await get_tree().process_frame
		_ok(Input.is_action_pressed(par[0]), "%s no gatilho" % par[0])
		var g2 := g.duplicate() as InputEventJoypadMotion
		g2.axis_value = 0.0
		Input.parse_input_event(g2)
		await get_tree().process_frame
	var botoes := {"correr_alternar": JOY_BUTTON_LEFT_STICK, "soltar": JOY_BUTTON_B, "menu": JOY_BUTTON_START, "medidor": JOY_BUTTON_BACK, "marcar": JOY_BUTTON_RIGHT_SHOULDER}
	for acao in botoes:
		var e := InputEventJoypadButton.new()
		e.button_index = botoes[acao]
		e.pressed = true
		Input.parse_input_event(e)
		await get_tree().process_frame
		_ok(Input.is_action_pressed(acao), "%s no controle" % acao)
		var e2 := e.duplicate() as InputEventJoypadButton
		e2.pressed = false
		Input.parse_input_event(e2)
		await get_tree().process_frame
	if get_tree().paused:
		m.pausa._continuar()
	var eixo := InputEventJoypadMotion.new()
	eixo.axis = JOY_AXIS_LEFT_Y
	eixo.axis_value = -1.0
	Input.parse_input_event(eixo)
	await get_tree().process_frame
	_ok(Input.get_vector("esquerda", "direita", "frente", "tras").y < -0.9, "analógico esquerdo para a frente")
	eixo = eixo.duplicate() as InputEventJoypadMotion
	eixo.axis_value = 0.0
	Input.parse_input_event(eixo)
