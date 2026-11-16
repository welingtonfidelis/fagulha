class_name MechVisual
extends Node3D
## O corpo das máquinas: um dos quatro robôs do Animated Mech Pack do Quaternius (CC0), com a textura dele
## sob a luz em faixas do vale e as animações do pacote (Idle, Walk, Run, Shoot, Death, HitRecieve_1...).
## A frente fica em -Z e os pés na origem. `olho` acende uma luz vermelha na cabeça (o aviso de ataque),
## `clarao` pisca o corpo ao levar tiro e `apagar` escurece a máquina desligada.

const PASTA := "res://assets/vale/mech/%s.gltf"
const ALTURAS := {"george": 6.17, "leela": 4.89, "mike": 4.98, "stan": 6.13}  # do modelo, em pé
const LACOS := ["Idle", "Walk", "Run", "Walk_Tall", "Run_Tall", "Dance"]

var anim: AnimationPlayer
var mat: ShaderMaterial
var luz: OmniLight3D
var cabeca: BoneAttachment3D
var altura := 1.0
var atual := ""
var margem_caido := 0.12  # caído (Death), o osso mais baixo fica a esta fração da altura acima do chão
var _esq: Skeleton3D
var _raiz: Node3D
var _sobe := 0.0
var _raiz_y := 0.0


static func criar(nome: String, alt: float, ruido: Texture2D) -> MechVisual:
	var v := MechVisual.new()
	v.altura = alt
	var cena: PackedScene = load(PASTA % nome)
	var raiz := cena.instantiate() as Node3D
	for n in raiz.find_children("Icosphere*", "", true, false):
		n.free()  # uma esfera de apoio que veio no arquivo
	raiz.scale = Vector3.ONE * alt / float(ALTURAS[nome])
	raiz.rotation.y = PI  # o modelo olha para +Z
	v.add_child(raiz)
	v.mat = ShaderMaterial.new()
	v.mat.shader = load("res://scripts/shaders/vale_tex.gdshader")
	v.mat.set_shader_parameter("tinta", Color(0.8, 0.8, 0.8))
	v.mat.set_shader_parameter("corte", 0.0)
	v.mat.set_shader_parameter("vento", 0.0)
	v.mat.set_shader_parameter("borda", 0.3)
	v.mat.set_shader_parameter("ruido", ruido)
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var orig := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if orig and orig.albedo_texture:
			v.mat.set_shader_parameter("tex", orig.albedo_texture)
		mi.material_override = v.mat
	v.anim = raiz.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for a: String in LACOS:
		if v.anim.has_animation(a):
			v.anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var esq := raiz.find_children("*", "Skeleton3D", true, false)
	if not esq.is_empty():
		v.cabeca = BoneAttachment3D.new()
		(esq[0] as Skeleton3D).add_child(v.cabeca)
		v.cabeca.bone_name = "Head"
		v.luz = OmniLight3D.new()
		v.luz.light_color = Color(1.0, 0.16, 0.08)
		v.luz.omni_range = alt * 0.8
		v.luz.omni_attenuation = 2.0
		v.luz.light_energy = 0.0
		v.luz.shadow_enabled = false
		v.cabeca.add_child(v.luz)
	v.tocar("Idle")
	return v


## Caída, a máquina não entra no chão: mede o osso mais baixo e ergue o corpo o que faltar.
func _process(delta: float) -> void:
	if _esq == null:
		var l := find_children("*", "Skeleton3D", true, false)
		if l.is_empty():
			set_process(false)
			return
		_esq = l[0]
		_raiz = get_child(0)
		_raiz_y = _raiz.position.y
	var alvo := 0.0
	if atual == "Death":
		var baixo := INF
		for i in _esq.get_bone_count():
			if _esq.get_bone_name(i).contains("Pole"):
				continue  # alvos de apoio das pernas, não são peça do corpo
			baixo = minf(baixo, to_local(_esq.global_transform * _esq.get_bone_global_pose(i).origin).y)
		alvo = maxf(0.0, margem_caido * altura - (baixo - _sobe))
	_sobe = lerpf(_sobe, alvo, 1.0 - exp(-8.0 * delta))
	_raiz.position.y = _raiz_y + _sobe


func tocar(nome: String, vel := 1.0, mistura := 0.2) -> void:
	if anim == null or not anim.has_animation(nome):
		return
	if atual != nome:
		atual = nome
		anim.play(nome, mistura, vel)
	else:
		anim.speed_scale = vel
		if not anim.is_playing() and nome in LACOS:
			anim.play(nome, mistura, vel)


## Onde fica a cabeça, no mundo (de onde sai o tiro).
func ponto_cabeca() -> Vector3:
	return cabeca.global_position if cabeca else global_position + Vector3(0, altura * 0.85, 0)


func olho(energia: float) -> void:
	if luz:
		luz.light_energy = energia


func clarao(v: float) -> void:
	mat.set_shader_parameter("clarao", v)


func apagar(v: float) -> void:
	mat.set_shader_parameter("apagado", v)
