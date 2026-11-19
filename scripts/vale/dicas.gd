class_name Dicas
extends Node
## As dicas do drone colega no mundo: uma frase curta com a imagem do botão, na primeira vez que cada coisa
## acontece (chegar à ilha, chegar perto da oficina, pegar uma peça, entrar na água, esquentar, ver um
## cristal, chegar à Fundição). Cada dica aparece uma vez só; as vistas vão para o save ("dicas").
## Quem cria passa `armadura`, `hud`, `drone`, `pecas` e `memorias` (os dois últimos podem ser null).

const ESPACO := 14.0  # segundos, no mínimo, entre uma dica e a seguinte
const DURA := 10.0  # segundos que a dica fica na tela
# chave -> a frase (com `{acao}` para as imagens dos botões)
const TEXTOS := {
	"chegada": "Esta é a base. Tudo o que você achar na ilha, eu instalo aqui",
	"oficina": "A oficina fica no cilindro da base:  {agir}  na boca dele",
	"peca": "Achou uma peça! Pouse num lugar calmo que eu instalo",
	"fundicao_longe": "As máquinas da Fundição, a oeste, dão material para fabricar armas na oficina",
	"fundicao": "No painel da Fundição,  {agir}  acorda as máquinas. Derrotado, perde metade do material",
	"agua": "Na água:  {pular}  sobe,  {soltar}  desce. Ela esfria o motor",
	"calor": "Motor quente: pouse, ou voe rente à água",
	"memoria": "Um cristal de memória. Encoste nele para ler",
	"farol": "Você leu todas as memórias. Há uma luz apagada no nordeste, no Cabo do Vento",
	"maquina": "Uma máquina antiga. Elas não se quebram: desligam.  {mirar}  +  {atirar}",
}

var armadura: Armadura
var hud: Hud
var drone: DroneColega
var pecas: PecasMundo
var memorias: Memorias
var vistas: Array = []
var mostradas := 0  # quantas apareceram nesta partida (testes)

var _t := 0.0
var _pausa := 4.0  # espera até a próxima dica (a primeira vem logo depois de o jogo abrir)
var _fila: Array[String] = []


func _ready() -> void:
	if Guardado.ativo:
		vistas = (Guardado.progresso("dicas") as Array).duplicate()
	if pecas:
		pecas.achou.connect(func(_nome: String) -> void: pedir("peca"))
		pecas.instalou.connect(func(_nomes: Array) -> void: pedir("fundicao_longe"))


## Põe a dica na fila, se ainda não foi vista.
func pedir(chave: String) -> void:
	if TEXTOS.has(chave) and not vistas.has(chave) and not _fila.has(chave):
		_fila.append(chave)


func _process(delta: float) -> void:
	if armadura == null or hud == null:
		return
	_pausa -= delta
	_t += delta
	if _t >= 0.5:
		_t = 0.0
		_olhar()
	if _pausa > 0.0 or _fila.is_empty() or armadura.em_pane or armadura.travado:
		return
	var chave: String = _fila.pop_front()
	vistas.append(chave)
	mostradas += 1
	_pausa = ESPACO
	if Guardado.ativo:
		Guardado.por_progresso("dicas", vistas)
	hud.aconselhar(String(TEXTOS[chave]), DURA)
	if drone:
		drone.falar()
		drone.gesto("Look", 1.6)


## As situações que pedem dica, conferidas duas vezes por segundo.
func _olhar() -> void:
	var p := armadura.global_position
	pedir("chegada")
	if BaseVale.boca_cilindro.is_finite() and p.distance_to(BaseVale.boca_cilindro) < 22.0 and vistas.has("chegada"):
		pedir("oficina")
	if armadura.estado == Armadura.Estado.NADO:
		pedir("agua")
	if armadura.calor >= 70.0:
		pedir("calor")
	if Fundicao.montada and Vector2(p.x - Fundicao.CENTRO.x, p.z - Fundicao.CENTRO.y).length() < Fundicao.RAIO:
		pedir("fundicao")
	if memorias:
		for chave: String in memorias.onde:
			if not memorias.lidas.has(chave) and p.distance_to(memorias.onde[chave]) < 30.0:
				pedir("memoria")
				break
	if not vistas.has("maquina"):
		for n in get_tree().get_nodes_in_group("maquinas"):
			var maq := n as Node3D
			if maq and not bool(maq.get("desligada")) and maq.global_position.distance_to(p) < 55.0:
				pedir("maquina")
				break
