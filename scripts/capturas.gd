class_name Capturas
extends Node
## `godot --path . -- --captura`: tira fotos das situações da etapa 1 em tools/capturas/.

var m: Node
var a: Armadura
var cam: CameraVoo
var pasta := ""


func rodar(main: Node) -> void:
	m = main
	a = main.armadura
	cam = main.camera
	pasta = ProjectSettings.globalize_path("res://tools/capturas/")
	DirAccess.make_dir_recursive_absolute(pasta)
	var il: Ilha = main.ilha
	await _esperar(1.0)
	# 1. de pé na beira do lago, olhando o morro
	a.recomecar()
	cam.pitch = -0.08
	await _esperar(1.5)
	await _foto("c01_chao")
	# 2. correndo
	Input.action_press("frente")
	Input.action_press("correr")
	await _esperar(1.3)
	await _foto("c02_correndo")
	Input.action_release("frente")
	Input.action_release("correr")
	await _esperar(0.8)
	# 3. decolagem
	cam.pitch = 0.05
	Input.action_press("pular")
	await _esperar(0.55)
	Input.action_release("pular")
	await _foto("c03_decolagem")
	await _esperar(1.5)
	# 4. voo sobre a mata, indo para o morro
	var morro := Vector3(330, 0, -270)
	var de := Vector3(-450, 0, 380)
	var dir := (morro - de).normalized()
	cam.yaw = atan2(-dir.x, -dir.z)
	cam.pitch = -0.03
	a.calor = 20.0
	a.teleportar(Vector3(de.x, il.altura(de.x, de.z) + 55.0, de.z), Armadura.Estado.VOO, dir * 30.0)
	await _esperar(1.6)
	await _foto("c04_voo_mata")
	# 5. arrancada
	Input.action_press("correr")
	await _esperar(1.6)
	await _foto("c05_arrancada")
	Input.action_release("correr")
	# 6. planando com as aletas abertas
	a.calor = 50.0
	cam.yaw = atan2(-dir.x, -dir.z) + 0.35
	cam.pitch = -0.25
	a.teleportar(Vector3(0, 260, 0), Armadura.Estado.PLANAR, -Basis(Vector3.UP, cam.yaw).z * 28.0)
	await _esperar(1.4)
	await _foto("c06_planando")
	# 7. rasante no lago
	cam.yaw = 0.0
	cam.pitch = -0.05
	a.calor = 75.0
	a.teleportar(Vector3(il.lago_centro.x, il.lago_nivel + 4.0, il.lago_centro.y + 120.0), Armadura.Estado.VOO, Vector3(0, 0, -30))
	await _esperar(0.7)
	await _foto("c07_rasante_lago")
	# 8. mergulho do alto
	cam.yaw = atan2(-dir.x, -dir.z)
	cam.pitch = -1.0
	a.calor = 60.0
	a.teleportar(Vector3(-200, 760, 300), Armadura.Estado.PLANAR, -Basis(Vector3.UP, cam.yaw).z * 30.0)
	await _esperar(3.0)
	await _foto("c08_mergulho")
	# 9. superaquecido
	cam.pitch = 0.05
	a.superaquecido = false
	a.teleportar(Vector3(-300, 300, 300), Armadura.Estado.VOO, -Basis(Vector3.UP, cam.yaw).z * 30.0)
	a.calor = 99.0
	Input.action_press("correr")
	await _esperar(0.5)
	Input.action_release("correr")
	await _foto("c09_superaquecido")
	# 10. a ilha do alto, com o medidor ligado
	a.superaquecido = false
	a.calor = 10.0
	var canto := Vector3(-880, 0, 880)
	var para_centro := (Vector3.ZERO - canto).normalized()
	cam.yaw = atan2(-para_centro.x, -para_centro.z)
	cam.pitch = -0.42
	a.teleportar(Vector3(canto.x, 620.0, canto.z), Armadura.Estado.VOO, para_centro * 30.0)
	m.hud.medidor = true
	await _esperar(1.2)
	await _foto("c10_ilha_do_alto_medidor")
	m.hud.medidor = false
	# 11. pulo duplo (brilho dos propulsores)
	a.calor = 0.0
	a.recomecar()
	cam.pitch = -0.05
	await _esperar(0.8)
	Input.action_press("pular")
	await _esperar(0.08)
	Input.action_release("pular")
	await _esperar(0.3)
	Input.action_press("pular")
	await _esperar(0.06)
	Input.action_release("pular")
	await _esperar(0.12)
	await _foto("c11_pulo_duplo")
	await _esperar(1.5)
	# 12. esquiva para o lado
	Input.action_press("direita")
	Input.action_press("soltar")
	await _esperar(0.06)
	Input.action_release("soltar")
	await _esperar(0.1)
	await _foto("c12_esquiva")
	Input.action_release("direita")
	await _esperar(0.8)
	# 13. mirando no chão e marcando um ponto no morro
	a.recomecar()
	cam.pitch = 0.02
	Input.action_press("mirar")
	await _esperar(0.9)
	Input.action_press("marcar")
	await _esperar(0.1)
	Input.action_release("marcar")
	await _esperar(0.4)
	await _foto("c13_mirando_chao")
	Input.action_release("mirar")
	# 14. pairando no alto, mirando
	var sobre := il.lago_centro + Vector2(-60, 120)
	cam.yaw = atan2(-dir.x, -dir.z)
	cam.pitch = -0.12
	a.teleportar(Vector3(sobre.x, il.altura(sobre.x, sobre.y) + 45.0, sobre.y), Armadura.Estado.VOO, dir * 25.0)
	await _esperar(0.4)
	Input.action_press("mirar")
	await _esperar(1.8)
	await _foto("c14_pairando")
	Input.action_release("mirar")
	print("CAPTURAS OK em ", pasta)
	get_tree().quit()


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(pasta + nome + ".png")
	print("foto ", nome)
