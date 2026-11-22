class_name SomAmbiente
extends Node3D
## O som do vale: mata de dia e de noite (com a transição pela hora), chuva, trovão e a água do riacho
## e da lagoa da Clareira, o rio do vale e o eco das cavernas. Os WAV saem de tools/montar_sons.py
## (gravações; créditos em CREDITOS.md).
## Debaixo d'água (2026-11-22; o usuário estranhou ouvir os grilos mergulhado): a natureza toda passa pelo
## barramento "Natureza", que ganha um passa-baixa forte e cai de volume; o Master ganha um passa-baixa leve (a
## música, o robô e os tiros ficam só um pouco abafados); e entram o ronco de debaixo d'água, bolhas de vez em
## quando e, ao entrar, o "splash" abafado (síntese de tools/sons_agua.py). Conta como debaixo d'água a câmera
## abaixo da lâmina (a mesma conta do véu azulado de EfeitosAgua) ou o robô nadando.
## Uso: crie o nó, atribua `ouvinte` (o robô ou a câmera), depois add_child e chame `riacho_em(pontos)`.
## Sem CicloDia.atual (null), toca só a mata de dia.

const MATA_DB := -14.0
const NOITE_DB := -16.0
const CHUVA_DB := -8.0
const RIACHO_DB := -10.0
const TROVAO_DB := -6.0
const REDUCAO_CHUVA_DB := -8.0  # a mata se cala com chuva forte
const SILENCIO_DB := -60.0
const FUNDO_DB := -17.0  # o fundo de floresta, por baixo dos pássaros e dos grilos
const FUNDO_NOITE_DB := -22.0
const CAVERNA_DB := -9.0
const ABAFA_CAVERNA_DB := -14.0  # quanto a mata e a chuva caem lá dentro
const RIO_DB := -8.0
const RIO_PASSO := 110.0  # metros entre um som e outro ao longo do rio
const SUAVIDADE := 2.0  # quanto maior, mais rápido o volume segue o alvo
const RIACHO_UNIT_SIZE := 6.0
const RIACHO_MAX_DIST := 45.0
const TROVAO_DIST := 120.0  # metros do ouvinte, numa direção sorteada
# debaixo d'água
const AGUA_DB := -9.0  # o ronco contínuo
const BOLHAS_DB := -16.0
const MERGULHO_DB := -6.0  # o splash de quem entra rápido; quem entra devagar ouve até 10 dB menos
const ABAFA_AGUA_DB := -18.0  # quanto a natureza cai, além do filtro
const CORTE_NATUREZA_HZ := 420.0  # só o grave da natureza passa: os grilos, os pássaros e as folhas somem
const CORTE_GERAL_HZ := 1500.0  # o resto (música, robô, tiros) fica só um pouco abafado
const SEM_CORTE_HZ := 18000.0
const AGUA_ENTRA := 0.35  # segundos para o som virar o de debaixo d'água
const AGUA_SAI := 0.55  # segundos para a natureza voltar
const AGUA_FOLGA := 0.06  # m: a câmera entra a isto abaixo da lâmina e sai a isto acima (não fica piscando)
const BUS_NATUREZA := &"Natureza"
const NOME_FILTRO := "abafa_agua"  # o passa-baixa que este nó põe no Master

## Quem ouve (o robô ou a câmera). Usado para pôr o trovão ao longe, numa direção sorteada. Sendo o robô,
## também diz se ele está nadando e de onde vem a lâmina d'água (`ilha.agua`).
var ouvinte: Node3D
## Quantos splashes e punhados de bolhas já tocaram (testes).
var mergulhos := 0
var bolhas := 0

## Volumes atuais, em dB (para teste).
var debug := {}

var _mata_dia: AudioStreamPlayer
var _mata_noite: AudioStreamPlayer
var _chuva: AudioStreamPlayer
var _fundo: AudioStreamPlayer
var _caverna: AudioStreamPlayer
var _na_caverna := 0.0
var _riacho_players: Array[AudioStreamPlayer3D] = []
var _contagem_trovao := 0.0
var _agua: AudioStreamPlayer  # o ronco de debaixo d'água (fora dela fica parado)
var _submerso := 0.0  # 0 fora, 1 debaixo d'água; segue o alvo em AGUA_ENTRA ou AGUA_SAI
var _cam_dentro := false
var _iniciado := false
var _rapidez_antes := 0.0
var _desde_mergulho := 10.0
var _contagem_bolhas := 2.0
var _bus := -1
var _filtro_natureza: AudioEffectLowPassFilter
var _filtro_geral: AudioEffectLowPassFilter
var _idx_geral := -1


func _ready() -> void:
	_preparar_barramentos()
	_mata_dia = _laco("mata_dia_loop", SILENCIO_DB)
	_mata_noite = _laco("mata_noite_loop", SILENCIO_DB)
	_chuva = _laco("chuva_loop", SILENCIO_DB)
	_fundo = _laco("mata_fundo_loop", SILENCIO_DB)
	_caverna = _laco("caverna_loop", SILENCIO_DB)
	_contagem_trovao = randf_range(8.0, 20.0)
	_agua = AudioStreamPlayer.new()
	_agua.stream = Som.laco_stream("agua_fundo_loop")
	_agua.volume_db = SILENCIO_DB
	add_child(_agua)


## Saindo de cena (o Main recarregou) debaixo d'água: tira o abafado, senão o jogo seguia surdo.
func _exit_tree() -> void:
	if _bus >= 0 and _bus < AudioServer.bus_count:
		AudioServer.set_bus_volume_db(_bus, 0.0)
		AudioServer.set_bus_effect_enabled(_bus, 0, false)
	if _idx_geral >= 0 and _idx_geral < AudioServer.get_bus_effect_count(0):
		AudioServer.set_bus_effect_enabled(0, _idx_geral, false)


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
		p.stream = Som.laco_stream("riacho_loop")
		p.volume_db = RIACHO_DB
		p.unit_size = RIACHO_UNIT_SIZE
		p.max_distance = RIACHO_MAX_DIST
		p.bus = BUS_NATUREZA
		add_child(p)
		p.global_position = Vector3(pos.x, Clareira.NIVEL, pos.z)
		p.play()
		_riacho_players.append(p)


## O rio do vale: um som a cada RIO_PASSO metros ao longo de cada curso (pontos já com a altura da água).
func rio_em(pontos: Array[Vector3]) -> void:
	for pos in pontos:
		if not pos.is_finite():
			continue
		var p := Som.laco3d(self, "rio_loop", RIO_DB, 9.0, 80.0)
		p.bus = BUS_NATUREZA
		p.global_position = pos


## 0 fora, 1 dentro do Sumidouro ou da Boca do Degelo (debaixo da terra, num vazio deles).
func _peso_caverna() -> float:
	if ouvinte == null:
		return 0.0
	var o := ouvinte.global_position + Vector3.UP * 1.5
	if Sumidouro.no_vazio(o) or BocaDegelo.no_vazio(o):
		return 1.0
	return 0.0


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

	_na_caverna = move_toward(_na_caverna, _peso_caverna(), delta / 1.5)
	var abafa := ABAFA_CAVERNA_DB * _na_caverna
	reducao += abafa

	var alvo_dia := _db_com_peso(MATA_DB + reducao, dia)
	var alvo_noite := _db_com_peso(NOITE_DB + reducao, noite)
	var alvo_chuva := SILENCIO_DB if chuva < 0.002 else CHUVA_DB + abafa + linear_to_db(clampf(chuva, 0.0, 1.0))
	_fundo.volume_db = _suaviza(_fundo.volume_db, lerpf(FUNDO_DB, FUNDO_NOITE_DB, noite) + reducao, delta)
	_caverna.volume_db = _suaviza(_caverna.volume_db, _db_com_peso(CAVERNA_DB, _na_caverna), delta)

	_mata_dia.volume_db = _suaviza(_mata_dia.volume_db, alvo_dia, delta)
	_mata_noite.volume_db = _suaviza(_mata_noite.volume_db, alvo_noite, delta)
	_chuva.volume_db = _suaviza(_chuva.volume_db, alvo_chuva, delta)

	_atualizar_trovao(delta, chuva)
	_atualizar_agua(delta)

	debug["peso_dia"] = dia
	debug["peso_noite"] = noite
	debug["mata_dia_db"] = _mata_dia.volume_db
	debug["mata_noite_db"] = _mata_noite.volume_db
	debug["chuva_db"] = _chuva.volume_db
	debug["caverna_db"] = _caverna.volume_db
	debug["na_caverna"] = _na_caverna


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
	var s := Som.stream("trovao" if randf() < 0.5 else "trovao_2")
	if ouvinte != null and ouvinte.is_inside_tree():
		var ang := randf() * TAU
		var p := AudioStreamPlayer3D.new()
		p.stream = s
		p.volume_db = TROVAO_DB
		p.unit_size = 30.0
		p.max_distance = 400.0
		p.bus = BUS_NATUREZA
		add_child(p)
		p.global_position = ouvinte.global_position \
				+ Vector3(cos(ang), 0.0, sin(ang)) * TROVAO_DIST + Vector3(0.0, 25.0, 0.0)
		p.play()
		p.finished.connect(p.queue_free)
	else:
		var q := AudioStreamPlayer.new()
		q.stream = s
		q.volume_db = TROVAO_DB
		q.bus = BUS_NATUREZA
		add_child(q)
		q.play()
		q.finished.connect(q.queue_free)


# ---------------------------------------------------------------- debaixo d'água

## O barramento Natureza (para o Master, com um passa-baixa de 24 dB por oitava) e o passa-baixa leve do
## Master. Os dois ficam desligados fora d'água. Um SomAmbiente novo (o Main recarregou) reaproveita os dois.
func _preparar_barramentos() -> void:
	_bus = AudioServer.get_bus_index(BUS_NATUREZA)
	if _bus == -1:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, BUS_NATUREZA)
		AudioServer.set_bus_send(_bus, &"Master")
		var f := AudioEffectLowPassFilter.new()
		f.resource_name = NOME_FILTRO
		f.db = AudioEffectFilter.FILTER_24DB
		f.cutoff_hz = SEM_CORTE_HZ
		AudioServer.add_bus_effect(_bus, f, 0)
	_filtro_natureza = AudioServer.get_bus_effect(_bus, 0) as AudioEffectLowPassFilter
	AudioServer.set_bus_effect_enabled(_bus, 0, false)
	_idx_geral = -1
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i).resource_name == NOME_FILTRO:
			_idx_geral = i
	if _idx_geral == -1:
		var g := AudioEffectLowPassFilter.new()
		g.resource_name = NOME_FILTRO
		g.db = AudioEffectFilter.FILTER_12DB
		g.cutoff_hz = SEM_CORTE_HZ
		AudioServer.add_bus_effect(0, g)
		_idx_geral = AudioServer.get_bus_effect_count(0) - 1
	_filtro_geral = AudioServer.get_bus_effect(0, _idx_geral) as AudioEffectLowPassFilter
	AudioServer.set_bus_effect_enabled(0, _idx_geral, false)


## Debaixo d'água: a câmera abaixo da lâmina (com folga para não piscar na superfície) ou o robô nadando
## (no nado a cabeça fica logo abaixo da lâmina, então ouvir de dentro é o certo mesmo com a câmera de fora).
func _debaixo_dagua() -> bool:
	var arm := ouvinte as Armadura
	if arm == null or arm.ilha == null:
		_cam_dentro = false
		return false
	var cam := get_viewport().get_camera_3d()
	if cam:
		var c := cam.global_position
		var s := arm.ilha.agua(c.x, c.z)
		_cam_dentro = s > -INF and c.y < s + (AGUA_FOLGA if _cam_dentro else -AGUA_FOLGA)
	else:
		_cam_dentro = false
	return _cam_dentro or arm.estado == Armadura.Estado.NADO


func _atualizar_agua(delta: float) -> void:
	var dentro := _debaixo_dagua()
	var arm := ouvinte as Armadura
	var rapidez := arm.velocity.length() if arm else 0.0
	_desde_mergulho += delta
	if not _iniciado:
		_iniciado = true
		_submerso = 1.0 if dentro else 0.0  # começou dentro d'água: sem splash
	elif dentro and _submerso < 0.2 and _desde_mergulho > 1.0 and _robo_na_agua(arm):
		# entrou de verdade (estava fora havia um tempo): o splash, mais forte para quem vem rápido. Só a câmera
		# passando por baixo da lâmina num rasante não faz splash: só muda o som.
		_desde_mergulho = 0.0
		_splash(maxf(rapidez, _rapidez_antes))
	_rapidez_antes = rapidez
	_submerso = move_toward(_submerso, 1.0 if dentro else 0.0, delta / (AGUA_ENTRA if dentro else AGUA_SAI))
	var s := smoothstep(0.0, 1.0, _submerso)

	# a natureza: cai de volume e só o grave passa; o resto do jogo, um pouco abafado
	AudioServer.set_bus_volume_db(_bus, ABAFA_AGUA_DB * s)
	var ligado := s > 0.001
	AudioServer.set_bus_effect_enabled(_bus, 0, ligado)
	AudioServer.set_bus_effect_enabled(0, _idx_geral, ligado)
	_filtro_natureza.cutoff_hz = SEM_CORTE_HZ * pow(CORTE_NATUREZA_HZ / SEM_CORTE_HZ, s)  # desce em oitavas, não em Hz
	_filtro_geral.cutoff_hz = SEM_CORTE_HZ * pow(CORTE_GERAL_HZ / SEM_CORTE_HZ, s)

	# o ronco: toca só debaixo d'água (e na passagem), começando num ponto sorteado do laço
	if ligado and not _agua.playing:
		_agua.play(randf() * _agua.stream.get_length())
	elif not ligado and _agua.playing:
		_agua.stop()
	_agua.volume_db = _db_com_peso(AGUA_DB, s)

	# bolhas de vez em quando; nadando rápido, mais vezes
	if s > 0.6:
		_contagem_bolhas -= delta * (2.2 if rapidez > Ajustes.NADO_VEL + 1.0 else 1.0)
		if _contagem_bolhas <= 0.0:
			_contagem_bolhas = randf_range(2.0, 6.0)
			_bolhas()
	elif _contagem_bolhas > 2.0:
		_contagem_bolhas = randf_range(0.8, 2.0)  # o primeiro punhado vem logo depois de entrar

	debug["submerso"] = _submerso
	debug["camera_dentro"] = _cam_dentro
	debug["agua_db"] = _agua.volume_db
	debug["natureza_bus_db"] = AudioServer.get_bus_volume_db(_bus)
	debug["corte_natureza_hz"] = _filtro_natureza.cutoff_hz
	debug["corte_geral_hz"] = _filtro_geral.cutoff_hz
	debug["filtro_ligado"] = ligado


## O robô com os pés abaixo da lâmina (ou nadando).
func _robo_na_agua(arm: Armadura) -> bool:
	if arm == null or arm.ilha == null:
		return false
	if arm.estado == Armadura.Estado.NADO:
		return true
	var p := arm.global_position
	var s := arm.ilha.agua(p.x, p.z)
	return s > -INF and p.y < s


## A entrada na água. `rapidez` em m/s: de 2 (afundando devagar) a 25 (mergulho do voo).
func _splash(rapidez: float) -> void:
	mergulhos += 1
	var forca := clampf(inverse_lerp(2.0, 25.0, rapidez), 0.0, 1.0)
	_toque("mergulho", MERGULHO_DB - 10.0 * (1.0 - forca), randf_range(0.94, 1.04) * lerpf(1.06, 0.92, forca))
	debug["mergulho_db"] = MERGULHO_DB - 10.0 * (1.0 - forca)


func _bolhas() -> void:
	bolhas += 1
	_toque(Som.variacao("bolhas", 4), BOLHAS_DB + randf_range(-6.0, 0.0), randf_range(0.85, 1.18))


## Toque curto de debaixo d'água, sem posição, no Master (que debaixo d'água já está com o passa-baixa leve).
func _toque(nome: String, db: float, tom: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = Som.stream(nome)
	p.volume_db = db
	p.pitch_scale = tom
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# ---------------------------------------------------------------- ajudantes

## dB de um som com peso (0 a 1) somado a um volume base; abaixo de ~-60 dB, mudo.
func _db_com_peso(base_db: float, peso: float) -> float:
	if peso < 0.001:
		return SILENCIO_DB
	return maxf(SILENCIO_DB, base_db + linear_to_db(peso))


func _suaviza(atual: float, alvo: float, delta: float) -> float:
	return lerpf(atual, alvo, 1.0 - exp(-SUAVIDADE * delta))


## Laço sem posição, no barramento Natureza (que debaixo d'água abafa).
func _laco(nome: String, volume_db_inicial: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Som.laco_stream(nome)
	p.volume_db = volume_db_inicial
	p.bus = BUS_NATUREZA
	add_child(p)
	p.play()
	return p
