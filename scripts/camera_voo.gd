class_name CameraVoo
extends Node3D
## Câmera por cima do ombro: perto no chão, mais longe no voo, campo de visão abrindo com a velocidade,
## leve atraso na decolagem, inclinação nas curvas e tremor em alta velocidade e no superaquecimento.
## No voo, a armadura segue para onde a câmera aponta (mira()).

var alvo: Armadura
var ilha: Ilha
var cam: Camera3D
var yaw := 0.0
var pitch := -0.12

var _pivo := Vector3.ZERO
var _dist := Ajustes.CAM_DIST_CHAO
var _mistura := 0.0
var _mira := 0.0
var _roll := 0.0
var _iniciado := false
var _t := 0.0
var _afasta := 0.0
var primeira := false  # scanner: a câmera vai para os olhos do robô
var zoom := 0.0  # 0 a 1, só em primeira pessoa


func _ready() -> void:
	cam = Camera3D.new()
	cam.near = 0.15
	cam.far = 14000.0
	cam.fov = Ajustes.FOV_CHAO
	add_child(cam)
	cam.current = true


func mira() -> Vector3:
	return -Basis.from_euler(Vector3(pitch, yaw, 0.0)).z


func basis_plano() -> Basis:
	return Basis(Vector3.UP, yaw)


# ajustes da pausa (Guardado): multiplicador da sensibilidade e o eixo de cima-baixo invertido
static var fator_sens := 1.0
static var inverter_y := false
static var afasta := 0.0  # 0 a 1: a câmera sobe e recua (segurando a granada, para ver o arco e onde cai)
static var travada := false  # a roda de armas está aberta: o analógico direito escolhe a arma, não gira a câmera
static var fov_mira := Ajustes.FOV_MIRA  # o zoom ao mirar (a arma de precisão fecha)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not travada:
		var mm := event as InputEventMouseMotion
		var sens := Ajustes.SENS_MOUSE * fator_sens * (Ajustes.SENS_MIRANDO if alvo and alvo.mirando_agora() else 1.0)
		yaw -= mm.relative.x * sens
		pitch -= mm.relative.y * sens * (-1.0 if inverter_y else 1.0)
		pitch = clampf(pitch, deg_to_rad(-85.0), deg_to_rad(75.0))


func _process(delta: float) -> void:
	if alvo == null:
		return
	_t += delta
	var olhar := Input.get_vector("olhar_esquerda", "olhar_direita", "olhar_cima", "olhar_baixo")
	olhar *= olhar.length()  # curva: precisão no meio, rapidez no fim
	if travada:
		olhar = Vector2.ZERO
	var sens := Ajustes.SENS_ANALOGICO * fator_sens * (Ajustes.SENS_MIRANDO if alvo.mirando_agora() else 1.0)
	if alvo.mirando_agora():
		sens *= clampf(fov_mira / Ajustes.FOV_MIRA, 0.3, 1.0)  # com zoom, a mira anda mais devagar
	if primeira:
		sens *= lerpf(0.8, 0.22, zoom)  # com zoom, a mira anda mais devagar
	yaw -= olhar.x * sens * delta
	pitch -= olhar.y * sens * 0.75 * delta * (-1.0 if inverter_y else 1.0)
	pitch = clampf(pitch, deg_to_rad(-85.0), deg_to_rad(75.0))

	if primeira:
		# pelos olhos do robô: sem ombro, sem distância, e o campo de visão fecha com o zoom
		global_position = alvo.pos_suave() + Vector3(0.0, 2.05 * Armadura.porte, 0.0)
		global_basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
		cam.position = Vector3.ZERO
		cam.fov = lerpf(cam.fov, lerpf(58.0, 13.0, zoom), 1.0 - exp(-9.0 * delta))
		_pivo = alvo.pos_suave() + Vector3(0.0, 2.15 * Armadura.porte * 1.12, 0.0)
		return
	var voando := alvo.em_voo() or alvo.estado == Armadura.Estado.NADO
	_mistura = move_toward(_mistura, 1.0 if voando else 0.0, delta * 1.6)
	var m := smoothstep(0.0, 1.0, _mistura)
	_mira = move_toward(_mira, 1.0 if alvo.mirando_agora() else 0.0, delta * 5.0)
	var mi := smoothstep(0.0, 1.0, _mira)
	var v := alvo.velocity.length()
	var kp := pow(Armadura.porte, 0.75)  # robô pequeno: câmera mais perto e mais baixa
	var alvo_pivo := alvo.pos_suave() + Vector3(0.0, lerpf(lerpf(2.15, 1.5, m), 2.05, mi) * Armadura.porte * 1.12, 0.0)
	alvo_pivo.y -= [0.0, 0.45, 0.85][alvo.postura] * Armadura.porte  # abaixado e sentado, a câmera desce junto
	_afasta = lerpf(_afasta, afasta, 1.0 - exp(-7.0 * delta))
	alvo_pivo.y += _afasta * 1.7 * kp
	if not _iniciado:
		_pivo = alvo_pivo
		_iniciado = true
	# seguir com atraso: na decolagem a câmera fica para trás e depois alcança
	var taxa := lerpf(16.0, 14.0, m)
	_pivo = _pivo.lerp(alvo_pivo, 1.0 - exp(-taxa * delta))
	var dist_alvo := lerpf(Ajustes.CAM_DIST_CHAO, Ajustes.CAM_DIST_VOO, m) + clampf(v - Ajustes.VOO_ALVO, 0.0, 30.0) * 0.03 * m
	dist_alvo = (lerpf(dist_alvo, Ajustes.CAM_DIST_MIRA, mi) + _afasta * 3.4) * kp
	_dist = lerpf(_dist, dist_alvo, 1.0 - exp(-(3.0 + 6.0 * mi) * delta))
	var b := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var ombro := lerpf(lerpf(0.7, 0.35, m), 0.85, mi) * kp
	var origem := _pivo + b * Vector3(ombro, 0.0, 0.0)
	var desejado := origem + b * Vector3(0.0, 0.0, _dist)
	# não atravessar o chão nem as árvores
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origem, desejado, 1 | 2, [alvo.get_rid()])
	var hit := espaco.intersect_ray(q)
	if not hit.is_empty():
		var ponto: Vector3 = hit["position"]
		var dir := (desejado - origem).normalized()
		desejado = origem + dir * maxf(0.4, origem.distance_to(ponto) - 0.35)
	if ilha:
		desejado.y = maxf(desejado.y, ilha.altura(desejado.x, desejado.z) + 0.6)
	global_position = desejado
	# inclinar nas curvas do voo
	var roll_alvo := clampf(alvo.giro_lateral * 0.08 - alvo.inclinar * 0.05, -0.17, 0.17) * m
	_roll = lerpf(_roll, roll_alvo, 1.0 - exp(-4.0 * delta))
	global_basis = Basis.from_euler(Vector3(pitch, yaw, _roll))
	# campo de visão pela velocidade
	var fov_alvo := lerpf(Ajustes.FOV_CHAO, Ajustes.FOV_MAX, clampf((v - 6.0) / (Ajustes.VEL_TOPO - 6.0), 0.0, 1.0) * m)
	if not voando and v > Ajustes.ANDAR + 1.0:
		fov_alvo += 3.0
	fov_alvo = lerpf(fov_alvo, fov_mira, mi)
	cam.fov = lerpf(cam.fov, fov_alvo, 1.0 - exp(-(3.0 + 6.0 * mi) * delta))
	# tremor
	var forca := alvo.tremor + maxf(0.0, v - Ajustes.ARRANCADA_ALVO) * 0.006 * m + (0.05 if alvo.superaquecido else 0.0)
	var tr := Vector3(sin(_t * 37.0) + sin(_t * 23.0) * 0.5, cos(_t * 31.0) + sin(_t * 17.0) * 0.5, 0.0)
	cam.position = tr * forca * 0.12
