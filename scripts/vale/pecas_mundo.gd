class_name PecasMundo
extends Node3D
## As peças das melhorias espalhadas pela ilha (doc §64): uma por lugar marcante. Chegando perto, o robô
## pega; a peça só passa a valer quando ele entra no cilindro da base, que a monta no corpo.

signal achou(nome: String)
signal instalou(nomes: Array)

const PEGA := 1.15  # m do meio do robô ao meio da caixa: tem de encostar nela
const BOCA := 2.1  # m: distância do meio da boca do cilindro para instalar
const RADAR := 300.0  # m: alcance da antena de busca

var armadura: Armadura
var mapa: Vale
var hud: Hud
var locais: Locais
var drone: DroneColega
var sons: Sons
var onde := {}  # nome -> Vector3 (no chão)
var _nos := {}  # nome -> Node3D da peça ainda não achada
var _t := 0.0
var _busca_t := 0.0
var _efeito: MeshInstance3D
var _efeito_t := -1.0
var _no_radar := []  # nomes das peças no alcance da antena
var bipes := 0  # quantas vezes uma peça entrou no radar (testes)


func _ready() -> void:
	# cada peça num lugar que combina com ela; a antena fica a poucos passos da base
	var alvos := {
		"antena": Vector2(-52, 44),
		"radiador": Vector2(-100, 540),
		"bocais": Vector2(Marcos.anel.x, Marcos.anel.z) if Marcos.anel.is_finite() else Vector2(-190, 600),
		"asas": Vector2(mapa.cume.x, mapa.cume.z),
		"barbatanas": Vector2(Vale.POCO.x + Vale.POCO.z + 6.0, Vale.POCO.y + 8.0),
		"amortecedores": Vector2(Marcos.colunas.x, Marcos.colunas.z) + Vector2(0, 16) if Marcos.colunas.is_finite() else Vector2(420, -584),
		"farol": Sumidouro.centro + Vector2(Sumidouro.POCO_RAIO + 9.0, 4.0) if Sumidouro.existe else Vector2(-290, -600),
		"scanner": Vector2(Ruinas.TORRE.x + 14.0, Ruinas.TORRE.y + 10.0),
		"celulas": Vector2(Marcos.arvore_mae.x, Marcos.arvore_mae.z) + Vector2(-17, 9) if Marcos.arvore_mae.is_finite() else Vector2(640, 120),
	}
	Melhorias.base = BaseVale.boca_cilindro
	# as colisões do mundo só respondem depois de um passo da física (o Sumidouro é conferido por raio)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for nome: String in Melhorias.NOMES:
		onde[nome] = _assentar(alvos[nome])
	# a luz do peito fica lá embaixo, no salão do Sumidouro: quem desce no escuro sai com a luz
	var salao := _no_salao()
	if salao.is_finite():
		onde["farol"] = salao
	repor()
	_efeito = MeshInstance3D.new()
	var aro := CylinderMesh.new()
	aro.top_radius = 1.0
	aro.bottom_radius = 1.0
	aro.height = 0.5
	aro.cap_top = false
	aro.cap_bottom = false
	_efeito.mesh = aro
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.4, 1.0, 0.85, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_efeito.material_override = m
	_efeito.visible = false
	add_child(_efeito)


## Põe no mundo as peças que ainda não foram achadas (e tira as que já foram).
func repor() -> void:
	for nome: String in _nos:
		(_nos[nome] as Node3D).queue_free()
	_nos.clear()
	for nome: String in Melhorias.NOMES:
		if Melhorias.tudo or Melhorias.achadas.has(nome) or Melhorias.instaladas.has(nome):
			continue
		var no := _peca(nome)
		no.position = onde[nome]
		add_child(no)
		_nos[nome] = no


## Um ponto do piso do salão do Sumidouro, fora da lagoa do meio e com vão livre por cima (INF: não achou).
func _no_salao() -> Vector3:
	if not Sumidouro.existe:
		return Vector3.INF
	var esp := get_world_3d().direct_space_state
	var perp := Vector2(-Sumidouro.dir.y, Sumidouro.dir.x)
	for t: Vector2 in [Vector2(12, 7), Vector2(12, -7), Vector2(16, 0), Vector2(9, 10), Vector2(9, -10), Vector2(-10, 6), Vector2(-10, -6)]:
		var xz := Sumidouro.centro + Sumidouro.dir * t.x + perp * t.y
		var de := Vector3(xz.x, Sumidouro.piso + 5.0, xz.y)
		if not Sumidouro.no_vazio(de):
			continue
		var chao := esp.intersect_ray(PhysicsRayQueryParameters3D.create(de, de + Vector3(0, -9.0, 0), 1))
		if chao.is_empty():
			continue
		var p: Vector3 = chao["position"]
		if absf(p.y - Sumidouro.piso) > 1.5:
			continue
		if not esp.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.4, 0), p + Vector3(0, 4.5, 0), 1)).is_empty():
			continue
		var lado := esp.intersect_ray(PhysicsRayQueryParameters3D.create(de + Vector3(1.5, 0, 0), de + Vector3(1.5, -9.0, 0), 1))
		if lado.is_empty() or absf(lado["position"].y - p.y) > 0.8:
			continue
		return p
	return Vector3.INF


## O ponto seco, plano e livre mais perto do alvo (espiral de até 40 m).
func _assentar(alvo: Vector2) -> Vector3:
	for i in 220:
		var r := sqrt(float(i)) * 2.7
		var ang := i * 2.39996
		var x := alvo.x + cos(ang) * r
		var z := alvo.y + sin(ang) * r
		var y := mapa.altura(x, z)
		var nivel := mapa.agua(x, z)
		if nivel != -INF and nivel > y - 0.3:
			continue
		if absf(mapa.altura(x + 1.5, z) - y) > 0.7 or absf(mapa.altura(x, z + 1.5) - y) > 0.7:
			continue
		if not Obstaculos.livre(mapa, x, z, 1.6):
			continue
		# debaixo de rocha (no Sumidouro a grade de alturas guarda o fundo da caverna, não o alto do morro):
		# com teto logo acima, a peça vai para o chão de verdade, achado por um raio vindo de cima
		var esp := get_world_3d().direct_space_state
		var teto := esp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.6, z), Vector3(x, y + 9.0, z), 1))
		if not teto.is_empty():
			var cima := esp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y + 260.0, z), Vector3(x, y, z), 1))
			if cima.is_empty():
				continue
			var lado := esp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x + 1.5, y + 260.0, z), Vector3(x + 1.5, y, z), 1))
			if lado.is_empty() or absf(lado["position"].y - cima["position"].y) > 0.8:
				continue
			y = cima["position"].y
		return Vector3(x, y, z)
	return Vector3(alvo.x, mapa.altura(alvo.x, alvo.y), alvo.y)


## A peça no chão: uma caixinha que flutua e gira, com um facho de luz para achar de longe.
func _peca(nome: String) -> Node3D:
	var no := Node3D.new()
	no.name = "Peca_" + nome
	var gira := Node3D.new()
	gira.name = "gira"
	gira.position.y = 0.95
	no.add_child(gira)
	var caixa := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.36, 0.5)
	caixa.mesh = bm
	var mc := ShaderMaterial.new()
	mc.shader = load("res://scripts/shaders/vale_solido.gdshader")
	mc.set_shader_parameter("cor", Color(0.86, 0.84, 0.78))
	mc.set_shader_parameter("brilho_borda", 0.2)
	caixa.material_override = mc
	gira.add_child(caixa)
	var luz_mat := StandardMaterial3D.new()
	luz_mat.albedo_color = Color(0.3, 1.0, 0.8)
	luz_mat.emission_enabled = true
	luz_mat.emission = Color(0.3, 1.0, 0.8)
	luz_mat.emission_energy_multiplier = 3.0
	var faixa := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.53, 0.07, 0.53)
	faixa.mesh = fm
	faixa.material_override = luz_mat
	gira.add_child(faixa)
	var facho := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.22
	cm.height = 26.0
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 10
	facho.mesh = cm
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.albedo_color = Color(0.4, 1.0, 0.85, 0.16)
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mf.cull_mode = BaseMaterial3D.CULL_DISABLED
	facho.material_override = mf
	facho.position.y = 13.6
	facho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(facho)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.4, 1.0, 0.85)
	luz.light_energy = 1.4
	luz.omni_range = 7.0
	luz.position.y = 1.2
	no.add_child(luz)
	return no


func _process(delta: float) -> void:
	_t += delta
	for nome: String in _nos:
		var gira := (_nos[nome] as Node3D).get_node("gira") as Node3D
		gira.rotation.y = _t * 1.1
		gira.position.y = 0.95 + sin(_t * 1.7) * 0.1
	if _efeito_t >= 0.0:
		_efeito_t += delta
		var f := _efeito_t / 1.5
		_efeito.visible = f < 1.0
		_efeito.global_position = armadura.global_position + Vector3(0, f * armadura.altura_corpo() * 1.15, 0)
		_efeito.scale = Vector3(0.55 + 0.25 * sin(f * PI), 1.0, 0.55 + 0.25 * sin(f * PI))
		(_efeito.material_override as StandardMaterial3D).albedo_color.a = 0.6 * sin(f * PI)
		if f >= 1.0:
			_efeito_t = -1.0
	if armadura == null or armadura.em_pane:
		return
	var p := armadura.global_position
	for nome: String in _nos.keys():
		# só encostando na caixa: o facho de luz é sinal, não pega
		if (p + Vector3(0, armadura.altura_corpo() * 0.45, 0)).distance_to((_nos[nome] as Node3D).position + Vector3(0, 0.95, 0)) < PEGA:
			_pegar(nome)
	_busca_t -= delta
	if _busca_t <= 0.0:
		_busca_t = 0.5
		_apontar()


func _pegar(nome: String) -> void:
	(_nos[nome] as Node3D).queue_free()
	_nos.erase(nome)
	Melhorias.achar(nome)
	if hud:
		hud.avisar("Peça encontrada: " + Melhorias.TITULOS[nome],
			"instale na oficina da base · %d de %d" % [Melhorias.achadas.size() + Melhorias.instaladas.size(), Melhorias.NOMES.size()])
	if sons:
		sons._toque("marcar")
	achou.emit(nome)
	_apontar()


## O que a antena capta: só as peças a menos de RADAR metros. Quando uma entra no alcance, um bipe e um
## aviso curto chamam a atenção. A base não vira objetivo: instalar é no tempo do jogador.
func _apontar() -> void:
	Melhorias.sinais.clear()
	if not Melhorias.tem("antena") or Melhorias.tudo:
		_no_radar.clear()
		return
	var p := armadura.global_position
	var agora := []
	for nome: String in _nos:
		var pos := (_nos[nome] as Node3D).position
		# sai do radar um pouco mais longe do que entra, para não piscar na borda
		if p.distance_to(pos) < (RADAR * 1.15 if _no_radar.has(nome) else RADAR):
			agora.append(nome)
			Melhorias.sinais.append(pos)
			if not _no_radar.has(nome):
				bipes += 1
				if sons:
					sons._toque("marcar", -4.0, 0.0)
				if hud:
					hud.avisar("Sinal captado", "a antena achou uma peça por perto")
	_no_radar = agora
