class_name QuedaDagua
extends RefCounted
## As quedas d'água do jogo, com volume (doc §164). Antes cada queda era uma fita aberta (um meio-cano): de frente
## passava, mas de lado virava uma linha fina ("a água caindo vista de lado sempre parece uma linha fina muito
## artificial", o usuário em 2026-11-24). Agora a água é um tubo fechado, mais grosso embaixo, com calombos descendo
## (o contorno mexe), e por fora corre uma casca de espuma branca rasgada em riscas, mais depressa que a água: rala
## no meio, cheia nas beiradas (o que se vê de lado) e quase toda branca no pé. No pé: bolhas de espuma, gotas
## pulando e névoa. Usada pela cachoeira do poço (CachoeiraAlta), pelas cortinas dos rios de degelo (TerraNova) e pela
## queda da represa (MarcosLeste).

const G := 9.8


## A água e a casca de espuma de uma queda, nas cores dadas (a do degelo é verde-água).
static func materiais(ruido: Texture2D, fundo := Color(0.15, 0.42, 0.62), meio := Color(0.33, 0.64, 0.82),
		claro := Color(0.63, 0.85, 0.94)) -> Array[ShaderMaterial]:
	var agua := ShaderMaterial.new()
	agua.shader = load("res://scripts/shaders/queda_dagua.gdshader")
	agua.set_shader_parameter("ruido", ruido)
	agua.set_shader_parameter("fundo", fundo)
	agua.set_shader_parameter("meio", meio)
	agua.set_shader_parameter("claro", claro)
	agua.set_shader_parameter("corte", 0.0)  # tubo fechado: sem recorte na beirada
	agua.set_shader_parameter("bolo", 0.9)
	var casca := agua.duplicate() as ShaderMaterial
	casca.set_shader_parameter("casca", 1.0)
	casca.set_shader_parameter("bolo", 1.4)
	return [agua, casca]


## A água rasa e deitada (em cima de um degrau): meio-cano aberto, mais espuma e corrente mais lenta.
static func material_rasa(agua: ShaderMaterial) -> ShaderMaterial:
	var m := agua.duplicate() as ShaderMaterial
	m.set_shader_parameter("espuma_pe", 0.0)
	m.set_shader_parameter("rasa", 1.0)
	m.set_shader_parameter("corte", 1.0)
	m.set_shader_parameter("bolo", 0.0)
	return m


## Uma queda inteira: a água (da largura `l0` em cima a `l1` embaixo e da grossura `g0` a `g1`) e a casca de
## espuma por fora. `pts` é o caminho do lado de trás da água (o que encosta na pedra), de cima para baixo; `lado3`
## é o rumo de uma beirada à outra, deitado.
static func queda(pai: Node3D, pts: PackedVector3Array, lado3: Vector3, l0: float, l1: float, g0: float, g1: float,
		mats: Array[ShaderMaterial], nome: String) -> void:
	fita(pai, pts, lado3, l0, l1, g0, g1, mats[0], nome, true)
	fita(pai, pts, lado3, l0 + 0.4, l1 + 1.2, g0 + 0.7, g1 + 1.2, mats[1], nome + "Espuma", true, 0.3)


## O caminho da água que sai de uma beirada: um trecho reto de `antes` até a `beira` e, dali, o arco de quem sai com
## velocidade de lado e cai (de lado cresce com o tempo, a queda com o quadrado dele) até `pouso`.
static func arco(antes: Vector3, beira: Vector3, pouso: Vector3, n := 26) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for k in 3:
		pts.append(antes.lerp(beira, k / 3.0))
	var altura := beira.y - pouso.y
	var tempo := sqrt(2.0 * altura / G)
	var lado := Vector3(pouso.x - beira.x, 0, pouso.z - beira.z)
	for k in n + 1:
		var tt := tempo * k / n
		pts.append(beira + lado * (tt / tempo) + Vector3(0, -0.5 * G * tt * tt, 0))
	return pts


## O quadro de cada ponto do caminho: [meio da seção, para fora, meia largura, meia fundura, quanto já passou (0 a 1),
## comprimento até ali]. "Para fora" é para cima no trecho deitado e para a frente na queda. `atras` recua a seção
## (a casca de espuma passa um pouco por trás da água, para as duas não se encostarem).
static func _quadros(pts: PackedVector3Array, lado3: Vector3, l0: float, l1: float, g0: float, g1: float, fechada: bool,
		atras: float) -> Array:
	var s := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		s.append(s[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total := s[s.size() - 1]
	var q: Array = []
	for i in pts.size():
		var tng := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var fora := lado3.cross(tng).normalized()
		var f := s[i] / total
		var meia_g := lerpf(g0, g1, f) * (0.5 if fechada else 1.0)
		# fechada, a seção é inteira e o caminho é o lado de trás dela (a água encosta na pedra e cresce para fora)
		var meio := pts[i] + fora * ((meia_g - atras) if fechada else 0.0)
		q.append([meio, fora, lerpf(l0, l1, f) * 0.5, meia_g, f, s[i]])
	return q


## Uma fita d'água com corpo. Aberta (`fechada` falso), a seção é um meio-cano (água rasa); fechada, é uma elipse
## inteira: de lado a queda tem a grossura de verdade. UV.x atravessa a fita (0 numa beira e 1 na outra, pela frente
## e por trás), UV.y é o comprimento (em 8 m), a cor do vértice guarda de 0 a 1 o quanto já passou (o pé vira espuma).
static func fita(pai: Node3D, pts: PackedVector3Array, lado3: Vector3, l0: float, l1: float, g0: float, g1: float,
		mat: Material, nome: String, fechada := false, atras := 0.0) -> MeshInstance3D:
	var quadros := _quadros(pts, lado3, l0, l1, g0, g1, fechada, atras)
	var colunas := 20 if fechada else 10
	var volta := TAU if fechada else PI
	var secoes: Array = []
	for qd: Array in quadros:
		var meio: Vector3 = qd[0]
		var fora: Vector3 = qd[1]
		var larg: float = qd[2]
		var gordo: float = qd[3]
		var sec: Array = []
		for c in colunas + 1:
			var ang := volta * float(c) / colunas
			var p := meio - lado3 * cos(ang) * larg + fora * sin(ang) * gordo
			var nrm := (fora * sin(ang) / gordo - lado3 * cos(ang) / larg).normalized()
			sec.append([p, nrm, Vector2((1.0 - cos(ang)) * 0.5, float(qd[5]) / 8.0), qd[4]])
		secoes.append(sec)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in secoes.size() - 1:
		var a: Array = secoes[i]
		var b: Array = secoes[i + 1]
		for c in colunas:
			for v: Array in [a[c], a[c + 1], b[c + 1], a[c], b[c + 1], b[c]]:
				st.set_color(Color(v[3], 0, 0))
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	if fechada:
		# as pontas tampadas (de cima, na beirada, via-se a boca oca do tubo)
		for ponta: int in [0, secoes.size() - 1]:
			var anel: Array = secoes[ponta]
			var qd: Array = quadros[ponta]
			var tng := (pts[mini(ponta + 1, pts.size() - 1)] - pts[maxi(ponta - 1, 0)]).normalized() * (-1.0 if ponta == 0 else 1.0)
			for c in colunas:
				var tri: Array = [anel[c], anel[c + 1]] if ponta > 0 else [anel[c + 1], anel[c]]
				for v: Array in [[qd[0], Vector2(0.5, float(qd[5]) / 8.0)], [tri[0][0], tri[0][2]], [tri[1][0], tri[1][2]]]:
					st.set_color(Color(qd[4], 0, 0))
					st.set_normal(tng)
					st.set_uv(v[1])
					st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


## O pé de uma queda: bolhas de espuma e gotas pulando (a névoa fica com quem chama, que sabe o tamanho dela).
static func pe(pai: Node3D, onde: Vector3, raio: float, semente: int) -> void:
	espuma(pai, onde, raio, clampi(int(raio * 4.0), 6, 16), semente)
	gotas(pai, onde, raio * 0.8, clampi(int(raio * 8.0), 12, 30))


## As ondas onde a queda bate na água: um disco deitado na linha d'água (`onde`), desenhado depois da água (que é
## transparente e o cobria), com a tinta, os anéis claros saindo do pé e a espuma boiando. `raio` é até onde os
## anéis vão; `poco` (x, z e raio), quando dado, deixa o poço inteiro um pouco mais azul.
static func ondas(pai: Node3D, onde: Vector3, ruido: Texture2D, raio: float, azul := Color(0.30, 0.62, 0.82), poco := Vector3.ZERO) -> void:
	var disco := PlaneMesh.new()
	var meia := raio * 1.1
	if poco.z > 0.0:
		meia = maxf(meia, Vector2(poco.x - onde.x, poco.y - onde.z).length() + poco.z * 1.25)
	disco.size = Vector2(meia, meia) * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/ondas_poco.gdshader")
	mat.set_shader_parameter("ruido", ruido)
	mat.set_shader_parameter("raio", raio)
	mat.set_shader_parameter("azul", azul)
	if poco.z > 0.0:
		mat.set_shader_parameter("poco_centro", Vector2(poco.x - onde.x, poco.y - onde.z))
		mat.set_shader_parameter("poco_raio", poco.z)
	mat.render_priority = 2
	disco.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Ondas"
	mi.mesh = disco
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = onde
	pai.add_child(mi)


## Bolhas brancas de espuma, como nuvenzinhas, crescendo e sumindo sem parar onde a água bate.
static func espuma(pai: Node3D, onde: Vector3, raio: float, n: int, semente: int) -> void:
	var bola := SphereMesh.new()
	bola.radius = 0.5
	bola.height = 1.0
	bola.radial_segments = 10
	bola.rings = 6
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/espuma_bolha.gdshader")
	bola.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = bola
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	for i in n:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * raio
		var s := rng.randf_range(1.2, 2.4) * (1.0 - r / raio * 0.4) * clampf(raio / 3.0, 0.6, 1.0)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 0.8, s)), Vector3(cos(ang) * r, 0.0, sin(ang) * r)))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Espuma"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.position = onde
	pai.add_child(mmi)


## Gotas pulando de onde a água bate.
static func gotas(pai: Node3D, onde: Vector3, raio: float, n: int) -> void:
	var gota := SphereMesh.new()
	gota.radius = 0.13
	gota.height = 0.26
	gota.radial_segments = 6
	gota.rings = 3
	var mg := StandardMaterial3D.new()
	mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mg.albedo_color = Color(0.93, 0.97, 1.0)
	gota.material = mg
	var pp := ParticleProcessMaterial.new()
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pp.emission_sphere_radius = raio
	pp.direction = Vector3(0, 1, 0)
	pp.spread = 55.0
	pp.initial_velocity_min = 3.0
	pp.initial_velocity_max = 6.5
	pp.gravity = Vector3(0, -G, 0)
	pp.scale_min = 0.6
	pp.scale_max = 1.4
	var g := GPUParticles3D.new()
	g.name = "Gotas"
	g.amount = n
	g.lifetime = 1.2
	g.process_material = pp
	g.draw_pass_1 = gota
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_aabb = AABB(Vector3(-10, -4, -10), Vector3(20, 14, 20))
	g.position = onde
	pai.add_child(g)


## A névoa de respingo: fumaça clara subindo devagar numa faixa de `largura` de cada lado, de través ao `lado3`.
static func nevoa(pai: Node3D, onde: Vector3, lado3: Vector3, largura: float, n: int) -> void:
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.vertex_color_use_as_albedo = true
	mp.albedo_color = Color(1, 1, 1, 0.26)
	if ResourceLoader.exists("res://assets/fx/kenney/smoke_04.png"):
		mp.albedo_texture = load("res://assets/fx/kenney/smoke_04.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 5.0)
	quad.material = mp
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gr.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = gr
	var pp := ParticleProcessMaterial.new()
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pp.emission_box_extents = Vector3(largura, 0.5, 2.0)
	pp.direction = Vector3(0, 1, 0)
	pp.spread = 40.0
	pp.initial_velocity_min = 1.0
	pp.initial_velocity_max = 2.6
	pp.gravity = Vector3(0, 0.2, 0)
	pp.scale_min = 0.7
	pp.scale_max = 1.6
	pp.color_ramp = gt
	var nev := GPUParticles3D.new()
	nev.name = "Nevoa"
	nev.amount = n
	nev.lifetime = 3.2
	nev.process_material = pp
	nev.draw_pass_1 = quad
	nev.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nev.visibility_aabb = AABB(Vector3(-16, -4, -16), Vector3(32, 20, 32))
	nev.position = onde
	nev.rotation.y = atan2(lado3.x, lado3.z) - PI * 0.5
	pai.add_child(nev)
