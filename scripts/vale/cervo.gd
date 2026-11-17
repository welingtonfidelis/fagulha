class_name Cervo
extends Node3D
## Cervo que pasta, anda, fica alerta e foge de uma ameaça (o robô, ou qualquer Node3D).
## Animado por código sobre res://assets/vale/cervo.glb (tools/vale/natureza.py, função cervo).
## O modelo olha para +Z; o nó do modelo gira 180° em Y, então a frente do cervo é -Z.
## Sem física: fica sobre o relevo (mapa.altura) e não entra na água.
## Uso: Cervo.new(), defina mapa, casa, raio_casa, semente (e ameaca, se houver), e só então add_child.

enum Estado { PASTANDO, ANDANDO, ALERTA, FUGINDO }
const NOMES := ["pastando", "andando", "alerta", "fugindo"]
const CENA := "res://assets/vale/cervo.glb"

const VEL_ANDAR := 1.2
const VEL_FUGA := 9.0
const DIST_ALERTA := 22.0  # ameaça mais perto que isso põe o cervo em alerta
const DIST_FUGA := 9.0  # mais perto que isso, foge sempre
const VEL_RAPIDA := 5.0  # ameaça mais rápida que isso, a menos de 22 m, faz fugir
const VEL_PARADA := 3.5  # ameaça até essa velocidade, a mais de 9 m, acalma o cervo
const TEMPO_CALMA := 3.0
const DIST_SEGURA := 45.0  # foge até ficar a mais de 45 m da ameaça
const DIST_PASSEIO_LONGE := 12.0  # o passeio nunca vai a menos disso da ameaça
const TEMPO_PASSEIO_MAX := 45.0
const DIST_ASSUSTAR := 60.0  # um tiro ou o robô a menos disso, mesmo sem ameaça, faz fugir

# poses, em radianos sobre o repouso das peças
const PESCOCO_PASTO := 2.3  # pescoço para baixo, focinho no capim
const PESCOCO_ALERTA := -0.35  # cabeça erguida
const PESCOCO_ANDAR := 0.2
const PESCOCO_FUGA := 0.1
const CABECA_PASTO := 0.5  # cabeça ainda mais para baixo
const AFUNDA_PASTO := 0.10  # o pescoço afunda um pouco no peito ao pastar
const PERNA_ANDAR := 0.35
const PERNA_FUGA := 0.6
const FREQ_ANDAR := 6.0
const FREQ_FUGA := 10.0
const DEFASE_PASSO := [0.0, PI, PI, 0.0]  # fe, fd, te, td: diagonais juntas (fe com td)
const DEFASE_GALOPE := [0.0, 0.0, 2.2, 2.2]  # par da frente junto, par de trás atrasado

var mapa: Ilha
var ameaca: Node3D  # o robô; pode ser null
var casa := Vector3.ZERO
var raio_casa := 40.0
var semente := 0
var estado := 0  # Estado
var pose_foto := -1  # >= 0: fica parado nesse estado, só animando (fotos)
## O corpo é um bicho animado do pacote (BichoVisual). Vazio: cerva ou, um em cada três, veado de galhada.
var desvios := 0  # rumos recusados por obstáculo (testes)
var destravou := 0  # vezes em que ficou preso e trocou o lado da volta (testes)
var _lado_desvio := 1.0
var _trava_t := 0.0
var _trava_p := Vector3.ZERO
var especie := ""
var altura_bicho := 0.0
var bicho: BichoVisual

var _rng := RandomNumberGenerator.new()
var _pronto := false
var _relogio := 0.0
var _tempo := 0.0  # tempo no estado atual
var _duracao_pasto := 6.0
var _alvo := Vector3.ZERO
var _voltando := false  # caminhando de volta para casa depois de fugir
var _rumo := Vector3.FORWARD
var _olhando := 0.0  # tempo que falta de cabeça erguida enquanto pasta
var _proximo_olhar := 4.0
var _tem_ameaca := false
var _ameaca_lida := false
var _dist := INF
var _vel := 0.0
var _pos_ameaca := Vector3.ZERO
var _calma := 0.0
var _acalmado := false
var _amp := 0.0
var _freq := FREQ_ANDAR
var _fase := 0.0
var _pitch := 0.0
var _susto := false  # fugindo de um ponto (sem ameaça por perto), como o tiro ou o robô de longe
var _susto_ponto := Vector3.ZERO
var _susto_dist := DIST_SEGURA  # foge até ficar a mais disso desse ponto

var _modelo: Node3D
var _corpo: Node3D
var _pescoco: Node3D
var _cabeca: Node3D
var _cauda: Node3D
var _pernas: Array[Node3D] = []  # fe, fd, te, td
var _rot0 := {}  # rotação de repouso de cada peça
var _pos0 := {}  # posição de repouso de cada peça


func _ready() -> void:
	add_to_group("bichos")
	_rng.seed = semente * 7919 + 17
	var cena := load(CENA) as PackedScene
	if cena == null:
		push_error("cervo: modelo não encontrado em %s" % CENA)
		return
	_modelo = cena.instantiate() as Node3D
	_modelo.rotation.y = PI  # o modelo olha para +Z; aqui a frente é -Z
	add_child(_modelo)
	_modelo.visible = false  # as peças antigas seguem só para a conta das poses; quem aparece é o bicho animado
	if especie == "":
		especie = "stag" if semente % 3 == 0 else "deer"
		altura_bicho = 1.55 if especie == "stag" else 1.3
	bicho = BichoVisual.criar(especie, altura_bicho, (mapa as Clareira)._tex if mapa is Clareira else null)
	add_child(bicho)
	_corpo = _peca("corpo")
	_pescoco = _peca("pescoco")
	_cabeca = _peca("cabeca")
	_cauda = _peca("cauda")
	_pernas.assign([_peca("perna_fe"), _peca("perna_fd"), _peca("perna_te"), _peca("perna_td")])
	if _corpo == null or _pescoco == null or _cabeca == null or _cauda == null or _pernas.has(null):
		return
	var pecas: Array = [_corpo, _pescoco, _cabeca, _cauda]
	pecas.append_array(_pernas)
	for no in pecas:
		_rot0[no] = no.rotation
		_pos0[no] = no.position
	rotation.y = _rng.randf() * TAU
	global_position = Vector3(casa.x, mapa.altura(casa.x, casa.z), casa.z)
	_duracao_pasto = _rng.randf_range(4.0, 9.0)
	_proximo_olhar = _rng.randf_range(3.0, 6.0)
	_pronto = true


func _peca(nome: String) -> Node3D:
	var no := _modelo.find_child(nome, true, false) as Node3D
	if no == null:
		push_error("cervo: peça '%s' não achada no modelo" % nome)
	return no


## Nome do estado atual, para testes e depuração.
func nome_estado() -> String:
	return NOMES[estado]


## Um susto (o robô passando perto, um tiro ou o ponto de impacto): a menos de 60 m do ponto, o cervo
## foge dele, mesmo sem ameaça. Usa a fuga existente, só que a partir do ponto.
func assustar(ponto: Vector3) -> void:
	if not _pronto or not is_inside_tree():
		return
	var d := _dist_ponto(ponto)
	if d >= DIST_ASSUSTAR:
		return
	_susto = true
	_susto_ponto = ponto
	_susto_dist = maxf(DIST_SEGURA, d + 15.0)
	_acalmado = false
	_calma = 0.0
	_mudar(Estado.FUGINDO)


func _dist_ponto(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _process(delta: float) -> void:
	if not _pronto or mapa == null:
		return
	_relogio += delta
	_tempo += delta
	if pose_foto >= 0:
		estado = pose_foto
		_olhando = 0.0
		_proximo_olhar = 99.0
		_amp = PERNA_ANDAR if estado == Estado.ANDANDO else (PERNA_FUGA if estado == Estado.FUGINDO else 0.0)
		global_position.y = mapa.altura(global_position.x, global_position.z)
		_animar(delta)
		return
	_ler_ameaca(delta)
	_decidir(delta)
	_mover(delta)
	global_position.y = mapa.altura(global_position.x, global_position.z)
	_animar(delta)


# ---------------------------------------------------------------- percepção e decisão

func _ler_ameaca(delta: float) -> void:
	_tem_ameaca = ameaca != null and is_instance_valid(ameaca)
	if not _tem_ameaca:
		_ameaca_lida = false
		return
	var p := ameaca.global_position
	_dist = Vector2(p.x - global_position.x, p.z - global_position.z).length()
	var v: Variant = ameaca.get("velocity")  # o robô (CharacterBody3D) já tem velocidade
	if v is Vector3:
		_vel = (v as Vector3).length()
	elif _ameaca_lida and delta > 0.0:
		_vel = (p - _pos_ameaca).length() / delta
	_pos_ameaca = p
	_ameaca_lida = true


func _decidir(delta: float) -> void:
	if _tem_ameaca:
		if estado == Estado.FUGINDO:
			if _dist > DIST_SEGURA:
				_voltar_para_casa()
			return
		if _dist < DIST_FUGA or (_dist < DIST_ALERTA and _vel > VEL_RAPIDA):
			_acalmado = false
			_calma = 0.0
			_mudar(Estado.FUGINDO)
			return
		if _dist >= DIST_ALERTA:
			_acalmado = false
		elif not _acalmado:
			if estado != Estado.ALERTA:
				_mudar(Estado.ALERTA)
			if _vel <= VEL_PARADA and _dist > DIST_FUGA:
				_calma += delta
				if _calma >= TEMPO_CALMA:
					_acalmado = true
					_calma = 0.0
					_mudar(Estado.PASTANDO)
					return
			else:
				_calma = 0.0
		if estado == Estado.ALERTA and (_dist >= DIST_ALERTA or _acalmado):
			_mudar(Estado.PASTANDO)
	elif _susto:
		_decidir_susto()
	elif estado == Estado.FUGINDO or estado == Estado.ALERTA:
		_acalmado = false
		_mudar(Estado.PASTANDO)


## Fugindo de um susto: segue até ficar longe do ponto e volta para casa, como na fuga da ameaça.
func _decidir_susto() -> void:
	if estado != Estado.FUGINDO:
		_susto = false
		return
	if _dist_ponto(_susto_ponto) > _susto_dist:
		_susto = false
		_voltar_para_casa()


func _mudar(novo: int) -> void:
	if novo == estado:
		return
	estado = novo
	_tempo = 0.0
	if novo == Estado.PASTANDO:
		_voltando = false
		_duracao_pasto = _rng.randf_range(4.0, 9.0)


func _voltar_para_casa() -> void:
	if _escolher_alvo(true):
		_mudar(Estado.ANDANDO)
		_voltando = true
	else:
		_mudar(Estado.PASTANDO)


# ---------------------------------------------------------------- movimento sem física

func _mover(delta: float) -> void:
	match estado:
		Estado.PASTANDO:
			if _tempo >= _duracao_pasto:
				if _escolher_alvo(false):
					_mudar(Estado.ANDANDO)
				else:
					_tempo = 0.0
		Estado.ANDANDO:
			var para := Vector3(_alvo.x - global_position.x, 0.0, _alvo.z - global_position.z)
			var fora := not _voltando and Vector2(global_position.x - casa.x, global_position.z - casa.z).length() > raio_casa
			if para.length() < 0.6 or _tempo > TEMPO_PASSEIO_MAX or fora:
				_mudar(Estado.PASTANDO)
			elif not _passo(delta, VEL_ANDAR, para.normalized(), true, 0.9):
				_mudar(Estado.PASTANDO)  # sem rumo livre até o alvo: pasta e escolhe outro
		Estado.FUGINDO:
			if _tem_ameaca:
				var fuga := Vector3(global_position.x - ameaca.global_position.x, 0.0, global_position.z - ameaca.global_position.z)
				if fuga.length() < 0.01:
					fuga = Vector3(1.0, 0.0, 0.0)
				_passo(delta, VEL_FUGA, fuga.normalized(), false, 2.5)
			elif _susto:
				var fuga_susto := Vector3(global_position.x - _susto_ponto.x, 0.0, global_position.z - _susto_ponto.z)
				if fuga_susto.length() < 0.01:
					fuga_susto = Vector3(1.0, 0.0, 0.0)
				_passo(delta, VEL_FUGA, fuga_susto.normalized(), false, 2.5)


## Anda `vel` m/s no rumo `dir` (plano). Se o passo cair na água (ou, com `seco`, em declive),
## gira 30° por vez até achar um rumo livre. Só anda de verdade quando já está virado para o rumo.
## Devolve false se nenhum rumo serve.
func _passo(delta: float, vel: float, dir: Vector3, seco: bool, tolerancia: float) -> bool:
	var passo := vel * delta
	var olhar := maxf(passo, 0.8)
	var frente := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	# preso: quer andar e não sai do lugar; tenta a volta pelo outro lado
	_trava_t += delta
	if _trava_t >= 1.2:
		if Vector2(global_position.x - _trava_p.x, global_position.z - _trava_p.z).length() < 0.4:
			_lado_desvio = -_lado_desvio
			destravou += 1
		_trava_t = 0.0
		_trava_p = global_position
	for k in 11:
		# o rumo pedido, depois todo um lado (de 30 em 30 graus) e só então o outro: contorna sem ir e voltar
		var ang := 0.0 if k == 0 else (k * 0.5236 * _lado_desvio if k <= 5 else (k - 5) * 0.5236 * -_lado_desvio)
		var d := dir.rotated(Vector3.UP, ang)
		var a := global_position + d * olhar
		if not _livre(a.x, a.z, seco):
			continue
		# tronco, pedra, ruína ou a base no caminho: tenta o rumo ao lado (dá a volta)
		if not Obstaculos.caminho_livre(mapa, global_position, global_position + d * maxf(olhar, 1.4), altura_bicho * 0.32):
			desvios += 1
			continue
		var de_frente := clampf(1.0 - frente.angle_to(d) / tolerancia, 0.0, 1.0)
		var x := global_position.x + d.x * passo * de_frente
		var z := global_position.z + d.z * passo * de_frente
		global_position = Vector3(x, mapa.altura(x, z), z)
		_rumo = d
		if k > 0:
			_lado_desvio = 1.0 if ang > 0.0 else -1.0  # segue a volta pelo lado em que começou
		return true
	return false


func _livre(x: float, z: float, seco: bool) -> bool:
	if mapa.agua(x, z) != -INF:
		return false
	return not seco or mapa.normal_em(x, z).y > 0.9


## Escolhe um ponto de pasto: 6 a 18 m adiante, seco, dentro do raio da casa e longe da ameaça.
## Com `perto_casa`, escolhe um ponto dentro de 60% do raio da casa (para voltar de um susto).
func _escolher_alvo(perto_casa: bool) -> bool:
	for k in 40:
		var ang := _rng.randf() * TAU
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var p: Vector3
		if perto_casa:
			p = casa + dir * _rng.randf_range(0.0, raio_casa * 0.6)
		else:
			p = global_position + dir * _rng.randf_range(6.0, 18.0)
		if Vector2(p.x - casa.x, p.z - casa.z).length() > raio_casa:
			continue
		if not _livre(p.x, p.z, true) or not Obstaculos.livre(mapa, p.x, p.z, altura_bicho * 0.32):
			continue
		if _tem_ameaca and Vector2(p.x - ameaca.global_position.x, p.z - ameaca.global_position.z).length() < DIST_PASSEIO_LONGE:
			continue
		_alvo = p
		return true
	return false


# ---------------------------------------------------------------- animação

func _alvo_rot(no: Node3D, dx: float, dy: float, dz: float, k: float) -> void:
	var r: Vector3 = _rot0[no]
	no.rotation = no.rotation.lerp(r + Vector3(dx, dy, dz), k)


func _animar(delta: float) -> void:
	var k := 1.0 - exp(-6.0 * delta)
	var pasto := estado == Estado.PASTANDO and _olhando <= 0.0
	var olhando := estado == Estado.PASTANDO and _olhando > 0.0

	# olhar em volta de vez em quando, enquanto pasta
	if estado == Estado.PASTANDO:
		_olhando = maxf(0.0, _olhando - delta)
		_proximo_olhar -= delta
		if _proximo_olhar <= 0.0:
			_olhando = 1.6
			_proximo_olhar = _rng.randf_range(3.0, 6.0)

	# pescoço e cabeça
	var ang_pescoco := PESCOCO_ANDAR
	if pasto:
		ang_pescoco = PESCOCO_PASTO
	elif estado == Estado.ALERTA or olhando:
		ang_pescoco = PESCOCO_ALERTA
	elif estado == Estado.FUGINDO:
		ang_pescoco = PESCOCO_FUGA
	var yaw_cabeca := 0.0
	if estado == Estado.ALERTA and _tem_ameaca:
		# a cabeça vira para a ameaça, na frame do pescoço
		var para := _pescoco.global_transform.basis.inverse() * (ameaca.global_position - _cabeca.global_position)
		yaw_cabeca = clampf(atan2(para.x, para.z), -1.2, 1.2)
	var afunda := AFUNDA_PASTO if pasto else 0.0
	_pescoco.rotation = _pescoco.rotation.lerp(Vector3(_rot0[_pescoco].x + ang_pescoco, _rot0[_pescoco].y, _rot0[_pescoco].z), k)
	var pos_pescoco: Vector3 = _pos0[_pescoco]
	_pescoco.position = _pescoco.position.lerp(pos_pescoco + Vector3(0.0, -afunda, 0.0), k)
	_alvo_rot(_cabeca, CABECA_PASTO if pasto else 0.0, yaw_cabeca, 0.0, k)

	# cauda: balança pastando e andando, sobe fugindo
	var amp_cauda := 0.05
	match estado:
		Estado.PASTANDO:
			amp_cauda = 0.5
		Estado.ANDANDO:
			amp_cauda = 0.3
		Estado.FUGINDO:
			amp_cauda = 0.15
	_alvo_rot(_cauda, -0.6 if estado == Estado.FUGINDO else 0.0, sin(_relogio * 7.0) * amp_cauda, 0.0, k)

	# pernas: passada em diagonais (pastando e alerta, param); fuga, em galope
	var alvo_amp := 0.0
	var alvo_freq := FREQ_ANDAR
	var offs: Array = DEFASE_PASSO
	if estado == Estado.ANDANDO:
		alvo_amp = PERNA_ANDAR
	elif estado == Estado.FUGINDO:
		alvo_amp = PERNA_FUGA
		alvo_freq = FREQ_FUGA
		offs = DEFASE_GALOPE
	_amp = lerpf(_amp, alvo_amp, k)
	_freq = lerpf(_freq, alvo_freq, k)
	_fase = fmod(_fase + _freq * delta, TAU)
	for i in 4:
		var perna := _pernas[i]
		var alvo: float = _rot0[perna].x + _amp * sin(_fase + offs[i])
		perna.rotation.x = lerpf(perna.rotation.x, alvo, 1.0 - exp(-14.0 * delta))

	# corpo: sobe e desce na passada; no galope, salta
	var salto := 0.25 if estado == Estado.FUGINDO else 0.1
	var corpo_rest: Vector3 = _pos0[_corpo]
	_corpo.position.y = corpo_rest.y + _amp * salto * absf(sin(_fase))

	# no plano, vira para o rumo; sobe e desce a encosta
	if estado == Estado.ANDANDO or estado == Estado.FUGINDO:
		var alvo_yaw := atan2(-_rumo.x, -_rumo.z)
		rotation.y = lerp_angle(rotation.y, alvo_yaw, 1.0 - exp(-5.0 * delta))
	var frente := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var a := global_position + frente * 1.0
	var inclina := atan(mapa.altura(a.x, a.z) - global_position.y)
	_pitch = lerpf(_pitch, inclina, k)
	rotation.x = _pitch
	rotation.z = 0.0
	if bicho:
		match estado:
			Estado.PASTANDO:
				bicho.tocar("Eating" if pasto else "Idle_2")
			Estado.ANDANDO:
				bicho.tocar("Walk", 1.1)
			Estado.FUGINDO:
				bicho.tocar("Gallop", 1.25, 0.15)
			_:
				bicho.tocar("Idle")
