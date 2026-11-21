class_name RaposaAmiga
extends Node3D
## A raposa que acompanha (1.1, doc §136). As raposas fogem de quem chega correndo, mas se acalmam com o robô
## quieto a mais de 9 m. Ficando quieto perto de uma raposa calma (a menos de 22 m), ela vai pegando confiança:
## uns 40 segundos ao todo, com um coraçãozinho subindo dela a cada terço. Se ela fugir, perde um pouco.
## Cheia a confiança, ela vira a amiga: segue o robô pela ilha, andando perto e galopando quando ele se
## afasta. Se ele voar para longe (mais de 160 m), ela aparece de novo atrás dele quando ele pousa, fora da
## vista, e vem correndo. A amiga fica guardada (volta com o jogo carregado).
## Quem cria passa `armadura`, `hud`, `mapa` e `vida`.

const PERTO := 22.0
const TEMPO_CONFIANCA := 40.0
const LONGE := 160.0
const ROSA := Color(1.0, 0.45, 0.6)

var armadura: Armadura
var hud: Hud
var mapa: Vale
var vida: VidaVale
var raposa: Raposa = null  # a amiga
var confianca := 0.0  # 0 a 1, com a raposa de agora
var de_quem: Raposa = null
var trazidas := 0  # vezes que ela reapareceu perto do robô (testes)
var coracoes := 0  # testes

var _amiga := false
var _avisou := false
var _degrau := 0
var _longe_t := 0.0
var _coracao: ImageTexture


func _ready() -> void:
	if Guardado.ativo:
		var g: Dictionary = Guardado.progresso("raposa")
		_amiga = bool(g.get("amiga", false))
		_avisou = bool(g.get("avisou", false))
	_coracao = _textura_coracao()


func _guardar() -> void:
	if Guardado.ativo:
		Guardado.por_progresso("raposa", {"amiga": _amiga, "avisou": _avisou})


func _process(delta: float) -> void:
	if armadura == null:
		return
	if raposa != null and not is_instance_valid(raposa):
		raposa = null
	if _amiga and raposa == null:
		# a amiga do jogo guardado: aparece atrás do robô quando ele estiver no chão
		if armadura.estado == Armadura.Estado.CHAO and not Cavernas.no_subsolo(armadura.global_position):
			trazer()
		return
	if raposa != null:
		var a := armadura.global_position
		var d := Vector2(a.x - raposa.global_position.x, a.z - raposa.global_position.z).length()
		_longe_t = _longe_t + delta if d > LONGE else 0.0
		if _longe_t > 2.0 and armadura.estado == Armadura.Estado.CHAO and not Cavernas.no_subsolo(a):
			trazer()
		return
	_confiar(delta)


# ---------------------------------------------------------------- a confiança

func _confiar(delta: float) -> void:
	var a := armadura.global_position
	var melhor: Raposa = null
	var md := PERTO
	for b in get_tree().get_nodes_in_group("bichos"):
		if b is Raposa and (b as Raposa).guia == null:
			var d := Vector2(a.x - (b as Node3D).global_position.x, a.z - (b as Node3D).global_position.z).length()
			if d < md:
				md = d
				melhor = b
	if melhor != de_quem:
		de_quem = melhor
		confianca = 0.0
		_degrau = 0
	if de_quem == null:
		return
	var quieto := armadura.estado == Armadura.Estado.CHAO and Vector2(armadura.velocity.x, armadura.velocity.z).length() < Cervo.VEL_PARADA
	if de_quem.estado == Cervo.Estado.FUGINDO:
		confianca = maxf(0.0, confianca - delta * 0.08)
		_degrau = int(confianca * 3.0)
		return
	if not (quieto and de_quem._acalmado):
		return
	if not _avisou and hud:
		_avisou = true
		_guardar()
		hud.avisar("Uma raposa", "fique quietinho perto dela")
	confianca = minf(1.0, confianca + delta / TEMPO_CONFIANCA)
	var degrau := int(confianca * 3.0)
	if degrau > _degrau:
		_degrau = degrau
		_coracoes(de_quem, 1 if degrau < 3 else 3)
	if confianca >= 1.0:
		_adotar(de_quem)


func _adotar(r: Raposa) -> void:
	# sai da conta da vida do vale (senão ela some quando o robô vai embora dali)
	if vida:
		for l: Dictionary in vida.lugares:
			var nos: Array = l["nos"]
			if nos.has(r):
				nos.erase(r)
				l["quantos"] = int(l["quantos"]) - 1
				if int(l["quantos"]) <= 0:
					l["pos"] = Vector3(1.0e7, 0.0, 1.0e7)  # o lugar fica sem raposa: não cria outra ali
	r.reparent(self)
	r.ameaca = null
	r._tem_ameaca = false
	r.guia = armadura
	raposa = r
	_amiga = true
	_guardar()
	Som.toque3d(self, "marcar", r.global_position + Vector3(0, 0.6, 0), -8.0)
	if hud:
		hud.avisar("A raposa confia em você!", "agora ela vai junto pela ilha")


## Põe a amiga atrás do robô, a uns 40 m, fora da vista da câmera e em chão seco; ela vem correndo.
func trazer() -> void:
	var a := armadura.global_position
	var cam := get_viewport().get_camera_3d()
	var tras := Vector3(0, 0, 1)
	if cam:
		tras = cam.global_basis.z
		tras.y = 0.0
		tras = tras.normalized() if tras.length() > 0.01 else Vector3(0, 0, 1)
	var p := Vector3.INF
	for k in 12:
		var ang := (k / 2) * 0.35 * (1.0 if k % 2 == 0 else -1.0)
		var q := a + tras.rotated(Vector3.UP, ang) * (40.0 - k * 1.5)
		if mapa.agua(q.x, q.z) == -INF and mapa.normal_em(q.x, q.z).y > 0.85 and Obstaculos.livre(mapa, q.x, q.z, 0.2):
			p = Vector3(q.x, mapa.altura(q.x, q.z), q.z)
			break
	if not p.is_finite():
		return
	if raposa == null:
		var r := Raposa.new()
		r.mapa = mapa
		r.casa = p
		r.raio_casa = 45.0
		r.semente = 4242
		r.guia = armadura
		r.position = p
		add_child(r)
		raposa = r
	else:
		raposa.global_position = p
	_longe_t = 0.0
	trazidas += 1


# ---------------------------------------------------------------- os coraçõezinhos

func _coracoes(r: Node3D, n: int) -> void:
	for i in n:
		var s := Sprite3D.new()
		s.texture = _coracao
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.013
		s.modulate = ROSA
		s.no_depth_test = true
		s.shaded = false
		var alto := (r as Cervo).altura_bicho + 0.35
		s.position = Vector3((i - (n - 1) * 0.5) * 0.35, alto, 0)
		s.modulate.a = 0.0
		r.add_child(s)
		var tw := s.create_tween()
		tw.tween_interval(i * 0.18)
		tw.tween_property(s, "modulate:a", 1.0, 0.25)
		tw.parallel().tween_property(s, "position:y", alto + 0.9, 1.6)
		tw.tween_property(s, "modulate:a", 0.0, 0.5)
		tw.tween_callback(s.queue_free)
		coracoes += 1


static func _textura_coracao() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for py in 64:
		for px in 64:
			var x := (px - 31.5) / 24.0
			var y := -(py - 34.0) / 24.0
			var f := pow(x * x + y * y - 1.0, 3.0) - x * x * y * y * y
			var a := clampf(-f * 12.0 + 0.5, 0.0, 1.0)
			img.set_pixel(px, py, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
