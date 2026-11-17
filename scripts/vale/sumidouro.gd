class_name Sumidouro
extends RefCounted
## O Sumidouro: a caverna grande e vertical do vale, feita para voar dentro. Um poço aberto no alto do
## morro desce até um salão; do salão sai um túnel para a encosta; no meio do poço há uma galeria em
## anel com janelas e uma ponte de pedra, e ao lado do salão uma câmara menor.
##
## A grade de alturas do vale só guarda um chão por ponto, então aqui o morro inteiro é refeito como uma
## peça própria: a rocha é descrita por distâncias (o morro menos os vazios), vira malha por "surface
## nets" e ganha colisão. A grade é rebaixada até o piso mais fundo debaixo da peça, para a câmera e o
## resto do jogo não acharem que ali ainda é o alto do morro.
## A malha vem de RochaMalha e fica gravada em ARQUIVO (`-- --assar-rochas` gera de novo).
## `cavar` roda depois de Cavernas.cavar e antes de o chão ser montado; `montar`, no fim.

const ARQUIVO := "res://assets/vale/sumidouro.res"
const NOME := "O Sumidouro"
const POCO_RAIO := 9.0
const SALAO := Vector3(28.0, 15.0, 21.0)  # meias-medidas: ao longo da saída, altura, largura
const SALAO_Y := 9.0  # o meio do salão acima do piso
const ANEL_ALTURA := 30.0  # piso da galeria acima do piso do salão
const ANEL_RAIO := 17.0
const ANEL_TUBO := 4.2
const TUNEL_RAIO := 5.6
const CAMARA_RAIO := 11.0
const COR := Color(0.35, 0.9, 1.0)
const COR_2 := Color(1.0, 0.7, 0.35)

static var existe := false
static var centro := Vector2.ZERO  # o eixo do poço
static var topo := 0.0  # altura do morro no eixo
static var piso := 0.0  # piso do salão
static var saida := Vector2.ZERO  # a boca na encosta
static var saida_h := 0.0
static var dir := Vector2.RIGHT  # do eixo para a saída
static var varanda := Vector2.ZERO  # direção da segunda boca, na altura da galeria (zero: não tem)
static var _mn := Vector3.ZERO
static var _mx := Vector3.ZERO


## Debaixo da terra, dentro de um vazio do Sumidouro (para o som e os testes).
static func no_vazio(p: Vector3) -> bool:
	return existe and p.x > _mn.x and p.x < _mx.x and p.z > _mn.z and p.z < _mx.z \
			and p.y < Cavernas.chao_antes(p.x, p.z) - 2.0 and vazio(p) < 0.0


## Dentro da área da peça (com folga): ali não nasce árvore, rocha de paredão nem bicho.
static func dentro(x: float, z: float, folga := 4.0) -> bool:
	return existe and x > _mn.x - folga and x < _mx.x + folga and z > _mn.z - folga and z < _mx.z + folga \
			and RochaMalha.dentro(x, z, folga)


# ---------------------------------------------------------------- o lugar

static func cavar(v: Vale) -> void:
	existe = false
	var t0 := Time.get_ticks_msec()
	if not _achar_lugar(v):
		print("sumidouro: nenhum morro serviu")
		return
	existe = true
	_limites()
	RochaMalha.rebaixar(_mn, _mx, vazio)
	print("sumidouro: eixo %s, morro a %.0f m, piso a %.0f m (%.0f de fundura), boca em %s; varanda %s; %d ms"
		% [centro, topo, piso, topo - piso, saida, varanda, Time.get_ticks_msec() - t0])


## Onde ficavam as seis grutas pequenas (tiradas em 2026-11-16). A busca desviava delas; a lista continua
## aqui só para o Sumidouro não mudar de morro (a malha gravada e a cachoeira contam com este lugar).
const ANTIGAS: Array[Vector2] = [Vector2(-492.6811, -617.3805), Vector2(-618.4566, -626.3876), Vector2(-210.7176, -811.5591), Vector2(-247.4296, -770.0528),
	Vector2(284.0017, 16.83289), Vector2(333.7697, 70.8974), Vector2(-384.0333, -438.239), Vector2(-434.2597, -469.4907),
	Vector2(853.1016, -110.6418), Vector2(777.1662, -90.60742), Vector2(-667.7155, -385.8185), Vector2(-649.8335, -435.4403)]


static func _perto_das_antigas(c: Vector2) -> bool:
	for i in range(0, ANTIGAS.size(), 2):
		if Geometry2D.get_closest_point_to_segment(c, ANTIGAS[i], ANTIGAS[i + 1]).distance_to(c) < 162.0:
			return true
	return false


## Procura um morro largo com uma encosta que desça pelo menos 46 m em até 130 m: o poço abre no alto e o
## túnel sai na encosta. Sempre o mesmo lugar (a busca não sorteia nada).
static func _achar_lugar(v: Vale) -> bool:
	var melhor := INF
	for gz in range(-31, 32):
		for gx in range(-31, 32):
			var c := Vector2(gx * 24.0, gz * 24.0)
			if c.length() < 300.0 or not Ruinas.livre(c.x, c.y) or _perto_das_antigas(c):
				continue
			var h := Cavernas.chao_antes(c.x, c.y)
			if h < 70.0:
				continue
			for k in 16:
				var d := Vector2.from_angle(TAU * k / 16.0)
				var l := 70.0
				var he := 0.0
				var achou := false
				while l <= 130.0:
					he = Cavernas.chao_antes(c.x + d.x * l, c.y + d.y * l)
					if h - he >= 46.0:
						achou = true
						break
					l += 6.0
				if not achou or h - he > 60.0 or he < 12.0:
					continue
				var e := c + d * l
				if not _serve(v, c, h, e, he, d, l):
					continue
				var nota := l + absf(h - he - 50.0) * 2.0 + c.length() * 0.05
				if nota < melhor:
					melhor = nota
					centro = c
					topo = h
					saida = e
					saida_h = he
					piso = he
					dir = d
	if melhor == INF:
		return false
	# a varanda: uma direção em que a encosta desce até a altura da galeria a menos de 70 m
	varanda = Vector2.ZERO
	var perto := 70.0
	for k in 16:
		var d2 := Vector2.from_angle(TAU * k / 16.0)
		if d2.dot(dir) > 0.3:
			continue
		var l2 := ANEL_RAIO + 12.0
		while l2 < perto:
			if Cavernas.chao_antes(centro.x + d2.x * l2, centro.y + d2.y * l2) < piso + ANEL_ALTURA + 1.0:
				perto = l2
				varanda = d2 * l2
				break
			l2 += 4.0
	return true


static func _serve(v: Vale, c: Vector2, h: float, e: Vector2, he: float, d: Vector2, l: float) -> bool:
	var perp := Vector2(-d.y, d.x)
	# rocha por cima do salão, da câmara e da galeria
	for a in 12:
		for r: float in [14.0, 26.0, 38.0]:
			var q := c + Vector2.from_angle(TAU * a / 12.0) * r
			if Cavernas.chao_antes(q.x, q.y) < he + ANEL_ALTURA + 9.0 and q.distance_to(c) < 30.0:
				return false
			if (q - c).dot(d) < 20.0 and Cavernas.chao_antes(q.x, q.y) < he + SALAO.y + SALAO_Y + 5.0:
				return false
			if v.agua(q.x, q.y) > -INF or not Ruinas.livre(q.x, q.y):
				return false
	# o túnel fica coberto até perto da boca, e a boca não cai na água
	var s := 30.0
	while s < l - 16.0:
		for u: float in [-7.0, 0.0, 7.0]:
			var q := c + d * s + perp * u
			if Cavernas.chao_antes(q.x, q.y) < he + 12.0:
				return false
		s += 6.0
	for s2: float in [0.0, 12.0, 24.0]:
		var q := e + d * s2
		if v.agua(q.x, q.y) > -INF or not Ruinas.livre(q.x, q.y) or Cavernas.chao_antes(q.x, q.y) > he + 1.5:
			return false
	return maxf(absf(e.x), absf(e.y)) < 820.0


static func _limites() -> void:
	var pts: Array[Vector2] = [centro, saida + dir * 16.0, _camara_xz()]
	if varanda != Vector2.ZERO:
		pts.append(centro + varanda + varanda.normalized() * 10.0)
	var mn := centro
	var mx := centro
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	var folga := SALAO.x + 18.0
	_mn = Vector3(mn.x - folga, piso - 6.0, mn.y - folga)
	_mx = Vector3(mx.x + folga, 0.0, mx.y + folga)
	# o morro pode ser mais alto longe do eixo: a caixa cobre o ponto mais alto dele
	_mx.y = maxf(topo + 14.0, RochaMalha.alto_da_caixa(Vector2(_mn.x, _mn.z), Vector2(_mx.x, _mx.z)) + 5.0)


static func _camara_xz() -> Vector2:
	var perp := Vector2(-dir.y, dir.x)
	return centro - dir * 26.0 + perp * 30.0


# ---------------------------------------------------------------- a forma

static func _v3(xz: Vector2, y: float) -> Vector3:
	return Vector3(xz.x, y, xz.y)


## Distância até o vazio mais perto (negativa dentro dele). É o desenho da caverna.
static func vazio(p: Vector3) -> float:
	var perp := Vector2(-dir.y, dir.x)
	var q := Vector2(p.x, p.z) - centro
	var ao_longo := q.dot(dir)
	var de_lado := q.dot(perp)
	var n := RochaMalha.parede(p)
	var n2 := RochaMalha.piso(p)  # o piso ondula pouco
	# salão: elipsoide de piso chato
	var e := Vector3((ao_longo - 8.0) / SALAO.x, (p.y - piso - SALAO_Y) / SALAO.y, de_lado / SALAO.z)
	var d := maxf((e.length() - 1.0) * minf(SALAO.y, SALAO.z) * 0.9 + n, piso + n2 - p.y)
	# poço: do teto do salão até acima do morro, um pouco torto
	var torto := Vector2(RochaMalha.ruido.get_noise_2d(p.y * 1.3, 7.0), RochaMalha.ruido.get_noise_2d(11.0, p.y * 1.3)) * 3.0
	d = minf(d, maxf((q - torto).length() - POCO_RAIO + n, piso + 6.0 - p.y))
	# lagoa rasa debaixo do poço
	d = minf(d, p.distance_to(_v3(centro, piso + 5.0)) - 6.3)
	# túnel de saída, de piso chato
	var a0 := _v3(centro + dir * 24.0, piso + 3.8)
	var a1 := _v3(saida + dir * 14.0, saida_h + 3.8)
	var tt := clampf((ao_longo - 24.0) / maxf(1.0, (saida - centro).length() - 10.0), 0.0, 1.0)
	d = minf(d, maxf(RochaMalha.capsula(p, a0, a1, TUNEL_RAIO) + n, lerpf(piso, saida_h, tt) + n2 - p.y))
	# galeria em anel no meio do poço, de piso chato, com três janelas para o poço
	var ya := piso + ANEL_ALTURA
	var anel := Vector2(q.length() - ANEL_RAIO, p.y - ya - 2.6).length() - ANEL_TUBO
	d = minf(d, maxf(anel + n * 0.6, ya + n2 * 0.5 - p.y))
	for jan: Vector2 in [perp, -perp, -dir]:
		var j := RochaMalha.capsula(p, _v3(centro, ya + 2.8), _v3(centro + jan * ANEL_RAIO, ya + 2.8), 3.6)
		d = minf(d, maxf(j + n * 0.6, ya - p.y))
	# varanda: da galeria para fora do morro
	if varanda != Vector2.ZERO:
		var vn := varanda.normalized()
		var va := RochaMalha.capsula(p, _v3(centro + vn * ANEL_RAIO, ya + 3.0), _v3(centro + varanda + vn * 10.0, ya + 3.0), 4.4)
		d = minf(d, maxf(va + n * 0.6, ya + n2 * 0.5 - p.y))
	# câmara ao lado do salão, com a passagem
	var cam := _camara_xz()
	d = minf(d, maxf(p.distance_to(_v3(cam, piso + 7.0)) - CAMARA_RAIO + n, piso + 1.5 + n2 - p.y))
	var passagem := RochaMalha.capsula(p, _v3(centro - dir * 10.0 + perp * 12.0, piso + 4.0), _v3(cam, piso + 5.0), 4.0)
	d = minf(d, maxf(passagem + n, piso + 0.6 + n2 - p.y))
	return d


## Rocha posta de volta dentro dos vazios: a ponte que cruza o poço e dois pilares no salão.
static func extra(p: Vector3) -> float:
	var perp := Vector2(-dir.y, dir.x)
	var ya := piso + ANEL_ALTURA
	var n := RochaMalha.fino.get_noise_3d(p.x * 0.7, p.y * 0.7, p.z * 0.7) * 0.45
	var ponte := RochaMalha.capsula(p, _v3(centro - perp * (ANEL_RAIO + 2.0), ya - 2.0), _v3(centro + perp * (ANEL_RAIO + 2.0), ya - 2.0), 2.3)
	ponte = maxf(ponte, p.y - ya)  # o tampo é chato, na altura do piso da galeria
	var d := ponte
	for lado: float in [-1.0, 1.0]:
		var pe := centro + dir * 21.0 + perp * lado * 10.0
		var cintura := 2.0 + 1.6 * pow(minf(1.3, absf((p.y - piso - 9.0) / 9.0)), 2.0)
		d = minf(d, maxf(Vector2(p.x - pe.x, p.z - pe.y).length() - cintura, p.y - piso - 27.0))
	return d + n


static func assar() -> void:
	if existe:
		RochaMalha.assar(_mn, _mx, vazio, extra, ARQUIVO, Vector3(centro.x, piso, centro.y))


# ---------------------------------------------------------------- no vale

static func montar(v: Vale) -> void:
	if not existe or not RochaMalha.montar(ARQUIVO, "Sumidouro", Vector3(centro.x, piso, centro.y)):
		return
	_enfeites(v)


static func _enfeites(v: Vale) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var perp := Vector2(-dir.y, dir.x)
	var ya := piso + ANEL_ALTURA
	# estalactites e estalagmites no salão e na câmara (fora do poço)
	var pontos: Array[Vector2] = []
	for i in 260:
		var xz := centro + dir * rng.randf_range(-24.0, 38.0) + perp * rng.randf_range(-22.0, 22.0)
		if i % 4 == 0:
			xz = _camara_xz() + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 10.0)
		if xz.distance_to(centro) > POCO_RAIO + 5.0:
			pontos.append(xz)
	RochaMalha.pingentes(pontos, func(_xz: Vector2) -> float: return piso + 3.0, vazio, extra, 5152)
	# cristais acesos: no salão, na câmara, no túnel e na galeria
	var lugares: Array = [
		[centro + dir * 30.0 + perp * 12.0, piso + 3.0, COR], [centro + dir * 30.0 - perp * 13.0, piso + 3.0, COR],
		[centro - dir * 12.0 - perp * 14.0, piso + 3.0, COR], [centro + dir * 4.0 + perp * 17.0, piso + 3.0, COR],
		[_camara_xz() + dir * 5.0, piso + 4.5, COR_2], [_camara_xz() - dir * 6.0 + perp * 3.0, piso + 4.5, COR_2],
		[centro.lerp(saida, 0.55) + perp * 3.5, lerpf(piso, saida_h, 0.5) + 2.5, COR],
		[centro + dir * ANEL_RAIO, ya + 2.0, COR_2], [centro - dir * ANEL_RAIO * 0.7 + perp * ANEL_RAIO * 0.7, ya + 2.0, COR_2],
		[centro - dir * ANEL_RAIO * 0.7 - perp * ANEL_RAIO * 0.7, ya + 2.0, COR_2]]
	for l: Array in lugares:
		var xz: Vector2 = l[0]
		var pt := RochaMalha.piso_teto(xz.x, xz.y, l[1], vazio, extra)
		if pt.x != INF:
			RochaMalha.cristal(Vector3(xz.x, pt.x, xz.y), l[2], rng)
	# uma luz fria e fraca no meio do salão, para o fundo não ficar um breu
	var geral := OmniLight3D.new()
	geral.light_color = Color(0.55, 0.8, 1.0)
	geral.light_energy = 1.1
	geral.omni_range = 34.0
	geral.omni_attenuation = 0.7
	geral.shadow_enabled = false
	geral.position = _v3(centro + dir * 8.0, piso + 12.0)
	v.add_child(geral)
	_lagoa(v)
	_vida(v)


static var morcegos: Morcegos


## Morcegos no poço (abaixo e acima da ponte) e vaga-lumes no salão e na câmara.
static func _vida(v: Vale) -> void:
	morcegos = Morcegos.new()
	morcegos.eixo = _v3(centro, piso)
	morcegos.faixas = [Vector2(9.0, ANEL_ALTURA - 6.0), Vector2(ANEL_ALTURA + 5.0, topo - piso - 4.0)]
	v.add_child(morcegos)
	for lugar: Array in [[_v3(centro + dir * 8.0, piso + 5.0), Vector3(24, 4.5, 17), 46, COR],
			[_v3(_camara_xz(), piso + 5.5), Vector3(7, 3, 7), 16, COR_2]]:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = lugar[1]
		pm.gravity = Vector3.ZERO
		pm.direction = Vector3(1, 0.3, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 0.15
		pm.initial_velocity_max = 0.5
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.6
		pm.turbulence_noise_scale = 3.0
		var curva := Curve.new()
		curva.add_point(Vector2(0, 0))
		curva.add_point(Vector2(0.2, 1))
		curva.add_point(Vector2(0.8, 1))
		curva.add_point(Vector2(1, 0))
		var ct := CurveTexture.new()
		ct.curve = curva
		pm.scale_curve = ct
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = (lugar[3] as Color).lerp(Color(1, 1, 0.7), 0.5)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var quad := QuadMesh.new()
		quad.size = Vector2(0.13, 0.13)
		quad.material = mat
		var gp := GPUParticles3D.new()
		gp.process_material = pm
		gp.draw_pass_1 = quad
		gp.amount = lugar[2]
		gp.lifetime = 9.0
		gp.preprocess = 9.0
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gp.visibility_aabb = AABB(-(lugar[1] as Vector3) - Vector3.ONE * 4.0, (lugar[1] as Vector3) * 2.0 + Vector3.ONE * 8.0)
		gp.position = lugar[0]
		v.add_child(gp)


## A lagoa debaixo do poço. A água de verdade (respingo, esfriar) vem de Vale.agua, que pergunta aqui.
const LAGOA_RAIO := 5.6
const LAGOA_FUNDO := 0.45  # quanto a lâmina fica abaixo do piso do salão


static func agua(x: float, z: float) -> float:
	if existe and Vector2(x, z).distance_to(centro) < LAGOA_RAIO:
		return piso - LAGOA_FUNDO
	return -INF


static func _lagoa(v: Vale) -> void:
	var lago := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = LAGOA_RAIO
	disco.bottom_radius = LAGOA_RAIO
	disco.height = 0.02
	disco.radial_segments = 32
	lago.mesh = disco
	var ml := StandardMaterial3D.new()
	ml.albedo_color = Color(0.1, 0.45, 0.55, 0.78)
	ml.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ml.roughness = 0.08
	ml.metallic = 0.3
	ml.emission_enabled = true
	ml.emission = Color(0.1, 0.6, 0.7)
	ml.emission_energy_multiplier = 0.35
	lago.material_override = ml
	lago.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lago.position = _v3(centro, piso - LAGOA_FUNDO)
	v.add_child(lago)
