class_name MiniRobos
extends Node3D
## Os cinco robozinhos (2026-11-19). Estão escondidos num canto do salão do Sumidouro, parados no escuro: só
## aparecem com a **luz do peito** acesa por perto, e é chegando com ela que o robô os acorda. Aí aparece a
## lembrança deles e eles vão para a base, onde passam a brincar: andam, correm uns atrás dos outros, pulam,
## giram e chutam uma bola pelo pátio. São só de ver (não têm colisão nem atrapalham).
## Quem cria passa `armadura`, `hud`, `memorias`, `pecas` e `mapa`.

const MODELO := "res://assets/vale/robo_v2.glb"
const TAMANHO := 0.42
const CORES := [Color(0.85, 0.2, 0.15), Color(0.95, 0.7, 0.1), Color(0.2, 0.65, 0.3), Color(0.55, 0.3, 0.75), Color(0.1, 0.6, 0.75)]
const VER := 13.0  # com a luz acesa, a essa distância eles aparecem
const ACORDAR := 3.5
const PATIO := Vector3(-2.0, 0.0, -4.6)  # o meio do pátio de brincar, no lugar da base
const PATIO_RAIO := 4.0

var armadura: Armadura
var hud: Hud
var memorias: Memorias
var pecas: PecasMundo
var mapa: Ilha
var achados := false
var no_escuro: Vector3 = Vector3.INF  # onde estão escondidos
var chutes := 0  # testes

var _robos: Array = []  # dicionários: no, juntas, pos, alvo, estado, t, fase, vel, yaw
var _bola: MeshInstance3D
var _bola_vel := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _mats := {}


func _ready() -> void:
	_rng.seed = 5150
	if Guardado.ativo:
		achados = bool((Guardado.progresso("achados") as Dictionary).get("minis", false))
	for i in 6:
		await get_tree().physics_frame
	for k in CORES.size():
		_robos.append(_novo(k))
	if achados:
		_ir_para_a_base()
	else:
		_esconder()


func _novo(k: int) -> Dictionary:
	var no := Node3D.new()
	add_child(no)
	var cena := (load(MODELO) as PackedScene).instantiate() as Node3D
	# sem virar o modelo: aqui a frente de quem anda é +z (corriam de costas)
	cena.scale = Vector3.ONE * TAMANHO
	no.add_child(cena)
	_pintar(cena, CORES[k])
	var j := {}
	for nome: String in ["raiz", "tronco", "cabeca", "quadrilE", "quadrilD", "joelhoE", "joelhoD", "ombroE", "ombroD", "luvaE", "luvaD"]:
		j[nome] = cena.find_child(nome, true, false)
	return {"no": no, "cena": cena, "j": j, "pos": Vector3.ZERO, "alvo": Vector3.ZERO, "estado": "parado", "t": _rng.randf_range(0.5, 2.5),
		"fase": _rng.randf() * TAU, "vel": 0.0, "yaw": _rng.randf() * TAU, "raiz_y": (j["raiz"] as Node3D).position.y if j["raiz"] else 0.0, "caca": -1}


## Pinta o robozinho no estilo do vale: o azul do robô grande vira a cor dele; as chamas somem.
func _pintar(cena: Node, cor: Color) -> void:
	for mi: MeshInstance3D in cena.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("chama") or String(mi.name).begins_with("lamina"):
			mi.visible = false
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null or not (m.resource_name in ["placa_escura", "placa_clara", "detalhe", "bocal", "laranja", "vidro"]):
				continue
			var c := cor if m.resource_name == "detalhe" else m.albedo_color
			var chave := c.to_html()
			if not _mats.has(chave):
				var mt := ShaderMaterial.new()
				mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
				mt.set_shader_parameter("cor", c)
				mt.set_shader_parameter("brilho_borda", 0.18)
				_mats[chave] = mt
			mi.set_surface_override_material(s, _mats[chave])


# ---------------------------------------------------------------- escondidos no Sumidouro

func _esconder() -> void:
	no_escuro = _canto_do_salao()
	if not no_escuro.is_finite():
		# sem o salão (mapas de teste): ficam guardados, fora de vista
		for r: Dictionary in _robos:
			(r["no"] as Node3D).visible = false
		return
	for k in _robos.size():
		var r: Dictionary = _robos[k]
		var ang := k * TAU / 5.0
		var p := no_escuro + Vector3(cos(ang) * 0.75, 0, sin(ang) * 0.75)
		(r["no"] as Node3D).global_position = p
		(r["no"] as Node3D).rotation.y = -ang + PI * 0.5  # em roda, virados para o meio
		_sentar(r, true)
		(r["no"] as Node3D).visible = false


## Um canto do salão longe da memória de lá.
func _canto_do_salao() -> Vector3:
	if not Sumidouro.existe:
		return Vector3.INF
	var esp := get_world_3d().direct_space_state
	var perp := Vector2(-Sumidouro.dir.y, Sumidouro.dir.x)
	var longe: Vector3 = memorias.onde.get("sumidouro", Vector3.INF) if memorias else Vector3.INF
	for t: Vector2 in [Vector2(-14, 9), Vector2(-14, -9), Vector2(-10, -6), Vector2(-10, 6), Vector2(-18, 0), Vector2(9, -10), Vector2(9, 10), Vector2(16, 0)]:
		var xz := Sumidouro.centro + Sumidouro.dir * t.x + perp * t.y
		var de := Vector3(xz.x, Sumidouro.piso + 5.0, xz.y)
		if not Sumidouro.no_vazio(de):
			continue
		var chao := esp.intersect_ray(PhysicsRayQueryParameters3D.create(de, de + Vector3(0, -9.0, 0), 1))
		if chao.is_empty():
			continue
		var p: Vector3 = chao["position"]
		if absf(p.y - Sumidouro.piso) > 1.5 or (longe.is_finite() and p.distance_to(longe) < 7.0):
			continue
		return p
	return Vector3.INF


func _sentar(r: Dictionary, sim: bool) -> void:
	var j: Dictionary = r["j"]
	for lado: String in ["E", "D"]:
		if j["quadril" + lado]:
			(j["quadril" + lado] as Node3D).rotation = Vector3(deg_to_rad(-88.0) if sim else 0.0, 0, 0)
		if j["joelho" + lado]:
			(j["joelho" + lado] as Node3D).rotation = Vector3(deg_to_rad(8.0) if sim else 0.0, 0, 0)
	if j["cabeca"]:
		(j["cabeca"] as Node3D).rotation = Vector3(deg_to_rad(22.0) if sim else 0.0, 0, 0)  # cabeça baixa, dormindo
	if j["raiz"]:
		(j["raiz"] as Node3D).position.y = float(r["raiz_y"]) - (0.36 if sim else 0.0)


func _acordar() -> void:
	achados = true
	if Guardado.ativo:
		var d: Dictionary = (Guardado.progresso("achados") as Dictionary).duplicate()
		d["minis"] = true
		Guardado.por_progresso("achados", d)
	_ir_para_a_base()
	if hud:
		hud.avisar("Cinco robozinhos acordaram", "eles foram correndo para a base")
	if memorias:
		memorias.abrir("robozinhos")


# ---------------------------------------------------------------- brincando na base

## O chão do pátio: o terreno, ou o tampo da laje da base onde ela cobre o terreno.
func _chao(x: float, z: float) -> float:
	var y := mapa.altura(x, z)
	var l: Vector3 = BaseVale.t_base.affine_inverse() * Vector3(x, y, z)
	if l.z > -5.2 and l.z < 7.2 and absf(l.x + 1.0) < 10.4:
		y = maxf(y, BaseVale.t_base.origin.y + 0.1)
	return y


func _ponto_do_patio() -> Vector3:
	var ang := _rng.randf() * TAU
	var d := sqrt(_rng.randf()) * PATIO_RAIO
	var p: Vector3 = BaseVale.t_base * (PATIO + Vector3(cos(ang) * d, 0, sin(ang) * d))
	p.y = _chao(p.x, p.z)
	return p


func _ir_para_a_base() -> void:
	for r: Dictionary in _robos:
		_sentar(r, false)
		r["pos"] = _ponto_do_patio()
		r["alvo"] = r["pos"]
		r["estado"] = "parado"
		(r["no"] as Node3D).visible = true
		(r["no"] as Node3D).global_position = r["pos"]
	if _bola == null:
		_bola = MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.16
		esfera.height = 0.32
		_bola.mesh = esfera
		var mb := ShaderMaterial.new()
		mb.shader = load("res://scripts/shaders/vale_solido.gdshader")
		mb.set_shader_parameter("cor", Color(0.95, 0.45, 0.1))
		_bola.material_override = mb
		add_child(_bola)
		_bola.global_position = _ponto_do_patio() + Vector3(0, 0.16, 0)


func _process(delta: float) -> void:
	if _robos.is_empty() or armadura == null:
		return
	if not achados:
		if not no_escuro.is_finite():
			return
		var d := armadura.global_position.distance_to(no_escuro)
		var aceso: bool = armadura.luz_ligada and d < VER
		for r: Dictionary in _robos:
			(r["no"] as Node3D).visible = aceso
		if aceso and d < ACORDAR and not get_tree().paused:
			_acordar()
		return
	_brincar(delta)


func _brincar(delta: float) -> void:
	# a bola rola e para; não sai do pátio
	if _bola:
		var pb := _bola.global_position + _bola_vel * delta
		_bola_vel = _bola_vel * exp(-1.4 * delta)
		var meio: Vector3 = BaseVale.t_base * PATIO
		var fora := Vector2(pb.x - meio.x, pb.z - meio.z)
		if fora.length() > PATIO_RAIO:
			var n := fora.normalized()
			_bola_vel = _bola_vel.bounce(Vector3(n.x, 0, n.y)) * 0.7
			pb = Vector3(meio.x + n.x * PATIO_RAIO, pb.y, meio.z + n.y * PATIO_RAIO)
		pb.y = _chao(pb.x, pb.z) + 0.16
		_bola.global_position = pb
		_bola.rotate_x(_bola_vel.length() * delta * 5.0)
	for k in _robos.size():
		var r: Dictionary = _robos[k]
		r["t"] = float(r["t"]) - delta
		var pos: Vector3 = r["pos"]
		var pulo := 0.0
		match String(r["estado"]):
			"parado":
				r["vel"] = 0.0
				if float(r["t"]) <= 0.0:
					_escolher(r, k)
			"andar", "bola", "caca":
				var alvo: Vector3 = r["alvo"]
				if String(r["estado"]) == "bola" and _bola:
					alvo = _bola.global_position
				elif String(r["estado"]) == "caca" and int(r["caca"]) >= 0:
					alvo = (_robos[int(r["caca"])] as Dictionary)["pos"]
				var para := Vector3(alvo.x - pos.x, 0, alvo.z - pos.z)
				var corre: bool = String(r["estado"]) != "andar"
				r["vel"] = move_toward(float(r["vel"]), 2.6 if corre else 1.3, delta * 5.0)
				if para.length() > 0.05:
					r["yaw"] = lerp_angle(float(r["yaw"]), atan2(para.x, para.z), 1.0 - exp(-7.0 * delta))
					pos += Vector3(sin(float(r["yaw"])), 0, cos(float(r["yaw"]))) * float(r["vel"]) * delta
				var chegou := para.length() < (0.32 if String(r["estado"]) != "caca" else 0.55)
				if chegou and String(r["estado"]) == "bola" and _bola:
					# chute: a bola sai na direção em que ele vinha, com um desvio
					var ang := float(r["yaw"]) + _rng.randf_range(-0.5, 0.5)
					_bola_vel = Vector3(sin(ang), 0, cos(ang)) * _rng.randf_range(3.0, 5.0)
					chutes += 1
				if chegou or float(r["t"]) <= 0.0:
					r["estado"] = "pular" if (chegou and _rng.randf() < 0.45) else "parado"
					r["t"] = _rng.randf_range(0.6, 1.6)
			"pular":
				r["vel"] = 0.0
				pulo = absf(sin(float(r["t"]) * 9.0)) * 0.22
				if float(r["t"]) <= 0.0:
					r["estado"] = "parado"
					r["t"] = _rng.randf_range(0.3, 1.2)
			"girar":
				r["vel"] = 0.0
				r["yaw"] = float(r["yaw"]) + delta * 7.0
				if float(r["t"]) <= 0.0:
					r["estado"] = "parado"
					r["t"] = _rng.randf_range(0.4, 1.4)
		pos.y = _chao(pos.x, pos.z)
		r["pos"] = pos
		var no := r["no"] as Node3D
		no.global_position = pos + Vector3(0, pulo, 0)
		no.rotation.y = float(r["yaw"])
		_passada(r, delta)


func _escolher(r: Dictionary, k: int) -> void:
	var sorte := _rng.randf()
	if sorte < 0.34:
		r["estado"] = "bola"
		r["t"] = 6.0
	elif sorte < 0.56:
		r["estado"] = "caca"
		r["caca"] = (k + 1 + _rng.randi() % (_robos.size() - 1)) % _robos.size()
		r["t"] = _rng.randf_range(2.5, 4.5)
	elif sorte < 0.84:
		r["estado"] = "andar"
		r["alvo"] = _ponto_do_patio()
		r["t"] = 7.0
	elif sorte < 0.93:
		r["estado"] = "girar"
		r["t"] = _rng.randf_range(0.8, 1.6)
	else:
		r["estado"] = "pular"
		r["t"] = 1.0


## As pernas e os braços balançam com o passo; parado, o corpo respira.
func _passada(r: Dictionary, delta: float) -> void:
	var j: Dictionary = r["j"]
	var v := float(r["vel"])
	r["fase"] = float(r["fase"]) + delta * (4.0 + v * 4.5)
	var amp := clampf(v / 2.6, 0.0, 1.0) * 0.75
	var s := sin(float(r["fase"]))
	for par: Array in [["E", 1.0], ["D", -1.0]]:
		var lado: String = par[0]
		var sinal: float = par[1]
		if j["quadril" + lado]:
			(j["quadril" + lado] as Node3D).rotation.x = -s * amp * sinal
		if j["joelho" + lado]:
			(j["joelho" + lado] as Node3D).rotation.x = maxf(0.0, s * sinal) * amp * 0.9
		if j["ombro" + lado]:
			(j["ombro" + lado] as Node3D).rotation.x = s * amp * sinal * 0.8
	if j["raiz"]:
		(j["raiz"] as Node3D).position.y = float(r["raiz_y"]) + absf(s) * amp * 0.03
