class_name Tiro
extends Node3D
## Os jatos da mão do robô, que também são a arma. Com a ação "atirar" (R2 / botão esquerdo) e o robô
## mirando no chão ou pairando, cada disparo esquenta o motor, acende os jatos, dá um tranco na câmera,
## lança um projétil de luz da mão direita até o ponto em que a mira bate e faz faísca no impacto.
## Os bichos do grupo "bichos" fogem do robô no disparo e do ponto de impacto.
## Uso: Tiro.new(), defina armadura (já com ilha e câmera), e só então add_child.

signal disparou(origem: Vector3, alvo: Vector3)

const CADENCIA := 0.28  # s entre disparos
const CALOR_POR_TIRO := 3.5
const ALCANCE := 220.0
const VELOCIDADE := 85.0  # m/s do projétil
const TRAVA_ANGULO := deg_to_rad(6.5)  # mirando, a máquina a menos disso do centro da mira fica travada
const TRAVA_SEGURA := 1.6  # a travada continua travada até este tanto do ângulo (não fica trocando)
const TRAVA_ALCANCE := 130.0

var armadura: Armadura
var disparos := 0
var travado: Node3D  # a máquina em que a mira travou (null: nenhuma); a tela desenha o colchete nela

var _espera := 0.0
var _mat_projetil: StandardMaterial3D
var _mat_faisca: StandardMaterial3D
var _malha_projetil: CapsuleMesh
var _malha_faisca: SphereMesh


func _ready() -> void:
	_mat_projetil = StandardMaterial3D.new()
	_mat_projetil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_projetil.albedo_color = Color(1.0, 0.8, 0.5)
	_mat_projetil.emission_enabled = true
	_mat_projetil.emission = Color(1.0, 0.55, 0.2)
	_mat_projetil.emission_energy_multiplier = 4.0
	_malha_projetil = CapsuleMesh.new()
	_malha_projetil.radius = 0.12
	_malha_projetil.height = 1.8
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


func _physics_process(delta: float) -> void:
	_espera = maxf(0.0, _espera - delta)
	if armadura == null or not is_instance_valid(armadura):
		return
	_atualizar_trava()
	if not Input.is_action_pressed("atirar"):
		return
	# no chão atira mirando ou não; no ar, só no voo parado (voando ou caindo, não)
	var e := armadura.estado
	if armadura.em_pane or (e != Armadura.Estado.CHAO and e != Armadura.Estado.PAIRAR):
		return
	if armadura.superaquecido or _espera > 0.0:
		return
	_espera = CADENCIA
	armadura.atirando = 0.6
	_disparar()


func _disparar() -> void:
	disparos += 1
	armadura.calor = minf(100.0, armadura.calor + CALOR_POR_TIRO)
	armadura.clarao_tiro = 1.0  # só o jato da mão que dispara acende (não os dos pés)
	armadura.tremor = maxf(armadura.tremor, 0.12)

	var origem := _mao()
	var guiado := travado != null and is_instance_valid(travado)
	var impacto: Vector3 = travado.call("ponto_de_trava") if guiado else _ponto_de_impacto()
	if not impacto.is_finite():
		guiado = false
		impacto = _ponto_de_impacto()
	disparou.emit(origem, impacto)
	get_tree().call_group("bichos", "assustar", armadura.global_position)

	_clarao(origem, 0.08)
	_projetil(origem, impacto, travado if guiado else null)


## Ajuda de mira: mirando (L2), a máquina ligada mais perto do centro da mira, dentro de um cone pequeno e
## com a vista livre, fica travada; os tiros seguem ela. Sem mirar não há trava.
func _atualizar_trava() -> void:
	var cam := armadura.camera
	if cam == null or not armadura.mirando_agora() or armadura.em_pane:
		travado = null
		return
	var de := cam.global_position
	var dir := cam.mira()
	var melhor: Node3D = null
	var menor := INF
	var espaco := get_world_3d().direct_space_state
	for n in get_tree().get_nodes_in_group("maquinas"):
		if not n.has_method("ponto_de_trava"):
			continue
		var p: Vector3 = n.call("ponto_de_trava")
		if not p.is_finite():
			continue
		var d := p - de
		var dist := d.length()
		if dist > TRAVA_ALCANCE or dist < 1.0:
			continue
		var ang := dir.angle_to(d)
		# de perto o cone abre um pouco (a máquina ocupa mais da tela)
		var limite := maxf(TRAVA_ANGULO, atan(1.2 / dist)) * (TRAVA_SEGURA if n == travado else 1.0)
		if ang > limite or ang >= menor:
			continue
		var q := PhysicsRayQueryParameters3D.create(de, p, 1, [armadura.get_rid()])
		var hit := espaco.intersect_ray(q)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(p) > 1.6:
			continue  # tem morro ou pedra na frente
		melhor = n
		menor = ang
	travado = melhor


## Onde a mira bate: um raio da câmera, sem acertar o próprio robô; sem acerto, fica a ALCANCE.
func _ponto_de_impacto() -> Vector3:
	var cam := armadura.camera
	var de: Vector3
	var dir: Vector3
	if cam != null:
		de = cam.global_position
		dir = cam.mira()
	else:
		de = armadura.global_position
		dir = -armadura.global_basis.z
	var ate := de + dir * ALCANCE
	var q := PhysicsRayQueryParameters3D.create(de, ate, 1 | 2, [armadura.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ate
	return hit["position"]


## Ponta da mão direita: o osso do punho quando o modelo tem a junta, senão um ponto acima do robô.
func _mao() -> Vector3:
	var v = armadura.visual
	if v != null and v.j is Dictionary:
		var punho = v.j.get("punhoD")
		if punho is Node3D and is_instance_valid(punho):
			return (punho as Node3D).global_position
	return armadura.global_position + Vector3(0.0, 0.6, 0.0)


func _projetil(origem: Vector3, impacto: Vector3, guia: Node3D = null) -> void:
	var proj := Node3D.new()
	add_child(proj)
	proj.global_position = origem
	var cabeca := Vector3.UP if absf((impacto - origem).normalized().dot(Vector3.UP)) < 0.99 else Vector3.BACK
	if impacto.distance_to(origem) > 0.01:
		proj.look_at(impacto, cabeca)
	var mi := MeshInstance3D.new()
	mi.mesh = _malha_projetil
	mi.material_override = _mat_projetil
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.x = PI / 2.0  # a cápsula fica no eixo -Z do nó, que aponta ao alvo
	proj.add_child(mi)
	var tempo := maxf(0.02, origem.distance_to(impacto) / VELOCIDADE)
	var tw := proj.create_tween()
	if guia == null:
		tw.tween_property(proj, "global_position", impacto, tempo)
		tw.tween_callback(_impacto.bind(impacto))
	else:
		# tiro travado: o destino acompanha a máquina até chegar
		var destino := [impacto]
		var passo := func(k: float) -> void:
			if is_instance_valid(guia):
				var p: Vector3 = guia.call("ponto_de_trava")
				if p.is_finite():
					destino[0] = p
			var onde := origem.lerp(destino[0], k)
			if onde.distance_to(destino[0]) > 0.05:
				proj.look_at_from_position(onde, destino[0], cabeca)
			else:
				proj.global_position = onde
		tw.tween_method(passo, 0.0, 1.0, tempo)
		tw.tween_callback(func() -> void: _impacto(destino[0]))
	tw.tween_callback(proj.queue_free)


func _impacto(ponto: Vector3) -> void:
	_estrela(ponto)
	get_tree().call_group("bichos", "assustar", ponto)
	get_tree().call_group("maquinas", "levar_tiro", ponto)
	_faisca(ponto)
	_clarao_impacto(ponto)


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
	var tw := luz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.15)
	tw.tween_callback(luz.queue_free)


func _clarao(ponto: Vector3, duracao: float) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.3)
	luz.light_energy = 1.5
	luz.omni_range = 2.5
	add_child(luz)
	luz.global_position = ponto
	get_tree().create_timer(duracao).timeout.connect(luz.queue_free)


## Brilho em estrela no impacto (textura do Kenney Particle Pack, CC0): cresce e some.
func _estrela(ponto: Vector3) -> void:
	if not ResourceLoader.exists("res://assets/fx/kenney/star_06.png"):
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.albedo_texture = load("res://assets/fx/kenney/star_06.png")
	mat.albedo_color = Color(1.0, 0.72, 0.4, 1.0)
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = ponto
	mi.scale = Vector3.ONE * 0.6
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 2.6, 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(mi.queue_free)
