extends SceneTree
# Fotos do corpo em peças (doc §143) no jogo: a aba Corpo da oficina (cartões, prévia, uma parte só, um conjunto
# fechado, vestindo) e o robô vestido lá fora, parado, correndo e voando (o rabo), mais uma fila de conjuntos
# com as melhorias no corpo. Uso:
# godot --path . -s tools/fotos_corpo.gd -- --teste-vale <pasta>/
var m: Node
var a: Armadura
var pasta := ""
var cam: Camera3D


func _initialize() -> void:
	_rodar()


func _esp(n: int) -> void:
	for i in n:
		await physics_frame


func _foto(nome: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta + nome + ".png")
	print("foto ", nome)


func _livre(de: Vector3, para: Vector3, fov := 55.0) -> void:
	cam.fov = fov
	cam.global_position = de
	cam.look_at(para)
	cam.make_current()


## A câmera de lado do robô (`giro` 0 é bem de lado, à direita de para onde ele vai; positivo vai para trás dele).
func _de_lado(dist := 3.2, giro := 0.0, alto := 0.7) -> void:
	# para onde o robô vai (andando) ou está virado (parado, com o giro forçado)
	var yaw: float = m.camera.yaw
	var hv := Vector2(a.velocity.x, a.velocity.z)
	if hv.length() > 1.0:
		yaw = atan2(-hv.x, -hv.y)
	elif not is_nan(a.visual.yaw_forcado):
		yaw = a.visual.yaw_forcado
	var frente := Vector3(-sin(yaw), 0, -cos(yaw))
	var direita := Vector3(cos(yaw), 0, -sin(yaw))
	var d := (direita * cos(giro) - frente * sin(giro)).normalized()
	var p := a.global_position
	_livre(p + d * dist + Vector3(0, alto, 0), p + Vector3(0, 0.55, 0), 42.0)


## A foto com a câmera de lado acompanhando o robô a cada quadro (correndo e voando ele anda bastante).
func _foto_seguindo(nome: String, dist: float, giro: float, alto: float) -> void:
	for i in 4:
		_de_lado(dist, giro, alto)
		await process_frame
	_de_lado(dist, giro, alto)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta + nome + ".png")
	print("foto ", nome)


func _focar(of: Oficina, nome: String) -> void:
	(of._botoes[nome] as Control).grab_focus()
	await _esp(25)


func _rodar() -> void:
	var args := OS.get_cmdline_user_args()
	for x in args:
		if not x.begins_with("--"):
			pasta = x
	if pasta == "":
		pasta = "/tmp/corpo/"
	DirAccess.make_dir_recursive_absolute(pasta)
	Main.abertura_vista = true
	InteriorCilindro.ativo = true
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
	m.ciclo.hora = 12.0
	m.ciclo.parado = true
	a = m.armadura
	if m.memorias:
		m.memorias.fechar()
	cam = Camera3D.new()
	m.add_child(cam)
	a.recomecar()
	Melhorias.energia = 100.0
	var of: Oficina = m.oficina
	var b := BaseVale.boca_cilindro
	var fora := b + of._eixo() * 0.6
	a.teleportar(Vector3(fora.x, m.ilha.altura(fora.x, fora.z) + 0.4, fora.z), Armadura.Estado.CHAO)
	await _esp(60)
	# ---- a aba Corpo
	of.entrar()
	await _esp(200)
	of._mudar_aba(4 - of.aba)
	await _esp(20)
	await _focar(of, "corpo_gato")
	await _foto("c1_aba_gato")
	await _focar(of, "corpo_sabre")
	await _foto("c2_aba_sabre")
	await _focar(of, "parte_cabeca")
	await _focar(of, "corpo_samurai")
	await _foto("c3_so_a_cabeca_samurai")
	await _focar(of, "parte_tudo")
	Corpo.tudo = false
	of._refazer_lista()
	await _esp(5)
	await _focar(of, "corpo_cavaleiro")
	await _foto("c4_fechado_cavaleiro")
	Corpo.tudo = true
	of._refazer_lista()
	await _esp(5)
	await _focar(of, "corpo_gato")
	of.instalar("corpo_gato")
	await _esp(int(Oficina.T_INSTALAR * 0.5 * 60.0))
	await _foto("c5_vestindo")
	await _esp(int(Oficina.T_INSTALAR * 0.5 * 60.0) + 15)
	await _foto("c6_vestido")
	print("vestido: ", Corpo.vestido)
	of.sair()
	await _esp(200)
	# ---- lá fora: parado e correndo no chão batido da base (o capim do campo escondia o rabo); voando sobre a
	# planície. O gato e o dente-de-sabre.
	var chao := Vector3(-6.0, 0.0, 44.0)
	var campo := Vector3(-2908.0, 0.0, -835.0)
	for chave: String in ["gato", "sabre"]:
		for parte: String in Corpo.PARTES:
			Corpo.vestido[parte] = chave
		a.visual.vestir_corpo(Corpo.vestido)
		var base := Vector3(chao.x, m.ilha.altura(chao.x, chao.z) + 0.4, chao.z)
		var meio := Vector3(4.0, m.ilha.altura(4.0, 44.0) + 0.4, 44.0)
		a.teleportar(meio, Armadura.Estado.CHAO)
		a.visual.yaw_forcado = -PI * 0.5  # virado para +x
		await _esp(120)
		await _foto_seguindo("r_%s_1_parado" % chave, 2.4, 0.5, 0.5)
		await _esp(40)
		await _foto_seguindo("r_%s_2_balancando" % chave, 2.2, 2.5, 1.0)
		a.visual.yaw_forcado = NAN
		a.teleportar(base, Armadura.Estado.CHAO)
		m.camera.yaw = -PI * 0.5
		await _esp(20)
		Input.action_press("frente")
		Input.action_press("correr")
		await _esp(60)
		await _foto_seguindo("r_%s_3_correndo" % chave, 2.4, 0.45, 0.5)
		Input.action_release("correr")
		Input.action_release("frente")
		await _esp(30)
		var alto := Vector3(campo.x, m.ilha.altura(campo.x, campo.z) + 25.0, campo.z)
		m.camera.yaw = -PI * 0.5
		a.teleportar(alto, Armadura.Estado.VOO, Vector3(18, 0, 0))
		Input.action_press("frente")
		await _esp(60)
		await _foto_seguindo("r_%s_4_voando" % chave, 2.3, 0.6, 0.6)
		Input.action_release("frente")
		a.teleportar(base, Armadura.Estado.CHAO)
		await _esp(60)
	a.teleportar(Vector3(4.0, m.ilha.altura(4.0, 44.0) + 0.4, 44.0), Armadura.Estado.CHAO)
	a.visual.yaw_forcado = -PI * 0.5
	await _esp(60)
	# ---- a fila: cada conjunto lá fora, com todas as melhorias no corpo
	var fila := ["", "urso", "enfermeira", "besouro", "marinheiro", "caldeira", "lucano", "majestade", "samurai", "solar", "cavaleiro", "cachorro"]
	for i in fila.size():
		var chave: String = fila[i]
		for parte: String in Corpo.PARTES:
			Corpo.vestido[parte] = chave
		a.visual.vestir_corpo(Corpo.vestido)
		await _esp(20)
		_de_lado(2.4, -0.9, 0.5)
		await _foto("f%02d_%s_frente" % [i, chave if chave != "" else "original"])
		_de_lado(2.4, 2.4, 0.9)
		await _foto("f%02d_%s_costas" % [i, chave if chave != "" else "original"])
	quit()
