class_name Pausa
extends CanvasLayer
## Pausa (Esc / Options). Um cartão no meio da tela com poucas escolhas grandes: continuar, voltar à base,
## comandos, vibração e sair. Os comandos ficam numa página à parte, em tabela (ação de um lado, botão do
## outro), com uma aba para o controle e outra para o teclado; uma dica diferente aparece a cada vez.
## Refeito em 2026-11-16 a pedido do usuário ("um menu de pause mais amigável"): antes era uma coluna de
## botões com um parágrafo de comandos embaixo.

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
	"Sente (seta para a esquerda): os bichos chegam mais perto.",
]
# [o que é, no controle, no teclado e mouse]. `{@nome}` vira a imagem do botão (ver Botoes).
const COMANDOS := [
	["NO CHÃO", "", ""],
	["Andar · olhar", "{@al} · {@ar}", "{@k_w}{@k_a}{@k_s}{@k_d} · {@m}"],
	["Correr", "{@l3}", "{@k_shift}"],
	["Pular · pulo duplo", "{@x} · {@x} no ar", "{@k_espaco}"],
	["Esquiva", "{@o}", "{@k_c}"],
	["Sentar", "{@esq}", "{@k_ctrl}"],
	["NO AR", "", ""],
	["Decolar", "segurar {@x}", "segurar {@k_espaco}"],
	["Ligar o voo · desligar e cair", "{@l3} no ar · toque em {@l3} ou {@x}", "{@k_shift} no ar"],
	["Acelerar e segurar", "{@al}", "{@k_w} · {@k_s}"],
	["Planar · voltar ao jato (asas)", "segurar {@l3} ou {@x}", "segurar {@k_shift}"],
	["Parar no ar", "{@l2} · {@r3}", "{@k_f}"],
	["Manobra (giro para o lado)", "{@o}", "{@k_c}"],
	["Mergulho com impacto", "{@tri}", "{@k_v}"],
	["COMBATE", "", ""],
	["Mirar · atirar", "{@l2} · {@r2}", "{@m_dir} · {@m_esq}"],
	["Trocar de arma", "toque em {@l1} · segurar: roda", "{@k_r} · {@k_1} a {@k_6}"],
	["Granada", "segurar e soltar {@r1}", "{@k_g}"],
	["Espada de laser", "{@r3} no chão", "{@k_x}"],
	["OUTROS", "", ""],
	["Oficina · ligar a Fundição", "{@quad}", "{@k_e}"],
	["Luz · scanner (melhorias)", "{@cima} · {@dir}", "{@k_l} · {@k_t}"],
	["Marcar um ponto", "{@baixo}", "{@k_q}"],
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
var _apagar_armado := 0.0
var _botao_sair: Button
var _voltar_comandos: Button
var _dica: Label
var _colunas: Array[TextoBotoes] = []  # as células de botão da tabela (trocam com a aba)
var _aba_controle: Button
var _aba_teclado: Button
var _sair_armado := 0.0
var _saindo := false
var _titulo: Label
var _subtitulo: Label
var _botao_voltar: Button
var avisos_controle := 0  # quantas vezes a pausa abriu por o controle ter desconectado (testes)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.06, 0.07, 0.72)
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
	_titulo = _texto("Pausa", 28, TINTA)
	topo.add_child(_titulo)
	_subtitulo = _texto(SUBTITULO, 13, APAGADO)
	topo.add_child(_subtitulo)
	# página inicial
	_inicio = VBoxContainer.new()
	_inicio.add_theme_constant_override("separation", 10)
	pilha.add_child(_inicio)
	_primeiro = _botao(_inicio, "Continuar", "volta ao jogo", _continuar, true)
	if na_simulacao:
		_botao(_inicio, "Acordar", "sai da simulação e vai para a ilha", _trocar_mundo.bind(false))
	_botao_voltar = _botao(_inicio, "Voltar ao começo" if na_simulacao else "Voltar à base", "reaparece no começo" if na_simulacao else "reaparece na base", _voltar)
	_botao_comandos = _botao(_inicio, "Comandos", "controle e teclado", _abrir_comandos)
	if not na_simulacao:
		_botao(_inicio, "Simulação", "treinar os comandos de novo", _trocar_mundo.bind(true))
	_botao_ajustes = _botao(_inicio, "Ajustes", "qualidade, câmera, vibração", _abrir_ajustes)
	_botao_sair = _botao(_inicio, "Sair do jogo", "guarda o progresso", _sair)
	# página de ajustes
	_pagina_ajustes = VBoxContainer.new()
	_pagina_ajustes.add_theme_constant_override("separation", 10)
	_pagina_ajustes.visible = false
	pilha.add_child(_pagina_ajustes)
	_botao_qualidade = _botao(_pagina_ajustes, "", "", _trocar_qualidade, true)
	_botao_sens = _botao(_pagina_ajustes, "", "", _trocar_sens)
	_botao_eixo = _botao(_pagina_ajustes, "", "", _trocar_eixo)
	_botao_vibra = _botao(_pagina_ajustes, "", "", _trocar_vibra)
	_botao_apagar = _botao(_pagina_ajustes, "Apagar o progresso e recomeçar", "o jogo recomeça do zero", _apagar)
	_voltar_ajustes = _botao(_pagina_ajustes, "Voltar", "", _fechar_ajustes)
	_escrever_ajustes()
	# página de comandos
	_pagina_comandos = VBoxContainer.new()
	_pagina_comandos.add_theme_constant_override("separation", 10)
	_pagina_comandos.visible = false
	pilha.add_child(_pagina_comandos)
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	_pagina_comandos.add_child(abas)
	_aba_controle = _aba(abas, "Controle", func() -> void: _mostrar_aba(1))
	_aba_teclado = _aba(abas, "Teclado e mouse", func() -> void: _mostrar_aba(2))
	var tabela := GridContainer.new()
	tabela.columns = 2
	tabela.add_theme_constant_override("h_separation", 36)
	tabela.add_theme_constant_override("v_separation", -6)
	_pagina_comandos.add_child(tabela)
	for linha: Array in COMANDOS:
		var titulo_grupo: bool = String(linha[1]) == ""
		var acao := _texto(linha[0], 11 if titulo_grupo else 14, AGUA if titulo_grupo else TINTA)
		acao.custom_minimum_size = Vector2(250, 0)
		tabela.add_child(acao)
		var tecla := TextoBotoes.new()
		tecla.tamanho = 14
		tecla.cor = LARANJA
		tecla.forcar = 1
		tabela.add_child(tecla)
		_colunas.append(tecla)
	_voltar_comandos = _botao(_pagina_comandos, "Voltar", "", _fechar_comandos, true)
	_mostrar_aba(1)
	# rodapé: a dica e como mexer no menu
	var linha_fina := ColorRect.new()
	linha_fina.color = Color(0.35, 0.95, 0.85, 0.22)
	linha_fina.custom_minimum_size = Vector2(0, 1)
	pilha.add_child(linha_fina)
	_dica = _texto("", 15, APAGADO)
	_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dica.custom_minimum_size = Vector2(520, 0)
	pilha.add_child(_dica)
	pilha.add_child(_texto("X ou Enter: escolher   ·   O ou Esc: voltar", 13, Color(0.5, 0.56, 0.55)))
	visible = false
	Input.joy_connection_changed.connect(_controle_mudou)


## O controle desconectou (pilha, Bluetooth, cabo): o jogo para e a pausa abre dizendo isso, em vez de o robô
## seguir voando sozinho. Dá para ligar de novo, usar outro controle ou seguir com teclado e mouse.
func _controle_mudou(_aparelho: int, ligado: bool) -> void:
	if ligado:
		if visible and _titulo.text != "Pausa":
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


## Um botão grande: o nome à esquerda e uma linha curta dizendo o que faz. O escolhido fica aceso.
func _botao(pai: Control, nome: String, explica: String, acao: Callable, _forte := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(540, 50)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", TINTA)
	b.add_theme_color_override("font_focus_color", LARANJA)
	b.add_theme_color_override("font_hover_color", TINTA)
	b.add_theme_stylebox_override("normal", _caixa(Color(0.085, 0.13, 0.14), 4, 18))
	b.add_theme_stylebox_override("hover", _caixa(Color(0.1, 0.155, 0.165), 4, 18))
	b.add_theme_stylebox_override("pressed", _caixa(Color(0.16, 0.13, 0.09), 4, 18))
	b.add_theme_stylebox_override("focus", _caixa(Color(0.16, 0.13, 0.09, 0.35), 4, 18, LARANJA))
	b.set_meta("nome", nome)
	b.set_meta("explica", explica)
	b.text = nome
	# a explicação fica à direita, na mesma linha
	var ex := _texto(explica, 13, APAGADO)
	ex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ex.offset_right = -18.0
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ex.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ex.name = "explica"
	b.add_child(ex)
	b.pressed.connect(acao)
	b.focus_entered.connect(func() -> void: _ao_focar(b))
	b.mouse_entered.connect(b.grab_focus)
	pai.add_child(b)
	return b


func _aba(pai: Control, nome: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = nome
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 17)
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
	_sair_armado = 0.0 if b != _botao_sair else _sair_armado
	if b != _botao_sair and _botao_sair:
		_botao_sair.text = "Sair do jogo"


func _escrever_ajustes() -> void:
	_botao_qualidade.text = "Qualidade do desenho: " + Qualidade.NOMES[clampi(int(Guardado.ajuste("qualidade")), 0, 2)]
	_botao_qualidade.set_meta("explica", "mais baixa: menos capim, sombras mais curtas e o jogo mais solto")
	_botao_sens.text = "Sensibilidade da câmera: %d de 5" % (int(Guardado.ajuste("sensibilidade")) + 1)
	_botao_sens.set_meta("explica", "quanto a câmera gira com o analógico direito e o mouse")
	_botao_eixo.text = "Olhar para cima e para baixo: " + ("invertido" if bool(Guardado.ajuste("inverter_y")) else "normal")
	_botao_eixo.set_meta("explica", "invertido: empurrar o analógico para a frente olha para baixo")
	_botao_vibra.text = "Vibração do controle: " + ("ligada" if bool(Guardado.ajuste("vibra")) else "desligada")
	_botao_vibra.set_meta("explica", "o controle treme nos golpes, no pouso e nos tiros")
	_botao_apagar.text = "Apagar o progresso e recomeçar"


func _aplicar() -> void:
	_escrever_ajustes()
	var principal := get_parent()
	if principal and principal.has_method("aplicar_ajustes"):
		principal.call("aplicar_ajustes")


func _trocar_qualidade() -> void:
	Guardado.por_ajuste("qualidade", (int(Guardado.ajuste("qualidade")) + 1) % 3)
	_aplicar()


func _trocar_sens() -> void:
	Guardado.por_ajuste("sensibilidade", (int(Guardado.ajuste("sensibilidade")) + 1) % 5)
	_aplicar()


func _trocar_eixo() -> void:
	Guardado.por_ajuste("inverter_y", not bool(Guardado.ajuste("inverter_y")))
	_aplicar()


func _trocar_vibra() -> void:
	Guardado.por_ajuste("vibra", not bool(Guardado.ajuste("vibra")))
	_aplicar()


## Apagar o progresso pede um segundo toque.
func _apagar() -> void:
	if _apagar_armado > 0.0:
		_apagar_armado = 0.0
		Guardado.recomecar_progresso()
		_botao_apagar.text = "Recomeçando..."
		# o jogo fecha e abre sozinho, já limpo: as peças, armas e lugares vivem espalhados na memória de muitas
		# partes do jogo, e reabrir é o jeito seguro de zerar tudo de uma vez
		if DisplayServer.get_name() != "headless":
			OS.set_restart_on_exit(true, OS.get_cmdline_args())
			get_tree().quit()
		return
	_apagar_armado = 4.0
	_botao_apagar.text = "Apagar tudo e recomeçar? Aperte de novo"


func _abrir_ajustes() -> void:
	_inicio.visible = false
	_pagina_ajustes.visible = true
	_escrever_ajustes()
	_botao_qualidade.grab_focus()


func _fechar_ajustes() -> void:
	_pagina_ajustes.visible = false
	_inicio.visible = true
	_botao_ajustes.grab_focus()


## Sair pede um segundo toque: o primeiro só arma.
func _sair() -> void:
	if _sair_armado > 0.0:
		var principal := get_parent()
		if principal and principal.has_method("guardar_progresso"):
			principal.call("guardar_progresso")
		get_tree().quit()
		return
	_sair_armado = 4.0
	_botao_sair.text = "Sair mesmo? Aperte de novo"


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
	# o Esc é "menu" e também "voltar": dentro de uma página ele volta uma página, como o círculo
	if visible and event.is_action_pressed("ui_cancel"):
		if _pagina_comandos.visible:
			_fechar_comandos()
		elif _pagina_ajustes.visible:
			_fechar_ajustes()
		else:
			_continuar()
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
	_inicio.visible = true
	_sair_armado = 0.0
	_botao_sair.text = "Sair do jogo"
	_titulo.text = "Pausa"
	_titulo.add_theme_color_override("font_color", TINTA)
	_subtitulo.text = SUBTITULO
	# desligado (em pane), o robô não volta à base pela pausa: quem o leva é o drone, e a derrota na Fundição
	# custa metade dos materiais
	var em_pane := armadura != null and armadura.em_pane
	_botao_voltar.disabled = em_pane
	_botao_voltar.text = "Voltar à base (robô desligado: aguarde o drone)" if em_pane else ("Voltar ao começo" if na_simulacao else "Voltar à base")
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


func _process(delta: float) -> void:
	if _apagar_armado > 0.0:
		_apagar_armado -= delta
		if _apagar_armado <= 0.0 and _botao_apagar:
			_botao_apagar.text = "Apagar o progresso e recomeçar"
	if _sair_armado > 0.0:
		_sair_armado -= delta
		if _sair_armado <= 0.0 and _botao_sair:
			_botao_sair.text = "Sair do jogo"
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
