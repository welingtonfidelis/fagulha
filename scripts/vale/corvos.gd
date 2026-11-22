class_name Corvos
extends Node3D
## Um casal de corvos da Montanha do Degelo (terra nova, 2026-11-22, doc §137.14): um em volta do pico, um no
## Vilarejo, um na beira do lago do circo. Pousam nas pedras altas e nos telhados, dão uns pulinhos, olham em volta e
## grasnam (o corpo inteiro dá um tranco para a frente). De tempos em tempos, ou com o robô chegando, levantam voo
## juntos, planam em voltas largas com umas batidas de asa e, às vezes, um deles dá uma cambalhota no ar; depois
## descem planando para outro poleiro. Só visual: sem física nem colisão.
## Uso: Corvos.new(), defina mapa, ameaca, casa, poleiros_xz (onde podem pousar: o alto de cada ponto vem de um raio
## de cima para baixo, então telhado também serve), semente e materiais (a Clareira); depois add_child.

enum Estado { POUSADOS, VOANDO, POUSANDO }

const CENA := "res://assets/vale/corvo.glb"
const ESCALA := 2.6
const VEL := 8.5
const DIST_VOA := 15.0  # o robô mais perto que isso faz o casal voar
const DIST_VOA_RAPIDO := 30.0  # ... e mais perto que isso, se estiver rápido
const VEL_RAPIDA := 8.0
const FREQ := 3.2  # batidas por segundo
const AMP := 0.75
const DOBRA := 1.48
const ENCOLHE := 0.4  # a asa fechada estreita (o eixo z do modelo é a largura dela): faixa junto do corpo

var mapa: Vale
var ameaca: Node3D
var casa := Vector3.ZERO
var poleiros_xz: Array[Vector2] = []
var semente := 0
var materiais: Clareira
var estado := Estado.POUSADOS
var decolagens := 0  # testes
var cambalhotas := 0  # testes

var _rng := RandomNumberGenerator.new()
var _poleiros: Array[Vector3] = []
var _aves: Array[Corvo] = []
var _t := 0.0  # tempo até a próxima mudança do casal
var _centro := Vector2.ZERO  # o meio das voltas
var _pronto := false


class Corvo:
	var raiz: Node3D
	var corpo: Node3D
	var asa_e: Node3D
	var asa_d: Node3D
	var pernas: Node3D
	var pes := 0.0  # 0 no poleiro, 1 recolhidos no voo
	var rot_corpo := Vector3.ZERO
	var rot_e := Vector3.ZERO
	var rot_d := Vector3.ZERO
	var pos := Vector3.ZERO
	var poleiro := Vector3.ZERO
	var yaw := 0.0
	var vh := 0.0
	var vy := 0.0
	var giro := 0.0
	var pitch := 0.0
	var roll := 0.0
	var voo := false
	var atraso := 0.0
	var th := 0.0  # onde está na volta
	var sentido := 1.0
	var alt := 20.0
	var fase := 0.0
	var bate := 0.0  # segundos de batida que faltam
	var prox_bate := 2.0
	var dobra := 1.0
	var amp := 0.0
	var cambalhota := 0.0  # 0 a TAU, girando
	var prox := 1.0  # próxima ação pousado
	var grasna := 0.0
	var pulo := 0.0
	var yaw_alvo := 0.0


func _ready() -> void:
	if mapa == null or materiais == null:
		push_error("corvos: falta o mapa ou os materiais")
		return
	_rng.seed = semente * 2381 + 41
	var cena := load(CENA) as PackedScene
	if cena == null:
		push_error("corvos: modelo não encontrado em %s" % CENA)
		return
	for i in 2:
		var a := Corvo.new()
		a.raiz = BichoFicha.nova("corvo", self, 0.35)
		add_child(a.raiz)
		var modelo := cena.instantiate() as Node3D
		modelo.rotation.y = PI  # o modelo olha para +Z; aqui a frente é -Z
		modelo.scale = Vector3.ONE * ESCALA
		a.raiz.add_child(modelo)
		_pintar(modelo)
		a.corpo = modelo.find_child("corpo", true, false) as Node3D
		a.asa_e = modelo.find_child("asaE", true, false) as Node3D
		a.asa_d = modelo.find_child("asaD", true, false) as Node3D
		a.pernas = modelo.find_child("pernas", true, false) as Node3D
		if a.corpo == null or a.asa_e == null or a.asa_d == null:
			a.raiz.queue_free()
			continue
		a.rot_corpo = a.corpo.rotation
		a.rot_e = a.asa_e.rotation
		a.rot_d = a.asa_d.rotation
		a.yaw = _rng.randf() * TAU
		a.yaw_alvo = a.yaw
		a.prox = _rng.randf_range(0.5, 3.0)
		a.raiz.visible = false  # até achar os poleiros
		_aves.append(a)
	_centro = Vector2(casa.x, casa.z)
	_t = _rng.randf_range(20.0, 50.0)


func _pintar(no: Node) -> void:
	if no is MeshInstance3D:
		var mi := no as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m:
				mi.set_surface_override_material(s, materiais.material(m.resource_name))
	for f in no.get_children():
		_pintar(f)


## Os poleiros: o alto de cada ponto, por um raio de cima (telhado, pedra), só onde dá para pousar.
func _achar_poleiros() -> void:
	var espaco := get_world_3d().direct_space_state
	for q in poleiros_xz:
		var chao := mapa.altura(q.x, q.y)
		var y := chao
		var raio := PhysicsRayQueryParameters3D.create(Vector3(q.x, chao + 60.0, q.y), Vector3(q.x, chao - 2.0, q.y), 1)
		var bate := espaco.intersect_ray(raio)
		if not bate.is_empty():
			var n: Vector3 = bate["normal"]
			var alto := float((bate["position"] as Vector3).y)
			if n.y < 0.8 or alto - chao > 14.0:
				continue
			y = alto
		elif mapa.normal_em(q.x, q.y).y < 0.75:
			continue
		_poleiros.append(Vector3(q.x, y, q.y))
	if _poleiros.is_empty():
		_poleiros.append(Vector3(casa.x, mapa.altura(casa.x, casa.z), casa.z))
	# começam pousados, os dois no mesmo poleiro ou em dois vizinhos
	var i := _rng.randi() % _poleiros.size()
	for k in _aves.size():
		var a := _aves[k]
		a.poleiro = _poleiro_par(i, k)
		a.pos = a.poleiro
		a.raiz.visible = true
	_pronto = true


## O poleiro do corvo `k` do casal quando o casal escolhe o poleiro `i`: o segundo fica no vizinho mais perto (até
## 9 m) ou ao lado do primeiro.
func _poleiro_par(i: int, k: int) -> Vector3:
	var p := _poleiros[i]
	if k == 0:
		return p
	var melhor := -1
	var md := 9.0
	for j in _poleiros.size():
		var d := _poleiros[j].distance_to(p)
		if j != i and d < md:
			md = d
			melhor = j
	if melhor >= 0:
		return _poleiros[melhor]
	var q := p + Vector3(1.1, 0, 0.5)
	var chao := mapa.altura(p.x, p.z)
	if absf(p.y - chao) < 0.3:
		q.y = mapa.altura(q.x, q.z)  # poleiro no chão: o vizinho acompanha a encosta (num telhado, fica no telhado)
	return q


func _physics_process(_delta: float) -> void:
	if not _pronto and not _aves.is_empty():
		_achar_poleiros()


# ---------------------------------------------------------------- o casal

func assustar(ponto: Vector3) -> void:
	if _pronto and estado == Estado.POUSADOS and Vector2(ponto.x - casa.x, ponto.z - casa.z).length() < 90.0:
		_decolar()


func _decolar() -> void:
	estado = Estado.VOANDO
	decolagens += 1
	_t = _rng.randf_range(18.0, 40.0)
	var sentido := 1.0 if _rng.randf() < 0.5 else -1.0
	for k in _aves.size():
		var a := _aves[k]
		a.voo = false
		a.atraso = 0.05 + k * _rng.randf_range(0.3, 1.0)
		a.alt = _rng.randf_range(16.0, 30.0)
		a.th = atan2(a.pos.z - _centro.y, a.pos.x - _centro.x)
		a.sentido = sentido
		a.vh = 3.0
		a.vy = 3.0


func _pousar_casal() -> void:
	estado = Estado.POUSANDO
	var p := _ameaca_pos()
	var escolha := -1
	for k in 10:
		var i := _rng.randi() % _poleiros.size()
		if Vector2(_poleiros[i].x - p.x, _poleiros[i].z - p.z).length() > 30.0:
			escolha = i
			break
	if escolha < 0:
		_t = _rng.randf_range(10.0, 20.0)  # o robô está em todo canto: mais umas voltas
		estado = Estado.VOANDO
		return
	for k in _aves.size():
		_aves[k].poleiro = _poleiro_par(escolha, k)


func _ameaca_pos() -> Vector3:
	return ameaca.global_position if is_instance_valid(ameaca) else Vector3(1e9, 0, 1e9)


func _process(delta: float) -> void:
	if not _pronto:
		return
	_t -= delta
	var am := _ameaca_pos()
	match estado:
		Estado.POUSADOS:
			var vel := 0.0
			var v: Variant = ameaca.get("velocity") if is_instance_valid(ameaca) else null
			if v is Vector3:
				vel = (v as Vector3).length()
			var d := 1e9
			for a in _aves:
				d = minf(d, Vector2(am.x - a.pos.x, am.z - a.pos.z).length())
			if d < DIST_VOA or (d < DIST_VOA_RAPIDO and vel > VEL_RAPIDA) or _t <= 0.0:
				_decolar()
		Estado.VOANDO:
			# o meio das voltas passeia devagar em volta da casa
			var ang := Time.get_ticks_msec() * 0.00002 + semente
			var alvo_c := Vector2(casa.x, casa.z) + Vector2(cos(ang), sin(ang * 1.3)) * 30.0
			_centro = _centro.move_toward(alvo_c, 2.0 * delta)
			if _t <= 0.0:
				_pousar_casal()
		Estado.POUSANDO:
			var todos := true
			for a in _aves:
				if a.voo:
					todos = false
			if todos:
				estado = Estado.POUSADOS
				_t = _rng.randf_range(25.0, 70.0)
	for a in _aves:
		if a.voo:
			_voar(a, delta)
		elif estado != Estado.POUSADOS and a.atraso > 0.0:
			a.atraso -= delta
			if a.atraso <= 0.0:
				a.voo = true
		else:
			_pousado(a, delta)
		_animar(a, delta)


func _voar(a: Corvo, delta: float) -> void:
	var sentido := a.sentido
	var chao := mapa.altura(a.pos.x, a.pos.z)
	if estado == Estado.POUSANDO:
		var d := Vector2(a.poleiro.x - a.pos.x, a.poleiro.z - a.pos.z)
		var dist := d.length()
		var err := wrapf(atan2(-d.x, -d.y) - a.yaw, -PI, PI)
		var wmax := 1.1 if dist > 6.0 else 3.0
		a.giro = clampf(err * 1.8, -wmax, wmax)
		a.vh = clampf(dist * 0.5, 1.5, VEL)
		var alvo_y := a.poleiro.y + (minf(dist * 0.35, a.alt) if dist > 1.0 else 0.0)
		a.vy = clampf((alvo_y - a.pos.y) * 1.8, -5.0, 4.0)
		if dist < 0.8 and absf(a.pos.y - a.poleiro.y) < 0.25:
			a.voo = false
			a.pos = a.poleiro
			a.vh = 0.0
			a.vy = 0.0
			a.giro = 0.0
			a.prox = _rng.randf_range(0.5, 2.0)
			a.yaw_alvo = a.yaw
			return
	else:
		# a volta: mira um ponto um pouco adiante no círculo
		var raio := 26.0 + sin(a.th * 0.5 + semente) * 6.0
		a.th += sentido * VEL / raio * delta
		var alvo := _centro + Vector2(cos(a.th + sentido * 0.5), sin(a.th + sentido * 0.5)) * raio
		var d := alvo - Vector2(a.pos.x, a.pos.z)
		var err := wrapf(atan2(-d.x, -d.y) - a.yaw, -PI, PI)
		a.giro = clampf(err * 1.5, -1.2, 1.2)
		a.vh = move_toward(a.vh, VEL, 3.0 * delta)
		var base := maxf(chao, a.poleiro.y)
		a.vy = clampf((base + a.alt - a.pos.y) * 0.9, -4.0, 4.5)
		# de vez em quando, uma cambalhota (o corvo gira inteiro de lado e volta)
		if a.cambalhota <= 0.0 and _rng.randf() < delta * 0.025:
			a.cambalhota = 0.001
			cambalhotas += 1
	a.yaw += a.giro * delta
	a.pos.x += -sin(a.yaw) * a.vh * delta
	a.pos.z += -cos(a.yaw) * a.vh * delta
	a.pos.y += a.vy * delta
	a.pos.y = maxf(a.pos.y, mapa.altura(a.pos.x, a.pos.z) + (0.0 if estado == Estado.POUSANDO else 1.5))
	if a.cambalhota > 0.0:
		a.cambalhota += delta * TAU / 1.1
		if a.cambalhota >= TAU:
			a.cambalhota = 0.0


func _pousado(a: Corvo, delta: float) -> void:
	a.pos = a.poleiro + Vector3(0, sin(PI * clampf(a.pulo / 0.35, 0.0, 1.0)) * 0.15, 0)
	a.pulo = maxf(a.pulo - delta, 0.0)
	a.grasna = maxf(a.grasna - delta, 0.0)
	a.prox -= delta
	if a.prox <= 0.0:
		var r := _rng.randf()
		if r < 0.3:
			a.grasna = 0.9  # três trancos rápidos
		elif r < 0.55:
			a.pulo = 0.35
			a.yaw_alvo = a.yaw + _rng.randf_range(-1.5, 1.5)
		else:
			a.yaw_alvo = a.yaw + _rng.randf_range(-0.8, 0.8)
		a.prox = _rng.randf_range(1.5, 4.0)
	a.yaw = lerp_angle(a.yaw, a.yaw_alvo, 1.0 - exp(-5.0 * delta))


func _animar(a: Corvo, delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	var plana := true
	if a.voo:
		a.prox_bate -= delta
		if a.prox_bate <= 0.0:
			a.bate = _rng.randf_range(0.8, 2.0)
			a.prox_bate = _rng.randf_range(3.0, 8.0) + a.bate
		a.bate = maxf(a.bate - delta, 0.0)
		plana = a.bate <= 0.0 and a.vy < 1.5 and not (estado == Estado.POUSANDO and Vector2(a.poleiro.x - a.pos.x, a.poleiro.z - a.pos.z).length() < 4.0)
	var batendo := a.voo and not plana
	if batendo or absf(sin(a.fase)) > 0.1:
		a.fase = fmod(a.fase + TAU * FREQ * delta, TAU)
	a.amp = lerpf(a.amp, AMP if batendo else 0.0, k)
	a.dobra = lerpf(a.dobra, 0.0 if a.voo else 1.0, k)
	# os pés: recolhidos no voo, baixados uns metros antes do poleiro
	var chegando := estado == Estado.POUSANDO and Vector2(a.poleiro.x - a.pos.x, a.poleiro.z - a.pos.z).length() < 5.0
	a.pes = lerpf(a.pes, 1.0 if a.voo and not chegando else 0.0, 1.0 - exp(-6.0 * delta))
	Passaros.recolher_pes(a.pernas, a.pes)
	var bater := a.amp * sin(a.fase) + (0.08 if a.voo else 0.0)
	a.asa_e.rotation = a.rot_e + Vector3(0.0, Passaros.SINAL_DOBRA_E * a.dobra * DOBRA, Passaros.SINAL_BATER_E * bater)
	a.asa_d.rotation = a.rot_d + Vector3(0.0, Passaros.SINAL_DOBRA_D * a.dobra * DOBRA, Passaros.SINAL_BATER_D * bater)
	var esc := Vector3(lerpf(1.0, 0.85, a.dobra), 1.0, lerpf(1.0, ENCOLHE, a.dobra))
	a.asa_e.scale = esc
	a.asa_d.scale = esc
	var tranco := sin(a.grasna * TAU * 3.3) * 0.25 if a.grasna > 0.0 else 0.0
	a.corpo.rotation = a.rot_corpo + Vector3(-absf(tranco), 0, 0)
	var pitch_alvo := clampf(atan2(a.vy, maxf(a.vh, 0.1)), -0.5, 0.5) - Gaivotas.NARIZ if a.voo else 0.0
	var roll_alvo := clampf(a.giro * a.vh * 0.1, -0.6, 0.6) if a.voo else 0.0
	a.pitch = lerpf(a.pitch, pitch_alvo, k)
	a.roll = lerpf(a.roll, roll_alvo, k)
	a.raiz.global_transform = Transform3D(Basis.from_euler(Vector3(a.pitch, a.yaw, a.roll + a.cambalhota)), a.pos)


## Quantos estão voando agora (testes).
func no_ar() -> int:
	var n := 0
	for a in _aves:
		if a.voo:
			n += 1
	return n
