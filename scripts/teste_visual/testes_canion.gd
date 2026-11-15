extends Node
## `godot --headless --path . -- --teste-canion`: bateria do cânion. Chão no platô, andar, decolar e voar pelo
## vale, a cachoeira esfria, o rio é água, batida no paredão, pouso no pilar e queda no fundo.
## Termina com "CANION OK (N pontos)" ou "CANION FALHOU: x de N" (código 1).

var m: Node
var a: Armadura
var cam: CameraVoo
var c: Canion
var falhas := 0
var pontos := 0


func rodar(main: Node) -> void:
	m = main
	a = main.armadura
	cam = main.camera
	c = main.ilha
	await _esperar(0.3)
	await _ponto_1()
	await _ponto_2()
	await _ponto_3()
	await _ponto_4()
	await _ponto_5()
	await _ponto_6()
	await _ponto_7()
	await _ponto_8()
	await _ponto_9()
	print("")
	if falhas == 0:
		print("CANION OK (%d pontos)" % pontos)
	else:
		print("CANION FALHOU: %d de %d" % [falhas, pontos])
	get_tree().quit(1 if falhas > 0 else 0)


func _ok(cond: bool, texto: String) -> void:
	pontos += 1
	if cond:
		print("  ok      ", texto)
	else:
		falhas += 1
		print("  FALHOU  ", texto)


func _esperar(seg: float) -> void:
	for i in roundi(seg * 60.0):
		await get_tree().physics_frame


func _soltar_tudo() -> void:
	for acao in ["frente", "tras", "esquerda", "direita", "pular", "correr", "soltar", "correr_alternar", "mirar", "marcar"]:
		Input.action_release(acao)


func _hv() -> float:
	return Vector2(a.velocity.x, a.velocity.z).length()


func _ponto_1() -> void:
	print("começa de pé no platô")
	a.recomecar()
	await _esperar(1.0)
	var y: float = a.global_position.y
	var agua_aqui: float = c.agua(a.global_position.x, a.global_position.z)
	_ok(a.estado == Armadura.Estado.CHAO and a.is_on_floor() and absf(y - Canion.ALTO) < 4.0 and agua_aqui == -INF,
		"começa de pé no chão do platô (%s, y %.1f m, ALTO %.0f m, água %s)" % [a.nome_estado(), y, Canion.ALTO, str(agua_aqui)])
	_soltar_tudo()


func _ponto_2() -> void:
	print("anda para um rumo livre")
	a.recomecar()
	await _esperar(0.6)
	var yaw: float = c.rumo_livre(a.global_position, 20.0)
	cam.yaw = yaw
	Input.action_press("frente")
	await _esperar(2.0)
	var v := _hv()
	_soltar_tudo()
	_ok(absf(v - Ajustes.ANDAR) < 0.6, "anda a ~3 m/s no rumo livre (%.2f m/s, %s)" % [v, a.nome_estado()])
	await _esperar(0.5)


func _ponto_3() -> void:
	print("decolagem segurando o pulo")
	a.recomecar()
	await _esperar(0.6)
	var y0: float = a.global_position.y
	Input.action_press("pular")
	await _esperar(0.45)
	Input.action_release("pular")
	await _esperar(1.5)
	var subiu: float = a.global_position.y - y0
	_ok(a.estado == Armadura.Estado.VOO and subiu > 12.0, "segurar o pulo decola e entra em voo (%s, subiu %.1f m)" % [a.nome_estado(), subiu])
	_soltar_tudo()


func _ponto_4() -> void:
	print("voo pelo meio do cânion")
	var z0 := -230.0
	a.calor = 0.0
	a.superaquecido = false
	cam.pitch = 0.0
	a.teleportar(Vector3(c.centro_x(z0), 45.0, z0), Armadura.Estado.VOO, Vector3(0, 0, 30.0))
	var bateu := false
	for i in 360:
		var p: Vector3 = a.global_position
		var alvo_x: float = c.centro_x(p.z + 40.0)
		cam.yaw = atan2(-(alvo_x - p.x), -40.0)
		cam.pitch = 0.0
		if i % 60 == 0:
			a.calor = 0.0
			a.superaquecido = false
		if a.estado == Armadura.Estado.AR or a.estado == Armadura.Estado.CHAO:
			bateu = true
		await get_tree().physics_frame
	var avancou: float = a.global_position.z - z0
	var no_ar := a.estado == Armadura.Estado.VOO or a.estado == Armadura.Estado.PLANAR
	_ok(no_ar and not bateu and avancou > 120.0,
		"voa 6 s pelo meio do cânion sem bater (%s, avançou %.0f m em z, y %.1f m)" % [a.nome_estado(), avancou, a.global_position.y])
	_soltar_tudo()
	cam.pitch = -0.12


func _ponto_5() -> void:
	print("a cachoeira esfria")
	var meio: Vector3 = (c.lip + c.poco) * 0.5
	a.calor = 80.0
	a.superaquecido = false
	Input.action_press("mirar")
	a.teleportar(Vector3(meio.x, 50.0, meio.z), Armadura.Estado.PAIRAR)
	await _esperar(0.5)
	var calor: float = a.calor
	_ok(a.na_agua and calor < 65.0, "a coluna da cachoeira conta como água e esfria (na_agua %s, calor %.1f)" % [str(a.na_agua), calor])
	_soltar_tudo()


func _ponto_6() -> void:
	print("o rio é água e o platô não")
	var no_rio: float = c.agua(c.rio_x(100.0), 100.0)
	var no_platô: float = c.agua(c.borda_x(-200.0, 1.0) + 30.0, -200.0)
	_ok(absf(no_rio - Canion.NIVEL_RIO) < 0.01 and no_platô == -INF,
		"rio devolve NIVEL_RIO (%.2f) e o platô devolve -INF (%s)" % [no_rio, str(no_platô)])


func _ponto_7() -> void:
	print("bater de frente no paredão")
	cam.yaw = -PI / 2.0
	cam.pitch = 0.0
	a.calor = 0.0
	a.superaquecido = false
	a.teleportar(Vector3(c.centro_x(0.0), 60.0, 0.0), Armadura.Estado.VOO, Vector3(32.0, 0.0, 0.0))
	var bateu := false
	var x0: float = a.global_position.x
	for i in 180:
		await get_tree().physics_frame
		if i % 60 == 0:
			a.calor = 0.0
		if a.estado == Armadura.Estado.AR:
			bateu = true
			break
	var andou: float = a.global_position.x - x0
	_ok(bateu, "bate no paredão e cai do voo (%s, andou %.1f m em x, y %.1f m)" % [a.nome_estado(), andou, a.global_position.y])
	_soltar_tudo()
	cam.yaw = 0.0


func _ponto_8() -> void:
	print("pousa no topo de um pilar")
	var p: Vector4 = c.pilares[1]
	var topo: float = Canion.FUNDO + p.w
	a.calor = 0.0
	a.teleportar(Vector3(p.x, topo + 6.0, p.y), Armadura.Estado.AR, Vector3.ZERO)
	var pousou := false
	for i in 180:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.CHAO:
			pousou = true
			break
	var y: float = a.global_position.y
	var limite: float = Canion.FUNDO + p.w - 12.0
	_ok(pousou and y > limite, "pousa no pilar em até 3 s e fica no alto (%s, y %.1f m, limite %.1f m)" % [a.nome_estado(), y, limite])
	_soltar_tudo()


func _ponto_9() -> void:
	print("cair no fundo não atravessa o chão")
	# +30 m cai em cima do pilares[1] (ele fica em centro_x(150) + 30); o vale fica do outro lado
	var x: float = c.centro_x(150.0) - 30.0
	a.calor = 0.0
	a.teleportar(Vector3(x, 20.0, 150.0), Armadura.Estado.AR, Vector3.ZERO)
	var ymin := 1e9
	var no_chao := false
	for i in 240:
		await get_tree().physics_frame
		ymin = minf(ymin, a.global_position.y)
		if a.estado == Armadura.Estado.CHAO or a.estado == Armadura.Estado.POUSO:
			no_chao = true
			break
	_ok(no_chao and ymin > Canion.FUNDO - 3.0 and a.global_position.y > Canion.FUNDO - 3.0,
		"cai no fundo e para no chão sem atravessar (%s, y %.1f m, menor y %.1f m)" % [a.nome_estado(), a.global_position.y, ymin])
	_soltar_tudo()
