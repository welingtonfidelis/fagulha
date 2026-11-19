class_name SimMapa
extends Ilha
## O mundo da simulação (o tutorial "dentro da cabeça do robô"): um chão plano sem fim, com uma grade de luz.
## Não tem relevo, água nem árvores; o chão e a colisão acompanham o robô, então dá para voar para qualquer
## lado sem chegar a uma borda. Quem cria passa `alvo` (o robô) depois de pô-lo na cena.

const LADO := 6000.0

var alvo: Node3D
var _chao: MeshInstance3D
var _corpo: StaticBody3D


func gerar(_semente := 7) -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(LADO, LADO)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/sim_chao.gdshader")
	plano.material = mat
	_chao = MeshInstance3D.new()
	_chao.mesh = plano
	_chao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chao)
	_corpo = StaticBody3D.new()
	_corpo.name = "ChaoColisao"
	_corpo.collision_layer = 1
	_corpo.collision_mask = 0
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(LADO, 4.0, LADO)
	var cs := CollisionShape3D.new()
	cs.shape = caixa
	cs.position = Vector3(0, -2.0, 0)
	_corpo.add_child(cs)
	add_child(_corpo)
	spawn = Vector3(0, 0.4, 0)
	spawn_yaw = 0.0


func _physics_process(_delta: float) -> void:
	if alvo == null:
		return
	var p := alvo.global_position
	# a malha anda de 40 em 40 m (o passo da grade grossa), para as linhas não escorregarem
	_chao.position = Vector3(snappedf(p.x, 40.0), 0.0, snappedf(p.z, 40.0))
	if Vector2(p.x - _corpo.position.x, p.z - _corpo.position.z).length() > LADO * 0.3:
		_corpo.position = Vector3(snappedf(p.x, 40.0), 0.0, snappedf(p.z, 40.0))


func altura(_x: float, _z: float) -> float:
	return 0.0


func agua(_x: float, _z: float) -> float:
	return -INF


func na_cachoeira(_p: Vector3) -> bool:
	return false


func agua_perto(_p: Vector3) -> bool:
	return false


func normal_em(_x: float, _z: float) -> Vector3:
	return Vector3.UP


func atualizar_colisao_arvores(_centro: Vector3, _forcar := false) -> void:
	pass
