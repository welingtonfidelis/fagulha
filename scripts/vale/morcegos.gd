class_name Morcegos
extends Node3D
## Morcegos do Sumidouro: voam em círculos dentro do poço, em duas alturas (acima e abaixo da ponte),
## e se agitam quando o robô chega perto. Não fazem nada ao robô; são só vida.
## Uso: defina eixo (o meio do poço, no piso), raio_max e as faixas de altura, e então add_child.

const QUANTOS := 16
## O morcego animado de Danimal (opengameart.org/content/vampire-bat-animated, CC0), reduzido no Blender.
const MODELO := "res://assets/vale/morcego/morcego.glb"
const TEXTURAS := ["res://assets/vale/morcego/morcego_pelo.jpg", "res://assets/vale/morcego/morcego_partes.jpg"]
const ENVERGADURA := 0.95  # metros de asa a asa
const GIRO_MODELO := 0.0  # para a frente do modelo ficar em -z
const SUSTO := 16.0  # distância em que o robô agita o bando

var alvo: Node3D
var eixo := Vector3.ZERO
var raio_max := 6.5
var faixas: Array[Vector2] = []  # alturas acima do eixo: [de, até]
var agitados := 0.0  # 0 calmos, 1 agitados (para teste)

var _bichos: Array[Dictionary] = []
var _escala := 0.0
var _mats := {}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var cena := load(MODELO) as PackedScene
	for i in QUANTOS:
		var faixa := faixas[i % faixas.size()]
		var no := Node3D.new()
		add_child(no)
		var modelo := cena.instantiate() as Node3D
		no.add_child(modelo)
		# o tamanho pela largura de asa a asa
		if _escala <= 0.0:
			var larg := 0.0
			for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
				var cx := mi.get_aabb()
				var esc := mi.global_basis.get_scale()
				larg = maxf(larg, maxf(cx.size.x * absf(esc.x), maxf(cx.size.y * absf(esc.y), cx.size.z * absf(esc.z))))
			_escala = ENVERGADURA / maxf(larg, 0.001)
		modelo.scale = Vector3.ONE * _escala * rng.randf_range(0.85, 1.15)
		modelo.rotation.y = GIRO_MODELO
		for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# as texturas do pacote não vieram junto na conversão: o corpo fica num marrom quase preto e o
			# segundo material (focinho, orelhas e dedos) num tom mais claro
			for sf in mi.mesh.get_surface_count():
				# a pintura do próprio modelo (pelo marrom, asas de couro, focinho rosado), no estilo do vale;
				# sem a textura, um marrom quase preto
				# (as texturas vão ao lado do modelo, reduzidas: no glb elas não vieram ligadas aos materiais)
				var arq: String = TEXTURAS[mini(sf, TEXTURAS.size() - 1)]
				if ResourceLoader.exists(arq):
					mi.set_surface_override_material(sf, _mat_tex(load(arq)))
				else:
					mi.set_surface_override_material(sf, _mat(Color(0.2, 0.15, 0.14) if sf > 0 else Color(0.09, 0.075, 0.085)))
		var anim: AnimationPlayer = null
		var tocadores := modelo.find_children("*", "AnimationPlayer", true, false)
		if not tocadores.is_empty():
			anim = tocadores[0] as AnimationPlayer
			for nome: String in anim.get_animation_list():
				if "Flying" in nome:
					anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
					anim.play(nome)
					anim.seek(rng.randf() * anim.get_animation(nome).length, true)
		_bichos.append({"no": no, "anim": anim, "raio": rng.randf_range(2.2, raio_max), "y": rng.randf_range(faixa.x, faixa.y),
			"fase": rng.randf() * TAU, "vel": rng.randf_range(0.5, 1.0) * (1.0 if i % 2 == 0 else -1.0),
			"sobe": rng.randf_range(0.6, 1.6), "bate": rng.randf_range(1.6, 2.4), "de": faixa.x, "ate": faixa.y})


func _mat_tex(tex: Texture2D) -> ShaderMaterial:
	var chave := "tex%d" % tex.get_instance_id()
	if not _mats.has(chave):
		var mt := ShaderMaterial.new()
		mt.shader = load("res://scripts/shaders/vale_tex_opaco.gdshader")
		mt.set_shader_parameter("tex", tex)
		mt.set_shader_parameter("tinta", Vector3(0.6, 0.5, 0.46))
		mt.set_shader_parameter("corte", 0.0)
		mt.set_shader_parameter("vento", 0.0)
		_mats[chave] = mt
	return _mats[chave]


func _mat(cor: Color) -> ShaderMaterial:
	var chave := cor.to_html()
	if not _mats.has(chave):
		var mt := ShaderMaterial.new()
		mt.shader = load("res://scripts/shaders/vale_solido.gdshader")
		mt.set_shader_parameter("cor", cor)
		mt.set_shader_parameter("brilho_borda", 0.3)
		_mats[chave] = mt
	return _mats[chave]


func _process(delta: float) -> void:
	var perto := alvo != null and is_instance_valid(alvo) and alvo.global_position.distance_to(eixo + Vector3(0, alvo.global_position.y - eixo.y, 0)) < SUSTO \
			and alvo.global_position.y > eixo.y - 2.0
	agitados = move_toward(agitados, 1.0 if perto else 0.0, delta * (2.5 if perto else 0.4))
	var t := Time.get_ticks_msec() * 0.001
	for b in _bichos:
		var vel: float = b["vel"] * (1.0 + agitados * 1.8)
		b["fase"] = float(b["fase"]) + vel * delta
		var f: float = b["fase"]
		var r: float = float(b["raio"]) * (1.0 + 0.12 * sin(t * 1.3 + f * 2.0))
		var y := clampf(float(b["y"]) + sin(t * float(b["sobe"]) + f) * (1.2 + agitados * 2.0), b["de"], b["ate"])
		var no: Node3D = b["no"]
		var p := eixo + Vector3(cos(f) * r, y, sin(f) * r)
		var frente := Vector3(-sin(f), 0, cos(f)) * signf(vel)
		no.global_position = p
		no.rotation.y = atan2(-frente.x, -frente.z)
		if b["anim"]:
			(b["anim"] as AnimationPlayer).speed_scale = float(b["bate"]) * (1.0 + agitados * 0.7)
		no.rotation.z = -0.35 * signf(vel)  # inclinado para dentro da volta
