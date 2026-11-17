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
	"Mirando, o tiro trava na máquina mais perto da mira.",
	"As máquinas não são destruídas: desligam e religam depois.",
	"Atrás de uma árvore ou de uma pedra, o tiro delas não chega.",
	"Se o robô desligar, o drone colega vem buscar e leva para a base.",
	"Na água funda o robô nada com os jatos, e isso esfria o motor.",
	"Aperte para abaixar e segure para sentar: os bichos chegam mais perto.",
]
const COMANDOS := [
	["Andar", "analógico esquerdo", "W A S D"],
	["Olhar", "analógico direito", "mouse"],
	["Correr", "L3", "Shift"],
	["Abaixar · sentar", "R3 · segurar R3", "Ctrl · segurar"],
	["Pular · pulo duplo", "X · X no ar", "Espaço"],
	["Decolar", "segurar X", "segurar Espaço"],
	["Ligar o voo · desligar e cair", "L3 no ar · toque em L3 ou X", "Shift no ar"],
	["Acelerar e segurar no voo", "analógico esquerdo", "W · S"],
	["Parar no ar e mirar", "L2", "botão direito · F"],
	["Atirar (um tiro por aperto)", "R2", "botão esquerdo"],
	["Esquiva · frear no voo", "O", "C"],
	["Mergulho com impacto", "triângulo no ar", "V"],
	["Nadar: subir · descer", "X · O", "Espaço · C"],
	["Marcar um ponto", "R1", "Q"],
	["Planar · voltar ao jato (asas)", "segurar L3 ou X no voo", "segurar Shift ou Espaço"],
	["Luz do peito (melhoria)", "Seta para cima", "L"],
	["Scanner (melhoria)", "Seta para a direita", "T"],
	["Oficina da base · ligar a Fundição", "quadrado", "E"],
	["Medidor", "Create", "F3"],
	["Pausa", "Options", "Esc"],
]

var armadura: Armadura
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
var _colunas: Array[Label] = []  # as células de botão da tabela (trocam com a aba)
var _aba_controle: Button
var _aba_teclado: Button
var _sair_armado := 0.0
var _saindo := false


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
	_cartao.add_theme_stylebox_override("panel", _caixa(Color(0.07, 0.11, 0.12, 0.96), 22, 34, Color(0.35, 0.95, 0.85, 0.35)))
	centro.add_child(_cartao)
	var pilha := VBoxContainer.new()
	pilha.add_theme_constant_override("separation", 18)
	_cartao.add_child(pilha)
	# cabeçalho
	var topo := VBoxContainer.new()
	topo.add_theme_constant_override("separation", 2)
	pilha.add_child(topo)
	topo.add_child(_texto("Pausa", 40, TINTA))
	topo.add_child(_texto("Faísca 2 · Em Busca do Sossego", 16, AGUA))
	# página inicial
	_inicio = VBoxContainer.new()
	_inicio.add_theme_constant_override("separation", 10)
	pilha.add_child(_inicio)
	_primeiro = _botao(_inicio, "Continuar", "voltar ao jogo", _continuar, true)
	_botao(_inicio, "Voltar à base", "o robô reaparece no estrado", _voltar)
	_botao_comandos = _botao(_inicio, "Comandos", "o que cada botão faz", _abrir_comandos)
	_botao_ajustes = _botao(_inicio, "Ajustes", "qualidade do desenho, câmera e vibração", _abrir_ajustes)
	_botao_sair = _botao(_inicio, "Sair do jogo", "fecha o jogo (o progresso fica guardado)", _sair)
	# página de ajustes
	_pagina_ajustes = VBoxContainer.new()
	_pagina_ajustes.add_theme_constant_override("separation", 10)
	_pagina_ajustes.visible = false
	pilha.add_child(_pagina_ajustes)
	_botao_qualidade = _botao(_pagina_ajustes, "", "", _trocar_qualidade, true)
	_botao_sens = _botao(_pagina_ajustes, "", "", _trocar_sens)
	_botao_eixo = _botao(_pagina_ajustes, "", "", _trocar_eixo)
	_botao_vibra = _botao(_pagina_ajustes, "", "", _trocar_vibra)
	_botao_apagar = _botao(_pagina_ajustes, "Apagar o progresso", "esquece os lugares visitados e as peças achadas", _apagar)
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
	tabela.add_theme_constant_override("v_separation", 5)
	_pagina_comandos.add_child(tabela)
	for linha: Array in COMANDOS:
		var acao := _texto(linha[0], 17, TINTA)
		acao.custom_minimum_size = Vector2(250, 0)
		tabela.add_child(acao)
		var tecla := _texto("", 17, LARANJA)
		tecla.custom_minimum_size = Vector2(230, 0)
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
func _botao(pai: Control, nome: String, explica: String, acao: Callable, forte := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(520, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", TINTA)
	b.add_theme_color_override("font_focus_color", Color(0.05, 0.09, 0.09))
	b.add_theme_color_override("font_hover_color", TINTA)
	b.add_theme_stylebox_override("normal", _caixa(Color(0.12, 0.18, 0.19) if not forte else Color(0.15, 0.26, 0.25), 12, 16))
	b.add_theme_stylebox_override("hover", _caixa(Color(0.17, 0.26, 0.27), 12, 16))
	b.add_theme_stylebox_override("pressed", _caixa(LARANJA.darkened(0.2), 12, 16))
	b.add_theme_stylebox_override("focus", _caixa(LARANJA, 12, 16))
	b.set_meta("nome", nome)
	b.set_meta("explica", explica)
	b.text = nome
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
	b.add_theme_stylebox_override("focus", _caixa(LARANJA, 10, 12))
	b.add_theme_color_override("font_focus_color", Color(0.05, 0.09, 0.09))
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
	_botao_apagar.text = "Apagar o progresso"


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
		_botao_apagar.text = "Progresso apagado (vale na próxima vez que abrir o jogo)"
		return
	_apagar_armado = 4.0
	_botao_apagar.text = "Apagar mesmo? Aperte de novo"


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
		_colunas[k].text = COMANDOS[k][qual]


func _abrir_comandos() -> void:
	_inicio.visible = false
	_pagina_comandos.visible = true
	_dica.text = "Dá para trocar entre o controle e o teclado a qualquer momento."
	_voltar_comandos.grab_focus()


func _fechar_comandos() -> void:
	_pagina_comandos.visible = false
	_inicio.visible = true
	_botao_comandos.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if visible:
			_continuar()
		else:
			_abrir()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		if _pagina_comandos.visible:
			_fechar_comandos()
		elif _pagina_ajustes.visible:
			_fechar_ajustes()
		else:
			_continuar()
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
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_saindo = true


func _process(delta: float) -> void:
	if _apagar_armado > 0.0:
		_apagar_armado -= delta
		if _apagar_armado <= 0.0 and _botao_apagar:
			_botao_apagar.text = "Apagar o progresso"
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


func _voltar() -> void:
	_continuar()
	if armadura:
		armadura.recomecar()
