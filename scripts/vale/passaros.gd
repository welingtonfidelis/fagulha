class_name Passaros
extends Node3D
## Um bando de pássaros pequenos (res://assets/vale/passaro.glb, ~0,3 m) sobre o relevo do vale.
## Estados do bando: NO_CHAO (ciscam, dão pulinhos e bicam o chão), VOANDO (levantam voo quase juntos,
## sobem a ~35 graus, dão uma ou duas voltas largas a 12–20 m e seguem para o pouso), POUSANDO (planam
## até um ponto novo e fecham as asas ao tocar o chão). Só visual: sem física nem colisão.
## Uso: Passaros.new(), defina mapa, casa, ameaca (opcional), quantos, semente e, se quiser, pintar;
## só então add_child. O nó do modelo gira 180° em Y, então a frente do pássaro é -Z (como o cervo).

enum Estado { NO_CHAO, VOANDO, POUSANDO }
const NOMES := ["no_chao", "voando", "pousando"]
const CENA := "res://assets/vale/passaro.glb"

const VEL := 9.0  # m/s no voo
const VH_SUBIDA := 7.4  # 9 m/s a 35 graus: parte horizontal da subida
const VY_SUBIDA := 5.2  # parte vertical da subida (35 graus)
const ALT_MIN := 12.0  # altitude sobre o relevo durante as voltas
const ALT_MAX := 20.0
const ATRASO_MAX := 0.4  # cada pássaro decola até esse tempo depois do primeiro
const RAIO_ORBITA_MIN := 14.0
const RAIO_ORBITA_MAX := 18.0
const DIST_VOO := 9.0  # ameaça mais perto que isso faz o bando voar
const DIST_VOO_RAPIDA := 16.0  # ... e mais perto que isso, se estiver rápida
const VEL_RAPIDA := 8.0
const DIST_ASSUSTAR := 70.0
const POUSO_MIN := 25.0
const POUSO_MAX := 60.0
const DIST_AMEACA_POUSO := 25.0
const RAIO_CASA := 110.0
const TENTATIVAS_POUSO := 12
const FREQ_BATER := 9.0  # Hz
const AMP_BATER := 0.9  # rad
const DOBRA := 1.35  # rad: quanto a asa fecha junto do corpo
# Sinais da dobra e da bateria, sobre o repouso (asa aberta).
const SINAL_DOBRA_E := 1.0  # no modelo, a ponta de asaE vai para trás com +1,35 rad (confirmado no teste de geometria)
const SINAL_DOBRA_D := -1.0
const SINAL_BATER_E := 1.0
const SINAL_BATER_D := -1.0
const PULO_DUR := 0.4
const PULO_ALT := 0.12  # altura do pulinho: pequena, o pássaro quase não sai do chão
const INCLINA_BICAR := -0.5  # corpo inclinado para a frente ao bicar (negativo = focinho para baixo)

var mapa: Ilha
var ameaca: Node3D  # o robô; pode ser null
var casa := Vector3.ZERO  # centro do bando
var quantos := 6
var semente := 0
var pintar: Callable  # opcional: pintar.call(modelo) em cada pássaro instanciado
var estado := Estado.NO_CHAO
var decolagens := 0  # quantas vezes o bando levantou voo (para testes)

var _rng := RandomNumberGenerator.new()
var _pronto := false
var _cena: PackedScene
var _aves: Array[Ave] = []
var _vel_ameaca := 0.0
var _pos_ameaca := Vector3.ZERO
var _ameaca_lida := false
var _t_voo := 0.0  # tempo desde a decolagem do bando
var _t_orbita := 0.0  # quanto tempo o bando dá voltas antes de pousar
var _aproximando := false  # o bando já escolheu o ponto de pouso


class Ave:
	var raiz: Node3D
	var corpo: Node3D
	var asa_e: Node3D
	var asa_d: Node3D
	var rot_corpo := Vector3.ZERO  # repouso das peças
	var rot_e := Vector3.ZERO
	var rot_d := Vector3.ZERO
	var pos := Vector3.ZERO  # no mundo: y é o chão ou a altitude
	var yaw := 0.0
	var yaw_alvo := 0.0  # para onde vira no chão
	var pitch := 0.0
	var roll := 0.0
	var vh := 0.0  # velocidade horizontal
	var vy := 0.0  # velocidade vertical
	var giro := 0.0  # taxa de guinada atual (rad/s; negativa = vira à direita)
	var voo := false
	var atraso := 0.0  # segundos até decolar
	var sentido := 1.0  # +1 gira para a direita, -1 para a esquerda
	var raio := 16.0  # distância até o centro da volta
	var alt := 15.0  # altitude sobre o relevo durante a volta
	var alvo := Vector3.ZERO  # ponto de pouso
	var t_aprox := 0.0
	var dobra := 1.0  # 1 = asas fechadas junto do corpo, 0 = abertas
	var amp := 0.0
	var fase := 0.0
	var prox := 1.0  # segundos até a próxima ação no chão
	var pulo := 0.0  # tempo restante do pulinho
	var pulo_de := Vector3.ZERO
	var pulo_para := Vector3.ZERO
	var bicar := 0.0  # tempo restante de bicada
	var inclina := 0.0  # inclinação atual do corpo
	var cabeca := 0.0  # giro atual do corpo para olhar em volta
	var cabeca_alvo := 0.0


func _ready() -> void:
	if mapa == null:
		push_error("passaros: falta o mapa")
		return
	add_to_group("bichos")
	_rng.seed = semente * 7919 + 31
	_cena = load(CENA) as PackedScene
	if _cena == null:
		push_error("passaros: modelo não encontrado em %s" % CENA)
		return
	for i in quantos:
		var a := _novo_passaro()
		if a != null:
			_aves.append(a)
	_pronto = not _aves.is_empty()


func _novo_passaro() -> Ave:
	var modelo := _cena.instantiate() as Node3D
	modelo.rotation.y = PI  # o modelo olha para +Z; aqui a frente é -Z
	modelo.scale = Vector3.ONE * 1.7  # maior que o real, para aparecer no capim
	var a := Ave.new()
	a.raiz = Node3D.new()
	add_child(a.raiz)
	a.raiz.add_child(modelo)
	a.corpo = modelo.find_child("corpo", true, false) as Node3D
	a.asa_e = modelo.find_child("asaE", true, false) as Node3D
	a.asa_d = modelo.find_child("asaD", true, false) as Node3D
	if a.corpo == null or a.asa_e == null or a.asa_d == null:
		push_error("passaros: peças 'corpo', 'asaE' ou 'asaD' não achadas no modelo")
		a.raiz.queue_free()
		return null
	if pintar.is_valid():
		pintar.call(modelo)
	a.rot_corpo = a.corpo.rotation
	a.rot_e = a.asa_e.rotation
	a.rot_d = a.asa_d.rotation
	a.pos = _ponto_chao(casa, 6.0)
	a.yaw = _rng.randf() * TAU
	a.yaw_alvo = a.yaw
	a.prox = _rng.randf_range(0.5, 2.5)
	return a


# ---------------------------------------------------------------- API

## Nome do estado atual, para testes e depuração.
func nome_estado() -> String:
	return NOMES[estado]


## Posição global de cada pássaro, para testes.
func posicoes() -> Array[Vector3]:
	var r: Array[Vector3] = []
	for a in _aves:
		r.append(a.raiz.global_position)
	return r


## Um susto (um tiro, o robô passando): a menos de 70 m do bando, ele levanta voo.
## Só age com o bando no chão.
func assustar(ponto: Vector3) -> void:
	if not _pronto or not is_inside_tree() or estado != Estado.NO_CHAO:
		return
	var c := _centro()
	if Vector2(ponto.x - c.x, ponto.z - c.z).length() < DIST_ASSUSTAR:
		_decolar()


## O bando chega voando de longe e pousa em volta de `ponto` (os pássaros da Árvore-Mãe).
func chegar_em(ponto: Vector3, espalha := 3.0) -> void:
	if not _pronto:
		return
	estado = Estado.POUSANDO
	_aproximando = true
	for a in _aves:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(30.0, 46.0)
		a.pos = ponto + Vector3(cos(ang) * dist, _rng.randf_range(9.0, 15.0), sin(ang) * dist)
		a.voo = true
		a.atraso = 0.0
		a.alt = 12.0
		a.vh = VEL
		a.vy = 0.0
		a.yaw = atan2(cos(ang), sin(ang))  # de frente para o ponto
		var ang2 := _rng.randf() * TAU
		var d := _rng.randf_range(1.5, espalha)
		var x := ponto.x + cos(ang2) * d
		var z := ponto.z + sin(ang2) * d
		a.alvo = Vector3(x, mapa.altura(x, z), z)
		a.t_aprox = 0.0


# ---------------------------------------------------------------- processo

func _process(delta: float) -> void:
	if not _pronto:
		return
	_ler_ameaca(delta)
	match estado:
		Estado.NO_CHAO:
			_checar_ameaca()
		Estado.VOANDO:
			_t_voo += delta
			if not _aproximando and _t_voo >= _t_orbita:
				_iniciar_pouso()
	for a in _aves:
		if a.voo:
			_voar(a, delta)
		elif a.atraso > 0.0:
			a.atraso -= delta
			a.pos.y = mapa.altura(a.pos.x, a.pos.z)
			if a.atraso <= 0.0:
				a.voo = true
		else:
			_chao(a, delta)
		_animar(a, delta)
	if estado == Estado.POUSANDO and _todos_no_chao():
		estado = Estado.NO_CHAO
		_aproximando = false


func _ler_ameaca(delta: float) -> void:
	_vel_ameaca = 0.0
	if not is_instance_valid(ameaca):
		_ameaca_lida = false
		return
	var p := ameaca.global_position
	var v: Variant = ameaca.get("velocity")  # o robô (CharacterBody3D) já tem velocidade
	if v is Vector3:
		_vel_ameaca = (v as Vector3).length()
	elif _ameaca_lida and delta > 0.0:
		_vel_ameaca = (p - _pos_ameaca).length() / delta
	_pos_ameaca = p
	_ameaca_lida = true


func _checar_ameaca() -> void:
	if not is_instance_valid(ameaca):
		return
	var c := _centro()
	var p := ameaca.global_position
	var d := Vector2(p.x - c.x, p.z - c.z).length()
	if d < DIST_VOO or (d < DIST_VOO_RAPIDA and _vel_ameaca > VEL_RAPIDA):
		_decolar()


func _centro() -> Vector3:
	if _aves.is_empty():
		return casa
	var s := Vector3.ZERO
	for a in _aves:
		s += a.pos
	s /= _aves.size()
	return Vector3(s.x, 0.0, s.z)


func _todos_no_chao() -> bool:
	for a in _aves:
		if a.voo or a.atraso > 0.0:
			return false
	return true


# ---------------------------------------------------------------- decolagem, volta e pouso

func _decolar() -> void:
	estado = Estado.VOANDO
	decolagens += 1
	_t_voo = 0.0
	_aproximando = false
	var c := _centro()
	var raio := _rng.randf_range(RAIO_ORBITA_MIN, RAIO_ORBITA_MAX)
	var sentido := 1.0 if _rng.randf() < 0.5 else -1.0
	var h0 := _rng.randf() * TAU
	var frente := Vector3(-sin(h0), 0.0, -cos(h0))
	var direita := frente.cross(Vector3.UP)
	var orbita := Vector3(c.x, 0.0, c.z) + direita * raio * sentido  # o bando dá voltas em torno disso
	var voltas := 1 if _rng.randf() < 0.6 else 2
	_t_orbita = voltas * TAU * raio / VEL
	for a in _aves:
		a.voo = false
		a.atraso = _rng.randf_range(0.0, ATRASO_MAX) + 0.01
		a.sentido = sentido
		a.alt = _rng.randf_range(ALT_MIN, ALT_MAX)
		var dx := a.pos.x - orbita.x
		var dz := a.pos.z - orbita.z
		a.raio = maxf(Vector2(dx, dz).length(), 3.0)
		var th := atan2(dz, dx)
		var m := Vector2(-sin(th), cos(th)) * sentido  # direção do movimento na volta (x, z)
		a.yaw = atan2(-m.x, -m.y)
		a.vh = VH_SUBIDA
		a.vy = 0.0
		a.giro = 0.0


func _iniciar_pouso() -> void:
	_aproximando = true
	estado = Estado.POUSANDO
	var ponto := _escolher_pouso()
	for a in _aves:
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(0.0, 3.0)
		var x := ponto.x + cos(ang) * d
		var z := ponto.z + sin(ang) * d
		if not _seco(x, z):
			x = ponto.x
			z = ponto.z
		a.alvo = Vector3(x, mapa.altura(x, z), z)
		a.t_aprox = 0.0


## Ponto novo de pouso: 25 a 60 m do bando, longe da ameaça, dentro do raio da casa, em chão seco.
func _escolher_pouso() -> Vector3:
	var c := _centro()
	for k in TENTATIVAS_POUSO:
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(POUSO_MIN, POUSO_MAX)
		var x := c.x + cos(ang) * d
		var z := c.z + sin(ang) * d
		if Vector2(x - casa.x, z - casa.z).length() > RAIO_CASA:
			continue
		if is_instance_valid(ameaca) and Vector2(x - ameaca.global_position.x, z - ameaca.global_position.z).length() <= DIST_AMEACA_POUSO:
			continue
		if not _seco(x, z):
			continue
		return Vector3(x, mapa.altura(x, z), z)
	return Vector3(casa.x, mapa.altura(casa.x, casa.z), casa.z)


func _voar(a: Ave, delta: float) -> void:
	var g := mapa.altura(a.pos.x, a.pos.z)
	if _aproximando:
		var gc := mapa.altura(a.alvo.x, a.alvo.z)
		var d := Vector2(a.alvo.x - a.pos.x, a.alvo.z - a.pos.z)
		var dist := d.length()
		a.t_aprox += delta
		if (dist < 1.5 and a.pos.y - gc < 0.06) or a.t_aprox > 14.0:
			_pousar(a, gc)
			return
		# vira para o alvo, com a curva limitada (mais rápida perto do chão)
		var yaw_d := atan2(-d.x, -d.y)
		var err := wrapf(yaw_d - a.yaw, -PI, PI)
		var wmax := 1.3 if dist > 4.0 else 3.0
		a.giro = clampf(err * 2.0, -wmax, wmax)
		a.yaw += a.giro * delta
		a.vh = clampf(dist * 0.6, 2.5, VEL)
		var alvo_y := gc + (minf(dist * 0.3, a.alt) if dist > 1.5 else 0.0)  # planeio que desce
		a.vy = clampf((alvo_y - a.pos.y) * 2.0, -4.0, 4.0)
	else:
		# volta: velocidade constante no círculo em torno da órbita
		a.vh = move_toward(a.vh, VEL, 3.0 * delta)
		a.giro = -a.sentido * a.vh / a.raio
		a.yaw += a.giro * delta
		a.vy = clampf((g + a.alt - a.pos.y) * 1.2, -VY_SUBIDA, VY_SUBIDA)
	a.pos.x += -sin(a.yaw) * a.vh * delta
	a.pos.z += -cos(a.yaw) * a.vh * delta
	a.pos.y += a.vy * delta
	a.pos.y = maxf(a.pos.y, mapa.altura(a.pos.x, a.pos.z))


func _pousar(a: Ave, gc: float) -> void:
	a.voo = false
	a.pos = Vector3(a.alvo.x, gc, a.alvo.z)
	a.vh = 0.0
	a.vy = 0.0
	a.giro = 0.0
	a.pulo = 0.0
	a.prox = _rng.randf_range(0.5, 2.0)
	a.yaw_alvo = a.yaw


# ---------------------------------------------------------------- chão

func _chao(a: Ave, delta: float) -> void:
	a.bicar = maxf(a.bicar - delta, 0.0)
	if a.pulo > 0.0:
		a.pulo = maxf(a.pulo - delta, 0.0)
		var t := 1.0 - a.pulo / PULO_DUR
		var p := a.pulo_de.lerp(a.pulo_para, t)
		var gp := mapa.altura(p.x, p.z)
		a.pos = Vector3(p.x, gp + sin(PI * t) * PULO_ALT, p.z)
	else:
		a.pos.y = mapa.altura(a.pos.x, a.pos.z)
		a.prox -= delta
		if a.prox <= 0.0:
			_decidir_chao(a)
	a.yaw = lerp_angle(a.yaw, a.yaw_alvo, 1.0 - exp(-4.0 * delta))


func _decidir_chao(a: Ave) -> void:
	var r := _rng.randf()
	if r < 0.45 and _tentar_pulo(a):
		a.prox = _rng.randf_range(0.6, 1.6)
		return
	if r < 0.8:
		a.bicar = 0.9
		a.prox = _rng.randf_range(1.2, 2.5)
	else:
		a.cabeca_alvo = _rng.randf_range(-0.5, 0.5)
		a.yaw_alvo = a.yaw + _rng.randf_range(-0.9, 0.9)
		a.prox = _rng.randf_range(1.0, 2.5)


func _tentar_pulo(a: Ave) -> bool:
	var ang := _rng.randf() * TAU
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	if Vector2(a.pos.x - casa.x, a.pos.z - casa.z).length() > 8.0:
		dir = Vector3(casa.x - a.pos.x, 0.0, casa.z - a.pos.z).normalized()
	var passo := _rng.randf_range(0.3, 0.8)
	var x := a.pos.x + dir.x * passo
	var z := a.pos.z + dir.z * passo
	if not _seco(x, z):
		return false
	a.pulo = PULO_DUR
	a.pulo_de = Vector3(a.pos.x, 0.0, a.pos.z)
	a.pulo_para = Vector3(x, 0.0, z)
	a.yaw_alvo = atan2(-dir.x, -dir.z)
	return true


func _seco(x: float, z: float) -> bool:
	return mapa.agua(x, z) == -INF and mapa.normal_em(x, z).y > 0.9


func _ponto_chao(centro: Vector3, raio: float) -> Vector3:
	for k in 10:
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(0.0, raio)
		var x := centro.x + cos(ang) * d
		var z := centro.z + sin(ang) * d
		if _seco(x, z):
			return Vector3(x, mapa.altura(x, z), z)
	return Vector3(centro.x, mapa.altura(centro.x, centro.z), centro.z)


# ---------------------------------------------------------------- animação

func _animar(a: Ave, delta: float) -> void:
	var k := 1.0 - exp(-10.0 * delta)
	var plana := false
	if a.voo and _aproximando:
		plana = a.pos.y - mapa.altura(a.alvo.x, a.alvo.z) < 2.5  # no último trecho, planando
	var bate := a.voo and not plana
	if bate:
		a.fase = fmod(a.fase + TAU * FREQ_BATER * delta, TAU)
	a.amp = lerpf(a.amp, AMP_BATER if bate else 0.0, k)
	a.dobra = lerpf(a.dobra, 0.0 if a.voo else 1.0, k)
	var dobra := a.dobra * DOBRA
	var bater := a.amp * sin(a.fase)
	a.asa_e.rotation = a.rot_e + Vector3(0.0, SINAL_DOBRA_E * dobra, SINAL_BATER_E * bater)
	a.asa_d.rotation = a.rot_d + Vector3(0.0, SINAL_DOBRA_D * dobra, SINAL_BATER_D * bater)

	# cabeça e bico: bicada inclina o corpo; no chão, o pássaro olha em volta
	a.inclina = lerpf(a.inclina, INCLINA_BICAR if (a.bicar > 0.0 and not a.voo) else 0.0, k)
	a.cabeca = lerpf(a.cabeca, 0.0 if a.voo else a.cabeca_alvo, k)
	a.corpo.rotation = a.rot_corpo + Vector3(a.inclina, a.cabeca, 0.0)

	# corpo no ar: aponta para onde vai, sobe/desce e inclina nas curvas
	var pitch_alvo := clampf(atan2(a.vy, a.vh), -0.5, 0.5) if a.voo else 0.0
	var roll_alvo := clampf(a.giro * a.vh * 0.1, -0.5, 0.5) if a.voo else 0.0
	a.pitch = lerpf(a.pitch, pitch_alvo, k)
	a.roll = lerpf(a.roll, roll_alvo, k)
	a.raiz.global_transform = Transform3D(Basis.from_euler(Vector3(a.pitch, a.yaw, a.roll)), a.pos)
