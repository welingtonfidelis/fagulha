class_name CicloDia
extends Node
## O dia do vale: amanhecer, manhã com névoa, dia claro, tardezinha, pôr do sol e noite, com chuva às
## vezes. Devagar (pedido do usuário): um dia inteiro leva 60 minutos de jogo.
## Quem cria passa o ambiente, o céu e o sol. Outros sistemas leem `CicloDia.atual.hora` e `.chuva`.
## Para fotos e testes: `-- --hora 18.2` começa naquela hora e `-- --chuva` força a chuva;
## `-- --dia-rapido` faz o dia passar em 2 minutos.

static var atual: CicloDia
## Teste de luz e cor (branch visual-luz-e-cor): liga o visual novo. `-- --visual-antigo` desliga.
static var estilo_novo := true

var env: Environment
var ceu: ShaderMaterial
var sol: DirectionalLight3D
var camera: Node3D

var hora := 9.5  # 0 a 24
var minutos_por_dia := 60.0
var chuva := 0.0  # 0 a 1 (suave)
var mapa: Ilha  # para saber onde há água (a chuva some com a câmera debaixo dela)
var escuro := 0.0  # 0 a 1: a câmera está debaixo da terra (a luz do céu e do sol quase não chega)
var chovendo := false  # ligado de fora (testes), fica até desligarem
var parado := false  # hora fixa (fotos)
var nevoa_longe := false  # vale grande: névoa por distância, que embaça perto como antes mas deixa ver longe

var _prox_chuva := 0.0
var _fim_chuva := 0.0
var _t := 0.0
var _gotas: GPUParticles3D
var _cam_ant := Vector3.INF
var _cam_vel := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

# hora: [céu alto, horizonte, luz ambiente, energia ambiente, cor do sol, energia do sol,
#        cor da névoa, densidade da névoa, saturação, exposição, cor das nuvens]
const CHAVES := [
	[0.0, Color(0.022, 0.04, 0.11), Color(0.07, 0.11, 0.22), Color(0.16, 0.22, 0.40), 0.75, Color(0.55, 0.66, 1.0), 0.32, Color(0.05, 0.08, 0.15), 0.0030, 0.80, 1.0, Color(0.12, 0.15, 0.24)],
	[5.0, Color(0.02, 0.035, 0.10), Color(0.10, 0.13, 0.24), Color(0.18, 0.24, 0.42), 0.75, Color(0.55, 0.66, 1.0), 0.30, Color(0.08, 0.11, 0.20), 0.0040, 0.80, 1.0, Color(0.16, 0.19, 0.30)],
	[6.3, Color(0.10, 0.16, 0.36), Color(0.92, 0.55, 0.45), Color(0.50, 0.44, 0.56), 1.25, Color(1.0, 0.60, 0.45), 0.75, Color(0.74, 0.56, 0.56), 0.0060, 0.92, 0.95, Color(1.0, 0.70, 0.62)],
	[8.3, Color(0.16, 0.30, 0.56), Color(0.74, 0.80, 0.86), Color(0.42, 0.50, 0.62), 0.85, Color(1.0, 0.90, 0.76), 0.90, Color(0.76, 0.82, 0.88), 0.0055, 0.90, 0.92, Color(1.0, 0.97, 0.93)],
	[11.5, Color(0.14, 0.30, 0.58), Color(0.62, 0.78, 0.90), Color(0.42, 0.52, 0.66), 0.80, Color(1.0, 0.94, 0.82), 1.05, Color(0.66, 0.80, 0.92), 0.0022, 0.98, 0.92, Color(1.0, 0.98, 0.95)],
	[15.5, Color(0.14, 0.29, 0.56), Color(0.66, 0.78, 0.88), Color(0.42, 0.50, 0.64), 0.80, Color(1.0, 0.92, 0.78), 1.05, Color(0.68, 0.80, 0.90), 0.0022, 0.98, 0.92, Color(1.0, 0.97, 0.92)],
	[17.6, Color(0.10, 0.20, 0.44), Color(0.90, 0.66, 0.42), Color(0.36, 0.38, 0.52), 0.85, Color(1.0, 0.70, 0.42), 1.10, Color(0.82, 0.62, 0.46), 0.0030, 0.95, 0.92, Color(1.0, 0.78, 0.60)],
	[18.7, Color(0.07, 0.11, 0.30), Color(0.88, 0.48, 0.34), Color(0.50, 0.42, 0.52), 1.25, Color(1.0, 0.52, 0.32), 0.85, Color(0.70, 0.46, 0.42), 0.0036, 0.90, 0.95, Color(1.0, 0.60, 0.50)],
	[19.6, Color(0.03, 0.05, 0.16), Color(0.30, 0.24, 0.36), Color(0.28, 0.30, 0.48), 1.0, Color(0.60, 0.66, 1.0), 0.25, Color(0.20, 0.20, 0.32), 0.0034, 0.82, 1.0, Color(0.40, 0.34, 0.44)],
	[21.0, Color(0.022, 0.04, 0.11), Color(0.07, 0.11, 0.22), Color(0.16, 0.22, 0.40), 0.75, Color(0.55, 0.66, 1.0), 0.32, Color(0.05, 0.08, 0.15), 0.0030, 0.80, 1.0, Color(0.12, 0.15, 0.24)],
	[24.0, Color(0.022, 0.04, 0.11), Color(0.07, 0.11, 0.22), Color(0.16, 0.22, 0.40), 0.75, Color(0.55, 0.66, 1.0), 0.32, Color(0.05, 0.08, 0.15), 0.0030, 0.80, 1.0, Color(0.12, 0.15, 0.24)],
]
const NASCER := 6.0
const POR := 19.0


func _ready() -> void:
	atual = self
	_rng.randomize()
	var args := OS.get_cmdline_user_args()
	if "--hora" in args and args.find("--hora") + 1 < args.size():
		hora = float(args[args.find("--hora") + 1])
		parado = true
	estilo_novo = not ("--visual-antigo" in args)
	RenderingServer.global_shader_parameter_set("estilo_novo", 1.0 if estilo_novo else 0.0)
	if "--dia-rapido" in args:
		minutos_por_dia = 2.0
	_prox_chuva = _rng.randf_range(7.0, 14.0) * 60.0
	if "--chuva" in args:
		chovendo = true
		chuva = 1.0
		_fim_chuva = 1.0e9
	_criar_gotas()
	_aplicar()


func eh_noite() -> bool:
	return hora < NASCER - 0.4 or hora > POR + 0.5


func nome_momento() -> String:
	if hora < 5.0 or hora >= 20.5:
		return "noite"
	if hora < 7.2:
		return "amanhecer"
	if hora < 10.5:
		return "manhã"
	if hora < 16.5:
		return "dia"
	if hora < 18.2:
		return "tardezinha"
	return "anoitecer"


func _process(delta: float) -> void:
	if not parado:
		hora = fposmod(hora + delta * 24.0 / (minutos_por_dia * 60.0), 24.0)
	_t += delta
	# chuva de vez em quando
	if not chovendo and not parado and _t > _prox_chuva:
		chovendo = true
		_fim_chuva = _t + _rng.randf_range(2.5, 5.0) * 60.0
	if chovendo and _fim_chuva > 0.0 and _t > _fim_chuva:
		chovendo = false
		_fim_chuva = 0.0
		_prox_chuva = _t + _rng.randf_range(8.0, 16.0) * 60.0
	chuva = move_toward(chuva, 1.0 if chovendo else 0.0, delta / 25.0)
	Armadura.chuva = chuva
	_aplicar()
	if _gotas and camera:
		# a gota leva meio segundo para cair até a altura do olho: no voo o bloco de chuva nasce adiantado,
		# onde a câmera vai estar, senão o robô sai de baixo dele
		var cp: Vector3 = camera.global_position
		if delta > 0.0 and _cam_ant.is_finite() and cp.distance_to(_cam_ant) < 8.0:
			_cam_vel = _cam_vel.lerp((cp - _cam_ant) / delta, 1.0 - exp(-8.0 * delta))
		else:
			_cam_vel = Vector3.ZERO
		_cam_ant = cp
		_gotas.global_position = cp + Vector3(0, 9.0, 0) + _cam_vel * 0.5
		# debaixo d'água e dentro das cavernas não chove
		var coberto: bool = Cavernas.no_subsolo(cp) or (mapa != null and mapa.agua(cp.x, cp.z) > cp.y)
		_gotas.emitting = chuva > 0.05 and not coberto
		_gotas.visible = not coberto
		escuro = move_toward(escuro, 1.0 if Cavernas.no_subsolo(cp) else 0.0, delta * 1.2)
		_gotas.amount_ratio = clampf(chuva, 0.05, 1.0)


func _aplicar() -> void:
	if env == null:
		return
	var a: Array = CHAVES[0]
	var b: Array = CHAVES[CHAVES.size() - 1]
	for i in CHAVES.size() - 1:
		if hora >= CHAVES[i][0] and hora <= CHAVES[i + 1][0]:
			a = CHAVES[i]
			b = CHAVES[i + 1]
			break
	var t := clampf((hora - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var nublado := chuva
	var cinza := Color(0.42, 0.46, 0.50)
	var topo: Color = (a[1] as Color).lerp(b[1], t)
	var horiz: Color = (a[2] as Color).lerp(b[2], t)
	var amb: Color = (a[3] as Color).lerp(b[3], t)
	var luz_dia := clampf(lerpf(a[6], b[6], t), 0.0, 1.2)
	var nev: Color = (a[7] as Color).lerp(b[7], t)
	var claro := clampf(luz_dia, 0.25, 1.0)  # de noite a chuva não clareia o céu
	ceu.set_shader_parameter("topo", topo.lerp(cinza * 0.75 * claro, nublado * 0.85))
	ceu.set_shader_parameter("horizonte", horiz.lerp(cinza * 1.2 * claro, nublado * 0.85))
	ceu.set_shader_parameter("cor_nuvens", ((a[11] as Color).lerp(b[11], t)).lerp(cinza * 1.1 * claro, nublado))
	ceu.set_shader_parameter("nuvem_de", lerpf(0.55, 0.28, nublado))
	ceu.set_shader_parameter("nuvem_ate", lerpf(0.66, 0.6, nublado))
	env.ambient_light_color = amb.lerp(cinza * claro, nublado * 0.6)
	env.ambient_light_energy = lerpf(a[4], b[4], t) * lerpf(1.0, 1.1, nublado)
	env.fog_light_color = nev.lerp(cinza * 1.15 * claro, nublado * 0.8)
	var dens := lerpf(a[8], b[8], t) + nublado * 0.007
	if nevoa_longe:
		# quanto mais densa a hora (manhã, chuva), mais perto a névoa fecha
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_begin = 0.0
		env.fog_depth_curve = 0.3
		env.fog_depth_end = 6000.0 * 0.0022 / maxf(dens, 0.0005)
		env.fog_aerial_perspective = 1.0  # a névoa pega a cor do céu atrás: o horizonte do mar some no céu
		# do alto a névoa pesa menos, para a vista do vale não lavar
		var alto := 0.0
		var vista := get_viewport().get_camera_3d() if is_inside_tree() else null
		if vista:
			alto = smoothstep(50.0, 260.0, vista.global_position.y)
		env.fog_density = 0.9 * lerpf(1.0, 0.6, alto)
		var ag := OS.get_cmdline_user_args()
		if "--nevoa" in ag:  # experiência: densidade e curva fixas
			env.fog_density = float(ag[ag.find("--nevoa") + 1])
			env.fog_depth_curve = float(ag[ag.find("--nevoa") + 2])
	else:
		env.fog_density = dens
	env.adjustment_saturation = lerpf(a[9], b[9], t) * lerpf(1.0, 0.8, nublado)
	env.tonemap_exposure = lerpf(a[10], b[10], t)
	# sol de dia, lua de noite (a mesma luz)
	var dia := hora > NASCER and hora < POR
	var ang := 0.0
	var az := 0.0
	if dia:
		var k := (hora - NASCER) / (POR - NASCER)
		ang = sin(k * PI) * 56.0 + 4.0
		az = lerpf(95.0, 265.0, k)
	else:
		var k2 := fposmod(hora - POR, 24.0) / (24.0 - (POR - NASCER))
		ang = sin(k2 * PI) * 38.0 + 14.0
		az = lerpf(250.0, 110.0, k2)
	sol.rotation_degrees = Vector3(-ang, az, 0.0)
	sol.light_color = ((a[5] as Color).lerp(b[5], t)).lerp(Color(0.8, 0.84, 0.9), nublado * 0.8)
	sol.light_energy = lerpf(a[6], b[6], t) * lerpf(1.0, 0.45, nublado)
	if estilo_novo:
		_estilo(luz_dia, nublado, topo, horiz)


## O visual novo por cima das cores da hora: sombra azul-violeta, sol mais quente, a distância azulando,
## céu mais saturado com nuvens de borda firme, mais brilho e mais cor.
func _estilo(luz_dia: float, nublado: float, topo: Color, horiz: Color) -> void:
	var dia := clampf(luz_dia, 0.0, 1.0) * (1.0 - nublado * 0.7)
	# (com 0,6 e um violeta mais forte os paredões na sombra ficavam roxos)
	env.ambient_light_color = env.ambient_light_color.lerp(Color(0.42, 0.46, 0.80), 0.4 * dia)
	env.ambient_light_energy *= lerpf(1.0, 1.12, dia)
	sol.light_color = sol.light_color.lerp(Color(1.0, 0.86, 0.6), 0.45 * dia)
	sol.light_energy *= lerpf(1.0, 1.04, dia)
	# a distância azula mais cedo: a mata do fundo vira silhueta fria
	env.fog_light_color = env.fog_light_color.lerp(Color(0.46, 0.58, 0.96), 0.55 * dia)
	if nevoa_longe:
		env.fog_depth_end *= lerpf(1.0, 0.62, dia)
		env.fog_depth_curve = lerpf(0.3, 0.55, dia)
	ceu.set_shader_parameter("topo", topo.lerp(Color(0.13, 0.24, 0.80), 0.55 * dia))
	ceu.set_shader_parameter("horizonte", horiz.lerp(Color(0.70, 0.76, 0.98), 0.4 * dia))
	ceu.set_shader_parameter("volume", 1.0)
	ceu.set_shader_parameter("nuvem_de", lerpf(0.53, 0.28, nublado))
	ceu.set_shader_parameter("nuvem_ate", lerpf(0.56, 0.5, nublado))
	ceu.set_shader_parameter("escala", 0.075)
	env.adjustment_saturation *= 1.1
	env.adjustment_contrast = 1.07
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.tonemap_exposure *= 0.97
	sol.shadow_opacity = lerpf(1.0, 0.5, nublado)
	# debaixo da terra fica escuro de verdade: quem ilumina são os cristais e a luz do peito
	env.ambient_light_energy *= lerpf(1.0, 0.07, escuro)
	sol.light_energy *= lerpf(1.0, 0.04, escuro)


func _criar_gotas() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.84, 0.92, 0.38)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 2.0
	mat.distance_fade_max_distance = 6.0
	var gota := QuadMesh.new()
	gota.size = Vector2(0.018, 0.6)
	gota.material = mat
	var pp := ParticleProcessMaterial.new()
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pp.emission_box_extents = Vector3(20, 3.0, 20)
	pp.direction = Vector3(0.12, -1, 0.05)
	pp.spread = 2.0
	pp.initial_velocity_min = 15.0
	pp.initial_velocity_max = 19.0
	pp.gravity = Vector3.ZERO
	_gotas = GPUParticles3D.new()
	_gotas.amount = 3400
	_gotas.lifetime = 1.0
	_gotas.process_material = pp
	_gotas.draw_pass_1 = gota
	_gotas.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	_gotas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gotas.emitting = false
	_gotas.top_level = true
	add_child(_gotas)
