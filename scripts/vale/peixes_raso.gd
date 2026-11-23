class_name PeixesRaso
extends Node3D
## Peixes rente à superfície (2026-11-22, pedido do usuário: vistos do alto, como sombras que se mexem, com uns
## saltos de vez em quando). Os cardumes de VidaAgua nadam a meia água e só existem a 150 m do robô; estes ficam a
## um palmo da lâmina e nascem a 320 m, então se veem voando:
## - trutas nos rios, de duas a quatro, em voltas curtas, escuras de costas;
## - percas nos lagos, de quatro a oito;
## - sardinhas no mar raso perto da costa: uma bola apertada, prateada, com as gaivotas rodando em cima (AvesCeu
##   usa os mesmos pontos, `pontos_mar`).
## Fogem do robô e de vez em quando um salta (sinal `saltou`, para o anel na água; as sardinhas saltam em grupo).
## Nenhum nas fontes quentes nem debaixo da terra. Um MultiMesh por lugar, a cauda balançando no shader.

const PERTO := 320.0
const LONGE := 380.0
const MAR_LUGARES := 36
const RIO_PASSO := 95.0  # m entre dois lugares de trutas ao longo de um rio
const SALTO_PERTO := 160.0  # só salta com o robô a menos disso (o anel é pequeno)
const SALTO_DUR := 0.65

signal saltou(posicao: Vector3)

## tipo -> [forma, quantos (mín, máx), comprimento (mín, máx), fundura (mín, máx), raio das voltas (mín, máx),
##          altura do salto]
const TIPOS := {
	"truta": [FormasBicho.TRUTA, Vector2i(2, 4), Vector2(0.42, 0.6), Vector2(0.12, 0.3), Vector2(1.2, 3.0), 0.5],
	"perca": [FormasBicho.PERCA, Vector2i(4, 8), Vector2(0.3, 0.45), Vector2(0.12, 0.35), Vector2(2.0, 5.0), 0.4],
	"sardinha": [FormasBicho.SARDINHA, Vector2i(22, 34), Vector2(0.2, 0.28), Vector2(0.1, 0.4), Vector2(1.2, 3.6), 0.3],
}

var mapa: Vale
var alvo: Node3D
var lugares: Array[Dictionary] = []  # {tipo, pos (no nível da água), fundo, semente, no, peixes, t_salto, saltos}
var PERTO_FOTO := 0.0  # as fotos ligam: nascem a qualquer distância
var vivos := 0
var saltos := 0

var _rng := RandomNumberGenerator.new()
var _mats := {}
var _fila := 0
var _t := 0.0


func _ready() -> void:
	if mapa == null:
		push_error("peixes rasos: falta o mapa")
		return
	var t0 := Time.get_ticks_msec()
	_rng.seed = 6262
	var sh: Shader = load("res://scripts/shaders/bicho_lote.gdshader")
	for tipo: String in TIPOS:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("modo", 0)
		_mats[tipo] = [FormasBicho.peixe(TIPOS[tipo][0]), mat]
	_rios()
	_lagos()
	_mar()
	var n := {"truta": 0, "perca": 0, "sardinha": 0}
	for l in lugares:
		n[l["tipo"]] += 1
	print("peixes rasos: %d lugares de trutas, %d de percas, %d cardumes de sardinha, %d ms" % [n["truta"], n["perca"], n["sardinha"],
		Time.get_ticks_msec() - t0])


## Água boa para peixe raso: doce ou do mar, funda o bastante, fora das fontes quentes e das grutas.
func _agua_boa(x: float, z: float, fundo_min: float) -> float:
	var nivel := mapa.agua(x, z)
	if nivel == -INF or nivel - mapa.altura(x, z) < fundo_min:
		return -INF
	if mapa.fonte_em(x, z) > 0.0 or Sumidouro.agua(x, z) > -INF or Vector2(x, z).distance_to(BocaDegelo.NASCENTE) < 140.0:
		return -INF
	return nivel


func _novo(tipo: String, x: float, z: float, nivel: float) -> void:
	for l in lugares:
		var p: Vector3 = l["pos"]
		if Vector2(p.x, p.z).distance_to(Vector2(x, z)) < 45.0:
			return
	lugares.append({"tipo": tipo, "pos": Vector3(x, nivel, z), "fundo": mapa.altura(x, z), "semente": 500 + lugares.size() * 11,
		"no": null, "peixes": [], "t_salto": _rng.randf_range(4.0, 20.0), "salto": {}})


## Ao longo de cada rio (os da ilha de hoje e os da terra nova), um lugar a cada tanto onde a água dá fundo.
func _rios() -> void:
	var cursos: Array = mapa._cursos.duplicate()
	if mapa.terra_nova:
		cursos.append_array(mapa.terra_nova.rios)
	for c: Vale.Curso in cursos:
		var falta := RIO_PASSO * 0.5
		for i in range(1, c.pts.size()):
			falta -= c.pts[i].distance_to(c.pts[i - 1])
			if falta > 0.0:
				continue
			falta = RIO_PASSO
			var q := c.pts[i]
			var nivel := _agua_boa(q.x, q.y, 0.55)
			if nivel > Vale.MAR + 0.5:
				_novo("truta", q.x, q.y, nivel)


## Nos lagos: um lugar de percas a cada 40 m de raio, longe da beira.
func _lagos() -> void:
	var lagos: Array = []
	if mapa.terra_nova:
		for l: Array in mapa.terra_nova.lagos:
			lagos.append([l[0], float(l[1])])
	lagos.append([Vector2(Vale.REPRESA_LAGOA.x, Vale.REPRESA_LAGOA.y), Vale.REPRESA_LAGOA.z])
	for l: Array in lagos:
		var c: Vector2 = l[0]
		var r: float = l[1]
		var quantos := clampi(int(r / 40.0), 1, 4)
		var feitos := 0
		for k in 40:
			if feitos >= quantos:
				break
			var p := c + Vector2.from_angle(_rng.randf() * TAU) * r * _rng.randf_range(0.3, 0.75)
			var nivel := _agua_boa(p.x, p.y, 0.9)
			if nivel > Vale.MAR + 0.5:
				var antes := lugares.size()
				_novo("perca", p.x, p.y, nivel)
				if lugares.size() > antes:
					feitos += 1


## No mar raso perto da costa: entre 1,3 e 7 m de fundo, com terra a menos de 160 m e nada de arrebentação em volta.
func _mar() -> void:
	var feitos := 0
	var tent := 0
	while feitos < MAR_LUGARES and tent < 9000:
		tent += 1
		var x := _rng.randf_range(-3900.0, 1500.0)
		var z := _rng.randf_range(-3900.0, 1500.0)
		var h := mapa.altura(x, z)
		if h > Vale.MAR - 1.3 or h < Vale.MAR - 7.0:
			continue
		var costa := false
		var rente := false
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0)
			if mapa.altura(x + d.x * 28.0, z + d.y * 28.0) > Vale.MAR - 0.4:
				rente = true
				break
			for r: float in [80.0, 160.0]:
				if mapa.altura(x + d.x * r, z + d.y * r) > Vale.MAR + 0.5:
					costa = true
		if rente or not costa or _agua_boa(x, z, 1.3) == -INF:
			continue
		var perto := false
		for l in lugares:
			if l["tipo"] == "sardinha" and Vector2((l["pos"] as Vector3).x, (l["pos"] as Vector3).z).distance_to(Vector2(x, z)) < 220.0:
				perto = true
				break
		if perto:
			continue
		var antes := lugares.size()
		_novo("sardinha", x, z, Vale.MAR)
		if lugares.size() > antes:
			feitos += 1


## Os cardumes do mar, para as gaivotas.
func pontos_mar() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for l in lugares:
		if l["tipo"] == "sardinha":
			out.append(l["pos"])
	return out


func _process(delta: float) -> void:
	if alvo == null or lugares.is_empty():
		return
	_t += delta
	var a := alvo.global_position
	for k in 4:
		_fila = (_fila + 1) % lugares.size()
		var l := lugares[_fila]
		var p: Vector3 = l["pos"]
		var d := Vector2(a.x - p.x, a.z - p.z).length()
		if l["no"] == null and d < maxf(PERTO, PERTO_FOTO):
			_criar(l)
			vivos += 1
		elif l["no"] != null and d > maxf(LONGE, PERTO_FOTO):
			(l["no"] as Node).queue_free()
			l["no"] = null
			l["peixes"] = []
			l.erase("nervosa")
			vivos -= 1
	for l: Dictionary in lugares:
		if l["no"] != null:
			_nadar(l, a, delta)


func _criar(l: Dictionary) -> void:
	var tipo: String = l["tipo"]
	var d: Array = TIPOS[tipo]
	var par: Array = _mats[tipo]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(l["semente"])
	var q: Vector2i = d[1]
	var quantos := rng.randi_range(q.x, q.y)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = par[0]
	mm.instance_count = quantos
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = par[1]
	# com sombra: na água rasa e clara é a sombra no fundo que mostra o peixe, visto do alto
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mmi.custom_aabb = AABB(Vector3(-16, -3, -16), Vector3(32, 6, 32))
	add_child(mmi)
	mmi.global_position = l["pos"]
	var peixes: Array = []
	var nivel: float = (l["pos"] as Vector3).y
	var fundo := float(l["fundo"])
	var comp_r: Vector2 = d[2]
	var prof_r: Vector2 = d[3]
	var raio_r: Vector2 = d[4]
	for i in quantos:
		var comp := rng.randf_range(comp_r.x, comp_r.y)
		var prof := minf(rng.randf_range(prof_r.x, prof_r.y), nivel - fundo - 0.12)
		var px := {"tam": comp, "prof": maxf(0.08, prof), "raio": rng.randf_range(raio_r.x, raio_r.y), "fase": rng.randf() * TAU,
			"vel": rng.randf_range(0.25, 0.55) * (1.0 if rng.randf() < 0.75 or tipo == "sardinha" else -1.0), "susto": 0.0,
			"v": Vector3.ZERO, "pos": (l["pos"] as Vector3) + Vector3(rng.randf_range(-2, 2), -prof, rng.randf_range(-2, 2))}
		if tipo == "sardinha":
			px["vel"] = 0.55
			px["fase"] = rng.randf_range(0.0, 1.2)  # andam juntas, quase em fila na volta
		peixes.append(px)
		mm.set_instance_custom_data(i, Color(rng.randf() * TAU, rng.randf_range(2.3, 3.4) if tipo != "sardinha" else 4.5, 0.09, 0.0))
	l["peixes"] = peixes
	l["no"] = mmi
	if tipo == "sardinha":
		var pm := PlaneMesh.new()
		pm.size = Vector2(16.0, 16.0)
		var nervosa := MeshInstance3D.new()
		nervosa.name = "AguaNervosa"
		nervosa.mesh = pm
		nervosa.material_override = _mat_nervosa()
		nervosa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nervosa.position = Vector3(0, 0.03, 0)
		mmi.add_child(nervosa)
		l["nervosa"] = nervosa


var _nervosa: ShaderMaterial

func _mat_nervosa() -> ShaderMaterial:
	if _nervosa == null:
		_nervosa = ShaderMaterial.new()
		_nervosa.shader = load("res://scripts/shaders/agua_nervosa.gdshader")
	return _nervosa


## Cada peixe dá voltas no seu raio, o lugar inteiro deriva devagar; o robô rente à água espanta; de vez em quando
## um salta (as sardinhas, umas quantas de uma vez).
func _nadar(l: Dictionary, a: Vector3, delta: float) -> void:
	var mmi := l["no"] as MultiMeshInstance3D
	var mm := mmi.multimesh
	var centro: Vector3 = l["pos"]
	var nivel := centro.y
	var semente := float(l["semente"])
	var tipo: String = l["tipo"]
	var deriva := Vector3(sin(_t * 0.05 + semente), 0, cos(_t * 0.04 + semente)) * (8.0 if tipo == "sardinha" else 3.0)
	if l.has("nervosa"):
		(l["nervosa"] as Node3D).position = deriva + Vector3(0, 0.03, 0)
	var peixes: Array = l["peixes"]
	var perto_robo := a.y < nivel + 3.5
	var salto: Dictionary = l["salto"]
	for i in peixes.size():
		var px: Dictionary = peixes[i]
		if salto.has(i):
			continue
		var fase := float(px["fase"]) + _t * float(px["vel"])
		var r: float = px["raio"]
		var alvo_p := centro + deriva + Vector3(cos(fase) * r, -float(px["prof"]), sin(fase * 1.13) * r)
		var pos: Vector3 = px["pos"]
		var vel_alvo := (alvo_p - pos).limit_length(1.0) * 1.4
		var foge := Vector3(pos.x - a.x, 0.0, pos.z - a.z)
		if perto_robo and foge.length() < 7.0:
			vel_alvo = foge.normalized() * 5.0
			px["susto"] = 1.0
		var vel: Vector3 = (px["v"] as Vector3).lerp(vel_alvo, 1.0 - exp(-(5.0 if float(px["susto"]) > 0.0 else 2.0) * delta))
		px["susto"] = maxf(0.0, float(px["susto"]) - delta)
		pos += vel * delta
		pos.y = nivel - float(px["prof"])
		px["v"] = vel
		px["pos"] = pos
		var frente := Vector3(vel.x, 0.0, vel.z)
		if frente.length() < 0.03:
			frente = Vector3(cos(fase + 1.57), 0.0, sin(fase + 1.57))
		var base := Basis.looking_at(frente.normalized(), Vector3.UP)
		mm.set_instance_transform(i, Transform3D(base.scaled(Vector3.ONE * float(px["tam"])), pos - centro))
	# os saltos
	var d := Vector2(a.x - centro.x, a.z - centro.z).length()
	if salto.is_empty() and d < maxf(SALTO_PERTO, PERTO_FOTO):
		l["t_salto"] = float(l["t_salto"]) - delta
		if float(l["t_salto"]) <= 0.0:
			_saltar(l)
	_mover_saltos(l, delta)


func _saltar(l: Dictionary) -> void:
	var peixes: Array = l["peixes"]
	if peixes.is_empty():
		return
	var tipo: String = l["tipo"]
	var quantos := _rng.randi_range(3, 6) if tipo == "sardinha" else 1
	var salto: Dictionary = l["salto"]
	var nivel: float = (l["pos"] as Vector3).y
	for k in quantos:
		var i := _rng.randi() % peixes.size()
		if salto.has(i):
			continue
		var px: Dictionary = peixes[i]
		var de: Vector3 = px["pos"]
		var v: Vector3 = px["v"]
		var dir := Vector3(v.x, 0, v.z).normalized() if Vector2(v.x, v.z).length() > 0.05 else Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
		var alcance := _rng.randf_range(0.6, 1.1) * (1.5 if tipo == "truta" else 1.0)
		var para := de + dir * alcance
		if mapa.agua(para.x, para.z) == -INF:
			para = de - dir * alcance
		salto[i] = {"de": de, "para": Vector3(para.x, de.y, para.z), "t": -k * 0.12, "alto": float(TIPOS[tipo][5]) * _rng.randf_range(0.7, 1.1),
			"saiu": false}
	l["t_salto"] = _rng.randf_range(10.0, 35.0)
	saltos += 1


func _mover_saltos(l: Dictionary, delta: float) -> void:
	var salto: Dictionary = l["salto"]
	if salto.is_empty():
		return
	var mm := (l["no"] as MultiMeshInstance3D).multimesh
	var centro: Vector3 = l["pos"]
	var nivel := centro.y
	var peixes: Array = l["peixes"]
	for i: int in salto.keys():
		var s: Dictionary = salto[i]
		s["t"] = float(s["t"]) + delta
		var u := float(s["t"]) / SALTO_DUR
		if u < 0.0:
			continue
		var de: Vector3 = s["de"]
		var para: Vector3 = s["para"]
		if not s["saiu"]:
			s["saiu"] = true
			saltou.emit(Vector3(de.x, nivel, de.z))
		if u >= 1.0:
			saltou.emit(Vector3(para.x, nivel, para.z))
			var px: Dictionary = peixes[i]
			px["pos"] = para
			salto.erase(i)
			continue
		var p := de.lerp(para, u)
		p.y = lerpf(de.y, para.y, u) + (float(s["alto"]) + (nivel - de.y)) * 4.0 * u * (1.0 - u)
		var dv := (para - de).normalized()
		var subida := (1.0 - 2.0 * u) * 4.0 * (float(s["alto"]) + (nivel - de.y)) / maxf(0.1, de.distance_to(para))
		var frente := (dv + Vector3(0, subida, 0)).normalized()
		var base := Basis.looking_at(frente, Vector3.UP if absf(frente.y) < 0.95 else Vector3.RIGHT)
		mm.set_instance_transform(i, Transform3D(base.scaled(Vector3.ONE * float((peixes[i] as Dictionary)["tam"])), p - centro))
