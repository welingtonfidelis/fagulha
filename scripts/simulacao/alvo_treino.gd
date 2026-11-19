class_name AlvoTreino
extends Node3D
## Um alvo da simulação: uma esfera de luz parada no ar. Leva tiro, míssil, granada e o mergulho com impacto
## como as máquinas do vale (está no grupo "maquinas" e responde às mesmas chamadas), e desliga com dois
## acertos: fica cinza e religa sozinho depois de um tempo. Ninguém é destruído, nem aqui.

const RAIO := 1.1
const RELIGA := 8.0

var desligada := false
var acertos := 0
var desligamentos := 0
var _vida := 2.0
var _volta := 0.0
var _mat: StandardMaterial3D
var _acerto: StaticBody3D
var _pisca := 0.0


func _ready() -> void:
	add_to_group("maquinas")
	var mi := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = RAIO
	esfera.height = RAIO * 2.0
	mi.mesh = esfera
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = _mat
	add_child(mi)
	# um miolo, para parecer alvo e não bola
	var miolo := MeshInstance3D.new()
	var e2 := SphereMesh.new()
	e2.radius = RAIO * 0.42
	e2.height = RAIO * 0.84
	miolo.mesh = e2
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.albedo_color = Color(1, 1, 1)
	m2.no_depth_test = true
	miolo.material_override = m2
	add_child(miolo)
	_acerto = StaticBody3D.new()
	_acerto.collision_layer = 2
	_acerto.collision_mask = 0
	var cs := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = RAIO
	cs.shape = forma
	_acerto.add_child(cs)
	add_child(_acerto)
	_pintar()


func _pintar() -> void:
	_mat.albedo_color = Color(0.32, 0.36, 0.38) if desligada else (Color(1, 1, 1) if _pisca > 0.0 else Color(1.0, 0.55, 0.2))


func _process(delta: float) -> void:
	if _pisca > 0.0:
		_pisca -= delta
		if _pisca <= 0.0:
			_pintar()
	if desligada:
		_volta -= delta
		if _volta <= 0.0:
			desligada = false
			_vida = 2.0
			_pintar()


func centro() -> Vector3:
	return global_position


func raio_acerto() -> float:
	return RAIO


func ponto_de_trava() -> Vector3:
	return Vector3.INF if desligada else global_position


func levar_tiro(ponto: Vector3, dano := 1.0, area := 0.0) -> void:
	if desligada or ponto.distance_to(global_position) > RAIO + 0.4 + area:
		return
	acertos += 1
	_vida -= dano
	_pisca = 0.12
	Som.toque3d(self, Som.variacao("impacto", 3), ponto, -4.0)
	if _vida <= 0.0:
		desligar()
	_pintar()


func levar_impacto(ponto: Vector3) -> void:
	if not desligada and ponto.distance_to(global_position) < 9.0:
		desligar()


func desligar() -> void:
	desligada = true
	desligamentos += 1
	_volta = RELIGA
	_pintar()


func avancar_tempo(_seg: float) -> void:
	pass
