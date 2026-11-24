class_name Experiencia
extends Node
## A experiência do robô (doc §148). Além das lutas, as descobertas dão experiência uma vez cada: lugar novo,
## memória, lembrança do Faísca, peça da ilha, robô acordado, ação de lugar, rota, semente e página do álbum. A luta
## da Fundição e das máquinas soltas passa pelo fôlego (`Arsenal.pelo_folego`), que enche de novo com as horas do
## dia. Cada nível abre um conjunto do corpo; a subida de nível festeja (aura, som) e mostra o cartão do nível no
## alto da tela, que espera o respiro quando a subida vem no meio de uma onda da Fundição.
## Quem cria passa `armadura`, `hud` e `locais`.

## As descobertas valem menos desde 2026-11-23 (pedido do usuário: o nível 3 vinha rápido demais com umas poucas
## memórias); antes eram 120, 240, 240, 160, 240, 120, 50 e 40. As rotas e a corrida pedem esforço e ficaram.
const LUGAR := 60
const MEMORIA := 100
const LEMBRANCA := 100
const PECA := 100
const ROBO := 150
const ACAO := 60
const ROTA := 100
const ROTA_DIFICIL := 100
const CORRIDA := 160
const SEMENTE := 30
const ALBUM := 25
const MAQUINA := 13  # uma máquina solta lá fora (InimigosVale); a grande vale `MAQUINA_GRANDE`
const MAQUINA_GRANDE := 48
const LUGARES_FORA := ["Clareira"]  # onde o jogo começa: não é descoberta

static var atual: Experiencia
static var segurar := false  # a Fundição no meio de uma onda: o cartão do nível espera o respiro

var armadura: Armadura
var hud: Hud
var locais: Locais
var _cartoes: Array = []  # os níveis ganhos esperando o cartão
var _soltos: Array = []  # conjuntos abertos sem nível (robô achado) esperando o cartão
var _festa := false  # a aura e o som do nível, no próximo quadro sem pausa (a memória aberta pausa o jogo)
var _hora_ant := -1.0
var _t := 0.0
var _boca: Node3D  # o aro de luz na boca do cilindro da base: pulsa laranja enquanto houver conjunto novo
var _boca_mat: StandardMaterial3D
var _boca_luz: OmniLight3D
var _halo_mat: StandardMaterial3D
const COR_ARO := Color(1.0, 0.8, 0.42)  # mais claro que a ferrugem da boca, para o aro não sumir nela
var _tem_novo := false
var _pulso := 0.0


func _ready() -> void:
	atual = self
	if locais:
		locais.chegou.connect(_ao_chegar)


func _exit_tree() -> void:
	if atual == self:
		atual = null


## Uma descoberta: dá `quanto` de experiência na primeira vez de `chave` (guardada no Arsenal), solta um cubinho
## verde-água de `de` (ou de perto do robô) e festeja se o nível subiu. Devolve se pagou.
static func descobrir(chave: String, quanto: int, de := Vector3.INF) -> bool:
	if Arsenal.descobertas.has(chave):
		return false
	Arsenal.descobertas[chave] = true
	var antes := Arsenal.nivel()
	Arsenal.ganhar({"xp": quanto})
	if is_instance_valid(atual):
		atual._cubinho(de)
		atual.festejar(antes)
	return true


## O nível subiu de `antes` para o de agora: a aura, o som e o cartão de cada nível novo (no meio de uma onda, só o
## "Nível N" de sempre, e o cartão espera).
func festejar(antes: int) -> void:
	var agora := Arsenal.nivel()
	if agora <= antes:
		return
	_festa = true
	for n in range(antes + 1, agora + 1):
		_cartoes.append(n)
	if segurar and hud:
		hud.avisar("Nível %d" % agora, "")


## O cartão de um conjunto que abriu sem nível (o robô achado acordou).
func conjunto_novo(chave: String) -> void:
	if Corpo.existe(chave) and not _soltos.has(chave):
		_soltos.append(chave)


func _mostrar() -> void:
	if hud == null or (_cartoes.is_empty() and _soltos.is_empty()):
		return
	var conjuntos: Array = []
	for n: int in _cartoes:
		conjuntos.append_array(Corpo.do_nivel(n))
	conjuntos.append_array(_soltos)
	hud.cartao_nivel(_cartoes.duplicate(), conjuntos)
	_cartoes.clear()
	_soltos.clear()


func _ao_chegar(nome: String, primeira_vez: bool) -> void:
	if primeira_vez and not LUGARES_FORA.has(nome):
		descobrir("lugar:" + nome, LUGAR)


## Um cubinho verde-água, o mesmo da luta, que sai do lugar da descoberta (ou de perto do robô) e voa para ele.
func _cubinho(de: Vector3) -> void:
	if armadura == null or not armadura.is_inside_tree():
		return
	var onde := de
	if not onde.is_finite() or onde.distance_to(armadura.global_position) > 40.0:
		onde = armadura.global_position - armadura.global_basis.z * 2.0
	Espolio.soltar(self, onde, {"sucata": 1}, armadura)


func _process(delta: float) -> void:
	if _festa:
		_festa = false
		if armadura and armadura.is_inside_tree():
			EfeitosTiro.aura_nivel(armadura, armadura.altura_corpo())
			Som.toque3d(self, "nivel", armadura.global_position + Vector3(0, 1, 0), -2.0)
	if not segurar and not (hud and hud.aviso_na_tela()):
		_mostrar()  # o cartão espera o aviso da descoberta ("Semente achada!", o nome do lugar) passar
	_pulsar(delta)
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	_relogio()
	_tem_novo = not Corpo.novos().is_empty()


## A boca do cilindro da base chama o robô de volta: um aro de luz laranja que respira devagar, enquanto houver
## conjunto novo não visto na aba Corpo (o mesmo do pontinho da bússola).
func _pulsar(delta: float) -> void:
	if _boca == null:
		if not _tem_novo or not BaseVale.boca_cilindro.is_finite():
			return
		_criar_boca()
	_pulso += delta
	var f := 0.5 - 0.5 * cos(_pulso * TAU / 2.6)  # uma respiração a cada 2,6 s
	_boca.visible = _tem_novo
	if not _tem_novo:
		_pulso = 0.0
		return
	_boca_mat.albedo_color = Color(COR_ARO, 0.45 + 0.55 * f)
	_boca_mat.emission_energy_multiplier = 1.2 + 3.8 * f
	_halo_mat.albedo_color = Color(COR_ARO, 0.08 + 0.3 * f)
	_boca_luz.light_energy = 0.5 + 2.0 * f


func _criar_boca() -> void:
	var t := BaseVale.cilindro_t
	var x := InteriorCilindro.X1 + 0.16 if InteriorCilindro.ativo else BaseVale.MEIO_CIL + 0.1
	_boca = Node3D.new()
	_boca.name = "BocaNovo"
	add_child(_boca)
	_boca.global_transform = Transform3D(t.basis * Basis(Vector3.BACK, PI * 0.5), t * Vector3(x, 0, 0))
	var aro := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.98
	tm.outer_radius = 2.16
	tm.rings = 48
	tm.ring_segments = 8
	aro.mesh = tm
	_boca_mat = StandardMaterial3D.new()
	_boca_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_boca_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_boca_mat.emission_enabled = true
	_boca_mat.emission = COR_ARO
	_boca_mat.albedo_color = Color(COR_ARO, 0.5)
	aro.material_override = _boca_mat
	aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boca.add_child(aro)
	# o halo: um aro largo e bem transparente por fora, que faz o brilho espalhar de dia
	var halo := MeshInstance3D.new()
	var th := TorusMesh.new()
	th.inner_radius = 1.9
	th.outer_radius = 2.42
	th.rings = 48
	th.ring_segments = 8
	halo.mesh = th
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.albedo_color = Color(COR_ARO, 0.2)
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.scale = Vector3(1, 0.3, 1)  # achatado ao longo do eixo: um disco de luz em volta da boca
	_boca.add_child(halo)
	_boca_luz = OmniLight3D.new()
	_boca_luz.light_color = Color(1.0, 0.6, 0.28)
	_boca_luz.omni_range = 5.5
	_boca_luz.shadow_enabled = false
	add_child(_boca_luz)
	_boca_luz.global_position = t * Vector3(x + 0.9, -0.8, 0)


## O fôlego enche com as horas do dia: um dia inteiro (uma hora jogando) enche ele todo, no mesmo relógio dos
## acampamentos (a hora que volta para trás depois de uma cena não conta).
func _relogio() -> void:
	var ciclo := CicloDia.atual
	if ciclo == null or not is_instance_valid(ciclo):
		return
	if _hora_ant >= 0.0 and Arsenal.folego < Arsenal.FOLEGO_MAX:
		var dh := fposmod(ciclo.hora - _hora_ant, 24.0)
		if dh < 12.0:
			Arsenal.folego = minf(Arsenal.FOLEGO_MAX, Arsenal.folego + Arsenal.FOLEGO_MAX * dh / 24.0)
	_hora_ant = ciclo.hora
