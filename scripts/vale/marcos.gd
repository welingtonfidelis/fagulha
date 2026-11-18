class_name Marcos
extends RefCounted
## Marcos altos do vale (2026-11-17): coisas grandes que se veem de longe, para quem voa se orientar e ter
## aonde ir. A Árvore-Mãe no Platô das Flores (que era bonito e vazio), o Anel meio enterrado nos Campos do
## Sul e as Colunas num morro do nordeste. Cada um tem nome na tela, colisão e entra no mapa de obstáculos.

static var lugares: Array = []  # [nome, Vector2(x, z), raio]: o jogo põe na lista de lugares com nome
static var arvore_mae := Vector3.INF
static var anel := Vector3.INF
static var colunas := Vector3.INF


## O primeiro ponto da lista que é terra firme e mais ou menos plana.
static func _chao_bom(v: Vale, candidatos: Array) -> Vector2:
	for c: Vector2 in candidatos:
		if v.agua(c.x, c.y) == -INF and v._fora(c.x, c.y) > 4.0 and v.normal_em(c.x, c.y).y > 0.9 and Ruinas.livre(c.x, c.y):
			return c
	return candidatos[0]


static func montar(v: Vale) -> void:
	lugares.clear()
	var corpo := StaticBody3D.new()
	corpo.name = "Marcos"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	v.add_child(corpo)
	_arvore_mae(v)
	_anel(v, corpo)
	_colunas(v)
	print("marcos: Árvore-Mãe em %s, Anel em %s, Colunas em %s" % [arvore_mae, anel, colunas])
	MarcosLeste.montar(v)
	MarcosMar.montar(v)
	FendaEscura.montar(v)


## Uma árvore de 70 m sozinha no meio das flores. Entra na lista de árvores do mapa (colisão do tronco e da
## copa pela medida do modelo, como as outras), com pedras e um canteiro em volta.
static func _arvore_mae(v: Vale) -> void:
	var c := _chao_bom(v, [Vector2(660, 110), Vector2(640, 140), Vector2(700, 90), Vector2(620, 80)])
	var h := v._fora(c.x, c.y)
	var nome := "q_arvore_b"
	if not v._malhas.has(nome):
		return
	var s := 6.6
	var p := Vector3(c.x, h - 0.8, c.y)
	v._por(nome, Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * s), p))
	var i := v.arv_pos.size()
	v.arv_pos.append(p)
	v.arv_escala.append(s * 0.8)
	v.arv_tipo.append(1)
	v.arv_nome.append(nome)
	var cel := Vector2i(floori(p.x / Ilha.CELULA_ARVORE), floori(p.z / Ilha.CELULA_ARVORE))
	var l: PackedInt32Array = v._grade_arv.get(cel, PackedInt32Array())
	l.append(i)
	v._grade_arv[cel] = l
	# pedras em roda e raízes de mato
	for k in 7:
		var a := k * TAU / 7.0 + 0.3
		var q := c + Vector2(cos(a), sin(a)) * (9.0 + 2.0 * (k % 2))
		var pedra: String = ["q_pedra_a", "q_pedra_b", "q_pedra_c"][k % 3]
		if v._malhas.has(pedra):
			v._por(pedra, Transform3D(Basis(Vector3.UP, a * 2.0).scaled(Vector3.ONE * (1.6 + 0.5 * (k % 3))), Vector3(q.x, v._fora(q.x, q.y) - 0.15, q.y)), true)
	for k in 10:
		var a2 := k * TAU / 10.0
		var q2 := c + Vector2(cos(a2), sin(a2)) * (5.0 + 1.5 * (k % 3))
		var planta: String = ["q_samambaia", "q_moita_flor", "q_planta_c"][k % 3]
		if v._malhas.has(planta):
			v._por(planta, Transform3D(Basis(Vector3.UP, a2).scaled(Vector3.ONE * 1.5), Vector3(q2.x, v._fora(q2.x, q2.y) - 0.05, q2.y)))
	arvore_mae = Vector3(c.x, h, c.y)
	lugares.append(["A Árvore-Mãe", c, 55.0])


## Um anel de metal de 62 m de diâmetro, de pé e meio enterrado, torto, enferrujado: dá para voar por dentro.
static func _anel(v: Vale, corpo: StaticBody3D) -> void:
	var c := _chao_bom(v, [Vector2(-190, 600), Vector2(-120, 560), Vector2(-60, 620), Vector2(-240, 520)])
	var h := v._fora(c.x, c.y)
	var malha := TorusMesh.new()
	malha.inner_radius = 27.0
	malha.outer_radius = 31.0
	malha.rings = 56
	malha.ring_segments = 14
	malha.material = BaseVale._mat_cor(Color(0.2, 0.22, 0.2), 0.85, 0.45, v._tex)
	var mi := MeshInstance3D.new()
	mi.name = "OAnel"
	mi.mesh = malha
	# o furo do toro é o eixo Y dele: deitar o eixo põe o anel de pé; depois, torto e virado
	var base := Basis(Vector3.UP, 0.9) * Basis(Vector3.BACK, 0.2) * Basis(Vector3.RIGHT, PI * 0.5)
	var centro := Vector3(c.x, h + 31.0 * 0.42, c.y)
	mi.transform = Transform3D(base, centro)
	v.add_child(mi)
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(malha.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.transform = mi.transform
	corpo.add_child(cs)
	# onde o anel entra no chão: dois pés que barram quem anda
	var eixo := base * Vector3.RIGHT
	for lado: float in [-1.0, 1.0]:
		Obstaculos.registrar(c.x + eixo.x * 27.0 * lado, c.y + eixo.z * 27.0 * lado, 3.0)
	anel = centro
	lugares.append(["O Anel", c, 60.0])


## Três colunas de 65 m num morro: uma inteira, uma afundada pela metade e um toco, com um pedaço caído.
static func _colunas(v: Vale) -> void:
	var melhor := Vector2(430, -620)
	var alto := -INF
	for gx in range(-2, 5):
		for gz in range(-3, 4):
			var q := Vector2(420 + gx * 40.0, -600 + gz * 40.0)
			if maxf(absf(q.x), absf(q.y)) > 760.0 or v.agua(q.x, q.y) > -INF or v.normal_em(q.x, q.y).y < 0.88 or not Ruinas.livre(q.x, q.y):
				continue
			if v._fora(q.x, q.y) > alto:
				alto = v._fora(q.x, q.y)
				melhor = q
	var o := Ruinas.Obra.new()
	o.v = v
	o.t = Transform3D(Basis(Vector3.UP, 0.4), Vector3(melhor.x, v._fora(melhor.x, melhor.y), melhor.y))
	o.rng.seed = 91
	o.corpo = StaticBody3D.new()
	o.corpo.name = "RuinaColunas"
	o.corpo.collision_layer = 1
	o.corpo.collision_mask = 0
	v.add_child(o.corpo)
	BaseVale._peca(o, "Column_Large_Straight", Vector3(-11.0, o.chao(-11.0, 0.0) - 3.0, 0.0), 0.3, 6.5, 0.75, 0.5)
	BaseVale._peca(o, "Column_Large_Straight", Vector3(5.0, o.chao(5.0, 6.0) - 30.0, 6.0), 1.2, 6.5, 0.85, 0.6)
	BaseVale._peca(o, "Column_Large_Straight", Vector3(14.0, o.chao(14.0, -8.0) - 51.0, -8.0), 2.0, 6.5, 0.9, 0.7)
	o.fechar()
	colunas = o.t.origin
	lugares.append(["As Colunas", melhor, 60.0])
