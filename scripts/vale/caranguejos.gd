class_name Caranguejos
extends Node3D
## Caranguejos na areia da praia da ponta leste (terra nova, 2026-11-21). Andam de lado, param e abanam as
## garras; com o robô perto correm de lado para a água e somem nela (sem água perto, se enterram na areia), e
## voltam a aparecer quando ele se afasta. Feitos por código, em formas simples; só visual, sem física.
## Uso: Caranguejos.new(), defina mapa, ameaca, casa, quantos, semente e materiais (a Clareira); depois add_child.
## A frente do caranguejo é -Z; ele anda no eixo X dele (de lado).

enum Estado { PARADO, ANDA, FOGE, ESCONDIDO }

const ESCALA := 1.6  # maior que o real (como os outros bichos pequenos), para aparecer na areia
const RAIO_CASA := 9.0
const VEL_ANDA := 0.35
const VEL_FOGE := 2.4
const DIST_FOGE := 6.5
const DIST_VOLTA := 18.0

var mapa: Vale
var ameaca: Node3D
var casa := Vector3.ZERO
var quantos := 5
var semente := 0
var materiais: Clareira
var fugas := 0  # quantas vezes um caranguejo fugiu (testes)

var _rng := RandomNumberGenerator.new()
var _bichos: Array[Bicho] = []


class Bicho:
	var raiz: Node3D
	var corpo: Node3D
	var pernas: Array[Node3D] = []
	var garras: Array[Node3D] = []
	var pos := Vector3.ZERO
	var yaw := 0.0
	var lado := 1.0  # para que lado anda (+X ou -X dele)
	var estado := Estado.PARADO
	var t := 0.0  # tempo que falta no estado
	var fase := 0.0
	var aceno := 0.0
	var fundo := 0.0  # quanto já afundou (água ou areia)


func _ready() -> void:
	if mapa == null or materiais == null:
		push_error("caranguejos: falta o mapa ou os materiais")
		return
	add_to_group("bichos")
	_rng.seed = semente * 6007 + 13
	for i in quantos:
		var b := _novo()
		b.pos = _ponto(casa, RAIO_CASA)
		b.yaw = _rng.randf() * TAU
		b.t = _rng.randf_range(0.5, 3.0)
		_bichos.append(b)


func _mat(nome: String) -> Material:
	return materiais.material(nome)


func _peca(pai: Node3D, malha: Mesh, mat: String, pos: Vector3, esc: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = _mat(mat)
	mi.position = pos
	mi.rotation = rot
	mi.scale = esc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


## Uma caixa esticada de `de` até `ate`, da grossura `esp` (os ossos das pernas e das garras).
func _osso(pai: Node3D, caixa: Mesh, mat: String, de: Vector3, ate: Vector3, esp: float) -> void:
	var y := ate - de
	var comp := y.length()
	y /= comp
	var x := y.cross(Vector3.FORWARD) if absf(y.z) < 0.9 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	var mi := MeshInstance3D.new()
	mi.mesh = caixa
	mi.material_override = _mat(mat)
	mi.transform = Transform3D(Basis(x, y, x.cross(y)) * Basis.from_scale(Vector3(esp, comp, esp)), (de + ate) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)


func _novo() -> Bicho:
	var b := Bicho.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.5
	esfera.height = 1.0
	esfera.radial_segments = 12
	esfera.rings = 6
	var caixa := BoxMesh.new()
	b.raiz = Node3D.new()
	b.raiz.scale = Vector3.ONE * ESCALA
	add_child(b.raiz)
	b.corpo = Node3D.new()
	b.corpo.position.y = 0.05  # rente ao chão
	b.raiz.add_child(b.corpo)
	# a carapaça: larga e chata, mais clara embaixo
	_peca(b.corpo, esfera, "caranguejo", Vector3.ZERO, Vector3(0.19, 0.065, 0.14))
	_peca(b.corpo, esfera, "caranguejo_claro", Vector3(0, -0.012, 0), Vector3(0.17, 0.045, 0.12))
	# os olhos em talos
	for s: float in [-1.0, 1.0]:
		_peca(b.corpo, caixa, "caranguejo", Vector3(s * 0.025, 0.035, -0.055), Vector3(0.008, 0.03, 0.008))
		_peca(b.corpo, esfera, "junta", Vector3(s * 0.025, 0.053, -0.055), Vector3.ONE * 0.014)
	# quatro pernas de cada lado, abertas em leque: a coxa sobe do corpo até o joelho e a canela desce até a
	# areia, bem para fora (o chão fica 0,05 abaixo do meio do corpo)
	for s: float in [-1.0, 1.0]:
		for k in 4:
			var leque := (k - 1.5) * 0.03
			var piv := Node3D.new()
			piv.position = Vector3(s * 0.075, 0.0, -0.03 + k * 0.022)
			b.corpo.add_child(piv)
			var joelho := Vector3(s * 0.07, 0.04, leque * 0.5)
			_osso(piv, caixa, "caranguejo", Vector3.ZERO, joelho, 0.02)
			_osso(piv, caixa, "caranguejo", joelho, Vector3(s * 0.15, -0.05, leque * 1.3), 0.015)
			piv.set_meta("lado", s)
			piv.set_meta("par", k % 2)
			b.pernas.append(piv)
		# a garra: braço curto subindo para a frente e a pinça grande, de ponta clara
		var g := Node3D.new()
		g.position = Vector3(s * 0.065, 0.0, -0.05)
		b.corpo.add_child(g)
		_osso(g, caixa, "caranguejo", Vector3.ZERO, Vector3(s * 0.03, 0.022, -0.05), 0.018)
		_peca(g, esfera, "caranguejo", Vector3(s * 0.034, 0.026, -0.085), Vector3(0.042, 0.034, 0.058))
		_osso(g, caixa, "caranguejo_claro", Vector3(s * 0.034, 0.03, -0.108), Vector3(s * 0.026, 0.028, -0.138), 0.012)
		_osso(g, caixa, "caranguejo_claro", Vector3(s * 0.042, 0.018, -0.105), Vector3(s * 0.034, 0.014, -0.13), 0.009)
		g.set_meta("lado", s)
		b.garras.append(g)
	return b


func _ponto(centro: Vector3, raio: float) -> Vector3:
	for k in 12:
		var x := centro.x + _rng.randf_range(-raio, raio)
		var z := centro.z + _rng.randf_range(-raio, raio)
		var h := mapa.altura(x, z)
		if h > 0.25 and h < 2.6 and mapa.cobertura(x, z) == 4:
			return Vector3(x, h, z)
	return Vector3(centro.x, mapa.altura(centro.x, centro.z), centro.z)


func _process(delta: float) -> void:
	if _bichos.is_empty():
		return
	var alvo := ameaca.global_position if ameaca else Vector3(1e9, 0, 1e9)
	for b in _bichos:
		_pensar(b, alvo, delta)
		_animar(b, delta)


func _pensar(b: Bicho, alvo: Vector3, delta: float) -> void:
	var d := Vector2(alvo.x - b.pos.x, alvo.z - b.pos.z).length()
	b.t -= delta
	match b.estado:
		Estado.PARADO, Estado.ANDA:
			if d < DIST_FOGE:
				b.estado = Estado.FOGE
				fugas += 1
				# foge de lado para onde o chão desce (a água); vira o corpo de modo que o X dele aponte para lá
				var desce := _para_baixo(b.pos)
				var longe := Vector2(b.pos.x - alvo.x, b.pos.z - alvo.z).normalized()
				var rumo := (desce * 0.7 + longe * 0.3).normalized()
				b.yaw = -atan2(rumo.y, rumo.x)  # o X dele (para onde anda de lado) aponta para o rumo
				b.lado = 1.0
				b.t = 6.0
			elif b.t <= 0.0:
				if b.estado == Estado.PARADO:
					b.estado = Estado.ANDA
					b.lado = 1.0 if _rng.randf() < 0.5 else -1.0
					if Vector2(b.pos.x - casa.x, b.pos.z - casa.z).length() > RAIO_CASA:
						# longe de casa: volta para ela
						var para := Vector2(casa.x - b.pos.x, casa.z - b.pos.z).normalized()
						b.yaw = -atan2(para.y, para.x)
						b.lado = 1.0
					else:
						b.yaw += _rng.randf_range(-0.8, 0.8)
					b.t = _rng.randf_range(1.0, 3.2)
				else:
					b.estado = Estado.PARADO
					b.t = _rng.randf_range(1.0, 4.5)
					b.aceno = 1.0 if _rng.randf() < 0.4 else 0.0
			if b.estado == Estado.ANDA:
				_andar(b, VEL_ANDA * delta, true)
		Estado.FOGE:
			var antes := b.pos
			_andar(b, VEL_FOGE * delta, false)
			var h := mapa.altura(b.pos.x, b.pos.z)
			var parado := antes.distance_to(b.pos) < VEL_FOGE * delta * 0.3
			if h < -0.1 or parado or b.t <= 0.0:
				# na água some; sem água perto, se enterra
				b.fundo = minf(b.fundo + delta * 0.5, 0.4)
				if b.fundo >= 0.4:
					b.estado = Estado.ESCONDIDO
					b.raiz.visible = false
					b.t = _rng.randf_range(14.0, 30.0)
		Estado.ESCONDIDO:
			if b.t <= 0.0 and d > DIST_VOLTA:
				b.pos = _ponto(casa, RAIO_CASA)
				b.fundo = 0.0
				b.raiz.visible = true
				b.estado = Estado.PARADO
				b.t = _rng.randf_range(1.0, 3.0)


## A direção (no chão) em que o terreno desce mais: para onde fica o mar.
func _para_baixo(p: Vector3) -> Vector2:
	var e := 3.0
	var gx := mapa.altura(p.x + e, p.z) - mapa.altura(p.x - e, p.z)
	var gz := mapa.altura(p.x, p.z + e) - mapa.altura(p.x, p.z - e)
	var g := Vector2(-gx, -gz)
	return g.normalized() if g.length() > 0.001 else Vector2(1, 0)


func _andar(b: Bicho, passo: float, cuidado: bool) -> void:
	var dir := Vector3(cos(-b.yaw), 0, sin(-b.yaw)) * b.lado
	var novo := b.pos + dir * passo
	var h := mapa.altura(novo.x, novo.z)
	if cuidado and (h < 0.15 or h > 3.0 or mapa.cobertura(novo.x, novo.z) != 4):
		b.lado = -b.lado  # no passeio não sai da areia
		return
	novo.y = h
	b.pos = novo


func _animar(b: Bicho, delta: float) -> void:
	var andando := b.estado == Estado.ANDA or b.estado == Estado.FOGE
	var ritmo := 22.0 if b.estado == Estado.FOGE else 11.0
	if andando:
		b.fase = fmod(b.fase + ritmo * delta, TAU)
	var y := maxf(b.pos.y, 0.0) if b.estado != Estado.FOGE else b.pos.y
	b.raiz.position = Vector3(b.pos.x, y - b.fundo, b.pos.z)
	b.raiz.rotation = Vector3(0, b.yaw, 0)
	for p in b.pernas:
		var s: float = p.get_meta("lado")
		var par: int = p.get_meta("par")
		var f := b.fase + (PI if par == 1 else 0.0) + (0.0 if s > 0 else PI * 0.5)
		p.rotation = Vector3(0, sin(f) * 0.35 if andando else 0.0, maxf(0.0, cos(f)) * 0.35 * s if andando else 0.0)
	b.corpo.position.y = 0.05 + (absf(sin(b.fase * 2.0)) * 0.006 if andando else 0.0)
	b.aceno = maxf(0.0, b.aceno - delta * 0.25)
	for g in b.garras:
		var s2: float = g.get_meta("lado")
		var abre := sin(Time.get_ticks_msec() * 0.008 + s2) * 0.5 + 0.5
		g.rotation = Vector3(-0.5 * b.aceno * abre - (0.25 if b.estado == Estado.FOGE else 0.0), 0, 0)


## Quantos estão à vista agora (testes).
func visiveis() -> int:
	var n := 0
	for b in _bichos:
		if b.raiz.visible:
			n += 1
	return n
