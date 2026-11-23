extends SceneTree
## Vitrine do corpo em peças (Corpo, doc §143): o robô do jogo vestido com cada conjunto, de frente e de costas,
## e o rabo dos conjuntos que têm, parado (balançando) e esticado (correndo e voando). Junta tudo numa folha.
## godot --path . -s tools/vitrine_corpo.gd [-- --so=gato,urso] [-- --rabos]

const PASTA := "res://tools/capturas/corpo/"
const LADO := 420
var cam: Camera3D
var palco: Node3D
var rotulo: Label


## Uma armadura de mentira, só com o que o rabo lê.
class Falsa:
	var velocity := Vector3.ZERO
	var estado := Armadura.Estado.CHAO
	var em_pane := false
	var no_assento := false
	var voa := false

	func em_voo() -> bool:
		return voa


func _initialize() -> void:
	root.size = Vector2i(LADO, LADO)
	DisplayServer.window_set_size(Vector2i(LADO, LADO))
	var amb := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.42, 0.44)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.85)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	amb.environment = e
	root.add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38, 150, 0)
	sol.light_energy = 0.8
	sol.shadow_enabled = true
	root.add_child(sol)
	var sol2 := DirectionalLight3D.new()
	sol2.rotation_degrees = Vector3(-25, -40, 0)
	sol2.light_energy = 0.25
	root.add_child(sol2)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	chao.mesh = pm
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.33, 0.39, 0.4)
	mc.roughness = 1.0
	chao.material_override = mc
	root.add_child(chao)
	cam = Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.make_current()
	palco = Node3D.new()
	root.add_child(palco)
	var camada := CanvasLayer.new()
	root.add_child(camada)
	rotulo = Label.new()
	rotulo.position = Vector2(12, 8)
	rotulo.add_theme_font_size_override("font_size", 64)
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	rotulo.add_theme_constant_override("outline_size", 6)
	camada.add_child(rotulo)
	_rodar()


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _foto() -> Image:
	await _quadros(4)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _olhar(h: float, giro: float, alto := 0.25, dist := 3.6, alvo_y := 0.5) -> void:
	var alvo := Vector3(0, h * alvo_y, 0)
	cam.global_position = alvo + Vector3(sin(giro), alto, cos(giro)).normalized() * h * dist
	cam.look_at(alvo)


func _robo(chave: String) -> ArmaduraVisual:
	for f in palco.get_children():
		f.free()
	for parte: String in Corpo.PARTES:
		Corpo.vestido[parte] = chave
	var v := ArmaduraVisual.new()
	palco.add_child(v)
	v.mat_chama.albedo_color.a = 0.0
	for c in v.chamas + v.chamas_pequenas:
		c.visible = false
	return v


## O rabo sozinho, como o jogo faria por `segundos` com a armadura de mentira.
func _rabo(v: ArmaduraVisual, a: Falsa, segundos: float) -> void:
	var dt := 1.0 / 60.0
	for i in int(segundos / dt):
		v._animar_rabo(dt, a)


func _folha(fotos: Array, cols: int, nome: String) -> void:
	var lin := (fotos.size() + cols - 1) / cols
	var folha := Image.create(cols * LADO, lin * LADO, false, Image.FORMAT_RGBA8)
	folha.fill(Color(0.09, 0.1, 0.11))
	for k in fotos.size():
		var im := fotos[k] as Image
		if im == null:
			continue
		im.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(im, Rect2i(0, 0, LADO, LADO), Vector2i((k % cols) * LADO, (k / cols) * LADO))
	folha.save_jpg(PASTA + nome, 0.88)
	print("folha ", nome, " ", folha.get_size())


func _rodar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	await _quadros(3)
	Armadura.porte = 0.48
	ArmaduraVisual.toon = true
	var h := ArmaduraVisual.ALTURA_ALVO * Armadura.porte
	var pedidos: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--so="):
			pedidos = Array(arg.substr(5).split(","))
	if pedidos.is_empty():
		pedidos = [""]
		for c: Array in Corpo.CONJUNTOS:
			pedidos.append(c[0])
	if "--rabos" in OS.get_cmdline_user_args():
		var fotos := []
		for chave: String in Corpo.COM_RABO:
			var v := _robo(chave)
			var a := Falsa.new()
			print(chave, ": rabo com ", v._rabo.size(), " gomos")
			rotulo.text = "%s parado" % Corpo.nome(chave)
			_olhar(h, PI * 0.5, 0.05, 1.7, 0.36)
			fotos.append(await _foto())
			_rabo(v, a, 0.65)
			rotulo.text = "%s balançando" % Corpo.nome(chave)
			_olhar(h, 0.25, 1.2, 2.6, 0.38)
			fotos.append(await _foto())
			a.velocity = Vector3(0, 0, -6)
			_rabo(v, a, 1.5)
			rotulo.text = "%s correndo (só o rabo)" % Corpo.nome(chave)
			_olhar(h, PI * 0.5, 0.05, 1.7, 0.36)
			fotos.append(await _foto())
			a.voa = true
			a.estado = Armadura.Estado.VOO
			a.velocity = Vector3(0, -4, -10)
			_rabo(v, a, 1.5)
			rotulo.text = "%s voando para baixo" % Corpo.nome(chave)
			fotos.append(await _foto())
		_folha(fotos, 4, "rabos_jogo.jpg")
		quit()
		return
	var fotos := []
	for chave: String in pedidos:
		var v := _robo(chave)
		var escondidas := 0
		for parte: String in Corpo.PARTES:
			for n: MeshInstance3D in v._de_fabrica.get(parte, []):
				if not n.visible:
					escondidas += 1
		print("%s: %d peças novas, %d de fábrica escondidas, rabo %d" % [Corpo.nome(chave), v._enxertos.size(), escondidas, v._rabo.size()])
		rotulo.text = Corpo.nome(chave)
		_olhar(h, PI - 0.5, 0.22, 2.9, 0.54)
		fotos.append(await _foto())
		rotulo.text = Corpo.nome(chave) + " (costas)"
		_olhar(h, 0.5, 0.22, 2.9, 0.54)
		fotos.append(await _foto())
	_folha(fotos, 6, "conjuntos_jogo.jpg")
	quit()
