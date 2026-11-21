class_name Acampamentos
extends Node3D
## Os acampamentos de máquinas (1.1, doc §136): quatro lugares no oeste e no sul onde as máquinas juntaram
## sucata em volta de um farolete vermelho. A briga é convidada: o farolete se vê de longe (e de noite pisca),
## a bússola mostra o acampamento perto, e quem não vai até lá não é incomodado.
## Cada máquina desligada ali dá o prêmio dela na hora, na conta da Fundição (o nível do acampamento faz as
## vezes da onda; pedido do usuário, 2026-11-21). Desligar todas ao mesmo tempo libera o lugar: o farolete fica
## verde, as máquinas dormem ali (ninguém é destruído), nascem flores em volta e os bichos voltam (um lugar novo
## de coelhos e pássaros na `VidaVale`).
## Depois de uns dias de jogo (`volta`, contados só jogando: um dia é uma hora), máquinas novas acham o lugar
## de novo, com o robô longe dali: o farolete volta ao vermelho, as flores e os bichos vão embora e o prêmio
## vale outra vez. Longo de propósito (pedido do usuário): vencer não pode parecer à toa.
## Quem cria passa `mapa`, `armadura`, `hud` e `vida`.

signal liberou(id: String)
signal reocupou(id: String)

## `volta`: dias de jogo até as máquinas voltarem (os maiores demoram mais)
const LISTA := [
	{"id": "planicie", "nome": "Acampamento da Planície", "pos": Vector2(-1040, 40), "maquinas": 3, "nivel": 3, "volta": 6.0},
	{"id": "capinzal", "nome": "Acampamento do Capinzal", "pos": Vector2(-300, 980), "maquinas": 3, "nivel": 5, "volta": 6.5},
	{"id": "barranco", "nome": "Acampamento do Barranco", "pos": Vector2(-500, 680), "maquinas": 4, "nivel": 8, "volta": 7.0},
	{"id": "planalto", "nome": "Acampamento do Planalto", "pos": Vector2(-620, 1040), "maquinas": 5, "nivel": 11, "volta": 8.0},
]
const ACORDA := 230.0
const DORME := 290.0
const BUSSOLA := 450.0  # a esta distância o acampamento aparece na bússola
const RAIO := 8.0  # onde as máquinas ficam, em volta do farolete
const VERMELHO := Color(1.0, 0.16, 0.1)
const VERDE := Color(0.3, 1.0, 0.45)
const OBJETOS := ["Prop_Crate_Tarp", "Prop_Barrel1", "Prop_Barrel_Large", "Prop_Crate4", "Prop_Crate_Tarp_Large", "Prop_Barrel2_Open", "Prop_Crate"]
const FLORES := ["q_flor_a", "q_flor_b", "q_flor_c", "q_flor_d", "q_moita_flor"]

static var livres: Array = []  # ids dos acampamentos já liberados
static var horas := {}  # id liberado -> horas de jogo desde a liberação
## Para a bússola da HUD: [posição, nome] dos que ainda têm máquinas
static var na_bussola: Array = []

var mapa: Vale
var armadura: Armadura
var hud: Hud
var vida: VidaVale
var camps := {}  # id -> {k, centro, maquinas, lampada, luz, ponto, flores, flores_no, bichos, ganho}
var liberados_agora := 0  # testes
var reocupados := 0  # testes

var _t := 0.0
var _hora_ant := -1.0
var _t_guardar := 0.0


func _ready() -> void:
	if Guardado.ativo:
		livres = (Guardado.progresso("acampamentos") as Array).duplicate()
		horas = (Guardado.progresso("acampamentos_horas") as Dictionary).duplicate()
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
	print("acampamentos: %d (%d liberados)" % [LISTA.size(), livres.size()])


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
	var c := _chao(d["pos"], 30.0)
	var no := Node3D.new()
	no.name = "Acampamento_" + id
	add_child(no)
	no.global_position = c
	var livre := livres.has(id)
	var camp := {"k": k, "centro": c, "no": no, "maquinas": [], "flores": [], "flores_no": null, "bichos": [], "ganho": {}}
	camps[id] = camp
	_farolete(camp, livre)
	# a sucata em roda: três pilhas de caixotes, lonas e barris, como barricadas, com vão entre elas
	var rng := RandomNumberGenerator.new()
	rng.seed = 6100 + k * 37
	for pilha in 3:
		var ang0 := pilha * TAU / 3.0 + 0.5 * k + rng.randf_range(-0.25, 0.25)
		var n := 3 + (k + pilha) % 2
		for j in n:
			var ang := ang0 + (j - (n - 1) * 0.5) * 0.15
			var r := 12.5 + rng.randf_range(-0.7, 0.7)
			var p := c + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			p.y = mapa.altura(p.x, p.z)
			_objeto(no, OBJETOS[(pilha * 3 + j + k) % OBJETOS.size()], p, -ang + rng.randf_range(-0.35, 0.35), rng.randf_range(1.25, 1.6))
	# as máquinas
	for i in int(d["maquinas"]):
		var ang := i * TAU / float(d["maquinas"]) + 0.4 * k
		var casa := c + Vector3(cos(ang) * RAIO, 0.0, sin(ang) * RAIO)
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
		_florir(camp, true)
		_bichos(camp)  # (antes só nasciam na hora da liberação: com o jogo carregado o lugar ficava sem bicho)


## O farolete: um poste de ferro de três pernas com a lâmpada lá em cima, a luz de verdade e o ponto de luz
## que se vê de longe de noite.
func _farolete(camp: Dictionary, livre: bool) -> void:
	var no: Node3D = camp["no"]
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color(0.22, 0.2, 0.18)
	ferro.metallic = 0.5
	ferro.roughness = 0.65
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 0.5, 2.0)
	base.mesh = bm
	var concreto := StandardMaterial3D.new()
	concreto.albedo_color = Color(0.42, 0.41, 0.38)
	base.material_override = concreto
	base.position = Vector3(0, 0.2, 0)
	no.add_child(base)
	var alto := 7.0
	var topo := Vector3(0, alto, 0)
	for i in 3:
		var a := i * TAU / 3.0
		_haste(no, Vector3(cos(a) * 0.8, 0.4, sin(a) * 0.8), topo - Vector3(0, 0.2, 0), 0.07, ferro)
	for h: float in [1.8, 3.6, 5.3]:
		var f := (h - 0.4) / (alto - 0.6)
		var rr := lerpf(0.8, 0.06, f)
		for i in 3:
			var a0 := i * TAU / 3.0
			var a1 := (i + 1) * TAU / 3.0
			_haste(no, Vector3(cos(a0) * rr, h, sin(a0) * rr), Vector3(cos(a1) * rr, h, sin(a1) * rr), 0.04, ferro)
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
	chapeu.material_override = ferro
	chapeu.position = topo + Vector3(0, 0.82, 0)
	no.add_child(chapeu)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 2.2
	luz.omni_range = 20.0
	luz.position = topo
	no.add_child(luz)
	var ponto := LuzesNoite.por(no, topo + Vector3(0, 0.25, 0), cor, 7.0, 0.0 if livre else 1.3)
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = 0.85
	cil.height = alto
	forma.shape = cil
	forma.position = Vector3(0, alto * 0.5, 0)
	corpo.add_child(forma)
	no.add_child(corpo)
	camp["lampada"] = mat
	camp["luz"] = luz
	camp["ponto"] = ponto
	camp["topo"] = no.global_position + topo


func _haste(pai: Node3D, a: Vector3, b: Vector3, raio: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = raio
	cil.bottom_radius = raio
	cil.height = a.distance_to(b)
	cil.radial_segments = 6
	mi.mesh = cil
	mi.material_override = mat
	pai.add_child(mi)
	mi.position = (a + b) * 0.5
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))


func _objeto(pai: Node3D, nome: String, pe: Vector3, giro: float, esc: float) -> void:
	var cena: PackedScene = load(BaseVale.PASTA + nome + ".gltf")
	if cena == null:
		return
	var raiz := cena.instantiate() as Node3D
	var caixa := BaseVale._caixa(raiz)
	var no := Node3D.new()
	no.add_child(raiz)
	raiz.position = -Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
	pai.add_child(no)
	no.global_transform = Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * esc), pe - Vector3(0, 0.05, 0))
	BaseVale.vestir(raiz, 0.7, 0.5, mapa._tex)
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var cx := BoxShape3D.new()
	cx.size = caixa.size * esc
	forma.shape = cx
	corpo.add_child(forma)
	pai.add_child(corpo)
	corpo.global_transform = Transform3D(Basis(Vector3.UP, giro), pe + Vector3(0, caixa.size.y * esc * 0.5 - 0.05, 0))


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
## piscando, as flores e os bichos vão embora e o acampamento volta à bússola.
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


## Flores e moitas floridas em volta do farolete e entre as máquinas; na hora da liberação elas crescem.
func _florir(camp: Dictionary, de_uma_vez: bool) -> void:
	var c: Vector3 = camp["centro"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(c.x * 13.0 + c.z * 7.0))
	var no := Node3D.new()
	no.name = "Flores"
	add_child(no)
	camp["flores_no"] = no
	for i in 70:
		var ang := rng.randf_range(0.0, TAU)
		var r := sqrt(rng.randf()) * 15.0 + 1.2
		var x := c.x + cos(ang) * r
		var z := c.z + sin(ang) * r
		if mapa.agua(x, z) != -INF:
			continue
		var tipo: String = FLORES[rng.randi() % FLORES.size()]
		if not mapa._malhas.has(tipo):
			continue
		var s := rng.randf_range(0.8, 1.3) * (1.4 if tipo == "q_moita_flor" else 1.0)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3(x, mapa.altura(x, z) - 0.03, z))
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
		for mc: Mecha in camps[id]["maquinas"]:
			if mc.process_mode == Node.PROCESS_MODE_DISABLED and d < ACORDA:
				mc.process_mode = Node.PROCESS_MODE_INHERIT
			elif mc.process_mode != Node.PROCESS_MODE_DISABLED and d > DORME:
				mc.process_mode = Node.PROCESS_MODE_DISABLED
