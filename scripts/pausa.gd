class_name Pausa
extends CanvasLayer
## Pausa (Esc / Options), tela de abertura, ajustes, comandos, caderno e a telinha de Sim e Não.
## Refeita em 2026-11-16 ("um menu de pause mais amigável") e revista em 2026-11-20 (letra maior, uma figura em
## cada botão, ajustes com o valor à vista, o caderno com o mapa grande).
## Desde 2026-11-21 (doc §136) tudo mora no tablet dobrável do robô, o mesmo da oficina: casca branca com friso
## azul, duas telas de papel, figuras grandes e letra escura. Na pausa, as escolhas ficam na tela da esquerda e
## o quadro "Agora" (a hora, o lugar, o robô e uma dica do drone) na da direita; na abertura, a esquerda é um
## fundo de tela com o farol no pôr do sol. A confirmação usa o tablet fechado, de uma tela só.

const DICAS := [
	"Mergulhar, a chuva e voar rente à água esfriam o motor.",
	"Segure o pulo para decolar reto e sair voando.",
	"A mira assistida se fabrica na oficina: com ela, o tiro trava na máquina mais perto da mira.",
	"As máquinas não são destruídas: desligam e religam depois.",
	"Atrás de uma árvore ou de uma pedra, o tiro delas não chega.",
	"Se o robô desligar, o drone colega vem buscar e o deixa num lugar seguro ali perto.",
	"Na água funda o robô nada com os jatos, e isso esfria o motor.",
	"Parado, a seta para a esquerda tira a câmera de trás do robô para você olhar a paisagem.",
	"O botão Create do controle (ou o M) abre o caderno: o mapa, as memórias e o que o scanner leu.",
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
	["Caderno: mapa e memórias", "{@create}", "{@k_m}"],
	["Nadar: subir · descer", "{@x} · {@o}", "{@k_espaco} · {@k_c}"],
	["Pausa · medidor", "{@options} · segurar {@l1}{@r1}", "{@k_esc} · {@k_f3}"],
]
const SUBTITULO := "Fagulha · Em Busca do Sossego"

# a cor de cada escolha (o círculo da figura): quem não lê acha pela figura e pela cor
const COR := {"continuar": Tablet.LARANJA_V, "comandos": Tablet.AZUL, "simulacao": Color(0.3, 0.65, 0.65), "ajustes": Color(0.45, 0.55, 0.6),
	"sair": Tablet.CINZA, "historia": Tablet.LILAS, "novo": Color(0.85, 0.6, 0.2), "acordar": Color(0.92, 0.58, 0.12), "casa": Tablet.VERDE,
	"voltar": Tablet.CINZA}
const VERDE_AGUA := Color(0.3, 0.65, 0.65)
const PETROLEO := Color(0.2, 0.5, 0.5)
const SEPARADOR_FAISCA := 30.0  # px na aba Memórias entre as da ilha e as lembranças do Faísca

var armadura: Armadura
var na_simulacao := false  # a pausa do tutorial: "Acordar" no lugar de "Voltar à base"
var aberturas := 0  # quantas vezes abriu (testes)
var abertura := false  # a pausa fazendo de tela de abertura (ao abrir o jogo): Continuar ou Começar, Novo jogo, Ajustes, Sair
var avisos_controle := 0  # quantas vezes a pausa abriu por o controle ter desconectado (testes)
var cadernos := 0  # quantas vezes o caderno abriu pelo botão próprio (testes)
var albuns := 0  # quantas vezes o álbum abriu (testes)
var perguntas_acordar := 0  # testes

var _fundo: ColorRect
var _cartao: TabletCasca
var _titulo: Label  # o nome da tela (os testes leem; a barra de cima e o cabeçalho mostram)
var _subtitulo: Label
var _dica: Label  # a dica do drone desta abertura
var _saindo := false
var _so_caderno := false  # o caderno abriu sozinho (Create / M): voltar fecha e solta o jogo

# a página inicial
var _inicio: Control
var _primeiro: BotaoTablet
var _botao_historia: BotaoTablet  # na tela de abertura: rever o prólogo (Historia)
var _botao_novo: BotaoTablet
var _botao_mundo: BotaoTablet
var _botao_voltar: BotaoTablet
var _botao_caderno: BotaoTablet  # o caderno saiu da lista (tem botão próprio); fica nulo
var _botao_comandos: BotaoTablet
var _botao_ajustes: BotaoTablet
var _botao_sair: BotaoTablet

# ajustes
var _pagina_ajustes: Control
var _botao_qualidade: BotaoTablet
var _botao_sens: BotaoTablet
var _botao_eixo: BotaoTablet
var _botao_vibra: BotaoTablet
var _voltar_ajustes: BotaoTablet
var _ajuste_sel := "qualidade"

# comandos
var _pagina_comandos: Control
var _aba_controle: BotaoTablet
var _aba_teclado: BotaoTablet
var _voltar_comandos: BotaoTablet
var _aba_comandos := 1  # 1 controle, 2 teclado e mouse

# caderno e álbum
var _pagina_caderno: Control
var _pilulas_caderno: Control  # Mapa, Memórias e Álbum (servem às duas páginas)
var _pilulas: Array[BotaoTablet] = []
var _caderno_contas: Label  # a conta em texto (os testes leem)
var _caderno_memorias: Control  # um botão por memória lida
var _voltar_caderno: BotaoTablet
var _botao_album: BotaoTablet
var _pagina_album: PaginaAlbum
var _voltar_album: BotaoTablet
var _aba_caderno := 0  # 0 mapa, 1 memórias, 2 álbum
var _mem_sel := ""

# a aba Mapa (2026-11-21, pedido do usuário): o mapa nas duas telas, uma metade de cada lado da dobra
const ZOOMS := [0.0, 2600.0, 1300.0]  # metros na altura do mapa: 0 é o mundo todo; os outros, em volta do robô
var _mapa_esq: MapaCaderno
var _mapa_dir: MapaCaderno
var _zoom_mapa := 0

# a telinha de Sim e Não que confirma sair, começar um jogo novo e apagar o progresso
var _confirma: ColorRect
var _confirma_caixa: TabletCasca
var _confirma_nao: BotaoTablet
var _confirma_sim: BotaoTablet
var _confirma_acao := ""  # "sair", "novo" ou "acordar"
var _confirma_volta: Control  # o botão que abriu a telinha, para o foco voltar a ele no "Não"
var _confirma_so := false  # a telinha abriu sozinha, sem a pausa atrás (o "Hora de acordar?" do fim do treino básico)
var _confirma_texto: Array = ["sair", "", ""]  # [figura, pergunta, frase]


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fundo = ColorRect.new()
	_fundo.color = Color(0.01, 0.03, 0.05, 0.5)
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fundo)
	_cartao = TabletCasca.new()
	_cartao.barra = false  # cada tela põe a barra de cima onde faz sentido
	_cartao.anchor_left = 0.5
	_cartao.anchor_right = 0.5
	_cartao.anchor_top = 0.5
	_cartao.anchor_bottom = 0.5
	_cartao.offset_left = -Tablet.TAM.x * 0.5
	_cartao.offset_right = Tablet.TAM.x * 0.5
	_cartao.offset_top = -Tablet.TAM.y * 0.5
	_cartao.offset_bottom = Tablet.TAM.y * 0.5
	_cartao.pintor = _pintar
	_fundo.add_child(_cartao)
	# os textos que os testes e a barra de cima leem (não aparecem como Label)
	_titulo = _rotulo("Pausa")
	_subtitulo = _rotulo(SUBTITULO)
	_dica = _rotulo("")
	_montar_inicio()
	_montar_ajustes()
	_montar_comandos()
	_montar_caderno()
	_montar_confirma()
	visible = false
	Input.joy_connection_changed.connect(_controle_mudou)


func _rotulo(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.visible = false
	_cartao.add_child(l)
	return l


func _pagina() -> Control:
	var p := Control.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = Tablet.TAM
	p.visible = false
	_cartao.add_child(p)
	return p


## Uma escolha grande: a figura num círculo de cor, o nome e uma linha curta dizendo o que faz. A explicação
## fica num Label "explica" escondido (quem lê é o desenho), como nos botões de antes.
func _botao(pai: Control, nome: String, explica: String, acao: Callable, icone := "") -> BotaoTablet:
	var b := BotaoTablet.new()
	b.estilo = "opcao"
	b.text = nome
	b.icone = icone
	b.cor = COR.get(icone, Tablet.LARANJA_V)
	b.set_meta("nome", nome)
	b.set_meta("explica", explica)
	var ex := Label.new()
	ex.name = "explica"
	ex.text = explica
	ex.visible = false
	b.add_child(ex)
	b.pressed.connect(acao)
	b.mouse_entered.connect(b.grab_focus)
	pai.add_child(b)
	return b


## Uma pílula pequena (abas e o Voltar do canto).
func _pilula(pai: Control, nome: String, icone: String, cor: Color, r: Rect2, acao: Callable, foca := true) -> BotaoTablet:
	var b := BotaoTablet.new()
	b.estilo = "pilula"
	b.text = nome
	b.icone = icone
	b.cor = cor
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_ALL if foca else Control.FOCUS_NONE
	b.pressed.connect(acao)
	if foca:
		b.mouse_entered.connect(b.grab_focus)
	pai.add_child(b)
	return b


## O Voltar do canto de baixo da tela da direita (o círculo e o Esc também voltam).
func _voltar_canto(pai: Control, acao: Callable) -> BotaoTablet:
	var R := Tablet.DIR
	var b := _pilula(pai, "Voltar", "voltar", Tablet.CINZA, Rect2(R.end.x - 132, R.end.y - 56, 116, 38), acao)
	b.estilo = "livre"
	b.pintor = func(c: Control, r: Rect2, foco: bool, sobre: bool) -> void:
		Tablet.caixa(c, r, Color(Tablet.TINTA, 0.12 if sobre else 0.07), int(r.size.y * 0.5))
		Tablet.pilula(c, r, "voltar", "Voltar", Tablet.CINZA, false, foco)
	return b


# ------------------------------------------------------------------ montagem

func _montar_inicio() -> void:
	_inicio = _pagina()
	_inicio.visible = true
	_primeiro = _botao(_inicio, "Continuar", "volta ao jogo", _continuar, "continuar")
	if not na_simulacao:
		_botao_historia = _botao(_inicio, "A história", "o começo da ilha, de novo", _ver_historia, "historia")
		_botao_historia.visible = false
	# o Novo jogo é o único jeito de apagar o progresso (antes havia também o "Apagar o progresso" nos ajustes,
	# que fazia o mesmo; pedido do usuário, 2026-11-21): na abertura fica na lista; na pausa da ilha, no fim,
	# separado e em vermelho
	_botao_novo = _botao(_inicio, "Novo jogo", "apaga tudo e começa do zero", _novo_jogo, "novo")
	_botao_novo.visible = false
	if na_simulacao:
		_botao_mundo = _botao(_inicio, "Acordar", "sai da simulação e vai para a ilha", _trocar_mundo.bind(false), "acordar")
		# "Voltar à base" saiu da pausa do jogo (pedido do usuário, 2026-11-20); na simulação fica o "Voltar ao começo"
		_botao_voltar = _botao(_inicio, "Voltar ao começo", "reaparece no começo", _voltar, "casa")
	_botao_comandos = _botao(_inicio, "Comandos", "controle e teclado", _abrir_comandos, "comandos")
	if not na_simulacao:
		_botao_mundo = _botao(_inicio, "Simulação", "treinar os comandos de novo", _trocar_mundo.bind(true), "simulacao")
	_botao_ajustes = _botao(_inicio, "Ajustes", "qualidade, câmera, vibração", _abrir_ajustes, "ajustes")
	_botao_sair = _botao(_inicio, "Sair do jogo", "guarda o progresso", _sair, "sair")


## Arruma as escolhas da página inicial: na pausa, na tela da esquerda; na abertura, na da direita (a esquerda
## é o fundo de tela), com o Continuar grande e o que a partida já tem.
func _arrumar_inicio() -> void:
	var L := Tablet.ESQ
	var R := Tablet.DIR
	var y := (R.position.y + 64.0) if abertura else (L.position.y + 148.0)
	var x := (R.position.x + 16.0) if abertura else (L.position.x + 16.0)
	var w := (R.size.x if abertura else L.size.x) - 32.0
	var ordem: Array = [_primeiro, _botao_historia, _botao_novo, _botao_mundo, _botao_voltar, _botao_comandos, _botao_ajustes, _botao_sair]
	# na pausa, o Novo jogo vai para o fim, longe do Continuar, em vermelho
	_botao_novo.perigo = not abertura
	_botao_novo.cor = COR["novo"] if abertura else Tablet.RUBI
	if not abertura:
		ordem.erase(_botao_novo)
		ordem.append(_botao_novo)
	for b: BotaoTablet in ordem:
		if b == null or not b.visible:
			continue
		var alto := 86.0
		if b == _botao_novo and not abertura:
			y += 10.0
			alto = 70.0
		if abertura:
			# o Continuar grande mostra o que a partida já tem; sem partida (Começar), fica do tamanho dos outros
			alto = (150.0 if tem_partida() else 96.0) if b == _primeiro else 78.0
		b.estilo = "livre" if abertura and b == _primeiro else "opcao"
		b.pintor = _pintar_continuar_grande
		b.position = Vector2(x, y)
		b.size = Vector2(w, alto)
		y += alto + (16.0 if abertura and b == _primeiro else (10.0 if abertura else 12.0))


func _montar_ajustes() -> void:
	_pagina_ajustes = _pagina()
	var L := Tablet.ESQ
	var x0 := L.position.x + 16
	var w := L.size.x - 32
	var y := L.position.y + 112.0
	_botao_qualidade = _linha_ajuste("qualidade", "Qualidade do desenho", "imagem", Tablet.AZUL, Rect2(x0, y, w, 118))
	y += 128
	_botao_sens = _linha_ajuste("sensibilidade", "Sensibilidade da câmera", "cam_sens", VERDE_AGUA, Rect2(x0, y, w, 118))
	y += 128
	_botao_eixo = _linha_ajuste("inverter_y", "Olhar para cima e para baixo", "setas_v", Tablet.LILAS, Rect2(x0, y, w, 118))
	y += 128
	_botao_vibra = _linha_ajuste("vibra", "Vibração do controle", "vibra", Color(0.85, 0.6, 0.2), Rect2(x0, y, w, 74))
	y += 84
	_voltar_ajustes = _botao(_pagina_ajustes, "Voltar", "", _fechar_ajustes, "voltar")
	_voltar_ajustes.position = Vector2(x0, y)
	_voltar_ajustes.size = Vector2(w, 64)
	_voltar_ajustes.focus_entered.connect(func() -> void: _ajuste_sel = "voltar")
	_escrever_ajustes()


## Um ajuste: a figura, o nome e o valor (em segmentos, bolinhas ou chave). O direcional para os lados muda;
## o X passa adiante (dá a volta).
func _linha_ajuste(chave: String, titulo: String, icone: String, cor: Color, r: Rect2) -> BotaoTablet:
	var b := BotaoTablet.new()
	b.estilo = "livre"
	b.text = titulo
	b.icone = icone
	b.cor = cor
	b.position = r.position
	b.size = r.size
	b.pintor = _pintar_ajuste.bind(chave)
	b.pressed.connect(_mudar_ajuste.bind(chave, 1))
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(func() -> void: _ajuste_sel = chave)
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right"):
			_mudar_ajuste(chave, -1 if ev.is_action_pressed("ui_left") else 1, false)
			b.accept_event())
	var ex := Label.new()
	ex.name = "explica"
	ex.visible = false
	b.add_child(ex)
	_pagina_ajustes.add_child(b)
	return b


func _montar_comandos() -> void:
	_pagina_comandos = _pagina()
	var L := Tablet.ESQ
	_aba_controle = _pilula(_pagina_comandos, "Controle", "comandos", Tablet.AZUL, Rect2(L.position.x + 18, L.position.y + 58, 186, 38), func() -> void: _mostrar_aba(1), false)
	_aba_teclado = _pilula(_pagina_comandos, "Teclado e mouse", "teclado", Color(0.45, 0.55, 0.6), Rect2(L.position.x + 204, L.position.y + 58, 186, 38), func() -> void: _mostrar_aba(2), false)
	_voltar_comandos = _voltar_canto(_pagina_comandos, _fechar_comandos)
	_mostrar_aba(1)


func _montar_caderno() -> void:
	var L := Tablet.ESQ
	_pagina_caderno = _pagina()
	_caderno_memorias = Control.new()
	_caderno_memorias.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caderno_memorias.size = Tablet.TAM
	_pagina_caderno.add_child(_caderno_memorias)
	_caderno_contas = Label.new()
	_caderno_contas.visible = false
	_pagina_caderno.add_child(_caderno_contas)
	_voltar_caderno = _voltar_canto(_pagina_caderno, _fechar_caderno)
	# a aba Mapa: o mapa nas duas telas. Cada metade mostra a sua parte do mundo, emendadas: o que fica
	# embaixo da dobra não some
	for lado in 2:
		var mp := MapaCaderno.new()
		mp.position = (L.position if lado == 0 else Tablet.DIR.position) + Vector2(12, 108)
		mp.size = Vector2(394, 610)
		mp.pulsar = true
		mp.rosa = lado == 1
		mp.clip_contents = true
		_pagina_caderno.add_child(mp)
		if lado == 0:
			_mapa_esq = mp
		else:
			_mapa_dir = mp
	# o álbum: uma página à parte (do tamanho do tablet), com o próprio Voltar
	_pagina_album = PaginaAlbum.new()
	_pagina_album.visible = false
	_cartao.add_child(_pagina_album)
	_voltar_album = _voltar_canto(_cartao, _fechar_album)
	_voltar_album.visible = false
	# as pílulas das abas do caderno, por cima das duas páginas (o mouse troca; L1 / R1 também)
	_pilulas_caderno = Control.new()
	_pilulas_caderno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilulas_caderno.size = Tablet.TAM
	_pilulas_caderno.visible = false
	_cartao.add_child(_pilulas_caderno)
	var abas := [["Mapa", "mapa", VERDE_AGUA], ["Memórias", "cristal", Tablet.AMBAR], ["Álbum", "album", Tablet.LILAS]]
	for i in abas.size():
		var p := _pilula(_pilulas_caderno, abas[i][0], abas[i][1], abas[i][2], Rect2(L.position.x + 18 + i * 127, L.position.y + 58, 127, 38), _ir_aba_caderno.bind(i), false)
		_pilulas.append(p)
	_botao_album = _pilulas[2]


## A telinha de Sim e Não, por cima da pausa (que fica escurecida atrás). O foco não sai dos dois botões.
func _montar_confirma() -> void:
	_confirma = ColorRect.new()
	_confirma.color = Color(0.0, 0.02, 0.03, 0.55)
	_confirma.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirma.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirma.visible = false
	add_child(_confirma)
	_confirma_caixa = TabletCasca.new()
	_confirma_caixa.aberto = false
	_confirma_caixa.barra = false
	_confirma_caixa.pintor = _pintar_confirma
	_confirma.add_child(_confirma_caixa)
	_confirma_nao = _botao_resposta(false)
	_confirma_sim = _botao_resposta(true)
	for par: Array in [[_confirma_nao, _confirma_sim], [_confirma_sim, _confirma_nao]]:
		var b: Button = par[0]
		var outro: Button = par[1]
		var ate := b.get_path_to(outro)
		b.focus_neighbor_left = ate
		b.focus_neighbor_right = ate
		b.focus_next = ate
		b.focus_previous = ate
		b.focus_neighbor_top = NodePath(".")
		b.focus_neighbor_bottom = NodePath(".")


func _botao_resposta(sim: bool) -> BotaoTablet:
	var b := BotaoTablet.new()
	b.estilo = "livre"
	b.text = "Sim" if sim else "Não"
	b.icone = "sim" if sim else "nao"
	b.size = Vector2(200, 70)
	b.pintor = _pintar_resposta
	b.pressed.connect(_responder.bind(sim))
	b.mouse_entered.connect(b.grab_focus)
	_confirma_caixa.add_child(b)
	return b


# ------------------------------------------------------------------ o desenho de cada tela

func _pintar(c: Control, telas: Array) -> void:
	var L: Rect2 = telas[0]
	var R: Rect2 = telas[1]
	if _inicio.visible:
		if abertura:
			_p_abertura(c, L, R)
		else:
			_p_pausa(c, L, R)
	elif _pagina_ajustes.visible:
		_p_ajustes(c, L, R)
	elif _pagina_comandos.visible:
		_p_comandos(c, L, R)
	elif _pagina_caderno.visible or _pagina_album.visible:
		_p_caderno(c, L, R)


func _cabecalho(c: Control, t: Rect2, titulo: String, sub := "", cor := Tablet.TINTA) -> void:
	Tablet.texto(c, Vector2(t.position.x + 24, t.position.y + 90), titulo, 32, cor, true)
	if sub != "":
		Tablet.paragrafo(c, Vector2(t.position.x + 24, t.position.y + 114), sub, t.size.x - 48, 14, Color(Tablet.TINTA, 0.55), 2)


func _p_pausa(c: Control, L: Rect2, R: Rect2) -> void:
	var alerta := _titulo.text == "O controle desconectou"
	Tablet.status(c, L, R, _titulo.text, Tablet.LARANJA_V if not alerta else Tablet.RUBI)
	_cabecalho(c, L, _titulo.text, _subtitulo.text, Tablet.RUBI if alerta else Tablet.TINTA)
	Tablet.rodape(c, L, [["x", "escolher"], ["o", "voltar"]])
	# a direita: como está a ilha e o robô agora
	Tablet.texto(c, Vector2(R.position.x + 24, R.position.y + 90), "Agora", 26, Tablet.TINTA, true)
	var card := Rect2(R.position.x + 16, R.position.y + 108, R.size.x - 32, 92)
	Tablet.caixa(c, card, Color(0.98, 0.86, 0.62, 0.55), 18)
	var h := Tablet.hora
	var noite := h < 5.5 or h >= 18.5
	if noite:
		c.draw_circle(card.position + Vector2(48, 46), 14, Color(0.45, 0.5, 0.75))
		c.draw_circle(card.position + Vector2(54, 41), 12, Color(0.98, 0.86, 0.62))
	else:
		Tablet.sol(c, card.position + Vector2(48, 46), 14, Color(0.92, 0.58, 0.12))
	var periodo := "noite" if noite else ("manhã" if h < 12.0 else "tarde")
	Tablet.texto(c, card.position + Vector2(86, 42), "%02d:%02d · %s" % [int(h), int(fmod(h, 1.0) * 60.0), periodo], 21, Tablet.TINTA, true)
	Tablet.pino(c, card.position + Vector2(94, 66), 6, PETROLEO)
	Tablet.texto(c, card.position + Vector2(108, 72), _lugar_agora() + " · " + _tempo_agora(), 15, Color(Tablet.TINTA, 0.65))
	# o robô: nível, experiência e materiais
	var rob := Rect2(R.position.x + 16, R.position.y + 212, R.size.x - 32, 150)
	Tablet.caixa(c, rob, Color(Tablet.TINTA, 0.06), 18)
	var nc := rob.position + Vector2(52, 52)
	var bx := Arsenal.barra()
	Tablet.anel(c, nc, 30, float(bx.x) / float(bx.y), 6.0)
	Tablet.texto(c, Vector2(nc.x - 30, nc.y + 9), str(Arsenal.nivel()), 26, Tablet.TINTA, true, HORIZONTAL_ALIGNMENT_CENTER, 60)
	Tablet.texto(c, rob.position + Vector2(100, 44), "Nível %d" % Arsenal.nivel(), 20, Tablet.TINTA, true)
	Tablet.texto(c, rob.position + Vector2(100, 68), "faltam %d de experiência" % (bx.y - bx.x), 15, Color(Tablet.TINTA, 0.6))
	var mx := rob.position.x + 30.0
	for par: Array in [["sucata", Arsenal.sucata], ["nucleos", Arsenal.nucleos], ["chips", Arsenal.chips]]:
		Tablet.material(c, par[0], Vector2(mx, rob.position.y + 116), 11.0, Tablet.TINTA, 2.0)
		Tablet.texto(c, Vector2(mx + 20, rob.position.y + 124), str(par[1]), 20, Tablet.TINTA, true)
		mx += 118
	# o que já achou, em quatro contas
	var n := _contas()
	var cw := (R.size.x - 32 - 24) / 4.0
	var cy := R.position.y + 376.0
	var ctas := [
		[func(p: Vector2) -> void: Tablet.pino(c, p + Vector2(0, 4), 8, PETROLEO), "%d/%d" % [n["lugares"], n["lugares_total"]], "lugares"],
		[func(p: Vector2) -> void: Icones.desenhar(c, "peca", p, 0.75, Tablet.TINTA, 2.0), "%d/%d" % [n["pecas"], Melhorias.NOMES.size()], "peças"],
		[func(p: Vector2) -> void: Tablet.cristal(c, p, 11, Tablet.AMBAR), "%d/%d" % [n["memorias"], Memorias.ORDEM.size()], "memórias"],
		[func(p: Vector2) -> void: Icones.desenhar(c, "aro", p, 0.75, Tablet.TINTA, 2.0), "%d/%d" % [n["rotas"], Rotas.ROTAS.size()], "rotas"],
	]
	for i in 4:
		Tablet.conta(c, Rect2(R.position.x + 16 + i * (cw + 8), cy, cw, 104), ctas[i][0], ctas[i][1], ctas[i][2])
	# a dica do drone colega num balão
	if _dica.text != "":
		var by := R.position.y + 504.0
		Tablet.drone(c, Vector2(R.position.x + 50, by + 50), 22)
		var balao := Rect2(R.position.x + 88, by, R.size.x - 104, 112)
		Tablet.caixa(c, balao, Color(1, 1, 1), 18, Color(Tablet.TINTA, 0.12), 2)
		c.draw_colored_polygon(PackedVector2Array([balao.position + Vector2(2, 40), balao.position + Vector2(-14, 52), balao.position + Vector2(2, 62)]), Color(1, 1, 1))
		Tablet.texto(c, balao.position + Vector2(18, 28), "Dica", 14, Tablet.AZUL.darkened(0.2), true)
		Tablet.paragrafo(c, balao.position + Vector2(18, 52), _dica.text, balao.size.x - 34, 17, Tablet.TINTA, 3)


## O que a partida já tem (lugares, peças, memórias, rotas).
func _contas() -> Dictionary:
	var principal := get_parent()
	var locais: Locais = principal.get("locais") if principal else null
	var memorias: Memorias = principal.get("memorias") if principal else null
	var pecas := 0
	for nm: String in Melhorias.NOMES:
		if Melhorias.instaladas.has(nm) or Melhorias.achadas.has(nm):
			pecas += 1
	var rotas := 0
	for r: Dictionary in Rotas.ROTAS:
		if int(Rotas.feitas.get(r["id"], 0)) >= 1:
			rotas += 1
	return {"lugares": locais.descobertos() if locais else 0, "lugares_total": locais.total() if locais else 0, "pecas": pecas,
		"memorias": (memorias.lidas.size() if memorias else 0), "rotas": rotas}


func _lugar_agora() -> String:
	if na_simulacao:
		return "Simulação"
	var principal := get_parent()
	var locais: Locais = principal.get("locais") if principal else null
	if locais and locais.atual != "":
		return locais.atual
	# o lugar visto mais perto do robô
	if locais and armadura:
		var melhor := ""
		var d0 := 350.0
		for it: Dictionary in locais.lista:
			if bool(it.get("visto", false)):
				var d := armadura.global_position.distance_to(it["pos"])
				if d < d0:
					d0 = d
					melhor = _perto_de(String(it["nome"]))
		if melhor != "":
			return melhor
	return "a ilha"


## A frase de onde o robô está, em duas partes (a miúda e o nome em negrito): "você está no" + "Navio Encalhado",
## "você está na" + "Clareira", "você está" + "perto das Fontes Quentes".
static func _onde(lugar: String) -> Array:
	if lugar.begins_with("perto "):
		return ["você está", lugar]
	for par: Array in [["Os ", "nos"], ["As ", "nas"], ["O ", "no"], ["A ", "na"], ["a ", "na"], ["o ", "no"]]:
		if lugar.begins_with(par[0]):
			return ["você está " + String(par[1]), lugar.substr(String(par[0]).length())]
	# sem artigo no nome: o gênero pela primeira palavra
	var p1 := lugar.get_slice(" ", 0)
	var em := "no"
	if p1.ends_with("as"):
		em = "nas"
	elif p1.ends_with("os"):
		em = "nos"
	elif p1.ends_with("a") or p1.ends_with("ção") or p1 in ["Foz", "Ponte"]:
		em = "na"
	return ["você está " + em, lugar]


## "perto de" com o artigo do nome junto: "perto do Navio Encalhado", "perto das Fontes Quentes".
static func _perto_de(nome: String) -> String:
	for par: Array in [["O ", "do "], ["A ", "da "], ["Os ", "dos "], ["As ", "das "]]:
		if nome.begins_with(par[0]):
			return "perto " + par[1] + nome.substr(String(par[0]).length())
	return "perto de " + nome


func _tempo_agora() -> String:
	var principal := get_parent()
	var ciclo: CicloDia = principal.get("ciclo") if principal else null
	if ciclo and (ciclo.chovendo or ciclo.chuva > 0.3):
		return "chuva"
	return "céu limpo"


func _p_abertura(c: Control, L: Rect2, R: Rect2) -> void:
	# a tela da esquerda é um fundo de tela: a ilha no fim da tarde, com o farol aceso
	var cores := [Color(0.24, 0.32, 0.58), Color(0.55, 0.45, 0.66), Color(0.93, 0.6, 0.52), Color(1.0, 0.8, 0.55)]
	for k in 60:
		var t := k / 59.0
		var cor: Color
		if t < 0.45:
			cor = cores[0].lerp(cores[1], t / 0.45)
		elif t < 0.7:
			cor = cores[1].lerp(cores[2], (t - 0.45) / 0.25)
		else:
			cor = cores[2].lerp(cores[3], (t - 0.7) / 0.3)
		c.draw_rect(Rect2(L.position.x, L.position.y + t * 560, L.size.x, 10), cor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 30:
		c.draw_circle(Vector2(rng.randf_range(L.position.x + 10, L.end.x - 10), rng.randf_range(L.position.y + 10, L.position.y + 200)), rng.randf_range(0.6, 1.5), Color(1, 1, 1, rng.randf_range(0.3, 0.8)))
	var sol := Vector2(L.position.x + 270, L.position.y + 520)
	Tablet.brilho(c, sol, 46, Color(1.0, 0.85, 0.5), 2.0)
	c.draw_circle(sol, 46, Color(1.0, 0.9, 0.62))
	var mar_y := L.position.y + 560.0
	var longe := PackedVector2Array([Vector2(L.position.x, mar_y)])
	for k in 21:
		longe.append(Vector2(L.position.x + k * L.size.x / 20.0, mar_y - 40 - sin(k * 0.7) * 18 - sin(k * 1.9) * 8))
	longe.append(Vector2(L.end.x, mar_y))
	c.draw_colored_polygon(longe, Color(0.52, 0.46, 0.62))
	c.draw_colored_polygon(PackedVector2Array([Vector2(L.position.x, mar_y + 2), Vector2(L.position.x, mar_y - 70), Vector2(L.position.x + 60, mar_y - 96),
		Vector2(L.position.x + 120, mar_y - 120), Vector2(L.position.x + 170, mar_y - 90), Vector2(L.position.x + 210, mar_y - 40), Vector2(L.position.x + 240, mar_y + 2)]), Color(0.27, 0.3, 0.42))
	var fx := L.position.x + 118.0
	var fy := mar_y - 118.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(fx - 8, fy), Vector2(fx - 5, fy - 52), Vector2(fx + 5, fy - 52), Vector2(fx + 8, fy)]), Color(0.22, 0.24, 0.34))
	c.draw_rect(Rect2(fx - 7, fy - 62, 14, 10), Color(0.22, 0.24, 0.34))
	var pisca := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.003)
	Tablet.brilho(c, Vector2(fx, fy - 57), 5, Color(1.0, 0.85, 0.4), 2.5 * pisca)
	c.draw_circle(Vector2(fx, fy - 57), 3.5, Color(1.0, 0.92, 0.6))
	for k in 26:
		var t := k / 25.0
		c.draw_rect(Rect2(L.position.x, mar_y + t * 213, L.size.x, 9), Color(0.42, 0.5, 0.72).lerp(Color(0.2, 0.26, 0.45), t))
	for k in 14:
		var w := 70.0 - k * 4.0
		c.draw_line(Vector2(sol.x - w * 0.5 + rng.randf_range(-8, 8), mar_y + 10 + k * 13), Vector2(sol.x + w * 0.5 + rng.randf_range(-8, 8), mar_y + 10 + k * 13), Color(1.0, 0.85, 0.6, 0.6 - k * 0.035), 3.0)
	# o robô voando, com as duas fitas laranja (balança devagar)
	var robo := Vector2(L.position.x + 318, L.position.y + 262 + sin(Time.get_ticks_msec() * 0.0015) * 4.0)
	Tablet.fita(c, Vector2(L.position.x + 30, L.position.y + 300), robo + Vector2(-7, 15), 22, Color(1.0, 0.6, 0.25), 0.3)
	Tablet.fita(c, Vector2(L.position.x + 40, L.position.y + 318), robo + Vector2(7, 21), 22, Color(1.0, 0.6, 0.25), 0.8)
	c.draw_set_transform(robo, 0.0, Vector2.ONE * 1.5)
	Tablet.caixa(c, Rect2(Vector2(-9, -18), Vector2(18, 16)), Color(0.95, 0.96, 0.98), 5)
	c.draw_rect(Rect2(Vector2(-6, -14), Vector2(12, 7)), Color(0.12, 0.16, 0.22))
	Tablet.caixa(c, Rect2(Vector2(-8, -1), Vector2(16, 14)), Color(0.95, 0.96, 0.98), 4)
	c.draw_rect(Rect2(Vector2(-8, 3), Vector2(16, 3)), Tablet.FRISO)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Tablet.cantos(c, L, 18, Tablet.CASCA)
	Tablet.caixa(c, L.grow(3), Color(0, 0, 0, 0), 20, Tablet.MOLDURA, 3)
	# o nome
	Tablet.texto(c, Vector2(L.position.x + 2, L.position.y + 126), "Fagulha", 66, Color(0, 0, 0, 0.25), true, HORIZONTAL_ALIGNMENT_CENTER, L.size.x)
	Tablet.texto(c, Vector2(L.position.x, L.position.y + 122), "Fagulha", 66, Color(1.0, 0.97, 0.9), true, HORIZONTAL_ALIGNMENT_CENTER, L.size.x)
	Tablet.texto(c, Vector2(L.position.x, L.position.y + 160), "Em Busca do Sossego", 21, Color(1.0, 0.9, 0.78), false, HORIZONTAL_ALIGNMENT_CENTER, L.size.x)
	Tablet.status(c, R, R, "Fagulha")
	Tablet.rodape(c, R, [["x", "escolher"]])


## O Continuar grande da abertura: a figura, o nome, o que faz e o que a partida já tem, em figuras.
func _pintar_continuar_grande(b: Control, r: Rect2, foco: bool, sobre: bool) -> void:
	Tablet.caixa(b, r, Color(1.0, 0.72, 0.3, 0.3 if foco else (0.2 if sobre else 0.14)), 20, Tablet.LARANJA if foco else Color(0, 0, 0, 0), 3 if foco else 0)
	var ic := Vector2(46, 48)
	b.draw_circle(ic, 28, Tablet.LARANJA_V)
	Tablet.icone(b, "continuar", ic, 32, Color.WHITE, Tablet.LARANJA_V)
	Tablet.texto(b, Vector2(90, 46), (b as Button).text, 24, Tablet.TINTA, true)
	Tablet.texto(b, Vector2(90, 70), (b as BotaoTablet).explicacao(), 15, Color(Tablet.TINTA, 0.6))
	if foco:
		Tablet.botao(b, "x", Vector2(r.size.x - 30, 48), 26)
	if not tem_partida():
		return
	var n := _contas()
	var sy := 112.0
	var bx := Arsenal.barra()
	Tablet.anel(b, Vector2(32, sy), 12, float(bx.x) / float(bx.y))
	Tablet.texto(b, Vector2(50, sy + 6), "nível %d" % Arsenal.nivel(), 15, Tablet.TINTA, true)
	Tablet.cristal(b, Vector2(154, sy), 9, Tablet.AMBAR)
	Tablet.texto(b, Vector2(170, sy + 6), "%d de %d" % [n["memorias"], Memorias.ORDEM.size()], 15, Tablet.TINTA, true)
	Icones.desenhar(b, "peca", Vector2(268, sy), 0.55, Tablet.TINTA, 2.0)
	Tablet.texto(b, Vector2(284, sy + 6), "%d de %d" % [n["pecas"], Melhorias.NOMES.size()], 15, Tablet.TINTA, true)


# ---- ajustes

func _pintar_ajuste(b: Control, r: Rect2, foco: bool, sobre: bool, chave: String) -> void:
	var bt := b as BotaoTablet
	Tablet.caixa(b, r, Color(1.0, 0.72, 0.3, 0.3) if foco else Color(Tablet.TINTA, 0.05 + (0.03 if sobre else 0.0)), 18, Tablet.LARANJA if foco else Color(0, 0, 0, 0), 3 if foco else 0)
	var ic := Vector2(36, 34)
	var circ := bt.cor if foco else bt.cor.lerp(Tablet.TELA, 0.8)
	b.draw_circle(ic, 20, circ)
	Tablet.icone(b, bt.icone, ic, 22, Color.WHITE if foco else bt.cor.darkened(0.25), circ)
	Tablet.texto(b, Vector2(66, 41), bt.text, 19, Tablet.TINTA, true)
	match chave:
		"qualidade":
			_segmentos(b, Rect2(18, 64, r.size.x - 36, 40), Qualidade.NOMES, clampi(int(Guardado.ajuste("qualidade")), 0, 2))
		"sensibilidade":
			var sens := clampi(int(Guardado.ajuste("sensibilidade")), 0, 4)
			b.draw_colored_polygon(PackedVector2Array([Vector2(34, 84), Vector2(46, 76), Vector2(46, 92)]), Color(Tablet.TINTA, 0.5))
			for k in 5:
				b.draw_circle(Vector2(84 + k * 58, 84), 13, Tablet.LARANJA_V if k <= sens else Color(Tablet.TINTA, 0.14))
			b.draw_colored_polygon(PackedVector2Array([Vector2(r.size.x - 34, 84), Vector2(r.size.x - 46, 76), Vector2(r.size.x - 46, 92)]), Color(Tablet.TINTA, 0.5))
		"inverter_y":
			_segmentos(b, Rect2(18, 64, r.size.x - 36, 40), ["normal", "invertido"], 1 if bool(Guardado.ajuste("inverter_y")) else 0)
		"vibra":
			var ligada := bool(Guardado.ajuste("vibra"))
			var p := Vector2(r.size.x - 82, 20)
			Tablet.caixa(b, Rect2(p, Vector2(64, 34)), Color(0.3, 0.62, 0.38) if ligada else Color(Tablet.TINTA, 0.2), 17)
			b.draw_circle(p + Vector2(47 if ligada else 17, 17), 13, Color.WHITE)


func _segmentos(c: CanvasItem, r: Rect2, nomes: Array, sel: int) -> void:
	Tablet.caixa(c, r, Color(Tablet.TINTA, 0.08), int(r.size.y * 0.5))
	var w := r.size.x / nomes.size()
	for i in nomes.size():
		var s := Rect2(r.position.x + i * w + 3, r.position.y + 3, w - 6, r.size.y - 6)
		if i == sel:
			Tablet.caixa(c, s, Tablet.LARANJA_V, int(s.size.y * 0.5))
		Tablet.texto(c, Vector2(s.position.x, s.position.y + s.size.y * 0.5 + 6), String(nomes[i]), 15, Color.WHITE if i == sel else Color(Tablet.TINTA, 0.65), i == sel, HORIZONTAL_ALIGNMENT_CENTER, s.size.x)


func _p_ajustes(c: Control, L: Rect2, R: Rect2) -> void:
	Tablet.status(c, L, R, "Ajustes", COR["ajustes"])
	_cabecalho(c, L, "Ajustes")
	var nomes := {"qualidade": "Qualidade do desenho", "sensibilidade": "Sensibilidade da câmera", "inverter_y": "Olhar para cima e para baixo",
		"vibra": "Vibração do controle", "voltar": "Ajustes"}
	var sel := _ajuste_sel
	Tablet.texto(c, Vector2(R.position.x + 24, R.position.y + 90), nomes.get(sel, "Ajustes"), 26, Tablet.TINTA, true)
	var quadro := Rect2(R.position.x + 16, R.position.y + 112, R.size.x - 32, 170)
	var texto := ""
	match sel:
		"qualidade", "voltar":
			var q := clampi(int(Guardado.ajuste("qualidade")), 0, 2)
			var pw := (R.size.x - 32 - 16) / 3.0
			for i in 3:
				var pr := Rect2(R.position.x + 16 + i * (pw + 8), R.position.y + 112, pw, 170)
				_paisagem(c, pr.grow(-4), i)
				Tablet.caixa(c, pr, Color(0, 0, 0, 0), 14, Tablet.LARANJA if i == q else Color(Tablet.TINTA, 0.15), 4 if i == q else 2)
				Tablet.texto(c, Vector2(pr.position.x, pr.end.y + 26), String(Qualidade.NOMES[i]), 16, Tablet.TINTA if i == q else Color(Tablet.TINTA, 0.55), i == q, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
			texto = "Mais baixa: menos capim, sombras mais curtas e o jogo mais solto. Mais alta: o vale mais cheio e mais bonito."
		"sensibilidade":
			Tablet.caixa(c, quadro, Color(Tablet.TINTA, 0.06), 16)
			var sens := clampi(int(Guardado.ajuste("sensibilidade")), 0, 4)
			var cen := quadro.get_center()
			c.draw_arc(cen, 62, 0, TAU, 48, Color(Tablet.TINTA, 0.15), 6.0, true)
			c.draw_arc(cen, 62, -PI * 0.5, -PI * 0.5 + TAU * (sens + 1) / 5.0, 48, Tablet.LARANJA_V, 6.0, true)
			Tablet.icone(c, "cam_sens", cen, 64, VERDE_AGUA, Tablet.TELA)
			texto = "Quanto a câmera gira com o analógico direito e com o mouse. Mais bolinhas: gira mais depressa."
		"inverter_y":
			var inv := bool(Guardado.ajuste("inverter_y"))
			for i in 2:
				var pr := Rect2(quadro.position.x + i * (quadro.size.x * 0.5 + 4), quadro.position.y, quadro.size.x * 0.5 - 4, quadro.size.y)
				var e_sel := (i == 1) == inv
				Tablet.caixa(c, pr, Color(Tablet.TINTA, 0.06), 14, Tablet.LARANJA if e_sel else Color(0, 0, 0, 0), 4 if e_sel else 0)
				var s := pr.position + Vector2(pr.size.x * 0.3, pr.size.y * 0.5)
				c.draw_circle(s, 22, Color(Tablet.TINTA, 0.15))
				c.draw_circle(s + Vector2(0, -10), 12, Tablet.TINTA)
				c.draw_colored_polygon(PackedVector2Array([s + Vector2(0, -44), s + Vector2(-8, -32), s + Vector2(8, -32)]), Tablet.LARANJA_V)
				var olho := pr.position + Vector2(pr.size.x * 0.72, pr.size.y * 0.5)
				c.draw_arc(olho, 14, PI * 0.15, PI * 0.85, 12, Tablet.TINTA, 2.5, true)
				c.draw_arc(olho, 14, -PI * 0.85, -PI * 0.15, 12, Tablet.TINTA, 2.5, true)
				c.draw_circle(olho, 5, Tablet.TINTA)
				var d := -1.0 if i == 0 else 1.0
				c.draw_colored_polygon(PackedVector2Array([olho + Vector2(0, d * 40), olho + Vector2(-8, d * 28), olho + Vector2(8, d * 28)]), Tablet.LARANJA_V)
				Tablet.texto(c, Vector2(pr.position.x, pr.end.y + 26), "normal" if i == 0 else "invertido", 16, Tablet.TINTA if e_sel else Color(Tablet.TINTA, 0.55), e_sel, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
			texto = "Invertido: empurrar o analógico para a frente olha para baixo, como num avião."
		"vibra":
			Tablet.caixa(c, quadro, Color(Tablet.TINTA, 0.06), 16)
			var cen := quadro.get_center()
			Tablet.icone(c, "comandos", cen, 96, Tablet.TINTA, Tablet.TELA)
			if bool(Guardado.ajuste("vibra")):
				for k in 3:
					c.draw_arc(cen, 62 + k * 12, -0.5, 0.5, 10, Color(0.85, 0.6, 0.2, 0.8 - k * 0.2), 3.0, true)
					c.draw_arc(cen, 62 + k * 12, PI - 0.5, PI + 0.5, 10, Color(0.85, 0.6, 0.2, 0.8 - k * 0.2), 3.0, true)
			texto = "O controle treme nos golpes, no pouso e nos tiros."
	Tablet.paragrafo(c, Vector2(R.position.x + 24, R.position.y + 352), texto, R.size.x - 48, 18, Tablet.TINTA, 4)
	if sel in ["qualidade", "sensibilidade", "inverter_y", "vibra"]:
		var dica := Rect2(R.position.x + 16, R.position.y + 470, R.size.x - 32, 70)
		Tablet.caixa(c, dica, Color(Tablet.TINTA, 0.06), 16)
		Tablet.botao(c, "esq", dica.position + Vector2(34, 35), 28)
		Tablet.botao(c, "dir", dica.position + Vector2(70, 35), 28)
		Tablet.texto(c, dica.position + Vector2(98, 42), "mudam o valor", 17, Tablet.TINTA, true)
	Tablet.rodape(c, R, [["x", "mudar" if sel in ["qualidade", "sensibilidade", "inverter_y", "vibra"] else "escolher"], ["o", "voltar"]])


## Uma paisagenzinha para comparar a qualidade: mais árvores, capim e sombra a cada degrau.
func _paisagem(c: CanvasItem, r: Rect2, q: int) -> void:
	for k in 12:
		var t := k / 11.0
		c.draw_rect(Rect2(r.position.x, r.position.y + t * r.size.y * 0.55, r.size.x, r.size.y * 0.06), Color(0.62, 0.8, 0.95).lerp(Color(0.9, 0.95, 0.98), t))
	var chao := r.position.y + r.size.y * 0.58
	c.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, chao), Vector2(r.position.x + r.size.x * 0.4, chao - 26), Vector2(r.end.x, chao - 8), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]), Color(0.55, 0.72, 0.42))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var arvores: int = [2, 4, 6][q]
	for k in arvores:
		var ax := r.position.x + 14 + rng.randf() * (r.size.x - 28)
		var ay := chao + 4 + rng.randf() * (r.size.y * 0.3)
		if q >= 1:
			c.draw_circle(Vector2(ax + 7, ay + 3), 9, Color(0.2, 0.32, 0.2, 0.35 if q == 2 else 0.2))
		c.draw_rect(Rect2(ax - 1.5, ay - 6, 3, 8), Color(0.45, 0.32, 0.22))
		c.draw_circle(Vector2(ax, ay - 12), 9, Color(0.28, 0.52, 0.3))
	var capim: int = [6, 24, 60][q]
	for k in capim:
		var gx := r.position.x + 4 + rng.randf() * (r.size.x - 8)
		var gy := chao + 10 + rng.randf() * (r.end.y - chao - 14)
		c.draw_line(Vector2(gx, gy), Vector2(gx + rng.randf_range(-2, 2), gy - 6), Color(0.35, 0.55, 0.25), 1.5)
	Tablet.cantos(c, r, 10, Tablet.TELA)


# ---- comandos

func _p_comandos(c: Control, L: Rect2, R: Rect2) -> void:
	Tablet.status(c, L, R, "Comandos", Tablet.AZUL)
	Tablet.caixa(c, Rect2(L.position.x + 14, L.position.y + 54, L.size.x - 28, 46), Color(Tablet.TINTA, 0.07), 23)
	var corte := 0
	for i in COMANDOS.size():
		if String(COMANDOS[i][0]) == "COMBATE":
			corte = i
	_tabela(c, L.position.x + 14, L.position.y + 108, L.size.x - 28, COMANDOS.slice(0, corte))
	var fim := _tabela(c, R.position.x + 14, R.position.y + 56, R.size.x - 28, COMANDOS.slice(corte))
	var dica := Rect2(R.position.x + 14, fim + 18, R.size.x - 28, 76)
	if dica.end.y < R.end.y - 64:
		Tablet.caixa(c, dica, Color(Tablet.TINTA, 0.06), 16)
		Tablet.icone(c, "teclado", dica.position + Vector2(36, 38), 30, Tablet.TINTA, Tablet.TELA)
		Tablet.paragrafo(c, dica.position + Vector2(70, 32), "Dá para trocar entre o controle e o teclado a qualquer momento.", dica.size.x - 84, 15, Color(Tablet.TINTA, 0.75), 2)
	Tablet.rodape(c, R, [["l1", "{@r1} aba"], ["o", "voltar"]])


func _grupo(c: CanvasItem, x: float, y: float, w: float, nome: String, cor: Color) -> void:
	Tablet.caixa(c, Rect2(x, y, w, 32), cor.lerp(Tablet.TELA, 0.75), 16)
	c.draw_circle(Vector2(x + 18, y + 16), 6, cor)
	Tablet.texto(c, Vector2(x + 32, y + 22), nome, 14, cor.darkened(0.35), true)


func _tabela(c: CanvasItem, x: float, y: float, w: float, linhas: Array) -> float:
	var cores := {"NO CHÃO": Tablet.VERDE, "NO AR": Tablet.AZUL, "COMBATE": Tablet.LARANJA_V, "OUTROS": Tablet.LILAS}
	var col := _aba_comandos
	var forcar := 1 if col == 1 else 0
	var par := 0
	for ln: Array in linhas:
		if String(ln[1]) == "":
			y += 6
			_grupo(c, x, y, w, ln[0], cores.get(ln[0], Tablet.AZUL))
			y += 40
			par = 0
			continue
		var acao := String(ln[0])
		var aw := Tablet.largura(acao, 15)
		var bw := Tablet.com_botoes(c, Vector2.ZERO, ln[col], 14, Tablet.LARANJA, -1.0, true, forcar)
		var dois := aw + bw + 20 > w - 16
		var alt := 62.0 if dois else 38.0
		if par % 2 == 1:
			Tablet.caixa(c, Rect2(x, y, w, alt), Color(Tablet.TINTA, 0.045), 10)
		Tablet.texto(c, Vector2(x + 12, y + 24), acao, 15, Tablet.TINTA)
		Tablet.com_botoes(c, Vector2(0, y + (50.0 if dois else 24.0)), ln[col], 14, Color(0.75, 0.38, 0.08), x + w - 10, false, forcar)
		y += alt
		par += 1
	return y


# ---- caderno

func _p_caderno(c: Control, L: Rect2, R: Rect2) -> void:
	Tablet.status(c, L, R, _titulo.text, VERDE_AGUA)
	Tablet.caixa(c, Rect2(L.position.x + 14, L.position.y + 54, L.size.x - 28, 46), Color(Tablet.TINTA, 0.07), 23)
	if _pagina_album.visible:
		Tablet.rodape(c, R, [["l1", "{@r1} aba"], ["o", "voltar"]])
		return
	if _aba_caderno == 0:
		_p_mapa_todo(c, L, R)
	else:
		_p_memorias(c, L, R)


## A aba Mapa: o mapa nas duas telas; em cima da direita, onde o robô está; embaixo, o zoom (triângulo / E).
func _p_mapa_todo(c: Control, L: Rect2, R: Rect2) -> void:
	var aqui := Rect2(R.position.x + 14, R.position.y + 54, R.size.x - 28, 46)
	Tablet.caixa(c, aqui, Color(Tablet.TINTA, 0.06), 23)
	Tablet.pino(c, aqui.position + Vector2(24, 24), 8, PETROLEO)
	var onde := _onde(_lugar_agora())
	var t: String = onde[0] + " "
	Tablet.texto(c, aqui.position + Vector2(42, 29), t, 14, Color(Tablet.TINTA, 0.6))
	Tablet.texto(c, aqui.position + Vector2(42 + Tablet.largura(t, 14), 29), onde[1], 17, Tablet.TINTA, true)
	# o zoom em três pontinhos, embaixo da direita
	for i in ZOOMS.size():
		var zp := Vector2(R.position.x + 34 + i * 20, R.end.y - 37)
		c.draw_circle(zp, 6.0 if i == _zoom_mapa else 4.0, VERDE_AGUA if i == _zoom_mapa else Color(Tablet.TINTA, 0.25))
	Tablet.rodape(c, L, [["tri", "zoom"], ["l1", "{@r1} aba"], ["o", "fechar"]])


## O pedaço do mundo das duas metades do mapa: o mundo todo, ou um pedaço em volta do robô (sem sair do mundo).
## De perto, o robô fica no meio de uma das telas, nunca na dobra: na direita, se der; na esquerda, se a direita
## o empurra para a beira.
func _aplicar_zoom() -> void:
	var tam := Vector2(_mapa_esq.size.x * 2.0, _mapa_esq.size.y)  # as duas metades emendadas, sem a dobra
	var m := MapaCaderno.mundo
	var alto: float = ZOOMS[_zoom_mapa]
	var v := Rect2()
	if alto <= 0.0:
		var esc := maxf(m.size.x / tam.x, m.size.y / tam.y)  # metros por pixel
		v = _encaixar(Rect2(m.get_center() - tam * esc * 0.5, tam * esc))
	else:
		var esc := alto / tam.y
		var pos := armadura.global_position if armadura else Vector3.ZERO
		var nota := -1.0
		for f: float in [0.75, 0.25]:  # onde o robô fica na largura das duas telas
			var w := _encaixar(Rect2(Vector2(pos.x - f * tam.x * esc, pos.z - tam.y * esc * 0.5), tam * esc))
			var sx := (pos.x - w.position.x) / w.size.x
			var n := minf(absf(sx - 0.5), minf(sx, 1.0 - sx))  # longe da dobra e das beiradas
			if n > nota:
				nota = n
				v = w
	_mapa_esq.mostrar(Rect2(v.position, Vector2(v.size.x * 0.5, v.size.y)))
	_mapa_dir.mostrar(Rect2(v.position + Vector2(v.size.x * 0.5, 0.0), Vector2(v.size.x * 0.5, v.size.y)))
	_cartao.queue_redraw()


## O pedaço sem sair do mundo; maior que o mundo, centrado nele (o resto é mar).
static func _encaixar(v: Rect2) -> Rect2:
	var m := MapaCaderno.mundo
	for k in 2:
		if v.size[k] < m.size[k]:
			v.position[k] = clampf(v.position[k], m.position[k], m.end[k] - v.size[k])
		else:
			v.position[k] = m.get_center()[k] - v.size[k] * 0.5
	return v


## As vagas da aba Memórias: 0–11 as da ilha; com alguma lembrança do Faísca lida, as vagas encolhem e, depois de
## um separador, vêm as seis dele (12–17) e o fecho, largo, por último (18).
func _vagas_lista() -> Array:
	var L := Tablet.ESQ
	var mw := (L.size.x - 28 - 10) / 2.0
	var v: Array = []
	if _lidas_faisca().is_empty():
		for i in Memorias.ORDEM.size():
			v.append(Rect2(L.position.x + 14 + (i % 2) * (mw + 10), L.position.y + 112 + (i / 2) * 104, mw, 96))
		return v
	for i in Memorias.ORDEM.size():
		v.append(Rect2(L.position.x + 14 + (i % 2) * (mw + 10), L.position.y + 112 + (i / 2) * 58, mw, 52))
	var y0 := L.position.y + 112 + 6 * 58 + SEPARADOR_FAISCA
	for i in Memorias.ORDEM_FAISCA.size():
		v.append(Rect2(L.position.x + 14 + (i % 2) * (mw + 10), y0 + (i / 2) * 58, mw, 52))
	v.append(Rect2(L.position.x + 14, y0 + 3 * 58, mw * 2.0 + 10, 52))
	return v


## Em que vaga fica cada chave (-1 se não for de nenhuma).
func _indice_vaga(chave: String) -> int:
	var i := Memorias.ORDEM.find(chave)
	if i >= 0:
		return i
	i = Memorias.ORDEM_FAISCA.find(chave)
	if i >= 0:
		return Memorias.ORDEM.size() + i
	return Memorias.ORDEM.size() + Memorias.ORDEM_FAISCA.size() if chave == Memorias.FECHO else -1


## As vagas das memórias ainda não lidas: o contorno e o cristal apagado (as lidas são botões). Com o Faísca, o
## separador azul e as vagas dele com a fagulha apagada (o fecho só aparece lido).
func _vagas_memoria(c: CanvasItem, vagas: Array) -> void:
	var lidas := _lidas()
	for i in Memorias.ORDEM.size():
		if lidas.has(Memorias.ORDEM[i]):
			continue
		var r: Rect2 = vagas[i]
		Tablet.caixa(c, r, Color(Tablet.TINTA, 0.04), 12, Color(Tablet.TINTA, 0.15), 1)
		Tablet.cristal(c, r.get_center(), 8, Color(Tablet.TINTA, 0.25), false)
	var dele := _lidas_faisca()
	if dele.is_empty():
		return
	var L := Tablet.ESQ
	var y: float = (vagas[Memorias.ORDEM.size() - 1] as Rect2).end.y + SEPARADOR_FAISCA * 0.5 + 3.0
	var rot := "do Faísca"
	var rw := Tablet.largura(rot, 14, true)
	var meio := L.get_center().x
	var ini := meio - (rw + 26) * 0.5
	c.draw_line(Vector2(L.position.x + 14, y), Vector2(ini - 10, y), Color(Tablet.AZUL, 0.55), 2.0)
	c.draw_line(Vector2(ini + rw + 36, y), Vector2(L.end.x - 14, y), Color(Tablet.AZUL, 0.55), 2.0)
	Tablet.fagulha(c, Vector2(ini + 8, y + 1), 8, Tablet.LARANJA)
	Tablet.texto(c, Vector2(ini + 24, y + 5), rot, 14, Tablet.AZUL.darkened(0.25), true)
	for i in Memorias.ORDEM_FAISCA.size():
		if dele.has(Memorias.ORDEM_FAISCA[i]):
			continue
		var r: Rect2 = vagas[Memorias.ORDEM.size() + i]
		Tablet.caixa(c, r, Color(Tablet.AZUL, 0.05), 12, Color(Tablet.AZUL, 0.25), 1)
		Tablet.fagulha(c, r.get_center(), 8, Color(Tablet.AZUL, 0.35), false)


func _lidas() -> Array:
	var principal := get_parent()
	var memorias: Memorias = principal.get("memorias") if principal else null
	return memorias.lidas if memorias else []


func _lidas_faisca() -> Array:
	var principal := get_parent()
	var memorias: Memorias = principal.get("memorias") if principal else null
	return memorias.lidas_faisca if memorias else []


func _pintar_memoria(b: Control, r: Rect2, foco: bool, sobre: bool, chave: String) -> void:
	var grande := r.size.y > 70.0
	var sel := foco or (_aba_caderno == 1 and chave == _mem_sel)
	var titulo := String(Memorias.dado(chave)[0])
	if Memorias.TEXTOS_FAISCA.has(chave):
		# as do Faísca: cartão azul-claro com a fagulha
		Tablet.caixa(b, r, Color(0.80, 0.89, 0.97, 0.85 if sobre or sel else 0.7), 12, Tablet.AZUL if sel else Color(Tablet.AZUL, 0.35), 3 if sel else 1)
		Tablet.fagulha(b, Vector2(19, r.size.y * 0.5 + 1), 9, Tablet.LARANJA)
		Tablet.paragrafo(b, Vector2(36, _linha_cartao(titulo, r.size.x - 42, r.size.y)), titulo, r.size.x - 42, 13, Tablet.TINTA, 2)
		return
	Tablet.caixa(b, r, Color(0.98, 0.86, 0.62, 0.75 if sobre or sel else 0.6), 12, Tablet.AMBAR if sel else Color(0, 0, 0, 0), 3 if sel else 0)
	if grande:
		Tablet.brilho(b, Vector2(30, r.size.y * 0.5), 12, Color(1.0, 0.7, 0.3), 0.8)
		Tablet.cristal(b, Vector2(30, r.size.y * 0.5), 12, Tablet.AMBAR)
		Tablet.paragrafo(b, Vector2(54, r.size.y * 0.5 - 4), titulo, r.size.x - 62, 16, Tablet.TINTA, 2)
	else:
		Tablet.cristal(b, Vector2(18, r.size.y * 0.5), 8, Tablet.AMBAR)
		Tablet.paragrafo(b, Vector2(32, _linha_cartao(titulo, r.size.x - 38, r.size.y)), titulo, r.size.x - 38, 13, Tablet.TINTA, 2)


## A primeira linha do título no cartão pequeno, com o texto (uma ou duas linhas) no meio da altura.
func _linha_cartao(titulo: String, larg: float, alto: float) -> float:
	return alto * 0.5 + (-4.0 if Tablet.largura(titulo, 13) > larg else 5.0)


func _p_memorias(c: Control, L: Rect2, R: Rect2) -> void:
	_vagas_memoria(c, _vagas_lista())
	if _lidas().is_empty():
		Tablet.paragrafo(c, Vector2(R.position.x + 24, R.position.y + 110), "Nenhuma memória lida ainda. Os cristais âmbar guardam o que aconteceu na ilha.", R.size.x - 48, 18, Color(Tablet.TINTA, 0.7), 4)
	elif not Memorias.dado(_mem_sel).is_empty():
		var dado: Array = Memorias.dado(_mem_sel)
		var dele := Memorias.TEXTOS_FAISCA.has(_mem_sel)
		var tinta := Tablet.AZUL if dele else Tablet.AMBAR
		var cc := Vector2(R.get_center().x, R.position.y + 96)
		Tablet.brilho(c, cc, 20, Color(1.0, 0.7, 0.3), 1.4)
		if dele:
			Tablet.fagulha(c, cc, 24, Tablet.LARANJA)
		else:
			Tablet.cristal(c, cc, 22, Tablet.AMBAR)
		Tablet.texto(c, Vector2(R.position.x + 10, R.position.y + 174), String(dado[0]), Tablet.caber(String(dado[0]), R.size.x - 40, 26, true), tinta.darkened(0.35), true, HORIZONTAL_ALIGNMENT_CENTER, R.size.x - 20)
		c.draw_line(Vector2(R.get_center().x - 60, R.position.y + 192), Vector2(R.get_center().x + 60, R.position.y + 192), Color(tinta, 0.6), 2.0)
		var onde := String(Memorias.LUGARES.get(_mem_sel, ""))
		if onde != "":
			var ow := Tablet.largura(onde, 15, true)
			Tablet.pino(c, Vector2(R.get_center().x - ow * 0.5 - 8, R.position.y + 214), 6, PETROLEO)
			Tablet.texto(c, Vector2(R.get_center().x - ow * 0.5 + 6, R.position.y + 220), onde, 15, PETROLEO, true)
		Tablet.paragrafo(c, Vector2(R.position.x + 26, R.position.y + 256), String(dado[1]), R.size.x - 52, 17, Tablet.TINTA, 21)
	Tablet.rodape(c, R, [["l1", "{@r1} aba"], ["o", "fechar"]])


# ---- confirmação

func _pintar_confirma(c: Control, telas: Array) -> void:
	var tela: Rect2 = telas[0]
	var perigo := _confirma_acao == "novo"
	var cor: Color = Tablet.RUBI if perigo else COR.get(_confirma_texto[0], Tablet.CINZA)
	var cen := Vector2(tela.get_center().x, tela.position.y + 78)
	c.draw_circle(cen, 46, cor.lerp(Tablet.TELA, 0.82))
	c.draw_circle(cen, 38, cor)
	Tablet.icone(c, _confirma_texto[0], cen, 44, Color.WHITE, cor)
	Tablet.texto(c, Vector2(tela.position.x, tela.position.y + 168), _confirma_texto[1], 30, Tablet.TINTA, true, HORIZONTAL_ALIGNMENT_CENTER, tela.size.x)
	Tablet.paragrafo(c, Vector2(tela.position.x + 30, tela.position.y + 198), _confirma_texto[2], tela.size.x - 60, 17, Color(Tablet.TINTA, 0.65), 4, HORIZONTAL_ALIGNMENT_CENTER)
	Tablet.rodape(c, tela, [["o", "também é Não"]], tela.end.y - 30)


func _pintar_resposta(b: Control, r: Rect2, foco: bool, sobre: bool) -> void:
	var sim := b == _confirma_sim
	var perigo := sim and _confirma_acao == "novo"
	var cor := Tablet.RUBI if perigo else (Color(0.3, 0.6, 0.35) if sim else Tablet.LARANJA_V)
	if foco:
		Tablet.caixa(b, r, Color(Tablet.RUBI, 0.16) if perigo else Color(1.0, 0.72, 0.3, 0.3), 35, Tablet.RUBI if perigo else Tablet.LARANJA, 3)
	elif perigo:
		Tablet.caixa(b, r, Color(Tablet.RUBI, 0.08 if not sobre else 0.12), 35, Color(Tablet.RUBI, 0.5), 2)
	else:
		Tablet.caixa(b, r, Color(Tablet.TINTA, 0.07 if not sobre else 0.11), 35)
	b.draw_circle(Vector2(38, 35), 20, cor)
	Tablet.icone(b, "sim" if sim else "nao", Vector2(38, 35), 24, Color.WHITE, cor)
	Tablet.texto(b, Vector2(70, 43), (b as Button).text, 24, Tablet.RUBI if perigo else Tablet.TINTA, true)
	if foco:
		Tablet.botao(b, "x", Vector2(r.size.x - 30, 35), 24)


## O tamanho da telinha segue o texto (as frases de apagar e de acordar são mais compridas).
func _arrumar_confirma() -> void:
	var alto_texto := Tablet.altura_paragrafo(_confirma_texto[2], 520.0 - 60.0, 17)
	var h := 412.0 + maxf(0.0, alto_texto - 24.0)
	var tam := Vector2(560, h)
	_confirma_caixa.custom_minimum_size = tam
	_confirma_caixa.size = tam
	_confirma_caixa.position = (get_viewport().get_visible_rect().size - tam) * 0.5
	var tela := Tablet.tela_fechada(Rect2(Vector2.ZERO, tam))
	var y := tela.position.y + 214.0 + maxf(0.0, alto_texto - 4.0)
	_confirma_nao.position = Vector2(tela.get_center().x - 210, y)
	_confirma_sim.position = Vector2(tela.get_center().x + 10, y)
	_confirma_nao.size = Vector2(200, 70)
	_confirma_sim.size = Vector2(200, 70)


# ------------------------------------------------------------------ o controle desconectou

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
	_subtitulo.text = "Ligue de novo, use outro controle ou continue com teclado e mouse."


# ------------------------------------------------------------------ ajustes

## Cada ajuste guarda a explicação (o que a tela da direita conta) e o valor (que o desenho mostra).
func _escrever_ajustes() -> void:
	var q := clampi(int(Guardado.ajuste("qualidade")), 0, 2)
	var sens := clampi(int(Guardado.ajuste("sensibilidade")), 0, 4)
	var valores := [
		[_botao_qualidade, String(Qualidade.NOMES[q]), "mais baixa: menos capim, sombras mais curtas e o jogo mais solto"],
		[_botao_sens, "%d de 5" % (sens + 1), "quanto a câmera gira com o analógico direito e o mouse"],
		[_botao_eixo, "invertido" if bool(Guardado.ajuste("inverter_y")) else "normal", "invertido: empurrar o analógico para a frente olha para baixo"],
		[_botao_vibra, "ligada" if bool(Guardado.ajuste("vibra")) else "desligada", "o controle treme nos golpes, no pouso e nos tiros"],
	]
	for v: Array in valores:
		var b: Button = v[0]
		(b.get_node("explica") as Label).text = v[1]
		b.set_meta("explica", v[2])


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


# ------------------------------------------------------------------ Sim e Não

## A telinha de confirmação: figura, pergunta, uma frase e dois botões. Começa no "Não", e o círculo (ou o Esc)
## também é "Não": um toque sem querer nunca apaga nem fecha nada.
func _confirmar(qual: String) -> void:
	_confirma_acao = qual
	_confirma_volta = get_viewport().gui_get_focus_owner()
	var textos: Dictionary = {
		"sair": ["sair", "Sair do jogo?", "O progresso fica guardado."],
		"novo": ["novo", "Começar um jogo novo?", "Peças, lugares, memórias e materiais somem, e o jogo recomeça do zero. Não dá para desfazer."],
		"acordar": ["acordar", "Hora de acordar?", "Você já sabe o básico. Sim: o robô acorda na ilha. Não: continua treinando voo e combate aqui."],
	}
	_confirma_texto = (textos[qual] as Array).duplicate()
	_confirma_nao.disabled = false
	_confirma_sim.disabled = false
	_confirma.visible = true
	_arrumar_confirma()
	if qual == "acordar":
		# o caminho de quem joga é acordar: começa no Sim. Os botões esperam um instante, para o X que acabou
		# a última lição não responder sem querer
		_confirma_sim.grab_focus()
		_confirma_nao.disabled = true
		_confirma_sim.disabled = true
		get_tree().create_timer(0.8, true).timeout.connect(func() -> void:
			if _confirma.visible and _confirma_acao == "acordar":
				_confirma_nao.disabled = false
				_confirma_sim.disabled = false
				_confirma_sim.grab_focus())
	else:
		_confirma_nao.grab_focus()
	_confirma_caixa.pivot_offset = _confirma_caixa.size * 0.5
	_confirma_caixa.scale = Vector2(0.92, 0.92)
	create_tween().tween_property(_confirma_caixa, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _responder(sim: bool) -> void:
	if not sim:
		_fechar_confirma()
		return
	match _confirma_acao:
		"acordar":
			_confirma.visible = false
			_confirma_so = false
			_fundo.visible = true
			_trocar_mundo(false)
		"sair":
			var principal := get_parent()
			if principal and principal.has_method("guardar_progresso"):
				principal.call("guardar_progresso")
			get_tree().quit()
		"novo":
			Guardado.recomecar_progresso()
			_confirma_texto[1] = "Começando..."
			_confirma_texto[2] = ""
			_confirma_nao.disabled = true
			_confirma_sim.disabled = true
			# o jogo fecha e abre sozinho, já limpo: as peças, armas e lugares vivem espalhados na memória de
			# muitas partes do jogo, e reabrir é o jeito seguro de zerar tudo de uma vez
			if DisplayServer.get_name() != "headless":
				_reabrir_sem_abertura()


func _fechar_confirma() -> void:
	_confirma.visible = false
	if _confirma_so:
		# sozinha: fecha tudo e solta o jogo (no "Hora de acordar?", o Não segue no treino livre)
		_confirma_so = false
		_fundo.visible = true
		_continuar()
		return
	if _confirma_volta and is_instance_valid(_confirma_volta) and _confirma_volta.is_visible_in_tree():
		_confirma_volta.grab_focus()


## O fim do treino básico (Tutor.basico_feito): a telinha de Sim e Não sozinha, sem a pausa atrás.
func perguntar_acordar() -> void:
	if visible or get_tree().paused:
		return
	perguntas_acordar += 1
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_confirma_so = true
	_fundo.visible = false
	_confirmar("acordar")


## Fecha o jogo e abre de novo, já limpo e sem passar pela tela de abertura.
func _reabrir_sem_abertura() -> void:
	var a := PackedStringArray()
	for x in OS.get_cmdline_args():
		if x != "--sem-abertura":
			a.append(x)
	a.append("--sem-abertura")
	OS.set_restart_on_exit(true, a)
	get_tree().quit()


# ------------------------------------------------------------------ abertura

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
	_titulo.text = "Fagulha"
	_subtitulo.text = "Em Busca do Sossego"
	_primeiro.text = "Continuar" if tem else "Começar"
	(_primeiro.get_node("explica") as Label).text = "de onde você parou" if tem else ("começa o treino" if na_simulacao else "começa a história")
	_botao_novo.visible = tem
	# rever o prólogo: só com uma partida em curso (no jogo novo, Começar já passa por ele)
	var principal := get_parent()
	if _botao_historia:
		_botao_historia.visible = tem and principal != null and principal.get("historia") != null
	_botao_novo.text = "Novo jogo"
	for b: Button in [_botao_voltar, _botao_caderno, _botao_mundo]:
		if b:
			b.visible = false
	_dica.text = ""
	_arrumar_inicio()
	_primeiro.grab_focus()


## Rever a história (na tela de abertura): a pausa fecha, o prólogo passa e a abertura volta no fim.
func _ver_historia() -> void:
	var principal := get_parent()
	if principal == null or not principal.has_method("ver_historia"):
		return
	visible = false
	abertura = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	principal.call("ver_historia")


## Novo jogo pergunta antes (Sim e Não): apaga o progresso e o jogo reabre limpo.
func _novo_jogo() -> void:
	_confirmar("novo")


# ------------------------------------------------------------------ as páginas

func _mostrar(pagina: Control) -> void:
	for p: Control in [_inicio, _pagina_ajustes, _pagina_comandos, _pagina_caderno, _pagina_album]:
		p.visible = p == pagina
	_pilulas_caderno.visible = pagina == _pagina_caderno or pagina == _pagina_album
	_voltar_album.visible = pagina == _pagina_album
	for i in _pilulas.size():
		_pilulas[i].ativa = (i == 2) if pagina == _pagina_album else (i == _aba_caderno)


func _abrir_ajustes() -> void:
	_mostrar(_pagina_ajustes)
	_escrever_ajustes()
	_botao_qualidade.grab_focus()


func _fechar_ajustes() -> void:
	_mostrar(_inicio)
	_botao_ajustes.grab_focus()


## O caderno é refeito a cada abertura, com o que o jogo sabe agora.
func _abrir_caderno() -> void:
	var principal := get_parent()
	var locais: Locais = principal.get("locais") if principal else null
	var mapa: Ilha = principal.get("ilha") if principal else null
	var frente := -armadura.global_basis.z if armadura else Vector3.FORWARD
	var pos := armadura.global_position if armadura else Vector3.ZERO
	for mp: MapaCaderno in [_mapa_esq, _mapa_dir]:
		mp.preparar(mapa, locais, pos, frente)
	_zoom_mapa = 0
	_aplicar_zoom()
	var n := _contas()
	var lidas := _lidas()
	_caderno_contas.text = "Lugares visitados: %d   ·   Peças: %d   ·   Memórias: %d de %d" % [n["lugares"], Melhorias.instaladas.size() + Melhorias.achadas.size(), lidas.size(), Memorias.ORDEM.size()]
	var dele := _lidas_faisca()
	if not dele.is_empty():
		var seis := Memorias.ORDEM_FAISCA.filter(func(k: String) -> bool: return dele.has(k)).size()
		_caderno_contas.text += "   ·   Do Faísca: %d de %d" % [seis, Memorias.ORDEM_FAISCA.size()]
	for velho in _caderno_memorias.get_children():
		_caderno_memorias.remove_child(velho)
		velho.queue_free()
	var todas: Array = Memorias.ORDEM + Memorias.ORDEM_FAISCA + [Memorias.FECHO]
	for chave: String in todas:
		if not lidas.has(chave) and not dele.has(chave):
			continue
		var b := BotaoTablet.new()
		b.estilo = "livre"
		b.text = String(Memorias.dado(chave)[0])
		b.pintor = _pintar_memoria.bind(chave)
		b.set_meta("chave", chave)
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(func() -> void:
			if _aba_caderno == 1:
				_mem_sel = chave)
		b.pressed.connect(func() -> void: _mem_sel = chave)
		_caderno_memorias.add_child(b)
	if _mem_sel == "" or not (lidas.has(_mem_sel) or dele.has(_mem_sel)):
		_mem_sel = String(_caderno_memorias.get_child(0).get_meta("chave")) if _caderno_memorias.get_child_count() > 0 else ""
	_aba_caderno = 0
	_mostrar(_pagina_caderno)
	_arrumar_memorias()
	_focar_caderno()


## As memórias lidas ficam nas vagas da aba Memórias, na esquerda; a lida em foco aparece na direita.
func _arrumar_memorias() -> void:
	var vagas := _vagas_lista()
	for b: Node in _caderno_memorias.get_children():
		var r: Rect2 = vagas[_indice_vaga(String(b.get_meta("chave")))]
		(b as Control).position = r.position
		(b as Control).size = r.size
	_caderno_memorias.visible = _aba_caderno == 1
	_mapa_esq.visible = _aba_caderno == 0
	_mapa_dir.visible = _aba_caderno == 0


func _focar_caderno() -> void:
	var alvo: Control = _voltar_caderno
	for b: Node in _caderno_memorias.get_children():
		if _aba_caderno == 1 and String(b.get_meta("chave")) == _mem_sel:
			alvo = b
			break
	alvo.grab_focus()


## Troca a aba do caderno (pílulas, L1 / R1): Mapa, Memórias ou Álbum.
func _ir_aba_caderno(i: int) -> void:
	i = wrapi(i, 0, 3)
	if i == 2:
		_abrir_album()
		return
	var do_album := _pagina_album.visible
	_aba_caderno = i
	_mostrar(_pagina_caderno)
	_arrumar_memorias()
	_focar_caderno()
	if do_album:
		_titulo.text = "Caderno" if _so_caderno else "Pausa"


## O caderno pelo botão próprio (Create / M): para o jogo e abre direto nele, com o próprio título; voltar
## (ou o mesmo botão) fecha e solta o jogo.
func abrir_caderno_direto() -> void:
	_abrir()
	_so_caderno = true
	cadernos += 1
	_titulo.text = "Caderno"
	_subtitulo.text = "o mapa e o que você já viu"
	_abrir_caderno()


func _abrir_album() -> void:
	albuns += 1
	_mostrar(_pagina_album)
	var primeiro := _pagina_album.montar()
	_titulo.text = "Álbum da ilha"
	_subtitulo.text = "uma página para cada coisa fotografada"
	if primeiro:
		primeiro.grab_focus()
	else:
		_voltar_album.grab_focus()


func _fechar_album() -> void:
	_titulo.text = "Caderno" if _so_caderno else "Pausa"
	_subtitulo.text = "o mapa e o que você já viu" if _so_caderno else SUBTITULO
	_aba_caderno = 0
	_mostrar(_pagina_caderno)
	_arrumar_memorias()
	_focar_caderno()


func _fechar_caderno() -> void:
	_mostrar(_inicio)
	if _so_caderno:
		_so_caderno = false
		_continuar()
		return
	_titulo.text = "Pausa"
	_subtitulo.text = SUBTITULO
	_botao_comandos.grab_focus()


## Sair pergunta antes (Sim e Não); o progresso é guardado ao sair.
func _sair() -> void:
	_confirmar("sair")


func _mostrar_aba(qual: int) -> void:
	_aba_comandos = qual
	_aba_controle.ativa = qual == 1
	_aba_teclado.ativa = qual == 2


func _abrir_comandos() -> void:
	_mostrar(_pagina_comandos)
	_mostrar_aba(2 if not Botoes.controle else 1)
	_voltar_comandos.grab_focus()


func _fechar_comandos() -> void:
	_mostrar(_inicio)
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
			if _confirma_so:
				_fechar_confirma()
			else:
				_confirma.visible = false
				_continuar()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("caderno"):
			get_viewport().set_input_as_handled()
		return
	# L1 / R1 trocam as abas dos comandos e do caderno
	if visible and (event.is_action_pressed("roda") or event.is_action_pressed("granada")):
		var passo := -1 if event.is_action_pressed("roda") else 1
		if _pagina_comandos.visible:
			_mostrar_aba(2 if _aba_comandos == 1 else 1)
			get_viewport().set_input_as_handled()
		elif _pagina_caderno.visible or _pagina_album.visible:
			var atual := 2 if _pagina_album.visible else _aba_caderno
			if _pagina_album.visible and wrapi(atual + passo, 0, 3) != 2:
				_fechar_album()
			_ir_aba_caderno(atual + passo)
			get_viewport().set_input_as_handled()
		return
	# o triângulo (ou o E) muda o zoom da aba Mapa: o mundo todo, perto e mais perto
	if visible and _pagina_caderno.visible and _aba_caderno == 0 and event.is_action_pressed("agir"):
		_zoom_mapa = (_zoom_mapa + 1) % ZOOMS.size()
		_aplicar_zoom()
		get_viewport().set_input_as_handled()
		return
	# o Esc é "menu" e também "voltar": dentro de uma página ele volta uma página, como o círculo
	if visible and event.is_action_pressed("ui_cancel"):
		if _pagina_comandos.visible:
			_fechar_comandos()
		elif _pagina_album.visible:
			_fechar_album()
		elif _pagina_caderno.visible:
			_fechar_caderno()
		elif _pagina_ajustes.visible:
			_fechar_ajustes()
		else:
			_continuar()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("caderno") and not na_simulacao and not abertura:
		# o caderno tem botão próprio: abre por cima do jogo e o mesmo botão fecha
		if visible and _pagina_album.visible:
			_fechar_album()
			_fechar_caderno()
		elif visible and _pagina_caderno.visible:
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
	_mostrar(_inicio)
	_confirma.visible = false
	_confirma_so = false
	_fundo.visible = true
	_so_caderno = false
	if _botao_historia:
		_botao_historia.visible = false
	# desfaz o que a tela de abertura mudou
	abertura = false
	_primeiro.text = "Continuar"
	(_primeiro.get_node("explica") as Label).text = "volta ao jogo"
	_botao_novo.visible = not na_simulacao  # na simulação é só treino
	for b: Button in [_botao_voltar, _botao_caderno, _botao_mundo]:
		if b:
			b.visible = true
	_titulo.text = "Pausa"
	_subtitulo.text = SUBTITULO
	# desligado (em pane), o robô não volta à base pela pausa: quem o leva é o drone, e a derrota na Fundição
	# custa metade dos materiais
	var em_pane := armadura != null and armadura.em_pane
	if _botao_voltar:
		_botao_voltar.disabled = em_pane
		(_botao_voltar.get_node("explica") as Label).text = "robô desligado: aguarde o drone" if em_pane else "reaparece no começo"
	_arrumar_inicio()
	_primeiro.grab_focus()
	_dica.text = DICAS[(aberturas - 1) % DICAS.size()]
	# o tablet chega com um movimento curto
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
