extends SceneTree
## Vitrine das melhorias do robô: fotos do robô com cada peça, em fundo liso.
## godot --path . -s tools/vitrine_melhorias.gd [-- --ossos]

const PASTA := "res://tools/capturas/melhorias/"
var cam: Camera3D
var palco: Node3D
var _h := 1.0


func _initialize() -> void:
	root.size = Vector2i(900, 900)
	DisplayServer.window_set_size(Vector2i(900, 900))
	var amb := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.42, 0.44)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.85)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.25
	amb.environment = e
	root.add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38, 150, 0)
	sol.light_energy = 0.8
	sol.shadow_enabled = true
	root.add_child(sol)
	var sol2 := DirectionalLight3D.new()
	sol2.rotation_degrees = Vector3(-25, -40, 0)
	sol2.light_energy = 0.2
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
	_rodar()


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _foto(nome: String) -> void:
	await _quadros(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA + nome + ".png")
	print("foto ", nome)


## Câmera olhando o robô: `giro` 0 é de frente, PI de costas; `alvo_y` e `dist` em alturas do robô.
func _olhar(h: float, giro: float, alto := 0.25, dist := 3.6, alvo_y := 0.5, lado := 0.0) -> void:
	var alvo := Vector3(lado * h, h * alvo_y, 0)
	var d := Vector3(sin(giro), alto, cos(giro)).normalized() * h * dist
	cam.global_position = alvo + d
	cam.look_at(alvo)


func _robo(pecas: Array, pose := "") -> ArmaduraVisual:
	for f in palco.get_children():
		f.free()
	var v := ArmaduraVisual.new()
	palco.add_child(v)
	if v.esqueleto != null:
		v._alvos = {}
		v._aplicar_ossos(0.0, 1.0)
	v.mat_chama.albedo_color.a = 0.0
	for c in v.chamas + v.chamas_pequenas:
		c.visible = false
	MelhoriasVisual.limpar(v)
	if not pecas.is_empty():
		MelhoriasVisual.vestir(v, pecas)
	return v


func _rodar() -> void:
	await _quadros(3)
	# o robô do jogo: o do vale, com o porte e o estilo pintado de lá
	Armadura.porte = 0.48
	ArmaduraVisual.MODELO = "res://assets/vale/robo_v1.glb"
	ArmaduraVisual.toon = true
	var v := _robo([])
	var h := ArmaduraVisual.ALTURA_ALVO * Armadura.porte
	if "--nos" in OS.get_cmdline_user_args():
		var inv := v.global_transform.affine_inverse()
		for n in v.modelo.find_children("*", "Node3D", true, false):
			var n3 := n as Node3D
			var p := inv * n3.global_position / h
			var linha := "%s <%s>  %.3f %.3f %.3f" % [n3.name, n3.get_parent().name, p.x, p.y, p.z]
			if n3 is MeshInstance3D and (n3 as MeshInstance3D).mesh != null:
				var bb := (inv * n3.global_transform) * (n3 as MeshInstance3D).mesh.get_aabb()
				linha += "  caixa x %.3f..%.3f y %.3f..%.3f z %.3f..%.3f" % [bb.position.x / h, bb.end.x / h, bb.position.y / h, bb.end.y / h, bb.position.z / h, bb.end.z / h]
			print(linha)
		_olhar(h, PI - 0.5, 0.22, 2.9, 0.54)
		await _foto("base_frente")
		_olhar(h, 0.5, 0.22, 2.9, 0.54)
		await _foto("base_costas")
		quit()
		return
	if "--ossos" in OS.get_cmdline_user_args():
		var sk := v.esqueleto
		print("altura ", h, " escala ", v.modelo.scale.x)
		for b in sk.get_bone_count():
			var p := v.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_rest(b).origin
			if not ("Hand" in sk.get_bone_name(b) and sk.get_bone_name(b).length() > 22):
				print("%s  %.3f %.3f %.3f" % [sk.get_bone_name(b), p.x / h, p.y / h, p.z / h])
		_olhar(h, 0.5)
		await _foto("base_frente")
		_olhar(h, PI - 0.5)
		await _foto("base_costas")
		_olhar(h, PI * 0.5, 0.1)
		await _foto("base_lado")
		quit()
		return
	await _todas(h)
	quit()


const VISTAS := [
	["radiador", "Radiador de aletas", 0.6, 0.3, 1.2, 0.58],
	["bocais", "Bocais largos (no ar)", 0.7, -0.22, 1.5, 0.22],
	["barbatanas", "Barbatanas", PI - 0.9, 0.2, 2.0, 0.3],
	["amortecedores", "Molas (amortecedores)", 0.6, 0.2, 1.1, 0.28],
	["antena", "Antena de busca", PI - 0.7, 0.2, 1.3, 0.88],
	["celulas", "Células de reserva", 0.45, 0.2, 1.1, 0.47],
	["scanner", "Scanner", PI - 0.8, 0.15, 1.0, 0.8],
]


func _todas(h: float) -> void:
	_h = h
	MelhoriasVisual.minimo = not ("--cheio" in OS.get_cmdline_user_args())
	if "--armas" in OS.get_cmdline_user_args():
		var camada_a := CanvasLayer.new()
		root.add_child(camada_a)
		var rot_a := Label.new()
		rot_a.position = Vector2(28, 20)
		rot_a.add_theme_font_size_override("font_size", 46)
		rot_a.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		rot_a.add_theme_constant_override("outline_size", 8)
		camada_a.add_child(rot_a)
		for dados in [["arma_rajada", "Rajada", PI - 0.9, 0.42], ["arma_canhao", "Canhão", PI - 0.9, 0.42], ["arma_precisao", "Precisão", PI - 0.9, 0.4],
				["arma_duplo", "Tiro duplo", PI, 0.42], ["lanca_misseis", "Lança-mísseis (ombro esquerdo)", 0.75, 0.68], ["lanca_granadas", "Lança-granadas (ombro direito)", -0.75, 0.68]]:
			_robo([dados[0]])
			rot_a.text = dados[1]
			_olhar(_h, dados[2], 0.25, 1.45, dados[3])
			await _foto("arma_" + String(dados[0]))
		_robo(["vida", "escudo"])
		rot_a.text = "Vida extra (ombreiras) e escudo"
		_olhar(_h, PI + 0.9, 0.25, 1.5, 0.55)
		await _foto("arma_vida_escudo_costas")
		_olhar(_h, PI - 0.5, 0.3, 1.5, 0.62)
		await _foto("arma_vida_escudo_frente")
		_robo(["arma_canhao", "lanca_misseis", "lanca_granadas"])
		rot_a.text = "Canhão e os dois lançadores"
		_olhar(_h, 0.35, 0.3, 2.4, 0.55)
		await _foto("arma_tudo_costas")
		_olhar(_h, PI - 0.5, 0.25, 2.4, 0.55)
		await _foto("arma_tudo_frente")
		return
	var camada := CanvasLayer.new()
	root.add_child(camada)
	var rot := Label.new()
	rot.position = Vector2(28, 20)
	rot.add_theme_font_size_override("font_size", 46)
	rot.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	rot.add_theme_constant_override("outline_size", 8)
	camada.add_child(rot)
	var so: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--so="):
			so = arg.substr(5)
	var n := 0
	for vista in VISTAS:
		n += 1
		if so != "" and so != vista[0]:
			continue
		MelhoriasVisual.jato = vista[0] == "bocais"
		var v := _robo([vista[0]])
		var sobe := 0.0
		if vista[0] == "bocais":
			sobe = 0.32
			v.position.y = h * sobe
		rot.text = vista[1]
		_olhar(h, vista[2], vista[3], vista[4], vista[5] + sobe)
		await _foto("%d_%s" % [n, vista[0]])
	MelhoriasVisual.jato = false
	if so == "" or so == "asas":
		for aberta in [false, true]:
			MelhoriasVisual.asas_fator = 1.0 if aberta else 0.0
			_robo(["asas"])
			rot.text = "Asas de planar: " + ("abertas" if aberta else "recolhidas")
			_olhar(h, 0.3, 0.6, 2.3 if aberta else 1.3, 0.6)
			await _foto("a%d_asas" % int(aberta))
		MelhoriasVisual.asas_fator = 0.0
	if so == "" or so == "farol":
		for aceso in [false, true]:
			MelhoriasVisual.farol_aceso = aceso
			_robo(["farol"])
			rot.text = "Luz do peito: " + ("acesa" if aceso else "apagada")
			_olhar(h, PI - 0.5, 0.25, 1.2, 0.6)
			await _foto("f%d_farol" % int(aceso))
	if so != "":
		return
	_robo(MelhoriasVisual.NOMES)
	rot.text = "Todas juntas, de frente"
	_olhar(h, PI - 0.5, 0.22, 2.9, 0.54)
	await _foto("t1_frente")
	rot.text = "Todas juntas, de costas"
	_olhar(h, 0.22, 0.5, 2.9, 0.54)
	await _foto("t2_costas")
	MelhoriasVisual.asas_fator = 1.0
	_robo(MelhoriasVisual.NOMES)
	rot.text = "Todas juntas, planando"
	_olhar(h, 0.22, 0.5, 2.9, 0.54)
	await _foto("t3_planando")
	MelhoriasVisual.asas_fator = 0.0
	rot.text = "Robô básico, de costas"
	_robo([])
	_olhar(h, 0.5, 0.3, 1.6, 0.56)
	await _foto("t0_hoje")
