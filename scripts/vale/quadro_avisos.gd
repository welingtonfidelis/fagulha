class_name QuadroAvisos
extends Node3D
## O quadro de avisos da base (1.1, doc §136): uma lousa de madeira em dois pés, na frente do telheiro.
## À esquerda, os chefes procurados: o retrato de cada um (tirado pelo `Procurados`), com a luz vermelha
## enquanto ele está de pé e o visto verde e uma taça depois de vencido. À direita, os pedidos do drone
## (`Pedidos`): três cartões só com figura, com a luz âmbar enquanto falta e verde quando está feito.
## Tudo de figura, para quem ainda não lê; os títulos e as contas pequenas são para os grandes.
## Quem cria passa `procurados`; o `Pedidos` escreve com `por_pedido`.

const ONDE := Vector3(-7.4, 0.0, -1.2)  # no lugar da base (BaseVale.t_base): à esquerda de quem chega
const GIRO := 0.55
const LARGURA := 2.7
const ALTURA := 1.35
const BAIXO := 0.62  # do chão até a borda de baixo da lousa
const VERMELHO := Color(1.0, 0.2, 0.14)
const VERDE := Color(0.3, 1.0, 0.45)
const AMBAR := Color(1.0, 0.72, 0.3)

var procurados: Procurados
var _slots_chefe := {}  # id -> {luz, visto, taca}
var _cartoes: Array = []  # [{vp, icone (Control), luz, conta (Label3D)}]
var _mats := {}


func _ready() -> void:
	global_transform = BaseVale.t_base * Transform3D(Basis(Vector3.UP, GIRO), ONDE)
	_moldura()
	_lado_procurados()
	_lado_pedidos()
	if procurados:
		procurados.venceu.connect(func(_id: String) -> void: atualizar_procurados())
	atualizar_procurados()


func _mat(cor: Color, luz := 0.0) -> StandardMaterial3D:
	var chave := "%s|%.1f" % [cor.to_html(), luz]
	if _mats.has(chave):
		return _mats[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.85
	if luz > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = luz
	_mats[chave] = m
	return m


func _caixa(tam: Vector3, pos: Vector3, mat: Material, giro := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation = giro
	add_child(mi)
	return mi


func _texto(t: String, pos: Vector3, tamanho: int, cor: Color) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = tamanho
	l.pixel_size = 0.0028
	l.modulate = cor
	l.outline_size = 0
	l.position = pos
	l.rotation.y = PI  # a frente da lousa é o -Z do quadro
	add_child(l)
	return l


## Os dois pés, a lousa verde-escura, a moldura e o beiral de madeira por cima.
func _moldura() -> void:
	var madeira := _mat(BaseLar.MADEIRA)
	var clara := _mat(BaseLar.MADEIRA_CLARA)
	var meio_y := BAIXO + ALTURA * 0.5
	for s: float in [-1.0, 1.0]:
		_caixa(Vector3(0.1, BAIXO + ALTURA + 0.25, 0.1), Vector3(s * (LARGURA * 0.5 + 0.05), (BAIXO + ALTURA + 0.25) * 0.5, 0.0), madeira)
	_caixa(Vector3(LARGURA, ALTURA, 0.05), Vector3(0, meio_y, 0.0), _mat(Color(0.16, 0.22, 0.18)))
	_caixa(Vector3(LARGURA + 0.3, 0.07, 0.22), Vector3(0, BAIXO + ALTURA + 0.12, 0.0), clara)
	_caixa(Vector3(LARGURA, 0.05, 0.12), Vector3(0, BAIXO - 0.02, -0.04), clara)
	# a ripa do meio separa os dois lados
	_caixa(Vector3(0.04, ALTURA, 0.06), Vector3(0, meio_y, -0.02), clara)
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(LARGURA + 0.2, BAIXO + ALTURA + 0.3, 0.2)
	forma.shape = bx
	forma.position = Vector3(0, (BAIXO + ALTURA + 0.3) * 0.5, 0)
	corpo.add_child(forma)
	add_child(corpo)


# ---------------------------------------------------------------- os procurados

func _lado_procurados() -> void:
	var y_titulo := BAIXO + ALTURA - 0.13
	# a frente da lousa é o -Z: o +X do quadro fica à esquerda de quem olha
	_texto("PROCURADOS", Vector3(LARGURA * 0.25, y_titulo, -0.04), 44, Color(0.95, 0.88, 0.7))
	var k := 0
	for d: Dictionary in Procurados.LISTA:
		var id: String = d["id"]
		var x := LARGURA * 0.25 - (k - 1) * 0.42
		var y := BAIXO + ALTURA * 0.5 + 0.05
		# o papel do cartaz e o retrato por cima
		_caixa(Vector3(0.38, 0.5, 0.01), Vector3(x, y, -0.03), _mat(Color(0.86, 0.79, 0.62)))
		var foto := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.32, 0.4)
		foto.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if procurados and procurados.retratos.has(id):
			m.albedo_texture = procurados.retratos[id]
		else:
			m.albedo_color = Color(0.5, 0.45, 0.4)
		foto.material_override = m
		foto.position = Vector3(x, y + 0.02, -0.04)
		foto.rotation.y = PI
		add_child(foto)
		_texto(String(d["nome"]).to_upper(), Vector3(x, y - 0.21, -0.04), 17, Color(0.2, 0.15, 0.1))
		var luz := MeshInstance3D.new()
		var esf := SphereMesh.new()
		esf.radius = 0.035
		esf.height = 0.07
		luz.mesh = esf
		luz.position = Vector3(x, BAIXO + 0.12, -0.05)
		add_child(luz)
		# o visto verde por cima do retrato e a taça na prateleira de baixo (só depois de vencido)
		var visto := Node3D.new()
		visto.position = Vector3(x, y + 0.02, -0.05)
		add_child(visto)
		var mv := _mat(VERDE, 1.4)
		var a := MeshInstance3D.new()
		var ba := BoxMesh.new()
		ba.size = Vector3(0.05, 0.16, 0.012)
		a.mesh = ba
		a.material_override = mv
		a.position = Vector3(0.06, -0.06, 0)
		a.rotation.z = -0.7
		visto.add_child(a)
		var b := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.05, 0.32, 0.012)
		b.mesh = bb
		b.material_override = mv
		b.position = Vector3(-0.05, 0.01, 0)
		b.rotation.z = 0.55
		visto.add_child(b)
		var taca := _taca(Vector3(x - 0.12, BAIXO + 0.005, -0.08))
		_slots_chefe[id] = {"luz": luz, "visto": visto, "taca": taca}
		k += 1


## Um visto verde aceso (dois traços), do tamanho `esc` do visto dos procurados.
func _visto(pos: Vector3, esc: float) -> Node3D:
	var no := Node3D.new()
	no.position = pos
	no.scale = Vector3.ONE * esc
	add_child(no)
	var mv := _mat(VERDE, 1.4)
	for parte: Array in [[Vector3(0.05, 0.16, 0.012), Vector3(0.06, -0.06, 0), -0.7], [Vector3(0.05, 0.32, 0.012), Vector3(-0.05, 0.01, 0), 0.55]]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = parte[0]
		mi.mesh = b
		mi.material_override = mv
		mi.position = parte[1]
		mi.rotation.z = parte[2]
		no.add_child(mi)
	no.visible = false
	return no


func _taca(pe: Vector3) -> Node3D:
	var no := Node3D.new()
	no.position = pe
	add_child(no)
	var ouro := StandardMaterial3D.new()
	ouro.albedo_color = Color(0.95, 0.75, 0.3)
	ouro.metallic = 0.8
	ouro.roughness = 0.3
	for parte: Array in [[0.03, 0.035, 0.015, 0.0075], [0.008, 0.008, 0.05, 0.04], [0.045, 0.02, 0.06, 0.095]]:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = parte[0]
		c.bottom_radius = parte[1]
		c.height = parte[2]
		c.radial_segments = 12
		mi.mesh = c
		mi.material_override = ouro
		mi.position = Vector3(0, parte[3], 0)
		no.add_child(mi)
	return no


func atualizar_procurados() -> void:
	for id: String in _slots_chefe:
		var s: Dictionary = _slots_chefe[id]
		var vencido := Procurados.vencidos.has(id)
		(s["luz"] as MeshInstance3D).material_override = _mat(VERDE if vencido else VERMELHO, 2.0)
		(s["visto"] as Node3D).visible = vencido
		(s["taca"] as Node3D).visible = vencido


# ---------------------------------------------------------------- os pedidos do drone

func _lado_pedidos() -> void:
	var y_titulo := BAIXO + ALTURA - 0.13
	_texto("PEDIDOS", Vector3(-LARGURA * 0.25, y_titulo, -0.04), 44, Color(0.95, 0.88, 0.7))
	for k in 3:
		var x := -LARGURA * 0.25 - (k - 1) * 0.42
		var y := BAIXO + ALTURA * 0.5 + 0.05
		_caixa(Vector3(0.38, 0.5, 0.01), Vector3(x, y, -0.03), _mat(Color(0.93, 0.92, 0.86)))
		var vp := SubViewport.new()
		vp.size = Vector2i(160, 160)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var icone := Control.new()
		icone.size = Vector2(160, 160)
		icone.set_meta("icone", "")
		icone.set_meta("cor", Color(0.15, 0.2, 0.22))
		icone.draw.connect(func() -> void:
			if String(icone.get_meta("icone")) != "":
				Icones.desenhar(icone, String(icone.get_meta("icone")), Vector2(80, 80), 4.0, icone.get_meta("cor"), 7.0))
		vp.add_child(icone)
		var tela := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.32, 0.32)
		tela.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = vp.get_texture()
		tela.material_override = m
		tela.position = Vector3(x, y + 0.04, -0.04)
		tela.rotation.y = PI
		add_child(tela)
		var conta := _texto("", Vector3(x, y - 0.18, -0.04), 30, Color(0.2, 0.2, 0.2))
		var luz := MeshInstance3D.new()
		var esf := SphereMesh.new()
		esf.radius = 0.035
		esf.height = 0.07
		luz.mesh = esf
		luz.position = Vector3(x, BAIXO + 0.12, -0.05)
		luz.material_override = _mat(AMBAR, 1.5)
		add_child(luz)
		var visto := _visto(Vector3(x + 0.08, y - 0.1, -0.05), 0.6)
		_cartoes.append({"vp": vp, "icone": icone, "luz": luz, "conta": conta, "tela": tela, "visto": visto})


## Um cartão de pedido: a figura (um ícone de `Icones`), a conta pequena ("1/3") e se já está feito.
## `icone` vazio esconde o cartão.
func por_pedido(i: int, icone: String, cor: Color, conta: String, feito: bool) -> void:
	if i < 0 or i >= _cartoes.size():
		return
	var c: Dictionary = _cartoes[i]
	var vazio := icone == ""
	(c["tela"] as MeshInstance3D).visible = not vazio
	(c["luz"] as MeshInstance3D).visible = not vazio
	(c["conta"] as Label3D).text = "" if vazio else conta
	(c["visto"] as Node3D).visible = feito and not vazio
	if vazio:
		return
	var ic: Control = c["icone"]
	ic.set_meta("icone", icone)
	ic.set_meta("cor", cor)
	ic.queue_redraw()
	(c["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	(c["luz"] as MeshInstance3D).material_override = _mat(VERDE if feito else AMBAR, 2.0 if feito else 1.5)
