class_name Fundicao
extends Node3D
## A Fundição (doc §66): a arena de ondas ao lado do Pátio das Máquinas. Um galpão de fábrica fechado e
## arruinado, de chão chato: uma única porta grande de onde os robôs saem, forjas ainda acesas, escombros e
## muretas de proteção, robôs velhos caídos e fios pendurados; duas brechas nos lados (doc §130).
## A ilha continua de paz: aqui só há luta quando o jogador fica mais de 18 s dentro do galpão (o painel de
## partida do meio saiu em 2026-11-20: não ligava mais nada). As ondas crescem; de 5 em 5 vem um minichefe. Toda horda começa da onda 1 (2026-11-20: não há mais ponto de volta). Saindo
## da cratera a rodada para. Robô
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
const T_PERIGO := 18.0  # segundos dentro do galpão até a horda começar (era 30; pedido do usuário, 2026-11-20)
const T_RESPIRO := 15.0
const CHEFE_A_CADA := 5
const T_AVISO_CHEFE := 2.6  # s de aviso antes de o minichefe sair da porta
const AGUA := Color(0.35, 0.95, 0.85)
const LARANJA := Color(1.0, 0.62, 0.3)

static var montada := false

var armadura: Armadura
var hud: Hud
var sons: Sons
var mapa: Vale
var fase := Fase.PARADA
var onda := 0  # a onda em andamento (ou a última ligada)
var perigo_t := T_PERIGO + 1.0  # contagem de quem está dentro do galpão com a Fundição parada (acima de T_PERIGO: ainda não entrou)
var avisos_perigo := 0  # testes
var _perigo_meio := false
var vivos: Array[Vigia] = []
var vencidos_total := 0  # testes
var rodada := {"sucata": 0, "nucleos": 0, "chips": 0}  # o que esta rodada já rendeu (a derrota leva metade)
var conta := {"xp": 0, "vencidos": 0, "ondas": 0, "recorde_antes": 0}  # o resto da rodada, para o resumo do fim
var _fila: Array[Dictionary] = []
var _t := 0.0
var _solta_t := 0.0
var _portao := 0
var _abrindo := [0.0, 0.0, 0.0]  # por entrada: s que faltam piscando antes de abrir (só as brechas)
var _aberta := [0.0, 0.0, 0.0]  # por entrada: s que ela ainda fica aberta depois do último robô
var saidas := [0, 0, 0]  # robôs que saíram por cada entrada (testes)
var _caidos: Array[Dictionary] = []
static var caidos_pecas := 0  # peças com casco de colisão nos robôs velhos caídos
var _espolios: Array[Dictionary] = []
var chefe_vivo: Vigia
var _chefe_t := 0.0
var _caixas: Array[Dictionary] = []
var _caixa_n := 0
var _caixa_t := 25.0
var subidas := 0  # vezes que subiu de nível na arena (testes)
var caixas_soltas := 0  # testes
var caixas_pegas := 0


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
			# o chão de luta fica limpo: o capim só nasce ao pé das paredes e na frente aberta (5: o chão comum,
			# sem capim). Antes ele subia pelas frestas do meio todo e escondia os robôs pequenos
			if absf(lx) < MX - 6.0 and lz > -MZ + 3.0 and lz < MZ - 3.0:
				v._cob[gz * n + gx] = 5
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
static var luz_porta: OmniLight3D
static var esteiras: Array = []  # [boca, fim] de cada esteira das forjas, no mundo: por onde saem as caixas
## As entradas dos robôs: a porta grande (0) e as duas brechas dos lados (1 oeste, 2 leste). Cada uma tem uma
## fila de lâmpadas em cima ("lampadas", os materiais) e uma luz vermelha ("luz"), ou null na porta, que usa
## a `luz_porta`.
static var entradas: Array[Dictionary] = []

## As brechas: buracos na parede do arco, atrás das forjas, no vão entre elas (x, z no lugar). Da onda 3 em
## diante parte dos robôs comuns sai por elas; a porta fica para o começo e para o minichefe.
const BRECHAS := [Vector2(-47.4, -11.0), Vector2(47.4, 1.0)]
const BRECHA_LARG := 6.0
const BRECHA_ALT := 4.4
const LUZES_FILA := 6
const COR_ENTRADA := Color(1.0, 0.28, 0.18)
const T_ABRE_BRECHA := 1.6  # s piscando antes de o primeiro robô sair por uma brecha


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


## Uma fila de lâmpadas sobre uma entrada, ao longo de `eixo`: acendem uma a uma enquanto a contagem de
## perigo corre e piscam antes de os robôs saírem por ali. Devolve os materiais, um por lâmpada.
static func _fila_de_luzes(v: Node3D, corpo: StaticBody3D, meio: Vector3, eixo: Vector3, comp: float) -> Array:
	var mats := []
	var b := Basis(Vector3.UP, atan2(-eixo.z, eixo.x))
	var passo := comp / LUZES_FILA
	for i in LUZES_FILA:
		var m := _luz(COR_ENTRADA, 0.0)
		_caixa(v, corpo, Vector3(passo * 0.72, 0.42, 0.42), Transform3D(b, meio + eixo * ((i + 0.5) * passo - comp * 0.5)), m, false)
		mats.append(m)
		acender(m, 0.0)
	return mats


## Uma lâmpada da fila: 0 apagada (vidro escuro), 1 acesa forte.
static func acender(m: StandardMaterial3D, f: float) -> void:
	m.albedo_color = Color(0.16, 0.07, 0.06).lerp(COR_ENTRADA, f)
	m.emission_energy_multiplier = lerpf(0.0, 4.0, f)


## As muretas de proteção: [x, z, comprimento, giro, altura], no lugar. Seis num anel de 13 m em volta do
## meio, quatro mais altas num anel de 23 m, e a barricada na frente da porta. Os vãos entre elas ficam
## de frente para a porta e para as duas brechas dos lados.
const MURETAS := [
	[0.0, -27.0, 9.0, 0.0, 2.1],
	[11.26, -6.5, 6.0, -1.047, 1.8], [11.26, 6.5, 6.0, 1.047, 1.8], [0.0, 13.0, 6.0, 0.0, 1.8],
	[-11.26, 6.5, 6.0, -1.047, 1.8], [-11.26, -6.5, 6.0, 1.047, 1.8], [0.0, -13.0, 6.0, 0.0, 1.8],
	[11.5, -19.9, 7.0, -0.524, 2.4], [11.5, 19.9, 7.0, 0.524, 2.4], [-11.5, 19.9, 7.0, -0.524, 2.4], [-11.5, -19.9, 7.0, 0.524, 2.4],
]


## O ponto (no lugar) fica no caminho dos robôs: a saída da porta ou o corredor de uma brecha?
static func _no_caminho(q: Vector3) -> bool:
	if absf(q.x) < 10.0 and q.z < -MZ + 10.0:
		return true
	for br: Vector2 in BRECHAS:
		if signf(q.x) == signf(br.x) and absf(q.x) > 30.0 and absf(q.z - br.y) < BRECHA_LARG * 0.5 + 2.5:
			return true
	return false


## Uma mureta: uma caixa só de colisão, reta e convexa (os robôs contornam sem prender em quina), desenhada
## como barreira de obra: a base larga, o alto mais estreito, uma tira de ferro no topo e as pontas lascadas.
static func _mureta(v: Node3D, corpo: StaticBody3D, p: Vector3, comp: float, giro: float, alt: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var cs := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = Vector3(comp, alt, 1.2)
	cs.shape = f
	cs.transform = Transform3D(b, p + Vector3(0, alt * 0.5 - 0.1, 0))
	corpo.add_child(cs)
	Obstaculos.registrar_forma(f, cs.transform, PISO)
	var cor := CONCRETO.lightened(0.16)
	_caixa(v, corpo, Vector3(comp, alt * 0.42, 1.2), Transform3D(b, p + Vector3(0, alt * 0.21 - 0.1, 0)), _mat(cor.darkened(0.06), 0.18, 0.12), false)
	_caixa(v, corpo, Vector3(comp - 0.25, alt * 0.62, 0.8), Transform3D(b, p + Vector3(0, alt * 0.69 - 0.1, 0)), _mat(cor, 0.12, 0.05), false)
	_caixa(v, corpo, Vector3(comp - 0.15, 0.12, 0.88), Transform3D(b, p + Vector3(0, alt - 0.1, 0)), _mat(FERRO, 0.6, 0.1), false)
	# as pontas lascadas: um dente mais baixo em cada ponta, por cima da base
	for s: float in [-1.0, 1.0]:
		_caixa(v, corpo, Vector3(0.5, alt * 0.25, 1.24), Transform3D(b, p + b * Vector3(s * (comp * 0.5 - 0.25), alt * 0.42 + alt * 0.125 - 0.1, 0)), _mat(cor.darkened(0.12), 0.25, 0.2), false)


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
	esteiras.append([p + b * Vector3(0, 1.6, -4.6), p + b * Vector3(0, 1.6, -15.4), p + b * Vector3(0, 0.45, -17.6)])
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
	# engrenagens: umas em pé, meio enterradas e encostadas na parede dos fundos, outras deitadas pelos cantos
	# (fora do chão de luta)
	var cogs := ["cog-a", "cog-b", "cog-c", "cog-d", "cog-e"]
	for dados in [[-17.0, -35.6, 4.4, true], [21.0, -35.6, 4.0, true], [22.0, 35.0, 3.0, false], [34.0, -20.5, 3.4, false], [-4.0, 35.0, 2.6, false]]:
		var em_pe: bool = dados[3]
		var base := Basis.from_euler(Vector3(PI * 0.5 - 0.3, rng.randf_range(-0.2, 0.2), 0)) if em_pe else Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, 0.08))
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
	# ganchos e um ímã pendurados das treliças (os dois guindastes de chão saíram na reforma: eram colunas
	# finas onde os robôs rodavam em volta)
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
	for dados in [[-34.0, -32.0], [32.0, -33.0], [-36.0, 31.0], [14.0, -32.0], [-12.0, 33.0], [30.0, 33.0]]:
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
	# os cones marcam a saída da porta pelos lados, sem ficar no caminho dos robôs
	for i in 6:
		var lado_c := -1.0 if i < 3 else 1.0
		_kit(raiz, "cone", Transform3D(Basis.from_euler(Vector3(PI * 0.5 if i % 3 == 2 else 0.0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * 2.4), aqui(lado_c * (7.0 + (i % 3) * 0.9), 0.35 if i % 3 == 2 else 0.0, -MZ + 3.0 + (i % 3) * 2.6)), Color(0.95, 0.8, 0.6), 0.3, 0.2, corpo)
	# mato só ao pé das paredes e nos cantos (reforma de 2026-11-20: o mato do meio, a moita grande em volta do
	# meio e as árvores secas saíram; escondiam os robôs e as árvores eram colunas finas no caminho). Fora
	# das brechas dos lados e da saída da porta
	for i in 30:
		var s := 1.0 if rng.randf() < 0.5 else -1.0
		var q := Vector3.ZERO
		if rng.randf() < 0.5:
			q = Vector3(s * (MX - 4.5), 0, rng.randf_range(-MZ + 3.0, MZ - 3.0))
		else:
			q = Vector3(rng.randf_range(-MX + 3.0, MX - 3.0), 0, s * (MZ - 2.4))
		if _no_caminho(q):
			continue
		_mato(v, rng, aqui(q.x, 0, q.z), 1.4, 3)


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
	# duas superfícies: o que é deitado (o alto do paredão e as rampas dos lados) leva o chão de capim do
	# vale; o que é em pé leva a rocha. Tudo em rocha, as rampas viravam duas faixas cinza no morro
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var sc := SurfaceTool.new()
	sc.begin(Mesh.PRIMITIVE_TRIANGLES)
	sc.set_smooth_group(0)
	sc.set_color(Color(0, 0, 0, 1))
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
			var sobe := maxf(maxf(p00.y, p10.y), maxf(p01.y, p11.y)) - minf(minf(p00.y, p10.y), minf(p01.y, p11.y))
			var deitado := sobe < passo * 1.15  # menos de uns 40 graus
			for p: Vector3 in [p00, p10, p11, p00, p11, p01]:
				if deitado:
					sc.set_color(Color(0, 0, 0, 1))
					sc.add_vertex(p)
				else:
					st.add_vertex(p)
				faces.append(p)
	st.index()
	st.generate_normals()
	sc.index()
	sc.generate_normals()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_rocha.gdshader")
	mat.set_shader_parameter("ruido", _tex)
	var mat_chao := ShaderMaterial.new()
	mat_chao.shader = load("res://scripts/shaders/vale_chao.gdshader")
	mat_chao.set_shader_parameter("ruido", _tex)
	var mi := MeshInstance3D.new()
	mi.name = "MorroDaFundicao"
	var malha := st.commit()
	malha.surface_set_material(0, mat)
	sc.commit(malha)
	malha.surface_set_material(1, mat_chao)
	mi.mesh = malha
	raiz.add_child(mi)
	# capim e mato nas rampas e no alto, para emendar com o morro
	var rm := RandomNumberGenerator.new()
	rm.seed = 9911
	for k in 150:
		var ix := rm.randi_range(1, nx - 2)
		var iz := rm.randi_range(1, nz - 2)
		var i := iz * nx + ix
		if vale_a_pena[i] == 0 or absf(alt[i + 1] - alt[i]) > passo * 0.9 or absf(alt[i + nx] - alt[i]) > passo * 0.9:
			continue
		var nome: String = ["q_planta_a", "q_samambaia", "q_moita", "q_planta_c", "q_trevo", "q_planta_b"][rm.randi() % 6]
		if v._malhas.has(nome):
			v._por(nome, Transform3D(Basis(Vector3.UP, rm.randf() * TAU).scaled(Vector3.ONE * rm.randf_range(0.9, 1.9)), aqui(x0 + ix * passo, alt[i] - 0.05, z0 + iz * passo)))
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
	esteiras.clear()
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
	# o piso: lajes de concreto claras e inteiras, com juntas finas e escuras (uma tira por baixo, que só
	# aparece nas frestas; sem ela o chão do vale brilhava verde entre as lajes). O topo fica 3,5 cm acima do
	# chão (mais alto, o robô e as mechas afundavam os pés nelas). Reforma de 2026-11-20: o chão escuro,
	# musgoso e furado escondia os robôs; agora eles se destacam nele
	var junta := _mat(Color(0.09, 0.09, 0.085), 0.2, 0.05)
	for k in range(1, 10):
		_caixa(raiz, corpo, Vector3(0.8, 0.04, MZ * 2.0), Transform3D(Basis.IDENTITY, aqui(-MX + k * 10.0, 0.0, 0.0)), junta, false)
	for k in range(1, 8):
		_caixa(raiz, corpo, Vector3(MX * 2.0, 0.04, 0.8), Transform3D(Basis.IDENTITY, aqui(0.0, 0.0, -MZ + k * 9.5)), junta, false)
	for ix in 10:
		for iz in 8:
			var beira := ix == 0 or ix == 9 or iz == 7
			_caixa(raiz, corpo, Vector3(9.85 - rng.randf() * 0.35, 0.3, 9.35 - rng.randf() * 0.35),
				Transform3D(Basis(Vector3.UP, rng.randf_range(-0.012, 0.012)), aqui(-MX + 5.0 + ix * 10.0, -0.115, -MZ + 4.75 + iz * 9.5)),
				_mat(CONCRETO.darkened(0.12 + rng.randf() * 0.08), 0.14, (0.12 if beira else 0.03) + rng.randf() * 0.05), false)
	# a parede dos fundos, encostada no morro: tiras de concreto que sobem até o arco, com o vão da porta
	for i in 12:
		var x0 := -MX + i * (MX * 2.0 / 12.0)
		var xm := x0 + MX / 12.0
		var h := maxf(1.0, minf(teto(x0), teto(x0 + MX * 2.0 / 12.0)) + 0.4)
		var de := 0.0
		if absf(xm) < PORTA_LARG * 0.5 + 2.4:
			de = PORTA_ALT + 3.0
		if h > de:
			_caixa(raiz, corpo, Vector3(MX * 2.0 / 12.0 + 0.05, h - de, 1.6), Transform3D(Basis.IDENTITY, aqui(xm, (h + de) * 0.5 - 0.3, -MZ - 0.2)), _mat(CONCRETO.darkened(0.45 + rng.randf_range(0.0, 0.12)), 0.3, 0.3))
	# na frente do concreto, painéis de parede do MegaKit (8 m de largura por 6 de altura), em fiadas até o
	# arco: a de baixo inteira e com janelas, as de cima cada vez mais quebradas e com falhas
	var paineis := ["WallAstra_Straight", "WallAstra_Straight_Divided", "WallBand_Straight", "WallAstra_Straight_Flat_Window", "WallAstra_Straight_Window"]
	var quebrados := ["WallAstra_Straight_Broken", "WallBand_Straight_Broken"]
	for fiada in 4:
		for col in 13:
			var xm := -48.0 + col * 8.0
			if absf(xm) < PORTA_LARG * 0.5 + 5.0 and fiada < 3:
				continue  # o vão da porta e o pórtico
			var folga := teto(xm) - (fiada + 1) * 6.0
			if minf(teto(xm - 4.0), teto(xm + 4.0)) < fiada * 6.0 + 2.0:
				continue  # já fora do arco
			var nome: String = paineis[rng.randi() % paineis.size()]
			if fiada >= 2 or folga < 2.0:
				if rng.randf() < 0.25:
					continue
				nome = quebrados[rng.randi() % 2] if rng.randf() < 0.6 else nome
			_megakit(raiz, nome, Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3(2.0, 2.0, 2.0)), aqui(xm, fiada * 6.0, -MZ + 1.3)), 0.16 + fiada * 0.09 + rng.randf() * 0.12, 0.2 + rng.randf() * 0.3)
	# o bloco de concreto que cobre o túnel, dentro do morro
	_caixa(raiz, corpo, Vector3(PORTA_LARG + 9.0, PORTA_ALT + 6.0, 23.0), Transform3D(Basis.IDENTITY, aqui(0, (PORTA_ALT + 6.0) * 0.5 + 0.9, -MZ - 12.6)), _mat(CONCRETO.darkened(0.1), 0.2, 0.6))
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
	# a luz vermelha da fresta: fraca em paz, pulsa forte quando o minichefe é anunciado
	luz_porta = OmniLight3D.new()
	luz_porta.light_color = Color(1.0, 0.25, 0.18)
	luz_porta.light_energy = 2.4
	luz_porta.omni_range = 22.0
	luz_porta.shadow_enabled = false
	luz_porta.position = aqui(0, 5.0, -MZ + 2.5)
	raiz.add_child(luz_porta)
	# a fila de lâmpadas sobre a porta: enche enquanto alguém fica no galpão parado (o tempo até a horda) e
	# fica acesa durante as ondas (antes era uma tira acesa sempre)
	entradas.clear()
	entradas.append({"luz": null, "lampadas": _fila_de_luzes(raiz, corpo, aqui(0, PORTA_ALT + 0.4, -MZ + 1.75), Vector3.RIGHT, PORTA_LARG - 3.0)})
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
				_mat(Color(0.5, 0.52, 0.5).darkened(rng.randf() * 0.16), 0.22 + rng.randf() * 0.2, 0.1 + rng.randf() * 0.14), false)
			# a colisão do painel é mais grossa que ele (2 m, para dentro) e passa um pouco dos vizinhos: com a
			# chapa fina de 0,6 m o robô entrava no telhado nas emendas e ao pousar depressa
			var cp := CollisionShape3D.new()
			var fp := BoxShape3D.new()
			fp.size = Vector3(p0.distance_to(p1) + 0.6, 2.0, comp_vao + 0.3)
			cp.shape = fp
			cp.transform = Transform3D(inclina, aqui(meio.x, meio.y, zc) + inclina * Vector3(0, 0.7, 0))
			corpo.add_child(cp)
	var ferro_arco := _mat(FERRO, 0.5, 0.15)
	for iz in vaos + 1:
		var zr := -MZ + iz * comp_vao
		for k in nseg:
			var a0 := PI * k / nseg
			var a1 := PI * (k + 1) / nseg
			var p0 := Vector2(cos(a0) * (ARCO_A - 0.7), sin(a0) * (ARCO_H - 0.7))
			var p1 := Vector2(cos(a1) * (ARCO_A - 0.7), sin(a1) * (ARCO_H - 0.7))
			var meio := (p0 + p1) * 0.5
			_caixa(raiz, corpo, Vector3(p0.distance_to(p1) + 0.2, 1.1, 0.8 if iz > 0 and iz < vaos else 1.5), Transform3D(Basis(Vector3(0, 0, 1), atan2(p1.y - p0.y, p1.x - p0.x)), aqui(meio.x, meio.y, zr)), ferro_arco)
			# a mesma nervura por fora, mais fina, como cinta do telhado
			var q0 := Vector2(cos(a0) * (ARCO_A + 0.45), sin(a0) * (ARCO_H + 0.45))
			var q1 := Vector2(cos(a1) * (ARCO_A + 0.45), sin(a1) * (ARCO_H + 0.45))
			_caixa(raiz, corpo, Vector3(q0.distance_to(q1) + 0.2, 0.5, 0.9), Transform3D(Basis(Vector3(0, 0, 1), atan2(q1.y - q0.y, q1.x - q0.x)), aqui((q0.x + q1.x) * 0.5, (q0.y + q1.y) * 0.5, zr)), ferro_arco)
	_morro(v, raiz)
	# a frente aberta: dois pedaços de parede que sobraram nos cantos e a placa da engrenagem no alto
	for s: float in [-1.0, 1.0]:
		for i in 3:
			var xm := s * (MX - 4.0 - i * 7.5)
			var h := maxf(1.5, teto(xm + s * 3.6) - rng.randf_range(0.5, 5.0 + i * 3.0))
			_caixa(raiz, corpo, Vector3(7.5, h, 1.0), Transform3D(Basis.IDENTITY, aqui(xm, h * 0.5 - 0.3, MZ - 0.4)), _mat(CONCRETO.darkened(0.4 + rng.randf_range(0.0, 0.12)), 0.3, 0.4))
			for fiada in int(h / 6.0) + 1:
				if fiada * 6.0 > h - 1.0:
					break
				var inteiro := (fiada + 1) * 6.0 <= h
				for face: float in [-1.0, 1.0]:
					_megakit(raiz, (["WallAstra_Straight", "WallBand_Straight"][rng.randi() % 2]) if inteiro else (["WallAstra_Straight_Broken", "WallBand_Straight_Broken"][rng.randi() % 2]),
						Transform3D(Basis(Vector3.UP, PI * 0.5 * face).scaled(Vector3(1.9, 2.0, 1.9)), aqui(xm, fiada * 6.0, MZ - 0.4 + face * 0.75)), 0.22 + rng.randf() * 0.18, 0.3 + rng.randf() * 0.3)
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
		LuzesNoite.por(raiz, pc + Vector3(1.1, 24.6, 0), LuzesNoite.BRASA, 7.0)  # a brasa na boca da chaminé, de noite
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
	# a luz de serviço: quatro luzes brancas e largas sobre o chão de luta, sem sombra, para os robôs se lerem
	# de longe (antes o meio ficava num verde-amarelado escuro, só com as lâmpadas fracas e o sol do rombo)
	for dados in [[-15.0, -15.0], [15.0, -15.0], [-15.0, 15.0], [15.0, 15.0]]:
		var servico := OmniLight3D.new()
		servico.light_color = Color(0.93, 0.95, 1.0)
		servico.light_energy = 0.75
		servico.omni_range = 30.0
		servico.omni_attenuation = 0.7
		servico.shadow_enabled = false
		servico.position = aqui(dados[0], 12.0, dados[1])
		raiz.add_child(servico)
	# as forjas, ainda acesas: três na parede oeste e duas na leste
	for z: float in [-22.0, 0.0, 22.0]:
		_forja(raiz, corpo, aqui(-MX + 12.0, 0, z), -PI * 0.5)
	for z: float in [-12.0, 14.0]:
		_forja(raiz, corpo, aqui(MX - 12.0, 0, z), PI * 0.5)
	# as duas brechas dos lados, no vão entre as forjas: um buraco escuro na parede do arco, com moldura de ferro
	# e a fila de lâmpadas em cima, virada para o meio
	for br: Vector2 in BRECHAS:
		var s := signf(br.x)
		_caixa(raiz, corpo, Vector3(0.4, BRECHA_ALT + 0.6, BRECHA_LARG + 0.4), Transform3D(Basis.IDENTITY, aqui(br.x + s * 1.3, (BRECHA_ALT + 0.6) * 0.5 - 0.1, br.y)), breu, false)
		for lado: float in [-1.0, 1.0]:
			_caixa(raiz, corpo, Vector3(1.0, BRECHA_ALT + 0.5, 0.8), Transform3D(Basis.IDENTITY, aqui(br.x + s * 0.6, (BRECHA_ALT + 0.5) * 0.5, br.y + lado * (BRECHA_LARG * 0.5 + 0.4))), ferro)
			# escombros do rombo no pé da moldura, do lado de fora do caminho
			_caixa(raiz, corpo, Vector3(1.4, 0.7, 1.1), Transform3D(Basis(Vector3.UP, 0.4 * lado), aqui(br.x - s * 0.4, 0.25, br.y + lado * (BRECHA_LARG * 0.5 + 1.5))), _mat(CONCRETO.darkened(0.1), 0.3, 0.4), false)
		_caixa(raiz, corpo, Vector3(1.2, 0.9, BRECHA_LARG + 1.6), Transform3D(Basis.IDENTITY, aqui(br.x + s * 0.6, BRECHA_ALT + 0.45, br.y)), ferro)
		var luz_b := OmniLight3D.new()
		luz_b.light_color = COR_ENTRADA
		luz_b.light_energy = 0.0
		luz_b.omni_range = 14.0
		luz_b.shadow_enabled = false
		luz_b.position = aqui(br.x - s * 2.5, 3.2, br.y)
		raiz.add_child(luz_b)
		# a fila enche da esquerda para a direita de quem olha de dentro, como as barras do HUD e a da porta
		entradas.append({"luz": luz_b, "lampadas": _fila_de_luzes(raiz, corpo, aqui(br.x - s * 0.05, BRECHA_ALT + 0.45, br.y), Vector3.BACK * s, BRECHA_LARG)})
	# proteção desenhada (reforma de 2026-11-20; antes eram paredes quebradas e escombros sorteados, cheios de
	# quinas onde os robôs se enroscavam): muretas retas em dois anéis em volta do meio, com vãos entre elas,
	# e uma barricada na frente da porta. O meio fica num círculo livre de uns 10 m
	for dados in MURETAS:
		var pm := Vector3(dados[0], 0.0, dados[1])
		_mureta(raiz, corpo, aqui(pm.x, 0, pm.z), dados[2], dados[3], dados[4])
	# escombros só encostados nas paredes, fora do chão de luta
	for dados in [[-27.0, -35.0, 1.5], [41.0, 33.0, 1.6], [-21.0, 35.5, 1.3]]:
		_escombros(raiz, corpo, rng, aqui(dados[0], 0, dados[1]), dados[2])
	# robôs velhos, tomados pelo tempo: caídos pelos cantos, apagados, longe dos caminhos
	var k := 0
	for dados in [[-44.0, -31.0, 0.8], [44.0, -27.0, 2.4], [44.0, 27.0, 4.0], [-44.0, 11.0, 1.5], [14.0, 34.5, 5.2], [-30.0, 34.0, 3.1]]:
		# robôs inimigos do próprio projeto (InimigoVisual), um de cada tipo comum, deitados de costas ou de bruços
		InimigoVisual.forcar_modelo = InimigoVisual.COMUNS[k % InimigoVisual.COMUNS.size()]
		var velho := InimigoVisual.montar(4400 + k * 13, 1.6, _tex)
		InimigoVisual.forcar_modelo = ""
		raiz.add_child(velho)
		velho.tocar("Death")
		velho._process(10.0)  # a pose de desligado já, e parada: a colisão é feita em cima dela
		velho.set_process(false)
		velho.apagar(1.0)
		velho.olho(0.0)
		velho.desbotar(0.8)
		var deita := -PI * 0.5 if k % 2 == 0 else PI * 0.5
		velho.transform = Transform3D(Basis(Vector3.UP, float(dados[2])) * Basis(Vector3.RIGHT, deita) * Basis(Vector3.BACK, 0.3 * sin(k * 2.1)), aqui(dados[0], 0.0, dados[1]))
		# assenta: a peça mais baixa encosta no piso
		var menor := INF
		for peca_v: PackedVector3Array in MalhaCorpo.por_peca(velho, null):
			for pv: Vector3 in peca_v:
				menor = minf(menor, pv.y)
		if menor != INF:
			velho.global_position.y += raiz.to_global(aqui(dados[0], 0.0, dados[1])).y + 0.01 - menor
		# um tufo de musgo ao lado (os robôs novos são finos: em cima, o tufo os escondia)
		_tufo(raiz, aqui(float(dados[0]) + 1.2, 0.05, float(dados[1]) - 1.0), 0.55)
		# a colisão segue o corpo caído, peça por peça, em cascos simples (são pequenos e não se mexem)
		for casco_v in MalhaCorpo.cascos(velho, null):
			corpo.add_child(casco_v)
			caidos_pecas += 1
		Obstaculos.registrar(aqui(dados[0], 0.0, dados[1]).x, aqui(dados[0], 0.0, dados[1]).z, 1.3)
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
	onda = 0


## O ponto está dentro do galpão (entre as paredes, do piso ao teto)?
static func dentro_do_galpao(p: Vector3) -> bool:
	return absf(p.x - CENTRO.x) < MX and absf(p.z - CENTRO.y) < MZ and p.y > PISO - 1.5 and p.y < PISO + ALT + 8.0


func _dist() -> float:
	var p := armadura.global_position
	return Vector2(p.x, p.z).distance_to(CENTRO)


## Quantos robôs a onda tem, quanto cada um aguenta e com que arma vem. Para a dificuldade subir aos
## poucos (pedido do usuário), as três primeiras ondas são só de ataque de perto (espada e martelo); da 4ª
## em diante entram os fuzis de um tiro, da 7ª os canhões e da 10ª os mísseis, sempre em minoria no começo.
## A cada 5, um minichefe com escolta menor. Só os nossos robôs (Mecha, `InimigoVisual`): o Stan, o Trilobite
## e o QuadShell saíram das ondas (pedido do usuário, 2026-11-20).
static func receita(numero: int) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var tema := tema_da_onda(numero)
	if tema >= 0:
		var tm: Dictionary = TEMAS[tema]
		for i in clampi(2 + numero + int(tm["mais"]), 3, 16):
			lista.append({"chefe": false, "resistencia": (1.0 + (numero - 1) * 0.1) * float(tm["forca"]), "semente": 9000 + numero * 37 + i,
				"arma": tm["arma"], "modelo": tm["modelo"]})
		return lista
	var chefe := numero % CHEFE_A_CADA == 0
	var quantos := mini(2 + numero, 14)
	if chefe:
		quantos = 2 + int(numero / CHEFE_A_CADA)
		# os minichefes se revezam: o Canhoneiro (dois tiros de canhão, de longe) nas ondas 5, 20, 35...; o
		# Capataz (lâmina, pula e esquiva) nas 10, 25...; o Guardião (atira de longe e bate de perto) nas 15, 30...
		lista.append({"chefe": true, "resistencia": 1.0 + numero / float(CHEFE_A_CADA) * 0.5, "semente": 9100 + numero,
			"arma": arma_do_chefe(numero)})
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


## Os pontos livres (no lugar) para onde os robôs da porta se espalham, fora das muretas.
const SAIDAS_PORTA := [Vector2(-20.0, -28.0), Vector2(-6.0, -21.0), Vector2(6.0, -21.0), Vector2(20.0, -28.0), Vector2(0.0, -19.0)]

## As ondas com tema, da 6ª em diante, de três em três (sem ser a do minichefe): todos do mesmo robô. As
## lâminas vêm em bando, os batedores em rajada e as couraças em poucas, lentas e duras.
const TEMAS := [
	{"nome": "lâminas", "modelo": "espadachim", "arma": "corpo", "mais": 2, "forca": 0.85},
	{"nome": "batedores", "modelo": "batedor", "arma": "bala", "mais": 1, "forca": 0.85},
	{"nome": "couraças", "modelo": "couraca", "arma": "pesado", "mais": -5, "forca": 1.25},
]


## O tema da onda (índice em TEMAS), ou -1 para uma onda misturada.
static func tema_da_onda(numero: int) -> int:
	if numero < 6 or numero % 3 != 0 or numero % CHEFE_A_CADA == 0:
		return -1
	return posmod(int(numero / 3) - 2, TEMAS.size())


## O respiro depois da onda: curto nas três primeiras (6 s, para engatar logo), 10 s no meio e 15 s antes e
## depois de um minichefe, para fabricar, pegar as caixas e se ajeitar.
static func respiro_de(numero: int) -> float:
	if (numero + 1) % CHEFE_A_CADA == 0 or numero % CHEFE_A_CADA == 0:
		return T_RESPIRO
	return 6.0 if numero <= 3 else 10.0


## A arma do minichefe da onda: "pesado" (Canhoneiro), "corpo" (Capataz) e "bala" (Guardião), em roda.
static func arma_do_chefe(numero: int) -> String:
	return ["pesado", "corpo", "bala"][posmod(int(numero / CHEFE_A_CADA) - 1, 3)]


static func nome_do_chefe(numero: int) -> String:
	return String(InimigoVisual.NOMES[InimigoVisual.POR_ARMA[arma_do_chefe(numero)][1]])


func ligar() -> void:
	if fase != Fase.PARADA or armadura.em_pane:
		return
	conta = {"xp": 0, "vencidos": 0, "ondas": 0, "recorde_antes": Arsenal.recorde}
	if hud:
		hud.resumo_t = 0.0
	onda = 1  # toda horda começa da onda 1 (pedido do usuário, 2026-11-20)
	fase = Fase.CONTAGEM
	_t = T_CONTAGEM
	if hud:
		hud.dica = ""
		hud.avisar("Eles estão vindo", "onda %d em %d s" % [onda, int(T_CONTAGEM)])
	if sons:
		sons._toque("onda_comeca", -5.0, 0.0)


func _comecar_onda() -> void:
	fase = Fase.ONDA
	_fila = receita(onda)
	_solta_t = 0.0
	_abrindo = [0.0, 0.0, 0.0]
	_aberta = [0.0, 0.0, 0.0]
	chefe_vivo = null
	if onda % CHEFE_A_CADA == 0:
		# o minichefe é anunciado: buzina, a luz da porta pulsa, o chão treme, e só então ele sai
		_chefe_t = T_AVISO_CHEFE
		if sons:
			sons._toque("chefe_aviso", -2.0, 0.0)
			sons._toque("porta_abre", -4.0, 0.0)
	if hud:
		var sub := "%d robôs vindo da porta" % _fila.size()
		if onda % CHEFE_A_CADA == 0:
			sub = "minichefe: %s" % nome_do_chefe(onda)
		elif tema_da_onda(onda) >= 0:
			sub = "%d %s · pela porta e pelas brechas" % [_fila.size(), TEMAS[tema_da_onda(onda)]["nome"]]
		elif onda >= 3:
			sub = "%d robôs · pela porta e pelas brechas" % _fila.size()
		hud.avisar("Onda %d" % onda, sub)


## Por onde sai o próximo robô: o minichefe e as duas primeiras ondas pela porta; da 3ª em diante os comuns se
## revezam em pares entre a porta e as duas brechas, e o jogador precisa olhar para os lados também.
func _entrada_de(dados: Dictionary) -> int:
	if dados["chefe"] or onda < 3:
		return 0
	return int(_portao / 2) % 3


func _soltar(dados: Dictionary, entrada := 0) -> void:
	var chefe: bool = dados["chefe"]
	_portao += 1
	var de := Vector3.ZERO
	var guia := Vector3.ZERO
	var espalha := Vector3.ZERO
	if entrada == 0:
		# pela porta: nascem no breu atrás dela, em fila, andam reto até passar da fresta e então se abrem em
		# leque, cada um para um ponto livre diferente (saindo todos em fila reta, uma arma de tiro rápido
		# pegava a fila inteira)
		de = aqui(0.0, 0.2, -MZ - 5.0 - (_portao % 4) * 3.2)
		guia = aqui(randf_range(-1.0, 1.0), 0.0, -MZ + 4.5)
		var sp: Vector2 = SAIDAS_PORTA[_portao % SAIDAS_PORTA.size()]
		espalha = aqui(sp.x + randf_range(-1.5, 1.5), 0.0, sp.y + randf_range(-1.5, 1.5))
	else:
		# por uma brecha: saem do buraco escuro, atravessam o vão entre as forjas e se espalham na boca dele
		var br: Vector2 = BRECHAS[entrada - 1]
		var s := signf(br.x)
		de = aqui(br.x - s * 0.3, 0.2, br.y + randf_range(-1.6, 1.6))
		guia = aqui(br.x - s * 10.0, 0.0, br.y + randf_range(-1.2, 1.2))
		espalha = aqui(s * randf_range(16.0, 21.0), 0.0, br.y + randf_range(-4.0, 4.0))
	var mc := Mecha.new()
	mc.arma_forcada = dados["arma"]
	mc.modelo_forcado = String(dados.get("modelo", ""))
	mc.mapa = mapa
	mc.alvo = armadura
	# a "casa" é um ponto perto do meio: dali eles já enxergam o robô em quase todo o galpão
	mc.casa = Vector3(CENTRO.x, PISO, CENTRO.y) + (de - Vector3(CENTRO.x, PISO, CENTRO.y)).normalized() * 16.0
	mc.semente = dados["semente"]
	mc.chefe = chefe
	mc.resistencia = dados["resistencia"]
	add_child(mc)
	mc.global_position = de
	mc.guiado = guia
	mc.set_meta("espalha", espalha)
	vivos.append(mc)
	if chefe:
		chefe_vivo = mc
		if hud:
			hud.chefe_nome = nome_do_chefe(onda)


## Uma caixa sai da forja pela esteira (as forjas ainda fabricam): "municao" enche as granadas e os mísseis,
## "conserto" apaga os acertos que o robô levou. Rola até a ponta, cai no chão e espera ser pega.
func soltar_caixa(tipo: String) -> void:
	if esteiras.is_empty():
		return
	var e: Array = esteiras[_caixa_n % esteiras.size()]
	_caixa_n += 1
	var cor := Color(1.0, 0.62, 0.3) if tipo == "municao" else Color(0.4, 1.0, 0.55)
	var no := _kit(self, "box-small", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.5), e[0]), Color(0.9, 0.88, 0.82), 0.1, 0.0)
	var faixa := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.64, 0.12, 0.54)
	faixa.mesh = bm
	faixa.material_override = _luz(cor, 3.0)
	faixa.position = Vector3(0, 0.3, 0)
	no.add_child(faixa)
	# a marca: uma cruz para o conserto, um losango para a munição
	for i in 2:
		var marca := MeshInstance3D.new()
		var mm := BoxMesh.new()
		mm.size = Vector3(0.3, 0.02, 0.09)
		marca.mesh = mm
		marca.material_override = _luz(cor, 3.0)
		marca.position = Vector3(0, 0.56, 0)
		marca.rotation.y = (PI * 0.5 * i) if tipo == "conserto" else (PI * 0.25 + PI * 0.5 * i)
		no.add_child(marca)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.4
	luz.omni_range = 6.0
	luz.position = Vector3(0, 0.6, 0)
	no.add_child(luz)
	_caixas.append({"no": no, "tipo": tipo, "t": 0.0, "e": e})
	caixas_soltas += 1
	Som.toque3d(self, "caixa_sai", e[0], 2.0, 14.0, 120.0)
	if hud:
		hud.avisar("Caixa de munição" if tipo == "municao" else "Caixa de conserto", "saindo de uma forja")


func _andar_caixas(delta: float) -> void:
	for cx in _caixas.duplicate():
		cx["t"] += delta
		var no := cx["no"] as Node3D
		var e: Array = cx["e"]
		var t: float = cx["t"]
		if t < 4.0:
			no.global_position = (e[0] as Vector3).lerp(e[1], t / 4.0)
		elif t < 4.6:
			var f := (t - 4.0) / 0.6
			no.global_position = (e[1] as Vector3).lerp(e[2], f) + Vector3(0, sin(f * PI) * 0.5, 0)
		else:
			no.global_position = e[2]
			no.rotation.y += delta * 0.8
		var perto := armadura.pos_suave().distance_to(no.global_position) < 1.5 + armadura.altura_corpo() * 0.4
		if perto and not armadura.em_pane:
			if cx["tipo"] == "municao":
				Arsenal.repor_granadas()
				if hud:
					hud.avisar("Munição reposta", "granadas %d · mísseis %d" % [Arsenal.granadas, Arsenal.misseis])
			else:
				armadura.avaria = 0
				armadura.set("_dano_frac", 0.0)
				armadura.escudo_t = 0.0
				armadura.escudo_cargas = Arsenal.ESCUDO_CARGAS
				if hud:
					hud.avisar("Robô consertado", "os acertos foram apagados")
			caixas_pegas += 1
			if sons:
				sons._toque("caixa_pega", -3.0, 0.0)
			no.queue_free()
			_caixas.erase(cx)
		elif t > 90.0:
			no.queue_free()
			_caixas.erase(cx)


func _recompensa(mc: Vigia) -> void:
	vencidos_total += 1
	var xp := roundi((80.0 if mc.chefe else 10.0) * (1.0 + onda * 0.15))
	var nivel_antes := Arsenal.nivel()
	Arsenal.xp += xp
	conta["xp"] += xp
	conta["vencidos"] += 1
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
	if Arsenal.nivel() > nivel_antes:
		subidas += 1
		EfeitosTiro.aura_nivel(armadura, armadura.altura_corpo())
		if hud:
			hud.avisar("Nível %d" % Arsenal.nivel(), "novas fabricações na base")
		if sons:
			sons._toque("nivel", -2.0, 0.0)
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


func _parar(motivo: String, sub := "", perdeu := {}) -> void:
	# o resumo da rodada: até onde foi, o recorde e o que levou (só se chegou a lutar)
	if hud and motivo != "" and (int(conta["vencidos"]) > 0 or int(conta["ondas"]) > 0):
		var novo: bool = Arsenal.recorde > int(conta["recorde_antes"])
		var mats := "sucata +%d · núcleos +%d · chips +%d" % [int(rodada["sucata"]) - int(perdeu.get("sucata", 0)), int(rodada["nucleos"]) - int(perdeu.get("nucleos", 0)), int(rodada["chips"]) - int(perdeu.get("chips", 0))]
		var linhas := [
			["Ondas vencidas", str(int(conta["ondas"]))],
			["Recorde", "onda %d" % Arsenal.recorde + (" · novo" if novo else "")],
			["Robôs desligados", str(int(conta["vencidos"]))],
			["Experiência", "+%d · nível %d" % [int(conta["xp"]), Arsenal.nivel()]],
			["Materiais" + (" (metade ficou lá)" if not perdeu.is_empty() else ""), mats],
			["Recomeça na", "onda 1"],
		]
		hud.mostrar_resumo(motivo, linhas, Arsenal.recorde > int(conta["recorde_antes"]))
		motivo = ""
	for cx in _caixas:
		(cx["no"] as Node3D).queue_free()
	_caixas.clear()
	onda = 0  # a próxima horda começa da onda 1, tenha saído ou perdido
	_abrindo = [0.0, 0.0, 0.0]
	_aberta = [0.0, 0.0, 0.0]
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
	# a luz da porta: calma em paz, pulsando forte enquanto o minichefe é anunciado
	if luz_porta:
		luz_porta.light_energy = (4.0 + 5.0 * absf(sin(agora * 9.0))) if _chefe_t > 0.0 else 2.4
	_luzes_das_entradas(agora)
	# a barra de vida do minichefe (o quanto falta para ele desligar)
	if hud:
		if chefe_vivo and is_instance_valid(chefe_vivo) and not chefe_vivo.desligada and fase == Fase.ONDA:
			hud.chefe_vida = 1.0 - chefe_vivo.calor / 100.0
		else:
			hud.chefe_vida = -1.0
	_andar_caixas(delta)
	var d := _dist()
	if fase == Fase.PARADA:
		# Não há mais botão para ligar (pedido do usuário, 2026-11-20). Quem entra no galpão recebe um aviso,
		# sem parar o jogo; ficando mais de 18 s lá dentro (eram 30), os robôs hostis começam a vir e a horda
		# começa. Sair zera a contagem.
		var la_dentro := dentro_do_galpao(armadura.global_position) and not armadura.em_pane and not armadura.travado
		if la_dentro:
			if perigo_t <= 0.0 or perigo_t > T_PERIGO:
				perigo_t = T_PERIGO
				_perigo_meio = false
				avisos_perigo += 1
				if hud:
					hud.avisar("Lugar perigoso", "se ficar mais de %d segundos aqui, robôs hostis começam a vir" % int(T_PERIGO))
				if sons:
					sons._toque("chefe_aviso", -10.0, 0.0)
			perigo_t -= delta
			if not _perigo_meio and perigo_t < 10.0:
				_perigo_meio = true
				if hud:
					hud.avisar("Eles estão acordando", "saia em 10 segundos ou prepare-se")
			if perigo_t <= 0.0:
				perigo_t = T_PERIGO + 1.0  # se a rodada acabar com o robô ainda aqui, avisa e conta de novo
				ligar()
		else:
			perigo_t = T_PERIGO + 1.0
		if hud:
			hud.perigo = (T_PERIGO - perigo_t) / T_PERIGO if fase == Fase.PARADA and perigo_t <= T_PERIGO else -1.0
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
		if sons:
			sons._toque("perdeu", -3.0, 0.0)
		_parar("A Fundição venceu desta vez", "metade dos materiais da rodada ficou lá", perdeu)
		return
	if d > SAIU:
		# saiu no meio da horda: ela zera e, na volta, começa da onda 1 de novo
		_parar("Fundição desligada", "você saiu da cratera; a horda recomeça na onda 1")
		return
	match fase:
		Fase.CONTAGEM:
			_t -= delta
			if _t <= 0.0:
				_comecar_onda()
		Fase.ONDA:
			for mc in vivos.duplicate():
				if is_instance_valid(mc) and not mc.guiado.is_finite() and mc.has_meta("espalha"):
					mc.guiado = mc.get_meta("espalha")
					mc.remove_meta("espalha")
			for mc in vivos.duplicate():
				if not is_instance_valid(mc):
					vivos.erase(mc)
				elif mc.desligada:
					vivos.erase(mc)
					_recompensa(mc)
			# no meio da onda, de tempos em tempos, uma forja solta uma caixa: de conserto se o robô levou
			# acerto, senão de munição (se ele tiver o que repor)
			_caixa_t -= delta
			if _caixa_t <= 0.0:
				_caixa_t = 38.0
				if armadura.avaria > 0:
					soltar_caixa("conserto")
				elif Arsenal.granadas < Arsenal.granadas_max() or Arsenal.misseis < Arsenal.misseis_max():
					soltar_caixa("municao")
			if _chefe_t > 0.0:
				_chefe_t -= delta
				armadura.tremor = maxf(armadura.tremor, 0.18)
				_solta_t = 0.2
			_solta_t -= delta
			if not _fila.is_empty() and vivos.size() < ATIVOS and _solta_t <= 0.0:
				var ent := _entrada_de(_fila.front())
				if ent > 0 and _aberta[ent] <= 0.0:
					# a brecha ainda fechada: as lâmpadas dela piscam e a luz pulsa por um tempo; só então sai o
					# robô (o jogador vê de onde ele vem antes de ele aparecer)
					if _abrindo[ent] <= 0.0:
						_abrindo[ent] = T_ABRE_BRECHA
						var br: Vector2 = BRECHAS[ent - 1]
						Som.toque3d(self, "porta_abre", aqui(br.x, 2.0, br.y), -1.0, 20.0, 110.0)
				else:
					_soltar(_fila.pop_front(), ent)
					saidas[ent] += 1
					_aberta[ent] = 5.0
					# as três primeiras ondas soltam os robôs mais juntos: curtas e rápidas
					_solta_t = 0.6 if onda <= 3 else 1.1
			for k in 3:
				if _abrindo[k] > 0.0:
					_abrindo[k] -= delta
					if _abrindo[k] <= 0.0:
						_aberta[k] = 5.0
				elif _aberta[k] > 0.0:
					_aberta[k] -= delta
			if _fila.is_empty() and vivos.is_empty():
				_vencer_onda()
		Fase.RESPIRO:
			_t -= delta
			if _t <= 0.0:
				onda += 1
				_comecar_onda()
	if hud and fase != Fase.PARADA:
		hud.perigo = -1.0
		hud.placar_total = 0
		hud.placar2 = ""
		match fase:
			Fase.CONTAGEM:
				hud.placar = "Onda %d em %d" % [onda, ceili(_t)]
			Fase.ONDA:
				hud.placar = "Onda %d" % onda
				hud.placar_total = receita(onda).size()
				hud.placar_restam = vivos.size() + _fila.size()
			Fase.RESPIRO:
				hud.placar = "Onda %d em %d" % [onda + 1, ceili(_t)]
				var b := Arsenal.barra()
				hud.placar2 = "nível %d (%d de %d)   sucata %d   núcleos %d   chips %d" % [Arsenal.nivel(), b.x, b.y, Arsenal.sucata, Arsenal.nucleos, Arsenal.chips]


## As lâmpadas das entradas (o aviso por figura, para quem não lê). Parado, com o robô lá dentro: enchem uma
## a uma até a horda começar, a próxima piscando. Na contagem, piscam todas. Nas ondas a fila da porta fica
## acesa; a brecha que vai abrir pisca e a luz dela pulsa, e fica acesa enquanto solta robôs.
func _luzes_das_entradas(agora: float) -> void:
	var pisca := 0.5 + 0.5 * sin(agora * 14.0)
	var cheias := -1.0
	if fase == Fase.PARADA and perigo_t <= T_PERIGO:
		cheias = (T_PERIGO - perigo_t) / T_PERIGO * LUZES_FILA
	for k in entradas.size():
		var lamps: Array = entradas[k]["lampadas"]
		for i in lamps.size():
			var f := 0.0
			match fase:
				Fase.PARADA:
					if cheias >= 0.0:
						f = 1.0 if i < floori(cheias) else (pisca if i == floori(cheias) else 0.0)
				Fase.CONTAGEM:
					f = pisca
				_:
					if k == 0:
						f = 0.8
					elif _abrindo[k] > 0.0:
						f = pisca
					elif _aberta[k] > 0.0:
						f = 1.0
			acender(lamps[i], f)
		var luz_e = entradas[k]["luz"]
		if luz_e is OmniLight3D:
			var forca := 0.0
			if cheias >= 0.0:
				forca = cheias / LUZES_FILA * 1.5
			elif fase == Fase.CONTAGEM:
				forca = 2.5 * pisca
			elif _abrindo[k] > 0.0:
				forca = 1.0 + 2.6 * pisca
			elif _aberta[k] > 0.0:
				forca = 1.6
			(luz_e as OmniLight3D).light_energy = forca


func _vencer_onda() -> void:
	Arsenal.recorde = maxi(Arsenal.recorde, onda)
	conta["ondas"] += 1
	# no respiro as forjas mandam o que faltar: munição, e conserto se o robô levou acerto
	if Arsenal.granadas < Arsenal.granadas_max() or Arsenal.misseis < Arsenal.misseis_max():
		soltar_caixa("municao")
	if armadura.avaria > 0:
		soltar_caixa("conserto")
	var chefe := onda % CHEFE_A_CADA == 0
	Arsenal.guardar()
	fase = Fase.RESPIRO
	_t = respiro_de(onda)
	_abrindo = [0.0, 0.0, 0.0]
	_aberta = [0.0, 0.0, 0.0]
	if hud:
		hud.avisar("Onda %d vencida" % onda, ("minichefe desligado · respiro de %d s" if chefe else "respiro de %d s") % int(_t))
	if sons:
		sons._toque("chefe_cai" if chefe else "onda_vencida", -3.0, 0.0)
	onda_vencida.emit(onda)
