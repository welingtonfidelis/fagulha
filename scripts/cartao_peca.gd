class_name CartaoPeca
extends CanvasLayer
## A janela de peça nova (2026-11-20): quando uma peça é instalada ou uma arma é fabricada, o jogo para e
## aparece um cartão dizendo o que aquilo faz e como se usa. É pensado também para quem não lê: uma figura
## grande do efeito, o botão do controle (ou a tecla) em tamanho grande, e só depois uma frase curta.
## Fecha com X, círculo, Enter ou Esc. Com várias de uma vez, mostra uma depois da outra.

const TINTA := Color(0.93, 0.94, 0.9)
const APAGADO := Color(0.62, 0.68, 0.66)
const LARANJA := Color(1.0, 0.62, 0.3)
const AGUA := Color(0.35, 0.95, 0.85)
## nome -> [título, frase, botões no controle, teclas, figura]. Sem botão: a peça funciona sozinha.
const PECAS := {
	"antena": ["Antena de busca", "A bússola mostra as peças que estiverem por perto.", "", "", "bussola"],
	"radiador": ["Radiador de aletas", "O motor esquenta mais devagar: dá para voar mais tempo.", "", "", "calor"],
	"radiador2": ["Radiador duplo", "O motor quase não esquenta: voa três vezes mais.", "", "", "calor2"],
	"bocais": ["Bocais largos", "A arrancada no ar fica mais rápida.", "{@al} para a frente", "{@k_w}", "veloz"],
	"asas": ["Asas de planar", "No voo, segure para desligar o jato e planar. Planando o motor esfria.", "segurar {@x}", "segurar {@k_shift}", "asas"],
	"barbatanas": ["Barbatanas", "O nado rápido fica mais veloz e vence a correnteza.", "{@al} até o fim", "{@k_shift}", "agua"],
	"amortecedores": ["Molas", "Pula mais alto e pousa sem tranco.", "{@x}", "{@k_espaco}", "pulo"],
	"farol": ["Luz do peito", "Acende e apaga uma luz para a noite e para as cavernas.", "{@cima}", "{@k_l}", "luz"],
	"celulas": ["Células de reserva", "No chão, o motor esfria mais depressa.", "", "", "frio"],
	"scanner": ["Scanner", "Olha pelos olhos do robô e diz o que é cada bicho e cada máquina.", "{@dir}", "{@k_t}", "olho"],
	"mira": ["Mira assistida", "Mirando, o tiro trava na máquina mais perto da mira.", "{@l2}", "{@m_dir}", "mira"],
	"rajada": ["Rajada", "Muitos tiros fracos, um atrás do outro. Esquenta.", "segurar {@r2}", "segurar {@m_esq}", "tiros"],
	"canhao": ["Canhão", "Segure para carregar e solte: um tiro forte que estoura.", "segurar e soltar {@r2}", "segurar e soltar {@m_esq}", "bola"],
	"precisao": ["Precisão", "Chega perto com a mira e dá um tiro forte e lento.", "{@l2} e {@r2}", "{@m_dir} e {@m_esq}", "mira"],
	"duplo": ["Tiro duplo", "Um gatilho para cada braço.", "{@l2} · {@r2}", "{@m_dir} · {@m_esq}", "tiros"],
	"misseis": ["Mísseis", "Segure para marcar até quatro máquinas e solte.", "segurar e soltar {@r2}", "segurar e soltar {@m_esq}", "missil"],
	"granadas": ["Granadas", "Segure para ver o arco e solte para lançar.", "segurar e soltar {@r1}", "{@k_g}", "bola"],
	"escudo": ["Escudo de energia", "Engole três acertos e depois recarrega sozinho.", "", "", "escudo"],
	"vida": ["Vida extra", "O robô aguenta um acerto a mais antes de desligar.", "", "", "coracao"],
}

static var ativo: CartaoPeca  # o cartão do jogo (quem instala ou fabrica chama `CartaoPeca.avisar`)

var aberto := ""  # a peça que está na tela agora
var mostrados := 0  # testes
var _fila: Array[String] = []
var _figura: Control
var _titulo: Label
var _frase: Label
var _botoes: TextoBotoes
var _sem_botao: Label
var _espera := 0.0
var _pausou := false


## Pede o cartão de `nome` (não faz nada fora do jogo de verdade ou para o que não tem cartão).
static func avisar(nome: String) -> void:
	if ativo and is_instance_valid(ativo) and PECAS.has(nome):
		ativo.mostrar(nome)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sem_pausa")
	visible = false
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.06, 0.07, 0.62)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var cartao := PanelContainer.new()
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = Color(0.045, 0.075, 0.08, 0.97)
	caixa.border_color = Color(0.2, 0.3, 0.31)
	caixa.set_border_width_all(2)
	caixa.set_corner_radius_all(8)
	caixa.set_content_margin_all(30)
	cartao.add_theme_stylebox_override("panel", caixa)
	centro.add_child(cartao)
	var pilha := VBoxContainer.new()
	pilha.add_theme_constant_override("separation", 14)
	pilha.custom_minimum_size = Vector2(600, 0)
	cartao.add_child(pilha)
	var topo := Label.new()
	topo.text = "PEÇA NOVA"
	topo.add_theme_font_size_override("font_size", 17)  # letras maiores desde 2026-11-20 (revisão dos menus)
	topo.add_theme_color_override("font_color", APAGADO)
	pilha.add_child(topo)
	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 36)
	_titulo.add_theme_color_override("font_color", LARANJA)
	pilha.add_child(_titulo)
	_figura = Control.new()
	_figura.custom_minimum_size = Vector2(600, 190)
	_figura.draw.connect(_desenhar_figura)
	pilha.add_child(_figura)
	_botoes = TextoBotoes.new()
	_botoes.tamanho = 34
	_botoes.cor = TINTA
	_botoes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pilha.add_child(_botoes)
	_sem_botao = Label.new()
	_sem_botao.text = "funciona sozinha"
	_sem_botao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sem_botao.add_theme_font_size_override("font_size", 23)
	_sem_botao.add_theme_color_override("font_color", AGUA)
	pilha.add_child(_sem_botao)
	_frase = Label.new()
	_frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frase.add_theme_font_size_override("font_size", 23)
	_frase.add_theme_color_override("font_color", TINTA)
	pilha.add_child(_frase)
	var rodape := TextoBotoes.new()
	rodape.texto = "{@x}  continuar"
	rodape.tamanho = 20
	rodape.cor = APAGADO
	rodape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pilha.add_child(rodape)


## A pausa não abre por cima do cartão.
func ocupada() -> bool:
	return visible


func mostrar(nome: String) -> void:
	if not PECAS.has(nome) or nome == aberto or _fila.has(nome):
		return
	_fila.append(nome)
	if aberto == "":
		_proximo()


func _proximo() -> void:
	if _fila.is_empty():
		aberto = ""
		visible = false
		if _pausou:
			_pausou = false
			get_tree().paused = false
		return
	aberto = _fila.pop_front()
	mostrados += 1
	var d: Array = PECAS[aberto]
	_titulo.text = d[0]
	_frase.text = d[1]
	var tem_botao := String(d[2]) != ""
	_botoes.visible = tem_botao
	_sem_botao.visible = not tem_botao
	_botoes.texto = (String(d[2]) if Botoes.controle else String(d[3])) if tem_botao else ""
	_figura.queue_redraw()
	visible = true
	_espera = 0.6  # um instante antes de aceitar o botão, para o aperto de antes não fechar
	if not get_tree().paused:
		_pausou = true
		get_tree().paused = true


func fechar() -> void:
	if aberto != "":
		_proximo()


func _process(delta: float) -> void:
	if aberto == "":
		return
	_espera -= delta
	_figura.queue_redraw()
	var d: Array = PECAS[aberto]
	if String(d[2]) != "":
		_botoes.texto = String(d[2]) if Botoes.controle else String(d[3])
	if _espera <= 0.0 and (Input.is_action_just_pressed("pular") or Input.is_action_just_pressed("soltar") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel")):
		fechar()


# ---------------------------------------------------------------- as figuras

func _robo(c: Vector2, s: float, cor := TINTA) -> void:
	# um robozinho de bloco: cabeça, corpo e pés
	_figura.draw_rect(Rect2(c + Vector2(-13, -34) * s, Vector2(26, 20) * s), cor)
	_figura.draw_rect(Rect2(c + Vector2(-8, -30) * s, Vector2(16, 9) * s), Color(0.05, 0.08, 0.1))
	_figura.draw_rect(Rect2(c + Vector2(-9, -12) * s, Vector2(18, 16) * s), cor)
	_figura.draw_rect(Rect2(c + Vector2(-10, 6) * s, Vector2(8, 10) * s), cor)
	_figura.draw_rect(Rect2(c + Vector2(2, 6) * s, Vector2(8, 10) * s), cor)


func _seta(de: Vector2, para: Vector2, cor: Color, grosso := 5.0) -> void:
	_figura.draw_line(de, para, cor, grosso, true)
	var d := (para - de).normalized()
	var n := Vector2(-d.y, d.x)
	_figura.draw_colored_polygon(PackedVector2Array([para + d * 12.0, para - d * 6.0 + n * 10.0, para - d * 6.0 - n * 10.0]), cor)


func _barra_calor(c: Vector2, cheio: float, cor: Color) -> void:
	_figura.draw_rect(Rect2(c + Vector2(-70, -14), Vector2(140, 28)), Color(0.12, 0.16, 0.17))
	_figura.draw_rect(Rect2(c + Vector2(-66, -10), Vector2(132 * cheio, 20)), cor)
	_figura.draw_rect(Rect2(c + Vector2(-70, -14), Vector2(140, 28)), Color(0.4, 0.5, 0.5), false, 2.0)


func _desenhar_figura() -> void:
	if aberto == "":
		return
	var c := _figura.size * 0.5
	var t := Time.get_ticks_msec() * 0.001
	var vai := fposmod(t * 0.6, 1.0)  # 0 a 1, em laço: as figuras se mexem
	match String(PECAS[aberto][4]):
		"bussola":
			_figura.draw_rect(Rect2(c + Vector2(-190, -22), Vector2(380, 44)), Color(0.1, 0.14, 0.15))
			for k in 9:
				_figura.draw_line(c + Vector2(-160 + k * 40, 6), c + Vector2(-160 + k * 40, 18), APAGADO, 2.0)
			var x := lerpf(-150.0, 110.0, 0.5 + 0.5 * sin(t * 1.3))
			_figura.draw_colored_polygon(PackedVector2Array([c + Vector2(x, 12), c + Vector2(x - 12, -12), c + Vector2(x + 12, -12)]), Color(0.3, 1.0, 0.8))
			_figura.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 34), c + Vector2(-9, 48), c + Vector2(9, 48)]), TINTA)
		"calor", "calor2":
			var duplo := String(PECAS[aberto][4]) == "calor2"
			_barra_calor(c + Vector2(-110, -40), 0.4 + 0.55 * vai, Color(1.0, 0.4, 0.15))
			_barra_calor(c + Vector2(-110, 40), 0.12 + (0.2 if duplo else 0.32) * vai, AGUA)
			_seta(c + Vector2(-110, -18), c + Vector2(-110, 14), TINTA)
			_robo(c + Vector2(120, 10 - 30 * sin(vai * PI)), 2.0)
			for k in (3 if duplo else 2):
				_figura.draw_arc(c + Vector2(60 + k * 14, 40), 9.0, -PI * 0.5, PI * 0.5, 10, AGUA, 3.0, true)
		"veloz":
			_robo(c + Vector2(-120 + 240 * vai, 10), 2.0)
			for k in 4:
				_figura.draw_line(c + Vector2(-170 + 240 * vai - k * 22, -24 + k * 16), c + Vector2(-210 + 240 * vai - k * 22, -24 + k * 16), LARANJA, 4.0, true)
		"asas":
			var p := c + Vector2(-150 + 300 * vai, -40 + 70 * vai)
			_figura.draw_colored_polygon(PackedVector2Array([p + Vector2(-70, 4), p + Vector2(0, -16), p + Vector2(70, 4), p + Vector2(0, 2)]), AGUA)
			_robo(p + Vector2(0, 18), 1.5)
			_figura.draw_arc(c + Vector2(-150, -150), 200.0, 0.5, 1.2, 20, Color(TINTA, 0.35), 2.0, true)
		"agua":
			for k in 3:
				var pts := PackedVector2Array()
				for i in 30:
					pts.append(c + Vector2(-200 + i * 14, -40 + k * 40 + sin(i * 0.7 + t * 3.0 + k) * 7.0))
				_figura.draw_polyline(pts, Color(0.3, 0.7, 1.0, 0.8), 3.0, true)
			_robo(c + Vector2(-120 + 240 * vai, 6), 1.8)
			_seta(c + Vector2(-190 + 240 * vai, 6), c + Vector2(-150 + 240 * vai, 6), LARANJA)
		"pulo":
			var alto := sin(vai * PI)
			_figura.draw_line(c + Vector2(-180, 78), c + Vector2(180, 78), APAGADO, 3.0)
			_robo(c + Vector2(-70, 40 - 50 * alto), 1.6, APAGADO)
			_robo(c + Vector2(70, 40 - 110 * alto), 2.0)
			for k in 5:
				_figura.draw_line(c + Vector2(58 + (k % 2) * 24, 70 - k * 4), c + Vector2(82 - (k % 2) * 24, 66 - k * 4), LARANJA, 3.0)
			_seta(c + Vector2(140, 60), c + Vector2(140, -50), LARANJA)
		"luz":
			_robo(c + Vector2(-90, 14), 2.2)
			var aceso := fposmod(t, 2.0) < 1.3
			if aceso:
				_figura.draw_colored_polygon(PackedVector2Array([c + Vector2(-70, 0), c + Vector2(190, -70), c + Vector2(190, 70)]), Color(1.0, 0.9, 0.5, 0.45))
			_figura.draw_circle(c + Vector2(-72, 2), 8.0, Color(1.0, 0.9, 0.5) if aceso else Color(0.3, 0.3, 0.3))
		"frio":
			_figura.draw_line(c + Vector2(-180, 60), c + Vector2(180, 60), APAGADO, 3.0)
			_robo(c + Vector2(-80, 30), 2.0)
			_barra_calor(c + Vector2(90, -10), 0.9 - 0.8 * vai, AGUA.lerp(Color(1.0, 0.4, 0.15), 1.0 - vai))
			_seta(c + Vector2(90, 20), c + Vector2(90, 52), AGUA)
		"olho":
			_figura.draw_arc(c, 60.0, 0, TAU, 40, TINTA, 4.0, true)
			_figura.draw_arc(c, 26.0 + 6.0 * sin(t * 3.0), 0, TAU, 30, AGUA, 3.0, true)
			_figura.draw_circle(c, 9.0, AGUA)
			for k in 4:
				var d := Vector2.from_angle(k * PI * 0.5 + PI * 0.25)
				_figura.draw_line(c + d * 74.0, c + d * 92.0, TINTA, 4.0)
		"mira":
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				_figura.draw_line(c + d * 16.0, c + d * 44.0, TINTA, 4.0, true)
			var alvo := c + Vector2(110 - 110 * minf(1.0, vai * 1.6), -30 + 30 * minf(1.0, vai * 1.6))
			_figura.draw_rect(Rect2(alvo - Vector2(14, 14), Vector2(28, 28)), Color(1.0, 0.35, 0.25), false, 4.0)
		"tiros":
			_robo(c + Vector2(-150, 14), 2.0)
			for k in 5:
				var x := fposmod(vai + k * 0.2, 1.0)
				_figura.draw_line(c + Vector2(-110 + x * 290, 6), c + Vector2(-86 + x * 290, 6), LARANJA, 5.0, true)
		"bola":
			_robo(c + Vector2(-150, 30), 2.0)
			var p2 := c + Vector2(-110 + 260 * vai, 10 - 120 * sin(vai * PI))
			if vai < 0.9:
				_figura.draw_circle(p2, 10.0, LARANJA)
			else:
				_figura.draw_arc(c + Vector2(150, 30), 36.0 * (vai - 0.9) * 10.0, 0, TAU, 24, LARANJA, 5.0, true)
		"missil":
			_robo(c + Vector2(-160, 30), 2.0)
			for k in 3:
				var alvo2 := c + Vector2(120, -60 + k * 60)
				_figura.draw_rect(Rect2(alvo2 - Vector2(13, 13), Vector2(26, 26)), Color(1.0, 0.35, 0.25), false, 3.0)
				var x2 := minf(1.0, vai * 1.3)
				var de := c + Vector2(-130, 0)
				_figura.draw_line(de, de.lerp(alvo2, x2), Color(TINTA, 0.5), 2.0, true)
				_figura.draw_circle(de.lerp(alvo2, x2), 6.0, LARANJA)
		"escudo":
			_robo(c + Vector2(0, 14), 2.2)
			_figura.draw_arc(c + Vector2(0, 0), 78.0 + 4.0 * sin(t * 4.0), 0, TAU, 40, Color(AGUA, 0.85), 5.0, true)
			_figura.draw_line(c + Vector2(190 - 100 * vai, -10), c + Vector2(170 - 100 * vai, -10), Color(1.0, 0.35, 0.25), 5.0, true)
		"coracao":
			for k in 4:
				var p3 := c + Vector2(-105 + k * 70, 0)
				var cor := Color(1.0, 0.35, 0.3) if k < 3 else LARANJA.lerp(TINTA, 0.5 + 0.5 * sin(t * 5.0))
				_figura.draw_circle(p3 + Vector2(-10, -8), 14.0, cor)
				_figura.draw_circle(p3 + Vector2(10, -8), 14.0, cor)
				_figura.draw_colored_polygon(PackedVector2Array([p3 + Vector2(-23, -2), p3 + Vector2(23, -2), p3 + Vector2(0, 28)]), cor)
