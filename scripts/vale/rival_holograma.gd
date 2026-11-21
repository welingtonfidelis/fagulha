class_name RivalHolograma
extends Node3D
## O rival das corridas (1.1, doc §136): a gravação do recorde de um piloto de teste de antigamente, tocada pela
## baliza como holograma (o mesmo azul da simulação). É o robô do jogo em luz, deitado no voo, com um rastro
## curto. Faz o caminho dos aros numa velocidade fixa por rota; quem cria (`Rotas`) diz o caminho e manda andar.

const COR := Color(0.35, 0.95, 0.85)

var caminho: Curve3D
var vel := 20.0
var andando := false
var chegou := false
var dist := 0.0

var _t := 0.0
var _largada := Vector3.ZERO
var _olhar := Vector3.FORWARD
var _modelo: Node3D
var _mat: ShaderMaterial
var _rastro: CPUParticles3D


func _ready() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(0.35, 0.95, 0.85);
uniform float forca = 1.0;
varying vec3 mundo;
void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float linhas = 0.6 + 0.4 * step(0.5, fract(mundo.y * 9.0 - TIME * 2.0));
	ALBEDO = cor * (0.25 + borda * 1.6) * linhas * forca;
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("cor", COR)
	var cena := load(ArmaduraVisual.MODELO) as PackedScene
	_modelo = Node3D.new()
	add_child(_modelo)
	if cena:
		var robo := cena.instantiate() as Node3D
		robo.rotation.y = PI  # o modelo olha para +Z; aqui a frente é -Z
		_modelo.add_child(robo)
		for mi in robo.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = _mat
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var luz := OmniLight3D.new()
	luz.light_color = COR
	luz.light_energy = 1.2
	luz.omni_range = 5.0
	luz.position = Vector3(0, 0.8, 0)
	add_child(luz)
	_rastro = CPUParticles3D.new()
	_rastro.local_coords = false
	_rastro.direction = Vector3.ZERO
	_rastro.spread = 0.0
	_rastro.initial_velocity_min = 0.0
	_rastro.initial_velocity_max = 0.4
	_rastro.gravity = Vector3.ZERO
	_rastro.scale_amount_min = 0.5
	_rastro.scale_amount_max = 0.9
	# o rastro afina e some: faíscas, não uma barra
	var some := Gradient.new()
	some.set_color(0, Color(0.9, 0.9, 0.9))  # luz somada: apagar é ir para o preto (o alfa não conta)
	some.set_color(1, Color(0, 0, 0))
	_rastro.color_ramp = some
	var afina := Curve.new()
	afina.add_point(Vector2(0, 1))
	afina.add_point(Vector2(1, 0.15))
	_rastro.scale_amount_curve = afina
	_rastro.amount = 60
	_rastro.lifetime = 0.45
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3)
	var bolinha := GradientTexture2D.new()  # faísca redonda e macia (não um quadrado)
	bolinha.fill = GradientTexture2D.FILL_RADIAL
	bolinha.fill_from = Vector2(0.5, 0.5)
	bolinha.fill_to = Vector2(1.0, 0.5)
	bolinha.width = 32
	bolinha.height = 32
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1))
	g.set_color(1, Color(0, 0, 0))
	bolinha.gradient = g
	var m := StandardMaterial3D.new()
	m.albedo_texture = bolinha
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = COR * 0.8
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	q.material = m
	_rastro.mesh = q
	_rastro.position = Vector3(0, 0.9, 0.6)
	_rastro.emitting = false
	add_child(_rastro)


## De pé na baliza, esperando a largada (de frente para o primeiro aro).
func esperar(onde: Vector3, olhar: Vector3) -> void:
	_largada = onde
	_olhar = olhar
	global_position = onde
	var d := olhar - onde
	d.y = 0.0
	if d.length() > 0.1:
		look_at(onde + d, Vector3.UP)
	_modelo.rotation.x = 0.0


func largar() -> void:
	andando = true
	_rastro.emitting = true


## De volta à baliza (o robô pousou de novo ali sem passar por nenhum aro).
func voltar() -> void:
	andando = false
	chegou = false
	dist = 0.0
	_rastro.emitting = false
	esperar(_largada, _olhar)


func _process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("forca", 0.85 + 0.15 * sin(_t * 9.0))
	if not andando or caminho == null or chegou:
		return
	# sai devagar da baliza e chega na velocidade em uns dois segundos
	var v := vel * clampf(0.35 + dist / (vel * 2.0), 0.35, 1.0)
	dist += v * delta
	var total := caminho.get_baked_length()
	if dist >= total:
		dist = total
		chegou = true
		_rastro.emitting = false
	var p := caminho.sample_baked(dist, true)
	var a := caminho.sample_baked(minf(dist + 3.0, total), true)
	global_position = p
	var dir := a - p
	if dir.length() > 0.1:
		look_at(a, Vector3.UP if absf(dir.normalized().y) < 0.97 else Vector3.FORWARD)
	# deitado no voo, como o robô do jogador
	_modelo.rotation.x = lerpf(_modelo.rotation.x, -1.25, 1.0 - exp(-4.0 * delta))
