class_name Arsenal
extends RefCounted
## O progresso de combate do robô (doc §66): a experiência e os materiais que a Fundição dá. Com eles o
## jogador vai fabricar armas, defesa e vida na base (etapas seguintes).

static var xp := 0
static var sucata := 0
static var nucleos := 0
static var chips := 0
static var ponto_volta := 1  # a onda em que a Fundição recomeça (salva a cada minichefe vencido)
static var recorde := 0  # a onda mais alta vencida
static var fabricados: Array = []  # o que já foi fabricado na oficina
static var tudo := false  # testes e fotos: a mira assistida vale (os testes antigos contam com ela)

## O que se fabrica na oficina da base com o que a Fundição dá. A ordem é a da lista na tela.
const RECEITAS := {
	"mira": {"titulo": "Mira assistida", "efeito": "Mirando, o tiro trava na máquina mais perto da mira.", "nivel": 2, "sucata": 15, "nucleos": 0, "chips": 0},
	"escudo": {"titulo": "Escudo de energia", "efeito": "Absorve um acerto e recarrega em 20 segundos.", "nivel": 3, "sucata": 30, "nucleos": 2, "chips": 0},
	"vida": {"titulo": "Vida extra", "efeito": "O robô aguenta um acerto a mais antes de desligar.", "nivel": 4, "sucata": 40, "nucleos": 3, "chips": 0},
}
const ESCUDO_RECARGA := 20.0


static func tem(nome: String) -> bool:
	return fabricados.has(nome) or (tudo and nome == "mira")


## "" se dá para fabricar; senão, o que falta.
static func falta(nome: String) -> String:
	var r: Dictionary = RECEITAS[nome]
	if nivel() < int(r["nivel"]):
		return "pede nível %d" % int(r["nivel"])
	if sucata < int(r["sucata"]) or nucleos < int(r["nucleos"]) or chips < int(r["chips"]):
		return "faltam materiais"
	return ""


static func custo(nome: String) -> String:
	var r: Dictionary = RECEITAS[nome]
	var partes := ["nível %d" % int(r["nivel"]), "%d sucata" % int(r["sucata"])]
	if int(r["nucleos"]) > 0:
		partes.append("%d núcleos" % int(r["nucleos"]))
	if int(r["chips"]) > 0:
		partes.append("%d chips" % int(r["chips"]))
	return " · ".join(partes)


static func fabricar(nome: String) -> bool:
	if fabricados.has(nome) or falta(nome) != "":
		return false
	var r: Dictionary = RECEITAS[nome]
	sucata -= int(r["sucata"])
	nucleos -= int(r["nucleos"])
	chips -= int(r["chips"])
	fabricados.append(nome)
	guardar()
	return true


## Quantos acertos desligam o robô.
static func golpes_pane() -> int:
	return Ajustes.PANE_GOLPES + (1 if tem("vida") else 0)



## O nível sai da experiência: cada nível pede 100 a mais que o anterior (100, 200, 300...).
static func nivel() -> int:
	var n := 1
	var resto := xp
	while resto >= n * 100:
		resto -= n * 100
		n += 1
	return n


## [quanto já tem neste nível, quanto o nível pede]
static func barra() -> Vector2i:
	var n := 1
	var resto := xp
	while resto >= n * 100:
		resto -= n * 100
		n += 1
	return Vector2i(resto, n * 100)


static func carregar() -> void:
	var d: Dictionary = Guardado.progresso("arsenal")
	xp = int(d.get("xp", 0))
	sucata = int(d.get("sucata", 0))
	nucleos = int(d.get("nucleos", 0))
	chips = int(d.get("chips", 0))
	ponto_volta = int(d.get("ponto_volta", 1))
	recorde = int(d.get("recorde", 0))
	fabricados = (d.get("fabricados", []) as Array).duplicate()


static func guardar() -> void:
	if Guardado.ativo:
		Guardado.por_progresso("arsenal", {"xp": xp, "sucata": sucata, "nucleos": nucleos, "chips": chips,
			"ponto_volta": ponto_volta, "recorde": recorde, "fabricados": fabricados})


static func zerar() -> void:
	xp = 0
	sucata = 0
	nucleos = 0
	chips = 0
	ponto_volta = 1
	recorde = 0
	fabricados = []
