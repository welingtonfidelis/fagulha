class_name AmigoRobo
extends Node3D
## Um robô achado que passou a morar na base (2026-11-23, doc §144). Ninguém mais veste o corpo dele: o jeito
## dele virou um conjunto da aba Corpo (Corpo.ACHADOS), e ele vive a rotina dele.
##  - **o antigo** (robo_v1): de dia cuida da horta, senta num banco da fogueira ou fica na beira da laje
##    olhando o campo; de noite sobe com os jatos no telheiro e fica sentado na beira, olhando o céu (era o que
##    ele ia fazer no Observatório). De manhã desce.
##  - **o mergulhador** (robo_v3): mora na água mais perto da base. Fica sentado na margem com os pés de pato
##    na água, balançando as pernas, e de vez em quando entra e nada um pouco em roda (de dia).
## Os dois acenam quando o robô chega perto depois de ter ido longe. São colegas: com eles na mira o tiro não
## sai (Tiro) e o scanner os conhece. Não têm colisão.
## Quem cria passa `tipo`, `armadura` e `mapa`.

const MODELOS := {"antigo": "res://assets/vale/robo_v1.glb", "mergulhador": "res://assets/vale/robo_v3.glb"}
const ANDA := 0.95  # m/s
const NADA := 0.6
const ACENO := 2.6  # segundos acenando
const PERTO := 9.0  # chegando a essa distância depois de ter estado longe, ele acena
const LONGE := 26.0
const SALTO := 1.4  # segundos do pulo de jato até o telhado (e de volta)
const TELHADO := Vector3(-2.6, 0.0, 0.72)  # no lugar da base: onde a bacia dele apoia, na beira do telheiro
const AFUNDA := 0.68  # nadando, os pés ficam esse tanto abaixo da lâmina (os ombros na linha da água)
const JUNTAS := ["raiz", "tronco", "cabeca", "quadrilE", "quadrilD", "joelhoE", "joelhoD", "tornozeloE", "tornozeloD",
	"ombroE", "ombroD", "cotoveloE", "cotoveloD"]

var tipo := "antigo"
var armadura: Armadura
var mapa: Ilha
var estado := ""
var acenos := 0  # testes
var lugares := {}  # nome -> [pos dos pés (ou da bacia, sentado), para onde olha]
var nivel_agua := -INF  # o mergulhador: a altura da água onde ele mora
var roda: Array[Vector3] = []  # o mergulhador: a volta que ele dá nadando
var _cena: Node3D
var _j := {}
var _raiz_y := 0.42
var _pos := Vector3.ZERO
var _yaw := 0.0
var _vel := 0.0
var _fase := 0.0
var _t := 0.0
var _relogio := 0.0
var _alvo := Vector3.ZERO
var _depois := ""
var _aceno := 0.0
var _longe := true
var _susto := 0.0
var _chamas: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
var _salto_de := Vector3.ZERO
var _salto_ate := Vector3.ZERO
var _roda_i := 0
var _ultimo := ""
var _banco_p := Vector3.INF  # o assento do banco (de `Armadura.assentos`) que o antigo usa


func _ready() -> void:
	_rng.seed = 4242 if tipo == "antigo" else 7171
	add_to_group("amigos")
	set_meta("meio_altura", 0.6)
	_cena = (load(MODELOS[tipo]) as PackedScene).instantiate() as Node3D
	add_child(_cena)
	for n: String in JUNTAS:
		_j[n] = _cena.find_child(n, true, false)
	if _j["raiz"]:
		_raiz_y = (_j["raiz"] as Node3D).position.y
	_pintar()
	_achar_lugares()
	if tipo == "antigo":
		_pos = (lugares["campo"] as Array)[0]
		_yaw = _yaw_de((lugares["campo"] as Array)[1])
		_parar("campo")
	else:
		_pos = (lugares["beira"] as Array)[0]
		_yaw = _yaw_de((lugares["beira"] as Array)[1])
		_parar("beira")
	_aplicar()


## As placas no estilo do vale (como o robô do jogador), a chama dos jatos acesa só no pulo e o núcleo morno.
func _pintar() -> void:
	var chama := StandardMaterial3D.new()
	chama.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chama.albedo_color = Color(1.0, 0.62, 0.3, 0.8)
	chama.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	chama.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	chama.cull_mode = BaseMaterial3D.CULL_DISABLED
	var calor := StandardMaterial3D.new()
	calor.albedo_color = Color(0.05, 0.03, 0.02)
	calor.emission_enabled = true
	calor.emission = Color(1.0, 0.42, 0.1)
	calor.emission_energy_multiplier = 0.5
	var cores := {}
	for mi: MeshInstance3D in _cena.find_children("*", "MeshInstance3D", true, false):
		var nome := String(mi.name).to_lower()
		if nome.begins_with("lamina"):
			mi.visible = false
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m == null:
				continue
			if m.resource_name == "chama" or nome.begins_with("chama"):
				mi.set_surface_override_material(s, chama)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if not _chamas.has(mi):
					_chamas.append(mi)
				mi.visible = false
			elif m.resource_name == "calor":
				mi.set_surface_override_material(s, calor)
			elif ArmaduraVisual.toon and m is StandardMaterial3D and ArmaduraVisual._da_familia(m.resource_name):
				var c := (m as StandardMaterial3D).albedo_color
				if not cores.has(c.to_html()):
					var mt := ShaderMaterial.new()
					mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
					mt.set_shader_parameter("cor", c)
					mt.set_shader_parameter("brilho_borda", 0.18)
					cores[c.to_html()] = mt
				mi.set_surface_override_material(s, cores[c.to_html()])


# ------------------------------------------------------------------ os lugares

## O chão num ponto, com a laje da base por cima do terreno (como os robozinhos).
func _chao(x: float, z: float) -> float:
	var y := mapa.altura(x, z)
	var l: Vector3 = BaseVale.t_base.affine_inverse() * Vector3(x, y, z)
	if l.z > -5.2 and l.z < 7.2 and absf(l.x + 1.0) < 10.4:
		y = maxf(y, BaseVale.t_base.origin.y + 0.1)
		if Vector2(l.x, l.z).length() < 2.9:
			y = maxf(y, BaseVale.t_base.origin.y + 0.19)  # o estrado redondo de nascer
	return y


func _no_chao(p: Vector3) -> Vector3:
	return Vector3(p.x, _chao(p.x, p.z), p.z)


static func _yaw_de(frente: Vector3) -> float:
	return atan2(frente.x, frente.z)


func _achar_lugares() -> void:
	var tb := BaseVale.t_base
	var fora := (tb.basis * Vector3(0, 0, -1)).normalized()  # da base para o campo
	if tipo == "antigo":
		# na ponta do chão batido, olhando o campo
		lugares["campo"] = [_no_chao(tb * Vector3(-3.0, 0, -9.6)), fora]
		# à frente do canteiro de plantar (o de trás da horta, BaseLar._horta), cuidando das sementes achadas
		if BaseLar.horta.is_finite():
			lugares["horta"] = [_no_chao(tb * Vector3(-8.4, 0, -6.2)), fora]
		if BaseLar.fogueira.is_finite():
			# o banco da fogueira mais virado para o campo (ele gosta de olhar longe)
			var melhor := -INF
			for a: Array in Armadura.assentos:
				var p: Vector3 = a[0]
				if p.distance_to(BaseLar.fogueira) < 3.5 and (a[1] as Vector3).dot(fora) > melhor:
					melhor = (a[1] as Vector3).dot(fora)
					lugares["banco"] = [p - Vector3(0, _raiz_y - 0.045, 0), a[1], a[2]]
					_banco_p = p
		# o telhado: a bacia na beira da frente do telheiro; o pulo sai do chão à frente dela
		var beira: Vector3 = tb * Vector3(TELHADO.x, BaseLar.teto_y(TELHADO.z) + 0.075, TELHADO.z)
		lugares["telhado"] = [beira - Vector3(0, _raiz_y - 0.045, 0), fora]
		lugares["telhado_chao"] = [_no_chao(tb * Vector3(TELHADO.x, 0, -1.4)), fora]
	else:
		_achar_agua()


## A água mais perto da base (o mergulhador mora ali): o ponto no raso onde ele senta, com a água na cintura
## e de frente para a base (vê quem chega; na margem o capim o escondia), e uma volta de nado onde a água é
## funda o bastante.
func _achar_agua() -> void:
	var b := BaseVale.t_base.origin
	var w_pt := Vector3.INF
	# no vale é a lagoa da clareira (do lado da base ela tem uma prainha sem capim, Clareira.CLAROS); em outro
	# mapa, a água funda mais perto
	var lagoa := Vector3(Clareira.LAGOA.x, 0, Clareira.LAGOA.y)
	var na_lagoa := mapa.agua(lagoa.x, lagoa.z) - mapa.altura(lagoa.x, lagoa.z) > 1.2 and Vector2(lagoa.x - b.x, lagoa.z - b.z).length() < 150.0
	if na_lagoa:
		w_pt = Vector3(lagoa.x, mapa.agua(lagoa.x, lagoa.z), lagoa.z)
	for r in range(8, 400 if not na_lagoa else 0, 2):
		var fundo := 1.2
		for k in 90:
			var a := k * TAU / 90.0
			var x := b.x + cos(a) * r
			var z := b.z + sin(a) * r
			var w := mapa.agua(x, z)
			var f := w - mapa.altura(x, z)
			if f > fundo:
				fundo = f
				w_pt = Vector3(x, w, z)
		if w_pt.is_finite():
			break
	if not w_pt.is_finite():
		lugares["beira"] = [_no_chao(b + Vector3(3, 0, -6)), Vector3(0, 0, -1)]
		return
	nivel_agua = w_pt.y
	var para_base := Vector3(b.x - w_pt.x, 0, b.z - w_pt.z).normalized()
	var p := w_pt
	for i in 60:
		p += para_base * 0.25
		if mapa.agua(p.x, p.z) < mapa.altura(p.x, p.z) + 0.02:
			break
	# da margem para dentro, até a água dar uns 35 cm
	var raso := p
	for i in 40:
		raso -= para_base * 0.1
		if mapa.agua(raso.x, raso.z) - mapa.altura(raso.x, raso.z) >= 0.35:
			break
	lugares["beira"] = [Vector3(raso.x, mapa.altura(raso.x, raso.z), raso.z), para_base]
	lugares["entrada"] = [Vector3(w_pt.x, nivel_agua - AFUNDA, w_pt.z), -para_base]
	# a volta de nado: em roda, onde der fundo em todos os pontos (na lagoa, do lado dele)
	var centro := w_pt + para_base * 3.0 if na_lagoa else w_pt - para_base * 2.6
	for raio: float in [2.4, 1.8, 1.2]:
		var pts: Array[Vector3] = []
		for k in 10:
			var a := k * TAU / 10.0
			var q := centro + Vector3(cos(a), 0, sin(a)) * raio
			if mapa.agua(q.x, q.z) - mapa.altura(q.x, q.z) < 0.9:
				pts.clear()
				break
			pts.append(Vector3(q.x, nivel_agua - AFUNDA, q.z))
		if not pts.is_empty():
			roda = pts
			lugares["entrada"] = [pts[0], -para_base]
			break


# ------------------------------------------------------------------ a rotina

static func noite() -> bool:
	return Tablet.hora >= 19.3 or Tablet.hora < 5.6


## Fica fazendo `o_que` ali por um tempo.
func _parar(o_que: String) -> void:
	estado = o_que
	_vel = 0.0
	_ultimo = o_que
	match o_que:
		"telhado":
			_t = 9999.0
		"nadando":
			_t = _rng.randf_range(22.0, 34.0)
		_:
			_t = _rng.randf_range(24.0, 48.0)


func _andar_para(p: Vector3, depois: String) -> void:
	_alvo = p
	_depois = depois
	estado = "andando"


## O robô do jogador está sentado no assento do banco que o antigo usa?
func _banco_do_jogador() -> bool:
	return armadura != null and _banco_p.is_finite() and armadura.assento_atual().distance_to(_banco_p) < 0.35


## Algum robô achado está sentado no assento `p` de `Armadura.assentos`? (o jogador não senta em cima dele)
static func assento_tomado(arvore: SceneTree, p: Vector3) -> bool:
	for n in arvore.get_nodes_in_group("amigos"):
		var a := n as AmigoRobo
		if a != null and a.estado == "banco" and a._banco_p.is_finite() and a._banco_p.distance_to(p) < 0.35:
			return true
	return false


## O que o antigo faz agora: de noite o telhado; de dia uma das três coisas, sem repetir a última.
func _proximo_antigo() -> void:
	if noite():
		_andar_para((lugares["telhado_chao"] as Array)[0], "pulo_sobe")
		return
	var opcoes: Array = []
	for o: String in ["horta", "campo", "banco"]:
		if lugares.has(o) and o != _ultimo and not (o == "banco" and _banco_do_jogador()):
			opcoes.append(o)
	var o_que: String = opcoes[_rng.randi() % opcoes.size()]
	if o_que == "banco":
		_andar_para((lugares["banco"] as Array)[2], "banco")
	else:
		_andar_para((lugares[o_que] as Array)[0], o_que)


func _process(delta: float) -> void:
	if armadura == null or get_tree().paused:
		return
	_relogio += delta
	var d := armadura.global_position.distance_to(global_position)
	if d > LONGE:
		_longe = true
	elif _longe and d < PERTO and not armadura.em_pane:
		_longe = false
		_aceno = ACENO
		acenos += 1
	_aceno = maxf(0.0, _aceno - delta)
	_susto = maxf(0.0, _susto - delta)
	_t -= delta
	if tipo == "antigo":
		_rotina_antigo(delta)
	else:
		_rotina_mergulhador(delta)
	_aplicar()


func _rotina_antigo(delta: float) -> void:
	match estado:
		"andando":
			if _aceno <= 0.0 and _passo(delta, ANDA):
				match _depois:
					"banco":
						if _banco_do_jogador():
							# o robô do jogador sentou ali enquanto ele vinha: vai para outro canto
							_ultimo = "banco"
							_proximo_antigo()
							return
						var b: Array = lugares["banco"]
						_pos = b[0]
						_yaw = _yaw_de(b[1])
						_parar("banco")
					"pulo_sobe":
						_salto_de = _pos
						_salto_ate = (lugares["telhado"] as Array)[0]
						_yaw = _yaw_de((lugares["telhado"] as Array)[1])
						estado = "pulo_sobe"
						_t = SALTO
					_:
						_yaw = _yaw_de((lugares[_depois] as Array)[1])
						_parar(_depois)
		"pulo_sobe", "pulo_desce":
			var f := clampf(1.0 - _t / SALTO, 0.0, 1.0)
			var g := smoothstep(0.0, 1.0, f)
			_pos = _salto_de.lerp(_salto_ate, g) + Vector3(0, sin(f * PI) * 1.1, 0)
			if _t <= 0.0:
				_pos = _salto_ate
				if estado == "pulo_sobe":
					_parar("telhado")
				else:
					_parar("campo")
					_t = 2.0
		"telhado":
			if not noite():
				_salto_de = _pos
				_salto_ate = (lugares["telhado_chao"] as Array)[0]
				estado = "pulo_desce"
				_t = SALTO
		_:
			if _t <= 0.0 or (noite() and estado != "telhado"):
				if estado == "banco":
					_pos = (lugares["banco"] as Array)[2]
				_proximo_antigo()


func _rotina_mergulhador(delta: float) -> void:
	match estado:
		"beira":
			if _t <= 0.0:
				if roda.is_empty() or noite():
					_parar("beira")
				else:
					_pos = _no_chao(_pos)
					_andar_para((lugares["entrada"] as Array)[0], "nadar")
		"andando":
			if _aceno <= 0.0 and _passo(delta, ANDA * 0.8 if _na_agua() else ANDA):
				if _depois == "nadar":
					_roda_i = 0
					_parar("nadando")
				else:
					_pos = (lugares["beira"] as Array)[0]
					_yaw = _yaw_de((lugares["beira"] as Array)[1])
					_parar("beira")
		"nadando":
			if _t <= 0.0:
				_andar_para((lugares["beira"] as Array)[0], "beira")
			elif _aceno <= 0.0:
				_alvo = roda[_roda_i]
				if _passo(delta, NADA):
					_roda_i = (_roda_i + 1) % roda.size()


## Os pés dele estão na água funda (nadando)?
func _na_agua() -> bool:
	return nivel_agua > -INF and _pos.y < nivel_agua - AFUNDA + 0.1


## Um passo para o alvo. Devolve true ao chegar.
func _passo(delta: float, rapidez: float) -> bool:
	var para := Vector3(_alvo.x - _pos.x, 0, _alvo.z - _pos.z)
	var dist := para.length()
	if dist < 0.12:
		_vel = 0.0
		return true
	_vel = move_toward(_vel, rapidez, delta * 2.5)
	var dir := para / dist
	_yaw = lerp_angle(_yaw, _yaw_de(dir), 1.0 - exp(-6.0 * delta))
	_pos += dir * minf(dist, _vel * delta)
	var chao := _chao(_pos.x, _pos.z)
	if nivel_agua > -INF and tipo == "mergulhador":
		_pos.y = maxf(chao, nivel_agua - AFUNDA)  # entra andando até boiar
	else:
		_pos.y = chao
	return false


# ------------------------------------------------------------------ as poses

func _g(nome: String, x: float, y := 0.0, z := 0.0) -> void:
	var no := _j.get(nome) as Node3D
	if no:
		no.rotation = Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z))


func _aplicar() -> void:
	for n: String in JUNTAS:
		var no := _j[n] as Node3D
		if no:
			no.rotation = Vector3.ZERO
	var raiz := _j["raiz"] as Node3D
	if raiz:
		raiz.position.y = _raiz_y
	var t := _relogio
	var jato := false
	# para acenar ele levanta da horta e vira para quem chegou (sentado, só vira a cabeça)
	var pose := estado
	if _aceno > 0.0 and estado == "horta":
		pose = "de_pe"
	match pose:
		"andando":
			if _na_agua():
				_pose_nado(t)
			else:
				_pose_passo()
		"horta":
			# agachado cuidando dos canteiros
			_g("quadrilE", -55, 0, 4)
			_g("quadrilD", -55, 0, -4)
			_g("joelhoE", 85)
			_g("joelhoD", 85)
			if raiz:
				raiz.position.y = _raiz_y - 0.13
			_g("tronco", 28 + sin(t * 0.9) * 3.0)
			_g("cabeca", 18)
			_g("ombroE", -58 + sin(t * 3.1) * 14.0, 0, 8)
			_g("ombroD", -52 + sin(t * 2.6 + 1.3) * 14.0, 0, -8)
			_g("cotoveloE", -35)
			_g("cotoveloD", -35)
		"de_pe":
			_g("tronco", sin(t * 1.5) * 1.5)
		"campo":
			# de pé na ponta do chão batido, olhando o campo, com as mãos para trás
			_g("tronco", sin(t * 1.5) * 1.5)
			_g("cabeca", -6 + sin(t * 0.37) * 4.0, sin(t * 0.21) * 22.0)
			_g("ombroE", 16, 0, -6)
			_g("ombroD", 16, 0, 6)
			_g("cotoveloE", -28)
			_g("cotoveloD", -28)
		"banco":
			_pose_cadeira()
			_g("ombroE", -28, 0, -6)
			_g("ombroD", -28, 0, 6)
			_g("cotoveloE", -42)
			_g("cotoveloD", -42)
			_g("cabeca", 8 + sin(t * 0.3) * 4.0, sin(t * 0.17) * 18.0)
		"telhado":
			# na beira do telheiro, apoiado nas mãos para trás, olhando o céu; as pernas balançam devagar
			_pose_cadeira()
			_g("joelhoE", 84 + sin(t * 0.9) * 7.0)
			_g("joelhoD", 84 + sin(t * 0.9 + PI) * 7.0)
			_g("tronco", -12)
			_g("cabeca", -32 + sin(t * 0.23) * 5.0, sin(t * 0.13) * 20.0)
			_g("ombroE", 42, 0, 10)
			_g("ombroD", 42, 0, -10)
		"pulo_sobe", "pulo_desce":
			jato = true
			_g("quadrilE", -24)
			_g("quadrilD", -18)
			_g("joelhoE", 34)
			_g("joelhoD", 26)
			_g("ombroE", -10, 0, 32)
			_g("ombroD", -10, 0, -32)
		"beira":
			# sentado no raso, a água na cintura, batendo os pés de pato devagar
			if raiz:
				raiz.position.y = _raiz_y - 0.36
			_g("quadrilE", -66 + sin(t * 2.1) * 10.0)
			_g("quadrilD", -66 + sin(t * 2.1 + PI) * 10.0)
			_g("joelhoE", 24)
			_g("joelhoD", 24)
			_g("tronco", -8)
			_g("cabeca", -4 + sin(t * 0.4) * 4.0, sin(t * 0.19) * 24.0)
			_g("ombroE", 32, 0, 12)
			_g("ombroD", 32, 0, -12)
		"nadando":
			_pose_nado(t)
		_:
			pass
	for c in _chamas:
		c.visible = jato
	_acenar(t)
	if _susto > 0.0 and _j["cabeca"]:
		(_j["cabeca"] as Node3D).rotation.y = sin(_susto * 22.0) * 0.4  # "não, não"
	global_position = _pos
	rotation.y = _yaw


func _pose_passo() -> void:
	_fase += get_process_delta_time() * (4.0 + _vel * 4.5)
	var amp := clampf(_vel / 1.4, 0.0, 1.0) * 0.5
	var s := sin(_fase)
	for par: Array in [["E", 1.0], ["D", -1.0]]:
		var lado: String = par[0]
		var sinal: float = par[1]
		var q := _j["quadril" + lado] as Node3D
		if q:
			q.rotation.x = -s * amp * sinal
		var jo := _j["joelho" + lado] as Node3D
		if jo:
			jo.rotation.x = maxf(0.0, s * sinal) * amp * 0.9
		var o := _j["ombro" + lado] as Node3D
		if o:
			o.rotation.x = s * amp * sinal * 0.8
	var raiz := _j["raiz"] as Node3D
	if raiz:
		raiz.position.y = _raiz_y + absf(s) * amp * 0.03


## Sentado de cadeira: coxas na horizontal e canelas pendendo (a bacia apoia onde ele foi posto).
func _pose_cadeira() -> void:
	_g("quadrilE", -88, 0, 3)
	_g("quadrilD", -88, 0, -3)
	_g("joelhoE", 86)
	_g("joelhoD", 86)


## Nadando em pé, com os ombros na linha da água: as pernas batem e os braços abrem e fecham.
func _pose_nado(t: float) -> void:
	_g("tronco", 14)
	_g("cabeca", -10)
	_g("quadrilE", -20 + sin(t * 4.2) * 24.0)
	_g("quadrilD", -20 + sin(t * 4.2 + PI) * 24.0)
	_g("joelhoE", 22 + maxf(0.0, sin(t * 4.2)) * 20.0)
	_g("joelhoD", 22 + maxf(0.0, sin(t * 4.2 + PI)) * 20.0)
	var bra := sin(t * 2.4) * 26.0
	_g("ombroE", -38 + bra * 0.4, 0, 46 + bra)
	_g("ombroD", -38 + bra * 0.4, 0, -46 - bra)
	_g("cotoveloE", -24)
	_g("cotoveloD", -24)


## O aceno: vira para o robô (sentado, só a cabeça) e balança o braço direito no alto.
func _acenar(t: float) -> void:
	if _aceno <= 0.0 or armadura == null:
		return
	var f := minf(1.0, minf(ACENO - _aceno, _aceno) * 4.0)  # entra e sai suave
	var para := armadura.global_position - _pos
	var quer := atan2(para.x, para.z)
	var sentado := estado in ["banco", "telhado", "beira"]
	if sentado:
		var cab := _j["cabeca"] as Node3D
		if cab:
			cab.rotation.y = lerpf(cab.rotation.y, clampf(wrapf(quer - _yaw, -PI, PI), -1.0, 1.0), f)
	elif not estado.begins_with("pulo"):
		_yaw = lerp_angle(_yaw, quer, 1.0 - exp(-8.0 * get_process_delta_time()))
	var o := _j["ombroD"] as Node3D
	if o:
		# z negativo abre o braço direito para fora (o esquerdo abre com z positivo)
		o.rotation = o.rotation.lerp(Vector3(deg_to_rad(-20.0), 0, deg_to_rad(-135.0 - sin(t * 9.0) * 22.0)), f)
	var c := _j["cotoveloD"] as Node3D
	if c:
		c.rotation = c.rotation.lerp(Vector3(deg_to_rad(-25.0), 0, 0), f)


## Com ele na mira o tiro não sai (Tiro); ele balança a cabeça.
func levou_mira() -> void:
	if _susto <= 0.0:
		_susto = 1.0
		Som.toque3d(self, Som.variacao("drone", 6), global_position + Vector3(0, 0.9, 0), -9.0, 5.0, 30.0)


## O que o scanner mostra dele.
func ficha() -> Dictionary:
	if tipo == "antigo":
		return {"nome": "Robô antigo", "tipo": "robô · amigo",
			"linhas": ["O robô de antes. Mora na base.", "De noite sobe no telhado para olhar o céu.", "O jeito dele está na aba Corpo."]}
	return {"nome": "Mergulhador", "tipo": "robô · amigo",
		"linhas": ["Segurou a comporta da Represa.", "Agora mora na água perto da base.", "O jeito dele está na aba Corpo."]}
