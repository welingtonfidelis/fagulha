class_name EfeitosMato
extends Node3D
## Efeitos do robô no mato: folhas ao atravessar a copa das árvores, e poeira nos pousos,
## na decolagem e no risco da esquiva no chão. Não cria sombra e libera cada emissor sozinho.
## Uso: põe `armadura` e `mapa` (Ilha ou Clareira) antes de add_child. Sem eles, não faz nada.

signal atravessou_copa(posicao: Vector3, velocidade: float)

const LIMIAR_COPA := 4.0  # m/s para contar a entrada numa copa e soltar folhas
const INTERVALO_EXPLOSAO := 0.5  # segundos mínimos entre explosões de uma mesma árvore
const COR_FOLHA_ESCURA := Color(0.09, 0.22, 0.07)
const COR_FOLHA_CLARA := Color(0.30, 0.50, 0.13)
const COR_POEIRA_A := Color(0.86, 0.78, 0.60)
const COR_POEIRA_B := Color(0.74, 0.66, 0.48)

var armadura: Armadura
var mapa: Ilha
var copas_atravessadas := 0
var poeiras := 0

var _tempo := 0.0
var _dentro := {}  # índices das árvores cuja copa contém o robô neste quadro
var _ultimo_disparo := {}  # índice da árvore -> tempo da última explosão de folhas
var _esquivando_ant := false
var _continuas: GPUParticles3D
var _mat_continuas: ParticleProcessMaterial
var _malha_folha: QuadMesh
var _malha_poeira: QuadMesh
var _tex_folha: GradientTexture1D
var _tex_poeira: GradientTexture1D
var _tex_fade: GradientTexture1D
var _cresce: CurveTexture


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_malha_folha = QuadMesh.new()
	_malha_folha.size = Vector2(0.12, 0.12)
	_malha_folha.material = mat
	var mat_p := StandardMaterial3D.new()
	mat_p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_p.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_p.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_p.vertex_color_use_as_albedo = true
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 1, 1, 0.26), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
	gr.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var bola := GradientTexture2D.new()
	bola.gradient = gr
	bola.fill = GradientTexture2D.FILL_RADIAL
	bola.fill_from = Vector2(0.5, 0.5)
	bola.fill_to = Vector2(1.0, 0.5)
	bola.width = 64
	bola.height = 64
	mat_p.albedo_texture = bola
	# fumaça do Kenney Particle Pack (CC0), se estiver no projeto
	if ResourceLoader.exists("res://assets/fx/kenney/smoke_04.png"):
		mat_p.albedo_texture = load("res://assets/fx/kenney/smoke_04.png")
		mat_p.albedo_color = Color(1.25, 1.2, 1.1, 0.5)
	_malha_poeira = QuadMesh.new()
	_malha_poeira.size = Vector2(1.0, 1.0)
	_malha_poeira.material = mat_p
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, 0.45))
	cv.add_point(Vector2(1.0, 1.0))
	_cresce = CurveTexture.new()
	_cresce.curve = cv
	_tex_folha = _gradiente(PackedColorArray([COR_FOLHA_ESCURA, COR_FOLHA_CLARA]), PackedFloat32Array([0.0, 1.0]))
	_tex_poeira = _gradiente(PackedColorArray([COR_POEIRA_A, COR_POEIRA_B]), PackedFloat32Array([0.0, 1.0]))
	_tex_fade = _gradiente(
		PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]),
		PackedFloat32Array([0.0, 0.55, 1.0]))
	# folhas contínuas enquanto o robô segue por dentro da copa
	_mat_continuas = ParticleProcessMaterial.new()
	_mat_continuas.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_mat_continuas.emission_sphere_radius = 0.6
	_mat_continuas.spread = 35.0
	_mat_continuas.initial_velocity_min = 1.5
	_mat_continuas.initial_velocity_max = 3.0
	_mat_continuas.gravity = Vector3(0, -1.2, 0)
	_mat_continuas.damping_min = 2.5
	_mat_continuas.damping_max = 3.5
	_mat_continuas.angle_min = 0.0
	_mat_continuas.angle_max = 360.0
	_mat_continuas.angular_velocity_min = -300.0
	_mat_continuas.angular_velocity_max = 300.0
	_mat_continuas.scale_min = 0.8
	_mat_continuas.scale_max = 1.2
	_mat_continuas.color_initial_ramp = _tex_folha
	_mat_continuas.color_ramp = _tex_fade
	_continuas = GPUParticles3D.new()
	_continuas.one_shot = false
	_continuas.explosiveness = 0.0
	_continuas.amount = 24
	_continuas.lifetime = 1.0
	_continuas.emitting = false
	_continuas.process_material = _mat_continuas
	_continuas.draw_pass_1 = _malha_folha
	_continuas.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	_continuas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_continuas)
	if armadura:
		armadura.estado_mudou.connect(_ao_mudar_estado)


func _physics_process(delta: float) -> void:
	if armadura == null or mapa == null:
		return
	_tempo += delta
	var vel := armadura.velocity
	var v := vel.length()
	var p := armadura.global_position + Vector3(0, 0.6, 0)
	# copas: entrada com velocidade gera explosão; dentro e se movendo, folhas contínuas
	var agora := _copas_em(p)
	for i in agora:
		if not _dentro.has(i) and v > LIMIAR_COPA:
			copas_atravessadas += 1
			atravessou_copa.emit(p, v)
			if _tempo - _ultimo_disparo.get(i, -1000.0) >= INTERVALO_EXPLOSAO:
				_ultimo_disparo[i] = _tempo
				_explosao_folhas(p, vel)
	_dentro = agora
	var emitir := not agora.is_empty() and v > 2.0
	_continuas.global_position = p
	if emitir:
		_mat_continuas.direction = vel.normalized()
	_continuas.emitting = emitir
	# esquiva no chão: risco de poeira no começo
	var esquivando_agora := armadura.esquivando > 0.0
	if esquivando_agora and not _esquivando_ant and armadura.is_on_floor():
		var dir := -armadura.esquiva_dir
		if dir.length() < 0.1:
			dir = Vector3.BACK
		_risco_esquiva(_ponto_chao(armadura.global_position), dir.normalized())
	_esquivando_ant = esquivando_agora


## Árvores (índice -> true) cuja copa contém o ponto, olhando as 9 células em volta.
func _copas_em(p: Vector3) -> Dictionary:
	var achou := {}
	var cel := Vector2i(floori(p.x / Ilha.CELULA_ARVORE), floori(p.z / Ilha.CELULA_ARVORE))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := cel + Vector2i(dx, dz)
			if not mapa._grade_arv.has(c):
				continue
			for i in mapa._grade_arv[c]:
				if _na_copa(i, p):
					achou[i] = true
	return achou


## Elipsoide da copa: folhosa 4 a 11 m × escala (raio 4), conífera 2 a 13 m × escala (raio 2,5).
func _na_copa(i: int, p: Vector3) -> bool:
	var base: Vector3 = mapa.arv_pos[i]
	var s: float = mapa.arv_escala[i]
	var folhosa: bool = mapa.arv_tipo[i] == 1
	var rh := (5.2 if folhosa else 2.8) * s
	var rv := (4.3 if folhosa else 6.5) * s
	var d := p - (base + Vector3(0, 7.5 * s, 0))
	return (d.x * d.x + d.z * d.z) / (rh * rh) + (d.y * d.y) / (rv * rv) <= 1.0


func _explosao_folhas(pos: Vector3, vel: Vector3) -> void:
	var v := vel.length()
	var qtd := int(clampf(40.0 + (v - 4.0) * 50.0 / 16.0, 40.0, 90.0))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.3
	mat.direction = vel.normalized()
	mat.spread = 40.0
	mat.initial_velocity_min = 2.0 + 0.1 * v
	mat.initial_velocity_max = 3.5 + 0.2 * v
	mat.gravity = Vector3(0, -1.2, 0)
	mat.damping_min = 2.5
	mat.damping_max = 3.5
	mat.angle_min = 0.0
	mat.angle_max = 360.0
	mat.angular_velocity_min = -300.0
	mat.angular_velocity_max = 300.0
	mat.scale_min = 0.8
	mat.scale_max = 1.2
	mat.color_initial_ramp = _tex_folha
	mat.color_ramp = _tex_fade
	_emitir(pos, qtd, 1.6, mat, _malha_folha)


func _ao_mudar_estado(novo: int) -> void:
	if armadura == null or mapa == null:
		return
	var chao := _ponto_chao(armadura.global_position)
	match novo:
		Armadura.Estado.POUSO:
			if armadura.pouso_forca >= 0.75:
				_anel_poeira(chao, 3.6, 44, true)
				get_tree().create_timer(0.1).timeout.connect(_anel_poeira.bind(chao, 3.6, 24, true))
			else:
				_anel_poeira(chao, 1.5, 20, false)
		Armadura.Estado.DECOLAGEM:
			if armadura.altura_do_chao() < 4.0:  # a decolagem começa no ar: o sopro só levanta poeira perto do chão
				_sopro_decolagem(chao + Vector3(0, 0.2, 0))


## Pouso: anel rente ao chão que se abre e sobe um pouco.
func _anel_poeira(pos: Vector3, raio: float, qtd: int, forte: bool) -> void:
	poeiras += 1
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_height = 0.05
	mat.emission_ring_radius = raio * 0.35
	mat.emission_ring_inner_radius = raio * 0.3
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 180.0
	mat.flatness = 1.0
	mat.initial_velocity_min = raio * 1.6
	mat.initial_velocity_max = raio * 2.6
	mat.damping_min = raio * 3.5
	mat.damping_max = raio * 4.5
	mat.gravity = Vector3(0, 0.6, 0)
	mat.scale_min = 0.9 if forte else 0.6
	mat.scale_max = 1.7 if forte else 1.0
	mat.scale_curve = _cresce
	mat.color_initial_ramp = _tex_poeira
	mat.color_ramp = _tex_fade
	_emitir(pos, qtd, 1.2 if forte else 0.9, mat, _malha_poeira)


## Decolagem: sopro de poeira para baixo e para os lados.
func _sopro_decolagem(pos: Vector3) -> void:
	poeiras += 1
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_height = 0.05
	mat.emission_ring_radius = 0.5
	mat.emission_ring_inner_radius = 0.4
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 180.0
	mat.flatness = 1.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.damping_min = 5.0
	mat.damping_max = 7.0
	mat.gravity = Vector3(0, 0.4, 0)
	mat.scale_min = 0.4
	mat.scale_max = 0.8
	mat.scale_curve = _cresce
	mat.color_initial_ramp = _tex_poeira
	mat.color_ramp = _tex_fade
	_emitir(pos, 30, 1.0, mat, _malha_poeira)


## Esquiva no chão: um risco pequeno de poeira na direção contrária ao movimento.
func _risco_esquiva(pos: Vector3, dir: Vector3) -> void:
	poeiras += 1
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = dir
	mat.spread = 25.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.2
	mat.damping_min = 3.0
	mat.damping_max = 4.0
	mat.scale_min = 0.25
	mat.scale_max = 0.45
	mat.color_initial_ramp = _tex_poeira
	mat.color_ramp = _tex_fade
	_emitir(pos, 8, 0.5, mat, _malha_poeira)


## Cria um emissor de uma só vez, põe no mundo e o libera depois de emitir.
func _emitir(pos: Vector3, qtd: int, vida: float, mat: ParticleProcessMaterial, malha: QuadMesh) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = qtd
	p.lifetime = vida
	p.process_material = mat
	p.draw_pass_1 = malha
	p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(vida + 0.5).timeout.connect(p.queue_free)


func _ponto_chao(p: Vector3) -> Vector3:
	return Vector3(p.x, mapa.altura(p.x, p.z) + 0.12, p.z)


static func _gradiente(cores: PackedColorArray, posicoes: PackedFloat32Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = cores
	g.offsets = posicoes
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
