class_name InimigoVisual
extends MechVisual
## O corpo dos robôs inimigos do próprio projeto (2026-11-20), no lugar dos mechas de pacote: três famílias
## de máquina comum (a Lata, o Guarda e o Barril) e três chefes (o Colosso, a Lâmina e o Artilheiro), feitos
## por `tools/vale/inimigos.py`. Como o robô do jogador, não têm esqueleto nem animação gravada: o modelo
## traz as juntas como nós e este código gira cada uma (parado, andando, correndo, atacando, desligado).
##
## As armas são as do jogador:
##  - **tiro**: o cano fica na luva direita; para atirar o braço estende na direção do robô e o tiro sai da
##    boca do cano (`ponto_tiro`), como o jogador mirando;
##  - **corpo**: a lâmina de luz sai do pulso só durante o golpe e varre em arco de um lado ao outro, como a
##    espada do jogador. Quem é alto inclina o arco para baixo, até a altura do robô (`alvo_mira`);
##  - **costas**: casulos de mísseis nos ombros.
## `forcar` ("corpo", "bala", "pesado" ou "missil") tira o sorteio da arma; `forcar_modelo` o do corpo.

const PASTA := "res://assets/vale/inimigos/%s.glb"
const FAMILIAS := ["lata", "guarda", "barril"]
const CHEFES := ["colosso", "lamina", "artilheiro"]
const NOMES := {"lata": "Lata", "guarda": "Guarda", "barril": "Barril", "colosso": "Colosso", "lamina": "Lâmina", "artilheiro": "Artilheiro"}
## As cores da chapa de cada família: [placa, placa clara], uma por sorteio.
const PALETAS := {
	"lata": [[Color(0.20, 0.25, 0.10), Color(0.36, 0.40, 0.20)], [Color(0.08, 0.20, 0.24), Color(0.22, 0.38, 0.40)], [Color(0.21, 0.21, 0.23), Color(0.42, 0.42, 0.42)]],
	"guarda": [[Color(0.42, 0.12, 0.04), Color(0.60, 0.26, 0.08)], [Color(0.30, 0.06, 0.10), Color(0.50, 0.18, 0.20)], [Color(0.40, 0.26, 0.06), Color(0.60, 0.44, 0.16)]],
	"barril": [[Color(0.62, 0.42, 0.04), Color(0.62, 0.58, 0.44)], [Color(0.10, 0.40, 0.34), Color(0.55, 0.60, 0.50)], [Color(0.70, 0.30, 0.05), Color(0.62, 0.58, 0.44)]],
}
const BASE := {"lata": "lata", "guarda": "guarda", "barril": "barril", "colosso": "lata", "lamina": "guarda", "artilheiro": "barril"}
const LENTES := {"lata": Color(1.0, 0.55, 0.12), "guarda": Color(1.0, 0.14, 0.07), "barril": Color(0.4, 0.9, 1.0)}
const FIXAS := {"escuro": Color(0.035, 0.04, 0.045), "grafite": Color(0.10, 0.11, 0.12), "aco": Color(0.32, 0.33, 0.34), "missil": Color(0.6, 0.08, 0.04)}
const T_GOLPE := 0.42  # do começo do ataque até a lâmina passar na frente
const T_TIRO := 0.3
const T_MISSIL := 0.4

static var forcar := ""
static var forcar_modelo := ""
static var _cenas := {}
static var _branco: ImageTexture

var ficha := {}
var modelo: Node3D
var tipo := "lata"
var j := {}  # nome da junta -> Node3D
var cor_lente := Color(1.0, 0.2, 0.1)
var tempo_ataque := 0.0  # segundos desde o começo do ataque (testes)
var lamina_acesa := false
var _mats: Array[ShaderMaterial] = []
var _mat_lente: StandardMaterial3D
var _laminas: Array[MeshInstance3D] = []
var _alvos := {}
var _fase := 0.0
var _vel := 1.0
var _apagado := 0.0
var _arriado := 0.0
var _perna := 0.3  # comprimento da coxa, em metros do modelo (para o corpo descer quando dobra as pernas)
var _raiz_base := 0.0
var _esc := 1.0


static func montar(semente: int, alt: float, ruido: Texture2D, chefe := false) -> InimigoVisual:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente * 9973 + 101
	var v := InimigoVisual.new()
	v.altura = alt
	v.tipo = (CHEFES if chefe else FAMILIAS)[rng.randi_range(0, 2)]
	if forcar_modelo != "":
		v.tipo = forcar_modelo
	if not _cenas.has(v.tipo):
		_cenas[v.tipo] = load(PASTA % v.tipo)
	v.modelo = (_cenas[v.tipo] as PackedScene).instantiate() as Node3D
	var caixa := BaseVale._caixa(v.modelo)
	v._esc = alt / maxf(0.01, caixa.size.y)
	v.modelo.scale = Vector3.ONE * v._esc
	v.modelo.rotation.y = PI  # o modelo olha para +Z; a frente das máquinas é -Z
	v.add_child(v.modelo)
	for nome: String in ["raiz", "tronco", "cabeca", "ombroE", "ombroD", "cotoveloE", "cotoveloD", "bocaE", "bocaD", "bocaM",
			"quadrilE", "quadrilD", "joelhoE", "joelhoD", "quadrilE2", "quadrilD2", "joelhoE2", "joelhoD2"]:
		var no := v.modelo.find_child(nome, true, false)
		if no is Node3D:
			v.j[nome] = no
	v._raiz_base = (v.j["raiz"] as Node3D).position.y
	v._perna = ((v.j["joelhoE"] as Node3D).position).length()
	# a arma: os chefes têm a deles; os comuns sorteiam (ou vem pedida)
	var arma := "tiro"
	var mao := "fuzil"
	var costas := ""
	match v.tipo:
		"colosso":
			mao = "canhao"
		"lamina":
			arma = "corpo"
			mao = "lamina"
		"artilheiro":
			arma = "costas"
			costas = "misseis2"
		_:
			var sorte := rng.randf()
			if forcar == "corpo" or (forcar == "" and sorte < 0.34):
				arma = "corpo"
				mao = "lamina"
			elif forcar == "missil" or (forcar == "" and sorte < 0.56):
				arma = "costas"
				costas = "misseis"
			else:
				mao = ["fuzil", "metralha", "canhao"][rng.randi_range(0, 2)]
				if forcar == "bala":
					mao = "fuzil"
				elif forcar == "pesado":
					mao = "canhao"
	var mostra := {"tiro": "arma_canhao", "corpo": "arma_lamina", "costas": "arma_misseis"}
	for n in v.modelo.find_children("arma_*", "Node3D", true, false):
		var nome_n := String(n.name)
		# os chefes já saem do gerador só com as armas deles
		(n as Node3D).visible = v.tipo in CHEFES or nome_n.begins_with(mostra[arma])
	v.boca = v.j.get("bocaM") if arma == "costas" else v.j.get("bocaD")
	var paleta := rng.randi_range(0, 2)
	var cores: Array = PALETAS[BASE[v.tipo]][paleta]
	v.cor_lente = LENTES[BASE[v.tipo]]
	v.ficha = {"arma": arma, "mao": mao, "costas": costas, "armaduras": rng.randi_range(0, 2), "porte": {"lata": 0.6, "guarda": 0.25, "barril": 0.45}[BASE[v.tipo]],
		"paleta": paleta, "modelo": v.tipo, "nome": NOMES[v.tipo]}
	v._vestir(cores, ruido)
	# a cabeça (para a luz do aviso) e as lâminas
	v.cabeca = null
	v.luz = OmniLight3D.new()
	v.luz.light_color = v.cor_lente
	v.luz.omni_range = alt * 0.8
	v.luz.omni_attenuation = 2.0
	v.luz.light_energy = 0.0
	v.luz.shadow_enabled = false
	(v.j["cabeca"] as Node3D).add_child(v.luz)
	v.luz.position = Vector3(0, 0.1, 0.3)
	if arma == "corpo":
		v._por_lamina("bocaD")
		if v.tipo == "lamina":
			v._por_lamina("bocaE")
	v.tocar("Idle")
	return v


func _vestir(cores: Array, ruido: Texture2D) -> void:
	if _branco == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_branco = ImageTexture.create_from_image(img)
	var por_nome := {}
	var feito := func(cor: Color) -> ShaderMaterial:
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/shaders/vale_tex_opaco.gdshader")
		m.set_shader_parameter("tex", _branco)
		m.set_shader_parameter("tinta", cor)
		m.set_shader_parameter("corte", 0.0)
		m.set_shader_parameter("vento", 0.0)
		m.set_shader_parameter("borda", 0.22)
		m.set_shader_parameter("ruido", ruido)
		_mats.append(m)
		return m
	por_nome["placa"] = feito.call(cores[0])
	por_nome["placa_clara"] = feito.call(cores[1])
	for nome: String in FIXAS:
		por_nome[nome] = feito.call(FIXAS[nome])
	mat = por_nome["placa"]
	_mat_lente = StandardMaterial3D.new()
	_mat_lente.albedo_color = cor_lente
	_mat_lente.emission_enabled = true
	_mat_lente.emission = cor_lente
	_mat_lente.emission_energy_multiplier = 1.6
	var mat_boca := StandardMaterial3D.new()
	mat_boca.albedo_color = Color(0.5, 0.25, 0.08)
	mat_boca.emission_enabled = true
	mat_boca.emission = Color(1.0, 0.5, 0.15)
	mat_boca.emission_energy_multiplier = 0.9
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m0 := mi.mesh.surface_get_material(s)
			var nome := String(m0.resource_name) if m0 else ""
			if nome == "lente":
				mi.set_surface_override_material(s, _mat_lente)
			elif nome == "boca":
				mi.set_surface_override_material(s, mat_boca)
			else:
				mi.set_surface_override_material(s, por_nome.get(nome, por_nome["grafite"]))


## A lâmina de luz, no eixo do braço, a partir da boca do emissor. Só aparece durante o golpe.
func _por_lamina(junta: String) -> void:
	var no := j.get(junta) as Node3D
	if no == null:
		return
	var comp := 0.5 * altura
	var cm := CapsuleMesh.new()
	cm.radius = 0.018 * altura
	cm.height = comp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.6)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.4, 0.1)
	m.emission_energy_multiplier = 4.0
	var mi := MeshInstance3D.new()
	mi.name = "LaminaDeLuz"
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis.from_scale(Vector3.ONE / _esc), Vector3(0, -comp * 0.5 / _esc, 0))
	mi.visible = false
	no.add_child(mi)
	_laminas.append(mi)


func tempo_do_tiro() -> float:
	return {"corpo": T_GOLPE, "costas": T_MISSIL}.get(ficha.get("arma", "tiro"), T_TIRO)


func tocar(nome: String, vel := 1.0, _mistura := 0.2) -> void:
	if atual != nome:
		if nome == "Shoot":
			tempo_ataque = 0.0
		atual = nome
	_vel = vel


func ponto_cabeca() -> Vector3:
	return (j["cabeca"] as Node3D).global_position + Vector3(0, altura * 0.08, 0) if j.has("cabeca") else global_position + Vector3(0, altura * 0.85, 0)


func olho(energia: float) -> void:
	if luz:
		luz.light_energy = energia
	if _mat_lente:
		_mat_lente.emission_energy_multiplier = lerpf(1.6, 0.03, _apagado) + energia * 5.0


func clarao(v: float) -> void:
	for m in _mats:
		m.set_shader_parameter("clarao", v)


func apagar(v: float) -> void:
	_apagado = v
	for m in _mats:
		m.set_shader_parameter("apagado", v)
	if _mat_lente:
		_mat_lente.emission_energy_multiplier = lerpf(1.6, 0.03, v)


## Tira a cor e puxa para a ferrugem (os robôs velhos caídos na Fundição).
func desbotar(v: float) -> void:
	for m in _mats:
		m.set_shader_parameter("desbotado", v)


func _alvo(nome: String, x: float, y := 0.0, z := 0.0) -> void:
	_alvos[nome] = Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z))


func _pernas(nome: String, esq: float, dir: float) -> void:
	_alvo(nome + "E", esq)
	_alvo(nome + "D", dir)
	if j.has(nome + "E2"):  # o Artilheiro: as de trás andam trocadas com as da frente
		_alvo(nome + "E2", dir)
		_alvo(nome + "D2", esq)


## Quantos graus o braço desce abaixo da horizontal para apontar o alvo (negativo: aponta para cima).
func _descida(junta: String) -> float:
	if not alvo_mira.is_finite() or not j.has(junta):
		return 0.0
	var de := (j[junta] as Node3D).global_position
	var d := alvo_mira - de
	return clampf(rad_to_deg(atan2(-d.y, maxf(0.4, Vector2(d.x, d.z).length()))), -55.0, 58.0)


func _process(delta: float) -> void:
	if modelo == null:
		return
	_alvos.clear()
	var t := float(Time.get_ticks_msec()) * 0.001
	var dobra := 0.0  # graus de dobra das pernas (o corpo desce junto)
	var lamina := false
	var macio := 10.0
	match atual:
		"Walk", "Run":
			var corre := atual == "Run"
			_fase += delta * (9.5 if corre else 6.0) * _vel
			var amp := 34.0 if corre else 22.0
			var s := sin(_fase)
			var c := cos(_fase)
			_pernas("quadril", -amp * s, amp * s)
			_pernas("joelho", amp * 1.1 * maxf(0.0, c), amp * 1.1 * maxf(0.0, -c))
			_alvo("ombroE", -amp * 0.7 * s, 0.0, 5.0)
			_alvo("ombroD", amp * 0.7 * s, 0.0, -5.0)
			_alvo("cotoveloE", -12.0)
			_alvo("cotoveloD", -12.0)
			_alvo("tronco", 6.0 if corre else 2.0, 0.0, 2.0 * s)
			dobra = 6.0 + 4.0 * absf(c)
			macio = 22.0
		"Shoot":
			tempo_ataque += delta
			macio = 22.0
			match String(ficha.get("arma", "tiro")):
				"corpo":
					# o golpe do jogador: o braço varre de um lado ao outro na altura do peito; daqui ele
					# desce o que for preciso para a lâmina passar na altura do robô
					var desce := maxf(0.0, _descida("ombroD"))
					var giro := lerpf(-85.0, 85.0, smoothstep(0.2, 0.62, tempo_ataque))
					_alvo("ombroD", -86.0 + desce, -giro, -6.0)
					_alvo("cotoveloD", -6.0)
					if j.has("bocaE") and tipo == "lamina":
						_alvo("ombroE", -86.0 + desce, giro, 6.0)
						_alvo("cotoveloE", -6.0)
					_alvo("tronco", desce * 0.25, -giro * 0.3, 0.0)
					dobra = 8.0 + desce * 0.25
					lamina = tempo_ataque > 0.06 and tempo_ataque < 0.85
				"costas":
					_alvo("tronco", 9.0)
					_alvo("ombroE", 10.0, 0.0, 16.0)
					_alvo("ombroD", 10.0, 0.0, -16.0)
					dobra = 12.0
				_:
					# braço estendido para o robô: o tiro sai da boca do cano
					var desce := _descida("ombroD")
					_alvo("ombroD", -90.0 + desce, 0.0, -3.0)
					_alvo("cotoveloD", -3.0)
					_alvo("cabeca", clampf(desce * 0.4, -20.0, 20.0))
					_alvo("tronco", 0.0, -6.0, 0.0)
					if tipo == "colosso":
						_alvo("ombroE", -90.0 + desce, 0.0, 3.0)
						_alvo("cotoveloE", -3.0)
		"Death":
			# desligou: arria nas pernas, o tronco e a cabeça caem para a frente e os braços pendem
			dobra = 46.0
			_alvo("tronco", 34.0)
			_alvo("cabeca", 30.0)
			_alvo("ombroE", 14.0, 0.0, 4.0)
			_alvo("ombroD", 14.0, 0.0, -4.0)
			macio = 4.0
		_:
			_alvo("tronco", 1.5 * sin(t * 1.6))
			_alvo("cabeca", 0.0, 10.0 * sin(t * 0.5))
			_alvo("ombroE", 2.0 * sin(t * 1.6), 0.0, 4.0)
			_alvo("ombroD", 2.0 * sin(t * 1.6 + 0.5), 0.0, -4.0)
	if dobra > 0.0 and atual != "Walk" and atual != "Run":
		_pernas("quadril", -dobra, -dobra)
		_pernas("joelho", dobra * 2.0, dobra * 2.0)
	var k := 1.0 - exp(-macio * delta)
	for nome: String in j:
		if nome.begins_with("boca"):
			continue
		var no := j[nome] as Node3D
		no.rotation = no.rotation.lerp(_alvos.get(nome, Vector3.ZERO), k)
	# dobrando as pernas, o corpo desce para os pés ficarem no chão
	_arriado = lerpf(_arriado, 2.0 * _perna * (1.0 - cos(deg_to_rad(dobra))), k)
	(j["raiz"] as Node3D).position.y = _raiz_base - _arriado
	lamina_acesa = lamina
	for l in _laminas:
		l.visible = lamina
