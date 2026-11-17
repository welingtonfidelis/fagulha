class_name MaquinaPequena
extends Node3D
## A base das máquinas do vale (hoje só as mechas): a lente
## vermelha, o calor que sobe a cada tiro do robô e desliga a máquina, a fumaça de desligada e o tempo
## até religar. Ninguém é destruído: desligam, ficam um tempo paradas e religam no mesmo lugar.
## O mergulho com impacto do robô por perto desliga na hora.
## Uso: defina mapa, alvo, casa e semente, e só então add_child.

signal desligou

const ESFRIA := 6.0  # calor perdido por segundo
const ESFRIA_ESPERA := 2.5
const TEMPO_DESLIGADA := 900.0  # 15 minutos reais de paz
const RAIO_IMPACTO := 8.0

var mapa: Ilha
var alvo: Armadura
var casa := Vector3.ZERO
var semente := 0
var calor := 0.0
var desligada := false
var desligamentos := 0
var religamentos := 0
var golpes_dados := 0
var mat_lente := StandardMaterial3D.new()

var _rng := RandomNumberGenerator.new()
var _corpo: Node3D  # o visual inteiro
var _acerto: StaticBody3D
var _fumaca: GPUParticles3D
var _pisca := 0.0
var _sem_tiro := 99.0
var _restante := 0.0
var _relogio := 0.0
var _ronco: AudioStreamPlayer3D
var mech: MechVisual  # o corpo animado (um dos robôs do pacote)
var _tiros: Array[Dictionary] = []
## Os projéteis das máquinas, por tipo de arma. vel em m/s; raio é a distância do robô que conta como acerto;
## dano é quanto de um acerto ele vale (três acertos inteiros desligam o robô); guia é quanto o míssil vira
## por segundo (rad); estouro é o raio da explosão.
const TIROS := {
	"bala": {"vel": 95.0, "raio": 0.85, "forca": 2.0, "dano": 0.34, "alcance": 140.0, "som": "tiro_1", "db": -7.0},
	"pesado": {"vel": 62.0, "raio": 1.0, "forca": 5.0, "dano": 0.67, "alcance": 160.0, "som": "tiro_sentinela", "db": -6.0},
	"missil": {"vel": 27.0, "raio": 1.3, "forca": 8.0, "dano": 1.0, "alcance": 190.0, "som": "tiro_zangao_2", "db": -3.0, "guia": 1.5, "estouro": 3.2},
}
var paradas := 0  # projéteis que pararam em tronco, rocha ou parede (testes)
static var tiros_dados := {}  # tipo -> quantos saíram (testes)
static var _malhas_tiro := {}
static var _mats_tiro := {}


func calor_por_tiro() -> float:
	return 50.0


func raio_acerto() -> float:
	return 0.6


## Nome do laço de som do motor (vazio: sem som).
func som_motor() -> String:
	return ""


func centro() -> Vector3:
	return _corpo.global_position if _corpo else global_position


func _montar_base() -> void:
	add_to_group("maquinas")
	_rng.seed = semente * 6151 + 17
	_corpo = Node3D.new()
	add_child(_corpo)
	mat_lente.albedo_color = Color(1.0, 0.12, 0.08)
	mat_lente.emission_enabled = true
	mat_lente.emission = Color(1.0, 0.1, 0.05)
	mat_lente.emission_energy_multiplier = 1.0
	_acerto = StaticBody3D.new()
	_acerto.collision_layer = 2
	_acerto.collision_mask = 0
	_corpo.add_child(_acerto)
	var cs := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = raio_acerto() * 0.8
	cs.shape = esfera
	_acerto.add_child(cs)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.color = Color(0.25, 0.25, 0.27, 0.5)
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.vertex_color_use_as_albedo = true
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	quad.material = mf
	_fumaca = GPUParticles3D.new()
	_fumaca.process_material = pm
	_fumaca.draw_pass_1 = quad
	_fumaca.amount = 10
	_fumaca.lifetime = 2.2
	_fumaca.emitting = false
	_fumaca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corpo.add_child(_fumaca)
	if som_motor() != "":
		_ronco = Som.laco3d(_corpo, som_motor(), -6.0, 4.0, 40.0)


## A arte dos projéteis é simples de propósito (passam depressa): a bala é um risco claro, o tiro pesado um
## caroço laranja comprido, e o míssil um cilindro com ponta e uma chama atrás.
static func _arte_tiro(tipo: String) -> Node3D:
	if _mats_tiro.is_empty():
		for par: Array in [["bala", Color(1.0, 0.92, 0.6)], ["pesado", Color(1.0, 0.55, 0.2)], ["chama", Color(1.0, 0.7, 0.3)]]:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = par[1]
			_mats_tiro[par[0]] = m
		var casco := StandardMaterial3D.new()
		casco.albedo_color = Color(0.75, 0.76, 0.78)
		casco.roughness = 0.6
		_mats_tiro["casco"] = casco
		var ponta := StandardMaterial3D.new()
		ponta.albedo_color = Color(0.8, 0.2, 0.12)
		_mats_tiro["ponta"] = ponta
		var risco := CapsuleMesh.new()
		risco.radius = 0.035
		risco.height = 1.3
		risco.radial_segments = 6
		risco.rings = 2
		_malhas_tiro["bala"] = risco
		var caroco := CapsuleMesh.new()
		caroco.radius = 0.1
		caroco.height = 0.7
		caroco.radial_segments = 8
		caroco.rings = 3
		_malhas_tiro["pesado"] = caroco
		var corpo := CylinderMesh.new()
		corpo.top_radius = 0.07
		corpo.bottom_radius = 0.07
		corpo.height = 0.6
		corpo.radial_segments = 8
		_malhas_tiro["corpo"] = corpo
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.07
		cone.height = 0.2
		cone.radial_segments = 8
		_malhas_tiro["cone"] = cone
		var chama := CylinderMesh.new()
		chama.top_radius = 0.05
		chama.bottom_radius = 0.0
		chama.height = 0.45
		chama.radial_segments = 6
		_malhas_tiro["chama"] = chama
	var no := Node3D.new()
	# o brilho vem das imagens do pacote de partículas: rastro comprido na bala, bola de fogo no tiro pesado, e
	# chama e fumaça atrás do míssil
	if tipo == "bala":
		no.add_child(EfeitosTiro.cruzado("trace_06", Color(1.0, 0.93, 0.6), 0.4, 3.2, 0.9, false))
	elif tipo == "pesado":
		no.add_child(EfeitosTiro.cruzado("trace_06", Color(1.0, 0.6, 0.2), 0.7, 3.0, 1.0, false))
		no.add_child(EfeitosTiro.cruzado("muzzle_04", Color(1.0, 0.75, 0.3), 0.5, 0.9, 0.1, false))
	else:
		no.add_child(EfeitosTiro.cruzado("muzzle_04", Color(1.0, 0.75, 0.35), 0.4, 1.0, 0.75, false))
		EfeitosTiro.rastro_fumaca(no)
	var pecas: Array = [["bala", "bala", 0.0]] if tipo == "bala" else ([["pesado", "pesado", 0.0]] if tipo == "pesado"
		else [["corpo", "casco", 0.0], ["cone", "ponta", -0.4]])
	for pc: Array in pecas:
		var mi := MeshInstance3D.new()
		mi.mesh = _malhas_tiro[pc[0]]
		mi.material_override = _mats_tiro[pc[1]]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.x = -PI / 2.0  # o comprido da peça fica no -Z do nó, que aponta para onde ele voa
		mi.position.z = pc[2]
		no.add_child(mi)
	if tipo != "bala":
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.45, 0.15)
		luz.light_energy = 1.4
		luz.omni_range = 3.5
		luz.shadow_enabled = false
		no.add_child(luz)
	return no


## Dispara um projétil do tipo dado de `de` para `para`, com um erro de mira de até `espalha` radianos.
func atirar_em(de: Vector3, para: Vector3, tipo := "bala", espalha := 0.0) -> void:
	var t: Dictionary = TIROS[tipo]
	var dir := (para - de).normalized()
	if espalha > 0.0:
		var lado := dir.cross(Vector3.UP).normalized()
		var cima := lado.cross(dir).normalized()
		dir = (dir + lado * randf_range(-espalha, espalha) + cima * randf_range(-espalha, espalha)).normalized()
	if tipo == "missil":
		dir = (dir + Vector3.UP * 0.35).normalized()  # o míssil sai para cima e depois vira para o alvo
	Som.toque3d(self, t["som"], de, t["db"], 10.0, 120.0)
	EfeitosTiro.clarao(self, de, dir, {"bala": 0.8, "pesado": 1.3, "missil": 1.1}[tipo])
	tiros_dados[tipo] = int(tiros_dados.get(tipo, 0)) + 1
	var no := _arte_tiro(tipo)
	no.top_level = true
	add_child(no)
	no.global_position = de
	_tiros.append({"no": no, "pos": de, "dir": dir, "andou": 0.0, "tipo": tipo})


func atualizar_tiros(delta: float) -> void:
	var i := _tiros.size() - 1
	var tem_alvo := alvo != null and is_instance_valid(alvo) and not alvo.em_pane
	while i >= 0:
		var pr := _tiros[i]
		var t: Dictionary = TIROS[pr["tipo"]]
		var dir: Vector3 = pr["dir"]
		var de: Vector3 = pr["pos"]
		if t.has("guia") and tem_alvo:
			# o míssil vira para o robô aos poucos: dá para escapar correndo de lado ou voando
			dir = Armadura.girar_para(dir, (centro_alvo() - de).normalized(), float(t["guia"]) * delta)
			pr["dir"] = dir
		var passo := float(t["vel"]) * delta
		var p := de + dir * passo
		pr["pos"] = p
		pr["andou"] = float(pr["andou"]) + passo
		var no: Node3D = pr["no"]
		no.look_at_from_position(p, p + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT)
		var fim := float(pr["andou"]) > float(t["alcance"])
		var bateu_chao := p.y < mapa.altura(p.x, p.z)
		# tronco, copa, rocha, ruína ou parede no trecho andado: o projétil para ali
		var qr := PhysicsRayQueryParameters3D.create(de, p, 1 | 2, [_acerto.get_rid()] if _acerto else [])
		var bateu := get_world_3d().direct_space_state.intersect_ray(qr)
		var parou := false
		if not bateu.is_empty():
			p = bateu["position"]
			passo = de.distance_to(p)
			bateu_chao = true
			parou = true
			paradas += 1
		var acertou := false
		if tem_alvo:
			# o projétil rápido anda mais de um metro por quadro: conta o ponto mais perto do trecho andado
			var c := centro_alvo()
			var perto := de + dir * clampf((c - de).dot(dir), 0.0, passo)
			acertou = perto.distance_to(c) < float(t["raio"])
			if acertou and parou and (c - de).dot(dir) > passo + 0.3:
				acertou = false  # o robô está atrás do que parou o projétil
		if acertou or bateu_chao or fim:
			if t.has("estouro") and (acertou or bateu_chao):
				_estouro(p, float(t["estouro"]))
				if tem_alvo and p.distance_to(centro_alvo()) < float(t["estouro"]):
					acertou = true
			if acertou and tem_alvo:
				alvo.levar_golpe(dir, t["forca"], t["dano"])
				golpes_dados += 1
			if not t.has("estouro") and (acertou or bateu_chao):
				EfeitosTiro.impacto(self, p, 1.4 if pr["tipo"] == "pesado" else 1.0)
			no.queue_free()
			_tiros.remove_at(i)
		i -= 1


## A explosão do míssil: o som e o efeito (fogo, faíscas e fumaça).
func _estouro(onde: Vector3, raio: float) -> void:
	Som.toque3d(self, Som.variacao("impacto", 3), onde, 0.0, 14.0, 160.0)
	EfeitosTiro.explosao(self, onde, raio)


func material(nome: String) -> Material:
	return (mapa as Clareira).material(nome) if mapa is Clareira else null


func peca(malha: Mesh, mat: Material, pos: Vector3, pai: Node3D = null, giro := Vector3.ZERO, escala := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.position = pos
	mi.rotation = giro
	mi.scale = escala
	(pai if pai else _corpo).add_child(mi)
	return mi


func bola(raio: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = raio
	m.height = raio * 2.0
	m.radial_segments = 14
	m.rings = 7
	return m


func caixa(tam: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = tam
	return m


## O topo da copa mais alta em volta do ponto (-INF sem árvore por perto): quem voa passa por cima.
func topo_copas(p: Vector3, folga := 2.5) -> float:
	var topo := -INF
	var cel := Vector2i(floori(p.x / Ilha.CELULA_ARVORE), floori(p.z / Ilha.CELULA_ARVORE))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c := cel + Vector2i(dx, dz)
			if not mapa._grade_arv.has(c):
				continue
			for i: int in mapa._grade_arv[c]:
				var base: Vector3 = mapa.arv_pos[i]
				var s: float = mapa.arv_escala[i]
				var folhosa: bool = mapa.arv_tipo[i] == 1
				var rh := (5.2 if folhosa else 2.8) * s + folga
				if Vector2(p.x - base.x, p.z - base.z).length_squared() < rh * rh:
					topo = maxf(topo, base.y + (7.5 + (4.3 if folhosa else 6.5)) * s)
	return topo


func alvo_visivel(alcance: float, de: Vector3) -> bool:
	if alvo == null or not is_instance_valid(alvo) or alvo.em_pane or alvo.graca_pane > 0.0:
		return false
	var c := centro_alvo()
	if de.distance_to(c) > alcance:
		return false
	for k in range(1, 7):
		var p := de.lerp(c, float(k) / 7.0)
		if p.y < mapa.altura(p.x, p.z):
			return false
	# rocha, ruína ou parede no caminho também tapam a vista (as árvores não: atrás delas o tiro é que para)
	if is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(de, c, 1)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return false
	return true


## Onde a mira do robô trava (Vector3.INF: não é alvo agora).
func ponto_de_trava() -> Vector3:
	return Vector3.INF if (desligada or _corpo == null) else centro()


func centro_alvo() -> Vector3:
	return alvo.global_position + Vector3.UP * 0.6


## Um tiro do robô perto do corpo: esquenta e pisca. Com calor 100, desliga.
func levar_tiro(ponto: Vector3) -> void:
	if _corpo == null or desligada or ponto.distance_to(centro()) > raio_acerto():
		return
	calor = minf(100.0, calor + calor_por_tiro())
	_sem_tiro = 0.0
	_pisca = 0.12
	Som.toque3d(self, Som.variacao("impacto", 3), ponto, -4.0)
	_provocada()
	if calor >= 100.0:
		desligar()


## O mergulho com impacto do robô: quem está perto desliga na hora.
func levar_impacto(ponto: Vector3) -> void:
	if _corpo == null or desligada or ponto.distance_to(centro()) > RAIO_IMPACTO:
		return
	calor = 100.0
	desligar()


func _provocada() -> void:
	pass


func desligar() -> void:
	desligada = true
	desligamentos += 1
	_restante = TEMPO_DESLIGADA
	_fumaca.emitting = true
	_acerto.set_deferred("collision_layer", 0)
	if _ronco:
		_ronco.stop()
	Som.toque3d(self, "maquina_desliga", centro(), -3.0)
	if mech:
		mech.tocar("Death", 1.0, 0.1)
		mech.apagar(1.0)
		mech.olho(0.0)
	desligou.emit()


func religar() -> void:
	calor = 0.0
	if not desligada:
		return
	desligada = false
	religamentos += 1
	_fumaca.emitting = false
	_acerto.set_deferred("collision_layer", 2)
	if _ronco:
		_ronco.play()
	if mech:
		mech.apagar(0.0)
		mech.tocar("Idle", 1.0, 0.6)


func avancar_tempo(segundos: float) -> void:
	if desligada:
		_restante -= segundos
		if _restante <= 0.0:
			religar()
	else:
		calor = 0.0


## Calor, pisca e o tempo de desligada. Devolve true enquanto estiver desligada.
func _passo_base(delta: float) -> bool:
	_relogio += delta
	_pisca = maxf(0.0, _pisca - delta)
	if desligada:
		_restante -= delta
		mat_lente.emission_energy_multiplier = 0.02
		if _restante <= 0.0:
			religar()
		return true
	_sem_tiro += delta
	if _sem_tiro > ESFRIA_ESPERA:
		calor = maxf(0.0, calor - ESFRIA * delta)
	return false


func _lente_brilho(base: float) -> void:
	mat_lente.emission_energy_multiplier = 6.0 if _pisca > 0.0 else base + calor * 0.02
	if mech:
		mech.clarao(0.8 if _pisca > 0.0 else 0.0)
		mech.olho(clampf((base - 1.0) * 0.22, 0.0, 1.2))
