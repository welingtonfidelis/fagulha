class_name MusicaPasseio
extends Node
## Música de vez em quando (2026-11-19): o passeio era só ambiente e motor. Três temas curtos e leves, feitos
## por `tools/musica_passeio.py`, entram em momentos escolhidos e somem sozinhos:
##  - `lugar`: ao chegar pela primeira vez a um lugar com nome;
##  - `amanhecer`: quando o dia clareia;
##  - `voo`: depois de alguns segundos voando bem alto.
## Entre uma música e outra passam pelo menos cinco minutos, para não virar trilha de fundo. Não toca com
## uma memória aberta (ela tem a música dela) nem com o robô desligado.
## Quem cria passa `armadura`, `mapa`, `locais` e `memorias`.

const DESCANSO := 300.0
const VOLUME := -13.0
const ALTO := 90.0  # metros acima do chão para o voo contar como alto
const ALTO_TEMPO := 8.0

var armadura: Armadura
var mapa: Ilha
var locais: Locais
var memorias: Memorias
var tocadas := 0  # testes
var ultima := ""
var espera := 45.0  # o primeiro minuto do jogo fica sem música

var _toca: AudioStreamPlayer
var _vista: AudioStreamPlayer  # o laço calmo de apreciar a vista
var vista_tocando := false  # testes
var _alto := 0.0
var _hora_ant := -1.0


func _ready() -> void:
	_toca = AudioStreamPlayer.new()
	_toca.volume_db = -60.0
	add_child(_toca)
	_vista = AudioStreamPlayer.new()
	_vista.volume_db = -60.0
	_vista.stream = Som.laco_stream("musica_vista")
	add_child(_vista)
	if locais:
		locais.chegou.connect(func(_nome: String, primeira: bool) -> void:
			if primeira:
				tocar("lugar"))


## Pede uma música. Só entra se o descanso já passou e nada mais está tocando.
func tocar(nome: String) -> bool:
	if espera > 0.0 or _toca.playing:
		return false
	if (memorias and memorias.aberta != "") or (armadura and armadura.em_pane):
		return false
	# o rádio da base tocando perto: a música do passeio espera
	if RadioBase.tocando and armadura and armadura.global_position.distance_to(RadioBase.onde) < RadioBase.ALCANCE + 10.0:
		return false
	var s := Som.stream("musica_" + nome)
	if s == null:
		return false
	_toca.stream = s
	_toca.volume_db = -40.0
	_toca.play()
	create_tween().tween_property(_toca, "volume_db", VOLUME, 2.0)
	espera = DESCANSO + s.get_length()
	tocadas += 1
	ultima = nome
	return true


func _process(delta: float) -> void:
	espera = maxf(0.0, espera - delta)
	# apreciar a vista sempre tem música: um laço calmo que entra devagar e sai quando o jogador volta ao jogo
	var vendo: bool = armadura != null and armadura.contemplando and not (memorias and memorias.aberta != "")
	if vendo and not vista_tocando:
		vista_tocando = true
		if _vista.stream:
			if not _vista.playing:
				_vista.volume_db = -45.0
				_vista.play()
			create_tween().tween_property(_vista, "volume_db", VOLUME - 1.0, 2.5)
		if _toca.playing:
			create_tween().tween_property(_toca, "volume_db", -60.0, 1.0)  # a música do passeio dá a vez
	elif not vendo and vista_tocando:
		vista_tocando = false
		var tw := create_tween()
		tw.tween_property(_vista, "volume_db", -60.0, 1.6)
		tw.tween_callback(func() -> void:
			if not vista_tocando:
				_vista.stop())
	# uma memória aberta cala a música do passeio
	if _toca.playing and memorias and memorias.aberta != "":
		_toca.stop()
	var c := CicloDia.atual
	if c:
		if _hora_ant >= 0.0 and _hora_ant < 5.7 and c.hora >= 5.7 and c.hora < 6.5:
			tocar("amanhecer")
		_hora_ant = c.hora
	if armadura and mapa:
		var p := armadura.global_position
		if armadura.em_voo() and p.y - mapa.altura(p.x, p.z) > ALTO:
			_alto += delta
			if _alto > ALTO_TEMPO:
				tocar("voo")
				_alto = 0.0
		else:
			_alto = 0.0
