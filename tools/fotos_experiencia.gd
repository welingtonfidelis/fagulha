extends SceneTree
# Fotos da experiência (doc §148): o cartão do nível, o pontinho da bússola, o aro de luz na boca do cilindro (de
# dia e de noite), a oficina com o conjunto novo (pontinho na pílula, a aba Corpo abrindo no Inteiro, a estrelinha
# e os pontinhos), o fogo das forjas cheio e em brasa e o resumo da Fundição com o retrato e a brasa.
# Uso: godot --path . -s tools/fotos_experiencia.gd -- --teste-vale <pasta>/
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
	await _esp(10)


func _olhar(d: Vector3) -> void:
	m.camera.yaw = atan2(-d.x, -d.z)
	m.camera.pitch = -0.12


func _no_chao(p: Vector3) -> Vector3:
	return Vector3(p.x, m.ilha.altura(p.x, p.z) + 0.3, p.z)


func _rodar() -> void:
	for x in OS.get_cmdline_user_args():
		if not x.begins_with("--"):
			pasta = x
	if pasta == "":
		pasta = "/tmp/experiencia/"
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
	Corpo.tudo = false
	Corpo.zerar()
	a.visual.vestir_corpo(Corpo.vestido)
	Arsenal.descobertas = {}
	Arsenal.folego = Arsenal.FOLEGO_MAX
	Arsenal.xp = Arsenal.xp_do_nivel(3) - 40  # nível 2, perto do 3 (o primeiro conjunto, o Gato; doc §154)
	of = m.oficina
	if "--so-forja" in OS.get_cmdline_user_args():
		await _forja()
		quit()
		return
	var b := BaseVale.boca_cilindro
	var eixo: Vector3 = of._eixo()
	# 1. longe da base, olhando para ela: uma descoberta sobe o nível
	var longe := _no_chao(b + eixo * 70.0)
	a.teleportar(longe, Armadura.Estado.CHAO)
	_olhar(-eixo)
	await _esp(330)  # o nome do lugar da chegada passa
	m.hud.avisar("Semente achada!", "plante no canteiro da horta, na base")
	Experiencia.descobrir("foto:semente", Experiencia.LUGAR)
	await _esp(40)
	await _foto("1_aviso_primeiro")  # o cartão espera o aviso passar
	while m.hud.aviso_na_tela():
		await physics_frame
	await _esp(30)
	await _foto("1b_cartao_abrindo")
	await _esp(40)
	m.hud.avisar("O Vilarejo", "")  # um lugar no meio do cartão: o nome desce para debaixo dele
	await _esp(40)
	await _foto("2_cartao_e_lugar")
	await _esp(400)
	await _foto("3_bussola_pontinho")
	# dois níveis de uma vez (o 4 e o 5: Cachorro e Urso)
	Arsenal.xp = Arsenal.xp_do_nivel(4) - 40
	Experiencia.descobrir("foto:memoria", Arsenal.xp_do_nivel(5) - Arsenal.xp + 20)
	await _esp(110)
	await _foto("4_cartao_dois_niveis")
	# um robô achado: o cartão sem nível
	await _esp(360)
	Corpo.resgatados["antigo"] = true
	Experiencia.atual.conjunto_novo("antigo")
	await _esp(110)
	await _foto("5_cartao_robo_achado")
	await _esp(360)
	# 2. a boca do cilindro, de frente
	var frente := _no_chao(b + eixo * 13.0)
	a.teleportar(frente, Armadura.Estado.CHAO)
	_olhar(-eixo)
	await _esp(90)
	Experiencia.atual._pulso = 1.3  # o pico da respiração
	await _foto("6_boca_de_dia_cheia")
	Experiencia.atual._pulso = 0.0  # o fundo
	await _foto("6b_boca_de_dia_fraca")
	m.ciclo.hora = 20.5
	await _esp(90)
	Experiencia.atual._pulso = 1.3
	await _foto("7_boca_de_noite")
	m.ciclo.hora = 10.0
	# 3. a oficina: o pontinho na pílula, a aba Corpo no conjunto novo, a estrelinha e os pontinhos
	var fora := b + eixo * 0.6
	a.teleportar(Vector3(fora.x, m.ilha.altura(fora.x, fora.z) + 0.4, fora.z), Armadura.Estado.CHAO)
	await _esp(60)
	of.entrar()
	await _esp(200)
	await _foto("8_oficina_pilula")
	of._mudar_aba(4 - of.aba)
	await _esp(20)
	await _foto("9_corpo_abre_no_novo")
	print("montagem: ", of._montagem, " novos: ", Corpo.novos())
	await _esp(120)
	print("depois de ver: ", Corpo.novos())
	await _focar("linha_cabeca")
	await _esp(30)
	await _foto("10_pontinhos_com_estrela")
	of.sair()
	await _esp(300)
	await _forja()
	# 5. o resumo da rodada, com o conjunto novo e a brasa
	var linhas := [["Ondas vencidas", "6"], ["Recorde", "onda 6 · novo"], ["Robôs desligados", "14"],
		["Experiência", "+460 · nível %d" % Arsenal.nivel()], ["Materiais", "sucata +9 · núcleos +2 · chips +1"], ["Recomeça na", "onda 1"]]
	var dados := {"ondas": 6, "recorde": 6, "vencidos": 14, "xp": 460, "sucata": 9, "nucleos": 2, "chips": 1,
		"perdeu_metade": false, "conjuntos": ["besouro"], "sem_folego": true}
	m.hud.mostrar_resumo("Você saiu da Fundição", linhas, true, dados)
	await _esp(90)
	await _foto("13_resumo")
	quit()


## O fogo das forjas: cheio e em brasa, de frente para a primeira forja (do meio do galpão para ela).
func _forja() -> void:
	if Fundicao.luzes_forja.is_empty():
		print("sem forjas")
		return
	var luz := Fundicao.luzes_forja[0].global_position
	var meio := Vector3(Fundicao.CENTRO.x, luz.y, Fundicao.CENTRO.y)
	var d := meio - luz
	d.y = 0.0
	d = d.normalized()
	a.teleportar(_no_chao(luz + d * 7.0), Armadura.Estado.CHAO)
	_olhar(-d)
	Arsenal.folego = Arsenal.FOLEGO_MAX
	await _esp(240)
	_olhar(-d)
	await _foto("11_forja_folego_cheio")
	Arsenal.folego = 0.0
	await _esp(300)
	_olhar(-d)
	await _foto("12_forja_em_brasa")
