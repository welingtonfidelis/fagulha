class_name CapimVivo
extends Node3D

## Capim e flores que nascem em volta do jogador conforme ele anda e voa. O mundo é dividido em blocos
## de 32 m (a mesma grade do capim da clareira); cada bloco ganha um MultiMesh de touceiras e outro de
## flores (só no platô), e é solto quando fica longe do alvo. A clareira do meio tem o seu próprio capim.

const BLOCO := 32.0  # lado do bloco, em metros
const RAIO := 104.0  # blocos cujo centro está a menos disso do alvo existem
const PASSO := 0.42  # metros entre touceiras no campo
const POR_QUADRO := 1  # blocos novos criados por quadro, no máximo
const MAX_BLOCOS := 60
const ALTURA_VOO := 70.0  # acima disso do chão não nasce capim novo
const GRADE_CAPIM := 76  # 32 / 76 = 0,42 m
const GRADE_FLOR := 42  # 32 / 29 = 1,10 m
const AMOSTRA := 2.0  # metros entre as amostras de cobertura e normal (o bloco inteiro usa 17 x 17)
const PALETA: Array[Color] = [Color(0.93, 0.30, 0.52), Color(0.98, 0.78, 0.12), Color(0.58, 0.36, 0.90), Color(0.97, 0.96, 0.88)]

var mapa: Vale
var alvo: Node3D

var blocos_vivos := 0
var touceiras := 0
var flores := 0

var _blocos := {}  # Vector2i -> [MultiMeshInstance3D do capim ou null, MultiMeshInstance3D das flores ou null]
var _fila: Array = []  # [distância ao alvo, Vector2i] dos blocos que faltam criar, o mais perto primeiro
var _t := 0.0
var _ultimo := Vector2(1e9, 1e9)
var _alvo := Vector3.ZERO
var _voando := false
var _malha_flor: ArrayMesh
var _ruido: FastNoiseLite


func _ready() -> void:
	_malha_flor = _fazer_flor()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_flor.gdshader")
	_malha_flor.surface_set_material(0, mat)
	_ruido = FastNoiseLite.new()
	_ruido.seed = 31
	_ruido.frequency = 0.012


func _process(delta: float) -> void:
	if mapa == null or alvo == null:
		return
	_t += delta
	var p := alvo.global_position
	_alvo = p
	if _t >= 0.2 or Vector2(p.x, p.z).distance_to(_ultimo) > 8.0:
		_t = 0.0
		_ultimo = Vector2(p.x, p.z)
		_atualizar(p)
	_criar_pendentes()


func _centro(chave: Vector2i) -> Vector2:
	return Vector2((chave.x + 0.5) * BLOCO, (chave.y + 0.5) * BLOCO)


func _atualizar(p: Vector3) -> void:
	_voando = p.y - mapa.altura(p.x, p.z) > ALTURA_VOO
	var xz := Vector2(p.x, p.z)
	for chave in _blocos.keys():
		if _centro(chave).distance_to(xz) > RAIO + 24.0:
			_soltar(chave)
	_fila = []
	if _voando:
		return
	var lista := []
	for bx in range(floori((p.x - RAIO) / BLOCO), floori((p.x + RAIO) / BLOCO) + 1):
		for bz in range(floori((p.z - RAIO) / BLOCO), floori((p.z + RAIO) / BLOCO) + 1):
			var chave := Vector2i(bx, bz)
			var d := _centro(chave).distance_to(xz)
			if d < RAIO and not _blocos.has(chave):
				lista.append([d, chave])
	lista.sort_custom(func(a, b): return a[0] < b[0])
	_fila = lista


func _criar_pendentes() -> void:
	if _voando:
		return
	var feitos := 0
	while feitos < POR_QUADRO and not _fila.is_empty() and blocos_vivos < MAX_BLOCOS:
		var item: Array = _fila.pop_front()
		var chave: Vector2i = item[1]
		if _blocos.has(chave):
			continue
		if _centro(chave).distance_to(Vector2(_alvo.x, _alvo.z)) >= RAIO:
			continue
		_criar(chave)
		feitos += 1


func _soltar(chave: Vector2i) -> void:
	var par: Array = _blocos[chave]
	var cap: MultiMeshInstance3D = par[0]
	var flo: MultiMeshInstance3D = par[1]
	if cap != null:
		touceiras -= cap.multimesh.instance_count
		cap.queue_free()
	if flo != null:
		flores -= flo.multimesh.instance_count
		flo.queue_free()
	if cap != null or flo != null:
		blocos_vivos -= 1
	_blocos.erase(chave)


func _semente(chave: Vector2i, extra: int) -> int:
	return (chave.x * 73856093) ^ (chave.y * 19349663) ^ (extra * 83492791) ^ 0x2F6B


## Altura do chão no ponto se ele aceita capim (água, areia, mar, encosta, fora do mapa, a menos de 115 m
## da origem); -INF se não. Entre 115 e 121 m, metade dos pontos nasce, para emendar com a clareira.
func _chao(px: float, pz: float, ny: float, rng: RandomNumberGenerator) -> float:
	if absf(px) > 990.0 or absf(pz) > 990.0:
		return -INF
	var r := Vector2(px, pz).length()
	if r < 115.0:
		return -INF
	if r < 121.0 and rng.randf() >= 0.5:
		return -INF
	if mapa.agua(px, pz) > -INF:
		return -INF
	var h := mapa.altura(px, pz)
	if h < 2.2 or ny < 0.9:
		return -INF
	return h


func _chance(c: int) -> float:
	match c:
		0, 3:
			return 1.0
		1:
			return 0.35
		2:
			return 0.12
	return 0.0


func _criar(chave: Vector2i) -> void:
	var x0 := chave.x * BLOCO
	var z0 := chave.y * BLOCO
	var cc := _centro(chave)
	var cy := mapa.altura(cc.x, cc.y)
	# cobertura e normal amostradas a cada 2 m (o resto do bloco usa a amostra mais perto)
	var n := int(BLOCO / AMOSTRA) + 1
	var ncob := PackedInt32Array()
	var nny := PackedFloat32Array()
	ncob.resize(n * n)
	nny.resize(n * n)
	for j in n:
		for i in n:
			var px := x0 + i * AMOSTRA
			var pz := z0 + j * AMOSTRA
			ncob[j * n + i] = mapa.cobertura(px, pz)
			nny[j * n + i] = 0.0 if RochaMalha.dentro(px, pz) else mapa.normal_em(px, pz).y
	var ts: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _semente(chave, 1)
	var passo := BLOCO / GRADE_CAPIM
	for j in GRADE_CAPIM:
		for i in GRADE_CAPIM:
			var px := clampf(x0 + (i + 0.5) * passo + rng.randf_range(-0.2, 0.2), x0, x0 + BLOCO - 0.001)
			var pz := clampf(z0 + (j + 0.5) * passo + rng.randf_range(-0.2, 0.2), z0, z0 + BLOCO - 0.001)
			var k := clampi(roundi((pz - z0) / AMOSTRA), 0, n - 1) * n + clampi(roundi((px - x0) / AMOSTRA), 0, n - 1)
			var h := _chao(px, pz, nny[k], rng)
			if h == -INF:
				continue
			if rng.randf() >= _chance(ncob[k]):
				continue
			var s := rng.randf_range(0.75, 1.5)
			var hy := rng.randf_range(0.8, 1.35)
			var giro := rng.randf() * TAU
			ts.append(Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(s, s * hy, s)),
				Vector3(px - cc.x, h - 0.03 - cy, pz - cc.y)))
	var tf: Array = []
	var cf: Array = []
	var rf := RandomNumberGenerator.new()
	rf.seed = _semente(chave, 2)
	var passo_f := BLOCO / GRADE_FLOR
	for j in GRADE_FLOR:
		for i in GRADE_FLOR:
			var px := clampf(x0 + (i + 0.5) * passo_f + rf.randf_range(-0.4, 0.4), x0, x0 + BLOCO - 0.001)
			var pz := clampf(z0 + (j + 0.5) * passo_f + rf.randf_range(-0.4, 0.4), z0, z0 + BLOCO - 0.001)
			var k := clampi(roundi((pz - z0) / AMOSTRA), 0, n - 1) * n + clampi(roundi((px - x0) / AMOSTRA), 0, n - 1)
			if ncob[k] != 3:
				continue
			var h := _chao(px, pz, nny[k], rf)
			if h == -INF:
				continue
			if rf.randf() >= 0.55:
				continue
			var sc := rf.randf_range(0.82, 1.18)
			var giro := rf.randf() * TAU
			var v := _ruido.get_noise_2d(px, pz) * 0.8 + 0.5
			var banda := clampi(floori(v * 4.0), 0, 3)
			if rf.randf() < 0.25:
				banda = rf.randi_range(0, 3)  # a mistura: uma flor de outra cor no meio da mancha
			tf.append(Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(1.0, sc, 1.0)),
				Vector3(px - cc.x, h - 0.02 - cy, pz - cc.y)))
			cf.append(PALETA[banda].srgb_to_linear())  # a cor da instância chega ao shader sem conversão
	var cap: MultiMeshInstance3D = null
	var flo: MultiMeshInstance3D = null
	if not ts.is_empty():
		cap = _mmi(mapa.capim_malha, ts, [], Vector3(cc.x, cy, cc.y))
		touceiras += ts.size()
	if not tf.is_empty():
		flo = _mmi(_malha_flor, tf, cf, Vector3(cc.x, cy, cc.y))
		flores += tf.size()
	_blocos[chave] = [cap, flo]
	if cap != null or flo != null:
		blocos_vivos += 1


func _mmi(malha: Mesh, ts: Array, cores: Array, centro: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cores.is_empty()
	mm.mesh = malha
	mm.instance_count = ts.size()
	for k in ts.size():
		mm.set_instance_transform(k, ts[k])
		if not cores.is_empty():
			mm.set_instance_color(k, cores[k])
	var m := MultiMeshInstance3D.new()
	m.multimesh = mm
	m.position = centro
	m.visibility_range_end = 95.0
	m.visibility_range_end_margin = 20.0
	m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


## A flor: caule verde fino (0,34 m) e cabeça de 5 pétalas em leque, inclinadas. A cor da pétala vem
## da instância (malha branca); UV2.x = 1 marca a pétala, UV.y é a altura do vértice (0 a 1).
func _fazer_flor() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.62  # acima do capim, para aparecer
	var w := 0.011
	var b1 := Vector3(-w, 0, 0)
	var b2 := Vector3(w, 0, 0)
	var m1 := Vector3(-w * 0.6, h * 0.55, 0)
	var m2 := Vector3(w * 0.6, h * 0.55, 0)
	var t := Vector3(0, h, 0)
	for v in [b1, b2, m2, b1, m2, m1, m1, m2, t]:
		_vert(st, v, v.y / h, 0.0)
	for k in 5:
		var a := k * TAU / 5.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		var lado := Vector3(-d.z, 0, d.x)
		# pétalas em taça (a ponta sobe), para a flor aparecer também de lado
		var p1 := t + d * 0.12 + lado * 0.06 + Vector3(0, 0.06, 0)
		var p2 := t + d * 0.12 - lado * 0.06 + Vector3(0, 0.06, 0)
		for v in [t, p1, p2]:
			_vert(st, v, 1.0, 1.0)
	return st.commit()


func _vert(st: SurfaceTool, v: Vector3, alt: float, petala: float) -> void:
	st.set_color(Color.WHITE)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0.0, alt))
	st.set_uv2(Vector2(petala, 0.0))
	st.add_vertex(v)
