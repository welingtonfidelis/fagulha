class_name Carrapato
extends MaquinaPequena
## Carrapato: rasteiro de 0,6 m, com um aríete na frente. Anda devagar perto da casa; vendo o robô no chão
## ou voando baixo (30 m), para, treme um instante e investe em linha reta, rápido. Quem sai de lado escapa,
## e depois da investida ele fica cansado, parado, por uns segundos. Dois tiros do robô desligam.

enum Estado { RONDA, ARMA, INVESTE, CANSADO }
const NOMES := ["ronda", "armando", "investida", "cansado"]
const VER := 30.0
const ALTURA_VE := 7.0  # robô mais alto que isso do chão não interessa
const VEL_RONDA := 1.0
const VEL_INVESTE := 11.0
const RAIO_RONDA := 12.0
const TEMPO_ARMA := 0.75
const TEMPO_INVESTE := 2.0
const TEMPO_CANSADO := 2.6
const RAIO_GOLPE := 0.95
const FORCA_GOLPE := 7.0

var estado := Estado.RONDA
var investidas := 0
var pose_foto := -1

var _tempo := 0.0
var _rumo := Vector3.FORWARD
var _destino := Vector3.ZERO
var _pausa := 1.0
var _pernas_pivo: Array[Node3D] = []
var _passo := 0.0
var _bateu := false


func raio_acerto() -> float:
	return 0.7


func som_motor() -> String:
	return "carrapato_loop"


func _ready() -> void:
	_montar_base()
	var casco := material("casco")
	var claro := material("casco_claro")
	var ferro := material("ferrugem")
	# corpo: um casco baixo com a tampa clara, o aríete (um rolo de ferro entre dois braços) na frente (-Z),
	# a lente debaixo de uma viseira e seis pernas finas de duas partes
	peca(bola(0.3), casco, Vector3(0, 0.27, 0.04), null, Vector3.ZERO, Vector3(1.0, 0.55, 1.3))
	peca(bola(0.24), claro, Vector3(0, 0.33, 0.1), null, Vector3.ZERO, Vector3(0.95, 0.5, 1.05))
	var aro := TorusMesh.new()
	aro.inner_radius = 0.27
	aro.outer_radius = 0.31
	aro.rings = 18
	aro.ring_segments = 6
	peca(aro, ferro, Vector3(0, 0.25, 0.04), null, Vector3.ZERO, Vector3(1.0, 1.0, 1.3))
	var rolo := CylinderMesh.new()
	rolo.top_radius = 0.085
	rolo.bottom_radius = 0.085
	rolo.height = 0.46
	rolo.radial_segments = 10
	peca(rolo, casco, Vector3(0, 0.19, -0.47), null, Vector3(0, 0, PI * 0.5))
	for lado: float in [-1.0, 1.0]:
		peca(caixa(Vector3(0.05, 0.06, 0.26)), ferro, Vector3(lado * 0.17, 0.2, -0.36))
		var tampa := CylinderMesh.new()
		tampa.top_radius = 0.1
		tampa.bottom_radius = 0.1
		tampa.height = 0.03
		tampa.radial_segments = 10
		peca(tampa, ferro, Vector3(lado * 0.235, 0.19, -0.47), null, Vector3(0, 0, PI * 0.5))
	peca(bola(0.065), mat_lente, Vector3(0, 0.36, -0.25))
	peca(caixa(Vector3(0.22, 0.03, 0.12)), casco, Vector3(0, 0.43, -0.25), null, Vector3(0.25, 0, 0))
	for lado: float in [-1.0, 1.0]:
		for k in 3:
			var pivo := Node3D.new()
			pivo.position = Vector3(lado * 0.24, 0.24, -0.16 + k * 0.2)
			_corpo.add_child(pivo)
			# a coxa sobe para fora; a canela desce até o chão
			peca(caixa(Vector3(0.2, 0.035, 0.04)), ferro, Vector3(lado * 0.09, 0.04, 0), pivo, Vector3(0, 0, lado * 0.45))
			peca(caixa(Vector3(0.035, 0.34, 0.035)), casco, Vector3(lado * 0.2, -0.07, 0), pivo, Vector3(0, 0, lado * 0.2))
			_pernas_pivo.append(pivo)
	_destino = casa
	var q := _ponto_ronda()
	global_position = Vector3(q.x, mapa.altura(q.x, q.z), q.z)
	rotation.y = _rng.randf() * TAU


func nome_estado() -> String:
	return "desligado" if desligada else NOMES[estado]


func centro() -> Vector3:
	return global_position + Vector3(0, 0.3, 0)


func _provocada() -> void:
	if estado == Estado.RONDA and alvo:
		_armar()


func _ponto_ronda() -> Vector3:
	for k in 8:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(2.0, RAIO_RONDA)
		var x := casa.x + cos(ang) * r
		var z := casa.z + sin(ang) * r
		if _pisavel(x, z):
			return Vector3(x, 0, z)
	return casa


func _pisavel(x: float, z: float) -> bool:
	return mapa.agua(x, z) == -INF and mapa.normal_em(x, z).y > 0.8


func _armar() -> void:
	estado = Estado.ARMA
	_tempo = 0.0


func _process(delta: float) -> void:
	if pose_foto >= 0:
		_lente_brilho(1.0 + pose_foto * 2.0)
		return
	if _passo_base(delta):
		_corpo.rotation.z = lerpf(_corpo.rotation.z, 0.35, 0.1)
		return
	_corpo.rotation.z = lerpf(_corpo.rotation.z, 0.0, 0.2)
	_tempo += delta
	var vel := 0.0
	var ve := alvo_visivel(VER, centro() + Vector3(0, 0.4, 0)) and alvo.altura_do_chao() < ALTURA_VE
	match estado:
		Estado.RONDA:
			if ve:
				_armar()
			elif _pausa > 0.0:
				_pausa -= delta
			else:
				var para := _destino - global_position
				para.y = 0.0
				if para.length() < 0.6:
					_destino = _ponto_ronda()
					_pausa = _rng.randf_range(0.8, 3.0)
				else:
					_rumo = para.normalized()
					vel = VEL_RONDA
		Estado.ARMA:
			# trava o rumo no robô e treme antes de sair
			if alvo and is_instance_valid(alvo):
				var para := alvo.global_position - global_position
				para.y = 0.0
				if para.length() > 0.2:
					_rumo = para.normalized()
			_corpo.position.x = sin(_relogio * 60.0) * 0.02
			if _tempo >= TEMPO_ARMA:
				estado = Estado.INVESTE
				_tempo = 0.0
				_bateu = false
				investidas += 1
				_corpo.position.x = 0.0
		Estado.INVESTE:
			vel = VEL_INVESTE
			if not _bateu and alvo and is_instance_valid(alvo) and not alvo.em_pane and alvo.graca_pane <= 0.0:
				var d := alvo.global_position - global_position
				if Vector2(d.x, d.z).length() < RAIO_GOLPE and d.y > -0.6 and d.y < 1.4:
					alvo.levar_golpe(_rumo, FORCA_GOLPE)
					golpes_dados += 1
					_bateu = true
			if _tempo >= TEMPO_INVESTE or _bateu:
				estado = Estado.CANSADO
				_tempo = 0.0
		Estado.CANSADO:
			if _tempo >= TEMPO_CANSADO:
				estado = Estado.RONDA
				_destino = casa
				_pausa = 0.5
	if vel > 0.0:
		var novo := global_position + _rumo * vel * delta
		if _pisavel(novo.x, novo.z):
			global_position = novo
			_passo += vel * delta * 9.0
		elif estado == Estado.INVESTE:
			estado = Estado.CANSADO  # deu na água ou num barranco: para
			_tempo = 0.0
		else:
			_destino = _ponto_ronda()
	global_position.y = mapa.altura(global_position.x, global_position.z)
	rotation.y = lerp_angle(rotation.y, atan2(-_rumo.x, -_rumo.z), 1.0 - exp(-8.0 * delta))
	# o corpo deita na ladeira
	var n := mapa.normal_em(global_position.x, global_position.z)
	var frente := Vector3(-sin(rotation.y), 0, -cos(rotation.y))
	_corpo.rotation.x = lerpf(_corpo.rotation.x, asin(clampf(-n.dot(frente), -0.6, 0.6)) + (-0.12 if estado == Estado.INVESTE else 0.0), 0.2)
	for i in _pernas_pivo.size():
		# as pernas vão e voltam em dois grupos alternados
		_pernas_pivo[i].rotation.y = sin(_passo + (i % 2) * PI) * 0.45
		_pernas_pivo[i].position.y = 0.24 + maxf(0.0, cos(_passo + (i % 2) * PI)) * 0.03
	var brilho := 0.7
	match estado:
		Estado.ARMA:
			brilho = 5.0
		Estado.INVESTE:
			brilho = 3.5
		Estado.CANSADO:
			brilho = 0.25
	_lente_brilho(brilho)
