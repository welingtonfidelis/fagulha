class_name CilindrosBase
extends Node3D
## Os três cilindros de vidro da baia dos robôs (`BaseVale._baia_dos_robos`). Hoje ficam vazios: a ideia é
## que robôs achados pelo vale (o robô de peças anterior, por exemplo) venham a ser guardados e usados aqui.
## São sólidos: não se entra neles.

var cilindros: Array[Node3D] = []


func _ready() -> void:
	for k in BaseVale.BAIA_VAGAS.size():
		var no := Node3D.new()
		var onde: Vector3 = BaseVale.BAIA + Vector3(float(BaseVale.BAIA_VAGAS[k]), BaseVale.BAIA_ALTO, 0.0)
		no.transform = BaseVale.t_base * Transform3D(Basis(Vector3.UP, PI), onde)  # de frente para a frente da base
		add_child(no)
		_montar_cilindro(no)
		cilindros.append(no)


## O cilindro: um pé, uma tampa e um tubo de vidro quase invisível.
func _montar_cilindro(no: Node3D) -> void:
	var escuro := StandardMaterial3D.new()
	escuro.albedo_color = Color(0.13, 0.15, 0.17)
	escuro.roughness = 0.7
	for par: Array in [[0.06, 0.12], [1.86, 0.1]]:
		var disco := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.56
		cil.bottom_radius = 0.6
		cil.height = par[1]
		disco.mesh = cil
		disco.material_override = escuro
		disco.position.y = par[0]
		no.add_child(disco)
	var vidro := MeshInstance3D.new()
	var tubo := CylinderMesh.new()
	tubo.top_radius = 0.53
	tubo.bottom_radius = 0.53
	tubo.height = 1.7
	tubo.cap_top = false
	tubo.cap_bottom = false
	vidro.mesh = tubo
	var mv := StandardMaterial3D.new()
	mv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mv.albedo_color = Color(0.55, 0.9, 0.95, 0.2)
	mv.cull_mode = BaseMaterial3D.CULL_DISABLED
	mv.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vidro.material_override = mv
	vidro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vidro.position.y = 0.97
	no.add_child(vidro)
	# três hastes escuras, para o tubo se ler como cápsula e não como mesa
	for k in 3:
		var haste := MeshInstance3D.new()
		var cx := BoxMesh.new()
		cx.size = Vector3(0.05, 1.72, 0.05)
		haste.mesh = cx
		haste.material_override = escuro
		var ang := PI * 0.5 + k * TAU / 3.0  # nenhuma na frente
		haste.position = Vector3(cos(ang) * 0.55, 0.97, sin(ang) * 0.55)
		no.add_child(haste)
	# o cilindro é sólido: não se entra nele
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var forma := CylinderShape3D.new()
	forma.radius = 0.58
	forma.height = 1.9
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position.y = 0.95
	corpo.add_child(cs)
	no.add_child(corpo)
