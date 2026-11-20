class_name AcoesLugar
extends Node3D
## Uma ação por lugar marcante (2026-11-19). Sem cronômetro nem placar: só pelo movimento, cada uma muda algo
## no mundo, e a mudança fica (vai para o save em `progresso.acoes`).
##  - **anel**: atravessar O Anel voando acende o aro por dentro;
##  - **torres**: passar voando rente às pás de uma das Torres do Vento paradas faz a hélice voltar a girar;
##  - **cardume**: mergulhar até o fundo do poço da Cachoeira solta um cardume que acompanha o robô ali;
##  - **cume**: apreciar a vista no cume ao pôr do sol mostra a ilha com os lugares visitados acesos;
##  - **arvore**: pousar no alto da Árvore-Mãe faz os pássaros pousarem em volta, e eles passam a morar lá.
## Quem cria passa `armadura`, `hud`, `mapa`, `camera` e `locais`.

const ANEL_BASE := 0.9  # os mesmos giros de `Marcos._anel`
const ANEL_VAO := 25.0  # raio livre do furo
const TORRE_PERTO := 26.0
const TORRE_FUNDO := 9.0  # quão longe do plano das pás ainda vale
const POCO_FUNDO := 6.0  # metros abaixo da superfície do poço
const CUME_PERTO := 45.0
const ARVORE_PERTO := 32.0  # as touceiras de folhas ficam até uns 25 m do tronco
const ARVORE_ALTO := 18.0  # acima do pé da árvore

var armadura: Armadura
var hud: Hud
var mapa: Vale
var camera: CameraVoo
var locais: Locais
var feitas := {}  # nome -> valor guardado
var contagem := 0  # quantas ações já aconteceram nesta partida (testes)

var _anel_eixo := Vector3.UP
var _anel_lado := 0.0
var _anel_luz: MeshInstance3D
var _anel_mat: StandardMaterial3D
var _anel_brilho := 0.0
var _rotores := {}  # k -> velocidade atual (as que voltaram a girar)
var _cardume: Peixes
var _bando: Passaros
var _poleiro: Poleiro
var _vista_mat: StandardMaterial3D
var _vista_pontos: Array[MeshInstance3D] = []
var _vista_k := 0.0
var _t := 0.0


## O mapa visto pelos pássaros da Árvore-Mãe: igual ao vale, mas com a copa dela como chão.
class Poleiro extends Ilha:
	var base: Ilha
	var meio := Vector2.ZERO
	var raio := 9.0
	var alto := 0.0
	func altura(x: float, z: float) -> float:
		if Vector2(x - meio.x, z - meio.y).length() < raio:
			return alto
		return base.altura(x, z)
	func agua(_x: float, _z: float) -> float:
		return -INF
	func normal_em(_x: float, _z: float) -> Vector3:
		return Vector3.UP


func _ready() -> void:
	if Guardado.ativo:
		feitas = (Guardado.progresso("acoes") as Dictionary).duplicate(true)
	for i in 6:
		await get_tree().physics_frame
	_montar_anel()
	for k in feitas.get("torres", []):
		_rotores[int(k)] = 0.22
	if feitas.has("cardume"):
		_soltar_cardume()
	if feitas.has("arvore"):
		var g: Array = feitas["arvore"]
		_por_bando(Vector3(g[0], g[1], g[2]), false)


func _guardar(nome: String, valor: Variant) -> void:
	feitas[nome] = valor
	contagem += 1
	if Guardado.ativo:
		Guardado.por_progresso("acoes", feitas)


func _avisar(titulo: String, sub: String) -> void:
	if hud:
		hud.avisar(titulo, sub)
	Som.toque3d(self, "fabricou", armadura.global_position, -6.0)


# ---------------------------------------------------------------- O Anel

func _montar_anel() -> void:
	if not Marcos.anel.is_finite():
		return
	var base := Basis(Vector3.UP, ANEL_BASE) * Basis(Vector3.BACK, 0.2) * Basis(Vector3.RIGHT, PI * 0.5)
	_anel_eixo = (base * Vector3.UP).normalized()
	# uma faixa de luz por dentro do aro, apagada até alguém atravessar
	var malha := TorusMesh.new()
	malha.inner_radius = 26.2
	malha.outer_radius = 27.3
	malha.rings = 56
	malha.ring_segments = 8
	_anel_mat = StandardMaterial3D.new()
	_anel_mat.albedo_color = Color(0.1, 0.12, 0.12)
	_anel_mat.emission_enabled = true
	_anel_mat.emission = Color(0.4, 0.95, 0.85)
	_anel_mat.emission_energy_multiplier = 0.0
	_anel_luz = MeshInstance3D.new()
	_anel_luz.mesh = malha
	_anel_luz.material_override = _anel_mat
	_anel_luz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anel_luz.transform = Transform3D(base, Marcos.anel)
	_anel_luz.visible = feitas.has("anel")
	add_child(_anel_luz)
	_anel_brilho = 1.0 if feitas.has("anel") else 0.0
	_anel_lado = (armadura.global_position - Marcos.anel).dot(_anel_eixo)


func _anel(delta: float) -> void:
	if _anel_luz == null:
		return
	var rel := armadura.global_position + Vector3(0, 0.6, 0) - Marcos.anel
	var lado := rel.dot(_anel_eixo)
	if not feitas.has("anel") and lado * _anel_lado < 0.0 and (rel - _anel_eixo * lado).length() < ANEL_VAO and armadura.estado != Armadura.Estado.CHAO:
		_guardar("anel", true)
		_anel_luz.visible = true
		_anel_brilho = 3.5  # acende forte e assenta
		_avisar("O Anel acendeu", "ele guarda a passagem de quem o atravessa")
	_anel_lado = lado
	LuzesNoite.ligadas["anel"] = feitas.has("anel")  # o balizamento da pista acende junto com o aro
	if _anel_luz.visible:
		_anel_brilho = move_toward(_anel_brilho, 1.0, delta * 1.2)
		# de dia a faixa fica discreta; de noite ela é uma das luzes da ilha
		_anel_mat.emission_energy_multiplier = _anel_brilho * lerpf(0.9, 2.2, ArmaduraVisual.noite) * (0.9 + 0.1 * sin(_t * 1.3))


# ---------------------------------------------------------------- As Torres do Vento

func _torres(delta: float) -> void:
	for item: Array in MarcosOeste.rotores:
		var rotor := item[0] as Node3D
		var k: int = item[2]
		if not is_instance_valid(rotor):
			continue
		if _rotores.has(k):
			_rotores[k] = move_toward(float(_rotores[k]), 0.22, delta * 0.05)
			rotor.rotate_object_local(Vector3.FORWARD, float(_rotores[k]) * delta)
			continue
		if String(item[1]) == "gira" or not armadura.em_voo():
			continue
		var rel := armadura.global_position - rotor.global_position
		var eixo := rotor.global_basis.z.normalized()
		if rel.length() < TORRE_PERTO and absf(rel.dot(eixo)) < TORRE_FUNDO:
			_rotores[k] = 0.0
			var lista: Array = feitas.get("torres", [])
			lista.append(k)
			_guardar("torres", lista)
			_avisar("Uma torre voltou a girar", "o vento do seu voo soltou as pás")


# ---------------------------------------------------------------- A Cachoeira

func _soltar_cardume() -> void:
	if _cardume != null:
		return
	_cardume = Peixes.new()
	_cardume.mapa = mapa
	_cardume.ameaca = null  # este não foge do robô: anda com ele
	_cardume.centro = Vector3(Vale.POCO.x, 0, Vale.POCO.y)
	_cardume.raio = 5.0
	_cardume.quantos = 9
	_cardume.semente = 77
	add_child(_cardume)


func _cachoeira() -> void:
	var p := armadura.global_position
	var no_poco := Vector2(p.x - Vale.POCO.x, p.z - Vale.POCO.y).length() < Vale.POCO.z
	if not feitas.has("cardume"):
		if no_poco and armadura.estado == Armadura.Estado.NADO and Vale.POCO_NIVEL - p.y > POCO_FUNDO:
			_guardar("cardume", true)
			_soltar_cardume()
			_avisar("Um cardume acordou no fundo", "ele acompanha quem nada no poço")
		return
	if _cardume:
		# com o robô na água do poço, o cardume nada em volta dele; fora, fica no meio do poço
		var com_ele: bool = no_poco and armadura.estado == Armadura.Estado.NADO
		_cardume.seguir(p if com_ele else Vector3(Vale.POCO.x, 0, Vale.POCO.y), 4.0 if com_ele else Vale.POCO.z - 4.0)


# ---------------------------------------------------------------- O cume ao pôr do sol

func _cume(delta: float) -> void:
	var c := CicloDia.atual
	var p := armadura.global_position
	var no_cume := Vector2(p.x - mapa.cume.x, p.z - mapa.cume.z).length() < CUME_PERTO
	var hora_boa: bool = c != null and c.hora > 16.8 and c.hora < 19.8
	var vendo: bool = armadura.contemplando and no_cume and hora_boa
	if vendo and _vista_pontos.is_empty():
		_acender_lugares()
		if not feitas.has("cume"):
			_guardar("cume", true)
	_vista_k = move_toward(_vista_k, 1.0 if vendo else 0.0, delta * (0.5 if vendo else 1.5))
	if _vista_mat:
		_vista_mat.albedo_color.a = smoothstep(0.0, 1.0, _vista_k) * (0.85 + 0.15 * sin(_t * 2.0))
	if _vista_k <= 0.0 and not _vista_pontos.is_empty():
		for mi in _vista_pontos:
			mi.queue_free()
		_vista_pontos.clear()


## Um ponto âmbar acima de cada lugar já visitado, grande o bastante para se ver do cume.
func _acender_lugares() -> void:
	if _vista_mat == null:
		_vista_mat = StandardMaterial3D.new()
		_vista_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_vista_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_vista_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_vista_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_vista_mat.billboard_keep_scale = true
		_vista_mat.disable_fog = true
		_vista_mat.no_depth_test = true
		_vista_mat.albedo_color = Color(3.4, 2.3, 0.9, 0.0)
		if ResourceLoader.exists("res://assets/fx/kenney/circle_05.png"):
			_vista_mat.albedo_texture = load("res://assets/fx/kenney/circle_05.png")
	if locais == null:
		return
	var malha := QuadMesh.new()
	for it: Dictionary in locais.lista:
		if not it["visto"]:
			continue
		var pos: Vector3 = it["pos"]
		var mi := MeshInstance3D.new()
		mi.mesh = malha
		mi.material_override = _vista_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var d := Vector2(pos.x - mapa.cume.x, pos.z - mapa.cume.z).length()
		mi.scale = Vector3.ONE * clampf(d * 0.034, 9.0, 70.0)  # mais longe, maior: do cume parecem do mesmo tamanho
		add_child(mi)
		mi.global_position = Vector3(pos.x, mapa.altura(pos.x, pos.z) + 22.0, pos.z)
		_vista_pontos.append(mi)


# ---------------------------------------------------------------- A Árvore-Mãe

func _por_bando(onde: Vector3, chegando: bool) -> void:
	if _bando != null:
		return
	_poleiro = Poleiro.new()
	_poleiro.base = mapa
	_poleiro.meio = Vector2(onde.x, onde.z)
	_poleiro.alto = onde.y
	_bando = Passaros.new()
	_bando.mapa = _poleiro
	_bando.ameaca = null  # estes não fogem
	_bando.casa = onde
	_bando.quantos = 7
	_bando.semente = 91
	add_child(_bando)
	if chegando:
		_bando.chegar_em(onde, 4.0)


func _arvore() -> void:
	if feitas.has("arvore") or not Marcos.arvore_mae.is_finite():
		return
	var p := armadura.global_position
	var am := Marcos.arvore_mae
	if armadura.estado == Armadura.Estado.CHAO and Vector2(p.x - am.x, p.z - am.z).length() < ARVORE_PERTO and p.y > am.y + ARVORE_ALTO:
		_guardar("arvore", [p.x, p.y, p.z])
		_por_bando(p, true)
		_avisar("Os pássaros vieram", "agora eles moram no alto da Árvore-Mãe")


func _exit_tree() -> void:
	if _poleiro and is_instance_valid(_poleiro):
		_poleiro.free()


func _physics_process(delta: float) -> void:
	if armadura == null or mapa == null:
		return
	_t += delta
	_anel(delta)
	_torres(delta)
	_cachoeira()
	_cume(delta)
	_arvore()
