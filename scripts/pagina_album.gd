class_name PaginaAlbum
extends Control
## A página do álbum no caderno (1.1, doc §136), no tablet dobrável. Ela é um Control do tamanho do tablet
## (Tablet.TAM), que a pausa põe como filho da TabletCasca em (0,0). Não desenha a casca, a barra de cima, as
## abas nem o rodapé: isso é da pausa. Esquerda: os grupos de Album.entradas() e as fotos soltas, em polaroides,
## numa lista sem barra que rola até o cartão em foco. Direita: a polaroide grande do cartão em foco, o nome, a
## hora da foto, quantas páginas têm foto e como fotografar.

const COLUNAS := 4
const CARTAO := Vector2(90, 106)
const ESPACO := 8
const POLA := 84.0  # a largura da polaroide pequena, dentro do cartão
const AREA := Rect2(34, 134, 404, 660)  # a lista da esquerda, em coordenadas do tablet
const LILAS_E := Color(0.434, 0.336, 0.595)  # o nome de cada grupo: lilás escuro
const SEGMENTOS := 13  # as barrinhas do progresso do álbum

var cartoes: Array = []  # testes: os botões das fotos, na ordem dos grupos
var _rolar: ScrollContainer
var _lista: VBoxContainer
var _nome := ""  # o cartão em foco
var _tex: Texture2D
var _sub := ""
var _com := 0  # páginas com foto
var _total := 0  # páginas no total


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Tablet.TAM
	custom_minimum_size = Tablet.TAM
	var vazio := StyleBoxEmpty.new()
	_rolar = ScrollContainer.new()
	_rolar.position = AREA.position
	_rolar.size = AREA.size
	_rolar.custom_minimum_size = AREA.size
	_rolar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolar.follow_focus = true
	_rolar.add_theme_stylebox_override("panel", vazio)
	var barra := _rolar.get_v_scroll_bar()
	for estilo in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		barra.add_theme_stylebox_override(estilo, vazio)
	add_child(_rolar)
	var margem := MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 8)
	_rolar.add_child(margem)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 6)
	margem.add_child(_lista)


## Refaz a lista (as fotos podem ter mudado) e devolve o primeiro cartão, para receber o foco.
func montar() -> Control:
	for velho in _lista.get_children():
		_lista.remove_child(velho)
		velho.queue_free()
	cartoes.clear()
	var grupos: Array = Album.entradas()
	var soltas: Array = []
	for i in Album.soltas.size():
		soltas.append(["solta_%d" % i, "foto %d" % (i + 1)])
	if not soltas.is_empty():
		grupos.append(["FOTOS SOLTAS", soltas])
	var com := 0
	var primeiro: Control = null
	for g: Array in grupos:
		if _lista.get_child_count() > 0:
			var folga := Control.new()
			folga.custom_minimum_size = Vector2(0, 12)
			_lista.add_child(folga)
		_lista.add_child(_titulo(_nome_grupo(String(g[0]))))
		var grade := GridContainer.new()
		grade.columns = COLUNAS
		grade.add_theme_constant_override("h_separation", ESPACO)
		grade.add_theme_constant_override("v_separation", ESPACO)
		_lista.add_child(grade)
		for e: Array in g[1]:
			var id := String(e[0])
			var nome := String(e[1])
			var solta := id.begins_with("solta_")
			var caminho := ""
			var hora := -1.0
			if solta:
				caminho = String(Album.soltas[int(id.trim_prefix("solta_"))])
			elif Album.paginas.has(id):
				var p: Dictionary = Album.paginas[id]
				caminho = String(p["foto"])
				hora = float(p.get("hora", -1.0))
				com += 1
			var tex := Album.textura(caminho)
			var c := BotaoTablet.new()
			c.estilo = "livre"
			c.text = nome
			c.custom_minimum_size = CARTAO
			c.pintor = _pintar_cartao.bind(tex, nome)
			c.mouse_entered.connect(c.grab_focus)
			c.focus_entered.connect(_mostrar.bind(nome, tex, hora, solta))
			grade.add_child(c)
			cartoes.append(c)
			if primeiro == null:
				primeiro = c
	_com = com
	_total = Album.total()
	_mostrar("", null, -1.0, false)
	_rolar.scroll_vertical = 0
	queue_redraw()
	return primeiro


func _mostrar(nome: String, tex: Texture2D, hora: float, solta: bool) -> void:
	_nome = nome
	_tex = tex
	if nome == "":
		_sub = ""
	elif tex == null:
		_sub = "ainda sem foto"
	elif solta:
		_sub = "uma foto sem página"
	elif hora < 0.0:
		_sub = "foto guardada"
	else:
		_sub = "foto %s, às %02d:%02d" % [_quando(hora), int(hora), int(fmod(hora, 1.0) * 60.0)]
	queue_redraw()


func _draw() -> void:
	var d := Tablet.DIR
	var x := d.position.x
	var y := d.position.y
	Tablet.texto(self, Vector2(x + 24, y + 90), "Álbum da ilha", 26, Tablet.TINTA, true)
	# a foto escolhida, grande e meio torta, como colada no caderno, com a fita adesiva em cima
	_desenhar_polaroide(self, Vector2(d.get_center().x, y + 290), 300.0, _tex, "", -0.04)
	draw_set_transform(Vector2(d.get_center().x - 6, y + 124), -0.1, Vector2.ONE)
	draw_rect(Rect2(-46, -12, 92, 24), Color(0.98, 0.9, 0.6, 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Tablet.texto(self, Vector2(x + 24, y + 500), _nome, 24, Tablet.TINTA, true)
	Tablet.texto(self, Vector2(x + 24, y + 524), _sub, 15, Color(Tablet.TINTA, 0.6))
	# quantas páginas têm foto, com as barrinhas lilás
	var cont := Rect2(x + 16, y + 548, d.size.x - 32, 62)
	Tablet.caixa(self, cont, Color(Tablet.TINTA, 0.06), 16)
	Tablet.icone(self, "album", cont.position + Vector2(32, 31), 28, Tablet.TINTA, Tablet.TELA)
	var conta := "%d de %d páginas" % [_com, _total]
	Tablet.texto(self, cont.position + Vector2(58, 38), conta, 18, Tablet.TINTA, true)
	var ini := cont.position.x + maxf(218.0, 58.0 + Tablet.largura(conta, 18, true) + 22.0)
	var passo := minf(11.0, (cont.end.x - 16.0 - ini) / SEGMENTOS)
	var acesos := maxi(1, roundi(float(_com) * SEGMENTOS / maxf(1.0, float(_total)))) if _com > 0 else 0
	for k in SEGMENTOS:
		Tablet.caixa(self, Rect2(ini + k * passo, cont.position.y + 25, 8, 12), Tablet.LILAS if k < acesos else Color(Tablet.TINTA, 0.15), 3)
	# como fotografar
	var como := Rect2(x + 16, y + 622, d.size.x - 32, 66)
	Tablet.caixa(self, como, Color(Tablet.LILAS, 0.12), 16)
	Tablet.texto(self, como.position + Vector2(16, 26), "para fotografar", 13, Color(Tablet.TINTA, 0.6))
	Tablet.com_botoes(self, como.position + Vector2(16, 52), "{@dir} scanner ou {@esq} vista  ·  {@tri} foto", 15, Tablet.TINTA)


## O cartão de uma foto: a polaroide pequena, com a borda laranja quando tem o foco.
static func _pintar_cartao(c: CanvasItem, r: Rect2, foco: bool, _sobre: bool, tex: Texture2D, nome: String) -> void:
	var altura := POLA * 1.12
	_desenhar_polaroide(c, Vector2(r.size.x * 0.5, 2.0 + altura * 0.5), POLA, tex, nome, 0.0, foco)


## Uma polaroide: a moldura branca com a sombra, a foto (ou um "?" apagado) e a legenda embaixo.
static func _desenhar_polaroide(c: CanvasItem, centro: Vector2, w: float, tex: Texture2D, legenda: String, ang := 0.0, sel := false) -> void:
	c.draw_set_transform(centro, ang, Vector2.ONE)
	var h := w * 1.12
	var r := Rect2(-w * 0.5, -h * 0.5, w, h)
	Tablet.caixa(c, Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.18), 4)
	Tablet.caixa(c, r, Color.WHITE, 4, Tablet.LARANJA if sel else Color(Tablet.TINTA, 0.12), 3 if sel else 1)
	var fr := Rect2(r.position + Vector2(w * 0.07, w * 0.07), Vector2(w * 0.86, w * 0.74))
	if tex:
		_capa(c, tex, fr)
	else:
		Tablet.caixa(c, fr, Color(Tablet.TINTA, 0.08), 2)
		Tablet.texto(c, Vector2(fr.position.x, fr.get_center().y + w * 0.1), "?", int(w * 0.3), Color(Tablet.TINTA, 0.25), true, HORIZONTAL_ALIGNMENT_CENTER, fr.size.x)
	if legenda != "":
		var tam := maxi(11, int(w * 0.12))
		if Tablet.largura(legenda, tam) > w - 6.0:
			tam = 10
		if Tablet.largura(legenda, tam) > w - 6.0:
			tam = 9
		Tablet.texto(c, Vector2(r.position.x, r.end.y - w * 0.09), legenda, tam, Tablet.TINTA if tex else Color(Tablet.TINTA, 0.45), false, HORIZONTAL_ALIGNMENT_CENTER, w)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A foto preenchendo o quadro, cortada no meio (como COVERED).
static func _capa(c: CanvasItem, tex: Texture2D, r: Rect2) -> void:
	var s := tex.get_size()
	var a := r.size.x / r.size.y
	var src: Rect2
	if s.x / s.y > a:
		src = Rect2((s.x - s.y * a) * 0.5, 0.0, s.y * a, s.y)
	else:
		src = Rect2(0.0, (s.y - s.x / a) * 0.5, s.x, s.x / a)
	c.draw_texture_rect_region(tex, r, src)


func _titulo(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", Tablet.negrito())
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", LILAS_E)
	return l


## "BICHOS" vira "Bichos", "CENAS RARAS" vira "Cenas raras".
static func _nome_grupo(s: String) -> String:
	return s.substr(0, 1) + s.substr(1).to_lower()


static func _quando(h: float) -> String:
	if h < 0.0:
		return ""
	if h >= 5.0 and h < 12.0:
		return "de manhã"
	if h >= 12.0 and h < 18.0:
		return "de tarde"
	if h >= 18.0 and h < 20.0:
		return "no fim da tarde"
	return "de noite"
