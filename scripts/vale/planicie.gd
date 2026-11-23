class_name Planicie
extends RefCounted
## A planície do ferro-velho (área B, oeste), em 2026-11-22 (doc §140). Pedido do usuário: em volta do
## acampamento da Planície a paisagem estava "pelada", só capim. Das ideias, as quatro primeiras:
## - pedras: afloramentos (uma pedra grande e as menores em volta, seixos no pé) e lajes soltas;
## - árvores: capões (grupos pequenos de árvores com moitas na beira) e umas árvores sozinhas no campo;
## - restos de gente, sem estrada (a ilha não tem caminhos batidos): uma linha de torres de energia que
##   atravessa a planície (de pé, uma torta, uma caída, um toco, com os cabos pendurados ou no chão), a lança de
##   um guindaste deitada no capim em cima do contrapeso, um trator velho afundado perto de um capão e um
##   contêiner meio enterrado e tombado, com a porta aberta. Tudo velho: ferrugem, tinta desbotada e musgo.
## - o chão: manchas de palha no capim (`palha`, no shader do capim e do chão), manchas de flores do campo
##   (`CapimVivo.floridos`) e terra nua (`CapimVivo.batidos` e uma pele de terra por cima).
## Nada fica a menos de `LIVRE` m do acampamento (o pátio e a volta das máquinas) nem perto da água.
## Montado pela TerraNova (`montar`); as árvores entram na mata dela (`arvores`, chamado em `plantar`).

const CENTRO := Vector2(-2950, -650)
const LIVRE := 75.0
const PALHA_RAIO := 540.0

## As torres de energia, de sul para norte: [x, z, estado]. Estados: "pe", "torta", "caida", "toco".
const TORRES := [
	[-3135.0, -260.0, "pe"], [-3128.0, -390.0, "torta"], [-3121.0, -520.0, "caida"],
	[-3114.0, -650.0, "pe"], [-3107.0, -780.0, "toco"], [-3100.0, -910.0, "pe"],
]
const TORRE_ALTA := 16.0
const LANCA := [Vector2(-2850, -770), Vector2(-2834.4, -790.8)]  # a base (no contrapeso) e a ponta
const TRATOR := [Vector2(-2818, -452), 2.2]
const CONTEINER := [Vector2(-3035, -805), 0.4]
## Os capões: [x, z, raio, árvores]; e as árvores sozinhas: [x, z].
const CAPOES := [
	[-3230.0, -600.0, 16.0, 9], [-2800.0, -905.0, 14.0, 8], [-2775.0, -420.0, 15.0, 10],
	[-3060.0, -300.0, 13.0, 7], [-3290.0, -430.0, 12.0, 6],
]
const SOZINHAS := [Vector2(-2880, -705), Vector2(-3010, -520), Vector2(-2735, -620), Vector2(-3245, -880)]
## Os afloramentos: [x, z, tamanho].
const PEDRAS := [
	[-2860.0, -600.0, 1.0], [-3045.0, -700.0, 0.8], [-2990.0, -840.0, 1.2], [-3205.0, -770.0, 1.0],
	[-2760.0, -780.0, 0.9], [-2930.0, -375.0, 1.1], [-3215.0, -335.0, 0.8], [-2745.0, -300.0, 1.0],
	[-3330.0, -650.0, 0.9],
]
## Flores do campo (x, z, raio) além das que nascem em volta dos capões e das árvores sozinhas.
const CAMPOS_FLOR := [Vector3(-2900, -835, 30), Vector3(-3175, -485, 28), Vector3(-2840, -345, 25), Vector3(-3030, -930, 24)]
## Terra nua solta no campo (x, z, raio); a do pé do trator, do contêiner e das torres vem junto deles.
const TERRA_NUA := [Vector3(-2990, -565, 7), Vector3(-3150, -565, 9), Vector3(-2780, -560, 6)]

static var _cil: CylinderMesh


# ---------------------------------------------------------------- árvores (para a mata da TerraNova)

## As árvores dos capões e as sozinhas: [nome, Transform3D], como a fila da `TerraNova.plantar`.
static func arvores(tn: TerraNova) -> Array:
	var fila: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4041
	for c: Array in CAPOES:
		var centro := Vector2(c[0], c[1])
		var r: float = c[2]
		var postas: Array[Vector2] = []
		var tentativas := 0
		while postas.size() < int(c[3]) and tentativas < 200:
			tentativas += 1
			# mais juntas no meio, ralas na beira
			var q := centro + Vector2.from_angle(rng.randf() * TAU) * r * sqrt(rng.randf()) * 0.9
			var perto := false
			for o: Vector2 in postas:
				if o.distance_to(q) < 4.2:
					perto = true
			if perto or not _cabe(tn, q, 8.0):
				continue
			postas.append(q)
			var u := rng.randf()
			var nome: String
			if u < 0.5:
				nome = ["q_comum_a", "q_comum_b", "q_comum_c", "q_comum_d", "q_comum_e"][rng.randi() % 5]
			elif u < 0.72:
				nome = ["q_torta_a", "q_torta_b", "q_torta_c", "q_torta_d", "q_torta_e"][rng.randi() % 5]
			elif u < 0.9:
				nome = ["q_pinheiro_n_a", "q_pinheiro_n_b", "q_pinheiro_n_c"][rng.randi() % 3]
			else:
				nome = ["q_betula_a", "q_betula_b", "q_betula_a_amarela"][rng.randi() % 3]
			# as do meio, mais altas
			var meio := 1.0 - q.distance_to(centro) / r
			var s := lerpf(0.95, 1.55, meio) * rng.randf_range(0.9, 1.1)
			fila.append([nome, _xf(tn, q, s, rng.randf() * TAU)])
	for q: Vector2 in SOZINHAS:
		if not _cabe(tn, q, 8.0):
			continue
		var nome: String = ["q_comum_c", "q_torta_b", "q_comum_a", "q_torta_d"][fila.size() % 4]
		fila.append([nome, _xf(tn, q, rng.randf_range(1.8, 2.2), rng.randf() * TAU)])
	return fila


static func _xf(tn: TerraNova, q: Vector2, s: float, giro: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * s), Vector3(q.x, tn.altura(q.x, q.y) - 0.15, q.y))


## O ponto serve para pôr coisa: chão seco, sem ladeira forte, longe da água e do acampamento.
static func _cabe(tn: TerraNova, q: Vector2, folga_agua: float) -> bool:
	if q.distance_to(CENTRO) < LIVRE:
		return false
	return tn.altura(q.x, q.y) > 3.0 and tn.normal_em(q.x, q.y).y > 0.86 and not tn.perto_dagua(q.x, q.y, folga_agua)


# ---------------------------------------------------------------- montagem

static func montar(tn: TerraNova, v: Vale) -> void:
	var raiz := Node3D.new()
	raiz.name = "Planicie"
	v.add_child(raiz)
	var cy := v.altura(CENTRO.x, CENTRO.y)
	raiz.global_position = Vector3(CENTRO.x, cy, CENTRO.y)
	var m := Acampamentos.Montagem.new()
	m.mapa = v
	m.no = raiz
	m.c = raiz.global_position
	m.id = "planicie_campo"
	m.rng.seed = 7707
	m.corpo = StaticBody3D.new()
	raiz.add_child(m.corpo)
	var nua: Array[Vector3] = []
	for k in TORRES.size():
		_torre(m, k, nua)
	_cabos(m)
	_lanca(m, nua)
	_trator(m, nua)
	_conteiner(m, nua)
	m.fechar()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var pedras := _pedras(tn, v, rng)
	var moitas := _moitas(tn, v, rng)
	# o chão: terra nua, flores e palha
	for t: Vector3 in TERRA_NUA:
		nua.append(t)
	for t: Vector3 in nua:
		CapimVivo.batidos.append(t)
		_terra_nua(v, raiz, t)
	for c: Array in CAPOES:
		CapimVivo.floridos.append(Vector3(c[0], c[1], float(c[2]) + 10.0))
	for q: Vector2 in SOZINHAS:
		CapimVivo.floridos.append(Vector3(q.x, q.y, 9.0))
	for f: Vector3 in CAMPOS_FLOR:
		CapimVivo.floridos.append(f)
	RenderingServer.global_shader_parameter_set("palha", Vector4(CENTRO.x, CENTRO.y, PALHA_RAIO, 1.0))
	print("planície: %d torres, %d pedras, %d moitas, %d manchas de terra nua, %d de flores" % [TORRES.size(), pedras, moitas, nua.size(),
		CAPOES.size() + SOZINHAS.size() + CAMPOS_FLOR.size()])


## Um ponto do mundo em medida da montagem (x e z a partir do meio, y a partir do chão do meio).
static func _loc(m: Acampamentos.Montagem, q: Vector2) -> Vector2:
	return q - CENTRO


# ---------------------------------------------------------------- torres de energia

## As peças de uma torre em treliça, na medida dela (y para cima a partir do pé): [a, b, grossura, material].
## `corte`: o que passa dessa altura fica de fora (o toco), com as pontas tortas.
static func _pecas_torre(corte: float, rng: RandomNumberGenerator) -> Array:
	var segs: Array = []
	var niveis := [0.0, 1.8, 3.6, 5.4, 7.2, 9.0, 10.6, 12.0, 13.2, 14.4, TORRE_ALTA]
	var meia := func(y: float) -> float:
		return lerpf(2.2, 0.5, pow(y / TORRE_ALTA, 0.8))
	var canto := func(y: float, sx: float, sz: float) -> Vector3:
		var w: float = meia.call(y)
		return Vector3(sx * w, y, sz * w)
	var cantos := [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]
	for i in niveis.size() - 1:
		var y0: float = niveis[i]
		var y1: float = niveis[i + 1]
		for k in 4:
			var c0: Array = cantos[k]
			var c1: Array = cantos[(k + 1) % 4]
			segs.append([canto.call(y0, c0[0], c0[1]), canto.call(y1, c0[0], c0[1]), 0.14, "velho_ferro"])  # a perna
			segs.append([canto.call(y1, c0[0], c0[1]), canto.call(y1, c1[0], c1[1]), 0.07, "velho_ferro"])  # o anel
			# o X de cada face
			segs.append([canto.call(y0, c0[0], c0[1]), canto.call(y1, c1[0], c1[1]), 0.055, "velho_ferro"])
			segs.append([canto.call(y0, c1[0], c1[1]), canto.call(y1, c0[0], c0[1]), 0.055, "velho_ferro"])
	# os braços, a 13,2 m: treliça de 8,4 m de ponta a ponta, com os isoladores pendurados nas pontas
	var yb := 13.2
	for lado: float in [-1.0, 1.0]:
		var raiz_w: float = meia.call(yb)
		var ponta := Vector3(lado * 4.2, yb, 0.0)
		for sz: float in [-1.0, 1.0]:
			segs.append([Vector3(lado * raiz_w, yb, sz * raiz_w), ponta + Vector3(0, 0, sz * 0.15), 0.08, "velho_ferro"])
			segs.append([Vector3(lado * raiz_w, yb + 1.2, sz * raiz_w * 0.8), ponta + Vector3(0, 0.25, 0), 0.07, "velho_ferro"])
		for f: float in [0.33, 0.66]:
			var x: float = lerpf(raiz_w, 4.2, f) * lado
			segs.append([Vector3(x, yb, -0.35), Vector3(x, yb + lerpf(1.2, 0.25, f), 0.0), 0.05, "velho_ferro"])
			segs.append([Vector3(x, yb, 0.35), Vector3(x, yb + lerpf(1.2, 0.25, f), 0.0), 0.05, "velho_ferro"])
		segs.append([ponta, ponta - Vector3(0, 1.1, 0), 0.09, "isolador"])
	# o pico do cabo de terra
	segs.append([Vector3(-0.5, TORRE_ALTA, -0.5), Vector3(0, TORRE_ALTA + 0.9, 0), 0.06, "velho_ferro"])
	segs.append([Vector3(0.5, TORRE_ALTA, 0.5), Vector3(0, TORRE_ALTA + 0.9, 0), 0.06, "velho_ferro"])
	if corte >= TORRE_ALTA:
		return segs
	var fora: Array = []
	for s: Array in segs:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		if minf(a.y, b.y) > corte:
			continue
		if maxf(a.y, b.y) > corte:
			# corta na altura do toco, cada ponta num lugar (ferro torcido)
			var lim := corte + rng.randf_range(-0.6, 0.9)
			var t := clampf((lim - a.y) / (b.y - a.y), 0.0, 1.0) if absf(b.y - a.y) > 0.01 else 1.0
			var fim := a.lerp(b, t) + Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
			fora.append([a, fim, s[2], s[3]])
		else:
			fora.append(s)
	return fora


## A base de cada torre (posição do pé e giro) e onde ficam as pontas dos braços (para os cabos).
static func _base_torre(m: Acampamentos.Montagem, k: int) -> Transform3D:
	var t: Array = TORRES[k]
	var q := _loc(m, Vector2(t[0], t[1]))
	var y := m.chao_min(q.x, q.y, 2.2) - 0.1
	var b := Basis.IDENTITY
	match String(t[2]):
		"torta":
			b = Basis(Vector3(0, 0, 1), 0.13)  # tomba 7,5 graus para o oeste
		"caida":
			# caiu para o oeste, deitada de lado (o pé com 2 m de altura, a ponta a meio metro do chão), com os
			# braços na horizontal
			var giro := Basis(Vector3.UP, -PI * 0.5)
			var ponta := q + Vector2(-1, 0) * TORRE_ALTA
			y = m.chao(q.x - 2.0, q.y) + 2.0
			var queda := (m.chao(ponta.x, ponta.y) + 0.6) - y
			var ang := acos(clampf(queda / TORRE_ALTA, -0.3, 0.3))
			b = giro * Basis(Vector3.RIGHT, ang)
			return Transform3D(b, Vector3(q.x - 2.0, y, q.y))
	return Transform3D(b, Vector3(q.x, y, q.y))


static func _torre(m: Acampamentos.Montagem, k: int, nua: Array[Vector3]) -> void:
	var t: Array = TORRES[k]
	var estado := String(t[2])
	var base := _base_torre(m, k)
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + k
	var corte := 4.2 if estado == "toco" else INF
	for s: Array in _pecas_torre(corte, rng):
		m.viga(base * (s[0] as Vector3), base * (s[1] as Vector3), s[2], s[3])
	# as sapatas de concreto nos quatro pés (ficam no lugar, mesmo com a torre caída)
	var pe0 := _loc(m, Vector2(t[0], t[1]))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(pe0.x + sx * 2.2, 0, pe0.y + sz * 2.2)
			var py := m.chao(p.x, p.z)
			m.caixa(Vector3(p.x, py + 0.12, p.z), Vector3(0.9, 0.7, 0.9), Basis(Vector3.UP, 0.05 * k), "velho_concreto", false)
	# colisão: as quatro pernas (de pé ou torta), o corpo deitado (caída), o toco baixo
	if estado == "caida":
		var cx := BoxShape3D.new()
		cx.size = Vector3(3.2, TORRE_ALTA, 2.6)
		m.forma(cx, Transform3D(base.basis, base * Vector3(0, TORRE_ALTA * 0.5, 0)))
		nua.append(Vector3(t[0] - 6.0, t[1], 7.0))
	else:
		var alto := 4.2 if estado == "toco" else TORRE_ALTA
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var a := base * Vector3(sx * 2.2, 0, sz * 2.2)
				var w := lerpf(2.2, 0.5, pow(alto / TORRE_ALTA, 0.8))
				var b := base * Vector3(sx * w, alto, sz * w)
				var cx := BoxShape3D.new()
				cx.size = Vector3(0.45, a.distance_to(b), 0.45)
				m.forma(cx, Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5))
		if estado == "toco":
			nua.append(Vector3(t[0], t[1], 5.0))
			# a parte de cima, quebrada, caída do lado
			var resto := Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, 1.48), base.origin + Vector3(-1.5, -4.0, 6.0))
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 900
			for s: Array in _pecas_torre(INF, rng2):
				var a: Vector3 = s[0]
				var b: Vector3 = s[1]
				if a.y < 4.6 or b.y < 4.6:
					continue
				m.viga(resto * a, resto * b, s[2], s[3])
			var cx := BoxShape3D.new()
			cx.size = Vector3(3.0, TORRE_ALTA - 4.6, 2.2)
			m.forma(cx, Transform3D(resto.basis, resto * Vector3(0, (TORRE_ALTA + 4.6) * 0.5, 0)))


## As pontas dos isoladores (onde o cabo pendura) de uma torre de pé, lado -1 ou 1.
static func _ponta_braco(m: Acampamentos.Montagem, k: int, lado: float) -> Vector3:
	return _base_torre(m, k) * Vector3(lado * 4.2, 13.2 - 1.1, 0.0)


## Os cabos: pendurados entre as torres de pé; das que ficam ao lado de uma caída ou do toco, o cabo desce até
## o chão e segue jogado no capim.
static func _cabos(m: Acampamentos.Montagem) -> void:
	for k in TORRES.size() - 1:
		var e0 := String(TORRES[k][2])
		var e1 := String(TORRES[k + 1][2])
		var de_pe0 := e0 == "pe" or e0 == "torta"
		var de_pe1 := e1 == "pe" or e1 == "torta"
		for lado: float in [-1.0, 1.0]:
			if de_pe0 and de_pe1:
				m.cabo_pendurado(_ponta_braco(m, k, lado), _ponta_braco(m, k + 1, lado), 3.2, 0.03)
			elif de_pe0 or de_pe1:
				var kk := k if de_pe0 else k + 1
				var outro := k + 1 if de_pe0 else k
				var a := _ponta_braco(m, kk, lado)
				var alvo := _base_torre(m, outro).origin
				var meio2 := Vector2(a.x, a.z).lerp(Vector2(alvo.x, alvo.z), 0.45) + Vector2(lado * 1.5, 0)
				var no_chao := Vector3(meio2.x, m.chao(meio2.x, meio2.y) + 0.05, meio2.y)
				m.cabo_pendurado(a, no_chao, 1.5, 0.03)
				m.cabo_chao(meio2, Vector2(alvo.x + lado * 2.5, alvo.z) + Vector2(m.rng.randf_range(-3, 3), 0), 0.03)


# ---------------------------------------------------------------- a lança do guindaste

## A lança de um guindaste caída no capim: treliça amarela desbotada, a base em cima do bloco de contrapeso e a
## ponta no chão, com a roldana e o moitão jogado do lado.
static func _lanca(m: Acampamentos.Montagem, nua: Array[Vector3]) -> void:
	var a2 := _loc(m, LANCA[0])
	var b2 := _loc(m, LANCA[1])
	var bloco := Vector3(a2.x, m.chao_min(a2.x, a2.y, 1.4), a2.y)
	m.caixa(bloco + Vector3(0, 0.45, 0), Vector3(2.4, 1.5, 2.2), Basis(Vector3.UP, 0.5), "velho_concreto")
	var a := bloco + Vector3(0, 1.35, 0)
	var b := Vector3(b2.x, m.chao(b2.x, b2.y) + 0.35, b2.y)
	var u := (b - a).normalized()
	var lado := u.cross(Vector3.UP).normalized()
	var cima := lado.cross(u).normalized()
	var comp := a.distance_to(b)
	var passos := int(comp / 1.6)
	var ponto := func(f: float, sl: float, sc: float) -> Vector3:
		var w := lerpf(0.7, 0.32, f)
		return a + u * comp * f + lado * sl * w + cima * sc * w
	var cantos := [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]
	for i in passos:
		var f0 := float(i) / passos
		var f1 := float(i + 1) / passos
		for k in 4:
			var c0: Array = cantos[k]
			var c1: Array = cantos[(k + 1) % 4]
			m.viga(ponto.call(f0, c0[0], c0[1]), ponto.call(f1, c0[0], c0[1]), 0.13, "velho_amarelo")
			m.viga(ponto.call(f1, c0[0], c0[1]), ponto.call(f1, c1[0], c1[1]), 0.06, "velho_amarelo")
			if (i + k) % 2 == 0:
				m.viga(ponto.call(f0, c0[0], c0[1]), ponto.call(f1, c1[0], c1[1]), 0.05, "velho_amarelo")
			else:
				m.viga(ponto.call(f0, c1[0], c1[1]), ponto.call(f1, c0[0], c0[1]), 0.05, "velho_amarelo")
	# o pino da base e as orelhas
	m.cano(a - lado * 0.9, a + lado * 0.9, 0.12, "velho_ferro")
	# a roldana da ponta e o moitão caído do lado, com um pedaço de cabo
	m.cano(b - lado * 0.25, b + lado * 0.25, 0.42, "velho_ferro")
	var moitao := Vector2(b.x, b.z) + Vector2(lado.x, lado.z) * 2.6 + Vector2(u.x, u.z) * 1.2
	var my := m.chao(moitao.x, moitao.y)
	m.caixa(Vector3(moitao.x, my + 0.3, moitao.y), Vector3(0.7, 0.9, 0.5), Basis(Vector3.UP, 0.8) * Basis(Vector3.FORWARD, 1.3), "velho_amarelo")
	m.cabo_chao(Vector2(b.x, b.z), moitao, 0.035)
	m.cabo_chao(moitao, moitao + Vector2(u.x, u.z) * 7.0 + Vector2(lado.x, lado.z) * 2.0, 0.035)
	var cx := BoxShape3D.new()
	cx.size = Vector3(1.3, comp, 1.3)
	m.forma(cx, Transform3D(Basis(Quaternion(Vector3.UP, u)), (a + b) * 0.5))
	nua.append(Vector3(LANCA[0].x, LANCA[0].y, 5.5))


# ---------------------------------------------------------------- o trator

static func _cilindro() -> CylinderMesh:
	if _cil == null:
		_cil = CylinderMesh.new()
		_cil.top_radius = 0.5
		_cil.bottom_radius = 0.5
		_cil.height = 1.0
		_cil.radial_segments = 18
		_cil.rings = 1
	return _cil


## Uma roda: o pneu (cilindro de muitos lados), o aro e o cubo, com o eixo ao longo de `eixo`.
static func _roda(m: Acampamentos.Montagem, centro: Vector3, eixo: Vector3, raio: float, largura: float) -> void:
	var b := Basis(Quaternion(Vector3.UP, eixo.normalized()))
	m._juntar(_cilindro(), Transform3D(b.scaled_local(Vector3(raio * 2.0, largura, raio * 2.0)), centro), "pneu")
	m._juntar(_cilindro(), Transform3D(b.scaled_local(Vector3(raio * 1.25, largura + 0.04, raio * 1.25)), centro), "velho_vermelho")
	m._juntar(_cilindro(), Transform3D(b.scaled_local(Vector3(raio * 0.4, largura + 0.12, raio * 0.4)), centro), "velho_ferro")


## Um trator velho de roda alta, vermelho desbotado e enferrujado, afundado até o cubo nas rodas de trás, sem uma
## roda da frente (ela está deitada do lado), com o capô amassado e a armação de proteção torta.
static func _trator(m: Acampamentos.Montagem, nua: Array[Vector3]) -> void:
	var q := _loc(m, TRATOR[0])
	var giro: float = TRATOR[1]
	var y := m.chao_min(q.x, q.y, 2.0) - 0.28
	var base := Transform3D(Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, 0.06) * Basis(Vector3.FORWARD, -0.05), Vector3(q.x, y, q.y))
	var em := func(x: float, yy: float, z: float) -> Vector3:
		return base * Vector3(x, yy, z)
	var bb := base.basis
	var x_eixo := bb * Vector3.RIGHT
	# rodas de trás (grandes) e a da frente que sobrou
	for lado: float in [-1.0, 1.0]:
		_roda(m, em.call(lado * 0.95, 0.8, -0.9), x_eixo, 0.8, 0.45)
	_roda(m, em.call(0.62, 0.42, 1.45), x_eixo, 0.42, 0.22)
	# a roda que caiu, deitada no chão do lado
	var caida := Vector2(q.x, q.y) + Vector2.from_angle(-giro + 0.4) * 2.6
	var cy := m.chao(caida.x, caida.y)
	_roda(m, Vector3(caida.x, cy + 0.1, caida.y), Vector3(0.1, 1, 0.05), 0.42, 0.22)
	# o eixo da frente, torto para o lado que perdeu a roda
	m.viga(em.call(-0.62, 0.28, 1.45), em.call(0.62, 0.42, 1.45), 0.12, "velho_ferro")
	# o chassi e o motor
	m.caixa(em.call(0.0, 0.75, 0.2), Vector3(0.62, 0.38, 2.6), bb, "velho_ferro", false)
	m.caixa(em.call(0.0, 1.12, 0.75), Vector3(0.78, 0.62, 1.7), bb * Basis(Vector3.FORWARD, 0.04), "velho_vermelho", false)  # o capô
	m.caixa(em.call(0.0, 1.05, 1.62), Vector3(0.82, 0.78, 0.12), bb, "velho_ferro", false)  # a grade do radiador
	m.caixa(em.call(0.0, 1.02, -0.35), Vector3(0.7, 0.55, 0.7), bb, "velho_vermelho", false)  # o câmbio
	# os para-lamas de trás e o banco
	for lado: float in [-1.0, 1.0]:
		m.caixa(em.call(lado * 0.95, 1.55, -0.9), Vector3(0.55, 0.06, 1.2), bb * Basis(Vector3.RIGHT, 0.0), "velho_vermelho", false)
		m.caixa(em.call(lado * 0.95, 1.3, -0.35), Vector3(0.55, 0.5, 0.06), bb * Basis(Vector3.RIGHT, -0.5), "velho_vermelho", false)
		m.caixa(em.call(lado * 0.95, 1.3, -1.45), Vector3(0.55, 0.5, 0.06), bb * Basis(Vector3.RIGHT, 0.5), "velho_vermelho", false)
	m.caixa(em.call(0.0, 1.42, -1.0), Vector3(0.5, 0.1, 0.45), bb, "pneu", false)
	m.caixa(em.call(0.0, 1.7, -1.22), Vector3(0.5, 0.5, 0.08), bb * Basis(Vector3.RIGHT, -0.2), "pneu", false)
	# o volante
	m.cano(em.call(0.0, 1.35, -0.35), em.call(0.0, 1.85, -0.6), 0.03, "velho_ferro")
	m._juntar(_cilindro(), Transform3D((bb * Basis(Vector3.RIGHT, -0.5)).scaled_local(Vector3(0.42, 0.03, 0.42)), em.call(0.0, 1.87, -0.62)), "pneu")
	# o escapamento, de pé no capô, e a armação de proteção (torta para um lado)
	m.cano(em.call(-0.25, 1.4, 1.2), em.call(-0.25, 2.3, 1.2), 0.055, "velho_ferro")
	for lado: float in [-1.0, 1.0]:
		m.viga(em.call(lado * 0.8, 1.55, -1.45), em.call(lado * 0.7 + 0.15, 2.65, -1.4), 0.08, "velho_ferro")
	m.viga(em.call(-0.55, 2.65, -1.4), em.call(0.85, 2.62, -1.4), 0.08, "velho_ferro")
	var cx := BoxShape3D.new()
	cx.size = Vector3(2.4, 1.8, 3.6)
	m.forma(cx, Transform3D(bb, em.call(0.0, 0.9, 0.1)))
	nua.append(Vector3(TRATOR[0].x, TRATOR[0].y, 6.0))


# ---------------------------------------------------------------- o contêiner

## Um contêiner de chapa ondulada, verde-azulado desbotado, meio enterrado e tombado de lado, com uma das portas
## aberta (a outra ficou fechada).
static func _conteiner(m: Acampamentos.Montagem, nua: Array[Vector3]) -> void:
	var q := _loc(m, CONTEINER[0])
	var giro: float = CONTEINER[1]
	var comp := 6.0
	var larg := 2.4
	var alt := 2.6
	var y := m.chao_min(q.x, q.y, 3.0) - 0.75
	var b := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, 0.16) * Basis(Vector3.FORWARD, 0.07)
	var em := func(x: float, yy: float, z: float) -> Vector3:
		return Vector3(q.x, y, q.y) + b * Vector3(x, yy, z)
	var cor := "velho_conteiner"
	for lado: float in [-1.0, 1.0]:
		m.chapa(em.call(0.0, 0.0, lado * larg * 0.5), comp, alt, b, cor)
	m.chapa(em.call(-comp * 0.5, 0.0, 0.0), larg, alt, b * Basis(Vector3.UP, PI * 0.5), cor)
	m.caixa(em.call(0.0, alt + 0.03, 0.0), Vector3(comp + 0.1, 0.08, larg + 0.1), b, cor, false)
	# a porta fechada e a aberta (presa na dobradiça, virada para fora)
	m.chapa(em.call(comp * 0.5, 0.0, -larg * 0.25), larg * 0.5, alt, b * Basis(Vector3.UP, PI * 0.5), cor)
	var dob: Vector3 = em.call(comp * 0.5, 0.0, larg * 0.5)
	var bp := b * Basis(Vector3.UP, -0.35)
	m.chapa(dob + bp * Vector3(larg * 0.25, 0.0, 0.03), larg * 0.5, alt, bp, cor)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.viga(em.call(sx * comp * 0.5, 0.0, sz * larg * 0.5), em.call(sx * comp * 0.5, alt + 0.08, sz * larg * 0.5), 0.16, "velho_ferro")
		for hy: float in [0.05, alt + 0.02]:
			m.viga(em.call(sx * comp * 0.5, hy, -larg * 0.5), em.call(sx * comp * 0.5, hy, larg * 0.5), 0.12, "velho_ferro")
	for hy: float in [0.05, alt + 0.02]:
		for sz: float in [-1.0, 1.0]:
			m.viga(em.call(-comp * 0.5, hy, sz * larg * 0.5), em.call(comp * 0.5, hy, sz * larg * 0.5), 0.12, "velho_ferro")
	var cx := BoxShape3D.new()
	cx.size = Vector3(comp, alt, larg)
	m.forma(cx, Transform3D(b, em.call(0.0, alt * 0.5, 0.0)))
	nua.append(Vector3(CONTEINER[0].x, CONTEINER[0].y, 6.5))


# ---------------------------------------------------------------- pedras e moitas

## Os afloramentos (uma pedra grande, as menores em volta e seixos no pé) e as lajes soltas no campo.
static func _pedras(tn: TerraNova, v: Vale, rng: RandomNumberGenerator) -> int:
	var postas := 0
	var ocupados: Array[Vector2] = _ocupados()
	for p: Array in PEDRAS:
		var c := Vector2(p[0], p[1])
		if not _cabe(tn, c, 10.0):
			continue
		var t: float = p[2]
		var grande: String = ["pedra_alta", "pedra_b"][postas % 2]
		var s := rng.randf_range(2.8, 4.2) * t
		_pedra(v, grande, c, s, rng.randf() * TAU, 0.1 * s, rng)
		postas += 1
		for i in rng.randi_range(3, 6):
			var q := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.5, 6.5) * t
			if not _cabe(tn, q, 8.0):
				continue
			_pedra(v, ["pedra_a", "pedra_b"][i % 2], q, rng.randf_range(0.7, 1.8) * t, rng.randf() * TAU, 0.05, rng)
			postas += 1
		for i in rng.randi_range(5, 9):
			var q := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.5, 9.0) * t
			var nome := "q_seixo_%s" % "abcdefghijk"[rng.randi() % 11]
			v._por(nome, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.6)),
				Vector3(q.x, v.altura(q.x, q.y) - 0.02, q.y)))
		ocupados.append(c)
	# as lajes: pedras largas deitadas, só a costa de fora do chão
	var lajes := 0
	var tentativas := 0
	while lajes < 7 and tentativas < 400:
		tentativas += 1
		var q := CENTRO + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(95.0, 380.0)
		if not _cabe(tn, q, 12.0):
			continue
		var longe := true
		for o: Vector2 in ocupados:
			if o.distance_to(q) < 40.0:
				longe = false
		if not longe:
			continue
		var s := rng.randf_range(2.4, 3.6)
		var giro := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
		var xf := Transform3D(giro.scaled(Vector3.ONE * s), Vector3(q.x, v.altura(q.x, q.y) - s * 0.32, q.y))
		v._por("pedra_b", xf, true)
		ocupados.append(q)
		lajes += 1
		postas += 1
	return postas


static func _pedra(v: Vale, nome: String, q: Vector2, s: float, giro: float, sobe: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
	v._por(nome, Transform3D(b.scaled(Vector3.ONE * s), Vector3(q.x, v.altura(q.x, q.y) + sobe - s * 0.12, q.y)), true)


## As moitas na beira dos capões e no pé das árvores sozinhas (sem colisão: o robô passa por elas).
static func _moitas(tn: TerraNova, v: Vale, rng: RandomNumberGenerator) -> int:
	var postas := 0
	for c: Array in CAPOES:
		var centro := Vector2(c[0], c[1])
		var r: float = c[2]
		for i in int(r * 0.9):
			var q := centro + Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.75, 1.2)
			if not _cabe(tn, q, 6.0):
				continue
			var nome: String = ["q_moita", "q_moita", "q_moita_flor", "q_samambaia"][rng.randi() % 4]
			v._por(nome, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.1, 2.0)),
				Vector3(q.x, v.altura(q.x, q.y) - 0.05, q.y)))
			postas += 1
	for q0: Vector2 in SOZINHAS:
		for i in 3:
			var q := q0 + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.5, 4.5)
			if not _cabe(tn, q, 6.0):
				continue
			v._por("q_moita", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6)),
				Vector3(q.x, v.altura(q.x, q.y) - 0.05, q.y)))
			postas += 1
	return postas


## Os lugares que já têm coisa (restos e capões): as lajes ficam longe deles.
static func _ocupados() -> Array[Vector2]:
	var o: Array[Vector2] = [LANCA[0], LANCA[1], TRATOR[0], CONTEINER[0]]
	for t: Array in TORRES:
		o.append(Vector2(t[0], t[1]))
	for c: Array in CAPOES:
		o.append(Vector2(c[0], c[1]))
	for q: Vector2 in SOZINHAS:
		o.append(q)
	return o


# ---------------------------------------------------------------- terra nua

## Uma pele de terra seca por cima do chão, com a beira comida pelo capim (o mesmo chão batido dos
## acampamentos, sem as manchas de óleo).
static func _terra_nua(v: Vale, pai: Node3D, t: Vector3) -> void:
	var raio := t.z
	var aneis := 10
	var fatias := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(t.x, v.altura(t.x, t.y), t.y)
	var pts: Array[Vector3] = [Vector3(0, 0.08, 0)]
	var ns: Array[Vector3] = [v.normal_em(t.x, t.y)]
	for i in aneis:
		var rr := raio * 1.2 * float(i + 1) / aneis
		for j in fatias:
			var a := j * TAU / fatias
			var wx := t.x + cos(a) * rr
			var wz := t.y + sin(a) * rr
			pts.append(Vector3(wx - t.x, v.altura(wx, wz) - c.y + 0.08, wz - t.y))
			ns.append(v.normal_em(wx, wz))
	for i in pts.size():
		st.set_normal(ns[i])
		st.add_vertex(pts[i])
	for j in fatias:
		st.add_index(0)
		st.add_index(1 + j)
		st.add_index(1 + (j + 1) % fatias)
	for i in aneis - 1:
		for j in fatias:
			var j1 := (j + 1) % fatias
			var a := 1 + i * fatias + j
			var b := 1 + i * fatias + j1
			var cc := 1 + (i + 1) * fatias + j1
			var d := 1 + (i + 1) * fatias + j
			st.add_index(a)
			st.add_index(cc)
			st.add_index(b)
			st.add_index(a)
			st.add_index(d)
			st.add_index(cc)
	var mi := MeshInstance3D.new()
	mi.name = "TerraNua"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = Acampamentos._shader_terra()
	mat.set_shader_parameter("ruido", v._tex)
	mat.set_shader_parameter("centro", c)
	mat.set_shader_parameter("raio", raio)
	mat.set_shader_parameter("oleo", 0.0)
	mi.material_override = mat
	mi.visibility_range_end = 700.0
	pai.add_child(mi)
	mi.global_position = c
