class_name InteriorCilindro
extends Node3D
## RASCUNHO (2026-11-22, pedido do usuário, para uma proposta): o lado de dentro do cilindro de melhorias.
## A ideia: o cilindro ficou fechado todos esses anos, então por fora enferrujou e por dentro se conservou.
## Por dentro ele é uma sala técnica limpa (forro de painéis claros, costelas grafite, faixas de luz, piso de
## grade, a vedação preta da boca separando o ferrugem de fora do limpo de dentro) e o robô fica num berço de
## montagem: um prato giratório com presilhas nos tornozelos, o aro de leitura, dois cabos presos nas costas,
## três braços de ferramenta num trilho do teto, nichos com peças de reposição e, no fundo, a tela redonda com a
## planta do robô. Na pose de oficina as juntas do robô ficam marcadas por anéis de luz e, instalando, as peças
## se afastam um pouco umas das outras (vista explodida): ele pode ser desmontado e montado de novo ali.
## Só entra no lugar do interior antigo com `ativo` ligado (as fotos do rascunho ligam); o jogo segue igual.
## Medidas no lugar do cilindro: X ao longo do eixo (+X é a boca), Y para cima, o centro do tubo na origem.

static var ativo := true
static var atual: InteriorCilindro

const R := 2.04  # apótema do forro (o tubo antigo tem 2,1 por dentro)
const LADOS := 16
const X0 := -2.96  # o fundo
const X1 := 3.04  # a boca
const PISO := -1.605  # o alto da grade do piso
const PARADA := Vector3(0.9, -1.59, 0.0)  # onde o robô fica (BaseVale.MEIO_CIL - Oficina.FUNDO, no estrado)
const TRECHOS := 8  # vãos entre as costelas
const BRANCO := Color(0.6, 0.64, 0.67)
const BRANCO2 := Color(0.5, 0.55, 0.58)
const RODAPE := Color(0.29, 0.33, 0.36)  # os painéis de baixo, junto do piso
const GRAFITE := Color(0.13, 0.15, 0.17)
const GRADE := Color(0.22, 0.25, 0.27)
const AGUA := Color(0.35, 0.95, 0.85)
const LARANJA := Color(1.0, 0.62, 0.3)
const LUZ_BRANCA := Color(0.92, 0.97, 1.0)

var _mats := {}
var _bracos: Array[Dictionary] = []
var _aro: Node3D
var _aro_luz: MeshInstance3D
var _tela_mat: ShaderMaterial
var _presos: Array[Node] = []  # o que vai junto do robô (presilhas, cabos, anéis das juntas): some ao soltar
var _solda: OmniLight3D
var _foco: SpotLight3D
var _fria: OmniLight3D
var _preso: ArmaduraVisual  # o robô no berço
var _discos := {}  # junta -> anel de luz do encaixe
var _presilhas: Array[Node3D] = []
var _cabos: Array[MeshInstance3D] = []
var _bocais: Array[Node3D] = []
var _costas_antes := Vector3.INF
var _mat_disco: StandardMaterial3D
var _prato: Node3D  # as placas dos pés, que giram com o robô
var _aberto := 0.0  # o último `abrir` (as peças afastadas também erguem o corpo)
var _paira := 0.0  # 0 no estrado, 1 no ar (a aba Jatos, doc §147)
var _paira_alvo := 0.0


func _exit_tree() -> void:
	if atual == self:
		atual = null


static func montar(pai: Node3D, xf: Transform3D) -> InteriorCilindro:
	var n := InteriorCilindro.new()
	n.name = "InteriorCilindro"
	pai.add_child(n)
	n.global_transform = xf
	n._construir()
	atual = n
	n._recortar_chao.call_deferred(pai)
	return n


## O terreno da clareira sobe acima do piso no fundo do tubo (parecia terra lá dentro): o chão deixa de ser
## desenhado dentro do cilindro (`recorte` no vale_chao.gdshader). O casco cobre a borda do recorte por fora.
func _recortar_chao(vale: Node) -> void:
	var feitos := {}
	for mi in vale.find_children("*", "MeshInstance3D", false, false):
		var malha := (mi as MeshInstance3D).mesh
		if malha == null or malha.get_surface_count() == 0:
			continue
		var mat := malha.surface_get_material(0) as ShaderMaterial
		if mat == null or mat.shader == null or not mat.shader.resource_path.ends_with("vale_chao.gdshader") or feitos.has(mat):
			continue
		feitos[mat] = true
		mat.set_shader_parameter("recorte_ativo", 1.0)
		mat.set_shader_parameter("recorte_para_local", Projection(global_transform.affine_inverse()))
		mat.set_shader_parameter("recorte_meio", Vector2(BaseVale.MEIO_CIL - 0.05, BaseVale.R_CIL - 0.05))
	print("recorte do chão em ", feitos.size(), " material(is)")


# ------------------------------------------------------------------ materiais e peças simples

func _mat(cor: Color, borda := 0.18) -> ShaderMaterial:
	var k := "s" + cor.to_html() + str(borda)
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/shaders/vale_solido.gdshader")
		m.set_shader_parameter("cor", cor)
		m.set_shader_parameter("brilho_borda", borda)
		_mats[k] = m
	return _mats[k]


func _luz(cor: Color, forca := 2.0) -> StandardMaterial3D:
	var k := "l" + cor.to_html() + str(forca)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = forca
		_mats[k] = m
	return _mats[k]


func _vidro() -> StandardMaterial3D:
	if not _mats.has("vidro"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.9, 0.95, 0.12)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic_specular = 0.9
		m.roughness = 0.05
		_mats["vidro"] = m
	return _mats["vidro"]


func _caixa(pai: Node3D, centro: Vector3, tam: Vector3, mat: Material, giro := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = Transform3D(giro, centro)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


func _cil(pai: Node3D, centro: Vector3, raio: float, alto: float, mat: Material, giro := Basis.IDENTITY, raio_topo := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = raio
	cm.top_radius = raio if raio_topo < 0.0 else raio_topo
	cm.height = alto
	cm.radial_segments = 20
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.transform = Transform3D(giro, centro)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


func _anel(pai: Node3D, centro: Vector3, r_dentro: float, r_fora: float, mat: Material, giro := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r_dentro
	tm.outer_radius = r_fora
	tm.rings = 48
	tm.ring_segments = 10
	mi.mesh = tm
	mi.material_override = mat
	mi.transform = Transform3D(giro, centro)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


## Um cilindro de `a` até `b` (o eixo Y da malha vai de um ao outro).
func _entre(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var comp := maxf(d.length(), 0.001)
	var y := d / comp
	var x := y.cross(Vector3(0.31, 0.2, 0.93)).normalized()
	mi.transform = Transform3D(Basis(x, y * comp, x.cross(y)), (a + b) * 0.5)


## Uma base que leva o Y para `dir` (para discos e ferramentas).
static func _apontar(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3(0.31, 0.2, 0.93)).normalized()
	return Basis(x, y, x.cross(y))


# ------------------------------------------------------------------ o forro: painéis, costelas, luzes

## O ponto do polígono do forro: o ângulo conta a partir de baixo (0 é o chão, PI o teto).
static func _ponto(x: float, ang: float, r: float) -> Vector3:
	return Vector3(x, -cos(ang) * r, sin(ang) * r)


func _construir() -> void:
	_solda = OmniLight3D.new()
	_solda.light_color = AGUA
	_solda.light_energy = 0.0
	_solda.omni_range = 2.0
	add_child(_solda)
	var passo := TAU / LADOS
	var rv := R / cos(passo * 0.5)  # raio dos cantos
	var largura := (X1 - X0) / TRECHOS
	var claro := SurfaceTool.new()
	claro.begin(Mesh.PRIMITIVE_TRIANGLES)
	var claro2 := SurfaceTool.new()
	claro2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fundo := SurfaceTool.new()
	fundo.begin(Mesh.PRIMITIVE_TRIANGLES)
	var baixo := SurfaceTool.new()
	baixo.begin(Mesh.PRIMITIVE_TRIANGLES)
	baixo.set_smooth_group(-1)
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 7
	for s in [claro, claro2]:
		s.set_smooth_group(-1)
	for k in LADOS:
		var a0 := (k - 0.5) * passo
		var a1 := (k + 0.5) * passo
		# o fundo escuro atrás dos painéis (aparece nas juntas)
		_quad(fundo, _ponto(X0, a0, rv + 0.03), _ponto(X1, a0, rv + 0.03), _ponto(X1, a1, rv + 0.03), _ponto(X0, a1, rv + 0.03))
		if k == 0 or k == 1 or k == LADOS - 1:
			continue  # debaixo do piso
		for t in TRECHOS:
			var xa := X0 + t * largura + 0.07
			var xb := X0 + (t + 1) * largura - 0.07
			# painel com folga de 2,5 cm nas beiradas: a junta escura entre um e outro
			var enc := 0.025 / rv
			var st := claro2 if sorte.randf() < 0.22 else claro
			if k == 2 or k == 3 or k == LADOS - 2 or k == LADOS - 3:
				st = baixo
			_quad(st, _ponto(xa, a0 + enc, rv - 0.002), _ponto(xb, a0 + enc, rv - 0.002), _ponto(xb, a1 - enc, rv - 0.002), _ponto(xa, a1 - enc, rv - 0.002))
	for par in [[claro, BRANCO], [claro2, BRANCO2], [baixo, RODAPE], [fundo, GRAFITE]]:
		var s: SurfaceTool = par[0]
		s.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = s.commit()
		mi.material_override = _mat(par[1], 0.1)
		# o casco antigo deixava o sol passar (as manchas alaranjadas de dentro): o forro faz sombra dos dois lados
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		add_child(mi)
	# as costelas: anéis de 16 lados, grafite, com uma luzinha laranja em cada uma, perto do piso
	var cost := SurfaceTool.new()
	cost.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in TRECHOS + 1:
		var x := X0 + t * largura
		var meia := 0.06
		var ri := rv - 0.11
		for k in LADOS:
			var a0 := (k - 0.5) * passo
			var a1 := (k + 0.5) * passo
			_quad(cost, _ponto(x - meia, a0, ri), _ponto(x + meia, a0, ri), _ponto(x + meia, a1, ri), _ponto(x - meia, a1, ri))
			_quad(cost, _ponto(x + meia, a0, ri), _ponto(x + meia, a0, rv), _ponto(x + meia, a1, rv), _ponto(x + meia, a1, ri), Vector3.RIGHT)
			_quad(cost, _ponto(x - meia, a1, ri), _ponto(x - meia, a1, rv), _ponto(x - meia, a0, rv), _ponto(x - meia, a0, ri), Vector3.LEFT)
		if t > 0 and t < TRECHOS:
			for lado: float in [-1.0, 1.0]:
				_caixa(self, _ponto(x, 1.0 if lado > 0.0 else TAU - 1.0, ri - 0.012), Vector3(0.05, 0.03, 0.05), _luz(LARANJA, 1.6))
	cost.generate_normals()
	var mc := MeshInstance3D.new()
	mc.mesh = cost.commit()
	mc.material_override = _mat(GRAFITE, 0.25)
	add_child(mc)
	# luzes: no teto, uma placa branca por vão; nos dois lados de cima, uma faixa verde-água por vão
	for t in TRECHOS:
		var xm := X0 + (t + 0.5) * largura
		_caixa(self, Vector3(xm, R - 0.012, 0.0), Vector3(largura - 0.3, 0.02, 0.42), _luz(LUZ_BRANCA, 0.9))
		for lado: float in [-1.0, 1.0]:
			var ang := PI - 2.0 * passo  # o painel de cima do lado
			var p := _ponto(xm, ang, R - 0.012)
			p.z *= lado
			var nrm := -Vector3(0, p.y, p.z).normalized()
			_caixa(self, p, Vector3(largura - 0.3, 0.02, 0.06), _luz(AGUA, 1.3), Basis(Vector3.RIGHT, nrm, Vector3.RIGHT.cross(nrm)))
	_piso()
	_berco()
	_trilhos_e_bracos()
	_fundo_e_tela()
	_nichos()
	_boca()
	for lado: float in [-1.0, 1.0]:
		_letreiro("07", 2.3, lado)
	# a luz: um tom frio no tubo e uma luz de mesa de operação em cima do berço
	var amb := OmniLight3D.new()
	amb.light_color = Color(0.78, 0.95, 1.0)
	amb.light_energy = 0.55
	amb.omni_range = 6.5
	amb.position = Vector3(-0.6, 0.9, 0.0)
	add_child(amb)
	_fria = amb
	var foco := SpotLight3D.new()
	foco.light_color = Color(1.0, 0.95, 0.86)
	foco.light_energy = 1.6
	foco.spot_range = 4.6
	foco.spot_angle = 32.0
	foco.position = Vector3(PARADA.x, 1.85, 0.0)
	foco.rotation = Vector3(-PI * 0.5, 0, 0)
	add_child(foco)
	_foco = foco


## A oficina aberta (`f` 1) ou fechada (0), doc §161: lá dentro quem ilumina o robô é o sol de ateliê da oficina;
## o foco apaga e a luz fria fica só de fundo (as três se somavam no robô e lavavam as cores das peças).
func luz_oficina(f: float) -> void:
	if _foco:
		_foco.light_energy = lerpf(1.6, 0.0, f)
	if _fria:
		_fria.light_energy = lerpf(0.55, 0.15, f)


## Um quadrilátero com a frente para `frente` (sem ela, para o eixo do tubo). Na Godot a frente é a do giro
## horário, a mesma conta do `BaseVale._tubo`.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, frente := Vector3.ZERO) -> void:
	if frente == Vector3.ZERO:
		var meio := (a + b + c + d) * 0.25
		frente = -Vector3(0, meio.y, meio.z)
	var n := (c - a).cross(b - a)
	var ordem := [a, b, c, a, c, d] if n.dot(frente) > 0.0 else [a, c, b, a, d, c]
	for v in ordem:
		st.add_vertex(v)


## Um cabo do ponto `a` ao `b`, caído no meio (curva de três pontos), feito de tubo; `atras` puxa a barriga dele.
func _malha_cabo(a: Vector3, b: Vector3, raio: float, atras := Vector3(-1, 0, 0)) -> ArrayMesh:
	var meio := (a + b) * 0.5 + atras * 0.25 + Vector3(0.0, -0.35, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var lados := 8
	var aneis: Array = []
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(meio, t).lerp(meio.lerp(b, t), t)
		var tg := (2.0 * (1.0 - t) * (meio - a) + 2.0 * t * (b - meio)).normalized()
		var x := tg.cross(Vector3(0.31, 0.2, 0.93)).normalized()
		var y := tg.cross(x)
		var anel: Array = []
		for k in lados:
			var ang := TAU * k / lados
			anel.append(p + (x * cos(ang) + y * sin(ang)) * raio)
		aneis.append([anel, p])
	for i in n:
		var r0: Array = aneis[i][0]
		var r1: Array = aneis[i + 1][0]
		var c: Vector3 = aneis[i][1]
		for k in lados:
			var k2 := (k + 1) % lados
			_quad(st, r0[k], r1[k], r1[k2], r0[k2], (r0[k] + r1[k2]) * 0.5 - c)
	st.generate_normals()
	return st.commit()


## O número da oficina pintado na parede, de frente para quem está dentro.
func _letreiro(texto: String, x: float, lado: float) -> void:
	var ang := 5.0 * TAU / LADOS
	var p := _ponto(x, ang, R - 0.006)
	p.z *= lado
	var z := -Vector3(0, p.y, p.z).normalized()
	var xx := Vector3(-lado, 0, 0)
	var num := Label3D.new()
	num.text = texto
	num.font_size = 110
	num.pixel_size = 0.004
	num.modulate = Color(0.95, 0.72, 0.18)
	num.outline_size = 0
	num.transform = Transform3D(Basis(xx, z.cross(xx), z), p)
	add_child(num)


# ------------------------------------------------------------------ o piso e o berço

func _piso() -> void:
	var z_borda := R * sqrt(2.0) + PISO - 0.01  # onde o painel de baixo do lado encontra o piso
	var tam := 0.6
	var x := X0 + 0.04
	var linha := 0
	while x < X1 - 0.1:
		var z := -z_borda
		var col := 0
		while z < z_borda - 0.05:
			var w := minf(tam, z_borda - z)
			var c := Vector3(x + tam * 0.5, PISO - 0.015, z + w * 0.5)
			if Vector2(c.x - PARADA.x, c.z).length() > 0.78:
				_caixa(self, c, Vector3(tam - 0.025, 0.03, w - 0.025), _mat(GRADE if (linha + col) % 2 == 0 else GRADE.darkened(0.12), 0.12))
			z += tam
			col += 1
		x += tam
		linha += 1
	_caixa(self, Vector3((X0 + X1) * 0.5, PISO - 0.04, 0.0), Vector3(X1 - X0, 0.02, z_borda * 2.0), _mat(GRAFITE))
	# as luzes de pista nas beiradas do piso
	for lado: float in [-1.0, 1.0]:
		_caixa(self, Vector3((X0 + X1) * 0.5, PISO + 0.004, lado * (z_borda - 0.02)), Vector3(X1 - X0 - 0.2, 0.012, 0.035), _luz(AGUA, 1.0))
	# faixas de aviso na boca, no chão (amarelo e grafite)
	for i in 9:
		var zz := -1.05 + i * 0.26
		_caixa(self, Vector3(X1 - 0.18, PISO + 0.002, zz), Vector3(0.22, 0.008, 0.12), _mat(Color(0.95, 0.72, 0.18), 0.1), Basis(Vector3.UP, 0.6))


func _berco() -> void:
	# o prato giratório: grafite, com o anel de luz em volta e as duas placas dos pés
	_cil(self, Vector3(PARADA.x, PISO - 0.008, 0.0), 0.76, 0.03, _mat(GRAFITE, 0.3))
	_cil(self, Vector3(PARADA.x, PISO + 0.004, 0.0), 0.66, 0.02, _mat(Color(0.3, 0.33, 0.36), 0.2))
	_anel(self, Vector3(PARADA.x, PISO + 0.006, 0.0), 0.67, 0.72, _luz(AGUA, 1.4))
	_prato = Node3D.new()
	_prato.position = Vector3(PARADA.x, PISO, 0.0)
	add_child(_prato)
	for lado: float in [-1.0, 1.0]:
		_caixa(_prato, Vector3(0.0, 0.016, lado * 0.13), Vector3(0.3, 0.012, 0.16), _mat(GRAFITE))
		_caixa(_prato, Vector3(0.155, 0.018, lado * 0.13), Vector3(0.012, 0.012, 0.16), _luz(LARANJA, 2.0))
	# o aro de leitura: pendurado do teto por três hastes; parado, fica acima da cabeça
	_aro = Node3D.new()
	_aro.name = "AroDeLeitura"
	add_child(_aro)
	_anel(_aro, Vector3.ZERO, 0.55, 0.61, _mat(GRAFITE, 0.35))
	_aro_luz = _anel(_aro, Vector3(0, -0.03, 0), 0.545, 0.565, _luz(AGUA, 1.5))
	for k in 3:
		var a := TAU * k / 3.0
		var p := Vector3(cos(a) * 0.57, 0.0, sin(a) * 0.57)
		_caixa(_aro, p + Vector3(0, 0.05, 0), Vector3(0.09, 0.08, 0.09), _mat(GRAFITE))
		var haste := _cil(_aro, Vector3.ZERO, 0.018, 1.0, _mat(GRAFITE, 0.3))
		haste.set_meta("de", p)
		var bainha := _cil(_aro, Vector3.ZERO, 0.03, 1.0, _mat(BRANCO2, 0.3))
		bainha.set_meta("bainha", p)
	por_aro(0.0)


## O aro de leitura: 0 parado acima da cabeça, 1 descido na altura do peito (lendo).
func por_aro(f: float) -> void:
	var y := lerpf(-0.12, -1.28, f)
	_aro.position = Vector3(PARADA.x, y, 0.0)
	for c in _aro.get_children():
		var topo := R - 0.05 - y
		if c.has_meta("de"):
			var p: Vector3 = c.get_meta("de")
			_entre(c, p + Vector3(0, 0.08, 0), p + Vector3(0, topo * 0.55, 0))
		elif c.has_meta("bainha"):
			var p: Vector3 = c.get_meta("bainha")
			_entre(c, p + Vector3(0, topo * 0.5, 0), p + Vector3(0, topo, 0))


# ------------------------------------------------------------------ os braços de ferramenta no trilho do teto

const L1 := 1.45
const L2 := 1.35


func _trilhos_e_bracos() -> void:
	var y_trilho := R - 0.17
	for lado: float in [-1.0, 1.0]:
		_caixa(self, Vector3((X0 + X1) * 0.5 - 0.2, y_trilho, lado * 0.62), Vector3(X1 - X0 - 0.8, 0.1, 0.12), _mat(GRAFITE, 0.3))
		for i in 4:
			_caixa(self, Vector3(X0 + 0.6 + i * 1.6, y_trilho + 0.1, lado * 0.62), Vector3(0.06, 0.12, 0.06), _mat(GRAFITE))
	_caixa(self, Vector3(-0.55, y_trilho, 0.0), Vector3(0.14, 0.1, 1.24), _mat(GRAFITE, 0.3))
	# [base no trilho, para onde o cotovelo dobra, ferramenta]
	for dados in [[Vector3(0.2, y_trilho - 0.1, 0.62), Vector3(-0.5, 0.6, 0.8), "pinca"],
			[Vector3(0.2, y_trilho - 0.1, -0.62), Vector3(-0.5, 0.6, -0.8), "solda"],
			[Vector3(-0.55, y_trilho - 0.1, 0.0), Vector3(-1.0, 0.5, 0.0), "leitor"]]:
		var b := {"base": dados[0], "dobra": dados[1], "nos": {}}
		var nos: Dictionary = b["nos"]
		_caixa(self, dados[0] + Vector3(0, 0.04, 0), Vector3(0.34, 0.1, 0.22), _mat(BRANCO2, 0.3))
		nos["ombro"] = _cil(self, dados[0] + Vector3(0, -0.04, 0), 0.1, 0.12, _mat(GRAFITE, 0.3))
		nos["seg1"] = _cil(self, Vector3.ZERO, 0.055, 1.0, _mat(BRANCO2, 0.3))
		nos["seg2"] = _cil(self, Vector3.ZERO, 0.042, 1.0, _mat(GRAFITE.lightened(0.15), 0.3))
		nos["cotovelo"] = _cil(self, Vector3.ZERO, 0.085, 0.16, _mat(GRAFITE, 0.3))
		nos["tampa"] = _cil(self, Vector3.ZERO, 0.05, 0.172, _mat(LARANJA, 0.2))
		nos["punho"] = _cil(self, Vector3.ZERO, 0.05, 0.08, _mat(GRAFITE, 0.3))
		var ferr := Node3D.new()
		add_child(ferr)
		nos["ferramenta"] = ferr
		match dados[2]:
			"pinca":
				_caixa(ferr, Vector3(0, 0.03, 0), Vector3(0.12, 0.05, 0.12), _mat(GRAFITE))
				for k in 3:
					var a := TAU * k / 3.0
					_caixa(ferr, Vector3(cos(a) * 0.045, 0.1, sin(a) * 0.045), Vector3(0.025, 0.11, 0.03), _mat(BRANCO2), Basis(Vector3(-sin(a), 0, cos(a)), 0.3))
					_caixa(ferr, Vector3(cos(a) * 0.06, 0.16, sin(a) * 0.06), Vector3(0.028, 0.03, 0.032), _mat(LARANJA))
			"solda":
				_cil(ferr, Vector3(0, 0.07, 0), 0.045, 0.12, _mat(GRAFITE), Basis.IDENTITY, 0.012)
				var ponta := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.02
				sm.height = 0.04
				ponta.mesh = sm
				ponta.material_override = _luz(AGUA, 4.0)
				ponta.position = Vector3(0, 0.14, 0)
				ferr.add_child(ponta)
			"leitor":
				_cil(ferr, Vector3(0, 0.03, 0), 0.09, 0.04, _mat(GRAFITE))
				_cil(ferr, Vector3(0, 0.052, 0), 0.07, 0.006, _luz(AGUA, 2.6))
		b["tipo"] = dados[2]
		_bracos.append(b)
	por_bracos([])


## Põe os braços: sem alvos, recolhidos junto do trilho; com alvos (um ponto por braço, no lugar do cilindro),
## a ferramenta chega no ponto vinda de fora (`fora`: a direção de onde ela chega).
func por_bracos(alvos: Array, foras: Array = []) -> void:
	for i in _bracos.size():
		var b := _bracos[i]
		var base: Vector3 = (b["base"] as Vector3) + Vector3(0, -0.1, 0)
		var dobra: Vector3 = b["dobra"]
		var ponta: Vector3
		var fora: Vector3
		if i < alvos.size():
			fora = (foras[i] as Vector3).normalized() if i < foras.size() else Vector3.UP
			ponta = (alvos[i] as Vector3) + fora * 0.17
		else:
			ponta = base + Vector3(0.1, -0.5, 0.0)
			dobra = Vector3(-1.0, 0.35, 0.0)
		var d := ponta - base
		var dist := clampf(d.length(), 0.05, L1 + L2 - 0.02)
		var dn := d.normalized()
		ponta = base + dn * dist
		var ao_longo := (L1 * L1 - L2 * L2 + dist * dist) / (2.0 * dist)
		var alto := sqrt(maxf(0.0, L1 * L1 - ao_longo * ao_longo))
		var lado := (dobra - dn * dobra.dot(dn)).normalized()
		var cotovelo := base + dn * ao_longo + lado * alto
		var nos: Dictionary = b["nos"]
		_entre(nos["seg1"], base, cotovelo)
		_entre(nos["seg2"], cotovelo, ponta)
		var eixo := (cotovelo - base).cross(ponta - cotovelo).normalized()
		if eixo.length() < 0.5:
			eixo = Vector3.BACK
		(nos["cotovelo"] as Node3D).transform = Transform3D(_apontar(eixo), cotovelo)
		(nos["tampa"] as Node3D).transform = Transform3D(_apontar(eixo), cotovelo)
		var dir_f := (ponta - cotovelo).normalized()
		(nos["punho"] as Node3D).transform = Transform3D(_apontar(dir_f), ponta)
		(nos["ferramenta"] as Node3D).transform = Transform3D(_apontar(dir_f), ponta + dir_f * 0.03)
		if b["tipo"] == "solda":
			_solda.position = ponta + dir_f * 0.17


# ------------------------------------------------------------------ o fundo: a tela redonda com a planta do robô

const TELA := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 cor : source_color = vec4(0.35, 0.95, 0.85, 1.0);
uniform float abre = 0.0;
float caixa(vec2 p, vec2 c, vec2 m) { vec2 d = abs(p - c) - m; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
float linha(float d, float w) { return 1.0 - smoothstep(0.0, w, abs(d)); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float g = 0.0;
	vec2 gr = abs(fract(p * 7.0) - 0.5);
	g += (1.0 - smoothstep(0.0, 0.035, min(gr.x, gr.y))) * 0.1;
	g += linha(r - 0.94, 0.012) * 0.9 + linha(r - 0.86, 0.006) * 0.3;
	float ang = atan(p.y, p.x);
	g += smoothstep(0.82, 1.0, fract(ang / 6.2831853 - TIME * 0.12)) * 0.22 * step(r, 0.86);
	for (int i = 0; i < 24; i++) {
		float a = float(i) / 24.0 * 6.2831853;
		g += (1.0 - smoothstep(0.0, 0.02, length(p - vec2(cos(a), sin(a)) * 0.9))) * 0.8;
	}
	vec2 q = vec2(p.x, -p.y) * 1.25;
	float e = 0.09 * abre;
	float d = 1e3;
	d = min(d, caixa(q, vec2(0.0, 0.5 + e), vec2(0.17, 0.13)) - 0.04);
	d = min(d, caixa(q, vec2(0.0, 0.14), vec2(0.17, 0.17)) - 0.03);
	d = min(d, caixa(q, vec2(0.0, -0.1 - e * 0.5), vec2(0.12, 0.05)) - 0.02);
	d = min(d, caixa(q, vec2(0.3 + e, 0.12), vec2(0.055, 0.17)) - 0.02);
	d = min(d, caixa(q, vec2(-0.3 - e, 0.12), vec2(0.055, 0.17)) - 0.02);
	d = min(d, caixa(q, vec2(0.1 + e * 0.3, -0.42 - e), vec2(0.06, 0.24)) - 0.02);
	d = min(d, caixa(q, vec2(-0.1 - e * 0.3, -0.42 - e), vec2(0.06, 0.24)) - 0.02);
	g += linha(d, 0.012) * 1.0 + (1.0 - smoothstep(0.0, 0.01, d)) * 0.1;
	float cruz = min(linha(q.x, 0.004), step(abs(q.y), 0.75)) + min(linha(q.y - 0.14, 0.004), step(abs(q.x), 0.5));
	g += cruz * 0.18;
	ALBEDO = cor.rgb * g + vec3(0.01, 0.03, 0.035);
}
"""


func _fundo_e_tela() -> void:
	# a parede do fundo: um disco grafite, a moldura e a tela com a planta do robô
	var giro := Basis(Vector3.BACK, PI * 0.5)  # o Y da malha vira o X do tubo
	_cil(self, Vector3(X0 - 0.01, 0, 0), R / cos(PI / LADOS), 0.02, _mat(Color(0.2, 0.22, 0.24), 0.2), giro)
	_anel(self, Vector3(X0 + 0.04, 0.25, 0), 1.08, 1.22, _mat(BRANCO, 0.3), giro)
	_anel(self, Vector3(X0 + 0.05, 0.25, 0), 1.22, 1.27, _mat(GRAFITE, 0.3), giro)
	var tela := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.16, 2.16)
	tela.mesh = qm
	var sh := Shader.new()
	sh.code = TELA
	_tela_mat = ShaderMaterial.new()
	_tela_mat.shader = sh
	tela.material_override = _tela_mat
	tela.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(X0 + 0.03, 0.25, 0))
	add_child(tela)
	# luzinhas em volta da moldura
	for k in 16:
		var a := TAU * k / 16.0
		_caixa(self, Vector3(X0 + 0.08, 0.25 + cos(a) * 1.33, sin(a) * 1.33), Vector3(0.03, 0.05, 0.05), _luz(LARANJA if k % 4 == 0 else AGUA, 2.2))
	# os dois consoles inclinados debaixo da tela, com teclas acesas
	for lado: float in [-1.0, 1.0]:
		var c := Vector3(X0 + 0.42, PISO + 0.5, lado * 0.62)
		var g := Basis(Vector3.BACK, -0.55)
		_caixa(self, c + Vector3(-0.08, -0.25, 0), Vector3(0.45, 0.5, 0.7), _mat(BRANCO2, 0.25))
		_caixa(self, c, Vector3(0.5, 0.05, 0.72), _mat(GRAFITE, 0.25), g)
		for i in 4:
			for jj in 6:
				var tecla := c + g * Vector3(-0.15 + i * 0.1, 0.03, -0.27 + jj * 0.11)
				_caixa(self, tecla, Vector3(0.06, 0.012, 0.07), _luz(AGUA if (i + jj) % 5 else LARANJA, 1.2 + 0.6 * ((i * 7 + jj) % 3)), g)


## A planta na tela: 0 inteira, 1 com as peças afastadas (instalando).
func por_tela(abre: float) -> void:
	_tela_mat.set_shader_parameter("abre", abre)


# ------------------------------------------------------------------ os nichos com peças de reposição

func _nichos() -> void:
	var cena: PackedScene = load("res://assets/vale/robo_v2.glb")
	var modelo := cena.instantiate() as Node3D
	# [x do nicho, lado, a junta que vira peça solta, giro, altura]
	var lista := [[-1.95, 1.0, "ombroE", 0.0, 0.05], [-1.1, 1.0, "cabeca", PI, -0.35], [-1.95, -1.0, "quadrilD", 0.0, 0.0],
		[-1.1, -1.0, "ombroD", 0.0, 0.05]]
	for n in lista:
		var lado: float = n[1]
		var ang := PI * 0.5 - 0.18
		var p := _ponto(n[0], ang, R - 0.18)
		p.z *= lado
		var giro := Basis(Vector3.RIGHT, lado * 0.18) * Basis(Vector3.UP, 0.0 if lado > 0.0 else PI)
		var nicho := Node3D.new()
		add_child(nicho)
		nicho.transform = Transform3D(giro, p)
		# a caixa: fundo, teto, chão e lados, com o vidro na frente e uma luz dentro
		var cx := Vector3(0.62, 0.78, 0.34)
		_caixa(nicho, Vector3(0, 0, cx.z * 0.5), Vector3(cx.x, cx.y, 0.02), _mat(GRAFITE))
		_caixa(nicho, Vector3(0, cx.y * 0.5, 0), Vector3(cx.x + 0.06, 0.04, cx.z), _mat(BRANCO2))
		_caixa(nicho, Vector3(0, -cx.y * 0.5, 0), Vector3(cx.x + 0.06, 0.04, cx.z), _mat(BRANCO2))
		for s: float in [-1.0, 1.0]:
			_caixa(nicho, Vector3(s * cx.x * 0.5, 0, 0), Vector3(0.04, cx.y, cx.z), _mat(BRANCO2))
		_caixa(nicho, Vector3(0, cx.y * 0.5 - 0.035, 0.0), Vector3(cx.x - 0.08, 0.012, 0.05), _luz(LUZ_BRANCA, 1.0))
		var vidro := _caixa(nicho, Vector3(0, 0, -cx.z * 0.5), Vector3(cx.x, cx.y, 0.01), _vidro())
		vidro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# o gancho e a peça (do próprio modelo do robô)
		_caixa(nicho, Vector3(0, cx.y * 0.5 - 0.09, 0.05), Vector3(0.04, 0.1, 0.04), _mat(GRAFITE))
		var junta := modelo.find_child(n[2], true, false) as Node3D
		if junta != null:
			var peca := junta.duplicate() as Node3D
			nicho.add_child(peca)
			# peça guardada não tem chama nem brasa acesa
			for mi in peca.find_children("*", "MeshInstance3D", true, false):
				if mi.name.begins_with("chama") or mi.name.begins_with("brasa"):
					(mi as Node3D).visible = false
			peca.transform = Transform3D(Basis(Vector3.UP, n[3]).scaled(Vector3.ONE * 1.3), Vector3(0, cx.y * 0.5 - 0.12 + float(n[4]), 0.04))
		var l := OmniLight3D.new()
		l.light_color = Color(0.85, 0.97, 1.0)
		l.light_energy = 0.6
		l.omni_range = 0.8
		l.position = Vector3(0, 0.2, 0)
		nicho.add_child(l)
	modelo.free()


# ------------------------------------------------------------------ a boca: a vedação entre o de fora e o de dentro

func _boca() -> void:
	var giro := Basis(Vector3.BACK, PI * 0.5)
	_anel(self, Vector3(X1 + 0.06, 0, 0), 2.02, 2.14, _mat(Color(0.05, 0.05, 0.055), 0.1), giro)  # a borracha
	_anel(self, Vector3(X1 - 0.03, 0, 0), 1.96, 2.06, _mat(Color(0.62, 0.66, 0.68), 0.45), giro)  # o aço limpo


# ------------------------------------------------------------------ o robô no berço

## As juntas que se afastam na vista explodida (no espaço do modelo, em metros do modelo) e o raio do anel de
## luz que marca cada encaixe. As pernas descem e o modelo sobe o mesmo tanto: os pés não saem das presilhas.
const ABRE := {
	"tronco": [Vector3(0, 0.06, 0), 0.075], "cabeca": [Vector3(0, 0.075, 0), 0.07],
	"ombroE": [Vector3(0.09, 0.0, 0), 0.055], "ombroD": [Vector3(-0.09, 0.0, 0), 0.055],
	"cotoveloE": [Vector3(0, -0.05, 0), 0.04], "cotoveloD": [Vector3(0, -0.05, 0), 0.04],
	"quadrilE": [Vector3(0.025, -0.055, 0), 0.055], "quadrilD": [Vector3(-0.025, -0.055, 0), 0.055],
	"joelhoE": [Vector3(0, -0.04, 0), 0.05], "joelhoD": [Vector3(0, -0.04, 0), 0.05],
	"costas": [Vector3(0, 0, -0.12), 0.11],
}
const SOBE := 0.095  # o tanto que as pernas descem, somado
const PAIRA := 0.34  # o tanto que o robô sobe do estrado na aba Jatos (na medida do modelo, como `SOBE`)
## A pose de quem está preso no berço: braços um pouco abertos.
const POSE_BERCO := {"ombroE": Vector3(0, 0, 16.0), "ombroD": Vector3(0, 0, -16.0), "cotoveloE": Vector3(-12.0, 0, 0),
	"cotoveloD": Vector3(-12.0, 0, 0), "quadrilE": Vector3(0, 0, 3.0), "quadrilD": Vector3(0, 0, -3.0), "tronco": Vector3.ZERO,
	"cabeca": Vector3(-4.0, 0, 0)}
## A pose da subida da decolagem, a de segurar o X (ArmaduraVisual, Estado.DECOLAGEM).
const POSE_SUBIDA := {"quadrilE": Vector3(4.0, 0, 3.0), "quadrilD": Vector3(4.0, 0, -3.0), "joelhoE": Vector3(10.0, 0, 0),
	"joelhoD": Vector3(10.0, 0, 0), "ombroE": Vector3(25.0, 0, 12.0), "ombroD": Vector3(25.0, 0, -12.0),
	"cotoveloE": Vector3(-15.0, 0, 0), "cotoveloD": Vector3(-15.0, 0, 0)}


## Prende o robô no berço (a Oficina chama ao abrir a tela): a pose de manequim, os anéis de luz nos encaixes,
## as presilhas dos tornozelos e os dois cabos nas costas. Depois, `abrir` afasta as peças e `seguir` acompanha
## o robô quando ele vira para mostrar uma peça.
func prender(v: ArmaduraVisual) -> void:
	soltar(v)
	_preso = v
	v.sobrepor = POSE_BERCO.duplicate()
	_paira = 0.0
	_paira_alvo = 0.0
	if v.modelo:
		v.modelo.set_meta("pos_berco", v.modelo.position)
	_mat_disco = _luz(AGUA, 1.0).duplicate()
	for k in ABRE:
		var j := v.j.get(k) as Node3D
		if j == null:
			continue
		j.set_meta("pos_berco", j.position)
		var r: float = ABRE[k][1]
		var disco := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.006
		cm.radial_segments = 20
		disco.mesh = cm
		disco.material_override = _mat_disco
		disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		j.add_child(disco)
		_discos[k] = disco
		_presos.append(disco)
	for lado in ["E", "D"]:
		var anel := _anel(self, Vector3.ZERO, 0.075, 0.1, _mat(GRAFITE, 0.3))
		_anel(anel, Vector3(0, 0.012, 0), 0.086, 0.097, _luz(LARANJA, 1.2))  # o filete aceso em cima (escala junto)
		anel.set_meta("lado", lado)
		_presilhas.append(anel)
		_presos.append(anel)
	for s in 2:
		var cabo := MeshInstance3D.new()
		cabo.material_override = _mat(GRAFITE, 0.3)
		add_child(cabo)
		_cabos.append(cabo)
		_presos.append(cabo)
		var bocal := _cil(self, Vector3.ZERO, 0.04, 0.07, _mat(LARANJA, 0.2))
		_bocais.append(bocal)
		_presos.append(bocal)
	_costas_antes = Vector3.INF
	abrir(0.0, 0.6)
	seguir()


## As peças afastadas: 0 o robô inteiro (encaixes só acesos, com `brilho`), 1 a vista explodida.
func abrir(f: float, brilho := 1.0) -> void:
	if not is_instance_valid(_preso):
		return
	var v := _preso
	for k in ABRE:
		var j := v.j.get(k) as Node3D
		if j == null or not j.has_meta("pos_berco"):
			continue
		var desl: Vector3 = ABRE[k][0] * f
		j.position = (j.get_meta("pos_berco") as Vector3) + desl
		if _discos.has(k):
			# o anel de luz no meio da folga, de frente para o lado em que a peça se afasta
			(_discos[k] as Node3D).transform = Transform3D(_apontar(ABRE[k][0]), -desl * 0.5)
	_mat_disco.emission_energy_multiplier = 0.35 + 0.45 * brilho
	_aberto = f
	_erguer()
	por_aro(f)
	por_tela(f)
	if f <= 0.0:
		por_bracos([])
		_solda.light_energy = 0.0
		return
	# os braços nas folgas (ombro esquerdo, quadril direito e as costas), mexendo um pouco, e a solda piscando
	var t := Time.get_ticks_msec() * 0.001
	var alvos: Array = []
	var foras: Array = []
	var centro := to_local(v.global_position)
	var i := 0
	for k in ["ombroE", "quadrilD", "costas"]:
		var j := v.j.get(k) as Node3D
		if j == null:
			continue
		var p := to_local(j.global_position)
		var fora := Vector3(p.x - centro.x, 0.0, p.z - centro.z)
		if k == "costas":
			fora = to_local(j.global_position - j.global_basis.z.normalized()) - p
			fora.y = 0.0
		var treme := Vector3(sin(t * 9.0 + i * 2.1) * 0.03, sin(t * 15.0 + i) * 0.04, cos(t * 11.0 + i * 1.3) * 0.03) * f
		alvos.append(p + Vector3(0, 0.05, 0) + treme)
		foras.append(fora.normalized() + Vector3(0, 0.55, 0))
		i += 1
	por_bracos(alvos, foras)
	_solda.light_energy = 0.5 * f * (0.6 + 0.4 * sin(t * 31.0))


## O corpo sobe do estrado: um pouco com as peças afastadas, e `PAIRA` quando paira.
func _erguer() -> void:
	var v := _preso
	if not is_instance_valid(v) or v.modelo == null or not v.modelo.has_meta("pos_berco"):
		return
	var sobe := SOBE * _aberto + PAIRA * smoothstep(0.0, 1.0, _paira)
	v.modelo.position = (v.modelo.get_meta("pos_berco") as Vector3) + Vector3(0, sobe * v.modelo.scale.y, 0)


## Na aba Jatos o robô sobe um pouco do estrado na pose da subida, com os jatos acesos na cor em foco (doc §147).
## As presilhas vão presas aos tornozelos e os cabos às costas, como sempre.
func pairar(sim: bool) -> void:
	if not is_instance_valid(_preso):
		return
	_paira_alvo = 1.0 if sim else 0.0
	for k in POSE_SUBIDA:
		if sim:
			_preso.sobrepor[k] = POSE_SUBIDA[k]
		elif POSE_BERCO.has(k):
			_preso.sobrepor[k] = POSE_BERCO[k]
		else:
			_preso.sobrepor.erase(k)


## No ar (0 a 1): os testes e as fotos olham.
func no_ar() -> float:
	return _paira


## As presilhas, o prato e os cabos acompanham o robô (ele vira para mostrar uma peça e a pose muda devagar).
func seguir() -> void:
	if not is_instance_valid(_preso):
		return
	var v := _preso
	var dt := get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()
	if _paira != _paira_alvo:
		_paira = move_toward(_paira, _paira_alvo, dt / 0.7)  # sobe e desce em 0,7 s
		_erguer()
	var esc := v.modelo.global_basis.get_scale().x if v.modelo else 1.0
	for anel: Node3D in _presilhas:
		var t := v.j.get("tornozelo" + String(anel.get_meta("lado"))) as Node3D
		if t != null:
			var p := to_local(t.global_position)
			anel.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * esc), Vector3(p.x, p.y + 0.02, p.z))
	if v.modelo:
		var frente := global_transform.basis.inverse() * v.modelo.global_basis.z
		_prato.rotation.y = atan2(-frente.z, frente.x)
	var c := v.j.get("costas") as Node3D
	if c == null:
		return
	if c.global_position.distance_to(_costas_antes) < 0.01:
		return
	_costas_antes = c.global_position
	var trs := -c.global_basis.z.normalized()  # as costas do modelo olham para -Z
	var trs_l := global_transform.basis.inverse() * trs
	trs_l.y = 0.0
	trs_l = trs_l.normalized()
	var lado_l := Vector3(-trs_l.z, 0.0, trs_l.x)
	for s in 2:
		var sinal := -1.0 if s == 0 else 1.0
		var lado_w := c.global_basis.x.normalized() * sinal * 0.06 * esc
		var fim := to_local(c.global_position + trs * 0.1 * esc + lado_w + Vector3(0, 0.08 * esc, 0))
		# a tomada do teto fica atrás do robô, do lado das costas (gira com o prato)
		var ini := Vector3(PARADA.x, R - 0.14, 0.0) + trs_l * 0.75 + lado_l * sinal * 0.22
		(_cabos[s] as MeshInstance3D).mesh = _malha_cabo(ini, fim, 0.024, trs_l)
		(_bocais[s] as Node3D).transform = Transform3D(_apontar(fim - ini), fim)


## Solta o robô: volta as juntas ao lugar e tira presilhas, cabos e anéis.
func soltar(v: ArmaduraVisual = null) -> void:
	if v == null and is_instance_valid(_preso):
		v = _preso
	for n in _presos:
		if is_instance_valid(n):
			n.queue_free()
	_presos.clear()
	_presilhas.clear()
	_cabos.clear()
	_bocais.clear()
	_discos.clear()
	_preso = null
	_paira = 0.0
	_paira_alvo = 0.0
	_aberto = 0.0
	por_aro(0.0)
	por_tela(0.0)
	por_bracos([])
	_solda.light_energy = 0.0
	if _prato:
		_prato.rotation.y = 0.0
	if v == null or not is_instance_valid(v):
		return
	for k in ABRE:
		var j := v.j.get(k) as Node3D
		if j != null and j.has_meta("pos_berco"):
			j.position = j.get_meta("pos_berco")
			j.remove_meta("pos_berco")
	if v.modelo and v.modelo.has_meta("pos_berco"):
		v.modelo.position = v.modelo.get_meta("pos_berco")
		v.modelo.remove_meta("pos_berco")
	v.sobrepor = {}


## A instalação de uma vez (as fotos usam): preso, com as peças afastadas `f`.
func trabalhar(v: ArmaduraVisual, f: float) -> void:
	if _preso != v:
		prender(v)
	abrir(f, 1.0)
	seguir()
