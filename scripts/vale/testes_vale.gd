extends Node
## `godot --headless --path . -- --teste-vale`: bateria da clareira (o mapa de entrada), sem janela.
## Confere o começo de pé, andar e correr, decolar e voar, a lagoa que esfria, o superaquecimento, o
## pouso de herói e de leve, a pedra do mirante, os cervos, o ciclo do dia e a chuva.
## Termina com "VALE OK (N pontos)" ou "VALE FALHOU: x de N" (código 1).

var m: Node
var il: Clareira
var a: Armadura
var cam: CameraVoo
var ciclo: CicloDia
var falhas := 0
var chovendo_depois := false  # o ciclo manteve chovendo=true depois de alguns quadros?
var pontos := 0


func rodar(main: Node) -> void:
	m = main
	il = main.ilha as Clareira
	a = main.armadura
	cam = main.camera
	ciclo = main.ciclo
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
	await _ponto_11()
	await _ponto_12()
	await _ponto_13()
	await _ponto_14()
	await _ponto_15()
	await _ponto_16()
	await _ponto_17()
	await _ponto_18()
	await _ponto_19()
	await _ponto_20()
	await _ponto_21()
	print("")
	if falhas == 0:
		print("VALE OK (%d pontos)" % pontos)
	else:
		print("VALE FALHOU: %d de %d" % [falhas, pontos])
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
	for acao in ["frente", "tras", "esquerda", "direita", "pular", "correr", "soltar", "correr_alternar", "abaixar", "voar", "pairar", "golpe", "mirar", "marcar", "atirar"]:
		Input.action_release(acao)


func _apertar(acao: String) -> void:
	Input.action_press(acao)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(acao)


func _hv() -> float:
	return Vector2(a.velocity.x, a.velocity.z).length()


## Zera calor e superaquecimento (entre os pontos, e antes de cada um).
func _zerar() -> void:
	a.calor = 0.0
	a.superaquecido = false


## Forma de colisão em cápsula da armadura (para medir a altura do corpo).
func _capsula() -> CapsuleShape3D:
	for c in a.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is CapsuleShape3D:
			return (c as CollisionShape3D).shape as CapsuleShape3D
	return null


## Ponto de chão seco e plano a `dist` metros de `de`, em 24 direções; Vector2.INF se não achar.
func _ponto_livre(de: Vector2, dist: float) -> Vector2:
	for k in 24:
		var ang := TAU * k / 24.0
		var p := de + Vector2(cos(ang), sin(ang)) * dist
		if il.agua(p.x, p.y) == -INF and il.normal_em(p.x, p.y).y > 0.94 and il.altura(p.x, p.y) > Clareira.NIVEL + 0.5:
			return p
	return Vector2.INF


func _spawn_xz() -> Vector2:
	return Vector2(il.spawn.x, il.spawn.z)


## 1. começa de pé no chão, fora d'água, porte e cápsula do robô pequeno.
func _ponto_1() -> void:
	print("começa de pé no chão, fora d'água")
	_zerar()
	a.recomecar()
	await _esperar(1.0)
	var agua_aqui := il.agua(a.global_position.x, a.global_position.z)
	var cap := _capsula()
	var alt_cap := cap.height if cap else -1.0
	_ok(a.estado == Armadura.Estado.CHAO and a.is_on_floor() and agua_aqui == -INF
		and absf(Armadura.porte - 0.48) < 0.01 and absf(alt_cap - 1.2) < 0.05,
		"de pé no chão, fora d'água (%s, água %s), porte %.2f (esperado 0,48), cápsula %.2f m (esperado 1,2)"
		% [a.nome_estado(), str(agua_aqui), Armadura.porte, alt_cap])
	_soltar_tudo()


## 2. anda a Ajustes.ANDAR e corre a Ajustes.CORRER num rumo livre.
func _ponto_2() -> void:
	print("anda e corre num rumo livre")
	_zerar()
	a.recomecar()
	await _esperar(0.6)
	cam.yaw = il.rumo_livre(a.global_position, 30.0)
	Input.action_press("frente")
	await _esperar(2.0)
	var v_and := _hv()
	Input.action_press("correr")
	await _esperar(2.0)
	var v_cor := _hv()
	var est := a.nome_estado()
	_soltar_tudo()
	_ok(absf(v_and - Ajustes.ANDAR * Armadura.vel_chao) < 0.6 and absf(v_cor - Ajustes.CORRER * Armadura.vel_chao) < 0.6 and a.estado == Armadura.Estado.CHAO,
		"anda a %.2f m/s (esperado %.1f) e corre a %.2f m/s (esperado %.1f), %s"
		% [v_and, Ajustes.ANDAR * Armadura.vel_chao, v_cor, Ajustes.CORRER * Armadura.vel_chao, est])
	await _esperar(0.5)


## 3. segurar o pulo no chão decola e entra em voo, subindo mais de 18 m; com a câmera para baixo
## (pitch -0,3), continua em voo 2,5 s depois com mais de 6 m do chão.
func _ponto_3() -> void:
	print("pulo e botão de voo no ar")
	_zerar()
	a.recomecar()
	await _esperar(0.6)
	var y0 := a.global_position.y
	var topo := 0.0
	cam.pitch = 0.5
	await _apertar("pular")
	await _esperar(0.15)
	await _apertar("voar")
	for i in roundi(1.5 * 60.0):
		await get_tree().physics_frame
		topo = maxf(topo, a.global_position.y - y0)
	var estado_1 := a.nome_estado()
	var voo_1 := a.estado == Armadura.Estado.VOO
	# de novo, com a câmera olhando para baixo
	_soltar_tudo()
	a.recomecar()
	await _esperar(0.6)
	cam.pitch = -0.3
	await _apertar("pular")
	await _esperar(0.15)
	await _apertar("voar")
	await _esperar(1.4)
	var alt := a.altura_do_chao()
	var voo_2 := a.estado == Armadura.Estado.VOO and alt > 1.0
	var estado_2 := a.nome_estado()
	cam.pitch = -0.12
	_ok(voo_1 and topo > 6.0 and voo_2,
		"pulo e L3 no ar liga o voo e sobe %.1f m com a câmera para cima (esperado mais de 6, %s); com pitch -0,3, 1,4 s depois: %s a %.1f m do chão (esperado voo com mais de 1 m)"
		% [topo, estado_1, estado_2, alt])
	_soltar_tudo()


## 4. a lagoa é água; rasante na lagoa esfria (calor 80 cai pelo menos 15 em 0,5 s).
func _ponto_4() -> void:
	print("a lagoa é água e a rasante esfria")
	_zerar()
	a.recomecar()
	await _esperar(0.3)
	var nivel_lagoa := il.agua(Clareira.LAGOA.x, Clareira.LAGOA.y)
	var campo := il.agua(a.global_position.x, a.global_position.z)
	a.calor = 80.0
	a.superaquecido = false
	a.teleportar(Vector3(Clareira.LAGOA.x, Clareira.NIVEL + 4.0, Clareira.LAGOA.y), Armadura.Estado.VOO)
	await _esperar(0.5)
	var calor: float = a.calor
	var na_agua := a.na_agua
	_ok(nivel_lagoa == Clareira.NIVEL and campo == -INF and calor <= 65.0,
		"lagoa agua %s (nível %.2f), campo %s; rasante a 4 m da água esfria de 80 para %.1f em 0,5 s (na_agua %s, esperado até 65)"
		% [str(nivel_lagoa), Clareira.NIVEL, str(campo), calor, str(na_agua)])
	_soltar_tudo()


## 5. superaquecer no voo: cai (AR), não religa, e pousando de mais de QUEDA_HEROI m tem pouso_forca 1.0.
func _ponto_5() -> void:
	print("superaquecer no voo: cai, não religa, pouso de herói")
	_zerar()
	a.recomecar()
	await _esperar(0.3)
	var sx := _spawn_xz()
	var ch := il.altura(sx.x, sx.y) + 60.0
	a.teleportar(Vector3(sx.x, ch, sx.y), Armadura.Estado.VOO)
	a.calor = 99.9
	a.superaquecido = false
	await _esperar(0.3)
	var caiu := a.estado == Armadura.Estado.AR and a.superaquecido
	# tenta religar: X e mirar no ar, superaquecido, não podem ligar o voo
	Input.action_press("pular")
	await _esperar(0.1)
	Input.action_release("pular")
	await _esperar(0.2)
	Input.action_press("mirar")
	await _esperar(0.3)
	Input.action_release("mirar")
	var nao_religou := a.estado == Armadura.Estado.AR and a.superaquecido
	var forca := -1.0
	var queda := -1.0
	for i in 8 * 60:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.POUSO or a.estado == Armadura.Estado.CHAO:
			forca = a.pouso_forca
			queda = a.queda_altura
			break
	_ok(caiu and nao_religou and forca == 1.0 and queda > Ajustes.QUEDA_HEROI,
		"superaquecido no voo: cai (%s), não religa (%s), pousou de %.1f m com pouso_forca %.1f (esperado 1,0 acima de %.0f m)"
		% [str(caiu), str(nao_religou), queda, forca, Ajustes.QUEDA_HEROI])
	_soltar_tudo()


## 6. superaquecido no chão libera em 100 / ESFRIA_SUPER_CHAO segundos, com folga de 1 s.
func _ponto_6() -> void:
	print("superaquecido no chão libera em 100 / ESFRIA_SUPER_CHAO s")
	_zerar()
	a.recomecar()
	await _esperar(0.5)
	a.calor = 100.0
	a.superaquecido = true
	var frames := 0
	while a.superaquecido and frames < 10 * 60:
		await get_tree().physics_frame
		frames += 1
	var liberou := frames / 60.0
	var esperado := 100.0 / Ajustes.ESFRIA_SUPER_CHAO
	_ok(not a.superaquecido and absf(liberou - esperado) <= 1.0,
		"superaquecido no chão libera em %.2f s (esperado %.2f s, folga 1 s; calor %.1f)" % [liberou, esperado, a.calor])
	_soltar_tudo()


## 7. soltar o voo a 7 m do chão dá pouso_forca 0,5 (queda leve).
func _ponto_7() -> void:
	print("soltar o voo a 7 m do chão")
	_zerar()
	a.recomecar()
	await _esperar(0.3)
	var sx := _spawn_xz()
	var ch := il.altura(sx.x, sx.y)
	a.teleportar(Vector3(sx.x, ch + 7.0, sx.y), Armadura.Estado.VOO)
	await get_tree().physics_frame
	var alt_soltar := a.altura_do_chao()
	await _apertar("soltar")
	var forca := -1.0
	var queda := -1.0
	for i in 4 * 60:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.POUSO or a.estado == Armadura.Estado.CHAO:
			forca = a.pouso_forca
			queda = a.queda_altura
			break
	_ok(forca == 0.5,
		"soltar o voo a %.1f m do chão: pousou com queda de %.1f m e pouso_forca %.2f (esperado 0,5)" % [alt_soltar, queda, forca])
	_soltar_tudo()


## 8. pedra do mirante: teleporte 12 m acima; pousa e fica mais de 2 m acima do chão do mapa.
func _ponto_8() -> void:
	print("pedra do mirante")
	_zerar()
	var mir := Clareira.MIRANTE
	var ch := il.altura(mir.x, mir.y)
	a.teleportar(Vector3(mir.x, ch + 12.0, mir.y), Armadura.Estado.AR)
	var estado_ini := a.nome_estado()
	var chegou := false
	for i in 8 * 60:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.CHAO and a.is_on_floor():
			chegou = true
			break
	await _esperar(0.5)
	var sobre := a.altura_do_chao()
	_ok(estado_ini == "no ar" and chegou and sobre > 2.0,
		"pedra do mirante em (%.0f, %.0f): começa %s, pousa %s, %.1f m acima do chão do mapa (esperado mais de 2; chão do mapa %.1f m)"
		% [mir.x, mir.y, estado_ini, str(chegou), sobre, ch])
	_soltar_tudo()


## 9. cervos: existem 3, nenhum dentro d'água; um cervo a 30 m parado continua pastando ou andando
## depois de 3 s; o robô a 6 m dele faz o cervo fugir em até 2 s.
func _ponto_9() -> void:
	print("cervos")
	_zerar()
	var cervos: Array[Cervo] = []
	for c in m.get_children():
		if c is Cervo:
			cervos.append(c as Cervo)
	var em_agua := 0
	for c in cervos:
		if il.agua(c.global_position.x, c.global_position.z) != -INF:
			em_agua += 1
	var existem := cervos.size() == 3 and cervos.size() == il.cervos_em.size() and em_agua == 0
	if cervos.is_empty():
		_ok(false, "cervos: nenhum cervo encontrado (cervos_em %d)" % il.cervos_em.size())
		_soltar_tudo()
		return
	var c0: Cervo = cervos[0]
	var pc := Vector2(c0.global_position.x, c0.global_position.z)
	var p30 := _ponto_livre(pc, 30.0)
	var p6 := _ponto_livre(pc, 6.0)
	if p30 == Vector2.INF or p6 == Vector2.INF:
		_ok(false, "cervos: chão seco a 30 m e a 6 m do cervo não achado em (%.0f, %.0f)" % [pc.x, pc.y])
		_soltar_tudo()
		return
	a.teleportar(Vector3(p30.x, il.altura(p30.x, p30.y) + 0.3, p30.y), Armadura.Estado.CHAO)
	await _esperar(3.0)
	var est_parado := c0.nome_estado()
	var dist30 := Vector2(a.global_position.x - c0.global_position.x, a.global_position.z - c0.global_position.z).length()
	var pasta := c0.estado == Cervo.Estado.PASTANDO or c0.estado == Cervo.Estado.ANDANDO
	a.teleportar(Vector3(p6.x, il.altura(p6.x, p6.y) + 0.3, p6.y), Armadura.Estado.CHAO)
	var fugiu := false
	for i in 2 * 60:
		await get_tree().physics_frame
		if c0.estado == Cervo.Estado.FUGINDO:
			fugiu = true
			break
	var est_fuga := c0.nome_estado()
	var dist6 := Vector2(a.global_position.x - c0.global_position.x, a.global_position.z - c0.global_position.z).length()
	_ok(existem and pasta and fugiu,
		"%d cervos (cervos_em %d, esperado 3), %d n'água (esperado 0); a %.1f m parado depois de 3 s: %s (esperado pastando ou andando); a %.1f m do robô: %s em até 2 s (esperado fugindo)"
		% [cervos.size(), il.cervos_em.size(), em_agua, dist30, est_parado, dist6, est_fuga])
	_soltar_tudo()


## 10. ciclo do dia: com minutos_por_dia 1,0, 5 s avançam ~2 h; eh_noite às 23 e não às 12.
func _ponto_10() -> void:
	print("ciclo do dia")
	_zerar()
	if ciclo == null:
		_ok(false, "main.ciclo existe")
		return
	ciclo.parado = false
	ciclo.minutos_por_dia = 1.0
	ciclo.hora = 10.0
	await _esperar(5.0)
	var avancou := fposmod(ciclo.hora - 10.0, 24.0)
	ciclo.hora = 23.0
	var noite := ciclo.eh_noite()
	ciclo.hora = 12.0
	var dia := not ciclo.eh_noite()
	ciclo.minutos_por_dia = 60.0
	ciclo.hora = 10.0
	_ok(avancou > 1.5 and avancou < 2.5 and noite and dia,
		"5 s com minutos_por_dia 1,0 avançam %.2f h (esperado entre 1,5 e 2,5); noite às 23 %s, não à noite às 12 %s"
		% [avancou, str(noite), str(not dia)])
	_soltar_tudo()


## Um voo reto de 3 s na altura (pitch 0), com ou sem chuva; devolve quanto o calor subiu.
func _voo_reto(com_chuva: bool) -> float:
	ciclo.chovendo = com_chuva
	ciclo.chuva = 1.0 if com_chuva else 0.0
	cam.pitch = 0.0
	var sx := _spawn_xz()
	a.teleportar(Vector3(sx.x, il.altura(sx.x, sx.y) + 60.0, sx.y), Armadura.Estado.VOO)
	a.calor = 30.0
	a.superaquecido = false
	await _esperar(0.2)
	var c0: float = a.calor
	await _esperar(3.0)
	var delta_calor: float = a.calor - c0
	chovendo_depois = ciclo.chovendo
	return delta_calor


## 11. chuva: Armadura.chuva acompanha ciclo.chuva e, em voo reto por 3 s, o calor sobe menos do que sem chuva.
func _ponto_11() -> void:
	print("chuva")
	_zerar()
	if ciclo == null:
		_ok(false, "main.ciclo existe")
		return
	var seco := await _voo_reto(false)
	var molhado := await _voo_reto(true)
	var acompanha := absf(Armadura.chuva - ciclo.chuva) < 0.01 and Armadura.chuva > 0.5
	var segurou := chovendo_depois
	var chuva_ciclo := ciclo.chuva
	var chuva_arm := Armadura.chuva
	ciclo.chuva = 0.0
	ciclo.chovendo = false
	_ok(acompanha and molhado < seco and segurou,
		"Armadura.chuva %.2f acompanha ciclo.chuva %.2f; chovendo ficou %s depois de 3 s; voo reto de 3 s: calor sobe %.1f com chuva e %.1f sem (esperado com chuva menos)"
		% [chuva_arm, chuva_ciclo, str(segurou), molhado, seco])
	_soltar_tudo()
	a.recomecar()


## Pane: acertos seguidos desligam o robô, o dia avança e ele religa frio no mesmo lugar.
func _ponto_12() -> void:
	_soltar_tudo()
	_zerar()
	var ciclo: CicloDia = m.ciclo
	var xz := _spawn_xz()
	a.teleportar(Vector3(xz.x, m.ilha.altura(xz.x, xz.y) + 0.3, xz.y), Armadura.Estado.CHAO)
	await _esperar(0.5)
	a.avaria = 0
	a.graca_pane = 0.0
	ciclo.parado = true
	ciclo.hora = 10.0
	var panes0: int = a.panes
	for i in Ajustes.PANE_GOLPES - 1:
		a.levar_golpe(Vector3(1, 0, 0), 4.0)
	var antes: bool = a.em_pane
	a.levar_golpe(Vector3(1, 0, 0), 4.0)
	var entrou: bool = a.em_pane
	var onde := a.global_position
	await _esperar(Ajustes.PANE_TEMPO + 1.5)
	var andou := Vector2(a.global_position.x - onde.x, a.global_position.z - onde.z).length()
	var passou := fposmod(ciclo.hora - 10.0, 24.0)
	var g0: int = a.golpes
	a.levar_golpe(Vector3(1, 0, 0), 4.0)  # na graça depois de religar não conta
	_ok(not antes and entrou and not a.em_pane and a.panes == panes0 + 1 and a.calor < 1.0 and a.avaria == 0
			and absf(passou - Ajustes.PANE_HORAS) < 0.2 and andou < 6.0 and a.golpes == g0,
		"pane: %d acertos desligam (antes %s, depois %s), religou com calor %.0f e avaria %d, o dia andou %.1f h (esperado %.1f), ficou a %.1f m, golpe na graça ignorado (%d = %d)"
			% [Ajustes.PANE_GOLPES, antes, entrou, a.calor, a.avaria, passou, Ajustes.PANE_HORAS, andou, a.golpes, g0])
	a.graca_pane = 0.0
	ciclo.hora = 10.0
	ciclo.parado = false
	_zerar()


## Sentinela: existe, patrulha longe do começo, desliga com tiros seguidos e religa quando o tempo salta.
func _ponto_13() -> void:
	var st: Node3D = null
	for n in m.get_children():
		if n is Sentinela:
			st = n
	if st == null:
		_ok(false, "sentinela: não há Sentinela na clareira")
		return
	var longe := Vector2(st.global_position.x, st.global_position.z).distance_to(_spawn_xz())
	var cabeca: Vector3 = st.global_position + Vector3(0, Sentinela.ALTURA_CABECA, 0)
	var no_cabeca := st.find_child("cabeca", true, false) as Node3D
	if no_cabeca:
		cabeca = no_cabeca.global_position
	for i in 8:
		st.call("levar_tiro", cabeca)
	await _esperar(0.3)
	var desligado: bool = st.call("nome_estado") == "desligado"
	st.call("avancar_tempo", Sentinela.TEMPO_DESLIGADO + 1.0)
	await _esperar(2.5)
	var nome: String = st.call("nome_estado")
	_ok(longe > 70.0 and desligado and nome != "desligado" and float(st.get("calor")) < 1.0,
		"sentinela: a %.0f m do começo; tiros seguidos desligam (%s); o salto do tempo religa (estado %s, calor %.0f)"
			% [longe, desligado, nome, float(st.get("calor"))])


## Desligar o voo freia e despenca (robô pesado, não plana) e o tiro sai sem mirar.
func _ponto_14() -> void:
	_soltar_tudo()
	_zerar()
	a.graca_pane = 0.0
	var xz := _spawn_xz()
	var chao: float = m.ilha.altura(xz.x, xz.y)
	cam.yaw = m.ilha.rumo_livre(Vector3(xz.x, chao, xz.y), 60.0)
	cam.pitch = 0.0
	var frente := Vector3(-sin(cam.yaw), 0.0, -cos(cam.yaw))
	a.teleportar(Vector3(xz.x, chao + 60.0, xz.y), Armadura.Estado.VOO, frente * 28.0)
	await _esperar(0.4)
	var v_antes := _hv()
	await _apertar("soltar")
	Input.action_release("soltar")
	await _esperar(1.5)  # meio segundo de freada com os jatos à frente, depois 1 s de queda
	var v_depois := _hv()
	var vy := a.velocity.y
	var est := a.nome_estado()
	await _esperar(3.5)
	var pousou := a.estado == Armadura.Estado.CHAO or a.estado == Armadura.Estado.POUSO
	_ok(v_antes > 20.0 and v_depois < v_antes * 0.45 and vy < -18.0 and pousou,
		"soltar o voo: de %.0f m/s de lado para %.0f em 1,5 s, caindo a %.0f m/s (%s); pousou: %s" % [v_antes, v_depois, vy, est, pousou])
	await _esperar(1.5)
	_zerar()
	var t: Node = m.get("tiro")
	var n0: int = t.get("disparos")
	Input.action_press("atirar")
	await _esperar(0.7)
	Input.action_release("atirar")
	var n1: int = t.get("disparos")
	_ok(n1 - n0 >= 2 and not a.mirando, "atira sem mirar: %d disparos em 0,7 s no chão" % (n1 - n0))
	# voando não atira; no voo parado atira
	var xz2 := _spawn_xz()
	var ch2: float = m.ilha.altura(xz2.x, xz2.y)
	var fr := Vector3(-sin(cam.yaw), 0.0, -cos(cam.yaw))
	a.teleportar(Vector3(xz2.x, ch2 + 40.0, xz2.y), Armadura.Estado.VOO, fr * 22.0)
	await _esperar(0.3)
	var v0: int = t.get("disparos")
	Input.action_press("atirar")
	await _esperar(0.7)
	var v1: int = t.get("disparos")
	Input.action_press("mirar")
	await _esperar(1.0)
	var v2: int = t.get("disparos")
	var est2 := a.nome_estado()
	Input.action_release("atirar")
	Input.action_release("mirar")
	_ok(v1 == v0 and v2 - v1 >= 2 and a.estado == Armadura.Estado.PAIRAR,
		"no ar só atira no voo parado: voando %d disparos, parado %d (%s)" % [v1 - v0, v2 - v1, est2])
	await _apertar("soltar")
	Input.action_release("soltar")
	await _esperar(3.5)
	_soltar_tudo()
	_zerar()


## O vale maior: a clareira emenda no terreno de fora sem degrau, dá para pisar fora dela e o mar existe.
func _ponto_15() -> void:
	if not (m.ilha is Vale):
		return
	var v: Vale = m.ilha
	_soltar_tudo()
	_zerar()
	# degrau na linha dos 160 m: compara 5 cm para dentro e 5 cm para fora, em volta toda
	var pior := 0.0
	for k in range(-158, 159, 4):
		for lado: Array in [[160.0, float(k)], [-160.0, float(k)], [float(k), 160.0], [float(k), -160.0]]:
			var x: float = lado[0]
			var z: float = lado[1]
			var dentro := v.altura(x * 0.9997, z * 0.9997)
			var fora := v.altura(x * 1.0003, z * 1.0003)
			pior = maxf(pior, absf(dentro - fora))
	# pisar fora da clareira: campo ao sul
	var p := Vector3(-100.0, 0.0, 500.0)
	p.y = v.altura(p.x, p.z)
	a.teleportar(p + Vector3(0, 3.0, 0), Armadura.Estado.AR)
	await _esperar(1.5)
	var no_chao := a.is_on_floor() and absf(a.global_position.y - v.altura(a.global_position.x, a.global_position.z)) < 0.6
	# mar: bem ao sul há água no nível zero, e na terra não
	var mar := v.agua(0.0, 980.0)
	var seco := v.agua(p.x, p.z)
	_ok(pior < 0.12 and no_chao and is_equal_approx(mar, Vale.MAR) and seco == -INF and v.arvores_fora > 5000,
		"vale: maior degrau na borda da clareira %.3f m; pisa no campo do sul (%s, a %.2f m do chão); mar em z=980: %.1f; %d árvores fora"
			% [pior, no_chao, a.global_position.y - v.altura(a.global_position.x, a.global_position.z), mar, v.arvores_fora])
	a.recomecar()
	await _esperar(0.5)


## Rio e mar: o rio sai da lagoa e chega ao mar descendo; longe da costa o robô entra em pane e volta à praia.
func _ponto_16() -> void:
	if not (m.ilha is Vale):
		return
	var v: Vale = m.ilha
	_soltar_tudo()
	_zerar()
	# o rio: água ao longo do trajeto, nível que só desce, e termina no mar
	var niveis: Array[float] = []
	var com_agua := 0
	var total := 0
	var s := v._rio_s_borda + 10.0
	while s < v._rio_s_foz - 10.0:
		var p := v._rio_ponto(s)
		var n := v.agua(p.x, p.y)
		total += 1
		if n > -INF:
			com_agua += 1
			niveis.append(n)
		s += 20.0
	var desce := true
	for i in range(1, niveis.size()):
		if niveis[i] > niveis[i - 1] + 0.01:
			desce = false
	var foz := v._rio_ponto(v._rio_s_foz + 15.0)
	# o mar: de pé na praia não há pane; a 300 m da costa há, e o robô volta para terra firme
	var lim: LimiteMar = null
	for n2 in m.get_children():
		if n2 is LimiteMar:
			lim = n2
	var ciclo: CicloDia = m.ciclo
	ciclo.parado = true
	var panes0: int = a.panes
	var longe := Vector3(0.0, 40.0, 1000.0)
	var dist_longe := v.distancia_da_costa(longe.x, longe.z)
	while dist_longe < LimiteMar.PANE + 30.0:
		longe.z += 40.0
		dist_longe = v.distancia_da_costa(longe.x, longe.z)
	a.teleportar(longe, Armadura.Estado.VOO, Vector3(0, 0, 5))
	await _esperar(0.6)
	var entrou: bool = a.em_pane
	await _esperar(Ajustes.PANE_TEMPO + 3.0)
	var em_terra := v.altura(a.global_position.x, a.global_position.z) > 1.0 and v.distancia_da_costa(a.global_position.x, a.global_position.z) < 1.0
	em_terra = em_terra and Vector2(a.global_position.x - v.spawn.x, a.global_position.z - v.spawn.z).length() < 4.0  # reaparece na base
	_ok(com_agua >= total - 1 and desce and v.agua(foz.x, foz.y) == Vale.MAR and lim != null and entrou and not a.em_pane and em_terra and a.panes == panes0 + 1,
		"rio e mar: água em %d de %d pontos do rio, nível só desce (%s), foz no mar (%.1f); a %.0f m da costa entra em pane (%s) e reaparece na base (%s, altura %.1f m)"
			% [com_agua, total, desce, v.agua(foz.x, foz.y), dist_longe, entrou, em_terra, v.altura(a.global_position.x, a.global_position.z)])
	a.graca_pane = 0.0
	ciclo.hora = 10.0
	ciclo.parado = false
	a.recomecar()
	await _esperar(0.5)


## Rio com curvas, paredões e ruínas: o rio serpenteia, as rochas e as três ruínas existem com colisão,
## e dá para pousar em cima do aqueduto.
func _ponto_17() -> void:
	if not (m.ilha is Vale):
		return
	var v: Vale = m.ilha
	_soltar_tudo()
	_zerar()
	# o rio do sul anda bem mais do que a linha reta entre a borda da clareira e a foz
	var de := v._rio_ponto(v._rio_s_borda)
	var ate := v._rio_ponto(v._rio_s_foz)
	var sinuoso := (v._rio_s_foz - v._rio_s_borda) / de.distance_to(ate)
	var rochas := 0
	var pedras := 0
	var obras := 0
	for n in v.get_children():
		if n.name == "Paredoes":
			rochas = n.get_child_count()
		elif String(n.name).begins_with("Ruina"):
			obras += 1
			pedras += n.get_child_count()
	# em cima do leito do aqueduto, sobre o segundo arco
	var lugar := Ruinas.ARCOS
	var chao := v.altura(lugar.x, lugar.y)
	var em_cima := Transform3D(Basis(Vector3.UP, lugar.z), Vector3(lugar.x, chao, lugar.y)) * Vector3(-11.0, Ruinas.NASCENCA + 8.2, 0.0)
	a.teleportar(em_cima, Armadura.Estado.AR)
	await _esperar(1.6)
	var sobre: float = a.global_position.y - chao
	_ok(sinuoso > 1.05 and rochas > 50 and obras == 4 and pedras > 300 and sobre > 13.0 and a.estado == Armadura.Estado.CHAO,
		"rio, paredões e ruínas: o rio anda %.2f vezes a reta; %d rochas com colisão nos paredões; %d ruínas com %d pedras; o robô pousa no aqueduto a %.1f m do chão"
			% [sinuoso, rochas, obras, pedras, sobre])


## 18. Vida fora da clareira: os lugares são sorteados em chão bom, espalhados pelo vale; os bichos nascem
## quando o robô chega perto e somem quando ele se afasta.
func _ponto_18() -> void:
	print("vida espalhada pelo vale")
	_soltar_tudo()
	_zerar()
	var vida: VidaVale = m.vida
	var v: Vale = m.ilha
	var ruins := 0
	var quadrantes := {}
	for l: Dictionary in vida.lugares:
		var p: Vector3 = l["pos"]
		if l["tipo"] != "peixe" and (v.agua(p.x, p.z) > -INF or v.normal_em(p.x, p.z).y < 0.85 or p.y < Vale.MAR + 2.0 or Vector2(p.x, p.z).length() < VidaVale.CLAREIRA_FORA):
			ruins += 1
		quadrantes[Vector2i(int(signf(p.x)), int(signf(p.z)))] = true
	var manada: Dictionary = {}
	for l: Dictionary in vida.lugares:
		if l["tipo"] == "cervo":
			manada = l
			break
	var mp: Vector3 = manada["pos"]
	var antes: int = (manada["nos"] as Array).size()
	a.teleportar(Vector3(mp.x + 70.0, v.altura(mp.x + 70.0, mp.z) + 50.0, mp.z), Armadura.Estado.PAIRAR)
	Input.action_press("mirar")
	await _esperar(4.0)
	var perto: int = (manada["nos"] as Array).size()
	var no_chao := true
	for n: Node3D in manada["nos"]:
		if absf(n.global_position.y - v.altura(n.global_position.x, n.global_position.z)) > 0.6:
			no_chao = false
	a.teleportar(Vector3(mp.x + 500.0 * (-1.0 if mp.x > 0.0 else 1.0), 300.0, mp.z), Armadura.Estado.PAIRAR)
	await _esperar(4.0)
	var longe: int = (manada["nos"] as Array).size()
	Input.action_release("mirar")
	_ok(vida.lugares.size() >= 60 and ruins == 0 and quadrantes.size() == 4 and antes == 0 and perto >= 2 and no_chao and longe == 0,
		"vida do vale: %d lugares, %d em chão ruim, %d quadrantes; manada com %d cervos longe, %d ao chegar (no chão: %s), %d ao sair"
		% [vida.lugares.size(), ruins, quadrantes.size(), antes, perto, no_chao, longe])


## 19. Zangão e Carrapato: enxergam o robô, atacam, desligam com tiros ou com o mergulho e religam com o tempo.
func _ponto_19() -> void:
	print("zangão e carrapato")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	var z: Zangao = null
	var cr: Carrapato = null
	for n: Node3D in m.inimigos.todas:
		if n is Zangao and z == null:
			z = n
		if n is Carrapato and cr == null:
			cr = n
	# carrapato: o robô parado a 14 m leva a investida
	var p := cr.casa + Vector3(14, 0, 0)
	a.teleportar(Vector3(p.x, v.altura(p.x, p.z) + 0.3, p.z), Armadura.Estado.CHAO)
	a.graca_pane = 0.0
	a.avaria = 0
	var g0: int = a.golpes
	var investiu := false
	for i in 8 * 60:
		await get_tree().physics_frame
		a.avaria = 0
		if cr.investidas > 0:
			investiu = true
		if a.golpes > g0:
			break
	var acertou: bool = a.golpes > g0
	# o mergulho com impacto perto desliga; o tempo religa
	a.golpe_chao.emit(cr.global_position + Vector3(2, 0, 0))
	await _esperar(0.2)
	var caiu: bool = cr.desligada
	cr.avancar_tempo(MaquinaPequena.TEMPO_DESLIGADA + 1.0)
	var voltou: bool = not cr.desligada and cr.religamentos == 1
	# zangão: vê o robô, caça e atira; dois tiros desligam
	p = z.casa + Vector3(0, 0, 22)
	a.teleportar(Vector3(p.x, v.altura(p.x, p.z) + 0.3, p.z), Armadura.Estado.CHAO)
	a.graca_pane = 0.0
	var cacou := false
	for i in 12 * 60:
		await get_tree().physics_frame
		a.avaria = 0
		if z.estado == Zangao.Estado.CACA:
			cacou = true
		if z.disparos > 0:
			break
	var atirou: bool = z.disparos > 0
	var alto: bool = z.global_position.y - v.altura(z.global_position.x, z.global_position.z) > 1.4
	z.levar_tiro(z.centro())
	var um: bool = not z.desligada
	z.levar_tiro(z.centro())
	var dois: bool = z.desligada
	await _esperar(2.5)
	var no_chao: bool = z.global_position.y - v.altura(z.global_position.x, z.global_position.z) < 0.6
	a.avaria = 0
	a.graca_pane = 0.0
	_ok(m.inimigos.todas.size() == 33 and investiu and acertou and caiu and voltou and cacou and atirou and alto and um and dois and no_chao,
		"inimigos: %d máquinas; carrapato investe (%s) e acerta o robô parado (%s), o mergulho desliga (%s), o tempo religa (%s); zangão caça (%s), atira (%s), voa (%s), um tiro não desliga (%s), dois desligam (%s) e ele cai no chão (%s)"
		% [m.inimigos.todas.size(), investiu, acertou, caiu, voltou, cacou, atirou, alto, um, dois, no_chao])


## 20. Cavernas: há túnel e grutas, o chão foi cavado, o teto existe e segura, e dá para atravessar o túnel voando.
func _ponto_20() -> void:
	print("cavernas")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	var com_teto := 0
	var tunel: Dictionary = {}
	for cav: Dictionary in Cavernas.lista:
		if float(cav["ate"]) - float(cav["de"]) > 12.0:
			com_teto += 1
		if not cav["gruta"] and tunel.is_empty():
			tunel = cav
	var pa: Vector2 = tunel["a"]
	var pb: Vector2 = tunel["b"]
	var d2 := (pb - pa).normalized()
	var comp: float = tunel["comp"]
	var meio := pa + d2 * comp * 0.5
	var chao_meio := v.altura(meio.x, meio.y)
	var esperado := lerpf(tunel["ha"], tunel["hb"], 0.5)
	var morro := Cavernas.chao_antes(meio.x, meio.y) - chao_meio
	var espaco := a.get_world_3d().direct_space_state
	var de := Vector3(meio.x, chao_meio + 1.0, meio.y)
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3(0, 30, 0), 1)
	var hit := espaco.intersect_ray(q)
	var teto := (hit["position"] as Vector3).y - chao_meio if not hit.is_empty() else -1.0
	# voando de uma boca à outra
	var ini := pa + d2 * 6.0
	cam.yaw = atan2(-d2.x, -d2.y)
	var sobe := atan2(float(tunel["hb"]) - float(tunel["ha"]), comp)
	cam.pitch = sobe + 0.22  # no cruzeiro o voo só fica nivelado com o nariz uns 12° acima do horizonte
	a.calor = 0.0
	a.teleportar(Vector3(ini.x, v.altura(ini.x, ini.y) + 4.0, ini.y), Armadura.Estado.VOO, Vector3(d2.x, tan(sobe), d2.y) * 18.0)
	var andou := 0.0
	var caiu := false
	for i in 12 * 60:
		await get_tree().physics_frame
		andou = (Vector2(a.global_position.x, a.global_position.z) - ini).dot(d2)
		if a.estado != Armadura.Estado.VOO:
			caiu = true
			break
		if andou > comp - 12.0:
			break
	if caiu:
		print("    caiu em ", a.global_position, " estado ", a.nome_estado(), " chão ", v.altura(a.global_position.x, a.global_position.z))
	cam.pitch = -0.12
	_ok(Cavernas.lista.size() >= 4 and com_teto >= 4 and not tunel.is_empty() and absf(chao_meio - esperado) < 1.5 and morro > 10.0 and teto > 4.0 and teto < 12.0 and not caiu and andou > comp - 12.0,
		"cavernas: %d (%d com teto); no meio do túnel o chão desceu %.1f m e o teto fica a %.1f m; voando de uma boca à outra andou %.0f de %.0f m (caiu: %s)"
		% [Cavernas.lista.size(), com_teto, morro, teto, andou, comp, caiu])



## 21. Sons: os arquivos montados existem, andar faz pisadas, atirar faz o tiro, e dentro do túnel o eco
## da caverna entra e a mata se cala.
func _ponto_21() -> void:
	print("sons")
	_soltar_tudo()
	_zerar()
	var faltam: Array[String] = []
	for nome: String in ["mata_dia_loop", "mata_fundo_loop", "mata_noite_loop", "chuva_loop", "trovao", "trovao_2",
			"riacho_loop", "rio_loop", "cachoeira_loop", "vento_loop", "caverna_loop", "folhagem_1", "folhagem_4",
			"motor_loop", "arrancada_loop", "decolagem", "pulo_duplo", "esquiva", "pouso_leve", "pouso_pesado",
			"golpe_chao", "motor_apaga", "passo_1", "passo_6", "tiro_1", "tiro_3", "impacto_1", "impacto_3",
			"maquina_desliga", "sentinela_desliga", "zangao_loop", "tiro_zangao_1", "tiro_zangao_2", "carrapato_loop",
			"sentinela_loop", "sentinela_passo", "tiro_sentinela", "alarme_calor", "marcar", "religar"]:
		if not ResourceLoader.exists(Som.PASTA % nome):
			faltam.append(nome)
	# pisadas e tiro, na clareira
	a.teleportar(il.spawn + Vector3(0, 0.3, 14.0), Armadura.Estado.CHAO, Vector3.ZERO)
	await _esperar(0.5)
	Sons.registro.clear()
	Sons.registrar = true
	Input.action_press("frente")
	await _esperar(2.0)
	Input.action_release("frente")
	var passos := 0
	for nome in Sons.registro:
		if nome.begins_with("passo_"):
			passos += 1
	await _esperar(0.4)
	Sons.registro.clear()
	Input.action_press("atirar")
	await _esperar(0.5)
	Input.action_release("atirar")
	var tiros := 0
	for nome in Sons.registro:
		if nome.begins_with("tiro_"):
			tiros += 1
	Sons.registrar = false
	# fora e dentro do túnel
	var fora: float = m.som_lugar.debug.get("na_caverna", -1.0)
	var tunel: Dictionary = {}
	for cav: Dictionary in Cavernas.lista:
		if not cav["gruta"] and tunel.is_empty():
			tunel = cav
	var meio: Vector2 = ((tunel["a"] as Vector2) + (tunel["b"] as Vector2)) * 0.5
	var v: Vale = m.ilha
	a.teleportar(Vector3(meio.x, v.altura(meio.x, meio.y) + 0.3, meio.y), Armadura.Estado.CHAO, Vector3.ZERO)
	await _esperar(3.0)
	var dentro: float = m.som_lugar.debug.get("na_caverna", -1.0)
	var eco: float = m.som_lugar.debug.get("caverna_db", -99.0)
	a.teleportar(il.spawn + Vector3(0, 0.3, 0), Armadura.Estado.CHAO, Vector3.ZERO)
	await _esperar(0.2)
	_ok(faltam.is_empty() and passos >= 3 and passos <= 9 and tiros >= 1 and fora < 0.05 and dentro > 0.95 and eco > -20.0,
		"sons: faltam %d arquivos %s; andando 2 s deu %d pisadas; atirando 0,5 s deu %d tiros; caverna fora %.2f, dentro do túnel %.2f (eco a %.0f dB)"
		% [faltam.size(), str(faltam) if not faltam.is_empty() else "", passos, tiros, fora, dentro, eco])
