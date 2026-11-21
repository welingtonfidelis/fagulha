class_name Historia
extends Node3D
## A história de abertura (doc §134, 2026-11-21; a história é a do usuário, doc §87).
## O prólogo passa num jogo novo, antes da simulação, e de novo pelo botão "A história" da tela de abertura:
## tomadas na própria ilha, cada uma com uma frase grande (para quem lê em voz alta; a imagem conta sozinha
## para quem ainda não lê). A gente que vivia aqui, as torres e a represa, os gigantes dormindo, os anos
## passando, o Faísca passando a faísca dele para o corpo novo e os olhos acendendo.
## O despertar passa uma vez, na primeira volta à ilha depois da simulação: os olhos abrem, a câmera mostra o
## Faísca caído ao lado, o drone olha um e outro, e um cartão diz o que fazer agora (as memórias âmbar e o farol).
## Segurar o X pula. Durante as cenas o robô fica travado; nas tomadas longe da base ele fica escondido debaixo
## da câmera (o capim e os bichos nascem em volta dele). Lugares, peças, dicas e máquinas ficam parados.
## Quem cria passa `principal`, `armadura`, `camera`, `hud`, `drone`, `ciclo`, `mapa` e `parar`.

signal terminou(qual: String)

const TINTA := Color(0.95, 0.96, 0.93)
const APAGADO := Color(0.66, 0.72, 0.7)
const LARANJA := Color(1.0, 0.62, 0.3)
const AMBAR := Color(1.0, 0.72, 0.32)
const COR_FAISCA := Color(1.0, 0.74, 0.4)
const ESCURO := Color(0.02, 0.03, 0.035)
const SEGURAR := 1.2  # s com o X apertado para pular
const ESCURECE := 0.5  # s do escuro na entrada e na saída de cada tomada
const FAIXA := 0.105  # altura de cada faixa preta de cinema (fração da tela)
const FRASES := [
	"Aqui morava gente que queria ajudar o mundo.",
	"Fizeram torres de vento, uma represa e robôs para ajudar.",
	"Um dia, não sobrou mais ninguém na ilha. Ficaram os robôs e as lembranças.",
	"O Faísca ficou e cuidou de tudo por muitos e muitos anos.",
	"Quando o corpo dele cansou, ele passou tudo o que sabia para um corpo novo.",
]

var principal: Node
var armadura: Armadura
var camera: CameraVoo
var hud: Hud
var drone: DroneColega
var ciclo: CicloDia
var mapa: Vale
var parar: Array = []  # os nós que ficam parados durante as cenas

var rodando := ""  # "prologo", "despertar" ou ""
var rever := false  # o prólogo foi pedido pela tela de abertura: no fim, volta para ela
var tomada := -1  # a tomada em curso (testes e fotos)
var prologos := 0  # testes
var despertares := 0
var pulos := 0

var _lista: Array = []
var _t := 0.0
var _cam: Camera3D
var _camada: CanvasLayer
var _faixa_cima: ColorRect
var _faixa_baixo: ColorRect
var _faixa_k := 0.0
var _frase: Label
var _preto: ColorRect
var _pular: TextoBotoes
var _anel: Control
var _segura := 0.0
var _saindo := -1.0  # pulou: s do escurecer até o fim
var _musica: AudioStreamPlayer
var _modos := {}  # nó -> process_mode de antes
var _antes := {}  # o que as cenas mudam e devolvem no fim
var _brilho: Node3D  # a faísca que passa de um corpo para o outro
var _brilho_luz: OmniLight3D
var _rastro: CPUParticles3D
var _luz_rosto: OmniLight3D
var _som_religou := false
var _cartao: Control
var _cartao_t := -1.0  # o cartão do fim do despertar está na tela há tanto tempo
var _cartao_feito := false


## A pausa não abre no meio de uma cena.
func ocupada() -> bool:
	return rodando != ""


func _ready() -> void:
	add_to_group("sem_pausa")
	_cam = Camera3D.new()
	_cam.near = 0.1
	_cam.far = 14000.0
	_cam.fov = 50.0
	add_child(_cam)
	_montar_tela()
	_montar_brilho()
	_musica = AudioStreamPlayer.new()
	_musica.volume_db = -60.0
	add_child(_musica)


# ------------------------------------------------------------------ o que as cenas param e devolvem

## Para lugares, peças, dicas e máquinas, esconde a tela do jogo e trava o robô. Pode ser chamado antes de o
## primeiro quadro rodar (o jogo novo chama logo ao montar, para a Clareira não contar como visitada).
func parar_tudo() -> void:
	if _modos.is_empty():
		for no in parar:
			if no is Node and is_instance_valid(no):
				_modos[no] = (no as Node).process_mode
				(no as Node).process_mode = Node.PROCESS_MODE_DISABLED
	armadura.travado = true
	if armadura.visual:
		armadura.visual.olhos_abertos = 0.0
	if hud:
		hud.visible = false


## A tela já começa escura (o despertar, logo depois de a ilha abrir).
func cobrir() -> void:
	_camada.visible = true
	_preto.modulate.a = 1.0
	_frase.modulate.a = 0.0
	_cartao.visible = false


func _soltar_tudo() -> void:
	for no in _modos:
		if is_instance_valid(no):
			(no as Node).process_mode = _modos[no]
	_modos.clear()
	armadura.travado = false
	if armadura.visual:
		armadura.visual.visible = true
		armadura.visual.olhos_abertos = 1.0
	if hud:
		hud.visible = true
	if drone:
		drone.cena_lugar = Vector3.INF
	camera.cam.make_current()


func _guardar_antes() -> void:
	_antes = {"pos": armadura.global_position, "yaw": camera.yaw, "pitch": camera.pitch,
		"hora": ciclo.hora if ciclo else 9.5, "parado": ciclo.parado if ciclo else false}


func _devolver_antes() -> void:
	if _antes.is_empty():
		return
	armadura.teleportar(_antes["pos"], Armadura.Estado.CHAO)
	camera.yaw = _antes["yaw"]
	camera.pitch = _antes["pitch"]
	if ciclo:
		ciclo.hora = _antes["hora"]
		ciclo.parado = _antes["parado"]
	_antes = {}


# ------------------------------------------------------------------ começar

## O prólogo. `de_novo`: pedido pela tela de abertura (no fim volta a ela, sem ir para a simulação).
func prologo(de_novo := false) -> void:
	if rodando != "":
		return
	rever = de_novo
	prologos += 1
	_guardar_antes()
	parar_tudo()
	_lista = _tomadas_prologo()
	_comecar("prologo", "musica_vista")


func despertar() -> void:
	if rodando != "":
		return
	despertares += 1
	_antes = {}
	parar_tudo()
	_lista = _tomadas_despertar()
	_comecar("despertar", "musica_amanhecer")


func _comecar(qual: String, musica: String) -> void:
	rodando = qual
	_segura = 0.0
	_saindo = -1.0
	_som_religou = false
	_camada.visible = true
	_preto.modulate.a = 1.0
	_frase.modulate.a = 0.0
	_faixa_k = 0.0 if qual == "despertar" else 1.0
	_cartao.visible = false
	_cartao_t = -1.0
	_cartao_feito = false
	if ciclo:
		ciclo.parado = true
		ciclo.chovendo = false
		ciclo.chuva = 0.0
	_cam.make_current()
	if ResourceLoader.exists("res://assets/sons/%s.wav" % musica):
		_musica.stream = Som.laco_stream(musica) if musica == "musica_vista" else Som.stream(musica)
		_musica.volume_db = -40.0
		_musica.play()
		create_tween().tween_property(_musica, "volume_db", -8.0, 2.5)
	tomada = -1
	_proxima()


func _proxima() -> void:
	tomada += 1
	_t = 0.0
	if tomada >= _lista.size():
		_fim()
		return
	var tom: Dictionary = _lista[tomada]
	# o robô: escondido debaixo da câmera, ou de pé no estrado
	var onde = tom.get("robo", null)
	if onde is Vector3:
		armadura.teleportar(onde, Armadura.Estado.CHAO)
		if armadura.visual:
			armadura.visual.visible = false
	else:
		armadura.teleportar(mapa.spawn, Armadura.Estado.CHAO)
		camera.yaw = mapa.spawn_yaw
		if armadura.visual:
			armadura.visual.visible = true
	_frase.text = String(tom.get("frase", ""))
	_quadro(tom, 0.0, 0.0)


# ------------------------------------------------------------------ cada quadro

func _process(delta: float) -> void:
	_desenhar_faixas(delta)
	if rodando == "":
		return
	if _cartao_t >= 0.0:
		_no_cartao(delta)
		return
	if _saindo >= 0.0:
		_saindo += delta
		_preto.modulate.a = maxf(_preto.modulate.a, clampf(_saindo / 0.35, 0.0, 1.0))
		_frase.modulate.a = minf(_frase.modulate.a, 1.0 - _saindo / 0.35)
		_musica.volume_db = lerpf(_musica.volume_db, -50.0, 1.0 - exp(-4.0 * delta))
		if _saindo >= 0.45:
			_saindo = -1.0
			_fim()
		return
	_segurar(delta)
	if tomada < 0 or tomada >= _lista.size():
		return
	_t += delta
	var tom: Dictionary = _lista[tomada]
	var dur: float = tom["dur"]
	_quadro(tom, clampf(_t / dur, 0.0, 1.0), delta)
	if _t >= dur:
		_proxima()


func _quadro(tom: Dictionary, f: float, delta: float) -> void:
	var dur: float = tom["dur"]
	var pv: Array = (tom["cam"] as Callable).call(f)
	_cam.global_position = pv[0]
	if (pv[1] as Vector3).distance_to(pv[0]) > 0.01:
		_cam.look_at(pv[1], Vector3.UP)
	_cam.fov = float(tom.get("fov", 50.0))
	if tom.has("hora") and ciclo:
		var h: Array = tom["hora"]
		ciclo.hora = fposmod(lerpf(h[0], h[1], f), 24.0)
	# o escuro na entrada e na saída da tomada
	var entra: float = tom.get("entra", ESCURECE)
	var sai: float = tom.get("sai", ESCURECE)
	var a_entra := 1.0 - clampf(_t / entra, 0.0, 1.0) if entra > 0.0 else 0.0
	var a_sai := 1.0 - clampf((dur - _t) / sai, 0.0, 1.0) if sai > 0.0 else 0.0
	_preto.modulate.a = maxf(a_entra, a_sai)
	# a frase: chega depois do escuro e sai antes dele; entre duas tomadas de mesma frase ela fica
	var anterior := String((_lista[tomada - 1] as Dictionary).get("frase", "")) if tomada > 0 else ""
	var seguinte := String((_lista[tomada + 1] as Dictionary).get("frase", "")) if tomada + 1 < _lista.size() else ""
	var frase := String(tom.get("frase", ""))
	var fa := 1.0
	if frase == "":
		fa = 0.0
	else:
		if anterior != frase:
			fa = minf(fa, clampf((_t - 0.5) / 0.7, 0.0, 1.0))
		if seguinte != frase:
			fa = minf(fa, clampf((dur - _t - 0.45) / 0.6, 0.0, 1.0))
	_frase.modulate.a = fa
	if tom.has("faz"):
		(tom["faz"] as Callable).call(f, delta)


## Segurar o X pula a cena toda (o anel em volta do botão enche).
func _segurar(delta: float) -> void:
	if Input.is_action_pressed("pular"):
		_segura += delta
	else:
		_segura = maxf(0.0, _segura - delta * 2.5)
	_anel.queue_redraw()
	_pular.modulate.a = 0.55 + 0.45 * clampf(_segura / 0.25, 0.0, 1.0)
	if _segura >= SEGURAR:
		_segura = 0.0
		pulos += 1
		_saindo = 0.0


func _fim() -> void:
	tomada = -1
	_brilho.visible = false
	_rastro.emitting = false
	_luz_rosto.light_energy = 0.0
	var qual := rodando
	if qual == "prologo" and not rever:
		# jogo novo: do escuro direto para a simulação (a cena recarrega); a ilha fica de manhã para o despertar
		rodando = ""
		_preto.modulate.a = 1.0
		_frase.modulate.a = 0.0
		if Guardado.ativo:
			Guardado.por_progresso("prologo_visto", true)
		if ciclo:
			ciclo.hora = 7.6
		terminou.emit(qual)
		if principal and principal.has_method("trocar_mundo"):
			principal.call("trocar_mundo", true)
		return
	if qual == "despertar" and not _cartao_feito:
		_abrir_cartao()
		return
	rodando = ""
	_devolver_antes()
	_soltar_tudo()
	if qual == "despertar" and Guardado.ativo:
		Guardado.por_progresso("despertar_visto", true)
	var tw := create_tween()
	tw.tween_property(_preto, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _camada.visible = rodando != "")
	create_tween().tween_property(_musica, "volume_db", -60.0, 2.0).finished.connect(_musica.stop)
	terminou.emit(qual)


# ------------------------------------------------------------------ as tomadas

func _chao(x: float, z: float) -> float:
	return mapa.altura(x, z)


## Uma câmera que vai de um ponto a outro, olhando de um alvo a outro, com saída e chegada macias.
func _vai(de: Vector3, olha_de: Vector3, ate: Vector3, olha_ate: Vector3, curva := 0.6) -> Callable:
	return func(f: float) -> Array:
		var k := lerpf(f, smoothstep(0.0, 1.0, f), curva)
		return [de.lerp(ate, k), olha_de.lerp(olha_ate, k)]


## Uma câmera que gira em volta de `centro` (graus do ângulo no chão: 0 é +X, 90 é +Z).
func _volta(centro: Vector3, raio: float, alto: float, g0: float, g1: float, olha_alto: float) -> Callable:
	return func(f: float) -> Array:
		var a := deg_to_rad(lerpf(g0, g1, f))
		return [centro + Vector3(cos(a) * raio, alto, sin(a) * raio), centro + Vector3(0, olha_alto, 0)]


## Onde fica o robô escondido numa tomada longe da base: no chão, perto da câmera.
func _esconder(x: float, z: float) -> Vector3:
	return Vector3(x, _chao(x, z) + 0.3, z)


func _tomadas_prologo() -> Array:
	var lista: Array = []
	# 1. Os Arcos de manhã: a câmera desce do alto até perto dos pilares
	var ax := Vector2(Ruinas.ARCOS.x, Ruinas.ARCOS.y)
	var eixo := Vector2(cos(Ruinas.ARCOS.z), -sin(Ruinas.ARCOS.z))
	var lado := Vector2(eixo.y, -eixo.x)
	if lado.y < 0.0:
		lado = -lado
	var ca := Vector3(ax.x, _chao(ax.x, ax.y), ax.y)
	var p1 := ax + lado * 120.0 - eixo * 30.0
	var p2 := ax + lado * 30.0 - eixo * 14.0
	lista.append({"frase": FRASES[0], "dur": 9.0, "hora": [7.1, 7.5], "fov": 48.0, "entra": 1.2,
		"robo": _esconder(p2.x, p2.y),
		"cam": _vai(Vector3(p1.x, _chao(p1.x, p1.y) + 70.0, p1.y), ca + Vector3(0, 4.0, 0),
			Vector3(p2.x, _chao(p2.x, p2.y) + 7.5, p2.y), ca + Vector3(eixo.x * 10.0, 5.0, eixo.y * 10.0))})
	# 2. As Torres do Vento: a câmera corre ao longo da fila, do lado de terra
	var t1: Vector2 = MarcosOeste.TORRES[1]
	var t2: Vector2 = MarcosOeste.TORRES[2]
	var t3: Vector2 = MarcosOeste.TORRES[3]
	var zc := t1.y + 52.0
	var ht := _chao(t2.x, t2.y)
	lista.append({"frase": FRASES[1], "dur": 6.5, "hora": [9.4, 9.6], "fov": 55.0,
		"robo": _esconder(70.0, zc),
		"cam": _vai(Vector3(30.0, ht + 38.0, zc), Vector3(t2.x, ht + 36.0, t2.y),
			Vector3(105.0, ht + 44.0, zc + 4.0), Vector3(t3.x, ht + 36.0, t3.y), 0.3)})
	# 2b. A represa, de baixo, rio abaixo
	var rp := MarcosLeste.REPRESA
	var r1 := rp + Vector2(84.0, 40.0)
	var r2 := rp + Vector2(62.0, 22.0)
	lista.append({"frase": FRASES[1], "dur": 5.5, "hora": [9.8, 10.0], "fov": 50.0,
		"robo": _esconder(r2.x, r2.y),
		"cam": _vai(Vector3(r1.x, _chao(r1.x, r1.y) + 14.0, r1.y), Vector3(rp.x, 30.0, rp.y),
			Vector3(r2.x, _chao(r2.x, r2.y) + 9.0, r2.y), Vector3(rp.x, 32.0, rp.y + 6.0), 0.3)})
	# 3. Os gigantes dormindo no campo, no fim da tarde
	# (eles têm uns 50 m de altura: a câmera fica a uns 200 m, como nas fotos do doc)
	var g := MarcosLeste.GIGANTES
	var hg := _chao(g.x, g.y)
	var esc := Vector2(g.x - 150.0, g.y + 150.0)
	lista.append({"frase": FRASES[2], "dur": 9.5, "hora": [17.6, 17.9], "fov": 50.0,
		"robo": _esconder(esc.x, esc.y),
		"cam": _vai(Vector3(g.x - 215.0, hg + 55.0, g.y + 195.0), Vector3(g.x - 5.0, hg + 30.0, g.y),
			Vector3(g.x - 160.0, hg + 30.0, g.y + 150.0), Vector3(g.x + 10.0, hg + 36.0, g.y), 0.4)})
	# 4. Os anos passando: o sol corre sobre o vale, visto de cima da clareira
	var cume: Vector3 = mapa.cume
	var de4 := Vector3(70.0, 0, 190.0)
	lista.append({"frase": FRASES[3], "dur": 9.5, "hora": [5.6, 5.6 + 24.0], "fov": 55.0,
		"robo": _esconder(de4.x, de4.z),
		"cam": _vai(Vector3(de4.x, _chao(de4.x, de4.z) + 48.0, de4.z), Vector3(cume.x, cume.y * 0.7, cume.z),
			Vector3(de4.x - 40.0, _chao(de4.x, de4.z) + 52.0, de4.z - 10.0), Vector3(cume.x - 60.0, cume.y * 0.7, cume.z), 0.2)})
	# 5. A base no anoitecer: a faísca sai do peito do Faísca caído e entra no robô novo, no estrado
	var rob := mapa.spawn
	var fz := BaseVale.faisca_em if BaseVale.faisca_em.is_finite() else rob + Vector3(3.0, 0, -3.0)
	var meio := (rob + fz) * 0.5
	# medidas do lugar da base (BaseVale): o estrado no meio, o Faísca em (3,3; -3,0) olhando para ele, o campo em -Z
	var tb := BaseVale.t_base
	var de5 := tb * Vector3(-2.0, 1.45, -5.4)
	var ate5 := tb * Vector3(-1.25, 1.15, -4.3)
	var peito_f := fz + Vector3(0, 0.55, 0)
	var peito_r := rob + Vector3(0, armadura.altura_corpo() * 0.58, 0)
	lista.append({"frase": FRASES[4], "dur": 11.0, "hora": [19.0, 19.15], "fov": 44.0, "sai": 0.0,
		"cam": _vai(de5, meio + Vector3(0, 0.6, 0), ate5, meio.lerp(rob, 0.3) + Vector3(0, 0.65, 0)),
		"faz": func(f: float, delta: float) -> void: _passar_faisca(f, delta, peito_f, peito_r)})
	# 6. Os olhos acendem: de perto, de frente para o robô
	lista.append({"frase": "", "dur": 5.5, "hora": [19.15, 19.2], "fov": 34.0, "entra": 0.35, "sai": 1.2,
		"cam": _rosto(1.9, 1.35),
		"faz": func(f: float, _delta: float) -> void: _abrir_olhos(f, 0.22, 0.5, false)})
	return lista


func _tomadas_despertar() -> Array:
	var lista: Array = []
	var rob := mapa.spawn
	var fz := BaseVale.faisca_em if BaseVale.faisca_em.is_finite() else rob + Vector3(3.0, 0, -3.0)
	# 1. De perto, os olhos abrem de manhã
	lista.append({"frase": "", "dur": 5.0, "hora": [7.6, 7.65], "fov": 36.0, "entra": 1.4, "sai": 0.3,
		"cam": _rosto(2.2, 1.5),
		"faz": func(f: float, _delta: float) -> void: _abrir_olhos(f, 0.28, 0.62, true)})
	# 2. Por cima do ombro do robô, o Faísca caído na frente dele, de cara para o estrado; o drone chega entre
	# os dois e olha um e o outro (medidas do lugar da base: o estrado no meio, o Faísca em (3,3; -3,0))
	var tb := BaseVale.t_base
	var junto := tb * Vector3(2.4, 1.75, -3.8)  # ao lado do Faísca, à esquerda dele na tela (mais para o meio, a cabeça do robô escondia o drone)
	lista.append({"frase": "", "dur": 7.5, "hora": [7.65, 7.75], "fov": 46.0, "entra": 0.3,
		"cam": _vai(tb * Vector3(-2.3, 1.6, 1.0), rob.lerp(fz, 0.7) + Vector3(0, 0.55, 0),
			tb * Vector3(-1.7, 1.25, 0.55), rob.lerp(fz, 0.78) + Vector3(0, 0.5, 0)),
		"faz": func(f: float, _delta: float) -> void: _drone_olha(f, junto, fz + Vector3(0, 0.5, 0), rob + Vector3(0, 0.9, 0))})
	return lista


## De frente para o rosto do robô, a `dist` metros, um pouco acima dos olhos.
func _rosto(dist: float, alto_k: float) -> Callable:
	return func(f: float) -> Array:
		var olho := _olhos_em()
		var frente := _frente_robo()
		var de := olho + frente * (dist + 0.25) + Vector3(0, 0.12 * alto_k, 0)
		var ate := olho + frente * dist + Vector3(0, 0.06 * alto_k, 0)
		var k := smoothstep(0.0, 1.0, f)
		return [de.lerp(ate, k), olho - Vector3(0, 0.05, 0)]


func _frente_robo() -> Vector3:
	if armadura.visual:
		var ry := armadura.visual.global_rotation.y
		return -Vector3(sin(ry), 0, cos(ry))
	return Vector3(-sin(mapa.spawn_yaw), 0, -cos(mapa.spawn_yaw))


func _olhos_em() -> Vector3:
	if armadura.visual and armadura.visual.modelo:
		var e := armadura.visual.modelo.find_child("olhoE", true, false) as Node3D
		var d := armadura.visual.modelo.find_child("olhoD", true, false) as Node3D
		if e and d:
			return (e.global_position + d.global_position) * 0.5
	return armadura.global_position + Vector3(0, armadura.altura_corpo() * 0.82, 0)


## Os olhos abrem entre `f0` e `f1`, com uma luz rápida no rosto; `piscar`: abrem, fecham e abrem (o despertar).
func _abrir_olhos(f: float, f0: float, f1: float, piscar: bool) -> void:
	if armadura.visual == null:
		return
	var k := clampf((f - f0) / (f1 - f0), 0.0, 1.0)
	if piscar:
		# meio aberto, fecha de novo, e abre de vez
		if k < 0.33:
			k = k / 0.33 * 0.55
		elif k < 0.5:
			k = 0.55 * (1.0 - (k - 0.33) / 0.17)
		else:
			k = smoothstep(0.5, 1.0, k)
	armadura.visual.olhos_abertos = k
	if f >= f0 and not _som_religou:
		_som_religou = true
		Som.toque3d(self, "religar", _olhos_em(), -4.0, 6.0, 40.0)
	_luz_rosto.light_color = Color(0.7, 0.95, 1.0)
	_luz_rosto.global_position = _olhos_em() + _frente_robo() * 0.7
	_luz_rosto.light_energy = (0.25 if ciclo and not ciclo.eh_noite() else 0.6) * sin(clampf((f - f0) / (f1 - f0 + 0.15), 0.0, 1.0) * PI)


## O drone vem para junto dos dois e olha o Faísca, depois o robô (e fala).
func _drone_olha(f: float, junto: Vector3, fz: Vector3, rob: Vector3) -> void:
	if drone == null:
		return
	if f < 0.15:
		drone.cena_lugar = drone.posto
		drone.cena_olha = rob
		return
	drone.cena_lugar = junto
	drone.cena_olha = fz if f < 0.6 else rob
	if f >= 0.62 and not bool(drone.get_meta("falou_cena", false)):
		drone.set_meta("falou_cena", true)
		drone.falar()
		drone.gesto("Look", 1.4)


## A faísca: brilha no peito do Faísca, sobe num arco e entra no peito do robô, que acende por um instante.
func _passar_faisca(f: float, _delta: float, de: Vector3, ate: Vector3) -> void:
	var k0 := 0.22
	var k1 := 0.72
	if f < k0 * 0.5:
		_brilho.visible = false
		_rastro.emitting = false
		_luz_rosto.light_energy = 0.0
		return
	_brilho.visible = f < k1 + 0.02
	var k := clampf((f - k0) / (k1 - k0), 0.0, 1.0)
	var e := smoothstep(0.0, 1.0, k)
	var arco := Vector3(0, sin(e * PI) * 1.4, 0)
	_brilho.global_position = de.lerp(ate, e) + arco
	# antes de sair, junta luz no peito dele; no caminho, deixa um rastro
	var junta := clampf((f - k0 * 0.5) / (k0 * 0.5), 0.0, 1.0)
	_brilho.scale = Vector3.ONE * lerpf(0.3, 1.0, junta) * (1.0 + 0.12 * sin(f * 80.0))
	_brilho_luz.light_energy = 2.2 * junta
	_rastro.emitting = k > 0.0 and k < 1.0
	# chegou: o peito do robô acende e apaga
	var chegou := clampf((f - k1) / 0.18, 0.0, 1.0)
	_luz_rosto.light_color = COR_FAISCA
	_luz_rosto.global_position = ate + _frente_robo() * 0.3
	_luz_rosto.light_energy = 4.0 * sin(chegou * PI) if f > k1 else 0.0


# ------------------------------------------------------------------ o cartão do fim do despertar

func _abrir_cartao() -> void:
	_cartao_t = 0.0
	# a câmera volta para trás do robô, no lugar de jogar
	camera.yaw = mapa.spawn_yaw
	camera.pitch = -0.12
	camera.cam.make_current()
	if armadura.visual:
		armadura.visual.olhos_abertos = 1.0
	_preto.modulate.a = 0.0
	_cartao.visible = true
	_cartao.modulate.a = 0.0
	create_tween().tween_property(_cartao, "modulate:a", 1.0, 0.4)
	if drone:
		drone.cena_lugar = Vector3.INF


func _no_cartao(delta: float) -> void:
	_cartao_t += delta
	_faixa_k = move_toward(_faixa_k, 0.0, delta * 2.0)
	if _cartao_t > 1.2 and (Input.is_action_just_pressed("pular") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel")):
		_cartao.visible = false
		_cartao_t = -1.0
		_cartao_feito = true
		_fim()


# ------------------------------------------------------------------ a tela

func _montar_tela() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 12
	_camada.visible = false
	add_child(_camada)
	_preto = ColorRect.new()
	_preto.color = ESCURO
	_preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_preto)
	_faixa_cima = ColorRect.new()
	_faixa_baixo = ColorRect.new()
	for fx: ColorRect in [_faixa_cima, _faixa_baixo]:
		fx.color = ESCURO
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.anchor_left = 0.0
		fx.anchor_right = 1.0
		_camada.add_child(fx)
	_frase = Label.new()
	_frase.anchor_left = 0.08
	_frase.anchor_right = 0.92
	_frase.anchor_top = 0.72
	_frase.anchor_bottom = 0.86
	_frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frase.add_theme_font_size_override("font_size", 38)
	_frase.add_theme_color_override("font_color", TINTA)
	_frase.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.85))
	_frase.add_theme_constant_override("outline_size", 10)
	_frase.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_frase.add_theme_constant_override("shadow_offset_y", 3)
	_frase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_frase)
	# segure X para pular: o botão, um anel que enche e a palavra
	var canto := HBoxContainer.new()
	canto.anchor_left = 1.0
	canto.anchor_right = 1.0
	canto.anchor_top = 1.0
	canto.anchor_bottom = 1.0
	canto.offset_left = -300.0
	canto.offset_right = -34.0
	canto.offset_top = -64.0
	canto.offset_bottom = -22.0
	canto.alignment = BoxContainer.ALIGNMENT_END
	canto.add_theme_constant_override("separation", 10)
	_camada.add_child(canto)
	_anel = Control.new()
	_anel.custom_minimum_size = Vector2(40, 40)
	_anel.draw.connect(_desenhar_anel)
	canto.add_child(_anel)
	_pular = TextoBotoes.new()
	_pular.texto = "segure {pular} para pular"
	_pular.tamanho = 19
	_pular.cor = APAGADO
	_pular.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	canto.add_child(_pular)
	_montar_cartao()


func _desenhar_anel() -> void:
	var c := _anel.size * 0.5
	_anel.draw_arc(c, 15.0, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 3.0, true)
	var k := clampf(_segura / SEGURAR, 0.0, 1.0)
	if k > 0.0:
		_anel.draw_arc(c, 15.0, -PI * 0.5, -PI * 0.5 + TAU * k, 40, LARANJA, 4.0, true)


func _desenhar_faixas(delta: float) -> void:
	if rodando != "" and _cartao_t < 0.0:
		_faixa_k = move_toward(_faixa_k, 1.0, delta * 1.5)
	elif rodando == "":
		_faixa_k = move_toward(_faixa_k, 0.0, delta * 2.0)
	_faixa_cima.anchor_top = 0.0
	_faixa_cima.anchor_bottom = FAIXA * _faixa_k
	_faixa_baixo.anchor_top = 1.0 - FAIXA * _faixa_k
	_faixa_baixo.anchor_bottom = 1.0
	for fx: ColorRect in [_faixa_cima, _faixa_baixo]:
		fx.offset_top = 0.0
		fx.offset_bottom = 0.0
	_pular.get_parent().visible = rodando != "" and _cartao_t < 0.0


## O cartão do fim do despertar: o que fazer agora, com figuras (quem não lê entende pelas figuras).
func _montar_cartao() -> void:
	_cartao = CenterContainer.new()
	_cartao.anchor_left = 0.0
	_cartao.anchor_right = 1.0
	_cartao.anchor_top = 0.0
	_cartao.anchor_bottom = 1.0
	_cartao.visible = false
	_camada.add_child(_cartao)
	var painel := PanelContainer.new()
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = Color(0.045, 0.075, 0.08, 0.95)
	caixa.border_color = Color(0.25, 0.37, 0.38)
	caixa.set_border_width_all(2)
	caixa.set_corner_radius_all(8)
	caixa.set_content_margin_all(30)
	painel.add_theme_stylebox_override("panel", caixa)
	_cartao.add_child(painel)
	var pilha := VBoxContainer.new()
	pilha.add_theme_constant_override("separation", 14)
	pilha.custom_minimum_size = Vector2(660, 0)
	painel.add_child(pilha)
	var titulo := Label.new()
	titulo.text = "A ilha agora é sua para cuidar."
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 34)
	titulo.add_theme_color_override("font_color", LARANJA)
	pilha.add_child(titulo)
	var figura := Control.new()
	figura.custom_minimum_size = Vector2(660, 170)
	figura.draw.connect(_desenhar_meta.bind(figura))
	pilha.add_child(figura)
	var frase := Label.new()
	frase.text = "Pela ilha há memórias âmbar guardando o que aconteceu aqui. Com todas lidas, o farol pode acender de novo."
	frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frase.add_theme_font_size_override("font_size", 22)
	frase.add_theme_color_override("font_color", TINTA)
	pilha.add_child(frase)
	var rodape := TextoBotoes.new()
	rodape.texto = "{pular}  começar"
	rodape.tamanho = 20
	rodape.cor = APAGADO
	rodape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pilha.add_child(rodape)


## Três memórias âmbar, uma seta e o farol aceso.
func _desenhar_meta(fig: Control) -> void:
	var meio_y := fig.size.y * 0.5
	var x0 := fig.size.x * 0.5 - 250.0
	var t := Time.get_ticks_msec() * 0.001
	for k in 3:
		var c := Vector2(x0 + k * 74.0, meio_y + sin(t * 1.6 + k) * 4.0)
		var losango := PackedVector2Array([c + Vector2(0, -38), c + Vector2(22, 0), c + Vector2(0, 38), c + Vector2(-22, 0)])
		fig.draw_circle(c, 34.0, Color(AMBAR.r, AMBAR.g, AMBAR.b, 0.12))
		fig.draw_colored_polygon(losango, AMBAR)
		fig.draw_line(c + Vector2(-22, 0), c + Vector2(22, 0), Color(0.75, 0.45, 0.15), 2.0, true)
	# a seta
	var sx := x0 + 3 * 74.0 - 4.0
	fig.draw_line(Vector2(sx, meio_y), Vector2(sx + 90.0, meio_y), TINTA, 5.0, true)
	fig.draw_colored_polygon(PackedVector2Array([Vector2(sx + 108.0, meio_y), Vector2(sx + 84.0, meio_y - 17.0), Vector2(sx + 84.0, meio_y + 17.0)]), TINTA)
	# o farol: torre listrada, a lanterna e os raios de luz
	var fx := sx + 168.0
	var base_y := meio_y + 66.0
	var topo_y := meio_y - 34.0
	var torre := PackedVector2Array([Vector2(fx - 26, base_y), Vector2(fx - 15, topo_y), Vector2(fx + 15, topo_y), Vector2(fx + 26, base_y)])
	fig.draw_colored_polygon(torre, Color(0.9, 0.9, 0.86))
	for k in 2:
		var y1 := lerpf(base_y, topo_y, 0.22 + k * 0.38)
		var y2 := lerpf(base_y, topo_y, 0.38 + k * 0.38)
		var w1 := lerpf(26.0, 15.0, 0.22 + k * 0.38)
		var w2 := lerpf(26.0, 15.0, 0.38 + k * 0.38)
		fig.draw_colored_polygon(PackedVector2Array([Vector2(fx - w1, y1), Vector2(fx - w2, y2), Vector2(fx + w2, y2), Vector2(fx + w1, y1)]), Color(0.85, 0.3, 0.22))
	fig.draw_rect(Rect2(fx - 13, topo_y - 22, 26, 22), AMBAR)
	fig.draw_colored_polygon(PackedVector2Array([Vector2(fx - 18, topo_y - 22), Vector2(fx, topo_y - 40), Vector2(fx + 18, topo_y - 22)]), Color(0.3, 0.32, 0.33))
	for s: float in [-1.0, 1.0]:
		var giro := 0.18 * sin(t * 1.4)
		var dir_a := Vector2(s, -0.12 + giro).normalized()
		var dir_b := Vector2(s, 0.12 + giro).normalized()
		var ponta := Vector2(fx, topo_y - 11)
		fig.draw_colored_polygon(PackedVector2Array([ponta, ponta + dir_a * 70.0, ponta + dir_b * 70.0]), Color(AMBAR.r, AMBAR.g, AMBAR.b, 0.4))
	fig.queue_redraw()


# ------------------------------------------------------------------ a faísca

func _montar_brilho() -> void:
	_brilho = Node3D.new()
	_brilho.visible = false
	add_child(_brilho)
	var bola := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.075
	esf.height = 0.15
	bola.mesh = esf
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.82)
	mat.emission_enabled = true
	mat.emission = COR_FAISCA
	mat.emission_energy_multiplier = 6.0
	bola.material_override = mat
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brilho.add_child(bola)
	var halo := MeshInstance3D.new()
	var esf2 := SphereMesh.new()
	esf2.radius = 0.2
	esf2.height = 0.4
	halo.mesh = esf2
	var mat2 := StandardMaterial3D.new()
	mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat2.albedo_color = Color(COR_FAISCA.r, COR_FAISCA.g, COR_FAISCA.b, 0.28)
	mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.material_override = mat2
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brilho.add_child(halo)
	_brilho_luz = OmniLight3D.new()
	_brilho_luz.light_color = COR_FAISCA
	_brilho_luz.omni_range = 4.0
	_brilho_luz.light_energy = 0.0
	_brilho.add_child(_brilho_luz)
	_rastro = CPUParticles3D.new()
	_rastro.emitting = false
	_rastro.amount = 60
	_rastro.lifetime = 0.7
	_rastro.local_coords = false
	_rastro.gravity = Vector3(0, 0.15, 0)
	_rastro.direction = Vector3.UP
	_rastro.spread = 180.0
	_rastro.initial_velocity_min = 0.05
	_rastro.initial_velocity_max = 0.25
	_rastro.scale_amount_min = 0.5
	_rastro.scale_amount_max = 1.0
	var curva := Curve.new()
	curva.add_point(Vector2(0, 1))
	curva.add_point(Vector2(1, 0))
	_rastro.scale_amount_curve = curva
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var mat3 := StandardMaterial3D.new()
	mat3.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat3.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat3.albedo_color = Color(1.0, 0.82, 0.5, 0.85)
	mat3.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat3.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat3
	_rastro.mesh = quad
	_brilho.add_child(_rastro)
	_luz_rosto = OmniLight3D.new()
	_luz_rosto.light_color = Color(0.7, 0.95, 1.0)
	_luz_rosto.omni_range = 2.6
	_luz_rosto.light_energy = 0.0
	_luz_rosto.shadow_enabled = false
	add_child(_luz_rosto)
