class_name CachoeiraAlta
extends RefCounted
## A cachoeira do poço do norte (doc §164, 2026-11-24). A de antes era uma fita lisa colada na encosta, sem espuma
## no pé e com um poço que parecia cascalho ("não tem cara de cachoeira", o usuário). A ideia que ele mandou (um
## desenho de banco de imagens, usado só como referência) tem a água caindo em dois degraus, fazendo a curva na
## beirada, espuma branca onde bate, ondas no poço, uma coluna de pedras empilhadas e mato em volta.
## Aqui: a queda de cima sai da nascente em arco por cima de uma laje e bate num degrau de lajes empilhadas; a água
## corre por cima dele e cai em duas quedas no poço, separadas por uma pedra. As quedas têm volume (QuedaDagua);
## espuma, gotas e névoa nos dois pés, ondas no poço. A pedra é a dos paredões, com musgo e mato.
## Medidas ao longo da queda: `al` vai da nascente para o poço, `lat` para o lado (+ do lado da coluna de pedras,
## o oposto da gruta).

const BEIRA := 3.5  # onde a água sai do alto (ao longo)
const DEGRAU_Y := 122.0  # o alto do degrau do meio
const DEGRAU_DE := 9.5  # o fundo do degrau, encostado no paredão
const DEGRAU_ATE := 25.5  # a beira da frente do degrau
const POUSO_CIMA := 14.0  # onde a queda de cima bate no degrau
const BAIXO_LAT := 4.0  # cada queda de baixo, para um lado da pedra do meio
const BAIXO_LONGE := 4.2  # quanto a queda de baixo avança até o poço
const COLUNA := Vector2(15.5, 12.0)  # o pé da coluna empilhada (ao longo, de lado)

static var _dir := Vector2.ZERO
static var _lado := Vector2.ZERO


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


static func aqui(al: float, lat: float, y: float) -> Vector3:
	var p := Vale.NASCENTE + _dir * al + _lado * lat
	return Vector3(p.x, y, p.y)


static func _dir3() -> Vector3:
	return Vector3(_dir.x, 0, _dir.y)


static func _lado3() -> Vector3:
	return Vector3(_lado.x, 0, _lado.y)


static func montar(v: Vale) -> void:
	_eixo()
	var raiz := Node3D.new()
	raiz.name = "CachoeiraAlta"
	v.add_child(raiz)
	var topo_y := v.queda_topo.y - 0.2
	_pedras(v, raiz)
	var mats := QuedaDagua.materiais(v._tex)
	var lado3 := _lado3()
	# a queda de cima: a água chega pela bacia da nascente, faz a curva na beirada e cai em arco até o degrau
	var cima := QuedaDagua.arco(aqui(BEIRA - 2.5, 0, topo_y + 0.1), aqui(BEIRA, 0, topo_y), aqui(POUSO_CIMA, 0, DEGRAU_Y + 0.3))
	QuedaDagua.queda(raiz, cima, lado3, 7.6, 9.6, 1.2, 3.6, mats, "QuedaDeCima")
	# por cima do degrau, rasa e cheia de espuma, abrindo até a beira da frente
	var rasa := PackedVector3Array()
	for k in 8:
		rasa.append(aqui(lerpf(POUSO_CIMA - 0.5, DEGRAU_ATE - 0.4, k / 7.0), 0, DEGRAU_Y + 0.32))
	QuedaDagua.fita(raiz, rasa, lado3, 9.0, 13.0, 0.12, 0.2, QuedaDagua.material_rasa(mats[0]), "AguaDoDegrau")
	# as duas quedas de baixo, uma de cada lado da pedra do meio
	var pes: Array[Vector3] = []
	for s: float in [-1.0, 1.0]:
		var lat := BAIXO_LAT * s
		var pe := aqui(DEGRAU_ATE + BAIXO_LONGE, lat * 1.1, Vale.POCO_NIVEL - 0.4)
		var baixo := QuedaDagua.arco(aqui(DEGRAU_ATE - 1.6, lat, DEGRAU_Y + 0.32), aqui(DEGRAU_ATE + 0.2, lat, DEGRAU_Y + 0.12), pe)
		QuedaDagua.queda(raiz, baixo, lado3, 4.8, 6.2, 1.0, 3.0, mats, "QuedaDeBaixo")
		pes.append(pe)
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

## O degrau de lajes empilhadas (cinco camadas, as de baixo um pouco mais à frente), a pedra do meio que divide a
## água de baixo, a coluna empilhada em pé do lado de fora da gruta, a laje da beirada por onde a água de cima faz a
## curva e pedras redondas na beira do poço. Arenito (cachoeira_pedra), mais quente que os paredões, com capim em
## cima de cada laje; tudo com colisão.
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
	# uma pedra que ocupa a caixa (lat, alto, ao longo) com o meio em `centro`
	var pedra := func(centro: Vector3, tam: Vector3, giro: float) -> void:
		var malha: ArrayMesh = malhas[rng.randi() % malhas.size()]
		var caixa := malha.get_aabb()
		var esc := Vector3(tam.x / caixa.size.x, tam.y / caixa.size.y, tam.z / caixa.size.z)
		var base := Basis(_lado3(), Vector3.UP, -_dir3()) * Basis.from_euler(Vector3(rng.randf_range(-0.04, 0.04), giro, rng.randf_range(-0.04, 0.04)))
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
	# o degrau: quatro camadas de lajes de lado a lado e, no alto, o canal (o meio 0,25 m abaixo da água e as
	# beiras levantadas, as margens)
	for ci in 4:
		var y0 := 107.4 + ci * 2.9
		var frente := DEGRAU_ATE + (4 - ci) * 0.45
		for lat: float in [-7.0, 0.0, 7.0]:
			for al: float in [DEGRAU_DE + 3.6, frente - 3.8]:
				var tam := Vector3(7.4 + rng.randf_range(-0.3, 0.5), 3.3, 7.6 + rng.randf_range(-0.3, 0.4))
				var c := aqui(al + rng.randf_range(-0.3, 0.3), lat + rng.randf_range(-0.5, 0.5), y0 + 1.65)
				pedra.call(c, tam, rng.randf_range(-0.1, 0.1))
	for dados: Array in [[-8.6, 3.6, true], [-4.0, 4.8, false], [0.0, 3.6, false], [4.0, 4.8, false], [8.6, 3.6, true]]:
		var alto := DEGRAU_Y + 1.4 if dados[2] else DEGRAU_Y - 0.25
		var y0 := 107.4 + 4 * 2.9 - 0.3
		for al: float in [DEGRAU_DE + 3.6, DEGRAU_ATE - 3.8]:
			var tam := Vector3(float(dados[1]) + rng.randf_range(-0.2, 0.3), alto - y0, 7.6 + rng.randf_range(-0.3, 0.4))
			pedra.call(aqui(al + rng.randf_range(-0.3, 0.3), float(dados[0]) + rng.randf_range(-0.2, 0.2), (y0 + alto) * 0.5), tam, rng.randf_range(-0.08, 0.08))
	# a pedra do meio, na beira da frente, entre as duas quedas de baixo
	pedra.call(aqui(DEGRAU_ATE - 0.9, 0, DEGRAU_Y + 0.7), Vector3(2.8, 2.6, 3.6), 0.2)
	# a coluna empilhada, em pé, do lado de fora da gruta: lajes cada vez menores, cada uma meio torta
	for k in 8:
		var y0 := 107.6 + k * 4.4
		var tam := Vector3(lerpf(7.0, 5.0, k / 7.0), 4.8, lerpf(7.6, 5.4, k / 7.0))
		var c := aqui(COLUNA.x + rng.randf_range(-0.6, 0.6) - k * 0.25, COLUNA.y + rng.randf_range(-0.6, 0.6), y0 + 2.4)
		pedra.call(c, tam, rng.randf_range(-0.3, 0.3))
	# a laje da beirada, por onde a água de cima faz a curva, e uma pedra de cada lado dela
	var topo := v.queda_topo.y - 0.2
	pedra.call(aqui(BEIRA - 1.0, 0, topo - 1.7), Vector3(10.4, 3.2, 5.6), 0.0)
	pedra.call(aqui(BEIRA + 0.3, -6.1, topo + 0.6), Vector3(3.4, 3.4, 4.6), 0.3)
	pedra.call(aqui(BEIRA + 0.6, 6.4, topo + 0.9), Vector3(3.8, 4.0, 4.8), -0.2)
	# pedras redondas na beira do poço (longe da saída do riacho e da boca da gruta)
	var poco := Vector2(Vale.POCO.x, Vale.POCO.y)
	for dados: Array in [[0.95, 20.0, 3.4], [1.25, 21.0, 2.6], [1.55, 19.5, 3.0], [-1.25, 20.5, 2.4], [-1.6, 19.0, 2.8]]:
		var ang: float = _dir.angle() + PI + float(dados[0])
		var r: float = dados[1]
		var p := poco + Vector2(cos(ang), sin(ang)) * r
		var tam: float = dados[2]
		var chao := v.altura(p.x, p.y)
		pedra.call(Vector3(p.x, chao + tam * 0.3, p.y), Vector3(tam * 1.2, tam * 0.9, tam), rng.randf() * TAU)
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
		var pe_lado := aqui(DEGRAU_ATE + 2.2, s * 10.0, 0.0)
		plantas.append(["q_planta_b", Vector3(pe_lado.x, v.altura(pe_lado.x, pe_lado.z), pe_lado.z), 1.4])
	for k: int in [1, 2, 3, 4, 5, 6, 7]:
		var y0 := 107.6 + k * 4.4
		var nome: String = ["q_samambaia", "arbusto", "q_planta_d"][k % 3]
		plantas.append([nome, aqui(19.0 - 0.4 * k, COLUNA.y - 1.6 + 1.2 * float(k % 2), y0 + 0.1), 1.2 if nome == "arbusto" else 1.5])
	plantas.append(["arbusto", aqui(COLUNA.x - 2.0, COLUNA.y, 107.6 + 8 * 4.4 + 0.1), 1.5])
	for dados: Array in [[BEIRA - 0.5, 8.6, "arbusto", 1.2], [BEIRA - 3.0, 7.8, "q_samambaia", 1.4], [BEIRA + 1.5, 10.5, "arbusto", 1.0]]:
		var p := aqui(float(dados[0]), float(dados[1]), 0.0)
		plantas.append([dados[2], Vector3(p.x, v.altura(p.x, p.z), p.z), dados[3]])
	plantas.append_array([["q_moita", aqui(32.0, 11.5, Vale.POCO_NIVEL + 0.4), 1.3], ["q_moita", aqui(30.5, -10.5, Vale.POCO_NIVEL + 0.4), 1.2],
		["q_moita", aqui(38.0, 15.5, Vale.POCO_NIVEL + 0.4), 1.2], ["q_samambaia", aqui(41.0, -16.0, Vale.POCO_NIVEL + 0.4), 1.4]])
	for pl: Array in plantas:
		if v._malhas.has(pl[0]):
			var p: Vector3 = pl[1]
			v._por(pl[0], Transform3D(Basis(Vector3.UP, p.x * 1.3 + p.z).scaled(Vector3.ONE * float(pl[2])), p))
