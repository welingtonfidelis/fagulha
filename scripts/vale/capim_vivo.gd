class_name CapimVivo
extends Node3D

## Capim e flores que nascem em volta do jogador conforme ele anda e voa. O mundo é dividido em blocos
## de 32 m (a mesma grade do capim da clareira); cada bloco ganha um MultiMesh de touceiras e outro de
## flores (só no platô), e é solto quando fica longe do alvo. A clareira do meio tem o seu próprio capim.

const BLOCO := 32.0  # lado do bloco, em metros
const RAIO := 118.0  # blocos cujo centro está a menos disso do alvo existem (cobre os 88 m do capim à vista)
const PASSO := 0.42  # metros entre touceiras no campo
const POR_QUADRO := 1  # blocos novos criados por quadro, no máximo
const MAX_BLOCOS := 60
const ALTURA_VOO := 70.0  # acima disso do chão não nasce capim novo
const GRADE_CAPIM := 76  # 32 / 76 = 0,42 m
const GRADE_FLOR := 42  # 32 / 29 = 1,10 m
const BLOCO_L := 64.0  # os tufos de longe: blocos maiores, tufos grandes e raros
const RAIO_L := 220.0
const GRADE_L := 36  # 64 / 36 = 1,8 m entre tufos
const NASCE_DE := 62.0  # crescem onde o capim de verdade vai acabando
const NASCE_ATE := 88.0
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
var tufos := 0
var _longe := {}  # Vector2i -> MultiMeshInstance3D dos tufos de longe (ou null)
var _fila_l: Array = []
var _malha_tufo: ArrayMesh
# As contas de cada bloco (uns 3 mil sorteios, com altura e água de cada ponto) rodam fora do quadro, numa
# tarefa do WorkerThreadPool: no quadro principal elas custavam de 8 a 10 ms por bloco (medido em 2026-11-19).
const EM_VOO := 2  # tarefas ao mesmo tempo, no máximo
var _tarefas := {}  # Vector3i(x, z, tipo) -> id da tarefa
var _prontos: Array = []  # [tipo, chave, dados] que as tarefas entregam
var _trava := Mutex.new()


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
	for chave in _longe.keys():
		if _centro_l(chave).distance_to(xz) > RAIO_L + 48.0:
			var velho: MultiMeshInstance3D = _longe[chave]
			if velho != null:
				tufos -= velho.multimesh.instance_count
				velho.queue_free()
			_longe.erase(chave)
	_fila = []
	_fila_l = []
	if _voando:
		return
	var lista_l := []
	for bx in range(floori((p.x - RAIO_L) / BLOCO_L), floori((p.x + RAIO_L) / BLOCO_L) + 1):
		for bz in range(floori((p.z - RAIO_L) / BLOCO_L), floori((p.z + RAIO_L) / BLOCO_L) + 1):
			var chave := Vector2i(bx, bz)
			var d := _centro_l(chave).distance_to(xz)
			if d < RAIO_L and not _longe.has(chave):
				lista_l.append([d, chave])
	lista_l.sort_custom(func(a, b): return a[0] < b[0])
	_fila_l = lista_l
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
	_recolher()
	if _voando:
		return
	var xz := Vector2(_alvo.x, _alvo.z)
	while _tarefas.size() < EM_VOO and not _fila.is_empty() and blocos_vivos < MAX_BLOCOS:
		var chave: Vector2i = (_fila.pop_front() as Array)[1]
		if _blocos.has(chave) or _tarefas.has(Vector3i(chave.x, chave.y, 0)) or _centro(chave).distance_to(xz) >= RAIO:
			continue
		_lancar(0, chave)
	# os tufos de longe só quando o capim de perto está em dia
	if _fila.is_empty() and _tarefas.size() < EM_VOO and not _fila_l.is_empty():
		var chave_l: Vector2i = (_fila_l.pop_front() as Array)[1]
		if not _longe.has(chave_l) and not _tarefas.has(Vector3i(chave_l.x, chave_l.y, 1)):
			_lancar(1, chave_l)


func _lancar(tipo: int, chave: Vector2i) -> void:
	if _malha_tufo == null and tipo == 1:
		_malha_tufo = _fazer_tufo()
	_tarefas[Vector3i(chave.x, chave.y, tipo)] = WorkerThreadPool.add_task(_trabalho.bind(tipo, chave))


## Roda numa tarefa, fora do quadro: só lê o mapa (alturas, água, cobertura) e devolve os números prontos.
func _trabalho(tipo: int, chave: Vector2i) -> void:
	var d: Dictionary = _calcular(chave) if tipo == 0 else _calcular_longe(chave)
	_trava.lock()
	_prontos.append([tipo, chave, d])
	_trava.unlock()


## No quadro principal: pega o que as tarefas entregaram e monta os blocos (só criar os MultiMesh).
func _recolher() -> void:
	if _tarefas.is_empty():
		return
	_trava.lock()
	var chegou := _prontos
	_prontos = []
	_trava.unlock()
	var xz := Vector2(_alvo.x, _alvo.z)
	for item: Array in chegou:
		var tipo: int = item[0]
		var chave: Vector2i = item[1]
		var k := Vector3i(chave.x, chave.y, tipo)
		if _tarefas.has(k):
			WorkerThreadPool.wait_for_task_completion(_tarefas[k])
			_tarefas.erase(k)
		# o robô pode ter ido embora enquanto a conta rodava
		if tipo == 0:
			if not _blocos.has(chave) and _centro(chave).distance_to(xz) < RAIO + 24.0:
				_montar(chave, item[2])
		elif not _longe.has(chave) and _centro_l(chave).distance_to(xz) < RAIO_L + 48.0:
			_montar_longe(chave, item[2])


func _exit_tree() -> void:
	for k in _tarefas:
		WorkerThreadPool.wait_for_task_completion(_tarefas[k])
	_tarefas.clear()


## Doze números por peça, na ordem que o MultiMesh guarda (as três linhas da matriz, cada uma com a posição).
static func _por_t(buf: PackedFloat32Array, t: Transform3D) -> void:
	var b := t.basis
	var o := t.origin
	buf.append_array(PackedFloat32Array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z]))


func _centro_l(chave: Vector2i) -> Vector2:
	return Vector2((chave.x + 0.5) * BLOCO_L, (chave.y + 0.5) * BLOCO_L)


## Um bloco de tufos de longe: poucos, largos e altos, só para o campo distante ter relevo e contorno.
func _calcular_longe(chave: Vector2i) -> Dictionary:
	var x0 := chave.x * BLOCO_L
	var z0 := chave.y * BLOCO_L
	var cc := _centro_l(chave)
	var cy := mapa.altura(cc.x, cc.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = _semente(chave, 7)
	var passo := BLOCO_L / GRADE_L
	var ts := PackedFloat32Array()
	for j in GRADE_L:
		for i in GRADE_L:
			var px := x0 + (i + rng.randf()) * passo
			var pz := z0 + (j + rng.randf()) * passo
			var sorte := rng.randf()
			var s := rng.randf_range(1.5, 2.6)
			var hy := rng.randf_range(0.75, 1.2)
			var giro := rng.randf() * TAU
			if sorte >= _chance(mapa.cobertura(px, pz)):
				continue
			var ny := 0.0 if RochaMalha.dentro(px, pz) else mapa.normal_em(px, pz).y
			var h := _chao(px, pz, ny, rng)
			if h == -INF:
				continue
			_por_t(ts, Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(s, s * hy, s)), Vector3(px - cc.x, h - 0.05 - cy, pz - cc.y)))
	return {"ts": ts, "centro": Vector3(cc.x, cy, cc.y)}


func _montar_longe(chave: Vector2i, d: Dictionary) -> void:
	var ts: PackedFloat32Array = d["ts"]
	var m: MultiMeshInstance3D = null
	if not ts.is_empty():
		m = _mmi(_malha_tufo, ts, 12, d["centro"])
		m.visibility_range_end = RAIO_L + 50.0
		tufos += ts.size() / 12
	_longe[chave] = m


## O tufo de longe: 6 folhas largas de um triângulo só (de longe é o contorno que conta).
func _fazer_tufo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 4
	for f in 6:
		var ang := f * TAU / 6.0 + r.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var lado := Vector3(-dir.z, 0, dir.x)
		var base := dir * r.randf_range(0.02, 0.16)
		var alt := r.randf_range(0.26, 0.42)
		var larg := r.randf_range(0.07, 0.10)
		for v in [base - lado * larg, base + lado * larg, base + dir * r.randf_range(0.06, 0.16) + Vector3(0, alt, 0)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var malha := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_capim.gdshader")
	mat.set_shader_parameter("ruido", (mapa.capim_malha.surface_get_material(0) as ShaderMaterial).get_shader_parameter("ruido"))
	mat.set_shader_parameter("some_ate", RAIO_L)
	mat.set_shader_parameter("nasce_de", NASCE_DE)
	mat.set_shader_parameter("nasce_ate", NASCE_ATE)
	malha.surface_set_material(0, mat)
	return malha


func _soltar(chave: Vector2i) -> void:
	var par: Array = _blocos[chave]
	var cap: MultiMeshInstance3D = par[0]
	var flo: MultiMeshInstance3D = par[1]
	var cap_perto: MultiMeshInstance3D = par[2] if par.size() > 2 else null
	if cap != null:
		touceiras -= cap.multimesh.instance_count
		cap.queue_free()
	if cap_perto != null:
		touceiras -= cap_perto.multimesh.instance_count
		cap_perto.queue_free()
	var alto: MultiMeshInstance3D = par[3] if par.size() > 3 else null
	if alto != null:
		touceiras -= alto.multimesh.instance_count
		alto.queue_free()
	if flo != null:
		flores -= flo.multimesh.instance_count
		flo.queue_free()
	if cap != null or flo != null or cap_perto != null or alto != null:
		blocos_vivos -= 1
	_blocos.erase(chave)


func _semente(chave: Vector2i, extra: int) -> int:
	return (chave.x * 73856093) ^ (chave.y * 19349663) ^ (extra * 83492791) ^ 0x2F6B


## Altura do chão no ponto se ele aceita capim (água, areia, mar, encosta, fora do mapa, a menos de 115 m
## da origem); -INF se não. Entre 115 e 121 m, metade dos pontos nasce, para emendar com a clareira.
func _chao(px: float, pz: float, ny: float, rng: RandomNumberGenerator) -> float:
	if absf(px) > Vale.F_META - 10.0 or absf(pz) > Vale.F_META - 10.0:
		return -INF
	var r := Vector2(px, pz).length()
	if r < 115.0:
		return -INF
	if r < 121.0 and rng.randf() >= 0.5:
		return -INF
	if mapa.agua(px, pz) > -INF:
		return -INF
	# em cima das lajes da pista do Anel só nasce um tufo ou outro, pelas frestas; nos vãos, o capim de sempre
	if Pista.em(px, pz) == 1 and rng.randf() > 0.1:
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


func _calcular(chave: Vector2i) -> Dictionary:
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
	var altos := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = _semente(chave, 1)
	var grade := roundi(GRADE_CAPIM / Clareira.TUFO_PASSO)
	var passo := BLOCO / grade
	for j in grade:
		for i in grade:
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
			# manchas de capim alto: metade dos tufos da mancha, do modelo comprido
			if mapa.capim_alto_malha != null and _ruido.get_noise_2d(px * 4.0 + 300.0, pz * 4.0 - 170.0) > 0.32:
				if (i + j) % 2 == 0:
					_por_t(altos, Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s)),
						Vector3(px - cc.x, h - 0.03 - cy, pz - cc.y)))
				continue
			ts.append(Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(s, s * hy, s)),
				Vector3(px - cc.x, h - 0.03 - cy, pz - cc.y)))
	var tf := PackedFloat32Array()  # flores: a peça e a cor (16 números)
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
			_por_t(tf, Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(1.0, sc, 1.0)),
				Vector3(px - cc.x, h - 0.02 - cy, pz - cc.y)))
			var cor := PALETA[banda].srgb_to_linear()  # a cor da instância chega ao shader sem conversão
			tf.append_array(PackedFloat32Array([cor.r, cor.g, cor.b, cor.a]))
	# duas densidades: uma parte das touceiras, maiores, vai até o fim; o resto só existe perto do robô
	var longe := PackedFloat32Array()
	var perto := PackedFloat32Array()  # a peça e o dado que marca "só de perto" (16 números)
	for t0: Transform3D in ts:
		if rng.randf() < Qualidade.PARTE_LONGE:
			_por_t(longe, Transform3D(t0.basis.scaled_local(Vector3.ONE * Qualidade.ESCALA_LONGE), t0.origin))
		else:
			_por_t(perto, t0)
			perto.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	return {"longe": longe, "perto": perto, "flores": tf, "altos": altos, "centro": Vector3(cc.x, cy, cc.y)}


func _montar(chave: Vector2i, d: Dictionary) -> void:
	var centro: Vector3 = d["centro"]
	var longe: PackedFloat32Array = d["longe"]
	var perto: PackedFloat32Array = d["perto"]
	var tf: PackedFloat32Array = d["flores"]
	var altos: PackedFloat32Array = d["altos"]
	var cap: MultiMeshInstance3D = null
	var cap_perto: MultiMeshInstance3D = null
	var flo: MultiMeshInstance3D = null
	var alto: MultiMeshInstance3D = null
	if not longe.is_empty():
		cap = _mmi(mapa.capim_malha, longe, 12, centro)
	if not perto.is_empty():
		cap_perto = _mmi(mapa.capim_malha, perto, 16, centro, true)
	touceiras += longe.size() / 12 + perto.size() / 16
	if not tf.is_empty():
		flo = _mmi(_malha_flor, tf, 16, centro, false, true)
		flores += tf.size() / 16
	if not altos.is_empty():
		alto = _mmi(mapa.capim_alto_malha, altos, 12, centro)
		touceiras += altos.size() / 12
	_blocos[chave] = [cap, flo, cap_perto, alto]
	if cap != null or flo != null or cap_perto != null or alto != null:
		blocos_vivos += 1


## `buf` já vem no formato do MultiMesh: `por_peca` números por peça (12 da posição, mais 4 da cor ou do dado).
func _mmi(malha: Mesh, buf: PackedFloat32Array, por_peca: int, centro: Vector3, perto := false, cores := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = cores
	mm.use_custom_data = perto
	mm.mesh = malha
	mm.instance_count = buf.size() / por_peca
	mm.buffer = buf
	var m := MultiMeshInstance3D.new()
	m.multimesh = mm
	m.position = centro
	m.visibility_range_end = Qualidade.CAPIM_ATE + Qualidade.RAIO_BLOCO + 2.0
	m.visibility_range_end_margin = 4.0
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if perto:
		m.add_to_group("capim_perto")
		Qualidade.preparar_capim_perto(m)
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
