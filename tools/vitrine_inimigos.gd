extends SceneTree
## Fotos dos robôs inimigos (InimigoVisual) num estúdio liso, em cada pose: os cinco comuns numa fila e os três
## chefes noutra, com o nosso robô ao lado para comparar o tamanho.
## godot --path . -s tools/vitrine_inimigos.gd      (as fotos vão para tools/capturas/inimigos/)

var cam: Camera3D
var comuns: Array[InimigoVisual] = []
var chefes: Array[InimigoVisual] = []
const DE_C := Vector3(-0.9, 1.35, -10.0)
const EM_C := Vector3(-0.9, 0.8, 0.0)
const DE_CH := Vector3(11.9, 2.4, -14.0)
const EM_CH := Vector3(11.9, 1.45, 0.0)


func _initialize() -> void:
	root.size = Vector2i(1600, 720)
	DisplayServer.window_set_size(Vector2i(1600, 720))
	var amb := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.42, 0.44)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.84, 0.88)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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


func _por(tipo: String, onde: Vector3, chefe: bool) -> InimigoVisual:
	InimigoVisual.forcar_modelo = tipo
	var v := InimigoVisual.montar(comuns.size() * 5 + chefes.size() * 3 + 2, 1.6, null, chefe)
	InimigoVisual.forcar_modelo = ""
	root.add_child(v)
	v.position = onde
	v.alvo_mira = onde + Vector3(0, 0.75, -2.6)
	return v


## O nosso robô, de frente para a câmera, para comparar o tamanho.
func _jogador(onde: Vector3) -> void:
	var r := ArmaduraVisual.new()
	root.add_child(r)
	r.preparar()
	r.scale = Vector3.ONE * 1.25 / maxf(0.01, BaseVale._caixa(r.modelo).size.y)
	r.position = onde
	r.yaw_forcado = 0.0
	var pose := PoseInimigo.new()
	pose.altura = BaseVale._caixa(r.modelo).size.y
	r.set_meta("pose", pose)
	for i in 30:
		r.atualizar(0.2, pose)


func _esp(n: int) -> void:
	for i in n:
		await process_frame


func _foto(nome: String, de: Vector3, alvo: Vector3) -> void:
	cam.position = de
	cam.look_at(alvo)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/capturas/inimigos/v2_%s.png" % nome)


## As duas filas, com o tempo parado (o meio de uma animação).
func _fotos(nome: String) -> void:
	Engine.time_scale = 0.0
	await _foto(nome + "_comuns", DE_C, EM_C)
	await _foto(nome + "_chefes", DE_CH, EM_CH)
	Engine.time_scale = 1.0


## Cada robô de perto, de três quartos pelo lado do braço da arma (o direito), com o tempo parado.
func _de_perto(nome: String, de_lado := false) -> void:
	Engine.time_scale = 0.0
	for v in _todos():
		var h := v.altura
		var de := v.position + (Vector3(h * 0.7, h * 0.95, -h * 1.5) if de_lado else Vector3(h * 1.1, h * 0.7, -h * 1.9))
		await _foto("%s_%s" % [nome, v.tipo], de, v.position + Vector3(0, h * (0.2 if de_lado else 0.5), -h * 0.25))
	Engine.time_scale = 1.0


func _todos() -> Array[InimigoVisual]:
	return comuns + chefes


func _vel(v: Vector3) -> void:
	for i in _todos():
		i.vel_vitrine = v * (1.6 if i in chefes else 1.0)


func _rodar() -> void:
	await process_frame
	Armadura.porte = 0.48  # como no vale
	DirAccess.make_dir_recursive_absolute("res://tools/capturas/inimigos")
	var k := 0
	for tipo: String in InimigoVisual.COMUNS:
		comuns.append(_por(tipo, Vector3(k * 1.9 - 3.8, 0, 0), false))
		k += 1
	k = 0
	for tipo: String in InimigoVisual.CHEFES:
		chefes.append(_por(tipo, Vector3(k * 4.2 + 9.0, 0, 0), true))
		k += 1
	_jogador(Vector3(-5.9, 0, 0))
	_jogador(Vector3(6.4, 0, 0))
	_vel(Vector3.ZERO)
	await _esp(40)
	await _fotos("1_parados")
	_vel(Vector3(0, 0, -1.6))
	await _esp(45)
	await _fotos("2_andando")
	_vel(Vector3(0, 0, -5.5))
	await _esp(45)
	await _fotos("3_correndo")
	_vel(Vector3.ZERO)
	await _esp(40)
	# o ataque em três tempos: armando, o meio (o tiro sai, a lâmina passa na frente) e o fim
	for v in _todos():
		v.olho(1.0)
		v.tocar("Shoot")
	for passo: Array in [[0.3, "a"], [0.42, "b"], [0.56, "c"]]:
		while comuns[0].tempo_ataque < float(passo[0]):
			await process_frame
		await _fotos("4_ataque_" + String(passo[1]))
		if passo[1] == "b":
			await _de_perto("12_ataque")
	Engine.time_scale = 0.0
	await _foto("5_ataque_lado_comuns", Vector3(-10.5, 1.4, -1.6), Vector3(-0.5, 0.85, -0.8))
	await _foto("5_ataque_lado_chefes", Vector3(2.0, 2.4, -2.4), Vector3(13.0, 1.6, -0.6))
	Engine.time_scale = 1.0
	# o Guardião de longe atira com o braço da lâmina
	var g := chefes[2]
	g.ataque = "tiro"
	g.tocar("Idle")
	await _esp(4)
	g.tocar("Shoot")
	await _esp(40)
	Engine.time_scale = 0.0
	await _foto("6_guardiao_atirando", g.position + Vector3(-4.6, 2.2, -5.4), g.position + Vector3(0, 1.5, -0.5))
	Engine.time_scale = 1.0
	g.ataque = "corpo"
	for v in _todos():
		v.olho(0.0)
		v.tocar("Idle")
	await _esp(30)
	# pulo e esquiva
	for v in _todos():
		v.no_ar = true
	await _esp(30)
	await _fotos("7_pulo")
	for v in _todos():
		v.no_ar = false
		v.pousando = 0.25
	await _esp(4)
	await _fotos("8_pouso")
	_vel(Vector3(7.0, 0, 0))
	for v in _todos():
		v.esquivando = 0.32
	await _esp(12)
	await _fotos("9_esquiva")
	_vel(Vector3.ZERO)
	for v in _todos():
		v.esquivando = 0.0
	await _esp(30)
	for v in _todos():
		v.tocar("Death")
		v.apagar(1.0)
		v.olho(0.0)
	await _esp(120)
	await _fotos("10_desligados")
	await _de_perto("13_desligado", true)
	for v in _todos():
		v.desbotar(1.0)
	await _esp(4)
	await _fotos("11_velhos")
	quit(0)
