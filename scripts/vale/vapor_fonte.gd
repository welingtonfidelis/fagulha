class_name VaporFonte
extends Node3D
## Vapor de uma fonte termal (poça de água quente, tipo Yellowstone). A água fica na origem do nó, um disco de
## raio `raio`; o vapor sobe devagar, leva o vento e some em uns 7 s. Feito com partículas CPU e a fumaça do
## Kenney Particle Pack (CC0); sem fumaça de verdade, só visual. Mais quente (`forca` alta), mais vapor.
## Uso: VaporFonte.new(), defina raio, forca, vento e semente; depois add_child.
## Desde 2026-11-22 (revisão do game designer) o vapor respira: nasce num disco do tamanho da poça, vem em
## rajadas de vez em quando e fica mais grosso de madrugada, no frio da manhã e na chuva (±40%, só a vista: o
## calor do motor não muda). Com `coluna`, é a coluna alta e lenta do Olho Azul, que se vê de longe.

const TEXTURA := "res://assets/fx/kenney/smoke_04.png"
const VIDA := 7.0
const FOLGA := 1.7  # a rampa de transparência vem 1,7 vez mais forte e o `respirar` multiplica por k / FOLGA

var raio := 6.0  # metros (poças de 3 a 14 m)
var forca := 1.0  # 0 a 1: quanto vapor (poças mais quentes soltam mais)
var vento := Vector3(0.5, 0.0, 0.2)  # deriva horizontal, em m/s
var semente := 0  # mesma semente, mesmo vapor em todas as rodadas
var coluna := false  # a coluna alta do Olho Azul

var _p: CPUParticles3D
var _rajada := 0.0  # 0 a 1
var _prox_rajada := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = semente + 91
	_prox_rajada = _rng.randf_range(8.0, 40.0)
	if coluna:
		_coluna()
		return
	_p = CPUParticles3D.new()
	_p.one_shot = false
	_p.emitting = true
	_p.preprocess = VIDA  # já tem vapor quando o nó aparece
	_p.lifetime = VIDA
	_p.amount = clampi(int(raio * 4.0 * forca), 8, 56)
	_p.local_coords = true
	_p.position = Vector3(0.0, 0.2, 0.0)

	# nascem espalhados pela área da poça (um disco, como a água), rente a ela
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_p.emission_ring_axis = Vector3.UP
	_p.emission_ring_radius = raio * 0.85
	_p.emission_ring_inner_radius = 0.0
	_p.emission_ring_height = 0.1

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
		Color(1, 1, 1, 0.5 * forca * FOLGA),
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


## A coluna do Olho Azul: poucas nuvens grandes que nascem no meio da poça e sobem devagar até uns 30 m,
## levadas pelo vento. Vista de longe (até 1,6 km), marca onde ficam as fontes.
func _coluna() -> void:
	_p = CPUParticles3D.new()
	_p.one_shot = false
	_p.emitting = true
	_p.lifetime = 20.0
	_p.preprocess = 20.0
	_p.amount = 22
	_p.local_coords = true
	_p.position = Vector3(0.0, 0.6, 0.0)
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_p.emission_ring_axis = Vector3.UP
	_p.emission_ring_radius = raio * 0.3
	_p.emission_ring_inner_radius = 0.0
	_p.emission_ring_height = 0.5
	_p.direction = Vector3.UP
	_p.spread = 8.0
	_p.initial_velocity_min = 1.1
	_p.initial_velocity_max = 1.7
	_p.gravity = Vector3(vento.x * 0.6, 0.04, vento.z * 0.6)
	_p.damping_min = 0.0
	_p.damping_max = 0.02
	_p.angle_min = 0.0
	_p.angle_max = 360.0
	_p.angular_velocity_min = -4.0
	_p.angular_velocity_max = 4.0
	var curva := Curve.new()
	curva.max_value = 4.0
	curva.add_point(Vector2(0.0, 0.6))
	curva.add_point(Vector2(1.0, 3.6))
	_p.scale_amount_curve = curva
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.3 * FOLGA), Color(1, 1, 1, 0.22 * FOLGA), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.55, 1.0])
	_p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(7.0, 7.0)
	q.material = _material()
	(q.material as StandardMaterial3D).proximity_fade_distance = 4.0
	_p.mesh = q
	_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p.visibility_range_end = 1600.0
	_p.visibility_range_end_margin = 200.0
	_p.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_p.use_fixed_seed = true
	_p.seed = semente
	add_child(_p)


## O vapor respira: mais grosso de madrugada e de manhã cedo (o ar frio condensa mais), na chuva e nas
## rajadas; mais ralo no meio da tarde. Só a vista (±40%).
func _process(delta: float) -> void:
	if _p == null:
		return
	_t += delta
	if _t > _prox_rajada:
		_rajada = 1.0
		_prox_rajada = _t + _rng.randf_range(25.0, 70.0)
	_rajada = move_toward(_rajada, 0.0, delta / 4.0)
	var k := 1.0
	var ciclo := CicloDia.atual
	if ciclo != null and is_instance_valid(ciclo):
		var h := ciclo.hora
		var frio := 1.0 - smoothstep(9.0, 13.0, h) + smoothstep(19.0, 23.0, h)  # 1 de noite e de manhã cedo
		k = 0.8 + 0.4 * clampf(frio, 0.0, 1.0) + 0.25 * ciclo.chuva
	var pulso := sin(PI * minf(1.0, (1.0 - _rajada) * 1.0)) if _rajada > 0.0 else 0.0
	k = clampf(k + 0.45 * pulso, 0.6, 1.4 + 0.3 * pulso)
	_p.color = Color(1, 1, 1, k / FOLGA)  # a cor da partícula só escurece (vai de 0 a 1): a rampa já vem com a folga
	_p.speed_scale = 1.0 + 0.3 * pulso


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
