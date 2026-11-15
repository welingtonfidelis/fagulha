class_name CapturasCanion
extends Node
## `godot --path . -- --canion-captura`: fotos do teste de qualidade visual em tools/capturas/canion/,
## com o fps de cada uma impresso (no Mac).

var m: Node
var a: Armadura
var cam: CameraVoo
var c: Canion
var pasta := ""


func rodar(main: Node) -> void:
	m = main
	a = main.armadura
	cam = main.camera
	c = main.ilha
	pasta = ProjectSettings.globalize_path("res://tools/capturas/canion_b/" if Main.mapa == "canion_b" else "res://tools/capturas/canion/")
	DirAccess.make_dir_recursive_absolute(pasta)
	await _esperar(2.5)
	# 1. na borda do platô, olhando a cachoeira do outro lado
	a.recomecar()
	cam.pitch = -0.12
	await _esperar(3.0)
	await _foto("v01_borda")
	# 2. voo baixo dentro do cânion, indo para o vale dos pilares
	var z0 := -210.0
	var de := Vector3(c.centro_x(z0), 32.0, z0)
	var para := Vector3(c.centro_x(z0 + 70.0), 32.0, z0 + 70.0)
	_voar(de, para, 0.0, 30.0)
	await _esperar(1.8)
	await _foto("v02_voo_canion")
	# 3. pairando na frente da cachoeira
	var olho := c.poco + Vector3(48.0, 34.0, 30.0)
	_voar(olho, olho + Vector3(-1, 0, -0.6), 0.0, 4.0)
	var meio := (c.lip + c.poco) * 0.5
	var d := (meio - olho).normalized()
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = asin(d.y) + 0.05
	Input.action_press("mirar")
	await _esperar(2.2)
	await _foto("v03_cachoeira")
	Input.action_release("mirar")
	# 4. no fundo do vale, olhando o pilar maior
	var p: Vector4 = c.pilares[1]
	var chao := Vector3(p.x - 45.0, 0.0, p.y - 40.0)
	chao.y = c.altura(chao.x, chao.z) + 0.3
	a.teleportar(chao, Armadura.Estado.CHAO)
	var ate := Vector3(p.x, 40.0, p.y) - chao
	cam.yaw = atan2(-ate.x, -ate.z)
	cam.pitch = 0.32
	await _esperar(2.5)
	await _foto("v04_fundo_do_vale")
	# 5. por cima dos pilares
	var zv := 70.0
	_voar(Vector3(c.centro_x(zv) + 40.0, 165.0, zv), Vector3(c.centro_x(zv + 80.0), 150.0, zv + 80.0), -0.42, 28.0)
	await _esperar(1.8)
	await _foto("v05_pilares_do_alto")
	# 6. passando por baixo da ponte de pedra
	var zp := Canion.Z_PONTE - 90.0
	_voar(Vector3(c.centro_x(zp), 70.0, zp), Vector3(c.centro_x(Canion.Z_PONTE), 75.0, Canion.Z_PONTE), 0.08, 30.0)
	await _esperar(1.6)
	await _foto("v06_ponte")
	# 7. de novo na borda, com o medidor
	a.recomecar()
	cam.pitch = -0.12
	m.hud.medidor = true
	await _esperar(2.5)
	await _foto("v07_medidor")
	print("CAPTURAS DO CÂNION OK em ", pasta)
	get_tree().quit()


func _voar(de: Vector3, para: Vector3, pitch: float, vel: float) -> void:
	var dir := (para - de).normalized()
	cam.yaw = atan2(-dir.x, -dir.z)
	cam.pitch = pitch
	a.calor = 20.0
	a.teleportar(de, Armadura.Estado.VOO, dir * vel)


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var tri := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	get_viewport().get_texture().get_image().save_png(pasta + nome + ".png")
	print("foto %s: %d fps, %.1f M triângulos, %d chamadas" % [nome, fps, tri / 1e6, dc])
