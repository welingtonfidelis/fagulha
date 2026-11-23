class_name Insetos
extends Node3D
## Borboletas nos campos de flores e libélulas sobre a água doce (2026-11-22, pedido do usuário: a ilha parecia
## vazia de bichos). São pequenas, então só existem perto do robô: a cada tanto um lugar é sorteado em volta dele
## (flor para a borboleta, água doce rasa e calma para a libélula), e o inseto some quando ele se afasta. Um
## MultiMesh de cada, com as asas batendo no shader (bicho_lote, modos 2 e 3). Só de dia e sem chuva.

const BORBOLETAS := 14
const LIBELULAS := 6
const RAIO := 30.0  # onde nascem (em volta do robô)
const PERTO_MIN := 5.0  # não nascem no pé dele
const SOME := 46.0
const CORES_BORB := [Color(0.98, 0.82, 0.18), Color(0.97, 0.97, 0.93), Color(0.95, 0.52, 0.14), Color(0.42, 0.6, 0.97),
	Color(0.97, 0.97, 0.93), Color(0.98, 0.82, 0.18)]
const CORES_LIB := [Color(0.18, 0.5, 0.95), Color(0.22, 0.72, 0.42), Color(0.85, 0.22, 0.14)]

var mapa: Vale
var alvo: Node3D
var borboletas: Array[Dictionary] = []  # {ativo, casa, pos, fase, cor}
var libelulas: Array[Dictionary] = []  # {ativo, casa, pos, mira, t, rumo}
var ativos := 0

var _mm_b: MultiMesh
var _mm_l: MultiMesh
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _t_busca := 0.0


func _ready() -> void:
	if mapa == null:
		push_error("insetos: falta o mapa")
		return
	_rng.seed = 909
	var sh: Shader = load("res://scripts/shaders/bicho_lote.gdshader")
	_mm_b = _lote(sh, FormasBicho.borboleta(), 2, BORBOLETAS)
	_mm_l = _lote(sh, FormasBicho.libelula(), 3, LIBELULAS)
	for i in BORBOLETAS:
		var c: Color = CORES_BORB[i % CORES_BORB.size()]
		borboletas.append({"ativo": false, "casa": Vector3.ZERO, "pos": Vector3.ZERO, "fase": _rng.randf() * TAU, "cor": c})
		_mm_b.set_instance_custom_data(i, Color(c.r, c.g, c.b, _rng.randf()))
	for i in LIBELULAS:
		var c: Color = CORES_LIB[i % CORES_LIB.size()]
		libelulas.append({"ativo": false, "casa": Vector3.ZERO, "pos": Vector3.ZERO, "mira": Vector3.ZERO, "t": 0.0, "rumo": Vector3.FORWARD})
		_mm_l.set_instance_custom_data(i, Color(c.r, c.g, c.b, _rng.randf()))


func _lote(sh: Shader, malha: Mesh, modo: int, quantos: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = malha
	mm.instance_count = quantos
	for i in quantos:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("modo", modo)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-5000, -100, -5000), Vector3(10000, 1200, 10000))
	add_child(mmi)
	return mm


func _flor(x: float, z: float) -> bool:
	if mapa.agua(x, z) > -INF or mapa.altura(x, z) < Vale.MAR + 0.5:
		return false
	return mapa.cobertura(x, z) == 3 or CapimVivo._florido(x, z)


## Água doce para libélula: rasa, sem correnteza forte (lago, remanso), fora das fontes quentes e das grutas.
func _agua_doce(x: float, z: float) -> float:
	var nivel := mapa.agua(x, z)
	if nivel == -INF or nivel < Vale.MAR + 0.3 or mapa.fonte_em(x, z) > 0.0 or Sumidouro.agua(x, z) > -INF:
		return -INF
	return nivel


func _process(delta: float) -> void:
	if alvo == null:
		return
	_t += delta
	var ciclo := CicloDia.atual
	var tempo_bom := ciclo == null or (not ciclo.eh_noite() and ciclo.chuva < 0.3 and ciclo.escuro < 0.5)
	var a := alvo.global_position
	_t_busca -= delta
	if _t_busca <= 0.0 and tempo_bom:
		_t_busca = 0.35
		_buscar(a)
	ativos = 0
	for i in borboletas.size():
		var b := borboletas[i]
		if b["ativo"] and (not tempo_bom or Vector2(a.x - b["casa"].x, a.z - b["casa"].z).length() > SOME):
			b["ativo"] = false
		if not b["ativo"]:
			_mm_b.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		ativos += 1
		_borboleta(i, b, a, delta)
	for i in libelulas.size():
		var l := libelulas[i]
		if l["ativo"] and (not tempo_bom or Vector2(a.x - l["casa"].x, a.z - l["casa"].z).length() > SOME):
			l["ativo"] = false
		if not l["ativo"]:
			_mm_l.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		ativos += 1
		_libelula(i, l, a, delta)


## Sorteia uns pontos em volta do robô; um bom vira a casa de um inseto que estava parado.
func _buscar(a: Vector3) -> void:
	for tentativa in 6:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(PERTO_MIN, RAIO)
		var x := a.x + cos(ang) * r
		var z := a.z + sin(ang) * r
		if _flor(x, z):
			for b in borboletas:
				if not b["ativo"]:
					b["ativo"] = true
					b["casa"] = Vector3(x, mapa.altura(x, z) + _rng.randf_range(1.25, 1.9), z)  # o capim chega a 1 m
					b["fase"] = _rng.randf() * TAU
					b["pos"] = b["casa"]
					break
			continue
		var nivel := _agua_doce(x, z)
		if nivel > -INF and nivel - mapa.altura(x, z) < 3.0:
			for l in libelulas:
				if not l["ativo"]:
					l["ativo"] = true
					var casa := Vector3(x, nivel + _rng.randf_range(0.4, 0.9), z)
					l["casa"] = casa
					l["pos"] = casa
					l["mira"] = casa
					l["t"] = 0.0
					break


func _borboleta(i: int, b: Dictionary, a: Vector3, delta: float) -> void:
	var f: float = b["fase"]
	var casa: Vector3 = b["casa"]
	# o robô chegando: a casa foge para o lado e um pouco para cima
	var longe := Vector3(casa.x - a.x, 0.0, casa.z - a.z)
	if longe.length() < 3.0:
		casa += longe.normalized() * 3.0 * delta + Vector3(0, 0.6 * delta, 0)
		b["casa"] = casa
	var t := _t
	var off := Vector3(sin(t * 0.8 + f) * 2.0 + sin(t * 2.3 + f * 2.0) * 0.45, sin(t * 2.7 + f) * 0.25 + sin(t * 6.3 + f) * 0.07,
		cos(t * 0.65 + f * 1.3) * 2.0 + cos(t * 1.9 + f) * 0.45)
	var pos := casa + off
	var chao := mapa.altura(pos.x, pos.z) + 1.05
	pos.y = maxf(pos.y, chao)
	var ant: Vector3 = b["pos"]
	b["pos"] = pos
	var v := pos - ant
	var frente := Vector3(v.x, 0.0, v.z)
	if frente.length() < 0.0005:
		frente = Vector3.FORWARD
	var base := Basis.looking_at(frente.normalized(), Vector3.UP)
	_mm_b.set_instance_transform(i, Transform3D(base.scaled(Vector3.ONE * 1.8), pos))


func _libelula(i: int, l: Dictionary, a: Vector3, delta: float) -> void:
	var casa: Vector3 = l["casa"]
	l["t"] = float(l["t"]) - delta
	if float(l["t"]) <= 0.0:
		l["t"] = _rng.randf_range(0.7, 2.6)
		var nova := casa + Vector3(_rng.randf_range(-3.5, 3.5), _rng.randf_range(-0.2, 0.3), _rng.randf_range(-3.5, 3.5))
		if _agua_doce(nova.x, nova.z) == -INF:
			nova = casa
		l["mira"] = nova
	var mira: Vector3 = l["mira"]
	var longe := Vector3(mira.x - a.x, 0.0, mira.z - a.z)
	if longe.length() < 2.5:
		mira += longe.normalized() * 3.0
		l["mira"] = mira
	var pos: Vector3 = l["pos"]
	var nova_pos := pos.lerp(mira, 1.0 - exp(-4.5 * delta))
	nova_pos.y += sin(_t * 5.0 + i) * 0.02
	var v := nova_pos - pos
	l["pos"] = nova_pos
	var rumo: Vector3 = l["rumo"]
	if Vector2(v.x, v.z).length() > 0.002:
		rumo = rumo.lerp(Vector3(v.x, 0.0, v.z).normalized(), 1.0 - exp(-6.0 * delta)).normalized()
		l["rumo"] = rumo
	var base := Basis.looking_at(rumo, Vector3.UP)
	_mm_l.set_instance_transform(i, Transform3D(base.scaled(Vector3.ONE * 1.4), nova_pos))
