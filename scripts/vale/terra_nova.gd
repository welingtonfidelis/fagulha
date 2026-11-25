class_name TerraNova
extends Node3D
## A terra nova do noroeste (2026-11-21, doc §137): um segundo pedaço de terreno, ao lado da ilha de hoje e
## separado dela por um canal, com a Montanha do Degelo na ponta. Relevo, cobertura, rios e lagos vêm prontos de
## tools/vale/mapa_terra_nova.py (assets/vale/mapa/terra_nova_*).
##
## O chão é desenhado em blocos de 200 m, cada um em quatro níveis de detalhe (NIVEIS). Os blocos são grades
## planas iguais, que o shader terra_nova_chao levanta pela textura de alturas: montar é rápido e o detalhe cai
## com a distância sem refazer malha. A colisão é uma grade de alturas só. O Vale pergunta a altura, a água e a
## cobertura daqui quando o ponto sai da ilha de hoje.

const DADOS := "res://assets/vale/mapa/"
const X0 := -3900.0
const Z0 := -3900.0
const PASSO := 4.0
const NX := 1151
const NZ := 1101
const BLOCO := 200.0
const CELULAS := 50  # pontos da grade por lado de bloco
const FUNDO := -40.0  # o fundo do mar fora das grades (tools/vale/terra_unida.py, FUNDO_FUNDO)
const META_VELHA := 1500.0  # a ilha de hoje (Vale.F_META)
## [células por quadrado, de, até] em metros da câmera: o detalhe todo (4 m) até 650 m, depois 8, 20 e 40 m
const NIVEIS := [[1, 0.0, 650.0], [2, 650.0, 1500.0], [5, 1500.0, 3300.0], [10, 3300.0, 0.0]]
const LAGO_SOBRA := 18.0  # até onde o espelho dos lagos pode passar do raio (só onde a água chega, `_mapear_lagos`)
const LAGO_FUNDO := 0.5  # a água do lago só se espalha por pontos da grade pelo menos isto abaixo do nível
const FONTE_SOBRA := 0.8  # nas fontes quentes a beira de mineral é estreita
const PONTA_A := Vector2(150, -1790)  # a ponta leste da terra nova (área A), onde a praia termina
const NAVIO := Vector2(-450, -1713)  # o navio encalhado, na praia que dá para o canal e para as Torres
const NAVIO_RUMO := PI + 0.1  # a proa para o oeste, quase paralela à costa

var h := PackedFloat32Array()
var h_longe := PackedFloat32Array()  # o relevo dos blocos de longe (cânions dos rios abertos)
var cob := PackedByteArray()  # dois bytes por ponto: o código da cobertura e quanto o lugar é boreal (0 a 255)
var rios: Array = []  # Vale.Curso
var faixas := PackedFloat32Array()  # a meia largura da fita de cada rio
var lagos: Array = []  # [Vector2(x, z), raio, nível]
var _lago_mapa: Array = []  # por lago: [gx0, gz0, células em x, células em z, PackedByteArray (1 = célula com água)]
var fontes: Array = []  # as fontes quentes da área B: [Vector2(x, z), raio, nível, força do vapor]; a primeira é o Olho Azul
var respiros: Array[Vector2] = []  # os furos que só soltam vapor
var quedas: Array = []  # [Vector3 beira, Vector3 pé, rio] de cada queda d'água (o pé desenhado: `cortinas_feitas`)
var canais := PackedFloat32Array()  # a meia largura do canal cavado de cada rio (no alto, 60% disso)
var cortinas_feitas: Array = []  # [Vector3 beira, Vector3 pé] de cada cortina, onde ela cai de verdade (testes e fotos)
var pico := Vector3.ZERO
var blocos := 0  # blocos de chão desenhados (testes)
var telhas := 0  # telhas de colisão
var arvores := 0
# a praia da área A: os lugares dos bichos (a VidaVale cria e apaga eles) e os troncos que o mar trouxe
var praia_caranguejos: Array[Vector3] = []
var praia_gaivotas: Array[Vector3] = []  # bandos pousados na areia
var praia_focas: Array[Vector3] = []
var praia_ar: Array[Vector3] = []  # centros das voltas das gaivotas no ar
var troncos := 0
var _x1 := 0.0
var _z1 := 0.0
var _mat_chao: ShaderMaterial
var tex_cob: ImageTexture  # a cobertura em textura (o chão e a pele da Boca do Degelo)


func carregar() -> bool:
	h = FileAccess.get_file_as_bytes(DADOS + "terra_nova_alturas.bin").to_float32_array()
	cob = FileAccess.get_file_as_bytes(DADOS + "terra_nova_cobertura.bin")
	if h.size() != NX * NZ or cob.size() != NX * NZ * 2:
		push_error("terra nova: dados ausentes ou do tamanho errado em %s" % DADOS)
		h = PackedFloat32Array()
		return false
	h_longe = FileAccess.get_file_as_bytes(DADOS + "terra_nova_alturas_longe.bin").to_float32_array()
	if h_longe.size() != h.size():
		h_longe = h
	_x1 = X0 + (NX - 1) * PASSO
	_z1 = Z0 + (NZ - 1) * PASSO
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(DADOS + "terra_nova_rios.json"))
	if not (j is Dictionary):
		return true
	var pc: Array = j["pico"]
	pico = Vector3(pc[0], pc[1], pc[2])
	for r: Dictionary in j["rios"]:
		var c := Vale.Curso.new()
		var pts := PackedVector2Array()
		for p: Array in r["pts"]:
			pts.append(Vector2(p[0], p[1]))
		c.pts = pts
		c.fechar()
		c.niv = PackedFloat32Array(r["niv"])
		c.fita_de = 0.0
		c.fita_ate = c.total()
		rios.append(c)
		faixas.append(float(r["faixa"]))
		canais.append(float(r.get("canal", 6.0)))
		for q: Array in r["quedas"]:
			quedas.append([Vector3(q[0], q[2], q[1]), Vector3(q[0], q[3], q[1]), rios.size() - 1])
	for l: Dictionary in j["lagos"]:
		lagos.append([Vector2(l["x"], l["z"]), float(l["raio"]), float(l["nivel"])])
	_mapear_lagos()
	for f: Dictionary in j.get("fontes", []):
		fontes.append([Vector2(f["x"], f["z"]), float(f["raio"]), float(f["nivel"]), float(f["forca"])])
	for q: Dictionary in j.get("respiros", []):
		respiros.append(Vector2(q["x"], q["z"]))
	return true


## O ponto está na grade da terra nova (fora da ilha de hoje quem decide é o Vale).
func cobre(x: float, z: float) -> bool:
	return not h.is_empty() and x >= X0 and x <= _x1 and z >= Z0 and z <= _z1


func altura(x: float, z: float) -> float:
	var fx := clampf((x - X0) / PASSO, 0.0, NX - 1.001)
	var fz := clampf((z - Z0) / PASSO, 0.0, NZ - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var i := iz * NX + ix
	return lerpf(lerpf(h[i], h[i + 1], fx - ix), lerpf(h[i + NX], h[i + NX + 1], fx - ix), fz - iz)


func _indice(x: float, z: float) -> int:
	var ix := clampi(roundi((x - X0) / PASSO), 0, NX - 1)
	var iz := clampi(roundi((z - Z0) / PASSO), 0, NZ - 1)
	return iz * NX + ix


## 0 campo, 1 mata, 2 mata fechada, 3 flores, 4 areia, 5 neve, 6 pedra, 7 campina alpina, 8 cascalho do rio,
## 9 duna (areia com capim ralo).
func cobertura(x: float, z: float) -> int:
	return cob[_indice(x, z) * 2]


## Quanto o lugar é dos pés da montanha (mata boreal), de 0 a 1.
func boreal(x: float, z: float) -> float:
	return cob[_indice(x, z) * 2 + 1] / 255.0


func normal_em(x: float, z: float) -> Vector3:
	var e := PASSO
	return Vector3(altura(x - e, z) - altura(x + e, z), 2.0 * e, altura(x, z - e) - altura(x, z + e)).normalized()


## O nível da água doce (rios e lagos) no ponto, se o chão `hh` estiver abaixo dela; -INF se não. O mar é do Vale.
func agua(x: float, z: float, hh: float) -> float:
	for k in rios.size():
		var c: Vale.Curso = rios[k]
		var f := faixas[k]
		var r := c.perto(x, z, f)
		if r.x < f:
			var n := c.nivel(r.y)
			if hh < n:
				return n
	for k in lagos.size():
		var l: Array = lagos[k]
		if hh < float(l[2]) and Vector2(x, z).distance_to(l[0]) < float(l[1]) + LAGO_SOBRA and _no_lago(k, x, z):
			return l[2]
	for f: Array in fontes:
		if Vector2(x, z).distance_to(f[0]) < float(f[1]) + FONTE_SOBRA and hh < float(f[2]):
			return f[2]
	return -INF


func perto_dagua(x: float, z: float, folga: float) -> bool:
	for k in rios.size():
		if (rios[k] as Vale.Curso).perto(x, z, faixas[k] + folga).x < faixas[k] * 0.6 + folga:
			return true
	for l: Array in lagos:
		if Vector2(x, z).distance_to(l[0]) < float(l[1]) + folga + 6.0:
			return true
	for f: Array in fontes:
		if Vector2(x, z).distance_to(f[0]) < float(f[1]) + folga + 2.0:
			return true
	return false


## O ar do lugar para o motor (doc §137.11): x é o frio da Montanha do Degelo (pela altitude e pela distância
## ao pico), y o calor da bacia das fontes (pela distância ao Olho Azul e pela altura sobre a água dele) e z o
## vapor da poça ou do respiro mais forte logo abaixo. Cada um de 0 a 1, em rampas suaves.
func clima(p: Vector3) -> Vector3:
	var q := Vector2(p.x, p.z)
	var frio := smoothstep(Ajustes.FRIO_ALT_INI, Ajustes.FRIO_ALT_CHEIO, p.y) * (1.0 - smoothstep(
			Ajustes.FRIO_RAIO, Ajustes.FRIO_RAIO_FIM, q.distance_to(Vector2(pico.x, pico.z))))
	if fontes.is_empty():
		return Vector3(frio, 0.0, 0.0)
	var olho: Vector2 = fontes[0][0]
	var d_olho := q.distance_to(olho)
	if d_olho > Ajustes.QUENTE_RAIO_FIM:
		return Vector3(frio, 0.0, 0.0)
	var quente := (1.0 - smoothstep(Ajustes.QUENTE_RAIO, Ajustes.QUENTE_RAIO_FIM, d_olho)) * (1.0 - smoothstep(
			Ajustes.QUENTE_TETO, Ajustes.QUENTE_TETO_FIM, p.y - float(fontes[0][2])))
	var vapor := 0.0
	for f: Array in fontes:
		vapor = maxf(vapor, _vapor_de(q, p.y, f[0], float(f[1]), float(f[2]), float(f[3])))
	for r: Vector2 in respiros:
		if q.distance_squared_to(r) < 36.0:
			vapor = maxf(vapor, _vapor_de(q, p.y, r, 1.2, altura(r.x, r.y), 1.0))
	return Vector3(frio, quente, vapor)


func _vapor_de(q: Vector2, y: float, centro: Vector2, raio: float, nivel: float, forca: float) -> float:
	var fora := q.distance_to(centro) - raio
	var acima := y - nivel
	if fora > Ajustes.FONTE_BEIRA or acima > Ajustes.FONTE_TETO:
		return 0.0
	return forca * (1.0 - smoothstep(0.0, Ajustes.FONTE_BEIRA, fora)) * (1.0 - smoothstep(
			Ajustes.RASANTE_ALTURA, Ajustes.FONTE_TETO, acima))


## A força da fonte quente em cuja água o ponto está (a mesma conta de `agua`); 0 fora delas.
func fonte_em(x: float, z: float) -> float:
	for f: Array in fontes:
		if Vector2(x, z).distance_to(f[0]) < float(f[1]) + FONTE_SOBRA and altura(x, z) < float(f[2]):
			return float(f[3])
	return 0.0


# ---------------------------------------------------------------- montagem

func montar(v: Vale) -> void:
	if h.is_empty():
		return
	name = "TerraNova"
	BocaDegelo.cavar(self)  # rebaixa a grade debaixo da gruta antes de o chão e a colisão saírem dela
	_mapear_lagos()
	_chao(v)
	_colisao()
	_aguas(v)
	_fontes(v)
	Planicie.montar(self, v)
	_praia(v)
	Vilarejo.montar(v)


func _chao(v: Vale) -> void:
	var tex_h := ImageTexture.create_from_image(Image.create_from_data(NX, NZ, false, Image.FORMAT_RF, h.to_byte_array()))
	var tex_c := ImageTexture.create_from_image(Image.create_from_data(NX, NZ, false, Image.FORMAT_RG8, cob))
	tex_cob = tex_c
	_mat_chao = ShaderMaterial.new()
	_mat_chao.shader = load("res://scripts/shaders/terra_nova_chao.gdshader")
	_mat_chao.set_shader_parameter("ruido", v._tex)
	_mat_chao.set_shader_parameter("alturas", tex_h)
	_mat_chao.set_shader_parameter("alturas_longe", ImageTexture.create_from_image(Image.create_from_data(NX, NZ, false, Image.FORMAT_RF, h_longe.to_byte_array())))
	_mat_chao.set_shader_parameter("cobertura", tex_c)
	_mat_chao.set_shader_parameter("origem", Vector2(X0, Z0))
	_mat_chao.set_shader_parameter("passo", PASSO)
	_mat_chao.set_shader_parameter("tamanho", Vector2i(NX, NZ))
	var grades: Array = []
	for nv: Array in NIVEIS:
		grades.append(_grade(nv[0]))
	var nbx := int((NX - 1) / CELULAS)
	var nbz := int((NZ - 1) / CELULAS)
	for bz in nbz:
		for bx in nbx:
			var x0 := X0 + bx * BLOCO
			var z0 := Z0 + bz * BLOCO
			# o quadrado da ilha de hoje fica de fora (os blocos casam com a borda dele)
			if x0 >= -META_VELHA and x0 + BLOCO <= META_VELHA and z0 >= -META_VELHA and z0 + BLOCO <= META_VELHA:
				continue
			var mn := INF
			var mx := -INF
			for j in range(0, CELULAS + 1, 2):
				for i in range(0, CELULAS + 1, 2):
					var hv := h[(bz * CELULAS + j) * NX + bx * CELULAS + i]
					mn = minf(mn, hv)
					mx = maxf(mx, hv)
			if mx < FUNDO + 0.6:
				continue  # só fundo de mar: o fundo do Vale (_mar) já cobre
			blocos += 1
			var caixa := AABB(Vector3(0, mn - 12.0, 0), Vector3(BLOCO, mx - mn + 14.0, BLOCO))
			for k in NIVEIS.size():
				var nv: Array = NIVEIS[k]
				var mi := MeshInstance3D.new()
				mi.mesh = grades[k]
				mi.material_override = _mat_chao
				mi.position = Vector3(x0, 0, z0)
				mi.custom_aabb = caixa
				mi.visibility_range_begin = nv[1]
				mi.visibility_range_end = nv[2]
				if k >= 2:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mi)


## Uma grade plana de um bloco, com um quadrado a cada `k` células, e a saia: os pontos da borda repetidos,
## marcados no UV2.x para o shader descer (esconde a fresta entre blocos de detalhes diferentes). O UV2.y leva `k`.
func _grade(k: int) -> ArrayMesh:
	var n := CELULAS / k
	var lado := n + 1
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in lado:
		for i in lado:
			verts.append(Vector3(i * k * PASSO, 0.0, j * k * PASSO))
			nrms.append(Vector3.UP)
			uv2s.append(Vector2(0, k))
	for j in n:
		for i in n:
			var a := j * lado + i
			idx.append_array(PackedInt32Array([a, a + 1, a + lado + 1, a, a + lado + 1, a + lado]))
	# a borda, em volta, e a saia embaixo dela (as duas faces, para não depender do sentido)
	var borda := PackedInt32Array()
	for i in lado:
		borda.append(i)
	for j in range(1, lado):
		borda.append(j * lado + n)
	for i in range(n - 1, -1, -1):
		borda.append(n * lado + i)
	for j in range(n - 1, 0, -1):
		borda.append(j * lado)
	borda.append(0)
	for t in borda.size() - 1:
		var a: int = borda[t]
		var b: int = borda[t + 1]
		var sa := verts.size()
		verts.append(verts[a])
		verts.append(verts[b])
		nrms.append(Vector3.UP)
		nrms.append(Vector3.UP)
		uv2s.append(Vector2(1, k))
		uv2s.append(Vector2(1, k))
		idx.append_array(PackedInt32Array([a, b, sa + 1, a, sa + 1, sa, a, sa + 1, b, a, sa, sa + 1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## A colisão em telhas de 512 m (129 × 129 pontos: quadradas e de potência de dois, o formato que o Jolt usa
## direto como grade de alturas). Telhas só de fundo de mar ficam de fora (a laje do Vale segura lá embaixo);
## dentro do quadrado da ilha de hoje os pontos descem bem abaixo do chão de lá (a colisão é a do Vale).
const TELHA := 128

func _colisao() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "ChaoTerraNova"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var lado := TELHA + 1
	for tz in ceili((NZ - 1) / float(TELHA)):
		for tx in ceili((NX - 1) / float(TELHA)):
			var dados := PackedFloat32Array()
			dados.resize(lado * lado)
			var mx := -INF
			for j in lado:
				var gz := tz * TELHA + j
				for i in lado:
					var gx := tx * TELHA + i
					var hv := FUNDO
					if gx < NX and gz < NZ:
						var x := X0 + gx * PASSO
						var z := Z0 + gz * PASSO
						hv = -40.0 if (absf(x) < META_VELHA - 2.0 and absf(z) < META_VELHA - 2.0) else h[gz * NX + gx]
					dados[i * lado + (TELHA - j)] = hv  # girada (ver abaixo)
					mx = maxf(mx, hv)
			if mx < FUNDO + 0.6:
				continue
			var forma := HeightMapShape3D.new()
			forma.map_width = lado
			forma.map_depth = lado
			forma.map_data = dados
			var cs := CollisionShape3D.new()
			cs.shape = forma
			# o Jolt corta cada quadrado da grade pela outra diagonal (do canto (i + 1, j) ao (i, j + 1)); o chão
			# desenhado (_grade) corta do (i, j) ao (i + 1, j + 1). Em chão plano não muda nada, mas nos degraus das
			# fontes quentes a colisão ficava até 2 m fora do chão. Girada 90° a telha corta igual ao desenho.
			cs.rotation = Vector3(0.0, PI * 0.5, 0.0)
			cs.scale = Vector3(PASSO, 1.0, PASSO)
			cs.position = Vector3(X0 + (tx * TELHA + TELHA * 0.5) * PASSO, 0.0, Z0 + (tz * TELHA + TELHA * 0.5) * PASSO)
			corpo.add_child(cs)
			telhas += 1


## Os rios de degelo (fitas que descem em degraus: cada degrau vira uma cortina d'água) e os lagos, verde-água.
func _aguas(v: Vale) -> void:
	for k in rios.size():
		var c: Vale.Curso = rios[k]
		var f := faixas[k]
		var mat := _mat_degelo(v, 71 + k, 0.55)
		mat.set_shader_parameter("pela_fita", true)
		mat.set_shader_parameter("largura", f * 2.0)
		mat.set_shader_parameter("espuma_queda", 1.0)
		# a fita para na beira de cada queda e recomeça no pé da cortina (inteira, ela descia a queda numa rampa
		# que entrava no paredão no meio do caminho; visto pelo usuário em 2026-11-22)
		var de := 0.0
		var teto := INF
		for q: Array in quedas:
			if int(q[2]) != k:
				continue
			var beira: Vector3 = q[0]
			var sv_q := c.perto(beira.x, beira.z, 20.0).y
			# a meia largura do canal ali (o gerador abre de 60% a 100% de `canal` da nascente à foz)
			var meia := canais[k] * (0.6 + 0.4 * clampf(sv_q / c.total(), 0.0, 1.0))
			# a grade do chão (4 m) começa a descer o paredão um pouco antes da beira: a água para onde ainda
			# há leito embaixo, senão a ponta da fita ficava no ar, como uma placa
			var sv_b := maxf(sv_q - 0.1, 0.0)
			while sv_b > maxf(sv_q - 12.0, 12.0) and not _leito_firme(c, sv_b, beira.y, meia):
				sv_b -= 0.5
			# a fita de cima chega na beira com a largura da cortina (mais larga, as pontas ficavam no ar)
			_fita(c, f, de, sv_b, mat, meia * 1.15, teto)
			_cortina(v, c, k, sv_b, beira.y, (q[1] as Vector3).y, meia)
			teto = (q[1] as Vector3).y
			# a de baixo já começa inteira uns metros antes da beira, no nível do pé: esse começo fica dentro
			# da pedra, e o poço (mais largo que a cortina) fica todo coberto
			de = maxf(sv_b - 3.0, 0.0)
		_fita(c, f, de, c.total(), mat, 0.0, teto)
	for k in lagos.size():
		_espelho_lago(v, k)
	# atravessar uma queda d'água esfria o motor, como na cachoeira do vale
	for q: Array in cortinas_feitas:
		var topo: Vector3 = q[0]
		var pe: Vector3 = q[1]
		v.cortinas.append([topo, pe, 7.0])
		v.quedas.append((topo + pe) * 0.5)


## Onde a água de cada lago chega, na grade de 4 m. Antes o espelho era um disco 18 m mais largo que o lago, e
## onde a beira é fina e o chão desce do lado de fora a sobra ficava no ar por cima da encosta (o usuário viu em
## -2449, 307, -2551). Agora a água se espalha do meio do lago pelos pontos da grade abaixo do nível (pelo menos
## `LAGO_FUNDO`, para não vazar por uma sela rasa da beira) e molha também os rasos encostados neles. Uma célula
## tem água se tem ponto molhado e os outros pontos dela estão molhados ou acima do nível (ali o chão cobre o
## espelho); a que tem um ponto baixo de fora fica seca. O mesmo mapa serve ao desenho e a `agua`.
func _mapear_lagos() -> void:
	_lago_mapa.clear()
	for l: Array in lagos:
		var c: Vector2 = l[0]
		var nivel := float(l[2])
		var alcance := float(l[1]) + LAGO_SOBRA
		var gx0 := clampi(floori((c.x - alcance - X0) / PASSO), 0, NX - 2)
		var gz0 := clampi(floori((c.y - alcance - Z0) / PASSO), 0, NZ - 2)
		var gx1 := clampi(ceili((c.x + alcance - X0) / PASSO), 0, NX - 1)
		var gz1 := clampi(ceili((c.y + alcance - Z0) / PASSO), 0, NZ - 1)
		var nx := gx1 - gx0 + 1
		var nz := gz1 - gz0 + 1
		# 0 seco, 1 fundo (espalha), 2 raso molhado
		var no := PackedByteArray()
		no.resize(nx * nz)
		var dentro := func(i: int, j: int) -> bool:
			var x := X0 + (gx0 + i) * PASSO
			var z := Z0 + (gz0 + j) * PASSO
			return Vector2(x, z).distance_to(c) < alcance
		# a semente: o ponto mais fundo perto do meio
		var semente := Vector2i(-1, -1)
		var mais_baixo := INF
		for j in nz:
			for i in nx:
				var x := X0 + (gx0 + i) * PASSO
				var z := Z0 + (gz0 + j) * PASSO
				if Vector2(x, z).distance_to(c) < float(l[1]) * 0.5:
					var hh := h[(gz0 + j) * NX + gx0 + i]
					if hh < mais_baixo:
						mais_baixo = hh
						semente = Vector2i(i, j)
		var fila: Array[Vector2i] = []
		if semente.x >= 0 and mais_baixo < nivel - LAGO_FUNDO:
			no[semente.y * nx + semente.x] = 1
			fila.append(semente)
		while not fila.is_empty():
			var p: Vector2i = fila.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := p + d
				if q.x < 0 or q.y < 0 or q.x >= nx or q.y >= nz or no[q.y * nx + q.x] != 0:
					continue
				var hq := h[(gz0 + q.y) * NX + gx0 + q.x]
				if hq >= nivel or not dentro.call(q.x, q.y):
					continue
				if hq < nivel - LAGO_FUNDO:
					no[q.y * nx + q.x] = 1
					fila.append(q)
				else:
					no[q.y * nx + q.x] = 2
		var cel := PackedByteArray()
		cel.resize((nx - 1) * (nz - 1))
		for j in nz - 1:
			for i in nx - 1:
				var molhado := false
				var ok := true
				for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var a := (j + o.y) * nx + i + o.x
					if no[a] != 0:
						molhado = true
					elif h[(gz0 + j + o.y) * NX + gx0 + i + o.x] < nivel:
						ok = false
				if molhado and ok:
					cel[j * (nx - 1) + i] = 1
		_lago_mapa.append([gx0, gz0, nx - 1, nz - 1, cel])


func _no_lago(k: int, x: float, z: float) -> bool:
	if k >= _lago_mapa.size():
		return true
	var mp: Array = _lago_mapa[k]
	var i := floori((x - X0) / PASSO) - int(mp[0])
	var j := floori((z - Z0) / PASSO) - int(mp[1])
	if i < 0 or j < 0 or i >= int(mp[2]) or j >= int(mp[3]):
		return false
	return (mp[4] as PackedByteArray)[j * int(mp[2]) + i] == 1


## O espelho de um lago: um quadrado no nível da água em cada célula do mapa.
func _espelho_lago(v: Vale, k: int) -> void:
	var mp: Array = _lago_mapa[k]
	var nivel := float(lagos[k][2]) - 0.01
	var cel: PackedByteArray = mp[4]
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in int(mp[3]):
		for i in int(mp[2]):
			if cel[j * int(mp[2]) + i] != 1:
				continue
			var x := X0 + (int(mp[0]) + i) * PASSO
			var z := Z0 + (int(mp[1]) + j) * PASSO
			var b := verts.size()
			verts.append_array(PackedVector3Array([Vector3(x, nivel, z), Vector3(x + PASSO, nivel, z),
				Vector3(x, nivel, z + PASSO), Vector3(x + PASSO, nivel, z + PASSO)]))
			idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	if idx.is_empty():
		return
	var nrms := PackedVector3Array()
	nrms.resize(verts.size())
	nrms.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_INDEX] = idx
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "LagoDegelo"
	mi.mesh = malha
	mi.material_override = _mat_degelo(v, 81, 0.06)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## O chão do leito, no meio e nos lados do canal, continua perto do nível da água (não é o paredão de uma queda).
func _leito_firme(c: Vale.Curso, sv: float, topo: float, meia: float) -> bool:
	var p := c.ponto(sv)
	var dir := (c.ponto(sv + 1.0) - c.ponto(sv - 1.0)).normalized()
	var lado := Vector2(-dir.y, dir.x)
	for s: float in [-0.6, 0.0, 0.6]:
		var q := p + lado * meia * s
		if altura(q.x, q.y) < topo - 4.6:
			return false
	# e as margens, onde a fita termina, seguram a água
	for s: float in [-1.15, 1.15]:
		var q := p + lado * meia * s
		if altura(q.x, q.y) < topo - 0.05:
			return false
	return true


## Um trecho da fita d'água de um rio, de `de` até `ate` (em metros ao longo dele). Chegando numa queda a fita
## estreita para a largura da cortina nos últimos 10 m (`estreita_fim`; 0 não estreita). `teto`: a água não
## passa disso (o trecho depois de uma queda começa antes da beira, dentro da pedra, já no nível do pé).
var bordas_fita := PackedVector3Array()  # as pontas de cada fatia da fita (testes e fotos: a borda não pode ficar no ar)

func _fita(c: Vale.Curso, f: float, de: float, ate: float, mat: Material, estreita_fim := 0.0, teto := INF) -> void:
	if ate - de < 1.0:
		return
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var sv := de
	var kk := 0
	while true:
		var p := c.ponto(sv)
		var q := c.ponto(minf(sv + 1.0, c.total()))
		if q.distance_to(p) < 0.01:
			q = p + (p - c.ponto(sv - 1.0))
		var dir := (q - p).normalized() if q.distance_to(p) > 0.01 else Vector2(0, 1)
		var lado := Vector2(-dir.y, dir.x)
		var y := minf(c.nivel(sv), teto)
		var larg := f
		if estreita_fim > 0.0:
			larg = lerpf(larg, estreita_fim, smoothstep(ate - 10.0, ate - 0.5, sv))
		for sinal: float in [-1.0, 1.0]:
			var w := p + lado * larg * sinal
			verts.append(Vector3(w.x, y, w.y))
			bordas_fita.append(Vector3(w.x, y, w.y))
			nrms.append(Vector3.UP)
			uvs.append(Vector2(sinal * 0.5 + 0.5, sv / 22.0))
		if kk > 0:
			var b := kk * 2
			idx.append_array(PackedInt32Array([b - 2, b - 1, b + 1, b - 2, b + 1, b]))
		kk += 1
		if sv >= ate:
			break
		sv = minf(sv + 4.0, ate)
	if kk < 2:
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "RioDegelo"
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A cortina d'água de uma queda: da beira até o poço, um meio-cano que sai para a frente como um jato (uns
## 2,4 m/s na beira) e que se afasta mais do paredão onde o chão estiver no caminho, para a água nunca entrar
## na pedra. Embaixo, névoa de respingo. Devolve onde a fita recomeça, no pé.
func _cortina(v: Vale, c: Vale.Curso, k: int, sv: float, topo: float, pe: float, meia: float) -> float:
	var p0 := c.ponto(sv)
	var dir := (c.ponto(sv + 1.5) - c.ponto(maxf(sv - 1.5, 0.0))).normalized()
	var lado := Vector2(-dir.y, dir.x)
	var queda := topo - pe
	var linhas := clampi(int(queda / 2.0), 10, 32)
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var x_ant := 0.0
	for j in linhas + 1:
		var t := float(j) / linhas
		var y := topo - 0.05 - (queda + 0.3) * t
		# a água faz a curva na beira (até 0,6 m) e desce rente à rocha do meio do vão; as beiradas podem entrar
		# nas paredes do lado. Antes ela caía em arco e tinha de passar livre de parede a parede: num desfiladeiro
		# estreito ficava de 1 a 3 m na frente do paredão e parecia flutuar (doc §165)
		var x := maxf(x_ant, minf(1.6 * sqrt(2.0 * maxf(0.0, topo - y) / 9.8), 0.6))
		var tent := 0
		while tent < 80 and not _vao_livre(p0 + dir * x, lado, meia * 0.45, y - 0.6):
			x += 0.25
			tent += 1
		x_ant = x
		xs.append(x)
		ys.append(y)
	# a água com volume (QuedaDagua, doc §164), verde-água do degelo: o caminho é o lado de trás da água, a 0,3 m
	# do vão livre medido acima; mais grossa embaixo, e tanto mais quanto mais alta a queda; as costas achatadas,
	# coladas na rocha até as beiradas (doc §165)
	var pts := PackedVector3Array()
	for j in linhas + 1:
		var pp := p0 + dir * (xs[j] - 0.3)
		pts.append(Vector3(pp.x, ys[j], pp.y))
	var raiz := Node3D.new()
	raiz.name = "CachoeiraDegelo"
	add_child(raiz)
	var lado3 := Vector3(lado.x, 0, lado.y)
	var mats := QuedaDagua.materiais(v._tex, Color(0.13, 0.42, 0.48), Color(0.42, 0.72, 0.76), Color(0.7, 0.9, 0.9))
	QuedaDagua.queda(raiz, pts, lado3, meia * 2.2, meia * 2.5, 0.7, clampf(queda * 0.12, 1.4, 3.0), mats, "Cortina", CachoeiraAlta.COSTAS)
	var x_pe := xs[xs.size() - 1] + 1.0
	var pe2 := p0 + dir * x_pe
	cortinas_feitas.append([Vector3(p0.x, topo, p0.y), Vector3(pe2.x, pe, pe2.y)])
	_nevoa(Vector3(pe2.x, pe + 0.8, pe2.y), dir, meia)
	QuedaDagua.pe(raiz, Vector3(pe2.x, pe + 0.25, pe2.y), meia * 0.9, 91 + quedas.size() + int(sv))
	var ondas_em := pe2 + dir * 1.0
	QuedaDagua.ondas(raiz, Vector3(ondas_em.x, pe + 0.04, ondas_em.y), v._tex, clampf(meia * 2.4, 6.0, 13.0), Color(0.3, 0.66, 0.68))
	return sv + x_pe + 0.5


## Todo o vão da cortina na altura `y` está acima do chão, de um lado ao outro.
func _vao_livre(p: Vector2, lado: Vector2, meia: float, y: float) -> bool:
	for s: float in [-0.9, -0.45, 0.0, 0.45, 0.9]:
		var q := p + lado * meia * s
		if altura(q.x, q.y) > y:
			return false
	return true


## A névoa de respingo no pé de uma queda (como a da cachoeira do vale).
func _nevoa(onde: Vector3, dir: Vector2, meia: float) -> void:
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.vertex_color_use_as_albedo = true
	mp.albedo_color = Color(1, 1, 1, 0.22)
	if ResourceLoader.exists("res://assets/fx/kenney/smoke_04.png"):
		mp.albedo_texture = load("res://assets/fx/kenney/smoke_04.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(6.0, 6.0)
	quad.material = mp
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	var pp := ParticleProcessMaterial.new()
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pp.emission_box_extents = Vector3(meia * 1.3, 0.5, 2.5)
	pp.direction = Vector3(0, 1, 0)
	pp.spread = 40.0
	pp.initial_velocity_min = 1.2
	pp.initial_velocity_max = 3.0
	pp.gravity = Vector3(0, 0.2, 0)
	pp.scale_min = 0.8
	pp.scale_max = 1.8
	pp.color_ramp = gt
	var nev := GPUParticles3D.new()
	nev.name = "NevoaQueda"
	nev.amount = 30
	nev.lifetime = 3.4
	nev.process_material = pp
	nev.draw_pass_1 = quad
	nev.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nev.visibility_aabb = AABB(Vector3(-18, -4, -18), Vector3(36, 24, 36))
	add_child(nev)
	nev.global_position = onde
	nev.rotation.y = atan2(dir.x, dir.y)


func _mat_degelo(v: Vale, semente: int, veloc: float) -> ShaderMaterial:
	var mat := v._mat_rio(semente, veloc)
	mat.set_shader_parameter("raso", Color(0.30, 0.74, 0.72))
	mat.set_shader_parameter("fundo", Color(0.05, 0.36, 0.42))
	return mat


# ---------------------------------------------------------------- a mata boreal

## O pinheiral dos pés da montanha, com álamos (as bétulas amarelas) nas bordas e nas clareiras. Entra na mesma
## lista de árvores do Vale (colisão, folhas ao atravessar, troca por distância).
func plantar(v: Vale) -> void:
	if h.is_empty():
		return
	var fila: Array = []
	var guardado: Variant = Cache.ler("terra_nova_mata")
	if guardado is Array:
		fila = guardado
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = 137
		var passo := 10.5
		var z := Z0 + 20.0
		while z < _z1 - 20.0:
			var x := X0 + 20.0
			while x < _x1 - 20.0:
				var px := x + rng.randf_range(-4.2, 4.2)
				var pz := z + rng.randf_range(-4.2, 4.2)
				var sorte := rng.randf()
				var sorte2 := rng.randf()
				var esc := rng.randf_range(0.0, 1.0)
				var giro := rng.randf() * TAU
				x += passo
				if maxf(absf(px), absf(pz)) < META_VELHA + 20.0:
					continue
				var c := cobertura(px, pz)
				if c != 1 and c != 2:
					continue
				if sorte > (0.8 if c == 2 else 0.42):
					continue
				var hh := altura(px, pz)
				if hh < 3.0 or normal_em(px, pz).y < 0.78 or perto_dagua(px, pz, 6.0):
					continue
				var na_parede := false
				for viz: Vector2 in [Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)]:
					if normal_em(px + viz.x, pz + viz.y).y < 0.64:
						na_parede = true
				if na_parede:
					continue
				var u := Clareira.sorte_do_lugar(px, pz)
				var tipo := ""
				var s := 1.0
				if sorte2 < (0.82 if c == 2 else 0.45):
					tipo = Clareira.tipo_variado("pinheiro", u)
					s = lerpf(1.25, 2.15, esc) if c == 2 else lerpf(1.0, 1.7, esc)
				else:
					# os álamos: quase todos amarelos (o dourado no meio do pinheiral escuro)
					tipo = Clareira.tipo_variado("betula", u * 0.43)
					s = lerpf(0.95, 1.5, esc)
				fila.append([tipo, Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * s), Vector3(px, hh - 0.15, pz))])
			z += passo
		Cache.gravar("terra_nova_mata", fila)
	fila = fila.filter(func(item: Array) -> bool:
		var o: Vector3 = (item[1] as Transform3D).origin
		return not BocaDegelo.dentro(o.x, o.z, 4.0))
	fila.append_array(_secas())
	fila.append_array(Planicie.arvores(self))
	fila.append_array(Vilarejo.arvores(v))
	# o lugar dos marcos de longe fica sem mata (a clareira da Árvore Branca, a igrejinha, o comboio)
	fila = fila.filter(func(item: Array) -> bool:
		var o: Vector3 = (item[1] as Transform3D).origin
		return not MarcosTerraNova.sem_mata(o.x, o.z))
	arvores = fila.size()
	var primeiro := v.arv_pos.size()
	for item: Array in fila:
		var xf: Transform3D = item[1]
		v.arv_pos.append(xf.origin)
		v.arv_escala.append(xf.basis.get_scale().x * 0.8)
		v.arv_tipo.append(0 if String(item[0]).contains("pinheiro") else 1)
		v.arv_nome.append(item[0])
	for i in range(primeiro, v.arv_pos.size()):
		var cel := Vector2i(floori(v.arv_pos[i].x / Clareira.CELULA_ARVORE), floori(v.arv_pos[i].z / Clareira.CELULA_ARVORE))
		var l: PackedInt32Array = v._grade_arv.get(cel, PackedInt32Array())
		l.append(i)
		v._grade_arv[cel] = l
	v.arvores_fora += fila.size()
	var grupos := {}
	for item: Array in fila:
		var xf: Transform3D = item[1]
		var chave := "%s|%d|%d" % [item[0], floori(xf.origin.x / 100.0), floori(xf.origin.z / 100.0)]
		if not grupos.has(chave):
			grupos[chave] = []
		(grupos[chave] as Array).append(xf)
	for chave: String in grupos:
		var xfs: Array = grupos[chave]
		v._multi(chave.split("|")[0], xfs, v._centro(xfs), 0.0, Clareira.TROCA_ARVORE, true)
	for g: Array in v._por_bloco(fila, 200.0, true):
		v._multi(g[0], g[1], v._centro(g[1]), Clareira.TROCA_ARVORE, Clareira.TROCA_VULTO, false)
	for g2: Array in v._por_bloco(fila, 400.0, true, true):
		v._multi(g2[0], g2[1], v._centro(g2[1]), Clareira.TROCA_VULTO, Vale.VULTO_ATE, false)
	print("terra nova: %d blocos de chão, %d telhas de colisão, %d árvores, %d rios, %d lagos, %d quedas" % [blocos, telhas, arvores, rios.size(), lagos.size(), quedas.size()])


# ---------------------------------------------------------------- as fontes quentes da área B

## As fontes quentes (FontesQuentes: a água até a beira de verdade, a crosta de sínter, as faixas e os canais
## no chão, as poças de lama, o gêiser e o som) e o vapor de cada poça e dos respiros (`VaporFonte`); o Olho
## Azul ganha ainda a coluna alta. O relevo e a bacia vêm prontos do gerador.
func _fontes(v: Vale) -> void:
	if fontes.is_empty():
		return
	var fq := FontesQuentes.montar(self, v)
	for k in fontes.size():
		var f: Array = fontes[k]
		var c: Vector2 = f[0]
		var vapor := VaporFonte.new()
		vapor.raio = f[1]
		vapor.forca = f[3]
		vapor.semente = 500 + k
		vapor.position = Vector3(c.x, f[2], c.y)
		add_child(vapor)
		if k == 0:
			var coluna := VaporFonte.new()
			coluna.raio = f[1]
			coluna.coluna = true
			coluna.semente = 600
			coluna.position = vapor.position
			add_child(coluna)
	for k in respiros.size():
		var p: Vector2 = respiros[k]
		var vapor := VaporFonte.new()
		vapor.raio = 1.2
		vapor.forca = 1.0
		vapor.semente = 700 + k
		vapor.position = Vector3(p.x, altura(p.x, p.y) + 0.2, p.y)
		if fq.geiser and p.is_equal_approx(fq.geiser_em):
			# o respiro do gêiser solta o vapor pela boca do cone
			vapor.raio = 0.45
			vapor.position = fq.geiser.position + Vector3.UP * (GeiserFonte.ALTO - 0.1)
			# e a coluna alta, o marco das fontes de longe (doc §168)
			var pluma := VaporFonte.new()
			pluma.pluma = true
			pluma.semente = 650
			pluma.position = vapor.position
			add_child(pluma)
		add_child(vapor)


## As árvores mortas da bacia das fontes: o chão quente e o mineral secaram o que crescia ali. Ficam em pé no
## brejo e na sínter, longe da água (troncos secos, do pacote do Quaternius).
func _secas() -> Array:
	var fila: Array = []
	if fontes.is_empty():
		return fila
	var c: Vector2 = fontes[0][0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 419
	var tentativas := 0
	while fila.size() < 46 and tentativas < 2000:
		tentativas += 1
		var ang := rng.randf() * TAU
		var d := rng.randf_range(45.0, 270.0)
		var px := c.x + cos(ang) * d
		var pz := c.y + sin(ang) * d
		var cb := cobertura(px, pz)
		if cb != 10 and cb != 12 and (cb != 0 or d > 220.0):
			continue
		if perto_dagua(px, pz, 8.0) or normal_em(px, pz).y < 0.9:
			continue
		var perto := false
		for q: Array in fila:
			if (q[1] as Transform3D).origin.distance_to(Vector3(px, (q[1] as Transform3D).origin.y, pz)) < 14.0:
				perto = true
				break
		if perto:
			continue
		var nome: String = ["q_seca_a", "q_seca_b", "q_seca_c", "q_seca_d", "q_seca_e"][rng.randi() % 5]
		var s := rng.randf_range(0.9, 1.5)
		fila.append([nome, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(px, altura(px, pz) - 0.15, pz))])
	return fila


# ---------------------------------------------------------------- a praia da área A

## A praia da ponta leste: varre a areia seca, separa os lugares dos caranguejos, das gaivotas e das focas,
## espalha troncos que o mar trouxe na parte alta da areia e põe um amontoado de pedras na beira, junto das
## focas. Sempre igual (semente fixa).
func _praia(v: Vale) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 211
	var areia: Array[Vector3] = []
	var z := -2720.0
	while z < -1600.0:
		var x := -1000.0
		while x < 260.0:
			var px := x + rng.randf_range(-2.5, 2.5)
			var pz := z + rng.randf_range(-2.5, 2.5)
			if cobertura(px, pz) == 4:
				var hh := altura(px, pz)
				if hh > 0.25 and hh < 3.4 and normal_em(px, pz).y > 0.96:
					areia.append(Vector3(px, hh, pz))
			x += 6.0
		z += 6.0
	for i in range(areia.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := areia[i]
		areia[i] = areia[j]
		areia[j] = tmp
	# o navio encalhado vem antes: os bichos e os troncos ficam fora dele
	Naufragio.montar(v, NAVIO, NAVIO_RUMO)
	var fora_do_navio: Array[Vector3] = []
	for p in areia:
		if Vector2(p.x, p.z).distance_to(NAVIO) > Naufragio.raio:
			fora_do_navio.append(p)
	areia = fora_do_navio
	# as focas ficam perto da ponta, na areia baixa
	var ponta: Array[Vector3] = []
	for p in areia:
		if Vector2(p.x, p.z).distance_to(PONTA_A) < 450.0:
			ponta.append(p)
	_escolher(ponta, praia_focas, 0.3, 1.0, 130.0, 2)
	_escolher(areia, praia_caranguejos, 0.3, 1.2, 70.0, 14, praia_focas, 25.0)
	_escolher(areia, praia_gaivotas, 1.0, 3.0, 190.0, 5, praia_focas, 60.0)
	_escolher(areia, praia_ar, 0.25, 2.0, 420.0, 2)
	var corpo := StaticBody3D.new()
	corpo.name = "TroncosDaPraia"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var feitos: Array[Vector3] = []
	for p in areia:
		if troncos >= 44:
			break
		if p.y < 1.5 or p.y > 3.2 or _perto_de(p, feitos, 24.0) or _perto_de(p, praia_focas, 14.0):
			continue
		feitos.append(p)
		_tronco(v, corpo, p, rng)
	# as pedras na beira, ao lado de cada lugar das focas: umas no seco, outras com a água batendo
	for f in praia_focas:
		var postas := 0
		for k in 60:
			if postas >= 6:
				break
			var ang := rng.randf() * TAU
			var d := rng.randf_range(9.0, 34.0)
			var px := f.x + cos(ang) * d
			var pz := f.z + sin(ang) * d
			var hh := altura(px, pz)
			if hh < -1.3 or hh > 1.4:
				continue
			# as pedras do vale, mas sem o musgo em cima (no sal da beira do mar não cresce), ora em pé, ora deitadas
			var nome: String = ["pedra_alta", "pedra_a", "pedra_b"][postas % 3]
			var esc := rng.randf_range(1.3, 3.0) if nome == "pedra_alta" else rng.randf_range(1.6, 3.6)
			var deita := rng.randf_range(0.9, 1.5) if nome == "pedra_alta" and postas % 2 == 0 else rng.randf_range(-0.25, 0.25)
			var giro := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, deita)
			_pedra(v, nome, Transform3D(giro.scaled(Vector3.ONE * esc), Vector3(px, hh + esc * (0.05 if deita > 0.5 else 0.12), pz)))
			postas += 1
	print("praia da área A: %d pontos de areia, %d lugares de caranguejo, %d bandos de gaivota, %d de focas, %d troncos" % [areia.size(), praia_caranguejos.size(), praia_gaivotas.size(), praia_focas.size(), troncos])


## Uma pedra do vale (como `Clareira._por`, com colisão), pintada com a rocha sem musgo.
func _pedra(v: Vale, nome: String, xf: Transform3D) -> void:
	if not v._malhas.has(nome):
		return
	for par: Array in v._malhas[nome]:
		var mi := MeshInstance3D.new()
		mi.mesh = par[0]
		mi.material_override = v.material("rocha_mar")
		mi.transform = xf * (par[1] as Transform3D)
		v.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = (par[0] as Mesh).create_convex_shape()
		cs.transform = mi.transform
		v._corpo_pedras.add_child(cs)
		Obstaculos.registrar_forma(cs.shape, cs.transform, altura(cs.transform.origin.x, cs.transform.origin.z))


## Os lugares com nome da terra nova (o jogo mostra o nome ao chegar e o álbum guarda). O `Vale` chama depois
## de `Marcos.montar`, que limpa a lista.
func lugares_com_nome() -> void:
	if h.is_empty():
		return
	if Naufragio.centro != Vector3.INF:
		Marcos.lugares.append([Naufragio.NOME, Vector2(Naufragio.centro.x, Naufragio.centro.z), 60.0])
	if not fontes.is_empty():
		Marcos.lugares.append(["As Fontes Quentes", fontes[0][0], 170.0])
	if Vilarejo.montado:
		Marcos.lugares.append([Vilarejo.NOME, Vilarejo.CENTRO, 60.0])
	if BocaDegelo.existe:
		Marcos.lugares.append([BocaDegelo.NOME, Vector2(BocaDegelo.salao.x, BocaDegelo.salao.z).lerp(Vector2(BocaDegelo.boca.x, BocaDegelo.boca.z), 0.5), 55.0])
	MarcosTerraNova.lugares_com_nome()


func _perto_de(p: Vector3, lista: Array[Vector3], dist: float) -> bool:
	for q in lista:
		if Vector2(p.x - q.x, p.z - q.z).length() < dist:
			return true
	return false


func _escolher(de: Array[Vector3], para: Array[Vector3], h_min: float, h_max: float, afastado: float, quantos: int, longe_de: Array[Vector3] = [], dist_longe := 0.0) -> void:
	for p in de:
		if para.size() >= quantos:
			return
		if p.y < h_min or p.y > h_max or _perto_de(p, para, afastado) or _perto_de(p, longe_de, dist_longe):
			continue
		para.append(p)


## Um tronco trazido pelo mar, deitado na areia ao longo da praia, meio enterrado; alguns com o toco das raízes
## numa ponta ou um galho quebrado. Tem colisão (o robô tropeça, não atravessa).
func _tronco(v: Vale, corpo: StaticBody3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var g := Vector2(altura(p.x + 3.0, p.z) - altura(p.x - 3.0, p.z), altura(p.x, p.z + 3.0) - altura(p.x, p.z - 3.0))
	var dir := Vector2(-g.y, g.x).normalized() if g.length() > 0.01 else Vector2(1, 0)
	dir = dir.rotated(rng.randf_range(-0.6, 0.6))
	var comp := rng.randf_range(2.5, 7.0)
	var r := rng.randf_range(0.15, 0.24) * (0.8 + comp / 10.0)
	var a := Vector3(p.x - dir.x * comp * 0.5, 0.0, p.z - dir.y * comp * 0.5)
	var b := Vector3(p.x + dir.x * comp * 0.5, 0.0, p.z + dir.y * comp * 0.5)
	a.y = altura(a.x, a.z)
	b.y = altura(b.x, b.z)
	var eixo := (b - a).normalized()
	var lado := eixo.cross(Vector3.UP).normalized()
	var cima := lado.cross(eixo).normalized()
	var base := Basis(lado, eixo, cima)
	var meio := (a + b) * 0.5 + cima * r * 0.45  # meio enterrado
	var mat := v.material("madeira_deriva")
	var cil := CylinderMesh.new()
	cil.top_radius = r * 0.72
	cil.bottom_radius = r
	cil.height = comp
	cil.radial_segments = 9
	cil.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cil
	mi.material_override = mat
	mi.transform = Transform3D(base, meio)
	add_child(mi)
	if rng.randf() < 0.45:
		# as raízes na ponta grossa: um nó largo e muitos tocos curtos, grossos e tortos, quase todos para trás
		var ponta := meio - eixo * comp * 0.5
		var bola := SphereMesh.new()
		bola.radius = 0.5
		bola.height = 1.0
		bola.radial_segments = 8
		bola.rings = 4
		var no_raiz := MeshInstance3D.new()
		no_raiz.mesh = bola
		no_raiz.material_override = mat
		no_raiz.transform = Transform3D(base * Basis.from_scale(Vector3(r * 3.6, r * 2.6, r * 3.4)), ponta - eixo * r * 0.4)
		add_child(no_raiz)
		var n_raiz := rng.randi_range(7, 10)
		for k in n_raiz:
			var ang := TAU * k / n_raiz + rng.randf_range(-0.35, 0.35)
			var sai := (lado * cos(ang) + cima * sin(ang)).normalized()
			var rc := rng.randf_range(0.28, 0.6)
			var raiz := CylinderMesh.new()
			raiz.top_radius = r * 0.15
			raiz.bottom_radius = r * 0.55
			raiz.height = rc
			raiz.radial_segments = 5
			raiz.rings = 1
			var dir_r := (sai * rng.randf_range(0.5, 0.9) - eixo * rng.randf_range(0.6, 1.0)).normalized()
			var lado_r := dir_r.cross(eixo).normalized() if absf(dir_r.dot(eixo)) < 0.98 else lado
			var rb := Basis(lado_r, dir_r, lado_r.cross(dir_r))
			var rm := MeshInstance3D.new()
			rm.mesh = raiz
			rm.material_override = mat
			rm.transform = Transform3D(rb, ponta - eixo * r * 0.6 + sai * r * 0.8 + dir_r * rc * 0.45)
			add_child(rm)
	elif rng.randf() < 0.6:
		# um galho quebrado saindo de lado
		var galho := CylinderMesh.new()
		galho.top_radius = r * 0.22
		galho.bottom_radius = r * 0.4
		galho.height = rng.randf_range(0.8, 1.6)
		galho.radial_segments = 6
		galho.rings = 1
		var gm := MeshInstance3D.new()
		gm.mesh = galho
		gm.material_override = mat
		var t := rng.randf_range(-0.3, 0.3)
		var gb := Basis(cima, rng.randf_range(0.7, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)) * base
		gm.transform = Transform3D(gb, meio + eixo * comp * t + gb.y * galho.height * 0.5)
		add_child(gm)
	var forma := CylinderShape3D.new()
	forma.radius = r
	forma.height = comp
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.transform = Transform3D(base, meio)
	corpo.add_child(cs)
	Obstaculos.registrar_forma(forma, cs.transform, altura(meio.x, meio.z))
	troncos += 1
