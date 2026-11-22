class_name Patos
extends Node3D
## Patos-arlequim na água fria embaixo das quedas da Montanha do Degelo, nos lagos dela e na água morna das fontes
## quentes (terra nova, 2026-11-22, doc §137.14). Nadam devagar em volta da casa, de cabeça balançando, e de vez em
## quando mergulham e voltam à tona uns metros adiante. Com o robô perto, nadam para longe; perto demais, mergulham
## e só aparecem longe dele. O macho é azul-ardósia com os flancos castanhos e riscos brancos; a fêmea é parda, com
## as pintas brancas na cara. Feitos por código, em formas simples; só visual, sem física.
## Uso: Patos.new(), defina mapa, ameaca, casa (na água), raio, quantos, semente e materiais (a Clareira); depois
## add_child. A frente do pato é -Z.

enum Estado { NADA, MERGULHA, SUMIDO, FOGE }

const DIST_FOGE := 16.0
const DIST_MERGULHO := 7.0
const VEL := 0.45
const VEL_FOGE := 1.6
const ESCALA := 1.5  # maior que o de verdade, para aparecer na água
const FUNDO_MIN := 0.25  # a água tem de ter ao menos isso de fundo

var mapa: Vale
var ameaca: Node3D
var casa := Vector3.ZERO
var raio := 14.0
var quantos := 2
var semente := 0
var materiais: Clareira
var mergulhos := 0  # testes

var _rng := RandomNumberGenerator.new()
var _patos: Array[Pato] = []
var _nivel := 0.0  # o nível da água na casa (para não passar de um poço para o outro numa queda)


class Pato:
	var raiz: Node3D
	var corpo: Node3D
	var cabeca: Node3D
	var pos := Vector3.ZERO
	var alvo := Vector3.ZERO
	var yaw := 0.0
	var estado := Estado.NADA
	var t := 0.0
	var fase := 0.0
	var afunda := 0.0  # 0 boiando, 1 sumido
	var mergulho := 0.0  # a inclinação de bico para baixo


func _ready() -> void:
	if mapa == null or materiais == null:
		push_error("patos: falta o mapa ou os materiais")
		return
	add_to_group("bichos")
	_rng.seed = semente * 5711 + 3
	_nivel = mapa.agua(casa.x, casa.z)
	if _nivel == -INF:
		push_warning("patos: a casa %s não está na água" % casa)
		return
	for i in quantos:
		var p := _novo(i % 2 == 0)
		p.pos = _ponto(casa, raio * 0.4, Vector3.INF)
		p.alvo = p.pos
		p.yaw = _rng.randf() * TAU
		p.t = _rng.randf_range(1.0, 4.0)
		p.fase = _rng.randf() * TAU
		_patos.append(p)


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


func _novo(macho: bool) -> Pato:
	var p := Pato.new()
	p.raiz = BichoFicha.nova("pato", self, 0.15)
	add_child(p.raiz)
	p.corpo = Node3D.new()
	p.corpo.scale = Vector3.ONE * ESCALA
	p.raiz.add_child(p.corpo)
	var cor := "pato" if macho else "pato_femea"
	# o corpo boia baixo: a linha d'água passa um pouco abaixo do meio
	_peca(p.corpo, cor, Vector3(0, 0.04, 0.0), Vector3(0.21, 0.15, 0.38))
	_peca(p.corpo, cor, Vector3(0, 0.08, 0.17), Vector3(0.09, 0.05, 0.16), Vector3(-0.5, 0, 0), 8)  # a cauda erguida
	if macho:
		for s: float in [-1.0, 1.0]:
			_peca(p.corpo, "pato_castanho", Vector3(s * 0.07, 0.045, 0.05), Vector3(0.09, 0.09, 0.25), Vector3.ZERO, 10)
			_peca(p.corpo, "pato_branco", Vector3(s * 0.098, 0.065, -0.11), Vector3(0.025, 0.11, 0.035), Vector3(0.2, 0, 0), 8)
			_peca(p.corpo, "pato_branco", Vector3(s * 0.055, 0.11, 0.03), Vector3(0.03, 0.025, 0.15), Vector3.ZERO, 8)
	# o pescoço curto e a cabeça
	_peca(p.corpo, cor, Vector3(0, 0.1, -0.14), Vector3(0.09, 0.12, 0.09), Vector3(0.3, 0, 0), 10)
	p.cabeca = Node3D.new()
	p.cabeca.position = Vector3(0, 0.16, -0.17)
	p.corpo.add_child(p.cabeca)
	_peca(p.cabeca, cor, Vector3(0, 0.02, -0.02), Vector3(0.11, 0.105, 0.13))
	_peca(p.cabeca, "bico_pato", Vector3(0, 0.0, -0.1), Vector3(0.04, 0.03, 0.06), Vector3.ZERO, 8)
	for s: float in [-1.0, 1.0]:
		_peca(p.cabeca, "junta", Vector3(s * 0.05, 0.035, -0.04), Vector3.ONE * 0.022, Vector3.ZERO, 6)
		if macho:
			_peca(p.cabeca, "pato_branco", Vector3(s * 0.035, 0.03, -0.075), Vector3(0.025, 0.055, 0.02), Vector3.ZERO, 6)
			_peca(p.cabeca, "pato_branco", Vector3(s * 0.05, 0.04, 0.02), Vector3(0.015, 0.025, 0.03), Vector3.ZERO, 6)
		else:
			_peca(p.cabeca, "pato_branco", Vector3(s * 0.04, 0.0, -0.07), Vector3.ONE * 0.028, Vector3.ZERO, 6)
			_peca(p.cabeca, "pato_branco", Vector3(s * 0.052, 0.04, 0.0), Vector3.ONE * 0.022, Vector3.ZERO, 6)
	if macho:
		_peca(p.cabeca, "pato_castanho", Vector3(0, 0.075, -0.02), Vector3(0.035, 0.02, 0.1), Vector3.ZERO, 6)
		_peca(p.corpo, "pato_branco", Vector3(0, 0.065, -0.135), Vector3(0.1, 0.02, 0.06), Vector3(0.3, 0, 0), 8)  # a gola
	return p


## Um ponto de água com fundo, no mesmo poço da casa, a até `r` do centro; longe de `fugir_de` (se não for INF).
func _ponto(centro: Vector3, r: float, fugir_de: Vector3) -> Vector3:
	var melhor := Vector3.INF
	var melhor_d := -1.0
	for k in 14:
		var ang := _rng.randf() * TAU
		var x := centro.x + cos(ang) * _rng.randf_range(0.0, r)
		var z := centro.z + sin(ang) * _rng.randf_range(0.0, r)
		if not _molhado(x, z):
			continue
		var p := Vector3(x, mapa.agua(x, z), z)
		if not fugir_de.is_finite():
			return p
		var d := Vector2(x - fugir_de.x, z - fugir_de.z).length()
		if d > melhor_d:
			melhor_d = d
			melhor = p
	if melhor.is_finite():
		return melhor
	return Vector3(casa.x, _nivel, casa.z)


func _molhado(x: float, z: float) -> bool:
	if Vector2(x - casa.x, z - casa.z).length() > raio:
		return false
	var n := mapa.agua(x, z)
	return n > -INF and absf(n - _nivel) < 1.5 and n - mapa.altura(x, z) > FUNDO_MIN


## Um tiro perto: os patos mergulham.
func assustar(ponto: Vector3) -> void:
	if Vector2(ponto.x - casa.x, ponto.z - casa.z).length() > 60.0:
		return
	for p in _patos:
		if p.estado == Estado.NADA or p.estado == Estado.FOGE:
			_mergulhar(p, ponto)


func _mergulhar(p: Pato, longe_de: Vector3) -> void:
	p.estado = Estado.MERGULHA
	p.alvo = _ponto(casa, raio, longe_de)
	mergulhos += 1


func _process(delta: float) -> void:
	if _patos.is_empty():
		return
	var alvo := ameaca.global_position if is_instance_valid(ameaca) else Vector3(1e9, 0, 1e9)
	for p in _patos:
		_pensar(p, alvo, delta)
		_animar(p, delta)


func _pensar(p: Pato, alvo: Vector3, delta: float) -> void:
	var d := Vector2(alvo.x - p.pos.x, alvo.z - p.pos.z).length()
	var perto_dagua := alvo.y < _nivel + 6.0
	p.t -= delta
	p.fase += delta
	match p.estado:
		Estado.NADA, Estado.FOGE:
			if d < DIST_MERGULHO and perto_dagua:
				_mergulhar(p, alvo)
				return
			if d < DIST_FOGE and p.estado == Estado.NADA:
				p.estado = Estado.FOGE
				p.alvo = _ponto(casa, raio, alvo)
			elif d > DIST_FOGE * 1.5 and p.estado == Estado.FOGE:
				p.estado = Estado.NADA
			var vel := VEL_FOGE if p.estado == Estado.FOGE else VEL
			var falta := Vector2(p.alvo.x - p.pos.x, p.alvo.z - p.pos.z)
			if falta.length() > 0.3:
				p.yaw = lerp_angle(p.yaw, atan2(-falta.x, -falta.y), 1.0 - exp(-2.5 * delta))
				var frente := Vector2(-sin(p.yaw), -cos(p.yaw))
				var passo := frente * vel * delta * clampf(frente.dot(falta.normalized()), 0.2, 1.0)
				if _molhado(p.pos.x + passo.x, p.pos.z + passo.y):
					p.pos.x += passo.x
					p.pos.z += passo.y
				else:
					p.alvo = _ponto(casa, raio, Vector3.INF)
			elif p.t <= 0.0:
				if _rng.randf() < 0.3 and p.estado == Estado.NADA:
					_mergulhar(p, Vector3.INF)  # atrás de comida
				else:
					p.alvo = _ponto(p.pos, 6.0, Vector3.INF)
				p.t = _rng.randf_range(3.0, 8.0)
		Estado.MERGULHA:
			p.mergulho = minf(p.mergulho + delta * 2.5, 1.0)
			p.afunda = minf(p.afunda + delta * 1.6, 1.0)
			if p.afunda >= 1.0:
				p.estado = Estado.SUMIDO
				p.raiz.visible = false
				p.t = _rng.randf_range(3.0, 6.0)
		Estado.SUMIDO:
			if p.t <= 0.0:
				# volta à tona longe dali, olhando para fora
				p.pos = p.alvo
				p.yaw = _rng.randf() * TAU
				p.raiz.visible = true
				p.afunda = 0.6
				p.mergulho = 0.0
				p.estado = Estado.NADA
				p.alvo = p.pos
				p.t = _rng.randf_range(2.0, 5.0)
	if p.estado == Estado.NADA or p.estado == Estado.FOGE:
		p.afunda = move_toward(p.afunda, 0.0, delta * 1.5)
	p.pos.y = mapa.agua(p.pos.x, p.pos.z)
	if p.pos.y == -INF:
		p.pos.y = _nivel


func _animar(p: Pato, delta: float) -> void:
	if not p.raiz.visible:
		return
	var nadando := p.estado == Estado.FOGE or Vector2(p.alvo.x - p.pos.x, p.alvo.z - p.pos.z).length() > 0.3
	# a cabeça vai e volta a cada braçada (como pato nadando), mais rápido fugindo
	var ritmo := 7.0 if p.estado == Estado.FOGE else 4.0
	var vai := sin(p.fase * ritmo) * (0.025 if nadando else 0.008)
	p.cabeca.position = Vector3(0, 0.16, -0.17 + vai)
	p.cabeca.rotation.y = sin(p.fase * 0.7) * 0.4 if not nadando else 0.0
	var balanco := sin(p.fase * 1.7) * 0.04
	var pitch := -p.mergulho * 0.9 + sin(p.fase * 2.1) * 0.03
	p.raiz.transform = Transform3D(Basis.from_euler(Vector3(pitch, p.yaw, balanco)), Vector3(p.pos.x, p.pos.y - 0.03 - p.afunda * 0.45 * ESCALA, p.pos.z))


## Quantos estão à tona agora (testes).
func a_tona() -> int:
	var n := 0
	for p in _patos:
		if p.raiz.visible:
			n += 1
	return n
