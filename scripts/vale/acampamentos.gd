class_name Acampamentos
extends Node3D
## Os acampamentos de máquinas (1.1, doc §136): três lugares bem afastados uns dos outros, onde as máquinas se
## instalaram com sucata em volta de um farolete vermelho. A briga é convidada: o farolete se vê de longe (e de
## noite pisca), a bússola mostra o acampamento perto, e quem não vai até lá não é incomodado.
## Em 2026-11-22 (pedido do usuário: simples demais, perto demais uns dos outros, e três bastam numa ilha
## pacata) eram quatro a 300 ou 400 m; ficaram três, a mais de 1 km um do outro (o do Planalto saiu), e cada um
## ganhou um jeito próprio de montar (`LISTA["jeito"]`):
##  - Capinzal, "sinal": o posto de sinal no campo aberto do sul. Um mastro listrado e estaiado com o farolete
##    no alto, mureta baixa de chapas, caixotes e tambores em três arcos, um telheiro de lona com a bancada, a
##    antena, o braseiro e a pilha de peças.
##  - Barranco, "oficina": a oficina na clareira do oeste. Uma torre de vigia com plataforma, escada e telhadinho
##    (o farolete em cima), uma barricada em ferradura, a oficina debaixo de um toldo comprido (bancadas,
##    estantes, armários, lanternas), o posto de carga, a caixa-d'água e a forja.
##  - Planície, "ferro_velho": o ferro-velho na planície da terra nova. Muro alto e fechado de painéis, contêineres
##    velhos, caixotes, tambores e chapas, com portão e cancela listrada; uma torre de armações com a lança e o ímã
##    pendurado, o monte de sucata, o cata-vento com placas de sol e baterias, dois toldos e dois braseiros.
## Tudo de sucata: peças dos kits da base (Quaternius), do KayKit e do Factory Kit (Kenney), e o resto (chapas
## onduladas, lonas, contêineres, vigas, cabos, bandeirolas, baterias, o miolo dos montes, o chão batido) feito
## aqui, numa malha por material. No chão batido o capim quase não nasce (`CapimVivo.batidos`). O que fica de pé
## conta como obstáculo para quem anda sem física (`Obstaculos`): as máquinas e os bichos dão a volta.
## Cada máquina desligada ali dá o prêmio dela na hora, na conta da Fundição (o nível do acampamento faz as
## vezes da onda; pedido do usuário, 2026-11-21). Desligar todas ao mesmo tempo libera o lugar: o farolete fica
## verde, as máquinas dormem ali (ninguém é destruído), os braseiros e as lanternas apagam, nascem flores em
## volta e os bichos voltam (um lugar novo de coelhos e pássaros na `VidaVale`).
## Depois de uns dias de jogo (`volta`, contados só jogando: um dia é uma hora), máquinas novas acham o lugar
## de novo, com o robô longe dali: o farolete volta ao vermelho, as flores e os bichos vão embora e o prêmio
## vale outra vez. Longo de propósito (pedido do usuário): vencer não pode parecer à toa.
## Quem cria passa `mapa`, `armadura`, `hud` e `vida`.

signal liberou(id: String)
signal reocupou(id: String)

## `volta`: dias de jogo até as máquinas voltarem (os maiores demoram mais). `frente`: para onde fica a entrada
## (no mundo, x e z). Os lugares (2026-11-22): longe da água (mais de 200 m), dos lugares com nome, das
## máquinas soltas, das tocas e das coisas para achar, e nenhum no leste da ilha.
const LISTA := [
	{"id": "capinzal", "nome": "Acampamento do Capinzal", "pos": Vector2(-160, 940), "maquinas": 3, "nivel": 3, "volta": 6.0,
		"jeito": "sinal", "frente": Vector2(0.17, -1.0)},
	{"id": "barranco", "nome": "Acampamento do Barranco", "pos": Vector2(-880, -100), "maquinas": 4, "nivel": 6, "volta": 7.0,
		"jeito": "oficina", "frente": Vector2(1.0, 0.11)},
	{"id": "planicie", "nome": "Acampamento da Planície", "pos": Vector2(-2950, -650), "maquinas": 5, "nivel": 9, "volta": 8.0,
		"jeito": "ferro_velho", "frente": Vector2(1.0, 0.1)},
]
const ACORDA := 230.0
const DORME := 290.0
const BUSSOLA := 450.0  # a esta distância o acampamento aparece na bússola
const RAIO := 7.5  # onde as máquinas ficam, em volta do farolete (o pátio fica livre entre 4 e 10 m)
const VERMELHO := Color(1.0, 0.16, 0.1)
const VERDE := Color(0.3, 1.0, 0.45)
const FLORES := ["q_flor_a", "q_flor_b", "q_flor_c", "q_flor_d", "q_moita_flor"]
## Até onde vai cada acampamento (o muro ou a mureta), por jeito: as flores e o chão batido seguem.
const TAMANHO := {"sinal": 14.0, "oficina": 16.0, "ferro_velho": 19.0}

## As peças de pacote. As do KayKit (CC0) levam a textura do pacote delas; as outras de
## `assets/vale/acampamentos/` são dos kits da base (Quaternius, CC0) e vestem os materiais da base; as com
## hífen são do Factory Kit (Kenney, CC0, as da Fundição); o resto já estava em `assets/vale/base/`.
const PASTA := "res://assets/vale/acampamentos/"
const KAYKIT := {
	"windturbine_tall": "spacebits_texture", "solarpanel": "spacebits_texture", "water_storage": "spacebits_texture",
	"Fuel_A_Barrels": "resource_bits_texture", "Fuel_B_Barrels": "resource_bits_texture", "Fuel_C_Barrels": "resource_bits_texture",
	"Pallet_Wood_Covered_A": "resource_bits_texture", "Containers_Crate_Large": "resource_bits_texture",
	"Containers_Crate_Medium_Grey": "resource_bits_texture", "Containers_Crate_Small_Green": "resource_bits_texture",
	"Iron_Nuggets": "resource_bits_texture",
	"metalframe": "block_bits_texture",
	"bucket_metal": "tools_bits_texture", "hammer": "tools_bits_texture", "saw": "tools_bits_texture", "shovel": "tools_bits_texture",
	"mallet": "tools_bits_texture", "fishing_tacklebox": "tools_bits_texture",
	"lantern_standing": "halloweenbits_texture", "lantern_hanging": "halloweenbits_texture",
}
const KIT_NOVO := ["Door_Frame_Square", "Prop_Vent_Big", "Prop_Fan_Small", "Prop_Light_Floor", "Prop_Crate3",
	"Column_Simple", "Prop_Locker", "Prop_Desk_Medium", "Prop_Shelves_ThinTall", "Prop_Barrel2_Closed"]
## As cores das coisas feitas aqui: [cor, ferrugem, sujeira]. Chapas e lonas desbotadas, de sucata.
const CORES := {
	"ferro": [Color(0.27, 0.26, 0.25), 0.55, 0.0],
	"ferro_claro": [Color(0.5, 0.5, 0.47), 0.45, 0.0],
	"concreto": [Color(0.52, 0.5, 0.46), 0.05, 0.5],
	"madeira": [Color(0.45, 0.33, 0.22), 0.0, 0.8],
	"cabo": [Color(0.07, 0.07, 0.08), 0.0, 0.0],
	"tinta_vermelha": [Color(0.66, 0.2, 0.14), 0.4, 0.3],
	"tinta_branca": [Color(0.82, 0.8, 0.74), 0.4, 0.3],
	"chapa_verde": [Color(0.24, 0.42, 0.38), 0.38, 0.2],
	"chapa_ocre": [Color(0.66, 0.46, 0.16), 0.38, 0.2],
	"chapa_vermelha": [Color(0.55, 0.2, 0.13), 0.38, 0.2],
	"chapa_cinza": [Color(0.46, 0.48, 0.47), 0.45, 0.1],
	"chapa_azul": [Color(0.22, 0.33, 0.5), 0.38, 0.2],
	"lona_laranja": [Color(0.8, 0.36, 0.1), 0.0, 0.35],
	"lona_azul": [Color(0.16, 0.3, 0.52), 0.0, 0.35],
	"lona_verde": [Color(0.3, 0.42, 0.18), 0.0, 0.35],
	"lona_creme": [Color(0.7, 0.62, 0.46), 0.0, 0.4],
}
const CHAPAS := ["chapa_verde", "chapa_ocre", "chapa_vermelha", "chapa_cinza", "chapa_azul", "chapa_cinza"]
const ENGRENAGENS := ["cog-a", "cog-b", "cog-c", "cog-d", "cog-e"]

static var livres: Array = []  # ids dos acampamentos já liberados
static var horas := {}  # id liberado -> horas de jogo desde a liberação
## Para a bússola da HUD: [posição, nome] dos que ainda têm máquinas
static var na_bussola: Array = []
static var _cenas := {}
static var _medidas := {}
static var _mats := {}
static var _malhas := {}

var mapa: Vale
var armadura: Armadura
var hud: Hud
var vida: VidaVale
## id -> {k, centro, no, maquinas, lampada, luz, ponto, topo, flores, flores_no, bichos, ganho, fogos, raio}
var camps := {}
var liberados_agora := 0  # testes
var reocupados := 0  # testes
var pecas := 0  # peças de pacote postas (testes e fotos)

var _t := 0.0
var _hora_ant := -1.0
var _t_guardar := 0.0
var _helices: Array = []  # [nó, eixo] das hélices que giram com o vento


func _ready() -> void:
	if Guardado.ativo:
		livres = (Guardado.progresso("acampamentos") as Array).duplicate()
		horas = (Guardado.progresso("acampamentos_horas") as Dictionary).duplicate()
	# o acampamento do Planalto saiu em 2026-11-22: num jogo salvo antes, ele não conta mais
	livres = livres.filter(func(id: String) -> bool: return not dado(id).is_empty())
	for id: String in horas.keys():
		if not livres.has(id):
			horas.erase(id)
	for id: String in livres:
		if not horas.has(id):
			horas[id] = 0.0
	var k := 0
	for d: Dictionary in LISTA:
		_montar(d, k)
		k += 1
	_bussola()
	print("acampamentos: %d (%d liberados), %d peças" % [LISTA.size(), livres.size(), pecas])


static func dado(id: String) -> Dictionary:
	for d: Dictionary in LISTA:
		if d["id"] == id:
			return d
	return {}


## O ponto pedido, ou o chão bom mais perto dele (fora d'água, pouco inclinado).
func _chao(p: Vector2, busca: float) -> Vector3:
	for r: float in [0.0, busca * 0.33, busca * 0.66, busca]:
		for a in 8:
			var q: Vector2 = p + Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0)) * r
			if mapa.agua(q.x, q.y) == -INF and mapa.normal_em(q.x, q.y).y > 0.93:
				return Vector3(q.x, mapa.altura(q.x, q.y), q.y)
	return Vector3(p.x, mapa.altura(p.x, p.y), p.y)


# ---------------------------------------------------------------- montar

func _montar(d: Dictionary, k: int) -> void:
	var id: String = d["id"]
	var jeito: String = d["jeito"]
	var c := _chao(d["pos"], 30.0)
	var frente: Vector2 = d["frente"]
	var no := Node3D.new()
	no.name = "Acampamento_" + id
	add_child(no)
	# o nó fica no meio do pátio, virado com o +z para a entrada
	no.global_transform = Transform3D(Basis(Vector3.UP, atan2(frente.x, frente.y)), c)
	var livre := livres.has(id)
	var camp := {"k": k, "id": id, "centro": c, "no": no, "maquinas": [], "flores": [], "flores_no": null, "bichos": [], "ganho": {},
		"fogos": [], "raio": float(TAMANHO[jeito])}
	camps[id] = camp
	var m := Montagem.new()
	m.dono = self
	m.mapa = mapa
	m.no = no
	m.c = c
	m.id = id
	m.rng.seed = 6100 + k * 37
	m.corpo = StaticBody3D.new()
	no.add_child(m.corpo)
	_chao_batido(m, float(TAMANHO[jeito]) + 1.5)
	# o capim quase não nasce no pátio pisado (volta pela beira e por fora da barricada)
	var batido := Vector3(c.x, c.z, float(TAMANHO[jeito]) + 3.0)
	if not CapimVivo.batidos.has(batido):
		CapimVivo.batidos.append(batido)
	match jeito:
		"sinal":
			_sinal(m, camp)
		"oficina":
			_oficina(m, camp)
		"ferro_velho":
			_ferro_velho(m, camp)
	m.fechar()
	_lampada(camp, livre)
	_luzes_do_lugar(id, livre)
	# as máquinas, no pátio, em volta do farolete (os ângulos contam a partir da entrada)
	var n := int(d["maquinas"])
	for i in n:
		var ang := (i + 0.5) * TAU / n
		var casa := no.to_global(Vector3(sin(ang) * RAIO, 0.0, cos(ang) * RAIO))
		casa.y = mapa.altura(casa.x, casa.z)
		var mc := Mecha.new()
		mc.mapa = mapa
		mc.alvo = armadura
		mc.casa = casa
		mc.semente = 900 + k * 10 + i
		mc.onda_nivel = int(d["nivel"])
		mc.chefe = false
		add_child(mc)
		(camp["maquinas"] as Array).append(mc)
		mc.desligou.connect(_caiu.bind(id, mc))
		if livre:
			_dormir.call_deferred(mc, true)
	if livre:
		_fogos(camp, false)
		_florir(camp, true)
		_bichos(camp)  # (antes só nasciam na hora da liberação: com o jogo carregado o lugar ficava sem bicho)


## A lâmpada do farolete, no alto do que cada jeito montou (`camp["topo_local"]`): a luz de verdade e o ponto de
## luz que se vê de longe de noite.
func _lampada(camp: Dictionary, livre: bool) -> void:
	var no: Node3D = camp["no"]
	var topo: Vector3 = camp["topo_local"]
	var cor := VERDE if livre else VERMELHO
	var lampada := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.42
	esfera.height = 0.84
	lampada.mesh = esfera
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor * 0.5
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 3.0
	lampada.material_override = mat
	lampada.position = topo + Vector3(0, 0.25, 0)
	no.add_child(lampada)
	var chapeu := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.6
	cone.height = 0.4
	chapeu.mesh = cone
	chapeu.material_override = _mat("ferro", mapa._tex)
	chapeu.position = topo + Vector3(0, 0.82, 0)
	no.add_child(chapeu)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.6
	luz.omni_range = 14.0
	luz.position = topo
	no.add_child(luz)
	var ponto := LuzesNoite.por(no, topo + Vector3(0, 0.25, 0), cor, 7.0, 0.0 if livre else 1.3)
	camp["lampada"] = mat
	camp["luz"] = luz
	camp["ponto"] = ponto
	camp["topo"] = no.to_global(topo)


# ---------------------------------------------------------------- o posto de sinal (Capinzal)

## O mastro listrado de vermelho e branco, estaiado por três cabos, com as travessas dos rádios e o farolete no
## alto; mureta baixa em três arcos (a entrada e duas passagens), o telheiro de lona com a bancada, a antena
## virada para fora, o braseiro na entrada e a pilha de peças.
func _sinal(m: Montagem, camp: Dictionary) -> void:
	# o pé de concreto e as baterias que alimentam o rádio
	var y0 := m.chao_min(0, 0, 1.0)
	m.caixa(Vector3(0, y0 + 0.25, 0), Vector3(1.7, 0.6, 1.7), Basis(Vector3.UP, 0.3), "concreto")
	var alto := 11.2
	var trechos := [[0.5, 3.3, 0.24, "tinta_vermelha"], [3.3, 5.9, 0.22, "tinta_branca"], [5.9, 8.3, 0.19, "tinta_vermelha"],
		[8.3, 10.2, 0.16, "tinta_branca"], [10.2, alto, 0.13, "tinta_vermelha"]]
	for t: Array in trechos:
		m.cano(Vector3(0, y0 + float(t[0]), 0), Vector3(0, y0 + float(t[1]), 0), float(t[2]), t[3])
		m.cano(Vector3(0, y0 + float(t[0]) - 0.1, 0), Vector3(0, y0 + float(t[0]) + 0.14, 0), float(t[2]) + 0.06, "ferro")
	var mastro := CylinderShape3D.new()
	mastro.radius = 0.3
	mastro.height = alto
	m.forma(mastro, Transform3D(Basis.IDENTITY, Vector3(0, y0 + alto * 0.5, 0)))
	# as travessas, com as caixas dos rádios e um prato pequeno
	m.viga(Vector3(-1.3, y0 + 7.3, 0), Vector3(1.3, y0 + 7.3, 0), 0.1, "ferro")
	for lado: float in [-1.0, 1.0]:
		m.caixa(Vector3(lado * 1.15, y0 + 6.95, 0), Vector3(0.32, 0.55, 0.26), Basis.IDENTITY, "chapa_cinza", false)
	m.viga(Vector3(0, y0 + 9.6, -1.0), Vector3(0, y0 + 9.6, 1.0), 0.08, "ferro")
	m.cano(Vector3(0, y0 + 9.6, 0.95), Vector3(0, y0 + 9.75, 1.15), 0.42, "chapa_cinza")
	# três estais: do alto até as âncoras no chão, entre as casas das máquinas
	for a: float in [deg_to_rad(20.0), deg_to_rad(140.0), deg_to_rad(260.0)]:
		var ax := sin(a) * 6.6
		var az := cos(a) * 6.6
		var ay := m.chao(ax, az)
		m.caixa(Vector3(ax, ay + 0.12, az), Vector3(0.55, 0.4, 0.55), Basis(Vector3.UP, a), "concreto")
		m.cano(Vector3(0, y0 + 9.4, 0), Vector3(ax, ay + 0.35, az), 0.028, "cabo")
		m.cano(Vector3(ax, ay + 0.3, az), Vector3(ax, ay + 0.75, az), 0.06, "ferro")
		# bandeirolas desbotadas nos estais (a lona que sobrou, cortada em triângulos)
		if a < PI * 0.5 or a > PI * 1.2:
			m.bandeirolas(Vector3(0, y0 + 9.2, 0), Vector3(ax, ay + 0.5, az), ["lona_laranja", "lona_azul", "lona_creme", "lona_verde", "tinta_vermelha"])
	for a: float in [deg_to_rad(205.0), deg_to_rad(232.0)]:
		_bateria(m, Vector2(sin(a) * 3.8, cos(a) * 3.8), -a, 1.0)
	_bateria(m, Vector2(sin(deg_to_rad(218.0)) * 3.9, cos(deg_to_rad(218.0)) * 3.9), 0.3, 0.85, 0.8)
	camp["topo_local"] = Vector3(0, y0 + alto + 0.15, 0)
	# a mureta: três arcos, com a entrada na frente e duas passagens dos lados
	var r := 14.0
	var arcos := [[14.0, 118.0, ["caixas", "chapas", "tambores", "chapas", "caixas", "chapas"]],
		[132.0, 228.0, ["chapas", "tambores", "chapas", "chapas", "caixas", "chapas"]],
		[242.0, 346.0, ["chapas", "caixas", "chapas", "tambores", "chapas", "caixas"]]]
	for arco: Array in arcos:
		_arco(m, r, deg_to_rad(arco[0]), deg_to_rad(arco[1]), arco[2], 1.6)
	# a entrada: dois postes com lanterna
	for a: float in [deg_to_rad(-14.0), deg_to_rad(14.0)]:
		var p := Vector2(sin(a) * r, cos(a) * r)
		var py := m.chao(p.x, p.y)
		m.cano(Vector3(p.x, py - 0.1, p.y), Vector3(p.x, py + 2.3, p.y), 0.09, "ferro")
		m.viga(Vector3(p.x, py + 2.25, p.y), Vector3(p.x * 0.95, py + 2.25, p.y * 0.95), 0.06, "ferro")
		_lanterna(m, Vector3(p.x * 0.95, py + 2.22, p.y * 0.95), true)
	# o telheiro de lona encostado na mureta do fundo, com a bancada debaixo
	_telheiro(m, deg_to_rad(180.0), 12.6, 9.4, 5.4, 2.9, 2.05, "lona_laranja")
	var bf := _no_arco(deg_to_rad(180.0), 11.9)
	m.peca("Prop_Desk_Medium", bf, PI + deg_to_rad(180.0), 0.95)
	var topo_mesa := 0.94 * 0.95
	m.peca("hammer", bf + _tg(deg_to_rad(180.0)) * -0.7, 1.2, 0.5, topo_mesa, false, Basis(Vector3.RIGHT, PI * 0.5))
	m.peca("saw", bf + _tg(deg_to_rad(180.0)) * 0.5, 2.0, 0.55, topo_mesa, false, Basis(Vector3.RIGHT, PI * 0.5))
	m.peca("fishing_tacklebox", bf + _tg(deg_to_rad(180.0)) * 1.0 + _dentro(deg_to_rad(180.0)) * 0.1, 0.4, 0.45, topo_mesa, false)
	m.peca("Prop_Locker", _no_arco(deg_to_rad(193.0), 12.3), deg_to_rad(193.0) + PI, 0.95)
	m.peca("shovel", _no_arco(deg_to_rad(206.0), 13.3), deg_to_rad(206.0), 0.75, 0.0, false, Basis(Vector3.RIGHT, 0.3))
	m.peca("Prop_Crate3", _no_arco(deg_to_rad(167.0), 12.0), 0.3, 0.8)
	m.peca("Prop_Crate3", _no_arco(deg_to_rad(167.0), 12.0), 0.8, 0.6, 0.8)
	# a antena, num canto, virada para fora
	var pa := _no_arco(deg_to_rad(255.0), 11.0)
	m.peca("Prop_SatelliteDish", pa, deg_to_rad(255.0) + PI * 0.5, 0.75)
	# a pilha de peças, um estrado com lona e o holofote
	_sucata(m, _no_arco(deg_to_rad(100.0), 11.0), 1.0)
	m.peca("Pallet_Wood_Covered_A", _no_arco(deg_to_rad(80.0), 11.4), 0.4, 1.1)
	m.peca("Pallet_Wood_Covered_A", _no_arco(deg_to_rad(80.0), 11.4), 0.65, 1.1, 0.33)
	m.peca("Prop_Light_Floor", _no_arco(deg_to_rad(300.0), 11.6), deg_to_rad(300.0) + PI, 1.0)
	_braseiro(m, camp, _no_arco(deg_to_rad(30.0), 10.6))
	# os cabos pelo chão: do mastro ao telheiro e à antena
	m.cabo_chao(Vector2(0.4, -0.6), _no_arco(deg_to_rad(182.0), 10.0), 0.05)
	m.cabo_chao(Vector2(-0.5, -0.3), pa + _dentro(deg_to_rad(255.0)) * 1.2, 0.04)
	m.cabo_chao(Vector2(0.2, 0.6), _no_arco(deg_to_rad(28.0), 4.5), 0.035)


# ---------------------------------------------------------------- a oficina (Barranco)

## A torre de vigia no meio (quatro pernas de ferro com mãos-francesas, plataforma com guarda-corpo, escada e
## telhadinho de chapa, o farolete em cima), a barricada em ferradura aberta para a frente, a oficina debaixo do
## toldo comprido no fundo, o posto de carga, a forja e a caixa-d'água.
func _oficina(m: Montagem, camp: Dictionary) -> void:
	var y0 := m.chao_min(0, 0, 2.2)
	var alto := 7.0
	var pe := 1.75
	var cima := 1.15
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var a := Vector3(sx * pe, m.chao(sx * pe, sz * pe) - 0.2, sz * pe)
			m.caixa(Vector3(a.x, a.y + 0.25, a.z), Vector3(0.6, 0.5, 0.6), Basis.IDENTITY, "concreto")
			m.viga(a, Vector3(sx * cima, y0 + alto, sz * cima), 0.17, "ferro", true)
	# os anéis e as cruzes de cada face
	for nivel: Array in [[0.4, 2.6], [2.6, 4.8], [4.8, alto]]:
		var h0: float = nivel[0]
		var h1: float = nivel[1]
		var r0 := lerpf(pe, cima, h0 / alto)
		var r1 := lerpf(pe, cima, h1 / alto)
		for f in 4:
			var ang := f * PI * 0.5
			var b := Basis(Vector3.UP, ang)
			var a0 := b * Vector3(-r0, y0 + h0, r0)
			var a1 := b * Vector3(r0, y0 + h0, r0)
			var c0 := b * Vector3(-r1, y0 + h1, r1)
			var c1 := b * Vector3(r1, y0 + h1, r1)
			m.viga(c0, c1, 0.09, "ferro")
			if f != 0 or h0 > 0.5:
				m.viga(a0, c1, 0.06, "ferro_claro")
				m.viga(a1, c0, 0.06, "ferro_claro")
	# a plataforma, o guarda-corpo (aberto do lado da escada) e o telhadinho
	var py := y0 + alto
	m.caixa(Vector3(0, py + 0.09, 0), Vector3(3.4, 0.18, 3.4), Basis.IDENTITY, "chapa_cinza")
	for f in 4:
		var b := Basis(Vector3.UP, f * PI * 0.5)
		for s: float in [-1.6, 0.0, 1.6]:
			m.viga(b * Vector3(s, py + 0.15, 1.65), b * Vector3(s, py + 1.15, 1.65), 0.06, "ferro_claro")
		if f == 0:
			# do lado da escada: só os cantos e a ponta do corrimão
			for s2: float in [-1.0, 1.0]:
				m.viga(b * Vector3(s2 * 1.6, py + 1.1, 1.65), b * Vector3(s2 * 0.55, py + 1.1, 1.65), 0.05, "ferro_claro")
			continue
		for hh: float in [0.6, 1.1]:
			m.viga(b * Vector3(-1.6, py + hh, 1.65), b * Vector3(1.6, py + hh, 1.65), 0.05, "ferro_claro")
	# o telhadinho cai para a frente (os postes da frente são mais baixos)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.viga(Vector3(sx * 1.55, py + 0.15, sz * 1.55), Vector3(sx * 1.55, py + 2.22 - sz * 0.12, sz * 1.55), 0.08, "ferro")
	m.chapa(Vector3(0, py + 2.08, 1.95), 3.9, 3.9, Basis(Vector3.RIGHT, -PI * 0.5 + 0.064), "chapa_vermelha", false)
	m.cano(Vector3(0, py + 2.2, 0), Vector3(0, py + 3.15, 0), 0.07, "ferro")
	camp["topo_local"] = Vector3(0, py + 3.2, 0)
	m.peca("Prop_Light_Floor", Vector2(-0.9, -1.1), PI, 0.7, py + 0.18, false)
	m.peca("bucket_metal", Vector2(1.0, -1.0), 0.5, 0.45, py + 0.18, false)
	var plat := BoxShape3D.new()
	plat.size = Vector3(3.4, 0.25, 3.4)
	m.forma(plat, Transform3D(Basis.IDENTITY, Vector3(0, py + 0.08, 0)))
	var teto := BoxShape3D.new()
	teto.size = Vector3(3.9, 0.15, 3.9)
	m.forma(teto, Transform3D(Basis.IDENTITY, Vector3(0, py + 2.3, 0)))
	# a escada, na face da entrada
	var ez := pe + 0.35
	var ey := m.chao(0, ez)
	for lado: float in [-0.38, 0.38]:
		m.viga(Vector3(lado, ey - 0.1, ez), Vector3(lado, py + 0.2, cima + 0.12), 0.06, "ferro_claro")
	for i in 17:
		var f2 := (i + 0.5) / 17.0
		var dz := lerpf(ez, cima + 0.12, f2)
		var dy := lerpf(ey, py, f2)
		m.viga(Vector3(-0.38, dy, dz), Vector3(0.38, dy, dz), 0.04, "ferro_claro")
	# a barricada em ferradura, aberta para a frente, e o fundo fechado pela parede da oficina
	var r := 16.0
	_arco(m, r, deg_to_rad(38.0), deg_to_rad(148.0), ["caixas", "chapas", "tambores", "caixas", "chapas", "pilha"], 2.1)
	_arco(m, r, deg_to_rad(212.0), deg_to_rad(322.0), ["pilha", "chapas", "caixas", "tambores", "chapas", "caixas"], 2.1)
	_arco(m, r, deg_to_rad(148.0), deg_to_rad(212.0), ["chapas", "chapas", "chapas", "chapas"], 2.6)
	for a: float in [deg_to_rad(38.0), deg_to_rad(322.0)]:
		var p := _no_arco(a, r - 1.0)
		m.peca("Containers_Crate_Large", p, a, 1.0)
		_lanterna(m, Vector3(p.x, m.chao(p.x, p.y) + 1.05, p.y), false)
	# a oficina: o toldo comprido sobre as bancadas, as estantes, os armários e as lanternas penduradas
	_toldo(m, deg_to_rad(180.0), 13.0, 8.2, 4.6, 3.1, 2.7, "lona_azul", false)
	for i in 2:
		var a := deg_to_rad(180.0 + (i - 0.5) * 11.0)
		var p := _no_arco(a, 14.6)
		m.peca("Prop_Desk_Medium", p, a + PI, 0.95)
		var topo_mesa := 0.94 * 0.95
		if i == 0:
			m.peca("hammer", p + _tg(a) * -0.8, 0.9, 0.5, topo_mesa, false, Basis(Vector3.RIGHT, PI * 0.5))
			m.peca("fishing_tacklebox", p + _tg(a) * 0.6, a, 0.45, topo_mesa, false)
			m.peca("Prop_Fan_Small", p + _tg(a) * -0.1 + _dentro(a) * -0.15, 0.6, 0.45, topo_mesa, false)
		else:
			m.peca("saw", p + _tg(a) * -0.6, 2.6, 0.55, topo_mesa, false, Basis(Vector3.RIGHT, PI * 0.5))
			m.peca("mallet", p + _tg(a) * 0.4, 0.3, 0.45, topo_mesa, false, Basis(Vector3.RIGHT, PI * 0.5))
			m.peca("cog-b", p + _tg(a) * 0.95, 0.0, 0.55, topo_mesa, false)
	for a: float in [deg_to_rad(156.0), deg_to_rad(204.0)]:
		m.peca("Prop_Shelves_ThinTall", _no_arco(a, 14.4), a + PI, 0.9)
	m.peca("Prop_Locker", _no_arco(deg_to_rad(161.0), 14.9), deg_to_rad(161.0) + PI, 0.9)
	m.peca("Prop_Locker", _no_arco(deg_to_rad(164.5), 14.9), deg_to_rad(164.5) + PI, 0.9)
	for a: float in [deg_to_rad(170.0), deg_to_rad(190.0)]:
		var p := _no_arco(a, 12.4)
		_lanterna(m, Vector3(p.x, m.chao(p.x, p.y) + 2.25, p.y), true)
	# o posto de carga: um pilar com cabos, baterias empilhadas e um cabo pendurado até a torre
	var pc := _no_arco(deg_to_rad(222.0), 11.6)
	m.peca("Column_Simple", pc, deg_to_rad(222.0), 0.55)
	_bateria(m, pc + _tg(deg_to_rad(222.0)) * 1.3, deg_to_rad(222.0) + 0.2, 1.0)
	_bateria(m, pc + _tg(deg_to_rad(222.0)) * 1.35, deg_to_rad(222.0) + 0.5, 0.85, 0.8)
	_bateria(m, pc - _tg(deg_to_rad(222.0)) * 1.3, deg_to_rad(222.0) - 0.3, 1.0)
	m.cabo_pendurado(Vector3(-cima, py - 0.3, -cima), Vector3(pc.x, m.chao(pc.x, pc.y) + 2.6, pc.y), 0.9, 0.04)
	m.cabo_chao(pc + _dentro(deg_to_rad(222.0)) * 0.6, Vector2(-1.0, -1.3), 0.05)
	m.cabo_chao(Vector2(0.9, -1.4), _no_arco(deg_to_rad(184.0), 11.2), 0.05)
	# a forja (o braseiro), com o balde e o malho
	var pf := _no_arco(deg_to_rad(140.0), 11.4)
	_braseiro(m, camp, pf)
	m.peca("bucket_metal", pf + _tg(deg_to_rad(140.0)) * 1.1, 0.4, 0.55)
	m.peca("mallet", pf - _tg(deg_to_rad(140.0)) * 1.0, 1.0, 0.6, 0.0, false, Basis(Vector3.RIGHT, PI * 0.5))
	m.peca("shovel", _no_arco(deg_to_rad(128.0), 15.3), deg_to_rad(128.0), 0.75, 0.0, false, Basis(Vector3.RIGHT, 0.3))
	# a caixa-d'água, a pilha de peças e o estrado
	m.peca("water_storage", _no_arco(deg_to_rad(82.0), 12.2), 0.3, 1.45)
	_sucata(m, _no_arco(deg_to_rad(272.0), 11.8), 1.4)
	m.peca("Pallet_Wood_Covered_A", _no_arco(deg_to_rad(250.0), 12.6), 1.0, 1.15)
	m.peca("Fuel_C_Barrels", _no_arco(deg_to_rad(105.0), 12.8), 0.6, 1.2)


# ---------------------------------------------------------------- o ferro-velho (Planície)

## O muro alto e fechado (painéis, contêineres, caixotes, tambores e chapas), com o portão na frente e uma
## passagem no fundo; a torre de armações com a lança e o ímã pendurado, o farolete em cima; a montanha de
## sucata, o cata-vento com as placas de sol, dois toldos, dois braseiros e os holofotes.
func _ferro_velho(m: Montagem, camp: Dictionary) -> void:
	var y0 := m.chao_min(0, 0, 1.6)
	var lado := 2.0 * 1.15
	var andares := 4
	for i in andares:
		m.peca_em("metalframe", Vector3(0, y0 - 0.05 + i * lado, 0), (i % 2) * PI * 0.5, 1.15)
	var topo := y0 + andares * lado
	var torre := BoxShape3D.new()
	torre.size = Vector3(lado, topo - y0, lado)
	m.forma(torre, Transform3D(Basis.IDENTITY, Vector3(0, (y0 + topo) * 0.5, 0)))
	# a escada na face da frente
	for lx: float in [-0.35, 0.35]:
		m.viga(Vector3(lx, y0, lado * 0.5 + 0.12), Vector3(lx, topo, lado * 0.5 + 0.12), 0.06, "ferro_claro")
	for i in int((topo - y0) / 0.42):
		var hy := y0 + 0.3 + i * 0.42
		m.viga(Vector3(-0.35, hy, lado * 0.5 + 0.12), Vector3(0.35, hy, lado * 0.5 + 0.12), 0.04, "ferro_claro")
	# a lança: duas vigas com treliça, o contrapeso de concreto atrás e o ímã pendurado no cabo
	var ang := deg_to_rad(72.0)
	var dir := Vector3(sin(ang), 0, cos(ang))
	var lateral := Vector3(dir.z, 0, -dir.x)
	var ponta := dir * 7.4
	var atras := -dir * 2.6
	var lh := topo + 0.4
	for s: float in [-0.32, 0.32]:
		m.viga(atras + lateral * s + Vector3(0, lh, 0), ponta + lateral * s * 0.5 + Vector3(0, lh + 0.25, 0), 0.12, "chapa_ocre")
	m.viga(atras + Vector3(0, lh + 1.0, 0), ponta + Vector3(0, lh + 0.4, 0), 0.08, "chapa_ocre")
	for i in 7:
		var f := float(i) / 6.0
		var b0 := atras.lerp(ponta, f) + Vector3(0, lh + lerpf(0.0, 0.25, f), 0)
		var b1 := atras.lerp(ponta, minf(f + 1.0 / 6.0, 1.0)) + Vector3(0, lh + 1.0 - 0.6 * minf(f + 1.0 / 6.0, 1.0), 0)
		m.viga(b0, b1, 0.05, "ferro_claro")
	m.caixa(atras + Vector3(0, lh - 0.1, 0), Vector3(1.4, 1.1, 1.2), Basis(Vector3.UP, ang), "concreto", false)
	var gancho := ponta + Vector3(0, lh - 3.6, 0)
	m.cano(ponta + Vector3(0, lh + 0.2, 0), gancho + Vector3(0, 0.6, 0), 0.03, "cabo")
	m.peca_em("crane-magnet", gancho - Vector3(0, 0.6, 0), ang, 1.3)
	m.peca_em("cog-b", gancho - Vector3(0, 1.9, 0), ang, 1.5, false, Basis(Vector3.RIGHT, PI * 0.5))
	m.cano(Vector3(0, topo, 0), Vector3(0, topo + 1.3, 0), 0.08, "ferro")
	camp["topo_local"] = Vector3(0, topo + 1.4, 0)
	# o muro: dois arcos fechando a roda, o portão na frente e a passagem no fundo
	var r := 19.0
	_arco(m, r, deg_to_rad(9.0), deg_to_rad(173.0), ["painel", "conteiner", "caixas", "painel", "tambores", "chapas", "painel", "conteiner",
		"caixas", "painel"], 2.7, true)
	_arco(m, r, deg_to_rad(187.0), deg_to_rad(351.0), ["painel", "caixas", "conteiner", "painel", "chapas", "tambores", "painel", "caixas",
		"conteiner", "painel"], 2.7, true)
	# o portão: o batente de uma porta da base, a cancela listrada levantada e as lanternas
	var pp := _no_arco(0.0, r)
	m.peca("Door_Frame_Square", pp, 0.0, 1.0, 0.0, false)  # (a colisão só nos dois batentes: o vão fica livre)
	for s: float in [-1.0, 1.0]:
		var bt := BoxShape3D.new()
		bt.size = Vector3(0.6, 4.6, 0.55)
		m.forma(bt, Transform3D(Basis.IDENTITY, Vector3(s * 2.12, m.chao(s * 2.12, r) + 2.3, r)))
	# a cancela, levantada: o pé listrado e o braço apontando para o alto, por cima do caminho
	var cy := m.chao(2.75, r - 0.9)
	m.caixa(Vector3(2.75, cy + 0.6, r - 0.9), Vector3(0.45, 1.2, 0.45), Basis.IDENTITY, "aviso")
	var giro_braco := PI - 1.2
	m.caixa(Vector3(2.75, cy + 1.15, r - 0.9) + Basis(Vector3.BACK, giro_braco) * Vector3(2.2, 0, 0), Vector3(4.6, 0.2, 0.2),
		Basis(Vector3.BACK, giro_braco), "aviso", false)
	for s: float in [-1.0, 1.0]:
		var pl := _no_arco(s * deg_to_rad(11.0), r - 1.1)
		m.peca("Containers_Crate_Medium_Grey", pl, s * 0.2, 0.9)
		_lanterna(m, Vector3(pl.x, m.chao(pl.x, pl.y) + 0.6, pl.y), false)
	# a montanha de sucata no fundo, à esquerda
	var ps := _no_arco(deg_to_rad(232.0), 12.5)
	_sucata(m, ps, 2.3)
	m.peca("robot-arm-a", ps + _tg(deg_to_rad(232.0)) * 3.9, 0.8, 1.3, 0.1, true, Basis(Vector3.BACK, 1.4))
	m.peca("pipe-large-long", ps - _tg(deg_to_rad(232.0)) * 4.2, 0.4, 1.2)
	m.peca("hopper-round", ps + _dentro(deg_to_rad(232.0)) * 3.9 - _tg(deg_to_rad(232.0)) * 1.4, 0.0, 1.2, 0.0, true, Basis(Vector3.RIGHT, 1.65))
	# o cata-vento, as placas de sol e as baterias, com o cabo até a torre
	var pv := _no_arco(deg_to_rad(138.0), 13.4)
	var vento := m.peca("windturbine_tall", pv, deg_to_rad(138.0), 2.6)
	_helice(vento)
	for i in 3:
		var a := deg_to_rad(104.0 + i * 8.0)
		m.peca("solarpanel", _no_arco(a, 14.6), a + PI * 0.5, 2.3)
	_bateria(m, _no_arco(deg_to_rad(124.0), 12.0), 0.3, 1.1)
	_bateria(m, _no_arco(deg_to_rad(129.5), 12.4), 0.9, 1.1)
	_bateria(m, _no_arco(deg_to_rad(126.5), 12.2), 0.6, 0.9, 0.88)
	m.cabo_chao(pv + _dentro(deg_to_rad(138.0)) * 0.6, Vector2(-0.6, -1.0), 0.06)
	m.cabo_chao(_no_arco(deg_to_rad(112.0), 13.6), _no_arco(deg_to_rad(124.0), 12.6), 0.04)
	# a oficina debaixo do toldo laranja
	_toldo(m, deg_to_rad(300.0), 15.2, 6.4, 4.0, 3.0, 2.6, "lona_laranja", false)
	var po := _no_arco(deg_to_rad(300.0), 16.4)
	m.peca("Prop_Desk_Medium", po, deg_to_rad(300.0) + PI, 0.95)
	m.peca("hammer", po + _tg(deg_to_rad(300.0)) * -0.6, 2.2, 0.5, 0.9, false, Basis(Vector3.RIGHT, PI * 0.5))
	m.peca("Prop_Fan_Small", po + _tg(deg_to_rad(300.0)) * 0.5, 0.2, 0.45, 0.9, false)
	m.peca("Prop_Shelves_ThinTall", _no_arco(deg_to_rad(286.0), 16.3), deg_to_rad(286.0) + PI, 0.9)
	m.peca("Prop_Locker", _no_arco(deg_to_rad(314.0), 16.5), deg_to_rad(314.0) + PI, 0.9)
	var pl2 := _no_arco(deg_to_rad(300.0), 14.0)
	_lanterna(m, Vector3(pl2.x, m.chao(pl2.x, pl2.y) + 2.4, pl2.y), true)
	# o depósito debaixo do toldo verde
	_toldo(m, deg_to_rad(52.0), 15.0, 5.6, 3.8, 2.9, 2.5, "lona_verde", false)
	m.peca("Containers_Crate_Large", _no_arco(deg_to_rad(46.0), 16.0), 0.3, 1.1)
	m.peca("Containers_Crate_Medium_Grey", _no_arco(deg_to_rad(46.0), 16.0), 0.5, 1.0, 1.15)
	m.peca("Containers_Crate_Small_Green", _no_arco(deg_to_rad(58.0), 16.1), 0.1, 1.2)
	m.peca("Containers_Crate_Small_Green", _no_arco(deg_to_rad(58.0), 16.1), 0.6, 1.1, 0.6)
	m.peca("Pallet_Wood_Covered_A", _no_arco(deg_to_rad(53.0), 13.9), 0.2, 1.1)
	m.peca("Fuel_B_Barrels", _no_arco(deg_to_rad(65.0), 14.2), 0.7, 1.2)
	# a caixa-d'água no fundo, os braseiros e o carrinho de peças perto do portão
	m.peca("water_storage", _no_arco(deg_to_rad(165.0), 14.6), 0.0, 1.5)
	_braseiro(m, camp, _no_arco(deg_to_rad(24.0), 12.4))
	_braseiro(m, camp, _no_arco(deg_to_rad(205.0), 10.6))
	m.peca("Iron_Nuggets", _no_arco(deg_to_rad(338.0), 12.0), 0.7, 1.6)
	m.peca("cog-d", _no_arco(deg_to_rad(345.0), 12.6), 0.0, 1.4, 0.0, false, Basis(Vector3.RIGHT, 1.2))
	m.cabo_chao(Vector2(0.8, 1.2), _no_arco(deg_to_rad(300.0), 12.0), 0.05)
	m.cabo_chao(Vector2(-0.4, 1.3), _no_arco(deg_to_rad(20.0), 11.0), 0.04)


# ---------------------------------------------------------------- partes comuns

## Um ponto no arco do acampamento (ângulo a partir da entrada, girando para a direita do nó).
static func _no_arco(a: float, r: float) -> Vector2:
	return Vector2(sin(a), cos(a)) * r


## A direção ao longo do arco, e a de dentro (para o meio).
static func _tg(a: float) -> Vector2:
	return Vector2(cos(a), -sin(a))


static func _dentro(a: float) -> Vector2:
	return -Vector2(sin(a), cos(a))


## Um arco de barricada no raio `r`, de `a0` a `a1`, em trechos retos, um por estilo da lista.
func _arco(m: Montagem, r: float, a0: float, a1: float, estilos: Array, alt: float, alto := false) -> void:
	var n := estilos.size()
	for i in n:
		var b0 := lerpf(a0, a1, float(i) / n)
		var b1 := lerpf(a0, a1, float(i + 1) / n)
		_trecho(m, estilos[i], _no_arco(b0, r), _no_arco(b1, r), alt, alto)


## Um trecho reto de barricada de `p0` a `p1`.
##  - "chapas": chapas onduladas de cores trocadas, pregadas em postes e duas travessas;
##  - "caixas": caixotes, alguns empilhados;
##  - "tambores": tambores amarrados de quatro em quatro, às vezes dois em cima;
##  - "painel": um painel de parede da base (quebrado) em pé, escorado por trás;
##  - "conteiner": um contêiner velho de chapa ondulada, deitado;
##  - "pilha": um monte de peças e estrados.
func _trecho(m: Montagem, estilo: String, p0: Vector2, p1: Vector2, alt: float, alto: bool) -> void:
	var meio := (p0 + p1) * 0.5
	var t := (p1 - p0).normalized()
	var comp := p0.distance_to(p1)
	var fora := Vector2(-t.y, t.x)  # o lado de fora (o arco gira para a direita do nó)
	if fora.dot(meio) < 0.0:
		fora = -fora
	var giro_x := atan2(-t.y, t.x)  # gira o eixo x da peça para o rumo do trecho
	match estilo:
		"chapas":
			var postes := maxi(2, ceili(comp / 1.9) + 1)
			for i in postes:
				var q := p0.lerp(p1, float(i) / (postes - 1))
				var qy := m.chao(q.x, q.y)
				m.viga(Vector3(q.x, qy - 0.3, q.y) - Vector3(fora.x, 0, fora.y) * 0.12, Vector3(q.x, qy + alt + 0.15, q.y) - Vector3(fora.x, 0, fora.y) * 0.12, 0.11, "ferro")
			for hh: float in [0.35, 0.82]:
				var a := Vector3(p0.x, m.chao(p0.x, p0.y) + alt * hh, p0.y) - Vector3(fora.x, 0, fora.y) * 0.2
				var b := Vector3(p1.x, m.chao(p1.x, p1.y) + alt * hh, p1.y) - Vector3(fora.x, 0, fora.y) * 0.2
				m.viga(a, b, 0.07, "ferro")
			var folhas := maxi(2, roundi(comp / 1.35))
			for i in folhas:
				var f := (i + 0.5) / folhas
				var q := p0.lerp(p1, f) + t * m.rng.randf_range(-0.12, 0.12)
				var qy := m.chao_min(q.x, q.y, 0.6)
				var h := alt * m.rng.randf_range(0.86, 1.08)
				var tomba := Basis(Vector3(t.x, 0, t.y), m.rng.randf_range(-0.07, 0.07))
				var b := tomba * Basis(Vector3.UP, giro_x)
				m.chapa(Vector3(q.x, qy - 0.15, q.y) + Vector3(fora.x, 0, fora.y) * (0.02 + 0.05 * (i % 2)), comp / folhas + 0.25, h, b,
					CHAPAS[m.rng.randi() % CHAPAS.size()])
			var cx := BoxShape3D.new()
			cx.size = Vector3(comp, alt, 0.35)
			var my := m.chao(meio.x, meio.y)
			m.forma(cx, Transform3D(Basis(Vector3.UP, giro_x), Vector3(meio.x, my + alt * 0.5 - 0.1, meio.y)))
		"caixas":
			var n := maxi(1, roundi(comp / 1.9))
			for i in n:
				var q := p0.lerp(p1, (i + 0.5) / n) + fora * m.rng.randf_range(-0.2, 0.2)
				var nome: String = ["Containers_Crate_Large", "Prop_Crate", "Containers_Crate_Large", "Prop_Crate4"][(i + m.rng.randi() % 2) % 4]
				var esc := 1.15 if nome == "Containers_Crate_Large" else 1.0
				var no := m.peca(nome, q, giro_x + m.rng.randf_range(-0.12, 0.12), esc)
				var alto_peca := BaseVale._caixa(no.get_child(0) as Node3D).size.y * esc
				if alto or m.rng.randf() < 0.45:
					var cima: String = ["Containers_Crate_Medium_Grey", "Prop_Crate3", "Containers_Crate_Small_Green"][m.rng.randi() % 3]
					m.peca(cima, q + t * m.rng.randf_range(-0.2, 0.2), giro_x + m.rng.randf_range(-0.3, 0.3), 1.0, alto_peca)
		"tambores":
			var n := maxi(1, roundi(comp / 2.0))
			for i in n:
				var q := p0.lerp(p1, (i + 0.5) / n)
				var nome: String = ["Fuel_A_Barrels", "Fuel_B_Barrels", "Fuel_C_Barrels"][m.rng.randi() % 3]
				m.peca(nome, q, giro_x + m.rng.randf_range(-0.2, 0.2), 1.25)
				if alto or i % 2 == 1:
					m.peca(["Fuel_A_Barrels", "Fuel_C_Barrels"][i % 2], q, giro_x + 0.4, 1.15, 1.26)
			m.peca("Prop_Barrel1", meio + fora * -1.3 + t * 0.6, m.rng.randf() * TAU, 1.1, 0.0, true,
				Basis(Vector3.RIGHT, PI * 0.5))
		"painel":
			var nome: String = ["WallBand_Straight_Broken", "WallAstra_Straight_Broken", "WallBand_Straight"][m.rng.randi() % 3]
			m.peca(nome, meio, atan2(t.x, t.y), comp / 4.4, -0.15)
			# as escoras por trás (por dentro do muro)
			for s: float in [-0.3, 0.3]:
				var q := meio + t * comp * s
				var qy := m.chao(q.x, q.y)
				m.viga(Vector3(q.x, qy + alt * 0.75, q.y) - Vector3(fora.x, 0, fora.y) * 0.4, Vector3(q.x, qy - 0.1, q.y) - Vector3(fora.x, 0, fora.y) * 1.9, 0.1, "ferro")
		"conteiner":
			# um contêiner velho de chapa ondulada, deitado no lugar do muro, com as portas numa ponta
			var cor: String = CHAPAS[m.rng.randi() % CHAPAS.size()]
			var largo := comp - 0.2
			var fundo := 2.3
			var h := 2.5
			var my := m.chao_min(meio.x, meio.y, comp * 0.4) - 0.08
			var b := Basis(Vector3.UP, giro_x)
			var em := func(x: float, y: float, z: float) -> Vector3:
				return Vector3(meio.x, my, meio.y) + b * Vector3(x, y, z)
			for lado: float in [-1.0, 1.0]:
				m.chapa(em.call(0.0, 0.0, lado * fundo * 0.5), largo, h, b, cor)
				m.chapa(em.call(lado * largo * 0.5, 0.0, 0.0), fundo, h, b * Basis(Vector3.UP, PI * 0.5), cor)
			m.caixa(em.call(0.0, h + 0.03, 0.0), Vector3(largo + 0.1, 0.08, fundo + 0.1), b, cor, false)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					m.viga(em.call(sx * largo * 0.5, 0.0, sz * fundo * 0.5), em.call(sx * largo * 0.5, h + 0.08, sz * fundo * 0.5), 0.16, "ferro")
				for hy: float in [0.05, h + 0.02]:
					m.viga(em.call(sx * largo * 0.5, hy, -fundo * 0.5), em.call(sx * largo * 0.5, hy, fundo * 0.5), 0.12, "ferro")
			for hy: float in [0.05, h + 0.02]:
				for sz: float in [-1.0, 1.0]:
					m.viga(em.call(-largo * 0.5, hy, sz * fundo * 0.5), em.call(largo * 0.5, hy, sz * fundo * 0.5), 0.12, "ferro")
			# as trancas das portas
			var ponta := -1.0 if m.rng.randf() < 0.5 else 1.0
			for k in 4:
				var z := lerpf(-fundo * 0.36, fundo * 0.36, k / 3.0)
				m.cano(em.call(ponta * (largo * 0.5 + 0.06), 0.15, z), em.call(ponta * (largo * 0.5 + 0.06), h - 0.1, z), 0.035, "ferro_claro")
			var cx := BoxShape3D.new()
			cx.size = Vector3(largo, h, fundo)
			m.forma(cx, Transform3D(b, em.call(0.0, h * 0.5, 0.0)))
		"pilha":
			_sucata(m, meio - fora * 0.6, 1.0)
			m.peca("Pallet_Wood_Covered_A", meio + t * comp * 0.3, giro_x, 1.1)
			m.peca("Pallet_Wood_Covered_A", meio + t * comp * 0.3, giro_x + 0.2, 1.1, 0.33)
			m.peca("Containers_Crate_Large", meio - t * comp * 0.32, giro_x, 1.1)


## Uma pilha de peças: miúdos de ferro, engrenagens de pé e deitadas, uma grade de ventilação e um tambor.
## Um monte de sucata: o miolo escuro coberto de chapas, vigas e canos jogados de qualquer jeito (feitos aqui,
## numa malha só), e por cima as peças de pacote: miúdos de ferro, engrenagens de pé e deitadas, uma grade de
## ventilação e um tambor no pé. Devolve [altura do chão, raio, altura do monte] para quem põe mais coisa.
func _sucata(m: Montagem, p: Vector2, tam: float) -> Array:
	var r := 1.5 * tam
	var alto := 0.6 + 0.8 * tam
	var y0 := m.chao_min(p.x, p.y, r * 0.7)
	var cone := func(q: Vector2) -> float:
		return y0 + alto * maxf(0.0, 1.0 - pow(q.distance_to(p) / r, 1.4))
	m.esfera(Vector3(p.x, y0 - alto * 0.12, p.y), Vector3(r * 1.7, alto * 2.0, r * 1.5), m.rng.randf() * TAU, "ferro")
	var cores := ["ferro", "ferro_claro", "ferro", "chapa_cinza"] + CHAPAS
	for i in int(10 + 13 * tam * tam):
		var a := m.rng.randf() * TAU
		var q := p + Vector2(cos(a), sin(a)) * r * sqrt(m.rng.randf()) * 1.05
		var y: float = lerpf(y0, cone.call(q), m.rng.randf_range(0.7, 1.0))
		var b := Basis.from_euler(Vector3(m.rng.randf_range(-0.9, 0.9), m.rng.randf() * TAU, m.rng.randf_range(-0.9, 0.9)))
		var cor: String = cores[m.rng.randi() % cores.size()]
		match m.rng.randi() % 4:
			0, 1:
				m.caixa(Vector3(q.x, y, q.y), Vector3(m.rng.randf_range(0.4, 1.4), m.rng.randf_range(0.06, 0.35), m.rng.randf_range(0.3, 1.0)) * clampf(tam, 1.0, 1.4), b, cor, false)
			2:
				var d := b * Vector3(m.rng.randf_range(0.5, 1.1) * tam, 0, 0)
				m.cano(Vector3(q.x, y, q.y) - d, Vector3(q.x, y, q.y) + d, m.rng.randf_range(0.06, 0.2), cor)
			3:
				m.chapa(Vector3(q.x, y - 0.3, q.y), m.rng.randf_range(0.8, 1.6), m.rng.randf_range(0.6, 1.1), b, cor)
	var ac := m.rng.randf() * TAU
	var qa := p + Vector2(cos(ac), sin(ac)) * r * 0.25
	m.peca_em("Iron_Nuggets", Vector3(qa.x, cone.call(qa) - 0.35 * tam, qa.y), m.rng.randf() * TAU, 1.3 * tam)
	for i in 5:
		var a := ac + 1.2 + i * TAU / 5.0 + m.rng.randf_range(-0.3, 0.3)
		var q := p + Vector2(cos(a), sin(a)) * r * m.rng.randf_range(0.35, 0.8)
		var de_pe := i % 2 == 0
		var incl := Basis(Vector3.RIGHT, m.rng.randf_range(1.0, 1.4)) if de_pe else Basis(Vector3.RIGHT, m.rng.randf_range(0.2, 0.5))
		var esc := m.rng.randf_range(0.8, 1.3) * minf(tam, 1.6)
		m.peca_em(ENGRENAGENS[(i + m.rng.randi()) % ENGRENAGENS.size()], Vector3(q.x, cone.call(q) - (0.25 if de_pe else 0.12) * esc, q.y), a, esc, false, incl)
	var qv := p + Vector2(cos(ac + PI), sin(ac + PI)) * r * 0.55
	m.peca_em("Prop_Vent_Big", Vector3(qv.x, cone.call(qv) - 0.3, qv.y), ac + PI * 0.5, 0.8 * minf(tam, 1.5), false, Basis(Vector3.RIGHT, 0.9))
	var qb := p + Vector2(cos(ac - 2.0), sin(ac - 2.0)) * (r + 0.5)
	m.peca("Prop_Barrel2_Closed", qb, 0.3, 1.2)
	var f := CylinderShape3D.new()
	f.radius = r * 0.75
	f.height = alto
	m.forma(f, Transform3D(Basis.IDENTITY, Vector3(p.x, y0 + alto * 0.5, p.y)))
	return [y0, r, alto]


## O telheiro: lona inclinada sobre quatro postes, a parte alta encostada na mureta (`r_fundo`), a baixa para
## o pátio (`r_frente`).
func _telheiro(m: Montagem, a: float, r_fundo: float, r_frente: float, larg: float, alt_fundo: float, alt_frente: float, lona: String) -> void:
	var cantos: Array[Vector3] = []
	for rr: float in [r_fundo, r_frente]:
		for s: float in [-0.5, 0.5]:
			var q := _no_arco(a, rr) + _tg(a) * larg * s
			var hh := alt_fundo if rr == r_fundo else alt_frente
			var qy := m.chao(q.x, q.y)
			m.viga(Vector3(q.x, qy - 0.2, q.y), Vector3(q.x, qy + hh + 0.08, q.y), 0.1, "ferro" if rr == r_frente else "madeira", true)
			cantos.append(Vector3(q.x, qy + hh, q.y))
	m.viga(cantos[2], cantos[3], 0.08, "ferro")
	m.lona(cantos[0], cantos[1], cantos[3], cantos[2], 0.22, lona)
	# as cordas que seguram a beira da lona, abertas para os lados até as estacas
	for i: int in [2, 3]:
		var c: Vector3 = cantos[i]
		var est := Vector2(c.x, c.z) + _tg(a) * (1.3 if i == 3 else -1.3)
		var ey := m.chao(est.x, est.y)
		m.cano(c, Vector3(est.x, ey + 0.05, est.y), 0.018, "cabo")
		m.viga(Vector3(est.x, ey - 0.1, est.y), Vector3(est.x, ey + 0.25, est.y), 0.06, "madeira")


## O toldo: lona quase plana sobre seis postes, em pé no fundo do acampamento, com uma parede de chapas atrás
## (`parede`) e duas travessas.
func _toldo(m: Montagem, a: float, r: float, larg: float, fundo: float, alt_fundo: float, alt_frente: float, lona: String, parede: bool) -> void:
	var cantos: Array[Vector3] = []
	for rr: float in [r + fundo * 0.5, r - fundo * 0.5]:
		var hh := alt_fundo if rr > r else alt_frente
		for s: float in [-0.5, 0.0, 0.5]:
			var q := _no_arco(a, rr) + _tg(a) * larg * s
			var qy := m.chao(q.x, q.y)
			m.viga(Vector3(q.x, qy - 0.2, q.y), Vector3(q.x, qy + hh + 0.05, q.y), 0.12, "ferro", true)
			cantos.append(Vector3(q.x, qy + hh, q.y))
	m.viga(cantos[0], cantos[2], 0.09, "ferro")
	m.viga(cantos[3], cantos[5], 0.09, "ferro")
	m.lona(cantos[0], cantos[2], cantos[5], cantos[3], 0.3, lona)
	if parede:
		var p0 := _no_arco(a, r + fundo * 0.5 + 0.35) - _tg(a) * larg * 0.5
		var p1 := _no_arco(a, r + fundo * 0.5 + 0.35) + _tg(a) * larg * 0.5
		_trecho(m, "chapas", p0, p1, 2.3, false)


## Uma lanterna (de pé, ou pendurada num gancho); de noite, com as máquinas no lugar, ganha um ponto âmbar.
func _lanterna(m: Montagem, p: Vector3, pendurada: bool) -> void:
	var nome := "lantern_hanging" if pendurada else "lantern_standing"
	var esc := 0.55
	m.peca_em(nome, p - Vector3(0, 1.41 * esc if pendurada else 0.0, 0), m.rng.randf() * TAU, esc)
	var luz := LuzesNoite.por(m.no, p + Vector3(0, -0.45 if pendurada else 0.3, 0), LuzesNoite.AMBAR, 1.3, 0.0, m.rng.randf())
	luz.set_meta("so_com", "acamp_" + m.id)


## O braseiro: um tambor aberto com brasa; de noite (e sem chuva) acende como a fogueira da base. Apaga quando
## o lugar é liberado.
func _braseiro(m: Montagem, camp: Dictionary, p: Vector2) -> void:
	var esc := 1.25
	m.peca("Prop_Barrel2_Open", p, m.rng.randf() * TAU, esc)
	var topo := Vector3(p.x, m.chao_min(p.x, p.y, 0.4) + 1.1 * esc, p.y)
	for i in 3:
		var a := i * TAU / 3.0 + 0.4
		m.viga(topo + Vector3(cos(a) * 0.36, -0.05, sin(a) * 0.36), topo + Vector3(cos(a + 1.6) * 0.36, -0.05, sin(a + 1.6) * 0.36), 0.04, "ferro")
	var brasa := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.3
	disco.bottom_radius = 0.3
	disco.height = 0.08
	brasa.mesh = disco
	brasa.position = topo - Vector3(0, 0.1, 0)
	m.no.add_child(brasa)
	var fria := _mat_aceso(Color(0.07, 0.06, 0.055), 0.0)
	brasa.material_override = fria
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.55, 0.22)
	luz.light_energy = 0.0
	luz.omni_range = 8.0
	luz.position = topo + Vector3(0, 0.6, 0)
	m.no.add_child(luz)
	var fogo := Fogueira.new()
	fogo.name = "Braseiro"
	fogo.brasa = brasa
	fogo.mat_fria = fria
	fogo.mat_acesa = _mat_aceso(Color(1.0, 0.36, 0.08), 0.5)
	fogo.luz = luz
	fogo.position = topo - Vector3(0, 0.3, 0)
	fogo.scale = Vector3.ONE * 0.85
	m.no.add_child(fogo)
	(camp["fogos"] as Array).append(fogo)
	for item: Array in [[Vector3(0, 0.05, 0), LuzesNoite.BRASA, 1.6, 0.0], [Vector3(0, 0.45, 0), LuzesNoite.AMBAR, 0.9, 0.42]]:
		var ponto := LuzesNoite.por(m.no, topo + (item[0] as Vector3), item[1], item[2], item[3], m.rng.randf())
		ponto.set_meta("so_com", "acamp_fogo_" + m.id)


## Uma bateria grande de sucata: caixa escura, faixa de aviso e os dois bornes (vermelho e preto) em cima.
func _bateria(m: Montagem, p: Vector2, giro: float, esc: float, sobe := 0.0) -> void:
	var tam := Vector3(1.0, 0.8, 0.65) * esc
	var b := Basis(Vector3.UP, giro)
	var c := Vector3(p.x, m.chao_min(p.x, p.y, tam.x * 0.5) + sobe + tam.y * 0.5 - 0.03, p.y)
	m.caixa(c, tam, b, "chapa_cinza")
	m.caixa(c + Vector3(0, tam.y * 0.1, 0), Vector3(tam.x + 0.02, tam.y * 0.2, tam.z + 0.02), b, "aviso", false)
	m.caixa(c + Vector3(0, tam.y * 0.5 + 0.02, 0), Vector3(tam.x * 0.94, 0.05, tam.z * 0.94), b, "cabo", false)
	for k: int in [0, 1]:
		var borne := c + b * Vector3((k - 0.5) * tam.x * 0.6, tam.y * 0.5, 0)
		m.cano(borne, borne + Vector3(0, 0.14 * esc, 0), 0.07 * esc, "tinta_vermelha" if k == 0 else "cabo")


## A hélice do cata-vento gira sozinha (o nó dela vem separado no modelo).
func _helice(no: Node3D) -> void:
	for filho: Node in no.find_children("*fan*", "", true, false):
		if filho is Node3D:
			var cx := BaseVale._caixa(filho as Node3D) if not (filho is MeshInstance3D) else (filho as MeshInstance3D).get_aabb()
			var eixo := Vector3.FORWARD
			if cx.size.x <= cx.size.y and cx.size.x <= cx.size.z:
				eixo = Vector3.RIGHT
			elif cx.size.y <= cx.size.z:
				eixo = Vector3.UP
			_helices.append([filho, eixo])
			return


## O chão batido: terra pisada no meio do acampamento, com a beira comida pelo capim. Uma malha em roda que
## segue o terreno, um pouco acima dele.
func _chao_batido(m: Montagem, raio: float) -> void:
	var aneis := 12
	var fatias := 48
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inv := m.no.global_transform.basis.inverse()
	var pontos: Array[Vector3] = [m.p(0, 0, 0.1)]
	var normais: Array[Vector3] = [inv * mapa.normal_em(m.c.x, m.c.z)]
	for i in aneis:
		var rr := raio * 1.18 * float(i + 1) / aneis
		for j in fatias:
			var ang := j * TAU / fatias
			var q := Vector2(cos(ang), sin(ang)) * rr
			pontos.append(m.p(q.x, q.y, 0.1))
			var w := m.no.to_global(Vector3(q.x, 0, q.y))
			normais.append(inv * mapa.normal_em(w.x, w.z))
	for v in pontos.size():
		st.set_normal(normais[v])
		st.set_uv(Vector2(pontos[v].x, pontos[v].z) * 0.1)
		st.add_vertex(pontos[v])
	for j in fatias:
		var j1 := (j + 1) % fatias
		st.add_index(0)
		st.add_index(1 + j)
		st.add_index(1 + j1)
	for i in aneis - 1:
		for j in fatias:
			var j1 := (j + 1) % fatias
			var a := 1 + i * fatias + j
			var b := 1 + i * fatias + j1
			var c := 1 + (i + 1) * fatias + j1
			var d := 1 + (i + 1) * fatias + j
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(a)
			st.add_index(d)
			st.add_index(c)
	var mi := MeshInstance3D.new()
	mi.name = "ChaoBatido"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _shader_terra()
	mat.set_shader_parameter("ruido", mapa._tex)
	mat.set_shader_parameter("centro", m.c)
	mat.set_shader_parameter("raio", raio)
	mi.material_override = mat
	m.no.add_child(mi)


static var _terra: Shader

static func _shader_terra() -> Shader:
	if _terra == null:
		_terra = Shader.new()
		_terra.code = """shader_type spatial;
#include "res://scripts/shaders/vale_comum.gdshaderinc"
// O chão batido dos acampamentos: terra pisada, mais escura no meio, com a beira comida pelo capim.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec3 centro;
uniform float raio = 15.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 d = wpos.xz - centro.xz;
	float n1 = texture(ruido, wpos.xz * 0.035 + vec2(0.17, 0.41)).r;
	float n2 = texture(ruido, wpos.xz * 0.19 + vec2(0.63, 0.29)).r;
	float n3 = texture(ruido, wpos.xz * 0.9 + vec2(0.11, 0.77)).r;
	float t = length(d) / (raio * (0.86 + (n1 - 0.5) * 0.55));
	if (t + (n2 - 0.5) * 0.3 + (n3 - 0.5) * 0.12 > 1.0) {
		discard;
	}
	vec3 terra = mix(vec3(0.13, 0.095, 0.065), vec3(0.21, 0.155, 0.1), smoothstep(0.3, 0.75, n2));
	terra *= 0.9 + (n3 - 0.5) * 0.25;
	// manchas de óleo e marcas de pé pesado, mais perto do meio
	float oleo = smoothstep(0.74, 0.84, texture(ruido, wpos.xz * 0.13 + vec2(0.91, 0.37)).r + (1.0 - t) * 0.08);
	terra = mix(terra, vec3(0.075, 0.075, 0.08), oleo * 0.45);
	vec3 capim = cor_capim(ruido, wpos.xz);
	float beira = smoothstep(0.5, 0.98, t + (n1 - 0.5) * 0.25);
	ALBEDO = mix(terra, capim, beira * 0.75);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
"""
	return _terra


# ---------------------------------------------------------------- materiais e peças

## Um material das coisas feitas aqui (`CORES`), ou a tinta listrada de aviso.
static func _mat(nome: String, ruido: Texture2D) -> ShaderMaterial:
	if _mats.has(nome):
		return _mats[nome]
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_base.gdshader")
	m.set_shader_parameter("ruido", ruido)
	if nome == "aviso":
		m.set_shader_parameter("tex", _listras())
		m.set_shader_parameter("tinta", Color(0.92, 0.9, 0.85))
		m.set_shader_parameter("ferrugem", 0.35)
		m.set_shader_parameter("sujeira", 0.5)
	else:
		var c: Array = CORES[nome]
		m.set_shader_parameter("tinta", c[0])
		m.set_shader_parameter("ferrugem", c[1])
		m.set_shader_parameter("sujeira", c[2])
	m.set_shader_parameter("musgo", 0.0)
	_mats[nome] = m
	return m


## As listras de aviso (amarelo e preto, na diagonal).
static func _listras() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var faixa := int(floor((x + y) / 8.0)) % 2 == 0
			img.set_pixel(x, y, Color(0.86, 0.66, 0.12) if faixa else Color(0.08, 0.08, 0.08))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _mat_aceso(cor: Color, forca: float) -> ShaderMaterial:
	var chave := "aceso|%s|%.2f" % [cor.to_html(), forca]
	if _mats.has(chave):
		return _mats[chave]
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_base.gdshader")
	m.set_shader_parameter("tinta", cor)
	m.set_shader_parameter("aceso", Color(cor.r * forca, cor.g * forca, cor.b * forca))
	_mats[chave] = m
	return m


## A pintura de uma peça de pacote: textura do KayKit desbotada e encardida, as cores da Fundição no kit do
## Kenney, ou os materiais da base nos kits do Quaternius (por nome, em `BaseVale.vestir`).
static func _vestir(nome: String, raiz: Node3D, ruido: Texture2D) -> void:
	var m: ShaderMaterial = null
	if KAYKIT.has(nome):
		var chave := "kay|" + String(KAYKIT[nome])
		if not _mats.has(chave):
			m = ShaderMaterial.new()
			m.shader = load("res://scripts/shaders/vale_base.gdshader")
			m.set_shader_parameter("ruido", ruido)
			m.set_shader_parameter("tex", load(PASTA + String(KAYKIT[nome]) + ".png"))
			m.set_shader_parameter("tinta", Color(0.9, 0.88, 0.84))
			m.set_shader_parameter("sujeira", 0.35)
			m.set_shader_parameter("ferrugem", 0.12)
			m.set_shader_parameter("musgo", 0.0)
			_mats[chave] = m
		m = _mats[chave]
	elif nome.contains("-"):
		if not _mats.has("kenney"):
			m = ShaderMaterial.new()
			m.shader = load("res://scripts/shaders/vale_base.gdshader")
			m.set_shader_parameter("ruido", ruido)
			m.set_shader_parameter("tex", load("res://assets/vale/fundicao/Textures/colormap.png"))
			m.set_shader_parameter("tinta", Color(0.62, 0.6, 0.58))
			m.set_shader_parameter("ferrugem", 0.45)
			m.set_shader_parameter("sujeira", 0.7)
			m.set_shader_parameter("musgo", 0.0)
			_mats["kenney"] = m
		m = _mats["kenney"]
	else:
		BaseVale.vestir(raiz, 0.35, 0.0, ruido)
		return
	for mi: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false) + ([raiz] if raiz is MeshInstance3D else []):
		mi.material_override = m


static func _cena(nome: String) -> PackedScene:
	if not _cenas.has(nome):
		var arq := ""
		if KAYKIT.has(nome) or KIT_NOVO.has(nome):
			arq = PASTA + nome + ".gltf"
		elif nome.contains("-"):
			arq = "res://assets/vale/fundicao/%s.glb" % nome
		else:
			arq = BaseVale.PASTA + nome + ".gltf"
		_cenas[nome] = load(arq) if ResourceLoader.exists(arq) else null
	return _cenas[nome]


## Quem monta um acampamento: o nó (no meio do pátio, virado para a entrada), o chão, as malhas feitas aqui
## (juntas numa por material) e as colisões. Tudo na medida do nó: x e z do lugar, y a partir do chão do meio.
class Montagem:
	var dono: Acampamentos
	var mapa: Vale
	var no: Node3D
	var c: Vector3
	var id := ""
	var corpo: StaticBody3D
	var rng := RandomNumberGenerator.new()
	var _st := {}  # material -> SurfaceTool

	## Altura do chão num ponto do lugar.
	func chao(x: float, z: float) -> float:
		var w := no.global_transform * Vector3(x, 0, z)
		return mapa.altura(w.x, w.z) - c.y

	## O chão mais baixo em volta (para uma peça larga não ficar no ar na ladeira).
	func chao_min(x: float, z: float, r: float) -> float:
		var h := chao(x, z)
		for k in 6:
			h = minf(h, chao(x + cos(k * TAU / 6.0) * r, z + sin(k * TAU / 6.0) * r))
		return h

	func p(x: float, z: float, sobe := 0.0) -> Vector3:
		return Vector3(x, chao(x, z) + sobe, z)

	func _juntar(malha: Mesh, xf: Transform3D, mat: String) -> void:
		if not _st.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_st[mat] = st
		(_st[mat] as SurfaceTool).append_from(malha, 0, xf)

	## A colisão de uma forma (na medida do lugar); o que fica de pé na altura do corpo vira obstáculo.
	func forma(f: Shape3D, xf: Transform3D) -> void:
		var cs := CollisionShape3D.new()
		cs.shape = f
		cs.transform = xf
		corpo.add_child(cs)
		var w := no.global_transform * xf
		Obstaculos.registrar_forma(f, w, mapa.altura(w.origin.x, w.origin.z))

	func caixa(centro: Vector3, tam: Vector3, b: Basis, mat: String, colide := true) -> void:
		_juntar(Acampamentos._malha("caixa"), Transform3D(b.scaled_local(tam), centro), mat)
		if colide:
			var cx := BoxShape3D.new()
			cx.size = tam
			forma(cx, Transform3D(b, centro))

	## Uma viga de seção quadrada de `a` a `b`.
	func viga(a: Vector3, b: Vector3, grossura: float, mat: String, colide := false) -> void:
		var d := b - a
		if d.length() < 0.01:
			return
		var base := Basis(Quaternion(Vector3.UP, d.normalized()))
		var tam := Vector3(grossura, d.length(), grossura)
		_juntar(Acampamentos._malha("caixa"), Transform3D(base.scaled_local(tam), (a + b) * 0.5), mat)
		if colide:
			var cx := BoxShape3D.new()
			cx.size = tam
			forma(cx, Transform3D(base, (a + b) * 0.5))

	## Um cano (cilindro) de `a` a `b`.
	func cano(a: Vector3, b: Vector3, raio: float, mat: String) -> void:
		var d := b - a
		if d.length() < 0.01:
			return
		var base := Basis(Quaternion(Vector3.UP, d.normalized()))
		_juntar(Acampamentos._malha("cilindro"), Transform3D(base.scaled_local(Vector3(raio * 2.0, d.length(), raio * 2.0)), (a + b) * 0.5), mat)

	## Uma bola achatada (o miolo de um monte), de tamanho `tam`, girada `giro`.
	func esfera(centro: Vector3, tam: Vector3, giro: float, mat: String) -> void:
		_juntar(Acampamentos._malha("esfera"), Transform3D(Basis(Vector3.UP, giro).scaled_local(tam), centro), mat)

	## Uma chapa ondulada: `pe` é o meio da beira de baixo; a base `b` diz para onde ela fica (x ao longo, y
	## para cima).
	func chapa(pe: Vector3, larg: float, alt: float, b: Basis, mat: String, colide := false) -> void:
		_juntar(Acampamentos._malha("chapa"), Transform3D(b.scaled_local(Vector3(larg, alt, 1.0)), pe), mat)
		if colide:
			var cx := BoxShape3D.new()
			cx.size = Vector3(larg, alt, 0.12)
			forma(cx, Transform3D(b, pe + b * Vector3(0, alt * 0.5, 0)))

	## Uma lona presa nos quatro cantos (na ordem da volta), com a barriga para baixo e umas dobras.
	func lona(p00: Vector3, p10: Vector3, p11: Vector3, p01: Vector3, barriga: float, mat: String) -> void:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nu := 10
		var nv := 7
		var pos := func(u: float, v: float) -> Vector3:
			var q: Vector3 = p00.lerp(p10, u).lerp(p01.lerp(p11, u), v)
			return q - Vector3(0, barriga * sin(PI * u) * sin(PI * v) + 0.035 * sin(u * 23.0 + v * 3.0), 0)
		for j in nv + 1:
			for i in nu + 1:
				var u := float(i) / nu
				var v := float(j) / nv
				var q: Vector3 = pos.call(u, v)
				var du: Vector3 = pos.call(minf(u + 0.02, 1.0), v) - pos.call(maxf(u - 0.02, 0.0), v)
				var dv: Vector3 = pos.call(u, minf(v + 0.02, 1.0)) - pos.call(u, maxf(v - 0.02, 0.0))
				var n := du.cross(dv).normalized()
				if n.y < 0.0:
					n = -n
				st.set_normal(n)
				st.set_uv(Vector2(u, v))
				st.add_vertex(q)
		for j in nv:
			for i in nu:
				var a := j * (nu + 1) + i
				st.add_index(a)
				st.add_index(a + 1)
				st.add_index(a + nu + 2)
				st.add_index(a)
				st.add_index(a + nu + 2)
				st.add_index(a + nu + 1)
		_juntar(st.commit(), Transform3D.IDENTITY, mat)

	## Bandeirolas penduradas num cabo de `a` a `b`, uma de cada cor da lista, em volta.
	func bandeirolas(a: Vector3, b: Vector3, cores: Array) -> void:
		var d := b - a
		var n := int(d.length() / 0.6)
		for i in range(1, n - 1):
			var p0 := a + d * float(i) / n
			var lx := d.normalized() * 0.34
			var ly := Vector3(0, 0.42, 0)
			var lz := lx.cross(ly).normalized() * 0.02
			_juntar(Acampamentos._malha("bandeira"), Transform3D(Basis(lx, ly, lz), p0), cores[i % cores.size()])

	## Um cabo jogado no chão, de `a` a `b`, serpenteando.
	func cabo_chao(a: Vector2, b: Vector2, raio: float) -> void:
		var comp := a.distance_to(b)
		var n := maxi(3, ceili(comp / 0.7))
		var lado := (b - a).normalized().orthogonal()
		var fase := rng.randf() * TAU
		var ant := Vector3.INF
		for i in n + 1:
			var f := float(i) / n
			var q := a.lerp(b, f) + lado * sin(f * 9.0 + fase) * 0.35 * sin(f * PI)
			var pt := Vector3(q.x, chao(q.x, q.y) + raio * 0.6, q.y)
			if ant.is_finite():
				cano(ant, pt, raio, "cabo")
			ant = pt

	## Um cabo pendurado entre dois pontos, com a barriga.
	func cabo_pendurado(a: Vector3, b: Vector3, barriga: float, raio: float) -> void:
		var n := 12
		var ant := a
		for i in range(1, n + 1):
			var f := float(i) / n
			var pt := a.lerp(b, f) - Vector3(0, barriga * 4.0 * f * (1.0 - f), 0)
			cano(ant, pt, raio, "cabo")
			ant = pt

	## Uma peça de pacote com o meio da base em `onde` (no chão, mais `sobe`), virada `giro` e na escala `esc`;
	## `inclina` deita ou tomba a peça antes de girar. Devolve o nó.
	func peca(nome: String, onde: Vector2, giro: float, esc: float, sobe := 0.0, colide := true, inclina := Basis.IDENTITY) -> Node3D:
		var cx := _medida(nome, inclina)
		var largo := maxf(cx.size.x, cx.size.z) * esc
		var y := (chao_min(onde.x, onde.y, largo * 0.35) if largo > 0.8 else chao(onde.x, onde.y)) + sobe
		return peca_em(nome, Vector3(onde.x, y, onde.y), giro, esc, colide, inclina)

	## A caixa de uma peça de pacote já deitada por `inclina` (sem escala).
	func _medida(nome: String, inclina: Basis) -> AABB:
		var cena := Acampamentos._cena(nome)
		if cena == null:
			return AABB()
		var chave := "%s|%s" % [nome, inclina]
		if not Acampamentos._medidas.has(chave):
			var raiz := cena.instantiate() as Node3D
			Acampamentos._medidas[chave] = Transform3D(inclina, Vector3.ZERO) * BaseVale._caixa(raiz)
			raiz.free()
		return Acampamentos._medidas[chave]

	## A mesma peça, com o meio da base num ponto exato do lugar (pendurada, empilhada, no alto da torre).
	func peca_em(nome: String, onde: Vector3, giro: float, esc: float, colide := false, inclina := Basis.IDENTITY) -> Node3D:
		var cena := Acampamentos._cena(nome)
		var no2 := Node3D.new()
		no.add_child(no2)
		if cena == null:
			push_warning("acampamentos: falta a peça " + nome)
			return no2
		var raiz := cena.instantiate() as Node3D
		var cx2 := _medida(nome, inclina)
		raiz.transform = Transform3D(inclina, -Vector3(cx2.get_center().x, cx2.position.y, cx2.get_center().z))
		no2.add_child(raiz)
		var largo := maxf(cx2.size.x, cx2.size.z) * esc
		var y := onde.y
		no2.transform = Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * esc), Vector3(onde.x, y - 0.04, onde.z))
		Acampamentos._vestir(nome, raiz, mapa._tex)
		if maxf(largo, cx2.size.y * esc) < 2.4:
			for mi: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false):
				mi.visibility_range_end = 320.0
		dono.pecas += 1
		if colide:
			var f := BoxShape3D.new()
			f.size = cx2.size * esc
			forma(f, Transform3D(Basis(Vector3.UP, giro), Vector3(onde.x, y + f.size.y * 0.5 - 0.04, onde.z)))
		return no2

	## Fecha as malhas feitas aqui: uma por material.
	func fechar() -> void:
		for mat: String in _st:
			var mi := MeshInstance3D.new()
			mi.name = "Malha_" + mat
			mi.mesh = (_st[mat] as SurfaceTool).commit()
			mi.material_override = Acampamentos._mat(mat, mapa._tex)
			mi.visibility_range_end = 1400.0
			no.add_child(mi)
		_st.clear()


## As malhas de base (de 1 m): a caixa, o cilindro e a chapa ondulada.
static func _malha(qual: String) -> Mesh:
	if _malhas.has(qual):
		return _malhas[qual]
	var malha: Mesh
	match qual:
		"caixa":
			malha = BoxMesh.new()
		"cilindro":
			var cil := CylinderMesh.new()
			cil.top_radius = 0.5
			cil.bottom_radius = 0.5
			cil.height = 1.0
			cil.radial_segments = 8
			cil.rings = 1
			malha = cil
		"bandeira":
			# um triângulo pendurado: a beira de cima no eixo x (0 a 1), a ponta embaixo
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_normal(Vector3(0, 0, 1))
			for v: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0.5, -1, 0)]:
				st.set_uv(Vector2(v.x, -v.y))
				st.add_vertex(v)
			malha = st.commit()
		"esfera":
			var esf := SphereMesh.new()
			esf.radius = 0.5
			esf.height = 1.0
			esf.radial_segments = 12
			esf.rings = 6
			malha = esf
		"chapa":
			# de -0.5 a 0.5 em x, de 0 a 1 em y; as ondas em z (as duas faces: o material não corta o avesso)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var n := 28
			for i in n + 1:
				var x := float(i) / n - 0.5
				var z := 0.04 * sin(x * TAU * 7.0)
				var dz := 0.04 * TAU * 7.0 * cos(x * TAU * 7.0)
				var nn := Vector3(-dz, 0, 1).normalized()
				for y: float in [0.0, 1.0]:
					st.set_normal(nn)
					st.set_uv(Vector2(x + 0.5, y))
					st.add_vertex(Vector3(x, y, z))
			for i in n:
				var a := i * 2
				st.add_index(a)
				st.add_index(a + 1)
				st.add_index(a + 3)
				st.add_index(a)
				st.add_index(a + 3)
				st.add_index(a + 2)
			malha = st.commit()
	_malhas[qual] = malha
	return malha


# ---------------------------------------------------------------- liberar

func _guardar(gravar := true) -> void:
	if Guardado.ativo:
		Guardado.por_progresso("acampamentos", livres, false)
		Guardado.por_progresso("acampamentos_horas", horas, gravar)


## Uma máquina do acampamento desligou: o prêmio dela vem na hora, na conta da Fundição. As que dormem por conta
## do lugar liberado (`para_sempre`) não contam.
func _caiu(id: String, mc: Mecha) -> void:
	if mc.para_sempre or livres.has(id):
		return
	var g := Arsenal.premio(false, int(dado(id)["nivel"]), mc.semente)
	var soma: Dictionary = camps[id]["ganho"]
	for k: String in g:
		soma[k] = int(soma.get(k, 0)) + int(g[k])
	Espolio.premiar(self, mc.global_position, g, armadura, hud)
	_conferir(id)


func _conferir(id: String) -> void:
	if livres.has(id):
		return
	for mc: Mecha in camps[id]["maquinas"]:
		if not mc.desligada:
			return
	_liberar(id)


func _liberar(id: String) -> void:
	livres.append(id)
	horas[id] = 0.0
	liberados_agora += 1
	_guardar()
	var camp: Dictionary = camps[id]
	for mc: Mecha in camp["maquinas"]:
		_dormir(mc, false)
	_acender(camp, VERDE, 0.0)
	_fogos(camp, false)
	_luzes_do_lugar(id, true)
	_florir(camp, false)
	_bichos(camp)
	var d := dado(id)
	Som.toque3d(self, "onda_vencida", camp["topo"], -2.0)
	if hud:
		# o que as máquinas dali renderam (cada uma deu o seu na hora)
		hud.avisar(String(d["nome"]), "o farolete ficou verde · " + Arsenal.texto_premio(camp["ganho"]))
	camp["ganho"] = {}
	_bussola()
	liberou.emit(id)


## As lanternas e os braseiros só acendem com as máquinas no lugar (os braseiros, também, só sem chuva:
## `Fogueira` diz isso em `LuzesNoite.ligadas["fogueira"]`).
func _luzes_do_lugar(id: String, livre: bool) -> void:
	LuzesNoite.ligadas["acamp_" + id] = not livre
	LuzesNoite.ligadas["acamp_fogo_" + id] = not livre and bool(LuzesNoite.ligadas.get("fogueira", true))


## Os braseiros de um lugar: acesos (de noite, quem decide é a `Fogueira`) ou apagados de vez.
func _fogos(camp: Dictionary, acesos: bool) -> void:
	for fogo: Fogueira in camp["fogos"]:
		fogo.process_mode = Node.PROCESS_MODE_INHERIT if acesos else Node.PROCESS_MODE_DISABLED
		if not acesos:
			fogo.forca = 0.0
			fogo.acesa = false
			for filho: Node in fogo.get_children():
				(filho as Node3D).visible = false
			if fogo.luz:
				fogo.luz.visible = false
			if fogo.brasa:
				fogo.brasa.material_override = fogo.mat_fria


## Os bichos do lugar liberado: um lugar de coelhos e um de pássaros na `VidaVale`.
func _bichos(camp: Dictionary) -> void:
	if vida == null or not (camp["bichos"] as Array).is_empty():
		return
	var c: Vector3 = camp["centro"]
	var k := int(camp["k"])
	var coelhos := {"tipo": "coelho", "pos": c + Vector3(6, 0, -5), "semente": 7300 + k * 11, "quantos": 3, "nos": []}
	var passaros := {"tipo": "passaro", "pos": c + Vector3(-4, 0, 7), "semente": 7350 + k * 11, "quantos": 6, "nos": []}
	vida.lugares.append(coelhos)
	vida.lugares.append(passaros)
	camp["bichos"] = [coelhos, passaros]


func _tirar_bichos(camp: Dictionary) -> void:
	if vida == null:
		return
	for l: Dictionary in camp["bichos"]:
		var nos: Array = l["nos"]
		if not nos.is_empty():
			for n in nos:
				if is_instance_valid(n):
					(n as Node).queue_free()
			nos.clear()
			vida.vivos -= 1
		var i := vida.lugares.find(l)
		if i >= 0:
			vida.lugares.remove_at(i)
	camp["bichos"] = []


## Máquinas novas acham o lugar (só com o robô longe): religam onde moravam, o farolete volta ao vermelho
## piscando, os braseiros e as lanternas voltam, as flores e os bichos vão embora e o acampamento volta à bússola.
func _reocupar(id: String) -> void:
	livres.erase(id)
	horas.erase(id)
	reocupados += 1
	_guardar()
	var camp: Dictionary = camps[id]
	for mc: Mecha in camp["maquinas"]:
		if not is_instance_valid(mc):
			continue
		mc.para_sempre = false
		mc.global_position = mc.casa
		mc.religar()
	_acender(camp, VERMELHO, 1.3)
	_fogos(camp, true)
	_luzes_do_lugar(id, false)
	var fl: Node = camp["flores_no"]
	if fl and is_instance_valid(fl):
		fl.queue_free()
	camp["flores_no"] = null
	camp["flores"] = []
	_tirar_bichos(camp)
	camp["ganho"] = {}
	_bussola()
	if hud:
		hud.avisar(String(dado(id)["nome"]), "as máquinas voltaram · o farolete está vermelho de novo")
	reocupou.emit(id)


## A máquina fica desligada para sempre, sem fumaça (dorme no meio das flores).
func _dormir(mc: Mecha, ja_estava: bool) -> void:
	if not is_instance_valid(mc):
		return
	mc.para_sempre = true
	if not mc.desligada:
		mc.desligar()
	if ja_estava:
		mc._fumaca.emitting = false
	else:
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if is_instance_valid(mc):
				mc._fumaca.emitting = false)


func _acender(camp: Dictionary, cor: Color, pisca: float) -> void:
	var mat: StandardMaterial3D = camp["lampada"]
	mat.albedo_color = cor * 0.5
	mat.emission = cor
	(camp["luz"] as OmniLight3D).light_color = cor
	var velho: Node3D = camp["ponto"]
	var pos := velho.position
	velho.queue_free()
	camp["ponto"] = LuzesNoite.por(camp["no"], pos, cor, 7.0, pisca)


## Flores e moitas floridas no pátio, entre as máquinas e até a mureta (fora do que fica de pé); na hora da
## liberação elas crescem.
func _florir(camp: Dictionary, de_uma_vez: bool) -> void:
	var c: Vector3 = camp["centro"]
	var raio: float = camp["raio"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(c.x * 13.0 + c.z * 7.0))
	var no := Node3D.new()
	no.name = "Flores"
	add_child(no)
	camp["flores_no"] = no
	for i in int(raio * raio * 0.45):
		var ang := rng.randf_range(0.0, TAU)
		var r := sqrt(rng.randf()) * (raio + 2.0) + 1.2
		var x := c.x + cos(ang) * r
		var z := c.z + sin(ang) * r
		var tipo: String = FLORES[rng.randi() % FLORES.size()]
		var s := rng.randf_range(0.8, 1.3) * (1.4 if tipo == "q_moita_flor" else 1.0)
		if mapa.agua(x, z) != -INF or not Obstaculos.livre(mapa, x, z, 0.35):
			continue
		if not mapa._malhas.has(tipo):
			continue
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3(x, mapa.altura(x, z) + 0.06, z))
		for par: Array in mapa._malhas[tipo]:
			var mi := MeshInstance3D.new()
			mi.mesh = par[0]
			mi.transform = xf * (par[1] as Transform3D)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			no.add_child(mi)
			(camp["flores"] as Array).append(mi)
			if not de_uma_vez:
				var final := mi.scale
				mi.scale = final * 0.01
				var tw := create_tween()
				tw.tween_interval(0.5 + r * 0.12 + rng.randf() * 0.6)
				tw.tween_property(mi, "scale", final, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## As horas de jogo dos lugares liberados: as que o dia andou desde a última olhada (a pane soma as três horas
## dela; a hora que volta para trás depois de uma cena não conta). Guarda a cada minuto.
func _relogio() -> void:
	var ciclo := CicloDia.atual
	if ciclo == null or not is_instance_valid(ciclo):
		return
	if _hora_ant >= 0.0 and not horas.is_empty():
		var dh := fposmod(ciclo.hora - _hora_ant, 24.0)
		if dh < 12.0:
			for id: String in horas:
				horas[id] = float(horas[id]) + dh
			_t_guardar += 0.4
			if _t_guardar > 60.0:
				_t_guardar = 0.0
				_guardar()
	_hora_ant = ciclo.hora


func _bussola() -> void:
	na_bussola.clear()
	for d: Dictionary in LISTA:
		if not livres.has(d["id"]) and camps.has(d["id"]):
			na_bussola.append([camps[d["id"]]["topo"], d["nome"]])


# ---------------------------------------------------------------- acordar e dormir

func _process(delta: float) -> void:
	for h: Array in _helices:
		if is_instance_valid(h[0]):
			(h[0] as Node3D).rotate_object_local(h[1], delta * 1.6)
	# a luz do farolete no chão só de noite (de dia ela manchava o pátio de vermelho)
	var noite := ArmaduraVisual.noite
	for id: String in camps:
		var luz: OmniLight3D = camps[id]["luz"]
		luz.light_energy = 1.6 * noite
		luz.visible = noite > 0.02
	_t += delta
	if _t < 0.4 or armadura == null:
		return
	_t = 0.0
	_relogio()
	var a := armadura.global_position
	for id: String in camps:
		var c: Vector3 = camps[id]["centro"]
		var d := Vector2(c.x - a.x, c.z - a.z).length()
		if livres.has(id) and d > DORME and float(horas.get(id, 0.0)) >= float(dado(id)["volta"]) * 24.0:
			_reocupar(id)
		LuzesNoite.ligadas["acamp_fogo_" + id] = not livres.has(id) and bool(LuzesNoite.ligadas.get("fogueira", true))
		for mc: Mecha in camps[id]["maquinas"]:
			if mc.process_mode == Node.PROCESS_MODE_DISABLED and d < ACORDA:
				mc.process_mode = Node.PROCESS_MODE_INHERIT
			elif mc.process_mode != Node.PROCESS_MODE_DISABLED and d > DORME:
				mc.process_mode = Node.PROCESS_MODE_DISABLED
