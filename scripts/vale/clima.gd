class_name Clima
extends Node3D
## O clima novo da 1.1 (doc §136), por cima do dia e da chuva do `CicloDia`. Tudo raro, para quem passeia:
## - **Neblina da manhã:** em umas quatro manhãs de cada dez, do clarear até umas nove horas, a névoa fecha e
##   faixas de neblina deitam no fundo do vale (só onde o chão é baixo), indo embora devagar com o sol.
## - **Tempestade:** uma chuva em cada três vira tempestade: o céu escurece mais e caem raios longe do robô
##   (nunca nele), com o clarão e o trovão chegando depois, conforme a distância.
## - **Arco-íris:** quando uma chuva forte acaba de dia, com o sol não muito alto, quase sempre aparece o
##   arco-íris do lado contrário ao sol, por uns dois minutos e meio.
## - **Aurora:** em uma noite de cada cinco, sem chuva, cortinas verdes e roxas no céu do norte, do meio da noite
##   até antes de clarear.
## Cada uma conta como cena rara numa foto do álbum (com ela no quadro).
## Quem cria passa `ciclo`, `camera` e `mapa`. Testes e fotos: `Clima.forcar` ("neblina", "tempestade",
## "arco" ou "aurora") ou `-- --clima <nome>`.

const NEBLINA_CHANCE := 0.4
const TEMPESTADE_CHANCE := 0.35
const ARCO_CHANCE := 0.8
const AURORA_CHANCE := 0.2
const VALE_BAIXO := 70.0  # a neblina deita onde o chão é mais baixo que isso (o fundo do vale)
const FAIXAS := 90
const ARCO_LONGE := 1500.0
const ARCO_ANGULO := 42.0  # graus: o raio do arco-íris visto do olho
const ARCO_DURA := 150.0

static var forcar := ""

var ciclo: CicloDia
var camera: CameraVoo
var mapa: Vale
var hoje_neblina := false
var hoje_aurora := false
var tempestade := false
var raios := 0  # testes
var arcos := 0  # testes
var arco := 0.0  # 0 a 1, o quanto se vê
var aurora := 0.0

var _rng := RandomNumberGenerator.new()
var _hora_ant := -1.0
var _chovia := false
var _chuva_forte := false
var _arco_resta := 0.0
var _prox_raio := 4.0
var _nevoa: MultiMeshInstance3D
var _mat_nevoa: StandardMaterial3D
var _faixas: Array = []  # [posição, largura, altura]
var _t_nevoa := 0.0
var _arco: MeshInstance3D
var _mat_arco: ShaderMaterial
var _aurora: Node3D
var _mats_aurora: Array[ShaderMaterial] = []
var _raio: MeshInstance3D
var _raio_t := 99.0
var _t_album := 0.0


func _ready() -> void:
	_rng.randomize()
	var args := OS.get_cmdline_user_args()
	if "--clima" in args and args.find("--clima") + 1 < args.size():
		forcar = String(args[args.find("--clima") + 1])
	hoje_neblina = _rng.randf() < NEBLINA_CHANCE
	hoje_aurora = _rng.randf() < AURORA_CHANCE
	_criar_nevoa()
	_criar_arco()
	_criar_aurora()
	_criar_raio()


# ---------------------------------------------------------------- o passo de cada quadro

func _process(delta: float) -> void:
	if ciclo == null or camera == null:
		return
	var h := ciclo.hora
	var cam := camera.cam
	var olho := cam.global_position
	# um sorteio por manhã e um por noite
	if _hora_ant >= 0.0:
		if _hora_ant < 4.0 and h >= 4.0:
			hoje_neblina = _rng.randf() < NEBLINA_CHANCE
		if _hora_ant < 20.0 and h >= 20.0:
			hoje_aurora = _rng.randf() < AURORA_CHANCE
	_hora_ant = h
	_neblina(delta, h, olho)
	_tempestade(delta, olho, cam)
	_arco_iris(delta, h, olho)
	_aurora_passo(delta, h, olho)
	# o relâmpago apaga depressa
	_raio_t += delta
	_raio.visible = (_raio_t < 0.07) or (_raio_t > 0.13 and _raio_t < 0.3)
	if _raio_t > 0.13 and _raio_t < 0.16:
		ciclo.clarao = maxf(ciclo.clarao, 0.8)
	ciclo.clarao = maxf(0.0, ciclo.clarao - delta * 4.5)
	# a foto do álbum: as cenas que estão no céu agora
	_t_album -= delta
	if _t_album <= 0.0:
		_t_album = 0.5
		if arco > 0.4:
			Album.marcar_cena("arco_iris", 1.2, _arco.global_transform * Vector3(0, 1, 0))
		if aurora > 0.4:
			Album.marcar_cena("aurora", 1.2, _aurora.global_position + Vector3(0, 130, 0))
		if ciclo.neblina > 0.5 and olho.y < VALE_BAIXO + 60.0:
			Album.marcar_cena("neblina", 1.2)


# ---------------------------------------------------------------- neblina

func _neblina(delta: float, h: float, olho: Vector3) -> void:
	var quer := hoje_neblina or forcar == "neblina"
	var alvo := 0.0
	if quer:
		alvo = smoothstep(4.6, 5.9, h) * (1.0 - smoothstep(8.3, 9.8, h))
		if forcar == "neblina":
			alvo = 1.0
	alvo *= 1.0 - smoothstep(110.0, 240.0, olho.y)
	alvo *= 1.0 - ciclo.chuva
	ciclo.neblina = move_toward(ciclo.neblina, alvo, delta / 8.0)
	var vis := ciclo.neblina
	_nevoa.visible = vis > 0.01
	if not _nevoa.visible:
		return
	var cor := ciclo.env.fog_light_color.lerp(Color(1, 1, 1), 0.35)
	cor.a = 0.3 * vis
	_mat_nevoa.albedo_color = cor
	_t_nevoa -= delta
	if _t_nevoa > 0.0:
		return
	_t_nevoa = 0.2
	var vento := Vector3(0.6, 0, 0.25)
	var mm := _nevoa.multimesh
	for i in FAIXAS:
		var f: Array = _faixas[i]
		var p: Vector3 = f[0]
		p += vento * 0.2
		if not p.is_finite() or Vector2(p.x - olho.x, p.z - olho.z).length() > 320.0:
			p = _lugar_faixa(olho, _faixas[i][0] == Vector3.INF)
		f[0] = p
		var t := Transform3D(Basis().scaled(Vector3(f[1], f[2], 1.0)), p)
		if not p.is_finite():
			t = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -9999, 0))
		mm.set_instance_transform(i, t)


## Um lugar para uma faixa de neblina: no fundo do vale, até 300 m (na volta, do lado de longe).
func _lugar_faixa(olho: Vector3, primeira: bool) -> Vector3:
	for tentativa in 6:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(25.0, 290.0) if primeira else _rng.randf_range(200.0, 300.0)
		var x := olho.x + cos(ang) * r
		var z := olho.z + sin(ang) * r
		var hy := mapa.altura(x, z)
		var agua := mapa.agua(x, z)
		if agua != -INF:
			hy = maxf(hy, agua)
		if hy < VALE_BAIXO:
			return Vector3(x, hy + _rng.randf_range(1.5, 6.0), z)
	return Vector3.INF


func _criar_nevoa() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	_mat_nevoa = StandardMaterial3D.new()
	_mat_nevoa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_nevoa.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_nevoa.albedo_texture = tex
	_mat_nevoa.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat_nevoa.billboard_keep_scale = true
	_mat_nevoa.proximity_fade_enabled = true
	_mat_nevoa.proximity_fade_distance = 6.0
	_mat_nevoa.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	_mat_nevoa.distance_fade_min_distance = 5.0
	_mat_nevoa.distance_fade_max_distance = 28.0
	_mat_nevoa.disable_fog = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _mat_nevoa
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = FAIXAS
	for i in FAIXAS:
		_faixas.append([Vector3.INF, _rng.randf_range(45.0, 85.0), _rng.randf_range(11.0, 19.0)])
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -9999, 0)))
	_nevoa = MultiMeshInstance3D.new()
	_nevoa.multimesh = mm
	_nevoa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nevoa.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 2e3, 2e5))
	_nevoa.visible = false
	add_child(_nevoa)


# ---------------------------------------------------------------- tempestade e raios

func _tempestade(delta: float, olho: Vector3, cam: Camera3D) -> void:
	if ciclo.chovendo and not _chovia:
		tempestade = forcar == "tempestade" or _rng.randf() < TEMPESTADE_CHANCE
	if not ciclo.chovendo:
		tempestade = forcar == "tempestade" and ciclo.chuva > 0.3
	_chovia = ciclo.chovendo
	ciclo.tempestade = move_toward(ciclo.tempestade, 1.0 if (tempestade and ciclo.chuva > 0.4) else 0.0, delta / 20.0)
	if ciclo.tempestade < 0.6 or Cavernas.no_subsolo(olho):
		return
	_prox_raio -= delta
	if _prox_raio <= 0.0:
		_prox_raio = _rng.randf_range(7.0, 20.0)
		raiar(olho, cam)


## Um raio longe (de 250 a 900 m), quase sempre na frente da câmera: o risco, o clarão e o trovão atrasado.
func raiar(olho: Vector3, cam: Camera3D) -> void:
	var frente := -cam.global_basis.z
	frente.y = 0.0
	frente = frente.normalized() if frente.length() > 0.01 else Vector3.FORWARD
	var ang := _rng.randf_range(-1.1, 1.1) if _rng.randf() < 0.65 else _rng.randf() * TAU
	var dir := frente.rotated(Vector3.UP, ang)
	var dist := _rng.randf_range(250.0, 900.0)
	var pe := olho + dir * dist
	pe.y = mapa.altura(pe.x, pe.z)
	var topo := pe + Vector3(_rng.randf_range(-60, 60), 420.0, _rng.randf_range(-60, 60))
	var pontos: Array[Vector3] = []
	var n := 16
	var desvio := Vector3.ZERO
	for i in n + 1:
		var k := float(i) / n
		desvio += Vector3(_rng.randf_range(-16, 16), 0, _rng.randf_range(-16, 16))
		desvio *= 0.85
		pontos.append(topo.lerp(pe, k) + desvio * (1.0 - k * 0.6))
	var galhos: Array = []
	for b in 3:
		var de := _rng.randi_range(3, 10)
		var g: Array[Vector3] = [pontos[de]]
		var lado := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		for j in 5:
			g.append(g[-1] + lado * _rng.randf_range(10, 22) + Vector3(_rng.randf_range(-5, 5), -_rng.randf_range(14, 26), _rng.randf_range(-5, 5)))
		galhos.append(g)
	var im := _raio.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_risco(im, pontos, 7.0, olho)
	for g: Array in galhos:
		_risco(im, g, 3.0, olho)
	im.surface_end()
	_raio_t = 0.0
	ciclo.clarao = 1.0
	raios += 1
	Album.marcar_cena("raio", 2.5, topo.lerp(pe, 0.5))
	var atraso := dist / 340.0
	var forca := clampf((dist - 250.0) / 650.0, 0.0, 1.0)
	get_tree().create_timer(atraso).timeout.connect(func() -> void:
		var som := AudioStreamPlayer.new()
		som.stream = Som.stream("trovao" if raios % 2 == 0 else "trovao_2")  # as gravações da chuva
		som.volume_db = lerpf(-3.0, -15.0, forca)
		som.pitch_scale = lerpf(1.05, 0.85, forca)
		add_child(som)
		som.play()
		som.finished.connect(som.queue_free))


func _risco(im: ImmediateMesh, pts: Array, largura: float, olho: Vector3) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var lado := (b - a).cross(olho - a).normalized() * largura * 0.5
		im.surface_add_vertex(a - lado)
		im.surface_add_vertex(a + lado)
		im.surface_add_vertex(b + lado)
		im.surface_add_vertex(a - lado)
		im.surface_add_vertex(b + lado)
		im.surface_add_vertex(b - lado)


func _criar_raio() -> void:
	_raio = MeshInstance3D.new()
	_raio.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(2.4, 2.6, 3.2)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	_raio.material_override = m
	_raio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raio.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 3e3, 2e5))
	_raio.top_level = true
	_raio.visible = false
	add_child(_raio)


# ---------------------------------------------------------------- arco-íris

func _arco_iris(delta: float, h: float, olho: Vector3) -> void:
	if ciclo.chuva > 0.7:
		_chuva_forte = true
	var elev := -ciclo.sol.rotation_degrees.x  # altura do sol (ou da lua) em graus
	var dia := h > 6.6 and h < 18.4
	if _chuva_forte and ciclo.chuva < 0.35 and not ciclo.chovendo:
		_chuva_forte = false
		if dia and elev < 38.0 and _rng.randf() < ARCO_CHANCE:
			_arco_resta = ARCO_DURA
			arcos += 1
	if forcar == "arco" and dia:
		_arco_resta = maxf(_arco_resta, 5.0)
	_arco_resta = maxf(0.0, _arco_resta - delta)
	var alvo := 1.0 if _arco_resta > 0.0 and dia and elev < 42.0 else 0.0
	alvo *= 1.0 - smoothstep(0.15, 0.6, ciclo.chuva)
	arco = move_toward(arco, alvo, delta / (10.0 if alvo > arco else 14.0))
	_arco.visible = arco > 0.01
	if not _arco.visible:
		return
	_mat_arco.set_shader_parameter("forca", arco)
	# o ponto do lado contrário ao sol (abaixo do horizonte); o arco é o círculo de 42° em volta dele
	var contra := -ciclo.sol.global_basis.z
	var cima := (Vector3.UP - contra * contra.dot(Vector3.UP)).normalized()
	var z := -contra
	var x := cima.cross(z).normalized()
	var r := ARCO_LONGE * tan(deg_to_rad(ARCO_ANGULO))
	_arco.global_transform = Transform3D(Basis(x, cima, z).scaled(Vector3(r, r, r)), olho + contra * ARCO_LONGE)


func _criar_arco() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 120
	var de := deg_to_rad(-40.0)
	var ate := deg_to_rad(220.0)
	var dentro := 0.95
	for i in n:
		var a0 := lerpf(de, ate, float(i) / n)
		var a1 := lerpf(de, ate, float(i + 1) / n)
		var v0 := float(i) / n
		var v1 := float(i + 1) / n
		var p00 := Vector3(cos(a0), sin(a0), 0) * dentro
		var p01 := Vector3(cos(a0), sin(a0), 0)
		var p10 := Vector3(cos(a1), sin(a1), 0) * dentro
		var p11 := Vector3(cos(a1), sin(a1), 0)
		for par: Array in [[p00, Vector2(0, v0)], [p01, Vector2(1, v0)], [p11, Vector2(1, v1)], [p00, Vector2(0, v0)], [p11, Vector2(1, v1)], [p10, Vector2(0, v1)]]:
			st.set_uv(par[1])
			st.add_vertex(par[0])
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform float forca = 0.0;
vec3 matiz(float h) {
	vec3 k = clamp(abs(fract(vec3(h) + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k;
}
void fragment() {
	float r = UV.x;  // 0 dentro (violeta) a 1 fora (vermelho)
	vec3 c = matiz((1.0 - r) * 0.76);
	float borda = smoothstep(0.0, 0.18, r) * smoothstep(1.0, 0.82, r);
	float pontas = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.88, UV.y);
	ALBEDO = c * borda * pontas * forca * 0.55;
}
"""
	_mat_arco = ShaderMaterial.new()
	_mat_arco.shader = sh
	_arco = MeshInstance3D.new()
	_arco.mesh = st.commit()
	_arco.material_override = _mat_arco
	_arco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arco.top_level = true
	_arco.custom_aabb = AABB(Vector3(-1.2, -1.2, -0.1), Vector3(2.4, 2.4, 0.2))
	_arco.visible = false
	add_child(_arco)


# ---------------------------------------------------------------- aurora

func _aurora_passo(delta: float, h: float, olho: Vector3) -> void:
	var noite := 0.0
	if h >= 21.0 or h < 4.0:
		var k := h - 21.0 if h >= 21.0 else h + 3.0  # 0 às 21 h, 7 às 4 h
		noite = smoothstep(0.0, 0.8, k) * (1.0 - smoothstep(5.8, 6.8, k))
	var alvo := noite if (hoje_aurora or forcar == "aurora") else 0.0
	if forcar == "aurora":
		alvo = 1.0
	alvo *= 1.0 - smoothstep(0.05, 0.3, ciclo.chuva)
	aurora = move_toward(aurora, alvo, delta / 25.0)
	_aurora.visible = aurora > 0.01
	if not _aurora.visible:
		return
	for m in _mats_aurora:
		m.set_shader_parameter("forca", aurora)
	_aurora.global_position = Vector3(olho.x, olho.y + 380.0, olho.z - 1700.0)


func _criar_aurora() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform float forca = 0.0;
uniform float semente = 0.0;
void vertex() {
	VERTEX.z += sin(VERTEX.x * 0.004 + TIME * 0.12 + semente) * 70.0 + sin(VERTEX.x * 0.011 - TIME * 0.2) * 25.0;
	VERTEX.x += sin(VERTEX.y * 0.01 + TIME * 0.3 + semente) * 12.0;
	VERTEX.y += (sin(VERTEX.x * 0.0045 + semente + TIME * 0.08) * 55.0 + sin(VERTEX.x * 0.013 - TIME * 0.15) * 20.0) * (1.0 - UV.y * 0.6);
}
void fragment() {
	float x = UV.x;
	float v = UV.y;  // 0 embaixo, 1 em cima
	float raios = 0.5 + 0.5 * sin(x * 160.0 + sin(x * 17.0 + TIME * 0.35 + semente) * 5.0 + TIME * 0.6);
	raios = mix(0.45, 1.0, raios * raios);
	float onda = 0.6 + 0.4 * sin(x * 9.0 - TIME * 0.25 + semente);
	float alt = smoothstep(0.0, 0.05, v) * mix(1.0, 0.35, smoothstep(0.1, 0.5, v)) * smoothstep(1.0, 0.6, v);
	float pontas = smoothstep(0.0, 0.18, x) * smoothstep(1.0, 0.82, x);
	vec3 cor = mix(vec3(0.15, 1.0, 0.5), vec3(0.65, 0.3, 1.0), smoothstep(0.25, 0.8, v));
	ALBEDO = cor * alt * pontas * raios * onda * forca * 0.85;
}
"""
	_aurora = Node3D.new()
	_aurora.top_level = true
	add_child(_aurora)
	for k in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 96
		var largura: float = [1900.0, 1300.0, 1100.0][k]
		var alto: float = [620.0, 480.0, 420.0][k]
		var desloca: Vector3 = [Vector3(0, 0, 0), Vector3(650, 50, -320), Vector3(-720, 20, 260)][k]
		for i in n:
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var x0 := (u0 - 0.5) * largura
			var x1 := (u1 - 0.5) * largura
			var z0 := sin(u0 * 7.0 + k) * 90.0
			var z1 := sin(u1 * 7.0 + k) * 90.0
			var a := Vector3(x0, 0, z0) + desloca
			var b := Vector3(x1, 0, z1) + desloca
			var c := a + Vector3(0, alto, -40)
			var d := b + Vector3(0, alto, -40)
			for par: Array in [[a, Vector2(u0, 0)], [b, Vector2(u1, 0)], [d, Vector2(u1, 1)], [a, Vector2(u0, 0)], [d, Vector2(u1, 1)], [c, Vector2(u0, 1)]]:
				st.set_uv(par[1])
				st.add_vertex(par[0])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("semente", k * 2.3)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-1500, -200, -500), Vector3(3000, 1100, 1000))
		_aurora.add_child(mi)
		_mats_aurora.append(m)
	_aurora.visible = false
