class_name CenasVista
extends Node3D
## Cenas raras ao apreciar a vista (2026-11-19). Depois de uns segundos olhando a paisagem, às vezes acontece
## alguma coisa para ver: uma revoada cruzando o céu, folhas levadas pelo vento ou, de noite, uma estrela
## cadente. É raro de propósito: no máximo uma por vez que se aprecia a vista, sorteada (menos da metade das
## vezes), com pelo menos quatro minutos entre uma e outra, e nunca a mesma duas vezes seguidas.
## Quem cria passa `armadura` e `camera`.

const DEMORA := 7.0  # segundos de vista antes do sorteio
const CHANCE := 0.4
const DESCANSO := 240.0
const AVE := "res://assets/vale/passaro.glb"

static var forcar := ""  # testes e fotos: "revoada", "folhas" ou "estrela" acontece sem sorteio nem descanso

var armadura: Armadura
var camera: CameraVoo
var vistas := 0  # quantas cenas aconteceram (testes)
var ultima := ""
var espera := 0.0

var _t_vista := 0.0
var _sorteou := false
var _aves: Array = []  # [nó, asa esquerda, asa direita, fase]
var _vel := Vector3.ZERO
var _t_cena := 0.0
var _riscos: Array = []  # [malha, velocidade, vida]
var _mat_risco: StandardMaterial3D


func _process(delta: float) -> void:
	espera = maxf(0.0, espera - delta)
	_animar(delta)
	if armadura == null or camera == null:
		return
	if not armadura.contemplando:
		_t_vista = 0.0
		_sorteou = false
		return
	_t_vista += delta
	if _sorteou or _t_vista < DEMORA:
		return
	_sorteou = true
	if forcar != "":
		_comecar(forcar)
	elif espera <= 0.0 and randf() < CHANCE:
		_comecar(_escolher())


func _escolher() -> String:
	var c := CicloDia.atual
	if ArmaduraVisual.noite > 0.7:
		return "estrela" if (c == null or c.chuva < 0.2) else ""
	return "folhas" if ultima == "revoada" else "revoada"


func _comecar(qual: String) -> void:
	if qual == "":
		return
	vistas += 1
	ultima = qual
	espera = DESCANSO
	_t_cena = 0.0
	var b := camera.cam.global_basis
	var frente := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var direita := frente.cross(Vector3.UP)
	var olho := camera.cam.global_position
	match qual:
		"revoada":
			# sete pássaros em cunha, da esquerda para a direita, longe e um pouco acima do horizonte
			var cena := load(AVE) as PackedScene
			_vel = direita * 9.0 + Vector3(0, 0.2, 0)
			var ponta := olho + frente * 58.0 - direita * 75.0 + Vector3(0, 13.0, 0)
			for i in 7:
				var lado := 0.0 if i == 0 else (1.0 if i % 2 == 1 else -1.0)
				var fila := ceili(i / 2.0)
				var no := Node3D.new()
				add_child(no)
				no.global_position = ponta - direita * fila * 3.2 + frente * lado * fila * 2.6 + Vector3(0, -0.3 * fila, 0)
				no.look_at(no.global_position + _vel, Vector3.UP)
				var modelo := cena.instantiate() as Node3D
				modelo.rotation.y = PI
				modelo.scale = Vector3.ONE * 3.4
				no.add_child(modelo)
				_aves.append([no, modelo.find_child("asaE", true, false), modelo.find_child("asaD", true, false), i * 0.7])
		"folhas":
			# um punhado de folhas passando no vento, perto, da esquerda para a direita
			var p := CPUParticles3D.new()
			p.amount = 46
			p.lifetime = 7.0
			p.one_shot = true
			p.explosiveness = 0.35
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(3.0, 2.5, 6.0)
			p.direction = direita
			p.spread = 14.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 5.5
			p.gravity = Vector3(0, -0.25, 0)
			p.angular_velocity_min = -160.0
			p.angular_velocity_max = 160.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.1
			var q := QuadMesh.new()
			q.size = Vector2(0.22, 0.14)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.vertex_color_use_as_albedo = true
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			q.material = m
			p.mesh = q
			var g := Gradient.new()
			g.set_color(0, Color(0.95, 0.55, 0.15))
			g.set_color(1, Color(0.75, 0.2, 0.12))
			p.color_initial_ramp = g
			add_child(p)
			p.global_position = olho + frente * 13.0 - direita * 16.0 + Vector3(0, 1.0, 0)
			p.emitting = true
			get_tree().create_timer(9.0).timeout.connect(p.queue_free)
		"estrela":
			# duas estrelas cadentes, uma depois da outra, no alto do céu à frente
			for k in 2:
				get_tree().create_timer(0.2 + k * 2.3).timeout.connect(_riscar.bind(olho, frente, direita, k))


func _riscar(olho: Vector3, frente: Vector3, direita: Vector3, k: int) -> void:
	if _mat_risco == null:
		_mat_risco = StandardMaterial3D.new()
		_mat_risco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_risco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_risco.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_risco.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_risco.disable_fog = true
		_mat_risco.albedo_color = Color(2.2, 2.3, 2.6, 1.0)
	var q := QuadMesh.new()
	q.size = Vector2(46.0, 1.1)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _mat_risco
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var rumo := (direita * (1.0 if k == 0 else -0.8) + Vector3(0, -0.42, 0)).normalized()
	mi.global_position = olho + frente * 620.0 + Vector3(0, 300.0 + k * 40.0, 0) - rumo * 150.0 + direita * (k * 120.0 - 60.0)
	# o quadro deitado ao longo do rumo, de frente para quem olha
	mi.global_basis = Basis(rumo, (-frente).cross(rumo).normalized(), -frente).orthonormalized()
	_riscos.append([mi, rumo * 420.0, 0.0])


func _animar(delta: float) -> void:
	if not _aves.is_empty():
		_t_cena += delta
		for a: Array in _aves:
			var no := a[0] as Node3D
			no.global_position += _vel * delta
			var bate := sin(_t_cena * 7.5 + float(a[3])) * 0.75
			if a[1] is Node3D:
				(a[1] as Node3D).rotation.z = bate
			if a[2] is Node3D:
				(a[2] as Node3D).rotation.z = -bate
		if _t_cena > 24.0:
			for a: Array in _aves:
				(a[0] as Node3D).queue_free()
			_aves.clear()
	for r: Array in _riscos.duplicate():
		var mi := r[0] as MeshInstance3D
		r[2] = float(r[2]) + delta
		mi.global_position += (r[1] as Vector3) * delta
		mi.transparency = clampf(float(r[2]) / 0.9, 0.0, 1.0)
		if float(r[2]) > 0.9:
			mi.queue_free()
			_riscos.erase(r)
