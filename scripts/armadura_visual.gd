class_name ArmaduraVisual
extends Node3D
## O modelo da armadura v1 (exportado do Blender por tools/maquete/armadura.py) animado por código:
## cada junta gira para a pose do estado (parado, andando, correndo, no ar, decolando, voando, planando).
## O modelo olha para +Z; o nó dele gira 180° para olhar para -Z, a frente na Godot.
## Ângulos das juntas no referencial do modelo: X positivo leva a perna, o braço e o tronco para trás
## (o tronco e a raiz inclinam para a frente); Z positivo abre o lado esquerdo (+X) para fora.

## O modelo e o estilo são escolhidos pelo mapa antes de criar a armadura.
static var MODELO := "res://assets/vale/robo_v2.glb"  # o robô do jogo; `robo_v1` é o anterior e `robo_v3` o mergulhador
static var noite := 0.0  # 0 a 1: de noite as luzes do robô acendem mais
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
var pecas := {}  # melhorias vestidas: nome -> nós (MelhoriasVisual)
var armas_punho := {}  # lado -> a arma que sai do punho e as partes dela (MelhoriasVisual._arma_punho)
var arma_vitrine := -1.0  # fotos: fixa quanto a arma saiu do punho (0 a mão, 1 a arma); -1 segue o jogo
var asas_f := 0.0  # 0 asas recolhidas, 1 abertas
var escudos_vistos := 0  # quantos acertos o escudo já engoliu (para piscar a bolha uma vez por acerto)
var yaw_forcado := NAN  # a oficina vira o robô para mostrar a peça
var previa := false  # na oficina: asas abertas e luz acesa para ver a peça
var jatos_vitrine := 0.0  # na aba Jatos da oficina: os jatos ficam acesos com o robô parado (doc §147)
var cor_vitrine := ""  # e na cor em foco ("" a de fábrica)
const COR_CHAMA := Color(1.0, 0.62, 0.3)  # o fogo de fábrica
var _fase := 0.0
var _torcao := 0.0  # giro do tronco em relação às pernas (mirar andando de lado)
var _re := false  # andando de costas: a passada roda ao contrário
var _passada := 0.0  # 0 parado, 1 andando (as juntas seguem mais rápido andando)
var _acel := 0.0  # aceleração de lado, suavizada (inclina o tronco ao arrancar e ao frear)
var _rolagem := 0.0  # a inclinação de lado do corpo, sem a volta da manobra
var desvio_giro := Vector3.ZERO  # quanto o corpo anda para a volta sair em torno do meio dele (a Armadura soma)
var _hv_ant := 0.0
var _raiz_y := 0.0
var _alvos := {}
var _chama_tamanho := 0.0
var _bafo: CPUParticles3D  # o sopro branco da mochila no frio da montanha (doc §137.11); nasce na primeira vez
var _yaw := 0.0
var _abaixa := 0.0  # 0 de pé, 1 abaixado (suavizado)
var _senta := 0.0  # 0 de pé, 1 sentado (suavizado)
var _levanta := 0.0  # abaixado ou sentado: quanto a bacia sobe para nenhuma peça entrar no chão
var _malhas: Array[MeshInstance3D] = []
var _pontos: Array[PackedVector3Array] = []
const ABAIXA_DESCE := 0.42  # quanto a bacia desce abaixado, em alturas de armadura de 1 m de porte
const SENTA_DESCE := 1.1
# Para os robôs inimigos (InimigoVisual, 2026-11-20), que são o nosso robô com outra pintura: outro modelo,
# sem melhorias, e quem dirige não é a Armadura e sim um PoseInimigo com os mesmos campos.
var caminho_modelo := ""  # vazio: o MODELO do jogador
var re_forcado := false  # anda de costas (a passada roda ao contrário)
var sobrepor := {}  # junta -> Vector3 em graus: troca a pose calculada daquela junta (poses que o jogador não tem)
var espada_desce := 0.0  # graus que o braço da espada desce abaixo do peito (inimigo alto alcançando o robô)
var cor_lamina := Color(0.3, 0.9, 1.0)
var escala_lamina := 1.0


## O modelo em uso tem o corpo novo (o robô redesenhado ou uma variante dele, como o mergulhador)?
static func corpo_novo() -> bool:
	return MODELO.ends_with("robo_v2.glb") or MODELO.ends_with("robo_v3.glb")


func _ready() -> void:
	preparar()


## Carrega o modelo e acha as juntas (o `_ready` chama; quem precisa do modelo antes de entrar na cena, como
## o InimigoVisual, chama direto). Só faz uma vez.
func preparar() -> void:
	if modelo != null:
		return
	var cena: PackedScene = load(caminho_modelo if caminho_modelo != "" else MODELO)
	modelo = cena.instantiate()
	modelo.rotation.y = PI
	add_child(modelo)
	mat_calor.albedo_color = Color(0.05, 0.03, 0.02)
	mat_calor.emission_enabled = true
	mat_calor.emission = Color(1.0, 0.42, 0.1)
	mat_calor.emission_energy_multiplier = 1.0
	mat_chama.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_chama.albedo_color = Color(COR_CHAMA, 0.8)
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
	# o robô novo tem a junta da luva, que torce em torno do antebraço: as peças do antebraço vão presas nela
	for lado in ["E", "D"]:
		var luva := modelo.find_child("luva" + lado, true, false)
		if luva != null:
			j["luva" + lado] = luva
	_raiz_y = (j["raiz"] as Node3D).position.y
	_trocar_materiais(modelo)
	# o corpo em peças (Corpo): só o robô do jogador, no modelo de hoje (o mergulhador fica como é)
	if caminho_modelo == "" and MODELO.ends_with("robo_v2.glb"):
		_guardar_fabrica()
		vestir_corpo(Corpo.vestido)
	if caminho_modelo == "" and (MODELO.ends_with("robo_v1.glb") or corpo_novo()):
		MelhoriasVisual.preparar(self)
		vestir_melhorias()


## Põe no corpo as melhorias instaladas (o robô do vale; sem nenhuma, fica o básico, de mochila lisa).
func vestir_melhorias(extra: Array = []) -> void:
	if not has_meta("descanso"):
		return
	MelhoriasVisual.limpar(self)
	asas_f = 0.0
	var lista := Melhorias.vestidas()
	if Arsenal.tem("mira") and not Arsenal.tudo:
		lista.append("mira")
	# a arma em uso muda a ponta do braço; os lançadores fabricados ficam nos ombros
	if Arsenal.modo in ["rajada", "canhao", "precisao", "duplo"] and Arsenal.tem_arma(Arsenal.modo):
		lista.append("arma_" + Arsenal.modo)
	if Arsenal.fabricados.has("vida"):
		lista.append("vida")
	if Arsenal.fabricados.has("escudo"):
		lista.append("escudo")
	if Arsenal.fabricados.has("misseis"):
		lista.append("lanca_misseis")
	if Arsenal.fabricados.has("granadas"):
		lista.append("lanca_granadas")
	for nome in extra:
		if not lista.has(nome):
			lista.append(nome)
	# sem outra arma, é a pistola que sai do punho direito
	if not lista.any(func(n): return String(n).begins_with("arma_")):
		lista.append("arma_pistola")
	pecas = MelhoriasVisual.vestir(self, lista)
	if pecas.has("asas"):
		MelhoriasVisual.por_asas(pecas["asas"], 0.0)
	if pecas.has("farol"):
		MelhoriasVisual.por_farol(pecas["farol"], false)


## Modelo com esqueleto (padrão Mixamo, pose em T): as mesmas poses do jogo vão para os ossos.
## Cada junta do jogo vira um osso; a rotação da pose é dada no referencial do modelo e acumulada
## de pai para filho, depois convertida para a pose local do osso.
const OSSOS := {
	"raiz": ["Hips", ""], "tronco": ["Spine", "raiz"], "cabeca": ["Head", "tronco"],
	"ombroE": ["LeftArm", "tronco"], "cotoveloE": ["LeftForeArm", "ombroE"], "punhoE": ["LeftHand", "cotoveloE"],
	"ombroD": ["RightArm", "tronco"], "cotoveloD": ["RightForeArm", "ombroD"], "punhoD": ["RightHand", "cotoveloD"],
	"quadrilE": ["LeftUpLeg", "raiz"], "joelhoE": ["LeftLeg", "quadrilE"], "tornozeloE": ["LeftFoot", "joelhoE"],
	"quadrilD": ["RightUpLeg", "raiz"], "joelhoD": ["RightLeg", "quadrilD"], "tornozeloD": ["RightFoot", "joelhoD"],
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
	var esc := ALTURA_ALVO * Armadura.porte / maxf(0.01, (topo - chao) * 1.04)
	modelo.scale = Vector3.ONE * esc
	modelo.position.y = -chao * esc
	_base_esq = (modelo.global_basis.orthonormalized().inverse() * sk.global_basis.orthonormalized())
	_hips_rest = sk.get_bone_rest(_osso["raiz"]).origin
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


## As cores pintadas do robô: as de fábrica e as dos conjuntos do Corpo, que começam com o nome da família
## (placa_gato, detalhe_samurai, laranja_ouro...).
static func _da_familia(nome: String) -> bool:
	return nome in ["placa_escura", "placa_clara", "detalhe", "bocal", "traje", "laranja", "vidro"] \
		or nome.begins_with("placa_") or nome.begins_with("detalhe_") or nome.begins_with("laranja_")


func _trocar_materiais(no: Node) -> void:
	if no is MeshInstance3D:
		var mi := no as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m == null:
				continue
			# estilo pintado: placas foscas com borda acesa (metal espelhado ficava preto sem reflexo)
			if toon and m is StandardMaterial3D and _da_familia(m.resource_name):
				var mt := ShaderMaterial.new()
				mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
				mt.set_shader_parameter("cor", (m as StandardMaterial3D).albedo_color)
				mt.set_shader_parameter("brilho_borda", 0.18)
				mi.set_surface_override_material(s, mt)
				continue
			if m is StandardMaterial3D and _da_familia(m.resource_name):
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


## Levantar de sentado, em três tempos: encolhe as pernas e apoia as mãos no chão, sobe para a posição
## abaixada com o tronco à frente e então estica o corpo. `p` vai de 0 a 1; devolve a altura da bacia.
## (Antes ele só esticava tudo de uma vez e parecia saltar do chão sem impulso.)
const ERGUER := [
	# quadril x, quadril z, joelho, tornozelo, raiz, tronco, cabeça, ombro x, ombro z, cotovelo, bacia
	[-98.0, 13.0, 16.0, 6.0, -8.0, 10.0, -4.0, -34.0, 9.0, -42.0, -1.1],  # sentado
	[-128.0, 9.0, 138.0, -6.0, 4.0, 34.0, -18.0, 26.0, 14.0, -8.0, -1.04],  # pernas encolhidas, mãos no chão
	[-78.0, 5.0, 112.0, -34.0, 0.0, 40.0, -26.0, 4.0, 10.0, -22.0, -0.52],  # agachado, peso à frente
	[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],  # de pé
]
const ERGUER_TEMPOS := [0.0, 0.34, 0.68, 1.0]


## Os pontos de cada peça que servem para achar a mais baixa do corpo (`_levanta` e `_cadeira_ajuste`): de
## cada uma ficam os pontos mais salientes em 60 direções (a caixa em volta exagerava com a perna dobrada e
## o robô flutuava). `_perna` marca as peças das pernas, que num móvel pendem para fora do assento.
func _medir_malhas() -> void:
	var dirs: Array[Vector3] = []
	for i in 60:
		var yy := 1.0 - 2.0 * (i + 0.5) / 60.0
		var rr := sqrt(1.0 - yy * yy)
		dirs.append(Vector3(cos(i * 2.39996) * rr, yy, sin(i * 2.39996) * rr))
	var quadris: Array = []
	for nome: String in ["quadrilE", "quadrilD"]:
		if j.get(nome) != null:
			quadris.append(j[nome])
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or (mi in chamas) or (mi in chamas_pequenas) or mi.has_meta("guardada"):
			continue
		var faces := mi.mesh.get_faces()
		if faces.is_empty():
			continue
		var pts := PackedVector3Array()
		for d in dirs:
			var melhor := faces[0]
			var md := -INF
			for v in faces:
				var x := v.dot(d)
				if x > md:
					md = x
					melhor = v
			if not pts.has(melhor):
				pts.append(melhor)
		_malhas.append(mi)
		_pontos.append(pts)
		var perna := false
		for q: Node in quadris:
			if q.is_ancestor_of(mi):
				perna = true
		_perna.append(perna)


## Sentar num móvel (sofá, poltrona, banco): coxas na horizontal, canelas pendendo, mãos nos joelhos.
## Sentando, dobra os joelhos com os braços à frente e leva o peso para trás até o assento; levantando,
## joga o tronco à frente, empurra com as pernas e estica o corpo. A última coluna é o peso: 0 de pé, 1 com
## a bacia no assento. Devolve a altura da bacia (em alturas de armadura de 1 m de porte).
const CADEIRA := [
	# quadril x, quadril z, joelho, tornozelo, raiz, tronco, cabeça, ombro x, ombro z, cotovelo, peso
	[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],  # de pé
	[-64.0, 7.0, 82.0, -22.0, 0.0, 30.0, -18.0, -52.0, 8.0, -12.0, 0.4],  # agachando, braços à frente
	[-90.0, 8.0, 86.0, 2.0, 0.0, -4.0, -2.0, -26.0, 10.0, -44.0, 1.0],  # sentado, mãos nos joelhos
	[-104.0, 9.0, 104.0, -12.0, 0.0, 40.0, -22.0, -46.0, 10.0, -18.0, 1.0],  # tronco à frente, pés embaixo
	[-46.0, 5.0, 58.0, -22.0, 0.0, 22.0, -12.0, -20.0, 8.0, -14.0, 0.45],  # meio de pé, empurrando
]
const CADEIRA_DESCE := 0.77  # quanto a bacia desce sentada, antes do acerto medido (`_cadeira_ajuste`)
var _cadeira_ajuste := 0.0
var _perna: Array[bool] = []


func _cadeira(a) -> float:
	var seq: Array
	var tempos: Array
	match a.assento_fase:
		0:
			seq = [CADEIRA[0], CADEIRA[1], CADEIRA[2]]
			tempos = [0.0, 0.5, 1.0]
		2:
			seq = [CADEIRA[2], CADEIRA[3], CADEIRA[4], CADEIRA[0]]
			tempos = [0.0, 0.3, 0.65, 1.0]
		_:
			seq = [CADEIRA[2], CADEIRA[2]]
			tempos = [0.0, 1.0]
	var p: float = a.assento_p if a.assento_fase != 1 else 1.0
	var i := 0
	while i < seq.size() - 2 and p > float(tempos[i + 1]):
		i += 1
	var k := smoothstep(0.0, 1.0, (p - float(tempos[i])) / maxf(0.001, float(tempos[i + 1]) - float(tempos[i])))
	var q: Array = []
	for n in 11:
		q.append(lerpf(seq[i][n], seq[i + 1][n], k))
	_lados("quadril", q[0], q[1])
	_lados("joelho", q[2], 0.0)
	_lados("tornozelo", q[3], 0.0)
	_alvo("raiz", q[4])
	# sentado, olha em volta devagar
	var olha := sin(Time.get_ticks_msec() * 0.0004) * 14.0 if a.assento_fase == 1 else 0.0
	_alvo("tronco", q[5])
	_alvo("cabeca", q[6], olha)
	_lados("ombro", q[7], q[8])
	_lados("cotovelo", q[9], 0.0)
	return float(q[10]) * (-CADEIRA_DESCE + _cadeira_ajuste)


func _erguer(p: float) -> float:
	var i := 0
	while i < 2 and p > ERGUER_TEMPOS[i + 1]:
		i += 1
	var k := smoothstep(0.0, 1.0, (p - ERGUER_TEMPOS[i]) / (ERGUER_TEMPOS[i + 1] - ERGUER_TEMPOS[i]))
	var q: Array = []
	for n in 11:
		q.append(lerpf(ERGUER[i][n], ERGUER[i + 1][n], k))
	_lados("quadril", q[0], q[1])
	_lados("joelho", q[2], 0.0)
	_lados("tornozelo", q[3], 0.0)
	_alvo("raiz", q[4])
	_alvo("tronco", q[5])
	_alvo("cabeca", q[6])
	_lados("ombro", q[7], q[8])
	_lados("cotovelo", q[9], 0.0)
	return float(q[10]) + _levanta


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


## `a` é a Armadura do jogador, ou um PoseInimigo (os inimigos), que tem os mesmos campos.
func atualizar(delta: float, a) -> void:
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
	_re = re_forcado
	if (a.estado == Armadura.Estado.PAIRAR or a.mirando_agora() or (maxf(maxf(a.atirando, a.atirando_e), a.lancando) > 0.0 and not a.em_voo())) and a.camera:
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
	elif a.estado == Armadura.Estado.NADO:
		if a.velocity.length() > 1.5:
			yaw_alvo = atan2(-a.dir_voo.x, -a.dir_voo.z)
			pitch_alvo = asin(clampf(a.dir_voo.y, -1.0, 1.0))
			roll_alvo = clampf(a.giro_lateral * 0.25, -0.6, 0.6)
		elif a.camera:
			yaw_alvo = a.camera.yaw
	elif a.estado == Armadura.Estado.FREAR:
		yaw_alvo = atan2(-a.dir_voo.x, -a.dir_voo.z)  # freando: de pé no ar, de frente para onde ia
	elif hv > 0.5:
		yaw_alvo = atan2(-a.velocity.x, -a.velocity.z)
	_torcao = lerp_angle(_torcao, torcao_alvo, 1.0 - exp(-10.0 * delta))
	var no_chao: bool = a.estado == Armadura.Estado.CHAO
	if delta > 0.0:
		_acel = lerpf(_acel, (hv - _hv_ant) / delta if no_chao else 0.0, 1.0 - exp(-8.0 * delta))
	_hv_ant = hv
	if no_chao and not a.mirando_agora():
		# no chão o corpo inclina para dentro da curva, mais quanto mais rápido
		roll_alvo = clampf(wrapf(yaw_alvo - _yaw, -PI, PI) * 0.5, -0.22, 0.22) * clampf(hv / Armadura.correr(), 0.0, 1.0)
	else:
		_passada = 0.0
	var tc := 1.0 - exp(-10.0 * delta)
	if not is_nan(yaw_forcado):
		yaw_alvo = yaw_forcado
	if a.no_assento:
		yaw_alvo = a.assento_yaw  # sentado num móvel: de frente para onde o móvel olha
	_yaw = lerp_angle(_yaw, yaw_alvo, tc)
	_rolagem = lerpf(_rolagem, roll_alvo, tc)
	# a manobra do círculo no voo: uma volta inteira em torno do nariz, para o lado pedido
	var volta := 0.0
	if a.manobra > 0.0 and a.manobra_lado != 0.0:
		var k_m: float = 1.0 - a.manobra / Armadura.MANOBRA_TEMPO
		volta = -a.manobra_lado * TAU * (k_m * k_m * (3.0 - 2.0 * k_m))
	rotation = Vector3(lerpf(rotation.x, pitch_alvo, tc), _yaw, _rolagem + volta)
	# a volta é em torno do meio do corpo, não dos pés: sem isto o robô varria um arco largo em vez de girar no
	# próprio eixo (o usuário achou o giro ruim, 2026-11-18)
	var meio_corpo := Vector3(0, a.altura_corpo() * 0.5, 0)
	desvio_giro = Basis.from_euler(Vector3(rotation.x, _yaw, _rolagem)) * meio_corpo - Basis.from_euler(rotation) * meio_corpo if volta != 0.0 else Vector3.ZERO
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
		Armadura.Estado.NADO:
			# nadando: deitado como no voo, braços ao longo do corpo e pernas batendo; parado, boia de pé
			var nv := smoothstep(1.0, 4.0, a.velocity.length())
			var bate := sin(Time.get_ticks_msec() * (0.012 if a.nado_rapido else 0.007)) * (5.0 if a.nado_rapido else 16.0)
			var boia := sin(Time.get_ticks_msec() * 0.002) * 6.0
			_alvo("raiz", 74.0 * nv)
			_alvo("cabeca", -52.0 * nv)
			_lados("ombro", lerpf(-8.0 + boia, 28.0, nv), lerpf(34.0, 9.0, nv))
			_lados("cotovelo", lerpf(-40.0, -6.0, nv), 0.0)
			_alvo("quadrilE", lerpf(-14.0 - boia, 4.0 + bate, nv), 0.0, 5.0)
			_alvo("quadrilD", lerpf(-14.0 + boia, 4.0 - bate, nv), 0.0, -5.0)
			_alvo("joelhoE", lerpf(34.0 + boia, 10.0 + maxf(0.0, -bate), nv))
			_alvo("joelhoD", lerpf(34.0 - boia, 10.0 + maxf(0.0, bate), nv))
			_lados("tornozelo", lerpf(20.0, 42.0, nv), 0.0)
			chama = (1.0 if a.nado_rapido else 0.35) * nv
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
	_senta = lerpf(_senta, 1.0 if a.postura == 2 and not a.no_assento else 0.0, 1.0 - exp(-6.0 * delta))
	if a.erguendo > 0.0 or a.no_assento:
		_senta = 0.0  # levantando do chão: a pose vem de _erguer; num móvel, de _cadeira
	if a.no_assento and not a.em_pane:
		bob = _cadeira(a) * Armadura.porte
	elif a.estado == Armadura.Estado.CHAO and not a.em_pane:
		if _abaixa > 0.01:
			_soma_lados("quadril", -58.0 * _abaixa, 3.0 * _abaixa)
			_soma_lados("joelho", 96.0 * _abaixa, 0.0)
			_soma_lados("tornozelo", -38.0 * _abaixa, 0.0)
			_soma("tronco", 26.0 * _abaixa)
			_soma("cabeca", -20.0 * _abaixa)
			_soma_lados("ombro", -14.0 * _abaixa, 6.0 * _abaixa)
			_soma_lados("cotovelo", -30.0 * _abaixa * (1.0 - _passada), 0.0)
			bob += (-ABAIXA_DESCE * _abaixa + _levanta) * Armadura.porte
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
		if a.erguendo > 0.0:
			bob = _erguer(1.0 - a.erguendo / Ajustes.ERGUER_TEMPO) * Armadura.porte
	var no_chao_baixo: bool = a.estado == Armadura.Estado.CHAO and not a.em_pane and not a.no_assento and (_abaixa > 0.01 or _senta > 0.01 or a.erguendo > 0.0)
	if not no_chao_baixo:
		_levanta = 0.0
	# mirando: o braço direito aponta para onde a câmera olha (sem arma ainda)
	if (_mira_braco(a) or (a.atirando > 0.0 and a.atirando > a.atirando_e - 10.0 and not a.em_voo() and not a.em_pane)) and a.camera and not (a.atirando <= 0.0 and a.atirando_e > 0.0):
		var p: float = rad_to_deg(a.camera.pitch)
		_alvo("ombroD", -88.0 - p, 0.0, -4.0)
		_alvo("cotoveloD", -4.0)
		_alvo("cabeca", -p * 0.5)
	elif (a.mirando_agora() or a.lancando > 0.0) and a.camera and not a.em_pane:
		# granada e míssil saem dos lançadores dos ombros: o braço fica parado e só a cabeça acompanha a mira
		_alvo("cabeca", -rad_to_deg(a.camera.pitch) * 0.5)
	# o braço esquerdo aponta do mesmo jeito quando é ele que atira (tiro duplo, no L2)
	if a.atirando_e > 0.0 and not a.em_voo() and not a.em_pane and a.camera:
		var pe := rad_to_deg(a.camera.pitch)
		_alvo("ombroE", -88.0 - pe, 0.0, 4.0)
		_alvo("cotoveloE", -4.0)
		_alvo("cabeca", -pe * 0.5)
	# golpe de espada: o braço direito varre de um lado ao outro, na altura do peito, e o tronco acompanha
	if a.espada_t > 0.0 and not a.em_pane:
		var fe: float = 1.0 - a.espada_t / float(Arsenal.ESPADA["tempo"])
		var giro: float = lerpf(-85.0, 85.0, smoothstep(0.0, 1.0, fe)) * a.espada_lado
		_alvo("ombroD", -84.0 + espada_desce, -giro, -6.0)
		_alvo("cotoveloD", -6.0)
		_alvo("tronco", espada_desce * 0.25, -giro * 0.3, 0.0)
	_lamina(a.espada_t > 0.0 and not a.em_pane)
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
	chama = maxf(chama, jatos_vitrine)
	if a.esquivando > 0.0:
		_alvo("tronco", 12.0)
	# propulsores das costas inclinados (bocal para baixo e para trás), como na maquete
	_alvo("podE", 14.0, 0.0, -10.0)
	_alvo("podD", 14.0, 0.0, 10.0)
	for k in sobrepor:
		var g: Vector3 = sobrepor[k]
		_alvos[k] = Vector3(deg_to_rad(g.x), deg_to_rad(g.y), deg_to_rad(g.z))
	# juntas vão até o alvo
	# andando as juntas seguem de perto (senão a suavização come a passada); nas outras poses, mais macio
	var t := 1.0 - exp(-lerpf(12.0, 34.0, _passada) * delta)
	abertura_aletas = move_toward(abertura_aletas, aletas, delta * 3.0)
	if esqueleto:
		_aplicar_ossos(bob, t)
	else:
		for k in j:
			var no: Node3D = j[k]
			if no == null or k.begins_with("aleta") or k.begins_with("luva"):
				continue
			var alvo: Vector3 = _alvos.get(k, Vector3.ZERO)
			no.rotation = no.rotation.lerp(alvo, t)
		_torcer_luvas(delta, a)
		_armas_do_punho(delta, a)
		_olhos(delta, a)
		_animar_rabo(delta, a)
		(j["raiz"] as Node3D).position.y = lerpf((j["raiz"] as Node3D).position.y, _raiz_y + bob, t)
		# aletas abrem como asas ao planar
		var ab := smoothstep(0.0, 1.0, abertura_aletas)
		for lado in ["E", "D"]:
			var s := 1.0 if lado == "E" else -1.0
			if j.get("aleta" + lado) is Node3D:  # os inimigos não têm as abas
				(j["aleta" + lado] as Node3D).rotation = Vector3(0, 0, deg_to_rad(78.0 * s * ab))
			for i in 3:
				if j.get("aleta%s%d" % [lado, i]) is Node3D:
					(j["aleta%s%d" % [lado, i]] as Node3D).rotation = Vector3(deg_to_rad(i * 10.0 * ab), 0, deg_to_rad(i * 9.0 * s * ab))
	# abaixado, sentado ou levantando: mede a peça mais baixa do corpo e sobe a bacia até ela encostar no
	# chão, sem entrar (abaixado, os pés afundavam)
	if (no_chao_baixo or a.no_assento) and not esqueleto and _malhas.is_empty():
		_medir_malhas()
	if no_chao_baixo and not esqueleto:
		var baixo := INF
		for i in _malhas.size():
			var gt := _malhas[i].global_transform
			for v in _pontos[i]:
				baixo = minf(baixo, gt.basis.y.y * v.y + gt.basis.x.y * v.x + gt.basis.z.y * v.z + gt.origin.y)
		var folga := (baixo - global_position.y) / Armadura.porte
		_levanta = clampf(_levanta - folga * 0.4, 0.0, 0.6)
	# sentado num móvel (parado, já assentado): mede a peça mais baixa da bacia e do tronco (as pernas pendem
	# para fora do assento e não contam) e acerta a altura até ela encostar no assento
	if a.no_assento and a.assento_fase == 1 and not a.em_pane and not esqueleto and not _malhas.is_empty():
		var baixo_b := INF
		for i in _malhas.size():
			if _perna[i]:
				continue
			var gt := _malhas[i].global_transform
			for v in _pontos[i]:
				baixo_b = minf(baixo_b, gt.basis.y.y * v.y + gt.basis.x.y * v.x + gt.basis.z.y * v.z + gt.origin.y)
		if baixo_b < INF:
			_cadeira_ajuste = clampf(_cadeira_ajuste - (baixo_b - global_position.y) / Armadura.porte * 0.4, -0.6, 0.6)
	if not pecas.is_empty():
		MelhoriasVisual.animar(self, a, delta)
	# chamas e brilho do calor
	_chama_tamanho = lerpf(_chama_tamanho, chama, 1.0 - exp(-10.0 * delta))
	_bafo_do_frio(a)
	# a origem das peças do modelo fica no chão (não no bocal), então a chama não escala: muda o brilho
	for c in chamas:
		c.visible = _chama_tamanho > 0.08
	for c in chamas_pequenas:
		c.visible = _chama_tamanho > 0.08 or (c == chama_tiro and a.clarao_tiro > 0.05)
	# a cor do fogo dos pés e das costas é o prêmio das rotas (doc §147); o das mãos fica o de fábrica
	var cor_j := COR_CHAMA
	if jatos_vitrine > 0.0:
		cor_j = Rotas.CORES.get(cor_vitrine, COR_CHAMA)
	elif a is Armadura:
		cor_j = Rotas.CORES.get(Rotas.rastro, COR_CHAMA)
	mat_chama.albedo_color = Color(cor_j, clampf(_chama_tamanho * 0.55 + randf_range(-0.08, 0.08), 0.0, 1.0))
	if mat_chama_fraca:
		mat_chama_fraca.albedo_color.a = clampf(mat_chama.albedo_color.a * 0.4 + a.impulso * 0.7, 0.0, 1.0)
	if mat_chama_tiro:
		var base_mao := mat_chama_fraca.albedo_color.a if _chama_tamanho > 0.08 else 0.0
		mat_chama_tiro.albedo_color.a = clampf(maxf(base_mao, a.clarao_tiro), 0.0, 1.0)
	var q: float = a.calor / 100.0
	# o núcleo do peito: de noite acendia a 3,2 e parecia a luz do peito ligada (2026-11-20); agora só um ponto
	var brilho := lerpf(lerpf(0.6, 1.3, noite), 7.0, q * q)
	if a.superaquecido:
		brilho = 8.0 if fmod(Time.get_ticks_msec() * 0.001, 0.3) < 0.15 else 2.0
	if a.em_pane:
		brilho = 0.05
	mat_calor.emission_energy_multiplier = brilho
	mat_calor.emission = Color(1.0, 0.42, 0.1).lerp(Color(1.0, 0.85, 0.65), smoothstep(0.8, 1.0, q))


var _lamina_no: MeshInstance3D


## A lâmina de laser: sai da mão direita, ao longo do braço, só enquanto dura o golpe.
## Os olhos de tela do robô novo (juntas `olhoE` e `olhoD`, uma no meio de cada olho): piscam de tempos em
## tempos, estreitam na mira, balançam tontos com o motor superaquecido e ficam caídos, quase fechados, em pane.
## `olhar` diz qual expressão está valendo (testes e fotos); `expressao_forcada` fixa uma (fotos).
var olhar := "normal"
var expressao_forcada := ""
var olhos_abertos := 1.0  # 0 a 1: as cenas da história (Historia) fecham os olhos e abrem devagar, no despertar
var _olho_nos := {}
var _pisca_em := 2.0
var _pisca_t := 0.0
var _olho_tempo := 0.0


func _olhos(delta: float, a) -> void:
	if _olho_nos.is_empty():
		for lado: String in ["E", "D"]:
			_olho_nos[lado] = modelo.find_child("olho" + lado, true, false)
	if not (_olho_nos["E"] is Node3D) or not (_olho_nos["D"] is Node3D):
		return
	_olho_tempo += delta
	olhar = "normal"
	if a.em_pane:
		olhar = "pane"
	elif a.superaquecido:
		olhar = "tonto"
	elif a.mirando_agora() or a.atirando > 0.0 or a.lancando > 0.0 or a.espada_t > 0.0:
		olhar = "foco"
	if expressao_forcada != "":
		olhar = expressao_forcada
	# piscar: fecha por um instante, a intervalos desiguais (em pane não pisca: já está quase fechado)
	_pisca_em -= delta
	if _pisca_em <= 0.0:
		_pisca_em = randf_range(2.2, 5.5)
		_pisca_t = 0.13
	_pisca_t = maxf(0.0, _pisca_t - delta)
	for lado: String in ["E", "D"]:
		var no := _olho_nos[lado] as Node3D
		var s := 1.0 if lado == "E" else -1.0
		var alto := 1.0
		var largo := 1.0
		var giro := 0.0
		match olhar:
			"pane":
				alto = 0.22
				largo = 1.15
				giro = -0.3 * s  # caídos para fora
			"tonto":
				alto = 0.75 + 0.2 * sin(_olho_tempo * 7.0 + s)
				giro = 0.55 * sin(_olho_tempo * 5.0) * s + 0.25 * sin(_olho_tempo * 9.0)
			"foco":
				alto = 0.6
				largo = 1.1
				giro = 0.16 * s  # franzidos para dentro
		if _pisca_t > 0.0 and olhar != "pane":
			alto = 0.08
		if olhos_abertos < 1.0:
			alto = lerpf(0.04, alto, clampf(olhos_abertos, 0.0, 1.0))
		var t := 1.0 - exp(-22.0 * delta)
		no.scale = no.scale.lerp(Vector3(largo, alto, 1.0), t)
		no.rotation.z = lerp_angle(no.rotation.z, giro, t)

## As luvas do robô novo (juntas `luvaE` e `luvaD`): em descanso ficam torcidas 90 graus em torno do antebraço,
## com o polegar para a frente e a mão aberta; para mirar, atirar ou golpear a luva destorce, a mão fecha e o
## cano da luva aponta para a frente.
var _luva_k := {"E": 1.0, "D": 1.0}


func _torcer_luvas(delta: float, a) -> void:
	for lado: String in ["E", "D"]:
		var no := modelo.find_child("luva" + lado, true, false) as Node3D if not _luvas.has(lado) else _luvas[lado] as Node3D
		_luvas[lado] = no
		if no == null:
			continue
		var reta: bool = (a.atirando > 0.0 or _mira_braco(a) or a.espada_t > 0.0) if lado == "D" else a.atirando_e > 0.0
		_luva_k[lado] = move_toward(float(_luva_k[lado]), 0.0 if (reta and not a.em_pane) else 1.0, delta * 7.0)
		var k := smoothstep(0.0, 1.0, float(_luva_k[lado]))
		no.rotation = Vector3(0.0, (PI * 0.5 if lado == "E" else -PI * 0.5) * k, 0.0)
		# e a mão fecha quando a luva está reta
		if not _dedos.has(lado):
			_dedos[lado] = modelo.find_child("dedos" + lado, true, false)
		if _dedos[lado] is Node3D:
			(_dedos[lado] as Node3D).rotation = Vector3(deg_to_rad(100.0) * (1.0 - k), 0.0, 0.0)


## Mirando com o braço direito: no modo de mísseis a mira é a do lançador do ombro, e o braço fica parado.
func _mira_braco(a) -> bool:
	return a.mirando_agora() and not (a is Armadura and Arsenal.modo == "misseis")


var _luvas := {}
var _dedos := {}
var _bocas := {}
var _arma_k := {"E": 0.0, "D": 0.0}  # 0 a mão para fora, 1 a arma para fora
var _punho0 := {}  # lado -> [posição, escala] do punho em descanso


## A mão entra no antebraço e a arma sai do punho no lugar dela (2026-11-23, rascunho 7 aprovado): na primeira
## metade a mão fechada sobe para dentro da luva e encolhe, e a boca escura do punho aparece; na segunda a arma
## desliza para fora (as aletas da precisão abrem no fim). O braço direito arma ao mirar ou atirar, o esquerdo
## só no tiro duplo; com a lâmina ou em pane, a mão fica.
func _armas_do_punho(delta: float, a) -> void:
	for lado: String in ["E", "D"]:
		var pu = j.get("punho" + lado)
		if not (pu is Node3D):
			continue
		var punho := pu as Node3D
		if not _punho0.has(lado):
			_punho0[lado] = [punho.position, punho.scale]
		var dados: Dictionary = armas_punho.get(lado, {})
		var tem: bool = not dados.is_empty() and is_instance_valid(dados["arma"])
		var armado: bool = (a.atirando > 0.0 or _mira_braco(a)) and a.espada_t <= 0.0 if lado == "D" else a.atirando_e > 0.0
		armado = armado and tem and not a.em_pane
		_arma_k[lado] = move_toward(float(_arma_k[lado]), 1.0 if armado else 0.0, delta * 6.0)
		var k := float(_arma_k[lado]) if arma_vitrine < 0.0 or not tem else arma_vitrine
		var m := smoothstep(0.0, 1.0, clampf(k * 2.0, 0.0, 1.0))
		var w := smoothstep(0.0, 1.0, clampf(k * 2.0 - 1.0, 0.0, 1.0))
		punho.position = (_punho0[lado][0] as Vector3) + Vector3(0.0, 0.05 * m, 0.0)
		punho.scale = (_punho0[lado][1] as Vector3) * (1.0 - 0.3 * m)
		punho.visible = m < 0.99
		if not tem:
			continue
		var arma := dados["arma"] as Node3D
		arma.visible = w > 0.01
		arma.position = (dados["pos"] as Vector3) + Vector3(0.0, (1.0 - w) * 0.06, 0.0)
		var lw := lerpf(0.6, 1.0, w)
		arma.scale = Vector3(lw, maxf(w, 0.02), lw)
		(dados["vao"] as Node3D).visible = m > 0.02
		if dados["giro"] is Node3D and a.atirando > 0.0 and w > 0.5:
			(dados["giro"] as Node3D).rotation.y += delta * 22.0  # os seis canos da rajada giram no tiro
		if dados["aletas"] is Node3D:
			(dados["aletas"] as Node3D).scale = Vector3.ONE * lerpf(0.3, 1.0, smoothstep(0.7, 1.0, w))


## De onde o tiro sai: a ponta da arma do punho; no robô sem ela, a junta `boca` da luva; sem as duas, `null`.
func boca_da_arma(esquerda: bool) -> Node3D:
	var lado := "E" if esquerda else "D"
	var dados: Dictionary = armas_punho.get(lado, {})
	if not dados.is_empty() and is_instance_valid(dados["boca"]):
		return dados["boca"] as Node3D
	if not _bocas.has(lado):
		_bocas[lado] = modelo.find_child("boca" + lado, true, false)
	return _bocas[lado] as Node3D


func _lamina(acesa: bool) -> void:
	if _lamina_no == null:
		if not acesa or not (j.get("punhoD") is Node3D):
			return
		_lamina_no = MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		# lâmina de pulso de 80 cm (pedido do usuário, 2026-11-20; a de 35 cm ficou curta demais). Era uma de 1,25 m
		cm.radius = 0.03 * escala_lamina
		cm.height = 0.8 * escala_lamina
		_lamina_no.mesh = cm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = cor_lamina.lerp(Color.WHITE, 0.6)
		m.emission_enabled = true
		m.emission = cor_lamina
		m.emission_energy_multiplier = 4.0
		_lamina_no.material_override = m
		_lamina_no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var punho := j["punhoD"] as Node3D
		punho.add_child(_lamina_no)
		# no descanso a mão pende para baixo do punho: a lâmina segue o braço (o -Y da junta), passando da
		# mão. As medidas são em metros do mundo, desfeita a escala do modelo
		var h := ALTURA_ALVO * Armadura.porte
		var esc := maxf(0.001, punho.global_basis.get_scale().y / maxf(0.001, punho.scale.y))  # sem a mão encolhida
		_lamina_no.transform = Transform3D(Basis.from_scale(Vector3.ONE / esc), Vector3(0, -(0.07 * h + 0.42) * escala_lamina / esc, 0))
		var luz := OmniLight3D.new()
		luz.light_color = cor_lamina
		luz.light_energy = 0.4
		luz.omni_range = 1.6
		luz.shadow_enabled = false
		_lamina_no.add_child(luz)
	_lamina_no.visible = acesa


## No frio da Montanha do Degelo, com o motor ligado, um sopro branco curto sai da mochila e fica para trás no
## ar (doc §137.11). Só o robô do jogador; as máquinas não sentem o frio.
func _bafo_do_frio(a) -> void:
	var ligar: bool = a is Armadura and a.frio > 0.35 and a.motor_ligado() and not a.em_pane
	if _bafo == null:
		if not ligar:
			return
		var pt := Armadura.porte
		_bafo = CPUParticles3D.new()
		_bafo.name = "BafoFrio"
		_bafo.amount = 5
		_bafo.lifetime = 1.1
		_bafo.explosiveness = 0.85  # sai em sopros, como respiração no frio, e não num jato contínuo
		_bafo.local_coords = false  # o sopro fica no ar e o robô segue em frente
		_bafo.position = Vector3(0.0, 1.35 * pt, 0.42 * pt)  # nas costas, entre os dois propulsores
		_bafo.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_bafo.emission_sphere_radius = 0.14 * pt
		_bafo.direction = Vector3(0.0, 0.25, 1.0)  # para trás, quase sem subir: não tampa a cabeça
		_bafo.spread = 35.0
		_bafo.initial_velocity_min = 0.9
		_bafo.initial_velocity_max = 1.5
		_bafo.gravity = Vector3(0.0, 0.12, 0.0)
		_bafo.damping_min = 0.6
		_bafo.damping_max = 1.2
		_bafo.scale_amount_min = 0.38 * pt
		_bafo.scale_amount_max = 0.55 * pt
		var cresce := Curve.new()
		cresce.add_point(Vector2(0.0, 0.5))
		cresce.add_point(Vector2(1.0, 1.8))
		_bafo.scale_amount_curve = cresce
		var rampa := Gradient.new()
		rampa.set_color(0, Color(1.0, 1.0, 1.0, 0.4))
		rampa.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_bafo.color_ramp = rampa
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 1.0, 1.0)
		if ResourceLoader.exists("res://assets/fx/kenney/smoke_04.png"):
			mat.albedo_texture = load("res://assets/fx/kenney/smoke_04.png")
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		quad.material = mat
		_bafo.mesh = quad
		add_child(_bafo)
	_bafo.emitting = ligar


# ------------------------------------------------------------------ o corpo em peças (Corpo, doc §143)

var corpo := {}  # parte -> conjunto vestido agora ("" é a peça de fábrica)
var _de_fabrica := {}  # parte -> malhas do modelo, escondidas quando a parte é de um conjunto
var _enxertos: Array[Node] = []
var _rabo: Array[Node3D] = []  # as juntas do rabo, da raiz para a ponta
var _rabo_dir: Array[Vector3] = []  # cada gomo em descanso (da junta até a seguinte), no referencial do modelo
var _rabo_fase := 0.0
var _rabo_estica := 0.0
var _rabo_alvo := Vector3(0, 0, -1)


## Guarda as malhas de fábrica de cada parte (chamar uma vez, logo depois de achar as juntas).
func _guardar_fabrica() -> void:
	for parte: String in Corpo.PARTES:
		_de_fabrica[parte] = []
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		var parte := Corpo.parte_de(n)
		if parte != "":
			(_de_fabrica[parte] as Array).append(n)
			n.set_meta("nome_fabrica", n.name)


## Veste as partes pedidas ({parte: conjunto}; "" ou ausente é a de fábrica). Pode ser chamado a qualquer hora:
## as peças vão presas nas juntas, então seguem a pose de agora.
func vestir_corpo(pedido: Dictionary) -> void:
	if _de_fabrica.is_empty():
		return
	for n in _enxertos:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	_enxertos.clear()
	_rabo.clear()
	_rabo_dir.clear()
	_malhas.clear()
	_pontos.clear()
	_perna.clear()
	corpo = {}
	for parte: String in Corpo.PARTES:
		var chave := String(pedido.get(parte, ""))
		if Corpo.cena(chave) == null:
			chave = ""
		corpo[parte] = chave
		for n: MeshInstance3D in _de_fabrica[parte]:
			var fabrica := chave == ""
			n.visible = fabrica
			# a de fábrica guardada troca de nome: as peças novas ficam com os nomes que as melhorias procuram
			# (o cano da luva, por exemplo)
			n.name = String(n.get_meta("nome_fabrica")) if fabrica else "guardada_" + String(n.get_meta("nome_fabrica"))
			if fabrica:
				n.remove_meta("guardada")
			else:
				n.set_meta("guardada", true)
	for parte: String in Corpo.PARTES:
		var chave: String = corpo[parte]
		if chave == "":
			continue
		var copia := Corpo.cena(chave).instantiate()
		for nome_j: String in Corpo.JUNTAS[parte]:
			var de := copia.find_child(nome_j, true, false)
			var para := j.get(nome_j) as Node3D
			if para == null:
				para = modelo.find_child(nome_j, true, false) as Node3D
			if de == null or para == null:
				continue
			for f in de.get_children():
				if f is MeshInstance3D:
					_sem_dono(f)
					f.reparent(para, false)
					_trocar_materiais(f)
					_enxertos.append(f)
			if parte == "tronco" and nome_j == "raiz":
				var r0 := de.find_child("rabo0", false, false)
				if r0 != null:
					_sem_dono(r0)
					r0.reparent(para, false)
					_trocar_materiais(r0)
					_enxertos.append(r0)
					_achar_rabo(r0 as Node3D)
		copia.free()
	_pintar_mochila()
	# o tronco de fábrica de volta traz o radiador e as grades: as melhorias decidem de novo o que aparece
	if has_meta("descanso"):
		vestir_melhorias()


var cor_detalhe = null  # Color com o tronco de um conjunto (Corpo.COR), null com o de fábrica


## Os detalhes azuis da mochila e das abas das costas (o material `detalhe`) vão na cor do tronco vestido; com o
## tronco de fábrica, voltam ao azul.
func _pintar_mochila() -> void:
	cor_detalhe = null
	var nome_cor := String(Corpo.COR.get(String(corpo.get("tronco", "")), ""))
	if nome_cor != "":
		for n in _enxertos:
			if not (n is MeshInstance3D) or cor_detalhe != null:
				continue
			var mi := n as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if m is StandardMaterial3D and m.resource_name == nome_cor:
					cor_detalhe = (m as StandardMaterial3D).albedo_color
					break
	var costas = j.get("costas")
	if not (costas is Node3D):
		return
	for n in (costas as Node3D).find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if not (m is StandardMaterial3D) or m.resource_name != "detalhe":
				continue
			var cor: Color = cor_detalhe if cor_detalhe != null else (m as StandardMaterial3D).albedo_color
			if toon:
				var mt := ShaderMaterial.new()
				mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
				mt.set_shader_parameter("cor", cor)
				mt.set_shader_parameter("brilho_borda", 0.18)
				mi.set_surface_override_material(s, mt)
			else:
				var sm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				sm.albedo_color = cor
				mi.set_surface_override_material(s, sm)


## A peça tirada do arquivo do conjunto deixa de pertencer a ele (senão o Godot reclama ao mudar de pai).
static func _sem_dono(n: Node) -> void:
	n.owner = null
	for f in n.get_children():
		_sem_dono(f)


## As juntas do rabo (rabo0, rabo1... e a ponta) e a direção de cada gomo em descanso.
func _achar_rabo(r0: Node3D) -> void:
	var no := r0
	while no != null:
		_rabo.append(no)
		var prox := no.find_child("rabo%d" % _rabo.size(), false, false) as Node3D
		if prox == null:
			var ponta := no.find_child("rabo_ponta", false, false) as Node3D
			_rabo_dir.append(ponta.position if ponta else Vector3(0, 0, -0.08))
		else:
			_rabo_dir.append(prox.position)
		no = prox
	_rabo_fase = 0.0
	_rabo_estica = 0.0


## O ângulo de um gomo no plano de trás e de cima (giro em torno do x do modelo; 0 é para trás).
static func _ang_rabo(v: Vector3) -> float:
	return atan2(v.y, -v.z)


## O rabo (pedido do usuário): parado ele balança de um lado para o outro, numa onda que vai da raiz à ponta;
## correndo e voando ele estica para trás, para longe de onde o robô vai, e sobra só a curvinha da ponta.
func _animar_rabo(delta: float, a) -> void:
	if _rabo.is_empty():
		return
	var raiz := j.get("raiz") as Node3D
	if raiz == null:
		return
	var hv := Vector2(a.velocity.x, a.velocity.z).length()
	var estica := 0.0
	var para_tras := Vector3.ZERO
	if (a.em_voo() or a.estado == Armadura.Estado.NADO) and a.velocity.length() > 1.5:
		estica = 1.0
		para_tras = -a.velocity.normalized()
	elif a.estado == Armadura.Estado.CHAO and hv > 0.8:
		estica = clampf((hv - 0.8) / maxf(0.5, Armadura.correr() * 0.45), 0.0, 1.0)
		para_tras = (Vector3(-a.velocity.x, 0.0, -a.velocity.z).normalized() + Vector3(0, 0.15, 0)).normalized()
	if a.em_pane or a.no_assento:
		estica = 0.0
	_rabo_estica = lerpf(_rabo_estica, estica, 1.0 - exp(-5.0 * delta))
	if para_tras != Vector3.ZERO:
		var local := raiz.global_basis.orthonormalized().inverse() * para_tras
		_rabo_alvo = _rabo_alvo.lerp(local, 1.0 - exp(-8.0 * delta)).normalized()
	# balanço: devagar e largo parado, curtinho e rápido esticado (a ponta tremula no vento)
	_rabo_fase += delta * lerpf(2.4, 9.0, _rabo_estica)
	var amp := deg_to_rad(lerpf(20.0, 5.0, _rabo_estica)) * (0.25 if a.em_pane else 1.0)
	var t := 1.0 - exp(-12.0 * delta)
	for i in _rabo.size():
		var d := _rabo_dir[i]
		var ang := _ang_rabo(_rabo_alvo) - _ang_rabo(d) if i == 0 else 0.75 * (_ang_rabo(_rabo_dir[i - 1]) - _ang_rabo(d))
		var esticar := Quaternion.IDENTITY.slerp(Quaternion(Vector3.RIGHT, ang), _rabo_estica)
		var lado := d.cross(Vector3.RIGHT)
		var balanca := Quaternion(lado.normalized(), amp * sin(_rabo_fase - i * 0.8)) if lado.length() > 0.0001 else Quaternion.IDENTITY
		_rabo[i].quaternion = _rabo[i].quaternion.slerp(esticar * balanca, t)
