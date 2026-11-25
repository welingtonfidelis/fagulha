class_name VigiaArvore
extends RefCounted
## A cabeça do Vigia numa árvore de comportamento (teste da Beehave, 2026-11-20). A biblioteca é a
## Beehave 2.9.3 (bitbrain, MIT), em `addons/beehave`. A árvore só decide o que a máquina quer fazer
## (o `estado`); andar, desviar de obstáculo e atirar continuam no `Vigia`. Os dois nós globais que a
## Beehave pede (`BeehaveGlobalMetrics` e `BeehaveGlobalDebugger`) entram como autoload no `project.godot`.
##
## Do mais urgente para o menos, a cada quadro:
##   1. quente demais (levou dois tiros)  -> RECUA: anda de costas, de frente para o robô, até esfriar
##   2. vê o robô (ou viu há pouco)       -> CAÇA: como antes; ao começar, avisa as máquinas por perto
##   3. tem uma pista (perdeu de vista, levou tiro ou outra máquina avisou) -> PROCURA: vai até lá e olha em volta
##   4. está longe de casa                -> VOLTA
##   5. nada disso                        -> RONDA
## Antes da árvore a máquina sabia onde o robô estava mesmo sem ver (seguia até 70 m) e nunca recuava.

const MEMORIA := 2.5  # segundos que ela ainda "vê" o robô depois de perder de vista
const QUENTE := 60.0
const FRIO := 30.0
const RECUO_MAX := 6.0
const RECUO_FOLGA := 12.0  # depois de recuar, só recua de novo passado este tempo
const AVISO_RAIO := 38.0
const OLHAR := 4.0  # segundos olhando em volta no lugar da pista

static var arvores := 0  # quantas foram montadas (testes)
static var avisos := 0  # máquinas avisadas por outra (testes)
static var recuos := 0
static var procuras := 0


## Monta a árvore de um vigia e a devolve, já na cena (filha dele). Quem dá o passo é o vigia (`tick`).
static func montar(v: Vigia) -> BeehaveTree:
	var t := BeehaveTree.new()
	t.name = "Cabeca"
	t.process_thread = BeehaveTree.ProcessThread.MANUAL
	t.actor = v
	var raiz := SelectorReactiveComposite.new()
	raiz.name = "Decide"
	raiz.add_child(_par("Recuar", Quente.new(), Recuar.new()))
	raiz.add_child(_par("Cacar", VeORobo.new(), Cacar.new()))
	raiz.add_child(_par("Procurar", TemPista.new(), Procurar.new()))
	raiz.add_child(_par("Voltar", LongeDeCasa.new(), Voltar.new()))
	var ronda := Rondar.new()
	ronda.name = "Rondar"
	raiz.add_child(ronda)
	t.add_child(raiz)
	v.add_child(t)
	arvores += 1
	return t


static func _par(nome: String, cond: ConditionLeaf, acao: ActionLeaf) -> SequenceReactiveComposite:
	var s := SequenceReactiveComposite.new()
	s.name = nome
	cond.name = "Se"
	acao.name = "Faz"
	s.add_child(cond)
	s.add_child(acao)
	return s


## Chama as máquinas de perto que estão na ronda (ou voltando para casa): elas vão olhar `onde`. Quem chama é a
## que viu o robô ou a que levou um tiro; nesse caso (`alerta`) as chamadas também ficam em alerta (doc §167).
static func avisar(v: Vigia, onde: Vector3, alerta: bool) -> void:
	if not v.is_inside_tree() or not onde.is_finite():
		return
	for n: Node in v.get_tree().get_nodes_in_group(Vigia.GRUPO):
		var o := n as Vigia
		if o == null or o == v or o.desligada or o.arvore == null or o.pista.is_finite():
			continue
		if o.estado != Vigia.Estado.RONDA and o.estado != Vigia.Estado.VOLTA:
			continue
		if o.global_position.distance_to(v.global_position) < AVISO_RAIO:
			o.pista = onde
			o.procura_t = 0.0
			o.avisada += 1
			if alerta:
				o.alerta_t = Vigia.ALERTA
			avisos += 1


# ---------------------------------------------------------------- condições

class Quente extends ConditionLeaf:
	func tick(actor: Node, _b: Blackboard) -> int:
		var v := actor as Vigia
		if v.recuando:
			if v.calor < VigiaArvore.FRIO or v.recuo_t > VigiaArvore.RECUO_MAX or v.alvo == null or v.alvo.em_pane:
				v.recuando = false
				v.recuo_folga = VigiaArvore.RECUO_FOLGA
		elif v.calor >= VigiaArvore.QUENTE and v.recuo_folga <= 0.0 and v.estado == Vigia.Estado.CACA and not v.chefe:
			v.recuando = true
			v.recuo_t = 0.0
			VigiaArvore.recuos += 1
		return SUCCESS if v.recuando else FAILURE


class VeORobo extends ConditionLeaf:
	func tick(actor: Node, _b: Blackboard) -> int:
		var v := actor as Vigia
		if v.alvo == null or v.alvo.em_pane or v.alvo.graca_pane > 0.0:
			return FAILURE
		if v.sem_ver > VigiaArvore.MEMORIA:
			return FAILURE
		return SUCCESS if v.global_position.distance_to(v.alvo.global_position) < Vigia.PERDER else FAILURE


class TemPista extends ConditionLeaf:
	func tick(actor: Node, _b: Blackboard) -> int:
		return SUCCESS if (actor as Vigia).pista.is_finite() else FAILURE


class LongeDeCasa extends ConditionLeaf:
	func tick(actor: Node, _b: Blackboard) -> int:
		var v := actor as Vigia
		if v.estado == Vigia.Estado.RONDA:
			return FAILURE
		var d := v.casa - v.global_position
		d.y = 0.0
		return SUCCESS if d.length() > 2.0 else FAILURE


# ---------------------------------------------------------------- ações

class Recuar extends ActionLeaf:
	func tick(actor: Node, _b: Blackboard) -> int:
		(actor as Vigia).estado = Vigia.Estado.RECUA
		return RUNNING


class Cacar extends ActionLeaf:
	func tick(actor: Node, _b: Blackboard) -> int:
		var v := actor as Vigia
		if v.estado != Vigia.Estado.CACA:
			if v.estado != Vigia.Estado.RECUA:
				v._recarga = maxf(v._recarga, 1.0)
			v.estado = Vigia.Estado.CACA
			VigiaArvore.avisar(v, v.visto_em, false)
		# enquanto caça, a pista é o último lugar onde viu o robô: perdendo de vista, vai procurar lá
		v.pista = v.visto_em
		v.procura_t = 0.0
		return RUNNING


class Procurar extends ActionLeaf:
	func tick(actor: Node, _b: Blackboard) -> int:
		var v := actor as Vigia
		if v.estado != Vigia.Estado.PROCURA:
			v.estado = Vigia.Estado.PROCURA
			v._aviso = 0.0
			VigiaArvore.procuras += 1
		if v.procura_t >= VigiaArvore.OLHAR:
			v.pista = Vector3.INF
			v.procura_t = 0.0
			v.estado = Vigia.Estado.VOLTA
			return SUCCESS
		return RUNNING


class Voltar extends ActionLeaf:
	func tick(actor: Node, _b: Blackboard) -> int:
		var v := actor as Vigia
		if v.estado != Vigia.Estado.VOLTA:
			v.estado = Vigia.Estado.VOLTA
			v._aviso = 0.0
		return RUNNING


class Rondar extends ActionLeaf:
	func tick(actor: Node, _b: Blackboard) -> int:
		(actor as Vigia).estado = Vigia.Estado.RONDA
		return RUNNING
