class_name Controles
extends RefCounted
## Ações de teclado, mouse e controle. Os nomes de botão seguem o controle de Xbox; no DualSense:
## A = X, B = círculo, X = quadrado, Y = triângulo, LEFT_STICK = L3, START = Options, BACK = Create/Share.
##
## Revisão de 2026-11-20 (para depender menos do clique dos analógicos): voar é segurar o X (do chão ou do
## ar), correr é empurrar o analógico até o fim, parar no ar é puxá-lo todo para trás, a espada foi para o
## quadrado e o "interagir" para o triângulo. O L3 e o R3 continuam fazendo o que faziam.
## Ainda em 2026-11-20 o L3 e o R3 ficaram sem ação (pedido do usuário): tudo o que faziam tem outro jeito no
## controle (correr e nadar rápido: analógico até o fim; parar no ar: L2 ou toque no X; cancelar o voo parado
## e ligar o voo no ar: segurar o X; cortar os jatos voando: toque no X e segurar o X). No teclado nada muda.

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

	# Pular / decolar / ligar o voo.
	_tecla("pular", [KEY_SPACE])
	_botao("pular", JOY_BUTTON_A)
	# Correr no chão e arrancada no voo: Shift segurado (no controle, o analógico até o fim). A ação de alternar
	# a corrida fica sem botão (era o L3), mas existe para as fotos.
	_tecla("correr", [KEY_SHIFT])
	_garantir("correr_alternar")
	# Ligar e desligar o voo, só no ar: Shift (no controle, segurar o X liga; toque e segurar o X desliga).
	_tecla("voar", [KEY_SHIFT])
	# Voo parado: F (no controle, o L2 ou um toque no X). Mergulho com impacto: triângulo / V.
	_tecla("pairar", [KEY_F])
	_tecla("golpe", [KEY_V])
	_botao("golpe", JOY_BUTTON_Y)
	# Apreciar a vista e sentar nos móveis: seta para a esquerda / Ctrl. Espada de laser: quadrado / X.
	_tecla("sentar", [KEY_CTRL])
	_botao("sentar", JOY_BUTTON_DPAD_LEFT)
	_tecla("espada", [KEY_X])
	_botao("espada", JOY_BUTTON_X)  # quadrado (era o R3 no chão, que mexia a câmera na hora do golpe)
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
	# Entrar na oficina da base e acordar robôs: triângulo no chão / E. Scanner (melhoria): seta para a direita / T.
	_tecla("agir", [KEY_E])
	_botao("agir", JOY_BUTTON_Y)  # triângulo no chão (no ar o triângulo é o mergulho com impacto)
	_tecla("scanner", [KEY_T])
	_botao("scanner", JOY_BUTTON_DPAD_RIGHT)
	# O caderno (mapa, memórias e o que o scanner leu) tem botão próprio, fora da pausa (pedido do usuário,
	# 2026-11-20): o clique no touchpad do DualSense / M.
	_tecla("caderno", [KEY_M])
	_botao("caderno", JOY_BUTTON_TOUCHPAD)
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
