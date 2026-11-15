class_name CanionEstilo
extends Canion
## O mesmo cânion no estilo pintado e sério (2026-11-14): formas simples feitas por nós no Blender
## (tools/estilo/gerar.py), cor nos shaders (terreno_estilo, folha_estilo), luz dramática e névoa fria.
## Nada de arte fotografada: tudo combina e é leve.

const E := "res://assets/estilo/"
const ARVORES := ["arvore_a", "arvore_b", "arvore_c"]
const ROCHAS := ["rocha_a", "rocha_b", "rocha_laje", "rocha_ponta"]

var _mat_rocha: ShaderMaterial
var _mat_folha: ShaderMaterial
var _mat_tronco: StandardMaterial3D
var _tex_ruido: NoiseTexture2D


func _ruido_tex() -> NoiseTexture2D:
	if _tex_ruido == null:
		_tex_ruido = NoiseTexture2D.new()
		_tex_ruido.width = 512
		_tex_ruido.height = 512
		_tex_ruido.seamless = true
		_tex_ruido.noise = _ruido(77, 1.0 / 40.0, 4)
	return _tex_ruido


func _material_terreno() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/terreno_estilo.gdshader")
	m.set_shader_parameter("ruido", _ruido_tex())
	return m


func _carregar_modelos() -> void:
	_mat_rocha = _material_terreno()
	_mat_rocha.set_shader_parameter("usa_cor", false)
	_mat_folha = ShaderMaterial.new()
	_mat_folha.shader = load("res://scripts/shaders/folha_estilo.gdshader")
	_mat_folha.set_shader_parameter("ruido", _ruido_tex())
	_mat_tronco = StandardMaterial3D.new()
	_mat_tronco.albedo_color = Color(0.085, 0.07, 0.06)
	_mat_tronco.roughness = 0.95
	for nome in ARVORES + ROCHAS + ["arvore_colossal", "moita", "arco"]:
		var cena: PackedScene = load(E + nome + ".glb")
		var raiz := cena.instantiate() as Node3D
		var lista := []
		_juntar_estilo(raiz, Transform3D.IDENTITY, lista)
		raiz.free()
		_malhas[nome] = lista


func _juntar_estilo(no: Node, base: Transform3D, lista: Array) -> void:
	var t := base
	if no is Node3D:
		t = base * (no as Node3D).transform
	if no is MeshInstance3D:
		var mesh := (no as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			var nome := m.resource_name if m else ""
			if nome == "folha":
				mesh.surface_set_material(s, _mat_folha)
			elif nome == "tronco":
				mesh.surface_set_material(s, _mat_tronco)
			else:
				mesh.surface_set_material(s, _mat_rocha)
		lista.append([mesh, t])
	for f in no.get_children():
		_juntar_estilo(f, t, lista)


func _rochas() -> void:
	# saliências talhadas nos paredões
	for lado: float in [-1.0, 1.0]:
		var z := -300.0
		while z < 300.0:
			z += _rng.randf_range(16.0, 30.0)
			if absf(z - Z_CACHOEIRA) < 22.0:
				continue
			for faixa in 2:
				var y := _rng.randf_range(18.0, 52.0) if faixa == 0 else _rng.randf_range(60.0, 104.0)
				var s := Vector3(_rng.randf_range(7.0, 13.0), _rng.randf_range(5.0, 9.0), _rng.randf_range(7.0, 13.0))
				var x := parede_x(z, lado, y) + lado * maxf(s.x, s.z) * 0.6  # enterrada: só a saliência aparece
				var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.25, 0.25))
				_instancia(ROCHAS[_rng.randi() % ROCHAS.size()], Transform3D(b.scaled(s), Vector3(x, y, z)), true, true)
	# pedras no fundo
	for k in 80:
		var z := _rng.randf_range(-300.0, 300.0)
		var x := centro_x(z) + _rng.randf_range(-1.0, 1.0) * meia(z) * 0.9
		if absf(x - rio_x(z)) < 8.0:
			continue
		var s := _rng.randf_range(1.2, 4.5)
		_instancia(ROCHAS[_rng.randi() % ROCHAS.size()], Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s)), Vector3(x, altura(x, z) + s * 0.1, z)), true, true)
	# ponte de pedra
	_instancia("arco", Transform3D(Basis(Vector3.UP, 0.06), Vector3(centro_x(Z_PONTE), ALTO - 9.0, Z_PONTE)), true, true)


func _vegetacao(semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente * 13 + 1
	var blocos := {}
	var passo := 8.0
	var z := -C_META + 6.0
	while z < C_META - 6.0:
		var x := -C_META + 6.0
		while x < C_META - 6.0:
			var px := x + rng.randf_range(-3.2, 3.2)
			var pz := z + rng.randf_range(-3.2, 3.2)
			x += passo
			var h := altura(px, pz)
			if agua(px, pz) > -INF or normal_em(px, pz).y < 0.86:
				continue
			if Vector2(px - lip.x, pz - lip.z).length() < 14.0 or _dist_segmento(Vector2(px, pz), corrego_de, Vector2(lip.x, lip.z)) < 10.0:
				continue
			if Vector2(px - poco.x, pz - poco.z).length() < 26.0 or (absf(px - rio_x(pz)) < 9.0 and h < FUNDO + 5.0):
				continue
			if Vector2(px - spawn_previsto().x, pz - spawn_previsto().z).length() < 9.0:
				continue
			var prob := 0.0
			if h > ALTO - 12.0:
				prob = clampf(_n_mata.get_noise_2d(px, pz) * 1.6 + 0.62, 0.08, 0.95)
			elif h < FUNDO + 7.0:
				prob = 0.45
			else:
				prob = 0.6
			if rng.randf() > prob:
				continue
			var tipo := rng.randi() % ARVORES.size()
			var s := rng.randf_range(0.8, 1.3)
			arv_pos.append(Vector3(px, h - 0.2, pz))
			arv_escala.append(s * 1.3)  # a colisão da Ilha foi feita para árvores de ~13 m
			arv_tipo.append(1)
			var chave := Vector3i(floori((px + C_META) / 64.0), floori((pz + C_META) / 64.0), tipo)
			if not blocos.has(chave):
				blocos[chave] = []
			(blocos[chave] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(px, h - 0.2, pz)))
		z += passo
	for i in arv_pos.size():
		var cel := Vector2i(floori(arv_pos[i].x / CELULA_ARVORE), floori(arv_pos[i].z / CELULA_ARVORE))
		if not _grade_arv.has(cel):
			_grade_arv[cel] = PackedInt32Array()
		var l: PackedInt32Array = _grade_arv[cel]
		l.append(i)
		_grade_arv[cel] = l
	for chave in blocos:
		_multi(ARVORES[chave.z], blocos[chave], 0.0, true)
	# árvores colossais: marcos de longe, à mão
	for p in [Vector2(borda_x(120.0, 1.0) + 40.0, 120.0), Vector2(borda_x(-150.0, -1.0) - 55.0, -150.0), Vector2(pilares[1].x, pilares[1].y)]:
		var h := altura(p.x, p.y)
		_instancia("arvore_colossal", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, h - 0.5, p.y)))
	# moitas
	var moitas := {}
	z = -C_META + 4.0
	while z < C_META - 4.0:
		var x := -C_META + 4.0
		while x < C_META - 4.0:
			var px := x + rng.randf_range(-1.8, 1.8)
			var pz := z + rng.randf_range(-1.8, 1.8)
			x += 4.0
			if agua(px, pz) > -INF or normal_em(px, pz).y < 0.78 or rng.randf() > 0.3:
				continue
			var chave := Vector2i(floori((px + C_META) / 64.0), floori((pz + C_META) / 64.0))
			if not moitas.has(chave):
				moitas[chave] = []
			var s := rng.randf_range(0.6, 1.5)
			(moitas[chave] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s)), Vector3(px, altura(px, pz) - 0.15, pz)))
		z += 4.0
	for chave in moitas:
		_multi("moita", moitas[chave], 160.0, false)
	_grama(rng)


func _multi(nome: String, xfs: Array, alcance: float, sombra: bool) -> void:
	for par in _malhas[nome]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = par[0]
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, (xfs[k] as Transform3D) * (par[1] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if alcance > 0.0:
			mmi.visibility_range_end = alcance
			mmi.visibility_range_end_margin = 20.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not sombra:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
