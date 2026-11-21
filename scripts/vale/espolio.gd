class_name Espolio
extends MeshInstance3D
## Os espólios de uma máquina vencida: cubinhos de luz que saem dela e voam para o robô (um por material, até
## quatro; o primeiro verde-água, os outros laranja). A Fundição, os acampamentos e as tocas dos procurados
## soltam os mesmos. `premiar` faz o prêmio inteiro de quem vence lá fora: soma no `Arsenal`, solta os cubinhos
## e, se o nível subiu, a aura, o som e o aviso.

const AGUA := Color(0.35, 0.95, 0.85)
const LARANJA := Color(1.0, 0.62, 0.3)

static var _mats := {}

var alvo: Armadura
var vel := Vector3.ZERO
var _t := 0.0


## Soma o prêmio, solta os cubinhos de `de` e festeja a subida de nível (o aviso vem depois do aviso de quem
## chamou, no mesmo quadro). Devolve true se o nível subiu.
static func premiar(pai: Node, de: Vector3, ganho: Dictionary, armadura: Armadura, hud: Hud) -> bool:
	var subiu := Arsenal.ganhar(ganho)
	soltar(pai, de, ganho, armadura)
	if subiu and armadura:
		EfeitosTiro.aura_nivel(armadura, armadura.altura_corpo())
		Som.toque3d(pai, "nivel", armadura.global_position + Vector3(0, 1, 0), -2.0)
		if hud:
			hud.avisar.call_deferred("Nível %d" % Arsenal.nivel(), "novas fabricações e melhorias na base")
	return subiu


static func soltar(pai: Node, de: Vector3, ganho: Dictionary, para: Armadura) -> void:
	if para == null:
		return
	for i in mini(4, int(ganho.get("sucata", 0)) + int(ganho.get("nucleos", 0)) + int(ganho.get("chips", 0))):
		var e := Espolio.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.22
		e.mesh = bm
		e.material_override = _luz(LARANJA if i > 0 else AGUA)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.alvo = para
		e._t = -0.35 - i * 0.12
		e.vel = Vector3(randf_range(-2, 2), 5.0, randf_range(-2, 2))
		pai.add_child(e)
		e.global_position = de + Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6))


static func _luz(cor: Color) -> StandardMaterial3D:
	if not _mats.has(cor):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = 3.0
		_mats[cor] = m
	return _mats[cor]


func _physics_process(delta: float) -> void:
	_t += delta
	rotation += Vector3(3.0, 4.0, 2.0) * delta
	if _t < 0.0:
		return
	if not is_instance_valid(alvo):
		queue_free()
		return
	var a := alvo.pos_suave() + Vector3(0, alvo.altura_corpo() * 0.5, 0)
	var para := a - global_position
	vel = vel.lerp(para.normalized() * (10.0 + _t * 30.0), minf(1.0, delta * 5.0))
	global_position += vel * delta
	if para.length() < 0.7 or _t > 5.0:
		queue_free()
