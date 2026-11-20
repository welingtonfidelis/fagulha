class_name MechVisual
extends Node3D
## A base do corpo animado das máquinas (quem monta o corpo é o InimigoVisual): tocar uma animação pelo nome
## comum (Idle, Walk, Run, Shoot, Death...), e os efeitos.
## A frente fica em -Z e os pés na origem. `olho` acende uma luz vermelha na cabeça (o aviso de ataque),
## `clarao` pisca o corpo ao levar tiro e `apagar` escurece a máquina desligada.

const LACOS := ["Idle", "Walk", "Run", "Walk_Tall", "Run_Tall", "Dance"]

var anim: AnimationPlayer
var mat: ShaderMaterial
var luz: OmniLight3D
var cabeca: BoneAttachment3D
var altura := 1.0
var atual := ""
var chao: Callable  # (x, z) -> altura do terreno; sem ele vale o plano da origem
var boca: Node3D  # de onde sai o tiro (a arma); sem ela, a cabeça
var alvo_mira := Vector3.INF  # no mundo: onde está quem a máquina ataca (o InimigoVisual aponta o braço para lá)
var margem_caido := 0.09  # caído (Death), o osso mais baixo fica a esta fração da altura acima do chão
var _esq: Skeleton3D
var _raiz: Node3D
var _sobe := 0.0
var _raiz_y := 0.0


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
		# mede cada osso contra o terreno debaixo dele (o corpo caído se espalha por uns metros) e desce ou sobe
		# o corpo até o mais baixo encostar no chão
		var menor := INF
		for i in _esq.get_bone_count():
			var nome_osso := _esq.get_bone_name(i)
			if nome_osso.contains("Pole") or nome_osso.contains("Attachment") or nome_osso == "c_traj" or nome_osso == "lookAt":
				continue
			var w := _esq.global_transform * _esq.get_bone_global_pose(i).origin
			var piso: float = float(chao.call(w.x, w.z)) if chao.is_valid() else global_position.y
			menor = minf(menor, w.y - piso)
		alvo = clampf(_sobe + margem_caido * altura - menor, -4.0, 4.0)
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


## De onde sai o tiro: a arma, se houver; senão a cabeça.
func ponto_tiro() -> Vector3:
	return boca.global_position if boca and is_instance_valid(boca) else ponto_cabeca()


## Quanto tempo depois de começar a animação de ataque o tiro sai (ou o golpe pega).
func tempo_do_tiro() -> float:
	return 0.3


## Onde fica a cabeça, no mundo.
func ponto_cabeca() -> Vector3:
	return cabeca.global_position if cabeca else global_position + Vector3(0, altura * 0.85, 0)


func olho(energia: float) -> void:
	if luz:
		luz.light_energy = energia


func clarao(v: float) -> void:
	mat.set_shader_parameter("clarao", v)


func apagar(v: float) -> void:
	mat.set_shader_parameter("apagado", v)
