class_name Oficina
extends Node3D
## A oficina da base (doc §65): o cilindro onde as peças são instaladas. Perto da boca aparece o convite
## (quadrado / E); o robô entra andando, os braços da máquina descem sobre ele e abre a tela: o robô de um
## lado, a lista das peças do outro, com a prévia da peça escolhida no corpo. Cada instalação gasta energia
## da base, que recarrega com o tempo de jogo; quando volta a dar para instalar, um aviso chama o jogador.

signal instalou(nome: String)

enum Fase { FORA, ENTRANDO, ABERTA, INSTALANDO, SAINDO }
const PERTO := 2.7  # m da boca para o convite aparecer
const FUNDO := 2.3  # m para dentro da boca onde o robô para
const T_ENTRAR := 1.5
const T_INSTALAR := 1.9
const T_SAIR := 1.3
const TINTA := Color(0.93, 0.94, 0.9)
const APAGADO := Color(0.62, 0.68, 0.66)
const LARANJA := Color(1.0, 0.62, 0.3)
const AGUA := Color(0.35, 0.95, 0.85)
# de que lado cada peça aparece melhor: de costas ou de frente
const DE_COSTAS := ["radiador", "radiador2", "asas", "amortecedores", "celulas", "bocais"]
## As armas de fábrica, que só sobem de degrau: [título, o que fazem]
const DE_FABRICA := {
	"pistola": ["Pistola", "A arma de fábrica: um tiro por aperto."],
	"espada": ["Espada de laser", "A lâmina curta do pulso, de fábrica: um golpe em arco, de perto, que alterna de lado."],
}

var armadura: Armadura
var camera: CameraVoo
var hud: Hud
var sons: Sons
var drone: DroneColega
var fase := Fase.FORA
var perto := false
const ABAS := ["Peças da ilha", "Armas", "Defesa", "Jatos", "Corpo"]
var aba := 0
var entradas := 0  # testes
var recargas := 0
var melhoradas := 0  # degraus de arma feitos aqui (testes)
var _t := 0.0
var _de := Vector3.ZERO
var _para := Vector3.ZERO
var _cam: Camera3D
var _luz: OmniLight3D
var _luz_forca := 1.3
## O sol de ateliê (2026-11-24, doc §161): com o interior novo, o robô no berço leva uma luz só, da cor e da força do
## sol das 11h lá fora, de cima e de três quartos. As lâmpadas que havia (o foco, a luz fria, a da oficina, e a da
## boca e a do drone atravessando a parede) se somavam no estilo em faixas e lavavam as cores das peças.
var _sol: DirectionalLight3D
const SOL_COR := Color(1.0, 0.9026, 0.7188)  # o sol às 11h, céu limpo (CicloDia)
const SOL_FORCA := 1.08
## O robô está na oficina (entrando, dentro ou saindo): a luz da boca do cilindro e a do drone apagam (doc §161).
static var por_dentro := false
var _bracos: Array[Dictionary] = []
var _desce := 0.0  # 0 braços recolhidos no teto, 1 em volta do robô
var _instalando := ""
var _escolhida := ""
var _tinha_energia := true
var _guardar_t := 0.0
var _tela: CanvasLayer
var _botoes := {}


## A pausa não abre com a oficina em uso (ela tem a própria tela e a própria câmera).
func ocupada() -> bool:
	return fase != Fase.FORA


func _ready() -> void:
	add_to_group("sem_pausa")
	var t := BaseVale.cilindro_t
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.1
	add_child(_cam)
	_luz = OmniLight3D.new()
	# o cilindro por dentro (doc §138) é branco e conservado: a luz fria combina; o antigo era de ferrugem
	_luz.light_color = Color(0.86, 0.95, 1.0) if InteriorCilindro.ativo else Color(1.0, 0.86, 0.66)
	# o interior novo tem o sol de ateliê no lugar desta lâmpada (doc §161; antes 0,95, e de costas a nuca estourava)
	_luz_forca = 0.0 if InteriorCilindro.ativo else 1.3
	_luz.light_energy = 0.0
	_luz.omni_range = 7.0
	_luz.position = t * Vector3(BaseVale.MEIO_CIL - FUNDO + 0.9, 0.9, 0.0)
	add_child(_luz)
	por_dentro = false
	if InteriorCilindro.ativo:
		_sol = DirectionalLight3D.new()
		_sol.light_color = SOL_COR
		_sol.light_energy = 0.0
		_sol.shadow_enabled = false  # com sombra, a casca do cilindro tapava
		_sol.visible = false
		add_child(_sol)
	if not InteriorCilindro.ativo:
		_montar_bracos()  # o interior novo tem os braços dele, nos trilhos do teto
	_montar_tela()
	_tinha_energia = Melhorias.energia >= Melhorias.CUSTO


## Onde o robô fica dentro do cilindro (no mundo): em cima do estrado.
func _parada() -> Vector3:
	return BaseVale.cilindro_t * Vector3(BaseVale.MEIO_CIL - FUNDO, -(BaseVale.R_CIL - 0.2) + 0.51, 0.0)


func _eixo() -> Vector3:
	return BaseVale.cilindro_t.basis.x.normalized()


## A luz da oficina de 0 (fora) a 1 (dentro): o sol de ateliê acende e as lâmpadas do interior baixam (doc §161).
func _luz_atelie(f: float) -> void:
	if _sol:
		_sol.light_energy = SOL_FORCA * f
	if _berco():
		_berco().luz_oficina(f)


## O berço de montagem do cilindro (doc §138), quando o interior novo está no jogo.
func _berco() -> InteriorCilindro:
	return InteriorCilindro.atual if is_instance_valid(InteriorCilindro.atual) else null


# ------------------------------------------------------------------ braços da máquina

## Três braços de dois segmentos presos no teto do tubo. Cada quadro, a ponta vai do ponto recolhido ao
## ponto de trabalho e o cotovelo sai da conta dos dois comprimentos.
func _montar_bracos() -> void:
	var escuro := _mat(Color(0.2, 0.23, 0.26))
	var x0 := BaseVale.MEIO_CIL - FUNDO
	var teto := BaseVale.R_CIL - 0.3
	for dados in [[Vector3(x0 + 0.1, teto, 0.95), Vector3(x0, -0.8, 0.5)], [Vector3(x0 + 0.1, teto, -0.95), Vector3(x0, -0.8, -0.5)],
			[Vector3(x0 - 1.0, teto, 0.0), Vector3(x0 - 0.42, -0.7, 0.0)]]:
		var b := {"base": dados[0], "alvo": dados[1], "nos": []}
		b["dobra"] = (Vector3(dados[0].x, 0, dados[0].z) - Vector3(x0, 0, 0)).normalized()
		b["recolhido"] = dados[0] + Vector3(-0.7, -0.22, 0.0)
		for i in 2:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.11 - i * 0.035, 1.0, 0.11 - i * 0.035)
			mi.mesh = bm
			mi.material_override = escuro
			add_child(mi)
			(b["nos"] as Array).append(mi)
		for i in 3:
			var junta := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.1 - i * 0.015
			sm.height = sm.radius * 2.0
			junta.mesh = sm
			junta.material_override = _mat(LARANJA) if i < 2 else _mat_luz(AGUA, 0.0)
			add_child(junta)
			(b["nos"] as Array).append(junta)
		var faisca := OmniLight3D.new()
		faisca.light_color = AGUA
		faisca.light_energy = 0.0
		faisca.omni_range = 2.2
		add_child(faisca)
		(b["nos"] as Array).append(faisca)
		_bracos.append(b)
	_por_bracos(0.0, 0.0)


func _mat(cor: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_solido.gdshader")
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("brilho_borda", 0.18)
	return m


func _mat_luz(cor: Color, forca: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = forca
	return m


func _segmento(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var comp := maxf(d.length(), 0.01)
	var y := d / comp
	var x := y.cross(Vector3(0.31, 0.2, 0.93)).normalized()
	mi.global_transform = Transform3D(Basis(x, y * comp, x.cross(y)), (a + b) * 0.5)


func _por_bracos(f: float, trabalho: float) -> void:
	var t := BaseVale.cilindro_t
	var l1 := 1.75
	var l2 := 1.75
	for i in _bracos.size():
		var b := _bracos[i]
		var base: Vector3 = b["base"]
		var ponta: Vector3 = (b["recolhido"] as Vector3).lerp(b["alvo"], smoothstep(0.0, 1.0, f))
		if trabalho > 0.0:
			var fase_b := _t * 9.0 + i * 2.1
			ponta += Vector3(sin(fase_b) * 0.09, sin(fase_b * 1.7) * 0.16, cos(fase_b * 1.3) * 0.09) * trabalho
		# cotovelo: no plano que tem a base, a ponta e o lado de dobrar
		var d := ponta - base
		var dist := clampf(d.length(), 0.05, l1 + l2 - 0.02)
		var ao_longo := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
		var alto := sqrt(maxf(0.0, l1 * l1 - ao_longo * ao_longo))
		var dn := d.normalized()
		var lado: Vector3 = (b["dobra"] as Vector3 + Vector3(0, 0.6, 0))
		lado = (lado - dn * lado.dot(dn)).normalized()
		var cotovelo := base + dn * ao_longo + lado * alto
		var nos: Array = b["nos"]
		_segmento(nos[0], t * base, t * cotovelo)
		_segmento(nos[1], t * cotovelo, t * ponta)
		(nos[2] as Node3D).global_position = t * base
		(nos[3] as Node3D).global_position = t * cotovelo
		(nos[4] as Node3D).global_position = t * ponta
		var brilho := trabalho * (0.5 + 0.5 * sin(_t * 31.0 + i * 1.9))
		((nos[4] as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = 0.6 * f + 6.0 * brilho
		(nos[5] as OmniLight3D).global_position = t * ponta
		(nos[5] as OmniLight3D).light_energy = 2.4 * brilho


# ------------------------------------------------------------------ a tela: o tablet dobrável (doc §136)
# O usuário achou a lista escura feia e pouco amiga; dos rascunhos, aprovou o tablet dobrável (2026-11-21).
# Na tela da esquerda, as abas em pílulas e a lista; na da direita, a planta azul do item em foco, a trilha de
# lâmpadas das melhorias, os carimbos do custo e o botão de segurar X (segurar evita gastar sem querer).

const T_SEGURAR := 0.55  # segundos segurando X para instalar, fabricar ou melhorar
const PILULAS := [["peca", "Peças"], ["pistola", "Armas"], ["escudo", "Defesa"], ["bocais", "Jatos"], ["corpo", "Corpo"]]
## As armas na ordem em que abrem, com as granadas no fim, depois dos mísseis (doc §158; só a lista, o nível
## de cada uma não muda).
const ARMAS := ["pistola", "espada", "duplo", "precisao", "rajada", "canhao", "misseis", "granadas"]
const DEFESA := ["mira", "escudo", "vida"]
## Os nomes curtos dos quadradinhos de peça.
const CURTO := {"antena": "Antena", "radiador": "Radiador", "radiador2": "Radiador 2", "bocais": "Bocais", "asas": "Asas",
	"barbatanas": "Barbatanas", "amortecedores": "Molas", "farol": "Luz", "celulas": "Células", "scanner": "Scanner",
	"corrida": "Bocal", "couraca": "Couraça", "cano": "Cano", "nucleo": "Núcleo"}
## O que cada luz da trilha dá, em figura e número (o último míssil trava cinco máquinas).
const TRILHA := {"pistola": ["dano", "+15%"], "espada": ["dano", "+15%"], "duplo": ["mira", "certeiro"], "canhao": ["estouro", "+8%"],
	"precisao": ["dano", "+15%"], "rajada": ["mira", "certeira"], "misseis": ["misseis", "+2"], "granadas": ["granadas", "+1"]}
const MATERIAL_COR := {"sucata": Color(0.88, 0.48, 0.15), "nucleos": Color(0.08, 0.58, 0.55), "chips": Color(0.48, 0.36, 0.8)}

var _casca: TabletCasca
var _lista: Control
var _pilulas: Array[BotaoTablet] = []
var _botao_segurar: BotaoTablet
var _segura := 0.0  # 0 a 1: o anel do botão de segurar
var _mouse_segura := false
var _soltar := false  # depois de fazer, espera soltar o X para não repetir
var _aviso := ""  # o recado curto da tela da direita ("Instalado!", "ainda não dá")
var _aviso_cor := Tablet.OK
var _aviso_t := 0.0
var _fazendo := ""  # "Melhorando…" etc. enquanto os braços trabalham
## A aba Corpo (§146): uma linha por parte, com setas; a primeira, "inteiro", troca as seis juntas.
const LINHAS_CORPO := ["inteiro", "cabeca", "tronco", "bracoD", "bracoE", "pernaD", "pernaE"]
## A distância da câmera à parte em foco (m), com o campo de visão de 40°.
const CAM_PERTO := {"cabeca": 1.85, "tronco": 1.8, "bracoD": 1.95, "bracoE": 1.95, "pernaD": 2.2, "pernaE": 2.2}
var _linha := "cabeca"  # aba Corpo: a linha em foco
var _montagem := {}  # aba Corpo: a peça escolhida de cada parte (vale até sair da oficina; vestir veste tudo)
var _perto := true  # aba Corpo: a câmera perto da parte em foco (o △ alterna)
var _cam_longe := Transform3D.IDENTITY  # a câmera de sempre da oficina: de onde ela sai e para onde volta
var _seta_t := 0.0  # segurando ◀ ou ▶, as peças passam sozinhas
var _piscar := 0.0  # a linha da peça fechada pisca vermelha ao tentar vestir
var _corpo_pedido := {}  # o corpo que os braços estão vestindo agora
var _novo_mostrado := false  # aba Corpo: o conjunto novo já foi posto na montagem nesta visita (doc §148)
var _visto_t := 0.0  # segundos com um conjunto novo em foco: passado `VER`, ele deixa de ser novo
const VER := 1.5


func _montar_tela() -> void:
	_tela = CanvasLayer.new()
	_tela.layer = 6
	_tela.visible = false
	add_child(_tela)
	_casca = TabletCasca.new()
	_casca.barra = false  # a barra de cima da oficina é própria (nível e experiência)
	_casca.anchor_left = 1.0
	_casca.anchor_right = 1.0
	_casca.anchor_top = 0.5
	_casca.anchor_bottom = 0.5
	_casca.offset_left = -Tablet.TAM.x - 8.0
	_casca.offset_right = -8.0
	_casca.offset_top = -Tablet.TAM.y * 0.5
	_casca.offset_bottom = Tablet.TAM.y * 0.5
	_casca.pintor = _pintar
	_tela.add_child(_casca)
	_lista = Control.new()
	_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista.size = Tablet.TAM
	_casca.add_child(_lista)
	var L := Tablet.ESQ
	var cores := [Tablet.VERDE, Tablet.LARANJA_V, Tablet.AZUL, Tablet.LILAS, Tablet.RUBI]
	var pw := (L.size.x - 36.0) / PILULAS.size()
	for i in PILULAS.size():
		var p := BotaoTablet.new()
		p.estilo = "pilula"
		p.icone = PILULAS[i][0]
		p.text = PILULAS[i][1]
		p.cor = cores[i]
		p.focus_mode = Control.FOCUS_NONE
		p.position = Vector2(L.position.x + 18 + i * pw, L.position.y + 58)
		p.size = Vector2(pw, 38)
		p.pressed.connect(func() -> void: _mudar_aba(i - aba))
		_casca.add_child(p)
		_pilulas.append(p)
	# o botão de segurar, para o mouse (o desenho é da tela da direita)
	_botao_segurar = BotaoTablet.new()
	_botao_segurar.estilo = "livre"
	_botao_segurar.focus_mode = Control.FOCUS_NONE
	_botao_segurar.position = Tablet.DIR.position + Vector2(28, 638)
	_botao_segurar.size = Vector2(360, 84)
	_botao_segurar.button_down.connect(func() -> void: _mouse_segura = true)
	_botao_segurar.button_up.connect(func() -> void: _mouse_segura = false)
	_casca.add_child(_botao_segurar)


## Um item da lista: um botão de verdade (foco, mouse, teclado) que se desenha com o `pintor`.
func _item(nome: String, r: Rect2, pintor: Callable) -> BotaoTablet:
	var b := BotaoTablet.new()
	b.estilo = "livre"
	b.position = r.position
	b.size = r.size
	b.pintor = pintor
	b.focus_entered.connect(func() -> void: _escolher(nome))
	b.mouse_entered.connect(b.grab_focus)
	b.set_meta("nome", nome)
	_lista.add_child(b)
	_botoes[nome] = b
	return b


func _mudar_aba(passo: int) -> void:
	if passo == 0:
		return
	aba = wrapi(aba + passo, 0, ABAS.size())
	_escolhida = ""
	_corpo_de_volta()
	_rastro_de_volta()
	_refazer_lista()
	if sons:
		sons._toque("roda_troca", -8.0, 0.0)


## A lista da aba em uso: as peças achadas na ilha, as armas, a defesa ou as cores de rastro.
func _refazer_lista() -> void:
	for f in _lista.get_children():
		_lista.remove_child(f)
		f.queue_free()
	_botoes.clear()
	for i in _pilulas.size():
		_pilulas[i].ativa = i == aba
	_ponto_corpo()
	if aba == 4 and not _novo_mostrado and not Corpo.novos().is_empty():
		# um conjunto novo: a aba abre na linha Inteiro com ele vestido na montagem (doc §148)
		_novo_mostrado = true
		_linha = "inteiro"
		for parte: String in Corpo.PARTES:
			_montagem[parte] = Corpo.novos()[0]
	var bom: Button = null
	match aba:
		0:
			bom = _lista_pecas()
		1:
			bom = _lista_armas()
		2:
			bom = _lista_defesa()
		3:
			bom = _lista_rastro()
		4:
			bom = _lista_corpo()
	if _escolhida != "" and _botoes.has(_escolhida):
		bom = _botoes[_escolhida]
	if bom == null and _lista.get_child_count() > 0:
		bom = _lista.get_child(0) as Button
	if bom:
		bom.grab_focus.call_deferred()


func _lista_pecas() -> Button:
	var L := Tablet.ESQ
	var bom: Button = null
	var tw := 124.0
	var th := 92.0
	var y0 := L.position.y + 116.0
	for i in Melhorias.NOMES.size():
		var nome: String = Melhorias.NOMES[i]
		var r := Rect2(L.position.x + 14 + (i % 3) * (tw + 8), y0 + (i / 3) * (th + 8), tw, th)
		var b := _item(nome, r, _pintar_peca.bind(nome))
		if bom == null and Melhorias.achadas.has(nome):
			bom = b
	# os prêmios (das rotas e dos procurados) só aparecem depois de ganhos, numa fileira menor
	var premios: Array = []
	for nome: String in Melhorias.PREMIOS:
		if Melhorias.achadas.has(nome) or Melhorias.instaladas.has(nome):
			premios.append(nome)
	var pw := (L.size.x - 28 - 3 * 8) / 4.0
	for i in premios.size():
		var nome: String = premios[i]
		var r := Rect2(L.position.x + 14 + i * (pw + 8), y0 + 4 * (th + 8) + 30, pw, 84)
		var b := _item(nome, r, _pintar_peca.bind(nome))
		if bom == null and Melhorias.achadas.has(nome):
			bom = b
	return bom


func _lista_armas() -> Button:
	var L := Tablet.ESQ
	var bom: Button = null
	for i in ARMAS.size():
		var nome: String = ARMAS[i]
		var y := L.position.y + 116.0 + i * 70.0
		var b := _item(nome, Rect2(L.position.x + 12, y + 4, L.size.x - 24, 60), _pintar_arma.bind(nome))
		if bom == null and _pode(nome):
			bom = b
	return bom


func _lista_defesa() -> Button:
	var L := Tablet.ESQ
	var bom: Button = null
	for i in DEFESA.size():
		var nome: String = DEFESA[i]
		var b := _item(nome, Rect2(L.position.x + 14, L.position.y + 116 + i * 112, L.size.x - 28, 100), _pintar_defesa.bind(nome))
		if bom == null and _pode(nome):
			bom = b
	return bom


func _lista_rastro() -> Button:
	var L := Tablet.ESQ
	var bom := _item("rastro_", Rect2(L.position.x + 14, L.position.y + 116, L.size.x - 28, 64), _pintar_rastro.bind(""))
	var tw := (L.size.x - 28 - 10) / 2.0
	for i in Rotas.ROTAS.size():
		var id: String = Rotas.ROTAS[i]["id"]
		var b := _item("rastro_" + id, Rect2(L.position.x + 14 + (i % 2) * (tw + 10), L.position.y + 194 + (i / 2) * 106, tw, 96), _pintar_rastro.bind(id))
		if Rotas.rastro == id:
			bom = b
	return bom


## Uma linha por parte (a primeira, "Inteiro", troca as seis), com setas; e a planta da direita, para o mouse.
func _lista_corpo() -> Button:
	var L := Tablet.ESQ
	if _montagem.is_empty():
		_montagem = Corpo.vestido.duplicate()
	var x := L.position.x + 14.0
	var w := L.size.x - 28.0
	var y := L.position.y + 114.0
	var bom: Button = null
	for i in LINHAS_CORPO.size():
		var linha: String = LINHAS_CORPO[i]
		var h := 86.0 if i == 0 else 84.0
		var b := _item("linha_" + linha, Rect2(x, y, w, h), _pintar_linha.bind(linha))
		b.gui_input.connect(_seta_linha.bind(b, linha))
		if linha == _linha:
			bom = b
		y += h + (12.0 if i == 0 else 4.0)
	# clicar numa peça da planta põe o foco na linha dela
	for parte: String in Corpo.PARTES:
		var t := BotaoTablet.new()
		t.estilo = "livre"
		t.focus_mode = Control.FOCUS_NONE
		var q := _quadro_planta(parte)
		t.position = q.position
		t.size = q.size
		t.pressed.connect(func() -> void:
			if _botoes.has("linha_" + parte):
				(_botoes["linha_" + parte] as Control).grab_focus())
		_lista.add_child(t)
	return bom


## O pontinho laranja na pílula do Corpo enquanto houver conjunto novo não visto.
func _ponto_corpo() -> void:
	if _pilulas.size() > 4:
		var tem := not Corpo.novos().is_empty()
		if _pilulas[4].ponto != tem:
			_pilulas[4].ponto = tem
			_pilulas[4].queue_redraw()


## Uma estrelinha de quatro pontas (o ✦ do conjunto novo).
static func _estrela(c: CanvasItem, ct: Vector2, r: float, cor: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := i * TAU / 8.0 - PI * 0.5
		pts.append(ct + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.32))
	var fora := PackedVector2Array()
	for i in 8:
		var ang := i * TAU / 8.0 - PI * 0.5
		fora.append(ct + Vector2(cos(ang), sin(ang)) * ((r + 3.0) if i % 2 == 0 else (r * 0.32 + 2.2)))
	c.draw_colored_polygon(fora, Color(1, 1, 1, 0.95))
	c.draw_colored_polygon(pts, cor)


## ◀ e ▶ (ou um clique nas setas da linha) trocam a peça daquela parte.
func _seta_linha(ev: InputEvent, b: Control, linha: String) -> void:
	var passo := 0
	if ev.is_action_pressed("ui_left"):
		passo = -1
	elif ev.is_action_pressed("ui_right"):
		passo = 1
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mx := (ev as InputEventMouseButton).position.x
		if mx > 76.0 and mx < 106.0:
			passo = -1
		elif mx > b.size.x - 40.0:
			passo = 1
	if passo != 0:
		_seta_t = 0.0
		_trocar_peca(linha, passo)
		b.accept_event()


## A peça seguinte (ou a anterior) daquela parte, dando a volta; na linha "inteiro", as seis juntas, a partir do
## conjunto do tronco.
func _trocar_peca(linha: String, passo: int) -> void:
	if fase != Fase.ABERTA:
		return
	var ordem := Corpo.ordem()
	var atual := String(_montagem.get("tronco" if linha == "inteiro" else linha, ""))
	var chave: String = ordem[wrapi(ordem.find(atual) + passo, 0, ordem.size())]
	if linha == "inteiro":
		for parte: String in Corpo.PARTES:
			_montagem[parte] = chave
	else:
		_montagem[linha] = chave
	_segura = 0.0
	_previa_corpo()
	if sons:
		sons._toque("roda_troca", -12.0, 0.0)


## Segurando ◀ ou ▶ no controle (ou no teclado), as peças passam sozinhas.
func _repetir_seta(delta: float) -> void:
	var dir := int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	if dir == 0:
		_seta_t = 0.0
		return
	_seta_t += delta
	if _seta_t > 0.45:
		_seta_t -= 0.14
		_trocar_peca(_linha, dir)


## A primeira peça da montagem que ainda está fechada (por nível ou de robô achado), ou "".
func _fechada() -> String:
	for parte: String in Corpo.PARTES:
		var k := String(_montagem.get(parte, ""))
		if not Corpo.aberto(k):
			return k
	return ""


## O conjunto das seis peças, se forem todas do mesmo; "#" se a montagem é misturada.
func _um_so() -> String:
	var k := String(_montagem.get("cabeca", ""))
	for parte: String in Corpo.PARTES:
		if String(_montagem.get(parte, "")) != k:
			return "#"
	return k


# ------------------------------------------------------------------ o estado de cada item

## Uma arma (ou o escudo) pronta que sobe de degrau?
func _de_degrau(nome: String) -> bool:
	return DE_FABRICA.has(nome) or (Arsenal.fabricados.has(nome) and Arsenal.MELHORA.has(nome))


## Segurar X faz alguma coisa com este item agora?
func _pode(nome: String) -> bool:
	if nome == "":
		return false
	if nome.begins_with("rastro_"):
		var id := nome.substr(7)
		return Rotas.rastro != id and (id == "" or int(Rotas.feitas.get(id, 0)) >= 1)
	if nome.begins_with("linha_"):
		return _fechada() == "" and _montagem != Corpo.vestido
	if _de_degrau(nome):
		return Arsenal.falta_degrau(nome) == ""
	if Arsenal.RECEITAS.has(nome):
		return not Arsenal.fabricados.has(nome) and Arsenal.falta(nome) == ""
	return Melhorias.achadas.has(nome) and not Melhorias.instaladas.has(nome)


## As luzes acesas da trilha: os degraus das armas; no escudo, a fabricação acende a primeira.
func _acesas(nome: String) -> int:
	if nome == "escudo":
		return (1 + Arsenal.degrau("escudo")) if Arsenal.fabricados.has("escudo") else 0
	return Arsenal.degrau(nome)


func _titulo_de(nome: String) -> String:
	match nome:
		"pistola":
			return "Pistola"
		"espada":
			return "Espada"
		"duplo":
			return "Tiro duplo"
		"misseis":
			return "Mísseis"
		"granadas":
			return "Granadas"
	return String(Arsenal.RECEITAS[nome]["titulo"])


func _custo_receita(nome: String) -> Dictionary:
	var r: Dictionary = Arsenal.RECEITAS[nome]
	return {"sucata": r["sucata"], "nucleos": r["nucleos"], "chips": r["chips"], "nivel": r["nivel"]}


func _avisar(t: String, cor := Tablet.OK) -> void:
	_aviso = t
	_aviso_cor = cor
	_aviso_t = 2.4


# ------------------------------------------------------------------ pintores da lista

func _pintar_arma(b: Control, r: Rect2, foco: bool, sobre: bool, nome: String) -> void:
	var feita := _de_degrau(nome)
	var travada := not feita and Arsenal.nivel() < int(Arsenal.RECEITAS[nome]["nivel"])
	var apagada := travada or (not feita and Arsenal.falta(nome) != "")
	var tinta := Color(Tablet.TINTA, 0.42) if apagada else Tablet.TINTA
	if foco:
		Tablet.caixa(b, r, Color(1.0, 0.72, 0.3, 0.32), 14)
		Tablet.caixa(b, Rect2(0, 10, 5, 40), Color(0.95, 0.5, 0.15), 3)
	elif sobre:
		Tablet.caixa(b, r, Color(Tablet.TINTA, 0.05), 14)
	Icones.desenhar(b, nome, Vector2(38, 30), 0.95, tinta, 2.0)
	Tablet.texto(b, Vector2(70, 38), _titulo_de(nome), 20, tinta, foco)
	if not feita:
		Tablet.caixa(b, Rect2(256, 16, 92, 28), Color(Tablet.LARANJA_V, 0.07 if apagada else 0.18), 14)
		Tablet.texto(b, Vector2(256, 36), "a fazer", 15, Color(0.85, 0.42, 0.12, 0.45 if apagada else 1.0), true, HORIZONTAL_ALIGNMENT_CENTER, 92)
	else:
		var dg := Arsenal.degrau(nome)
		var trava := Arsenal.falta_degrau(nome).begins_with("pede")
		for k in Arsenal.DEGRAUS:
			Tablet.lampada(b, Vector2(268 + k * 34, 26), 9.0, 1 if k < dg else (2 if k == dg and not trava else 0))
	if travada or (feita and Arsenal.falta_degrau(nome).begins_with("pede")):
		Icones.desenhar(b, "cadeado", Vector2(r.size.x - 10, 26), 0.42, Color(Tablet.TINTA, 0.5), 1.6)


func _pintar_peca(b: Control, r: Rect2, foco: bool, sobre: bool, nome: String) -> void:
	var tem := Melhorias.instaladas.has(nome)
	var achou := Melhorias.achadas.has(nome) and not tem
	var pequeno := r.size.y < 90.0
	var ic := "radiador" if nome == "radiador2" else nome
	if tem or achou:
		var borda := Tablet.LARANJA if foco else (Color(Tablet.LARANJA, 0.5) if achou else Color(0, 0, 0, 0))
		var fundo := Color(1.0, 0.72, 0.3, 0.22) if achou else Color(Tablet.TINTA, 0.06 + (0.04 if sobre else 0.0))
		Tablet.caixa(b, r, fundo, 14, borda, 3 if foco else (1 if achou else 0))
		Icones.desenhar(b, ic, r.get_center() - Vector2(0, 12), 0.9 if pequeno else 1.05, Tablet.LARANJA if achou else Tablet.TINTA, 2.2)
		Tablet.texto(b, Vector2(0, r.size.y - 14), CURTO.get(nome, nome), 14, Tablet.TINTA, foco, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if tem:
			Tablet.visto(b, Vector2(r.size.x - 16, 16), 9)
		else:
			Tablet.brilhinho(b, Vector2(r.size.x - 16, 16), 10, Tablet.LARANJA)
		return
	# não achada: o contorno tracejado e a interrogação
	var tinta := Tablet.LARANJA if foco else Color(Tablet.TINTA, 0.25)
	var lw := 2.5 if foco else 1.5
	var px := 6.0
	while px < r.size.x - 10:
		b.draw_line(Vector2(px, 0), Vector2(px + 6, 0), tinta, lw)
		b.draw_line(Vector2(px, r.size.y), Vector2(px + 6, r.size.y), tinta, lw)
		px += 12.0
	var py := 6.0
	while py < r.size.y - 10:
		b.draw_line(Vector2(0, py), Vector2(0, py + 6), tinta, lw)
		b.draw_line(Vector2(r.size.x, py), Vector2(r.size.x, py + 6), tinta, lw)
		py += 12.0
	Tablet.texto(b, Vector2(0, r.size.y * 0.5 + 14), "?", 40, Color(Tablet.TINTA, 0.25), true, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _pintar_defesa(b: Control, r: Rect2, foco: bool, sobre: bool, nome: String) -> void:
	var rc: Dictionary = Arsenal.RECEITAS[nome]
	var feito := Arsenal.fabricados.has(nome)
	var travado := not feito and Arsenal.nivel() < int(rc["nivel"])
	var fundo := Color(1.0, 0.72, 0.3, 0.3) if foco else Color(Tablet.TINTA, 0.05 + (0.04 if sobre else 0.0))
	Tablet.caixa(b, r, fundo, 16, Tablet.LARANJA if foco else Color(0, 0, 0, 0), 3 if foco else 0)
	b.draw_circle(Vector2(50, 50), 32, Color(Tablet.TINTA, 0.08))
	Icones.desenhar(b, nome, Vector2(50, 50), 1.15, Color(Tablet.TINTA, 0.4) if travado else Tablet.TINTA, 2.2)
	Tablet.texto(b, Vector2(96, 44), String(rc["titulo"]), 20, Color(Tablet.TINTA, 0.45) if travado else Tablet.TINTA, true)
	var cargas := Arsenal.escudo_cargas() if feito else 1
	var curto := {"mira": "aponta sozinha", "escudo": "segura %d %s" % [cargas, "acerto" if cargas == 1 else "acertos"], "vida": "um acerto a mais"}
	Tablet.texto(b, Vector2(96, 70), curto[nome], 15, Color(Tablet.TINTA, 0.6))
	if nome == "escudo" and feito:
		# a trilha pequena: a primeira luz acende ao fabricar
		var trava := Arsenal.falta_degrau("escudo").begins_with("pede")
		for k in Arsenal.ESCUDO_CARGAS:
			Tablet.lampada(b, Vector2(r.size.x - 98 + k * 30, 64), 8.0, 1 if k < cargas else (2 if k == cargas and not trava else 0))
	elif feito:
		Tablet.visto(b, Vector2(r.size.x - 30, 50), 13)
	elif travado:
		Icones.desenhar(b, "cadeado", Vector2(r.size.x - 30, 44), 0.5, Color(Tablet.TINTA, 0.5), 1.8)
		Tablet.texto(b, Vector2(r.size.x - 70, 78), "nível %d" % int(rc["nivel"]), 13, Color(Tablet.TINTA, 0.5), false, HORIZONTAL_ALIGNMENT_CENTER, 80)
	else:
		Tablet.caixa(b, Rect2(r.size.x - 96, 36, 82, 28), Color(Tablet.LARANJA, 0.18), 14)
		Tablet.texto(b, Vector2(r.size.x - 96, 56), "a fazer", 14, Tablet.LARANJA, true, HORIZONTAL_ALIGNMENT_CENTER, 82)


func _pintar_rastro(b: Control, r: Rect2, foco: bool, sobre: bool, id: String) -> void:
	var fundo := Color(Tablet.TINTA, 0.05 + (0.04 if sobre and not foco else 0.0))
	Tablet.caixa(b, r, fundo, 16, Tablet.LARANJA if foco else Color(0, 0, 0, 0), 3 if foco else 0)
	if id == "":
		var cf := ArmaduraVisual.COR_CHAMA
		b.draw_circle(Vector2(36, 32), 16, cf.darkened(0.08))
		b.draw_arc(Vector2(36, 32), 16, 0, TAU, 24, cf.darkened(0.4), 1.5, true)
		Tablet.texto(b, Vector2(66, 40), "De fábrica", 18, Tablet.TINTA)
		if Rotas.rastro == "":
			Tablet.visto(b, Vector2(r.size.x - 26, 32), 11)
		return
	var bc := Vector2(38, 40)
	if int(Rotas.feitas.get(id, 0)) >= 1:
		var cor: Color = Rotas.CORES[id]
		Tablet.brilho(b, bc, 18, cor, 1.6)
		b.draw_circle(bc, 18, cor.darkened(0.08))
		b.draw_arc(bc, 18, 0, TAU, 24, cor.darkened(0.4), 1.5, true)
		var palavras := String(Rotas.NOMES_COR[id]).split(" ", false, 1)
		Tablet.texto(b, Vector2(66, 38), palavras[0].left(1).to_upper() + palavras[0].substr(1), 17, Tablet.TINTA, true)
		Tablet.texto(b, Vector2(66, 58), palavras[1] if palavras.size() > 1 else "", 13, Color(Tablet.TINTA, 0.6))
		if Rotas.rastro == id:
			Tablet.visto(b, Vector2(r.size.x - 18, 18), 10)
		if int(Rotas.feitas.get(id, 0)) >= 2:
			Icones.desenhar(b, "coroa", Vector2(r.size.x - 18, r.size.y - 18), 0.38, Tablet.LARANJA, 1.6)
	else:
		b.draw_circle(bc, 18, Color(Tablet.TINTA, 0.08))
		Icones.desenhar(b, "aro", bc, 0.55, Color(Tablet.TINTA, 0.35), 1.8)
		Tablet.texto(b, Vector2(66, 38), "?", 20, Color(Tablet.TINTA, 0.3), true)
		Tablet.paragrafo(b, Vector2(66, 60), Rotas.titulo(id), r.size.x - 74, 12, Color(Tablet.TINTA, 0.45), 2)


## Um botão da fileira das partes: a figura da parte e o nome; cheio quando é a parte escolhida.
## O robozinho de traço da linha, com a parte acesa (de frente: o braço D dele fica à esquerda de quem olha).
func _silhueta(c: CanvasItem, ct: Vector2, acesa: String) -> void:
	var apagado := Color(Tablet.TINTA, 0.22)
	var aceso := Color(0.86, 0.42, 0.1)
	var pecas := {"cabeca": Rect2(-9, -26, 18, 14), "tronco": Rect2(-10, -10, 20, 19), "bracoD": Rect2(-17, -9, 6, 18),
		"bracoE": Rect2(11, -9, 6, 18), "pernaD": Rect2(-9, 10, 7, 17), "pernaE": Rect2(2, 10, 7, 17)}
	for p: String in pecas:
		var r: Rect2 = pecas[p]
		Tablet.caixa(c, Rect2(ct + r.position, r.size), aceso if acesa == "inteiro" or acesa == p else apagado, 4 if p == "cabeca" or p == "tronco" else 3)


func _seta(c: CanvasItem, ct: Vector2, dir: float, cor: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([ct + Vector2(7 * dir, 0), ct + Vector2(-5 * dir, -9), ct + Vector2(-5 * dir, 9)]), cor)


## Uma peça num quadrado: a miniatura (apagada se fechada por nível, com o cadeado); a de robô achado fechada é só
## a sombra e a figura do lugar, e aberta ganha a figura pequena no canto.
func _peca_no_quadro(c: CanvasItem, q: Rect2, chave: String, parte: String) -> void:
	var aberto := Corpo.aberto(chave)
	var achado := Corpo.de_achado(chave)
	var tex := Corpo.miniatura(chave, parte)
	if tex:
		var tinta := Color(1, 1, 1, 1.0 if aberto else 0.4)
		if achado and not aberto:
			tinta = Color(0.16, 0.15, 0.14, 0.78)
		c.draw_texture_rect(tex, q, false, tinta)
	var r := q.size.x * 0.24
	if achado:
		var ct := q.get_center() if not aberto else q.position + Vector2(r * 0.6, r * 0.6)
		var rr := r if not aberto else r * 0.6
		c.draw_circle(ct, rr, Color(0.2, 0.55, 0.6, 0.94))
		Icones.desenhar(c, String(Corpo.ACHADOS[chave]["icone"]), ct, rr / 26.0, Color(0.97, 0.95, 0.88), 1.8)
	elif not aberto:
		c.draw_circle(q.get_center(), r, Color(0.85, 0.82, 0.75, 0.94))
		Icones.desenhar(c, "cadeado", q.get_center(), r / 28.0, Tablet.TINTA, 1.8)


## Uma linha da aba Corpo: a figura da parte e o nome pequeno, as setas, a miniatura da peça e o nome do conjunto;
## o visto na peça que está vestida; na linha em foco, um pontinho por peça (quanto ainda falta abrir).
func _pintar_linha(b: Control, r: Rect2, foco: bool, sobre: bool, linha: String) -> void:
	var chave := String(_montagem.get("tronco" if linha == "inteiro" else linha, ""))
	var piscando := _piscar > 0.0 and linha != "inteiro" and not Corpo.aberto(chave) and fmod(_piscar, 0.3) > 0.15
	var borda := Tablet.RUBI if piscando else (Tablet.LARANJA if foco else Color(0, 0, 0, 0))
	var fundo := Color(1.0, 0.72, 0.3, 0.26) if foco else Color(Tablet.TINTA, 0.05 + (0.04 if sobre else 0.0))
	Tablet.caixa(b, r, fundo, 14, borda, 3 if foco or piscando else 0)
	_silhueta(b, Vector2(36, 36), linha)
	Tablet.texto(b, Vector2(0, 76), "Inteiro" if linha == "inteiro" else String(Corpo.NOMES_PARTE[linha]), 12, Color(Tablet.TINTA, 0.75), foco, HORIZONTAL_ALIGNMENT_CENTER, 72)
	var tinta_seta := Tablet.LARANJA if foco else Color(Tablet.TINTA, 0.3)
	_seta(b, Vector2(90, 36), -1.0, tinta_seta)
	_seta(b, Vector2(r.size.x - 20, 36), 1.0, tinta_seta)
	var mini := Rect2(106, 8, 58, 58)
	Tablet.caixa(b, mini, Color(Tablet.TINTA, 0.07), 10)
	if linha == "inteiro":
		var so := _um_so()
		if so != "#":
			var ret := Corpo.retrato(so)
			if ret:
				var tinta := Color(1, 1, 1, 1.0 if Corpo.aberto(so) else 0.4)
				if Corpo.de_achado(so) and not Corpo.aberto(so):
					tinta = Color(0.16, 0.15, 0.14, 0.78)
				b.draw_texture_rect(ret, mini.grow(-2), false, tinta)
		else:
			Icones.desenhar(b, "corpo", mini.get_center(), 1.25, Tablet.TINTA, 2.2)
		if Corpo.novos().has(so):
			_estrela(b, mini.end - Vector2(4, 54), 10.0, Tablet.LARANJA_V)
		elif not Corpo.novos().is_empty():
			b.draw_circle(Vector2(r.size.x - 10, 10), 7.0, Color(1, 1, 1, 0.95))
			b.draw_circle(Vector2(r.size.x - 10, 10), 5.0, Tablet.LARANJA_V)
		Tablet.texto(b, Vector2(176, 34), Corpo.curto(so) if so != "#" else "Misturado", 19, Tablet.TINTA, foco)
		Tablet.texto(b, Vector2(176, 56), "troca as seis de uma vez", 13, Color(Tablet.TINTA, 0.6))
		return
	var aberto := Corpo.aberto(chave)
	_peca_no_quadro(b, mini.grow(-3), chave, linha)
	if Corpo.novos().has(chave):
		_estrela(b, mini.end - Vector2(4, 54), 10.0, Tablet.LARANJA_V)
	var nome := Corpo.curto(chave)
	Tablet.texto(b, Vector2(176, 34), nome, 19 if nome.length() <= 10 else 16, Tablet.TINTA if aberto else Color(Tablet.TINTA, 0.5), foco)
	if not aberto:
		if Corpo.de_achado(chave):
			Tablet.texto(b, Vector2(176, 56), String(Corpo.ACHADOS[chave]["lugar"]), 13, Color(0.15, 0.45, 0.5), true)
		else:
			Tablet.texto(b, Vector2(176, 56), "nível %d" % Corpo.nivel(chave), 14, Tablet.RUBI, true)
	elif chave == String(Corpo.vestido.get(linha, "")):
		Tablet.visto(b, Vector2(r.size.x - 48, 28), 9)
	if foco:
		_pontinhos(b, r, chave)


## Um pontinho por peça: cheio aberto, vazio fechado, verde-água de robô achado; o grande e laranja é a da vez.
func _pontinhos(c: CanvasItem, r: Rect2, chave: String) -> void:
	var ordem := Corpo.ordem()
	var x0 := 108.0
	var passo := (r.size.x - 40.0 - x0) / float(ordem.size() - 1)
	for i in ordem.size():
		var k: String = ordem[i]
		var p := Vector2(x0 + i * passo, 76)
		var cor := Color(0.2, 0.55, 0.6) if Corpo.de_achado(k) else Tablet.TINTA
		if k == chave:
			c.draw_circle(p, 6.5, Tablet.LARANJA_V)
		elif Corpo.novos().has(k):
			_estrela(c, p, 6.5, Tablet.LARANJA_V)
		elif Corpo.aberto(k):
			c.draw_circle(p, 3.6, Color(cor, 0.8))
		else:
			c.draw_arc(p, 3.6, 0, TAU, 16, Color(cor, 0.55), 1.4, true)


# ------------------------------------------------------------------ o tablet inteiro

func _pintar(c: Control, telas: Array) -> void:
	var L: Rect2 = telas[0]
	var R: Rect2 = telas[1]
	# a barra de cima: o nome à esquerda; o nível, a experiência e a bateria à direita
	c.draw_circle(Vector2(L.position.x + 26, L.position.y + 21), 6, Tablet.LARANJA_V)
	Tablet.texto(c, Vector2(L.position.x + 44, L.position.y + 27), "Oficina", 15, Tablet.TINTA, true)
	Tablet.texto(c, Vector2(R.end.x - 150, R.position.y + 27), "nível %d" % Arsenal.nivel(), 15, Tablet.TINTA, true)
	var bx := Arsenal.barra()
	Tablet.anel(c, Vector2(R.end.x - 78, R.position.y + 21), 9, float(bx.x) / float(bx.y))
	Tablet.bateria(c, Vector2(R.end.x - 56, R.position.y + 14))
	# o trilho das pílulas (as pílulas são botões, para o mouse)
	Tablet.caixa(c, Rect2(L.position.x + 14, L.position.y + 54, L.size.x - 28, 46), Color(Tablet.TINTA, 0.07), 23)
	match aba:
		0:
			_esq_pecas(c, L)
			_dir_peca(c, R)
		1:
			Tablet.caixa(c, Rect2(L.position.x + 14, L.end.y - 82, L.size.x - 28, 56), Color(Tablet.TINTA, 0.07), 16)
			Tablet.bolso(c, Vector2(L.position.x + 44, L.end.y - 46), 122.0, 22)
			_dir_arma(c, R)
		2:
			_esq_defesa(c, L)
			_dir_defesa(c, R)
		3:
			_dir_rastro(c, R)
		4:
			_dir_corpo(c, R)
	if aba == 4:
		_rodape_corpo(c, R)
	else:
		Tablet.rodape(c, R, [["o", "sair"], ["l1", "{@r1} trocar de aba"]])


## O rodapé da aba Corpo: sair, trocar de aba e o △ com a figura do que ele faz (ver tudo ou de perto).
func _rodape_corpo(c: Control, R: Rect2) -> void:
	var yy := R.end.y - 34.0
	var x := R.position.x + 24.0
	for it: Array in [["o", "sair"], ["l1", "{@r1} aba"]]:
		Tablet.botao(c, it[0], Vector2(x + 12, yy), 24)
		x += 42.0 + Tablet.com_botoes(c, Vector2(x + 30, yy + 6), it[1], 15, Color(Tablet.TINTA, 0.7)) + 18.0
	if _linha == "inteiro":
		return
	Tablet.botao(c, "tri", Vector2(x + 12, yy), 24)
	var fig := Vector2(x + 42, yy)
	if _perto:
		# o robô entre quatro cantos de enquadrar: ver tudo
		Icones.desenhar(c, "corpo", fig, 0.62, Tablet.TINTA, 1.6)
		for k in 4:
			var sx := -1.0 if k % 2 == 0 else 1.0
			var sy := -1.0 if k < 2 else 1.0
			var p := fig + Vector2(sx * 12, sy * 12)
			c.draw_polyline(PackedVector2Array([p + Vector2(0, -sy * 5), p, p + Vector2(-sx * 5, 0)]), Tablet.TINTA, 1.6, true)
	else:
		# a lupa: de perto
		c.draw_arc(fig + Vector2(-2, -2), 7, 0, TAU, 20, Tablet.TINTA, 1.8, true)
		c.draw_line(fig + Vector2(3, 3), fig + Vector2(9, 9), Tablet.TINTA, 2.4, true)
	Tablet.texto(c, Vector2(x + 60, yy + 6), "ver tudo" if _perto else "de perto", 15, Color(Tablet.TINTA, 0.7))


func _esq_pecas(c: Control, L: Rect2) -> void:
	var achadas := 0
	for nome: String in Melhorias.NOMES:
		if Melhorias.achadas.has(nome) or Melhorias.instaladas.has(nome):
			achadas += 1
	var y0 := L.position.y + 116.0
	for nome: String in Melhorias.PREMIOS:
		if Melhorias.achadas.has(nome) or Melhorias.instaladas.has(nome):
			var yp := y0 + 4 * 100.0 + 18
			Icones.desenhar(c, "coroa", Vector2(L.position.x + 28, yp - 4), 0.45, Tablet.LARANJA, 1.8)
			Tablet.texto(c, Vector2(L.position.x + 44, yp + 2), "prêmios", 15, Tablet.LARANJA, true)
			break
	var by := L.end.y - 82.0
	Tablet.caixa(c, Rect2(L.position.x + 14, by, L.size.x - 28, 56), Color(Tablet.TINTA, 0.07), 16)
	Icones.desenhar(c, "peca", Vector2(L.position.x + 42, by + 28), 0.6, Tablet.TINTA, 2.0)
	Tablet.texto(c, Vector2(L.position.x + 64, by + 35), "%d de %d" % [achadas, Melhorias.NOMES.size()], 20, Tablet.TINTA, true)
	for k in Melhorias.NOMES.size():
		Tablet.caixa(c, Rect2(L.position.x + 160 + k * 23, by + 22, 18, 12), Tablet.LARANJA if k < achadas else Color(Tablet.TINTA, 0.15), 4)


func _esq_defesa(c: Control, L: Rect2) -> void:
	# o robô agora: os corações, o escudo e a mira
	var by := L.position.y + 470.0
	var tinta_viva := Color(0.08, 0.58, 0.55)
	Tablet.caixa(c, Rect2(L.position.x + 14, by, L.size.x - 28, 220), Color(Tablet.TINTA, 0.06), 18)
	Tablet.texto(c, Vector2(L.position.x + 34, by + 36), "Seu robô agora", 18, Tablet.TINTA, true)
	var golpes := Arsenal.golpes_pane()
	for k in golpes:
		Tablet.coracao(c, Vector2(L.position.x + 50 + k * 42, by + 82), 15, Color(0.92, 0.32, 0.38), true)
	var n_cor := golpes
	if not Arsenal.fabricados.has("vida"):
		Tablet.coracao(c, Vector2(L.position.x + 50 + golpes * 42, by + 82), 15, Color(Tablet.TINTA, 0.25), false)
		n_cor += 1
	Tablet.texto(c, Vector2(L.position.x + 34 + n_cor * 42 + 8, by + 90), "acertos", 15, Color(Tablet.TINTA, 0.6))
	var tem_escudo := Arsenal.fabricados.has("escudo")
	var cargas := Arsenal.escudo_cargas() if tem_escudo else 0
	for k in Arsenal.ESCUDO_CARGAS:
		Icones.desenhar(c, "escudo", Vector2(L.position.x + 50 + k * 42, by + 138), 0.8, tinta_viva if k < cargas else Color(Tablet.TINTA, 0.22), 2.2)
	Tablet.texto(c, Vector2(L.position.x + 34 + Arsenal.ESCUDO_CARGAS * 42 + 8, by + 146), "escudo" if tem_escudo else "sem escudo", 15, Color(Tablet.TINTA, 0.6))
	var tem_mira := Arsenal.fabricados.has("mira")
	Icones.desenhar(c, "mira", Vector2(L.position.x + 50, by + 192), 0.8, tinta_viva if tem_mira else Color(Tablet.TINTA, 0.22), 2.2)
	Tablet.texto(c, Vector2(L.position.x + 76, by + 200), "mira que aponta sozinha" if tem_mira else "sem mira assistida", 15, Color(Tablet.TINTA, 0.6))


## A trilha de três lâmpadas da tela da direita, com o que cada uma dá embaixo.
## `rotulos` é [[figura, texto], ...]; `proxima` -1 quando nenhuma é a próxima; `trava` põe o cadeado nela.
func _trilha(c: Control, R: Rect2, ys: float, acesas: int, proxima: int, trava: bool, rotulos: Array) -> void:
	var xs := [R.position.x + 74, R.position.x + 209, R.position.x + 344]
	for k in 2:
		var x0: float = xs[k] + 26
		while x0 < xs[k + 1] - 26:
			c.draw_line(Vector2(x0, ys), Vector2(x0 + 6, ys), Color(Tablet.TINTA, 0.6 if k < acesas else 0.3), 2.0)
			x0 += 12.0
	for k in 3:
		var travada := trava and k == proxima
		Tablet.lampada(c, Vector2(xs[k], ys), 20.0, 1 if k < acesas else (2 if k == proxima and not travada else 0))
		if travada:
			c.draw_circle(Vector2(xs[k] + 18, ys - 18), 12, Color(0.85, 0.82, 0.75))
			Icones.desenhar(c, "cadeado", Vector2(xs[k] + 18, ys - 18), 0.38, Tablet.TINTA, 1.6)
		var tr: Array = rotulos[k]
		var vivo := Color(Tablet.TINTA, 1.0 if k <= maxi(acesas, proxima) else 0.5)
		Tablet.ganho(c, tr[0], Vector2(xs[k] - 20, ys + 60), vivo)
		Tablet.texto(c, Vector2(xs[k] - 4, ys + 66), tr[1], 16, vivo, k == proxima)


## O pé da tela da direita: o custo em carimbos, o que falta e o botão de segurar (ou o selo de pronto).
func _custo_e_botao(c: Control, R: Rect2, titulo: String, custo: Dictionary, faz: String, nivel_txt: String) -> void:
	Tablet.texto(c, Vector2(R.position.x + 26, R.position.y + 480), titulo, 19, Tablet.TINTA, true)
	Tablet.carimbos(c, R.position.x + 64, R.position.y + 540, custo)
	var ft := Tablet.falta(custo)
	if Arsenal.nivel() < int(custo.get("nivel", 1)):
		ft = [nivel_txt % int(custo["nivel"]), Color(Tablet.TINTA, 0.6), false]
	Tablet.texto(c, Vector2(R.position.x + 26, R.position.y + 612), ft[0], 17, ft[1], true)
	_segurar(c, R, ft[2], "segure para " + faz if ft[2] else "ainda não dá")


func _segurar(c: Control, R: Rect2, pode: bool, s: String) -> void:
	var centro := Vector2(R.position.x + 70, R.position.y + 680)
	if fase == Fase.INSTALANDO:
		Tablet.segurar(c, centro, true, _fazendo, clampf(_t / T_INSTALAR, 0.0, 1.0))
		return
	if _aviso_t > 0.0:
		if _aviso_cor == Tablet.OK:
			Tablet.feito(c, centro, _aviso)
		else:
			Tablet.segurar(c, centro, false, _aviso)
		return
	Tablet.segurar(c, centro, pode, s, _segura)


func _dir_arma(c: Control, R: Rect2) -> void:
	var n := _escolhida
	if not ARMAS.has(n):
		return
	var feita := _de_degrau(n)
	var dg := Arsenal.degrau(n)
	Tablet.texto(c, Vector2(R.position.x + 26, R.position.y + 86), _titulo_de(n), 32, Tablet.TINTA, true)
	var rotulo := "a fazer" if not feita else ("no máximo" if dg >= Arsenal.DEGRAUS else "%d de 3 luzes acesas" % dg)
	if feita and n == "misseis":
		rotulo = "%d mísseis no ombro" % Arsenal.misseis_max()
	elif feita and n == "granadas":
		rotulo = "%d granadas" % Arsenal.granadas_max()
	Tablet.planta(c, Rect2(R.position.x + 22, R.position.y + 104, R.size.x - 44, 200), n, rotulo, false, 5.0)
	var rotulos: Array = []
	for k in 3:
		rotulos.append(["maquina", "5 alvos"] if n == "misseis" and k == 2 else TRILHA[n])
	var trava := feita and Arsenal.falta_degrau(n).begins_with("pede")
	_trilha(c, R, R.position.y + 360.0, dg, dg if feita and dg < Arsenal.DEGRAUS else -1, trava, rotulos)
	if not feita:
		_custo_e_botao(c, R, "Para fabricar", _custo_receita(n), "fabricar", "chega no nível %d para fazer")
		return
	if dg >= Arsenal.DEGRAUS:
		var cc := Vector2(R.get_center().x, R.position.y + 548)
		Tablet.brilho(c, cc, 44, Color(1.0, 0.8, 0.3), 1.6)
		c.draw_circle(cc, 46, Color(1.0, 0.84, 0.42))
		c.draw_arc(cc, 46, 0, TAU, 40, Color(0.8, 0.5, 0.12), 3.0, true)
		Icones.desenhar(c, "coroa", cc, 1.6, Color(0.55, 0.32, 0.08), 3.0)
		Tablet.texto(c, Vector2(R.position.x, R.position.y + 634), "Todas as luzes acesas!", 24, Color(0.22, 0.52, 0.3), true, HORIZONTAL_ALIGNMENT_CENTER, R.size.x)
		var ganho := "+%d%% de dano desde a fábrica" % roundi(float(Arsenal.MELHORA[n].get("dano", 0.0)) * Arsenal.DEGRAUS * 100.0)
		if n == "misseis":
			ganho = "%d mísseis, trava %d máquinas" % [Arsenal.misseis_max(), Arsenal.alvos_misseis()]
		elif n == "granadas":
			ganho = "%d granadas, estouro maior" % Arsenal.granadas_max()
		var w := Tablet.largura(ganho, 16, true) + 70
		Tablet.caixa(c, Rect2(R.get_center().x - w * 0.5, R.position.y + 660, w, 48), Color(Tablet.TINTA, 0.07), 24)
		Tablet.ganho(c, TRILHA[n][0], Vector2(R.get_center().x - w * 0.5 + 34, R.position.y + 684), Tablet.TINTA)
		Tablet.texto(c, Vector2(R.get_center().x - w * 0.5 + 56, R.position.y + 690), ganho, 16, Tablet.TINTA, true)
		return
	_custo_e_botao(c, R, "Para acender a %dª luz" % (dg + 1), Arsenal.custo_degrau(n), "acender", "chega no nível %d para acender")


func _dir_defesa(c: Control, R: Rect2) -> void:
	var n := _escolhida
	if not DEFESA.has(n):
		return
	var rc: Dictionary = Arsenal.RECEITAS[n]
	var feito := Arsenal.fabricados.has(n)
	Tablet.texto(c, Vector2(R.position.x + 26, R.position.y + 86), String(rc["titulo"]), 30, Tablet.TINTA, true)
	Tablet.planta(c, Rect2(R.position.x + 22, R.position.y + 104, R.size.x - 44, 200), n, "defesa")
	if n == "escudo":
		# o escudo em três luzes (pedido do usuário, 2026-11-21): 1, 2 e 3 acertos; a primeira acende ao fabricar
		var acesas := _acesas("escudo")
		var cheio := acesas >= Arsenal.ESCUDO_CARGAS
		var trava := feito and Arsenal.falta_degrau("escudo").begins_with("pede")
		_trilha(c, R, R.position.y + 360.0, acesas, -1 if cheio else acesas, trava, [["escudo", "1 acerto"], ["escudo", "2 acertos"], ["escudo", "3 acertos"]])
		if not feito:
			_custo_e_botao(c, R, "Para fabricar", _custo_receita(n), "fabricar", "chega no nível %d para fazer")
		elif not cheio:
			_custo_e_botao(c, R, "Para acender a %dª luz" % (acesas + 1), Arsenal.custo_degrau("escudo"), "acender", "chega no nível %d para acender")
		else:
			Tablet.ficha(c, Vector2(R.position.x + 22, R.position.y + 470), 230, func(p: Vector2) -> void: Tablet.relogio(c, p, Tablet.TINTA), "volta em %d s" % int(Arsenal.ESCUDO_RECARGA))
			_segurar(c, R, false, "")
			if _aviso_t <= 0.0 and fase != Fase.INSTALANDO:
				Tablet.feito(c, Vector2(R.position.x + 70, R.position.y + 680), "Escudo completo")
		return
	Tablet.paragrafo(c, Vector2(R.position.x + 26, R.position.y + 340), String(rc["efeito"]), R.size.x - 52, 18, Tablet.TINTA, 3)
	var yi := R.position.y + 400.0
	match n:
		"vida":
			Tablet.ficha(c, Vector2(R.position.x + 22, yi), 200, func(p: Vector2) -> void: Tablet.coracao(c, p, 11, Color(0.92, 0.32, 0.38), true), "+1 acerto")
		"mira":
			Tablet.ficha(c, Vector2(R.position.x + 22, yi), 230, func(p: Vector2) -> void: Icones.desenhar(c, "mira", p, 0.6, Tablet.TINTA, 2.0), "trava na máquina")
	if feito:
		if _aviso_t > 0.0 or fase == Fase.INSTALANDO:
			_segurar(c, R, false, "")
		else:
			Tablet.feito(c, Vector2(R.position.x + 70, R.position.y + 680), "Fabricado")
	else:
		_custo_e_botao(c, R, "Para fabricar", _custo_receita(n), "fabricar", "chega no nível %d para fazer")


func _dir_peca(c: Control, R: Rect2) -> void:
	var n := _escolhida
	if n == "" or not CURTO.has(n):
		return
	var tem := Melhorias.instaladas.has(n)
	var achou := Melhorias.achadas.has(n) and not tem
	var conhece := tem or achou
	var titulo := String(Melhorias.TITULOS[n]) if conhece else "Peça não encontrada"
	Tablet.texto(c, Vector2(R.position.x + 26, R.position.y + 86), titulo, 30, Tablet.TINTA, true)
	var ic := "radiador" if n == "radiador2" else n
	Tablet.planta(c, Rect2(R.position.x + 22, R.position.y + 104, R.size.x - 44, 200), ic, "prêmio" if Melhorias.PREMIOS.has(n) else "peça da ilha", not conhece)
	var ef := "Está em algum lugar da ilha."
	if conhece:
		ef = String(Melhorias.EFEITOS[n])
		ef = ef.left(1).to_upper() + ef.substr(1) + "."
	Tablet.paragrafo(c, Vector2(R.position.x + 26, R.position.y + 350), ef, R.size.x - 52, 20, Tablet.TINTA, 3)
	if conhece:
		var cy := R.position.y + 480.0
		Tablet.caixa(c, Rect2(R.position.x + 22, cy - 40, R.size.x - 44, 80), Color(Tablet.TINTA, 0.06), 16)
		Icones.desenhar(c, ic, Vector2(R.position.x + 62, cy), 0.8, Tablet.TINTA, 2.0)
		Tablet.texto(c, Vector2(R.position.x + 96, cy - 4), "com o robô" if achou else "no robô", 17, Tablet.TINTA, true)
		var onde := "segure X para instalar agora" if achou else ("veja nas costas dele" if n in DE_COSTAS else "veja nele, ao lado")
		Tablet.texto(c, Vector2(R.position.x + 96, cy + 18), onde, 15, Color(Tablet.TINTA, 0.6))
	if tem:
		if _aviso_t > 0.0:
			_segurar(c, R, false, "")
		else:
			Tablet.feito(c, Vector2(R.position.x + 70, R.position.y + 680), "Instalada")
	elif achou:
		_segurar(c, R, true, "segure para instalar")
	elif Melhorias.instaladas.has("antena"):
		Tablet.caixa(c, Rect2(R.position.x + 22, R.position.y + 440, R.size.x - 44, 80), Color(Tablet.TINTA, 0.06), 16)
		Icones.desenhar(c, "antena", Vector2(R.position.x + 62, R.position.y + 480), 0.8, Tablet.TINTA, 2.0)
		Tablet.paragrafo(c, Vector2(R.position.x + 96, R.position.y + 474), "a antena mostra na bússola quando estiver perto", R.size.x - 130, 16, Tablet.TINTA, 2)


func _dir_rastro(c: Control, R: Rect2) -> void:
	if not _escolhida.begins_with("rastro_"):
		return
	var sel := _escolhida.substr(7)
	var ganha := sel == "" or int(Rotas.feitas.get(sel, 0)) >= 1
	var nome := "De fábrica"
	if sel != "":
		var cn := String(Rotas.NOMES_COR[sel])
		nome = (cn.left(1).to_upper() + cn.substr(1)) if ganha else "Cor não ganha"
	Tablet.texto(c, Vector2(R.position.x + 26, R.position.y + 86), nome, 30, Tablet.TINTA, true)
	# o céu de noite com o robô de costas subindo, o fogo dos pés e das costas na cor
	var ceu := Rect2(R.position.x + 22, R.position.y + 104, R.size.x - 44, 240)
	Tablet.caixa(c, ceu, Color(0.07, 0.1, 0.22), 14)
	for k in 8:
		c.draw_rect(Rect2(ceu.position.x, ceu.end.y - 16 - k * 14, ceu.size.x, 14), Color(0.35, 0.2, 0.45, 0.03 * (8 - k)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 40:
		c.draw_circle(Vector2(rng.randf_range(ceu.position.x + 10, ceu.end.x - 10), rng.randf_range(ceu.position.y + 10, ceu.end.y - 40)), rng.randf_range(0.6, 1.6), Color(1, 1, 1, rng.randf_range(0.3, 0.8)))
	c.draw_colored_polygon(PackedVector2Array([Vector2(ceu.position.x, ceu.end.y), Vector2(ceu.position.x, ceu.end.y - 30), Vector2(ceu.position.x + 90, ceu.end.y - 52),
		Vector2(ceu.position.x + 180, ceu.end.y - 34), Vector2(ceu.position.x + 280, ceu.end.y - 60), Vector2(ceu.end.x, ceu.end.y - 38), Vector2(ceu.end.x, ceu.end.y)]), Color(0.04, 0.06, 0.12))
	if ganha:
		var cor: Color = Rotas.CORES.get(sel, ArmaduraVisual.COR_CHAMA)
		_robo_subindo(c, Vector2(ceu.get_center().x, ceu.position.y + 24), cor)
	else:
		Tablet.texto(c, ceu.position + Vector2(0, 140), "?", 80, Color(1, 1, 1, 0.3), true, HORIZONTAL_ALIGNMENT_CENTER, ceu.size.x)
	Tablet.cantos(c, ceu, 14, Tablet.TELA)
	if sel != "":
		var yi := R.position.y + 380.0
		Tablet.caixa(c, Rect2(R.position.x + 22, yi, R.size.x - 44, 80), Color(Tablet.TINTA, 0.06), 16)
		Icones.desenhar(c, "aro", Vector2(R.position.x + 62, yi + 40), 0.8, Tablet.TINTA, 2.0)
		Tablet.texto(c, Vector2(R.position.x + 96, yi + 34), "ganho na rota" if ganha else "faça a rota sem pousar", 15, Color(Tablet.TINTA, 0.6))
		Tablet.texto(c, Vector2(R.position.x + 96, yi + 58), Rotas.titulo(sel), 18, Tablet.TINTA, true)
	var texto := "O fogo laranja que veio de fábrica, nos jatos dos pés e das costas." if sel == "" else "O fogo dos jatos dos pés e das costas acende nesta cor."
	Tablet.paragrafo(c, Vector2(R.position.x + 26, R.position.y + 500), texto, R.size.x - 52, 17, Color(Tablet.TINTA, 0.75), 3)
	if Rotas.rastro == sel and _aviso_t <= 0.0:
		Tablet.feito(c, Vector2(R.position.x + 70, R.position.y + 680), "Em uso")
	else:
		_segurar(c, R, ganha and Rotas.rastro != sel, "segure para usar" if ganha else "ainda não ganho")


## O robozinho de costas na subida, de traço simples: os jatos dos pés e das costas acesos na cor.
func _robo_subindo(c: CanvasItem, topo: Vector2, cor: Color) -> void:
	var x := topo.x
	var y := topo.y
	var corpo := Color(0.86, 0.9, 0.95)
	var sombra := Color(0.55, 0.62, 0.72)
	var escuro := Color(0.3, 0.35, 0.43)
	Tablet.caixa(c, Rect2(x - 38, y + 44, 11, 38), sombra, 5)  # braços
	Tablet.caixa(c, Rect2(x + 27, y + 44, 11, 38), sombra, 5)
	Tablet.caixa(c, Rect2(x - 20, y + 90, 16, 40), sombra, 5)  # pernas
	Tablet.caixa(c, Rect2(x + 4, y + 90, 16, 40), sombra, 5)
	Tablet.caixa(c, Rect2(x - 23, y + 126, 21, 11), escuro, 4)  # pés
	Tablet.caixa(c, Rect2(x + 2, y + 126, 21, 11), escuro, 4)
	Tablet.caixa(c, Rect2(x - 26, y + 38, 52, 52), corpo, 10)  # tronco
	Tablet.caixa(c, Rect2(x - 22, y, 44, 36), corpo, 12)  # cabeça
	Tablet.caixa(c, Rect2(x - 19, y + 46, 13, 24), escuro, 4)  # bocais das costas
	Tablet.caixa(c, Rect2(x + 6, y + 46, 13, 24), escuro, 4)
	for bx in [-12.5, 12.5]:
		_fogo(c, Vector2(x + bx, y + 70), 11.0, 30.0, cor)
		_fogo(c, Vector2(x + bx, y + 137), 17.0, 62.0, cor)


func _fogo(c: CanvasItem, base: Vector2, larg: float, comp: float, cor: Color) -> void:
	Tablet.brilho(c, base + Vector2(0, comp * 0.3), larg * 0.9, cor, 1.3)
	c.draw_colored_polygon(PackedVector2Array([base + Vector2(-larg * 0.5, 0), base + Vector2(larg * 0.5, 0), base + Vector2(0, comp)]), Color(cor, 0.95))
	c.draw_colored_polygon(PackedVector2Array([base + Vector2(-larg * 0.22, 0), base + Vector2(larg * 0.22, 0), base + Vector2(0, comp * 0.45)]), Color(1, 1, 1, 0.85))


## O conjunto em foco: o retrato grande, as quatro partes (as que mudam em destaque) e o botão de vestir.
## Onde fica cada peça na planta da direita (coordenadas da casca).
func _quadro_planta(parte: String) -> Rect2:
	var R := Tablet.DIR
	var q := Rect2(R.position.x + 22, R.position.y + 104, R.size.x - 44, 386)
	var cx := q.get_center().x
	var t := 112.0
	var y1 := q.position.y + 14.0
	var y2 := y1 + t + 12.0
	match parte:
		"cabeca":
			return Rect2(cx - t * 0.5, y1, t, t)
		"tronco":
			return Rect2(cx - t * 0.5, y2, t, t)
		"bracoD":
			return Rect2(cx - t * 1.5 - 12.0, y2, t, t)
		"bracoE":
			return Rect2(cx + t * 0.5 + 12.0, y2, t, t)
		"pernaD":
			return Rect2(cx - t - 6.0, y2 + t + 12.0, t, t)
	return Rect2(cx + 6.0, y2 + t + 12.0, t, t)


## A planta da montagem: as seis peças no formato do corpo (a da linha em foco com a borda laranja, as que mudam
## com o brilhinho, as fechadas com o cadeado), quantas mudam e o vestir, um só para tudo.
func _dir_corpo(c: Control, R: Rect2) -> void:
	var so := _um_so()
	Tablet.texto(c, Vector2(R.position.x + 26, R.position.y + 86), Corpo.nome(so) if so != "#" else "Misturado", 30, Tablet.TINTA, true)
	var q := Rect2(R.position.x + 22, R.position.y + 104, R.size.x - 44, 386)
	Tablet.caixa(c, q, Color(Tablet.TINTA, 0.07), 16)
	var mudam := 0
	var fechadas := 0
	for parte: String in Corpo.PARTES:
		var chave := String(_montagem.get(parte, ""))
		var muda := chave != String(Corpo.vestido.get(parte, ""))
		if muda:
			mudam += 1
		if not Corpo.aberto(chave):
			fechadas += 1
		var r := _quadro_planta(parte)
		Tablet.caixa(c, r, Color(Tablet.LARANJA, 0.2) if muda else Color(Tablet.TINTA, 0.06), 14, Tablet.LARANJA if _linha == parte else Color(0, 0, 0, 0), 3)
		_peca_no_quadro(c, r.grow(-6), chave, parte)
		if muda and Corpo.aberto(chave):
			Tablet.brilhinho(c, r.position + Vector2(r.size.x - 13, 13), 8, Tablet.LARANJA)
	var yl := q.end.y + 34.0
	var x := R.position.x + 38.0
	if mudam > 0:
		Tablet.brilhinho(c, Vector2(x, yl - 6), 9, Tablet.LARANJA)
		Tablet.texto(c, Vector2(x + 16, yl), "%d muda%s" % [mudam, "" if mudam == 1 else "m"], 17, Tablet.TINTA, true)
		x += 150.0
	if fechadas > 0:
		c.draw_circle(Vector2(x, yl - 6), 12, Color(0.85, 0.82, 0.75, 0.94))
		Icones.desenhar(c, "cadeado", Vector2(x, yl - 6), 0.42, Tablet.TINTA, 1.6)
		Tablet.texto(c, Vector2(x + 18, yl), "%d fechada%s" % [fechadas, "" if fechadas == 1 else "s"], 17, Tablet.TINTA, true)
	Tablet.texto(c, Vector2(R.position.x + 26, R.position.y + 612), "só muda o jeito: anda, voa e luta igual", 15, Color(Tablet.TINTA, 0.6))
	var centro := Vector2(R.position.x + 70, R.position.y + 680)
	var fechada := _fechada()
	if _montagem == Corpo.vestido and _aviso_t <= 0.0 and fase != Fase.INSTALANDO:
		Tablet.feito(c, centro, "Em uso")
	elif fechada != "" and _aviso_t <= 0.0 and fase != Fase.INSTALANDO:
		if Corpo.de_achado(fechada):
			Tablet.segurar(c, centro, false, "acorde o robô")
			Tablet.texto(c, Vector2(centro.x + 52, centro.y + 30), String(Corpo.ACHADOS[fechada]["lugar"]), 15, Color(Tablet.TINTA, 0.5), true)
		else:
			Tablet.segurar(c, centro, false, "abre no nível %d" % Corpo.nivel(fechada))
	else:
		_segurar(c, R, _pode("linha_" + _linha), "segure para vestir")


## O corpo que a montagem pede no robô: as peças de robô achado ainda fechadas ficam como estão (surpresa).
func _pedido_corpo() -> Dictionary:
	var pedido := _montagem.duplicate() if not _montagem.is_empty() else Corpo.vestido.duplicate()
	for parte: String in Corpo.PARTES:
		var k := String(pedido.get(parte, ""))
		if Corpo.de_achado(k) and not Corpo.aberto(k):
			pedido[parte] = Corpo.vestido.get(parte, "")
	return pedido


## O robô mostra a montagem (prévia), de frente como em todos (2026-11-23); nas linhas do lado E ele vira um pouco
## para o outro lado, para aquele lado aparecer.
func _previa_corpo() -> void:
	var pedido := _pedido_corpo()
	if armadura.visual.corpo != pedido:
		armadura.visual.vestir_corpo(pedido)
	var e := _eixo()
	armadura.visual.yaw_forcado = atan2(-e.x, -e.z) + (0.35 if _linha.ends_with("E") else -0.35)
	_lista.queue_redraw()
	for b in _lista.get_children():
		(b as Control).queue_redraw()


## Na aba Jatos o robô fica de costas, sobe um pouco na pose da subida (a de segurar o X) e acende os jatos dos pés e
## das costas na cor em foco (doc §147). A cor ainda não ganha fica escondida ("?"): os jatos ficam na de fábrica.
func _vitrine_rastro(id: String) -> void:
	_virar("bocais")
	armadura.visual.jatos_vitrine = 1.2  # o fogo da decolagem
	armadura.visual.cor_vitrine = id if int(Rotas.feitas.get(id, 0)) >= 1 else ""
	if _berco():
		_berco().pairar(true)


## Fora da aba Jatos o robô volta ao estrado e os jatos apagam.
func _rastro_de_volta() -> void:
	if armadura and armadura.visual:
		armadura.visual.jatos_vitrine = 0.0
		armadura.visual.cor_vitrine = ""
	if _berco():
		_berco().pairar(false)


## Fora da aba Corpo o robô volta ao corpo que está vestido de verdade.
func _corpo_de_volta() -> void:
	if armadura and armadura.visual and armadura.visual.corpo != Corpo.vestido:
		armadura.visual.vestir_corpo(Corpo.vestido)


## A peça (ou arma) em foco aparece no corpo do robô, virado para o lado em que ela se vê.
func _escolher(nome: String) -> void:
	_escolhida = nome
	_segura = 0.0
	if nome.begins_with("linha_"):
		var nova := nome.substr(6)
		if nova != _linha:
			_perto = true  # outra parte: a câmera volta para perto (o pedido é ver a peça que está sendo trocada)
		_linha = nova
		_previa_corpo()
		return
	_corpo_de_volta()
	if nome.begins_with("rastro_"):
		armadura.visual.vestir_melhorias()
		_vitrine_rastro(nome.substr(7))
		return
	_rastro_de_volta()
	if DE_FABRICA.has(nome):
		armadura.visual.vestir_melhorias()
		_virar("antena")
		return
	if Arsenal.RECEITAS.has(nome):
		var previa_de := {"mira": "mira", "vida": "vida", "escudo": "escudo", "misseis": "lanca_misseis", "granadas": "lanca_granadas", "rajada": "arma_rajada", "canhao": "arma_canhao", "precisao": "arma_precisao", "duplo": "arma_duplo"}
		armadura.visual.vestir_melhorias([previa_de[nome]] if previa_de.has(nome) else [])
		armadura.visual.previa = true
		_virar("antena")
		return
	armadura.visual.vestir_melhorias([nome] if Melhorias.achadas.has(nome) else [])
	armadura.visual.previa = true
	_virar(nome)


## Um conjunto novo em foco na montagem por `VER` segundos deixa de ser novo (a estrelinha e os pontinhos somem).
func _ver_novo(delta: float) -> void:
	var k := _um_so() if _linha == "inteiro" else String(_montagem.get(_linha, ""))
	if not Corpo.novos().has(k):
		_visto_t = 0.0
		return
	_visto_t += delta
	if _visto_t < VER:
		return
	_visto_t = 0.0
	Corpo.ver(k)
	_ponto_corpo()
	for b in _lista.get_children():
		(b as Control).queue_redraw()


func _virar(nome: String) -> void:
	var e := _eixo()
	var frente := atan2(-e.x, -e.z)  # de frente para a boca
	armadura.visual.yaw_forcado = frente + (PI * 0.82 if nome in DE_COSTAS else -0.35)


## Segurar X (ou o botão redondo, no mouse) enche o anel; cheio, faz.
func _process(delta: float) -> void:
	_aviso_t = maxf(0.0, _aviso_t - delta)
	_piscar = maxf(0.0, _piscar - delta)
	if fase != Fase.ABERTA or not _tela.visible:
		_segura = 0.0
		return
	if aba == 4 and _escolhida.begins_with("linha_"):
		_repetir_seta(delta)
		_ver_novo(delta)
		if Input.is_action_just_pressed("ui_accept") and _fechada() != "":
			_piscar = 0.9  # a linha da peça fechada pisca
	var segurando := Input.is_action_pressed("ui_accept") or _mouse_segura
	if _soltar:
		_segura = 0.0
		if not segurando:
			_soltar = false
		return
	if segurando and _pode(_escolhida):
		_segura += delta / T_SEGURAR
		if _segura >= 1.0:
			_segura = 0.0
			_soltar = true
			instalar(_escolhida)
	else:
		_segura = maxf(0.0, _segura - delta * 4.0)
	# o foco nunca fica perdido (um clique fora tirava; o controle ficava sem lista)
	if get_viewport().gui_get_focus_owner() == null and _botoes.has(_escolhida):
		(_botoes[_escolhida] as Control).grab_focus()


# ------------------------------------------------------------------ o passo a passo

func entrar() -> void:
	if fase != Fase.FORA or armadura.em_pane or armadura.travado:
		return
	fase = Fase.ENTRANDO
	entradas += 1
	Arsenal.repor_granadas()
	_t = 0.0
	_de = armadura.global_position
	_para = _parada()
	armadura.travado = true
	armadura.velocity = Vector3.ZERO
	armadura.postura = 0
	if hud:
		hud.dica = ""
		hud.visible = false
	var t := BaseVale.cilindro_t
	_cam.global_position = t * Vector3(BaseVale.MEIO_CIL + 0.7, -0.75, 0.75)
	_cam.look_at(_para + Vector3(0, 0.66, 0) - t.basis.z.normalized() * 0.85)
	_cam.make_current()
	_cam_longe = _cam.global_transform
	por_dentro = true
	if _sol:
		# de trás e de lado (120° da câmera) e alto como o sol das 11h: de frente ele acendia todas as faces à vista e
		# o roxo do Mago virava rosa; assim metade fica na sombra, onde a cor da peça aparece como lá fora
		var para_cam := _cam.global_position - _para
		para_cam.y = 0.0
		var lado := para_cam.normalized().rotated(Vector3.UP, deg_to_rad(-120.0))
		var de_onde := (lado * cos(deg_to_rad(55.0)) + Vector3.UP * sin(deg_to_rad(55.0))).normalized()
		_sol.global_basis = Basis.looking_at(-de_onde, Vector3.UP)
		_sol.visible = true
	if sons:
		sons._toque("religar", -8.0)


func instalar(nome: String) -> void:
	if fase != Fase.ABERTA:
		return
	# a arma pronta sobe um degrau (as de fábrica e as fabricadas)
	if DE_FABRICA.has(nome) or (Arsenal.fabricados.has(nome) and Arsenal.MELHORA.has(nome)):
		var falta := Arsenal.falta_degrau(nome)
		if falta != "":
			if Arsenal.degrau(nome) < Arsenal.degraus_de(nome):
				_avisar("ainda não dá", Tablet.RUBI)
			return
		fase = Fase.INSTALANDO
		_instalando = "degrau:" + nome
		_t = 0.0
		_fazendo = "Acendendo a luz…"
		if sons:
			sons._toque("religar", -6.0)
		return
	if nome.begins_with("linha_"):
		var fechada := _fechada()
		if fechada != "":
			_piscar = 0.9
			if Corpo.de_achado(fechada):
				_avisar("acorde o robô %s" % String(Corpo.ACHADOS[fechada]["lugar"]), Tablet.RUBI)
			else:
				_avisar("abre no nível %d" % Corpo.nivel(fechada), Tablet.RUBI)
			return
		if _montagem == Corpo.vestido:
			return
		fase = Fase.INSTALANDO
		_instalando = "corpo"
		_corpo_pedido = _montagem.duplicate()
		_perto = false  # vestindo, a câmera afasta para mostrar o robô inteiro (até a próxima troca de linha)
		_t = 0.0
		_fazendo = "Trocando…"
		if sons:
			sons._toque("religar", -6.0)
		return
	if nome.begins_with("rastro_"):
		var id := nome.substr(7)
		if id != "" and int(Rotas.feitas.get(id, 0)) < 1:
			return
		Rotas.rastro = id
		if Guardado.ativo:
			Guardado.por_progresso("rastro", id)
		if sons:
			sons._toque("marcar", -6.0, 0.0)
		_refazer_lista()
		return
	if Arsenal.RECEITAS.has(nome):
		if Arsenal.fabricados.has(nome):
			return
		if Arsenal.falta(nome) != "":
			_avisar("ainda não dá", Tablet.RUBI)
			return
		fase = Fase.INSTALANDO
		_instalando = nome
		_t = 0.0
		_fazendo = "Fabricando…"
		if sons:
			sons._toque("religar", -6.0)
		return
	if not Melhorias.achadas.has(nome):
		return
	fase = Fase.INSTALANDO
	_instalando = nome
	_t = 0.0
	_fazendo = "Instalando…"
	if sons:
		sons._toque("religar", -6.0)


func sair() -> void:
	if fase != Fase.ABERTA:
		return
	fase = Fase.SAINDO
	_t = 0.0
	_tela.visible = false
	_rastro_de_volta()
	if _berco():
		_berco().soltar(armadura.visual)
	armadura.visual.previa = false
	_corpo_de_volta()
	armadura.visual.vestir_melhorias()
	_de = armadura.global_position
	# sai pela rampa até o chão, 2,5 m à frente da boca
	_para = BaseVale.cilindro_t * Vector3(BaseVale.MEIO_CIL + 2.5, -BaseVale.C_CIL.y + 0.05, 0.0)
	var e := _eixo()
	armadura.visual.yaw_forcado = atan2(-e.x, -e.z)


func _input(event: InputEvent) -> void:
	if fase != Fase.ABERTA:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sair()
	elif event.is_action_pressed("roda"):
		get_viewport().set_input_as_handled()
		_mudar_aba(-1)
	elif event.is_action_pressed("granada"):
		get_viewport().set_input_as_handled()
		_mudar_aba(1)
	elif event.is_action_pressed("agir") and aba == 4 and _linha != "inteiro":
		get_viewport().set_input_as_handled()
		_perto = not _perto  # △: de perto da parte ou o robô inteiro


func _physics_process(delta: float) -> void:
	_t += delta
	_recarregar(delta)
	if armadura == null:
		return
	match fase:
		Fase.FORA:
			var b := BaseVale.boca_cilindro
			var p := armadura.global_position
			# chegando à base, no chão: munição e vida de volta
			var na_base := Vector2(p.x - b.x, p.z - b.z).length() < 16.0 and armadura.estado == Armadura.Estado.CHAO and not armadura.em_pane
			if na_base and (Arsenal.granadas < Arsenal.granadas_max() or Arsenal.misseis < Arsenal.misseis_max() or armadura.avaria > 0 or float(armadura.get("_dano_frac")) > 0.01):
				Arsenal.repor_granadas()
				armadura.avaria = 0
				armadura.set("_dano_frac", 0.0)
				armadura.escudo_t = 0.0
				armadura.escudo_cargas = Arsenal.escudo_cargas()
				recargas += 1
				if hud:
					hud.avisar("Base", "munição e vida recarregadas")
				if sons:
					sons._toque("marcar", -6.0, 0.0)
			perto = Vector2(p.x - b.x, p.z - b.z).length() < PERTO and p.y < b.y and p.y > b.y - 4.0 \
				and armadura.estado == Armadura.Estado.CHAO and not armadura.em_pane and not armadura.escaneando and not armadura.travado and not armadura.contemplando
			if hud:
				var novo := "{agir}  entrar na oficina" if perto else ""
				if hud.dica != novo and (perto or hud.dica.begins_with("{agir}  entrar")):
					hud.dica = novo
			if perto and Input.is_action_just_pressed("agir"):
				entrar()
		Fase.ENTRANDO:
			var f := clampf(_t / T_ENTRAR, 0.0, 1.0)
			var e := _eixo()
			armadura.global_position = _de.lerp(_para, smoothstep(0.0, 1.0, f))
			armadura.velocity = -e * (2.6 if f < 0.9 else 0.0)
			armadura.visual.yaw_forcado = atan2(e.x, e.z)
			_luz.light_energy = _luz_forca * f
			_luz_atelie(f)
			_desce = clampf((_t - T_ENTRAR * 0.6) / 0.9, 0.0, 1.0)
			_por_bracos(_desce, 0.0)
			if _t >= T_ENTRAR + 0.6:
				_abrir()
		Fase.ABERTA:
			armadura.velocity = Vector3.ZERO
			_mover_camera(delta)
			_desce = minf(1.0, _desce + delta * 2.0)
			_por_bracos(_desce, 0.0)
			var ic := _berco()
			if ic:
				ic.seguir()  # o robô vira para mostrar a peça: presilhas, prato e cabos vão junto
		Fase.INSTALANDO:
			_mover_camera(delta)
			var k_i := sin(clampf(_t / T_INSTALAR, 0.0, 1.0) * PI)
			_por_bracos(1.0, k_i)
			var ic := _berco()
			if ic:
				ic.abrir(k_i if _t < T_INSTALAR else 0.0, 1.0)  # as peças se afastam e voltam
				ic.seguir()
			if _t >= T_INSTALAR:
				if ic:
					ic.abrir(0.0, 0.6)
				var nome := _instalando
				_instalando = ""
				fase = Fase.ABERTA
				if nome.begins_with("degrau:"):
					var arma := nome.substr(7)
					if Arsenal.melhorar(arma):
						melhoradas += 1
						if sons:
							sons._toque("fabricou", -3.0, 0.0)
					_refazer_lista()
					_escolher(arma)
					if arma == "escudo":  # o degrau novo já vem cheio
						armadura.escudo_cargas = Arsenal.escudo_cargas()
					_avisar("Luz acesa!")
					return
				if nome == "corpo":
					Corpo.vestido = _corpo_pedido.duplicate()
					Corpo.guardar()
					if sons:
						sons._toque("marcar", -4.0, 0.0)
					_refazer_lista()
					_previa_corpo()
					_avisar("Vestido!")
					return
				if Arsenal.RECEITAS.has(nome):
					if Arsenal.fabricar(nome):
						armadura.visual.escudos_vistos = armadura.escudos_gastos
						if sons:
							sons._toque("fabricou", -3.0, 0.0)
						instalou.emit(nome)
					_refazer_lista()
					_escolher(nome)
					_avisar("Fabricado!")
					return
				if Melhorias.instalar(nome):
					_tinha_energia = Melhorias.energia >= Melhorias.CUSTO
					if sons:
						sons._toque("marcar", -4.0, 0.0)
					if drone:
						drone.falar()
					instalou.emit(nome)
				_refazer_lista()
				_escolher(nome)
				_avisar("Instalado!")
		Fase.SAINDO:
			_mover_camera(delta)
			var f := clampf(_t / T_SAIR, 0.0, 1.0)
			_desce = maxf(0.0, _desce - delta * 2.4)
			_por_bracos(_desce, 0.0)
			armadura.global_position = _de.lerp(_para, smoothstep(0.0, 1.0, f))
			armadura.velocity = _eixo() * (2.6 if f < 0.9 else 0.0)
			_luz.light_energy = _luz_forca * (1.0 - f)
			_luz_atelie(1.0 - f)
			if f >= 1.0:
				_fechar()


## A câmera da oficina: na aba Corpo, perto da parte em foco (na faixa livre à esquerda do tablet); senão, a de
## sempre. Desliza até lá (uns 0,35 s).
func _mover_camera(delta: float) -> void:
	var alvo := _cam_longe
	if fase == Fase.ABERTA and aba == 4 and _perto and _linha != "inteiro" and CAM_PERTO.has(_linha):
		alvo = _camera_perto(_linha)
	_cam.global_transform = _cam.global_transform.interpolate_with(alvo, 1.0 - exp(-9.0 * delta))


func _junta(nome: String) -> Vector3:
	var n := armadura.visual.j.get(nome) as Node3D
	if n == null:
		n = armadura.visual.modelo.find_child(nome, true, false) as Node3D
	return n.global_position if n else armadura.global_position + Vector3(0, 0.6, 0)


## Onde a câmera fica para mostrar a parte: na frente dela, do lado da câmera de sempre, com a parte no meio da
## faixa da tela que o tablet deixa livre.
func _camera_perto(parte: String) -> Transform3D:
	var alvo: Vector3
	var l := parte.right(1)
	match parte:
		"cabeca":
			alvo = _junta("cabeca") + Vector3(0, 0.16, 0)
		"tronco":
			alvo = _junta("tronco") + Vector3(0, 0.08, 0)
		"bracoD", "bracoE":
			alvo = (_junta("ombro" + l) + _junta("punho" + l)) * 0.5
		_:
			alvo = (_junta("quadril" + l) + _junta("tornozelo" + l)) * 0.5
	var dist: float = CAM_PERTO[parte]
	var de := _cam_longe.origin - alvo
	de.y *= 0.4
	de = de.normalized()
	var pos := alvo + de * dist + Vector3(0, 0.08, 0)
	var frente := (alvo - pos).normalized()
	var direita := frente.cross(Vector3.UP).normalized()
	var tela := get_viewport().get_visible_rect().size
	var tan_h := tan(deg_to_rad(_cam.fov * 0.5)) * tela.x / maxf(1.0, tela.y)
	var livre := 1.0 - (Tablet.TAM.x + 8.0) / maxf(1.0, tela.x)  # a fração da tela à esquerda do tablet
	var olhar := alvo + direita * ((1.0 - livre) * 0.88 * dist * tan_h)
	return Transform3D(Basis.looking_at(olhar - pos, Vector3.UP), pos)


func _abrir() -> void:
	fase = Fase.ABERTA
	if _berco():
		_berco().prender(armadura.visual)
	_escolhida = ""
	aba = 0
	_montagem = Corpo.vestido.duplicate()  # a aba Corpo começa no corpo vestido, na linha da cabeça
	_linha = "cabeca"
	_novo_mostrado = false
	_visto_t = 0.0
	_perto = true
	_tela.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refazer_lista()


func _fechar() -> void:
	fase = Fase.FORA
	por_dentro = false
	_luz_atelie(0.0)
	if _sol:
		_sol.visible = false
	_rastro_de_volta()
	if _berco():
		_berco().soltar(armadura.visual)
	armadura.velocity = Vector3.ZERO
	armadura.visual.yaw_forcado = NAN
	armadura.travado = false
	armadura.teleportar(armadura.global_position, Armadura.Estado.CHAO)
	if camera:
		var e := _eixo()
		camera.yaw = atan2(-e.x, -e.z)
		camera.pitch = -0.1
		camera.cam.make_current()
	if hud:
		hud.visible = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A energia da base saiu (pedido do usuário): não há mais espera entre instalações.
func _recarregar(_delta: float) -> void:
	pass
