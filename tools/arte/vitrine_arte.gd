extends SceneTree
## A vitrine da caixa de arte: põe os .glb feitos com tools/arte/blender_arte.py num chão de capim, na luz do vale
## (o ambiente do Main._ambiente_vale e o CicloDia com a hora parada), ao lado do nosso robô de 1,2 m, e tira uma
## folha de fotos em algumas horas do dia.
##
##   godot --path . -s tools/arte/vitrine_arte.gd -- a.glb [b.glb ...] [--nome folha] [--horas 12,18.6,23]
##       [--pasta tools/capturas/arte]
##
## Precisa de janela (com --headless não sai imagem). Sai <pasta>/<nome>_vitrine.png (padrão: caixa_vitrine.png).
## Os materiais: um .glb com textura (o caminho de artista) entra com o shader vale_base e a textura dele; sem
## textura, cada material vira o do jogo com o mesmo nome (Clareira.material), como o Main._pintar faz no vale.
## Nome que o jogo não conhece vira "rocha", e a vitrine avisa no terminal.
## As fotos: a câmera fica sempre do lado do sol (ou da lua) e a peça gira para mostrar cada face; uma foto é contra
## o sol, com a frente na sombra. As de perto são só da primeira peça, com as outras escondidas.
## O chão é só o shader do capim (sem as touceiras do jogo). De frente = o lado +Z do Godot (o -Y do Blender).

const ALTURA_ROBO := 1.2
const VAO := 0.6  # entre as peças da fila
const TELA := Vector2i(1280, 800)
const PAINEL := Vector2i(800, 500)
const MARGEM := 16

var cam: Camera3D
var pivo: Node3D  # a fila gira em volta do que está na foto
var pecas: Array[Node3D] = []
var ciclo: CicloDia
var clareira: Clareira
var rotulo: Label
var pasta := "res://tools/capturas/arte"
var nome := "caixa"
var horas: Array[float] = [12.0, 18.6, 23.0]
var arquivos: Array[String] = []
var avisados := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a := args[i]
		if a == "--nome" and i + 1 < args.size():
			nome = args[i + 1]
			i += 1
		elif a == "--pasta" and i + 1 < args.size():
			pasta = _res(args[i + 1])
			i += 1
		elif a == "--horas" and i + 1 < args.size():
			horas.clear()
			for h in args[i + 1].split(",", false):
				horas.append(float(h))
			i += 1
		elif a.ends_with(".glb") or a.ends_with(".gltf"):
			arquivos.append(_res(a))
		i += 1
	if arquivos.is_empty():
		printerr("vitrine_arte: passe ao menos um .glb depois de --")
		quit(1)
		return
	root.size = TELA
	DisplayServer.window_set_size(TELA)
	_ambiente()
	_rodar()


## Caminho relativo à pasta do jogo vira res://.
func _res(c: String) -> String:
	if c.begins_with("res://") or c.begins_with("/"):
		return c
	return "res://" + c


## O mesmo ambiente do vale (Main._ambiente_vale), com o CicloDia dando a cor de cada hora.
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
	sol.directional_shadow_max_distance = 40.0
	sol.directional_shadow_blend_splits = true
	root.add_child(sol)
	root.msaa_3d = Viewport.MSAA_4X
	root.use_debanding = true
	ciclo = CicloDia.new()
	ciclo.env = env
	ciclo.ceu = ceu
	ciclo.sol = sol
	ciclo.parado = true
	ciclo.hora = horas[0]
	root.add_child(ciclo)
	# os materiais do jogo pelo nome (a textura de ruído que a Clareira faz no gerar)
	clareira = Clareira.new()
	clareira._tex = NoiseTexture2D.new()
	clareira._tex.width = 512
	clareira._tex.height = 512
	clareira._tex.seamless = true
	clareira._tex.noise = clareira._ruido(77, 1.0 / 40.0, 4)
	clareira._materiais()
	_chao()
	cam = Camera3D.new()
	cam.fov = 35.0
	cam.far = 2000.0
	root.add_child(cam)
	cam.make_current()
	var camada := CanvasLayer.new()
	root.add_child(camada)
	rotulo = Label.new()
	rotulo.position = Vector2(18, 12)
	rotulo.add_theme_font_size_override("font_size", 30)
	rotulo.add_theme_color_override("font_color", Color(1, 1, 1))
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	rotulo.add_theme_constant_override("outline_size", 8)
	camada.add_child(rotulo)


## Um chão de 80 m com o shader do capim do vale (as cores de vértice pretas são capim puro).
func _chao() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	var lado := 80.0
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
		printerr("vitrine_arte: não abriu ", caminho, " (erro ", err, ")")
		return null
	var cena := doc.generate_scene(estado) as Node3D
	_pintar(cena)
	return cena


## Com textura: vale_base com a textura do modelo. Sem: o material do jogo com o mesmo nome.
func _pintar(no: Node) -> void:
	if no is MeshInstance3D:
		var mi := no as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nm := m.resource_name if m else ""
			if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture:
				var sm := ShaderMaterial.new()
				sm.shader = load("res://scripts/shaders/vale_base.gdshader")
				sm.set_shader_parameter("tex", (m as BaseMaterial3D).albedo_texture)
				sm.set_shader_parameter("ruido", clareira._tex)
				mi.set_surface_override_material(s, sm)
			else:
				if not clareira._mats.has(nm) and not avisados.has(nm):
					avisados[nm] = true
					print("vitrine_arte: o jogo não tem o material \"%s\"; vai como rocha" % nm)
				mi.set_surface_override_material(s, clareira.material(nm))
	for f in no.get_children():
		_pintar(f)


## O nosso robô, virado para onde as peças olham (+Z), no tamanho do jogo.
func _robo(onde: Vector3) -> void:
	Armadura.porte = 0.48  # como no vale
	var r := ArmaduraVisual.new()
	pivo.add_child(r)
	r.preparar()
	r.scale = Vector3.ONE * ALTURA_ROBO / maxf(0.01, BaseVale._caixa(r.modelo).size.y)
	r.set_meta("base", onde)
	r.position = onde
	r.yaw_forcado = PI
	var pose := PoseInimigo.new()
	pose.altura = BaseVale._caixa(r.modelo).size.y
	r.set_meta("pose", pose)
	for i in 30:
		r.atualizar(0.2, pose)


func _esp(n: int) -> void:
	for i in n:
		await process_frame


## Tudo passa a girar em volta de `c` (sem giro, cada coisa fica onde a fila a pôs).
func _centrar(c: Vector3) -> void:
	pivo.rotation = Vector3.ZERO
	pivo.position = c
	for f in pivo.get_children():
		(f as Node3D).position = (f.get_meta("base") as Vector3) - c


## A direção, no chão, de onde vem a luz (o sol de dia, a lua de noite).
func _de_onde_vem_a_luz() -> Vector3:
	var z := ciclo.sol.global_transform.basis.z  # a luz anda para o -Z dela
	var s := Vector3(z.x, 0.0, z.z)
	return s.normalized() if s.length() > 0.01 else Vector3.BACK


## Só estas peças aparecem (o robô sempre).
func _so(lista: Array[Node3D]) -> void:
	for p in pecas:
		p.visible = p in lista


## Uma foto. A câmera fica do lado da luz, 30° para o lado (para a forma ter sombra), ou do lado oposto
## (`contra`), e as peças giram para mostrar a face pedida: giro 0 é de frente, -35 em 3/4, -90 de lado (a
## esquerda da peça) e 180 de costas. `elevacao` em graus; `caixa` é o que precisa caber.
func _tomada(texto: String, caixa: AABB, giro: float, elevacao: float, contra := false) -> Image:
	var dir := _de_onde_vem_a_luz().rotated(Vector3.UP, deg_to_rad(30.0))
	if contra:
		dir = -dir
	var c := caixa.get_center()
	_centrar(c)
	var g := deg_to_rad(giro)
	pivo.rotation.y = atan2(dir.x, dir.z) + g
	var s := caixa.size
	var largura := absf(s.x * cos(g)) + absf(s.z * sin(g))
	var fundo := absf(s.x * sin(g)) + absf(s.z * cos(g))
	var tg := tan(deg_to_rad(cam.fov * 0.5))
	var dist := maxf(s.y * 0.5 / tg, largura * 0.5 / (tg * float(TELA.x) / TELA.y)) * 1.15 + fundo * 0.5
	var e := deg_to_rad(elevacao)
	rotulo.text = texto
	cam.position = c + (dir * cos(e) + Vector3.UP * sin(e)) * dist
	cam.look_at(c)
	await _esp(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.resize(PAINEL.x, PAINEL.y, Image.INTERPOLATE_LANCZOS)
	return img


func _rodar() -> void:
	await process_frame
	pivo = Node3D.new()
	root.add_child(pivo)
	# as peças numa fila em X, cada uma com o pé no chão (a origem do Blender é o pé), e o robô à esquerda
	var x := 0.0
	var caixas: Array[AABB] = []
	for c in arquivos:
		var p := _carregar(c)
		if p == null:
			continue
		pivo.add_child(p)
		var cx := BaseVale._caixa(p)
		var onde := Vector3(x - cx.position.x, 0.0, 0.0)
		p.set_meta("base", onde)
		p.position = onde
		pecas.append(p)
		caixas.append(AABB(cx.position + onde, cx.size))
		x += cx.size.x + VAO
		print("vitrine_arte: ", c.get_file(), " mede %.2f × %.2f × %.2f m (largura, altura, fundo)" % [cx.size.x, cx.size.y, cx.size.z])
	if pecas.is_empty():
		quit(1)
		return
	var xr := caixas[0].position.x - 0.5 - 0.35
	_robo(Vector3(xr, 0, caixas[0].get_center().z))
	var caixa_robo := AABB(Vector3(xr - 0.35, 0, caixas[0].get_center().z - 0.3), Vector3(0.7, ALTURA_ROBO, 0.6))
	var fila := caixa_robo
	for b in caixas:
		fila = fila.merge(b)
	var perto := caixas[0].merge(caixa_robo)
	var so_a_primeira: Array[Node3D] = [pecas[0]]
	var paineis: Array[Image] = []
	for k in horas.size():
		var h := horas[k]
		ciclo.hora = h
		ciclo._aplicar()
		await _esp(20)
		var hh := "%dh%02d" % [int(h), int(round(fmod(h, 1.0) * 60.0))]
		if k == 0:
			_so(pecas)
			paineis.append(await _tomada(hh + " · a fila, de frente", fila, 0.0, 4.0))
			_so(so_a_primeira)
			paineis.append(await _tomada(hh + " · de frente", perto, 0.0, 4.0))
			paineis.append(await _tomada(hh + " · em 3/4", perto, -35.0, 20.0))
			paineis.append(await _tomada(hh + " · de lado (a esquerda dela)", perto, -90.0, 4.0))
			paineis.append(await _tomada(hh + " · de costas", perto, 180.0, 4.0))
			paineis.append(await _tomada(hh + " · contra o sol (a frente na sombra)", perto, 0.0, 4.0, true))
		else:
			_so(pecas)
			paineis.append(await _tomada(hh + " · a fila, em 3/4", fila, -35.0, 20.0))
			_so(so_a_primeira)
			paineis.append(await _tomada(hh + " · em 3/4", perto, -35.0, 20.0))
	_folha(paineis)
	clareira.free()
	quit(0)


## Os painéis em duas colunas numa imagem só.
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
	DirAccess.make_dir_recursive_absolute(pasta)
	var saida := pasta.path_join(nome + "_vitrine.png")
	folha.save_png(saida)
	print("vitrine_arte: folha ", ProjectSettings.globalize_path(saida), " ", folha.get_width(), "×", folha.get_height())
