class_name Main
extends Node3D
## Etapa 1, primeiro voo: monta tudo por código (céu, sol, ilha de teste, armadura, câmera e tela).
## Modos: `-- --teste` (testes sem janela, com --headless) e `-- --captura` (fotos em tools/capturas/).
## `-- --canion` abre o cânion do teste de qualidade visual; `-- --canion-captura` tira as fotos dele.
## A pausa troca entre a ilha e o cânion.

static var mapa := ""

var ilha: Ilha
var armadura: Armadura
var camera: CameraVoo
var hud: Hud
var pausa: Pausa
var vida: VidaVale
var inimigos: InimigosVale
var som_lugar: SomAmbiente
var sons: Sons
var locais: Locais
var ciclo: CicloDia
var tiro: Tiro
var sol: DirectionalLight3D


func _ready() -> void:
	Controles.configurar()
	var args := OS.get_cmdline_user_args()
	if mapa == "":
		# o cânion pintado é o mapa de entrada (estilo escolhido em 2026-11-14); os testes e as fotos
		# antigas continuam na ilha, e --canion abre o realista
		# o quadro do novo rumo (clareira) é o mapa de entrada; os outros ficam como registro
		mapa = "clareira"
		if "--teste-vale" in args or "--vale-captura" in args:
			mapa = "clareira"
		elif "--mundo" in args or "--mundo-captura" in args or "--teste-mundo" in args:
			mapa = "mundo"
		elif "--canion-b" in args:
			mapa = "canion_b"
		elif "--teste" in args or "--captura" in args or "--ilha" in args:
			mapa = "ilha"
		elif ("--canion" in args or "--canion-captura" in args or "--teste-canion" in args) and not ("--canion-b" in args):
			mapa = "canion"
	if mapa == "canion":
		_ambiente_canion()
		ilha = Canion.new()
	elif mapa == "canion_b":
		_ambiente_estilo()
		ilha = CanionEstilo.new()
	elif mapa == "mundo":
		_ambiente_estilo(true)
		ilha = Mundo.new()
	elif mapa == "clareira":
		_ambiente_vale()
		ilha = Clareira.new() if "--so-clareira" in args else Vale.new()
	else:
		_ambiente()
		ilha = Ilha.new()
	var vale := mapa == "clareira"
	Armadura.porte = 0.48 if vale else 1.0
	Armadura.vel_chao = 0.7 if vale else 1.0
	ArmaduraVisual.MODELO = "res://assets/vale/robo_v1.glb" if vale else "res://assets/armadura/robo_teste_v1.glb"
	ArmaduraVisual.toon = vale
	ilha.name = "Mapa"
	add_child(ilha)
	ilha.gerar(7)
	armadura = Armadura.new()
	armadura.name = "Armadura"
	armadura.ilha = ilha
	add_child(armadura)
	armadura.ponto_inicio = ilha.spawn
	armadura.yaw_inicio = ilha.spawn_yaw
	armadura.global_position = ilha.spawn
	if ilha is Vale:
		armadura.base = ilha.spawn
	camera = CameraVoo.new()
	camera.name = "Camera"
	camera.alvo = armadura
	camera.ilha = ilha
	camera.yaw = ilha.spawn_yaw
	add_child(camera)
	armadura.camera = camera
	if ciclo:
		ciclo.camera = camera
		ciclo.nevoa_longe = ilha is Vale  # aqui o mapa já existe
	var camada := CanvasLayer.new()
	add_child(camada)
	hud = Hud.new()
	hud.alvo = armadura
	camada.add_child(hud)
	sons = Sons.new()
	sons.armadura = armadura
	add_child(sons)
	sons.iniciar()
	if ilha is Canion:
		sons.cachoeira_em(((ilha as Canion).lip + (ilha as Canion).poco) * 0.5)
	if ilha is Canion or ilha is Mundo:
		locais = Locais.new()
		locais.armadura = armadura
		add_child(locais)
		if ilha is Canion:
			locais.do_canion(ilha as Canion)
		else:
			for l in (ilha as Mundo).lugares:
				locais.adicionar(l["nome"], l["pos"], l["raio"])
			for q in (ilha as Mundo).quedas:
				sons.cachoeira_em(q)
		hud.ligar_locais(locais)
	if ilha is Clareira and ResourceLoader.exists("res://scripts/vale/cervo.gd"):
		var k := 0
		for p in (ilha as Clareira).cervos_em:
			var cervo: Node3D = load("res://scripts/vale/cervo.gd").new()
			cervo.set("mapa", ilha)
			cervo.set("ameaca", armadura)
			cervo.set("casa", p)
			cervo.set("semente", 31 + k)
			cervo.position = p
			add_child(cervo)
			_pintar(cervo, ilha as Clareira)
			k += 1
	if ilha is Clareira:
		# tiro pelas mãos, folhas e poeira, água e som do lugar
		tiro = Tiro.new()
		tiro.armadura = armadura
		add_child(tiro)
		tiro.disparou.connect(sons.ao_atirar)
		var mato := EfeitosMato.new()
		mato.armadura = armadura
		mato.mapa = ilha
		add_child(mato)
		mato.atravessou_copa.connect(sons.ao_atravessar_copa)
		if ilha is Vale:
			var limite := LimiteMar.new()
			limite.armadura = armadura
			limite.mapa = ilha
			limite.hud = hud
			add_child(limite)
			for q in (ilha as Vale).quedas:
				sons.cachoeira_em(q)
			# lugares com nome: aparecem na tela na chegada (os da maquete aprovada e as três ruínas)
			var mapa_vale := ilha as Vale
			locais = Locais.new()
			locais.armadura = armadura
			add_child(locais)
			var foz := mapa_vale._rio_ponto(mapa_vale._rio_s_foz)
			for l: Array in [["Clareira", Vector2(0, 0), 95.0], ["Cachoeira", Vector2(Vale.POCO.x, Vale.POCO.y), 55.0],
					["Mata Fechada", Vector2(140, -600), 190.0], ["Serra do Mirante", Vector2(mapa_vale.cume.x, mapa_vale.cume.z), 120.0],
					["Platô das Flores", Vector2(640, 120), 210.0], ["Campos do Sul", Vector2(-100, 540), 190.0],
					["Foz do Riacho", foz, 60.0], ["Os Arcos", Vector2(Ruinas.ARCOS.x, Ruinas.ARCOS.y), 60.0],
					["A Torre Caída", Vector2(Ruinas.TORRE.x, Ruinas.TORRE.y), 50.0], ["O Pátio das Máquinas", Vector2(Ruinas.PATIO.x, Ruinas.PATIO.y), 45.0]]:
				var lp: Vector2 = l[1]
				locais.adicionar(l[0], Vector3(lp.x, mapa_vale.altura(lp.x, lp.y), lp.y), l[2])
			for cav: Dictionary in Cavernas.lista:
				var mc: Vector2 = ((cav["a"] as Vector2) + (cav["b"] as Vector2)) * 0.5
				locais.adicionar(cav["nome"], Vector3(mc.x, mapa_vale.altura(mc.x, mc.y) + 3.0, mc.y), float(cav["comp"]) * 0.45)
			hud.ligar_locais(locais)
			var capim := CapimVivo.new()
			capim.mapa = ilha
			capim.alvo = armadura
			add_child(capim)
		var pane := Pane.new()
		pane.armadura = armadura
		pane.ciclo = ciclo
		add_child(pane)
		var noite := Noite.new()
		noite.camera = camera
		noite.armadura = armadura
		add_child(noite)
		var agua_fx := EfeitosAgua.new()
		agua_fx.armadura = armadura
		agua_fx.mapa = ilha
		add_child(agua_fx)
		som_lugar = SomAmbiente.new()
		som_lugar.ouvinte = armadura
		add_child(som_lugar)
		var pts: Array[Vector3] = []
		for r in Clareira.RIACHO:
			pts.append(Vector3(r.x, Clareira.NIVEL, r.y))
		som_lugar.riacho_em(pts)
		if ilha is Vale:
			som_lugar.rio_em((ilha as Vale).pontos_do_rio(SomAmbiente.RIO_PASSO))
		# bichos pequenos: pássaros em bando, coelhos e o cardume da lagoa
		var pinta := func(no: Node) -> void: _pintar(no, ilha as Clareira)
		var k_b := 0
		for casa_b: Vector3 in [Vector3(-6, 0, 58), Vector3(-31, 0, -11), Vector3(52, 0, 40)]:
			var bando := Passaros.new()
			bando.mapa = ilha
			bando.ameaca = armadura
			bando.casa = casa_b
			bando.quantos = 5 + k_b
			bando.semente = 11 + k_b
			bando.pintar = pinta
			add_child(bando)
			k_b += 1
		var k_c := 0
		for casa_c: Vector3 in [Vector3(9, 0, 24), Vector3(12, 0, 27), Vector3(44, 0, 52), Vector3(-56, 0, -4), Vector3(-20, 0, 70)]:
			var coelho := Coelho.new()
			coelho.mapa = ilha
			coelho.ameaca = armadura
			coelho.casa = casa_c
			coelho.semente = 51 + k_c
			add_child(coelho)
			_pintar(coelho, ilha as Clareira)
			k_c += 1
		# máquina agressiva: um Sentinela rio acima, longe do começo
		var sentinela := Sentinela.new()
		sentinela.mapa = ilha
		sentinela.alvo = armadura
		sentinela.casa = Vector3(-62, 0, -56)
		sentinela.semente = 5
		sentinela.pintar = pinta
		add_child(sentinela)
		var peixes := Peixes.new()
		peixes.mapa = ilha
		peixes.ameaca = armadura
		peixes.centro = Vector3(Clareira.LAGOA.x, 0, Clareira.LAGOA.y)
		peixes.raio = Clareira.LAGOA.z - 1.5
		peixes.pintar = pinta
		add_child(peixes)
		peixes.ligar_respingo(agua_fx)
		peixes.saltou.connect(func(pos: Vector3) -> void: agua_fx._anel(pos, 0.2, 1.6, 0.8, 0.8))
		if ilha is Vale:
			# a vida fora da clareira: nasce e some conforme o robô chega e se afasta
			vida = VidaVale.new()
			vida.mapa = ilha
			vida.alvo = armadura
			vida.pintar = pinta
			add_child(vida)
			inimigos = InimigosVale.new()
			inimigos.mapa = ilha
			inimigos.alvo = armadura
			inimigos.pintar = pinta
			add_child(inimigos)
	if ilha is Mundo:
		var chao := ChaoVivo.new()
		chao.mapa = ilha
		chao.alvo = armadura
		add_child(chao)
	pausa = Pausa.new()
	pausa.armadura = armadura
	add_child(pausa)
	if "--teste" in args:
		var t := Testes.new()
		add_child(t)
		t.rodar(self)
	elif "--captura" in args:
		var c := Capturas.new()
		add_child(c)
		c.rodar(self)
	elif "--teste-canion" in args:
		var tc: Node = load("res://scripts/teste_visual/testes_canion.gd").new()
		add_child(tc)
		tc.call("rodar", self)
	elif "--teste-mundo" in args:
		var tm: Node = load("res://scripts/testes_mundo.gd").new()
		add_child(tm)
		tm.call("rodar", self)
	elif "--teste-vale" in args:
		var tv: Node = load("res://scripts/vale/testes_vale.gd").new()
		add_child(tv)
		tv.call("rodar", self)
	elif "--vale-captura" in args:
		var cv: Node = load("res://scripts/vale/capturas_vale.gd").new()
		add_child(cv)
		cv.call("rodar", self)
	elif "--mundo-captura" in args:
		var cm: Node = load("res://scripts/capturas_mundo.gd").new()
		add_child(cm)
		cm.call("rodar", self)
	elif "--canion-captura" in args or "--canion-b-captura" in args:
		var cc := CapturasCanion.new()
		add_child(cc)
		cc.rodar(self)
	else:
		if OS.has_feature("linux"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Céu do HDRI, névoa volumétrica com raios de sol, luz global (SDFGI), reflexos e antisserrilhado temporal.
func _ambiente_canion() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ceu := PanoramaSkyMaterial.new()
	ceu.panorama = load("res://assets/teste_visual/ceu.hdr")
	ceu.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = ceu
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.76, 0.8)
	env.fog_density = 0.0007
	env.fog_aerial_perspective = 0.7
	env.fog_sky_affect = 0.15
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0014
	env.volumetric_fog_albedo = Color(0.88, 0.91, 0.94)
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_length = 180.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.15
	env.volumetric_fog_sky_affect = 0.3
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.4
	env.sdfgi_energy = 0.9
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-38.0, 140.0, 0.0)
	sol.light_color = Color(1.0, 0.9, 0.76)
	sol.light_energy = 2.5
	sol.light_volumetric_fog_energy = 1.6
	sol.shadow_enabled = true
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sol.directional_shadow_max_distance = 260.0
	sol.directional_shadow_blend_splits = true
	sol.shadow_blur = 1.2
	add_child(sol)
	var vp := get_viewport()
	vp.use_taa = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.mesh_lod_threshold = 2.0


## Estilo pintado e sério: céu frio e escuro, sol baixo e quente, névoa azulada com raios de sol.
func _ambiente_estilo(mundo_grande := false) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ceu := ProceduralSkyMaterial.new()
	ceu.sky_top_color = Color(0.16, 0.27, 0.42)
	ceu.sky_horizon_color = Color(0.62, 0.70, 0.74)
	ceu.ground_horizon_color = Color(0.50, 0.58, 0.62)
	ceu.ground_bottom_color = Color(0.22, 0.27, 0.30)
	ceu.sky_curve = 0.09
	ceu.sun_angle_max = 40.0
	ceu.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = ceu
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 3.0
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_color = Color(0.36, 0.46, 0.60)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.42, 0.52, 0.58)
	env.fog_density = 0.0009
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.1
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0016
	env.volumetric_fog_albedo = Color(0.72, 0.82, 0.9)
	env.volumetric_fog_anisotropy = 0.75
	env.volumetric_fog_length = 200.0
	env.volumetric_fog_ambient_inject = 0.1
	# sem SDFGI: debaixo das copas ele deixava a sombra preta; a luz do céu direta dá o ar pintado
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.06
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95
	env.adjustment_contrast = 1.05
	if mundo_grande:
		env.fog_density = 0.00028
		env.fog_aerial_perspective = 0.75
		env.volumetric_fog_density = 0.0007
		env.volumetric_fog_length = 420.0
		env.volumetric_fog_anisotropy = 0.8
		# nuvens pintadas no céu
		var nuvens := NoiseTexture2D.new()
		nuvens.width = 1024
		nuvens.height = 512
		nuvens.seamless = true
		var rn := FastNoiseLite.new()
		rn.frequency = 0.006
		rn.fractal_octaves = 5
		nuvens.noise = rn
		var rampa := Gradient.new()
		rampa.set_color(0, Color(0, 0, 0, 0))
		rampa.set_color(1, Color(1.0, 0.96, 0.9, 0.85))
		rampa.set_offset(0, 0.52)
		rampa.set_offset(1, 0.78)
		nuvens.color_ramp = rampa
		ceu.sky_cover = nuvens
		ceu.sky_cover_modulate = Color(0.95, 0.9, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-34.0, 150.0, 0.0) if mundo_grande else Vector3(-44.0, 165.0, 0.0)
	sol.light_color = Color(1.0, 0.90, 0.74)
	sol.light_energy = 2.8
	sol.light_volumetric_fog_energy = 1.2
	sol.shadow_enabled = true
	sol.shadow_opacity = 0.86
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sol.directional_shadow_max_distance = 320.0
	sol.directional_shadow_blend_splits = true
	add_child(sol)
	var vp := get_viewport()
	vp.use_taa = true
	vp.msaa_3d = Viewport.MSAA_DISABLED


## O vale: dia claro de floresta temperada, céu azul com nuvens grandes, sombra azulada, distância
## que clareia. A luz em faixas vem dos shaders vale_*.
func _ambiente_vale() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ceu := ProceduralSkyMaterial.new()
	ceu.sky_top_color = Color(0.14, 0.30, 0.58)
	ceu.sky_horizon_color = Color(0.62, 0.78, 0.90)
	ceu.ground_horizon_color = Color(0.62, 0.78, 0.90)
	ceu.ground_bottom_color = Color(0.30, 0.42, 0.40)
	ceu.sky_curve = 0.12
	ceu.sun_angle_max = 20.0
	var nuvens := NoiseTexture2D.new()
	nuvens.width = 1024
	nuvens.height = 512
	nuvens.seamless = true
	var rn := FastNoiseLite.new()
	rn.frequency = 0.005
	rn.fractal_octaves = 4
	nuvens.noise = rn
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1, 1, 1, 0))
	rampa.set_color(1, Color(1.0, 0.98, 0.95, 0.95))
	rampa.set_offset(0, 0.55)
	rampa.set_offset(1, 0.66)
	nuvens.color_ramp = rampa
	ceu.sky_cover = nuvens
	var sky := Sky.new()
	sky.sky_material = ceu
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.52, 0.66)  # sombra azulada
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.80, 0.92)
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.98
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-42.0, 135.0, 0.0)
	sol.light_color = Color(1.0, 0.94, 0.82)
	sol.light_energy = 1.05
	sol.shadow_enabled = true
	sol.shadow_opacity = 1.0
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sol.directional_shadow_max_distance = 170.0
	sol.directional_shadow_blend_splits = true
	add_child(sol)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().use_debanding = true
	ciclo = CicloDia.new()
	ciclo.env = env
	ciclo.ceu = ceu
	ciclo.sol = sol
	ciclo.rampa_nuvens = rampa
	add_child(ciclo)


## Troca os materiais de um modelo do vale pelos do estilo (pelo nome do material do Blender).
func _pintar(no: Node, c: Clareira) -> void:
	if no is MeshInstance3D:
		var mi := no as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m:
				mi.set_surface_override_material(s, c.material(m.resource_name))
	for f in no.get_children():
		_pintar(f, c)


func _ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ceu := ProceduralSkyMaterial.new()
	ceu.sky_top_color = Color(0.20, 0.36, 0.62)
	ceu.sky_horizon_color = Color(0.64, 0.72, 0.80)
	ceu.ground_horizon_color = Color(0.64, 0.72, 0.80)
	ceu.ground_bottom_color = Color(0.22, 0.26, 0.30)
	ceu.sky_curve = 0.12
	ceu.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = ceu
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.64, 0.72, 0.80)
	env.fog_density = 0.00045
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-36.0, -40.0, 0.0)
	sol.light_color = Color(1.0, 0.94, 0.84)
	sol.light_energy = 1.7
	sol.shadow_enabled = true
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sol.directional_shadow_max_distance = 380.0
	sol.directional_shadow_blend_splits = true
	add_child(sol)
