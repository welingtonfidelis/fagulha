class_name Paredoes
extends RefCounted
## Paredões e encostas de pedra do vale (2026-11-15). O relevo é uma grade de 4 m, então uma parede
## quase em pé saía lisa como uma folha esticada. Aqui ela ganha o que falta numa rocha de verdade:
## blocos e lajes encaixados na parede (saliências, degraus, sombras), pedras caídas no pé e arbustos
## nas beiras. As rochas usam a mesma pedra do chão (vale_rocha/cor_rocha), então emendam sem costura.

const INGREME := 0.66  # normal.y abaixo disso é parede
const VARIANTES := 4


## Uma massa de rocha lisa: uma bola com calombos largos, com poucas faces grandes aparadas e as
## quinas arredondadas pela luz (normais suaves). De longe lê como um bloco só, não como entulho.
static func rocha(semente: int, talhos: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var n := 6
	var faces := [[Vector3.RIGHT, Vector3.UP], [Vector3.LEFT, Vector3.UP], [Vector3.UP, Vector3.BACK],
		[Vector3.DOWN, Vector3.FORWARD], [Vector3.BACK, Vector3.UP], [Vector3.FORWARD, Vector3.UP]]
	var planos: Array = []
	for k in talhos:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 0.9), rng.randf_range(-1, 1)).normalized()
		planos.append([d, rng.randf_range(0.62, 0.8)])
	var k1 := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	var k2 := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	var f1 := rng.randf() * TAU
	var f2 := rng.randf() * TAU
	var tris := PackedVector3Array()
	for f: Array in faces:
		var nf: Vector3 = f[0]
		var u: Vector3 = f[1]
		var w: Vector3 = nf.cross(u)
		var grade: Array[Vector3] = []
		for jj in n + 1:
			for ii in n + 1:
				var p := (nf + u * (float(ii) / n * 2.0 - 1.0) + w * (float(jj) / n * 2.0 - 1.0)).normalized()
				# entre a bola e o cubo: lados quase em pé, topo quase chato, quinas redondas
				var cubo := p / maxf(absf(p.x), maxf(absf(p.y), absf(p.z))) * 0.8
				p = p.lerp(cubo, 0.62)
				p *= 0.96 + 0.09 * sin(p.dot(k1) * 2.6 + f1) + 0.06 * sin(p.dot(k2) * 4.3 + f2)
				for pl: Array in planos:
					var sobra := p.dot(pl[0]) - (pl[1] as float)
					if sobra > 0.0:
						p -= (pl[0] as Vector3) * sobra * 0.85
				grade.append(p)
		for jj in n:
			for ii in n:
				var a := grade[jj * (n + 1) + ii]
				var b := grade[jj * (n + 1) + ii + 1]
				var c := grade[(jj + 1) * (n + 1) + ii + 1]
				var d := grade[(jj + 1) * (n + 1) + ii]
				for tri: Array in [[a, b, c], [a, c, d]]:
					var nt: Vector3 = ((tri[2] as Vector3) - tri[0]).cross((tri[1] as Vector3) - tri[0])
					if nt.length_squared() < 1e-12:
						continue
					if nt.dot((tri[0] as Vector3) + tri[1] + tri[2]) < 0.0:
						tris.append_array(PackedVector3Array([tri[0], tri[2], tri[1]]))
					else:
						tris.append_array(PackedVector3Array([tri[0], tri[1], tri[2]]))
	# normais suaves: cada ponto soma as faces que o tocam
	var soma := {}
	var t := 0
	while t < tris.size():
		var nt := (tris[t + 2] - tris[t]).cross(tris[t + 1] - tris[t])
		for q in 3:
			var ch := Vector3i(roundi(tris[t + q].x * 500.0), roundi(tris[t + q].y * 500.0), roundi(tris[t + q].z * 500.0))
			soma[ch] = (soma.get(ch, Vector3.ZERO) as Vector3) + nt
		t += 3
	var nrms := PackedVector3Array()
	nrms.resize(tris.size())
	for q in tris.size():
		var ch := Vector3i(roundi(tris[q].x * 500.0), roundi(tris[q].y * 500.0), roundi(tris[q].z * 500.0))
		nrms[q] = (soma[ch] as Vector3).normalized()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = tris
	arr[Mesh.ARRAY_NORMAL] = nrms
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func montar(v: Vale) -> void:
	var t0 := Time.get_ticks_msec()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_rocha.gdshader")
	mat.set_shader_parameter("ruido", v._tex)
	var malhas: Array[ArrayMesh] = []
	var pontos: Array[PackedVector3Array] = []
	for k in VARIANTES:
		var m := rocha(31 + k * 7, 3 + k % 3)
		m.surface_set_material(0, mat)
		malhas.append(m)
		pontos.append(m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var corpo := StaticBody3D.new()
	corpo.name = "Paredoes"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	v.add_child(corpo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var grupos := {}  # "variante|bx|bz|porte" -> transformações
	var arbustos: Array = []
	var n_parede := 0
	var n_pe := 0
	for gz in range(2, Vale.F_N - 2):
		for gx in range(2, Vale.F_N - 2):
			var x := -Vale.F_META + gx * Vale.F_PASSO
			var z := -Vale.F_META + gz * Vale.F_PASSO
			if maxf(absf(x), absf(z)) < Clareira.C_META + 6.0 or Cavernas.dentro(x, z, 2.0):
				continue
			var nrm := v.normal_em_fora(gx, gz)
			if nrm.y > INGREME:
				continue
			var h := v._fora_h[gz * Vale.F_N + gx]
			if h < 1.0:
				continue
			var fora := Vector3(nrm.x, 0, nrm.z).normalized()  # para onde a parede olha
			var forca := smoothstep(INGREME, 0.35, nrm.y)  # 0 na encosta, 1 na parede em pé
			# massas de rocha encostadas na parede: poucas e grandes, de pé como colunas, uma ao lado da
			# outra. Onde duas se encontram fica a fenda escura; em cima de cada uma, o capim.
			if rng.randf() < 0.16 + forca * 0.5:
				var px := x + rng.randf_range(-2.0, 2.0)
				var pz := z + rng.randf_range(-2.0, 2.0)
				var larg := rng.randf_range(4.5, 8.0) * (0.7 + forca * 0.6)
				if rng.randf() < 0.1:
					larg *= 1.5  # de vez em quando um contraforte
				var alt := larg * rng.randf_range(1.3, 2.3) * (0.55 + forca * 0.65)
				var esc := Vector3(larg, alt, larg * rng.randf_range(0.6, 0.85))
				var base := Basis.looking_at(-fora, Vector3.UP) if fora.length_squared() > 0.5 else Basis.IDENTITY
				base = base * Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.16), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.12, 0.12)))
				var pos := Vector3(px, v._fora(px, pz) - alt * rng.randf_range(0.0, 0.25), pz) + fora * larg * rng.randf_range(-0.15, 0.12)
				var xf := Transform3D(base.scaled_local(esc * 0.5 / 0.5), pos)
				var vi := rng.randi() % VARIANTES
				_guardar(grupos, vi, xf, true)
				n_parede += 1
				_colisao(corpo, pontos[vi], xf)
			# pedras caídas no pé: desce a encosta até o chão deitar e larga algumas ali
			if rng.randf() < 0.3 * forca + 0.06:
				var p2 := Vector2(x, z)
				var achou := false
				for passo in 9:
					p2 += Vector2(fora.x, fora.z) * 4.0
					if v.normal_em(p2.x, p2.y).y > 0.9:
						achou = true
						break
				if achou and maxf(absf(p2.x), absf(p2.y)) > Clareira.C_META + 4.0 and v._fora(p2.x, p2.y) > 1.0 and not v._perto_dagua(p2.x, p2.y):
					for k in rng.randi_range(1, 3):
						var qx := p2.x + rng.randf_range(-5.0, 5.0)
						var qz := p2.y + rng.randf_range(-5.0, 5.0)
						var tam := rng.randf_range(0.5, 1.5) * (1.9 if rng.randf() < 0.15 else 1.0)
						var esc := Vector3(tam * rng.randf_range(0.8, 1.3), tam * rng.randf_range(0.6, 1.0), tam * rng.randf_range(0.8, 1.3))
						var xf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))).scaled_local(esc),
							Vector3(qx, v._fora(qx, qz) + tam * 0.15, qz))
						var vi := rng.randi() % VARIANTES
						_guardar(grupos, vi, xf, false)
						n_pe += 1
						if tam > 1.3:
							_colisao(corpo, pontos[vi], xf)
			# arbustos agarrados na beira de cima e nos degraus menos em pé
			if forca < 0.5 and rng.randf() < 0.1:
				var s := rng.randf_range(0.8, 1.5)
				arbustos.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h - 0.1, z)))
	# a falésia da borda do mapa (Vale._falesia_da_borda) é uma parede reta: colunas de rocha encostadas
	# nela, de alturas e larguras variadas, quebram a linha; no pé, pedras meio dentro d'água
	var n_borda := 0
	var ult := Vale.F_N - 1
	for lado: Array in [[Vector2i(0, 0), Vector2i(1, 0), Vector3(0, 0, -1)], [Vector2i(ult, 0), Vector2i(0, 1), Vector3(1, 0, 0)],
			[Vector2i(ult, ult), Vector2i(-1, 0), Vector3(0, 0, 1)], [Vector2i(0, ult), Vector2i(0, -1), Vector3(-1, 0, 0)]]:
		var fora: Vector3 = lado[2]
		var base := Basis.looking_at(-fora, Vector3.UP)
		for k in range(1, ult):
			var g: Vector2i = (lado[0] as Vector2i) + (lado[1] as Vector2i) * k
			var h := v._fora_h[g.y * Vale.F_N + g.x]
			if h < 1.5:
				continue
			var x := -Vale.F_META + g.x * Vale.F_PASSO
			var z := -Vale.F_META + g.y * Vale.F_PASSO
			var total := h + 15.0
			if h > 5.0 and rng.randf() < 0.42:
				var larg := rng.randf_range(5.0, 9.5) * (1.5 if rng.randf() < 0.12 else 1.0)
				var alt := h * rng.randf_range(0.45, 0.8)
				var cy := minf(h * rng.randf_range(0.2, 0.62), h + 1.0 - alt * 0.8)
				# a parede sai para fora conforme desce: a coluna fica encostada nela, na altura do meio dela
				var desce := clampf((h - cy) / total, 0.0, 1.0)
				var afasta := total * 0.3 * desce + larg * rng.randf_range(0.0, 0.25)
				var xf := Transform3D((base * Basis.from_euler(Vector3(rng.randf_range(-0.04, 0.14), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.1, 0.1))))
					.scaled_local(Vector3(larg, alt, larg * rng.randf_range(0.6, 0.9))), Vector3(x, cy, z) + fora * afasta)
				var vi := rng.randi() % VARIANTES
				_guardar(grupos, vi, xf, true)
				_colisao(corpo, pontos[vi], xf)
				n_borda += 1
			if rng.randf() < 0.3:
				var tam := rng.randf_range(1.5, 4.5) * (1.7 if rng.randf() < 0.12 else 1.0)
				var esc := Vector3(tam * rng.randf_range(0.8, 1.3), tam * rng.randf_range(0.6, 1.1), tam * rng.randf_range(0.8, 1.3))
				var xf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))).scaled_local(esc),
					Vector3(x, rng.randf_range(-0.5, 0.6) * tam * 0.5, z) + fora * (total * rng.randf_range(0.3, 0.5) + 3.0) + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)))
				var vi := rng.randi() % VARIANTES
				_guardar(grupos, vi, xf, true)
				_colisao(corpo, pontos[vi], xf)
				n_borda += 1
	print("paredões: %d rochas na falésia da borda" % n_borda)
	for chave: String in grupos:
		var partes := chave.split("|")
		var xfs: Array = grupos[chave]
		var centro := Vector3.ZERO
		for xf: Transform3D in xfs:
			centro += xf.origin
		centro /= xfs.size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malhas[int(partes[0])]
		mm.instance_count = xfs.size()
		for k in xfs.size():
			var t: Transform3D = xfs[k]
			t.origin -= centro
			mm.set_instance_transform(k, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = centro
		var grande := partes[3] == "1"
		mmi.visibility_range_end = 1500.0 if grande else 520.0
		mmi.visibility_range_end_margin = 30.0
		if not grande:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v.add_child(mmi)
	if not arbustos.is_empty():
		var blocos := {}
		for xf: Transform3D in arbustos:
			var ch := Vector2i(floori(xf.origin.x / 200.0), floori(xf.origin.z / 200.0))
			if not blocos.has(ch):
				blocos[ch] = []
			(blocos[ch] as Array).append(xf)
		for ch: Vector2i in blocos:
			var xfs: Array = blocos[ch]
			var centro := Vector3.ZERO
			for xf: Transform3D in xfs:
				centro += xf.origin
			v._multi("arbusto", xfs, centro / xfs.size(), 0.0, 420.0, false)
	print("paredões: %d blocos na parede, %d pedras no pé, %d arbustos, %d ms" % [n_parede, n_pe, arbustos.size(), Time.get_ticks_msec() - t0])


static func _guardar(grupos: Dictionary, variante: int, xf: Transform3D, grande: bool) -> void:
	var chave := "%d|%d|%d|%d" % [variante, floori(xf.origin.x / 200.0), floori(xf.origin.z / 200.0), int(grande)]
	if not grupos.has(chave):
		grupos[chave] = []
	(grupos[chave] as Array).append(xf)


## Colisão de uma rocha grande: o casco dela já no lugar (a forma não é esticada depois).
static func _colisao(corpo: StaticBody3D, pts: PackedVector3Array, xf: Transform3D) -> void:
	var casco := PackedVector3Array()
	var visto := {}
	for p in pts:
		var q := xf.basis * p
		var ch := Vector3i(roundi(q.x * 0.9), roundi(q.y * 0.9), roundi(q.z * 0.9))
		if not visto.has(ch):
			visto[ch] = true
			casco.append(q)
	var forma := ConvexPolygonShape3D.new()
	forma.points = casco
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position = xf.origin
	corpo.add_child(cs)
