class_name Armadura
extends CharacterBody3D
## A armadura de 2,6 m: anda, corre, pula, dá pulo duplo, esquiva, decola, voa, dá arrancada, plana,
## mergulha, paira mirando, solta e pousa.
## O voo é uma física de planador com motor: a gravidade age sempre, a velocidade gira para o nariz
## (sustentação), o motor empurra até a velocidade alvo e o arrasto segura o mergulho perto de 70 m/s.
## Os números ficam em Ajustes.

enum Estado { CHAO, AR, DECOLAGEM, VOO, PLANAR, POUSO, PAIRAR }
const NOMES := ["chão", "no ar", "decolagem", "voo", "planando", "pouso", "pairando"]

signal estado_mudou(novo: int)
signal superaqueceu
signal religou
signal entrou_pane
signal saiu_pane

## Porte do corpo: 1,0 é a armadura de 2,6 m; o robô pequeno do vale usa 0,48 (1,2 m). O mapa define
## antes de criar a armadura. Mexe na cápsula de colisão e a câmera lê para chegar mais perto.
static var porte := 1.0
## Chuva (0 a 1), definida pelo ciclo do dia: ajuda a esfriar o motor.
static var vel_chao := 1.0  # robô pequeno anda e corre mais devagar (a passada é curta)
static var chuva := 0.0

var estado := Estado.CHAO
var calor := 0.0
var superaquecido := false
var arrancada := false  # efetiva neste quadro (para HUD, visual e câmera)
var na_agua := false  # esfriando por rasante ou dentro d'água
var dir_voo := Vector3.FORWARD  # para onde o nariz aponta no voo
var tremor := 0.0  # a câmera lê e treme
var giro_lateral := 0.0  # rad/s do nariz no plano (para inclinar o corpo e a câmera)
var mirando := false  # L2 no chão ou pairando
var esquivando := 0.0  # tempo que falta da esquiva (o visual e a câmera leem)
var esquiva_dir := Vector3.ZERO
var impulso := 0.0  # brilho rápido dos propulsores (pulo duplo, esquiva)
var tem_marcador := false
var marcador := Vector3.ZERO
var alvo_mira := Vector3.ZERO  # onde a mira bate (para a distância na tela)
var alvo_mira_ok := false
var pouso_forca := 0.0  # 0 pouso comum, 0,5 queda com estilo leve, 1 pouso de herói (o visual e os efeitos leem)
var clarao_tiro := 0.0  # brilho rápido do jato da mão direita a cada disparo
var atirando := 0.0  # tempo desde o último tiro (o visual aponta o braço mesmo sem mirar)
var _pairar_travado := false  # desligou o voo parado com o L2 ainda apertado: só volta a pairar apertando de novo
var _solto := false  # motor desligado ou travado no voo: cai pesado até pousar ou religar
var golpes := 0  # quantos golpes de máquina levou (testes)
var avaria := 0  # acertos acumulados; saram com o tempo
var em_pane := false  # desligado por excesso de acertos (o visual, a tela e as máquinas leem)
var graca_pane := 0.0  # depois de religar, as máquinas não o enxergam por este tempo
var panes := 0
var _avaria_tempo := 0.0
var _pane_t := 0.0
var _pane_volta := Vector3.INF  # para onde o robô volta no meio da pane (pane no mar)
var queda_altura := 0.0  # metros caídos no último pouso

var camera: CameraVoo
var ilha: Ilha
var visual: ArmaduraVisual
var ponto_inicio := Vector3.ZERO
var yaw_inicio := 0.0

var _tempo_estado := 0.0
var _tempo_super := 0.0
var _segurando := 0.0
var _pulo_vivo := false
var _correr_alt := false
var _arrancada_alt := false
var _fora_chao := 0.0
var _pouso_tempo := 0.0
var _yaw_ultimo := 0.0
var _duplo_usado := false
var _origem_chao := false  # o pulo segurado veio do chão (decola) ou do ar (liga o voo)
var _esquiva_espera := 0.0
var _esquiva_ar_usada := false
var _graca := 0.0  # tempo restante em que o voo recém-decolado não desce
var _religa_rapido := false  # caiu por superaquecer e já esfriou: X religa na hora
var _pico_y := 0.0  # ponto mais alto desde que saiu do chão ou do voo (mede a queda)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.5
	var forma := CapsuleShape3D.new()
	forma.radius = maxf(0.26, 0.5 * porte)
	forma.height = 2.5 * porte
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position = Vector3(0, 1.28 * porte, 0)
	add_child(cs)
	visual = ArmaduraVisual.new()
	visual.name = "Visual"
	add_child(visual)


func em_voo() -> bool:
	return estado == Estado.VOO or estado == Estado.PLANAR or estado == Estado.DECOLAGEM


func motor_ligado() -> bool:
	return estado == Estado.VOO or estado == Estado.DECOLAGEM or estado == Estado.PAIRAR


func mirando_agora() -> bool:
	return mirando and (estado == Estado.CHAO or estado == Estado.PAIRAR)


## Chegando ao chão (voando baixo e descendo, ou caindo): o visual arma as pernas para o pouso.
func chegando_ao_chao() -> bool:
	if not (em_voo() or estado == Estado.AR or estado == Estado.PAIRAR):
		return false
	return velocity.y < -1.0 and altura_do_chao() < 1.2 + absf(velocity.y) * 0.22


func nome_estado() -> String:
	return NOMES[estado]


func altura_do_chao() -> float:
	return global_position.y - ilha.altura(global_position.x, global_position.z)


## Para os testes e as fotos: põe a armadura num lugar, num estado e com uma velocidade.
## Golpe de uma máquina: empurra e esquenta. Com Ajustes.PANE_GOLPES acertos seguidos o robô entra em pane:
## desliga, o dia avança e ele religa no mesmo lugar (não há vida nem morte). Os acertos saram com o tempo.
func levar_golpe(direcao: Vector3, forca: float) -> void:
	if em_pane or graca_pane > 0.0:
		return
	velocity += direcao.normalized() * forca + Vector3(0, forca * 0.35, 0)
	calor = minf(100.0, calor + Ajustes.GOLPE_CALOR)
	tremor = maxf(tremor, 0.8)
	golpes += 1
	avaria += 1
	_avaria_tempo = Ajustes.AVARIA_SARA
	if avaria >= Ajustes.PANE_GOLPES:
		em_pane = true
		_pane_t = 0.0
		if estado != Estado.CHAO:
			_mudar(Estado.AR)
		entrou_pane.emit()


## Pane sem golpe (longe demais no mar): desliga e, com a tela já escura, volta para `volta` (a praia).
func pane_forcada(volta: Vector3) -> void:
	if em_pane:
		return
	em_pane = true
	_pane_t = 0.0
	_pane_volta = volta
	if estado != Estado.CHAO:
		_mudar(Estado.AR)
	entrou_pane.emit()


## Laço do robô desligado: só cai e espera. Devolve true enquanto a pane durar.
func _pane(delta: float) -> bool:
	graca_pane = maxf(0.0, graca_pane - delta)
	if avaria > 0 and not em_pane:
		_avaria_tempo -= delta
		if _avaria_tempo <= 0.0:
			avaria -= 1
			_avaria_tempo = Ajustes.AVARIA_SARA
	if not em_pane:
		return false
	_pane_t += delta
	if _pane_volta.is_finite() and _pane_t >= 2.3:
		# a tela já escureceu: o robô reaparece na praia
		global_position = _pane_volta
		velocity = Vector3.ZERO
		_pane_volta = Vector3.INF
		_pico_y = global_position.y
		_mudar(Estado.AR)
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	velocity.y -= Ajustes.GRAVIDADE * delta
	move_and_slide()
	if is_on_floor() and estado != Estado.CHAO:
		_mudar(Estado.CHAO)
	if _pane_t >= Ajustes.PANE_TEMPO and is_on_floor() and not _pane_volta.is_finite():
		em_pane = false
		avaria = 0
		calor = 0.0
		superaquecido = false
		graca_pane = Ajustes.PANE_GRACA
		panes += 1
		saiu_pane.emit()
	return true


func teleportar(pos: Vector3, novo: int, vel := Vector3.ZERO) -> void:
	global_position = pos
	velocity = vel
	if vel.length() > 0.5:
		dir_voo = vel.normalized()
	elif camera:
		dir_voo = camera.mira()
	_mudar(novo)
	_pulo_vivo = false
	_arrancada_alt = false
	_correr_alt = false
	esquivando = 0.0
	if ilha:
		ilha.atualizar_colisao_arvores(pos, true)


func recomecar() -> void:
	em_pane = false
	avaria = 0
	calor = 0.0
	superaquecido = false
	teleportar(ponto_inicio, Estado.CHAO)
	if camera:
		camera.yaw = yaw_inicio
		camera.pitch = -0.12


func _mudar(novo: int) -> void:
	if novo == estado:
		return
	estado = novo
	_tempo_estado = 0.0
	floor_snap_length = 0.5 if (novo == Estado.CHAO or novo == Estado.POUSO) else 0.0
	if novo != Estado.VOO:
		_arrancada_alt = false
		if novo != Estado.DECOLAGEM:
			_graca = 0.0
	if novo == Estado.CHAO or novo == Estado.VOO or novo == Estado.PAIRAR:
		_religa_rapido = false
		_duplo_usado = false
		_esquiva_ar_usada = false
	estado_mudou.emit(novo)


func _physics_process(delta: float) -> void:
	_tempo_estado += delta
	if _pane(delta):
		return
	var mira := camera.mira() if camera else -global_basis.z
	var mov := Input.get_vector("esquerda", "direita", "frente", "tras")
	mirando = Input.is_action_pressed("mirar")
	_esquiva_espera = maxf(0.0, _esquiva_espera - delta)
	impulso = maxf(0.0, impulso - delta * 3.0)
	atirando = maxf(0.0, atirando - delta)
	clarao_tiro = maxf(0.0, clarao_tiro - delta * 5.0)
	if ilha:
		ilha.atualizar_colisao_arvores(global_position)
	match estado:
		Estado.CHAO, Estado.POUSO:
			_chao(delta, mov)
		Estado.AR:
			_ar(delta, mov, mira)
		Estado.DECOLAGEM:
			_decolagem(delta, mira)
		Estado.VOO, Estado.PLANAR:
			_voo(delta, mov, mira)
		Estado.PAIRAR:
			_pairar(delta, mov, mira)
	_esquiva_aplicar(delta)
	var antes := velocity
	move_and_slide()
	_depois_de_mover(antes)
	_agua_e_calor(delta)
	tremor = maxf(0.0, tremor - delta * 1.5)
	# giro do nariz no plano, para inclinar nas curvas
	var yaw_agora := atan2(-dir_voo.x, -dir_voo.z)
	giro_lateral = lerpf(giro_lateral, wrapf(yaw_agora - _yaw_ultimo, -PI, PI) / delta, 1.0 - exp(-6.0 * delta))
	_yaw_ultimo = yaw_agora
	if global_position.y < -40.0 or Vector2(global_position.x, global_position.z).length() > 3000.0:
		recomecar()
	_mira_e_marcador()


func _plano_camera() -> Basis:
	return camera.basis_plano() if camera else Basis.IDENTITY


# ---------------------------------------------------------------- chão e pulo

func _chao(delta: float, mov: Vector2) -> void:
	if Input.is_action_just_pressed("correr_alternar"):
		_correr_alt = not _correr_alt
	if mov.length() < 0.15:
		_correr_alt = false
	var correr := Input.is_action_pressed("correr") or _correr_alt
	var dir := _plano_camera() * Vector3(mov.x, 0.0, mov.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var vmax := (Ajustes.CORRER if correr else Ajustes.ANDAR) * vel_chao
	if mirando:
		vmax = Ajustes.ANDAR_MIRANDO * vel_chao
	if na_agua:
		vmax *= 0.5
	if estado == Estado.POUSO:
		vmax *= 0.25
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if esquivando > 0.0:
		hv *= exp(-Ajustes.ESQUIVA_FREIO * delta)  # no arranque de jato o robô só desliza e perde força
	else:
		# ganhar velocidade leva um instante; parar e inverter é mais firme
		var acelera := dir.length() > 0.1 and hv.dot(dir) >= -0.1 and hv.length() <= vmax + 0.5
		hv = hv.move_toward(dir * vmax, (Ajustes.ACEL_CHAO if acelera else Ajustes.FREIO_CHAO) * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y -= Ajustes.GRAVIDADE * delta
	if estado == Estado.POUSO and _tempo_estado >= _pouso_tempo:
		_mudar(Estado.CHAO)
	if estado == Estado.CHAO and Input.is_action_just_pressed("pular"):
		velocity.y = Ajustes.PULO
		_pulo_vivo = true
		_origem_chao = true
		_segurando = 0.0
		_mudar(Estado.AR)
	elif estado == Estado.CHAO and Input.is_action_just_pressed("soltar"):
		_tentar_esquiva(mov)


func _ar(delta: float, mov: Vector2, mira: Vector3) -> void:
	velocity.y -= Ajustes.GRAVIDADE * (Ajustes.QUEDA_PESADA if _solto else 1.0) * delta
	var dir := _plano_camera() * Vector3(mov.x, 0.0, mov.y)
	var lim := Ajustes.CORRER * vel_chao
	var alvo := dir.limit_length(1.0) * lim
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() > lim:
		# sem motor não plana: o ar tira a velocidade de lado que sobrou do voo ou do arranque
		hv = hv.move_toward(hv.normalized() * lim, Ajustes.ARRASTO_QUEDA * (1.6 if _solto else 1.0) * delta)
	if alvo.length() > 0.1 or hv.length() < lim:
		hv = hv.move_toward(alvo, Ajustes.ACEL_AR * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not mirando:
		_pairar_travado = false
	if mirando and not superaquecido and not _pairar_travado:
		_solto = false
		_mudar(Estado.PAIRAR)
		return
	if _pulo_vivo:
		# segurando o pulo: do chão vira decolagem; do ar (pulo duplo) liga o voo
		if Input.is_action_pressed("pular"):
			_segurando += delta
			var limite := Ajustes.SEGURAR_DECOLAGEM if _origem_chao else Ajustes.SEGURAR_VOO
			if _segurando >= limite and not superaquecido:
				if _origem_chao:
					_decolar()
				else:
					_ligar_voo(mira)
		else:
			_pulo_vivo = false
	elif Input.is_action_just_pressed("pular") and not superaquecido and _religa_rapido:
		_religa_rapido = false
		_ligar_voo(mira)  # caindo com o motor recém-esfriado: um toque no X recupera o voo
	elif Input.is_action_just_pressed("pular") and not superaquecido:
		if not _duplo_usado:
			_duplo_usado = true
			velocity.y = maxf(velocity.y, Ajustes.PULO_DUPLO)
			calor = minf(100.0, calor + Ajustes.CALOR_PULO_DUPLO)
			impulso = 1.0
		_pulo_vivo = true
		_origem_chao = false
		_segurando = 0.0
	if Input.is_action_just_pressed("soltar"):
		_tentar_esquiva(mov)


func _decolar() -> void:
	_pulo_vivo = false
	velocity.y = Ajustes.DECOLAGEM_IMPULSO
	calor = minf(100.0, calor + Ajustes.CALOR_DECOLAGEM)
	tremor = maxf(tremor, 0.35)
	_mudar(Estado.DECOLAGEM)


func _decolagem(delta: float, mira: Vector3) -> void:
	velocity.y -= Ajustes.G_VOO * 0.55 * delta
	var plano := Vector3(mira.x, 0.0, mira.z).normalized()
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(plano * 6.0, 8.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	dir_voo = (plano + Vector3.UP * 1.2).normalized()
	if _tempo_estado >= Ajustes.DECOLAGEM_TEMPO:
		_graca = Ajustes.DECOLAGEM_GRACA
		_ligar_voo(mira)


func _ligar_voo(mira: Vector3) -> void:
	_solto = false
	if superaquecido:
		return
	if estado != Estado.DECOLAGEM:
		dir_voo = velocity.normalized() if velocity.length() > 6.0 else mira
		if velocity.length() < 8.0:
			velocity.y = maxf(velocity.y, Ajustes.IGNICAO_IMPULSO)
	_mudar(Estado.VOO)


# ---------------------------------------------------------------- voo e planar

static func girar_para(a: Vector3, b: Vector3, max_ang: float) -> Vector3:
	var ang := a.angle_to(b)
	if ang < 0.0001:
		return b.normalized()
	return a.slerp(b, minf(1.0, max_ang / ang)).normalized()


func _voo(delta: float, mov: Vector2, mira: Vector3) -> void:
	# recém-decolado: mesmo com a câmera olhando para baixo, o nariz fica um pouco acima do horizonte,
	# para o voo não bater no chão logo de saída; a trava solta aos poucos
	if _graca > 0.0:
		_graca -= delta
		var piso := 0.12 * clampf(_graca / 0.5, 0.0, 1.0)
		if mira.y < piso:
			mira = Vector3(mira.x, piso, mira.z).normalized()
	var v := velocity.length()
	var taxa := lerpf(Ajustes.GIRO_LENTO, Ajustes.GIRO_RAPIDO, clampf(v / 70.0, 0.0, 1.0))
	dir_voo = girar_para(dir_voo, mira, taxa * delta)
	var motor := estado == Estado.VOO
	if motor and Input.is_action_just_pressed("correr_alternar"):
		_arrancada_alt = not _arrancada_alt
	arrancada = motor and (Input.is_action_pressed("correr") or _arrancada_alt)
	# gravidade
	velocity += Vector3.DOWN * Ajustes.G_VOO * delta
	# motor: empurra até a velocidade alvo, perdendo força acima do teto
	if motor:
		var alvo := Ajustes.ARRANCADA_ALVO if arrancada else Ajustes.VOO_ALVO
		if mov.y > 0.5:
			alvo = Ajustes.FREIO_ALVO
		var ao_longo := velocity.dot(dir_voo)
		var maximo := Ajustes.EMPUXO_ARRANCADA if arrancada else Ajustes.EMPUXO_MAX
		var emp := clampf((alvo - ao_longo) * Ajustes.EMPUXO_GANHO, 0.0, maximo)
		emp *= 1.0 - smoothstep(Ajustes.TETO, Ajustes.TETO + Ajustes.TETO_FAIXA, global_position.y)
		velocity += dir_voo * emp * delta
	# sustentação: a velocidade gira para o nariz (fraca devagar)
	var vlen := velocity.length()
	var sust := Ajustes.SUSTENTACAO * clampf(vlen / 20.0, 0.12, 1.0)
	velocity = velocity.lerp(dir_voo * vlen, clampf(sust * delta, 0.0, 1.0))
	# arrasto
	velocity -= velocity * Ajustes.ARRASTO * vlen * delta
	# deslize lateral com o analógico esquerdo
	var lado := dir_voo.cross(Vector3.UP)
	if lado.length() > 0.1:
		velocity += lado.normalized() * mov.x * Ajustes.LATERAL * delta
	# planando devagar demais, o nariz cai
	if estado == Estado.PLANAR and vlen < Ajustes.ESTOL:
		dir_voo = girar_para(dir_voo, (dir_voo + Vector3.DOWN).normalized(), 1.2 * delta)
	# botões
	if Input.is_action_just_pressed("pular"):
		if estado == Estado.VOO:
			_mudar(Estado.PLANAR)
		elif not superaquecido:
			_mudar(Estado.VOO)
	if Input.is_action_just_pressed("soltar"):
		# motor desligado: robô pesado, perde o embalo e despenca
		velocity.x *= Ajustes.SOLTAR_CORTE
		velocity.z *= Ajustes.SOLTAR_CORTE
		velocity.y = minf(velocity.y, 0.0) - 2.0
		_solto = true
		_pulo_vivo = false
		tremor = maxf(tremor, 0.25)
		_mudar(Estado.AR)
	elif Input.is_action_just_pressed("mirar") and not superaquecido:
		_mudar(Estado.PAIRAR)  # no voo, apertar o L2 freia e paira (segurado de antes não conta)


# ---------------------------------------------------------------- pairar, esquiva e mira

func _pairar(delta: float, mov: Vector2, mira: Vector3) -> void:
	var dir := _plano_camera() * Vector3(mov.x, 0.0, mov.y)
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(dir.limit_length(1.0) * Ajustes.PAIRAR_VEL, Ajustes.PAIRAR_FREIO * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = move_toward(velocity.y, sin(_tempo_estado * 2.2) * 0.25, Ajustes.PAIRAR_FREIO * delta)
	dir_voo = Vector3(mira.x, 0.0, mira.z).normalized() if Vector2(mira.x, mira.z).length() > 0.05 else dir_voo
	# voo parado: fica assim mesmo soltando o L2. X volta a voar para a frente; O desliga o propulsor.
	if Input.is_action_just_pressed("pular"):
		_ligar_voo(mira)
	elif Input.is_action_just_pressed("soltar"):
		_solto = true
		_pulo_vivo = false
		_pairar_travado = true
		velocity.y = minf(velocity.y, 0.0) - 1.0
		_mudar(Estado.AR)


func _tentar_esquiva(mov: Vector2) -> void:
	if _esquiva_espera > 0.0 or superaquecido:
		return
	if estado == Estado.AR:
		if _esquiva_ar_usada:
			return
		_esquiva_ar_usada = true
	var dir := _plano_camera() * Vector3(mov.x, 0.0, mov.y)
	if dir.length() < 0.2:
		dir = _plano_camera() * Vector3(0.0, 0.0, 1.0)  # sem direção: para trás
	esquiva_dir = dir.normalized()
	esquivando = Ajustes.ESQUIVA_TEMPO
	# arranque de jato: um empurrão só, que o chão e o ar vão freando (nada de velocidade forçada)
	var v0 := esquiva_dir * Ajustes.ESQUIVA_VEL * vel_chao
	velocity.x = v0.x
	velocity.z = v0.z
	velocity.y = maxf(velocity.y, Ajustes.ESQUIVA_SALTO if estado == Estado.CHAO else 1.5)
	tremor = maxf(tremor, 0.2)
	_esquiva_espera = Ajustes.ESQUIVA_ESPERA
	calor = minf(100.0, calor + Ajustes.CALOR_ESQUIVA)
	impulso = 1.0


func _esquiva_aplicar(delta: float) -> void:
	if esquivando <= 0.0:
		return
	esquivando = maxf(0.0, esquivando - delta)


## Onde a mira bate, e o marcador (R2 mirando marca; mirando para o céu apaga; chegando perto some).
func _mira_e_marcador() -> void:
	alvo_mira_ok = false
	if camera and mirando_agora():
		var de := camera.global_position
		var para := de + camera.mira() * Ajustes.ALCANCE_MIRA
		var q := PhysicsRayQueryParameters3D.create(de, para, 1 | 2, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			alvo_mira = hit["position"]
			alvo_mira_ok = true
		if Input.is_action_just_pressed("marcar"):
			tem_marcador = alvo_mira_ok
			marcador = alvo_mira
	if tem_marcador and global_position.distance_to(marcador) < 6.0 and not mirando:
		tem_marcador = false


func _depois_de_mover(antes: Vector3) -> void:
	# batidas de lado (árvore, encosta íngreme)
	if em_voo() or estado == Estado.AR:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var n := col.get_normal()
			if n.y > cos(floor_max_angle):
				continue
			var impacto := -antes.dot(n)
			# de frente a mais de 22 m/s, ou de través em alta velocidade
			if (impacto > 22.0 or (impacto > 14.0 and antes.length() > 28.0)) and em_voo():
				velocity = velocity * 0.3 + n * 4.0
				tremor = maxf(tremor, 0.8)
				_mudar(Estado.AR)
				break
			elif impacto > 2.0:
				velocity *= 1.0 - clampf(impacto / 70.0, 0.0, 0.3)
	# pouso
	if is_on_floor():
		_fora_chao = 0.0
		_solto = false
		if estado == Estado.AR or em_voo() or estado == Estado.PAIRAR:
			# a força do pouso segue a altura da queda: de alto, pouso de herói; de baixo, com estilo leve
			queda_altura = maxf(0.0, _pico_y - global_position.y)
			var forte := queda_altura > Ajustes.QUEDA_HEROI or (em_voo() and antes.length() > 38.0)
			var leve := queda_altura > Ajustes.QUEDA_LEVE and estado == Estado.AR
			# todo pouso de voo, de voo parado ou de queda maior que um pulo tem a sua animação
			var toque := em_voo() or estado == Estado.PAIRAR or queda_altura > Ajustes.QUEDA_TOQUE
			if forte or leve:
				pouso_forca = 1.0 if forte else 0.5
				tremor = maxf(tremor, 0.9 if forte else 0.3)
				_pouso_tempo = 0.95 if forte else 0.4
				velocity.x *= 0.2 if forte else 0.5
				velocity.z *= 0.2 if forte else 0.5
				_mudar(Estado.POUSO)
			elif toque:
				pouso_forca = 0.25
				tremor = maxf(tremor, 0.12)
				_pouso_tempo = 0.24
				var hvt := Vector3(velocity.x, 0.0, velocity.z).limit_length(Ajustes.CORRER * vel_chao * 1.4)
				velocity.x = hvt.x * 0.8
				velocity.z = hvt.z * 0.8
				if em_voo():
					_correr_alt = true
				_mudar(Estado.POUSO)
			else:
				pouso_forca = 0.0
				var hv := Vector3(velocity.x, 0.0, velocity.z).limit_length(Ajustes.CORRER * vel_chao * 1.4)
				velocity.x = hv.x
				velocity.z = hv.z
				if em_voo():
					_correr_alt = true
				_pouso_tempo = 0.0
				_mudar(Estado.CHAO)
	elif estado == Estado.CHAO:
		_fora_chao += get_physics_process_delta_time()
		if _fora_chao > 0.15:
			_pulo_vivo = false
			_mudar(Estado.AR)


# ---------------------------------------------------------------- água e calor

func _agua_e_calor(delta: float) -> void:
	na_agua = ilha.agua_perto(global_position) if ilha else false
	# mede a queda: o pico é a altura ao sair do chão ou do voo
	if is_on_floor() or estado != Estado.AR:
		_pico_y = global_position.y
	else:
		_pico_y = maxf(_pico_y, global_position.y)
	var taxa := 0.0
	match estado:
		Estado.CHAO, Estado.POUSO:
			taxa = -Ajustes.ESFRIA_CHAO
		Estado.AR:
			taxa = -Ajustes.ESFRIA_AR
		Estado.DECOLAGEM:
			taxa = 0.0
		Estado.VOO:
			if dir_voo.y < Ajustes.MERGULHO_Y:
				taxa = -Ajustes.ESFRIA_VOO_MERGULHO
			else:
				taxa = Ajustes.CALOR_VOO * (1.0 + Ajustes.CALOR_SUBIDA * maxf(0.0, dir_voo.y))
				if arrancada:
					taxa *= Ajustes.CALOR_ARRANCADA
		Estado.PLANAR:
			taxa = -Ajustes.ESFRIA_MERGULHO if dir_voo.y < Ajustes.MERGULHO_Y else -Ajustes.ESFRIA_PLANAR
		Estado.PAIRAR:
			taxa = Ajustes.CALOR_PAIRAR
	if na_agua:
		taxa = minf(taxa, 0.0) - Ajustes.ESFRIA_AGUA
	if chuva > 0.3:
		taxa -= Ajustes.ESFRIA_CHUVA * chuva
	if superaquecido:
		# 12 s para esfriar no ar, 5 s no chão; a água e a chuva aceleram
		var no_chao := estado == Estado.CHAO or estado == Estado.POUSO
		taxa = -(Ajustes.ESFRIA_SUPER_CHAO if no_chao else Ajustes.ESFRIA_SUPER_AR)
		if na_agua:
			taxa -= Ajustes.ESFRIA_AGUA
		if chuva > 0.3:
			taxa -= Ajustes.ESFRIA_CHUVA * chuva
	calor = clampf(calor + taxa * delta, 0.0, 100.0)
	if not superaquecido and calor >= 100.0:
		superaquecido = true
		_tempo_super = 0.0
		tremor = maxf(tremor, 0.5)
		if motor_ligado() or estado == Estado.PLANAR:
			_pulo_vivo = false
			_duplo_usado = true
			_solto = true
			_mudar(Estado.AR)  # o motor trava e o robô cai; se não esfriar a tempo, pousa como der
		superaqueceu.emit()
	elif superaquecido:
		_tempo_super += delta
		if calor <= Ajustes.RELIGA_EM:
			superaquecido = false
			_religa_rapido = estado == Estado.AR
			religou.emit()
	if estado != Estado.VOO:
		arrancada = false


func _process(delta: float) -> void:
	if visual:
		visual.atualizar(delta, self)
