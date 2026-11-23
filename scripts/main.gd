class_name Main
extends Node3D
## Etapa 1, primeiro voo: monta tudo por código (céu, sol, ilha de teste, armadura, câmera e tela).
## Modos: `-- --teste` (testes sem janela, com --headless) e `-- --captura` (fotos em tools/capturas/).
## O jogo é o vale (`scripts/vale/`); a ilha pequena fica para a bateria do voo. Os mapas antigos (ilha de
## 4 km e os dois cânions) saíram em 2026-11-15 e estão no histórico do git.

static var mapa := ""
static var simulacao := false  # rodando o tutorial (o mundo vazio "dentro da cabeça do robô")
static var pedido := ""  # "sim" ou "mundo": o que montar ao recarregar a cena (trocar_mundo)
static var abertura_vista := false  # a tela de abertura já apareceu neste processo
static var mundo_montado := false  # o vale já foi montado neste processo (montar de novo pede reabrir o jogo)

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
var aves_ceu: AvesCeu
var peixes_raso: PeixesRaso
var vida_longe: VidaLonge
var insetos: Insetos
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
var farol: FarolFinal
var robo_antigo: RoboAntigo
var acoes: AcoesLugar
var minis: MiniRobos
var cartao_peca: CartaoPeca
var ninho: NinhoAve
var torre: MastroRadio
var cenas_vista: CenasVista
var musica: MusicaPasseio
var rotas: Rotas  # as rotas do piloto de teste (1.1, doc §136)
var experiencia: Experiencia  # a experiência das descobertas, o fôlego e o cartão do nível (doc §148)
var acampamentos: Acampamentos
var procurados: Procurados
var quadro: QuadroAvisos
var radio_base: RadioBase
var horta: Horta
var album: Album
var clima: Clima
var raposa_amiga: RaposaAmiga
var pedidos: Pedidos
var luzes_noite: LuzesNoite
var retomou_em := Vector3.INF  # onde o robô foi posto ao abrir, pelo save (testes)
var _ultimo_firme := Vector3.INF
var _ultimo_yaw := 0.0
var _firme_t := 0.0
var dicas_no: Dicas
var historia: Historia  # o prólogo e o despertar (a história de abertura, doc §134)
var tutor: Tutor


func _input(event: InputEvent) -> void:
	Botoes.observar(event)  # qual aparelho o jogador está usando: as imagens de botão acompanham


func _ready() -> void:
	Controles.configurar()
	Botoes.comecar()
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
	Corpo.zerar()
	Corpo.tudo = Melhorias.tudo  # nos testes e nas fotos todos os conjuntos do corpo abertos
	# a simulação: pedida pela pausa, pela linha de comando, ou num jogo novo (nunca visto e nenhum lugar visitado)
	var novo: bool = Guardado.ativo and not bool(Guardado.progresso("simulacao_vista")) and (Guardado.progresso("lugares") as Array).is_empty()
	# a história (2026-11-21): num jogo novo a ilha abre primeiro, para o prólogo, e só depois vem a simulação;
	# na primeira volta da simulação, o despertar
	var prologo_visto := bool(Guardado.progresso("prologo_visto")) if Guardado.ativo else false
	var prologo_agora: bool = pedido == "" and not ("--simulacao" in args) and ((novo and not prologo_visto) or "--prologo" in args)
	simulacao = pedido == "sim" or (pedido == "" and ("--simulacao" in args or (novo and not prologo_agora)))
	var despertar_agora: bool = not simulacao and not prologo_agora and (("--despertar" in args) or (Guardado.ativo and prologo_visto
		and bool(Guardado.progresso("simulacao_vista")) and not bool(Guardado.progresso("despertar_visto"))))
	pedido = ""
	Guardado.sem_progresso = simulacao  # na simulação o robô ganha peças e armas de treino: nada disso é gravado
	if Guardado.ativo and not simulacao:
		Melhorias.carregar()
		Arsenal.carregar()
		Corpo.carregar()
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
	if simulacao:
		mapa = "simulacao"
		_ambiente_vale()
		ciclo.hora = 12.0
		ciclo.parado = true
		ilha = SimMapa.new()
	elif mapa == "clareira":
		_ambiente_vale()
		ilha = Clareira.new() if "--so-clareira" in args else Vale.new()
		mundo_montado = true
	else:
		_ambiente()
		ilha = Ilha.new()
	var vale := mapa != "ilha"
	Armadura.porte = 0.48 if vale else 1.0
	if not vale:
		Melhorias.tudo = true  # a ilha pequena de teste não tem peças
		Arsenal.tudo = true
	Armadura.vel_chao = 0.7 if vale else 1.0
	# andar e correr um pouco acima do que eram (2,1 e 6,3 m/s), pedido de 2026-11-19
	Armadura.vel_andar = 3.0 if vale else 0.0
	Armadura.vel_correr = 7.5 if vale else 0.0
	ArmaduraVisual.MODELO = "res://assets/vale/robo_v2.glb"  # o robô provisório (Tripo + Mixamo) saiu do jogo em 2026-11-20
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
		# na pane o drone deixa o robô num chão seguro a uns 100 m, e não mais na base (2026-11-21)
		var vale_resgate := ilha as Vale
		armadura.achar_resgate = func(p: Vector3) -> Vector3:
			return LugarSeguro.achar(vale_resgate, p, armadura.get_world_3d().direct_space_state, get_tree())
	camera = CameraVoo.new()
	camera.name = "Camera"
	camera.alvo = armadura
	camera.ilha = ilha
	camera.yaw = ilha.spawn_yaw
	add_child(camera)
	armadura.camera = camera
	if ciclo:
		ciclo.camera = camera
		ciclo.mapa = ilha
		ciclo.nevoa_longe = ilha is Vale  # aqui o mapa já existe
		if CicloDia.estilo_novo:
			# visual novo: o fundo desfoca de leve (a mata distante vira mancha macia) e há pólen no ar
			var lente := CameraAttributesPractical.new()
			lente.dof_blur_far_enabled = true
			lente.dof_blur_far_distance = 160.0
			lente.dof_blur_far_transition = 500.0
			lente.dof_blur_amount = 0.03
			camera.cam.attributes = lente
			if ilha is Clareira:
				add_child(PoeiraLuz.new())
				var petalas := PetalasAr.new()
				petalas.mapa = ilha
				add_child(petalas)
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
			hud.memorias = memorias
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
		if ilha is Vale:
			luzes_noite = LuzesNoite.new()
			luzes_noite.name = "LuzesNoite"
			add_child(luzes_noite)
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
		# (ficava em -62, -56, a 120 m da base e na direção natural da primeira caminhada; 2026-11-19)
		mecha.casa = Vector3(-128, ilha.altura(-128, -118), -118)
		mecha.semente = 5
		mecha.iniciante = true  # o primeiro que o jogador acha: o mais fácil do jogo (2026-11-21)
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
			inimigos.hud = hud
			add_child(inimigos)
			# a vida vista do alto (2026-11-22): peixes rente à água, pássaros no céu, os bichos de terra de longe e,
			# perto do robô, borboletas e libélulas
			peixes_raso = PeixesRaso.new()
			peixes_raso.name = "PeixesRaso"
			peixes_raso.mapa = ilha
			peixes_raso.alvo = armadura
			add_child(peixes_raso)
			peixes_raso.saltou.connect(func(pos: Vector3) -> void: agua_fx._anel(pos, 0.15, 1.3, 0.7, 0.75))
			aves_ceu = AvesCeu.new()
			aves_ceu.name = "AvesCeu"
			aves_ceu.mapa = ilha
			aves_ceu.pontos_mar = peixes_raso.pontos_mar()
			add_child(aves_ceu)
			vida_longe = VidaLonge.new()
			vida_longe.name = "VidaLonge"
			vida_longe.vida = vida
			add_child(vida_longe)
			insetos = Insetos.new()
			insetos.name = "Insetos"
			insetos.mapa = ilha
			insetos.alvo = armadura
			add_child(insetos)
	# nas fotos as dicas ficam de fora, a não ser que se peça (`--dicas`)
	if ilha is Vale and (not ("--vale-captura" in args) or "--dicas" in args):
		var dicas := Dicas.new()
		dicas.name = "Dicas"
		dicas.armadura = armadura
		dicas.hud = hud
		dicas.drone = drone
		dicas.pecas = pecas
		dicas.memorias = memorias
		add_child(dicas)
		dicas_no = dicas
	if ilha is Vale and BaseVale.boca_cilindro.is_finite():
		var cilindros := CilindrosBase.new()
		cilindros.name = "CilindrosBase"
		add_child(cilindros)
		acoes = AcoesLugar.new()
		acoes.name = "AcoesLugar"
		acoes.armadura = armadura
		acoes.hud = hud
		acoes.mapa = ilha as Vale
		acoes.camera = camera
		acoes.locais = locais
		add_child(acoes)
		cenas_vista = CenasVista.new()
		cenas_vista.name = "CenasVista"
		cenas_vista.armadura = armadura
		cenas_vista.camera = camera
		add_child(cenas_vista)
		musica = MusicaPasseio.new()
		musica.name = "MusicaPasseio"
		musica.armadura = armadura
		musica.mapa = ilha
		musica.locais = locais
		musica.memorias = memorias
		add_child(musica)
		rotas = Rotas.new()
		rotas.name = "Rotas"
		rotas.armadura = armadura
		rotas.hud = hud
		rotas.mapa = ilha as Vale
		add_child(rotas)
		armadura.golpe_chao.connect(rotas.no_golpe)
		experiencia = Experiencia.new()
		experiencia.name = "Experiencia"
		experiencia.armadura = armadura
		experiencia.hud = hud
		experiencia.locais = locais
		add_child(experiencia)
		acampamentos = Acampamentos.new()
		acampamentos.name = "Acampamentos"
		acampamentos.mapa = ilha as Vale
		acampamentos.armadura = armadura
		acampamentos.hud = hud
		acampamentos.vida = vida
		add_child(acampamentos)
		procurados = Procurados.new()
		procurados.name = "Procurados"
		procurados.mapa = ilha as Vale
		procurados.armadura = armadura
		procurados.hud = hud
		add_child(procurados)
		quadro = QuadroAvisos.new()
		quadro.name = "QuadroAvisos"
		quadro.procurados = procurados
		add_child(quadro)
		radio_base = RadioBase.new()
		radio_base.name = "RadioBase"
		radio_base.armadura = armadura
		radio_base.hud = hud
		add_child(radio_base)
		horta = Horta.new()
		horta.name = "Horta"
		horta.mapa = ilha as Vale
		horta.armadura = armadura
		horta.hud = hud
		horta.acampamentos = acampamentos
		add_child(horta)
		album = Album.new()
		album.name = "Album"
		album.armadura = armadura
		album.camera = camera
		album.scanner = scanner
		album.hud = hud
		album.mapa = ilha as Vale
		add_child(album)
		clima = Clima.new()
		clima.name = "Clima"
		clima.ciclo = ciclo
		clima.camera = camera
		clima.mapa = ilha as Vale
		add_child(clima)
		raposa_amiga = RaposaAmiga.new()
		raposa_amiga.name = "RaposaAmiga"
		raposa_amiga.armadura = armadura
		raposa_amiga.hud = hud
		raposa_amiga.mapa = ilha as Vale
		raposa_amiga.vida = vida
		add_child(raposa_amiga)
		pedidos = Pedidos.new()
		pedidos.name = "Pedidos"
		pedidos.quadro = quadro
		pedidos.armadura = armadura
		pedidos.hud = hud
		pedidos.rotas = rotas
		pedidos.scanner = scanner
		pedidos.horta = horta
		pedidos.acampamentos = acampamentos
		add_child(pedidos)
		_anotar_pontos()
		if memorias:
			ninho = NinhoAve.new()
			ninho.name = "NinhoAve"
			ninho.armadura = armadura
			ninho.hud = hud
			ninho.memorias = memorias
			ninho.mapa = ilha
			add_child(ninho)
			torre = MastroRadio.new()
			torre.name = "MastroRadio"
			torre.armadura = armadura
			torre.hud = hud
			torre.memorias = memorias
			torre.mapa = ilha as Vale
			add_child(torre)
		if memorias and pecas:
			minis = MiniRobos.new()
			minis.name = "MiniRobos"
			minis.armadura = armadura
			minis.hud = hud
			minis.memorias = memorias
			minis.pecas = pecas
			minis.mapa = ilha
			add_child(minis)
		if memorias and pecas:
			robo_antigo = RoboAntigo.new()
			robo_antigo.name = "RoboAntigo"
			robo_antigo.armadura = armadura
			robo_antigo.hud = hud
			robo_antigo.memorias = memorias
			robo_antigo.pecas = pecas
			add_child(robo_antigo)
	if ilha is Vale and memorias:
		farol = FarolFinal.new()
		farol.name = "FarolFinal"
		farol.armadura = armadura
		farol.hud = hud
		farol.memorias = memorias
		farol.dicas = dicas_no
		add_child(farol)
	if simulacao:
		(ilha as SimMapa).alvo = armadura
		hud.simples = true
		_ceu_da_simulacao()
		# as armas, para a estação de combate (os alvos de treino estão no grupo "maquinas")
		tiro = Tiro.new()
		tiro.armadura = armadura
		add_child(tiro)
		hud.tiro = tiro
		tiro.hud = hud
		hud.tiro_no = tiro
		var roda_sim := RodaArmas.new()
		roda_sim.name = "RodaArmas"
		roda_sim.armadura = armadura
		roda_sim.hud = hud
		add_child(roda_sim)
		tiro.disparou.connect(sons.ao_atirar)
		tiro.disparou.connect(vibra.ao_atirar)
		armadura.golpe_chao.connect(func(onde: Vector3) -> void: get_tree().call_group("maquinas", "levar_impacto", onde))
		tutor = Tutor.new()
		tutor.name = "Tutor"
		tutor.armadura = armadura
		tutor.camera = camera
		tutor.mapa = ilha as SimMapa
		tutor.tiro = tiro
		tutor.carga = carga
		tutor.livre_de_cara = Guardado.ativo and (bool(Guardado.progresso("simulacao_vista")) or not (Guardado.progresso("lugares") as Array).is_empty())
		camada.add_child(tutor)
	# a janela de peça nova só existe no jogo de verdade (nos testes e nas fotos ela pararia tudo)
	if Guardado.ativo and not simulacao:
		cartao_peca = CartaoPeca.new()
		cartao_peca.name = "CartaoPeca"
		add_child(cartao_peca)
		CartaoPeca.ativo = cartao_peca
	pausa = Pausa.new()
	pausa.armadura = armadura
	pausa.na_simulacao = simulacao
	add_child(pausa)
	if tutor:
		tutor.basico_feito.connect(pausa.perguntar_acordar)
	if ilha is Vale:
		historia = Historia.new()
		historia.name = "Historia"
		historia.principal = self
		historia.armadura = armadura
		historia.camera = camera
		historia.hud = hud
		historia.drone = drone
		historia.ciclo = ciclo
		historia.mapa = ilha as Vale
		historia.parar = [locais, pecas, dicas_no, inimigos, fundicao, acoes, minis, ninho, torre, robo_antigo, farol, oficina, scanner, cenas_vista, musica, rotas, acampamentos, procurados, horta]
		for c in get_children():
			if c is LimiteMar or c is Mecha:
				historia.parar.append(c)
		add_child(historia)
		historia.terminou.connect(_historia_terminou)
	aplicar_ajustes()
	if not simulacao:
		_retomar_progresso()
	set_process(true)

	if carga != null:
		carga.fechar()
	# a tela de abertura: uma vez por vez que o jogo abre (não na volta da simulação nem depois de recomeçar)
	var abre: bool = Guardado.ativo and not abertura_vista and not ("--sem-abertura" in OS.get_cmdline_args()) and DisplayServer.get_name() != "headless"
	if abre:
		abertura_vista = true
		_abrir_abertura()
	# a história: para tudo já, antes do primeiro quadro (senão a Clareira contava como visitada no jogo novo)
	if historia and (prologo_agora or despertar_agora):
		historia.parar_tudo()
		if not abre:
			historia.cobrir()  # sem a tela de abertura (depois de Novo jogo, ou na volta da simulação): começa no escuro
		_rodar_historia("prologo" if prologo_agora else "despertar", abre)
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


## A simulação não tem céu de verdade: o ciclo do dia para (ele repintaria o céu do vale a cada quadro) e entra
## um escuro fechado, com o horizonte da cor do chão. O sol fica, para o robô continuar bem iluminado.
func _ceu_da_simulacao() -> void:
	if ciclo == null or ciclo.env == null:
		return
	ciclo.set_process(false)
	var env: Environment = ciclo.env
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/sim_ceu.gdshader")
	env.sky.sky_material = mat
	env.fog_enabled = false
	env.ambient_light_color = Color(0.5, 0.68, 0.74)
	env.ambient_light_energy = 0.95
	env.adjustment_saturation = 1.0
	if sol:
		sol.light_color = Color(0.92, 0.98, 1.0)
		sol.light_energy = 1.0
		sol.rotation_degrees = Vector3(-52.0, 150.0, 0.0)


## A abertura espera um instante: o robô é posto onde parou e a câmera assenta atrás dele, para a tela abrir
## sobre a paisagem (pausando no primeiro quadro, a câmera ainda estava no meio do mar).
func _abrir_abertura() -> void:
	armadura.travado = true
	for i in 45:
		await get_tree().process_frame
	armadura.travado = false
	if pausa and pausa.pode_abrir():
		pausa.abrir_abertura()


## A história começa depois de a ilha assentar e, se a tela de abertura apareceu, depois de ela fechar.
func _rodar_historia(qual: String, abre: bool) -> void:
	for i in 50:
		await get_tree().process_frame
	if abre:
		while is_instance_valid(pausa) and (pausa.visible or get_tree().paused):
			await get_tree().process_frame
		for i in 6:
			await get_tree().process_frame
	if qual == "prologo":
		historia.prologo()
	else:
		historia.despertar()


## "A história", na tela de abertura: o prólogo de novo; no fim a abertura volta.
func ver_historia() -> void:
	if historia:
		historia.prologo(true)


func _historia_terminou(qual: String) -> void:
	if qual == "prologo" and historia.rever:
		for i in 20:
			await get_tree().process_frame
		if pausa and pausa.pode_abrir():
			pausa.abrir_abertura()


## Vai da simulação para o mundo ou do mundo para a simulação. A cena é recarregada; só montar o vale pela
## segunda vez no mesmo processo é que pede reabrir o jogo (muita coisa dele vive em variáveis estáticas).
func trocar_mundo(para_sim: bool) -> void:
	if simulacao and not para_sim:
		Guardado.por_progresso("simulacao_vista", true)
	elif not simulacao:
		guardar_progresso()
	get_tree().paused = false
	if not para_sim and mundo_montado and DisplayServer.get_name() != "headless":
		var a: Array = []
		for x in OS.get_cmdline_args():
			if x == "--":
				break
			if x != "--sem-abertura":
				a.append(x)
		a.append("--sem-abertura")
		OS.set_restart_on_exit(true, PackedStringArray(a))
		get_tree().quit()
		return
	pedido = "sim" if para_sim else "mundo"
	mapa = ""
	get_tree().reload_current_scene()


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
	# retoma onde o robô estava (o último chão firme), e não mais sempre na base
	var pos_g = Guardado.progresso("posicao")
	if pos_g is Array and (pos_g as Array).size() >= 4 and ilha is Vale:
		var onde := Vector3(float(pos_g[0]), float(pos_g[1]), float(pos_g[2]))
		var no_mapa: bool = maxf(absf(onde.x), absf(onde.z)) < Vale.F_META - 20.0 \
				or ((ilha as Vale).terra_nova != null and (ilha as Vale).terra_nova.cobre(onde.x, onde.z))
		if no_mapa and ilha.agua(onde.x, onde.z) == -INF:
			# se o relevo mudou de uma versão para outra e o ponto ficou enterrado, sobe para o chão de agora
			onde.y = maxf(onde.y, ilha.altura(onde.x, onde.z)) + 0.4
			armadura.teleportar(onde, Armadura.Estado.AR)
			camera.yaw = float(pos_g[3])
			retomou_em = onde
	if locais:
		var vistos: Array = Guardado.progresso("lugares")
		for it in locais.lista:
			if vistos.has(it["nome"]):
				it["visto"] = true
		locais.chegou.connect(func(_nome: String, primeira: bool) -> void:
			if primeira:
				guardar_progresso())


func guardar_progresso() -> void:
	if not Guardado.ativo or simulacao:
		return
	if ciclo:
		Guardado.por_progresso("hora", ciclo.hora, false)
	Guardado.por_progresso("energia_base", Melhorias.energia, false)
	if _ultimo_firme.is_finite():
		Guardado.por_progresso("posicao", [_ultimo_firme.x, _ultimo_firme.y, _ultimo_firme.z, _ultimo_yaw], false)
	if locais:
		var vistos: Array = []
		for it in locais.lista:
			if it["visto"]:
				vistos.append(it["nome"])
		Guardado.por_progresso("lugares", vistos, false)
	Guardado.salvar()


## O último chão firme em que o robô esteve: é onde o jogo retoma. Não vale no ar, na água, em pane, preso
## (oficina, drone instalando) nem com a Fundição ligada (voltar para o meio de uma onda seria um castigo, e
## sair e entrar seria um jeito de fugir dela).
func _anotar_firme() -> void:
	if armadura == null or simulacao or not (ilha is Vale):
		return
	if armadura.estado != Armadura.Estado.CHAO or not armadura.is_on_floor() or armadura.em_pane or armadura.travado:
		return
	if fundicao and fundicao.fase != Fundicao.Fase.PARADA:
		return
	_ultimo_firme = armadura.global_position
	_ultimo_yaw = camera.yaw if camera else 0.0


func _process(delta: float) -> void:
	_firme_t += delta
	if _firme_t >= 1.0:
		_firme_t = 0.0
		_anotar_firme()
	# a hora do dia é guardada de minuto em minuto; os lugares, na hora em que são achados
	_guardar_t += delta
	if _guardar_t >= 60.0:
		_guardar_t = 0.0
		guardar_progresso()


func _notification(o_que: int) -> void:
	if o_que == NOTIFICATION_WM_CLOSE_REQUEST or o_que == NOTIFICATION_PREDELETE:
		if is_inside_tree() and is_processing():
			guardar_progresso()


## Anota em `PontosIlha` as coisas para achar e para começar na ilha (pedido do usuário, 2026-11-21: nada perto
## demais de outra coisa). Espera os sistemas que acham o lugar depois de alguns quadros (memórias, rotas).
func _anotar_pontos() -> void:
	PontosIlha.zerar()
	for i in 90:
		await get_tree().physics_frame
		if i >= 10 and (rotas == null or not rotas.lista.is_empty()):
			break
	if pecas:
		for k: String in pecas.onde:
			PontosIlha.anotar("peca:" + k, pecas.onde[k])
	if memorias:
		for k: String in memorias.onde:
			PontosIlha.anotar("memoria:" + k, memorias.onde[k])
		for k: String in memorias.onde_faisca:
			PontosIlha.anotar("lembranca:" + k, memorias.onde_faisca[k])
	if rotas:
		for id: String in rotas.lista:
			PontosIlha.anotar("baliza:" + id, rotas.lista[id]["baliza"])
	if procurados:
		for id: String in procurados.tocas:
			PontosIlha.anotar("toca:" + id, procurados.tocas[id]["centro"])
	if acampamentos:
		for id: String in acampamentos.camps:
			PontosIlha.anotar("acampamento:" + id, acampamentos.camps[id]["centro"])
	if robo_antigo:
		for i in robo_antigo.estatuas.size():
			if robo_antigo.estatuas[i] and is_instance_valid(robo_antigo.estatuas[i]):
				PontosIlha.anotar("robo:%d" % i, robo_antigo.estatuas[i].global_position)
	if minis:
		PontosIlha.anotar("robozinhos", minis.no_escuro)
	if torre:
		PontosIlha.anotar("receptor", torre.receptor)
	if ninho:
		PontosIlha.anotar("ninho", ninho.tampo)
	PontosIlha.pronto = true
