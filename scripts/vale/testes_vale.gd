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
	await _ponto_22()
	await _ponto_23()
	await _ponto_24()
	await _ponto_25()
	await _ponto_26()
	await _ponto_27()
	await _ponto_28()
	await _ponto_29()
	await _ponto_30()
	await _ponto_31()
	await _ponto_32()
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
	for acao in ["frente", "tras", "esquerda", "direita", "pular", "correr", "soltar", "correr_alternar", "sentar", "espada", "voar", "pairar", "golpe", "mirar", "marcar", "atirar", "agir", "scanner", "luz", "roda", "granada"]:
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
	cam.yaw = il.spawn_yaw  # a frente da base dá para o campo (atrás fica a parede do hangar)
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


## Mecha da clareira: existe, fica longe do começo, desliga com tiros seguidos e religa quando o tempo salta.
func _ponto_13() -> void:
	var st: Mecha = null
	for n in m.get_children():
		if n is Mecha:
			st = n
	if st == null:
		_ok(false, "mecha: não há mecha na clareira")
		return
	var longe := Vector2(st.global_position.x, st.global_position.z).distance_to(_spawn_xz())
	var tiros := 0
	while not st.desligada and tiros < 12:
		st.levar_tiro(st.centro())
		tiros += 1
	await _esperar(0.3)
	var desligado: bool = st.desligada
	st.avancar_tempo(MaquinaPequena.TEMPO_DESLIGADA + 1.0)
	await _esperar(0.5)
	_ok(longe > 70.0 and desligado and tiros >= 3 and tiros <= 5 and not st.desligada and st.calor < 1.0,
		"mecha da clareira: a %.0f m do começo; %d tiros seguidos desligam (%s); o salto do tempo religa (%s, calor %.0f); ficha %s"
			% [longe, tiros, desligado, not st.desligada, st.calor, str(st.ficha)])


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
	for k in 3:
		await _apertar("atirar")
		await _esperar(0.25)
	var n1: int = t.get("disparos")
	_ok(n1 - n0 >= 2 and not a.mirando, "atira sem mirar: %d disparos em três apertos no chão" % (n1 - n0))
	# voando não atira; no voo parado atira
	var xz2 := _spawn_xz()
	var ch2: float = m.ilha.altura(xz2.x, xz2.y)
	var fr := Vector3(-sin(cam.yaw), 0.0, -cos(cam.yaw))
	a.teleportar(Vector3(xz2.x, ch2 + 40.0, xz2.y), Armadura.Estado.VOO, fr * 22.0)
	await _esperar(0.3)
	var v0: int = t.get("disparos")
	for k in 2:
		await _apertar("atirar")
		await _esperar(0.3)
	var v1: int = t.get("disparos")
	Input.action_press("mirar")
	await _esperar(0.5)
	for k in 3:
		await _apertar("atirar")
		await _esperar(0.25)
	var v2: int = t.get("disparos")
	var est2 := a.nome_estado()
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
	# o drone colega vem buscar: chega por cima do robô antes de a tela escurecer, e depois volta ao posto
	var dr: DroneColega = m.drone
	var res0 := dr.resgates if dr else -1
	await _esperar(Ajustes.PANE_ESCURECE)
	var chegou := dr != null and dr.resgates == res0 + 1 and dr.chegou_a < 0.6
	await _esperar(Ajustes.PANE_TEMPO - Ajustes.PANE_ESCURECE + 3.0)
	await _esperar(2.5)
	var no_posto := dr != null and dr.modo == DroneColega.Modo.POSTO and dr.global_position.distance_to(dr.posto) < 3.2  # com o robô ali ele chega um pouco para o lado dele
	var em_terra := v.altura(a.global_position.x, a.global_position.z) > 1.0 and v.distancia_da_costa(a.global_position.x, a.global_position.z) < 1.0
	em_terra = em_terra and Vector2(a.global_position.x - v.spawn.x, a.global_position.z - v.spawn.z).length() < 4.0  # reaparece na base
	_ok(com_agua >= total - 1 and desce and v.agua(foz.x, foz.y) == Vale.MAR and lim != null and entrou and not a.em_pane and em_terra and a.panes == panes0 + 1 and chegou and no_posto
			and BaseVale.pecas_kit > 30 and m.find_child("FaiscaCaido", true, false) != null and m.find_child("CilindroDeMelhorias", true, false) != null,
		"rio e mar: água em %d de %d pontos do rio, nível só desce (%s), foz no mar (%.1f); a %.0f m da costa entra em pane (%s) e reaparece na base (%s, altura %.1f m); o drone chegou sobre o robô (%s) e voltou ao posto (%s); base com %d peças dos kits"
			% [com_agua, total, desce, v.agua(foz.x, foz.y), dist_longe, entrou, em_terra, v.altura(a.global_position.x, a.global_position.z), chegou, no_posto, BaseVale.pecas_kit])
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
	_ok(sinuoso > 1.05 and rochas > 50 and obras == 5 and pedras > 300 and sobre > 13.0 and a.estado == Armadura.Estado.CHAO,
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


## 19. Mechas: são sorteados (cada um com a ficha dele), enxergam o robô e atacam conforme a arma (o de espada
## ou martelo bate, o de tiro atira), desligam com os tiros certos ou com o mergulho, e religam com o tempo.
func _ponto_19() -> void:
	print("mechas")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	var fichas_ok := true
	var grandes := 0
	var de_corpo: Mecha = null
	var de_tiro: Mecha = null
	var armas := {}
	for n: Node3D in m.inimigos.todas:
		var mc := n as Mecha
		if mc == null or mc.mech == null or not (String(mc.ficha.get("arma", "")) in ["tiro", "corpo", "costas"]):
			fichas_ok = false
			continue
		armas[mc.ficha["arma"]] = true
		if mc.chefe:
			grandes += 1
		elif mc.corpo_a_corpo and de_corpo == null:
			de_corpo = mc
		elif not mc.corpo_a_corpo and de_tiro == null:
			de_tiro = mc
	# o de espada ou martelo: o robô parado a 6 m leva o golpe
	var bateu := false
	var p := Vector3.ZERO
	if de_corpo:
		p = de_corpo.global_position + Vector3(6, 0, 0)
		a.teleportar(Vector3(p.x, v.altura(p.x, p.z) + 0.3, p.z), Armadura.Estado.CHAO)
		a.graca_pane = 0.0
		var g0: int = a.golpes
		for i in 14 * 60:
			await get_tree().physics_frame
			a.avaria = 0
			a.global_position = Vector3(p.x, a.global_position.y, p.z)
			if a.golpes > g0:
				bateu = true
				break
		# o mergulho com impacto perto desliga; o tempo religa
		a.golpe_chao.emit(de_corpo.global_position + Vector3(2, 0, 0))
		await _esperar(0.2)
	var caiu: bool = de_corpo != null and de_corpo.desligada
	if de_corpo:
		de_corpo.avancar_tempo(MaquinaPequena.TEMPO_DESLIGADA + 1.0)
	var voltou: bool = de_corpo != null and not de_corpo.desligada and de_corpo.religamentos == 1
	# o de tiro: vê o robô, caça e atira; os tiros certos desligam
	var cacou := false
	var atirou := false
	var antes_nao := false
	var depois_sim := false
	var deitou := false
	if de_tiro:
		p = de_tiro.global_position + Vector3(0, 0, 20)
		a.teleportar(Vector3(p.x, v.altura(p.x, p.z) + 0.3, p.z), Armadura.Estado.CHAO)
		a.graca_pane = 0.0
		for i in 14 * 60:
			await get_tree().physics_frame
			a.avaria = 0
			if de_tiro.estado == Vigia.Estado.CACA:
				cacou = true
			if de_tiro.disparos > 0:
				break
		atirou = de_tiro.disparos > 0
		var precisa := ceili(100.0 / de_tiro.calor_tiro)
		for i in precisa - 1:
			de_tiro.levar_tiro(de_tiro.centro())
		antes_nao = not de_tiro.desligada
		de_tiro.levar_tiro(de_tiro.centro())
		depois_sim = de_tiro.desligada
		await _esperar(1.0)
		deitou = de_tiro.mech.atual == "Death"
	# projéteis: a bala chega depressa no robô parado, o míssil vira e estoura nele, e três balas valem um acerto
	var tipos := {}
	for n: Node3D in m.inimigos.todas:
		if not (n as Mecha).corpo_a_corpo:
			tipos[(n as Mecha).tipo_tiro] = true
	var bala_ok := false
	var missil_ok := false
	var tempo_bala := 9.0
	var tempo_missil := 9.0
	var avaria_3_balas := -1
	if de_tiro:
		de_tiro.religar()
		# ninguém luta sozinho nesta parte (um vizinho atirando estragava a medida): os tiros do teste saem à mão
		m.inimigos.process_mode = Node.PROCESS_MODE_DISABLED  # o gerente parado: senão ele reacorda os mechas
		v._corpo_arvores.collision_layer = 0  # sem árvores no caminho: aqui se mede o projétil (o ponto 29 mede o obstáculo)
		p = de_tiro.global_position + Vector3(0, 0, 40)
		a.teleportar(Vector3(p.x, v.altura(p.x, p.z) + 0.3, p.z), Armadura.Estado.CHAO)
		a.graca_pane = 0.0
		a.avaria = 0
		a._dano_frac = 0.0
		await _esperar(0.2)
		var g2: int = a.golpes
		var boca := de_tiro.centro() + Vector3(0, 1.0, 0)
		de_tiro.atirar_em(boca, de_tiro.centro_alvo(), "bala", 0.0)
		for i in 120:
			await get_tree().physics_frame
			de_tiro.atualizar_tiros(1.0 / 60.0)
			if a.golpes > g2:
				bala_ok = true
				tempo_bala = i / 60.0
				break
		for k in 2:
			de_tiro.atirar_em(boca, de_tiro.centro_alvo(), "bala", 0.0)
			for i in 60:
				await get_tree().physics_frame
				de_tiro.atualizar_tiros(1.0 / 60.0)
		avaria_3_balas = a.avaria
		a.avaria = 0
		a.velocity = Vector3.ZERO
		a.teleportar(Vector3(p.x, v.altura(p.x, p.z) + 0.3, p.z), Armadura.Estado.CHAO)
		await _esperar(0.2)
		g2 = a.golpes
		de_tiro.atirar_em(boca, de_tiro.centro_alvo(), "missil", 0.0)
		for i in 300:
			await get_tree().physics_frame
			de_tiro.atualizar_tiros(1.0 / 60.0)
			if a.golpes > g2:
				missil_ok = true
				tempo_missil = i / 60.0
				break
		m.inimigos.process_mode = Node.PROCESS_MODE_INHERIT
		v._corpo_arvores.collision_layer = 2
		de_tiro.desligar()
	a.avaria = 0
	a.graca_pane = 0.0
	_ok(tipos.size() >= 2 and bala_ok and tempo_bala < 0.55 and avaria_3_balas == 1 and missil_ok and tempo_missil > 0.6,
		"projéteis: %d tipos entre os mechas; a bala cruza 40 m em %.2f s e acerta (%s); três balas somam %d acerto; o míssil vira e estoura no robô parado (%s) em %.1f s"
		% [tipos.size(), tempo_bala, bala_ok, avaria_3_balas, missil_ok, tempo_missil])
	_ok(m.inimigos.todas.size() == 12 and grandes == 2 and fichas_ok and armas.size() >= 2 and bateu and caiu and voltou and cacou and atirou and antes_nao and depois_sim and deitou,
		"mechas: %d no vale (%d grandes), fichas certas (%s), %d jeitos de lutar; o de espada ou martelo acerta o robô parado (%s), o mergulho desliga (%s), o tempo religa (%s); o de tiro caça (%s), atira (%s), aguenta até o penúltimo tiro (%s), desliga no último (%s) e cai (%s)"
		% [m.inimigos.todas.size(), grandes, fichas_ok, armas.size(), bateu, caiu, voltou, cacou, atirou, antes_nao, depois_sim, deitou])


## 20. Sem grutas pequenas: só o Sumidouro cava o chão. Fora dele a grade é a original (nada rebaixado, nenhum
## retângulo de chão refeito), inclusive onde ficava a gruta do Platô das Flores, e não há peça de gruta.
func _ponto_20() -> void:
	print("sem grutas pequenas")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	var cavados := 0
	var x := -Vale.F_META + 8.0
	while x < Vale.F_META - 8.0:
		var z := -Vale.F_META + 8.0
		while z < Vale.F_META - 8.0:
			if v._fora(x, z) < Cavernas.chao_antes(x, z) - 0.3 and Vector2(x, z).distance_to(Sumidouro.centro) > 120.0 \
					and Vector2(x, z).distance_to(Fundicao.CENTRO) > Fundicao.RAIO + 34.0:
				cavados += 1
			z += 8.0
		x += 8.0
	var pecas := m.find_children("Gruta*", "", true, false).size()
	var plato := absf(v.altura(815.0, -100.0) - Cavernas.chao_antes(815.0, -100.0))
	_ok(cavados == 0 and pecas == 0 and plato < 0.05 and Sumidouro.existe,
		"sem grutas: %d pontos cavados fora do Sumidouro, %d peças de gruta, o platô difere %.2f m do chão original; Sumidouro existe: %s"
		% [cavados, pecas, plato, Sumidouro.existe])



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
	# fora e dentro do Sumidouro
	var fora: float = m.som_lugar.debug.get("na_caverna", -1.0)
	a.teleportar(Vector3(Sumidouro.centro.x, Sumidouro.piso + 3.0, Sumidouro.centro.y), Armadura.Estado.PAIRAR, Vector3.ZERO)
	await _esperar(3.0)
	var dentro: float = m.som_lugar.debug.get("na_caverna", -1.0)
	var eco: float = m.som_lugar.debug.get("caverna_db", -99.0)
	a.teleportar(il.spawn + Vector3(0, 0.3, 0), Armadura.Estado.CHAO, Vector3.ZERO)
	await _esperar(0.2)
	# nenhum tocador 3D em posição inválida (um só no infinito deixava o jogo inteiro mudo)
	var invalidos := 0
	for n in m.find_children("*", "AudioStreamPlayer3D", true, false):
		if not (n as AudioStreamPlayer3D).global_position.is_finite():
			invalidos += 1
	_ok(invalidos == 0 and faltam.is_empty() and passos >= 3 and passos <= 9 and tiros >= 1 and fora < 0.05 and dentro > 0.95 and eco > -20.0,
		"sons: %d tocadores em posição inválida; faltam %d arquivos %s; andando 2 s deu %d pisadas; atirando 0,5 s deu %d tiros; caverna fora %.2f, dentro do Sumidouro %.2f (eco a %.0f dB)"
		% [invalidos, faltam.size(), str(faltam) if not faltam.is_empty() else "", passos, tiros, fora, dentro, eco])


## 22. Decolagem segurando o pulo (o do chão e o duplo): sobe reto uns 10 m e sai voando; um toque curto não
## decola. Levantar de sentado leva um instante e só depois ele anda. Nenhuma peça de rocha tem furo por cima.
func _ponto_22() -> void:
	print("decolagem segurando o pulo, levantar e furos")
	_soltar_tudo()
	_zerar()
	a.recomecar()
	await _esperar(0.6)
	cam.pitch = 0.0
	var p0 := a.global_position
	var topo := 0.0
	var desvio := 0.0
	var decolou := false
	Input.action_press("pular")
	for i in 120:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.DECOLAGEM:
			decolou = true
			topo = maxf(topo, a.global_position.y - p0.y)
			desvio = maxf(desvio, Vector2(a.global_position.x - p0.x, a.global_position.z - p0.z).length())
	Input.action_release("pular")
	var voo_1 := a.estado == Armadura.Estado.VOO
	# no pulo duplo
	_zerar()
	a.recomecar()
	await _esperar(0.6)
	await _apertar("pular")
	await _esperar(0.3)
	var decolou_2 := false
	Input.action_press("pular")
	for i in 110:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.DECOLAGEM:
			decolou_2 = true
	Input.action_release("pular")
	var voo_2 := a.estado == Armadura.Estado.VOO and a._duplo_usado == false
	# toques curtos: pulo e pulo duplo sem decolar
	_zerar()
	a.recomecar()
	await _esperar(0.6)
	await _apertar("pular")
	await _esperar(0.3)
	await _apertar("pular")
	await _esperar(0.5)
	var so_pulo := a.estado == Armadura.Estado.AR
	# levantar de sentado
	a.recomecar()
	await _esperar(0.6)
	a.postura = 2
	await _esperar(0.3)
	var q0 := a.global_position
	Input.action_press("frente")
	await _esperar(0.1)
	var levantando := a.erguendo > 0.0 and a.postura == 0
	await _esperar(Ajustes.ERGUER_TEMPO * 0.6)
	var parado := Vector2(a.global_position.x - q0.x, a.global_position.z - q0.z).length()
	await _esperar(1.2)
	Input.action_release("frente")
	var andou := Vector2(a.global_position.x - q0.x, a.global_position.z - q0.z).length()
	# furos por cima das peças de rocha
	var furos := RochaMalha.furos(Sumidouro._mn, Sumidouro._mx, Sumidouro.vazio, Sumidouro.extra, 2.0).size()
	_ok(decolou and topo > 8.5 and desvio < 2.5 and voo_1 and decolou_2 and voo_2 and so_pulo and levantando and parado < 0.3 and andou > 0.8 and furos == 0,
		"segurar o pulo no chão decola (%s), sobe %.1f m com %.1f m de desvio e sai voando (%s); no pulo duplo também (%s, %s); toques curtos só pulam (%s); levantando de sentado (%s) andou %.2f m no começo e %.1f m depois; %d furos sobre as rochas"
		% [decolou, topo, desvio, voo_1, decolou_2, voo_2, so_pulo, levantando, parado, andou, furos])
	_soltar_tudo()
	a.recomecar()
	await _esperar(0.3)


## 23. O Sumidouro: o poço está aberto do alto do morro até o piso, a ponte cruza o poço, o túnel sai livre
## para a encosta, e o robô que cai pelo poço pousa no salão (com o eco de caverna).
func _ponto_23() -> void:
	print("sumidouro")
	_soltar_tudo()
	_zerar()
	var S := Sumidouro
	var eixo := Vector3(S.centro.x, S.piso, S.centro.y)
	var d := Vector3(S.dir.x, 0, S.dir.y)
	var espaco := a.get_world_3d().direct_space_state
	var raio := func(de: Vector3, ate: Vector3) -> Vector3:
		var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de, ate, 1))
		return (hit["position"] as Vector3) if not hit.is_empty() else Vector3.INF
	# do alto do morro para baixo, ao lado da ponte: chega ao piso
	var lado_ponte := eixo + d * 5.0
	var fundo: Vector3 = raio.call(lado_ponte + Vector3(0, S.topo - S.piso + 8.0, 0), lado_ponte - Vector3(0, 6, 0))
	# no eixo, de cima da galeria: bate na ponte
	var ponte: Vector3 = raio.call(eixo + Vector3(0, S.ANEL_ALTURA + 6.0, 0), eixo)
	# do salão até fora da boca, pelo meio do túnel: nada no caminho
	var boca := Vector3(S.saida.x, S.saida_h + 3.5, S.saida.y)
	var tunel: Vector3 = raio.call(eixo + d * 26.0 + Vector3(0, 3.5, 0), boca + d * 4.0)
	# o robô cai pelo poço
	a.teleportar(lado_ponte + Vector3(0, S.topo - S.piso + 4.0, 0), Armadura.Estado.AR, Vector3.ZERO)
	var pousou := false
	for i in 10 * 60:
		await get_tree().physics_frame
		if a.is_on_floor():
			pousou = true
			break
	var onde := a.global_position.y - S.piso
	await _esperar(2.0)
	var eco: float = m.som_lugar.debug.get("na_caverna", -1.0)
	a.teleportar(il.spawn + Vector3(0, 0.3, 0), Armadura.Estado.CHAO, Vector3.ZERO)
	await _esperar(0.2)
	_ok(S.existe and fundo != Vector3.INF and absf(fundo.y - S.piso) < 2.0 and ponte != Vector3.INF and absf(ponte.y - S.piso - S.ANEL_ALTURA) < 1.5
			and tunel == Vector3.INF and pousou and absf(onde) < 2.0 and eco > 0.9 and S.topo - S.piso > 40.0,
		"sumidouro: %.0f m de fundura; o poço chega a %.1f m do piso; ponte a %.1f m; túnel livre até a boca (%s); o robô caiu pelo poço e pousou a %.1f m do piso (%s), eco %.2f"
		% [S.topo - S.piso, fundo.y - S.piso if fundo != Vector3.INF else 99.0, ponte.y - S.piso if ponte != Vector3.INF else -1.0, tunel == Vector3.INF, onde, pousou, eco])


## 24. Vibração, Zangão acima das copas, água da lagoa e morcegos do Sumidouro.
func _ponto_24() -> void:
	print("vibração, copas e vida do sumidouro")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	# vibração: cada ação deixa o tranco dela no registro
	a.teleportar(il.spawn + Vector3(0, 6.0, 12.0), Armadura.Estado.AR, Vector3.ZERO)
	Vibra.registro.clear()
	await _esperar(2.0)
	Input.action_press("atirar")
	await _esperar(0.4)
	Input.action_release("atirar")
	a.graca_pane = 0.0
	a.levar_golpe(Vector3(1, 0, 0), 2.0)
	a.golpe_chao.emit(a.global_position)
	await _esperar(0.3)
	var pousou := Vibra.registro.has("pouso_leve") or Vibra.registro.has("pouso_pesado")
	var vib := pousou and Vibra.registro.has("tiro") and Vibra.registro.has("levar_golpe") and Vibra.registro.has("golpe_chao")
	a.avaria = 0
	# (o Zangão, que voava por cima das copas, saiu do jogo: todas as máquinas andam no chão)
	# a lagoa do Sumidouro é água de verdade, e os morcegos se agitam com o robô no poço
	var S := Sumidouro
	var nivel := v.agua(S.centro.x, S.centro.y)
	var fora_dagua := v.agua(S.centro.x + 9.0, S.centro.y)
	var calmos := S.morcegos.agitados
	a.teleportar(Vector3(S.centro.x + 3.0, S.piso + 14.0, S.centro.y), Armadura.Estado.PAIRAR, Vector3.ZERO)
	Input.action_press("mirar")
	await _esperar(1.5)
	Input.action_release("mirar")
	var agitados := S.morcegos.agitados
	a.teleportar(il.spawn + Vector3(0, 0.3, 0), Armadura.Estado.CHAO, Vector3.ZERO)
	await _esperar(0.2)
	_ok(vib and absf(nivel - (S.piso - S.LAGOA_FUNDO)) < 0.01 and fora_dagua == -INF and calmos < 0.2 and agitados > 0.8,
		"vibração: %s; lagoa a %.2f m do piso; morcegos de %.2f a %.2f com o robô no poço"
		% [str(Vibra.registro.slice(0, 8)), nivel - S.piso, calmos, agitados])


## 25. A mira trava na máquina perto do centro (e o tiro travado acerta); longe do centro não trava. No poço
## fundo da cachoeira o robô nada: desce para onde a câmera olha, esfria, pula para fora na tona e, vindo
## rápido de baixo, rompe a lâmina voando.
func _ponto_25() -> void:
	(il as Vale)._corpo_arvores.collision_layer = 0  # sem árvores entre o robô e a máquina (o ponto 29 mede o obstáculo)
	print("mira com trava e nado")
	_soltar_tudo()
	_zerar()
	var alvo_m: Node3D = null
	for n in get_tree().get_nodes_in_group("maquinas"):
		if n is MaquinaPequena and (n.call("ponto_de_trava") as Vector3).is_finite():
			alvo_m = n
			break
	var travou := false
	var acertou := false
	var sem_trava := false
	if alvo_m:
		var pm: Vector3 = alvo_m.call("ponto_de_trava")
		var chao := Vector2(pm.x + 22.0, pm.z)
		a.teleportar(Vector3(chao.x, il.altura(chao.x, chao.y) + 0.3, chao.y), Armadura.Estado.CHAO, Vector3.ZERO)
		a.graca_pane = 30.0  # as máquinas não reagem durante a medida
		Input.action_press("mirar")
		var calor0: float = alvo_m.get("calor")
		for desvio: float in [3.0, 16.0]:
			for i in 50:
				pm = alvo_m.call("ponto_de_trava")
				var d := pm - cam.global_position
				cam.yaw = atan2(-d.x, -d.z) + deg_to_rad(desvio)
				cam.pitch = atan2(d.y, Vector2(d.x, d.z).length())
				if desvio < 5.0 and i == 20:
					Input.action_press("atirar")
				await get_tree().physics_frame
			if desvio < 5.0:
				travou = m.tiro.travado == alvo_m
				Input.action_release("atirar")
				await _esperar(0.5)
				acertou = float(alvo_m.get("calor")) > calor0 or bool(alvo_m.get("desligada"))
			else:
				sem_trava = m.tiro.travado == null
		Input.action_release("mirar")
		a.graca_pane = 0.0
	# nado no poço da cachoeira
	_zerar()
	var poco := Vector3(Vale.POCO.x, Vale.POCO_NIVEL, Vale.POCO.y)
	var fundura := Vale.POCO_NIVEL - il.altura(poco.x, poco.z)
	a.teleportar(poco + Vector3(0, -3.0, 0), Armadura.Estado.AR, Vector3.ZERO)
	await _esperar(0.3)
	var nadando := a.estado == Armadura.Estado.NADO
	a.calor = 60.0
	cam.pitch = -0.7
	var y0 := a.global_position.y
	Input.action_press("frente")
	await _esperar(0.8)
	Input.action_release("frente")
	var desceu := y0 - a.global_position.y
	var esfriou := 60.0 - a.calor
	# sobe devagar até a tona e pula para fora
	Input.action_press("pular")
	await _esperar(2.5)
	Input.action_release("pular")
	var na_tona := a.estado == Armadura.Estado.NADO and Vale.POCO_NIVEL - a.global_position.y < a.altura_corpo()
	await _esperar(0.2)
	await _apertar("pular")
	await _esperar(0.25)
	var pulou := a.estado == Armadura.Estado.AR and a.global_position.y > Vale.POCO_NIVEL - 0.3
	# de baixo para cima com os jatos abertos: sai voando
	a.teleportar(poco + Vector3(0, -fundura + 1.5, 0), Armadura.Estado.AR, Vector3.ZERO)
	await _esperar(0.3)
	cam.pitch = 1.2
	Input.action_press("frente")
	await _apertar("correr_alternar")
	var saiu_voando := false
	for i in 150:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.VOO and a.global_position.y > Vale.POCO_NIVEL:
			saiu_voando = true
			break
	Input.action_release("frente")
	cam.pitch = -0.12
	# a correnteza das fitas vai no sentido em que o comprimento cresce: o nível tem de descer nesse sentido
	var rio_desce := true
	for cu in (il as Vale)._cursos:
		var sv: float = cu.fita_de
		while sv + 10.0 <= cu.fita_ate:
			if cu.nivel(sv + 10.0) > cu.nivel(sv) + 0.001:
				rio_desce = false
			sv += 10.0
	(il as Vale)._corpo_arvores.collision_layer = 2
	_ok(rio_desce and alvo_m != null and travou and acertou and sem_trava and fundura > 9.0 and nadando and desceu > 1.5 and esfriou > 15.0 and na_tona and pulou and saiu_voando,
		"os rios só descem no sentido da correnteza (%s); mira: travou a 3° do centro (%s), o tiro travado acertou (%s), a 16° não trava (%s); poço com %.1f m de fundura: nada (%s), desceu %.1f m em 0,8 s, esfriou %.0f, parou na tona (%s), pulou para fora (%s), saiu voando de baixo (%s)"
		% [rio_desce, travou, acertou, sem_trava, fundura, nadando, desceu, esfriou, na_tona, pulou, saiu_voando])
	_soltar_tudo()
	a.recomecar()
	await _esperar(0.3)


## 29. Física: um desnível baixo sobe andando e um alto barra; a colisão de cada árvore segue o modelo dela
## (tronco fino, copa sólida só onde há folhagem, livre por baixo); o projétil de mecha para na parede e a
## parede tapa a vista dele.
func _ponto_26() -> void:
	print("física: degraus, árvores e projéteis")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	m.add_child(corpo)
	var caixa := func(centro: Vector2, tam: Vector2, alto: float) -> void:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(tam.x, alto + 3.0, tam.y)
		cs.shape = bx
		corpo.add_child(cs)
		cs.global_position = Vector3(centro.x, v.altura(centro.x, centro.y) + alto - (alto + 3.0) * 0.5, centro.y)
	var lugar := Vector3(-20.0, 0.0, 20.0)
	lugar.y = v.altura(lugar.x, lugar.z)
	caixa.call(Vector2(lugar.x, lugar.z - 4.0), Vector2(5.0, 3.0), 0.36)
	caixa.call(Vector2(lugar.x, lugar.z + 4.0), Vector2(5.0, 3.0), 0.95)
	a.teleportar(lugar + Vector3(0, 0.3, 0), Armadura.Estado.CHAO)
	await _esperar(0.5)
	var d0: int = a.degraus
	cam.yaw = 0.0
	Input.action_press("frente")
	await _esperar(2.2)
	Input.action_release("frente")
	var subiu: bool = a.degraus > d0 and a.global_position.z < lugar.z - 2.6 and a.global_position.y > v.altura(a.global_position.x, a.global_position.z) + 0.25
	a.teleportar(lugar + Vector3(0, 0.3, 0), Armadura.Estado.CHAO)
	await _esperar(0.5)
	cam.yaw = PI
	Input.action_press("frente")
	await _esperar(2.5)
	Input.action_release("frente")
	var barrou: bool = a.global_position.z < lugar.z + 2.6
	_soltar_tudo()
	# uma árvore de folha larga sem vizinha por perto
	var qual := -1
	for i in v.arv_pos.size():
		if i >= v.arv_nome.size() or v.arv_nome[i].contains("pinheiro") or v.arv_nome[i].contains("betula"):
			continue
		var p := v.arv_pos[i]
		if Vector2(p.x, p.z).length() < 170.0 or Vector2(p.x, p.z).length() > 600.0:
			continue
		var so := true
		for k in v.arv_pos.size():
			if k != i and Vector2(v.arv_pos[k].x - p.x, v.arv_pos[k].z - p.z).length() < 16.0:
				so = false
				break
		if so:
			qual = i
			break
	var arvore_ok := false
	var txt := "nenhuma árvore isolada"
	if qual >= 0:
		var p := v.arv_pos[qual]
		var s := v.arv_escala[qual] / 0.8
		var f: Array = v.forma_da_arvore(v.arv_nome[qual])
		a.teleportar(p + Vector3(9.0, 0.6, 0.0), Armadura.Estado.CHAO)
		await _esperar(0.4)
		var espaco := a.get_world_3d().direct_space_state
		var de_cima := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 80, 0), p + Vector3(0, 0.5, 0), 2))
		var topo_y := ((de_cima["position"] as Vector3).y - p.y) if not de_cima.is_empty() else -1.0
		var de_lado := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(6, 1.0, 0), p + Vector3(0, 1.0, 0), 2))
		var tronco_r := Vector2((de_lado["position"] as Vector3).x - p.x, (de_lado["position"] as Vector3).z - p.z).length() if not de_lado.is_empty() else -1.0
		var y_baixo := (float(f[3]) - float(f[4]) * 0.5) * s - 0.5
		var fora := float(f[0]) * s + 0.7
		var por_baixo := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(9, y_baixo, fora), p + Vector3(-9, y_baixo, fora), 2))
		var copa_de := (float(f[3]) - float(f[4]) * 0.5) * s
		arvore_ok = topo_y > copa_de and topo_y < (float(f[3]) + float(f[4]) * 0.5) * s + 0.6 and tronco_r > 0.1 and tronco_r < 0.9 and por_baixo.is_empty()
		txt = "%s: copa sólida de %.1f a %.1f m (raio achado no topo %.1f m), tronco de %.2f m de raio, livre por baixo (%s)" % [v.arv_nome[qual], copa_de, topo_y, float(f[2]) * s, tronco_r, por_baixo.is_empty()]
	# o projétil do mecha para numa parede no meio do caminho, e a parede tapa a vista
	var mc: MaquinaPequena = m.inimigos.todas[0] if m.inimigos and not m.inimigos.todas.is_empty() else null
	var parou := false
	var sem_vista := false
	if mc:
		m.inimigos.process_mode = Node.PROCESS_MODE_DISABLED
		mc.religar()
		var pm := mc.global_position + Vector3(0, 0, 30)
		a.teleportar(Vector3(pm.x, v.altura(pm.x, pm.z) + 0.3, pm.z), Armadura.Estado.CHAO)
		a.graca_pane = 0.0
		caixa.call(Vector2(mc.global_position.x, mc.global_position.z + 14.0), Vector2(14.0, 1.2), 9.0)
		await _esperar(0.3)
		var g0: int = a.golpes
		var p0: int = mc.paradas
		var boca := mc.centro() + Vector3(0, 0.6, 0)
		sem_vista = not mc.alvo_visivel(200.0, boca)
		mc.atirar_em(boca, mc.centro_alvo(), "bala", 0.0)
		for i in 90:
			await get_tree().physics_frame
			mc.atualizar_tiros(1.0 / 60.0)
		parou = mc.paradas > p0 and a.golpes == g0
		mc.desligar()
		m.inimigos.process_mode = Node.PROCESS_MODE_INHERIT
	corpo.queue_free()
	_ok(subiu and barrou and arvore_ok and parou and sem_vista,
		"física: degrau de 36 cm subiu andando (%s), de 95 cm barrou (%s); %s; o projétil parou na parede (%s) e a parede tapa a vista do mecha (%s)"
		% [subiu, barrou, txt, parou, sem_vista])
	a.recomecar()
	await _esperar(0.3)


## 30. Mechas e bichos não atravessam tronco, pedra, ruína nem a base: há obstáculos registrados; um mecha em
## ronda dá a volta numa fila de pedras e chega do outro lado; um cervo fugindo também; um mecha cercado
## percebe que travou e muda de plano.
func _ponto_27() -> void:
	print("mechas e bichos desviam dos obstáculos")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	# o que já está registrado: um tronco e a parede da base barram; o estrado da base não
	var com_tronco := -1
	for i in v.arv_pos.size():
		if Vector2(v.arv_pos[i].x, v.arv_pos[i].z).length() > 200.0:
			com_tronco = i
			break
	var tronco_barra := com_tronco >= 0 and not Obstaculos.livre(v, v.arv_pos[com_tronco].x, v.arv_pos[com_tronco].z, 0.4)
	var tb := Transform3D(Basis(Vector3.UP, Ruinas.BASE.z), Vector3(Ruinas.BASE.x, 0, Ruinas.BASE.y))
	var parede := tb * Vector3(0.4, 0, 6.6)
	var estrado := tb * Vector3(0.0, 0, -1.0)
	var base_ok := not Obstaculos.livre(v, parede.x, parede.z, 0.4) and Obstaculos.livre(v, estrado.x, estrado.z, 0.4)
	# uma fila de pedras no campo aberto, atravessada no caminho
	var a0 := Vector3(-30.0, 0.0, 30.0)
	var b0 := Vector3(-30.0, 0.0, 8.0)
	var pedras: Array[Vector3] = []
	for k in range(-2, 3):
		pedras.append(Vector3(a0.x + k * 1.7, 0.0, 19.0))
		Obstaculos.registrar(a0.x + k * 1.7, 19.0, 1.0)
	var perto := func(p: Vector3, folga: float) -> bool:
		for q in pedras:
			if Vector2(p.x - q.x, p.z - q.z).length() < folga:
				return true
		return false
	# o mecha em ronda
	var mc: Vigia = null
	for n in m.inimigos.todas:
		if n is Vigia and not (n as Vigia).chefe:
			mc = n
			break
	var chegou := false
	var atravessou := false
	var desviou := false
	var destravou := false
	if mc:
		a.teleportar(Vector3(-30.0, v.altura(-30.0, 62.0) + 0.3, 62.0), Armadura.Estado.CHAO)
		a.graca_pane = 999.0  # ninguém o enxerga: o mecha fica em ronda
		await _esperar(0.3)
		mc.religar()
		mc.process_mode = Node.PROCESS_MODE_INHERIT
		mc.global_position = Vector3(a0.x, v.altura(a0.x, a0.z), a0.z)
		mc.estado = Vigia.Estado.RONDA
		mc._destino = b0
		mc._pausa = 0.0
		var d0: int = mc.desvios
		var menor := INF
		var passou_t := 0.0
		while passou_t < 40.0:  # por tempo de jogo: sem tela os quadros passam mais depressa que 60 por segundo
			await get_tree().process_frame
			passou_t += get_process_delta_time()
			if perto.call(mc.global_position, 1.0 + mc.altura_m * 0.3 * 0.7):
				atravessou = true
			menor = minf(menor, Vector2(mc.global_position.x - b0.x, mc.global_position.z - b0.z).length())
			if menor < 1.5:
				break
			if mc.estado == Vigia.Estado.RONDA and mc._pausa <= 0.0 and mc._destino.distance_to(b0) > 0.1 and menor > 1.5:
				mc._destino = b0  # se trocou de destino ao destravar, o teste devolve o mesmo alvo
		chegou = menor < 1.5
		print("    mecha: menor distância ao destino %.1f m, parou em %s, destravou %d vezes, velocidade de ronda %.1f" % [menor, mc.global_position, mc.destravou, Vigia.VEL_RONDA])
		desviou = mc.desvios > d0
	# um cervo fugindo na direção da fila
	var cv: Cervo = null
	for n in m.vida.get_children():
		if n is Cervo:
			cv = n
			break
	var cervo_passou := false
	var cervo_atravessou := false
	if cv:
		cv.process_mode = Node.PROCESS_MODE_DISABLED  # só o passo, chamado à mão
		cv.global_position = Vector3(a0.x + 0.3, v.altura(a0.x, a0.z), a0.z)
		cv.rotation.y = 0.0
		for i in 60 * 8:
			cv._passo(1.0 / 60.0, 5.0, Vector3(0, 0, -1), false, 2.5)
			cv.rotation.y = lerp_angle(cv.rotation.y, atan2(-cv._rumo.x, -cv._rumo.z), 0.2)
			if perto.call(cv.global_position, 1.0 + cv.altura_bicho * 0.32 * 0.7):
				cervo_atravessou = true
			if cv.global_position.z < 12.0:
				cervo_passou = true
				break
		cv.process_mode = Node.PROCESS_MODE_INHERIT
	if mc:
		# cercado: um anel de pedras em volta dele; ele tem de notar que travou
		var c0 := mc.global_position
		for k in 10:
			Obstaculos.registrar(c0.x + cos(k * TAU / 10.0) * 2.6, c0.z + sin(k * TAU / 10.0) * 2.6, 1.0)
		mc._destino = c0 + Vector3(0, 0, -20)
		mc._pausa = 0.0
		var t0: int = mc.destravou
		var passou_t := 0.0
		while passou_t < 4.0:
			await get_tree().process_frame
			passou_t += get_process_delta_time()
			if mc.estado == Vigia.Estado.RONDA and mc._pausa > 0.0:
				mc._pausa = 0.0
		destravou = mc.destravou > t0 and mc.global_position.distance_to(c0) < 2.2
		mc.desligar()
	a.graca_pane = 0.0
	_ok(Obstaculos.quantos > 800 and tronco_barra and base_ok and mc != null and chegou and not atravessou and desviou and destravou and cv != null and cervo_passou and not cervo_atravessou,
		"desvio: %d obstáculos registrados, tronco barra (%s), parede da base barra e o estrado não (%s); o mecha deu a volta na fila de pedras e chegou (%s, atravessou: %s, desviou: %s); cercado, notou que travou (%s); o cervo deu a volta (%s, atravessou: %s)"
		% [Obstaculos.quantos, tronco_barra, base_ok, chegou, atravessou, desviou, destravou, cervo_passou, cervo_atravessou])
	a.recomecar()
	await _esperar(0.3)


## 31. O drone colega fala quando o robô chega perto, e com ele na mira o tiro não sai. Os passos e os bipes
## de síntese existem.
func _ponto_28() -> void:
	print("drone colega: fala e não leva tiro")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	var dr: DroneColega = m.drone
	var falou := false
	var poupou := false
	var nao_saiu := false
	var atira_longe := false
	if dr:
		a.teleportar(Vector3(-40.0, v.altura(-40.0, 10.0) + 0.3, 10.0), Armadura.Estado.CHAO)
		await _esperar(0.6)
		var b0 := dr.bipes
		var perto := dr.posto + Vector3(0, 0, -4.5)
		a.teleportar(Vector3(perto.x, v.altura(perto.x, perto.z) + 0.5, perto.z), Armadura.Estado.CHAO)
		await _esperar(1.0)
		falou = dr.bipes > b0 and int(Som.contagem.get("drone_1", 0)) + int(Som.contagem.get("drone_2", 0)) + int(Som.contagem.get("drone_3", 0)) + int(Som.contagem.get("drone_4", 0)) + int(Som.contagem.get("drone_5", 0)) + int(Som.contagem.get("drone_6", 0)) > 0
		# mira no drone (duas voltas: a câmera fica atrás do robô, então a pontaria é acertada a partir dela)
		for volta in 3:
			var d: Vector3 = dr.global_position - cam.global_position
			cam.yaw = atan2(-d.x, -d.z)
			cam.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			await _esperar(0.3)
		var d0: int = m.tiro.disparos
		var p0: int = m.tiro.poupados
		Input.action_press("atirar")
		await _esperar(0.6)
		Input.action_release("atirar")
		poupou = m.tiro.poupados > p0
		nao_saiu = m.tiro.disparos == d0
		# virado para o outro lado, atira normalmente
		cam.yaw += PI
		cam.pitch = 0.0
		await _esperar(0.4)
		d0 = m.tiro.disparos
		Input.action_press("atirar")
		await _esperar(0.5)
		Input.action_release("atirar")
		atira_longe = m.tiro.disparos > d0
	var arquivos := true
	for nome in ["passo_1", "passo_6", "drone_1", "drone_6"]:
		if not ResourceLoader.exists(Som.PASTA % nome):
			arquivos = false
	_ok(dr != null and falou and poupou and nao_saiu and atira_longe and arquivos,
		"drone: falou quando o robô chegou perto (%s); com ele na mira o tiro não sai (poupou: %s, nenhum disparo: %s) e para o outro lado sai (%s); sons de síntese presentes (%s)"
		% [falou, poupou, nao_saiu, atira_longe, arquivos])
	_soltar_tudo()
	a.recomecar()
	await _esperar(0.3)


## 32. Melhorias: o robô básico esquenta três vezes mais rápido no voo e não tem nado rápido; chegando perto
## de uma peça ele pega, e entrando no cilindro da base ela é instalada e aparece no corpo.
func _ponto_29() -> void:
	print("melhorias: robô básico, achar a peça e instalar no cilindro")
	_soltar_tudo()
	_zerar()
	var pm: PecasMundo = m.pecas
	Melhorias.tudo = false
	Melhorias.achadas = []
	Melhorias.instaladas = []
	a.visual.vestir_melhorias()
	pm.repor()
	await _esperar(0.2)
	_ok(Melhorias.calor_voo() > Ajustes.CALOR_VOO * 2.5 and not Melhorias.nado_rapido() and Melhorias.esfria_chao() < Ajustes.ESFRIA_CHAO,
		"o básico esquenta em ~%d s de voo, sem nado rápido" % int(100.0 / Melhorias.calor_voo()))
	_ok(a.visual.pecas.is_empty() and pm._nos.size() == Melhorias.NOMES.size(), "básico sem peças no corpo; %d peças na ilha" % pm._nos.size())
	var seco := true
	for nome: String in pm.onde:
		var p: Vector3 = pm.onde[nome]
		var nivel: float = m.ilha.agua(p.x, p.z)
		if nivel != -INF and nivel > p.y:
			seco = false
	_ok(seco, "todas as peças em chão seco")
	var pa: Vector3 = pm.onde["antena"]
	# no facho de luz, 6 m acima da caixa, não pega; nem a 3 m de lado
	a.teleportar(pa + Vector3(0, 6.0, 0), Armadura.Estado.AR)
	await _esperar(0.1)
	var no_facho: bool = Melhorias.achadas.is_empty()
	a.teleportar(pa + Vector3(3.0, 0.3, 0), Armadura.Estado.CHAO)
	await _esperar(0.3)
	_ok(no_facho and Melhorias.achadas.is_empty(), "o facho de luz e a vizinhança não pegam a peça: só encostando na caixa")
	var pf: Vector3 = pm.onde["farol"]
	var esp_t := a.get_world_3d().direct_space_state
	var teto_t := esp_t.intersect_ray(PhysicsRayQueryParameters3D.create(pf + Vector3(0, 0.4, 0), pf + Vector3(0, 4.0, 0), 1))
	_ok(Sumidouro.existe and absf(pf.y - Sumidouro.piso) < 1.5 and Sumidouro.no_vazio(pf + Vector3(0, 1.0, 0)) and teto_t.is_empty(),
		"a peça da luz fica no piso do salão do Sumidouro, com vão livre por cima (%.1f m; piso a %.1f)" % [pf.y, Sumidouro.piso])
	a.teleportar(pa + Vector3(0, 0.3, 0), Armadura.Estado.CHAO)
	await _esperar(0.4)
	_ok(Melhorias.achadas.has("antena") and not Melhorias.tem("antena"), "chegou perto: pegou a antena (ainda não vale)")
	# a oficina: convite na boca, entra, instala gastando energia, recusa sem energia e sai
	var of: Oficina = m.oficina
	var b := BaseVale.boca_cilindro
	Melhorias.energia = 100.0
	Melhorias.achar("farol")
	a.teleportar(Vector3(b.x, m.ilha.altura(b.x, b.z) + 0.4, b.z), Armadura.Estado.CHAO)
	await _esperar(0.5)
	var convite: bool = of.perto and m.hud.dica != "" and not Melhorias.tem("antena")
	await _apertar("agir")
	await _esperar(2.4)
	_ok(convite and of.fase == Oficina.Fase.ABERTA and a.travado, "quadrado na boca do cilindro abre a oficina (o robô entra e fica parado)")
	of.instalar("antena")
	await _esperar(2.3)
	_ok(Melhorias.tem("antena") and a.visual.pecas.has("antena"), "instalou a antena: no corpo do robô")
	of.instalar("farol")
	await _esperar(2.3)
	_ok(Melhorias.tem("farol") and Melhorias.achadas.is_empty(), "a segunda peça instala em seguida, sem esperar (não há mais energia da base)")
	of.sair()
	await _esperar(1.8)
	_ok(of.fase == Oficina.Fase.FORA and not a.travado and m.hud.visible, "saiu da oficina e o robô voltou ao jogador")
	Melhorias.instaladas.erase("farol")
	await _esperar(0.7)
	var longe := Melhorias.sinais.is_empty()
	var pr: Vector3 = pm.onde["radiador"]
	var b0 := pm.bipes
	a.teleportar(Vector3(pr.x + 150.0, m.ilha.altura(pr.x + 150.0, pr.z) + 0.4, pr.z), Armadura.Estado.CHAO)
	await _esperar(0.8)
	_ok(longe and Melhorias.sinais.size() >= 1 and Melhorias.sinais.size() <= 2 and pm.bipes == b0 + Melhorias.sinais.size() and Melhorias.base.is_finite(),
		"a antena só capta peça por perto (%d sinal a 150 m), com bipe; a base está na bússola" % Melhorias.sinais.size())
	Melhorias.tudo = true
	Melhorias.instaladas = []
	Melhorias.energia = 100.0
	Melhorias.sinais.clear()
	a.visual.vestir_melhorias()
	pm.repor()


## 33. Scanner: a seta para a direita leva a câmera para os olhos do robô; com o círculo em cima do Faísca
## caído a leitura enche e sai a ficha; apertando de novo, volta à terceira pessoa.
func _ponto_30() -> void:
	print("scanner: primeira pessoa, leitura no círculo e ficha")
	_soltar_tudo()
	_zerar()
	var sc: Scanner = m.scanner
	var f := BaseVale.faisca_em
	var de := f + (a.global_position - f).normalized() * 0.0 + Vector3(4.5, 0, 3.0)
	a.teleportar(Vector3(de.x, m.ilha.altura(de.x, de.z) + 0.4, de.z), Armadura.Estado.CHAO)
	await _esperar(0.6)
	await _apertar("scanner")
	await _esperar(0.3)
	var entrou: bool = sc.ligado and cam.primeira and not a.visual.visible
	for volta in 3:
		var d: Vector3 = f + Vector3(0, 0.45, 0) - cam.global_position
		cam.yaw = atan2(-d.x, -d.z)
		cam.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await _esperar(0.2)
	var l0 := sc.leituras
	await _esperar(2.2)
	_ok(entrou and sc.leituras == l0 + 1 and String(sc.ficha.get("nome", "")) == "Faísca",
		"círculo em cima do Faísca: leitura completa e ficha (%s)" % String(sc.ficha.get("nome", "nada")))
	cam.yaw += PI
	await _esperar(1.2)
	var largou: bool = not (sc.alvo_atual is String)  # virado, o Faísca saiu do círculo (outro alvo pode ter entrado)
	await _apertar("scanner")
	await _esperar(0.3)
	_ok(largou and not sc.ligado and not cam.primeira and a.visual.visible, "virando a câmera o Faísca sai do círculo; apertando de novo volta à terceira pessoa")


## 34. A Fundição: a cratera é chata e sem árvores; o painel liga a onda, os robôs saem dos portões, vencidos
## dão experiência e sucata, a onda seguinte vem depois do respiro e sair da cratera para tudo. E a pistola:
## segurando o gatilho sai um tiro só.
func _ponto_31() -> void:
	print("fundição: cratera, ondas, recompensa e pistola")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	var f: Fundicao = m.fundicao
	var chato := true
	for lx: float in [-46.0, -20.0, 0.0, 20.0, 46.0]:
		for lz: float in [-36.0, -15.0, 0.0, 15.0, 36.0, 50.0]:
			var p := Fundicao.aqui(lx, 0, lz)
			if absf(v.altura(p.x, p.z) - Fundicao.PISO) > 0.3:
				chato = false
	var atras := Fundicao.aqui(0, 0, -Fundicao.MZ - 40.0)
	var morro := v.altura(atras.x, atras.z) - Fundicao.PISO
	_ok(f != null and chato and morro > 18.0 and not Ruinas.livre(Fundicao.CENTRO.x + 40.0, Fundicao.CENTRO.y),
		"o chão do galpão é chato, sem mata, e os fundos entram no morro (%.0f m acima do piso, 40 m atrás)" % morro)
	var meio := Vector3(Fundicao.CENTRO.x + 2.6, Fundicao.PISO + 0.4, Fundicao.CENTRO.y)
	a.teleportar(meio, Armadura.Estado.CHAO)
	await _esperar(0.5)
	# a pistola: gatilho segurado por 1 s dá um disparo; três apertos dão três
	cam.pitch = 0.5
	var d0: int = m.tiro.disparos
	Input.action_press("atirar")
	await _esperar(1.0)
	Input.action_release("atirar")
	var um: bool = m.tiro.disparos == d0 + 1
	for k in 3:
		await _apertar("atirar")
		await _esperar(0.3)
	_ok(um and m.tiro.disparos == d0 + 4, "pistola: segurar dá um tiro só; cada aperto, um (%d em 4)" % (m.tiro.disparos - d0))
	_zerar()
	var convite: bool = m.hud.dica.begins_with("Quadrado / E:  ligar a Fundição")
	await _apertar("agir")
	await _esperar(0.3)
	var contando: bool = f.fase == Fundicao.Fase.CONTAGEM and f.onda == 1
	await _esperar(Fundicao.T_CONTAGEM + 4.5)
	var esperado := Fundicao.receita(1).size()
	# saem da porta e se abrem em leque: não ficam todos na mesma linha
	var xs := []
	for mc0 in f.vivos:
		xs.append(mc0.global_position.x)
	var abertura: float = (xs.max() - xs.min()) if xs.size() > 1 else 0.0
	_ok(convite and contando and f.fase == Fundicao.Fase.ONDA and f.vivos.size() == esperado,
		"quadrado no painel liga a onda 1: %d robôs saem da porta e se espalham (%.0f m de um lado ao outro)" % [f.vivos.size(), abertura])
	_ok(abertura > 3.0, "os robôs não saem em fila reta: 4,5 s depois da porta já abriram %.0f m" % abertura)
	Arsenal.xp = 95  # a um passo do nível 2: vencer a onda sobe de nível, com a aura
	var xp0 := Arsenal.xp
	var auras0 := int(EfeitosTiro.contagem.get("aura", 0))
	for mc in f.vivos.duplicate():
		mc.calor = 100.0
		mc.desligar()
	await _esperar(0.5)
	_ok(Arsenal.nivel() == 2 and f.subidas == 1 and int(EfeitosTiro.contagem.get("aura", 0)) == auras0 + 1, "subiu para o nível 2 e a aura apareceu em volta do robô")
	_ok(f.fase == Fundicao.Fase.RESPIRO and Arsenal.xp > xp0 and Arsenal.sucata >= esperado and m.hud.placar != "",
		"robôs vencidos: experiência %d, sucata %d, e o respiro começa" % [Arsenal.xp, Arsenal.sucata])
	a.calor = 0.0
	await _esperar(Fundicao.T_RESPIRO + 1.0)
	var segunda: bool = f.fase == Fundicao.Fase.ONDA and f.onda == 2
	a.teleportar(Vector3(Fundicao.CENTRO.x + Fundicao.SAIU + 12.0, v.altura(Fundicao.CENTRO.x + Fundicao.SAIU + 12.0, Fundicao.CENTRO.y) + 0.5, Fundicao.CENTRO.y), Armadura.Estado.CHAO)
	await _esperar(0.6)
	_ok(segunda and f.fase == Fundicao.Fase.PARADA and f.vivos.is_empty() and f.onda == 1 and m.hud.placar == "",
		"a onda 2 vem sozinha; saindo da cratera tudo para e a onda 2 fica para a volta")
	# o telhado segura o robô: solto de cima em vários pontos (painéis, emendas e nervuras) ele para em cima,
	# e voando depressa contra a lateral do arco ele não atravessa
	var em_cima := 0
	var pontos_teto := [Vector2(-30.0, 20.0), Vector2(-14.2, 28.5), Vector2(22.0, -30.0), Vector2(38.0, 0.0), Vector2(-44.0, 9.5), Vector2(9.8, 19.0)]
	for pt: Vector2 in pontos_teto:
		a.teleportar(Fundicao.aqui(pt.x, Fundicao.teto(pt.x) + 6.0, pt.y), Armadura.Estado.AR)
		await _esperar(1.6)
		var lz: float = a.global_position.z - Fundicao.CENTRO.y
		var lx: float = a.global_position.x - Fundicao.CENTRO.x
		if a.global_position.y - Fundicao.PISO > Fundicao.teto(lx) - 0.4 or absf(lx) > Fundicao.ARCO_A or absf(lz) > Fundicao.MZ + 1.0:
			em_cima += 1
	a.teleportar(Fundicao.aqui(-75.0, 8.0, 10.0), Armadura.Estado.VOO, Vector3(40.0, 0, 0))
	cam.yaw = -PI * 0.5
	cam.pitch = 0.0
	await _esperar(1.2)
	var fora_arco: bool = (a.global_position.x - Fundicao.CENTRO.x) < -Fundicao.ARCO_A * 0.75
	_ok(em_cima == pontos_teto.size() and fora_arco, "o telhado da forja segura o robô (%d de %d pousos em cima; voando contra a lateral, parou a %.0f m do meio)" % [em_cima, pontos_teto.size(), a.global_position.x - Fundicao.CENTRO.x])
	a.teleportar(meio, Armadura.Estado.CHAO)
	await _esperar(0.3)
	_ok(Fundicao.receita(5)[0]["chefe"] and Fundicao.receita(10).size() < Fundicao.receita(9).size(), "de 5 em 5 ondas a receita traz um minichefe com escolta menor")
	# a dificuldade sobe aos poucos: só ataque de perto nas três primeiras; fuzis da 4ª, canhões da 7ª, mísseis da 10ª
	var so_perto := true
	for n in [1, 2, 3]:
		for d in Fundicao.receita(n):
			if d["arma"] != "corpo":
				so_perto = false
	var conta := func(n: int, arma: String) -> int:
		var q := 0
		for d in Fundicao.receita(n):
			if d["arma"] == arma:
				q += 1
		return q
	var perto_vivos := true
	for mc0 in f.vivos:
		perto_vivos = perto_vivos and mc0.corpo_a_corpo
	_ok(so_perto and conta.call(4, "bala") >= 1 and conta.call(4, "pesado") == 0 and conta.call(7, "pesado") >= 1 and conta.call(9, "missil") == 0 and conta.call(11, "missil") >= 1
		and conta.call(8, "corpo") >= 3, "ondas 1 a 3 só de perto; fuzis na 4ª (%d), canhões na 7ª (%d), mísseis depois da 10ª (%d na 11ª)" % [conta.call(4, "bala"), conta.call(7, "pesado"), conta.call(11, "missil")])
	# fabricáveis: sem a mira assistida a mira não trava; com materiais e nível, a oficina fabrica
	Arsenal.tudo = false
	_ok(not Arsenal.tem("mira") and Arsenal.falta("mira") != "" and Arsenal.golpes_pane() == Ajustes.PANE_GOLPES, "a mira assistida é fabricável: sem ela não trava, e sem materiais não fabrica")
	Arsenal.xp = 1000
	Arsenal.sucata = 100
	Arsenal.nucleos = 9
	var fez: bool = Arsenal.fabricar("mira") and Arsenal.fabricar("escudo") and Arsenal.fabricar("vida")
	a.escudo_t = 0.0
	a.avaria = 0
	a.levar_golpe(Vector3.FORWARD, 1.0)
	_ok(fez and Arsenal.tem("mira") and Arsenal.sucata == 15 and Arsenal.golpes_pane() == Ajustes.PANE_GOLPES + 1 and a.avaria == 0 and a.escudo_t > 0.0,
		"fabricou mira, escudo e vida extra: sobra %d de sucata, aguenta %d acertos e o escudo engoliu um" % [Arsenal.sucata, Arsenal.golpes_pane()])
	Arsenal.tudo = true
	Arsenal.zerar()
	a.recomecar()


## 35. Armas: a rajada repete segurando; o canhão carrega e estoura em área; o tiro duplo solta dois; a
## granada desliga a máquina perto de onde cai; a roda (L1) troca a arma em câmera lenta e só deixa
## escolher o que foi fabricado.
func _ponto_32() -> void:
	print("armas: modos de tiro, granada e roda")
	_soltar_tudo()
	_zerar()
	var v: Vale = m.ilha
	var roda: RodaArmas = m.get_node("RodaArmas")
	var lugar := Vector3(-30.0, v.altura(-30.0, 60.0) + 0.4, 60.0)
	a.teleportar(lugar, Armadura.Estado.CHAO)
	cam.pitch = 0.3
	await _esperar(0.5)
	Arsenal.tudo = false
	Arsenal.fabricados = []
	Arsenal.modo = "pistola"
	roda.trocar("rajada")
	var travou: bool = Arsenal.modo == "pistola" and Arsenal.granadas_max() == 0
	Arsenal.tudo = true
	Arsenal.repor_granadas()
	roda.trocar("rajada")
	var d0: int = m.tiro.disparos
	Input.action_press("atirar")
	await _esperar(0.6)
	Input.action_release("atirar")
	var rajada: int = m.tiro.disparos - d0
	_ok(travou and Arsenal.modo == "rajada" and rajada >= 5, "sem fabricar não troca; a rajada repete segurando (%d tiros em 0,6 s)" % rajada)
	_zerar()
	roda.trocar("duplo")
	await _esperar(0.3)
	var dd0: int = m.tiro.disparos
	await _apertar("atirar")
	await _esperar(0.1)
	var so_direito: bool = m.tiro.disparos == dd0 + 1
	await _esperar(0.3)
	Input.action_press("mirar")
	Input.action_press("atirar")
	await _esperar(0.25)
	var sem_mira: bool = not a.mirando and a.atirando_e > 0.0
	await _esperar(0.25)
	Input.action_release("mirar")
	Input.action_release("atirar")
	var dois: bool = so_direito and sem_mira and m.tiro.disparos == dd0 + 3 and a.visual.pecas.has("arma_duplo")
	_zerar()
	roda.trocar("canhao")
	await _esperar(0.4)
	d0 = m.tiro.disparos
	Input.action_press("atirar")
	await _esperar(0.7)
	var carregando: bool = m.tiro.carga > 0.4 and m.tiro.disparos == d0
	await _esperar(0.6)
	Input.action_release("atirar")
	await _esperar(0.2)
	_ok(dois and carregando and m.tiro.disparos == d0 + 1 and m.tiro.carga == 0.0, "tiro duplo: R2 um braço, L2 o outro (sem mirar, levantando o braço esquerdo); o canhão carrega e dispara ao soltar")
	# o estouro pega a máquina que está perto, e a de longe não
	var mc := Mecha.new()
	mc.mapa = v
	mc.casa = lugar + Vector3(0, 0, -14.0)
	mc.semente = 31
	m.add_child(mc)
	mc.global_position = mc.casa
	mc.pose_foto = 0
	await _esperar(0.3)
	var c0: float = mc.calor
	m.tiro._estouro(mc.centro() + Vector3(3.0, 0, 0), 2.0, 6.0)
	var pegou: bool = mc.calor > c0 + 10.0
	var c1: float = mc.calor
	m.tiro._estouro(mc.centro() + Vector3(14.0, 0, 0), 2.0, 6.0)
	var longe_nao: bool = mc.calor == c1
	# a granada sai em arco, cai e estoura
	_zerar()
	mc.calor = 0.0
	var g0: int = Arsenal.granadas
	for volta in 3:
		# a mira no chão, ao pé da mecha: é ali que a granada cai
		var dg: Vector3 = mc.global_position + Vector3(0, 0.1, 0) - cam.global_position
		cam.yaw = atan2(-dg.x, -dg.z)
		cam.pitch = atan2(dg.y, Vector2(dg.x, dg.z).length())
		await _esperar(0.2)
	Input.action_press("granada")
	await _esperar(0.3)
	var arco_g: PackedVector3Array = m.tiro.arco
	var sobe_g: Vector3 = (arco_g[1] - arco_g[0]).normalized() if arco_g.size() > 5 else Vector3.ZERO
	var cai_g: Vector3 = arco_g[arco_g.size() - 1] if arco_g.size() > 5 else Vector3.ZERO
	# sai a uns 70° e cai perto de onde a mira aponta (a mecha)
	var arco_ok: bool = arco_g.size() > 5 and Arsenal.granadas == g0 and rad_to_deg(asin(sobe_g.y)) > 60.0 and Vector2(cai_g.x - mc.global_position.x, cai_g.z - mc.global_position.z).length() < 5.0 and CameraVoo.afasta > 0.5
	Input.action_release("granada")
	await _esperar(3.4)
	_ok(arco_ok and pegou and longe_nao and Arsenal.granadas == g0 - 1 and m.tiro.granadas_jogadas >= 1 and m.tiro._granadas.is_empty() and mc.calor > 0.0,
		"segurando aparece o arco, que sai a 70° e cai onde a mira aponta, e a câmera recua; soltando, a granada esquenta a mecha (%.0f)" % mc.calor)
	# mísseis: segurando trava a máquina à frente; soltando sai um míssil que a segue
	_zerar()
	mc.calor = 0.0
	roda.trocar("misseis")
	var mi0: int = Arsenal.misseis
	for volta in 3:
		var dm: Vector3 = mc.centro() - cam.global_position
		cam.yaw = atan2(-dm.x, -dm.z)
		cam.pitch = atan2(dm.y, Vector2(dm.x, dm.z).length())
		await _esperar(0.2)
	Input.action_press("atirar")
	await _esperar(0.6)
	var travou_m: bool = m.tiro.travas.has(mc) and m.tiro.travas.size() <= 4 and Arsenal.misseis == mi0
	Input.action_release("atirar")
	await _esperar(0.25)
	var subindo := false
	for filho in m.tiro.get_children():
		if String(filho.name).begins_with("Missil") and (filho as Node3D).global_position.y > a.global_position.y + 2.0:
			subindo = true
	await _esperar(2.4)
	travou_m = travou_m and subindo
	# (outra mecha da ilha pode estar no cone e ser travada também: vale um míssil por alvo)
	_ok(travou_m and m.tiro.misseis_lancados >= 1 and Arsenal.misseis == mi0 - m.tiro.misseis_lancados and mc.calor > 30.0,
		"mísseis: segurando trava a mecha; soltando o míssil sobe do ombro, vira e acerta (calor %.0f, restam %d)" % [mc.calor, Arsenal.misseis])
	mc.queue_free()
	# as caixas das forjas: a de conserto apaga os acertos, a de munição enche os lançadores
	var fd: Fundicao = m.fundicao
	a.avaria = 2
	Arsenal.granadas = 0
	fd.soltar_caixa("conserto")
	fd.soltar_caixa("municao")
	await _esperar(5.0)
	for cx in fd._caixas.duplicate():
		a.teleportar((cx["no"] as Node3D).global_position + Vector3(0.5, 0.4, 0), Armadura.Estado.CHAO)
		await _esperar(0.4)
	_ok(fd.caixas_pegas == 2 and a.avaria == 0 and Arsenal.granadas == Arsenal.granadas_max() and Arsenal.misseis == Arsenal.misseis_max(),
		"caixas das forjas: a de conserto apagou os acertos e a de munição encheu os lançadores (%d pegas)" % fd.caixas_pegas)
	# a espada de laser: R3 no chão dá um golpe em arco que alterna de lado e esquenta a mecha à frente,
	# mas não a que está atrás
	_zerar()
	a.teleportar(lugar, Armadura.Estado.CHAO)
	cam.yaw = 0.0
	cam.pitch = 0.0
	await _esperar(0.4)
	var me1 := Mecha.new()
	var me2 := Mecha.new()
	for par in [[me1, Vector3(0, 0, -3.0)], [me2, Vector3(0, 0, 3.2)]]:
		var mx: Mecha = par[0]
		mx.mapa = v
		mx.casa = lugar + (par[1] as Vector3)
		mx.semente = 33
		m.add_child(mx)
		mx.global_position = mx.casa
		mx.pose_foto = 0
	await _esperar(0.3)
	var lado0: float = a.espada_lado
	await _apertar("espada")
	await _esperar(0.1)
	var acesa: bool = a.espada_t > 0.0 and a.espada_lado == -lado0
	await _esperar(0.5)
	await _apertar("espada")
	await _esperar(0.15)
	_ok(acesa and m.tiro.golpes_espada == 2 and a.espada_lado == lado0 and me1.calor > 30.0 and me2.calor == 0.0 and a.calor < 1.0,
		"espada: dois golpes, um de cada lado; a mecha da frente esquentou (%.0f), a de trás não, e o motor do robô não aqueceu" % me1.calor)
	me1.queue_free()
	me2.queue_free()
	await _esperar(0.5)
	# chegando à base, no chão, munição e vida voltam
	Arsenal.granadas = 0
	Arsenal.misseis = 1
	a.avaria = 2
	var bb := BaseVale.boca_cilindro
	a.teleportar(Vector3(bb.x + 8.0, v.altura(bb.x + 8.0, bb.z + 5.0) + 0.4, bb.z + 5.0), Armadura.Estado.CHAO)
	await _esperar(0.5)
	_ok(Arsenal.granadas == Arsenal.granadas_max() and Arsenal.misseis == Arsenal.misseis_max() and a.avaria == 0 and m.oficina.recargas >= 1,
		"chegando à base no chão, munição e vida são recarregadas")
	a.teleportar(lugar, Armadura.Estado.CHAO)
	await _esperar(0.3)
	# a roda: abre em câmera lenta, o analógico direito escolhe e soltar troca
	roda.trocar("pistola")
	Input.action_press("roda")
	await get_tree().process_frame
	await get_tree().process_frame
	var abriu: bool = RodaArmas.aberta and Engine.time_scale < 0.5 and CameraVoo.travada
	Input.action_press("olhar_direita")
	for k in 4:
		await get_tree().process_frame
	var apontou: String = roda.escolha
	Input.action_release("olhar_direita")
	Input.action_release("roda")
	for k in 3:
		await get_tree().process_frame
	_ok(abriu and not RodaArmas.aberta and Engine.time_scale == 1.0 and not CameraVoo.travada and Arsenal.modo == apontou and apontou != "pistola",
		"a roda abre em câmera lenta, o analógico escolhe e soltar troca (%s)" % Arsenal.modo)
	Arsenal.modo = "pistola"
	_zerar()
