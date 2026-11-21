class_name MapaCaderno
extends Control
## O desenho da ilha no caderno: o contorno da terra, a base, onde o robô está e só os lugares já visitados.
## Nada do que falta aparece. Quem cria chama `preparar(mapa, locais, robo)`.
## Desde 2026-11-20 o mapa é maior (500 px) e cada nome procura um lugar livre em volta do ponto (em cima,
## embaixo, ao lado, nas diagonais), sem tampar outro nome nem o robô e a base; se não couber, tenta com letra
## menor, e se nem assim couber o ponto fica sem nome.

const LADO := 500.0
const T_NOME := 15
const T_NOME_MENOR := 12
const AGUA := Color(0.35, 0.95, 0.85)
const LARANJA := Color(1.0, 0.62, 0.3)
const AREIA := Color(1.0, 0.82, 0.5)
const ESCURO := Color(0.03, 0.05, 0.06)

var _terra: ImageTexture
var _pontos: Array = []  # [posição no desenho, nome]
var _nomes: Array = []  # [retângulo do nome, nome, tamanho da letra], já sem um tampar o outro
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
			# a terra, numa grade de 160 x 160 (uns 19 m por ponto)
			var n := 160
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
	_arrumar_nomes()
	queue_redraw()


## Escolhe onde cada nome fica: o primeiro lugar livre em volta do ponto. Os marcadores e o "N" contam como
## ocupados desde o começo, para nenhum nome cair em cima deles.
func _arrumar_nomes() -> void:
	_nomes = []
	var fonte := ThemeDB.fallback_font
	var ocupado: Array[Rect2] = [Rect2(LADO * 0.5 - 12.0, 0.0, 24.0, 26.0)]
	for pt: Array in _pontos:
		ocupado.append(Rect2(pt[0] - Vector2(5, 5), Vector2(10, 10)))
	if _robo.is_finite():
		ocupado.append(Rect2(_robo - Vector2(10, 10), Vector2(20, 20)))
	if _base.is_finite():
		ocupado.append(Rect2(_base - Vector2(11, 12), Vector2(22, 21)))
	var sobrou: Array = []
	for pt: Array in _pontos:
		if not _por_nome(pt, T_NOME, fonte, ocupado):
			sobrou.append(pt)
	for pt: Array in sobrou:
		_por_nome(pt, T_NOME_MENOR, fonte, ocupado)


func _por_nome(pt: Array, tamanho: int, fonte: Font, ocupado: Array[Rect2]) -> bool:
	var p: Vector2 = pt[0]
	var nome: String = pt[1]
	var tam := Vector2(fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + 6.0, fonte.get_height(tamanho))
	var meio := -tam.x * 0.5
	for o: Vector2 in [Vector2(meio, -tam.y - 6.0), Vector2(meio, 6.0), Vector2(9.0, -tam.y * 0.5), Vector2(-tam.x - 9.0, -tam.y * 0.5),
			Vector2(5.0, -tam.y - 4.0), Vector2(-tam.x - 5.0, -tam.y - 4.0), Vector2(5.0, 4.0), Vector2(-tam.x - 5.0, 4.0),
			Vector2(meio, -tam.y * 2.0 - 6.0), Vector2(meio, tam.y + 6.0)]:
		# perto da borda o nome encosta para dentro; se isso o puser em cima do próprio ponto, não serve
		var pos := (p + o).clamp(Vector2(2, 2), Vector2(LADO, LADO) - tam - Vector2(2, 2))
		var r := Rect2(pos, tam)
		var livre := true
		for q: Rect2 in ocupado:
			if q.intersects(r):
				livre = false
				break
		if livre:
			ocupado.append(r)
			_nomes.append([r, nome, tamanho])
			return true
	return false


func _draw() -> void:
	var fonte := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(LADO, LADO)), Color(0.05, 0.09, 0.1))
	if _terra:
		draw_texture_rect(_terra, Rect2(Vector2.ZERO, Vector2(LADO, LADO)), false)
	draw_rect(Rect2(Vector2.ZERO, Vector2(LADO, LADO)), Color(0.2, 0.3, 0.31), false, 2.0)
	draw_string_outline(fonte, Vector2(LADO * 0.5 - 6.0, 20.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, ESCURO)
	draw_string(fonte, Vector2(LADO * 0.5 - 6.0, 20.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.6))
	for pt: Array in _pontos:
		draw_circle(pt[0], 5.0, ESCURO)
		draw_circle(pt[0], 3.6, AGUA)
	for nm: Array in _nomes:
		var r: Rect2 = nm[0]
		var tamanho: int = nm[2]
		var linha := r.position + Vector2(3.0, fonte.get_ascent(tamanho))
		draw_string_outline(fonte, linha, nm[1], HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, 4, ESCURO)
		draw_string(fonte, linha, nm[1], HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, Color(0.93, 0.96, 0.95, 0.92))
	if _base.is_finite():
		var casa := PackedVector2Array([_base + Vector2(0, -10), _base + Vector2(9.5, -1.5), _base + Vector2(-9.5, -1.5)])
		draw_polyline(casa + PackedVector2Array([casa[0]]), ESCURO, 3.0, true)
		draw_colored_polygon(casa, AREIA)
		draw_rect(Rect2(_base.x - 6.5, _base.y - 1.5, 13.0, 9.0), ESCURO, false, 2.0)
		draw_rect(Rect2(_base.x - 6.5, _base.y - 1.5, 13.0, 9.0), AREIA)
	if _robo.is_finite():
		draw_circle(_robo, 8.5, ESCURO)
		draw_circle(_robo, 6.5, LARANJA)
		draw_circle(_robo, 2.4, ESCURO)
