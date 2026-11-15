class_name Coelho
extends Node3D
## Coelho do vale: fica sentado, às vezes de pé, come, pula pelo pasto e foge em pulos longos e
## ziguezagueando de uma ameaça (o robô, ou qualquer Node3D) ou de um susto (assustar).
## Animado por código sobre res://assets/vale/coelho.glb. O modelo olha para +Z; o nó do modelo gira 180° em Y,
## então a frente do coelho é -Z. Sem física: fica sobre o relevo (mapa.altura) e não entra na água.
## Uso: Coelho.new(), defina mapa, casa, raio_casa, semente (e ameaca, se houver), e só então add_child.

enum Estado { PARADO, COMENDO, PULANDO, FUGINDO }
const NOMES := ["parado", "comendo", "pulando", "fugindo"]
const CENA := "res://assets/vale/coelho.glb"

const DIST_FUGA := 7.0  # ameaça mais perto que isso faz fugir
const DIST_FUGA_RAPIDA := 14.0  # e, a menos disso, também faz fugir se vier a mais de VEL_RAPIDA
const VEL_RAPIDA := 6.0
const DIST_SEGURA := 28.0  # foge até ficar a mais de 28 m do ponto de fuga, e então para
const DIST_ASSUSTAR := 50.0  # um susto a menos disso faz fugir
const TEMPO_CALMO_VOLTA := 6.0  # parado e calmo por esse tempo, volta em pulinhos para perto da casa
const PULO_PASSO := 0.45  # m por pulo de passeio
const PULO_DUR := 0.32
const PULO_ALT := 0.12
const PAUSA_MIN := 0.1
const PAUSA_MAX := 0.6
const PAUSA_VOLTA_MAX := 0.25  # voltando para casa, as pausas são curtas
const FUGA_PASSO := 1.3
const FUGA_DUR := 0.22
const FUGA_ALT := 0.22
const ZIGUE := 0.436  # 25 graus
const GIRO := 0.698  # 40 graus: quanto gira a cada tentativa de um pulo
const TENTATIVAS := 8
const MIN_INCLIN := 0.75  # normal.y mínimo do chão onde o coelho pisa
const IMPULSO_PERNA := 0.8  # perna_t gira isso em X no impulso
const CABECA_COMER := 0.5  # cabeça baixa para comer (+X, como o pescoço do cervo)
const CORPO_PE := -0.7  # de pé nas patas de trás
const CAUDA_FUGA := -0.6  # a cauda branca levanta (mesmo sinal do cervo)
const ORELHA_TREMOR := 0.25

var mapa: Ilha
var ameaca: Node3D  # o robô; pode ser null
var casa := Vector3.ZERO
var raio_casa := 14.0
var semente := 0
var estado := 0  # Estado
var pose_foto := -1  # >= 0: fica nesse estado, só animando (fotos)

var _rng := RandomNumberGenerator.new()
var _pronto := false
var _relogio := 0.0
var _tempo := 0.0  # tempo no estado atual
var _duracao := 4.0  # quanto dura PARADO ou COMENDO
var _alvo := Vector3.ZERO
var _voltando := false  # indo para perto da casa (depois de fugir ou de se afastar)
var _pausa := 0.0  # tempo que falta até o próximo pulo
var _em_pulo := false
var _pulo_t := 0.0
var _pulo_dur := PULO_DUR
var _pulo_alt := PULO_ALT
var _pulo_p0 := Vector3.ZERO
var _pulo_p1 := Vector3.ZERO
var _rumo := Vector3.FORWARD
var _u := -1.0  # fase do pulo, 0 a 1; -1 fora do pulo
var _tem_ameaca := false
var _ameaca_lida := false
var _dist := INF
var _vel := 0.0
var _pos_ameaca := Vector3.ZERO
var _tempo_calmo := 6.0
var _fugindo_ameaca := false  # a fuga é da ameaça (senão, do ponto do susto)
var _origem_susto := Vector3.ZERO
var _zig := ZIGUE
var _pulos_zig := 0
var _pulos_ate_zig := 2
var _pe_ini := 0.0
var _pe_dur := 0.0  # > 0: fica de pé nesse trecho do PARADO
var _proxima_orelha := 3.0
var _orelha_t := 0.0

var _modelo: Node3D
var _corpo: Node3D
var _cabeca: Node3D
var _orelhas: Node3D
var _perna_t: Node3D
var _cauda: Node3D
var _rot0 := {}  # rotação de repouso de cada peça
var _pos0 := {}  # posição de repouso de cada peça


func _ready() -> void:
	add_to_group("bichos")
	_rng.seed = semente * 7919 + 29
	var cena := load(CENA) as PackedScene
	if cena == null:
		push_error("coelho: modelo não encontrado em %s" % CENA)
		return
	_modelo = cena.instantiate() as Node3D
	_modelo.rotation.y = PI  # o modelo olha para +Z; aqui a frente é -Z
	_modelo.scale = Vector3.ONE * 1.55  # lebre grande, as orelhas passam do capim
	add_child(_modelo)
	_corpo = _peca("corpo")
	_cabeca = _peca("cabeca")
	_orelhas = _peca("orelhas")
	_perna_t = _peca("perna_t")
	_cauda = _peca("cauda")
	if _corpo == null or _cabeca == null or _orelhas == null or _perna_t == null or _cauda == null:
		return
	for no in [_corpo, _cabeca, _orelhas, _perna_t, _cauda]:
		_rot0[no] = no.rotation
		_pos0[no] = no.position
	rotation.y = _rng.randf() * TAU
	global_position = Vector3(casa.x, mapa.altura(casa.x, casa.z), casa.z)
	_proxima_orelha = _rng.randf_range(1.5, 4.0)
	_mudar(Estado.PARADO)
	_pronto = true


func _peca(nome: String) -> Node3D:
	var no := _modelo.find_child(nome, true, false) as Node3D
	if no == null:
		push_error("coelho: peça '%s' não achada no modelo" % nome)
	return no


## Nome do estado atual, para testes e depuração.
func nome_estado() -> String:
	return NOMES[estado]


## Um susto (o robô passando perto, um tiro): a menos de 50 m do ponto, o coelho foge dele.
func assustar(ponto: Vector3) -> void:
	if not _pronto or not is_inside_tree():
		return
	if _dist_xz(global_position, ponto) >= DIST_ASSUSTAR:
		return
	_origem_susto = ponto
	_iniciar_fuga(false)


func _process(delta: float) -> void:
	if not _pronto or mapa == null:
		return
	_relogio += delta
	_tempo += delta
	if pose_foto >= 0:
		# pose de foto: fica nesse estado, só animando; pulo e fuga repetem no lugar
		estado = pose_foto
		var gp := global_position
		if estado == Estado.PULANDO or estado == Estado.FUGINDO:
			_pulo_dur = FUGA_DUR if estado == Estado.FUGINDO else PULO_DUR
			_pulo_alt = FUGA_ALT if estado == Estado.FUGINDO else PULO_ALT
			_pulo_t = fmod(_pulo_t + delta, _pulo_dur + 0.4)
			_u = _pulo_t / _pulo_dur if _pulo_t < _pulo_dur else -1.0
		else:
			_u = -1.0
		var arco := _pulo_alt * sin(PI * _u) if _u >= 0.0 else 0.0
		global_position = Vector3(gp.x, mapa.altura(gp.x, gp.z) + arco, gp.z)
		_animar(delta)
		return
	_ler_ameaca(delta)
	_decidir(delta)
	_mover(delta)
	_animar(delta)


# ---------------------------------------------------------------- percepção e decisão

func _ler_ameaca(delta: float) -> void:
	_tem_ameaca = ameaca != null and is_instance_valid(ameaca)
	if not _tem_ameaca:
		_ameaca_lida = false
		return
	var p := ameaca.global_position
	_dist = _dist_xz(global_position, p)
	var v: Variant = ameaca.get("velocity")  # o robô (CharacterBody3D) já tem velocidade
	if v is Vector3:
		_vel = (v as Vector3).length()
	elif _ameaca_lida and delta > 0.0:
		_vel = (p - _pos_ameaca).length() / delta
	_pos_ameaca = p
	_ameaca_lida = true


func _decidir(delta: float) -> void:
	if estado == Estado.FUGINDO:
		_tempo_calmo = 0.0
	else:
		_tempo_calmo += delta
	if _tem_ameaca and (_dist < DIST_FUGA or (_dist < DIST_FUGA_RAPIDA and _vel > VEL_RAPIDA)):
		_iniciar_fuga(true)
	elif _tem_ameaca and _dist < DIST_FUGA_RAPIDA:
		_tempo_calmo = 0.0


func _iniciar_fuga(da_ameaca: bool) -> void:
	_fugindo_ameaca = da_ameaca
	_tempo_calmo = 0.0
	if estado != Estado.FUGINDO:
		_mudar(Estado.FUGINDO)


func _origem() -> Vector3:
	if _fugindo_ameaca and _tem_ameaca:
		return ameaca.global_position
	return _origem_susto


func _mudar(novo: int) -> void:
	if novo == estado and _pronto:
		return
	estado = novo
	_tempo = 0.0
	_pausa = 0.0
	_pe_dur = 0.0
	match novo:
		Estado.PARADO:
			_voltando = false
			_duracao = _rng.randf_range(3.0, 6.0)
			if _rng.randf() < 0.35:  # às vezes, de pé nas patas de trás
				_pe_dur = _rng.randf_range(1.0, 2.0)
				_pe_ini = _rng.randf_range(0.5, _duracao - _pe_dur - 0.3)
		Estado.COMENDO:
			_duracao = _rng.randf_range(3.0, 6.0)
		Estado.FUGINDO:
			_pulos_zig = 0
			_pulos_ate_zig = _rng.randi_range(2, 3)


func _dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


func _longe_de_casa() -> bool:
	return _dist_xz(global_position, casa) > raio_casa * 0.5


# ---------------------------------------------------------------- movimento em pulos

func _mover(delta: float) -> void:
	if _em_pulo:
		_pulo_t += delta
		var u := _pulo_t / _pulo_dur
		if u >= 1.0:
			_em_pulo = false
			_u = -1.0
			global_position = Vector3(_pulo_p1.x, mapa.altura(_pulo_p1.x, _pulo_p1.z), _pulo_p1.z)
			_ao_pousar()
		else:
			_u = u
			var p := _pulo_p0.lerp(_pulo_p1, u)
			global_position = Vector3(p.x, mapa.altura(p.x, p.z) + _pulo_alt * sin(PI * u), p.z)
	else:
		_comportamento(delta)
		var gp := global_position
		global_position = Vector3(gp.x, mapa.altura(gp.x, gp.z), gp.z)
	# o corpo aponta para a direção do pulo, virando suave; sem inclinar no declive
	if estado == Estado.PULANDO or estado == Estado.FUGINDO or _em_pulo:
		var alvo_yaw := atan2(-_rumo.x, -_rumo.z)
		rotation.y = lerp_angle(rotation.y, alvo_yaw, 1.0 - exp(-10.0 * delta))
	rotation.x = 0.0
	rotation.z = 0.0


func _comportamento(delta: float) -> void:
	match estado:
		Estado.PARADO:
			if _tempo < _duracao:
				return
			if _longe_de_casa():
				if _tempo_calmo >= TEMPO_CALMO_VOLTA:
					_ir_para(true)
			elif _rng.randf() < 0.4:
				_mudar(Estado.COMENDO)
			else:
				_ir_para(false)
		Estado.COMENDO:
			if _tempo >= _duracao:
				_mudar(Estado.PARADO)
		Estado.PULANDO:
			var gp := global_position
			var para := Vector3(_alvo.x - gp.x, 0.0, _alvo.z - gp.z)
			if para.length() < 0.3:
				_mudar(Estado.PARADO)
				return
			_pausa -= delta
			if _pausa > 0.0:
				return
			if not _pular(para.normalized(), minf(PULO_PASSO, para.length()), PULO_DUR, PULO_ALT):
				_mudar(Estado.PARADO)  # sem chão livre até o alvo: para e espera
		Estado.FUGINDO:
			var origem := _origem()
			if _dist_xz(global_position, origem) > DIST_SEGURA:
				_mudar(Estado.PARADO)
				return
			_pausa -= delta
			if _pausa > 0.0:
				return
			var gp := global_position
			var fuga := Vector3(gp.x - origem.x, 0.0, gp.z - origem.z)
			if fuga.length() < 0.01:
				fuga = Vector3.RIGHT
			_pulos_zig += 1
			if _pulos_zig >= _pulos_ate_zig:  # ziguezague: vira 25 graus para o outro lado
				_zig = -_zig
				_pulos_zig = 0
				_pulos_ate_zig = _rng.randi_range(2, 3)
			if not _pular(fuga.normalized().rotated(Vector3.UP, _zig), FUGA_PASSO, FUGA_DUR, FUGA_ALT):
				_pausa = 0.05  # sem rumo livre agora: tenta de novo logo


func _ao_pousar() -> void:
	if estado == Estado.PULANDO:
		_pausa = _rng.randf_range(PAUSA_MIN, PAUSA_VOLTA_MAX if _voltando else PAUSA_MAX)
	else:
		_pausa = 0.0


## Começa um pulo de `comp` metros no rumo `dir`, de `dur` segundos e `alt` de altura no arco.
## Confere o ponto de chegada e o caminho; se não servir, gira 40 graus e tenta de novo (até 8 vezes).
## Devolve false se nenhum rumo serve.
func _pular(dir: Vector3, comp: float, dur: float, alt: float) -> bool:
	var de := Vector3(global_position.x, 0.0, global_position.z)
	var sentido := 1.0 if _rng.randf() < 0.5 else -1.0
	var base := dir.normalized()
	for k in TENTATIVAS:
		var d := base.rotated(Vector3.UP, sentido * GIRO * k)
		var ate := de + d * comp
		if _caminho_livre(de, ate):
			_pulo_p0 = de
			_pulo_p1 = ate
			_rumo = d
			_pulo_t = 0.0
			_pulo_dur = dur
			_pulo_alt = alt
			_em_pulo = true
			return true
	return false


func _caminho_livre(a: Vector3, b: Vector3) -> bool:
	for t in [0.25, 0.5, 0.75, 1.0]:
		var p := a.lerp(b, t)
		if not _livre(p.x, p.z):
			return false
	return true


func _livre(x: float, z: float) -> bool:
	if mapa.agua(x, z) > -INF:
		return false
	return mapa.normal_em(x, z).y >= MIN_INCLIN


## Escolhe o alvo do passeio: 2 a 6 m adiante, ou (voltando) um ponto perto da casa. Sempre dentro do raio.
func _escolher_alvo(voltando: bool) -> bool:
	var gp := global_position
	for k in 30:
		var ang := _rng.randf() * TAU
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var p: Vector3
		if voltando:
			p = casa + dir * _rng.randf_range(0.0, raio_casa * 0.6)
		else:
			p = gp + dir * _rng.randf_range(2.0, 6.0)
		if _dist_xz(p, casa) > raio_casa * 0.9:
			continue
		if not _livre(p.x, p.z):
			continue
		_alvo = p
		return true
	return false


func _ir_para(voltando: bool) -> void:
	if _escolher_alvo(voltando):
		_voltando = voltando
		_mudar(Estado.PULANDO)
	else:
		_tempo = 0.0  # tenta de novo depois


# ---------------------------------------------------------------- animação

func _em_pe() -> bool:
	return estado == Estado.PARADO and _pe_dur > 0.0 and _tempo >= _pe_ini and _tempo < _pe_ini + _pe_dur


func _animar(delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)

	# orelhas: mexem de vez em quando
	_proxima_orelha -= delta
	if _proxima_orelha <= 0.0:
		_orelha_t = 0.3
		_proxima_orelha = _rng.randf_range(1.5, 4.0)
	_orelha_t = maxf(0.0, _orelha_t - delta)
	var r_orelhas: Vector3 = _rot0[_orelhas]
	_orelhas.rotation = _orelhas.rotation.lerp(r_orelhas + Vector3(ORELHA_TREMOR if _orelha_t > 0.0 else 0.0, 0.0, 0.0), k)

	# cabeça: baixa para comer (mastigando), olha em volta quando de pé
	var pe := _em_pe()
	var cab := Vector3.ZERO
	if estado == Estado.COMENDO:
		cab.x = CABECA_COMER + sin(_relogio * 9.0) * 0.06
	if pe:
		cab.y = sin(_relogio * 1.6) * 0.5
	var r_cabeca: Vector3 = _rot0[_cabeca]
	_cabeca.rotation = _cabeca.rotation.lerp(r_cabeca + cab, k)

	# corpo: de pé nas patas de trás
	var r_corpo: Vector3 = _rot0[_corpo]
	_corpo.rotation = _corpo.rotation.lerp(r_corpo + Vector3(CORPO_PE if pe else 0.0, 0.0, 0.0), k)

	# cauda: levanta fugindo
	var r_cauda: Vector3 = _rot0[_cauda]
	_cauda.rotation = _cauda.rotation.lerp(r_cauda + Vector3(CAUDA_FUGA if estado == Estado.FUGINDO else 0.0, 0.0, 0.0), k)

	# patas de trás: esticam para trás no impulso e voltam (na primeira metade do pulo)
	var r_perna: Vector3 = _rot0[_perna_t]
	var ext := 0.0
	if _u >= 0.0 and _u < 0.6:
		ext = IMPULSO_PERNA * sin(PI * _u / 0.6)
	_perna_t.rotation = Vector3(r_perna.x + ext, r_perna.y, r_perna.z)
