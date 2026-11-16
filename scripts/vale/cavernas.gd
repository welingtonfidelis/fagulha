class_name Cavernas
extends RefCounted
## Cavernas do vale: túneis que atravessam os morros. O relevo é uma grade de alturas e não aceita teto,
## então cada caverna é um rasgo cavado na grade (o chão e as paredes) coberto por um teto de rocha feito
## à parte, com o arco por baixo e o chão de cima refeito por cima. Os lugares são achados no próprio
## relevo. Há dois tipos: o túnel (linha de 70 a 150 m com as duas pontas baixas e um morro no meio) e a
## gruta sem saída (linha de 45 a 80 m que entra numa encosta, com o chão plano).
## `cavar` roda antes de o chão ser montado; `montar`, depois dos paredões.
## Desde 2026-11-15 cada gruta é uma peça de RochaMalha (como o Sumidouro): corredor com curvas, paredes
## de pedra e, nas sem saída, um salão no fundo com claraboia.

const MEIA := 7.0  # metade da largura do chão do túnel
const PAREDE := 5.0  # em quantos metros a parede sobe até o chão de fora
const ALTO := 7.5  # altura do arco no meio
const QUANTAS := 6
const TUNEIS := 2  # no máximo; o resto são grutas sem saída
const NOMES := ["Passagem da Serra", "Gruta do Eco", "Gruta dos Cristais", "Toca Funda", "Gruta da Lua", "Boca Verde"]
const CORES := [Color(0.3, 0.95, 0.85), Color(1.0, 0.72, 0.3), Color(0.55, 0.7, 1.0), Color(0.75, 1.0, 0.5)]

static var lista: Array[Dictionary] = []  # {a, b, ha, hb, comp, de, ate, nome}
static var _orig := PackedFloat32Array()


## O chão de antes de cavar, em qualquer ponto (a mesma conta de Vale._fora).
static func chao_antes(x: float, z: float) -> float:
	var fx := clampf((x + Vale.F_META) / Vale.F_PASSO, 0.0, Vale.F_N - 1.001)
	var fz := clampf((z + Vale.F_META) / Vale.F_PASSO, 0.0, Vale.F_N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var i := iz * Vale.F_N + ix
	return lerpf(lerpf(_orig[i], _orig[i + 1], fx - ix), lerpf(_orig[i + Vale.F_N], _orig[i + Vale.F_N + 1], fx - ix), fz - iz)


## Vector2(distância até o eixo, posição ao longo dele de 0 a 1) para a caverna `c`.
static func _eixo(c: Dictionary, x: float, z: float) -> Vector2:
	var a: Vector2 = c["a"]
	var ab: Vector2 = (c["b"] as Vector2) - a
	var t := clampf((Vector2(x, z) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(Vector2(x, z).distance_to(a + ab * t), t)


## Dentro do rasgo de alguma caverna (com folga): ali não nasce árvore nem rocha de paredão.
static func dentro(x: float, z: float, folga := 4.0) -> bool:
	if RochaMalha.dentro(x, z, folga):
		return true
	for c in lista:
		if _eixo(c, x, z).x < MEIA + PAREDE + folga:
			return true
	return false


static func cavar(v: Vale) -> void:
	lista.clear()
	Sumidouro.existe = false
	_orig = v._fora_h.duplicate()
	RochaMalha.preparar(v)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	var lado := MEIA + PAREDE
	var tentativas := 0
	var tuneis := 0
	var t_ini := Time.get_ticks_msec()
	while lista.size() < QUANTAS and tentativas < 120000:
		tentativas += 1
		var gruta := tentativas > 30000 or tuneis >= TUNEIS
		var a := Vector2(rng.randf_range(-860, 860), rng.randf_range(-860, 860))
		var ang := rng.randf() * TAU
		var comp := rng.randf_range(45.0, 80.0) if gruta else rng.randf_range(70.0, 150.0)
		var b := a + Vector2(cos(ang), sin(ang)) * comp
		if maxf(absf(b.x), absf(b.y)) > 840.0 or a.length() < 240.0 or b.length() < 240.0:
			continue
		var ha := chao_antes(a.x, a.y)
		var hb := ha if gruta else chao_antes(b.x, b.y)
		if ha < 5.0 or hb < 5.0 or absf(ha - hb) > 22.0:
			continue
		var longe := true
		for c in lista:
			if ((c["a"] as Vector2) + (c["b"] as Vector2)).distance_to(a + b) * 0.5 < 200.0:
				longe = false
		if not longe:
			continue
		var dir := (b - a) / comp
		var perp := Vector2(-dir.y, dir.x)
		var serve := true
		var fim := comp + (lado + 3.0 if gruta else 0.0)  # a gruta precisa de morro também além do fundo
		var n := int(fim / 6.0)
		for i in n + 1:
			var sv := fim * float(i) / n
			var t := sv / comp
			var p := a + dir * sv
			var chao := lerpf(ha, hb, minf(t, 1.0))
			var coberto := t > 0.42 if gruta else (t > 0.3 and t < 0.7)
			for u: float in [0.0, -lado, lado]:
				var q := p + perp * u
				var folga := chao_antes(q.x, q.y) - chao
				if folga < -1.5 or (coberto and folga < 11.5):
					serve = false
					break
			if not serve or v.agua(p.x, p.y) > -INF or not Ruinas.livre(p.x, p.y):
				serve = false
				break
		if not serve:
			continue
		if not gruta:
			tuneis += 1
		lista.append({"a": a, "b": b, "ha": ha, "hb": hb, "comp": comp, "de": 0.0, "ate": 0.0, "gruta": gruta, "nome": NOMES[lista.size() % NOMES.size()]})
	# cada gruta ganha a caixa dela, o trecho coberto, e a grade é rebaixada debaixo do vazio
	var k := 0
	for c in lista:
		c["i"] = k
		k += 1
		_limites(c)
		RochaMalha.rebaixar(c["mn"], c["mx"], vazio_de.bind(c))
	print("cavernas: %d lugares (%d tentativas, %d ms)" % [lista.size(), tentativas, Time.get_ticks_msec() - t_ini])
	for c in lista:
		print("  %s (%s): de %s a %s, %.0f m, chão de %.0f a %.0f m, coberta de %.0f a %.0f m" % [c["nome"], "gruta" if c["gruta"] else "túnel", c["a"], c["b"], c["comp"], c["ha"], c["hb"], c["de"], c["ate"]])


static func arquivo(c: Dictionary) -> String:
	return "res://assets/vale/gruta_%d.res" % int(c["i"])


## A caixa da peça e o trecho coberto ("de" e "ate", ao longo do eixo): onde o morro passa 3 m do arco.
static func _limites(c: Dictionary) -> void:
	var a: Vector2 = c["a"]
	var b: Vector2 = c["b"]
	var comp: float = c["comp"]
	var dir := (b - a) / comp
	var folga := MEIA + PAREDE + 12.0
	var mn := a.min(b) - Vector2.ONE * folga
	var mx := a.max(b) + Vector2.ONE * folga
	var alto := RochaMalha.alto_da_caixa(mn, mx)
	c["mn"] = Vector3(mn.x, minf(c["ha"], c["hb"]) - 5.0, mn.y)
	c["mx"] = Vector3(mx.x, alto + 5.0, mx.y)
	var de := -1.0
	var ate := 0.0
	var sv := 0.0
	while sv <= comp:
		var p := a + dir * sv
		if chao_antes(p.x, p.y) - lerpf(c["ha"], c["hb"], sv / comp) > ALTO + 3.0:
			if de < 0.0:
				de = sv
			ate = sv
		sv += 2.0
	c["de"] = maxf(de, 0.0)
	c["ate"] = ate


## Quanto o corredor sai da linha reta em cada ponto do eixo: curvas largas, que somem nas bocas.
static func _curva(c: Dictionary, sv: float) -> float:
	var comp: float = c["comp"]
	var janela := smoothstep(0.0, 20.0, sv)
	if not c["gruta"]:
		janela *= smoothstep(0.0, 20.0, comp - sv)
	return sin(sv / comp * PI * (2.0 if comp > 90.0 else 1.5) + float(c["i"]) * 1.7) * (2.6 if not c["gruta"] else 3.6) * janela


## O vazio de uma gruta: um corredor de piso chato que serpenteia, mais largo e mais alto em alguns
## trechos; onde o morro por cima é fino, vira um rasgo aberto (a boca). A gruta sem saída termina num
## salão redondo com uma claraboia.
static func vazio_de(p: Vector3, c: Dictionary) -> float:
	var a: Vector2 = c["a"]
	var comp: float = c["comp"]
	var dir := ((c["b"] as Vector2) - a) / comp
	var q := Vector2(p.x, p.z) - a
	var sv := q.dot(dir)
	var u0 := q.dot(Vector2(-dir.y, dir.x))
	if absf(u0) > 34.0 or sv < -30.0 or sv > comp + 30.0:
		return 20.0
	var u := u0 - _curva(c, clampf(sv, 0.0, comp))
	var chao := lerpf(c["ha"], c["hb"], clampf(sv / comp, 0.0, 1.0))
	var h := p.y - chao
	var semente := float(c["i"]) * 31.0
	var larg := MEIA + RochaMalha.ruido.get_noise_2d(sv * 0.9, semente) * 2.2
	var alt := ALTO + RochaMalha.ruido.get_noise_2d(semente + 50.0, sv * 0.9) * 2.0
	var fora := maxf(maxf(-sv, sv - comp), 0.0)  # além das pontas, o corredor fecha arredondado
	var n := RochaMalha.parede(p)
	var n2 := RochaMalha.piso(p)
	var tubo := (Vector3(u / larg, h / alt, fora / larg).length() - 1.0) * minf(larg, alt)
	# morro fino por cima: rasgo aberto, de paredes em pé
	var cobre := chao_antes(p.x, p.z) - chao - alt
	if cobre < 3.0:
		tubo = minf(tubo, Vector2(maxf(absf(u) - larg * 0.95, 0.0), fora).length() - 0.5)
	var d := maxf(tubo + n, chao + n2 - p.y)
	if c["gruta"]:
		# salão no fundo, com a claraboia
		var e := Vector3((sv - comp + 9.0) / 13.0, (h - 6.5) / 9.5, u / 12.5)
		d = minf(d, maxf((e.length() - 1.0) * 9.5 + n, chao + n2 - p.y))
		var furo := Vector2(sv - comp + 9.0, u).length() - 2.6 + n * 0.5
		d = minf(d, maxf(furo, chao + 6.0 - p.y))
	return d


## Gera de novo as malhas das grutas (a pedido: `-- --assar-rochas`).
static func assar() -> void:
	for c in lista:
		RochaMalha.assar(c["mn"], c["mx"], vazio_de.bind(c), Callable(), arquivo(c), _chave(c))


static func _chave(c: Dictionary) -> Vector3:
	var a: Vector2 = c["a"]
	return Vector3(a.x, c["ha"], a.y)


static func montar(v: Vale) -> void:
	var t0 := Time.get_ticks_msec()
	var k := 0
	for c in lista:
		if RochaMalha.montar(arquivo(c), "Gruta%d" % k, _chave(c)):
			_enfeites(v, c, CORES[k % CORES.size()], 700 + k)
		k += 1
	print("cavernas: %d grutas montadas, %d ms" % [lista.size(), Time.get_ticks_msec() - t0])




## Cristais acesos ao pé das paredes, alternando os lados (iluminam e mostram o caminho), um grupo maior
## no salão do fundo, e estalactites.
static func _enfeites(v: Vale, c: Dictionary, cor: Color, semente: int) -> void:
	if float(c["ate"]) <= float(c["de"]):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var a: Vector2 = c["a"]
	var comp: float = c["comp"]
	var dir := ((c["b"] as Vector2) - a) / comp
	var perp := Vector2(-dir.y, dir.x)
	var vaz := vazio_de.bind(c)
	var altura_em := func(xz: Vector2) -> float:
		return lerpf(c["ha"], c["hb"], clampf((xz - a).dot(dir) / comp, 0.0, 1.0)) + 2.5
	var sv := float(c["de"]) + 5.0
	var lado := 1.0
	while sv < float(c["ate"]) - 3.0:
		var xz := a + dir * sv + perp * (_curva(c, sv) + lado * (MEIA - 2.6))
		var pt := RochaMalha.piso_teto(xz.x, xz.y, altura_em.call(xz), vaz, Callable())
		if pt.x != INF:
			RochaMalha.cristal(Vector3(xz.x, pt.x, xz.y), cor, rng, 0.8)
		lado = -lado
		sv += 15.0
	if c["gruta"]:
		var xz := a + dir * (comp - 4.0) + perp * (_curva(c, comp) + 5.0)
		var pt := RochaMalha.piso_teto(xz.x, xz.y, altura_em.call(xz), vaz, Callable())
		if pt.x != INF:
			RochaMalha.cristal(Vector3(xz.x, pt.x, xz.y), cor.lerp(Color.WHITE, 0.3), rng, 1.3)
	var pontos: Array[Vector2] = []
	for i in int(comp * 1.2):
		var s2 := rng.randf_range(float(c["de"]) + 2.0, comp + (4.0 if c["gruta"] else -2.0))
		pontos.append(a + dir * s2 + perp * (_curva(c, minf(s2, comp)) + rng.randf_range(-10.0, 10.0)))
	RochaMalha.pingentes(pontos, altura_em, vaz, Callable(), semente + 40)
