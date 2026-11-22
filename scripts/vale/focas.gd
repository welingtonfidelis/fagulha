class_name Focas
extends Node3D
## Focas deitadas na areia da ponta leste (terra nova, 2026-11-21). Ficam ao sol levantando a cabeça de vez em
## quando; com o robô chegando, olham para ele; perto demais, vão aos pulinhos até o mar, nadam um pouco com a
## cabeça de fora e mergulham. Voltam a deitar no mesmo lugar quando ele vai embora. Feitas por código, em
## formas simples; só visual, sem física.
## Uso: Focas.new(), defina mapa, ameaca, casa, quantos, semente e materiais (a Clareira); depois add_child.
## A frente da foca é -Z.

enum Estado { DEITADA, ALERTA, FOGE, NADA, SUMIDA }

const DIST_ALERTA := 28.0
const DIST_FOGE := 13.0
const DIST_VOLTA := 50.0
const VEL_FOGE := 1.7
const VEL_NADO := 1.3

var mapa: Vale
var ameaca: Node3D
var casa := Vector3.ZERO
var quantos := 3
var semente := 0
var materiais: Clareira
var fugas := 0  # testes

var _rng := RandomNumberGenerator.new()
var _focas: Array[Foca] = []


class Foca:
	var raiz: Node3D
	var corpo: Node3D
	var cabeca: Node3D
	var nadadeiras: Array[Node3D] = []
	var lugar := Vector3.ZERO  # onde deita
	var pos := Vector3.ZERO
	var yaw := 0.0
	var estado := Estado.DEITADA
	var t := 0.0
	var fase := 0.0
	var olhar := Vector2.ZERO  # giro e inclinação da cabeça (alvo)
	var olhar_agora := Vector2.ZERO
	var rumo := Vector2.ZERO
	var fundo := 0.0


func _ready() -> void:
	if mapa == null or materiais == null:
		push_error("focas: falta o mapa ou os materiais")
		return
	add_to_group("bichos")
	_rng.seed = semente * 4973 + 7
	for i in quantos:
		var f := _nova()
		f.lugar = _ponto(casa, 7.0)
		f.pos = f.lugar
		f.yaw = _rng.randf() * TAU
		f.t = _rng.randf_range(2.0, 6.0)
		_focas.append(f)


func _peca(pai: Node3D, mat: String, pos: Vector3, esc: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var esfera := SphereMesh.new()
	esfera.radius = 0.5
	esfera.height = 1.0
	esfera.radial_segments = 14
	esfera.rings = 7
	var mi := MeshInstance3D.new()
	mi.mesh = esfera
	mi.material_override = materiais.material(mat)
	mi.position = pos
	mi.rotation = rot
	mi.scale = esc
	pai.add_child(mi)
	return mi


func _nova() -> Foca:
	var f := Foca.new()
	f.raiz = Node3D.new()
	add_child(f.raiz)
	f.corpo = Node3D.new()
	f.raiz.add_child(f.corpo)
	# corpo de torpedo: o tronco, a barriga clara e o quarto de trás afinando até as nadadeiras
	_peca(f.corpo, "foca", Vector3(0, 0.24, -0.04), Vector3(0.64, 0.48, 1.3))
	_peca(f.corpo, "foca_clara", Vector3(0, 0.13, 0.0), Vector3(0.56, 0.26, 1.35))
	_peca(f.corpo, "foca", Vector3(0, 0.2, 0.36), Vector3(0.5, 0.38, 0.95))
	_peca(f.corpo, "foca", Vector3(0, 0.14, 0.72), Vector3(0.28, 0.2, 0.5))
	for s: float in [-1.0, 1.0]:
		var tras := Node3D.new()
		tras.position = Vector3(s * 0.05, 0.11, 0.92)
		f.corpo.add_child(tras)
		_peca(tras, "foca", Vector3(s * 0.06, 0, 0.12), Vector3(0.16, 0.04, 0.28), Vector3(0, s * 0.35, 0))
		tras.set_meta("lado", s)
		f.nadadeiras.append(tras)
		var frente := Node3D.new()
		frente.position = Vector3(s * 0.28, 0.1, -0.24)
		f.corpo.add_child(frente)
		_peca(frente, "foca", Vector3(s * 0.04, 0, 0.06), Vector3(0.1, 0.04, 0.24), Vector3(0, -s * 0.5, s * 0.3))
		frente.set_meta("lado", s)
		f.nadadeiras.append(frente)
	# a cabeça: redonda, focinho claro, olhos grandes e escuros
	f.cabeca = Node3D.new()
	f.cabeca.position = Vector3(0, 0.32, -0.6)
	f.corpo.add_child(f.cabeca)
	_peca(f.cabeca, "foca", Vector3(0, 0.07, -0.1), Vector3(0.3, 0.27, 0.32))
	_peca(f.cabeca, "foca_clara", Vector3(0, 0.03, -0.24), Vector3(0.17, 0.13, 0.15))
	_peca(f.cabeca, "junta", Vector3(0, 0.06, -0.31), Vector3(0.05, 0.035, 0.03))
	for s: float in [-1.0, 1.0]:
		_peca(f.cabeca, "junta", Vector3(s * 0.085, 0.12, -0.2), Vector3.ONE * 0.055)
	return f


func _ponto(centro: Vector3, raio: float) -> Vector3:
	for k in 14:
		var x := centro.x + _rng.randf_range(-raio, raio)
		var z := centro.z + _rng.randf_range(-raio, raio)
		var h := mapa.altura(x, z)
		if h > 0.3 and h < 2.4:
			return Vector3(x, h, z)
	return Vector3(centro.x, maxf(mapa.altura(centro.x, centro.z), 0.3), centro.z)


func _process(delta: float) -> void:
	if _focas.is_empty():
		return
	var alvo := ameaca.global_position if ameaca else Vector3(1e9, 0, 1e9)
	for f in _focas:
		_pensar(f, alvo, delta)
		_animar(f, alvo, delta)


func _pensar(f: Foca, alvo: Vector3, delta: float) -> void:
	var d := Vector2(alvo.x - f.pos.x, alvo.z - f.pos.z).length()
	f.t -= delta
	match f.estado:
		Estado.DEITADA, Estado.ALERTA:
			if d < DIST_FOGE:
				f.estado = Estado.FOGE
				fugas += 1
				var desce := _para_baixo(f.pos)
				var longe := Vector2(f.pos.x - alvo.x, f.pos.z - alvo.z).normalized()
				f.rumo = (desce * 0.75 + longe * 0.25).normalized()
				f.t = 20.0
			elif d < DIST_ALERTA:
				f.estado = Estado.ALERTA
			else:
				f.estado = Estado.DEITADA
				if f.t <= 0.0:
					# de vez em quando levanta a cabeça e olha em volta; no resto, cabeça encostada
					f.olhar = Vector2(_rng.randf_range(-0.7, 0.7), -0.45) if _rng.randf() < 0.5 else Vector2(0, 0.25)
					f.t = _rng.randf_range(2.5, 7.0)
		Estado.FOGE:
			var alvo_yaw := atan2(-f.rumo.x, -f.rumo.y)
			f.yaw = lerp_angle(f.yaw, alvo_yaw, 1.0 - exp(-5.0 * delta))
			f.fase += delta * 6.5
			var passo := VEL_FOGE * delta * (0.4 + 0.6 * maxf(0.0, sin(f.fase)))
			f.pos += Vector3(f.rumo.x, 0, f.rumo.y) * passo
			f.pos.y = mapa.altura(f.pos.x, f.pos.z)
			if f.pos.y < -0.45 or f.t <= 0.0:
				f.estado = Estado.NADA
				f.t = _rng.randf_range(6.0, 10.0)
		Estado.NADA:
			f.fase += delta * 2.0
			f.pos += Vector3(f.rumo.x, 0, f.rumo.y) * VEL_NADO * delta
			f.pos.y = -0.24
			if f.t <= 0.0:
				# mergulha
				f.fundo = minf(f.fundo + delta * 0.6, 1.2)
				if f.fundo >= 1.2:
					f.estado = Estado.SUMIDA
					f.raiz.visible = false
					f.t = _rng.randf_range(30.0, 60.0)
		Estado.SUMIDA:
			if f.t <= 0.0 and Vector2(alvo.x - f.lugar.x, alvo.z - f.lugar.z).length() > DIST_VOLTA:
				f.pos = f.lugar
				f.fundo = 0.0
				f.raiz.visible = true
				f.estado = Estado.DEITADA
				f.t = _rng.randf_range(2.0, 5.0)


func _para_baixo(p: Vector3) -> Vector2:
	var e := 4.0
	var gx := mapa.altura(p.x + e, p.z) - mapa.altura(p.x - e, p.z)
	var gz := mapa.altura(p.x, p.z + e) - mapa.altura(p.x, p.z - e)
	var g := Vector2(-gx, -gz)
	return g.normalized() if g.length() > 0.001 else Vector2(1, 0)


func _animar(f: Foca, alvo: Vector3, delta: float) -> void:
	var k := 1.0 - exp(-3.0 * delta)
	if f.estado == Estado.ALERTA:
		# cabeça erguida virada para o robô
		var para := Vector2(alvo.x - f.pos.x, alvo.z - f.pos.z)
		var rel := wrapf(atan2(-para.x, -para.y) - f.yaw, -PI, PI)
		f.olhar = Vector2(clampf(rel, -0.9, 0.9), -0.55)
	elif f.estado == Estado.FOGE or f.estado == Estado.NADA:
		f.olhar = Vector2(0, -0.2)
	f.olhar_agora = f.olhar_agora.lerp(f.olhar, k)
	f.cabeca.rotation = Vector3(-f.olhar_agora.y, f.olhar_agora.x, 0)  # y negativo ergue a cabeça
	var pulo := 0.0
	var arqueia := 0.0
	if f.estado == Estado.FOGE:
		pulo = maxf(0.0, sin(f.fase)) * 0.12
		arqueia = sin(f.fase) * 0.12
	var balanco := sin(f.fase) * 0.05 if f.estado == Estado.NADA else 0.0
	f.raiz.position = Vector3(f.pos.x, f.pos.y + pulo - f.fundo, f.pos.z)
	f.raiz.rotation = Vector3(arqueia, f.yaw, balanco)
	for n in f.nadadeiras:
		var s: float = n.get_meta("lado")
		var bate := sin(f.fase * 1.3 + s) * 0.4 if (f.estado == Estado.FOGE or f.estado == Estado.NADA) else sin(Time.get_ticks_msec() * 0.0007 + s) * 0.06
		n.rotation.y = bate


## Quantas estão deitadas na areia agora (testes).
func deitadas() -> int:
	var n := 0
	for f in _focas:
		if f.estado == Estado.DEITADA or f.estado == Estado.ALERTA:
			n += 1
	return n
