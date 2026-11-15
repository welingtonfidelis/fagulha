class_name Pausa
extends CanvasLayer
## Pausa (Esc / Options): continuar, voltar ao começo e sair, com a lista de comandos.

var armadura: Armadura
var _painel: PanelContainer
var _primeiro: Button


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
	_botao(caixa, "Próximo mapa: " + NOMES_MAPA[_proximo_mapa()], _trocar_mapa)
	_botao(caixa, "Sair do jogo", func() -> void: get_tree().quit())
	var ajuda := Label.new()
	ajuda.add_theme_font_size_override("font_size", 15)
	ajuda.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	ajuda.text = "\n".join([
		"Controle",
		"  analógico esquerdo: andar · L3: correr / arrancada no voo",
		"  X: pular · X no ar: pulo duplo · segure X: decolar / ligar o voo · X no voo: planar ↔ motor",
		"  O: esquiva (no voo: soltar) · L2: mirar (no ar: pairar) · R2: atirar · R1: marcar um ponto",
		"  analógico direito: olhar e mirar o voo · Options: pausa · Create: medidor",
		"",
		"Teclado e mouse",
		"  WASD: andar · Shift: correr / arrancada · Espaço: pular, pulo duplo, decolar, voar, planar",
		"  C: esquiva (no voo: soltar) · botão direito: mirar / pairar · botão esquerdo: atirar · Q: marcar",
		"  mouse: olhar · Esc: pausa · F3: medidor",
		"",
		"Calor: subir e acelerar esquentam; planar, mergulhar e passar rente à água esfriam.",
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


func _continuar() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


const NOMES_MAPA := {"clareira": "a clareira (novo rumo)", "mundo": "a ilha de 4 km", "ilha": "ilha de teste antiga", "canion": "cânion realista", "canion_b": "cânion pintado"}


func _proximo_mapa() -> String:
	var ordem := ["clareira", "mundo", "canion_b", "canion", "ilha"]
	return ordem[(ordem.find(Main.mapa) + 1) % ordem.size()]


func _trocar_mapa() -> void:
	Main.mapa = _proximo_mapa()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _voltar() -> void:
	_continuar()
	if armadura:
		armadura.recomecar()
