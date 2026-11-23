class_name GeiserFonte
extends Node3D
## O gêiser pequeno da bacia das fontes quentes (2026-11-22, pedido do usuário: "gêiser de vez em quando, além do
## vapor e das bolhas"). Fica num dos respiros, num cone baixo de sínter com o furo no alto. A cada 2 a 4 minutos
## (o primeiro mais cedo) ele avisa com um gorgolejo e borrifos curtos, jorra uns 7 s até 5 a 7 m de altura e
## acaba num bafo de vapor que o vento leva. Só a vista e o som: ninguém se machuca e nada muda no jogo.
## Partículas na GPU (a imagem circle_05 e a fumaça smoke_04 do Kenney Particle Pack, CC0). O nó fica no chão, no
## pé do cone. `forcar(t)` põe o jorro no segundo t (para as fotos).

const ALTO := 1.15  # a altura do cone
const PINGO := "res://assets/fx/kenney/circle_05.png"
const FUMACA := "res://assets/fx/kenney/smoke_04.png"
const AVISO := 3.5
const JORRO := 7.0
const FIM := 1.5

enum Fase { ESPERA, AVISO, JORRO, FIM }

var fontes: FontesQuentes
var fase := Fase.ESPERA

var _t := 0.0  # tempo dentro da fase
var _espera := 60.0
var _jato: GPUParticles3D
var _borrifo: GPUParticles3D
var _bafo: GPUParticles3D
var _m_jato: ParticleProcessMaterial
var _coluna: MeshInstance3D  # o miolo do jato (geiser_jato)
var _m_col: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4417
	_espera = _rng.randf_range(40.0, 90.0)
	_cone()
	_particulas()


func _process(delta: float) -> void:
	_t += delta
	var alt := 0.0
	var forte := 0.0
	match fase:
		Fase.ESPERA:
			if _t > _espera:
				_mudar(Fase.AVISO)
		Fase.AVISO:
			# borrifos curtos e baixos, em soluços
			var solu := maxf(0.0, sin(_t * 7.3) * sin(_t * 2.9 + 1.0))
			_jato.amount_ratio = 0.08 + 0.35 * solu * smoothstep(0.5, AVISO, _t)
			_m_jato.initial_velocity_min = 2.0 + 2.0 * solu
			_m_jato.initial_velocity_max = 3.5 + 3.0 * solu
			_borrifo.amount_ratio = 0.15 * solu
			alt = 0.3 + 1.1 * solu
			forte = 0.6 * solu * smoothstep(0.5, AVISO, _t)
			if _t > AVISO:
				_mudar(Fase.JORRO)
		Fase.JORRO:
			var sobe := smoothstep(0.0, 0.6, _t)
			var tremor := 0.85 + 0.15 * sin(_t * 11.0) * sin(_t * 3.7)
			_jato.amount_ratio = sobe * tremor
			_m_jato.initial_velocity_min = lerpf(5.0, 9.5, sobe) * tremor
			_m_jato.initial_velocity_max = lerpf(7.0, 12.0, sobe) * tremor
			_borrifo.amount_ratio = smoothstep(0.8, 1.6, _t)
			_bafo.amount_ratio = 0.4 + 0.6 * sobe
			alt = lerpf(1.0, 6.5, sobe) * tremor
			forte = 1.0
			if _t > JORRO:
				_mudar(Fase.FIM)
		Fase.FIM:
			var u := clampf(_t / FIM, 0.0, 1.0)
			_jato.amount_ratio = (1.0 - u) * 0.6
			_m_jato.initial_velocity_min = lerpf(8.0, 2.0, u)
			_m_jato.initial_velocity_max = lerpf(10.0, 3.0, u)
			_borrifo.amount_ratio = 1.0 - u
			_bafo.amount_ratio = 1.0 - u * 0.5
			alt = lerpf(6.0, 0.5, u)
			forte = 1.0 - u
			if _t > FIM + 1.0:
				_mudar(Fase.ESPERA)
	_coluna.visible = forte > 0.01
	_m_col.set_shader_parameter("altura", maxf(alt, 0.05))
	_m_col.set_shader_parameter("forca", forte)


func _mudar(f: Fase) -> void:
	fase = f
	_t = 0.0
	match f:
		Fase.ESPERA:
			_espera = _rng.randf_range(120.0, 240.0)
			_jato.emitting = false
			_borrifo.emitting = false
			_bafo.emitting = false
		Fase.AVISO:
			_jato.emitting = true
			_borrifo.emitting = true
			_jato.amount_ratio = 0.0
			_borrifo.amount_ratio = 0.0
			# o som tem o gorgolejo (3,5 s), o jorro (8 s) e o respingo final
			Som.toque3d(self, "geiser", global_position + Vector3.UP * (ALTO + 0.5), -3.0, 10.0, 140.0)
		Fase.JORRO:
			_bafo.emitting = true
			_bafo.amount_ratio = 0.4


## Para as fotos: o gêiser no segundo `t` do jorro (sem som).
func forcar(t := 3.0) -> void:
	fase = Fase.JORRO
	_t = t
	_jato.emitting = true
	_borrifo.emitting = true
	_bafo.emitting = true
	_jato.amount_ratio = 1.0
	_borrifo.amount_ratio = 1.0
	_bafo.amount_ratio = 1.0
	_m_jato.initial_velocity_min = 9.5
	_m_jato.initial_velocity_max = 12.0
	_coluna.visible = true
	_m_col.set_shader_parameter("altura", 6.5)
	_m_col.set_shader_parameter("forca", 1.0)
	_jato.restart()
	_borrifo.restart()
	_bafo.restart()


# ---------------------------------------------------------------- o cone

## Um cone baixo de sínter feito no torno: o furo escuro e molhado no alto, a boca de mineral creme e as encostas
## brancas que descem até se enterrar no chão (o anel de fora fica 15 cm abaixo do relevo, sem brecha).
func _cone() -> void:
	# (raio, altura sobre o pé, cor, molhado); a última linha segue o chão
	var perfil := [
		[0.0, 0.35, Color(0.03, 0.028, 0.025), 1.0],
		[0.1, 0.55, Color(0.04, 0.035, 0.03), 1.0],
		[0.17, 0.95, Color(0.07, 0.055, 0.035), 1.0],
		[0.24, ALTO - 0.02, Color(0.17, 0.13, 0.06), 1.0],
		[0.36, ALTO, Color(0.19, 0.16, 0.085), 0.8],
		[0.62, 0.98, Color(0.16, 0.15, 0.135), 0.55],
		[1.05, 0.66, Color(0.17, 0.168, 0.16), 0.25],
		[1.6, 0.36, Color(0.165, 0.16, 0.15), 0.1],
		[2.3, 0.14, Color(0.15, 0.145, 0.135), 0.05],
		[3.1, -0.15, Color(0.19, 0.165, 0.1), 0.3],
	]
	var n := 40
	var linhas: Array = []
	for i in n:
		var a := TAU * i / n
		var dir := Vector2(cos(a), sin(a))
		var cal := 0.5 + 0.5 * sin(a * 5.0 + 0.4) * sin(a * 3.0)
		var pts: Array = []
		var cores: Array = []
		for j in perfil.size():
			var pr: Array = perfil[j]
			var r: float = pr[0] * (1.0 + 0.12 * cal * float(j > 3))
			var px := position.x + dir.x * r
			var pz := position.z + dir.y * r
			var chao := fontes.altura_malha(px, pz) - position.y
			var y: float = pr[1]
			if j == perfil.size() - 1:
				y = chao - 0.15
			elif j > 3:
				y = maxf(y + cal * 0.05, chao + 0.05)
			var cor: Color = pr[2]
			cor.a = pr[3]
			pts.append(Vector3(dir.x * r, y, dir.y * r))
			cores.append(cor)
		linhas.append([pts, cores])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var l0: Array = linhas[i]
		var l1: Array = linhas[(i + 1) % n]
		for j in perfil.size() - 1:
			FontesQuentes._quad_cima(st, [l0[0][j], l1[0][j], l1[0][j + 1], l0[0][j + 1]],
				[l0[1][j], l1[1][j], l1[1][j + 1], l0[1][j + 1]])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Cone"
	mi.mesh = st.commit()
	mi.material_override = fontes._mat_crosta
	add_child(mi)


# ---------------------------------------------------------------- a água e o vapor

func _particulas() -> void:
	var boca := Vector3(0.0, ALTO - 0.05, 0.0)
	# o jato: pingos que sobem e caem de volta
	_m_jato = ParticleProcessMaterial.new()
	_m_jato.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_m_jato.emission_sphere_radius = 0.22
	_m_jato.direction = Vector3.UP
	_m_jato.spread = 9.0
	_m_jato.initial_velocity_min = 9.5
	_m_jato.initial_velocity_max = 12.0
	_m_jato.gravity = Vector3(0.0, -9.8, 0.0)
	_m_jato.damping_min = 0.2
	_m_jato.damping_max = 0.6
	_m_jato.scale_min = 0.6
	_m_jato.scale_max = 1.2
	_m_jato.scale_curve = _curva([Vector2(0, 0.5), Vector2(0.4, 1.0), Vector2(1, 1.6)])
	_m_jato.color_ramp = _rampa([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)], [0.0, 0.06, 0.7, 1.0])
	_jato = _sistema("Jato", _m_jato, 1400, 2.3, Vector2(0.16, 0.7), PINGO, Color(0.84, 0.9, 0.93), true)
	_jato.position = boca
	# os borrifos no pé: a água que cai respinga em volta do cone
	var mb := ParticleProcessMaterial.new()
	mb.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mb.emission_ring_axis = Vector3.UP
	mb.emission_ring_radius = 2.2
	mb.emission_ring_inner_radius = 0.6
	mb.emission_ring_height = 0.05
	mb.direction = Vector3.UP
	mb.spread = 35.0
	mb.initial_velocity_min = 1.2
	mb.initial_velocity_max = 2.6
	mb.gravity = Vector3(0.0, -9.8, 0.0)
	mb.scale_min = 0.5
	mb.scale_max = 1.0
	mb.color_ramp = _rampa([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)], [0.0, 1.0])
	_borrifo = _sistema("Borrifo", mb, 320, 0.6, Vector2(0.12, 0.4), PINGO, Color(0.86, 0.9, 0.92), true)
	_borrifo.position = Vector3(0.0, 0.3, 0.0)
	# o bafo: o vapor grosso que sai junto e o vento leva
	var mv := ParticleProcessMaterial.new()
	mv.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mv.emission_box_extents = Vector3(0.3, 2.5, 0.3)
	mv.direction = Vector3.UP
	mv.spread = 12.0
	mv.initial_velocity_min = 2.0
	mv.initial_velocity_max = 4.0
	mv.gravity = Vector3(0.6, 0.15, 0.25)
	mv.damping_min = 0.4
	mv.damping_max = 0.8
	mv.angle_min = 0.0
	mv.angle_max = 360.0
	mv.angular_velocity_min = -12.0
	mv.angular_velocity_max = 12.0
	mv.scale_curve = _curva([Vector2(0, 0.4), Vector2(1, 2.4)])
	mv.color_ramp = _rampa([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)], [0.0, 0.2, 1.0])
	_bafo = _sistema("Bafo", mv, 90, 7.0, Vector2(5.0, 5.0), FUMACA, Color(0.92, 0.93, 0.94), false)
	_bafo.position = boca + Vector3(0.0, 2.6, 0.0)
	_bafo.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 30, 24))
	# o miolo: um tubo aberto que se alarga para cima (y de 0 a 1; o shader estica)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lados := 18
	var fatias := 12
	for j in fatias:
		var y0 := float(j) / fatias
		var y1 := float(j + 1) / fatias
		var r0 := 0.14 + 0.34 * pow(y0, 1.6)
		var r1 := 0.14 + 0.34 * pow(y1, 1.6)
		for i in lados:
			var a0 := TAU * i / lados
			var a1 := TAU * (i + 1) / lados
			var q := [Vector3(cos(a0) * r0, y0, sin(a0) * r0), Vector3(cos(a1) * r0, y0, sin(a1) * r0),
				Vector3(cos(a1) * r1, y1, sin(a1) * r1), Vector3(cos(a0) * r1, y1, sin(a0) * r1)]
			for k: int in [0, 2, 1, 0, 3, 2]:
				var qv: Vector3 = q[k]
				st.set_normal(Vector3(qv.x, 0.0, qv.z).normalized())
				st.add_vertex(qv)
	_m_col = ShaderMaterial.new()
	_m_col.shader = load("res://scripts/shaders/geiser_jato.gdshader")
	_m_col.set_shader_parameter("ruido", fontes.v._tex)
	_coluna = MeshInstance3D.new()
	_coluna.name = "Miolo"
	_coluna.mesh = st.commit()
	_coluna.material_override = _m_col
	_coluna.position = boca - Vector3(0.0, 0.25, 0.0)
	_coluna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_coluna.custom_aabb = AABB(Vector3(-1, 0, -1), Vector3(2, 8, 2))
	_coluna.visible = false
	add_child(_coluna)


## `em_pe`: a imagem fica de pé (gira só em volta do eixo vertical), comprida como um risco de água.
func _sistema(nome: String, m: ParticleProcessMaterial, quantos: int, vida: float, tam: Vector2, imagem: String, cor: Color, em_pe: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nome
	p.process_material = m
	p.amount = quantos
	p.lifetime = vida
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 12, 12))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 700.0
	p.visibility_range_end_margin = 80.0
	p.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var q := QuadMesh.new()
	q.size = tam
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if em_pe else BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = em_pe  # no modo de pé o tamanho da partícula (a curva) não viria sozinho
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = cor
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.6
	if ResourceLoader.exists(imagem):
		mat.albedo_texture = load(imagem)
	q.material = mat
	p.draw_pass_1 = q
	add_child(p)
	return p


static func _curva(pts: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 3.0
	for p: Vector2 in pts:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _rampa(cores: Array, offs: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(cores)
	g.offsets = PackedFloat32Array(offs)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
