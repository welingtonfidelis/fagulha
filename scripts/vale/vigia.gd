class_name Vigia
extends MaquinaPequena
## Vigia: atirador de chão de 1,7 m (o George do pacote, de antenas). Ronda a pé em volta da casa; vendo o
## robô (42 m), vai até uns 16 m dele, fica de frente e solta tiros lentos, um de cada vez, com um aviso
## vermelho antes. Chegando perto demais ele recua. Não corre atrás de quem voa alto: fica atirando de
## baixo. Três tiros do robô desligam: cai, fuma e religa depois.

enum Estado { RONDA, CACA, VOLTA }
const NOMES := ["ronda", "caça", "volta"]
const VER := 42.0
const PERDER := 70.0
const VEL_RONDA := 1.2
const RAIO_RONDA := 14.0
const TEMPO_AVISO := 0.65

# o que muda de uma máquina para outra (a Mecha acerta estes pela ficha do sorteio)
var modelo := "george"
var altura_m := 1.7
var vel_caca := 4.2
var dist_tiro := 16.0
var tempo_tiro := 2.4
var calor_tiro := 34.0
var tipo_tiro := "bala"  # "bala", "pesado" ou "missil" (MaquinaPequena.TIROS)
var rajada := 1  # tiros por vez
var espalha := 0.03  # erro de mira, em radianos
var _rajada_resta := 0
var _rajada_t := 0.0
var corpo_a_corpo := false  # em vez de atirar, chega junto e bate (espada ou martelo)
var forca_golpe := 7.0
var rodeia := false  # em vez de ficar parado na distância de tiro, corre em volta do robô
var motor := "carrapato_loop"

var estado := Estado.RONDA
var disparos := 0
var pose_foto := -1

var _rumo := Vector3.FORWARD
var _destino := Vector3.ZERO
var _pausa := 1.0
var _recarga := 1.5
var _aviso := 0.0
var _lado := 1.0
var _tiro_t := 0.0  # tempo que falta da animação de tiro


func calor_por_tiro() -> float:
	return calor_tiro


func raio_acerto() -> float:
	return 0.55 * altura_m


func som_motor() -> String:
	return motor


func centro() -> Vector3:
	return global_position + Vector3(0, altura_m * 0.6, 0)


func _ready() -> void:
	_montar_base()
	_acerto.position.y = altura_m * 0.6
	_fumaca.position.y = altura_m * 0.5
	_montar_corpo()
	_lado = 1.0 if semente % 2 == 0 else -1.0
	_destino = casa
	var q := _ponto_ronda()
	global_position = Vector3(q.x, mapa.altura(q.x, q.z), q.z)
	rotation.y = _rng.randf() * TAU


## O corpo da máquina (quem herda pode montar outro).
func _montar_corpo() -> void:
	pass


## Desligado, o corpo deita acompanhando a inclinação do chão (a altura quem acerta é o MechVisual).
func _deitar_no_terreno(delta: float) -> void:
	var n := mapa.normal_em(global_position.x, global_position.z)
	var n_local := global_basis.inverse() * n
	var alvo_b := Basis(Quaternion(Vector3.UP, n_local.normalized()))
	_corpo.basis = _corpo.basis.slerp(alvo_b, 1.0 - exp(-5.0 * delta))


func nome_estado() -> String:
	return "desligado" if desligada else NOMES[estado]


func _provocada() -> void:
	if estado != Estado.CACA and alvo:
		estado = Estado.CACA
		_recarga = 0.8


func _ponto_ronda() -> Vector3:
	for k in 8:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(3.0, RAIO_RONDA)
		var x := casa.x + cos(ang) * r
		var z := casa.z + sin(ang) * r
		if _pisavel(x, z):
			return Vector3(x, 0, z)
	return casa


func _pisavel(x: float, z: float) -> bool:
	return mapa.agua(x, z) == -INF and mapa.normal_em(x, z).y > 0.8


func _process(delta: float) -> void:
	atualizar_tiros(delta)
	if pose_foto >= 0:
		_lente_brilho(1.0 + pose_foto * 2.0)
		return
	if _passo_base(delta):
		_deitar_no_terreno(delta)
		return
	_corpo.basis = _corpo.basis.slerp(Basis.IDENTITY, 1.0 - exp(-6.0 * delta))
	_tiro_t = maxf(0.0, _tiro_t - delta)
	var vel := 0.0
	var olho := centro() + Vector3(0, altura_m * 0.3, 0)
	var ve := alvo_visivel(VER, olho)
	var alvo_p := centro_alvo() if alvo else global_position
	var para_alvo := alvo_p - global_position
	var dist := Vector2(para_alvo.x, para_alvo.z).length()
	match estado:
		Estado.RONDA:
			if ve:
				estado = Estado.CACA
				_recarga = 1.0
			elif _pausa > 0.0:
				_pausa -= delta
			else:
				var para := _destino - global_position
				para.y = 0.0
				if para.length() < 0.7:
					_destino = _ponto_ronda()
					_pausa = _rng.randf_range(1.0, 4.0)
				else:
					_rumo = para.normalized()
					vel = VEL_RONDA
		Estado.CACA:
			if alvo == null or alvo.em_pane or alvo.graca_pane > 0.0 or para_alvo.length() > PERDER:
				estado = Estado.VOLTA
				_aviso = 0.0
			else:
				if dist > 0.3:
					_rumo = Vector3(para_alvo.x, 0, para_alvo.z).normalized()
				# chega até a distância de tiro; perto demais, recua de frente para o robô
				if _aviso <= 0.0 and _tiro_t <= 0.0:
					if dist > dist_tiro * 1.25:
						vel = vel_caca
					elif dist < dist_tiro * 0.55:
						vel = -vel_caca * 0.6
					elif rodeia:
						# corre em volta do robô, de lado para ele, e para na hora de atirar
						_rumo = _rumo.cross(Vector3.UP) * _lado
						vel = vel_caca
				_recarga -= delta
				if (_aviso > 0.0 or _tiro_t > 0.0) and dist > 0.3:
					_rumo = Vector3(para_alvo.x, 0, para_alvo.z).normalized()
				if _aviso > 0.0 and _tiro_t <= 0.0 and mech and _aviso <= mech.tempo_do_tiro():
					_tiro_t = mech.tempo_do_tiro() + 0.75  # a animação começa antes, para o tiro sair com o braço estendido
				if _aviso > 0.0:
					_aviso -= delta
					if _aviso <= 0.0:
						disparos += 1
						_tiro_t = maxf(_tiro_t, 0.5)
						if corpo_a_corpo:
							# o golpe só pega se o robô ainda estiver ao alcance
							if para_alvo.length() < dist_tiro * 1.6 and alvo and not alvo.em_pane:
								alvo.levar_golpe(_rumo, forca_golpe)
								golpes_dados += 1
						else:
							_rajada_resta = rajada
							_rajada_t = 0.0
				elif _recarga <= 0.0 and ve and para_alvo.length() < dist_tiro * 2.2:
					_aviso = TEMPO_AVISO
					_recarga = tempo_tiro
		Estado.VOLTA:
			var para := casa - global_position
			para.y = 0.0
			if para.length() < 2.0:
				estado = Estado.RONDA
				_destino = casa
				_pausa = 1.0
			else:
				_rumo = para.normalized()
				vel = vel_caca * 0.7
			if ve and para_alvo.length() < VER * 0.6:
				estado = Estado.CACA
	# a rajada sai aos poucos, cada tiro com o erro de mira dele
	if _rajada_resta > 0 and mech:
		_rajada_t -= delta
		if _rajada_t <= 0.0:
			_rajada_resta -= 1
			_rajada_t = 0.13 if tipo_tiro == "bala" else 0.28
			_tiro_t = maxf(_tiro_t, 0.3)
			atirar_em(mech.ponto_tiro() + _rumo * 0.35, alvo_p, tipo_tiro, espalha)
	if vel != 0.0:
		var novo := global_position + _rumo * vel * delta
		if _pisavel(novo.x, novo.z):
			global_position = novo
		elif estado == Estado.RONDA:
			_destino = _ponto_ronda()
		elif rodeia:
			_lado = -_lado  # deu na água ou num barranco: roda para o outro lado
			vel = 0.0
		else:
			vel = 0.0
	global_position.y = mapa.altura(global_position.x, global_position.z)
	rotation.y = lerp_angle(rotation.y, atan2(-_rumo.x, -_rumo.z), 1.0 - exp(-6.0 * delta))
	if mech:
		if _tiro_t > 0.0:
			mech.tocar("Shoot", 1.0, 0.05)
		elif absf(vel) > 2.0:
			mech.tocar("Run", 1.0 if vel > 0.0 else -0.8)
		elif vel != 0.0:
			mech.tocar("Walk", 1.1)
		else:
			mech.tocar("Idle")
	_lente_brilho(6.0 if _aviso > 0.0 else (2.4 if estado == Estado.CACA else 0.8))
