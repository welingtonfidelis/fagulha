class_name AvesCeu
extends Node3D
## Os pássaros do céu (2026-11-22, pedido do usuário: vista do alto, a ilha parecia vazia de bichos). Bandos em
## lote: um MultiMesh por bando, com o voo inteiro no shader ave_ceu (o processador só arrasta o meio do bando
## devagar), então custam uma chamada de desenho por bando e quase nada de processador. Cada um no seu canto
## (fauna com moderação, que combine com o lugar):
## - andorinhas em bandos pequenos, rente ao campo aberto e às águas doces, em voltas rápidas e tortas;
## - gaviões sozinhos ou em par, planando em voltas largas e altas sobre os morros e a mata;
## - gaivotas em volta dos cardumes rasos do mar, perto da costa (os pontos vêm de PeixesRaso);
## - um bando de gansos em V que cruza a ilha de tempos em tempos, bem alto.
## Só de dia e sem chuva forte. Sem física nem colisão.

const ANDORINHAS := 10
const ANDORINHAS_LAGO := 2  # dos bandos de andorinhas, quantos ficam sobre os lagos da terra nova
const GAVIOES := 5
const GAIVOTAS := 8
const GANSOS := 11
const GANSO_VEL := 13.0  # m/s
const GANSO_ROTA := 5200.0  # m de uma travessia
const MUNDO := Rect2(-3900.0, -3900.0, 5400.0, 5400.0)

var mapa: Vale
var pontos_mar: Array[Vector3] = []  # os cardumes rasos do mar (PeixesRaso): as gaivotas rodam em cima deles
var bandos: Array[Dictionary] = []  # {no, tipo, casa, alt, fase, y}
var ganso: Dictionary = {}  # o bando em V: {no, de, para, t, dur, espera}

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _mats := {}


func _ready() -> void:
	if mapa == null:
		push_error("aves do céu: falta o mapa")
		return
	_rng.seed = 7171
	var t0 := Time.get_ticks_msec()
	_materiais()
	_andorinhas()
	_gavioes()
	_gaivotas()
	_gansos()
	print("aves do céu: %d bandos de andorinhas, %d de gaviões, %d de gaivotas e um V de %d gansos, %d ms" % [_conta("andorinha"),
		_conta("gaviao"), _conta("gaivota"), GANSOS, Time.get_ticks_msec() - t0])


func _conta(tipo: String) -> int:
	var n := 0
	for b in bandos:
		if b["tipo"] == tipo:
			n += 1
	return n


func _materiais() -> void:
	var sh: Shader = load("res://scripts/shaders/ave_ceu.gdshader")
	# tipo: [forma, modo, batidas/s, amplitude, diedro, plana]
	var tipos := {"andorinha": [FormasBicho.ANDORINHA, 0, 9.0, 0.75, 0.05, 0.55], "gaviao": [FormasBicho.GAVIAO, 1, 3.0, 0.45, 0.14, 0.93],
		"gaivota": [FormasBicho.GAIVOTA, 2, 2.6, 0.6, 0.1, 0.6], "ganso": [FormasBicho.GANSO, 3, 3.2, 0.55, 0.05, -1.0]}
	for tipo: String in tipos:
		var d: Array = tipos[tipo]
		var forma: Dictionary = d[0]
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("modo", d[1])
		mat.set_shader_parameter("bate", d[2])
		mat.set_shader_parameter("amp", d[3])
		mat.set_shader_parameter("diedro", d[4])
		mat.set_shader_parameter("plana", d[5])
		mat.set_shader_parameter("ombro", float(forma["raio"]) * 0.6)
		_mats[tipo] = [FormasBicho.ave(forma), mat]


## Um bando: o MultiMesh com um pássaro por linha de `aves` ([canto no bando, fase, velocidade, raio, altura]).
func _bando(tipo: String, aves: Array, escala: float, caixa: float, longe: float) -> MultiMeshInstance3D:
	var par: Array = _mats[tipo]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = par[0]
	mm.instance_count = aves.size()
	for i in aves.size():
		var a: Array = aves[i]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * escala), a[0]))
		mm.set_instance_custom_data(i, Color(a[1], a[2], a[3], a[4]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Bando_" + tipo
	mmi.multimesh = mm
	mmi.material_override = par[1]
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-caixa, -caixa * 0.4, -caixa), Vector3(caixa * 2.0, caixa * 0.8, caixa * 2.0))
	mmi.visibility_range_end = longe
	add_child(mmi)
	return mmi


## O chão mais alto em volta de um ponto (água doce conta como chão): para os bandos não entrarem no morro.
func _teto_chao(x: float, z: float, raio: float, n := 8) -> float:
	var mx := maxf(mapa.altura(x, z), mapa.agua(x, z))
	for k in n:
		var a := TAU * k / n
		var px := x + cos(a) * raio
		var pz := z + sin(a) * raio
		mx = maxf(mx, maxf(mapa.altura(px, pz), mapa.agua(px, pz)))
	return maxf(mx, Vale.MAR)


func _sortear_terra(quantos: int, afastado: float, ok: Callable) -> Array[Vector2]:
	var feitos: Array[Vector2] = []
	var tent := 0
	while feitos.size() < quantos and tent < quantos * 600:
		tent += 1
		var p := MUNDO.position + Vector2(_rng.randf(), _rng.randf()) * MUNDO.size
		if not ok.call(p):
			continue
		var livre := true
		for q in feitos:
			if q.distance_to(p) < afastado:
				livre = false
				break
		if livre:
			feitos.append(p)
	return feitos


# ---------------------------------------------------------------- andorinhas

func _andorinhas() -> void:
	var casas: Array[Vector2] = []
	if mapa.terra_nova:
		for l: Array in mapa.terra_nova.lagos:
			if casas.size() < ANDORINHAS_LAGO and float(l[2]) < 150.0:  # o lago do circo, gelado, lá no alto, fica sem
				casas.append(l[0])
	var campo := func(p: Vector2) -> bool:
		var h := mapa.altura(p.x, p.y)
		if h < Vale.MAR + 3.0 or h > 300.0 or mapa.agua(p.x, p.y) > -INF:
			return false
		var c := mapa.cobertura(p.x, p.y)
		return (c == 0 or c == 3) and mapa.normal_em(p.x, p.y).y > 0.9 and Vector2(p.x, p.y).length() > 60.0
	casas.append_array(_sortear_terra(ANDORINHAS - casas.size(), 380.0, campo))
	for c in casas:
		var aves := []
		for i in _rng.randi_range(8, 13):
			aves.append([Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)), _rng.randf() * TAU, _rng.randf_range(0.85, 1.25),
				_rng.randf_range(8.0, 17.0), _rng.randf_range(1.5, 4.0)])
		var no := _bando("andorinha", aves, 1.3, 45.0, 380.0)
		var b := {"no": no, "tipo": "andorinha", "casa": c, "alt": _rng.randf_range(7.0, 13.0), "fase": _rng.randf() * TAU, "y": -INF}
		bandos.append(b)
		_mover_andorinhas(b, 0.0, true)


## O meio do bando passeia devagar em volta da casa, sempre um tanto acima do chão mais alto ali.
func _mover_andorinhas(b: Dictionary, delta: float, ja := false) -> void:
	var c: Vector2 = b["casa"]
	var f: float = b["fase"]
	var p := c + Vector2(cos(_t * 0.031 + f) * 70.0, sin(_t * 0.023 + f * 1.7) * 70.0)
	var y := _teto_chao(p.x, p.y, 18.0, 4) + float(b["alt"])
	var y0: float = b["y"]
	y = y if ja or y0 == -INF else lerpf(y0, y, 1.0 - exp(-0.8 * delta))
	b["y"] = y
	(b["no"] as Node3D).position = Vector3(p.x, y, p.y)


# ---------------------------------------------------------------- gaviões

func _gavioes() -> void:
	var morro := func(p: Vector2) -> bool:
		var h := mapa.altura(p.x, p.y)
		return h > 35.0 and h < 420.0 and mapa.agua(p.x, p.y) == -INF and p.length() > 200.0
	for c in _sortear_terra(GAVIOES, 750.0, morro):
		var y := _teto_chao(c.x, c.y, 140.0, 12) + _rng.randf_range(55.0, 95.0)
		var aves := []
		var sentido := 1.0 if _rng.randf() < 0.5 else -1.0
		var dois := _rng.randf() < 0.45
		for i in (2 if dois else 1):
			aves.append([Vector3(i * 18.0, i * 7.0, -i * 12.0), _rng.randf() * TAU, sentido * TAU / _rng.randf_range(36.0, 52.0),
				_rng.randf_range(45.0, 80.0), _rng.randf_range(3.0, 7.0)])
		var no := _bando("gaviao", aves, 1.15, 120.0, 1300.0)
		no.position = Vector3(c.x, y, c.y)
		bandos.append({"no": no, "tipo": "gaviao", "casa": c, "alt": y, "fase": _rng.randf() * TAU, "y": y})


# ---------------------------------------------------------------- gaivotas

func _gaivotas() -> void:
	var casas: Array[Vector3] = []
	for p in pontos_mar:
		var livre := true
		for q in casas:
			if Vector2(q.x, q.z).distance_to(Vector2(p.x, p.z)) < 400.0:
				livre = false
				break
		if livre and casas.size() < GAIVOTAS:
			casas.append(p)
	for c in casas:
		var aves := []
		for i in _rng.randi_range(3, 6):
			var sentido := 1.0 if _rng.randf() < 0.7 else -1.0
			aves.append([Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-3, 3), _rng.randf_range(-8, 8)), _rng.randf() * TAU,
				sentido * _rng.randf_range(0.12, 0.2), _rng.randf_range(14.0, 28.0), _rng.randf_range(2.0, 5.0)])
		var no := _bando("gaivota", aves, 1.1, 70.0, 900.0)
		no.position = Vector3(c.x, Vale.MAR + _rng.randf_range(12.0, 20.0), c.z)
		bandos.append({"no": no, "tipo": "gaivota", "casa": Vector2(c.x, c.z), "alt": no.position.y, "fase": 0.0, "y": no.position.y})


# ---------------------------------------------------------------- o bando em V

func _gansos() -> void:
	var aves := []
	for i in GANSOS:
		var lado := 0.0 if i == 0 else (1.0 if i % 2 == 1 else -1.0)
		var fila := floorf((i + 1) * 0.5)
		aves.append([Vector3(lado * fila * 2.4, -fila * 0.12, fila * 2.7), _rng.randf() * TAU, 1.0, 0.0, 0.0])
	var no := _bando("ganso", aves, 1.0, 40.0, 1600.0)
	no.visible = false
	ganso = {"no": no, "de": Vector3.ZERO, "para": Vector3.ZERO, "t": 0.0, "dur": 1.0, "espera": _rng.randf_range(20.0, 45.0)}


## Uma travessia: uma reta por cima da ilha, alta o bastante para passar por cima de tudo no caminho.
func _rota_ganso() -> void:
	var meio := Vector2(_rng.randf_range(-3200.0, 900.0), _rng.randf_range(-3200.0, 900.0))
	var dir := Vector2.from_angle(_rng.randf() * TAU)
	var de := meio - dir * GANSO_ROTA * 0.5
	var para := meio + dir * GANSO_ROTA * 0.5
	var topo := Vale.MAR + 110.0
	for k in 53:
		var p := de.lerp(para, k / 52.0)
		topo = maxf(topo, mapa.altura(p.x, p.y) + 90.0)
	topo += _rng.randf_range(0.0, 30.0)
	ganso["de"] = Vector3(de.x, topo, de.y)
	ganso["para"] = Vector3(para.x, topo, para.y)
	ganso["t"] = 0.0
	ganso["dur"] = GANSO_ROTA / GANSO_VEL
	var no := ganso["no"] as MultiMeshInstance3D
	no.set_instance_shader_parameter("rumo", Vector3(dir.x, 0.0, dir.y))
	no.position = ganso["de"]
	no.visible = true


func _mover_ganso(delta: float) -> void:
	var no := ganso["no"] as MultiMeshInstance3D
	if not no.visible:
		ganso["espera"] = float(ganso["espera"]) - delta
		if float(ganso["espera"]) <= 0.0:
			_rota_ganso()
		return
	ganso["t"] = float(ganso["t"]) + delta
	var u := float(ganso["t"]) / float(ganso["dur"])
	if u >= 1.0:
		no.visible = false
		ganso["espera"] = _rng.randf_range(70.0, 200.0)
		return
	no.position = (ganso["de"] as Vector3).lerp(ganso["para"], u)


## Põe o bando em V já cruzando perto de um ponto (fotos).
func ganso_perto(p: Vector3, rumo: Vector2) -> void:
	var dir := rumo.normalized()
	var de := Vector2(p.x, p.z) - dir * GANSO_ROTA * 0.5
	ganso["de"] = Vector3(de.x, p.y, de.y)
	ganso["para"] = Vector3(de.x + dir.x * GANSO_ROTA, p.y, de.y + dir.y * GANSO_ROTA)
	ganso["dur"] = GANSO_ROTA / GANSO_VEL
	ganso["t"] = float(ganso["dur"]) * 0.5
	var no := ganso["no"] as MultiMeshInstance3D
	no.set_instance_shader_parameter("rumo", Vector3(dir.x, 0.0, dir.y))
	no.position = p
	no.visible = true


## Onde um pássaro de um bando está agora: a mesma conta do shader ave_ceu (fotos e testes).
func onde(b: Dictionary, i: int) -> Vector3:
	var no := b["no"] as MultiMeshInstance3D
	var d := no.multimesh.get_instance_custom_data(i)
	var o := no.multimesh.get_instance_transform(i).origin
	var t := _t
	var p := o
	match b["tipo"]:
		"andorinha":
			var a1 := d.g * (0.55 + 0.18 * sin(d.r * 3.1))
			var a2 := d.g * (0.47 + 0.18 * cos(d.r * 2.3))
			p += Vector3(d.b * sin(a1 * t + d.r), d.a * sin(d.g * 0.33 * t + d.r * 1.7), d.b * sin(a2 * t + d.r * 2.3 + 1.0))
		"gaviao":
			var r := d.b * (1.0 + 0.25 * sin(t * 0.05 + d.r))
			p += Vector3(r * cos(d.g * t + d.r), d.a * sin(t * 0.11 + d.r), r * sin(d.g * t + d.r))
		"gaivota":
			p += Vector3(d.b * cos(d.g * t + d.r) + 0.5 * d.b * sin(0.23 * t + d.r * 2.0), d.a * sin(0.31 * t + d.r * 1.3),
				d.b * sin(d.g * t + d.r) + 0.5 * d.b * cos(0.19 * t + d.r * 1.7))
	return no.global_position + p


func _process(delta: float) -> void:
	_t = fposmod(_t + delta, 7200.0)  # volta a zero a cada duas horas: com mais que isso a batida de asa perde precisão
	RenderingServer.global_shader_parameter_set("tempo_bichos", _t)
	var ciclo := CicloDia.atual
	visible = ciclo == null or (not ciclo.eh_noite() and ciclo.chuva < 0.55)
	if not visible:
		return
	for b in bandos:
		if b["tipo"] == "andorinha":
			_mover_andorinhas(b, delta)
	_mover_ganso(delta)
