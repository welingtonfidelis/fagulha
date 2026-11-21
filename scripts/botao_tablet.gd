class_name BotaoTablet
extends Button
## Um botão do tablet (doc §136): é um Button de verdade (foco, mouse, teclado, `pressed`), mas desenhado à mão
## no jeito do tablet. Estilos:
##   "opcao"  — a escolha grande de menu (figura num círculo, nome = `text`, explicação = `sub` ou o Label
##              filho "explica", se houver);
##   "pilula" — aba ou botão curto (`ativa` deixa cheio);
##   "livre"  — quem desenha é o `pintor`, chamado com (botão, retângulo, foco, mouse_por_cima).
## Desligado (`disabled`), fica meio apagado.

var estilo := "opcao"
var icone := ""
var cor := Tablet.LARANJA_V
var sub := ""
var perigo := false
var ativa := false
var pintor: Callable
var alfa_desligado := 0.45


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_text = true
	var vazio := StyleBoxEmpty.new()
	for s: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed", "normal_mirrored", "hover_mirrored", "pressed_mirrored", "disabled_mirrored", "hover_pressed_mirrored"]:
		add_theme_stylebox_override(s, vazio)
	for f: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(f, Color(0, 0, 0, 0))
	for sinal: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
		sinal.connect(queue_redraw)


func _process(_dt: float) -> void:
	if is_visible_in_tree():
		self_modulate.a = alfa_desligado if disabled else 1.0
		queue_redraw()


func explicacao() -> String:
	if sub != "":
		return sub
	var l := get_node_or_null("explica") as Label
	return l.text if l else ""


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var foco := has_focus()
	var sobre := is_hovered() and not disabled
	match estilo:
		"opcao":
			Tablet.opcao(self, r, icone, text, explicacao(), foco and not disabled, cor, perigo, sobre)
		"pilula":
			Tablet.pilula(self, r, icone, text, cor, ativa, foco)
		_:
			if pintor.is_valid():
				pintor.call(self, r, foco, sobre)
