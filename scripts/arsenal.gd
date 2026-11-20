class_name Arsenal
extends RefCounted
## O progresso de combate do robô (doc §66): a experiência e os materiais que a Fundição dá. Com eles o
## jogador vai fabricar armas, defesa e vida na base (etapas seguintes).

static var xp := 0
static var sucata := 0
static var nucleos := 0
static var chips := 0
static var recorde := 0  # a onda mais alta vencida
static var fabricados: Array = []  # o que já foi fabricado na oficina
static var modo := "pistola"  # a arma em uso (a roda do L1 troca)
static var granadas := 0  # no lançador agora
static var misseis := 0  # no lançador agora

## Os modos de tiro (doc §67). gatilho: "aperto" (um tiro por aperto), "segura" (repete) ou "carga" (segura
## para carregar e solta). dano é em tiros de pistola; area, o raio do estouro; fov, o zoom ao mirar.
## O tiro duplo vem cedo e a rajada tarde (pedido do usuário, 2026-11-20: com a rajada logo nas primeiras
## hordas as lutas ficavam fáceis demais).
const ORDEM := ["pistola", "duplo", "canhao", "precisao", "rajada", "misseis"]
const MODOS := {
	"pistola": {"som": "laser_pistola", "cor": Color(1.0, 0.55, 0.2), "boca": "muzzle_01", "comp": 2.2, "grosso": 1.0, "titulo": "Pistola", "resumo": "um tiro por aperto", "gatilho": "aperto", "cadencia": 0.2, "dano": 1.0, "calor": 3.5, "area": 0.0, "vel": 130.0},
	"rajada": {"som": "laser_rajada", "cor": Color(1.0, 0.88, 0.3), "boca": "muzzle_03", "comp": 1.5, "grosso": 0.6, "titulo": "Rajada", "resumo": "muitos tiros fracos; esquenta e para", "gatilho": "segura", "cadencia": 0.085, "dano": 0.34, "calor": 1.5, "area": 0.0, "vel": 150.0, "espalha": 0.022},
	"canhao": {"som": "canhao_tiro", "cor": Color(1.0, 0.35, 0.15), "boca": "muzzle_05", "comp": 1.6, "grosso": 2.6, "titulo": "Canhão", "resumo": "segure para carregar e solte", "gatilho": "carga", "cadencia": 0.7, "dano": 3.6, "calor": 13.0, "area": 5.0, "vel": 70.0, "carga": 1.1},
	"precisao": {"som": "laser_precisao", "cor": Color(0.35, 0.75, 1.0), "boca": "muzzle_02", "comp": 6.0, "grosso": 0.7, "titulo": "Precisão", "resumo": "zoom, um tiro forte e lento", "gatilho": "aperto", "cadencia": 1.15, "dano": 3.2, "calor": 8.0, "area": 0.0, "vel": 320.0, "fov": 20.0},
	"duplo": {"som": "laser_duplo", "cor": Color(0.4, 1.0, 0.8), "boca": "muzzle_01", "comp": 2.2, "grosso": 1.0, "titulo": "Tiro duplo", "resumo": "R2 o braço direito, L2 o esquerdo; menos preciso", "gatilho": "duplo", "cadencia": 0.2, "dano": 1.0, "calor": 3.5, "area": 0.0, "vel": 130.0, "espalha": 0.03, "solto": true},
	"misseis": {"som": "missil_sai", "titulo": "Mísseis", "resumo": "segure para travar até 4 alvos e solte", "gatilho": "trava", "cadencia": 0.9, "dano": 3.0, "calor": 4.0, "area": 4.5, "vel": 34.0},
}
## A espada de laser (R3 no chão): um golpe em arco, que alterna de lado a cada vez.
## O alcance é o do braço mais a lâmina curta de pulso, a partir do meio do robô: defesa de perto. Eram 3,6 m.
const ESPADA := {"dano": 2.0, "alcance": 1.4, "abre": 80.0, "tempo": 0.2, "espera": 0.3}
const GRANADA := {"dano": 2.6, "area": 7.0, "pavio": 4.5, "alcance": 55.0}
const ANGULO_LANCE := deg_to_rad(70.0)  # granadas e mísseis saem dos lançadores do ombro quase a pique


static func tem_arma(nome: String) -> bool:
	return nome == "pistola" or fabricados.has(nome) or tudo


static func granadas_max() -> int:
	return 3 if (fabricados.has("granadas") or tudo) else 0


static func misseis_max() -> int:
	return 8 if (fabricados.has("misseis") or tudo) else 0


## Enche os dois lançadores (na oficina e ao pegar uma caixa de munição).
static func repor_granadas() -> void:
	granadas = granadas_max()
	misseis = misseis_max()
static var tudo := false  # testes e fotos: a mira assistida vale (os testes antigos contam com ela)

## O que se fabrica na oficina da base com o que a Fundição dá. A ordem é a da lista na tela.
const RECEITAS := {
	"duplo": {"titulo": "Tiro duplo", "efeito": "Um tiro por aperto em cada braço: R2 o direito, L2 o esquerdo. Os dois juntos atiram ao mesmo tempo. Menos preciso que a pistola.", "nivel": 1, "sucata": 10, "nucleos": 0, "chips": 0},
	"granadas": {"titulo": "Lança-granadas", "efeito": "No ombro direito. Segure R1 (G) para ver o arco e solte. Três granadas; repõe na oficina e nas caixas da Fundição.", "nivel": 2, "sucata": 20, "nucleos": 0, "chips": 0},
	"canhao": {"titulo": "Canhão", "efeito": "Segure para carregar e solte: um tiro forte, que estoura em volta.", "nivel": 2, "sucata": 25, "nucleos": 1, "chips": 0},
	"precisao": {"titulo": "Precisão", "efeito": "Mirando, zoom forte e um tiro que vale três. Lento para recarregar.", "nivel": 3, "sucata": 30, "nucleos": 1, "chips": 0},
	"rajada": {"titulo": "Rajada", "efeito": "Metralhadora: segurando o gatilho, muitos tiros fracos. Esquenta: a curva ao lado da mira enche e, cheia, a rajada para até esfriar.", "nivel": 4, "sucata": 45, "nucleos": 2, "chips": 0},
	"misseis": {"titulo": "Lança-mísseis", "efeito": "No ombro esquerdo. Segure o gatilho para travar até quatro máquinas à frente e solte: um míssil segue cada uma. Oito mísseis.", "nivel": 5, "sucata": 60, "nucleos": 2, "chips": 1},
	"mira": {"titulo": "Mira assistida", "efeito": "Mirando, o tiro trava na máquina mais perto da mira.", "nivel": 2, "sucata": 15, "nucleos": 0, "chips": 0},
	"escudo": {"titulo": "Escudo de energia", "efeito": "Absorve três acertos; quebrado, recarrega em 20 segundos.", "nivel": 3, "sucata": 30, "nucleos": 2, "chips": 0},
	"vida": {"titulo": "Vida extra", "efeito": "O robô aguenta um acerto a mais antes de desligar.", "nivel": 4, "sucata": 40, "nucleos": 3, "chips": 0},
}
const ESCUDO_RECARGA := 20.0
const ESCUDO_CARGAS := 3  # acertos que o escudo engole antes de quebrar


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
	CartaoPeca.avisar(nome)
	if nome == "granadas" or nome == "misseis":
		repor_granadas()
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
	recorde = int(d.get("recorde", 0))
	fabricados = (d.get("fabricados", []) as Array).duplicate()
	modo = String(d.get("modo", "pistola"))
	if not MODOS.has(modo) or not tem_arma(modo):
		modo = "pistola"
	granadas = granadas_max()


static func guardar() -> void:
	if Guardado.ativo:
		Guardado.por_progresso("arsenal", {"xp": xp, "sucata": sucata, "nucleos": nucleos, "chips": chips,
			"recorde": recorde, "fabricados": fabricados, "modo": modo})


static func zerar() -> void:
	xp = 0
	sucata = 0
	nucleos = 0
	chips = 0
	recorde = 0
	fabricados = []
	modo = "pistola"
	granadas = 0
	misseis = 0
