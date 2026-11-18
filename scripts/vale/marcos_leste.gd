class_name MarcosLeste
extends RefCounted
## Os marcos altos do leste da ilha de 3 km (2026-11-18, doc §80): A Represa Rachada nas Encostas do Dique,
## O Farol Apagado na ponta do Cabo do Vento e O Sono dos Gigantes entre os Campos do Sul e o Platô.
## Construções de concreto e metal, velhas: ferrugem, musgo e mato tomando conta. Tudo com colisão.
## A represa e o farol são montados bloco a bloco com a Obra das ruínas; os gigantes são mechas do pacote
## ampliados, desligados há muito tempo (ninguém é destruído: eles dormem).

const REPRESA := Vector2(Vale.REPRESA_X, -335.0)
const REPRESA_MEIA := 48.0  # metade do comprimento da parede
const REPRESA_BOJO := 7.0  # quanto a parede avança para dentro da lagoa no meio
const REPRESA_TOPO := 40.0  # altura do alto da parede (a água fica a 26)
const ROMBO := 3.0  # onde fica o rombo, ao longo da parede (m a partir do meio)
const FAROL := Vector2(1338.0, -1338.0)
const FAROL_ALTURA := 62.0
const FAROL_PE := 7.6  # raio da torre no pé
const FAROL_ALTO := 4.5  # e no alto
const GIGANTES := Vector2(470.0, 400.0)
## cada gigante: [x, z a partir do meio, giro, altura do modelo, postura, quanto afunda]
## (na primeira versão tinham 22 a 34 m e sumiam entre as árvores: não eram colossais)
const DORMINDO := [[-70.0, -40.0, 0.6, 62.0, "deitado", 4.0], [44.0, 6.0, 2.5, 74.0, "de_pe", 31.0], [10.0, 88.0, 4.3, 54.0, "deitado", 3.5],
	[-96.0, 56.0, 1.4, 50.0, "de_pe", 22.0]]

static var farol_topo := Vector3.INF
static var represa_meio := Vector3.INF
static var gigantes: Array[Node3D] = []
static var pedras_cabo := 0
static var triangulos := 0  # da colisão dos gigantes
static var malhas: Array[PackedVector3Array] = []  # a colisão de cada gigante, como foi calculada (testes)


## O eixo da parede da represa (x do mundo) na posição `dz` ao longo dela: em arco, bojuda para a lagoa.
static func represa_x(dz: float) -> float:
	var k := clampf(dz / REPRESA_MEIA, -1.0, 1.0)
	return REPRESA.x - REPRESA_BOJO * (1.0 - k * k)


## Árvore, planta ou bicho pode ficar aqui? (não dentro das obras)
static func livre(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if not MarcosMar.livre(x, z) or not FendaEscura.livre(x, z) or not MarcosOeste.livre(x, z):
		return false
	if absf(z - REPRESA.y) < REPRESA_MEIA + 10.0 and absf(x - REPRESA.x) < 30.0:
		return false
	if p.distance_to(FAROL) < 24.0:
		return false
	for g: Array in DORMINDO:
		if p.distance_to(GIGANTES + Vector2(g[0], g[1])) < float(g[3]) * 0.62:
			return false
	return true


static func montar(v: Vale) -> void:
	var t0 := Time.get_ticks_msec()
	gigantes.clear()
	malhas.clear()
	triangulos = 0
	var blocos: Array[PackedVector3Array] = []
	for k in 6:
		blocos.append(Ruinas._cubo_talhado(211 + k * 7, 2 + k % 3))
	var tambores: Array[PackedVector3Array] = []
	for k in 3:
		tambores.append(Ruinas._tambor(31 + k * 3))
	var pecas := 0
	for sitio: Array in [["Represa", REPRESA], ["Farol", FAROL]]:
		var c: Vector2 = sitio[1]
		var o := Ruinas.Obra.new()
		o.v = v
		o.blocos = blocos
		o.tambores = tambores
		# a origem da obra fica no nível do mar: as alturas das peças são as do mundo
		o.t = Transform3D(Basis.IDENTITY, Vector3(c.x, 0.0, c.y))
		o.rng.seed = hash(sitio[0])
		o.corpo = StaticBody3D.new()
		o.corpo.name = "Marco" + sitio[0]
		o.corpo.collision_layer = 1
		o.corpo.collision_mask = 0
		v.add_child(o.corpo)
		if sitio[0] == "Represa":
			_represa(o)
		else:
			_farol(o)
		o.fechar()
		pecas += o.pecas
	_gigantes(v)
	_pedras_do_cabo(v)
	Marcos.lugares.append(["A Represa Rachada", REPRESA, 70.0])
	Marcos.lugares.append(["O Farol Apagado", FAROL, 60.0])
	Marcos.lugares.append(["O Sono dos Gigantes", GIGANTES, 90.0])
	print("marcos do leste: %d peças na represa e no farol, %d gigantes (%d triângulos de colisão), %d ms" % [pecas, gigantes.size(), triangulos, Time.get_ticks_msec() - t0])


# ---------------------------------------------------------------- A Represa Rachada

## Uma parede de concreto em arco que fecha a garganta da lagoa, com um rombo no meio por onde a água cai.
## Mais grossa embaixo, com um passadiço no alto, escoras do lado de baixo e ferragem aparecendo no rombo.
static func _represa(o: Ruinas.Obra) -> void:
	var v := o.v
	var fiada := 3.0
	var passo := 4.6
	var n_lado := int(ceil(REPRESA_MEIA / passo))
	var y := 8.0
	var jf := 0
	while y < REPRESA_TOPO - 0.1:
		var yc := y + fiada * 0.5
		var alto := clampf((yc - 10.0) / (REPRESA_TOPO - 10.0), 0.0, 1.0)
		var grossura := lerpf(7.5, 3.2, alto)
		for i in range(-n_lado, n_lado + 1):
			var dz := (i + 0.5 * (jf % 2)) * passo
			if absf(dz) > REPRESA_MEIA + 1.0:
				continue
			var x := represa_x(dz) - REPRESA.x
			# o chão dos dois lados da parede: pedra enterrada no barranco não é montada
			var chao := minf(v._fora(REPRESA.x + x - 5.0, REPRESA.y + dz), v._fora(REPRESA.x + x + 5.0, REPRESA.y + dz))
			if y + fiada < chao - 1.0:
				continue
			# o rombo: um V torto de cima até a linha d'água
			var meia := 0.9 + maxf(0.0, yc - Vale.REPRESA_NIVEL) * 0.95 + o.j(0.5)
			if yc > Vale.REPRESA_NIVEL - 0.4 and absf(dz - ROMBO) < meia:
				continue
			var tang := atan2(represa_x(dz + 1.0) - represa_x(dz - 1.0), 2.0)
			o.bloco(Vector3(x + lerpf(1.0, 0.0, alto), yc, dz), Vector3(grossura + o.j(0.2), fiada + 0.06, passo * 1.05),
				Basis(Vector3.UP, tang + o.j(0.012)), "concreto")
		y += fiada
		jf += 1
	# o passadiço no alto, com o corrimão de ferro; no rombo ele pende, partido
	for i in range(-n_lado, n_lado + 1):
		var dz := i * passo
		if absf(dz) > REPRESA_MEIA:
			continue
		var x := represa_x(dz) - REPRESA.x
		var tang := atan2(represa_x(dz + 1.0) - represa_x(dz - 1.0), 2.0)
		var perto_rombo := absf(dz - ROMBO)
		if perto_rombo < 8.5:
			if perto_rombo > 5.5:
				# as pontas da laje, caídas para dentro do rombo
				var cai := 0.5 * signf(dz - ROMBO)
				o.bloco(Vector3(x, REPRESA_TOPO - 1.2, dz - cai * 2.0), Vector3(4.4, 0.5, passo), Basis(Vector3.UP, tang) * Basis(Vector3.RIGHT, -cai), "concreto")
			continue
		o.bloco(Vector3(x, REPRESA_TOPO + 0.25, dz), Vector3(4.6, 0.5, passo * 1.02), Basis(Vector3.UP, tang), "concreto")
		for lado: float in [-2.05, 2.05]:
			if o.rng.randf() < 0.75:
				o.bloco(Vector3(x + lado, REPRESA_TOPO + 1.05, dz), Vector3(0.12, 0.12, passo), Basis(Vector3.UP, tang) * Basis(Vector3.RIGHT, o.j(0.05)), "ferrugem", false)
			if i % 2 == 0:
				o.bloco(Vector3(x + lado, REPRESA_TOPO + 0.8, dz), Vector3(0.14, 0.9, 0.14), Basis(Vector3.UP, tang), "ferrugem", false)
	# escoras do lado de baixo (leste): contrafortes inclinados de concreto
	for dz: float in [-24.0, -12.0, 15.0, 26.0]:
		var x := represa_x(dz) - REPRESA.x
		var chao := v._fora(REPRESA.x + x + 7.0, REPRESA.y + dz)
		var topo := REPRESA_TOPO - 6.0
		if topo - chao < 4.0:
			continue
		o.bloco(Vector3(x + 5.0, (chao + topo) * 0.5 - 1.0, dz), Vector3(3.0, topo - chao + 3.0, 2.6), Basis(Vector3.BACK, 0.2), "concreto")
	# ferragem torta aparecendo nas beiras do rombo
	for k in 9:
		var lado_r := -1.0 if k % 2 == 0 else 1.0
		var yk := Vale.REPRESA_NIVEL + 0.6 + k * 0.75
		var dz := ROMBO + lado_r * (1.0 + (yk - Vale.REPRESA_NIVEL) * 0.95)
		o.bloco(Vector3(represa_x(dz) - REPRESA.x + o.j(1.0), yk, dz - lado_r * 0.9), Vector3(0.1, 0.1, 2.2 + o.j(0.6)),
			Basis.from_euler(Vector3(o.j(0.5), o.j(0.4), o.j(0.3))), "ferrugem", false)
	# pedaços da parede caídos no leito, ao pé do rombo
	for k in 9:
		var p := Vector2(represa_x(ROMBO) - REPRESA.x + 6.0 + o.rng.randf() * 16.0, ROMBO + o.j(9.0))
		var tam := Vector3(o.rng.randf_range(1.6, 4.2), o.rng.randf_range(1.2, 2.6), o.rng.randf_range(1.6, 3.8))
		o.bloco(Vector3(p.x, v._fora(REPRESA.x + p.x, REPRESA.y + p.y) + tam.y * 0.25, p.y), tam,
			Basis.from_euler(Vector3(o.j(0.5), o.rng.randf() * TAU, o.j(0.5))), "concreto")
	# mato no alto e nas escoras
	for k in 16:
		var dz := o.j(REPRESA_MEIA - 2.0)
		if absf(dz - ROMBO) < 9.0:
			continue
		o.arbusto(Vector3(represa_x(dz) - REPRESA.x + o.j(1.6), REPRESA_TOPO + 0.45, dz), o.rng.randf_range(0.7, 1.3))
	_agua_da_represa(v)
	represa_meio = Vector3(represa_x(ROMBO), Vale.REPRESA_NIVEL, REPRESA.y + ROMBO)


## A água entre o disco da lagoa e a parede (o disco é redondo, a parede não) e a queda pelo rombo.
static func _agua_da_represa(v: Vale) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := REPRESA.x - 46.0
	var passo := 4.0
	var dz := -REPRESA_MEIA
	while dz < REPRESA_MEIA:
		var a := Vector3(x0, 0, REPRESA.y + dz)
		var b := Vector3(represa_x(dz) - 0.6, 0, REPRESA.y + dz)
		var c := Vector3(represa_x(dz + passo) - 0.6, 0, REPRESA.y + dz + passo)
		var d := Vector3(x0, 0, REPRESA.y + dz + passo)
		for p: Vector3 in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p.x, p.z) * 0.05)
			st.add_vertex(p)
		dz += passo
	var lamina := MeshInstance3D.new()
	lamina.name = "AguaDaRepresa"
	lamina.mesh = st.commit()
	lamina.material_override = v._mat_rio(66, 0.08)
	lamina.position = Vector3(0, Vale.REPRESA_NIVEL - 0.02, 0)
	lamina.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(lamina)
	# a queda: sai do rombo, na linha d'água, e cai no começo do córrego
	var ruido_q := NoiseTexture2D.new()
	ruido_q.width = 256
	ruido_q.height = 256
	ruido_q.seamless = true
	ruido_q.noise = v._ruido(67, 1.0 / 14.0, 3)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/cachoeira.gdshader")
	mat.set_shader_parameter("ruido", ruido_q)
	var topo := Vector3(represa_x(ROMBO) + 1.0, Vale.REPRESA_NIVEL - 0.15, REPRESA.y + ROMBO)
	var pe_x := REPRESA.x + 7.0
	var pe := Vector3(pe_x, v._fora(pe_x, REPRESA.y + ROMBO) + 0.5, REPRESA.y + ROMBO)
	var dir := Vector3(1, 0, 0)
	var lado := Vector3(0, 0, 1)
	var q := SurfaceTool.new()
	q.begin(Mesh.PRIMITIVE_TRIANGLES)
	var linhas := 18
	for k in linhas:
		var faixa: Array = []
		for t: float in [float(k) / linhas, float(k + 1) / linhas]:
			var centro := Vector3(lerpf(topo.x, pe.x, pow(t, 0.55)), lerpf(topo.y, pe.y, t * t * 0.4 + t * 0.6), topo.z)
			faixa.append([centro, 2.2 * lerpf(0.85, 1.3, t), lerpf(0.7, 1.7, t), t])
		var colunas := 8
		for cn in colunas:
			for canto: Array in [[cn, 0], [cn + 1, 0], [cn + 1, 1], [cn, 0], [cn + 1, 1], [cn, 1]]:
				var u := float(canto[0]) / colunas
				var ang := PI * u
				var f: Array = faixa[canto[1]]
				var fora := (dir * sin(ang) - lado * cos(ang)).normalized()
				q.set_normal((fora + Vector3.UP * 0.2).normalized())
				q.set_uv(Vector2(u, f[3]))
				q.add_vertex((f[0] as Vector3) - lado * cos(ang) * float(f[1]) + dir * (sin(ang) * float(f[2]) - 0.4))
	var queda := MeshInstance3D.new()
	queda.name = "QuedaDaRepresa"
	queda.mesh = q.commit()
	queda.material_override = mat
	queda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(queda)
	v.quedas.append((topo + pe) * 0.5)
	v.cortinas.append([topo, pe, 3.2])


# ---------------------------------------------------------------- O Farol Apagado

## Uma torre alta e inclinada na ponta do cabo: faixas de tinta velha, o alto quebrado, a gaiola da
## lanterna enferrujada e o que sobrou da lente. É oca e aberta em cima: dá para pousar no balcão e entrar.
static func _farol(o: Ruinas.Obra) -> void:
	var v := o.v
	var chao := v._fora(FAROL.x, FAROL.y)
	# pende para o mar (nordeste): o eixo sai do prumo uns 11 graus
	var eixo := Basis(Vector3(1, 0, 1).normalized(), -0.19)  # eram 6 graus e de longe não se notava
	var pe := Vector3(0, chao - 1.5, 0)
	var fiada := 2.4
	var fiadas := int(FAROL_ALTURA / fiada)
	var por_volta := 16
	for jf in fiadas:
		var alto := float(jf) / fiadas
		var raio := lerpf(FAROL_PE, FAROL_ALTO, alto)
		var arco := TAU * raio / por_volta
		var mat := "concreto_pintado" if (jf / 4) % 2 == 1 else "concreto"
		for i in por_volta:
			var phi := (i + 0.5 * (jf % 2)) * TAU / por_volta
			# a porta, no pé, virada para a terra (sudoeste)
			if jf < 2 and absf(angle_difference(phi, PI * 0.75)) < 0.35:
				continue
			# o alto quebrado: faltam pedras do lado do mar, cada vez mais para cima
			if alto > 0.78 and absf(angle_difference(phi, -PI * 0.25)) < (alto - 0.78) * 7.0 + o.j(0.25):
				continue
			# uma racha que sobe em espiral
			if absf(angle_difference(phi, 1.2 + alto * 2.4)) < 0.2 and jf % 4 == 2:
				continue
			var centro := pe + eixo * Vector3(cos(phi) * raio, (jf + 0.5) * fiada, sin(phi) * raio)
			o.bloco(centro, Vector3(arco * 1.07, fiada + 0.04, 1.3 + o.j(0.08)), eixo * Basis(Vector3.UP, PI * 0.5 - phi + o.j(0.012)), mat)
	var topo_y := fiadas * fiada
	# o balcão: uma laje redonda que sobra para fora, e o corrimão de ferro com falhas
	var laje := pe + eixo * Vector3(0, topo_y, 0)
	for i in 16:
		var phi := i * TAU / 16.0
		if absf(angle_difference(phi, -PI * 0.25)) < 0.5:
			continue  # o pedaço do lado do mar caiu
		var c := pe + eixo * Vector3(cos(phi) * (FAROL_ALTO + 1.3), topo_y + 0.25, sin(phi) * (FAROL_ALTO + 1.3))
		o.bloco(c, Vector3((FAROL_ALTO + 1.3) * 0.42, 0.5, 3.4), eixo * Basis(Vector3.UP, PI * 0.5 - phi), "concreto")
		if i % 2 == 0 and o.rng.randf() < 0.8:
			var cp := pe + eixo * Vector3(cos(phi) * (FAROL_ALTO + 2.8), topo_y + 1.1, sin(phi) * (FAROL_ALTO + 2.8))
			o.bloco(cp, Vector3(0.14, 1.3, 0.14), eixo, "ferrugem", false)
			o.bloco(cp + eixo * Vector3(0, 0.65, 0), Vector3(2.6, 0.1, 0.1), eixo * Basis(Vector3.UP, PI * 0.5 - phi), "ferrugem", false)
	# o piso da lanterna, por dentro do balcão (com um buraco no meio: a escada caiu)
	for i in 8:
		var phi := i * TAU / 8.0 + 0.2
		o.bloco(pe + eixo * Vector3(cos(phi) * 2.9, topo_y + 0.25, sin(phi) * 2.9), Vector3(2.5, 0.5, 2.8), eixo * Basis(Vector3.UP, PI * 0.5 - phi), "casco")
	# a gaiola da lanterna: oito montantes de ferro, dois aros e o chapéu de chapa, torto
	for i in 8:
		var phi := i * TAU / 8.0
		if i == 7:
			continue  # um montante faltando
		o.bloco(pe + eixo * Vector3(cos(phi) * 3.5, topo_y + 3.4, sin(phi) * 3.5), Vector3(0.26, 6.0, 0.26), eixo * Basis(Vector3.UP, -phi), "ferrugem", false)
		o.bloco(pe + eixo * Vector3(cos(phi + 0.39) * 3.3, topo_y + 6.3, sin(phi + 0.39) * 3.3), Vector3(0.18, 0.18, 2.8), eixo * Basis(Vector3.UP, -phi - 0.39), "ferrugem", false)
	for i in 8:
		var phi := i * TAU / 8.0 + 0.39
		var c := pe + eixo * Vector3(cos(phi) * 1.9, topo_y + 7.4, sin(phi) * 1.9)
		o.bloco(c, Vector3(2.9, 0.12, 4.0), eixo * Basis(Vector3.UP, PI * 0.5 - phi) * Basis(Vector3.RIGHT, 0.5), "ferrugem")
	# a lente: o que sobrou de um globo de vidro grosso, com os aros de latão
	var lente := laje + eixo * Vector3(0, 3.0, 0)
	o.bola(lente, 1.9, "vidro_velho")
	o.aro(lente + Vector3(0, 0.6, 0), 1.85, 2.15, "casco_claro")
	o.aro(lente + Vector3(0, -0.9, 0), 1.65, 1.95, "casco_claro")
	var esfera := SphereShape3D.new()
	esfera.radius = 2.0
	o.forma(esfera, Transform3D(Basis.IDENTITY, lente))
	# cacos e pedras caídas em volta do pé, mais do lado para onde ela pende
	o.entulho(Vector2(6.0, -6.0), Vector2(18.0, 18.0), 26, 0.9, 3.0)
	for k in 12:
		var a := o.rng.randf() * TAU
		var r := o.rng.randf_range(8.5, 12.0)
		o.arbusto(Vector3(cos(a) * r, v._fora(FAROL.x + cos(a) * r, FAROL.y + sin(a) * r), sin(a) * r), o.rng.randf_range(0.8, 1.4))
	# mato subindo pela parede do lado da terra: touceiras presas à pedra, mais ralas para cima
	for k in 34:
		var alto_m := pow(o.rng.randf(), 1.7)
		var phi_m := PI * 0.75 + o.j(1.5)
		var raio_m := lerpf(FAROL_PE, FAROL_ALTO, alto_m * 0.6) + 0.5
		o.arbusto(pe + eixo * Vector3(cos(phi_m) * raio_m, alto_m * 0.6 * FAROL_ALTURA + 0.6, sin(phi_m) * raio_m), o.rng.randf_range(0.9, 1.7) * (1.0 - alto_m * 0.5))
	farol_topo = o.t * laje


# ---------------------------------------------------------------- O Sono dos Gigantes

## Robôs colossais de terraplanagem, desligados há tanto tempo que o mato tomou conta: dois deitados, meio
## enterrados, e dois de pé, enterrados até a cintura. Costas e braços viram plataformas para pousar.
static func _gigantes(v: Vale) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "Gigantes"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	v.add_child(corpo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var k := 0
	for g: Array in DORMINDO:
		var c := GIGANTES + Vector2(g[0], g[1])
		var alt: float = g[3]
		var deitado: bool = g[4] == "deitado"
		var gigante := Mech00Visual.montar(9100 + k * 17, alt, v._tex)
		v.add_child(gigante)
		gigante.position = Vector3(c.x, v._fora(c.x, c.y), c.y)
		gigante.rotation.y = g[2]
		gigante.tocar("Death" if deitado else "Idle", 1.0, 0.0)
		# a pose final já, e parada: os ossos dão o lugar de cada parte do corpo
		gigante.anim.seek(gigante.anim.current_animation_length if deitado else 0.0, true)
		gigante.anim.pause()
		# O mecha caído se ergue sozinho a cada quadro até o osso mais baixo encostar no chão
		# (MechVisual._process). Aqui o corpo é assentado à mão, logo abaixo; com o ajuste ligado ele subia até
		# 4 m depois de a colisão estar calculada, e o usuário atravessava o que via.
		gigante.set_process(false)
		gigante.olho(0.0)
		# a tinta de fábrica já se foi: ferrugem e pó, com as cores quase apagadas
		gigante.mat.set_shader_parameter("tinta", Color(0.8, 0.76, 0.72))
		gigante.mat.set_shader_parameter("desbotado", 0.85)
		gigante.apagar(0.35)
		gigantes.append(gigante)
		var esq := gigante.esqueleto
		esq.force_update_all_bone_transforms()
		if deitado:
			# O corpo cai para um lado a partir dos pés, e o chão ali é ladeira: apoiado só na altura dos pés,
			# o resto ficava no ar (o usuário viu um com "a bunda flutuando"). Aqui o corpo se inclina com o
			# chão que tem debaixo dele e desce até encostar.
			var pts := _ossos(esq)
			var meio := Vector2.ZERO
			for q: Vector3 in pts:
				meio += Vector2(q.x, q.z)
			meio /= pts.size()
			var r := alt * 0.3
			var nrm := Vector3(-(v._fora(meio.x + r, meio.y) - v._fora(meio.x - r, meio.y)) / (2.0 * r), 1.0,
				-(v._fora(meio.x, meio.y + r) - v._fora(meio.x, meio.y - r)) / (2.0 * r)).normalized()
			# gira em volta do meio do corpo, para o chão debaixo dele continuar sendo o mesmo
			var eixo_g := Vector3(meio.x, v._fora(meio.x, meio.y), meio.y)
			var inclina := Transform3D(Basis(Quaternion(Vector3.UP, nrm)), Vector3.ZERO)
			gigante.global_transform = Transform3D(Basis.IDENTITY, eixo_g) * inclina * Transform3D(Basis.IDENTITY, -eixo_g) * gigante.global_transform
			esq.force_update_all_bone_transforms()
		# desce até um quarto dos ossos ficar abaixo do chão (os de pé: enterrados até a cintura)
		var folgas: Array[float] = []
		for q: Vector3 in _ossos(esq):
			folgas.append(q.y - v._fora(q.x, q.z))
		folgas.sort()
		var desce := folgas[int(folgas.size() * 0.25)] + alt * 0.035 if deitado else float(g[5])
		gigante.global_position.y -= desce
		if not deitado:
			gigante.rotation.x = 0.07 * (1.0 if k % 2 == 0 else -1.0)  # um pouco tombado
		esq.force_update_all_bone_transforms()
		# A colisão é a própria malha do corpo, calculada na pose em que ele dorme: o que se vê é o que barra
		# e o que sustenta. (Antes foram duas caixas largas, que faziam parede invisível, e depois cápsulas
		# por osso, que deixavam atravessar chapas e barravam em vãos: o usuário pediu a física real.)
		var faces := MalhaCorpo.faces(gigante, esq)
		malhas.append(faces)
		corpo.add_child(MalhaCorpo.forma(faces))
		triangulos += faces.size() / 3
		Obstaculos.registrar(c.x, c.y, alt * 0.2)
		# árvores e mato crescendo em cima deles: em faces largas viradas para cima
		var pousos: Array[Vector3] = []
		var f := 0
		while f + 2 < faces.size():
			var n := (faces[f + 1] - faces[f]).cross(faces[f + 2] - faces[f])
			if absf(n.normalized().y) > 0.8 and n.length() > alt * alt * 0.004:
				var meio_f := (faces[f] + faces[f + 1] + faces[f + 2]) / 3.0
				if meio_f.y > v._fora(meio_f.x, meio_f.z) + 2.0:
					pousos.append(meio_f)
			f += 3
		for i in 9:
			if pousos.is_empty():
				break
			var pt: Vector3 = pousos[rng.randi() % pousos.size()]
			var planta: String = ["q_betula_a", "arbusto", "q_arvore_a", "arbusto", "q_pinheiro_b", "arbusto", "q_samambaia"][i % 7]
			if v._malhas.has(planta):
				var es := rng.randf_range(0.7, 1.2) * (1.6 if planta == "arbusto" else 1.0)
				v._por(planta, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * es), pt - Vector3(0, 0.3, 0)))
		# mato e pedras encostados neles
		for i in 12:
			var a := rng.randf() * TAU
			var r2 := alt * rng.randf_range(0.18, 0.45)
			var p2 := c + Vector2(cos(a), sin(a)) * r2
			var nome: String = ["arbusto", "q_samambaia", "q_moita_flor", "q_pedra_a", "q_pedra_b"][i % 5]
			if v._malhas.has(nome):
				v._por(nome, Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * rng.randf_range(1.6, 3.4)), Vector3(p2.x, v._fora(p2.x, p2.y) - 0.1, p2.y)))
		k += 1


## Onde está cada osso do corpo, no mundo (sem os de controle, que ficam longe do corpo).
static func _ossos(esq: Skeleton3D) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for i in esq.get_bone_count():
		var nome_o := esq.get_bone_name(i).to_lower()
		if nome_o.contains("ik") or nome_o.contains("pole") or nome_o.contains("dummy") or nome_o.contains("attach"):
			continue
		pts.append(esq.global_transform * esq.get_bone_global_pose(i).origin)
	return pts


# ---------------------------------------------------------------- o campo pedregoso do Cabo do Vento

## O Cabo era capim liso: aqui entram as pedras espalhadas, mais juntas perto da ponta e do penhasco.
static func _pedras_do_cabo(v: Vale) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var postas := 0
	var tentativas := 0
	var por_tipo := {}
	var corpo := StaticBody3D.new()
	corpo.name = "PedrasDoCabo"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	v.add_child(corpo)
	while postas < 230 and tentativas < 4000:
		tentativas += 1
		var p := Vector2(rng.randf_range(820.0, 1420.0), rng.randf_range(-1420.0, -880.0))
		# só no cabo: a nordeste da linha que vai de (820, -1180) a (1180, -880)
		if p.x - 820.0 + (p.y + 1180.0) * 1.2 < 0.0:
			continue
		var h := v._fora(p.x, p.y)
		if h < 6.0 or v.normal_em(p.x, p.y).y < 0.9 or p.distance_to(FAROL) < 26.0 or v.agua(p.x, p.y) > -INF:
			continue
		var sorte := rng.randf()
		var nome: String = "q_pedra_a" if sorte < 0.35 else ("q_pedra_b" if sorte < 0.7 else ("q_pedra_c" if sorte < 0.9 else "pedra_alta"))
		if not v._malhas.has(nome):
			nome = "pedra_a"
		if not v._malhas.has(nome):
			return
		var es := rng.randf_range(1.2, 3.2) if sorte < 0.9 else rng.randf_range(1.5, 2.6)
		var xf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3.ONE * es),
			Vector3(p.x, h - 0.25 * es, p.y))
		if not por_tipo.has(nome):
			por_tipo[nome] = []
		(por_tipo[nome] as Array).append(xf)
		if es > 2.2:
			# as grandes barram o caminho: uma esfera do tamanho delas
			var f := SphereShape3D.new()
			f.radius = es * 0.55
			var cs := CollisionShape3D.new()
			cs.shape = f
			cs.position = Vector3(p.x, h + es * 0.2, p.y)
			corpo.add_child(cs)
			Obstaculos.registrar(p.x, p.y, es * 0.55)
		postas += 1
	# desenhadas em lote, um por tipo, e só até 900 m (soltas, uma a uma, pesavam na vista do cume)
	for nome_t: String in por_tipo:
		var xfs: Array = por_tipo[nome_t]
		v._multi(nome_t, xfs, v._centro(xfs), 0.0, 900.0, true)
	pedras_cabo = postas
