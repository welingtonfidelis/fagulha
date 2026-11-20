class_name TorreQuente
extends Node3D
## A torre de resfriamento da Fundição (2026-11-19), o lugar que o **radiador** abre: uma chaminé larga, em fiadas
## de blocos que afinam para cima, com cintas de ferro, escada de marinheiro, o duto que vem da Fundição,
## respiros acesos no pé e uma grade fechando a boca. É fechada: entra-se pela
## porta de baixo e o ar quente que sobe por dentro leva o robô até o alto, mas esquenta o motor depressa.
## Sem radiador ele superaquece antes do topo, o ar deixa de sustentá-lo e ele cai; com o radiador chega.
## No alto há uma sacada com um receptor antigo. Ligando-o, aparece a lembrança "Alguém respondeu" e passa a
## existir, de noite, uma luz distante no horizonte do mar: o gancho para um lugar fora da ilha, que ainda
## vai ser construído.
## Quem cria passa `armadura`, `hud`, `memorias` e `mapa`.

const RAIO := 9.0  # por dentro
const ALTURA := 62.0
const SACADA := 52.0  # altura do piso da sacada
const NUCLEO := 5.2  # raio da coluna de ar quente
const SOBE := 9.0  # m/s a que o ar leva o robô
const CALOR := 38.0  # %/s sem radiador (o radiador divide pelo mesmo fator do voo)
const PERTO := 2.6
const SINAL := Vector3(-2300.0, 60.0, 1700.0)  # onde a luz distante aparece (fora do mapa, a sudoeste)

var armadura: Armadura
var hud: Hud
var memorias: Memorias
var mapa: Vale
var ligado := false  # o receptor foi ligado
var pe := Vector3.INF  # o meio do chão da torre, no mundo
var receptor := Vector3.INF
var dentro := false  # o robô está na coluna de ar quente (testes)
var _dica_minha := ""
var _avisou := false


func _ready() -> void:
	if Guardado.ativo:
		ligado = bool((Guardado.progresso("achados") as Dictionary).get("sinal", false))
	for i in 6:
		await get_tree().physics_frame
	_construir()
	LuzesNoite.ligadas["sinal"] = ligado


func _bloco(corpo: StaticBody3D, centro: Vector3, tam: Vector3, cor: Color, giro := Basis.IDENTITY, colide := true, luz := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var cx := BoxMesh.new()
	cx.size = tam
	mi.mesh = cx
	if luz > 0.0:
		var ml := StandardMaterial3D.new()
		ml.albedo_color = cor
		ml.emission_enabled = true
		ml.emission = cor
		ml.emission_energy_multiplier = luz
		mi.material_override = ml
	else:
		var mt := ShaderMaterial.new()
		mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
		mt.set_shader_parameter("cor", cor)
		mt.set_shader_parameter("brilho_borda", 0.12)
		mi.material_override = mt
	mi.transform = Transform3D(giro, centro)
	add_child(mi)
	if colide:
		var f := BoxShape3D.new()
		f.size = tam
		var cs := CollisionShape3D.new()
		cs.shape = f
		cs.transform = Transform3D(giro, centro)
		corpo.add_child(cs)


func _construir() -> void:
	# um lugar firme ao lado da Fundição, do lado das chaminés
	var melhor := Vector2.INF
	var menor := INF
	for dz: float in [-40.0, -25.0, -10.0, 5.0, 20.0, 35.0, 50.0]:
		for dx: float in [-95.0, -80.0, -110.0, -125.0]:
			var c := Fundicao.CENTRO + Vector2(dx, dz)
			var h0: float = mapa._fora(c.x, c.y)
			var desnivel := 0.0
			for k in 8:
				var a := k * TAU / 8.0
				desnivel = maxf(desnivel, absf(mapa._fora(c.x + cos(a) * RAIO, c.y + sin(a) * RAIO) - h0))
			# sem árvore dentro nem encostada (ela atravessaria a parede)
			if mapa._arvore_perto(Vector3(c.x, h0, c.y), RAIO + 6.0):
				desnivel += 100.0
			if mapa.agua(c.x, c.y) == -INF and desnivel < menor:
				menor = desnivel
				melhor = c
	if not melhor.is_finite():
		return
	var chao: float = mapa._fora(melhor.x, melhor.y)
	# o piso fica no ponto mais alto do terreno em volta, para a porta não nascer enterrada
	for k in 8:
		var a := k * TAU / 8.0
		chao = maxf(chao, mapa._fora(melhor.x + cos(a) * (RAIO + 1.0), melhor.y + sin(a) * (RAIO + 1.0)))
	pe = Vector3(melhor.x, chao + 0.3, melhor.y)
	var o := Ruinas.Obra.new()
	o.v = mapa
	var blocos: Array[PackedVector3Array] = []
	for k2 in 6:
		blocos.append(Ruinas._cubo_talhado(1201 + k2 * 7, 1 + k2 % 3))
	o.blocos = blocos
	o.t = Transform3D.IDENTITY
	o.rng.seed = 6262
	o.corpo = StaticBody3D.new()
	o.corpo.name = "TorreQuente"
	o.corpo.collision_layer = 1
	o.corpo.collision_mask = 0
	add_child(o.corpo)
	var corpo := o.corpo
	# a porta fica virada para o lado que desce
	var n := mapa.normal_em(melhor.x, melhor.y)
	var rumo_porta := atan2(n.z, n.x) if Vector2(n.x, n.z).length() > 0.02 else 0.0
	var para_porta := Vector3(cos(rumo_porta), 0, sin(rumo_porta))
	# a base: um soco de concreto que vence o desnível, com uma soleira na frente da porta
	o.bloco(pe + Vector3(0, -3.2, 0), Vector3(perfil(0.0) * 2.25, 6.4, perfil(0.0) * 2.25), Basis(Vector3.UP, -rumo_porta + PI * 0.25), "concreto")
	o.bloco(pe + para_porta * (perfil(0.0) + 3.0) + Vector3(0, -0.9, 0), Vector3(7.0, 1.8, 6.0), Basis(Vector3.UP, -rumo_porta), "concreto")
	# a casca: fiadas de blocos que afinam para cima e abrem de leve na boca, como numa torre de resfriamento
	var fiadas := 20
	var alt_fiada := ALTURA / fiadas
	var por_volta := 18
	for jf in fiadas:
		var y := (jf + 0.5) * alt_fiada
		var raio := perfil(y) + 0.6
		var cai := atan2(perfil(y + alt_fiada * 0.5) - perfil(y - alt_fiada * 0.5), alt_fiada)  # a inclinação da parede ali
		var arco := TAU * raio / por_volta
		for i2 in por_volta:
			var phi := rumo_porta + (i2 + 0.5 * (jf % 2)) * TAU / por_volta
			if jf < 2 and absf(angle_difference(phi, rumo_porta)) < 0.24:
				continue  # a porta
			var mat := "concreto"
			if (jf * 7 + i2 * 3) % 11 == 0:
				mat = "casco_claro"  # remendos mais claros
			elif jf == 13 or jf == 14:
				mat = "tinta_velha" if i2 % 2 == 0 else "concreto"  # o que sobrou da faixa pintada
			o.bloco(pe + Vector3(cos(phi) * raio, y, sin(phi) * raio), Vector3(arco * 1.07, alt_fiada * 1.03, 1.2 + o.j(0.08)),
				Basis(Vector3.UP, PI * 0.5 - phi + o.j(0.012)) * Basis(Vector3.RIGHT, -cai), mat)
	# a boca: um aro mais grosso e uma grade de ferro fechando o alto (por ela só passa a fumaça)
	for i2 in por_volta:
		var phi2 := rumo_porta + i2 * TAU / por_volta
		var rb := perfil(ALTURA) + 0.9
		o.bloco(pe + Vector3(cos(phi2) * rb, ALTURA + 0.5, sin(phi2) * rb), Vector3(TAU * rb / por_volta * 1.08, 1.0, 1.9), Basis(Vector3.UP, PI * 0.5 - phi2), "casco_claro", false)
	var tampa := BoxShape3D.new()
	tampa.size = Vector3(perfil(ALTURA) * 2.2, 0.5, perfil(ALTURA) * 2.2)
	o.forma(tampa, Transform3D(Basis.IDENTITY, pe + Vector3(0, ALTURA + 0.6, 0)))
	for kb in 9:
		var d := (kb - 4) * 2.3
		var meia := sqrt(maxf(1.0, pow(perfil(ALTURA) + 0.4, 2.0) - d * d))
		o.bloco(pe + Vector3(d, ALTURA + 0.65, 0), Vector3(0.28, 0.28, meia * 2.0), Basis.IDENTITY, "ferrugem", false)
		o.bloco(pe + Vector3(0, ALTURA + 0.9, d), Vector3(meia * 2.0, 0.22, 0.22), Basis.IDENTITY, "ferrugem", false)
	# cintas de ferro por fora
	for y2: float in [9.0, 24.0, 40.0, 55.0]:
		var rc := perfil(y2) + 1.28
		for i2 in por_volta:
			var phi3 := rumo_porta + (i2 + 0.5) * TAU / por_volta
			if y2 < 10.0 and absf(angle_difference(phi3, rumo_porta)) < 0.3:
				continue
			o.bloco(pe + Vector3(cos(phi3) * rc, y2, sin(phi3) * rc), Vector3(TAU * rc / por_volta * 1.06, 0.55, 0.16), Basis(Vector3.UP, PI * 0.5 - phi3), "ferrugem", false)
	# a moldura da porta, com a verga e duas folhas de ferro abertas e tortas
	var lado_porta := para_porta.cross(Vector3.UP)
	var rp := perfil(1.0) + 1.3
	for lado: float in [-1.0, 1.0]:
		o.bloco(pe + para_porta * rp + lado_porta * lado * 2.6 + Vector3(0, 2.5, 0), Vector3(0.7, 5.0, 1.8), Basis(Vector3.UP, -rumo_porta + PI * 0.5), "casco_claro", false)
		o.bloco(pe + para_porta * (rp + 1.7) + lado_porta * lado * 3.5 + Vector3(0, 2.2, 0), Vector3(0.14, 4.4, 2.4),
			Basis(Vector3.UP, -rumo_porta + PI * 0.5 + lado * 1.0) * Basis.from_euler(Vector3(o.j(0.05), 0, lado * 0.06)), "ferrugem", false)
	o.bloco(pe + para_porta * rp + Vector3(0, 5.4, 0), Vector3(6.4, 0.9, 1.9), Basis(Vector3.UP, -rumo_porta + PI * 0.5), "casco_claro", false)
	# a escada de marinheiro até o alto, do lado da porta, com um trecho que caiu
	var phi_e := rumo_porta + 0.75
	for ke in 34:
		var ye := 1.5 + ke * 1.75
		if ke >= 19 and ke <= 22:
			continue
		var re := perfil(ye) + 1.55
		var pe2 := pe + Vector3(cos(phi_e) * re, ye, sin(phi_e) * re)
		o.bloco(pe2, Vector3(0.9, 0.08, 0.08), Basis(Vector3.UP, PI * 0.5 - phi_e), "ferrugem", false)
		for lr: float in [-0.45, 0.45]:
			o.bloco(pe2 + Basis(Vector3.UP, PI * 0.5 - phi_e) * Vector3(lr, 0, 0), Vector3(0.07, 1.8, 0.07), Basis(Vector3.UP, PI * 0.5 - phi_e), "ferrugem", false)
	# o duto grosso que sai da torre na direção da Fundição, sobre cavaletes, e some no chão
	var fund := Vector3(Fundicao.CENTRO.x, 0, Fundicao.CENTRO.y) - Vector3(pe.x, 0, pe.z)
	var rumo_f := fund.normalized()
	var ang_f := atan2(rumo_f.z, rumo_f.x)
	for kd in 5:
		var dd := perfil(6.0) + 2.0 + kd * 6.0
		var pd := pe + rumo_f * dd
		var chao_d: float = mapa._fora(pd.x, pd.z)
		var yd := maxf(pe.y + 5.5 - kd * 0.9, chao_d + 1.6)
		MarcosOeste._cilindro(o, Transform3D(Basis(Vector3.UP, -ang_f) * Basis(Vector3.BACK, PI * 0.5), Vector3(pd.x, yd, pd.z)), 1.25, 1.25, 6.1, "ferrugem")
		if kd % 2 == 0:
			o.bloco(Vector3(pd.x, (yd + chao_d) * 0.5 - 0.6, pd.z), Vector3(0.5, maxf(0.6, yd - chao_d - 1.0), 2.8), Basis(Vector3.UP, -ang_f), "casco", false)
		MarcosOeste._cilindro(o, Transform3D(Basis(Vector3.UP, -ang_f) * Basis(Vector3.BACK, PI * 0.5), Vector3(pd.x, yd, pd.z) + rumo_f * 3.0), 1.4, 1.4, 0.4, "casco", false)
	# respiros no pé da casca, acesos por dentro
	for kr in 5:
		var phi_r := rumo_porta + PI * 0.5 + kr * 0.55
		var rr := perfil(2.0) + 1.25
		o.bloco(pe + Vector3(cos(phi_r) * rr, 2.0, sin(phi_r) * rr), Vector3(1.9, 1.5, 0.2), Basis(Vector3.UP, PI * 0.5 - phi_r), "casco", false)
		_bloco(corpo, pe + Vector3(cos(phi_r) * (rr + 0.06), 2.0, sin(phi_r) * (rr + 0.06)), Vector3(1.5, 1.05, 0.12), Color(1.0, 0.42, 0.1), Basis(Vector3.UP, PI * 0.5 - phi_r), false, 1.3)
	# entulho e mato ao pé
	for ke2 in 9:
		var phi_k := o.rng.randf() * TAU
		var rk := perfil(0.0) + o.rng.randf_range(2.0, 7.0)
		var pk := Vector3(pe.x + cos(phi_k) * rk, 0, pe.z + sin(phi_k) * rk)
		pk.y = mapa._fora(pk.x, pk.z)
		if absf(angle_difference(phi_k, rumo_porta)) < 0.5:
			continue
		if ke2 % 3 == 0:
			o.arbusto(pk, o.rng.randf_range(0.8, 1.3))
		else:
			var tam := Vector3(o.rng.randf_range(0.8, 2.2), o.rng.randf_range(0.5, 1.2), o.rng.randf_range(0.8, 2.0))
			o.bloco(pk + Vector3(0, tam.y * 0.3, 0), tam, Basis.from_euler(Vector3(o.j(0.4), o.rng.randf() * TAU, o.j(0.4))), "concreto", tam.x > 1.3)
	# por dentro: a brasa no fundo (de onde o ar sobe) e a grade por cima dela
	_bloco(corpo, pe + Vector3(0, 0.05, 0), Vector3(NUCLEO * 1.7, 0.1, NUCLEO * 1.7), Color(1.0, 0.4, 0.1), Basis(Vector3.UP, 0.4), false, 1.6)
	for kg in 7:
		o.bloco(pe + Vector3((kg - 3) * 1.5, 0.22, 0), Vector3(0.22, 0.14, NUCLEO * 2.0), Basis.IDENTITY, "casco", false)
		o.bloco(pe + Vector3(0, 0.3, (kg - 3) * 1.5), Vector3(NUCLEO * 2.0, 0.1, 0.18), Basis.IDENTITY, "casco", false)
	# anéis de passadiço quebrados pelo caminho (não dá para parar neles: são só a ferragem)
	for ya: float in [18.0, 35.0]:
		for i2 in por_volta:
			if (i2 + int(ya)) % 3 == 0:
				continue
			var phi_a := rumo_porta + i2 * TAU / por_volta
			var ra := perfil(ya) - 0.5
			o.bloco(pe + Vector3(cos(phi_a) * ra, ya, sin(phi_a) * ra), Vector3(TAU * ra / por_volta, 0.1, 0.5), Basis(Vector3.UP, PI * 0.5 - phi_a), "ferrugem", false)
	# a sacada, do lado oposto à porta: uma grade de ferro larga com guarda-corpo, e o receptor
	var fundo := rumo_porta + PI
	var para_fundo := Vector3(cos(fundo), 0, sin(fundo))
	var lado_f := para_fundo.cross(Vector3.UP)
	var rs := perfil(SACADA) - 2.1
	var s2 := pe + para_fundo * rs + Vector3(0, SACADA - 0.3, 0)
	o.bloco(s2, Vector3(4.2, 0.6, 11.0), Basis(Vector3.UP, -fundo), "ferrugem")
	for kc in 3:
		o.bloco(s2 + para_fundo * 1.0 + lado_f * (kc - 1) * 4.2 + Vector3(0, -1.6, 0), Vector3(2.6, 0.3, 0.3), Basis(Vector3.UP, -fundo) * Basis(Vector3.BACK, 0.7), "casco", false)
	o.bloco(s2 - para_fundo * 2.0 + Vector3(0, 1.3, 0), Vector3(0.1, 0.1, 11.0), Basis(Vector3.UP, -fundo), "ferrugem", false)
	for kc in 6:
		if kc == 2:
			continue  # falta um balaústre: é por ali que se chega
		o.bloco(s2 - para_fundo * 2.0 + lado_f * (kc - 2.5) * 2.0 + Vector3(0, 0.8, 0), Vector3(0.1, 1.0, 0.1), Basis.IDENTITY, "ferrugem", false)
	receptor = s2 + para_fundo * 1.0 + Vector3(0, 0.3, 0)
	o.bloco(receptor + Vector3(0, 0.65, 0), Vector3(1.0, 1.3, 2.2), Basis(Vector3.UP, -fundo), "casco")
	o.bloco(receptor + lado_f * 2.3 + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 1.3), Basis(Vector3.UP, -fundo + 0.2), "tinta_velha", false)
	# a tela do receptor (acende de vez depois de ligado), botões e a antena que sobe até a grade
	_bloco(corpo, receptor - para_fundo * 0.52 + Vector3(0, 0.95, 0), Vector3(0.04, 0.5, 1.3), Color(0.3, 0.9, 0.8), Basis(Vector3.UP, -fundo), false, 1.8 if ligado else 0.25)
	for kb2 in 4:
		_bloco(corpo, receptor - para_fundo * 0.52 + lado_f * (kb2 - 1.5) * 0.3 + Vector3(0, 0.45, 0), Vector3(0.05, 0.08, 0.12), Color(1.0, 0.6, 0.2) if kb2 % 2 == 0 else Color(0.4, 0.9, 0.5), Basis(Vector3.UP, -fundo), false, 0.9)
	o.bloco(receptor + lado_f * -0.8 + Vector3(0, (ALTURA - SACADA) * 0.5 + 1.0, 0), Vector3(0.08, ALTURA - SACADA + 1.4, 0.08), Basis.IDENTITY, "ferrugem", false)
	BaseVale._peca(o, "Prop_SatelliteDish", pe + Vector3(0, ALTURA + 1.0, 0) + para_fundo * (perfil(ALTURA) - 2.0), -fundo, 1.6, 0.5, 0.4, false)
	o.fechar()
	# fumaça clara saindo pela grade
	Fundicao._fumaca(self, pe + Vector3(0, ALTURA + 1.5, 0), 9.0, Color(0.75, 0.74, 0.72, 0.3), 18)
	LuzesNoite.por(self, pe + Vector3(0, ALTURA + 2.5, 0), LuzesNoite.BRASA, 8.0)
	# o ar quente que se vê: fagulhas subindo pela coluna
	var fag := CPUParticles3D.new()
	fag.amount = 70
	fag.lifetime = 5.6
	fag.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fag.emission_sphere_radius = NUCLEO * 0.8
	fag.direction = Vector3.UP
	fag.spread = 6.0
	fag.initial_velocity_min = 8.0
	fag.initial_velocity_max = 11.0
	fag.gravity = Vector3.ZERO
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mf.albedo_color = Color(2.2, 1.0, 0.3)
	q.material = mf
	fag.mesh = q
	fag.position = pe + Vector3(0, 0.6, 0)
	add_child(fag)
	for yl: float in [2.0, 26.0, SACADA + 2.0]:
		var brasa := OmniLight3D.new()
		brasa.light_color = Color(1.0, 0.5, 0.2) if yl < SACADA else Color(0.6, 0.9, 0.85)
		brasa.light_energy = 1.5 if yl < 10.0 else 0.8
		brasa.omni_range = 18.0
		brasa.shadow_enabled = false
		brasa.position = pe + Vector3(0, yl, 0) + (para_fundo * (rs - 1.0) if yl > SACADA else Vector3.ZERO)
		add_child(brasa)
	# a luz distante no horizonte: só existe depois de ligado o receptor, e só de noite
	var longe := LuzesNoite.por(self, SINAL, Color(0.75, 0.9, 1.0), 170.0)
	longe.set_meta("so_com", "sinal")


## O raio de dentro da torre a cada altura: larga no pé, afina até dois terços e abre de leve na boca.
static func perfil(y: float) -> float:
	var k := clampf(y / ALTURA, 0.0, 1.0)
	return RAIO + 4.6 * pow(1.0 - minf(k / 0.72, 1.0), 2.0) + 1.1 * pow(maxf(0.0, k - 0.72) / 0.28, 2.0)


func _ligar() -> void:
	ligado = true
	LuzesNoite.ligadas["sinal"] = true
	if Guardado.ativo:
		var d: Dictionary = (Guardado.progresso("achados") as Dictionary).duplicate()
		d["sinal"] = true
		Guardado.por_progresso("achados", d)
	if hud:
		hud.dica = ""
		hud.avisar("O receptor ligou", "de noite, procure uma luz no mar, a sudoeste")
	if memorias:
		memorias.abrir("sinal_de_fora")


func _physics_process(delta: float) -> void:
	if armadura == null or not pe.is_finite():
		return
	var p := armadura.global_position
	var d := Vector2(p.x - pe.x, p.z - pe.z).length()
	dentro = d < NUCLEO and p.y > pe.y - 0.5 and p.y < pe.y + SACADA + 3.0
	if not dentro:
		armadura.calor_extra = 0.0
		return
	# o ar quente esquenta sempre; só sustenta quem não superaqueceu e está fora do chão
	armadura.calor_extra = CALOR * Melhorias.calor_voo() / 1.65
	if not armadura.superaquecido and armadura.estado != Armadura.Estado.CHAO and p.y < pe.y + SACADA + 1.2:
		armadura.velocity.y = move_toward(armadura.velocity.y, SOBE, 60.0 * delta)
	if not _avisou and hud:
		_avisou = true
		hud.aconselhar("O ar quente leva para cima, mas esquenta o motor. Pule para dentro dele.", 8.0)


func _process(_delta: float) -> void:
	if armadura == null or not receptor.is_finite() or get_tree().paused:
		return
	var convite := ""
	if not ligado and armadura.estado == Armadura.Estado.CHAO and armadura.global_position.distance_to(receptor) < PERTO:
		convite = "{agir}  ligar o receptor"
	if hud:
		if convite != "":
			hud.dica = convite
			_dica_minha = convite
		elif _dica_minha != "" and hud.dica == _dica_minha:
			hud.dica = ""
			_dica_minha = ""
	if convite != "" and Input.is_action_just_pressed("agir"):
		_ligar()
