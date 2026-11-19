class_name MapaCaderno
extends Control
## O desenho da ilha no caderno da pausa: o contorno da terra, a base, onde o robô está e só os lugares já
## visitados. Nada do que falta aparece. Quem cria chama `preparar(mapa, locais, robo)`.

const LADO := 330.0
const AGUA := Color(0.35, 0.95, 0.85)
const LARANJA := Color(1.0, 0.62, 0.3)

var _terra: ImageTexture
var _pontos: Array = []  # [posição no desenho, nome]
var _robo := Vector2.INF
var _base := Vector2.INF
var _meta := 1500.0


func _init() -> void:
	custom_minimum_size = Vector2(LADO, LADO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _no_desenho(x: float, z: float) -> Vector2:
	return Vector2((x + _meta) / (2.0 * _meta), (z + _meta) / (2.0 * _meta)) * LADO


func preparar(mapa: Ilha, locais: Locais, robo: Vector3) -> void:
	if mapa is Vale:
		_meta = Vale.F_META
		if _terra == null:
			# a terra, numa grade de 110 x 110 (uns 27 m por ponto)
			var n := 110
			var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
			for j in n:
				for i in n:
					var x := -_meta + (i + 0.5) * 2.0 * _meta / n
					var z := -_meta + (j + 0.5) * 2.0 * _meta / n
					var h := mapa.altura(x, z)
					var cor := Color(0.05, 0.09, 0.1)
					if h > Vale.MAR + 0.3:
						cor = Color(0.13, 0.2, 0.19).lerp(Color(0.24, 0.33, 0.29), clampf(h / 160.0, 0.0, 1.0))
					img.set_pixel(i, j, cor)
			_terra = ImageTexture.create_from_image(img)
	_pontos = []
	if locais:
		for it in locais.lista:
			if bool(it.get("visto", false)):
				var p: Vector3 = it["pos"]
				_pontos.append([_no_desenho(p.x, p.z), String(it["nome"])])
	_robo = _no_desenho(robo.x, robo.z)
	_base = _no_desenho(Melhorias.base.x, Melhorias.base.z) if Melhorias.base.is_finite() else Vector2.INF
	queue_redraw()


func _draw() -> void:
	var fonte := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(LADO, LADO)), Color(0.05, 0.09, 0.1))
	if _terra:
		draw_texture_rect(_terra, Rect2(Vector2.ZERO, Vector2(LADO, LADO)), false)
	draw_rect(Rect2(Vector2.ZERO, Vector2(LADO, LADO)), Color(0.2, 0.3, 0.31), false, 2.0)
	draw_string(fonte, Vector2(LADO * 0.5 - 4.0, 14.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
	for pt: Array in _pontos:
		var p: Vector2 = pt[0]
		draw_circle(p, 3.2, AGUA)
		var nome: String = pt[1]
		var w := fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(fonte, Vector2(clampf(p.x - w * 0.5, 2.0, LADO - w - 2.0), p.y - 6.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.93, 0.96, 0.95, 0.8))
	if _base.is_finite():
		draw_colored_polygon(PackedVector2Array([_base + Vector2(0, -7), _base + Vector2(6.5, -1), _base + Vector2(-6.5, -1)]), Color(1.0, 0.82, 0.5))
		draw_rect(Rect2(_base.x - 4.5, _base.y - 1.0, 9.0, 6.0), Color(1.0, 0.82, 0.5))
	if _robo.is_finite():
		draw_circle(_robo, 5.5, Color(0, 0, 0, 0.5))
		draw_circle(_robo, 4.0, LARANJA)
