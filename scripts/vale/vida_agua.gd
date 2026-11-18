class_name VidaAgua
extends Node3D
## A vida debaixo d'água (2026-11-18, pedido do usuário: com mais lugares para explorar nadando, o fundo
## precisava de plantas e peixes). Duas partes:
## - o fundo plantado: algas, corais e pedras no mar raso, nas piscinas naturais e na lagoa da represa,
##   desenhados em lote e só de perto;
## - cardumes de fundo: peixes coloridos que nadam em volta de um ponto, a meia água, e fogem do robô. Como
##   os bichos de terra, só existem enquanto o robô está por perto.
## (Os peixes de superfície, que saltam, continuam sendo os de `Peixes`.)

const PERTO := 150.0
const LONGE := 210.0
const CARDUMES := 70
const PEIXES_POR_CARDUME := 18
const CORES: Array[Color] = [Color(0.95, 0.5, 0.12), Color(0.95, 0.82, 0.2), Color(0.25, 0.6, 0.9), Color(0.75, 0.8, 0.85), Color(0.9, 0.3, 0.35), Color(0.3, 0.8, 0.7)]

var mapa: Vale
var alvo: Node3D
var lugares: Array[Dictionary] = []  # {pos, semente, cor, no}
var plantas := 0
var vivos := 0

var _malha_peixe: Mesh
var _fila := 0
var _t := 0.0


## Água funda o bastante para nadar ali: devolve o nível, ou -INF.
func _agua_boa(x: float, z: float, fundo_min: float) -> float:
	var nivel := mapa.agua(x, z)
	if nivel == -INF or nivel - mapa.altura(x, z) < fundo_min:
		return -INF
	return nivel


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_plantar()
	_sortear()
	var cena := load("res://assets/vale/peixe.glb") as PackedScene
	if cena:
		var inst := cena.instantiate()
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			_malha_peixe = (n as MeshInstance3D).mesh
			break
		inst.free()
	print("vida na água: %d plantas e pedras de fundo, %d cardumes, %d ms" % [plantas, lugares.size(), Time.get_ticks_msec() - t0])


## O fundo: algas altas, plantas baixas, corais (cogumelos grandes, coloridos pela cor do material) e pedras.
func _plantar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8128
	var por_tipo := {}
	var passo := 7.0
	var z := -Vale.F_META + 6.0
	while z < Vale.F_META - 6.0:
		var x := -Vale.F_META + 6.0
		while x < Vale.F_META - 6.0:
			var px := x + rng.randf_range(-3.0, 3.0)
			var pz := z + rng.randf_range(-3.0, 3.0)
			var sorte := rng.randf()
			var giro := rng.randf() * TAU
			var tam := rng.randf()
			x += passo
			var h := mapa.altura(px, pz)
			# só onde há água por cima e o fundo não é o chão liso do mar aberto (lá ninguém mergulha)
			if h > -0.7 and mapa.agua(px, pz) == -INF:
				continue
			var nivel := mapa.agua(px, pz)
			if nivel == -INF or nivel - h < 0.7 or h < -12.5:
				continue
			# manchas: uns trechos cheios, outros quase vazios
			var mancha := sin(px * 0.031 + 1.7) * cos(pz * 0.027 - 0.4) + sin(px * 0.011 - pz * 0.013)
			if sorte > 0.55 + mancha * 0.25:
				continue
			var fundura := nivel - h
			var nome := ""
			var escala := 1.0
			var q := fposmod(sorte * 37.0, 1.0)
			if q < 0.34:
				nome = "q_samambaia"  # alga alta: cresce com a fundura
				escala = lerpf(1.6, 4.2, tam) * clampf(fundura / 4.0, 0.5, 1.4)
			elif q < 0.55:
				nome = "q_planta_c"
				escala = lerpf(1.4, 2.8, tam)
			elif q < 0.7:
				nome = "q_planta_a"
				escala = lerpf(1.2, 2.4, tam)
			elif q < 0.82:
				nome = "q_cogumelo"  # coral
				escala = lerpf(1.6, 3.6, tam)
			elif q < 0.93:
				nome = "q_pedra_b" if tam < 0.5 else "q_pedra_c"
				escala = lerpf(0.9, 2.2, tam)
			else:
				nome = "q_seixo_a"
				escala = lerpf(1.5, 3.0, tam)
			if not mapa._malhas.has(nome):
				continue
			var chave := "%s|%d|%d" % [nome, floori(px / 120.0), floori(pz / 120.0)]
			if not por_tipo.has(chave):
				por_tipo[chave] = [nome, []]
			((por_tipo[chave] as Array)[1] as Array).append(Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * escala), Vector3(px, h - 0.08, pz)))
			plantas += 1
		z += passo
	for chave: String in por_tipo:
		var par: Array = por_tipo[chave]
		var xfs: Array = par[1]
		mapa._multi(par[0], xfs, mapa._centro(xfs), 0.0, 130.0, false)


## Os lugares dos cardumes: água com pelo menos 2,5 m, perto da costa, das ilhotas, do cais e do navio.
func _sortear() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4096
	var fixos: Array[Vector2] = [Vector2(MarcosMar.CAIS.x + 60.0, MarcosMar.CAIS.y + 24.0), Vector2(MarcosMar.CAIS.x + 100.0, MarcosMar.CAIS.y + 36.0),
		Vector2(MarcosMar.RELE.x - 70.0, MarcosMar.RELE.y), Vector2(MarcosOeste.CASCO.x - 30.0, MarcosOeste.CASCO.y + 16.0),
		Vector2(Vale.REPRESA_LAGOA.x, Vale.REPRESA_LAGOA.y), Vector2(Vale.REPRESA_LAGOA.x + 40.0, Vale.REPRESA_LAGOA.y - 20.0)]
	var feitos: Array[Vector2] = []
	for f: Vector2 in fixos:
		if _agua_boa(f.x, f.y, 2.5) > -INF:
			feitos.append(f)
	var tentativas := 0
	while feitos.size() < CARDUMES and tentativas < CARDUMES * 300:
		tentativas += 1
		var p := Vector2(rng.randf_range(-Vale.F_META + 40.0, Vale.F_META - 40.0), rng.randf_range(-Vale.F_META + 40.0, Vale.F_META - 40.0))
		if _agua_boa(p.x, p.y, 2.5) == -INF or mapa.altura(p.x, p.y) < -12.5:
			continue
		var livre := true
		for q in feitos:
			if q.distance_to(p) < 70.0:
				livre = false
				break
		if livre:
			feitos.append(p)
	for i in feitos.size():
		var p2 := feitos[i]
		var nivel := mapa.agua(p2.x, p2.y)
		var fundo := mapa.altura(p2.x, p2.y)
		lugares.append({"pos": Vector3(p2.x, lerpf(fundo, nivel, 0.45), p2.y), "nivel": nivel, "fundo": fundo, "semente": 300 + i * 7, "cor": CORES[i % CORES.size()], "no": null, "peixes": []})


func _process(delta: float) -> void:
	if alvo == null or lugares.is_empty():
		return
	_t += delta
	var a := alvo.global_position
	# uns poucos lugares por quadro: nasce perto, some longe
	for k in 4:
		_fila = (_fila + 1) % lugares.size()
		var l := lugares[_fila]
		var d := Vector2(a.x - (l["pos"] as Vector3).x, a.z - (l["pos"] as Vector3).z).length()
		if l["no"] == null and d < PERTO:
			_criar(l)
			vivos += 1
		elif l["no"] != null and d > LONGE:
			(l["no"] as Node).queue_free()
			l["no"] = null
			l["peixes"] = []
			vivos -= 1
	# os cardumes vivos nadam
	for l: Dictionary in lugares:
		if l["no"] == null:
			continue
		var mm := (l["no"] as MultiMeshInstance3D).multimesh
		var centro: Vector3 = l["pos"]
		var teto := float(l["nivel"]) - 0.5
		var piso := float(l["fundo"]) + 0.5
		var peixes: Array = l["peixes"]
		for i in peixes.size():
			var px: Dictionary = peixes[i]
			var fase := float(px["fase"]) + _t * float(px["vel"])
			# cada peixe dá voltas no seu raio, subindo e descendo, e o cardume inteiro deriva devagar
			var alvo_p := centro + Vector3(cos(fase) * float(px["raio"]), sin(fase * 0.7 + float(px["fase"])) * float(px["sobe"]), sin(fase * 1.13) * float(px["raio"]))
			alvo_p += Vector3(sin(_t * 0.07 + float(l["semente"])), 0, cos(_t * 0.05 + float(l["semente"]))) * 6.0
			var pos: Vector3 = px["pos"]
			var foge := pos - a
			var vel_alvo := (alvo_p - pos).limit_length(1.0) * 1.6
			if foge.length() < 6.0:
				vel_alvo = foge.normalized() * 7.0  # o robô chegou: dispara para longe
				px["susto"] = 1.0
			var vel: Vector3 = (px["v"] as Vector3).lerp(vel_alvo, 1.0 - exp(-(5.0 if float(px["susto"]) > 0.0 else 2.2) * delta))
			px["susto"] = maxf(0.0, float(px["susto"]) - delta)
			pos += vel * delta
			pos.y = clampf(pos.y, piso, teto)
			px["v"] = vel
			px["pos"] = pos
			var frente := vel if vel.length() > 0.05 else Vector3.FORWARD
			# o modelo olha para +Z; a cauda balança virando o corpo um pouco de lado
			var base := Basis.looking_at(-frente.normalized(), Vector3.UP) * Basis(Vector3.UP, sin(_t * 9.0 + float(px["fase"]) * 5.0) * 0.18)
			mm.set_instance_transform(i, Transform3D(base.scaled(Vector3.ONE * float(px["tam"])), pos - (l["no"] as Node3D).global_position))


func _criar(l: Dictionary) -> void:
	if _malha_peixe == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(l["semente"])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _malha_peixe
	mm.instance_count = PEIXES_POR_CARDUME
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mapa._solido(l["cor"])
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	add_child(mmi)
	mmi.global_position = l["pos"]
	var peixes: Array = []
	var altura_agua := float(l["nivel"]) - float(l["fundo"])
	for i in PEIXES_POR_CARDUME:
		var raio := rng.randf_range(1.5, 6.0)
		var fase := rng.randf() * TAU
		peixes.append({"raio": raio, "fase": fase, "vel": rng.randf_range(0.25, 0.6) * (1.0 if i % 3 != 0 else -1.0), "sobe": rng.randf_range(0.2, 0.45) * altura_agua * 0.5,
			"tam": rng.randf_range(2.6, 5.0), "pos": (l["pos"] as Vector3) + Vector3(cos(fase) * raio, 0, sin(fase) * raio), "v": Vector3.ZERO, "susto": 0.0})
	l["peixes"] = peixes
	l["no"] = mmi
