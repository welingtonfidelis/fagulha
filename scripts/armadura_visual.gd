class_name ArmaduraVisual
extends Node3D
## O modelo da armadura v1 (exportado do Blender por tools/maquete/armadura.py) animado por código:
## cada junta gira para a pose do estado (parado, andando, correndo, no ar, decolando, voando, planando).
## O modelo olha para +Z; o nó dele gira 180° para olhar para -Z, a frente na Godot.
## Ângulos das juntas no referencial do modelo: X positivo leva a perna, o braço e o tronco para trás
## (o tronco e a raiz inclinam para a frente); Z positivo abre o lado esquerdo (+X) para fora.

## O modelo e o estilo são escolhidos pelo mapa antes de criar a armadura.
static var MODELO := "res://assets/armadura/robo_teste_v1.glb"  # modelo do usuário (Tripo + Mixamo); v1 e v2 são registro
static var noite := 0.0  # 0 a 1: de noite as luzes do robô acendem mais
static var modelo_do_mapa := ""  # o robô normal do mapa (a pausa troca pelo Faísca e volta)
const FAISCA := "res://assets/faisca/faisca.scn"  # teste: o Faísca da Ilha Cafuné, montado lá e gravado como cena
static var toon := false  # estilo do vale: peças com luz em faixas
const JUNTAS := ["raiz", "tronco", "cabeca", "costas"]
const LADOS := ["ombro", "cotovelo", "punho", "quadril", "joelho", "tornozelo", "pod", "aleta"]

var modelo: Node3D
var j := {}  # nome -> Node3D
var chamas: Array[Node3D] = []
var chamas_pequenas: Array[Node3D] = []
var mat_calor := StandardMaterial3D.new()
var mat_chama := StandardMaterial3D.new()
var mat_chama_fraca: StandardMaterial3D
var mat_chama_tiro: StandardMaterial3D
var chama_tiro: Node3D
var abertura_aletas := 0.0
var _fase := 0.0
var _torcao := 0.0  # giro do tronco em relação às pernas (mirar andando de lado)
var _re := false  # andando de costas: a passada roda ao contrário
var _passada := 0.0  # 0 parado, 1 andando (as juntas seguem mais rápido andando)
var _acel := 0.0  # aceleração de lado, suavizada (inclina o tronco ao arrancar e ao frear)
var _hv_ant := 0.0
var _raiz_y := 0.0
var _alvos := {}
var _chama_tamanho := 0.0
var _yaw := 0.0
var _abaixa := 0.0  # 0 de pé, 1 abaixado (suavizado)
var _senta := 0.0  # 0 de pé, 1 sentado (suavizado)
var _levanta := 0.0  # sentado: quanto a bacia sobe para nenhuma peça entrar no chão
var _malhas: Array[MeshInstance3D] = []
var _mat_rosto: ShaderMaterial
var _pisca := 3.0
const ABAIXA_DESCE := 0.42  # quanto a bacia desce abaixado, em alturas de armadura de 1 m de porte
const SENTA_DESCE := 1.1


func _ready() -> void:
	var cena: PackedScene = load(MODELO)
	modelo = cena.instantiate()
	modelo.rotation.y = PI
	add_child(modelo)
	mat_calor.albedo_color = Color(0.05, 0.03, 0.02)
	mat_calor.emission_enabled = true
	mat_calor.emission = Color(1.0, 0.42, 0.1)
	mat_calor.emission_energy_multiplier = 1.0
	mat_chama.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_chama.albedo_color = Color(1.0, 0.62, 0.3, 0.8)
	mat_chama.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_chama.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_chama.cull_mode = BaseMaterial3D.CULL_DISABLED
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	if not esqueletos.is_empty():
		_preparar_esqueleto(esqueletos[0] as Skeleton3D)
		return
	for nome in JUNTAS:
		j[nome] = modelo.find_child(nome, true, false)
	for lado in ["E", "D"]:
		for nome in LADOS:
			j[nome + lado] = modelo.find_child(nome + lado, true, false)
		for i in 3:
			j["aleta%s%d" % [lado, i]] = modelo.find_child("aleta%s%d" % [lado, i], true, false)
	for k in j:
		if j[k] == null:
			push_warning("junta não achada: " + k)
	_raiz_y = (j["raiz"] as Node3D).position.y
	_trocar_materiais(modelo)


## Modelo com esqueleto (padrão Mixamo, pose em T): as mesmas poses do jogo vão para os ossos.
## Cada junta do jogo vira um osso; a rotação da pose é dada no referencial do modelo e acumulada
## de pai para filho, depois convertida para a pose local do osso.
## O terceiro nome é o do esqueleto Rig_Medium do KayKit (o do Faísca).
const OSSOS := {
	"raiz": ["Hips", "", "hips"], "tronco": ["Spine", "raiz", "spine"], "cabeca": ["Head", "tronco", "head"],
	"ombroE": ["LeftArm", "tronco", "upperarm.l"], "cotoveloE": ["LeftForeArm", "ombroE", "lowerarm.l"], "punhoE": ["LeftHand", "cotoveloE", "wrist.l"],
	"ombroD": ["RightArm", "tronco", "upperarm.r"], "cotoveloD": ["RightForeArm", "ombroD", "lowerarm.r"], "punhoD": ["RightHand", "cotoveloD", "wrist.r"],
	"quadrilE": ["LeftUpLeg", "raiz", "upperleg.l"], "joelhoE": ["LeftLeg", "quadrilE", "lowerleg.l"], "tornozeloE": ["LeftFoot", "joelhoE", "foot.l"],
	"quadrilD": ["RightUpLeg", "raiz", "upperleg.r"], "joelhoD": ["RightLeg", "quadrilD", "lowerleg.r"], "tornozeloD": ["RightFoot", "joelhoD", "foot.r"],
}
const ORDEM_OSSOS := ["raiz", "tronco", "cabeca", "ombroE", "cotoveloE", "punhoE", "ombroD", "cotoveloD", "punhoD",
	"quadrilE", "joelhoE", "tornozeloE", "quadrilD", "joelhoD", "tornozeloD"]
const ALTURA_ALVO := 2.6

var esqueleto: Skeleton3D
var _osso := {}  # junta -> índice do osso
var _rot := {}  # junta -> rotação suavizada (euler, referencial do modelo)
var _base_esq := Basis.IDENTITY  # base do esqueleto dentro do modelo
var _hips_rest := Vector3.ZERO


func _preparar_esqueleto(sk: Skeleton3D) -> void:
	esqueleto = sk
	# tira objetos soltos que vieram no arquivo (uma esfera de teste)
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skeleton.is_empty() and not sk.is_ancestor_of(n):
			n.queue_free()
	for k in OSSOS:
		var nome: String = OSSOS[k][0]
		var idx := -1
		for prefixo in ["mixamorig:", "mixamorig_", ""]:
			idx = sk.find_bone(prefixo + nome)
			if idx >= 0:
				break
		if idx < 0:
			idx = sk.find_bone(OSSOS[k][2])
		if idx < 0:
			idx = sk.find_bone(String(OSSOS[k][2]).replace(".", "_"))
		if idx < 0:
			push_warning("osso não achado: " + nome)
		_osso[k] = idx
		_rot[k] = Vector3.ZERO
		j[k] = null
	# escala para 2,6 m, com os pés no chão
	var topo := 0.0
	var chao := INF
	for b in sk.get_bone_count():
		var y := (sk.global_transform * sk.get_bone_global_rest(b).origin).y - global_position.y
		topo = maxf(topo, y)
		chao = minf(chao, y)
	# o Faísca tem um capacete grande acima do osso da cabeça: a altura vem das peças, não dos ossos
	var rosto := modelo.find_child("rosto", true, false) as MeshInstance3D
	if rosto:
		for n in modelo.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or String(mi.name).begins_with("jato"):
				continue
			var cx := mi.mesh.get_aabb()
			for i in 8:
				var y := (mi.global_transform * cx.get_endpoint(i)).y - global_position.y
				topo = maxf(topo, y)
				chao = minf(chao, y)
		_preparar_faisca(rosto)
	var esc := ALTURA_ALVO * Armadura.porte / maxf(0.01, (topo - chao) * (1.0 if rosto else 1.04))
	modelo.scale = Vector3.ONE * esc
	modelo.position.y = -chao * esc
	_base_esq = (modelo.global_basis.orthonormalized().inverse() * sk.global_basis.orthonormalized())
	_hips_rest = sk.get_bone_rest(_osso["raiz"]).origin
	if not chamas.is_empty():
		return
	# chamas simples nas costas (o modelo não tem bocais próprios)
	var preso := BoneAttachment3D.new()
	sk.add_child(preso)
	var espinha := sk.find_bone("mixamorig:Spine2")
	if espinha < 0:
		espinha = sk.find_bone("mixamorig_Spine2")
	preso.bone_idx = maxi(espinha, 0)
	for lado in [-1.0, 1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.035
		cone.bottom_radius = 0.0
		cone.height = 0.26
		cone.radial_segments = 10
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = mat_chama
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(lado * 0.06, -0.12, -0.11)
		preso.add_child(mi)
		chamas.append(mi)


## O Faísca: a tela do rosto ganha de volta o shader dos olhos de LED (o .glb não leva shader) e os jatos
## dele viram as chamas do voo. As cores e as peças ficam como vieram da Ilha Cafuné.
func _preparar_faisca(rosto: MeshInstance3D) -> void:
	_mat_rosto = ShaderMaterial.new()
	_mat_rosto.shader = load("res://scripts/shaders/faisca_rosto.gdshader")
	rosto.material_override = _mat_rosto
	for n in modelo.find_children("jato*", "MeshInstance3D", true, false):
		chamas.append(n)


func _aplicar_ossos(bob: float, t: float) -> void:
	var acum := {}
	for k in ORDEM_OSSOS:
		var alvo: Vector3 = _alvos.get(k, Vector3.ZERO)
		_rot[k] = (_rot[k] as Vector3).lerp(alvo, t)
		var d := Basis.from_euler(_rot[k])
		# o descanso do modelo é em T: os braços descem 78° antes da pose
		if k == "ombroE":
			d = d * Basis(Vector3(0, 0, 1), deg_to_rad(-78.0))
		elif k == "ombroD":
			d = d * Basis(Vector3(0, 0, 1), deg_to_rad(78.0))
		var pai: String = OSSOS[k][1]
		var a_pai: Basis = acum[pai] if pai != "" else Basis.IDENTITY
		acum[k] = a_pai * d
	for k in ORDEM_OSSOS:
		var idx: int = _osso[k]
		if idx < 0:
			continue
		# acumulado no referencial do esqueleto
		var a: Basis = _base_esq.inverse() * (acum[k] as Basis) * _base_esq
		var pai_idx := esqueleto.get_bone_parent(idx)
		var g_rest := esqueleto.get_bone_global_rest(idx).basis.orthonormalized()
		var pai_novo := Basis.IDENTITY
		if pai_idx >= 0:
			var junta_pai: String = OSSOS[k][1]
			var a_pai: Basis = Basis.IDENTITY
			if junta_pai != "":
				a_pai = _base_esq.inverse() * (acum[junta_pai] as Basis) * _base_esq
			pai_novo = a_pai * esqueleto.get_bone_global_rest(pai_idx).basis.orthonormalized()
		esqueleto.set_bone_pose_rotation(idx, (pai_novo.inverse() * a * g_rest).get_rotation_quaternion())
	var raiz_idx: int = _osso["raiz"]
	if raiz_idx >= 0:
		esqueleto.set_bone_pose_position(raiz_idx, _hips_rest + Vector3(0, bob / modelo.scale.y, 0))


func _trocar_materiais(no: Node) -> void:
	if no is MeshInstance3D:
		var mi := no as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m == null:
				continue
			# estilo pintado: placas foscas com borda acesa (metal espelhado ficava preto sem reflexo)
			if toon and m is StandardMaterial3D and m.resource_name in ["placa_escura", "placa_clara", "detalhe", "bocal", "traje"]:
				var mt := ShaderMaterial.new()
				mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
				mt.set_shader_parameter("cor", (m as StandardMaterial3D).albedo_color)
				mt.set_shader_parameter("brilho_borda", 0.18)
				mi.set_surface_override_material(s, mt)
				continue
			if m is StandardMaterial3D and m.resource_name in ["placa_escura", "placa_clara", "detalhe", "bocal", "traje"]:
				var sm := m as StandardMaterial3D
				sm.metallic = 0.15
				sm.roughness = 0.62
				sm.rim_enabled = true
				sm.rim = 0.35
				sm.rim_tint = 0.4
			if m.resource_name == "calor":
				mi.set_surface_override_material(s, mat_calor)
			elif m.resource_name == "chama":
				mi.set_surface_override_material(s, mat_chama)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if mi.name.begins_with("chama_panturrilha"):
					# jatos das mãos: mais fracos que os dos pés, a não ser no tiro
					if mat_chama_fraca == null:
						mat_chama_fraca = mat_chama.duplicate()
					mi.set_surface_override_material(s, mat_chama_fraca)
					chamas_pequenas.append(mi)
					# a da mão direita tem material próprio: é ela que acende no tiro
					var pai := mi.get_parent()
					while pai != null and pai != self and not String(pai.name).begins_with("punho"):
						pai = pai.get_parent()
					if pai != null and String(pai.name) == "punhoD":
						mat_chama_tiro = mat_chama.duplicate()
						mi.set_surface_override_material(s, mat_chama_tiro)
						chama_tiro = mi
				else:
					chamas.append(mi)
	for f in no.get_children():
		_trocar_materiais(f)


## Pulso macio de 0 a 1, com o pico em x = 0 e período de uma volta; `fino` maior = pulso mais estreito.
func _pulso(x: float, fino: float) -> float:
	return pow(0.5 + 0.5 * cos(x), fino)


func _alvo(nome: String, x: float, y := 0.0, z := 0.0) -> void:
	_alvos[nome] = Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z))


func _soma(nome: String, x: float) -> void:
	if _alvos.has(nome):
		_alvos[nome] += Vector3(deg_to_rad(x), 0.0, 0.0)


func _soma_lados(nome: String, x: float, z_esq: float) -> void:
	_alvos[nome + "E"] += Vector3(deg_to_rad(x), 0.0, deg_to_rad(z_esq))
	_alvos[nome + "D"] += Vector3(deg_to_rad(x), 0.0, deg_to_rad(-z_esq))


func _lados(nome: String, x: float, z_esq: float) -> void:
	# z_esq é o ângulo do lado esquerdo; o direito espelha
	_alvo(nome + "E", x, 0.0, z_esq)
	_alvo(nome + "D", x, 0.0, -z_esq)


func atualizar(delta: float, a: Armadura) -> void:
	if modelo == null:
		return
	_alvos.clear()
	for k in j:
		_alvos[k] = Vector3.ZERO
	var hv := Vector2(a.velocity.x, a.velocity.z).length()
	# o corpo inteiro: no chão olha para onde anda; no voo segue o nariz, sobe, desce e inclina na curva
	var yaw_alvo := _yaw
	var pitch_alvo := 0.0
	var roll_alvo := 0.0
	var torcao_alvo := 0.0
	_re = false
	if (a.estado == Armadura.Estado.PAIRAR or a.mirando_agora() or (a.atirando > 0.0 and not a.em_voo())) and a.camera:
		yaw_alvo = a.camera.yaw
		if a.estado == Armadura.Estado.CHAO and hv > 0.5:
			# andando e mirando: as pernas viram para onde ele anda e o tronco torce para a mira;
			# indo para trás, recua de costas (a passada roda ao contrário) em vez de girar o corpo
			var dif := wrapf(atan2(-a.velocity.x, -a.velocity.z) - a.camera.yaw, -PI, PI)
			if absf(dif) > deg_to_rad(105.0):
				_re = true
				dif = wrapf(dif - PI, -PI, PI)
			dif = clampf(dif, deg_to_rad(-65.0), deg_to_rad(65.0))
			yaw_alvo = a.camera.yaw + dif
			torcao_alvo = -dif
	elif a.em_voo():
		yaw_alvo = atan2(-a.dir_voo.x, -a.dir_voo.z)
		if a.estado != Armadura.Estado.DECOLAGEM:
			pitch_alvo = asin(clampf(a.dir_voo.y, -1.0, 1.0))
			roll_alvo = clampf(a.giro_lateral * 0.35 - a.inclinar * 0.45, -1.0, 1.0)
	elif a.estado == Armadura.Estado.FREAR:
		yaw_alvo = atan2(-a.dir_voo.x, -a.dir_voo.z)  # freando: de pé no ar, de frente para onde ia
	elif hv > 0.5:
		yaw_alvo = atan2(-a.velocity.x, -a.velocity.z)
	_torcao = lerp_angle(_torcao, torcao_alvo, 1.0 - exp(-10.0 * delta))
	var no_chao := a.estado == Armadura.Estado.CHAO
	if delta > 0.0:
		_acel = lerpf(_acel, (hv - _hv_ant) / delta if no_chao else 0.0, 1.0 - exp(-8.0 * delta))
	_hv_ant = hv
	if no_chao and not a.mirando_agora():
		# no chão o corpo inclina para dentro da curva, mais quanto mais rápido
		roll_alvo = clampf(wrapf(yaw_alvo - _yaw, -PI, PI) * 0.5, -0.22, 0.22) * clampf(hv / (Ajustes.CORRER * Armadura.vel_chao), 0.0, 1.0)
	else:
		_passada = 0.0
	var tc := 1.0 - exp(-10.0 * delta)
	_yaw = lerp_angle(_yaw, yaw_alvo, tc)
	rotation = Vector3(lerpf(rotation.x, pitch_alvo, tc), _yaw, lerpf(rotation.z, roll_alvo, tc))
	var aletas := 0.0
	var bob := 0.0
	var chama := 0.0
	match a.estado:
		Armadura.Estado.CHAO, Armadura.Estado.POUSO:
			if a.estado == Armadura.Estado.POUSO and a.pouso_forca > 0.9:
				# pouso de herói: um joelho no chão, o punho direito apoiado, o braço esquerdo para trás
				_alvo("quadrilE", -95.0, 0.0, 8.0)
				_alvo("joelhoE", 100.0)
				_alvo("quadrilD", -20.0, 0.0, -6.0)
				_alvo("joelhoD", 115.0)
				_alvo("tornozeloD", 40.0)
				_alvo("tronco", 34.0)
				_alvo("cabeca", -26.0)
				_alvo("ombroD", -52.0, 0.0, -8.0)
				_alvo("cotoveloD", -12.0)
				_alvo("ombroE", 58.0, 0.0, 34.0)
				_alvo("cotoveloE", -20.0)
				bob = -0.62 * Armadura.porte
			elif a.estado == Armadura.Estado.POUSO:
				# agachada conforme a força: só um toque (0,25) ou a queda média (0,5)
				var f := 0.5 if a.pouso_forca < 0.4 else 1.0
				_lados("quadril", -45.0 * f, 4.0)
				_lados("joelho", 70.0 * f, 0.0)
				_lados("tornozelo", -25.0 * f, 0.0)
				_alvo("tronco", 22.0 * f)
				_lados("ombro", -10.0, 25.0 * f + 8.0)
				_lados("cotovelo", -35.0 * f, 0.0)
				bob = -0.35 * f * Armadura.porte
			else:
				# passada de corpo inteiro. Em cada perna: vai para a frente (quadril negativo) dobrando o
				# joelho, estica para pisar, cede um pouco com o peso e empurra com o pé. A bacia gira com
				# as pernas, o tronco e os braços giram ao contrário, e a cabeça fica firme.
				var hvn := hv / Armadura.vel_chao
				var corrida := smoothstep(0.0, 1.0, clampf((hvn - Ajustes.ANDAR) / (Ajustes.CORRER - Ajustes.ANDAR), 0.0, 1.0))
				var w := smoothstep(0.15, 1.1, hvn)  # 0 parado, 1 andando: mistura sem estalo
				var ciclo := Armadura.porte * lerpf(2.0, 4.0, corrida)
				_fase = fposmod(_fase + delta * hv * TAU / ciclo * (-1.0 if _re else 1.0), TAU)
				_passada = w
				var amp := lerpf(25.0, 40.0, corrida) * w
				var frente := lerpf(6.0, 12.0, corrida) * w
				var k_base := lerpf(5.0, 14.0, corrida) * w
				var k_ida := lerpf(46.0, 88.0, corrida) * w
				var k_peso := lerpf(9.0, 16.0, corrida) * w
				var pe_emp := lerpf(20.0, 34.0, corrida) * w
				var pe_calc := lerpf(12.0, 8.0, corrida) * w
				for par: Array in [["E", _fase], ["D", _fase + PI]]:
					var lado: String = par[0]
					var f: float = par[1]
					_alvo("quadril" + lado, -amp * sin(f) - frente, 0.0, 2.0 if lado == "E" else -2.0)
					_alvo("joelho" + lado, k_base + k_ida * _pulso(f + 0.35, 2.0) + k_peso * _pulso(f - 2.3, 6.0))
					_alvo("tornozelo" + lado, pe_emp * _pulso(f - 4.4, 4.0) - pe_calc * _pulso(f - 1.2, 4.0))
				var sf := sin(_fase)
				var braco := lerpf(15.0, 36.0, corrida) * w
				var cot0 := lerpf(12.0, 58.0, corrida * w)
				var cot1 := lerpf(10.0, 22.0, corrida) * w
				_alvo("ombroE", braco * sf, 0.0, 6.0)
				_alvo("ombroD", -braco * sf, 0.0, -6.0)
				_alvo("cotoveloE", -(cot0 + cot1 * (0.5 - 0.5 * sf)))
				_alvo("cotoveloD", -(cot0 + cot1 * (0.5 + 0.5 * sf)))
				var giro := lerpf(5.0, 9.0, corrida) * w
				var inclina := lerpf(3.0, 13.0, corrida) * w + clampf(_acel * 0.7, -9.0, 10.0)
				_alvo("raiz", 0.0, -giro * sf)
				_alvo("tronco", inclina, giro * 1.7 * sf)
				_alvo("cabeca", -inclina * 0.7, -giro * 0.7 * sf)
				# andando o corpo sobe no meio do apoio; correndo sobe no ar, entre um pé e outro
				bob = cos(2.0 * _fase) * lerpf(0.03, -0.07, corrida) * w * Armadura.porte
				if w < 0.99:
					# parado: respira de leve
					var resp := sin(Time.get_ticks_msec() * 0.0015) * (1.0 - w)
					_alvos["tronco"] += Vector3(deg_to_rad(resp * 1.2), 0, 0)
					_alvos["cotoveloE"] += Vector3(deg_to_rad(-12.0 * (1.0 - w)), 0, 0)
					_alvos["cotoveloD"] += Vector3(deg_to_rad(-12.0 * (1.0 - w)), 0, 0)
		Armadura.Estado.AR:
			_lados("quadril", -18.0, 6.0)
			_lados("joelho", 32.0, 0.0)
			_lados("ombro", 10.0, 32.0)
			_lados("cotovelo", -30.0, 0.0)
			if a.mergulhando:
				# mergulho com impacto: pernas recolhidas, punho direito armado para baixo
				_alvo("raiz", 20.0)
				_lados("quadril", -70.0, 6.0)
				_lados("joelho", 110.0, 0.0)
				_alvo("ombroD", -150.0, 0.0, -8.0)
				_alvo("cotoveloD", -70.0)
				_alvo("ombroE", 40.0, 0.0, 30.0)
			aletas = 0.0
		Armadura.Estado.DECOLAGEM:
			if a._tempo_estado < 0.12:
				_lados("quadril", -40.0, 4.0)
				_lados("joelho", 60.0, 0.0)
				_alvo("tronco", 20.0)
			else:
				_lados("quadril", 4.0, 3.0)
				_lados("joelho", 10.0, 0.0)
				_lados("ombro", 25.0, 12.0)
				_lados("cotovelo", -15.0, 0.0)
			chama = 1.2
		Armadura.Estado.VOO:
			_alvo("raiz", 72.0)
			_alvo("cabeca", -55.0)
			if a.arrancada:
				_lados("ombro", 34.0, 8.0)
				_lados("cotovelo", -4.0, 0.0)
				_lados("quadril", 4.0, 1.0)
			elif toon:
				# as mãos guiam: braços abertos como lemes, e na curva o de dentro fecha e o de fora abre
				var curva := clampf(a.giro_lateral * 0.6, -1.0, 1.0)
				_alvo("ombroE", 20.0, 0.0, 30.0 + curva * 22.0)
				_alvo("ombroD", 20.0, 0.0, -30.0 + curva * 22.0)
				_lados("cotovelo", -16.0, 0.0)
				_lados("punho", -18.0, 0.0)
				_lados("quadril", 6.0, 3.0)
			else:
				_lados("ombro", 18.0, 14.0)
				_lados("cotovelo", -10.0, 0.0)
				_lados("quadril", 6.0, 3.0)
			_lados("joelho", 18.0, 0.0)
			_lados("tornozelo", 40.0, 0.0)
			chama = 1.6 if a.arrancada else 1.0
		Armadura.Estado.PAIRAR:
			var balanco := sin(Time.get_ticks_msec() * 0.003) * 3.0
			_lados("quadril", 10.0 + balanco, 5.0)
			_lados("joelho", 30.0, 0.0)
			_lados("tornozelo", 28.0, 0.0)
			_lados("ombro", 6.0, 18.0)
			_lados("cotovelo", -22.0, 0.0)
			_alvo("tronco", 4.0)
			chama = 0.6
		Armadura.Estado.FREAR:
			# corpo jogado para trás, pernas e braços esticados à frente: os jatos dos pés e das mãos freiam
			_alvo("raiz", -26.0)
			_alvo("tronco", 8.0)
			_alvo("cabeca", 14.0)
			_lados("quadril", -62.0, 7.0)
			_lados("joelho", 14.0, 0.0)
			_lados("tornozelo", -18.0, 0.0)
			_lados("ombro", -78.0, 12.0)
			_lados("cotovelo", -8.0, 0.0)
			_lados("punho", -8.0, 0.0)
			chama = 1.8
		Armadura.Estado.PLANAR:
			_alvo("raiz", 64.0)
			_alvo("cabeca", -48.0)
			_lados("ombro", 8.0, 42.0)
			_lados("cotovelo", -8.0, 0.0)
			_lados("quadril", 4.0, 9.0)
			_lados("joelho", 10.0, 0.0)
			_lados("tornozelo", 35.0, 0.0)
			aletas = 1.0
	# abaixado ou sentado (só no chão): soma à pose de pé ou de passada
	_abaixa = lerpf(_abaixa, 1.0 if a.postura == 1 else 0.0, 1.0 - exp(-9.0 * delta))
	_senta = lerpf(_senta, 1.0 if a.postura == 2 else 0.0, 1.0 - exp(-6.0 * delta))
	if a.estado == Armadura.Estado.CHAO and not a.em_pane:
		if _abaixa > 0.01:
			_soma_lados("quadril", -58.0 * _abaixa, 3.0 * _abaixa)
			_soma_lados("joelho", 96.0 * _abaixa, 0.0)
			_soma_lados("tornozelo", -38.0 * _abaixa, 0.0)
			_soma("tronco", 26.0 * _abaixa)
			_soma("cabeca", -20.0 * _abaixa)
			_soma_lados("ombro", -14.0 * _abaixa, 6.0 * _abaixa)
			_soma_lados("cotovelo", -30.0 * _abaixa * (1.0 - _passada), 0.0)
			bob -= ABAIXA_DESCE * _abaixa * Armadura.porte
		if _senta > 0.01:
			# sentado no chão, pernas esticadas à frente, mãos nas coxas, olhando a paisagem
			var s := smoothstep(0.0, 1.0, _senta)
			var olha := sin(Time.get_ticks_msec() * 0.0004) * 14.0
			_lados("quadril", -98.0 * s, 13.0 * s)
			_lados("joelho", 16.0 * s, 0.0)
			_lados("tornozelo", 6.0 * s, 0.0)
			_alvo("raiz", -8.0 * s)
			_alvo("tronco", 10.0 * s, 0.0, 0.0)
			_alvo("cabeca", -4.0 * s, olha * s)
			_lados("ombro", -34.0 * s, 9.0 * s)
			_lados("cotovelo", -42.0 * s, 0.0)
			bob = (-SENTA_DESCE * s + _levanta) * Armadura.porte
	if _senta <= 0.01:
		_levanta = 0.0
	# mirando: o braço direito aponta para onde a câmera olha (sem arma ainda)
	if (a.mirando_agora() or (a.atirando > 0.0 and not a.em_voo() and not a.em_pane)) and a.camera:
		var p := rad_to_deg(a.camera.pitch)
		_alvo("ombroD", -88.0 - p, 0.0, -4.0)
		_alvo("cotoveloD", -4.0)
		_alvo("cabeca", -p * 0.5)
	# chegando ao chão: corpo em pé, pernas armadas para baixo e braços abertos para equilibrar
	if a.chegando_ao_chao() and not a.em_pane:
		_alvo("raiz", 8.0)
		_alvo("cabeca", 6.0)
		_alvo("tronco", 6.0)
		_lados("quadril", -28.0, 5.0)
		_lados("joelho", 38.0, 0.0)
		_lados("tornozelo", -12.0, 0.0)
		_lados("ombro", 4.0, 38.0)
		_lados("cotovelo", -18.0, 0.0)
		chama = maxf(chama, 1.3 if a.motor_ligado() else 0.0)
	# em pane: desligado, ajoelhado, cabeça e braços caídos
	if a.em_pane:
		_lados("quadril", -60.0, 5.0)
		_lados("joelho", 118.0, 0.0)
		_lados("tornozelo", 30.0, 0.0)
		_alvo("tronco", 38.0)
		_alvo("cabeca", 34.0)
		_lados("ombro", 14.0, 6.0)
		_lados("cotovelo", -6.0, 0.0)
		bob = -0.5 * Armadura.porte
		chama = 0.0
	if absf(_torcao) > 0.001 and _alvos.has("tronco"):
		_alvos["tronco"] += Vector3(0.0, _torcao, 0.0)
	chama = maxf(chama, a.impulso * 1.3)
	if a.esquivando > 0.0:
		_alvo("tronco", 12.0)
	# propulsores das costas inclinados (bocal para baixo e para trás), como na maquete
	_alvo("podE", 14.0, 0.0, -10.0)
	_alvo("podD", 14.0, 0.0, 10.0)
	# juntas vão até o alvo
	# andando as juntas seguem de perto (senão a suavização come a passada); nas outras poses, mais macio
	var t := 1.0 - exp(-lerpf(12.0, 34.0, _passada) * delta)
	abertura_aletas = move_toward(abertura_aletas, aletas, delta * 3.0)
	if esqueleto:
		_aplicar_ossos(bob, t)
	else:
		for k in j:
			var no: Node3D = j[k]
			if no == null or k.begins_with("aleta"):
				continue
			var alvo: Vector3 = _alvos.get(k, Vector3.ZERO)
			no.rotation = no.rotation.lerp(alvo, t)
		(j["raiz"] as Node3D).position.y = lerpf((j["raiz"] as Node3D).position.y, _raiz_y + bob, t)
		# aletas abrem como asas ao planar
		var ab := smoothstep(0.0, 1.0, abertura_aletas)
		for lado in ["E", "D"]:
			var s := 1.0 if lado == "E" else -1.0
			(j["aleta" + lado] as Node3D).rotation = Vector3(0, 0, deg_to_rad(78.0 * s * ab))
			for i in 3:
				(j["aleta%s%d" % [lado, i]] as Node3D).rotation = Vector3(deg_to_rad(i * 10.0 * ab), 0, deg_to_rad(i * 9.0 * s * ab))
	# sentado: mede a peça mais baixa do corpo e sobe a bacia até ela encostar no chão, sem entrar
	if _senta > 0.01 and not esqueleto:
		if _malhas.is_empty():
			for n in modelo.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi.mesh and not (mi in chamas) and not (mi in chamas_pequenas):
					_malhas.append(mi)
		var baixo := INF
		for mi in _malhas:
			var cx := mi.mesh.get_aabb()
			var gt := mi.global_transform
			for i in 8:
				baixo = minf(baixo, (gt * cx.get_endpoint(i)).y)
		var folga := (baixo - a.global_position.y) / Armadura.porte
		_levanta = clampf(_levanta - folga * 0.4, 0.0, 0.6)
	# o Faísca pisca de vez em quando e fecha os olhos na pane
	if _mat_rosto:
		_pisca -= delta
		if _pisca < -0.16:
			_pisca = randf_range(2.0, 5.0)
		_mat_rosto.set_shader_parameter("abertura", 0.05 if a.em_pane else (absf(_pisca + 0.08) / 0.08 if _pisca < 0.0 else 1.0))
		_mat_rosto.set_shader_parameter("forma", 4 if a.superaquecido else 0)
	# chamas e brilho do calor
	_chama_tamanho = lerpf(_chama_tamanho, chama, 1.0 - exp(-10.0 * delta))
	# a origem das peças do modelo fica no chão (não no bocal), então a chama não escala: muda o brilho
	for c in chamas:
		c.visible = _chama_tamanho > 0.08
	for c in chamas_pequenas:
		c.visible = _chama_tamanho > 0.08 or (c == chama_tiro and a.clarao_tiro > 0.05)
	mat_chama.albedo_color.a = clampf(_chama_tamanho * 0.55 + randf_range(-0.08, 0.08), 0.0, 1.0)
	if mat_chama_fraca:
		mat_chama_fraca.albedo_color.a = clampf(mat_chama.albedo_color.a * 0.4 + a.impulso * 0.7, 0.0, 1.0)
	if mat_chama_tiro:
		var base_mao := mat_chama_fraca.albedo_color.a if _chama_tamanho > 0.08 else 0.0
		mat_chama_tiro.albedo_color.a = clampf(maxf(base_mao, a.clarao_tiro), 0.0, 1.0)
	var q := a.calor / 100.0
	var brilho := lerpf(lerpf(0.6, 3.2, noite), 7.0, q * q)
	if a.superaquecido:
		brilho = 8.0 if fmod(Time.get_ticks_msec() * 0.001, 0.3) < 0.15 else 2.0
	if a.em_pane:
		brilho = 0.05
	mat_calor.emission_energy_multiplier = brilho
	mat_calor.emission = Color(1.0, 0.42, 0.1).lerp(Color(1.0, 0.85, 0.65), smoothstep(0.8, 1.0, q))
