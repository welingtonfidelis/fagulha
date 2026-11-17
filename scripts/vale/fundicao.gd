class_name Fundicao
extends Node3D
## A Fundição (doc §66): a arena de ondas ao lado do Pátio das Máquinas. Um galpão de fábrica fechado e
## arruinado, de chão chato: uma única porta grande de onde os robôs saem, forjas ainda acesas, escombros e
## paredes quebradas de proteção, robôs velhos caídos, fios pendurados e o painel de partida no meio.
## A ilha continua de paz: aqui só há luta quando o jogador liga o painel (quadrado / E). As ondas crescem;
## de 5 em 5 vem um minichefe, e vencê-lo salva o ponto de volta. Saindo da cratera a rodada para. Robô
## vencido desliga e afunda no chão (ninguém é destruído); deixa experiência e materiais (Arsenal).
## `cavar` aplaina o relevo antes de o chão ser montado; `montar` põe as peças; o nó cuida das ondas.

signal onda_vencida(numero: int)

enum Fase { PARADA, CONTAGEM, ONDA, RESPIRO }
const CENTRO := Vector2(-580.0, -270.0)  # na encosta sul da Serra do Mirante: a frente num patamar, os fundos dentro do morro
const RAIO := 66.0  # o chão chato
const PISO := 86.0
const SAIU := 84.0  # passando disto do centro, a rodada para
const ATIVOS := 7  # robôs ligados ao mesmo tempo, no máximo
const T_CONTAGEM := 5.0
const T_RESPIRO := 15.0
const CHEFE_A_CADA := 5
const AGUA := Color(0.35, 0.95, 0.85)
const LARANJA := Color(1.0, 0.62, 0.3)

static var montada := false

var armadura: Armadura
var hud: Hud
var sons: Sons
var mapa: Vale
var fase := Fase.PARADA
var onda := 0  # a onda em andamento (ou a última ligada)
var vivos: Array[Mecha] = []
var vencidos_total := 0  # testes
var rodada := {"sucata": 0, "nucleos": 0, "chips": 0}  # o que esta rodada já rendeu (a derrota leva metade)
var _fila: Array[Dictionary] = []
var _t := 0.0
var _solta_t := 0.0
var _portao := 0
var _caidos: Array[Dictionary] = []
var _espolios: Array[Dictionary] = []
var _painel_luz: OmniLight3D
var _mat_painel: StandardMaterial3D


# ---------------------------------------------------------------- o lugar

## Corta um nicho na encosta: o chão do galpão fica chato e o morro sobe quase a pique em volta dos fundos
## e dos lados (o galpão entra na montanha, de onde o minério sai). À frente fica um pátio que emenda no
## relevo. O túnel atrás da porta ganha o seu corredor, coberto depois por um bloco de concreto.
static func cavar(v: Vale) -> void:
	var n := Vale.F_N
	for gz in n:
		var z := -Vale.F_META + gz * Vale.F_PASSO
		if absf(z - CENTRO.y) > MZ + 60.0:
			continue
		for gx in n:
			var x := -Vale.F_META + gx * Vale.F_PASSO
			var lx := x - CENTRO.x
			var lz := z - CENTRO.y
			if absf(lx) > MX + 40.0:
				continue
			var d := Vector2(maxf(absf(lx) - (MX + 5.0), 0.0), maxf(maxf((-MZ - 3.0) - lz, lz - (MZ + 24.0)), 0.0)).length()
			# o corredor do túnel, atrás da porta
			var dt := Vector2(maxf(absf(lx) - 12.5, 0.0), maxf(maxf((-MZ - 22.0) - lz, lz + MZ), 0.0)).length()
			var t := minf(smoothstep(0.0, 13.0, d), smoothstep(0.0, 5.0, dt))
			if t >= 1.0:
				continue
			var i := gz * n + gx
			v._fora_h[i] = lerpf(PISO, v._fora_h[i], t)


# O galpão (pedido do usuário, com um desenho de referência): um lugar fechado e arruinado pelo abandono,
# com uma única porta grande de onde os robôs vêm, escombros e paredes quebradas que servem de proteção,
# ferrugem e mato, robôs velhos caídos, fios pendurados e as forjas ainda acesas.
const MX := 50.0  # meia largura por dentro (leste-oeste)
const MZ := 38.0  # meio comprimento (a porta fica na parede norte, z = -MZ)
const ALT := 18.0  # altura de referência (lâmpadas, ganchos)
const ARCO_A := 51.5  # meia largura do arco do telhado, no chão
const ARCO_H := 24.0  # altura do arco no meio
const PORTA_LARG := 16.0
const PORTA_ALT := 12.0
const ABRE_PORTA := 0.66  # rad que cada folha abre
const CONCRETO := Color(0.36, 0.38, 0.36)
const FERRO := Color(0.3, 0.27, 0.24)
const FOGO := Color(1.0, 0.5, 0.14)

static var _tex: Texture2D
static var luzes_forja: Array[OmniLight3D] = []
static var bracos_forja: Array[Node3D] = []
static var lampadas: Array[Dictionary] = []


static func _mat(cor: Color, fer := 0.35, mus := 0.3) -> ShaderMaterial:
	return BaseVale._mat_cor(cor, fer, mus, _tex)


static func _luz(cor: Color, forca: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = forca
	return m


## A altura do telhado em arco sobre o ponto x (0 fora dele).
static func teto(x: float) -> float:
	return ARCO_H * sqrt(maxf(0.0, 1.0 - (x / ARCO_A) * (x / ARCO_A)))


## Do lugar para o mundo: x para o leste, z para o sul, y acima do piso.
static func aqui(x: float, y: float, z: float) -> Vector3:
	return Vector3(CENTRO.x + x, PISO + y, CENTRO.y + z)


static func no_mundo(graus: float, raio: float, alto := 0.0) -> Vector3:
	var a := deg_to_rad(graus)
	return Vector3(CENTRO.x + cos(a) * raio, PISO + alto, CENTRO.y + sin(a) * raio)


static func _caixa(v: Node3D, corpo: StaticBody3D, tam: Vector3, xf: Transform3D, mat: Material, colide := true, desvia := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = xf
	v.add_child(mi)
	if colide:
		var cs := CollisionShape3D.new()
		var f := BoxShape3D.new()
		f.size = tam
		cs.shape = f
		cs.transform = xf
		corpo.add_child(cs)
		if desvia:
			Obstaculos.registrar_forma(f, xf, PISO)
	return mi


static func _cilindro(v: Node3D, corpo: StaticBody3D, raio: float, alt: float, xf: Transform3D, mat: Material, colide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = raio
	cm.bottom_radius = raio
	cm.height = alt
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = mat
	mi.transform = xf
	mi.visible = mat != null  # sem material: só a colisão
	v.add_child(mi)
	if colide:
		var cs := CollisionShape3D.new()
		var f := CylinderShape3D.new()
		f.radius = raio
		f.height = alt
		cs.shape = f
		cs.transform = xf
		corpo.add_child(cs)
		Obstaculos.registrar(xf.origin.x, xf.origin.z, raio + 0.4)
	return mi


static func _fumaca(v: Node3D, pos: Vector3, tam: float, cor: Color, quantos: int) -> void:
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.vertex_color_use_as_albedo = true
	mp.albedo_color = cor
	if ResourceLoader.exists("res://assets/fx/kenney/smoke_04.png"):
		mp.albedo_texture = load("res://assets/fx/kenney/smoke_04.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(tam, tam)
	quad.material = mp
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	var pp := ParticleProcessMaterial.new()
	pp.direction = Vector3(0, 1, 0)
	pp.spread = 14.0
	pp.initial_velocity_min = 1.2
	pp.initial_velocity_max = 2.4
	pp.gravity = Vector3(0.3, 0.5, 0)
	pp.scale_min = 0.6
	pp.scale_max = 1.6
	pp.color_ramp = gt
	var gp := GPUParticles3D.new()
	gp.amount = quantos
	gp.lifetime = 5.0
	gp.process_material = pp
	gp.draw_pass_1 = quad
	gp.position = pos
	gp.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 20, 16))
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(gp)


## Uma parede em painéis de 10 m, com o alto quebrado em alturas diferentes; `vao` deixa um buraco.
static func _parede(v: Node3D, corpo: StaticBody3D, rng: RandomNumberGenerator, de: Vector3, ate: Vector3, vao := Vector2(INF, INF)) -> void:
	var comp := de.distance_to(ate)
	var dir := (ate - de) / comp
	var b := Basis(Vector3.UP, atan2(-dir.z, dir.x))
	var n := int(ceil(comp / 10.0))
	var passo := comp / n
	for i in n:
		var s := (i + 0.5) * passo
		if s > vao.x and s < vao.y:
			continue
		var h := ALT - (rng.randf_range(2.0, 7.5) if rng.randf() < 0.4 else rng.randf_range(0.0, 0.8))
		if s > vao.x - passo and s < vao.y + passo:
			h = rng.randf_range(5.0, 10.0)
		var p := de + dir * s
		_caixa(v, corpo, Vector3(passo + 0.05, h, 1.6), Transform3D(b, p + Vector3(0, h * 0.5 - 0.4, 0)),
			_mat(CONCRETO.darkened(rng.randf_range(0.0, 0.12)), 0.25, 0.4))
		# o pilar de aço entre os painéis
		_caixa(v, corpo, Vector3(0.7, h + 0.3, 2.0), Transform3D(b, p + dir * (passo * 0.5) + Vector3(0, h * 0.5 - 0.3, 0)), _mat(FERRO, 0.5, 0.15), false)
		# mato pendurado do alto quebrado, pelo lado de dentro
		if rng.randf() < 0.55:
			var w := rng.randf_range(1.5, 4.0)
			var c := rng.randf_range(1.5, 5.0)
			var dentro := (Vector3(CENTRO.x, p.y, CENTRO.y) - p)
			dentro = (dentro - dir * dentro.dot(dir)).normalized()
			_caixa(v, corpo, Vector3(w, c, 0.25), Transform3D(b, p + dir * rng.randf_range(-3.0, 3.0) + Vector3(0, h - c * 0.5 - 0.3, 0) + dentro * 0.95),
				_mat(Color(0.2, 0.42, 0.16), 0.0, 1.0), false)


## Um monte de escombros: blocos tortos em volta de um ponto. O bloco maior protege de tiro.
static func _escombros(v: Node3D, corpo: StaticBody3D, rng: RandomNumberGenerator, p: Vector3, tam: float) -> void:
	_caixa(v, corpo, Vector3(tam * 2.2, tam * 1.5, tam), Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))), p + Vector3(0, tam * 0.6, 0)),
		_mat(CONCRETO.lightened(0.06), 0.15, 0.55), true, true)
	for i in 5:
		var t := tam * rng.randf_range(0.3, 0.75)
		var q := p + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)).normalized() * tam * rng.randf_range(1.2, 2.2)
		_caixa(v, corpo, Vector3(t * 1.6, t, t * 1.2), Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))), q + Vector3(0, t * 0.35, 0)),
			_mat(CONCRETO.darkened(rng.randf_range(0.0, 0.15)), 0.3, 0.5), true, t > 0.9)
	_tufo(v, p + Vector3(rng.randf_range(-0.6, 0.6), tam * 1.25, rng.randf_range(-0.4, 0.4)), tam * 0.9)


static func _tufo(v: Node3D, p: Vector3, raio: float) -> void:
	var tufo := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = raio
	sm.height = raio * 0.9
	sm.radial_segments = 10
	sm.rings = 5
	tufo.mesh = sm
	tufo.material_override = _mat(Color(0.22, 0.45, 0.17), 0.0, 1.0)
	tufo.position = p
	v.add_child(tufo)


## Um pedaço de parede que ficou em pé: três lajes de alturas diferentes, encostadas.
static func _parede_quebrada(v: Node3D, corpo: StaticBody3D, rng: RandomNumberGenerator, p: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var x := -3.2
	for i in 3:
		var w := rng.randf_range(1.8, 2.6)
		var h := rng.randf_range(1.6, 4.4)
		_caixa(v, corpo, Vector3(w, h, 0.9), Transform3D(b * Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.06, 0.06))), p + b * Vector3(x + w * 0.5, h * 0.5 - 0.2, 0)),
			_mat(CONCRETO.lightened(0.04), 0.2, 0.5), true, true)
		x += w
	_caixa(v, corpo, Vector3(5.5, 0.5, 1.4), Transform3D(b, p + b * Vector3(0, 0.12, 0.5)), _mat(Color(0.22, 0.45, 0.17), 0.0, 1.0), false)


# Peças prontas (em vez de caixas): o Factory Kit do Kenney (CC0) para máquinas, esteiras, braços, tubos,
# guindastes e engrenagens; o Modular SciFi MegaKit (já usado na base) para colunas, barris, caixas e cabos;
# e as plantas do vale para o mato. Tudo recebe a mesma pintura de ferrugem e musgo.
const KIT := "res://assets/vale/fundicao/%s.glb"
const MEGAKIT := "res://assets/vale/base/%s.gltf"
const TINTA_KIT := Color(0.78, 0.7, 0.6)

static var _cenas := {}
static var _mats_kit := {}
static var pecas_kit := 0


static func _mat_kit(tinta: Color, fer: float, mus: float) -> ShaderMaterial:
	var chave := "%s|%.2f|%.2f" % [tinta.to_html(), fer, mus]
	if not _mats_kit.has(chave):
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/shaders/vale_base.gdshader")
		m.set_shader_parameter("ruido", _tex)
		m.set_shader_parameter("tex", load("res://assets/vale/fundicao/Textures/colormap.png"))
		m.set_shader_parameter("tinta", tinta)
		m.set_shader_parameter("ferrugem", fer * 0.5)  # o kit é liso e claro: ferrugem inteira o deixava quase preto
		m.set_shader_parameter("musgo", mus)
		_mats_kit[chave] = m
	return _mats_kit[chave]


## Uma peça do Factory Kit. `xf` leva a escala; a origem da peça é a do modelo (o meio da base, no kit).
static func _kit(v: Node3D, nome: String, xf: Transform3D, tinta := TINTA_KIT, fer := 0.4, mus := 0.25, corpo: StaticBody3D = null) -> Node3D:
	if not _cenas.has(nome):
		_cenas[nome] = load(KIT % nome)
	var no := (_cenas[nome] as PackedScene).instantiate() as Node3D
	no.transform = xf
	for mi: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m and String(m.resource_name).contains("glass"):
				mi.set_surface_override_material(s, _luz(Color(0.25, 0.5, 0.5), 0.5))
			else:
				mi.set_surface_override_material(s, _mat_kit(tinta, fer, mus))
	v.add_child(no)
	pecas_kit += 1
	if corpo:
		_colisao_de(corpo, BaseVale._caixa(no), no.global_transform if no.is_inside_tree() else xf)
	return no


## Colisão em caixa para uma peça de pacote: a caixa que envolve o modelo, no lugar e no tamanho dele.
static func _colisao_de(corpo: StaticBody3D, caixa: AABB, xf: Transform3D) -> void:
	var f := BoxShape3D.new()
	f.size = caixa.size * xf.basis.get_scale()
	var cs := CollisionShape3D.new()
	cs.shape = f
	cs.transform = Transform3D(xf.basis.orthonormalized(), xf * caixa.get_center())
	corpo.add_child(cs)
	if f.size.x > 0.9 or f.size.z > 0.9:
		Obstaculos.registrar_forma(f, cs.transform, PISO)


## Uma peça do MegaKit (as da base), com o meio da base na origem.
static func _megakit(v: Node3D, nome: String, xf: Transform3D, fer := 0.5, mus := 0.35, corpo: StaticBody3D = null) -> Node3D:
	var chave := "mk_" + nome
	if not _cenas.has(chave):
		_cenas[chave] = load(MEGAKIT % nome)
	var raiz := (_cenas[chave] as PackedScene).instantiate() as Node3D
	var caixa := BaseVale._caixa(raiz)
	raiz.position = -Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
	var no := Node3D.new()
	no.add_child(raiz)
	no.transform = xf
	BaseVale.vestir(raiz, fer, mus, _tex)
	v.add_child(no)
	pecas_kit += 1
	if corpo:
		_colisao_de(corpo, AABB(Vector3(-caixa.size.x * 0.5, 0, -caixa.size.z * 0.5), caixa.size), xf)
	return no


static func _esc(giro: float, escala: float, p: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * escala), p)


## Mato de verdade: samambaias, moitas, plantas e trevos do vale em volta de um ponto.
static func _mato(v: Vale, rng: RandomNumberGenerator, p: Vector3, raio: float, quantos: int) -> void:
	var tipos := ["q_samambaia", "q_planta_a", "q_planta_b", "q_planta_c", "q_moita", "q_trevo", "q_planta_d", "q_samambaia"]
	for i in quantos:
		var nome: String = tipos[rng.randi() % tipos.size()]
		if not v._malhas.has(nome):
			continue
		var q := p + Vector3(rng.randf_range(-raio, raio), 0, rng.randf_range(-raio, raio))
		v._por(nome, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.7)), q - Vector3(0, 0.05, 0)))


## Uma forja: a máquina, o funil e a chaminé de tubos, a boca acesa, a esteira com peças em brasa, o
## pistão e o braço de robô que ainda se mexe. `giro` vira a boca (o -Z dela) para o meio do galpão.
static func _forja(v: Node3D, corpo: StaticBody3D, p: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var escuro := _mat(Color(0.12, 0.11, 0.1), 0.3, 0.1)
	var ferro := Color(0.98, 0.86, 0.74)
	# o corpo (com uma caixa invisível de colisão) e o que vai em cima
	_kit(v, "machine-fortified", Transform3D(b.scaled(Vector3.ONE * 4.6), p), ferro, 0.45, 0.2)
	var cs := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = Vector3(5.6, 6.2, 7.4)
	cs.shape = f
	cs.transform = Transform3D(b, p + Vector3(0, 3.1, 0))
	corpo.add_child(cs)
	Obstaculos.registrar_forma(f, cs.transform, PISO)
	_kit(v, "hopper-high-round", Transform3D(b.scaled(Vector3.ONE * 3.0), p + Vector3(0, 6.1, 0)), ferro, 0.5, 0.25, corpo)
	for i in 3:
		_kit(v, "pipe-large-long", Transform3D((b * Basis(Vector3(0, 0, 1), PI * 0.5)).scaled(Vector3.ONE * 1.7), p + b * Vector3(2.9, 1.7 + i * 3.4, 1.6)), ferro, 0.55, 0.2, corpo)
	_kit(v, "pipe-large-valve", Transform3D((b * Basis(Vector3(0, 0, 1), PI * 0.5)).scaled(Vector3.ONE * 1.7), p + b * Vector3(2.9, 11.0, 1.6)), ferro, 0.55, 0.2)
	_kit(v, "piston-round", Transform3D(b.scaled(Vector3.ONE * 2.6), p + b * Vector3(-4.6, 0, 1.4)), ferro, 0.45, 0.25, corpo)
	_kit(v, "machine-window", Transform3D((b * Basis(Vector3.UP, PI * 0.5)).scaled(Vector3.ONE * 2.6), p + b * Vector3(5.0, 0, 0.5)), ferro, 0.5, 0.3, corpo)
	# a boca: um vão escuro com o fogo no fundo
	_caixa(v, corpo, Vector3(3.8, 3.0, 0.3), Transform3D(b, p + b * Vector3(0, 2.0, -3.72)), escuro, false)
	_caixa(v, corpo, Vector3(3.2, 2.2, 0.2), Transform3D(b, p + b * Vector3(0, 1.8, -3.82)), _luz(FOGO, 3.2), false)
	_caixa(v, corpo, Vector3(3.2, 0.5, 0.25), Transform3D(b, p + b * Vector3(0, 0.9, -3.87)), _luz(Color(1.0, 0.82, 0.4), 4.5), false)
	_fumaca(v, p + b * Vector3(2.9, 13.5, 1.6), 6.0, Color(0.5, 0.5, 0.5, 0.3), 14)
	_fumaca(v, p + b * Vector3(0, 3.4, -4.2), 2.6, Color(1.0, 0.6, 0.3, 0.22), 8)
	# a esteira (duas peças em fila, saindo da boca), com peças em brasa esfriando
	var ao_longo := b * Basis(Vector3.UP, PI * 0.5)
	for i in 2:
		_kit(v, "conveyor-long-sides" if i == 0 else "conveyor-long-stripe-sides", Transform3D(ao_longo.scaled(Vector3.ONE * 3.0), p + b * Vector3(0, 0, -7.0 - i * 6.0)), ferro, 0.4, 0.2)
	var ce := CollisionShape3D.new()
	var fe := BoxShape3D.new()
	fe.size = Vector3(3.0, 1.2, 12.0)
	ce.shape = fe
	ce.transform = Transform3D(b, p + b * Vector3(0, 0.6, -10.0))
	corpo.add_child(ce)
	Obstaculos.registrar_forma(fe, ce.transform, PISO)
	for i in 4:
		_caixa(v, corpo, Vector3(1.0, 0.5, 1.0), Transform3D(b * Basis(Vector3.UP, i * 0.5), p + b * Vector3(0.2 - i * 0.15, 1.45, -5.4 - i * 2.8)), _luz(FOGO.darkened(0.2 + i * 0.18), 1.6 - i * 0.35), false)
	# o braço de robô ao lado da esteira: gira devagar de um lado para o outro
	var braco := _kit(v, "robot-arm-a", Transform3D((b * Basis(Vector3.UP, PI * 0.5)).scaled(Vector3.ONE * 2.2), p + b * Vector3(-3.6, 0, -8.5)), Color(0.85, 0.6, 0.35), 0.45, 0.15, corpo)
	braco.set_meta("giro0", braco.rotation.y)
	bracos_forja.append(braco)
	var luz := OmniLight3D.new()
	luz.light_color = FOGO
	luz.light_energy = 3.0
	luz.omni_range = 22.0
	luz.position = p + b * Vector3(0, 2.6, -6.0)
	v.add_child(luz)
	luzes_forja.append(luz)


## O que enche o galpão: engrenagens, guindastes, tubos pelas paredes, colunas, barris, caixas, telas,
## cabos pendurados e mato.
static func _decorar(v: Vale, raiz: Node3D, corpo: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var ferro := Color(0.98, 0.86, 0.74)
	# engrenagens: umas em pé, meio enterradas, outras deitadas
	var cogs := ["cog-a", "cog-b", "cog-c", "cog-d", "cog-e"]
	for dados in [[-4.0, -10.0, 5.2, true], [16.0, 18.0, 4.0, true], [-30.0, 14.0, 3.0, false], [34.0, -18.0, 3.4, false], [6.0, 30.0, 2.6, false], [-18.0, -28.0, 4.4, true]]:
		var em_pe: bool = dados[3]
		var base := Basis.from_euler(Vector3(PI * 0.5 - 0.3, rng.randf() * TAU, 0)) if em_pe else Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, 0.08))
		var esc: float = dados[2]
		_kit(raiz, cogs[rng.randi() % cogs.size()], Transform3D(base.scaled(Vector3.ONE * esc), aqui(dados[0], esc * 0.38 if em_pe else 0.25, dados[1])), Color(0.7, 0.5, 0.32), 0.7, 0.3, null if em_pe else corpo)
		if em_pe:
			var cs := CollisionShape3D.new()
			var f := BoxShape3D.new()
			f.size = Vector3(esc, esc * 0.8, 0.9)
			cs.shape = f
			cs.transform = Transform3D(Basis(Vector3.UP, base.get_euler().y), aqui(dados[0], esc * 0.4, dados[1]))
			corpo.add_child(cs)
			Obstaculos.registrar_forma(f, cs.transform, PISO)
	# dois guindastes de chão, e ganchos e um ímã pendurados das treliças
	for dados in [[0.4, 3.2, -26.0, -30.0], [2.6, 2.8, 30.0, 30.0]]:
		_kit(raiz, "crane", _esc(dados[0], dados[1], aqui(dados[2], 0, dados[3])), ferro, 0.5, 0.3)
		_cilindro(raiz, corpo, 1.5, 9.0, Transform3D(Basis.IDENTITY, aqui(dados[2], 4.5, dados[3])), null)
	for dados in [[-14.0, -17.0, "crane-magnet"], [12.0, 16.0, "crane-lift"], [28.0, -6.0, "crane-lift"], [-30.0, 27.0, "crane-magnet"]]:
		var alto := teto(dados[0]) - 0.6
		if String(dados[2]) == "crane-magnet":
			_kit(raiz, "crane-lift", _esc(0.0, 3.0, aqui(dados[0], alto, dados[1])), ferro, 0.5, 0.2, corpo)
			_kit(raiz, "crane-magnet", _esc(0.6, 3.0, aqui(dados[0], alto - 6.75 - 2.7, dados[1])), ferro, 0.55, 0.2, corpo)
		else:
			_kit(raiz, "crane-lift", _esc(0.0, 3.0, aqui(dados[0], alto, dados[1])), ferro, 0.5, 0.2, corpo)
	# tubos correndo pelo alto das paredes leste e oeste, com válvulas e uma descida
	for s: float in [-1.0, 1.0]:
		for i in 14:
			var z := -MZ + 6.0 + i * 4.4
			var nome := "pipe-large-valve" if i % 5 == 2 else "pipe-large-long"
			var giro_tubo := Basis(Vector3.UP, PI * 0.5)
			_kit(raiz, nome, Transform3D(giro_tubo.scaled(Vector3.ONE * 2.2), aqui(s * (MX - 5.5), 6.2, z + (1.1 if nome == "pipe-large-valve" else 0.0))), ferro, 0.5, 0.3, corpo)
	# colunas de aço do MegaKit encostadas nas paredes compridas
	for i in 4:
		_megakit(raiz, "Column_MetalSupport" if i % 2 == 0 else "Column_Pipes", Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3(2.4, 3.2, 2.4)), aqui(-36.0 + i * 24.0, 0, -MZ + 1.6)), 0.55, 0.35, corpo)
	# barris e caixas largados pelos cantos
	for dados in [[-34.0, -32.0], [32.0, -33.0], [-36.0, 31.0], [36.0, 2.0], [14.0, -32.0], [-12.0, 33.0], [30.0, 33.0]]:
		for i in rng.randi_range(2, 4):
			var nome: String = ["Prop_Barrel1", "Prop_Barrel_Large", "Prop_Crate", "Prop_Crate_Large", "Prop_Crate_Tarp", "Prop_Barrel2_Open"][rng.randi() % 6]
			var q := aqui(float(dados[0]) + rng.randf_range(-3.5, 3.5), 0, float(dados[1]) + rng.randf_range(-3.0, 3.0))
			var tomba := Basis(Vector3(1, 0, 0), PI * 0.5) if nome.contains("Barrel") and rng.randf() < 0.35 else Basis.IDENTITY
			_megakit(raiz, nome, Transform3D((Basis(Vector3.UP, rng.randf() * TAU) * tomba).scaled(Vector3.ONE * rng.randf_range(1.5, 2.1)), q + Vector3(0, 0.55 if tomba != Basis.IDENTITY else 0.0, 0)), 0.6, 0.4, corpo)
	# telas penduradas e avisos perto da porta
	for dados in [[-13.0, -MZ + 3.0, 0.0], [13.0, -MZ + 3.0, 0.0]]:
		_kit(raiz, "screen-hanging-wide", _esc(dados[2], 3.4, aqui(dados[0], 8.5, dados[1])), ferro, 0.4, 0.2, corpo)
	for dados in [[-10.5, -MZ + 7.0], [10.5, -MZ + 7.0], [-11.0, -MZ + 13.0], [11.0, -MZ + 13.0]]:
		_kit(raiz, "warning-orange", _esc(rng.randf(), 2.2, aqui(dados[0], 0, dados[1])), Color(0.9, 0.75, 0.55), 0.45, 0.2, corpo)
	for i in 6:
		_kit(raiz, "cone", Transform3D(Basis.from_euler(Vector3(PI * 0.5 if i % 3 == 0 else 0.0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * 2.4), aqui(rng.randf_range(-9.0, 9.0), 0.35 if i % 3 == 0 else 0.0, -MZ + rng.randf_range(4.0, 12.0))), Color(0.95, 0.8, 0.6), 0.3, 0.2, corpo)
	# o painel de partida: uma mesa de tela, uma alavanca e o botão de chão
	_kit(raiz, "screen-panel-wide", _esc(PI, 2.2, aqui(0, 0, -2.2)), ferro, 0.35, 0.15, corpo)
	_kit(raiz, "lever-single", _esc(0.4, 2.4, aqui(2.4, 0, -1.2)), ferro, 0.35, 0.15, corpo)
	_kit(raiz, "button-floor-round", _esc(0.0, 5.2, aqui(0, 0, 0)), Color(0.8, 0.8, 0.75), 0.3, 0.1)
	# mato: nas frestas do piso, ao pé das paredes, em volta dos escombros e debaixo do rombo do telhado
	for i in 46:
		_mato(v, rng, aqui(rng.randf_range(-MX + 3.0, MX - 3.0), 0, rng.randf_range(-MZ + 3.0, MZ - 3.0)), 2.2, rng.randi_range(2, 4))
	for i in 26:
		var s := 1.0 if rng.randf() < 0.5 else -1.0
		if rng.randf() < 0.5:
			_mato(v, rng, aqui(s * (MX - 6.0), 0, rng.randf_range(-MZ + 3.0, MZ - 3.0)), 1.4, 3)
		else:
			_mato(v, rng, aqui(rng.randf_range(-MX + 3.0, MX - 3.0), 0, s * (MZ - 2.4)), 1.4, 3)
	_mato(v, rng, aqui(2.0, 0, -3.0), 11.0, 26)
	for i in 5:
		if v._malhas.has("q_morta_a"):
			var pa := aqui(rng.randf_range(-12.0, 16.0), 0, rng.randf_range(-13.0, 8.0))
			v._por(["q_morta_a", "q_morta_b", "q_morta_c"][i % 3], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.5)), pa))
			_cilindro(raiz, corpo, 0.45, 5.0, Transform3D(Basis.IDENTITY, pa + Vector3(0, 2.5, 0)), null)


## Um fio pendurado entre dois pontos, com barriga; ou solto, caindo reto (ate igual a de).
static func _fio(v: Node3D, de: Vector3, ate: Vector3, barriga: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var ant := de
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := de.lerp(ate, t) + Vector3(0, -barriga * 4.0 * t * (1.0 - t), 0)
		if de.is_equal_approx(ate):
			p = de + Vector3(sin(t * 5.0) * 0.25, -barriga * t, 0)
		var d := (p - ant).normalized()
		var lado := d.cross(Vector3(0.3, 0.9, 0.2)).normalized() * 0.07
		var cima := d.cross(lado).normalized() * 0.07
		for q in [[lado, cima], [cima, -lado], [-lado, -cima], [-cima, lado]]:
			var a1: Vector3 = ant + q[0]
			var a2: Vector3 = ant + q[1]
			var b1: Vector3 = p + q[0]
			var b2: Vector3 = p + q[1]
			for vert: Vector3 in [a1, b1, b2, a1, b2, a2, a1, b2, b1, a1, a2, b2]:
				st.add_vertex(vert)
		ant = p
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(Color(0.08, 0.08, 0.09), 0.3, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(mi)


## O paredão de rocha em que o galpão entra (pedido do usuário, com um desenho: o galpão construído na
## forma dele e então enfiado em parte na montanha; a versão anterior, uma capa curva de terra acompanhando
## o telhado, foi rejeitada). A grade de alturas só guarda um chão por ponto, e ali o chão é o piso do
## galpão; então a rocha é uma peça própria: uma parede quase a pique, de borda torta, que nasce em cima do
## telhado a COBRE metros dos fundos, passa bem acima dele e emenda atrás e dos lados na encosta de verdade.
## O telhado continua inteiro e à vista até sumir dentro da pedra.
const COBRE := 24.0  # metros do comprimento do galpão, a partir dos fundos, que ficam dentro da rocha
const PAREDAO := 33.0  # altura da rocha acima do piso, no meio

static func _morro(v: Vale, raiz: Node3D) -> void:
	var passo := 2.0
	var x0 := -96.0
	var z0 := -MZ - 64.0
	var nx := int(192.0 / passo) + 1
	var nz := int((64.0 + COBRE + 6.0) / passo) + 1
	var alt := PackedFloat32Array()
	var vale_a_pena := PackedByteArray()
	alt.resize(nx * nz)
	vale_a_pena.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var lx := x0 + ix * passo
			var lz := z0 + iz * passo
			var w := aqui(lx, 0, lz)
			var real := v.altura(w.x, w.z) - PISO
			var antes := Cavernas.chao_antes(w.x, w.z) - PISO
			var arco := teto(lx) if lz > -MZ - 0.5 else 0.0
			# a linha da frente do paredão avança e recua de leve; nas pontas ela recua para dentro da encosta,
			# em ferradura, e o paredão vai acabando na subida do morro em vez de terminar num degrau
			var fora := maxf(0.0, absf(lx) - 56.0)
			var linha := -MZ + COBRE + sin(lx * 0.13) * 2.2 + sin(lx * 0.37 + 1.0) * 1.0 - fora * 0.7
			# o alto é liso e sobe devagar para trás, até encontrar a encosta (antes era uma laje cheia de ondas)
			var atras := maxf(0.0, linha - lz)
			# para os lados o alto baixa até a altura da encosta, e o paredão some nela sem deixar muro de lado
			var topo := lerpf(PAREDAO + atras * 0.22 + sin(lx * 0.07 + 0.5) * 0.9, antes + 0.6, smoothstep(40.0, 68.0, absf(lx)))
			var sobe := smoothstep(linha, linha - 6.0, lz)  # 0 na frente da linha, 1 seis metros para trás
			# a cara da rocha tem relevo (saliências em pé), que some no alto
			var relevo := (sin(lx * 0.55) * 0.5 + sin(lx * 1.3 + 2.0) * 0.25) * sin(sobe * PI)
			var base := maxf(real, arco)  # de onde a pedra nasce: do chão, ou de cima do telhado
			var y := lerpf(base, maxf(topo, antes), smoothstep(0.0, 1.0, clampf(sobe + relevo * 0.12, 0.0, 1.0)))
			if lz < linha - 6.0:
				y = maxf(y, antes)
			# onde não há rocha (na frente da linha, ou onde ela não passa do chão) a peça se esconde: um palmo
			# debaixo do chão, ou debaixo do telhado
			if y < base + 0.2:
				y = base - (0.7 if arco > real else 0.3)
			alt[iz * nx + ix] = y
			vale_a_pena[iz * nx + ix] = 1 if y > base + 0.2 else 0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var faces := PackedVector3Array()
	for iz in nz - 1:
		for ix in nx - 1:
			var i := iz * nx + ix
			if vale_a_pena[i] + vale_a_pena[i + 1] + vale_a_pena[i + nx] + vale_a_pena[i + nx + 1] == 0:
				continue
			var p00 := aqui(x0 + ix * passo, alt[i], z0 + iz * passo)
			var p10 := aqui(x0 + (ix + 1) * passo, alt[i + 1], z0 + iz * passo)
			var p01 := aqui(x0 + ix * passo, alt[i + nx], z0 + (iz + 1) * passo)
			var p11 := aqui(x0 + (ix + 1) * passo, alt[i + nx + 1], z0 + (iz + 1) * passo)
			for p: Vector3 in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(p)
				faces.append(p)
	st.index()
	st.generate_normals()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_rocha.gdshader")
	mat.set_shader_parameter("ruido", _tex)
	var mi := MeshInstance3D.new()
	mi.name = "MorroDaFundicao"
	mi.mesh = st.commit()
	mi.material_override = mat
	raiz.add_child(mi)
	var pedra := Paredoes.rocha(77, 4)
	var pedra2 := Paredoes.rocha(91, 3)
	var corpo_p := StaticBody3D.new()
	corpo_p.name = "PedrasDaFundicao"
	corpo_p.collision_layer = 1
	corpo_p.collision_mask = 0
	raiz.add_child(corpo_p)
	var rp := RandomNumberGenerator.new()
	rp.seed = 4242
	for dados in [[-58.0, -8.0, 5.0], [-64.0, -2.0, 3.2], [-53.5, -13.0, 3.6], [58.0, -9.0, 4.6], [65.0, -3.0, 3.0], [54.0, -13.5, 3.8],
			[-70.0, 4.0, 2.2], [71.0, 3.0, 2.4], [-61.0, 8.0, 1.6], [62.0, 9.0, 1.8], [-30.0, -19.0, 4.2], [8.0, -20.0, 3.4], [34.0, -19.5, 4.6]]:
		var esc: float = dados[2]
		var wp := aqui(dados[0], 0, dados[1])
		var chao_p := 0.0
		# as três últimas ficam na beira de cima do paredão
		if float(dados[1]) < -15.0:
			chao_p = PAREDAO + 0.2
		var bp := Basis.from_euler(Vector3(rp.randf_range(-0.2, 0.2), rp.randf() * TAU, rp.randf_range(-0.2, 0.2))).scaled(Vector3(esc * rp.randf_range(0.9, 1.3), esc * rp.randf_range(0.7, 1.0), esc))
		var mp := MeshInstance3D.new()
		mp.mesh = pedra if rp.randf() < 0.5 else pedra2
		mp.material_override = mat
		mp.transform = Transform3D(bp, wp + Vector3(0, chao_p + esc * 0.45, 0))
		raiz.add_child(mp)
		var cp := CollisionShape3D.new()
		cp.shape = mp.mesh.create_convex_shape()
		cp.transform = mp.transform
		corpo_p.add_child(cp)
		Obstaculos.registrar(wp.x, wp.z, esc * 0.95)
	var corpo := StaticBody3D.new()
	corpo.name = "MorroDaFundicaoCorpo"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(faces)
	forma.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = forma
	corpo.add_child(cs)
	raiz.add_child(corpo)


static func montar(v: Vale) -> void:
	_tex = v._tex
	luzes_forja.clear()
	bracos_forja.clear()
	pecas_kit = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 6606
	var raiz := Node3D.new()
	raiz.name = "FundicaoObra"
	v.add_child(raiz)
	var corpo := StaticBody3D.new()
	corpo.name = "FundicaoCorpo"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	raiz.add_child(corpo)
	# o piso: lajes de concreto rachadas, com frestas por onde o chão e o mato aparecem. O topo fica 3,5 cm
	# acima do chão (mais alto, o robô e as mechas afundavam os pés nelas)
	for ix in 10:
		for iz in 8:
			if rng.randf() < 0.16:
				continue
			_caixa(raiz, corpo, Vector3(9.5 - rng.randf() * 0.9, 0.3, 9.0 - rng.randf() * 0.9),
				Transform3D(Basis(Vector3.UP, rng.randf_range(-0.03, 0.03)), aqui(-MX + 5.0 + ix * 10.0, -0.115, -MZ + 4.75 + iz * 9.5)),
				_mat(CONCRETO.darkened(0.3 + rng.randf() * 0.12), 0.25, 0.08 + rng.randf() * 0.16), false)
	# a parede dos fundos, encostada no morro: tiras de concreto que sobem até o arco, com o vão da porta
	for i in 12:
		var x0 := -MX + i * (MX * 2.0 / 12.0)
		var xm := x0 + MX / 12.0
		var h := maxf(1.0, minf(teto(x0), teto(x0 + MX * 2.0 / 12.0)) + 0.4)
		var de := 0.0
		if absf(xm) < PORTA_LARG * 0.5 + 2.4:
			de = PORTA_ALT + 3.0
		if h > de:
			_caixa(raiz, corpo, Vector3(MX * 2.0 / 12.0 + 0.05, h - de, 1.6), Transform3D(Basis.IDENTITY, aqui(xm, (h + de) * 0.5 - 0.3, -MZ - 0.2)), _mat(CONCRETO.darkened(rng.randf_range(0.0, 0.12)), 0.25, 0.4))
	# o bloco de concreto que cobre o túnel, dentro do morro
	_caixa(raiz, corpo, Vector3(PORTA_LARG + 9.0, PORTA_ALT + 6.0, 23.0), Transform3D(Basis.IDENTITY, aqui(0, (PORTA_ALT + 6.0) * 0.5 + 0.9, -MZ - 12.6)), _mat(CONCRETO.darkened(0.1), 0.2, 0.6), false)
	# a porta grande: o pórtico e duas folhas só um pouco abertas. Lá dentro é breu; os robôs saem pela
	# fresta, e o robô do jogador não entra (uma parede que não se vê fecha o vão)
	var ferro := _mat(FERRO, 0.45, 0.2)
	var breu := StandardMaterial3D.new()
	breu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	breu.albedo_color = Color(0.012, 0.012, 0.014)
	for s: float in [-1.0, 1.0]:
		_caixa(raiz, corpo, Vector3(2.4, PORTA_ALT + 3.0, 3.0), Transform3D(Basis.IDENTITY, aqui(s * (PORTA_LARG * 0.5 + 1.2), (PORTA_ALT + 3.0) * 0.5, -MZ)), ferro)
		# folha: dobradiça no pilar, aberta para dentro só uns 38 graus (sobra uma fresta de 3,4 m no meio)
		var dobra := aqui(s * PORTA_LARG * 0.5, 0, -MZ + 0.4)
		var bf := Basis(Vector3.UP, s * ABRE_PORTA)
		_caixa(raiz, corpo, Vector3(PORTA_LARG * 0.5, PORTA_ALT, 0.7), Transform3D(bf, dobra + bf * Vector3(-s * PORTA_LARG * 0.25, PORTA_ALT * 0.5, 0)), _mat(Color(0.26, 0.28, 0.27), 0.5, 0.25))
		for k in 3:
			_caixa(raiz, corpo, Vector3(PORTA_LARG * 0.5 - 0.6, 0.5, 0.9), Transform3D(bf, dobra + bf * Vector3(-s * PORTA_LARG * 0.25, 2.0 + k * 4.0, 0)), ferro, false)
		_caixa(raiz, corpo, Vector3(PORTA_LARG * 0.5 - 2.0, PORTA_ALT - 3.0, 0.82), Transform3D(bf, dobra + bf * Vector3(-s * PORTA_LARG * 0.25, PORTA_ALT * 0.5, 0)), _mat(Color(0.2, 0.22, 0.21), 0.7, 0.3), false)
		_caixa(raiz, corpo, Vector3(1.2, PORTA_ALT, 18.0), Transform3D(Basis.IDENTITY, aqui(s * (PORTA_LARG * 0.5 + 0.6), PORTA_ALT * 0.5, -MZ - 10.0)), breu)
	_caixa(raiz, corpo, Vector3(PORTA_LARG + 7.0, 3.0, 3.2), Transform3D(Basis.IDENTITY, aqui(0, PORTA_ALT + 1.5, -MZ)), ferro)
	_caixa(raiz, corpo, Vector3(PORTA_LARG + 2.4, 1.0, 18.0), Transform3D(Basis.IDENTITY, aqui(0, PORTA_ALT + 0.5, -MZ - 10.0)), breu)
	_caixa(raiz, corpo, Vector3(PORTA_LARG + 2.4, PORTA_ALT, 1.0), Transform3D(Basis.IDENTITY, aqui(0, PORTA_ALT * 0.5, -MZ - 19.0)), breu)
	_caixa(raiz, corpo, Vector3(PORTA_LARG, 0.3, 18.0), Transform3D(Basis.IDENTITY, aqui(0, -0.11, -MZ - 10.0)), breu, false)
	# o vão fechado para o jogador (as mechas andam por conta própria e passam)
	var tranca := CollisionShape3D.new()
	var ft := BoxShape3D.new()
	ft.size = Vector3(PORTA_LARG, PORTA_ALT, 0.8)
	tranca.shape = ft
	tranca.position = aqui(0, PORTA_ALT * 0.5, -MZ - 1.2)
	corpo.add_child(tranca)
	# o telhado em arco, do chão de um lado ao chão do outro: painéis entre nervuras de aço. Um rombo
	# grande no alto deixa a luz entrar, e faltam uns painéis soltos
	var nseg := 16
	var vaos := 8
	var comp_vao := MZ * 2.0 / vaos
	for iz in vaos:
		var zc := -MZ + (iz + 0.5) * comp_vao
		for k in nseg:
			var a0 := PI * k / nseg
			var a1 := PI * (k + 1) / nseg
			var p0 := Vector2(cos(a0) * ARCO_A, sin(a0) * ARCO_H)
			var p1 := Vector2(cos(a1) * ARCO_A, sin(a1) * ARCO_H)
			var no_rombo := iz >= 3 and iz <= 5 and k >= 6 and k <= 9
			var beira := (iz == 2 or iz == 6) and k >= 6 and k <= 9 or (iz >= 3 and iz <= 5 and (k == 5 or k == 10))
			# debaixo do morro (os três vãos dos fundos) não falta painel: por ali se veria o céu
			if no_rombo or (beira and rng.randf() < 0.45) or (iz > 2 and k > 2 and k < nseg - 3 and rng.randf() < 0.05):
				continue
			var meio := (p0 + p1) * 0.5
			var inclina := Basis(Vector3(0, 0, 1), atan2(p1.y - p0.y, p1.x - p0.x))
			_caixa(raiz, corpo, Vector3(p0.distance_to(p1) + 0.12, 0.6, comp_vao + 0.05), Transform3D(inclina, aqui(meio.x, meio.y, zc)),
				_mat(Color(0.5, 0.52, 0.5).darkened(rng.randf() * 0.16), 0.22 + rng.randf() * 0.2, 0.1 + rng.randf() * 0.14))
	var ferro_arco := _mat(FERRO, 0.5, 0.15)
	for iz in vaos + 1:
		var zr := -MZ + iz * comp_vao
		for k in nseg:
			var a0 := PI * k / nseg
			var a1 := PI * (k + 1) / nseg
			var p0 := Vector2(cos(a0) * (ARCO_A - 0.7), sin(a0) * (ARCO_H - 0.7))
			var p1 := Vector2(cos(a1) * (ARCO_A - 0.7), sin(a1) * (ARCO_H - 0.7))
			var meio := (p0 + p1) * 0.5
			_caixa(raiz, corpo, Vector3(p0.distance_to(p1) + 0.2, 1.1, 0.8 if iz > 0 and iz < vaos else 1.5), Transform3D(Basis(Vector3(0, 0, 1), atan2(p1.y - p0.y, p1.x - p0.x)), aqui(meio.x, meio.y, zr)), ferro_arco, false)
			# a mesma nervura por fora, mais fina, como cinta do telhado
			var q0 := Vector2(cos(a0) * (ARCO_A + 0.45), sin(a0) * (ARCO_H + 0.45))
			var q1 := Vector2(cos(a1) * (ARCO_A + 0.45), sin(a1) * (ARCO_H + 0.45))
			_caixa(raiz, corpo, Vector3(q0.distance_to(q1) + 0.2, 0.5, 0.9), Transform3D(Basis(Vector3(0, 0, 1), atan2(q1.y - q0.y, q1.x - q0.x)), aqui((q0.x + q1.x) * 0.5, (q0.y + q1.y) * 0.5, zr)), ferro_arco, false)
	_morro(v, raiz)
	# a frente aberta: dois pedaços de parede que sobraram nos cantos e a placa da engrenagem no alto
	for s: float in [-1.0, 1.0]:
		for i in 3:
			var xm := s * (MX - 4.0 - i * 7.5)
			var h := maxf(1.5, teto(xm + s * 3.6) - rng.randf_range(0.5, 5.0 + i * 3.0))
			_caixa(raiz, corpo, Vector3(7.5, h, 1.4), Transform3D(Basis.IDENTITY, aqui(xm, h * 0.5 - 0.3, MZ - 0.4)), _mat(CONCRETO.darkened(rng.randf_range(0.0, 0.12)), 0.25, 0.45))
	_caixa(raiz, corpo, Vector3(12.0, 6.5, 0.5), Transform3D(Basis.from_euler(Vector3(0, 0, 0.05)), aqui(0, ARCO_H - 5.4, MZ + 0.9)), _mat(Color(0.5, 0.3, 0.16), 0.9, 0.2))
	_kit(raiz, "cog-b", Transform3D((Basis.from_euler(Vector3(PI * 0.5, 0, 0.05))).scaled(Vector3.ONE * 5.0), aqui(0, ARCO_H - 5.4, MZ + 1.5)), Color(0.9, 0.5, 0.25), 0.7, 0.15)
	for s: float in [-1.0, 1.0]:
		_caixa(raiz, corpo, Vector3(0.5, 6.0, 0.5), Transform3D(Basis(Vector3(0, 0, 1), s * 0.5), aqui(s * 7.6, ARCO_H - 2.2, MZ + 0.6)), ferro_arco, false)
	# a moldura de vigas enferrujadas na frente: dois montantes inclinados, a travessa e as escoras em X
	var viga := _mat(Color(0.5, 0.3, 0.17), 0.85, 0.15)
	for s: float in [-1.0, 1.0]:
		_caixa(raiz, corpo, Vector3(1.3, 17.5, 1.3), Transform3D(Basis(Vector3(0, 0, 1), s * 0.42), aqui(s * 21.5, 8.0, MZ + 0.5)), viga, true, true)
		_caixa(raiz, corpo, Vector3(1.0, 9.5, 0.9), Transform3D(Basis(Vector3(0, 0, 1), s * -0.95), aqui(s * 9.0, 18.6, MZ + 0.5)), viga)
		_caixa(raiz, corpo, Vector3(1.0, 9.5, 0.9), Transform3D(Basis(Vector3(0, 0, 1), s * 0.95), aqui(s * 9.0, 18.6, MZ + 0.5)), viga)
	_caixa(raiz, corpo, Vector3(38.0, 1.3, 1.3), Transform3D(Basis.IDENTITY, aqui(0, 15.8, MZ + 0.5)), viga)
	_caixa(raiz, corpo, Vector3(30.0, 1.0, 1.1), Transform3D(Basis.IDENTITY, aqui(0, 21.4, MZ + 0.5)), viga)
	# o duto grande que sai do flanco do galpão e entra na rocha, com a boca de ventilação, e os cabos
	# que vão do telhado até o paredão
	var duto := Color(0.8, 0.78, 0.76)
	for i in 3:
		_kit(raiz, "pipe-large-long", Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 3.6), aqui(46.5, 8.0, 4.0 - i * 7.2)), duto, 0.45, 0.3, corpo)
	_kit(raiz, "hopper-round", Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)).scaled(Vector3.ONE * 3.8), aqui(46.5, 9.8, 7.6)), duto, 0.5, 0.25, corpo)
	for i in 5:
		var xc := 14.0 + i * 6.5
		_fio(raiz, aqui(xc, teto(xc) + 0.4, -4.0 + i * 1.5), aqui(xc + 12.0, 24.0 + i * 1.2, -MZ + COBRE - 4.5), 2.5 + i * 0.6)
	# duas chaminés altas do lado de fora, soltando fumaça, com um tubo de ferrugem ao pé
	for i in 2:
		var pc := aqui(-MX - 6.5 - i * 3.4, 0, MZ - 16.0 - i * 2.0)
		for k in 5:
			_kit(raiz, "pipe-large-long", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5).scaled(Vector3.ONE * 2.2), pc + Vector3(1.1, 2.2 + k * 4.4, 0)), Color(0.85, 0.75, 0.7), 0.5, 0.3, corpo)
		_fumaca(raiz, pc + Vector3(0, 23.5, 0), 6.0, Color(0.4, 0.4, 0.4, 0.34), 14)
	_kit(raiz, "pipe-large-bend", _esc(0.0, 2.6, aqui(-MX - 6.0, 0, MZ - 11.0)), Color(0.9, 0.55, 0.35), 0.8, 0.3, corpo)
	# lâmpadas penduradas das treliças: luz fraca e amarelada; duas piscam e duas já queimaram
	lampadas.clear()
	var n_lamp := 0
	for dados in [[-30.0, -22.0], [0.0, -27.0], [30.0, -22.0], [-34.0, 5.0], [34.0, 5.0], [-14.0, 16.0], [16.0, 14.0], [-30.0, 28.0], [4.0, 30.0], [32.0, 28.0]]:
		n_lamp += 1
		var pl := aqui(dados[0], minf(ALT - 5.4, teto(dados[0]) - 4.0), dados[1])
		_fio(raiz, Vector3(pl.x, PISO + teto(dados[0]) - 0.9, pl.z), pl + Vector3(0.02, 0, 0), 0.0)
		_caixa(raiz, corpo, Vector3(1.5, 0.22, 0.5), Transform3D(Basis(Vector3.UP, n_lamp * 0.9), pl), _mat(Color(0.2, 0.2, 0.2), 0.5, 0.1))
		if n_lamp % 5 == 0:
			continue  # queimada
		var vidro := _luz(Color(1.0, 0.86, 0.6), 2.2)
		_caixa(raiz, corpo, Vector3(1.3, 0.1, 0.34), Transform3D(Basis(Vector3.UP, n_lamp * 0.9), pl + Vector3(0, -0.14, 0)), vidro, false)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.84, 0.6)
		lamp.light_energy = 1.1
		lamp.omni_range = 19.0
		lamp.position = pl + Vector3(0, -0.6, 0)
		raiz.add_child(lamp)
		lampadas.append({"luz": lamp, "vidro": vidro, "pisca": n_lamp % 4 == 2})
	# as forjas, ainda acesas: três na parede oeste e duas na leste
	for z: float in [-22.0, 0.0, 22.0]:
		_forja(raiz, corpo, aqui(-MX + 12.0, 0, z), -PI * 0.5)
	for z: float in [-12.0, 14.0]:
		_forja(raiz, corpo, aqui(MX - 12.0, 0, z), PI * 0.5)
	# proteção: paredes quebradas e montes de escombros
	for dados in [[-12.0, -14.0, 0.2], [14.0, -8.0, -0.4], [-20.0, 8.0, 1.2], [8.0, 12.0, 0.1], [24.0, 20.0, -0.9], [-6.0, 24.0, 0.5]]:
		_parede_quebrada(raiz, corpo, rng, aqui(dados[0], 0, dados[1]), dados[2])
	for dados in [[-26.0, -22.0, 1.6], [22.0, -22.0, 1.9], [-10.0, 2.0, 1.3], [26.0, 4.0, 1.5], [-24.0, 24.0, 1.8], [12.0, 28.0, 1.4], [30.0, -4.0, 1.2], [-2.0, 34.0, 2.0], [20.0, 36.0, 1.7]]:
		_escombros(raiz, corpo, rng, aqui(dados[0], 0, dados[1]), dados[2])
	# uma viga caída, encostada na parede
	_caixa(raiz, corpo, Vector3(0.9, 0.9, 22.0), Transform3D(Basis.from_euler(Vector3(0.5, 0.5, 0)), aqui(26.0, 5.0, 24.0)), ferro, true, true)
	# robôs velhos, tomados pelo tempo: caídos pelos cantos, apagados
	var k := 0
	for dados in [[-16.0, 16.0, 0.8], [10.0, -18.0, 2.4], [30.0, 28.0, 4.0], [-32.0, -8.0, 1.5], [4.0, 6.0, 5.2], [-28.0, 32.0, 3.1]]:
		var velho := Mech00Visual.montar(4400 + k * 13, 1.9, _tex)
		raiz.add_child(velho)
		velho.position = aqui(dados[0], 0.0, dados[1])
		velho.rotation.y = dados[2]
		velho.tocar("Death", 6.0, 0.0)
		velho.apagar(1.0)
		velho.olho(0.0)
		_tufo(raiz, aqui(float(dados[0]) + 0.5, 0.2, float(dados[1]) - 0.4), 1.3)
		var cv := CollisionShape3D.new()
		var fv := BoxShape3D.new()
		fv.size = Vector3(1.5, 0.9, 2.4)
		cv.shape = fv
		cv.transform = Transform3D(Basis(Vector3.UP, dados[2]), aqui(dados[0], 0.45, dados[1]))
		corpo.add_child(cv)
		Obstaculos.registrar_forma(fv, cv.transform, PISO)
		k += 1
	# fios pendurados: uns de treliça a treliça, outros arrebentados
	for i in 16:
		var x := rng.randf_range(-34.0, 34.0)
		var z := -MZ + rng.randi_range(1, 6) * 9.5
		var de := aqui(x, teto(x) - 1.3, z)
		if i % 3 == 0:
			_fio(raiz, de, de, rng.randf_range(4.0, 9.0))
		else:
			var x2 := clampf(x + rng.randf_range(-12.0, 12.0), -36.0, 36.0)
			_fio(raiz, de, aqui(x2, teto(x2) - 1.3, z + 9.5), rng.randf_range(2.0, 5.0))
	_decorar(v, raiz, corpo, rng)
	montada = true
	print("fundição: galpão montado em (%.0f, %.0f), piso a %.0f m, %d peças de pacote" % [CENTRO.x, CENTRO.y, PISO, pecas_kit])


# ---------------------------------------------------------------- as ondas

func _ready() -> void:
	var meio := Vector3(CENTRO.x, PISO, CENTRO.y)
	_mat_painel = _luz(AGUA, 2.0)
	var tampo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.1
	tampo.mesh = cm
	tampo.material_override = _mat_painel
	tampo.position = meio + Vector3(0, 0.82, 0)
	add_child(tampo)
	_painel_luz = OmniLight3D.new()
	_painel_luz.light_color = AGUA
	_painel_luz.omni_range = 9.0
	_painel_luz.position = meio + Vector3(0, 2.2, 0)
	add_child(_painel_luz)
	onda = Arsenal.ponto_volta - 1


func _dist() -> float:
	var p := armadura.global_position
	return Vector2(p.x, p.z).distance_to(CENTRO)


## Quantos robôs a onda tem, quanto cada um aguenta e com que arma vem. Para a dificuldade subir aos
## poucos (pedido do usuário), as três primeiras ondas são só de ataque de perto (espada e martelo); da 4ª
## em diante entram os fuzis de um tiro, da 7ª os canhões e da 10ª os mísseis, sempre em minoria no começo.
## A cada 5, um minichefe com escolta menor.
static func receita(numero: int) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var chefe := numero % CHEFE_A_CADA == 0
	var quantos := mini(2 + numero, 14)
	if chefe:
		quantos = 2 + int(numero / CHEFE_A_CADA)
		lista.append({"chefe": true, "resistencia": 1.5 + numero / float(CHEFE_A_CADA) * 0.5, "semente": 9100 + numero,
			"arma": "corpo" if numero <= 5 else ("bala" if numero <= 10 else "pesado")})
	var balas := 0 if numero < 4 else clampi(int((numero - 2) / 2.0), 1, quantos - 2)
	var pesados := 0 if numero < 7 else clampi(int((numero - 5) / 3.0), 1, 3)
	var misseis := 0 if numero < 10 else clampi(int((numero - 8) / 3.0), 1, 3)
	balas = maxi(0, mini(balas, quantos - pesados - misseis - 1))
	for i in quantos:
		var arma := "corpo"
		if i < misseis:
			arma = "missil"
		elif i < misseis + pesados:
			arma = "pesado"
		elif i < misseis + pesados + balas:
			arma = "bala"
		lista.append({"chefe": false, "resistencia": 1.0 + (numero - 1) * 0.1, "semente": 9000 + numero * 37 + i, "arma": arma})
	# os de perto saem primeiro; os de arma, por último
	lista.reverse()
	if chefe:
		lista.push_front(lista.pop_back())
	return lista


func ligar() -> void:
	if fase != Fase.PARADA or armadura.em_pane:
		return
	onda = maxi(onda, Arsenal.ponto_volta - 1) + 1
	fase = Fase.CONTAGEM
	_t = T_CONTAGEM
	if hud:
		hud.dica = ""
		hud.avisar("Fundição ligada", "onda %d em %d s" % [onda, int(T_CONTAGEM)])
	if sons:
		sons._toque("religar", -6.0)


func _comecar_onda() -> void:
	fase = Fase.ONDA
	_fila = receita(onda)
	_solta_t = 0.0
	if hud:
		hud.avisar("Onda %d" % onda, "minichefe!" if onda % CHEFE_A_CADA == 0 else "%d robôs vindo da porta" % _fila.size())


func _soltar(dados: Dictionary) -> void:
	var chefe: bool = dados["chefe"]
	# todos nascem no breu atrás da porta, em fila, e andam reto até passar da fresta
	_portao += 1
	var de := aqui(0.0, 0.2, -MZ - 5.0 - (_portao % 4) * 3.2)
	var mc := Mecha.new()
	mc.mapa = mapa
	mc.alvo = armadura
	# a "casa" é um ponto perto do meio: dali eles já enxergam o robô em quase toda a cratera
	mc.casa = Vector3(CENTRO.x, PISO, CENTRO.y) + (de - Vector3(CENTRO.x, PISO, CENTRO.y)).normalized() * 16.0
	mc.semente = dados["semente"]
	mc.chefe = chefe
	mc.resistencia = dados["resistencia"]
	mc.arma_forcada = dados["arma"]
	add_child(mc)
	mc.global_position = de
	mc.guiado = aqui(0.0, 0.0, -MZ + 9.0)
	vivos.append(mc)


func _recompensa(mc: Mecha) -> void:
	vencidos_total += 1
	var xp := roundi((80.0 if mc.chefe else 10.0) * (1.0 + onda * 0.15))
	var nivel_antes := Arsenal.nivel()
	Arsenal.xp += xp
	var ganho := {"sucata": 6 if mc.chefe else 1 + int(mc.semente % 3 == 0), "nucleos": 0, "chips": 0}
	if mc.chefe:
		ganho["nucleos"] = 2
		ganho["chips"] = 1
	elif onda >= 4 and mc.semente % 4 == 0:
		ganho["nucleos"] = 1
	Arsenal.sucata += ganho["sucata"]
	Arsenal.nucleos += ganho["nucleos"]
	Arsenal.chips += ganho["chips"]
	for k: String in ganho:
		rodada[k] += ganho[k]
	Arsenal.guardar()
	if Arsenal.nivel() > nivel_antes and hud:
		hud.avisar("Nível %d" % Arsenal.nivel(), "novas fabricações na base")
	# os espólios: cubinhos de luz que saem do robô caído e voam para o jogador
	for i in mini(4, int(ganho["sucata"]) + int(ganho["nucleos"]) + int(ganho["chips"])):
		var cubo := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.22
		cubo.mesh = bm
		cubo.material_override = _luz(LARANJA if i > 0 else AGUA, 3.0)
		add_child(cubo)
		cubo.global_position = mc.global_position + Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6))
		_espolios.append({"no": cubo, "t": -0.35 - i * 0.12, "vel": Vector3(randf_range(-2, 2), 5.0, randf_range(-2, 2))})
	_caidos.append({"no": mc, "t": 0.0})


func _parar(motivo: String, sub := "") -> void:
	if fase != Fase.RESPIRO:
		onda = maxi(0, onda - 1)  # a onda que não acabou fica para a próxima vez
	fase = Fase.PARADA
	for mc in vivos:
		if is_instance_valid(mc):
			mc.queue_free()
	vivos.clear()
	_fila.clear()
	rodada = {"sucata": 0, "nucleos": 0, "chips": 0}
	if hud:
		hud.placar = ""
		hud.placar2 = ""
		if motivo != "":
			hud.avisar(motivo, sub)


func _physics_process(delta: float) -> void:
	if armadura == null:
		return
	# robôs vencidos afundam no chão e somem; os espólios voam para o jogador
	for c in _caidos.duplicate():
		c["t"] += delta
		var no := c["no"] as Node3D
		if not is_instance_valid(no):
			_caidos.erase(c)
		elif c["t"] > 2.2:
			no.position.y -= delta * 1.6
			if c["t"] > 4.4:
				no.queue_free()
				_caidos.erase(c)
	for e in _espolios.duplicate():
		e["t"] += delta
		var cubo := e["no"] as MeshInstance3D
		cubo.rotation += Vector3(3.0, 4.0, 2.0) * delta
		if e["t"] < 0.0:
			continue
		var alvo := armadura.pos_suave() + Vector3(0, armadura.altura_corpo() * 0.5, 0)
		var para: Vector3 = alvo - cubo.global_position
		e["vel"] = (e["vel"] as Vector3).lerp(para.normalized() * (10.0 + e["t"] * 30.0), minf(1.0, delta * 5.0))
		cubo.global_position += (e["vel"] as Vector3) * delta
		if para.length() < 0.7 or e["t"] > 5.0:
			cubo.queue_free()
			_espolios.erase(e)
	# as forjas tremem como fogo e os braços seguem trabalhando devagar
	var agora := Time.get_ticks_msec() * 0.001
	for i in luzes_forja.size():
		luzes_forja[i].light_energy = 2.6 + sin(agora * 9.0 + i * 1.7) * 0.5 + sin(agora * 23.0 + i) * 0.3
	for l in lampadas:
		if l["pisca"]:
			var acesa := fmod(agora * 1.3 + (l["luz"] as OmniLight3D).position.x, 5.0) > 0.5 and sin(agora * 37.0) > -0.6
			(l["luz"] as OmniLight3D).light_energy = 1.1 if acesa else 0.08
			(l["vidro"] as StandardMaterial3D).emission_energy_multiplier = 2.2 if acesa else 0.15
	for i in bracos_forja.size():
		bracos_forja[i].rotation.y = float(bracos_forja[i].get_meta("giro0")) + sin(agora * 0.45 + i * 1.3) * 0.7
	var pulso := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	_mat_painel.emission = AGUA if fase == Fase.PARADA else LARANJA
	_mat_painel.emission_energy_multiplier = lerpf(0.8, 2.6, pulso) if fase == Fase.PARADA else 1.2
	_painel_luz.light_color = _mat_painel.emission
	_painel_luz.light_energy = 0.6 + pulso * 0.6
	var d := _dist()
	if fase == Fase.PARADA:
		if hud:
			var perto := d < 4.0 and absf(armadura.global_position.y - PISO) < 3.0 and armadura.estado == Armadura.Estado.CHAO and not armadura.travado
			var texto := "Quadrado / E:  ligar a Fundição (onda %d)" % (maxi(onda, Arsenal.ponto_volta - 1) + 1)
			if perto:
				hud.dica = texto
				if Input.is_action_just_pressed("agir"):
					ligar()
			elif hud.dica.begins_with("Quadrado / E:  ligar a Fundição"):
				hud.dica = ""
		return
	# a rodada: saiu da cratera ou desligou, para tudo
	if armadura.em_pane:
		var perdeu := {}
		for k: String in rodada:
			perdeu[k] = int(rodada[k] / 2)
		Arsenal.sucata -= perdeu["sucata"]
		Arsenal.nucleos -= perdeu["nucleos"]
		Arsenal.chips -= perdeu["chips"]
		Arsenal.guardar()
		_parar("A Fundição venceu desta vez", "metade dos materiais da rodada ficou lá")
		return
	if d > SAIU:
		_parar("Fundição desligada", "você saiu da cratera")
		return
	match fase:
		Fase.CONTAGEM:
			_t -= delta
			if _t <= 0.0:
				_comecar_onda()
		Fase.ONDA:
			for mc in vivos.duplicate():
				if not is_instance_valid(mc):
					vivos.erase(mc)
				elif mc.desligada:
					vivos.erase(mc)
					_recompensa(mc)
			_solta_t -= delta
			if not _fila.is_empty() and vivos.size() < ATIVOS and _solta_t <= 0.0:
				_soltar(_fila.pop_front())
				_solta_t = 1.1
			if _fila.is_empty() and vivos.is_empty():
				_vencer_onda()
		Fase.RESPIRO:
			_t -= delta
			if _t <= 0.0:
				onda += 1
				_comecar_onda()
	if hud and fase != Fase.PARADA:
		match fase:
			Fase.CONTAGEM:
				hud.placar = "Onda %d em %d" % [onda, ceili(_t)]
			Fase.ONDA:
				hud.placar = "Onda %d · %d robôs" % [onda, vivos.size() + _fila.size()]
			Fase.RESPIRO:
				hud.placar = "Respiro · onda %d em %d" % [onda + 1, ceili(_t)]
		var b := Arsenal.barra()
		hud.placar2 = "Nível %d (%d de %d)  ·  Sucata %d  ·  Núcleos %d  ·  Chips %d" % [Arsenal.nivel(), b.x, b.y, Arsenal.sucata, Arsenal.nucleos, Arsenal.chips]


func _vencer_onda() -> void:
	Arsenal.recorde = maxi(Arsenal.recorde, onda)
	var chefe := onda % CHEFE_A_CADA == 0
	if chefe:
		Arsenal.ponto_volta = onda + 1
	Arsenal.guardar()
	fase = Fase.RESPIRO
	_t = T_RESPIRO
	if hud:
		hud.avisar("Onda %d vencida" % onda, "ponto de volta salvo" if chefe else "respiro de %d s" % int(T_RESPIRO))
	if sons:
		sons._toque("marcar", -4.0, 0.0)
	onda_vencida.emit(onda)
