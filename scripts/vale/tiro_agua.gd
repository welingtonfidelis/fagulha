class_name TiroAgua
extends RefCounted
## O tiro que bate na água (pedido do usuário, 2026-11-23; escolhidos o jeito de cada arma e os explosivos fortes).
## A água não tem colisão: o raio do tiro passava pela lâmina e batia no fundo. `cruzamento` acha onde o caminho
## entra na água, e o tiro para ali com o efeito da arma:
## - pistola e tiro duplo: respingo pequeno, um anel e uma fumacinha de vapor (o laser é energia);
## - rajada: respingo curto e baixo a cada tiro; em sequência vira uma fileira, como chuva grossa;
## - precisão: um esguicho fino e alto;
## - canhão e míssil: coluna d'água com espuma e dois anéis largos (o míssil, maior e com fogo);
## - granada: entra com um respingo, afunda soltando bolhas e estoura embaixo: sobe uma cúpula e depois a coluna.
## Tudo com as imagens do Kenney Particle Pack (`EfeitosTiro._leva`), sem sombra, e se solta sozinho.

const ACIMA := 0.03  # os efeitos deitados ficam um pouco acima da lâmina
const MAX_ANEIS := 24

static var _malha_anel: TorusMesh
static var _malha_cupula: SphereMesh
static var _malha_gota: SphereMesh
static var _aneis: Array[MeshInstance3D] = []
static var contagem := {}  # efeito -> quantas vezes saiu (testes)


## Onde o caminho de `de` a `ate` entra na água; Vector3.INF se não entra (ou se já sai de dentro dela).
## A lâmina é quase plana: basta olhar o ponto final e, se ele estiver embaixo, procurar a entrada por bisseção.
static func cruzamento(mapa: Node, de: Vector3, ate: Vector3) -> Vector3:
	if mapa == null or not mapa.has_method("agua"):
		return Vector3.INF
	var s_fim: float = mapa.agua(ate.x, ate.z)
	if s_fim == -INF or ate.y >= s_fim:
		return Vector3.INF
	var s_ini: float = mapa.agua(de.x, de.z)
	if s_ini != -INF and de.y <= s_ini:
		return Vector3.INF
	var a := 0.0
	var b := 1.0
	for i in 14:
		var k := (a + b) * 0.5
		var p := de.lerp(ate, k)
		var s: float = mapa.agua(p.x, p.z)
		if s != -INF and p.y < s:
			b = k
		else:
			a = k
	var q := de.lerp(ate, b)
	var sq: float = mapa.agua(q.x, q.z)
	return Vector3(q.x, sq if sq != -INF else q.y, q.z)


static func _contar(nome: String) -> void:
	contagem[nome] = int(contagem.get(nome, 0)) + 1


static func _pronto(pai: Node, onde: Vector3) -> bool:
	return pai != null and pai.is_inside_tree() and onde.is_finite()


## Um anel na lâmina que cresce de r0 a r1 em `dur` segundos e some (o mesmo desenho dos anéis do mergulho).
static func anel(pai: Node, p: Vector3, r0: float, r1: float, dur: float, alfa: float, atraso := 0.0) -> void:
	if _malha_anel == null:
		_malha_anel = TorusMesh.new()
		_malha_anel.inner_radius = 0.975  # fino: a espessura cresce com o raio
		_malha_anel.outer_radius = 1.0
		_malha_anel.rings = 48
		_malha_anel.ring_segments = 6
	while _aneis.size() >= MAX_ANEIS:
		var velho: MeshInstance3D = _aneis.pop_front()
		if is_instance_valid(velho):
			velho.queue_free()
	var n := MeshInstance3D.new()
	n.mesh = _malha_anel
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.86, 0.95, 1.0, alfa if atraso <= 0.0 else 0.0)
	m.render_priority = 1  # desenha depois da lâmina (transparente também), senão a água cobre
	n.material_override = m
	n.top_level = true
	pai.add_child(n)
	n.global_position = Vector3(p.x, p.y + ACIMA, p.z)
	n.scale = Vector3(r0, 0.35, r0)  # achatado: deitado na lâmina, não um aro de pé
	_aneis.append(n)
	var tw := n.create_tween()
	if atraso > 0.0:
		tw.tween_interval(atraso)
		tw.tween_callback(func() -> void: m.albedo_color.a = alfa)
	tw.set_parallel(true)
	tw.tween_property(n, "scale", Vector3(r1, 0.35, r1), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		_aneis.erase(n)
		n.queue_free())


## Uma mancha deitada na lâmina (espuma, brilho): cresce um pouco e some em `dur`.
static func _mancha(pai: Node, p: Vector3, imagem: String, cor: Color, soma: bool, tam0: float, tam1: float, dur: float) -> void:
	var n := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	n.mesh = q
	var m := EfeitosTiro.mat(imagem, cor, soma, false).duplicate() as StandardMaterial3D
	m.render_priority = 1
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.top_level = true
	pai.add_child(n)
	n.global_position = Vector3(p.x, p.y + ACIMA * 2.0, p.z)
	n.rotation.y = randf() * TAU
	n.scale = Vector3.ONE * tam0
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "scale", Vector3.ONE * tam1, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(n.queue_free)


## Gotas que saltam e caem (bolinhas, como as do mergulho): `quantas`, com velocidade `vel` (mín., máx.),
## abertas `abre` graus em volta do alto.
static func _gotas(pai: Node, p: Vector3, quantas: int, vel: Vector2, abre: float, tam: float, vida := 0.9) -> void:
	if _malha_gota == null:
		var mg := StandardMaterial3D.new()
		mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mg.albedo_color = Color(0.88, 0.96, 1.0, 0.92)
		mg.vertex_color_use_as_albedo = true
		_malha_gota = SphereMesh.new()
		_malha_gota.radius = 0.5
		_malha_gota.height = 1.0
		_malha_gota.radial_segments = 8
		_malha_gota.rings = 4
		_malha_gota.material = mg
	var g := CPUParticles3D.new()
	g.one_shot = true
	g.explosiveness = 0.92
	g.amount = quantas
	g.lifetime = vida
	g.local_coords = false
	g.direction = Vector3.UP
	g.spread = abre
	g.initial_velocity_min = vel.x
	g.initial_velocity_max = vel.y
	g.gravity = Vector3(0, -15.0, 0)
	g.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	g.emission_sphere_radius = tam * 1.5
	g.scale_amount_min = tam * 0.6
	g.scale_amount_max = tam * 1.3
	var curva := Curve.new()
	curva.add_point(Vector2(0, 1.0))
	curva.add_point(Vector2(1, 0.45))
	g.scale_amount_curve = curva
	var cores := Gradient.new()
	cores.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	cores.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.color_ramp = cores
	g.mesh = _malha_gota
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.top_level = true
	g.position = p
	g.emitting = true
	pai.add_child(g)
	EfeitosTiro._soltar(g, vida + 0.3)


## Vapor: fumaça branca e mole que sobe devagar e abre.
static func _vapor(pai: Node, p: Vector3, quantas: int, tam: float, alfa := 0.55) -> void:
	EfeitosTiro._leva(pai, p + Vector3(0, 0.15, 0), "smoke_04", Color(1.3, 1.32, 1.35, alfa), false, quantas, 1.7, tam,
		Vector2(0.4, 1.1), Vector3(0, 0.9, 0), 25.0, 2.6)


## O estalo do laser na lâmina: um brilho curto na cor do tiro.
static func _brilho(pai: Node, p: Vector3, cor: Color, tam: float) -> void:
	EfeitosTiro._leva(pai, p + Vector3(0, 0.05, 0), "light_02", cor.lerp(Color.WHITE, 0.45), true, 1, 0.16, tam,
		Vector2.ZERO, Vector3.ZERO, 0.0, 1.5)
	_mancha(pai, p, "circle_02", Color(cor.r, cor.g, cor.b, 0.8), true, tam * 0.4, tam * 1.1, 0.3)


## Um jorrinho branco que sobe e desaba (o corpo do respingo: as gotas sozinhas sumiam de longe).
static func _jorro(pai: Node, p: Vector3, quantas: int, tam: float, vel: Vector2, abre := 10.0) -> void:
	EfeitosTiro._leva(pai, p + Vector3(0, 0.1, 0), "smoke_04", Color(1.35, 1.38, 1.4, 0.85), false, quantas, 0.9, tam,
		vel, Vector3(0, -9.0, 0), abre, 1.6)


## Pistola e tiro duplo. O jogo vê o tiro de longe (20 a 40 m): o respingo é maior que o de verdade.
static func laser(pai: Node, p: Vector3, cor: Color, tam := 1.0) -> void:
	if not _pronto(pai, p):
		return
	_contar("laser")
	_brilho(pai, p, cor, 1.8 * tam)
	_jorro(pai, p, 4, 0.9 * tam, Vector2(2.5, 4.5) * sqrt(tam))
	_gotas(pai, p, 22, Vector2(3.5, 6.5) * sqrt(tam), 25.0, 0.15 * tam, 1.0)
	EfeitosTiro._leva(pai, p, "smoke_07", Color(1.3, 1.33, 1.35, 0.6), false, 4, 0.6, 0.9 * tam, Vector2(0.8, 1.8),
		Vector3(0, -1.0, 0), 75.0, 1.8)  # borrifo baixo em volta
	_vapor(pai, p, 4, 1.5 * tam, 0.7)
	anel(pai, p, 0.2, 2.2 * tam, 1.0, 0.8)
	anel(pai, p, 0.1, 1.2 * tam, 0.8, 0.55, 0.18)


## Um tiro da rajada: mais baixo e mais curto; vários seguidos fazem a fileira.
static func rajada(pai: Node, p: Vector3, cor: Color) -> void:
	if not _pronto(pai, p):
		return
	_contar("rajada")
	_brilho(pai, p, cor, 1.0)
	_jorro(pai, p, 2, 0.6, Vector2(2.0, 3.5))
	_gotas(pai, p, 12, Vector2(2.5, 4.5), 22.0, 0.13, 0.8)
	if int(contagem["rajada"]) % 2 == 0:
		_vapor(pai, p, 1, 1.0, 0.55)
	anel(pai, p, 0.15, 1.4, 0.8, 0.7)


## Precisão: o esguicho fino e alto (uns 5 m) e um anel largo.
static func precisao(pai: Node, p: Vector3, cor: Color) -> void:
	if not _pronto(pai, p):
		return
	_contar("precisao")
	_brilho(pai, p, cor, 2.0)
	_jorro(pai, p, 6, 0.8, Vector2(5.0, 9.0), 4.0)
	_gotas(pai, p, 40, Vector2(9.0, 13.0), 3.0, 0.14, 1.5)
	EfeitosTiro._leva(pai, p + Vector3(0, 0.2, 0), "smoke_07", Color(1.3, 1.33, 1.35, 0.6), false, 10, 1.0, 0.8,
		Vector2(6.0, 10.0), Vector3(0, -8.0, 0), 3.0, 1.6)  # a névoa do jorro
	_gotas(pai, p, 14, Vector2(2.0, 4.0), 55.0, 0.12, 0.7)  # a coroa baixa
	_vapor(pai, p, 3, 1.3)
	anel(pai, p, 0.3, 3.2, 1.3, 0.8)
	anel(pai, p, 0.15, 1.8, 1.0, 0.55, 0.25)


## Canhão (forte = 0) e míssil (forte = 1): coluna d'água, coroa de gotas, espuma e anéis largos. `raio` é o do
## dano (canhão 5 m: coluna de uns 5 m); o míssil sobe mais e ainda solta um clarão de fogo e mais vapor.
static func coluna(pai: Node, p: Vector3, raio: float, forte := 0.0, cor := Color(1.0, 0.6, 0.25)) -> void:
	if not _pronto(pai, p):
		return
	_contar("coluna")
	var k := clampf(raio / 5.0, 0.6, 1.6) * lerpf(1.0, 1.15, forte)
	if forte > 0.0:
		EfeitosTiro._leva(pai, p + Vector3(0, 0.4, 0), "flare_01", Color(1.0, 0.9, 0.7), true, 1, 0.14, 7.0 * k,
			Vector2.ZERO, Vector3.ZERO, 0.0, 1.5)
		EfeitosTiro._leva(pai, p + Vector3(0, 0.5, 0), "fire_02", Color(1.0, 0.75, 0.35), true, 6, 0.35, 2.2 * k,
			Vector2(0.5, 3.0 * k), Vector3(0, 2.0, 0), 140.0, 1.5)
	else:
		_brilho(pai, p, cor, 3.0 * k)
	# o corpo da coluna: borrifo branco grosso que sobe e desaba
	EfeitosTiro._leva(pai, p + Vector3(0, 0.3, 0), "smoke_04", Color(1.35, 1.38, 1.4, 0.9), false, 18, 1.4, 1.9 * k,
		Vector2(5.0 * k, 10.0 * k), Vector3(0, -9.0, 0), 8.0, 1.9)
	_gotas(pai, p, 50, Vector2(8.0 * k, 12.5 * k), 9.0, 0.16 * k, 1.7)  # o jorro
	_gotas(pai, p, 36, Vector2(3.0 * k, 6.0 * k), 62.0, 0.13 * k, 1.1)  # a coroa que se abre
	EfeitosTiro._leva(pai, p + Vector3(0, 0.2, 0), "smoke_07", Color(0.95, 0.98, 1.0, 0.55), false, 8, 1.2, 2.6 * k,
		Vector2(2.5 * k, 5.0 * k), Vector3(0, -0.5, 0), 88.0, 2.2)  # o borrifo que corre baixo
	_vapor(pai, p, 4 + roundi(forte * 4.0), 2.6 * k, 0.6)
	_mancha(pai, p, "smoke_10", Color(1.35, 1.38, 1.4, 0.85), false, 2.0 * k, 6.5 * k, 3.2)  # a espuma
	_mancha(pai, p, "circle_05", Color(0.97, 0.99, 1.0, 0.7), false, 1.2 * k, 4.5 * k, 2.2)
	anel(pai, p, 0.4, 7.5 * k, 1.6, 0.6)
	anel(pai, p, 0.3, 5.0 * k, 1.3, 0.65, 0.3)
	anel(pai, p, 0.2, 3.0 * k, 1.0, 0.5, 0.65)


## A granada que entra: respingo médio e anel (depois ela afunda soltando bolhas, ver `bolhas`).
static func entrada(pai: Node, p: Vector3) -> void:
	if not _pronto(pai, p):
		return
	_contar("entrada")
	_gotas(pai, p, 16, Vector2(2.0, 4.0), 30.0, 0.11)
	anel(pai, p, 0.15, 1.4, 0.9, 0.75)


## Bolhas que sobem de `fundo` até a lâmina `s` (a granada afundando): bolinhas e um anel pequeno em cima.
static func bolhas(pai: Node, fundo: Vector3, s: float) -> void:
	if not _pronto(pai, fundo):
		return
	var sobe := maxf(0.3, s - fundo.y)
	EfeitosTiro._leva(pai, fundo, "circle_05", Color(0.85, 0.95, 1.0, 0.8), false, 3, sobe / 2.2, 0.07,
		Vector2(1.8, 2.6), Vector3(0, 1.5, 0), 15.0, 1.4)
	_mancha(pai, Vector3(fundo.x, s, fundo.z), "circle_05", Color(0.95, 0.99, 1.0, 0.45), false, 0.15, 0.5, 0.6)


## A granada estoura embaixo d'água: a lâmina incha numa cúpula, rompe e solta a coluna e a espuma.
static func cupula(pai: Node, p: Vector3, raio: float) -> void:
	if not _pronto(pai, p):
		return
	_contar("cupula")
	if _malha_cupula == null:
		_malha_cupula = SphereMesh.new()
		_malha_cupula.is_hemisphere = true
		_malha_cupula.radius = 1.0
		_malha_cupula.height = 1.0
		_malha_cupula.radial_segments = 24
		_malha_cupula.rings = 8
	var r := clampf(raio * 0.4, 1.2, 3.5)  # a granada (7 m de dano) faz uma cúpula de uns 2,8 m
	var n := MeshInstance3D.new()
	n.mesh = _malha_cupula
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.78, 0.9, 0.96, 0.6)
	m.roughness = 0.45
	m.metallic_specular = 0.4
	m.rim_enabled = true
	m.rim = 1.0
	m.rim_tint = 0.2
	m.render_priority = 1
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.top_level = true
	pai.add_child(n)
	n.global_position = Vector3(p.x, p.y - 0.05, p.z)
	n.scale = Vector3(r * 0.3, 0.05, r * 0.3)
	_mancha(pai, p, "light_02", Color(1.0, 0.7, 0.35, 0.7), true, r * 0.6, r * 1.6, 0.35)  # o clarão por baixo
	EfeitosTiro._leva(pai, p + Vector3(0, 0.1, 0), "smoke_07", Color(1.3, 1.33, 1.35, 0.5), false, 10, 0.5, r * 0.7,
		Vector2(r * 1.5, r * 2.5), Vector3(0, -1.0, 0), 85.0, 1.8)  # a lâmina rasga em volta
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(r * 0.95, r * 0.55, r * 0.95), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: coluna(pai, p, raio * 0.9, 0.0, Color(1.0, 0.7, 0.4)))
	tw.set_parallel(true)
	tw.tween_property(n, "scale", Vector3(r * 1.25, 0.02, r * 1.25), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.set_parallel(false)
	tw.tween_callback(n.queue_free)
