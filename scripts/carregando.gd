class_name Carregando
extends CanvasLayer

## Tela de carregamento: o vale ao amanhecer. Enquanto o mundo é montado o céu clareia e o sol sobe por
## trás dos morros; uma linha fina embaixo mostra quanto falta e o que está sendo feito. A montagem chama
## `mostrar` entre os passos (Ilha.aviso); cada chamada desenha um quadro.

const LARANJA := Color(1.0, 0.62, 0.3)

var _tela: Control
var _f := 0.0
var _texto := ""
var _fonte: Font
var _some := 1.0


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonte = ThemeDB.fallback_font
	_tela = Control.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


## Avança a tela para a fração `f` (0 a 1) com o passo `texto`, e espera o quadro ser desenhado.
func mostrar(f: float, texto: String) -> void:
	_f = maxf(_f, f)
	_texto = texto
	_tela.queue_redraw()
	await RenderingServer.frame_post_draw


## O mundo está pronto: a tela some devagar e sai.
func fechar() -> void:
	_f = 1.0
	_texto = ""
	var t := create_tween()
	t.tween_method(func(a: float) -> void:
		_some = a
		if is_instance_valid(_tela):
			_tela.queue_redraw(), 1.0, 0.0, 0.7).set_delay(0.15)
	t.tween_callback(queue_free)


func _morro(tam: Vector2, base: float, alto: float, fase: float, larg: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var x := tam.x * i / n
		var u := float(i) / n * larg + fase
		var y := base - alto * (0.55 + 0.30 * sin(u * 2.1) + 0.15 * sin(u * 5.3 + 1.2))
		pts.append(Vector2(x, y))
	pts.append(Vector2(tam.x, tam.y))
	pts.append(Vector2(0, tam.y))
	_tela.draw_colored_polygon(pts, cor)


func _desenhar() -> void:
	var tam := _tela.size
	var a := _some
	var dia := smoothstep(0.0, 1.0, _f)
	# céu: da noite ao amanhecer, mais claro perto do horizonte
	var alto := Color(0.035, 0.05, 0.085).lerp(Color(0.16, 0.25, 0.40), dia)
	var baixo := Color(0.07, 0.085, 0.12).lerp(Color(0.86, 0.56, 0.34), dia)
	var faixas := 90
	for k in faixas:
		var c := alto.lerp(baixo, pow(float(k) / (faixas - 1), 1.6))
		c.a = a
		_tela.draw_rect(Rect2(0, tam.y * 0.72 * k / faixas, tam.x, tam.y * 0.72 / faixas + 1.0), c)
	# o sol sobe por trás do morro do fundo
	var horizonte := tam.y * 0.66
	var sol := Vector2(tam.x * 0.47, horizonte + tam.y * 0.10 - tam.y * 0.17 * dia)
	_tela.draw_circle(sol, tam.y * 0.11, Color(1.0, 0.72, 0.42, 0.10 * dia * a))
	_tela.draw_circle(sol, tam.y * 0.045, Color(1.0, 0.86, 0.62, (0.25 + 0.75 * dia) * a))
	# três linhas de morros, a de trás mais clara
	var sombra := 0.35 + 0.65 * dia
	_morro(tam, horizonte + tam.y * 0.04, tam.y * 0.20, 0.4, 5.0, Color(0.17 * sombra, 0.24 * sombra, 0.27 * sombra, a))
	_morro(tam, horizonte + tam.y * 0.13, tam.y * 0.17, 2.3, 3.6, Color(0.085 * sombra, 0.16 * sombra, 0.14 * sombra, a))
	_morro(tam, horizonte + tam.y * 0.25, tam.y * 0.15, 5.1, 2.4, Color(0.035 * sombra, 0.075 * sombra, 0.06 * sombra, a))
	_tela.draw_rect(Rect2(0, horizonte + tam.y * 0.24, tam.x, tam.y), Color(0.03 * sombra, 0.065 * sombra, 0.052 * sombra, a))
	# título
	var k := tam.y / 900.0
	var nome := "FAÍSCA 2"
	var tn := int(54 * k)
	var wn := _fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tn).x
	_tela.draw_string(_fonte, Vector2((tam.x - wn) * 0.5, tam.y * 0.30), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tn, Color(1, 1, 1, 0.95 * a))
	var sub := "EM BUSCA DO SOSSEGO"
	var ts := int(17 * k)
	var wsub := _fonte.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	_tela.draw_string(_fonte, Vector2((tam.x - wsub) * 0.5, tam.y * 0.30 + 34.0 * k), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(1, 1, 1, 0.6 * a))
	# a linha do progresso e o passo
	if _texto != "":
		var larg := tam.x * 0.28
		var x0 := (tam.x - larg) * 0.5
		var y := tam.y * 0.90
		_tela.draw_rect(Rect2(x0, y, larg, 2.0 * k), Color(1, 1, 1, 0.16 * a))
		_tela.draw_rect(Rect2(x0, y, larg * _f, 2.0 * k), Color(LARANJA, a))
		_robo(Vector2(x0 + larg * _f, y - 50.0 * k), k, a)
		var tt := int(15 * k)
		var wt := _fonte.get_string_size(_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tt).x
		_tela.draw_string(_fonte, Vector2((tam.x - wt) * 0.5, y + 26.0 * k), _texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tt, Color(1, 1, 1, 0.7 * a))


## O vulto do robô voando por cima da linha, na ponta do progresso: sobe, desce e inclina conforme avança,
## com o jato aceso atrás. Desenhado de lado, em unidades de um corpo (o `u`).
func _robo(onde: Vector2, k: float, a: float) -> void:
	var u := 62.0 * k
	var onda := _f * 21.0
	var sobe := sin(onda) * 9.0 * k + sin(onda * 0.37 + 1.0) * 5.0 * k
	var inclina := -cos(onda) * 0.22 - 0.06  # nariz para cima quando sobe
	_tela.draw_set_transform(onde + Vector2(0, sobe), inclina, Vector2(u, u))
	var cor := Color(0.93, 0.95, 0.98, 0.9 * a)
	# jato dos pés: duas chamas que tremem
	var treme := 0.75 + 0.25 * sin(_f * 173.0)
	for dy: float in [0.03, 0.13]:
		_tela.draw_colored_polygon(PackedVector2Array([Vector2(-0.70, dy - 0.035), Vector2(-0.70, dy + 0.035), Vector2(-0.70 - 0.34 * treme, dy)]), Color(LARANJA, 0.95 * a))
		_tela.draw_colored_polygon(PackedVector2Array([Vector2(-0.70, dy - 0.018), Vector2(-0.70, dy + 0.018), Vector2(-0.70 - 0.16 * treme, dy)]), Color(1.0, 0.9, 0.7, a))
	# pernas para trás, uma um pouco aberta
	_tela.draw_colored_polygon(PackedVector2Array([Vector2(-0.24, -0.03), Vector2(-0.70, -0.005), Vector2(-0.70, 0.065), Vector2(-0.24, 0.07)]), cor)
	_tela.draw_colored_polygon(PackedVector2Array([Vector2(-0.24, 0.03), Vector2(-0.70, 0.095), Vector2(-0.70, 0.165), Vector2(-0.22, 0.12)]), cor)
	# tronco, mochila e a asa do planador
	_tela.draw_colored_polygon(PackedVector2Array([Vector2(-0.27, -0.10), Vector2(0.16, -0.12), Vector2(0.22, -0.02), Vector2(0.18, 0.11), Vector2(-0.27, 0.12)]), cor)
	_tela.draw_colored_polygon(PackedVector2Array([Vector2(-0.24, -0.20), Vector2(0.04, -0.20), Vector2(0.08, -0.11), Vector2(-0.26, -0.10)]), cor)
	_tela.draw_colored_polygon(PackedVector2Array([Vector2(-0.06, -0.20), Vector2(-0.52, -0.36), Vector2(-0.40, -0.26), Vector2(-0.22, -0.19)]), cor)
	# cabeça com a antena, e o braço esticado para a frente
	_tela.draw_circle(Vector2(0.31, -0.035), 0.105, cor)
	_tela.draw_line(Vector2(0.30, -0.13), Vector2(0.24, -0.24), cor, 0.022)
	_tela.draw_colored_polygon(PackedVector2Array([Vector2(0.06, 0.02), Vector2(0.56, 0.075), Vector2(0.60, 0.115), Vector2(0.56, 0.15), Vector2(0.06, 0.11)]), cor)
	# o visor aceso
	_tela.draw_rect(Rect2(0.33, -0.065, 0.075, 0.035), Color(LARANJA, a))
	_tela.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
