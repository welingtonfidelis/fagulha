class_name MarcosOeste
extends RefCounted
## Os lugares das faixas novas do norte e do oeste (ilha de 3 km, etapa 6, doc §84), que tinham ganhado só
## terra: As Torres do Vento na costa norte, O Observatório num morro do noroeste e O Casco Encalhado na
## enseada do oeste. Mesma linguagem do leste: concreto e ferro velhos, com mato. Tudo com colisão.

const TORRES := [Vector2(-10, -1172), Vector2(128, -1186), Vector2(262, -1168), Vector2(396, -1182), Vector2(534, -1166)]
const TORRE_ALT := 48.0
const PA := 21.0  # comprimento de cada pá
const OBSERVATORIO := Vector2(-700.0, -1088.0)
const CUPULA := 20.0  # raio da cúpula (eram 12 m, e de longe sumia no morro)
const CASCO := Vector2(-1206.0, 322.0)  # o meio do navio
const CASCO_COMP := 76.0

static var torres_topo: Array[Vector3] = []
static var girando := 0
static var rotores: Array = []  # [nó do rotor, estado, índice da torre] das torres de pé (as ações por lugar usam)
static var observatorio_topo := Vector3.INF
static var conves := Vector3.INF  # um ponto do convés do navio


## Uma hélice que ainda gira, devagar.
class Rotor extends Node3D:
	var vel := 0.3
	func _process(delta: float) -> void:
		rotate_object_local(Vector3.FORWARD, vel * delta)


static func livre(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for t: Vector2 in TORRES:
		if p.distance_to(t) < 28.0:  # uma clareira ao pé de cada torre, para ela aparecer do chão
			return false
	if p.distance_to(OBSERVATORIO) < CUPULA + 12.0:
		return false
	return absf(z - CASCO.y) > 16.0 or absf(x - CASCO.x) > CASCO_COMP * 0.5 + 8.0


## O chão de dentro do Observatório fica plano, na altura do meio (a do piso de concreto). O morro sobe para
## o sudeste e, com a cúpula de 20 m, passava por dentro até 1,9 m acima do piso: enterrava o robô sentado e
## quem entrasse (visto pelo usuário em 2026-11-20). Em volta emenda no relevo em 10 m, e sob o piso não nasce
## capim. Roda antes de a malha e a colisão do chão de fora serem feitas.
static func cavar(v: Vale) -> void:
	var n := Vale.F_N
	var h0 := v._fora(OBSERVATORIO.x, OBSERVATORIO.y)
	var dentro := CUPULA + 1.5  # passa um pouco da parede do tambor
	var emenda := 10.0
	var alcance := dentro + emenda + Vale.F_PASSO
	for gz in n:
		var z := -Vale.F_META + gz * Vale.F_PASSO
		if absf(z - OBSERVATORIO.y) > alcance:
			continue
		for gx in n:
			var x := -Vale.F_META + gx * Vale.F_PASSO
			if absf(x - OBSERVATORIO.x) > alcance:
				continue
			var d := Vector2(x, z).distance_to(OBSERVATORIO)
			var i := gz * n + gx
			if d < CUPULA:
				v._cob[i] = 5  # o chão comum, sem capim
			var t := smoothstep(dentro, dentro + emenda, d)
			if t < 1.0:
				v._fora_h[i] = lerpf(h0, v._fora_h[i], t)


static func montar(v: Vale) -> void:
	var t0 := Time.get_ticks_msec()
	torres_topo.clear()
	girando = 0
	rotores.clear()
	var blocos: Array[PackedVector3Array] = []
	for k in 6:
		blocos.append(Ruinas._cubo_talhado(503 + k * 7, 2 + k % 3))
	var pecas := 0
	# o navio fica adernado e com a proa mais alta, encalhada na areia: a obra inteira é girada
	var navio := Basis(Vector3.UP, 0.08) * Basis(Vector3.BACK, 0.055) * Basis(Vector3.RIGHT, 0.2)
	for sitio: Array in [["Torres", Transform3D.IDENTITY], ["Observatorio", Transform3D(Basis.IDENTITY, Vector3(OBSERVATORIO.x, 0, OBSERVATORIO.y))],
			["Casco", Transform3D(navio, Vector3(CASCO.x, -4.4, CASCO.y))]]:  # na primeira versão ficou fundo demais: só a casa do leme saía da água
		var o := Ruinas.Obra.new()
		o.v = v
		o.blocos = blocos
		o.t = sitio[1]
		o.rng.seed = hash(sitio[0])
		o.corpo = StaticBody3D.new()
		o.corpo.name = "Marco" + sitio[0]
		o.corpo.collision_layer = 1
		o.corpo.collision_mask = 0
		v.add_child(o.corpo)
		match sitio[0]:
			"Torres":
				_torres(o)
			"Observatorio":
				_observatorio(o)
			"Casco":
				_casco(o)
		o.fechar()
		pecas += o.pecas
	Marcos.lugares.append(["As Torres do Vento", (TORRES[1] + TORRES[3]) * 0.5, 330.0])
	Marcos.lugares.append(["O Observatório", OBSERVATORIO, 70.0])
	Marcos.lugares.append(["O Casco Encalhado", CASCO, 80.0])
	print("marcos do oeste: %d peças, %d torres (%d girando), %d ms" % [pecas, torres_topo.size(), girando, Time.get_ticks_msec() - t0])


## Um cilindro (ou cone truncado) solto, com colisão opcional. `xf` na medida da obra, no meio da peça.
static func _cilindro(o: Ruinas.Obra, xf: Transform3D, raio_baixo: float, raio_alto: float, alt: float, mat: String, colide := true) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = raio_baixo
	m.top_radius = raio_alto
	m.height = alt
	m.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = o.v.material(mat)
	mi.transform = o.t * xf
	o.v.add_child(mi)
	if colide:
		var f := CylinderShape3D.new()
		f.radius = maxf(raio_baixo, raio_alto)
		f.height = alt
		o.forma(f, xf)
	return mi


# ---------------------------------------------------------------- As Torres do Vento

## Cinco torres de vento em fila na costa norte: duas ainda giram devagar, uma parou, uma perdeu uma pá
## (que ficou no chão) e uma quebrou ao meio.
static func _torres(o: Ruinas.Obra) -> void:
	var v := o.v
	# [estado]: gira, gira lento, parada, sem uma pá, quebrada
	var estados := ["gira", "falta", "parada", "quebrada", "gira"]
	for k in TORRES.size():
		var c: Vector2 = TORRES[k]
		var chao := v._fora(c.x, c.y)
		var pe := Vector3(c.x, chao - 0.5, c.y)
		var estado: String = estados[k]
		o.bloco(pe + Vector3(0, 0.6, 0), Vector3(7.0, 1.4, 7.0), Basis(Vector3.UP, 0.3 * k), "concreto")
		var alt := TORRE_ALT if estado != "quebrada" else TORRE_ALT * 0.42
		_cilindro(o, Transform3D(Basis.IDENTITY, pe + Vector3(0, 1.2 + alt * 0.5, 0)), 1.9, lerpf(1.9, 1.05, alt / TORRE_ALT), alt, "casco_claro")
		var topo := pe + Vector3(0, 1.2 + alt, 0)
		var rumo := Basis(Vector3.UP, 0.25 + 0.2 * k)  # viradas mais ou menos para o mar
		if estado == "quebrada":
			# a metade de cima tombou ao lado, com a casa de máquinas e as pás enterradas
			var cai := rumo * Vector3(1, 0, 0.3).normalized()
			var meio := Vector3(c.x, 0, c.y) + cai * 17.0
			meio.y = v._fora(meio.x, meio.z) + 1.3
			_cilindro(o, Transform3D(Basis.looking_at(cai, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), meio), 1.5, 1.05, TORRE_ALT * 0.52, "casco_claro")
			var ponta := Vector3(c.x, 0, c.y) + cai * 31.0
			ponta.y = v._fora(ponta.x, ponta.z) + 1.4
			o.bloco(ponta, Vector3(3.0, 3.0, 7.0), Basis.looking_at(cai, Vector3.UP) * Basis(Vector3.BACK, 0.4), "tinta_velha")
			o.bloco(ponta + cai * 4.0 + Vector3(0, 3.0, 0), Vector3(1.5, PA, 0.4), Basis.from_euler(Vector3(0.5, 0.3, 0.9)), "casco_claro", false)
			o.bloco(ponta + cai * 5.0 + Vector3(4.0, 0.4, 3.0), Vector3(1.5, 0.4, PA), Basis(Vector3.UP, 0.8), "casco_claro")
			torres_topo.append(topo)
			continue
		# a casa de máquinas e o cubo da hélice
		o.bloco(topo + rumo * Vector3(0, 1.4, 1.2), Vector3(3.0, 2.8, 7.6), rumo, "tinta_velha")
		var cubo := topo + rumo * Vector3(0, 1.4, -3.2)
		var rotor: Node3D = Rotor.new() if estado == "gira" else Node3D.new()
		rotor.transform = o.t * Transform3D(rumo * Basis(Vector3.FORWARD, 0.5 + k * 1.1), cubo)
		v.add_child(rotor)
		rotores.append([rotor, estado, k])
		if estado == "gira":
			(rotor as Rotor).vel = 0.32 if k == 0 else 0.2
			girando += 1
		var nariz := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 1.3
		esfera.height = 2.6
		nariz.mesh = esfera
		nariz.material_override = v.material("casco_claro")
		rotor.add_child(nariz)
		for i in 3:
			if estado == "falta" and i == 1:
				continue
			var pa := MeshInstance3D.new()
			var caixa := BoxMesh.new()
			caixa.size = Vector3(1.7, PA, 0.32)
			pa.mesh = caixa
			pa.material_override = v.material("casco_claro")
			pa.transform = Transform3D(Basis(Vector3.FORWARD, i * TAU / 3.0), Vector3.ZERO) * Transform3D(Basis(Vector3.UP, 0.18), Vector3(0, PA * 0.5 + 0.8, 0))
			rotor.add_child(pa)
		if estado == "falta":
			# a pá que caiu, espetada no chão ao pé da torre
			var q := Vector3(c.x + 9.0, 0, c.y + 5.0)
			q.y = v._fora(q.x, q.z) + PA * 0.3
			o.bloco(q, Vector3(1.7, PA, 0.32), Basis.from_euler(Vector3(0.5, 0.7, 0.25)), "casco_claro")
		for i in 5:
			var a := o.rng.randf() * TAU
			o.arbusto(Vector3(c.x + cos(a) * 5.0, v._fora(c.x + cos(a) * 5.0, c.y + sin(a) * 5.0), c.y + sin(a) * 5.0), o.rng.randf_range(0.7, 1.2))
		torres_topo.append(topo)


# ---------------------------------------------------------------- O Observatório

## Uma cúpula de concreto num morro do noroeste: o tambor redondo, a cúpula em fiadas que fecham, a fenda
## por onde o telescópio olhava (ele ainda está lá, apontado para o céu) e um pedaço da casca que caiu.
static func _observatorio(o: Ruinas.Obra) -> void:
	var v := o.v
	var chao := v._fora(OBSERVATORIO.x, OBSERVATORIO.y)
	var pe := Vector3(0, chao - 1.0, 0)
	var por_volta := 26
	var k := CUPULA / 12.0  # as medidas de dentro acompanham o raio
	# o tambor: parede redonda de 7 m, com a porta virada para o sul
	var tambor_alt := 12.0
	o.anel(pe, Basis.IDENTITY, CUPULA, 1.6, 3.0, por_volta, 4, func(_i: int, jf: int, phi: float) -> bool:
		return not (jf < 2 and absf(angle_difference(phi, PI * 0.5)) < 0.22), )
	# a cúpula: sete fiadas que se inclinam para dentro; fica aberta a fenda (para o norte) e um rombo a oeste
	var fiadas := 9
	for jf in fiadas:
		var e0 := (jf + 0.5) / fiadas * PI * 0.5 * 0.92
		var raio := CUPULA * cos(e0)
		var y := tambor_alt + CUPULA * sin(e0)
		var n := maxi(5, int(por_volta * cos(e0)))
		var arco := TAU * raio / n
		for i in n:
			var phi := (i + 0.5 * (jf % 2)) * TAU / n
			if absf(angle_difference(phi, -PI * 0.5)) < 0.20 + 0.04 * jf:
				continue  # a fenda do telescópio
			if jf >= 2 and jf <= 4 and absf(angle_difference(phi, PI + 0.3)) < 0.5:
				continue  # o pedaço que caiu
			o.bloco(pe + Vector3(cos(phi) * raio, y, sin(phi) * raio), Vector3(arco * 1.08, CUPULA * PI * 0.5 * 0.92 / fiadas * 1.06, 1.2),
				Basis(Vector3.UP, PI * 0.5 - phi + o.j(0.01)) * Basis(Vector3.RIGHT, -e0), "concreto" if (jf + i) % 5 != 0 else "casco_claro")
	# o piso, o pedestal e o telescópio apontado pela fenda
	o.bloco(pe + Vector3(0, 0.6, 0), Vector3(CUPULA * 1.7, 1.2, CUPULA * 1.7), Basis.IDENTITY, "concreto")
	_cilindro(o, Transform3D(Basis.IDENTITY, pe + Vector3(0, 1.2 + 3.0 * k, 0)), 1.8 * k, 1.4 * k, 6.0 * k, "concreto")
	var mira := Basis(Vector3.RIGHT, 0.75)  # inclinado para o norte, pela fenda
	_cilindro(o, Transform3D(mira, pe + Vector3(0, 7.2 * k, 0) + mira * Vector3(0, 3.0 * k, 0)), 1.5 * k, 1.2 * k, 15.0 * k, "ferrugem")
	_cilindro(o, Transform3D(mira, pe + Vector3(0, 7.2 * k, 0) + mira * Vector3(0, 10.8 * k, 0)), 1.7 * k, 1.7 * k, 0.8 * k, "casco", false)
	_cilindro(o, Transform3D(Basis(Vector3.BACK, PI * 0.5), pe + Vector3(0, 6.6 * k, 0)), 0.9 * k, 0.9 * k, 5.4 * k, "ferrugem", false)
	# a casca que caiu, do lado de fora, e mato tomando a entrada
	for n_casca in 7:
		var p := Vector2(-CUPULA - 3.0 - o.rng.randf() * 8.0, o.j(7.0) - 3.0)
		var tam := Vector3(o.rng.randf_range(1.6, 3.6), 0.9, o.rng.randf_range(1.6, 3.2))
		o.bloco(Vector3(p.x, v._fora(OBSERVATORIO.x + p.x, OBSERVATORIO.y + p.y) + 0.4, p.y), tam, Basis.from_euler(Vector3(o.j(0.5), o.rng.randf() * TAU, o.j(0.4))), "casco_claro")
	BaseVale._peca(o, "Prop_SatelliteDish", Vector3(CUPULA + 6.0, v._fora(OBSERVATORIO.x + CUPULA + 6.0, OBSERVATORIO.y + 5.0), 5.0), 0.8, 3.4, 0.7, 0.6)
	for n_mato in 12:
		var a := o.rng.randf() * TAU
		var r := CUPULA + o.rng.randf_range(1.5, 6.0)
		o.arbusto(Vector3(cos(a) * r, v._fora(OBSERVATORIO.x + cos(a) * r, OBSERVATORIO.y + sin(a) * r), sin(a) * r), o.rng.randf_range(0.8, 1.4))
	observatorio_topo = o.t * (pe + Vector3(0, tambor_alt + CUPULA, 0))


# ---------------------------------------------------------------- O Casco Encalhado

## Um cargueiro velho encalhado na enseada do oeste, adernado, com a proa na areia e a popa na água.
## Na medida da obra: x vai da popa (-38) à proa (+38), y sobe a partir da quilha, z é a boca do navio.
static func _casco(o: Ruinas.Obra) -> void:
	var meia := 6.8
	var alto := 9.0
	# o fundo e os costados, em chapas de 8 m; algumas faltam (dá para entrar no porão)
	var x := -38.0
	var k := 0
	while x < 22.0:
		o.bloco(Vector3(x + 4.0, 0.3, 0), Vector3(8.2, 0.6, meia * 2.0), Basis.IDENTITY, "ferrugem")
		for lado: float in [-1.0, 1.0]:
			var falta := (k == 3 and lado > 0.0) or (k == 5 and lado < 0.0)
			if not falta:
				o.bloco(Vector3(x + 4.0, alto * 0.32, lado * (meia + 0.25)), Vector3(8.2, alto * 0.64, 0.5), Basis(Vector3.RIGHT, -lado * 0.1), "ferrugem")
			o.bloco(Vector3(x + 4.0, alto * 0.82, lado * (meia + 0.75)), Vector3(8.2, alto * 0.38, 0.5), Basis(Vector3.RIGHT, -lado * 0.1), "tinta_velha" if k % 3 != 1 else "ferrugem")
		# cavernas: as costelas por dentro
		o.bloco(Vector3(x, alto * 0.5, 0), Vector3(0.3, 0.4, meia * 2.0), Basis.IDENTITY, "ferrugem", false)
		x += 8.0
		k += 1
	# a proa: os costados fecham em bico
	for i in 4:
		var x0 := 22.0 + i * 4.0
		var z0 := meia * (1.0 - i / 4.0)
		var z1 := meia * (1.0 - (i + 1) / 4.0)
		for lado: float in [-1.0, 1.0]:
			var ang := atan2(z0 - z1, 4.0) * lado
			o.bloco(Vector3(x0 + 2.0, alto * 0.55, lado * (z0 + z1) * 0.5), Vector3(4.6, alto * 1.1, 0.5), Basis(Vector3.UP, ang), "ferrugem" if i % 2 == 0 else "tinta_velha")
		o.bloco(Vector3(x0 + 2.0, 0.3, 0), Vector3(4.2, 0.6, (z0 + z1) + 0.4), Basis.IDENTITY, "ferrugem")
		o.bloco(Vector3(x0 + 2.0, alto + 1.0, 0), Vector3(4.2, 0.4, (z0 + z1) + 0.4), Basis.IDENTITY, "casco")
	# a popa: o espelho
	o.bloco(Vector3(-38.2, alto * 0.5, 0), Vector3(0.5, alto, meia * 2.0 + 1.4), Basis.IDENTITY, "ferrugem")
	# o convés: chapas com buracos (as bocas dos porões e o que apodreceu)
	x = -38.0
	k = 0
	while x < 22.0:
		for parte in 3:
			var z := (parte - 1) * meia * 0.67
			var porao := parte == 1 and (k == 3 or k == 4 or k == 6)
			if porao or (k * 3 + parte) % 7 == 5:
				continue
			o.bloco(Vector3(x + 4.0, alto + 0.2, z), Vector3(8.1, 0.4, meia * 0.68), Basis.IDENTITY, "casco")
		x += 8.0
		k += 1
	# a casa do leme, na popa: três andares, a ponte de comando e a chaminé torta
	o.bloco(Vector3(-27.0, alto + 3.9, 0), Vector3(13.0, 7.0, 10.5), Basis.IDENTITY, "tinta_velha")
	o.bloco(Vector3(-25.0, alto + 9.0, 0), Vector3(8.0, 3.2, 12.6), Basis.IDENTITY, "casco_claro")
	o.bloco(Vector3(-25.0, alto + 10.9, 0), Vector3(9.0, 0.4, 13.4), Basis.IDENTITY, "casco")
	_cilindro(o, Transform3D(Basis(Vector3.BACK, 0.16), Vector3(-31.0, alto + 13.5, 0)), 1.9, 1.6, 8.0, "tinta_velha")
	_cilindro(o, Transform3D(Basis(Vector3.BACK, 0.16), Vector3(-31.6, alto + 17.2, 0)), 1.65, 1.65, 0.9, "junta", false)
	# os dois mastros de carga: um de pé, com o pau de carga caído; o outro quebrado sobre o convés
	MarcosMar._trelica(o, Vector3(4.0, alto, 0), Vector3(4.0, alto + 18.0, 0), 1.2, 0.16)
	MarcosMar._trelica(o, Vector3(4.0, alto + 6.0, 0), Vector3(15.0, alto + 1.4, 4.0), 0.8, 0.13)
	MarcosMar._trelica(o, Vector3(-9.0, alto, 0), Vector3(-9.0, alto + 6.0, 0), 1.2, 0.16)
	MarcosMar._trelica(o, Vector3(-9.0, alto + 5.5, 0), Vector3(-2.0, alto + 0.9, -5.0), 1.1, 0.14)
	# carga que sobrou no convés, e a âncora de corrente caída na areia da proa
	MarcosMar._conteiner(o, Vector3(13.0, alto + 1.7, -3.2), Basis(Vector3.UP, 0.1), "lata_ocre")
	MarcosMar._conteiner(o, Vector3(13.6, alto + 1.7, 2.6), Basis(Vector3.UP, -0.06), "lata_azul")
	o.bloco(Vector3(34.0, alto * 0.5, 4.4), Vector3(0.3, alto * 1.1, 0.3), Basis(Vector3.RIGHT, 0.3), "junta", false)
	conves = o.t * Vector3(-4.0, alto + 0.4, 4.5)
