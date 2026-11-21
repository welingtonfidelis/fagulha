class_name CartaoPeca
extends CanvasLayer
## A janela de peça nova (2026-11-20): quando uma peça é instalada ou uma arma é fabricada, o jogo para e
## aparece um cartão dizendo o que aquilo faz e como se usa. Desde 2026-11-21 ele é o tablet fechado (doc §136):
## o nome da peça no título, a planta azul com o ícone, "Como usar" com o anel e o botão do controle, e o botão
## laranja de continuar. Fecha com X, círculo, Enter ou Esc. Com várias de uma vez, mostra uma depois da outra.

## nome -> [título, frase, botões no controle, teclas]. Sem botão: a peça funciona sozinha.
## O nome da peça também é o nome do ícone em Icones.
const PECAS := {
	"antena": ["Antena de busca", "A bússola mostra as peças que estiverem por perto.", "", ""],
	"radiador": ["Radiador de aletas", "O motor esquenta mais devagar: dá para voar mais tempo.", "", ""],
	"radiador2": ["Radiador duplo", "O motor quase não esquenta: voa três vezes mais.", "", ""],
	"bocais": ["Bocais largos", "A arrancada no ar fica mais rápida.", "{@al} para a frente", "{@k_w}"],
	"asas": ["Asas de planar", "No voo, segure para desligar o jato e planar. Planando o motor esfria.", "segurar {@x}", "segurar {@k_shift}"],
	"barbatanas": ["Barbatanas", "O nado rápido fica mais veloz e vence a correnteza.", "{@al} até o fim", "{@k_shift}"],
	"amortecedores": ["Molas", "Pula mais alto e pousa sem tranco.", "{@x}", "{@k_espaco}"],
	"farol": ["Luz do peito", "Acende e apaga uma luz para a noite e para as cavernas.", "{@cima}", "{@k_l}"],
	"celulas": ["Células de reserva", "No chão, o motor esfria mais depressa.", "", ""],
	"scanner": ["Scanner", "Olha pelos olhos do robô e diz o que é cada bicho e cada máquina.", "{@dir}", "{@k_t}"],
	"mira": ["Mira assistida", "Mirando, o tiro trava na máquina mais perto da mira.", "{@l2}", "{@m_dir}"],
	"rajada": ["Rajada", "Muitos tiros fracos, um atrás do outro. Esquenta.", "segurar {@r2}", "segurar {@m_esq}"],
	"canhao": ["Canhão", "Segure para carregar e solte: um tiro forte que estoura.", "segurar e soltar {@r2}", "segurar e soltar {@m_esq}"],
	"precisao": ["Precisão", "Chega perto com a mira e dá um tiro forte e lento.", "{@l2} e {@r2}", "{@m_dir} e {@m_esq}"],
	"duplo": ["Tiro duplo", "Um gatilho para cada braço.", "{@l2} · {@r2}", "{@m_dir} · {@m_esq}"],
	"misseis": ["Mísseis", "Segure para marcar até quatro máquinas e solte.", "segurar e soltar {@r2}", "segurar e soltar {@m_esq}"],
	"granadas": ["Granadas", "Segure para ver o arco e solte para lançar.", "segurar e soltar {@r1}", "{@k_g}"],
	"escudo": ["Escudo de energia", "Engole três acertos e depois recarrega sozinho.", "", ""],
	"vida": ["Vida extra", "O robô aguenta um acerto a mais antes de desligar.", "", ""],
}

static var ativo: CartaoPeca  # o cartão do jogo (quem instala ou fabrica chama `CartaoPeca.avisar`)

var aberto := ""  # a peça que está na tela agora
var mostrados := 0  # testes
var _fila: Array[String] = []
var _tablet: TabletCasca
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
	fundo.color = Color(0.02, 0.04, 0.06, 0.3)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	_tablet = TabletCasca.new()
	_tablet.aberto = false
	_tablet.size = Vector2(480, 820)
	_tablet.custom_minimum_size = Vector2(480, 820)
	_tablet.rotulo = "Peça nova"
	_tablet.pintor = _pintar
	centro.add_child(_tablet)


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
	_tablet.queue_redraw()
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
	if _espera <= 0.0 and (Input.is_action_just_pressed("pular") or Input.is_action_just_pressed("soltar") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel")):
		fechar()


# ---------------------------------------------------------------- o tablet

## O botão do controle (ou da tecla) que a peça usa agora, conforme o aparelho em uso.
static func _texto_botoes(d: Array) -> String:
	return String(d[2]) if Botoes.controle else String(d[3])


## O primeiro botão citado no texto ("segurar {@x}" -> "x"), para a figura grande do anel.
static func _botao_da(s: String) -> String:
	var i := s.find("{@")
	if i < 0:
		return "x"
	return s.substr(i + 2, s.find("}", i) - i - 2)


func _pintar(c: CanvasItem, telas: Array) -> void:
	if aberto == "":
		return
	var t: Rect2 = telas[0]
	var d: Array = PECAS[aberto]
	var tem_botao := String(d[2]) != ""
	Tablet.texto(c, Vector2(t.position.x, t.position.y + 96), String(d[0]), 32, Tablet.TINTA, true, HORIZONTAL_ALIGNMENT_CENTER, t.size.x)
	Tablet.planta(c, Rect2(t.position.x + 18, t.position.y + 118, t.size.x - 36, 262), aberto, "peça da ilha")
	Tablet.texto(c, Vector2(t.position.x + 24, t.position.y + 404), "Como usar", 18, Tablet.TINTA, true)
	# o quadro "Como usar": a figura do botão, o que ele faz e a frase; sem botão, só a frase
	var uso := Rect2(t.position.x + 18, t.position.y + 418, t.size.x - 36, maxf(120.0, 84.0 + Tablet.altura_paragrafo(String(d[1]), 274.0, 17)))
	Tablet.caixa(c, uso, Tablet.CLARO, 18)
	var frase_x := uso.position.x + 24.0
	if tem_botao:
		var gc := Vector2(uso.position.x + 60.0, uso.get_center().y)
		var texto_botoes := _texto_botoes(d)
		c.draw_arc(gc, 34, 0, TAU, 40, Color(Tablet.TINTA, 0.15), 6.0, true)
		c.draw_arc(gc, 34, -PI / 2.0, -PI / 2.0 + TAU * 0.7, 40, Tablet.LARANJA_V, 6.0, true)
		Tablet.botao(c, _botao_da(texto_botoes), gc, 44)
		frase_x = uso.position.x + 112.0
		Tablet.com_botoes(c, Vector2(frase_x, uso.position.y + 52), texto_botoes, 21, Tablet.TINTA)
	else:
		Tablet.texto(c, Vector2(frase_x, uso.position.y + 52), "funciona sozinha", 21, Tablet.TINTA, true)
	Tablet.paragrafo(c, Vector2(frase_x, uso.position.y + 80), String(d[1]), uso.end.x - frase_x - 20.0, 17, Color(Tablet.TINTA, 0.7))
	# o botão laranja de continuar (fecha como o X, o círculo, Enter ou Esc)
	var bt := Rect2(t.position.x + 90, t.end.y - 108, t.size.x - 180, 60)
	Tablet.caixa(c, bt, Tablet.LARANJA_V, 30)
	Tablet.botao(c, "x", bt.position + Vector2(34, 30), 30)
	Tablet.texto(c, bt.position + Vector2(60, 38), "continuar", 21, Color.WHITE, true)
