class_name LuzesNoite
extends Node
## Luzes de noite nos marcos (2026-11-19): de noite sumiam as referências. São pontos de luz pequenos (um
## disco que brilha, virado para a câmera, sem cone nem feixe de malha): vermelho piscando no alto das Torres
## do Vento e da torre do Relé, brasa nas chaminés da Fundição e um ponto âmbar sobre cada memória ainda
## não lida. Aparecem com o escurecer (`ArmaduraVisual.noite`) e somem de dia.
## Qualquer construção pode pedir um ponto com `LuzesNoite.por(...)`; este nó só acende, apaga e pisca.

const GRUPO := "luzes_noite"
## Lâmpadas de verdade (Light3D) com uma força de dia e outra de noite (2026-11-24, doc §161): a do cantinho e a do
## estrado da base ficavam acesas iguais de dia e de noite e lavavam as cores do robô perto do sofá.
const GRUPO_LAMPADAS := "lampadas_noite"
const BRILHO := 2.6
const VERMELHO := Color(1.0, 0.16, 0.1)
const BRASA := Color(1.0, 0.45, 0.12)
const AMBAR := Color(1.0, 0.72, 0.32)
const CIANO := Color(0.4, 0.95, 0.85)

static var _mats := {}
static var ligadas := {}  # nome -> bool: pontos com a meta `so_com` só acendem quando o nome está ligado (a pista do Anel)
static var _malha: QuadMesh

var acesas := 0  # quantas estão à vista agora (testes)
var _t := 0.0


## Põe a lâmpada `l` no grupo: este nó passa a força dela de `dia` para `noite` com o escurecer.
static func lampada(l: Light3D, dia: float, noite: float) -> void:
	l.set_meta("dia", dia)
	l.set_meta("noite", noite)
	l.light_energy = dia
	l.visible = dia > 0.01
	l.add_to_group(GRUPO_LAMPADAS)


## Um ponto de luz em `pos` (no espaço de `pai`). `pisca` > 0: acende por um instante a cada `pisca` segundos.
static func por(pai: Node3D, pos: Vector3, cor: Color, tamanho: float, pisca := 0.0, fase := 0.0) -> MeshInstance3D:
	if _malha == null:
		_malha = QuadMesh.new()
		_malha.size = Vector2.ONE
	var chave := cor.to_html()
	if not _mats.has(chave):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.disable_fog = true
		m.albedo_color = Color(cor.r * BRILHO, cor.g * BRILHO, cor.b * BRILHO, 0.0)  # acima de 1: o brilho da tela pega
		if ResourceLoader.exists("res://assets/fx/kenney/circle_05.png"):
			m.albedo_texture = load("res://assets/fx/kenney/circle_05.png")
		_mats[chave] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _malha
	mi.material_override = _mats[chave]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * tamanho
	mi.visible = false
	mi.set_meta("pisca", pisca)
	mi.set_meta("fase", fase)
	mi.add_to_group(GRUPO)
	pai.add_child(mi)
	return mi


func _ready() -> void:
	# os marcos altos: o mundo já está montado quando este nó entra
	var k := 0
	for topo: Vector3 in MarcosOeste.torres_topo:
		var p := por(get_parent() as Node3D, Vector3.ZERO, VERMELHO, 9.0, 2.4, k * 0.37)
		p.global_position = topo + Vector3(0, 2.5, 0)
		k += 1
	if MarcosMar.rele_topo.is_finite():
		var p2 := por(get_parent() as Node3D, Vector3.ZERO, VERMELHO, 7.0, 1.8, 0.5)
		p2.global_position = MarcosMar.rele_topo + Vector3(0, 6.0, 0)


func _process(delta: float) -> void:
	_t += delta
	var n := ArmaduraVisual.noite
	for chave: String in _mats:
		(_mats[chave] as StandardMaterial3D).albedo_color.a = n
	for no: Node in get_tree().get_nodes_in_group(GRUPO_LAMPADAS):
		var l := no as Light3D
		l.light_energy = lerpf(float(l.get_meta("dia", 0.0)), float(l.get_meta("noite", 1.0)), n)
		l.visible = l.light_energy > 0.01
	acesas = 0
	for no: Node in get_tree().get_nodes_in_group(GRUPO):
		var mi := no as MeshInstance3D
		var pisca: float = mi.get_meta("pisca", 0.0)
		var aceso := n > 0.03
		var so_com: String = mi.get_meta("so_com", "")
		if so_com != "" and not bool(ligadas.get(so_com, false)):
			aceso = false
		if aceso and pisca > 0.0:
			aceso = fposmod(_t / pisca + float(mi.get_meta("fase", 0.0)), 1.0) < 0.5
		mi.visible = aceso
		if aceso:
			acesas += 1
