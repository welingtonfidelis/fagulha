class_name Zangao
extends MaquinaPequena
## Zangão: voador de 0,9 m. Ronda em volta da casa a uns 15 m do chão, acima das copas; vendo o robô (45 m), chega perto,
## fica rodeando a 12–18 m e solta tiros lentos, um de cada vez, que dá para desviar. É mais lento que o
## voo de cruzeiro do robô, então dá para fugir. Dois tiros do robô desligam: cai, fuma e religa depois.

enum Estado { RONDA, CACA, VOLTA }
const NOMES := ["ronda", "caça", "volta"]
const VER := 45.0
const PERDER := 80.0
const ALTURA := 15.0  # acima das copas
const VEL_RONDA := 3.0
const VEL_CACA := 12.0
const RAIO_RONDA := 16.0
const DIST_TIRO := 15.0
const TEMPO_TIRO := 2.6
const TEMPO_AVISO := 0.7
const VEL_PROJETIL := 15.0
const RAIO_GOLPE := 1.1
const FORCA_GOLPE := 5.0

var estado := Estado.RONDA
var disparos := 0
var pose_foto := -1

var _vel := Vector3.ZERO
var _fase := 0.0
var _recarga := 1.5
var _aviso := 0.0
var _helices: Array[MeshInstance3D] = []
var _tiros: Array[Dictionary] = []
var _mat_tiro := StandardMaterial3D.new()
var _queda := 0.0
var _lado := 1.0


func raio_acerto() -> float:
	return 0.75


func som_motor() -> String:
	return "zangao_loop"


func _ready() -> void:
	_montar_base()
	var casco := material("casco")
	var claro := material("casco_claro")
	var ferro := material("ferrugem")
	# corpo: uma lentilha de metal, o aro em volta, a lente na frente (-Z) e duas hélices em braços
	peca(bola(0.36), casco, Vector3.ZERO, null, Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	var aro := TorusMesh.new()
	aro.inner_radius = 0.36
	aro.outer_radius = 0.45
	aro.rings = 20
	aro.ring_segments = 8
	peca(aro, claro, Vector3.ZERO)
	peca(bola(0.12), mat_lente, Vector3(0, -0.03, -0.3))
	peca(bola(0.17), ferro, Vector3(0, -0.03, -0.2))
	peca(caixa(Vector3(0.06, 0.26, 0.06)), ferro, Vector3(0.1, 0.3, 0.12), null, Vector3(0.2, 0, -0.3))
	for lado: float in [-1.0, 1.0]:
		peca(caixa(Vector3(0.3, 0.05, 0.07)), ferro, Vector3(lado * 0.55, 0.06, 0.0))
		var h := peca(caixa(Vector3(0.5, 0.015, 0.06)), claro, Vector3(lado * 0.7, 0.12, 0.0))
		_helices.append(h)
		peca(bola(0.06), casco, Vector3(lado * 0.7, 0.09, 0.0))
	_mat_tiro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_tiro.albedo_color = Color(1.0, 0.5, 0.2)
	_lado = 1.0 if semente % 2 == 0 else -1.0
	_fase = _rng.randf() * TAU
	var h0 := mapa.altura(casa.x, casa.z)
	global_position = Vector3(casa.x, h0 + ALTURA, casa.z) + Vector3(cos(_fase), 0, sin(_fase)) * RAIO_RONDA * 0.5


func nome_estado() -> String:
	return "desligado" if desligada else NOMES[estado]


func _provocada() -> void:
	if estado == Estado.RONDA:
		estado = Estado.CACA


func religar() -> void:
	super()
	_queda = 0.0
	estado = Estado.VOLTA


func _process(delta: float) -> void:
	_atualizar_tiros(delta)
	if pose_foto >= 0:
		_helices_girar(delta, 30.0)
		_lente_brilho(1.0 + pose_foto * 2.0)
		return
	if _passo_base(delta):
		# desligado: cai e fica no chão, tombado
		var chao := mapa.altura(global_position.x, global_position.z) + 0.25
		_vel.y -= 14.0 * delta
		_vel.x *= exp(-2.0 * delta)
		_vel.z *= exp(-2.0 * delta)
		global_position += _vel * delta
		if global_position.y <= chao:
			global_position.y = chao
			_vel = Vector3.ZERO
			_queda = minf(1.0, _queda + delta * 3.0)
		_corpo.rotation.z = lerpf(_corpo.rotation.z, 0.5 * _queda, 0.2)
		return
	_corpo.rotation.z = lerpf(_corpo.rotation.z, 0.0, 0.1)
	var ve := alvo_visivel(VER, global_position)
	var alvo_p := centro_alvo() if alvo else global_position
	var dist := global_position.distance_to(alvo_p)
	var quer := global_position
	var vmax := VEL_RONDA
	match estado:
		Estado.RONDA:
			_fase += delta * VEL_RONDA / RAIO_RONDA * _lado
			quer = Vector3(casa.x + cos(_fase) * RAIO_RONDA, 0, casa.z + sin(_fase) * RAIO_RONDA)
			quer.y = mapa.altura(quer.x, quer.z) + ALTURA
			if ve:
				estado = Estado.CACA
				_recarga = 1.2
		Estado.CACA:
			vmax = VEL_CACA
			if alvo == null or alvo.em_pane or alvo.graca_pane > 0.0 or dist > PERDER:
				estado = Estado.VOLTA
			else:
				# rodeia o robô, um pouco acima dele
				_fase += delta * 0.5 * _lado
				quer = alvo_p + Vector3(cos(_fase), 0, sin(_fase)) * DIST_TIRO
				quer.y = maxf(alvo_p.y + 3.5, mapa.altura(quer.x, quer.z) + 3.0)
				_recarga -= delta
				if _aviso > 0.0:
					_aviso -= delta
					if _aviso <= 0.0:
						_atirar(alvo_p)
				elif _recarga <= 0.0 and ve and dist < DIST_TIRO * 1.8:
					_aviso = TEMPO_AVISO
					_recarga = TEMPO_TIRO
		Estado.VOLTA:
			vmax = VEL_CACA * 0.6
			quer = Vector3(casa.x, mapa.altura(casa.x, casa.z) + ALTURA, casa.z)
			if global_position.distance_to(quer) < 4.0:
				estado = Estado.RONDA
			elif ve and dist < VER * 0.6:
				estado = Estado.CACA
	var para := quer - global_position
	_vel = _vel.lerp(para.limit_length(1.0) * vmax if para.length() > 1.0 else para * vmax, 1.0 - exp(-2.5 * delta))
	global_position += _vel * delta
	# nunca entra no chão
	var piso := mapa.altura(global_position.x, global_position.z) + 1.5
	if global_position.y < piso:
		global_position.y = piso
	global_position.y += sin(_relogio * 2.3 + _fase) * 0.01
	# olha para o robô caçando, senão para onde vai
	var olhar := alvo_p - global_position if estado == Estado.CACA else _vel
	if Vector2(olhar.x, olhar.z).length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(-olhar.x, -olhar.z), 1.0 - exp(-5.0 * delta))
	_corpo.rotation.x = lerpf(_corpo.rotation.x, clampf(-Vector2(_vel.x, _vel.z).length() * 0.03, -0.4, 0.0), 0.1)
	_helices_girar(delta, 40.0)
	_lente_brilho(5.0 if _aviso > 0.0 else (2.2 if estado == Estado.CACA else 0.8))


func _helices_girar(delta: float, vel: float) -> void:
	for h in _helices:
		h.rotation.y += vel * delta


func _atirar(para: Vector3) -> void:
	disparos += 1
	Som.toque3d(self, Som.variacao("tiro_zangao", 2), global_position, -4.0, 8.0, 70.0)
	var mi := MeshInstance3D.new()
	mi.mesh = bola(0.16)
	mi.material_override = _mat_tiro
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	var de := global_position + (para - global_position).normalized() * 0.5
	mi.global_position = de
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.4, 0.15)
	luz.light_energy = 1.5
	luz.omni_range = 3.5
	mi.add_child(luz)
	_tiros.append({"no": mi, "pos": de, "dir": (para - de).normalized(), "andou": 0.0})


func _atualizar_tiros(delta: float) -> void:
	var i := _tiros.size() - 1
	while i >= 0:
		var t := _tiros[i]
		var p: Vector3 = t["pos"] + (t["dir"] as Vector3) * VEL_PROJETIL * delta
		t["pos"] = p
		t["andou"] = float(t["andou"]) + VEL_PROJETIL * delta
		var no: MeshInstance3D = t["no"]
		no.global_position = p
		var fim := float(t["andou"]) > 70.0 or p.y < mapa.altura(p.x, p.z)
		if not fim and alvo != null and is_instance_valid(alvo) and not alvo.em_pane and p.distance_to(centro_alvo()) < RAIO_GOLPE:
			alvo.levar_golpe(t["dir"], FORCA_GOLPE)
			golpes_dados += 1
			fim = true
		if fim:
			no.queue_free()
			_tiros.remove_at(i)
		i -= 1
