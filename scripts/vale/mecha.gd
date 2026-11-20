class_name Mecha
extends Vigia
## Mecha: um robô inimigo sorteado (InimigoVisual): o nosso robô com outra pintura, em cinco comuns (Sentinela,
## Espadachim, Couraça, Batedor e Artilheiro) e três chefes (Capataz, Canhoneiro e Guardião). O jeito de lutar
## sai da ficha: com a lâmina chega junto e bate em arco; com o cano na luva atira de braço estendido; com
## mísseis nas costas atira de mais longe e mais devagar; o Guardião atira de longe e bate de perto.
## Por cima da IA do Vigia, as mecânicas do robô do jogador que não são voar nem nadar: os ágeis esquivam de
## lado quando o robô mira neles ou acerta um tiro, os de lâmina pulam em cima do robô para golpear, e todos
## pulam o que os prende no caminho.

var ficha := {}
var arma_forcada := ""  # "corpo", "bala", "pesado" ou "missil" (InimigoVisual.forcar); "" sorteia
var modelo_forcado := ""  # o robô da ficha ("batedor", "couraca"...; InimigoVisual.forcar_modelo): as ondas com tema
var agil := 0.3  # 0 a 1: quanto pula e esquiva
var misto := false  # atira de longe e, de perto, bate de lâmina (o Guardião)
var pulos := 0  # testes
var pulos_altos := 0  # testes: saltos altos contra o robô pairando logo acima
var esquivas := 0  # testes
const PERTO_MISTO := 4.5
const GRAVIDADE := 18.0

var _vis: InimigoVisual
var _salto_y := 0.0
var _salto_vy := 0.0
var _impulso := Vector3.ZERO  # andar extra de lado ou para a frente (esquiva e pulo de ataque), m/s
var _impulso_t := 0.0
var _espera_esquiva := 2.0
var _espera_pulo := 3.0
var _destravou_visto := 0
var _furou_visto := 0
var _calor_visto := 0.0


func _init() -> void:
	altura_m = 1.6
	motor = "carrapato_loop"


func _montar_corpo() -> void:
	InimigoVisual.forcar = arma_forcada
	InimigoVisual.forcar_modelo = modelo_forcado
	var v := InimigoVisual.montar(semente, altura_m, (mapa as Clareira)._tex if mapa is Clareira else null, chefe)
	InimigoVisual.forcar = ""
	InimigoVisual.forcar_modelo = ""
	_vis = v
	altura_m = v.altura
	_acerto.position.y = altura_m * 0.6
	_fumaca.position.y = altura_m * 0.5
	for cs in _acerto.get_children():
		if cs is CollisionShape3D and (cs as CollisionShape3D).shape is SphereShape3D:
			((cs as CollisionShape3D).shape as SphereShape3D).radius = raio_acerto() * 0.8
	mech = v
	v.chao = func(x: float, z: float) -> float: return mapa.altura(x, z)
	_corpo.add_child(v)
	ficha = v.ficha
	agil = float(ficha.get("agil", 0.3))
	misto = bool(ficha.get("misto", false))
	var porte: float = ficha["porte"]
	match String(ficha["arma"]):
		"corpo":
			# os de lâmina são os ágeis: chegam correndo e golpeiam seguido
			corpo_a_corpo = true
			dist_tiro = 2.2
			tempo_tiro = lerpf(1.7, 1.1, agil)
			vel_caca = 5.4 + 1.2 * agil
			forca_golpe = 6.0
		"costas":
			# mísseis: lentos, viram para o robô e estouram; dá para fugir deles
			dist_tiro = 30.0
			vel_caca = 3.2
			tipo_tiro = "missil"
			rajada = 2 if String(ficha["costas"]) == "misseis2" else 1
			tempo_tiro = 5.0
			espalha = 0.12
		_:
			dist_tiro = 18.0
			vel_caca = 4.2
			_arma_de_tiro(String(ficha["mao"]))
	if misto:
		# o Guardião começa atirando; perto do robô troca para a lâmina (`_modo_misto`)
		corpo_a_corpo = false
		_arma_de_tiro("fuzil")
		rajada = 2
		v.ataque = "tiro"
	alcance_golpe = altura_m * 1.45  # do meio do corpo até a ponta da lâmina, com o braço estendido
	vel_caca *= 1.0 - 0.18 * porte
	calor_tiro = [34.0, 26.0, 21.0][clampi(int(ficha["armaduras"]), 0, 2)]
	if chefe:
		calor_tiro *= 0.5
		forca_golpe *= 1.3
		vel_caca *= 0.8
		dist_tiro *= 1.5 if not corpo_a_corpo else 1.6
	_espera_esquiva = _rng.randf_range(1.0, 3.0)
	_espera_pulo = _rng.randf_range(1.5, 4.0)


func _arma_de_tiro(mao: String) -> void:
	match mao:
		"metralha":
			tipo_tiro = "bala"  # rajada de três
			rajada = 3
			tempo_tiro = 2.6
			espalha = 0.045
		"canhao":
			tipo_tiro = "pesado"
			rajada = 2 if String(ficha.get("modelo", "")) == "canhoneiro" else 1
			tempo_tiro = 2.4
			espalha = 0.025
		_:
			tipo_tiro = "bala"  # fuzil: um tiro certeiro
			tempo_tiro = 1.6
			espalha = 0.018


## O Guardião: perto do robô bate de lâmina; longe, atira. Só troca entre um ataque e outro.
func _modo_misto() -> void:
	if not misto or alvo == null or _aviso > 0.0 or _tiro_t > 0.0 or _rajada_resta > 0:
		return
	var perto := Vector2(alvo.global_position.x - global_position.x, alvo.global_position.z - global_position.z).length() < PERTO_MISTO * (1.2 if corpo_a_corpo else 1.0)
	if perto == corpo_a_corpo:
		return
	corpo_a_corpo = perto
	if perto:
		dist_tiro = 2.2 * 1.6
		tempo_tiro = 1.5
		_recarga = minf(_recarga, 0.4)
	else:
		_arma_de_tiro("fuzil")
		rajada = 2
		dist_tiro = 18.0 * 1.5
	_vis.ataque = "corpo" if perto else "tiro"


func _process(delta: float) -> void:
	_modo_misto()
	super._process(delta)
	if pose_foto >= 0 or _vis == null:
		return
	_mexer(delta)
	# o aviso na arma: uma bola de luz na boca do cano (ou na mão da lâmina) que cresce enquanto ele arma o
	# ataque, além dos olhos (dá para ver quem vai atirar antes do tiro)
	var t_aviso := TEMPO_AVISO_GOLPE if corpo_a_corpo else TEMPO_AVISO
	_vis.carga(0.15 + 0.85 * clampf(1.0 - _aviso / t_aviso, 0.0, 1.0) if _aviso > 0.0 and not desligada else 0.0)


## Pulo e esquiva, por cima do andar do Vigia (que põe o corpo no chão a cada quadro): a altura do pulo e o
## empurrão de lado ou para a frente somam depois.
func _mexer(delta: float) -> void:
	if desligada:
		if _salto_y > 0.0:
			global_position.y = mapa.altura(global_position.x, global_position.z)  # desligou no ar: cai no chão
		_salto_y = 0.0
		_salto_vy = 0.0
		_impulso_t = 0.0
		_vis.no_ar = false
		_vis.esquivando = 0.0
		return
	_espera_esquiva -= delta
	_espera_pulo -= delta
	var no_ar := _salto_y > 0.0 or _salto_vy > 0.0
	var combate := estado == Estado.CACA and alvo != null and not alvo.em_pane
	var para := (alvo.global_position - global_position) if alvo else Vector3.ZERO
	para.y = 0.0
	var dist := para.length()
	var atacando := _aviso > 0.0 or _tiro_t > 0.0
	if combate and not no_ar and not atacando:
		var levou := calor > _calor_visto + 1.0
		var alto := alvo.global_position.y - global_position.y
		# o robô pairando logo acima, fora do alcance da lâmina: salta alto e golpeia no topo do salto (pairar a
		# 2–4 m do chão deixava o robô intocável pelos de lâmina). O topo chega junto com o fim do aviso
		if corpo_a_corpo and _espera_pulo <= 0.0 and dist < 7.0 and _recarga < 0.6 and alto > altura_m * 0.7 and alto < 4.8:
			_empurrar(para.normalized() * maxf(0.0, dist - 1.0) / TEMPO_AVISO_GOLPE, TEMPO_AVISO_GOLPE, GRAVIDADE * TEMPO_AVISO_GOLPE)
			_aviso = TEMPO_AVISO_GOLPE
			_recarga = tempo_tiro
			pulos += 1
			pulos_altos += 1
			_espera_pulo = lerpf(4.5, 2.2, agil) + _rng.randf_range(0.0, 1.0)
		# esquiva: o robô mirando nele (ou um tiro que acabou de pegar) e ele é ágil
		elif _espera_esquiva <= 0.0 and dist > 2.0 and (levou or _mirado()) and _rng.randf() < agil:
			var lado := para.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
			_empurrar(lado * lerpf(6.0, 9.0, agil), 0.32, 3.2)
			_vis.esquivando = 0.32
			esquivas += 1
			_espera_esquiva = lerpf(5.0, 1.6, agil) + _rng.randf_range(0.0, 1.5)
		# pulo de ataque: os de lâmina saltam em cima do robô de uns metros e já chegam golpeando
		elif corpo_a_corpo and agil >= 0.5 and _espera_pulo <= 0.0 and dist > 3.5 and dist < 9.0 and _recarga < 0.6:
			var tempo_ar := 2.0 * 6.0 / GRAVIDADE
			_empurrar(para.normalized() * minf(10.0, (dist - 1.6) / tempo_ar), tempo_ar, 6.0)
			_recarga = minf(_recarga, tempo_ar * 0.5)
			pulos += 1
			_espera_pulo = lerpf(7.0, 3.0, agil) + _rng.randf_range(0.0, 2.0)
	# preso no caminho (o Vigia trocou de plano) ou desistindo de dar a volta (vai passar por cima): pula
	if destravou != _destravou_visto or furou != _furou_visto:
		_destravou_visto = destravou
		_furou_visto = furou
		if not no_ar:
			_empurrar(_rumo * 3.0, 0.6, 5.5)
			pulos += 1
	_calor_visto = calor
	# no ar e o empurrão
	if _salto_y > 0.0 or _salto_vy > 0.0:
		_salto_vy -= GRAVIDADE * delta
		_salto_y += _salto_vy * delta
		if _salto_y <= 0.0:
			_salto_y = 0.0
			_salto_vy = 0.0
			_vis.pousando = 0.25
	if _impulso_t > 0.0:
		_impulso_t -= delta
		var passo := _impulso * delta
		var nx := global_position.x + passo.x
		var nz := global_position.z + passo.z
		if _pisavel(nx, nz) and Obstaculos.livre(mapa, nx, nz, altura_m * 0.3):
			global_position.x = nx
			global_position.z = nz
		else:
			_impulso_t = 0.0
	_vis.esquivando = maxf(0.0, _vis.esquivando - delta)
	global_position.y = mapa.altura(global_position.x, global_position.z) + _salto_y
	_vis.no_ar = _salto_y > 0.05


func _empurrar(vel: Vector3, tempo: float, sobe: float) -> void:
	_impulso = vel
	_impulso_t = tempo
	_salto_vy = sobe


## O robô está mirando nele: a linha da câmera passa perto do corpo.
func _mirado() -> bool:
	if alvo == null or alvo.camera == null or not alvo.mirando_agora():
		return false
	var de: Vector3 = alvo.camera.global_position
	var dir: Vector3 = alvo.camera.mira()
	var v := centro() - de
	var t := v.dot(dir)
	return t > 0.0 and (v - dir * t).length() < raio_acerto() * 2.0
