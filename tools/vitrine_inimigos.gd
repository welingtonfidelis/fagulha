extends SceneTree
## Fotos dos robôs inimigos do projeto (InimigoVisual) num estúdio liso, em cada pose.
## godot --path . -s tools/vitrine_inimigos.gd      (as fotos vão para tools/capturas/inimigos/)

var cam: Camera3D
var comuns: Array[InimigoVisual] = []
var chefes: Array[InimigoVisual] = []


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var amb := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.42, 0.44)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.84, 0.88)
	e.ambient_light_energy = 0.7
	amb.environment = e
	root.add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38, 150, 0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	root.add_child(sol)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	chao.mesh = pm
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.33, 0.39, 0.4)
	chao.material_override = mc
	root.add_child(chao)
	cam = Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.make_current()
	_rodar()


func _por(tipo: String, arma: String, onde: Vector3, alt: float, chefe: bool) -> InimigoVisual:
	InimigoVisual.forcar = arma
	InimigoVisual.forcar_modelo = tipo
	var v := InimigoVisual.montar(comuns.size() * 5 + chefes.size() * 3 + 2, alt, null, chefe)
	InimigoVisual.forcar = ""
	InimigoVisual.forcar_modelo = ""
	root.add_child(v)
	v.position = onde
	return v


func _jogador(onde: Vector3) -> void:
	var cena: PackedScene = load("res://assets/vale/robo_v2.glb")
	var r := cena.instantiate() as Node3D
	root.add_child(r)
	var cx := BaseVale._caixa(r)
	r.scale = Vector3.ONE * 1.2 / cx.size.y
	r.position = onde
	# o modelo olha para +Z: assim ele fica de frente para os inimigos


func _esp(n: int) -> void:
	for i in n:
		await process_frame


func _foto(nome: String, de: Vector3, alvo: Vector3) -> void:
	cam.position = de
	cam.look_at(alvo)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/capturas/inimigos/%s.png" % nome)


func _todos() -> Array[InimigoVisual]:
	return comuns + chefes


func _rodar() -> void:
	DirAccess.make_dir_recursive_absolute("res://tools/capturas/inimigos")
	var alts := {"lata": 1.8, "guarda": 1.9, "barril": 1.6}
	var fam := 0
	for tipo: String in InimigoVisual.FAMILIAS:
		var k := 0
		for arma: String in ["bala", "corpo", "missil"]:
			comuns.append(_por(tipo, arma, Vector3((fam * 3 + k) * 1.7 - 6.8 + fam * 0.6, 0, 0), alts[tipo], false))
			k += 1
		fam += 1
	for i in 3:
		chefes.append(_por(InimigoVisual.CHEFES[i], "", Vector3(i * 4.2 + 24.0, 0, 0), 3.0, true))
	for v in comuns:
		_jogador(v.position + Vector3(0, 0, -2.0))
		v.alvo_mira = v.position + Vector3(0, 0.6, -2.0)
	for v in chefes:
		_jogador(v.position + Vector3(0, 0, -2.6))
		v.alvo_mira = v.position + Vector3(0, 0.6, -2.6)
	var de_c := Vector3(-2.0, 2.0, -9.5)
	var em_c := Vector3(-5.1, 0.85, 0.0)
	var de_c2 := Vector3(3.0, 2.0, -11.5)
	var em_c2 := Vector3(3.4, 0.85, 0.0)
	var de_ch := Vector3(25.0, 3.6, -15.5)
	var em_ch := Vector3(28.2, 1.5, 0.0)
	await _esp(30)
	await _foto("1_comuns_parados_1", de_c, em_c)
	await _foto("1_comuns_parados_2", de_c2, em_c2)
	await _foto("1_chefes_parados", de_ch, em_ch)
	for v in _todos():
		v.tocar("Run", 1.0)
	await _esp(34)
	await _foto("2_comuns_correndo_1", de_c, em_c)
	await _foto("2_comuns_correndo_2", de_c2, em_c2)
	await _foto("2_chefes_correndo", de_ch, em_ch)
	for v in _todos():
		v.tocar("Idle")
	await _esp(30)
	# o ataque em três tempos: começo, meio (quando o tiro sai ou a lâmina passa) e fim
	for v in _todos():
		v.tocar("Shoot")
	var vistos := 0.0
	for passo: Array in [[0.24, "a"], [0.42, "b"], [0.62, "c"]]:
		while comuns[0].tempo_ataque < float(passo[0]):
			await process_frame
		await _foto("3_comuns_ataque_%s_1" % passo[1], de_c, em_c)
		await _foto("3_comuns_ataque_%s_2" % passo[1], de_c2, em_c2)
		await _foto("3_chefes_ataque_%s" % passo[1], de_ch, em_ch)
	await _foto("4_comuns_ataque_lado", Vector3(-13.0, 1.5, -1.0), Vector3(-5.0, 0.9, -1.0))
	await _foto("4_chefes_ataque_lado", Vector3(18.0, 2.2, -1.3), Vector3(26.0, 1.5, -1.3))
	for v in _todos():
		v.tocar("Death")
		v.apagar(1.0)
		v.olho(0.0)
	await _esp(90)
	await _foto("5_comuns_desligados_1", de_c, em_c)
	await _foto("5_comuns_desligados_2", de_c2, em_c2)
	await _foto("5_chefes_desligados", de_ch, em_ch)
	quit(0)
