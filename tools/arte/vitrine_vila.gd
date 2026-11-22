extends SceneTree
## A vitrine da vila: põe os .glb pintados de uma vila (tools/arte/vilarejo_vila1.py --pintar) cada um no seu
## lugar, num chão de capim, na luz do vale (o ambiente do Main._ambiente_vale e o CicloDia com a hora parada), e
## repete as tomadas que o Blender gravou em tomadas.json, com o nosso robô de 1,2 m onde ele estava lá.
##
##   godot --path . -s tools/arte/vitrine_vila.gd -- [--pasta tools/capturas/vilarejo/vila1_glb] [--nome vila1]
##       [--tomadas v_cima@12,v_voo@12,v_voo@18.6,...]
##
## Precisa de janela (com --headless não sai imagem). Sai <pasta>/../<nome>_vitrine.png. Sem --tomadas, todas
## ao meio-dia e mais o voo e a rua no fim da tarde e o voo à noite.
## Os materiais: com textura, o shader vale_base com a textura; sem textura (o mato provisório), o vale_base com a
## cor do material como tinta. As coordenadas do Blender (x, y, z) viram (x, z, -y) no Godot.

const ALTURA_ROBO := 1.2
const TELA := Vector2i(1120, 700)  # o mesmo formato das fotos do Blender
const PAINEL := Vector2i(800, 500)
const MARGEM := 16
const SENSOR_MM := 36.0  # a lente do Blender vale na largura

var cam: Camera3D
var ciclo: CicloDia
var clareira: Clareira
var rotulo: Label
var robo: ArmaduraVisual
var pose: PoseInimigo
var pasta := "res://tools/capturas/vilarejo/vila1_glb"
var nome := "vila1"
var pedidas: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a := args[i]
		if a == "--pasta" and i + 1 < args.size():
			pasta = _res(args[i + 1])
			i += 1
		elif a == "--nome" and i + 1 < args.size():
			nome = args[i + 1]
			i += 1
		elif a == "--tomadas" and i + 1 < args.size():
			for t in args[i + 1].split(",", false):
				pedidas.append(t)
			i += 1
		i += 1
	root.size = TELA
	DisplayServer.window_set_size(TELA)
	_ambiente()
	_rodar()


func _res(c: String) -> String:
	if c.begins_with("res://") or c.begins_with("/"):
		return c
	return "res://" + c


## Do Blender (Z para cima) para o Godot (Y para cima).
func _g(p: Array) -> Vector3:
	return Vector3(p[0], p[2], -p[1])


## O mesmo ambiente do vale (Main._ambiente_vale), como na vitrine_arte.
func _ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ceu := ShaderMaterial.new()
	ceu.shader = load("res://scripts/shaders/vale_ceu.gdshader")
	var nuvens := NoiseTexture2D.new()
	nuvens.width = 512
	nuvens.height = 512
	nuvens.seamless = true
	var rn := FastNoiseLite.new()
	rn.frequency = 0.008
	rn.fractal_octaves = 4
	nuvens.noise = rn
	ceu.set_shader_parameter("nuvens", nuvens)
	var sky := Sky.new()
	sky.sky_material = ceu
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.52, 0.66)
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.80, 0.92)
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.98
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.light_color = Color(1.0, 0.94, 0.82)
	sol.light_energy = 1.05
	sol.shadow_enabled = true
	sol.shadow_opacity = 1.0
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sol.directional_shadow_max_distance = 60.0
	sol.directional_shadow_blend_splits = true
	root.add_child(sol)
	root.msaa_3d = Viewport.MSAA_4X
	root.use_debanding = true
	ciclo = CicloDia.new()
	ciclo.env = env
	ciclo.ceu = ceu
	ciclo.sol = sol
	ciclo.parado = true
	ciclo.hora = 12.0
	root.add_child(ciclo)
	clareira = Clareira.new()
	clareira._tex = NoiseTexture2D.new()
	clareira._tex.width = 512
	clareira._tex.height = 512
	clareira._tex.seamless = true
	clareira._tex.noise = clareira._ruido(77, 1.0 / 40.0, 4)
	clareira._materiais()
	_chao()
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.far = 3000.0
	root.add_child(cam)
	cam.make_current()
	var camada := CanvasLayer.new()
	root.add_child(camada)
	rotulo = Label.new()
	rotulo.position = Vector2(16, 10)
	rotulo.add_theme_font_size_override("font_size", 24)
	rotulo.add_theme_color_override("font_color", Color(1, 1, 1))
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	rotulo.add_theme_constant_override("outline_size", 7)
	camada.add_child(rotulo)


## Um chão de 400 m com o shader do capim do vale.
func _chao() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	var lado := 400.0
	for j in n:
		for k in n:
			var x0 := -lado * 0.5 + lado * k / n
			var z0 := -lado * 0.5 + lado * j / n
			var x1 := x0 + lado / n
			var z1 := z0 + lado / n
			for p: Vector3 in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1),
					Vector3(x0, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]:
				st.set_color(Color(0, 0, 0, 1))
				st.set_normal(Vector3.UP)
				st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_chao.gdshader")
	m.set_shader_parameter("ruido", clareira._tex)
	mi.material_override = m
	root.add_child(mi)


func _carregar(caminho: String) -> Node3D:
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(caminho), estado)
	if err != OK:
		printerr("vitrine_vila: não abriu ", caminho, " (erro ", err, ")")
		return null
	var cena := doc.generate_scene(estado) as Node3D
	_pintar(cena)
	return cena


## Tudo com o vale_base: a textura do modelo, ou a cor do material como tinta.
func _pintar(no: Node) -> void:
	if no is MeshInstance3D:
		var mi := no as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var sm := ShaderMaterial.new()
			sm.shader = load("res://scripts/shaders/vale_base.gdshader")
			sm.set_shader_parameter("ruido", clareira._tex)
			if m and m.albedo_texture:
				sm.set_shader_parameter("tex", m.albedo_texture)
			elif m:
				var c := m.albedo_color
				sm.set_shader_parameter("tinta", Vector3(c.r, c.g, c.b))
			mi.set_surface_override_material(s, sm)
	for f in no.get_children():
		_pintar(f)


func _esp(n: int) -> void:
	for i in n:
		await process_frame


func _por_robo() -> void:
	Armadura.porte = 0.48  # como no vale
	robo = ArmaduraVisual.new()
	root.add_child(robo)
	robo.preparar()
	robo.scale = Vector3.ONE * ALTURA_ROBO / maxf(0.01, BaseVale._caixa(robo.modelo).size.y)
	pose = PoseInimigo.new()
	pose.altura = BaseVale._caixa(robo.modelo).size.y


## O robô no lugar da tomada, virado para a câmera (um pouco de lado, para ler a forma).
func _robo_em(onde: Vector3, olha: Vector3) -> void:
	robo.position = Vector3(onde.x, 0.0, onde.z)
	var d := (olha - robo.position)
	d.y = 0.0
	d = d.normalized().rotated(Vector3.UP, deg_to_rad(25.0))
	robo.yaw_forcado = atan2(-d.x, -d.z)
	for i in 30:
		robo.atualizar(0.2, pose)


func _tomada(t: Dictionary, hora: float) -> Image:
	var pos := _g(t["cam"])
	var alvo := _g(t["alvo"])
	_robo_em(_g(t["robo"]), pos)
	if t.get("orto") != null:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(t["orto"])
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = rad_to_deg(2.0 * atan(SENSOR_MM * 0.5 / float(t["lente"])))
	cam.position = pos
	var dir := (alvo - pos).normalized()
	cam.look_at(alvo, Vector3.BACK if absf(dir.dot(Vector3.UP)) > 0.99 else Vector3.UP)
	# a sombra: longe na vista de cima e do voo, perto (mais nítida) no chão
	ciclo.sol.directional_shadow_max_distance = 220.0 if pos.distance_to(alvo) > 60.0 else 60.0
	var hh := "%dh%02d" % [int(hora), int(round(fmod(hora, 1.0) * 60.0))]
	rotulo.text = hh + " · " + String(t["legenda"])
	await _esp(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.resize(PAINEL.x, PAINEL.y, Image.INTERPOLATE_LANCZOS)
	return img


func _rodar() -> void:
	await process_frame
	var tomadas := {}
	var ordem: Array[String] = []
	var f := FileAccess.open(pasta.path_join("tomadas.json"), FileAccess.READ)
	if f == null:
		printerr("vitrine_vila: falta ", pasta.path_join("tomadas.json"), " (rode o vilarejo com --pintar)")
		quit(1)
		return
	for t in JSON.parse_string(f.get_as_text()):
		tomadas[t["nome"]] = t
		ordem.append(t["nome"])
	var n := 0
	for arq in DirAccess.get_files_at(pasta):
		if arq.ends_with(".glb"):
			var p := _carregar(pasta.path_join(arq))
			if p:
				root.add_child(p)
				n += 1
	print("vitrine_vila: %d peças" % n)
	_por_robo()
	if pedidas.is_empty():
		for k in ordem:
			pedidas.append(k + "@12")
		pedidas.append_array(["v_voo@18.6", "v_rua@18.6", "v_voo@23"])
	var paineis: Array[Image] = []
	var hora_atual := -1.0
	for pedido in pedidas:
		var partes := pedido.split("@")
		var hora := float(partes[1]) if partes.size() > 1 else 12.0
		if not tomadas.has(partes[0]):
			printerr("vitrine_vila: não há a tomada ", partes[0])
			continue
		if hora != hora_atual:
			ciclo.hora = hora
			ciclo._aplicar()
			await _esp(20)
			hora_atual = hora
		paineis.append(await _tomada(tomadas[partes[0]], hora))
	_folha(paineis)
	clareira.free()
	quit(0)


func _folha(paineis: Array[Image]) -> void:
	var colunas := 2
	var linhas := ceili(paineis.size() / float(colunas))
	var folha := Image.create(colunas * PAINEL.x + (colunas + 1) * MARGEM, linhas * PAINEL.y + (linhas + 1) * MARGEM,
			false, Image.FORMAT_RGB8)
	folha.fill(Color(0.08, 0.09, 0.1))
	for i in paineis.size():
		var p := paineis[i]
		p.convert(Image.FORMAT_RGB8)
		var px := MARGEM + (i % colunas) * (PAINEL.x + MARGEM)
		var py := MARGEM + (i / colunas) * (PAINEL.y + MARGEM)
		folha.blit_rect(p, Rect2i(Vector2i.ZERO, PAINEL), Vector2i(px, py))
	var saida := pasta.get_base_dir().path_join(nome + "_vitrine.png")
	folha.save_png(saida)
	print("vitrine_vila: folha ", ProjectSettings.globalize_path(saida), " ", folha.get_width(), "×", folha.get_height())
