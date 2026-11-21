class_name RadioBase
extends Node3D
## O rádio da bancada (1.1, doc §136): de pé na frente dele, o triângulo (agir) liga e desliga. Toca em fila
## as três músicas feitas para ele (`tools/musica_radio.py`: manhã, tarde e noite), começando pela da hora do
## dia. O som sai do rádio: alto dentro da base, sumindo a uns 40 m. Com o rádio tocando perto, a música do
## passeio (`MusicaPasseio`) espera. Ligado ou desligado fica guardado.
## Quem cria passa `armadura` e `hud`.

const FAIXAS := ["radio_manha", "radio_tarde", "radio_noite"]
const PERTO := 1.5
const ALCANCE := 40.0

static var tocando := false
static var onde := Vector3.INF

var armadura: Armadura
var hud: Hud
var faixa := 0
var trocas := 0  # testes

var _som: AudioStreamPlayer3D
var _luz: OmniLight3D
var _perto := false


func _ready() -> void:
	onde = BaseLar.radio
	tocando = false
	if not onde.is_finite():
		return
	global_position = onde
	_som = AudioStreamPlayer3D.new()
	_som.unit_size = 4.0
	_som.max_distance = ALCANCE
	_som.volume_db = -4.0
	_som.attenuation_filter_cutoff_hz = 9000.0
	add_child(_som)
	_som.finished.connect(_proxima)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.72, 0.35)
	_luz.light_energy = 0.0
	_luz.omni_range = 1.6
	_luz.position = Vector3(0, 0.15, -0.15)
	add_child(_luz)
	if Guardado.ativo and bool(Guardado.progresso("radio")):
		ligar(true)


## A faixa que combina com a hora: manhã até o meio da tarde, tarde até escurecer, noite depois.
func _da_hora() -> int:
	var h := CicloDia.atual.hora if CicloDia.atual else 10.0
	if h >= 5.0 and h < 14.0:
		return 0
	if h >= 14.0 and h < 19.0:
		return 1
	return 2


func ligar(sim: bool) -> void:
	tocando = sim
	if sim:
		faixa = _da_hora()
		_tocar()
		Som.toque3d(self, "marcar", global_position, -14.0)
	else:
		_som.stop()
	_luz.light_energy = 0.8 if sim else 0.0
	if Guardado.ativo:
		Guardado.por_progresso("radio", sim)


func _tocar() -> void:
	_som.stream = Som.stream(FAIXAS[faixa])
	_som.play()


func _proxima() -> void:
	if not tocando:
		return
	faixa = (faixa + 1) % FAIXAS.size()
	trocas += 1
	_tocar()


func _physics_process(_delta: float) -> void:
	if armadura == null or not onde.is_finite():
		return
	var p := armadura.global_position
	var d := Vector2(p.x - onde.x, p.z - onde.z).length()
	var perto := d < PERTO and absf(p.y - onde.y) < 2.0 and armadura.estado == Armadura.Estado.CHAO \
		and not armadura.em_pane and not armadura.travado and not armadura.no_assento \
		and not armadura.escaneando and not armadura.contemplando
	# o banquinho da bancada fica a um metro: o rádio vale quando o robô está mais perto dele que do assento
	if perto:
		var lugar := armadura.assento_perto()
		if not lugar.is_empty():
			var ps: Vector3 = lugar[0]
			perto = d < Vector2(p.x - ps.x, p.z - ps.z).length()
	armadura.convite_outro = perto
	if hud:
		var novo := ("{agir}  desligar o rádio" if tocando else "{agir}  ligar o rádio") if perto else ""
		if hud.dica != novo and (perto or hud.dica.ends_with(" o rádio")):
			hud.dica = novo
	_perto = perto
	if perto and Input.is_action_just_pressed("agir"):
		ligar(not tocando)
