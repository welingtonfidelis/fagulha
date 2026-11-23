class_name Tablet
extends RefCounted
## O tablet dobrável do robô (doc §136, 2026-11-21). O usuário achou a oficina feia e pouco amiga e escolheu,
## entre os rascunhos, o caderno; depois pediu o mesmo jeito num tablet dobrável, e o mesmo padrão em todas as
## telas: casca branca com friso azul (as cores do robô), telas cor de papel com pontinhos, figuras grandes e
## letra escura. Aqui ficam as medidas e os pincéis comuns; quem monta cada tela é a própria tela.
## Tablet aberto: 916 x 830, com a tela da esquerda em ESQ e a da direita em DIR (coordenadas do tablet).
## Tablet fechado: uma tela só, para avisos e perguntas (`casca_fechada`).

const TELA := Color(0.97, 0.94, 0.87)
const CASCA := Color(0.91, 0.93, 0.96)
const FRISO := Color(0.2, 0.45, 0.9)
const MOLDURA := Color(0.1, 0.11, 0.13)
const TINTA := Color(0.18, 0.22, 0.27)
const LARANJA := Color(0.92, 0.5, 0.15)  # letra e borda
const LARANJA_V := Color(0.95, 0.55, 0.2)  # preenchimento
const AZUL := Color(0.35, 0.58, 0.85)
const VERDE := Color(0.45, 0.7, 0.4)
const LILAS := Color(0.62, 0.48, 0.85)
const RUBI := Color(0.82, 0.25, 0.2)
const AMBAR := Color(0.85, 0.5, 0.12)
const OK := Color(0.22, 0.55, 0.32)
const AGUA := Color(0.3, 0.65, 0.65)
const CINZA := Color(0.5, 0.52, 0.56)
const PLANTA := Color(0.11, 0.2, 0.36)
const CLARO := Color(1.0, 0.72, 0.3, 0.3)  # o fundo de quem tem o foco

const TAM := Vector2(916, 830)
const ESQ := Rect2(22, 24, 418, 782)
const DIR := Rect2(476, 24, 418, 782)

static var hora := 12.0  # a hora do jogo, para a barra de cima (o CicloDia escreve)
static var _f: Font
static var _fb: FontVariation


static func fonte() -> Font:
	if _f == null:
		_f = ThemeDB.fallback_font
	return _f


static func negrito() -> Font:
	if _fb == null:
		_fb = FontVariation.new()
		_fb.base_font = fonte()
		_fb.variation_embolden = 0.7
	return _fb


static func largura(s: String, tam: int, forte := false) -> float:
	return (negrito() if forte else fonte()).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


# ------------------------------------------------------------------ o básico

static func caixa(c: CanvasItem, r: Rect2, cor: Color, raio := 10, borda := Color(0, 0, 0, 0), lw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	sb.anti_aliasing = true
	if lw > 0:
		sb.border_color = borda
		sb.set_border_width_all(lw)
	sb.draw(c.get_canvas_item(), r)


static func texto(c: CanvasItem, pos: Vector2, s: String, tam: int, cor: Color, forte := false, alinh := HORIZONTAL_ALIGNMENT_LEFT, larg := -1.0) -> void:
	c.draw_string(negrito() if forte else fonte(), pos, s, alinh, larg, tam, cor)


## O maior tamanho de letra (de `tam` para baixo, até `minimo`) em que `s` cabe numa linha de `larg`.
static func caber(s: String, larg: float, tam: int, forte := false, minimo := 18) -> int:
	while tam > minimo and largura(s, tam, forte) > larg:
		tam -= 1
	return tam


static func paragrafo(c: CanvasItem, pos: Vector2, s: String, larg: float, tam: int, cor: Color, linhas := -1, alinh := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_multiline_string(fonte(), pos, s, alinh, larg, tam, linhas, cor)


static func altura_paragrafo(s: String, larg: float, tam: int) -> float:
	return fonte().get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, larg, tam).y


static func brilho(c: CanvasItem, centro: Vector2, raio: float, cor: Color, forca := 1.0) -> void:
	for i in 7:
		c.draw_circle(centro, raio * (1.0 + i * 0.22), Color(cor, 0.07 * forca))


## Cantos redondos por cima de um desenho quadrado: pinta o lado de fora do canto com `cor`.
static func cantos(c: CanvasItem, r: Rect2, raio: float, cor: Color) -> void:
	for k in 4:
		var canto: Vector2 = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)][k]
		var centro: Vector2 = canto + Vector2(raio if k == 0 or k == 3 else -raio, raio if k < 2 else -raio)
		var a0: float = [PI, PI * 1.5, 0.0, PI * 0.5][k]
		var pts := PackedVector2Array([canto])
		for i in 9:
			pts.append(centro + Vector2.from_angle(a0 + i * (PI * 0.5) / 8.0) * raio)
		c.draw_colored_polygon(pts, cor)


# ------------------------------------------------------------------ a casca e as telas

## Uma tela: papel com pontinhos, a moldura escura, a linha da barra de cima e o risquinho de baixo.
static func tela(c: CanvasItem, r: Rect2, barra := true) -> void:
	caixa(c, r.grow(3), MOLDURA, 20)
	caixa(c, r, TELA, 18)
	var y := r.position.y + (52.0 if barra else 22.0)
	while y < r.end.y - 24:
		var x := r.position.x + 18.0
		while x < r.end.x - 10:
			c.draw_circle(Vector2(x, y), 1.1, Color(TINTA, 0.13))
			x += 24.0
		y += 24.0
	if barra:
		c.draw_line(Vector2(r.position.x + 16, r.position.y + 40), Vector2(r.end.x - 16, r.position.y + 40), Color(TINTA, 0.1), 1.0)
	caixa(c, Rect2(r.get_center().x - 50, r.end.y - 14, 100, 5), Color(TINTA, 0.25), 3)


## O tablet aberto com o canto de cima à esquerda em `o`: a casca, a dobradiça, a câmera e as duas telas.
## Devolve [tela esquerda, tela direita].
static func casca(c: CanvasItem, o: Vector2) -> Array:
	caixa(c, Rect2(o + Vector2(8, 10), TAM + Vector2(0, 2)), Color(0, 0, 0, 0.32), 38)
	caixa(c, Rect2(o, TAM), CASCA, 34)
	caixa(c, Rect2(o + Vector2(5, 5), TAM - Vector2(10, 10)), Color(0, 0, 0, 0), 30, Color(FRISO, 0.85), 3)
	for k in 10:
		var t := float(k) / 9.0
		var g := lerpf(0.55, 0.86, 1.0 - absf(t - 0.4) * 1.6)
		c.draw_rect(Rect2(o + Vector2(448 + k * 2, 6), Vector2(2, 818)), Color(g, g + 0.01, g + 0.03))
	for yk: float in [6.0, 806.0]:
		caixa(c, Rect2(o + Vector2(445, yk), Vector2(26, 18)), Color(0.62, 0.64, 0.68), 6)
	c.draw_circle(o + Vector2(686, 12), 3.0, Color(0.15, 0.17, 0.2))
	var L := Rect2(o + ESQ.position, ESQ.size)
	var R := Rect2(o + DIR.position, DIR.size)
	tela(c, L)
	tela(c, R)
	for k in 8:
		c.draw_rect(Rect2(L.end.x - 8 - k * 3, L.position.y, 3, L.size.y), Color(0, 0, 0, 0.012 * (8 - k)))
		c.draw_rect(Rect2(R.position.x + 5 + k * 3, R.position.y, 3, R.size.y), Color(0, 0, 0, 0.012 * (8 - k)))
	return [L, R]


## O tablet fechado (uma tela só) no retângulo `r`. Devolve a tela.
static func casca_fechada(c: CanvasItem, r: Rect2, barra := true) -> Rect2:
	caixa(c, Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.32), 34)
	caixa(c, r, CASCA, 30)
	caixa(c, r.grow(-5), Color(0, 0, 0, 0), 26, Color(FRISO, 0.85), 3)
	c.draw_circle(Vector2(r.get_center().x, r.position.y + 12), 3.0, Color(0.15, 0.17, 0.2))
	var t := tela_fechada(r)
	tela(c, t, barra)
	return t


static func tela_fechada(r: Rect2) -> Rect2:
	return Rect2(r.position + Vector2(20, 24), r.size - Vector2(40, 44))


## O reflexo do vidro, por cima de tudo.
static func vidro(c: CanvasItem, L: Rect2, R: Rect2) -> void:
	c.draw_colored_polygon(PackedVector2Array([Vector2(R.end.x - 150, R.position.y), Vector2(R.end.x - 60, R.position.y), Vector2(R.end.x - 260, R.end.y), Vector2(R.end.x - 350, R.end.y)]), Color(1, 1, 1, 0.05))
	c.draw_colored_polygon(PackedVector2Array([Vector2(L.end.x - 120, L.position.y), Vector2(L.end.x - 80, L.position.y), Vector2(L.end.x - 280, L.end.y), Vector2(L.end.x - 320, L.end.y)]), Color(1, 1, 1, 0.04))


static func bateria(c: CanvasItem, pos: Vector2) -> void:
	caixa(c, Rect2(pos, Vector2(30, 14)), Color(0, 0, 0, 0), 3, TINTA, 2)
	caixa(c, Rect2(pos + Vector2(3, 3), Vector2(20, 8)), Color(0.3, 0.65, 0.35), 2)
	c.draw_rect(Rect2(pos + Vector2(31, 4), Vector2(3, 6)), TINTA)


## A barra de cima: o ponto colorido e o nome à esquerda (na tela `esq`); a hora do jogo, o sol e a bateria
## à direita (na tela `dir`). `rotulo_dir` troca a hora por um texto (ex.: o lugar da memória).
static func status(c: CanvasItem, esq: Rect2, dir: Rect2, rotulo: String, cor := LARANJA_V, rotulo_dir := "") -> void:
	c.draw_circle(Vector2(esq.position.x + 26, esq.position.y + 21), 6, cor)
	texto(c, Vector2(esq.position.x + 44, esq.position.y + 27), rotulo, 15, TINTA, true)
	if rotulo_dir != "":
		var w := largura(rotulo_dir, 15, true)
		pino(c, Vector2(dir.end.x - 34 - w, dir.position.y + 24), 6, AGUA)
		texto(c, Vector2(dir.end.x - 20 - w, dir.position.y + 27), rotulo_dir, 15, TINTA, true)
		return
	sol(c, Vector2(dir.end.x - 132, dir.position.y + 21), 5.5, Color(0.92, 0.58, 0.12))
	texto(c, Vector2(dir.end.x - 118, dir.position.y + 27), "%02d:%02d" % [int(hora), int(fmod(hora, 1.0) * 60.0)], 15, TINTA, true)
	bateria(c, Vector2(dir.end.x - 58, dir.position.y + 14))


# ------------------------------------------------------------------ figuras pequenas

static func sol(c: CanvasItem, p: Vector2, r: float, cor: Color) -> void:
	c.draw_circle(p, r, cor)
	for k in 8:
		var d := Vector2.from_angle(k * TAU / 8.0)
		c.draw_line(p + d * r * 1.45, p + d * r * 2.0, cor, 1.8, true)


static func pino(c: CanvasItem, p: Vector2, r: float, cor: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.86, -r * 0.5), p + Vector2(0, r * 1.5), p + Vector2(r * 0.86, -r * 0.5)]), cor)
	c.draw_circle(p - Vector2(0, r), r, cor)
	c.draw_circle(p - Vector2(0, r), r * 0.42, TELA)


## A fagulha das lembranças do Faísca (doc §137.12): um ponto claro com quatro faíscas miúdas por cima. Sem
## `cheio`, só o contorno apagado (a vaga ainda não achada).
static func fagulha(c: CanvasItem, p: Vector2, r: float, cor: Color, cheio := true) -> void:
	if cheio:
		c.draw_circle(p, r * 0.62, cor)
		c.draw_circle(p, r * 0.34, Color(1.0, 0.96, 0.86))
	else:
		c.draw_arc(p, r * 0.62, 0.0, TAU, 20, cor, 2.0, true)
	for k in 4:
		var d := Vector2.from_angle(-PI * 0.5 + (k - 1.5) * 0.62)
		c.draw_line(p + d * r * 0.88, p + d * r * (1.25 + 0.18 * (k % 2)), cor, maxf(1.5, r * 0.12), true)


static func cristal(c: CanvasItem, p: Vector2, r: float, cor: Color, cheio := true) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -r * 1.3), p + Vector2(r * 0.8, 0), p + Vector2(0, r * 1.3), p + Vector2(-r * 0.8, 0)])
	if cheio:
		c.draw_colored_polygon(pts, cor)
		c.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], p]), cor.lightened(0.35))
	else:
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), cor, 2.0, true)


static func drone(c: CanvasItem, p: Vector2, r: float) -> void:
	for s: float in [-1.0, 1.0]:
		c.draw_line(p + Vector2(s * r * 0.7, -r * 0.55), p + Vector2(s * r * 1.25, -r * 0.95), Color(TINTA, 0.7), 2.0, true)
		c.draw_line(p + Vector2(s * r * 0.85, -r * 1.0), p + Vector2(s * r * 1.65, -r * 1.0), Color(TINTA, 0.7), 2.5, true)
	c.draw_circle(p, r, Color(0.95, 0.96, 0.98))
	c.draw_arc(p, r, 0, TAU, 32, Color(TINTA, 0.5), 2.0, true)
	caixa(c, Rect2(p + Vector2(-r * 0.62, -r * 0.34), Vector2(r * 1.24, r * 0.62)), Color(0.12, 0.16, 0.22), int(r * 0.3))
	c.draw_circle(p + Vector2(-r * 0.25, -r * 0.03), r * 0.13, Color(0.35, 0.95, 0.85))
	c.draw_circle(p + Vector2(r * 0.25, -r * 0.03), r * 0.13, Color(0.35, 0.95, 0.85))
	c.draw_line(p + Vector2(-r * 0.7, r * 0.55), p + Vector2(r * 0.7, r * 0.55), FRISO, 3.0, true)


static func visto(c: CanvasItem, pos: Vector2, r: float) -> void:
	c.draw_circle(pos, r, OK)
	c.draw_polyline(PackedVector2Array([pos + Vector2(-r * 0.45, 0), pos + Vector2(-r * 0.12, r * 0.35), pos + Vector2(r * 0.48, -r * 0.35)]), Color.WHITE, maxf(2.0, r * 0.22), true)


static func brilhinho(c: CanvasItem, pos: Vector2, r: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for k in 9:
		var a := k * TAU / 8.0 - PI / 2.0
		var rr := r if k % 2 == 0 else r * 0.38
		pts.append(pos + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, cor)


static func coracao(c: CanvasItem, pos: Vector2, tam: float, cor: Color, cheio: bool) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		var t := k * TAU / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(pos + Vector2(x, y) * tam / 17.0)
	if cheio:
		c.draw_colored_polygon(pts, cor)
	else:
		c.draw_polyline(pts, cor, 2.0, true)


static func relogio(c: CanvasItem, pos: Vector2, cor: Color) -> void:
	c.draw_arc(pos, 11, 0, TAU, 24, cor, 2.0, true)
	c.draw_line(pos, pos + Vector2(0, -7), cor, 2.0)
	c.draw_line(pos, pos + Vector2(5, 3), cor, 2.0)


static func termometro(c: CanvasItem, p: Vector2) -> void:
	caixa(c, Rect2(p + Vector2(-4, -12), Vector2(8, 18)), Color(0, 0, 0, 0), 4, TINTA, 2)
	c.draw_circle(p + Vector2(0, 8), 6, AZUL)
	c.draw_rect(Rect2(p + Vector2(-1.5, -2), Vector2(3, 8)), AZUL)
	c.draw_line(p + Vector2(9, -8), p + Vector2(9, 2), AZUL, 2.0)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(9, 6), p + Vector2(5, 0), p + Vector2(13, 0)]), AZUL)


## O anel do nível: a volta inteira clara e a parte feita em laranja.
static func anel(c: CanvasItem, p: Vector2, r: float, frac: float, lw := 3.0) -> void:
	c.draw_arc(p, r, 0, TAU, 40, Color(TINTA, 0.17), lw, true)
	if frac > 0.001:
		c.draw_arc(p, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(frac, 0.0, 1.0), 40, Color(0.9, 0.48, 0.15), lw, true)


static func fita(c: CanvasItem, de: Vector2, para: Vector2, onda: float, cor: Color, fase: float) -> void:
	var pts := PackedVector2Array()
	for k in 41:
		var t := k / 40.0
		var p := de.lerp(para, t)
		p.y += sin(t * TAU * 1.2 + fase) * onda * (1.0 - t * 0.4)
		pts.append(p)
	for camada in 4:
		c.draw_polyline(pts, Color(cor, 0.08 + camada * 0.2), 14.0 - camada * 3.5, true)


# ------------------------------------------------------------------ materiais

static func porca(c: CanvasItem, centro: Vector2, tam: float, cor: Color, lw := 2.0) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var a := i * TAU / 6.0 + PI / 6.0
		pts.append(centro + Vector2(cos(a), sin(a)) * tam)
	c.draw_polyline(pts, cor, lw, true)
	c.draw_arc(centro, tam * 0.42, 0, TAU, 20, cor, lw, true)


static func nucleo(c: CanvasItem, centro: Vector2, tam: float, cor: Color, lw := 2.0) -> void:
	brilho(c, centro, tam * 0.7, cor, 0.8)
	c.draw_arc(centro, tam, 0, TAU, 24, cor, lw, true)
	c.draw_circle(centro, tam * 0.42, cor)


static func chip(c: CanvasItem, centro: Vector2, tam: float, cor: Color, lw := 2.0) -> void:
	var s := tam * 0.72
	c.draw_rect(Rect2(centro - Vector2(s, s), Vector2(s, s) * 2.0), cor, false, lw)
	c.draw_rect(Rect2(centro - Vector2(s, s) * 0.4, Vector2(s, s) * 0.8), cor, false, lw * 0.8)
	for k in 3:
		var o := (k - 1) * s * 0.6
		c.draw_line(centro + Vector2(o, -s), centro + Vector2(o, -tam * 1.05), cor, lw)
		c.draw_line(centro + Vector2(o, s), centro + Vector2(o, tam * 1.05), cor, lw)
		c.draw_line(centro + Vector2(-s, o), centro + Vector2(-tam * 1.05, o), cor, lw)
		c.draw_line(centro + Vector2(s, o), centro + Vector2(tam * 1.05, o), cor, lw)


## "sucata", "nucleos" ou "chips".
static func material(c: CanvasItem, nome: String, centro: Vector2, tam: float, cor: Color, lw := 2.0) -> void:
	match nome:
		"sucata":
			porca(c, centro, tam, cor, lw)
		"nucleos":
			nucleo(c, centro, tam, cor, lw)
		"chips":
			chip(c, centro, tam, cor, lw)


static func tem(mat: String) -> int:
	return {"sucata": Arsenal.sucata, "nucleos": Arsenal.nucleos, "chips": Arsenal.chips}.get(mat, 0)


## Os carimbos de custo: um círculo por material, laranja se tem, vermelho se falta. Devolve a largura.
static func carimbos(c: CanvasItem, x0: float, y: float, custo: Dictionary, passo := 92.0) -> float:
	var cx := x0
	for mat: String in ["sucata", "nucleos", "chips"]:
		var q := int(custo.get(mat, 0))
		if q <= 0:
			continue
		var tinta := RUBI if tem(mat) < q else LARANJA
		c.draw_circle(Vector2(cx, y), 34, Color(tinta, 0.1))
		c.draw_arc(Vector2(cx, y), 34, 0, TAU, 32, tinta, 2.5, true)
		material(c, mat, Vector2(cx, y - 10), 10.0, tinta, 2.0)
		texto(c, Vector2(cx - 30, y + 22), str(q), 18, tinta, true, HORIZONTAL_ALIGNMENT_CENTER, 60)
		cx += passo
	return cx - x0


## O que falta para o custo: [texto, cor, pode].
static func falta(custo: Dictionary) -> Array:
	if Arsenal.nivel() < int(custo.get("nivel", 1)):
		return ["chega no nível %d para fazer" % int(custo["nivel"]), Color(TINTA, 0.6), false]
	var faltas: Array = []
	var nomes := {"sucata": "sucata", "nucleos": "núcleos", "chips": "chips"}
	for mat: String in ["sucata", "nucleos", "chips"]:
		if tem(mat) < int(custo.get(mat, 0)):
			faltas.append("%s %d de %d" % [nomes[mat], tem(mat), int(custo[mat])])
	if faltas.is_empty():
		return ["tem tudo no bolso!", OK, true]
	return ["falta " + ", ".join(faltas), RUBI, false]


## Os três materiais do bolso numa linha (figura e número).
static func bolso(c: CanvasItem, pos: Vector2, passo := 118.0, tam := 20) -> void:
	var x := pos.x
	for par: Array in [["sucata", Arsenal.sucata, LARANJA], ["nucleos", Arsenal.nucleos, Color(0.08, 0.58, 0.55)], ["chips", Arsenal.chips, Color(0.5, 0.35, 0.85)]]:
		material(c, par[0], Vector2(x, pos.y - tam * 0.35), 11.0, par[2], 2.0)
		texto(c, Vector2(x + 20, pos.y), str(par[1]), tam, TINTA, true)
		x += passo


# ------------------------------------------------------------------ botões do controle

## Uma figura de botão do controle (Botoes) num círculo escuro: as figuras são claras.
static func botao(c: CanvasItem, nome: String, centro: Vector2, lado := 28.0, alfa := 1.0) -> void:
	c.draw_circle(centro, lado * 0.5, Color(TINTA, alfa))
	var t := Botoes.textura(nome)
	if t:
		c.draw_texture_rect(t, Rect2(centro - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false, Color(1, 1, 1, alfa))


## Texto com figuras de botão ({@x}, como em Botoes): desenha e devolve a largura. Com `ate` >= 0, encosta à
## direita em `ate`. `controle` -1 segue o aparelho em uso, 1 força o controle e 0 o teclado.
static func com_botoes(c: CanvasItem, pos: Vector2, s: String, tam: int, cor: Color, ate := -1.0, medir := false, controle := -1) -> float:
	var ped: Array = Botoes.pedacos(s, controle)
	var lado := tam * 1.45
	var w := 0.0
	for p: Variant in ped:
		if p is Texture2D:
			w += lado + 4.0
		else:
			w += largura(String(p), tam)
	if medir:
		return w
	var x := pos.x if ate < 0 else ate - w
	for p: Variant in ped:
		if p is Texture2D:
			var cen := Vector2(x + lado * 0.5, pos.y - tam * 0.35)
			c.draw_circle(cen, lado * 0.5, TINTA)
			c.draw_texture_rect(p, Rect2(cen - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false)
			x += lado + 4.0
		else:
			c.draw_string(fonte(), Vector2(x, pos.y), String(p), HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
			x += largura(String(p), tam)
	return w


## O rodapé de uma tela: [[botão, texto], ...] (o texto aceita {@botão}).
static func rodape(c: CanvasItem, t: Rect2, itens: Array, y := -1.0) -> void:
	var x := t.position.x + 24.0
	var yy := t.end.y - 34.0 if y < 0 else y
	for it: Array in itens:
		botao(c, it[0], Vector2(x + 12, yy), 24)
		var w := com_botoes(c, Vector2(x + 30, yy + 6), it[1], 15, Color(TINTA, 0.7))
		x += 42 + w + 18


# ------------------------------------------------------------------ blocos de tela

## Uma escolha grande de menu: a figura num círculo de cor, o nome e a explicação; com o foco, fundo claro,
## borda laranja e o X à direita. `perigo` deixa tudo vermelho (apagar o progresso).
static func opcao(c: CanvasItem, r: Rect2, ic: String, titulo: String, sub: String, foco: bool, cor: Color, perigo := false, sobre := false) -> void:
	var fundo := CLARO if foco else Color(TINTA, 0.08 if sobre else 0.05)
	var borda := LARANJA if foco else Color(0, 0, 0, 0)
	var lw := 3 if foco else 0
	if perigo:
		fundo = Color(RUBI, 0.14 if foco or sobre else 0.08)
		borda = Color(RUBI, 0.9 if foco else 0.4)
		lw = 3 if foco else 2
	caixa(c, r, fundo, 18, borda, lw)
	var centro := r.position + Vector2(r.size.y * 0.5 + 4, r.size.y * 0.5)
	var rad := minf(r.size.y * 0.34, 28.0)
	var circ := cor if foco else cor.lerp(TELA, 0.8)
	c.draw_circle(centro, rad, circ)
	icone(c, ic, centro, rad * 1.15, Color.WHITE if foco else cor.darkened(0.25), circ)
	var tx := r.position.x + r.size.y + 16
	var cy := r.position.y + r.size.y * 0.5
	texto(c, Vector2(tx, cy + (-3.0 if sub != "" else 8.0)), titulo, 21, RUBI if perigo else TINTA, true)
	if sub != "":
		texto(c, Vector2(tx, cy + 20), sub, 15, Color(RUBI, 0.75) if perigo else Color(TINTA, 0.6))
	if foco:
		botao(c, "x", Vector2(r.end.x - 30, cy), 26)


## Uma pílula (aba ou botão curto): cheia na cor quando ativa; com o foco, a borda laranja.
static func pilula(c: CanvasItem, r: Rect2, ic: String, nome: String, cor: Color, ativa: bool, foco := false) -> void:
	if ativa:
		caixa(c, r, cor, int(r.size.y * 0.5))
	if foco:
		caixa(c, r.grow(2), Color(0, 0, 0, 0), int(r.size.y * 0.5) + 2, LARANJA, 3)
	# estreita (cinco abas na fileira): margem, figura e letra menores
	var estreita := r.size.x < 90.0
	var x := r.position.x + (7.0 if estreita else 14.0)
	if ic != "":
		icone(c, ic, Vector2(x + 8, r.get_center().y), 16 if estreita else 18, Color.WHITE if ativa else cor.darkened(0.15), cor if ativa else TELA)
		x += 20.0 if estreita else 24.0
	texto(c, Vector2(x, r.get_center().y + 5 if estreita else r.get_center().y + 6), nome, 13 if estreita else 15, Color.WHITE if ativa else TINTA, ativa)


## A fileira de abas desenhada (as abas trocam por L1 / R1): [[figura, nome, cor], ...]
static func pilulas(c: CanvasItem, t: Rect2, abas: Array, ativa: int, w: float) -> void:
	caixa(c, Rect2(t.position.x + 14, t.position.y + 54, t.size.x - 28, 46), Color(TINTA, 0.07), 23)
	var ax := t.position.x + 18.0
	for i in abas.size():
		pilula(c, Rect2(ax, t.position.y + 58, w, 38), abas[i][0], abas[i][1], abas[i][2], i == ativa)
		ax += w


## Um cartãozinho de conta: figura em cima, número grande e o que é.
static func conta(c: CanvasItem, r: Rect2, desenho: Callable, numero: String, rotulo: String) -> void:
	caixa(c, r, Color(TINTA, 0.06), 16)
	desenho.call(r.position + Vector2(r.size.x * 0.5, 28))
	texto(c, Vector2(r.position.x, r.position.y + 70), numero, 20, TINTA, true, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	texto(c, Vector2(r.position.x, r.position.y + 90), rotulo, 13, Color(TINTA, 0.6), false, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Uma ficha com figura e texto curto, em pílula (o que um item dá).
static func ficha(c: CanvasItem, pos: Vector2, w: float, desenho: Callable, s: String) -> void:
	caixa(c, Rect2(pos, Vector2(w, 46)), Color(TINTA, 0.07), 23)
	desenho.call(pos + Vector2(26, 23))
	texto(c, pos + Vector2(48, 30), s, 16, TINTA, true)


## A planta azul: grade, a figura acesa no meio e a legenda embaixo ("?" quando ainda não se conhece).
static func planta(c: CanvasItem, r: Rect2, ic: String, legenda: String, desconhecida := false, escala := 4.6) -> void:
	caixa(c, r, PLANTA, 14)
	var gx := r.position.x + 12
	while gx < r.end.x - 4:
		c.draw_line(Vector2(gx, r.position.y + 6), Vector2(gx, r.end.y - 6), Color(0.45, 0.65, 0.95, 0.16), 1.0)
		gx += 18.0
	var gy := r.position.y + 12
	while gy < r.end.y - 4:
		c.draw_line(Vector2(r.position.x + 6, gy), Vector2(r.end.x - 6, gy), Color(0.45, 0.65, 0.95, 0.16), 1.0)
		gy += 18.0
	var centro := r.get_center() - Vector2(0, 8)
	if desconhecida:
		texto(c, Vector2(r.position.x, centro.y + 34), "?", 96, Color(0.75, 0.9, 1.0, 0.55), true, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	else:
		Icones.desenhar(c, ic, centro, escala, Color(0.55, 0.8, 1.0, 0.25), 9.0)
		Icones.desenhar(c, ic, centro, escala, Color(0.8, 0.93, 1.0), 3.0)
	c.draw_line(Vector2(r.position.x + 30, r.end.y - 22), Vector2(r.end.x - 30, r.end.y - 22), Color(0.7, 0.88, 1.0, 0.7), 1.2)
	texto(c, Vector2(r.position.x + 40, r.end.y - 30), legenda, 14, Color(0.75, 0.9, 1.0))


## O botão redondo de segurar X: o anel enche enquanto segura (`progresso` 0 a 1).
static func segurar(c: CanvasItem, centro: Vector2, pode: bool, s: String, progresso := 0.0) -> void:
	c.draw_arc(centro, 36, 0, TAU, 40, Color(TINTA, 0.15), 6.0, true)
	if pode:
		brilho(c, centro, 30, Color(1.0, 0.6, 0.2), 0.9)
		c.draw_circle(centro, 30, LARANJA_V)
		if progresso > 0.001:
			c.draw_arc(centro, 36, -PI / 2.0, -PI / 2.0 + TAU * clampf(progresso, 0.0, 1.0), 40, Color(0.85, 0.4, 0.1), 6.0, true)
	else:
		c.draw_circle(centro, 30, Color(TINTA, 0.18))
	botao(c, "x", centro, 30, 1.0 if pode else 0.45)
	texto(c, Vector2(centro.x + 52, centro.y + 7), s, 19, TINTA if pode else Color(TINTA, 0.45), true)


## O selo verde de pronto (no lugar do botão de segurar).
static func feito(c: CanvasItem, pos: Vector2, s: String) -> void:
	c.draw_circle(pos, 30, Color(OK, 0.15))
	visto(c, pos, 24)
	texto(c, Vector2(pos.x + 46, pos.y + 8), s, 21, OK, true)


## Uma lâmpada da trilha de melhorias: 0 apagada, 1 acesa, 2 a próxima.
static func lampada(c: CanvasItem, centro: Vector2, r: float, estado: int) -> void:
	if estado == 1:
		brilho(c, centro, r, Color(1.0, 0.8, 0.3), 1.4)
		c.draw_circle(centro, r, Color(1.0, 0.84, 0.4))
	elif estado == 2:
		c.draw_circle(centro, r, Color(1.0, 0.62, 0.3, 0.18))
		c.draw_arc(centro, r + 4, 0, TAU, 28, Color(0.95, 0.5, 0.15), 2.0, true)
	c.draw_arc(centro, r, 0, TAU, 28, TINTA, 2.0, true)
	var bw := r * 0.85
	c.draw_rect(Rect2(centro.x - bw * 0.5, centro.y + r * 0.9, bw, r * 0.55), TINTA, false, 1.8)
	c.draw_line(Vector2(centro.x - bw * 0.5, centro.y + r * 1.17), Vector2(centro.x + bw * 0.5, centro.y + r * 1.17), TINTA, 1.4)
	if estado == 1:
		c.draw_arc(centro + Vector2(0, r * 0.15), r * 0.32, PI, TAU, 10, Color(0.8, 0.5, 0.12), 1.6, true)


## A figura de um ganho de melhoria: dano (estrela), rapidez (setas), estouro, máquina; o resto vem de Icones.
static func ganho(c: CanvasItem, nome: String, centro: Vector2, cor: Color) -> void:
	match nome:
		"rapidez":
			for k in 2:
				var x := centro.x - 8 + k * 9
				c.draw_polyline(PackedVector2Array([Vector2(x - 2, centro.y - 8), Vector2(x + 5, centro.y), Vector2(x - 2, centro.y + 8)]), cor, 2.4, true)
		"dano":
			for k in 8:
				var a := k * TAU / 8.0
				var r1 := 12.0 if k % 2 == 0 else 8.0
				c.draw_line(centro + Vector2(cos(a), sin(a)) * 4.0, centro + Vector2(cos(a), sin(a)) * r1, cor, 2.2, true)
		"estouro":
			c.draw_circle(centro, 3.5, cor)
			c.draw_arc(centro, 8, 0, TAU, 20, cor, 2.0, true)
			for a: float in [0.3, 2.4, 4.4]:
				c.draw_arc(centro, 13, a, a + 0.9, 8, cor, 2.0, true)
		"escudo":
			Icones.desenhar(c, "escudo", centro, 0.6, cor, 2.0)
		_:
			Icones.desenhar(c, nome, centro, 0.62, cor, 2.0)


## As figuras dos menus (as da pausa, desenhadas em 36 e escaladas) e algumas novas; o resto vem de Icones.
## `fundo` é a cor de trás, para os recortes (o furo da engrenagem, os botões do controle).
static func icone(cv: CanvasItem, tipo: String, p: Vector2, lado: float, cor: Color, fundo: Color) -> void:
	var r := lado * 0.47
	match tipo:
		"imagem":
			caixa(cv, Rect2(p - Vector2(r, r * 0.78), Vector2(r * 2, r * 1.56)), Color(0, 0, 0, 0), 4, cor, 2)
			cv.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.8, r * 0.6), p + Vector2(-r * 0.2, -r * 0.15), p + Vector2(r * 0.2, r * 0.25), p + Vector2(r * 0.45, 0.0), p + Vector2(r * 0.8, r * 0.6)]), cor)
			cv.draw_circle(p + Vector2(r * 0.45, -r * 0.4), r * 0.16, cor)
		"cam_sens":
			cv.draw_arc(p, r * 0.85, 0, TAU, 28, cor, 2.2, true)
			cv.draw_circle(p, r * 0.3, cor)
			for k in 4:
				var d := Vector2.from_angle(k * TAU / 4.0)
				var ponta := p + d * r * 1.05
				cv.draw_colored_polygon(PackedVector2Array([ponta, ponta - d * r * 0.32 + d.orthogonal() * r * 0.2, ponta - d * r * 0.32 - d.orthogonal() * r * 0.2]), cor)
		"setas_v":
			cv.draw_line(p + Vector2(0, -r * 0.6), p + Vector2(0, r * 0.6), cor, 2.5, true)
			for s: float in [-1.0, 1.0]:
				cv.draw_colored_polygon(PackedVector2Array([p + Vector2(0, s * r * 1.0), p + Vector2(-r * 0.45, s * r * 0.45), p + Vector2(r * 0.45, s * r * 0.45)]), cor)
		"vibra":
			caixa(cv, Rect2(p - Vector2(r * 0.55, r * 0.8), Vector2(r * 1.1, r * 1.6)), cor, 4)
			cv.draw_rect(Rect2(p - Vector2(r * 0.35, r * 0.55), Vector2(r * 0.7, r * 0.95)), fundo)
			for s: float in [-1.0, 1.0]:
				cv.draw_arc(p, r * 0.95, -0.5 + (0.0 if s > 0 else PI), 0.5 + (0.0 if s > 0 else PI), 8, cor, 2.0, true)
		"teclado":
			caixa(cv, Rect2(p - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), Color(0, 0, 0, 0), 3, cor, 2)
			for j in 2:
				for i in 4:
					cv.draw_rect(Rect2(p + Vector2(-r * 0.75 + i * r * 0.42, -r * 0.35 + j * r * 0.36), Vector2(r * 0.24, r * 0.2)), cor)
			cv.draw_rect(Rect2(p + Vector2(-r * 0.45, r * 0.32), Vector2(r * 0.9, r * 0.14)), cor)
		"mapa":
			var pts := PackedVector2Array([p + Vector2(-r, -r * 0.7), p + Vector2(-r * 0.33, -r * 0.9), p + Vector2(r * 0.33, -r * 0.7), p + Vector2(r, -r * 0.9), p + Vector2(r, r * 0.7), p + Vector2(r * 0.33, r * 0.9), p + Vector2(-r * 0.33, r * 0.7), p + Vector2(-r, r * 0.9), p + Vector2(-r, -r * 0.7)])
			cv.draw_polyline(pts, cor, 2.2, true)
			cv.draw_line(p + Vector2(-r * 0.33, -r * 0.9), p + Vector2(-r * 0.33, r * 0.7), cor, 1.6, true)
			cv.draw_line(p + Vector2(r * 0.33, -r * 0.7), p + Vector2(r * 0.33, r * 0.9), cor, 1.6, true)
		"cristal":
			cristal(cv, p, r * 0.75, cor)
		"continuar", "comandos", "simulacao", "ajustes", "sair", "novo", "acordar", "casa", "voltar", "album", "historia", "apagar", "sim", "nao":
			_figura_menu(cv, tipo, p, lado, cor, fundo)
		_:
			Icones.desenhar(cv, tipo, p, lado / 32.0, cor, 2.0)


## As figuras dos botões da pausa (as mesmas do Pausa.IconeMenu), desenhadas em 36 e escaladas.
static func _figura_menu(cv: CanvasItem, tipo: String, centro: Vector2, tam: float, cor: Color, fundo: Color) -> void:
	cv.draw_set_transform(centro - Vector2(tam, tam) * 0.5, 0.0, Vector2.ONE * (tam / 36.0))
	var c := Vector2(18, 18)
	var r := 17.0
	match tipo:
		"sim":
			cv.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.62, r * 0.02), c + Vector2(-r * 0.15, r * 0.5), c + Vector2(r * 0.68, -r * 0.5)]), cor, 3.5, true)
		"nao":
			cv.draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), cor, 3.5, true)
			cv.draw_line(c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.5, r * 0.5), cor, 3.5, true)
		"continuar":
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.62), c + Vector2(r * 0.68, 0), c + Vector2(-r * 0.45, r * 0.62)]), cor)
		"comandos":
			# um controle: corpo, duas pegadas, a cruz à esquerda e dois botões à direita
			cv.draw_rect(Rect2(c.x - r * 0.62, c.y - r * 0.42, r * 1.24, r * 0.7), cor)
			cv.draw_circle(c + Vector2(-r * 0.62, -r * 0.07), r * 0.35, cor)
			cv.draw_circle(c + Vector2(r * 0.62, -r * 0.07), r * 0.35, cor)
			cv.draw_circle(c + Vector2(-r * 0.72, r * 0.3), r * 0.26, cor)
			cv.draw_circle(c + Vector2(r * 0.72, r * 0.3), r * 0.26, cor)
			cv.draw_rect(Rect2(c.x - r * 0.78, c.y - r * 0.13, r * 0.38, r * 0.12), fundo)
			cv.draw_rect(Rect2(c.x - r * 0.65, c.y - r * 0.26, r * 0.12, r * 0.38), fundo)
			cv.draw_circle(c + Vector2(r * 0.5, -r * 0.18), r * 0.09, fundo)
			cv.draw_circle(c + Vector2(r * 0.7, r * 0.0), r * 0.09, fundo)
		"simulacao":
			# um cubo de arame, como o chão do holograma
			var t := r * 0.85
			var pts := PackedVector2Array([c + Vector2(0, -t), c + Vector2(t * 0.87, -t * 0.5), c + Vector2(t * 0.87, t * 0.5),
				c + Vector2(0, t), c + Vector2(-t * 0.87, t * 0.5), c + Vector2(-t * 0.87, -t * 0.5), c + Vector2(0, -t)])
			cv.draw_polyline(pts, cor, 2.5, true)
			cv.draw_polyline(PackedVector2Array([c + Vector2(-t * 0.87, -t * 0.5), c, c + Vector2(t * 0.87, -t * 0.5)]), cor, 2.5, true)
			cv.draw_line(c, c + Vector2(0, t), cor, 2.5, true)
		"ajustes":
			for k in 8:
				var ang := k * TAU / 8.0
				var dir := Vector2.from_angle(ang)
				var lado := dir.orthogonal()
				var base := c + dir * r * 0.55
				var ponta := c + dir * r * 0.92
				cv.draw_colored_polygon(PackedVector2Array([base + lado * r * 0.2, ponta + lado * r * 0.14, ponta - lado * r * 0.14, base - lado * r * 0.2]), cor)
			cv.draw_circle(c, r * 0.62, cor)
			cv.draw_circle(c, r * 0.24, fundo)
		"sair":
			# uma porta e a seta saindo por ela
			cv.draw_rect(Rect2(c.x - r * 0.75, c.y - r * 0.8, r * 0.85, r * 1.6), cor, false, 2.5)
			cv.draw_circle(c + Vector2(-r * 0.12, r * 0.05), r * 0.08, cor)
			cv.draw_line(c + Vector2(-r * 0.05, 0), c + Vector2(r * 0.85, 0), cor, 2.5, true)
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.95, 0), c + Vector2(r * 0.6, -r * 0.3), c + Vector2(r * 0.6, r * 0.3)]), cor)
		"novo":
			var p4 := PackedVector2Array()
			for k in 8:
				p4.append(c + Vector2.from_angle(k * TAU / 8.0 - PI * 0.5) * (r * 0.9 if k % 2 == 0 else r * 0.28))
			cv.draw_colored_polygon(p4, cor)
		"acordar":
			cv.draw_circle(c, r * 0.4, cor)
			for k in 8:
				var d := Vector2.from_angle(k * TAU / 8.0)
				cv.draw_line(c + d * r * 0.6, c + d * r * 0.92, cor, 2.5, true)
		"casa":
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.85), c + Vector2(r * 0.85, -r * 0.05), c + Vector2(-r * 0.85, -r * 0.05)]), cor)
			cv.draw_rect(Rect2(c.x - r * 0.6, c.y - r * 0.1, r * 1.2, r * 0.85), cor)
			cv.draw_rect(Rect2(c.x - r * 0.17, c.y + r * 0.25, r * 0.34, r * 0.5), fundo)
		"voltar":
			cv.draw_line(c + Vector2(r * 0.8, 0), c + Vector2(-r * 0.5, 0), cor, 3.0, true)
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.85, 0), c + Vector2(-r * 0.35, -r * 0.45), c + Vector2(-r * 0.35, r * 0.45)]), cor)
		"album":
			# uma câmera: o corpo, o visor em cima e a lente
			cv.draw_rect(Rect2(c.x - r * 0.85, c.y - r * 0.42, r * 1.7, r * 1.15), cor)
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.38, -r * 0.42), c + Vector2(-r * 0.25, -r * 0.7), c + Vector2(r * 0.25, -r * 0.7), c + Vector2(r * 0.38, -r * 0.42)]), cor)
			cv.draw_circle(c + Vector2(0, r * 0.15), r * 0.42, fundo)
			cv.draw_circle(c + Vector2(0, r * 0.15), r * 0.26, cor)
			cv.draw_circle(c + Vector2(r * 0.6, -r * 0.22), r * 0.09, fundo)
		"historia":
			# um livro aberto: duas páginas inclinadas e a lombada no meio
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.06, -r * 0.5), c + Vector2(-r * 0.88, -r * 0.62), c + Vector2(-r * 0.88, r * 0.5), c + Vector2(-r * 0.06, r * 0.62)]), cor)
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.06, -r * 0.5), c + Vector2(r * 0.88, -r * 0.62), c + Vector2(r * 0.88, r * 0.5), c + Vector2(r * 0.06, r * 0.62)]), cor)
			for k in 3:
				var yy := -r * 0.28 + k * r * 0.26
				cv.draw_line(c + Vector2(-r * 0.72, yy - r * 0.08), c + Vector2(-r * 0.22, yy), fundo, 1.6, true)
				cv.draw_line(c + Vector2(r * 0.22, yy), c + Vector2(r * 0.72, yy - r * 0.08), fundo, 1.6, true)
		"apagar":
			# uma lixeira
			cv.draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.45, r * 1.1, r * 1.25), cor, false, 2.5)
			cv.draw_line(c + Vector2(-r * 0.8, -r * 0.62), c + Vector2(r * 0.8, -r * 0.62), cor, 2.5, true)
			cv.draw_rect(Rect2(c.x - r * 0.22, c.y - r * 0.85, r * 0.44, r * 0.22), cor)
			for k in 3:
				var x := c.x + (k - 1) * r * 0.3
				cv.draw_line(Vector2(x, c.y - r * 0.2), Vector2(x, c.y + r * 0.6), cor, 2.0, true)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
