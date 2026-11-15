class_name Controles
extends RefCounted
## Ações de teclado, mouse e controle. Os nomes de botão seguem o controle de Xbox; no DualSense:
## A = X, B = círculo, LEFT_STICK = L3, START = Options, BACK = Create/Share.

static var _feito := false


static func configurar() -> void:
	if _feito:
		return
	_feito = true
	_tecla("frente", [KEY_W, KEY_UP])
	_tecla("tras", [KEY_S, KEY_DOWN])
	_tecla("esquerda", [KEY_A, KEY_LEFT])
	_tecla("direita", [KEY_D, KEY_RIGHT])
	_eixo("frente", JOY_AXIS_LEFT_Y, -1.0)
	_eixo("tras", JOY_AXIS_LEFT_Y, 1.0)
	_eixo("esquerda", JOY_AXIS_LEFT_X, -1.0)
	_eixo("direita", JOY_AXIS_LEFT_X, 1.0)
	_eixo("olhar_esquerda", JOY_AXIS_RIGHT_X, -1.0)
	_eixo("olhar_direita", JOY_AXIS_RIGHT_X, 1.0)
	_eixo("olhar_cima", JOY_AXIS_RIGHT_Y, -1.0)
	_eixo("olhar_baixo", JOY_AXIS_RIGHT_Y, 1.0)
	for a in ["olhar_esquerda", "olhar_direita", "olhar_cima", "olhar_baixo"]:
		InputMap.action_set_deadzone(a, 0.12)

	# Pular / decolar / ligar o voo / alternar planar.
	_tecla("pular", [KEY_SPACE])
	_botao("pular", JOY_BUTTON_A)
	# Correr no chão e arrancada no voo: Shift segurado; L3 alterna.
	_tecla("correr", [KEY_SHIFT])
	_botao("correr_alternar", JOY_BUTTON_LEFT_STICK)
	# No voo, solta (motor desligado, sem planar); no chão, no ar e pairando, esquiva.
	_tecla("soltar", [KEY_C])
	_botao("soltar", JOY_BUTTON_B)
	# Mirar (pairar no ar) e marcar um ponto: L2 / botão direito e R2 / botão esquerdo.
	_mouse("mirar", MOUSE_BUTTON_RIGHT)
	_eixo("mirar", JOY_AXIS_TRIGGER_LEFT, 1.0)
	InputMap.action_set_deadzone("mirar", 0.3)
	# Atirar pelas mãos: R2 / botão esquerdo (mirando ou pairando). Marcar um ponto: R1 / Q / botão do meio.
	_mouse("atirar", MOUSE_BUTTON_LEFT)
	_eixo("atirar", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	InputMap.action_set_deadzone("atirar", 0.3)
	_tecla("marcar", [KEY_Q])
	_mouse("marcar", MOUSE_BUTTON_MIDDLE)
	_botao("marcar", JOY_BUTTON_RIGHT_SHOULDER)
	# Pausa e medidor de desempenho.
	_tecla("menu", [KEY_ESCAPE, KEY_TAB])
	_botao("menu", JOY_BUTTON_START)
	_tecla("medidor", [KEY_F3])
	_botao("medidor", JOY_BUTTON_BACK)
	# Na Godot 4.7, confirmar e voltar dos menus não vêm ligados ao controle.
	_botao("ui_accept", JOY_BUTTON_A)
	_botao("ui_cancel", JOY_BUTTON_B)


static func _garantir(acao: String) -> void:
	if not InputMap.has_action(acao):
		InputMap.add_action(acao, 0.2)


static func _tecla(acao: String, teclas: Array) -> void:
	_garantir(acao)
	for k in teclas:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(acao, ev)


static func _mouse(acao: String, botao: MouseButton) -> void:
	_garantir(acao)
	var ev := InputEventMouseButton.new()
	ev.button_index = botao
	InputMap.action_add_event(acao, ev)


static func _botao(acao: String, botao: JoyButton) -> void:
	_garantir(acao)
	var ev := InputEventJoypadButton.new()
	ev.button_index = botao
	ev.device = -1
	InputMap.action_add_event(acao, ev)


static func _eixo(acao: String, eixo: JoyAxis, direcao: float) -> void:
	_garantir(acao)
	var ev := InputEventJoypadMotion.new()
	ev.axis = eixo
	ev.axis_value = direcao
	ev.device = -1
	InputMap.action_add_event(acao, ev)
