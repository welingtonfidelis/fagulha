class_name Armadura
extends CharacterBody3D
## A armadura de 2,6 m: anda, corre, pula, dá pulo duplo, esquiva, decola, voa, dá arrancada, plana,
## mergulha, paira mirando, solta e pousa.
## O voo é uma física de planador com motor: a gravidade age sempre, a velocidade gira para o nariz
## (sustentação), o motor empurra até a velocidade alvo e o arrasto segura o mergulho perto de 70 m/s.
## Os números ficam em Ajustes.

enum Estado { CHAO, AR, DECOLAGEM, VOO, PLANAR, POUSO, PAIRAR, FREAR, NADO }
const NOMES := ["chão", "no ar", "decolagem", "voo", "planando", "pouso", "pairando", "freando", "nadando"]

signal estado_mudou(novo: int)
signal superaqueceu
signal religou
signal entrou_pane
signal saiu_pane
signal voltou_base  # no meio da pane, com a tela escura: acabou de reaparecer na base

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
var atirando_e := 0.0  # o mesmo para o braço esquerdo (tiro duplo)
var atirando := 0.0  # tempo desde o último tiro (o visual aponta o braço mesmo sem mirar)
var mergulhando := false  # mergulho com impacto em andamento (o visual lê)
var base := Vector3.INF  # onde reaparece depois do curto (o mapa define; sem base, religa onde caiu)
var caido := false  # caiu por superaquecer: não religa nem paira até tocar o chão
var _ignicao := 0.0  # pausa curta ao ligar os jatos no ar, antes do empurrão
signal golpe_chao(onde: Vector3)
signal levou_golpe
var acelerador := 0.0  # no voo: -1 segurando, 0 cruzeiro, 1 acelerando (analógico esquerdo)
var inclinar := 0.0  # no voo: analógico esquerdo de lado, suavizado (o visual e a câmera inclinam)
var postura := 0  # no chão: 0 de pé, 1 abaixado, 2 sentado (o visual e a câmera leem)
var _abaixar_seg := false  # o botão de abaixar segue apertado desde que abaixou
var _abaixar_t := 0.0
var erguendo := 0.0  # tempo que falta para acabar de levantar de sentado (o visual lê; não anda nesse tempo)
var _pulo_seg := -1.0  # há quanto tempo o pulo está segurado desde o aperto (-1: soltou)
var _decola_y := 0.0  # de onde a decolagem começou
var travado := false  # a oficina da base conduz o robô (não anda, não cai, não esquenta)
var escaneando := false  # scanner aberto: primeira pessoa, sem tiro
var _planar_seg := -1.0  # há quanto tempo o botão de planar está segurado (-1: não está)
var _planar_botao := "voar"
var escudo_t := 0.0  # tempo que falta para o escudo de energia recarregar (0: pronto)
var escudos_gastos := 0  # testes
var espada_t := 0.0  # tempo que falta do golpe de espada (o visual balança o braço e acende a lâmina)
var espada_lado := 1.0  # +1 da esquerda para a direita, -1 ao contrário
var luz_ligada := false  # a luz do peito (melhoria), ligada pelo jogador
var nado_rapido := false  # nadando com os jatos abertos (o visual e os efeitos leem)
var nados := 0  # quantas vezes entrou a nadar (testes)
# a física anda a 60 por segundo e a tela não: o corpo e a câmera aparecem entre os dois últimos passos,
# senão o robô dava trancos para a frente e para trás no voo
var _pos_ant := Vector3.ZERO
var _pos_fis := Vector3.ZERO
var _corte := true  # teleporte: não há de onde suavizar
var _frear_tempo := 0.0  # quanto dura a freada antes de os jatos desligarem
var _pairar_travado := false  # desligou o voo parado com o L2 ainda apertado: só volta a pairar apertando de novo
var _solto := false  # motor desligado ou travado no voo: cai pesado até pousar ou religar
var golpes := 0  # quantos golpes de máquina levou (testes)
var avaria := 0  # acertos acumulados; saram com o tempo
var _dano_frac := 0.0  # pedaço de acerto das balas, até somar um inteiro
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
	return estado == Estado.VOO or estado == Estado.DECOLAGEM or estado == Estado.PAIRAR or estado == Estado.FREAR


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
## `dano` é quanto do acerto conta: 1 para um golpe ou um míssil, uma fração para uma bala (três balas valem
## um acerto).
func levar_golpe(direcao: Vector3, forca: float, dano := 1.0) -> void:
	if em_pane or graca_pane > 0.0:
		return
	# o escudo de energia (fabricável) engole um acerto e leva um tempo para recarregar
	if Arsenal.tem("escudo") and escudo_t <= 0.0:
		escudo_t = Arsenal.ESCUDO_RECARGA
		escudos_gastos += 1
		tremor = maxf(tremor, 0.25)
		velocity += direcao.normalized() * forca * 0.3
		return
	velocity += direcao.normalized() * forca + Vector3(0, forca * 0.35, 0)
	calor = minf(100.0, calor + Ajustes.GOLPE_CALOR * dano)
	tremor = maxf(tremor, 0.3 + 0.5 * minf(dano, 1.0))
	golpes += 1
	levou_golpe.emit()
	_dano_frac += dano
	while _dano_frac >= 0.999:
		_dano_frac -= 1.0
		avaria += 1
	_avaria_tempo = Ajustes.AVARIA_SARA
	if avaria >= Arsenal.golpes_pane():
		_dano_frac = 0.0
		em_pane = true
		_pane_t = 0.0
		_pane_volta = base
		if estado != Estado.CHAO:
			_mudar(Estado.AR)
		entrou_pane.emit()


## Pane sem golpe (longe demais no mar): desliga e, com a tela já escura, volta para `volta` (a praia).
func pane_forcada(volta: Vector3) -> void:
	if em_pane:
		return
	em_pane = true
	_pane_t = 0.0
	_pane_volta = base if base.is_finite() else volta
	if estado != Estado.CHAO:
		_mudar(Estado.AR)
	entrou_pane.emit()


## Laço do robô desligado: só cai e espera. Devolve true enquanto a pane durar.
func _pane(delta: float) -> bool:
	graca_pane = maxf(0.0, graca_pane - delta)
	if (avaria > 0 or _dano_frac > 0.0) and not em_pane:
		_avaria_tempo -= delta
		if _avaria_tempo <= 0.0:
			# sara um acerto inteiro; sem nenhum inteiro, some o pedaço que as balas deixaram (ele ficava para
			# sempre, e as marcas de vida não sumiam da tela)
			if avaria > 0:
				avaria -= 1
			else:
				_dano_frac = 0.0
			_avaria_tempo = Ajustes.AVARIA_SARA
	if not em_pane:
		return false
	postura = 0
	_pane_t += delta
	if _pane_volta.is_finite() and _pane_t >= Ajustes.PANE_VOLTA:
		# a tela já escureceu: o robô reaparece na praia
		global_position = _pane_volta
		_corte = true
		velocity = Vector3.ZERO
		_pane_volta = Vector3.INF
		_pico_y = global_position.y
		if base.is_finite() and camera:
			camera.yaw = yaw_inicio
			camera.pitch = -0.12
		_mudar(Estado.AR)
		voltou_base.emit()
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


## Onde o robô aparece neste quadro: entre os dois últimos passos da física.
func pos_suave() -> Vector3:
	if _corte:
		return global_position
	return _pos_ant.lerp(_pos_fis, Engine.get_physics_interpolation_fraction()) + Vector3(0, _degrau_y, 0)


var degraus := 0  # quantos degraus subiu (testes)
var _degrau_y := 0.0  # depois de subir um degrau o corpo desenhado alcança o de verdade aos poucos


## Andando no chão contra um desnível baixo (até Ajustes.DEGRAU), sobe nele como numa escada: confere se
## há obstáculo à frente, se cabe por cima e se lá em cima há piso em que dá para ficar de pé.
func _subir_degrau(delta: float) -> void:
	if estado != Estado.CHAO or not is_on_floor() or em_pane:
		return
	var h := Vector3(velocity.x, 0, velocity.z)
	if h.length() < 0.6:
		return
	var frente := h.normalized() * maxf(h.length() * delta, 0.16)
	var t0 := global_transform
	if not test_move(t0, frente):
		return
	if test_move(t0, Vector3(0, Ajustes.DEGRAU, 0)):
		return
	var em_cima := t0.translated(Vector3(0, Ajustes.DEGRAU, 0))
	if test_move(em_cima, frente):
		return
	var la := em_cima.translated(frente)
	var col := KinematicCollision3D.new()
	if not test_move(la, Vector3(0, -Ajustes.DEGRAU, 0), col):
		return
	if col.get_normal().y < cos(floor_max_angle):
		return
	var sobe := Ajustes.DEGRAU + col.get_travel().y
	if sobe < 0.06:
		return
	global_position = la.origin + col.get_travel()
	_degrau_y -= sobe
	degraus += 1


func teleportar(pos: Vector3, novo: int, vel := Vector3.ZERO) -> void:
	global_position = pos
	_corte = true
	_pulo_seg = -1.0
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
	mergulhando = false
	if novo != Estado.CHAO:
		postura = 0
		_abaixar_seg = false
		erguendo = 0.0
	if novo != Estado.VOO:
		_arrancada_alt = false
		acelerador = 0.0
		inclinar = 0.0
		if novo != Estado.DECOLAGEM:
			_graca = 0.0
	if novo == Estado.CHAO or novo == Estado.POUSO:
		caido = false
	if novo == Estado.CHAO or novo == Estado.VOO or novo == Estado.PAIRAR:
		_religa_rapido = false
		_duplo_usado = false
		_esquiva_ar_usada = false
	estado_mudou.emit(novo)


func _physics_process(delta: float) -> void:
	_passo(delta)
	_pos_ant = global_position if _corte else _pos_fis
	_pos_fis = global_position
	_corte = false


func _passo(delta: float) -> void:
	_tempo_estado += delta
	if _pane(delta):
		return
	escudo_t = maxf(0.0, escudo_t - delta)
	if travado:
		return
	if Input.is_action_just_pressed("luz") and Melhorias.tem("farol"):
		luz_ligada = not luz_ligada
	var mira := camera.mira() if camera else -global_basis.z
	var mov := Input.get_vector("esquerda", "direita", "frente", "tras")
	# no tiro duplo o L2 é o gatilho do braço esquerdo: não mira
	mirando = Input.is_action_pressed("mirar") and not (Arsenal.modo == "duplo" and Arsenal.tem_arma("duplo"))
	_esquiva_espera = maxf(0.0, _esquiva_espera - delta)
	impulso = maxf(0.0, impulso - delta * 3.0)
	atirando = maxf(0.0, atirando - delta)
	atirando_e = maxf(0.0, atirando_e - delta)
	espada_t = maxf(0.0, espada_t - delta)
	clarao_tiro = maxf(0.0, clarao_tiro - delta * 5.0)
	if ilha:
		ilha.atualizar_colisao_arvores(global_position)
	_entrar_no_nado()
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
		Estado.FREAR:
			_frear(delta, mira)
		Estado.NADO:
			_nado(delta, mov)
	_esquiva_aplicar(delta)
	_subir_degrau(delta)
	_degrau_y = move_toward(_degrau_y, 0.0, delta * 2.6)
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
	# L3 alterna a corrida; o R3 abaixa (ver _abaixar)
	var quieto := Vector2(velocity.x, velocity.z).length() < 1.2
	if Input.is_action_just_pressed("correr_alternar"):
		_correr_alt = not _correr_alt
	if mov.length() < 0.15:
		_correr_alt = false
	var correr := Input.is_action_pressed("correr") or _correr_alt
	var postura_antes := postura
	erguendo = maxf(0.0, erguendo - delta)
	_abaixar(delta, mov, correr, quieto)
	var dir := _plano_camera() * Vector3(mov.x, 0.0, mov.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var vmax := (Ajustes.CORRER if correr else Ajustes.ANDAR) * vel_chao
	if mirando:
		vmax = Ajustes.ANDAR_MIRANDO * vel_chao
	if postura == 1:
		vmax = minf(vmax, Ajustes.ANDAR_ABAIXADO * vel_chao)
	elif postura == 2 or erguendo > 0.0:
		vmax = 0.0
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
	if estado == Estado.CHAO and postura == 2 and Input.is_action_just_pressed("pular"):
		postura = 0  # sentado, o X só levanta
	elif estado == Estado.CHAO and Input.is_action_just_pressed("pular") and erguendo <= 0.0:
		velocity.y = Ajustes.PULO * Melhorias.pulo()
		_origem_chao = true
		_segurando = 0.0
		_pulo_seg = 0.0
		_mudar(Estado.AR)
		_pulo_vivo = true
	elif estado == Estado.CHAO and Input.is_action_just_pressed("soltar"):
		postura = 0
		_tentar_esquiva(mov)
	# levantar de sentado leva um instante (o visual encolhe as pernas, apoia e sobe)
	if postura_antes == 2 and postura == 0 and estado == Estado.CHAO and esquivando <= 0.0:
		erguendo = Ajustes.ERGUER_TEMPO
	elif postura != 0 or esquivando > 0.0:
		erguendo = 0.0


## Sentar (seta para a esquerda / Ctrl): um toque senta, parado; outro toque, mexer o analógico ou apertar o
## X levanta. Correr sempre levanta. (Agachar saiu: não tinha uso no jogo.)
func _abaixar(delta: float, mov: Vector2, correr: bool, quieto: bool) -> void:
	if estado != Estado.CHAO or esquivando > 0.0:
		postura = 0
		_abaixar_seg = false
		return
	# sentar é um toque na seta para a esquerda (Ctrl), parado; outro toque levanta. Agachar saiu do jogo
	if Input.is_action_just_pressed("sentar"):
		if postura == 0 and quieto:
			postura = 2
		else:
			postura = 0
	if postura == 2 and mov.length() > 0.35:
		postura = 0
	if postura != 0 and correr:
		postura = 0


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
	if mergulhando:
		# mergulho com impacto: jatos cortados, desce reto e rápido até bater
		velocity.x *= exp(-6.0 * delta)
		velocity.z *= exp(-6.0 * delta)
		velocity.y = move_toward(velocity.y, -Ajustes.MERGULHO_VEL, 220.0 * delta)
		return
	if not mirando:
		_pairar_travado = false
	var quer_pairar := (mirando and not _pairar_travado) or Input.is_action_just_pressed("pairar")
	if quer_pairar and not superaquecido and not caido:
		_solto = false
		_mudar(Estado.PAIRAR)
		return
	# segurar o pulo (o do chão ou o duplo) decola: sobe reto uns 10 m e sai voando para a frente
	if Input.is_action_just_pressed("pular"):
		_pulo_seg = 0.0
	elif Input.is_action_pressed("pular") and _pulo_seg >= 0.0:
		_pulo_seg += delta
		if _pulo_seg >= Ajustes.DECOLAR_SEGURAR and not superaquecido and not caido:
			_decolar()
			return
	else:
		_pulo_seg = -1.0
	if _pulo_vivo:
		# segurando o pulo, os jatos estendem a subida por um instante
		if Input.is_action_pressed("pular") and _segurando < Ajustes.PULO_SEGURA_TEMPO and velocity.y > 0.0:
			_segurando += delta
			velocity.y += Ajustes.PULO_SEGURA * delta
			impulso = maxf(impulso, 0.5)
		else:
			_pulo_vivo = false
	if Input.is_action_just_pressed("voar") and not superaquecido and not caido:
		# o botão de voo no ar liga os jatos: o robô deita e acelera para onde a câmera aponta
		_pulo_vivo = false
		_ligar_voo(mira)
		return
	if Input.is_action_just_pressed("pular") and not superaquecido and not caido and not _duplo_usado:
		_duplo_usado = true
		velocity.y = maxf(velocity.y, Ajustes.PULO_DUPLO * Melhorias.pulo())
		calor = minf(100.0, calor + Ajustes.CALOR_PULO_DUPLO)
		impulso = 1.0
		_pulo_vivo = false
	if Input.is_action_just_pressed("soltar"):
		_tentar_esquiva(mov)
	elif Input.is_action_just_pressed("golpe") and not caido:
		_mergulhar()


## Mergulho com impacto (triângulo no voo, parado no ar ou caindo): corta os jatos e despenca reto.
func _mergulhar() -> void:
	if altura_do_chao() < Ajustes.MERGULHO_ALTURA_MIN:
		return
	mergulhando = true
	_pulo_vivo = false
	_solto = false
	_pico_y = maxf(_pico_y, global_position.y)
	velocity = Vector3(velocity.x * 0.3, minf(velocity.y, -12.0), velocity.z * 0.3)
	impulso = 1.0
	tremor = maxf(tremor, 0.3)
	_mudar(Estado.AR)
	mergulhando = true  # _mudar zera


func _decolar() -> void:
	_pulo_vivo = false
	_pulo_seg = -1.0
	_solto = false
	_decola_y = global_position.y
	calor = minf(100.0, calor + Ajustes.CALOR_DECOLAGEM)
	tremor = maxf(tremor, 0.35)
	impulso = 1.0
	_mudar(Estado.DECOLAGEM)


## Decolagem: de pé, sobe reto DECOLAGEM_SUBIDA metros (ou até bater num teto) e então deita e sai voando
## para onde a câmera aponta.
func _decolagem(delta: float, mira: Vector3) -> void:
	velocity.y = move_toward(velocity.y, Ajustes.DECOLAGEM_VEL, 60.0 * delta)
	var plano := Vector3(mira.x, 0.0, mira.z).normalized()
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 14.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	dir_voo = (plano * 0.2 + Vector3.UP).normalized()
	if global_position.y - _decola_y >= Ajustes.DECOLAGEM_SUBIDA or _tempo_estado >= Ajustes.DECOLAGEM_TEMPO \
			or (is_on_ceiling() and _tempo_estado > 0.15):
		_graca = Ajustes.DECOLAGEM_GRACA
		dir_voo = (plano + Vector3.UP * 1.2).normalized()
		velocity += plano * 5.0
		_ligar_voo(mira)


func _ligar_voo(mira: Vector3) -> void:
	_solto = false
	if superaquecido:
		return
	if estado != Estado.DECOLAGEM:
		dir_voo = velocity.normalized() if velocity.length() > 6.0 else mira
		if velocity.length() < 8.0:
			velocity.y = maxf(velocity.y, Ajustes.IGNICAO_IMPULSO)
		calor = minf(100.0, calor + Ajustes.CALOR_IGNICAO)
		_ignicao = Ajustes.IGNICAO_TEMPO
		impulso = 1.0
		# ligado perto do chão, o nariz não desce abaixo do horizonte por um instante
		if altura_do_chao() < 8.0:
			_graca = Ajustes.DECOLAGEM_GRACA
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
	var taxa := lerpf(Ajustes.GIRO_LENTO, Ajustes.GIRO_RAPIDO, clampf(v / Ajustes.VEL_TOPO, 0.0, 1.0))
	if estado == Estado.PLANAR:
		taxa *= Melhorias.giro_planar()
	# inclinar o analógico esquerdo para o lado da curva fecha a curva
	var virando := dir_voo.cross(mira).y  # > 0: virando para a esquerda
	if absf(mov.x) > 0.2 and signf(-mov.x) == signf(virando) and absf(virando) > 0.02:
		taxa *= 1.0 + Ajustes.CURVA_INCLINADA * absf(mov.x)
	dir_voo = girar_para(dir_voo, mira, taxa * delta)
	inclinar = lerpf(inclinar, mov.x, 1.0 - exp(-6.0 * delta))
	var motor := estado == Estado.VOO
	# acelerador no analógico esquerdo: neutro é o cruzeiro, todo para a frente é a arrancada, para trás segura
	acelerador = (-mov.y if absf(mov.y) > 0.15 else 0.0) if motor else 0.0
	arrancada = motor and acelerador > 0.85
	if _ignicao > 0.0:
		# pausa de ignição: um instante suspenso, e então o empurrão para onde a câmera aponta
		_ignicao -= delta
		velocity *= exp(-5.0 * delta)
		impulso = 1.0
		if _ignicao <= 0.0:
			velocity += dir_voo * Ajustes.IGNICAO_EMPURRAO
			tremor = maxf(tremor, 0.25)
		return
	# gravidade
	velocity += Vector3.DOWN * Ajustes.G_VOO * delta
	# motor: empurra até a velocidade alvo, perdendo força acima do teto
	if motor:
		var frente := maxf(acelerador, 0.0)
		var alvo := lerpf(Melhorias.voo_alvo(), Melhorias.arrancada_alvo(), frente)
		if acelerador < 0.0:
			alvo = lerpf(Melhorias.voo_alvo(), Ajustes.FREIO_ALVO, -acelerador)
		var ao_longo := velocity.dot(dir_voo)
		var maximo := lerpf(Ajustes.EMPUXO_MAX, Ajustes.EMPUXO_ARRANCADA, frente)
		var emp := clampf((alvo - ao_longo) * Ajustes.EMPUXO_GANHO, 0.0, maximo)
		emp *= 1.0 - smoothstep(Ajustes.TETO, Ajustes.TETO + Ajustes.TETO_FAIXA, global_position.y)
		velocity += dir_voo * emp * delta
		if acelerador < 0.0 and ao_longo > alvo:
			# segurando: os jatos freiam de verdade (só o arrasto do ar demorava demais)
			velocity -= dir_voo * minf((ao_longo - alvo) * Ajustes.EMPUXO_GANHO, Ajustes.FREIO_AR) * -acelerador * delta
	# sustentação: a velocidade gira para o nariz (fraca devagar)
	var vlen := velocity.length()
	var sust := Ajustes.SUSTENTACAO * clampf(vlen / (Ajustes.VOO_ALVO * 0.7), 0.12, 1.0)
	velocity = velocity.lerp(dir_voo * vlen, clampf(sust * delta, 0.0, 1.0))
	# arrasto
	velocity -= velocity * (Melhorias.arrasto_planar() if estado == Estado.PLANAR else Ajustes.ARRASTO) * vlen * delta
	# deslize lateral com o analógico esquerdo
	var lado := dir_voo.cross(Vector3.UP)
	if lado.length() > 0.1:
		velocity += lado.normalized() * mov.x * Ajustes.LATERAL * delta
	# planando devagar demais, o nariz cai
	if estado == Estado.PLANAR and vlen < Melhorias.estol():
		dir_voo = girar_para(dir_voo, (dir_voo + Vector3.DOWN).normalized(), 1.2 * delta)
	# botões
	# planando, o X religa o motor
	# L3 / Shift e X fazem o mesmo no voo (pedido do usuário, 2026-11-17): um toque corta tudo e o robô cai,
	# esteja com o jato ou planando; segurar troca um pelo outro (do jato para o planador e de volta). Sem
	# as asas não há planador: o toque corta os jatos na hora.
	if estado == Estado.PLANAR or Melhorias.tem("asas"):
		if Input.is_action_just_pressed("voar"):
			_planar_seg = 0.0
			_planar_botao = "voar"
		elif Input.is_action_just_pressed("pular"):
			_planar_seg = 0.0
			_planar_botao = "pular"
		if _planar_seg >= 0.0:
			if Input.is_action_pressed(_planar_botao):
				_planar_seg += delta
				if _planar_seg >= Ajustes.PLANAR_SEGURAR:
					_planar_seg = -1.0
					_pulo_vivo = false
					if estado == Estado.VOO:
						_mudar(Estado.PLANAR)
					elif not superaquecido:
						_mudar(Estado.VOO)
					return
			else:
				# soltou antes: era um toque
				_planar_seg = -1.0
				_cortar_jatos()
				return
	elif Input.is_action_just_pressed("voar") or Input.is_action_just_pressed("pular"):
		_cortar_jatos()
		return
	if Input.is_action_just_pressed("soltar"):
		# antes de desligar, vira os jatos para a frente e freia
		_pulo_vivo = false
		_frear_tempo = lerpf(Ajustes.FREAR_TEMPO_MIN, Ajustes.FREAR_TEMPO, clampf(velocity.length() / Ajustes.VOO_ALVO, 0.0, 1.0))
		tremor = maxf(tremor, 0.3)
		_mudar(Estado.FREAR)
	elif Input.is_action_just_pressed("golpe"):
		_mergulhar()
	elif (Input.is_action_just_pressed("mirar") or Input.is_action_just_pressed("pairar")) and not superaquecido:
		_mudar(Estado.PAIRAR)  # no voo, apertar o L2 ou o R3 freia e paira (segurado de antes não conta)


## O botão de voo de novo corta os jatos na hora: fica de pé e cai com a gravidade comum, levando o embalo;
## dá para religar a qualquer momento.
func _cortar_jatos() -> void:
	_pulo_vivo = false
	_duplo_usado = true
	_solto = false
	_mudar(Estado.AR)


## Freada antes de desligar o voo: de pé no ar, pés e mãos para a frente, os jatos seguram o embalo.
## Quando acaba, o motor desliga e o robô cai pesado.
func _frear(delta: float, mira: Vector3) -> void:
	var k := exp(-Ajustes.FREAR_FORCA * delta)
	velocity.x *= k
	velocity.z *= k
	velocity.y = velocity.y * exp(-3.0 * delta) - Ajustes.G_VOO * 0.3 * delta
	impulso = maxf(impulso, 0.9)
	tremor = maxf(tremor, 0.15)
	if Input.is_action_just_pressed("pular") and not superaquecido:
		_ligar_voo(mira)  # desistiu de desligar: volta a voar
	elif _tempo_estado >= _frear_tempo:
		velocity.y = minf(velocity.y, 0.0) - 2.0
		_solto = true
		_mudar(Estado.AR)


# ---------------------------------------------------------------- nado

func altura_corpo() -> float:
	return 2.6 * porte


## Em água funda, com o corpo já debaixo da lâmina e sem estar subindo, o robô passa a nadar.
func _entrar_no_nado() -> void:
	if ilha == null or estado == Estado.NADO or estado == Estado.DECOLAGEM or velocity.y > 1.5:
		return
	var nivel := ilha.agua(global_position.x, global_position.z)
	if nivel == -INF or nivel - global_position.y < Ajustes.NADO_ENTRA * altura_corpo():
		return
	if nivel - ilha.altura(global_position.x, global_position.z) < Ajustes.NADO_FUNDURA * altura_corpo():
		return
	velocity *= 0.45 if velocity.length() > Ajustes.NADO_RAPIDO else 1.0
	nado_rapido = false
	nados += 1
	_solto = false
	caido = false
	_mudar(Estado.NADO)


## Nado com os jatos: o analógico esquerdo leva para onde a câmera aponta (olhando para baixo, desce), o X
## sobe, o O desce e o L3 abre os jatos (nado rápido). Parado ele fica boiando no lugar. Na lâmina, o X pula
## para fora; chegando rápido de baixo para cima, sai voando. No raso volta a andar.
func _nado(delta: float, mov: Vector2) -> void:
	var nivel := ilha.agua(global_position.x, global_position.z)
	var alt := altura_corpo()
	if nivel == -INF or nivel - ilha.altura(global_position.x, global_position.z) < Ajustes.NADO_FUNDURA * alt * 0.8:
		_duplo_usado = false
		_mudar(Estado.AR)  # raso: afunda até o chão e anda
		return
	if (Input.is_action_just_pressed("correr_alternar") or Input.is_action_just_pressed("correr")) and Melhorias.nado_rapido():
		nado_rapido = not nado_rapido
	if mov.length() < 0.15 and not Input.is_action_pressed("pular"):
		nado_rapido = false
	var b := Basis.from_euler(Vector3(camera.pitch, camera.yaw, 0.0)) if camera else Basis.IDENTITY
	var dir := (b * Vector3(mov.x, 0.0, mov.y)).limit_length(1.0)
	var alvo := dir * (Ajustes.NADO_RAPIDO if nado_rapido else Ajustes.NADO_VEL)
	var vert := (1.0 if Input.is_action_pressed("pular") else 0.0) - (1.0 if Input.is_action_pressed("soltar") else 0.0)
	alvo.y += vert * Ajustes.NADO_SOBE
	velocity = velocity.move_toward(alvo, Ajustes.NADO_ACEL * delta)
	if velocity.length() > 1.0:
		dir_voo = velocity.normalized()
	impulso = maxf(impulso, 0.6 if nado_rapido else 0.0)
	# a lâmina: a cabeça fica logo abaixo dela, a não ser que ele saia
	var limite := nivel - alt * 0.8
	if global_position.y >= limite and velocity.y >= 0.0:
		if velocity.y > Ajustes.NADO_SALTO and not superaquecido:
			# chegou rápido de baixo: rompe a lâmina e sai voando
			_graca = Ajustes.DECOLAGEM_GRACA
			velocity.y = maxf(velocity.y, 9.0)
			_mudar(Estado.VOO)
			return
		if Input.is_action_just_pressed("pular"):
			# pulo para fora d'água (segurando, decola como de costume)
			velocity.y = Ajustes.PULO * 1.25
			_pulo_seg = 0.0
			_pulo_vivo = false
			_duplo_usado = false
			impulso = 1.0
			_mudar(Estado.AR)
			return
		velocity.y = minf(velocity.y, (limite - global_position.y) * 4.0)


# ---------------------------------------------------------------- pairar, esquiva e mira

func _pairar(delta: float, mov: Vector2, mira: Vector3) -> void:
	var dir := _plano_camera() * Vector3(mov.x, 0.0, mov.y)
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(dir.limit_length(1.0) * Ajustes.PAIRAR_VEL, Ajustes.PAIRAR_FREIO * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = move_toward(velocity.y, sin(_tempo_estado * 2.2) * 0.25, Ajustes.PAIRAR_FREIO * delta)
	dir_voo = Vector3(mira.x, 0.0, mira.z).normalized() if Vector2(mira.x, mira.z).length() > 0.05 else dir_voo
	# voo parado: fica assim mesmo soltando o L2. X volta a voar para a frente; O desliga o propulsor.
	if Input.is_action_just_pressed("pular") or Input.is_action_just_pressed("voar"):
		_ligar_voo(mira)
	elif Input.is_action_just_pressed("golpe"):
		_mergulhar()
	elif Input.is_action_just_pressed("pairar"):
		# R3 de novo cancela o voo parado: cai com a gravidade comum
		_pairar_travado = mirando
		_mudar(Estado.AR)
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
			if (impacto > Ajustes.VOO_ALVO * 0.85 or (impacto > Ajustes.VOO_ALVO * 0.55 and antes.length() > Ajustes.VOO_ALVO * 1.1)) and em_voo():
				velocity = velocity * 0.3 + n * 4.0
				tremor = maxf(tremor, 0.8)
				_mudar(Estado.AR)
				break
			elif impacto > 2.0:
				velocity *= 1.0 - clampf(impacto / Ajustes.VEL_TOPO, 0.0, 0.3)
	# pouso
	if is_on_floor():
		_fora_chao = 0.0
		_solto = false
		if estado == Estado.AR or em_voo() or estado == Estado.PAIRAR or estado == Estado.FREAR:
			# a força do pouso segue a altura da queda: de alto, pouso de herói; de baixo, com estilo leve
			queda_altura = maxf(0.0, _pico_y - global_position.y)
			var bateu := mergulhando
			var forte := queda_altura > Ajustes.QUEDA_HEROI or (em_voo() and antes.length() > Ajustes.ARRANCADA_ALVO + 4.0) or bateu
			var leve := (queda_altura > Ajustes.QUEDA_LEVE and estado == Estado.AR) or caido
			# todo pouso de voo, de voo parado ou de queda maior que um pulo tem a sua animação
			var toque := em_voo() or estado == Estado.PAIRAR or estado == Estado.FREAR or queda_altura > Ajustes.QUEDA_TOQUE
			if forte or leve:
				pouso_forca = 1.0 if forte else 0.5
				tremor = maxf(tremor, 0.9 if forte else 0.3)
				_pouso_tempo = (0.95 if forte else 0.4) * Melhorias.tranco()
				if caido:
					_pouso_tempo = Ajustes.RECUPERA_SUPER  # caiu superaquecido: leva um tempo para se recompor
				if bateu:
					tremor = maxf(tremor, 1.2)
					golpe_chao.emit(global_position)
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
			taxa = -Melhorias.esfria_chao()
		Estado.AR:
			taxa = -Ajustes.ESFRIA_AR
		Estado.DECOLAGEM:
			taxa = 0.0
		Estado.VOO:
			if dir_voo.y < Ajustes.MERGULHO_Y:
				taxa = -Ajustes.ESFRIA_VOO_MERGULHO
			else:
				taxa = Melhorias.calor_voo() * (1.0 + Ajustes.CALOR_SUBIDA * maxf(0.0, dir_voo.y))
				if arrancada:
					taxa *= Ajustes.CALOR_ARRANCADA
				elif acelerador > 0.0:
					taxa *= 1.0 + (Ajustes.CALOR_ARRANCADA - 1.0) * acelerador
		Estado.PLANAR:
			taxa = -Ajustes.ESFRIA_MERGULHO if dir_voo.y < Ajustes.MERGULHO_Y else -Ajustes.ESFRIA_PLANAR
		Estado.PAIRAR:
			taxa = Melhorias.calor_pairar()
		Estado.NADO:
			taxa = -Ajustes.NADO_ESFRIA
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
			_mudar(Estado.AR)
			caido = true  # o motor trava e o robô cai; se não esfriar a tempo, pousa como der
		superaqueceu.emit()
	elif superaquecido:
		_tempo_super += delta
		if calor <= Ajustes.RELIGA_EM:
			superaquecido = false
			_religa_rapido = false
			religou.emit()
	if estado != Estado.VOO:
		arrancada = false


func _process(delta: float) -> void:
	if visual:
		visual.position = pos_suave() - global_position
		visual.atualizar(delta, self)
