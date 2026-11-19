extends SceneTree
## Fotos de modelos de fora do projeto, para escolher (os candidatos a minichefe e a inimigo novo).
## godot --path . -s tools/vitrine_modelos.gd

const O := "/Users/welington/Documents/Projects/others/bibliotecas/"
const MODELOS := [
	["CombatMech (KayKit)", "kaykit-complete-v6-1-assets/KayKit Mystery Monthly Series 5 (1.1)/1 - July 2024 - Combat Mech/characters/CombatMech.glb"],
	["Leela (Quaternius)", "Animated Mech Pack - March 2021/Textured/glTF/Leela.gltf"],
	["Mike (Quaternius)", "Animated Mech Pack - March 2021/Textured/glTF/Mike.gltf"],
	["Stan (Quaternius)", "Animated Mech Pack - March 2021/Textured/glTF/Stan.gltf"],
	["EyeDrone (Quaternius)", "Sci-Fi Essentials Kit[Standard]/glTF/Enemy_EyeDrone.gltf"],
	["QuadShell (Quaternius)", "Sci-Fi Essentials Kit[Standard]/glTF/Enemy_QuadShell.gltf"],
	["Trilobite (Quaternius)", "Sci-Fi Essentials Kit[Standard]/glTF/Enemy_Trilobite.gltf"],
]


func _initialize() -> void:
	root.size = Vector2i(800, 800)
	DisplayServer.window_set_size(Vector2i(800, 800))
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
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.make_current()
	var camada := CanvasLayer.new()
	root.add_child(camada)
	var rot := Label.new()
	rot.position = Vector2(24, 16)
	rot.add_theme_font_size_override("font_size", 40)
	rot.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	rot.add_theme_constant_override("outline_size", 8)
	camada.add_child(rot)
	_rodar(cam, rot)


func _rodar(cam: Camera3D, rot: Label) -> void:
	var n := 0
	for dados in MODELOS:
		n += 1
		var doc := GLTFDocument.new()
		var estado := GLTFState.new()
		if doc.append_from_file(O + dados[1], estado) != OK:
			print("não abriu: ", dados[1])
			continue
		var no := doc.generate_scene(estado) as Node3D
		root.add_child(no)
		var anims := []
		var tri := 0
		for ap: AnimationPlayer in no.find_children("*", "AnimationPlayer", true, false):
			anims = ap.get_animation_list()
			for a in anims:
				if String(a).to_lower().contains("idle"):
					ap.play(a)
		for i in 6:
			await process_frame
		var caixa := AABB()
		var primeiro := true
		for mi: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
			var a := mi.global_transform * mi.get_aabb()
			caixa = a if primeiro else caixa.merge(a)
			primeiro = false
			for s in mi.mesh.get_surface_count():
				tri += mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3 if mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] != null else 0
		no.position.y -= caixa.position.y
		var meio := caixa.get_center() - Vector3(0, caixa.position.y, 0)
		var tam := maxf(caixa.size.y, maxf(caixa.size.x, caixa.size.z))
		cam.global_position = meio + Vector3(sin(0.6), 0.28, cos(0.6)).normalized() * tam * 2.9
		cam.look_at(meio)
		rot.text = "%s\n%.1f m de altura · %d mil triângulos · %d animações" % [dados[0], caixa.size.y, int(tri / 1000.0), anims.size()]
		print("%s: altura %.2f, %d triângulos, animações %s" % [dados[0], caixa.size.y, tri, anims])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/capturas/chefes/%d.png" % n)
		no.queue_free()
		await process_frame
	quit()
