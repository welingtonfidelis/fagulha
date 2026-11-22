class_name MapaCaderno
extends Control
## O mapa do caderno no tablet (2026-11-21): só o quadro do mapa, no tamanho que quem usa der (`size`, p.ex. 394x394).
## O relevo vem do Vale, numa textura que cobre o mundo todo, a ilha e a terra nova (`mundo`), feita uma vez por
## build e guardada no `Cache`; sem Vale, fica só o papel. Rios e lagos entram em azul-claro e a neve em branco.
## O mapa mostra um pedaço do mundo (`vista`): o mundo todo depois de `preparar`, ou o pedaço que `mostrar` der
## (pode passar da borda: o resto é mar). `pulsar` põe um anel no robô; sem `rosa`, fica sem a rosa dos ventos.
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
const N_TERRA := 720  # pixels de cada lado da textura do relevo: 7,5 m por pixel no mundo de 5,4 km
const AGUA_DOCE := Color(0.46, 0.73, 0.88)

static var _terra: ImageTexture  # o relevo do mundo todo (feito uma vez por build; depois vem do Cache)
static var mundo := Rect2(-Vale.F_META, -Vale.F_META, 2.0 * Vale.F_META, 2.0 * Vale.F_META)  # (x, z) que a textura cobre
static var ms_terra := -1  # quanto a textura levou para sair (testes)

var vista := Rect2()  # o pedaço do mundo (x, z) que este mapa mostra
var pulsar := false  # o robô com um anel que pulsa (no mapa grande)
var rosa := true  # a rosa dos ventos no canto de baixo à direita (a metade esquerda do mapa grande não tem)
static var _mar_fundo := Color(0.47, 0.71, 0.82)  # o mar fundo, para o que passa da borda do mundo
# tudo em (x, z) do mundo: a posição no quadro sai de `_norm` na hora (o pedaço mostrado muda com o zoom)
var _pontos: Array = []  # [posição, nome] dos lugares vistos
var _camps: Array = []  # [posição, id] dos acampamentos
var _procs: Array = []  # [posição, id] dos procurados
var _base := Vector2.INF  # INF quando não há base
var _robo := Vector2.INF  # INF quando não há robô
var _olha := Vector2(0, -1)  # para onde o robô olha, no mapa (x, z)
var _nomes: Array = []  # [retângulo do nome, nome], já sem um tampar o outro


func _init() -> void:
	custom_minimum_size = Vector2(394, 394)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_arrumar()
		queue_redraw()


func _process(_delta: float) -> void:
	if pulsar and is_visible_in_tree():
		queue_redraw()


## Faz (ou lê do Cache) o relevo do mundo. O Vale chama no fim da montagem, para o caderno não travar na primeira
## abertura (na primeira vez de cada build leva por volta de 1 s).
static func preparar_terra(v: Vale) -> void:
	var m := _mundo_de(v)
	if _terra == null or m != mundo:
		mundo = m
		_terra = _fazer_terra(v)


func preparar(mapa: Ilha, locais: Locais, robo: Vector3, frente := Vector3.FORWARD) -> void:
	if mapa is Vale:
		preparar_terra(mapa as Vale)
	vista = mundo
	_pontos = []
	if locais:
		for it: Dictionary in locais.lista:
			if bool(it.get("visto", false)):
				var p: Vector3 = it["pos"]
				_pontos.append([Vector2(p.x, p.z), String(it["nome"])])
	_camps = []
	for camp: Dictionary in Acampamentos.LISTA:
		var cp: Vector2 = camp["pos"]
		_camps.append([cp, String(camp["id"])])
	_procs = []
	for pr: Dictionary in Procurados.LISTA:
		var pp: Vector2 = pr["pos"]
		_procs.append([pp, String(pr["id"])])
	var bp: Vector3 = Melhorias.base if Melhorias.base.is_finite() else BaseVale.boca_cilindro
	_base = Vector2(bp.x, bp.z) if bp.is_finite() else Vector2.INF
	_robo = Vector2(robo.x, robo.z) if robo.is_finite() else Vector2.INF
	var d := Vector2(frente.x, frente.z)
	_olha = d.normalized() if d.length() >= 0.1 else Vector2(0, -1)
	_arrumar()
	queue_redraw()


## Mostra este pedaço do mundo (x, z); pode passar da borda do mundo (o resto é mar).
func mostrar(v: Rect2) -> void:
	vista = v
	_arrumar()
	queue_redraw()


## Mundo (x, z) para a posição normalizada no quadro (0 a 1 no pedaço mostrado).
func _norm(x: float, z: float) -> Vector2:
	return (Vector2(x, z) - vista.position) / vista.size if vista.has_area() else Vector2(0.5, 0.5)


## Mundo (x, z) direto para o pixel no quadro.
func _p(w: Vector2) -> Vector2:
	return _norm(w.x, w.y) * size


func _dentro(w: Vector2) -> bool:
	var n := _norm(w.x, w.y)
	return n.x >= -0.01 and n.x <= 1.01 and n.y >= -0.01 and n.y <= 1.01


## O quadrado que cobre a ilha e, se houver, a terra nova (que vai para o oeste e para o norte).
static func _mundo_de(v: Vale) -> Rect2:
	var a := Vector2(-Vale.F_META, -Vale.F_META)
	var b := Vector2(Vale.F_META, Vale.F_META)
	if v.terra_nova:
		a = a.min(Vector2(TerraNova.X0, TerraNova.Z0))
	var lado := maxf(b.x - a.x, b.y - a.y)
	return Rect2(a, Vector2(lado, lado))


static func _fazer_terra(v: Vale) -> ImageTexture:
	var t0 := Time.get_ticks_msec()
	var n := N_TERRA
	var img: Image
	var guardado: Variant = Cache.ler("mapa_caderno")
	if guardado is Dictionary and (guardado as Dictionary).get("mundo") == mundo and (guardado as Dictionary).get("n") == n:
		img = Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, guardado["dados"])
	else:
		img = _pintar_terra(v, n)
		Cache.gravar("mapa_caderno", {"mundo": mundo, "n": n, "dados": img.get_data()})
	_mar_fundo = img.get_pixel(1, 1)
	ms_terra = Time.get_ticks_msec() - t0
	return ImageTexture.create_from_image(img)


static func _pintar_terra(v: Vale, n: int) -> Image:
	var passo := mundo.size.x / n
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var doce := PackedByteArray()  # 1 onde há rio, lago ou poça acima do mar
	doce.resize(n * n)
	for j in n:
		var z := mundo.position.y + (j + 0.5) * passo
		for i in n:
			var x := mundo.position.x + (i + 0.5) * passo
			var h := v.altura(x, z)
			hs[j * n + i] = h
			if h > Vale.MAR + 0.3 and v.agua(x, z) > h + 0.05:
				doce[j * n + i] = 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var relevo := 0.035 * 12.5 / passo  # a força da sombra era medida em pixels de 12,5 m
	for j in n:
		for i in n:
			var h := hs[j * n + i]
			var cor: Color
			if h <= Vale.MAR + 0.3:
				var fundo := clampf((Vale.MAR - h) / 25.0, 0.0, 1.0)
				cor = Color(0.62, 0.84, 0.88).lerp(Color(0.36, 0.6, 0.78), fundo)
			elif doce[j * n + i] == 1:
				cor = AGUA_DOCE
			elif h < Vale.MAR + 2.5:
				cor = Color(0.94, 0.87, 0.66)
			else:
				# capim até uns 70 m, mata mais escura até 120, pedra até a linha da neve (~420 m) e neve acima
				if h < 67.5:
					cor = Color(0.66, 0.8, 0.5).lerp(Color(0.45, 0.65, 0.42), h / 67.5)
				elif h < 120.0:
					cor = Color(0.45, 0.65, 0.42).lerp(Color(0.62, 0.6, 0.5), (h - 67.5) / 52.5)
				elif h < 420.0:
					cor = Color(0.62, 0.6, 0.5).lerp(Color(0.6, 0.6, 0.6), (h - 120.0) / 300.0)
				else:
					cor = Color(0.6, 0.6, 0.6).lerp(Color(0.95, 0.95, 0.97), clampf((h - 420.0) / 50.0, 0.0, 1.0))
				# o relevo: luz do noroeste
				var hn := hs[maxi(j - 1, 0) * n + maxi(i - 1, 0)]
				var luz := clampf((h - hn) * relevo, -0.25, 0.25)
				cor = cor.lightened(luz) if luz > 0 else cor.darkened(-luz)
			img.set_pixel(i, j, cor)
	# as fontes quentes, para se acharem no mapa: o miolo azul e a beira laranja
	if v.terra_nova:
		for f: Array in v.terra_nova.fontes:
			var c: Vector2 = f[0]
			var r: float = f[1]
			var de := ((c - Vector2(r + 10.0, r + 10.0) - mundo.position) / passo).floor()
			var ate := ((c + Vector2(r + 10.0, r + 10.0) - mundo.position) / passo).ceil()
			for j in range(maxi(int(de.y), 0), mini(int(ate.y), n - 1) + 1):
				for i in range(maxi(int(de.x), 0), mini(int(ate.x), n - 1) + 1):
					var d := (mundo.position + (Vector2(i, j) + Vector2(0.5, 0.5)) * passo).distance_to(c)
					if d < r * 0.8:
						img.set_pixel(i, j, Color(0.12, 0.45, 0.72))
					elif d < r + 7.5:
						img.set_pixel(i, j, Color(0.9, 0.5, 0.18))
	return img


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
		ocupado.append(Rect2(_p(_robo) - Vector2(16, 16), Vector2(32, 32)))
	for pt: Array in _pontos:
		ocupado.append(Rect2(_p(pt[0]) - Vector2(6, 6), Vector2(12, 12)))
	for pt: Array in _pontos:
		if _dentro(pt[0]):
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
	if _terra and vista.has_area():
		draw_rect(quadro, _mar_fundo)
		var parte := vista.intersection(mundo)
		if parte.has_area():
			var px := Vector2(_terra.get_width(), _terra.get_height()) / mundo.size
			var a := (parte.position - vista.position) / vista.size * size
			var b := (parte.end - vista.position) / vista.size * size
			draw_texture_rect_region(_terra, Rect2(a, b - a), Rect2((parte.position - mundo.position) * px, parte.size * px))
	else:
		draw_rect(quadro, PAPEL)
	Tablet.cantos(self, quadro, RAIO, Tablet.TELA)
	_contorno(quadro, RAIO, Color(Tablet.TINTA, 0.3))
	# os lugares vistos, com o nome
	for pt: Array in _pontos:
		if not _dentro(pt[0]):
			continue
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
		if not _dentro(c[0]):
			continue
		var q := _p(c[0])
		var cor := VERDE_LIVRE if Acampamentos.livres.has(c[1]) else VERMELHO
		draw_circle(q, 7.5, Color.WHITE)
		draw_circle(q, 5.5, cor)
	# procurados (coroa vermelha, ou verde quando vencidos)
	for c: Array in _procs:
		if not _dentro(c[0]):
			continue
		var q := _p(c[0])
		draw_circle(q, 11.0, Color.WHITE)
		var venc := Procurados.vencidos.has(c[1])
		Icones.desenhar(self, "coroa", q, 0.5, COROA_VENCIDA if venc else COROA, 2.0)
	# a base: casinha laranja num círculo branco
	if _base.is_finite() and _dentro(_base):
		var b := _p(_base)
		draw_circle(b, 11.0, Color.WHITE)
		_casinha(b)
	# o robô: seta com brilho, apontando para onde ele olha
	if _robo.is_finite() and _dentro(_robo):
		var r := _p(_robo)
		var d := _olha
		if pulsar:
			# um anel que abre e some, para o olho achar o robô
			var f := fmod(Time.get_ticks_msec() / 1400.0, 1.0)
			draw_arc(r, 14.0 + f * 26.0, 0.0, TAU, 40, Color(LARANJA_ROBO, 0.85 * (1.0 - f)), 4.0, true)
			draw_circle(r, 15.0, Color(1, 1, 1, 0.55))
		Tablet.brilho(self, r, 10.0, LARANJA_ROBO, 1.2)
		draw_colored_polygon(PackedVector2Array([r + d * 13, r + d.rotated(2.4) * 10, r - d * 4, r + d.rotated(-2.4) * 10]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([r + d * 10, r + d.rotated(2.4) * 7.5, r - d * 2.5, r + d.rotated(-2.4) * 7.5]), Tablet.LARANJA_V)
	# a rosa dos ventos, no canto de baixo à direita
	if not rosa:
		return
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
