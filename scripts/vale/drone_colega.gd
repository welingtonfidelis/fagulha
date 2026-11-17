class_name DroneColega
extends Node3D
## O drone colega do robô (modelo Enemy_EyeDrone do Sci-Fi Essentials Kit do Quaternius, CC0). Fica no
## posto dele na base, ao lado da boca do cilindro de melhorias, pairando e olhando o robô quando ele chega
## perto. Quando o robô entra em pane, aparece voando por cima dele, acende o facho e o leva de volta: a
## tela escurece, os dois reaparecem na base e ele volta ao posto.
## Quem cria passa `armadura` e `posto` (no mundo).

enum Modo { POSTO, BUSCA, SOBRE, VOLTA }

const ALTURA_SOBRE := 2.3  # a que altura fica sobre o robô caído
const CHEGADA := 2.0  # segundos da descida até o robô

var armadura: Armadura
var posto := Vector3.ZERO
var ruido: Texture2D
var modo := Modo.POSTO
var resgates := 0  # quantas vezes chegou sobre o robô caído (testes)
var chegou_a := INF  # a menor distância a que chegou do ponto sobre o robô, no último resgate (testes)

var _corpo: Node3D
var _anim: AnimationPlayer
var _facho: MeshInstance3D
var _luz: OmniLight3D
var _t := 0.0
var _de := Vector3.ZERO
var _fase := 0.0
var bipes := 0  # quantas vezes falou (testes)
var _perto := false
var _fala_t := 3.0


func _ready() -> void:
	var cena: PackedScene = load(BaseVale.PASTA + "Enemy_EyeDrone.gltf")
	_corpo = cena.instantiate() as Node3D
	_corpo.scale = Vector3.ONE * 0.72
	add_child(_corpo)
	BaseVale.vestir(_corpo, 0.12, 0.0, ruido)
	_anim = _corpo.find_children("*", "AnimationPlayer", true, false)[0] if not _corpo.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	_tocar("Idle")
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.82, 0.35)
	_luz.light_energy = 0.7
	_luz.omni_range = 5.0
	_luz.position = Vector3(0, 0.1, 0.5)
	add_child(_luz)
	# o facho de luz que ele desce sobre o robô caído
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = 0.75
	cone.height = ALTURA_SOBRE
	cone.radial_segments = 20
	cone.cap_top = false
	cone.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.45, 0.95, 0.85, 0.22)
	_facho = MeshInstance3D.new()
	_facho.mesh = cone
	_facho.material_override = mat
	_facho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_facho.position = Vector3(0, -ALTURA_SOBRE * 0.5 - 0.3, 0)
	_facho.visible = false
	add_child(_facho)
	global_position = posto
	add_to_group("amigos")  # ninguém atira nele (Tiro)
	if armadura:
		armadura.entrou_pane.connect(_buscar)
		armadura.voltou_base.connect(_na_base)
		armadura.saiu_pane.connect(_soltar)


func _tocar(nome: String) -> void:
	if _anim == null:
		return
	for a in _anim.get_animation_list():
		if String(a).ends_with(nome):
			if _anim.current_animation != a:
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
				_anim.play(a, 0.3)
			return


## O robô desligou: o drone aparece no alto, atrás dele, e desce até ficar por cima.
func _buscar() -> void:
	modo = Modo.BUSCA
	_t = 0.0
	chegou_a = INF
	var alvo := armadura.global_position
	var lado := Vector3(sin(_fase * 7.0 + alvo.x), 0, cos(_fase * 7.0 + alvo.z)).normalized()
	if global_position.distance_to(alvo) > 60.0:
		global_position = alvo + lado * 16.0 + Vector3(0, 13.0, 0)
	_de = global_position
	_tocar("Look")


## Com a tela escura o robô reapareceu na base: o drone vai junto, por cima dele.
func _na_base() -> void:
	modo = Modo.SOBRE
	_t = 0.0
	global_position = armadura.global_position + Vector3(0, ALTURA_SOBRE, 0)


## O robô religou: o drone apaga o facho e volta ao posto.
func _soltar() -> void:
	modo = Modo.VOLTA
	_t = 0.0
	_de = global_position
	_tocar("Idle")


## Uma frase de bipes e assobios (sons de síntese: tools/sons_sinteticos.py).
func falar() -> void:
	bipes += 1
	_fala_t = randf_range(8.0, 16.0)
	Som.toque3d(self, Som.variacao("drone", 6), global_position, -6.0, 6.0, 45.0)


func _olhar(para: Vector3, delta: float, pressa: float) -> void:
	var d := para - global_position
	d.y = 0.0
	if d.length_squared() < 0.01:
		return
	# a frente do modelo é +Z
	var alvo := atan2(d.x, d.z)
	rotation.y = lerp_angle(rotation.y, alvo, 1.0 - exp(-pressa * delta))


func _process(delta: float) -> void:
	_fase += delta
	var balanco := Vector3(0, sin(_fase * 1.7) * 0.12, 0)
	match modo:
		Modo.POSTO:
			global_position = global_position.lerp(posto + balanco, 1.0 - exp(-3.0 * delta))
			if armadura and armadura.global_position.distance_to(posto) < 22.0:
				_olhar(armadura.global_position, delta, 3.0)
			else:
				rotation.y += delta * 0.25 * sin(_fase * 0.3)
			# fala quando o robô chega perto, e de vez em quando enquanto ele fica por ali
			var junto := armadura != null and not armadura.em_pane and armadura.global_position.distance_to(global_position) < 7.5
			_fala_t -= delta
			if junto and (not _perto or _fala_t <= 0.0):
				falar()
			_perto = junto
			_facho.visible = false
		Modo.BUSCA:
			_t += delta
			var sobre := armadura.global_position + Vector3(0, ALTURA_SOBRE, 0)
			var k := clampf(_t / CHEGADA, 0.0, 1.0)
			k = 1.0 - pow(1.0 - k, 3.0)  # chega rápido e freia em cima dele
			global_position = _de.lerp(sobre, k) + balanco * k
			_olhar(armadura.global_position + (armadura.global_position - _de) * 0.01, delta, 6.0)
			chegou_a = minf(chegou_a, global_position.distance_to(sobre))
			if k >= 1.0 and not _facho.visible:
				_facho.visible = true
				resgates += 1
				_tocar("Charging")
				falar()
		Modo.SOBRE:
			global_position = armadura.global_position + Vector3(0, ALTURA_SOBRE, 0) + balanco
			_facho.visible = true
		Modo.VOLTA:
			_t += delta
			_facho.visible = _t < 0.6
			var k2 := smoothstep(0.0, 1.0, clampf((_t - 0.5) / 2.6, 0.0, 1.0))
			global_position = _de.lerp(posto, k2) + balanco
			if _t > 0.5:
				_olhar(posto + (posto - _de), delta, 3.0)
			if k2 >= 1.0:
				modo = Modo.POSTO
	if _facho.visible:
		var m := _facho.material_override as StandardMaterial3D
		m.albedo_color.a = 0.2 + 0.08 * sin(_fase * 9.0)
