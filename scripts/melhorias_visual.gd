class_name MelhoriasVisual
extends RefCounted
## Peças das melhorias presas ao robô. Cada peça é montada no "espaço do robô": x para a direita dele,
## y para cima, z para trás (a frente é -z), tudo em alturas do robô (1.0 = 2,6 m de porte; a cabeça acaba em 0,92).
## Feitas para o robô do vale (`assets/vale/robo_v1.glb`): cada grupo fica preso a uma junta dele.

const NOMES := ["radiador", "bocais", "asas", "barbatanas", "amortecedores", "antena", "farol", "celulas", "scanner", "mira"]

static var minimo := true  # versão discreta: peças pequenas, rentes ao corpo
static var asas_fator := 0.0  # 0 recolhidas dentro da mochila, 1 abertas (só planando)
static var farol_aceso := true
static var jato := false  # mostra a chama dos bocais novos (no ar)
static var farois_abertos := true  # faróis de ombro: tampa levantada e leds acesos
static var ESCURO := Color(0.3, 0.33, 0.37)
static var CLARO := Color(0.86, 0.84, 0.78)
static var VERDE := Color(0.4, 0.72, 0.68)
const ACO := Color(0.6, 0.63, 0.67)
const PESSEGO := Color(1.0, 0.62, 0.3)

static var _mats := {}


## As cores saem do próprio modelo (placa escura, placa clara e detalhe), para as peças não destoarem.
static func _ler_cores(v: ArmaduraVisual) -> void:
	for n in v.modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null:
				continue
			match m.resource_name:
				"placa_escura": ESCURO = m.albedo_color
				"placa_clara": CLARO = m.albedo_color
				"detalhe": VERDE = m.albedo_color


## Peça pintada no estilo do vale (luz em faixas); com `luz`, peça acesa.
static func _mat(cor: Color, luz := 0.0, _metal := 0.0) -> Material:
	var chave := "%s %.2f %s" % [cor.to_html(), luz, ArmaduraVisual.toon]
	if not _mats.has(chave):
		if luz <= 0.0 and ArmaduraVisual.toon:
			var mt := ShaderMaterial.new()
			mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
			mt.set_shader_parameter("cor", cor)
			mt.set_shader_parameter("brilho_borda", 0.18)
			_mats[chave] = mt
		else:
			var m := StandardMaterial3D.new()
			m.albedo_color = cor
			m.roughness = 0.62
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			if luz > 0.0:
				m.emission_enabled = true
				m.emission = cor
				m.emission_energy_multiplier = luz
			_mats[chave] = m
	return _mats[chave]


static func _mat_chama(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = cor
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Nó preso a uma junta do robô (tronco, cabeca, costas, joelhoE...) cujos filhos são postos no espaço
## do robô. Chamar com o robô na pose de descanso (logo depois de criado).
static func _ancora(v: ArmaduraVisual, junta: String) -> Node3D:
	if not v.has_meta("descanso"):
		preparar(v)
	var pai := v.j[junta] as Node3D
	var h := ArmaduraVisual.ALTURA_ALVO * Armadura.porte
	var no := Node3D.new()
	pai.add_child(no)
	no.transform = (v.get_meta("descanso")[junta] as Transform3D) * Transform3D(Basis.from_scale(Vector3.ONE * h), Vector3.ZERO)
	(v.get_meta("ancoras") as Array).append(no)
	return no


## Guarda onde cada junta está na pose de descanso (chamar logo que o robô é criado): as peças são
## postas em relação a isso, então podem ser vestidas depois, com o robô em qualquer pose.
static func preparar(v: ArmaduraVisual) -> void:
	var descanso := {}
	for k in v.j:
		if v.j[k] != null:
			descanso[k] = (v.j[k] as Node3D).global_transform.affine_inverse() * v.global_transform
	v.set_meta("descanso", descanso)
	v.set_meta("ancoras", [])


## Tira todas as peças e devolve o robô ao básico.
static func limpar(v: ArmaduraVisual) -> void:
	if v.has_meta("ancoras"):
		for no in v.get_meta("ancoras"):
			if is_instance_valid(no):
				(no as Node).queue_free()
		v.set_meta("ancoras", [])
	for n in v.modelo.find_children("brasa_pe*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visible = true
	var alfa := v.mat_chama.albedo_color.a
	v.mat_chama.albedo_color = Color(1.0, 0.62, 0.3, alfa)
	basico(v)


static func por_asas(nos: Array, fator: float) -> void:
	for g: Node3D in nos:
		var s: float = g.get_meta("lado")
		g.basis = Basis.from_euler(Vector3(0, deg_to_rad(-s * 16.0), deg_to_rad(-s * 4.0))) * Basis.from_scale(Vector3(s * maxf(fator, 0.001), 1, 1))
		g.visible = fator > 0.01


static func por_farol(nos: Array, aceso: bool) -> void:
	(nos[0] as Node3D).visible = aceso
	(nos[1] as Node3D).visible = aceso


## A cada quadro, no jogo: as asas saem da mochila só planando (motor desligado, sem cair a pique),
## a luz do peito segue o botão e a ponta da antena pulsa.
static func animar(v: ArmaduraVisual, a: Armadura, delta: float) -> void:
	if v.pecas.has("asas"):
		var abre := (a.estado == Armadura.Estado.PLANAR and a.dir_voo.y > -0.8 and not a.em_pane) or v.previa
		v.asas_f = move_toward(v.asas_f, 1.0 if abre else 0.0, delta * 3.2)
		por_asas(v.pecas["asas"], smoothstep(0.0, 1.0, v.asas_f))
	if v.pecas.has("farol"):
		por_farol(v.pecas["farol"], (a.luz_ligada and not a.em_pane) or v.previa)
	if v.pecas.has("escudo"):
		# o emissor apaga enquanto o escudo recarrega; quando ele engole um acerto, uma bolha pisca em volta
		((v.pecas["escudo"] as Array)[0] as Node3D).visible = a.escudo_t <= 0.0
		if a.escudos_gastos != v.escudos_vistos:
			v.escudos_vistos = a.escudos_gastos
			bolha_escudo(v, a.altura_corpo())
	if v.pecas.has("antena"):
		var luz := (v.pecas["antena"] as Array)[0] as Node3D
		luz.scale = Vector3.ONE * (1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.006))


static func _grupo(pai: Node3D, pos: Vector3, graus := Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees = graus
	pai.add_child(g)
	return g


static func _por(pai: Node3D, malha: Mesh, pos: Vector3, graus: Vector3, mat: Material, esc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = graus
	mi.scale = esc
	pai.add_child(mi)
	return mi


static func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, graus := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = tam
	return _por(pai, m, pos, graus, mat)


static func _cil(pai: Node3D, r_topo: float, r_base: float, alt: float, pos: Vector3, mat: Material, graus := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_topo
	m.bottom_radius = r_base
	m.height = alt
	m.radial_segments = 14
	m.rings = 1
	return _por(pai, m, pos, graus, mat)


static func _bola(pai: Node3D, r: float, pos: Vector3, mat: Material, esc := Vector3.ONE, graus := Vector3.ZERO) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 7
	return _por(pai, m, pos, graus, mat, esc)


## Chapa: contorno convexo no plano XY, com espessura em Z.
static func _chapa(pai: Node3D, pts: PackedVector2Array, esp: float, pos: Vector3, mat: Material, graus := Vector3.ZERO, esc := Vector3.ONE) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := pts.size()
	# cada face vai nas duas ordens: a chapa aparece dos dois lados, mesmo espelhada
	for lado in [-1.0, 1.0]:
		for i in range(1, n - 1):
			for ordem in [[0, i, i + 1], [0, i + 1, i]]:
				for k in ordem:
					st.add_vertex(Vector3(pts[k].x, pts[k].y, lado * esp * 0.5))
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var q := [Vector3(a.x, a.y, -esp * 0.5), Vector3(b.x, b.y, -esp * 0.5), Vector3(b.x, b.y, esp * 0.5), Vector3(a.x, a.y, esp * 0.5)]
		for k in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
			st.add_vertex(q[k])
	st.generate_normals()
	return _por(pai, st.commit(), pos, graus, mat, esc)


## O robô começa básico: sem o radiador da mochila (painel e grades), que só aparece com a melhoria.
static func basico(v: ArmaduraVisual, com_radiador := false) -> void:
	for n in v.modelo.find_children("*", "MeshInstance3D", true, false):
		var nome := String(n.name)
		if nome == "radiador" or nome.begins_with("grade"):
			(n as MeshInstance3D).visible = com_radiador


## Monta as peças pedidas. Devolve nome -> lista de nós (para animar depois).
static func vestir(v: ArmaduraVisual, pecas: Array) -> Dictionary:
	_ler_cores(v)
	var feito := {}
	if minimo:
		for nome in pecas:
			feito[nome] = _minimo(v, nome)
		return feito
	for nome in pecas:
		match nome:
			"radiador": feito[nome] = _radiador(v)
			"bocais": feito[nome] = _bocais(v)
			"asas": feito[nome] = _asas(v)
			"barbatanas": feito[nome] = _barbatanas(v)
			"amortecedores": feito[nome] = _amortecedores(v)
			"antena": feito[nome] = _antena(v)
			"farois": feito[nome] = _farois(v)
			"celulas": feito[nome] = _celulas(v)
			"scanner": feito[nome] = _scanner(v)
	return feito


## Radiador de aletas: seis aletas de fio rubro sobre a grade da mochila.
static func _radiador(v: ArmaduraVisual) -> Array:
	var a := _ancora(v, "costas")
	var g := _grupo(a, Vector3(0, 0.569, 0.15))
	_caixa(g, Vector3(0.104, 0.012, 0.022), Vector3(0, 0.056, 0.008), _mat(VERDE))
	_caixa(g, Vector3(0.104, 0.012, 0.022), Vector3(0, -0.056, 0.008), _mat(VERDE))
	for i in 6:
		var x := (i - 2.5) * 0.017
		var al := _grupo(g, Vector3(x, 0, 0), Vector3(0, (i - 2.5) * 8.0, 0))
		_caixa(al, Vector3(0.006, 0.1, 0.04), Vector3(0, 0, 0.02), _mat(ESCURO))
		_caixa(al, Vector3(0.0075, 0.1, 0.008), Vector3(0, 0, 0.043), _mat(Color(1.0, 0.3, 0.08), 2.4))
	return [g]


## Bocais largos: um sino atrás de cada bota, com chama comprida e azulada.
static func _bocais(v: ArmaduraVisual) -> Array:
	var nos := []
	for s in [-1.0, 1.0]:
		var a := _ancora(v, "joelhoE" if s < 0.0 else "joelhoD")
		var g := _grupo(a, Vector3(s * 0.076, 0.13, 0.082), Vector3(-10, 0, 0))
		_caixa(g, Vector3(0.05, 0.05, 0.03), Vector3(0, 0.03, -0.012), _mat(ESCURO))
		_cil(g, 0.02, 0.024, 0.036, Vector3(0, 0.022, 0.004), _mat(VERDE))
		_cil(g, 0.021, 0.04, 0.062, Vector3(0, -0.026, 0.004), _mat(ESCURO))
		_cil(g, 0.043, 0.043, 0.01, Vector3(0, -0.058, 0.004), _mat(CLARO))
		_cil(g, 0.033, 0.033, 0.004, Vector3(0, -0.062, 0.004), _mat(Color(0.45, 0.8, 1.0), 3.0))
		_cil(g, 0.033, 0.0, 0.22, Vector3(0, -0.172, 0.004), _mat_chama(Color(0.35, 0.65, 1.0, 0.75)))
		_cil(g, 0.017, 0.0, 0.13, Vector3(0, -0.127, 0.004), _mat_chama(Color(0.85, 0.95, 1.0, 0.9)))
		nos.append(g)
	return nos


## Asas de planar: duas asas curtas nos lados da mochila.
static func _asas(v: ArmaduraVisual) -> Array:
	var a := _ancora(v, "costas")
	var nos := []
	for s in [-1.0, 1.0]:
		var g := _grupo(a, Vector3(s * 0.074, 0.6, 0.12))
		# espelho pela base (escala negativa num eixo só não sobrevive a `scale`)
		g.basis = Basis.from_euler(Vector3(0, deg_to_rad(-s * 24.0), deg_to_rad(-s * 5.0))) * Basis.from_scale(Vector3(s, 1, 1))
		_cil(g, 0.017, 0.017, 0.07, Vector3(0, -0.012, 0), _mat(ESCURO))
		_chapa(g, PackedVector2Array([Vector2(0.008, 0.034), Vector2(0.2, 0.016), Vector2(0.2, -0.054), Vector2(0.008, -0.082)]),
			0.012, Vector3.ZERO, _mat(CLARO))
		_chapa(g, PackedVector2Array([Vector2(0.2, 0.016), Vector2(0.262, 0.004), Vector2(0.276, -0.026), Vector2(0.2, -0.054)]),
			0.01, Vector3.ZERO, _mat(VERDE))
		_chapa(g, PackedVector2Array([Vector2(0.03, -0.08), Vector2(0.2, -0.054), Vector2(0.2, -0.068), Vector2(0.03, -0.097)]),
			0.007, Vector3.ZERO, _mat(ESCURO))
		_caixa(g, Vector3(0.012, 0.008, 0.014), Vector3(0.27, -0.012, 0), _mat(PESSEGO, 3.0))
		nos.append(g)
	return nos


## Barbatanas: uma lâmina por fora de cada antebraço.
static func _barbatanas(v: ArmaduraVisual) -> Array:
	var nos := []
	for s in [-1.0, 1.0]:
		var a := _ancora(v, "cotoveloE" if s < 0.0 else "cotoveloD")
		var g := _grupo(a, Vector3(s * 0.244, 0.425, 0.0))
		g.basis = Basis.from_euler(Vector3(0, deg_to_rad(-s * 35.0), 0)) * Basis.from_scale(Vector3(s, 1, 1))
		_chapa(g, PackedVector2Array([Vector2(0, 0.058), Vector2(0.04, 0.035), Vector2(0.088, -0.04), Vector2(0.07, -0.078), Vector2(0, -0.066)]),
			0.008, Vector3.ZERO, _mat(VERDE))
		_chapa(g, PackedVector2Array([Vector2(-0.006, 0.064), Vector2(0.016, 0.05), Vector2(0.016, -0.064), Vector2(-0.006, -0.072)]),
			0.022, Vector3.ZERO, _mat(ESCURO))
		for i in 3:
			_caixa(g, Vector3(0.046 - i * 0.006, 0.0045, 0.0095), Vector3(0.04, 0.012 - i * 0.027, 0), _mat(CLARO), Vector3(0, 0, -40))
		nos.append(g)
	return nos


## Amortecedores: um pistão por fora de cada bota.
static func _amortecedores(v: ArmaduraVisual) -> Array:
	var nos := []
	for s in [-1.0, 1.0]:
		var a := _ancora(v, "joelhoE" if s < 0.0 else "joelhoD")
		var g := _grupo(a, Vector3(s * 0.142, 0.135, 0.0))
		_cil(g, 0.016, 0.016, 0.07, Vector3(0, 0.04, 0), _mat(ESCURO))
		_cil(g, 0.019, 0.019, 0.012, Vector3(0, 0.005, 0), _mat(VERDE))
		_cil(g, 0.019, 0.019, 0.012, Vector3(0, 0.075, 0), _mat(VERDE))
		_cil(g, 0.008, 0.008, 0.1, Vector3(0, -0.045, 0), _mat(ACO))
		for i in 4:
			_cil(g, 0.014, 0.014, 0.007, Vector3(0, -0.012 - i * 0.02, 0), _mat(CLARO))
		_bola(g, 0.019, Vector3(0, 0.083, 0), _mat(ESCURO))
		_bola(g, 0.019, Vector3(0, -0.095, 0), _mat(ESCURO))
		_caixa(g, Vector3(0.03, 0.016, 0.016), Vector3(-s * 0.012, 0.083, 0), _mat(ESCURO))
		_caixa(g, Vector3(0.03, 0.016, 0.016), Vector3(-s * 0.012, -0.095, 0), _mat(ESCURO))
		nos.append(g)
	return nos


## Antena de busca: prato e luz maior no mastro que ele já tem.
static func _antena(v: ArmaduraVisual) -> Array:
	var a := _ancora(v, "cabeca")
	var g := _grupo(a, Vector3(-0.08, 0.905, 0.064))
	_cil(g, 0.012, 0.016, 0.02, Vector3(0, 0.008, 0), _mat(ESCURO))
	var prato := _grupo(g, Vector3(0, 0.058, 0), Vector3(-58, 0, 0))
	_cil(prato, 0.04, 0.008, 0.018, Vector3(0, 0.009, 0), _mat(CLARO))
	_cil(prato, 0.042, 0.042, 0.004, Vector3(0, 0.018, 0), _mat(VERDE))
	_cil(prato, 0.0025, 0.0025, 0.03, Vector3(0, 0.03, 0), _mat(ESCURO))
	_bola(prato, 0.006, Vector3(0, 0.046, 0), _mat(ESCURO))
	var luz := _bola(g, 0.015, Vector3(0, 0.118, 0), _mat(Color(0.3, 1.0, 0.8), 3.2))
	_cil(g, 0.011, 0.011, 0.005, Vector3(0, 0.1, 0), _mat(VERDE))
	return [g, prato, luz]


## Faróis de ombro: uma tampa em cima de cada ombro que levanta e mostra três leds (faróis escamoteáveis).
static func _farois(v: ArmaduraVisual) -> Array:
	var nos := []
	for s in [-1.0, 1.0]:
		var a := _ancora(v, "ombroE" if s < 0.0 else "ombroD")
		var g := _grupo(a, Vector3(s * 0.168, 0.659, 0.0))
		_caixa(g, Vector3(0.07, 0.008, 0.078), Vector3(0, 0.003, 0), _mat(ESCURO))
		# a tampa gira numa dobradiça atrás; os leds vão presos embaixo dela
		var ang := 50.0 if farois_abertos else 0.0
		var tampa := _grupo(g, Vector3(0, 0.008, 0.036), Vector3(ang, 0, 0))
		_caixa(tampa, Vector3(0.066, 0.009, 0.074), Vector3(0, 0.004, -0.037), _mat(CLARO))
		_caixa(tampa, Vector3(0.066, 0.004, 0.012), Vector3(0, 0.009, -0.066), _mat(VERDE))
		# o bloco dos leds pende da ponta da tampa e fica sempre de frente
		var bloco := _grupo(tampa, Vector3(0, 0.0, -0.066), Vector3(-ang, 0, 0))
		bloco.visible = farois_abertos  # fechado, o bloco fica recolhido dentro do ombro
		_caixa(bloco, Vector3(0.06, 0.03, 0.018), Vector3(0, -0.016, 0), _mat(ESCURO))
		for i in 3:
			_caixa(bloco, Vector3(0.014, 0.018, 0.004), Vector3((i - 1) * 0.019, -0.016, -0.01),
				_mat(Color(1.0, 0.92, 0.7), 3.6) if farois_abertos else _mat(Color(0.5, 0.48, 0.42)))
		_cil(g, 0.005, 0.005, 0.07, Vector3(0, 0.008, 0.036), _mat(ACO), Vector3(0, 0, 90))
		if farois_abertos:
			var foco := SpotLight3D.new()
			foco.position = Vector3(0, 0.03, -0.05)
			foco.rotation_degrees = Vector3(-8, 0, 0)
			foco.spot_range = 9.0
			foco.spot_angle = 28.0
			foco.light_color = Color(1.0, 0.93, 0.75)
			foco.light_energy = 1.6
			g.add_child(foco)
		nos.append(tampa)
	return nos


## Células de reserva: três em pé atrás da cintura, embaixo da mochila.
static func _celulas(v: ArmaduraVisual) -> Array:
	var a := _ancora(v, "tronco")
	var g := _grupo(a, Vector3(0, 0.446, 0.086))
	_caixa(g, Vector3(0.11, 0.05, 0.016), Vector3(0, 0, -0.004), _mat(ESCURO))
	var nos := [g]
	for i in 3:
		var x := (i - 1) * 0.034
		nos.append(_cil(g, 0.013, 0.013, 0.036, Vector3(x, 0, 0.012), _mat(Color(0.3, 0.9, 1.0), 2.4)))
		for k in [-1.0, 1.0]:
			_cil(g, 0.0155, 0.0155, 0.008, Vector3(x, k * 0.021, 0.012), _mat(CLARO))
	return nos


## Scanner: uma câmera no lado direito da cabeça, com lente comprida apontada para a frente.
static func _scanner(v: ArmaduraVisual) -> Array:
	var a := _ancora(v, "cabeca")
	var g := _grupo(a, Vector3(0.142, 0.8, 0.015))
	_caixa(g, Vector3(0.012, 0.03, 0.09), Vector3(-0.004, 0, -0.035), _mat(ESCURO))
	var corpo := _grupo(g, Vector3(0.012, 0, -0.085))
	_caixa(corpo, Vector3(0.05, 0.05, 0.062), Vector3.ZERO, _mat(CLARO))
	_caixa(corpo, Vector3(0.052, 0.012, 0.064), Vector3(0, 0.02, 0), _mat(VERDE))
	_cil(corpo, 0.021, 0.023, 0.03, Vector3(0, -0.002, -0.044), _mat(ESCURO), Vector3(90, 0, 0))
	_cil(corpo, 0.018, 0.02, 0.026, Vector3(0, -0.002, -0.07), _mat(ESCURO), Vector3(90, 0, 0))
	_cil(corpo, 0.0225, 0.0225, 0.006, Vector3(0, -0.002, -0.06), _mat(CLARO), Vector3(90, 0, 0))
	var lente := _cil(corpo, 0.015, 0.015, 0.003, Vector3(0, -0.002, -0.084), _mat(Color(0.35, 0.9, 1.0), 2.6), Vector3(90, 0, 0))
	_bola(corpo, 0.005, Vector3(0.017, 0.03, -0.026), _mat(Color(1.0, 0.2, 0.15), 3.0))
	_caixa(corpo, Vector3(0.016, 0.008, 0.02), Vector3(-0.01, 0.03, 0.01), _mat(ESCURO))
	return [g, corpo, lente]


## Versão minimalista: cada melhoria é um detalhe pequeno, rente ao corpo, que não muda a silhueta.
static func _minimo(v: ArmaduraVisual, nome: String) -> Array:
	var nos := []
	match nome:
		"radiador":
			# só quatro aletas verticais de fio rubro na mochila (sem a melhoria, a mochila é lisa)
			var g := _grupo(_ancora(v, "costas"), Vector3(0, 0.569, 0.141))
			for i in 4:
				var x := (i - 1.5) * 0.024
				_caixa(g, Vector3(0.008, 0.096, 0.02), Vector3(x, 0, 0.01), _mat(CLARO))
				_caixa(g, Vector3(0.009, 0.096, 0.005), Vector3(x, 0, 0.022), v.mat_calor)
			nos.append(g)
		"bocais":
			# embaixo de cada pé, no lugar da brasa antiga: um bocal mais largo, de luz e chama azuladas
			for n in v.modelo.find_children("brasa_pe*", "MeshInstance3D", true, false):
				(n as MeshInstance3D).visible = false
			for s in [-1.0, 1.0]:
				var g := _grupo(_ancora(v, "tornozeloE" if s < 0.0 else "tornozeloD"), Vector3(s * 0.076, 0.0, 0.006))
				_cil(g, 0.05, 0.046, 0.016, Vector3(0, 0.009, 0), _mat(ESCURO))
				_cil(g, 0.052, 0.052, 0.005, Vector3(0, 0.003, 0), _mat(VERDE))
				_cil(g, 0.04, 0.04, 0.003, Vector3(0, 0.0005, 0), _mat(Color(0.45, 0.8, 1.0), 3.0))
				v.mat_chama.albedo_color = Color(0.45, 0.72, 1.0, v.mat_chama.albedo_color.a)
				if jato:
					_cil(g, 0.04, 0.0, 0.26, Vector3(0, -0.13, 0), _mat_chama(Color(0.35, 0.65, 1.0, 0.75)))
					_cil(g, 0.02, 0.0, 0.15, Vector3(0, -0.075, 0), _mat_chama(Color(0.85, 0.95, 1.0, 0.9)))
				nos.append(g)
		"asas":
			# asas grandes que saem dos lados da mochila: recolhidas, só a fresta aparece
			var a := _ancora(v, "costas")
			for s in [-1.0, 1.0]:
				_caixa(a, Vector3(0.004, 0.118, 0.018), Vector3(s * 0.0735, 0.585, 0.108), _mat(VERDE))
				var g := _grupo(a, Vector3(s * 0.07, 0.6, 0.108))
				g.basis = Basis.from_euler(Vector3(0, deg_to_rad(-s * 16.0), deg_to_rad(-s * 4.0))) * Basis.from_scale(Vector3(s * maxf(asas_fator, 0.001), 1, 1))
				g.visible = asas_fator > 0.01
				g.set_meta("lado", s)
				_chapa(g, PackedVector2Array([Vector2(0.0, 0.036), Vector2(0.24, 0.016), Vector2(0.24, -0.06), Vector2(0.0, -0.092)]),
					0.011, Vector3.ZERO, _mat(CLARO))
				_chapa(g, PackedVector2Array([Vector2(0.24, 0.016), Vector2(0.325, 0.0), Vector2(0.342, -0.03), Vector2(0.24, -0.06)]),
					0.009, Vector3.ZERO, _mat(VERDE))
				_chapa(g, PackedVector2Array([Vector2(0.03, -0.089), Vector2(0.24, -0.06), Vector2(0.24, -0.074), Vector2(0.03, -0.106)]),
					0.006, Vector3.ZERO, _mat(ESCURO))
				nos.append(g)
		"barbatanas":
			# um friso baixo por fora de cada antebraço e de cada bota
			for s in [-1.0, 1.0]:
				for onde in [["cotoveloE" if s < 0.0 else "cotoveloD", Vector3(s * 0.246, 0.425, 0.0), 1.0],
						["joelhoE" if s < 0.0 else "joelhoD", Vector3(s * 0.127, 0.14, 0.0), 1.25]]:
					var g := _grupo(_ancora(v, onde[0]), onde[1])
					g.basis = Basis.from_scale(Vector3(s, 1, 1) * float(onde[2]))
					_chapa(g, PackedVector2Array([Vector2(0, 0.05), Vector2(0.022, 0.02), Vector2(0.03, -0.045), Vector2(0, -0.055)]),
						0.007, Vector3.ZERO, _mat(VERDE))
					nos.append(g)
		"amortecedores":
			# uma mola atrás de cada coxa (a peça escura da perna)
			for s in [-1.0, 1.0]:
				var g := _grupo(_ancora(v, "quadrilE" if s < 0.0 else "quadrilD"), Vector3(s * 0.074, 0.305, 0.042))
				_cil(g, 0.005, 0.005, 0.13, Vector3.ZERO, _mat(ACO))
				for i in 7:
					_cil(g, 0.013, 0.013, 0.006, Vector3(0, (i - 3) * 0.015, 0), _mat(CLARO))
				_cil(g, 0.015, 0.015, 0.012, Vector3(0, 0.062, 0), _mat(VERDE))
				_cil(g, 0.015, 0.015, 0.012, Vector3(0, -0.062, 0), _mat(VERDE))
				nos.append(g)
		"antena":
			# um anel e uma ponta de luz maior no mastro que ele já tem
			var g := _grupo(_ancora(v, "cabeca"), Vector3(-0.08, 0.905, 0.064))
			_cil(g, 0.012, 0.012, 0.005, Vector3(0, 0.07, 0), _mat(VERDE))
			_cil(g, 0.009, 0.009, 0.005, Vector3(0, 0.086, 0), _mat(VERDE))
			nos.append(_bola(g, 0.013, Vector3(0, 0.118, 0), _mat(Color(0.3, 1.0, 0.8), 3.0)))
		"farol":
			# a luz do peito: um aro com grade sobre o núcleo; aceso, o núcleo vira farol
			var g := _grupo(_ancora(v, "tronco"), Vector3(0, 0.561, -0.11), Vector3(90, 0, 0))
			_cil(g, 0.038, 0.038, 0.006, Vector3.ZERO, _mat(ESCURO))
			for i in 3:
				_caixa(g, Vector3(0.062, 0.003, 0.0035), Vector3(0, -0.007, (i - 1) * 0.017), _mat(ESCURO))
			nos.append(_cil(g, 0.03, 0.03, 0.003, Vector3(0, -0.0045, 0), _mat(Color(1.0, 0.74, 0.28), 3.0)))
			var foco := SpotLight3D.new()
			foco.position = Vector3(0, -0.02, 0)
			foco.rotation_degrees = Vector3(-90, 0, 0)  # o facho sai para a frente do peito
			foco.spot_range = 26.0
			foco.spot_angle = 38.0
			foco.light_color = Color(1.0, 0.93, 0.75)
			foco.light_energy = 4.0
			g.add_child(foco)
			nos.append(foco)
			nos.append(g)
			por_farol(nos, farol_aceso)
		"celulas":
			# três pontos de luz na parte de trás da cintura
			var g := _grupo(_ancora(v, "tronco"), Vector3(0, 0.446, 0.08))
			for i in 3:
				nos.append(_caixa(g, Vector3(0.022, 0.016, 0.006), Vector3((i - 1) * 0.034, 0, 0), _mat(Color(0.3, 0.9, 1.0), 2.4)))
		"arma_rajada", "arma_canhao", "arma_precisao", "arma_duplo":
			# a ponta do braço muda com a arma: os canos vão ao longo do antebraço e passam da mão
			for s in ([1.0, -1.0] if nome == "arma_duplo" else [1.0]):
				var g := _grupo(_ancora(v, "cotoveloD" if s > 0.0 else "cotoveloE"), Vector3(s * 0.204, 0.39, -0.062))
				match nome:
					"arma_rajada":
						_caixa(g, Vector3(0.05, 0.06, 0.03), Vector3(0, 0.03, 0.006), _mat(ESCURO))
						for i in 3:
							_cil(g, 0.0085, 0.0085, 0.12, Vector3((i - 1) * 0.017, -0.05, -0.004 if i == 1 else 0.004), _mat(ACO))
						_cil(g, 0.03, 0.03, 0.008, Vector3(0, -0.07, 0.0), _mat(VERDE))
					"arma_canhao":
						_cil(g, 0.03, 0.036, 0.11, Vector3(0, -0.01, 0), _mat(ESCURO))
						_cil(g, 0.04, 0.04, 0.022, Vector3(0, -0.075, 0), _mat(CLARO))
						_cil(g, 0.028, 0.028, 0.006, Vector3(0, -0.088, 0), _mat(PESSEGO, 2.4))
						_cil(g, 0.038, 0.038, 0.01, Vector3(0, 0.04, 0), _mat(VERDE))
					"arma_precisao":
						_cil(g, 0.011, 0.011, 0.24, Vector3(0, -0.07, 0), _mat(ACO))
						_cil(g, 0.016, 0.016, 0.03, Vector3(0, -0.185, 0), _mat(ESCURO))
						_caixa(g, Vector3(0.03, 0.07, 0.026), Vector3(0, 0.03, 0.004), _mat(ESCURO))
						_cil(g, 0.014, 0.014, 0.07, Vector3(0, 0.0, -0.03), _mat(CLARO))
						_cil(g, 0.012, 0.012, 0.004, Vector3(0, -0.037, -0.03), _mat(Color(0.35, 0.9, 1.0), 2.4))
					"arma_duplo":
						_cil(g, 0.02, 0.022, 0.1, Vector3(0, -0.03, 0), _mat(ESCURO))
						_cil(g, 0.026, 0.026, 0.012, Vector3(0, -0.082, 0), _mat(VERDE))
						_cil(g, 0.015, 0.015, 0.005, Vector3(0, -0.09, 0), _mat(PESSEGO, 2.2))
				nos.append(g)
		"lanca_misseis", "lanca_granadas":
			# os dois lançadores ficam para fora dos ombros, na ponta de uma barra que sai das costas, e apontam
			# na mesma direção (para cima e um pouco para a frente): o que sai deles passa longe da cabeça
			var s := -1.0 if nome == "lanca_misseis" else 1.0
			var raiz := _ancora(v, "tronco")
			_caixa(raiz, Vector3(0.03, 0.04, 0.03), Vector3(s * 0.085, 0.64, 0.088), _mat(ESCURO))
			_caixa(raiz, Vector3(0.13, 0.022, 0.022), Vector3(s * 0.145, 0.652, 0.088), _mat(ACO))
			_cil(raiz, 0.016, 0.016, 0.05, Vector3(s * 0.205, 0.665, 0.088), _mat(VERDE))
			var g := _grupo(raiz, Vector3(s * 0.205, 0.735, 0.08), Vector3(-20, 0, 0))
			if nome == "lanca_misseis":
				# uma caixa em pé com quatro bocas em cima
				_caixa(g, Vector3(0.085, 0.13, 0.085), Vector3.ZERO, _mat(ESCURO))
				_caixa(g, Vector3(0.091, 0.012, 0.091), Vector3(0, -0.03, 0), _mat(VERDE))
				for i in 4:
					var px := (i % 2 - 0.5) * 0.036
					var pz := (int(i / 2.0) - 0.5) * 0.036
					_cil(g, 0.014, 0.014, 0.01, Vector3(px, 0.066, pz), _mat(CLARO))
					_cil(g, 0.009, 0.009, 0.004, Vector3(px, 0.071, pz), _mat(Color(1.0, 0.3, 0.2), 2.2))
			else:
				# um tubo curto e largo
				_cil(g, 0.03, 0.034, 0.15, Vector3.ZERO, _mat(ESCURO))
				_cil(g, 0.038, 0.038, 0.016, Vector3(0, 0.072, 0), _mat(CLARO))
				_cil(g, 0.036, 0.036, 0.012, Vector3(0, -0.03, 0), _mat(VERDE))
				_cil(g, 0.024, 0.024, 0.004, Vector3(0, 0.081, 0), _mat(PESSEGO, 1.8))
			nos.append(g)
		"vida":
			# vida extra: uma ombreira baixa em cada ombro (placas a mais de armadura)
			for s in [-1.0, 1.0]:
				var g := _grupo(_ancora(v, "ombroE" if s < 0.0 else "ombroD"), Vector3(s * 0.168, 0.662, 0.0), Vector3(0, 0, -s * 14.0))
				_bola(g, 0.052, Vector3(0, 0.0, 0), _mat(CLARO), Vector3(1.0, 0.34, 0.95))
				_bola(g, 0.056, Vector3(0, -0.006, 0), _mat(ESCURO), Vector3(1.0, 0.3, 0.98))
				_caixa(g, Vector3(0.05, 0.006, 0.02), Vector3(0, 0.018, 0), _mat(VERDE))
				nos.append(g)
		"escudo":
			# o escudo de energia: um disco emissor por fora do antebraço esquerdo, como um broquel; aceso quando
			# está pronto
			var g := _grupo(_ancora(v, "cotoveloE"), Vector3(-0.252, 0.43, 0.0), Vector3(0, 0, 90))
			_cil(g, 0.05, 0.05, 0.014, Vector3.ZERO, _mat(ESCURO))
			_cil(g, 0.054, 0.054, 0.005, Vector3(0, 0.004, 0), _mat(CLARO))
			nos.append(_cil(g, 0.036, 0.036, 0.005, Vector3(0, 0.009, 0), _mat(Color(0.35, 0.95, 0.85), 2.6)))
			nos.append(g)
		"mira":
			# um aro com um ponto vermelho no punho direito, o braço que atira
			var g := _grupo(_ancora(v, "cotoveloD"), Vector3(0.204, 0.4, -0.004))
			_cil(g, 0.052, 0.052, 0.014, Vector3.ZERO, _mat(ESCURO))
			_cil(g, 0.054, 0.054, 0.005, Vector3(0, 0.004, 0), _mat(VERDE))
			nos.append(_bola(g, 0.011, Vector3(0, 0, -0.055), _mat(Color(1.0, 0.25, 0.2), 3.0)))
		"scanner":
			# uma lente pequena na frente da orelha direita
			var g := _grupo(_ancora(v, "cabeca"), Vector3(0.137, 0.8, -0.054), Vector3(90, 0, 0))
			_cil(g, 0.016, 0.018, 0.022, Vector3.ZERO, _mat(ESCURO))
			_cil(g, 0.019, 0.019, 0.005, Vector3(0, 0.008, 0), _mat(CLARO))
			nos.append(_cil(g, 0.011, 0.011, 0.003, Vector3(0, -0.012, 0), _mat(Color(0.35, 0.9, 1.0), 2.6)))
	return nos


## A bolha do escudo de energia: aparece em volta do robô no instante em que ele engole um acerto e some.
static func bolha_escudo(v: ArmaduraVisual, alt: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = alt * 0.62
	sm.height = alt * 1.24
	sm.radial_segments = 20
	sm.rings = 10
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.35, 0.95, 0.85, 0.55)
	m.rim_enabled = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = alt * 0.5
	v.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.18, 0.35).from(Vector3.ONE * 0.9)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(mi.queue_free)
