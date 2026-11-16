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
	# o corpo é o Mike do pacote: atarracado, de braços grandes, com 0,9 m
	montar_mech("mike", 0.9)
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
	if mech:
		match estado:
			Estado.INVESTE:
				mech.tocar("Run", 1.8)
			Estado.ARMA:
				mech.tocar("Idle", 3.0)
			Estado.CANSADO:
				mech.tocar("Idle", 0.5)
			_:
				if vel > 0.0:
					mech.tocar("Walk", 1.3)
				else:
					mech.tocar("Idle")
	var brilho := 0.7
	match estado:
		Estado.ARMA:
			brilho = 5.0
		Estado.INVESTE:
			brilho = 3.5
		Estado.CANSADO:
			brilho = 0.25
	_lente_brilho(brilho)
