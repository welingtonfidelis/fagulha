class_name Vilarejo
extends RefCounted
## O Vilarejo (terra nova, área A, 2026-11-22, doc §137.10): uma vila pequena de casas de laje em volta de uma
## caixa d'água, largada há muito tempo. As peças vêm prontas do Blender (tools/arte/vilarejo_vila1.py: uma malha
## pintada por casa ou por área, em assets/vale/vilarejo/); aqui elas só vão para o lugar, no platô que o mapa
## aplainou (tools/vale/mapa_mundo.py), com o shader do vale e a colisão da própria malha. Do desenho vêm também,
## em vila.json, as árvores e as moitas (que viram plantas do jogo), as casas (caixas para os bichos desviarem)
## e o chão calçado (chao.bin), que tira o capim de cima da rua, da praça e de dentro das casas e o deixa ralo em
## volta, para os restos da rua aparecerem (`calcado`).
## As coordenadas do Blender (x, y, z) viram (x, z, −y) aqui, giradas por RUMO em volta do meio da praça.

const NOME := "O Vilarejo"
const CENTRO := Vector2(-756.0, -2592.0)  # o meio da praça; o mesmo de tools/vale/mapa_mundo.py
const RUMO := 0.0
const RAIO := 56.0  # até onde vão as casas: bicho e planta solta ficam fora
const PASTA := "res://assets/vale/vilarejo/"
const PECAS := ["torre", "praca", "ruas", "ruela_pedra", "casa_a", "casa_b", "casa_c", "casa_d", "casa_e", "casa_f",
		"casa_g", "casa_h", "casa_i", "escola", "oficina", "estufa", "energia", "hortas", "parquinho", "postes_luz",
		"entulho", "hastes"]
const SOME_EM := {"entulho": 320.0, "hortas": 380.0, "parquinho": 380.0}  # o miúdo some de longe

static var montado := false
static var chao_y := 0.0
static var _info := {}
static var _chao := PackedByteArray()
static var _chao_n := 0
static var _chao_passo := 0.5
static var _chao_meia := 64.0
static var _mats := {}


static func montar(v: Vale) -> void:
	var t0 := Time.get_ticks_msec()
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "vila.json"))
	if not (info is Dictionary):
		push_warning("vilarejo: sem vila.json")
		return
	_info = info
	var c: Dictionary = _info["chao"]
	_chao = FileAccess.get_file_as_bytes(PASTA + String(c["arquivo"]))
	_chao_n = int(c["n"])
	_chao_passo = float(c["passo"])
	_chao_meia = float(c["meia"])
	chao_y = v.altura(CENTRO.x, CENTRO.y)
	var xf := _xf()
	var raiz := Node3D.new()
	raiz.name = "Vilarejo"
	raiz.transform = xf
	v.add_child(raiz)
	var corpo := StaticBody3D.new()
	corpo.name = "VilarejoCorpo"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	corpo.transform = xf
	v.add_child(corpo)
	var tris := 0
	for nome: String in PECAS:
		var cena := load(PASTA + nome + ".glb") as PackedScene
		if cena == null:
			push_warning("vilarejo: falta %s.glb" % nome)
			continue
		var no := cena.instantiate() as Node3D
		no.name = nome
		raiz.add_child(no)
		var faces := PackedVector3Array()
		for mi: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
			_pintar(v, mi)
			if SOME_EM.has(nome):
				mi.visibility_range_end = SOME_EM[nome]
				mi.visibility_range_end_margin = 30.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			var rel := _relativo(raiz, mi)
			for p in mi.mesh.get_faces():
				faces.append(rel * p)
		if faces.is_empty():
			continue
		var forma := ConcavePolygonShape3D.new()
		forma.backface_collision = true  # paredes de uma chapa só, lajes caídas: bate dos dois lados
		forma.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.name = nome
		cs.shape = forma
		corpo.add_child(cs)
		tris += faces.size() / 3
	# as moitas e as trepadeiras do desenho viram a moita do jogo, do tamanho que tinham (umas com flor)
	var moitas := 0
	var largura := _largura_modelo(v, "q_moita")
	if largura > 0.1:
		for mo: Dictionary in _info.get("moitas", []):
			var p := no_mundo(mo["p"])
			var u := Clareira.sorte_do_lugar(p.x, p.z)
			var s := 2.5 * float(mo["r"]) / largura
			var nome_m := "q_moita_flor" if u < 0.2 and v._malhas.has("q_moita_flor") else "q_moita"
			v._por(nome_m, Transform3D(Basis(Vector3.UP, u * TAU).scaled(Vector3.ONE * s), p))
			moitas += 1
	# as casas, a caixa d'água, a estufa e a energia: caixas para os bichos sem física não atravessarem
	for o: Dictionary in _info["obstaculos"]:
		var oc: Array = o["c"]
		var tam: Array = o["tam"]
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(float(tam[0]), float(tam[2]), float(tam[1]))
		var meio := xf * Vector3(float(oc[0]), float(tam[2]) * 0.5, -float(oc[1]))
		Obstaculos.registrar_forma(caixa, Transform3D(xf.basis * Basis(Vector3.UP, deg_to_rad(float(o["giro"]))), meio), chao_y)
	montado = true
	print("vilarejo em %s: %d peças, %d moitas, colisão com %d triângulos, %d ms" % [Vector3(CENTRO.x, chao_y, CENTRO.y), raiz.get_child_count(), moitas, tris, Time.get_ticks_msec() - t0])


## Do desenho para o mundo: a praça no meio do platô, girada por RUMO.
static func _xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, RUMO), Vector3(CENTRO.x, chao_y, CENTRO.y))


## Um ponto do desenho (Blender: x, y, z) no mundo.
static func no_mundo(p: Array) -> Vector3:
	return _xf() * Vector3(float(p[0]), float(p[2]), -float(p[1]))


static func _relativo(ate: Node, no: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = no
	while n != ate and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## O shader do vale: a textura assada de cada malha (a sujeira, os escorridos e as bordas gastas já vêm nela), ou
## a cor chapada do material onde não há textura (as hastes dos postes).
static func _pintar(v: Vale, mi: MeshInstance3D) -> void:
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
		var chave := "nada"
		if m and m.albedo_texture:
			chave = "tex|%d" % m.albedo_texture.get_instance_id()
		elif m:
			chave = "cor|" + m.albedo_color.to_html()
		if not _mats.has(chave):
			var sm := ShaderMaterial.new()
			sm.shader = load("res://scripts/shaders/vale_base.gdshader")
			sm.set_shader_parameter("ruido", v._tex)
			if m and m.albedo_texture:
				sm.set_shader_parameter("tex", m.albedo_texture)
			elif m:
				sm.set_shader_parameter("tinta", Vector3(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b))
			_mats[chave] = sm
		mi.set_surface_override_material(s, _mats[chave])


## As árvores do desenho como árvores do jogo (no formato da fila de `TerraNova.plantar`): os pinheiros do pacote
## e os álamos amarelos, do tamanho que tinham no desenho. A mata em volta não vem daqui: é a cobertura do mapa.
static func arvores(v: Vale) -> Array:
	var fila: Array = []
	if not montado:
		return fila
	for a: Dictionary in _info["arvores"]:
		var p := no_mundo(a["p"])
		var u := Clareira.sorte_do_lugar(p.x, p.z)
		var pinho := String(a["tipo"]) == "pinheiro"
		var tipo := Clareira.tipo_variado("pinheiro", u) if pinho else Clareira.tipo_variado("betula", u * 0.43)
		var alto := _altura_modelo(v, tipo)
		if alto <= 0.1:
			continue
		var s := float(a["alt"]) / alto
		var y := p.y - (0.15 if float((a["p"] as Array)[2]) < 0.05 else 0.0)  # a da laje fica em cima da laje
		fila.append([tipo, Transform3D(Basis(Vector3.UP, u * TAU).scaled(Vector3.ONE * s), Vector3(p.x, y, p.z))])
	return fila


static func _largura_modelo(v: Vale, nome: String) -> float:
	var caixa := AABB()
	var primeiro := true
	for par: Array in v._malhas.get(nome, []):
		var c := (par[1] as Transform3D) * (par[0] as Mesh).get_aabb()
		caixa = c if primeiro else caixa.merge(c)
		primeiro = false
	return maxf(caixa.size.x, caixa.size.z)


static func _altura_modelo(v: Vale, nome: String) -> float:
	var topo := 0.0
	for par: Array in v._malhas.get(nome, []):
		var caixa := (par[1] as Transform3D) * (par[0] as Mesh).get_aabb()
		topo = maxf(topo, caixa.end.y)
	return topo


## Dentro da vila (para bicho e planta solta não nascerem no meio das casas).
static func dentro(x: float, z: float) -> bool:
	return Vector2(x, z).distance_squared_to(CENTRO) < RAIO * RAIO


## O chão aqui: 2 em cima de rua, praça, laje, piso ou canteiro (o capim não nasce), 1 até 1,5 m dali (o capim
## fica ralo, para a rua aparecer), 0 no resto.
static func calcado(x: float, z: float) -> int:
	if _chao_n == 0:
		return 0
	var d := Vector2(x - CENTRO.x, z - CENTRO.y)
	if absf(d.x) > _chao_meia + 8.0 or absf(d.y) > _chao_meia + 8.0:
		return 0
	var l := d.rotated(RUMO)  # de volta ao desenho: o mundo foi girado por RUMO em volta do eixo de cima
	var i := floori((l.x + _chao_meia) / _chao_passo)
	var j := floori((-l.y + _chao_meia) / _chao_passo)
	if i < 0 or j < 0 or i >= _chao_n or j >= _chao_n:
		return 0
	return _chao[j * _chao_n + i]
