extends Node
## `godot --path . -- --mundo-captura`: fotos do mundo em tools/capturas/mundo/, com o fps de cada uma.

var m: Node
var a: Armadura
var cam: CameraVoo
var w: Mundo
var pasta := ""


func rodar(main: Node) -> void:
	m = main
	a = main.armadura
	cam = main.camera
	w = main.ilha
	pasta = ProjectSettings.globalize_path("res://tools/capturas/mundo/")
	DirAccess.make_dir_recursive_absolute(pasta)
	await _esperar(3.0)
	a.recomecar()
	cam.pitch = -0.1
	await _esperar(3.0)
	await _foto("m01_plato_da_chegada")
	var g := Vector3(-80, 0, 450)  # dentro da Garganta, descendo para o Vale dos Pilares
	await _voo(Vector3(g.x, w.altura(g.x, g.z) + 55.0, g.z), Vector3(-380, 60, 880), 0.0, "m02_garganta")
	var p := _lugar("Vale dos Pilares")
	await _voo(Vector3(p.x - 220, 330, p.z - 300), p, -0.5, "m03_vale_dos_pilares")
	var l := _lugar("Lago Suspenso")
	await _voo(Vector3(l.x + 60, 360, l.z + 640), l, -0.42, "m04_lago_suspenso")
	var q: Vector3 = w.quedas[0]
	await _voo(Vector3(w.lago_centro.x + 60, w.nivel_lago + 55, w.lago_centro.y + 40), q, 0.05, "m05_queda_do_veu")
	var b := _lugar("Bosque Colossal")
	await _voo(b + Vector3(300, 120, 240), b + Vector3(0, 30, 0), -0.15, "m06_bosque_colossal")
	await _voo(Vector3(-1500, 620, 1500), Vector3(0, 60, 0), -0.3, "m07_ilha_do_alto")
	m.hud.medidor = true
	var c := _lugar("Costa dos Paredões")
	await _voo(Vector3(c.x - 150, 330, c.z - 560), c, -0.4, "m08_costa_medidor")
	print("CAPTURAS DO MUNDO OK em ", pasta)
	get_tree().quit()


func _lugar(nome: String) -> Vector3:
	for l in w.lugares:
		if l["nome"] == nome:
			var p: Vector3 = l["pos"]
			return Vector3(p.x, maxf(w.altura(p.x, p.z), w.agua(p.x, p.z)), p.z)
	return Vector3.ZERO


func _voo(de: Vector3, para: Vector3, pitch: float, nome: String) -> void:
	var dir := (para - de)
	dir.y = 0.0
	dir = dir.normalized()
	cam.yaw = atan2(-dir.x, -dir.z)
	cam.pitch = pitch
	a.calor = 15.0
	a.superaquecido = false
	a.teleportar(de, Armadura.Estado.VOO, dir * 30.0)
	await _esperar(1.7)
	await _foto(nome)


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var tri := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	get_viewport().get_texture().get_image().save_png(pasta + nome + ".png")
	print("foto %s: %d fps, %.1f M triângulos, %d chamadas" % [nome, fps, tri / 1e6, dc])
