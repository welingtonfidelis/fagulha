class_name EfeitosAgua
extends Node3D
## "Física da água" visual: o robô mergulha e faz respingo, anda na água rasa e deixa anéis, voa rente
## à superfície e solta borrifo e riscas, e paira baixo sobre a água e a faz abrir anéis.
## Nada faz sombra e tudo se libera sozinho. Precisa de `armadura` e `mapa` antes do add_child.
## A superfície vem de mapa.agua(x, z) (-INF onde não há água); tudo fica em superfície + 0,03.

signal respingou(posicao: Vector3, forca: float)

const ALTURA_SUPERFICIE := 0.03
const MAX_ANEIS := 40
const QUEDA_MINIMA := 2.0  # m/s para a entrada na água dar respingo
const RASANTE_ALTURA := 3.0  # m acima da superfície
const RASANTE_VEL := 10.0  # m/s
const RASANTE_INTERVALO := 0.12
const RASO_PROFUNDIDADE := 1.5  # m: água mais funda que isso não conta como rasa
const RASO_INTERVALO_ANDANDO := 0.35
const RASO_INTERVALO_PARADO := 1.2
const PAIRAR_ALTURA := 4.0
const PAIRAR_INTERVALO := 0.5

var armadura: Armadura
var mapa: Ilha
var respingos := 0  # contador para teste
var aneis := 0  # contador para teste (anéis criados, não os vivos)

var _malha_gota: SphereMesh
var _malha_anel: TorusMesh
var _rastro: GPUParticles3D
var _anel_vivos: Array[MeshInstance3D] = []
var _iniciado := false
var _dentro_antes := false
var _vy_antes := 0.0
var _t_rasante := 0.0
var _t_raso := 0.0
var _t_pairar := 0.0


func _ready() -> void:
	var mat_gota := StandardMaterial3D.new()
	mat_gota.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_gota.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_gota.albedo_color = Color(0.84, 0.94, 1.0, 0.9)
	_malha_gota = SphereMesh.new()
	_malha_gota.radius = 0.05
	_malha_gota.height = 0.1
	_malha_gota.radial_segments = 8
	_malha_gota.rings = 4
	_malha_gota.material = mat_gota
	_malha_anel = TorusMesh.new()
	_malha_anel.inner_radius = 0.97  # anel fino: a espessura cresce junto com o raio
	_malha_anel.outer_radius = 1.0
	# borrifo do rasante: liga e desliga, as gotas sobem pouco e ficam para trás
	_rastro = GPUParticles3D.new()
	_rastro.name = "Rastro"
	_rastro.amount = 30
	_rastro.lifetime = 0.9
	_rastro.emitting = false
	_rastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rastro.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm_rastro := ParticleProcessMaterial.new()
	pm_rastro.direction = Vector3(0, 0.35, -1).normalized()  # -Z do emissor aponta para trás do robô
	pm_rastro.spread = 25.0
	pm_rastro.initial_velocity_min = 1.5
	pm_rastro.initial_velocity_max = 3.0
	pm_rastro.gravity = Vector3(0, -3.0, 0)
	pm_rastro.scale_min = 0.4
	pm_rastro.scale_max = 0.9
	_rastro.process_material = pm_rastro
	_rastro.draw_pass_1 = _malha_gota
	add_child(_rastro)


func _physics_process(delta: float) -> void:
	if armadura == null or mapa == null:
		return
	var p := armadura.global_position
	var v := armadura.velocity
	var s: float = mapa.agua(p.x, p.z)
	var tem := s > -INF
	var dentro := tem and p.y < s
	if not _iniciado:
		_iniciado = true
		_dentro_antes = dentro
		_vy_antes = v.y

	# 1) entrada na água: respingo proporcional à queda
	if dentro and not _dentro_antes:
		var queda := minf(v.y, _vy_antes)
		if queda < -QUEDA_MINIMA:
			_respingo(Vector3(p.x, s + ALTURA_SUPERFICIE, p.z), -queda)
	_dentro_antes = dentro
	_vy_antes = v.y

	# 2) andando ou parado na água rasa: anéis pequenos
	var raso := dentro and armadura.is_on_floor() and s - mapa.altura(p.x, p.z) < RASO_PROFUNDIDADE
	if raso:
		_t_raso += delta
		var andando := Vector2(v.x, v.z).length() > 0.3
		var intervalo := RASO_INTERVALO_ANDANDO if andando else RASO_INTERVALO_PARADO
		if _t_raso >= intervalo:
			_t_raso -= intervalo
			_anel(Vector3(p.x, s + ALTURA_SUPERFICIE, p.z), 0.2, 0.9, 0.6, 0.55)
	else:
		_t_raso = 0.0

	# 3) rasante: borrifo atrás do robô e riscas na superfície
	var acima := p.y - s
	var rasante := tem and armadura.em_voo() and acima < RASANTE_ALTURA and acima > -1.0 and v.length() > RASANTE_VEL
	_rastro.emitting = rasante
	if rasante:
		var tras := Vector3.BACK
		if Vector2(v.x, v.z).length() > 0.5:
			tras = Vector3(-v.x, 0.0, -v.z).normalized()
		_rastro.global_transform = Transform3D(Basis.looking_at(tras, Vector3.UP), Vector3(p.x, s + 0.05, p.z) + tras * 0.8)
		_t_rasante += delta
		if _t_rasante >= RASANTE_INTERVALO:
			_t_rasante -= RASANTE_INTERVALO
			_anel(Vector3(p.x, s + ALTURA_SUPERFICIE, p.z), 0.3, 1.5, 0.5, 0.55)
	else:
		_t_rasante = 0.0

	# 4) pairando baixo sobre a água: a água abre embaixo dele
	if tem and armadura.estado == Armadura.Estado.PAIRAR and acima < PAIRAR_ALTURA:
		_t_pairar += delta
		if _t_pairar >= PAIRAR_INTERVALO:
			_t_pairar -= PAIRAR_INTERVALO
			_anel(Vector3(p.x, s + ALTURA_SUPERFICIE, p.z), 0.5, 2.2, 1.4, 0.7)
	else:
		_t_pairar = 0.0


func _respingo(p: Vector3, forca: float) -> void:
	respingos += 1
	respingou.emit(p, forca)
	var t := clampf((forca - QUEDA_MINIMA) / 14.0, 0.0, 1.0)  # queda de ~16 m/s = respingo cheio
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 38.0
	pm.initial_velocity_min = lerpf(2.5, 4.5, t)
	pm.initial_velocity_max = lerpf(3.5, 6.5, t)
	pm.gravity = Vector3(0, -14.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	var gotas := GPUParticles3D.new()
	gotas.one_shot = true
	gotas.explosiveness = 1.0
	gotas.amount = int(lerpf(20.0, 40.0, t))
	gotas.lifetime = 0.7
	gotas.process_material = pm
	gotas.draw_pass_1 = _malha_gota
	gotas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gotas.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 8, 10))
	add_child(gotas)
	gotas.global_position = p
	gotas.emitting = true
	_liberar_depois(gotas, 1.0)
	_anel(p, 0.3, 3.0, 0.9, 0.75)


## Um anel na superfície, que cresce de r0 a r1 em `dur` segundos e some.
func _anel(p: Vector3, r0: float, r1: float, dur: float, alfa: float) -> void:
	if _anel_vivos.size() >= MAX_ANEIS:
		var velho: MeshInstance3D = _anel_vivos.pop_front()
		if is_instance_valid(velho):
			velho.queue_free()
	var n := MeshInstance3D.new()
	n.mesh = _malha_anel
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.82, 0.93, 1.0, alfa)
	n.material_override = m
	add_child(n)
	n.global_position = p
	n.scale = Vector3(r0, 1.0, r0)
	_anel_vivos.append(n)
	aneis += 1
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "scale", Vector3(r1, 1.0, r1), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.finished.connect(_soltar_anel.bind(n))


func _soltar_anel(n: MeshInstance3D) -> void:
	_anel_vivos.erase(n)
	if is_instance_valid(n):
		n.queue_free()


func _liberar_depois(n: Node, tempo: float) -> void:
	get_tree().create_timer(tempo).timeout.connect(_liberar.bind(n))


func _liberar(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()
