class_name Obstaculos
extends RefCounted
## O que barra quem anda sem física (mechas e bichos): troncos, pedras, blocos dos paredões, ruínas e a
## base. Eles andam pela altura do terreno e atravessavam tudo isso. Cada obstáculo vira um ou mais círculos
## no chão, guardados numa grade; os troncos saem da grade de árvores do mapa. Só conta o que fica de pé na
## altura do corpo: laje baixa (dá para pisar) e viga no alto (dá para passar por baixo) ficam de fora.
## Quem cria colisão registra aqui; `Vale.gerar` limpa no começo.

const CELULA := 8.0
const BAIXO := 0.5  # até esta altura acima do chão não é obstáculo
const ALTO := 3.2  # a partir desta altura acima do chão também não

static var _grade := {}  # Vector2i -> PackedVector3Array de (x, z, raio)
static var quantos := 0


static func limpar() -> void:
	_grade.clear()
	quantos = 0


static func registrar(x: float, z: float, raio: float) -> void:
	var cel := Vector2i(floori(x / CELULA), floori(z / CELULA))
	var l: PackedVector3Array = _grade.get(cel, PackedVector3Array())
	l.append(Vector3(x, z, raio))
	_grade[cel] = l
	quantos += 1


## Uma forma de colisão já no lugar (`xf` no mundo): caixa, cilindro ou casco. `chao` é a altura do terreno ali.
static func registrar_forma(f: Shape3D, xf: Transform3D, chao: float) -> void:
	var meio := Vector3.ZERO  # metades da caixa que envolve a forma, nos eixos dela
	if f is BoxShape3D:
		meio = (f as BoxShape3D).size * 0.5
	elif f is CylinderShape3D:
		meio = Vector3((f as CylinderShape3D).radius, (f as CylinderShape3D).height * 0.5, (f as CylinderShape3D).radius)
	elif f is ConvexPolygonShape3D:
		for p in (f as ConvexPolygonShape3D).points:
			meio = meio.max(p.abs())
	else:
		return
	var ex := xf.basis.x * meio.x
	var ey := xf.basis.y * meio.y
	var ez := xf.basis.z * meio.z
	var sobe := absf(ex.y) + absf(ey.y) + absf(ez.y)
	if xf.origin.y + sobe < chao + BAIXO or xf.origin.y - sobe > chao + ALTO:
		return
	# no chão: uma fila de círculos ao longo do eixo mais comprido
	var eixos: Array[Vector2] = [Vector2(ex.x, ex.z), Vector2(ey.x, ey.z), Vector2(ez.x, ez.z)]
	eixos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length() > b.length())
	var longo := eixos[0]
	var raio := clampf(eixos[1].length(), 0.3, 3.0)
	var comp := longo.length()
	if comp <= raio * 1.2:
		registrar(xf.origin.x, xf.origin.z, maxf(raio, comp))
		return
	var n := maxi(1, ceili((comp - raio) / maxf(raio, 0.4)))
	for k in range(-n, n + 1):
		var p := Vector2(xf.origin.x, xf.origin.z) + longo.normalized() * (comp - raio) * float(k) / n
		registrar(p.x, p.y, raio)


## Dá para ficar neste ponto, com um corpo de raio `raio`?
static func livre(mapa: Ilha, x: float, z: float, raio: float) -> bool:
	var cel := Vector2i(floori(x / CELULA), floori(z / CELULA))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var l: PackedVector3Array = _grade.get(cel + Vector2i(dx, dz), PackedVector3Array())
			for o in l:
				var soma := o.z + raio
				if (o.x - x) * (o.x - x) + (o.y - z) * (o.y - z) < soma * soma:
					return false
	if mapa == null:
		return true
	var ca := Vector2i(floori(x / Ilha.CELULA_ARVORE), floori(z / Ilha.CELULA_ARVORE))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := ca + Vector2i(dx, dz)
			if not mapa._grade_arv.has(c):
				continue
			for i: int in mapa._grade_arv[c]:
				var p := mapa.arv_pos[i]
				var ex := p.x - x
				var ez := p.z - z
				if (absf(ex) > 2.5 or absf(ez) > 2.5) and mapa.arv_escala[i] < 2.5:
					continue  # árvore comum: tronco fino, nem faz a conta (a Árvore-Mãe passa)
				var soma: float = float(mapa._medidas_colisao(i)[0]) + raio
				if ex * ex + ez * ez < soma * soma:
					return false
	return true


## Dá para andar de `de` até `ate`? Quem já está dentro de um obstáculo (nasceu ali) pode sair.
static func caminho_livre(mapa: Ilha, de: Vector3, ate: Vector3, raio: float) -> bool:
	if not livre(mapa, de.x, de.z, raio * 0.6):
		return true
	var d := Vector2(ate.x - de.x, ate.z - de.z).length()
	var n := maxi(1, ceili(d / maxf(raio, 0.35)))
	for k in range(1, n + 1):
		var p := de.lerp(ate, float(k) / n)
		if not livre(mapa, p.x, p.z, raio):
			return false
	return true


## Um rumo (plano) por onde dá para andar `alcance` metros: o próprio `rumo`, ou girado de 30 em 30 graus,
## primeiro todo o lado `lado` (+1 ou -1) e só depois o outro. Quem chama guarda o lado em que acabou indo
## e passa de novo: assim contorna o obstáculo por um lado só, sem ficar indo e voltando, e larga a volta
## assim que o rumo direto abre. Vector3.ZERO se está cercado. `serve` (opcional) é a regra de quem anda
## para o ponto de chegada (água, barranco).
static func rumo_livre(mapa: Ilha, de: Vector3, rumo: Vector3, alcance: float, raio: float, lado: float, serve := Callable()) -> Vector3:
	for k in 11:
		var ang := 0.0 if k == 0 else (k * 0.5236 * lado if k <= 5 else (k - 5) * 0.5236 * -lado)
		var d := rumo.rotated(Vector3.UP, ang)
		var ate := de + d * alcance
		if serve.is_valid() and not serve.call(ate.x, ate.z):
			continue
		if caminho_livre(mapa, de, ate, raio):
			return d
	return Vector3.ZERO
