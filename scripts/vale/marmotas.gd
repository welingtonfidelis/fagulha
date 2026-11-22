class_name Marmotas
extends Node3D
## Uma colônia de marmotas na campina alpina da Montanha do Degelo (terra nova, 2026-11-22, doc §137.14): tocas em
## volta de uma pedra grande. Pastam perto das tocas; uma sobe na pedra e fica de vigia, sentada em pé. Com o robô
## chegando, a vigia dá o alarme e todas ficam em pé, olhando para ele; perto demais, correm cada uma para a sua toca
## e somem. Depois de um tempo põem a cabeça para fora e, com o robô longe, saem para pastar de novo. Feitas por
## código, em formas simples; só visual, sem física.
## Uso: Marmotas.new(), defina mapa, ameaca, casa, quantos, semente e materiais (a Clareira); depois add_child.
## A frente da marmota é -Z.

enum Estado { PASTA, VIGIA, ALERTA, FOGE, TOCA, ESPIA }

const DIST_ALERTA := 40.0
const DIST_FOGE := 20.0
const DIST_VOLTA := 32.0  # o robô mais longe que isso deixa a colônia sair da toca
const VEL_ANDA := 0.35
const VEL_FOGE := 3.8
const ESCALA := 1.3  # maior que a de verdade, para aparecer no capim
const EM_PE := 1.25  # rad: o corpo erguido, sentada nas patas de trás
const PEDRA := "res://assets/vale/pedra_a.glb"
const PEDRA_LARGURA := 2.0

var mapa: Vale
var ameaca: Node3D
var casa := Vector3.ZERO
var quantos := 3
var semente := 0
var materiais: Clareira
var fugas := 0  # testes
var alarmes := 0  # testes

var _rng := RandomNumberGenerator.new()
var _marmotas: Array[Marmota] = []
var _tocas: Array[Vector3] = []
var _topo := Vector3.ZERO  # onde a vigia senta, em cima da pedra
var _t_alarme := 0.0


class Marmota:
	var raiz: Node3D
	var corpo: Node3D
	var cabeca: Node3D
	var cauda: Node3D
	var pernas: Array[Node3D] = []
	var toca := Vector3.ZERO
	var pos := Vector3.ZERO
	var alvo := Vector3.ZERO
	var yaw := 0.0
	var estado := Estado.PASTA
	var t := 0.0
	var fase := 0.0
	var erguido := 0.0  # 0 de quatro, 1 em pé
	var come := 0.0  # bicando o capim (a cabeça baixa)
	var olhar := 0.0
	var fundo := 0.0  # quanto está dentro da toca
	var vigia := false


func _ready() -> void:
	if mapa == null or materiais == null:
		push_error("marmotas: falta o mapa ou os materiais")
		return
	add_to_group("bichos")
	_rng.seed = semente * 6151 + 23
	_pedra()
	var n_tocas := clampi(quantos - 1, 2, 4)
	for i in n_tocas:
		var ang := TAU * i / n_tocas + _rng.randf_range(-0.4, 0.4)
		var p := _ponto(casa + Vector3(cos(ang), 0, sin(ang)) * _rng.randf_range(4.0, 7.5), 1.5)
		_tocas.append(p)
		_toca(p, ang)
	for i in quantos:
		var m := _nova()
		m.toca = _tocas[i % _tocas.size()]
		m.vigia = i == 0
		if m.vigia:
			m.estado = Estado.VIGIA
			m.pos = _topo
		else:
			m.pos = _ponto(m.toca, 3.0)
		m.alvo = m.pos
		m.yaw = _rng.randf() * TAU
		m.t = _rng.randf_range(0.5, 3.0)
		_marmotas.append(m)


# ---------------------------------------------------------------- formas

func _peca(pai: Node3D, mat: String, pos: Vector3, esc: Vector3, rot := Vector3.ZERO, lados := 12) -> MeshInstance3D:
	var esfera := SphereMesh.new()
	esfera.radius = 0.5
	esfera.height = 1.0
	esfera.radial_segments = lados
	esfera.rings = maxi(lados / 2, 3)
	var mi := MeshInstance3D.new()
	mi.mesh = esfera
	mi.material_override = materiais.material(mat)
	mi.position = pos
	mi.rotation = rot
	mi.scale = esc
	pai.add_child(mi)
	return mi


## A pedra da vigia: a pedra do vale, girada ao acaso, meio enterrada.
func _pedra() -> void:
	var cena := load(PEDRA) as PackedScene
	var y := mapa.altura(casa.x, casa.z)
	_topo = Vector3(casa.x, y + 0.9, casa.z)
	if cena == null:
		return
	var p := cena.instantiate() as Node3D
	add_child(p)
	var caixa := AABB()
	var primeiro := true
	for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m:
				mi.set_surface_override_material(s, materiais.material("rocha_mar"))  # sem musgo: no alto não tem
		var c := mi.transform * mi.mesh.get_aabb()
		caixa = c if primeiro else caixa.merge(c)
		primeiro = false
	var esc := PEDRA_LARGURA / maxf(maxf(caixa.size.x, caixa.size.z), 0.1)
	var alto := esc * 1.15
	p.scale = Vector3(esc, alto, esc)
	p.rotation.y = _rng.randf() * TAU
	# a base afunda até o ponto mais baixo do chão embaixo dela (na encosta, nada fica no ar)
	var baixo := y
	for k in 6:
		var a := TAU * k / 6.0
		baixo = minf(baixo, mapa.altura(casa.x + cos(a) * PEDRA_LARGURA * 0.5, casa.z + sin(a) * PEDRA_LARGURA * 0.5))
	p.position = Vector3(casa.x, baixo - caixa.position.y * alto - 0.15, casa.z)
	_topo = Vector3(casa.x, p.position.y + caixa.end.y * alto - 0.08, casa.z)


## Uma toca: o monte de terra cavada e o buraco escuro na frente dele, deitados no chão.
func _toca(p: Vector3, ang: float) -> void:
	var no := Node3D.new()
	add_child(no)
	var n := mapa.normal_em(p.x, p.z)
	var frente := Vector3(cos(ang), 0, sin(ang))  # a boca olha para fora da colônia
	frente = (frente - n * frente.dot(n)).normalized()
	no.transform = Transform3D(Basis.looking_at(frente, n), p)
	_peca(no, "terra_toca", Vector3(0, -0.1, 0.3), Vector3(1.2, 0.36, 1.0), Vector3.ZERO, 9)
	_peca(no, "terra_toca", Vector3(0.35, -0.08, 0.6), Vector3(0.55, 0.22, 0.5), Vector3.ZERO, 7)
	_peca(no, "toca", Vector3(0, 0.0, -0.2), Vector3(0.6, 0.1, 0.48), Vector3(0.3, 0, 0), 10)


func _nova() -> Marmota:
	var m := Marmota.new()
	m.raiz = BichoFicha.nova("marmota", self, 0.3)
	add_child(m.raiz)
	var corpo_esc := Node3D.new()
	corpo_esc.scale = Vector3.ONE * ESCALA
	m.raiz.add_child(corpo_esc)
	# o corpo gira em volta do quadril (para sentar em pé)
	m.corpo = Node3D.new()
	m.corpo.position = Vector3(0, 0.15, 0.05)
	corpo_esc.add_child(m.corpo)
	_peca(m.corpo, "marmota", Vector3(0, 0.06, -0.2), Vector3(0.3, 0.29, 0.5))
	_peca(m.corpo, "marmota_clara", Vector3(0, -0.02, -0.22), Vector3(0.23, 0.15, 0.4))
	_peca(m.corpo, "marmota", Vector3(0, 0.07, -0.02), Vector3(0.32, 0.31, 0.3))  # o lombo arqueado
	m.cauda = Node3D.new()
	m.cauda.position = Vector3(0, 0.08, 0.12)
	m.corpo.add_child(m.cauda)
	_peca(m.cauda, "marmota_escura", Vector3(0, -0.04, 0.1), Vector3(0.085, 0.085, 0.22), Vector3(0.45, 0, 0), 8)
	# a cabeça: topo escuro, focinho claro, orelhinhas redondas
	m.cabeca = Node3D.new()
	m.cabeca.position = Vector3(0, 0.12, -0.43)
	m.corpo.add_child(m.cabeca)
	_peca(m.cabeca, "marmota", Vector3(0, 0.02, -0.06), Vector3(0.22, 0.19, 0.22))
	_peca(m.cabeca, "marmota_escura", Vector3(0, 0.075, -0.06), Vector3(0.19, 0.09, 0.19), Vector3.ZERO, 10)
	_peca(m.cabeca, "marmota_clara", Vector3(0, -0.01, -0.155), Vector3(0.12, 0.1, 0.1), Vector3.ZERO, 10)
	_peca(m.cabeca, "junta", Vector3(0, 0.01, -0.205), Vector3(0.04, 0.03, 0.03), Vector3.ZERO, 8)
	for s: float in [-1.0, 1.0]:
		_peca(m.cabeca, "junta", Vector3(s * 0.08, 0.05, -0.12), Vector3.ONE * 0.034, Vector3.ZERO, 8)
		_peca(m.cabeca, "marmota_escura", Vector3(s * 0.085, 0.1, -0.01), Vector3(0.06, 0.055, 0.03), Vector3.ZERO, 8)
	# as patas: as da frente vão junto com o peito; as de trás ficam no chão quando ela senta
	for d: Array in [[-0.11, -0.33, 0.07], [0.11, -0.33, 0.07], [-0.13, -0.02, 0.09], [0.13, -0.02, 0.09]]:
		var perna := Node3D.new()
		perna.position = Vector3(d[0], -0.02, d[1])
		perna.set_meta("frente", float(d[1]) < -0.1)
		m.corpo.add_child(perna)
		_peca(perna, "marmota_escura", Vector3(0, -0.085, 0), Vector3(d[2], 0.18, d[2] * 1.2), Vector3.ZERO, 8)
		m.pernas.append(perna)
	return m


func _ponto(centro: Vector3, raio: float) -> Vector3:
	for k in 12:
		var x := centro.x + _rng.randf_range(-raio, raio)
		var z := centro.z + _rng.randf_range(-raio, raio)
		if mapa.agua(x, z) == -INF and mapa.normal_em(x, z).y > 0.8:
			return Vector3(x, mapa.altura(x, z), z)
	return Vector3(centro.x, mapa.altura(centro.x, centro.z), centro.z)


# ---------------------------------------------------------------- comportamento

## Um tiro ou o robô passando: a colônia toda corre para as tocas.
func assustar(ponto: Vector3) -> void:
	if Vector2(ponto.x - casa.x, ponto.z - casa.z).length() > 70.0:
		return
	for m in _marmotas:
		_fugir(m)


func _fugir(m: Marmota) -> void:
	if m.estado == Estado.FOGE or m.estado == Estado.TOCA:
		return
	if m.estado == Estado.ESPIA:
		m.estado = Estado.TOCA
		m.t = _rng.randf_range(12.0, 22.0)
		return
	m.estado = Estado.FOGE
	m.t = 12.0
	fugas += 1


func _process(delta: float) -> void:
	if _marmotas.is_empty():
		return
	var alvo := ameaca.global_position if is_instance_valid(ameaca) else Vector3(1e9, 0, 1e9)
	var d := Vector2(alvo.x - casa.x, alvo.z - casa.z).length()
	_t_alarme -= delta
	for m in _marmotas:
		_pensar(m, alvo, d, delta)
		_animar(m, alvo, delta)


func _pensar(m: Marmota, alvo: Vector3, d_casa: float, delta: float) -> void:
	var d := Vector2(alvo.x - m.pos.x, alvo.z - m.pos.z).length()
	m.t -= delta
	match m.estado:
		Estado.PASTA, Estado.VIGIA, Estado.ALERTA:
			if d < DIST_FOGE:
				_fugir(m)
				return
			if d_casa < DIST_ALERTA:
				if m.estado != Estado.ALERTA and m.vigia and _t_alarme <= 0.0:
					alarmes += 1
					_t_alarme = 6.0
				m.estado = Estado.ALERTA
				m.olhar = 0.0
				return
			if m.estado == Estado.ALERTA:
				m.estado = Estado.VIGIA if m.vigia else Estado.PASTA
				m.t = _rng.randf_range(1.0, 3.0)
			if m.estado == Estado.VIGIA:
				if m.t <= 0.0:
					m.olhar = _rng.randf_range(-1.1, 1.1)
					m.yaw += _rng.randf_range(-0.6, 0.6)
					m.t = _rng.randf_range(2.0, 5.0)
				return
			# pastando: anda um pouco, come, olha em volta
			var falta := Vector2(m.alvo.x - m.pos.x, m.alvo.z - m.pos.z)
			if falta.length() > 0.15:
				m.yaw = lerp_angle(m.yaw, atan2(-falta.x, -falta.y), 1.0 - exp(-4.0 * delta))
				var passo := minf(VEL_ANDA * delta, falta.length())
				var dir := falta.normalized()
				m.pos += Vector3(dir.x, 0, dir.y) * passo
				m.pos.y = mapa.altura(m.pos.x, m.pos.z)
				m.fase += delta * 7.0
				m.come = 0.0
			elif m.t <= 0.0:
				var r := _rng.randf()
				if r < 0.45:
					m.alvo = _ponto(m.toca, 4.0)
					m.t = _rng.randf_range(1.0, 2.0)
				elif r < 0.8:
					m.come = 1.0
					m.t = _rng.randf_range(2.0, 5.0)
				else:
					m.come = 0.0
					m.olhar = _rng.randf_range(-0.9, 0.9)
					m.t = _rng.randf_range(1.0, 2.5)
		Estado.FOGE:
			var falta := Vector2(m.toca.x - m.pos.x, m.toca.z - m.pos.z)
			m.yaw = lerp_angle(m.yaw, atan2(-falta.x, -falta.y), 1.0 - exp(-8.0 * delta))
			m.fase += delta * 14.0
			var passo := VEL_FOGE * delta
			if falta.length() <= passo or m.t <= 0.0:
				m.pos = m.toca
				m.fundo = minf(m.fundo + delta * 2.5, 1.0)
				if m.fundo >= 1.0:
					m.estado = Estado.TOCA
					m.raiz.visible = false
					m.t = _rng.randf_range(12.0, 22.0)
			else:
				var dir := falta.normalized()
				m.pos += Vector3(dir.x, 0, dir.y) * passo
				# da pedra, a vigia pula para o chão
				m.pos.y = move_toward(m.pos.y, mapa.altura(m.pos.x, m.pos.z), 4.0 * delta)
		Estado.TOCA:
			if m.t <= 0.0:
				# põe a cabeça para fora e olha
				m.estado = Estado.ESPIA
				m.raiz.visible = true
				m.fundo = 0.66
				m.pos = m.toca
				var para := Vector2(alvo.x - m.pos.x, alvo.z - m.pos.z)
				m.yaw = atan2(-para.x, -para.y)
				m.t = _rng.randf_range(4.0, 8.0)
		Estado.ESPIA:
			if d < DIST_FOGE * 0.7:
				m.estado = Estado.TOCA
				m.raiz.visible = false
				m.fundo = 1.0
				m.t = _rng.randf_range(10.0, 18.0)
			elif m.t <= 0.0:
				if d > DIST_VOLTA:
					m.fundo = 0.0
					m.estado = Estado.VIGIA if m.vigia else Estado.PASTA
					m.alvo = _topo if m.vigia else _ponto(m.toca, 3.0)
					if m.vigia:
						m.pos = _topo
					m.t = _rng.randf_range(1.0, 3.0)
				else:
					m.t = _rng.randf_range(3.0, 6.0)


func _animar(m: Marmota, alvo: Vector3, delta: float) -> void:
	if not m.raiz.visible:
		return
	var k := 1.0 - exp(-6.0 * delta)
	var em_pe := m.estado in [Estado.VIGIA, Estado.ALERTA, Estado.ESPIA]
	m.erguido = lerpf(m.erguido, 1.0 if em_pe else 0.0, k)
	# olha para o robô em alerta; o alarme da vigia é a cabeça jogada para trás, de boca aberta
	var giro := m.olhar
	if m.estado == Estado.ALERTA or m.estado == Estado.ESPIA:
		var para := Vector2(alvo.x - m.pos.x, alvo.z - m.pos.z)
		var rel := wrapf(atan2(-para.x, -para.y) - m.yaw, -PI, PI)
		if absf(rel) > 1.0:
			m.yaw = lerp_angle(m.yaw, atan2(-para.x, -para.y), 1.0 - exp(-2.0 * delta))
		giro = clampf(rel, -1.0, 1.0)
	var grito := 0.0
	if m.vigia and m.estado == Estado.ALERTA and _t_alarme > 5.2:
		grito = sin((6.0 - _t_alarme) * PI / 0.8) * 0.5
	var come := m.come * (0.55 + 0.12 * sin(Time.get_ticks_msec() * 0.012 + m.toca.x)) * (1.0 - m.erguido)
	m.cabeca.rotation = m.cabeca.rotation.lerp(Vector3(-come + grito - m.erguido * EM_PE * 0.85, giro, 0.0), k)
	var correndo := m.estado == Estado.FOGE
	var andando := m.estado == Estado.PASTA and Vector2(m.alvo.x - m.pos.x, m.alvo.z - m.pos.z).length() > 0.15
	var galope := sin(m.fase) if correndo else 0.0
	m.corpo.rotation.x = m.erguido * EM_PE + galope * 0.18
	m.cauda.rotation.x = (0.5 if m.estado == Estado.ALERTA else 0.0) + galope * 0.4
	for p in m.pernas:
		var frente: bool = p.get_meta("frente")
		var bate := 0.0
		if correndo:
			bate = sin(m.fase + (0.0 if frente else PI)) * 0.9
		elif andando:
			bate = sin(m.fase + (0.0 if frente else PI) + p.position.x * 20.0) * 0.5
		# em pé, as patas de trás ficam no chão (desfazem a inclinação do corpo) e as da frente pendem no peito
		p.rotation.x = bate - m.erguido * EM_PE * (0.75 if frente else 1.0)
	var pulo := absf(galope) * 0.1 if correndo else (absf(sin(m.fase)) * 0.02 if andando else 0.0)
	var n := mapa.normal_em(m.pos.x, m.pos.z) if m.pos.y - mapa.altura(m.pos.x, m.pos.z) < 0.3 else Vector3.UP
	var frente_v := Vector3(-sin(m.yaw), 0, -cos(m.yaw))
	frente_v = (frente_v - n * frente_v.dot(n)).normalized()
	m.raiz.transform = Transform3D(Basis.looking_at(frente_v, n), Vector3(m.pos.x, m.pos.y + pulo - m.fundo * 0.75 * ESCALA, m.pos.z))


## Quantas estão fora da toca agora (testes).
func fora() -> int:
	var n := 0
	for m in _marmotas:
		if m.estado != Estado.TOCA:
			n += 1
	return n
