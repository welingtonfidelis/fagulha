class_name VaporFonte
extends Node3D
## Vapor de uma fonte termal (poça de água quente, tipo Yellowstone). A água fica na origem do nó, um disco de
## raio `raio`; o vapor sobe devagar, leva o vento e some em uns 7 s. Feito com partículas CPU e a fumaça do
## Kenney Particle Pack (CC0); sem fumaça de verdade, só visual. Mais quente (`forca` alta), mais vapor.
## Uso: VaporFonte.new(), defina raio, forca, vento e semente; depois add_child.

const TEXTURA := "res://assets/fx/kenney/smoke_04.png"
const VIDA := 7.0

var raio := 6.0  # metros (poças de 3 a 14 m)
var forca := 1.0  # 0 a 1: quanto vapor (poças mais quentes soltam mais)
var vento := Vector3(0.5, 0.0, 0.2)  # deriva horizontal, em m/s
var semente := 0  # mesma semente, mesmo vapor em todas as rodadas

var _p: CPUParticles3D


func _ready() -> void:
	_p = CPUParticles3D.new()
	_p.one_shot = false
	_p.emitting = true
	_p.preprocess = VIDA  # já tem vapor quando o nó aparece
	_p.lifetime = VIDA
	_p.amount = clampi(int(raio * 4.0 * forca), 8, 56)
	_p.local_coords = true
	_p.position = Vector3(0.0, 0.2, 0.0)

	# nascem espalhados pela área da poça, rente à água
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_p.emission_box_extents = Vector3(raio * 0.75, 0.05, raio * 0.75)

	# sobem devagar, com um pouco de espalhamento e o vento empurrando
	_p.direction = Vector3.UP
	_p.spread = 15.0
	_p.initial_velocity_min = 0.5
	_p.initial_velocity_max = 1.0
	_p.gravity = Vector3(vento.x, 0.25, vento.z)
	_p.damping_min = 0.1
	_p.damping_max = 0.3
	_p.angle_min = 0.0
	_p.angle_max = 360.0
	_p.angular_velocity_min = -10.0
	_p.angular_velocity_max = 10.0

	# cresce de meio metro para mais de dois ao longo da vida
	_p.scale_amount_min = 1.0
	_p.scale_amount_max = 1.0
	var curva := Curve.new()
	curva.max_value = 2.5
	curva.add_point(Vector2(0.0, 0.5))
	curva.add_point(Vector2(1.0, 2.2))
	_p.scale_amount_curve = curva

	# transparente: some no nascer e na morte, fica suave no meio
	var g := Gradient.new()
	g.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.5 * forca),
		Color(1, 1, 1, 0.0),
	])
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	_p.color_ramp = g

	var tam := 2.6 + raio * 0.3
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.material = _material()
	_p.mesh = q

	_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p.visibility_range_end = 650.0
	_p.visibility_range_end_margin = 80.0
	_p.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_p.use_fixed_seed = true
	_p.seed = semente
	add_child(_p)


## Material da fumaça: sem sombra, transparente, virado para a câmera, com a imagem do Kenney se existir.
func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.86, 0.88, 0.9)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.5
	if ResourceLoader.exists(TEXTURA):
		m.albedo_texture = load(TEXTURA)
	else:
		# sem a imagem: um disco macio para a borda não ficar dura
		var t := GradientTexture2D.new()
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new()
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		gr.offsets = PackedFloat32Array([0.0, 1.0])
		t.gradient = gr
		m.albedo_texture = t
	return m


## Para de soltar vapor (as partículas que já existem terminam de subir).
func parar() -> void:
	if _p:
		_p.emitting = false


## Volta a soltar vapor.
func ligar() -> void:
	if _p:
		_p.emitting = true


## As partículas do vapor (para teste).
func particulas() -> CPUParticles3D:
	return _p
