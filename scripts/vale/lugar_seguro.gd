class_name LugarSeguro
extends RefCounted
## Onde o drone colega deixa o robô depois da pane (pedido do usuário, 2026-11-21): não mais na base, e sim a
## uns 100 m de onde ele desligou, num chão seguro. "Seguro" é chão firme acima do mar e fora d'água, plano,
## sem tronco, pedra, bloco de paredão, ruína ou construção por perto, fora das cavernas, do poço do
## Sumidouro e do galpão da Fundição, e o mais longe possível das máquinas ligadas.
## Procura num anel em volta do ponto (de 70 a 130 m, preferindo os 100); sem nada lá, abre o anel. Devolve
## Vector3.INF quando não acha (quem chama usa a base).

const ALVO := 100.0  # metros do ponto da pane
const ANEIS := [[70.0, 130.0], [40.0, 200.0], [20.0, 320.0]]
const DIRECOES := 24
const RAIO := 2.2  # o corpo do robô com folga, para não nascer encostado em nada
const PLANO := 0.95  # o chão quase reto (normal)
const DEGRAU := 0.6  # metros de diferença no chão em volta do ponto
const SOSSEGO := 120.0  # longe assim de uma máquina ligada já é sossego (não pesa mais na escolha)


## O ponto (já no chão) mais seguro perto de `de`. `espaco` é o estado da física do mundo (para ver se há algo
## em cima do chão que a lista de obstáculos não conhece).
static func achar(mapa: Vale, de: Vector3, espaco: PhysicsDirectSpaceState3D, arvore: SceneTree) -> Vector3:
	if mapa == null:
		return Vector3.INF
	var maquinas: Array[Vector3] = []
	if arvore:
		for n in arvore.get_nodes_in_group("maquinas"):
			var mq := n as MaquinaPequena
			if mq and is_instance_valid(mq) and not mq.desligada and mq.is_inside_tree():
				maquinas.append(mq.global_position)
	for anel: Array in ANEIS:
		var melhor := Vector3.INF
		var nota_melhor := -INF
		var r := float(anel[0])
		while r <= float(anel[1]):
			for k in DIRECOES:
				var ang := TAU * (float(k) + (0.5 if int(r) % 20 == 0 else 0.0)) / DIRECOES
				var x := de.x + cos(ang) * r
				var z := de.z + sin(ang) * r
				if not serve(mapa, x, z, espaco):
					continue
				var p := Vector3(x, mapa.altura(x, z), z)
				var longe := SOSSEGO
				for q in maquinas:
					longe = minf(longe, Vector2(q.x - x, q.z - z).length())
				# longe das máquinas pesa mais; perto dos 100 m e chão mais reto desempatam
				var nota := longe - absf(r - ALVO) * 0.25 + (mapa.normal_em(x, z).y - PLANO) * 200.0
				if nota > nota_melhor:
					nota_melhor = nota
					melhor = p
			r += 15.0
		if melhor.is_finite():
			return melhor + Vector3(0, 0.4, 0)
	return Vector3.INF


## Dá para deixar o robô neste ponto?
static func serve(mapa: Vale, x: float, z: float, espaco: PhysicsDirectSpaceState3D = null) -> bool:
	var h := mapa.altura(x, z)
	if h < 1.5 or mapa.agua(x, z) != -INF:
		return false  # no mar, na areia molhada, no rio ou na lagoa
	if mapa.normal_em(x, z).y < PLANO:
		return false
	for k in 8:
		var a := TAU * k / 8.0
		if absf(mapa.altura(x + cos(a) * 3.0, z + sin(a) * 3.0) - h) > DEGRAU:
			return false
	if Cavernas.dentro(x, z, 8.0) or Sumidouro.dentro(x, z, 12.0) or Fundicao.dentro_do_galpao(Vector3(x, h, z)):
		return false
	if not (Ruinas.livre(x, z) and MarcosOeste.livre(x, z) and MarcosLeste.livre(x, z) and MarcosMar.livre(x, z)):
		return false
	if not Obstaculos.livre(mapa, x, z, RAIO):
		return false
	if espaco:
		# o que a lista não conhece (casa, caixote, tronco caído): um raio de cima tem de bater no próprio chão
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 40.0, z), Vector3(x, h - 1.0, z))
		var bate := espaco.intersect_ray(q)
		if not bate.is_empty() and (bate["position"] as Vector3).y > h + 0.5:
			return false
	return true
