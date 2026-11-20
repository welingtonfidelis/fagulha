class_name Noite
extends Node3D
## A noite do vale: estrelas, vaga-lumes sobre o capim e o brilho fraco dos leds do robô.
## Quem cria passa `camera` e `armadura`; lê a hora e a chuva de `CicloDia.atual`.

var camera: Node3D
var armadura: Armadura

var forca := 0.0  # 0 de dia, 1 de noite fechada (para testes e fotos)

var _mat_estrelas: StandardMaterial3D
var _estrelas: MultiMeshInstance3D
var _vagalumes: GPUParticles3D
var _lanterna: OmniLight3D

const RAIO := 900.0


func _ready() -> void:
	_criar_estrelas()
	_criar_vagalumes()
	_lanterna = OmniLight3D.new()
	_lanterna.light_color = Color(1.0, 0.72, 0.45)
	_lanterna.omni_range = 2.4
	_lanterna.omni_attenuation = 1.6
	_lanterna.light_energy = 0.0
	_lanterna.shadow_enabled = false
	add_child(_lanterna)


func _process(_delta: float) -> void:
	var c := CicloDia.atual
	if c == null:
		return
	var h := c.hora
	# escurece entre 18,8 e 20,2; clareia entre 4,8 e 6,2
	var n := maxf(smoothstep(18.8, 20.2, h), 1.0 - smoothstep(4.8, 6.2, h))
	forca = n
	var ceu_limpo := 1.0 - c.chuva
	_mat_estrelas.albedo_color.a = n * ceu_limpo
	_estrelas.visible = n * ceu_limpo > 0.02
	if camera:
		_estrelas.global_position = camera.global_position
	# vaga-lumes: do anoitecer até a madrugada, sem chuva
	var vl := maxf(smoothstep(18.4, 19.4, h), 1.0 - smoothstep(4.0, 5.2, h)) * (1.0 if c.chuva < 0.2 else 0.0)
	var subsolo: bool = camera != null and Cavernas.no_subsolo(camera.global_position)
	_vagalumes.emitting = vl > 0.3 and not subsolo
	_vagalumes.visible = not subsolo
	if armadura:
		var p := armadura.global_position
		var chao := armadura.ilha.altura(p.x, p.z) if armadura.ilha else p.y
		_vagalumes.global_position = Vector3(p.x, chao + 1.1, p.z)
		# o brilho dos leds do robô: fraco, só um halo em volta dele (iluminar o caminho é da luz do peito,
		# que é melhoria). Fica um palmo à frente do peito e segue a posição suavizada: presa à posição da
		# física, dentro do corpo, ela tremia no voo e piscava por baixo da cabeça (visto pelo usuário)
		var frente := -armadura.visual.global_basis.z.normalized() if armadura.visual else Vector3.ZERO
		_lanterna.global_position = armadura.pos_suave() + Vector3(0, 0.6, 0) + frente * 0.32
	_lanterna.light_energy = n * 0.22
	ArmaduraVisual.noite = n


func _criar_estrelas() -> void:
	_mat_estrelas = StandardMaterial3D.new()
	_mat_estrelas.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_estrelas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_estrelas.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_estrelas.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat_estrelas.billboard_keep_scale = true
	_mat_estrelas.disable_fog = true
	_mat_estrelas.vertex_color_use_as_albedo = true
	_mat_estrelas.albedo_color = Color(1, 1, 1, 0)
	if ResourceLoader.exists("res://assets/fx/kenney/circle_05.png"):
		_mat_estrelas.albedo_texture = load("res://assets/fx/kenney/circle_05.png")
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _mat_estrelas
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var total := 1500
	mm.instance_count = total
	for i in total:
		# só a metade de cima do céu, mais estrelas perto do alto
		var y := rng.randf_range(0.04, 1.0)
		var ang := rng.randf() * TAU
		var r := sqrt(1.0 - y * y)
		var dir := Vector3(cos(ang) * r, y, sin(ang) * r)
		var grande := rng.randf() < 0.07
		var tam := rng.randf_range(9.0, 15.0) if grande else rng.randf_range(3.5, 7.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * tam), dir * RAIO))
		var b := rng.randf_range(0.45, 1.0)
		var quente := rng.randf()
		mm.set_instance_color(i, Color(b, b * lerpf(0.92, 1.0, quente), b * lerpf(1.0, 0.82, quente)))
	_estrelas = MultiMeshInstance3D.new()
	_estrelas.multimesh = mm
	_estrelas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_estrelas.extra_cull_margin = 2000.0
	_estrelas.top_level = true
	_estrelas.visible = false
	add_child(_estrelas)


func _criar_vagalumes() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.85, 1.0, 0.35)
	if ResourceLoader.exists("res://assets/fx/kenney/circle_05.png"):
		mat.albedo_texture = load("res://assets/fx/kenney/circle_05.png")
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	q.material = mat
	# pisca: acende e apaga duas vezes na vida
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.4, 0.55, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var rampa := GradientTexture1D.new()
	rampa.gradient = g
	var pp := ParticleProcessMaterial.new()
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pp.emission_box_extents = Vector3(26, 0.9, 26)
	pp.direction = Vector3(1, 0.2, 0)
	pp.spread = 180.0
	pp.initial_velocity_min = 0.15
	pp.initial_velocity_max = 0.5
	pp.gravity = Vector3.ZERO
	pp.turbulence_enabled = true
	pp.turbulence_noise_strength = 0.6
	pp.turbulence_noise_scale = 3.0
	pp.turbulence_influence_min = 0.1
	pp.turbulence_influence_max = 0.3
	pp.scale_min = 0.6
	pp.scale_max = 1.3
	pp.color_ramp = rampa
	_vagalumes = GPUParticles3D.new()
	_vagalumes.amount = 140
	_vagalumes.lifetime = 6.0
	_vagalumes.process_material = pp
	_vagalumes.draw_pass_1 = q
	_vagalumes.visibility_aabb = AABB(Vector3(-32, -8, -32), Vector3(64, 16, 64))
	_vagalumes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vagalumes.emitting = false
	_vagalumes.top_level = true
	add_child(_vagalumes)
