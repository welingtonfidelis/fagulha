extends SceneTree
# Fotos dos robôs achados morando na base (doc §144): os conjuntos deles na aba Corpo (fechado, com a figura do
# lugar, e aberto), o antigo na horta, na beira da laje, no banco da fogueira, pulando e no telhado de noite,
# o mergulhador na margem e nadando, um aceno, e o robô vestido com cada um dos dois conjuntos. Uso:
# godot --path . -s tools/fotos_achados.gd -- --teste-vale <pasta>/
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


func _livre(de: Vector3, para: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.global_position = de
	cam.look_at(para)
	cam.make_current()


## A câmera olhando um amigo: `giro` 0 é de frente para ele, positivo vai para a direita dele.
func _olhar(r: AmigoRobo, dist := 2.8, giro := 0.5, alto := 0.9, alvo_y := 0.6, fov := 46.0) -> void:
	var f := Vector3(sin(r.rotation.y), 0, cos(r.rotation.y))
	var d := f.rotated(Vector3.UP, giro)
	var p := r.global_position
	_livre(p + d * dist + Vector3(0, alto, 0), p + Vector3(0, alvo_y, 0), fov)


func _focar(of: Oficina, nome: String) -> void:
	(of._botoes[nome] as Control).grab_focus()
	await _esp(25)


## Na aba Corpo, as setas da linha até a peça `chave`.
func _pecas(of: Oficina, linha: String, chave: String) -> void:
	for i in Corpo.ordem().size():
		if String(of._montagem.get("tronco" if linha == "inteiro" else linha, "")) == chave:
			return
		of._trocar_peca(linha, 1)


func _por(r: AmigoRobo, lugar: String, estado := "") -> void:
	var l: Array = r.lugares[lugar]
	r._pos = l[0]
	r._yaw = AmigoRobo._yaw_de(l[1])
	r._parar(estado if estado != "" else lugar)
	r._aceno = 0.0
	r._longe = false


func _rodar() -> void:
	var args := OS.get_cmdline_user_args()
	for x in args:
		if not x.begins_with("--"):
			pasta = x
	if pasta == "":
		pasta = "/tmp/achados/"
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
	cam = Camera3D.new()
	m.add_child(cam)
	a.recomecar()
	Melhorias.energia = 100.0
	var ra: RoboAntigo = m.robo_antigo
	await _esp(20)
	# ---- a aba Corpo: os dois conjuntos fechados (a sombra e a figura do lugar), depois o antigo acordado
	Corpo.tudo = false
	var of: Oficina = m.oficina
	var b := BaseVale.boca_cilindro
	var fora := b + of._eixo() * 0.6
	a.teleportar(Vector3(fora.x, m.ilha.altura(fora.x, fora.z) + 0.4, fora.z), Armadura.Estado.CHAO)
	await _esp(60)
	of.entrar()
	await _esp(200)
	of._mudar_aba(4 - of.aba)
	await _esp(20)
	await _focar(of, "linha_cabeca")
	_pecas(of, "cabeca", "antigo")
	await _esp(30)
	await _foto("a1_aba_antigo_fechado")
	_pecas(of, "cabeca", "mergulhador")
	await _esp(30)
	await _foto("a2_aba_mergulhador_fechado")
	of.sair()
	await _esp(120)
	# acorda os dois (como se o robô tivesse ido lá)
	ra.achar_robo(0)
	await _esp(10)
	m.memorias.fechar()
	ra.achar_robo(1)
	await _esp(10)
	m.memorias.fechar()
	await _esp(30)
	of.entrar()
	await _esp(200)
	of._mudar_aba(4 - of.aba)
	await _esp(20)
	await _focar(of, "linha_cabeca")
	_pecas(of, "cabeca", "antigo")
	await _esp(30)
	await _foto("a3_aba_antigo_aberto")
	await _focar(of, "linha_inteiro")
	_pecas(of, "inteiro", "mergulhador")
	of.instalar("linha_inteiro")
	await _esp(int(Oficina.T_INSTALAR * 60.0) + 20)
	await _foto("a4_aba_mergulhador_vestido")
	of.sair()
	await _esp(200)
	# ---- o robô vestido com cada conjunto, na laje
	var laje := Vector3(4.0, m.ilha.altura(4.0, 44.0) + 0.4, 44.0)
	for chave: String in ["mergulhador", "antigo"]:
		for parte: String in Corpo.PARTES:
			Corpo.vestido[parte] = chave
		a.visual.vestir_corpo(Corpo.vestido)
		a.teleportar(laje, Armadura.Estado.CHAO)
		a.visual.yaw_forcado = -PI * 0.5
		await _esp(90)
		var p := a.global_position
		_livre(p + Vector3(2.1, 0.75, 1.3), p + Vector3(0, 0.55, 0), 42.0)
		await _foto("v_%s_vestido" % chave)
	a.visual.yaw_forcado = NAN
	Corpo.zerar()
	a.visual.vestir_corpo(Corpo.vestido)
	# o robô do jogador longe, para não roubar a cena (e sem acenos)
	a.teleportar(Vector3(60.0, m.ilha.altura(60.0, 120.0) + 0.4, 120.0), Armadura.Estado.CHAO)
	await _esp(30)
	var ant: AmigoRobo = ra.amigos[0]
	var mer: AmigoRobo = ra.amigos[1]
	print("lugares do antigo: ", ant.lugares.keys(), "  do mergulhador: ", mer.lugares.keys(), " roda ", mer.roda.size(), " nivel ", mer.nivel_agua)
	# ---- o antigo de dia
	for lugar: String in ["horta", "campo", "banco"]:
		if not ant.lugares.has(lugar):
			print("sem lugar ", lugar)
			continue
		_por(ant, lugar)
		await _esp(40)
		_olhar(ant, 2.6, 0.55 if lugar != "horta" else 1.3, 0.8 if lugar != "horta" else 1.3, 0.5)
		await _foto("b_antigo_%s" % lugar)
		if lugar == "campo":
			_olhar(ant, 3.2, 2.5, 1.2, 0.5)
			await _foto("b_antigo_campo_costas")
	# de longe, a base com ele no banco
	_olhar(ant, 9.0, 0.3, 3.0, 0.5, 50.0)
	await _foto("b_antigo_banco_longe")
	# o pulo para o telhado
	m.ciclo.hora = 19.0
	_por(ant, "telhado_chao", "campo")
	ant._t = 0.0
	m.ciclo.hora = 20.5
	await _esp(4)
	var chao_t: Vector3 = (ant.lugares["telhado_chao"] as Array)[0]
	ant._pos = chao_t
	ant.estado = "andando"
	ant._alvo = chao_t
	ant._depois = "pulo_sobe"
	await _esp(int(AmigoRobo.SALTO * 0.5 * 60.0) + 2)
	print("estado no pulo: ", ant.estado)
	var tb := BaseVale.t_base
	_livre(tb * Vector3(-2.6 + 4.5, 2.2, -8.5), ant.global_position + Vector3(0, 0.5, 0), 50.0)
	await _foto("c_antigo_pulando")
	# no telhado, de noite
	m.ciclo.hora = 22.5
	await _esp(60)
	_por(ant, "telhado")
	await _esp(40)
	_livre(tb * Vector3(-2.6 + 2.2, 3.6, -4.2), ant.global_position + Vector3(0, 0.6, 0), 48.0)
	await _foto("c_antigo_telhado_noite")
	_livre(tb * Vector3(-2.6 + 6.0, 1.4, -13.0), ant.global_position + Vector3(0, 0.0, 0), 55.0)
	await _foto("c_antigo_telhado_longe")
	# ---- o mergulhador, de dia
	m.ciclo.hora = 10.0
	await _esp(60)
	_por(mer, "beira")
	await _esp(40)
	_olhar(mer, 3.0, 0.7, 0.9, 0.2)
	await _foto("d_mergulhador_beira")
	_olhar(mer, 8.0, 0.25, 3.6, 0.3, 50.0)
	await _foto("d_mergulhador_beira_longe")
	if not mer.roda.is_empty():
		mer._pos = mer.roda[0]
		mer._parar("nadando")
		await _esp(90)
		_olhar(mer, 3.4, 0.6, 1.4, -0.1)
		await _foto("d_mergulhador_nadando")
	# ---- o aceno: o robô vem de longe e chega perto do antigo na horta
	_por(ant, "horta")
	var h: Vector3 = (ant.lugares["horta"] as Array)[0]
	var de := h + Vector3(5.0, 0, 3.0)
	a.teleportar(Vector3(de.x, m.ilha.altura(de.x, de.z) + 0.4, de.z), Armadura.Estado.CHAO)
	ant._longe = true
	await _esp(50)
	print("acenos do antigo: ", ant.acenos)
	var pa := a.global_position - ant.global_position
	pa.y = 0
	pa = pa.normalized()
	_livre(ant.global_position + pa * 3.0 + pa.cross(Vector3.UP) * 0.9 + Vector3(0, 1.2, 0), ant.global_position + Vector3(0, 0.75, 0), 46.0)
	await _foto("e_aceno_perto")
	var dir := (a.global_position - ant.global_position)
	dir.y = 0
	dir = dir.normalized()
	var lado := dir.cross(Vector3.UP)
	_livre(a.global_position + dir * 2.4 + lado * 1.2 + Vector3(0, 1.5, 0), ant.global_position + Vector3(0, 0.7, 0), 50.0)
	await _foto("e_aceno")
	# e o mergulhador acenando de dentro da água
	_por(mer, "beira")
	var bm: Vector3 = (mer.lugares["beira"] as Array)[0] + (mer.lugares["beira"] as Array)[1] * 7.0
	a.teleportar(Vector3(bm.x, m.ilha.altura(bm.x, bm.z) + 0.4, bm.z), Armadura.Estado.CHAO)
	mer._longe = true
	await _esp(50)
	print("acenos do mergulhador: ", mer.acenos)
	var dm := (a.global_position - mer.global_position)
	dm.y = 0
	dm = dm.normalized()
	_livre(mer.global_position + dm * 3.2 + dm.cross(Vector3.UP) * 0.8 + Vector3(0, 1.3, 0), mer.global_position + Vector3(0, 0.45, 0), 45.0)
	await _foto("e_aceno_mergulhador")
	quit()
