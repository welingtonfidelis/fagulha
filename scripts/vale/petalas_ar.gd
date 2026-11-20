class_name PetalasAr
extends Node3D
## O que o vento leva, em volta da câmera. Pelo vale: umas poucas folhas (o pólen é da PoeiraLuz). As pétalas
## do pacote só aparecem perto dos grandes campos de flores (o Platô das Flores). Só de dia e sobre terra
## firme; debaixo da terra (grutas, Sumidouro) não há nada no ar. (Antes eram pétalas por toda a ilha, e
## muitas: pedido do usuário, 2026-11-20.)

const MODELOS := ["q_petala_a", "q_petala_b", "q_petala_c"]
const POR_MODELO := 14
const FLORES := [[Vector2(640, 120), 260.0]]  # os campos grandes de flores: [meio, raio]
const FOLHAS := 16
const VENTO := Vector3(0.86, 0.0, 0.5)  # para onde as ondas do capim andam (vale_capim.gdshader)

var mapa: Ilha
var _emissores: Array[GPUParticles3D] = []
var _folhas: GPUParticles3D


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_petala.gdshader")
	mat.set_shader_parameter("tex", load("res://assets/vale/q/flor.png"))
	for nome: String in MODELOS:
		var cena: PackedScene = load("res://assets/vale/q/" + nome + ".glb")
		var raiz := cena.instantiate()
		var mi := (raiz.find_children("*", "MeshInstance3D", true, false) + ([raiz] if raiz is MeshInstance3D else []))[0] as MeshInstance3D
		var malha := mi.mesh.duplicate() as Mesh
		raiz.free()
		malha.surface_set_material(0, mat)
		var e := GPUParticles3D.new()
		e.amount = POR_MODELO
		e.lifetime = 11.0
		e.preprocess = 11.0
		e.local_coords = false
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.visibility_aabb = AABB(Vector3(-50, -25, -50), Vector3(100, 50, 100))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(16, 3.5, 16)
		pm.gravity = Vector3(0, -0.22, 0)
		pm.direction = VENTO
		pm.spread = 25.0
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 1.3
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.8
		pm.turbulence_noise_scale = 3.0
		pm.scale_min = 0.26
		pm.scale_max = 0.42
		var curva := Curve.new()
		curva.add_point(Vector2(0, 0))
		curva.add_point(Vector2(0.12, 1))
		curva.add_point(Vector2(0.85, 1))
		curva.add_point(Vector2(1, 0))
		var ct := CurveTexture.new()
		ct.curve = curva
		pm.scale_curve = ct
		e.process_material = pm
		e.draw_pass_1 = malha
		add_child(e)
		_emissores.append(e)
	_criar_folhas()


## As folhas: poucas, pequenas, em tons de verde seco e laranja, levadas pelo mesmo vento.
func _criar_folhas() -> void:
	_folhas = GPUParticles3D.new()
	_folhas.amount = FOLHAS
	_folhas.lifetime = 12.0
	_folhas.preprocess = 12.0
	_folhas.local_coords = false
	_folhas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_folhas.visibility_aabb = AABB(Vector3(-50, -25, -50), Vector3(100, 50, 100))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 4.0, 18)
	pm.gravity = Vector3(0, -0.3, 0)
	pm.direction = VENTO
	pm.spread = 22.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.6
	pm.angular_velocity_min = -140.0
	pm.angular_velocity_max = 140.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.9
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.55, 0.6, 0.2), Color(0.85, 0.5, 0.15), Color(0.6, 0.35, 0.15)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	_folhas.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.09)
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	q.material = m
	_folhas.draw_pass_1 = q
	add_child(_folhas)


func _process(_delta: float) -> void:
	var vista := get_viewport().get_camera_3d()
	if vista == null:
		return
	var p := vista.global_position
	# nascem um pouco contra o vento e acima da vista, para atravessarem a cena
	global_position = p - VENTO * 6.0 + Vector3(0, 3.0, 0)
	var chao := mapa.altura(p.x, p.z) if mapa else 0.0
	var de_dia := CicloDia.atual == null or not CicloDia.atual.eh_noite()
	var em_terra := chao > 1.0 and p.y > chao and p.y < chao + 40.0 and not Cavernas.no_subsolo(p)
	var perto_de_flores := false
	for campo: Array in FLORES:
		if Vector2(p.x, p.z).distance_to(campo[0]) < float(campo[1]):
			perto_de_flores = true
	for e in _emissores:
		e.emitting = de_dia and em_terra and perto_de_flores
		e.visible = em_terra
	_folhas.emitting = de_dia and em_terra
	_folhas.visible = em_terra
