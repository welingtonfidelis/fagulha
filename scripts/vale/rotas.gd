class_name Rotas
extends Node3D
## As rotas do piloto de teste (1.1, doc §136). Quem morava na ilha testava o voo dos robôs ajudantes em
## percursos marcados; sobraram balizas velhas, e a simulação foi montada a partir delas (por isso os aros são os
## mesmos do treino). Pousar numa baliza acende a rota: os aros de luz, com o da vez em laranja.
## Regras: depois de sair do chão não se pousa mais até o fim (o calor é o desafio; água, chuva e cachoeira
## esfriam no caminho). Feita uma vez, a mesma baliza passa a dar a versão difícil, em que cada aro vai apagando
## se o robô demora (um relógio que se vê, sem número).
## Prêmios: a primeira vez de cada rota dá uma cor de rastro para os jatos (`RastroJatos`); a difícil põe uma
## miniatura do lugar na estante da base (`Miniaturas`); todas as rotas feitas dão a peça "corrida".
## Feita a difícil, a baliza passa a dar a corrida: a gravação do recorde de um piloto de teste de antigamente
## (`RivalHolograma`) espera na baliza e sai junto quando o robô decola, sem prazo nos aros. Chegar antes dele
## bate o recorde: na primeira vez, experiência, sucata e uma tacinha dourada ao lado da miniatura.
## Quem cria passa `armadura`, `hud` e `mapa`.

signal mudou  # uma rota foi feita (a estante e a oficina se refazem)

const ROTAS := [
	{"id": "rio", "nome": "Rasante do rio", "dica": "voe baixo: a água e a cachoeira esfriam o motor"},
	{"id": "torres", "nome": "Pás das Torres do Vento", "dica": "zigue-zague entre as torres"},
	{"id": "mastro", "nome": "Descida do mastro", "dica": "suba pelo calor da antena e termine com um mergulho no alvo"},
	{"id": "ninho", "nome": "Maresia do ninho", "dica": "na maresia os jatos apagam: planando até pousar no ninho", "pede": "asas"},
	{"id": "represa", "nome": "Aros da Represa", "dica": "debaixo d'água: mergulhe e nade pelos aros"},
	{"id": "fenda", "nome": "Fenda Escura", "dica": "os aros ficam no escuro: acenda a luz do peito", "pede": "farol"},
	{"id": "volta", "nome": "Volta da ilha", "dica": "a prova do calor: rente ao mar o motor esfria"},
]
const CORES := {
	"rio": Color(0.35, 0.8, 1.0), "torres": Color(0.92, 0.95, 1.0), "mastro": Color(1.0, 0.28, 0.22),
	"ninho": Color(1.0, 0.84, 0.32), "represa": Color(0.25, 1.0, 0.66), "fenda": Color(0.7, 0.45, 1.0),
	"volta": Color(1.0, 0.55, 0.15),
}
const NOMES_COR := {"rio": "azul do rio", "torres": "branco do vento", "mastro": "vermelho da antena", "ninho": "dourado do ninho",
	"represa": "verde da represa", "fenda": "roxo da fenda", "volta": "laranja da volta"}
const LARANJA := Color(1.0, 0.62, 0.3)
const AGUA := Color(0.35, 0.95, 0.85)
const APAGANDO := Color(0.55, 0.12, 0.08)
const RAIO_AR := 6.0
const RAIO_AGUA := 3.6
const BALIZA_PERTO := 3.2  # de pé a esta distância da baliza, a rota acende
const BALIZA_SAI := 16.0  # andando para longe da baliza sem voar, a rota apaga
const VEL_AR := 24.0  # m/s que medem o tempo de cada aro na versão difícil
const VEL_AGUA := 7.5
const FOLGA := 3.5  # segundos a mais em cada aro difícil
const LONGE := 650.0  # longe assim do aro da vez, a rota se perde
const ALVO_RAIO := 7.0  # o alvo do mergulho do mastro
const NINHO_RAIO := 9.0

static var feitas := {}  # id -> 1 (feita) ou 2 (feita na difícil)
static var rastro := ""  # a cor de rastro em uso ("" sem rastro)
static var recordes: Array = []  # ids das rotas com o recorde do piloto de teste batido
## A velocidade da gravação em cada rota (m/s): entre o voo normal (18) e a arrancada (28), para ganhar dela é
## preciso arrancar e cuidar do calor. No ninho só se plana; na represa se nada.
const RIVAL_VEL := {"rio": 21.0, "torres": 20.0, "mastro": 20.0, "ninho": 14.0, "represa": 5.8, "fenda": 17.0, "volta": 22.5}

var armadura: Armadura
var hud: Hud
var mapa: Vale
var lista := {}  # id -> {baliza, aros, fim ("aro", "alvo", "pouso"), alvo, agua, escuro}
var atual := ""  # a rota acesa ("" nenhuma)
var correndo := false  # já saiu do chão
var dificil := false
var corrida := false
var rival: RivalHolograma
var resultado_corrida := ""  # "ganhou" ou "perdeu" (testes)
var _avisou_rival := false
var proximo := 0
var concluidas := 0  # testes
var falhas := 0
var ultimo_fim := ""  # "feita", "pousou", "apagou", "longe" (testes)

var _aros: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _t_aro := 0.0
var _prazo := 0.0
var _balizas := {}  # id -> {"no": Node3D, "mat": StandardMaterial3D}
var _alvo: MeshInstance3D
var _alvo_mat: StandardMaterial3D
var _t := 0.0
var _pouso_t := 0.0
var _estante: Node3D


func _ready() -> void:
	if Guardado.ativo:
		feitas = (Guardado.progresso("rotas") as Dictionary).duplicate(true)
		rastro = String(Guardado.progresso("rastro"))
		recordes = (Guardado.progresso("recordes") as Array).duplicate()
	for i in 8:
		await get_tree().physics_frame
	if mapa == null:
		return
	lista["rio"] = _rota_rio()
	lista["torres"] = _rota_torres()
	lista["mastro"] = _rota_mastro()
	lista["ninho"] = _rota_ninho()
	lista["represa"] = _rota_represa()
	lista["fenda"] = _rota_fenda()
	lista["volta"] = _rota_volta()
	for id: String in lista:
		lista[id]["baliza"] = _assentar(lista[id]["baliza"])
		_montar_baliza(id)
	por_miniaturas()


static func titulo(id: String) -> String:
	for r: Dictionary in ROTAS:
		if r["id"] == id:
			return r["nome"]
	return id


static func dado(id: String, chave: String) -> String:
	for r: Dictionary in ROTAS:
		if r["id"] == id:
			return String(r.get(chave, ""))
	return ""


static func todas_feitas() -> bool:
	for r: Dictionary in ROTAS:
		if int(feitas.get(r["id"], 0)) < 1:
			return false
	return true


# ---------------------------------------------------------------- o desenho de cada rota

## Um ponto no chão (a baliza fica de pé nele).
func _chao(x: float, z: float) -> Vector3:
	return Vector3(x, mapa.altura(x, z), z)


## Um ponto no ar a `alto` metros do chão ou da água, o que for mais alto.
func _no_ar(x: float, z: float, alto: float) -> Vector3:
	var h := mapa.altura(x, z)
	var a := mapa.agua(x, z)
	if a != -INF:
		h = maxf(h, a)
	return Vector3(x, h + alto, z)


## Sobe o ponto até ficar `folga` metros acima do chão (os aros não podem nascer enterrados).
func _livre(p: Vector3, folga := 9.0) -> Vector3:
	return Vector3(p.x, maxf(p.y, mapa.altura(p.x, p.z) + folga), p.z)


## O primeiro chão firme (acima de `nivel`) andando de `de` para `para`.
func _beira(de: Vector2, para: Vector2, nivel: float) -> Vector3:
	var d := (para - de).normalized()
	for k in 200:
		var p := de + d * (k * 2.0)
		if mapa.altura(p.x, p.y) > nivel + 0.6:
			return _chao(p.x + d.x * 4.0, p.y + d.y * 4.0)
	return _chao(para.x, para.y)


## O chão de verdade perto de `p` (o mapa de alturas não tem as pedras, a represa nem os barrancos): um raio de
## cima para baixo no ponto e em volta dele, até 24 m, e fica o primeiro lugar plano e seco.
func _assentar(p: Vector3) -> Vector3:
	var espaco := get_world_3d().direct_space_state
	for raio: float in [0.0, 3.0, 6.0, 9.0, 12.0, 16.0, 20.0, 24.0]:
		var n := 1 if raio == 0.0 else 10
		for k in n:
			var ang := k * TAU / n
			var q := p + Vector3(cos(ang) * raio, 0.0, sin(ang) * raio)
			var consulta := PhysicsRayQueryParameters3D.create(q + Vector3(0, 12, 0), q - Vector3(0, 40, 0))
			if armadura:
				consulta.exclude = [armadura.get_rid()]
			var acerto := espaco.intersect_ray(consulta)
			if acerto.is_empty():
				continue
			var chao: Vector3 = acerto["position"]
			var agua := mapa.agua(chao.x, chao.z)
			if (acerto["normal"] as Vector3).y > 0.9 and (agua == -INF or chao.y > agua + 0.3):
				return chao
	return p


func _rota_rio() -> Dictionary:
	var aros: Array[Vector3] = []
	# o primeiro aro fica dentro da queda d'água: quem passa já sai frio
	var queda := Vector2(Vale.NASCENTE.x, Vale.NASCENTE.y).lerp(Vector2(Vale.POCO.x, Vale.POCO.y), 0.42)
	aros.append(Vector3(queda.x, Vale.POCO_NIVEL + 12.0, queda.y))
	for p: Vector2 in [Vector2(-276, -430), Vector2(-260, -380), Vector2(-222, -295), Vector2(-180, -200), Vector2(-140, -136), Vector2(-100, -80)]:
		aros.append(_livre(_no_ar(p.x, p.y, 3.5), 3.0))
	for p: Vector2 in [Vector2(52, 30), Vector2(104, 104), Vector2(170, 215), Vector2(232, 320), Vector2(282, 430), Vector2(316, 560)]:
		aros.append(_livre(_no_ar(p.x, p.y, 3.5), 3.0))
	var atras := Vector2(Vale.NASCENTE.x, Vale.NASCENTE.y) + (Vector2(Vale.NASCENTE.x, Vale.NASCENTE.y) - Vector2(Vale.POCO.x, Vale.POCO.y)).normalized() * 22.0
	return {"baliza": _chao(atras.x, atras.y), "aros": aros, "fim": "aro"}


func _rota_torres() -> Dictionary:
	var hubs: Array[Vector3] = []
	for item: Array in MarcosOeste.rotores:
		if is_instance_valid(item[0]):
			hubs.append((item[0] as Node3D).global_position)
	hubs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	var aros: Array[Vector3] = []
	if hubs.size() < 2:
		return {"baliza": _chao(-90, -1175), "aros": [_no_ar(0, -1175, 60)], "fim": "aro"}
	var lado := 1.0
	for i in hubs.size():
		var h := hubs[i]
		# rente a cada torre, de um lado e do outro: o zigue-zague
		aros.append(_livre(h + Vector3(0, -12.0, 30.0 * lado), 12.0))
		lado = -lado
		if i < hubs.size() - 1:
			var b := hubs[i + 1]
			var vao := b.x - h.x
			var n := 1 if vao < 180.0 else 2
			for k in n:
				var f := float(k + 1) / float(n + 1)
				var m := h.lerp(b, f)
				aros.append(_livre(m + Vector3(0, 16.0 if lado > 0.0 else -6.0, 34.0 * lado), 12.0))
				lado = -lado
	var ultimo := hubs[hubs.size() - 1]
	aros.append(_livre(ultimo + Vector3(70.0, -20.0, 0.0), 10.0))
	var b0 := hubs[0]
	return {"baliza": _chao(b0.x - 85.0, b0.z), "aros": aros, "fim": "aro"}


func _rota_mastro() -> Dictionary:
	var pe := _chao(1268.0, 668.0)
	var aros: Array[Vector3] = []
	var r := 28.0
	# sobe em espiral pelo campo quente da antena, contorna o topo e desce em espiral até o alvo
	var subida := [[0.0, 45.0], [1.6, 85.0], [3.2, 120.0], [4.8, 150.0]]
	for s: Array in subida:
		aros.append(pe + Vector3(cos(s[0]) * r, s[1], sin(s[0]) * r))
	var descida := [[0.6, 125.0], [2.2, 95.0], [3.8, 65.0], [5.4, 38.0]]
	for s: Array in descida:
		aros.append(pe + Vector3(cos(s[0]) * (r + 6.0), s[1], sin(s[0]) * (r + 6.0)))
	var alvo := _chao(pe.x - 30.0, pe.z - 18.0)
	# a baliza fica no lado oeste da ilhota, longe da torre velha (a memória lá em cima) e da baliza do ninho
	return {"baliza": _chao(1222.0, 652.0), "aros": aros, "fim": "alvo", "alvo": alvo}


func _rota_ninho() -> Dictionary:
	var p := NinhoAve.PILAR
	var aros: Array[Vector3] = []
	# o primeiro aro, alto e fora da maresia; depois, já planando, a volta em torno do pilar até pousar
	for q: Vector3 in [Vector3(1300, 165, 770), Vector3(1328, 140, 846), Vector3(1425, 112, 930), Vector3(1445, 88, 1035),
			Vector3(1372, 66, 1100), Vector3(1290, 52, 1046)]:
		aros.append(q)
	var alvo := Vector3(p.x, NinhoAve.ALTO, p.y)
	return {"baliza": _beira(Vector2(1282, 760), Vector2(1282, 648), 1.0), "aros": aros, "fim": "pouso", "alvo": alvo}


func _rota_represa() -> Dictionary:
	var c := Vector2(Vale.REPRESA_LAGOA.x, Vale.REPRESA_LAGOA.y)
	var nivel := Vale.REPRESA_NIVEL
	var aros: Array[Vector3] = []
	# uma volta debaixo d'água, longe da correnteza da comporta (a leste)
	for k in 8:
		var ang := PI * 0.5 + k * TAU / 8.0
		var raio := 48.0
		var pt := c + Vector2(cos(ang) * raio * 0.8 - 18.0, sin(ang) * raio)
		var fundo := mapa.altura(pt.x, pt.y)
		var tenta := 0
		while nivel - fundo < 6.0 and tenta < 8:
			pt = pt.lerp(c - Vector2(18.0, 0.0), 0.25)
			fundo = mapa.altura(pt.x, pt.y)
			tenta += 1
		aros.append(Vector3(pt.x, lerpf(nivel, fundo, 0.5), pt.y))
	# a baliza fica na ponta da parede da represa, longe da comporta (no meio, com o robô mergulhador) e da
	# memória do passadiço: dali se mergulha na lagoa
	var crista := Vector3(MarcosLeste.represa_x(-135.0) - 4.0, MarcosLeste.REPRESA_TOPO + 1.0, MarcosLeste.REPRESA.y - 135.0)
	return {"baliza": crista, "aros": aros, "fim": "aro", "agua": true}


func _rota_fenda() -> Dictionary:
	var linha := FendaEscura.LINHA
	var aros: Array[Vector3] = []
	var total := 0.0
	var trechos: Array[float] = []
	for i in linha.size() - 1:
		var l := linha[i].distance_to(linha[i + 1])
		trechos.append(l)
		total += l
	var d := 30.0
	while d < total - 10.0:
		var resto := d
		var i := 0
		while i < trechos.size() - 1 and resto > trechos[i]:
			resto -= trechos[i]
			i += 1
		var pt := linha[i].lerp(linha[i + 1], clampf(resto / trechos[i], 0.0, 1.0))
		aros.append(Vector3(pt.x, mapa.altura(pt.x, pt.y) + 5.5, pt.y))
		d += 65.0
	# a baliza fica no fundo da fenda, na boca aberta (o teto começa uns 34 m adiante)
	var boca := linha[0] + (linha[1] - linha[0]).normalized() * 8.0
	return {"baliza": _chao(boca.x, boca.y), "aros": aros, "fim": "aro", "escuro": true}


func _rota_volta() -> Dictionary:
	var farol := Vector2(1338.0, -1338.0)
	var meio := Vector2(66.0, -120.0)
	var pontos: Array[Vector3] = []
	var ang0 := atan2(farol.y - meio.y, farol.x - meio.x)
	# de 7,5 em 7,5 graus, a começar pela direção do farol, no sentido do relógio visto de cima: o aro fica no
	# mar, 60 m além da última terra daquela direção; depois os aros perto demais saem e, onde a costa faz ponta,
	# entra um aro no meio (nenhum salto passa de `SALTO_VOLTA`)
	for k in range(0, 48):
		var ang := ang0 + k * TAU / 48.0
		var d := Vector2(cos(ang), sin(ang))
		var ultimo := 300.0
		var r := 300.0
		while r < 2600.0:
			var q := meio + d * r
			if mapa.altura(q.x, q.y) > MAR_ALTO:
				ultimo = r
			r += 20.0
		var q2 := meio + d * (ultimo + 60.0)
		pontos.append(_livre(_no_ar(q2.x, q2.y, 16.0), 12.0))
	# o último aro fecha a volta perto do farol
	var fim := farol + (meio - farol).normalized() * 60.0
	pontos.append(_livre(_no_ar(fim.x, fim.y, 40.0), 14.0))
	var ralos: Array[Vector3] = [pontos[0]]
	for i in range(1, pontos.size()):
		if pontos[i].distance_to(ralos[ralos.size() - 1]) > 200.0 or i == pontos.size() - 1:
			ralos.append(pontos[i])
	pontos = [ralos[0]]
	for i in range(1, ralos.size()):
		var de := pontos[pontos.size() - 1]
		var n := ceili(de.distance_to(ralos[i]) / SALTO_VOLTA)
		for j in range(1, n):
			var q := de.lerp(ralos[i], float(j) / n)
			pontos.append(_livre(_no_ar(q.x, q.z, 16.0), 12.0))
		pontos.append(ralos[i])
	var bal := farol + (meio - farol).normalized() * 72.0  # longe do pé do farol (a peça e o fim do jogo ficam lá em cima)
	return {"baliza": _chao(bal.x, bal.y), "aros": pontos, "fim": "aro"}

const MAR_ALTO := 1.0
const SALTO_VOLTA := 380.0


# ---------------------------------------------------------------- as balizas

func _montar_baliza(id: String) -> void:
	var r: Dictionary = lista[id]
	var no := Node3D.new()
	no.name = "Baliza_" + id
	add_child(no)
	no.global_position = r["baliza"]
	var concreto := StandardMaterial3D.new()
	concreto.albedo_color = Color(0.46, 0.45, 0.42)
	concreto.roughness = 0.95
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color(0.2, 0.19, 0.18)
	ferro.metallic = 0.5
	ferro.roughness = 0.6
	_peca(no, BoxMesh.new(), Vector3(1.1, 0.34, 1.1), Vector3(0, 0.12, 0), concreto)
	var poste := CylinderMesh.new()
	poste.top_radius = 0.07
	poste.bottom_radius = 0.09
	poste.height = 1.9
	_peca(no, poste, Vector3.ONE, Vector3(0, 1.2, 0), ferro)
	# faixas desbotadas no poste, laranja e branco
	for k in 3:
		var faixa := StandardMaterial3D.new()
		faixa.albedo_color = Color(0.85, 0.48, 0.2) if k % 2 == 0 else Color(0.82, 0.8, 0.74)
		faixa.roughness = 0.9
		var anel := CylinderMesh.new()
		anel.top_radius = 0.085
		anel.bottom_radius = 0.085
		anel.height = 0.16
		_peca(no, anel, Vector3.ONE, Vector3(0, 1.45 + k * 0.16, 0), faixa)
	# no alto, um aro pequeno: a figura da rota, que acende
	var aro := TorusMesh.new()
	aro.inner_radius = 0.24
	aro.outer_radius = 0.34
	aro.rings = 24
	aro.ring_segments = 8
	var luz := StandardMaterial3D.new()
	luz.albedo_color = Color(0.25, 0.14, 0.08)
	luz.emission_enabled = true
	luz.emission = LARANJA
	luz.emission_energy_multiplier = 0.6
	var topo := _peca(no, aro, Vector3.ONE, Vector3(0, 2.52, 0), luz)
	topo.rotation = Vector3(PI * 0.5, 0, 0)
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = 0.14
	cil.height = 2.3
	forma.shape = cil
	forma.position = Vector3(0, 1.3, 0)
	corpo.add_child(forma)
	no.add_child(corpo)
	LuzesNoite.por(no, no.global_position + Vector3(0, 2.52, 0), LuzesNoite.AMBAR, 0.9, 1.4)
	_balizas[id] = {"no": no, "mat": luz, "topo": topo}


func _peca(pai: Node3D, malha: Mesh, escala: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	if malha is BoxMesh:
		(malha as BoxMesh).size = escala
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.position = pos
	pai.add_child(mi)
	return mi


## Refaz as miniaturas da estante da base: uma por rota feita na versão difícil, cada uma na sua vaga (a ordem
## de `ROTAS`).
func por_miniaturas() -> void:
	if _estante and is_instance_valid(_estante):
		_estante.queue_free()
	_estante = Node3D.new()
	_estante.name = "Estante"
	add_child(_estante)
	var vagas := BaseLar.estante_vagas
	for i in ROTAS.size():
		var id: String = ROTAS[i]["id"]
		if i < vagas.size() and int(feitas.get(id, 0)) >= 2:
			var m := Miniaturas.fazer(id)
			_estante.add_child(m)
			m.global_transform = vagas[i]
			if recordes.has(id):
				var taca := Miniaturas.taca()
				m.add_child(taca)
				taca.position = Vector3(0.088, Miniaturas.PEDESTAL.y, -0.052)


# ---------------------------------------------------------------- acender, correr, acabar

func _acender(id: String) -> void:
	_apagar()
	atual = id
	correndo = false
	proximo = 0
	corrida = int(feitas.get(id, 0)) >= 2
	_avisou_rival = false
	dificil = int(feitas.get(id, 0)) == 1
	var r: Dictionary = lista[id]
	var raio := RAIO_AGUA if r.get("agua", false) else RAIO_AR
	var aros: Array = r["aros"]
	for i in aros.size():
		var p: Vector3 = aros[i]
		var antes: Vector3 = r["baliza"] if i == 0 else aros[i - 1]
		var depois: Vector3 = aros[i + 1] if i + 1 < aros.size() else p + (p - antes)
		var dir := (depois - antes).normalized()
		if dir.length() < 0.5:
			dir = Vector3.FORWARD
		var toro := TorusMesh.new()
		toro.inner_radius = raio * 0.82
		toro.outer_radius = raio
		toro.rings = 48
		toro.ring_segments = 8
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = toro
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), p)
		_aros.append(mi)
		_mats.append(mat)
	if r["fim"] == "alvo":
		_montar_alvo(r["alvo"])
	_pintar_aros()
	var b: Dictionary = _balizas[id]
	(b["mat"] as StandardMaterial3D).emission_energy_multiplier = 3.0
	Som.toque3d(self, "onda_comeca", armadura.global_position, -8.0)
	if hud:
		var pede := dado(id, "pede")
		if pede != "" and not Melhorias.tem(pede):
			hud.avisar(titulo(id), "precisa: " + String(Melhorias.TITULOS.get(pede, pede)).to_lower())
		elif corrida:
			hud.avisar(titulo(id) + " · corrida", "a gravação do recorde sai junto quando você decolar: chegue antes dela")
		elif dificil:
			hud.avisar(titulo(id) + " · difícil", "os aros apagam se você demorar · " + dado(id, "dica"))
		else:
			hud.avisar(titulo(id), "passe pelos aros sem pousar · " + dado(id, "dica"))
	Hud.aro_rota = _aros[0].global_position if not _aros.is_empty() else Vector3.INF
	if corrida:
		_montar_rival(id)


## O holograma do piloto de teste, ao lado da baliza, e o caminho dele: da baliza por todos os aros até o fim.
func _montar_rival(id: String) -> void:
	var r: Dictionary = lista[id]
	var bal: Vector3 = r["baliza"]
	var aros: Array = r["aros"]
	var pontos: Array[Vector3] = []
	var lado := Vector3(2.2, 0, 0)
	if not aros.is_empty():
		var f: Vector3 = aros[0] - bal
		f.y = 0.0
		if f.length() > 0.1:
			lado = f.normalized().cross(Vector3.UP) * 2.2
	var largada := bal + lado + Vector3(0, 0.2, 0)
	pontos.append(largada)
	if not r.get("agua", false):
		pontos.append(largada + Vector3(0, 6.0, 0))
	for p: Vector3 in aros:
		pontos.append(p)
	if r["fim"] != "aro":
		var alvo: Vector3 = r["alvo"]
		pontos.append(alvo + Vector3(0, 0.5, 0))
	var c := Curve3D.new()
	c.bake_interval = 1.5
	for i in pontos.size():
		var ant: Vector3 = pontos[maxi(0, i - 1)]
		var dep: Vector3 = pontos[mini(pontos.size() - 1, i + 1)]
		var alca := (dep - ant) * 0.22
		c.add_point(pontos[i], -alca, alca)
	rival = RivalHolograma.new()
	rival.name = "Rival"
	rival.caminho = c
	rival.vel = float(RIVAL_VEL.get(id, 20.0))
	add_child(rival)
	rival.esperar(largada, aros[0] if not aros.is_empty() else largada + Vector3.FORWARD)


func _montar_alvo(onde: Vector3) -> void:
	var disco := CylinderMesh.new()
	disco.top_radius = ALVO_RAIO
	disco.bottom_radius = ALVO_RAIO
	disco.height = 0.06
	_alvo_mat = StandardMaterial3D.new()
	_alvo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_alvo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_alvo_mat.albedo_color = Color(LARANJA.r, LARANJA.g, LARANJA.b, 0.0)
	_alvo = MeshInstance3D.new()
	_alvo.mesh = disco
	_alvo.material_override = _alvo_mat
	_alvo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_alvo)
	_alvo.global_position = onde + Vector3(0, 0.12, 0)


func _apagar() -> void:
	for mi in _aros:
		if is_instance_valid(mi):
			mi.queue_free()
	_aros.clear()
	_mats.clear()
	if _alvo and is_instance_valid(_alvo):
		_alvo.queue_free()
	_alvo = null
	if atual != "" and _balizas.has(atual):
		(_balizas[atual]["mat"] as StandardMaterial3D).emission_energy_multiplier = 0.6
	atual = ""
	correndo = false
	corrida = false
	Hud.aro_rota = Vector3.INF
	if rival and is_instance_valid(rival):
		rival.queue_free()
	rival = null


## As cores dos aros: o da vez em laranja (na difícil, apagando com o tempo), os seguintes em água-clara, e no
## escuro da fenda quase invisíveis até a luz chegar perto.
func _pintar_aros() -> void:
	var r: Dictionary = lista[atual]
	var escuro: bool = r.get("escuro", false)
	for i in _mats.size():
		var mat := _mats[i]
		if i < proximo:
			continue
		if i == proximo:
			var c := LARANJA
			if dificil and correndo and _prazo > 0.0:
				var resta := clampf(1.0 - _t_aro / _prazo, 0.0, 1.0)
				c = APAGANDO.lerp(LARANJA, smoothstep(0.0, 0.6, resta))
				c.a = lerpf(0.18, 1.0, resta)
			else:
				c.a = 0.55 if escuro else 1.0
			mat.albedo_color = c
			mat.disable_fog = true
		else:
			var a := 0.1 if escuro else (0.5 if i == proximo + 1 else 0.3)
			mat.albedo_color = Color(AGUA.r, AGUA.g, AGUA.b, a)
			mat.disable_fog = false
	if _alvo_mat:
		var na_vez := proximo >= _aros.size()
		_alvo_mat.albedo_color.a = (0.75 + 0.2 * sin(_t * 5.0)) if na_vez else 0.18


func _prazo_do(i: int) -> float:
	var r: Dictionary = lista[atual]
	var aros: Array = r["aros"]
	var de: Vector3 = r["baliza"] if i == 0 else aros[i - 1]
	var ate: Vector3 = aros[i]
	var vel := VEL_AGUA if r.get("agua", false) else VEL_AR
	var extra := 6.0 if i == 0 else FOLGA  # o primeiro inclui decolar
	return de.distance_to(ate) / vel + extra


func _falhar(motivo: String) -> void:
	ultimo_fim = motivo
	falhas += 1
	var id := atual
	Som.toque3d(self, "perdeu", armadura.global_position, -10.0)
	if hud:
		var frase := {"pousou": "pousou no caminho", "apagou": "o aro apagou", "longe": "ficou longe dos aros"}
		hud.avisar(titulo(id), String(frase.get(motivo, motivo)) + " · volte à baliza para tentar de novo")
	_apagar()


func _completar() -> void:
	var id := atual
	ultimo_fim = "feita"
	concluidas += 1
	var antes := int(feitas.get(id, 0))
	var nivel := 2 if dificil else 1
	var titulo_aviso := titulo(id) + (" · difícil" if dificil else "")
	var sub := "rota completa"
	if corrida:
		_fim_corrida(id)
		return
	if nivel > antes:
		feitas[id] = nivel
		if Guardado.ativo:
			Guardado.por_progresso("rotas", feitas)
	if antes == 0:
		rastro = id
		if Guardado.ativo:
			Guardado.por_progresso("rastro", rastro)
		sub = "rastro novo: " + String(NOMES_COR[id]) + " · troque na oficina da base"
	elif nivel == 2 and antes < 2:
		sub = "uma miniatura do lugar foi para a estante da base"
	if todas_feitas() and not Melhorias.achadas.has("corrida") and not Melhorias.instaladas.has("corrida"):
		Melhorias.achar("corrida")
		sub = "todas as rotas! peça nova: " + String(Melhorias.TITULOS["corrida"]).to_lower() + " · instale na base"
	Som.toque3d(self, "onda_vencida", armadura.global_position, -6.0)
	if hud:
		hud.avisar(titulo_aviso, sub)
	_apagar()
	if nivel == 2 and antes < 2:
		por_miniaturas()
	mudou.emit()


func _physics_process(delta: float) -> void:
	_t += delta
	if armadura == null or lista.is_empty():
		return
	var p := armadura.global_position
	var e := armadura.estado
	var no_chao := (e == Armadura.Estado.CHAO or e == Armadura.Estado.POUSO) and armadura.is_on_floor()
	# a luz das balizas: a acesa forte; as outras piscam devagar
	for id: String in _balizas:
		if id != atual:
			var m: StandardMaterial3D = _balizas[id]["mat"]
			m.emission_energy_multiplier = 0.5 + 0.35 * sin(_t * 2.0 + float(id.length()))
	if atual == "":
		if no_chao:
			for id: String in lista:
				var b: Vector3 = lista[id]["baliza"]
				if Vector2(p.x - b.x, p.z - b.z).length() < BALIZA_PERTO and absf(p.y - b.y) < 2.5:
					_acender(id)
					break
		return
	var r: Dictionary = lista[atual]
	var bal: Vector3 = r["baliza"]
	if not correndo:
		var pede := dado(atual, "pede")
		if pede != "" and not Melhorias.tem(pede):
			if Vector2(p.x - bal.x, p.z - bal.z).length() > BALIZA_SAI:
				_apagar()
			return
		if not no_chao and e != Armadura.Estado.NADO:
			correndo = true
			proximo = 0
			_t_aro = 0.0
			_prazo = _prazo_do(0) if dificil else 0.0
			_largar_rival()
		elif Vector2(p.x - bal.x, p.z - bal.z).length() > BALIZA_SAI:
			_apagar()
			return
		elif e == Armadura.Estado.NADO and r.get("agua", false):
			correndo = true
			proximo = 0
			_t_aro = 0.0
			_prazo = _prazo_do(0) if dificil else 0.0
			_largar_rival()
		_pintar_aros()
		return
	_t_aro += delta
	if corrida and rival and rival.chegou and not _avisou_rival:
		_avisou_rival = true
		Som.toque3d(self, "perdeu", p, -12.0)
		if hud:
			hud.avisar(titulo(atual) + " · corrida", "a gravação chegou primeiro · termine a rota mesmo assim")
	var aros: Array = r["aros"]
	var raio := RAIO_AGUA if r.get("agua", false) else RAIO_AR
	var centro := p + Vector3(0, armadura.altura_corpo() * 0.5, 0)
	if proximo < aros.size():
		var alvo: Vector3 = aros[proximo]
		if centro.distance_to(alvo) < raio + 0.6:
			_aros[proximo].visible = false
			proximo += 1
			_t_aro = 0.0
			Som.toque3d(self, "marcar", p, -6.0)
			if proximo >= aros.size():
				if r["fim"] == "aro":
					_completar()
					return
				_prazo = 0.0
				Hud.aro_rota = r["alvo"]
			else:
				_prazo = _prazo_do(proximo) if dificil else 0.0
				Hud.aro_rota = aros[proximo]
		elif dificil and _t_aro > _prazo:
			_falhar("apagou")
			return
		elif centro.distance_to(alvo) > LONGE:
			_falhar("longe")
			return
	else:
		var alvo_f: Vector3 = r["alvo"]
		if centro.distance_to(alvo_f) > LONGE:
			_falhar("longe")
			return
	# chegou ao chão: só vale no fim de pouso (o ninho); em qualquer outro lugar a rota acaba
	if no_chao:
		if proximo >= aros.size() and r["fim"] == "pouso":
			var alvo_p: Vector3 = r["alvo"]
			if Vector2(p.x - alvo_p.x, p.z - alvo_p.z).length() < NINHO_RAIO and p.y > alvo_p.y - 3.0:
				_completar()
				return
		if proximo == 0 and Vector2(p.x - bal.x, p.z - bal.z).length() < BALIZA_PERTO + 1.0:
			correndo = false  # voltou para a baliza sem passar por nenhum aro: ainda não começou
			if rival:
				rival.voltar()
			_avisou_rival = false
			_pintar_aros()
			return
		if proximo >= aros.size() and r["fim"] == "alvo" and _pouso_t < 0.4:
			_pouso_t += delta  # o sinal do mergulho no alvo pode chegar um quadro depois do chão
			return
		_falhar("pousou")
		return
	_pouso_t = 0.0
	_pintar_aros()


func _largar_rival() -> void:
	if corrida and rival:
		rival.largar()


## O fim de uma corrida: antes da gravação, o recorde é batido (na primeira vez, prêmio e a tacinha na estante).
func _fim_corrida(id: String) -> void:
	var ganhou := rival == null or not rival.chegou
	resultado_corrida = "ganhou" if ganhou else "perdeu"
	var titulo_aviso := titulo(id) + " · corrida"
	var sub := ""
	if ganhou:
		Som.toque3d(self, "onda_vencida", armadura.global_position, -4.0)
		if not recordes.has(id):
			recordes.append(id)
			if Guardado.ativo:
				Guardado.por_progresso("recordes", recordes)
			var nivel_antes := Arsenal.nivel()
			Arsenal.xp += 50
			Arsenal.sucata += 3
			Arsenal.guardar()
			sub = "recorde batido! uma tacinha foi para a estante · +50 de experiência"
			if Arsenal.nivel() > nivel_antes and hud:
				hud.avisar.call_deferred("Nível %d" % Arsenal.nivel(), "novas fabricações e melhorias na base")
		else:
			sub = "recorde batido de novo!"
		if recordes.size() == ROTAS.size():
			sub = "todos os recordes do piloto de teste são seus!"
	else:
		Som.toque3d(self, "marcar", armadura.global_position, -6.0)
		sub = "a gravação chegou antes · o recorde ainda é do piloto de teste"
	if hud:
		hud.avisar(titulo_aviso, sub)
	_apagar()
	if ganhou:
		por_miniaturas()
	mudou.emit()


## O mergulho com impacto (sinal `golpe_chao` da armadura): no alvo do mastro, fecha a rota.
func no_golpe(onde: Vector3) -> void:
	if atual == "" or not correndo:
		return
	var r: Dictionary = lista[atual]
	if r["fim"] != "alvo" or proximo < (r["aros"] as Array).size():
		return
	var alvo: Vector3 = r["alvo"]
	if Vector2(onde.x - alvo.x, onde.z - alvo.z).length() < ALVO_RAIO + 1.0:
		_completar()
