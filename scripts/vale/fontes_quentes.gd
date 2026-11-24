class_name FontesQuentes
extends Node3D
## As fontes quentes da área B, refeitas em 2026-11-22 a partir da revisão do game designer (doc §139). Antes, cada
## poça era um disco opaco: a grade de 4 m do chão cortava a beira em serrote, o laranja era largo e liso, e do
## alto cada poça parecia um alvo. Escolhas do usuário: o Olho Azul vivo, de cartão-postal; um gêiser pequeno de
## vez em quando, além do vapor e das bolhas; e o vapor que muda com a hora só na vista (o calor não muda).
## - A beira de verdade (`contorno`): para cada poça, em 64 ângulos, onde o chão (do jeito que a malha desenha)
##   passa da altura da água. A água vai até ela, transparente pela espessura (fonte_quente), e uma crosta baixa
##   de sínter cobre a emenda (fonte_crosta).
## - O chão em volta (fontes_chao, no shader do chão da terra nova): faixas pelo calor a partir dessa beira e um
##   canal de escoamento pelo lado mais baixo de cada poça.
## - Bolhas no Olho Azul e nas médias, duas poças de lama que estouram devagar, o gêiser (GeiserFonte) num dos
##   respiros, o som (borbulhar, chiado, lama) e a "meia branca" de mineral nos pinheiros secos da bacia.

const ANGULOS := 64
## O tom de cada poça (fonte_quente): 0 o Olho Azul, 1 azul leitoso, 2 esmeralda, 3 turquesa dos degraus.
const TONS := [0, 2, 1, 1, 2, 1, 3]
const LAMA_RAIO := 2.6
const BACIA := 330.0

var tn: TerraNova
var v: Vale
var pocas: Array[Dictionary] = []  # {c, r, agua, forca, tom, contorno, saida, canal, crosta}
var lamas: Array[Vector3] = []
var geiser: GeiserFonte
var geiser_em := Vector2.INF  # o respiro onde ele fica
var _olho := Vector2.ZERO
var _mat_crosta: ShaderMaterial
var _lama_t := []
var _rng := RandomNumberGenerator.new()


static func montar(terra: TerraNova, vale: Vale) -> FontesQuentes:
	var f := FontesQuentes.new()
	f.name = "FontesQuentes"
	f.tn = terra
	f.v = vale
	terra.add_child(f)
	f._construir()
	return f


## A altura do chão como a malha desenha: a grade de 4 m em triângulos, com a diagonal do canto (i, j) ao
## (i + 1, j + 1) (TerraNova._grade). O `altura` da TerraNova é bilinear e erra a beira em até meio metro.
func altura_malha(x: float, z: float) -> float:
	var fx := clampf((x - TerraNova.X0) / TerraNova.PASSO, 0.0, TerraNova.NX - 1.001)
	var fz := clampf((z - TerraNova.Z0) / TerraNova.PASSO, 0.0, TerraNova.NZ - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var u := fx - ix
	var w := fz - iz
	var i := iz * TerraNova.NX + ix
	var h00 := tn.h[i]
	var h10 := tn.h[i + 1]
	var h01 := tn.h[i + TerraNova.NX]
	var h11 := tn.h[i + TerraNova.NX + 1]
	if u >= w:
		return h00 + u * (h10 - h00) + w * (h11 - h10)
	return h00 + w * (h01 - h00) + u * (h11 - h01)


func _construir() -> void:
	_rng.seed = 1122
	_olho = tn.fontes[0][0]
	_mat_crosta = ShaderMaterial.new()
	_mat_crosta.shader = load("res://scripts/shaders/fonte_crosta.gdshader")
	_mat_crosta.set_shader_parameter("ruido", v._tex)
	var agua_sh: Shader = load("res://scripts/shaders/fonte_quente.gdshader")
	for k in tn.fontes.size():
		var f: Array = tn.fontes[k]
		var p := {"c": f[0], "r": float(f[1]), "agua": float(f[2]) - 0.01, "forca": float(f[3])}
		p["tom"] = TONS[k] if k < TONS.size() else 3
		p["verdade"] = _contorno(p["c"], p["r"], p["agua"])
		p["contorno"] = _alisar(p["verdade"], 10)
		p["crosta"] = 1.45 * _largura(p["r"])
		_saida(p)
		pocas.append(p)
		_agua(p, agua_sh, k)
		_crosta(p)
	_ligar_chao()
	_lamas()
	_geiser()
	_sons.call_deferred()  # o som toca já no laço: precisa estar na árvore
	_meias.call_deferred()
	set_process(true)


## Quanto a crosta é larga: 1 nas poças pequenas, até 1,6 no Olho Azul.
func _largura(r: float) -> float:
	return lerpf(1.0, 1.6, clampf((r - 6.0) / 18.0, 0.0, 1.0))


# ---------------------------------------------------------------- a beira

func _contorno(c: Vector2, r: float, agua: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(ANGULOS)
	for i in ANGULOS:
		var a := TAU * i / ANGULOS
		var dir := Vector2(cos(a), sin(a))
		var achou := -1.0
		var ant := altura_malha(c.x + dir.x * r * 0.4, c.y + dir.y * r * 0.4)
		var d := r * 0.4 + 0.05
		while d < r + 6.0:
			var hh := altura_malha(c.x + dir.x * d, c.y + dir.y * d)
			if hh >= agua:
				achou = d - 0.05 * (hh - agua) / maxf(0.001, hh - ant)
				break
			ant = hh
			d += 0.05
		out[i] = achou if achou > 0.0 else r + 0.8
	return _alisar(out, 2)


## A beira que se vê (crosta e faixas) é a de verdade bem alisada: a grade de 4 m do chão deixava a poça
## poligonal. A água vai até a de verdade ou a alisada, a que for mais longe (o que sobra fica embaixo do chão
## ou da crosta, que é larga o bastante para cobrir a diferença).
static func _alisar(c: PackedFloat32Array, vezes: int) -> PackedFloat32Array:
	var out := c.duplicate()
	for _p in vezes:
		var b := out.duplicate()
		for i in ANGULOS:
			out[i] = 0.25 * b[(i + ANGULOS - 1) % ANGULOS] + 0.5 * b[i] + 0.25 * b[(i + 1) % ANGULOS]
	return out


## O raio da beira num ângulo qualquer (entre os 64 guardados).
static func raio_em(contorno: PackedFloat32Array, a: float) -> float:
	var f := fposmod(a, TAU) / TAU * ANGULOS
	var i := int(f) % ANGULOS
	return lerpf(contorno[i], contorno[(i + 1) % ANGULOS], f - floorf(f))


## Por onde a poça transborda: o lado mais baixo em volta dela. O canal desce por ali.
func _saida(p: Dictionary) -> void:
	var c: Vector2 = p["c"]
	var r: float = p["r"]
	var menor := INF
	var melhor := Vector2.RIGHT
	for i in 48:
		var a := TAU * i / 48.0
		var dir := Vector2(cos(a), sin(a))
		var hh := 0.0
		for d: float in [r + 6.0, r + 10.0, r + 16.0]:
			hh += altura_malha(c.x + dir.x * d, c.y + dir.y * d)
		if hh < menor:
			menor = hh
			melhor = dir
	p["saida"] = melhor
	p["canal"] = 6.0 + r * 1.6


# ---------------------------------------------------------------- a água

func _agua(p: Dictionary, sh: Shader, k: int) -> void:
	var c: Vector2 = p["c"]
	var r: float = p["r"]
	var y: float = p["agua"]
	var n := 96 if r > 12.0 else (64 if r > 6.0 else 48)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var r0 := maxf(raio_em(p["contorno"], a0), raio_em(p["verdade"], a0)) + 0.3
		var r1 := maxf(raio_em(p["contorno"], a1), raio_em(p["verdade"], a1)) + 0.3
		# a frente para cima (na Godot a frente gira no sentido horário; visto de cima, de a0 para a1 é horário)
		st.add_vertex(Vector3(0.0, 0.0, 0.0))
		st.add_vertex(Vector3(cos(a0) * r0, 0.0, sin(a0) * r0))
		st.add_vertex(Vector3(cos(a1) * r1, 0.0, sin(a1) * r1))
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("centro", c)
	mat.set_shader_parameter("raio", r)
	mat.set_shader_parameter("ruido", v._tex)
	mat.set_shader_parameter("tom", float(p["tom"]))
	mat.set_shader_parameter("bolhas", 1.0 if k < 6 else 0.35)
	var mi := MeshInstance3D.new()
	mi.name = "FonteQuente"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = Vector3(c.x, y, c.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- a crosta de sínter na beira

const CREME := Color(0.2, 0.17, 0.085)
const CREME_SECO := Color(0.19, 0.165, 0.1)
const SINTER := Color(0.17, 0.168, 0.16)
const SINTER2 := Color(0.15, 0.148, 0.14)
const CREME_CHAO := Color(0.19, 0.16, 0.075)  # o fio creme do chão logo depois da crosta (fontes_chao)

## Uma faixa baixa em volta da beira: entra na água, sobe numa crista ondulada de mineral branco e desce até o
## chão por fora, onde acaba em creme molhado (a primeira faixa do chão). Do lado da saída a crista baixa e
## fica molhada: a água passa por cima.
func _crosta(p: Dictionary) -> void:
	var c: Vector2 = p["c"]
	var r: float = p["r"]
	var ag: float = p["agua"]
	var g := _largura(r)
	var n := 128 if r > 12.0 else (80 if r > 6.0 else 56)
	var saida: Vector2 = p["saida"]
	var a_saida := atan2(saida.y, saida.x)
	var offs := [-0.55, -0.2, 0.15, 0.55, 1.0, 1.45]
	var aneis: Array = []  # [pontos, cores]
	for i in n:
		var a := TAU * i / n
		var dir := Vector2(cos(a), sin(a))
		var rc := raio_em(p["contorno"], a)
		var na_saida := clampf(1.0 - absf(wrapf(a - a_saida, -PI, PI)) / 0.35, 0.0, 1.0)
		var calombo := 0.5 + 0.5 * sin(a * 23.0 + sin(a * 7.0) * 2.0) * sin(a * 11.0 + 1.3)
		var pts: Array[Vector3] = []
		var cores: Array[Color] = []
		for j in offs.size():
			var d: float = rc + float(offs[j]) * g
			var px := c.x + dir.x * d
			var pz := c.y + dir.y * d
			var hh := altura_malha(px, pz)
			var y := 0.0
			var cor := SINTER
			match j:
				0:
					y = ag - 0.05
					cor = CREME
					cor.a = 1.0
				1:
					y = ag + lerpf(0.05 + calombo * 0.03, 0.02, na_saida)
					cor = CREME
					cor.a = 0.85
				2:
					y = lerpf(maxf(ag + 0.13, hh + 0.06) + calombo * 0.06 * g, ag + 0.04, na_saida)
					cor = SINTER.lerp(CREME, na_saida)
					cor.a = lerpf(0.15, 0.9, na_saida)
				3:
					y = lerpf(maxf(hh + 0.06, ag + 0.03), maxf(hh + 0.04, ag + 0.01), na_saida)
					cor = SINTER2.lerp(CREME_CHAO, 0.5).lerp(CREME, na_saida)
					cor.a = lerpf(0.0, 0.8, na_saida)
				4:
					y = hh + 0.04
					cor = CREME_CHAO
					cor.a = 0.0
				5:
					y = hh - 0.08
					cor = CREME_CHAO
					cor.a = 0.0
			pts.append(Vector3(px, y, pz))
			cores.append(cor)
		aneis.append([pts, cores])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a0: Array = aneis[i]
		var a1: Array = aneis[(i + 1) % n]
		for j in offs.size() - 1:
			var q := [a0[0][j], a1[0][j], a1[0][j + 1], a0[0][j + 1]]
			var qc := [a0[1][j], a1[1][j], a1[1][j + 1], a0[1][j + 1]]
			_quad_cima(st, q, qc)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Crosta"
	mi.mesh = st.commit()
	mi.material_override = _mat_crosta
	add_child(mi)


## Dois triângulos de frente para cima (a ordem dos vértices sai da normal, pelas diagonais: vale também para
## o quadrado que encosta no centro, com dois cantos no mesmo ponto).
static func _quad_cima(st: SurfaceTool, q: Array, qc: Array) -> void:
	var ordem := [0, 1, 2, 0, 2, 3]
	var n := ((q[2] as Vector3) - (q[0] as Vector3)).cross((q[1] as Vector3) - (q[3] as Vector3))
	if n.y < 0.0:
		ordem = [0, 2, 1, 0, 3, 2]
	for k in ordem:
		st.set_color(qc[k])
		st.add_vertex(q[k])


# ---------------------------------------------------------------- o chão em volta (fontes_chao)

func _ligar_chao() -> void:
	var m: ShaderMaterial = tn._mat_chao
	if m == null:
		return
	var img := Image.create(ANGULOS, 16, false, Image.FORMAT_RF)
	var vp := PackedVector4Array()
	var vs := PackedVector4Array()
	for k in 16:
		if k < pocas.size():
			var p: Dictionary = pocas[k]
			var c: Vector2 = p["c"]
			var sd: Vector2 = p["saida"]
			vp.append(Vector4(c.x, c.y, p["r"], p["crosta"]))
			vs.append(Vector4(sd.x, sd.y, p["canal"], p["agua"]))
			for i in ANGULOS:
				img.set_pixel(i, k, Color((p["contorno"] as PackedFloat32Array)[i], 0, 0))
		else:
			vp.append(Vector4.ZERO)
			vs.append(Vector4.ZERO)
	m.set_shader_parameter("fq_n", mini(pocas.size(), 16))
	m.set_shader_parameter("fq_pocas", vp)
	m.set_shader_parameter("fq_saida", vs)
	m.set_shader_parameter("fq_bacia", Vector3(_olho.x, _olho.y, BACIA))
	m.set_shader_parameter("fq_contorno", ImageTexture.create_from_image(img))


# ---------------------------------------------------------------- as poças de lama

## Duas poças de lama cinza no chão plano da bacia, longe da água e dos respiros.
func _lamas() -> void:
	var tentativas := 0
	while lamas.size() < 2 and tentativas < 4000:
		tentativas += 1
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(45.0, 140.0)
		var x := _olho.x + cos(a) * d
		var z := _olho.y + sin(a) * d
		var ok := true
		for p in pocas:
			if Vector2(x, z).distance_to(p["c"]) < float(p["r"]) + 22.0:
				ok = false
		for q: Vector2 in tn.respiros:
			if Vector2(x, z).distance_to(q) < 20.0:
				ok = false
		for l in lamas:
			if Vector2(x, z).distance_to(Vector2(l.x, l.z)) < 45.0:
				ok = false
		if not ok or tn.perto_dagua(x, z, 10.0):
			continue
		var baixo := INF
		var alto := -INF
		for i in 12:
			var b := TAU * i / 12.0
			for rr: float in [0.0, LAMA_RAIO * 0.5, LAMA_RAIO + 1.2]:
				var hh := altura_malha(x + cos(b) * rr, z + sin(b) * rr)
				baixo = minf(baixo, hh)
				alto = maxf(alto, hh)
		if alto - baixo > 0.3:
			continue
		var y := 0.0
		for i in 12:
			var b := TAU * i / 12.0
			y = maxf(y if i > 0 else -INF, altura_malha(x + cos(b) * LAMA_RAIO * 0.9, z + sin(b) * LAMA_RAIO * 0.9))
		y = maxf(y, altura_malha(x, z)) + 0.04
		lamas.append(Vector3(x, y, z))
		_lama(Vector3(x, y, z))
		_lama_t.append(_rng.randf_range(0.5, 2.0))
	var m: ShaderMaterial = tn._mat_chao
	if m:
		var vl := PackedVector4Array([Vector4.ZERO, Vector4.ZERO])
		for i in lamas.size():
			vl[i] = Vector4(lamas[i].x, lamas[i].z, LAMA_RAIO, 0.0)
		m.set_shader_parameter("fq_lamas", vl)


func _lama(p: Vector3) -> void:
	# a lama: um disco com anéis de pontos (os domos mexem nos vértices)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var aneis := 26
	var lados := 96
	for j in aneis:
		var ra := LAMA_RAIO * float(j) / aneis
		var rb := LAMA_RAIO * float(j + 1) / aneis
		for i in lados:
			var a0 := TAU * i / lados
			var a1 := TAU * (i + 1) / lados
			var q := [Vector3(cos(a0) * ra, 0, sin(a0) * ra), Vector3(cos(a1) * ra, 0, sin(a1) * ra),
				Vector3(cos(a1) * rb, 0, sin(a1) * rb), Vector3(cos(a0) * rb, 0, sin(a0) * rb)]
			_quad_cima(st, q, [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	st.generate_normals()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/fonte_lama.gdshader")
	mat.set_shader_parameter("ruido", v._tex)
	mat.set_shader_parameter("raio", LAMA_RAIO)
	var mi := MeshInstance3D.new()
	mi.name = "Lama"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# a borda: lama seca e mineral, que sobe da lama e desce até o chão
	var bst := SurfaceTool.new()
	bst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 64
	var offs := [-0.3, 0.0, 0.3, 0.7]
	var cores := [Color(0.06, 0.055, 0.048, 1.0), Color(0.075, 0.07, 0.06, 0.55), Color(0.085, 0.08, 0.07, 0.1),
		Color(0.09, 0.085, 0.075, 0.0)]
	var linhas: Array = []
	for i in n:
		var a := TAU * i / n
		var cal := 0.5 + 0.5 * sin(a * 9.0 + 0.7) * sin(a * 5.0)
		var pts: Array = []
		for j in offs.size():
			var d: float = LAMA_RAIO + float(offs[j])
			var px := p.x + cos(a) * d
			var pz := p.z + sin(a) * d
			var hh := altura_malha(px, pz)
			var y: float = [p.y - 0.04, p.y + 0.04 + cal * 0.04, maxf(p.y, hh + 0.04), hh - 0.07][j]
			pts.append(Vector3(px, y, pz))
		linhas.append(pts)
	for i in n:
		var l0: Array = linhas[i]
		var l1: Array = linhas[(i + 1) % n]
		for j in offs.size() - 1:
			_quad_cima(bst, [l0[j], l1[j], l1[j + 1], l0[j + 1]], [cores[j], cores[j], cores[j + 1], cores[j + 1]])
	bst.generate_normals()
	var bmi := MeshInstance3D.new()
	bmi.name = "BordaLama"
	bmi.mesh = bst.commit()
	bmi.material_override = _mat_crosta
	add_child(bmi)


# ---------------------------------------------------------------- o gêiser

## O gêiser fica no respiro mais perto do Olho Azul (o vapor dele continua saindo entre um jorro e outro).
func _geiser() -> void:
	if tn.respiros.is_empty():
		return
	var melhor: Vector2 = tn.respiros[0]
	for q: Vector2 in tn.respiros:
		if q.distance_to(_olho) < melhor.distance_to(_olho):
			melhor = q
	geiser_em = melhor
	geiser = GeiserFonte.new()
	geiser.name = "Geiser"
	geiser.fontes = self
	geiser.position = Vector3(melhor.x, altura_malha(melhor.x, melhor.y), melhor.y)
	add_child(geiser)


# ---------------------------------------------------------------- o som

func _sons() -> void:
	for k in pocas.size():
		var p: Dictionary = pocas[k]
		if k >= 7 and k % 2 == 0:
			continue  # os degraus ficam colados: um som a cada dois
		var no := Node3D.new()
		var c: Vector2 = p["c"]
		no.position = Vector3(c.x, float(p["agua"]) + 0.3, c.y)
		add_child(no)
		var r: float = p["r"]
		SomAmbiente.na_natureza(Som.laco3d(no, "fonte_borbulha_loop", -6.0 if k == 0 else -10.0, 5.0 + r * 0.3, 30.0 + r * 1.5))
	for q: Vector2 in tn.respiros:
		var no := Node3D.new()
		no.position = Vector3(q.x, altura_malha(q.x, q.y) + 0.4, q.y)
		add_child(no)
		SomAmbiente.na_natureza(Som.laco3d(no, "respiro_loop", -12.0, 3.0, 22.0))


## As bolhas da lama estouram de vez em quando, com o "blop", só com alguém perto.
func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for i in lamas.size():
		if cam.global_position.distance_to(lamas[i]) > 40.0:
			continue
		_lama_t[i] -= delta
		if _lama_t[i] <= 0.0:
			_lama_t[i] = _rng.randf_range(1.2, 3.6)
			var ang := _rng.randf() * TAU
			SomAmbiente.na_natureza(Som.toque3d(self, Som.variacao("lama", 3), lamas[i] + Vector3(cos(ang), 0.05, sin(ang)) * LAMA_RAIO * 0.4, -8.0, 4.0, 30.0))


# ---------------------------------------------------------------- a meia branca dos pinheiros secos

## Os pinheiros secos da bacia (TerraNova._secas, modelos q_seca) ganham por cima a "meia" de mineral branco.
func _meias() -> void:
	var malhas := {}
	for nome: String in ["q_seca_a", "q_seca_b", "q_seca_c", "q_seca_d", "q_seca_e"]:
		for par: Array in v._malhas.get(nome, []):
			malhas[par[0]] = true
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/fonte_meia.gdshader")
	mat.set_shader_parameter("ruido", v._tex)
	var achadas := 0
	for no in v.get_children():
		var mmi := no as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or not malhas.has(mmi.multimesh.mesh):
			continue
		if Vector2(mmi.global_position.x, mmi.global_position.z).distance_to(_olho) > BACIA:
			continue
		mmi.material_overlay = mat
		achadas += 1
	print("fontes quentes: %d poças, %d lamas, meia branca em %d grupos de pinheiros" % [pocas.size(), lamas.size(), achadas])
