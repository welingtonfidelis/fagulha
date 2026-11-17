class_name Ruinas
extends RefCounted
## As ruínas antigas da mata do oeste (2026-11-15), as três da maquete aprovada, espalhadas:
## Os Arcos (um aqueduto partido), A Torre Caída (meia torre de pé, o topo tombado ao lado) e
## O Pátio das Máquinas (muros baixos, colunas e o berço de onde as máquinas saíam).
## Tudo é montado pedra por pedra por código: cada bloco é uma peça talhada com a sua própria colisão,
## então dá para voar por baixo dos arcos, por dentro da torre e pousar em cima do que sobrou.
## A pedra é clara e gasta, e o musgo toma as faces de cima (vale_ruina.gdshader).

# x, z e giro de cada lugar (os três em chão quase plano, a uns 270 m um do outro)
const ARCOS := Vector3(-730, 30, 0.35)
const TORRE := Vector3(-640, 440, 1.1)
const PATIO := Vector3(-680, 170, -0.25)

const VAO := 11.0  # de um pilar ao outro
const NASCENCA := 8.5  # altura de onde o arco começa
const TORRE_RAIO := 5.85
const PATIO_MEIO := Vector2(15, 11)


## Árvore pode nascer aqui? (não dentro das obras nem coladas nelas: cada ruína fica num claro pequeno da mata)
## A base do robô, no ponto de nascimento da clareira (x, z, giro): a frente (-Z do lugar) olha o campo.
const BASE := Vector3(2.0, 44.0, -0.233)


static func livre(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if p.distance_to(Fundicao.CENTRO) < Fundicao.RAIO + 22.0:
		return false
	var eixo := Vector2(cos(ARCOS.z), -sin(ARCOS.z))
	var a := Vector2(ARCOS.x, ARCOS.y)
	var t := clampf((p - a).dot(eixo), -34.0, 40.0)
	if p.distance_to(a + eixo * t) < 15.0:
		return false
	if p.distance_to(Vector2(TORRE.x, TORRE.y)) < 21.0:
		return false
	var caido := Basis(Vector3.UP, TORRE.z) * Vector3(17, 0, 5)
	if p.distance_to(Vector2(TORRE.x + caido.x, TORRE.y + caido.z)) < 15.0:
		return false
	var l := Basis(Vector3.UP, -PATIO.z) * Vector3(x - PATIO.x, 0, z - PATIO.y)
	return absf(l.x) > PATIO_MEIO.x + 10.0 or absf(l.z) > PATIO_MEIO.y + 10.0


static func montar(v: Vale) -> void:
	var t0 := Time.get_ticks_msec()
	var blocos: Array[PackedVector3Array] = []
	for k in 6:
		blocos.append(_cubo_talhado(11 + k * 5, 3 + k % 3))
	var tambores: Array[PackedVector3Array] = []
	for k in 3:
		tambores.append(_tambor(7 + k * 3))
	var total := 0
	for sitio: Array in [["Arcos", ARCOS], ["Torre", TORRE], ["Patio", PATIO], ["Base", BASE]]:
		var d: Vector3 = sitio[1]
		var o := Obra.new()
		o.v = v
		o.blocos = blocos
		o.tambores = tambores
		o.na_clareira = sitio[0] == "Base"
		o.t = Transform3D(Basis(Vector3.UP, d.z), Vector3(d.x, v.altura(d.x, d.y) if o.na_clareira else v._fora(d.x, d.y), d.y))
		o.rng.seed = hash(sitio[0])
		o.corpo = StaticBody3D.new()
		o.corpo.name = "Ruina" + sitio[0]
		o.corpo.collision_layer = 1
		o.corpo.collision_mask = 0
		v.add_child(o.corpo)
		match sitio[0]:
			"Arcos":
				_arcos(o)
			"Torre":
				_torre(o)
			"Patio":
				_patio(o)
			"Base":
				_base(o)
		o.fechar()
		total += o.pecas
	print("ruínas: %d peças, %d ms" % [total, Time.get_ticks_msec() - t0])


# ---------------------------------------------------------------- A Base

## Onde o robô nasce e reaparece depois do curto: o hangar em ruínas (scripts/vale/base_vale.gd).
static func _base(o: Obra) -> void:
	BaseVale.montar(o)


# ---------------------------------------------------------------- Os Arcos

static func _arcos(o: Obra) -> void:
	var curso := 1.3
	var alturas := [NASCENCA, NASCENCA, NASCENCA, NASCENCA, 5.2, 2.0]  # os dois últimos pilares são tocos
	var arcos := [9, 9, 9, 4, 0]  # quantas pedras do arco sobraram (9 = inteiro), a partir do pilar da esquerda
	for k in 6:
		var lx := (k - 2.5) * VAO
		var y := o.chao(lx, 0.0) - 1.2
		var topo: float = alturas[k]
		var j := 0
		while y < topo - 0.05:
			var h := minf(curso, topo - y)
			if j % 2 == 0:
				o.bloco(Vector3(lx + o.j(0.06), y + h * 0.5, o.j(0.06)), Vector3(2.6 + o.j(0.08), h, 3.2 + o.j(0.08)), Basis(Vector3.UP, o.j(0.025)))
			else:
				# fiada de duas pedras, para a junta não subir reta
				o.bloco(Vector3(lx + o.j(0.05), y + h * 0.5, -0.82), Vector3(2.6 + o.j(0.08), h, 1.58), Basis(Vector3.UP, o.j(0.03)))
				o.bloco(Vector3(lx + o.j(0.05), y + h * 0.5, 0.82), Vector3(2.6 + o.j(0.08), h, 1.58), Basis(Vector3.UP, o.j(0.03)))
			y += h
			j += 1
		if topo >= NASCENCA:
			o.bloco(Vector3(lx, NASCENCA + 0.02, 0), Vector3(3.0, 0.5, 3.6))  # a imposta, onde os arcos apoiam
	var rm := 4.2 + 0.575
	for a in 5:
		var cx := (a - 2.0) * VAO
		for i in int(arcos[a]):
			var ang := PI * (i + 0.5) / 9.0
			var gordo := 1.12 if i == 4 else 1.0  # a pedra do fecho
			o.bloco(Vector3(cx - cos(ang) * rm, NASCENCA + 0.25 + sin(ang) * rm, 0), Vector3(PI * rm / 9.0 * 1.03, 1.15 * gordo, 3.2 + o.j(0.05)),
				Basis(Vector3(0, 0, 1), PI * 0.5 - ang + o.j(0.02)))
	# o enchimento entre os arcos, em cima de cada pilar
	for k in 5:
		var lx := (k - 2.5) * VAO
		var esq: bool = k > 0 and int(arcos[k - 1]) == 9
		var dir: bool = int(arcos[k]) == 9
		if not esq and not dir:
			continue
		for yr: float in [2.1, 3.3, 4.5]:
			var w := 5.5 - sqrt(maxf(0.0, 5.35 * 5.35 - yr * yr))
			var we := w if esq or k == 0 else 0.5
			var wd := w if dir else 0.5
			o.bloco(Vector3(lx + (wd - we) * 0.5, NASCENCA + 0.25 + yr, 0), Vector3(we + wd, 1.2, 3.2 + o.j(0.06)))
	# o leito por cima, até onde ainda há arco
	var x := -2.5 * VAO - 1.6
	while x < 0.5 * VAO + 1.0:
		var c := 3.7 + o.j(0.3)
		o.bloco(Vector3(x + c * 0.5, NASCENCA + 0.25 + 5.65 + o.j(0.03), o.j(0.05)), Vector3(c - 0.04, 1.1, 3.8), Basis(Vector3.UP, o.j(0.015)))
		x += c
	# a última laje pendendo, e as que caíram
	o.bloco(Vector3(x + 1.2, NASCENCA + 5.5, 0.2), Vector3(3.0, 1.1, 3.6), Basis(Vector3(0, 0, 1), -0.22))
	o.bloco(Vector3(13.5, o.chao(13.5, 2.5) + 0.3, 2.5), Vector3(3.6, 1.1, 3.7), Basis.from_euler(Vector3(0.12, 0.6, 0.3)))
	o.bloco(Vector3(20.0, o.chao(20.0, -3.5) + 0.5, -3.5), Vector3(3.4, 1.1, 3.6), Basis.from_euler(Vector3(-0.5, 1.9, 0.15)))
	o.entulho(Vector2(22.0, 0.0), Vector2(15.0, 8.0), 22, 0.7, 2.1)
	o.entulho(Vector2(-12.0, 0.0), Vector2(18.0, 6.0), 7, 0.5, 1.2)
	for p: Vector2 in [Vector2(-24, 0.6), Vector2(-9, -0.9), Vector2(1, 0.8)]:
		o.arbusto(Vector3(p.x, NASCENCA + 6.4, p.y), 1.1)
	for p: Vector2 in [Vector2(-31, 3), Vector2(-15, -3.6), Vector2(-4, 3.4), Vector2(7, -3.8), Vector2(16, 5.5), Vector2(24, -5), Vector2(30, 2.4), Vector2(11.5, 0.5)]:
		o.arbusto(Vector3(p.x, o.chao(p.x, p.y), p.y), 1.5)


# ---------------------------------------------------------------- A Torre Caída

static func _torre(o: Obra) -> void:
	var base := Vector3(0, o.chao_min(Vector2.ZERO, 7.0) - 1.0, 0)
	var alto := 0.0  # para que lado a parede ficou inteira
	var porta := PI * 0.82
	# de pé: 15 fiadas no lado inteiro, descendo em serra até duas no lado que desabou
	var fiadas := func(i: int, _j: int, phi: float) -> bool:
		var inteira := pow((cos(phi - alto) + 1.0) * 0.5, 1.25)
		var n := roundi(lerpf(2.6, 15.6, inteira) + sin(i * 2.3) * 0.9)
		if _j >= n:
			return false
		if _j >= 1 and _j < 4 and absf(angle_difference(phi, porta)) < 0.33:
			return false  # a porta
		if (_j == 7 or _j == 8) and (absf(angle_difference(phi, alto + 0.95)) < 0.2 or absf(angle_difference(phi, alto - 0.95)) < 0.2):
			return false  # janelas
		if (_j == 11 or _j == 12) and absf(angle_difference(phi, alto)) < 0.2:
			return false
		return true
	o.anel(base, Basis.IDENTITY, TORRE_RAIO, 1.3, 1.2, 14, 16, fiadas)
	# o que sobrou dos pisos, presos no lado inteiro (dá para pousar)
	for piso: Array in [[5, 1.25], [10, 0.85]]:
		for i in 14:
			var phi := (i + 0.5) * TAU / 14.0
			if absf(angle_difference(phi, alto)) > (piso[1] as float):
				continue
			o.bloco(base + Vector3(cos(phi) * 3.75, (piso[0] as int) * 1.2 + 0.2, sin(phi) * 3.75), Vector3(TAU * 3.75 / 14.0 * 1.25, 0.4, 3.0),
				Basis(Vector3.UP, PI * 0.5 - phi + o.j(0.03)))
	# o topo tombado: um tubo deitado, meio enterrado, de onde se vê o céu pelos buracos
	var deitado := Basis(Vector3.UP, 0.5) * Basis(Vector3(0, 0, 1), -PI * 0.5 + 0.1)
	var c2 := Vector3(13.5, 0, 5.0)
	c2.y = o.chao(c2.x + 3.0, c2.z) + TORRE_RAIO - 1.0
	var tombado := func(i: int, _j: int, _phi: float) -> bool:
		var sorte := absf(sin(i * 12.9898 + _j * 78.233) * 43758.5453)
		sorte -= floorf(sorte)
		if sorte < 0.17:
			return false
		return _j < 4 + roundi(sin(i * 1.7) * 1.4)
	o.anel(c2, deitado, TORRE_RAIO, 1.3, 1.2, 14, 6, tombado)
	# no meio da torre, o núcleo apagado de uma máquina antiga
	var cy := o.chao(0, 0)
	o.aro(Vector3(0, cy + 0.55, 0), 2.0, 3.1, "casco")
	o.bola(Vector3(0, cy + 1.2, 0), 1.3, "junta")
	o.bloco(Vector3(2.1, cy + 1.3, 0.4), Vector3(0.22, 3.2, 0.22), Basis.from_euler(Vector3(0.2, 0, -0.7)), "ferrugem", false)
	o.bloco(Vector3(-1.6, cy + 1.0, -1.5), Vector3(0.2, 2.4, 0.2), Basis.from_euler(Vector3(-0.8, 0.4, 0.5)), "ferrugem", false)
	var cil := CylinderShape3D.new()
	cil.radius = 3.0
	cil.height = 1.6
	o.forma(cil, Transform3D(Basis.IDENTITY, Vector3(0, cy + 0.6, 0)))
	o.entulho(Vector2(-7.5, 1.0), Vector2(6.0, 7.0), 20, 0.7, 2.0)
	o.entulho(Vector2(7.0, 4.0), Vector2(6.0, 4.0), 9, 0.6, 1.6)
	o.entulho(Vector2(0.0, 0.0), Vector2(4.2, 4.2), 6, 0.5, 1.0)
	for p: Vector2 in [Vector2(-9, -4), Vector2(-8, 6), Vector2(4.5, -8.5), Vector2(9, 9.5), Vector2(-3.4, 2.6), Vector2(19, -1), Vector2(15, 11)]:
		o.arbusto(Vector3(p.x, o.chao(p.x, p.y), p.y), 1.5)
	o.arbusto(Vector3(3.6, base.y + 6.6, 0.8), 1.0)


# ---------------------------------------------------------------- O Pátio das Máquinas

static func _patio(o: Obra) -> void:
	var m := PATIO_MEIO
	# o muro em volta: sobe e desce, some em alguns trechos, e os quatro cantos ficaram mais altos
	var cantos := [Vector2(-m.x, -m.y), Vector2(m.x, -m.y), Vector2(m.x, m.y), Vector2(-m.x, m.y)]
	var s := 0.0
	for lado in 4:
		var a: Vector2 = cantos[lado]
		var b: Vector2 = cantos[(lado + 1) % 4]
		var comp := a.distance_to(b)
		var n := roundi(comp / 2.6)
		var passo := comp / n
		var dir := (b - a) / comp
		for i in n:
			var p := a + dir * (i + 0.5) * passo
			var d := (i + 0.5) * passo
			var fiadas := clampi(roundi(2.1 + 1.5 * sin((s + d) * 0.21 + 1.0) + 1.1 * sin((s + d) * 0.53)), 0, 4)
			if d < 3.0 or d > comp - 3.0:
				fiadas = 5 - int(i % 2 == 1 and lado % 2 == 0)
			if lado == 1 and absf(d - comp * 0.5) < 2.7:
				fiadas = 0  # a entrada
			var y := o.chao(p.x, p.y) - 0.45
			for jf in fiadas:
				var desloc := dir * (passo * 0.5 if jf % 2 == 1 and i < n - 1 else 0.0)
				o.bloco(Vector3(p.x + desloc.x + o.j(0.04), y + jf + 0.5, p.y + desloc.y + o.j(0.04)), Vector3(passo * 1.01, 1.0, 1.2 + o.j(0.06)),
					Basis(Vector3.UP, atan2(-dir.y, dir.x) + o.j(0.02)))
		s += comp
	# o estrado de pedra, em dois degraus
	var cy := o.chao_min(Vector2.ZERO, 5.5) - 0.3
	o.tambor(Vector3(0, cy, 0), Vector3(11.0, 0.75, 11.0))
	o.tambor(Vector3(0, cy + 0.75, 0), Vector3(8.4, 0.45, 8.4), 0.3)
	var topo := cy + 1.2
	# o berço: um aro de metal sobre calços, a cúpula no meio e a lente ainda acesa, bem fraca
	for k in 4:
		var ang := k * TAU / 4.0 + 0.4
		o.bloco(Vector3(cos(ang) * 2.65, topo + 0.3, sin(ang) * 2.65), Vector3(0.7, 0.6, 0.7), Basis(Vector3.UP, -ang), "casco_claro", false)
	o.aro(Vector3(0, topo + 0.75, 0), 2.3, 3.0, "casco")
	o.bola(Vector3(0, topo - 0.1, 0), 1.45, "casco")
	o.bola(Vector3(0, topo + 0.55, 0), 1.1, "casco_claro")
	o.lente(Vector3(0.5, topo + 1.38, 0.56), 0.2)
	o.bloco(Vector3(-2.9, topo + 1.6, 1.0), Vector3(0.24, 4.4, 0.24), Basis.from_euler(Vector3(0.25, 0.3, 0.55)), "ferrugem", false)
	o.bloco(Vector3(2.2, topo + 1.2, -2.3), Vector3(0.22, 3.4, 0.22), Basis.from_euler(Vector3(-0.5, 0.2, -0.45)), "ferrugem", false)
	var cil := CylinderShape3D.new()
	cil.radius = 3.0
	cil.height = 2.0
	o.forma(cil, Transform3D(Basis.IDENTITY, Vector3(0, topo + 0.6, 0)))
	# as colunas em volta: três inteiras (duas ainda seguram a viga), as outras quebradas
	var tambores_de := [6, 6, 3, 1, 6, 2]
	var pes: Array[Vector3] = []
	for k in 6:
		var ang := k * TAU / 6.0 + 0.52
		var p := Vector2(cos(ang) * 8.4, sin(ang) * 8.4)
		var y := o.chao(p.x, p.y) - 0.3
		o.bloco(Vector3(p.x, y + 0.25, p.y), Vector3(2.1, 0.5, 2.1), Basis(Vector3.UP, -ang))
		y += 0.5
		for jd in int(tambores_de[k]):
			o.tambor(Vector3(p.x + o.j(0.035), y, p.y + o.j(0.035)), Vector3(1.45, 1.3, 1.45), o.rng.randf() * TAU)
			y += 1.3
		if int(tambores_de[k]) == 6:
			o.bloco(Vector3(p.x, y + 0.25, p.y), Vector3(2.0, 0.5, 2.0), Basis(Vector3.UP, -ang))
			y += 0.5
		pes.append(Vector3(p.x, y, p.y))
	var meio := (pes[0] + pes[1]) * 0.5
	var vao := pes[1] - pes[0]
	o.bloco(meio + Vector3(0, 0.4, 0), Vector3(vao.length() + 1.8, 0.8, 1.4), Basis(Vector3.UP, atan2(-vao.z, vao.x)))
	# a coluna que tombou para fora, os tambores em fila
	var ang3 := 3 * TAU / 6.0 + 0.52
	var fora := Vector2(cos(ang3), sin(ang3))
	var lado3 := Vector2(-fora.y, fora.x)
	for jd in 4:
		var p := fora * (10.6 + jd * 1.45) + lado3 * (jd * 0.35 + o.j(0.12))
		if absf(p.x) > m.x - 1.5 or absf(p.y) > m.y - 1.5:
			break
		o.tambor(Vector3(p.x, o.chao(p.x, p.y) + 0.5, p.y), Vector3(1.45, 1.3, 1.45), 0.0, Basis(Vector3.UP, -ang3 + jd * 0.12) * Basis(Vector3(0, 0, 1), -PI * 0.5), true)
	o.entulho(Vector2(8.0, -6.0), Vector2(5.0, 3.5), 9, 0.5, 1.3)
	o.entulho(Vector2(-10.0, 5.0), Vector2(3.5, 4.0), 8, 0.5, 1.4)
	o.entulho(Vector2(16.0, 0.0), Vector2(2.5, 4.0), 6, 0.6, 1.5)
	for p: Vector2 in [Vector2(-13, -9), Vector2(-12.5, 8.5), Vector2(12.6, -9.2), Vector2(13, 8.6), Vector2(-5, -9.6), Vector2(4, 9.7), Vector2(-13.8, 0.5), Vector2(6.5, -3.4), Vector2(-6.2, 3.8), Vector2(17.5, 3)]:
		o.arbusto(Vector3(p.x, o.chao(p.x, p.y), p.y), 1.5)


# ---------------------------------------------------------------- as peças

## Um cubo de lado 1 gasto: cantos e quinas lascados, faces um pouco tortas. Volta os triângulos soltos.
static func _cubo_talhado(semente: int, lascas: int) -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var planos: Array = []
	for k in lascas:
		var d := Vector3(1.0 if rng.randf() < 0.5 else -1.0, 1.0 if rng.randf() < 0.6 else -1.0, 1.0 if rng.randf() < 0.5 else -1.0).normalized()
		planos.append([d, 0.866 * rng.randf_range(0.74, 0.9)])
	for k in 3:
		var e := [Vector3(1, 1, 0), Vector3(0, 1, 1), Vector3(1, 0, 1), Vector3(-1, 1, 0), Vector3(0, 1, -1), Vector3(1, 0, -1)][rng.randi() % 6] as Vector3
		planos.append([e.normalized(), 0.7071 * rng.randf_range(0.86, 0.95)])
	var n := 2
	var faces := [[Vector3.RIGHT, Vector3.UP], [Vector3.LEFT, Vector3.UP], [Vector3.UP, Vector3.BACK], [Vector3.DOWN, Vector3.FORWARD], [Vector3.BACK, Vector3.UP], [Vector3.FORWARD, Vector3.UP]]
	var tris := PackedVector3Array()
	for f: Array in faces:
		var nf: Vector3 = f[0]
		var u: Vector3 = f[1]
		var w: Vector3 = nf.cross(u)
		var grade: Array[Vector3] = []
		for j in n + 1:
			for i in n + 1:
				var p := (nf + u * (float(i) / n * 2.0 - 1.0) + w * (float(j) / n * 2.0 - 1.0)) * 0.5
				var r := sin(p.x * 12.9 + p.y * 78.2 + p.z * 37.7 + semente) * 43758.5
				p += p.normalized() * ((r - floorf(r)) - 0.5) * 0.035
				for pl: Array in planos:
					var sobra := p.dot(pl[0]) - (pl[1] as float)
					if sobra > 0.0:
						p -= (pl[0] as Vector3) * sobra
				grade.append(p)
		for j in n:
			for i in n:
				var a := grade[j * (n + 1) + i]
				var b := grade[j * (n + 1) + i + 1]
				var c := grade[(j + 1) * (n + 1) + i + 1]
				var d := grade[(j + 1) * (n + 1) + i]
				_tri(tris, a, b, c)
				_tri(tris, a, c, d)
	return tris


## Um tambor de coluna: de y = 0 a 1, raio 0,5, dez lados, com as beiras gastas.
static func _tambor(semente: int) -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var lados := 10
	var baixo: Array[Vector3] = []
	var cima: Array[Vector3] = []
	var gola_b: Array[Vector3] = []
	var gola_c: Array[Vector3] = []
	for i in lados:
		var a := i * TAU / lados
		var r := 0.5 * rng.randf_range(0.965, 1.0)
		var lasca := 0.82 if rng.randf() < 0.18 else 0.93
		gola_b.append(Vector3(cos(a) * r * 0.93, 0.0, sin(a) * r * 0.93))
		baixo.append(Vector3(cos(a) * r, 0.07, sin(a) * r))
		cima.append(Vector3(cos(a) * r, 0.93 - (1.0 - lasca) * 0.5, sin(a) * r))
		gola_c.append(Vector3(cos(a) * r * lasca, 1.0, sin(a) * r * lasca))
	var tris := PackedVector3Array()
	for i in lados:
		var k := (i + 1) % lados
		for par: Array in [[gola_b, baixo], [baixo, cima], [cima, gola_c]]:
			var de: Array[Vector3] = par[0]
			var ate: Array[Vector3] = par[1]
			_tri(tris, de[i], de[k], ate[k])
			_tri(tris, de[i], ate[k], ate[i])
		_tri(tris, Vector3(0, 1, 0), gola_c[i], gola_c[k])
		_tri(tris, Vector3(0, 0, 0), gola_b[k], gola_b[i])
	return tris


## Guarda um triângulo (quem vira para fora é a Obra, ao juntar a peça).
static func _tri(tris: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (c - a).cross(b - a).length_squared() > 1e-12:
		tris.append_array(PackedVector3Array([a, b, c]))


## Uma obra em construção: junta os triângulos de todas as peças numa malha só por material e
## põe uma forma de colisão por peça.
class Obra:
	var v: Vale
	var t: Transform3D  # do lugar para o mundo (a origem fica no chão, no meio da obra)
	var corpo: StaticBody3D
	var rng := RandomNumberGenerator.new()
	var blocos: Array[PackedVector3Array]
	var tambores: Array[PackedVector3Array]
	var pecas := 0
	var na_clareira := false  # a base fica dentro da clareira, onde o chão é o da clareira
	var _verts := {}
	var _nrms := {}

	func j(amp: float) -> float:
		return rng.randf_range(-amp, amp)

	## Altura do terreno num ponto do lugar, na medida do lugar (0 = o chão no meio da obra).
	func chao(lx: float, lz: float) -> float:
		var p := t * Vector3(lx, 0, lz)
		return (v.altura(p.x, p.z) if na_clareira else v._fora(p.x, p.z)) - t.origin.y

	func chao_min(c: Vector2, raio: float) -> float:
		var m := chao(c.x, c.y)
		for k in 8:
			m = minf(m, chao(c.x + cos(k * TAU / 8.0) * raio, c.y + sin(k * TAU / 8.0) * raio))
		return m

	func _juntar(tris: PackedVector3Array, xf: Transform3D, mat: String, centro_y := 0.0) -> void:
		if not _verts.has(mat):
			_verts[mat] = PackedVector3Array()
			_nrms[mat] = PackedVector3Array()
		var vs: PackedVector3Array = _verts[mat]
		var ns: PackedVector3Array = _nrms[mat]
		var mundo := t * xf
		var meio := mundo * Vector3(0, centro_y, 0)
		var i := 0
		while i < tris.size():
			var a := mundo * tris[i]
			var b := mundo * tris[i + 1]
			var c := mundo * tris[i + 2]
			var n := (c - a).cross(b - a).normalized()
			if n.dot((a + b + c) / 3.0 - meio) < 0.0:
				n = -n
				var troca := b
				b = c
				c = troca
			vs.append_array(PackedVector3Array([a, b, c]))
			ns.append_array(PackedVector3Array([n, n, n]))
			i += 3
		_verts[mat] = vs
		_nrms[mat] = ns
		pecas += 1

	func forma(f: Shape3D, xf: Transform3D) -> void:
		var cs := CollisionShape3D.new()
		cs.shape = f
		cs.transform = t * xf
		corpo.add_child(cs)
		var w := cs.transform.origin
		Obstaculos.registrar_forma(f, cs.transform, v.altura(w.x, w.z) if na_clareira else v._fora(w.x, w.z))

	## Um bloco talhado: centro, tamanho e giro, na medida do lugar.
	func bloco(centro: Vector3, tam: Vector3, giro := Basis.IDENTITY, mat := "ruina", colide := true) -> void:
		_juntar(blocos[rng.randi() % blocos.size()], Transform3D(giro.scaled_local(tam), centro), mat)
		if colide:
			var cx := BoxShape3D.new()
			cx.size = tam
			forma(cx, Transform3D(giro, centro))

	## Um tambor de coluna com a base em `pe` (ou deitado, com `giro`).
	func tambor(pe: Vector3, tam: Vector3, volta := 0.0, giro := Basis.IDENTITY, deitado := false) -> void:
		var base := giro * Basis(Vector3.UP, volta)
		var origem := pe - (base * Vector3(0, tam.y * 0.5, 0) if deitado else Vector3.ZERO)
		_juntar(tambores[rng.randi() % tambores.size()], Transform3D(base.scaled_local(tam), origem), "ruina", 0.5)
		var cil := CylinderShape3D.new()
		cil.radius = tam.x * 0.5
		cil.height = tam.y
		forma(cil, Transform3D(base, origem + base * Vector3(0, tam.y * 0.5, 0)))

	## Parede em anel, de blocos: `fica.call(i, fiada, ângulo)` diz se a pedra ainda está lá.
	func anel(base: Vector3, eixo: Basis, raio: float, grossura: float, alt_fiada: float, por_volta: int, fiadas: int, fica: Callable) -> void:
		var arco := TAU * raio / por_volta
		for jf in fiadas:
			for i in por_volta:
				var phi := (i + 0.5 * (jf % 2)) * TAU / por_volta
				if not fica.call(i, jf, phi):
					continue
				var centro := base + eixo * Vector3(cos(phi) * raio, (jf + 0.5) * alt_fiada, sin(phi) * raio)
				bloco(centro, Vector3(arco * 1.07, alt_fiada, grossura + j(0.1)), eixo * Basis(Vector3.UP, PI * 0.5 - phi + j(0.015)))

	## Pedras caídas, meio enterradas, numa mancha em volta de `c`.
	func entulho(c: Vector2, espalha: Vector2, quantas: int, de: float, ate: float) -> void:
		for k in quantas:
			var p := c + Vector2(rng.randfn(0.0, 0.5) * espalha.x, rng.randfn(0.0, 0.5) * espalha.y)
			var tam := Vector3(rng.randf_range(de, ate), rng.randf_range(de, ate) * 0.75, rng.randf_range(de, ate))
			bloco(Vector3(p.x, chao(p.x, p.y) + tam.y * rng.randf_range(0.05, 0.35), p.y), tam,
				Basis.from_euler(Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45))), "ruina", tam.x > 1.0)

	func arbusto(p: Vector3, s: float) -> void:
		var mundo := t * p
		v._por("arbusto", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s * rng.randf_range(0.8, 1.25)), mundo - Vector3(0, 0.1, 0)))

	func aro(c: Vector3, dentro: float, fora: float, mat: String) -> void:
		var m := TorusMesh.new()
		m.inner_radius = dentro
		m.outer_radius = fora
		m.rings = 28
		m.ring_segments = 10
		_solto(m, c, mat)

	func bola(c: Vector3, raio: float, mat: String) -> void:
		var m := SphereMesh.new()
		m.radius = raio
		m.height = raio * 2.0
		m.radial_segments = 20
		m.rings = 10
		_solto(m, c, mat)

	func _solto(m: Mesh, c: Vector3, mat: String) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = v.material(mat)
		mi.transform = t * Transform3D(Basis.IDENTITY, c)
		v.add_child(mi)
		return mi

	## A lente da máquina adormecida: um brilho vermelho fraco, que mal ilumina o berço à noite.
	func lente(c: Vector3, raio: float) -> void:
		var m := SphereMesh.new()
		m.radius = raio
		m.height = raio * 2.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.01, 0.01)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.07, 0.06)
		mat.emission_energy_multiplier = 0.9
		var mi := _solto(m, c, "junta")
		mi.material_override = mat
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.12, 0.08)
		luz.light_energy = 0.14
		luz.omni_range = 5.0
		luz.shadow_enabled = false
		luz.position = Vector3(0, 0.5, 0)
		mi.add_child(luz)

	## A lâmpada da base: acesa, de cor amiga, ilumina o estrado à noite.
	func farol(c: Vector3, raio: float, cor: Color) -> void:
		var m := SphereMesh.new()
		m.radius = raio
		m.height = raio * 2.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cor * 0.2
		mat.emission_enabled = true
		mat.emission = cor
		mat.emission_energy_multiplier = 2.2
		var mi := _solto(m, c, "junta")
		mi.material_override = mat
		var luz := OmniLight3D.new()
		luz.light_color = cor
		luz.light_energy = 0.7
		luz.omni_range = 9.0
		luz.shadow_enabled = false
		luz.position = Vector3(0, -0.4, -0.6)
		mi.add_child(luz)

	func fechar() -> void:
		var mat_pedra := ShaderMaterial.new()
		mat_pedra.shader = load("res://scripts/shaders/vale_ruina.gdshader")
		mat_pedra.set_shader_parameter("ruido", v._tex)
		for nome: String in _verts:
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = _verts[nome]
			arr[Mesh.ARRAY_NORMAL] = _nrms[nome]
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(0, mat_pedra if nome == "ruina" else v.material(nome))
			var mi := MeshInstance3D.new()
			mi.name = "Pedras_" + nome
			mi.mesh = m
			v.add_child(mi)
