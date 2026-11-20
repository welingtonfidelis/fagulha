class_name MiniRobos
extends Node3D
## Os cinco robozinhos (2026-11-19). Estão escondidos num canto do salão do Sumidouro, parados no escuro: só
## aparecem com a **luz do peito** acesa por perto, e é chegando com ela que o robô os acorda. Aí aparece a
## lembrança deles e eles vão para a base, onde passam a brincar: andam, correm uns atrás dos outros, pulam,
## giram e chutam uma bola pelo pátio. De vez em quando um vai jogar videogame (2026-11-20): sobe no banquinho
## da bancada e joga na TV de tubo, ou senta no sofá ou na poltrona com um portátil (BaseLar.lugares_minis).
## São só de ver (não têm colisão nem atrapalham).
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
var partidas := 0  # testes: quantas vezes um robozinho sentou para jogar
## Jogar videogame é de vez em quando, e no máximo dois ao mesmo tempo (pedido do usuário, 2026-11-20: eles
## jogavam demais). Eram 16% a cada escolha, sem limite e sem intervalo; agora, depois de um sair para jogar,
## nenhum outro sai antes de JOGAR_INTERVALO segundos.
const JOGAR_CHANCE := 0.04
const JOGANDO_MAX := 2
const JOGAR_INTERVALO := Vector2(35.0, 70.0)
var _jogar_espera := 20.0

var _robos: Array = []  # dicionários: no, juntas, pos, alvo, estado, t, fase, vel, yaw
var _bola: MeshInstance3D
var _bola_vel := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _quadro_tv := 0.0
var _portatil: PackedScene


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
	# colega: o tiro não sai com ele na mira (Tiro), e o scanner o reconhece
	no.add_to_group("amigos")
	no.set_meta("robozinho", true)
	no.set_meta("meio_altura", 0.25)
	no.set_meta("levou_mira", _levou_mira)
	var cena := (load(MODELO) as PackedScene).instantiate() as Node3D
	# sem virar o modelo: aqui a frente de quem anda é +z (corriam de costas)
	cena.scale = Vector3.ONE * TAMANHO
	no.add_child(cena)
	_pintar(cena, CORES[k])
	var j := {}
	for nome: String in ["raiz", "tronco", "cabeca", "quadrilE", "quadrilD", "joelhoE", "joelhoD", "ombroE", "ombroD", "cotoveloE", "cotoveloD", "luvaE", "luvaD"]:
		j[nome] = cena.find_child(nome, true, false)
	return {"no": no, "cena": cena, "j": j, "pos": Vector3.ZERO, "alvo": Vector3.ZERO, "estado": "parado", "t": _rng.randf_range(0.5, 2.5),
		"fase": _rng.randf() * TAU, "vel": 0.0, "yaw": _rng.randf() * TAU, "raiz_y": (j["raiz"] as Node3D).position.y if j["raiz"] else 0.0, "caca": -1,
		"lugar": -1, "rota": [], "de": Vector3.ZERO, "aparelho": null, "susto": 0.0}


## O robô apontou a arma para um deles (o tiro não sai, como com o drone colega): leva um susto, pula com
## os braços para cima, balança a cabeça e reclama com bipes. Sentado jogando, só levanta os braços.
const SUSTO := 1.0
var sustos := 0  # testes


func _levou_mira(no: Node3D) -> void:
	for r: Dictionary in _robos:
		if r["no"] != no or float(r["susto"]) > 0.0:
			continue
		r["susto"] = SUSTO
		sustos += 1
		Som.toque3d(no, Som.variacao("drone", 6), no.global_position + Vector3(0, 0.3, 0), -9.0, 5.0, 30.0)
		if not String(r["estado"]) in ESTADOS_JOGO:
			r["estado"] = "parado"
			r["t"] = SUSTO + 0.3
			r["vel"] = 0.0


func _susto(r: Dictionary, delta: float) -> void:
	var s := float(r["susto"])
	if s <= 0.0:
		return
	s = maxf(0.0, s - delta)
	r["susto"] = s
	var j: Dictionary = r["j"]
	var no := r["no"] as Node3D
	var f := 1.0 - s / SUSTO
	var forca := sin(f * PI)
	var sentado := String(r["estado"]) in ESTADOS_JOGO
	if not sentado:
		# pulinho no começo e vira para quem apontou
		no.global_position.y += maxf(0.0, sin(f * PI * 3.0)) * 0.14 * (1.0 - f)
		if armadura:
			var para := armadura.global_position - no.global_position
			r["yaw"] = lerp_angle(float(r["yaw"]), atan2(para.x, para.z), 1.0 - exp(-10.0 * delta))
			no.rotation.y = float(r["yaw"])
	for par: Array in [["E", 1.0], ["D", -1.0]]:
		var lado: String = par[0]
		var sinal: float = par[1]
		if j["ombro" + lado]:
			var o := j["ombro" + lado] as Node3D
			o.rotation = o.rotation.lerp(Vector3(deg_to_rad(-150.0), 0, deg_to_rad(-20.0) * sinal), forca)
		if j["cotovelo" + lado]:
			var c := j["cotovelo" + lado] as Node3D
			c.rotation = c.rotation.lerp(Vector3(deg_to_rad(-25.0), 0, 0), forca)
	if j["cabeca"]:
		(j["cabeca"] as Node3D).rotation.y = sin(f * 22.0) * 0.45 * forca  # "não, não"
	if s <= 0.0 and not sentado:
		# acabou: os braços e a cabeça voltam (andando, a passada cuida dos ombros)
		for nome: String in ["ombroE", "ombroD", "cotoveloE", "cotoveloD", "cabeca"]:
			if j[nome]:
				(j[nome] as Node3D).rotation = Vector3.ZERO


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
		if Vector2(l.x, l.z).length() < 2.9:
			y = maxf(y, BaseVale.t_base.origin.y + 0.19)  # o estrado redondo de nascer
	return y


func _ponto_do_patio() -> Vector3:
	var ang := _rng.randf() * TAU
	var d := sqrt(_rng.randf()) * PATIO_RAIO
	var p: Vector3 = BaseVale.t_base * (PATIO + Vector3(cos(ang) * d, 0, sin(ang) * d))
	p.y = _chao(p.x, p.z)
	return p


func _ir_para_a_base() -> void:
	if is_instance_valid(BaseLar.giz):
		BaseLar.giz.visible = true  # a amarelinha é deles
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
	_animar_tv(delta)
	_jogar_espera = maxf(0.0, _jogar_espera - delta)
	for k in _robos.size():
		var r: Dictionary = _robos[k]
		r["t"] = float(r["t"]) - delta
		var pos: Vector3 = r["pos"]
		var pulo := 0.0
		if _jogando(r, delta):
			_susto(r, delta)
			continue
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
		_susto(r, delta)


func _escolher(r: Dictionary, k: int) -> void:
	if _rng.randf() < JOGAR_CHANCE and _ir_jogar(r):
		return
	var sorte := _rng.randf()
	if sorte < 0.34:
		r["estado"] = "bola"
		r["t"] = 6.0
	elif sorte < 0.56:
		r["estado"] = "caca"
		r["caca"] = (k + 1 + _rng.randi() % (_robos.size() - 1)) % _robos.size()
		r["t"] = _rng.randf_range(2.5, 4.5)
		if String((_robos[int(r["caca"])] as Dictionary)["estado"]) in ESTADOS_JOGO:
			r["estado"] = "andar"  # quem está jogando não brinca de pega
			r["alvo"] = _ponto_do_patio()
			r["t"] = 7.0
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


# ---------------------------------------------------------------- jogando videogame

const ESTADOS_JOGO := ["ir", "subir", "jogar", "descer", "voltar"]


## Escolhe um lugar livre (banquinho da TV, sofá ou poltrona) e sai andando para lá.
func _ir_jogar(r: Dictionary) -> bool:
	if _jogar_espera > 0.0:
		return false
	var jogando := 0
	for o: Dictionary in _robos:
		if String(o["estado"]) in ESTADOS_JOGO:
			jogando += 1
	if jogando >= JOGANDO_MAX:
		return false
	var livres: Array = []
	for i in BaseLar.lugares_minis.size():
		var ocupado := false
		for o: Dictionary in _robos:
			if int(o["lugar"]) == i and String(o["estado"]) in ESTADOS_JOGO:
				ocupado = true
		if not ocupado:
			livres.append(i)
	if livres.is_empty():
		return false
	var i: int = livres[_rng.randi() % livres.size()]
	var l: Dictionary = BaseLar.lugares_minis[i]
	r["lugar"] = i
	r["rota"] = (l["via"] as Array).duplicate() + [l["pe"]]
	r["estado"] = "ir"
	r["t"] = 40.0
	_jogar_espera = _rng.randf_range(JOGAR_INTERVALO.x, JOGAR_INTERVALO.y)
	return true


## Os estados de quem foi jogar: anda pelo caminho, sobe no móvel, joga, desce e volta ao pátio. Devolve
## false se o robozinho não está nisso (aí segue a brincadeira comum).
func _jogando(r: Dictionary, delta: float) -> bool:
	var est := String(r["estado"])
	if not est in ESTADOS_JOGO:
		return false
	var no := r["no"] as Node3D
	var pos: Vector3 = r["pos"]
	var l: Dictionary = BaseLar.lugares_minis[int(r["lugar"])] if int(r["lugar"]) >= 0 else {}
	var frente: Vector3 = l.get("frente", Vector3.FORWARD)
	var yaw_sentado := atan2(frente.x, frente.z)
	match est:
		"ir", "voltar":
			var rota: Array = r["rota"]
			if rota.is_empty() or float(r["t"]) <= 0.0:
				if est == "ir" and not rota.is_empty():
					rota.clear()  # demorou demais: desiste
					r["estado"] = "voltar"
					r["rota"] = [_ponto_do_patio()]
					r["t"] = 30.0
					return true
				if est == "ir":
					r["estado"] = "subir"
					r["t"] = 0.5
					r["de"] = pos
				else:
					r["estado"] = "parado"
					r["lugar"] = -1
					r["t"] = _rng.randf_range(0.4, 1.2)
				return true
			var alvo: Vector3 = rota[0]
			var para := Vector3(alvo.x - pos.x, 0, alvo.z - pos.z)
			r["vel"] = move_toward(float(r["vel"]), 1.5, delta * 5.0)
			if para.length() > 0.05:
				r["yaw"] = lerp_angle(float(r["yaw"]), atan2(para.x, para.z), 1.0 - exp(-9.0 * delta))
				pos += para.normalized() * minf(float(r["vel"]) * delta, para.length())
			if para.length() < 0.12:
				rota.pop_front()
			pos.y = _chao(pos.x, pos.z)
			r["pos"] = pos
			no.global_position = pos
			no.rotation.y = float(r["yaw"])
			_passada(r, delta)
		"subir", "descer":
			# um pulinho do chão para o assento (ou de volta), já virando de costas para o móvel
			var f := clampf(1.0 - float(r["t"]) / 0.5, 0.0, 1.0)
			var de: Vector3 = r["de"]
			var para2: Vector3 = l["assento"] if est == "subir" else l["pe"]
			if est == "descer":
				para2.y = _chao(para2.x, para2.z)
			var p := de.lerp(para2, smoothstep(0.0, 1.0, f)) + Vector3(0, sin(f * PI) * 0.22, 0)
			r["yaw"] = lerp_angle(float(r["yaw"]), yaw_sentado, 1.0 - exp(-12.0 * delta))
			no.global_position = p
			no.rotation.y = float(r["yaw"])
			r["pos"] = p
			if f >= 1.0:
				if est == "subir":
					r["estado"] = "jogar"
					r["t"] = _rng.randf_range(12.0, 24.0)
					partidas += 1
					_sentar(r, true)
					_mostrar_aparelho(r, String(l["tipo"]))
				else:
					r["estado"] = "voltar"
					r["rota"] = (l["via"] as Array).duplicate()
					(r["rota"] as Array).reverse()
					(r["rota"] as Array).append(_ponto_do_patio())
					r["t"] = 40.0
		"jogar":
			r["vel"] = 0.0
			no.global_position = l["assento"]
			r["pos"] = l["assento"]
			r["yaw"] = yaw_sentado
			no.rotation.y = yaw_sentado
			_pose_jogo(r, String(l["tipo"]))
			if float(r["t"]) <= 0.0:
				_sentar(r, false)
				_esconder_aparelho(r)
				var j: Dictionary = r["j"]
				for nome: String in ["ombroE", "ombroD", "cotoveloE", "cotoveloD", "tronco"]:
					if j[nome]:
						(j[nome] as Node3D).rotation = Vector3.ZERO
				r["estado"] = "descer"
				r["t"] = 0.5
				r["de"] = no.global_position
	return true


## Sentado com o aparelho nas mãos: braços para a frente, cotovelos dobrados, os dedos apertando (os braços
## tremem um pouco) e a cabeça para a TV (de leve para cima) ou para o portátil (para baixo).
func _pose_jogo(r: Dictionary, tipo: String) -> void:
	var j: Dictionary = r["j"]
	var tempo := Time.get_ticks_msec() * 0.001 + float(r["fase"])
	var aperta := sin(tempo * 17.0) * 0.05 + sin(tempo * 5.3) * 0.04
	for par: Array in [["E", 1.0], ["D", -1.0]]:
		var lado: String = par[0]
		var sinal: float = par[1]
		if j["ombro" + lado]:
			(j["ombro" + lado] as Node3D).rotation = Vector3(deg_to_rad(-38.0) + aperta * sinal, 0, deg_to_rad(-12.0) * sinal)
		if j["cotovelo" + lado]:
			(j["cotovelo" + lado] as Node3D).rotation = Vector3(deg_to_rad(-62.0) - aperta * sinal, 0, 0)
	if j["cabeca"]:
		var olha := -8.0 if tipo == "tv" else 26.0
		(j["cabeca"] as Node3D).rotation = Vector3(deg_to_rad(olha + sin(tempo * 0.7) * 3.0), sin(tempo * 0.45) * 0.08, 0)
	if j["tronco"]:
		# na TV o corpo vai junto com o jogo, para um lado e para o outro
		(j["tronco"] as Node3D).rotation = Vector3(deg_to_rad(6.0), 0, sin(tempo * 1.3) * (0.1 if tipo == "tv" else 0.03))
	var ap := r["aparelho"] as Node3D
	if ap and j["luvaE"] and j["luvaD"]:
		var meio := ((j["luvaE"] as Node3D).global_position + (j["luvaD"] as Node3D).global_position) * 0.5
		var no := r["no"] as Node3D
		ap.global_transform = Transform3D(no.global_basis * Basis(Vector3.RIGHT, deg_to_rad(-35.0 if tipo == "tv" else -53.0)), meio + no.global_basis.z * 0.03)


func _mostrar_aparelho(r: Dictionary, tipo: String) -> void:
	var ap := r["aparelho"] as Node3D
	if ap == null:
		ap = Node3D.new()
		add_child(ap)
		r["aparelho"] = ap
	for c in ap.get_children():
		c.queue_free()
	if tipo == "portatil":
		if _portatil == null:
			_portatil = load(BaseLar.MOVEIS + "gameconsole_handheld.gltf")
		var cena := _portatil.instantiate() as Node3D
		cena.scale = Vector3.ONE * 0.2  # no pacote ele é deitado, de tela para cima: a inclinação vem de _pose_jogo
		ap.add_child(cena)
	else:
		# o controle do videogame da TV, com o fio
		var corpo := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.13, 0.025, 0.06)
		corpo.mesh = bm
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/shaders/vale_solido.gdshader")
		m.set_shader_parameter("cor", Color(0.55, 0.53, 0.48))
		corpo.material_override = m
		ap.add_child(corpo)
		for bx: float in [-0.035, 0.035]:
			var botao := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.022, 0.012, 0.022)
			botao.mesh = bb
			var mb := ShaderMaterial.new()
			mb.shader = load("res://scripts/shaders/vale_solido.gdshader")
			mb.set_shader_parameter("cor", Color(0.75, 0.18, 0.12) if bx > 0.0 else Color(0.1, 0.1, 0.1))
			botao.material_override = mb
			botao.position = Vector3(bx, 0.016, 0.0)
			ap.add_child(botao)
	ap.visible = true


func _esconder_aparelho(r: Dictionary) -> void:
	if r["aparelho"]:
		(r["aparelho"] as Node3D).visible = false


## A tela da TV anda a partida enquanto alguém joga nela; sem ninguém, fica parada na tela de começo.
func _animar_tv(delta: float) -> void:
	if BaseLar.tela_tv == null or BaseLar.quadros_tv.is_empty():
		return
	var alguem := false
	for r: Dictionary in _robos:
		if String(r["estado"]) == "jogar" and int(r["lugar"]) >= 0 and String((BaseLar.lugares_minis[int(r["lugar"])] as Dictionary)["tipo"]) == "tv":
			alguem = true
	var antes := int(_quadro_tv)
	_quadro_tv = fposmod(_quadro_tv + delta * 6.0, float(BaseLar.quadros_tv.size())) if alguem else 0.0
	if int(_quadro_tv) != antes:
		var tex: Texture2D = BaseLar.quadros_tv[int(_quadro_tv)]
		BaseLar.tela_tv.set_shader_parameter("tex", tex)
		BaseLar.tela_tv.set_shader_parameter("luz", tex)
