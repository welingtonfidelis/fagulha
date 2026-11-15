class_name SomAmbiente
extends Node3D
## O som do vale: mata de dia e de noite (com a transição pela hora), chuva, trovão e a água do riacho
## e da lagoa da Clareira. Os WAV vêm de tools/gerar_sons.py (assets/sons/).
## Uso: crie o nó, atribua `ouvinte` (o robô ou a câmera), depois add_child e chame `riacho_em(pontos)`.
## Sem CicloDia.atual (null), toca só a mata de dia.

const PASTA := "res://assets/sons/%s.wav"
const MATA_DB := -14.0
const NOITE_DB := -16.0
const CHUVA_DB := -8.0
const RIACHO_DB := -10.0
const TROVAO_DB := -6.0
const REDUCAO_CHUVA_DB := -8.0  # a mata se cala com chuva forte
const SILENCIO_DB := -60.0
const SUAVIDADE := 2.0  # quanto maior, mais rápido o volume segue o alvo
const RIACHO_UNIT_SIZE := 6.0
const RIACHO_MAX_DIST := 45.0
const TROVAO_DIST := 120.0  # metros do ouvinte, numa direção sorteada

## Quem ouve (o robô ou a câmera). Usado para pôr o trovão ao longe, numa direção sorteada.
var ouvinte: Node3D

## Volumes atuais, em dB (para teste).
var debug := {}

var _mata_dia: AudioStreamPlayer
var _mata_noite: AudioStreamPlayer
var _chuva: AudioStreamPlayer
var _riacho_players: Array[AudioStreamPlayer3D] = []
var _cache := {}
var _contagem_trovao := 0.0


func _ready() -> void:
	_mata_dia = _laco("mata_dia_loop", SILENCIO_DB)
	_mata_noite = _laco("mata_noite_loop", SILENCIO_DB)
	_chuva = _laco("chuva_loop", SILENCIO_DB)
	_contagem_trovao = randf_range(8.0, 20.0)


## Põe a água do riacho e da lagoa para tocar. `pontos` são os pontos do riacho (x, z); usa 3 deles,
## espaçados, e a lagoa da Clareira. Tudo na altura NIVEL. Chamar de novo troca os sons antigos.
func riacho_em(pontos: Array[Vector3]) -> void:
	for p in _riacho_players:
		p.queue_free()
	_riacho_players.clear()
	if pontos.is_empty():
		return
	var n := pontos.size()
	var posicoes: Array[Vector3] = []
	for k in 3:
		var i := roundi(float(k) * (n - 1) / 2.0)
		posicoes.append(pontos[i])
	posicoes.append(Vector3(Clareira.LAGOA.x, Clareira.NIVEL, Clareira.LAGOA.y))
	for pos in posicoes:
		var p := AudioStreamPlayer3D.new()
		p.stream = _laco_stream("riacho_loop")
		p.volume_db = RIACHO_DB
		p.unit_size = RIACHO_UNIT_SIZE
		p.max_distance = RIACHO_MAX_DIST
		add_child(p)
		p.global_position = Vector3(pos.x, Clareira.NIVEL, pos.z)
		p.play()
		_riacho_players.append(p)


func _process(delta: float) -> void:
	var com_ciclo := CicloDia.atual != null
	var hora := 12.0
	var chuva := 0.0
	if com_ciclo:
		hora = CicloDia.atual.hora
		chuva = CicloDia.atual.chuva
	var noite := peso_noite(hora) if com_ciclo else 0.0
	var dia := 1.0 - noite
	var reducao := REDUCAO_CHUVA_DB * clampf((chuva - 0.3) / 0.7, 0.0, 1.0)

	var alvo_dia := _db_com_peso(MATA_DB + reducao, dia)
	var alvo_noite := _db_com_peso(NOITE_DB + reducao, noite)
	var alvo_chuva := SILENCIO_DB if chuva < 0.002 else CHUVA_DB + linear_to_db(clampf(chuva, 0.0, 1.0))

	_mata_dia.volume_db = _suaviza(_mata_dia.volume_db, alvo_dia, delta)
	_mata_noite.volume_db = _suaviza(_mata_noite.volume_db, alvo_noite, delta)
	_chuva.volume_db = _suaviza(_chuva.volume_db, alvo_chuva, delta)

	_atualizar_trovao(delta, chuva)

	debug["peso_dia"] = dia
	debug["peso_noite"] = noite
	debug["mata_dia_db"] = _mata_dia.volume_db
	debug["mata_noite_db"] = _mata_noite.volume_db
	debug["chuva_db"] = _chuva.volume_db


## Peso da noite (0 a 1) pela hora: noite plena antes das 5,5 e depois das 20; o amanhecer
## passa de 5,5 a 6,5 e o anoitecer de 19 a 20 (cerca de 1 hora de jogo cada).
static func peso_noite(hora: float) -> float:
	if hora < 5.5 or hora >= 20.0:
		return 1.0
	if hora < 6.5:
		return smoothstep(0.0, 1.0, 1.0 - (hora - 5.5))
	if hora < 19.0:
		return 0.0
	return smoothstep(0.0, 1.0, hora - 19.0)


func _atualizar_trovao(delta: float, chuva: float) -> void:
	if chuva <= 0.6:
		_contagem_trovao = randf_range(8.0, 20.0)
		return
	_contagem_trovao -= delta
	if _contagem_trovao <= 0.0:
		_contagem_trovao = randf_range(25.0, 60.0)
		_trovao()


func _trovao() -> void:
	var s := _som("trovao")
	if ouvinte != null and ouvinte.is_inside_tree():
		var ang := randf() * TAU
		var p := AudioStreamPlayer3D.new()
		p.stream = s
		p.volume_db = TROVAO_DB
		p.unit_size = 30.0
		p.max_distance = 400.0
		add_child(p)
		p.global_position = ouvinte.global_position \
				+ Vector3(cos(ang), 0.0, sin(ang)) * TROVAO_DIST + Vector3(0.0, 25.0, 0.0)
		p.play()
		p.finished.connect(p.queue_free)
	else:
		var q := AudioStreamPlayer.new()
		q.stream = s
		q.volume_db = TROVAO_DB
		add_child(q)
		q.play()
		q.finished.connect(q.queue_free)


# ---------------------------------------------------------------- ajudantes

## dB de um som com peso (0 a 1) somado a um volume base; abaixo de ~-60 dB, mudo.
func _db_com_peso(base_db: float, peso: float) -> float:
	if peso < 0.001:
		return SILENCIO_DB
	return maxf(SILENCIO_DB, base_db + linear_to_db(peso))


func _suaviza(atual: float, alvo: float, delta: float) -> float:
	return lerpf(atual, alvo, 1.0 - exp(-SUAVIDADE * delta))


## Laço sem posição, no barramento Master.
func _laco(nome: String, volume_db_inicial: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _laco_stream(nome)
	p.volume_db = volume_db_inicial
	add_child(p)
	p.play()
	return p


## Cópia do WAV com o laço ligado, do início até o último quadro.
func _laco_stream(nome: String) -> AudioStreamWAV:
	var base: AudioStreamWAV = load(PASTA % nome)
	var s := base.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(base.get_length() * base.mix_rate)
	return s


func _som(nome: String) -> AudioStream:
	if not _cache.has(nome):
		_cache[nome] = load(PASTA % nome)
	return _cache[nome]
