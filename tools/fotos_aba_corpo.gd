extends SceneTree
# Fotos da aba Corpo peça por peça (doc §146): no nível 3, as linhas com setas, a planta da direita, a câmera perto
# da parte em foco e longe com o △, uma peça fechada por nível, um braço só, a linha Inteiro, o vestir e o tronco de
# um conjunto de rabo. Uso: godot --path . -s tools/fotos_aba_corpo.gd -- --teste-vale <pasta>/
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


## As setas da linha até a peça `chave`.
func _pecas(linha: String, chave: String) -> void:
	for i in Corpo.ordem().size():
		if String(of._montagem.get("tronco" if linha == "inteiro" else linha, "")) == chave:
			return
		of._trocar_peca(linha, 1)


func _rodar() -> void:
	for x in OS.get_cmdline_user_args():
		if not x.begins_with("--"):
			pasta = x
	if pasta == "":
		pasta = "/tmp/aba_corpo/"
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
	Melhorias.energia = 100.0
	Corpo.tudo = false
	Corpo.zerar()
	a.visual.vestir_corpo(Corpo.vestido)
	Arsenal.xp = 380  # nível 3: abertos até o Besouro e o Marinheiro
	Corpo.resgatados["antigo"] = true  # o antigo acordado; o mergulhador ainda na Represa
	await _esp(20)
	of = m.oficina
	var b := BaseVale.boca_cilindro
	var fora := b + of._eixo() * 0.6
	a.teleportar(Vector3(fora.x, m.ilha.altura(fora.x, fora.z) + 0.4, fora.z), Armadura.Estado.CHAO)
	await _esp(60)
	of.entrar()
	await _esp(200)
	of._mudar_aba(4 - of.aba)
	await _esp(30)
	await _focar("linha_cabeca")
	await _foto("1_abre_na_cabeca")
	_pecas("cabeca", "gato")
	await _esp(30)
	await _foto("2_cabeca_de_gato")
	await _focar("linha_bracoD")
	_pecas("bracoD", "cachorro")
	await _esp(40)
	await _foto("3_braco_d_de_cachorro")
	of._perto = false
	await _esp(40)
	await _foto("4_braco_d_longe")
	await _focar("linha_pernaD")
	_pecas("pernaD", "majestade")
	await _esp(40)
	await _foto("5_perna_d_fechada")
	_pecas("pernaD", "urso")
	await _focar("linha_pernaE")
	_pecas("pernaE", "mergulhador")
	await _esp(40)
	await _foto("6_perna_e_do_mergulhador")
	_pecas("pernaE", "")
	await _focar("linha_tronco")
	_pecas("tronco", "cachorro")
	await _esp(40)
	await _foto("7_tronco_de_cachorro")
	_pecas("tronco", "")
	await _focar("linha_inteiro")
	await _esp(40)
	await _foto("8_inteiro_misturado")
	of.instalar("linha_inteiro")
	await _esp(int(Oficina.T_INSTALAR * 0.5 * 60.0))
	await _foto("9_vestindo")
	await _esp(int(Oficina.T_INSTALAR * 0.5 * 60.0) + 30)
	await _foto("10_vestido")
	print("vestido: ", Corpo.vestido)
	quit()
