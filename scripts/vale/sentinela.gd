class_name Sentinela
extends Node3D
## Sentinela: uma torre andante de três pernas (3,2 m), lenta. Vê o robô de longe (55 m, com linha de visão
## livre do terreno), acende a lente, avisa com um feixe vermelho e dá um tiro forte. Cada tiro que acerta a
## cabeça esquenta o corpo; com calor 100 ele desliga, cai e fica assim um tempo, depois se levanta no mesmo
## lugar. Sem física para andar: fica sobre o relevo (mapa.altura) e não entra na água.
## Modelo: res://assets/vale/sentinela.glb (peças soltas na raiz). A cabeça olha para +Z; o nó dela gira PI em Y,
## então a frente é -Z. Pernas: IK de dois segmentos, o joelho dobra para fora e para cima.
## Uso: Sentinela.new(), defina mapa, alvo, casa (e o resto), e só então add_child.

signal disparou(origem: Vector3, destino: Vector3)
signal desligou

enum Estado { PATRULHA, ALERTA, AVISO, DISPARO, RECARGA, DESLIGADO }
const NOMES := ["patrulha", "alerta", "aviso", "disparo", "recarga", "desligado"]
const CENA := "res://assets/vale/sentinela.glb"

const ALTURA_CABECA := 2.75
const VEL_ANDAR := 1.1
const VER := 55.0  # m
const PERDER := 75.0  # m
const ALCANCE_TIRO := 60.0
const TEMPO_AVISO := 1.6
const TEMPO_RECARGA := 3.2
const VEL_PROJETIL := 38.0
const RAIO_GOLPE := 1.6
const FORCA_GOLPE := 9.0
const COXA := 1.0
const CANELA := 2.0
const PASSO := 1.1
const CALOR_POR_TIRO := 17.0  # 6 tiros seguidos desligam
const ESFRIA := 5.0  # calor perdido por segundo
const ESFRIA_ESPERA := 2.5  # só começa a esfriar depois desse tempo sem levar tiro
const TEMPO_DESLIGADO := 3600.0  # segundos reais desligado: um dia inteiro do jogo, para haver paz depois da briga

# detalhes do corpo (afinar aqui)
const QUADRIL_RAIO := 0.18
const QUADRIL_QUEDA := 0.55
const PE_FORA := 1.45
const ANG_PERNAS := [PI / 2.0, 210.0 * PI / 180.0, 330.0 * PI / 180.0]  # +Z é para trás: 90 atrás, 210 e 330 à frente
const DURACAO_PASSO := 0.45
const ALTURA_PASSO := 0.35
const VEL_CABECA := 1.5  # rad/s
const PISCA_BRANCO := 0.1
const TEMPO_ALERTA := 0.8
const TEMPO_TRAVA := 0.35
const TEMPO_SEM_VISAO := 4.0
const ALTURA_CAIDA := 0.5  # centro da cabeça ao cair, acima do chão
const TEMPO_QUEDA := 0.9
const TEMPO_LEVANTAR := 1.5
const TEMPO_FUMACA := 6.0

var mapa: Ilha
var alvo: Armadura  # o robô; pode ser null
var casa := Vector3.ZERO
var raio_patrulha := 22.0
var semente := 0
var pintar: Callable  # o integrador pinta o visual; a lente é pintada à parte
var estado := 0  # Estado
var pose_foto := -1  # >= 0: fica parado nesse estado, só animando (fotos)
var calor := 0.0  # 0 a 100; com 100 desliga
var desligamentos := 0
var religamentos := 0
var disparos := 0
var mat_lente: StandardMaterial3D

var mech: MechVisual  # o corpo: a Leela do Animated Mech Pack (escolha do usuário), de 3,1 m
const ALTURA_MECH := 3.1
var _rng := RandomNumberGenerator.new()
var _pronto := false
var _tempo := 0.0  # tempo no estado atual
var _visual: Node3D
var _cabeca: Node3D  # pivô no centro da cabeça
var _lente: MeshInstance3D
var _malhas_cabeca: Array[MeshInstance3D] = []
var _coxas: Array[MeshInstance3D] = []
var _canelas: Array[MeshInstance3D] = []
var _joelhos: Array[MeshInstance3D] = []
var _pes: Array[MeshInstance3D] = []
var _corpo_tiro: StaticBody3D
var _feixe: MeshInstance3D
var _fumaca: GPUParticles3D
var _luz_calor: OmniLight3D
var _mat_pisca: StandardMaterial3D
var _mat_feixe: StandardMaterial3D
var _mat_projetil: StandardMaterial3D
var _mat_faisca: StandardMaterial3D
var _malha_projetil: SphereMesh
var _malha_faisca: SphereMesh
var _pe_w: Array[Vector3] = []  # pés plantados, no mundo
var _passo_i := -1
var _ronco: AudioStreamPlayer3D
var _passo_t := 0.0
var _passo_de := Vector3.ZERO
var _passo_ate := Vector3.ZERO
var _rumo_mov := Vector3.ZERO
var _andando := false
var _balanco := 0.0
var _fase_andar := 0.0
var _pat_pausa := 1.0
var _pat_alvo := Vector3.ZERO
var _tem_alvo := false
var _olhar_yaw := 0.0
var _olhar_t := 0.0
var _yaw_cab := 0.0
var _pitch_cab := 0.0
var _cab_y := ALTURA_CABECA  # altura do centro da cabeça, no espaço local
var _ve := false
var _dist_alvo := INF
var _sem_visao := 0.0
var _mira := Vector3.ZERO
var _pisca := 0.0
var _empurrao := 0.0
var _fase_lente := 0.0
var _tempo_sem_tiro := 0.0
var _restante := TEMPO_DESLIGADO  # segundos que faltam desligado
var _levantando := false
var _queda := 0.0  # 0 de pé, 1 caído
var _proj_no: Node3D
var _proj_ativo := false
var _proj_pos := Vector3.ZERO
var _proj_dir := Vector3.FORWARD
var _proj_viajado := 0.0


func _ready() -> void:
	add_to_group("maquinas")
	_rng.seed = semente * 7919 + 31
	var cena := load(CENA) as PackedScene
	if cena == null:
		push_error("sentinela: modelo não encontrado em %s" % CENA)
		return
	var raiz := cena.instantiate() as Node3D
	var cab := raiz.find_child("cabeca", true, false) as MeshInstance3D
	var coxa := raiz.find_child("coxa", true, false) as MeshInstance3D
	var canela := raiz.find_child("canela", true, false) as MeshInstance3D
	var joelho := raiz.find_child("joelho", true, false) as MeshInstance3D
	var pe := raiz.find_child("pe", true, false) as MeshInstance3D
	if cab == null or coxa == null or canela == null or joelho == null or pe == null:
		push_error("sentinela: peça do modelo não achada")
		raiz.free()
		return

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_cabeca = Node3D.new()
	_cabeca.name = "Cabeca"
	_visual.add_child(_cabeca)
	var modelo_cab := Node3D.new()
	modelo_cab.rotation.y = PI  # o modelo olha para +Z; aqui a frente é -Z
	_cabeca.add_child(modelo_cab)
	var copia_cab := _copia_arvore(cab)
	modelo_cab.add_child(copia_cab)
	_lente = copia_cab.find_child("lente", true, false) as MeshInstance3D
	copia_cab.visible = false  # o corpo agora é a Leela do pacote (mech); as peças antigas seguem só na conta

	for i in 3:
		var c := _copia(coxa)
		c.name = "coxa%d" % i
		_visual.add_child(c)
		_coxas.append(c)
		var k := _copia(canela)
		k.name = "canela%d" % i
		_visual.add_child(k)
		_canelas.append(k)
		var j := _copia(joelho)
		j.name = "joelho%d" % i
		_visual.add_child(j)
		_joelhos.append(j)
		var p := _copia(pe)
		p.name = "pe%d" % i
		_visual.add_child(p)
		_pes.append(p)
	raiz.free()  # as peças soltas originais saem da cena; as cópias ficaram
	for mi: MeshInstance3D in _coxas + _canelas + _joelhos + _pes:
		mi.visible = false
	mech = MechVisual.criar("leela", ALTURA_MECH, (mapa as Clareira)._tex if mapa is Clareira else null)
	mech.margem_caido = 0.13  # o casulo é gordo: caído, o meio dele fica bem acima do chão
	mech.position.y = 0.07  # os pés do modelo passam um pouco da origem
	add_child(mech)

	if _lente == null:
		push_error("sentinela: lente não achada")
		return
	if pintar.is_valid():
		pintar.call(_visual)
	mat_lente = StandardMaterial3D.new()
	mat_lente.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_lente.albedo_color = Color(1.0, 0.12, 0.08)
	mat_lente.emission_enabled = true
	mat_lente.emission = Color(1.0, 0.1, 0.05)
	mat_lente.emission_energy_multiplier = 1.0
	_lente.material_override = mat_lente

	_corpo_tiro = StaticBody3D.new()
	_corpo_tiro.name = "Acerto"
	_corpo_tiro.collision_layer = 2
	_corpo_tiro.collision_mask = 0
	add_child(_corpo_tiro)
	var cs := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.7
	cs.shape = esfera
	_corpo_tiro.add_child(cs)

	_criar_efeitos()
	global_position = Vector3(casa.x, mapa.altura(casa.x, casa.z), casa.z)
	rotation.y = _rng.randf() * TAU
	for i in 3:
		_pe_w.append(_repouso_w(i))
	_pronto = true
	_ronco = Som.laco3d(self, "sentinela_loop", -5.0, 7.0, 60.0)


func _copia(orig: MeshInstance3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = orig.name
	mi.mesh = orig.mesh
	mi.transform = orig.transform
	return mi


func _copia_arvore(orig: MeshInstance3D) -> MeshInstance3D:
	var mi := _copia(orig)
	_malhas_cabeca.append(mi)
	for f in orig.get_children():
		if f is MeshInstance3D:
			mi.add_child(_copia_arvore(f))
	return mi


func _criar_efeitos() -> void:
	_mat_feixe = StandardMaterial3D.new()
	_mat_feixe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_feixe.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_feixe.albedo_color = Color(1.0, 0.15, 0.1, 0.5)
	var cil := CylinderMesh.new()
	cil.top_radius = 0.025
	cil.bottom_radius = 0.025
	cil.height = 1.0
	cil.radial_segments = 6
	cil.rings = 1
	_feixe = MeshInstance3D.new()
	_feixe.mesh = cil
	_feixe.material_override = _mat_feixe
	_feixe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_feixe.top_level = true
	_feixe.visible = false
	add_child(_feixe)

	_mat_pisca = StandardMaterial3D.new()
	_mat_pisca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_pisca.albedo_color = Color(1.0, 1.0, 1.0)

	_mat_projetil = StandardMaterial3D.new()
	_mat_projetil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_projetil.albedo_color = Color(1.0, 0.45, 0.2)
	_mat_projetil.emission_enabled = true
	_mat_projetil.emission = Color(1.0, 0.25, 0.1)
	_mat_projetil.emission_energy_multiplier = 4.0
	_malha_projetil = SphereMesh.new()
	_malha_projetil.radius = 0.28
	_malha_projetil.height = 0.56

	_mat_faisca = StandardMaterial3D.new()
	_mat_faisca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_faisca.albedo_color = Color(1.0, 0.6, 0.25)
	_mat_faisca.emission_enabled = true
	_mat_faisca.emission = Color(1.0, 0.5, 0.15)
	_mat_faisca.emission_energy_multiplier = 3.0
	_malha_faisca = SphereMesh.new()
	_malha_faisca.radius = 0.05
	_malha_faisca.height = 0.1
	_malha_faisca.radial_segments = 4
	_malha_faisca.rings = 2
	_malha_faisca.material = _mat_faisca

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.0, 0.2, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fumo := QuadMesh.new()
	fumo.size = Vector2(0.6, 0.6)
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mf.albedo_color = Color(0.25, 0.25, 0.27, 0.45)
	fumo.material = mf
	_fumaca = GPUParticles3D.new()
	_fumaca.process_material = pm
	_fumaca.draw_pass_1 = fumo
	_fumaca.amount = 16
	_fumaca.lifetime = 2.5
	_fumaca.emitting = false
	_fumaca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fumaca)

	_luz_calor = OmniLight3D.new()
	_luz_calor.light_color = Color(1.0, 0.5, 0.2)
	_luz_calor.light_energy = 0.0
	_luz_calor.omni_range = 4.0
	_luz_calor.shadow_enabled = false
	add_child(_luz_calor)


## Nome do estado atual, para testes e depuração.
func nome_estado() -> String:
	return NOMES[estado]


## Um tiro que acerta a cabeça (a menos de 1 m do centro): esquenta, dá um tranco e pisca. Com calor 100, desliga.
## Onde a mira do robô trava: a cabeça (Vector3.INF: desligado).
func ponto_de_trava() -> Vector3:
	return Vector3.INF if (not _pronto or estado == Estado.DESLIGADO) else _cabeca.global_position


func levar_tiro(ponto: Vector3) -> void:
	if not _pronto or estado == Estado.DESLIGADO:
		return
	if ponto.distance_to(_cabeca.global_position) >= 1.0:
		return
	calor = minf(100.0, calor + CALOR_POR_TIRO)
	_tempo_sem_tiro = 0.0
	_empurrao = 1.0
	_pisca = PISCA_BRANCO
	Som.toque3d(self, Som.variacao("impacto", 3), ponto, -2.0)
	if estado == Estado.PATRULHA:
		_mudar(Estado.ALERTA)
	if calor >= 100.0:
		_desligar()


## O mergulho com impacto do robô por perto: esquenta muito (dois impactos desligam).
func levar_impacto(ponto: Vector3) -> void:
	if not _pronto or estado == Estado.DESLIGADO or ponto.distance_to(global_position) > 9.0:
		return
	calor = minf(100.0, calor + 60.0)
	_tempo_sem_tiro = 0.0
	_pisca = PISCA_BRANCO
	if estado == Estado.PATRULHA:
		_mudar(Estado.ALERTA)
	if calor >= 100.0:
		_desligar()


## O jogo chama quando o tempo dá um salto: desconta do tempo que falta desligado; ligado, zera o calor.
func avancar_tempo(segundos: float) -> void:
	if estado == Estado.DESLIGADO:
		_restante -= segundos
		if _restante <= 0.0:
			religar()
	else:
		calor = 0.0


## Levanta na hora, no mesmo lugar, com calor 0 (o caminho normal sobe em 1,5 s).
func religar() -> void:
	if estado != Estado.DESLIGADO:
		calor = 0.0
		return
	religamentos += 1
	calor = 0.0
	_tempo_sem_tiro = 0.0
	_levantando = false
	_queda = 0.0
	_restante = TEMPO_DESLIGADO
	_fumaca.emitting = false
	_corpo_tiro.set_deferred("collision_layer", 2)
	if _ronco:
		_ronco.play()
	_mudar(Estado.PATRULHA)


func _desligar() -> void:
	_mudar(Estado.DESLIGADO)
	desligamentos += 1
	_restante = TEMPO_DESLIGADO
	_levantando = false
	_tem_alvo = false
	_feixe.visible = false
	_fumaca.emitting = true
	_corpo_tiro.set_deferred("collision_layer", 0)
	_faisca(_cabeca.global_position)
	if _ronco:
		_ronco.stop()
	Som.toque3d(self, "sentinela_desliga", _cabeca.global_position, 0.0, 12.0, 140.0)
	desligou.emit()


func _process(delta: float) -> void:
	if not _pronto or mapa == null:
		return
	_tempo += delta
	if pose_foto >= 0:
		estado = pose_foto
		_queda = 1.0 if estado == Estado.DESLIGADO else 0.0
	else:
		_ler_visao(delta)
		if estado != Estado.DESLIGADO:
			_tempo_sem_tiro += delta
			if _tempo_sem_tiro > ESFRIA_ESPERA and calor > 0.0:
				calor = maxf(0.0, calor - ESFRIA * delta)
		_logica(delta)
	_atualizar_mira(delta)
	_atualizar_projetil(delta)
	if estado != Estado.DESLIGADO:
		_passos(delta)
	_visual_pisca(delta)
	_cabeca_visual(delta)
	_pernas_visual()
	_lente_visual(delta)
	_feixe_visual()
	_mech_visual()
	_fumaca.position = _cabeca.position + Vector3(0.0, 0.3, 0.0)
	_corpo_tiro.position = _cabeca.position
	global_position.y = mapa.altura(global_position.x, global_position.z)


## O corpo animado segue o estado: vira para onde a cabeça olha, anda, atira e cai desligado.
func _mech_visual() -> void:
	if mech == null:
		return
	mech.rotation.y = _yaw_cab
	if estado == Estado.DESLIGADO and not _levantando:
		mech.tocar("Death", 1.0, 0.1)
		mech.apagar(1.0)
		mech.olho(0.0)
		return
	mech.apagar(0.0)
	if estado == Estado.DISPARO:
		mech.tocar("Shoot", 1.0, 0.05)
	elif _andando:
		mech.tocar("Walk", 0.75 if estado == Estado.PATRULHA else 1.3)
	else:
		mech.tocar("Idle", 1.0, 0.8 if _levantando else 0.25)
	mech.clarao(0.8 if _pisca > 0.0 else 0.0)
	mech.olho(clampf(mat_lente.emission_energy_multiplier * 0.2, 0.0, 1.6))


# ---------------------------------------------------------------- percepção e decisão

func _alvo_ok() -> bool:
	return alvo != null and is_instance_valid(alvo)


func _centro_alvo() -> Vector3:
	return alvo.global_position + Vector3.UP * 0.6


## Robô em pane (ou ainda na graça depois da pane): para o Sentinela, ele não existe.
func _em_pane() -> bool:
	if not _alvo_ok():
		return false
	if alvo.get("em_pane") == true:
		return true
	var g = alvo.get("graca_pane")
	return g != null and float(g) > 0.0


func _ler_visao(delta: float) -> void:
	_ve = false
	if not _alvo_ok() or _em_pane():
		_dist_alvo = INF
	else:
		var c := _centro_alvo()
		var de := _lente.global_position
		_dist_alvo = de.distance_to(c)
		_ve = _dist_alvo < VER and _linha_livre(de, c)
	_sem_visao = 0.0 if _ve else _sem_visao + delta


func _linha_livre(de: Vector3, ate: Vector3) -> bool:
	for k in range(1, 9):
		var p := de.lerp(ate, float(k) / 9.0)
		if p.y < mapa.altura(p.x, p.z):
			return false
	return true


func _perdido() -> bool:
	return _dist_alvo > PERDER or _sem_visao > TEMPO_SEM_VISAO


func _logica(delta: float) -> void:
	match estado:
		Estado.PATRULHA:
			if _ve:
				_mudar(Estado.ALERTA)
			else:
				_patrulhar(delta)
		Estado.ALERTA:
			_avancar(delta)
			if _perdido():
				_mudar(Estado.PATRULHA)
			elif _ve and _tempo >= TEMPO_ALERTA and _dist_alvo < ALCANCE_TIRO:
				_mudar(Estado.AVISO)
		Estado.AVISO:
			_andando = false
			if not _ve:
				_mudar(Estado.ALERTA)
			elif _tempo >= TEMPO_AVISO:
				_mudar(Estado.DISPARO)
				_disparar()
				_mudar(Estado.RECARGA)
		Estado.RECARGA:
			_avancar(delta)
			if _tempo >= TEMPO_RECARGA:
				_mudar(Estado.ALERTA if _ve else Estado.PATRULHA)
		Estado.DESLIGADO:
			_desligado(delta)


## Em combate ela não fica mais plantada: entre um tiro e outro anda na direção do robô, até uns 22 m dele
## (parada só para avisar e atirar). Antes ela só andava na patrulha e parecia presa no lugar.
const DIST_COMBATE := 22.0
const VEL_COMBATE := 2.2


func _avancar(delta: float) -> void:
	_andando = false
	if not _alvo_ok() or _dist_alvo < DIST_COMBATE:
		return
	var para := _horiz(_centro_alvo() - global_position)
	if para.length() < 0.5:
		return
	var dir := para.normalized()
	var giro := 1.6 * delta
	rotation.y += clampf(angle_difference(rotation.y, _yaw_de(dir)), -giro, giro)
	if absf(angle_difference(rotation.y, _yaw_de(dir))) < 0.7:
		var novo := global_position + dir * VEL_COMBATE * delta
		if _chao_bom(novo):
			global_position = Vector3(novo.x, mapa.altura(novo.x, novo.z), novo.z)
			_rumo_mov = dir
			_andando = true


func _desligado(delta: float) -> void:
	if not _levantando:
		_queda = move_toward(_queda, 1.0, delta / TEMPO_QUEDA)
		_restante -= delta
		if _restante <= 0.0:
			_levantando = true
	else:
		_queda = move_toward(_queda, 0.0, delta / TEMPO_LEVANTAR)
		if _queda <= 0.0:
			religar()
	if _tempo > TEMPO_FUMACA:
		_fumaca.emitting = false


func _mudar(novo: int) -> void:
	if novo == estado:
		return
	estado = novo
	_tempo = 0.0
	if novo == Estado.AVISO:
		_mira = _centro_alvo() if _alvo_ok() else _mira
	if novo == Estado.PATRULHA:
		_tem_alvo = false
		_andando = false
		_pat_pausa = _rng.randf_range(1.0, 3.0)


# ---------------------------------------------------------------- patrulha

func _patrulhar(delta: float) -> void:
	if not _tem_alvo:
		_andando = false
		_pat_pausa -= delta
		_olhar_t -= delta
		if _olhar_t <= 0.0:
			_olhar_yaw = _rng.randf_range(-2.2, 2.2)
			_olhar_t = _rng.randf_range(2.0, 3.0)
		if _pat_pausa <= 0.0:
			_escolher_alvo_patrulha()
		return
	var para := Vector3(_pat_alvo.x - global_position.x, 0.0, _pat_alvo.z - global_position.z)
	if para.length() < 0.5:
		_tem_alvo = false
		_andando = false
		_pat_pausa = _rng.randf_range(2.0, 5.0)
		_olhar_t = 0.0
		return
	var dir := para.normalized()
	var giro := 1.2 * delta
	rotation.y += clampf(angle_difference(rotation.y, _yaw_de(dir)), -giro, giro)
	_andando = false
	var erro := absf(angle_difference(rotation.y, _yaw_de(dir)))
	# o passo só anda quando as pernas estão perto do repouso (a marcha de um pé por vez limita a velocidade)
	# (com o corpo de duas pernas ele anda sem parar; a espera pelo passo do tripé o deixava preso no lugar)
	if erro < 0.6:
		var novo := global_position + dir * VEL_ANDAR * delta
		if _chao_bom(novo):
			global_position = Vector3(novo.x, mapa.altura(novo.x, novo.z), novo.z)
			_rumo_mov = dir
			_andando = true
		else:
			_tem_alvo = false
			_pat_pausa = 0.2


func _escolher_alvo_patrulha() -> void:
	for k in 40:
		var ang := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * raio_patrulha
		var p := Vector3(casa.x + cos(ang) * r, 0.0, casa.z + sin(ang) * r)
		p.y = mapa.altura(p.x, p.z)
		if _chao_bom(p):
			_pat_alvo = p
			_tem_alvo = true
			return
	_pat_pausa = _rng.randf_range(2.0, 5.0)


func _chao_bom(p: Vector3) -> bool:
	return mapa.agua(p.x, p.z) == -INF and mapa.normal_em(p.x, p.z).y > 0.8


func _yaw_de(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _horiz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ---------------------------------------------------------------- pernas

func _repouso_w(i: int) -> Vector3:
	var ang: float = ANG_PERNAS[i]
	var w := global_position + global_basis * Vector3(cos(ang) * PE_FORA, 0.0, sin(ang) * PE_FORA)
	w.y = mapa.altura(w.x, w.z)
	return w


func _atraso_max() -> float:
	var m := 0.0
	for i in 3:
		m = maxf(m, _horiz(_repouso_w(i) - _pe_w[i]).length())
	return m


## Os pés ficam plantados no mundo. Quando o repouso de um pé se afasta mais de PASSO × 0,5 do pé plantado,
## esse pé dá um passo (arco de ALTURA_PASSO) até o repouso adiantado na direção do movimento. Um pé de cada vez.
func _passos(delta: float) -> void:
	if _passo_i < 0:
		var pior := PASSO * 0.5
		var escolhido := -1
		for i in 3:
			var d := _horiz(_repouso_w(i) - _pe_w[i]).length()
			if d > pior:
				pior = d
				escolhido = i
		if escolhido < 0:
			return
		_passo_i = escolhido
		_passo_t = 0.0
		_passo_de = _pe_w[escolhido]
		var r := _repouso_w(escolhido)
		var adiante := _rumo_mov
		if adiante.length() < 0.01:
			adiante = _horiz(r - global_position).normalized()
		var ate := r + adiante * PASSO * 0.5
		ate.y = mapa.altura(ate.x, ate.z)
		if not _chao_bom(ate):
			ate = r
		_passo_ate = ate
	_passo_t += delta / DURACAO_PASSO
	var s := clampf(_passo_t, 0.0, 1.0)
	var e := s * s * (3.0 - 2.0 * s)
	var p := _passo_de.lerp(_passo_ate, e)
	p.y += ALTURA_PASSO * sin(s * PI)
	_pe_w[_passo_i] = p
	if _passo_t >= 1.0:
		_pe_w[_passo_i] = _passo_ate
		Som.toque3d(self, "sentinela_passo", _passo_ate, -4.0, 10.0, 110.0)
		_passo_i = -1


## IK de dois segmentos (coxa e canela), em coordenadas locais. O joelho fica para fora e para cima.
func _ik(h: Vector3, f: Vector3, fora: Vector3) -> Array:
	var v := f - h
	var d := v.length()
	var dir := v / d if d > 0.0001 else Vector3.DOWN
	d = clampf(d, absf(COXA - CANELA) + 0.02, COXA + CANELA - 0.02)
	var cos_a := clampf((COXA * COXA + d * d - CANELA * CANELA) / (2.0 * COXA * d), -1.0, 1.0)
	var sen_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var polo := fora + Vector3.UP
	var pv := polo - dir * polo.dot(dir)
	if pv.length() < 0.001:
		pv = fora - dir * fora.dot(dir)
	if pv.length() < 0.001:
		pv = Vector3.FORWARD
	pv = pv.normalized()
	var k := h + dir * (COXA * cos_a) + pv * (COXA * sen_a)
	var fe := h + dir * d
	return [k, fe]


func _orientar(mi: MeshInstance3D, origem: Vector3, destino: Vector3, comp: float) -> void:
	var y := destino - origem
	if y.length() < 0.0001:
		y = Vector3.DOWN
	y = y.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y * comp, z), origem)


func _pernas_visual() -> void:
	var quadril_y := _cab_y - QUADRIL_QUEDA
	for i in 3:
		var ang: float = ANG_PERNAS[i]
		var fora := Vector3(cos(ang), 0.0, sin(ang))
		var h := Vector3(fora.x * QUADRIL_RAIO, quadril_y, fora.z * QUADRIL_RAIO)
		var f := to_local(_pe_w[i])
		var r := _ik(h, f, fora)
		var k: Vector3 = r[0]
		var fe: Vector3 = r[1]
		_orientar(_coxas[i], h, k, COXA)
		_orientar(_canelas[i], k, fe, CANELA)
		_joelhos[i].position = k
		_pes[i].position = fe


# ---------------------------------------------------------------- cabeça, lente, feixe, calor

func _angulos_para(p: Vector3) -> Vector2:
	var d := to_local(p) - _cabeca.position
	var yaw := atan2(-d.x, -d.z)
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.7, 0.7)
	return Vector2(yaw, pitch)


func _cabeca_visual(delta: float) -> void:
	var altura_normal := (_pe_w[0].y + _pe_w[1].y + _pe_w[2].y) / 3.0 + ALTURA_CABECA - global_position.y
	var s := _queda * _queda * (3.0 - 2.0 * _queda)
	_cab_y = lerpf(altura_normal, ALTURA_CAIDA, s)
	_balanco = lerpf(_balanco, 1.0 if _andando else 0.0, 1.0 - exp(-5.0 * delta))
	_fase_andar = fmod(_fase_andar + delta * 5.5, TAU)
	var bob := Vector3(sin(_fase_andar) * 0.03 * _balanco, absf(sin(_fase_andar * 2.0)) * 0.03 * _balanco, 0.0)
	_cabeca.position = Vector3(0.0, _cab_y, 0.0) + bob

	var alvo_yaw := _yaw_cab
	var alvo_pitch := _pitch_cab
	if estado == Estado.PATRULHA:
		alvo_yaw = 0.0 if _andando else _olhar_yaw
		alvo_pitch = 0.0
	elif estado != Estado.DESLIGADO and _alvo_ok():
		var p := _mira if (estado == Estado.AVISO or estado == Estado.DISPARO) else _centro_alvo()
		var ang := _angulos_para(p)
		alvo_yaw = ang.x
		alvo_pitch = ang.y
	var passo := VEL_CABECA * delta
	_yaw_cab += clampf(angle_difference(_yaw_cab, alvo_yaw), -passo, passo)
	_pitch_cab += clampf(alvo_pitch - _pitch_cab, -passo, passo)
	_empurrao = maxf(0.0, _empurrao - delta * 6.0)
	_cabeca.rotation = Vector3(_pitch_cab - 0.25 * _empurrao, _yaw_cab, 0.35 * s)


func _lente_visual(delta: float) -> void:
	var e := 0.0
	match estado:
		Estado.PATRULHA:
			e = 1.0
		Estado.ALERTA:
			e = 3.0
		Estado.AVISO:
			var f := clampf(_tempo / TEMPO_AVISO, 0.0, 1.0)
			_fase_lente = fmod(_fase_lente + delta * lerpf(2.0, 14.0, f) * TAU, TAU)
			var ligada := 0.5 + 0.5 * sin(_fase_lente)
			e = lerpf(2.0, 8.0, f) * (0.25 + 0.75 * ligada)
		Estado.DISPARO:
			e = 8.0
		_:
			e = 0.0
	mat_lente.emission_energy_multiplier = e
	# o material não recebe luz: a cor acompanha a energia (apagada = quase preta, forte = clara)
	var cor := Color(0.05, 0.03, 0.03).lerp(Color(1.0, 0.12, 0.08), clampf(e * 1.4, 0.0, 1.0))
	mat_lente.albedo_color = cor.lerp(Color(1.0, 0.62, 0.5), clampf((e - 3.0) / 5.0, 0.0, 1.0))


func _atualizar_mira(delta: float) -> void:
	if not _alvo_ok():
		return
	if estado == Estado.AVISO:
		if _tempo < TEMPO_AVISO - TEMPO_TRAVA:
			_mira = _mira.lerp(_centro_alvo(), 1.0 - exp(-3.0 * delta))
	elif estado == Estado.ALERTA or estado == Estado.RECARGA:
		_mira = _centro_alvo()


func _feixe_visual() -> void:
	var mostra := estado == Estado.AVISO and _alvo_ok()
	_feixe.visible = mostra
	if mostra:
		var de := _lente.global_position
		var v := _mira - de
		var len := v.length()
		if len < 0.1:
			_feixe.visible = false
		else:
			var y := v / len
			var x := y.cross(Vector3.UP)
			if x.length() < 0.001:
				x = Vector3.RIGHT
			x = x.normalized()
			var z := x.cross(y)
			_feixe.transform = Transform3D(Basis(x, y * len, z), (de + _mira) * 0.5)
	_luz_calor.position = _cabeca.position + Vector3(0.0, 0.0, -0.5)
	_luz_calor.light_energy = 0.8 * calor / 100.0 if estado != Estado.DESLIGADO else 0.0


func _visual_pisca(delta: float) -> void:
	var antes := _pisca > 0.0
	_pisca = maxf(0.0, _pisca - delta)
	if antes or _pisca > 0.0:
		var mat: Material = _mat_pisca if _pisca > 0.0 else null
		for m in _malhas_cabeca:
			m.material_overlay = mat


# ---------------------------------------------------------------- tiro

func _disparar() -> void:
	disparos += 1
	var origem := _lente.global_position
	var destino := _mira
	disparou.emit(origem, destino)
	Som.toque3d(self, "tiro_sentinela", origem, 0.0, 14.0, 160.0)
	_clarao(origem, 0.12)
	_projetil_iniciar(origem, destino)


func _projetil_iniciar(origem: Vector3, destino: Vector3) -> void:
	if _proj_no != null and is_instance_valid(_proj_no):
		_proj_no.queue_free()
	_proj_no = Node3D.new()
	_proj_no.top_level = true
	add_child(_proj_no)
	var mi := MeshInstance3D.new()
	mi.mesh = _malha_projetil
	mi.material_override = _mat_projetil
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_proj_no.add_child(mi)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.35, 0.12)
	luz.light_energy = 3.0
	luz.omni_range = 5.0
	luz.shadow_enabled = false
	_proj_no.add_child(luz)
	_proj_pos = origem
	_proj_no.position = origem
	var v := destino - origem
	_proj_dir = v.normalized() if v.length() > 0.01 else -global_basis.z
	_proj_viajado = 0.0
	_proj_ativo = true


## O projétil segue em linha reta pelo ponto travado, até bater no chão, andar 90 m ou passar perto do robô.
func _atualizar_projetil(delta: float) -> void:
	if not _proj_ativo:
		return
	var passo := VEL_PROJETIL * delta
	_proj_pos += _proj_dir * passo
	_proj_viajado += passo
	_proj_no.position = _proj_pos
	var fim := _proj_viajado >= 90.0 or _proj_pos.y < mapa.altura(_proj_pos.x, _proj_pos.z)
	if not fim and _alvo_ok() and _proj_pos.distance_to(_centro_alvo()) < RAIO_GOLPE:
		fim = true
	if fim:
		_estourar()


func _estourar() -> void:
	var ponto := _proj_pos
	_proj_ativo = false
	if _proj_no != null and is_instance_valid(_proj_no):
		_proj_no.queue_free()
	_proj_no = null
	_faisca(ponto)
	_clarao_impacto(ponto)
	if _alvo_ok() and ponto.distance_to(_centro_alvo()) < RAIO_GOLPE:
		alvo.levar_golpe(_proj_dir, FORCA_GOLPE)


func _faisca(ponto: Vector3) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color(1.0, 0.6, 0.25)
	var pt := GPUParticles3D.new()
	pt.process_material = pm
	pt.draw_pass_1 = _malha_faisca
	pt.amount = 14
	pt.lifetime = 0.4
	pt.one_shot = true
	pt.explosiveness = 1.0
	pt.emitting = false
	pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pt)
	pt.global_position = ponto
	pt.emitting = true
	get_tree().create_timer(0.8).timeout.connect(pt.queue_free)


func _clarao_impacto(ponto: Vector3) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.55, 0.2)
	luz.light_energy = 3.0
	luz.omni_range = 6.0
	add_child(luz)
	luz.global_position = ponto
	get_tree().create_timer(0.15).timeout.connect(luz.queue_free)


func _clarao(ponto: Vector3, duracao: float) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.3, 0.15)
	luz.light_energy = 4.0
	luz.omni_range = 5.0
	add_child(luz)
	luz.global_position = ponto
	get_tree().create_timer(duracao).timeout.connect(luz.queue_free)
