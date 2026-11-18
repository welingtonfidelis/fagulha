class_name FendaEscura
extends Node
## A Fenda Escura (ilha de 3 km, etapa 4, doc §82): o cânion que corta a Chapada do Sudoeste. O corte vem
## pronto do relevo (tools/vale/mapa_3km.py): 50 m de fundura e uns 24 m de chão. Aqui entram só os
## cogumelos que brilham, as pedras do chão e os morcegos. Um teto de lajes e o escuro foram testados e
## saíram a pedido do usuário: a fenda fica aberta, com a luz do dia.

const LINHA: Array[Vector2] = [Vector2(-1090, 960), Vector2(-960, 1010), Vector2(-860, 1100), Vector2(-730, 1120), Vector2(-610, 1200)]
const COBRE_DE := 34.0  # o teto começa e acaba a estas distâncias ao longo da linha
const COBRE_ATE := 505.0
const MEIA := 30.0  # da linha até a beira de cima

static var existe := false
static var cogumelos: Array[Vector3] = []
static var bandos: Array[Morcegos] = []
static var _s := PackedFloat32Array()


## Vector2(distância até a linha da fenda, comprimento andado ao longo dela).
static func perto(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var melhor := Vector2(INF, 0.0)
	for i in LINHA.size() - 1:
		var a := LINHA[i]
		var ab := LINHA[i + 1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < melhor.x:
			melhor = Vector2(d, _s[i] + ab.length() * t)
	return melhor


static func ponto(sv: float) -> Vector2:
	for i in LINHA.size() - 1:
		if sv <= _s[i + 1] or i == LINHA.size() - 2:
			return LINHA[i].lerp(LINHA[i + 1], clampf((sv - _s[i]) / (_s[i + 1] - _s[i]), 0.0, 1.0))
	return LINHA[0]


static func rumo(sv: float) -> Vector2:
	return (ponto(sv + 2.0) - ponto(sv - 2.0)).normalized()


static func livre(_x: float, _z: float) -> bool:
	return true  # a fenda aberta tem árvores no fundo, como antes


static func preparar() -> void:
	_s.resize(LINHA.size())
	_s[0] = 0.0
	for i in range(1, LINHA.size()):
		_s[i] = _s[i - 1] + LINHA[i].distance_to(LINHA[i - 1])
	existe = true


static func montar(v: Vale) -> void:
	var t0 := Time.get_ticks_msec()
	preparar()
	cogumelos.clear()
	bandos.clear()
	var blocos: Array[PackedVector3Array] = []
	for k in 6:
		blocos.append(Ruinas._cubo_talhado(401 + k * 7, 3 + k % 3))
	var o := Ruinas.Obra.new()
	o.v = v
	o.blocos = blocos
	o.t = Transform3D.IDENTITY
	o.rng.seed = 60606
	o.corpo = StaticBody3D.new()
	o.corpo.name = "FendaTeto"
	o.corpo.collision_layer = 1
	o.corpo.collision_mask = 0
	v.add_child(o.corpo)
	# (o teto de lajes e o escuro saíram a pedido do usuário em 2026-11-18: os quadros ficaram ruins; a fenda
	# fica aberta, como era)
	# pedras soltas pelo chão
	for i in 46:
		var s2 := o.rng.randf_range(COBRE_DE, COBRE_ATE)
		var c2 := ponto(s2) + Vector2(-rumo(s2).y, rumo(s2).x) * o.j(9.0)
		var tam := Vector3(o.rng.randf_range(1.0, 4.0), o.rng.randf_range(0.8, 2.6), o.rng.randf_range(1.0, 3.6))
		o.bloco(Vector3(c2.x, v._fora(c2.x, c2.y) + tam.y * 0.3, c2.y), tam, Basis.from_euler(Vector3(o.j(0.4), o.rng.randf() * TAU, o.j(0.4))), "rocha", tam.x > 1.6)
	o.fechar()
	_cogumelos(v, o.rng)
	# morcegos em três trechos, no alto, entre as paredes
	for s3: float in [120.0, 270.0, 420.0]:
		var c3 := ponto(s3)
		var m := Morcegos.new()
		m.eixo = Vector3(c3.x, v._fora(c3.x, c3.y), c3.y)
		m.raio_max = 8.0
		m.faixas = [Vector2(14.0, 30.0), Vector2(24.0, 38.0)]
		v.add_child(m)
		bandos.append(m)
	Marcos.lugares.append(["A Fenda Escura", ponto(270.0), 120.0])
	print("fenda escura: %d cogumelos, %d bandos de morcegos, %d ms" % [cogumelos.size(), bandos.size(), Time.get_ticks_msec() - t0])


## Tufos de cogumelos que brilham, junto das paredes: a única luz do fundo além das claraboias.
static func _cogumelos(v: Vale, rng: RandomNumberGenerator) -> void:
	var chapeu := SphereMesh.new()
	chapeu.radius = 0.5
	chapeu.height = 0.5
	chapeu.is_hemisphere = true
	chapeu.radial_segments = 10
	chapeu.rings = 4
	var pe_m := CylinderMesh.new()
	pe_m.top_radius = 0.09
	pe_m.bottom_radius = 0.13
	pe_m.height = 1.0
	pe_m.radial_segments = 6
	var mat_pe := StandardMaterial3D.new()
	mat_pe.albedo_color = Color(0.55, 0.62, 0.58)
	var sv := COBRE_DE + 14.0
	var i := 0
	while sv < COBRE_ATE - 10.0:
		var c := ponto(sv)
		var lat := Vector2(-rumo(sv).y, rumo(sv).x)
		var q := c + lat * (9.5 if i % 2 == 0 else -9.5) + rumo(sv) * rng.randf_range(-4.0, 4.0)
		var chao := v._fora(q.x, q.y)
		var cor := Color(0.25, 1.0, 0.8) if i % 3 != 0 else Color(0.5, 0.75, 1.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cor * 0.4
		mat.emission_enabled = true
		mat.emission = cor
		mat.emission_energy_multiplier = 1.6
		var tufo := Node3D.new()
		tufo.position = Vector3(q.x, chao, q.y)
		v.add_child(tufo)
		for n in rng.randi_range(3, 6):
			var alt := rng.randf_range(0.35, 1.3)
			var onde := Vector3(rng.randf_range(-1.1, 1.1), 0, rng.randf_range(-1.1, 1.1))
			var haste := MeshInstance3D.new()
			haste.mesh = pe_m
			haste.material_override = mat_pe
			haste.scale = Vector3(1, alt, 1)
			haste.position = onde + Vector3(0, alt * 0.5, 0)
			haste.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tufo.add_child(haste)
			var ch := MeshInstance3D.new()
			ch.mesh = chapeu
			ch.material_override = mat
			ch.scale = Vector3.ONE * rng.randf_range(0.5, 1.1)
			ch.position = onde + Vector3(0, alt, 0)
			ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tufo.add_child(ch)
		var luz := OmniLight3D.new()
		luz.light_color = cor
		luz.light_energy = 0.55
		luz.omni_range = 9.0
		luz.omni_attenuation = 1.6
		luz.shadow_enabled = false
		luz.position = Vector3(0, 1.4, 0)
		luz.distance_fade_enabled = true
		luz.distance_fade_begin = 110.0
		luz.distance_fade_length = 30.0
		tufo.add_child(luz)
		cogumelos.append(tufo.position)
		sv += rng.randf_range(20.0, 30.0)
		i += 1


## Liga a fenda ao robô: os morcegos reagem a ele e a luz ambiente acompanha a câmera.
static func ligar(_v: Vale, robo: Node3D) -> void:
	if not existe:
		return
	for m in bandos:
		m.alvo = robo
