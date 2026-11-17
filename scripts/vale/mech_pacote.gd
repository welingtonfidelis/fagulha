class_name MechPacote
extends MechVisual
## O corpo animado de uma máquina que vem pronta de um pacote (doc §69): o Stan do Animated Mech Pack e o
## Trilobite e o QuadShell do Sci-Fi Essentials Kit, todos do Quaternius (CC0). O modelo é posto na altura
## pedida, de frente para -Z, com a pintura em faixas do vale sobre a textura dele, e as animações
## respondem pelos nomes comuns das máquinas (Idle, Walk, Run, Shoot, Death).

const PASTA := "res://assets/vale/inimigos/%s.gltf"
## altura do modelo como vem no arquivo, e o nome de cada animação comum nele
const DADOS := {
	"stan": {"arquivo": "Stan", "altura": 6.46, "nomes": {}, "tiro": 0.45},
	"trilobite": {"arquivo": "Enemy_Trilobite", "altura": 2.49, "nomes": {"Shoot": "Attack", "Death": "TurnOff"}, "tiro": 0.4},
	"quadshell": {"arquivo": "Enemy_QuadShell", "altura": 1.49, "nomes": {"Shoot": "Attack", "Death": "TurnOff"}, "tiro": 0.35},
}

static var _cenas := {}

var tipo := ""
var mats: Array[ShaderMaterial] = []
var _nomes := {}
var _tiro := 0.4


static func montar(qual: String, alt: float, ruido: Texture2D) -> MechPacote:
	var d: Dictionary = DADOS[qual]
	if not _cenas.has(qual):
		_cenas[qual] = load(PASTA % d["arquivo"])
	var v := MechPacote.new()
	v.tipo = qual
	v.altura = alt
	v._nomes = d["nomes"]
	v._tiro = d["tiro"]
	var raiz := (_cenas[qual] as PackedScene).instantiate() as Node3D
	raiz.scale = Vector3.ONE * (alt / float(d["altura"]))
	raiz.rotation.y = PI  # os modelos olham para +Z; as máquinas, para -Z
	v.add_child(raiz)
	# a pintura do vale por cima da textura de cada superfície
	var feitos := {}
	for mi: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var tex: Texture2D = orig.albedo_texture if orig else null
			if not feitos.has(tex):
				var m := ShaderMaterial.new()
				m.shader = load("res://scripts/shaders/vale_tex.gdshader")
				m.set_shader_parameter("tex", tex)
				m.set_shader_parameter("tinta", Color(1.0, 0.98, 0.95) if qual == "stan" else Color(1.15, 1.12, 1.1))
				m.set_shader_parameter("corte", 0.0)
				m.set_shader_parameter("vento", 0.0)
				m.set_shader_parameter("borda", 0.3)
				m.set_shader_parameter("ruido", ruido)
				feitos[tex] = m
				v.mats.append(m)
			mi.set_surface_override_material(s, feitos[tex])
	v.mat = v.mats[0]
	v.anim = raiz.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for comum: String in ["Idle", "Walk", "Run"]:
		var real: String = v._nomes.get(comum, comum)
		if v.anim.has_animation(real):
			v.anim.get_animation(real).loop_mode = Animation.LOOP_LINEAR
	# o olho de aviso: uma luz vermelha na altura da cabeça
	v.luz = OmniLight3D.new()
	v.luz.light_color = Color(1.0, 0.16, 0.08)
	v.luz.omni_range = alt * 0.9
	v.luz.omni_attenuation = 2.0
	v.luz.light_energy = 0.0
	v.luz.shadow_enabled = false
	v.luz.position = Vector3(0, alt * 0.8, -alt * 0.25)
	v.add_child(v.luz)
	v.boca = Node3D.new()
	v.boca.position = Vector3(0, alt * (0.62 if qual == "stan" else 0.7), -alt * 0.3)
	v.add_child(v.boca)
	v.tocar("Idle")
	return v


func tocar(nome: String, vel := 1.0, mistura := 0.2) -> void:
	var real: String = _nomes.get(nome, nome)
	if anim == null or not anim.has_animation(real):
		return
	if atual != nome:
		atual = nome
		anim.play(real, mistura, vel)
	else:
		anim.speed_scale = vel
		if not anim.is_playing() and nome in LACOS:
			anim.play(real, mistura, vel)


func tempo_do_tiro() -> float:
	return _tiro


func clarao(v: float) -> void:
	for m in mats:
		m.set_shader_parameter("clarao", v)


func apagar(v: float) -> void:
	for m in mats:
		m.set_shader_parameter("apagado", v)
