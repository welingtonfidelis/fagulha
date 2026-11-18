class_name Clareira
extends Ilha
## Primeiro quadro do novo rumo (2026-11-14): uma clareira de floresta temperada, feita à mão, para
## acertar o visual antes de crescer o vale. 320 × 320 m, um ponto por metro. Campo de capim no meio,
## riacho que cruza até uma lagoa, uma pedra-mirante, carvalhos soltos, e a mata fechando em volta
## sobre colinas. Estilo: luz em faixas, formas simples, cores limpas (scripts/shaders/vale_*).

const TROCA_ARVORE := 190.0  # a esta distância cada árvore já é a versão leve dela
const TROCA_VULTO := 450.0  # e a esta, o vulto genérico
const FAIXA_TROCA := 34.0  # a mesma de vale_comum.gdshaderinc
const C_N := 321
const C_META := 160.0
const NIVEL := 19.4  # água do riacho e da lagoa
const V := "res://assets/vale/"
const RIACHO: Array[Vector2] = [Vector2(-96, -70), Vector2(-60, -48), Vector2(-34, -40), Vector2(-12, -22), Vector2(8, -18), Vector2(26, -6)]
const LAGOA := Vector3(34.0, -2.0, 12.0)  # x, z, raio
const LAGOA_FUNDO := 3.4  # metros a mais de fundura no meio
# Sem estradas (pedido do usuário): ninguém passa sempre por aqui. Só alguns claros naturais de terra
# e capim ralo, de borda irregular (x, z, raio).
const CLAROS: Array[Vector3] = [Vector3(-6, 58, 4.5), Vector3(9, 24, 3.2), Vector3(-31, -11, 5.0), Vector3(52, 40, 3.6), Vector3(2, 44, 12.5)]  # o último é o chão batido da base
const MIRANTE := Vector2(-46.0, 22.0)

var cervos_em: Array[Vector3] = []
var _tex: NoiseTexture2D
var _malhas := {}
var _mats := {}
var _corpo_pedras: StaticBody3D
var _n_base: FastNoiseLite
var _n_morro: FastNoiseLite


## 0 a 1: quanto o ponto está dentro de um claro natural (borda torta, sem forma de caminho).
static func _claro(p: Vector2) -> float:
	var m := 0.0
	for c in CLAROS:
		var d := p - Vector2(c.x, c.y)
		var ang := atan2(d.y, d.x)
		var r := c.z * (1.0 + 0.28 * sin(ang * 3.0 + c.x) + 0.16 * sin(ang * 7.0 + c.y))
		m = maxf(m, 1.0 - smoothstep(r * 0.55, r, d.length()))
	return m


static func _dist_linha(p: Vector2, linha: Array[Vector2]) -> float:
	var d := INF
	for i in linha.size() - 1:
		var a := linha[i]
		var ab := linha[i + 1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		d = minf(d, p.distance_to(a + ab * t))
	return d


func _alt(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var r := p.length()
	var h := 20.6 + _n_base.get_noise_2d(x, z) * 1.3
	# colinas em volta, fechando o quadro
	h += smoothstep(72.0, 150.0, r + _n_morro.get_noise_2d(x, z) * 26.0) * (30.0 + _n_morro.get_noise_2d(z, x) * 10.0)
	# riacho e lagoa: leito abaixo do nível da água
	var dr := _dist_linha(p, RIACHO)
	h = minf(h, lerpf(NIVEL - 0.7, h, smoothstep(1.6, 5.5, dr)))
	var dl := p.distance_to(Vector2(LAGOA.x, LAGOA.y))
	# a lagoa afunda no meio (5 m), para o robô poder nadar
	h = minf(h, lerpf(NIVEL - 1.8 - LAGOA_FUNDO * (1.0 - smoothstep(0.0, LAGOA.z * 0.75, dl)), h, smoothstep(LAGOA.z * 0.55, LAGOA.z * 1.25, dl)))
	return h


func gerar(_semente := 7) -> void:
	var t0 := Time.get_ticks_msec()
	_n_base = _ruido(21, 1.0 / 46.0, 3)
	_n_morro = _ruido(22, 1.0 / 90.0, 3)
	_n_mata = _ruido(23, 1.0 / 60.0, 2)
	_tex = NoiseTexture2D.new()
	_tex.width = 512
	_tex.height = 512
	_tex.seamless = true
	_tex.noise = _ruido(77, 1.0 / 40.0, 4)
	Tempos.marca("ruídos")
	var guardado: Variant = Cache.ler("clareira_grade")
	if guardado is Dictionary:
		alturas = guardado["alturas"]
		normais = guardado["normais"]
		cores = guardado["cores"]
	else:
		alturas.resize(C_N * C_N)
		for iz in C_N:
			for ix in C_N:
				alturas[iz * C_N + ix] = _alt(-C_META + ix, -C_META + iz)
		normais.resize(C_N * C_N)
		cores.resize(C_N * C_N)
		for iz in C_N:
			for ix in C_N:
				var i := iz * C_N + ix
				var hl := alturas[i - 1] if ix > 0 else alturas[i]
				var hr := alturas[i + 1] if ix < C_N - 1 else alturas[i]
				var hd := alturas[i - C_N] if iz > 0 else alturas[i]
				var hu := alturas[i + C_N] if iz < C_N - 1 else alturas[i]
				normais[i] = Vector3(hl - hr, 2.0, hd - hu).normalized()
				var p := Vector2(-C_META + ix, -C_META + iz)
				var trilha := _claro(p)
				var molhado := 1.0 - smoothstep(NIVEL - 0.1, NIVEL + 0.45, alturas[i])
				cores[i] = Color(trilha, molhado, 0.0)
		Cache.gravar("clareira_grade", {"alturas": alturas, "normais": normais, "cores": cores})
	Tempos.marca("grade da clareira")
	_materiais()
	Tempos.marca("_materiais")
	_malha()
	Tempos.marca("_malha")
	_colisao()
	Tempos.marca("_colisao")
	_agua()
	Tempos.marca("_agua")
	_modelos()
	Tempos.marca("_modelos")
	_arvores_e_pedras()
	Tempos.marca("_arvores_e_pedras")
	_capim()
	Tempos.marca("_capim")
	_preparar_colisao_arvores()
	Tempos.marca("_preparar_colisao_arvores")
	spawn = Vector3(2.0, altura(2.0, 44.0) + 0.45, 44.0)  # em cima do estrado da base
	spawn_yaw = atan2(-(LAGOA.x - 2.0) * 0.4, 44.0 + 10.0)  # olhando o campo, o riacho e a lagoa
	lago_centro = Vector2(LAGOA.x, LAGOA.y)
	lago_nivel = NIVEL
	for p in [Vector2(-20, 14), Vector2(14, 22), Vector2(-4, -44)]:
		cervos_em.append(Vector3(p.x, altura(p.x, p.y), p.y))
	print("clareira gerada em %d ms, %d árvores" % [Time.get_ticks_msec() - t0, arv_pos.size()])


func altura(x: float, z: float) -> float:
	var fx := clampf(x + C_META, 0.0, C_N - 1.001)
	var fz := clampf(z + C_META, 0.0, C_N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var i := iz * C_N + ix
	return lerpf(lerpf(alturas[i], alturas[i + 1], fx - ix), lerpf(alturas[i + C_N], alturas[i + C_N + 1], fx - ix), fz - iz)


func agua(x: float, z: float) -> float:
	return NIVEL if altura(x, z) < NIVEL else -INF


func normal_em(x: float, z: float) -> Vector3:
	return normais[clampi(roundi(z + C_META), 0, C_N - 1) * C_N + clampi(roundi(x + C_META), 0, C_N - 1)]


# ---------------------------------------------------------------- materiais

func _solido(cor: Color, musgo := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_solido.gdshader")
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("musgo", musgo)
	m.set_shader_parameter("ruido", _tex)
	return m


## Concreto velho: juntas das fôrmas, escorridos e limo escuro (vale_concreto.gdshader).
func _concreto(cor: Color, limo: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_concreto.gdshader")
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("limo", limo)
	m.set_shader_parameter("ruido", _tex)
	return m


func _folha(fundo: Color, meio: Color, topo: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_folha.gdshader")
	m.set_shader_parameter("fundo", fundo)
	m.set_shader_parameter("meio", meio)
	m.set_shader_parameter("topo", topo)
	m.set_shader_parameter("ruido", _tex)
	return m


func _materiais() -> void:
	_mats = {
		"tronco": _solido(Color(0.17, 0.12, 0.085)),
		"casca_clara": _solido(Color(0.70, 0.68, 0.60)),
		"rocha": _solido(Color(0.33, 0.34, 0.37), 1.0),
		"folha": _folha(Color(0.045, 0.15, 0.08), Color(0.13, 0.30, 0.09), Color(0.33, 0.47, 0.12)),
		"folha_clara": _folha(Color(0.12, 0.24, 0.07), Color(0.30, 0.42, 0.10), Color(0.55, 0.60, 0.16)),
		"folha_escura": _folha(Color(0.02, 0.085, 0.07), Color(0.05, 0.16, 0.10), Color(0.12, 0.27, 0.13)),
		"pelo": _solido(Color(0.33, 0.225, 0.14)),
		"pelo_escuro": _solido(Color(0.24, 0.15, 0.09)),
		"pelo_claro": _solido(Color(0.78, 0.72, 0.60)),
		"chifre": _solido(Color(0.62, 0.56, 0.45)),
		"casco": _solido(Color(0.13, 0.15, 0.17)),
		"casco_claro": _solido(Color(0.33, 0.31, 0.26)),
		"ferrugem": _solido(Color(0.28, 0.13, 0.07)),
		"junta": _solido(Color(0.05, 0.055, 0.06)),
		"musgo": _solido(Color(0.13, 0.26, 0.08)),
		# as construções de concreto e metal da ilha de 3 km: concreto gasto, tinta desbotada e vidro sujo
		"concreto": _concreto(Color(0.47, 0.46, 0.43), 0.6),
		"concreto_pintado": _concreto(Color(0.40, 0.21, 0.17), 0.3),  # a faixa vermelha do farol, desbotada
		"tinta_velha": _solido(Color(0.30, 0.165, 0.13), 0.9),
		"vidro_velho": _solido(Color(0.30, 0.46, 0.44)),
		# a lata dos contêineres, desbotada
		"lata_azul": _solido(Color(0.15, 0.24, 0.31), 0.5),
		"lata_verde": _solido(Color(0.18, 0.27, 0.19), 0.5),
		"lata_ocre": _solido(Color(0.42, 0.31, 0.13), 0.5),
		"pelo_coelho": _solido(Color(0.40, 0.34, 0.27)),
		"pena": _solido(Color(0.15, 0.18, 0.24)),
		"pena_clara": _solido(Color(0.66, 0.40, 0.24)),
		"bico": _solido(Color(0.78, 0.58, 0.20)),
		"peixe": _solido(Color(0.09, 0.13, 0.12)),
	}
	# árvores e plantas dos pacotes do Quaternius (assets/vale/q): textura do modelo com a luz do vale
	var folha_q := Color(0.52, 0.64, 0.44)
	_mats["q_casca"] = _tex_q("casca.jpg", Color(0.62, 0.55, 0.5), 0.0, 0.0)
	_mats["q_casca_betula"] = _tex_q("casca_betula.png", Color(0.82, 0.82, 0.78), 0.0, 0.0)
	_mats["q_folha"] = _tex_q("folha.png", folha_q, 0.4, 1.0)
	_mats["q_folha_betula"] = _tex_q("folha_betula.png", folha_q, 0.4, 1.0)
	_mats["q_folha_amarela"] = _tex_q("folha_amarela.png", Color(0.80, 0.70, 0.42), 0.4, 1.0)
	_mats["q_folha_pinheiro"] = _tex_q("folha_pinheiro.png", Color(0.50, 0.62, 0.50), 0.4, 1.0)
	_mats["q_folha_vinho"] = _tex_q("folha_vinho.png", Color(0.72, 0.52, 0.52), 0.4, 1.0)
	_mats["q_folha_laranja"] = _tex_q("folha_laranja.png", Color(0.78, 0.62, 0.45), 0.4, 1.0)
	_mats["q_planta"] = _tex_q("planta.png", Color(0.60, 0.72, 0.50), 0.4, 0.5, 1.2)
	_mats["q_flor"] = _tex_q("flor.png", Color(0.95, 0.9, 0.85), 0.4, 0.5, 1.2)
	_mats["q_cogumelo"] = _tex_q("cogumelo.png", Color(0.85, 0.8, 0.75), 0.0, 0.0)
	_mats["q_moita"] = _tex_q("moita.png", folha_q, 0.4, 0.4, 0.5)
	_mats["q_leaves_normaltree"] = _mats["q_moita"]
	_mats["q_pedra"] = _tex_q("pedra.png", Color(0.62, 0.63, 0.66), 0.0, 0.0)
	_mats["q_seixo"] = _tex_q("seixo.png", Color(0.62, 0.63, 0.66), 0.0, 0.0)


func _tex_q(arquivo: String, tinta: Color, corte: float, vento: float, alto_vento := 0.12) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_tex.gdshader")
	m.set_shader_parameter("tex", load(V + "q/" + arquivo))
	m.set_shader_parameter("tinta", tinta)
	m.set_shader_parameter("corte", corte)
	m.set_shader_parameter("vento", vento)
	m.set_shader_parameter("alto_vento", alto_vento)
	m.set_shader_parameter("ruido", _tex)
	return m


func material(nome: String) -> ShaderMaterial:
	return _mats.get(nome, _mats["rocha"])


# ---------------------------------------------------------------- chão, água

func _malha() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_chao.gdshader")
	mat.set_shader_parameter("ruido", _tex)
	var bl := 64
	var lado := bl + 1
	for bz in (C_N - 1) / bl:
		for bx in (C_N - 1) / bl:
			var verts := PackedVector3Array()
			var nrms := PackedVector3Array()
			var cols := PackedColorArray()
			verts.resize(lado * lado)
			nrms.resize(lado * lado)
			cols.resize(lado * lado)
			for j in lado:
				for i in lado:
					var g := (bz * bl + j) * C_N + bx * bl + i
					var k := j * lado + i
					verts[k] = Vector3(-C_META + bx * bl + i, alturas[g], -C_META + bz * bl + j)
					nrms[k] = normais[g]
					cols[k] = cores[g]
			var idx := PackedInt32Array()
			idx.resize(bl * bl * 6)
			var p := 0
			for j in bl:
				for i in bl:
					var a := j * lado + i
					idx[p] = a
					idx[p + 1] = a + 1
					idx[p + 2] = a + lado + 1
					idx[p + 3] = a
					idx[p + 4] = a + lado + 1
					idx[p + 5] = a + lado
					p += 6
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = nrms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = m
			add_child(mi)


func _colisao() -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := HeightMapShape3D.new()
	forma.map_width = C_N
	forma.map_depth = C_N
	forma.map_data = alturas
	var cs := CollisionShape3D.new()
	cs.shape = forma
	corpo.add_child(cs)
	_corpo_pedras = StaticBody3D.new()
	_corpo_pedras.collision_layer = 1
	_corpo_pedras.collision_mask = 0
	add_child(_corpo_pedras)


func _agua() -> void:
	var ruido_agua := NoiseTexture2D.new()
	ruido_agua.width = 256
	ruido_agua.height = 256
	ruido_agua.seamless = true
	ruido_agua.noise = _ruido(61, 1.0 / 11.0, 3)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/rio.gdshader")
	mat.set_shader_parameter("ruido", ruido_agua)
	mat.set_shader_parameter("raso", Color(0.20, 0.45, 0.42))
	mat.set_shader_parameter("fundo", Color(0.04, 0.16, 0.20))
	mat.set_shader_parameter("fluxo", Vector2(0.8, 0.45))
	mat.set_shader_parameter("velocidade", 0.35)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(220, 220)
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(0, NIVEL, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- modelos

func _modelos() -> void:
	for nome in ["carvalho_a", "carvalho_b", "carvalho_a_longe", "carvalho_b_longe", "betula", "betula_longe", "pinheiro",
			"pinheiro_longe", "arbusto", "pedra_a", "pedra_b", "pedra_alta"]:
		var cena: PackedScene = load(V + nome + ".glb")
		var raiz := cena.instantiate() as Node3D
		var lista := []
		_juntar(raiz, Transform3D.IDENTITY, lista)
		raiz.free()
		_malhas[nome] = lista
	# modelos dos pacotes (tools/vale/pacotes.py): as árvores têm versão de longe
	for nome: String in Q_ARVORES:
		_modelo_q(nome, nome, {})
		_modelo_q(nome + "_longe", nome + "_longe", {})
	for nome: String in Q_PLANTAS:
		_modelo_q(nome, nome, {})
	# a mesma árvore com outra folhagem
	for nome: String in Q_CORES:
		var v: Array = Q_CORES[nome]
		_modelo_q(nome, v[0], {v[1]: v[2]})
		_modelo_q(nome + "_longe", String(v[0]) + "_longe", {v[1]: v[2]})


const Q_ARVORES := ["q_arvore_a", "q_arvore_b", "q_arvore_c", "q_arvore_d", "q_betula_a", "q_betula_b", "q_betula_c",
	"q_pinheiro_a", "q_pinheiro_b", "q_pinheiro_c", "q_morta_a", "q_morta_b", "q_morta_c"]
const Q_PLANTAS := ["q_samambaia", "q_planta_a", "q_planta_b", "q_planta_c", "q_planta_d", "q_flor_a", "q_flor_b", "q_flor_c",
	"q_flor_d", "q_cogumelo", "q_moita", "q_moita_flor", "q_trevo", "q_pedra_a", "q_pedra_b", "q_pedra_c", "q_seixo_a", "q_seixo_b"]
const Q_CORES := {
	"q_betula_a_amarela": ["q_betula_a", "q_folha_betula", "q_folha_amarela"],
	"q_betula_c_amarela": ["q_betula_c", "q_folha_betula", "q_folha_amarela"],
	"q_arvore_b_vinho": ["q_arvore_b", "q_folha", "q_folha_vinho"],
	"q_arvore_d_laranja": ["q_arvore_d", "q_folha", "q_folha_laranja"],
}


## Carrega um modelo dos pacotes: cada malha vira uma cópia com os materiais do vale (pelo nome do material
## do arquivo), com `troca` para as variações de cor.
func _modelo_q(nome: String, arquivo: String, troca: Dictionary) -> void:
	var cena: PackedScene = load(V + "q/" + arquivo + ".glb")
	var raiz := cena.instantiate() as Node3D
	var lista := []
	for n in raiz.find_children("*", "MeshInstance3D", true, false) + ([raiz] if raiz is MeshInstance3D else []):
		var mi := n as MeshInstance3D
		var copia := mi.mesh.duplicate() as Mesh
		for s in copia.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var nm := String(m.resource_name) if m else "rocha"
			copia.surface_set_material(s, material(String(troca.get(nm, nm))))
		var t := mi.transform
		var pai := mi.get_parent()
		while pai != null and pai is Node3D:
			t = (pai as Node3D).transform * t
			pai = pai.get_parent()
		lista.append([copia, t])
	raiz.free()
	_malhas[nome] = lista


## Troca parte das árvores do vale pelas dos pacotes, para variar a mata. `u` (0 a 1) vem da posição, não do
## sorteio da mata, para as árvores ficarem onde sempre estiveram.
static func tipo_variado(tipo: String, u: float) -> String:
	if "--sem-pacotes" in OS.get_cmdline_user_args():
		return tipo  # para comparar o desempenho com e sem os modelos dos pacotes
	var v := fposmod(u * 7.31, 1.0)
	match tipo:
		# (até 2026-11-18 uma parte das árvores continuava sendo a nossa, feita por código; o usuário pediu um
		# padrão só, o do pacote Nature. As antigas ficam só como vulto, além de 450 m.)
		"pinheiro":
			return ["q_pinheiro_a", "q_pinheiro_b", "q_pinheiro_c"][int(v * 3.0) % 3]
		"betula":
			if u < 0.3:
				return "q_betula_a_amarela" if v < 0.5 else "q_betula_c_amarela"
			return ["q_betula_a", "q_betula_b", "q_betula_c"][int(v * 3.0) % 3]
		_:
			if u < 0.05:
				return ["q_morta_a", "q_morta_b", "q_morta_c"][int(v * 3.0) % 3]
			if u < 0.09:
				return "q_arvore_b_vinho"
			if u < 0.13:
				return "q_arvore_d_laranja"
			return ["q_arvore_a", "q_arvore_b", "q_arvore_c", "q_arvore_d"][int(v * 4.0) % 4]


## A versão leve de cada árvore (176 a 550 triângulos nas dos pacotes): é o que se vê de TROCA_ARVORE até
## TROCA_VULTO, para a troca não mudar a forma da árvore.
static func longe_de(tipo: String) -> String:
	return tipo + "_longe"


## O vulto genérico, de TROCA_VULTO em diante: lá a forma exata não se nota, e os vultos das árvores antigas
## são bem mais baratos (levar a versão leve de cada modelo até o horizonte custava uns 20% nas vistas altas).
static func vulto_de(tipo: String) -> String:
	if not tipo.begins_with("q_") or Q_CORES.has(tipo) or tipo.contains("morta"):
		return tipo + "_longe"
	if tipo.contains("pinheiro"):
		return "pinheiro_longe"
	if tipo.contains("betula"):
		return "betula_longe"
	return "carvalho_b_longe" if (tipo.ends_with("_b") or tipo.ends_with("_c")) else "carvalho_a_longe"


static func sorte_do_lugar(x: float, z: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)


func _juntar(no: Node, base: Transform3D, lista: Array) -> void:
	var t := base
	if no is Node3D:
		t = base * (no as Node3D).transform
	if no is MeshInstance3D:
		var mesh := (no as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			mesh.surface_set_material(s, material(m.resource_name if m else "rocha"))
		lista.append([mesh, t])
	for f in no.get_children():
		_juntar(f, t, lista)


func _por(nome: String, xf: Transform3D, colisao := false) -> void:
	for par in _malhas[nome]:
		var mi := MeshInstance3D.new()
		mi.mesh = par[0]
		mi.transform = xf * (par[1] as Transform3D)
		add_child(mi)
		if colisao:
			var cs := CollisionShape3D.new()
			cs.shape = (par[0] as Mesh).create_convex_shape()
			cs.transform = mi.transform
			_corpo_pedras.add_child(cs)
			Obstaculos.registrar_forma(cs.shape, cs.transform, altura(cs.transform.origin.x, cs.transform.origin.z))


## A mata da clareira pode pôr árvore aqui? (o vale maior corta os cantos do quadrado)
func _arvore_cabe(_x: float, _z: float) -> bool:
	return true


func _arvore(tipo: String, x: float, z: float, s: float, giro: float) -> void:
	var h := altura(x, z)
	arv_pos.append(Vector3(x, h - 0.15, z))
	arv_escala.append(s * 0.8)
	arv_tipo.append(0 if tipo.contains("pinheiro") else 1)
	arv_nome.append(tipo)
	_fila_arv.append([tipo, Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * s), Vector3(x, h - 0.15, z))])


var _fila_arv: Array = []
var arv_nome := PackedStringArray()  # o modelo de cada árvore, na ordem de arv_pos
var _forma_arv := {}  # modelo -> medidas da colisão na escala 1


## Mede um modelo de árvore para a colisão: o raio em 24 faixas de altura. O tronco é a parte fina de baixo;
## a copa sólida é só o miolo (as pontas dos galhos e das folhas deixam passar), de onde a folhagem engrossa
## até perto do topo. Nos pinheiros, de galhos ralos desde o chão, o miolo é fino e começa acima do robô.
func forma_da_arvore(nome: String) -> Array:
	if _forma_arv.has(nome):
		return _forma_arv[nome]
	var topo := 0.01
	var pts := PackedVector3Array()
	for par in _malhas[nome]:
		var mesh: Mesh = par[0]
		for sf in mesh.get_surface_count():
			for p: Vector3 in mesh.surface_get_arrays(sf)[Mesh.ARRAY_VERTEX]:
				var q := (par[1] as Transform3D) * p
				pts.append(q)
				topo = maxf(topo, q.y)
	var n := 24
	var faixa := PackedFloat32Array()
	faixa.resize(n)
	for q in pts:
		var k := clampi(int(q.y / topo * n), 0, n - 1)
		faixa[k] = maxf(faixa[k], Vector2(q.x, q.z).length())
	var maior := 0.0
	for k in n:
		maior = maxf(maior, faixa[k])
	var conif := nome.contains("pinheiro")
	var de := n
	for k in n:
		if faixa[k] > maior * 0.4 and (not conif or topo * k / n >= 2.6):
			de = k
			break
	var soma := 0.0
	var quantas := 0
	for k in range(de, n):
		if faixa[k] > 0.0:
			soma += faixa[k]
			quantas += 1
	var copa_de := topo * de / n
	var copa_ate := topo - 0.4
	var r_copa := (soma / maxf(1.0, quantas)) * (0.3 if conif else 0.55)
	r_copa = minf(r_copa, (copa_ate - copa_de) * 0.5)
	var r_tronco := 0.6
	for k in range(0, maxi(1, de)):
		if faixa[k] > 0.05:
			r_tronco = minf(r_tronco, faixa[k])
	r_tronco = clampf(r_tronco, 0.2, 0.6) if not conif else 0.3
	var f := [r_tronco, copa_de + maxf(r_copa, 0.3), r_copa, (copa_de + copa_ate) * 0.5, copa_ate - copa_de]
	_forma_arv[nome] = f
	return f


func _medidas_colisao(i: int) -> Array:
	if i >= arv_nome.size() or not _malhas.has(arv_nome[i]):
		return super._medidas_colisao(i)
	var f := forma_da_arvore(arv_nome[i])
	var s := arv_escala[i] / 0.8  # a escala com que o modelo foi desenhado
	return [f[0] * s, f[1] * s, f[2] * s, f[3] * s, f[4] * s]
var capim_malha: ArrayMesh  # a touceira com o material do capim (o capim de fora da clareira reusa)


func _arvores_e_pedras() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# postas à mão: carvalhos soltos no campo, bétulas na beira d'água
	_arvore("carvalho_b", -14.0, 26.0, 1.25, 0.4)
	_arvore("carvalho_a", 22.0, 38.0, 1.1, 2.1)
	_arvore("carvalho_a", -58.0, -4.0, 1.2, 4.0)
	_arvore("betula", 48.0, 6.0, 1.0, 1.0)
	_arvore("betula", 44.0, 14.0, 0.85, 2.5)
	_arvore("betula", 20.0, -22.0, 0.95, 0.2)
	# a mata em volta: fecha o quadro nas colinas
	var z := -C_META + 6.0
	while z < C_META - 6.0:
		var x := -C_META + 6.0
		while x < C_META - 6.0:
			var px := x + rng.randf_range(-2.6, 2.6)
			var pz := z + rng.randf_range(-2.6, 2.6)
			x += 6.5
			var r := Vector2(px, pz).length()
			if agua(px, pz) > -INF or normal_em(px, pz).y < 0.8 or _claro(Vector2(px, pz)) > 0.2:
				continue
			var borda := smoothstep(58.0, 84.0, r + _n_mata.get_noise_2d(px, pz) * 22.0)
			if rng.randf() > borda * 0.85:
				continue
			var sorte := rng.randf()
			var alto := altura(px, pz) > 34.0
			var tipo := "pinheiro" if (sorte < (0.55 if alto else 0.15)) else ("betula" if sorte > 0.86 else ("carvalho_a" if sorte < 0.6 else "carvalho_b"))
			# os sorteios acontecem sempre, para as árvores da clareira ficarem onde sempre estiveram
			var esc := rng.randf_range(0.85, 1.5)
			var giro := rng.randf() * TAU
			if _arvore_cabe(px, pz):
				_arvore(tipo_variado(tipo, sorte_do_lugar(px, pz)), px, pz, esc, giro)
		z += 6.5
	for i in arv_pos.size():
		var cel := Vector2i(floori(arv_pos[i].x / CELULA_ARVORE), floori(arv_pos[i].z / CELULA_ARVORE))
		if not _grade_arv.has(cel):
			_grade_arv[cel] = PackedInt32Array()
		var l: PackedInt32Array = _grade_arv[cel]
		l.append(i)
		_grade_arv[cel] = l
	# desenho: por tipo e por bloco de 80 m, completo perto e leve de longe
	var grupos := {}
	for item in _fila_arv:
		var xf: Transform3D = item[1]
		var chave := "%s|%d|%d" % [item[0], floori(xf.origin.x / 80.0), floori(xf.origin.z / 80.0)]
		if not grupos.has(chave):
			grupos[chave] = []
		(grupos[chave] as Array).append(xf)
	for chave in grupos:
		var tipo: String = (chave as String).split("|")[0]
		var xfs: Array = grupos[chave]
		var centro := Vector3.ZERO
		for xf in xfs:
			centro += (xf as Transform3D).origin
		centro /= xfs.size()
		_multi(tipo, xfs, centro, 0.0, TROCA_ARVORE, true)
	for chave in _por_bloco(_fila_arv, 400.0, true):
		var xfs2: Array = chave[1]
		_multi(chave[0], xfs2, _centro(xfs2), TROCA_ARVORE, TROCA_VULTO, true)
	for chave in _por_bloco(_fila_arv, 400.0, true, true):
		var xfs3: Array = chave[1]
		_multi(chave[0], xfs3, _centro(xfs3), TROCA_VULTO, 0.0, false)
	# arbustos na beira da mata
	var arb: Array = []
	for k in 260:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(56.0, 80.0)
		var p := Vector2(cos(ang), sin(ang)) * r
		if agua(p.x, p.y) > -INF or _claro(p) > 0.2:
			continue
		var s := rng.randf_range(0.8, 1.9)
		arb.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.85, s)), Vector3(p.x, altura(p.x, p.y) - 0.1, p.y)))
	_multi("arbusto", arb, Vector3.ZERO, 0.0, 0.0, true)
	# pedras postas à mão: o mirante, a beira da lagoa e o riacho
	var hm := altura(MIRANTE.x, MIRANTE.y)
	_por("pedra_alta", Transform3D(Basis(Vector3.UP, 0.6).scaled(Vector3.ONE * 4.2), Vector3(MIRANTE.x, hm + 2.2, MIRANTE.y)), true)
	_por("pedra_b", Transform3D(Basis(Vector3.UP, 2.0).scaled(Vector3.ONE * 3.0), Vector3(MIRANTE.x + 5.0, hm + 0.4, MIRANTE.y + 3.0)), true)
	_por("pedra_a", Transform3D(Basis(Vector3.UP, 1.0).scaled(Vector3.ONE * 1.8), Vector3(MIRANTE.x - 4.5, hm + 0.2, MIRANTE.y - 2.0)), true)
	for d in [[Vector2(46, -10), 2.2, "pedra_a"], [Vector2(40, 10), 1.5, "pedra_b"], [Vector2(24, -12), 1.2, "pedra_a"], [Vector2(-22, -30), 1.4, "pedra_b"],
			[Vector2(-40, -47), 1.9, "pedra_a"], [Vector2(2, -16), 0.9, "pedra_a"], [Vector2(30, 9), 0.8, "pedra_b"]]:
		var p: Vector2 = d[0]
		var s: float = d[1]
		_por(d[2], Transform3D(Basis(Vector3.UP, p.x).scaled(Vector3.ONE * s), Vector3(p.x, altura(p.x, p.y) + s * 0.15, p.y)), true)


## Junta a fila de árvores por modelo e por bloco do mapa: [[modelo, transformações], ...]. Com `longe`, pelo
## modelo de longe (vários tipos caem no mesmo).
func _por_bloco(fila: Array, bloco: float, longe: bool, vulto := false) -> Array:
	var grupos := {}
	for item in fila:
		var xf: Transform3D = item[1]
		var nome: String = (vulto_de(item[0]) if vulto else longe_de(item[0])) if longe else String(item[0])
		var chave := "%s|%d|%d" % [nome, floori(xf.origin.x / bloco), floori(xf.origin.z / bloco)]
		if not grupos.has(chave):
			grupos[chave] = [nome, []]
		((grupos[chave] as Array)[1] as Array).append(xf)
	return grupos.values()


func _centro(xfs: Array) -> Vector3:
	var centro := Vector3.ZERO
	for xf in xfs:
		centro += (xf as Transform3D).origin
	return centro / maxf(1.0, xfs.size())


## Um MultiMesh por malha do modelo. `de` e `ate` são distâncias por peça (0 desliga): o modelo aparece aos
## poucos até `de` e some aos poucos até `ate`, cada peça pela distância dela até a câmera (vale_comum:
## `presenca`). O bloco inteiro só deixa de ser desenhado quando nenhuma peça dele pode aparecer.
func _multi(nome: String, xfs: Array, centro: Vector3, de: float, ate: float, sombra: bool) -> void:
	var raio := 0.0
	for xf in xfs:
		raio = maxf(raio, (xf as Transform3D).origin.distance_to(centro))
	for par in _malhas[nome]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = de > 0.0 or ate > 0.0
		mm.mesh = par[0]
		mm.instance_count = xfs.size()
		for k in xfs.size():
			var t := (xfs[k] as Transform3D) * (par[1] as Transform3D)
			t.origin -= centro
			mm.set_instance_transform(k, t)
			if mm.use_custom_data:
				mm.set_instance_custom_data(k, Color(ate, de, 0.0, 0.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = centro
		if de > 0.0 or ate > 0.0:
			# as distâncias mudam com a qualidade do desenho: Qualidade refaz as faixas destes blocos
			mmi.set_meta("troca", Vector3(de, ate, raio))
			mmi.add_to_group("por_distancia")
			Qualidade.preparar_bloco(mmi)
		if not sombra:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


# ---------------------------------------------------------------- capim

func _touceira() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for f in 11:
		var ang := r.randf() * TAU
		var dir := Vector3(cos(ang), 0, sin(ang))
		var lado := Vector3(-dir.z, 0, dir.x)
		var base := dir * r.randf_range(0.0, 0.2)
		var alt := r.randf_range(0.2, 0.42)
		var larg := r.randf_range(0.016, 0.028)
		var meio := base + dir * 0.05 + Vector3(0, alt * 0.55, 0)
		var ponta := base + dir * r.randf_range(0.08, 0.2) + Vector3(0, alt, 0)
		for v in [base - lado * larg, base + lado * larg, meio + lado * larg * 0.6, base - lado * larg, meio + lado * larg * 0.6,
				meio - lado * larg * 0.6, meio - lado * larg * 0.6, meio + lado * larg * 0.6, ponta]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


func _capim() -> void:
	var touceira := _touceira()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_capim.gdshader")
	mat.set_shader_parameter("ruido", _tex)
	touceira.surface_set_material(0, mat)
	Qualidade.registrar_material(mat)
	capim_malha = touceira
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var blocos := {}
	var passo := 0.4
	var z := -118.0
	while z < 118.0:
		var x := -118.0
		while x < 118.0:
			var px := x + rng.randf_range(-0.2, 0.2)
			var pz := z + rng.randf_range(-0.2, 0.2)
			x += passo
			var i := clampi(roundi(pz + C_META), 0, C_N - 1) * C_N + clampi(roundi(px + C_META), 0, C_N - 1)
			if normais[i].y < 0.9 or alturas[i] < NIVEL + 0.12 or cores[i].r > 0.45:
				continue
			var r := Vector2(px, pz).length()
			if r > 116.0 or (r > 80.0 and rng.randf() > 0.45):
				continue
			var chave := Vector2i(floori(px / 32.0), floori(pz / 32.0))
			if not blocos.has(chave):
				blocos[chave] = []
			var s := rng.randf_range(0.75, 1.5)
			(blocos[chave] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.35), s)),
				Vector3(px, altura(px, pz) - 0.03, pz)))
		z += passo
	var total := 0
	for chave in blocos:
		var xfs: Array = blocos[chave]
		total += xfs.size()
		var centro := Vector3((chave.x + 0.5) * 32.0, 20.0, (chave.y + 0.5) * 32.0)
		# duas densidades, como no capim de fora (Qualidade): uma parte vai até 95 m, o resto só perto do robô
		for perto: bool in [false, true]:
			var parte: Array = []
			for k in xfs.size():
				if ((k * 7 + 3) % 10 < int(Qualidade.PARTE_LONGE * 10.0)) != perto:
					var t: Transform3D = xfs[k]
					if not perto:
						t = Transform3D(t.basis.scaled_local(Vector3.ONE * Qualidade.ESCALA_LONGE), t.origin)
					t.origin -= centro
					parte.append(t)
			if parte.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = perto
			mm.mesh = touceira
			mm.instance_count = parte.size()
			for k in parte.size():
				mm.set_instance_transform(k, parte[k])
				if perto:
					mm.set_instance_custom_data(k, Color(1.0, 0.0, 0.0, 0.0))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.position = centro
			mmi.visibility_range_end = Qualidade.CAPIM_ATE + Qualidade.RAIO_BLOCO + 2.0
			mmi.visibility_range_end_margin = 4.0
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if perto:
				mmi.add_to_group("capim_perto")
				Qualidade.preparar_capim_perto(mmi)
			add_child(mmi)
	print("capim: %d touceiras" % total)
