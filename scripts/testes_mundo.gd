extends Node
## `godot --headless --path . -- --teste-mundo`: bateria do mapa "mundo" (sem janela). Confere o começo no
## Platô da Chegada, andar, decolar, os lugares do dados.json, o lago, o mar, as cachoeiras, o voo alto
## sobre a ilha, a queda no chão e a troca de lugar. Não usa altura fixa: tudo sai de altura(), agua() e
## normal_em(), então continua valendo quando alguém mudar o relevo.
## Termina com "MUNDO OK (N pontos)" ou "MUNDO FALHOU: x de N" (código 1).

var m: Node
var a: Armadura
var cam: CameraVoo
var w: Mundo
var falhas := 0
var pontos := 0


func rodar(main: Node) -> void:
	m = main
	a = main.armadura
	cam = main.camera
	w = main.ilha as Mundo
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
	await _ponto_10()
	print("")
	if falhas == 0:
		print("MUNDO OK (%d pontos)" % pontos)
	else:
		print("MUNDO FALHOU: %d de %d" % [falhas, pontos])
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


## Ponto de chão (fora d'água, plano o bastante) mais perto de (cx, cz); Vector2.INF se não achar.
func _chao_perto(cx: float, cz: float) -> Vector2:
	for raio in range(0, 1200, 25):
		for k in 24:
			var ang := TAU * k / 24.0
			var p := Vector2(cx, cz) + Vector2(cos(ang), sin(ang)) * float(raio)
			if absf(p.x) > 1900.0 or absf(p.y) > 1900.0:
				continue
			if w.agua(p.x, p.y) == -INF and w.normal_em(p.x, p.y).y > 0.9:
				return p
	return Vector2.INF


func _ponto_1() -> void:
	print("começa de pé no Platô da Chegada")
	a.recomecar()
	await _esperar(1.0)
	var agua_aqui: float = w.agua(a.global_position.x, a.global_position.z)
	var lugar: String = m.locais.atual
	_ok(a.estado == Armadura.Estado.CHAO and a.is_on_floor() and agua_aqui == -INF and lugar == "Platô da Chegada",
		"começa de pé, fora d'água, no lugar certo (%s, água %s, lugar \"%s\")" % [a.nome_estado(), str(agua_aqui), lugar])
	_soltar_tudo()


func _ponto_2() -> void:
	print("anda para um rumo livre")
	a.recomecar()
	await _esperar(0.6)
	cam.yaw = w.rumo_livre(a.global_position, 20.0)
	Input.action_press("frente")
	await _esperar(2.0)
	var v := _hv()
	_soltar_tudo()
	_ok(absf(v - Ajustes.ANDAR) < 0.6 and a.estado == Armadura.Estado.CHAO,
		"anda a ~3 m/s no rumo livre (%.2f m/s, %s)" % [v, a.nome_estado()])
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
	_ok(a.estado == Armadura.Estado.VOO and subiu > 12.0,
		"segurar o pulo decola e entra em voo (%s, subiu %.1f m)" % [a.nome_estado(), subiu])
	_soltar_tudo()


func _ponto_4() -> void:
	print("lugares do dados.json no mundo")
	var total := 0
	var achados := 0
	var faltam: Array[String] = []
	for l: Dictionary in w.dados["locais"]:
		var nome: String = l["nome"]
		total += 1
		var achou := false
		for lug: Dictionary in w.lugares:
			if lug["nome"] == nome:
				achou = true
		if achou:
			achados += 1
		else:
			faltam.append(nome)
	_ok(total > 0 and achados == total and w.lugares.size() == total,
		"os lugares do dados.json existem em main.ilha.lugares (%d de %d, sobram %d, faltam %s)"
		% [achados, total, w.lugares.size() - achados, str(faltam)])


func _ponto_5() -> void:
	print("o lago é água e esfria a rasante")
	var nivel_no_centro: float = w.agua(w.lago_centro.x, w.lago_centro.y)
	var centro := Vector3(w.lago_centro.x, w.nivel_lago + 4.0, w.lago_centro.y)
	a.calor = 80.0
	a.superaquecido = false
	a.teleportar(centro, Armadura.Estado.VOO, Vector3(30.0, 0.0, 0.0))
	await _esperar(0.5)
	var calor: float = a.calor
	_ok(absf(nivel_no_centro - w.nivel_lago) < 0.01 and calor < 62.0,
		"lago: agua %.2f (nível %.2f); rasante a 30 m/s esfria de 80 para %.1f em 0,5 s" % [nivel_no_centro, w.nivel_lago, calor])
	_soltar_tudo()


func _ponto_6() -> void:
	print("o mar é água")
	# procura um ponto a 2040 m do centro que seja mar (altura abaixo de zero)
	var no_mar := Vector2.INF
	var alt := 0.0
	var testados := 0
	for k in 64:
		var ang := TAU * k / 64.0
		var p := Vector2(cos(ang), sin(ang)) * 2040.0
		testados += 1
		if no_mar == Vector2.INF and w.altura(p.x, p.y) < -1.0:
			no_mar = p
			alt = w.altura(p.x, p.y)
	var ag := 0.0
	if no_mar != Vector2.INF:
		ag = w.agua(no_mar.x, no_mar.y)
	_ok(no_mar != Vector2.INF and absf(ag) < 0.01,
		"mar a 2040 m do centro: agua %s em (%.0f, %.0f), altura %.1f m (%d ângulos testados)"
		% [str(ag), no_mar.x, no_mar.y, alt, testados])


func _ponto_7() -> void:
	print("as cachoeiras esfriam")
	var relatos: Array[String] = []
	var tudo := not w.quedas.is_empty()
	for q: Vector3 in w.quedas:
		a.calor = 80.0
		a.superaquecido = false
		Input.action_press("mirar")
		a.teleportar(q, Armadura.Estado.PAIRAR)
		await _esperar(0.5)
		var calor: float = a.calor
		var na: bool = a.na_agua
		if not (na and calor < 65.0):
			tudo = false
		relatos.append("(%.0f, %.0f) na_agua %s calor %.1f" % [q.x, q.z, str(na), calor])
		_soltar_tudo()
		await _esperar(0.3)
	_ok(tudo, "cada cachoeira conta como água e esfria: %s" % str(relatos))


func _ponto_8() -> void:
	print("voo alto atravessando a ilha")
	var hmax := -INF
	for i in 65:
		for j in 65:
			hmax = maxf(hmax, w.altura(-2048.0 + i * 64.0, -2048.0 + j * 64.0))
	var x0 := -1800.0
	cam.yaw = -PI / 2.0
	cam.pitch = 0.0
	a.calor = 0.0
	a.superaquecido = false
	a.teleportar(Vector3(x0, hmax + 150.0, 0.0), Armadura.Estado.VOO, Vector3(30.0, 0.0, 0.0))
	var saiu := ""
	for i in 1200:
		await get_tree().physics_frame
		if i % 60 == 0:
			a.calor = 0.0
			a.superaquecido = false
		if saiu == "" and a.estado != Armadura.Estado.VOO:
			saiu = a.nome_estado()
	var avancou: float = a.global_position.x - x0
	var sobre: float = a.global_position.y - w.altura(a.global_position.x, a.global_position.z)
	_ok(a.estado == Armadura.Estado.VOO and avancou > 500.0 and saiu == "",
		"voa 20 s a 30 m/s em x sobre a ilha (altura máxima %.1f m, teto de voo %.1f m, avançou %.0f m em x, %s, saiu do voo: %s)"
		% [hmax, hmax + 150.0, avancou, a.nome_estado(), saiu if saiu != "" else "não"])
	_soltar_tudo()
	cam.yaw = 0.0
	print("        folga final sobre o terreno %.1f m" % sobre)


func _ponto_9() -> void:
	print("cair no chão não atravessa")
	var alvos: Array[Vector2] = []
	for k in 5:
		var ang := TAU * k / 5.0 + 0.3
		alvos.append(Vector2(cos(ang), sin(ang)) * 1000.0)
	var relatos: Array[String] = []
	var tudo := true
	for alvo in alvos:
		var p := _chao_perto(alvo.x, alvo.y)
		if p == Vector2.INF:
			tudo = false
			relatos.append("sem chão perto de (%.0f, %.0f)" % [alvo.x, alvo.y])
			continue
		var alt := w.altura(p.x, p.y)
		a.calor = 0.0
		a.superaquecido = false
		a.teleportar(Vector3(p.x, alt + 15.0, p.y), Armadura.Estado.AR, Vector3.ZERO)
		var estado_inicial: String = a.nome_estado()
		var chegou := false
		var ymin := 1e9
		for i in 240:
			await get_tree().physics_frame
			ymin = minf(ymin, a.global_position.y)
			if a.estado == Armadura.Estado.CHAO or a.estado == Armadura.Estado.POUSO:
				chegou = true
				break
		var y := a.global_position.y
		var ok_ponto := estado_inicial == "no ar" and chegou and y > alt - 3.0
		if not ok_ponto:
			tudo = false
		relatos.append("(%.0f, %.0f) %s, y %.1f, terreno %.1f, menor y %.1f" % [p.x, p.y, a.nome_estado(), y, alt, ymin])
		_soltar_tudo()
		await _esperar(0.2)
	_ok(tudo, "5 quedas de 15 m pousam no chão em até 4 s sem atravessar: %s" % str(relatos))


func _ponto_10() -> void:
	print("chegar a um lugar muda o lugar atual")
	var pos := Vector3.ZERO
	var achou := false
	for lug: Dictionary in w.lugares:
		if lug["nome"] == "Lago Suspenso":
			pos = lug["pos"]
			achou = true
	a.recomecar()
	await _esperar(0.3)
	var antes: String = m.locais.atual
	a.calor = 0.0
	a.teleportar(pos, Armadura.Estado.AR)
	await _esperar(0.5)
	var atual: String = m.locais.atual
	_ok(achou and atual == "Lago Suspenso",
		"teleporte para o Lago Suspenso muda o lugar atual (antes \"%s\", agora \"%s\", pos %s)" % [antes, atual, str(pos)])
	_soltar_tudo()
