extends Node
## `godot --path . -- --vale-captura`: fotos do quadro da clareira em tools/capturas/vale/.

var m: Node
var a: Armadura
var cam: CameraVoo
var c: Clareira
var pasta := ""


func rodar(main: Node) -> void:
	m = main
	a = main.armadura
	cam = main.camera
	c = main.ilha
	var args := OS.get_cmdline_user_args()
	var sub := "vale"
	if "--pasta" in args and args.find("--pasta") + 1 < args.size():
		sub = args[args.find("--pasta") + 1]
	pasta = ProjectSettings.globalize_path("res://tools/capturas/" + sub + "/")
	DirAccess.make_dir_recursive_absolute(pasta)
	if "--curta" in args:
		await _curta()
		return
	if "--mirando" in args:
		await _mirando()
		return
	if "--passada" in args:
		await _passada()
		return
	if "--pouso" in args:
		await _pouso()
		return
	if "--sentinela" in args:
		await _sentinela()
		return
	if "--bichos" in args:
		await _bichos()
		return
	if "--cervo" in args:
		await _cervo()
		return
	if "--efeitos" in args:
		await _efeitos()
		return
	await _esperar(2.5)
	a.recomecar()
	cam.pitch = -0.06
	await _esperar(2.5)
	await _foto("q01_chegada")
	# de frente para o robô
	cam.yaw = c.spawn_yaw + PI * 0.92
	cam.pitch = -0.02
	await _esperar(1.2)
	await _foto("q02_robo_de_frente")
	cam.yaw = c.spawn_yaw
	# correndo pelo capim
	Input.action_press("frente")
	Input.action_press("correr")
	await _esperar(1.6)
	await _foto("q03_correndo")
	Input.action_release("frente")
	Input.action_release("correr")
	# na beira da lagoa
	_por(Vector3(24, 0, 4), Vector3(Clareira.LAGOA.x, 0, Clareira.LAGOA.y), -0.1)
	await _esperar(2.0)
	await _foto("q04_lagoa")
	# um cervo no campo
	var alvo_c: Node3D = null
	for n in m.get_children():
		if n is Cervo:
			alvo_c = n
			break
	var cv: Vector3 = alvo_c.global_position if alvo_c else c.cervos_em[0]
	_por(cv + Vector3(-5.5, 0, 4.5), cv, -0.04)
	await _esperar(0.5)
	await _foto("q04b_cervo")
	# em cima da pedra-mirante, olhando o campo
	var mi := Clareira.MIRANTE
	a.teleportar(Vector3(mi.x, c.altura(mi.x, mi.y) + 9.0, mi.y), Armadura.Estado.AR)
	_olhar(Vector3(mi.x, 0, mi.y), Vector3(20, 0, -5), -0.16)
	await _esperar(2.6)
	await _foto("q05_mirante")
	# voo baixo sobre o campo
	var de := Vector3(-34, c.altura(-34, 52) + 7.0, 52)
	var dir := (Vector3(30, 0, -20) - de)
	dir.y = 0.0
	dir = dir.normalized()
	cam.yaw = atan2(-dir.x, -dir.z)
	cam.pitch = -0.1
	a.calor = 10.0
	a.teleportar(de, Armadura.Estado.VOO, dir * 22.0)
	await _esperar(1.6)
	await _foto("q06_voo_baixo")
	# pairando alto, vendo a clareira inteira
	a.teleportar(Vector3(10, c.altura(10, 95) + 42.0, 95), Armadura.Estado.VOO, Vector3(0, 0, -6))
	cam.yaw = 0.0
	cam.pitch = -0.42
	Input.action_press("mirar")
	await _esperar(2.2)
	m.hud.medidor = true
	await _esperar(0.4)
	await _foto("q07_do_alto")
	Input.action_release("mirar")
	print("CAPTURAS DO VALE OK em ", pasta)
	get_tree().quit()


func _por(onde: Vector3, olhando: Vector3, pitch: float) -> void:
	a.teleportar(Vector3(onde.x, c.altura(onde.x, onde.z) + 0.3, onde.z), Armadura.Estado.CHAO)
	_olhar(onde, olhando, pitch)


func _olhar(de: Vector3, para: Vector3, pitch: float) -> void:
	var d := para - de
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = pitch


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var tri := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	get_viewport().get_texture().get_image().save_png(pasta + nome + ".png")
	print("foto %s: %d fps, %.1f M triângulos" % [nome, fps, tri / 1e6])


## Três fotos só, para comparar as horas do dia (`--curta --hora N --pasta nome`).
func _curta() -> void:
	await _esperar(2.5)
	a.recomecar()
	cam.pitch = -0.02
	await _esperar(2.5)
	await _foto("a_chegada")
	_por(Vector3(24, 0, 4), Vector3(Clareira.LAGOA.x, 0, Clareira.LAGOA.y), 0.06)
	await _esperar(2.0)
	await _foto("b_lagoa")
	a.teleportar(Vector3(10, c.altura(10, 95) + 42.0, 95), Armadura.Estado.VOO, Vector3(0, 0, -6))
	cam.yaw = 0.0
	cam.pitch = -0.3
	Input.action_press("mirar")
	await _esperar(2.4)
	await _foto("c_do_alto")
	Input.action_release("mirar")
	get_tree().quit()


## Fotos dos efeitos: tiro, pouso de herói, copa atravessada e água (`--efeitos --pasta nome`).
func _efeitos() -> void:
	await _esperar(2.5)
	a.recomecar()
	await _esperar(2.0)
	# tiro mirando no chão
	cam.pitch = -0.16
	Input.action_press("mirar")
	await _esperar(0.8)
	Input.action_press("atirar")
	await _esperar(0.585)
	await _foto("e1_tiro")
	await _esperar(0.3)
	await _foto("e1b_tiro")
	Input.action_release("atirar")
	Input.action_release("mirar")
	# pouso de herói
	var p := c.spawn
	a.teleportar(p + Vector3(0, 20, 0), Armadura.Estado.AR)
	for i in 400:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.POUSO:
			break
	await _esperar(0.12)
	await _foto("e2_pouso_heroi")
	await _esperar(0.3)
	await _foto("e2b_pouso_heroi")
	await _esperar(1.5)
	# atravessando uma copa
	var alvo := -1
	for i in c.arv_pos.size():
		if c.arv_tipo[i] == 1 and c.arv_pos[i].distance_to(c.spawn) < 70.0:
			alvo = i
			break
	if alvo >= 0:
		var copa: Vector3 = c.arv_pos[alvo] + Vector3(0, 7.0 * c.arv_escala[alvo], 0)
		var dir := Vector3(0.6, 0, -0.8).normalized()
		cam.yaw = atan2(-dir.x, -dir.z)
		cam.pitch = 0.0
		a.calor = 5.0
		a.teleportar(copa - dir * 16.0, Armadura.Estado.VOO, dir * 20.0)
		await _esperar(0.95)
		await _foto("e3_copa")
		await _esperar(0.25)
		await _foto("e3b_copa")
	# pose de voo de perto, reta e em curva
	cam.pitch = -0.05
	a.calor = 5.0
	a.teleportar(Vector3(-30, c.altura(-30, 60) + 14.0, 60), Armadura.Estado.VOO, Vector3(0.7, 0, -0.7) * 22.0)
	cam.yaw = atan2(-0.7, 0.7)
	await _esperar(1.0)
	await _foto("e6_voo_reto")
	Input.action_press("direita")
	await _esperar(0.7)
	await _foto("e7_voo_curva")
	Input.action_release("direita")
	# rasante e mergulho na lagoa
	var l := Vector3(Clareira.LAGOA.x, Clareira.NIVEL, Clareira.LAGOA.y)
	var d2 := Vector3(1, 0, 0)
	cam.yaw = atan2(-d2.x, -d2.z)
	cam.pitch = -0.12
	a.calor = 5.0
	a.teleportar(l - d2 * 9.0 + Vector3(0, 1.6, 0), Armadura.Estado.VOO, d2 * 16.0)
	await _esperar(0.5)
	await _foto("e4_rasante")
	a.teleportar(l + Vector3(0, 7, 0), Armadura.Estado.AR)
	cam.pitch = -0.25
	for i in 300:
		await get_tree().physics_frame
		if a.na_agua:
			break
	await _esperar(0.15)
	await _foto("e5_mergulho")
	await _esperar(0.35)
	await _foto("e5b_mergulho")
	get_tree().quit()


## O cervo de perto, de lado e de frente, em cada estado (`--cervo --pasta nome`).
func _cervo() -> void:
	await _esperar(2.5)
	var cv: Node3D = null
	for n in m.get_children():
		if n is Cervo:
			cv = n
			break
	cv.global_position = Vector3(-14, 0, 50)
	cv.rotation.y = 0.0
	a.visual.visible = false
	for e in 4:
		cv.set("pose_foto", e)
		var lado := cv.global_position + Vector3(4.2, 0, 0.3)
		a.teleportar(Vector3(lado.x, c.altura(lado.x, lado.z) + 0.3, lado.z), Armadura.Estado.CHAO)
		_olhar(lado, cv.global_position, 0.02)
		await _esperar(1.6)
		await _foto("cervo_%d_lado" % e)
	cv.set("pose_foto", 0)
	var frente := cv.global_position + Vector3(2.2, 0, -3.4)
	a.teleportar(Vector3(frente.x, c.altura(frente.x, frente.z) + 0.3, frente.z), Armadura.Estado.CHAO)
	_olhar(frente, cv.global_position, 0.02)
	await _esperar(1.6)
	await _foto("cervo_4_frente")
	get_tree().quit()


## Pássaros, coelhos e peixes de perto (`--bichos --pasta nome`). A câmera é a do jogo, então o robô fica
## escondido e parado perto; os bichos não o veem (ameaca = null) até a foto da revoada.
func _bichos() -> void:
	await _esperar(2.5)
	a.visual.visible = false
	var bando: Node3D = null
	var coelho: Node3D = null
	var peixes: Node3D = null
	for n in m.get_children():
		if n is Passaros and bando == null:
			bando = n
		elif n is Coelho and coelho == null:
			coelho = n
		elif n is Peixes:
			peixes = n
	for n in m.get_children():
		if n is Passaros or n is Coelho or n is Peixes:
			n.set("ameaca", null)
	# pássaros no chão
	var pb: Vector3 = bando.posicoes()[0]
	var de := pb + Vector3(2.6, 0, 1.2)
	a.teleportar(Vector3(de.x, c.altura(de.x, de.z) + 0.3, de.z), Armadura.Estado.CHAO)
	_olhar(de, pb, -0.05)
	await _esperar(2.0)
	await _foto("b1_passaros_chao")
	# revoada: câmera solta, alta, para nenhum tronco tapar
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 40.0
	livre.global_position = pb + Vector3(7.0, 5.0, 7.0)
	livre.look_at(pb + Vector3(0, 1.0, 0))
	livre.make_current()
	await _esperar(0.6)
	await _foto("b2_revoada_antes")
	bando.call("assustar", pb + Vector3(3, 0, 0))
	for i in 4:
		await _esperar(0.45)
		var soma := Vector3.ZERO
		var ps: Array = bando.posicoes()
		for q: Vector3 in ps:
			soma += q
		livre.look_at(soma / ps.size())
		await _esperar(0.1)
		await _foto("b2_revoada_%d" % i)
	cam.cam.make_current()
	livre.queue_free()
	# coelho: parado, comendo, pulando
	for e in 3:
		coelho.set("pose_foto", e)
		var pc := coelho.global_position
		var dc := pc + Vector3(2.4, 0, 0.6)
		a.teleportar(Vector3(dc.x, c.altura(dc.x, dc.z) + 0.3, dc.z), Armadura.Estado.CHAO)
		_olhar(dc, pc, -0.05)
		await _esperar(1.5)
		await _foto("b4_coelho_%d" % e)
	# peixes vistos de cima
	var l := Vector3(Clareira.LAGOA.x, Clareira.NIVEL, Clareira.LAGOA.y)
	a.teleportar(l + Vector3(0, 3.2, 3.0), Armadura.Estado.VOO, Vector3(0, 0, -0.1))
	cam.yaw = 0.0
	cam.pitch = -0.9
	Input.action_press("mirar")
	await _esperar(1.6)
	await _foto("b5_peixes")
	Input.action_release("mirar")
	get_tree().quit()


## O Sentinela de perto em cada estado, com câmera solta, e um tiro visto pelo jogador (`--sentinela`).
func _sentinela() -> void:
	await _esperar(2.5)
	var st: Node3D = null
	for n in m.get_children():
		if n is Sentinela:
			st = n
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 45.0
	var p := st.global_position
	# o robô ao lado, para a escala e para a mira
	a.teleportar(Vector3(p.x + 4.0, c.altura(p.x + 4.0, p.z + 5.0) + 0.3, p.z + 5.0), Armadura.Estado.CHAO)
	a.graca_pane = 999.0
	livre.global_position = p + Vector3(7.5, 2.4, 9.5)
	livre.look_at(p + Vector3(0, 1.7, 0))
	livre.make_current()
	for par: Array in [[0, "patrulha"], [2, "aviso"], [5, "desligado"]]:
		st.set("pose_foto", par[0])
		await _esperar(2.2)
		await _foto("s_%s" % par[1])
	st.set("pose_foto", -1)
	st.call("religar")
	await _esperar(2.0)
	await _foto("s_religado")
	# andando, de lado
	for i in 2:
		await _esperar(2.5)
		livre.global_position = st.global_position + Vector3(9.0, 2.0, 2.0)
		livre.look_at(st.global_position + Vector3(0, 1.6, 0))
		await _esperar(0.1)
		await _foto("s_andando_%d" % i)
	livre.queue_free()
	cam.cam.make_current()
	# visto pelo jogador: o aviso e o tiro
	a.graca_pane = 0.0
	var q := st.global_position
	a.teleportar(Vector3(q.x + 14.0, c.altura(q.x + 14.0, q.z + 16.0) + 0.3, q.z + 16.0), Armadura.Estado.CHAO)
	_olhar(a.global_position, q, 0.08)
	var n0: int = st.get("disparos")
	for i in 600:
		await get_tree().physics_frame
		if st.call("nome_estado") == "aviso":
			break
	await _esperar(0.9)
	await _foto("s_jogador_aviso")
	for i in 600:
		await get_tree().physics_frame
		if int(st.get("disparos")) > n0:
			break
	await _esperar(0.18)
	await _foto("s_jogador_tiro")
	get_tree().quit()


## A chegada ao chão e os três pousos (`--pouso`): armando as pernas, toque, médio.
func _pouso() -> void:
	await _esperar(2.5)
	a.recomecar()
	await _esperar(1.5)
	cam.pitch = -0.05
	var p := c.spawn
	for par: Array in [[2.6, "toque"], [7.0, "medio"]]:
		a.teleportar(p + Vector3(0, par[0], 0), Armadura.Estado.AR)
		for i in 300:
			await get_tree().physics_frame
			if a.chegando_ao_chao() and a.altura_do_chao() < 0.9:
				break
		await _foto("p_%s_chegando" % par[1])
		for i in 300:
			await get_tree().physics_frame
			if a.estado == Armadura.Estado.POUSO:
				break
		await _esperar(0.1)
		await _foto("p_%s_pouso" % par[1])
		await _esperar(1.2)
	get_tree().quit()


## A passada vista de lado, quadro a quadro (`--passada`): 8 fotos do andar e 8 da corrida.
func _passada() -> void:
	await _esperar(2.5)
	a.recomecar()
	var claro := Clareira.CLAROS[0]
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		(n as Node3D).visible = false  # sem capim nem árvores, para ver os pés
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 24.0
	livre.make_current()
	for modo: String in ["andar", "correr"]:
		a.teleportar(Vector3(claro.x + 3.0, c.altura(claro.x + 3.0, claro.y) + 0.2, claro.y), Armadura.Estado.CHAO)
		cam.yaw = PI * 0.5  # anda para -X
		cam.pitch = 0.0
		await _esperar(0.5)
		Input.action_press("frente")
		if modo == "correr":
			Input.action_press("correr")
		await _esperar(0.9)
		for i in 8:
			for q in (5 if modo == "andar" else 3):
				await get_tree().physics_frame
			# a câmera vai um quadro à frente do robô (a foto sai no quadro seguinte)
			var adiante: Vector3 = a.global_position + a.velocity * (1.0 / 60.0)
			livre.global_position = adiante + Vector3(0, 0.55, 5.2)
			livre.look_at(adiante + Vector3(0, 0.55, 0))
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(pasta + "%s_%d.png" % [modo, i])
		Input.action_release("frente")
		Input.action_release("correr")
		await _esperar(0.6)
	get_tree().quit()


## Andar atirando na diagonal, de lado e de costas, visto de cima e de frente (`--mirando`).
func _mirando() -> void:
	await _esperar(2.5)
	a.recomecar()
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		(n as Node3D).visible = false
	m.hud.visible = false
	var claro := Clareira.CLAROS[0]
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 22.0
	livre.make_current()
	for par: Array in [["frente", "direita", "diagonal"], ["direita", "", "lado"], ["tras", "", "costas"], ["tras", "esquerda", "diag_costas"]]:
		a.teleportar(Vector3(claro.x, c.altura(claro.x, claro.y) + 0.2, claro.y), Armadura.Estado.CHAO)
		cam.yaw = 0.0  # mira para -Z
		cam.pitch = 0.0
		await _esperar(0.4)
		Input.action_press(par[0])
		if par[1] != "":
			Input.action_press(par[1])
		for q in 54:
			a.atirando = 1.0  # braço em posição de tiro, sem o clarão do disparo
			await get_tree().physics_frame
		var adiante: Vector3 = a.global_position + a.velocity * (1.0 / 60.0)
		livre.global_position = adiante + Vector3(0.5, 3.4, -2.0)  # de cima e da frente
		livre.look_at(adiante + Vector3(0, 0.5, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta + "m_%s.png" % par[2])
		_soltar()
		await _esperar(0.5)
	get_tree().quit()


func _soltar() -> void:
	for ac in ["frente", "tras", "esquerda", "direita", "atirar", "mirar", "correr"]:
		Input.action_release(ac)
