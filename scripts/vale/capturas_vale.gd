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
	if "--largo" in args:
		await _largo()
		return
	if "--mirando" in args:
		await _mirando()
		return
	if "--passada" in args:
		await _passada()
		return
	if "--posturas" in args:
		await _posturas()
		return
	if "--plantas" in args:
		await _plantas()
		return
	if "--nado" in args:
		await _nado()
		return
	if "--levantar" in args:
		await _levantar()
		return
	if "--sonda-som" in args:
		await _sonda_som()
		return
	if "--furos" in args:
		await _furos()
		return
	if "--sumidouro" in args:
		await _sumidouro()
		return
	if "--cavernas" in args:
		await _cavernas()
		return
	if "--inimigos" in args:
		await _inimigos()
		return
	if "--vida" in args:
		await _vida()
		return
	if "--base" in args:
		await _base()
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
	# os outros bichos do pacote, lado a lado: veado de galhada, raposa e lobo
	var k := 0
	for par: Array in [["stag", 1.55, Cervo], ["fox", 0.55, Raposa], ["wolf", 0.85, Lobo]]:
		var b: Cervo = (par[2] as GDScript).new()
		b.especie = par[0]
		b.altura_bicho = par[1]
		b.mapa = c
		b.casa = cv.global_position + Vector3(0, 0, 2.2 + k * 2.2)
		b.semente = 90 + k
		m.add_child(b)
		b.global_position = b.casa
		b.rotation.y = 0.0
		b.pose_foto = 2 if k == 0 else 0
		k += 1
	var de := cv.global_position + Vector3(7.5, 0, 3.4)
	a.teleportar(Vector3(de.x, c.altura(de.x, de.z) + 0.3, de.z), Armadura.Estado.CHAO)
	_olhar(de, cv.global_position + Vector3(0, 0, 3.4), 0.0)
	await _esperar(2.0)
	await _foto("cervo_5_todos")
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
	# quanto ela anda sozinha em 25 s de patrulha (o robô longe)
	var p0 := st.global_position
	var andou := 0.0
	var ant := p0
	for i in 25 * 60:
		await get_tree().physics_frame
		andou += st.global_position.distance_to(ant)
		ant = st.global_position
	print("sentinela: andou %.1f m em 25 s de patrulha (ficou a %.1f m de onde estava)" % [andou, st.global_position.distance_to(p0)])
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
		var mv: MechVisual = st.get("mech")
		var sk := mv.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var baixo := INF
		for i in sk.get_bone_count():
			var w := sk.global_transform * sk.get_bone_global_pose(i).origin
			if sk.get_bone_name(i).contains("Pole"):
				continue
			baixo = minf(baixo, w.y - c.altura(w.x, w.z))
		print("sentinela %s: osso mais baixo a %.2f m do chão" % [par[1], baixo])
		if par[0] == 5:
			livre.global_position = st.global_position + Vector3(-7.0, 2.2, 8.0)
			livre.look_at(st.global_position + Vector3(0, 0.5, 0))
			await _esperar(0.3)
			await _foto("s_desligado_perto")
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


## Cada caverna de fora (a boca), por dentro e de cima (`--cavernas`).
func _cavernas() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 62.0
	livre.make_current()
	var k := 0
	for cav: Dictionary in Cavernas.lista:
		var pa: Vector2 = cav["a"]
		var pb: Vector2 = cav["b"]
		var d2 := (pb - pa).normalized()
		var dir := Vector3(d2.x, 0, d2.y)
		var ini := Vector3(pa.x, float(cav["ha"]), pa.y)
		a.teleportar(ini + Vector3(0, 60, 0), Armadura.Estado.PAIRAR)
		Input.action_press("mirar")
		await _esperar(1.2)
		var boca := ini + dir * maxf(0.0, float(cav["de"]) - 26.0)
		livre.global_position = boca + Vector3(0, 4.0, 0) + dir.cross(Vector3.UP) * 5.0
		livre.look_at(ini + dir * (float(cav["de"]) + 8.0) + Vector3(0, 3.5, 0))
		await _esperar(0.4)
		await _foto("g%d_boca" % k)
		var s_meio := lerpf(float(cav["de"]), float(cav["ate"]), 0.3)
		var perp := dir.cross(Vector3.UP)
		var meio := ini + dir * s_meio + perp * Cavernas._curva(cav, s_meio)
		meio.y = lerpf(cav["ha"], cav["hb"], s_meio / float(cav["comp"])) + 2.6
		var adiante := ini + dir * (s_meio + 22.0) + perp * Cavernas._curva(cav, s_meio + 22.0)
		adiante.y = meio.y + 0.6
		livre.global_position = meio
		livre.look_at(adiante)
		await _esperar(0.4)
		await _foto("g%d_dentro" % k)
		if cav["gruta"]:
			var fundo := ini + dir * (float(cav["comp"]) - 24.0) + perp * Cavernas._curva(cav, float(cav["comp"]) - 24.0)
			fundo.y = float(cav["ha"]) + 3.0
			livre.global_position = fundo
			livre.look_at(ini + dir * (float(cav["comp"]) - 8.0) + perp * Cavernas._curva(cav, float(cav["comp"])) + Vector3(0, float(cav["ha"]) - ini.y + 7.0, 0))
			await _esperar(0.4)
			await _foto("g%d_salao" % k)
		var centro := ini + dir * float(cav["comp"]) * 0.5
		livre.global_position = centro + Vector3(0, 75, 0) - dir * 45.0
		livre.look_at(centro)
		await _esperar(0.4)
		await _foto("g%d_cima" % k)
		k += 1
	Input.action_release("mirar")
	get_tree().quit()


## O Zangão e o Carrapato de perto, e os dois em ação vistos de fora (`--inimigos`).
func _inimigos() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 30.0
	livre.make_current()
	var z: Batedor = null
	var cr: Carrapato = null
	for n: Node3D in m.inimigos.todas:
		if n is Batedor and z == null:
			z = n
		if n is Carrapato and cr == null:
			cr = n
	# de perto, parados
	a.teleportar(z.global_position + Vector3(120, 60, 0), Armadura.Estado.PAIRAR)
	Input.action_press("mirar")
	await _esperar(1.0)
	z.pose_foto = 1
	for v: Array in [["z1_frente", Vector3(1.0, 1.2, -4.2)], ["z2_lado", Vector3(4.2, 1.2, 0.3)]]:
		livre.global_position = z.global_position + z.global_basis * (v[1] as Vector3)
		livre.look_at(z.global_position + Vector3(0, 0.8, 0))
		await _esperar(0.3)
		await _foto(v[0])
	z.pose_foto = -1
	cr.pose_foto = 1
	for v: Array in [["c1_frente", Vector3(0.8, 0.9, -3.0)], ["c2_lado", Vector3(3.0, 0.9, 0.2)]]:
		livre.global_position = cr.global_position + cr.global_basis * (v[1] as Vector3)
		livre.look_at(cr.global_position + Vector3(0, 0.45, 0))
		await _esperar(0.3)
		await _foto(v[0])
	cr.pose_foto = -1
	var vg: Vigia = null
	for n: Node3D in m.inimigos.todas:
		if n is Vigia and not (n is Batedor) and vg == null:
			vg = n
	if vg:
		vg.pose_foto = 1
		for v: Array in [["v1_frente", Vector3(1.2, 1.4, -4.6)], ["v2_lado", Vector3(4.6, 1.4, 0.3)]]:
			livre.global_position = vg.global_position + vg.global_basis * (v[1] as Vector3)
			livre.look_at(vg.global_position + Vector3(0, 0.9, 0))
			await _esperar(0.3)
			await _foto(v[0])
		vg.pose_foto = -1
		vg.desligar()
		await _esperar(2.0)
		livre.global_position = vg.global_position + vg.global_basis * Vector3(3.0, 1.6, -4.0)
		livre.look_at(vg.global_position + Vector3(0, 0.5, 0))
		await _foto("v3_desligado")
		vg.religar()
	Input.action_release("mirar")
	# em ação: o robô no chão perto dos carrapatos
	var p := cr.casa + Vector3(14, 0, 0)
	a.teleportar(Vector3(p.x, c.altura(p.x, p.z) + 0.3, p.z), Armadura.Estado.CHAO)
	a.graca_pane = 0.0
	for i in 200:
		await get_tree().physics_frame
		if cr.estado == Carrapato.Estado.INVESTE:
			break
	await _esperar(0.25)
	livre.fov = 50.0
	livre.global_position = a.global_position + Vector3(4, 3.0, 9)
	livre.look_at((a.global_position + cr.global_position) * 0.5)
	await _foto("c3_investida")
	# o robô perto dos zangões
	a.avaria = 0
	p = z.casa + Vector3(0, 0, 22)
	a.teleportar(Vector3(p.x, c.altura(p.x, p.z) + 0.3, p.z), Armadura.Estado.CHAO)
	for i in 600:
		await get_tree().physics_frame
		a.avaria = 0
		if z.disparos > 0:
			break
	await _esperar(0.3)
	livre.global_position = a.global_position + Vector3(7, 2.5, 8)
	livre.look_at((a.global_position + z.global_position) * 0.5)
	await _foto("z3_tiro")
	get_tree().quit()


## A vida fora da clareira (`--vida`): duas manadas, uma toca, um bando e o cardume do poço.
func _vida() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 38.0
	livre.make_current()
	var vistos := {}
	for l: Dictionary in m.vida.lugares:
		var tipo: String = l["tipo"]
		var limite := 3 if tipo == "cervo" else 1
		if int(vistos.get(tipo, 0)) >= limite:
			continue
		vistos[tipo] = int(vistos.get(tipo, 0)) + 1
		var p: Vector3 = l["pos"]
		var longe := p + Vector3(60, 0, 60)
		a.teleportar(Vector3(longe.x, c.altura(longe.x, longe.z) + 40.0, longe.z), Armadura.Estado.PAIRAR)
		Input.action_press("mirar")
		await _esperar(4.0)
		var dist := 16.0 if tipo == "cervo" else (9.0 if tipo == "peixe" else 6.0)
		var de := p + Vector3(dist, dist * 0.35, dist * 0.6)
		de.y = maxf(de.y, c.altura(de.x, de.z) + 1.2)
		livre.global_position = de
		livre.look_at(p + Vector3(0, 0.5, 0))
		await _esperar(0.5)
		await _foto("v_%s_%d" % [tipo, vistos[tipo]])
	Input.action_release("mirar")
	get_tree().quit()


## A base: o nascimento pela câmera do jogo, e a obra de frente, de lado, de cima e à noite (`--base`).
func _base() -> void:
	await _esperar(2.5)
	a.recomecar()
	await _esperar(2.0)
	await _foto("b1_nascimento")
	cam.yaw = c.spawn_yaw + PI
	cam.pitch = -0.1
	await _esperar(1.5)
	await _foto("b2_olhando_a_base")
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 50.0
	livre.make_current()
	var p := c.spawn
	var frente := Vector3(-sin(c.spawn_yaw), 0, -cos(c.spawn_yaw))
	var lado := frente.cross(Vector3.UP)
	for v: Array in [["b3_frente", frente * 11.0 + Vector3(0, 3.0, 0)], ["b4_lado", lado * 11.0 + frente * 4.0 + Vector3(0, 3.5, 0)], ["b5_cima", frente * 6.0 + Vector3(0, 14.0, 0)], ["b6_tras", -frente * 12.0 + lado * 3.0 + Vector3(0, 4.0, 0)]]:
		livre.global_position = p + v[1]
		livre.look_at(p + Vector3(0, 1.2, 0))
		await _esperar(0.3)
		await _foto(v[0])
	if m.ciclo:
		m.ciclo.hora = 22.0
		m.ciclo.parado = true
		await _esperar(1.5)
		livre.global_position = p + frente * 9.0 + lado * 3.0 + Vector3(0, 2.4, 0)
		livre.look_at(p + Vector3(0, 1.4, 0))
		await _esperar(0.5)
		await _foto("b7_noite")
	get_tree().quit()


## Abaixado, andando abaixado, sentado e a freada no ar (`--posturas`), com câmera solta e com a do jogo.
func _posturas() -> void:
	await _esperar(2.5)
	a.recomecar()
	var claro := Clareira.CLAROS[0]
	var capim := c.find_children("*", "MultiMeshInstance3D", true, false)
	for n in capim:
		(n as Node3D).visible = false
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 26.0
	livre.make_current()
	var chao := Vector3(claro.x, c.altura(claro.x, claro.y) + 0.2, claro.y)
	a.teleportar(chao, Armadura.Estado.CHAO)
	cam.yaw = PI * 0.5
	cam.pitch = 0.0
	await _esperar(0.8)
	var tirar := func(nome: String) -> void:
		var p: Vector3 = a.global_position + a.velocity * (1.0 / 60.0)
		for v: Array in [["lado", Vector3(0, 0.6, 4.6)], ["frente", Vector3(-3.6, 0.9, 2.6)]]:
			livre.global_position = p + v[1]
			livre.look_at(p + Vector3(0, 0.5, 0))
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(pasta + "%s_%s.png" % [nome, v[0]])
	await tirar.call("a_de_pe")
	Input.action_press("abaixar")
	await _esperar(0.1)
	Input.action_release("abaixar")
	await _esperar(0.8)
	await tirar.call("b_abaixado")
	Input.action_press("frente")
	await _esperar(1.0)
	await tirar.call("c_abaixado_andando")
	Input.action_release("frente")
	await _esperar(0.6)
	Input.action_press("abaixar")
	await _esperar(0.1)
	Input.action_release("abaixar")
	await _esperar(0.4)
	Input.action_press("abaixar")
	await _esperar(1.0)
	Input.action_release("abaixar")
	await _esperar(1.2)
	await tirar.call("d_sentado")
	# sentado, pela câmera do jogo, com o capim
	for n in capim:
		(n as Node3D).visible = true
	cam.cam.make_current()
	cam.yaw = PI * 0.5 + 0.5
	cam.pitch = -0.1
	await _esperar(1.5)
	await _foto("e_sentado_jogo")
	# freada: voando para -X, desliga os jatos
	livre.make_current()
	a.teleportar(chao + Vector3(40, 30, 0), Armadura.Estado.VOO, Vector3(-30, 0, 0))
	cam.yaw = PI * 0.5
	cam.pitch = 0.0
	await _esperar(0.6)
	Input.action_press("soltar")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("soltar")
	for q in 2:
		await _esperar(0.17)
		await tirar.call("f_freando_%d" % q)
	# mergulho com impacto: no ar e batendo
	await _esperar(2.0)
	a.teleportar(chao + Vector3(0, 26, 0), Armadura.Estado.VOO, Vector3(-18, 0, 0))
	await _esperar(0.3)
	Input.action_press("golpe")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("golpe")
	await _esperar(0.3)
	await tirar.call("j_mergulho")
	for i in 240:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.POUSO:
			break
	await _esperar(0.15)
	await tirar.call("k_impacto")
	if "--chuva" in OS.get_cmdline_user_args():
		# chuva no voo, pela câmera do jogo: voo reto, arrancada e parado no ar
		m.hud.visible = true
		cam.cam.make_current()
		a.calor = 0.0
		a.teleportar(chao + Vector3(300, 60, 0), Armadura.Estado.VOO, Vector3(-30, 0, 0))
		cam.pitch = -0.05
		await _esperar(2.5)
		await _foto("g_chuva_voo")
		Input.action_press("frente")
		await _esperar(2.0)
		await _foto("h_chuva_arrancada")
		Input.action_release("frente")
		Input.action_press("mirar")
		await _esperar(2.5)
		await _foto("i_chuva_parado")
		Input.action_release("mirar")
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


## O vale inteiro visto do alto e de alguns lugares (`--largo`), com câmera solta.
func _largo() -> void:
	await _esperar(3.0)
	a.recomecar()
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 60.0
	livre.far = 9000.0
	livre.make_current()
	var vistas := [
		["l1_do_alto_norte", Vector3(0, 330, 520), Vector3(0, 40, -300)],
		["l2_do_alto_leste", Vector3(-420, 300, 120), Vector3(500, 20, 120)],
		["l3_da_serra", Vector3(-640, 0, -700), Vector3(200, 20, 300)],
		["l4_praia", Vector3(250, 0, 800), Vector3(700, 10, 500)],
		["l5_borda_sul", Vector3(40, 0, 230), Vector3(0, 20, 0)],
		["f1_campo_sul", Vector3(-100, 0, 500), Vector3(100, 10, 700)],
		["f2_plato_flores", Vector3(640, 0, 120), Vector3(700, 36, 60)],
		["f3_plato_mar", Vector3(700, 0, 160), Vector3(900, 10, 300)],
		["f4_beira_rio", Vector3(262, 0, 392), Vector3(300, 6, 520)],
		["r1_saida_lagoa", Vector3(30, 0, 20), Vector3(100, 18, 100)],
		["r2_garganta", Vector3(150, 0, 200), Vector3(100, 20, 100)],
		["r3_rio_campo", Vector3(250, 0, 330), Vector3(300, 5, 520)],
		["r4_foz", Vector3(300, 0, 760), Vector3(350, 0, 900)],
		["r5_rio_do_alto", Vector3(120, 190, 420), Vector3(260, 5, 420)],
		["l6_campos_sul", Vector3(-100, 0, 500), Vector3(300, 0, 900)],
		["l7_mata_fechada", Vector3(120, 0, -560), Vector3(-200, 60, -500)],
		["l8_ruinas", Vector3(-560, 0, 420), Vector3(-700, 30, 250)],
	]
	if "--uma" in OS.get_cmdline_user_args():
		vistas = [vistas[0]]
	if "--serra" in OS.get_cmdline_user_args():
		var cm: Vector3 = (c as Vale).cume
		vistas = [["s1_cume_perto", Vector3(cm.x + 24, cm.y + 6, cm.z + 30), cm + Vector3(0, 6, 0)], ["s2_vista_do_cume", Vector3(cm.x, cm.y + 12, cm.z), Vector3(200, 20, 200)],
			["s3_cume_de_longe", Vector3(-250, 0, -250), cm]]
	if "--norte" in OS.get_cmdline_user_args():
		vistas = [["n1_cachoeira", Vector3(-268, 128, -440), Vector3(-300, 120, -512)], ["n2_poco", Vector3(-283, 0, -470), Vector3(-300, 124, -515)], ["n3_de_cima", Vector3(-316, 0, -540), Vector3(-270, 100, -430)], ["n4_riacho_mata", Vector3(-200, 0, -250), Vector3(-250, 80, -360)], ["n5_entrada_clareira", Vector3(-88, 0, -60), Vector3(-150, 34, -150)], ["n6_nascente", Vector3(-470, 0, -640), Vector3(-380, 170, -600)], ["n7_do_alto", Vector3(-120, 200, -300), Vector3(-300, 110, -500)]]
	if "--ruinas" in OS.get_cmdline_user_args():
		# [nome, lugar, de (na medida do lugar; y acima do chão dele), para onde olha]
		vistas = []
		for u: Array in [["u1_arcos", Ruinas.ARCOS, Vector3(-6, 5, 30), Vector3(0, 8, 0)], ["u2_arcos_baixo", Ruinas.ARCOS, Vector3(-30, 2.5, 7), Vector3(10, 9, -1)],
				["u3_arcos_alto", Ruinas.ARCOS, Vector3(-34, 30, 34), Vector3(4, 6, 0)],
				["u4_torre", Ruinas.TORRE, Vector3(-8, 4, 27), Vector3(5, 7, 0)], ["u5_torre_alto", Ruinas.TORRE, Vector3(30, 26, 24), Vector3(5, 5, 2)],
				["u6_torre_dentro", Ruinas.TORRE, Vector3(-2.6, 2.2, 2.4), Vector3(3, 10, -3)],
				["u7_patio", Ruinas.PATIO, Vector3(27, 5, 9), Vector3(0, 3, 0)], ["u8_patio_alto", Ruinas.PATIO, Vector3(-20, 24, 26), Vector3(0, 1, 0)],
				["u9_patio_berco", Ruinas.PATIO, Vector3(8.5, 3.4, 6.5), Vector3(0, 2.2, 0)]]:
			var lugar: Vector3 = u[1]
			var tl := Transform3D(Basis(Vector3.UP, lugar.z), Vector3(lugar.x, c.altura(lugar.x, lugar.y), lugar.y))
			vistas.append([u[0], tl * (u[2] as Vector3), tl * (u[3] as Vector3)])
	if "--paredes" in OS.get_cmdline_user_args():
		var cm2: Vector3 = (c as Vale).cume
		vistas = [["n1_cachoeira", Vector3(-268, 128, -440), Vector3(-300, 120, -512)], ["n2_poco", Vector3(-283, 0, -470), Vector3(-300, 124, -515)], ["p3_poco_lado", Vector3(-262, 0, -478), Vector3(-320, 122, -490)],
			["p4_serra_encosta", Vector3(cm2.x + 90, cm2.y - 20, cm2.z + 110), cm2 + Vector3(0, -15, 0)], ["r0_rio_inteiro", Vector3(-250, 620, 560), Vector3(230, 0, 430)], ["r3_rio_campo", Vector3(250, 0, 330), Vector3(300, 5, 520)]]
	if "--rio" in OS.get_cmdline_user_args():
		vistas = [["r0_rio_inteiro", Vector3(-250, 620, 560), Vector3(230, 0, 430)], ["r1_saida_lagoa", Vector3(30, 0, 20), Vector3(100, 18, 100)], ["r3_rio_campo", Vector3(250, 0, 330), Vector3(300, 5, 520)],
			["r5_rio_do_alto", Vector3(120, 190, 420), Vector3(260, 5, 420)], ["r6_riacho_norte_alto", Vector3(-60, 260, -200), Vector3(-230, 60, -330)], ["r4_foz", Vector3(300, 0, 760), Vector3(350, 0, 900)]]
	if "--flores" in OS.get_cmdline_user_args():
		vistas = [["f2_plato_flores", Vector3(640, 0, 120), Vector3(700, 36, 60)], ["f3_plato_mar", Vector3(700, 0, 160), Vector3(900, 10, 300)], ["f5_plato_alto", Vector3(420, 190, 330), Vector3(680, 38, 100)], ["f6_plato_borda", Vector3(505, 0, 160), Vector3(640, 30, 120)]]
	for v: Array in vistas:
		var de: Vector3 = v[1]
		if de.y == 0.0:
			de.y = c.altura(de.x, de.z) + 3.0
		# o robô vai junto, para as árvores perto dele aparecerem completas
		a.teleportar(Vector3(de.x, c.altura(de.x, de.z) + 0.3, de.z), Armadura.Estado.CHAO)
		livre.global_position = de
		livre.look_at(v[2])
		await _esperar(2.2)
		await _foto(v[0])
	get_tree().quit()


## O Sumidouro por fora e por dentro (`--sumidouro`).
func _sumidouro() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 68.0
	livre.make_current()
	var S := Sumidouro
	var d := Vector3(S.dir.x, 0, S.dir.y)
	var lado := d.cross(Vector3.UP)
	var eixo := Vector3(S.centro.x, S.piso, S.centro.y)
	var boca := Vector3(S.saida.x, S.saida_h, S.saida.y)
	var ya := S.ANEL_ALTURA
	a.teleportar(eixo + Vector3(0, 8.0, 0) + d * 6.0, Armadura.Estado.PAIRAR)
	Input.action_press("mirar")
	await _esperar(1.0)
	var vistas: Array = [
		["a_cima", eixo + Vector3(0, 115, 0) - d * 70.0, eixo + Vector3(0, 45, 0)],
		["b_poco_de_cima", eixo + Vector3(0, 84, 0) - d * 22.0 + lado * 10.0, eixo + Vector3(0, 30, 0)],
		["c_boca", boca + d * 34.0 + Vector3(0, 7, 0) + lado * 8.0, boca + Vector3(0, 4, 0) - d * 6.0],
		["d_tunel", boca - d * 8.0 + Vector3(0, 3.0, 0), eixo + d * 20.0 + Vector3(0, 5, 0)],
		["e_salao", eixo + d * 33.0 + Vector3(0, 5.0, 0) + lado * 6.0, eixo + Vector3(0, 9, 0)],
		["f_salao_fundo", eixo - d * 15.0 + Vector3(0, 4.0, 0) - lado * 9.0, eixo + d * 22.0 + Vector3(0, 8, 0)],
		["g_poco_de_baixo", eixo + Vector3(0, 2.5, 0) + d * 3.0, eixo + Vector3(0, 50, 0) + d * 0.5],
		["h_ponte", eixo + Vector3(0, ya + 9.0, 0) + d * 6.5, eixo + Vector3(0, ya - 3.0, 0) - d * 3.0],
		["i_galeria", eixo + Vector3(0, ya + 2.6, 0) + d * S.ANEL_RAIO, eixo + Vector3(0, ya + 2.4, 0) + lado * S.ANEL_RAIO],
		["j_janela", eixo + Vector3(0, ya + 3.0, 0) + lado * (S.ANEL_RAIO - 1.0), eixo + Vector3(0, ya + 1.0, 0) - lado * 10.0],
		["k_camara", Vector3(S._camara_xz().x, S.piso + 5.0, S._camara_xz().y) + d * 7.0, Vector3(S._camara_xz().x, S.piso + 5.0, S._camara_xz().y) - d * 6.0],
	]
	if S.varanda != Vector2.ZERO:
		var vn := Vector3(S.varanda.x, 0, S.varanda.y)
		vistas.append(["l_varanda", eixo + vn * 1.9 + Vector3(0, ya + 14.0, 0), eixo + vn * 0.6 + Vector3(0, ya + 2.0, 0)])
		vistas.append(["m_varanda_dentro", eixo + vn.normalized() * (S.ANEL_RAIO + 3.0) + Vector3(0, ya + 2.8, 0), eixo + vn * 1.2 + Vector3(0, ya + 2.5, 0)])
	for vista: Array in vistas:
		livre.global_position = vista[1]
		livre.look_at(vista[2])
		await _esperar(0.5)
		await _foto(vista[0])
	Input.action_release("mirar")
	get_tree().quit()


## Procura furos no chão por cima do Sumidouro e das grutas e fotografa a boca do túnel (`--furos`).
func _furos() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var S := Sumidouro
	var f := RochaMalha.furos(S._mn, S._mx, S.vazio, S.extra)
	print("furos no Sumidouro: ", f.size())
	var mn := Vector3.INF
	var mx := -Vector3.INF
	for p in f:
		mn = mn.min(p)
		mx = mx.max(p)
	print("  de ", mn, " a ", mx)
	for cv in Cavernas.lista:
		var fg := RochaMalha.furos(cv["mn"], cv["mx"], Cavernas.vazio_de.bind(cv), Callable())
		print("furos em ", cv["nome"], ": ", fg.size(), "  ", fg.slice(0, 6))
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 68.0
	livre.make_current()
	var d := Vector3(S.dir.x, 0, S.dir.y)
	var lado := d.cross(Vector3.UP)
	var boca := Vector3(S.saida.x, S.saida_h, S.saida.y)
	a.teleportar(boca + d * 10.0 + Vector3(0, 4.0, 0), Armadura.Estado.PAIRAR)
	Input.action_press("mirar")
	await _esperar(1.0)
	var poco := Vector3(Vale.POCO.x, Vale.POCO_NIVEL, Vale.POCO.y)
	var vistas: Array = [
		["a_do_poco", poco + Vector3(0, 6, 0), boca + Vector3(0, 3, 0)],
		["b_de_cima", boca + Vector3(0, 60, 0) + d * 20.0, boca],
		["b2_cachoeira_lado", (m.ilha as Vale).quedas[0] + ((Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized().cross(Vector3.UP)) * 15.0 + (Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized() * 7.0 + Vector3(0, -8, 0), (m.ilha as Vale).quedas[0] + (Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized() * 5.0 + Vector3(0, -6, 0)],
		["b3_cachoeira_meio_lado", (m.ilha as Vale).quedas[0] + ((Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized().cross(Vector3.UP)) * 16.0 + (Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized() * 16.0 + Vector3(0, -6, 0), (m.ilha as Vale).quedas[0]],
		["c_frente", boca + d * 22.0 + Vector3(0, 3, 0), boca + Vector3(0, 3, 0)],
		["d_lado1", boca + d * 8.0 + lado * 22.0 + Vector3(0, 6, 0), boca + Vector3(0, 2, 0)],
		["e_lado2", boca + d * 8.0 - lado * 22.0 + Vector3(0, 6, 0), boca + Vector3(0, 2, 0)],
		["f_dentro_fora", boca - d * 4.0 + Vector3(0, 2.0, 0), boca + d * 20.0 + Vector3(0, 2, 0)],
		["g_chao_boca", boca + d * 14.0 + Vector3(0, 1.2, 0), boca - d * 4.0 + Vector3(0, 2, 0)],
	]
	if f.size() > 0:
		var meio := (mn + mx) * 0.5
		vistas.append(["h_furo_cima", meio + Vector3(0, 30, 8), meio])
		vistas.append(["i_furo_dentro", f[f.size() / 2] + Vector3(0, 1.2, 0), Vector3(S.centro.x, S.piso + 10.0, S.centro.y)])
	for vista: Array in vistas:
		livre.global_position = vista[1]
		livre.look_at(vista[2])
		await _esperar(0.5)
		await _foto(vista[0])
	Input.action_release("mirar")
	get_tree().quit()


## Confere se o som está saindo (`--sonda-som`): o aparelho de saída, o volume do barramento e o pico medido.
func _sonda_som() -> void:
	await _esperar(2.5)
	a.recomecar()
	print("som: driver ", AudioServer.get_driver_name(), ", saída ", AudioServer.get_output_device(), ", aparelhos ", AudioServer.get_output_device_list())
	print("som: barramento 0 a ", AudioServer.get_bus_volume_db(0), " dB, mudo ", AudioServer.is_bus_mute(0), ", mix ", AudioServer.get_mix_rate(), " Hz")
	Input.action_press("frente")
	var pico := -200.0
	for i in 180:
		await get_tree().process_frame
		pico = maxf(pico, maxf(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0)))
	Input.action_release("frente")
	var todos: Array[Node] = m.find_children("*", "AudioStreamPlayer", true, false) + m.find_children("*", "AudioStreamPlayer3D", true, false)
	print("som: pico em 3 s andando ", pico, " dB; ", todos.size(), " tocadores")
	for n in todos:
		if n is AudioStreamPlayer3D:
			var p3 := n as AudioStreamPlayer3D
			if not p3.global_position.is_finite() or not is_finite(p3.pitch_scale) or p3.pitch_scale <= 0.0 or not is_finite(p3.volume_db):
				print("  ESTRANHO: ", p3.get_path(), " pos ", p3.global_position, " tom ", p3.pitch_scale, " vol ", p3.volume_db)
		else:
			var p1 := n as AudioStreamPlayer
			if not is_finite(p1.pitch_scale) or p1.pitch_scale <= 0.0 or not is_finite(p1.volume_db):
				print("  ESTRANHO: ", p1.get_path(), " tom ", p1.pitch_scale, " vol ", p1.volume_db)
	# desliga um por um até o som voltar
	for n in todos:
		if not n.playing:
			continue
		n.stop()
		var pc := -200.0
		for i in 20:
			await get_tree().process_frame
			pc = maxf(pc, AudioServer.get_bus_peak_volume_left_db(0, 0))
		if pc > -100.0:
			print("  o som voltou (", pc, " dB) ao desligar ", n.get_path(), " stream ", n.stream.resource_path if n.stream else "")
			break
	get_tree().quit()


## Abaixado (pés no chão), o levantar de sentado quadro a quadro e a decolagem segurando o pulo (`--levantar`).
func _levantar() -> void:
	await _esperar(2.5)
	a.recomecar()
	var claro := Clareira.CLAROS[0]
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		(n as Node3D).visible = false
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 22.0
	livre.make_current()
	var chao := Vector3(claro.x, c.altura(claro.x, claro.y) + 0.2, claro.y)
	a.teleportar(chao, Armadura.Estado.CHAO)
	cam.yaw = PI * 0.5
	cam.pitch = 0.0
	await _esperar(0.8)
	var tirar := func(nome: String, longe := 4.6, alto := 0.5) -> void:
		var p: Vector3 = a.pos_suave()
		livre.global_position = p + Vector3(0, alto, longe)
		livre.look_at(p + Vector3(0, alto, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta + nome + ".png")
	await tirar.call("a_de_pe")
	Input.action_press("abaixar")
	await _esperar(0.1)
	Input.action_release("abaixar")
	await _esperar(0.8)
	await tirar.call("b_abaixado")
	Input.action_press("frente")
	for i in 3:
		await _esperar(0.37)
		await tirar.call("c_abaixado_andando_%d" % i)
	Input.action_release("frente")
	await _esperar(0.6)
	a.postura = 2
	await _esperar(1.5)
	await tirar.call("d_sentado")
	Input.action_press("pular")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("pular")
	for i in 7:
		await _esperar(0.14)
		await tirar.call("e_levanta_%d" % i)
	await _esperar(0.5)
	# decolagem segurando o pulo
	livre.fov = 50.0
	Input.action_press("pular")
	for i in 8:
		await _esperar(0.22)
		var p: Vector3 = a.pos_suave()
		livre.global_position = chao + Vector3(3.0, 5.0, 17.0)
		livre.look_at(chao + Vector3(-3.0, 6.5, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta + "f_decola_%d.png" % i)
	Input.action_release("pular")
	get_tree().quit()


## O nado no poço da cachoeira, a lagoa funda e a mira travada numa máquina (`--nado`).
func _nado() -> void:
	await _esperar(2.5)
	var poco := Vector3(Vale.POCO.x, Vale.POCO_NIVEL, Vale.POCO.y)
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 55.0
	# pela câmera do jogo: boiando, nadando para baixo e nadando rápido
	a.teleportar(poco + Vector3(0, -3.0, 0), Armadura.Estado.AR)
	cam.yaw = 0.6
	cam.pitch = -0.1
	await _esperar(1.5)
	await _foto("a_boiando")
	cam.pitch = -0.45
	Input.action_press("frente")
	await _esperar(0.7)
	await _foto("b_descendo")
	Input.action_release("frente")
	await _esperar(0.5)
	cam.pitch = 0.05
	cam.yaw = 2.2
	Input.action_press("frente")
	Input.action_press("correr_alternar")
	await _esperar(0.1)
	Input.action_release("correr_alternar")
	await _esperar(0.5)
	await _foto("c_rapido")
	Input.action_release("frente")
	# de perto, câmera solta debaixo d'água
	m.hud.visible = false
	a.teleportar(poco + Vector3(0, -5.0, 0), Armadura.Estado.AR)
	cam.yaw = PI * 0.5
	cam.pitch = 0.0
	await _esperar(1.2)
	livre.make_current()
	livre.fov = 30.0
	livre.global_position = a.pos_suave() + Vector3(0, 0.6, 4.2)
	livre.look_at(a.pos_suave() + Vector3(0, 0.6, 0))
	await _esperar(0.3)
	await _foto("d_boiando_perto")
	Input.action_press("frente")
	await _esperar(0.45)
	livre.global_position = a.pos_suave() + Vector3(0, 0.6, 4.2)
	livre.look_at(a.pos_suave() + Vector3(0, 0.6, 0))
	await _foto("e_nadando_perto")
	Input.action_release("frente")
	# o poço de cima e saindo voando
	livre.fov = 60.0
	livre.global_position = poco + Vector3(14, 16, 22)
	livre.look_at(poco + Vector3(0, 2, 0))
	a.teleportar(poco + Vector3(0, -9.0, 0), Armadura.Estado.AR)
	await _esperar(0.4)
	cam.pitch = 1.2
	Input.action_press("frente")
	Input.action_press("correr_alternar")
	await _esperar(0.1)
	Input.action_release("correr_alternar")
	for i in 200:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.VOO:
			break
	await _esperar(0.25)
	await _foto("f_saindo_voando")
	Input.action_release("frente")
	# a lagoa da clareira
	m.hud.visible = true
	cam.cam.make_current()
	a.teleportar(Vector3(Clareira.LAGOA.x, Clareira.NIVEL - 2.5, Clareira.LAGOA.y), Armadura.Estado.AR)
	cam.pitch = -0.05
	cam.yaw = 1.0
	await _esperar(1.5)
	await _foto("g_lagoa")
	# a mira travada numa máquina
	var alvo_m: Node3D = null
	for n in get_tree().get_nodes_in_group("maquinas"):
		if n is Batedor and (n.call("ponto_de_trava") as Vector3).is_finite():
			alvo_m = n
			break
	if alvo_m:
		var pm: Vector3 = alvo_m.call("ponto_de_trava")
		a.teleportar(Vector3(pm.x + 16.0, c.altura(pm.x + 16.0, pm.z) + 0.3, pm.z), Armadura.Estado.CHAO)
		a.graca_pane = 30.0
		Input.action_press("mirar")
		for i in 60:
			pm = alvo_m.call("ponto_de_trava")
			var d := pm - cam.global_position
			cam.yaw = atan2(-d.x, -d.z) + deg_to_rad(3.5)
			cam.pitch = atan2(d.y, Vector2(d.x, d.z).length()) - deg_to_rad(2.0)
			if i == 40:
				Input.action_press("atirar")
			await get_tree().physics_frame
		await _foto("h_mira_travada")
		Input.action_release("atirar")
		Input.action_release("mirar")
	get_tree().quit()


## As árvores e as plantas dos pacotes, de perto (`--plantas`).
func _plantas() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var v := c as Vale
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 55.0
	livre.make_current()
	a.teleportar(Vector3(0, 400, 0), Armadura.Estado.PAIRAR)
	Input.action_press("mirar")
	for tipo: String in ["q_flor_a", "q_flor_c", "q_samambaia", "q_cogumelo", "q_moita", "q_pedra_a", "q_planta_c"]:
		if not v.plantas_amostra.has(tipo):
			print("sem amostra de ", tipo)
			continue
		var p: Vector3 = v.plantas_amostra[tipo]
		livre.global_position = Vector3(p.x + 3.2, v.altura(p.x + 3.2, p.z + 2.4) + 1.3, p.z + 2.4)
		livre.look_at(p + Vector3(0, 0.3, 0))
		await _esperar(0.5)
		await _foto("p_" + tipo)
	# árvores: procura uma de cada jeito perto do meio do mapa
	var vistos := {}
	for item in v._fila_q:
		var tipo: String = item[0]
		var base := tipo.substr(0, tipo.length() - 2) if not tipo.contains("_amarela") and not tipo.contains("_vinho") and not tipo.contains("_laranja") else tipo
		if vistos.has(base) or not tipo.begins_with("q_"):
			continue
		var p: Vector3 = (item[1] as Transform3D).origin
		if Vector2(p.x, p.z).length() < 160.0 or Vector2(p.x, p.z).length() > 600.0:
			continue
		vistos[base] = true
		livre.global_position = Vector3(p.x + 13.0, v.altura(p.x + 13.0, p.z + 9.0) + 3.5, p.z + 9.0)
		livre.look_at(p + Vector3(0, 6.0, 0))
		await _esperar(0.5)
		await _foto("a_" + base)
	Input.action_release("mirar")
	get_tree().quit()
