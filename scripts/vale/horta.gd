class_name Horta
extends Node3D
## A horta da base (1.1, doc §136): nove sementes pela ilha e um canteiro para plantar. Cinco sementes ficam
## perto dos lugares bonitos (a Árvore-Mãe, o Anel, a Cachoeira, os Arcos, as Colunas), a uns 55 a 95 m do meio
## deles e longe das outras coisas para achar (`PontosIlha`), e cada acampamento de máquinas liberado deixa mais
## uma no meio das flores. A semente brilha verde de leve (de noite é um ponto de
## luz) e é só passar por ela para pegar. No canteiro de trás da horta da base, o triângulo (agir) planta a
## próxima: ela nasce pequenina e cresce em umas oito horas do dia do jogo (com chuva, no dobro do passo).
## Planta crescida fica. As sementes achadas e as plantas (e quanto cresceram) ficam guardadas.
## A bússola mostra a semente mais perto a menos de 150 m (uma folhinha verde).
## Quem cria passa `mapa`, `armadura`, `hud` e `acampamentos`.

const PERTO_PEGAR := 2.4
const PERTO_PLANTAR := 2.6
const HORAS_CRESCER := 8.0
const BUSSOLA := 150.0
const VERDE := Color(0.55, 1.0, 0.45)
## Os lugares das sementes da ilha (perto, mas fora do marco). Os acampamentos dão o resto.
## `pos` é o marco; a semente fica a uns 14 m dele, para o lado de `rumo` (graus), num chão limpo e seco.
const ILHA := [
	{"id": "mae", "pos": Vector2(660, 110), "rumo": 200.0},
	{"id": "anel", "pos": Vector2(-190, 600), "rumo": 90.0},
	{"id": "cachoeira", "pos": Vector2(-290, -485), "rumo": 0.0},
	{"id": "arcos", "pos": Vector2(-730, 30), "rumo": 120.0},
	{"id": "colunas", "pos": Vector2(420, -600), "rumo": 300.0},
]
## O que nasce de cada semente, na ordem das covas (e o tamanho da planta crescida).
const PLANTAS := [["q_flor_a", 0.55], ["q_planta_b", 0.5], ["q_flor_c", 0.55], ["q_samambaia", 0.42], ["q_moita_flor", 0.5],
	["q_flor_b", 0.55], ["q_planta_d", 0.48], ["q_flor_d", 0.55], ["q_cogumelo", 0.5]]

static var na_bussola: Array = []  # posições das sementes ainda no chão

var mapa: Vale
var armadura: Armadura
var hud: Hud
var acampamentos: Acampamentos
var achadas: Array = []  # ids das sementes já pegas
var plantas: Array = []  # [{"horas": float}] na ordem das covas
var colhidas_teste := 0

var _soltas := {}  # id -> Node3D (a semente no chão)
var _nos_planta: Array = []  # Node3D de cada planta (a malha cresce por escala)
var _t := 0.0
var _perto_canteiro := false


func _ready() -> void:
	if Guardado.ativo:
		var g: Dictionary = Guardado.progresso("horta")
		achadas = (g.get("achadas", []) as Array).duplicate()
		for p: Dictionary in g.get("plantas", []):
			plantas.append({"horas": float(p.get("horas", 0.0))})
	if acampamentos:
		acampamentos.liberou.connect(_do_acampamento)
		for id: String in Acampamentos.livres:
			if not achadas.has("camp_" + id):
				_do_acampamento(id)
	for i in plantas.size():
		_nascer(i)
	_bussola()
	_espalhar()


## As sementes da ilha esperam o `Main` anotar as outras coisas (peças, memórias, balizas...) para cada uma achar
## um lugar longe delas, perto do lugar bonito dela.
func _espalhar() -> void:
	for i in 180:
		if PontosIlha.pronto:
			break
		await get_tree().physics_frame
	for d: Dictionary in ILHA:
		var p := _lugar(d)
		PontosIlha.anotar("semente:" + String(d["id"]), p)
		if not achadas.has(d["id"]):
			_soltar(d["id"], p)
	_bussola()


## O lugar da semente: de 55 a 95 m do meio do lugar bonito, a começar pelo rumo dela, em chão seco e plano, a
## pelo menos `PontosIlha.LONGE` de tudo o que está anotado (e das outras sementes). A conta é sempre a mesma:
## a semente volta ao mesmo lugar a cada vez que o jogo abre.
func _lugar(d: Dictionary) -> Vector3:
	var c: Vector2 = d["pos"]
	var r0 := deg_to_rad(float(d["rumo"]))
	for dist: float in [55.0, 65.0, 75.0, 85.0, 95.0]:
		for k in 16:
			var ang := r0 + (k + 1) / 2 * TAU / 16.0 * (1.0 if k % 2 == 0 else -1.0)
			var q := c + Vector2(cos(ang), sin(ang)) * dist
			var p := _chao(q, 6.0)
			if p.is_finite() and PontosIlha.livre(p, PontosIlha.LONGE + 5.0):  # uma folga, para não ficar no limite
				return p
	var p := _chao(c + Vector2(cos(r0), sin(r0)) * 55.0, 20.0)
	return p if p.is_finite() else Vector3(c.x, mapa.altura(c.x, c.y), c.y)


func na_mao() -> int:
	return achadas.size() - plantas.size()


## Um chão limpo perto de `p`: o raio de cima tem de bater no próprio terreno (não numa pedra, tronco ou
## coluna), plano e longe da água uns 5 m. Sem nenhum, `Vector3.INF`.
func _chao(p: Vector2, busca: float) -> Vector3:
	var espaco := get_world_3d().direct_space_state
	for r: float in [0.0, busca * 0.25, busca * 0.5, busca * 0.75, busca]:
		var n := 1 if r == 0.0 else 10
		for a in n:
			var q: Vector2 = p + Vector2(cos(a * TAU / n), sin(a * TAU / n)) * r
			var h := mapa.altura(q.x, q.y)
			if mapa.normal_em(q.x, q.y).y < 0.9 or not _seco(q, 5.0) or not Obstaculos.livre(mapa, q.x, q.y, 1.5):
				continue  # (as árvores longe do robô não têm colisão: o raio de cima não acha o tronco)
			var consulta := PhysicsRayQueryParameters3D.create(Vector3(q.x, h + 30.0, q.y), Vector3(q.x, h - 2.0, q.y))
			if armadura:
				consulta.exclude = [armadura.get_rid()]
			var acerto := espaco.intersect_ray(consulta)
			if acerto.is_empty() or absf((acerto["position"] as Vector3).y - h) < 0.3:
				return Vector3(q.x, h, q.y)
	return Vector3.INF


func _seco(q: Vector2, margem: float) -> bool:
	if mapa.agua(q.x, q.y) != -INF:
		return false
	for a in 6:
		var e := q + Vector2(cos(a * TAU / 6.0), sin(a * TAU / 6.0)) * margem
		if mapa.agua(e.x, e.y) != -INF:
			return false
	return true


func _guardar() -> void:
	if not Guardado.ativo:
		return
	var l: Array = []
	for p: Dictionary in plantas:
		l.append({"horas": snappedf(float(p["horas"]), 0.01)})
	Guardado.por_progresso("horta", {"achadas": achadas, "plantas": l})


func _bussola() -> void:
	na_bussola.clear()
	for id: String in _soltas:
		na_bussola.append((_soltas[id] as Node3D).global_position)


# ---------------------------------------------------------------- a semente no chão

func _mat(cor: Color, luz := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.7
	if luz > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = luz
	return m


## A semente: um caroço castanho com dois brotos verdes, girando devagar meio metro acima de um montinho de
## terra, com uma luz verde fraca e, de noite, o ponto de luz.
func _soltar(id: String, pe: Vector3) -> void:
	if _soltas.has(id):
		return
	var no := Node3D.new()
	no.name = "Semente_" + id
	add_child(no)
	no.global_position = pe
	var monte := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.3
	monte.mesh = sm
	monte.material_override = _mat(Color(0.32, 0.22, 0.14))
	monte.position = Vector3(0, 0.0, 0)
	no.add_child(monte)
	var gira := Node3D.new()
	gira.name = "gira"
	gira.position = Vector3(0, 0.8, 0)
	gira.scale = Vector3.ONE * 1.6
	no.add_child(gira)
	var caroco := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.13
	cm.height = 0.34
	caroco.mesh = cm
	caroco.material_override = _mat(Color(0.62, 0.42, 0.22), 0.25)
	gira.add_child(caroco)
	for s: float in [-1.0, 1.0]:
		var folha := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.1
		fm.height = 0.04
		folha.mesh = fm
		folha.material_override = _mat(VERDE, 2.0)
		folha.position = Vector3(s * 0.09, 0.2, 0)
		folha.scale = Vector3(1.0, 1.0, 0.55)
		folha.rotation.z = -s * 0.5
		gira.add_child(folha)
	var luz := OmniLight3D.new()
	luz.light_color = VERDE
	luz.light_energy = 1.1
	luz.omni_range = 4.0
	luz.position = Vector3(0, 1.0, 0)
	no.add_child(luz)
	LuzesNoite.por(no, pe + Vector3(0, 0.9, 0), VERDE, 2.2, 0.6, float(id.hash() % 100) * 0.1)
	_soltas[id] = no


func _do_acampamento(id: String) -> void:
	# a semente de um acampamento é uma só: liberado de novo depois de reocupado, não deixa outra
	if not acampamentos.camps.has(id) or achadas.has("camp_" + id):
		return
	var c: Vector3 = acampamentos.camps[id]["centro"]
	_soltar("camp_" + id, Vector3(c.x + 2.0, mapa.altura(c.x + 2.0, c.z + 1.0), c.z + 1.0))
	_bussola()


func _pegar(id: String) -> void:
	var no: Node3D = _soltas[id]
	_soltas.erase(id)
	Som.toque3d(self, "caixa_pega", no.global_position + Vector3(0, 0.7, 0), -6.0)
	EfeitosTiro.impacto_laser(self, no.global_position + Vector3(0, 0.7, 0), VERDE, 1.4)
	no.queue_free()
	achadas.append(id)
	_guardar()
	_bussola()
	if hud:
		var falta := ILHA.size() + Acampamentos.LISTA.size() - achadas.size()
		hud.avisar("Semente achada!", "plante no canteiro da horta, na base · %d na mão · %s" %
			[na_mao(), "faltam %d pela ilha" % falta if falta > 0 else "achou todas"])


# ---------------------------------------------------------------- as plantas do canteiro

func _nascer(i: int) -> void:
	if i >= BaseLar.horta_vagas.size():
		return
	var tipo: String = PLANTAS[i % PLANTAS.size()][0]
	var no := Node3D.new()
	no.name = "Planta_%d" % i
	add_child(no)
	no.global_position = BaseLar.horta_vagas[i]
	no.rotation.y = i * 2.1
	# a covinha de terra mexida (fica sempre)
	var cova := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.07
	cova.mesh = sm
	cova.material_override = _mat(Color(0.24, 0.16, 0.1))
	cova.position = Vector3(0, 0.01, 0)
	no.add_child(cova)
	var planta := Node3D.new()
	planta.name = "planta"
	no.add_child(planta)
	if mapa._malhas.has(tipo):
		for par: Array in mapa._malhas[tipo]:
			var mi := MeshInstance3D.new()
			mi.mesh = par[0]
			mi.transform = par[1]
			planta.add_child(mi)
	while _nos_planta.size() <= i:
		_nos_planta.append(null)
	_nos_planta[i] = no
	_crescer_visual(i)


func crescido(i: int) -> float:
	return clampf(float(plantas[i]["horas"]) / HORAS_CRESCER, 0.0, 1.0)


func _crescer_visual(i: int) -> void:
	var no: Node3D = _nos_planta[i]
	if no == null:
		return
	var f := crescido(i)
	var alvo: float = PLANTAS[i % PLANTAS.size()][1]
	var s := alvo * lerpf(0.12, 1.0, smoothstep(0.0, 1.0, f))
	(no.get_node("planta") as Node3D).scale = Vector3.ONE * s


func plantar() -> bool:
	if na_mao() <= 0 or plantas.size() >= BaseLar.horta_vagas.size():
		return false
	plantas.append({"horas": 0.0})
	_nascer(plantas.size() - 1)
	Som.toque3d(self, "folhagem_2", BaseLar.horta_vagas[plantas.size() - 1], -4.0)
	_guardar()
	if hud:
		hud.avisar("Plantou!", "cresce em umas oito horas do dia · com chuva, mais depressa")
	return true


## Quanto do canteiro está perto: o robô de pé, a menos de 2,6 m de alguma cova.
func _canteiro_perto() -> bool:
	if BaseLar.horta_vagas.is_empty() or armadura.estado != Armadura.Estado.CHAO or armadura.em_pane or armadura.no_assento \
			or armadura.escaneando or armadura.contemplando:
		return false
	var p := armadura.global_position
	for v: Vector3 in BaseLar.horta_vagas:
		if Vector2(p.x - v.x, p.z - v.z).length() < PERTO_PLANTAR and absf(p.y - v.y) < 2.0:
			return true
	return false


func _process(delta: float) -> void:
	if armadura == null:
		return
	# crescer: horas do dia do jogo (a chuva dobra o passo)
	var ciclo := CicloDia.atual
	if ciclo and not plantas.is_empty():
		var horas := delta * 24.0 / (ciclo.minutos_por_dia * 60.0) * (1.0 + ciclo.chuva)
		var mudou := false
		for i in plantas.size():
			var antes := crescido(i)
			if antes >= 1.0:
				continue
			plantas[i]["horas"] = float(plantas[i]["horas"]) + horas
			_crescer_visual(i)
			if crescido(i) >= 1.0:
				mudou = true
				if hud and armadura.global_position.distance_to(BaseLar.horta_vagas[i]) < 60.0:
					hud.avisar("A planta cresceu!", "%d de %d no canteiro" % [_crescidas(), BaseLar.horta_vagas.size()])
		_t += delta
		if mudou or _t > 20.0:
			_t = 0.0
			_guardar()
	# pegar a semente: é só passar por ela (andando ou baixinho no voo)
	var a := armadura.global_position
	for id: String in _soltas.keys():
		var no: Node3D = _soltas[id]
		var g := no.get_node("gira") as Node3D
		g.rotation.y += delta * 1.2
		g.position.y = 0.8 + 0.08 * sin(Time.get_ticks_msec() * 0.002 + no.global_position.x)
		var d := no.global_position - a
		if Vector2(d.x, d.z).length() < PERTO_PEGAR and absf(d.y + 0.5) < 2.6:
			_pegar(id)
	# plantar: o convite no canteiro, com semente na mão
	var perto := na_mao() > 0 and plantas.size() < BaseLar.horta_vagas.size() and _canteiro_perto()
	if hud:
		var novo := "{agir}  plantar" if perto else ""
		if hud.dica != novo and (perto or hud.dica == "{agir}  plantar"):
			hud.dica = novo
	_perto_canteiro = perto
	if perto and Input.is_action_just_pressed("agir"):
		plantar()


func _crescidas() -> int:
	var n := 0
	for i in plantas.size():
		if crescido(i) >= 1.0:
			n += 1
	return n
