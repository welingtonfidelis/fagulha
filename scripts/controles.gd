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
	# o analógico de andar também (era 0,2: a passada lenta começava tarde)
	for a in ["frente", "tras", "esquerda", "direita"]:
		InputMap.action_set_deadzone(a, 0.12)

	# Pular / decolar / ligar o voo. No voo, só o toque no L3 corta os jatos (o X deixou de cortar em 2026-11-19).
	_tecla("pular", [KEY_SPACE])
	_botao("pular", JOY_BUTTON_A)
	# Correr no chão e arrancada no voo: Shift segurado; L3 alterna (no chão, só andando).
	_tecla("correr", [KEY_SHIFT])
	_botao("correr_alternar", JOY_BUTTON_LEFT_STICK)
	# Ligar e desligar o voo, só no ar: L3 / Shift.
	_tecla("voar", [KEY_SHIFT])
	_botao("voar", JOY_BUTTON_LEFT_STICK)
	# Voo parado: R3 / F (o L2 também paira). Mergulho com impacto: triângulo / V.
	_tecla("pairar", [KEY_F])
	_botao("pairar", JOY_BUTTON_RIGHT_STICK)
	_tecla("golpe", [KEY_V])
	_botao("golpe", JOY_BUTTON_Y)
	# Abaixar: R3 no chão / Ctrl. Um toque abaixa, segurar senta. (No ar o R3 é parar no ar.)
	# Sentar: seta para a esquerda / Ctrl (agachar saiu do jogo). Espada de laser: R3 no chão / X.
	_tecla("sentar", [KEY_CTRL])
	_botao("sentar", JOY_BUTTON_DPAD_LEFT)
	_tecla("espada", [KEY_X])
	_botao("espada", JOY_BUTTON_RIGHT_STICK)
	# No voo, freia e desliga o motor; no chão, no ar e pairando, esquiva.
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
	# Marcar um ponto passou para a seta para baixo (o R1 agora joga granada).
	_tecla("marcar", [KEY_Q])
	_mouse("marcar", MOUSE_BUTTON_MIDDLE)
	_botao("marcar", JOY_BUTTON_DPAD_DOWN)
	# Roda de armas: segurar L1 / R (as teclas 1 a 6 trocam direto). Granada: R1 / G.
	_tecla("roda", [KEY_R])
	_botao("roda", JOY_BUTTON_LEFT_SHOULDER)
	_tecla("granada", [KEY_G])
	_botao("granada", JOY_BUTTON_RIGHT_SHOULDER)
	# A luz do peito (melhoria): seta para cima / L.
	_tecla("luz", [KEY_L])
	_botao("luz", JOY_BUTTON_DPAD_UP)
	# Entrar na oficina da base: quadrado / E. Scanner (melhoria): seta para a direita / T.
	_tecla("agir", [KEY_E])
	_botao("agir", JOY_BUTTON_X)
	_tecla("scanner", [KEY_T])
	_botao("scanner", JOY_BUTTON_DPAD_RIGHT)
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
