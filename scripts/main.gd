class_name Main
extends Node3D
## Etapa 1, primeiro voo: monta tudo por código (céu, sol, ilha de teste, armadura, câmera e tela).
## Modos: `-- --teste` (testes sem janela, com --headless) e `-- --captura` (fotos em tools/capturas/).
## O jogo é o vale (`scripts/vale/`); a ilha pequena fica para a bateria do voo. Os mapas antigos (ilha de
## 4 km e os dois cânions) saíram em 2026-11-15 e estão no histórico do git.

static var mapa := ""

var ilha: Ilha
var armadura: Armadura
var camera: CameraVoo
var hud: Hud
var drone: DroneColega
var pecas: PecasMundo
var oficina: Oficina
var fundicao: Fundicao
var scanner: Scanner
var pausa: Pausa
var vida: VidaVale
var inimigos: InimigosVale
var som_lugar: SomAmbiente
var sons: Sons
var vibra: Vibra
var locais: Locais
var vida_agua: VidaAgua
var memorias: Memorias
var mato: EfeitosMato
var ciclo: CicloDia
var tiro: Tiro
var sol: DirectionalLight3D


func _ready() -> void:
	Controles.configurar()
	var args := OS.get_cmdline_user_args()
	# o robô é desenhado entre dois passos da física (Armadura.pos_suave); o ajuste de tremor do motor mexe no
	# ritmo desses passos e a fração de interpolação deixa de bater com o que foi andado
	Engine.physics_jitter_fix = 0.0
	Tempos.ligado = "--tempos" in args
	Cache.ligado = not ("--sem-cache" in args)
	Tempos.marca("início")
	# nos testes e nas fotos nada é lido nem gravado da última partida
	Guardado.ativo = not ("--teste" in args or "--teste-vale" in args or "--captura" in args or "--vale-captura" in args)
	Guardado.carregar()
	# melhorias: nos testes e nas fotos o robô tem tudo (`--basico` mostra o do começo do jogo)
	Melhorias.tudo = not Guardado.ativo and not ("--basico" in args)
	Melhorias.achadas = []
	Melhorias.instaladas = []
	Arsenal.zerar()
	Arsenal.tudo = Melhorias.tudo
	if Guardado.ativo:
		Melhorias.carregar()
		Arsenal.carregar()
	# no jogo de verdade o mundo é montado atrás da tela de carregamento
	set_process(false)
	var carga: Carregando = null
	if Guardado.ativo or "--carregando" in args:
		carga = Carregando.new()
		add_child(carga)
		await carga.mostrar(0.03, "Lendo o relevo")
	if mapa == "":
		# o vale é o jogo; a ilha pequena fica só para a bateria do voo (--teste) e as fotos antigas
		mapa = "ilha" if ("--teste" in args or "--captura" in args or "--ilha" in args) else "clareira"
	if mapa == "clareira":
		_ambiente_vale()
		ilha = Clareira.new() if "--so-clareira" in args else Vale.new()
	else:
		_ambiente()
		ilha = Ilha.new()
	var vale := mapa == "clareira"
	Armadura.porte = 0.48 if vale else 1.0
	if not vale:
		Melhorias.tudo = true  # a ilha pequena de teste não tem peças
		Arsenal.tudo = true
	Armadura.vel_chao = 0.7 if vale else 1.0
	ArmaduraVisual.MODELO = "res://assets/vale/robo_v1.glb" if vale else "res://assets/armadura/robo_teste_v1.glb"
	ArmaduraVisual.toon = vale
	ilha.name = "Mapa"
	add_child(ilha)
	Tempos.marca("antes de gerar")
	if carga != null:
		ilha.aviso = carga.mostrar
	await ilha.gerar(7)
	if carga != null:
		await carga.mostrar(0.92, "Acordando os bichos e as máquinas")
	Tempos.marca("gerar (total)")
	if Tempos.ligado:
		print("TEMPO desde o início do processo: %d ms (cache: %d lidos, %d gravados)" % [Time.get_ticks_msec(), Cache.lidos, Cache.gravados])
		get_tree().process_frame.connect(func(): print("TEMPO primeiro quadro aos %d ms" % Time.get_ticks_msec()), CONNECT_ONE_SHOT)
		RenderingServer.frame_post_draw.connect(func(): print("TEMPO primeiro desenho aos %d ms" % Time.get_ticks_msec()), CONNECT_ONE_SHOT)
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
	vibra = Vibra.new()
	vibra.armadura = armadura
	add_child(vibra)
	vibra.iniciar()
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
		hud.tiro = tiro
		tiro.hud = hud
		hud.tiro_no = tiro
		var roda := RodaArmas.new()
		roda.name = "RodaArmas"
		roda.armadura = armadura
		roda.hud = hud
		add_child(roda)
		tiro.disparou.connect(sons.ao_atirar)
		tiro.disparou.connect(vibra.ao_atirar)
		mato = EfeitosMato.new()
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
					["A Torre Caída", Vector2(Ruinas.TORRE.x, Ruinas.TORRE.y), 50.0], ["O Pátio das Máquinas", Vector2(Ruinas.PATIO.x, Ruinas.PATIO.y), 45.0],
					# as regiões da ilha de 3 km (2026-11-18); os lugares delas entram nas etapas seguintes
					["Costa Quebrada", Vector2(850, 800), 230.0], ["Encostas do Dique", Vector2(1000, -420), 200.0],
					["Cabo do Vento", Vector2(1150, -1120), 230.0], ["Arquipélago Raso", Vector2(1280, 900), 210.0],
					["Chapada do Sudoeste", Vector2(-830, 1040), 200.0]]:
				var lp: Vector2 = l[1]
				locais.adicionar(l[0], Vector3(lp.x, mapa_vale.altura(lp.x, lp.y), lp.y), l[2])
			for mc: Array in Marcos.lugares:
				var mp: Vector2 = mc[1]
				locais.adicionar(mc[0], Vector3(mp.x, mapa_vale.altura(mp.x, mp.y) + 6.0, mp.y), mc[2])
			if Sumidouro.existe:
				if Sumidouro.morcegos:
					Sumidouro.morcegos.alvo = armadura
				locais.adicionar(Sumidouro.NOME, Vector3(Sumidouro.centro.x, Sumidouro.piso + 14.0, Sumidouro.centro.y), 46.0)
			hud.ligar_locais(locais)
			FendaEscura.ligar(mapa_vale, armadura)
			if not ("--sem-pacotes" in args):
				vida_agua = VidaAgua.new()
				vida_agua.name = "VidaAgua"
				vida_agua.mapa = mapa_vale
				vida_agua.alvo = armadura
				add_child(vida_agua)
			var capim := CapimVivo.new()
			capim.mapa = ilha
			capim.alvo = armadura
			add_child(capim)
		var pane := Pane.new()
		pane.armadura = armadura
		pane.ciclo = ciclo
		add_child(pane)
		if BaseVale.posto_drone.is_finite():
			drone = DroneColega.new()
			drone.name = "DroneColega"
			drone.armadura = armadura
			drone.posto = BaseVale.posto_drone
			drone.ruido = (ilha as Clareira)._tex
			add_child(drone)
		if ilha is Vale:
			pecas = PecasMundo.new()
			pecas.name = "PecasMundo"
			pecas.armadura = armadura
			pecas.mapa = ilha as Vale
			pecas.hud = hud
			pecas.locais = locais
			pecas.drone = drone
			pecas.sons = sons
			add_child(pecas)
			memorias = Memorias.new()
			memorias.name = "Memorias"
			memorias.armadura = armadura
			memorias.mapa = ilha as Vale
			memorias.hud = hud
			memorias.pecas = pecas
			add_child(memorias)
			if BaseVale.boca_cilindro.is_finite():
				oficina = Oficina.new()
				oficina.name = "Oficina"
				oficina.armadura = armadura
				oficina.camera = camera
				oficina.hud = hud
				oficina.sons = sons
				oficina.drone = drone
				add_child(oficina)
			if Fundicao.montada:
				fundicao = Fundicao.new()
				fundicao.name = "Fundicao"
				fundicao.armadura = armadura
				fundicao.hud = hud
				fundicao.sons = sons
				fundicao.mapa = ilha as Vale
				add_child(fundicao)
				if locais:
					locais.adicionar("A Fundição", Vector3(Fundicao.CENTRO.x, Fundicao.PISO + 4.0, Fundicao.CENTRO.y), Fundicao.RAIO + 14.0)
			scanner = Scanner.new()
			scanner.name = "Scanner"
			scanner.armadura = armadura
			scanner.camera = camera
			scanner.hud = hud
			scanner.sons = sons
			scanner.mapa = ilha as Vale
			add_child(scanner)
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
		# máquina agressiva: um mecha rio acima, longe do começo
		var mecha := Mecha.new()
		mecha.mapa = ilha
		mecha.alvo = armadura
		mecha.casa = Vector3(-62, ilha.altura(-62, -56), -56)
		mecha.semente = 5
		add_child(mecha)
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
	pausa = Pausa.new()
	pausa.armadura = armadura
	add_child(pausa)
	aplicar_ajustes()
	_retomar_progresso()
	set_process(true)
	if carga != null:
		carga.fechar()
	if "--teste" in args:
		var t := Testes.new()
		add_child(t)
		t.rodar(self)
	elif "--captura" in args:
		var c := Capturas.new()
		add_child(c)
		c.rodar(self)
	elif "--teste-vale" in args:
		var tv: Node = load("res://scripts/vale/testes_vale.gd").new()
		add_child(tv)
		tv.call("rodar", self)
	elif "--vale-captura" in args:
		var cv: Node = load("res://scripts/vale/capturas_vale.gd").new()
		add_child(cv)
		cv.call("rodar", self)
	else:
		if OS.has_feature("linux"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ambiente_vale() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ceu := ShaderMaterial.new()
	ceu.shader = load("res://scripts/shaders/vale_ceu.gdshader")
	var nuvens := NoiseTexture2D.new()
	nuvens.width = 512
	nuvens.height = 512
	nuvens.seamless = true
	var rn := FastNoiseLite.new()
	rn.frequency = 0.008
	rn.fractal_octaves = 4
	nuvens.noise = rn
	ceu.set_shader_parameter("nuvens", nuvens)
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


const SENSIBILIDADES := [0.5, 0.75, 1.0, 1.35, 1.8]


## Os ajustes guardados valem agora: qualidade do desenho, câmera e vibração. Nas fotos e nos testes a
## qualidade é a alta, para as imagens serem comparáveis.
func aplicar_ajustes() -> void:
	Qualidade.aplicar(self, int(Guardado.ajuste("qualidade")) if Guardado.ativo else 2)
	CameraVoo.fator_sens = SENSIBILIDADES[clampi(int(Guardado.ajuste("sensibilidade")), 0, SENSIBILIDADES.size() - 1)]
	CameraVoo.inverter_y = bool(Guardado.ajuste("inverter_y"))
	Vibra.ligada = bool(Guardado.ajuste("vibra"))


var _guardar_t := 0.0


## O progresso da última partida: os lugares já visitados e a hora do dia.
func _retomar_progresso() -> void:
	if not Guardado.ativo:
		return
	if ciclo:
		ciclo.hora = float(Guardado.progresso("hora"))
	if locais:
		var vistos: Array = Guardado.progresso("lugares")
		for it in locais.lista:
			if vistos.has(it["nome"]):
				it["visto"] = true
		locais.chegou.connect(func(_nome: String, primeira: bool) -> void:
			if primeira:
				guardar_progresso())


func guardar_progresso() -> void:
	if not Guardado.ativo:
		return
	if ciclo:
		Guardado.por_progresso("hora", ciclo.hora, false)
	Guardado.por_progresso("energia_base", Melhorias.energia, false)
	if locais:
		var vistos: Array = []
		for it in locais.lista:
			if it["visto"]:
				vistos.append(it["nome"])
		Guardado.por_progresso("lugares", vistos, false)
	Guardado.salvar()


func _process(delta: float) -> void:
	# a hora do dia é guardada de minuto em minuto; os lugares, na hora em que são achados
	_guardar_t += delta
	if _guardar_t >= 60.0:
		_guardar_t = 0.0
		guardar_progresso()


func _notification(o_que: int) -> void:
	if o_que == NOTIFICATION_WM_CLOSE_REQUEST or o_que == NOTIFICATION_PREDELETE:
		if is_inside_tree() and is_processing():
			guardar_progresso()
