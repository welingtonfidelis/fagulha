class_name MapaCaderno
extends Control
## O mapa do caderno no tablet (2026-11-21): só o quadrado do mapa, no tamanho que quem usa der (`size`, p.ex. 394x394).
## O relevo vem do Vale, numa textura de 240 x 240 feita uma vez por execução (`_terra`); sem Vale, fica só o papel.
## Por cima entram os lugares vistos (com o nome), os acampamentos, os procurados, a base e o robô (a seta para
## onde ele olha) e a rosa dos ventos. Nada de legenda nem "você está em": a página do caderno desenha isso.
## Cada nome procura um lugar livre em volta do seu ponto, sem tampar outro nome nem um marcador.
## Quem cria chama `preparar(mapa, locais, robo, frente)` a cada abertura: refaz os pontos e os nomes, não a textura.

const T_NOME := 12
const RAIO := 14.0
const MIOLO := Color(0.1, 0.5, 0.52)
const CASA := Color(0.75, 0.45, 0.15)
const PAPEL := Color(0.94, 0.9, 0.8)
const LARANJA_ROBO := Color(1.0, 0.6, 0.2)
const VERDE_LIVRE := Color(0.3, 0.7, 0.35)
const VERMELHO := Color(0.9, 0.25, 0.2)
const COROA_VENCIDA := Color(0.3, 0.6, 0.35)
const COROA := Color(0.85, 0.2, 0.18)

static var _terra: ImageTexture  # o relevo, feito uma vez (57.600 alturas)

var _meta := Vale.F_META
var _pontos: Array = []  # [normalizado 0..1, nome] dos lugares vistos
var _camps: Array = []  # [normalizado, id] dos acampamentos
var _procs: Array = []  # [normalizado, id] dos procurados
var _base := Vector2.INF  # normalizado; INF quando não há base
var _robo := Vector2.INF  # normalizado; INF quando não há robô
var _olha := Vector2(0, -1)  # para onde o robô olha, no mapa (x, z)
var _nomes: Array = []  # [retângulo do nome, nome], já sem um tampar o outro


func _init() -> void:
	custom_minimum_size = Vector2(394, 394)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_arrumar()
		queue_redraw()


func preparar(mapa: Ilha, locais: Locais, robo: Vector3, frente := Vector3.FORWARD) -> void:
	if mapa is Vale:
		_meta = Vale.F_META
		if _terra == null:
			_terra = _fazer_terra(mapa as Vale)
	_pontos = []
	if locais:
		for it: Dictionary in locais.lista:
			if bool(it.get("visto", false)):
				var p: Vector3 = it["pos"]
				_pontos.append([_norm(p.x, p.z), String(it["nome"])])
	_camps = []
	for camp: Dictionary in Acampamentos.LISTA:
		var cp: Vector2 = camp["pos"]
		_camps.append([_norm(cp.x, cp.y), String(camp["id"])])
	_procs = []
	for pr: Dictionary in Procurados.LISTA:
		var pp: Vector2 = pr["pos"]
		_procs.append([_norm(pp.x, pp.y), String(pr["id"])])
	var bp: Vector3 = Melhorias.base if Melhorias.base.is_finite() else BaseVale.boca_cilindro
	_base = _norm(bp.x, bp.z) if bp.is_finite() else Vector2.INF
	_robo = _norm(robo.x, robo.z) if robo.is_finite() else Vector2.INF
	var d := Vector2(frente.x, frente.z)
	_olha = d.normalized() if d.length() >= 0.1 else Vector2(0, -1)
	_arrumar()
	queue_redraw()


## Mundo (x, z) para a posição normalizada no quadrado do mapa.
func _norm(x: float, z: float) -> Vector2:
	return Vector2((x + _meta) / (2.0 * _meta), (z + _meta) / (2.0 * _meta))


func _p(n: Vector2) -> Vector2:
	return n * size


func _fazer_terra(vale: Vale) -> ImageTexture:
	var n := 240
	var meta := Vale.F_META
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = vale.altura(-meta + (i + 0.5) * 2.0 * meta / n, -meta + (j + 0.5) * 2.0 * meta / n)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var h := hs[j * n + i]
			var cor: Color
			if h <= Vale.MAR + 0.3:
				var fundo := clampf((Vale.MAR - h) / 25.0, 0.0, 1.0)
				cor = Color(0.62, 0.84, 0.88).lerp(Color(0.36, 0.6, 0.78), fundo)
			elif h < Vale.MAR + 2.5:
				cor = Color(0.94, 0.87, 0.66)
			else:
				var t := clampf((h - Vale.MAR) / 150.0, 0.0, 1.0)
				if t < 0.45:
					cor = Color(0.66, 0.8, 0.5).lerp(Color(0.45, 0.65, 0.42), t / 0.45)
				elif t < 0.8:
					cor = Color(0.45, 0.65, 0.42).lerp(Color(0.62, 0.6, 0.5), (t - 0.45) / 0.35)
				else:
					cor = Color(0.62, 0.6, 0.5).lerp(Color(0.9, 0.9, 0.86), (t - 0.8) / 0.2)
				# o relevo: luz do noroeste
				var hn := hs[maxi(j - 1, 0) * n + maxi(i - 1, 0)]
				var luz := clampf((h - hn) * 0.035, -0.25, 0.25)
				cor = cor.lightened(luz) if luz > 0 else cor.darkened(-luz)
			img.set_pixel(i, j, cor)
	return ImageTexture.create_from_image(img)


## Escolhe onde cada nome fica: o primeiro lugar livre em volta do ponto. Os marcadores, a base, o robô, os
## acampamentos, os procurados e a rosa dos ventos contam como ocupados desde o começo.
func _arrumar() -> void:
	_nomes = []
	if size.x <= 0.0:
		return
	var nn := size - Vector2(26, 24)
	var ocupado: Array[Rect2] = [Rect2(nn.x - 18.0, nn.y - 32.0, 36.0, 50.0)]
	for c: Array in _camps:
		ocupado.append(Rect2(_p(c[0]) - Vector2(8, 8), Vector2(16, 16)))
	for c: Array in _procs:
		ocupado.append(Rect2(_p(c[0]) - Vector2(10, 10), Vector2(20, 20)))
	if _base.is_finite():
		ocupado.append(Rect2(_p(_base) - Vector2(12, 12), Vector2(24, 24)))
	if _robo.is_finite():
		ocupado.append(Rect2(_p(_robo) - Vector2(12, 12), Vector2(24, 24)))
	for pt: Array in _pontos:
		ocupado.append(Rect2(_p(pt[0]) - Vector2(6, 6), Vector2(12, 12)))
	for pt: Array in _pontos:
		_por_nome(_p(pt[0]), String(pt[1]), ocupado)


func _por_nome(p: Vector2, nome: String, ocupado: Array[Rect2]) -> void:
	var fonte := Tablet.fonte()
	var tam := Vector2(fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, T_NOME).x + 6.0, fonte.get_height(T_NOME))
	var meio := -tam.x * 0.5
	for o: Vector2 in [Vector2(meio, -tam.y - 6.0), Vector2(meio, 6.0), Vector2(9.0, -tam.y * 0.5), Vector2(-tam.x - 9.0, -tam.y * 0.5),
			Vector2(5.0, -tam.y - 4.0), Vector2(-tam.x - 5.0, -tam.y - 4.0), Vector2(5.0, 4.0), Vector2(-tam.x - 5.0, 4.0),
			Vector2(meio, -tam.y * 2.0 - 6.0), Vector2(meio, tam.y + 6.0)]:
		# perto da borda o nome encosta para dentro; se isso o puser em cima do próprio ponto, não serve
		var pos := (p + o).clamp(Vector2(2, 2), size - tam - Vector2(2, 2))
		var r := Rect2(pos, tam)
		var livre := true
		for q: Rect2 in ocupado:
			if q.intersects(r):
				livre = false
				break
		if livre:
			ocupado.append(r)
			_nomes.append([r, nome])
			return


func _draw() -> void:
	var fonte := Tablet.fonte()
	var quadro := Rect2(Vector2.ZERO, size)
	if _terra:
		draw_texture_rect(_terra, quadro, false)
	else:
		draw_rect(quadro, PAPEL)
	Tablet.cantos(self, quadro, RAIO, Tablet.TELA)
	_contorno(quadro, RAIO, Color(Tablet.TINTA, 0.3))
	# os lugares vistos, com o nome
	for pt: Array in _pontos:
		var q := _p(pt[0])
		draw_circle(q, 5.5, Color.WHITE)
		draw_circle(q, 3.8, MIOLO)
	var lp_fonte := fonte.get_ascent(T_NOME)
	for nm: Array in _nomes:
		var r: Rect2 = nm[0]
		var linha := r.position + Vector2(3.0, lp_fonte)
		draw_string_outline(fonte, linha, nm[1], HORIZONTAL_ALIGNMENT_LEFT, -1, T_NOME, 4, Color(1, 1, 1, 0.85))
		draw_string(fonte, linha, nm[1], HORIZONTAL_ALIGNMENT_LEFT, -1, T_NOME, Tablet.TINTA)
	# acampamentos (vermelho, ou verde quando já liberado)
	for c: Array in _camps:
		var q := _p(c[0])
		var cor := VERDE_LIVRE if Acampamentos.livres.has(c[1]) else VERMELHO
		draw_circle(q, 7.5, Color.WHITE)
		draw_circle(q, 5.5, cor)
	# procurados (coroa vermelha, ou verde quando vencidos)
	for c: Array in _procs:
		var q := _p(c[0])
		draw_circle(q, 11.0, Color.WHITE)
		var venc := Procurados.vencidos.has(c[1])
		Icones.desenhar(self, "coroa", q, 0.5, COROA_VENCIDA if venc else COROA, 2.0)
	# a base: casinha laranja num círculo branco
	if _base.is_finite():
		var b := _p(_base)
		draw_circle(b, 11.0, Color.WHITE)
		_casinha(b)
	# o robô: seta com brilho, apontando para onde ele olha
	if _robo.is_finite():
		var r := _p(_robo)
		var d := _olha
		Tablet.brilho(self, r, 10.0, LARANJA_ROBO, 1.2)
		draw_colored_polygon(PackedVector2Array([r + d * 13, r + d.rotated(2.4) * 10, r - d * 4, r + d.rotated(-2.4) * 10]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([r + d * 10, r + d.rotated(2.4) * 7.5, r - d * 2.5, r + d.rotated(-2.4) * 7.5]), Tablet.LARANJA_V)
	# a rosa dos ventos, no canto de baixo à direita
	var nn := size - Vector2(26, 24)
	draw_circle(nn, 16.0, Color(1, 1, 1, 0.85))
	draw_colored_polygon(PackedVector2Array([nn + Vector2(0, -12), nn + Vector2(5, 0), nn + Vector2(-5, 0)]), Tablet.RUBI)
	draw_colored_polygon(PackedVector2Array([nn + Vector2(0, 12), nn + Vector2(5, 0), nn + Vector2(-5, 0)]), Color(Tablet.TINTA, 0.5))
	Tablet.texto(self, nn + Vector2(-5, -18), "N", 12, Tablet.TINTA, true)


func _casinha(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(7.5, -1), p + Vector2(-7.5, -1)]), CASA)
	draw_rect(Rect2(p.x - 5, p.y - 1, 10, 7), CASA)


## Uma linha fina de canto a canto, com os cantos arredondados (o mesmo raio do quadrado).
func _contorno(r: Rect2, raio: float, cor: Color) -> void:
	var centros: Array[Vector2] = [r.position + Vector2(raio, raio), Vector2(r.end.x - raio, r.position.y + raio),
			r.end - Vector2(raio, raio), Vector2(r.position.x + raio, r.end.y - raio)]
	var pts := PackedVector2Array()
	for k in 4:
		for i in 9:
			pts.append(centros[k] + Vector2.from_angle(PI + k * PI * 0.5 + i * PI * 0.5 / 8.0) * raio)
	pts.append(pts[0])
	draw_polyline(pts, cor, 1.0, true)
