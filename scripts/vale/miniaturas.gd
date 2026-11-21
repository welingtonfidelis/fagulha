class_name Miniaturas
extends RefCounted
## As miniaturas da estante da base (doc §136): cada rota do piloto de teste feita na versão difícil põe ali uma
## maquete do lugar, de uns 20 cm, num pedestal de madeira com uma plaquinha na cor do rastro daquela rota.
## Feitas de peças simples (caixas, cilindros, esferas), viradas para -Z (para dentro da sala, de costas para a
## parede). A origem é o meio da base do pedestal.

const PEDESTAL := Vector3(0.22, 0.025, 0.15)
const TOPO := 0.025  # onde a maquete começa (em cima do pedestal)

static var _mats := {}


static func fazer(id: String) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Mini_" + id
	_caixa(raiz, PEDESTAL, Vector3(0, PEDESTAL.y * 0.5, 0), _mat("madeira"))
	_caixa(raiz, Vector3(PEDESTAL.x + 0.008, 0.006, PEDESTAL.z + 0.008), Vector3(0, 0.003, 0), _mat("madeira_escura"))
	# a plaquinha da frente, na cor do rastro da rota
	var cor: Color = Rotas.CORES.get(id, Color.WHITE)
	_caixa(raiz, Vector3(0.09, 0.012, 0.003), Vector3(0, PEDESTAL.y * 0.5, -PEDESTAL.z * 0.5 - 0.0015), _luz(cor, 1.2))
	match id:
		"rio": _rio(raiz)
		"torres": _torres(raiz)
		"mastro": _mastro(raiz)
		"ninho": _ninho(raiz)
		"represa": _represa(raiz)
		"fenda": _fenda(raiz)
		"volta": _volta(raiz)
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return raiz


# ---------------------------------------------------------------- cada lugar

## A cachoeira: o paredão, a queda e o poço embaixo.
static func _rio(r: Node3D) -> void:
	var y := TOPO
	_caixa(r, Vector3(0.19, 0.15, 0.05), Vector3(0, y + 0.075, 0.045), _mat("pedra"))
	_caixa(r, Vector3(0.07, 0.03, 0.04), Vector3(-0.065, y + 0.165, 0.04), _mat("pedra"), Vector3(0, 0, 0.2))
	_caixa(r, Vector3(0.08, 0.025, 0.045), Vector3(0.06, y + 0.16, 0.042), _mat("pedra"), Vector3(0, 0, -0.15))
	_bola(r, 0.03, Vector3(-0.06, y + 0.185, 0.05), _mat("mato"), Vector3(1.4, 0.6, 1.0))
	_bola(r, 0.025, Vector3(0.07, y + 0.18, 0.05), _mat("mato"), Vector3(1.3, 0.6, 1.0))
	_caixa(r, Vector3(0.045, 0.15, 0.008), Vector3(0, y + 0.08, 0.017), _luz(Color(0.55, 0.85, 1.0), 0.5))
	_cil(r, 0.07, 0.07, 0.006, Vector3(0, y + 0.004, -0.02), _luz(Color(0.25, 0.55, 0.85), 0.35))
	for p: Vector3 in [Vector3(-0.075, 0.012, -0.03), Vector3(0.08, 0.01, -0.045), Vector3(0.05, 0.008, 0.0)]:
		_bola(r, 0.014, Vector3(p.x, y + p.y, p.z), _mat("pedra"))


## Duas torres de vento, uma na frente com as pás e outra menor atrás.
static func _torres(r: Node3D) -> void:
	var y := TOPO
	_bola(r, 0.09, Vector3(0, y - 0.005, 0.0), _mat("mato"), Vector3(1.15, 0.12, 0.8))
	for t: Array in [[Vector3(-0.035, 0, -0.015), 0.17, 0.4], [Vector3(0.06, 0, 0.04), 0.12, 1.4]]:
		var pe: Vector3 = t[0] + Vector3(0, y, 0)
		var alto: float = t[1]
		var giro: float = t[2]
		_cil(r, 0.005, 0.009, alto, pe + Vector3(0, alto * 0.5, 0), _mat("branco"))
		var topo := pe + Vector3(0, alto, 0)
		_caixa(r, Vector3(0.018, 0.016, 0.034), topo + Vector3(0, 0.004, 0.004), _mat("branco"))
		var cubo := topo + Vector3(0, 0.004, -0.016)
		_bola(r, 0.007, cubo, _mat("ferro"))
		for k in 3:
			var a := giro + k * TAU / 3.0
			var dir := Vector3(sin(a), cos(a), 0)
			var pa := alto * 0.42
			_caixa(r, Vector3(0.008, pa, 0.003), cubo + dir * pa * 0.5 + Vector3(0, 0, -0.002), _mat("branco"), Vector3(0, 0, -a))


## A antena da Ilha do Relé, de faixas vermelhas e brancas, com os cabos e a luz no alto.
static func _mastro(r: Node3D) -> void:
	var y := TOPO
	_bola(r, 0.085, Vector3(0, y - 0.01, 0.005), _mat("areia"), Vector3(1.2, 0.18, 0.85))
	_bola(r, 0.05, Vector3(0.02, y + 0.004, 0.02), _mat("mato"), Vector3(1.3, 0.25, 1.0))
	var base := Vector3(0, y + 0.01, 0.005)
	var alto := 0.19
	var n := 6
	for k in n:
		var f0 := float(k) / n
		var f1 := float(k + 1) / n
		var r0 := lerpf(0.011, 0.004, f0)
		var r1 := lerpf(0.011, 0.004, f1)
		var h := alto / n
		_cil(r, r1, r0, h, base + Vector3(0, h * (k + 0.5), 0), _mat("vermelho" if k % 2 == 0 else "branco"))
	var topo := base + Vector3(0, alto, 0)
	_bola(r, 0.007, topo + Vector3(0, 0.005, 0), _luz(Color(1.0, 0.25, 0.2), 2.2))
	for a: float in [0.5, 2.6, 4.7]:
		var chao := base + Vector3(cos(a) * 0.075, 0.0, sin(a) * 0.055)
		_fio(r, base + Vector3(0, alto * 0.72, 0), chao, 0.0012, _mat("ferro"))


## O pilar do ninho no mar, com o ninho e o ovo dourado.
static func _ninho(r: Node3D) -> void:
	var y := TOPO
	_cil(r, 0.095, 0.095, 0.006, Vector3(0, y + 0.003, 0), _luz(Color(0.2, 0.45, 0.7), 0.3))
	_cil(r, 0.024, 0.034, 0.13, Vector3(0, y + 0.065, 0.005), _mat("pedra"))
	_cil(r, 0.03, 0.026, 0.02, Vector3(0, y + 0.138, 0.005), _mat("pedra"))
	_bola(r, 0.015, Vector3(0.03, y + 0.01, -0.02), _mat("pedra"))
	var ninho := TorusMesh.new()
	ninho.inner_radius = 0.012
	ninho.outer_radius = 0.032
	ninho.rings = 16
	ninho.ring_segments = 8
	_malha(r, ninho, Vector3(0, y + 0.152, 0.005), _mat("palha"))
	_bola(r, 0.011, Vector3(0, y + 0.162, 0.005), _luz(Color(1.0, 0.82, 0.3), 0.8), Vector3(1.0, 1.35, 1.0))
	# a ave pousada na beira
	_bola(r, 0.009, Vector3(0.026, y + 0.168, 0.012), _mat("branco"), Vector3(1.6, 1.0, 1.0))
	_bola(r, 0.005, Vector3(0.038, y + 0.177, 0.012), _mat("branco"))


## A represa: o paredão, a água presa atrás, a comporta e o fio d'água que escapa.
static func _represa(r: Node3D) -> void:
	var y := TOPO
	_caixa(r, Vector3(0.2, 0.085, 0.03), Vector3(0, y + 0.0425, -0.005), _mat("concreto"))
	_caixa(r, Vector3(0.2, 0.012, 0.04), Vector3(0, y + 0.091, -0.005), _mat("concreto_escuro"))
	_caixa(r, Vector3(0.2, 0.07, 0.06), Vector3(0, y + 0.035, 0.04), _luz(Color(0.2, 0.55, 0.5), 0.4))
	_caixa(r, Vector3(0.03, 0.045, 0.004), Vector3(0.03, y + 0.03, -0.021), _mat("ferro"))
	_caixa(r, Vector3(0.016, 0.004, 0.035), Vector3(0.03, y + 0.004, -0.04), _luz(Color(0.5, 0.85, 0.95), 0.5))
	for x: float in [-0.07, -0.02, 0.08]:
		_caixa(r, Vector3(0.004, 0.08, 0.034), Vector3(x, y + 0.04, -0.005), _mat("concreto_escuro"))
	# um aro verde no fundo da água, onde a rota passava
	var aro := TorusMesh.new()
	aro.inner_radius = 0.012
	aro.outer_radius = 0.016
	aro.rings = 20
	aro.ring_segments = 6
	var mi := _malha(r, aro, Vector3(-0.045, y + 0.08, 0.045), _luz(Rotas.CORES["represa"], 1.6))
	mi.rotation = Vector3(PI * 0.5, 0, 0)


## As duas lajes da Fenda Escura, inclinadas uma para a outra, e os cristais roxos lá no fundo.
static func _fenda(r: Node3D) -> void:
	var y := TOPO
	_caixa(r, Vector3(0.2, 0.012, 0.13), Vector3(0, y + 0.006, 0), _mat("pedra_escura"))
	for s: float in [-1.0, 1.0]:
		_caixa(r, Vector3(0.055, 0.17, 0.12), Vector3(s * 0.05, y + 0.085, 0), _mat("pedra_escura"), Vector3(0, 0, s * 0.2))
	for c: Array in [[Vector3(-0.008, 0.02, -0.01), 0.3], [Vector3(0.01, 0.016, 0.02), -0.4], [Vector3(0.0, 0.012, -0.04), 0.1]]:
		_caixa(r, Vector3(0.007, 0.03, 0.007), c[0] + Vector3(0, y, 0), _luz(Color(0.72, 0.45, 1.0), 2.0), Vector3(0, 0.6, c[1]))


## A ilha inteira vista de fora: o morro, a praia e o farol.
static func _volta(r: Node3D) -> void:
	var y := TOPO
	_cil(r, 0.1, 0.1, 0.006, Vector3(0, y + 0.003, 0), _luz(Color(0.2, 0.45, 0.7), 0.3))
	_bola(r, 0.085, Vector3(-0.005, y + 0.004, 0.005), _mat("areia"), Vector3(1.0, 0.16, 0.75))
	_bola(r, 0.07, Vector3(-0.012, y + 0.012, 0.008), _mat("mato"), Vector3(1.0, 0.35, 0.7))
	_bola(r, 0.03, Vector3(-0.03, y + 0.03, 0.015), _mat("mato_escuro"), Vector3(1.2, 0.8, 1.0))
	var pe := Vector3(0.045, y + 0.012, -0.012)
	_cil(r, 0.009, 0.013, 0.085, pe + Vector3(0, 0.0425, 0), _mat("branco"))
	_cil(r, 0.0105, 0.0115, 0.014, pe + Vector3(0, 0.05, 0), _mat("vermelho"))
	_cil(r, 0.008, 0.008, 0.012, pe + Vector3(0, 0.091, 0), _luz(Color(1.0, 0.85, 0.45), 2.0))
	_cil(r, 0.0, 0.011, 0.016, pe + Vector3(0, 0.105, 0), _mat("vermelho"))


## A tacinha dourada do recorde do piloto de teste batido (`Rotas`), uns 4 cm, num canto do pedestal. A origem
## é o meio da base.
static func taca() -> Node3D:
	var t := Node3D.new()
	t.name = "Taca"
	var ouro := _mat("ouro")
	_cil(t, 0.011, 0.012, 0.004, Vector3(0, 0.002, 0), ouro)
	_cil(t, 0.0025, 0.004, 0.012, Vector3(0, 0.01, 0), ouro)
	_cil(t, 0.012, 0.005, 0.016, Vector3(0, 0.024, 0), ouro)
	for lado in [-1.0, 1.0]:
		var alca := TorusMesh.new()
		alca.inner_radius = 0.0035
		alca.outer_radius = 0.0055
		alca.rings = 12
		alca.ring_segments = 6
		var mi := _malha(t, alca, Vector3(lado * 0.012, 0.025, 0), ouro)
		mi.rotation = Vector3(PI * 0.5, 0, 0)
	for mi in t.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return t


# ---------------------------------------------------------------- peças

static func _mat(nome: String) -> StandardMaterial3D:
	if _mats.has(nome):
		return _mats[nome]
	var cores := {
		"madeira": Color(0.42, 0.27, 0.15), "madeira_escura": Color(0.24, 0.15, 0.08), "pedra": Color(0.52, 0.5, 0.46),
		"pedra_escura": Color(0.2, 0.19, 0.21), "mato": Color(0.33, 0.48, 0.24), "mato_escuro": Color(0.2, 0.33, 0.17),
		"areia": Color(0.74, 0.66, 0.48), "branco": Color(0.88, 0.87, 0.82), "vermelho": Color(0.75, 0.18, 0.14),
		"ferro": Color(0.22, 0.21, 0.2), "concreto": Color(0.6, 0.59, 0.55), "concreto_escuro": Color(0.42, 0.41, 0.38),
		"palha": Color(0.55, 0.42, 0.24),
	}
	var m := StandardMaterial3D.new()
	m.albedo_color = cores.get(nome, Color.MAGENTA)
	m.roughness = 0.85
	if nome == "ferro":
		m.metallic = 0.5
		m.roughness = 0.5
	elif nome == "ouro":
		m.albedo_color = Color(1.0, 0.76, 0.3)
		m.metallic = 0.85
		m.roughness = 0.28
		m.emission_enabled = true  # a sala da base é escura: um brilho leve para a taça aparecer
		m.emission = Color(1.0, 0.7, 0.25)
		m.emission_energy_multiplier = 0.35
	_mats[nome] = m
	return m


static func _luz(cor: Color, forca: float) -> StandardMaterial3D:
	var chave := "luz_%s_%.2f" % [cor.to_html(false), forca]
	if _mats.has(chave):
		return _mats[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor * 0.6
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = forca
	m.roughness = 0.4
	_mats[chave] = m
	return m


static func _malha(pai: Node3D, malha: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.position = pos
	pai.add_child(mi)
	return mi


static func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, giro := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = tam
	var mi := _malha(pai, b, pos, mat)
	mi.rotation = giro
	return mi


static func _cil(pai: Node3D, topo: float, base: float, alto: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = topo
	c.bottom_radius = base
	c.height = alto
	c.radial_segments = 16
	c.rings = 1
	return _malha(pai, c, pos, mat)


static func _bola(pai: Node3D, raio: float, pos: Vector3, mat: Material, esc := Vector3.ONE) -> MeshInstance3D:
	var e := SphereMesh.new()
	e.radius = raio
	e.height = raio * 2.0
	e.radial_segments = 16
	e.rings = 8
	var mi := _malha(pai, e, pos, mat)
	mi.scale = esc
	return mi


## Um fio reto de `a` até `b`.
static func _fio(pai: Node3D, a: Vector3, b: Vector3, raio: float, mat: Material) -> void:
	var mi := _cil(pai, raio, raio, a.distance_to(b), (a + b) * 0.5, mat)
	var dir := (b - a).normalized()
	mi.basis = Basis(Quaternion(Vector3.UP, dir))
