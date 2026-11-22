class_name Gaivotas
extends Node3D
## Gaivotas planando sobre a praia da ponta leste (terra nova, 2026-11-21): voltas largas e lentas, de asa
## aberta, inclinando nas curvas, com umas batidas de asa de vez em quando. O centro das voltas passeia devagar
## em volta da casa. Só visual. As gaivotas pousadas na areia são um bando de `Passaros` pintado por
## `pintar_gaivota`.
## Uso: Gaivotas.new(), defina mapa, casa, quantos, semente e materiais (a Clareira); depois add_child.

const CENA := "res://assets/vale/passaro.glb"
const ESCALA := 3.0  # o mesmo modelo dos passarinhos, bem maior
const VEL := 7.5
const FREQ := 2.6  # batidas por segundo, quando bate
const AMP := 0.55
const PLANA := 0.12  # a asa aberta um pouco acima da linha do corpo, no planeio
## O passaro.glb é a pose de pousado, de bico 29° para cima; voando, a frente baixa para o corpo ficar reto
const NARIZ := 0.45  # rad
# nomes das peças do modelo e as cores da gaivota: costas e asas cinza, corpo branco, bico amarelo
const ASAS := ["asaE", "asaD"]

var mapa: Vale
var casa := Vector3.ZERO
var quantos := 3
var semente := 0
var materiais: Clareira

var _rng := RandomNumberGenerator.new()
var _aves: Array[Dictionary] = []
var _t := 0.0


## Pinta o modelo do passarinho com as cores da gaivota.
static func pintar_gaivota(no: Node, c: Clareira, na_asa := false) -> void:
	var asa := na_asa or String(no.name) in ASAS
	if no is MeshInstance3D:
		var mi := no as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m == null:
				continue
			var nome := m.resource_name
			match nome:
				"pena":
					nome = "gaivota_dorso" if asa else "gaivota"
				"pena_clara":
					nome = "gaivota"
				"bico":
					nome = "bico_gaivota"
				"pelo_escuro":
					nome = "junta"
			mi.set_surface_override_material(s, c.material(nome))
	for f in no.get_children():
		pintar_gaivota(f, c, asa)


func _ready() -> void:
	if mapa == null or materiais == null:
		push_error("gaivotas: falta o mapa ou os materiais")
		return
	add_to_group("bichos")
	_rng.seed = semente * 3301 + 17
	var cena := load(CENA) as PackedScene
	if cena == null:
		return
	for i in quantos:
		var modelo := cena.instantiate() as Node3D
		modelo.rotation.y = PI  # o modelo olha para +Z; aqui a frente é -Z
		modelo.scale = Vector3.ONE * ESCALA
		var raiz := Node3D.new()
		add_child(raiz)
		raiz.add_child(modelo)
		pintar_gaivota(modelo, materiais)
		var asa_e := modelo.find_child("asaE", true, false) as Node3D
		var asa_d := modelo.find_child("asaD", true, false) as Node3D
		if asa_e == null or asa_d == null:
			raiz.queue_free()
			continue
		Passaros.recolher_pes(modelo.find_child("pernas", true, false) as Node3D, 1.0)  # sempre no ar
		_aves.append({
			"raiz": raiz, "asa_e": asa_e, "asa_d": asa_d, "rot_e": asa_e.rotation, "rot_d": asa_d.rotation,
			"th": _rng.randf() * TAU, "raio": _rng.randf_range(25.0, 60.0), "alt": _rng.randf_range(18.0, 40.0),
			"sentido": 1.0 if _rng.randf() < 0.5 else -1.0, "fase": 0.0, "bate": 0.0,
			"prox": _rng.randf_range(1.0, 8.0), "yaw": 0.0, "roll": 0.0, "pitch": 0.0, "ini": false,
			"centro": Vector2(casa.x, casa.z) + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-40, 40)),
			"vento": _rng.randf() * TAU,
		})


func _process(delta: float) -> void:
	_t += delta
	for a in _aves:
		_voar(a, delta)


func _voar(a: Dictionary, delta: float) -> void:
	var raio: float = a["raio"] + sin(_t * 0.11 + a["vento"]) * 7.0
	var w: float = a["sentido"] * VEL / raio
	a["th"] = a["th"] + w * delta
	# o centro das voltas passeia em volta da casa, devagar
	var ang: float = a["vento"] + _t * 0.017
	var alvo_c := Vector2(casa.x, casa.z) + Vector2(cos(ang), sin(ang * 1.3)) * 70.0
	var c: Vector2 = a["centro"]
	c = c.move_toward(alvo_c, 1.2 * delta)
	a["centro"] = c
	var th: float = a["th"]
	var p := c + Vector2(cos(th), sin(th)) * raio
	var chao := maxf(mapa.altura(p.x, p.y), 0.0)
	var alt: float = a["alt"] + sin(_t * 0.23 + a["vento"] * 2.0) * 4.0
	var pos := Vector3(p.x, chao + alt, p.y)
	var m := Vector2(-sin(th), cos(th)) * float(a["sentido"])
	var yaw := atan2(-m.x, -m.y)
	if not a["ini"]:
		a["yaw"] = yaw
		a["ini"] = true
	var giro := wrapf(yaw - float(a["yaw"]), -PI, PI) / maxf(delta, 0.001)
	a["yaw"] = yaw
	var k := 1.0 - exp(-3.0 * delta)
	a["roll"] = lerpf(a["roll"], clampf(giro * VEL * 0.1, -0.6, 0.6), k)
	# umas batidas de asa de vez em quando, no resto plana
	a["prox"] = a["prox"] - delta
	if a["prox"] <= 0.0:
		a["bate"] = _rng.randf_range(0.8, 1.6)
		a["prox"] = _rng.randf_range(4.0, 10.0) + a["bate"]
	var batendo: bool = a["bate"] > 0.0
	a["bate"] = maxf(0.0, a["bate"] - delta)
	if batendo or absf(sin(a["fase"])) > 0.08:
		a["fase"] = fmod(a["fase"] + TAU * FREQ * delta, TAU)
	var bater: float = AMP * sin(a["fase"]) + PLANA
	var e: Node3D = a["asa_e"]
	var d: Node3D = a["asa_d"]
	e.rotation = a["rot_e"] + Vector3(0.0, 0.0, Passaros.SINAL_BATER_E * bater)
	d.rotation = a["rot_d"] + Vector3(0.0, 0.0, Passaros.SINAL_BATER_D * bater)
	var raiz: Node3D = a["raiz"]
	raiz.global_transform = Transform3D(Basis.from_euler(Vector3(-NARIZ, yaw, a["roll"])), pos)
