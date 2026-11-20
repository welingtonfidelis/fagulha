class_name MarcosMar
extends RefCounted
## Os lugares de água da ilha de 3 km (2026-11-18, doc §81): O Cais Submerso na baía da Costa Quebrada,
## A Ilha do Relé no Arquipélago Raso e os pilares da ponte antiga que ligava a costa às ilhotas.
## Concreto e ferro velhos: o cais meio afundado, guindastes saindo da água, contêineres no fundo.
## Tudo montado com a Obra das ruínas (blocos com colisão) e algumas peças do kit da base.

const CAIS := Vector2(806.0, 902.0)  # onde o cais sai da praia
const CAIS_RUMO := 0.36  # para onde ele avança (radianos, a partir do leste, virando para o sul)
const CAIS_COMP := 132.0
const RELE := Vector2(1282.0, 648.0)  # o pé da torre, no alto da ilhota
const RELE_ALTURA := 46.0
## a ponte antiga: da costa à Ilha do Relé e dela à ilhota do sul
const PONTE := [[Vector2(1072.0, 640.0), Vector2(1206.0, 640.0), 6], [Vector2(1300.0, 712.0), Vector2(1326.0, 868.0), 6]]

static var cais_ponta := Vector3.INF
static var rele_topo := Vector3.INF
static var conteiner_aberto := Vector3.INF  # no fundo da baía (a etapa das peças põe uma ali dentro)
static var pilares := 0
static var conteineres := 0


static func livre(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	var d := Vector2(cos(CAIS_RUMO), sin(CAIS_RUMO))
	var t := clampf((p - CAIS).dot(d), -34.0, CAIS_COMP)
	if p.distance_to(CAIS + d * t) < 22.0:
		return false
	return p.distance_to(RELE) > 16.0


static func montar(v: Vale) -> void:
	var t0 := Time.get_ticks_msec()
	pilares = 0
	conteineres = 0
	var blocos: Array[PackedVector3Array] = []
	for k in 6:
		blocos.append(Ruinas._cubo_talhado(307 + k * 7, 2 + k % 3))
	var tambores: Array[PackedVector3Array] = []
	for k in 3:
		tambores.append(Ruinas._tambor(41 + k * 3))
	var pecas := 0
	for sitio: Array in [["Cais", CAIS, -CAIS_RUMO], ["Rele", RELE, 0.0], ["Ponte", Vector2.ZERO, 0.0]]:
		var c: Vector2 = sitio[1]
		var o := Ruinas.Obra.new()
		o.v = v
		o.blocos = blocos
		o.tambores = tambores
		# a origem da obra fica no nível do mar: as alturas das peças são as do mundo
		o.t = Transform3D(Basis(Vector3.UP, sitio[2]), Vector3(c.x, 0.0, c.y))
		o.rng.seed = hash(sitio[0])
		o.corpo = StaticBody3D.new()
		o.corpo.name = "Marco" + sitio[0]
		o.corpo.collision_layer = 1
		o.corpo.collision_mask = 0
		v.add_child(o.corpo)
		match sitio[0]:
			"Cais":
				_cais(o)
			"Rele":
				_rele(o)
			"Ponte":
				_ponte(o)
		o.fechar()
		pecas += o.pecas
	Marcos.lugares.append(["O Cais Submerso", CAIS + Vector2(cos(CAIS_RUMO), sin(CAIS_RUMO)) * 60.0, 95.0])
	Marcos.lugares.append(["A Ilha do Relé", RELE, 75.0])
	print("marcos do mar: %d peças, %d contêineres, %d pilares, %d ms" % [pecas, conteineres, pilares, Time.get_ticks_msec() - t0])


## O fundo (ou o chão) num ponto da obra, na altura do mundo.
static func _fundo(o: Ruinas.Obra, lx: float, lz: float) -> float:
	var p := o.t * Vector3(lx, 0, lz)
	return o.v._fora(p.x, p.z)


## Uma treliça de ferro de `a` até `b`: quatro banzos e as diagonais, com uma caixa só de colisão.
## A colisão de uma perna de torre: uma caixa fina de `a` a `b`.
static func perna_colisao(o: Ruinas.Obra, a: Vector3, b: Vector3, grossura: float) -> void:
	var cx := BoxShape3D.new()
	cx.size = Vector3(grossura, grossura, a.distance_to(b))
	o.forma(cx, Transform3D(Basis.looking_at((b - a).normalized(), Vector3.RIGHT), (a + b) * 0.5))


static func _trelica(o: Ruinas.Obra, a: Vector3, b: Vector3, larg: float, fio := 0.16, mat := "ferrugem", colide := true) -> void:
	var eixo := b - a
	var comp := eixo.length()
	if comp < 0.5:
		return
	var z := eixo / comp
	var x := z.cross(Vector3.UP)
	if x.length() < 0.05:
		x = z.cross(Vector3.RIGHT)
	x = x.normalized()
	var y := x.cross(z).normalized()
	var base := Basis(x, y, z)
	var meio := (a + b) * 0.5
	var h := larg * 0.5
	for canto: Vector2 in [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]:
		o.bloco(meio + x * canto.x + y * canto.y, Vector3(fio, fio, comp), base, mat, false)
	var n := maxi(1, int(comp / (larg * 1.25)))
	for k in n:
		var z0 := -comp * 0.5 + comp * k / n
		var z1 := -comp * 0.5 + comp * (k + 1) / n
		var dz := z1 - z0
		var diag := sqrt(dz * dz + larg * larg)
		var ang := atan2(larg, dz)
		var s := 1.0 if k % 2 == 0 else -1.0
		# uma diagonal em cada face, alternando o sentido
		o.bloco(meio + y * h + z * (z0 + z1) * 0.5, Vector3(fio * 0.7, fio * 0.7, diag), base * Basis(Vector3.UP, ang * s), mat, false)
		o.bloco(meio - y * h + z * (z0 + z1) * 0.5, Vector3(fio * 0.7, fio * 0.7, diag), base * Basis(Vector3.UP, -ang * s), mat, false)
		o.bloco(meio + x * h + z * (z0 + z1) * 0.5, Vector3(fio * 0.7, fio * 0.7, diag), base * Basis(Vector3.RIGHT, -ang * s), mat, false)
		o.bloco(meio - x * h + z * (z0 + z1) * 0.5, Vector3(fio * 0.7, fio * 0.7, diag), base * Basis(Vector3.RIGHT, ang * s), mat, false)
	if colide:
		var cx := BoxShape3D.new()
		cx.size = Vector3(larg, larg, comp)
		o.forma(cx, Transform3D(base, meio))


## Um contêiner de carga: a caixa de lata com as travessas das pontas. `aberto` deixa uma ponta sem porta
## e o miolo vazio (dá para entrar).
static func _conteiner(o: Ruinas.Obra, centro: Vector3, giro: Basis, cor: String, aberto := false) -> void:
	var c := Vector3(12.0, 2.6, 2.45)
	conteineres += 1
	if not aberto:
		o.bloco(centro, c, giro, cor)
	else:
		var e := 0.14
		o.bloco(centro + giro * Vector3(0, -c.y * 0.5 + e * 0.5, 0), Vector3(c.x, e, c.z), giro, cor)
		o.bloco(centro + giro * Vector3(0, c.y * 0.5 - e * 0.5, 0), Vector3(c.x, e, c.z), giro, cor)
		o.bloco(centro + giro * Vector3(0, 0, -c.z * 0.5 + e * 0.5), Vector3(c.x, c.y, e), giro, cor)
		o.bloco(centro + giro * Vector3(0, 0, c.z * 0.5 - e * 0.5), Vector3(c.x, c.y, e), giro, cor)
		o.bloco(centro + giro * Vector3(-c.x * 0.5 + e * 0.5, 0, 0), Vector3(e, c.y, c.z), giro, cor)
		# a porta que sobrou, escancarada
		o.bloco(centro + giro * Vector3(c.x * 0.5 + 0.55, 0, c.z * 0.5 + 0.3), Vector3(1.2, c.y, e), giro * Basis(Vector3.UP, -1.0), cor, false)
	for sx: float in [-1.0, 1.0]:
		o.bloco(centro + giro * Vector3(sx * (c.x * 0.5 - 0.1), 0, 0), Vector3(0.22, c.y + 0.12, c.z + 0.12), giro, "ferrugem", false)


# ---------------------------------------------------------------- O Cais Submerso

## O porto de carga antigo: a laje na praia, o cais avançando baía adentro e afundando aos pedaços, um
## guindaste ainda de pé, outro tombado na água e contêineres na praia, no cais e no fundo.
## Na medida da obra: x avança mar adentro, z é a largura do cais, y é a altura do mundo (0 = o mar).
static func _cais(o: Ruinas.Obra) -> void:
	var v := o.v
	# a laje do pátio, na praia, rachada em placas
	for ix in 4:
		for iz in 3:
			var lx := -34.0 + ix * 8.6
			var lz := -8.6 + iz * 8.6
			var h := maxf(_fundo(o, lx, lz), 1.2)
			o.bloco(Vector3(lx, h - 0.1, lz), Vector3(8.4, 0.9, 8.4), Basis.from_euler(Vector3(o.j(0.03), o.j(0.03), o.j(0.03))), "concreto")
	# o cais em trechos de 12 m: os primeiros de pé, depois tortos, afundados ou faltando
	# [altura do tabuleiro, tomba de lado, tomba de frente] ou vazio (o trecho caiu inteiro)
	var trechos := [[2.3, 0.0, 0.0], [2.3, 0.0, 0.0], [2.3, 0.01, 0.0], [2.2, 0.0, 0.02], [1.5, 0.09, 0.07], [], [-1.1, -0.2, 0.05], [-0.6, 0.16, -0.08], [],
		[0.9, 0.05, 0.1], [1.4, -0.04, 0.02]]
	for k in trechos.size():
		var lx := 6.0 + k * 12.0
		if (trechos[k] as Array).is_empty():
			# só os pilares, quebrados em alturas diferentes
			for lz: float in [-3.4, 3.4]:
				var fundo := _fundo(o, lx, lz)
				var topo := o.rng.randf_range(-2.5, 1.2)
				if topo > fundo + 1.0:
					o.bloco(Vector3(lx, (fundo + topo) * 0.5, lz), Vector3(1.3, topo - fundo + 0.6, 1.3), Basis.from_euler(Vector3(o.j(0.06), 0, o.j(0.06))), "concreto")
			continue
		var tr: Array = trechos[k]
		var giro := Basis.from_euler(Vector3(tr[1], 0, tr[2]))
		o.bloco(Vector3(lx, float(tr[0]) - 0.5, 0), Vector3(11.8, 1.0, 9.2), giro, "concreto")
		for lz: float in [-3.4, 3.4]:
			for dx: float in [-3.6, 3.6]:
				var fundo := _fundo(o, lx + dx, lz)
				var topo := float(tr[0]) - 1.0
				if topo > fundo + 0.8:
					o.bloco(Vector3(lx + dx, (fundo + topo) * 0.5, lz), Vector3(1.2, topo - fundo + 0.5, 1.2), Basis.IDENTITY, "concreto")
		# cabeços de amarração nas beiras
		if k % 2 == 0 and float(tr[0]) > 1.0:
			for lz: float in [-4.0, 4.0]:
				o.bloco(Vector3(lx, float(tr[0]) + 0.35, lz), Vector3(0.5, 0.7, 0.5), giro, "ferrugem", false)
	# o guindaste de pé, no terceiro trecho: quatro pernas, a casa de máquinas e a lança sobre a água
	var g := Vector3(32.0, 2.3, 0.0)
	for canto: Vector2 in [Vector2(-3.2, -3.4), Vector2(3.2, -3.4), Vector2(3.2, 3.4), Vector2(-3.2, 3.4)]:
		_trelica(o, g + Vector3(canto.x, 0, canto.y), g + Vector3(canto.x * 0.55, 13.0, canto.y * 0.55), 1.0, 0.18)
	o.bloco(g + Vector3(0, 13.6, 0), Vector3(6.4, 1.0, 6.6), Basis.IDENTITY, "ferrugem")
	o.bloco(g + Vector3(-1.2, 16.0, 0), Vector3(5.2, 3.8, 4.2), Basis.IDENTITY, "tinta_velha")
	o.bloco(g + Vector3(-5.2, 15.2, 0), Vector3(3.0, 2.2, 3.2), Basis.IDENTITY, "casco")  # o contrapeso
	var pe_lanca := g + Vector3(1.6, 17.2, 0)
	var ponta := pe_lanca + Vector3(21.0, 9.0, 13.0)
	_trelica(o, pe_lanca, ponta, 1.5, 0.2)
	_trelica(o, g + Vector3(-1.0, 18.0, 0), g + Vector3(-1.0, 25.0, 0), 1.1, 0.16, "ferrugem", false)
	o.bloco((g + Vector3(-1.0, 25.0, 0) + ponta) * 0.5, Vector3(0.09, 0.09, (ponta - g - Vector3(-1.0, 25.0, 0)).length()),
		Basis.looking_at((ponta - g - Vector3(-1.0, 25.0, 0)).normalized(), Vector3.UP), "junta", false)
	# o cabo e o gancho, pendurados da ponta da lança
	o.bloco(ponta - Vector3(0, 7.0, 0), Vector3(0.08, 14.0, 0.08), Basis.IDENTITY, "junta", false)
	o.bloco(ponta - Vector3(0, 14.4, 0), Vector3(0.7, 1.0, 0.5), Basis.IDENTITY, "ferrugem", false)
	# o segundo guindaste, tombado no fim do cais: o corpo dentro d'água e a lança saindo dela
	var c2 := Vector3(108.0, 0.0, -12.0)
	var f2 := _fundo(o, c2.x, c2.z)
	_trelica(o, Vector3(c2.x - 6.0, f2 + 1.2, c2.z + 6.0), Vector3(c2.x + 8.0, f2 + 3.0, c2.z - 4.0), 2.4, 0.2)
	o.bloco(Vector3(c2.x + 9.0, f2 + 2.6, c2.z - 5.0), Vector3(5.2, 3.8, 4.2), Basis.from_euler(Vector3(0.5, 0.6, 1.1)), "tinta_velha")
	_trelica(o, Vector3(c2.x + 9.0, f2 + 3.0, c2.z - 6.0), Vector3(c2.x + 22.0, 7.5, c2.z - 21.0), 1.5, 0.2)
	# e a ponta de uma terceira lança, só o esqueleto furando a água entre os trechos afundados
	var f3 := _fundo(o, 70.0, 14.0)
	_trelica(o, Vector3(64.0, f3 + 0.5, 20.0), Vector3(78.0, 4.5, 9.0), 1.4, 0.18)
	# contêineres: empilhados no pátio, dois no cais, e os que escorregaram para o fundo
	var cores := ["tinta_velha", "lata_azul", "lata_verde", "ferrugem", "lata_azul", "lata_ocre"]
	var hp := maxf(_fundo(o, -22.0, 12.0), 1.2) + 0.35
	_conteiner(o, Vector3(-22.0, hp + 1.3, 13.5), Basis(Vector3.UP, 0.12), "lata_azul")
	_conteiner(o, Vector3(-21.5, hp + 3.9, 13.6), Basis(Vector3.UP, 0.2), "tinta_velha")
	_conteiner(o, Vector3(-23.0, hp + 1.3, 10.6), Basis(Vector3.UP, 0.1), "lata_ocre")
	_conteiner(o, Vector3(-26.0, hp + 1.3, -13.0), Basis(Vector3.UP, 1.4), "lata_verde")
	_conteiner(o, Vector3(14.0, 3.6, -2.4), Basis(Vector3.UP, 0.05), "lata_verde")
	_conteiner(o, Vector3(44.0, 3.5, 2.6), Basis(Vector3.UP, -0.3), "ferrugem")
	var no_fundo := [[24.0, -16.0], [40.0, 18.0], [52.0, -14.0], [60.0, -22.0], [66.0, 6.0], [84.0, -8.0], [92.0, 16.0], [100.0, 26.0], [118.0, 6.0], [126.0, -16.0],
		[74.0, 30.0], [48.0, 34.0]]
	for k in no_fundo.size():
		var q: Array = no_fundo[k]
		var fundo := _fundo(o, q[0], q[1])
		if fundo > -1.5:
			continue
		var giro := Basis.from_euler(Vector3(o.j(0.35), o.rng.randf() * TAU, o.j(0.3)))
		# um deles está aberto, de boca para cima do cais, no fundo raso
		var aberto := k == 4
		if aberto:
			giro = Basis(Vector3.UP, 0.4)
			conteiner_aberto = o.t * Vector3(q[0], fundo + 1.35, q[1])
		_conteiner(o, Vector3(q[0], fundo + 1.25 + (0.0 if aberto else o.rng.randf_range(-0.3, 0.5)), q[1]), giro, cores[k % cores.size()], aberto)
	# caixas e tambores do kit, no pátio e no começo do cais
	for dados: Array in [["Prop_Crate_Large", -30.0, 2.0, 0.4, 1.6], ["Prop_Crate", -27.0, 4.6, 1.1, 1.5], ["Prop_Crate_Large", 8.0, 2.8, 0.2, 1.5],
			["Prop_Barrel1", -18.0, -4.0, 0.0, 1.5], ["Prop_Barrel1", -16.6, -4.8, 0.7, 1.5], ["Prop_Barrel_Large", 20.0, -3.0, 0.0, 1.4], ["Prop_Crate", 26.0, 3.2, 2.0, 1.5]]:
		var lx: float = dados[1]
		var lz: float = dados[2]
		var h := 2.3 if lx > 0.0 else maxf(_fundo(o, lx, lz), 1.2) + 0.35
		BaseVale._peca(o, dados[0], Vector3(lx, h, lz), dados[3], dados[4], 0.75, 0.55)
	# mato tomando o pátio e o começo do cais
	for k in 14:
		var lx := o.rng.randf_range(-38.0, 20.0)
		var lz := o.j(12.0)
		var h := 2.3 if lx > 0.0 and absf(lz) < 4.5 else maxf(_fundo(o, lx, lz), 0.4)
		o.arbusto(Vector3(lx, h + 0.3, lz), o.rng.randf_range(0.7, 1.3))
	cais_ponta = o.t * Vector3(CAIS_COMP - 6.0, 1.4, 0)


# ---------------------------------------------------------------- A Ilha do Relé

## A torre de transmissão quebrada, no alto da ilhota: treliça de ferro com o terço de cima dobrado, as
## antenas (uma ainda presa, outra no chão), os estais e a casinha de concreto do relé.
static func _rele(o: Ruinas.Obra) -> void:
	var v := o.v
	var chao := v._fora(RELE.x, RELE.y)
	var pe := Vector3(0, chao - 0.6, 0)
	# a sapata de concreto
	o.bloco(pe + Vector3(0, 0.5, 0), Vector3(8.6, 1.4, 8.6), Basis.IDENTITY, "concreto")
	# a torre em lances que afinam; do terceiro lance para cima ela dobrou para o sul
	var lances := 6
	var alt_lance := RELE_ALTURA * 0.68 / 4.0
	var base_y := 1.0
	for k in 4:
		var l0 := lerpf(6.0, 2.6, float(k) / 4.0)
		var l1 := lerpf(6.0, 2.6, float(k + 1) / 4.0)
		var y0 := base_y + k * alt_lance
		var y1 := y0 + alt_lance
		for canto: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			_trelica(o, pe + Vector3(canto.x * l0 * 0.5, y0, canto.y * l0 * 0.5), pe + Vector3(canto.x * l1 * 0.5, y1, canto.y * l1 * 0.5), 0.5, 0.14, "ferrugem", false)
		# as travessas de cada patamar
		for lado in 4:
			var a := Vector3([-1, 1, 1, -1][lado] * l1 * 0.5, y1, [-1, -1, 1, 1][lado] * l1 * 0.5)
			var b := Vector3([1, 1, -1, -1][lado] * l1 * 0.5, y1, [-1, 1, 1, -1][lado] * l1 * 0.5)
			o.bloco(pe + (a + b) * 0.5, Vector3(0.14, 0.14, a.distance_to(b)), Basis.looking_at((b - a).normalized(), Vector3.UP), "ferrugem", false)
		# a colisão é só das quatro pernas: o miolo fechado barrava quem queria passar por baixo da torre e
		# ocupava o meio do patamar (visto pelo usuário em 2026-11-20)
		for canto: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			perna_colisao(o, pe + Vector3(canto.x * l0 * 0.5, y0, canto.y * l0 * 0.5), pe + Vector3(canto.x * l1 * 0.5, y1, canto.y * l1 * 0.5), 0.6)
	var quebra := pe + Vector3(0, base_y + 4.0 * alt_lance, 0)
	# o terço de cima, dobrado e pendurado para o sul
	var dobrado := quebra + Vector3(3.0, RELE_ALTURA * 0.05, RELE_ALTURA * 0.30)
	_trelica(o, quebra, dobrado, 2.2, 0.14)
	_trelica(o, dobrado, dobrado + Vector3(2.0, -RELE_ALTURA * 0.12, RELE_ALTURA * 0.10), 1.4, 0.12)
	# a plataforma de serviço, a dois terços da altura, com corrimão
	var plat := pe + Vector3(0, base_y + 3.0 * alt_lance, 0)
	o.bloco(plat, Vector3(5.6, 0.25, 5.6), Basis.IDENTITY, "casco")
	for lado in 4:
		var a := Vector3([-1, 1, 1, -1][lado] * 2.8, 1.1, [-1, -1, 1, 1][lado] * 2.8)
		var b := Vector3([1, 1, -1, -1][lado] * 2.8, 1.1, [-1, 1, 1, -1][lado] * 2.8)
		if lado != 2:
			o.bloco(plat + (a + b) * 0.5, Vector3(0.1, 0.1, 5.6), Basis.looking_at((b - a).normalized(), Vector3.UP), "ferrugem", false)
	# as antenas: uma presa na torre, outra pendurada na parte dobrada, outra caída no chão
	BaseVale._peca(o, "Prop_SatelliteDish", plat + Vector3(-2.4, 0.2, -2.4), 2.4, 2.6, 0.7, 0.5, false)
	BaseVale._peca(o, "Prop_SatelliteDish", quebra + Vector3(0.4, -3.2, 1.6), 0.4, 2.2, 0.8, 0.4, false)
	var caida := BaseVale._peca(o, "Prop_SatelliteDish", Vector3(9.0, v._fora(RELE.x + 9.0, RELE.y + 11.0) + 0.6, 11.0), 1.0, 3.0, 0.8, 0.7)
	caida.transform = caida.transform * Transform3D(Basis.from_euler(Vector3(1.1, 0, 0.3)), Vector3.ZERO)
	# os estais: dois ainda esticados, um arrebentado no chão
	for dados: Array in [[Vector3(-22, 0, -14), true], [Vector3(-16, 0, 20), true], [Vector3(24, 0, -8), false]]:
		var ancora: Vector3 = dados[0]
		ancora.y = v._fora(RELE.x + ancora.x, RELE.y + ancora.z) + 0.4
		o.bloco(ancora, Vector3(1.6, 1.2, 1.6), Basis.IDENTITY, "concreto")
		if dados[1]:
			var de := plat + Vector3(0, 1.0, 0)
			o.bloco((de + ancora) * 0.5, Vector3(0.07, 0.07, de.distance_to(ancora)), Basis.looking_at((ancora - de).normalized(), Vector3.UP), "junta", false)
		else:
			o.bloco(ancora + Vector3(-6.0, 0.1, 2.0), Vector3(0.07, 0.07, 13.0), Basis(Vector3.UP, 1.9), "junta", false)
	# a casinha do relé: quatro paredes de concreto, sem porta, com a laje rachada
	var casa := Vector3(-11.0, v._fora(RELE.x - 11.0, RELE.y + 4.0), 4.0)
	o.bloco(casa + Vector3(0, 1.6, -2.4), Vector3(6.2, 3.4, 0.5), Basis.IDENTITY, "concreto")
	o.bloco(casa + Vector3(0, 1.6, 2.4), Vector3(6.2, 3.4, 0.5), Basis.IDENTITY, "concreto")
	o.bloco(casa + Vector3(-2.85, 1.6, 0), Vector3(0.5, 3.4, 4.4), Basis.IDENTITY, "concreto")
	o.bloco(casa + Vector3(2.85, 1.6, 1.3), Vector3(0.5, 3.4, 1.9), Basis.IDENTITY, "concreto")
	o.bloco(casa + Vector3(0.3, 3.5, 0.2), Vector3(6.8, 0.5, 5.6), Basis.from_euler(Vector3(0.05, 0, -0.07)), "concreto")
	BaseVale._peca(o, "Prop_Computer", casa + Vector3(-1.6, 0.0, -1.4), 0.0, 1.2, 0.7, 0.5, false)
	BaseVale._peca(o, "Prop_Crate", casa + Vector3(5.2, 0.0, -1.0), 0.6, 1.4, 0.7, 0.6)
	for k in 12:
		var a := o.rng.randf() * TAU
		var r := o.rng.randf_range(5.0, 16.0)
		o.arbusto(Vector3(cos(a) * r, v._fora(RELE.x + cos(a) * r, RELE.y + sin(a) * r), sin(a) * r), o.rng.randf_range(0.7, 1.3))
	rele_topo = o.t * plat


# ---------------------------------------------------------------- a ponte antiga

## Os pilares da ponte que ligava a costa às ilhotas, plantados nos bancos de areia: uns inteiros, com o
## capitel e um resto de tabuleiro, outros quebrados na linha d'água, um tombado.
static func _ponte(o: Ruinas.Obra) -> void:
	for trecho: Array in PONTE:
		var a: Vector2 = trecho[0]
		var b: Vector2 = trecho[1]
		var n: int = trecho[2]
		var dir := (b - a).normalized()
		var giro := Basis(Vector3.UP, -atan2(dir.y, dir.x))
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			var fundo := o.v._fora(p.x, p.y)
			var tipo := (k * 7 + int(a.x)) % 5
			pilares += 1
			if tipo == 3:
				# tombado: deitado no banco de areia, meio fora d'água
				o.bloco(Vector3(p.x, maxf(fundo, -1.5) + 1.3, p.y), Vector3(3.0, 2.8, 9.0), giro * Basis.from_euler(Vector3(0.12, 0.5, 0.2)), "concreto")
				continue
			var topo := 8.5 if tipo < 2 else o.rng.randf_range(1.0, 4.5)
			o.bloco(Vector3(p.x, (fundo + topo) * 0.5 - 0.4, p.y), Vector3(3.0, topo - fundo + 0.8, 3.6), giro * Basis.from_euler(Vector3(o.j(0.03), 0, o.j(0.03))), "concreto")
			if tipo < 2:
				o.bloco(Vector3(p.x, topo + 0.5, p.y), Vector3(4.2, 1.0, 6.4), giro, "concreto")
				if tipo == 0:
					# um resto do tabuleiro, apoiado só neste pilar
					o.bloco(Vector3(p.x, topo + 1.5, p.y) + giro * Vector3(3.0, 0, 0), Vector3(11.0, 1.0, 6.0), giro * Basis(Vector3.BACK, -0.06), "concreto")
					o.bloco(Vector3(p.x, topo + 2.5, p.y) + giro * Vector3(3.0, 0, 2.8), Vector3(10.0, 0.12, 0.12), giro * Basis(Vector3.BACK, -0.06), "ferrugem", false)
