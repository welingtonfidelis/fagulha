class_name PoseInimigo
extends RefCounted
## O que o ArmaduraVisual lê da Armadura, para um robô inimigo (InimigoVisual): os inimigos são o nosso robô
## com outra pintura e se mexem com as mesmas poses (andar, correr, pular, pousar, esquivar, mirar com o braço
## estendido, golpe de espada em arco, pane). Quem enche é o InimigoVisual, a cada quadro, pela IA do Vigia.
## As velocidades vão no espaço do modelo (já divididas pela escala do inimigo) para a passada não escorregar.


## A "câmera" de quem mira: só o giro e a inclinação que o braço segue.
class Mira:
	var yaw := 0.0
	var pitch := 0.0


var estado: int = Armadura.Estado.CHAO
var velocity := Vector3.ZERO
var camera := Mira.new()
var dir_voo := Vector3.FORWARD
var em_pane := false
var no_assento := false
var assento_fase := 1
var assento_p := 1.0
var assento_yaw := 0.0
var postura := 0
var erguendo := 0.0
var atirando := 0.0
var atirando_e := 0.0
var espada_t := 0.0
var espada_lado := 1.0
var esquivando := 0.0
var pouso_forca := 0.3
var nado_rapido := false
var giro_lateral := 0.0
var inclinar := 0.0
var superaquecido := false
var manobra := 0.0
var manobra_lado := 0.0
var impulso := 0.0
var clarao_tiro := 0.0
var arrancada := false
var mergulhando := false
var calor := 0.0
var _tempo_estado := 1.0
var altura := 1.2  # do corpo, em metros do modelo


func mirando_agora() -> bool:
	return false


func em_voo() -> bool:
	return false


func chegando_ao_chao() -> bool:
	return false


func motor_ligado() -> bool:
	return false


func altura_corpo() -> float:
	return altura
