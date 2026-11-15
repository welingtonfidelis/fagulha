class_name Mundo
extends Ilha
## O mundo de verdade (2026-11-14): a ilha de 4 × 4 km da maquete (docs/mapa), feita à mão e lida de
## assets/mundo/ (alturas.bin e agua.bin: 1025 × 1025 pontos, um a cada 4 m; dados.json: lugares, lago,
## quedas, pilares). Estilo pintado e sério. Nada é sorteado no relevo; só a posição das árvores e das
## pedras sai de uma semente fixa.

const M_N := 1025
const M_ESP := 4.0
const M_META := 2048.0
const M_BLOCO := 64  # quadrados por bloco de malha (256 m)
const PASTA := "res://assets/mundo/"
const E := "res://assets/estilo/"
const ARV := ["arvore_a", "arvore_b", "arvore_c"]
const ROCHAS := ["rocha_a", "rocha_b", "rocha_laje", "rocha_ponta"]
const PERTO := 420.0  # até aqui as árvores usam o modelo completo

var agua_mapa := PackedFloat32Array()
var dados := {}
var nivel_lago := 40.0
var lugares: Array[Dictionary] = []  # nome, pos, raio
var quedas: Array[Vector3] = []  # meio de cada cachoeira (para o som e para esfriar)

var _malhas := {}
var _mat_rocha: ShaderMaterial
var _mat_folha: ShaderMaterial
var _mat_tronco: StandardMaterial3D
var _tex: NoiseTexture2D
var _formas := {}
var _folhas: Array[ShaderMaterial] = []  # paletas da mata: oliva-amarelada, azul-petróleo e a verde padrão
var _corpo_rochas: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _mat_queda: ShaderMaterial


func gerar(semente := 7) -> void:
	var t0 := Time.get_ticks_msec()
	_rng.seed = semente
	_n_mata = _ruido(semente + 14, 1.0 / 170.0, 3)
	_n_campo = _ruido(semente + 15, 1.0 / 60.0, 2)
	alturas = FileAccess.get_file_as_bytes(PASTA + "alturas.bin").to_float32_array()
	agua_mapa = FileAccess.get_file_as_bytes(PASTA + "agua.bin").to_float32_array()
	dados = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "dados.json"))
	nivel_lago = dados["nivel_lago"]
	lago_centro = Vector2(dados["lago"][0], dados["lago"][1])
	lago_raio = dados["lago"][2]
	lago_nivel = nivel_lago
	_materiais()
	_derivar()
	_malha_mundo()
	_colisao_mundo()
	_agua_mundo()
	_modelos()
	_pedras()
	_mata()
	_cipos()
	_ruinas()
	_preparar_colisao_arvores()
	_lugares()
	print("mundo gerado em %d ms, %d árvores" % [Time.get_ticks_msec() - t0, arv_pos.size()])


# ---------------------------------------------------------------- consultas

func altura(x: float, z: float) -> float:
	var fx := clampf((x + M_META) / M_ESP, 0.0, M_N - 1.001)
	var fz := clampf((z + M_META) / M_ESP, 0.0, M_N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * M_N + ix
	return lerpf(lerpf(alturas[i], alturas[i + 1], tx), lerpf(alturas[i + M_N], alturas[i + M_N + 1], tx), tz)


func _celula(x: float, z: float) -> int:
	return clampi(roundi((z + M_META) / M_ESP), 0, M_N - 1) * M_N + clampi(roundi((x + M_META) / M_ESP), 0, M_N - 1)


func agua(x: float, z: float) -> float:
	var a := agua_mapa[_celula(x, z)]
	return a if a > -500.0 else -INF


func agua_perto(p: Vector3) -> bool:
	if super.agua_perto(p):
		return true
	for q in quedas:
		if Vector2(p.x - q.x, p.z - q.z).length() < 16.0 and absf(p.y - q.y) < 40.0:
			return true
	return false


func normal_em(x: float, z: float) -> Vector3:
	return normais[_celula(x, z)]


# ---------------------------------------------------------------- relevo

func _materiais() -> void:
	_tex = NoiseTexture2D.new()
	_tex.width = 512
	_tex.height = 512
	_tex.seamless = true
	_tex.noise = _ruido(77, 1.0 / 40.0, 4)
	_mat_rocha = ShaderMaterial.new()
	_mat_rocha.shader = load("res://scripts/shaders/terreno_estilo.gdshader")
	_mat_rocha.set_shader_parameter("ruido", _tex)
	_mat_rocha.set_shader_parameter("usa_cor", false)
	_mat_folha = ShaderMaterial.new()
	_mat_folha.shader = load("res://scripts/shaders/folha_estilo.gdshader")
	_mat_folha.set_shader_parameter("ruido", _tex)
	for pal in [[Color(0.03, 0.07, 0.035), Color(0.10, 0.17, 0.045), Color(0.33, 0.33, 0.07)],
			[Color(0.015, 0.05, 0.06), Color(0.035, 0.12, 0.10), Color(0.12, 0.27, 0.16)]]:
		var mf := ShaderMaterial.new()
		mf.shader = _mat_folha.shader
		mf.set_shader_parameter("ruido", _tex)
		mf.set_shader_parameter("sombra", pal[0])
		mf.set_shader_parameter("meio", pal[1])
		mf.set_shader_parameter("luz", pal[2])
		_folhas.append(mf)
	_folhas.append(_mat_folha)
	_mat_tronco = StandardMaterial3D.new()
	_mat_tronco.albedo_color = Color(0.085, 0.07, 0.06)
	_mat_tronco.roughness = 0.95


func _derivar() -> void:
	normais.resize(M_N * M_N)
	cores.resize(M_N * M_N)
	for iz in M_N:
		var z := -M_META + iz * M_ESP
		for ix in M_N:
			var i := iz * M_N + ix
			var hl := alturas[i - 1] if ix > 0 else alturas[i]
			var hr := alturas[i + 1] if ix < M_N - 1 else alturas[i]
			var hd := alturas[i - M_N] if iz > 0 else alturas[i]
			var hu := alturas[i + M_N] if iz < M_N - 1 else alturas[i]
			normais[i] = Vector3(hl - hr, 2.0 * M_ESP, hd - hu).normalized()
			var mata_f := clampf(_n_mata.get_noise_2d(-M_META + ix * M_ESP, z) * 1.3 + 0.6, 0.0, 1.0)
			var molhado := 0.0
			if agua_mapa[i] > -500.0:
				molhado = 1.0
			elif alturas[i] < 3.0:
				molhado = 0.6
			cores[i] = Color(mata_f, molhado, 0.0)


func _malha_mundo() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/terreno_estilo.gdshader")
	mat.set_shader_parameter("ruido", _tex)
	var blocos := (M_N - 1) / M_BLOCO
	var lado := M_BLOCO + 1
	var idx := PackedInt32Array()
	idx.resize(M_BLOCO * M_BLOCO * 6)
	var p := 0
	for j in M_BLOCO:
		for i in M_BLOCO:
			var a := j * lado + i
			idx[p] = a
			idx[p + 1] = a + 1
			idx[p + 2] = a + lado + 1
			idx[p + 3] = a
			idx[p + 4] = a + lado + 1
			idx[p + 5] = a + lado
			p += 6
	for bz in blocos:
		for bx in blocos:
			var verts := PackedVector3Array()
			var nrms := PackedVector3Array()
			var cols := PackedColorArray()
			verts.resize(lado * lado)
			nrms.resize(lado * lado)
			cols.resize(lado * lado)
			for j in lado:
				var iz := bz * M_BLOCO + j
				for i in lado:
					var ix := bx * M_BLOCO + i
					var g := iz * M_N + ix
					var k := j * lado + i
					verts[k] = Vector3(-M_META + ix * M_ESP, alturas[g], -M_META + iz * M_ESP)
					nrms[k] = normais[g]
					cols[k] = cores[g]
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


func _colisao_mundo() -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := HeightMapShape3D.new()
	forma.map_width = M_N
	forma.map_depth = M_N
	var d := PackedFloat32Array()
	d.resize(M_N * M_N)
	for i in M_N * M_N:
		d[i] = alturas[i] / M_ESP
	forma.map_data = d
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.scale = Vector3.ONE * M_ESP
	corpo.add_child(cs)
	_corpo_rochas = StaticBody3D.new()
	_corpo_rochas.collision_layer = 1
	_corpo_rochas.collision_mask = 0
	add_child(_corpo_rochas)


# ---------------------------------------------------------------- água

func _agua_mundo() -> void:
	var ruido_agua := NoiseTexture2D.new()
	ruido_agua.width = 256
	ruido_agua.height = 256
	ruido_agua.seamless = true
	ruido_agua.noise = _ruido(61, 1.0 / 11.0, 3)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/rio.gdshader")
	mat.set_shader_parameter("ruido", ruido_agua)
	# mar
	var mar := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40000, 40000)
	mar.mesh = pm
	var mm := ShaderMaterial.new()
	mm.shader = load("res://scripts/shaders/agua.gdshader")
	mm.set_shader_parameter("raio", 100000.0)
	mm.set_shader_parameter("raso", Color(0.10, 0.26, 0.30))
	mm.set_shader_parameter("fundo", Color(0.02, 0.06, 0.10))
	mar.material_override = mm
	mar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mar)
	# rios e lago: um quadrado de água por célula molhada do mapa (acima do mar)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var m := M_ESP * 0.5
	for iz in range(1, M_N - 1):
		for ix in range(1, M_N - 1):
			var a := agua_mapa[iz * M_N + ix]
			if a < 0.5:
				continue
			var x := -M_META + ix * M_ESP
			var z := -M_META + iz * M_ESP
			st.add_vertex(Vector3(x - m, a, z - m))
			st.add_vertex(Vector3(x + m, a, z - m))
			st.add_vertex(Vector3(x + m, a, z + m))
			st.add_vertex(Vector3(x - m, a, z - m))
			st.add_vertex(Vector3(x + m, a, z + m))
			st.add_vertex(Vector3(x - m, a, z + m))
	var rios := MeshInstance3D.new()
	rios.mesh = st.commit()
	rios.material_override = mat
	rios.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rios)
	# cachoeiras: dos rios altos para o lago, e mais uma porção escorrendo dos paredões para os rios
	_mat_queda = ShaderMaterial.new()
	_mat_queda.shader = load("res://scripts/shaders/cachoeira.gdshader")
	_mat_queda.set_shader_parameter("ruido", ruido_agua)
	for q in dados["quedas"]:
		var de := Vector2(q["de"][0], q["de"][1])
		var dir := (lago_centro - de).normalized()
		var pe2 := de + dir * 34.0
		_queda(Vector3(de.x, float(q["alto"]) - 0.4, de.y), Vector3(pe2.x, nivel_lago - 0.5, pe2.y), 12.0, true)
	var rq := RandomNumberGenerator.new()
	rq.seed = 404
	var feitas: Array[Vector3] = []
	var tent := 0
	while feitas.size() < 22 and tent < 40000:
		tent += 1
		var ix := rq.randi_range(30, M_N - 30)
		var iz := rq.randi_range(30, M_N - 30)
		var nivel := agua_mapa[iz * M_N + ix]
		if nivel < 1.0 or absf(nivel - nivel_lago) < 0.01:
			continue
		var base := Vector3(-M_META + ix * M_ESP, nivel, -M_META + iz * M_ESP)
		var ang := rq.randf() * TAU
		var dir := Vector3(cos(ang), 0, sin(ang))
		# anda para fora do rio até achar o alto do paredão
		var achou := false
		var topo := Vector3.ZERO
		var pe := base
		for passo in range(3, 40):
			var p := base + dir * passo * 4.0
			var h := altura(p.x, p.z)
			if h < nivel + 6.0:
				pe = Vector3(p.x, maxf(h, nivel) - 0.3, p.z)
			elif h > nivel + 85.0:
				topo = Vector3(p.x, h - 0.5, p.z)
				achou = true
				break
		if not achou or topo.distance_to(pe) > 260.0:
			continue
		var perto := false
		for f in feitas:
			if f.distance_to(topo) < 220.0:
				perto = true
		if perto:
			continue
		feitas.append(topo)
		_queda(topo, pe, rq.randf_range(3.0, 7.0), false)
	# névoa deitada no fundo dos vales
	var postos: Array[Vector3] = []
	for k in 6000:
		var ix := rq.randi_range(10, M_N - 10)
		var iz := rq.randi_range(10, M_N - 10)
		var nivel := agua_mapa[iz * M_N + ix]
		if nivel < 1.0:
			continue
		var p := Vector3(-M_META + ix * M_ESP, nivel + 16.0, -M_META + iz * M_ESP)
		var livre := true
		for o in postos:
			if o.distance_to(p) < 170.0:
				livre = false
				break
		if not livre:
			continue
		postos.append(p)
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		fv.size = Vector3(260, 46, 260)
		var fm := FogMaterial.new()
		fm.density = 0.035
		fm.albedo = Color(0.78, 0.86, 0.92)
		fm.edge_fade = 0.6
		fv.material = fm
		fv.position = p
		add_child(fv)


func _queda(topo: Vector3, pe: Vector3, largura: float, nevoa: bool) -> void:
	var dirh := Vector3(pe.x - topo.x, 0, pe.z - topo.z)
	var dir := dirh.normalized() if dirh.length() > 0.5 else Vector3.RIGHT
	var lado := Vector3(-dir.z, 0, dir.x)
	var fita := SurfaceTool.new()
	fita.begin(Mesh.PRIMITIVE_TRIANGLES)
	var linhas := 24
	for k in linhas:
		var t0 := float(k) / linhas
		var t1 := float(k + 1) / linhas
		var p0 := Vector3(topo.x + (pe.x - topo.x) * pow(t0, 0.55), lerpf(topo.y, pe.y, t0), topo.z + (pe.z - topo.z) * pow(t0, 0.55))
		var p1 := Vector3(topo.x + (pe.x - topo.x) * pow(t1, 0.55), lerpf(topo.y, pe.y, t1), topo.z + (pe.z - topo.z) * pow(t1, 0.55))
		var l0 := largura * lerpf(0.75, 1.15, t0)
		var l1 := largura * lerpf(0.75, 1.15, t1)
		for v in [[p0 - lado * l0, Vector2(0, t0)], [p0 + lado * l0, Vector2(1, t0)], [p1 + lado * l1, Vector2(1, t1)],
				[p0 - lado * l0, Vector2(0, t0)], [p1 + lado * l1, Vector2(1, t1)], [p1 - lado * l1, Vector2(0, t1)]]:
			fita.set_normal((dir + Vector3.UP * 0.2).normalized())
			fita.set_uv(v[1])
			fita.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = fita.commit()
	mi.material_override = _mat_queda
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	quedas.append((topo + pe) * 0.5)
	if nevoa:
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		fv.size = Vector3(80, 34, 80)
		var fm := FogMaterial.new()
		fm.density = 0.09
		fm.albedo = Color(0.9, 0.94, 0.97)
		fv.material = fm
		fv.position = pe + Vector3(0, 9, 0)
		add_child(fv)


# ---------------------------------------------------------------- modelos, pedras e mata

func _modelos() -> void:
	var nomes: Array = ARV + ROCHAS + ["arvore_colossal", "arco"]
	for a in ARV:
		nomes.append(a + "_longe")
	for nome in nomes:
		var cena: PackedScene = load(E + nome + ".glb")
		var raiz := cena.instantiate() as Node3D
		var lista := []
		_juntar(raiz, Transform3D.IDENTITY, lista)
		raiz.free()
		_malhas[nome] = lista


func _juntar(no: Node, base: Transform3D, lista: Array) -> void:
	var t := base
	if no is Node3D:
		t = base * (no as Node3D).transform
	if no is MeshInstance3D:
		var mesh := (no as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			var nome := m.resource_name if m else ""
			mesh.surface_set_material(s, _mat_folha if nome == "folha" else (_mat_tronco if nome == "tronco" else _mat_rocha))
		lista.append([mesh, t])
	for f in no.get_children():
		_juntar(f, t, lista)


func _por(nome: String, xf: Transform3D, colisao := false) -> void:
	for par in _malhas[nome]:
		var mi := MeshInstance3D.new()
		mi.mesh = par[0]
		mi.transform = xf * (par[1] as Transform3D)
		add_child(mi)
		if colisao:
			if not _formas.has(par[0]):
				_formas[par[0]] = (par[0] as Mesh).create_trimesh_shape()
			var cs := CollisionShape3D.new()
			cs.shape = _formas[par[0]]
			cs.transform = mi.transform
			_corpo_rochas.add_child(cs)


func _pedras() -> void:
	# saliências talhadas nos paredões, enterradas pela metade
	var postas := 0
	var tentativas := 0
	while postas < 1300 and tentativas < 120000:
		tentativas += 1
		var x := _rng.randf_range(-M_META + 40.0, M_META - 40.0)
		var z := _rng.randf_range(-M_META + 40.0, M_META - 40.0)
		var i := _celula(x, z)
		var n := normais[i]
		if n.y > 0.5 or alturas[i] < 8.0:
			continue
		var s := _rng.randf_range(6.0, 16.0)
		var nh := Vector3(n.x, 0, n.z).normalized()
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
		_por(ROCHAS[_rng.randi() % ROCHAS.size()], Transform3D(b.scaled(Vector3.ONE * s), Vector3(x, alturas[i], z) - nh * s * 0.5), true)
		postas += 1


## Cortinas de cipó e musgo penduradas nos paredões: tiras finas que afinam para baixo, numa malha só.
func _cipos() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 55
	var postas := 0
	var tent := 0
	while postas < 2200 and tent < 200000:
		tent += 1
		var x := r.randf_range(-M_META + 40.0, M_META - 40.0)
		var z := r.randf_range(-M_META + 40.0, M_META - 40.0)
		var i := _celula(x, z)
		var n := normais[i]
		if n.y > 0.45 or alturas[i] < 12.0:
			continue
		var nh := Vector3(n.x, 0, n.z).normalized()
		var lado := Vector3(-nh.z, 0, nh.x)
		var base := Vector3(x, alturas[i], z) + nh * 1.2
		var larg := r.randf_range(3.0, 8.0)
		for f in r.randi_range(5, 9):
			var o := lado * r.randf_range(-larg, larg) + nh * r.randf_range(0.0, 0.8)
			var comp := r.randf_range(7.0, 26.0)
			var w := r.randf_range(0.18, 0.5)
			var a := base + o - lado * w
			var b := base + o + lado * w
			var c := base + o + Vector3(0, -comp, 0) + nh * r.randf_range(-0.4, 0.6)
			for v in [a, b, c]:
				st.set_normal((nh + Vector3.UP * 0.5).normalized())
				st.add_vertex(v)
		postas += 1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/cipo_estilo.gdshader")
	m.set_shader_parameter("ruido", _tex)
	m.set_shader_parameter("vento", 0.0)
	m.set_shader_parameter("sombra", Color(0.02, 0.05, 0.03))
	m.set_shader_parameter("meio", Color(0.05, 0.11, 0.04))
	m.set_shader_parameter("luz", Color(0.16, 0.22, 0.06))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _mata() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var blocos := {}
	var inicio := Vector2(dados["locais"][0]["p"][0], dados["locais"][0]["p"][1])
	var passo := 9.0
	var z := -M_META + 20.0
	while z < M_META - 20.0:
		var x := -M_META + 20.0
		while x < M_META - 20.0:
			var px := x + rng.randf_range(-3.6, 3.6)
			var pz := z + rng.randf_range(-3.6, 3.6)
			x += passo
			var i := _celula(px, pz)
			var h := alturas[i]
			if h < 2.5 or agua_mapa[i] > -500.0 or normais[i].y < 0.88:
				continue
			var prob := clampf(_n_mata.get_noise_2d(px, pz) * 2.4 + 0.38, 0.02, 0.92)  # clareiras e mata fechada
			if h > 380.0:
				prob *= 0.25
			if Vector2(px - inicio.x, pz - inicio.y).length() < 38.0:
				continue
			var s := rng.randf_range(1.0, 1.75)
			# fundo de cânion (água por perto): menos árvores e menores, para não tapar o voo
			for d in [Vector2(36, 0), Vector2(-36, 0), Vector2(0, 36), Vector2(0, -36)]:
				if agua_mapa[_celula(px + d.x, pz + d.y)] > 0.5:
					prob *= 0.3
					s *= 0.6
					break
			if rng.randf() > prob:
				continue
			arv_pos.append(Vector3(px, h - 0.2, pz))
			arv_escala.append(s * 1.3)
			arv_tipo.append(1)
			var chave := Vector2i(floori((px + M_META) / 256.0), floori((pz + M_META) / 256.0))
			if not blocos.has(chave):
				blocos[chave] = []
			(blocos[chave] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(px, h - 0.2, pz)))
		z += passo
	# o Bosque Colossal: gigantes postas em volta do morro do oeste
	var bosque := Vector2(dados["bosque"][0], dados["bosque"][1])
	for k in 16:
		var ang := TAU * k / 16.0 + rng.randf_range(-0.15, 0.15)
		var p := bosque + Vector2(cos(ang), sin(ang)) * rng.randf_range(60.0, 290.0)
		var h := altura(p.x, p.y)
		var s := rng.randf_range(0.8, 1.25)
		_por("arvore_colossal", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, h - 0.6, p.y)))
		arv_pos.append(Vector3(p.x, h, p.y))
		arv_escala.append(3.4 * s)
		arv_tipo.append(1)
	for i in arv_pos.size():
		var cel := Vector2i(floori(arv_pos[i].x / CELULA_ARVORE), floori(arv_pos[i].z / CELULA_ARVORE))
		if not _grade_arv.has(cel):
			_grade_arv[cel] = PackedInt32Array()
		var l: PackedInt32Array = _grade_arv[cel]
		l.append(i)
		_grade_arv[cel] = l
	# por bloco de 256 m: modelo completo perto, modelo leve de longe
	for chave in blocos:
		var xfs: Array = blocos[chave]
		var centro := Vector3(-M_META + (chave.x + 0.5) * 256.0, 0.0, -M_META + (chave.y + 0.5) * 256.0)
		centro.y = altura(centro.x, centro.z)
		var tipo: String = ARV[absi(chave.x * 7 + chave.y * 13) % ARV.size()]
		# a variação de cor da mata vem do shader (manchas largas e suaves), não do bloco
		_multi(tipo, xfs, centro, 0.0, PERTO, true)
		_multi(tipo + "_longe", xfs, centro, PERTO, 0.0, false)


func _multi(nome: String, xfs: Array, centro: Vector3, de: float, ate: float, sombra: bool, paleta: ShaderMaterial = null) -> void:
	for par in _malhas[nome]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = par[0]
		mm.instance_count = xfs.size()
		for k in xfs.size():
			var t := (xfs[k] as Transform3D) * (par[1] as Transform3D)
			t.origin -= centro
			mm.set_instance_transform(k, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if paleta and (par[0] as Mesh).surface_get_material(0) == _mat_folha:
			mmi.material_override = paleta
		mmi.position = centro
		if de > 0.0:
			mmi.visibility_range_begin = de
			mmi.visibility_range_begin_margin = 30.0
		if ate > 0.0:
			mmi.visibility_range_end = ate
			mmi.visibility_range_end_margin = 30.0
		if not sombra:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _ruinas() -> void:
	# por enquanto só o Arco sobre a Garganta; as outras ruínas ainda são só pontos no mapa
	for r in dados["ruinas"]:
		if r["nome"] == "Arco":
			var x: float = r["p"][0]
			var z: float = r["p"][1]
			var y := maxf(altura(x + 110.0, z), altura(x - 110.0, z)) - 10.0
			_por("arco", Transform3D(Basis(Vector3.UP, 0.1).scaled(Vector3.ONE * 1.5), Vector3(x, y, z)), true)


func _lugares() -> void:
	for l in dados["locais"]:
		var x: float = l["p"][0]
		var z: float = l["p"][1]
		var y := maxf(altura(x, z), agua(x, z))
		lugares.append({"nome": l["nome"], "pos": Vector3(x, y + 20.0, z), "raio": 150.0})
	var ini: Dictionary = lugares[0]
	var p: Vector3 = ini["pos"]
	spawn = Vector3(p.x, altura(p.x, p.z) + 0.3, p.z)
	spawn_yaw = -PI * 0.5  # olhando para leste, para a Garganta
