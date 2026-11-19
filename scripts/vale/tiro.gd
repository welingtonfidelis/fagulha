class_name Tiro
extends Node3D
## Os jatos da mão do robô, que também são a arma. Com a ação "atirar" (R2 / botão esquerdo) e o robô
## mirando no chão ou pairando, cada disparo esquenta o motor, acende os jatos, dá um tranco na câmera,
## lança um projétil de luz da mão direita até o ponto em que a mira bate e faz faísca no impacto.
## Os bichos do grupo "bichos" fogem do robô no disparo e do ponto de impacto.
## Uso: Tiro.new(), defina armadura (já com ilha e câmera), e só então add_child.

signal disparou(origem: Vector3, alvo: Vector3)

const CADENCIA := 0.2  # s no mínimo entre disparos (a pistola atira a cada aperto)
const CALOR_POR_TIRO := 3.5
const ALCANCE := 220.0
const VELOCIDADE := 130.0  # m/s do projétil (as máquinas atiram bala rápida; o robô acompanha)
const TRAVA_ANGULO := deg_to_rad(6.5)  # mirando, a máquina a menos disso do centro da mira fica travada
const TRAVA_SEGURA := 1.6  # a travada continua travada até este tanto do ângulo (não fica trocando)
const TRAVA_ALCANCE := 130.0

var armadura: Armadura
var hud: Hud
var poupados := 0  # tiros que não saíram por haver um colega na mira (testes)
var _aviso_amigo := 0.0
var barrados := 0  # tiros que pararam num obstáculo antes do ponto mirado (testes)
var disparos := 0
var travado: Node3D  # a máquina em que a mira travou (null: nenhuma); a tela desenha o colchete nela

var _espera := 0.0
var _pedido := 0.0  # tempo que um aperto do gatilho ainda vale
var carga := 0.0  # 0 a 1: o canhão carregando (a tela desenha)
var _som_carga: AudioStreamPlayer3D  # o som de carregar, para cortar quando solta o gatilho
var travas: Array = []  # as máquinas travadas pelos mísseis (a tela desenha um losango em cada uma)
var arco := PackedVector3Array()  # o caminho da granada enquanto o botão está segurado
var misseis_lancados := 0  # testes
var _pedido_e := 0.0
var _espera_e := 0.0
var _trava_t := 0.0
var _segurando_missil := false
var _mirando_granada := false
var _arco_no: Node3D
var granadas_jogadas := 0  # testes
var golpes_espada := 0
var espada_acertos := 0
var _espada_espera := 0.0
var _granadas: Array[Dictionary] = []
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


## Um colega (grupo "amigos") perto da linha da mira, antes de qualquer obstáculo.
func _amigo_na_mira() -> bool:
	var cam := armadura.camera
	if cam == null:
		return false
	var de: Vector3 = cam.global_position
	var dir: Vector3 = cam.mira()
	var ate := _ponto_de_impacto().distance_to(de)
	for n in get_tree().get_nodes_in_group("amigos"):
		var v: Vector3 = (n as Node3D).global_position - de
		var t := v.dot(dir)
		if t < 0.5 or t > ate + 0.8:
			continue
		if (v - dir * t).length() < 0.8 + t * 0.012:
			return true
	return false


func _physics_process(delta: float) -> void:
	_espera = maxf(0.0, _espera - delta)
	_aviso_amigo = maxf(0.0, _aviso_amigo - delta)
	if armadura == null or not is_instance_valid(armadura):
		return
	_atualizar_trava()
	var modo: Dictionary = Arsenal.MODOS[Arsenal.modo if Arsenal.tem_arma(Arsenal.modo) else "pistola"]
	CameraVoo.fov_mira = float(modo.get("fov", Ajustes.FOV_MIRA))
	_granada(delta)
	_espada(delta)
	# o gatilho de cada arma: a pistola dispara uma vez por aperto (segurar não repete; um aperto dado um
	# instante antes de a arma estar pronta ainda vale); a rajada repete enquanto segura; o canhão carrega
	# segurando e dispara ao soltar
	var quer := false
	var forca := 1.0
	match String(modo["gatilho"]):
		"segura":
			quer = Input.is_action_pressed("atirar")
		"carga":
			if Input.is_action_pressed("atirar") and _pode_atirar():
				if carga <= 0.0:
					_som_carga = Som.toque3d(self, "canhao_carga", armadura.global_position, -6.0)
				carga = minf(1.0, carga + delta / float(modo["carga"]))
				armadura.atirando = 0.6
			elif carga > 0.0:
				# soltou: o som de carregar para ali (antes seguia até o fim mesmo sem tiro)
				if is_instance_valid(_som_carga):
					_som_carga.queue_free()
				_som_carga = null
				quer = carga > 0.25
				forca = carga
				carga = 0.0
		"duplo":
			# cada gatilho, o seu braço: R2 o direito, L2 o esquerdo, um tiro por aperto; os dois juntos
			# atiram ao mesmo tempo
			_espera_e = maxf(0.0, _espera_e - delta)
			if Input.is_action_just_pressed("mirar"):
				_pedido_e = 0.14
			_pedido_e = maxf(0.0, _pedido_e - delta)
			if _pedido_e > 0.0 and _espera_e <= 0.0 and not RodaArmas.aberta and _pode_atirar() and not _amigo_na_mira():
				_pedido_e = 0.0
				_espera_e = float(modo["cadencia"])
				armadura.atirando_e = 0.6
				_disparar(modo, 1.0, true)
			if Input.is_action_just_pressed("atirar"):
				_pedido = 0.14
			_pedido = maxf(0.0, _pedido - delta)
			quer = _pedido > 0.0
		"trava":
			_travar_misseis(delta, modo)
			return
		_:
			if Input.is_action_just_pressed("atirar"):
				_pedido = 0.14
			_pedido = maxf(0.0, _pedido - delta)
			quer = _pedido > 0.0
	if String(modo["gatilho"]) != "trava":
		travas.clear()
	if not quer or RodaArmas.aberta:
		return
	if not _pode_atirar() or _espera > 0.0:
		return
	# regra: não se atira em colega (o drone da base). Com ele na mira o tiro não sai
	if _amigo_na_mira():
		poupados += 1
		_espera = float(modo["cadencia"])
		if _aviso_amigo <= 0.0:
			if hud:
				hud.avisar("colega na mira", "o tiro não sai")
			_aviso_amigo = 4.0
			get_tree().call_group("amigos", "levou_mira")
		return
	_espera = float(modo["cadencia"])
	_pedido = 0.0
	armadura.atirando = 0.6
	_disparar(modo, forca)


## Os mísseis: segurando o gatilho, as máquinas à frente (num cone de 32°, até 130 m, com a vista livre)
## vão sendo travadas, uma a cada 0,3 s, até quatro ou até acabarem os mísseis; soltando, sai um míssil do
## lançador do ombro esquerdo para cada uma. Sem nenhuma travada, sai um reto para onde a mira aponta.
func _travar_misseis(delta: float, modo: Dictionary) -> void:
	for t in travas.duplicate():
		if not is_instance_valid(t) or not (t.call("ponto_de_trava") as Vector3).is_finite():
			travas.erase(t)
	var segura := Input.is_action_pressed("atirar") and not RodaArmas.aberta and _pode_atirar()
	if segura:
		_segurando_missil = true
		armadura.atirando = 0.6
		_trava_t -= delta
		var limite := mini(4, Arsenal.misseis)
		if _trava_t <= 0.0 and travas.size() < limite:
			var cam := armadura.camera
			var de: Vector3 = cam.global_position
			var dir: Vector3 = cam.mira()
			var melhor: Node3D = null
			var menor := deg_to_rad(32.0)
			for n in get_tree().get_nodes_in_group("maquinas"):
				if travas.has(n) or not n.has_method("ponto_de_trava"):
					continue
				var pt: Vector3 = n.call("ponto_de_trava")
				if not pt.is_finite() or pt.distance_to(de) > 130.0:
					continue
				var ang := dir.angle_to(pt - de)
				if ang >= menor:
					continue
				var q := PhysicsRayQueryParameters3D.create(de, pt, 1, [armadura.get_rid()])
				var bate := get_world_3d().direct_space_state.intersect_ray(q)
				if not bate.is_empty() and (bate["position"] as Vector3).distance_to(pt) > 2.0:
					continue
				menor = ang
				melhor = n
			if melhor:
				travas.append(melhor)
				_trava_t = 0.3
				Som.toque3d(self, "trava", armadura.global_position, -4.0)
		return
	if not _segurando_missil:
		return
	_segurando_missil = false
	_trava_t = 0.0
	if _espera > 0.0 or Arsenal.misseis <= 0:
		if Arsenal.misseis <= 0:
			Som.toque3d(self, "sem_municao", armadura.global_position, -4.0)
			if hud:
				hud.avisar("Sem mísseis", "reponha na oficina ou numa caixa da Fundição")
		travas.clear()
		return
	_espera = float(modo["cadencia"])
	var alvos: Array = travas.duplicate()
	travas.clear()
	if alvos.is_empty():
		alvos.append(null)
	var k := 0
	for alvo_m in alvos:
		if Arsenal.misseis <= 0:
			break
		Arsenal.misseis -= 1
		misseis_lancados += 1
		disparos += 1
		# (atirar não esquenta mais o robô: pedido do usuário em 2026-11-18; o calor é só do voo)
		armadura.tremor = maxf(armadura.tremor, 0.25)
		var origem := _ombro(-1.0) + Vector3(0, 0.1 + k * 0.05, 0)
		var destino: Vector3 = (alvo_m as Node3D).call("ponto_de_trava") if alvo_m else _ponto_de_impacto()
		EfeitosTiro.clarao(self, origem, Vector3.UP, 0.8)
		disparou.emit(origem, destino)
		_missil(origem, destino, alvo_m as Node3D, float(modo["dano"]), float(modo["area"]), float(modo["vel"]), k * 0.14)
		k += 1
	get_tree().call_group("bichos", "assustar", armadura.global_position)


## O lançador do ombro (lado -1 esquerdo, +1 direito), no mundo.
func _ombro(lado: float) -> Vector3:
	var b := armadura.visual.global_basis.orthonormalized() if armadura.visual else armadura.global_basis
	var h := armadura.altura_corpo()
	return armadura.pos_suave() + b * Vector3(lado * 0.205 * h, 0.74 * h, 0.07 * h)


## A granada sai do lançador a 70° e cai onde a mira aponta (até 55 m): a velocidade é a que leva até lá.
## Assim o jogador mira no chão onde quer que ela caia, sem ter de olhar para cima.
func _lance_granada() -> Vector3:
	var de := _ombro(1.0)
	var alvo := _ponto_de_impacto()
	var plano := Vector3(alvo.x - de.x, 0, alvo.z - de.z)
	var x := clampf(plano.length(), 4.0, float(Arsenal.GRANADA["alcance"]))
	if plano.length() > float(Arsenal.GRANADA["alcance"]) or not armadura.alvo_mira_ok and plano.length() > 60.0:
		alvo.y = de.y - armadura.altura_corpo() * 0.7
	if plano.length() < 0.1:
		plano = -armadura.global_basis.z
	var dir := plano.normalized()
	var y := clampf(alvo.y - de.y, -40.0, x * 1.5)
	var ang := Arsenal.ANGULO_LANCE
	var baixo := 2.0 * cos(ang) * cos(ang) * (x * tan(ang) - y)
	var v := sqrt(22.0 * x * x / maxf(baixo, 0.5))
	return (dir * cos(ang) + Vector3.UP * sin(ang)) * clampf(v, 6.0, 40.0)


## Por onde a granada vai: os pontos do arco e onde cai (o último). A mesma conta do voo dela.
func arco_granada() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var p := _ombro(1.0)
	var vel := _lance_granada()
	var passo := 0.05
	var espaco := get_world_3d().direct_space_state
	pts.append(p)
	for i in 110:
		vel.y -= 22.0 * passo
		var ate := p + vel * passo
		var bate := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(p, ate, 1 | 2, [armadura.get_rid()]))
		if not bate.is_empty():
			pts.append(bate["position"])
			return pts
		p = ate
		pts.append(p)
	return pts


## O míssil: corpo escuro, nariz vermelho, quatro aletas e a chama atrás (aponta para o -Z do nó).
func _corpo_missil() -> Node3D:
	var fora := Node3D.new()
	fora.name = "Missil"
	var no := Node3D.new()
	no.scale = Vector3.ONE * 0.33  # do tamanho das bocas do lançador
	fora.add_child(no)
	var escuro := StandardMaterial3D.new()
	escuro.albedo_color = Color(0.82, 0.84, 0.86)
	var vermelho := StandardMaterial3D.new()
	vermelho.albedo_color = Color(0.9, 0.2, 0.15)
	var corpo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.085
	cm.bottom_radius = 0.085
	cm.height = 0.62
	cm.radial_segments = 10
	corpo.mesh = cm
	corpo.material_override = escuro
	corpo.rotation.x = PI * 0.5
	no.add_child(corpo)
	var nariz := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.0
	nm.bottom_radius = 0.085
	nm.height = 0.24
	nm.radial_segments = 10
	nariz.mesh = nm
	nariz.material_override = vermelho
	nariz.rotation.x = -PI * 0.5
	nariz.position.z = -0.43
	no.add_child(nariz)
	for i in 4:
		var aleta := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.012, 0.16, 0.18)
		aleta.mesh = am
		aleta.material_override = vermelho
		aleta.position = Vector3(0, 0, 0.24)
		var giro := Node3D.new()
		giro.rotation.z = i * PI * 0.5
		aleta.position.y = 0.12
		giro.add_child(aleta)
		no.add_child(giro)
	var chama := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.07
	fm.bottom_radius = 0.0
	fm.height = 0.7
	fm.radial_segments = 8
	chama.mesh = fm
	chama.material_override = _mat_projetil
	chama.rotation.x = -PI * 0.5
	chama.position.z = 0.66
	chama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(chama)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 1.2
	luz.omni_range = 4.0
	luz.position.z = 0.6
	no.add_child(luz)
	EfeitosTiro.rastro_fumaca(fora)
	return fora


## A granada: uma bola escura com uma cinta e uma luz vermelha que pisca.
func _corpo_granada() -> Node3D:
	var no := Node3D.new()
	no.scale = Vector3.ONE * 0.36  # cabe no tubo do lançador
	var bola := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	sm.radial_segments = 12
	sm.rings = 6
	bola.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.26, 0.22)
	bola.material_override = m
	no.add_child(bola)
	var cinta := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.176
	cm.bottom_radius = 0.176
	cm.height = 0.07
	cm.radial_segments = 12
	cinta.mesh = cm
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.85, 0.7, 0.3)
	cinta.material_override = mc
	no.add_child(cinta)
	var luz := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.05
	lm.height = 0.1
	luz.mesh = lm
	var ml := StandardMaterial3D.new()
	ml.albedo_color = Color(1.0, 0.2, 0.15)
	ml.emission_enabled = true
	ml.emission = Color(1.0, 0.2, 0.15)
	ml.emission_energy_multiplier = 4.0
	luz.material_override = ml
	luz.position.y = 0.18
	luz.name = "luz"
	no.add_child(luz)
	return no


## O voo do míssil: sai do lançador a 70°, sobe, vira e desce em cima do alvo (uma curva de três pontos,
## com o fim acompanhando a máquina travada).
func _missil(origem: Vector3, destino: Vector3, guia: Node3D, dano: float, area: float, vel: float, atraso: float) -> void:
	var proj := _corpo_missil()
	add_child(proj)
	proj.global_position = origem
	var frente := -armadura.visual.global_basis.z.normalized() if armadura.visual else -armadura.global_basis.z
	var lance := (frente * cos(Arsenal.ANGULO_LANCE) + Vector3.UP * sin(Arsenal.ANGULO_LANCE)).normalized()
	var dist := origem.distance_to(destino)
	var meio := origem + lance * clampf(dist * 0.55, 7.0, 26.0)
	proj.look_at(origem + lance, Vector3.BACK if absf(lance.y) > 0.99 else Vector3.UP)
	proj.visible = atraso <= 0.0
	var fim := [destino]
	var passo := func(k: float) -> void:
		if is_instance_valid(guia):
			var p: Vector3 = guia.call("ponto_de_trava")
			if p.is_finite():
				fim[0] = p
		var a1 := origem.lerp(meio, k)
		var b1 := meio.lerp(fim[0], k)
		var onde := a1.lerp(b1, k)
		var para := (b1 - a1).normalized()
		if para.length() > 0.5 and absf(para.y) < 0.995:
			proj.look_at_from_position(onde, onde + para, Vector3.UP)
		else:
			proj.global_position = onde
	var tw := proj.create_tween()
	if atraso > 0.0:
		tw.tween_interval(atraso)
		tw.tween_callback(func() -> void: proj.visible = true)
	tw.tween_method(passo, 0.0, 1.0, maxf(0.5, (dist + 14.0) / vel)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _impacto(fim[0], dano, area))
	tw.tween_callback(proj.queue_free)


## No chão atira mirando ou não; no ar, só no voo parado (voando ou caindo, não).
func _pode_atirar() -> bool:
	var e := armadura.estado
	if armadura.em_pane or armadura.travado or armadura.escaneando or armadura.superaquecido:
		return false
	return e == Armadura.Estado.CHAO or e == Armadura.Estado.PAIRAR


## A espada de laser (R3 no chão / X): um golpe em arco na frente do robô, que alterna de lado a cada vez
## (da esquerda para a direita, depois da direita para a esquerda). Pega todas as máquinas ao alcance, dá um
## passo à frente e não esquenta o motor.
func _espada(delta: float) -> void:
	_espada_espera = maxf(0.0, _espada_espera - delta)
	if not Input.is_action_just_pressed("espada") or _espada_espera > 0.0 or RodaArmas.aberta:
		return
	if armadura.estado != Armadura.Estado.CHAO or armadura.em_pane or armadura.travado or armadura.escaneando or armadura.postura != 0:
		return
	var e: Dictionary = Arsenal.ESPADA
	_espada_espera = float(e["espera"])
	armadura.espada_t = float(e["tempo"])
	armadura.espada_lado = -armadura.espada_lado
	golpes_espada += 1
	var yaw: float = armadura.camera.yaw if armadura.camera else armadura.rotation.y
	var frente := Vector3(-sin(yaw), 0, -cos(yaw))
	armadura.velocity += frente * 3.5
	armadura.atirando = maxf(armadura.atirando, float(e["tempo"]))
	var meio := armadura.pos_suave() + Vector3(0, armadura.altura_corpo() * 0.5, 0)
	var cor := Color(0.4, 0.95, 1.0)
	# (o arco largo de luz era do alcance de 3,6 m; com a lâmina curta fica só o brilho dela)
	Som.toque3d(self, "espada_1" if armadura.espada_lado > 0.0 else "espada_2", armadura.global_position, -3.0)
	var acertou := false
	for n in get_tree().get_nodes_in_group("maquinas"):
		if not n.has_method("ponto_de_trava"):
			continue
		var pt: Vector3 = n.call("ponto_de_trava")
		if not pt.is_finite():
			continue
		var para := pt - meio
		var folga: float = n.call("raio_acerto") if n.has_method("raio_acerto") else 1.0
		if Vector2(para.x, para.z).length() > float(e["alcance"]) + folga or absf(para.y) > 4.5:
			continue
		if rad_to_deg(frente.angle_to(Vector3(para.x, 0, para.z))) > float(e["abre"]):
			continue
		n.call("levar_tiro", pt, float(e["dano"]), 0.0)
		EfeitosTiro.impacto_laser(self, pt, cor, 1.2)
		acertou = true
	if acertou:
		armadura.tremor = maxf(armadura.tremor, 0.35)
		espada_acertos += 1
	get_tree().call_group("bichos", "assustar", armadura.global_position)


## A granada (R1 / G): sai em arco para onde a câmera aponta, quica uma vez e estoura.
func _granada(delta: float) -> void:
	for g in _granadas.duplicate():
		g["t"] += delta
		var no := g["no"] as Node3D
		var vel: Vector3 = g["vel"]
		vel.y -= 22.0 * delta
		var de := no.global_position
		var ate := de + vel * delta
		var q := PhysicsRayQueryParameters3D.create(de, ate, 1 | 2, [armadura.get_rid()])
		var bate := get_world_3d().direct_space_state.intersect_ray(q)
		var perto := false
		for n in get_tree().get_nodes_in_group("maquinas"):
			if n.has_method("ponto_de_trava"):
				var pt: Vector3 = n.call("ponto_de_trava")
				if pt.is_finite() and pt.distance_to(ate) < 1.6:
					perto = true
		if not bate.is_empty():
			ate = bate["position"] + (bate["normal"] as Vector3) * 0.15
			vel = vel.bounce(bate["normal"]) * 0.35
			g["quiques"] += 1
		g["vel"] = vel
		no.global_position = ate
		no.rotation += Vector3(7.0, 3.0, 5.0) * delta
		var pisca := no.get_node_or_null("luz") as Node3D
		if pisca:
			pisca.visible = fmod(float(g["t"]) * (3.0 + float(g["t"]) * 3.0), 1.0) < 0.5
		if perto or g["quiques"] >= 2 or g["t"] >= float(Arsenal.GRANADA["pavio"]):
			_granadas.erase(g)
			no.queue_free()
			_estouro(ate, float(Arsenal.GRANADA["dano"]), float(Arsenal.GRANADA["area"]))
	# segurando o botão aparece o arco (a tela desenha `arco`); soltando, a granada sai do lançador do ombro
	var pode := not RodaArmas.aberta and _pode_atirar() and Arsenal.granadas > 0
	if Input.is_action_just_pressed("granada") and not RodaArmas.aberta and Arsenal.granadas <= 0:
		Som.toque3d(self, "sem_municao", armadura.global_position, -4.0)
		if hud and _aviso_amigo <= 0.0:
			hud.avisar("Sem granadas", "fabrique o lança-granadas na oficina" if Arsenal.granadas_max() == 0 else "reponha na oficina ou numa caixa da Fundição")
			_aviso_amigo = 2.5
	CameraVoo.afasta = 1.0 if (Input.is_action_pressed("granada") and pode) else 0.0
	if Input.is_action_pressed("granada") and pode:
		_mirando_granada = true
		arco = arco_granada()
		_mostrar_arco()
		return
	_esconder_arco()
	if not _mirando_granada:
		return
	_mirando_granada = false
	arco = PackedVector3Array()
	if not pode:
		return
	Arsenal.granadas -= 1
	granadas_jogadas += 1
	var no := _corpo_granada()
	add_child(no)
	no.global_position = _ombro(1.0)
	_granadas.append({"no": no, "vel": _lance_granada(), "t": 0.0, "quiques": 0})
	Som.toque3d(self, "granada_sai", armadura.global_position, -2.0)
	armadura.atirando = 0.4
	EfeitosTiro.clarao(self, no.global_position, Vector3.UP, 0.5)


## O arco no mundo: bolinhas ao longo do caminho e um anel onde a granada cai.
func _mostrar_arco() -> void:
	if _arco_no == null:
		_arco_no = Node3D.new()
		_arco_no.top_level = true
		add_child(_arco_no)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.62, 0.3, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		var bola := SphereMesh.new()
		bola.radius = 0.07
		bola.height = 0.14
		bola.radial_segments = 8
		bola.rings = 4
		for i in 24:
			var mi := MeshInstance3D.new()
			mi.mesh = bola
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_arco_no.add_child(mi)
		var anel := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = float(Arsenal.GRANADA["area"]) - 0.12
		tm.outer_radius = float(Arsenal.GRANADA["area"])
		tm.rings = 48
		tm.ring_segments = 4
		anel.mesh = tm
		anel.material_override = mat
		anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anel.name = "anel"
		_arco_no.add_child(anel)
	_arco_no.visible = true
	_arco_no.global_transform = Transform3D.IDENTITY
	var n := arco.size()
	for i in 24:
		var mi := _arco_no.get_child(i) as MeshInstance3D
		var k := int((i + 1) * (n - 1) / 25.0)
		mi.visible = n > 2 and k > 0
		if mi.visible:
			mi.position = arco[k]
	var anel_no := _arco_no.get_node("anel") as MeshInstance3D
	anel_no.position = arco[n - 1] + Vector3(0, 0.15, 0)


func _esconder_arco() -> void:
	if _arco_no:
		_arco_no.visible = false


## Um estouro: dano em área nas máquinas, clarão e faíscas.
func _estouro(ponto: Vector3, dano: float, area: float) -> void:
	get_tree().call_group("bichos", "assustar", ponto)
	get_tree().call_group("maquinas", "levar_tiro", ponto, dano, area)
	EfeitosTiro.estouro(self, ponto, area)
	Som.toque3d(self, Som.variacao("explosao", 2), ponto, 3.0, 20.0, 220.0)
	armadura.tremor = maxf(armadura.tremor, clampf(1.2 - armadura.global_position.distance_to(ponto) * 0.05, 0.0, 0.8))


func _disparar(modo: Dictionary = Arsenal.MODOS["pistola"], forca := 1.0, esquerdo := false) -> void:
	disparos += 1
	if not esquerdo:
		armadura.clarao_tiro = 1.0  # só o jato da mão direita acende, e só quando é ela que dispara
	armadura.tremor = maxf(armadura.tremor, 0.12 + 0.1 * float(modo["dano"]) * forca)
	_um_tiro(modo, forca, esquerdo)


func _um_tiro(modo: Dictionary, forca: float, esquerdo: bool) -> void:
	var origem := _mao(esquerdo)
	var guiado := travado != null and is_instance_valid(travado)
	var impacto: Vector3 = travado.call("ponto_de_trava") if guiado else _ponto_de_impacto()
	if not impacto.is_finite():
		guiado = false
		impacto = _ponto_de_impacto()
	# o tiro sai da ponta da arma, um palmo adiante do punho na direção do alvo (do punho, o clarão e a luz
	# nasciam em cima do antebraço)
	origem += (impacto - origem).normalized() * 0.2 * armadura.altura_corpo()
	var espalha := float(modo.get("espalha", 0.0))
	if espalha > 0.0 and not guiado:
		var dist := origem.distance_to(impacto)
		impacto += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * dist * espalha
	# algo sólido entre a mão e o ponto (tronco, copa, rocha, parede): o tiro para ali, travado ou não
	var fora: Array[RID] = [armadura.get_rid()]
	if guiado and travado.get("_acerto") is CollisionObject3D:
		fora.append((travado.get("_acerto") as CollisionObject3D).get_rid())  # o corpo do alvo travado não é obstáculo
	var qo := PhysicsRayQueryParameters3D.create(origem, impacto, 1 | 2, fora)
	var meio := get_world_3d().direct_space_state.intersect_ray(qo)
	if not meio.is_empty() and (meio["position"] as Vector3).distance_to(impacto) > 1.6:
		impacto = meio["position"]
		guiado = false
		barrados += 1
	disparou.emit(origem, impacto)
	get_tree().call_group("bichos", "assustar", armadura.global_position)

	var cor: Color = modo.get("cor", Color(1.0, 0.55, 0.2))
	var grosso := float(modo.get("grosso", 1.0)) * lerpf(0.5, 1.0, forca)
	_clarao(origem, 0.08)
	EfeitosTiro.clarao(self, origem, impacto - origem, 0.5 + 0.3 * grosso, String(modo.get("boca", "muzzle_01")), cor)
	EfeitosTiro.risco(self, origem, impacto, cor, grosso)
	_projetil(origem, impacto, travado if guiado else null, float(modo["dano"]) * forca, float(modo["area"]) * lerpf(0.6, 1.0, forca), float(modo["vel"]), grosso, 0.0, cor, float(modo.get("comp", 2.2)))


## Ajuda de mira: mirando (L2), a máquina ligada mais perto do centro da mira, dentro de um cone pequeno e
## com a vista livre, fica travada; os tiros seguem ela. Sem mirar não há trava.
func _atualizar_trava() -> void:
	var cam := armadura.camera
	# travar a mira é fabricável (a Mira assistida, no Arsenal): sem ela, o tiro vai para onde a mira aponta
	if cam == null or not armadura.mirando_agora() or armadura.em_pane or not Arsenal.tem("mira"):
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


## De onde o tiro sai: a ponta do cano da luva; sem ela, o osso do punho quando o modelo tem a junta, senão um ponto acima do robô.
func _mao(esquerda := false) -> Vector3:
	var v = armadura.visual
	# o robô novo atira pelo cano da luva
	if v != null and v.has_method("boca_da_arma"):
		var boca: Node3D = v.boca_da_arma(esquerda)
		if boca != null and is_instance_valid(boca):
			return boca.global_position
	if v != null and v.j is Dictionary:
		var punho = v.j.get("punhoE" if esquerda else "punhoD")
		if punho is Node3D and is_instance_valid(punho):
			return (punho as Node3D).global_position
	return armadura.global_position + Vector3(0.0, 0.6, 0.0)


func _projetil(origem: Vector3, impacto: Vector3, guia: Node3D = null, dano := 1.0, area := 0.0, vel := VELOCIDADE, tam := 1.0, atraso := 0.0,
		cor := Color(1.0, 0.55, 0.2), comp := 2.2) -> void:
	var proj := Node3D.new()
	add_child(proj)
	proj.global_position = origem
	var cabeca := Vector3.UP if absf((impacto - origem).normalized().dot(Vector3.UP)) < 0.99 else Vector3.BACK
	if impacto.distance_to(origem) > 0.01:
		proj.look_at(impacto, cabeca)
	# o raio em duas camadas: um miolo fino quase branco dentro de um halo comprido na cor da arma
	# o raio fica todo para trás da ponta (a cauda), dentro de um nó que começa encolhido e estica conforme
	# o tiro se afasta: inteiro desde o começo, a cauda nascia atravessando o braço e o corpo do robô, e a
	# luz parecia sair de partes dele
	var raio := Node3D.new()
	raio.scale = Vector3(1, 1, 0.04)
	proj.add_child(raio)
	raio.create_tween().tween_property(raio, "scale:z", 1.0, comp * 1.1 / maxf(vel, 1.0))
	var halo := EfeitosTiro.cruzado("trace_01", cor, 0.9 * tam, comp, comp * 0.5, true)
	var halo2 := EfeitosTiro.cruzado("light_02", cor, 0.7 * tam, 0.7 * tam, 0.0, true)
	proj.add_child(halo2)
	raio.add_child(halo)
	var miolo := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.045 * tam
	cm.height = comp * 0.7
	miolo.mesh = cm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = cor.lerp(Color.WHITE, 0.55)
	miolo.material_override = mm
	miolo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	miolo.rotation.x = PI / 2.0  # a cápsula fica no eixo -Z do nó, que aponta ao alvo
	miolo.position.z = comp * 0.38
	raio.add_child(miolo)
	var luz_p := OmniLight3D.new()
	luz_p.light_color = cor
	luz_p.light_energy = 1.0 * tam
	luz_p.omni_range = 3.0
	luz_p.shadow_enabled = false
	proj.add_child(luz_p)
	var tempo := maxf(0.02, origem.distance_to(impacto) / vel)
	var tw := proj.create_tween()
	if atraso > 0.0:
		proj.visible = false
		tw.tween_interval(atraso)
		tw.tween_callback(func() -> void: proj.visible = true)
	if guia == null:
		tw.tween_property(proj, "global_position", impacto, tempo)
		tw.tween_callback(_impacto.bind(impacto, dano, area, cor))
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
		tw.tween_callback(func() -> void: _impacto(destino[0], dano, area, cor))
	tw.tween_callback(proj.queue_free)


func _impacto(ponto: Vector3, dano := 1.0, area := 0.0, cor := Color(1.0, 0.55, 0.2)) -> void:
	if area > 0.0:
		_estouro(ponto, dano, area)
		return
	get_tree().call_group("bichos", "assustar", ponto)
	get_tree().call_group("maquinas", "levar_tiro", ponto, dano, 0.0)
	EfeitosTiro.impacto_laser(self, ponto, cor, 0.7 + 0.3 * dano)
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
	luz.light_energy = 0.8
	luz.omni_range = 1.6
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
