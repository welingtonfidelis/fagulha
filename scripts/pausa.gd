class_name Pausa
extends CanvasLayer
## Pausa (Esc / Options). Um cartão no meio da tela com poucas escolhas grandes: continuar, voltar à base,
## comandos, vibração e sair. Os comandos ficam numa página à parte, em tabela (ação de um lado, botão do
## outro), com uma aba para o controle e outra para o teclado; uma dica diferente aparece a cada vez.
## Refeito em 2026-11-16 a pedido do usuário ("um menu de pause mais amigável"): antes era uma coluna de
## botões com um parágrafo de comandos embaixo.
## Revisto em 2026-11-20 (itens 1 a 4 da revisão das telas): letra maior para ler da TV, uma figura em cada
## botão, ajustes com o valor entre setas (o direcional para os lados muda) e o "apagar" à parte, em vermelho, e
## o caderno com o mapa grande. O caderno saiu da lista: abre pelo touchpad do DualSense / M.

const T_TITULO := 34
const T_SUB := 17
const T_BOTAO := 24
const T_EXPLICA := 17
const T_DICA := 19
const T_RODAPE := 17
const T_TABELA := 18
const T_GRUPO := 16
# os textos curtos, para não encostar na explicação à direita do botão (letra 24 desde 2026-11-20)
const APAGAR := "Apagar o progresso"
const LARG_CADERNO := 620.0  # a coluna da direita do caderno, ao lado do mapa de 500
const VERMELHO := Color(1.0, 0.45, 0.4)

const LARANJA := Color(1.0, 0.62, 0.3)
const AGUA := Color(0.35, 0.95, 0.85)
const TINTA := Color(0.93, 0.94, 0.9)
const APAGADO := Color(0.62, 0.68, 0.66)
const DICAS := [
	"Mergulhar, a chuva e voar rente à água esfriam o motor.",
	"Segure o pulo para decolar reto e sair voando.",
	"A mira assistida se fabrica na oficina: com ela, o tiro trava na máquina mais perto da mira.",
	"As máquinas não são destruídas: desligam e religam depois.",
	"Atrás de uma árvore ou de uma pedra, o tiro delas não chega.",
	"Se o robô desligar, o drone colega vem buscar e leva para a base.",
	"Na água funda o robô nada com os jatos, e isso esfria o motor.",
	"Parado, a seta para a esquerda tira a câmera de trás do robô para você olhar a paisagem.",
	"O touchpad do controle (ou o M) abre o caderno: o mapa, as memórias e o que o scanner leu.",
]
# [o que é, no controle, no teclado e mouse]. `{@nome}` vira a imagem do botão (ver Botoes).
const COMANDOS := [
	["NO CHÃO", "", ""],
	["Andar · olhar", "{@al} · {@ar}", "{@k_w}{@k_a}{@k_s}{@k_d} · {@m}"],
	["Correr", "{@al} até o fim", "{@k_shift}"],
	["Pular · pulo duplo", "{@x} · {@x} no ar", "{@k_espaco}"],
	["Esquiva", "{@o}", "{@k_c}"],
	["Apreciar a vista (parado)", "{@esq}", "{@k_ctrl}"],
	["NO AR", "", ""],
	["Voar (do chão ou do ar)", "segurar {@x}", "segurar {@k_espaco}"],
	["Parar no ar · voltar a voar", "toque em {@x}", "toque em {@k_espaco}"],
	["Desligar os jatos e cair", "parado: segurar {@x} · voando: toque e segure {@x}", "parado: segurar {@k_espaco} · voando: {@k_shift}"],
	["Arrancada · frear", "{@al} para a frente · para trás", "{@k_w} · {@k_s}"],
	["Planar · voltar ao jato (asas)", "segurar {@x}", "segurar {@k_espaco}"],
	["Manobra (giro para o lado)", "{@o}", "{@k_c}"],
	["Mergulho com impacto", "{@tri}", "{@k_v}"],
	["COMBATE", "", ""],
	["Mirar · atirar", "{@l2} · {@r2}", "{@m_dir} · {@m_esq}"],
	["Trocar de arma", "toque em {@l1} · segurar: roda", "{@k_r} · {@k_1} a {@k_6}"],
	["Granada", "segurar e soltar {@r1}", "{@k_g}"],
	["Espada de laser", "{@quad} no chão", "{@k_x}"],
	["OUTROS", "", ""],
	["Oficina · sentar · acordar e trocar de robô", "{@tri} no chão, perto", "{@k_e}"],
	["Luz · scanner (melhorias)", "{@cima} · {@dir}", "{@k_l} · {@k_t}"],
	["Marcar um ponto", "{@baixo}", "{@k_q}"],
	["Caderno: mapa e memórias", "{@touchpad}", "{@k_m}"],
	["Nadar: subir · descer", "{@x} · {@o}", "{@k_espaco} · {@k_c}"],
	["Pausa · medidor", "{@options} · {@create}", "{@k_esc} · {@k_f3}"],
]

const SUBTITULO := "Faísca 2 · Em Busca do Sossego"

var armadura: Armadura
var na_simulacao := false  # a pausa do tutorial: "Acordar" no lugar de "Voltar à base"
var aberturas := 0  # quantas vezes abriu (testes)
var _cartao: PanelContainer
var _inicio: Control
var _pagina_comandos: Control
var _primeiro: Button
var _botao_comandos: Button
var _botao_vibra: Button
var _botao_ajustes: Button
var _botao_qualidade: Button
var _botao_sens: Button
var _botao_eixo: Button
var _botao_apagar: Button
var _voltar_ajustes: Button
var _pagina_ajustes: Control
var _botao_sair: Button
var _voltar_comandos: Button
var _dica: Label
var _colunas: Array[TextoBotoes] = []  # as células de botão da tabela (trocam com a aba)
var _aba_controle: Button
var _aba_teclado: Button
var _saindo := false
var _titulo: Label
var _subtitulo: Label
var _botao_voltar: Button
var _pagina_caderno: Control
var _botao_caderno: Button
var _caderno_mapa: MapaCaderno
var _caderno_contas: Label
var _caderno_memorias: GridContainer
var _caderno_texto: Label
var _caderno_scanner: Label
var _voltar_caderno: Button
var abertura := false  # a pausa fazendo de tela de abertura (ao abrir o jogo): Continuar ou Começar, Novo jogo, Ajustes, Sair
var _botao_novo: Button
var _botao_mundo: Button
var avisos_controle := 0  # quantas vezes a pausa abriu por o controle ter desconectado (testes)
var _so_caderno := false  # o caderno abriu sozinho (touchpad / M): voltar fecha e solta o jogo
var _rodape: Label
var cadernos := 0  # quantas vezes o caderno abriu pelo botão próprio (testes)
# a telinha de Sim e Não que confirma sair, começar um jogo novo e apagar o progresso (2026-11-20; antes era
# "aperte de novo" escrito no próprio botão, comprido demais com a letra grande)
var _confirma: ColorRect
var _confirma_caixa: PanelContainer
var _confirma_figura: IconeMenu
var _confirma_pergunta: Label
var _confirma_frase: Label
var _confirma_nao: Button
var _confirma_sim: Button
var _confirma_acao := ""  # "sair", "apagar" ou "novo"
var _confirma_volta: Control  # o botão que abriu a telinha, para o foco voltar a ele no "Não"


## As figuras dos botões da pausa, desenhadas (no estilo dos ícones dos cartões): acendem em laranja com o foco.
class IconeMenu extends Control:
	const ESCURO := Color(0.06, 0.09, 0.1)
	var tipo := ""
	var cor := Color(0.93, 0.94, 0.9)

	## `lado`: o tamanho em pixels; o desenho é feito em 36 e escalado (a telinha de confirmação usa 64).
	func _init(t: String, lado := 36.0) -> void:
		tipo = t
		custom_minimum_size = Vector2(lado, lado)
		size = Vector2(lado, lado)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (size.x / 36.0))
		var c := Vector2(18, 18)
		var r := 17.0
		match tipo:
			"sim":
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.62, r * 0.02), c + Vector2(-r * 0.15, r * 0.5), c + Vector2(r * 0.68, -r * 0.5)]), cor, 3.5, true)
			"nao":
				draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), cor, 3.5, true)
				draw_line(c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.5, r * 0.5), cor, 3.5, true)
			"continuar":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.62), c + Vector2(r * 0.68, 0), c + Vector2(-r * 0.45, r * 0.62)]), cor)
			"comandos":
				# um controle: corpo, duas pegadas, a cruz à esquerda e dois botões à direita
				draw_rect(Rect2(c.x - r * 0.62, c.y - r * 0.42, r * 1.24, r * 0.7), cor)
				draw_circle(c + Vector2(-r * 0.62, -r * 0.07), r * 0.35, cor)
				draw_circle(c + Vector2(r * 0.62, -r * 0.07), r * 0.35, cor)
				draw_circle(c + Vector2(-r * 0.72, r * 0.3), r * 0.26, cor)
				draw_circle(c + Vector2(r * 0.72, r * 0.3), r * 0.26, cor)
				draw_rect(Rect2(c.x - r * 0.78, c.y - r * 0.13, r * 0.38, r * 0.12), ESCURO)
				draw_rect(Rect2(c.x - r * 0.65, c.y - r * 0.26, r * 0.12, r * 0.38), ESCURO)
				draw_circle(c + Vector2(r * 0.5, -r * 0.18), r * 0.09, ESCURO)
				draw_circle(c + Vector2(r * 0.7, r * 0.0), r * 0.09, ESCURO)
			"simulacao":
				# um cubo de arame, como o chão do holograma
				var t := r * 0.85
				var pts := PackedVector2Array([c + Vector2(0, -t), c + Vector2(t * 0.87, -t * 0.5), c + Vector2(t * 0.87, t * 0.5),
					c + Vector2(0, t), c + Vector2(-t * 0.87, t * 0.5), c + Vector2(-t * 0.87, -t * 0.5), c + Vector2(0, -t)])
				draw_polyline(pts, cor, 2.5, true)
				draw_polyline(PackedVector2Array([c + Vector2(-t * 0.87, -t * 0.5), c, c + Vector2(t * 0.87, -t * 0.5)]), cor, 2.5, true)
				draw_line(c, c + Vector2(0, t), cor, 2.5, true)
			"ajustes":
				for k in 8:
					var ang := k * TAU / 8.0
					var dir := Vector2.from_angle(ang)
					var lado := dir.orthogonal()
					var base := c + dir * r * 0.55
					var ponta := c + dir * r * 0.92
					draw_colored_polygon(PackedVector2Array([base + lado * r * 0.2, ponta + lado * r * 0.14, ponta - lado * r * 0.14, base - lado * r * 0.2]), cor)
				draw_circle(c, r * 0.62, cor)
				draw_circle(c, r * 0.24, ESCURO)
			"sair":
				# uma porta e a seta saindo por ela
				draw_rect(Rect2(c.x - r * 0.75, c.y - r * 0.8, r * 0.85, r * 1.6), cor, false, 2.5)
				draw_circle(c + Vector2(-r * 0.12, r * 0.05), r * 0.08, cor)
				draw_line(c + Vector2(-r * 0.05, 0), c + Vector2(r * 0.85, 0), cor, 2.5, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.95, 0), c + Vector2(r * 0.6, -r * 0.3), c + Vector2(r * 0.6, r * 0.3)]), cor)
			"novo":
				var p4 := PackedVector2Array()
				for k in 8:
					p4.append(c + Vector2.from_angle(k * TAU / 8.0 - PI * 0.5) * (r * 0.9 if k % 2 == 0 else r * 0.28))
				draw_colored_polygon(p4, cor)
			"acordar":
				draw_circle(c, r * 0.4, cor)
				for k in 8:
					var d := Vector2.from_angle(k * TAU / 8.0)
					draw_line(c + d * r * 0.6, c + d * r * 0.92, cor, 2.5, true)
			"casa":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.85), c + Vector2(r * 0.85, -r * 0.05), c + Vector2(-r * 0.85, -r * 0.05)]), cor)
				draw_rect(Rect2(c.x - r * 0.6, c.y - r * 0.1, r * 1.2, r * 0.85), cor)
				draw_rect(Rect2(c.x - r * 0.17, c.y + r * 0.25, r * 0.34, r * 0.5), ESCURO)
			"voltar":
				draw_line(c + Vector2(r * 0.8, 0), c + Vector2(-r * 0.5, 0), cor, 3.0, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.85, 0), c + Vector2(-r * 0.35, -r * 0.45), c + Vector2(-r * 0.35, r * 0.45)]), cor)
			"apagar":
				# uma lixeira
				draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.45, r * 1.1, r * 1.25), cor, false, 2.5)
				draw_line(c + Vector2(-r * 0.8, -r * 0.62), c + Vector2(r * 0.8, -r * 0.62), cor, 2.5, true)
				draw_rect(Rect2(c.x - r * 0.22, c.y - r * 0.85, r * 0.44, r * 0.22), cor)
				for k in 3:
					var x := c.x + (k - 1) * r * 0.3
					draw_line(Vector2(x, c.y - r * 0.2), Vector2(x, c.y + r * 0.6), cor, 2.0, true)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.06, 0.07, 0.78)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	_cartao = PanelContainer.new()
	_cartao.add_theme_stylebox_override("panel", _caixa(Color(0.045, 0.075, 0.08, 0.96), 8, 32, Color(0.2, 0.3, 0.31)))
	centro.add_child(_cartao)
	var pilha := VBoxContainer.new()
	pilha.add_theme_constant_override("separation", 18)
	_cartao.add_child(pilha)
	# cabeçalho
	var topo := VBoxContainer.new()
	topo.add_theme_constant_override("separation", 2)
	pilha.add_child(topo)
	_titulo = _texto("Pausa", T_TITULO, TINTA)
	topo.add_child(_titulo)
	_subtitulo = _texto(SUBTITULO, T_SUB, APAGADO)
	topo.add_child(_subtitulo)
	# página inicial: cada botão com uma figura à esquerda (quem não lê acha pela figura)
	_inicio = VBoxContainer.new()
	_inicio.add_theme_constant_override("separation", 10)
	pilha.add_child(_inicio)
	_primeiro = _botao(_inicio, "Continuar", "volta ao jogo", _continuar, true, "continuar")
	_botao_novo = _botao(_inicio, "Novo jogo", "apaga o progresso e começa do zero", _novo_jogo, false, "novo")
	_botao_novo.visible = false
	if na_simulacao:
		_botao_mundo = _botao(_inicio, "Acordar", "sai da simulação e vai para a ilha", _trocar_mundo.bind(false), false, "acordar")
	# "Voltar à base" saiu da pausa do jogo (pedido do usuário, 2026-11-20); na simulação fica o "Voltar ao começo"
	if na_simulacao:
		_botao_voltar = _botao(_inicio, "Voltar ao começo", "reaparece no começo", _voltar, false, "casa")
	_botao_comandos = _botao(_inicio, "Comandos", "controle e teclado", _abrir_comandos, false, "comandos")
	# o Caderno saiu da pausa: tem botão próprio, o touchpad / M (pedido do usuário, 2026-11-20)
	if not na_simulacao:
		_botao_mundo = _botao(_inicio, "Simulação", "treinar os comandos de novo", _trocar_mundo.bind(true), false, "simulacao")
	_botao_ajustes = _botao(_inicio, "Ajustes", "qualidade, câmera, vibração", _abrir_ajustes, false, "ajustes")
	_botao_sair = _botao(_inicio, "Sair do jogo", "guarda o progresso", _sair, false, "sair")
	# página de ajustes: o valor fica à direita, entre setas; o direcional para os lados muda. Apagar o progresso
	# fica separado, no fim e em vermelho
	_pagina_ajustes = VBoxContainer.new()
	_pagina_ajustes.add_theme_constant_override("separation", 10)
	_pagina_ajustes.visible = false
	pilha.add_child(_pagina_ajustes)
	_botao_qualidade = _botao(_pagina_ajustes, "Qualidade do desenho", "", _mudar_ajuste.bind("qualidade", 1), true)
	_botao_sens = _botao(_pagina_ajustes, "Sensibilidade da câmera", "", _mudar_ajuste.bind("sensibilidade", 1))
	_botao_eixo = _botao(_pagina_ajustes, "Olhar para cima e para baixo", "", _mudar_ajuste.bind("inverter_y", 1))
	_botao_vibra = _botao(_pagina_ajustes, "Vibração do controle", "", _mudar_ajuste.bind("vibra", 1))
	for par: Array in [[_botao_qualidade, "qualidade"], [_botao_sens, "sensibilidade"], [_botao_eixo, "inverter_y"], [_botao_vibra, "vibra"]]:
		var bt: Button = par[0]
		var chave: String = par[1]
		bt.gui_input.connect(func(ev: InputEvent) -> void:
			if ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right"):
				_mudar_ajuste(chave, -1 if ev.is_action_pressed("ui_left") else 1, false)
				bt.accept_event())
	_voltar_ajustes = _botao(_pagina_ajustes, "Voltar", "", _fechar_ajustes, false, "voltar")
	var vao := Control.new()
	vao.custom_minimum_size = Vector2(0, 26)
	_pagina_ajustes.add_child(vao)
	_botao_apagar = _botao(_pagina_ajustes, APAGAR, "o jogo recomeça do zero", _apagar, false, "apagar")
	_pintar_perigo(_botao_apagar)
	_escrever_ajustes()
	# página do caderno: só o que já foi feito (nada do que falta aparece). Abre sozinha pelo touchpad / M
	_pagina_caderno = VBoxContainer.new()
	_pagina_caderno.add_theme_constant_override("separation", 12)
	_pagina_caderno.visible = false
	pilha.add_child(_pagina_caderno)
	var lado_a_lado := HBoxContainer.new()
	lado_a_lado.add_theme_constant_override("separation", 28)
	_pagina_caderno.add_child(lado_a_lado)
	_caderno_mapa = MapaCaderno.new()
	lado_a_lado.add_child(_caderno_mapa)
	var direita := VBoxContainer.new()
	direita.add_theme_constant_override("separation", 10)
	direita.custom_minimum_size = Vector2(LARG_CADERNO, 0)
	lado_a_lado.add_child(direita)
	_caderno_contas = _texto("", T_EXPLICA + 2, TINTA)
	_caderno_contas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caderno_contas.custom_minimum_size = Vector2(LARG_CADERNO, 0)
	direita.add_child(_caderno_contas)
	direita.add_child(_texto("MEMÓRIAS LIDAS", T_GRUPO, AGUA))
	_caderno_memorias = GridContainer.new()
	_caderno_memorias.columns = 3  # as 11 memórias em 4 linhas, para a página caber com o mapa grande
	_caderno_memorias.add_theme_constant_override("h_separation", 8)
	_caderno_memorias.add_theme_constant_override("v_separation", 8)
	direita.add_child(_caderno_memorias)
	_caderno_texto = _texto("", T_EXPLICA + 1, APAGADO)
	_caderno_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caderno_texto.custom_minimum_size = Vector2(LARG_CADERNO, 150)
	direita.add_child(_caderno_texto)
	direita.add_child(_texto("O SCANNER JÁ LEU", T_GRUPO, AGUA))
	_caderno_scanner = _texto("", T_EXPLICA, APAGADO)
	_caderno_scanner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caderno_scanner.custom_minimum_size = Vector2(LARG_CADERNO, 0)
	direita.add_child(_caderno_scanner)
	_voltar_caderno = _botao(_pagina_caderno, "Voltar", "", _fechar_caderno, true, "voltar")
	# página de comandos: duas tabelas lado a lado (chão e ar; combate e outros), para caber com letra grande
	_pagina_comandos = VBoxContainer.new()
	_pagina_comandos.add_theme_constant_override("separation", 12)
	_pagina_comandos.visible = false
	pilha.add_child(_pagina_comandos)
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	_pagina_comandos.add_child(abas)
	_aba_controle = _aba(abas, "Controle", func() -> void: _mostrar_aba(1))
	_aba_teclado = _aba(abas, "Teclado e mouse", func() -> void: _mostrar_aba(2))
	var duas := HBoxContainer.new()
	duas.add_theme_constant_override("separation", 48)
	_pagina_comandos.add_child(duas)
	var tabela: GridContainer = null
	for linha: Array in COMANDOS:
		var titulo_grupo: bool = String(linha[1]) == ""
		if tabela == null or String(linha[0]) == "COMBATE":
			tabela = GridContainer.new()
			tabela.columns = 2
			tabela.add_theme_constant_override("h_separation", 28)
			tabela.add_theme_constant_override("v_separation", 2)
			duas.add_child(tabela)
		var acao := _texto(linha[0], T_GRUPO if titulo_grupo else T_TABELA, AGUA if titulo_grupo else TINTA)
		acao.custom_minimum_size = Vector2(290, 0)
		tabela.add_child(acao)
		var tecla := TextoBotoes.new()
		tecla.tamanho = T_TABELA
		tecla.cor = LARANJA
		tecla.forcar = 1
		tabela.add_child(tecla)
		_colunas.append(tecla)
	_voltar_comandos = _botao(_pagina_comandos, "Voltar", "", _fechar_comandos, true, "voltar")
	_mostrar_aba(1)
	# rodapé: a dica e como mexer no menu
	var linha_fina := ColorRect.new()
	linha_fina.color = Color(0.35, 0.95, 0.85, 0.22)
	linha_fina.custom_minimum_size = Vector2(0, 1)
	pilha.add_child(linha_fina)
	_dica = _texto("", T_DICA, APAGADO)
	_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dica.custom_minimum_size = Vector2(640, 0)
	pilha.add_child(_dica)
	_rodape = _texto("X ou Enter: escolher   ·   O ou Esc: voltar", T_RODAPE, Color(0.55, 0.61, 0.6))
	pilha.add_child(_rodape)
	_montar_confirma()
	visible = false
	Input.joy_connection_changed.connect(_controle_mudou)


## A telinha de Sim e Não, por cima da pausa (que fica escurecida atrás). O foco não sai dos dois botões.
func _montar_confirma() -> void:
	_confirma = ColorRect.new()
	_confirma.color = Color(0.01, 0.03, 0.035, 0.62)
	_confirma.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirma.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirma.visible = false
	add_child(_confirma)
	var meio := CenterContainer.new()
	meio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirma.add_child(meio)
	_confirma_caixa = PanelContainer.new()
	meio.add_child(_confirma_caixa)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	_confirma_caixa.add_child(col)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 22)
	col.add_child(linha)
	_confirma_figura = IconeMenu.new("sair", 64.0)
	_confirma_figura.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(_confirma_figura)
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 6)
	linha.add_child(textos)
	_confirma_pergunta = _texto("", T_TITULO - 4, TINTA)
	textos.add_child(_confirma_pergunta)
	_confirma_frase = _texto("", T_EXPLICA + 2, APAGADO)
	_confirma_frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirma_frase.custom_minimum_size = Vector2(450, 0)
	textos.add_child(_confirma_frase)
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 16)
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(botoes)
	_confirma_nao = _botao(botoes, "Não", "", _responder.bind(false), false, "nao")
	_confirma_sim = _botao(botoes, "Sim", "", _responder.bind(true), false, "sim")
	for par: Array in [[_confirma_nao, _confirma_sim], [_confirma_sim, _confirma_nao]]:
		var b: Button = par[0]
		var outro: Button = par[1]
		b.custom_minimum_size = Vector2(262, 62)
		var ate := b.get_path_to(outro)
		b.focus_neighbor_left = ate
		b.focus_neighbor_right = ate
		b.focus_next = ate
		b.focus_previous = ate
		b.focus_neighbor_top = NodePath(".")
		b.focus_neighbor_bottom = NodePath(".")


## O controle desconectou (pilha, Bluetooth, cabo): o jogo para e a pausa abre dizendo isso, em vez de o robô
## seguir voando sozinho. Dá para ligar de novo, usar outro controle ou seguir com teclado e mouse.
func _controle_mudou(_aparelho: int, ligado: bool) -> void:
	if ligado:
		if visible and _titulo.text == "O controle desconectou":
			_titulo.text = "Controle conectado"
			_subtitulo.text = "Pode continuar."
		return
	if not visible:
		if not pode_abrir():
			return
		_abrir()
	avisos_controle += 1
	_titulo.text = "O controle desconectou"
	_titulo.add_theme_color_override("font_color", LARANJA)
	_subtitulo.text = "Ligue de novo, use outro controle ou continue com teclado e mouse."


func _caixa(cor: Color, raio: int, margem: int, borda := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	sb.set_content_margin_all(margem)
	if borda.a > 0.0:
		sb.border_color = borda
		sb.set_border_width_all(2)
	return sb


func _texto(t: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


## Um botão grande: a figura, o nome à esquerda e uma linha curta dizendo o que faz. O escolhido fica aceso.
func _botao(pai: Control, nome: String, explica: String, acao: Callable, _forte := false, icone := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(660, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", T_BOTAO)
	b.set_meta("nome", nome)
	b.set_meta("explica", explica)
	b.text = nome
	if icone != "":
		var fig := IconeMenu.new(icone)
		fig.name = "figura"
		fig.position = Vector2(18, 13)
		b.add_child(fig)
		b.focus_entered.connect(func() -> void:
			fig.cor = VERMELHO if b.get_meta("perigo", false) else LARANJA
			fig.queue_redraw())
		b.focus_exited.connect(func() -> void:
			fig.cor = VERMELHO.darkened(0.15) if b.get_meta("perigo", false) else TINTA
			fig.queue_redraw())
	# a explicação (ou o valor, nos ajustes) fica à direita, na mesma linha
	var ex := _texto(explica, T_EXPLICA, APAGADO)
	ex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ex.offset_right = -18.0
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ex.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ex.name = "explica"
	b.add_child(ex)
	_pintar_normal(b)
	b.pressed.connect(acao)
	b.focus_entered.connect(func() -> void: _ao_focar(b))
	b.mouse_entered.connect(b.grab_focus)
	pai.add_child(b)
	return b


## O botão comum: fundo escuro, letra clara, laranja com o foco.
func _pintar_normal(b: Button) -> void:
	var com_figura := b.get_node_or_null("figura") != null
	b.set_meta("perigo", false)
	b.add_theme_color_override("font_color", TINTA)
	b.add_theme_color_override("font_focus_color", LARANJA)
	b.add_theme_color_override("font_hover_color", TINTA)
	for par: Array in [["normal", Color(0.085, 0.13, 0.14), Color(0, 0, 0, 0)], ["hover", Color(0.1, 0.155, 0.165), Color(0, 0, 0, 0)],
			["pressed", Color(0.16, 0.13, 0.09), Color(0, 0, 0, 0)], ["focus", Color(0.16, 0.13, 0.09, 0.35), LARANJA]]:
		var sb := _caixa(par[1], 4, 18, par[2])
		if com_figura:
			sb.content_margin_left = 68.0
		b.add_theme_stylebox_override(par[0], sb)
	var fig := b.get_node_or_null("figura") as IconeMenu
	if fig:
		fig.cor = LARANJA if b.has_focus() else TINTA
		fig.queue_redraw()
	(b.get_node("explica") as Label).add_theme_color_override("font_color", APAGADO)


## O botão perigoso (apagar o progresso): fundo e letra avermelhados, para não ser confundido com um ajuste.
func _pintar_perigo(b: Button) -> void:
	b.set_meta("perigo", true)
	b.add_theme_color_override("font_color", VERMELHO.darkened(0.1))
	b.add_theme_color_override("font_focus_color", VERMELHO)
	b.add_theme_color_override("font_hover_color", VERMELHO)
	for par: Array in [["normal", Color(0.17, 0.07, 0.07)], ["hover", Color(0.22, 0.09, 0.09)], ["pressed", Color(0.3, 0.1, 0.1)]]:
		var sb := _caixa(par[1], 4, 18)
		sb.content_margin_left = 68.0
		b.add_theme_stylebox_override(par[0], sb)
	var foco := _caixa(Color(0.25, 0.08, 0.08, 0.6), 4, 18, VERMELHO)
	foco.content_margin_left = 68.0
	b.add_theme_stylebox_override("focus", foco)
	var fig := b.get_node_or_null("figura") as IconeMenu
	if fig:
		fig.cor = VERMELHO if b.has_focus() else VERMELHO.darkened(0.15)
		fig.queue_redraw()
	(b.get_node("explica") as Label).add_theme_color_override("font_color", VERMELHO.darkened(0.3))


func _aba(pai: Control, nome: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = nome
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", _caixa(Color(0.12, 0.18, 0.19), 10, 12))
	b.add_theme_stylebox_override("hover", _caixa(Color(0.17, 0.26, 0.27), 10, 12))
	b.add_theme_stylebox_override("pressed", _caixa(Color(0.2, 0.42, 0.4), 10, 12))
	b.add_theme_stylebox_override("focus", _caixa(Color(0, 0, 0, 0), 10, 12, LARANJA))
	b.add_theme_color_override("font_focus_color", LARANJA)
	b.pressed.connect(acao)
	pai.add_child(b)
	return b


## O rodapé explica o botão escolhido; sem explicação, mostra a dica.
func _ao_focar(b: Button) -> void:
	var e := String(b.get_meta("explica", ""))
	if _dica and e != "":
		_dica.text = e.capitalize().substr(0, 1) + e.substr(1) + "."


## Cada ajuste mostra o nome à esquerda e o valor à direita, entre setas: o direcional (ou as setas do teclado)
## para os lados muda, e o X passa para o próximo. A sensibilidade aparece em bolinhas.
func _escrever_ajustes() -> void:
	var q := clampi(int(Guardado.ajuste("qualidade")), 0, 2)
	var sens := clampi(int(Guardado.ajuste("sensibilidade")), 0, 4)
	var valores := [
		[_botao_qualidade, String(Qualidade.NOMES[q]), "mais baixa: menos capim, sombras mais curtas e o jogo mais solto"],
		[_botao_sens, "●".repeat(sens + 1) + "○".repeat(4 - sens), "quanto a câmera gira com o analógico direito e o mouse"],
		[_botao_eixo, "invertido" if bool(Guardado.ajuste("inverter_y")) else "normal", "invertido: empurrar o analógico para a frente olha para baixo"],
		[_botao_vibra, "ligada" if bool(Guardado.ajuste("vibra")) else "desligada", "o controle treme nos golpes, no pouso e nos tiros"],
	]
	for v: Array in valores:
		var b: Button = v[0]
		var ex := b.get_node("explica") as Label
		ex.text = "◀   %s   ▶" % v[1]
		ex.add_theme_font_size_override("font_size", T_BOTAO - 2)
		ex.add_theme_color_override("font_color", LARANJA if b.has_focus() else TINTA)
		b.set_meta("explica", v[2])
		if not b.has_meta("pintado"):
			b.set_meta("pintado", true)
			b.focus_entered.connect(func() -> void: ex.add_theme_color_override("font_color", LARANJA))
			b.focus_exited.connect(func() -> void: ex.add_theme_color_override("font_color", TINTA))
	_botao_apagar.text = APAGAR


## Muda um ajuste um passo para um lado (`passo` -1 ou +1). A qualidade e a sensibilidade param nas pontas com
## as setas e dão a volta com o X; os de ligar e desligar só trocam.
func _mudar_ajuste(chave: String, passo: int, volta := true) -> void:
	match chave:
		"qualidade", "sensibilidade":
			var n := 3 if chave == "qualidade" else 5
			var atual := int(Guardado.ajuste(chave))
			Guardado.por_ajuste(chave, posmod(atual + passo, n) if volta else clampi(atual + passo, 0, n - 1))
		_:
			Guardado.por_ajuste(chave, not bool(Guardado.ajuste(chave)))
	_aplicar()


func _aplicar() -> void:
	_escrever_ajustes()
	var principal := get_parent()
	if principal and principal.has_method("aplicar_ajustes"):
		principal.call("aplicar_ajustes")


func _trocar_qualidade() -> void:
	_mudar_ajuste("qualidade", 1)


func _trocar_sens() -> void:
	_mudar_ajuste("sensibilidade", 1)


func _trocar_eixo() -> void:
	_mudar_ajuste("inverter_y", 1)


func _trocar_vibra() -> void:
	_mudar_ajuste("vibra", 1)


## Apagar o progresso pergunta antes, na telinha de Sim e Não.
func _apagar() -> void:
	_confirmar("apagar")


## A telinha de confirmação: figura, pergunta, uma frase e dois botões. Começa no "Não", e o círculo (ou o Esc)
## também é "Não": um toque sem querer nunca apaga nem fecha nada.
func _confirmar(qual: String) -> void:
	_confirma_acao = qual
	_confirma_volta = get_viewport().gui_get_focus_owner()
	var perigo := qual != "sair"
	var textos: Dictionary = {
		"sair": ["sair", "Sair do jogo?", "O progresso fica guardado."],
		"apagar": ["apagar", "Apagar todo o progresso?", "Peças, lugares e memórias somem, e o jogo recomeça do zero. Não dá para desfazer."],
		"novo": ["novo", "Começar um jogo novo?", "O progresso de agora é apagado. Não dá para desfazer."],
	}
	var t: Array = textos[qual]
	_confirma_figura.tipo = t[0]
	_confirma_figura.cor = VERMELHO if perigo else LARANJA
	_confirma_figura.queue_redraw()
	_confirma_pergunta.text = t[1]
	_confirma_frase.text = t[2]
	_confirma_caixa.add_theme_stylebox_override("panel", _caixa(Color(0.045, 0.075, 0.08, 0.98), 8, 28, VERMELHO if perigo else Color(0.25, 0.37, 0.38)))
	if perigo:
		_pintar_perigo(_confirma_sim)
	else:
		_pintar_normal(_confirma_sim)
	_confirma_nao.disabled = false
	_confirma_sim.disabled = false
	_confirma.visible = true
	_confirma_nao.grab_focus()
	_confirma_caixa.pivot_offset = _confirma_caixa.size * 0.5
	_confirma_caixa.scale = Vector2(0.92, 0.92)
	create_tween().tween_property(_confirma_caixa, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _responder(sim: bool) -> void:
	if not sim:
		_fechar_confirma()
		return
	match _confirma_acao:
		"sair":
			var principal := get_parent()
			if principal and principal.has_method("guardar_progresso"):
				principal.call("guardar_progresso")
			get_tree().quit()
		"apagar", "novo":
			Guardado.recomecar_progresso()
			_confirma_pergunta.text = "Recomeçando..." if _confirma_acao == "apagar" else "Começando..."
			_confirma_frase.text = ""
			_confirma_nao.disabled = true
			_confirma_sim.disabled = true
			# o jogo fecha e abre sozinho, já limpo: as peças, armas e lugares vivem espalhados na memória de
			# muitas partes do jogo, e reabrir é o jeito seguro de zerar tudo de uma vez
			if DisplayServer.get_name() != "headless":
				_reabrir_sem_abertura()


func _fechar_confirma() -> void:
	_confirma.visible = false
	if _confirma_volta and is_instance_valid(_confirma_volta) and _confirma_volta.is_visible_in_tree():
		_confirma_volta.grab_focus()


## Fecha o jogo e abre de novo, já limpo e sem passar pela tela de abertura.
func _reabrir_sem_abertura() -> void:
	var a := PackedStringArray()
	for x in OS.get_cmdline_args():
		if x != "--sem-abertura":
			a.append(x)
	a.append("--sem-abertura")
	OS.set_restart_on_exit(true, a)
	get_tree().quit()


## Tem partida guardada? (algum lugar visitado, peça achada ou a simulação já vista)
static func tem_partida() -> bool:
	if not Guardado.ativo:
		return false
	return bool(Guardado.progresso("simulacao_vista")) or not (Guardado.progresso("lugares") as Array).is_empty() or not (Guardado.progresso("pecas") as Array).is_empty()


## A tela de abertura: a mesma pausa, com o nome do jogo e só o que faz sentido antes de jogar.
func abrir_abertura() -> void:
	_abrir()
	abertura = true
	var tem := tem_partida()
	_titulo.text = "Faísca 2"
	_titulo.add_theme_color_override("font_color", LARANJA)
	_subtitulo.text = "Em Busca do Sossego"
	_primeiro.text = "Continuar" if tem else "Começar"
	(_primeiro.get_node("explica") as Label).text = "de onde você parou" if tem else "acorda o robô"
	_botao_novo.visible = tem
	_botao_novo.text = "Novo jogo"
	for b: Button in [_botao_voltar, _botao_caderno, _botao_mundo]:
		if b:
			b.visible = false
	_dica.visible = false
	_primeiro.grab_focus()


## Novo jogo pergunta antes (Sim e Não): apaga o progresso e o jogo reabre limpo.
func _novo_jogo() -> void:
	_confirmar("novo")


func _abrir_ajustes() -> void:
	_inicio.visible = false
	_pagina_ajustes.visible = true
	_escrever_ajustes()
	_botao_qualidade.grab_focus()


## O caderno é refeito a cada abertura, com o que o jogo sabe agora.
func _abrir_caderno() -> void:
	var principal := get_parent()
	var locais: Locais = principal.get("locais") if principal else null
	var memorias: Memorias = principal.get("memorias") if principal else null
	var mapa: Ilha = principal.get("ilha") if principal else null
	_caderno_mapa.preparar(mapa, locais, armadura.global_position if armadura else Vector3.ZERO)
	var lugares := locais.descobertos() if locais else 0
	var lidas: Array = memorias.lidas if memorias else []
	_caderno_contas.text = "Lugares visitados: %d   ·   Peças: %d   ·   Memórias: %d de %d" % [lugares, Melhorias.instaladas.size() + Melhorias.achadas.size(), lidas.size(), Memorias.ORDEM.size()]
	for velho in _caderno_memorias.get_children():
		velho.queue_free()
	_caderno_texto.text = "Nenhuma memória lida ainda." if lidas.is_empty() else "Escolha uma memória para reler."
	for chave: String in Memorias.ORDEM:
		if not lidas.has(chave):
			continue
		var par: Array = Memorias.TEXTOS[chave]
		var b := Button.new()
		b.text = String(par[0])
		b.custom_minimum_size = Vector2((LARG_CADERNO - 16.0) / 3.0, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", T_EXPLICA + 1)
		b.add_theme_color_override("font_color", TINTA)
		b.add_theme_color_override("font_focus_color", LARANJA)
		b.add_theme_stylebox_override("normal", _caixa(Color(0.085, 0.13, 0.14), 4, 10))
		b.add_theme_stylebox_override("hover", _caixa(Color(0.1, 0.155, 0.165), 4, 10))
		b.add_theme_stylebox_override("focus", _caixa(Color(0.16, 0.13, 0.09, 0.35), 4, 10, LARANJA))
		var texto := String(par[1])
		b.focus_entered.connect(func() -> void: _caderno_texto.text = texto)
		b.mouse_entered.connect(b.grab_focus)
		_caderno_memorias.add_child(b)
	var lidos: Array = Melhorias.escaneados
	_caderno_scanner.text = "Nada ainda." if lidos.is_empty() else ", ".join(PackedStringArray(lidos))
	_inicio.visible = false
	_pagina_caderno.visible = true
	_dica.text = "O caderno guarda só o que você já viu."
	_voltar_caderno.grab_focus()


## O caderno pelo botão próprio (touchpad / M): para o jogo e abre direto nele, com o próprio título; voltar
## (ou o mesmo botão) fecha e solta o jogo.
func abrir_caderno_direto() -> void:
	_abrir()
	_so_caderno = true
	cadernos += 1
	_titulo.text = "Caderno"
	_subtitulo.text = "o mapa e o que você já viu"
	_abrir_caderno()
	_dica.text = "Voltar, o círculo ou o touchpad de novo fecham o caderno."


func _fechar_caderno() -> void:
	_pagina_caderno.visible = false
	_inicio.visible = true
	if _so_caderno:
		_so_caderno = false
		_continuar()
		return
	_botao_comandos.grab_focus()


func _fechar_ajustes() -> void:
	_pagina_ajustes.visible = false
	_inicio.visible = true
	_botao_ajustes.grab_focus()


## Sair pergunta antes (Sim e Não); o progresso é guardado ao sair.
func _sair() -> void:
	_confirmar("sair")


func _mostrar_aba(qual: int) -> void:
	_aba_controle.button_pressed = qual == 1
	_aba_teclado.button_pressed = qual == 2
	for k in _colunas.size():
		_colunas[k].forcar = 1 if qual == 1 else 0
		_colunas[k].texto = COMANDOS[k][qual]


func _abrir_comandos() -> void:
	_inicio.visible = false
	_pagina_comandos.visible = true
	_dica.text = "Dá para trocar entre o controle e o teclado a qualquer momento."
	_voltar_comandos.grab_focus()


func _fechar_comandos() -> void:
	_pagina_comandos.visible = false
	_inicio.visible = true
	_botao_comandos.grab_focus()


## A pausa não abre por cima de outra tela: com uma memória aberta (o jogo já está parado por ela) ou dentro
## da oficina. Antes, fechar a pausa soltava o jogo atrás do texto da memória, e "Voltar à base" deixava a
## tela da oficina aberta.
func pode_abrir() -> bool:
	if get_tree().paused:
		return false
	for no in get_tree().get_nodes_in_group("sem_pausa"):
		if no.has_method("ocupada") and no.ocupada():
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if visible and _confirma.visible:
		if event.is_action_pressed("ui_cancel"):
			_fechar_confirma()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("menu"):
			_confirma.visible = false
			_continuar()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("caderno"):
			get_viewport().set_input_as_handled()
		return
	# o Esc é "menu" e também "voltar": dentro de uma página ele volta uma página, como o círculo
	if visible and event.is_action_pressed("ui_cancel"):
		if _pagina_comandos.visible:
			_fechar_comandos()
		elif _pagina_caderno.visible:
			_fechar_caderno()
		elif _pagina_ajustes.visible:
			_fechar_ajustes()
		else:
			_continuar()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("caderno") and not na_simulacao and not abertura:
		# o caderno tem botão próprio: abre por cima do jogo e o mesmo botão fecha
		if visible and _pagina_caderno.visible:
			_fechar_caderno()
		elif visible and _inicio.visible:
			_abrir_caderno()
		elif not visible and pode_abrir():
			abrir_caderno_direto()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu"):
		if visible:
			_continuar()
		elif pode_abrir():
			_abrir()
		get_viewport().set_input_as_handled()
	elif not visible and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _abrir() -> void:
	aberturas += 1
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pagina_comandos.visible = false
	_pagina_ajustes.visible = false
	_pagina_caderno.visible = false
	_inicio.visible = true
	_confirma.visible = false
	_so_caderno = false
	# desfaz o que a tela de abertura mudou
	abertura = false
	_primeiro.text = "Continuar"
	(_primeiro.get_node("explica") as Label).text = "volta ao jogo"
	_botao_novo.visible = false
	for b: Button in [_botao_voltar, _botao_caderno, _botao_mundo]:
		if b:
			b.visible = true
	_dica.visible = true
	_titulo.text = "Pausa"
	_titulo.add_theme_color_override("font_color", TINTA)
	_subtitulo.text = SUBTITULO
	# desligado (em pane), o robô não volta à base pela pausa: quem o leva é o drone, e a derrota na Fundição
	# custa metade dos materiais
	var em_pane := armadura != null and armadura.em_pane
	if _botao_voltar:
		_botao_voltar.disabled = em_pane
		_botao_voltar.text = "Voltar ao começo (robô desligado: aguarde o drone)" if em_pane else "Voltar ao começo"
		(_botao_voltar.get_node("explica") as Label).visible = not em_pane
	_primeiro.grab_focus()
	_dica.text = "Dica: " + DICAS[(aberturas - 1) % DICAS.size()]
	# o cartão chega com um movimento curto
	_cartao.pivot_offset = _cartao.size * 0.5
	_cartao.scale = Vector2(0.94, 0.94)
	_cartao.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_cartao, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cartao, "modulate:a", 1.0, 0.12)


## Fecha o menu, mas o jogo só volta quando os botões do menu forem soltos: senão a bolinha que fecha a
## pausa também desligava o voo, e o X do "Continuar" também pulava.
func _continuar() -> void:
	if not visible:
		return  # fechada: quem parou o jogo foi outra tela, e não é a pausa que o solta
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_saindo = true


func _process(_delta: float) -> void:
	if not _saindo:
		return
	if visible:
		_saindo = false
		return
	for acao in ["ui_cancel", "ui_accept", "soltar", "pular"]:
		if Input.is_action_pressed(acao):
			return
	_saindo = false
	get_tree().paused = false


func _trocar_mundo(para_sim: bool) -> void:
	if armadura and armadura.em_pane:
		return
	var principal := get_parent()
	if principal and principal.has_method("trocar_mundo"):
		visible = false
		principal.call("trocar_mundo", para_sim)


func _voltar() -> void:
	if armadura and armadura.em_pane:
		return
	_continuar()
	if armadura:
		armadura.recomecar()
