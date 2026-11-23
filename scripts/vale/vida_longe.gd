class_name VidaLonge
extends Node3D
## Os bichos de terra vistos de longe (2026-11-22, pedido do usuário: voando, a ilha parecia vazia). VidaVale só cria
## os bichos de verdade (esqueleto, animação, jeito de ser) a menos de 240 m do robô. Aqui cada manada de cervos,
## alcateia, raposa e grupo de focas que ainda não nasceu aparece de longe numa forma simples (FormasBicho), no mesmo
## lugar onde vai nascer (o mesmo sorteio de VidaVale._criar), pastando ou olhando em volta (bicho_lote, modo 1).
## Some quando os de verdade nascem e, a mais de `bicho_lote.longe` da câmera, vira nada (não fica cintilando).
## Um MultiMesh por espécie, para a ilha inteira: quatro chamadas de desenho.

const PERTO := 200.0  # mais perto que isso a forma some (os de verdade nascem a 240 m)
const RAIO := {"cervo": 9.0, "lobo": 7.0, "raposa": 7.0, "foca": 5.0}  # o espalhamento de VidaVale._criar

var vida: VidaVale
var grupos := {}  # tipo -> {mm, lugares: [[lugar, primeiro índice, quantos]]}
var mostrados := 0

var _t := 0.0


func _ready() -> void:
	if vida == null:
		push_error("vida de longe: falta a vida do vale")
		return
	var sh: Shader = load("res://scripts/shaders/bicho_lote.gdshader")
	var formas := {"cervo": FormasBicho.quadrupede(FormasBicho.CERVO), "lobo": FormasBicho.quadrupede(FormasBicho.LOBO),
		"raposa": FormasBicho.quadrupede(FormasBicho.RAPOSA), "foca": FormasBicho.foca()}
	var total := 0
	for tipo: String in formas:
		var par: Array = formas[tipo]
		var lista := []
		var posicoes: Array[Transform3D] = []
		for l in vida.lugares:
			if l["tipo"] != tipo:
				continue
			var ps := _onde(l)
			lista.append([l, posicoes.size(), ps.size()])
			posicoes.append_array(ps)
		if posicoes.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = par[0]
		mm.instance_count = posicoes.size()
		for i in posicoes.size():
			mm.set_instance_transform(i, _sumido(posicoes[i]))
			mm.set_instance_custom_data(i, Color(randf(), 0, 0, 0))
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("modo", 1)
		mat.set_shader_parameter("pescoco", par[1])
		mat.set_shader_parameter("pasto", -0.55 if tipo == "foca" else 1.0)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Longe_" + tipo
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-5000, -100, -5000), Vector3(10000, 1200, 10000))
		add_child(mmi)
		grupos[tipo] = {"mm": mm, "lugares": lista, "pos": posicoes}
		total += posicoes.size()
	print("vida de longe: %d bichos em %d espécies" % [total, grupos.size()])
	_atualizar()


## Onde cada bicho do lugar vai nascer: o mesmo sorteio (semente e espalhamento) de VidaVale._criar.
func _onde(l: Dictionary) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(l["semente"])
	var giro := RandomNumberGenerator.new()
	giro.seed = int(l["semente"]) * 31 + 7
	var p: Vector3 = l["pos"]
	var out: Array[Transform3D] = []
	for i in int(l["quantos"]):
		var q := vida._perto(rng, p, RAIO[l["tipo"]])
		var b := Basis(Vector3.UP, giro.randf() * TAU)
		if l["tipo"] == "foca":
			b = b * Basis(Vector3.RIGHT, -0.04)
		out.append(Transform3D(b, q))
	return out


static func _sumido(t: Transform3D) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ZERO), t.origin)


## Mostra a forma de cada lugar cujos bichos de verdade não existem agora e que não está perto demais do robô.
func _atualizar() -> void:
	mostrados = 0
	var a := vida.alvo.global_position if vida.alvo else Vector3.INF
	for tipo: String in grupos:
		var g: Dictionary = grupos[tipo]
		var mm: MultiMesh = g["mm"]
		var posicoes: Array[Transform3D] = g["pos"]
		for item: Array in g["lugares"]:
			var l: Dictionary = item[0]
			var p: Vector3 = l["pos"]
			var mostra := (l["nos"] as Array).is_empty() and Vector2(a.x - p.x, a.z - p.z).length() > PERTO
			for k in int(item[2]):
				var i: int = int(item[1]) + k
				mm.set_instance_transform(i, posicoes[i] if mostra else _sumido(posicoes[i]))
			if mostra:
				mostrados += int(item[2])


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.4:
		return
	_t = 0.0
	_atualizar()
