class_name Canion
extends Ilha
## Teste de qualidade visual (2026-11-14): um cânion de 640 × 640 m feito à mão, com paredões, um vale
## largo com três pilares de pedra, uma ponte de rocha natural, cachoeira de ~110 m caindo num poço,
## rio, mata em cima e embaixo, e névoa. Modelos e texturas do Poly Haven (CC0) em assets/teste_visual/.
## Usa o mesmo jeito da Ilha (altura, água, colisão das árvores perto), então a armadura voa nele igual.

const C_META := 320.0
const C_N := 641  # um ponto por metro
const C_BLOCO := 64
const ALTO := 118.0  # platô
const FUNDO := 4.0  # chão do cânion
const CORRIDA := 16.0  # largura horizontal da parede
const NIVEL_RIO := 3.0
const Z_CACHOEIRA := -70.0
const Z_PONTE := 262.0
const A := "res://assets/teste_visual/"

var lip := Vector3.ZERO  # topo da cachoeira
var poco := Vector3.ZERO  # onde ela cai
var nivel_corrego := 0.0
var corrego_de := Vector2.ZERO
var pilares: Array[Vector4] = []  # x, z, raio, altura

var _n_warp: FastNoiseLite
var _n_plato: FastNoiseLite
var _n_fino: FastNoiseLite
var _n_pilar: FastNoiseLite
var _rng := RandomNumberGenerator.new()
var _malhas := {}  # nome -> Array de [Mesh, Transform3D]
var _corpo_rochas: StaticBody3D
var _formas := {}  # Mesh -> forma de colisão (uma por malha, reaproveitada)
## Todas as árvores com a malha detalhada, uma a uma: a Godot reduz cada uma pela distância (LOD automático).
## A versão leve em MultiMesh perdia as folhas.
const USAR_DETALHADA := true


# ---------------------------------------------------------------- forma

func centro_x(z: float) -> float:
	return 55.0 * sin(z / 140.0) + 18.0 * sin(z / 57.0 + 1.3)


func meia(z: float) -> float:
	var vale := exp(-pow((z - 150.0) / 70.0, 2.0))
	return 24.0 + 8.0 * sin(z / 95.0 + 0.7) + 46.0 * vale


func rio_x(z: float) -> float:
	return centro_x(z) + 7.0 * sin(z / 37.0)


func borda_x(z: float, lado: float) -> float:
	return centro_x(z) + lado * (meia(z) + CORRIDA)


func _altura_canion(x: float, z: float) -> float:
	var calma := smoothstep(18.0, 60.0, absf(z - Z_CACHOEIRA))  # parede reta perto da cachoeira
	var dx := x - centro_x(z) + _n_warp.get_noise_2d(x, z) * 9.0 * calma
	var d := absf(dx)
	var m := meia(z)
	var plato := ALTO + _n_plato.get_noise_2d(x, z) * 2.5 + _n_fino.get_noise_2d(x * 3.0, z * 3.0) * 0.6
	var h: float
	if d < m:
		h = FUNDO + _n_plato.get_noise_2d(x * 2.0, z * 2.0) * 0.8 + smoothstep(m * 0.55, m, d) * 3.0
	elif d < m + CORRIDA:
		var t := (d - m) / CORRIDA
		t = clampf(t + 0.05 * sin(t * TAU * 2.0 + z * 0.03), 0.0, 1.0)
		h = lerpf(FUNDO + 3.0, plato, smoothstep(0.0, 1.0, t))
	else:
		h = plato
	# leito do rio
	if d < m:
		var dr := absf(x - rio_x(z))
		h = minf(h, lerpf(NIVEL_RIO - 1.6, h, smoothstep(4.0, 10.0, dr)))
	# pilares
	for p in pilares:
		var dp := Vector2(x - p.x, z - p.y).length()
		var r := p.z * (1.0 + 0.18 * _n_pilar.get_noise_2d(x * 0.8, z * 0.8))
		if dp < r * 1.5:
			var topo := FUNDO + p.w + _n_fino.get_noise_2d(x * 2.0, z * 2.0) * 3.0
			h = maxf(h, lerpf(FUNDO + 2.0, topo, 1.0 - smoothstep(r * 0.82, r * 1.12, dp)))
	# poço da cachoeira e a saída até o rio
	var dpoco := Vector2(x - poco.x, z - poco.z).length()
	if dpoco < 30.0:
		h = minf(h, lerpf(NIVEL_RIO - 4.5, h, smoothstep(10.0, 24.0, dpoco)))
	var saida := _dist_segmento(Vector2(x, z), Vector2(poco.x, poco.z), Vector2(rio_x(Z_CACHOEIRA + 45.0), Z_CACHOEIRA + 45.0))
	if saida < 12.0 and d < m:
		h = minf(h, lerpf(NIVEL_RIO - 1.2, h, smoothstep(3.0, 9.0, saida)))
	# córrego no platô até a borda
	var dc := _dist_segmento(Vector2(x, z), corrego_de, Vector2(lip.x - 2.0, lip.z))
	if dc < 11.0 and (x < lip.x + 1.0):
		h = minf(h, lerpf(nivel_corrego - 1.6, h, smoothstep(3.5, 10.0, dc)))
	return h


static func _dist_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---------------------------------------------------------------- geração

func gerar(semente := 7) -> void:
	var t0 := Time.get_ticks_msec()
	_rng.seed = semente
	_n_warp = _ruido(semente + 10, 1.0 / 45.0, 3)
	_n_plato = _ruido(semente + 11, 1.0 / 120.0, 4)
	_n_fino = _ruido(semente + 12, 1.0 / 18.0, 3)
	_n_pilar = _ruido(semente + 13, 1.0 / 12.0, 2)
	_n_mata = _ruido(semente + 14, 1.0 / 90.0, 3)
	_n_campo = _ruido(semente + 15, 1.0 / 60.0, 2)
	# lugares feitos à mão
	for p in [Vector4(-35, 112, 10, 72), Vector4(30, 150, 13, 96), Vector4(-26, 198, 9, 60)]:
		pilares.append(Vector4(centro_x(p.y) + p.x, p.y, p.z, p.w))
	var xb := borda_x(Z_CACHOEIRA, -1.0)
	nivel_corrego = ALTO - 3.5
	lip = Vector3(xb, nivel_corrego, Z_CACHOEIRA)
	poco = Vector3(xb + CORRIDA + 9.0, NIVEL_RIO, Z_CACHOEIRA)
	corrego_de = Vector2(xb - 170.0, Z_CACHOEIRA + 45.0)
	alturas.resize(C_N * C_N)
	for iz in C_N:
		var z := -C_META + iz
		for ix in C_N:
			alturas[iz * C_N + ix] = _altura_canion(-C_META + ix, z)
	_derivados_canion()
	_malha_canion()
	_colisao_canion()
	_agua_canion()
	_carregar_modelos()
	_rochas()
	_vegetacao(semente)
	_preparar_colisao_arvores()
	_inicio()
	print("cânion gerado em %d ms, %d árvores" % [Time.get_ticks_msec() - t0, arv_pos.size()])


func altura(x: float, z: float) -> float:
	var fx := clampf(x + C_META, 0.0, C_N - 1.001)
	var fz := clampf(z + C_META, 0.0, C_N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * C_N + ix
	return lerpf(lerpf(alturas[i], alturas[i + 1], tx), lerpf(alturas[i + C_N], alturas[i + C_N + 1], tx), tz)


func agua(x: float, z: float) -> float:
	var h := altura(x, z)
	if h < NIVEL_RIO:
		return NIVEL_RIO
	if x < lip.x + 1.0 and h < nivel_corrego and _dist_segmento(Vector2(x, z), corrego_de, Vector2(lip.x, lip.z)) < 8.0:
		return nivel_corrego
	return -INF


func agua_perto(p: Vector3) -> bool:
	if super.agua_perto(p):
		return true
	# a coluna da cachoeira e o borrifo em volta do poço esfriam também
	var de := Vector2(lip.x, lip.z)
	var ate := Vector2(poco.x, poco.z)
	var d := _dist_segmento(Vector2(p.x, p.z), de, ate)
	return d < 9.0 and p.y < lip.y + 4.0 and p.y > NIVEL_RIO - 4.0


func normal_em(x: float, z: float) -> Vector3:
	return Vector3(altura(x - 1.0, z) - altura(x + 1.0, z), 2.0, altura(x, z - 1.0) - altura(x, z + 1.0)).normalized()


func _derivados_canion() -> void:
	normais.resize(C_N * C_N)
	cores.resize(C_N * C_N)
	for iz in C_N:
		for ix in C_N:
			var i := iz * C_N + ix
			var hl := alturas[i - 1] if ix > 0 else alturas[i]
			var hr := alturas[i + 1] if ix < C_N - 1 else alturas[i]
			var hd := alturas[i - C_N] if iz > 0 else alturas[i]
			var hu := alturas[i + C_N] if iz < C_N - 1 else alturas[i]
			normais[i] = Vector3(hl - hr, 2.0, hd - hu).normalized()
			var x := -C_META + ix
			var z := -C_META + iz
			var h := alturas[i]
			var mata_f := clampf(_n_mata.get_noise_2d(x, z) * 1.2 + 0.7, 0.0, 1.0)
			if h < FUNDO + 8.0:
				mata_f = maxf(mata_f, 0.6)
			var molhado := 1.0 - smoothstep(NIVEL_RIO + 0.2, NIVEL_RIO + 2.5, h)
			var dc := Vector2(x - poco.x, z - poco.z).length()
			molhado = maxf(molhado, 1.0 - smoothstep(14.0, 40.0, dc))
			cores[i] = Color(mata_f, molhado, 0.0)


func _material_terreno() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/terreno_canion.gdshader")
	var t := A + "texturas/"
	mat.set_shader_parameter("rocha_cor", load(t + "cliff_side_diff_2k.jpg"))
	mat.set_shader_parameter("rocha_nrm", load(t + "cliff_side_nor_gl_2k.jpg"))
	mat.set_shader_parameter("rocha_rug", load(t + "cliff_side_rough_2k.jpg"))
	mat.set_shader_parameter("grama_cor", load(t + "aerial_grass_rock_diff_2k.jpg"))
	mat.set_shader_parameter("grama_nrm", load(t + "aerial_grass_rock_nor_gl_2k.jpg"))
	mat.set_shader_parameter("grama_rug", load(t + "aerial_grass_rock_rough_2k.jpg"))
	mat.set_shader_parameter("chao_cor", load(t + "forest_ground_04_diff_2k.jpg"))
	mat.set_shader_parameter("chao_nrm", load(t + "forest_ground_04_nor_gl_2k.jpg"))
	mat.set_shader_parameter("chao_rug", load(t + "forest_ground_04_rough_2k.jpg"))
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = _ruido(77, 1.0 / 40.0, 4)
	mat.set_shader_parameter("ruido", tex)
	return mat


func _malha_canion() -> void:
	var mat := _material_terreno()
	var blocos := (C_N - 1) / C_BLOCO
	var lado := C_BLOCO + 1
	for bz in blocos:
		for bx in blocos:
			var verts := PackedVector3Array()
			var nrms := PackedVector3Array()
			var cols := PackedColorArray()
			verts.resize(lado * lado)
			nrms.resize(lado * lado)
			cols.resize(lado * lado)
			for j in lado:
				for i in lado:
					var ix := bx * C_BLOCO + i
					var iz := bz * C_BLOCO + j
					var g := iz * C_N + ix
					var k := j * lado + i
					verts[k] = Vector3(-C_META + ix, alturas[g], -C_META + iz)
					nrms[k] = normais[g]
					cols[k] = cores[g]
			var idx := PackedInt32Array()
			idx.resize(C_BLOCO * C_BLOCO * 6)
			var p := 0
			for j in C_BLOCO:
				for i in C_BLOCO:
					var a := j * lado + i
					idx[p] = a
					idx[p + 1] = a + 1
					idx[p + 2] = a + lado + 1
					idx[p + 3] = a
					idx[p + 4] = a + lado + 1
					idx[p + 5] = a + lado
					p += 6
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = nrms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = m
			add_child(mi)


func _colisao_canion() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "ChaoColisao"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := HeightMapShape3D.new()
	forma.map_width = C_N
	forma.map_depth = C_N
	forma.map_data = alturas
	var cs := CollisionShape3D.new()
	cs.shape = forma
	corpo.add_child(cs)
	_corpo_rochas = StaticBody3D.new()
	_corpo_rochas.name = "RochasColisao"
	_corpo_rochas.collision_layer = 1
	_corpo_rochas.collision_mask = 0
	add_child(_corpo_rochas)


# ---------------------------------------------------------------- água

func _agua_canion() -> void:
	# ruído seamless compartilhado pelo rio e pelo córrego (correnteza e espuma)
	var ruido_agua := NoiseTexture2D.new()
	ruido_agua.width = 256
	ruido_agua.height = 256
	ruido_agua.seamless = true
	ruido_agua.noise = _ruido(61, 1.0 / 11.0, 3)
	var rio := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(C_META * 2.0, C_META * 2.0)
	pm.subdivide_width = 16
	pm.subdivide_depth = 16
	rio.mesh = pm
	# rio corre ao longo de +Z
	rio.material_override = _material_rio(Vector2(0, 1), ruido_agua)
	rio.position = Vector3(0, NIVEL_RIO, 0)
	rio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rio)
	# córrego no platô, correndo da nascente até a borda
	var corr := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	var de3 := Vector3(corrego_de.x, nivel_corrego, corrego_de.y)
	var comp := Vector2(lip.x, lip.z).distance_to(corrego_de) + 6.0
	cm.size = Vector2(16.0, comp)
	corr.mesh = cm
	corr.material_override = _material_rio((Vector2(lip.x, lip.z) - corrego_de).normalized(), ruido_agua)
	corr.position = (de3 + Vector3(lip.x, nivel_corrego, lip.z)) * 0.5
	corr.look_at_from_position(corr.position, Vector3(lip.x, nivel_corrego, lip.z), Vector3.UP)
	add_child(corr)
	# a queda: fita curva do topo até o poço
	var ruido := NoiseTexture2D.new()
	ruido.width = 256
	ruido.height = 256
	ruido.seamless = true
	ruido.noise = _ruido(55, 1.0 / 14.0, 3)
	var mq := ShaderMaterial.new()
	mq.shader = load("res://scripts/shaders/cachoeira.gdshader")
	mq.set_shader_parameter("ruido", ruido)
	for camada in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var linhas := 28
		var pontos: Array[Vector3] = []
		for k in linhas + 1:
			var t := float(k) / linhas
			var x := lip.x + 1.0 + (poco.x - lip.x - 1.0) * pow(t, 0.55) + camada * 0.8
			var y := lerpf(lip.y + 0.2, NIVEL_RIO - 0.5, t)
			pontos.append(Vector3(x, y, lip.z))
		for k in linhas:
			var t0 := float(k) / linhas
			var t1 := float(k + 1) / linhas
			var l0 := lerpf(10.0, 15.0, t0) * (1.0 - camada * 0.25)
			var l1 := lerpf(10.0, 15.0, t1) * (1.0 - camada * 0.25)
			var a0 := pontos[k] + Vector3(0, 0, -l0 * 0.5)
			var b0 := pontos[k] + Vector3(0, 0, l0 * 0.5)
			var a1 := pontos[k + 1] + Vector3(0, 0, -l1 * 0.5)
			var b1 := pontos[k + 1] + Vector3(0, 0, l1 * 0.5)
			var n := Vector3(1, 0.15, 0).normalized()
			for v in [[a0, Vector2(0, t0)], [b0, Vector2(1, t0)], [b1, Vector2(1, t1)], [a0, Vector2(0, t0)], [b1, Vector2(1, t1)], [a1, Vector2(0, t1)]]:
				st.set_normal(n)
				st.set_uv(v[1])
				st.add_vertex(v[0])
		var fita := MeshInstance3D.new()
		fita.mesh = st.commit()
		fita.material_override = mq
		fita.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fita)
	_borrifo()


func _material_rio(fluxo: Vector2, ruido_agua: NoiseTexture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/rio.gdshader")
	m.set_shader_parameter("fluxo", fluxo)
	m.set_shader_parameter("ruido", ruido_agua)
	return m


func _borrifo() -> void:
	# névoa local no poço (precisa da névoa volumétrica ligada) e partículas de borrifo
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fv.size = Vector3(60, 34, 60)
	var fm := FogMaterial.new()
	fm.density = 0.1
	fm.albedo = Color(0.92, 0.95, 0.97)
	fv.material = fm
	fv.position = poco + Vector3(4, 8, 0)
	add_child(fv)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.55))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = gt
	mat.albedo_color = Color(0.95, 0.97, 1.0, 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2(4, 4)
	quad.material = mat
	var pp := ParticleProcessMaterial.new()
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pp.emission_box_extents = Vector3(5, 1, 7)
	pp.direction = Vector3(0.6, 1, 0)
	pp.spread = 60.0
	pp.initial_velocity_min = 4.0
	pp.initial_velocity_max = 11.0
	pp.gravity = Vector3(0, -2.5, 0)
	pp.damping_min = 1.5
	pp.damping_max = 3.0
	pp.scale_min = 0.8
	pp.scale_max = 2.4
	var curva := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(1, 2.2))
	curva.curve = c
	pp.scale_curve = curva
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 0.9))
	gr.set_color(1, Color(1, 1, 1, 0.0))
	var grt := GradientTexture1D.new()
	grt.gradient = gr
	pp.color_ramp = grt
	var part := GPUParticles3D.new()
	part.amount = 160
	part.lifetime = 3.2
	part.process_material = pp
	part.draw_pass_1 = quad
	part.position = poco + Vector3(0, 0.5, 0)
	part.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 50, 80))
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)


# ---------------------------------------------------------------- modelos

func _carregar_modelos() -> void:
	for nome in ["coastal_cliff_01", "mountainside", "rock_face_01", "rock_face_02", "rock_moss_set_01", "rock_moss_set_02",
			"boulder_01", "island_tree_02", "island_tree_02_leve", "pachira_aquatica_01", "anthurium_botany_01",
			"calathea_orbifolia_01", "fern_02", "shrub_02", "root_cluster_01"]:
		var cena: PackedScene = load(A + nome + ".glb")
		var raiz := cena.instantiate() as Node3D
		var lista := []
		_juntar_malhas(raiz, Transform3D.IDENTITY, lista)
		raiz.free()
		_malhas[nome] = lista


func _juntar_malhas(no: Node, base: Transform3D, lista: Array) -> void:
	var t := base
	if no is Node3D:
		t = base * (no as Node3D).transform
	if no is MeshInstance3D:
		var mesh := (no as MeshInstance3D).mesh
		_ajustar_materiais(mesh)
		lista.append([mesh, t])
	for f in no.get_children():
		_juntar_malhas(f, t, lista)


func _ajustar_materiais(mesh: Mesh) -> void:
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s) as StandardMaterial3D
		if m == null:
			continue
		var folha := m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or "leave" in m.resource_name.to_lower()
		if folha:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			m.alpha_hash_scale = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.backlight_enabled = true
			m.backlight = Color(0.35, 0.42, 0.16)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


func _instancia(nome: String, xf: Transform3D, sombra := true, colisao := false, alcance := 0.0, lod := 1.0) -> void:
	for par in _malhas[nome]:
		var mi := MeshInstance3D.new()
		mi.lod_bias = lod
		mi.mesh = par[0]
		mi.transform = xf * (par[1] as Transform3D)
		if not sombra:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if alcance > 0.0:
			mi.visibility_range_end = alcance
			mi.visibility_range_end_margin = 10.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mi)
		if colisao:
			var cs := CollisionShape3D.new()
			if not _formas.has(par[0]):
				_formas[par[0]] = (par[0] as Mesh).create_trimesh_shape()
			cs.shape = _formas[par[0]]
			cs.transform = mi.transform
			_corpo_rochas.add_child(cs)


## Primeiro x (andando do meio do cânion para fora) em que a parede passa da altura y.
func parede_x(z: float, lado: float, y: float) -> float:
	var x := centro_x(z)
	for k in 200:
		x += lado
		if altura(x, z) > y:
			return x
	return x


func _rochas() -> void:
	var pecas := ["rock_face_01", "rock_face_02", "mountainside"]
	for lado: float in [-1.0, 1.0]:
		var z := -300.0
		while z < 300.0:
			z += _rng.randf_range(20.0, 34.0)
			if absf(z - Z_CACHOEIRA) < 22.0:
				continue
			for faixa in 2:
				var y := _rng.randf_range(22.0, 52.0) if faixa == 0 else _rng.randf_range(62.0, 100.0)
				var s := _rng.randf_range(4.0, 7.5)
				# enterrada no paredão: só a ponta aparece (antes invadia o vale e travava o voo)
				var x := parede_x(z, lado, y) + lado * s * 4.2
				var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
				_instancia(pecas[_rng.randi() % pecas.size()], Transform3D(b.scaled(Vector3.ONE * s), Vector3(x, y, z)), true, true)
	# pedras soltas no fundo e na borda
	for k in 70:
		var z := _rng.randf_range(-300.0, 300.0)
		var x := centro_x(z) + _rng.randf_range(-1.0, 1.0) * meia(z) * 0.9
		if absf(x - rio_x(z)) < 9.0:
			continue
		var nome: String = ["rock_moss_set_01", "rock_moss_set_02", "boulder_01"][_rng.randi() % 3]
		var s := _rng.randf_range(1.5, 4.0)
		_instancia(nome, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, altura(x, z) - 0.3, z)), true, true)
	# ponte de rocha natural sobre o cânion
	var pc := Vector3(centro_x(Z_PONTE), ALTO - 16.0, Z_PONTE)
	var bp := Basis(Vector3.UP, 0.08)
	_instancia("coastal_cliff_01", Transform3D(bp.scaled(Vector3.ONE * 1.3), pc), true, true)


func _vegetacao(semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente * 13 + 1
	var passo := 9.0
	var z := -C_META + 6.0
	while z < C_META - 6.0:
		var x := -C_META + 6.0
		while x < C_META - 6.0:
			var px := x + rng.randf_range(-3.5, 3.5)
			var pz := z + rng.randf_range(-3.5, 3.5)
			x += passo
			var h := altura(px, pz)
			if agua(px, pz) > -INF or normal_em(px, pz).y < 0.86:
				continue
			if Vector2(px - lip.x, pz - lip.z).length() < 14.0 or _dist_segmento(Vector2(px, pz), corrego_de, Vector2(lip.x, lip.z)) < 10.0:
				continue
			if Vector2(px - poco.x, pz - poco.z).length() < 26.0 or absf(px - rio_x(pz)) < 9.0 and h < FUNDO + 5.0:
				continue
			var prob := 0.0
			if h > ALTO - 12.0:
				var dborda := absf(absf(px - centro_x(pz)) - (meia(pz) + CORRIDA))
				prob = 0.36 if dborda < 70.0 else 0.12
			elif h < FUNDO + 7.0:
				prob = 0.3
			else:
				prob = 0.5  # topo dos pilares
			if rng.randf() > prob:
				continue
			var s := rng.randf_range(3.2, 4.6)
			arv_pos.append(Vector3(px, h - 0.3, pz))
			arv_escala.append(s * 0.36)
			arv_tipo.append(1)
		z += passo
	for i in arv_pos.size():
		var cel := Vector2i(floori(arv_pos[i].x / CELULA_ARVORE), floori(arv_pos[i].z / CELULA_ARVORE))
		if not _grade_arv.has(cel):
			_grade_arv[cel] = PackedInt32Array()
		var l: PackedInt32Array = _grade_arv[cel]
		l.append(i)
		_grade_arv[cel] = l
	# árvores: a versão detalhada perto do começo (uma a uma, com redução automática de longe) e a leve no
	# resto, em MultiMesh por bloco de 64 m
	var blocos := {}
	var sp := spawn_previsto()
	for i in arv_pos.size():
		var s := arv_escala[i] / 0.36
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s))
		var xf := Transform3D(b, arv_pos[i])
		if USAR_DETALHADA:
			_instancia("island_tree_02", xf, true, false, 0.0, 0.3)
			continue
		var chave := Vector2i(floori((arv_pos[i].x + C_META) / 64.0), floori((arv_pos[i].z + C_META) / 64.0))
		if not blocos.has(chave):
			blocos[chave] = []
		(blocos[chave] as Array).append(xf)
	for chave in blocos:
		var xfs: Array = blocos[chave]
		for par in _malhas["island_tree_02_leve"]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = par[0]
			mm.instance_count = xfs.size()
			for k in xfs.size():
				mm.set_instance_transform(k, (xfs[k] as Transform3D) * (par[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			add_child(mmi)
	# sub-bosque e grama em MultiMesh por bloco de 64 m
	_sub_bosque(rng)
	_grama(rng)


func spawn_previsto() -> Vector3:
	var z := -18.0
	var x := borda_x(z, 1.0) + 14.0
	return Vector3(x, altura(x, z), z)


func _sub_bosque(rng: RandomNumberGenerator) -> void:
	var tipos := [["pachira_aquatica_01", 1.3, 2.2], ["anthurium_botany_01", 1.2, 1.8], ["calathea_orbifolia_01", 1.4, 2.2],
		["fern_02", 1.6, 2.6], ["shrub_02", 0.9, 1.3], ["root_cluster_01", 1.0, 1.8]]
	var blocos := {}
	var passo := 3.2
	var z := -C_META + 4.0
	while z < C_META - 4.0:
		var x := -C_META + 4.0
		while x < C_META - 4.0:
			var px := x + rng.randf_range(-1.4, 1.4)
			var pz := z + rng.randf_range(-1.4, 1.4)
			x += passo
			var h := altura(px, pz)
			if agua(px, pz) > -INF or normal_em(px, pz).y < 0.8:
				continue
			var dborda := absf(absf(px - centro_x(pz)) - (meia(pz) + CORRIDA))
			var perto_borda := h > ALTO - 12.0 and dborda < 60.0
			var fundo := h < FUNDO + 7.0 and absf(px - rio_x(pz)) > 8.0
			if not (perto_borda or fundo or (h > FUNDO + 30.0 and h < ALTO - 12.0)):
				continue
			if rng.randf() > 0.22:
				continue
			var tipo: Array = tipos[rng.randi() % tipos.size()]
			var s := rng.randf_range(tipo[1], tipo[2])
			var chave := Vector3i(floori((px + C_META) / 64.0), floori((pz + C_META) / 64.0), tipos.find(tipo))
			if not blocos.has(chave):
				blocos[chave] = []
			(blocos[chave] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(px, h - 0.1, pz)))
		z += passo
	for chave in blocos:
		var nome: String = tipos[chave.z][0]
		var xfs: Array = blocos[chave]
		for par in _malhas[nome]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = par[0]
			mm.instance_count = xfs.size()
			for k in xfs.size():
				mm.set_instance_transform(k, (xfs[k] as Transform3D) * (par[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.visibility_range_end = 80.0
			mmi.visibility_range_end_margin = 15.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)


func _grama(rng: RandomNumberGenerator) -> void:
	var touceira := _touceira()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/grama.gdshader")
	touceira.surface_set_material(0, mat)
	var blocos := {}
	var passo := 1.7
	var z := -C_META + 2.0
	while z < C_META - 2.0:
		var x := -C_META + 2.0
		while x < C_META - 2.0:
			var px := x + rng.randf_range(-0.8, 0.8)
			var pz := z + rng.randf_range(-0.8, 0.8)
			x += passo
			var i := (int(pz + C_META)) * C_N + int(px + C_META)
			if i < 0 or i >= normais.size() or normais[i].y < 0.88:
				continue
			var h := alturas[i]
			if h < NIVEL_RIO + 0.4 or rng.randf() > 0.55:
				continue
			var chave := Vector2i(floori((px + C_META) / 64.0), floori((pz + C_META) / 64.0))
			if not blocos.has(chave):
				blocos[chave] = []
			var s := rng.randf_range(0.7, 1.4)
			(blocos[chave] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(px, h - 0.05, pz)))
		z += passo
	for chave in blocos:
		var xfs: Array = blocos[chave]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = touceira
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 70.0
		mmi.visibility_range_end_margin = 15.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _touceira() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var pe := Color8(46, 62, 24).srgb_to_linear()
	var ponta := Color8(150, 165, 80).srgb_to_linear()
	for f in 14:
		var ang := r.randf() * TAU
		var dir := Vector3(cos(ang), 0, sin(ang))
		var lado := Vector3(-dir.z, 0, dir.x)
		var base := dir * r.randf_range(0.0, 0.25)
		var alt := r.randf_range(0.45, 0.95)
		var curva := r.randf_range(0.15, 0.4)
		var larg := r.randf_range(0.03, 0.05)
		var segs := 3
		for k in segs:
			var t0 := float(k) / segs
			var t1 := float(k + 1) / segs
			var p0 := base + dir * curva * t0 * t0 + Vector3(0, alt * t0, 0)
			var p1 := base + dir * curva * t1 * t1 + Vector3(0, alt * t1, 0)
			var w0 := larg * (1.0 - t0)
			var w1 := larg * (1.0 - t1) + 0.002
			var n := (Vector3.UP * 0.6 + dir).normalized()
			var c0 := pe.lerp(ponta, t0)
			var c1 := pe.lerp(ponta, t1)
			for v in [[p0 - lado * w0, c0], [p0 + lado * w0, c0], [p1 + lado * w1, c1], [p0 - lado * w0, c0], [p1 + lado * w1, c1], [p1 - lado * w1, c1]]:
				st.set_color(v[1])
				st.set_normal(n)
				st.add_vertex(v[0])
	return st.commit()


func _inicio() -> void:
	spawn = spawn_previsto() + Vector3(0, 0.3, 0)
	var para := Vector3(poco.x, 60.0, poco.z) - spawn
	spawn_yaw = atan2(-para.x, -para.z)
	lago_centro = Vector2(poco.x, poco.z)
	lago_nivel = NIVEL_RIO
