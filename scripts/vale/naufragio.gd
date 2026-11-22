class_name Naufragio
extends RefCounted
## O Navio Encalhado (terra nova, área A, 2026-11-21, doc §137.4): um cargueiro pequeno de ferro, deitado na
## praia que dá para o canal, de frente para as Torres do Vento. Adernou para o mar e afundou na areia até a
## metade da altura. O casco é feito aqui, em duas chapas com a borda, e tem um rombo do lado do mar por onde o
## robô entra no porão (o chão lá dentro é a própria areia). O convés tem chapas faltando sobre o porão da
## frente, a casa do comando fica na popa e o guindaste tombou por cima. Dois contêineres que caíram dele
## ficaram na areia.
## Na medida do navio: x vai da popa (−) à proa (+), y sobe da quilha, z é a largura (+ é o lado da terra).

const NOME := "O Navio Encalhado"
const E := 1.45  # o desenho é feito num navio de 46 m e crescido nesta medida (67 m), para se ver das Torres
const COMP := 46.0 * E
const BOCA := 9.0 * E  # a largura no meio
const PONTAL := 6.5 * E  # da quilha ao convés, no meio
const CHAPA := 0.32  # grossura do casco
const ENTERRA := 1.9 * E  # quanto a quilha fica abaixo da areia
const ESTACOES := 46  # cortes ao longo do casco
const VOLTA := 12  # pontos em cada meia seção, da borda do convés à quilha

static var centro := Vector3.INF
static var raio := 46.0  # o que fica livre em volta (bichos, troncos)


static func montar(v: Vale, onde: Vector2, rumo: float) -> void:
	var t0 := Time.get_ticks_msec()
	var hs := v.altura(onde.x, onde.y)
	# adernado para o mar (o lado −z), com a proa um pouco mais alta, onde a onda a jogou
	var base := Basis(Vector3.UP, rumo) * Basis(Vector3.BACK, 0.035) * Basis(Vector3.RIGHT, -0.2)
	var xf := Transform3D(base, Vector3(onde.x, hs - ENTERRA, onde.y))
	centro = Vector3(onde.x, hs, onde.y)
	var o := Ruinas.Obra.new()
	o.v = v
	o.t = xf
	o.na_clareira = true  # a altura do chão vem do Vale (que pergunta à terra nova), não da grade velha
	o.rng.seed = 4401
	for k in 4:
		o.blocos.append(Ruinas._cubo_talhado(911 + k * 5, 1))
	o.corpo = StaticBody3D.new()
	o.corpo.name = "NavioEncalhado"
	o.corpo.collision_layer = 1
	o.corpo.collision_mask = 0
	v.add_child(o.corpo)
	_casco(v, o, xf)
	_conves(o)
	_comando(o)
	o.fechar()
	# os contêineres que caíram, já na areia (outra obra, no prumo)
	var o2 := Ruinas.Obra.new()
	o2.v = v
	o2.t = Transform3D(Basis(Vector3.UP, rumo), Vector3(onde.x, 0.0, onde.y))
	o2.na_clareira = true
	o2.rng.seed = 4409
	o2.blocos = o.blocos
	o2.corpo = o.corpo
	for c: Array in [[Vector3(-COMP * 0.5 - 9.0, 0, -7.0), Basis.from_euler(Vector3(0.06, 0.5, 0.2)), "conteiner_azul", false],
			[Vector3(COMP * 0.5 + 6.0, 0, 9.0), Basis.from_euler(Vector3(0.0, -1.1, -0.05)), "conteiner_ocre", true]]:
		var p: Vector3 = c[0]
		var mundo := o2.t * p
		p.y = v.altura(mundo.x, mundo.z) + 0.85
		MarcosMar._conteiner(o2, p, c[1], c[2], c[3])
	o2.fechar()
	# para os bichos sem física não atravessarem o casco
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(COMP, 6.0, BOCA)
	Obstaculos.registrar_forma(caixa, Transform3D(Basis(Vector3.UP, rumo), centro + Vector3(0, 2.0, 0)), hs)
	print("navio encalhado em %s: %d peças, %d ms" % [centro, o.pecas + o2.pecas, Time.get_ticks_msec() - t0])


# ---------------------------------------------------------------- o casco

static func _meia_boca(u: float) -> float:  # u: −1 na popa, +1 na proa
	var w := BOCA * 0.5
	if u > 0.3:
		w *= 1.0 - pow((u - 0.3) / 0.7, 1.9)
	elif u < -0.8:
		w *= 1.0 - 0.14 * (-u - 0.8) / 0.2
	return maxf(w, 0.0)


static func _alto(u: float) -> float:  # a altura do convés: sobe na proa (o tosado) e um pouco na popa
	return PONTAL + (0.9 * pow(maxf(0.0, u - 0.55) / 0.45, 2.0) + 0.35 * maxf(0.0, -u - 0.75) / 0.25) * E


static func _quilha(u: float) -> float:  # a quilha sobe na proa (o pé de proa redondo) e na popa (o espelho)
	if u > 0.72:
		return 3.4 * E * pow((u - 0.72) / 0.28, 2.0)
	if u < -0.86:
		return 1.6 * E * pow((-u - 0.86) / 0.14, 1.5)
	return 0.0


static func _ponto(u: float, s: float, lado: float, dentro: float) -> Vector3:
	# s vai de 0 (a borda do convés) a 1 (a quilha); a seção é quase quadrada no meio e vira um V na proa
	var n := 5.0
	if u > 0.2:
		n = lerpf(5.0, 1.8, minf((u - 0.2) / 0.8, 1.0))
	elif u < -0.6:
		n = lerpf(5.0, 3.0, (-u - 0.6) / 0.4)
	var w := maxf(_meia_boca(u) - dentro, 0.0)
	var d := _alto(u)
	var k := _quilha(u) + dentro
	var th := s * PI * 0.5
	var z := w * pow(cos(th), 2.0 / n)
	var y := k + (d - k) * (1.0 - pow(sin(th), 2.0 / n))
	return Vector3(u * COMP * 0.5, y, z * lado)


## O rombo do lado do mar e os furos de ferrugem: o pedaço de chapa (pelo meio dele) que não está mais lá.
static func _furo(c: Vector3) -> bool:
	if c.z < -0.5:
		# o rombo: rasgado, mais largo embaixo, com o pé rente à areia (o robô entra andando)
		var r := sin(c.x * 1.3 + c.y * 2.1) * 0.22 + sin(c.x * 2.9 - c.y * 1.7) * 0.14
		var largura := 3.6 + (7.4 - c.y) * 0.45
		if absf(c.x - 3.0) / largura + pow((c.y - 6.2) / 2.3, 2.0) + r < 1.0:
			return true
	if c.y > 5.5 and absf(c.z) > 1.0:
		var hsh := fposmod(sin(c.x * 12.9898 + c.y * 78.233 + c.z * 37.719) * 43758.5453, 1.0)
		return hsh < 0.025
	return false


static func _casco(v: Vale, o: Ruinas.Obra, xf: Transform3D) -> void:
	var verts := {"casco_navio": PackedVector3Array(), "ferrugem": PackedVector3Array()}
	var nrms := {"casco_navio": PackedVector3Array(), "ferrugem": PackedVector3Array()}
	var colisao := {"faces": PackedVector3Array()}  # num dicionário: a função de dentro guarda nele (a lista solta seria cópia)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, fora: Vector3, mat: String) -> void:
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-8:
			return
		if n.dot(fora) < 0.0:
			var tr := b
			b = c
			c = tr
			n = -n
		n = n.normalized()
		var vs: PackedVector3Array = verts[mat]
		var ns: PackedVector3Array = nrms[mat]
		vs.append_array(PackedVector3Array([a, b, c]))
		ns.append_array(PackedVector3Array([n, n, n]))
		verts[mat] = vs
		nrms[mat] = ns
		var fs: PackedVector3Array = colisao["faces"]
		fs.append_array(PackedVector3Array([a, b, c]))
		colisao["faces"] = fs
	for lado: float in [-1.0, 1.0]:
		for pele in 2:
			var dentro := CHAPA if pele == 1 else 0.0
			for i in ESTACOES:
				var u0 := -1.0 + 2.0 * i / ESTACOES
				var u1 := -1.0 + 2.0 * (i + 1) / ESTACOES
				for j in VOLTA:
					var s0 := float(j) / VOLTA
					var s1 := float(j + 1) / VOLTA
					var a := _ponto(u0, s0, lado, dentro)
					var b := _ponto(u1, s0, lado, dentro)
					var c := _ponto(u1, s1, lado, dentro)
					var d := _ponto(u0, s1, lado, dentro)
					var meio := (a + b + c + d) * 0.25
					if _furo(meio):
						continue
					# para fora do casco: para o lado, para baixo perto da quilha e para a frente na proa
					var y_meio := (_alto(u0) + _quilha(u0)) * 0.5
					var fora := Vector3(maxf(0.0, u0 - 0.3) * 3.0, (meio.y - y_meio) * 0.6, meio.z)
					if pele == 1:
						fora = -fora
					var mat := "casco_navio" if pele == 0 and meio.y > _alto(u0) - 3.0 else "ferrugem"
					tri.call(a, b, c, fora, mat)
					tri.call(a, c, d, fora, mat)
			# a borda de cima, entre as duas chapas
			for i in ESTACOES:
				var u0 := -1.0 + 2.0 * i / ESTACOES
				var u1 := -1.0 + 2.0 * (i + 1) / ESTACOES
				var a := _ponto(u0, 0.0, lado, 0.0)
				var b := _ponto(u1, 0.0, lado, 0.0)
				var c := _ponto(u1, 0.0, lado, CHAPA)
				var d := _ponto(u0, 0.0, lado, CHAPA)
				tri.call(a, b, c, Vector3.UP, "ferrugem")
				tri.call(a, c, d, Vector3.UP, "ferrugem")
	# o espelho de popa: a chapa reta atrás, por fora e por dentro
	for pele in 2:
		var dentro := CHAPA if pele == 1 else 0.0
		var x0 := -COMP * 0.5 + dentro
		var meio := Vector3(x0, (_alto(-1.0) + _quilha(-1.0)) * 0.5, 0.0)
		var borda: Array[Vector3] = []
		for j in VOLTA + 1:
			borda.append(_ponto(-1.0, float(j) / VOLTA, 1.0, dentro))
		for j in range(VOLTA, -1, -1):
			borda.append(_ponto(-1.0, float(j) / VOLTA, -1.0, dentro))
		for k in borda.size() - 1:
			var a := borda[k]
			var b := borda[k + 1]
			a.x = x0
			b.x = x0
			tri.call(meio, a, b, Vector3(-1.0 if pele == 0 else 1.0, 0, 0), "casco_navio" if pele == 0 else "ferrugem")
	for nome: String in verts:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts[nome]
		arr[Mesh.ARRAY_NORMAL] = nrms[nome]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(0, v.material(nome))
		var mi := MeshInstance3D.new()
		mi.name = "Casco_" + nome
		mi.mesh = m
		mi.transform = xf
		v.add_child(mi)
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(colisao["faces"])
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.transform = xf
	o.corpo.add_child(cs)


# ---------------------------------------------------------------- o convés e o comando

## As chapas do convés, de borda a borda; sobre o porão da frente caíram quase todas (uma ficou pendurada
## para dentro). A tampa do porão de trás ainda está lá.
static func _conves(o: Ruinas.Obra) -> void:
	var x := -12.6
	var k := 0
	while x < 23.0 - 4.0:
		var u := x / 23.0
		var w := _meia_boca(u) / E * 2.0 - 0.3
		var y := _alto(u) / E - 0.14
		k += 1
		if x > -1.5 and x < 9.5:
			if k % 3 == 0:
				# pendurada: presa num lado, caída para dentro do porão
				_b(o, Vector3(x, y - 1.6, -0.8), Vector3(3.4, 0.22, w * 0.8), Basis(Vector3.RIGHT, 0.55), "ferrugem")
			x += 3.6
			continue
		_b(o, Vector3(x, y, 0.0), Vector3(3.5, 0.24, w), Basis(Vector3.BACK, o.j(0.015)), "ferrugem" if k % 4 != 1 else "casco_navio")
		x += 3.6
	# a tampa do porão de trás e a borda do porão da frente
	_b(o, Vector3(-6.5, 6.5 + 0.45, 0.0), Vector3(8.5, 0.9, 5.4), Basis.IDENTITY, "casco_navio")
	for zs: float in [-2.9, 2.9]:
		_b(o, Vector3(4.0, 6.5 + 0.35, zs), Vector3(11.0, 0.7, 0.3), Basis.IDENTITY, "ferrugem")
	# o guindaste: o mastro de pé no meio e a lança tombada por cima do porão aberto
	_b(o, Vector3(-1.4, 6.5 + 2.6, 2.6), Vector3(0.9, 5.2, 0.9), Basis.IDENTITY, "lata_ocre")
	MarcosMar._trelica(o, Vector3(-1.4, 6.5 + 4.9, 2.6) * E, Vector3(10.5, 6.5 + 0.9, -3.4) * E, 0.75 * E, 0.14 * E, "lata_ocre")
	# o mastro de vante, com a verga
	_b(o, Vector3(16.0, _alto(0.7) / E + 4.4, 0.0), Vector3(0.36, 8.8, 0.36), Basis.IDENTITY, "ferrugem", false)
	_b(o, Vector3(16.0, _alto(0.7) / E + 7.4, 0.0), Vector3(0.22, 0.22, 4.4), Basis.IDENTITY, "ferrugem", false)


## A casa do comando na popa: dois andares de tinta branca encardida, a ponte com a fileira de janelas de
## vidro sujo, a chaminé e o mastrinho do rádio.
static func _comando(o: Ruinas.Obra) -> void:
	var y0 := _alto(-0.75) / E
	_b(o, Vector3(-17.6, y0 + 1.6, 0.0), Vector3(7.2, 3.2, 7.6), Basis.IDENTITY, "tinta_branca")
	_b(o, Vector3(-18.0, y0 + 4.4, 0.0), Vector3(5.2, 2.4, 8.8), Basis.IDENTITY, "tinta_branca")
	_b(o, Vector3(-18.0, y0 + 5.7, 0.0), Vector3(5.8, 0.24, 9.2), Basis.IDENTITY, "ferrugem")
	# as janelas da ponte, de frente para a proa e dos lados
	_b(o, Vector3(-15.36, y0 + 4.6, 0.0), Vector3(0.14, 0.9, 7.6), Basis.IDENTITY, "vidro_velho", false)
	for zs: float in [-1.0, 1.0]:
		_b(o, Vector3(-18.0, y0 + 4.6, zs * 4.42), Vector3(3.6, 0.8, 0.12), Basis.IDENTITY, "vidro_velho", false)
		for k in 3:
			_b(o, Vector3(-19.6 + k * 2.0, y0 + 1.9, zs * 3.82), Vector3(0.8, 0.8, 0.1), Basis.IDENTITY, "vidro_velho", false)
	# a chaminé, com a faixa escura em cima
	var cano := CylinderMesh.new()
	cano.top_radius = 0.85 * E
	cano.bottom_radius = 1.0 * E
	cano.height = 3.4 * E
	cano.radial_segments = 12
	o._solto(cano, Vector3(-20.4, y0 + 4.9, 0.0) * E, "chamine")
	var faixa := CylinderMesh.new()
	faixa.top_radius = 0.87 * E
	faixa.bottom_radius = 0.9 * E
	faixa.height = 0.5 * E
	faixa.radial_segments = 12
	o._solto(faixa, Vector3(-20.4, y0 + 6.4, 0.0) * E, "junta")
	_b(o, Vector3(-17.4, y0 + 7.2, 0.0), Vector3(0.16, 2.8, 0.16), Basis.IDENTITY, "ferrugem", false)
	_b(o, Vector3(-17.4, y0 + 8.0, 0.0), Vector3(0.12, 0.12, 2.2), Basis.IDENTITY, "ferrugem", false)


## Um bloco na medida do desenho (o navio de 46 m), crescido por E.
static func _b(o: Ruinas.Obra, c: Vector3, tam: Vector3, giro := Basis.IDENTITY, mat := "ferrugem", colide := true) -> void:
	o.bloco(c * E, tam * E, giro, mat, colide)
