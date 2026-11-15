class_name ChaoVivo
extends Node3D
## Vegetação rasteira só em volta do jogador (2026-11-14): a ilha é grande demais para ter grama em tudo.
## O chão é dividido em células de 32 m. As que estão num raio de 3 células do alvo ficam vivas; cada
## uma tem touceiras de grama, samambaias de folha larga e flores de destaque. Tudo é sorteado com uma
## semente tirada da própria célula, então a mesma célula sai sempre igual.
##
## Uso: crie o nó, atribua `mapa` (um Ilha ou Mundo já gerado) e `alvo` (o Node3D do jogador) e só
## depois faça add_child. Sem os dois, não faz nada.

const SH_GRAMA := preload("res://scripts/shaders/grama.gdshader")
const SH_PLANTA := preload("res://scripts/shaders/planta_estilo.gdshader")

const CELULA := 32.0
const RAIO_CELULAS := 3
const VISIVEL_ATE := 110.0
const CRIAR_POR_QUADRO := 2
const N_TOUCEIRAS := 350
const N_SAMAMBAIAS := 40
const N_FLORES := 10
const LIMITE_COS_NORMAL := 0.86  # inclinação máxima: normal.y acima disso

var mapa: Ilha
var alvo: Node3D

var _vivas := {}  # Vector2i -> Node3D (a raiz da célula)
var _fila: Array = []  # células a criar, da mais perto para a mais longe
var _centro := Vector2i(999999, 999999)  # célula em que o alvo estava na última checagem
var _malha_touceira: ArrayMesh
var _malha_samambaia: ArrayMesh
var _malha_flor: ArrayMesh
var _mat_grama: ShaderMaterial
var _mat_planta: ShaderMaterial


func _ready() -> void:
	_preparar()


func _process(_delta: float) -> void:
	if mapa == null or alvo == null:
		return
	var c := _celula_de(alvo.global_position)
	if c != _centro:
		_centro = c
		_atualizar_celulas(c)
	for _i in CRIAR_POR_QUADRO:
		if _fila.is_empty():
			break
		var k: Vector2i = _fila.pop_front()
		if not _vivas.has(k):
			_vivas[k] = _montar_celula(k)


## Quantas células estão vivas agora (para teste).
func total_celulas() -> int:
	return _vivas.size()


# ---------------------------------------------------------------- células

func _celula_de(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELULA), floori(p.z / CELULA))


func _atualizar_celulas(c: Vector2i) -> void:
	var lista: Array[Vector2i] = []
	var quero := {}
	for dz in range(-RAIO_CELULAS, RAIO_CELULAS + 1):
		for dx in range(-RAIO_CELULAS, RAIO_CELULAS + 1):
			if dx * dx + dz * dz <= RAIO_CELULAS * RAIO_CELULAS:
				var k := c + Vector2i(dx, dz)
				quero[k] = true
				lista.append(k)
	# libera as que saíram do raio
	for k in _vivas.keys():
		if not quero.has(k):
			_vivas[k].queue_free()
			_vivas.erase(k)
	# fila das que faltam, da mais perto para a mais longe
	lista.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - c).length_squared() < (b - c).length_squared())
	_fila.clear()
	for k in lista:
		if not _vivas.has(k):
			_fila.append(k)


func _montar_celula(k: Vector2i) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Celula_%d_%d" % [k.x, k.y]
	add_child(raiz)
	var r := RandomNumberGenerator.new()
	r.seed = hash(k)
	var origem := Vector2(k.x * CELULA, k.y * CELULA)
	raiz.add_child(_multimesh(_malha_touceira, _mat_grama,
			_espalhar(r, origem, N_TOUCEIRAS, 0.7, 1.3), PackedColorArray()))
	raiz.add_child(_multimesh(_malha_samambaia, _mat_planta,
			_espalhar(r, origem, N_SAMAMBAIAS, 0.8, 1.2), PackedColorArray()))
	var flores := _espalhar(r, origem, N_FLORES, 0.8, 1.3)
	var tons := PackedColorArray()
	for i in flores.size():
		tons.append(Color(float(r.randi() % 2), 0.0, 0.0, 0.0))
	raiz.add_child(_multimesh(_malha_flor, _mat_planta, flores, tons))
	return raiz


## Sorteia `n` posições dentro da célula que caem em chão seco e pouco inclinado.
## Tenta até 4n vezes; se o chão for ruim, sai com menos.
func _espalhar(r: RandomNumberGenerator, origem: Vector2, n: int, e_min: float, e_max: float) -> Array[Transform3D]:
	var xfs: Array[Transform3D] = []
	var tentativas := 0
	while xfs.size() < n and tentativas < n * 4:
		tentativas += 1
		var x := origem.x + r.randf() * CELULA
		var z := origem.y + r.randf() * CELULA
		if mapa.agua(x, z) != -INF:
			continue
		if mapa.normal_em(x, z).y <= LIMITE_COS_NORMAL:
			continue
		var e := r.randf_range(e_min, e_max)
		var giro := r.randf() * TAU
		var base := Basis(Vector3.UP, giro).scaled(Vector3.ONE * e)
		xfs.append(Transform3D(base, Vector3(x, mapa.altura(x, z) - 0.03, z)))
	return xfs


func _multimesh(malha: ArrayMesh, mat: ShaderMaterial, xfs: Array[Transform3D], tons: PackedColorArray) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malha
	mm.use_custom_data = tons.size() > 0
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, tons[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = VISIVEL_ATE
	mmi.visibility_range_end_margin = 12.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return mmi


# ---------------------------------------------------------------- malhas (uma vez só)

func _preparar() -> void:
	if _malha_touceira != null:
		return
	_malha_touceira = _montar_touceira()
	_malha_samambaia = _montar_samambaia()
	_malha_flor = _montar_flor()
	_mat_grama = ShaderMaterial.new()
	_mat_grama.shader = SH_GRAMA
	_mat_planta = ShaderMaterial.new()
	_mat_planta.shader = SH_PLANTA


## Touceira de grama: 14 lâminas que saem do centro, pé escuro e ponta clara (como canion.gd).
## 84 triângulos.
func _montar_touceira() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var pe := Color8(46, 62, 24).srgb_to_linear()
	var ponta := Color8(150, 165, 80).srgb_to_linear()
	for f in 14:
		var ang := r.randf() * TAU
		var dir := Vector3(cos(ang), 0, sin(ang))
		var lado := Vector3(-dir.z, 0, dir.x)
		var base := dir * r.randf_range(0.0, 0.25)
		var alt := r.randf_range(0.45, 0.95)
		var curva := r.randf_range(0.15, 0.4)
		var larg := r.randf_range(0.03, 0.05)
		var segs := 3
		for k in segs:
			var t0 := float(k) / segs
			var t1 := float(k + 1) / segs
			var p0 := base + dir * curva * t0 * t0 + Vector3(0, alt * t0, 0)
			var p1 := base + dir * curva * t1 * t1 + Vector3(0, alt * t1, 0)
			var w0 := larg * (1.0 - t0)
			var w1 := larg * (1.0 - t1) + 0.002
			var nrm := (Vector3.UP * 0.6 + dir).normalized()
			_fita(st, p0, p1, lado, w0, w1, pe.lerp(ponta, t0), pe.lerp(ponta, t1), nrm)
	return st.commit()


## Samambaia: 7 folhas largas e arqueadas saindo do centro, ~0,9 m de altura. Pé azulado, ponta oliva.
## 56 triângulos.
func _montar_samambaia() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var pe := Color8(30, 56, 56).srgb_to_linear()
	var ponta := Color8(104, 116, 52).srgb_to_linear()
	for f in 7:
		var ang := (float(f) / 7.0) * TAU + r.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var lado := Vector3(-dir.z, 0, dir.x)
		var comp := r.randf_range(0.36, 0.5)
		var alt := r.randf_range(0.75, 0.95)
		var largura := r.randf_range(0.09, 0.12)
		var segs := 4
		for k in segs:
			var t0 := float(k) / segs
			var t1 := float(k + 1) / segs
			var p0 := _ponto_folha(dir, comp, alt, t0)
			var p1 := _ponto_folha(dir, comp, alt, t1)
			var w0 := largura * pow(1.0 - t0, 0.8) + 0.004
			var w1 := largura * pow(1.0 - t1, 0.8) + 0.004
			var nrm := (Vector3.UP * 0.6 + dir).normalized()
			_fita(st, p0, p1, lado, w0, w1, pe.lerp(ponta, t0), pe.lerp(ponta, t1), nrm)
	return st.commit()


func _ponto_folha(dir: Vector3, comp: float, alt: float, t: float) -> Vector3:
	return dir * comp * t + Vector3(0, alt * sin(t * PI * 0.5) - 0.55 * t * t, 0)


## Flor de destaque: haste fina (alfa 1) e uma ponta pequena em losango (alfa 0, cor vem da instância).
## 10 triângulos.
func _montar_flor() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var talo := Color8(72, 86, 42).srgb_to_linear()
	talo.a = 1.0
	var alto := 0.55
	var curva := 0.06
	var lado := Vector3(0, 0, 1)
	var segs := 3
	for k in segs:
		var t0 := float(k) / segs
		var t1 := float(k + 1) / segs
		var p0 := Vector3(curva * t0 * t0, alto * t0, 0)
		var p1 := Vector3(curva * t1 * t1, alto * t1, 0)
		var w0 := 0.009 * (1.0 - t0 * 0.4)
		var w1 := 0.009 * (1.0 - t1 * 0.4)
		_fita(st, p0, p1, lado, w0, w1, talo, talo, Vector3.UP)
	# ponta: losango pequeno em cima da haste, alfa 0 marca a parte que recebe a cor da flor
	var c := Vector3(curva, alto, 0)
	var s := 0.035
	var topo := c + Vector3(0, 0.07, 0)
	var cantos := [c + Vector3(s, 0, 0), c + Vector3(0, 0, s), c + Vector3(-s, 0, 0), c + Vector3(0, 0, -s)]
	var marca := Color(1, 1, 1, 0)
	for i in 4:
		var a: Vector3 = cantos[i]
		var b: Vector3 = cantos[(i + 1) % 4]
		var nrm := ((a + b) * 0.5 - c + Vector3.UP * 0.5).normalized()
		for v in [a, b, topo]:
			st.set_color(marca)
			st.set_normal(nrm)
			st.add_vertex(v)
	return st.commit()


## Uma fita (dois triângulos por trecho) de p0 a p1, com largura w0/w1 para os lados de `lado`.
func _fita(st: SurfaceTool, p0: Vector3, p1: Vector3, lado: Vector3, w0: float, w1: float, c0: Color, c1: Color, nrm: Vector3) -> void:
	var vs := [
		[p0 - lado * w0, c0], [p0 + lado * w0, c0], [p1 + lado * w1, c1],
		[p0 - lado * w0, c0], [p1 + lado * w1, c1], [p1 - lado * w1, c1]]
	for v in vs:
		st.set_color(v[1])
		st.set_normal(nrm)
		st.add_vertex(v[0])
