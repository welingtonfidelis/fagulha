class_name Cavernas
extends RefCounted
## Cavernas do vale: túneis que atravessam os morros. O relevo é uma grade de alturas e não aceita teto,
## então cada caverna é um rasgo cavado na grade (o chão e as paredes) coberto por um teto de rocha feito
## à parte, com o arco por baixo e o chão de cima refeito por cima. Os lugares são achados no próprio
## relevo. Há dois tipos: o túnel (linha de 70 a 150 m com as duas pontas baixas e um morro no meio) e a
## gruta sem saída (linha de 45 a 80 m que entra numa encosta, com o chão plano).
## `cavar` roda antes de o chão ser montado; `montar`, depois dos paredões.

const MEIA := 7.0  # metade da largura do chão do túnel
const PAREDE := 5.0  # em quantos metros a parede sobe até o chão de fora
const ALTO := 7.5  # altura do arco no meio
const QUANTAS := 6
const TUNEIS := 2  # no máximo; o resto são grutas sem saída
const NOMES := ["Passagem da Serra", "Gruta do Eco", "Gruta dos Cristais", "Toca Funda", "Gruta da Lua", "Boca Verde"]
const CORES := [Color(0.3, 0.95, 0.85), Color(1.0, 0.72, 0.3), Color(0.55, 0.7, 1.0), Color(0.75, 1.0, 0.5)]

static var lista: Array[Dictionary] = []  # {a, b, ha, hb, comp, de, ate, nome}
static var _orig := PackedFloat32Array()


## O chão de antes de cavar, em qualquer ponto (a mesma conta de Vale._fora).
static func chao_antes(x: float, z: float) -> float:
	var fx := clampf((x + Vale.F_META) / Vale.F_PASSO, 0.0, Vale.F_N - 1.001)
	var fz := clampf((z + Vale.F_META) / Vale.F_PASSO, 0.0, Vale.F_N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var i := iz * Vale.F_N + ix
	return lerpf(lerpf(_orig[i], _orig[i + 1], fx - ix), lerpf(_orig[i + Vale.F_N], _orig[i + Vale.F_N + 1], fx - ix), fz - iz)


## Vector2(distância até o eixo, posição ao longo dele de 0 a 1) para a caverna `c`.
static func _eixo(c: Dictionary, x: float, z: float) -> Vector2:
	var a: Vector2 = c["a"]
	var ab: Vector2 = (c["b"] as Vector2) - a
	var t := clampf((Vector2(x, z) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(Vector2(x, z).distance_to(a + ab * t), t)


## Dentro do rasgo de alguma caverna (com folga): ali não nasce árvore nem rocha de paredão.
static func dentro(x: float, z: float, folga := 4.0) -> bool:
	for c in lista:
		if _eixo(c, x, z).x < MEIA + PAREDE + folga:
			return true
	return false


static func cavar(v: Vale) -> void:
	lista.clear()
	_orig = v._fora_h.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	var lado := MEIA + PAREDE
	var tentativas := 0
	var tuneis := 0
	var t_ini := Time.get_ticks_msec()
	while lista.size() < QUANTAS and tentativas < 120000:
		tentativas += 1
		var gruta := tentativas > 30000 or tuneis >= TUNEIS
		var a := Vector2(rng.randf_range(-860, 860), rng.randf_range(-860, 860))
		var ang := rng.randf() * TAU
		var comp := rng.randf_range(45.0, 80.0) if gruta else rng.randf_range(70.0, 150.0)
		var b := a + Vector2(cos(ang), sin(ang)) * comp
		if maxf(absf(b.x), absf(b.y)) > 840.0 or a.length() < 240.0 or b.length() < 240.0:
			continue
		var ha := chao_antes(a.x, a.y)
		var hb := ha if gruta else chao_antes(b.x, b.y)
		if ha < 5.0 or hb < 5.0 or absf(ha - hb) > 22.0:
			continue
		var longe := true
		for c in lista:
			if ((c["a"] as Vector2) + (c["b"] as Vector2)).distance_to(a + b) * 0.5 < 200.0:
				longe = false
		if not longe:
			continue
		var dir := (b - a) / comp
		var perp := Vector2(-dir.y, dir.x)
		var serve := true
		var fim := comp + (lado + 3.0 if gruta else 0.0)  # a gruta precisa de morro também além do fundo
		var n := int(fim / 6.0)
		for i in n + 1:
			var sv := fim * float(i) / n
			var t := sv / comp
			var p := a + dir * sv
			var chao := lerpf(ha, hb, minf(t, 1.0))
			var coberto := t > 0.42 if gruta else (t > 0.3 and t < 0.7)
			for u: float in [0.0, -lado, lado]:
				var q := p + perp * u
				var folga := chao_antes(q.x, q.y) - chao
				if folga < -1.5 or (coberto and folga < 11.5):
					serve = false
					break
			if not serve or v.agua(p.x, p.y) > -INF or not Ruinas.livre(p.x, p.y):
				serve = false
				break
		if not serve:
			continue
		if not gruta:
			tuneis += 1
		lista.append({"a": a, "b": b, "ha": ha, "hb": hb, "comp": comp, "de": 0.0, "ate": 0.0, "gruta": gruta, "nome": NOMES[lista.size() % NOMES.size()]})
	# cava o rasgo na grade: chão plano no meio, parede em pé dos lados
	for c in lista:
		var a: Vector2 = c["a"]
		var b: Vector2 = c["b"]
		var mn := a.min(b) - Vector2.ONE * (lado + 6.0)
		var mx := a.max(b) + Vector2.ONE * (lado + 6.0)
		for gz in range(int((mn.y + Vale.F_META) / Vale.F_PASSO), int((mx.y + Vale.F_META) / Vale.F_PASSO) + 2):
			for gx in range(int((mn.x + Vale.F_META) / Vale.F_PASSO), int((mx.x + Vale.F_META) / Vale.F_PASSO) + 2):
				var x := -Vale.F_META + gx * Vale.F_PASSO
				var z := -Vale.F_META + gz * Vale.F_PASSO
				var e := _eixo(c, x, z)
				if e.x > lado:
					continue
				var i := gz * Vale.F_N + gx
				var chao := lerpf(c["ha"], c["hb"], e.y)
				var novo := lerpf(chao, _orig[i], smoothstep(MEIA, lado, e.x))
				if novo < v._fora_h[i]:
					v._fora_h[i] = novo
	print("cavernas: %d rasgos cavados (%d tentativas, %d ms)" % [lista.size(), tentativas, Time.get_ticks_msec() - t_ini])
	for c in lista:
		print("  %s (%s): de %s a %s, %.0f m, chão de %.0f a %.0f m" % [c["nome"], "gruta" if c["gruta"] else "túnel", c["a"], c["b"], c["comp"], c["ha"], c["hb"]])


static func montar(v: Vale) -> void:
	var t0 := Time.get_ticks_msec()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_rocha.gdshader")
	mat.set_shader_parameter("ruido", v._tex)
	var corpo := StaticBody3D.new()
	corpo.name = "Cavernas"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	v.add_child(corpo)
	var k := 0
	for c in lista:
		_teto(v, c, mat, corpo)
		_cristais(v, c, CORES[k % CORES.size()], 700 + k)
		k += 1
	print("cavernas: %d tetos, %d ms" % [lista.size(), Time.get_ticks_msec() - t0])


static func _arco(c: Dictionary, s: float, u: float) -> float:
	var chao := lerpf(c["ha"], c["hb"], minf(1.0, s / float(c["comp"])))
	var r := clampf(absf(u) / (MEIA + PAREDE - 0.5), 0.0, 1.0)
	var calombo := sin(s * 0.31 + u * 0.4) * 0.5 + sin(s * 0.83 - u * 0.9 + 1.7) * 0.3
	return chao + ALTO * pow(maxf(0.04, 1.0 - r * r), 0.42) + calombo


static func _teto(v: Vale, c: Dictionary, mat: Material, corpo: StaticBody3D) -> void:
	var a: Vector2 = c["a"]
	var comp: float = c["comp"]
	var dir := ((c["b"] as Vector2) - a) / comp
	var perp := Vector2(-dir.y, dir.x)
	var lado := MEIA + PAREDE
	var passo := 2.0
	var n := int((comp + (lado + 2.0 if c["gruta"] else 0.0)) / passo)
	# o teto só existe onde o morro passa bem acima do arco
	var vale_linha := PackedByteArray()
	vale_linha.resize(n + 1)
	for i in n + 1:
		var s := i * passo
		var p := a + dir * s
		var ok := true
		for u: float in [0.0, -lado, lado]:
			var q := p + perp * u
			if chao_antes(q.x, q.y) - _arco(c, s, u * 0.2) < 3.0:
				ok = false
		vale_linha[i] = 1 if ok else 0
	var meio := int(comp * (0.8 if c["gruta"] else 0.5) / passo)
	if vale_linha[meio] == 0:
		return
	var i0 := meio
	while i0 > 0 and vale_linha[i0 - 1] == 1:
		i0 -= 1
	var i1 := meio
	while i1 < n and vale_linha[i1 + 1] == 1:
		i1 += 1
	c["de"] = i0 * passo
	c["ate"] = i1 * passo
	var cols := int((lado + 1.0) * 2.0 / passo) + 1
	var baixo: Array[PackedVector3Array] = []
	var cima: Array[PackedVector3Array] = []
	for i in range(i0, i1 + 1):
		var lb := PackedVector3Array()
		var lc := PackedVector3Array()
		for j in cols:
			var u := -(lado + 1.0) + j * passo
			var q := a + dir * (i * passo) + perp * u
			var topo := chao_antes(q.x, q.y) + 0.12
			lb.append(Vector3(q.x, minf(_arco(c, i * passo, u), topo - 1.5), q.y))
			lc.append(Vector3(q.x, topo, q.y))
		baixo.append(lb)
		cima.append(lc)
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var vt := PackedVector3Array()  # o chão de cima, com material de capim
	var nt := PackedVector3Array()
	var d3 := Vector3(dir.x, 0, dir.y)
	for i in baixo.size() - 1:
		for j in cols - 1:
			_quad(vs, ns, baixo[i][j], baixo[i + 1][j], baixo[i + 1][j + 1], baixo[i][j + 1], Vector3.DOWN)
			_quad(vt, nt, cima[i][j], cima[i + 1][j], cima[i + 1][j + 1], cima[i][j + 1], Vector3.UP)
	# as duas bocas: a face de rocha entre o arco e o chão de cima
	for ponta: Array in [[0, -d3], [baixo.size() - 1, d3]]:
		var i: int = ponta[0]
		for j in cols - 1:
			_quad(vs, ns, baixo[i][j], baixo[i][j + 1], cima[i][j + 1], cima[i][j], ponta[1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	var arr2 := []
	arr2.resize(Mesh.ARRAY_MAX)
	arr2[Mesh.ARRAY_VERTEX] = vt
	arr2[Mesh.ARRAY_NORMAL] = nt
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
	var mat_cima := ShaderMaterial.new()
	mat_cima.shader = load("res://scripts/shaders/vale_teto.gdshader")
	mat_cima.set_shader_parameter("ruido", v._tex)
	m.surface_set_material(1, mat_cima)
	vs.append_array(vt)
	var mi := MeshInstance3D.new()
	mi.name = "Teto_" + String(c["nome"])
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	v.add_child(mi)
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(vs)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	corpo.add_child(cs)


static func _quad(vs: PackedVector3Array, ns: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, para: Vector3) -> void:
	for t: Array in [[a, b, c], [a, c, d]]:
		var p0: Vector3 = t[0]
		var p1: Vector3 = t[1]
		var p2: Vector3 = t[2]
		var n := (p2 - p0).cross(p1 - p0)
		if n.length_squared() < 1e-10:
			continue
		n = n.normalized()
		if n.dot(para) < 0.0:
			n = -n
			var troca := p1
			p1 = p2
			p2 = troca
		vs.append_array(PackedVector3Array([p0, p1, p2]))
		ns.append_array(PackedVector3Array([n, n, n]))


## Cristais acesos ao pé das paredes, alternando os lados: iluminam o túnel e mostram o caminho.
static func _cristais(v: Vale, c: Dictionary, cor: Color, semente: int) -> void:
	if float(c["ate"]) <= float(c["de"]):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor * 0.5
	mat.emission_enabled = true
	mat.emission = cor * 0.8
	mat.emission_energy_multiplier = 0.9
	mat.roughness = 0.3
	var a: Vector2 = c["a"]
	var comp: float = c["comp"]
	var dir := ((c["b"] as Vector2) - a) / comp
	var perp := Vector2(-dir.y, dir.x)
	var s := float(c["de"]) + 5.0
	var lado := 1.0
	while s < float(c["ate"]) - 3.0:
		var p := a + dir * s + perp * lado * (MEIA - 0.3 + rng.randf_range(0.0, 1.2))
		var base := Vector3(p.x, v._fora(p.x, p.y) - 0.2, p.y)
		var maior := 0.0
		for q in rng.randi_range(2, 4):
			var alt := rng.randf_range(0.8, 2.6)
			maior = maxf(maior, alt)
			var prisma := CylinderMesh.new()
			prisma.top_radius = 0.03
			prisma.bottom_radius = alt * rng.randf_range(0.13, 0.2)
			prisma.height = alt
			prisma.radial_segments = 5
			prisma.rings = 1
			var mi := MeshInstance3D.new()
			mi.mesh = prisma
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var inclina := Basis.from_euler(Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45)))
			mi.transform = Transform3D(inclina, base + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) + inclina * Vector3(0, alt * 0.5, 0))
			v.add_child(mi)
		var luz := OmniLight3D.new()
		luz.light_color = cor
		luz.light_energy = 1.6
		luz.omni_range = 13.0
		luz.shadow_enabled = false
		luz.position = base + Vector3(0, maior + 0.6, 0) - Vector3(perp.x, 0, perp.y) * lado * 1.5
		v.add_child(luz)
		s += rng.randf_range(11.0, 16.0)
		lado = -lado
