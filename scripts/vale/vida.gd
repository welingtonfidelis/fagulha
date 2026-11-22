class_name VidaVale
extends Node
## A vida espalhada pelo vale, fora da clareira: manadas de cervos, coelhos, bandos de pássaros e o cardume
## do poço da cachoeira. Os lugares são sorteados uma vez (sempre os mesmos) e os bichos de cada lugar só
## existem enquanto o robô está por perto: nascem a menos de `PERTO` e somem a mais de `LONGE`.
## Uso: VidaVale.new(), defina mapa, alvo e pintar; depois add_child.

const PERTO := 240.0
const LONGE := 320.0
const CLAREIRA_FORA := 130.0  # a clareira já tem os seus bichos
const MEIO := 1400.0  # os lugares são sorteados dentro deste quadrado (a ilha de 3 km)
# a ilha de 3 km tem 1,7 vez a terra da de 2 km: os bichos cresceram na mesma medida
const MANADAS := 24
const TOCAS := 56
const BANDOS := 30
const RAPOSAS := 20
const ALCATEIAS := 8
# a terra nova (doc §137): os mesmos bichos da mata, menos (é mais pinheiral e montanha), e os da praia da área A
const TN_BICHOS := {"cervo": [14, 110.0, 0.93, 5.0], "coelho": [22, 60.0, 0.9, 3.0], "passaro": [14, 85.0, 0.88, 3.0],
		"raposa": [10, 120.0, 0.9, 4.0], "lobo": [5, 260.0, 0.9, 30.0]}

var mapa: Vale
var alvo: Node3D
var pintar: Callable
var lugares: Array[Dictionary] = []  # {tipo, pos, semente, quantos, nos}
var vivos := 0  # lugares com bichos agora

var _t := 0.0
var _fila := 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	_sortear(rng, "cervo", MANADAS, 110.0, 0.93, 5.0)
	_sortear(rng, "coelho", TOCAS, 60.0, 0.9, 3.0)
	_sortear(rng, "passaro", BANDOS, 85.0, 0.88, 3.0)
	_sortear(rng, "raposa", RAPOSAS, 120.0, 0.9, 4.0)
	_sortear(rng, "lobo", ALCATEIAS, 260.0, 0.9, 30.0)
	lugares.append({"tipo": "peixe", "pos": Vector3(Vale.POCO.x, Vale.POCO_NIVEL, Vale.POCO.y), "semente": 91, "quantos": 9, "nos": []})
	if mapa.terra_nova and not mapa.terra_nova.h.is_empty():
		_terra_nova(rng)
	var n := {"cervo": 0, "coelho": 0, "passaro": 0, "peixe": 0, "raposa": 0, "lobo": 0, "caranguejo": 0, "gaivota": 0, "foca": 0, "gaivota_ar": 0}
	for l in lugares:
		n[l["tipo"]] += 1
	print("vida do vale: %d manadas, %d tocas de coelho, %d bandos, %d cardume, %d raposas, %d alcateias; praia: %d de caranguejos, %d bandos de gaivotas, %d de focas, %d de gaivotas no ar" % [n["cervo"], n["coelho"], n["passaro"], n["peixe"], n["raposa"], n["lobo"], n["caranguejo"], n["gaivota"], n["foca"], n["gaivota_ar"]])


## Os bichos da terra nova: os da mata sorteados na terra dela e os da praia nos lugares que ela separou.
func _terra_nova(rng: RandomNumberGenerator) -> void:
	var tn := mapa.terra_nova
	for tipo: String in TN_BICHOS:
		var d: Array = TN_BICHOS[tipo]
		_sortear(rng, tipo, int(d[0]), d[1], d[2], d[3], true)
	for p in tn.praia_caranguejos:
		lugares.append({"tipo": "caranguejo", "pos": p, "semente": 200 + lugares.size() * 7, "quantos": rng.randi_range(3, 6), "nos": []})
	for p in tn.praia_gaivotas:
		lugares.append({"tipo": "gaivota", "pos": p, "semente": 200 + lugares.size() * 7, "quantos": rng.randi_range(5, 9), "nos": []})
	for p in tn.praia_focas:
		lugares.append({"tipo": "foca", "pos": p, "semente": 200 + lugares.size() * 7, "quantos": rng.randi_range(2, 4), "nos": []})
	for p in tn.praia_ar:
		lugares.append({"tipo": "gaivota_ar", "pos": p, "semente": 200 + lugares.size() * 7, "quantos": rng.randi_range(3, 4), "nos": []})


## Chão bom para bicho: firme, pouco inclinado, fora d'água, acima do mar, longe das ruínas e da clareira.
func chao_bom(x: float, z: float, inclinacao: float, acima_do_mar: float) -> bool:
	if Vector2(x, z).length() < CLAREIRA_FORA:
		return false
	var h := mapa.altura(x, z)
	if h < Vale.MAR + acima_do_mar or mapa.agua(x, z) > -INF:
		return false
	if mapa.normal_em(x, z).y < inclinacao or not Ruinas.livre(x, z) or Cavernas.dentro(x, z, 10.0):
		return false
	# nada de beira de paredão: os vizinhos também têm de ser chão
	for d: Vector2 in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
		if mapa.normal_em(x + d.x, z + d.y).y < inclinacao - 0.08 or mapa.agua(x + d.x, z + d.y) > -INF:
			return false
	return true


func _sortear(rng: RandomNumberGenerator, tipo: String, quantos: int, afastado: float, inclinacao: float, acima: float, na_terra_nova := false) -> void:
	var feitos: Array[Vector2] = []
	var tentativas := 0
	while feitos.size() < quantos and tentativas < quantos * 400:
		tentativas += 1
		var p := Vector2(rng.randf_range(-MEIO, MEIO), rng.randf_range(-MEIO, MEIO))
		if na_terra_nova:
			p = Vector2(rng.randf_range(TerraNova.X0, 1500.0), rng.randf_range(TerraNova.Z0, 1500.0))
			if not mapa._na_terra_nova(p.x, p.y) or mapa.altura(p.x, p.y) > 380.0:
				continue
		if not chao_bom(p.x, p.y, inclinacao, acima):
			continue
		var livre := true
		for q in feitos:
			if q.distance_to(p) < afastado:
				livre = false
				break
		if not livre:
			continue
		feitos.append(p)
		var n := 1
		match tipo:
			"cervo":
				n = rng.randi_range(2, 4)
			"coelho":
				n = rng.randi_range(1, 3)
			"passaro":
				n = rng.randi_range(4, 8)
			"lobo":
				n = rng.randi_range(2, 3)
		lugares.append({"tipo": tipo, "pos": Vector3(p.x, mapa.altura(p.x, p.y), p.y), "semente": 200 + lugares.size() * 7, "quantos": n, "nos": []})


func _process(delta: float) -> void:
	if alvo == null or lugares.is_empty():
		return
	_t += delta
	if _t < 0.1:
		return
	_t = 0.0
	# olha uns poucos lugares por vez, para não criar muitos bichos no mesmo quadro
	var a := alvo.global_position
	for k in 10:
		_fila = (_fila + 1) % lugares.size()
		var l := lugares[_fila]
		var p: Vector3 = l["pos"]
		var d := Vector2(a.x - p.x, a.z - p.z).length()
		var nos: Array = l["nos"]
		if nos.is_empty() and d < PERTO:
			_criar(l)
			vivos += 1
			break
		elif not nos.is_empty() and d > LONGE:
			for n: Node in nos:
				if is_instance_valid(n):
					n.queue_free()
			nos.clear()
			vivos -= 1


func _criar(l: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(l["semente"])
	var p: Vector3 = l["pos"]
	var nos: Array = l["nos"]
	match l["tipo"]:
		"cervo":
			for i in int(l["quantos"]):
				var q := _perto(rng, p, 9.0)
				var cervo := Cervo.new()
				cervo.mapa = mapa
				cervo.ameaca = alvo
				cervo.casa = q
				cervo.raio_casa = 34.0
				cervo.semente = int(l["semente"]) + i
				cervo.position = q
				add_child(cervo)
				if pintar.is_valid():
					pintar.call(cervo)
				nos.append(cervo)
		"raposa", "lobo":
			for i in int(l["quantos"]):
				var q := _perto(rng, p, 7.0)
				var bicho: Cervo = Raposa.new() if l["tipo"] == "raposa" else Lobo.new()
				bicho.mapa = mapa
				bicho.ameaca = alvo
				bicho.casa = q
				bicho.raio_casa = 45.0
				bicho.semente = int(l["semente"]) + i
				bicho.position = q
				add_child(bicho)
				nos.append(bicho)
		"coelho":
			for i in int(l["quantos"]):
				var q := _perto(rng, p, 4.0)
				var coelho := Coelho.new()
				coelho.mapa = mapa
				coelho.ameaca = alvo
				coelho.casa = q
				coelho.semente = int(l["semente"]) + i
				add_child(coelho)
				if pintar.is_valid():
					pintar.call(coelho)
				nos.append(coelho)
		"passaro":
			var bando := Passaros.new()
			bando.mapa = mapa
			bando.ameaca = alvo
			bando.casa = p
			bando.quantos = int(l["quantos"])
			bando.semente = int(l["semente"])
			bando.pintar = pintar
			add_child(bando)
			nos.append(bando)
		"caranguejo":
			var c := Caranguejos.new()
			c.mapa = mapa
			c.ameaca = alvo
			c.casa = p
			c.quantos = int(l["quantos"])
			c.semente = int(l["semente"])
			c.materiais = mapa
			add_child(c)
			nos.append(c)
		"foca":
			var f := Focas.new()
			f.mapa = mapa
			f.ameaca = alvo
			f.casa = p
			f.quantos = int(l["quantos"])
			f.semente = int(l["semente"])
			f.materiais = mapa
			add_child(f)
			nos.append(f)
		"gaivota":
			# um bando pousado na areia: o mesmo bando dos passarinhos, maior, de asa lenta e só na praia
			var m := mapa
			var g := Passaros.new()
			g.mapa = mapa
			g.ameaca = alvo
			g.casa = p
			g.quantos = int(l["quantos"])
			g.semente = int(l["semente"])
			g.escala = 3.0
			g.freq = 3.4
			g.pintar = func(no: Node) -> void: Gaivotas.pintar_gaivota(no, m)
			g.chao_ok = func(x: float, z: float) -> bool:
				var cb := m.cobertura(x, z)
				return (cb == 4 or cb == 9) and m.altura(x, z) > 0.4
			add_child(g)
			nos.append(g)
		"gaivota_ar":
			var ga := Gaivotas.new()
			ga.mapa = mapa
			ga.casa = p
			ga.quantos = int(l["quantos"])
			ga.semente = int(l["semente"])
			ga.materiais = mapa
			add_child(ga)
			nos.append(ga)
		"peixe":
			var peixes := Peixes.new()
			peixes.mapa = mapa
			peixes.ameaca = alvo
			peixes.centro = Vector3(p.x, 0, p.z)
			peixes.raio = Vale.POCO.z - 3.0
			peixes.quantos = int(l["quantos"])
			peixes.semente = int(l["semente"])
			peixes.pintar = pintar
			add_child(peixes)
			nos.append(peixes)


func _perto(rng: RandomNumberGenerator, p: Vector3, raio: float) -> Vector3:
	for k in 12:
		var x := p.x + rng.randf_range(-raio, raio)
		var z := p.z + rng.randf_range(-raio, raio)
		if mapa.agua(x, z) == -INF and mapa.normal_em(x, z).y > 0.85:
			return Vector3(x, mapa.altura(x, z), z)
	return p


## Quantos bichos de um tipo existem agora (testes).
func contar(tipo: String) -> int:
	var n := 0
	for l in lugares:
		if l["tipo"] == tipo:
			n += (l["nos"] as Array).size()
	return n
