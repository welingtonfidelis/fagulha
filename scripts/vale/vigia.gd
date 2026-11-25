class_name Vigia
extends MaquinaPequena
## Vigia: atirador de chão de 1,7 m (o George do pacote, de antenas). Ronda a pé em volta da casa; vendo o
## robô (42 m), vai até uns 16 m dele, fica de frente e solta tiros lentos, um de cada vez, com um aviso
## vermelho antes. Chegando perto demais ele recua. Não corre atrás de quem voa alto: fica atirando de
## baixo. Três tiros do robô desligam: cai, fuma e religa depois.

enum Estado { RONDA, CACA, VOLTA, PROCURA, RECUA }
const NOMES := ["ronda", "caça", "volta", "procura", "recua"]
const GRUPO := "vigias"
## A cabeça numa árvore de comportamento (VigiaArvore, com a Beehave). Desligando, volta a máquina de
## estados de antes: ronda, caça e volta.
static var com_arvore := true
const VER := 42.0
const PERDER := 70.0
const VEL_RONDA := 1.2
const RAIO_RONDA := 14.0
const TEMPO_AVISO := 0.65
const TEMPO_AVISO_GOLPE := 0.55  # corpo a corpo: o aviso antes da lâmina (a varrida começa junto)

# o que muda de uma máquina para outra (a Mecha acerta estes pela ficha do sorteio)
var modelo := "george"
var altura_m := 1.7
var vel_caca := 4.2
var dist_tiro := 16.0
var tempo_tiro := 2.4
var calor_tiro := 34.0
var tipo_tiro := "bala"  # "bala", "pesado" ou "missil" (MaquinaPequena.TIROS)
var rajada := 1  # tiros por vez
var espalha := 0.03  # erro de mira, em radianos
var _rajada_resta := 0
var _rajada_t := 0.0
var corpo_a_corpo := false  # em vez de atirar, chega junto e bate (espada ou martelo)
var forca_golpe := 7.0
var alcance_golpe := 0.0  # corpo a corpo: até onde o golpe pega, do meio do corpo (0: dist_tiro * 1.25)
var aviso_mult := 1.0  # o aviso antes do ataque, vezes isto (mais longo no iniciante da base)
var dano_golpe := 1.0  # o calor que um golpe põe no robô, vezes isto (Ajustes.GOLPE_CALOR)
var rodeia := false  # em vez de ficar parado na distância de tiro, corre em volta do robô
var motor := "carrapato_loop"

var estado := Estado.RONDA
var disparos := 0
var chefe := false  # máquina grande: aguenta mais e bate mais forte (a Mecha acerta o resto)
var pose_foto := -1
var guiado := Vector3.INF  # um ponto para onde andar reto antes de qualquer coisa (a saída da porta da Fundição)
var _guiado_de := Vector3.INF  # o guiado em que o prazo está contando
var _guiado_t := 0.0
const PRAZO_GUIADO := 10.0  # s para chegar no ponto guiado; passou disso, larga e segue caçando

var _rumo := Vector3.FORWARD
var _destino := Vector3.ZERO
var _pausa := 1.0
var _recarga := 1.5
var _aviso := 0.0
var _lado := 1.0
var _tiro_t := 0.0  # tempo que falta da animação de tiro

# o que a árvore usa
var arvore: BeehaveTree
var visto_em := Vector3.INF  # onde viu o robô pela última vez
var sem_ver := 99.0  # há quantos segundos não vê
var pista := Vector3.INF  # um lugar para ir olhar
var procura_t := 0.0  # tempo olhando em volta no lugar da pista
var recuando := false
var recuo_t := 0.0
var recuo_folga := 0.0
var avisada := 0  # vezes em que outra máquina a chamou (testes)
var alerta_t := 0.0  # levou tiro há pouco: enxerga até PERDER (doc §167)
var provocadas := 0  # tiros levados com a árvore ligada (testes)
const ALERTA := 12.0
const ERRO_PISTA := 0.08  # a pista do tiro erra até isto da distância...
const ERRO_PISTA_MAX := 10.0  # ...e no máximo isto, em m


func calor_por_tiro() -> float:
	return calor_tiro


func raio_acerto() -> float:
	return 0.55 * altura_m


func som_motor() -> String:
	return motor


func centro() -> Vector3:
	return global_position + Vector3(0, altura_m * 0.6, 0)


func _ready() -> void:
	_montar_base()
	_acerto.position.y = altura_m * 0.6
	_fumaca.position.y = altura_m * 0.5
	_montar_corpo()
	_lado = 1.0 if semente % 2 == 0 else -1.0
	_destino = casa
	var q := _ponto_ronda()
	global_position = Vector3(q.x, mapa.altura(q.x, q.z), q.z)
	rotation.y = _rng.randf() * TAU
	add_to_group(GRUPO)
	if com_arvore:
		arvore = VigiaArvore.montar(self)


## O corpo da máquina (quem herda pode montar outro).
func _montar_corpo() -> void:
	pass


## Desligado, o corpo deita acompanhando a inclinação do chão (a altura quem acerta é o MechVisual).
func _deitar_no_terreno(delta: float) -> void:
	var n := mapa.normal_em(global_position.x, global_position.z)
	var n_local := global_basis.inverse() * n
	var alvo_b := Basis(Quaternion(Vector3.UP, n_local.normalized()))
	_corpo.basis = _corpo.basis.slerp(alvo_b, 1.0 - exp(-5.0 * delta))


func nome_estado() -> String:
	return "desligado" if desligada else NOMES[estado]


## Levou um tiro (ou um mergulho com impacto). Mesmo sem ver quem atirou, sabe de onde veio (doc §167): fica em
## alerta (enxerga até PERDER em vez de VER) e, sem o robô à vista, a pista vira o lugar do tiro, com um erro que
## cresce com a distância; as máquinas de perto vão junto. Antes a árvore desfazia a caça no quadro seguinte,
## porque a máquina não via o robô, e um tiro de mais de 42 m não dava em nada (visto pelo usuário num procurado,
## 2026-11-25).
func _provocada() -> void:
	if alvo == null or alvo.em_pane:
		return
	if arvore == null:
		if estado != Estado.CACA:
			estado = Estado.CACA
			_recarga = 0.8
		return
	alerta_t = ALERTA
	provocadas += 1
	if sem_ver <= VigiaArvore.MEMORIA:
		return  # vendo o robô ela já caça
	var de := alvo.global_position
	var erro := minf(de.distance_to(global_position) * ERRO_PISTA, ERRO_PISTA_MAX)
	var ang := _rng.randf() * TAU
	pista = de + Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(0.0, erro)
	procura_t = 0.0
	VigiaArvore.avisar(self, pista, true)


func _ponto_ronda() -> Vector3:
	for k in 8:
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(3.0, RAIO_RONDA)
		var x := casa.x + cos(ang) * r
		var z := casa.z + sin(ang) * r
		if _pisavel(x, z) and Obstaculos.livre(mapa, x, z, altura_m * 0.3):
			return Vector3(x, 0, z)
	return casa


var desvios := 0  # quadros em que andou por um rumo diferente do que queria, por obstáculo (testes)
var destravou := 0  # vezes em que ficou preso e mudou de plano (testes)
var furou := 0  # vezes em que desistiu de dar a volta e atravessou o obstáculo (testes)
var voltas_cortadas := 0  # vezes em que percebeu que rodava em volta de alguma coisa (testes)
var esperas := 0  # vezes em que desistiu de chegar no robô e ficou esperando (testes)
var _espera_t := 0.0
var _espera_de := Vector3.INF  # onde o robô estava quando ele desistiu
var _meta_estado := -1
var _meta_melhor := INF  # a menor distância até onde quer ir, na janela de agora
var _meta_t := 0.0
var _meta_desvio := 0.0
var _meta_p := Vector3.ZERO  # onde a janela começou
var _meta_andou := 0.0  # o caminho andado na janela
var _sem_avanco := 0
var _atravessa_t := 0.0
var _lado_desvio := 1.0
var _trava_t := 0.0
var _trava_p := Vector3.ZERO


## Não dá para chegar onde quer (dando voltas pelos dois lados). Caçando, o robô está num lugar onde ele não
## chega (em cima de alguma coisa, ou fechado por obstáculos): fica parado de frente para ele até o robô sair de
## lá. Na ronda escolhe outro ponto e na procura desiste da pista. Só voltando para casa ele atravessa.
func _nao_chega() -> void:
	match estado:
		Estado.CACA:
			_espera_t = 8.0  # ou até o robô sair de lá
			_espera_de = alvo.global_position if alvo else global_position
			esperas += 1
		Estado.RONDA:
			_destino = _ponto_ronda()
		Estado.PROCURA:
			procura_t = VigiaArvore.OLHAR
		_:
			_atravessa_t = 1.6
			furou += 1


## Corpo a corpo: até onde a lâmina pega, do meio do corpo.
func alcance() -> float:
	return alcance_golpe if alcance_golpe > 0.0 else dist_tiro * 1.25


## Onde ele quer chegar agora (para saber se está chegando): o robô na caça, a pista, a casa ou o ponto da ronda.
func _meta() -> Vector3:
	match estado:
		Estado.CACA:
			return alvo.global_position if alvo else Vector3.INF
		Estado.PROCURA:
			return pista
		Estado.VOLTA:
			return casa
		Estado.RONDA:
			return _destino
	return Vector3.INF


func _pisavel(x: float, z: float) -> bool:
	return mapa.agua(x, z) == -INF and mapa.normal_em(x, z).y > 0.8


func _process(delta: float) -> void:
	atualizar_tiros(delta)
	if pose_foto >= 0:
		_lente_brilho(1.0 + pose_foto * 2.0)
		return
	if _passo_base(delta):
		_deitar_no_terreno(delta)
		return
	_corpo.basis = _corpo.basis.slerp(Basis.IDENTITY, 1.0 - exp(-6.0 * delta))
	_tiro_t = maxf(0.0, _tiro_t - delta)
	var vel := 0.0
	var olho := centro() + Vector3(0, altura_m * 0.3, 0)
	alerta_t = maxf(0.0, alerta_t - delta)
	var ve := alvo_visivel(PERDER if alerta_t > 0.0 else VER, olho)
	var alvo_p := centro_alvo() if alvo else global_position
	var para_alvo := alvo_p - global_position
	var dist := Vector2(para_alvo.x, para_alvo.z).length()
	var guiando := guiado.is_finite()
	if ve:
		visto_em = alvo.global_position
		sem_ver = 0.0
	else:
		sem_ver += delta
	recuo_folga = maxf(0.0, recuo_folga - delta)
	if arvore and not guiando:
		arvore.tick()
	if guiando:
		var pg := guiado - global_position
		pg.y = 0.0
		if guiado != _guiado_de:
			_guiado_de = guiado
			_guiado_t = 0.0
		_guiado_t += delta
		# chegou, ou não chega (um ponto que ficou atrás de alguma coisa): larga o guiado. Sem o prazo, um
		# Espadachim da Fundição rodou em volta de uma mureta para sempre (visto pelo usuário, 2026-11-20)
		if pg.length() < 1.3 or _guiado_t > PRAZO_GUIADO:
			guiado = Vector3.INF
			estado = Estado.CACA
			_recarga = 1.0
		else:
			_rumo = pg.normalized()
			vel = vel_caca
	match (-1 if guiando else int(estado)):
		Estado.RONDA:
			if ve:
				estado = Estado.CACA
				_recarga = 1.0
			elif _pausa > 0.0:
				_pausa -= delta
			else:
				var para := _destino - global_position
				para.y = 0.0
				if para.length() < 0.7:
					_destino = _ponto_ronda()
					_pausa = _rng.randf_range(1.0, 4.0)
				else:
					_rumo = para.normalized()
					vel = VEL_RONDA
		Estado.CACA:
			if arvore == null and (alvo == null or alvo.em_pane or alvo.graca_pane > 0.0 or para_alvo.length() > PERDER):
				estado = Estado.VOLTA
				_aviso = 0.0
			else:
				if dist > 0.3:
					_rumo = Vector3(para_alvo.x, 0, para_alvo.z).normalized()
				var dy := (alvo.global_position.y - global_position.y) if alvo else 0.0
				# chega até a distância de tiro; perto demais, recua de frente para o robô
				if _aviso <= 0.0 and _tiro_t <= 0.0:
					if corpo_a_corpo:
						# a lâmina: chega junto, até ficar bem dentro do alcance dela (antes parava na beira e
						# começava o golpe de longe, sem chegar: a lâmina passava no ar, visto pelo usuário)
						if dist > alcance() * 0.7:
							vel = vel_caca
						elif dist < alcance() * 0.3:
							vel = -vel_caca * 0.5
					elif dist > dist_tiro * 1.25:
						vel = vel_caca
					elif dist < dist_tiro * 0.55:
						vel = -vel_caca * 0.6
					elif rodeia:
						# corre em volta do robô, de lado para ele, e para na hora de atirar
						_rumo = _rumo.cross(Vector3.UP) * _lado
						vel = vel_caca
				elif corpo_a_corpo and _aviso > 0.0 and dist > alcance() * 0.5:
					# armando o golpe ele ainda avança: um passo do robô para trás não deixa a lâmina no ar
					vel = vel_caca * 1.15
				if _espera_t > 0.0:
					# o robô está onde ele não chega: espera de frente, até o robô sair de lá
					_espera_t -= delta
					if alvo and alvo.global_position.distance_to(_espera_de) > 1.5:
						_espera_t = 0.0
					elif vel > 0.0:
						vel = 0.0
				_recarga -= delta
				if (_aviso > 0.0 or _tiro_t > 0.0) and dist > 0.3:
					_rumo = Vector3(para_alvo.x, 0, para_alvo.z).normalized()
				if _aviso > 0.0 and _tiro_t <= 0.0 and mech and _aviso <= mech.tempo_do_tiro():
					_tiro_t = mech.tempo_do_tiro() + 0.75  # a animação começa antes, para o tiro sair com o braço estendido
				if _aviso > 0.0:
					_aviso -= delta
					if _aviso <= 0.0:
						disparos += 1
						_tiro_t = maxf(_tiro_t, 0.5)
						if corpo_a_corpo:
							# o golpe só pega se o robô ainda estiver ao alcance (e não muito acima ou abaixo)
							if dist < alcance() * 1.2 and absf(dy) < altura_m and alvo and not alvo.em_pane:
								alvo.levar_golpe(_rumo, forca_golpe, dano_golpe)
								golpes_dados += 1
						else:
							_rajada_resta = rajada
							_rajada_t = 0.0
				elif _recarga <= 0.0 and ve and (dist < alcance() and absf(dy) < altura_m if corpo_a_corpo else para_alvo.length() < dist_tiro * 2.2):
					_aviso = (TEMPO_AVISO_GOLPE if corpo_a_corpo else TEMPO_AVISO) * aviso_mult
					_recarga = tempo_tiro
		Estado.VOLTA:
			var para := casa - global_position
			para.y = 0.0
			if para.length() < 2.0:
				estado = Estado.RONDA
				_destino = casa
				_pausa = 1.0
			else:
				_rumo = para.normalized()
				vel = vel_caca * 0.7
			if ve and para_alvo.length() < VER * 0.6:
				estado = Estado.CACA
		Estado.PROCURA:
			# vai até onde o robô foi visto por último e fica olhando em volta
			var ate := pista - global_position
			ate.y = 0.0
			if pista.is_finite() and ate.length() > 2.5:
				_rumo = ate.normalized()
				vel = vel_caca * 0.8
			else:
				procura_t += delta
				_rumo = _rumo.rotated(Vector3.UP, 1.1 * delta * _lado)
		Estado.RECUA:
			# quente: anda de costas, de frente para o robô, sem atirar, até esfriar
			recuo_t += delta
			_aviso = 0.0
			if dist > 0.3:
				_rumo = Vector3(para_alvo.x, 0, para_alvo.z).normalized()
			if dist < dist_tiro * 2.6:
				vel = -vel_caca * 0.75
	# a rajada sai aos poucos, cada tiro com o erro de mira dele
	if _rajada_resta > 0 and mech:
		_rajada_t -= delta
		if _rajada_t <= 0.0:
			_rajada_resta -= 1
			_rajada_t = 0.13 if tipo_tiro == "bala" else 0.28
			_tiro_t = maxf(_tiro_t, 0.3)
			atirar_em(mech.ponto_tiro() + _rumo * 0.35, alvo_p, tipo_tiro, espalha)
	if vel != 0.0:
		# tronco, pedra, ruína ou a base no caminho: dá a volta pelo rumo livre mais perto do que queria
		var quer := _rumo * signf(vel)
		var raio := altura_m * 0.3
		# quanto olha à frente: não passa de onde quer chegar. Olhando 2 m adiante de um ponto colado numa
		# mureta, o caminho direto dava "fechado" mesmo com o ponto livre, e o robô rodava a mureta sem chegar
		var olha := maxf(absf(vel) * 0.35, raio * 1.6)
		var chegar := guiado if guiado.is_finite() else _meta()
		if vel > 0.0 and chegar.is_finite():
			olha = minf(olha, maxf(Vector2(chegar.x - global_position.x, chegar.z - global_position.z).length(), raio * 0.6))
		var anda := Obstaculos.rumo_livre(mapa, global_position, quer, olha, raio, _lado_desvio, _pisavel)
		if _atravessa_t > 0.0:
			# já rodou demais em volta da mesma coisa sem chegar: segue reto por um instante, por cima dela
			_atravessa_t -= delta
			anda = quer
		if anda != Vector3.ZERO and anda.dot(quer) < 0.99:
			desvios += 1
			_lado_desvio = 1.0 if quer.cross(anda).y > 0.0 else -1.0  # segue a volta pelo lado em que começou
		if anda == Vector3.ZERO:
			vel = 0.0
		else:
			global_position += anda * absf(vel) * delta
			if vel > 0.0 and estado != Estado.CACA and estado != Estado.RECUA:
				_rumo = anda  # na caça ele continua de frente para o robô, andando de lado se for preciso
		# rodando em volta da mesma coisa: desviando quase o tempo todo, sem chegar mais perto de onde quer ir
		# e sem sair de perto de onde estava. Na forja as máquinas ficavam rodando numa planta ou numa esteira
		# com o robô do outro lado (visto pelo usuário em 2026-11-18). O primeiro teste comparava a posição
		# com a de 4 s antes, e quem corre em volta da coluna do guindaste dá uma volta e meia nesse tempo e
		# fica do outro lado do círculo: continuava rodando (visto de novo em 2026-11-20). Primeiro troca o
		# lado da volta; se continuar, atravessa. Contornar uma parede comprida não conta: aí ele vai longe.
		var meta := _meta()
		# o robô em cima de alguma coisa (dentro de um obstáculo, no chão) e o caminho direto fechado: nem tenta a
		# volta, espera ali
		if estado == Estado.CACA and vel > 0.0 and _espera_t <= 0.0 and anda.dot(quer) < 0.99 and alvo \
				and Vector2(meta.x - global_position.x, meta.z - global_position.z).length() < 6.0 \
				and not Obstaculos.livre(mapa, meta.x, meta.z, 0.3):
			_nao_chega()
		if vel > 0.0 and meta.is_finite() and int(estado) == _meta_estado:
			var dm := Vector2(meta.x - global_position.x, meta.z - global_position.z).length()
			_meta_t += delta
			_meta_andou += anda.length() * absf(vel) * delta
			if anda.dot(quer) < 0.99:
				_meta_desvio += delta
			if dm < _meta_melhor - 0.6:
				_meta_melhor = dm
				_meta_t = 0.0
				_meta_desvio = 0.0
				_meta_p = global_position
				_meta_andou = 0.0
				_sem_avanco = 0
			elif _meta_t >= 1.8 and (_meta_andou >= 3.0 or _meta_t >= 8.0):
				# rodar é andar bastante e acabar perto de onde começou; contornar uma fila de pedras devagar
				# (a ronda anda a 1,2 m/s) leva para longe dali, então não conta (o teste antigo, com uma
				# distância fixa de 5,5 m, travava a ronda numa fila de pedras)
				var reta := Vector2(global_position.x - _meta_p.x, global_position.z - _meta_p.z).length()
				if _meta_desvio > _meta_t * 0.6 and _meta_andou >= 3.0 and reta < _meta_andou * 0.45:
					_sem_avanco += 1
					voltas_cortadas += 1
					_lado_desvio = -_lado_desvio
					if _sem_avanco >= 2:
						_sem_avanco = 0
						_nao_chega()
				_meta_melhor = dm
				_meta_t = 0.0
				_meta_desvio = 0.0
				_meta_p = global_position
				_meta_andou = 0.0
		elif vel > 0.0:
			_meta_estado = int(estado)
			_meta_melhor = INF
			_meta_t = 0.0
			_meta_desvio = 0.0
			_meta_p = global_position
			_meta_andou = 0.0
		# destravar: quer andar e não sai do lugar
		_trava_t += delta
		if _trava_t >= 1.2:
			if global_position.distance_to(_trava_p) < 0.5:
				destravou += 1
				_lado_desvio = -_lado_desvio  # tenta a volta pelo outro lado
				if estado == Estado.RONDA or estado == Estado.VOLTA:
					_destino = _ponto_ronda()
					if estado == Estado.VOLTA:
						estado = Estado.RONDA
				elif rodeia:
					_lado = -_lado
			_trava_t = 0.0
			_trava_p = global_position
	else:
		_trava_t = 0.0
		_trava_p = global_position
	global_position.y = mapa.altura(global_position.x, global_position.z)
	rotation.y = lerp_angle(rotation.y, atan2(-_rumo.x, -_rumo.z), 1.0 - exp(-6.0 * delta))
	if mech:
		mech.alvo_mira = alvo_p if alvo else Vector3.INF
		if _tiro_t > 0.0:
			mech.tocar("Shoot", 1.0, 0.05)
		elif absf(vel) > 2.0:
			mech.tocar("Run", 1.0 if vel > 0.0 else -0.8)
		elif vel != 0.0:
			mech.tocar("Walk", 1.1)
		else:
			mech.tocar("Idle")
	_lente_brilho(6.0 if _aviso > 0.0 else (2.4 if estado == Estado.CACA else (1.5 if estado == Estado.PROCURA else 0.8)))
