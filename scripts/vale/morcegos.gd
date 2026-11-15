class_name Morcegos
extends Node3D
## Morcegos do Sumidouro: voam em círculos dentro do poço, em duas alturas (acima e abaixo da ponte),
## e se agitam quando o robô chega perto. Não fazem nada ao robô; são só vida.
## Uso: defina eixo (o meio do poço, no piso), raio_max e as faixas de altura, e então add_child.

const QUANTOS := 16
const SUSTO := 16.0  # distância em que o robô agita o bando

var alvo: Node3D
var eixo := Vector3.ZERO
var raio_max := 6.5
var faixas: Array[Vector2] = []  # alturas acima do eixo: [de, até]
var agitados := 0.0  # 0 calmos, 1 agitados (para teste)

var _bichos: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.08, 0.11)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var corpo := SphereMesh.new()
	corpo.radius = 0.09
	corpo.height = 0.26
	corpo.radial_segments = 6
	corpo.rings = 3
	var asa := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, -0.1), Vector3(0.42, 0, -0.02), Vector3(0, 0, 0.12),
		Vector3(0.42, 0, -0.02), Vector3(0.3, 0, 0.16), Vector3(0, 0, 0.12)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	asa.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	for i in QUANTOS:
		var faixa := faixas[i % faixas.size()]
		var no := Node3D.new()
		add_child(no)
		var c := MeshInstance3D.new()
		c.mesh = corpo
		c.material_override = mat
		c.rotation.x = PI * 0.5
		no.add_child(c)
		var asas: Array[Node3D] = []
		for lado: float in [1.0, -1.0]:
			var a := MeshInstance3D.new()
			a.mesh = asa
			a.material_override = mat
			a.scale.x = lado
			a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			no.add_child(a)
			asas.append(a)
		_bichos.append({"no": no, "asas": asas, "raio": rng.randf_range(2.2, raio_max), "y": rng.randf_range(faixa.x, faixa.y),
			"fase": rng.randf() * TAU, "vel": rng.randf_range(0.5, 1.0) * (1.0 if i % 2 == 0 else -1.0),
			"sobe": rng.randf_range(0.6, 1.6), "bate": rng.randf_range(9.0, 13.0), "de": faixa.x, "ate": faixa.y})


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
		var bat := sin(t * float(b["bate"]) * (1.0 + agitados * 0.6) + f) * 0.9
		(b["asas"][0] as Node3D).rotation.z = bat
		(b["asas"][1] as Node3D).rotation.z = -bat
