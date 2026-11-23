extends SceneTree
# Rascunho do tiro que bate na água (2026-11-23): cada efeito de `TiroAgua` na lagoa da Clareira, em quadros
# seguidos (o tempo desde o acerto vai no nome), com o robô na margem para dar a escala. Uma folha por arma.
# Com --jogo, em vez disso, os tiros de verdade: o robô na margem mira a lagoa e atira com cada arma, a granada e o
# míssil, e as fotos saem pela câmera do jogo (com a tela).
# Uso: godot --path . --fixed-fps 60 -s tools/fotos_tiro_agua.gd -- --teste-vale [--so=granada | --jogo] <pasta>/
var m: Node
var a: Armadura
var pasta := ""
var cam: Camera3D
var imagens := {}
var alvo := Vector3.ZERO  # onde o tiro bate (na lâmina)
var margem := Vector3.ZERO  # onde o robô fica


func _initialize() -> void:
	_rodar()


func _esp(n: int) -> void:
	for i in n:
		await physics_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(pasta + nome + ".png")
	imagens[nome] = img
	print("foto ", nome)


func _folha(nomes: Array, cols: int, saida: String, div := 2) -> void:
	var w0: int = (imagens[nomes[0]] as Image).get_width() / div
	var h0: int = (imagens[nomes[0]] as Image).get_height() / div
	var g := 8
	var linhas := (nomes.size() + cols - 1) / cols
	var folha := Image.create(cols * w0 + (cols + 1) * g, linhas * h0 + (linhas + 1) * g, false, Image.FORMAT_RGB8)
	folha.fill(Color(0.09, 0.1, 0.11))
	for i in nomes.size():
		var im := (imagens[nomes[i]] as Image).duplicate() as Image
		im.convert(Image.FORMAT_RGB8)
		im.resize(w0, h0, Image.INTERPOLATE_LANCZOS)
		folha.blit_rect(im, Rect2i(0, 0, w0, h0), Vector2i(g + (i % cols) * (w0 + g), g + (i / cols) * (h0 + g)))
	folha.save_png(pasta + saida + ".png")
	print("folha ", saida)


## A lâmina no ponto (x, z), ou -INF.
func _agua(x: float, z: float) -> float:
	return m.ilha.agua(x, z)


## Um ponto da lagoa da Clareira com mais de 1,5 m de fundura e a margem seca mais perto dele.
func _achar_lagoa() -> bool:
	var c := Vector2(Clareira.LAGOA.x, Clareira.LAGOA.y)
	var melhor := Vector3.INF
	for i in 400:
		var ang := TAU * float(i % 20) / 20.0
		var d := float(i / 20) * 0.6
		var q := c + Vector2(cos(ang), sin(ang)) * d
		var s := _agua(q.x, q.y)
		if s != -INF and s - m.ilha.altura(q.x, q.y) > 1.5:
			melhor = Vector3(q.x, s, q.y)
			break
	if not melhor.is_finite():
		return false
	alvo = melhor
	# a margem: andando do ponto para a base até sair da água, mais 2 m
	var rumo := (Vector2(m.ilha.spawn.x, m.ilha.spawn.z) - Vector2(alvo.x, alvo.z)).normalized()
	for i in 200:
		var q := Vector2(alvo.x, alvo.z) + rumo * (float(i) * 0.5)
		if _agua(q.x, q.y) == -INF:
			q += rumo * 2.0
			margem = Vector3(q.x, m.ilha.altura(q.x, q.y), q.y)
			break
	# o tiro bate a uns 6 m da beira (no meio da lagoa ficava longe e pequeno)
	var beira := Vector2(margem.x, margem.z) - rumo * 2.0
	for i in 40:
		var q := beira - rumo * (6.0 + float(i) * 0.25)
		var s := _agua(q.x, q.y)
		if s != -INF and s - m.ilha.altura(q.x, q.y) > 1.2:
			alvo = Vector3(q.x, s, q.y)
			break
	return true


## Põe a câmera atrás do robô, na margem, olhando o ponto do tiro (o robô fica no canto de baixo).
func _enquadrar(dist_extra := 0.0, altura := 3.4) -> void:
	var rumo := (alvo - margem)
	rumo.y = 0.0
	rumo = rumo.normalized()
	var lado := rumo.cross(Vector3.UP).normalized()
	var pos := margem - rumo * (2.5 + dist_extra) + lado * 2.2 + Vector3(0, altura + dist_extra * 0.35, 0)
	cam.global_position = pos
	cam.look_at(alvo + Vector3(0, 1.2 + dist_extra * 0.3, 0), Vector3.UP)
	a.teleportar(margem + Vector3(0, 0.3, 0), Armadura.Estado.CHAO)
	a.rotation.y = atan2(-rumo.x, -rumo.z)


## Dispara `gatilho` e tira uma foto em cada tempo de `tempos` (segundos desde o disparo). Conta quadros: com
## `--fixed-fps 60` cada quadro vale 1/60 s mesmo quando a foto demora (pelo relógio, o tempo pulava na captura).
func _sequencia(nome: String, gatilho: Callable, tempos: Array) -> Array:
	var nomes := []
	var q := 0
	gatilho.call()
	for t: float in tempos:
		while q < roundi(t * 60.0):
			await process_frame
			q += 1
		var n := "%s_%04dms" % [nome, roundi(q * 1000.0 / 60.0)]
		await _foto(n)
		nomes.append(n)
	await _esp(150)
	return nomes


## Quadros com a câmera do jogo apontada para o alvo (mirando, ela anda; a cada quadro a mira volta ao ponto).
func _quadros(n: int) -> void:
	for i in n:
		var c: CameraVoo = m.camera
		var d := alvo - c.global_position
		c.yaw = atan2(-d.x, -d.z)
		c.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await physics_frame


## Fotos em `marcas` (quadros desde agora); `durante` roda a cada quadro (segurar e soltar botões).
func _jogo_fotos(nome: String, marcas: Array, durante := Callable()) -> Array:
	var nomes := []
	var q := 0
	for alvo_q: int in marcas:
		while q < alvo_q:
			if durante.is_valid():
				durante.call(q)
			await _quadros(1)
			q += 1
		var n := "j_%s_%04dms" % [nome, roundi(q * 1000.0 / 60.0)]
		await _foto(n)
		nomes.append(n)
	return nomes


func _jogo() -> void:
	Arsenal.tudo = true
	var todas := []
	var so := ""
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--so="):
			so = x.substr(5)
	for k in ["pistola", "duplo", "rajada", "precisao", "canhao", "misseis", "granada"]:
		if so != "" and k != so:
			continue
		a.teleportar(margem + Vector3(0, 0.3, 0), Armadura.Estado.CHAO)
		Arsenal.modo = "pistola" if k == "granada" else k
		Arsenal.misseis = 8
		Arsenal.granadas = 3
		a.visual.vestir_melhorias()
		if k != "granada":
			Input.action_press("mirar")
		await _quadros(50)
		var nomes := []
		match k:
			"pistola", "precisao":
				nomes = await _jogo_fotos(k, [6, 14, 30, 60], func(q: int) -> void:
					if q == 0:
						Input.action_press("atirar")
					elif q == 2:
						Input.action_release("atirar"))
			"duplo":
				nomes = await _jogo_fotos(k, [6, 14, 30, 60], func(q: int) -> void:
					if q == 0:
						Input.action_press("atirar")
						Input.action_release("mirar")
					elif q == 1:
						Input.action_press("mirar")
					elif q == 2:
						Input.action_release("atirar"))
			"rajada":
				nomes = await _jogo_fotos(k, [15, 30, 45, 70], func(q: int) -> void:
					if q == 0:
						Input.action_press("atirar")
					elif q == 45:
						Input.action_release("atirar"))
			"canhao":
				nomes = await _jogo_fotos(k, [60, 80, 100, 130], func(q: int) -> void:
					if q == 0:
						Input.action_press("atirar")
					elif q == 70:
						Input.action_release("atirar"))
			"misseis":
				nomes = await _jogo_fotos(k, [15, 60, 80, 110], func(q: int) -> void:
					if q == 0:
						Input.action_press("atirar")
					elif q == 20:
						Input.action_release("atirar"))
			"granada":
				nomes = await _jogo_fotos(k, [30, 100, 125, 145, 158, 175, 200, 260], func(q: int) -> void:
					if q == 0:
						Input.action_press("granada")
					elif q == 35:
						Input.action_release("granada"))
		Input.action_release("mirar")
		Input.action_release("atirar")
		_folha(nomes, 4, "jogo_" + k)
		todas.append(nomes)
		await _quadros(150)
	print("granada: ", m.tiro.granadas_jogadas, " tiros na água: ", m.tiro.acertos_agua, " estouros na água: ", m.tiro.estouros_agua)


func _rajada(cor: Color) -> void:
	var rumo := (alvo - margem)
	rumo.y = 0.0
	rumo = rumo.normalized()
	var lado := rumo.cross(Vector3.UP).normalized()
	for i in 12:
		var p := alvo + lado * (float(i) - 5.5) * 0.55 + rumo * randf_range(-0.6, 0.6)
		p.y = _agua(p.x, p.z)
		if p.y != -INF:
			TiroAgua.rajada(m, p, cor)
		await create_timer(Arsenal.MODOS["rajada"]["cadencia"]).timeout


func _granada() -> void:
	var g: Node3D = m.tiro._corpo_granada()
	m.add_child(g)
	var rumo := (alvo - margem).normalized()
	var p := alvo - rumo * 1.2 + Vector3(0, 1.8, 0)
	var vel := rumo * 4.0 + Vector3(0, -6.0, 0)
	g.global_position = p
	# cai até a lâmina
	while g.global_position.y > alvo.y:
		await process_frame
		var dt := 1.0 / 60.0
		vel.y -= 22.0 * dt
		g.global_position += vel * dt
		g.rotation += Vector3(7.0, 3.0, 5.0) * dt
	var entrou := Vector3(g.global_position.x, alvo.y, g.global_position.z)
	print("granada entrou ", entrou)
	TiroAgua.entrada(m, entrou)
	# afunda devagar, soltando bolhas
	var t := 0.0
	var bolha := 0.0
	vel = vel * 0.15
	while t < 0.6:
		await process_frame
		var dt := 1.0 / 60.0
		t += dt
		bolha += dt
		vel = vel.lerp(Vector3(0, -1.3, 0), 0.08)
		g.global_position += vel * dt
		if bolha > 0.12:
			bolha = 0.0
			TiroAgua.bolhas(m, g.global_position, alvo.y)
	var fundo := g.global_position
	print("granada estoura em ", fundo)
	g.queue_free()
	TiroAgua.cupula(m, Vector3(fundo.x, alvo.y, fundo.z), Arsenal.GRANADA["area"])


func _rodar() -> void:
	for x in OS.get_cmdline_user_args():
		if not x.begins_with("--"):
			pasta = x
	if pasta == "":
		pasta = "/tmp/tiro_agua/"
	DirAccess.make_dir_recursive_absolute(pasta)
	Main.abertura_vista = true
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	while m.get("pausa") == null or not (m.get("pausa") as Node).is_inside_tree():
		await process_frame
	for c in m.get_children():
		if c.get_script() and String(c.get_script().resource_path).ends_with("testes_vale.gd"):
			c.queue_free()
	if m.pausa.visible:
		m.pausa.call("_continuar")
	paused = false
	await _esp(30)
	m.ciclo.hora = 10.0
	m.ciclo.parado = true
	a = m.armadura
	if m.memorias:
		m.memorias.fechar()
	a.recomecar()
	await _esp(20)
	if not _achar_lagoa():
		print("ERRO: não achei a lagoa")
		quit(1)
		return
	print("alvo ", alvo, " margem ", margem)
	var jogo := OS.get_cmdline_user_args().has("--jogo")
	if jogo:
		await _quadros(60)
		await _jogo()
		quit()
		return
	for c in m.get_children():
		if c is CanvasLayer:
			c.visible = false
	cam = Camera3D.new()
	cam.fov = 42.0
	root.add_child(cam)
	cam.current = true
	_enquadrar()
	var atras := cam.global_position + cam.global_basis.z * 6.0
	atras.y = m.ilha.altura(atras.x, atras.z) + 0.5
	TiroAgua.laser(m, atras, Color.WHITE)
	TiroAgua.rajada(m, atras, Color.WHITE)
	TiroAgua.precisao(m, atras, Color.WHITE)
	TiroAgua.coluna(m, atras, 5.0, 1.0)
	TiroAgua.entrada(m, atras)
	TiroAgua.bolhas(m, atras, atras.y + 1.0)
	TiroAgua.cupula(m, atras, 7.0)
	var g0: Node3D = m.tiro._corpo_granada()
	m.add_child(g0)
	g0.global_position = atras
	await _esp(150)
	g0.queue_free()
	var so := ""
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--so="):
			so = x.substr(5)
	if so == "granada":
		_enquadrar(4.0, 3.0)
		await _esp(30)
		var gr := await _sequencia("7_granada", func() -> void: _granada.call(), [0.25, 0.5, 0.75, 0.95, 1.15, 1.5, 2.0, 3.0])
		_folha(gr, 4, "folha_7_granada")
		quit()
		return
	var folhas := []
	var cores: Dictionary = {}
	for k in ["pistola", "rajada", "precisao", "duplo", "canhao"]:
		cores[k] = Arsenal.MODOS[k]["cor"]
	var pistola := await _sequencia("1_pistola", func() -> void: TiroAgua.laser(m, alvo, cores["pistola"]),
		[0.05, 0.2, 0.45, 1.0])
	_folha(pistola, 4, "folha_1_pistola")
	var duplo := await _sequencia("2_duplo", func() -> void:
		TiroAgua.laser(m, alvo, cores["duplo"])
		TiroAgua.laser(m, alvo + Vector3(1.4, 0, 0.6), cores["duplo"]), [0.05, 0.2, 0.45, 1.0])
	_folha(duplo, 4, "folha_2_duplo")
	var rajada := await _sequencia("3_rajada", func() -> void: _rajada.call(cores["rajada"]), [0.3, 0.6, 1.0, 1.6])
	_folha(rajada, 4, "folha_3_rajada")
	var precisao := await _sequencia("4_precisao", func() -> void: TiroAgua.precisao(m, alvo, cores["precisao"]),
		[0.1, 0.35, 0.7, 1.3])
	_folha(precisao, 4, "folha_4_precisao")
	_enquadrar(5.0, 3.5)
	await _esp(30)
	var canhao := await _sequencia("5_canhao", func() -> void:
		TiroAgua.coluna(m, alvo, Arsenal.MODOS["canhao"]["area"], 0.0, cores["canhao"]), [0.1, 0.4, 0.8, 1.6])
	_folha(canhao, 4, "folha_5_canhao")
	var missil := await _sequencia("6_missil", func() -> void:
		TiroAgua.coluna(m, alvo, Arsenal.MODOS["misseis"]["area"], 1.0), [0.08, 0.4, 0.8, 1.6])
	_folha(missil, 4, "folha_6_missil")
	var granada := await _sequencia("7_granada", func() -> void: _granada.call(),
		[0.25, 0.5, 0.75, 0.95, 1.15, 1.5, 2.0, 3.0])
	_folha(granada, 4, "folha_7_granada")
	quit()
