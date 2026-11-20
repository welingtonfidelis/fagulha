class_name BaseVale
extends RefCounted
## A base do robô, no ponto de nascimento (2026-11-16, das imagens de ideia do usuário): o resto de um
## hangar tomado pelo mato. Piso de chapas, um pedaço de parede e colunas, o cilindro de melhorias aberto
## (o robô vai entrar ali para receber melhorias, no futuro), caixas e a antena, e o Faísca caído, já sem
## funcionar, coberto de musgo. As peças são dos kits de ficção do Quaternius (CC0), pintadas com
## ferrugem e musgo pelo `vale_base.gdshader`; o cilindro é feito aqui. O drone colega (DroneColega) fica
## no posto dele, ao lado da boca do cilindro.
## Medidas do lugar: +X direita, -Z a frente (o campo), +Z o fundo.

const PASTA := "res://assets/vale/base/"
const R_CIL := 2.3  # raio de fora do cilindro
const C_CIL := Vector3(-8.6, R_CIL + 0.18, 1.6)  # centro do cilindro (o eixo é o X do lugar, a boca olha +X)
const MEIO_CIL := 3.2  # metade do comprimento
const ESCALA_FAISCA := 0.66  # perto de 1 m de pé: o usuário pediu mais uns 15 a 20% menor que o robô do jogador

static var t_base := Transform3D()  # do lugar da base para o mundo (os cilindros dos robôs usam)
static var posto_drone := Vector3.INF  # no mundo: onde o drone fica parado
static var cilindro_t := Transform3D()  # no mundo: o centro do cilindro, com o X apontando para a boca
static var boca_cilindro := Vector3.INF  # no mundo: o meio da boca do cilindro
static var faisca_em := Vector3.INF  # no mundo: onde o Faísca caído está sentado
static var faisca_pecas := 0  # peças do Faísca caído com colisão própria (casco convexo)
static var pecas_kit := 0

static var _mats := {}
static var _cenas := {}


static func montar(o: Ruinas.Obra) -> void:
	_mats.clear()
	pecas_kit = 0
	t_base = o.t
	var cy := 0.0
	# a laje do hangar, rachada nas beiras, e o piso de chapas por cima
	o.bloco(Vector3(-1.0, cy - 0.6, 1.0), Vector3(21.0, 1.2, 12.5), Basis.IDENTITY, "ruina")
	for ix in range(-2, 3):
		for iz in range(-1, 2):
			if (ix == 2 and iz == -1) or (ix == -2 and iz == -1):
				continue  # chapas que faltam nos cantos da frente
			var nome: String = ["Platform_Metal2", "Platform_DarkPlates", "Platform_Squares"][absi(ix * 3 + iz * 5) % 3]
			# debaixo do telheiro o piso é cuidado: pouca ferrugem e quase nenhum musgo
			_peca(o, nome, Vector3(ix * 4.0 - 1.0, cy + 0.02, iz * 4.0 + 1.0), 0.0, 1.0, 0.5 if iz < 0 else 0.22, 0.2 if iz < 0 else 0.03, false)
	# o estrado redondo onde o robô nasce
	_peca(o, "Platform_Round1", Vector3(0, cy + 0.02, 0), 0.0, 1.0, 0.3, 0.1, false)
	var disco := CylinderShape3D.new()
	disco.radius = 2.95
	disco.height = 0.19
	o.forma(disco, Transform3D(Basis.IDENTITY, Vector3(0, cy + 0.095, 0)))
	# a parede do fundo: três panos, um quebrado, e as colunas do hangar
	var fz := 6.6
	_peca(o, "WallAstra_Straight", Vector3(-5.0, cy, fz), PI * 0.5, 1.35, 0.5, 0.4)
	_peca(o, "WallAstra_Straight_Window", Vector3(0.4, cy, fz), PI * 0.5, 1.35, 0.5, 0.5)
	_peca(o, "WallAstra_Straight_Broken", Vector3(5.8, cy, fz), PI * 0.5, 1.35, 0.6, 0.55)
	_peca(o, "WallBand_Straight_Broken", Vector3(10.9, cy, 4.6), 0.12, 1.3, 0.7, 0.6)
	_peca(o, "Column_Large_Straight", Vector3(-8.0, cy, fz + 0.4), PI * 0.5, 0.41, 0.5, 0.45)
	_peca(o, "Column_Large_Straight", Vector3(8.6, cy, fz + 0.4), PI * 0.5, 0.41, 0.6, 0.5)
	_peca(o, "Column_Pipes", Vector3(-2.4, cy, fz + 0.2), 0.0, 0.85, 0.7, 0.4)
	_peca(o, "Column_Pipes", Vector3(3.1, cy, fz + 0.2), 0.0, 0.85, 0.6, 0.4)
	# o telheiro, o cantinho, a bancada, a horta e a fogueira (2026-11-20)
	BaseLar.montar(o, cy)
	# a lâmpada do estrado, na parede
	_peca(o, "Prop_Light_Wide", Vector3(0.4, cy + 3.5, fz - 0.75), PI * 0.5, 1.6, 0.2, 0.0, false)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.82, 0.6)  # era ciano; a base ficou de luz quente
	luz.light_energy = 1.2
	luz.omni_range = 11.0
	luz.position = o.t * Vector3(0.4, cy + 3.3, fz - 1.6)
	o.v.add_child(luz)
	_cilindro(o, cy)
	_baia_dos_robos(o, cy)
	_faisca(o, Vector3(3.3, cy, -3.0), -0.81)
	_peca(o, "Prop_Crate4", Vector3(3.3 + 0.724 * 0.68, cy, -3.0 - 0.69 * 0.68), -0.81, 0.8, 0.7, 0.5)
	# caixas, tambores, armário e a antena
	_peca(o, "Prop_Crate_Large", Vector3(5.6, cy, 5.3), 0.08, 1.0, 0.5, 0.45)
	_peca(o, "Prop_Crate_Tarp", Vector3(4.2, cy, 5.2), 0.3, 0.9, 0.2, 0.5)
	_peca(o, "Prop_Crate", Vector3(10.4, cy, -2.4), -0.2, 1.0, 0.6, 0.4)
	_peca(o, "Prop_Crate4", Vector3(8.9, cy, 5.5), 0.5, 1.0, 0.7, 0.5)
	_peca(o, "Prop_Barrel1", Vector3(7.2, cy, 5.5), 0.0, 1.15, 0.8, 0.3)
	_peca(o, "Prop_Barrel2_Open", Vector3(7.9, cy, 5.2), 1.0, 1.15, 0.7, 0.4)
	_peca(o, "Prop_Barrel_Large", Vector3(10.6, cy, 0.4), 0.4, 1.2, 0.8, 0.5)
	_peca(o, "Prop_Shelves_WideTall", Vector3(-5.7, cy, 5.75), 0.0, 1.0, 0.6, 0.3)
	_peca(o, "Prop_SatelliteDish", Vector3(10.4, o.chao(10.4, 7.6), 7.6), 2.4, 1.2, 0.5, 0.45)
	_peca(o, "Prop_Crate_Tarp_Large", Vector3(-12.6, o.chao(-12.6, -2.8), -2.8), 1.3, 1.0, 0.3, 0.6)
	# entulho e mato tomando as beiras
	o.entulho(Vector2(-11.0, 6.5), Vector2(2.0, 1.6), 6, 0.4, 1.0)
	o.entulho(Vector2(10.8, -3.8), Vector2(1.8, 1.4), 5, 0.4, 0.9)
	o.entulho(Vector2(-4.0, -5.6), Vector2(2.2, 0.8), 4, 0.3, 0.7)
	for p: Vector3 in [Vector3(-10.6, 0, 5.6), Vector3(9.4, 0, 6.2), Vector3(11.2, 0, 2.0), Vector3(-11.6, 0, -4.4), Vector3(6.4, 0, -5.6), Vector3(-6.2, 0, 7.6)]:
		o.arbusto(Vector3(p.x, o.chao(p.x, p.z), p.z), 1.0 + 0.5 * absf(sin(p.x)))
	for p2: Array in [["q_samambaia", Vector3(6.6, 0, 5.8), 1.5], 
			["q_samambaia", Vector3(-10.4, 0, -0.9), 1.4], 
			["q_planta_b", Vector3(-4.9, 0, -3.8), 1.2], ["q_moita", Vector3(9.9, 0, -1.6), 1.0], 
			["q_planta_d", Vector3(7.9, 0, 6.0), 1.2], ["q_samambaia", Vector3(-7.6, 0, -2.6), 1.2]]:
		_planta(o, p2[0], p2[1], p2[2])


## Uma peça dos kits, com a base no ponto `pe` (medida do lugar) e virada `giro` em torno do eixo de pé.
## Devolve o nó, já na cena.
static func _peca(o: Ruinas.Obra, nome: String, pe: Vector3, giro: float, esc: float, fer: float, mus: float, colide := true) -> Node3D:
	if not _cenas.has(nome):
		_cenas[nome] = load(PASTA + nome + ".gltf")
	var raiz := (_cenas[nome] as PackedScene).instantiate() as Node3D
	var caixa := _caixa(raiz)
	var no := Node3D.new()
	no.name = "Kit_" + nome
	no.add_child(raiz)
	# a origem do nó fica no meio da base da peça
	raiz.position = -Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
	var base := Basis(Vector3.UP, giro).scaled(Vector3.ONE * esc)
	no.transform = o.t * Transform3D(base, pe)
	vestir(raiz, fer, mus, o.v._tex)
	o.v.add_child(no)
	pecas_kit += 1
	if colide:
		var cx := BoxShape3D.new()
		cx.size = caixa.size * esc
		o.forma(cx, Transform3D(Basis(Vector3.UP, giro), pe + Vector3(0, caixa.size.y * esc * 0.5, 0)))
	return no


## A baia onde os robôs ficam guardados (os três cilindros de vidro são do `CilindrosBase`, hoje vazios): um estrado de metal
## com degrau, um painel de fundo, uma cobertura apoiada em dois postes, os cabos que descem até cada cilindro
## e um terminal ao lado. Fica à direita de quem nasce, contra a parede do fundo.
const BAIA := Vector3(6.2, 0.0, 3.7)  # o meio do estrado, no chão da base
const BAIA_ALTO := 0.45  # altura do estrado (o capim da clareira não passa dela)
const BAIA_VAGAS := [-1.6, 0.0, 1.6]  # onde fica cada cilindro, ao longo do estrado


static func _baia_dos_robos(o: Ruinas.Obra, cy: float) -> void:
	var b := BAIA + Vector3(0, cy, 0)
	o.bloco(b + Vector3(0, BAIA_ALTO * 0.5, 0), Vector3(5.2, BAIA_ALTO, 2.0), Basis.IDENTITY, "casco")
	# a rampa de acesso, no lugar do degrau (o robô não subia: o degrau era baixo, mas a caixa do estrado o
	# barrava logo atrás). Uma chapa inclinada, do chão até a beira do estrado.
	var rampa_l := 1.5
	var rampa_ang := atan(BAIA_ALTO / rampa_l)
	o.bloco(b + Vector3(0, BAIA_ALTO * 0.5 - 0.03, -1.0 - rampa_l * 0.5), Vector3(5.2, 0.08, sqrt(rampa_l * rampa_l + BAIA_ALTO * BAIA_ALTO)),
		Basis(Vector3.RIGHT, -rampa_ang), "casco")
	o.bloco(b + Vector3(0, 1.6, 0.94), Vector3(5.2, 2.3, 0.16), Basis.IDENTITY, "ferrugem")  # o painel de fundo
	o.bloco(b + Vector3(0, 2.84, 0.05), Vector3(5.5, 0.16, 2.0), Basis.IDENTITY, "casco", false)  # a cobertura
	for lado: float in [-1.0, 1.0]:
		o.bloco(b + Vector3(lado * 2.6, 1.64, -0.85), Vector3(0.16, 2.4, 0.16), Basis.IDENTITY, "casco")
	for vx: float in BAIA_VAGAS:
		# o cabo que desce da cobertura até a tampa do cilindro, e uma faixa clara no painel atrás de cada vaga
		o.bloco(b + Vector3(vx, 2.56, 0.0), Vector3(0.06, 0.42, 0.06), Basis.IDENTITY, "casco", false)
		o.bloco(b + Vector3(vx, 1.5, 0.85), Vector3(0.9, 1.9, 0.04), Basis.IDENTITY, "casco", false)
	_peca(o, "Prop_AccessPoint", Vector3(BAIA.x + 2.95, cy, BAIA.z + 1.5), -0.5, 1.3, 0.4, 0.3)  # saiu do caminho entre a baia e o drone
	_peca(o, "Prop_Cable_1", Vector3(BAIA.x - 2.2, cy + 0.04, BAIA.z - 2.0), 0.4, 1.2, 0.2, 0.3, false)
	_peca(o, "Prop_Cable_3", Vector3(BAIA.x + 1.6, cy + 0.04, BAIA.z - 2.1), 2.4, 1.0, 0.2, 0.3, false)


## A caixa de todas as malhas de uma cena, na medida da raiz dela.
static func _caixa(raiz: Node3D) -> AABB:
	var caixa := AABB()
	var primeiro := true
	for mi: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false) + ([raiz] if raiz is MeshInstance3D else []):
		var t := mi.transform
		var pai := mi.get_parent()
		while pai != null and pai != raiz and pai is Node3D:
			t = (pai as Node3D).transform * t
			pai = pai.get_parent()
		var b := t * mi.get_aabb()
		caixa = b if primeiro else caixa.merge(b)
		primeiro = false
	return caixa


## Troca os materiais de uma cena dos kits pelos do vale, pelo nome do material do modelo.
static func vestir(raiz: Node, fer: float, mus: float, ruido: Texture2D) -> void:
	for mi: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false) + ([raiz] if raiz is MeshInstance3D else []):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			mi.set_surface_override_material(s, material(String(m.resource_name) if m else "", fer, mus, ruido))


static func material(nome: String, fer: float, mus: float, ruido: Texture2D) -> ShaderMaterial:
	var chave := "%s|%.2f|%.2f" % [nome, fer, mus]
	if _mats.has(chave):
		return _mats[chave]
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_base.gdshader")
	m.set_shader_parameter("ruido", ruido)
	m.set_shader_parameter("ferrugem", fer)
	m.set_shader_parameter("musgo", mus)
	var tex := ""
	if nome.begins_with("MI_Trim_01"):
		tex = "trim_01"
	elif nome.begins_with("MI_Trim_02"):
		tex = "trim_02"
		if nome.ends_with("Rails"):
			m.set_shader_parameter("corte", 0.5)
	elif nome.begins_with("MI_Trim_03_Cables"):
		tex = "cabos"
	elif nome == "MI_Trim_03_Dark":
		tex = "trim_03_dark"
	elif nome.begins_with("MI_Trim_03"):
		tex = "trim_03"
	elif nome == "MI_PaddedWall":
		tex = "acolchoado"
	elif nome == "MI_Props_Batch1":
		tex = "props_1"
	elif nome == "MI_Props_Batch2":
		tex = "props_2"
	elif nome == "MI_Props_Crates":
		tex = "caixas"
	elif nome == "MI_Enemies":
		tex = "drone"
		m.set_shader_parameter("luz", load(PASTA + "drone_luz.png"))
		m.set_shader_parameter("luz_forca", 2.6)
	elif nome.contains("Decal"):
		tex = "decalques"
		m.set_shader_parameter("corte", 0.5)
		m.set_shader_parameter("ferrugem", fer * 0.5)
		if nome == "M_Decal_Screen":
			m.set_shader_parameter("luz", load(PASTA + "decalques.png"))
			m.set_shader_parameter("luz_forca", 0.5)
	elif nome == "M_Black":
		m.set_shader_parameter("tinta", Color(0.03, 0.035, 0.04))
	elif nome == "M_Light":
		m.set_shader_parameter("tinta", Color(0.5, 0.9, 0.85))
		m.set_shader_parameter("aceso", Color(0.3, 0.85, 0.75))
		m.set_shader_parameter("musgo", 0.0)
		m.set_shader_parameter("ferrugem", 0.0)
	elif nome == "M_LightFade_Red":
		m.set_shader_parameter("tinta", Color(0.5, 0.1, 0.08))
		m.set_shader_parameter("aceso", Color(0.35, 0.05, 0.03))
	elif nome == "M_Glass":
		m.set_shader_parameter("tinta", Color(0.07, 0.11, 0.12))
		m.set_shader_parameter("ferrugem", 0.0)
	else:
		m.set_shader_parameter("tinta", Color(0.45, 0.46, 0.45))
	if tex != "":
		m.set_shader_parameter("tex", load(PASTA + tex + ".png"))
		if tex != "drone" and tex != "decalques":
			m.set_shader_parameter("tinta", Color(0.5, 0.52, 0.5))  # os kits são claros demais para uma ruína
	_mats[chave] = m
	return m


## Uma cor só (o cilindro e as peças do Faísca).
static func _mat_cor(cor: Color, fer: float, mus: float, ruido: Texture2D) -> ShaderMaterial:
	var chave := "cor|%s|%.2f|%.2f" % [cor.to_html(), fer, mus]
	if _mats.has(chave):
		return _mats[chave]
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_base.gdshader")
	m.set_shader_parameter("ruido", ruido)
	m.set_shader_parameter("tinta", cor)
	m.set_shader_parameter("ferrugem", fer)
	m.set_shader_parameter("musgo", mus)
	_mats[chave] = m
	return m


static func _planta(o: Ruinas.Obra, nome: String, p: Vector3, s: float) -> void:
	if not o.v._malhas.has(nome):
		return
	var mundo := o.t * Vector3(p.x, maxf(o.chao(p.x, p.z), p.y), p.z)
	o.v._por(nome, Transform3D(Basis(Vector3.UP, p.x * 1.7 + p.z).scaled(Vector3.ONE * s), mundo - Vector3(0, 0.05, 0)))


# ---------------------------------------------------------------- o cilindro de melhorias

## Um trecho de tubo ao longo do X (de x0 a x1), com a face para fora ou para dentro.
static func _tubo(st: SurfaceTool, x0: float, x1: float, r0: float, r1: float, para_fora: bool) -> void:
	var n := 28
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p00 := Vector3(x0, cos(a0) * r0, sin(a0) * r0)
		var p01 := Vector3(x0, cos(a1) * r0, sin(a1) * r0)
		var p10 := Vector3(x1, cos(a0) * r1, sin(a0) * r1)
		var p11 := Vector3(x1, cos(a1) * r1, sin(a1) * r1)
		var tris := [p00, p10, p11, p00, p11, p01]
		for q in range(0, 6, 3):
			var a: Vector3 = tris[q]
			var b: Vector3 = tris[q + 1]
			var c: Vector3 = tris[q + 2]
			var nrm := (c - a).cross(b - a)
			var meio := (a + b + c) / 3.0
			var radial := Vector3(0, meio.y, meio.z)
			# a frente da face olha para fora do eixo (ou para dentro); nas tampas, pelo sentido do X
			var certo := nrm.dot(radial) > 0.0 if absf(r0 - r1) < 0.001 else nrm.x * (1.0 if para_fora else -1.0) > 0.0
			if absf(r0 - r1) < 0.001 and not para_fora:
				certo = not certo
			if certo:
				st.add_vertex(a)
				st.add_vertex(b)
				st.add_vertex(c)
			else:
				st.add_vertex(a)
				st.add_vertex(c)
				st.add_vertex(b)


static func _cilindro(o: Ruinas.Obra, cy: float) -> void:
	var c := C_CIL + Vector3(0, cy, 0)
	var ri := R_CIL - 0.2
	var casca := SurfaceTool.new()
	casca.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tubo(casca, -MEIO_CIL, MEIO_CIL, R_CIL, R_CIL, true)
	_tubo(casca, -MEIO_CIL, -MEIO_CIL, 0.0, R_CIL, false)  # a tampa do fundo
	_tubo(casca, MEIO_CIL, MEIO_CIL, ri, R_CIL + 0.16, true)  # o aro da boca
	for x: float in [-2.3, -0.2, 1.9, MEIO_CIL - 0.16]:
		_tubo(casca, x - 0.14, x + 0.14, R_CIL + 0.16, R_CIL + 0.16, true)
		_tubo(casca, x - 0.14, x - 0.14, R_CIL, R_CIL + 0.16, false)
		_tubo(casca, x + 0.14, x + 0.14, R_CIL, R_CIL + 0.16, true)
	casca.generate_normals()
	var dentro := SurfaceTool.new()
	dentro.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tubo(dentro, -MEIO_CIL + 0.2, MEIO_CIL, ri, ri, false)
	_tubo(dentro, -MEIO_CIL + 0.2, -MEIO_CIL + 0.2, 0.0, ri, true)
	dentro.generate_normals()
	var tex: Texture2D = o.v._tex
	var mi := MeshInstance3D.new()
	mi.name = "CilindroDeMelhorias"
	var malha := casca.commit()
	malha.surface_set_material(0, _mat_cor(Color(0.2, 0.23, 0.21), 0.8, 0.5, tex))
	dentro.commit(malha)
	malha.surface_set_material(1, _mat_cor(Color(0.035, 0.045, 0.05), 0.3, 0.0, tex))
	mi.mesh = malha
	mi.transform = o.t * Transform3D(Basis.IDENTITY, c)
	o.v.add_child(mi)
	# a porta redonda, aberta para o lado do fundo
	var porta := SurfaceTool.new()
	porta.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tubo(porta, -0.12, 0.12, R_CIL + 0.1, R_CIL + 0.1, true)
	_tubo(porta, 0.12, 0.12, 0.0, R_CIL + 0.1, true)
	_tubo(porta, -0.12, -0.12, 0.0, R_CIL + 0.1, false)
	_tubo(porta, 0.12, 0.26, R_CIL + 0.1, R_CIL - 0.1, true)  # o aro em relevo
	_tubo(porta, 0.26, 0.26, R_CIL - 0.45, R_CIL - 0.1, true)
	_tubo(porta, 0.12, 0.26, R_CIL - 0.45, R_CIL - 0.45, false)
	_tubo(porta, 0.12, 0.3, 0.55, 0.4, true)  # o cubo do meio
	_tubo(porta, 0.3, 0.3, 0.0, 0.4, true)
	porta.generate_normals()
	var mp := MeshInstance3D.new()
	mp.name = "PortaDoCilindro"
	mp.mesh = porta.commit()
	mp.mesh.surface_set_material(0, _mat_cor(Color(0.22, 0.22, 0.19), 0.9, 0.4, tex))
	# a porta foi tirada das dobradiças e encostada na parede, atrás do cilindro (aberta, ela tomava o
	# meio da base, onde hoje é o cantinho de descanso)
	var giro := Basis(Vector3.RIGHT, 0.1) * Basis(Vector3.UP, PI * 0.5)
	var centro_porta := Vector3(c.x - 0.6, cy + R_CIL + 0.12, 5.55)
	mp.transform = o.t * Transform3D(giro, centro_porta)
	o.v.add_child(mp)
	# os raios da porta
	for k in 4:
		var ang := k * PI * 0.5 + 0.4
		o.bloco(centro_porta + giro * Vector3(0.2, cos(ang) * 1.2, sin(ang) * 1.2), Vector3(0.14, 1.35, 0.2), giro * Basis(Vector3.RIGHT, ang), "ferrugem", false)
	var cp := BoxShape3D.new()
	cp.size = Vector3(0.35, R_CIL * 2.0, R_CIL * 2.0)
	o.forma(cp, Transform3D(giro, centro_porta))
	# os berços que seguram o cilindro, e a colisão dele: um anel de caixas e a tampa do fundo
	for x: float in [-2.0, 1.6]:
		o.bloco(Vector3(c.x + x, cy + 0.45, c.z), Vector3(0.7, 0.9, R_CIL * 1.7), Basis.IDENTITY, "casco")
	for k in 14:
		var a := TAU * (k + 0.5) / 14
		var cx := BoxShape3D.new()
		cx.size = Vector3(MEIO_CIL * 2.0, 0.24, TAU * R_CIL / 14 + 0.1)
		o.forma(cx, Transform3D(Basis(Vector3.RIGHT, a), c + Vector3(0, -sin(a) * (R_CIL - 0.1), cos(a) * (R_CIL - 0.1))))
	var tampa := BoxShape3D.new()
	tampa.size = Vector3(0.25, R_CIL * 2.0, R_CIL * 2.0)
	o.forma(tampa, Transform3D(Basis.IDENTITY, c + Vector3(-MEIO_CIL + 0.1, 0, 0)))
	# por dentro: o estrado, os dois braços, o painel e a luz
	o.bloco(c + Vector3(0.1, -ri + 0.42, 0), Vector3(MEIO_CIL * 2.0 - 0.5, 0.14, 2.4), Basis.IDENTITY, "casco")
	# a rampa da boca: do chão até o estrado (0,87 m acima), para o robô subir andando
	var sobe := c.y - ri + 0.49 - cy
	var corre := 2.15
	var topo := Vector3(c.x + MEIO_CIL - 0.15, cy + sobe, c.z)
	var pe := topo + Vector3(corre, -sobe, 0)
	var incl := atan2(sobe, corre)
	var giro_rampa := Basis(Vector3.BACK, -incl)
	o.bloco((topo + pe) * 0.5 - giro_rampa * Vector3(0, 0.06, 0), Vector3(sqrt(sobe * sobe + corre * corre) + 0.1, 0.12, 1.7), giro_rampa, "casco")
	for lado_r: float in [-1.0, 1.0]:
		o.bloco((topo + pe) * 0.5 + Vector3(0, 0.02, lado_r * 0.9) - giro_rampa * Vector3(0, 0.06, 0), Vector3(sqrt(sobe * sobe + corre * corre) + 0.1, 0.2, 0.1), giro_rampa, "ferrugem", false)
	for lado: float in [-1.0, 1.0]:
		o.bloco(c + Vector3(0.9, 1.25, lado * 1.15), Vector3(0.2, 1.1, 0.2), Basis.from_euler(Vector3(lado * -0.75, 0, 0.2)), "casco_claro", false)
		o.bloco(c + Vector3(1.1, 0.55, lado * 0.62), Vector3(0.16, 0.95, 0.16), Basis.from_euler(Vector3(lado * 0.5, 0, -0.3)), "ferrugem", false)
		o.bloco(c + Vector3(1.25, 0.08, lado * 0.42), Vector3(0.3, 0.12, 0.34), Basis.from_euler(Vector3(0, lado * 0.4, 0)), "junta", false)
	_peca(o, "Prop_Computer", c + Vector3(-2.6, -ri + 0.5, -0.5), PI * 0.5, 1.0, 0.2, 0.0, false)
	_peca(o, "Prop_AccessPoint", c + Vector3(MEIO_CIL + 1.0, -c.y + cy, -R_CIL - 0.3), -0.7, 1.4, 0.4, 0.3)
	_peca(o, "Prop_Cable_3", Vector3(c.x + MEIO_CIL + 0.4, cy + 0.04, 0.3), PI * 0.5 + 0.25, 1.0, 0.2, 0.3, false)
	_peca(o, "Prop_Cable_1", Vector3(c.x + MEIO_CIL + 1.2, cy + 0.04, 2.6), 0.9, 1.3, 0.2, 0.3, false)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.4, 0.95, 0.8)
	luz.light_energy = 1.1
	luz.omni_range = 6.5
	luz.position = o.t * (c + Vector3(-0.6, 0.9, 0))
	o.v.add_child(luz)
	boca_cilindro = o.t * (c + Vector3(MEIO_CIL, 0, 0))
	cilindro_t = o.t * Transform3D(Basis.IDENTITY, c)
	posto_drone = o.t * Vector3(c.x + MEIO_CIL + 2.3, cy + 2.1, c.z - 2.0)


# ---------------------------------------------------------------- o Faísca caído

## Gira um osso em torno dos eixos do esqueleto (não os do próprio osso): os pais primeiro.
static func _dobrar(sk: Skeleton3D, osso: String, giro: Basis) -> void:
	var b := sk.find_bone(osso)
	if b < 0:
		return
	var g := sk.get_bone_global_pose(b)
	var pai := sk.get_bone_parent(b)
	var gp := sk.get_bone_global_pose(pai) if pai >= 0 else Transform3D.IDENTITY
	var novo := Transform3D(giro * g.basis, g.origin)
	sk.set_bone_pose_rotation(b, (gp.affine_inverse() * novo).basis.get_rotation_quaternion())
	sk.force_update_all_bone_transforms()


## O Faísca (o robô da Ilha Cafuné, o jogo que inspirou este), sentado e caído contra uma caixa, à vista de quem sai do estrado,
## desligado há muito tempo: sem luz no rosto, enferrujado e com o mato crescendo em cima.
static func _faisca(o: Ruinas.Obra, pe: Vector3, giro: float) -> void:
	var cena: PackedScene = load("res://assets/faisca/faisca.scn")
	if cena == null:
		return
	var f := cena.instantiate() as Node3D
	f.name = "FaiscaCaido"
	o.v.add_child(f)
	var sk: Skeleton3D = f.find_children("*", "Skeleton3D", true, false)[0]
	var g := deg_to_rad(1.0)
	# no esqueleto: a frente é +Z, o braço esquerdo fica em +X
	# sentado: tronco quase de pé, um pouco para trás (as costas na caixa), pernas esticadas para a frente,
	# braços caídos ao lado do corpo e a cabeça baixa
	_dobrar(sk, "hips", Basis(Vector3.RIGHT, -10.0 * g))
	_dobrar(sk, "head", Basis(Vector3.RIGHT, 28.0 * g) * Basis(Vector3.BACK, -8.0 * g))
	_dobrar(sk, "upperleg.r", Basis(Vector3.UP, -9.0 * g) * Basis(Vector3.RIGHT, -80.0 * g))
	_dobrar(sk, "upperleg.l", Basis(Vector3.UP, 9.0 * g) * Basis(Vector3.RIGHT, -80.0 * g))
	_dobrar(sk, "upperarm.l", Basis(Vector3.BACK, -80.0 * g))
	_dobrar(sk, "upperarm.r", Basis(Vector3.BACK, 80.0 * g))
	var no_f := sk.transform  # do esqueleto para a raiz do Faísca
	var pai_sk := sk.get_parent()
	while pai_sk != null and pai_sk != f and pai_sk is Node3D:
		no_f = (pai_sk as Node3D).transform * no_f
		pai_sk = pai_sk.get_parent()
	var baixo := (no_f * sk.get_bone_global_pose(sk.find_bone("hips")).origin).y - 0.15  # o quadril perto do chão; o ajuste fino vem abaixo
	var base := Basis(Vector3.UP, giro).scaled(Vector3.ONE * ESCALA_FAISCA)
	var chao := o.chao(pe.x, pe.z)
	f.transform = o.t * Transform3D(base, Vector3(pe.x, maxf(pe.y, chao) - (baixo + 0.02) * ESCALA_FAISCA, pe.z))
	# assenta de verdade no quadro seguinte, quando as peças já seguiram os ossos: o ponto mais baixo delas
	# encosta no chão (a conta pelos ossos deixava o corpo no ar)
	var piso := o.t.origin.y + maxf(pe.y, chao)
	if o.v.is_inside_tree():
		o.v.get_tree().process_frame.connect(func() -> void:
			if not is_instance_valid(f):
				return
			var menor := INF
			for mi2: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
				if not mi2.visible:
					continue
				var cx := mi2.get_aabb()
				for k in 8:
					menor = minf(menor, (mi2.global_transform * cx.get_endpoint(k)).y)
			if menor != INF:
				f.global_position.y += piso + 0.01 - menor
			# com ele no lugar, a colisão: a malha do próprio corpo (MalhaCorpo)
			# O modelo dele é detalhado demais para virar colisão triângulo a triângulo (139 mil): cada peça
			# do corpo entra como o casco convexo dela, já no lugar.
			var corpo_f := StaticBody3D.new()
			corpo_f.name = "FaiscaCaidoCorpo"
			corpo_f.collision_layer = 1
			corpo_f.collision_mask = 0
			o.v.add_child(corpo_f)
			for mi3: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
				if not mi3.visible or mi3.mesh == null:
					continue
				var casco := mi3.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
				if casco == null or casco.points.size() < 4:
					continue
				var pts := PackedVector3Array()
				for vtx: Vector3 in casco.points:
					pts.append(mi3.global_transform * vtx)
				var no_mundo := ConvexPolygonShape3D.new()
				no_mundo.points = pts
				var cs_f := CollisionShape3D.new()
				cs_f.shape = no_mundo
				corpo_f.add_child(cs_f)
				faisca_pecas += 1, CONNECT_ONE_SHOT)
	var tex: Texture2D = o.v._tex
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		var nome := String(mi.name)
		if nome.begins_with("jato"):
			mi.visible = false
			continue
		var cor := Color(0.03, 0.035, 0.045)
		var m0 := mi.material_override if mi.material_override else (mi.mesh.surface_get_material(0) if mi.mesh.get_surface_count() > 0 else null)
		if m0 is StandardMaterial3D and nome != "rosto" and not nome.begins_with("carga"):
			cor = (m0 as StandardMaterial3D).albedo_color
			if cor.b > cor.r + 0.2:
				cor = Color(0.1, 0.14, 0.16)  # o que era luz azul está apagado
		if nome != "rosto":
			cor = Color(cor.r * 0.5, cor.g * 0.5, cor.b * 0.5)  # a pintura perdeu a cor
		mi.material_override = _mat_cor(cor, 0.65 if nome != "rosto" else 0.0, 0.85 if nome != "rosto" else 0.4, tex)
	faisca_em = f.global_transform.origin if f.is_inside_tree() else (o.t * pe)
	# encosto: o resto de parede atrás dele, e o corpo segura o robô do jogador
	var no_caminho := o.t * pe
	Obstaculos.registrar(no_caminho.x, no_caminho.z, 0.6)
	# o mato em cima dele: no colo, nos ombros, na cabeça e em volta
	var mundo_de := func(osso: String, extra: Vector3) -> Vector3:
		var bi := sk.find_bone(osso)
		return f.transform * (no_f * (sk.get_bone_global_pose(bi).origin + extra)) if bi >= 0 else f.transform.origin
	for item: Array in [["q_flor_b", "head", Vector3(-0.08, 0.4, -0.05), 0.22]]:
		var nome_p: String = item[0]
		if o.v._malhas.has(nome_p):
			var w: Vector3 = mundo_de.call(item[1], item[2])
			o.v._por(nome_p, Transform3D(Basis(Vector3.UP, w.x * 2.1).scaled(Vector3.ONE * float(item[3])), w))
	# plantas pequenas em volta dele e entre as pernas (frente = +Z dele)
	var gb := Basis(Vector3.UP, giro)
	for item2: Array in [["q_trevo", Vector3(0.0, 0, 0.36), 0.13], ["q_flor_c", Vector3(0.03, 0, 0.52), 0.16], ["q_planta_a", Vector3(-0.42, 0, 0.15), 0.16],
			["q_trevo", Vector3(0.44, 0, 0.3), 0.15], ["q_planta_b", Vector3(-0.36, 0, 0.62), 0.14], ["q_flor_a", Vector3(0.4, 0, 0.7), 0.15],
			["q_cogumelo", Vector3(-0.5, 0, -0.12), 0.3], ["q_trevo", Vector3(0.1, 0, 0.86), 0.14], ["q_planta_d", Vector3(0.52, 0, -0.08), 0.16],
			["q_trevo", Vector3(-0.2, 0, 0.92), 0.12], ["q_flor_c", Vector3(-0.56, 0, 0.45), 0.14]]:
		_planta(o, item2[0], pe + gb * ((item2[1] as Vector3) * 0.62), item2[2])
