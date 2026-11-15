extends SceneTree
## Monta o Faísca da Ilha Cafuné e grava como .glb (esqueleto, peças presas aos ossos e cores).

func _init() -> void:
	var destino := OS.get_cmdline_user_args()[0]
	var r := Robo.new()
	r.rosto_parado = true
	root.add_child(r)
	await process_frame
	await process_frame
	r.tpose()
	var n := 0
	for mi: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
		var m := mi.material_override
		if m == r.mat.rosto:
			mi.name = "rosto"
		elif mi in r._jatos:
			mi.name = "jato_%d" % r._jatos.find(mi)
			mi.visible = true
		elif mi in r._carga:
			mi.name = "carga_%d" % r._carga.find(mi)
		else:
			mi.name = "peca_%d" % n
		n += 1
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).next_pass = null
	print("pecas ", n, " ossos ", r.esqueleto.get_bone_count())
	for b in r.esqueleto.get_bone_count():
		print("  ", b, " ", r.esqueleto.get_bone_name(b), " pai ", r.esqueleto.get_bone_parent(b))
	# cena do Godot (o .glb gravava os ossos como nós soltos, sem esqueleto): tudo embutido, sem apontar
	# para arquivos da Ilha Cafuné
	for mi: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override is ShaderMaterial:
			mi.material_override = null
	r.set_script(null)
	r.name = "Faisca"
	_adotar(r, r)
	var cena := PackedScene.new()
	print("pack ", cena.pack(r))
	print("save ", ResourceSaver.save(cena, destino))
	quit()


func _adotar(n: Node, dono: Node) -> void:
	for f in n.get_children():
		f.scene_file_path = ""
		f.owner = dono
		_adotar(f, dono)
