class_name BichoVisual
extends Node3D
## O corpo dos bichos de quatro patas: um dos animais do Ultimate Animated Animals do Quaternius (CC0), com
## as cores do modelo sob a luz em faixas do vale e as animações do pacote (Idle, Idle_2, Eating, Walk,
## Gallop). A frente fica em -Z e as patas na origem.

const PASTA := "res://assets/vale/bichos/%s.gltf"
const ALTURAS := {"deer": 4.26, "stag": 4.19, "fox": 2.67, "wolf": 2.67}  # do modelo
const LACOS := ["Idle", "Idle_2", "Eating", "Walk", "Gallop", "Idle_Headlow", "Idle_2_HeadLow"]

var anim: AnimationPlayer
var atual := ""

static var _mats := {}  # cor -> material (os bichos da mesma espécie dividem)


static func criar(nome: String, altura: float, ruido: Texture2D) -> BichoVisual:
	var v := BichoVisual.new()
	var cena: PackedScene = load(PASTA % nome)
	var raiz := cena.instantiate() as Node3D
	raiz.scale = Vector3.ONE * altura / float(ALTURAS[nome])
	raiz.rotation.y = PI  # o modelo olha para +Z
	v.add_child(raiz)
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var copia := mi.mesh.duplicate() as Mesh
		for s in copia.get_surface_count():
			var orig := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var cor := orig.albedo_color if orig else Color(0.3, 0.2, 0.12)
			var chave := cor.to_html()
			if not _mats.has(chave):
				var m := ShaderMaterial.new()
				m.shader = load("res://scripts/shaders/vale_solido.gdshader")
				m.set_shader_parameter("cor", Color(cor.r * 0.8, cor.g * 0.8, cor.b * 0.8))  # um pouco mais escuro, na paleta do vale
				m.set_shader_parameter("brilho_borda", 0.25)
				m.set_shader_parameter("ruido", ruido)
				_mats[chave] = m
			# a malha fica sem material próprio: quem pinta os bichos pelo nome do material não mexe aqui
			copia.surface_set_material(s, null)
			mi.set_surface_override_material(s, _mats[chave])
		mi.mesh = copia
	v.anim = raiz.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for a: String in LACOS:
		if v.anim.has_animation(a):
			v.anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	v.tocar("Idle")
	return v


func tocar(nome: String, vel := 1.0, mistura := 0.3) -> void:
	if anim == null or not anim.has_animation(nome):
		return
	if atual != nome:
		atual = nome
		anim.play(nome, mistura, vel)
	else:
		anim.speed_scale = vel
