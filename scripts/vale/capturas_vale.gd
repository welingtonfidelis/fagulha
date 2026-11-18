extends Node
## `godot --path . -- --vale-captura`: fotos do quadro da clareira em tools/capturas/vale/.

var m: Node
var a: Armadura
var cam: CameraVoo
var c: Clareira
var pasta := ""


func rodar(main: Node) -> void:
	m = main
	a = main.armadura
	cam = main.camera
	c = main.ilha
	var args := OS.get_cmdline_user_args()
	var sub := "vale"
	if "--pasta" in args and args.find("--pasta") + 1 < args.size():
		sub = args[args.find("--pasta") + 1]
	pasta = ProjectSettings.globalize_path("res://tools/capturas/" + sub + "/")
	DirAccess.make_dir_recursive_absolute(pasta)
	if "--curta" in args:
		await _curta()
		return
	if "--largo" in args:
		await _largo()
		return
	if "--mirando" in args:
		await _mirando()
		return
	if "--passada" in args:
		await _passada()
		return
	if "--posturas" in args:
		await _posturas()
		return
	if "--efeitos-tiro" in args:
		await _efeitos_tiro()
		return
	if "--mechas-tiro" in args:
		await _mechas_tiro()
		return
	if "--mechas" in args:
		await _mechas()
		return
	if "--plantas" in args:
		await _plantas()
		return
	if "--nado" in args:
		await _nado()
		return
	if "--levantar" in args:
		await _levantar()
		return
	if "--sonda-som" in args:
		await _sonda_som()
		return
	if "--perf" in args:
		await _perf()
		return
	if "--pausa" in args:
		await _esperar(2.5)
		m.pausa._abrir()
		get_tree().paused = false
		await _esperar(0.5)
		await _foto("p1_pausa")
		m.pausa._botao_sair.grab_focus()
		m.pausa._sair()
		await _esperar(0.2)
		await _foto("p2_sair")
		m.pausa._abrir_ajustes()
		await _esperar(0.2)
		await _foto("p5_ajustes")
		m.pausa._fechar_ajustes()
		m.pausa._abrir_comandos()
		await _esperar(0.2)
		await _foto("p3_comandos")
		m.pausa._mostrar_aba(2)
		await _esperar(0.2)
		await _foto("p4_teclado")
		get_tree().quit()
		return
	if "--fisica" in args:
		await _fisica()
		return
	if "--ingreme" in args:
		# onde o chão sobe de uma vez perto da clareira (para achar paredões lisos)
		await _esperar(2.0)
		var v := c as Vale
		for k in range(-12, 13):
			var px := -80.0 + 0.39 * k * 5.0
			var pz := -78.0 + 0.92 * k * 5.0
			var perto := Vector2(999, 0)
			var qual := -1
			for ci in v._cursos.size():
				var r: Vector2 = (v._cursos[ci] as Vale.Curso).perto(px, pz, 190.0)
				if r.x < perto.x:
					perto = r
					qual = ci
			print("perfil %4d: (%.0f, %.0f) altura %.1f  fora %.1f  mistura %.2f  rio %d dist %.0f s %.0f de %.0f" % [k * 5, px, pz, v.altura(px, pz), v._fora(px, pz),
				smoothstep(Vale.BORDA_DE, Vale.BORDA_ATE, maxf(absf(px), absf(pz))), qual, perto.x, perto.y, (v._cursos[maxi(qual, 0)] as Vale.Curso).total()])
		for zi in range(-40, 41):
			var linha := ""
			for xi in range(-40, 41):
				var x := xi * 8.0
				var z := zi * 8.0
				var h := c.altura(x, z)
				var d := 0.0
				for o in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
					d = maxf(d, absf(c.altura(x + o.x, z + o.y) - h))
				linha += "#" if d > 7.0 else ("+" if d > 4.0 else ("o" if xi == 0 and zi == 0 else "."))
			print(linha)
		get_tree().quit()
		return
	if "--muro" in args:
		# o paredão a noroeste da clareira, de três lados
		await _esperar(2.5)
		a.recomecar()
		m.hud.visible = false
		var livre := Camera3D.new()
		m.add_child(livre)
		livre.fov = 60.0
		livre.make_current()
		var n := 0
		for par in [[Vector2(-50, -40), Vector2(-90, -85)], [Vector2(-120, -20), Vector2(-110, -70)], [Vector2(-20, -70), Vector2(-70, -95)], [Vector2(-110, -120), Vector2(-80, -80)]]:
			n += 1
			var de: Vector2 = par[0]
			var para: Vector2 = par[1]
			a.teleportar(Vector3(de.x, c.altura(de.x, de.y) + 0.3, de.y), Armadura.Estado.CHAO)
			await _esperar(0.8)
			livre.global_position = Vector3(de.x, c.altura(de.x, de.y) + 3.5, de.y)
			livre.look_at(Vector3(para.x, c.altura(para.x, para.y) + 1.0, para.y))
			await _esperar(0.5)
			await _foto("muro_%d" % n)
		get_tree().quit()
		return
	if "--luzes" in args:
		# à noite: o robô parado e voando, com a luz do peito apagada e acesa (`--luzes --hora 23`)
		await _esperar(2.5)
		a.recomecar()
		m.hud.visible = false
		var livre := Camera3D.new()
		m.add_child(livre)
		livre.fov = 50.0
		livre.make_current()
		var campo := Vector3(-30, 0, 46)
		a.teleportar(Vector3(campo.x, c.altura(campo.x, campo.z) + 0.3, campo.z), Armadura.Estado.CHAO)
		await _esperar(1.0)
		for aceso in [false, true]:
			a.luz_ligada = aceso
			await _esperar(0.4)
			var fr := -a.visual.global_basis.z.normalized()
			livre.global_position = a.global_position - fr * 4.2 + Vector3(1.6, 2.0, 0)
			livre.look_at(a.global_position + fr * 3.0 + Vector3(0, 0.4, 0))
			await _foto("l_chao_%d" % int(aceso))
		a.luz_ligada = false
		a.teleportar(Vector3(campo.x, c.altura(campo.x, campo.z) + 14.0, campo.z), Armadura.Estado.VOO, Vector3(10, 0, -10))
		for k in 3:
			await _esperar(0.5)
			var vel := a.velocity.normalized()
			livre.global_position = a.pos_suave() - vel * 2.6 + Vector3(0, 0.9, 0)
			livre.look_at(a.pos_suave() + Vector3(0, 0.7, 0))
			await _foto("l_voo_%d" % k)
		get_tree().quit()
		return
	if "--pecas" in args:
		# onde cada peça ficou, com o que há por cima e por baixo, e uma foto de cada (`--pecas --basico`)
		await _esperar(2.5)
		a.recomecar()
		m.hud.visible = false
		Melhorias.tudo = false
		m.pecas.repor()
		var livre := Camera3D.new()
		m.add_child(livre)
		livre.fov = 55.0
		livre.make_current()
		var so := ""
		for arg in args:
			if arg.begins_with("--so="):
				so = arg.substr(5)
		for nome: String in m.pecas.onde:
			var p: Vector3 = m.pecas.onde[nome]
			var esp := a.get_world_3d().direct_space_state
			var cima := esp.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p + Vector3(0, 80, 0), 1))
			var baixo := esp.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 60.0, 0), p + Vector3(0, -60, 0), 1))
			print("peca %s: (%.0f, %.1f, %.0f) altura %.1f  teto %s  primeiro chão vindo de cima %s" % [nome, p.x, p.y, p.z, c.altura(p.x, p.z),
				("%.1f" % cima["position"].y) if not cima.is_empty() else "nenhum", ("%.1f" % baixo["position"].y) if not baixo.is_empty() else "nenhum"])
			if so != "" and so != nome:
				continue
			# a câmera olha do lado do meio da caverna quando a peça está lá dentro
			var lado := Vector3(7.5, 3.2, 6.0)
			if nome == "farol" and Sumidouro.existe:
				var meio := Vector3(Sumidouro.centro.x, p.y, Sumidouro.centro.y)
				lado = (meio - p).normalized() * 7.0 + Vector3(0, 2.4, 0)
			a.teleportar(p + lado * 0.5 + Vector3(0, -lado.y * 0.5 + 0.4, 0), Armadura.Estado.CHAO)
			await _esperar(0.8)
			livre.global_position = p + lado
			livre.look_at(p + Vector3(0, 0.9, 0))
			await _esperar(0.4)
			await _foto("peca_" + nome)
		if Sumidouro.existe:
			print("sumidouro: centro %s piso %.1f" % [Sumidouro.centro, Sumidouro.piso])
		get_tree().quit()
		return
	if "--mapa" in args:
		await _mapa()
		return
	if "--capa" in args:
		await _capa()
		return
	if "--capim" in args:
		# o campo de capim visto de perto ao longe: a borda onde as touceiras acabam (`--capim --hora 12`)
		await _esperar(2.5)
		a.recomecar()
		m.hud.visible = false
		var livre := Camera3D.new()
		m.add_child(livre)
		livre.fov = 70.0
		livre.far = 4000.0
		livre.make_current()
		var vistas := [["a_sul_chao", Vector3(-100, 2.2, 500), Vector3(100, -6, 700)], ["b_sul_12m", Vector3(-100, 12, 500), Vector3(100, -30, 700)],
			["c_sul_40m", Vector3(-100, 40, 500), Vector3(100, -60, 700)], ["d_base_campo", Vector3(2, 2.5, 46), Vector3(120, 0, 260)],
			["e_plato", Vector3(640, 2.2, 120), Vector3(700, 0, 60)], ["f_sul_100m", Vector3(-100, 100, 500), Vector3(100, -40, 700)]]
		for vista: Array in vistas:
			var de: Vector3 = vista[1]
			var chao := c.altura(de.x, de.z)
			a.teleportar(Vector3(de.x, chao + 0.3, de.z), Armadura.Estado.CHAO)
			a.visual.visible = false
			livre.global_position = Vector3(de.x, chao + de.y, de.z)
			livre.look_at(Vector3(vista[2].x, chao + vista[2].y, vista[2].z))
			await _esperar(4.0)
			await _foto(vista[0])
		get_tree().quit()
		return
	if "--terreno" in args:
		# alturas em volta de pontos candidatos (para escolher o lugar de uma obra grande)
		await _esperar(2.0)
		var v := c as Vale
		print("cume %s" % v.cume)
		# perfis norte-sul em volta da serra: o chão original (sem a cratera), de 20 em 20 m
		for x: float in [-700.0, -640.0, -580.0, -520.0, -460.0, -400.0]:
			var linha := "perfil x=%d:" % int(x)
			var z := -560.0
			while z <= -200.0:
				linha += " %d" % int(Cavernas.chao_antes(x, z))
				z += 20.0
			print(linha)
		print("agua perto: %s %s %s" % [c.agua(-580, -360) > -INF, c.agua(-520, -340) > -INF, c.agua(-640, -340) > -INF])
		get_tree().quit()
		return
	if "--fundicao" in args:
		# o galpão por dentro e de cima, e uma onda saindo da porta (`--fundicao --hora 12`)
		await _esperar(2.5)
		a.recomecar()
		var f: Fundicao = m.fundicao
		var livre := Camera3D.new()
		m.add_child(livre)
		livre.fov = 62.0
		livre.make_current()
		a.teleportar(Fundicao.aqui(8.0, 0.4, 20.0), Armadura.Estado.CHAO)
		m.hud.visible = false
		await _esperar(1.5)
		var n := 0
		for par in [[Fundicao.aqui(46, 16.0, 118), Fundicao.aqui(0, 11.0, 0)], [Fundicao.aqui(105, 30.0, 70), Fundicao.aqui(10, 10.0, -8)],
				[Fundicao.aqui(14, 4.0, 34), Fundicao.aqui(-4, 6.0, -38)], [Fundicao.aqui(0, 110.0, 80), Fundicao.aqui(0, 0, -10)],
				[Fundicao.aqui(-22, 6.0, 20), Fundicao.aqui(30, 5.0, -20)]]:
			n += 1
			livre.global_position = par[0]
			livre.look_at(par[1])
			await _esperar(0.5)
			await _foto("g%d" % n)
		livre.global_position = Fundicao.aqui(9, 3.0, -14)
		livre.look_at(Fundicao.aqui(0, 4.5, -38))
		await _esperar(0.3)
		await _foto("g6_porta")
		f.ligar()
		await _esperar(Fundicao.T_CONTAGEM + 5.0)
		await _foto("g7_saindo")
		await _esperar(3.5)
		await _foto("g8_fora")
		# a bússola com a caveira, de longe
		cam.cam.make_current()
		m.hud.visible = true
		a.teleportar(Vector3(-560.0, c.altura(-560.0, 200.0) + 0.4, 200.0), Armadura.Estado.CHAO)
		cam.yaw = PI * 0.75
		cam.pitch = 0.0
		await _esperar(1.2)
		await _foto("g9_bussola")
		get_tree().quit()
		return
	if "--armas" in args:
		# as armas no corpo do robô, a roda, o arco da granada e a trava dos mísseis (`--armas --hora 12`)
		await _esperar(2.5)
		a.recomecar()
		a.teleportar(Vector3(-30.0, c.altura(-30.0, 60.0) + 0.4, 60.0), Armadura.Estado.CHAO)
		Arsenal.tudo = false
		Arsenal.fabricados = ["rajada", "canhao", "precisao", "duplo", "misseis", "granadas"]
		Arsenal.repor_granadas()
		var roda: RodaArmas = m.get_node("RodaArmas")
		var livre := Camera3D.new()
		m.add_child(livre)
		livre.fov = 34.0
		await _esperar(1.0)
		m.hud.visible = false
		livre.make_current()
		for nome: String in ["pistola", "rajada", "canhao", "precisao", "duplo"]:
			Arsenal.modo = "x"
			roda.trocar(nome)
			a.visual.vestir_melhorias()
			await _esperar(0.4)
			var fr := -a.visual.global_basis.z.normalized()
			var lado := a.visual.global_basis.x.normalized()
			livre.global_position = a.global_position + fr * 2.3 + lado * 1.5 + Vector3(0, 0.8, 0)
			livre.look_at(a.global_position + Vector3(0, 0.62, 0))
			await _foto("b_" + nome)
		var fr2 := -a.visual.global_basis.z.normalized()
		livre.global_position = a.global_position - fr2 * 2.6 + Vector3(0.9, 1.3, 0)
		livre.look_at(a.global_position + Vector3(0, 0.75, 0))
		await _esperar(0.2)
		await _foto("b_lancadores_costas")
		# três mechas à frente
		a.teleportar(Vector3(20.0, c.altura(20.0, -40.0) + 0.4, -40.0), Armadura.Estado.CHAO)
		cam.cam.make_current()
		m.hud.visible = true
		cam.yaw = 0.6
		cam.pitch = -0.12
		await _esperar(0.8)
		var fr3 := Vector3(-sin(cam.yaw), 0, -cos(cam.yaw))
		var lado3 := Vector3(fr3.z, 0, -fr3.x)
		for i in 3:
			var mc := Mecha.new()
			mc.mapa = c
			mc.casa = a.global_position + fr3 * (22.0 + i * 5.0) + lado3 * (i - 1) * 7.0
			mc.casa.y = c.altura(mc.casa.x, mc.casa.z)
			mc.semente = 40 + i
			m.add_child(mc)
			mc.global_position = mc.casa
			mc.pose_foto = 0
		await _esperar(0.5)
		Input.action_press("granada")
		await _esperar(0.6)
		await _foto("b_arco_granada")
		Input.action_release("granada")
		await _esperar(0.45)
		livre.fov = 55.0
		livre.global_position = a.global_position + lado3 * 9.0 + Vector3(0, 2.5, 0) + fr3 * 4.0
		livre.look_at(a.global_position + fr3 * 6.0 + Vector3(0, 4.0, 0))
		livre.make_current()
		m.hud.visible = false
		await _foto("b_granada_voando")
		var antes_g: int = m.tiro._granadas.size()
		for espera in 60:
			await _esperar(0.05)
			if m.tiro._granadas.size() < antes_g:
				break
		livre.global_position = a.global_position + lado3 * 12.0 + Vector3(0, 4.0, 0) + fr3 * 14.0
		livre.look_at(a.global_position + fr3 * 24.0 + Vector3(0, 2.0, 0))
		await _foto("b_estouro_1")
		await _esperar(0.22)
		await _foto("b_estouro_2")
		await _esperar(0.8)
		await _foto("b_estouro_3")
		await _esperar(1.5)
		cam.cam.make_current()
		m.hud.visible = true
		roda.trocar("misseis")
		await _esperar(0.6)
		Input.action_press("atirar")
		await _esperar(1.3)
		await _foto("b_misseis_travando")
		Input.action_release("atirar")
		await _esperar(0.42)
		livre.make_current()
		m.hud.visible = false
		await _foto("b_misseis_subindo")
		await _esperar(0.45)
		livre.global_position = a.global_position + lado3 * 16.0 + Vector3(0, 5.0, 0) + fr3 * 10.0
		livre.look_at(a.global_position + fr3 * 14.0 + Vector3(0, 6.0, 0))
		await _foto("b_misseis_virando")
		get_tree().quit()
		return
	if "--chefes" in args:
		# as máquinas de pacote ao lado do robô, e o laser de cada arma (`--chefes --hora 12`)
		await _esperar(2.5)
		a.recomecar()
		var lugar := Vector3(20.0, c.altura(20.0, -40.0) + 0.4, -40.0)
		a.teleportar(lugar, Armadura.Estado.CHAO)
		m.hud.visible = false
		var livre := Camera3D.new()
		m.add_child(livre)
		livre.fov = 50.0
		livre.make_current()
		var maqs := []
		var k := 0
		for tipo: String in ["quadshell", "trilobite", "stan"]:
			var mp := MaquinaPacote.new()
			mp.tipo = tipo
			mp.mapa = c
			mp.casa = lugar + Vector3(4.0 + k * 5.0, 0, -6.0)
			mp.casa.y = c.altura(mp.casa.x, mp.casa.z)
			mp.semente = 5 + k
			m.add_child(mp)
			mp.global_position = mp.casa
			mp.rotation.y = PI
			mp.pose_foto = 0
			maqs.append(mp)
			k += 1
		await _esperar(1.0)
		livre.global_position = lugar + Vector3(8.0, 3.2, 10.0)
		livre.look_at(lugar + Vector3(8.0, 1.8, -6.0))
		await _foto("c1_maquinas")
		for mp in maqs:
			mp.mech.tocar("Shoot", 1.0, 0.05)
		await _esperar(0.35)
		await _foto("c2_atacando")
		for mp in maqs:
			mp.desligar()
		await _esperar(2.2)
		await _foto("c3_desligadas")
		for mp in maqs:
			mp.queue_free()
		# o laser de cada arma, de lado
		Arsenal.tudo = true
		var roda: RodaArmas = m.get_node("RodaArmas")
		cam.yaw = PI * 0.5
		cam.pitch = 0.0
		await _esperar(0.5)
		for nome: String in ["pistola", "rajada", "canhao", "precisao"]:
			Arsenal.modo = "x"
			roda.trocar(nome)
			a.calor = 0.0
			await _esperar(0.5)
			livre.global_position = a.global_position + Vector3(-6.0, 3.4, 9.0)
			livre.look_at(a.global_position + Vector3(-6.0, 1.2, 0))
			Input.action_press("atirar")
			await _esperar(1.15 if nome == "canhao" else 0.05)
			Input.action_release("atirar")
			await _esperar(0.1 if nome == "canhao" else 0.03)
			await _foto("c4_laser_" + nome)
			await _esperar(0.8)
		get_tree().quit()
		return
	if "--aura" in args:
		# a aura de subir de nível, em três momentos (`--aura --hora 19`)
		await _esperar(2.5)
		a.recomecar()
		a.teleportar(Vector3(-52.0, c.altura(-52.0, 44.0) + 0.4, 44.0) + Vector3(6, 0, 6), Armadura.Estado.CHAO)
		m.hud.visible = false
		var livre := Camera3D.new()
		m.add_child(livre)
		livre.fov = 40.0
		livre.make_current()
		await _esperar(1.0)
		livre.global_position = a.global_position + Vector3(3.4, 2.2, 4.0)
		livre.look_at(a.global_position + Vector3(0, 1.1, 0))
		EfeitosTiro.aura_nivel(a, a.altura_corpo())
		for k in 3:
			await _esperar([0.3, 0.6, 0.8][k])
			await _foto("aura_%d" % k)
		get_tree().quit()
		return
	if "--espada" in args:
		# o golpe de espada em três momentos, com uma mecha na frente (`--espada --hora 12`)
		await _esperar(2.5)
		a.recomecar()
		var lugar := Vector3(20.0, c.altura(20.0, -40.0) + 0.4, -40.0)
		a.teleportar(lugar, Armadura.Estado.CHAO)
		cam.yaw = 0.0
		cam.pitch = 0.0
		m.hud.visible = false
		var mx := Mecha.new()
		mx.mapa = c
		mx.casa = lugar + Vector3(0, 0, -3.2)
		mx.semente = 33
		m.add_child(mx)
		mx.global_position = mx.casa
		mx.rotation.y = PI
		mx.pose_foto = 0
		var livre := Camera3D.new()
		m.add_child(livre)
		livre.fov = 45.0
		livre.global_position = lugar + Vector3(3.6, 2.6, 3.4)
		livre.look_at(lugar + Vector3(0, 0.9, -1.4))
		livre.make_current()
		await _esperar(1.0)
		for k in 2:
			Input.action_press("espada")
			await _esperar(0.1)
			Input.action_release("espada")
			await _foto("e%d_a" % k)
			await _esperar(0.1)
			await _foto("e%d_b" % k)
			await _esperar(0.6)
		get_tree().quit()
		return
	if "--resumo" in args:
		# o cartão de fim de rodada da Fundição (`--resumo --hora 12`)
		await _esperar(2.5)
		a.recomecar()
		a.teleportar(Fundicao.aqui(60.0, 0.0, 60.0) + Vector3(0, 1.0, 0), Armadura.Estado.CHAO)
		await _esperar(1.0)
		m.hud.mostrar_resumo("Fundição desligada", [["Ondas vencidas", "6"], ["Recorde", "onda 6 · novo"], ["Robôs desligados", "31"], ["Experiência", "+412 · nível 4"],
			["Materiais", "sucata +38 · núcleos +3 · chips +1"], ["Recomeça na", "onda 6"]], true)
		m.hud.placar = "Onda 7"
		m.hud.placar_total = 9
		m.hud.placar_restam = 4
		await _esperar(1.0)
		await _foto("resumo")
		get_tree().quit()
		return
	if "--hud" in args:
		# a tela limpa em quatro situações (`--hud --hora 12`)
		await _esperar(2.5)
		a.recomecar()
		Arsenal.tudo = false
		Arsenal.fabricados = ["rajada", "canhao", "granadas", "misseis", "escudo"]
		Arsenal.repor_granadas()
		a.teleportar(Vector3(20.0, c.altura(20.0, -40.0) + 0.4, -40.0), Armadura.Estado.CHAO)
		cam.yaw = 0.6
		cam.pitch = -0.08
		await _esperar(3.5)
		await _foto("h1_andando")
		a.calor = 55.0
		a.avaria = 1
		a.escudo_t = 9.0
		Input.action_press("granada")
		await _esperar(0.2)
		Input.action_release("granada")
		await _esperar(0.5)
		Input.action_press("mirar")
		await _esperar(0.5)
		Input.action_press("atirar")
		await _esperar(0.05)
		Input.action_release("atirar")
		await _esperar(0.25)
		await _foto("h2_mirando_quente")
		Input.action_release("mirar")
		a.avaria = 0
		a.teleportar(a.global_position + Vector3(0, 30.0, 0), Armadura.Estado.VOO, Vector3(8, 0, -14))
		cam.pitch = -0.15
		a.calor = 30.0
		await _esperar(1.2)
		await _foto("h3_voando")
		a.calor = 100.0
		a.superaquecido = true
		await _esperar(0.3)
		await _foto("h4_superaquecido")
		get_tree().quit()
		return
	if "--menus" in args:
		# a roda de armas, a faixa do toque, a oficina nas três abas e a pausa (`--menus --basico --hora 12`)
		await _esperar(2.5)
		a.recomecar()
		Melhorias.tudo = false
		Arsenal.tudo = false
		Arsenal.xp = 420
		Arsenal.sucata = 34
		Arsenal.nucleos = 2
		Arsenal.fabricados = ["rajada", "canhao", "precisao", "mira"]
		for nome: String in ["antena", "radiador", "asas"]:
			Melhorias.achar(nome)
		Melhorias.instalar("antena")
		a.visual.vestir_melhorias()
		a.teleportar(Vector3(20.0, c.altura(20.0, -40.0) + 0.4, -40.0), Armadura.Estado.CHAO)
		var roda: RodaArmas = m.get_node("RodaArmas")
		await _esperar(1.0)
		roda.proxima()
		await _esperar(0.3)
		await _foto("n1_faixa")
		await _esperar(2.2)
		Input.action_press("roda")
		await _esperar(0.5)
		Input.action_press("olhar_direita")
		Input.action_press("olhar_baixo")
		await _esperar(0.3)
		await _foto("n2_roda")
		Input.action_release("olhar_direita")
		Input.action_release("olhar_baixo")
		Input.action_release("roda")
		await _esperar(0.5)
		var of: Oficina = m.oficina
		var b := BaseVale.boca_cilindro
		var fora := b + of._eixo() * 0.6
		a.teleportar(Vector3(fora.x, c.altura(fora.x, fora.z) + 0.4, fora.z), Armadura.Estado.CHAO)
		await _esperar(0.6)
		of.entrar()
		await _esperar(2.8)
		await _foto("n3_oficina_pecas")
		of._mudar_aba(1)
		await _esperar(0.4)
		await _foto("n4_oficina_armas")
		of._mudar_aba(1)
		await _esperar(0.4)
		await _foto("n5_oficina_defesa")
		of.sair()
		await _esperar(2.0)
		m.pausa._abrir()
		get_tree().paused = false
		await _esperar(0.5)
		await _foto("n6_pausa")
		m.pausa._abrir_comandos()
		await _esperar(0.3)
		await _foto("n7_comandos")
		get_tree().quit()
		return
	if "--oficina" in args:
		await _oficina()
		return
	if "--scanner" in args:
		await _scanner()
		return
	if "--melhorias" in args:
		await _melhorias()
		return
	if "--resgate" in args:
		await _resgate()
		return
	if "--troca" in args:
		await _troca()
		return
	if "--furos" in args:
		await _furos()
		return
	if "--sumidouro" in args:
		await _sumidouro()
		return
	if "--cavernas" in args:
		await _cavernas()
		return
	if "--vida" in args:
		await _vida()
		return
	if "--base" in args:
		await _base()
		return
	if "--pouso" in args:
		await _pouso()
		return
	if "--bichos" in args:
		await _bichos()
		return
	if "--cervo" in args:
		await _cervo()
		return
	if "--efeitos" in args:
		await _efeitos()
		return
	await _esperar(2.5)
	a.recomecar()
	cam.pitch = -0.06
	await _esperar(2.5)
	await _foto("q01_chegada")
	# de frente para o robô
	cam.yaw = c.spawn_yaw + PI * 0.92
	cam.pitch = -0.02
	await _esperar(1.2)
	await _foto("q02_robo_de_frente")
	cam.yaw = c.spawn_yaw
	# correndo pelo capim
	Input.action_press("frente")
	Input.action_press("correr")
	await _esperar(1.6)
	await _foto("q03_correndo")
	Input.action_release("frente")
	Input.action_release("correr")
	# na beira da lagoa
	_por(Vector3(24, 0, 4), Vector3(Clareira.LAGOA.x, 0, Clareira.LAGOA.y), -0.1)
	await _esperar(2.0)
	await _foto("q04_lagoa")
	# um cervo no campo
	var alvo_c: Node3D = null
	for n in m.get_children():
		if n is Cervo:
			alvo_c = n
			break
	var cv: Vector3 = alvo_c.global_position if alvo_c else c.cervos_em[0]
	_por(cv + Vector3(-5.5, 0, 4.5), cv, -0.04)
	await _esperar(0.5)
	await _foto("q04b_cervo")
	# em cima da pedra-mirante, olhando o campo
	var mi := Clareira.MIRANTE
	a.teleportar(Vector3(mi.x, c.altura(mi.x, mi.y) + 9.0, mi.y), Armadura.Estado.AR)
	_olhar(Vector3(mi.x, 0, mi.y), Vector3(20, 0, -5), -0.16)
	await _esperar(2.6)
	await _foto("q05_mirante")
	# voo baixo sobre o campo
	var de := Vector3(-34, c.altura(-34, 52) + 7.0, 52)
	var dir := (Vector3(30, 0, -20) - de)
	dir.y = 0.0
	dir = dir.normalized()
	cam.yaw = atan2(-dir.x, -dir.z)
	cam.pitch = -0.1
	a.calor = 10.0
	a.teleportar(de, Armadura.Estado.VOO, dir * 22.0)
	await _esperar(1.6)
	await _foto("q06_voo_baixo")
	# pairando alto, vendo a clareira inteira
	a.teleportar(Vector3(10, c.altura(10, 95) + 42.0, 95), Armadura.Estado.VOO, Vector3(0, 0, -6))
	cam.yaw = 0.0
	cam.pitch = -0.42
	Input.action_press("mirar")
	await _esperar(2.2)
	m.hud.medidor = true
	await _esperar(0.4)
	await _foto("q07_do_alto")
	Input.action_release("mirar")
	print("CAPTURAS DO VALE OK em ", pasta)
	get_tree().quit()


func _por(onde: Vector3, olhando: Vector3, pitch: float) -> void:
	a.teleportar(Vector3(onde.x, c.altura(onde.x, onde.z) + 0.3, onde.z), Armadura.Estado.CHAO)
	_olhar(onde, olhando, pitch)


func _olhar(de: Vector3, para: Vector3, pitch: float) -> void:
	var d := para - de
	cam.yaw = atan2(-d.x, -d.z)
	cam.pitch = pitch


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var tri := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	get_viewport().get_texture().get_image().save_png(pasta + nome + ".png")
	print("foto %s: %d fps, %.1f M triângulos" % [nome, fps, tri / 1e6])


## Três fotos só, para comparar as horas do dia (`--curta --hora N --pasta nome`).
func _curta() -> void:
	await _esperar(2.5)
	a.recomecar()
	cam.pitch = -0.02
	await _esperar(2.5)
	await _foto("a_chegada")
	_por(Vector3(24, 0, 4), Vector3(Clareira.LAGOA.x, 0, Clareira.LAGOA.y), 0.06)
	await _esperar(2.0)
	await _foto("b_lagoa")
	a.teleportar(Vector3(10, c.altura(10, 95) + 42.0, 95), Armadura.Estado.VOO, Vector3(0, 0, -6))
	cam.yaw = 0.0
	cam.pitch = -0.3
	Input.action_press("mirar")
	await _esperar(2.4)
	await _foto("c_do_alto")
	Input.action_release("mirar")
	get_tree().quit()


## Fotos dos efeitos: tiro, pouso de herói, copa atravessada e água (`--efeitos --pasta nome`).
func _efeitos() -> void:
	await _esperar(2.5)
	a.recomecar()
	await _esperar(2.0)
	# tiro mirando no chão
	cam.pitch = -0.16
	Input.action_press("mirar")
	await _esperar(0.8)
	Input.action_press("atirar")
	await _esperar(0.585)
	await _foto("e1_tiro")
	await _esperar(0.3)
	await _foto("e1b_tiro")
	Input.action_release("atirar")
	Input.action_release("mirar")
	# pouso de herói
	var p := c.spawn
	a.teleportar(p + Vector3(0, 20, 0), Armadura.Estado.AR)
	for i in 400:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.POUSO:
			break
	await _esperar(0.12)
	await _foto("e2_pouso_heroi")
	await _esperar(0.3)
	await _foto("e2b_pouso_heroi")
	await _esperar(1.5)
	# atravessando uma copa
	var alvo := -1
	for i in c.arv_pos.size():
		if c.arv_tipo[i] == 1 and c.arv_pos[i].distance_to(c.spawn) < 70.0:
			alvo = i
			break
	if alvo >= 0:
		var copa: Vector3 = c.arv_pos[alvo] + Vector3(0, 7.0 * c.arv_escala[alvo], 0)
		var dir := Vector3(0.6, 0, -0.8).normalized()
		cam.yaw = atan2(-dir.x, -dir.z)
		cam.pitch = 0.0
		a.calor = 5.0
		a.teleportar(copa - dir * 16.0, Armadura.Estado.VOO, dir * 20.0)
		await _esperar(0.95)
		await _foto("e3_copa")
		await _esperar(0.25)
		await _foto("e3b_copa")
	# pose de voo de perto, reta e em curva
	cam.pitch = -0.05
	a.calor = 5.0
	a.teleportar(Vector3(-30, c.altura(-30, 60) + 14.0, 60), Armadura.Estado.VOO, Vector3(0.7, 0, -0.7) * 22.0)
	cam.yaw = atan2(-0.7, 0.7)
	await _esperar(1.0)
	await _foto("e6_voo_reto")
	Input.action_press("direita")
	await _esperar(0.7)
	await _foto("e7_voo_curva")
	Input.action_release("direita")
	# rasante e mergulho na lagoa
	var l := Vector3(Clareira.LAGOA.x, Clareira.NIVEL, Clareira.LAGOA.y)
	var d2 := Vector3(1, 0, 0)
	cam.yaw = atan2(-d2.x, -d2.z)
	cam.pitch = -0.12
	a.calor = 5.0
	a.teleportar(l - d2 * 9.0 + Vector3(0, 1.6, 0), Armadura.Estado.VOO, d2 * 16.0)
	await _esperar(0.5)
	await _foto("e4_rasante")
	a.teleportar(l + Vector3(0, 7, 0), Armadura.Estado.AR)
	cam.pitch = -0.25
	for i in 300:
		await get_tree().physics_frame
		if a.na_agua:
			break
	await _esperar(0.15)
	await _foto("e5_mergulho")
	await _esperar(0.35)
	await _foto("e5b_mergulho")
	get_tree().quit()


## O cervo de perto, de lado e de frente, em cada estado (`--cervo --pasta nome`).
func _cervo() -> void:
	await _esperar(2.5)
	var cv: Node3D = null
	for n in m.get_children():
		if n is Cervo:
			cv = n
			break
	cv.global_position = Vector3(-14, 0, 50)
	cv.rotation.y = 0.0
	a.visual.visible = false
	for e in 4:
		cv.set("pose_foto", e)
		var lado := cv.global_position + Vector3(4.2, 0, 0.3)
		a.teleportar(Vector3(lado.x, c.altura(lado.x, lado.z) + 0.3, lado.z), Armadura.Estado.CHAO)
		_olhar(lado, cv.global_position, 0.02)
		await _esperar(1.6)
		await _foto("cervo_%d_lado" % e)
	cv.set("pose_foto", 0)
	var frente := cv.global_position + Vector3(2.2, 0, -3.4)
	a.teleportar(Vector3(frente.x, c.altura(frente.x, frente.z) + 0.3, frente.z), Armadura.Estado.CHAO)
	_olhar(frente, cv.global_position, 0.02)
	await _esperar(1.6)
	await _foto("cervo_4_frente")
	# os outros bichos do pacote, lado a lado: veado de galhada, raposa e lobo
	var k := 0
	for par: Array in [["stag", 1.55, Cervo], ["fox", 0.55, Raposa], ["wolf", 0.85, Lobo]]:
		var b: Cervo = (par[2] as GDScript).new()
		b.especie = par[0]
		b.altura_bicho = par[1]
		b.mapa = c
		b.casa = cv.global_position + Vector3(0, 0, 2.2 + k * 2.2)
		b.semente = 90 + k
		m.add_child(b)
		b.global_position = b.casa
		b.rotation.y = 0.0
		b.pose_foto = 2 if k == 0 else 0
		k += 1
	var de := cv.global_position + Vector3(7.5, 0, 3.4)
	a.teleportar(Vector3(de.x, c.altura(de.x, de.z) + 0.3, de.z), Armadura.Estado.CHAO)
	_olhar(de, cv.global_position + Vector3(0, 0, 3.4), 0.0)
	await _esperar(2.0)
	await _foto("cervo_5_todos")
	get_tree().quit()


## Pássaros, coelhos e peixes de perto (`--bichos --pasta nome`). A câmera é a do jogo, então o robô fica
## escondido e parado perto; os bichos não o veem (ameaca = null) até a foto da revoada.
func _bichos() -> void:
	await _esperar(2.5)
	a.visual.visible = false
	var bando: Node3D = null
	var coelho: Node3D = null
	var peixes: Node3D = null
	for n in m.get_children():
		if n is Passaros and bando == null:
			bando = n
		elif n is Coelho and coelho == null:
			coelho = n
		elif n is Peixes:
			peixes = n
	for n in m.get_children():
		if n is Passaros or n is Coelho or n is Peixes:
			n.set("ameaca", null)
	# pássaros no chão
	var pb: Vector3 = bando.posicoes()[0]
	var de := pb + Vector3(2.6, 0, 1.2)
	a.teleportar(Vector3(de.x, c.altura(de.x, de.z) + 0.3, de.z), Armadura.Estado.CHAO)
	_olhar(de, pb, -0.05)
	await _esperar(2.0)
	await _foto("b1_passaros_chao")
	# revoada: câmera solta, alta, para nenhum tronco tapar
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 40.0
	livre.global_position = pb + Vector3(7.0, 5.0, 7.0)
	livre.look_at(pb + Vector3(0, 1.0, 0))
	livre.make_current()
	await _esperar(0.6)
	await _foto("b2_revoada_antes")
	bando.call("assustar", pb + Vector3(3, 0, 0))
	for i in 4:
		await _esperar(0.45)
		var soma := Vector3.ZERO
		var ps: Array = bando.posicoes()
		for q: Vector3 in ps:
			soma += q
		livre.look_at(soma / ps.size())
		await _esperar(0.1)
		await _foto("b2_revoada_%d" % i)
	cam.cam.make_current()
	livre.queue_free()
	# coelho: parado, comendo, pulando
	for e in 3:
		coelho.set("pose_foto", e)
		var pc := coelho.global_position
		var dc := pc + Vector3(2.4, 0, 0.6)
		a.teleportar(Vector3(dc.x, c.altura(dc.x, dc.z) + 0.3, dc.z), Armadura.Estado.CHAO)
		_olhar(dc, pc, -0.05)
		await _esperar(1.5)
		await _foto("b4_coelho_%d" % e)
	# peixes vistos de cima
	var l := Vector3(Clareira.LAGOA.x, Clareira.NIVEL, Clareira.LAGOA.y)
	a.teleportar(l + Vector3(0, 3.2, 3.0), Armadura.Estado.VOO, Vector3(0, 0, -0.1))
	cam.yaw = 0.0
	cam.pitch = -0.9
	Input.action_press("mirar")
	await _esperar(1.6)
	await _foto("b5_peixes")
	Input.action_release("mirar")
	get_tree().quit()


## A chegada ao chão e os três pousos (`--pouso`): armando as pernas, toque, médio.
func _pouso() -> void:
	await _esperar(2.5)
	a.recomecar()
	await _esperar(1.5)
	cam.pitch = -0.05
	var p := c.spawn
	for par: Array in [[2.6, "toque"], [7.0, "medio"]]:
		a.teleportar(p + Vector3(0, par[0], 0), Armadura.Estado.AR)
		for i in 300:
			await get_tree().physics_frame
			if a.chegando_ao_chao() and a.altura_do_chao() < 0.9:
				break
		await _foto("p_%s_chegando" % par[1])
		for i in 300:
			await get_tree().physics_frame
			if a.estado == Armadura.Estado.POUSO:
				break
		await _esperar(0.1)
		await _foto("p_%s_pouso" % par[1])
		await _esperar(1.2)
	get_tree().quit()


## Cada caverna de fora (a boca), por dentro e de cima (`--cavernas`).
## A troca das árvores e das plantas por distância (`--troca`): a câmera avança sobre a mata e fotografa a
## cada 20 m (nenhum bloco pode aparecer ou sumir de uma vez), e mede o custo do quadro.
func _troca() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 62.0
	livre.far = 3000.0
	livre.make_current()
	var de := Vector3(-20, 0, -330)
	var rumo := Vector3(0.51, 0, -0.86).normalized()
	for k in 6:
		var p := de + rumo * 20.0 * k
		p.y = m.ilha.altura(p.x, p.z) + 30.0
		a.teleportar(Vector3(p.x, m.ilha.altura(p.x, p.z) + 0.3, p.z), Armadura.Estado.CHAO)
		livre.global_position = p
		livre.look_at(p + rumo * 100.0 + Vector3(0, -22.0, 0))
		await _esperar(0.5)
		await _foto("t%d" % k)
	for k in 3:
		var p := Vector3([40.0, 300.0, 140.0][k], 0, [-430.0, -300.0, -600.0][k])
		p.y = m.ilha.altura(p.x, p.z) + 3.0
		a.teleportar(Vector3(p.x, p.y - 2.7, p.z), Armadura.Estado.CHAO)
		livre.global_position = p
		livre.look_at(p + rumo * 100.0)
		await _esperar(1.0)
		var t0 := Time.get_ticks_usec()
		for q in 60:
			await get_tree().process_frame
		print("custo %d: %.1f ms por quadro, %d desenhos, %d mil triângulos" % [k, (Time.get_ticks_usec() - t0) / 60000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)])
		await _foto("chao%d" % k)
	get_tree().quit()


## O drone colega no posto e o resgate (`--resgate`): o robô desliga no campo, o drone chega por cima, a
## tela escurece e os dois reaparecem na base.
func _resgate() -> void:
	await _esperar(2.5)
	a.recomecar()
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 50.0
	livre.make_current()
	var dr: DroneColega = m.drone
	await _esperar(1.0)
	livre.global_position = dr.posto + Vector3(2.6, 0.3, -3.2)
	livre.look_at(dr.posto)
	await _esperar(0.4)
	await _foto("d1_no_posto")
	livre.global_position = dr.posto + Vector3(6.5, 1.5, -7.5)
	livre.look_at(dr.posto + Vector3(-2.0, -0.6, 1.0))
	await _esperar(0.3)
	await _foto("d2_posto_e_cilindro")
	var campo := Vector3(-20, 0, 20)
	campo.y = m.ilha.altura(campo.x, campo.z) + 0.3
	a.teleportar(campo, Armadura.Estado.CHAO)
	await _esperar(0.8)
	livre.global_position = campo + Vector3(4.5, 2.2, 5.5)
	livre.look_at(campo + Vector3(0, 1.6, 0))
	a.pane_forcada(campo)
	for k in 4:
		await _esperar([0.7, 0.6, 0.8, 0.5][k])
		await _foto("d%d_resgate" % (3 + k))
	await _esperar(Ajustes.PANE_TEMPO - 2.6 + 0.6)
	livre.global_position = a.global_position + Vector3(3.5, 2.0, -5.0)
	livre.look_at(a.global_position + Vector3(0, 1.6, 0))
	await _esperar(0.2)
	await _foto("d7_de_volta")
	await _esperar(2.2)
	await _foto("d8_drone_voltando")
	get_tree().quit()


## Conferência da física (`--fisica`): mede cada modelo de árvore contra a colisão que ela ganha.
func _fisica() -> void:
	await _esperar(1.5)
	var v: Vale = m.ilha
	print("FIS modelo | tronco raio | copa de..ate | copa raio | topo  (medidas do modelo na escala 1)")
	for nome: String in v._malhas:
		if nome.ends_with("_longe") or not (nome.contains("arvore") or nome.contains("carvalho") or nome.contains("betula") or nome.contains("pinheiro")):
			continue
		var pts := PackedVector3Array()
		for par in v._malhas[nome]:
			var mesh: Mesh = par[0]
			for sf in mesh.get_surface_count():
				for p: Vector3 in mesh.surface_get_arrays(sf)[Mesh.ARRAY_VERTEX]:
					pts.append((par[1] as Transform3D) * p)
		var topo := 0.0
		for p in pts:
			topo = maxf(topo, p.y)
		# raio por faixa de altura
		var faixas := PackedFloat32Array()
		faixas.resize(24)
		for p in pts:
			var k := clampi(int(p.y / topo * 24.0), 0, 23)
			faixas[k] = maxf(faixas[k], Vector2(p.x, p.z).length())
		var r_tronco := (faixas[1] + faixas[2]) * 0.5
		var copa_de := topo
		var r_copa := 0.0
		for k in 24:
			r_copa = maxf(r_copa, faixas[k])
		for k in range(2, 24):
			if faixas[k] > maxf(r_tronco * 2.2, r_copa * 0.45):
				copa_de = topo * k / 24.0
				break
		print("FIS %-22s | %.2f | %.1f..%.1f | %.1f | %.1f" % [nome, r_tronco, copa_de, topo, r_copa, topo])
		var linha := ""
		for k in 24:
			linha += "%.1f " % faixas[k]
		print("FISP   ", linha)
	get_tree().quit()


## Medição de desempenho (`--perf`): tempo de CPU e de placa por quadro em vários pontos, sem limite de
## quadros, e de novo com uma coisa desligada de cada vez (quanto cada uma custa).
func _perf() -> void:
	await _esperar(3.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := get_viewport()
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 70.0
	livre.far = 4000.0
	livre.make_current()
	var v: Vale = m.ilha
	print("PERF janela ", vp.size, " msaa ", vp.msaa_3d, " nós ", get_tree().get_node_count(), " memória MB ", int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		" vídeo MB ", int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0), " formas de colisão ", int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)))
	var medir := func(rotulo: String) -> void:
		for q in 20:
			await get_tree().process_frame
		var cpu := 0.0
		var gpu := 0.0
		var t0 := Time.get_ticks_usec()
		var n := 80
		for q in n:
			await get_tree().process_frame
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
		var total := (Time.get_ticks_usec() - t0) / 1000.0 / n
		print("PERF %-34s quadro %5.1f ms (%3d qps) | desenho CPU %4.1f | placa %5.1f | script %4.1f | física %4.1f | %4d desenhos | %5d mil tri | %5d objetos"
			% [rotulo, total, int(1000.0 / total), cpu / n, gpu / n, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	var pontos := [["base, olhando o campo", Vector3(2, 2.5, 46), Vector3(0, 1, 0)], ["campo da clareira, no chão", Vector3(-20, 1.6, 20), Vector3(30, 2, -20)],
		["mata fechada, no chão", Vector3(140, 1.6, -600), Vector3(100, 3, -640)], ["sobre a mata, a 60 m", Vector3(60, 60, -420), Vector3(200, 0, -700)],
		["platô das flores, no chão", Vector3(640, 1.6, 120), Vector3(700, 0, 60)], ["cachoeira e poço", Vector3(-268, 8, -440), Vector3(-300, 0, -512)],
		["do cume, vista inteira", Vector3(0, 0, 0), Vector3(0, 0, 0)], ["campos do sul", Vector3(-100, 1.6, 500), Vector3(100, 0, 700)],
		["no alto, 250 m, mapa inteiro", Vector3(0, 250, 300), Vector3(0, 0, -300)]]
	if "--so-base" in OS.get_cmdline_user_args():
		pontos = []
	for pt: Array in pontos:
		var de: Vector3 = pt[1]
		var para: Vector3 = pt[2]
		if String(pt[0]).begins_with("do cume"):
			de = v.cume + Vector3(0, 6, 0)
			para = Vector3(0, 20, 0)
		elif de.y < 20.0:
			de.y += v.altura(de.x, de.z)
			para.y += v.altura(para.x, para.z)
		a.teleportar(Vector3(de.x, v.altura(de.x, de.z) + 0.4, de.z), Armadura.Estado.CHAO)
		livre.global_position = de
		livre.look_at(para)
		await _esperar(1.2)
		await medir.call(pt[0])
	# quanto custa cada coisa: na mata fechada no chão e sobre a mata
	var casos := [["mata fechada, no chão", Vector3(140, 1.6, -600), Vector3(100, 3, -640)], ["sobre a mata, a 60 m", Vector3(60, 60, -420), Vector3(200, 0, -700)], ["base, olhando o campo", Vector3(2, 2.5, 46), Vector3(0, 1, 0)]]
	if "--so-base" in OS.get_cmdline_user_args():
		casos = [casos[2], ["campos do sul", Vector3(-100, 1.6, 500), Vector3(100, 0, 700)], casos[0]]
	for caso: Array in casos:
		var de: Vector3 = caso[1]
		var para: Vector3 = caso[2]
		if de.y < 20.0:
			de.y += v.altura(de.x, de.z)
			para.y += v.altura(para.x, para.z)
		a.teleportar(Vector3(de.x, v.altura(de.x, de.z) + 0.4, de.z), Armadura.Estado.CHAO)
		livre.global_position = de
		livre.look_at(para)
		await _esperar(1.2)
		print("PERF --- ", caso[0])
		for q: int in [0, 1, 2]:
			Qualidade.aplicar(m, q)
			await _esperar(0.3)
			await medir.call("  qualidade " + Qualidade.NOMES[q])
		await medir.call("  tudo ligado")
		var sol: DirectionalLight3D = null
		for n in m.find_children("*", "DirectionalLight3D", true, false):
			if (n as DirectionalLight3D).shadow_enabled:
				sol = n
		if sol:
			sol.shadow_enabled = false
			await medir.call("  sem sombras do sol")
			sol.shadow_enabled = true
		vp.msaa_3d = Viewport.MSAA_DISABLED
		await medir.call("  sem suavização (MSAA)")
		vp.msaa_3d = Viewport.MSAA_4X
		var capins := m.find_children("*", "CapimVivo", true, false)
		for n in capins:
			(n as Node3D).visible = false
		await medir.call("  sem capim vivo")
		for n in capins:
			(n as Node3D).visible = true
		var mms: Array = []
		for n in v.get_children():
			if n is MultiMeshInstance3D:
				mms.append(n)
		for n in mms:
			(n as Node3D).visible = false
		await medir.call("  sem árvores, plantas e rochas")
		for n in mms:
			(n as Node3D).visible = true
		var so_capim: Array = []
		for n in mms:
			if (n as MultiMeshInstance3D).multimesh.mesh == v.capim_malha:
				so_capim.append(n)
		for n in so_capim:
			(n as Node3D).visible = false
		await medir.call("  sem o capim fixo da clareira (%d blocos)" % so_capim.size())
		for n in so_capim:
			(n as Node3D).visible = true
		var kits := m.find_children("Kit_*", "Node3D", true, false)
		for n in kits:
			(n as Node3D).visible = false
		await medir.call("  sem as peças dos kits da base (%d)" % kits.size())
		for n in kits:
			(n as Node3D).visible = true
		for n in [m.vida, m.inimigos]:
			if n:
				(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
		await medir.call("  bichos e mechas parados")
		for n in [m.vida, m.inimigos]:
			if n:
				(n as Node).process_mode = Node.PROCESS_MODE_INHERIT
		vp.scaling_3d_scale = 0.7
		await medir.call("  resolução 3D a 70%")
		vp.scaling_3d_scale = 1.0
	get_tree().quit()


func _cavernas() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 62.0
	livre.make_current()
	# onde ficavam as grutas pequenas (tiradas em 2026-11-16): o chão tem de estar inteiro
	var k := 0
	for l: Array in [[Vector2(853, -111), Vector2(777, -91)], [Vector2(284, 17), Vector2(334, 71)], [Vector2(-493, -617), Vector2(-618, -626)],
			[Vector2(-211, -812), Vector2(-247, -770)], [Vector2(-384, -438), Vector2(-434, -469)], [Vector2(-668, -386), Vector2(-650, -435)]]:
		var pa: Vector2 = l[0]
		var pb: Vector2 = l[1]
		var d2 := (pb - pa).normalized()
		var dir := Vector3(d2.x, 0, d2.y)
		var c2 := (pa + pb) * 0.5
		var centro := Vector3(c2.x, m.ilha.altura(c2.x, c2.y), c2.y)
		a.teleportar(centro + Vector3(0, 0.3, 0), Armadura.Estado.CHAO)
		await _esperar(1.2)
		livre.global_position = centro + Vector3(0, 75, 0) - dir * 45.0
		livre.look_at(centro)
		await _esperar(0.4)
		await _foto("g%d_cima" % k)
		var ini := Vector3(pa.x, m.ilha.altura(pa.x, pa.y) + 4.0, pa.y) - dir * 12.0 + dir.cross(Vector3.UP) * 5.0
		livre.global_position = ini
		livre.look_at(centro + Vector3(0, 3, 0))
		await _esperar(0.4)
		await _foto("g%d_boca" % k)
		k += 1
	get_tree().quit()


## A vida fora da clareira (`--vida`): duas manadas, uma toca, um bando e o cardume do poço.
func _vida() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 38.0
	livre.make_current()
	var vistos := {}
	for l: Dictionary in m.vida.lugares:
		var tipo: String = l["tipo"]
		var limite := 3 if tipo == "cervo" else 1
		if int(vistos.get(tipo, 0)) >= limite:
			continue
		vistos[tipo] = int(vistos.get(tipo, 0)) + 1
		var p: Vector3 = l["pos"]
		var longe := p + Vector3(60, 0, 60)
		a.teleportar(Vector3(longe.x, c.altura(longe.x, longe.z) + 40.0, longe.z), Armadura.Estado.PAIRAR)
		Input.action_press("mirar")
		await _esperar(4.0)
		var dist := 16.0 if tipo == "cervo" else (9.0 if tipo == "peixe" else 6.0)
		var de := p + Vector3(dist, dist * 0.35, dist * 0.6)
		de.y = maxf(de.y, c.altura(de.x, de.z) + 1.2)
		livre.global_position = de
		livre.look_at(p + Vector3(0, 0.5, 0))
		await _esperar(0.5)
		await _foto("v_%s_%d" % [tipo, vistos[tipo]])
	Input.action_release("mirar")
	get_tree().quit()


## A base: o nascimento pela câmera do jogo, e a obra de frente, de lado, de cima e à noite (`--base`).
func _base() -> void:
	await _esperar(2.5)
	a.recomecar()
	await _esperar(2.0)
	await _foto("b1_nascimento")
	cam.yaw = c.spawn_yaw + PI
	cam.pitch = -0.1
	await _esperar(1.5)
	await _foto("b2_olhando_a_base")
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 50.0
	livre.make_current()
	var p := c.spawn
	var frente := Vector3(-sin(c.spawn_yaw), 0, -cos(c.spawn_yaw))
	var lado := frente.cross(Vector3.UP)
	var tl := Transform3D(Basis(Vector3.UP, Ruinas.BASE.z), Vector3(p.x, c.altura(p.x, p.z), p.z))
	for v: Array in [["b3_frente", Vector3(0, 4.5, -17), Vector3(0, 1.8, 2)], ["b4_cima", Vector3(-1, 24, -9), Vector3(-1, 0, 1.5)],
			["b5_cilindro", Vector3(-1.5, 2.6, -5.5), Vector3(-7.5, 2.0, 1.6)], ["b6_boca", Vector3(-2.2, 2.3, 1.2), Vector3(-9, 2.2, 1.6)],
			["b7_faisca", Vector3(0.4, 1.3, -0.6), Vector3(3.4, 0.6, -3.2)], ["b8_faisca_lado", Vector3(6.6, 1.0, -0.6), Vector3(3.4, 0.6, -3.2)],
			["b9_lado", Vector3(17, 5, -7), Vector3(0, 1.5, 2)], ["b10_tras", Vector3(3, 7, 17), Vector3(0, 1.5, 0)]]:
		livre.global_position = tl * (v[1] as Vector3)
		livre.look_at(tl * (v[2] as Vector3))
		await _esperar(0.3)
		await _foto(v[0])
	var fp := tl * Vector3(3.3, 0.3, -2.9)
	var ff := tl.basis * Vector3(sin(-0.81), 0, cos(-0.81))
	var fl := ff.cross(Vector3.UP)
	for v2: Array in [["f1_frente", ff * 2.2 + Vector3(0, 0.35, 0)], ["f2_lado", fl * 2.2 + Vector3(0, 0.2, 0)], ["f3_outro_lado", -fl * 2.2 + Vector3(0, 0.2, 0)], ["f4_cima", ff * 1.2 + Vector3(0, 2.6, 0)]]:
		livre.global_position = fp + v2[1]
		livre.look_at(fp)
		await _esperar(0.3)
		await _foto(v2[0])
	if m.ciclo:
		m.ciclo.hora = 22.0
		m.ciclo.parado = true
		await _esperar(1.5)
		livre.global_position = p + frente * 9.0 + lado * 3.0 + Vector3(0, 2.4, 0)
		livre.look_at(p + Vector3(0, 1.4, 0))
		await _esperar(0.5)
		await _foto("b11_noite")
	get_tree().quit()


## Abaixado, andando abaixado, sentado e a freada no ar (`--posturas`), com câmera solta e com a do jogo.
func _posturas() -> void:
	await _esperar(2.5)
	a.recomecar()
	var claro := Clareira.CLAROS[0]
	var capim := c.find_children("*", "MultiMeshInstance3D", true, false)
	for n in capim:
		(n as Node3D).visible = false
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 26.0
	livre.make_current()
	var chao := Vector3(claro.x, c.altura(claro.x, claro.y) + 0.2, claro.y)
	a.teleportar(chao, Armadura.Estado.CHAO)
	cam.yaw = PI * 0.5
	cam.pitch = 0.0
	await _esperar(0.8)
	var tirar := func(nome: String) -> void:
		var p: Vector3 = a.global_position + a.velocity * (1.0 / 60.0)
		for v: Array in [["lado", Vector3(0, 0.6, 4.6)], ["frente", Vector3(-3.6, 0.9, 2.6)]]:
			livre.global_position = p + v[1]
			livre.look_at(p + Vector3(0, 0.5, 0))
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(pasta + "%s_%s.png" % [nome, v[0]])
	await tirar.call("a_de_pe")
	Input.action_press("sentar")
	await _esperar(0.1)
	Input.action_release("sentar")
	await _esperar(0.8)
	await tirar.call("b_abaixado")
	Input.action_press("frente")
	await _esperar(1.0)
	await tirar.call("c_abaixado_andando")
	Input.action_release("frente")
	await _esperar(0.6)
	Input.action_press("sentar")
	await _esperar(0.1)
	Input.action_release("sentar")
	await _esperar(0.4)
	Input.action_press("sentar")
	await _esperar(1.0)
	Input.action_release("sentar")
	await _esperar(1.2)
	await tirar.call("d_sentado")
	# sentado, pela câmera do jogo, com o capim
	for n in capim:
		(n as Node3D).visible = true
	cam.cam.make_current()
	cam.yaw = PI * 0.5 + 0.5
	cam.pitch = -0.1
	await _esperar(1.5)
	await _foto("e_sentado_jogo")
	# freada: voando para -X, desliga os jatos
	livre.make_current()
	a.teleportar(chao + Vector3(40, 30, 0), Armadura.Estado.VOO, Vector3(-30, 0, 0))
	cam.yaw = PI * 0.5
	cam.pitch = 0.0
	await _esperar(0.6)
	Input.action_press("soltar")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("soltar")
	for q in 2:
		await _esperar(0.17)
		await tirar.call("f_freando_%d" % q)
	# mergulho com impacto: no ar e batendo
	await _esperar(2.0)
	a.teleportar(chao + Vector3(0, 26, 0), Armadura.Estado.VOO, Vector3(-18, 0, 0))
	await _esperar(0.3)
	Input.action_press("golpe")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("golpe")
	await _esperar(0.3)
	await tirar.call("j_mergulho")
	for i in 240:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.POUSO:
			break
	await _esperar(0.15)
	await tirar.call("k_impacto")
	if "--chuva" in OS.get_cmdline_user_args():
		# chuva no voo, pela câmera do jogo: voo reto, arrancada e parado no ar
		m.hud.visible = true
		cam.cam.make_current()
		a.calor = 0.0
		a.teleportar(chao + Vector3(300, 60, 0), Armadura.Estado.VOO, Vector3(-30, 0, 0))
		cam.pitch = -0.05
		await _esperar(2.5)
		await _foto("g_chuva_voo")
		Input.action_press("frente")
		await _esperar(2.0)
		await _foto("h_chuva_arrancada")
		Input.action_release("frente")
		Input.action_press("mirar")
		await _esperar(2.5)
		await _foto("i_chuva_parado")
		Input.action_release("mirar")
	get_tree().quit()


## A passada vista de lado, quadro a quadro (`--passada`): 8 fotos do andar e 8 da corrida.
func _passada() -> void:
	await _esperar(2.5)
	a.recomecar()
	var claro := Clareira.CLAROS[0]
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		(n as Node3D).visible = false  # sem capim nem árvores, para ver os pés
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 24.0
	livre.make_current()
	for modo: String in ["andar", "correr"]:
		a.teleportar(Vector3(claro.x + 3.0, c.altura(claro.x + 3.0, claro.y) + 0.2, claro.y), Armadura.Estado.CHAO)
		cam.yaw = PI * 0.5  # anda para -X
		cam.pitch = 0.0
		await _esperar(0.5)
		Input.action_press("frente")
		if modo == "correr":
			Input.action_press("correr")
		await _esperar(0.9)
		for i in 8:
			for q in (5 if modo == "andar" else 3):
				await get_tree().physics_frame
			# a câmera vai um quadro à frente do robô (a foto sai no quadro seguinte)
			var adiante: Vector3 = a.global_position + a.velocity * (1.0 / 60.0)
			livre.global_position = adiante + Vector3(0, 0.55, 5.2)
			livre.look_at(adiante + Vector3(0, 0.55, 0))
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(pasta + "%s_%d.png" % [modo, i])
		Input.action_release("frente")
		Input.action_release("correr")
		await _esperar(0.6)
	get_tree().quit()


## Andar atirando na diagonal, de lado e de costas, visto de cima e de frente (`--mirando`).
func _mirando() -> void:
	await _esperar(2.5)
	a.recomecar()
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		(n as Node3D).visible = false
	m.hud.visible = false
	var claro := Clareira.CLAROS[0]
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 22.0
	livre.make_current()
	for par: Array in [["frente", "direita", "diagonal"], ["direita", "", "lado"], ["tras", "", "costas"], ["tras", "esquerda", "diag_costas"]]:
		a.teleportar(Vector3(claro.x, c.altura(claro.x, claro.y) + 0.2, claro.y), Armadura.Estado.CHAO)
		cam.yaw = 0.0  # mira para -Z
		cam.pitch = 0.0
		await _esperar(0.4)
		Input.action_press(par[0])
		if par[1] != "":
			Input.action_press(par[1])
		for q in 54:
			a.atirando = 1.0  # braço em posição de tiro, sem o clarão do disparo
			await get_tree().physics_frame
		var adiante: Vector3 = a.global_position + a.velocity * (1.0 / 60.0)
		livre.global_position = adiante + Vector3(0.5, 3.4, -2.0)  # de cima e da frente
		livre.look_at(adiante + Vector3(0, 0.5, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta + "m_%s.png" % par[2])
		_soltar()
		await _esperar(0.5)
	get_tree().quit()


func _soltar() -> void:
	for ac in ["frente", "tras", "esquerda", "direita", "atirar", "mirar", "correr"]:
		Input.action_release(ac)


## O vale inteiro visto do alto e de alguns lugares (`--largo`), com câmera solta.
func _largo() -> void:
	await _esperar(3.0)
	a.recomecar()
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 60.0
	livre.far = 9000.0
	livre.make_current()
	var vistas := [
		["l1_do_alto_norte", Vector3(0, 330, 520), Vector3(0, 40, -300)],
		["l2_do_alto_leste", Vector3(-420, 300, 120), Vector3(500, 20, 120)],
		["l3_da_serra", Vector3(-640, 0, -700), Vector3(200, 20, 300)],
		["l4_praia", Vector3(250, 0, 800), Vector3(700, 10, 500)],
		["l5_borda_sul", Vector3(40, 0, 230), Vector3(0, 20, 0)],
		["f1_campo_sul", Vector3(-100, 0, 500), Vector3(100, 10, 700)],
		["f2_plato_flores", Vector3(640, 0, 120), Vector3(700, 36, 60)],
		["f3_plato_mar", Vector3(700, 0, 160), Vector3(900, 10, 300)],
		["f4_beira_rio", Vector3(262, 0, 392), Vector3(300, 6, 520)],
		["r1_saida_lagoa", Vector3(30, 0, 20), Vector3(100, 18, 100)],
		["r2_garganta", Vector3(150, 0, 200), Vector3(100, 20, 100)],
		["r3_rio_campo", Vector3(250, 0, 330), Vector3(300, 5, 520)],
		["r4_foz", Vector3(300, 0, 760), Vector3(350, 0, 900)],
		["r5_rio_do_alto", Vector3(120, 190, 420), Vector3(260, 5, 420)],
		["l6_campos_sul", Vector3(-100, 0, 500), Vector3(300, 0, 900)],
		["l7_mata_fechada", Vector3(120, 0, -560), Vector3(-200, 60, -500)],
		["l8_ruinas", Vector3(-560, 0, 420), Vector3(-700, 30, 250)],
	]
	if "--uma" in OS.get_cmdline_user_args():
		vistas = [vistas[0]]
	if "--serra" in OS.get_cmdline_user_args():
		var cm: Vector3 = (c as Vale).cume
		vistas = [["s1_cume_perto", Vector3(cm.x + 24, cm.y + 6, cm.z + 30), cm + Vector3(0, 6, 0)], ["s2_vista_do_cume", Vector3(cm.x, cm.y + 12, cm.z), Vector3(200, 20, 200)],
			["s3_cume_de_longe", Vector3(-250, 0, -250), cm]]
	if "--norte" in OS.get_cmdline_user_args():
		vistas = [["n1_cachoeira", Vector3(-268, 128, -440), Vector3(-300, 120, -512)], ["n2_poco", Vector3(-283, 0, -470), Vector3(-300, 124, -515)], ["n3_de_cima", Vector3(-316, 0, -540), Vector3(-270, 100, -430)], ["n4_riacho_mata", Vector3(-200, 0, -250), Vector3(-250, 80, -360)], ["n5_entrada_clareira", Vector3(-88, 0, -60), Vector3(-150, 34, -150)], ["n6_nascente", Vector3(-470, 0, -640), Vector3(-380, 170, -600)], ["n7_do_alto", Vector3(-120, 200, -300), Vector3(-300, 110, -500)]]
	if "--ruinas" in OS.get_cmdline_user_args():
		# [nome, lugar, de (na medida do lugar; y acima do chão dele), para onde olha]
		vistas = []
		for u: Array in [["u1_arcos", Ruinas.ARCOS, Vector3(-6, 5, 30), Vector3(0, 8, 0)], ["u2_arcos_baixo", Ruinas.ARCOS, Vector3(-30, 2.5, 7), Vector3(10, 9, -1)],
				["u3_arcos_alto", Ruinas.ARCOS, Vector3(-34, 30, 34), Vector3(4, 6, 0)],
				["u4_torre", Ruinas.TORRE, Vector3(-8, 4, 27), Vector3(5, 7, 0)], ["u5_torre_alto", Ruinas.TORRE, Vector3(30, 26, 24), Vector3(5, 5, 2)],
				["u6_torre_dentro", Ruinas.TORRE, Vector3(-2.6, 2.2, 2.4), Vector3(3, 10, -3)],
				["u7_patio", Ruinas.PATIO, Vector3(27, 5, 9), Vector3(0, 3, 0)], ["u8_patio_alto", Ruinas.PATIO, Vector3(-20, 24, 26), Vector3(0, 1, 0)],
				["u9_patio_berco", Ruinas.PATIO, Vector3(8.5, 3.4, 6.5), Vector3(0, 2.2, 0)]]:
			var lugar: Vector3 = u[1]
			var tl := Transform3D(Basis(Vector3.UP, lugar.z), Vector3(lugar.x, c.altura(lugar.x, lugar.y), lugar.y))
			vistas.append([u[0], tl * (u[2] as Vector3), tl * (u[3] as Vector3)])
	if "--paredes" in OS.get_cmdline_user_args():
		var cm2: Vector3 = (c as Vale).cume
		vistas = [["n1_cachoeira", Vector3(-268, 128, -440), Vector3(-300, 120, -512)], ["n2_poco", Vector3(-283, 0, -470), Vector3(-300, 124, -515)], ["p3_poco_lado", Vector3(-262, 0, -478), Vector3(-320, 122, -490)],
			["p4_serra_encosta", Vector3(cm2.x + 90, cm2.y - 20, cm2.z + 110), cm2 + Vector3(0, -15, 0)], ["r0_rio_inteiro", Vector3(-250, 620, 560), Vector3(230, 0, 430)], ["r3_rio_campo", Vector3(250, 0, 330), Vector3(300, 5, 520)]]
	if "--rio" in OS.get_cmdline_user_args():
		vistas = [["r0_rio_inteiro", Vector3(-250, 620, 560), Vector3(230, 0, 430)], ["r1_saida_lagoa", Vector3(30, 0, 20), Vector3(100, 18, 100)], ["r3_rio_campo", Vector3(250, 0, 330), Vector3(300, 5, 520)],
			["r5_rio_do_alto", Vector3(120, 190, 420), Vector3(260, 5, 420)], ["r6_riacho_norte_alto", Vector3(-60, 260, -200), Vector3(-230, 60, -330)], ["r4_foz", Vector3(300, 0, 760), Vector3(350, 0, 900)]]
	if "--borda" in OS.get_cmdline_user_args():
		vistas = [["b1_plato_de_fora", Vector3(1090, 12, 330), Vector3(1000, 15, 120)], ["b2_plato_rente", Vector3(1040, 6, 20), Vector3(1000, 12, 160)],
			["b3_norte_de_fora", Vector3(-200, 60, -1040), Vector3(-300, 40, -800)], ["b4_oeste_de_fora", Vector3(-1040, 50, -300), Vector3(-800, 30, -450)],
			["b5_canto", Vector3(-1030, 90, -1030), Vector3(-700, 30, -700)], ["b6_ilha_do_alto", Vector3(0, 1500, 700), Vector3(0, 0, 60)],
			["b7_costa_norte_rente", Vector3(-420, 0, -905), Vector3(-200, 30, -820)], ["b8_costa_oeste_rente", Vector3(-905, 0, 240), Vector3(-820, 20, 0)]]
	if "--marcos" in OS.get_cmdline_user_args():
		var am := Marcos.arvore_mae
		var an := Marcos.anel
		var co := Marcos.colunas
		vistas = [["m1_arvore_mae", am + Vector3(70, 14, 90), am + Vector3(0, 30, 0)], ["m2_arvore_de_baixo", am + Vector3(16, 2.5, 14), am + Vector3(0, 28, 0)],
			["m3_anel", an + Vector3(60, 0, 80), an + Vector3(0, 6, 0)], ["m4_anel_de_dentro", an + Vector3(-30, 8, -40), an + Vector3(30, 0, 40)],
			["m5_colunas", co + Vector3(80, 20, 90), co + Vector3(0, 30, 0)], ["m6_do_alto", Vector3(100, 320, 200), Vector3(300, 0, -100)]]
	if "--novas" in OS.get_cmdline_user_args():
		# as regiões da ilha de 3 km: do alto e do chão
		vistas = [["n01_ilha_do_alto", Vector3(0, 900, 1500), Vector3(0, 0, 100)], ["n02_cabo_do_alto", Vector3(700, 220, -700), Vector3(1250, 40, -1250)],
			["n03_cabo_do_mar", Vector3(1460, 30, -1100), Vector3(1250, 50, -1260)], ["n04_cabo_no_chao", Vector3(1100, 0, -1100), Vector3(1290, 70, -1280)],
			["n05_encostas_do_alto", Vector3(1300, 200, -100), Vector3(950, 30, -380)], ["n06_lagoa_da_represa", Vector3(800, 70, -420), Vector3(960, 30, -320)],
			["n07_corrego_de_baixo", Vector3(1230, 0, -260), Vector3(980, 40, -330)], ["n08_costa_quebrada_do_alto", Vector3(500, 220, 1150), Vector3(950, 0, 850)],
			["n09_baia_do_cais", Vector3(820, 0, 880), Vector3(960, 0, 1010)], ["n10_arquipelago", Vector3(1050, 60, 700), Vector3(1270, 5, 640)],
			["n11_ilhotas_do_alto", Vector3(1000, 260, 1300), Vector3(1280, 0, 900)], ["n12_chapada_do_alto", Vector3(-400, 240, 1350), Vector3(-830, 40, 1080)],
			["n13_fenda_de_cima", Vector3(-860, 110, 1010), Vector3(-830, 5, 1110)], ["n14_fenda_por_dentro", Vector3(-930, 0, 1030), Vector3(-800, 12, 1112)],
			["n15_saida_da_fenda", Vector3(-470, 14, 1360), Vector3(-640, 20, 1190)], ["n16_enseada_do_oeste", Vector3(-1050, 90, 250), Vector3(-1300, 0, 330)],
			["n17_costa_norte", Vector3(-100, 120, -1050), Vector3(-250, 0, -1350)], ["n18_foz_e_baia", Vector3(250, 90, 430), Vector3(360, 0, 900)],
			["n19_costa_antiga_leste", Vector3(760, 0, -600), Vector3(1000, 50, -600)], ["n20_costa_antiga_sul", Vector3(-800, 0, 820), Vector3(-800, 60, 1000)]]
	if "--marcos-leste" in OS.get_cmdline_user_args():
		# a represa, o farol e os gigantes: de longe, de perto e de cima
		var f := MarcosLeste.FAROL
		var g := MarcosLeste.GIGANTES
		vistas = [["m01_represa_da_lagoa", Vector3(1010, 40, -335), Vector3(1100, 26, -335)], ["m02_represa_de_baixo", Vector3(1170, 22, -300), Vector3(1100, 24, -332)],
			["m03_represa_do_alto", Vector3(1160, 90, -430), Vector3(1090, 20, -335)], ["m04_represa_no_passadico", Vector3(1101, 44.0, -378), Vector3(1096, 38, -330)],
			["m05_corrego_e_mar", Vector3(1110, 40, -335), Vector3(1260, 0, -300)], ["m06_farol_de_longe", Vector3(1150, 0, -1150), Vector3(f.x, 95, f.y)],
			["m07_farol_do_pe", Vector3(f.x - 22, 0, f.y + 22), Vector3(f.x, 95, f.y)], ["m08_farol_do_mar", Vector3(1470, 30, -1420), Vector3(f.x, 85, f.y)],
			["m09_farol_lanterna", Vector3(f.x - 14, 140, f.y + 16), Vector3(f.x + 3, 131, f.y - 3)], ["m10_farol_do_alto", Vector3(f.x - 60, 160, f.y + 80), Vector3(f.x, 80, f.y)],
			["m11_gigantes_de_longe", Vector3(g.x - 260, 80, g.y + 240), Vector3(g.x, 40, g.y)], ["m12_gigantes_do_chao", Vector3(g.x - 150, 0, g.y + 150), Vector3(g.x + 10, 50, g.y)],
			["m13_gigante_de_pe", Vector3(g.x + 120, 60, g.y + 70), Vector3(g.x + 44, 55, g.y + 6)], ["m14_gigante_deitado", Vector3(g.x - 130, 50, g.y - 110), Vector3(g.x - 70, 30, g.y - 40)],
			["m15_gigantes_de_cima", Vector3(g.x - 20, 260, g.y + 90), Vector3(g.x - 20, 30, g.y + 30)], ["m16_do_plato", Vector3(640, 60, 180), Vector3(g.x, 40, g.y)]]
	if "--marcos-mar" in OS.get_cmdline_user_args():
		# o cais, a ilha do relé e a ponte antiga
		var cc := MarcosMar.CAIS
		var rr := MarcosMar.RELE
		vistas = [["a01_cais_da_praia", Vector3(cc.x - 60, 14, cc.y - 30), Vector3(cc.x + 50, 6, cc.y + 20)], ["a02_cais_do_alto", Vector3(cc.x + 20, 90, cc.y - 110), Vector3(cc.x + 60, 0, cc.y + 25)],
			["a03_guindaste", Vector3(cc.x + 2, 9, cc.y + 34), Vector3(cc.x + 34, 16, cc.y + 12)], ["a04_cais_do_mar", Vector3(cc.x + 190, 16, cc.y + 90), Vector3(cc.x + 80, 6, cc.y + 30)],
			["a05_trechos_afundados", Vector3(cc.x + 60, 12, cc.y + 62), Vector3(cc.x + 82, 0, cc.y + 30)], ["a06_debaixo_dagua", Vector3(cc.x + 52, -3.5, cc.y + 44), Vector3(cc.x + 70, -6, cc.y + 30)],
			["a07_patio", Vector3(cc.x - 46, 9, cc.y + 16), Vector3(cc.x - 18, 4, cc.y + 6)], ["a08_rele_da_costa", Vector3(1040, 12, 640), Vector3(rr.x, 30, rr.y)],
			["a09_ponte_antiga", Vector3(1090, 16, 590), Vector3(1150, 4, 640)], ["a10_rele_de_perto", Vector3(rr.x - 44, 24, rr.y + 40), Vector3(rr.x, 32, rr.y)],
			["a11_rele_do_alto", Vector3(rr.x + 70, 100, rr.y + 90), Vector3(rr.x, 20, rr.y)], ["a12_rele_plataforma", Vector3(rr.x - 10, 52, rr.y - 12), Vector3(rr.x + 2, 44, rr.y + 6)],
			["a13_arquipelago_do_alto", Vector3(1150, 200, 1000), Vector3(1290, 0, 760)], ["a14_ponte_sul", Vector3(1250, 14, 800), Vector3(1320, 4, 800)]]
	if "--fenda" in OS.get_cmdline_user_args():
		# a Fenda Escura: de cima, as bocas e por dentro (sem a luz do peito; `--farol` acende)
		var fq := func(sv: float, lado: float, y: float) -> Vector3:
			var p2 := FendaEscura.ponto(sv) + Vector2(-FendaEscura.rumo(sv).y, FendaEscura.rumo(sv).x) * lado
			return Vector3(p2.x, y, p2.y)
		vistas = [["e01_de_cima", Vector3(-860, 190, 1260), Vector3(-860, 40, 1090)], ["e02_teto_de_perto", fq.call(250.0, -46.0, 78.0), fq.call(290.0, 0.0, 52.0)],
			["e03_boca_leste", fq.call(545.0, 4.0, 9.0), fq.call(470.0, 0.0, 14.0)], ["e04_boca_oeste", fq.call(4.0, 0.0, 12.0), fq.call(70.0, 0.0, 14.0)],
			["e05_dentro_claraboia", fq.call(60.0, 3.0, 7.0), fq.call(110.0, 0.0, 12.0)], ["e06_dentro_fundo", fq.call(200.0, -3.0, 6.0), fq.call(250.0, 2.0, 8.0)],
			["e07_dentro_cogumelos", fq.call(300.0, 4.0, 5.0), fq.call(330.0, -6.0, 5.0)], ["e08_dentro_para_cima", fq.call(360.0, 0.0, 6.0), fq.call(395.0, 0.0, 40.0)],
			["e09_saida_para_o_mar", fq.call(455.0, 0.0, 7.0), fq.call(540.0, 0.0, 6.0)]]
		Melhorias.tudo = true
		a.luz_ligada = "--farol" in OS.get_cmdline_user_args()
	if "--flores" in OS.get_cmdline_user_args():
		vistas = [["f2_plato_flores", Vector3(640, 0, 120), Vector3(700, 36, 60)], ["f3_plato_mar", Vector3(700, 0, 160), Vector3(900, 10, 300)], ["f5_plato_alto", Vector3(420, 190, 330), Vector3(680, 38, 100)], ["f6_plato_borda", Vector3(505, 0, 160), Vector3(640, 30, 120)]]
	for v: Array in vistas:
		var de: Vector3 = v[1]
		if de.y == 0.0:
			de.y = c.altura(de.x, de.z) + 3.0
		# o robô vai junto, para as árvores perto dele aparecerem completas (no mar ele fica na praia mais
		# perto, senão entra em pane e a tela escurece)
		var pe := Vector3(de.x, c.altura(de.x, de.z) + 0.3, de.z)
		if pe.y < 1.5 and c is Vale:
			pe = (c as Vale).praia_perto(de.x, de.z) + Vector3(0, 0.3, 0)
		a.teleportar(pe, Armadura.Estado.CHAO)
		livre.global_position = de
		livre.look_at(v[2])
		await _esperar(2.2)
		await _foto(v[0])
	get_tree().quit()


## O Sumidouro por fora e por dentro (`--sumidouro`).
func _sumidouro() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 68.0
	livre.make_current()
	var S := Sumidouro
	var d := Vector3(S.dir.x, 0, S.dir.y)
	var lado := d.cross(Vector3.UP)
	var eixo := Vector3(S.centro.x, S.piso, S.centro.y)
	var boca := Vector3(S.saida.x, S.saida_h, S.saida.y)
	var ya := S.ANEL_ALTURA
	a.teleportar(eixo + Vector3(0, 8.0, 0) + d * 6.0, Armadura.Estado.PAIRAR)
	Input.action_press("mirar")
	await _esperar(1.0)
	var vistas: Array = [
		["a_cima", eixo + Vector3(0, 115, 0) - d * 70.0, eixo + Vector3(0, 45, 0)],
		["b_poco_de_cima", eixo + Vector3(0, 84, 0) - d * 22.0 + lado * 10.0, eixo + Vector3(0, 30, 0)],
		["c_boca", boca + d * 34.0 + Vector3(0, 7, 0) + lado * 8.0, boca + Vector3(0, 4, 0) - d * 6.0],
		["d_tunel", boca - d * 8.0 + Vector3(0, 3.0, 0), eixo + d * 20.0 + Vector3(0, 5, 0)],
		["e_salao", eixo + d * 33.0 + Vector3(0, 5.0, 0) + lado * 6.0, eixo + Vector3(0, 9, 0)],
		["f_salao_fundo", eixo - d * 15.0 + Vector3(0, 4.0, 0) - lado * 9.0, eixo + d * 22.0 + Vector3(0, 8, 0)],
		["g_poco_de_baixo", eixo + Vector3(0, 2.5, 0) + d * 3.0, eixo + Vector3(0, 50, 0) + d * 0.5],
		["h_ponte", eixo + Vector3(0, ya + 9.0, 0) + d * 6.5, eixo + Vector3(0, ya - 3.0, 0) - d * 3.0],
		["i_galeria", eixo + Vector3(0, ya + 2.6, 0) + d * S.ANEL_RAIO, eixo + Vector3(0, ya + 2.4, 0) + lado * S.ANEL_RAIO],
		["j_janela", eixo + Vector3(0, ya + 3.0, 0) + lado * (S.ANEL_RAIO - 1.0), eixo + Vector3(0, ya + 1.0, 0) - lado * 10.0],
		["k_camara", Vector3(S._camara_xz().x, S.piso + 5.0, S._camara_xz().y) + d * 7.0, Vector3(S._camara_xz().x, S.piso + 5.0, S._camara_xz().y) - d * 6.0],
	]
	if S.varanda != Vector2.ZERO:
		var vn := Vector3(S.varanda.x, 0, S.varanda.y)
		vistas.append(["l_varanda", eixo + vn * 1.9 + Vector3(0, ya + 14.0, 0), eixo + vn * 0.6 + Vector3(0, ya + 2.0, 0)])
		vistas.append(["m_varanda_dentro", eixo + vn.normalized() * (S.ANEL_RAIO + 3.0) + Vector3(0, ya + 2.8, 0), eixo + vn * 1.2 + Vector3(0, ya + 2.5, 0)])
	for vista: Array in vistas:
		livre.global_position = vista[1]
		livre.look_at(vista[2])
		await _esperar(0.5)
		await _foto(vista[0])
	Input.action_release("mirar")
	get_tree().quit()


## Procura furos no chão por cima do Sumidouro e das grutas e fotografa a boca do túnel (`--furos`).
func _furos() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var S := Sumidouro
	var f := RochaMalha.furos(S._mn, S._mx, S.vazio, S.extra)
	print("furos no Sumidouro: ", f.size())
	var mn := Vector3.INF
	var mx := -Vector3.INF
	for p in f:
		mn = mn.min(p)
		mx = mx.max(p)
	print("  de ", mn, " a ", mx)
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 68.0
	livre.make_current()
	var d := Vector3(S.dir.x, 0, S.dir.y)
	var lado := d.cross(Vector3.UP)
	var boca := Vector3(S.saida.x, S.saida_h, S.saida.y)
	a.teleportar(boca + d * 10.0 + Vector3(0, 4.0, 0), Armadura.Estado.PAIRAR)
	Input.action_press("mirar")
	await _esperar(1.0)
	var poco := Vector3(Vale.POCO.x, Vale.POCO_NIVEL, Vale.POCO.y)
	var vistas: Array = [
		["a_do_poco", poco + Vector3(0, 6, 0), boca + Vector3(0, 3, 0)],
		["b_de_cima", boca + Vector3(0, 60, 0) + d * 20.0, boca],
		["b2_cachoeira_lado", (m.ilha as Vale).quedas[0] + ((Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized().cross(Vector3.UP)) * 15.0 + (Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized() * 7.0 + Vector3(0, -8, 0), (m.ilha as Vale).quedas[0] + (Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized() * 5.0 + Vector3(0, -6, 0)],
		["b3_cachoeira_meio_lado", (m.ilha as Vale).quedas[0] + ((Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized().cross(Vector3.UP)) * 16.0 + (Vector3(Vale.POCO.x, 0, Vale.POCO.y) - Vector3(Vale.NASCENTE.x, 0, Vale.NASCENTE.y)).normalized() * 16.0 + Vector3(0, -6, 0), (m.ilha as Vale).quedas[0]],
		["c_frente", boca + d * 22.0 + Vector3(0, 3, 0), boca + Vector3(0, 3, 0)],
		["d_lado1", boca + d * 8.0 + lado * 22.0 + Vector3(0, 6, 0), boca + Vector3(0, 2, 0)],
		["e_lado2", boca + d * 8.0 - lado * 22.0 + Vector3(0, 6, 0), boca + Vector3(0, 2, 0)],
		["f_dentro_fora", boca - d * 4.0 + Vector3(0, 2.0, 0), boca + d * 20.0 + Vector3(0, 2, 0)],
		["g_chao_boca", boca + d * 14.0 + Vector3(0, 1.2, 0), boca - d * 4.0 + Vector3(0, 2, 0)],
	]
	if f.size() > 0:
		var meio := (mn + mx) * 0.5
		vistas.append(["h_furo_cima", meio + Vector3(0, 30, 8), meio])
		vistas.append(["i_furo_dentro", f[f.size() / 2] + Vector3(0, 1.2, 0), Vector3(S.centro.x, S.piso + 10.0, S.centro.y)])
	for vista: Array in vistas:
		livre.global_position = vista[1]
		livre.look_at(vista[2])
		await _esperar(0.5)
		await _foto(vista[0])
	Input.action_release("mirar")
	get_tree().quit()


## Confere se o som está saindo (`--sonda-som`): o aparelho de saída, o volume do barramento e o pico medido.
func _sonda_som() -> void:
	await _esperar(2.5)
	a.recomecar()
	print("som: driver ", AudioServer.get_driver_name(), ", saída ", AudioServer.get_output_device(), ", aparelhos ", AudioServer.get_output_device_list())
	print("som: barramento 0 a ", AudioServer.get_bus_volume_db(0), " dB, mudo ", AudioServer.is_bus_mute(0), ", mix ", AudioServer.get_mix_rate(), " Hz")
	Input.action_press("frente")
	var pico := -200.0
	for i in 180:
		await get_tree().process_frame
		pico = maxf(pico, maxf(AudioServer.get_bus_peak_volume_left_db(0, 0), AudioServer.get_bus_peak_volume_right_db(0, 0)))
	Input.action_release("frente")
	var todos: Array[Node] = m.find_children("*", "AudioStreamPlayer", true, false) + m.find_children("*", "AudioStreamPlayer3D", true, false)
	print("som: pico em 3 s andando ", pico, " dB; ", todos.size(), " tocadores")
	for n in todos:
		if n is AudioStreamPlayer3D:
			var p3 := n as AudioStreamPlayer3D
			if not p3.global_position.is_finite() or not is_finite(p3.pitch_scale) or p3.pitch_scale <= 0.0 or not is_finite(p3.volume_db):
				print("  ESTRANHO: ", p3.get_path(), " pos ", p3.global_position, " tom ", p3.pitch_scale, " vol ", p3.volume_db)
		else:
			var p1 := n as AudioStreamPlayer
			if not is_finite(p1.pitch_scale) or p1.pitch_scale <= 0.0 or not is_finite(p1.volume_db):
				print("  ESTRANHO: ", p1.get_path(), " tom ", p1.pitch_scale, " vol ", p1.volume_db)
	# desliga um por um até o som voltar
	for n in todos:
		if not n.playing:
			continue
		n.stop()
		var pc := -200.0
		for i in 20:
			await get_tree().process_frame
			pc = maxf(pc, AudioServer.get_bus_peak_volume_left_db(0, 0))
		if pc > -100.0:
			print("  o som voltou (", pc, " dB) ao desligar ", n.get_path(), " stream ", n.stream.resource_path if n.stream else "")
			break
	get_tree().quit()


## Abaixado (pés no chão), o levantar de sentado quadro a quadro e a decolagem segurando o pulo (`--levantar`).
func _levantar() -> void:
	await _esperar(2.5)
	a.recomecar()
	var claro := Clareira.CLAROS[0]
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		(n as Node3D).visible = false
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 22.0
	livre.make_current()
	var chao := Vector3(claro.x, c.altura(claro.x, claro.y) + 0.2, claro.y)
	a.teleportar(chao, Armadura.Estado.CHAO)
	cam.yaw = PI * 0.5
	cam.pitch = 0.0
	await _esperar(0.8)
	var tirar := func(nome: String, longe := 4.6, alto := 0.5) -> void:
		var p: Vector3 = a.pos_suave()
		livre.global_position = p + Vector3(0, alto, longe)
		livre.look_at(p + Vector3(0, alto, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta + nome + ".png")
	await tirar.call("a_de_pe")
	Input.action_press("sentar")
	await _esperar(0.1)
	Input.action_release("sentar")
	await _esperar(0.8)
	await tirar.call("b_abaixado")
	Input.action_press("frente")
	for i in 3:
		await _esperar(0.37)
		await tirar.call("c_abaixado_andando_%d" % i)
	Input.action_release("frente")
	await _esperar(0.6)
	a.postura = 2
	await _esperar(1.5)
	await tirar.call("d_sentado")
	Input.action_press("pular")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("pular")
	for i in 7:
		await _esperar(0.14)
		await tirar.call("e_levanta_%d" % i)
	await _esperar(0.5)
	# decolagem segurando o pulo
	livre.fov = 50.0
	Input.action_press("pular")
	for i in 8:
		await _esperar(0.22)
		var p: Vector3 = a.pos_suave()
		livre.global_position = chao + Vector3(3.0, 5.0, 17.0)
		livre.look_at(chao + Vector3(-3.0, 6.5, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta + "f_decola_%d.png" % i)
	Input.action_release("pular")
	get_tree().quit()


## O nado no poço da cachoeira, a lagoa funda e a mira travada numa máquina (`--nado`).
func _nado() -> void:
	await _esperar(2.5)
	var poco := Vector3(Vale.POCO.x, Vale.POCO_NIVEL, Vale.POCO.y)
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 55.0
	# pela câmera do jogo: boiando, nadando para baixo e nadando rápido
	a.teleportar(poco + Vector3(0, -3.0, 0), Armadura.Estado.AR)
	cam.yaw = 0.6
	cam.pitch = -0.1
	await _esperar(1.5)
	await _foto("a_boiando")
	cam.pitch = -0.45
	Input.action_press("frente")
	await _esperar(0.7)
	await _foto("b_descendo")
	Input.action_release("frente")
	await _esperar(0.5)
	cam.pitch = 0.05
	cam.yaw = 2.2
	Input.action_press("frente")
	Input.action_press("correr_alternar")
	await _esperar(0.1)
	Input.action_release("correr_alternar")
	await _esperar(0.5)
	await _foto("c_rapido")
	Input.action_release("frente")
	# de perto, câmera solta debaixo d'água
	m.hud.visible = false
	a.teleportar(poco + Vector3(0, -5.0, 0), Armadura.Estado.AR)
	cam.yaw = PI * 0.5
	cam.pitch = 0.0
	await _esperar(1.2)
	livre.make_current()
	livre.fov = 30.0
	livre.global_position = a.pos_suave() + Vector3(0, 0.6, 4.2)
	livre.look_at(a.pos_suave() + Vector3(0, 0.6, 0))
	await _esperar(0.3)
	await _foto("d_boiando_perto")
	Input.action_press("frente")
	await _esperar(0.45)
	livre.global_position = a.pos_suave() + Vector3(0, 0.6, 4.2)
	livre.look_at(a.pos_suave() + Vector3(0, 0.6, 0))
	await _foto("e_nadando_perto")
	Input.action_release("frente")
	# o poço de cima e saindo voando
	livre.fov = 60.0
	livre.global_position = poco + Vector3(14, 16, 22)
	livre.look_at(poco + Vector3(0, 2, 0))
	a.teleportar(poco + Vector3(0, -9.0, 0), Armadura.Estado.AR)
	await _esperar(0.4)
	cam.pitch = 1.2
	Input.action_press("frente")
	Input.action_press("correr_alternar")
	await _esperar(0.1)
	Input.action_release("correr_alternar")
	for i in 200:
		await get_tree().physics_frame
		if a.estado == Armadura.Estado.VOO:
			break
	await _esperar(0.25)
	await _foto("f_saindo_voando")
	Input.action_release("frente")
	# a lagoa da clareira
	m.hud.visible = true
	cam.cam.make_current()
	a.teleportar(Vector3(Clareira.LAGOA.x, Clareira.NIVEL - 2.5, Clareira.LAGOA.y), Armadura.Estado.AR)
	cam.pitch = -0.05
	cam.yaw = 1.0
	await _esperar(1.5)
	await _foto("g_lagoa")
	# a mira travada numa máquina
	var alvo_m: Node3D = null
	for n in get_tree().get_nodes_in_group("maquinas"):
		if n is Mecha and (n.call("ponto_de_trava") as Vector3).is_finite():
			alvo_m = n
			break
	if alvo_m:
		var pm: Vector3 = alvo_m.call("ponto_de_trava")
		a.teleportar(Vector3(pm.x + 16.0, c.altura(pm.x + 16.0, pm.z) + 0.3, pm.z), Armadura.Estado.CHAO)
		a.graca_pane = 30.0
		Input.action_press("mirar")
		for i in 60:
			pm = alvo_m.call("ponto_de_trava")
			var d := pm - cam.global_position
			cam.yaw = atan2(-d.x, -d.z) + deg_to_rad(3.5)
			cam.pitch = atan2(d.y, Vector2(d.x, d.z).length()) - deg_to_rad(2.0)
			if i == 40:
				Input.action_press("atirar")
			await get_tree().physics_frame
		await _foto("h_mira_travada")
		Input.action_release("atirar")
		Input.action_release("mirar")
	get_tree().quit()


## As árvores e as plantas dos pacotes, de perto (`--plantas`).
func _plantas() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	var v := c as Vale
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 55.0
	livre.make_current()
	a.teleportar(Vector3(0, 400, 0), Armadura.Estado.PAIRAR)
	Input.action_press("mirar")
	for tipo: String in ["q_flor_a", "q_flor_c", "q_samambaia", "q_cogumelo", "q_moita", "q_pedra_a", "q_planta_c"]:
		if not v.plantas_amostra.has(tipo):
			print("sem amostra de ", tipo)
			continue
		var p: Vector3 = v.plantas_amostra[tipo]
		livre.global_position = Vector3(p.x + 3.2, v.altura(p.x + 3.2, p.z + 2.4) + 1.3, p.z + 2.4)
		livre.look_at(p + Vector3(0, 0.3, 0))
		await _esperar(0.5)
		await _foto("p_" + tipo)
	# árvores: procura uma de cada jeito perto do meio do mapa
	var vistos := {}
	for item in v._fila_q:
		var tipo: String = item[0]
		var base := tipo.substr(0, tipo.length() - 2) if not tipo.contains("_amarela") and not tipo.contains("_vinho") and not tipo.contains("_laranja") else tipo
		if vistos.has(base) or not tipo.begins_with("q_"):
			continue
		var p: Vector3 = (item[1] as Transform3D).origin
		if Vector2(p.x, p.z).length() < 160.0 or Vector2(p.x, p.z).length() > 600.0:
			continue
		vistos[base] = true
		livre.global_position = Vector3(p.x + 13.0, v.altura(p.x + 13.0, p.z + 9.0) + 3.5, p.z + 9.0)
		livre.look_at(p + Vector3(0, 6.0, 0))
		await _esperar(0.5)
		await _foto("a_" + base)
	Input.action_release("mirar")
	get_tree().quit()


## Uma fileira de mechs sorteados, parados e andando, para conferir a montagem (`--mechas`).
func _mechas() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		if (n as MultiMeshInstance3D).visibility_range_end > 0.0 and (n as MultiMeshInstance3D).visibility_range_end < 100.0:
			(n as Node3D).visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 34.0
	livre.make_current()
	var claro := Clareira.CLAROS[0]
	var base := Vector3(claro.x, c.altura(claro.x, claro.y), claro.y)
	a.teleportar(base + Vector3(0, 0.3, 30), Armadura.Estado.CHAO)
	var lista: Array[Mech00Visual] = []
	for i in 8:
		var v := Mech00Visual.montar(40 + i, 1.8, c._tex)
		m.add_child(v)
		var x := (i % 4 - 1.5) * 3.6
		var z := -3.0 if i < 4 else 2.5
		v.global_position = Vector3(base.x + x, c.altura(base.x + x, base.z + z), base.z + z)
		v.rotation.y = PI  # de frente para a câmera (+Z)
		lista.append(v)
		print("mech ", 40 + i, ": ", v.ficha)
	await _esperar(1.0)
	livre.global_position = base + Vector3(-7.0, 3.6, 12.0)
	livre.look_at(base + Vector3(0, 0.9, 0))
	await _foto("a_fileira")
	livre.global_position = base + Vector3(-9.0, 2.2, -8.0)
	livre.look_at(base + Vector3(0, 0.9, 0))
	await _foto("b_costas")
	for i in lista.size():
		lista[i].tocar(["Walk", "Run", "Shoot", "Death"][i % 4])
	await _esperar(0.45)
	livre.global_position = base + Vector3(-7.0, 3.6, 12.0)
	livre.look_at(base + Vector3(0, 0.9, 0))
	await _foto("c_animando")
	livre.fov = 20.0
	livre.global_position = lista[1].global_position + Vector3(1.6, 1.3, 4.6)
	livre.look_at(lista[1].global_position + Vector3(0, 0.9, 0))
	await _foto("d_perto")
	get_tree().quit()


## O momento do ataque de cada jeito de mecha (uma bolinha branca marca de onde o tiro sai) e dois caídos:
## um numa ladeira e outro na beira do riacho (`--mechas-tiro`).
func _mechas_tiro() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		if (n as MultiMeshInstance3D).visibility_range_end > 0.0 and (n as MultiMeshInstance3D).visibility_range_end < 100.0:
			(n as Node3D).visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 30.0
	livre.make_current()
	var claro := Clareira.CLAROS[0]
	var base := Vector3(claro.x, c.altura(claro.x, claro.y), claro.y)
	a.teleportar(base + Vector3(0, 0.3, 40), Armadura.Estado.CHAO)
	# acha uma semente de cada jeito: arma na mão direita, braço-canhão esquerdo, costas e espada
	var achados := {}
	for sem in range(1, 400):
		var t := Mech00Visual.montar(sem, 1.9, c._tex)
		var f: Dictionary = t.ficha
		var chave := String(f["arma"])
		if f["mao"] == "canhão":
			chave = "canhao_" + String(f["lado"])
		if not achados.has(chave):
			achados[chave] = sem
		t.free()
		if achados.size() >= 5:
			break
	print("sementes: ", achados)
	var marca := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.09
	bm.height = 0.18
	marca.mesh = bm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.no_depth_test = true
	marca.material_override = mm
	m.add_child(marca)
	for chave: String in achados:
		var v := Mech00Visual.montar(achados[chave], 1.9, c._tex)
		m.add_child(v)
		v.global_position = base
		v.rotation.y = PI
		await _esperar(0.4)
		v.tocar("Shoot")
		await _esperar(v.tempo_do_tiro())
		marca.global_position = v.ponto_tiro()
		livre.global_position = base + Vector3(3.2, 1.6, 6.0)
		livre.look_at(base + Vector3(0, 1.1, 0))
		await _foto("t_" + chave)
		v.queue_free()
	marca.visible = false
	# caídos: procura uma ladeira e a beira do riacho
	var ladeira := Vector3.INF
	for r in range(30, 110, 6):
		for k in 24:
			var q := Vector2(cos(k * TAU / 24.0), sin(k * TAU / 24.0)) * float(r)
			var ny := c.normal_em(q.x, q.y).y
			if ny > 0.86 and ny < 0.93 and c.agua(q.x, q.y) == -INF and ladeira == Vector3.INF:
				ladeira = Vector3(q.x, c.altura(q.x, q.y), q.y)
	var beira := Vector3.INF
	for rp in Clareira.RIACHO:
		for d: Vector2 in [Vector2(3.5, 0), Vector2(-3.5, 0), Vector2(0, 3.5), Vector2(0, -3.5)]:
			var q := Vector2(rp.x, rp.y) + d
			if c.agua(q.x, q.y) == -INF and beira == Vector3.INF and q.length() > 30.0:
				beira = Vector3(q.x, c.altura(q.x, q.y), q.y)
	var k2 := 0
	for lugar: Vector3 in [ladeira, beira]:
		if lugar == Vector3.INF:
			continue
		var mc := Mecha.new()
		mc.mapa = c
		mc.casa = lugar
		mc.semente = 31 + k2
		m.add_child(mc)
		mc.global_position = lugar
		mc.pose_foto = 0
		await _esperar(0.3)
		mc.pose_foto = -1
		mc.desligar()
		await _esperar(2.5)
		livre.global_position = lugar + Vector3(4.5, 2.4, 5.5)
		livre.look_at(lugar + Vector3(0, 0.3, 0))
		await _foto("c_caido_%d" % k2)
		k2 += 1
	get_tree().quit()


## Os efeitos dos tiros de perto (`--efeitos-tiro`): clarão e rastro de cada projétil, impacto e a explosão.
func _efeitos_tiro() -> void:
	await _esperar(2.5)
	m.hud.visible = false
	m.inimigos.process_mode = Node.PROCESS_MODE_DISABLED
	for n in c.find_children("*", "MultiMeshInstance3D", true, false):
		if (n as MultiMeshInstance3D).visibility_range_end > 0.0 and (n as MultiMeshInstance3D).visibility_range_end < 100.0:
			(n as Node3D).visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 40.0
	livre.make_current()
	var claro := Clareira.CLAROS[0]
	var base := Vector3(claro.x, c.altura(claro.x, claro.y), claro.y)
	a.teleportar(base + Vector3(0, 0.3, 40), Armadura.Estado.CHAO)
	var mc := Mecha.new()
	mc.mapa = c
	mc.casa = base + Vector3(-7, 0, 0)
	mc.semente = 1
	m.add_child(mc)
	mc.global_position = mc.casa
	mc.rotation.y = -PI / 2.0
	mc.pose_foto = 0
	await _esperar(0.5)
	livre.global_position = base + Vector3(-3.0, 1.8, 11.0)
	livre.look_at(base + Vector3(-3.0, 1.4, 0))
	var de := mc.global_position + Vector3(1.2, 1.5, 0)
	for tipo: String in ["bala", "pesado", "missil"]:
		mc.atirar_em(de, de + Vector3(30, 0, 0), tipo, 0.0)
		for i in (3 if tipo != "missil" else 14):
			mc.atualizar_tiros(1.0 / 60.0)
		await get_tree().process_frame
		await _foto("a_" + tipo)
		for i in 400:
			mc.atualizar_tiros(1.0 / 60.0)
		await _esperar(0.3)
	# impacto e explosão, em três tempos
	var alvo_p := base + Vector3(2.0, 0.4, 0)
	EfeitosTiro.impacto(mc, alvo_p + Vector3(-3, 0.6, 0))
	await _esperar(0.06)
	await _foto("b_impacto")
	await _esperar(0.6)
	for k in 3:
		EfeitosTiro.explosao(mc, alvo_p, 3.2)
		await _esperar([0.07, 0.25, 0.9][k])
		await _foto("c_explosao_%d" % k)
		await _esperar(2.2)
	get_tree().quit()


## O robô básico, uma peça na ilha, a instalação e as peças em uso (`--melhorias --basico --hora 12`).
func _melhorias() -> void:
	await _esperar(2.5)
	a.recomecar()
	m.hud.visible = true
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 42.0
	livre.make_current()
	var pm: PecasMundo = m.pecas
	Melhorias.tudo = false
	a.visual.vestir_melhorias()
	pm.repor()
	await _esperar(0.6)
	var frente := -a.global_basis.z
	livre.global_position = a.global_position - frente * 3.2 + Vector3(1.2, 1.5, 0)
	livre.look_at(a.global_position + Vector3(0, 0.75, 0))
	await _foto("m1_basico_costas")
	var pa: Vector3 = pm.onde["antena"]
	a.teleportar(pa + Vector3(5.0, 0.3, 3.0), Armadura.Estado.CHAO)
	await _esperar(0.6)
	livre.global_position = pa + Vector3(9.5, 2.4, 7.0)
	livre.look_at(pa + Vector3(1.5, 1.2, 1.0))
	await _foto("m2_peca_na_ilha")
	a.teleportar(pa + Vector3(0, 0.3, 0), Armadura.Estado.CHAO)
	await _esperar(0.5)
	await _foto("m3_pegou")
	for nome: String in Melhorias.NOMES:
		Melhorias.achar(nome)
	pm.repor()
	var b := BaseVale.boca_cilindro
	a.teleportar(Vector3(b.x, m.ilha.altura(b.x, b.z) + 0.4, b.z), Armadura.Estado.CHAO)
	livre.global_position = Vector3(b.x, m.ilha.altura(b.x, b.z), b.z) + (b - C_BASE()).normalized() * 6.0 + Vector3(0, 1.8, 0)
	livre.look_at(Vector3(b.x, m.ilha.altura(b.x, b.z) + 0.9, b.z))
	await _esperar(0.75)
	await _foto("m4_instalando")
	await _esperar(1.6)
	frente = -a.global_basis.z
	livre.global_position = a.global_position - frente * 3.0 + Vector3(0.9, 1.4, 0)
	livre.look_at(a.global_position + Vector3(0, 0.75, 0))
	await _foto("m5_instalado_costas")
	# planando com as asas
	var alto := Vector3(60, m.ilha.altura(60, 60) + 70.0, 60)
	a.teleportar(alto, Armadura.Estado.PLANAR, Vector3(-12, -3, -12))
	await _esperar(1.3)
	var vel := a.velocity.normalized()
	livre.global_position = a.global_position - vel * 4.2 + Vector3(0, 1.7, 0)
	livre.look_at(a.global_position)
	await _foto("m6_planando")
	get_tree().quit()


func C_BASE() -> Vector3:
	return BaseVale.posto_drone


## A oficina: convite na boca, o robô entrando, a tela com a lista e a prévia, a instalação e a falta de
## energia (`--oficina --basico --hora 12`).
func _oficina() -> void:
	await _esperar(2.5)
	a.recomecar()
	Melhorias.tudo = false
	Melhorias.energia = 100.0
	for nome: String in ["antena", "radiador", "asas", "farol", "amortecedores"]:
		Melhorias.achar(nome)
	a.visual.vestir_melhorias()
	m.pecas.repor()
	var of: Oficina = m.oficina
	var b := BaseVale.boca_cilindro
	var fora := b + of._eixo() * 0.6
	a.teleportar(Vector3(fora.x, m.ilha.altura(fora.x, fora.z) + 0.4, fora.z), Armadura.Estado.CHAO)
	cam.yaw = atan2(of._eixo().x, of._eixo().z)
	cam.pitch = -0.1
	await _esperar(1.0)
	await _foto("o1_convite")
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.fov = 45.0
	livre.global_position = b + of._eixo() * 5.5 + BaseVale.cilindro_t.basis.z.normalized() * 3.6 + Vector3(0, -0.6, 0)
	livre.look_at(b + Vector3(0, -1.6, 0))
	livre.make_current()
	await _esperar(0.3)
	await _foto("o0_rampa")
	cam.cam.make_current()
	livre.queue_free()
	of.entrar()
	await _esperar(1.1)
	await _foto("o2_entrando")
	await _esperar(1.6)
	await _foto("o3_tela")
	for nome: String in ["asas", "radiador", "farol", "amortecedores"]:
		(of._botoes[nome] as Button).grab_focus()
		await _esperar(0.9)
		await _foto("o4_previa_" + nome)
	of.instalar("asas")
	await _esperar(1.0)
	await _foto("o5_instalando")
	await _esperar(1.4)
	await _foto("o6_instalado")
	(of._botoes["radiador"] as Button).grab_focus()
	of.instalar("radiador")
	await _esperar(0.6)
	await _foto("o7_sem_energia")
	of.sair()
	await _esperar(2.0)
	await _foto("o8_saiu")
	get_tree().quit()


## O scanner: o visor procurando, lendo e com a ficha do Faísca, do drone e de uma mecha
## (`--scanner --hora 12`).
func _scanner() -> void:
	await _esperar(2.5)
	a.recomecar()
	var sc: Scanner = m.scanner
	var f := BaseVale.faisca_em
	a.teleportar(Vector3(f.x + 4.5, m.ilha.altura(f.x + 4.5, f.z + 3.0) + 0.4, f.z + 3.0), Armadura.Estado.CHAO)
	await _esperar(0.8)
	sc.ligar()
	cam.yaw += 0.5
	await _esperar(0.6)
	await _foto("s1_procurando")
	for alvo in [[f + Vector3(0, 0.45, 0), "faisca"], [m.drone.global_position + Vector3(0, 0.5, 0), "drone"]]:
		for volta in 3:
			var d: Vector3 = (alvo[0] as Vector3) - cam.global_position
			cam.yaw = atan2(-d.x, -d.z)
			cam.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			await _esperar(0.25)
		await _foto("s2_lendo_" + String(alvo[1]))
		await _esperar(1.9)
		await _foto("s3_ficha_" + String(alvo[1]))
	# uma mecha: a mais perto
	var mais: Node3D = null
	for no in get_tree().get_nodes_in_group("maquinas"):
		if mais == null or (no as Node3D).global_position.distance_to(a.global_position) < mais.global_position.distance_to(a.global_position):
			mais = no
	if mais:
		var perto := mais.global_position + Vector3(22, 0, 14)
		sc.desligar()
		a.teleportar(Vector3(perto.x, m.ilha.altura(perto.x, perto.z) + 0.4, perto.z), Armadura.Estado.CHAO)
		await _esperar(0.5)
		sc.ligar()
		Input.action_press("atirar")
		for volta in 12:
			var d: Vector3 = mais.global_position + Vector3(0, 1.1, 0) - cam.global_position
			cam.yaw = atan2(-d.x, -d.z)
			cam.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			await _esperar(0.2)
		await _foto("s4_ficha_mecha")
		Input.action_release("atirar")
	get_tree().quit()


## Fotos para a arte da Steam (`--capa --hora N`): o robô voando sobre o vale, em vários lugares e ângulos.
func _capa() -> void:
	await _esperar(3.0)
	a.recomecar()
	m.hud.visible = false
	var livre := Camera3D.new()
	m.add_child(livre)
	livre.far = 9000.0
	livre.make_current()
	# [nome, de onde sai (y acima do chão), rumo]
	var voos := [["serra", Vector3(-80, 90, -160), Vector3(-0.7, 0, -1)]]
	# [nome, à frente, ao lado, acima, olha à frente, olha acima, fov]
	var angulos := [["largo", -2.6, 1.0, 0.7, 10.0, 0.6, 50.0], ["largo_b", -3.0, 1.6, 0.5, 10.0, 1.4, 50.0], ["alto", -3.2, 0.5, -0.2, 10.0, 3.2, 58.0],
		["alto_b", -3.6, 0.9, -0.5, 10.0, 4.2, 62.0], ["alto_c", -2.8, -0.6, 0.0, 10.0, 3.0, 62.0]]
	if "--pairando" in OS.get_cmdline_user_args():
		# pairando de frente para a câmera, com a serra atrás
		var serra := Vector3(-0.7, 0, -1).normalized()
		var lugar := Vector3(-108, 0, -200)
		lugar.y = c.altura(lugar.x, lugar.z) + 85.0
		for caso: Array in [["a", 1.0, false]]:
			a.calor = 0.0
			a.teleportar(lugar, Armadura.Estado.PAIRAR)
			cam.yaw = atan2(serra.x * caso[1], serra.z * caso[1])
			cam.pitch = 0.0
			if caso[2]:
				Input.action_press("mirar")
			await _esperar(1.6)
			var p: Vector3 = a.global_position
			var ld := serra.cross(Vector3.UP).normalized()
			for v: Array in [["1", 1.8, 0.0, 0.2, 0.35, 60.0], ["2", 2.1, 0.0, 0.5, 0.3, 58.0], ["3", 1.9, 0.25, -0.2, 0.4, 62.0], ["4", 2.3, -0.2, 0.9, 0.2, 55.0], ["5", 1.6, 0.0, 0.5, 0.4, 62.0], ["6", 2.2, 0.0, 1.3, 0.2, 60.0]]:
				livre.fov = v[5]
				livre.global_position = p - serra * v[1] + ld * v[2] + Vector3.UP * v[3]
				livre.look_at(p + Vector3.UP * v[4])
				await _foto("pairando_%s_%s" % [caso[0], v[0]])
			Input.action_release("mirar")
		get_tree().quit()
		return
	for voo: Array in voos:
		var de: Vector3 = voo[1]
		var rumo: Vector3 = (voo[2] as Vector3).normalized()
		var lado := rumo.cross(Vector3.UP).normalized()
		for ang: Array in angulos:
			a.calor = 0.0
			a.teleportar(Vector3(de.x, c.altura(de.x, de.z) + de.y, de.z), Armadura.Estado.VOO, rumo * 30.0)
			cam.yaw = atan2(-rumo.x, -rumo.z)
			cam.pitch = 0.0
			Input.action_press("frente")
			await _esperar(1.4)
			var p: Vector3 = a.global_position + a.velocity * (1.0 / 60.0)
			livre.fov = ang[6]
			livre.global_position = p + rumo * ang[1] + lado * ang[2] + Vector3.UP * ang[3]
			livre.look_at(p + rumo * ang[4] + Vector3.UP * ang[5])
			await _foto("%s_%s" % [voo[0], ang[0]])
			Input.action_release("frente")
	get_tree().quit()


## O mapa visto de cima, com o nome de cada lugar (`--mapa --hora 12`): docs/mapa/mapa_lugares.png.
## Norte (-Z) para cima. Também imprime a lista dos lugares com posição e raio.
func _mapa() -> void:
	await _esperar(3.0)
	m.hud.visible = false
	a.visual.visible = false
	var lado := 2400
	var meio := 1580.0  # metade do lado fotografado, em metros
	if "--meio" in OS.get_cmdline_user_args():
		meio = float(OS.get_cmdline_user_args()[OS.get_cmdline_user_args().find("--meio") + 1])
	var vp := SubViewport.new()
	vp.size = Vector2i(lado, lado)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var de_cima := Camera3D.new()
	de_cima.projection = Camera3D.PROJECTION_ORTHOGONAL
	de_cima.size = meio * 2.0
	de_cima.far = 3000.0
	vp.add_child(de_cima)
	de_cima.look_at_from_position(Vector3(0, 900, 0), Vector3.ZERO, Vector3(0, 0, -1))
	de_cima.current = true
	var folha := Control.new()
	folha.size = Vector2(lado, lado)
	vp.add_child(folha)
	var px := func(x: float, z: float) -> Vector2:
		return Vector2((x + meio) / (meio * 2.0) * lado, (z + meio) / (meio * 2.0) * lado)
	var pontos: Array = []
	for it: Dictionary in m.locais.lista:
		pontos.append([it["nome"], it["pos"].x, it["pos"].z, it["raio"]])
	pontos.append(["Base", Melhorias.base.x, Melhorias.base.z, 0.0])
	var saida_nome := "mapa_lugares"
	if "--so-pecas" in OS.get_cmdline_user_args():
		# o mapa das peças: só elas e a base (`--mapa --so-pecas`)
		saida_nome = "mapa_pecas"
		pontos = [["Base", Melhorias.base.x, Melhorias.base.z, 0.0]]
		for nome_p: String in Melhorias.NOMES:
			var pp: Vector3 = m.pecas.onde[nome_p]
			pontos.append([Melhorias.TITULOS[nome_p], pp.x, pp.z, 0.0])
	var fora_n := 0
	for ap: Vector3 in c.arv_pos:
		if maxf(absf(ap.x), absf(ap.z)) > 1000.0:
			fora_n += 1
	print("ARVORES %d no total, %d fora dos 2 km antigos" % [c.arv_pos.size(), fora_n])
	for pt: Array in pontos:
		print("LUGAR %s x %.0f z %.0f raio %.0f" % pt)
		var onde: Vector2 = px.call(pt[1], pt[2])
		var marca := ColorRect.new()
		marca.color = Color(1.0, 0.62, 0.25)
		marca.size = Vector2(12, 12)
		marca.position = onde - Vector2(6, 6)
		marca.rotation = PI / 4.0
		marca.pivot_offset = Vector2(6, 6)
		folha.add_child(marca)
		var nome := Label.new()
		nome.text = pt[0]
		var regiao: bool = float(pt[3]) >= 95.0  # região larga: letra maior, em cima do ponto; lugar: embaixo
		nome.add_theme_font_size_override("font_size", 40 if regiao else 30)
		nome.add_theme_color_override("font_color", Color.WHITE)
		nome.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.1))
		nome.add_theme_constant_override("outline_size", 10)
		folha.add_child(nome)
		nome.position = onde + Vector2(-nome.get_minimum_size().x * 0.5, -nome.get_minimum_size().y - 10.0 if regiao else 10.0)
	# norte e escala
	var rodape := Label.new()
	rodape.text = "500 m          norte para cima"
	rodape.add_theme_font_size_override("font_size", 30)
	rodape.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.1))
	rodape.add_theme_constant_override("outline_size", 10)
	rodape.position = Vector2(40, lado - 70)
	folha.add_child(rodape)
	var regua := ColorRect.new()
	regua.size = Vector2(500.0 / (meio * 2.0) * lado, 6)
	regua.position = Vector2(40, lado - 86)
	folha.add_child(regua)
	for i in 6:
		await RenderingServer.frame_post_draw
	var saida := ProjectSettings.globalize_path("res://docs/mapa/%s.png" % saida_nome)
	vp.get_texture().get_image().save_png(saida)
	print("MAPA em ", saida)
	get_tree().quit()
