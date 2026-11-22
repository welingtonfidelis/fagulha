class_name BocaDegelo
extends RefCounted
## A Boca do Degelo (doc §137.13): a gruta de gelo da Montanha do Degelo, aberta no paredão logo acima da
## nascente do rio do sul. A boca fica 8 m acima da nascente (só se entra voando); dela sai um corredor de
## uns 60 m que sobe devagar e serpenteia até um salão de gelo, com duas colunas de gelo, pingentes no teto e
## cristais de gelo acesos. É para passear e olhar; o frio lá dentro é o mesmo da montanha (§137.11).
##
## Como o Sumidouro (§40), é uma peça própria de rocha (RochaMalha, "surface nets"), mas na grade da terra nova:
## `cavar` guarda o chão de antes da caixa e rebaixa a grade (alturas de perto e de longe) debaixo do vazio, antes
## de o chão e a colisão da terra nova serem montados; a malha refaz a encosta por cima com a mesma cor do chão
## (terra_nova_cor) e, lá dentro, é gelo (boca_degelo.gdshader). A malha fica gravada em ARQUIVO
## (`-- --assar-rochas` gera de novo depois de mudar o desenho).

const NOME := "A Boca do Degelo"
const ARQUIVO := "res://assets/vale/boca_degelo.res"
const NASCENTE := Vector2(-2915.0, -2380.0)  # o começo do rio do sul (o primeiro ponto de TerraNova.rios[1])
const RUMO := Vector2(0.0, -1.0)  # da nascente para dentro da montanha (para o norte)
const TUBO := 6.5  # raio do corredor
const TUBO_MEIO := 5.0  # o eixo do corredor acima do piso dele
# o corredor: [ao longo, de lado, piso acima da nascente]; o primeiro ponto fica no ar, na frente do paredão,
# para abrir a boca
const CAMINHO: Array[Vector3] = [Vector3(-12.0, 0.0, 8.0), Vector3(8.0, 0.0, 8.0), Vector3(28.0, 3.5, 10.0),
	Vector3(50.0, -3.5, 12.5), Vector3(72.0, 0.0, 15.0)]
const SALAO_A := 90.0  # o meio do salão, ao longo
const SALAO_PISO := 15.0  # acima da nascente
const SALAO := Vector3(18.0, 10.0, 14.0)  # meias-medidas: ao longo, altura, de lado
const SALAO_MEIO := 6.0  # o meio do elipsoide acima do piso
const ESCONDE := 1.0  # onde a grade não foi rebaixada, a pele da peça fica este tanto abaixo do chão
const REBAIXO := 2.2
const BOCA_LONGE := 26.0  # até aqui (ao longo) a grade de longe desce com a de perto: a boca aparece de longe
const ESCURO := 0.8  # quanto escurece lá dentro (no Sumidouro é 1); a luz que passa pelo gelo vem do shader
const COR_CRISTAL := Color(0.6, 0.93, 1.0)

static var existe := false
static var tn: TerraNova
static var base := Vector3.ZERO  # a nascente: (x, chão, z)
static var boca := Vector3.ZERO  # o meio da boca, no paredão (nome na tela, testes, fotos)
static var salao := Vector3.ZERO  # o meio do salão, um pouco acima do piso
static var _mn := Vector3.ZERO
static var _mx := Vector3.ZERO
static var _g0 := Vector2i.ZERO  # o primeiro nó da caixa na grade da terra nova
static var _gn := Vector2i.ZERO  # quantos nós a caixa tem em x e em z
static var _antes := PackedFloat32Array()  # o chão de antes, nos nós da caixa
static var _baixo := PackedByteArray()  # 1 nos nós rebaixados
static var _mat: ShaderMaterial


static func _lado() -> Vector2:
	return Vector2(-RUMO.y, RUMO.x)


static func _mundo(a: float, s: float, y: float) -> Vector3:
	var l := _lado()
	return Vector3(base.x + RUMO.x * a + l.x * s, base.y + y, base.z + RUMO.y * a + l.y * s)


# ---------------------------------------------------------------- o chão de antes e o de agora

## A altura de um nó: a de antes (guardada) ou a de agora (a grade, já rebaixada).
static func _no(gx: int, gz: int, de_antes: bool) -> float:
	gx = clampi(gx, 0, TerraNova.NX - 1)
	gz = clampi(gz, 0, TerraNova.NZ - 1)
	if de_antes:
		var lx := gx - _g0.x
		var lz := gz - _g0.y
		if lx >= 0 and lz >= 0 and lx < _gn.x and lz < _gn.y:
			return _antes[lz * _gn.x + lx]
	return tn.h[gz * TerraNova.NX + gx]


## A altura num ponto do jeito que o chão é desenhado: dois triângulos por quadrado, com a diagonal do nó (i, j)
## ao (i + 1, j + 1) (TerraNova._grade). Assim a pele da peça casa com o chão em volta mesmo no paredão.
static func _tri(x: float, z: float, de_antes: bool) -> float:
	var fx := (x - TerraNova.X0) / TerraNova.PASSO
	var fz := (z - TerraNova.Z0) / TerraNova.PASSO
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := _no(ix, iz, de_antes)
	var h11 := _no(ix + 1, iz + 1, de_antes)
	if tx >= tz:
		var h10 := _no(ix + 1, iz, de_antes)
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	var h01 := _no(ix, iz + 1, de_antes)
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


static func antes(x: float, z: float) -> float:
	return _tri(x, z, true)


## A encosta que a peça refaz: o chão de antes onde a grade foi rebaixada, e ESCONDE abaixo dele onde a grade
## continua lá (as duas não brigam).
static func topo(x: float, z: float) -> float:
	var a := _tri(x, z, true)
	return a - ESCONDE * (1.0 - smoothstep(0.0, 1.0, a - _tri(x, z, false)))


static func rocha(p: Vector3) -> float:
	var morro := p.y - topo(p.x, p.z)
	return minf(maxf(morro, -vazio(p)), maxf(extra(p), morro))


# ---------------------------------------------------------------- a forma

## O piso do corredor e do salão num ponto, acima da nascente.
static func _piso_em(a: float) -> float:
	if a <= CAMINHO[0].x:
		return CAMINHO[0].z
	for i in CAMINHO.size() - 1:
		var p0 := CAMINHO[i]
		var p1 := CAMINHO[i + 1]
		if a <= p1.x:
			return lerpf(p0.z, p1.z, smoothstep(p0.x, p1.x, a))
	return SALAO_PISO


## Distância até o vazio (negativa dentro). É o desenho da gruta.
static func vazio(p: Vector3) -> float:
	var q := Vector2(p.x - base.x, p.z - base.z)
	var a := q.dot(RUMO)
	var s := q.dot(_lado())
	var y := p.y - base.y
	# paredes tortas: o ruído das grutas e mais um, médio, que deixa o gelo encaroçado; na boca ele pesa mais,
	# para a borda não sair redonda como uma janela
	var perto_boca := 1.0 - smoothstep(6.0, 22.0, a)
	var n := RochaMalha.parede(p) + RochaMalha.ruido.get_noise_3d(p.x * 1.9, p.y * 1.9, p.z * 1.9) * (0.9 + 1.1 * perto_boca)
	var n2 := RochaMalha.piso(p) * 0.7
	# o corredor: cápsulas emendadas, de piso chato; perto da boca o corte é um arco largo e baixo (mais largo
	# que alto, como a boca das grutas de geleira)
	var achata := 1.0 + 0.4 * perto_boca
	var raio := TUBO * (1.0 + 0.22 * perto_boca)
	var d := INF
	for i in CAMINHO.size() - 1:
		var c0 := CAMINHO[i]
		var c1 := CAMINHO[i + 1]
		var e0 := _mundo(c0.x, c0.y, c0.z + TUBO_MEIO)
		var e1 := _mundo(c1.x, c1.y, c1.z + TUBO_MEIO)
		var ab := e1 - e0
		var t := clampf((p - e0).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var r := p - (e0 + ab * t)
		r.y *= achata
		d = minf(d, r.length() - raio)
	d = maxf(d + n, _piso_em(a) + n2 - y)
	# o salão: um elipsoide de piso chato
	var e := Vector3((a - SALAO_A) / SALAO.x, (y - SALAO_PISO - SALAO_MEIO) / SALAO.y, s / SALAO.z)
	var ds := maxf((e.length() - 1.0) * minf(SALAO.y, SALAO.z) * 0.9 + n, SALAO_PISO + n2 - y)
	return minf(d, ds)


## Gelo posto de volta dentro do salão: duas colunas que vão do piso ao teto, de cintura fina.
static func extra(p: Vector3) -> float:
	var y := p.y - base.y
	var d := INF
	for col: Vector3 in [Vector3(SALAO_A + 3.0, -6.5, 2.4), Vector3(SALAO_A - 9.0, 7.5, 1.7)]:
		var pe := _mundo(col.x, col.y, 0.0)
		var cintura := col.z * (0.75 + 0.6 * pow(minf(1.4, absf((y - SALAO_PISO - 7.0) / 8.0)), 2.0))
		d = minf(d, Vector2(p.x - pe.x, p.z - pe.z).length() - cintura)
	return d + RochaMalha.fino.get_noise_3d(p.x * 0.7, p.y * 0.4, p.z * 0.7) * 0.5


# ---------------------------------------------------------------- na grade da terra nova

## Roda dentro de TerraNova.montar, antes de o chão e a colisão serem montados.
static func cavar(t: TerraNova) -> void:
	existe = false
	tn = t
	if t.h.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	base = Vector3(NASCENTE.x, t.altura(NASCENTE.x, NASCENTE.y), NASCENTE.y)
	boca = _mundo(CAMINHO[1].x - 2.0, 0.0, CAMINHO[1].z + 5.0)
	salao = _mundo(SALAO_A, 0.0, SALAO_PISO + 5.0)
	# a caixa: do ar na frente da boca até o fundo do salão, com folga para os lados
	var cantos: Array[Vector3] = [_mundo(-20.0, -24.0, 0.0), _mundo(-20.0, 24.0, 0.0), _mundo(SALAO_A + SALAO.x + 16.0, -24.0, 0.0),
		_mundo(SALAO_A + SALAO.x + 16.0, 24.0, 0.0)]
	var mn := cantos[0]
	var mx := cantos[0]
	for c in cantos:
		mn = mn.min(c)
		mx = mx.max(c)
	_g0 = Vector2i(floori((mn.x - TerraNova.X0) / TerraNova.PASSO) - 1, floori((mn.z - TerraNova.Z0) / TerraNova.PASSO) - 1)
	var g1 := Vector2i(ceili((mx.x - TerraNova.X0) / TerraNova.PASSO) + 1, ceili((mx.z - TerraNova.Z0) / TerraNova.PASSO) + 1)
	_gn = g1 - _g0 + Vector2i.ONE
	_antes.resize(_gn.x * _gn.y)
	_baixo.resize(_gn.x * _gn.y)
	_baixo.fill(0)
	var alto := -INF
	for lz in _gn.y:
		for lx in _gn.x:
			var hv := t.h[(_g0.y + lz) * TerraNova.NX + _g0.x + lx]
			_antes[lz * _gn.x + lx] = hv
			alto = maxf(alto, hv)
	_mn = Vector3(TerraNova.X0 + _g0.x * TerraNova.PASSO, base.y + CAMINHO[0].z - 6.0, TerraNova.Z0 + _g0.y * TerraNova.PASSO)
	_mx = Vector3(TerraNova.X0 + g1.x * TerraNova.PASSO, alto + 5.0, TerraNova.Z0 + g1.y * TerraNova.PASSO)
	existe = true
	# a grade desce até REBAIXO abaixo do piso do vazio (e mais dois nós em volta), como em RochaMalha.rebaixar
	var novo := {}
	var guardado: Variant = Cache.ler("boca_degelo_rebaixo")
	if guardado is Dictionary:
		novo = guardado
	else:
		for lz in _gn.y:
			for lx in _gn.x:
				var gx := _g0.x + lx
				var gz := _g0.y + lz
				var x := TerraNova.X0 + gx * TerraNova.PASSO
				var z := TerraNova.Z0 + gz * TerraNova.PASSO
				var y := _mn.y
				var teto := _antes[lz * _gn.x + lx] - 1.0
				while y < teto:
					if vazio(Vector3(x, y, z)) < 0.0:
						novo[Vector2i(gx, gz)] = y - REBAIXO
						break
					y += 0.6
		var fundo := {}
		for chave: Vector2i in novo:
			var m := float(novo[chave])
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					m = minf(m, float(novo.get(chave + Vector2i(dx, dz), INF)))
			fundo[chave] = m
		novo = fundo
		for volta in 2:
			var mais := {}
			for chave: Vector2i in novo:
				for dz in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var viz := chave + Vector2i(dx, dz)
						if not novo.has(viz):
							mais[viz] = minf(float(mais.get(viz, INF)), float(novo[chave]))
			for chave: Vector2i in mais:
				novo[chave] = mais[chave]
		Cache.gravar("boca_degelo_rebaixo", novo)
	var baixados := 0
	for chave: Vector2i in novo:
		var i := chave.y * TerraNova.NX + chave.x
		var y2 := float(novo[chave])
		if y2 < t.h[i]:
			t.h[i] = y2
			baixados += 1
			var lx2 := chave.x - _g0.x
			var lz2 := chave.y - _g0.y
			if lx2 >= 0 and lz2 >= 0 and lx2 < _gn.x and lz2 < _gn.y:
				_baixo[lz2 * _gn.x + lx2] = 1
		# de longe (blocos de 8 a 40 m por quadrado) o rebaixo fundo abria uma cova larga em volta da peça; lá
		# só a boca desce (para ela continuar aberta de longe), e não nos pontos dos blocos de 20 e 40 m; o resto
		# fica um pouco abaixo da pele, que cobre
		var lx3 := chave.x - _g0.x
		var lz3 := chave.y - _g0.y
		var an := t.h[i] if lx3 < 0 or lz3 < 0 or lx3 >= _gn.x or lz3 >= _gn.y else _antes[lz3 * _gn.x + lx3]
		var pn := Vector2(TerraNova.X0 + chave.x * TerraNova.PASSO, TerraNova.Z0 + chave.y * TerraNova.PASSO)
		var na_boca := (pn - NASCENTE).dot(RUMO) < BOCA_LONGE and not (chave.x % 5 == 0 and chave.y % 5 == 0)
		var y3 := y2 if na_boca else an - 1.5
		if y3 < t.h_longe[i]:
			t.h_longe[i] = y3
	print("boca do degelo: nascente em %s, boca a %.0f m, salão a %.0f m, %d nós rebaixados, %d ms"
		% [base, boca.y, salao.y, baixados, Time.get_ticks_msec() - t0])


## A grade foi rebaixada aqui (ou a menos de `folga` + 4 m): não nasce árvore, rocha, capim nem bicho.
static func dentro(x: float, z: float, folga := 0.0) -> bool:
	if not existe or x < _mn.x - folga - 8.0 or x > _mx.x + folga + 8.0 or z < _mn.z - folga - 8.0 or z > _mx.z + folga + 8.0:
		return false
	var f := folga + 4.0 if folga > 0.0 else 0.0
	var a0 := Vector2i(floori((x - f - TerraNova.X0) / TerraNova.PASSO), floori((z - f - TerraNova.Z0) / TerraNova.PASSO)) - _g0
	var a1 := Vector2i(ceili((x + f - TerraNova.X0) / TerraNova.PASSO), ceili((z + f - TerraNova.Z0) / TerraNova.PASSO)) - _g0
	for lz in range(maxi(a0.y, 0), mini(a1.y, _gn.y - 1) + 1):
		for lx in range(maxi(a0.x, 0), mini(a1.x, _gn.x - 1) + 1):
			if _baixo[lz * _gn.x + lx] == 1:
				return true
	return false


## Dentro da caixa da peça (só no plano).
static func na_caixa(p: Vector3) -> bool:
	return existe and p.x > _mn.x and p.x < _mx.x and p.z > _mn.z and p.z < _mx.z


## Debaixo da encosta, dentro do vazio da gruta (o escuro, a chuva, o eco, os testes).
static func no_vazio(p: Vector3) -> bool:
	return na_caixa(p) and p.y < antes(p.x, p.z) - 2.0 and vazio(p) < 0.0


## A fundura que vai na cor do vértice. A casca de fora (onde quem manda é o chão de antes) é 0: tem a cor do
## chão; as paredes do vazio e as colunas são gelo, menos os 3 primeiros metros abaixo da encosta (a beira da
## boca fica de pedra, sem o corte seco do cinza para o azul). Pela fundura só (o chão de antes menos a altura)
## as encostas íngremes saíam com pontas de gelo azul furando o chão, por fora da montanha.
static func _fundo(p: Vector3) -> float:
	var morro := p.y - topo(p.x, p.z)
	var v := -vazio(p)
	var e := extra(p)
	var de_fora := (morro >= v) if maxf(morro, v) <= maxf(e, morro) else (morro >= e)
	if de_fora:
		return 0.0
	return maxf(antes(p.x, p.z) - p.y - 2.0, 0.0)


static func assar() -> void:
	if existe:
		RochaMalha.assar_com(_mn, _mx, rocha, _fundo,
			ARQUIVO, base)


# ---------------------------------------------------------------- no mundo

static func montar(v: Vale) -> void:
	if not existe or tn == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/boca_degelo.gdshader")
	mat.set_shader_parameter("ruido", v._tex)
	mat.set_shader_parameter("cobertura", tn.tex_cob)
	mat.set_shader_parameter("origem", Vector2(TerraNova.X0, TerraNova.Z0))
	mat.set_shader_parameter("passo", TerraNova.PASSO)
	mat.set_shader_parameter("tamanho", Vector2i(TerraNova.NX, TerraNova.NZ))
	mat.set_shader_parameter("base_xz", Vector2(base.x, base.z))
	mat.set_shader_parameter("rumo", RUMO)
	if not RochaMalha.montar(ARQUIVO, "BocaDegelo", base, mat):
		return
	_mat = mat
	_enfeites(v)


## A luz do dia que atravessa o gelo (Ciclo, a cada quadro): de noite as paredes apagam e ficam os cristais.
static func luz(dia: float) -> void:
	if _mat:
		_mat.set_shader_parameter("dia", dia)


## O piso e o teto do vazio num ponto do mapa, a partir de uma altura dentro dele. Vector2(piso, teto) ou INF.
static func piso_teto(x: float, z: float, y0: float) -> Vector2:
	if vazio(Vector3(x, y0, z)) > 0.0:
		return Vector2(INF, INF)
	var a := y0
	while a > y0 - 25.0 and rocha(Vector3(x, a, z)) > 0.0:
		a -= 0.2
	var b := y0
	while b < y0 + 30.0 and rocha(Vector3(x, b, z)) > 0.0:
		b += 0.2
	return Vector2(a, b)


static func _enfeites(v: Vale) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13713
	# cristais de gelo acesos: sete no salão, perto das paredes e ao pé das colunas, e três no corredor
	var lugares: Array[Vector3] = [Vector3(SALAO_A - 12.0, -10.0, 1.3), Vector3(SALAO_A + 9.0, 11.0, 1.5),
		Vector3(SALAO_A + 13.0, -7.0, 1.1), Vector3(SALAO_A - 3.0, 12.0, 1.0), Vector3(SALAO_A + 6.0, -9.5, 0.8),
		Vector3(SALAO_A - 11.0, 9.0, 0.9), Vector3(SALAO_A + 15.0, 3.0, 1.2),
		Vector3(24.0, 4.5, 0.6), Vector3(42.0, -5.0, 0.7), Vector3(62.0, 3.5, 0.8)]
	for l in lugares:
		var p := _mundo(l.x, l.y, _piso_em(l.x) + 3.0)
		var pt := piso_teto(p.x, p.z, p.y)
		if pt.x != INF and pt.x > p.y - 24.0:
			RochaMalha.cristal(Vector3(p.x, pt.x, p.z), COR_CRISTAL, rng, l.z, 0.5)  # o gelo espelha: meia luz basta
	_pingentes(v, rng)
	# uma luz fria e fraca no meio do salão, para o fundo não ficar um breu
	var geral := OmniLight3D.new()
	geral.name = "LuzDaBocaDoDegelo"
	geral.light_color = Color(0.6, 0.85, 1.0)
	geral.light_energy = 0.3
	geral.omni_range = 30.0
	geral.omni_attenuation = 0.7
	geral.shadow_enabled = false
	geral.position = salao + Vector3(0, 4.0, 0)
	v.add_child(geral)


## Pingentes de gelo no teto do corredor e do salão, num MultiMesh só.
static func _pingentes(v: Vale, rng: RandomNumberGenerator) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 2
	var lista: Array[Transform3D] = []
	for i in 380:
		# os primeiros 80 vão na beira da boca: uma franja de pingentes compridos que se vê lá de fora
		var na_beira := i < 80
		var a := rng.randf_range(0.0, 6.0) if na_beira else rng.randf_range(8.0, SALAO_A + SALAO.x - 2.0)
		var s := rng.randf_range(-SALAO.z, SALAO.z) if a > SALAO_A - SALAO.x else rng.randf_range(-7.5, 7.5)
		var p := _mundo(a, s, _piso_em(a) + 3.0)
		var pt := piso_teto(p.x, p.z, p.y)
		# (na frente do paredão o vazio dá no céu: sem teto achado, nada de pingente solto no ar)
		if pt.x == INF or pt.y - pt.x < 5.0 or pt.y > p.y + 29.0:
			continue
		var alt := rng.randf_range(0.5, minf(2.6, (pt.y - pt.x) * 0.2))
		if na_beira:
			alt = rng.randf_range(0.8, 3.2)
		var larg := alt * rng.randf_range(0.14, 0.24)
		lista.append(Transform3D(Basis.from_scale(Vector3(larg, -alt, larg)), Vector3(p.x, pt.y + 0.25 - alt * 0.5, p.z)))
	if lista.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = lista.size()
	for i in lista.size():
		mm.set_instance_transform(i, lista[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "PingentesDeGelo"
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.8, 0.9)
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = Color(0.2, 0.45, 0.6)
	m.emission_energy_multiplier = 0.5
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(mmi)
