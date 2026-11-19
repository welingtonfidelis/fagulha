class_name Pane
extends CanvasLayer
## A pane do robô na tela: escurece, o dia avança algumas horas e clareia quando ele religa.
## Quem cria passa `armadura` e `ciclo` (pode ser null).

var armadura: Armadura
var ciclo: CicloDia
var saltos := 0  # quantas vezes o tempo saltou (testes)

var _preto: ColorRect
var _tw: Tween
var _texto: Label


func _ready() -> void:
	layer = 20
	_preto = ColorRect.new()
	_preto.color = Color(0.01, 0.012, 0.02, 0.0)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preto)
	_preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texto = Label.new()
	_texto.text = "curto no motor · voltando à base"
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.add_theme_font_size_override("font_size", 22)
	_texto.add_theme_color_override("font_color", Color(1.0, 0.62, 0.3))
	_texto.modulate.a = 0.0
	add_child(_texto)
	_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if armadura:
		armadura.entrou_pane.connect(_entrou)
		armadura.saiu_pane.connect(_saiu)


func _entrou() -> void:
	if _tw:
		_tw.kill()
	var tw := create_tween()
	_tw = tw
	tw.tween_interval(Ajustes.PANE_ESCURECE)
	tw.tween_property(_preto, "color:a", 1.0, 1.3)
	tw.parallel().tween_property(_texto, "modulate:a", 1.0, 1.3)
	tw.tween_callback(_saltar)


## Com a tela escura: o dia avança e as máquinas ganham o mesmo tempo (as desligadas esfriam).
func _saltar() -> void:
	saltos += 1
	var seg := 0.0
	if ciclo:
		ciclo.hora = fposmod(ciclo.hora + Ajustes.PANE_HORAS, 24.0)
		seg = Ajustes.PANE_HORAS / 24.0 * ciclo.minutos_por_dia * 60.0
	get_tree().call_group("maquinas", "avancar_tempo", seg)


func _saiu() -> void:
	if _tw:
		_tw.kill()
	var tw := create_tween()
	_tw = tw
	tw.tween_property(_preto, "color:a", 0.0, 1.6)
	tw.parallel().tween_property(_texto, "modulate:a", 0.0, 0.8)
