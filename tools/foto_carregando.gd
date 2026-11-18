extends SceneTree

## Fotos da tela de carregamento em três momentos: `godot --path . -s tools/foto_carregando.gd`.

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	var c := Carregando.new()
	root.add_child(c)
	DirAccess.make_dir_recursive_absolute("res://tools/capturas/carregando")
	for par: Array in [[0.12, "Abrindo a clareira", "a"], [0.54, "Espalhando flores e pedras", "b"], [0.92, "Acordando os bichos e as máquinas", "c"]]:
		await c.mostrar(par[0], par[1])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/capturas/carregando/%s.png" % par[2])
	quit()
