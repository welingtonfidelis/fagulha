class_name BaseLar
extends RefCounted
## O lado aconchegante da base (2026-11-20, do rascunho aprovado pelo usuário): o hangar continua velho, com
## ferrugem e musgo, mas alguém cuida dele. Um telheiro aberto na frente cobre os 6,5 m do fundo da laje
## (5,3 m de altura na frente, caindo para 4,3 m em cima da parede); debaixo dele ficam a oficina (o
## cilindro), o cantinho de descanso, a bancada de passatempos e a baia dos robôs. Fora, na terra: a horta
## e as flores de um lado, a fogueira com bancos do outro, e um varal de luzinhas ligando tudo.
## Os móveis são do KayKit Furniture Bits (CC0); a TV de tubo, o rádio, o telheiro, os canteiros e a
## fogueira são feitos aqui. Medidas do lugar, como no `BaseVale`: +X direita, -Z a frente, +Z o fundo.

const MOVEIS := "res://assets/vale/moveis/"
const ESC := 0.62  # os móveis do pacote são para gente de 2 m; o robô tem 1,2 m
const Z_FRENTE := 0.9  # onde fica a viga da frente do telheiro (o estrado de nascer fica a céu aberto)
const Z_FUNDO := 7.5
const Y_FRENTE := 5.35
const CAIMENTO := 1.05 / 6.3  # quanto o telhado desce por metro, da frente para o fundo
const PAREDE := 6.02  # a face de dentro da parede do fundo
const ALTO_SOFA := 0.34  # a altura do assento do sofá e da poltrona
const MADEIRA := Color(0.33, 0.21, 0.12)
const MADEIRA_CLARA := Color(0.5, 0.36, 0.2)
const TERRA := Color(0.17, 0.11, 0.07)
const LONA := Color(0.56, 0.36, 0.18)
const FIO := Color(0.05, 0.05, 0.05)
const CORES_LUZINHA := [Color(1.0, 0.72, 0.32), Color(1.0, 0.52, 0.22), Color(1.0, 0.86, 0.55)]

static var moveis := 0
static var luzinhas := 0
static var canteiros := 0
static var fogueira := Vector3.INF  # no mundo
static var bancada := Vector3.INF  # no mundo: o meio do tampo
static var horta := Vector3.INF  # no mundo: o meio dos canteiros
static var sofa := Vector3.INF  # no mundo: o assento do sofá
static var _mat_movel: ShaderMaterial
static var _cenas := {}
static var _bolinha: SphereMesh


## A altura da face de baixo do telhado num ponto (medida do lugar).
static func teto_y(z: float) -> float:
	return Y_FRENTE - (z - Z_FRENTE) * CAIMENTO


## Um lugar de sentar: `pos` é onde a bacia do robô apoia, `frente` para onde ele olha, e ao levantar ele
## vai para `sai` metros à frente, no chão (`chao_y`). O robô lê a lista em `Armadura.assentos`.
static func assento_em(o: Ruinas.Obra, pos: Vector3, frente: Vector3, sai: float, chao_y: float) -> void:
	var f := (o.t.basis * frente).normalized()
	var fora := pos + frente * sai
	Armadura.assentos.append([o.t * pos, f, o.t * Vector3(fora.x, chao_y + 0.05, fora.z)])


static func montar(o: Ruinas.Obra, cy: float) -> void:
	Armadura.assentos.clear()
	moveis = 0
	luzinhas = 0
	canteiros = 0
	_mat_movel = null
	_telheiro(o, cy)
	_cantinho(o, cy)
	_bancada(o, cy)
	_giz(o, cy)
	_horta(o)
	_fogueira(o, cy)


# ---------------------------------------------------------------- peças

## Uma caixa de uma cor só (madeira, terra, lona, plástico).
static func caixa(o: Ruinas.Obra, centro: Vector3, tam: Vector3, cor: Color, giro := Basis.IDENTITY, colide := false, fer := 0.0, mus := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = BaseVale._mat_cor(cor, fer, mus, o.v._tex)
	mi.transform = o.t * Transform3D(giro, centro)
	o.v.add_child(mi)
	if colide:
		var cx := BoxShape3D.new()
		cx.size = tam
		o.forma(cx, Transform3D(giro, centro))
	return mi


## Uma cor que acende sozinha (tela, brasa, o vidro das luzinhas).
static func _mat_aceso(o: Ruinas.Obra, cor: Color, forca: float) -> ShaderMaterial:
	var chave := "aceso|%s|%.2f" % [cor.to_html(), forca]
	if BaseVale._mats.has(chave):
		return BaseVale._mats[chave]
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_base.gdshader")
	m.set_shader_parameter("ruido", o.v._tex)
	m.set_shader_parameter("tinta", cor)
	m.set_shader_parameter("aceso", Color(cor.r * forca, cor.g * forca, cor.b * forca))
	BaseVale._mats[chave] = m
	return m


## Um móvel do pacote, com a base no ponto `pe` e virado `giro`. `achata` encolhe só a altura (tapete).
static func movel(o: Ruinas.Obra, nome: String, pe: Vector3, giro: float, esc := ESC, colide := true, achata := 1.0) -> Node3D:
	if not _cenas.has(nome):
		_cenas[nome] = load(MOVEIS + nome + ".gltf")
	var raiz := (_cenas[nome] as PackedScene).instantiate() as Node3D
	var cx := BaseVale._caixa(raiz)
	var no := Node3D.new()
	no.name = "Movel_" + nome
	no.add_child(raiz)
	raiz.position = -Vector3(cx.get_center().x, cx.position.y, cx.get_center().z)
	no.transform = o.t * Transform3D(Basis(Vector3.UP, giro) * Basis.from_scale(Vector3(esc, esc * achata, esc)), pe)
	_vestir(o, raiz)
	o.v.add_child(no)
	moveis += 1
	if colide:
		var f := BoxShape3D.new()
		f.size = Vector3(cx.size.x * esc, cx.size.y * esc * achata, cx.size.z * esc)
		o.forma(f, Transform3D(Basis(Vector3.UP, giro), pe + Vector3(0, f.size.y * 0.5, 0)))
	return no


## Um quadro na parede: `centro` é o meio do quadro, encostado na parede pelas costas.
static func quadro(o: Ruinas.Obra, nome: String, centro: Vector3, giro: float, esc := ESC, tomba := 0.0) -> void:
	if not _cenas.has(nome):
		_cenas[nome] = load(MOVEIS + nome + ".gltf")
	var raiz := (_cenas[nome] as PackedScene).instantiate() as Node3D
	raiz.name = "Quadro_" + nome
	raiz.transform = o.t * Transform3D(Basis(Vector3.UP, giro) * Basis(Vector3.BACK, tomba) * Basis.from_scale(Vector3.ONE * esc), centro)
	_vestir(o, raiz)
	o.v.add_child(raiz)
	moveis += 1


static func _vestir(o: Ruinas.Obra, raiz: Node) -> void:
	if _mat_movel == null:
		_mat_movel = ShaderMaterial.new()
		_mat_movel.shader = load("res://scripts/shaders/vale_base.gdshader")
		_mat_movel.set_shader_parameter("ruido", o.v._tex)
		_mat_movel.set_shader_parameter("tex", load(MOVEIS + "furniturebits_texture.png"))
		_mat_movel.set_shader_parameter("tinta", Color(0.78, 0.76, 0.72))
		_mat_movel.set_shader_parameter("ferrugem", 0.0)
		_mat_movel.set_shader_parameter("musgo", 0.0)
	for mi: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false) + ([raiz] if raiz is MeshInstance3D else []):
		mi.material_override = _mat_movel


## Um varal de luzinhas de `a` até `b`, com a barriga para baixo. De dia são bolinhas de vidro; de noite
## cada uma ganha um ponto de luz (`LuzesNoite`).
static func varal(o: Ruinas.Obra, a: Vector3, b: Vector3, barriga: float, passo := 0.85) -> void:
	if _bolinha == null:
		_bolinha = SphereMesh.new()
		_bolinha.radius = 0.07
		_bolinha.height = 0.16
		_bolinha.radial_segments = 8
		_bolinha.rings = 4
	var n := maxi(2, int(round(a.distance_to(b) / passo)))
	var antes := a
	for k in range(1, n + 1):
		var f := float(k) / n
		var p := a.lerp(b, f) - Vector3(0, barriga * 4.0 * f * (1.0 - f), 0)
		var meio := (antes + p) * 0.5
		var dir := p - antes
		if dir.length() > 0.01:
			var olha := Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT)
			caixa(o, meio, Vector3(0.018, 0.018, dir.length()), FIO, olha)
		if k < n:
			var cor: Color = CORES_LUZINHA[luzinhas % CORES_LUZINHA.size()]
			var mi := MeshInstance3D.new()
			mi.mesh = _bolinha
			mi.material_override = _mat_aceso(o, cor, 0.55)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.transform = o.t * Transform3D(Basis.IDENTITY, p - Vector3(0, 0.08, 0))
			o.v.add_child(mi)
			LuzesNoite.por(o.v, o.t * (p - Vector3(0, 0.08, 0)), cor, 0.6)
			luzinhas += 1
		antes = p


# ---------------------------------------------------------------- o telheiro

static func _telheiro(o: Ruinas.Obra, cy: float) -> void:
	var x0 := -11.6
	var larg := 2.65
	var z0 := Z_FRENTE - 0.35  # o beiral da frente
	var ang := atan(CAIMENTO)
	var giro := Basis(Vector3.RIGHT, ang)
	var comp := (Z_FUNDO - z0) / cos(ang)
	var zc := (z0 + Z_FUNDO) * 0.5
	var yc := cy + teto_y(zc)
	# a viga da frente, em três postes com sapata e mão-francesa; no canto do cilindro ela apoia nele
	var y_viga := cy + Y_FRENTE - 0.3
	o.bloco(Vector3(-1.0, y_viga, Z_FRENTE), Vector3(21.3, 0.34, 0.3), Basis.IDENTITY, "casco", false)
	for px: float in [-11.35, 3.4, 9.35]:
		var alto := Y_FRENTE - 0.47
		o.bloco(Vector3(px, cy + alto * 0.5, Z_FRENTE), Vector3(0.28, alto, 0.28), Basis.IDENTITY, "casco")
		o.bloco(Vector3(px, cy + 0.14, Z_FRENTE), Vector3(0.56, 0.28, 0.56), Basis.IDENTITY, "ruina", false)
		for lado: float in [-1.0, 1.0]:
			if px + lado * 1.0 < -11.5 or px + lado * 1.0 > 9.5:
				continue
			o.bloco(Vector3(px + lado * 0.5, y_viga - 0.62, Z_FRENTE), Vector3(0.11, 1.35, 0.11), Basis(Vector3.BACK, -lado * 0.78), "ferrugem", false)
	o.bloco(Vector3(BaseVale.C_CIL.x, cy + 4.74, Z_FRENTE), Vector3(0.6, 0.36, 0.4), Basis.IDENTITY, "ferrugem", false)
	# a viga do fundo, deitada em cima da parede
	o.bloco(Vector3(-1.0, cy + teto_y(6.75) - 0.22, 6.75), Vector3(21.3, 0.26, 0.3), Basis.IDENTITY, "casco", false)
	# os caibros
	for k in 8:
		var x := -11.35 + k * (20.7 / 7.0)
		o.bloco(Vector3(x, yc - 0.13, zc), Vector3(0.14, 0.2, comp), giro, "ferrugem", false)
	# as telhas: chapas de cores e idades diferentes, uma lona no lugar da que faltava e meia chapa caída
	# sobre a baia (por onde entra um facho de sol)
	var mats := ["casco", "casco_claro", "casco", "ferrugem", "", "casco", "casco_claro", "casco"]
	for k in 8:
		var x := x0 + (k + 0.5) * larg
		var sobe := 0.03 + 0.012 * (k % 3)
		if mats[k] == "":
			caixa(o, Vector3(x, yc + 0.05, zc), Vector3(larg + 0.2, 0.04, comp * 0.97), LONA, giro)
			for ponta: float in [-1.0, 1.0]:  # as ripas que seguram a lona
				caixa(o, Vector3(x + ponta * (larg * 0.5 + 0.02), yc + 0.08, zc), Vector3(0.09, 0.05, comp * 0.97), MADEIRA, giro)
		elif k == 6:
			var parte := comp * 0.62
			var zf := Z_FUNDO - parte * 0.5 * cos(ang)
			o.bloco(Vector3(x, cy + teto_y(zf) + sobe, zf), Vector3(larg - 0.04, 0.06, parte), giro, mats[k], false)
		else:
			o.bloco(Vector3(x, yc + sobe, zc), Vector3(larg - 0.04, 0.06, comp), giro, mats[k], false)
	var cob := BoxShape3D.new()
	cob.size = Vector3(21.2, 0.22, comp)
	o.forma(cob, Transform3D(giro, Vector3(-1.0, yc, zc)))
	# as luzinhas: na beira do telheiro, por dentro do cantinho, e um fio comprido até a fogueira
	var yl := y_viga - 0.2
	varal(o, Vector3(-5.2, yl, Z_FRENTE - 0.2), Vector3(3.4, yl, Z_FRENTE - 0.2), 0.42)
	varal(o, Vector3(3.4, yl, Z_FRENTE - 0.2), Vector3(9.35, yl, Z_FRENTE - 0.2), 0.36)
	varal(o, Vector3(-5.6, cy + 3.75, PAREDE - 0.2), Vector3(3.2, cy + 3.75, PAREDE - 0.2), 0.3)


# ---------------------------------------------------------------- o cantinho de descanso

static func _cantinho(o: Ruinas.Obra, cy: float) -> void:
	var meio := -3.0
	var zs := PAREDE - 0.58  # o meio do sofá, com as costas na parede
	movel(o, "rug_rectangle_stripes_A", Vector3(meio, cy + 0.01, zs - 1.75), 0.0, 1.0, false, 0.35)
	movel(o, "couch_pillows", Vector3(meio, cy, zs), PI)
	movel(o, "table_low_decorated", Vector3(meio, cy + 0.03, zs - 1.75), 0.0, 0.42)
	movel(o, "armchair_pillows", Vector3(meio + 2.25, cy, zs - 1.35), -1.95)
	movel(o, "cactus_medium_A", Vector3(meio + 1.55, cy, zs + 0.1), 0.6, 0.7, false)
	sofa = o.t * Vector3(meio, cy + 0.45, zs - 0.1)
	for lado: float in [-0.45, 0.45]:
		assento_em(o, Vector3(meio + lado, cy + ALTO_SOFA, zs - 0.08), Vector3(0, 0, -1), 0.95, cy)
	var frente_polt := Basis(Vector3.UP, -1.95) * Vector3(0, 0, 1)
	assento_em(o, Vector3(meio + 2.25, cy + ALTO_SOFA, zs - 1.35) + frente_polt * 0.06, frente_polt, 0.95, cy)
	# a luminária de pé, a única luz quente e forte da base
	var lx := meio - 1.5
	movel(o, "lamp_standing", Vector3(lx, cy, zs + 0.1), 0.0, ESC, false)
	var pe_lamp := CylinderShape3D.new()
	pe_lamp.radius = 0.12
	pe_lamp.height = 1.5
	o.forma(pe_lamp, Transform3D(Basis.IDENTITY, Vector3(lx, cy + 0.75, zs + 0.1)))
	var luz := OmniLight3D.new()
	luz.name = "LuzDoCantinho"
	luz.light_color = Color(1.0, 0.74, 0.44)
	luz.light_energy = 1.7
	luz.omni_range = 7.5
	luz.position = o.t * Vector3(lx + 0.5, cy + 1.7, zs - 0.6)
	o.v.add_child(luz)
	LuzesNoite.por(o.v, o.t * Vector3(lx, cy + 1.36, zs + 0.1), LuzesNoite.AMBAR, 1.3)
	# o mural das lembranças, na parede atrás do sofá
	var zq := PAREDE - 0.02
	quadro(o, "pictureframe_large_B", Vector3(meio, cy + 2.05, zq), PI)
	quadro(o, "pictureframe_medium", Vector3(meio - 1.05, cy + 2.2, zq), PI, ESC, 0.04)
	quadro(o, "pictureframe_small_A", Vector3(meio + 1.0, cy + 2.32, zq), PI, ESC, -0.05)
	quadro(o, "pictureframe_small_B", Vector3(meio + 1.08, cy + 1.86, zq), PI, ESC, 0.03)
	quadro(o, "pictureframe_large_A", Vector3(meio + 0.1, cy + 2.95, zq), PI, 0.5, -0.02)
	quadro(o, "pictureframe_small_B", Vector3(meio - 1.1, cy + 1.62, zq), PI, 0.55, -0.04)


# ---------------------------------------------------------------- a bancada de passatempos

static func _bancada(o: Ruinas.Obra, cy: float) -> void:
	var bx := 1.55
	var bz := PAREDE - 0.5
	movel(o, "desk_large", Vector3(bx, cy, bz), PI)
	var tampo := cy + 1.0 * ESC
	bancada = o.t * Vector3(bx, tampo, bz)
	movel(o, "chair_stool_wood", Vector3(bx - 0.55, cy, bz - 0.95), 0.3)
	movel(o, "cactus_small_A", Vector3(bx + 1.0, tampo, bz + 0.12), 1.1, 0.5, false)
	movel(o, "mug_A", Vector3(bx + 0.12, tampo, bz - 0.22), 2.2, 0.5, false)
	movel(o, "book_set", Vector3(bx + 0.62, tampo + 0.0, bz - 0.26), 0.25, 0.42, false)
	_tv(o, Vector3(bx - 0.55, tampo, bz + 0.08))
	_radio(o, Vector3(bx + 0.5, tampo, bz + 0.16))
	# o videogame: a caixa, o cartucho espetado, o fio até a TV e o controle na beira da bancada
	var vg := Vector3(bx - 0.5, tampo, bz - 0.3)
	caixa(o, vg + Vector3(0, 0.04, 0), Vector3(0.34, 0.08, 0.24), Color(0.6, 0.58, 0.52))
	caixa(o, vg + Vector3(0, 0.085, 0.02), Vector3(0.3, 0.012, 0.1), Color(0.12, 0.12, 0.13))
	caixa(o, vg + Vector3(0.02, 0.13, 0.02), Vector3(0.17, 0.11, 0.03), Color(0.62, 0.16, 0.12))
	caixa(o, vg + Vector3(-0.11, 0.085, -0.08), Vector3(0.05, 0.012, 0.03), Color(0.7, 0.2, 0.14))
	caixa(o, vg + Vector3(0.14, 0.02, 0.2), Vector3(0.012, 0.012, 0.22), FIO)
	caixa(o, vg + Vector3(-0.33, 0.012, -0.02), Vector3(0.012, 0.012, 0.2), FIO, Basis(Vector3.UP, 0.9))
	movel(o, "gameconsole_handheld", Vector3(vg.x - 0.42, tampo, vg.z - 0.06), -0.5, 0.26, false)
	# uma luzinha de tela, fraca, para o canto não ficar morto de noite
	var luz := OmniLight3D.new()
	luz.name = "LuzDaTV"
	luz.light_color = Color(0.45, 0.8, 1.0)
	luz.light_energy = 0.5
	luz.omni_range = 2.6
	luz.position = o.t * Vector3(bx - 0.55, tampo + 0.3, bz - 0.5)
	o.v.add_child(luz)


## A tela do joguinho: uma navinha, três invasores e as estrelas, em pontos grandes.
static func _tela_do_jogo() -> ImageTexture:
	var img := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.03, 0.09))
	var ponto := func(x: int, y: int, cor: Color) -> void:
		for dx in 2:
			for dy in 2:
				img.set_pixel(clampi(x * 2 + dx, 0, 63), clampi(y * 2 + dy, 0, 47), cor)
	for k in 22:
		ponto.call((k * 37 + 5) % 32, (k * 53 + 3) % 24, Color(0.5, 0.55, 0.7))
	var nave := ["..#..", ".###.", "#####", "#.#.#"]
	for j in nave.size():
		for i in 5:
			if nave[j][i] == "#":
				ponto.call(14 + i, 18 + j, Color(0.4, 1.0, 0.75))
	var bicho := ["#...#", ".###.", "##.##", ".#.#."]
	for b in 3:
		for j in bicho.size():
			for i in 5:
				if bicho[j][i] == "#":
					ponto.call(5 + b * 9 + i, 4 + (b % 2) * 2 + j, [Color(1.0, 0.45, 0.35), Color(1.0, 0.8, 0.3), Color(0.9, 0.45, 1.0)][b])
	for y in [15, 12, 9]:
		ponto.call(16, y, Color(1.0, 1.0, 0.8))
	return ImageTexture.create_from_image(img)


static func _tv(o: Ruinas.Obra, pe: Vector3) -> void:
	var corpo := Color(0.42, 0.38, 0.31)
	caixa(o, pe + Vector3(0, 0.27, 0.02), Vector3(0.66, 0.5, 0.5), corpo, Basis.IDENTITY, false, 0.12)
	caixa(o, pe + Vector3(0, 0.27, 0.3), Vector3(0.44, 0.36, 0.14), Color(0.2, 0.19, 0.17))  # o tubo, atrás
	caixa(o, pe + Vector3(-0.07, 0.29, -0.235), Vector3(0.48, 0.4, 0.02), Color(0.06, 0.06, 0.07))  # a moldura
	for px: float in [-0.24, 0.24]:
		caixa(o, pe + Vector3(px, 0.01, 0.0), Vector3(0.08, 0.03, 0.4), Color(0.1, 0.1, 0.1))
	for k in 2:  # os botões de girar
		caixa(o, pe + Vector3(0.25, 0.38 - k * 0.13, -0.24), Vector3(0.07, 0.07, 0.03), Color(0.75, 0.72, 0.62))
	for lado: float in [-1.0, 1.0]:  # a antena
		caixa(o, pe + Vector3(lado * 0.14, 0.72, 0.1), Vector3(0.012, 0.44, 0.012), Color(0.6, 0.6, 0.6), Basis(Vector3.BACK, -lado * 0.5))
	var tela := MeshInstance3D.new()
	tela.name = "TelaDoJogo"
	var q := QuadMesh.new()
	q.size = Vector2(0.42, 0.33)
	tela.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_base.gdshader")
	var tex := _tela_do_jogo()
	m.set_shader_parameter("ruido", o.v._tex)
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("luz", tex)
	m.set_shader_parameter("luz_forca", 1.5)
	tela.material_override = m
	tela.transform = o.t * Transform3D(Basis(Vector3.UP, PI), pe + Vector3(-0.07, 0.29, -0.247))
	o.v.add_child(tela)


static func _radio(o: Ruinas.Obra, pe: Vector3) -> void:
	var giro := Basis(Vector3.UP, -0.22)
	var p := func(v: Vector3) -> Vector3:
		return pe + giro * v
	caixa(o, p.call(Vector3(0, 0.15, 0)), Vector3(0.52, 0.3, 0.17), Color(0.5, 0.26, 0.12), giro)
	caixa(o, p.call(Vector3(0, 0.31, 0)), Vector3(0.3, 0.025, 0.03), Color(0.1, 0.1, 0.1), giro)  # a alça
	for lado: float in [-1.0, 1.0]:
		caixa(o, p.call(Vector3(lado * 0.15, 0.13, -0.09)), Vector3(0.17, 0.17, 0.012), Color(0.07, 0.07, 0.08), giro)
		caixa(o, p.call(Vector3(lado * 0.15, 0.13, -0.098)), Vector3(0.07, 0.07, 0.012), Color(0.3, 0.3, 0.3), giro)
	var visor := caixa(o, p.call(Vector3(0, 0.255, -0.09)), Vector3(0.2, 0.04, 0.012), Color(1.0, 0.75, 0.35), giro)
	visor.material_override = _mat_aceso(o, Color(1.0, 0.72, 0.3), 0.8)
	caixa(o, p.call(Vector3(0.2, 0.5, 0.05)), Vector3(0.012, 0.44, 0.012), Color(0.65, 0.65, 0.65), giro * Basis(Vector3.BACK, -0.3))


# ---------------------------------------------------------------- o pátio: riscos de giz

## A amarelinha e uns rabiscos (sol, estrela) riscados no piso da frente, onde os robozinhos brincam.
static func _giz(o: Ruinas.Obra, cy: float) -> void:
	var img := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var branco := Color(0.92, 0.9, 0.82, 1.0)
	var risco := func(x0: int, y0: int, x1: int, y1: int, cor: Color) -> void:
		var n := maxi(absi(x1 - x0), absi(y1 - y0)) + 1
		for k in n:
			var f := float(k) / maxf(1.0, n - 1)
			var x := int(round(lerpf(x0, x1, f)))
			var y := int(round(lerpf(y0, y1, f)))
			for dx in 2:
				for dy in 2:
					if (x * 7 + y * 13 + dx) % 9 != 0:  # o giz falha um pouco
						img.set_pixel(clampi(x + dx, 0, 127), clampi(y + dy, 0, 255), cor)
	var quadrado := func(x: int, y: int, l: int) -> void:
		risco.call(x, y, x + l, y, branco)
		risco.call(x + l, y, x + l, y + l, branco)
		risco.call(x + l, y + l, x, y + l, branco)
		risco.call(x, y + l, x, y, branco)
	# as casas: 1, 2, 3-4, 5, 6-7, 8 e o céu
	quadrado.call(50, 216, 28)
	quadrado.call(50, 188, 28)
	quadrado.call(36, 160, 28)
	quadrado.call(64, 160, 28)
	quadrado.call(50, 132, 28)
	quadrado.call(36, 104, 28)
	quadrado.call(64, 104, 28)
	quadrado.call(50, 76, 28)
	for k in 13:  # o céu, em arco
		var a0 := PI + PI * k / 13.0
		var a1 := PI + PI * (k + 1) / 13.0
		risco.call(64 + int(cos(a0) * 26.0), 76 + int(sin(a0) * 26.0), 64 + int(cos(a1) * 26.0), 76 + int(sin(a1) * 26.0), branco)
	var amarelo := Color(1.0, 0.85, 0.35, 1.0)
	for k in 8:  # um sol
		var a := TAU * k / 8.0
		risco.call(108 + int(cos(a) * 7.0), 30 + int(sin(a) * 7.0), 108 + int(cos(a) * 14.0), 30 + int(sin(a) * 14.0), amarelo)
		risco.call(108 + int(cos(a) * 6.0), 30 + int(sin(a) * 6.0), 108 + int(cos(a + TAU / 8.0) * 6.0), 30 + int(sin(a + TAU / 8.0) * 6.0), amarelo)
	var azul := Color(0.55, 0.8, 1.0, 1.0)
	for k in 5:  # uma estrela
		var a := -PI * 0.5 + TAU * 2.0 * k / 5.0
		var b := -PI * 0.5 + TAU * 2.0 * (k + 1) / 5.0
		risco.call(18 + int(cos(a) * 12.0), 200 + int(sin(a) * 12.0), 18 + int(cos(b) * 12.0), 200 + int(sin(b) * 12.0), azul)
	var mi := MeshInstance3D.new()
	mi.name = "RiscosDeGiz"
	var q := PlaneMesh.new()
	q.size = Vector2(2.3, 4.6)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_base.gdshader")
	m.set_shader_parameter("ruido", o.v._tex)
	m.set_shader_parameter("tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("corte", 0.5)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = o.t * Transform3D(Basis(Vector3.UP, 0.35), Vector3(-5.3, cy + 0.035, -2.9))
	o.v.add_child(mi)


# ---------------------------------------------------------------- a horta e as flores

## Três canteiros na terra, fora da laje, à esquerda de quem sai: flores, verduras e brotos. Um barril de
## água ao lado e uma cerquinha baixa de estacas.
static func _horta(o: Ruinas.Obra) -> void:
	var c := Vector2(-8.4, -9.0)
	var linhas := [["q_flor_a", "q_flor_c", "q_flor_b", "q_flor_d"], ["q_planta_b", "q_planta_d", "q_planta_a"], ["q_trevo_b", "q_cogumelo", "q_trevo", "q_planta_c"]]
	var tam := [0.5, 0.42, 0.4]
	for k in 3:
		var z := c.y + (k - 1) * 1.75
		var y := o.chao_min(Vector2(c.x, z), 2.0)
		var topo := o.chao(c.x, z) + 0.24
		var meio_y := (y - 0.3 + topo) * 0.5
		caixa(o, Vector3(c.x, meio_y, z), Vector3(4.3, topo - y + 0.3, 0.96), TERRA, Basis.IDENTITY, true)
		for lado: float in [-1.0, 1.0]:
			caixa(o, Vector3(c.x, meio_y + 0.03, z + lado * 0.52), Vector3(4.5, topo - y + 0.36, 0.09), MADEIRA)
			caixa(o, Vector3(c.x + lado * 2.2, meio_y + 0.03, z), Vector3(0.09, topo - y + 0.36, 1.13), MADEIRA)
		var nomes: Array = linhas[k]
		for i in 7:
			var px := c.x - 1.8 + i * 0.6
			var nome: String = nomes[i % nomes.size()]
			if o.v._malhas.has(nome):
				var s: float = tam[k] * (0.85 + 0.3 * absf(sin(px * 3.1 + k)))
				o.v._por(nome, Transform3D(Basis(Vector3.UP, px * 2.3 + k).scaled(Vector3.ONE * s), o.t * Vector3(px, topo - 0.03, z + 0.12 * sin(i * 1.7))))
		canteiros += 1
	horta = o.t * Vector3(c.x, o.chao(c.x, c.y), c.y)
	BaseVale._peca(o, "Prop_Barrel2_Open", Vector3(c.x + 3.1, o.chao(c.x + 3.1, c.y + 0.6), c.y + 0.6), 0.7, 1.0, 0.5, 0.3)
	# a cerquinha: estacas e uma ripa, só do lado de fora (a mata)
	for i in 9:
		var ex := c.x - 3.0
		var ez := c.y - 3.0 + i * 0.75
		caixa(o, Vector3(ex, o.chao(ex, ez) + 0.3, ez), Vector3(0.09, 0.7, 0.09), MADEIRA_CLARA, Basis(Vector3.UP, i * 0.4), false, 0.0, 0.25)
	var ey := o.chao(c.x - 3.0, c.y) + 0.45
	caixa(o, Vector3(c.x - 3.0, ey, c.y), Vector3(0.05, 0.08, 6.2), MADEIRA_CLARA, Basis.IDENTITY, false, 0.0, 0.25)


# ---------------------------------------------------------------- a fogueira

static func _fogueira(o: Ruinas.Obra, cy: float) -> void:
	var c := Vector2(6.6, -9.2)
	var y := o.chao(c.x, c.y)
	fogueira = o.t * Vector3(c.x, y, c.y)
	for k in 9:
		var a := TAU * k / 9.0
		o.bloco(Vector3(c.x + cos(a) * 0.72, y + 0.1, c.y + sin(a) * 0.72), Vector3(0.44, 0.32, 0.36), Basis(Vector3.UP, -a + 0.3 * sin(k * 2.0)), "ruina", false)
	var aro := CylinderShape3D.new()
	aro.radius = 0.9
	aro.height = 0.36
	o.forma(aro, Transform3D(Basis.IDENTITY, Vector3(c.x, y + 0.18, c.y)))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		caixa(o, Vector3(c.x + cos(a) * 0.2, y + 0.3, c.y + sin(a) * 0.2), Vector3(0.13, 0.13, 0.85), MADEIRA, Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, 0.85), false, 0.0, 0.0)
	# de dia e na chuva fica apagada (carvão escuro); o nó `Fogueira` acende de noite, com tempo seco
	var brasa := caixa(o, Vector3(c.x, y + 0.08, c.y), Vector3(0.7, 0.1, 0.7), Color(0.06, 0.055, 0.05), Basis(Vector3.UP, 0.5))
	for item: Array in [[Vector3(0, 0.4, 0), LuzesNoite.BRASA, 1.9, 0.0, 0.0], [Vector3(0, 0.75, 0), LuzesNoite.AMBAR, 1.1, 0.42, 0.0], [Vector3(0.1, 0.95, -0.05), LuzesNoite.AMBAR, 0.6, 0.27, 0.3]]:
		var ponto := LuzesNoite.por(o.v, o.t * (Vector3(c.x, y, c.y) + (item[0] as Vector3)), item[1], item[2], item[3], item[4])
		ponto.set_meta("so_com", "fogueira")
	var luz := OmniLight3D.new()
	luz.name = "LuzDaFogueira"
	luz.light_color = Color(1.0, 0.55, 0.22)
	luz.light_energy = 0.0
	luz.omni_range = 7.0
	luz.position = o.t * Vector3(c.x, y + 0.9, c.y)
	o.v.add_child(luz)
	var fogo := Fogueira.new()
	fogo.name = "Fogueira"
	fogo.brasa = brasa
	fogo.mat_fria = brasa.material_override
	fogo.mat_acesa = _mat_aceso(o, Color(1.0, 0.36, 0.08), 0.45)
	fogo.luz = luz
	fogo.transform = o.t * Transform3D(Basis.IDENTITY, Vector3(c.x, y, c.y))
	o.v.add_child(fogo)
	# três bancos de tronco, deixando livre o lado do campo
	for a: float in [0.15, PI * 0.5, PI - 0.15]:
		var b := Vector2(c.x + cos(a) * 2.25, c.y + sin(a) * 2.25)
		var by := o.chao(b.x, b.y)
		var gb := Basis(Vector3.UP, PI * 0.5 - a)
		caixa(o, Vector3(b.x, by + 0.4, b.y), Vector3(1.7, 0.18, 0.46), MADEIRA_CLARA, gb, false, 0.0, 0.12)
		for lado: float in [-1.0, 1.0]:
			caixa(o, Vector3(b.x, by + 0.14, b.y) + gb * Vector3(lado * 0.6, 0, 0), Vector3(0.3, 0.4, 0.4), MADEIRA, gb)
		var assento := BoxShape3D.new()
		assento.size = Vector3(1.7, 0.49, 0.46)
		o.forma(assento, Transform3D(gb, Vector3(b.x, by + 0.245, b.y)))
		var para_fogo := Vector3(c.x - b.x, 0, c.y - b.y).normalized()
		for lado: float in [-0.42, 0.42]:
			assento_em(o, Vector3(b.x, by + 0.5, b.y) + gb * Vector3(lado, 0, 0), para_fogo, 0.75, by)
	# o poste do varal, e o fio que vem da beira do telheiro
	var px := c.x + 2.6
	var pz := c.y + 2.2
	var py := o.chao(px, pz)
	caixa(o, Vector3(px, py + 1.6, pz), Vector3(0.12, 3.4, 0.12), MADEIRA, Basis.IDENTITY, true)
	varal(o, Vector3(9.35, cy + Y_FRENTE - 0.5, Z_FRENTE - 0.2), Vector3(px, py + 3.25, pz), 0.75)
