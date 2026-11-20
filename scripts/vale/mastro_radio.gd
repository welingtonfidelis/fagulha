class_name MastroRadio
extends Node3D
## O mastro grande do Relé (2026-11-19), o lugar que o **radiador duplo** abre. Na Ilha do Relé, ao lado da
## torre velha e torta, fica um mastro de rádio de 150 m. A antena do topo ainda transmite: num raio de 80 m em
## volta dela o motor esquenta depressa (`Armadura.calor_extra`). Com o radiador simples o robô superaquece
## antes de chegar; com o duplo dá tempo. No alto há uma cabine pequena, protegida por uma gaiola de ferro
## (ali dentro não esquenta), com o receptor: é lá em cima que o robô capta o sinal. Ligando o receptor, aparece
## a lembrança "Alguém respondeu" e passa a existir, de noite, uma luz distante no horizonte do mar: o gancho
## para um lugar fora da ilha, que ainda vai ser construído.
## Quem cria passa `armadura`, `hud`, `memorias` e `mapa`.

const ALTURA := 150.0
const PATAMAR := 60.0  # um patamar de serviço abaixo do campo da antena, para esfriar antes da subida final
const CAMPO := 80.0  # raio do campo quente em volta do topo
const ABRIGO := 5.0  # dentro da gaiola da cabine não esquenta
const CALOR := 40.0  # %/s sem radiador
const FATOR_RADIADOR := 0.62  # com o radiador simples: ainda esquenta demais
const FATOR_DUPLO := 0.16  # com o duplo: dá tempo de sobra para quem não se perde
const PERTO := 2.4
const SINAL := Vector3(-2300.0, 60.0, 1700.0)  # onde a luz distante aparece (fora do mapa, a sudoeste)

var armadura: Armadura
var hud: Hud
var memorias: Memorias
var mapa: Vale
var ligado := false  # o receptor foi ligado
var pe := Vector3.INF  # o pé do mastro, no mundo
var topo := Vector3.INF  # o piso da cabine
var receptor := Vector3.INF
var no_campo := false  # o robô está no campo quente da antena (testes)
var _dica_minha := ""
var _avisou := false


func _ready() -> void:
	if Guardado.ativo:
		ligado = bool((Guardado.progresso("achados") as Dictionary).get("sinal", false))
	for i in 6:
		await get_tree().physics_frame
	_construir()
	LuzesNoite.ligadas["sinal"] = ligado


func _luz(centro: Vector3, tam: Vector3, cor: Color, forca: float, giro := Basis.IDENTITY) -> void:
	var mi := MeshInstance3D.new()
	var cx := BoxMesh.new()
	cx.size = tam
	mi.mesh = cx
	var ml := StandardMaterial3D.new()
	ml.albedo_color = cor
	ml.emission_enabled = true
	ml.emission = cor
	ml.emission_energy_multiplier = forca
	mi.material_override = ml
	mi.transform = Transform3D(giro, centro)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A largura do mastro a cada altura: 9 m no pé, 2 m no topo.
static func largura(y: float) -> float:
	return lerpf(9.0, 2.0, pow(clampf(y / ALTURA, 0.0, 1.0), 0.8))


func _construir() -> void:
	# o chão mais alto e firme da ilhota, fora do pé da torre velha e da casinha
	var melhor := Vector2.INF
	var mais_alto := -INF
	for dx: float in [-34.0, -24.0, -14.0, 14.0, 24.0, 34.0]:
		for dz: float in [-30.0, -20.0, -10.0, 10.0, 20.0, 30.0]:
			var c := MarcosMar.RELE + Vector2(dx, dz)
			if mapa.agua(c.x, c.y) > -INF or c.distance_to(MarcosMar.RELE) < 17.0 or c.distance_to(MarcosMar.RELE + Vector2(-11.0, 4.0)) < 9.0:
				continue
			var h: float = mapa._fora(c.x, c.y)
			for k in 4:
				var a := k * TAU / 4.0
				h = minf(h, mapa._fora(c.x + cos(a) * 5.0, c.y + sin(a) * 5.0))
			if h > mais_alto:
				mais_alto = h
				melhor = c
	if not melhor.is_finite():
		return
	pe = Vector3(melhor.x, mais_alto + 0.4, melhor.y)
	topo = pe + Vector3(0, ALTURA, 0)
	var o := Ruinas.Obra.new()
	o.v = mapa
	var blocos: Array[PackedVector3Array] = []
	for k2 in 5:
		blocos.append(Ruinas._cubo_talhado(1501 + k2 * 5, 1 + k2 % 2))
	o.blocos = blocos
	o.t = Transform3D.IDENTITY
	o.rng.seed = 7373
	o.corpo = StaticBody3D.new()
	o.corpo.name = "MastroRadio"
	o.corpo.collision_layer = 1
	o.corpo.collision_mask = 0
	add_child(o.corpo)
	# a sapata e os quatro pés
	o.bloco(pe + Vector3(0, -1.2, 0), Vector3(12.0, 3.2, 12.0), Basis.IDENTITY, "concreto")
	for canto: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		o.bloco(pe + Vector3(canto.x * 4.5, 0.6, canto.y * 4.5), Vector3(1.8, 1.4, 1.8), Basis.IDENTITY, "casco_claro")
	# o mastro: quinze lances de treliça que afinam; cada lance tem as quatro pernas, as travessas e as diagonais
	var lances := 15
	var alt := ALTURA / lances
	for k in lances:
		var y0 := k * alt
		var y1 := y0 + alt
		var l0 := largura(y0)
		var l1 := largura(y1)
		var fio := lerpf(0.34, 0.14, float(k) / lances)
		for canto: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var a := pe + Vector3(canto.x * l0 * 0.5, y0, canto.y * l0 * 0.5)
			var b := pe + Vector3(canto.x * l1 * 0.5, y1, canto.y * l1 * 0.5)
			o.bloco((a + b) * 0.5, Vector3(fio, fio, a.distance_to(b)), Basis.looking_at((b - a).normalized(), Vector3.RIGHT), "ferrugem" if k % 3 != 1 else "tinta_velha", false)
		for lado in 4:
			var c0 := Vector2([-1, 1, 1, -1][lado], [-1, -1, 1, 1][lado])
			var c1 := Vector2([1, 1, -1, -1][lado], [-1, 1, 1, -1][lado])
			var t0 := pe + Vector3(c0.x * l1 * 0.5, y1, c0.y * l1 * 0.5)
			var t1 := pe + Vector3(c1.x * l1 * 0.5, y1, c1.y * l1 * 0.5)
			o.bloco((t0 + t1) * 0.5, Vector3(fio * 0.8, fio * 0.8, t0.distance_to(t1)), Basis.looking_at((t1 - t0).normalized(), Vector3.UP), "ferrugem", false)
			var d0 := pe + Vector3(c0.x * l0 * 0.5, y0, c0.y * l0 * 0.5)
			o.bloco((d0 + t1) * 0.5, Vector3(fio * 0.6, fio * 0.6, d0.distance_to(t1)), Basis.looking_at((t1 - d0).normalized(), Vector3.UP), "ferrugem", false)
		# a colisão é só das quatro pernas: dá para passar por baixo do mastro e andar no patamar inteiro
		for canto: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			MarcosMar.perna_colisao(o, pe + Vector3(canto.x * l0 * 0.5, y0, canto.y * l0 * 0.5), pe + Vector3(canto.x * l1 * 0.5, y1, canto.y * l1 * 0.5), maxf(0.5, fio * 1.6))
	# o patamar de serviço, abaixo do campo quente: dá para pousar e esfriar antes do último trecho
	var lp := largura(PATAMAR) + 5.0
	o.bloco(pe + Vector3(0, PATAMAR, 0), Vector3(lp, 0.3, lp), Basis.IDENTITY, "casco")
	for lado in 4:
		var a2 := Vector3([-1, 1, 1, -1][lado] * lp * 0.5, 1.1, [-1, -1, 1, 1][lado] * lp * 0.5)
		var b2 := Vector3([1, 1, -1, -1][lado] * lp * 0.5, 1.1, [-1, 1, 1, -1][lado] * lp * 0.5)
		o.bloco(pe + Vector3(0, PATAMAR, 0) + (a2 + b2) * 0.5, Vector3(0.1, 0.1, lp), Basis.looking_at((b2 - a2).normalized(), Vector3.UP), "ferrugem", false)
	BaseVale._peca(o, "Prop_SatelliteDish", pe + Vector3(lp * 0.5 - 1.2, PATAMAR + 0.2, -lp * 0.5 + 1.2), 0.8, 2.6, 0.6, 0.4, false)
	# as antenas do meio: tambores e painéis presos ao mastro, a dois terços da altura
	for dados: Array in [[98.0, 0.0], [104.0, PI * 0.5], [110.0, PI], [116.0, PI * 1.5]]:
		var ya: float = dados[0]
		var ang: float = dados[1]
		var fora := Vector3(cos(ang), 0, sin(ang)) * (largura(ya) * 0.5 + 1.3)
		MarcosOeste._cilindro(o, Transform3D(Basis(Vector3.UP, -ang) * Basis(Vector3.BACK, PI * 0.5), pe + Vector3(0, ya, 0) + fora), 1.5, 1.5, 1.1, "casco_claro", false)
		o.bloco(pe + Vector3(0, ya, 0) + fora * 0.5, Vector3(0.16, 0.16, fora.length()), Basis.looking_at(fora.normalized(), Vector3.UP), "ferrugem", false)
	for k in 6:
		var yp := 122.0 + k * 3.2
		var ang2 := k * 1.1
		var f2 := Vector3(cos(ang2), 0, sin(ang2)) * (largura(yp) * 0.5 + 0.5)
		o.bloco(pe + Vector3(0, yp, 0) + f2, Vector3(0.5, 2.6, 0.16), Basis(Vector3.UP, -ang2 + PI * 0.5), "casco_claro", false)
	# a cabine do topo: um piso, a gaiola de ferro em volta (quatro cantos, cintas e teto de grade) e o receptor
	var lc := 5.6
	o.bloco(topo + Vector3(0, -0.15, 0), Vector3(lc, 0.3, lc), Basis.IDENTITY, "casco")
	for canto: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		o.bloco(topo + Vector3(canto.x * lc * 0.5, 1.5, canto.y * lc * 0.5), Vector3(0.14, 3.0, 0.14), Basis.IDENTITY, "ferrugem", false)
	for yg: float in [1.1, 3.0]:
		for lado in 4:
			if yg < 2.0 and lado == 2:
				continue  # a entrada: um lado sem a cinta de baixo
			var a3 := Vector3([-1, 1, 1, -1][lado] * lc * 0.5, yg, [-1, -1, 1, 1][lado] * lc * 0.5)
			var b3 := Vector3([1, 1, -1, -1][lado] * lc * 0.5, yg, [-1, 1, 1, -1][lado] * lc * 0.5)
			o.bloco(topo + (a3 + b3) * 0.5, Vector3(0.09, 0.09, lc), Basis.looking_at((b3 - a3).normalized(), Vector3.UP), "ferrugem", false)
	for kg in 5:
		o.bloco(topo + Vector3((kg - 2) * 1.3, 3.05, 0), Vector3(0.07, 0.07, lc), Basis.IDENTITY, "ferrugem", false)
	receptor = topo + Vector3(-1.5, 0.0, -1.5)
	o.bloco(receptor + Vector3(0, 0.65, 0), Vector3(1.0, 1.3, 1.6), Basis(Vector3.UP, 0.78), "casco", false)
	# a antena do topo: uma haste alta com travessas, de onde sai o campo
	o.bloco(topo + Vector3(0, 3.0 + 9.0, 0), Vector3(0.22, 18.0, 0.22), Basis.IDENTITY, "ferrugem", false)
	for kt in 5:
		o.bloco(topo + Vector3(0, 6.0 + kt * 3.0, 0), Vector3(3.2 - kt * 0.5, 0.1, 0.1), Basis(Vector3.UP, kt * 0.8), "casco_claro", false)
	# os estais: três cabos do meio do mastro até blocos de ancoragem
	for ke in 3:
		var ang3 := ke * TAU / 3.0 + 0.4
		var anc := Vector3(pe.x + cos(ang3) * 46.0, 0, pe.z + sin(ang3) * 46.0)
		anc.y = maxf(mapa._fora(anc.x, anc.z), 0.0) + 0.5
		o.bloco(anc, Vector3(2.4, 2.0, 2.4), Basis.IDENTITY, "concreto")
		var de := pe + Vector3(0, 96.0, 0)
		o.bloco((de + anc) * 0.5, Vector3(0.09, 0.09, de.distance_to(anc)), Basis.looking_at((anc - de).normalized(), Vector3.UP), "junta", false)
	o.fechar()
	# luzes: a tela do receptor, a antena acesa (de onde vem o calor) e o balizamento vermelho
	_luz(receptor + Vector3(0.36, 0.95, 0.36), Vector3(0.04, 0.5, 1.0), Color(0.3, 0.9, 0.8), 1.8 if ligado else 0.25, Basis(Vector3.UP, 0.78))
	for kt in 5:
		_luz(topo + Vector3(0, 6.0 + kt * 3.0, 0), Vector3(0.3, 0.3, 0.3), Color(1.0, 0.5, 0.15), 2.4)
	LuzesNoite.por(self, topo + Vector3(0, 22.0, 0), LuzesNoite.VERMELHO, 9.0, 1.6, 0.2)
	LuzesNoite.por(self, pe + Vector3(0, PATAMAR + 2.0, 0), LuzesNoite.VERMELHO, 5.0, 1.6, 0.7)
	LuzesNoite.por(self, topo + Vector3(0, 12.0, 0), LuzesNoite.BRASA, 14.0)
	# o campo que se vê: fagulhas mornas subindo devagar em volta do topo
	var fag := CPUParticles3D.new()
	fag.amount = 90
	fag.lifetime = 6.0
	fag.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fag.emission_sphere_radius = CAMPO * 0.7
	fag.direction = Vector3.UP
	fag.spread = 30.0
	fag.initial_velocity_min = 0.6
	fag.initial_velocity_max = 1.8
	fag.gravity = Vector3.ZERO
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.albedo_color = Color(2.0, 0.9, 0.3, 0.4)
	q.material = mf
	fag.mesh = q
	fag.position = topo
	add_child(fag)
	# a luz distante no horizonte: só existe depois de ligado o receptor, e só de noite
	var longe := LuzesNoite.por(self, SINAL, Color(0.75, 0.9, 1.0), 170.0)
	longe.set_meta("so_com", "sinal")


func _ligar() -> void:
	ligado = true
	LuzesNoite.ligadas["sinal"] = true
	if Guardado.ativo:
		var d: Dictionary = (Guardado.progresso("achados") as Dictionary).duplicate()
		d["sinal"] = true
		Guardado.por_progresso("achados", d)
	if hud:
		hud.dica = ""
		hud.avisar("O receptor captou um sinal", "de noite, procure uma luz no mar, a sudoeste")
	if memorias:
		memorias.abrir("sinal_de_fora")


func _physics_process(_delta: float) -> void:
	if armadura == null or not topo.is_finite():
		return
	var d := armadura.global_position.distance_to(topo + Vector3(0, 1.0, 0))
	no_campo = d < CAMPO and d > ABRIGO
	var fator := FATOR_DUPLO if Melhorias.tem("radiador2") else (FATOR_RADIADOR if Melhorias.tem("radiador") else 1.0)
	armadura.calor_extra = CALOR * fator if no_campo else 0.0
	if no_campo and not _avisou and hud:
		_avisou = true
		hud.aconselhar("A antena lá de cima ainda transmite e esquenta o motor. Só o radiador duplo aguenta até a cabine.", 9.0)


func _process(_delta: float) -> void:
	if armadura == null or not receptor.is_finite() or get_tree().paused:
		return
	var convite := ""
	if not ligado and armadura.estado == Armadura.Estado.CHAO and armadura.global_position.distance_to(receptor) < PERTO:
		convite = "{agir}  ligar o receptor"
	if hud:
		if convite != "":
			hud.dica = convite
			_dica_minha = convite
		elif _dica_minha != "" and hud.dica == _dica_minha:
			hud.dica = ""
			_dica_minha = ""
	if convite != "" and Input.is_action_just_pressed("agir"):
		_ligar()
