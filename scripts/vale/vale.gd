class_name Vale
extends Clareira
## O vale maior (2026-11-15): 2 km × 2 km em volta da clareira, que fica no meio sem mudar.
## O relevo e a cobertura de fora vêm da maquete aprovada (tools/vale/mapa_vale.py → assets/vale/mapa/),
## um ponto a cada 4 m. Na borda da clareira (de 108 a 156 m do centro) o chão dela se mistura ao de fora,
## e na linha dos 160 m os dois são iguais, sem degrau.
## Primeira etapa: só a base (chão, mar e mata de longe). Cada canto ganha capricho depois.

const F_N := 751
const F_PASSO := 4.0
const F_META := 1500.0
const MAR := 0.0
const DADOS := "res://assets/vale/mapa/"
const BORDA_DE := 108.0
const BORDA_ATE := 156.0
const AGUA_DENTRO := 110.0  # a água doce da clareira só vale até aqui (a lâmina dela vai até aí)

# O rio que sai da lagoa e vai até o mar, ao sul (x, z). Dentro da clareira a água é a lâmina dela (NIVEL);
# da borda em diante o nível desce até o mar, numa fita própria.
const RIO: Array[Vector2] = [Vector2(34, -2), Vector2(52, 30), Vector2(74, 66), Vector2(104, 104), Vector2(132, 150), Vector2(170, 215),
	Vector2(232, 320), Vector2(282, 430), Vector2(316, 560), Vector2(332, 700), Vector2(344, 820), Vector2(352, 1000)]
const RIO_LEITO := 4.5  # metade da largura do leito chato
const RIO_FAIXA := 11.0  # metade da largura da fita d'água (as margens escondem a sobra)
const RIO_FUNDO := 1.3  # na beira do leito
const RIO_FUNDO_MEIO := 3.0  # no meio (era 1,3 em todo o leito: raso demais; pedido do usuário, 2026-11-22)

# O riacho que vem do norte: nasce na serra, cai na cachoeira (o fim do trecho de cima) dentro do poço
# e desce pela mata fechada até o começo do riacho da clareira.
const NASCENTE := Vector2(-306, -530)  # o alto da cachoeira, onde a água brota (um pouco atrás da beira do paredão)
const RIO_BAIXO: Array[Vector2] = [Vector2(-290, -485), Vector2(-276, -430), Vector2(-260, -380), Vector2(-222, -295), Vector2(-180, -200),
	Vector2(-140, -136), Vector2(-108, -88), Vector2(-96, -70)]
const POCO := Vector3(-290, -485, 17)  # x, z, raio
const POCO_NIVEL := 108.0
const POCO_FUNDO := 10.0  # metros a mais de fundura no meio do poço
# A represa das Encostas do Dique (ilha de 3 km): a lagoa que ela segura e o córrego que sai do pé dela
# até o mar do leste. O relevo (bacia, garganta e vale do córrego) vem pronto de tools/vale/mapa_3km.py.
const REPRESA_LAGOA := Vector3(1010, -335, 84)  # x, z, raio do espelho (na garganta a água segue até a parede: MarcosLeste)
const REPRESA_NIVEL := 26.0
const REPRESA_X := 1102.0  # o eixo da represa, que fecha a garganta
const RIO_REPRESA: Array[Vector2] = [Vector2(1107, -333), Vector2(1150, -318), Vector2(1200, -338), Vector2(1250, -300), Vector2(1300, -285)]

var _cursos: Array = []  # de Curso: [0] sul, [1] norte (do poço até a clareira)
var _rio_s_borda := 0.0  # onde o rio do sul sai da lâmina da clareira
var _rio_s_foz := 0.0  # onde chega ao mar
var cume := Vector3.ZERO  # o ponto mais alto do vale (Serra do Mirante)
var queda_topo := Vector3.ZERO
var quedas: Array[Vector3] = []  # o meio de cada cachoeira (para o som)
var cortinas: Array = []  # [topo, pé, raio] de cada queda d'água: atravessá-la zera o calor do robô


func na_cachoeira(p: Vector3) -> bool:
	for c: Array in cortinas:
		var a: Vector3 = c[0]
		var ab: Vector3 = (c[1] as Vector3) - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(a + ab * t) < float(c[2]):
			return true
	return false

var _fora_h := PackedFloat32Array()
var _cob := PackedByteArray()
var arvores_fora := 0
## A terra nova do noroeste, com a Montanha do Degelo (doc §137). Fora do quadrado de hoje, a altura, a água
## e a cobertura vêm dela.
var terra_nova: TerraNova = null

# distância até a terra, numa grade de 16 m (para o limite do mar)
## Até onde o vulto das árvores de fora é desenhado. Eram 1.300 m na ilha de 2 km; na de 3 km, do alto da
## serra a mata do outro lado sumia e a terra parecia pelada.
const VULTO_ATE := 2300.0
const C_PASSO := 16.0
const C_N2 := 189
# a grade da costa cobre a ilha de hoje e, quando há, a terra nova (canto de cima à esquerda e tamanho)
var _c0 := Vector2(-F_META, -F_META)
var _cn := Vector2i(C_N2, C_N2)
var _costa_dist := PackedFloat32Array()
var _costa_terra := PackedInt32Array()  # índice da célula de terra mais perto


func gerar(_semente := 7) -> void:
	var t0 := Time.get_ticks_msec()
	Obstaculos.limpar()
	Tempos.marca("Obstaculos.limpar")
	_carregar()
	terra_nova = TerraNova.new()
	if not terra_nova.carregar():
		terra_nova.free()
		terra_nova = null
	Tempos.marca("_carregar")
	_preparar_rio()
	Tempos.marca("_preparar_rio")
	Cavernas.cavar(self)
	Tempos.marca("Cavernas.cavar")
	Sumidouro.cavar(self)
	Tempos.marca("Sumidouro.cavar")
	Fundicao.cavar(self)
	Tempos.marca("Fundicao.cavar")
	MarcosOeste.cavar(self)
	Tempos.marca("MarcosOeste.cavar")
	await _avisar(0.12, "Abrindo a clareira")
	await super.gerar(_semente)
	await _avisar(0.34, "Estendendo o chão e o mar")
	Tempos.marca("super.gerar")
	_malha_fora()
	Tempos.marca("_malha_fora")
	_colisao_fora()
	Tempos.marca("_colisao_fora")
	if terra_nova:
		add_child(terra_nova)
		terra_nova.montar(self)
		Tempos.marca("TerraNova.montar")
	_falesia_da_borda()
	Tempos.marca("_falesia_da_borda")
	_mar()
	Tempos.marca("_mar")
	_fita_rio()
	Tempos.marca("_fita_rio")
	_preparar_costa()
	Tempos.marca("_preparar_costa")
	_cume()
	Tempos.marca("_cume")
	await _avisar(0.46, "Plantando a mata")
	# a mata e os paredões de fora são sorteados no relevo de antes do ombro da Fundição (doc §162): o resto da
	# ilha fica com as mesmas árvores e pedras, e no ombro quem planta é ela
	Fundicao.relevo_antigo(self, true)
	_mata_fora()
	Fundicao.relevo_antigo(self, false)
	Tempos.marca("_mata_fora")
	if terra_nova:
		terra_nova.plantar(self)
		Tempos.marca("TerraNova.plantar")
	await _avisar(0.54, "Espalhando flores e pedras")
	Fundicao.relevo_antigo(self, true)
	_plantas_do_chao()
	Fundicao.relevo_antigo(self, false)
	Tempos.marca("_plantas_do_chao")
	await _avisar(0.60, "Erguendo os paredões")
	Fundicao.relevo_antigo(self, true)
	Paredoes.montar(self)
	Fundicao.relevo_antigo(self, false)
	Tempos.marca("Paredoes.montar")
	if "--assar-rochas" in OS.get_cmdline_user_args():
		Sumidouro.assar()
		BocaDegelo.assar()
	await _avisar(0.76, "Acordando as ruínas")
	Sumidouro.montar(self)
	Tempos.marca("Sumidouro.montar")
	BocaDegelo.montar(self)
	Tempos.marca("BocaDegelo.montar")
	Ruinas.montar(self)
	Tempos.marca("Ruinas.montar")
	Marcos.montar(self)
	Tempos.marca("Marcos.montar")
	if terra_nova:
		terra_nova.lugares_com_nome()
	await _avisar(0.86, "Acendendo as forjas")
	Fundicao.montar(self)
	Tempos.marca("Fundicao.montar")
	MapaCaderno.preparar_terra(self)  # o relevo do mapa do caderno (do Cache depois da primeira vez)
	Tempos.marca("MapaCaderno.preparar_terra")
	print("vale gerado em %d ms, %d árvores fora da clareira" % [Time.get_ticks_msec() - t0, arvores_fora])


func _carregar() -> void:
	_fora_h = FileAccess.get_file_as_bytes(DADOS + "alturas.bin").to_float32_array()
	_cob = FileAccess.get_file_as_bytes(DADOS + "cobertura.bin")
	if _fora_h.size() != F_N * F_N or _cob.size() != F_N * F_N:
		push_error("vale: dados do mapa ausentes ou do tamanho errado em %s" % DADOS)
		_fora_h.resize(F_N * F_N)
		_fora_h.fill(22.0)
		_cob.resize(F_N * F_N)


## A costa da ilha vem pronta no arquivo de alturas (tools/vale/mapa_3km.py): mar em toda a volta.

## Altura do terreno de fora (a grade de 4 m), em qualquer ponto.
func _fora(x: float, z: float) -> float:
	var fx := clampf((x + F_META) / F_PASSO, 0.0, F_N - 1.001)
	var fz := clampf((z + F_META) / F_PASSO, 0.0, F_N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var i := iz * F_N + ix
	return lerpf(lerpf(_fora_h[i], _fora_h[i + 1], fx - ix), lerpf(_fora_h[i + F_N], _fora_h[i + F_N + 1], fx - ix), fz - iz)


func cobertura(x: float, z: float) -> int:
	if maxf(absf(x), absf(z)) > F_META:
		return terra_nova.cobertura(x, z) if _na_terra_nova(x, z) else 0
	var ix := clampi(roundi((x + F_META) / F_PASSO), 0, F_N - 1)
	var iz := clampi(roundi((z + F_META) / F_PASSO), 0, F_N - 1)
	return _cob[iz * F_N + ix]


func _dentro(x: float, z: float) -> bool:
	return maxf(absf(x), absf(z)) <= C_META


func clima(p: Vector3) -> Vector3:
	return terra_nova.clima(p) if _na_terra_nova(p.x, p.z) else Vector3.ZERO


func fonte_em(x: float, z: float) -> float:
	return terra_nova.fonte_em(x, z) if _na_terra_nova(x, z) else 0.0


## Fora do quadrado da ilha de hoje e dentro da grade da terra nova.
func _na_terra_nova(x: float, z: float) -> bool:
	return terra_nova != null and maxf(absf(x), absf(z)) > F_META and terra_nova.cobre(x, z)


## O relevo de fora em qualquer lugar: a grade de hoje, a da terra nova, ou o fundo do mar além das duas.
func _alt_fora(x: float, z: float) -> float:
	if maxf(absf(x), absf(z)) <= F_META or terra_nova == null:
		return _fora(x, z)
	return terra_nova.altura(x, z) if terra_nova.cobre(x, z) else TerraNova.FUNDO


## O chão da clareira, misturado ao de fora perto da borda, e com o leito do rio que sai da lagoa.
func _alt(x: float, z: float) -> float:
	var t := smoothstep(BORDA_DE, BORDA_ATE, maxf(absf(x), absf(z)))
	var h := super._alt(x, z)
	if t > 0.0:
		h = lerpf(h, _fora(x, z), t)
	return _cavar_rio(x, z, h) if t < 1.0 else h


# ---------------------------------------------------------------- os cursos d'água

## Um trecho de rio: uma linha no chão com o nível da água em cada ponto. O chão ganha o leito e um vale
## de encostas suaves em volta; a água é uma fita que acompanha o nível.
class Curso:
	var pts := PackedVector2Array()
	var s := PackedFloat32Array()  # comprimento acumulado
	var niv := PackedFloat32Array()  # nível da água em cada ponto
	var fita_de := 0.0  # trecho que ganha fita d'água (fora dele a água é de outra lâmina)
	var fita_ate := 0.0
	var cava_ate := INF  # dali em diante o chão não ganha leito (o mar)
	var mn := Vector2.ZERO
	var mx := Vector2.ZERO
	const SALTO := 5

	func fechar() -> void:
		s.resize(pts.size())
		s[0] = 0.0
		mn = pts[0]
		mx = pts[0]
		for i in range(1, pts.size()):
			s[i] = s[i - 1] + pts[i].distance_to(pts[i - 1])
			mn = mn.min(pts[i])
			mx = mx.max(pts[i])

	func total() -> float:
		return s[s.size() - 1]

	## Vector2(distância até a linha, comprimento andado até o ponto mais perto); INF se longe (mais de `raio`).
	func perto(x: float, z: float, raio: float) -> Vector2:
		if x < mn.x - raio or x > mx.x + raio or z < mn.y - raio or z > mx.y + raio:
			return Vector2(INF, 0.0)
		var p := Vector2(x, z)
		# passada larga primeiro (a linha tem um ponto a cada poucos metros), depois só a vizinhança do melhor
		var perto_i := 0
		var perto_d := INF
		var i0 := 0
		while i0 < pts.size():
			var dd := p.distance_squared_to(pts[i0])
			if dd < perto_d:
				perto_d = dd
				perto_i = i0
			i0 += SALTO
		if sqrt(perto_d) > raio + 60.0:
			return Vector2(INF, 0.0)
		var melhor := Vector2(INF, 0.0)
		for i in range(maxi(0, perto_i - SALTO - 1), mini(pts.size() - 1, perto_i + SALTO + 1)):
			var a := pts[i]
			var ab := pts[i + 1] - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d < melhor.x:
				melhor = Vector2(d, s[i] + ab.length() * t)
		return melhor

	func _trecho(sv: float) -> int:
		for i in pts.size() - 1:
			if sv <= s[i + 1]:
				return i
		return pts.size() - 2

	func ponto(sv: float) -> Vector2:
		var i := _trecho(sv)
		return pts[i].lerp(pts[i + 1], clampf((sv - s[i]) / maxf(0.001, s[i + 1] - s[i]), 0.0, 1.0))

	func nivel(sv: float) -> float:
		var i := _trecho(sv)
		return lerpf(niv[i], niv[i + 1], clampf((sv - s[i]) / maxf(0.001, s[i + 1] - s[i]), 0.0, 1.0))


## Refaz uma linha como um rio de verdade: passa pelos pontos em curva suave (sem quinas) e serpenteia
## para os lados. `amp` é quanto sai para o lado, `onda` o comprimento de cada volta; nas pontas
## (`firme_ini`, `firme_fim` metros) fica presa ao traçado, para encaixar no que já existe.
func _linha_curva(linha: Array[Vector2], passo: float, amp: float, onda: float, fase: float, firme_ini: float, firme_fim: float) -> PackedVector2Array:
	var base := PackedVector2Array()
	var n := linha.size()
	for i in n - 1:
		var p0 := linha[maxi(i - 1, 0)]
		var p1 := linha[i]
		var p2 := linha[i + 1]
		var p3 := linha[mini(i + 2, n - 1)]
		var k := maxi(2, roundi(p1.distance_to(p2) / 4.0))
		for j in k:
			var t := float(j) / k
			base.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	base.append(linha[n - 1])
	var comp := PackedFloat32Array()
	comp.resize(base.size())
	comp[0] = 0.0
	for i in range(1, base.size()):
		comp[i] = comp[i - 1] + base[i].distance_to(base[i - 1])
	var total := comp[comp.size() - 1]
	var torta := PackedVector2Array()
	for i in base.size():
		var a := base[maxi(i - 3, 0)]
		var b := base[mini(i + 3, base.size() - 1)]
		var lado := (b - a).normalized().orthogonal()
		var sv := comp[i]
		var solta := smoothstep(0.0, firme_ini, sv) * smoothstep(0.0, firme_fim, total - sv)
		# três voltas de tamanhos que não casam: nenhuma curva repete a anterior
		var sai := sin(TAU * sv / onda + fase) * 0.58 + sin(TAU * sv / (onda * 0.47) + fase * 2.3 + 1.1) * 0.30 + sin(TAU * sv / (onda * 2.3) + fase * 0.6) * 0.42
		torta.append(base[i] + lado * sai * amp * solta)
	# pontos a cada `passo` metros
	var saida := PackedVector2Array([torta[0]])
	var resto := passo
	for i in range(1, torta.size()):
		var a := torta[i - 1]
		var d := a.distance_to(torta[i])
		while d >= resto and d > 0.0:
			a = a.move_toward(torta[i], resto)
			saida.append(a)
			d = a.distance_to(torta[i])
			resto = passo
		resto -= d
	if saida[saida.size() - 1].distance_to(torta[torta.size() - 1]) > 1.0:
		saida.append(torta[torta.size() - 1])
	return saida


func _preparar_rio() -> void:
	_cursos.clear()
	# 1. sul: da lagoa ao mar. Na clareira vale a lâmina dela (NIVEL); da borda em diante desce até o mar.
	var sul := Curso.new()
	sul.pts = _linha_curva(RIO, 8.0, 46.0, 280.0, 0.9, 260.0, 60.0)
	sul.fechar()
	var borda := 0.0
	var foz := sul.total()
	var achou := false
	for i in sul.pts.size():
		var q := sul.pts[i]
		if not achou and maxf(absf(q.x), absf(q.y)) >= AGUA_DENTRO - 2.0:
			borda = sul.s[i]
			achou = true
		if achou and _fora(q.x, q.y) < MAR + 0.3:
			foz = sul.s[i]
			break
	sul.niv.resize(sul.pts.size())
	for i in sul.pts.size():
		sul.niv[i] = NIVEL if sul.s[i] <= borda else lerpf(NIVEL, MAR + 0.05, clampf((sul.s[i] - borda) / (foz - borda), 0.0, 1.0))
	sul.fita_de = borda
	sul.fita_ate = minf(foz + 24.0, sul.total())
	sul.cava_ate = foz
	_rio_s_borda = borda
	_rio_s_foz = foz
	_cursos.append(sul)
	# 2. norte de baixo: do poço da cachoeira até o riacho da clareira. O nível acompanha o chão, sempre descendo.
	var baixo := Curso.new()
	baixo.pts = _linha_curva(RIO_BAIXO, 8.0, 16.0, 150.0, 2.2, 70.0, 80.0)
	baixo.fechar()
	baixo.niv.resize(baixo.pts.size())
	var n := POCO_NIVEL
	var fim_fita := baixo.total()
	var achou2 := false
	for i in baixo.pts.size():
		var q := baixo.pts[i]
		var resta := baixo.total() - baixo.s[i]
		n = minf(n - 0.02, _fora(q.x, q.y) - 0.9) if i > 0 else POCO_NIVEL
		# nos últimos 90 m o nível chega ao da clareira
		n = maxf(n, NIVEL)
		if resta < 90.0:
			n = minf(n, lerpf(NIVEL, n, resta / 90.0))
		baixo.niv[i] = n
		if not achou2 and maxf(absf(q.x), absf(q.y)) <= AGUA_DENTRO - 2.0:
			fim_fita = baixo.s[i]
			achou2 = true
	baixo.fita_de = 0.0
	baixo.fita_ate = fim_fita
	_cursos.append(baixo)
	# o córrego da represa: nasce ao pé dela e desce até o mar do leste; o nível acompanha o chão
	var dique := Curso.new()
	dique.pts = _linha_curva(RIO_REPRESA, 6.0, 5.0, 90.0, 0.7, 30.0, 30.0)
	dique.fechar()
	dique.niv.resize(dique.pts.size())
	var nd := _fora(dique.pts[0].x, dique.pts[0].y) - 0.5
	var foz_d := dique.total()
	var achou3 := false
	for i in dique.pts.size():
		var q := dique.pts[i]
		nd = maxf(MAR + 0.05, minf(nd - 0.01, _fora(q.x, q.y) - 0.6)) if i > 0 else nd
		dique.niv[i] = nd
		if not achou3 and _fora(q.x, q.y) < MAR + 0.3:
			foz_d = dique.s[i]
			achou3 = true
	dique.fita_de = 0.0
	dique.fita_ate = minf(foz_d + 14.0, dique.total())
	dique.cava_ate = foz_d
	_cursos.append(dique)
	# 3. a nascente: a água brota no alto do paredão e já cai (um rio descendo a serra íngreme ficava
	# parecendo uma rampa; a queda saindo da pedra é mais simples e mais bonita)
	queda_topo = Vector3(NASCENTE.x, _fora(NASCENTE.x, NASCENTE.y) - 0.6, NASCENTE.y)
	# o relevo de fora ganha os leitos e o poço (a clareira ganha os dela em _alt)
	for gz in F_N:
		for gx in F_N:
			var x := -F_META + gx * F_PASSO
			var z := -F_META + gz * F_PASSO
			var i := gz * F_N + gx
			_fora_h[i] = _cavar_rio(x, z, _fora_h[i])


## Pontos ao longo dos rios, um a cada `passo` metros, na altura da água (para o som).
func pontos_do_rio(passo: float) -> Array[Vector3]:
	var lista: Array[Vector3] = []
	for c: Curso in _cursos:
		var sv := c.fita_de + passo * 0.5
		while sv < minf(c.fita_ate, c.total()):
			var p := c.ponto(sv)
			# sem água bem no eixo (agua devolve -INF), o som fica no chão: uma posição infinita num tocador
			# 3D estraga a mistura inteira e o jogo fica mudo
			var y := agua(p.x, p.y)
			lista.append(Vector3(p.x, y if is_finite(y) else altura(p.x, p.y), p.y))
			sv += passo
	return lista


## Compatível com os testes: ponto do rio do sul no comprimento s.
func _rio_ponto(sv: float) -> Vector2:
	return (_cursos[0] as Curso).ponto(sv)


## O chão com o leito dos rios: fundo chato, e a margem sobe da água em rampa suave até achar o terreno.
func _cavar_rio(x: float, z: float, h: float) -> float:
	for c: Curso in _cursos:
		var r := c.perto(x, z, 190.0)
		if r.x > 190.0:
			continue
		# atrás do começo da linha o vale não se abre (senão ele aplainava o paredão da cachoeira). Depois do
		# fim ele se abre em volta da ponta, em encosta: parando de uma vez, o morro da clareira ficava cortado
		# num muro reto de 10 m atravessado no riacho (visto pelo usuário em 2026-11-17)
		if r.y < 0.5 and r.x > RIO_LEITO:
			continue
		var n := c.nivel(r.y)
		var leito := minf(h, n - lerpf(RIO_FUNDO_MEIO, RIO_FUNDO, smoothstep(0.0, RIO_LEITO, r.x)))
		var rampa := n + 0.55 + maxf(0.0, r.x - 10.0) * 0.25
		var margem := minf(maxf(h, n + 0.55), maxf(rampa, n + 0.55))
		if h < n + 0.55:
			margem = n + 0.55 + (h - n - 0.55) * smoothstep(12.0, 40.0, r.x)  # terreno baixo: dique que some aos poucos
		var novo := lerpf(leito, margem, smoothstep(RIO_LEITO, 10.0, r.x))
		# depois do fim da linha a água segue por outra lâmina (o rio do norte entra no riacho da clareira): ali
		# o chão só baixa. A margem de "terreno baixo" levantava o leito do riacho num dique 0,5 m acima da água,
		# e a água não passava de (-88, -65) a (-75, -57) (visto pelo usuário em 2026-11-23)
		if r.y >= c.total() - 0.01:
			novo = minf(novo, h)
		# na foz o leito se desfaz no fundo do mar (senão as margens seguiam mar adentro como dois diques)
		h = lerpf(novo, h, smoothstep(c.cava_ate - 40.0, c.cava_ate + 6.0, r.y))
	# a bacia da nascente, no alto do paredão
	var dn := Vector2(x, z).distance_to(NASCENTE)
	if dn < 9.0 and queda_topo.y > 0.0:
		h = minf(h, lerpf(queda_topo.y - 0.9, h, smoothstep(3.0, 8.0, dn)))
	# o poço da cachoeira
	var dp := Vector2(x, z) - Vector2(POCO.x, POCO.y)
	var d := dp.length()
	if d < 60.0:
		# o contorno não é um círculo de compasso: a parede avança e recua em volta (e chega mais perto
		# da beira justamente onde a água cai, para a queda sair da pedra)
		var da := angle_difference(atan2(NASCENTE.y - POCO.y, NASCENTE.x - POCO.x), dp.angle())
		var w := cos(da * 3.0) * 0.45 + cos(da * 5.0) * 0.3 + cos(da * 8.0 + 0.6) * 0.25
		var w2 := sin(da * 2.0 + 0.8) * 0.5 + sin(da * 7.0 + 2.0) * 0.3 + sin(da * 11.0) * 0.2
		var dparede := d - w * 4.5
		# um anfiteatro: chão chato em volta do poço e paredão em volta, por onde a água cai
		if dparede < 46.0:
			h = minf(h, lerpf(POCO_NIVEL + 0.5, h, smoothstep(31.0, 38.5 + w2 * 3.0, dparede)))
		var dpoco := d - w2 * 2.6
		if dpoco < POCO.z * 1.6:
			# fundo de 12 m no meio (dá para mergulhar e nadar), subindo em bacia até a beira rasa
			var fundo_poco := POCO_NIVEL - 2.4 - POCO_FUNDO * (1.0 - smoothstep(0.0, POCO.z * 0.8, dpoco))
			h = minf(h, lerpf(fundo_poco, maxf(h, POCO_NIVEL + 0.4), smoothstep(POCO.z * 0.55, POCO.z * 1.1, dpoco)))
	return h


func _mat_rio(semente: int, veloc: float) -> ShaderMaterial:
	var ruido_agua := NoiseTexture2D.new()
	ruido_agua.width = 256
	ruido_agua.height = 256
	ruido_agua.seamless = true
	ruido_agua.noise = _ruido(semente, 1.0 / 11.0, 3)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/rio.gdshader")
	mat.set_shader_parameter("ruido", ruido_agua)
	mat.set_shader_parameter("raso", Color(0.20, 0.45, 0.42))
	mat.set_shader_parameter("fundo", Color(0.04, 0.16, 0.20))
	mat.set_shader_parameter("fluxo", Vector2(0.35, 0.9))
	mat.set_shader_parameter("velocidade", veloc)
	return mat


## As fitas d'água dos cursos, o espelho do poço e a cachoeira.
func _fita_rio() -> void:
	var mat := _mat_rio(63, 0.5)
	# a correnteza segue cada curso, rio abaixo (o UV da fita cresce com o comprimento, e o nível só desce)
	mat.set_shader_parameter("pela_fita", true)
	mat.set_shader_parameter("largura", RIO_FAIXA * 2.0)
	for c: Curso in _cursos:
		var verts := PackedVector3Array()
		var nrms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var sv := c.fita_de
		var k := 0
		while sv <= c.fita_ate:
			var p := c.ponto(sv)
			var q := c.ponto(sv + 1.0)
			var dir := (q - p).normalized() if q.distance_to(p) > 0.01 else Vector2(0, 1)
			var lado := Vector2(-dir.y, dir.x)
			var y := c.nivel(sv)
			for sinal: float in [-1.0, 1.0]:
				var v := p + lado * RIO_FAIXA * sinal
				verts.append(Vector3(v.x, y, v.y))
				nrms.append(Vector3.UP)
				uvs.append(Vector2(sinal * 0.5 + 0.5, sv / 22.0))
			if k > 0:
				var b := k * 2
				idx.append_array(PackedInt32Array([b - 2, b - 1, b + 1, b - 2, b + 1, b]))
			k += 1
			sv += 5.0
		if k < 2:
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = nrms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "Rio"
		mi.mesh = m
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# o espelho do poço
	var disco := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = POCO.z * 1.32
	cil.bottom_radius = POCO.z * 1.32
	cil.height = 0.02
	cil.radial_segments = 28
	cil.cap_bottom = false
	disco.mesh = cil
	disco.material_override = _mat_rio(64, 0.15)
	disco.position = Vector3(POCO.x, POCO_NIVEL - 0.01, POCO.y)
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disco)
	# o espelho da lagoa da represa (a terra em volta e a própria represa escondem a borda do disco)
	var lagoa_r := MeshInstance3D.new()
	var cl := CylinderMesh.new()
	cl.top_radius = REPRESA_LAGOA.z
	cl.bottom_radius = REPRESA_LAGOA.z
	cl.height = 0.02
	cl.radial_segments = 48
	lagoa_r.mesh = cl
	lagoa_r.material_override = _mat_rio(66, 0.08)
	lagoa_r.position = Vector3(REPRESA_LAGOA.x, REPRESA_NIVEL - 0.01, REPRESA_LAGOA.y)
	lagoa_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lagoa_r)
	# o espelho da nascente
	var olho := MeshInstance3D.new()
	var co := CylinderMesh.new()
	co.top_radius = 5.0
	co.bottom_radius = 5.0
	co.height = 0.02
	co.radial_segments = 20
	co.cap_bottom = false
	olho.mesh = co
	olho.material_override = disco.material_override
	olho.position = Vector3(NASCENTE.x, queda_topo.y - 0.01, NASCENTE.y)
	olho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(olho)
	_cachoeira()


## A queda: uma cortina d'água da beira do paredão até o poço, com névoa de respingo embaixo.
func _cachoeira() -> void:
	var ruido_q := NoiseTexture2D.new()
	ruido_q.width = 256
	ruido_q.height = 256
	ruido_q.seamless = true
	ruido_q.noise = _ruido(65, 1.0 / 14.0, 3)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/cachoeira.gdshader")
	mat.set_shader_parameter("ruido", ruido_q)
	var para := Vector2(POCO.x, POCO.y) - NASCENTE
	var dir2 := para.normalized()
	var beira := NASCENTE + dir2 * 5.0
	var topo := Vector3(beira.x, queda_topo.y - 0.2, beira.y)
	para = Vector2(POCO.x, POCO.y) - beira
	var pe2 := Vector2(topo.x, topo.z) + dir2 * maxf(4.0, para.length() - POCO.z * 0.75)
	var pe := Vector3(pe2.x, POCO_NIVEL - 0.3, pe2.y)
	var dir := Vector3(dir2.x, 0, dir2.y)
	var lado := Vector3(-dir.z, 0, dir.x)
	var largura := 4.2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var linhas := 24
	for k in linhas:
		var t0 := float(k) / linhas
		var t1 := float(k + 1) / linhas
		var p0 := Vector3(topo.x + (pe.x - topo.x) * pow(t0, 0.55), lerpf(topo.y, pe.y, t0 * t0 * 0.35 + t0 * 0.65), topo.z + (pe.z - topo.z) * pow(t0, 0.55))
		var p1 := Vector3(topo.x + (pe.x - topo.x) * pow(t1, 0.55), lerpf(topo.y, pe.y, t1 * t1 * 0.35 + t1 * 0.65), topo.z + (pe.z - topo.z) * pow(t1, 0.55))
		var l0 := largura * lerpf(0.8, 1.25, t0)
		var l1 := largura * lerpf(0.8, 1.25, t1)
		# a queda tem corpo: a seção é um meio-cano que sai da pedra (de lado, uma fita chata parecia papel)
		var colunas := 10
		for cnum in colunas:
			var quad: Array = []
			for canto: Array in [[cnum, 0], [cnum + 1, 0], [cnum + 1, 1], [cnum, 0], [cnum + 1, 1], [cnum, 1]]:
				var u := float(canto[0]) / colunas
				var ang := PI * u
				var t := t0 if canto[1] == 0 else t1
				var centro := p0 if canto[1] == 0 else p1
				var larg := l0 if canto[1] == 0 else l1
				var fundura := lerpf(0.9, 2.1, t)  # mais gorda embaixo
				var fora := (dir * sin(ang) - lado * cos(ang)).normalized()
				quad.append([centro - lado * cos(ang) * larg + dir * (sin(ang) * fundura - 0.5), Vector2(u, t), (fora + Vector3.UP * 0.2).normalized()])
			for v: Array in quad:
				st.set_normal(v[2])
				st.set_uv(v[1])
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.name = "Cachoeira"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	quedas.append((topo + pe) * 0.5)
	cortinas.append([topo, pe, largura * 1.1])
	# névoa de respingo no pé da queda
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.vertex_color_use_as_albedo = true
	mp.albedo_color = Color(1, 1, 1, 0.22)
	if ResourceLoader.exists("res://assets/fx/kenney/smoke_04.png"):
		mp.albedo_texture = load("res://assets/fx/kenney/smoke_04.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 5.0)
	quad.material = mp
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	var pp := ParticleProcessMaterial.new()
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pp.emission_box_extents = Vector3(largura * 1.2, 0.5, 2.0)
	pp.direction = Vector3(0, 1, 0)
	pp.spread = 40.0
	pp.initial_velocity_min = 1.0
	pp.initial_velocity_max = 2.6
	pp.gravity = Vector3(0, 0.2, 0)
	pp.scale_min = 0.7
	pp.scale_max = 1.6
	pp.color_ramp = gt
	var nev := GPUParticles3D.new()
	nev.amount = 26
	nev.lifetime = 3.2
	nev.process_material = pp
	nev.draw_pass_1 = quad
	nev.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nev.visibility_aabb = AABB(Vector3(-16, -4, -16), Vector3(32, 20, 32))
	nev.position = pe + Vector3(0, 0.8, 0)
	nev.rotation.y = atan2(lado.x, lado.z) - PI * 0.5
	add_child(nev)


func altura(x: float, z: float) -> float:
	return super.altura(x, z) if _dentro(x, z) else _alt_fora(x, z)


func agua(x: float, z: float) -> float:
	if maxf(absf(x), absf(z)) < AGUA_DENTRO:
		return super.agua(x, z)
	var h := altura(x, z)
	if h < MAR:
		return MAR
	if _na_terra_nova(x, z):
		return terra_nova.agua(x, z, h)
	for c: Curso in _cursos:
		var r := c.perto(x, z, RIO_FAIXA)
		if r.x < RIO_FAIXA and r.y >= c.fita_de - 2.0 and r.y <= c.fita_ate + 2.0:
			var n := c.nivel(r.y)
			if h < n:
				return n
	if Sumidouro.agua(x, z) > -INF:
		return Sumidouro.agua(x, z)
	if h < REPRESA_NIVEL and x > REPRESA_LAGOA.x - REPRESA_LAGOA.z and x < REPRESA_X:
		# o disco da lagoa, e a garganta entre ele e a parede da represa
		var dz := z - REPRESA_LAGOA.y
		if Vector2(x, z).distance_to(Vector2(REPRESA_LAGOA.x, REPRESA_LAGOA.y)) < REPRESA_LAGOA.z \
				or (x > REPRESA_X - 46.0 and absf(dz) < MarcosLeste.REPRESA_MEIA and x < MarcosLeste.represa_x(dz) - 1.5):
			return REPRESA_NIVEL
	if Vector2(x, z).distance_to(Vector2(POCO.x, POCO.y)) < POCO.z * 1.15 and h < POCO_NIVEL:
		return POCO_NIVEL
	if Vector2(x, z).distance_to(NASCENTE) < 5.0 and h < queda_topo.y:
		return queda_topo.y
	return -INF


func normal_em(x: float, z: float) -> Vector3:
	if _dentro(x, z):
		return super.normal_em(x, z)
	if _na_terra_nova(x, z):
		return terra_nova.normal_em(x, z)
	var e := F_PASSO
	return Vector3(_fora(x - e, z) - _fora(x + e, z), 2.0 * e, _fora(x, z - e) - _fora(x, z + e)).normalized()


## A mata que fechava o quadro da clareira vira um anel de borda torta; fora dele vale a cobertura do mapa,
## para o quadrado não aparecer visto de cima.
func _arvore_cabe(x: float, z: float) -> bool:
	var r := Vector2(x, z).length()
	if r < 122.0 + _n_mata.get_noise_2d(x * 0.7, z * 0.7) * 26.0:
		return true
	var c := cobertura(x, z)
	return c == 1 or c == 2


## O cume da serra: acha o ponto mais alto e põe um marco de pedras em pé, que se vê de longe e serve de mirante.
func _cume() -> void:
	var melhor := 0
	for i in _fora_h.size():
		if _fora_h[i] > _fora_h[melhor]:
			melhor = i
	var x := -F_META + (melhor % F_N) * F_PASSO
	var z := -F_META + (melhor / F_N) * F_PASSO
	cume = Vector3(x, _fora_h[melhor], z)
	for d: Array in [[Vector2(0, -7), 7.5, 0.4, "pedra_alta"], [Vector2(8, 3), 5.5, 2.2, "pedra_alta"], [Vector2(-8, 5), 4.6, 4.1, "pedra_alta"],
			[Vector2(3, 9), 2.6, 1.0, "pedra_b"], [Vector2(-4, -1), 2.0, 3.0, "pedra_a"]]:
		var o: Vector2 = d[0]
		var esc: float = d[1]
		var px := x + o.x
		var pz := z + o.y
		_por(d[3], Transform3D(Basis(Vector3.UP, d[2]).scaled(Vector3.ONE * esc), Vector3(px, _fora(px, pz) + esc * 0.35, pz)), true)


# ---------------------------------------------------------------- a costa

## Grade grossa com a distância de cada ponto do mar até a terra mais perto (busca em largura a partir da terra).
func _preparar_costa() -> void:
	if terra_nova:
		_c0 = Vector2(TerraNova.X0, TerraNova.Z0)
		_cn = Vector2i(int((F_META - _c0.x) / C_PASSO) + 1, int((F_META - _c0.y) / C_PASSO) + 1)
	var nx := _cn.x
	_costa_dist.resize(_cn.x * _cn.y)
	_costa_dist.fill(INF)
	_costa_terra.resize(_cn.x * _cn.y)
	_costa_terra.fill(-1)
	var fila := PackedInt32Array()
	for iz in _cn.y:
		for ix in nx:
			var x := _c0.x + ix * C_PASSO
			var z := _c0.y + iz * C_PASSO
			if _alt_fora(x, z) > 1.2:
				var i := iz * nx + ix
				_costa_dist[i] = 0.0
				_costa_terra[i] = i
				fila.append(i)
	var k := 0
	while k < fila.size():
		var i := fila[k]
		k += 1
		var ix := i % nx
		var iz := i / nx
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var jx := ix + d.x
			var jz := iz + d.y
			if jx < 0 or jz < 0 or jx >= nx or jz >= _cn.y:
				continue
			var j := jz * nx + jx
			if _costa_terra[j] >= 0:
				continue
			_costa_terra[j] = _costa_terra[i]
			var t := _costa_terra[i]
			_costa_dist[j] = Vector2(jx - t % nx, jz - t / nx).length() * C_PASSO
			fila.append(j)


func _celula_costa(x: float, z: float) -> int:
	var ix := clampi(roundi((x - _c0.x) / C_PASSO), 0, _cn.x - 1)
	var iz := clampi(roundi((z - _c0.y) / C_PASSO), 0, _cn.y - 1)
	return iz * _cn.x + ix


## Metros até a terra mais perto (0 em terra). Fora da grade soma o que passou da borda.
func distancia_da_costa(x: float, z: float) -> float:
	var fim := _c0 + Vector2(_cn - Vector2i.ONE) * C_PASSO
	var fora_mapa := Vector2(maxf(0.0, maxf(_c0.x - x, x - fim.x)), maxf(0.0, maxf(_c0.y - z, z - fim.y))).length()
	return _costa_dist[_celula_costa(x, z)] + fora_mapa


## Um ponto de terra firme perto de (x, z), para o robô voltar depois da pane no mar.
func praia_perto(x: float, z: float) -> Vector3:
	var t := _costa_terra[_celula_costa(x, z)]
	if t < 0:
		return spawn
	var px := _c0.x + (t % _cn.x) * C_PASSO
	var pz := _c0.y + (t / _cn.x) * C_PASSO
	# alguns passos para dentro da terra, para não nascer na linha d'água
	var dentro := (Vector2(px, pz) - Vector2(x, z)).normalized()
	for passo in 6:
		var q := Vector2(px, pz) + dentro * 4.0
		if _alt_fora(q.x, q.y) < 1.2:
			break
		px = q.x
		pz = q.y
		if _alt_fora(px, pz) > 2.5:
			break
	return Vector3(px, altura(px, pz) + 0.4, pz)


# ---------------------------------------------------------------- chão de fora

func _malha_fora() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_chao.gdshader")
	mat.set_shader_parameter("ruido", _tex)
	var bl := 50  # quadrados por bloco: 200 m
	var lado := bl + 1
	var furo := int(C_META / F_PASSO)  # quadrados da clareira, de cada lado do centro
	var meio := (F_N - 1) / 2
	for bz in (F_N - 1) / bl:
		for bx in (F_N - 1) / bl:
			var verts := PackedVector3Array()
			var nrms := PackedVector3Array()
			var cols := PackedColorArray()
			verts.resize(lado * lado)
			nrms.resize(lado * lado)
			cols.resize(lado * lado)
			for j in lado:
				for i in lado:
					var gx := bx * bl + i
					var gz := bz * bl + j
					var x := -F_META + gx * F_PASSO
					var z := -F_META + gz * F_PASSO
					var h := _fora_h[gz * F_N + gx]
					var k := j * lado + i
					verts[k] = Vector3(x, h, z)
					nrms[k] = normal_em_fora(gx, gz)
					var c := _cob[gz * F_N + gx]
					var areia := 1.0 if c == 4 else (1.0 - smoothstep(1.5, 4.5, h))
					cols[k] = Color(0.3 if c == 2 else 0.0, 0.0, areia, 0.0 if c == 3 else 1.0)
			var idx := PackedInt32Array()
			for j in bl:
				for i in bl:
					var gx := bx * bl + i
					var gz := bz * bl + j
					# o quadrado da clareira fica de fora: lá o chão é o dela
					if gx >= meio - furo and gx < meio + furo and gz >= meio - furo and gz < meio + furo:
						continue
					var a := j * lado + i
					idx.append_array(PackedInt32Array([a, a + 1, a + lado + 1, a, a + lado + 1, a + lado]))
			if idx.is_empty():
				continue
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


## Onde o mapa acaba com a terra acima do mar (o norte, o oeste e o Platô das Flores a leste), a grade
## terminava no ar: de fora via-se o chão por baixo, sem parede. Aqui a borda desce em falésia de pedra até
## o fundo do mar, um pouco inclinada e irregular, com colisão.
var falesia_faces := 0

func _falesia_da_borda() -> void:
	var n := F_N - 1
	var fundo := -15.0
	var faces := PackedVector3Array()
	var ru := FastNoiseLite.new()
	ru.seed = 771
	ru.frequency = 0.03
	# os quatro lados: [nó inicial, passo ao longo da borda, direção para fora]
	for lado: Array in [[Vector2i(0, 0), Vector2i(1, 0), Vector2(0, -1)], [Vector2i(n, 0), Vector2i(0, 1), Vector2(1, 0)],
			[Vector2i(n, n), Vector2i(-1, 0), Vector2(0, 1)], [Vector2i(0, n), Vector2i(0, -1), Vector2(-1, 0)]]:
		var g0: Vector2i = lado[0]
		var passo: Vector2i = lado[1]
		var para_fora: Vector2 = lado[2]
		var ao_longo := Vector2(passo)
		var linhas: Array = []  # por nó: [topo, meio, pé]
		for k in n + 1:
			var g := g0 + passo * k
			var h := _fora_h[g.y * F_N + g.x]
			var x := -F_META + g.x * F_PASSO
			var z := -F_META + g.y * F_PASSO
			# nos cantos os dois lados saem na diagonal, para se encontrarem
			var d := para_fora
			if k == 0:
				d = para_fora - ao_longo
			elif k == n:
				d = para_fora + ao_longo
			var alto := maxf(h - fundo, 0.0)
			var r1 := ru.get_noise_2d(x * 1.7 + z, z * 1.7 - x)
			var r2 := ru.get_noise_2d(x - 300.0, z + 300.0)
			var o1 := alto * (0.10 + 0.10 * r1) + 1.0
			var o2 := alto * (0.34 + 0.14 * r2) + 3.0
			linhas.append([h, Vector3(x, h, z), Vector3(x + d.x * o1, lerpf(h, fundo, 0.45 + 0.1 * r2), z + d.y * o1), Vector3(x + d.x * o2, fundo, z + d.y * o2)])
		for k in n:
			var a: Array = linhas[k]
			var b: Array = linhas[k + 1]
			if float(a[0]) < fundo + 0.5 and float(b[0]) < fundo + 0.5:
				continue
			# onde a grade da terra nova continua do lado de fora, o chão segue nela (a terra é uma só): sem falésia
			if terra_nova and _fora_coberto(a[1], para_fora) and _fora_coberto(b[1], para_fora):
				continue
			var fora3 := Vector3(para_fora.x, 0, para_fora.y)
			for f in 2:
				for tri: Array in [[a[1 + f], b[1 + f], b[2 + f]], [a[1 + f], b[2 + f], a[2 + f]]]:
					var t0: Vector3 = tri[0]
					var t1: Vector3 = tri[1]
					var t2: Vector3 = tri[2]
					# a frente da face olha para fora do mapa
					if (t2 - t0).cross(t1 - t0).dot(fora3) < 0.0:
						var troca := t1
						t1 = t2
						t2 = troca
					faces.append_array(PackedVector3Array([t0, t1, t2]))
	falesia_faces = faces.size() / 3
	if faces.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in faces:
		st.add_vertex(v)
	st.generate_normals()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/vale_rocha.gdshader")
	mat.set_shader_parameter("ruido", _tex)
	var mi := MeshInstance3D.new()
	mi.name = "FalesiaDaBorda"
	mi.mesh = st.commit()
	mi.mesh.surface_set_material(0, mat)
	add_child(mi)
	var corpo := StaticBody3D.new()
	corpo.name = "FalesiaDaBordaCorpo"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	corpo.add_child(cs)


func _fora_coberto(p: Vector3, para_fora: Vector2) -> bool:
	return terra_nova.cobre(p.x + para_fora.x * 8.0, p.z + para_fora.y * 8.0)


func normal_em_fora(gx: int, gz: int) -> Vector3:
	var hl := _fora_h[gz * F_N + maxi(gx - 1, 0)]
	var hr := _fora_h[gz * F_N + mini(gx + 1, F_N - 1)]
	var hd := _fora_h[maxi(gz - 1, 0) * F_N + gx]
	var hu := _fora_h[mini(gz + 1, F_N - 1) * F_N + gx]
	return Vector3(hl - hr, 2.0 * F_PASSO, hd - hu).normalized()


func _colisao_fora() -> void:
	# o mesmo relevo da malha; dentro da clareira fica um metro abaixo do chão dela
	var dados := _fora_h.duplicate()
	var furo := int(C_META / F_PASSO) - 1
	var meio := (F_N - 1) / 2
	for gz in range(meio - furo, meio + furo + 1):
		for gx in range(meio - furo, meio + furo + 1):
			# o relevo de fora não vale dentro da clareira (lá ele pode passar por cima do chão dela)
			var x := -F_META + gx * F_PASSO
			var z := -F_META + gz * F_PASSO
			dados[gz * F_N + gx] = minf(dados[gz * F_N + gx], super.altura(x, z)) - 1.0
	# na área do ombro da Fundição a colisão é uma malha com os triângulos da malha do chão (doc §162)
	Fundicao.colisao_do_ombro(self, dados)
	var corpo := StaticBody3D.new()
	corpo.name = "ChaoFora"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var forma := HeightMapShape3D.new()
	forma.map_width = F_N
	forma.map_depth = F_N
	forma.map_data = dados
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.scale = Vector3(F_PASSO, 1.0, F_PASSO)
	corpo.add_child(cs)
	# o relevo acaba a F_META do meio, e a pane do mar pode vir depois disso: um fundo plano sem fim, logo
	# abaixo do ponto mais fundo do mapa, para o robô que mergulha lá fora não cair no vazio
	var mais_fundo := 0.0
	for h in dados:
		mais_fundo = minf(mais_fundo, h)
	# (uma caixa larga, não um WorldBoundaryShape3D: no Jolt o plano "sem fim" só vai até 1 km do corpo)
	var laje_fundo := BoxShape3D.new()
	laje_fundo.size = Vector3(12000.0, 4.0, 12000.0)
	var cs_p := CollisionShape3D.new()
	cs_p.shape = laje_fundo
	cs_p.position = Vector3(0.0, mais_fundo - 2.5, 0.0)
	corpo.add_child(cs_p)


func _mar() -> void:
	var ruido_agua := NoiseTexture2D.new()
	ruido_agua.width = 256
	ruido_agua.height = 256
	ruido_agua.seamless = true
	ruido_agua.noise = _ruido(91, 1.0 / 32.0, 3)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/rio.gdshader")
	mat.set_shader_parameter("ruido", ruido_agua)
	mat.set_shader_parameter("raso", Color(0.22, 0.56, 0.56))
	mat.set_shader_parameter("fundo", Color(0.03, 0.16, 0.30))
	mat.set_shader_parameter("fluxo", Vector2(0.3, 0.8))
	mat.set_shader_parameter("velocidade", 0.22)
	mat.set_shader_parameter("prof_max", 12.0)
	var pm := PlaneMesh.new()
	pm.size = Vector2(40000, 40000)
	var mi := MeshInstance3D.new()
	mi.name = "Mar"
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(0, MAR, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# fundo escuro além do mapa, na mesma profundidade, para a cor do mar não mudar na borda dos dados
	# com o mesmo shader e a mesma cor de areia do chão: com outro material, do alto se via o quadrado dos dados
	var fundo := MeshInstance3D.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var m := 20000.0
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-m, 0, -m), Vector3(m, 0, -m), Vector3(m, 0, m), Vector3(-m, 0, m)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arr[Mesh.ARRAY_COLOR] = PackedColorArray([Color(0, 0, 1, 1), Color(0, 0, 1, 1), Color(0, 0, 1, 1), Color(0, 0, 1, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var pf := ArrayMesh.new()
	pf.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	fundo.mesh = pf
	var mf := ShaderMaterial.new()
	mf.shader = load("res://scripts/shaders/vale_chao.gdshader")
	mf.set_shader_parameter("ruido", _tex)
	fundo.material_override = mf
	fundo.position = Vector3(0, -14.05, 0)
	fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fundo)


# ---------------------------------------------------------------- mata de fora

## Dentro d'água ou na beira dos rios e do poço: árvore não nasce.
func _perto_dagua(x: float, z: float) -> bool:
	for c: Curso in _cursos:
		if c.perto(x, z, 9.0).x < 9.0:
			return true
	return Vector2(x, z).distance_to(Vector2(POCO.x, POCO.y)) < POCO.z * 1.4 or Vector2(x, z).distance_to(NASCENTE) < 12.0


var _fila_q: Array = []  # as árvores de fora, com o tipo (fotos e testes)
var plantas_amostra := {}  # tipo -> um lugar onde há uma (fotos)
var plantas_chao := 0  # quantas plantas, flores e pedras dos pacotes foram postas (testes)


## Plantas de chão, flores, cogumelos, moitas e pedras dos pacotes, pelo mapa todo: flores em manchas nos
## campos, samambaias e cogumelos debaixo da mata, pedras soltas. Só aparecem de perto (até 120 m).
func _plantas_do_chao() -> void:
	if "--sem-pacotes" in OS.get_cmdline_user_args():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2311
	var fila: Array = []
	var pedras: Array = []
	var guardado: Variant = Cache.ler("plantas_chao")
	if guardado is Dictionary:
		fila = guardado["fila"]
		pedras = guardado["pedras"]
	else:
		var passo := 6.0
		var z := -F_META + 10.0
		while z < F_META - 10.0:
			var x := -F_META + 10.0
			while x < F_META - 10.0:
				var px := x + rng.randf_range(-2.8, 2.8)
				var pz := z + rng.randf_range(-2.8, 2.8)
				var sorte := rng.randf()
				var qual := rng.randf()
				var giro := rng.randf() * TAU
				var tam := rng.randf_range(0.8, 1.25)
				x += passo
				var h := altura(px, pz)
				if h < 2.5 or agua(px, pz) > -INF or normal_em(px, pz).y < 0.82 or not Ruinas.livre(px, pz) or Cavernas.dentro(px, pz):
					continue
				if Vector2(px - spawn.x, pz - spawn.z).length() < 10.0:
					continue
				var c := cobertura(px, pz) if maxf(absf(px), absf(pz)) > C_META else (1 if _arvore_cabe(px, pz) and Vector2(px, pz).length() > 70.0 else 0)
				var mancha := _n_mata.get_noise_2d(px * 2.3 + 500.0, pz * 2.3 - 300.0)
				var especie := _n_mata.get_noise_2d(px * 0.9 - 900.0, pz * 0.9 + 700.0)
				var tipo := ""
				var s := 1.0
				if c == 0:
					if mancha > 0.18 and sorte < 0.55:
						if especie > 0.0:
							tipo = "q_flor_a" if qual < 0.35 else "q_flor_b"
						else:
							tipo = "q_flor_c" if qual < 0.3 else "q_flor_d"
						s = 0.25
					elif sorte < 0.05:
						tipo = ["q_planta_c", "q_planta_d", "q_trevo", "q_trevo_b"][int(qual * 4.0) % 4]
						s = 0.6
					elif sorte < 0.07:
						tipo = "q_seixo_" + "abcdefghijk"[int(qual * 11.0) % 11]
						s = 1.6
					elif sorte < 0.076:
						tipo = "q_pedra"
				elif c == 1 or c == 2:
					if sorte < 0.2:
						tipo = ["q_samambaia", "q_samambaia", "q_planta_a", "q_planta_b"][int(qual * 4.0) % 4]
						s = 0.6
					elif sorte < 0.24:
						tipo = "q_cogumelo"
						s = 0.7
					elif sorte < 0.28:
						tipo = "q_moita" if qual < 0.7 else "q_moita_flor"
						s = 0.8
					elif sorte < 0.287:
						tipo = "q_pedra"
					elif sorte < 0.305:
						tipo = "q_orelha"  # o cogumelo de tronco, em tufos no chão da mata
						s = 0.55
				# beira d'água (rio, lagoa, mar): seixos soltos no lugar do que cresceria ali. (As lajes RockPath do
				# pacote saíram em 2026-11-19: cada uma é um trecho de calçamento e a margem ficava com cara de estrada.)
				if sorte > 0.45 and (agua(px + 4.0, pz) > -INF or agua(px - 4.0, pz) > -INF or agua(px, pz + 4.0) > -INF or agua(px, pz - 4.0) > -INF):
					tipo = "q_seixo_" + "abcdefghijk"[int(qual * 11.0) % 11]
					s = 1.3 + 0.9 * fposmod(qual * 7.0, 1.0)
					var longe_m := Vector2(px, pz).length()
					if not plantas_amostra.has("margem") and longe_m > 150.0 and longe_m < 500.0:
						plantas_amostra["margem"] = Vector3(px, h, pz)
				if tipo == "":
					continue
				# no ombro da Fundição quem planta é ela (doc §162); o sorteio segue igual para o resto da ilha
				var poe := not Fundicao.no_ombro(px, pz)
				if tipo == "q_pedra":
					tipo = ["q_pedra_a", "q_pedra_b", "q_pedra_c"][int(qual * 3.0) % 3]
					s = rng.randf_range(0.3, 0.62)
					var xfp := Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * s), Vector3(px, h - 0.12 * s, pz))
					if poe:
						fila.append([tipo, xfp])
						pedras.append([tipo, xfp])
					continue
				# deitada no chão inclinado
				var n := normal_em(px, pz)
				var b := Basis(Vector3.UP, giro)
				b = Basis(Quaternion(Vector3.UP, n)) * b
				if poe:
					fila.append([tipo, Transform3D(b.scaled(Vector3.ONE * s * tam), Vector3(px, h - 0.03, pz))])
				if tipo.begins_with("q_flor"):
					# flor vem em canteiro: mais três ou quatro em volta, da mesma espécie
					for k in 3 + int(qual * 2.0):
						var of := Vector2.from_angle(giro + k * 1.7) * rng.randf_range(0.6, 2.4)
						var hf := altura(px + of.x, pz + of.y)
						if agua(px + of.x, pz + of.y) > -INF:
							continue
						var esc_f := rng.randf_range(0.7, 1.2)
						if poe:
							fila.append([tipo, Transform3D(Basis(Vector3.UP, giro * (k + 2)).scaled(Vector3.ONE * s * esc_f),
								Vector3(px + of.x, hf - 0.03, pz + of.y))])
				if tipo == "q_cogumelo":
					# cogumelo vem em grupo
					for k in 2:
						var o := Vector2.from_angle(giro + k * 2.2) * rng.randf_range(0.35, 0.8)
						var esc_c := rng.randf_range(0.5, 0.9)
						if poe:
							fila.append([tipo, Transform3D(Basis(Vector3.UP, giro * (k + 2)).scaled(Vector3.ONE * s * tam * esc_c),
								Vector3(px + o.x, altura(px + o.x, pz + o.y) - 0.03, pz + o.y))])
			z += passo
		Cache.gravar("plantas_chao", {"fila": fila, "pedras": pedras})
	plantas_chao = fila.size()
	for item in fila:
		var onde: Vector3 = (item[1] as Transform3D).origin
		if not plantas_amostra.has(item[0]) and Vector2(onde.x, onde.z).length() > 150.0 and Vector2(onde.x, onde.z).length() < 500.0:
			plantas_amostra[item[0]] = onde
		# um seixo de margem, para a foto de conferência (vale também quando as plantas vêm do cache)
		if not plantas_amostra.has("margem") and String(item[0]).begins_with("q_seixo") and Vector2(onde.x, onde.z).length() > 150.0 and Vector2(onde.x, onde.z).length() < 500.0 \
				and (agua(onde.x + 4.0, onde.z) > -INF or agua(onde.x - 4.0, onde.z) > -INF or agua(onde.x, onde.z + 4.0) > -INF or agua(onde.x, onde.z - 4.0) > -INF):
			plantas_amostra["margem"] = onde
	var grupos := {}
	for item in fila:
		var xf: Transform3D = item[1]
		var chave := "%s|%d|%d" % [item[0], floori(xf.origin.x / 160.0), floori(xf.origin.z / 160.0)]
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
		var grande := tipo.begins_with("q_pedra") or tipo.begins_with("q_moita")
		_multi(tipo, xfs, centro, 0.0, 280.0 if grande else 140.0, grande)
	# as pedras seguram o robô
	var corpo := StaticBody3D.new()
	corpo.name = "PedrasSoltas"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	var formas := {}
	for item in pedras:
		var nome: String = item[0]
		if not formas.has(nome):
			formas[nome] = ((_malhas[nome] as Array)[0][0] as Mesh).create_convex_shape()
		var cs := CollisionShape3D.new()
		cs.shape = formas[nome]
		cs.transform = (item[1] as Transform3D) * ((_malhas[nome] as Array)[0][1] as Transform3D)
		Obstaculos.registrar_forma(formas[nome], cs.transform, _fora(cs.transform.origin.x, cs.transform.origin.z))
		corpo.add_child(cs)
	print("plantas de chão: %d peças, %d pedras com colisão" % [fila.size(), pedras.size()])


func _mata_fora() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var primeiro := arv_pos.size()
	var fila: Array = []
	var passo := 9.0
	var z := -F_META + 12.0
	while z < F_META - 12.0:
		var x := -F_META + 12.0
		while x < F_META - 12.0:
			var px := x + rng.randf_range(-3.6, 3.6)
			var pz := z + rng.randf_range(-3.6, 3.6)
			x += passo
			if maxf(absf(px), absf(pz)) < C_META + 2.0:
				continue
			var c := cobertura(px, pz)
			if c != 1 and c != 2:
				continue
			if rng.randf() > (0.92 if c == 2 else 0.5):
				continue
			var h := _fora(px, pz)
			if h < 3.0 or normal_em(px, pz).y < 0.76 or _perto_dagua(px, pz) or not Ruinas.livre(px, pz) or Cavernas.dentro(px, pz):
				continue
			# colada num paredão a árvore sumia dentro da rocha
			var na_parede := false
			for viz: Vector2 in [Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)]:
				if normal_em(px + viz.x, pz + viz.y).y < 0.62:
					na_parede = true
			if na_parede:
				continue
			var sorte := rng.randf()
			var tipo := "carvalho_a"
			var s := rng.randf_range(0.9, 1.5)
			if h > 95.0:
				tipo = "pinheiro" if sorte < 0.85 else "betula"
			elif c == 2:
				# mata fechada: árvores maiores, mais carvalho e pinheiro escuro
				tipo = "carvalho_b" if sorte < 0.5 else ("pinheiro" if sorte < 0.8 else "carvalho_a")
				s = rng.randf_range(1.3, 2.0)
			else:
				tipo = "pinheiro" if sorte < 0.2 else ("betula" if sorte > 0.84 else ("carvalho_a" if sorte < 0.6 else "carvalho_b"))
			var giro := rng.randf() * TAU
			if Fundicao.no_ombro(px, pz):
				continue  # o ombro da Fundição tem as árvores dele (o sorteio daqui corre no relevo de antes)
			arv_pos.append(Vector3(px, h - 0.15, pz))
			arv_escala.append(s * 0.8)
			tipo = tipo_variado(tipo, sorte_do_lugar(px, pz))
			arv_tipo.append(0 if tipo.contains("pinheiro") else 1)
			arv_nome.append(tipo)
			fila.append([tipo, Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * s), Vector3(px, h - 0.15, pz))])
		z += passo
	Fundicao.arvores_do_ombro(self, fila)
	arvores_fora = fila.size()
	_fila_q = fila
	# grade para a colisão e para as folhas ao atravessar as copas
	for i in range(primeiro, arv_pos.size()):
		var cel := Vector2i(floori(arv_pos[i].x / CELULA_ARVORE), floori(arv_pos[i].z / CELULA_ARVORE))
		var l: PackedInt32Array = _grade_arv.get(cel, PackedInt32Array())
		l.append(i)
		_grade_arv[cel] = l
	# desenho: por tipo e por bloco (100 m perto, 160 m longe); completo perto, leve de longe, e nada além
	# de VULTO_ATE. A troca é árvore a árvore (Clareira._multi)
	var grupos := {}
	for item in fila:
		var xf: Transform3D = item[1]
		var chave := "%s|%d|%d" % [item[0], floori(xf.origin.x / 100.0), floori(xf.origin.z / 100.0)]
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
	for g in _por_bloco(fila, 200.0, true):
		var xfs2: Array = g[1]
		_multi(g[0], xfs2, _centro(xfs2), TROCA_ARVORE, TROCA_VULTO, false)
	for g2 in _por_bloco(fila, 400.0, true, true):
		var xfs3: Array = g2[1]
		_multi(g2[0], xfs3, _centro(xfs3), TROCA_VULTO, VULTO_ATE, false)
