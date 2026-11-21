class_name Peixes
extends Node3D
## Cardume de peixes que nadam devagar numa lagoa, em profundidade própria, dentro de um círculo.
## Fogem quando a ameaça (o robô) passa rente à água ou quando há um respingo (`assustar`), e de vez em
## quando um peixe salta e cai de volta (sinal `saltou`, para o integrador ligar aos anéis da água).
## Um nó só, sem física nem colisão. Uso: Peixes.new(), defina mapa, ameaca, centro, raio, quantos,
## semente (e pintar, se houver), depois add_child. Peixe nenhum entra onde o fundo é raso.

const VEL_MIN := 0.4  # m/s
const VEL_MAX := 0.9
const PROF_MIN := 0.07  # m abaixo da superfície (rasos: a água do vale é pouco transparente)
const PROF_MAX := 0.2
const FUNDO_MIN := 0.45  # água com menos disso de fundo não entra
const FOLGA_FUNDO := 0.15  # o peixe fica pelo menos isso acima do fundo
const VIRADA := 2.0  # rad/s, no máximo
const COESAO := 0.35  # puxão leve para o meio do cardume
const SEPARACAO := 0.5  # m: peixes mais perto que isso se afastam
const AMEACA_ALTURA := 2.5  # m acima da superfície em que a ameaça ainda assusta
const AMEACA_DIST := 5.0  # m (horizontal) de um peixe para ele fugir da ameaça
const PONTO_DIST := 12.0  # m (horizontal) para `assustar`
const VEL_SUSTO := 3.5  # m/s
const TEMPO_SUSTO := 1.2  # s
const ESPERA_SUSTO := 2.0  # s depois de um susto em que o peixe não se assusta de novo
const SALTO_AMEACA := 15.0  # m: a ameaça mais perto que isso impede o salto
const SALTO_DURACAO := 0.7  # s
const SALTO_ALTURA := 0.5  # m acima da superfície
const SALTO_ALCANCES := [1.6, 1.1, 0.7]  # m que o salto avança (o primeiro que cair em água funda)
const GIRO_AR := 22.0  # 1/s: quão depressa o focinho acompanha o arco
const GIRO_AGUA := 6.0  # 1/s: quão depressa o peixe se endireita depois de entrar na água

signal saltou(posicao: Vector3)

## Um peixe do cardume. Classe interna: só guarda o estado de cada um.
class Peixe:
	var no: Node3D  # nó de posição e rumo; o modelo fica dentro dele
	var corpo: Node3D
	var cauda: Node3D
	var corpo_y0 := 0.0
	var cauda_giro0 := 0.0
	var pos := Vector2.ZERO  # x e z
	var dir := Vector2.RIGHT  # rumo atual, unitário em x e z
	var rumo := 0.0  # rumo que muda devagar
	var t_rumo := 3.0  # s até mudar o rumo
	var vel := 0.6  # velocidade normal
	var vel_atual := 0.6
	var prof := 0.4  # profundidade sorteada
	var prof_atual := 0.4  # profundidade usada (menor se o fundo for raso)
	var fase := 0.0  # fase da cauda e do corpo
	var fuga := 0.0  # s de susto que restam
	var de := Vector2.ZERO  # ponto de onde foge
	var espera := 0.0  # s até poder se assustar de novo
	var salto := -1.0  # 0 a 1 no salto; -1 quando está na água
	var salto_surf := 0.0
	var salto_de := Vector2.ZERO  # onde o arco começa e onde acaba (x e z)
	var salto_ate := Vector2.ZERO
	var salto_y0 := 0.0  # altura no começo e no fim (os dois debaixo d'água, na profundidade do peixe)
	var salto_y1 := 0.0
	var fora := false  # acima da água agora (para o anel ao sair e ao entrar)
	var inclina := 0.0  # rad: focinho para cima (+) ou para baixo (-)

var mapa: Ilha
var ameaca: Node3D  # o robô; pode ser null
var centro := Vector3.ZERO  # x e z do meio da lagoa
var raio := 10.0
var quantos := 9
var semente := 0
var pintar: Callable  # opcional: pintar.call(modelo) para cada peixe
var acompanha := false  # o meio da área anda (`seguir`): quem ficou para trás nada depressa até alcançar
var sustos := 0  # contador para teste (eventos de susto)
var saltos := 0  # contador para teste

var _peixes: Array[Peixe] = []
var _rng := RandomNumberGenerator.new()
var _c := Vector2.ZERO
var _t_salto := 20.0
var _pronto := false


func _ready() -> void:
	add_to_group("bichos")
	if mapa == null:
		push_error("peixes: falta o mapa")
		return
	_rng.seed = semente * 7919 + 31
	_c = Vector2(centro.x, centro.z)
	# os modelos são os do Cute Fish Pack (água doce: carpa e peixes dourados), como os cardumes de VidaAgua
	var especies := ["Koi", "Goldfish", "BlueGoldfish", "Koi", "Tetra"]
	var malhas: Array = []
	if mapa is Clareira:
		for e: String in especies:
			malhas.append(VidaAgua.malha_de(e, mapa as Clareira))
	for i in quantos:
		var p := Peixe.new()
		p.no = Node3D.new()
		p.no.name = "Peixe%d" % i
		add_child(p.no)
		var modelo := Node3D.new()
		modelo.rotation.y = PI  # o modelo olha para +Z; aqui a frente é -Z
		modelo.scale = Vector3.ONE * 1.5
		p.no.add_child(modelo)
		var par: Array = malhas[i % malhas.size()] if not malhas.is_empty() else []
		if par.is_empty():
			return
		var inst := Node3D.new()
		modelo.add_child(inst)
		var corpo_m := MeshInstance3D.new()
		corpo_m.name = "corpo"
		corpo_m.mesh = par[0]
		# uns 45 cm de comprimento (o `modelo` já aumenta 1,5 vez)
		corpo_m.scale = Vector3.ONE * (_rng.randf_range(0.36, 0.52) / float(par[1]) / 1.5)
		corpo_m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.add_child(corpo_m)
		p.corpo = corpo_m
		p.cauda = corpo_m  # o modelo é uma peça só: o balanço da cauda vira o corpo inteiro, de leve
		p.corpo_y0 = corpo_m.position.y
		p.cauda_giro0 = corpo_m.rotation.y
		p.prof = _rng.randf_range(PROF_MIN, PROF_MAX)
		p.prof_atual = p.prof
		p.vel = _rng.randf_range(VEL_MIN, VEL_MAX)
		p.vel_atual = p.vel
		p.rumo = _rng.randf() * TAU
		p.dir = Vector2.from_angle(p.rumo)
		p.t_rumo = _rng.randf_range(2.0, 5.0)
		p.fase = _rng.randf() * TAU
		p.pos = _ponto_aleatorio()
		_peixes.append(p)
		_posicionar(p)
	_t_salto = _rng.randf_range(20.0, 50.0)
	_pronto = true


func _process(delta: float) -> void:
	if not _pronto:
		return
	var dt := minf(delta, 0.05)
	var tem_amea := ameaca != null and ameaca.is_inside_tree()
	var a := ameaca.global_position if tem_amea else Vector3.ZERO
	var a_xz := Vector2(a.x, a.z)

	# susto pela ameaça: dentro d'água ou até 2,5 m acima dela, e perto de um peixe
	if tem_amea:
		var sup := mapa.agua(a.x, a.z)
		if sup > -INF and a.y - sup < AMEACA_ALTURA:
			var algum := false
			for p in _peixes:
				if p.salto < 0.0 and p.pos.distance_to(a_xz) < AMEACA_DIST and (p.fuga > 0.0 or p.espera <= 0.0):
					if _susto(p, a_xz):
						algum = true
			if algum:
				sustos += 1

	_t_salto -= dt
	if _t_salto <= 0.0:
		_tentar_salto(tem_amea, a_xz)

	# meio do cardume (peixes que não estão saltando)
	var soma := Vector2.ZERO
	var n := 0
	for p in _peixes:
		if p.salto < 0.0:
			soma += p.pos
			n += 1
	var cm: Vector2 = soma / n if n > 0 else _c

	for p in _peixes:
		if p.espera > 0.0:
			p.espera -= dt
		if p.salto >= 0.0:
			_saltando(p, dt)
		else:
			_nadar(p, dt, cm)
		_animar(p, dt)


## Sorteia um peixe que não esteja saltando nem assustado e manda saltar (se a ameaça estiver longe).
## O salto é um arco para a frente: precisa de água funda onde ele cai e no meio do caminho.
func _tentar_salto(tem_amea: bool, a_xz: Vector2) -> void:
	var livres: Array[Peixe] = []
	for p in _peixes:
		if p.salto < 0.0 and p.fuga <= 0.0 and (not tem_amea or p.pos.distance_to(a_xz) >= SALTO_AMEACA):
			livres.append(p)
	while not livres.is_empty():
		var k := _rng.randi() % livres.size()
		var p := livres[k]
		livres.remove_at(k)
		for alcance: float in SALTO_ALCANCES:
			var ate := p.pos + p.dir * alcance
			if not _valido(ate) or _fundo(p.pos.lerp(ate, 0.5)) < FUNDO_MIN:
				continue
			p.salto = 0.0
			p.salto_de = p.pos
			p.salto_ate = ate
			p.salto_surf = mapa.agua(p.pos.x, p.pos.y)
			p.salto_y0 = p.no.global_position.y
			p.salto_y1 = mapa.agua(ate.x, ate.y) - minf(p.prof, _fundo(ate) - FOLGA_FUNDO)
			p.fora = false
			saltos += 1
			_t_salto = _rng.randf_range(20.0, 50.0)
			return
	_t_salto = 2.0  # ninguém pode saltar agora: tenta de novo daqui a pouco


## O arco do salto: avança de `salto_de` a `salto_ate`, sobe SALTO_ALTURA acima da água e volta à mesma
## profundidade (sem tranco). O focinho acompanha o arco: para cima ao sair, reto no alto, para baixo ao entrar.
func _saltando(p: Peixe, dt: float) -> void:
	p.salto += dt / SALTO_DURACAO
	var t := clampf(p.salto, 0.0, 1.0)
	var meio := lerpf(p.salto_y0, p.salto_y1, 0.5)
	var alto := SALTO_ALTURA + (p.salto_surf - meio)  # no meio do arco fica SALTO_ALTURA acima da água
	var y := lerpf(p.salto_y0, p.salto_y1, t) + 4.0 * t * (1.0 - t) * alto
	p.pos = p.salto_de.lerp(p.salto_ate, t)
	# subida e avanço por unidade de t: o ângulo do arco
	var sobe := (p.salto_y1 - p.salto_y0) + 4.0 * (1.0 - 2.0 * t) * alto
	var avanca := maxf(p.salto_de.distance_to(p.salto_ate), 0.01)
	p.inclina = lerpf(p.inclina, atan2(sobe, avanca), 1.0 - exp(-dt * GIRO_AR))
	p.vel_atual = 1.6  # a cauda bate depressa no ar
	p.no.global_position = Vector3(p.pos.x, y, p.pos.y)
	p.no.rotation = Vector3(p.inclina, _yaw(p), 0.0)
	var s := mapa.agua(p.pos.x, p.pos.y)
	if (y > s) != p.fora:
		p.fora = y > s
		saltou.emit(Vector3(p.pos.x, s, p.pos.y))  # um anel onde sai e outro onde entra
	if t >= 1.0:
		p.salto = -1.0
		if p.fora:
			p.fora = false
			saltou.emit(Vector3(p.pos.x, s, p.pos.y))
		_posicionar(p)


func _nadar(p: Peixe, dt: float, cm: Vector2) -> void:
	if p.fuga > 0.0:
		p.fuga -= dt
	var fugindo := p.fuga > 0.0
	var v := p.vel
	var alvo := Vector2.ZERO
	if fugindo:
		v = VEL_SUSTO
		alvo = p.pos - p.de
		if alvo.length() < 0.01:
			alvo = p.dir
	else:
		p.t_rumo -= dt
		if p.t_rumo <= 0.0:
			p.rumo += _rng.randf_range(-1.2, 1.2)
			p.t_rumo = _rng.randf_range(2.0, 5.0)
		alvo = Vector2.from_angle(p.rumo)
		var para_cm := cm - p.pos
		if para_cm.length() > 0.5:
			alvo += para_cm.normalized() * COESAO
		for q in _peixes:
			if q == p or q.salto >= 0.0:
				continue
			var d := p.pos - q.pos
			var dl := d.length()
			if dl > 0.001 and dl < SEPARACAO:
				alvo += d / dl * (SEPARACAO - dl) / SEPARACAO * 2.0
		# perto da borda do círculo, volta para o meio
		var do_c := p.pos - _c
		var r := do_c.length() / raio
		if r > 0.8:
			alvo += -do_c.normalized() * (1.0 + 2.0 * (r - 0.8) / 0.2)
		# raso à frente (ou fora do círculo): desvia para o meio
		var f := alvo.normalized() if alvo.length() > 0.001 else p.dir
		var frente := p.pos + f * 1.2
		if _fundo(frente) < FUNDO_MIN + 0.2 or (frente - _c).length() > raio:
			alvo += (_c - p.pos).normalized() * 2.0

	# o cardume que acompanha: fora do círculo, o peixe vai direto para o meio, tanto mais depressa quanto mais longe
	var atrasado := false
	if acompanha and not fugindo:
		var falta := (_c - p.pos).length() - raio
		if falta > 0.0:
			atrasado = true
			alvo = (_c - p.pos).normalized()
			v = clampf(1.0 + falta * 1.6, p.vel, 8.0)
	if alvo.length() > 0.001:
		var ang := p.dir.angle()
		var vira := VIRADA * (4.0 if atrasado else 1.0)
		ang += clampf(angle_difference(ang, alvo.angle()), -vira * dt, vira * dt)
		p.dir = Vector2.from_angle(ang)
	p.vel_atual = v
	p.inclina = lerpf(p.inclina, 0.0, 1.0 - exp(-dt * GIRO_AGUA))  # depois do salto, endireita debaixo d'água
	var nova := p.pos + p.dir * v * dt
	if _valido(nova) or (atrasado and _fundo(nova) >= FUNDO_MIN):
		p.pos = nova
	else:
		# não cabe ali (raso ou fora do círculo): fica e vira para o meio
		var ir := _c - p.pos
		if ir.length() > 0.01:
			p.dir = p.dir.lerp(ir.normalized(), 0.3).normalized()
	_posicionar(p)


## Põe o nó do peixe sobre a água, na profundidade dele (menos se o fundo for raso) e de frente para o rumo.
func _posicionar(p: Peixe) -> void:
	var fundo := _fundo(p.pos)
	if fundo < FUNDO_MIN:
		return
	var s := mapa.agua(p.pos.x, p.pos.y)
	p.prof_atual = minf(p.prof, fundo - FOLGA_FUNDO)
	p.no.global_position = Vector3(p.pos.x, s - p.prof_atual, p.pos.y)
	p.no.rotation = Vector3(p.inclina, _yaw(p), 0.0)


func _animar(p: Peixe, dt: float) -> void:
	p.fase += dt * (4.0 + 5.0 * p.vel_atual)
	p.cauda.rotation.y = p.cauda_giro0 + 0.16 * sin(p.fase)
	if p.corpo != null:
		p.corpo.position.y = p.corpo_y0 + 0.012 * sin(p.fase * 0.5)


## Dispara o peixe para longe de `de` por TEMPO_SUSTO. Devolve true se foi um susto novo.
func _susto(p: Peixe, de: Vector2) -> bool:
	p.de = de
	if p.fuga > 0.0:
		return false
	var fuga := p.pos - de
	if fuga.length() < 0.01:
		fuga = p.dir
	p.dir = fuga.normalized()  # arranca de uma vez, na direção da fuga
	p.fuga = TEMPO_SUSTO
	p.espera = ESPERA_SUSTO
	return true


## Peixes a menos de 12 m (horizontal) do ponto disparam para longe dele.
func assustar(ponto: Vector3) -> void:
	var q := Vector2(ponto.x, ponto.z)
	var algum := false
	for p in _peixes:
		if p.salto < 0.0 and p.pos.distance_to(q) < PONTO_DIST:
			if _susto(p, q):
				algum = true
	if algum:
		sustos += 1


## Liga o sinal `respingou` de um efeito (EfeitosAgua) a um susto na posição do respingo.
func ligar_respingo(fx: Node) -> void:
	if fx != null and fx.has_signal("respingou") and not fx.is_connected("respingou", _ao_respingo):
		fx.connect("respingou", _ao_respingo)


func _ao_respingo(posicao: Vector3, _forca: float) -> void:
	assustar(posicao)


## Posições dos peixes no mundo (para teste).
func posicoes() -> Array[Vector3]:
	var r: Array[Vector3] = []
	for p in _peixes:
		r.append(p.no.global_position)
	return r


func _ponto_aleatorio() -> Vector2:
	for _t in 60:
		var v := _c + Vector2.from_angle(_rng.randf() * TAU) * (raio * 0.8 * sqrt(_rng.randf()))
		if _valido(v):
			return v
	return _c


## Muda o meio e o raio da área do cardume (o cardume que acompanha o robô no poço da Cachoeira).
func seguir(meio: Vector3, novo_raio: float) -> void:
	centro = Vector3(meio.x, 0, meio.z)
	_c = Vector2(meio.x, meio.z)
	raio = novo_raio
	acompanha = true


## Fundo da água em (x, z): profundidade em metros, ou -INF onde não há água.
func _fundo(v: Vector2) -> float:
	var s := mapa.agua(v.x, v.y)
	if s == -INF:
		return -INF
	return s - mapa.altura(v.x, v.y)


func _valido(v: Vector2) -> bool:
	return (v - _c).length() <= raio and _fundo(v) >= FUNDO_MIN


func _yaw(p: Peixe) -> float:
	return atan2(-p.dir.x, -p.dir.y)  # a frente do nó é -Z
