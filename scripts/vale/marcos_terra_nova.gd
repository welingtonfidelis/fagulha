class_name MarcosTerraNova
extends RefCounted
## Os marcos de longe da terra nova (2026-11-25, doc §168). Na terra nova, quem andava pelo chão não via nada
## para se orientar em um terço do mapa. Com estes, de quase todo lugar se veem dois ou mais:
## - a igrejinha do Vilarejo, com a torre do sino de 29 m, na beira do platô;
## - o mastro do cume da Montanha do Degelo, fino, com a luz vermelha (a montanha é o marco, ele dá o ponto);
## - a Árvore Branca, uma bétula de 70 m de copa prateada numa clareira do sopé oeste;
## - o Comboio da Neve (ideia do usuário): um trem de expedição de três carros (a base móvel da KayKit, pintada
##   de laranja-polar) que subia a montanha e quebrou no meio do caminho, parado numa encosta nevada do ombro,
##   de frente para o morro, com as rodas afundadas na neve.
## Os outros dois ficam com quem já existia: o mastro alto do navio (`Naufragio._conves`) e a coluna de vapor
## do gêiser (`VaporFonte.pluma`, em `TerraNova._fontes`).

const IGREJA := Vector2(-776.7, -2669.3)  # na beira do platô do Vilarejo, a 80 m da praça
const IGREJA_LIVRE := 16.0  # a mata não planta aqui
const CUME_BUSCA := Rect2(-2950.0, -2950.0, 250.0, 250.0)  # o pico fica aqui dentro (o ponto mais alto)
const ARVORE := Vector2(-3010.0, -1440.0)
const ARVORE_ALTA := 70.0
const ARVORE_CLAREIRA := 30.0
## O meio do trem (o vagão), numa encosta nevada do ombro da montanha, a 520 m, acima do lago do circo. Achado
## numa busca pelo relevo de 5 em 5 m: quase toda a montanha é paredão ou chão áspero demais para um carro de 13 m.
const COMBOIO := Vector2(-2750.0, -2700.0)
const COMBOIO_RUMO := 0.017  # para onde a cabine olha, morro acima: (sin, cos) em (x, z)
const COMBOIO_LIVRE := 40.0
const COMBOIO_ESCALA := 6.5  # a base móvel da KayKit mede 2 m: cada carro fica com 13 m, o porte dos gigantes
const COMBOIO_PASTA := "res://assets/vale/comboio/"
## Os carros, da frente para trás: [peça, quanto anda na direção da frente (m), desvio de lado (m), giro].
## O último saiu da trilha e ficou torto.
const COMBOIO_CARROS := [
	["mobile_base_command", 14.6, 0.0, 0.0],
	["mobile_base_carriage", 0.0, 0.0, 0.06],
	["mobile_base_cargo", -15.6, 1.6, 0.3],
]

const NOME_CUME := "O Cume do Degelo"
const NOME_ARVORE := "A Árvore Branca"
const NOME_COMBOIO := "O Comboio da Neve"

static var igreja := Vector3.INF  # o pé da torre do sino
static var cume := Vector3.INF  # o pé do mastro, no pico
static var cume_topo := Vector3.INF
static var arvore := Vector3.INF
static var comboio := Vector3.INF
static var montados := 0


## A mata da terra nova não planta no lugar dos marcos (`TerraNova.plantar`).
static func sem_mata(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	return p.distance_to(IGREJA) < IGREJA_LIVRE or p.distance_to(ARVORE) < ARVORE_CLAREIRA or p.distance_to(COMBOIO) < COMBOIO_LIVRE


static func montar(v: Vale) -> void:
	if v.terra_nova == null:
		return
	var t0 := Time.get_ticks_msec()
	montados = 0
	_igreja(v)
	_cume(v)
	_arvore(v)
	_comboio(v)
	print("marcos da terra nova: %d (igrejinha %s, cume %s, Árvore Branca %s, comboio %s), %d ms" % [montados, igreja, cume, arvore, comboio, Time.get_ticks_msec() - t0])


## Os nomes no mapa e as páginas do álbum (o `Vale` chama junto com `TerraNova.lugares_com_nome`).
static func lugares_com_nome() -> void:
	if cume.is_finite():
		Marcos.lugares.append([NOME_CUME, Vector2(cume.x, cume.z), 45.0])
	if arvore.is_finite():
		Marcos.lugares.append([NOME_ARVORE, ARVORE, 50.0])
	if comboio.is_finite():
		Marcos.lugares.append([NOME_COMBOIO, COMBOIO, 60.0])


# ---------------------------------------------------------------- peças

## Uma obra com blocos lisos (máquina e parede rebocada não têm a lasca das pedras das ruínas).
static func _obra(v: Vale, xf: Transform3D, nome: String) -> Ruinas.Obra:
	var o := Ruinas.Obra.new()
	o.v = v
	o.t = xf
	o.na_clareira = true  # a altura do chão vem do Vale, que pergunta à terra nova
	o.rng.seed = hash(nome)  # as telhas caídas e o resto do sorteio, sempre iguais
	o.blocos.append(BoxMesh.new().get_faces())
	o.corpo = StaticBody3D.new()
	o.corpo.name = nome
	o.corpo.collision_layer = 1
	o.corpo.collision_mask = 0
	v.add_child(o.corpo)
	return o


## Uma barra de `de` até `ate` (treliça, cabo, antena), na medida da obra.
static func _barra(o: Ruinas.Obra, de: Vector3, ate: Vector3, grossura: float, mat: String, colide := false) -> void:
	var d := ate - de
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	o.bloco((de + ate) * 0.5, Vector3(grossura, d.length(), grossura), Basis(x, y, x.cross(y)), mat, colide)


static func _cilindro(o: Ruinas.Obra, c: Vector3, r_cima: float, r_baixo: float, alto: float, mat: String, giro := Basis.IDENTITY, lados := 14) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_cima
	m.bottom_radius = r_baixo
	m.height = alto
	m.radial_segments = lados
	m.rings = 1
	var mi := o._solto(m, c, mat)
	mi.transform = o.t * Transform3D(giro, c)
	return mi


## Colisão pelo contorno de uma lista de pontos (telhado, pirâmide, torre de treliça).
static func _casca(o: Ruinas.Obra, pontos: PackedVector3Array) -> void:
	var f := ConvexPolygonShape3D.new()
	f.points = pontos
	o.forma(f, Transform3D.IDENTITY)


# ---------------------------------------------------------------- a igrejinha do Vilarejo

## A igrejinha: nave de 7 x 13 m com telhado de duas águas e a torre do sino na frente, virada para a praça.
## A porta é a da torre. A encosta ali desce para fora do platô: um embasamento de pedra faz o piso reto.
static func _igreja(v: Vale) -> void:
	if not Vilarejo.montado:
		return
	var vc := Vilarejo.CENTRO
	var rumo := atan2(IGREJA.x - vc.x, IGREJA.y - vc.y)  # +z da obra aponta para fora da vila: a frente (−z) olha a praça
	var giro := Basis(Vector3.UP, rumo)
	# o chão debaixo da planta (a nave e a torre)
	var baixo := INF
	var alto := -INF
	for lz in range(-11, 8, 2):
		for lx: float in [-3.8, 0.0, 3.8]:
			var w := Vector3(IGREJA.x, 0, IGREJA.y) + giro * Vector3(lx, 0, lz)
			var hh := v.altura(w.x, w.z)
			baixo = minf(baixo, hh)
			alto = maxf(alto, hh)
	var piso := lerpf(baixo, alto, 0.7)
	var o := _obra(v, Transform3D(giro, Vector3(IGREJA.x, piso, IGREJA.y)), "Igrejinha")
	# o embasamento, metido no chão
	var fundo := baixo - piso - 0.8
	o.bloco(Vector3(0, (fundo + 0.15) * 0.5, -2.1), Vector3(8.0, 0.15 - fundo, 18.0), Basis.IDENTITY, "ruina")
	# a nave e a empena (da largura do telhado: o beiral fica forrado por baixo)
	o.bloco(Vector3(0, 3.0, 0), Vector3(7.0, 6.0, 13.0), Basis.IDENTITY, "cal")
	var empena := PrismMesh.new()
	empena.size = Vector3(8.0, 3.0, 13.0)
	o._solto(empena, Vector3(0, 7.5, 0), "cal")
	# o telhado de duas águas, com beiral
	var caida := atan2(3.0, 4.0)
	for lado: float in [-1.0, 1.0]:
		var meio := Vector3(lado * 2.0, 7.5, 0) + Basis(Vector3.BACK, -lado * caida) * Vector3(0, 0.14, 0)
		o.bloco(meio, Vector3(5.2, 0.26, 13.8), Basis(Vector3.BACK, -lado * caida), "telha")
	_casca(o, PackedVector3Array([Vector3(-4.0, 6.0, -6.9), Vector3(4.0, 6.0, -6.9), Vector3(0, 9.3, -6.9),
			Vector3(-4.0, 6.0, 6.9), Vector3(4.0, 6.0, 6.9), Vector3(0, 9.3, 6.9)]))
	# as janelas estreitas dos lados e o vão do fundo
	for lado: float in [-1.0, 1.0]:
		for z: float in [-3.0, 0.6, 4.2]:
			o.bloco(Vector3(lado * 3.52, 3.3, z), Vector3(0.1, 2.1, 0.9), Basis.IDENTITY, "junta", false)
	o.bloco(Vector3(0, 7.2, 6.52), Vector3(0.9, 1.1, 0.1), Basis.IDENTITY, "junta", false)
	# a torre do sino: a porta embaixo, a janelinha, duas cintas, o vão do sino, a ponta e a cruz
	var tz := -8.6
	o.bloco(Vector3(0, 10.0, tz), Vector3(4.2, 20.0, 4.2), Basis.IDENTITY, "cal")
	o.bloco(Vector3(0, 1.6, tz - 2.12), Vector3(1.8, 3.2, 0.1), Basis.IDENTITY, "junta", false)
	o.bloco(Vector3(0, 9.0, tz - 2.12), Vector3(0.7, 1.4, 0.1), Basis.IDENTITY, "junta", false)
	for y: float in [15.6, 20.1]:
		o.bloco(Vector3(0, y, tz), Vector3(4.6, 0.36, 4.6), Basis.IDENTITY, "cal", false)
	o.bloco(Vector3(0, 17.7, tz), Vector3(2.0, 2.6, 4.3), Basis.IDENTITY, "junta", false)
	o.bloco(Vector3(0, 17.7, tz), Vector3(4.3, 2.6, 2.0), Basis.IDENTITY, "junta", false)
	_cilindro(o, Vector3(0, 23.5, tz), 0.0, 3.3, 6.4, "telha", Basis(Vector3.UP, PI * 0.25), 4)
	_casca(o, PackedVector3Array([Vector3(-2.33, 20.3, tz - 2.33), Vector3(2.33, 20.3, tz - 2.33), Vector3(2.33, 20.3, tz + 2.33),
			Vector3(-2.33, 20.3, tz + 2.33), Vector3(0, 26.7, tz)]))
	o.bloco(Vector3(0, 27.9, tz), Vector3(0.16, 2.6, 0.16), Basis.IDENTITY, "ferrugem", false)
	o.bloco(Vector3(0, 28.5, tz), Vector3(1.5, 0.14, 0.14), Basis.IDENTITY, "ferrugem", false)
	# umas telhas que caíram, no chão da frente
	for k in 5:
		var lx := -2.6 + k * 1.3 + o.j(0.4)
		var lz := 7.8 + o.j(1.2)
		o.bloco(Vector3(lx, o.chao(lx, lz) + 0.08, lz), Vector3(0.9, 0.12, 0.5), Basis(Vector3.UP, o.j(1.2)), "telha", false)
	o.fechar()
	igreja = o.t * Vector3(0, 0, tz)
	montados += 1


# ---------------------------------------------------------------- o mastro do cume

## O mastro da estação do tempo no pico: treliça de três pernas, 26 m, em faixas vermelhas e brancas, com
## a antena de prato e a luz vermelha piscando lá em cima (`LuzesNoite`). A sapata de concreto entra na rocha.
static func _cume(v: Vale) -> void:
	var pico := Vector3(0, -INF, 0)
	var x := CUME_BUSCA.position.x
	while x < CUME_BUSCA.end.x:
		var z := CUME_BUSCA.position.y
		while z < CUME_BUSCA.end.y:
			var hh := v.altura(x, z)
			if hh > pico.y:
				pico = Vector3(x, hh, z)
			z += 4.0
		x += 4.0
	if pico.y < 400.0:
		return
	var o := _obra(v, Transform3D(Basis.IDENTITY, pico - Vector3(0, 0.2, 0)), "MastroDoCume")
	o.bloco(Vector3(0, -3.4, 0), Vector3(3.8, 7.6, 3.8), Basis.IDENTITY, "concreto")
	var alto := 26.0
	var pes: Array[Vector3] = []
	for k in 3:
		pes.append(Vector3(cos(k * TAU / 3.0 + 0.3), 0, sin(k * TAU / 3.0 + 0.3)))
	var andares := 10
	for i in andares:
		var y0 := alto * i / andares
		var y1 := alto * (i + 1) / andares
		var r0 := lerpf(2.2, 0.5, float(i) / andares)
		var r1 := lerpf(2.2, 0.5, float(i + 1) / andares)
		var mat := "aco_vermelho" if i % 2 == 0 else "aco_branco"
		for k in 3:
			var a0 := pes[k] * r0 + Vector3(0, y0, 0)
			var a1 := pes[k] * r1 + Vector3(0, y1, 0)
			var b1 := pes[(k + 1) % 3] * r1 + Vector3(0, y1, 0)
			_barra(o, a0, a1, 0.24, mat)
			_barra(o, a0, b1, 0.1, mat)
			_barra(o, a1, b1, 0.1, mat)
	var contorno := PackedVector3Array()
	for k in 3:
		contorno.append(pes[k] * 2.3)
		contorno.append(pes[k] * 0.6 + Vector3(0, alto, 0))
	_casca(o, contorno)
	# o prato da antena, a caixa dos instrumentos e o para-raios
	_cilindro(o, Vector3(0.9, 19.5, 0), 0.85, 0.85, 0.16, "aco_branco", Basis(Vector3.BACK, PI * 0.5), 16)
	o.bloco(Vector3(0, 3.0, 1.2), Vector3(0.9, 1.1, 0.55), Basis.IDENTITY, "aco_branco", false)
	_barra(o, Vector3(0, alto, 0), Vector3(0, alto + 2.4, 0), 0.08, "junta")
	o.fechar()
	cume = o.t.origin
	cume_topo = o.t * Vector3(0, alto + 1.0, 0)
	LuzesNoite.por(v, cume_topo, LuzesNoite.VERMELHO, 9.0, 2.4, 0.2)
	montados += 1


# ---------------------------------------------------------------- a Árvore Branca

## Uma bétula de 70 m, de casca branca e copa prateada (`q_betula_a_prata`), numa clareira do sopé oeste. Entra
## na lista de árvores do mapa (colisão do tronco e da copa, como as outras e a Árvore-Mãe).
static func _arvore(v: Vale) -> void:
	var nome := "q_betula_a_prata"
	if not v._malhas.has(nome):
		return
	var cx := AABB()
	var tem := false
	for par: Array in v._malhas[nome]:
		var b := (par[1] as Transform3D) * (par[0] as Mesh).get_aabb()
		cx = b if not tem else cx.merge(b)
		tem = true
	var s := ARVORE_ALTA / cx.size.y
	var p := Vector3(ARVORE.x, v.altura(ARVORE.x, ARVORE.y) - 1.0, ARVORE.y)
	var xf := Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3.ONE * s), p)
	v._multi(nome, [xf], p, 0.0, 0.0, true)  # sem troca por distância: de longe é ela mesma
	var i := v.arv_pos.size()
	v.arv_pos.append(p)
	v.arv_escala.append(s * 0.8)
	v.arv_tipo.append(1)
	v.arv_nome.append(nome)
	var cel := Vector2i(floori(p.x / Clareira.CELULA_ARVORE), floori(p.z / Clareira.CELULA_ARVORE))
	var l: PackedInt32Array = v._grade_arv.get(cel, PackedInt32Array())
	l.append(i)
	v._grade_arv[cel] = l
	# pedras em roda, meio enterradas, e samambaias nas raízes
	for k in 7:
		var a := k * TAU / 7.0 + 0.5
		var q := ARVORE + Vector2(cos(a), sin(a)) * (13.0 + 3.0 * (k % 2))
		var pedra: String = ["q_pedra_a", "q_pedra_b", "q_pedra_c"][k % 3]
		if v._malhas.has(pedra):
			v._por(pedra, Transform3D(Basis(Vector3.UP, a * 2.0).scaled(Vector3.ONE * (2.2 + 0.7 * (k % 3))), Vector3(q.x, v.altura(q.x, q.y) - 0.3, q.y)), true)
	for k in 12:
		var a2 := k * TAU / 12.0 + 0.2
		var q2 := ARVORE + Vector2(cos(a2), sin(a2)) * (7.0 + 2.0 * (k % 3))
		var planta: String = ["q_samambaia", "q_moita_flor", "q_planta_c"][k % 3]
		if v._malhas.has(planta):
			v._por(planta, Transform3D(Basis(Vector3.UP, a2).scaled(Vector3.ONE * 1.8), Vector3(q2.x, v.altura(q2.x, q2.y) - 0.05, q2.y)))
	arvore = p
	montados += 1


# ---------------------------------------------------------------- o Comboio da Neve

## O trem de expedição: três carros da base móvel da KayKit (CC0), cada um sobre um chassi de seis rodas, na
## pintura laranja-polar (a parte branca da textura do pacote virou laranja, para ler na neve). A frente das peças
## da KayKit é o +z (o para-brisa da cabine e as rodas "front"). Cada carro assenta no chão dele, com as rodas
## afundadas na neve; a neve no teto é do shader (`neve` no `vale_tex_opaco`), só nas faces de cima.
static func _comboio(v: Vale, onde := COMBOIO, rumo := COMBOIO_RUMO) -> void:
	var e := COMBOIO_ESCALA
	var frente := Vector3(sin(rumo), 0.0, cos(rumo))
	var lado := Vector3(frente.z, 0.0, -frente.x)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_tex_opaco.gdshader")
	mat.set_shader_parameter("tex", load(COMBOIO_PASTA + "spacebits_laranja.png"))
	mat.set_shader_parameter("ruido", v._tex)
	mat.set_shader_parameter("vento", 0.0)
	mat.set_shader_parameter("corte", 0.0)
	mat.set_shader_parameter("neve", 1.0)
	var corpo := StaticBody3D.new()
	corpo.name = "ComboioDaNeve"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	v.add_child(corpo)
	var meio_trem := Vector3(onde.x, 0.0, onde.y)
	for c: Array in COMBOIO_CARROS:
		var f := frente.rotated(Vector3.UP, float(c[3]))
		var l := Vector3(f.z, 0.0, -f.x)
		var p: Vector3 = meio_trem + frente * float(c[1]) + lado * float(c[2])
		# o chão sob o carro: um plano pelos nove pontos de uma grade de 13 m (a = ao longo, b = de lado)
		var soma := 0.0
		var sa := 0.0
		var sb := 0.0
		var hs: Array[Vector3] = []
		for a: float in [-6.5, 0.0, 6.5]:
			for b: float in [-6.5, 0.0, 6.5]:
				var hh := v.altura(p.x + f.x * a + l.x * b, p.z + f.z * a + l.z * b)
				hs.append(Vector3(a, b, hh))
				soma += hh
				sa += a * hh
				sb += b * hh
		var h0 := soma / 9.0
		var ia := sa / (6.0 * 6.5 * 6.5)  # subida por metro ao longo
		var ib := sb / (6.0 * 6.5 * 6.5)  # e de lado
		# afunda até não sobrar vão embaixo (o fundo fica 0,3 m abaixo do chão em todos os pontos); ao menos as rodas
		var vao := 0.0
		for q in hs:
			vao = maxf(vao, h0 + ia * q.x + ib * q.y - q.z)
		var n := (l + Vector3.UP * ib).cross(f + Vector3.UP * ia).normalized()
		if n.y < 0.0:
			n = -n
		var z := (f - n * f.dot(n)).normalized()
		var giro := Basis(n.cross(z), n, z)
		p.y = h0 - clampf(vao + 0.3, 0.14 * e, 0.36 * e)
		var car := Node3D.new()
		car.name = "Carro_" + String(c[0])
		car.transform = Transform3D(giro.scaled(Vector3.ONE * e), p)
		v.add_child(car)
		var chassi: Node3D = (load(COMBOIO_PASTA + "mobile_base_frame.gltf") as PackedScene).instantiate()
		car.add_child(chassi)
		var modulo: Node3D = (load(COMBOIO_PASTA + String(c[0]) + ".gltf") as PackedScene).instantiate()
		modulo.position = Vector3(0.0, 0.42, 0.0)
		car.add_child(modulo)
		for mi: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = mat
		# a colisão: uma caixa do chassi ao teto (2,14 x 1,72 x 2,1 na medida da peça)
		var cx := BoxShape3D.new()
		cx.size = Vector3(2.14, 1.72, 2.1) * e
		var cs := CollisionShape3D.new()
		cs.shape = cx
		cs.transform = Transform3D(giro, p + n * (0.86 * e))
		corpo.add_child(cs)
		Obstaculos.registrar_forma(cx, cs.transform, v.altura(p.x, p.z))
	comboio = Vector3(onde.x, v.altura(onde.x, onde.y), onde.y)
	montados += 1
