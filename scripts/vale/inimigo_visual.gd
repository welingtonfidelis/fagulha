class_name InimigoVisual
extends MechVisual
## O corpo dos robôs inimigos (2026-11-20, segunda versão, ideia do usuário): o nosso robô jogável com outra
## pintura, outros olhos e peças próprias (`tools/vale/robo_v2.py`, VARIANTE=<nome>), animado pelo mesmo
## código do jogador (ArmaduraVisual): anda, corre, pula, pousa, esquiva, mira com o braço estendido, bate de
## espada em arco e, desligado, cai de joelhos como o robô em pane. Não voa nem nada. Os primeiros robôs do
## projeto (Lata, Guarda e Barril) se mexiam pouco e saíram.
##
## Cinco comuns e três chefes, cada um com o seu jeito de lutar (`FICHAS`):
##  - Sentinela: fuzil, um tiro certeiro;  Espadachim: lâmina de luz, rápido, pula para cima do robô;
##  - Couraça: canhão, lento e aguenta mais;  Batedor: metralha, o mais rápido, esquiva muito;
##  - Artilheiro: mísseis dos casulos das costas;
##  - chefes: o Capataz (lâmina, pula e esquiva), o Canhoneiro (dois tiros de canhão) e o Guardião (atira de
##    longe e, de perto, bate de lâmina).
## A Mecha lê a ficha e acerta a IA (Vigia); este visual traduz o estado dela para o PoseInimigo.
## `forcar` ("corpo", "bala", "pesado" ou "missil") escolhe pela arma; `forcar_modelo` escolhe o robô.

const PASTA := "res://assets/vale/robos_inimigos/%s.glb"
const COMUNS := ["sentinela", "espadachim", "couraca", "batedor", "artilheiro"]
const CHEFES := ["capataz", "canhoneiro", "guardiao"]
const NOMES := {"sentinela": "Sentinela", "espadachim": "Espadachim", "couraca": "Couraça", "batedor": "Batedor",
	"artilheiro": "Artilheiro", "capataz": "Capataz", "canhoneiro": "Canhoneiro", "guardiao": "Guardião"}
## arma ("tiro", "corpo" ou "costas"), mão, costas, armaduras (0 a 2: aguenta mais tiros), porte (pesado anda
## mais devagar), altura em metros, ágil (0 a 1: quanto pula e esquiva), misto (atira de longe e bate de perto),
## a chance no sorteio dos comuns e a cor da lâmina e do aviso.
const FICHAS := {
	"sentinela": {"arma": "tiro", "mao": "fuzil", "costas": "", "armaduras": 1, "porte": 0.3, "altura": 1.55, "agil": 0.35, "chance": 0.26},
	"espadachim": {"arma": "corpo", "mao": "lamina", "costas": "", "armaduras": 0, "porte": 0.1, "altura": 1.5, "agil": 1.0, "chance": 0.24},
	"couraca": {"arma": "tiro", "mao": "canhao", "costas": "", "armaduras": 2, "porte": 0.6, "altura": 1.65, "agil": 0.1, "chance": 0.16},
	"batedor": {"arma": "tiro", "mao": "metralha", "costas": "", "armaduras": 0, "porte": 0.0, "altura": 1.4, "agil": 1.0, "chance": 0.18},
	"artilheiro": {"arma": "costas", "mao": "", "costas": "misseis", "armaduras": 1, "porte": 0.45, "altura": 1.6, "agil": 0.2, "chance": 0.16},
	"capataz": {"arma": "corpo", "mao": "lamina", "costas": "", "armaduras": 2, "porte": 0.3, "altura": 2.8, "agil": 0.8},
	"canhoneiro": {"arma": "tiro", "mao": "canhao", "costas": "", "armaduras": 2, "porte": 0.6, "altura": 3.0, "agil": 0.1},
	"guardiao": {"arma": "corpo", "mao": "lamina", "costas": "", "armaduras": 2, "porte": 0.4, "altura": 2.9, "agil": 0.5, "misto": true},
}
const POR_ARMA := {"corpo": ["espadachim", "capataz"], "bala": ["sentinela", "guardiao"], "pesado": ["couraca", "canhoneiro"], "missil": ["artilheiro", "canhoneiro"]}
const T_GOLPE := 0.42  # do começo do ataque até a lâmina passar na frente
const T_TIRO := 0.3
const T_MISSIL := 0.4
const VARRE := 0.3  # quanto dura a varrida da lâmina (o meio dela é o T_GOLPE)
const COR_LAMINA := Color(1.0, 0.35, 0.12)

static var forcar := ""
static var forcar_modelo := ""

var ficha := {}
var modelo: Node3D  # o modelo dentro do corpo (para quem mede peças, como a Fundição)
var corpo: ArmaduraVisual
var pose := PoseInimigo.new()
var tipo := "sentinela"
var escala := 1.0  # do corpo: altura do inimigo / altura do nosso robô
var ataque := "tiro"  # o ataque da vez: "tiro", "corpo" ou "costas" (o Guardião troca conforme a distância)
var cor_lente := Color(1.0, 0.4, 0.2)
var tempo_ataque := 0.0  # segundos desde o começo do ataque (testes e vitrine)
var lamina_acesa := false
## Pulo e esquiva (a Mecha acerta): no ar, pousando e esquivando
var no_ar := false
var pousando := 0.0
var esquivando := 0.0
var _mats: Array[ShaderMaterial] = []
var _mat_olhos: Array[StandardMaterial3D] = []
var _vel := 1.0
var _apagado := 0.0
var _desbotado := 0.0
var _pos_ant := Vector3.INF
var _vel_mundo := Vector3.ZERO
var _lado_golpe := 1.0
var vel_vitrine := Vector3.INF  # vitrine: anda sem sair do lugar (velocidade no mundo)


static func montar(semente: int, _alt: float, ruido: Texture2D, chefe := false) -> InimigoVisual:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente * 9973 + 101
	var v := InimigoVisual.new()
	var tipo_s := ""
	if forcar_modelo != "" and FICHAS.has(forcar_modelo):
		tipo_s = forcar_modelo
	elif forcar != "" and POR_ARMA.has(forcar):
		tipo_s = POR_ARMA[forcar][1 if chefe else 0]
	elif chefe:
		tipo_s = CHEFES[rng.randi_range(0, CHEFES.size() - 1)]
	else:
		var sorte := rng.randf()
		tipo_s = COMUNS[COMUNS.size() - 1]
		for nome: String in COMUNS:
			sorte -= float(FICHAS[nome]["chance"])
			if sorte <= 0.0:
				tipo_s = nome
				break
	if forcar == "bala" and tipo_s == "sentinela" and rng.randf() < 0.4:
		tipo_s = "batedor"
	v.tipo = tipo_s
	var f: Dictionary = FICHAS[tipo_s]
	v.altura = float(f["altura"])
	v.ficha = {"arma": f["arma"], "mao": f["mao"], "costas": f["costas"], "armaduras": f["armaduras"], "porte": f["porte"],
		"agil": f["agil"], "misto": f.get("misto", false), "modelo": tipo_s, "nome": NOMES[tipo_s], "paleta": 0}
	v.ataque = String(f["arma"])
	v.corpo = ArmaduraVisual.new()
	v.corpo.name = "Corpo"
	v.corpo.caminho_modelo = PASTA % tipo_s
	v.corpo.cor_lamina = COR_LAMINA
	v.corpo.preparar()
	v.corpo.yaw_forcado = 0.0  # quem vira para o robô é o Vigia; o corpo fica de frente para onde ele olha
	v.add_child(v.corpo)
	v.modelo = v.corpo.modelo
	# do tamanho da ficha: o nosso robô tem 1,25 m; o comum fica um pouco maior que ele e o chefe, o dobro
	var caixa := BaseVale._caixa(v.corpo.modelo)
	v.escala = v.altura / maxf(0.01, caixa.size.y)
	v.corpo.scale = Vector3.ONE * v.escala
	v.corpo.escala_lamina = v.escala
	v.pose.altura = caixa.size.y
	v._vestir(ruido)
	# o aviso de ataque: os olhos acendem e uma luz na cabeça
	v.cabeca = null
	v.luz = OmniLight3D.new()
	v.luz.light_color = v.cor_lente
	v.luz.omni_range = v.altura * 0.8
	v.luz.omni_attenuation = 2.0
	v.luz.light_energy = 0.0
	v.luz.shadow_enabled = false
	if v.corpo.j.get("cabeca") is Node3D:
		(v.corpo.j["cabeca"] as Node3D).add_child(v.luz)
		v.luz.position = Vector3(0, 0.15, -0.25)
	else:
		v.add_child(v.luz)
	v.boca = v.corpo.boca_da_arma(false)
	if v.ataque == "costas":
		v.boca = v.corpo.j.get("podD") if v.corpo.j.get("podD") is Node3D else v.corpo.j.get("tronco")
	v.tocar("Idle")
	return v


## As chapas ganham o material das máquinas do vale (pisca ao levar tiro, escurece desligada, desbota velha),
## na cor que o modelo trouxe. Os olhos ficam acesos na cor deles e acendem mais no aviso.
func _vestir(ruido: Texture2D) -> void:
	var feitos := {}
	for mi: MeshInstance3D in corpo.modelo.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m0 := mi.mesh.surface_get_material(s)
			var nome := String(m0.resource_name) if m0 else ""
			if nome in ["calor", "chama", "lamina"]:
				continue
			var cor := (m0 as StandardMaterial3D).albedo_color if m0 is StandardMaterial3D else Color(0.3, 0.3, 0.3)
			if nome == "olhos":
				# a cor dos olhos vem na emissão (a cor base é quase preta)
				if m0 is StandardMaterial3D and (m0 as StandardMaterial3D).emission_enabled:
					cor = (m0 as StandardMaterial3D).emission
				var mo := StandardMaterial3D.new()
				mo.albedo_color = cor
				mo.emission_enabled = true
				mo.emission = cor
				mo.emission_energy_multiplier = 1.6
				mo.set_meta("cor", cor)
				_mat_olhos.append(mo)
				mi.set_surface_override_material(s, mo)
				cor_lente = cor
				continue
			var chave := cor.to_html()
			if not feitos.has(chave):
				var m := ShaderMaterial.new()
				m.shader = load("res://scripts/shaders/vale_tex_opaco.gdshader")
				m.set_shader_parameter("tex", _branco())
				m.set_shader_parameter("tinta", cor)
				m.set_shader_parameter("corte", 0.0)
				m.set_shader_parameter("vento", 0.0)
				m.set_shader_parameter("borda", 0.2)
				m.set_shader_parameter("ruido", ruido)
				_mats.append(m)
				feitos[chave] = m
			mi.set_surface_override_material(s, feitos[chave])
	if not _mats.is_empty():
		mat = _mats[0]


static var _tex_branca: ImageTexture


static func _branco() -> ImageTexture:
	if _tex_branca == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_tex_branca = ImageTexture.create_from_image(img)
	return _tex_branca


func tempo_do_tiro() -> float:
	return {"corpo": T_GOLPE, "costas": T_MISSIL}.get(ataque, T_TIRO)


func tocar(nome: String, vel := 1.0, _mistura := 0.2) -> void:
	if atual != nome:
		if nome == "Shoot":
			tempo_ataque = 0.0
			_lado_golpe = -_lado_golpe
		atual = nome
	_vel = vel


func ponto_tiro() -> Vector3:
	if boca and is_instance_valid(boca):
		return boca.global_position + (Vector3(0, 0.25 * altura, 0) if ataque == "costas" else Vector3.ZERO)
	return ponto_cabeca()


func ponto_cabeca() -> Vector3:
	var c = corpo.j.get("cabeca") if corpo else null
	return (c as Node3D).global_position + Vector3(0, altura * 0.06, 0) if c is Node3D else global_position + Vector3(0, altura * 0.85, 0)


func olho(energia: float) -> void:
	if luz:
		luz.light_energy = energia
	for m in _mat_olhos:
		m.emission_energy_multiplier = lerpf(1.6, 0.03, _apagado) + energia * 4.0


func clarao(v: float) -> void:
	for m in _mats:
		m.set_shader_parameter("clarao", v)


func apagar(v: float) -> void:
	_apagado = v
	for m in _mats:
		m.set_shader_parameter("apagado", v)
	for m in _mat_olhos:
		m.emission_energy_multiplier = lerpf(1.6, 0.03, v)


var _brilho: MeshInstance3D
var _mat_brilho: StandardMaterial3D
const COR_CARGA := Color(1.0, 0.5, 0.16)


## O aviso de ataque na arma: uma bola de luz laranja na boca do cano (ou na mão da lâmina) que cresce e
## tremula enquanto ele arma o golpe ou o tiro. `f` de 0 (apagada) a 1 (vai sair).
func carga(f: float) -> void:
	if f <= 0.0:
		if _brilho:
			_brilho.visible = false
		return
	if _brilho == null:
		_brilho = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 12
		sm.rings = 6
		_brilho.mesh = sm
		_mat_brilho = StandardMaterial3D.new()
		_mat_brilho.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_brilho.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_brilho.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_brilho.material_override = _mat_brilho
		_brilho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_brilho)
	_brilho.visible = true
	_brilho.global_position = ponto_tiro()
	var treme := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.05)
	_brilho.scale = Vector3.ONE * lerpf(0.22, 0.6, f) * treme * altura / 1.55
	_mat_brilho.albedo_color = Color(COR_CARGA, 0.35 + 0.55 * f)


## Tira a cor e puxa para a ferrugem (os robôs velhos caídos na Fundição).
func desbotar(v: float) -> void:
	_desbotado = v
	for m in _mats:
		m.set_shader_parameter("desbotado", v)


## Graus de inclinação de `de` até o alvo (positivo: o alvo está acima).
func _inclinacao(de: Vector3) -> float:
	if not alvo_mira.is_finite():
		return 0.0
	var d := alvo_mira - de
	return rad_to_deg(atan2(d.y, maxf(0.4, Vector2(d.x, d.z).length())))


func _process(delta: float) -> void:
	if corpo == null or corpo.modelo == null:
		return
	# a velocidade de verdade (anda, recua, esquiva, pula), no espaço do modelo
	var p := global_position
	if _pos_ant.is_finite() and delta > 0.0 and delta < 1.0:
		var v := (p - _pos_ant) / delta
		_vel_mundo = _vel_mundo.lerp(v, 1.0 - exp(-12.0 * delta))
	_pos_ant = p
	if vel_vitrine.is_finite():
		_vel_mundo = vel_vitrine
	var frente := -global_basis.z
	frente.y = 0.0
	frente = frente.normalized() if frente.length() > 0.01 else Vector3.FORWARD
	var hv := Vector2(_vel_mundo.x, _vel_mundo.z).length()
	if atual == "Death":
		hv = 0.0
	var de_costas := Vector3(_vel_mundo.x, 0, _vel_mundo.z).dot(frente) < -0.3
	pose.velocity = Vector3(0, 0, -hv / escala)
	corpo.re_forcado = de_costas
	pose.em_pane = atual == "Death"
	pose.estado = Armadura.Estado.AR if no_ar else (Armadura.Estado.POUSO if pousando > 0.0 else Armadura.Estado.CHAO)
	pose.pouso_forca = 0.3
	pose.esquivando = esquivando
	pose.atirando = 0.0
	pose.espada_t = 0.0
	pose.calor = 0.0
	corpo.sobrepor.clear()
	corpo.espada_desce = 0.0
	var lamina := false
	if atual == "Shoot" and not pose.em_pane:
		tempo_ataque += delta
		match ataque:
			"corpo":
				# o golpe do jogador: arma a lâmina de lado e varre de um lado ao outro; o meio da varrida é o
				# instante do acerto. Quem é alto desce o braço até a lâmina passar na altura do robô
				var ombro = corpo.j.get("ombroD")
				if ombro is Node3D:
					corpo.espada_desce = clampf(-_inclinacao((ombro as Node3D).global_position), 0.0, 60.0)
				var comeco := T_GOLPE - VARRE * 0.5
				var tempo_e := float(Arsenal.ESPADA["tempo"])
				if tempo_ataque > 0.06 and tempo_ataque < comeco + VARRE + 0.12:
					var f := clampf((tempo_ataque - comeco) / VARRE, 0.0, 1.0)
					pose.espada_t = maxf(0.001, tempo_e * (1.0 - f))
					pose.espada_lado = _lado_golpe
					lamina = true
			"costas":
				# os mísseis saem dos casulos das costas: o corpo se apruma, abre os braços e firma as pernas
				corpo.sobrepor["tronco"] = Vector3(-8.0, 0, 0)
				corpo.sobrepor["ombroE"] = Vector3(8.0, 0, 22.0)
				corpo.sobrepor["ombroD"] = Vector3(8.0, 0, -22.0)
				corpo.sobrepor["cotoveloE"] = Vector3(-30.0, 0, 0)
				corpo.sobrepor["cotoveloD"] = Vector3(-30.0, 0, 0)
			_:
				# o braço estende para o robô e o tiro sai da boca do cano, como o jogador mirando
				pose.atirando = 0.6
				var ombro2 = corpo.j.get("ombroD")
				pose.camera.pitch = deg_to_rad(_inclinacao((ombro2 as Node3D).global_position if ombro2 is Node3D else ponto_cabeca()))
				if tipo == "canhoneiro":
					pose.atirando_e = 0.6  # dois canhões: os dois braços
	if atual != "Shoot":
		pose.atirando_e = 0.0
	lamina_acesa = lamina
	pose.camera.yaw = 0.0
	corpo.atualizar(minf(delta, 1.0) if delta < 5.0 else 1.0, pose)
	if delta >= 5.0:
		# pose de uma vez (a Fundição põe os velhos já caídos): várias passadas para as juntas chegarem
		for i in 30:
			corpo.atualizar(0.2, pose)
	pousando = maxf(0.0, pousando - delta)
