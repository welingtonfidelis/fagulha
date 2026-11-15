class_name MaquinaPequena
extends Node3D
## O que o Zangão e o Carrapato têm em comum: o corpo montado por código com peças simples, a lente
## vermelha, o calor que sobe a cada tiro do robô e desliga a máquina, a fumaça de desligada e o tempo
## até religar. Ninguém é destruído: desligam, ficam um tempo paradas e religam no mesmo lugar.
## O mergulho com impacto do robô por perto desliga na hora.
## Uso: defina mapa, alvo, casa e semente, e só então add_child.

signal desligou

const ESFRIA := 6.0  # calor perdido por segundo
const ESFRIA_ESPERA := 2.5
const TEMPO_DESLIGADA := 900.0  # 15 minutos reais de paz
const RAIO_IMPACTO := 8.0

var mapa: Ilha
var alvo: Armadura
var casa := Vector3.ZERO
var semente := 0
var calor := 0.0
var desligada := false
var desligamentos := 0
var religamentos := 0
var golpes_dados := 0
var mat_lente := StandardMaterial3D.new()

var _rng := RandomNumberGenerator.new()
var _corpo: Node3D  # o visual inteiro
var _acerto: StaticBody3D
var _fumaca: GPUParticles3D
var _pisca := 0.0
var _sem_tiro := 99.0
var _restante := 0.0
var _relogio := 0.0
var _ronco: AudioStreamPlayer3D


func calor_por_tiro() -> float:
	return 50.0


func raio_acerto() -> float:
	return 0.6


## Nome do laço de som do motor (vazio: sem som).
func som_motor() -> String:
	return ""


func centro() -> Vector3:
	return _corpo.global_position if _corpo else global_position


func _montar_base() -> void:
	add_to_group("maquinas")
	_rng.seed = semente * 6151 + 17
	_corpo = Node3D.new()
	add_child(_corpo)
	mat_lente.albedo_color = Color(1.0, 0.12, 0.08)
	mat_lente.emission_enabled = true
	mat_lente.emission = Color(1.0, 0.1, 0.05)
	mat_lente.emission_energy_multiplier = 1.0
	_acerto = StaticBody3D.new()
	_acerto.collision_layer = 2
	_acerto.collision_mask = 0
	_corpo.add_child(_acerto)
	var cs := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = raio_acerto() * 0.8
	cs.shape = esfera
	_acerto.add_child(cs)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.color = Color(0.25, 0.25, 0.27, 0.5)
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.vertex_color_use_as_albedo = true
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	quad.material = mf
	_fumaca = GPUParticles3D.new()
	_fumaca.process_material = pm
	_fumaca.draw_pass_1 = quad
	_fumaca.amount = 10
	_fumaca.lifetime = 2.2
	_fumaca.emitting = false
	_fumaca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corpo.add_child(_fumaca)
	if som_motor() != "":
		_ronco = Som.laco3d(_corpo, som_motor(), -6.0, 4.0, 40.0)


func material(nome: String) -> Material:
	return (mapa as Clareira).material(nome) if mapa is Clareira else null


func peca(malha: Mesh, mat: Material, pos: Vector3, pai: Node3D = null, giro := Vector3.ZERO, escala := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.position = pos
	mi.rotation = giro
	mi.scale = escala
	(pai if pai else _corpo).add_child(mi)
	return mi


func bola(raio: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = raio
	m.height = raio * 2.0
	m.radial_segments = 14
	m.rings = 7
	return m


func caixa(tam: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = tam
	return m


## O topo da copa mais alta em volta do ponto (-INF sem árvore por perto): quem voa passa por cima.
func topo_copas(p: Vector3, folga := 2.5) -> float:
	var topo := -INF
	var cel := Vector2i(floori(p.x / Ilha.CELULA_ARVORE), floori(p.z / Ilha.CELULA_ARVORE))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := cel + Vector2i(dx, dz)
			if not mapa._grade_arv.has(c):
				continue
			for i: int in mapa._grade_arv[c]:
				var base: Vector3 = mapa.arv_pos[i]
				var s: float = mapa.arv_escala[i]
				var folhosa: bool = mapa.arv_tipo[i] == 1
				var rh := (5.2 if folhosa else 2.8) * s + folga
				if Vector2(p.x - base.x, p.z - base.z).length_squared() < rh * rh:
					topo = maxf(topo, base.y + (7.5 + (4.3 if folhosa else 6.5)) * s)
	return topo


func alvo_visivel(alcance: float, de: Vector3) -> bool:
	if alvo == null or not is_instance_valid(alvo) or alvo.em_pane or alvo.graca_pane > 0.0:
		return false
	var c := centro_alvo()
	if de.distance_to(c) > alcance:
		return false
	for k in range(1, 7):
		var p := de.lerp(c, float(k) / 7.0)
		if p.y < mapa.altura(p.x, p.z):
			return false
	return true


func centro_alvo() -> Vector3:
	return alvo.global_position + Vector3.UP * 0.6


## Um tiro do robô perto do corpo: esquenta e pisca. Com calor 100, desliga.
func levar_tiro(ponto: Vector3) -> void:
	if _corpo == null or desligada or ponto.distance_to(centro()) > raio_acerto():
		return
	calor = minf(100.0, calor + calor_por_tiro())
	_sem_tiro = 0.0
	_pisca = 0.12
	Som.toque3d(self, Som.variacao("impacto", 3), ponto, -4.0)
	_provocada()
	if calor >= 100.0:
		desligar()


## O mergulho com impacto do robô: quem está perto desliga na hora.
func levar_impacto(ponto: Vector3) -> void:
	if _corpo == null or desligada or ponto.distance_to(centro()) > RAIO_IMPACTO:
		return
	calor = 100.0
	desligar()


func _provocada() -> void:
	pass


func desligar() -> void:
	desligada = true
	desligamentos += 1
	_restante = TEMPO_DESLIGADA
	_fumaca.emitting = true
	_acerto.set_deferred("collision_layer", 0)
	if _ronco:
		_ronco.stop()
	Som.toque3d(self, "maquina_desliga", centro(), -3.0)
	desligou.emit()


func religar() -> void:
	calor = 0.0
	if not desligada:
		return
	desligada = false
	religamentos += 1
	_fumaca.emitting = false
	_acerto.set_deferred("collision_layer", 2)
	if _ronco:
		_ronco.play()


func avancar_tempo(segundos: float) -> void:
	if desligada:
		_restante -= segundos
		if _restante <= 0.0:
			religar()
	else:
		calor = 0.0


## Calor, pisca e o tempo de desligada. Devolve true enquanto estiver desligada.
func _passo_base(delta: float) -> bool:
	_relogio += delta
	_pisca = maxf(0.0, _pisca - delta)
	if desligada:
		_restante -= delta
		mat_lente.emission_energy_multiplier = 0.02
		if _restante <= 0.0:
			religar()
		return true
	_sem_tiro += delta
	if _sem_tiro > ESFRIA_ESPERA:
		calor = maxf(0.0, calor - ESFRIA * delta)
	return false


func _lente_brilho(base: float) -> void:
	mat_lente.emission_energy_multiplier = 6.0 if _pisca > 0.0 else base + calor * 0.02
