extends SceneTree
# Fotos do cilindro por dentro (doc §138): entra na oficina (ela prende o robô no berço ao abrir) e fotografa
# parado e com as peças afastadas (vista explodida). Uso:
# godot --path . -s tools/fotos_cilindro.gd -- --teste-vale <pasta>/
var m: Node
var a: Armadura
var r: Rotas
var pasta := ""
var cam: Camera3D
var qual := ""
var F: Font
var FB: FontVariation
var FI: FontVariation
const TINTA := Color(0.93, 0.94, 0.9)
const APAGADO := Color(0.62, 0.68, 0.66)
const LARANJA := Color(1.0, 0.62, 0.3)
const AGUA := Color(0.35, 0.95, 0.85)
const LILAS := Color(0.78, 0.66, 1.0)
const VERMELHO := Color(1.0, 0.45, 0.4)
const PAPEL := Color(0.96, 0.92, 0.83)
const TINTA_C := Color(0.18, 0.22, 0.27)
const AZUL_C := Color(0.2, 0.36, 0.62)
const ARMAS := ["pistola", "espada", "duplo", "canhao", "precisao", "rajada", "misseis", "granadas"]

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

func _jogo() -> void:
	m.camera.cam.make_current()

func _perto_da_baliza(id: String) -> void:
	var b: Vector3 = r.lista[id]["baliza"]
	a.teleportar(b + Vector3(1.6, 0.6, 0.0), Armadura.Estado.CHAO)
	await _esp(40)

func _rodar() -> void:
	var args := OS.get_cmdline_user_args()
	for x in args:
		if not x.begins_with("--"):
			pasta = x
	if pasta == "":
		pasta = "/tmp/rotas/"
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
	m.ciclo.hora = 13.0
	m.ciclo.parado = true
	a = m.armadura
	r = m.rotas
	if m.memorias:
		m.memorias.fechar()
	while r.lista.is_empty():
		await physics_frame
	cam = Camera3D.new()
	m.add_child(cam)
	m.ciclo.hora = 12.0
	a.recomecar()
	Melhorias.energia = 100.0
	for nome: String in ["antena", "radiador", "asas", "farol", "amortecedores"]:
		Melhorias.achar(nome)
	a.visual.vestir_melhorias()
	var of: Oficina = m.oficina
	var b := BaseVale.boca_cilindro
	var t := BaseVale.cilindro_t
	var ic := InteriorCilindro.atual
	print("INTERIOR ", ic != null)
	var fora := b + of._eixo() * 0.6
	a.teleportar(Vector3(fora.x, m.ilha.altura(fora.x, fora.z) + 0.4, fora.z), Armadura.Estado.CHAO)
	await _esp(60)
	_livre(t * Vector3(BaseVale.MEIO_CIL + 6.0, 0.4, 3.2), t * Vector3(0.5, -0.6, 0), 50.0)
	await _foto("n0_boca_de_fora")
	of.entrar()
	await _esp(200)
	of._tela.visible = false
	of.armadura.visual.yaw_forcado = atan2(-of._eixo().x, -of._eixo().z) - 0.35
	await _esp(40)
	await _foto("n1_camera_oficina")
	_livre(t * Vector3(BaseVale.MEIO_CIL - 0.1, 0.1, 0.0), t * Vector3(-BaseVale.MEIO_CIL, -0.4, 0), 78.0)
	await _foto("n2_da_boca_para_dentro")
	_livre(t * Vector3(-0.9, 0.1, -1.1), t * Vector3(0.9, -1.0, 0.0), 62.0)
	await _foto("n3_robo_de_tras")
	_livre(t * Vector3(-0.7, -0.35, -0.6), t * Vector3(-1.6, -0.6, 1.7), 60.0)
	await _foto("n4_nichos")
	_livre(t * Vector3(-0.2, -0.2, 0.0), t * Vector3(-3.0, 0.1, 0.0), 62.0)
	await _foto("n5_tela_do_fundo")
	_livre(t * Vector3(0.9 + 1.5, -0.7, 1.1), t * Vector3(0.9, -0.95, 0.0), 55.0)
	await _foto("n6_robo_tres_quartos")
	ic.trabalhar(a.visual, 1.0)
	await _esp(20)
	of._cam.make_current()
	await _foto("w1_instalando_camera_oficina")
	_livre(t * Vector3(0.9 + 1.5, -0.7, 1.1), t * Vector3(0.9, -0.95, 0.0), 55.0)
	await _foto("w2_instalando_tres_quartos")
	_livre(t * Vector3(0.9, -0.8, 1.55), t * Vector3(0.9, -0.95, 0.0), 62.0)
	await _foto("w3_instalando_de_lado")
	_livre(t * Vector3(-0.6, -0.2, -1.0), t * Vector3(0.9, -0.95, 0.0), 58.0)
	await _foto("w4_instalando_de_tras")
	quit()
