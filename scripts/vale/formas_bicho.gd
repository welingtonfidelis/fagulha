class_name FormasBicho
extends RefCounted
## Os corpos dos bichos desenhados em lote (2026-11-22): os pássaros do céu (AvesCeu), os peixes rasos (PeixesRaso),
## os bichos de terra vistos de longe (VidaLonge) e os insetos (Insetos). Malhas pequenas feitas por código, de faces
## lisas, com a cor em cada vértice (já linear) e, no alfa do vértice, o peso da peça que o shader mexe: a asa
## (ave_ceu; bicho_lote nos modos 2 e 3), a cauda do peixe (modo 0) ou o pescoço e a cabeça (modo 1).
## Em todas a frente é -Z e o alto é +Y; o tamanho é o de verdade, em metros.


## Junta triângulos coloridos numa malha só.
class Malha:
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		st.set_color(ca)
		st.add_vertex(a)
		st.set_color(cb)
		st.add_vertex(b)
		st.set_color(cc)
		st.add_vertex(c)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
		tri(a, b, c, ca, cb, cc)
		tri(a, c, d, ca, cc, cd)

	## Um corpo em fuso ao longo de z: `secoes` é uma lista de [z, meia altura, meia largura, y do meio]. A cor sai de
	## `cor.call(z, s)` (s de -1, embaixo, a 1, em cima) e já traz o peso no alfa.
	func fuso(secoes: Array, lados: int, cor: Callable) -> void:
		for i in secoes.size() - 1:
			var s0: Array = secoes[i]
			var s1: Array = secoes[i + 1]
			for k in lados:
				var a0 := TAU * k / lados
				var a1 := TAU * (k + 1) / lados
				var p00 := Vector3(cos(a0) * s0[2], s0[3] + sin(a0) * s0[1], s0[0])
				var p01 := Vector3(cos(a1) * s0[2], s0[3] + sin(a1) * s0[1], s0[0])
				var p10 := Vector3(cos(a0) * s1[2], s1[3] + sin(a0) * s1[1], s1[0])
				var p11 := Vector3(cos(a1) * s1[2], s1[3] + sin(a1) * s1[1], s1[0])
				quad(p00, p01, p11, p10, cor.call(s0[0], sin(a0)), cor.call(s0[0], sin(a1)), cor.call(s1[0], sin(a1)), cor.call(s1[0], sin(a0)))

	## Um tubo de `lados` faces de `a` a `b` (raios ra e rb), com tampa na ponta. Pesos pa e pb nas duas pontas.
	func tubo(a: Vector3, b: Vector3, ra: float, rb: float, cor_a: Color, cor_b: Color, lados := 4, giro := 0.785) -> void:
		var eixo := (b - a).normalized()
		var u := eixo.cross(Vector3.UP if absf(eixo.y) < 0.9 else Vector3.RIGHT).normalized()
		var w := eixo.cross(u)
		for k in lados:
			var a0 := TAU * k / lados + giro
			var a1 := TAU * (k + 1) / lados + giro
			var d0 := u * cos(a0) + w * sin(a0)
			var d1 := u * cos(a1) + w * sin(a1)
			quad(a + d0 * ra, a + d1 * ra, b + d1 * rb, b + d0 * rb, cor_a, cor_a, cor_b, cor_b)
			tri(b + d0 * rb, b + d1 * rb, b, cor_b, cor_b, cor_b)

	func fechar() -> ArrayMesh:
		st.generate_normals()
		return st.commit()


static func _l(c: Color, peso := 0.0) -> Color:
	var x := c.srgb_to_linear()
	x.a = peso
	return x


# ---------------------------------------------------------------- pássaros

## Um pássaro de asas abertas. Chaves: comp, raio, envergadura, corda, varredura (quanto a ponta vai para trás),
## cauda, cauda_meia, bifurca (cauda em forquilha), e as cores dorso, ventre, asa, ponta, bico e cabeca (opcional).
## O ombro (em volta do qual a asa bate) fica em x = raio * 0.6.
static func ave(e: Dictionary) -> ArrayMesh:
	var m := Malha.new()
	var comp: float = e["comp"]
	var r: float = e["raio"]
	var env: float = e["envergadura"]
	var corda: float = e["corda"]
	var varre: float = e["varredura"]
	var dorso := _l(e["dorso"])
	var ventre := _l(e["ventre"])
	var cabeca := _l(e.get("cabeca", e["dorso"]))
	var asa_c := e["asa"] as Color
	var ponta_c := e["ponta"] as Color
	var cor_corpo := func(z: float, s: float) -> Color:
		var c := ventre.lerp(dorso, smoothstep(-0.35, 0.35, s))
		if z < -0.3 * comp and e.has("cabeca"):
			c = cabeca
		return c
	m.fuso([[-0.5 * comp, r * 0.3, r * 0.3, 0.0], [-0.36 * comp, r * 0.78, r * 0.72, r * 0.12], [-0.15 * comp, r, r, 0.0],
		[0.2 * comp, r * 0.78, r * 0.75, 0.0], [0.45 * comp, r * 0.25, r * 0.3, r * 0.05]], 6, cor_corpo)
	# o bico
	var bc := _l(e["bico"])
	m.tubo(Vector3(0, r * 0.05, -0.5 * comp + r * 0.15), Vector3(0, -r * 0.05, -0.5 * comp - r * 0.9), r * 0.22, r * 0.03, bc, bc, 3)
	# a cauda, chata, aberta em leque (ou em forquilha, nas andorinhas)
	var cz := 0.4 * comp
	var cl: float = e["cauda"]
	var cm: float = e["cauda_meia"]
	var y := r * 0.08
	if e.get("bifurca", false):
		m.tri(Vector3(-r * 0.3, y, cz), Vector3(r * 0.3, y, cz), Vector3(0, y, cz + cl * 0.45), dorso, dorso, dorso)
		m.tri(Vector3(-r * 0.3, y, cz), Vector3(0, y, cz + cl * 0.45), Vector3(-cm, y, cz + cl), dorso, dorso, dorso)
		m.tri(Vector3(r * 0.3, y, cz), Vector3(cm, y, cz + cl), Vector3(0, y, cz + cl * 0.45), dorso, dorso, dorso)
	else:
		m.quad(Vector3(-r * 0.35, y, cz), Vector3(r * 0.35, y, cz), Vector3(cm, y, cz + cl), Vector3(-cm, y, cz + cl), dorso, dorso, dorso, dorso)
	# as asas: duas placas por lado, da raiz ao meio e do meio à ponta (o peso cresce para a ponta: dobra mais)
	var x0 := r * 0.6
	var ya := r * 0.3
	for s: float in [-1.0, 1.0]:
		var rf := Vector3(s * x0, ya, -0.42 * corda)
		var rt := Vector3(s * x0, ya, 0.58 * corda)
		var mf := Vector3(s * env * 0.24, ya, -0.38 * corda + varre * 0.25)
		var mt := Vector3(s * env * 0.24, ya, 0.62 * corda + varre * 0.3)
		var pf := Vector3(s * env * 0.5, ya, varre)
		var pt := Vector3(s * env * 0.44, ya, varre + 0.42 * corda)
		var c_r := _l(asa_c, 0.02)
		var c_m := _l(asa_c, 0.5)
		var c_p := _l(ponta_c, 1.0)
		var c_pt := _l(asa_c.lerp(ponta_c, 0.6), 0.9)
		m.quad(rf, mf, mt, rt, c_r, c_m, c_m, c_r)
		m.quad(mf, pf, pt, mt, c_m, c_p, c_pt, c_m)
	return m.fechar()


const ANDORINHA := {"comp": 0.16, "raio": 0.022, "envergadura": 0.34, "corda": 0.06, "varredura": 0.08, "cauda": 0.08,
	"cauda_meia": 0.035, "bifurca": true, "dorso": Color(0.1, 0.12, 0.26), "ventre": Color(0.86, 0.82, 0.74),
	"asa": Color(0.08, 0.09, 0.18), "ponta": Color(0.05, 0.05, 0.09), "bico": Color(0.1, 0.08, 0.06), "cabeca": Color(0.45, 0.16, 0.1)}
const GAVIAO := {"comp": 0.55, "raio": 0.075, "envergadura": 1.3, "corda": 0.32, "varredura": 0.05, "cauda": 0.22,
	"cauda_meia": 0.1, "dorso": Color(0.36, 0.25, 0.15), "ventre": Color(0.8, 0.72, 0.6), "asa": Color(0.42, 0.3, 0.19),
	"ponta": Color(0.13, 0.1, 0.08), "bico": Color(0.85, 0.7, 0.2)}
const GAIVOTA := {"comp": 0.48, "raio": 0.065, "envergadura": 1.15, "corda": 0.2, "varredura": 0.12, "cauda": 0.12,
	"cauda_meia": 0.07, "dorso": Color(0.64, 0.68, 0.72), "ventre": Color(0.95, 0.95, 0.93), "asa": Color(0.68, 0.72, 0.76),
	"ponta": Color(0.08, 0.08, 0.09), "bico": Color(0.95, 0.78, 0.2), "cabeca": Color(0.96, 0.96, 0.94)}
const GANSO := {"comp": 0.95, "raio": 0.12, "envergadura": 1.6, "corda": 0.3, "varredura": 0.06, "cauda": 0.16,
	"cauda_meia": 0.1, "dorso": Color(0.42, 0.38, 0.33), "ventre": Color(0.8, 0.76, 0.7), "asa": Color(0.4, 0.37, 0.32),
	"ponta": Color(0.16, 0.15, 0.14), "bico": Color(0.12, 0.12, 0.12), "cabeca": Color(0.1, 0.1, 0.1)}


# ---------------------------------------------------------------- peixes

## Um peixe de corpo em fuso, com a cauda em pé e uma barbatana nas costas. Chaves: comp, alt (meia altura),
## larg (meia largura), dorso, flanco, ventre, barbatana. O peso cresce da cabeça (0) à ponta da cauda (1).
static func peixe(e: Dictionary) -> ArrayMesh:
	var m := Malha.new()
	var comp: float = e["comp"]
	var alt: float = e["alt"]
	var larg: float = e["larg"]
	var dorso := e["dorso"] as Color
	var flanco := e["flanco"] as Color
	var ventre := e["ventre"] as Color
	var peso := func(z: float) -> float:
		return smoothstep(-0.2 * comp, 0.65 * comp, z)
	var cor := func(z: float, s: float) -> Color:
		var c := flanco.lerp(dorso, smoothstep(0.15, 0.55, s)).lerp(ventre, smoothstep(-0.2, -0.6, s))
		return _l(c, peso.call(z))
	m.fuso([[-0.5 * comp, alt * 0.22, larg * 0.25, 0.0], [-0.36 * comp, alt * 0.78, larg * 0.85, 0.0], [-0.1 * comp, alt, larg, 0.0],
		[0.2 * comp, alt * 0.66, larg * 0.62, 0.0], [0.42 * comp, alt * 0.2, larg * 0.22, 0.0]], 6, cor)
	var b := e["barbatana"] as Color
	var zc := 0.4 * comp
	var c0 := _l(b, peso.call(zc))
	var c1 := _l(b, 1.0)
	m.tri(Vector3(0, alt * 0.18, zc), Vector3(0, alt * 0.95, 0.64 * comp), Vector3(0, 0, 0.53 * comp), c0, c1, c1)
	m.tri(Vector3(0, -alt * 0.18, zc), Vector3(0, 0, 0.53 * comp), Vector3(0, -alt * 0.95, 0.64 * comp), c0, c1, c1)
	var cd := _l(dorso.lerp(b, 0.5), 0.3)
	m.tri(Vector3(0, alt * 0.9, -0.12 * comp), Vector3(0, alt * 1.45, 0.04 * comp), Vector3(0, alt * 0.72, 0.16 * comp), cd, cd, cd)
	return m.fechar()


const TRUTA := {"comp": 1.0, "alt": 0.11, "larg": 0.095, "dorso": Color(0.34, 0.36, 0.25), "flanco": Color(0.62, 0.58, 0.44),
	"ventre": Color(0.85, 0.8, 0.7), "barbatana": Color(0.3, 0.28, 0.2)}
const PERCA := {"comp": 1.0, "alt": 0.15, "larg": 0.095, "dorso": Color(0.3, 0.37, 0.2), "flanco": Color(0.6, 0.6, 0.3),
	"ventre": Color(0.86, 0.82, 0.62), "barbatana": Color(0.62, 0.3, 0.15)}
const SARDINHA := {"comp": 1.0, "alt": 0.1, "larg": 0.08, "dorso": Color(0.24, 0.36, 0.5), "flanco": Color(0.72, 0.76, 0.8),
	"ventre": Color(0.9, 0.92, 0.93), "barbatana": Color(0.4, 0.45, 0.5)}


# ---------------------------------------------------------------- bichos de terra, de longe

## Um bicho de quatro patas em formas simples (só para ver de longe). Chaves: comp, alto (altura do lombo), corpo
## (meia altura do corpo), larg, perna, pescoco, cabeca, cauda, e as cores pelo, ventre, pernas, cara. O pescoço e a
## cabeça têm peso (o modo 1 do bicho_lote os gira em volta da base do pescoço, que volta em `pivo`).
static func quadrupede(e: Dictionary) -> Array:
	var m := Malha.new()
	var comp: float = e["comp"]
	var alto: float = e["alto"]
	var c: float = e["corpo"]
	var larg: float = e["larg"]
	var yb := alto - c
	var pelo := _l(e["pelo"])
	var ventre := _l(e["ventre"])
	var pernas := _l(e["pernas"])
	var cara := e["cara"] as Color
	var cor := func(_z: float, s: float) -> Color:
		return ventre.lerp(pelo, smoothstep(-0.5, 0.1, s))
	m.fuso([[-0.5 * comp, c * 0.7, larg * 0.8, yb + 0.03], [-0.3 * comp, c, larg, yb], [0.22 * comp, c * 0.95, larg * 0.95, yb],
		[0.5 * comp, c * 0.6, larg * 0.7, yb + 0.02]], 6, cor)
	var pr: float = e["perna"]
	for px: float in [-1.0, 1.0]:
		for pz: float in [-0.36, 0.36]:
			var topo := Vector3(px * larg * 0.55, yb, pz * comp)
			m.tubo(topo, Vector3(topo.x, 0.0, topo.z + 0.02), pr, pr * 0.6, pelo, pernas, 4)
	# pescoço para cima e para a frente; a cabeça para a frente e um pouco para baixo
	var base := Vector3(0, yb + c * 0.3, -0.42 * comp)
	var ang: float = e.get("pescoco_ang", 0.9)
	var fim := base + Vector3(0, sin(ang), -cos(ang)) * float(e["pescoco"])
	m.tubo(base, fim, c * 0.55, c * 0.4, _l(e["pelo"], 0.3), _l(e["pelo"], 1.0), 5)
	var focinho := fim + Vector3(0, -0.35, -0.94).normalized() * float(e["cabeca"])
	m.tubo(fim + Vector3(0, 0, 0.04), focinho, c * 0.5, c * 0.22, _l(cara, 1.0), _l(cara.darkened(0.4), 1.0), 5)
	# orelhas
	for s: float in [-1.0, 1.0]:
		m.tubo(fim + Vector3(s * c * 0.25, c * 0.15, 0.02), fim + Vector3(s * c * 0.45, c * 0.75, 0.08), c * 0.12, 0.005, _l(cara, 1.0), _l(cara, 1.0), 3)
	var cauda: float = e["cauda"]
	var cr: float = e.get("cauda_raio", c * 0.18)
	var t0 := Vector3(0, yb + c * 0.4, 0.48 * comp)
	m.tubo(t0, t0 + Vector3(0, -0.55, 0.84).normalized() * cauda, cr, cr * 0.5, pelo, _l(e.get("cauda_ponta", e["pelo"])), 5)
	return [m.fechar(), base]


## A foca deitada: um fuso no chão, a cabeça na frente (com peso: o modo 1 a levanta para olhar) e as nadadeiras.
static func foca() -> Array:
	var m := Malha.new()
	var dorso := Color(0.4, 0.4, 0.42)
	var ventre := Color(0.62, 0.6, 0.56)
	var cor := func(z: float, s: float) -> Color:
		return _l(ventre.lerp(dorso, smoothstep(-0.5, 0.2, s)), smoothstep(-0.25, -0.65, z))
	m.fuso([[-0.8, 0.07, 0.07, 0.24], [-0.68, 0.13, 0.13, 0.25], [-0.5, 0.17, 0.18, 0.24], [-0.2, 0.25, 0.28, 0.25],
		[0.25, 0.22, 0.25, 0.22], [0.6, 0.1, 0.12, 0.13], [0.75, 0.04, 0.06, 0.1]], 7, cor)
	var nd := _l(dorso.darkened(0.25))
	for s: float in [-1.0, 1.0]:
		m.tri(Vector3(s * 0.2, 0.12, -0.2), Vector3(s * 0.42, 0.02, -0.05), Vector3(s * 0.22, 0.08, 0.02), nd, nd, nd)
		m.tri(Vector3(s * 0.04, 0.1, 0.72), Vector3(s * 0.26, 0.06, 0.95), Vector3(s * 0.05, 0.08, 0.95), nd, nd, nd)
	return [m.fechar(), Vector3(0, 0.25, -0.3)]


const CERVO := {"comp": 1.25, "alto": 1.05, "corpo": 0.24, "larg": 0.2, "perna": 0.06, "pescoco": 0.55, "pescoco_ang": 1.05,
	"cabeca": 0.32, "cauda": 0.14, "pelo": Color(0.5, 0.34, 0.19), "ventre": Color(0.8, 0.7, 0.56), "pernas": Color(0.36, 0.25, 0.15),
	"cara": Color(0.46, 0.31, 0.18), "cauda_ponta": Color(0.9, 0.88, 0.84)}
const LOBO := {"comp": 1.05, "alto": 0.74, "corpo": 0.2, "larg": 0.16, "perna": 0.05, "pescoco": 0.28, "pescoco_ang": 0.5,
	"cabeca": 0.3, "cauda": 0.42, "cauda_raio": 0.06, "pelo": Color(0.45, 0.44, 0.42), "ventre": Color(0.72, 0.7, 0.66),
	"pernas": Color(0.38, 0.37, 0.35), "cara": Color(0.5, 0.49, 0.46)}
const RAPOSA := {"comp": 0.62, "alto": 0.42, "corpo": 0.12, "larg": 0.1, "perna": 0.03, "pescoco": 0.17, "pescoco_ang": 0.6,
	"cabeca": 0.2, "cauda": 0.42, "cauda_raio": 0.07, "pelo": Color(0.74, 0.37, 0.13), "ventre": Color(0.93, 0.89, 0.8),
	"pernas": Color(0.2, 0.13, 0.1), "cara": Color(0.76, 0.39, 0.14), "cauda_ponta": Color(0.95, 0.93, 0.88)}


# ---------------------------------------------------------------- insetos

## A borboleta: corpo fino e escuro (sem peso) e duas asas de cada lado (peso 1, batem em volta do corpo). A cor da
## asa vem da tinta de cada uma (bicho_lote modo 2): aqui só o claro do meio e a borda escura.
static func borboleta() -> ArrayMesh:
	var m := Malha.new()
	var corpo := _l(Color(0.12, 0.1, 0.09))
	m.tubo(Vector3(0, 0.002, -0.022), Vector3(0, 0, 0.03), 0.005, 0.003, corpo, corpo, 4)
	var claro := _l(Color(1, 1, 1), 1.0)
	var meio := _l(Color(0.95, 0.95, 0.95), 1.0)
	var borda := _l(Color(0.4, 0.36, 0.32), 1.0)
	for s: float in [-1.0, 1.0]:
		var r0 := Vector3(s * 0.004, 0.003, -0.016)
		var r1 := Vector3(s * 0.004, 0.003, 0.006)
		m.quad(r0, Vector3(s * 0.05, 0.003, -0.034), Vector3(s * 0.056, 0.003, -0.006), r1, claro, borda, borda, meio)
		var h0 := Vector3(s * 0.004, 0.003, 0.002)
		var h1 := Vector3(s * 0.004, 0.003, 0.02)
		m.quad(h0, Vector3(s * 0.042, 0.003, 0.006), Vector3(s * 0.03, 0.003, 0.036), h1, claro, borda, borda, meio)
	return m.fechar()


## A libélula: corpo comprido (sem peso: ganha a tinta), olhos grandes e quatro asas estreitas, claras (peso 1).
static func libelula() -> ArrayMesh:
	var m := Malha.new()
	var corpo := _l(Color(0.95, 0.95, 0.95))
	var escuro := _l(Color(0.25, 0.25, 0.25))
	m.tubo(Vector3(0, 0, -0.012), Vector3(0, 0, 0.004), 0.006, 0.005, corpo, corpo, 4)
	m.tubo(Vector3(0, 0, 0.004), Vector3(0, -0.002, 0.068), 0.003, 0.0018, corpo, escuro, 4)
	m.tubo(Vector3(0, 0.001, -0.02), Vector3(0, 0.001, -0.011), 0.006, 0.007, escuro, escuro, 4)
	var asa := _l(Color(0.82, 0.88, 0.92), 1.0)
	for s: float in [-1.0, 1.0]:
		for z0: float in [-0.008, 0.002]:
			m.quad(Vector3(s * 0.003, 0.004, z0), Vector3(s * 0.052, 0.004, z0 - 0.002), Vector3(s * 0.052, 0.004, z0 + 0.007),
				Vector3(s * 0.003, 0.004, z0 + 0.008), asa, asa, asa, asa)
	return m.fechar()
