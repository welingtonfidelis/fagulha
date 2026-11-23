extends SceneTree
# Fotos das armas que saem do punho e dos jatos nos cantos da mochila (2026-11-23): cada arma com o braço apontado,
# de cima, de frente (a boca), de três quartos e pela câmera do jogo, e a troca da mão pela arma em cinco passos;
# com --jatos, também a mochila de costas, de lado e com os jatos acesos. Cada arma vira uma folha.
# Com --conjuntos, em vez disso, a pistola em cada conjunto do corpo: a boca do punho aberta, de frente, e a arma
# fora, de três quartos.
# Com --detalhes: a Antena de busca no mastro, a pata do gato, os braços do cachorro e da caldeira e a mochila
# com o tronco de cada conjunto (asas abertas).
# Com --lancadores: granada e míssil disparados pelo próprio jogo (o braço direito fica parado).
# Uso: godot --path . -s tools/fotos_armas_jatos.gd -- --teste-vale [--jatos | --conjuntos | --detalhes | --lancadores] <pasta>/
var m: Node
var a: Armadura
var pasta := ""
var cam: Camera3D
var cam_jogo: Camera3D
var fundo: MeshInstance3D
var mirar := false
var duplo := false
var vitrine := 0.0
var com_jatos := false
var conjuntos := false
var detalhes := false
var lancadores := false
var imagens := {}
const PASSOS := [0.0, 0.3, 0.5, 0.75, 1.0]

const ARMAS := {
	"pistola": "arma_pistola",
	"rajada": "arma_rajada",
	"precisao": "arma_precisao",
	"canhao": "arma_canhao",
	"duplo": "arma_duplo",
}


func _initialize() -> void:
	_rodar()


func _esp(n: int) -> void:
	for i in n:
		if a == null:
			await physics_frame
			continue
		# o braço aponta com o tiro (o `mirando` volta ao botão a cada quadro); no duplo, os dois braços
		a.atirando = 0.5 if mirar else 0.0
		a.atirando_e = 0.5 if duplo else 0.0
		a.visual.jatos_vitrine = vitrine
		await physics_frame


func _foto(nome: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(pasta + nome + ".png")
	imagens[nome] = img
	print("foto ", nome)


## Junta as fotos numa folha, cada uma reduzida `div` vezes, em `cols` colunas sobre fundo escuro.
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


func _esconder() -> void:
	for c in m.get_children():
		if c is CanvasLayer:
			c.visible = false


## A câmera de fotos em `pos` olhando `alvo`, com o fundo liso atrás do alvo.
func _camera(pos: Vector3, alvo: Vector3, up := Vector3.UP, fov := 28.0, com_fundo := true) -> void:
	cam.current = true
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(alvo, up)
	fundo.visible = com_fundo
	fundo.global_position = alvo + (alvo - pos).normalized() * 0.45
	fundo.look_at(pos, up)


func _rodar() -> void:
	for x in OS.get_cmdline_user_args():
		if x == "--jatos":
			com_jatos = true
		elif x == "--conjuntos":
			conjuntos = true
		elif x == "--detalhes":
			detalhes = true
		elif x == "--lancadores":
			lancadores = true
		elif not x.begins_with("--"):
			pasta = x
	if pasta == "":
		pasta = "/tmp/armas_jatos/"
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
	await _esp(20)
	var b := BaseVale.boca_cilindro
	var eixo: Vector3 = m.oficina._eixo()
	var p := b + eixo * 40.0
	a.teleportar(Vector3(p.x, m.ilha.altura(p.x, p.z) + 0.4, p.z), Armadura.Estado.CHAO)
	await _esp(60)
	_esconder()
	cam_jogo = root.get_camera_3d()
	cam = Camera3D.new()
	root.add_child(cam)
	for n in root.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if env:
			env.glow_enabled = false
	fundo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(6, 6)
	fundo.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.55, 0.62, 0.7)
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fundo.material_override = fm
	root.add_child(fundo)
	var v: ArmaduraVisual = a.visual
	if conjuntos:
		await _conjuntos(v)
		quit()
		return
	if detalhes:
		await _detalhes(v)
		quit()
		return
	if lancadores:
		await _lancadores(v)
		quit()
		return
	for arma in ARMAS:
		v.vestir_melhorias([ARMAS[arma]])
		duplo = arma == "duplo"
		mirar = true
		v.arma_vitrine = -1.0
		await _esp(90)
		var cot := (v.j["cotoveloD"] as Node3D).global_position
		var boca := v.boca_da_arma(false).global_position
		var f := (boca - cot).normalized()  # ao longo do antebraço, para a boca
		var dir := f.cross(Vector3.UP).normalized()  # para fora, à direita do robô
		var c := cot.lerp(boca, 0.62)
		_camera(c + Vector3.UP * 0.62, c, f)
		await _esp(6)
		await _foto("%s_1_cima" % arma)
		_camera(boca + f * 0.62 + Vector3.UP * 0.03, boca)
		await _esp(6)
		await _foto("%s_2_frente" % arma)
		_camera(c + dir * 0.5 + f * 0.28 + Vector3.UP * 0.24, c, Vector3.UP, 34.0)
		await _esp(6)
		await _foto("%s_3_tres_quartos" % arma)
		_camera(c - f * 1.15 + dir * 0.62 + Vector3.UP * 0.32, c + f * 0.12, Vector3.UP, 38.0, false)
		await _esp(6)
		await _foto("%s_4_ombro" % arma)
		_folha(["%s_1_cima" % arma, "%s_2_frente" % arma, "%s_3_tres_quartos" % arma, "%s_4_ombro" % arma], 2,
			"folha_%s" % arma)
		# a troca: a mão fechada entra, a boca do punho aparece e a arma sai (de lado, mais perto)
		var passos: Array = []
		for i in PASSOS.size():
			v.arma_vitrine = PASSOS[i]
			_camera(c + dir * 0.36 + f * 0.24 + Vector3.UP * 0.16, cot.lerp(boca, 0.8), Vector3.UP, 34.0)
			await _esp(4)
			var nm := "%s_5_troca_%d" % [arma, i]
			await _foto(nm)
			passos.append(nm)
		v.arma_vitrine = -1.0
		_folha(passos, 3, "troca_%s" % arma)
	if not com_jatos:
		quit()
		return
	# a mochila: de costas, de lado e com os jatos acesos
	v.vestir_melhorias([])
	duplo = false
	mirar = false
	await _esp(60)
	var bas := v.global_basis.orthonormalized()
	var frente := -bas.z
	var costas := (v.j["costas"] as Node3D).global_position if v.j.get("costas") is Node3D else a.global_position + Vector3.UP * 0.7
	var lado := bas.x
	costas -= Vector3.UP * 0.08
	_camera(costas - frente * 1.4 + Vector3.UP * 0.05, costas, Vector3.UP, 34.0)
	await _esp(6)
	await _foto("jatos_1_costas")
	_camera(costas - lado * 1.4 - frente * 0.14, costas - frente * 0.14, Vector3.UP, 34.0)
	await _esp(6)
	await _foto("jatos_2_lado")
	vitrine = 1.2
	await _esp(40)
	_camera(costas - frente * 1.0 + lado * 0.6 + Vector3.UP * 0.35, costas - Vector3.UP * 0.1, Vector3.UP, 40.0, false)
	await _esp(6)
	await _foto("jatos_3_acesos")
	_camera(costas - lado * 1.3 - frente * 0.2, costas - frente * 0.1 - Vector3.UP * 0.12, Vector3.UP, 40.0)
	await _esp(6)
	await _foto("jatos_4_acesos_lado")
	quit()


func _conjuntos(v: ArmaduraVisual) -> void:
	mirar = true
	var vaos: Array = []
	var foras: Array = []
	for c: Array in Corpo.CONJUNTOS:
		var chave: String = c[0]
		var pedido := {}
		for parte: String in Corpo.PARTES:
			pedido[parte] = chave
		v.vestir_corpo(pedido)
		v.arma_vitrine = 1.0
		await _esp(40)
		var cot := (v.j["cotoveloD"] as Node3D).global_position
		var boca := v.boca_da_arma(false).global_position
		var f := (boca - cot).normalized()
		var dir := f.cross(Vector3.UP).normalized()
		var cc := cot.lerp(boca, 0.62)
		_camera(cc + dir * 0.5 + f * 0.28 + Vector3.UP * 0.24, cc, Vector3.UP, 34.0)
		await _esp(4)
		await _foto("conj_%s_fora" % chave)
		foras.append("conj_%s_fora" % chave)
		v.arma_vitrine = 0.5
		_camera(boca + f * 0.62 + Vector3.UP * 0.03, boca)
		await _esp(4)
		await _foto("conj_%s_vao" % chave)
		vaos.append("conj_%s_vao" % chave)
	v.arma_vitrine = -1.0
	_folha(foras, 4, "conjuntos_arma_fora", 3)
	_folha(vaos, 4, "conjuntos_boca_do_punho", 3)


func _todo(chave: String) -> Dictionary:
	var pedido := {}
	for parte: String in Corpo.PARTES:
		pedido[parte] = chave
	return pedido


func _detalhes(v: ArmaduraVisual) -> void:
	mirar = false
	v.previa = true
	var bas := v.global_basis.orthonormalized()
	var frente := -bas.z
	var lado := bas.x
	# a Antena de busca no mastro: a cabeça de fábrica e a do Antigo
	for cab_chave in ["", "antigo"]:
		v.vestir_corpo({"cabeca": cab_chave})
		await _esp(30)
		var cab := (v.j["cabeca"] as Node3D).global_position
		var topo := cab + Vector3.UP * 0.5
		var mastro := MelhoriasVisual._mastro(v)
		if mastro != null:
			var cx := mastro.global_transform * mastro.get_aabb()
			topo = cx.position + cx.size * 0.5 + Vector3.UP * cx.size.y * 0.5
		var meio := cab.lerp(topo, 0.55)
		var nome: String = "antena_" + (cab_chave if cab_chave != "" else "fabrica")
		_camera(meio + frente * 1.25 + lado * 0.75 + Vector3.UP * 0.3, meio, Vector3.UP, 30.0)
		await _esp(4)
		await _foto(nome + "_1")
		_camera(meio + frente * 1.25 - lado * 0.75 + Vector3.UP * 0.3, meio, Vector3.UP, 30.0)
		await _esp(4)
		await _foto(nome + "_2")
	_folha(["antena_fabrica_1", "antena_fabrica_2", "antena_antigo_1", "antena_antigo_2"], 2, "detalhe_antena")
	# os braços: a pata do gato encostada e o cachorro e a caldeira sem cano
	var bracos: Array = []
	for chave in ["gato", "cachorro", "caldeira"]:
		v.vestir_corpo(_todo(chave))
		await _esp(40)
		var pu := (v.j["punhoD"] as Node3D).global_position
		var lu := (v.j["luvaD"] as Node3D).global_position
		var fora := pu - (v.j["tronco"] as Node3D).global_position
		fora.y = 0.0
		fora = fora.normalized()
		var alvo := lu.lerp(pu, 0.75)
		_camera(alvo + fora * 0.55 + frente * 0.45 + Vector3.UP * 0.12, alvo, Vector3.UP, 34.0)
		await _esp(4)
		await _foto("braco_%s_1" % chave)
		_camera(alvo + frente * 0.75 + Vector3.UP * 0.05, alvo, Vector3.UP, 34.0)
		await _esp(4)
		await _foto("braco_%s_2" % chave)
		bracos.append_array(["braco_%s_1" % chave, "braco_%s_2" % chave])
	_folha(bracos, 2, "detalhe_bracos")
	# a mochila e as asas na cor do tronco vestido (só o tronco; o resto de fábrica)
	var cores: Array = []
	for chave in ["", "besouro", "gato", "caldeira", "enfermeira", "lucano", "cavaleiro", "solar"]:
		v.vestir_corpo({"tronco": chave})
		await _esp(40)
		var co := (v.j["costas"] as Node3D).global_position
		_camera(co - frente * 1.7 + lado * 0.75 + Vector3.UP * 0.45, co - Vector3.UP * 0.05, Vector3.UP, 36.0)
		await _esp(4)
		var nm: String = "mochila_" + (chave if chave != "" else "fabrica")
		await _foto(nm)
		cores.append(nm)
	_folha(cores, 4, "detalhe_mochila_cores", 3)
	v.vestir_corpo({})


## Duas fotos do momento: de frente (três quartos) e pela câmera do jogo.
func _duas(v: ArmaduraVisual, nome: String) -> void:
	var bas := v.global_basis.orthonormalized()
	var frente := -bas.z
	var lado := bas.x
	var c := a.global_position + Vector3.UP * 0.75
	_camera(c + frente * 2.2 + lado * 1.1 + Vector3.UP * 0.3, c, Vector3.UP, 36.0, false)
	await _foto(nome + "_frente")
	cam_jogo.current = true
	fundo.visible = false
	await _foto(nome + "_jogo")


func _lancadores(v: ArmaduraVisual) -> void:
	mirar = false
	v.vestir_melhorias(["lanca_misseis", "lanca_granadas"])
	await _esp(30)
	# a granada: segurando o botão (o arco) e logo depois de soltar
	Arsenal.granadas = 3
	cam_jogo.current = true
	Input.action_press("granada")
	await _esp(40)
	await _duas(v, "granada_1_segura")
	Input.action_release("granada")
	await _esp(4)
	await _duas(v, "granada_2_solta")
	await _esp(90)
	# os mísseis: no modo de mísseis, mirando (L2) e segurando o gatilho para travar, e logo depois de soltar
	Arsenal.modo = "misseis"
	Arsenal.misseis = 8
	v.vestir_melhorias(["lanca_misseis", "lanca_granadas"])
	cam_jogo.current = true
	Input.action_press("mirar")
	Input.action_press("atirar")
	await _esp(40)
	await _duas(v, "missil_1_trava")
	Input.action_release("atirar")
	await _esp(5)
	await _duas(v, "missil_2_sai")
	Input.action_release("mirar")
	Arsenal.modo = "pistola"
	_folha(["granada_1_segura_frente", "granada_1_segura_jogo", "granada_2_solta_frente", "granada_2_solta_jogo",
		"missil_1_trava_frente", "missil_1_trava_jogo", "missil_2_sai_frente", "missil_2_sai_jogo"], 2, "lancadores", 2)

