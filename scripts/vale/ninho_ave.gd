class_name NinhoAve
extends Node3D
## O ninho da ave grande (2026-11-19), o lugar que as **asas** abrem. Fica no alto de um pilar da ponte antiga,
## no mar ao sul do Arquipélago, mais alto que os outros. Em volta dele a maresia apaga os jatos
## (`Armadura.jato_cortado`): sem asas o robô cai no mar e do mar não se sobe; com as asas ele passa a planar
## sozinho ao entrar na maresia, e chega quem vier alto. Pousando no tabuleiro, a ave acorda, levanta voo e
## passa a aparecer de vez em quando bem alto sobre a ilha, dando voltas.
## Quem cria passa `armadura`, `hud`, `memorias` e `mapa`.

const PILAR := Vector2(1338.0, 1004.0)
const ALTO := 36.0  # o tampo do tabuleiro acima do mar
const MARESIA := 175.0  # raio em que os jatos apagam
const MARESIA_TETO := 230.0  # acima disso o ar é limpo
const AVE_MODELO := "res://assets/vale/aguia/aguia.glb"
const ENVERGADURA := 11.0  # metros de ponta a ponta das asas
const CORES_AVE := {"Wings": Color(0.25, 0.14, 0.08), "Head": Color(0.9, 0.89, 0.84), "Beak": Color(0.95, 0.68, 0.12), "Claws": Color(0.9, 0.62, 0.1)}
const GIRO_MODELO := 0.0  # para a frente do modelo ficar em -z
const CEU_ALTURA := 270.0
const CEU_RAIO := 520.0
const CEU_VEL := 24.0
const CEU_FICA := 170.0  # segundos de cada aparição
const CEU_ESPERA := [300.0, 540.0]  # entre uma aparição e outra

var armadura: Armadura
var hud: Hud
var memorias: Memorias
var mapa: Ilha
var achada := false
var no_ceu := false
var aparicoes := 0  # testes
var tampo := Vector3.INF  # o meio do tabuleiro, no mundo

var _ave: Node3D
var _anim: AnimationPlayer
var _anim_voo := ""
var _anim_pousada := ""
var _t := 0.0
var _espera := 60.0
var _fica := 0.0
var _ang := 0.0
var _subindo := 0.0
var _avisou := false
var _nevoa: Array[MeshInstance3D] = []


func _ready() -> void:
	if Guardado.ativo:
		achada = bool((Guardado.progresso("achados") as Dictionary).get("ave", false))
	for i in 6:
		await get_tree().physics_frame
	_construir()
	_por_ave()
	if achada:
		_ave.visible = false
		_espera = randf_range(90.0, 240.0)


func _peca(centro: Vector3, tam: Vector3, cor: Color, giro := Basis.IDENTITY, forma := "caixa") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if forma == "ovo":
		var e := SphereMesh.new()
		e.radius = 0.5
		e.height = 1.0
		e.radial_segments = 10
		e.rings = 6
		mi.mesh = e
	else:
		mi.mesh = BoxMesh.new()
	var mt := ShaderMaterial.new()
	mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
	mt.set_shader_parameter("cor", cor)
	mt.set_shader_parameter("brilho_borda", 0.12)
	mi.material_override = mt
	mi.transform = Transform3D(giro.scaled_local(tam), centro)
	add_child(mi)
	return mi


## O pilar, no jeito das outras ruínas da ponte (blocos de concreto com a textura delas), e o ninho em cima.
func _construir() -> void:
	var v := mapa as Vale
	var o := Ruinas.Obra.new()
	o.v = v
	var blocos: Array[PackedVector3Array] = []
	for k in 5:
		blocos.append(Ruinas._cubo_talhado(907 + k * 3, 1 + k % 3))
	o.blocos = blocos
	o.t = Transform3D.IDENTITY
	o.rng.seed = 9091
	o.corpo = StaticBody3D.new()
	o.corpo.name = "PilarDoNinho"
	o.corpo.collision_layer = 1
	o.corpo.collision_mask = 0
	add_child(o.corpo)
	var fundo: float = minf(mapa.altura(PILAR.x, PILAR.y), -2.0)
	var p := Vector3(PILAR.x, 0, PILAR.y)
	var giro := Basis(Vector3.UP, 0.2)
	# o fuste em três lances, mais grosso embaixo, com as juntas à mostra
	var lances := [[fundo, 11.0, Vector3(5.6, 0, 6.6)], [11.0, 23.0, Vector3(4.9, 0, 5.8)], [23.0, ALTO - 2.2, Vector3(4.3, 0, 5.1)]]
	for l: Array in lances:
		var y0: float = l[0]
		var y1: float = l[1]
		var t: Vector3 = l[2]
		o.bloco(p + Vector3(0, (y0 + y1) * 0.5, 0), Vector3(t.x, y1 - y0 + 0.3, t.z), giro * Basis.from_euler(Vector3(o.j(0.01), 0, o.j(0.01))), "concreto")
		o.bloco(p + Vector3(0, y1 - 0.2, 0), Vector3(t.x + 0.5, 0.5, t.z + 0.5), giro, "casco_claro", false)
	# o capitel e o resto do tabuleiro, com um canto partido e pendurado
	o.bloco(p + Vector3(0, ALTO - 1.7, 0), Vector3(6.6, 1.4, 9.0), giro, "concreto")
	o.bloco(p + Vector3(0, ALTO - 0.5, 0), Vector3(14.0, 1.0, 10.4), giro, "concreto")
	o.bloco(p + giro * Vector3(9.4, ALTO - 1.9, -1.5), Vector3(5.0, 0.9, 6.0), giro * Basis(Vector3.BACK, -0.55) * Basis(Vector3.RIGHT, 0.12), "concreto")
	o.bloco(p + giro * Vector3(-8.6, ALTO - 0.7, 2.2), Vector3(3.4, 0.9, 5.0), giro * Basis(Vector3.BACK, 0.16), "concreto")
	# guarda-corpo de ferro, torto e com falhas; vergalhões saindo das quebras; um cabo pendurado
	for lado: float in [-1.0, 1.0]:
		for k in 6:
			if (k + int(lado)) % 4 == 0:
				continue
			o.bloco(p + giro * Vector3(-5.6 + k * 2.2, ALTO + 0.55, lado * 5.0), Vector3(0.1, 1.1, 0.1), giro * Basis.from_euler(Vector3(o.j(0.12), 0, o.j(0.12))), "ferrugem", false)
		o.bloco(p + giro * Vector3(-0.6, ALTO + 1.05, lado * 5.0), Vector3(10.4, 0.1, 0.1), giro * Basis(Vector3.BACK, o.j(0.03)), "ferrugem", false)
	for k in 5:
		o.bloco(p + giro * Vector3(7.2 + k * 0.25, ALTO - 0.4 - k * 0.12, -3.4 + k * 1.5), Vector3(2.0, 0.07, 0.07), giro * Basis.from_euler(Vector3(0, o.j(0.3), -0.3 + o.j(0.25))), "ferrugem", false)
	o.bloco(p + giro * Vector3(-6.8, ALTO - 5.5, -5.0), Vector3(0.09, 10.0, 0.09), Basis.from_euler(Vector3(0.05, 0, 0.07)), "ferrugem", false)
	# o que sobrou da ponte em volta: um pilar partido mais baixo, na direção da ilhota, e um pedaço do tabuleiro
	# caído ao pé, meio dentro d'água
	var rumo := (Vector2(1326.0, 868.0) - PILAR).normalized()
	var q := PILAR + rumo * 26.0
	var fq: float = minf(mapa.altura(q.x, q.y), -2.0)
	o.bloco(Vector3(q.x, (fq + 7.5) * 0.5, q.y), Vector3(4.4, 7.5 - fq, 5.2), giro * Basis.from_euler(Vector3(0.03, 0.2, -0.04)), "concreto")
	for k in 4:
		o.bloco(Vector3(q.x + o.j(1.2), 8.2 + k * 0.1, q.y + o.j(1.5)), Vector3(0.08, 1.8, 0.08), Basis.from_euler(Vector3(o.j(0.4), 0, o.j(0.4))), "ferrugem", false)
	o.bloco(p + giro * Vector3(5.5, -0.2, 6.5), Vector3(8.0, 1.0, 6.0), giro * Basis.from_euler(Vector3(0.5, 0.3, 0.22)), "concreto")
	o.bloco(p + giro * Vector3(-5.0, -0.8, -5.5), Vector3(4.0, 3.0, 4.6), giro * Basis.from_euler(Vector3(0.3, 0.9, -0.2)), "concreto")
	o.fechar()
	tampo = p + Vector3(0, ALTO, 0)
	# mato tomando o tabuleiro, nos cantos
	for dados: Array in [[Vector3(-5.2, 0.05, -3.9), 0.9], [Vector3(5.6, 0.05, 3.8), 0.7], [Vector3(-5.8, 0.05, 3.2), 0.6]]:
		v._por("arbusto", Transform3D(Basis(Vector3.UP, o.rng.randf() * TAU).scaled(Vector3.ONE * float(dados[1])), tampo + giro * (dados[0] as Vector3)))
	_ninho()
	_maresia(p)


## O ninho: três voltas de galhos trançados, cada uma mais alta e mais fechada, o forro de palha, três ovos e
## umas penas caídas em volta.
func _ninho() -> void:
	var galhos := [Color(0.3, 0.21, 0.13), Color(0.38, 0.27, 0.16), Color(0.24, 0.17, 0.11)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	for volta in 3:
		var n := 22 - volta * 3
		var raio := 3.0 - volta * 0.32
		for k in n:
			var ang := k * TAU / n + volta * 0.4
			var comp := rng.randf_range(1.7, 2.6)
			_peca(tampo + Vector3(cos(ang) * raio, 0.16 + volta * 0.22 + rng.randf_range(-0.04, 0.06), sin(ang) * raio),
				Vector3(comp, rng.randf_range(0.12, 0.2), rng.randf_range(0.12, 0.2)), galhos[(k + volta) % 3],
				Basis(Vector3.UP, -ang + PI * 0.5 + rng.randf_range(-0.45, 0.45)) * Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2)))
	# gravetos espetados para fora, que quebram a roda certinha
	for k in 12:
		var ang2 := rng.randf() * TAU
		_peca(tampo + Vector3(cos(ang2) * 3.3, 0.35 + rng.randf() * 0.4, sin(ang2) * 3.3), Vector3(rng.randf_range(1.0, 1.8), 0.09, 0.09), galhos[k % 3],
			Basis(Vector3.UP, -ang2 + rng.randf_range(-0.3, 0.3)) * Basis(Vector3.BACK, rng.randf_range(0.15, 0.6)))
	# o forro de palha, por dentro
	for k in 9:
		var ang3 := k * TAU / 9.0
		_peca(tampo + Vector3(cos(ang3) * 1.25, 0.14, sin(ang3) * 1.25), Vector3(1.9, 0.1, 1.0), Color(0.62, 0.52, 0.3), Basis(Vector3.UP, -ang3 + 0.3))
	_peca(tampo + Vector3(0, 0.12, 0), Vector3(2.0, 0.12, 2.0), Color(0.66, 0.56, 0.33), Basis(Vector3.UP, 0.5))
	# três ovos claros, encostados
	for dados: Array in [[Vector3(0.9, 0.48, 0.5), 0.2], [Vector3(1.35, 0.46, -0.15), -0.3], [Vector3(0.7, 0.45, -0.45), 0.5]]:
		_peca(tampo + (dados[0] as Vector3), Vector3(0.52, 0.7, 0.52), Color(0.86, 0.84, 0.76), Basis(Vector3.BACK, float(dados[1])) * Basis(Vector3.RIGHT, 0.25), "ovo")
	# penas caídas no tabuleiro
	for k in 7:
		var pf := tampo + Vector3(rng.randf_range(-5.5, 5.5), 0.04, rng.randf_range(-4.2, 4.2))
		if Vector2(pf.x - tampo.x, pf.z - tampo.z).length() < 3.4:
			continue
		_peca(pf, Vector3(0.7, 0.02, 0.16), Color(0.32, 0.2, 0.12) if k % 2 == 0 else Color(0.85, 0.85, 0.82), Basis(Vector3.UP, rng.randf() * TAU))


## A maresia: véus claros baixos em volta do pilar.
func _maresia(p: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_color = Color(0.92, 0.97, 1.0, 0.2)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists("res://assets/fx/kenney/circle_05.png"):
		mat.albedo_texture = load("res://assets/fx/kenney/circle_05.png")
	var q := QuadMesh.new()
	for k in 34:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := k * TAU / 34.0 * 3.0
		var r := MARESIA * (0.35 + 0.65 * fposmod(k * 0.618, 1.0))
		mi.position = p + Vector3(cos(ang) * r, 8.0 + 26.0 * fposmod(k * 0.37, 1.0), sin(ang) * r)
		mi.scale = Vector3.ONE * (60.0 + 40.0 * fposmod(k * 0.21, 1.0))
		add_child(mi)
		_nevoa.append(mi)


## A ave: a águia do Animal Pack Vol.2 do Quaternius (CC0), aumentada até a envergadura pedida e pintada no
## estilo do vale. Tem duas animações, a de pousada e a de voo.
func _por_ave() -> void:
	_ave = Node3D.new()
	add_child(_ave)
	var modelo := (load(AVE_MODELO) as PackedScene).instantiate() as Node3D
	_ave.add_child(modelo)
	# a medida de ponta a ponta das asas, para acertar o tamanho
	var larg := 0.0
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		var cx := mi.get_aabb()
		var esc := mi.global_basis.get_scale()
		larg = maxf(larg, maxf(cx.size.x * absf(esc.x), maxf(cx.size.y * absf(esc.y), cx.size.z * absf(esc.z))))
		for sfc in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(sfc) as StandardMaterial3D
			if m:
				var mt := ShaderMaterial.new()
				mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
				# as cores do modelo se perderam na conversão (vieram todas cinza): voltam pelo nome do material
				mt.set_shader_parameter("cor", CORES_AVE.get(String(m.resource_name), m.albedo_color))
				mt.set_shader_parameter("brilho_borda", 0.15)
				mi.set_surface_override_material(sfc, mt)
	if larg > 0.001:
		modelo.scale = Vector3.ONE * (ENVERGADURA / larg)
	modelo.rotation.y = GIRO_MODELO
	var tocadores := modelo.find_children("*", "AnimationPlayer", true, false)
	if not tocadores.is_empty():
		_anim = tocadores[0] as AnimationPlayer
		for nome: String in _anim.get_animation_list():
			_anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
			if "Fly" in nome:
				_anim_voo = nome
			elif "Idle" in nome:
				_anim_pousada = nome
	_ave.global_position = tampo + Vector3(-0.5, 0.55, 0.0)
	_ave.rotation.y = 1.9
	_tocar(_anim_pousada, 0.35)


func _tocar(nome: String, ritmo: float) -> void:
	if _anim and nome != "":
		if _anim.current_animation != nome:
			_anim.play(nome, 0.5)
		_anim.speed_scale = ritmo


func _achar() -> void:
	achada = true
	if Guardado.ativo:
		var d: Dictionary = (Guardado.progresso("achados") as Dictionary).duplicate()
		d["ave"] = true
		Guardado.por_progresso("achados", d)
	_subindo = 0.001
	if hud:
		hud.avisar("A ave grande acordou", "de vez em quando ela vai passar bem alto sobre a ilha")
	if memorias:
		memorias.abrir("ave_grande")


## Começa uma aparição no céu (os testes e as fotos chamam direto).
func aparecer() -> void:
	if not achada:
		return
	no_ceu = true
	_subindo = 0.0
	aparicoes += 1
	_fica = CEU_FICA
	_ang = randf() * TAU
	_ave.visible = true
	_tocar(_anim_voo, 0.55)


func _process(delta: float) -> void:
	_t += delta
	for k in _nevoa.size():
		_nevoa[k].position.y += sin(_t * 0.2 + k) * delta * 0.4
	if armadura == null or not tampo.is_finite():
		return
	var p := armadura.global_position
	var d := Vector2(p.x - PILAR.x, p.z - PILAR.y).length()
	var na_maresia: bool = d < MARESIA and p.y < MARESIA_TETO
	armadura.jato_cortado = na_maresia
	if na_maresia and not _avisou and armadura.estado != Armadura.Estado.NADO and armadura.estado != Armadura.Estado.CHAO:
		_avisou = true
		if hud:
			hud.aconselhar("A maresia aqui apaga os jatos. Com asas, dá para atravessar planando.", 8.0)
	if not achada:
		if armadura.estado == Armadura.Estado.CHAO and p.distance_to(tampo) < 7.5 and p.y > tampo.y - 1.0 and not get_tree().paused:
			_achar()
		return
	if _subindo > 0.0:
		# acorda, abre as asas e sobe em espiral até sumir no alto
		_subindo += delta
		_tocar(_anim_voo, 1.5)
		var ang := _subindo * 0.5
		_ave.global_position = tampo + Vector3(cos(ang) * _subindo * 6.0, 0.5 + _subindo * _subindo * 0.9, sin(ang) * _subindo * 6.0)
		_ave.rotation.y = atan2(sin(ang), -cos(ang))  # de frente para onde a espiral vai
		if _subindo > 16.0:
			_subindo = 0.0
			_ave.visible = false
			_espera = randf_range(120.0, 240.0)
		return
	if not no_ceu:
		_espera -= delta
		if _espera <= 0.0:
			aparecer()
		return
	# dando voltas bem alto sobre a ilha: bate as asas um pouco e plana
	_fica -= delta
	_ang += CEU_VEL / CEU_RAIO * delta
	var pos := Vector3(cos(_ang) * CEU_RAIO, CEU_ALTURA + sin(_t * 0.15) * 18.0, sin(_ang) * CEU_RAIO)
	_ave.global_position = pos
	_ave.rotation = Vector3(0, atan2(sin(_ang), -cos(_ang)), -0.22)  # de frente para a volta, inclinada para dentro dela
	if _fica <= 0.0:
		no_ceu = false
		_ave.visible = false
		_espera = randf_range(CEU_ESPERA[0], CEU_ESPERA[1])
