class_name Sons
extends Node
## Os sons da armadura: laços de vento, motor e arrancada, toques de estado, alarme de calor e cachoeiras.
## Os WAV saem de tools/montar_sons.py (gravações; assets/sons/); os três avisos (alarme, marcar, religar)
## ainda são sintetizados por tools/gerar_sons.py. Usa o barramento Master.
## Uso: crie o nó, atribua `armadura` e chame `iniciar()`.

const VENTO_DB := -8.0
const MOTOR_DB := -12.0
const ARRANCADA_DB := -10.0
const TOQUE_DB := -6.0
const CACHOEIRA_DB := -6.0
const SILENCIO_DB := -60.0
const PASSO_DB := -9.0
const PASSO_ANDANDO := 0.75  # metros entre pisadas, andando
const PASSO_CORRENDO := 1.25
const PASSO_CORRE_VEL := 5.0
const TIRO_DB := -8.0
const GOLPE_DB := -2.0
const FOLHAGEM_DB := -8.0

## Para os testes: anota o nome de cada toque (os laços não entram aqui).
static var registro: Array[String] = []
static var registrar := false

var armadura: Armadura

var _vento: AudioStreamPlayer
var _motor: AudioStreamPlayer
var _arrancada: AudioStreamPlayer
var _estado_antes: int = Armadura.Estado.CHAO
var _impulso_antes := 0.0
var _marcador_antes := false
var _andado := 0.0


## Liga os laços e conecta os sinais da armadura. Chame depois de atribuir `armadura`.
func iniciar() -> void:
	_vento = _laco("vento_loop", VENTO_DB)
	_motor = _laco("motor_loop", MOTOR_DB)
	_arrancada = _laco("arrancada_loop", ARRANCADA_DB)
	_vento.volume_db = SILENCIO_DB
	_motor.volume_db = SILENCIO_DB
	_arrancada.volume_db = SILENCIO_DB
	armadura.estado_mudou.connect(_ao_mudar_estado)
	armadura.superaqueceu.connect(_ao_superaquecer)
	armadura.religou.connect(_ao_religar)
	armadura.golpe_chao.connect(func(_onde: Vector3) -> void: _toque("golpe_chao", GOLPE_DB))
	_estado_antes = armadura.estado
	_impulso_antes = armadura.impulso
	_marcador_antes = armadura.tem_marcador


## Um som de cachoeira no mundo, em `pos`. Fica tocando em laço e some com a distância.
func cachoeira_em(pos: Vector3) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = Som.laco_stream("cachoeira_loop")
	p.volume_db = CACHOEIRA_DB
	p.unit_size = 30.0
	p.max_distance = 260.0
	add_child(p)
	p.global_position = pos
	p.play()


func _process(delta: float) -> void:
	if armadura == null or _vento == null:
		return
	_atualizar_laços(delta)
	_toques_por_variavel()
	_passos(delta)


func _atualizar_laços(delta: float) -> void:
	var v := armadura.velocity.length()
	# Vento: só conta fora do chão ou acima de 12 m/s; mudo abaixo de ~6 m/s, cheio a 60 m/s.
	var conta := not armadura.is_on_floor() or v > 12.0
	var forca := clampf((v - 6.0) / 54.0, 0.0, 1.0) if conta else 0.0
	var alvo_vento := lerpf(-40.0, VENTO_DB, forca) if forca > 0.0 else SILENCIO_DB
	_vento.volume_db = _suaviza(_vento.volume_db, alvo_vento, delta)
	_vento.pitch_scale = lerpf(0.75, 1.35, forca)
	# Motor: com a turbina ligada, o tom sobe com a velocidade.
	var alvo_motor := MOTOR_DB if armadura.motor_ligado() else SILENCIO_DB
	_motor.volume_db = _suaviza(_motor.volume_db, alvo_motor, delta)
	_motor.pitch_scale = lerpf(0.8, 1.5, clampf(v / 60.0, 0.0, 1.0))
	# Arrancada: a turbina rasga.
	var alvo_arr := ARRANCADA_DB if armadura.arrancada else SILENCIO_DB
	_arrancada.volume_db = _suaviza(_arrancada.volume_db, alvo_arr, delta)
	_arrancada.pitch_scale = lerpf(0.95, 1.4, clampf(v / 60.0, 0.0, 1.0))


func _toques_por_variavel() -> void:
	# Pulo duplo ou esquiva: o impulso cruza 0.9 vindo de baixo de 0.5.
	var impulso := armadura.impulso
	if _impulso_antes < 0.5 and impulso >= 0.9:
		_toque("esquiva" if armadura.esquivando > 0.0 else "pulo_duplo")
	_impulso_antes = impulso
	# Marcador: passa a existir.
	if armadura.tem_marcador and not _marcador_antes:
		_toque("marcar")
	_marcador_antes = armadura.tem_marcador


## O tiro da mão (ligue em Tiro.disparou).
func ao_atirar(_origem: Vector3, _alvo: Vector3) -> void:
	_toque(Som.variacao("tiro", 3), TIRO_DB)


## Folhas ao atravessar uma copa (ligue em EfeitosMato.atravessou_copa).
func ao_atravessar_copa(_posicao: Vector3, _velocidade: float) -> void:
	_toque(Som.variacao("folhagem", 4), FOLHAGEM_DB)


## Pisadas: uma a cada tanto de chão andado, mais espaçadas na corrida. Sentado ou parado, nenhuma.
func _passos(delta: float) -> void:
	var v := Vector2(armadura.velocity.x, armadura.velocity.z).length()
	if armadura.estado != Armadura.Estado.CHAO or not armadura.is_on_floor() or v < 0.6:
		_andado = 0.0
		return
	_andado += v * delta
	var passada := PASSO_CORRENDO if v > PASSO_CORRE_VEL else PASSO_ANDANDO
	if _andado >= passada:
		_andado = 0.0
		var db := PASSO_DB + (2.0 if v > PASSO_CORRE_VEL else 0.0) - (5.0 if armadura.postura == 1 else 0.0)
		_toque(Som.variacao("passo", 6), db, 0.08)


func _ao_mudar_estado(novo: int) -> void:
	var antes := _estado_antes
	_estado_antes = novo
	match novo:
		Armadura.Estado.DECOLAGEM:
			_toque("decolagem")
		Armadura.Estado.POUSO:
			_toque("pouso_pesado")
		Armadura.Estado.CHAO:
			if antes == Armadura.Estado.AR or antes == Armadura.Estado.VOO \
					or antes == Armadura.Estado.PLANAR or antes == Armadura.Estado.PAIRAR:
				_toque("pouso_leve")


func _ao_superaquecer() -> void:
	_toque("alarme_calor")
	_toque("motor_apaga")


func _ao_religar() -> void:
	_toque("religar")


# ---------------------------------------------------------------- ajudantes

func _suaviza(atual: float, alvo: float, delta: float) -> float:
	return lerpf(atual, alvo, 1.0 - exp(-4.0 * delta))


## Laço sem posição, no barramento Master.
func _laco(nome: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Som.laco_stream(nome)
	p.volume_db = volume_db
	add_child(p)
	p.play()
	return p


## Toque curto e único, que se solta no fim.
func _toque(nome: String, db := TOQUE_DB, tom := 0.03) -> void:
	if registrar:
		registro.append(nome)
	var p := AudioStreamPlayer.new()
	p.stream = Som.stream(nome)
	p.volume_db = db
	p.pitch_scale = randf_range(1.0 - tom, 1.0 + tom)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
