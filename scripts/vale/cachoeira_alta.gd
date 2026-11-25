class_name CachoeiraAlta
extends RefCounted
## A cachoeira do poço do norte (doc §164, 2026-11-24). A de antes era uma fita lisa colada na encosta, sem espuma
## no pé e com um poço que parecia cascalho ("não tem cara de cachoeira", o usuário). A ideia que ele mandou (um
## desenho de banco de imagens, usado só como referência) tem a água caindo em dois degraus, fazendo a curva na
## beirada, espuma branca onde bate, ondas no poço, uma coluna de pedras empilhadas e mato em volta.
## Aqui: a queda de cima sai da nascente em arco por cima de uma laje e bate num degrau de lajes empilhadas; a água
## corre por cima dele e cai em duas quedas no poço, separadas por uma pedra. As quedas têm volume (QuedaDagua);
## espuma, gotas e névoa nos dois pés, ondas no poço. A pedra é a dos paredões, com musgo e mato.
## A água desce encostada na pedra (doc §165: em arco solto ela passava de 2 a 6 m na frente e parecia flutuar): a de
## cima por lajes deitadas no caimento dela, num rego entre dois umbrais; as de baixo rente à frente das lajes do
## degrau; e as costas da água são achatadas (`COSTAS`), coladas na pedra até as beiradas. O poço ganhou uma enseada
## que chega até debaixo da frente do degrau, para as quedas de baixo caírem na água e não em terra seca.
## Medidas ao longo da queda: `al` vai da nascente para o poço, `lat` para o lado (+ do lado da coluna de pedras,
## o oposto da gruta).

const BEIRA := 3.5  # onde a água sai do alto (ao longo)
const DEGRAU_Y := 122.0  # o alto do degrau do meio
const DEGRAU_DE := 9.5  # o fundo do degrau, encostado no paredão
const DEGRAU_ATE := 25.5  # a beira da frente do degrau
const POUSO_CIMA := 10.6  # onde a queda de cima bate no degrau (rente ao fundo dele)
const LAJE_BEIRA := BEIRA + 1.8  # a frente da laje da beirada, a quina por onde a água de cima faz a curva
const BAIXO_LAT := 4.0  # cada queda de baixo, para um lado da pedra do meio
const BAIXO_LONGE := 2.4  # quanto o pé da queda de baixo fica além da beira do degrau (rente às lajes)
const COLUNA := Vector2(15.5, 12.0)  # o pé da coluna empilhada (ao longo, de lado)
const COSTAS := 0.25  # a metade de trás da água, achatada contra a pedra (QuedaDagua.fita)
const EMBUTE := 0.25  # quanto as costas da água entram na pedra, para não sobrar fresta

static var _dir := Vector2.ZERO
static var _lado := Vector2.ZERO
static var _topo := 0.0  # a altura da água no alto da beirada
## As lajes do degrau: [triângulos virados para a frente, já no lugar; lat de, lat até, y de, y até (a caixa)]. As
## quedas de baixo descem rente a elas.
static var _lajes: Array = []

## A enseada do poço (doc §165): o meio dela ao longo e os meios-eixos (ao longo, de lado), e a fundura no meio.
const ENSEADA := Vector3(28.5, 7.5, 12.5)
const ENSEADA_FUNDO := 3.4
static var _enseada_idx := PackedInt32Array()  # os nós da grade de fora que a enseada baixou
static var _enseada_antes := PackedFloat32Array()
static var _enseada_novo := PackedFloat32Array()
static var _enseada_marca := PackedByteArray()  # um por nó: onde os sorteios de fora não põem nada


static func _eixo() -> void:
	_dir = (Vector2(Vale.POCO.x, Vale.POCO.y) - Vale.NASCENTE).normalized()
	_lado = Vector2(-_dir.y, _dir.x)


## Os blocos do paredão (Paredoes) que ficavam na frente da queda e no lugar do degrau e da coluna saem: a pedra
## dali é a da cachoeira. Só tira o que já foi sorteado (o sorteio e o cache dos paredões não mudam).
static func tira_bloco(p: Vector3) -> bool:
	if _dir == Vector2.ZERO:
		_eixo()
	var q := Vector2(p.x, p.z) - Vale.NASCENTE
	var al := q.dot(_dir)
	var lat := q.dot(_lado)
	return al > -3.0 and al < 28.0 and lat > -8.0 and lat < 15.5


# ---------------------------------------------------------------- a enseada do poço

## O quanto (x, z) está para fora da enseada: 0 no meio dela, 1 no contorno (torto, não um círculo de compasso).
static func _e_enseada(x: float, z: float) -> float:
	if _dir == Vector2.ZERO:
		_eixo()
	var q := Vector2(x, z) - Vale.NASCENTE
	var e := Vector2((q.dot(_dir) - ENSEADA.x) / ENSEADA.y, q.dot(_lado) / ENSEADA.z)
	var ang := e.angle()
	return e.length() / (1.0 + 0.08 * sin(ang * 3.0 + 0.7) + 0.05 * sin(ang * 5.0 + 2.1))


## Onde a enseada tem água (Vale.agua, onde o chão fica abaixo do nível do poço).
static func na_enseada(x: float, z: float) -> bool:
	return _e_enseada(x, z) < 1.12


## O poço chegava a uns 30 m da nascente e o pé das quedas de baixo, rente às lajes, caía em terra seca (o usuário
## viu, doc §165). A enseada baixa a grade de fora em volta do pé, até debaixo da frente do degrau, com uns 3 m de
## fundo, e emenda no poço. Como no ombro da Fundição, guarda o relevo de antes: os sorteios da mata, das plantas e
## dos paredões correm nele (`relevo_antigo`), para o resto da ilha não mudar, e não põem nada onde a enseada mexeu
## (`enseada_mexida`). O chão de antes das cavernas (`Cavernas.chao_antes`) desce junto: a enseada é chão de
## fora, não corte de caverna, e sem isso o fundo dela contava como subsolo (escuro e sem chuva) e como furo por
## cima da rocha do Sumidouro.
static func cavar_enseada(v: Vale) -> void:
	_eixo()
	var n := Vale.F_N
	_enseada_idx.clear()
	_enseada_antes.clear()
	_enseada_novo.clear()
	var marca := PackedByteArray()
	marca.resize(n * n)
	var meio := aqui(ENSEADA.x, 0, 0)
	var alcance := maxf(ENSEADA.y, ENSEADA.z) * 1.5 + Vale.F_PASSO
	var g0 := Vector2i(floori((meio.x - alcance + Vale.F_META) / Vale.F_PASSO), floori((meio.z - alcance + Vale.F_META) / Vale.F_PASSO))
	var g1 := Vector2i(ceili((meio.x + alcance + Vale.F_META) / Vale.F_PASSO), ceili((meio.z + alcance + Vale.F_META) / Vale.F_PASSO))
	for gz in range(maxi(g0.y, 1), mini(g1.y, n - 1)):
		for gx in range(maxi(g0.x, 1), mini(g1.x, n - 1)):
			var x := -Vale.F_META + gx * Vale.F_PASSO
			var z := -Vale.F_META + gz * Vale.F_PASSO
			var e := _e_enseada(x, z)
			if e > 1.3:
				continue
			var i := gz * n + gx
			var h := v._fora_h[i]
			var novo := minf(h, lerpf(Vale.POCO_NIVEL - ENSEADA_FUNDO, maxf(h, Vale.POCO_NIVEL + 0.4), smoothstep(0.55, 1.2, e)))
			if novo < h - 0.005:
				v._fora_h[i] = novo
				Cavernas._orig[i] = minf(Cavernas._orig[i], novo)
				_enseada_idx.append(i)
				_enseada_antes.append(h)
				_enseada_novo.append(novo)
				marca[i] = 1
	_enseada_marca = PackedByteArray()
	_enseada_marca.resize(n * n)
	for k in _enseada_idx.size():
		var i := _enseada_idx[k]
		for j: int in [i, i - 1, i + 1, i - n, i + n]:
			_enseada_marca[j] = 1
	print("cachoeira: enseada do poço em %d nós da grade" % _enseada_idx.size())


## Troca a grade de fora entre o relevo de antes da enseada e o de agora (Vale._relevo_antigo).
static func relevo_antigo(v: Vale, antigo: bool) -> void:
	var fonte := _enseada_antes if antigo else _enseada_novo
	for k in _enseada_idx.size():
		v._fora_h[_enseada_idx[k]] = fonte[k]


## Onde a enseada mexeu no chão (com a folga de um nó): os sorteios de fora não põem nada ali (Vale.chao_mexido).
static func enseada_mexida(x: float, z: float) -> bool:
	if _enseada_marca.is_empty():
		return false
	var gx := roundi((x + Vale.F_META) / Vale.F_PASSO)
	var gz := roundi((z + Vale.F_META) / Vale.F_PASSO)
	if gx < 0 or gz < 0 or gx >= Vale.F_N or gz >= Vale.F_N:
		return false
	return _enseada_marca[gz * Vale.F_N + gx] == 1


static func aqui(al: float, lat: float, y: float) -> Vector3:
	var p := Vale.NASCENTE + _dir * al + _lado * lat
	return Vector3(p.x, y, p.y)


static func _dir3() -> Vector3:
	return Vector3(_dir.x, 0, _dir.y)


static func _lado3() -> Vector3:
	return Vector3(_lado.x, 0, _lado.y)


## O lado de trás da queda de cima (ao longo) em cada altura: rente à frente da laje da beirada no alto, saindo devagar
## para a frente até o fundo do degrau. As lajes de trás dela seguem esta mesma linha.
static func _costas_cima(y: float) -> float:
	return LAJE_BEIRA - 0.2 + 4.3 * pow(_t_cima(y), 1.6)


## Quanto a queda de cima avança para cada metro que desce (o caimento das lajes de trás dela).
static func _caimento_cima(y: float) -> float:
	return 4.3 * 1.6 * pow(maxf(_t_cima(y), 0.001), 0.6) / (_topo - 0.5 - DEGRAU_Y - 0.3)


static func _t_cima(y: float) -> float:
	return clampf((_topo - 0.5 - y) / (_topo - 0.5 - DEGRAU_Y - 0.3), 0.0, 1.0)


## Para onde olha a frente de uma laje deitada `incl` (para a frente e um pouco para cima).
static func _para_fora(incl: float) -> Vector3:
	return _dir3() * cos(incl) + Vector3.UP * sin(incl)


## Guarda uma laje do degrau (malha e lugar): só os triângulos virados para a frente, que é onde a água encosta.
static func _guarda_laje(malha: ArrayMesh, xf: Transform3D, lat: float, tam: Vector3, y0: float, y1: float) -> void:
	var tris := PackedVector3Array()
	var v: PackedVector3Array = malha.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var frente := _dir3()
	for i in range(0, v.size() - 2, 3):
		var a := xf * v[i]
		var b := xf * v[i + 1]
		var c := xf * v[i + 2]
		var n := (b - a).cross(c - a)
		if absf(n.dot(frente)) > 0.2 * n.length():
			tris.append_array([a, b, c])
	_lajes.append([tris, lat - tam.x * 0.5 - 0.5, lat + tam.x * 0.5 + 0.5, y0 - 0.5, y1 + 0.5])


## Onde está a frente da pedra do degrau em (`lat`, `y`), ao longo: um raio de frente para trás contra as lajes.
static func _frente_laje(lat: float, y: float) -> float:
	var de := aqui(60.0, lat, y)
	var para := -_dir3()
	var melhor := -INF
	for laje: Array in _lajes:
		if lat < float(laje[1]) or lat > float(laje[2]) or y < float(laje[3]) or y > float(laje[4]):
			continue
		var tris: PackedVector3Array = laje[0]
		for i in range(0, tris.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(de, para, tris[i], tris[i + 1], tris[i + 2])
			if hit != null:
				var q := Vector2((hit as Vector3).x, (hit as Vector3).z) - Vale.NASCENTE
				melhor = maxf(melhor, q.dot(_dir))
	return melhor


## O caminho da queda de baixo em `lat`: por cima do canal, a curva na quina dele e, dali, rente à frente da pedra (a
## do meio das cinco medidas de lado a lado, em cada altura; as camadas de baixo ficam mais à frente), sem voltar para
## trás e alisado.
static func _caminho_baixo(lat: float) -> PackedVector3Array:
	var ys := PackedFloat32Array()
	var als := PackedFloat32Array()
	var y := DEGRAU_Y - 0.6
	while y > Vale.POCO_NIVEL - 0.4:
		var achou: Array[float] = []
		for dl: float in [-2.0, -1.0, 0.0, 1.0, 2.0]:
			var f := _frente_laje(lat + dl, y)
			if not is_inf(f):
				achou.append(f)
		achou.sort()
		ys.append(y)
		als.append(achou[achou.size() / 2] if not achou.is_empty() else -INF)
		y -= 0.5
	# fresta entre duas camadas: fica a de cima; descendo, a água nunca volta para dentro
	for i in als.size():
		if is_inf(als[i]):
			als[i] = als[maxi(i - 1, 0)] if i > 0 else DEGRAU_ATE
		if i > 0:
			als[i] = maxf(als[i], als[i - 1])
	var lisa := PackedFloat32Array()
	for i in als.size():
		var soma := 0.0
		var n := 0
		for j in range(maxi(i - 2, 0), mini(i + 3, als.size())):
			soma += als[j]
			n += 1
		lisa.append(soma / n - EMBUTE)
	var quina := als[0]
	var pts := PackedVector3Array([aqui(DEGRAU_ATE - 1.6, lat, DEGRAU_Y - 0.1), aqui(DEGRAU_ATE - 0.7, lat, DEGRAU_Y - 0.12),
		aqui(quina - 0.4, lat, DEGRAU_Y - 0.15), aqui(quina - 0.12, lat, DEGRAU_Y - 0.38)])
	for i in lisa.size():
		pts.append(aqui(lisa[i], lat, ys[i]))
	pts.append(aqui(lisa[lisa.size() - 1], lat, Vale.POCO_NIVEL - 0.4))
	return pts


static func montar(v: Vale) -> void:
	_eixo()
	var raiz := Node3D.new()
	raiz.name = "CachoeiraAlta"
	v.add_child(raiz)
	var topo_y := v.queda_topo.y - 0.2
	_topo = topo_y
	_lajes.clear()
	_pedras(v, raiz)
	var mats := QuedaDagua.materiais(v._tex)
	var lado3 := _lado3()
	# a queda de cima: a água chega pela bacia da nascente, faz a curva na quina da laje da beirada e desce encostada
	# nas lajes de trás dela até o fundo do degrau
	var cima := PackedVector3Array([aqui(BEIRA - 2.5, 0, topo_y + 0.1), aqui(BEIRA - 0.8, 0, topo_y + 0.05),
		aqui(BEIRA + 0.9, 0, topo_y), aqui(LAJE_BEIRA - 0.45, 0, topo_y - 0.05), aqui(LAJE_BEIRA - 0.2, 0, topo_y - 0.35)])
	for k in 15:
		var y := lerpf(topo_y - 0.9, DEGRAU_Y + 0.3, k / 14.0)
		cima.append(aqui(_costas_cima(y), 0, y))
	QuedaDagua.queda(raiz, cima, lado3, 7.6, 9.6, 1.2, 3.4, mats, "QuedaDeCima", COSTAS)
	# por cima do degrau, rasa e cheia de espuma, abrindo até a beira da frente
	var rasa := PackedVector3Array()
	for k in 8:
		rasa.append(aqui(lerpf(POUSO_CIMA - 0.5, DEGRAU_ATE - 0.4, k / 7.0), 0, DEGRAU_Y + 0.32))
	QuedaDagua.fita(raiz, rasa, lado3, 9.0, 13.0, 0.12, 0.2, QuedaDagua.material_rasa(mats[0]), "AguaDoDegrau")
	# as duas quedas de baixo, uma de cada lado da pedra do meio, descendo rente às lajes do degrau
	var pes: Array[Vector3] = []
	for s: float in [-1.0, 1.0]:
		var baixo := _caminho_baixo(BAIXO_LAT * s)
		QuedaDagua.queda(raiz, baixo, lado3, 4.8, 6.2, 1.0, 2.8, mats, "QuedaDeBaixo", COSTAS)
		pes.append(baixo[baixo.size() - 1] + _dir3() * 1.2)
	# espuma, gotas e névoa onde a água bate
	var bate_cima := aqui(POUSO_CIMA + 0.6, 0, DEGRAU_Y + 0.35)
	QuedaDagua.espuma(raiz, bate_cima, 3.8, 14, 1)
	QuedaDagua.gotas(raiz, bate_cima, 3.0, 30)
	QuedaDagua.nevoa(raiz, bate_cima + Vector3(0, 0.6, 0), lado3, 4.0, 14)
	for k in pes.size():
		var pe: Vector3 = pes[k] + Vector3(0, 0.3, 0)
		QuedaDagua.espuma(raiz, pe, 3.4, 13, 7 + k)
		QuedaDagua.gotas(raiz, pe, 2.8, 28)
	QuedaDagua.nevoa(raiz, aqui(DEGRAU_ATE + BAIXO_LONGE, 0, Vale.POCO_NIVEL + 0.8), lado3, 7.5, 28)
	QuedaDagua.ondas(raiz, aqui(DEGRAU_ATE + BAIXO_LONGE + 2.0, 0, Vale.POCO_NIVEL + 0.05), v._tex, 20.0, Color(0.30, 0.62, 0.82), Vale.POCO)
	# o som e o frio de atravessar (Vale.na_cachoeira): as duas alturas
	v.quedas.append((cima[cima.size() - 1] + cima[2]) * 0.5)
	v.quedas.append(aqui(DEGRAU_ATE + 3.0, 0, (DEGRAU_Y + Vale.POCO_NIVEL) * 0.5))
	v.cortinas.append([cima[2], cima[cima.size() - 1], 7.6])
	v.cortinas.append([aqui(DEGRAU_ATE, 0, DEGRAU_Y), aqui(DEGRAU_ATE + BAIXO_LONGE, 0, Vale.POCO_NIVEL), 8.5])


# ---------------------------------------------------------------- as pedras

## O degrau de lajes empilhadas (quatro camadas, as de baixo um pouco mais à frente, e o canal em cima), a pedra do
## meio que divide a água de baixo, a coluna empilhada em pé do lado de fora da gruta, a laje da beirada por onde a
## água de cima faz a curva, as lajes deitadas atrás da queda de cima com um umbral de cada lado e pedras redondas na
## beira do poço. A pedra dos paredões (cachoeira_pedra), com musgo e capim em cima de cada laje; tudo com colisão.
static func _pedras(v: Vale, raiz: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/cachoeira_pedra.gdshader")
	mat.set_shader_parameter("ruido", v._tex)
	var malhas: Array[ArrayMesh] = [Paredoes.rocha(77, 4), Paredoes.rocha(91, 3), Paredoes.rocha(53, 5), Paredoes.rocha(64, 4)]
	var corpo := StaticBody3D.new()
	corpo.name = "PedrasDaCachoeira"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	raiz.add_child(corpo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	# uma pedra que ocupa a caixa (lat, alto, ao longo) com o meio em `centro`; `inclina` deita a frente dela para cima
	# (a parte de baixo mais à frente)
	var pedra := func(centro: Vector3, tam: Vector3, giro: float, inclina: float) -> Array:
		var malha: ArrayMesh = malhas[rng.randi() % malhas.size()]
		var caixa := malha.get_aabb()
		var esc := Vector3(tam.x / caixa.size.x, tam.y / caixa.size.y, tam.z / caixa.size.z)
		var base := Basis(_lado3(), Vector3.UP, -_dir3()) * Basis.from_euler(Vector3(rng.randf_range(-0.04, 0.04) + inclina, giro, rng.randf_range(-0.04, 0.04)))
		var meio_local := caixa.position + caixa.size * 0.5
		var xf := Transform3D(base.scaled_local(esc), Vector3.ZERO)
		xf.origin = centro - xf.basis * meio_local
		var mi := MeshInstance3D.new()
		mi.mesh = malha
		mi.material_override = mat
		mi.transform = xf
		raiz.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = malha.create_convex_shape()
		cs.transform = xf
		corpo.add_child(cs)
		return [malha, xf]
	# o degrau: quatro camadas de lajes de lado a lado e, no alto, o canal (o meio 0,25 m abaixo da água e as
	# beiras levantadas, as margens)
	for ci in 4:
		var y0 := 107.4 + ci * 2.9
		var frente := DEGRAU_ATE + (4 - ci) * 0.45
		for lat: float in [-7.0, 0.0, 7.0]:
			for al: float in [DEGRAU_DE + 3.6, frente - 3.8]:
				var tam := Vector3(7.4 + rng.randf_range(-0.3, 0.5), 3.3, 7.6 + rng.randf_range(-0.3, 0.4))
				var c_al := al + rng.randf_range(-0.3, 0.3)
				var c_lat := lat + rng.randf_range(-0.5, 0.5)
				var feita: Array = pedra.call(aqui(c_al, c_lat, y0 + 1.65), tam, rng.randf_range(-0.1, 0.1), 0.0)
				_guarda_laje(feita[0], feita[1], c_lat, tam, y0, y0 + 3.3)
	for dados: Array in [[-8.6, 3.6, true], [-4.0, 4.8, false], [0.0, 3.6, false], [4.0, 4.8, false], [8.6, 3.6, true]]:
		var alto := DEGRAU_Y + 1.4 if dados[2] else DEGRAU_Y - 0.25
		var y0 := 107.4 + 4 * 2.9 - 0.3
		for al: float in [DEGRAU_DE + 3.6, DEGRAU_ATE - 3.8]:
			var tam := Vector3(float(dados[1]) + rng.randf_range(-0.2, 0.3), alto - y0, 7.6 + rng.randf_range(-0.3, 0.4))
			var c_al := al + rng.randf_range(-0.3, 0.3)
			var c_lat := float(dados[0]) + rng.randf_range(-0.2, 0.2)
			var feita: Array = pedra.call(aqui(c_al, c_lat, (y0 + alto) * 0.5), tam, rng.randf_range(-0.08, 0.08), 0.0)
			_guarda_laje(feita[0], feita[1], c_lat, tam, y0, alto)
	# a pedra do meio, na beira da frente, entre as duas quedas de baixo
	pedra.call(aqui(DEGRAU_ATE - 0.9, 0, DEGRAU_Y + 0.7), Vector3(2.8, 2.6, 3.6), 0.2, 0.0)
	# a coluna empilhada, em pé, do lado de fora da gruta: lajes cada vez menores, cada uma meio torta
	for k in 8:
		var y0 := 107.6 + k * 4.4
		var tam := Vector3(lerpf(7.0, 5.0, k / 7.0), 4.8, lerpf(7.6, 5.4, k / 7.0))
		var c := aqui(COLUNA.x + rng.randf_range(-0.6, 0.6) - k * 0.25, COLUNA.y + rng.randf_range(-0.6, 0.6), y0 + 2.4)
		pedra.call(c, tam, rng.randf_range(-0.3, 0.3), 0.0)
	# a laje da beirada, por onde a água de cima faz a curva, e uma pedra de cada lado dela
	var topo := v.queda_topo.y - 0.2
	pedra.call(aqui(BEIRA - 1.0, 0, topo - 1.7), Vector3(10.4, 3.2, 5.6), 0.0, 0.0)
	pedra.call(aqui(BEIRA + 0.3, -6.1, topo + 0.6), Vector3(3.4, 3.4, 4.6), 0.3, 0.0)
	pedra.call(aqui(BEIRA + 0.6, 6.4, topo + 0.9), Vector3(3.8, 4.0, 4.8), -0.2, 0.0)
	# pedras redondas na beira do poço (longe da saída do riacho e da boca da gruta)
	var poco := Vector2(Vale.POCO.x, Vale.POCO.y)
	for dados: Array in [[0.95, 20.0, 3.4], [1.25, 21.0, 2.6], [1.55, 19.5, 3.0], [-1.25, 20.5, 2.4], [-1.6, 19.0, 2.8]]:
		var ang: float = _dir.angle() + PI + float(dados[0])
		var r: float = dados[1]
		var p := poco + Vector2(cos(ang), sin(ang)) * r
		var tam: float = dados[2]
		var chao := v.altura(p.x, p.y)
		pedra.call(Vector3(p.x, chao + tam * 0.3, p.y), Vector3(tam * 1.2, tam * 0.9, tam), rng.randf() * TAU, 0.0)
	# atrás da queda de cima: lajes empilhadas, deitadas no caimento da água, para ela descer encostada na pedra, e um
	# umbral de cada lado, mais à frente, para ela correr num rego (doc §165; antes havia 4 a 6 m de ar atrás dela)
	# (as fileiras trocam entre duas lajes e uma só, como tijolos: a emenda não fica sempre no meio da água)
	var y_laje := DEGRAU_Y - 0.4
	var fileira := 0
	while y_laje < topo - 3.0:
		var ym := y_laje + 1.65
		var incl := atan(_caimento_cima(ym))
		var lats: Array = [[-2.5, 6.6], [2.5, 6.6]] if fileira % 2 == 0 else [[0.0, 9.8]]
		for dados: Array in lats:
			var tam := Vector3(float(dados[1]) + rng.randf_range(-0.2, 0.4), 3.3, 5.0)
			var frente := aqui(_costas_cima(ym) + EMBUTE + 0.1, float(dados[0]) + rng.randf_range(-0.2, 0.2), ym)
			pedra.call(frente - _para_fora(incl) * tam.z * 0.5, tam, rng.randf_range(-0.05, 0.05), incl)
		y_laje += 2.85
		fileira += 1
	var umbrais: Array[Vector3] = []
	for s: float in [-1.0, 1.0]:
		for k in 3:
			var alto := 6.4 if k < 2 else 7.2
			var ym := DEGRAU_Y - 0.4 + k * 5.9 + alto * 0.5
			var incl := atan(_caimento_cima(ym))
			var tam := Vector3(2.8 + rng.randf_range(-0.2, 0.4), alto, 5.4)
			var frente := aqui(_costas_cima(ym) + 1.1, s * (6.5 + rng.randf_range(-0.2, 0.3)), ym)
			pedra.call(frente - _para_fora(incl) * tam.z * 0.5, tam, rng.randf_range(-0.12, 0.12), incl)
			umbrais.append(aqui(_costas_cima(ym + alto * 0.5) + 0.5, s * 6.7, ym + alto * 0.5 - 0.15))
	# o miolo do degrau: entre a fileira de lajes de trás e a da frente sobrava um corredor de 1 a 3 m, da água até o
	# canal, onde dava para entrar e ver a água passando por cima (o usuário, em -295, 108, -514); três pedras altas
	# o fecham
	for lat: float in [-6.6, 0.0, 6.6]:
		pedra.call(aqui(18.2, lat + rng.randf_range(-0.3, 0.3), 114.1), Vector3(7.8, 14.2, 5.6), rng.randf_range(-0.06, 0.06), 0.0)
	# e atrás do degrau, do lado da gruta, onde o paredão se afasta: outro oco entre as lajes e a encosta
	pedra.call(aqui(6.6, -8.4, 114.6), Vector3(6.8, 14.6, 6.4), 0.15, 0.0)
	# o pé do degrau dentro d'água: com a enseada, o chão debaixo da fileira da frente desce até o fundo
	for lat: float in [-7.0, 0.0, 7.0]:
		var tam := Vector3(7.6 + rng.randf_range(-0.2, 0.4), 4.2, 7.4)
		var c_al := DEGRAU_ATE + 1.9 - tam.z * 0.5 + rng.randf_range(-0.2, 0.2)
		pedra.call(aqui(c_al, lat + rng.randf_range(-0.4, 0.4), Vale.POCO_NIVEL - 2.3), tam, rng.randf_range(-0.1, 0.1), 0.0)
	# mato: arbustos e samambaias saindo das lajes (na frente de cada camada do degrau, nas margens do canal, na
	# coluna e no alto), moitas no pé, para as pedras serem do lugar e não postas ali
	var plantas: Array = []
	for s: float in [-1.0, 1.0]:
		plantas.append(["arbusto", aqui(DEGRAU_ATE - 2.2, s * 8.9, DEGRAU_Y + 1.3), 1.15])
		plantas.append(["arbusto", aqui(DEGRAU_DE + 2.8, s * 9.0, DEGRAU_Y + 1.3), 0.95])
		plantas.append(["q_samambaia", aqui(DEGRAU_ATE - 0.6, s * 9.6, DEGRAU_Y + 1.2), 1.4])
		for ci in 4:
			var frente := DEGRAU_ATE + (4 - ci) * 0.45
			var lat := s * (9.2 + 0.5 * float((ci + int(s > 0.0)) % 2))
			var nome := "q_samambaia" if (ci + int(s > 0.0)) % 2 == 0 else "arbusto"
			plantas.append([nome, aqui(frente - 0.5, lat, 107.4 + ci * 2.9 + 3.2), 1.3 if nome == "q_samambaia" else 0.8])
		var pe_lado := aqui(DEGRAU_ATE + 2.2, s * 15.5, 0.0)  # na margem da enseada
		plantas.append(["q_planta_b", Vector3(pe_lado.x, v.altura(pe_lado.x, pe_lado.z), pe_lado.z), 1.4])
	for k: int in [1, 2, 3, 4, 5, 6, 7]:
		var y0 := 107.6 + k * 4.4
		var nome: String = ["q_samambaia", "arbusto", "q_planta_d"][k % 3]
		plantas.append([nome, aqui(19.0 - 0.4 * k, COLUNA.y - 1.6 + 1.2 * float(k % 2), y0 + 0.1), 1.2 if nome == "arbusto" else 1.5])
	plantas.append(["arbusto", aqui(COLUNA.x - 2.0, COLUNA.y, 107.6 + 8 * 4.4 + 0.1), 1.5])
	for k in umbrais.size():
		plantas.append(["q_samambaia" if k % 2 == 0 else "arbusto", umbrais[k], 1.3 if k % 2 == 0 else 0.85])
	for dados: Array in [[BEIRA - 0.5, 8.6, "arbusto", 1.2], [BEIRA - 3.0, 7.8, "q_samambaia", 1.4], [BEIRA + 1.5, 10.5, "arbusto", 1.0]]:
		var p := aqui(float(dados[0]), float(dados[1]), 0.0)
		plantas.append([dados[2], Vector3(p.x, v.altura(p.x, p.z), p.z), dados[3]])
	for dados: Array in [["q_moita", 32.0, 12.5, 1.3], ["q_moita", 29.5, -16.5, 1.2], ["q_moita", 38.0, 15.5, 1.2], ["q_samambaia", 41.0, -16.0, 1.4]]:
		var p := aqui(float(dados[1]), float(dados[2]), 0.0)
		plantas.append([dados[0], Vector3(p.x, v.altura(p.x, p.z), p.z), dados[3]])
	for pl: Array in plantas:
		if v._malhas.has(pl[0]):
			var p: Vector3 = pl[1]
			# nada nascendo do fundo da enseada nem boiando nela
			if p.y < Vale.POCO_NIVEL + 1.0 and v.agua(p.x, p.z) > v.altura(p.x, p.z) - 0.05:
				continue
			v._por(pl[0], Transform3D(Basis(Vector3.UP, p.x * 1.3 + p.z).scaled(Vector3.ONE * float(pl[2])), p))
