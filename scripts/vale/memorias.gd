class_name Memorias
extends Node3D
## As memórias (2026-11-18): nos dez lugares que não têm peça, um pequeno cristal âmbar guarda uma lembrança.
## Tocando nele o jogo para, a tela escurece e aparece um texto curto sobre o lugar, com uma música leve.
## A história é a que o usuário contou (doc §87): gente boa tentando melhorar o mundo, sem vilão; os humanos
## se foram, a natureza tomou o lugar, e o Faísca passou a consciência ao robô que jogamos.
## Dá para reler: a memória continua no lugar, mais apagada.

const PEGA := 1.3
const AMBAR := Color(1.0, 0.72, 0.32)
const TINTA := Color(0.93, 0.94, 0.9)
const APAGADO := Color(0.62, 0.68, 0.66)
const LARANJA := Color(1.0, 0.62, 0.3)

## chave -> [título, texto]
const TEXTOS := {
	"cachoeira": ["A água que ficou",
		"Vieram aqui medir a força da queda. Queriam luz para uma cidade inteira sem queimar nada.\n\nAnotaram tudo com cuidado, durante três verões. No último, alguém escreveu na margem do caderno: \"e se a gente só deixasse ela cair?\"\n\nNão construíram nada neste lugar. Foi uma das poucas decisões de que ninguém se arrependeu."],
	"serra": ["O ponto mais alto",
		"Daqui se via a ilha inteira, e era para isso que subiam. Traziam mapas, café e discussões compridas sobre onde pôr cada coisa.\n\nNinguém queria estragar a vista. Por isso as torres ficaram na costa, a represa num vale escondido, e o cume ficou como estava.\n\nÀs vezes subiam só para ficar quietos."],
	"sumidouro": ["O que a terra guarda",
		"Desceram com cordas e lanternas, procurando um lugar fresco e estável para guardar energia.\n\nAcharam o salão, a lagoa e um silêncio que ninguém esperava. Uma das engenheiras pediu para desligarem as luzes por um minuto. Ficaram todos no escuro, ouvindo a água pingar.\n\nO projeto mudou de lugar. O salão ficou para os morcegos."],
	"arcos": ["A água que andava",
		"Os arcos já eram velhos quando eles chegaram. Outra gente, muito antes, tinha tentado a mesma coisa: levar água de onde sobra para onde falta.\n\nIsso deu a todos uma alegria estranha. Queria dizer que a vontade de ajudar não tinha começado com eles.\n\nConsertaram dois pilares e deixaram um bilhete numa fresta, para quem viesse depois."],
	"represa": ["A parede que cedeu",
		"A represa foi o maior trabalho da ilha. Deu luz por muitos anos e nunca fez mal a ninguém.\n\nQuando a rachadura apareceu, já não havia quem a consertasse. A água foi abrindo o caminho dela, devagar, sem pressa e sem raiva.\n\nHoje o córrego corre como corria antes de tudo. A parede ficou de lembrança: foi boa enquanto durou."],
	"rele": ["Alô, alguém aí?",
		"Desta torre falavam com o mundo. Mandavam o que aprendiam, de graça, para quem quisesse ouvir.\n\nCom o tempo as respostas foram rareando. Continuaram transmitindo assim mesmo, todas as manhãs: o que tinha dado certo, o que não tinha, e o tempo que fazia na ilha.\n\nA última mensagem dizia só: \"hoje o mar está lindo.\""],
	"fenda": ["O corte",
		"Abriram a terra aqui atrás de um minério que faria baterias melhores. Era para durar dez anos.\n\nDurou dois. No fundo, acharam uma nascente, e nenhum deles teve coragem de seguir cavando.\n\nFecharam as máquinas, plantaram o que deu e foram embora desta parte da ilha. As árvores do fundo são netas daquelas mudas."],
	"torres": ["O vento trabalha de graça",
		"Cada torre tinha nome. Quem as montou batizou a primeira com o nome da filha e a ideia pegou.\n\nElas giraram por muito tempo depois que todos se foram, acendendo lâmpadas em casas vazias. Uma a uma, foram parando.\n\nDuas ainda giram. Ninguém sabe dizer por quê. Talvez só gostem do vento."],
	"observatorio": ["Olhando para cima",
		"Não era para achar nada de útil. Construíram porque alguém disse que um lugar que só olha para os próprios problemas acaba ficando triste.\n\nNas noites limpas a ilha inteira subia o morro. Os robôs também vinham, e ficavam olhando sem entender bem o quê.\n\nO telescópio ainda aponta para a última estrela que escolheram."],
	"casco": ["O último barco",
		"Este navio trazia peças e levava gente. Na última viagem veio vazio e ninguém embarcou.\n\nFaísca esperou no cais por muitas marés. Depois puxou o barco para a areia, para o mar não o levar, e sentou ao lado.\n\nFoi aqui que ele decidiu continuar. Havia uma ilha inteira para cuidar, e alguém precisava se lembrar deles."],
	"robo_mergulhador": ["O que segurava a comporta",
		"Este cuidava da represa por baixo d'água, onde ninguém mais descia. Abria e fechava a comporta do fundo, tirava galho, media a parede com a mão.\n\nNo dia em que a rachadura abriu, ele desceu e segurou a comporta para a água sair devagar. Deu certo: a lagoa não desceu de uma vez, e o vale lá embaixo não se assustou.\n\nFicou segurando. A água ainda corre forte por ali, e ele ainda está com a mão na roda.\n\nJá pode soltar. O drone leva para a base."],
	"ave_grande": ["A dona do vento",
		"Ela já fazia ninho por aqui antes da ponte, e continuou depois que a ponte caiu.\n\nQuem trabalhava nas torres dizia que ela mostrava onde o vento era bom: bastava ver por onde ela subia sem bater as asas.\n\nNinguém nunca chegou perto. Ela escolhia os lugares altos, com o mar em volta, onde o ar não deixa motor nenhum funcionar.\n\nAgora ela sabe que tem alguém na ilha de novo. De vez em quando vai passar lá em cima, para ver."],
	"sinal_de_fora": ["Alguém respondeu",
		"Deste mastro eles falaram com o mundo por anos, e as respostas foram rareando até parar.\n\nA antena continuou transmitindo sozinha, e este receptor ficou ligado aqui em cima, esquecido. Gravou tudo o que chegou depois.\n\nQuase tudo é chiado. Mas há uma voz, repetida todas as noites, sempre na mesma hora, vinda de sudoeste, de além do mar:\n\n\"Recebemos. Tem lugar para vocês aqui.\"\n\nA luz que acompanha a voz ainda acende. De noite dá para ver."],
	"robozinhos": ["Os pequenos",
		"Eram cinco, feitos para andar por dentro dos canos e das frestas onde ninguém mais cabia. Passavam o dia correndo pelo salão, um atrás do outro.\n\nQuando as luzes daqui de baixo se apagaram, eles se juntaram num canto, sentaram em roda e ficaram esperando alguém acender de novo.\n\nEsperaram bastante. Não tinham medo do escuro: só não sabiam brincar nele.\n\nAgora foram para a base. Vai ter barulho por lá."],
	# fora das dez: a lembrança do robô anterior, que aparece ao acordá-lo no Observatório (RoboAntigo)
	"robo_antigo": ["O que vinha olhar",
		"Este robô subia o morro quase toda noite. Não tinha tarefa nenhuma aqui: vinha porque gostava.\n\nSentava sempre neste mesmo lugar, ao pé do telescópio, e ficava olhando pela fenda até o céu clarear. Quem trabalhava aqui deixava a porta aberta para ele.\n\nQuando todos se foram, ele continuou vindo. Numa dessas noites a bateria acabou no meio do caminho das estrelas, e ele ficou.\n\nAinda dá para acordá-lo. O drone leva para a base."],
}
const ORDEM := ["cachoeira", "serra", "sumidouro", "arcos", "represa", "rele", "fenda", "torres", "observatorio", "casco"]

var armadura: Armadura
var mapa: Vale
var hud: Hud
var pecas: PecasMundo
var onde := {}  # chave -> Vector3
var lidas: Array = []
var aberta := ""  # a memória que está na tela agora
var aberturas := 0  # quantas vezes uma memória foi aberta (testes)

var _nos := {}
var _t := 0.0
var _saiu := {}  # chave -> o robô já se afastou depois de ler (para não reabrir em cima)
var _camada: CanvasLayer
var _titulo: Label
var _texto: Label
var _conta: Label
var _musica: AudioStreamPlayer
var _fecha_em := 0.0


func _ready() -> void:
	lidas = (Guardado.progresso("memorias") as Array).duplicate() if Guardado.ativo else []
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var alvos := {
		"cachoeira": Vector2(Vale.POCO.x - 24.0, Vale.POCO.y + 20.0),
		"serra": Vector2(mapa.cume.x, mapa.cume.z),
		"arcos": Vector2(Ruinas.ARCOS.x + 10.0, Ruinas.ARCOS.y + 16.0),
		"fenda": FendaEscura.ponto(250.0),
		"torres": (MarcosOeste.TORRES[2] as Vector2) + Vector2(7.0, 9.0),
		"observatorio": MarcosOeste.OBSERVATORIO + Vector2(0.0, MarcosOeste.CUPULA + 7.0),
	}
	for chave: String in alvos:
		onde[chave] = pecas._assentar(alvos[chave])
	# em cima de construções: o passadiço da represa, a plataforma da torre do relé e o convés do navio
	for alto: Array in [["represa", Vector2(MarcosLeste.represa_x(-26.0), MarcosLeste.REPRESA.y - 26.0)],
			["rele", Vector2(MarcosMar.rele_topo.x + 1.5, MarcosMar.rele_topo.z - 1.5)], ["casco", Vector2(MarcosOeste.conves.x, MarcosOeste.conves.z)]]:
		var p := pecas._de_cima(alto[1])
		onde[alto[0]] = p if p.is_finite() else pecas._assentar(alto[1])
	# no salão do Sumidouro, onde a luz do peito faz falta
	var salao := pecas._no_salao()
	onde["sumidouro"] = salao if salao.is_finite() else pecas._assentar(Sumidouro.saida)
	for chave: String in ORDEM:
		var no := _cristal(lidas.has(chave))
		no.position = onde[chave]
		add_child(no)
		_nos[chave] = no
	_montar_tela()


## O cristal: um losango âmbar que gira devagar, com um halo de luz. Lido, fica menor e mais apagado.
func _cristal(lida: bool) -> Node3D:
	var no := Node3D.new()
	var gira := Node3D.new()
	gira.name = "gira"
	gira.position.y = 1.0
	no.add_child(gira)
	var m := PrismMesh.new()
	m.size = Vector3(0.34, 0.5, 0.34)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = AMBAR * (0.45 if lida else 0.8)
	mat.emission_enabled = true
	mat.emission = AMBAR
	mat.emission_energy_multiplier = 0.7 if lida else 2.4
	for sinal: float in [1.0, -1.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position.y = 0.25 * sinal
		mi.rotation.x = 0.0 if sinal > 0.0 else PI
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gira.add_child(mi)
	var luz := OmniLight3D.new()
	luz.light_color = AMBAR
	luz.light_energy = 0.3 if lida else 1.1
	luz.omni_range = 6.0
	luz.shadow_enabled = false
	luz.distance_fade_enabled = true
	luz.distance_fade_begin = 90.0
	luz.distance_fade_length = 30.0
	gira.add_child(luz)
	# de noite, a memória ainda não lida se vê de longe: um ponto âmbar acima do cristal
	if not lida:
		LuzesNoite.por(gira, Vector3(0, 0.9, 0), LuzesNoite.AMBAR, 4.5)
	return no


func _montar_tela() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 20
	_camada.process_mode = Node.PROCESS_MODE_ALWAYS
	_camada.visible = false
	add_child(_camada)
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.045, 0.07, 0.86)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(fundo)
	var meio := CenterContainer.new()
	meio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(meio)
	var coluna := VBoxContainer.new()
	coluna.custom_minimum_size = Vector2(760, 0)
	coluna.add_theme_constant_override("separation", 18)
	meio.add_child(coluna)
	_conta = Label.new()
	_conta.add_theme_font_size_override("font_size", 16)
	_conta.add_theme_color_override("font_color", APAGADO)
	coluna.add_child(_conta)
	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 38)
	_titulo.add_theme_color_override("font_color", LARANJA)
	coluna.add_child(_titulo)
	var risco := ColorRect.new()
	risco.color = Color(LARANJA.r, LARANJA.g, LARANJA.b, 0.6)
	risco.custom_minimum_size = Vector2(64, 2)
	risco.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	coluna.add_child(risco)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(760, 0)
	_texto.add_theme_font_size_override("font_size", 23)
	_texto.add_theme_color_override("font_color", TINTA)
	_texto.add_theme_constant_override("line_spacing", 9)
	coluna.add_child(_texto)
	var rodape := Label.new()
	rodape.text = "X, círculo ou Esc para fechar"
	rodape.add_theme_font_size_override("font_size", 15)
	rodape.add_theme_color_override("font_color", APAGADO)
	coluna.add_child(rodape)
	_musica = AudioStreamPlayer.new()
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/sons/memoria_loop.wav"):
		_musica.stream = Som.laco_stream("memoria_loop")
	_musica.volume_db = -60.0
	add_child(_musica)
	process_mode = Node.PROCESS_MODE_ALWAYS


func abrir(chave: String) -> void:
	if aberta != "" or not TEXTOS.has(chave):
		return
	aberta = chave
	aberturas += 1
	var das_dez: bool = ORDEM.has(chave)
	if das_dez and not lidas.has(chave):
		lidas.append(chave)
		if Guardado.ativo:
			Guardado.por_progresso("memorias", lidas)
	var par: Array = TEXTOS[chave]
	_conta.text = ("MEMÓRIA   ·   %d de %d" % [lidas.size(), ORDEM.size()]) if das_dez else "LEMBRANÇA"
	_titulo.text = par[0]
	_texto.text = par[1]
	_camada.visible = true
	_fecha_em = 0.6  # um instante antes de aceitar o botão, para o aperto que trouxe o robô não fechar
	if hud:
		hud.visible = false
	get_tree().paused = true
	if _musica.stream:
		_musica.play()
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(_musica, "volume_db", -9.0, 1.6)
	# lida: o cristal fica mais apagado
	if _nos.has(chave):
		var velho: Node3D = _nos[chave]
		var novo := _cristal(true)
		novo.position = velho.position
		add_child(novo)
		velho.queue_free()
		_nos[chave] = novo
	_saiu[chave] = false


func fechar() -> void:
	if aberta == "":
		return
	aberta = ""
	_camada.visible = false
	get_tree().paused = false
	if hud:
		hud.visible = true
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_musica, "volume_db", -60.0, 1.2)
	tw.tween_callback(_musica.stop)


func _process(delta: float) -> void:
	if aberta != "":
		_fecha_em -= delta
		if _fecha_em <= 0.0 and (Input.is_action_just_pressed("pular") or Input.is_action_just_pressed("soltar") or Input.is_action_just_pressed("ui_cancel")):
			fechar()
		return
	if get_tree().paused or armadura == null or armadura.em_pane:
		return
	_t += delta
	var p := armadura.global_position + Vector3(0, armadura.altura_corpo() * 0.45, 0)
	for chave: String in _nos:
		var no: Node3D = _nos[chave]
		var gira := no.get_node("gira") as Node3D
		gira.rotation.y = _t * 0.8
		gira.position.y = 1.0 + sin(_t * 1.3 + no.position.x) * 0.12
		var d := p.distance_to(no.position + Vector3(0, 1.0, 0))
		if d > PEGA * 2.5:
			_saiu[chave] = true
		elif d < PEGA and _saiu.get(chave, true) and not armadura.travado:
			abrir(chave)
			return
