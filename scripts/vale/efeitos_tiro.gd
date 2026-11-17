class_name EfeitosTiro
extends RefCounted
## Efeitos dos tiros, com as imagens do Kenney Particle Pack (CC0) soltas pelo sistema de partículas da Godot:
## o clarão na boca da arma, o rastro das balas, as faíscas do impacto e a explosão com fumaça do míssil.
## Tudo se solta sozinho e nada faz sombra.

const PASTA := "res://assets/fx/kenney/%s.png"

static var _mats := {}
static var contagem := {}  # nome do efeito -> quantas vezes saiu (testes)


## Material de uma imagem: `soma` acende (clarão, fogo), sem ela cobre (fumaça). `virado` encara a câmera.
static func mat(imagem: String, cor: Color, soma := true, virado := true) -> StandardMaterial3D:
	var chave := "%s|%s|%s|%s" % [imagem, cor.to_html(), soma, virado]
	if not _mats.has(chave):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if soma else BaseMaterial3D.BLEND_MODE_MIX
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_texture = load(PASTA % imagem)
		m.albedo_color = cor
		m.vertex_color_use_as_albedo = true
		if virado:
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.billboard_keep_scale = true
		_mats[chave] = m
	return _mats[chave]


static func _soltar(no: Node, depois: float) -> void:
	no.get_tree().create_timer(depois).timeout.connect(no.queue_free)


static func _contar(nome: String) -> void:
	contagem[nome] = int(contagem.get(nome, 0)) + 1


## Dois quadros cruzados com a imagem esticada ao longo de -Z do nó (rastro, chama): vistos de qualquer lado.
static func cruzado(imagem: String, cor: Color, largura: float, comprimento: float, centro_z := 0.0, soma := true) -> Node3D:
	var no := Node3D.new()
	for giro: float in [0.0, PI / 2.0]:
		var q := QuadMesh.new()
		q.size = Vector2(largura, comprimento)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mat(imagem, cor, soma, false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# o quadro nasce de pé (Y); deita para o comprido ficar em -Z, com o alto da imagem para a frente
		mi.rotation = Vector3(-PI / 2.0, 0.0, giro)
		mi.rotation_order = EULER_ORDER_YXZ
		mi.position.z = centro_z
		no.add_child(mi)
	return no


## Clarão na boca da arma: a língua de fogo para a frente e um brilho curto.
static func clarao(pai: Node, onde: Vector3, dir: Vector3, tam := 1.0) -> void:
	if pai == null or not pai.is_inside_tree() or not onde.is_finite() or dir.length() < 0.01:
		return
	_contar("clarao")
	var no := cruzado("muzzle_01", Color(1.0, 0.85, 0.45), 0.55 * tam, 1.1 * tam, -0.5 * tam, false)
	no.top_level = true
	pai.add_child(no)
	no.look_at_from_position(onde, onde + dir, Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.RIGHT)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.7, 0.35)
	luz.light_energy = 2.2 * tam
	luz.omni_range = 4.0 * tam
	luz.shadow_enabled = false
	no.add_child(luz)
	var tw := no.create_tween()
	tw.tween_property(no, "scale", Vector3(0.5, 0.5, 1.25), 0.09)
	tw.tween_callback(no.queue_free)


## Uma leva de partículas que sai de uma vez e some.
static func _leva(pai: Node, onde: Vector3, imagem: String, cor: Color, soma: bool, quantas: int, vida: float, tam: float,
		vel: Vector2, gravidade: Vector3, abre: float, cresce := 1.0, dir := Vector3.UP) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = quantas
	p.lifetime = vida
	p.local_coords = false
	p.direction = dir
	p.spread = abre
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.gravity = gravidade
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curva := Curve.new()
	curva.add_point(Vector2(0, 1.0 / maxf(cresce, 0.01) if cresce > 1.0 else 1.0))
	curva.add_point(Vector2(1, 1.0 if cresce > 1.0 else cresce))
	p.scale_amount_curve = curva
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.material = mat(imagem, cor, soma, true)
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.use_fixed_seed = true
	p.seed = int(contagem.get("leva", 0)) * 7919 + 13
	_contar("leva")
	# a posição vai antes de entrar na cena: posta depois, as partículas nasciam no centro do mapa
	p.top_level = true
	p.position = onde
	p.emitting = true
	pai.add_child(p)
	_soltar(p, vida + 0.3)
	return p


## Impacto de bala: um estalo claro, faíscas que saltam e caem, e um fio de fumaça.
static func impacto(pai: Node, onde: Vector3, tam := 1.0) -> void:
	if pai == null or not pai.is_inside_tree() or not onde.is_finite():
		return
	_contar("impacto")
	_leva(pai, onde, "scorch_02", Color(1.0, 0.92, 0.7), false, 1, 0.14, 1.3 * tam, Vector2.ZERO, Vector3.ZERO, 0.0, 1.8)
	_leva(pai, onde, "light_01", Color(1.0, 0.75, 0.4), true, 9, 0.45, 0.16 * tam, Vector2(3.0, 7.0), Vector3(0, -14.0, 0), 70.0, 0.3)
	_leva(pai, onde, "smoke_07", Color(0.55, 0.55, 0.57, 0.5), false, 3, 0.9, 0.7 * tam, Vector2(0.4, 1.0), Vector3(0, 0.8, 0), 40.0, 2.2)


## Explosão: bola de fogo que abre e apaga, faíscas, um anel de calor e fumaça escura que sobe.
static func explosao(pai: Node, onde: Vector3, raio: float) -> void:
	if pai == null or not pai.is_inside_tree() or not onde.is_finite():
		return
	_contar("explosao")
	_leva(pai, onde, "scorch_02", Color(1.0, 0.95, 0.8), false, 1, 0.16, raio * 1.6, Vector2.ZERO, Vector3.ZERO, 0.0, 2.2)
	_leva(pai, onde + Vector3(0, 0.3, 0), "fire_01", Color(1.0, 0.5, 0.12), false, 9, 0.6, raio * 1.05, Vector2(0.8, raio * 1.5), Vector3(0, 1.5, 0), 180.0, 1.9)
	_leva(pai, onde + Vector3(0, 0.3, 0), "fire_02", Color(1.0, 0.82, 0.35), false, 7, 0.45, raio * 0.85, Vector2(0.5, raio * 1.1), Vector3(0, 2.0, 0), 180.0, 1.6)
	_leva(pai, onde, "light_01", Color(1.0, 0.7, 0.3), true, 16, 0.7, 0.2, Vector2(5.0, 12.0), Vector3(0, -12.0, 0), 80.0, 0.3)
	_leva(pai, onde + Vector3(0, 0.5, 0), "smoke_10", Color(0.16, 0.15, 0.16, 0.9), false, 11, 2.2, raio * 1.1, Vector2(0.6, 2.4), Vector3(0, 1.6, 0), 75.0, 2.4)
	_leva(pai, onde + Vector3(0, 0.1, 0), "scorch_01", Color(1.0, 0.6, 0.3, 0.7), true, 1, 0.35, raio * 1.2, Vector2.ZERO, Vector3.ZERO, 0.0, 2.6)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 5.0
	luz.omni_range = raio * 3.0
	luz.shadow_enabled = false
	luz.top_level = true
	pai.add_child(luz)
	luz.global_position = onde + Vector3(0, 0.6, 0)
	var tw := luz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.35)
	tw.tween_callback(luz.queue_free)


## Fumaça contínua atrás de um míssil (filha dele; as partículas ficam para trás no mundo).
static func rastro_fumaca(pai: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 0.9
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, 0.5, 0)
	p.angle_max = 360.0
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.35))
	curva.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curva
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.8, 0.6, 0.9), Color(0.8, 0.8, 0.8, 0.6), Color(0.6, 0.6, 0.6, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.75, 0.75)
	q.material = mat("smoke_07", Color(0.7, 0.7, 0.72, 0.6), false, true)
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position.z = 0.45
	pai.add_child(p)
