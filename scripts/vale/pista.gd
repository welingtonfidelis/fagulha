class_name Pista
extends RefCounted
## A pista de pouso do Anel (ideia do usuário, 2026-11-19): o Anel era o arco de aproximação de uma pista.
## Ela começa um pouco à frente dele, do lado do mar, passa por dentro do aro e segue pela planície. Está
## gasta, quebrada e tomada pelo mato: lajes de concreto que faltam, outras partidas e desniveladas, o que
## sobrou da faixa do meio e das marcas da cabeceira, e postes baixos de balizamento na beira (alguns caídos).
## Os postes de pé acendem de noite depois que alguém atravessa o Anel (`LuzesNoite.ligadas["anel"]`).
## Não é estrada: é uma ruína no meio do capim.

const LARGURA := 16.0  # duas lajes de 8 m
const LAJE := 10.0  # comprimento de cada laje
const ANTES := 50.0  # metros do lado do mar, a partir do Anel
const DEPOIS := 150.0  # metros pela planície
const FALTA := 0.2  # parte das lajes que sumiu
const POSTE_PASSO := 20.0

static var meio := Vector2.INF  # o pé do Anel, no chão
static var rumo := Vector2.ZERO  # ao longo da pista, do mar para a planície
static var lajes := {}  # Vector2i(fila ao longo, lado) -> true onde há laje
static var postes := 0
static var pecas := 0


## 1 em cima de uma laje, 2 num vão da pista (laje que falta), 0 fora dela. O capim usa.
static func em(x: float, z: float) -> int:
	if not meio.is_finite():
		return 0
	var d := Vector2(x, z) - meio
	var s := d.dot(rumo)
	var w := d.dot(Vector2(-rumo.y, rumo.x))
	if s < -ANTES or s > DEPOIS or absf(w) > LARGURA * 0.5:
		return 0
	var chave := Vector2i(floori((s + ANTES) / LAJE), 0 if w < 0.0 else 1)
	return 1 if lajes.has(chave) else 2


static func montar(v: Vale, centro_anel: Vector3, eixo_anel: Vector3) -> void:
	lajes.clear()
	postes = 0
	meio = Vector2(centro_anel.x, centro_anel.z)
	var e := Vector2(eixo_anel.x, eixo_anel.z).normalized()
	# o lado do mar é o que desce: a pista começa ali e avança para a planície
	var soma := 0.0
	for d: float in [150.0, 300.0, 450.0]:
		soma += v._fora(meio.x + e.x * d, meio.y + e.y * d) - v._fora(meio.x - e.x * d, meio.y - e.y * d)
	rumo = e if soma > 0.0 else -e
	var de_lado := Vector2(-rumo.y, rumo.x)
	var o := Ruinas.Obra.new()
	o.v = v
	var blocos: Array[PackedVector3Array] = []
	for k in 5:
		blocos.append(Ruinas._cubo_talhado(811 + k * 5, 1 + k % 2))
	o.blocos = blocos
	o.t = Transform3D.IDENTITY
	o.rng.seed = 4242
	o.corpo = StaticBody3D.new()
	o.corpo.name = "PistaDoAnel"
	o.corpo.collision_layer = 1
	o.corpo.collision_mask = 0
	v.add_child(o.corpo)
	var giro_pista := Basis(Vector3.UP, atan2(rumo.x, rumo.y))  # o z da laje ao longo da pista
	var filas := int((ANTES + DEPOIS) / LAJE)
	for f in filas:
		var s := -ANTES + (f + 0.5) * LAJE
		for lado in 2:
			var w := (lado - 0.5) * LARGURA * 0.5
			var p := meio + rumo * s + de_lado * w
			# as pontas somem mais (o mato e o mar comeram), e nada de laje na água
			var beira := 1.0 + (0.9 if (f < 2 or f > filas - 3) else 0.0)
			if o.rng.randf() < FALTA * beira or v.agua(p.x, p.y) > -INF:
				continue
			lajes[Vector2i(f, lado)] = true
			var h := v._fora(p.x, p.y)
			var n := v.normal_em(p.x, p.y)
			var assenta := Basis(Quaternion(Vector3.UP, n)) * giro_pista
			if o.rng.randf() < 0.3:
				# partida ao meio: duas metades desniveladas, com uma fresta
				for meia: float in [-1.0, 1.0]:
					var pm := p + rumo * meia * LAJE * 0.26
					var torta := assenta * Basis.from_euler(Vector3(o.j(0.07), o.j(0.05), o.j(0.06)))
					o.bloco(Vector3(pm.x, v._fora(pm.x, pm.y) + 0.02 + o.j(0.06), pm.y), Vector3(LARGURA * 0.5 - 0.25, 0.42, LAJE * 0.47), torta, "concreto")
			else:
				var torta2 := assenta * Basis.from_euler(Vector3(o.j(0.025), o.j(0.02), o.j(0.025)))
				o.bloco(Vector3(p.x, h + 0.03, p.y), Vector3(LARGURA * 0.5 - 0.2, 0.42, LAJE - 0.25), torta2, "concreto")
				# o que sobrou da faixa do meio: um traço claro na beira de dentro, em parte das lajes
				if lado == 0 and f % 2 == 0 and o.rng.randf() < 0.7:
					var pf := meio + rumo * s
					o.bloco(Vector3(pf.x, v._fora(pf.x, pf.y) + 0.25, pf.y), Vector3(0.7, 0.05, LAJE * 0.5), assenta, "casco_claro", false)
	# as marcas da cabeceira, do lado do mar: o que restou de seis barras claras
	for k in 6:
		if o.rng.randf() < 0.35:
			continue
		var pc := meio + rumo * (-ANTES + LAJE * 1.6) + de_lado * ((k - 2.5) * 2.3)
		if em(pc.x, pc.y) == 1:
			o.bloco(Vector3(pc.x, v._fora(pc.x, pc.y) + 0.25, pc.y), Vector3(1.2, 0.05, 7.0), giro_pista, "casco_claro", false)
	# os postes de balizamento na beira: baixos, de ferro; uns de pé (acendem de noite), outros caídos
	var s2 := -ANTES + 5.0
	while s2 < DEPOIS:
		for lado: float in [-1.0, 1.0]:
			var pp := meio + rumo * s2 + de_lado * lado * (LARGURA * 0.5 + 1.6)
			if v.agua(pp.x, pp.y) > -INF:
				continue
			var hp := v._fora(pp.x, pp.y)
			var sorte := o.rng.randf()
			if sorte < 0.25:
				continue  # sumiu
			if sorte < 0.45:
				o.bloco(Vector3(pp.x, hp + 0.12, pp.y), Vector3(0.16, 1.0, 0.16), Basis.from_euler(Vector3(PI * 0.5 + o.j(0.1), o.rng.randf() * TAU, 0)), "ferrugem", false)
				continue
			o.bloco(Vector3(pp.x, hp + 0.5, pp.y), Vector3(0.16, 1.0, 0.16), Basis.from_euler(Vector3(o.j(0.06), 0, o.j(0.06))), "ferrugem", false)
			o.bloco(Vector3(pp.x, hp + 1.06, pp.y), Vector3(0.3, 0.14, 0.3), Basis.IDENTITY, "casco", false)
			var luz := LuzesNoite.por(v, Vector3(pp.x, hp + 1.25, pp.y), LuzesNoite.CIANO, 2.2)
			luz.set_meta("so_com", "anel")
			postes += 1
		s2 += POSTE_PASSO
	pecas = o.pecas
	o.fechar()
	print("pista do Anel: %d lajes de %d, %d postes de pé, rumo %s" % [lajes.size(), filas * 2, postes, rumo])
