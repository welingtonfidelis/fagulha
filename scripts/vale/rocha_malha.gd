class_name RochaMalha
extends RefCounted
## Peças de rocha com vazios dentro (o Sumidouro e as grutas). A grade de alturas do vale só guarda um
## chão por ponto; aqui o morro é refeito como malha: quem chama descreve o vazio por distâncias, a
## grade é rebaixada debaixo dele, e a rocha (o morro de antes menos o vazio) vira malha por "surface
## nets", com colisão. Gerar a malha leva segundos, então ela fica gravada em arquivo
## (`-- --assar-rochas` gera tudo de novo depois de mudar um desenho).

const PASSO := 1.6  # tamanho da célula da malha
const REBAIXO := 2.2  # quanto a grade fica abaixo do piso do vazio
const SHADER := "res://scripts/shaders/vale_gruta.gdshader"

static var vale: Vale
static var ruido := FastNoiseLite.new()
static var fino := FastNoiseLite.new()


static func preparar(v: Vale) -> void:
	vale = v
	ruido.seed = 4411
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.075
	fino.seed = 4412
	fino.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fino.frequency = 0.26


## Ruído das paredes num ponto (uns 2 m para dentro ou para fora).
static func parede(p: Vector3) -> float:
	return ruido.get_noise_3d(p.x, p.y, p.z) * 1.7 + fino.get_noise_3d(p.x, p.y, p.z) * 0.4


## Ondulação pequena dos pisos.
static func piso(p: Vector3) -> float:
	return ruido.get_noise_2d(p.x * 1.5, p.z * 1.5) * 0.45


static func capsula(p: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) - r


## O ponto mais alto do chão de antes dentro de um retângulo do mapa (nó a nó da grade). A caixa de uma
## peça tem de passar dele: onde o morro era mais alto que a caixa, a peça ficava sem tampa.
static func alto_da_caixa(mn: Vector2, mx: Vector2) -> float:
	var alto := -INF
	var x := floorf(mn.x / Vale.F_PASSO) * Vale.F_PASSO
	while x <= mx.x + Vale.F_PASSO:
		var z := floorf(mn.y / Vale.F_PASSO) * Vale.F_PASSO
		while z <= mx.y + Vale.F_PASSO:
			alto = maxf(alto, Cavernas.chao_antes(x, z))
			z += Vale.F_PASSO
		x += Vale.F_PASSO
	return alto


## A grade foi rebaixada aqui (ou a menos de `folga` + 4 m): não nasce árvore, rocha, capim nem bicho.
static func dentro(x: float, z: float, folga := 0.0) -> bool:
	if vale == null:
		return false
	if BocaDegelo.dentro(x, z, folga):
		return true
	if vale._fora(x, z) < Cavernas.chao_antes(x, z) - 0.3:
		return true
	if folga <= 0.0:
		return false
	var f := folga + 4.0
	for o: Vector2 in [Vector2(f, 0), Vector2(-f, 0), Vector2(0, f), Vector2(0, -f)]:
		if vale._fora(x + o.x, z + o.y) < Cavernas.chao_antes(x + o.x, z + o.y) - 0.3:
			return true
	return false


## Rebaixa a grade debaixo de cada vazio da caixa até REBAIXO abaixo do piso dele, e mais dois nós em
## volta (a rampa que a grade faz ao descer fica escondida dentro da rocha da peça).
static func rebaixar(mn: Vector3, mx: Vector3, vazio: Callable) -> void:
	var gx0 := int((mn.x + Vale.F_META) / Vale.F_PASSO)
	var gx1 := int((mx.x + Vale.F_META) / Vale.F_PASSO) + 1
	var gz0 := int((mn.z + Vale.F_META) / Vale.F_PASSO)
	var gz1 := int((mx.z + Vale.F_META) / Vale.F_PASSO) + 1
	var novo := {}
	var nome := "rebaixo_%d_%d_%d_%d" % [gx0, gz0, gx1, gz1]
	var guardado: Variant = Cache.ler(nome)
	if guardado is Dictionary:
		novo = guardado
	else:
		for gz in range(gz0, gz1 + 1):
			for gx in range(gx0, gx1 + 1):
				var x := -Vale.F_META + gx * Vale.F_PASSO
				var z := -Vale.F_META + gz * Vale.F_PASSO
				var y := mn.y
				var teto := Cavernas._orig[gz * Vale.F_N + gx] - 1.0
				while y < teto:
					if float(vazio.call(Vector3(x, y, z))) < 0.0:
						novo[Vector2i(gx, gz)] = y - REBAIXO
						break
					y += 0.6
		# cada nó desce até o mais fundo dos vizinhos: na beira de um vazio o piso começa mais alto (parede
		# curva), e sem isso a grade aparecia ali por dentro
		var fundo := {}
		for chave: Vector2i in novo:
			var m := float(novo[chave])
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					m = minf(m, float(novo.get(chave + Vector2i(dx, dz), INF)))
			fundo[chave] = m
		novo = fundo
		for volta in 2:
			var mais := {}
			for chave: Vector2i in novo:
				for dz in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var viz := chave + Vector2i(dx, dz)
						if not novo.has(viz):
							mais[viz] = minf(float(mais.get(viz, INF)), float(novo[chave]))
			for chave: Vector2i in mais:
				novo[chave] = mais[chave]
		Cache.gravar(nome, novo)
	for chave: Vector2i in novo:
		var i := chave.y * Vale.F_N + chave.x
		if float(novo[chave]) < vale._fora_h[i]:
			vale._fora_h[i] = float(novo[chave])


## A superfície do morro que a peça refaz: igual ao chão de antes onde a grade foi rebaixada, e
## 0,6 m abaixo dele onde a grade continua lá (para as duas não brigarem).
static func topo(x: float, z: float) -> float:
	var antes := Cavernas.chao_antes(x, z)
	return antes - 0.6 * (1.0 - smoothstep(0.0, 1.0, antes - vale._fora(x, z)))


## Distância com sinal até a rocha (negativa dentro da pedra): o morro menos o vazio, mais a pedra
## posta de volta (`extra`, opcional: pontes e pilares).
static func rocha(p: Vector3, vazio: Callable, extra: Callable) -> float:
	var morro := p.y - topo(p.x, p.z)
	var d := maxf(morro, -float(vazio.call(p)))
	if extra.is_valid():
		d = minf(d, maxf(float(extra.call(p)), morro))
	return d


## Furos no chão por cima de uma peça: pontos em que a grade foi rebaixada para dentro da pedra e não há
## malha por cima (dali se veria a caverna por fora). Um raio desce do céu até a grade; se não bate em
## nada e o desenho diz que ali é pedra, é furo. Para os testes.
static func furos(mn: Vector3, mx: Vector3, vazio: Callable, extra: Callable, passo := 1.0) -> Array[Vector3]:
	var lista: Array[Vector3] = []
	var espaco := vale.get_world_3d().direct_space_state
	var x := mn.x - 12.0
	while x <= mx.x + 12.0:
		var z := mn.z - 12.0
		while z <= mx.z + 12.0:
			var g := vale._fora(x, z)
			var antes := Cavernas.chao_antes(x, z)
			if antes - g > 1.5 and rocha(Vector3(x, g + 0.5, z), vazio, extra) < -0.35:
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, antes + 40.0, z), Vector3(x, g + 0.5, z), 1)
				if espaco.intersect_ray(q).is_empty():
					lista.append(Vector3(x, g, z))
			z += passo
		x += passo
	return lista


## Gera a malha da caixa e grava em `arquivo`. `chave` identifica o lugar (se o relevo mudar, avisa).
static func assar(mn: Vector3, mx: Vector3, vazio: Callable, extra: Callable, arquivo: String, chave: Vector3) -> void:
	assar_com(mn, mx, func(p: Vector3) -> float: return rocha(p, vazio, extra),
		func(p: Vector3) -> float: return Cavernas.chao_antes(p.x, p.z) - p.y, arquivo, chave)


## O mesmo, para qualquer relevo: `dens` dá a distância com sinal até a rocha (negativa dentro) e `fundo`
## quanto o ponto fica abaixo do chão de antes (a cor do vértice). A terra nova usa este (BocaDegelo).
static func assar_com(mn: Vector3, mx: Vector3, dens_f: Callable, fundo_f: Callable, arquivo: String, chave: Vector3) -> void:
	var t0 := Time.get_ticks_msec()
	var nx := int((mx.x - mn.x) / PASSO) + 2
	var ny := int((mx.y - mn.y) / PASSO) + 2
	var nz := int((mx.z - mn.z) / PASSO) + 2
	var dens := PackedFloat32Array()
	dens.resize(nx * ny * nz)
	for k in nz:
		for j in ny:
			for i in nx:
				dens[(k * ny + j) * nx + i] = dens_f.call(mn + Vector3(i, j, k) * PASSO)
	# um vértice por célula cortada pela superfície, no meio dos cruzamentos das arestas
	var indice := PackedInt32Array()
	indice.resize(nx * ny * nz)
	indice.fill(-1)
	var verts := PackedVector3Array()
	var cantos := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
		Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var arestas := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var val := PackedFloat32Array()
	val.resize(8)
	for k in nz - 1:
		for j in ny - 1:
			for i in nx - 1:
				var cheios := 0
				for c in 8:
					var o: Vector3i = cantos[c]
					val[c] = dens[((k + o.z) * ny + j + o.y) * nx + i + o.x]
					if val[c] < 0.0:
						cheios += 1
				if cheios == 0 or cheios == 8:
					continue
				var soma := Vector3.ZERO
				var quantos := 0
				for ar: Array in arestas:
					var va := val[ar[0]]
					var vb := val[ar[1]]
					if (va < 0.0) != (vb < 0.0):
						soma += Vector3(cantos[ar[0]]).lerp(Vector3(cantos[ar[1]]), va / (va - vb))
						quantos += 1
				indice[(k * ny + j) * nx + i] = verts.size()
				verts.append(mn + (Vector3(i, j, k) + soma / quantos) * PASSO)
	# um quadrado para cada aresta da grade que cruza a superfície, com a frente virada para o vazio
	var idx := PackedInt32Array()
	for k in range(1, nz - 1):
		for j in range(1, ny - 1):
			for i in range(1, nx - 1):
				var aqui := dens[(k * ny + j) * nx + i] < 0.0
				for eixo in 3:
					var ox := 1 if eixo == 0 else 0
					var oy := 1 if eixo == 1 else 0
					var oz := 1 if eixo == 2 else 0
					if (dens[((k + oz) * ny + j + oy) * nx + i + ox] < 0.0) == aqui:
						continue
					var q := PackedInt32Array()
					if eixo == 0:
						q = [indice[((k - 1) * ny + j - 1) * nx + i], indice[((k - 1) * ny + j) * nx + i], indice[(k * ny + j) * nx + i], indice[(k * ny + j - 1) * nx + i]]
					elif eixo == 1:
						q = [indice[((k - 1) * ny + j) * nx + i - 1], indice[(k * ny + j) * nx + i - 1], indice[(k * ny + j) * nx + i], indice[((k - 1) * ny + j) * nx + i]]
					else:
						q = [indice[(k * ny + j - 1) * nx + i - 1], indice[(k * ny + j - 1) * nx + i], indice[(k * ny + j) * nx + i], indice[(k * ny + j) * nx + i - 1]]
					if q[0] < 0 or q[1] < 0 or q[2] < 0 or q[3] < 0:
						continue
					if aqui:
						idx.append_array([q[0], q[2], q[1], q[0], q[3], q[2]])
					else:
						idx.append_array([q[0], q[1], q[2], q[0], q[2], q[3]])
	# normais pela inclinação do próprio desenho (lisas) e a cor: r = capim (perto do chão de fora), g = fundura
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	normais.resize(verts.size())
	cores.resize(verts.size())
	var e := 0.35
	for i in verts.size():
		var p := verts[i]
		normais[i] = Vector3(
			float(dens_f.call(p + Vector3(e, 0, 0))) - float(dens_f.call(p - Vector3(e, 0, 0))),
			float(dens_f.call(p + Vector3(0, e, 0))) - float(dens_f.call(p - Vector3(0, e, 0))),
			float(dens_f.call(p + Vector3(0, 0, e))) - float(dens_f.call(p - Vector3(0, 0, e)))).normalized()
		var fundo: float = fundo_f.call(p)
		cores[i] = Color(1.0 - smoothstep(0.9, 2.2, fundo), clampf(fundo / 14.0, 0.0, 1.0), 0.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normais
	arr[Mesh.ARRAY_COLOR] = cores
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.set_meta("chave", chave)
	var erro := ResourceSaver.save(m, arquivo, ResourceSaver.FLAG_COMPRESS)
	print("rocha assada: %s, %d×%d×%d amostras, %d triângulos, %d ms (gravar: %d)"
		% [arquivo.get_file(), nx, ny, nz, idx.size() / 3, Time.get_ticks_msec() - t0, erro])


## Põe a malha gravada no vale, com colisão dos dois lados. Devolve false se o arquivo falta. Sem `mat`, a
## rocha do Sumidouro.
static func montar(arquivo: String, nome: String, chave: Vector3, mat: Material = null) -> bool:
	if not ResourceLoader.exists(arquivo):
		push_warning("%s: falta a malha (%s); rode -- --assar-rochas" % [nome, arquivo])
		return false
	var m := load(arquivo) as ArrayMesh
	if (m.get_meta("chave", Vector3.INF) as Vector3).distance_to(chave) > 0.5:
		push_warning("%s: a malha gravada é de outro lugar; rode -- --assar-rochas" % nome)
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = m
	mi.material_override = mat if mat else material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	vale.add_child(mi)
	var corpo := StaticBody3D.new()
	corpo.name = nome + "Corpo"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	vale.add_child(corpo)
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(m.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = forma
	corpo.add_child(cs)
	return true


## O material da rocha. Com `solto`, para pedras e estalactites sem cor de vértice (sempre "lá no fundo").
static func material(solto := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER)
	mat.set_shader_parameter("ruido", vale._tex)
	if solto:
		mat.set_shader_parameter("fundo_fixo", 1.0)
	return mat


## O piso e o teto de um vazio num ponto do mapa, a partir de uma altura dentro dele. Vector2(piso, teto) ou INF.
static func piso_teto(x: float, z: float, y0: float, vazio: Callable, extra: Callable) -> Vector2:
	if float(vazio.call(Vector3(x, y0, z))) > 0.0:
		return Vector2(INF, INF)
	var a := y0
	while a > y0 - 30.0 and rocha(Vector3(x, a, z), vazio, extra) > 0.0:
		a -= 0.25
	var b := y0
	while b < y0 + 40.0 and rocha(Vector3(x, b, z), vazio, extra) > 0.0:
		b += 0.25
	return Vector2(a, b)


## Um grupo de cristais acesos com a luz dele.
static func cristal(base: Vector3, cor: Color, rng: RandomNumberGenerator, porte := 1.0, luz_k := 1.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor * 0.5
	mat.emission_enabled = true
	mat.emission = cor * 0.8
	mat.emission_energy_multiplier = 1.1
	mat.roughness = 0.3
	var maior := 0.0
	for q in rng.randi_range(3, 5):
		var alt := rng.randf_range(1.0, 3.4) * porte
		maior = maxf(maior, alt)
		var prisma := CylinderMesh.new()
		prisma.top_radius = 0.03
		prisma.bottom_radius = alt * rng.randf_range(0.13, 0.2)
		prisma.height = alt
		prisma.radial_segments = 5
		prisma.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = prisma
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var inclina := Basis.from_euler(Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45)))
		mi.transform = Transform3D(inclina, base + Vector3(rng.randf_range(-0.8, 0.8), -0.3, rng.randf_range(-0.8, 0.8)) + inclina * Vector3(0, alt * 0.5, 0))
		vale.add_child(mi)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.2 * porte * luz_k  # eram 2,2 e 17 m: as cavernas ficavam claras demais
	luz.omni_range = 11.0 * porte
	luz.shadow_enabled = false
	luz.position = base + Vector3(0, maior + 0.8, 0)
	vale.add_child(luz)


## Estalactites (do teto) e estalagmites (do piso) nos pontos dados, num MultiMesh só.
static func pingentes(pontos: Array[Vector2], y0: Callable, vazio: Callable, extra: Callable, semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 2
	var lista: Array[Transform3D] = []
	for xz in pontos:
		var pt := piso_teto(xz.x, xz.y, float(y0.call(xz)), vazio, extra)
		if pt.x == INF or pt.y - pt.x < 5.0 or pt.y - pt.x > 38.0:
			continue
		var alt := rng.randf_range(0.8, minf(5.0, (pt.y - pt.x) * 0.3))
		var larg := alt * rng.randf_range(0.22, 0.4)
		if rng.randf() < 0.65:
			lista.append(Transform3D(Basis.from_scale(Vector3(larg, -alt, larg)), Vector3(xz.x, pt.y + 0.3 - alt * 0.5, xz.y)))
		else:
			lista.append(Transform3D(Basis.from_scale(Vector3(larg * 1.3, alt * 0.7, larg * 1.3)), Vector3(xz.x, pt.x - 0.2 + alt * 0.35, xz.y)))
	if lista.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = lista.size()
	for i in lista.size():
		mm.set_instance_transform(i, lista[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material(true)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vale.add_child(mmi)
