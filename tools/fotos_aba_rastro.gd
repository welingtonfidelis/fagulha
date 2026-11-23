extends SceneTree
# Fotos da aba Jatos (doc §147): o robô de costas sobe um pouco na pose da subida, com o fogo dos pés e das costas na
# cor em foco; ao trocar de aba ele volta ao estrado. Uso: godot --path . -s tools/fotos_aba_rastro.gd -- --teste-vale <pasta>/
var m: Node
var a: Armadura
var of: Oficina
var pasta := ""


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


func _focar(nome: String) -> void:
	(of._botoes[nome] as Control).grab_focus()
	await _esp(40)


func _rodar() -> void:
	for x in OS.get_cmdline_user_args():
		if not x.begins_with("--"):
			pasta = x
	if pasta == "":
		pasta = "/tmp/aba_rastro/"
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
	m.ciclo.hora = 10.0
	m.ciclo.parado = true
	a = m.armadura
	if m.memorias:
		m.memorias.fechar()
	a.recomecar()
	Rotas.feitas = {"rio": 1, "mastro": 1}
	Rotas.rastro = ""
	await _esp(20)
	of = m.oficina
	var b := BaseVale.boca_cilindro
	var fora := b + of._eixo() * 0.6
	a.teleportar(Vector3(fora.x, m.ilha.altura(fora.x, fora.z) + 0.4, fora.z), Armadura.Estado.CHAO)
	await _esp(60)
	of.entrar()
	await _esp(200)
	await _foto("0_estrado")
	of._mudar_aba(3 - of.aba)
	await _esp(30)
	await _focar("rastro_rio")
	await _esp(30)
	await _foto("1_rio")
	await _focar("rastro_mastro")
	await _esp(60)
	await _foto("2_mastro")
	await _focar("rastro_ninho")
	await _esp(60)
	await _foto("3_ninho_fechada")
	await _focar("rastro_")
	await _esp(60)
	await _foto("4_de_fabrica")
	print("no ar: ", of._berco().no_ar() if of._berco() else -1.0)
	of._mudar_aba(1)
	await _esp(80)
	await _foto("5_aba_corpo_no_estrado")
	print("no ar depois: ", of._berco().no_ar() if of._berco() else -1.0, " jatos ", a.visual.jatos_vitrine)
	# lá fora, pairando no alto com o vermelho em uso
	Rotas.rastro = "mastro"
	of.sair()
	await _esp(300)
	var p := a.global_position + of._eixo() * 40.0
	a.teleportar(Vector3(p.x, m.ilha.altura(p.x, p.z) + 0.2, p.z), Armadura.Estado.CHAO)
	await _esp(60)
	a._decolar()  # a subida de segurar o X
	await _esp(30)
	await _foto("6_decolando_vermelho")
	await _esp(40)
	await _foto("7_subindo_vermelho")
	m.ciclo.hora = 20.5  # de noite a cor aparece mais
	a.teleportar(Vector3(p.x, m.ilha.altura(p.x, p.z) + 0.2, p.z), Armadura.Estado.CHAO)
	await _esp(60)
	a._decolar()
	await _esp(45)
	await _foto("8_subindo_de_noite")
	quit()
