class_name Memorias
extends Node3D
## As memórias (2026-11-18): nos dez lugares que não têm peça, no Sono dos Gigantes (a décima primeira,
## de 2026-11-20) e na frente da Fundição (a décima segunda, de 2026-11-21), um pequeno cristal âmbar guarda
## uma lembrança.
## Tocando nele o jogo para, a tela escurece e aparece um texto curto sobre o lugar, com uma música leve.
## A história é a que o usuário contou (doc §87): gente boa tentando melhorar o mundo, sem vilão; os humanos
## se foram, a natureza tomou o lugar, e o Faísca passou a consciência ao robô que jogamos.
## Dá para reler: a memória continua no lugar, mais apagada.
##
## As lembranças do Faísca (2026-11-22, doc §137.12): seis na terra nova, contadas por ele em primeira pessoa,
## da chegada à vila até a partida para o outro lado, e um fecho que abre depois da sexta. Não contam para o farol
## (`ORDEM` fica com as 12), ficam numa fagulha em vez do cristal e vão para a chave "lembrancas" do save.

const PEGA := 1.3
const FUNDICAO_LADO := Vector2(-36.0, Fundicao.MZ + 14.0)  # do meio da Fundição até a memória dela (x leste, y sul); do lado oeste do patamar, longe do scanner
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
	"gigantes": ["Os que carregavam o pesado",
		"Estes quatro ergueram a represa, o cais e as torres. Trabalhavam devagar, para não assustar os bichos, e paravam a obra inteira quando aparecia um ninho no caminho.\n\nQuando o último serviço acabou, ninguém teve coragem de desmontá-los. Trouxeram os quatro para este campo, onde bate sol o dia todo, e desligaram um por um, agradecendo.\n\nDois pediram para ficar de pé. Dizem que era para continuar vendo o mar."],
	"robo_mergulhador": ["O que segurava a comporta",
		"Este cuidava da represa por baixo d'água, onde ninguém mais descia. Abria e fechava a comporta do fundo, tirava galho, media a parede com a mão.\n\nNo dia em que a rachadura abriu, ele desceu e segurou a comporta para a água sair devagar. Deu certo: a lagoa não desceu de uma vez, e o vale lá embaixo não se assustou.\n\nFicou segurando. A água ainda corre forte por ali, e ele ainda está com a mão na roda.\n\nJá pode soltar. O drone leva para a base."],
	"ave_grande": ["A dona do vento",
		"Ela já fazia ninho por aqui antes da ponte, e continuou depois que a ponte caiu.\n\nQuem trabalhava nas torres dizia que ela mostrava onde o vento era bom: bastava ver por onde ela subia sem bater as asas.\n\nNinguém nunca chegou perto. Ela escolhia os lugares altos, com o mar em volta, onde o ar não deixa motor nenhum funcionar.\n\nAgora ela sabe que tem alguém na ilha de novo. De vez em quando vai passar lá em cima, para ver."],
	"sinal_de_fora": ["Alguém respondeu",
		"Deste mastro eles falaram com o mundo por anos, e as respostas foram rareando até parar.\n\nA antena continuou transmitindo sozinha, e este receptor ficou ligado aqui em cima, esquecido. Gravou tudo o que chegou depois.\n\nQuase tudo é chiado. Mas há uma voz, repetida todas as noites, sempre na mesma hora, vinda de sudoeste, de além do mar:\n\n\"Recebemos. Tem lugar para vocês aqui.\"\n\nA luz que acompanha a voz ainda acende. De noite dá para ver."],
	"robozinhos": ["Os pequenos",
		"Eram cinco, feitos para andar por dentro dos canos e das frestas onde ninguém mais cabia. Passavam o dia correndo pelo salão, um atrás do outro.\n\nQuando as luzes daqui de baixo se apagaram, eles se juntaram num canto, sentaram em roda e ficaram esperando alguém acender de novo.\n\nEsperaram bastante. Não tinham medo do escuro: só não sabiam brincar nele.\n\nAgora foram para a base. Vai ter barulho por lá."],
	# a da Fundição (2026-11-21, da história de abertura): por que os robôs de lá atacam. Fica do lado de fora do
	# galpão, para ler sem começar a horda
	"fundicao": ["A forja que não parou",
		"Aqui se faziam os robôs que ajudavam na ilha. A fábrica era tão bem-feita que trabalhava sozinha: bastava ter sucata e sol.\n\nQuando todos se foram, ninguém desligou as forjas. Elas continuaram montando robôs, sem ninguém para dizer a eles o que fazer.\n\nOs que saem de lá hoje estão confusos. Não sabem para quem trabalham, e se assustam com quem chega.\n\nDesligar um deles não faz mal: ele descansa, e as peças voltam para a ilha."],
	# fora das dez: a lembrança do robô anterior, que aparece ao acordá-lo no Observatório (RoboAntigo)
	"robo_antigo": ["O que vinha olhar",
		"Este robô subia o morro quase toda noite. Não tinha tarefa nenhuma aqui: vinha porque gostava.\n\nSentava sempre neste mesmo lugar, ao pé do telescópio, e ficava olhando pela fenda até o céu clarear. Quem trabalhava aqui deixava a porta aberta para ele.\n\nQuando todos se foram, ele continuou vindo. Numa dessas noites a bateria acabou no meio do caminho das estrelas, e ele ficou.\n\nAinda dá para acordá-lo. O drone leva para a base."],
}
## As lembranças do Faísca: chave -> [título, texto]. A ordem do caderno é a da vida dele; cada uma se lê sozinha.
const TEXTOS_FAISCA := {
	"f_navio": ["Os que chegaram com a tempestade",
		"Este navio encalhou numa noite de tempestade, muito antes de mim.\n\nO povo da vila desceu com lanternas e cobertores. Ninguém perguntou de onde o pessoal do navio vinha. Arrumaram camas na escola e disseram: fiquem, tem lugar.\n\nEra só até a primavera. Ninguém foi embora."],
	"f_oficina": ["O nome",
		"Esta oficina era a casa dos robôs de ajuda da vila. De noite a gente descansava aqui, e de manhã as crianças da escola vinham chamar cada um pelo nome.\n\nO meu, foram elas que inventaram. Disseram que eu soltava faísca quando ria.\n\nEu ainda não sabia rir. Aprendi com elas."],
	"f_turquesa": ["A cor da água",
		"A professora trazia a turma até aqui para explicar a cor deste lago. É pó de pedra, bem fininho, que o gelo mói lá em cima e o rio traz.\n\nAs crianças não acreditavam. Achavam mais bonito dizer que um pedaço do céu tinha caído aqui.\n\nEu mergulhava e trazia um punhado do fundo, para provar. Elas olhavam o pó na minha mão e diziam: viu? É céu."],
	"f_fontes": ["O inverno nas fontes",
		"No inverno, a vila inteira vinha para cá. Os mais velhos ficavam na água até o queixo, contando as mesmas histórias de sempre.\n\nEu ficava aqui em cima, segurando as toalhas e olhando o vapor subir. Ninguém tinha pressa de voltar.\n\nFoi aqui que eu aprendi o que é sossego."],
	"f_circo": ["A festa do degelo",
		"Toda primavera, a vila subia até este lago para ouvir o gelo quebrar. Era um estalo comprido, que corria pelas paredes da montanha.\n\nEu levava os cobertores e o chá quente. Quando o gelo abria, alguém gritava: desceu!\n\nEra o sinal de que ia ter água nas hortas o ano inteiro."],
	"f_pico": ["As luzes do outro lado",
		"Quando a última família foi embora, baixei o portão da nossa oficina. Ele emperrou no meio, e eu deixei assim.\n\nDepois subi até aqui, devagar, com o frio segurando o calor do motor.\n\nDo outro lado, as torres ainda acendiam as luzes das casas vazias. Achei que era um convite. No outro dia, desci e fui para lá."],
	"f_fecho": ["Para você",
		"Agora você sabe de onde eu vim.\n\nDepois que todos se foram, procurei aquele sossego de novo, e o meu corpo cansou antes de eu achar. Você não precisa ter pressa.\n\nAs crianças da escola fizeram um desenho meu. Deixei no mural da base, para você."],
}
const ORDEM_FAISCA := ["f_navio", "f_oficina", "f_turquesa", "f_fontes", "f_circo", "f_pico"]
const FECHO := "f_fecho"
## Onde ficam (medidos pelo level designer em 2026-11-22; o y é só o ponto de partida do raio que acha o chão)
const PONTOS_FAISCA := {
	"f_navio": Vector3(-453.0, 1.6, -1713.2),  # no porão da frente do navio encalhado, entrando a pé pelo rombo
	"f_oficina": Vector3(-736.4, 30.0, -2578.8),  # na calçada, na porta da oficina dos robôs de ajuda
	"f_turquesa": Vector3(-1480.0, 28.3, -2745.0),  # no fundo do Lago Turquesa, no meio, a 16,6 m
	"f_fontes": Vector3(-2266.0, 36.3, -538.0),  # no alto do monte de sínter das fontes
	"f_circo": Vector3(-2378.0, 305.3, -2650.0),  # na beira da saída do lago do circo, junto à queda
	"f_pico": Vector3(-2842.0, 861.8, -2850.0),  # no pico da Montanha do Degelo
}
const COR_FAGULHA := Color(1.0, 0.74, 0.4)  # a da faísca do prólogo (`Historia.COR_FAISCA`)
const ORDEM := ["cachoeira", "serra", "sumidouro", "arcos", "represa", "rele", "fenda", "torres", "observatorio", "casco", "gigantes", "fundicao"]
## chave -> o nome do lugar, para a barra de cima do tablet (o pino à direita)
const LUGARES := {"cachoeira": "Cachoeira", "serra": "Serra", "sumidouro": "Sumidouro", "arcos": "Arcos", "represa": "Represa",
	"rele": "Relé", "fenda": "Fenda", "torres": "Torres", "observatorio": "Observatório", "casco": "Casco", "gigantes": "Gigantes",
	"fundicao": "Fundição", "robo_mergulhador": "Represa", "ave_grande": "Alto do vento", "sinal_de_fora": "Mastro",
	"robozinhos": "Canos", "robo_antigo": "Observatório",
	"f_navio": "Navio Encalhado", "f_oficina": "Vilarejo", "f_turquesa": "Lago Turquesa", "f_fontes": "Fontes Quentes",
	"f_circo": "Lago do Circo", "f_pico": "Pico do Degelo", "f_fecho": "Faísca"}


## O título e o texto de uma memória da ilha ou de uma lembrança do Faísca; vazio se a chave não existe.
static func dado(chave: String) -> Array:
	if TEXTOS.has(chave):
		return TEXTOS[chave]
	return TEXTOS_FAISCA.get(chave, [])

var armadura: Armadura
var mapa: Vale
var hud: Hud
var pecas: PecasMundo
var onde := {}  # chave -> Vector3
var lidas: Array = []
var onde_faisca := {}  # as lembranças do Faísca: chave -> Vector3
var lidas_faisca: Array = []  # as do Faísca já lidas (com o fecho, "f_fecho")
var _fecho_depois := false  # a sexta acabou de ser lida: o fecho abre quando ela fechar
var _lendo_faisca := false
var aberta := ""  # a memória que está na tela agora
var aberturas := 0  # quantas vezes uma memória foi aberta (testes)

var _nos := {}
var _t := 0.0
var _saiu := {}  # chave -> o robô já se afastou depois de ler (para não reabrir em cima)
var _camada: CanvasLayer
var _tablet: TabletCasca  # o tablet fechado da memória (2026-11-21)
var _titulo_txt := ""
var _texto_txt := ""
var _musica: AudioStreamPlayer
var _fecha_em := 0.0


func _ready() -> void:
	lidas = (Guardado.progresso("memorias") as Array).duplicate() if Guardado.ativo else []
	lidas_faisca = (Guardado.progresso("lembrancas") as Array).duplicate() if Guardado.ativo else []
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var alvos := {
		"cachoeira": Vector2(Vale.POCO.x - 24.0, Vale.POCO.y + 20.0),
		"serra": Vector2(mapa.cume.x, mapa.cume.z),
		"arcos": Vector2(Ruinas.ARCOS.x + 10.0, Ruinas.ARCOS.y + 16.0),
		"fenda": FendaEscura.ponto(250.0),
		"torres": (MarcosOeste.TORRES[2] as Vector2) + Vector2(7.0, 9.0),
		# no platô ao lado do Observatório, de onde se vê a cúpula: dentro dele fica o robô de antes
		"observatorio": MarcosOeste.OBSERVATORIO + Vector2(0.0, 62.0),
	}
	for chave: String in alvos:
		onde[chave] = pecas._assentar(alvos[chave])
	# em cima de construções: o passadiço da represa, a plataforma da torre do relé e o convés do navio
	# (a da represa fica no meio da parede, longe da comporta, onde está o robô mergulhador, e da baliza da rota)
	for alto: Array in [["represa", Vector2(MarcosLeste.represa_x(-75.0), MarcosLeste.REPRESA.y - 75.0)],
			["casco", Vector2(MarcosOeste.conves.x, MarcosOeste.conves.z)]]:
		var p := pecas._de_cima(alto[1])
		onde[alto[0]] = p if p.is_finite() else pecas._assentar(alto[1])
	# na torre velha do Relé, em cima do patamar reto perto do topo (ficava na ponta de uma barra de ferro: o
	# raio de cima para baixo batia no lance dobrado da torre)
	onde["rele"] = MarcosMar.rele_topo + Vector3(1.3, 0.2, -1.3)
	# no salão do Sumidouro, onde a luz do peito faz falta: no lado oposto ao da câmara do fundo (onde ficam os
	# robozinhos) e longe de debaixo da baliza do rio, que fica no morro em cima do túnel
	var salao := pecas._no_salao([Vector2(0, -15), Vector2(-3, -14), Vector2(3, -15), Vector2(0, -12), Vector2(16, -8)])
	onde["sumidouro"] = salao if salao.is_finite() else pecas._assentar(Sumidouro.saida)
	# no Sono dos Gigantes (2026-11-20, ideia do usuário): em cima do peito da Escavadeira deitada, ao lado
	# da cabine. O ponto sai do próprio modelo e um raio acha a chapa.
	onde["gigantes"] = pecas._assentar(MarcosLeste.GIGANTES)
	if not MarcosLeste.gigantes.is_empty():
		var deitada := MarcosLeste.gigantes[0] as Node3D
		var modelo_g := deitada.get_child(0) as Node3D
		var no_peito: Vector3 = modelo_g.global_transform * Vector3(0.16, 1.46, 0.3)
		var raio := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(no_peito + Vector3(0, 9.0, 0), no_peito - Vector3(0, 9.0, 0), 1))
		if not raio.is_empty():
			onde["gigantes"] = raio["position"]
	# na Fundição: no patamar da frente, fora do galpão (dentro dele, ficar 18 s começa a horda)
	if Fundicao.montada:
		onde["fundicao"] = pecas._assentar(Vector2(Fundicao.CENTRO.x + FUNDICAO_LADO.x, Fundicao.CENTRO.y + FUNDICAO_LADO.y))
	for chave: String in ORDEM:
		if not onde.has(chave):
			continue
		var no := _cristal(lidas.has(chave))
		no.position = onde[chave]
		add_child(no)
		_nos[chave] = no
	_lembrancas_do_faisca()
	_montar_tela()


## As seis lembranças do Faísca, só com a terra nova montada. Cada ponto acha o chão com um raio de cima: no porão
## e na oficina um raio curto (o de longe bateria no casco ou no telhado); no pico, de bem alto (a grade de
## alturas fica uns 0,8 m abaixo da colisão ali).
func _lembrancas_do_faisca() -> void:
	if mapa == null or mapa.get("terra_nova") == null:
		return
	for chave: String in ORDEM_FAISCA:
		var p: Vector3 = PONTOS_FAISCA[chave]
		var de := 1000.0 - p.y if chave == "f_pico" else 3.0
		var r := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, de, 0), p - Vector3(0, 12.0, 0), 1))
		onde_faisca[chave] = r["position"] if not r.is_empty() else p
		var no := _fagulha(lidas_faisca.has(chave))
		no.position = onde_faisca[chave]
		add_child(no)
		_nos[chave] = no
		# o ponto de luz da noite, para achar de longe (no porão e no fundo do lago não se vê de longe mesmo)
		if not lidas_faisca.has(chave) and chave != "f_navio" and chave != "f_turquesa":
			LuzesNoite.por(no.get_node("gira") as Node3D, Vector3.ZERO, LuzesNoite.AMBAR, 1.6)  # em volta dela, pulsando junto
	if lidas_faisca.has(FECHO):
		BaseLar.mostrar_desenho()


static var _tex_bolinha: Texture2D


static func _bolinha() -> Texture2D:
	if _tex_bolinha == null:
		_tex_bolinha = load("res://assets/fx/kenney/circle_05.png")
	return _tex_bolinha


## A fagulha das lembranças do Faísca: um ponto creme bem aceso com um halo laranja e faíscas miúdas subindo. Não
## gira: pulsa devagar. Lida, fica menor, mais fraca e sem faíscas.
func _fagulha(lida: bool) -> Node3D:
	var no := Node3D.new()
	no.set_meta("fagulha", true)
	var gira := Node3D.new()
	gira.name = "gira"
	gira.position.y = 1.0
	no.add_child(gira)
	var miolo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.075 if lida else 0.1
	esfera.height = esfera.radius * 2.0
	esfera.radial_segments = 12
	esfera.rings = 6
	miolo.mesh = esfera
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1.0, 0.95, 0.84) if not lida else Color(0.85, 0.66, 0.45)
	miolo.material_override = mm
	miolo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gira.add_child(miolo)
	# o halo: um quadrado virado para a câmera com a bolinha macia do Kenney (a mesma das luzes da noite), somando luz
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.45 if lida else 0.8)
	halo.mesh = quad
	var mh := StandardMaterial3D.new()
	mh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mh.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mh.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mh.albedo_color = Color(COR_FAGULHA, 0.3 if lida else 0.7)
	mh.albedo_texture = _bolinha()
	halo.material_override = mh
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gira.add_child(halo)
	if not lida:
		var fa := CPUParticles3D.new()
		fa.amount = 7
		fa.lifetime = 1.3
		fa.local_coords = false
		fa.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fa.emission_sphere_radius = 0.08
		fa.direction = Vector3.UP
		fa.spread = 35.0
		fa.initial_velocity_min = 0.25
		fa.initial_velocity_max = 0.55
		fa.gravity = Vector3(0.0, 0.15, 0.0)
		fa.scale_amount_min = 0.035
		fa.scale_amount_max = 0.06
		var rampa := Gradient.new()
		rampa.set_color(0, Color(1.0, 0.85, 0.55, 1.0))
		rampa.set_color(1, Color(1.0, 0.5, 0.15, 0.0))
		fa.color_ramp = rampa
		var qf := QuadMesh.new()
		qf.size = Vector2.ONE
		var mf := StandardMaterial3D.new()
		mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mf.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mf.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mf.vertex_color_use_as_albedo = true
		mf.albedo_texture = _bolinha()
		qf.material = mf
		fa.mesh = qf
		gira.add_child(fa)
	var luz := OmniLight3D.new()
	luz.light_color = COR_FAGULHA
	luz.light_energy = 0.3 if lida else 1.2
	luz.omni_range = 6.0
	luz.shadow_enabled = false
	luz.distance_fade_enabled = true
	luz.distance_fade_begin = 90.0
	luz.distance_fade_length = 30.0
	gira.add_child(luz)
	return no


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
	fundo.color = Color(0.02, 0.04, 0.06, 0.8)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(fundo)
	var meio := CenterContainer.new()
	meio.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(meio)
	_tablet = TabletCasca.new()
	_tablet.aberto = false
	_tablet.size = Vector2(600, 262)
	_tablet.custom_minimum_size = Vector2(600, 262)
	_tablet.cor_rotulo = Tablet.AMBAR
	_tablet.pintor = _pintar_tablet
	meio.add_child(_tablet)
	_musica = AudioStreamPlayer.new()
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists("res://assets/sons/memoria_loop.wav"):
		_musica.stream = Som.laco_stream("memoria_loop")
	_musica.volume_db = -60.0
	add_child(_musica)
	process_mode = Node.PROCESS_MODE_ALWAYS


func abrir(chave: String) -> void:
	if aberta != "" or dado(chave).is_empty():
		return
	aberta = chave
	aberturas += 1
	var das_dez: bool = ORDEM.has(chave)
	if das_dez and not lidas.has(chave):
		lidas.append(chave)
		if Guardado.ativo:
			Guardado.por_progresso("memorias", lidas)
	_lendo_faisca = TEXTOS_FAISCA.has(chave)
	if _lendo_faisca and not lidas_faisca.has(chave):
		lidas_faisca.append(chave)
		# a sexta: o fecho já conta como lido (se o jogo fechar antes, ele fica no caderno) e o desenho vai ao mural
		if ORDEM_FAISCA.all(func(k: String) -> bool: return lidas_faisca.has(k)) and not lidas_faisca.has(FECHO):
			lidas_faisca.append(FECHO)
			_fecho_depois = true
			BaseLar.mostrar_desenho()
		if Guardado.ativo:
			Guardado.por_progresso("lembrancas", lidas_faisca)
	var par: Array = dado(chave)
	_titulo_txt = par[0]
	_texto_txt = par[1]
	# a altura do tablet acompanha o texto: 262 de cabeça, o parágrafo, 120 de rodapé (máximo 860)
	var ch := minf(860.0, 262.0 + Tablet.altura_paragrafo(_texto_txt, 480.0, 20) + 120.0)
	_tablet.size = Vector2(600, ch)
	_tablet.custom_minimum_size = Vector2(600, ch)
	_tablet.rotulo = ("Memória · %d de %d" % [lidas.size(), ORDEM.size()]) if das_dez else "Lembrança"
	if ORDEM_FAISCA.has(chave):
		var seis := ORDEM_FAISCA.filter(func(k: String) -> bool: return lidas_faisca.has(k)).size()
		_tablet.rotulo = "Lembrança do Faísca · %d de %d" % [seis, ORDEM_FAISCA.size()]
	elif chave == FECHO:
		_tablet.rotulo = "Lembrança do Faísca"
	_tablet.cor_rotulo = Tablet.AZUL if _lendo_faisca else Tablet.AMBAR
	_tablet.rotulo_dir = String(LUGARES.get(chave, ""))
	_tablet.queue_redraw()
	_camada.visible = true
	_fecha_em = 0.6  # um instante antes de aceitar o botão, para o aperto que trouxe o robô não fechar
	if hud:
		hud.visible = false
	get_tree().paused = true
	if _musica.stream:
		_musica.play()
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(_musica, "volume_db", -9.0, 1.6)
	# lida: o cristal (ou a fagulha) fica mais apagado
	if _nos.has(chave):
		var velho: Node3D = _nos[chave]
		var novo := _fagulha(true) if velho.has_meta("fagulha") else _cristal(true)  # a luz da noite sai com o velho
		novo.position = velho.position
		add_child(novo)
		velho.queue_free()
		_nos[chave] = novo
	_saiu[chave] = false


## O desenho do tablet: o cristal âmbar brilhando, o título com o fio, o texto e o rodapé.
func _pintar_tablet(c: CanvasItem, telas: Array) -> void:
	var t: Rect2 = telas[0]
	var cc := Vector2(t.get_center().x, t.position.y + 108)
	Tablet.brilho(c, cc, 22, Color(1.0, 0.7, 0.3), 1.6)
	var tinta := Tablet.AMBAR
	if _lendo_faisca:
		Tablet.fagulha(c, cc, 26, Tablet.LARANJA)
		tinta = Tablet.AZUL
	else:
		Tablet.cristal(c, cc, 24, Tablet.AMBAR)
	Tablet.texto(c, Vector2(t.position.x, t.position.y + 196), _titulo_txt, Tablet.caber(_titulo_txt, t.size.x - 48, 32, true), tinta.darkened(0.35), true, HORIZONTAL_ALIGNMENT_CENTER, t.size.x)
	c.draw_line(Vector2(t.get_center().x - 60, t.position.y + 218), Vector2(t.get_center().x + 60, t.position.y + 218), Color(tinta, 0.6), 2.0)
	Tablet.paragrafo(c, Vector2(t.position.x + 40, t.position.y + 262), _texto_txt, t.size.x - 80, 20, Tablet.TINTA)
	Tablet.rodape(c, t, [["x", "fechar"]])


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
	# a sexta lembrança do Faísca fechou: o fecho abre sozinho, logo depois
	if _fecho_depois:
		_fecho_depois = false
		get_tree().create_timer(1.2, false).timeout.connect(abrir.bind(FECHO))  # parado com o jogo pausado


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
		if no.has_meta("fagulha"):
			# a fagulha não gira: pulsa devagar e quase não sobe
			gira.scale = Vector3.ONE * (1.0 + 0.1 * sin(_t * 2.2 + no.position.x))
			gira.position.y = 1.0 + sin(_t * 0.9 + no.position.z) * 0.05
		else:
			gira.rotation.y = _t * 0.8
			gira.position.y = 1.0 + sin(_t * 1.3 + no.position.x) * 0.12
		var d := p.distance_to(no.position + Vector3(0, 1.0, 0))
		if d > PEGA * 2.5:
			_saiu[chave] = true
		elif d < PEGA and _saiu.get(chave, true) and not armadura.travado:
			abrir(chave)
			return
