class_name Ilha
extends Node3D
## Ilha de teste da etapa 1: 2 × 2 km, ruído simples (sem erosão), um morro, um lago e o mar em volta.
## Com 2 km, o relevo inteiro (um ponto a cada 4 m) cabe na placa de vídeo sem níveis de detalhe; o sistema
## de anéis de detalhe entra na etapa 2, com a ilha de 8 km.

const META := 1024.0  # a ilha vai de -1024 a +1024 m em x e z
const ESP := 4.0  # metros entre pontos
const N := 513  # pontos por lado
const BLOCO := 64  # quadrados por bloco de malha (256 m)
const CELULA_ARVORE := 32.0
const RAIO_COLISAO_ARVORE := 70.0
const MAX_COLISAO_ARVORE := 450

var alturas := PackedFloat32Array()
var normais := PackedVector3Array()
var cores := PackedColorArray()
var mata := PackedFloat32Array()  # densidade da mata em cada ponto, 0 a 1

var lago_centro := Vector2(-280.0, 200.0)
var lago_raio := 150.0
var lago_nivel := 0.0
var spawn := Vector3.ZERO
var spawn_yaw := 0.0

# árvores: posição da base, escala e tipo (0 conífera, 1 folhosa)
var arv_pos := PackedVector3Array()
var arv_escala := PackedFloat32Array()
var arv_tipo := PackedByteArray()
var _grade_arv := {}  # Vector2i -> PackedInt32Array

var _corpo_arvores: StaticBody3D
var _formas_tronco: Array[CollisionShape3D] = []
var _formas_copa: Array[CollisionShape3D] = []
var _ultimo_centro := Vector3(INF, 0, INF)

var _n_colina: FastNoiseLite
var _n_crista: FastNoiseLite
var _n_costa: FastNoiseLite
var _n_det: FastNoiseLite
var _n_mata: FastNoiseLite
var _n_campo: FastNoiseLite


## Chamado entre os passos da montagem (fração de 0 a 1 e o que está sendo feito): a tela de carregamento.
var aviso := Callable()


func _avisar(f: float, texto: String) -> void:
	if aviso.is_valid():
		await aviso.call(f, texto)


func gerar(semente := 7) -> void:
	var t0 := Time.get_ticks_msec()
	_ruidos(semente)
	_gerar_alturas()
	_cavar_lago()
	_derivados()
	_malha()
	_colisao()
	_agua()
	_arvores(semente)
	_preparar_colisao_arvores()
	print("ilha gerada em %d ms, %d árvores" % [Time.get_ticks_msec() - t0, arv_pos.size()])


# ---------------------------------------------------------------- relevo

func _ruido(semente: int, freq: float, oitavas: int, tipo := FastNoiseLite.FRACTAL_FBM) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = semente
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = tipo
	n.fractal_octaves = oitavas
	return n


func _ruidos(semente: int) -> void:
	_n_colina = _ruido(semente, 1.0 / 520.0, 5)
	_n_crista = _ruido(semente + 1, 1.0 / 260.0, 5, FastNoiseLite.FRACTAL_RIDGED)
	_n_costa = _ruido(semente + 2, 1.0 / 380.0, 3)
	_n_det = _ruido(semente + 3, 1.0 / 45.0, 2)
	_n_mata = _ruido(semente + 4, 1.0 / 260.0, 3)
	_n_campo = _ruido(semente + 5, 1.0 / 180.0, 2)


func _altura_base(x: float, z: float) -> float:
	var h := 50.0 + _n_colina.get_noise_2d(x, z) * 75.0
	# o morro, a sudeste
	var dm := Vector2(x - 330.0, z + 270.0).length()
	var morro := exp(-pow(dm / 400.0, 2.0))
	h += morro * (250.0 + 110.0 * _n_crista.get_noise_2d(x, z))
	h += _n_det.get_noise_2d(x, z) * 2.5
	# costa: o relevo desce até a praia e some no mar
	var r := Vector2(x, z).length() / META + _n_costa.get_noise_2d(x, z) * 0.12
	h = h * (1.0 - smoothstep(0.58, 0.9, r)) + 6.0 * (1.0 - smoothstep(0.82, 0.95, r))
	h -= 50.0 * smoothstep(0.88, 1.02, r)
	return h


func _gerar_alturas() -> void:
	alturas.resize(N * N)
	for iz in N:
		var z := -META + iz * ESP
		for ix in N:
			alturas[iz * N + ix] = _altura_base(-META + ix * ESP, z)


const LAGO_BORDA := 2.4  # até onde a margem desce suave, em raios do lago


func _cavar_lago() -> void:
	# 1) um nível provisório: o ponto mais baixo num anel perto da água
	var menor := INF
	for k in 72:
		var a := TAU * k / 72.0
		var p := lago_centro + Vector2(cos(a), sin(a)) * lago_raio * 1.35
		menor = minf(menor, altura(p.x, p.y))
	var provisorio := menor - 1.0
	# 2) bacia: fundo dentro do raio e margem descendo suave até LAGO_BORDA raios
	var alcance := lago_raio * LAGO_BORDA
	var i0 := _indice(lago_centro.x - alcance)
	var i1 := _indice(lago_centro.x + alcance)
	var k0 := _indice(lago_centro.y - alcance)
	var k1 := _indice(lago_centro.y + alcance)
	for iz in range(k0, k1 + 1):
		for ix in range(i0, i1 + 1):
			var p := Vector2(-META + ix * ESP, -META + iz * ESP)
			var d := p.distance_to(lago_centro) / lago_raio
			if d > LAGO_BORDA:
				continue
			var i := iz * N + ix
			var h := alturas[i]
			if d <= 1.0:
				h = minf(h, provisorio - 1.5 - 13.0 * (1.0 - d * d))
			else:
				var t := smoothstep(1.0, LAGO_BORDA, d)
				h = minf(h, lerpf(provisorio - 1.5, h, t * t))
			alturas[i] = h
	# 3) o nível de verdade é o ponto mais baixo da borda da bacia: a água nunca vaza para fora dela
	menor = INF
	for k in 120:
		var a := TAU * k / 120.0
		var p := lago_centro + Vector2(cos(a), sin(a)) * alcance * 0.97
		menor = minf(menor, altura(p.x, p.y))
	lago_nivel = minf(provisorio, menor - 0.4)


func _indice(c: float) -> int:
	return clampi(int(round((c + META) / ESP)), 0, N - 1)


## Altura do chão em qualquer ponto (interpolada).
func altura(x: float, z: float) -> float:
	var fx := clampf((x + META) / ESP, 0.0, N - 1.001)
	var fz := clampf((z + META) / ESP, 0.0, N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * N + ix
	var a := lerpf(alturas[i], alturas[i + 1], tx)
	var b := lerpf(alturas[i + N], alturas[i + N + 1], tx)
	return lerpf(a, b, tz)


## Superfície da água em (x, z), ou -INF se não houver água ali.
func agua(x: float, z: float) -> float:
	var h := altura(x, z)
	if Vector2(x, z).distance_to(lago_centro) < lago_raio * LAGO_BORDA and h < lago_nivel:
		return lago_nivel
	if h < 0.0:
		return 0.0
	return -INF


## A armadura está rente à água ou dentro dela (esfria o motor e anda devagar)?
## O ponto está dentro de uma queda d'água? (só o Vale tem cachoeiras)
func na_cachoeira(_p: Vector3) -> bool:
	return false


func agua_perto(p: Vector3) -> bool:
	var nivel := agua(p.x, p.z)
	var acima := p.y - nivel
	return nivel > -INF and acima < Ajustes.RASANTE_ALTURA and acima > -60.0


func normal_em(x: float, z: float) -> Vector3:
	var e := ESP
	return Vector3(altura(x - e, z) - altura(x + e, z), 2.0 * e, altura(x, z - e) - altura(x, z + e)).normalized()


func _lin(r: int, g: int, b: int) -> Color:
	return Color8(r, g, b).srgb_to_linear()


func _derivados() -> void:
	normais.resize(N * N)
	cores.resize(N * N)
	mata.resize(N * N)
	var grama := _lin(76, 112, 44)
	var campo := _lin(128, 134, 62)
	var chao_mata := _lin(48, 64, 30)
	var rocha := _lin(112, 108, 100)
	var areia := _lin(190, 176, 136)
	var fundo := _lin(92, 96, 76)
	for iz in N:
		for ix in N:
			var i := iz * N + ix
			var x := -META + ix * ESP
			var z := -META + iz * ESP
			var hl := alturas[i - 1] if ix > 0 else alturas[i]
			var hr := alturas[i + 1] if ix < N - 1 else alturas[i]
			var hd := alturas[i - N] if iz > 0 else alturas[i]
			var hu := alturas[i + N] if iz < N - 1 else alturas[i]
			var nrm := Vector3(hl - hr, 2.0 * ESP, hd - hu).normalized()
			normais[i] = nrm
			var h := alturas[i]
			var inclin := rad_to_deg(acos(clampf(nrm.y, -1.0, 1.0)))
			var dens := densidade_mata(x, z, h, inclin)
			mata[i] = dens
			var c := grama.lerp(campo, smoothstep(0.3, 0.8, _n_campo.get_noise_2d(x, z)) * 0.75)
			c = c.lerp(chao_mata, smoothstep(0.35, 0.7, dens))
			c = c.lerp(rocha, clampf(smoothstep(35.0, 45.0, inclin) * 0.85 + smoothstep(300.0, 360.0, h) * 0.5, 0.0, 1.0))
			var d_lago := Vector2(x, z).distance_to(lago_centro) / lago_raio
			var praia_lago := 1.0 - smoothstep(0.0, 4.0, h - lago_nivel)
			if d_lago > LAGO_BORDA:
				praia_lago = 0.0
			c = c.lerp(areia, maxf(1.0 - smoothstep(2.0, 6.0, h), praia_lago * 0.8))
			if h < -1.0 or (d_lago < 1.0 and h < lago_nivel - 1.0):
				c = fundo
			cores[i] = c


func densidade_mata(x: float, z: float, h: float, inclin: float) -> float:
	var d := _n_mata.get_noise_2d(x, z) * 1.4 + 0.58
	d -= smoothstep(28.0, 38.0, inclin)
	d -= smoothstep(240.0, 320.0, h)
	d -= 1.0 - smoothstep(4.0, 9.0, h)
	return clampf(d, 0.0, 1.0)


# ---------------------------------------------------------------- malha e colisão

func _malha() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/terreno.gdshader")
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = _ruido(99, 1.0 / 32.0, 4)
	mat.set_shader_parameter("ruido", tex)
	var blocos := (N - 1) / BLOCO
	var lado := BLOCO + 1
	for bz in blocos:
		for bx in blocos:
			var verts := PackedVector3Array()
			var nrms := PackedVector3Array()
			var cols := PackedColorArray()
			verts.resize(lado * lado)
			nrms.resize(lado * lado)
			cols.resize(lado * lado)
			for j in lado:
				var iz := bz * BLOCO + j
				for i in lado:
					var ix := bx * BLOCO + i
					var g := iz * N + ix
					var k := j * lado + i
					verts[k] = Vector3(-META + ix * ESP, alturas[g], -META + iz * ESP)
					nrms[k] = normais[g]
					cols[k] = cores[g]
			var idx := PackedInt32Array()
			idx.resize(BLOCO * BLOCO * 6)
			var p := 0
			for j in BLOCO:
				for i in BLOCO:
					var a := j * lado + i
					var b := a + 1
					var c := a + lado
					var d := c + 1
					# horário visto de cima
					idx[p] = a
					idx[p + 1] = b
					idx[p + 2] = d
					idx[p + 3] = a
					idx[p + 4] = d
					idx[p + 5] = c
					p += 6
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = nrms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.name = "Relevo_%d_%d" % [bx, bz]
			mi.mesh = m
			add_child(mi)


func _colisao() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "ChaoColisao"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := HeightMapShape3D.new()
	forma.map_width = N
	forma.map_depth = N
	var dados := PackedFloat32Array()
	dados.resize(N * N)
	for i in N * N:
		dados[i] = alturas[i] / ESP  # a forma é escalada por ESP nos três eixos (escala uniforme)
	forma.map_data = dados
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.scale = Vector3(ESP, ESP, ESP)
	corpo.add_child(cs)


func _agua() -> void:
	var shader: Shader = load("res://scripts/shaders/agua.gdshader")
	var mar := MeshInstance3D.new()
	mar.name = "Mar"
	var pm := PlaneMesh.new()
	pm.size = Vector2(40000, 40000)
	mar.mesh = pm
	var mm := ShaderMaterial.new()
	mm.shader = shader
	mm.set_shader_parameter("raio", 100000.0)
	mar.material_override = mm
	mar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mar)
	var lago := MeshInstance3D.new()
	lago.name = "Lago"
	var pl := PlaneMesh.new()
	pl.size = Vector2(lago_raio * LAGO_BORDA * 2.0, lago_raio * LAGO_BORDA * 2.0)
	pl.subdivide_width = 8
	pl.subdivide_depth = 8
	lago.mesh = pl
	var ml := ShaderMaterial.new()
	ml.shader = shader
	ml.set_shader_parameter("centro", lago_centro)
	ml.set_shader_parameter("raio", lago_raio * LAGO_BORDA * 0.98)
	lago.material_override = ml
	lago.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lago.position = Vector3(lago_centro.x, lago_nivel, lago_centro.y)
	add_child(lago)
	# começo: na praia do lado oposto ao morro, olhando o lago com o morro ao fundo
	var para_morro := (Vector2(330, -270) - lago_centro).normalized()
	var d := lago_raio * 0.8
	while d < lago_raio * LAGO_BORDA and altura(lago_centro.x - para_morro.x * d, lago_centro.y - para_morro.y * d) < lago_nivel + 1.0:
		d += 2.0
	var p := lago_centro - para_morro * (d + 14.0)
	spawn = Vector3(p.x, altura(p.x, p.y) + 0.2, p.y)
	spawn_yaw = atan2(-para_morro.x, -para_morro.y)


## Para os testes: um rumo a partir de `de` com `metros` de chão seco, quase plano e sem árvores.
func rumo_livre(de: Vector3, metros: float) -> float:
	for k in 24:
		var yaw := TAU * k / 24.0
		var dir := -Basis(Vector3.UP, yaw).z
		var livre := true
		var passo := 2.0
		while passo <= metros and livre:
			var q := de + dir * passo
			if agua(q.x, q.z) > -INF or normal_em(q.x, q.z).y < 0.94 or _arvore_perto(q, 4.0):
				livre = false
			passo += 2.0
		if livre:
			return yaw
	return spawn_yaw


func _arvore_perto(q: Vector3, raio: float) -> bool:
	var cel := Vector2i(floori(q.x / CELULA_ARVORE), floori(q.z / CELULA_ARVORE))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := cel + Vector2i(dx, dz)
			if not _grade_arv.has(c):
				continue
			var lista: PackedInt32Array = _grade_arv[c]
			for i in lista:
				if Vector2(arv_pos[i].x - q.x, arv_pos[i].z - q.z).length() < raio:
					return true
	return false


# ---------------------------------------------------------------- árvores

func _arvores(semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente * 31 + 5
	var passo := 6.5
	var c := -META + 20.0
	while c < META - 20.0:
		var r := -META + 20.0
		while r < META - 20.0:
			var x := r + rng.randf_range(-2.8, 2.8)
			var z := c + rng.randf_range(-2.8, 2.8)
			r += passo
			var h := altura(x, z)
			if h < 4.0 or Vector2(x - spawn.x, z - spawn.z).length() < 14.0:
				continue
			if agua(x, z) > -INF or h < lago_nivel + 2.5 and Vector2(x, z).distance_to(lago_centro) < lago_raio * LAGO_BORDA:
				continue
			var inclin := rad_to_deg(acos(normal_em(x, z).y))
			var dens := densidade_mata(x, z, h, inclin)
			if rng.randf() > dens * 0.85 + 0.01:
				continue
			arv_pos.append(Vector3(x, h - 0.3, z))
			arv_escala.append(rng.randf_range(0.75, 1.3))
			var conifera := h > 150.0 or _n_campo.get_noise_2d(z, x) > 0.25
			arv_tipo.append(0 if conifera else 1)
		c += passo
	# grade para a colisão perto da armadura
	for i in arv_pos.size():
		var cel := Vector2i(floori(arv_pos[i].x / CELULA_ARVORE), floori(arv_pos[i].z / CELULA_ARVORE))
		if not _grade_arv.has(cel):
			_grade_arv[cel] = PackedInt32Array()
		var lista: PackedInt32Array = _grade_arv[cel]
		lista.append(i)
		_grade_arv[cel] = lista
	# desenho: MultiMesh por bloco de 256 m e por tipo
	var malhas := [ArvoresMalha.conifera(), ArvoresMalha.folhosa()]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var blocos := {}
	for i in arv_pos.size():
		var chave := Vector3i(floori((arv_pos[i].x + META) / 256.0), floori((arv_pos[i].z + META) / 256.0), arv_tipo[i])
		if not blocos.has(chave):
			blocos[chave] = PackedInt32Array()
		var l: PackedInt32Array = blocos[chave]
		l.append(i)
		blocos[chave] = l
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = semente + 77
	for chave in blocos:
		var lista: PackedInt32Array = blocos[chave]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = malhas[chave.z]
		mm.instance_count = lista.size()
		for k in lista.size():
			var i := lista[k]
			var s := arv_escala[i]
			var b := Basis(Vector3.UP, rng2.randf() * TAU).scaled(Vector3(s, s * rng2.randf_range(0.9, 1.15), s))
			mm.set_instance_transform(k, Transform3D(b, arv_pos[i]))
			var v := rng2.randf_range(0.8, 1.2)
			mm.set_instance_color(k, Color(v * rng2.randf_range(0.92, 1.08), v, v * rng2.randf_range(0.85, 1.05)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.visibility_range_end = 2600.0
		add_child(mmi)


func _preparar_colisao_arvores() -> void:
	_corpo_arvores = StaticBody3D.new()
	_corpo_arvores.name = "ArvoresColisao"
	_corpo_arvores.collision_layer = 2
	_corpo_arvores.collision_mask = 0
	add_child(_corpo_arvores)
	for k in MAX_COLISAO_ARVORE:
		var t := CollisionShape3D.new()
		var cil := CylinderShape3D.new()
		cil.radius = 0.45
		cil.height = 6.0
		t.shape = cil
		t.disabled = true
		_corpo_arvores.add_child(t)
		_formas_tronco.append(t)
		var c := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 2.6
		cap.height = 9.0
		c.shape = cap
		c.disabled = true
		_corpo_arvores.add_child(c)
		_formas_copa.append(c)


## As medidas da colisão da árvore `i`, no mundo: [raio do tronco, altura do tronco, raio da copa, altura do
## meio da copa, altura da copa]. Aqui, a árvore genérica da ilha de testes; o vale mede cada modelo.
func _medidas_colisao(i: int) -> Array:
	var s := arv_escala[i]
	var conif := arv_tipo[i] == 0
	var r := (2.6 if conif else 3.8) * s
	return [0.45 * s, (3.5 if conif else 5.0) * s, r, (9.0 if conif else 8.5) * s, (9.0 if conif else 7.0) * s]


## Liga a colisão só das árvores perto de `centro` (troncos e copas).
func atualizar_colisao_arvores(centro: Vector3, forcar := false) -> void:
	if not forcar and Vector2(centro.x, centro.z).distance_to(Vector2(_ultimo_centro.x, _ultimo_centro.z)) < 12.0:
		return
	_ultimo_centro = centro
	var usados := 0
	var raio_cel := int(ceil(RAIO_COLISAO_ARVORE / CELULA_ARVORE))
	var cc := Vector2i(floori(centro.x / CELULA_ARVORE), floori(centro.z / CELULA_ARVORE))
	for dz in range(-raio_cel, raio_cel + 1):
		for dx in range(-raio_cel, raio_cel + 1):
			var cel := cc + Vector2i(dx, dz)
			if not _grade_arv.has(cel):
				continue
			var lista: PackedInt32Array = _grade_arv[cel]
			for i in lista:
				if usados >= MAX_COLISAO_ARVORE:
					break
				var p := arv_pos[i]
				if Vector2(p.x - centro.x, p.z - centro.z).length() > RAIO_COLISAO_ARVORE:
					continue
				var md := _medidas_colisao(i)  # [raio do tronco, altura do tronco, raio da copa, meio da copa, altura da copa]
				var tronco := _formas_tronco[usados]
				var copa := _formas_copa[usados]
				# formas próprias de cada vaga (sem escala não uniforme, que a física não aceita bem)
				var cil: CylinderShape3D = tronco.shape
				cil.radius = md[0]
				cil.height = md[1]
				tronco.position = p + Vector3(0, md[1] * 0.5, 0)
				tronco.disabled = false
				var cap: CapsuleShape3D = copa.shape
				cap.radius = md[2]
				cap.height = maxf(md[2] * 2.0 + 0.1, md[4])
				copa.position = p + Vector3(0, md[3], 0)
				copa.disabled = md[2] < 0.3
				usados += 1
	for k in range(usados, MAX_COLISAO_ARVORE):
		_formas_tronco[k].disabled = true
		_formas_copa[k].disabled = true
