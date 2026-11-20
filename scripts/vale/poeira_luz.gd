class_name PoeiraLuz
extends GPUParticles3D
## Pólen e poeira no ar, em volta da câmera (teste de luz e cor, 2026-11-18): pontinhos claros que flutuam
## devagar e pegam a luz. De noite ficam mais raros e esverdeados, como vaga-lumes. Um emissor só.

func _ready() -> void:
	amount = 90
	lifetime = 9.0
	preprocess = 9.0
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 5, 22)
	pm.gravity = Vector3(0, -0.03, 0)
	pm.direction = Vector3(1, 0.2, 0.3)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.45
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 4.0
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0))
	curva.add_point(Vector2(0.25, 1))
	curva.add_point(Vector2(0.75, 1))
	curva.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	process_material = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.96, 0.75, 0.75)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	quad.material = mat
	draw_pass_1 = quad


func _process(_delta: float) -> void:
	var vista := get_viewport().get_camera_3d()
	if vista:
		global_position = vista.global_position + Vector3(0, 1.5, 0)
	var noite := CicloDia.atual != null and CicloDia.atual.eh_noite()
	# de dia é pólen (ralo); de noite, vaga-lumes. Debaixo da terra não há nada no ar
	var subsolo: bool = vista != null and Cavernas.no_subsolo(vista.global_position)
	emitting = not subsolo
	visible = not subsolo
	amount_ratio = 1.0 if noite else 0.5
	((draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_color = Color(0.7, 1.0, 0.5, 0.9) if noite else Color(1.0, 0.96, 0.75, 0.75)
