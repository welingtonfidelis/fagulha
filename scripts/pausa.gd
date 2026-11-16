class_name Pausa
extends CanvasLayer
## Pausa (Esc / Options): continuar, voltar ao começo e sair, com a lista de comandos.

var armadura: Armadura
var _painel: PanelContainer
var _primeiro: Button
var _botao_vibra: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	_painel = PanelContainer.new()
	centro.add_child(_painel)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 12)
	_painel.add_child(caixa)
	var titulo := Label.new()
	titulo.text = "Pausa"
	titulo.add_theme_font_size_override("font_size", 28)
	caixa.add_child(titulo)
	_primeiro = _botao(caixa, "Continuar", _continuar)
	_botao(caixa, "Voltar ao começo", _voltar)
	_botao_vibra = _botao(caixa, "", func() -> void:
		Vibra.ligada = not Vibra.ligada
		_botao_vibra.text = "Vibração do controle: " + ("ligada" if Vibra.ligada else "desligada"))
	_botao_vibra.text = "Vibração do controle: " + ("ligada" if Vibra.ligada else "desligada")
	_botao(caixa, "Sair do jogo", func() -> void: get_tree().quit())
	var ajuda := Label.new()
	ajuda.add_theme_font_size_override("font_size", 15)
	ajuda.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	ajuda.text = "\n".join([
		"Controle",
		"  analógico esquerdo: andar · L3: correr · R3: abaixar (segure para sentar)",
		"  X: pular · X no ar: pulo duplo · segure o X num dos dois: decola reto e sai voando",
		"  L3 no ar: liga e desliga o voo · L2 mirando: o tiro trava na máquina perto da mira",
		"  na água funda ele nada: analógico vai para onde a câmera olha, X sobe (na tona: pula), O desce, L3 acelera",
		"  no voo, analógico esquerdo: frente acelera, trás segura, lado inclina e fecha a curva",
		"  O: esquiva (no voo: freia e desliga os jatos) · triângulo no ar: mergulho com impacto",
		"  L2 ou R3: parar no ar e mirar · R2: atirar · R1: marcar um ponto",
		"  analógico direito: olhar e guiar o voo · Options: pausa · Create: medidor",
		"",
		"Teclado e mouse",
		"  WASD: andar e acelerador do voo · Shift: correr (no ar: liga e desliga o voo) · Ctrl: abaixar",
		"  Espaço: pular, pulo duplo (segure: decola) · C: esquiva (no voo: freia e desliga) · V: mergulho · F: parar no ar",
		"  botão direito: mirar / parar no ar · botão esquerdo: atirar · Q: marcar · Esc: pausa · F3: medidor",
		"",
		"Calor: subir e acelerar esquentam; mergulhar, a chuva e passar rente à água esfriam.",
	])
	caixa.add_child(ajuda)
	visible = false


func _botao(pai: Control, texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(320, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(acao)
	pai.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if visible:
			_continuar()
		else:
			_abrir()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_continuar()
		get_viewport().set_input_as_handled()
	elif not visible and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _abrir() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_primeiro.grab_focus()


## Fecha o menu, mas o jogo só volta quando os botões do menu forem soltos: senão a bolinha que fecha a
## pausa também desligava o voo, e o X do "Continuar" também pulava.
func _continuar() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_saindo = true


var _saindo := false


func _process(_delta: float) -> void:
	if not _saindo:
		return
	if visible:
		_saindo = false
		return
	for acao in ["ui_cancel", "ui_accept", "soltar", "pular"]:
		if Input.is_action_pressed(acao):
			return
	_saindo = false
	get_tree().paused = false


func _voltar() -> void:
	_continuar()
	if armadura:
		armadura.recomecar()
