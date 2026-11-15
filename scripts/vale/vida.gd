class_name VidaVale
extends Node
## A vida espalhada pelo vale, fora da clareira: manadas de cervos, coelhos, bandos de pássaros e o cardume
## do poço da cachoeira. Os lugares são sorteados uma vez (sempre os mesmos) e os bichos de cada lugar só
## existem enquanto o robô está por perto: nascem a menos de `PERTO` e somem a mais de `LONGE`.
## Uso: VidaVale.new(), defina mapa, alvo e pintar; depois add_child.

const PERTO := 240.0
const LONGE := 320.0
const CLAREIRA_FORA := 130.0  # a clareira já tem os seus bichos
const MEIO := 930.0  # os lugares são sorteados dentro deste quadrado
const MANADAS := 14
const TOCAS := 34
const BANDOS := 18

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
	lugares.append({"tipo": "peixe", "pos": Vector3(Vale.POCO.x, Vale.POCO_NIVEL, Vale.POCO.y), "semente": 91, "quantos": 9, "nos": []})
	var n := {"cervo": 0, "coelho": 0, "passaro": 0, "peixe": 0}
	for l in lugares:
		n[l["tipo"]] += 1
	print("vida do vale: %d manadas, %d tocas de coelho, %d bandos, %d cardume" % [n["cervo"], n["coelho"], n["passaro"], n["peixe"]])


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


func _sortear(rng: RandomNumberGenerator, tipo: String, quantos: int, afastado: float, inclinacao: float, acima: float) -> void:
	var feitos: Array[Vector2] = []
	var tentativas := 0
	while feitos.size() < quantos and tentativas < quantos * 400:
		tentativas += 1
		var p := Vector2(rng.randf_range(-MEIO, MEIO), rng.randf_range(-MEIO, MEIO))
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
	for k in 6:
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
