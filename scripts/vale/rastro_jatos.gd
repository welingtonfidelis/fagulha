class_name RastroJatos
extends MeshInstance3D
## O rastro dos jatos dos pés (prêmio das rotas do piloto de teste, doc §136): duas fitas de luz que ficam no ar
## atrás do robô quando ele voa depressa, na cor escolhida na oficina (`Rotas.rastro`; vazio, sem rastro).
## As fitas são refeitas a cada quadro, viradas para a câmera, e somem em `VIDA` segundos.

const VIDA := 0.8
const LARGURA := 0.16
const PERTO_SOME := 1.5  # m da câmera: a fita some (atrás do robô ela vem direto para a câmera)
const PERTO_INTEIRA := 5.0
const VEL_MIN := 9.0  # m/s: devagar não deixa rastro
const PASSO := 0.35  # metros entre um ponto e outro da fita

var armadura: Armadura
var pontos := 0  # pontos vivos agora (testes)

var _pes: Array[Node3D] = []
var _visual: Node
var _trilhas: Array = [[], []]  # por pé: [[posição, idade], ...] do mais novo para o mais velho
var _im := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()


func _ready() -> void:
	top_level = true
	mesh = _im
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0


func _achar_pes() -> void:
	_pes.clear()
	_visual = armadura.visual if armadura else null
	if _visual == null:
		return
	for n in _visual.find_children("chama_pe*", "", true, false):
		if n is Node3D:
			_pes.append(n)
	_pes = _pes.slice(0, 2)


func _onde_pes() -> Array[Vector3]:
	var lista: Array[Vector3] = []
	for n in _pes:
		if is_instance_valid(n):
			lista.append(n.global_position)
	if lista.size() < 2:
		# sem os bicos no modelo (o robô anterior): dois pontos atrás dos quadris
		var b := armadura.global_basis
		var meio := armadura.global_position + Vector3(0, armadura.altura_corpo() * 0.3, 0)
		lista = [meio + b.x * 0.18, meio - b.x * 0.18]
	return lista


func _process(delta: float) -> void:
	if armadura == null:
		return
	if armadura.visual != _visual or (not _pes.is_empty() and not is_instance_valid(_pes[0])):
		_achar_pes()
	var cor: Color = Rotas.CORES.get(Rotas.rastro, Color(0, 0, 0, 0))
	var liga: bool = Rotas.rastro != "" and armadura.em_voo() and armadura.velocity.length() > VEL_MIN and armadura.visual != null and armadura.visual.visible
	pontos = 0
	for k in 2:
		var tr: Array = _trilhas[k]
		for item: Array in tr:
			item[1] = float(item[1]) + delta
		while not tr.is_empty() and float(tr[tr.size() - 1][1]) > VIDA:
			tr.pop_back()
	if liga:
		var pes := _onde_pes()
		for k in 2:
			var tr: Array = _trilhas[k]
			if tr.is_empty() or (tr[0][0] as Vector3).distance_to(pes[k]) > PASSO:
				tr.push_front([pes[k], 0.0])
			else:
				tr[0][0] = pes[k]
	_im.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null or cor.a <= 0.0:
		return
	var olho := cam.global_position
	var aberto := false
	for k in 2:
		var tr: Array = _trilhas[k]
		pontos += tr.size()
		if tr.size() < 2:
			continue
		if not aberto:
			_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			aberto = true
		for i in tr.size() - 1:
			var a: Vector3 = tr[i][0]
			var b: Vector3 = tr[i + 1][0]
			var fa := 1.0 - float(tr[i][1]) / VIDA
			var fb := 1.0 - float(tr[i + 1][1]) / VIDA
			var ao_longo := (b - a)
			if ao_longo.length() < 0.001:
				continue
			var lado_a := ao_longo.cross(olho - a).normalized() * LARGURA * (0.35 + 0.65 * fa)
			var lado_b := ao_longo.cross(olho - b).normalized() * LARGURA * (0.35 + 0.65 * fb)
			var na := smoothstep(PERTO_SOME, PERTO_INTEIRA, olho.distance_to(a))
			var nb := smoothstep(PERTO_SOME, PERTO_INTEIRA, olho.distance_to(b))
			var ca := Color(cor.r, cor.g, cor.b, 0.85 * pow(fa, 1.4) * na)
			var cb := Color(cor.r, cor.g, cor.b, 0.85 * pow(fb, 1.4) * nb)
			for v: Array in [[a + lado_a, ca], [a - lado_a, ca], [b + lado_b, cb], [a - lado_a, ca], [b - lado_b, cb], [b + lado_b, cb]]:
				_im.surface_set_color(v[1])
				_im.surface_add_vertex(v[0])
	if aberto:
		_im.surface_end()
