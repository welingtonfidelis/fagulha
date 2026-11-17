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
static func clarao(pai: Node, onde: Vector3, dir: Vector3, tam := 1.0, imagem := "muzzle_01", cor := Color(1.0, 0.85, 0.45)) -> void:
	if pai == null or not pai.is_inside_tree() or not onde.is_finite() or dir.length() < 0.01:
		return
	_contar("clarao")
	var no := cruzado(imagem, cor.lerp(Color.WHITE, 0.35), 0.55 * tam, 1.1 * tam, -0.5 * tam, imagem != "muzzle_01")
	no.top_level = true
	pai.add_child(no)
	no.look_at_from_position(onde, onde + dir, Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.RIGHT)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.6 * tam
	luz.omni_range = 2.4 * tam
	luz.position.z = -0.4 * tam  # à frente da boca, para iluminar adiante e não o corpo
	luz.shadow_enabled = false
	no.add_child(luz)
	var tw := no.create_tween()
	tw.tween_property(no, "scale", Vector3(0.5, 0.5, 1.25), 0.09)
	tw.tween_callback(no.queue_free)


## O risco de luz que o tiro deixa no ar, da boca da arma até onde vai bater: aparece e some num instante.
static func risco(pai: Node, de: Vector3, ate: Vector3, cor: Color, grosso := 1.0) -> void:
	var comp := minf(de.distance_to(ate), 60.0)
	if pai == null or not pai.is_inside_tree() or comp < 1.0:
		return
	var no := cruzado("trace_02", Color(cor.r, cor.g, cor.b, 0.55), 0.22 * grosso, comp, -comp * 0.5, true)
	no.top_level = true
	pai.add_child(no)
	var dir := (ate - de).normalized()
	no.look_at_from_position(de, de + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT)
	var tw := no.create_tween()
	tw.tween_property(no, "scale", Vector3(0.15, 0.15, 1.0), 0.16)
	tw.tween_callback(no.queue_free)


## O impacto de um tiro de laser, na cor dele: um anel que abre, um brilho e faíscas.
static func impacto_laser(pai: Node, onde: Vector3, cor: Color, tam := 1.0) -> void:
	if pai == null or not pai.is_inside_tree() or not onde.is_finite():
		return
	_leva(pai, onde, "circle_02", cor, true, 1, 0.22, 1.5 * tam, Vector2.ZERO, Vector3.ZERO, 0.0, 2.4)
	_leva(pai, onde, "light_02", cor.lerp(Color.WHITE, 0.5), true, 1, 0.14, 1.6 * tam, Vector2.ZERO, Vector3.ZERO, 0.0, 1.4)
	_leva(pai, onde, "spark_06", cor.lerp(Color.WHITE, 0.3), true, 7, 0.35, 0.45 * tam, Vector2(3.0, 8.0), Vector3(0, -10.0, 0), 80.0, 0.3)
	_leva(pai, onde, "smoke_07", Color(0.6, 0.6, 0.62, 0.4), false, 2, 0.8, 0.6 * tam, Vector2(0.3, 0.8), Vector3(0, 0.8, 0), 40.0, 2.0)


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


## O estouro de uma granada ou de um míssil (partículas do Kenney Particle Pack): um clarão em estrela, a
## bola de fogo em duas camadas, riscos de faísca, torrões de terra que saltam e caem, um anel de choque
## que corre pelo chão, a coluna de fumaça e a marca de queimado. `raio` é o do dano.
static func estouro(pai: Node, onde: Vector3, raio: float) -> void:
	if pai == null or not pai.is_inside_tree() or not onde.is_finite():
		return
	_contar("estouro")
	var r := raio * 0.5
	_leva(pai, onde + Vector3(0, 0.5, 0), "flare_01", Color(1.0, 0.95, 0.8), true, 1, 0.16, r * 5.0, Vector2.ZERO, Vector3.ZERO, 0.0, 1.6)
	# a bola de fogo soma luz (em mistura comum ela saía marrom e apagada no sol)
	_leva(pai, onde + Vector3(0, 0.6, 0), "flame_04", Color(1.0, 0.5, 0.14), true, 14, 0.6, r * 1.9, Vector2(1.0, r * 2.4), Vector3(0, 2.5, 0), 180.0, 2.2)
	_leva(pai, onde + Vector3(0, 0.7, 0), "fire_02", Color(1.0, 0.86, 0.45), true, 10, 0.42, r * 1.4, Vector2(0.6, r * 1.6), Vector3(0, 3.0, 0), 180.0, 1.8)
	_leva(pai, onde + Vector3(0, 0.3, 0), "spark_04", Color(1.0, 0.82, 0.5), true, 16, 0.55, r * 0.9, Vector2(r * 3.0, r * 6.5), Vector3(0, -6.0, 0), 85.0, 0.4)
	_leva(pai, onde + Vector3(0, 0.2, 0), "light_01", Color(1.0, 0.75, 0.35), true, 26, 1.0, 0.22, Vector2(6.0, 16.0), Vector3(0, -16.0, 0), 75.0, 0.3)
	_leva(pai, onde + Vector3(0, 0.2, 0), "dirt_02", Color(0.34, 0.27, 0.19), false, 12, 1.1, r * 0.4, Vector2(5.0, 11.0), Vector3(0, -20.0, 0), 50.0, 0.8)
	_leva(pai, onde + Vector3(0, 0.8, 0), "smoke_02", Color(0.42, 0.4, 0.4, 0.8), false, 9, 2.8, r * 1.5, Vector2(0.8, 2.6), Vector3(0, 2.4, 0), 60.0, 2.6)
	_leva(pai, onde + Vector3(0, 0.4, 0), "smoke_10", Color(0.62, 0.6, 0.58, 0.55), false, 6, 1.7, r * 1.8, Vector2(2.0, 4.5), Vector3(0, 0.4, 0), 88.0, 2.2)
	# o anel de choque e a marca de queimado ficam deitados no chão
	for dados in [["circle_02", Color(1.0, 0.85, 0.6, 0.9), true, 0.3, raio * 2.3], ["scorch_01", Color(0.08, 0.07, 0.06, 0.75), false, 0.7, raio * 1.3]]:
		var chao := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.orientation = PlaneMesh.FACE_Y
		chao.mesh = q
		var m := mat(dados[0], dados[1], dados[2], false).duplicate() as StandardMaterial3D
		chao.material_override = m
		chao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chao.top_level = true
		chao.position = onde + Vector3(0, 0.12 if dados[2] else 0.06, 0)
		chao.scale = Vector3.ONE * float(dados[4]) * (0.25 if dados[2] else 1.0)
		pai.add_child(chao)
		var tw := chao.create_tween()
		tw.set_parallel(true)
		if dados[2]:
			tw.tween_property(chao, "scale", Vector3.ONE * float(dados[4]), float(dados[3])).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(m, "albedo_color:a", 0.0, float(dados[3]))
		else:
			tw.tween_property(m, "albedo_color:a", 0.0, 6.0).set_delay(1.5)
		tw.set_parallel(false)
		tw.tween_callback(chao.queue_free)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 6.0
	luz.omni_range = raio * 3.0
	luz.shadow_enabled = false
	luz.top_level = true
	pai.add_child(luz)
	luz.global_position = onde + Vector3(0, 0.8, 0)
	var tl := luz.create_tween()
	tl.tween_property(luz, "light_energy", 0.0, 0.4)
	tl.tween_callback(luz.queue_free)


## O rastro do golpe de espada: um arco de luz deitado na frente do robô, que varre de um lado ao outro e some.
static func arco_espada(pai: Node, onde: Vector3, frente: Vector3, lado: float, raio: float, cor: Color) -> void:
	if pai == null or not pai.is_inside_tree() or frente.length() < 0.01:
		return
	_contar("espada")
	var no := Node3D.new()
	no.top_level = true
	pai.add_child(no)
	no.look_at_from_position(onde, onde + frente, Vector3.UP)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(raio * 2.2, raio * 1.5)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	# o rastro é um leque parado e fraco, que só acende e apaga: a lâmina de verdade é a que vai na mão do
	# robô (girando junto, o rastro parecia uma segunda espada)
	var m := mat("slash_02", Color(cor.r, cor.g, cor.b, 0.0), true, false).duplicate() as StandardMaterial3D
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0, -raio * 0.5)
	mi.scale.x = lado
	no.add_child(mi)
	var tw := no.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.38, 0.12)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(no.queue_free)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.2
	luz.omni_range = raio * 2.0
	luz.shadow_enabled = false
	luz.position = Vector3(0, 0.2, -raio * 0.5)
	no.add_child(luz)


## A aura de subir de nível: presa ao robô por uns dois segundos e meio. Uma coluna de luz que sobe e apaga,
## três anéis que sobem dos pés à cabeça um atrás do outro, um círculo aceso no chão, estrelinhas subindo
## em espiral e um clarão. `alt` é a altura do robô.
static func aura_nivel(robo: Node3D, alt: float) -> void:
	if robo == null or not robo.is_inside_tree():
		return
	_contar("aura")
	var cor := Color(0.4, 1.0, 0.85)
	var dourado := Color(1.0, 0.85, 0.4)
	var no := Node3D.new()
	robo.add_child(no)
	# a coluna de luz
	var coluna := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = alt * 0.42
	cm.bottom_radius = alt * 0.5
	cm.height = alt * 2.6
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 20
	coluna.mesh = cm
	var mc := StandardMaterial3D.new()
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mc.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mc.cull_mode = BaseMaterial3D.CULL_DISABLED
	mc.albedo_color = Color(cor.r, cor.g, cor.b, 0.0)
	mc.albedo_texture = load(PASTA % "trace_02")
	coluna.material_override = mc
	coluna.position.y = alt * 1.3
	coluna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(coluna)
	var tc := coluna.create_tween()
	tc.tween_property(mc, "albedo_color:a", 0.55, 0.25)
	tc.tween_property(mc, "albedo_color:a", 0.3, 1.5)
	tc.tween_property(mc, "albedo_color:a", 0.0, 0.7)
	# os anéis que sobem
	for i in 3:
		var anel := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = alt * 0.4
		tm.outer_radius = alt * 0.46
		tm.rings = 32
		tm.ring_segments = 6
		anel.mesh = tm
		var ma := StandardMaterial3D.new()
		ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ma.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ma.albedo_color = Color(dourado.r, dourado.g, dourado.b, 0.0)
		anel.material_override = ma
		anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(anel)
		var ta := anel.create_tween()
		ta.tween_interval(i * 0.4)
		ta.tween_property(ma, "albedo_color:a", 0.95, 0.1)
		ta.parallel().tween_property(anel, "position:y", alt * 1.25, 0.9).from(0.05)
		ta.parallel().tween_property(anel, "scale", Vector3(0.6, 1.0, 0.6), 0.9).from(Vector3(1.25, 1.0, 1.25))
		ta.tween_property(ma, "albedo_color:a", 0.0, 0.25)
	# o círculo no chão
	var chao := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * alt * 2.6
	q.orientation = PlaneMesh.FACE_Y
	chao.mesh = q
	var mch := mat("magic_03", cor, true, false).duplicate() as StandardMaterial3D
	chao.material_override = mch
	chao.position.y = 0.06
	chao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(chao)
	var tch := chao.create_tween()
	tch.tween_property(chao, "rotation:y", TAU * 0.6, 2.4)
	tch.parallel().tween_property(mch, "albedo_color:a", 0.0, 0.8).set_delay(1.6)
	# estrelinhas e brilhos subindo
	var estrelas := _leva(no, robo.global_position + Vector3(0, 0.2, 0), "star_04", dourado, true, 26, 1.6, alt * 0.22, Vector2(alt * 0.9, alt * 1.9), Vector3(0, 1.0, 0), 28.0, 0.4)
	estrelas.explosiveness = 0.25
	estrelas.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	estrelas.emission_ring_axis = Vector3.UP
	estrelas.emission_ring_radius = alt * 0.45
	estrelas.emission_ring_inner_radius = alt * 0.3
	estrelas.emission_ring_height = 0.1
	estrelas.orbit_velocity_min = 0.4
	estrelas.orbit_velocity_max = 0.8
	_leva(no, robo.global_position + Vector3(0, alt * 0.5, 0), "flare_01", Color(1.0, 0.97, 0.85), true, 1, 0.3, alt * 3.2, Vector2.ZERO, Vector3.ZERO, 0.0, 1.5)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 0.0
	luz.omni_range = alt * 5.0
	luz.shadow_enabled = false
	luz.position.y = alt * 0.7
	no.add_child(luz)
	var tl := luz.create_tween()
	tl.tween_property(luz, "light_energy", 4.0, 0.2)
	tl.tween_property(luz, "light_energy", 0.0, 2.2)
	_soltar(no, 2.8)


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
