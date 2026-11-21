class_name TabletCasca
extends Control
## A casca do tablet como nó de tela (doc §136): desenha a casca, as telas de papel e a barra de cima, chama o
## `pintor` da tela que está aberta e põe o reflexo do vidro por cima de tudo (até dos botões filhos).
## Aberto: tamanho Tablet.TAM, telas Tablet.ESQ e Tablet.DIR. Fechado: o tamanho que quem usa der.
## O `pintor` recebe (casca, telas): telas é [esquerda, direita] aberto e [tela] fechado, em coordenadas da casca.

var aberto := true:
	set(v):
		aberto = v
		if aberto:
			size = Tablet.TAM
			custom_minimum_size = Tablet.TAM
		else:
			custom_minimum_size = Vector2.ZERO  # fechado: o tamanho é de quem usa (senão o mínimo prende no aberto)
		queue_redraw()
var rotulo := ""  # o nome na barra de cima
var cor_rotulo := Tablet.LARANJA_V
var rotulo_dir := ""  # no lugar da hora (ex.: o lugar de uma memória)
var barra := true
var pintor: Callable
var _vidro: Control


func _init() -> void:
	size = Tablet.TAM
	custom_minimum_size = Tablet.TAM
	_vidro = Control.new()
	_vidro.name = "vidro"
	_vidro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vidro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vidro.draw.connect(_pintar_vidro)
	add_child(_vidro, false, Node.INTERNAL_MODE_BACK)


func telas() -> Array:
	if aberto:
		return [Tablet.ESQ, Tablet.DIR]
	return [Tablet.tela_fechada(Rect2(Vector2.ZERO, size))]


func _process(_dt: float) -> void:
	if is_visible_in_tree():
		queue_redraw()
		_vidro.queue_redraw()


func _draw() -> void:
	var t: Array
	if aberto:
		t = Tablet.casca(self, Vector2.ZERO)
		if barra:
			Tablet.status(self, t[0], t[1], rotulo, cor_rotulo, rotulo_dir)
	else:
		t = [Tablet.casca_fechada(self, Rect2(Vector2.ZERO, size), barra)]
		if barra:
			Tablet.status(self, t[0], t[0], rotulo, cor_rotulo, rotulo_dir)
	if pintor.is_valid():
		pintor.call(self, t)


func _pintar_vidro() -> void:
	var t := telas()
	if aberto:
		Tablet.vidro(_vidro, t[0], t[1])
	else:
		var r: Rect2 = t[0]
		_vidro.draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 150, r.position.y), Vector2(r.end.x - 70, r.position.y), Vector2(r.end.x - 230, r.end.y), Vector2(r.end.x - 310, r.end.y)]), Color(1, 1, 1, 0.05))
