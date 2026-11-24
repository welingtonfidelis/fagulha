class_name Arsenal
extends RefCounted
## O progresso de combate do robô (doc §66): a experiência e os materiais que a Fundição dá. Com eles o
## jogador vai fabricar armas, defesa e vida na base (etapas seguintes).

static var xp := 0
## A experiência das descobertas (doc §148): chave -> true, o que já pagou (lugares, memórias, peças, rotas...).
static var descobertas := {}
## O fôlego da luta (doc §148): a experiência da Fundição e das máquinas soltas rende cheio até `FOLEGO_MAX` por dia
## de jogo; passando, rende `FOLEGO_FORA`. Enche de novo com as horas do dia (Experiencia).
const FOLEGO_MAX := 1200.0
const FOLEGO_FORA := 0.25
static var folego := FOLEGO_MAX
## Cada nível pede 500 a mais que o anterior (doc §148; antes eram 100). A versão 2 do save começa do zero.
const PASSO_NIVEL := 400
const XP_VERSAO := 2
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
## A roda segue a ordem em que as armas abrem (doc §158): o tiro duplo cedo, a precisão, a rajada, o canhão e por
## último os mísseis. A rajada continua longe do começo (pedido do usuário, 2026-11-20: com ela logo nas primeiras
## hordas as lutas ficavam fáceis demais).
const ORDEM := ["pistola", "duplo", "precisao", "rajada", "canhao", "misseis"]
const MODOS := {
	"pistola": {"som": "laser_pistola", "cor": Color(1.0, 0.55, 0.2), "boca": "muzzle_01", "comp": 2.2, "grosso": 1.0, "titulo": "Pistola", "resumo": "um tiro por aperto", "gatilho": "aperto", "cadencia": 0.2, "dano": 1.0, "calor": 3.5, "area": 0.0, "vel": 130.0},
	"rajada": {"som": "laser_rajada", "cor": Color(1.0, 0.88, 0.3), "boca": "muzzle_03", "comp": 1.5, "grosso": 0.6, "titulo": "Rajada", "resumo": "muitos tiros fracos; esquenta e para", "gatilho": "segura", "cadencia": 0.085, "dano": 0.34, "calor": 1.5, "area": 0.0, "vel": 150.0, "espalha": 0.022},
	"canhao": {"som": "canhao_tiro", "cor": Color(1.0, 0.35, 0.15), "boca": "muzzle_05", "comp": 1.6, "grosso": 2.6, "titulo": "Canhão", "resumo": "segure para carregar e solte", "gatilho": "carga", "cadencia": 0.7, "dano": 3.6, "calor": 13.0, "area": 5.0, "vel": 70.0, "carga": 1.1},
	"precisao": {"som": "laser_precisao", "cor": Color(0.35, 0.75, 1.0), "boca": "muzzle_02", "comp": 6.0, "grosso": 0.7, "titulo": "Precisão", "resumo": "zoom, um tiro forte e lento", "gatilho": "aperto", "cadencia": 1.15, "dano": 3.2, "calor": 8.0, "area": 0.0, "vel": 320.0, "fov": 20.0},
	"duplo": {"som": "laser_duplo", "cor": Color(0.4, 1.0, 0.8), "boca": "muzzle_01", "comp": 2.2, "grosso": 1.0, "titulo": "Tiro duplo", "resumo": "R2 o braço direito, L2 o esquerdo; menos preciso", "gatilho": "duplo", "cadencia": 0.2, "dano": 0.7, "calor": 3.5, "area": 0.0, "vel": 130.0, "espalha": 0.03, "solto": true},
	"misseis": {"som": "missil_sai", "titulo": "Mísseis", "resumo": "segure para travar os alvos e solte", "gatilho": "trava", "cadencia": 0.9, "dano": 3.0, "calor": 4.0, "area": 4.5, "vel": 34.0},
}
## A espada de laser (quadrado no chão): um golpe em arco, que alterna de lado a cada vez.
## O alcance é o do braço mais a lâmina curta de pulso, a partir do meio do robô: defesa de perto. Eram 3,6 m.
const ESPADA := {"dano": 2.0, "alcance": 1.4, "abre": 80.0, "tempo": 0.2, "espera": 0.3}
const GRANADA := {"dano": 2.6, "area": 7.0, "pavio": 4.5, "alcance": 55.0}
const ANGULO_LANCE := deg_to_rad(70.0)  # granadas e mísseis saem dos lançadores do ombro quase a pique


static func tem_arma(nome: String) -> bool:
	return nome == "pistola" or fabricados.has(nome) or tudo


static func granadas_max() -> int:
	return 3 + int(_soma("granadas", "municao")) if (fabricados.has("granadas") or tudo) else 0


static func misseis_max() -> int:
	return 8 + int(_soma("misseis", "municao")) if (fabricados.has("misseis") or tudo) else 0


## Quantas máquinas os mísseis travam de uma vez (4; o último degrau do lança-mísseis trava 5).
static func alvos_misseis() -> int:
	return 4 + int(_soma("misseis", "alvos"))


# ---------------------------------------------------------------- os degraus das armas

## As melhorias das armas na oficina (pedido do usuário, 2026-11-21: dar sentido à experiência e ao material
## ganho). Cada arma sobe três degraus depois de fabricada; o que cada degrau soma está aqui. Nos números de
## tiro é uma fração do valor de fábrica (dano 0,15 = 15 % a mais por degrau; espalha -0,25 = um quarto a
## menos); "municao" e "alvos" são de unidade em unidade.
const DEGRAUS := 3
const MELHORA := {
	"pistola": {"dano": 0.15, "cadencia": -0.06},
	"duplo": {"dano": 0.12, "espalha": -0.25},
	"canhao": {"dano": 0.12, "carga": -0.15, "area": 0.08},
	"precisao": {"dano": 0.15, "cadencia": -0.1},
	"rajada": {"dano": 0.12, "espalha": -0.2, "enche": -0.12},
	"misseis": {"dano": 0.1, "municao": 2, "alvos": 0},
	"granadas": {"dano": 0.1, "area": 0.08, "municao": 1},
	"espada": {"dano": 0.15, "alcance": 0.1},
	# o escudo (pedido do usuário, 2026-11-21): fabricado segura 1 acerto e cada degrau soma mais um, até 3
	"escudo": {"cargas": 1},
}
## O que cada degrau dá, em poucas palavras (a tela da oficina mostra o do próximo).
const MELHORA_TEXTO := {
	"pistola": "mais dano e um tiro mais depressa",
	"duplo": "mais dano e mais preciso",
	"canhao": "mais dano, carrega mais depressa e estoura maior",
	"precisao": "mais dano e recarrega mais depressa",
	"rajada": "mais dano, mais precisa e esquenta menos",
	"misseis": "mais dano e dois mísseis a mais",
	"granadas": "mais dano, estouro maior e uma granada a mais",
	"espada": "mais dano e a lâmina alcança mais longe",
	"escudo": "segura um acerto a mais",
}
## O custo de cada degrau (1, 2 e 3): o nível do robô é somado ao nível da receita da arma. O terceiro soma 6 desde
## 2026-11-24 (doc §158; era 5): com a curva lenta, os degraus vão até o nível 15, junto com os conjuntos.
const CUSTO_DEGRAU := [
	{"nivel": 1, "sucata": 15, "nucleos": 0, "chips": 0},
	{"nivel": 3, "sucata": 30, "nucleos": 1, "chips": 0},
	{"nivel": 6, "sucata": 50, "nucleos": 2, "chips": 1},
]
## O nível de partida dos degraus das armas de fábrica, que não têm receita (doc §158): a pistola no 1, 3 e 6;
## a espada no 3, 5 e 8.
const BASE_DEGRAU := {"pistola": 0, "espada": 2}

static var degraus := {}  # arma -> degrau feito (0 a 3)
static var _cache := {}  # arma -> os números com os degraus somados


static func degrau(arma: String) -> int:
	return int(degraus.get(arma, 0))


## Quantos degraus a coisa tem: as armas 3; o escudo 2 (a primeira luz acende ao fabricar).
static func degraus_de(arma: String) -> int:
	return ESCUDO_CARGAS - 1 if arma == "escudo" else DEGRAUS


## Os acertos que o escudo engole antes de quebrar: 1 de fábrica e mais um por degrau.
static func escudo_cargas() -> int:
	return mini(1 + degrau("escudo"), ESCUDO_CARGAS)


static func _soma(arma: String, chave: String) -> float:
	var m: Dictionary = MELHORA.get(arma, {})
	var extra := float(m.get(chave, 0.0)) * degrau(arma)
	if arma == "misseis" and chave == "alvos" and degrau(arma) >= DEGRAUS:
		extra = 1.0
	return extra


## Os números de uma arma de tiro com os degraus somados (a `Tiro` lê daqui, não de `MODOS`).
static func dados(arma: String) -> Dictionary:
	if _cache.has(arma):
		return _cache[arma]
	var d: Dictionary = MODOS.get(arma, MODOS["pistola"]).duplicate()
	if arma == "espada":
		d = ESPADA.duplicate()
	elif arma == "granadas":
		d = GRANADA.duplicate()
	var m: Dictionary = MELHORA.get(arma, {})
	for k: String in m:
		if k == "municao" or k == "alvos":
			continue
		if d.has(k) or k == "enche":
			d[k] = float(d.get(k, 1.0)) * maxf(0.1, 1.0 + float(m[k]) * degrau(arma))
	_cache[arma] = d
	return d


static func espada() -> Dictionary:
	return dados("espada")


static func granada() -> Dictionary:
	return dados("granadas")


## A arma pode subir de degrau? (fabricada, de fábrica ou já no topo contam)
static func pode_melhorar(arma: String) -> bool:
	return MELHORA.has(arma) and (arma == "pistola" or arma == "espada" or fabricados.has(arma)) and degrau(arma) < degraus_de(arma)


## O que o próximo degrau dá (o último do lança-mísseis também trava uma máquina a mais).
static func texto_degrau(arma: String) -> String:
	var t := String(MELHORA_TEXTO.get(arma, "mais dano"))
	if arma == "misseis" and degrau(arma) == DEGRAUS - 1:
		t += "; trava cinco máquinas"
	return t


## O escudo pula o primeiro degrau da escada (a fabricação já acende a primeira luz).
static func custo_degrau(arma: String) -> Dictionary:
	var i := degrau(arma) + (DEGRAUS - degraus_de(arma))
	var c: Dictionary = CUSTO_DEGRAU[mini(i, DEGRAUS - 1)].duplicate()
	c["nivel"] = int(c["nivel"]) + (int(RECEITAS[arma]["nivel"]) if RECEITAS.has(arma) else int(BASE_DEGRAU.get(arma, 1)))
	return c


## "" se dá para subir o degrau; senão, o que falta.
static func falta_degrau(arma: String) -> String:
	if not pode_melhorar(arma):
		return "no topo" if degrau(arma) >= degraus_de(arma) else "fabrique antes"
	var c := custo_degrau(arma)
	if nivel() < int(c["nivel"]):
		return "pede nível %d" % int(c["nivel"])
	if sucata < int(c["sucata"]) or nucleos < int(c["nucleos"]) or chips < int(c["chips"]):
		return "faltam materiais"
	return ""


static func texto_custo(c: Dictionary) -> String:
	var partes := ["%d sucata" % int(c["sucata"])]
	if int(c["nucleos"]) > 0:
		partes.append("%d %s" % [int(c["nucleos"]), "núcleo" if int(c["nucleos"]) == 1 else "núcleos"])
	if int(c["chips"]) > 0:
		partes.append("%d %s" % [int(c["chips"]), "chip" if int(c["chips"]) == 1 else "chips"])
	return " · ".join(partes)


static func melhorar(arma: String) -> bool:
	if falta_degrau(arma) != "":
		return false
	var c := custo_degrau(arma)
	sucata -= int(c["sucata"])
	nucleos -= int(c["nucleos"])
	chips -= int(c["chips"])
	degraus[arma] = degrau(arma) + 1
	_cache.clear()
	if arma == "granadas" or arma == "misseis":
		repor_granadas()
	guardar()
	return true


# ---------------------------------------------------------------- os prêmios

## O prêmio de uma máquina desligada, na conta da Fundição (doc §66): `onda` é o nível dela (a onda da
## Fundição, o nível do acampamento ou o da toca do procurado) e `chefe` a máquina grande. Os acampamentos e os
## procurados usam a mesma conta (pedido do usuário, 2026-11-21: vencer lá fora rende o mesmo que na Fundição).
static func premio(chefe: bool, onda: int, semente: int) -> Dictionary:
	var g := {"xp": roundi((80.0 if chefe else 10.0) * (1.0 + onda * 0.15)), "sucata": 6 if chefe else 1 + int(semente % 3 == 0), "nucleos": 0, "chips": 0}
	if chefe:
		g["nucleos"] = 2
		g["chips"] = 1
	elif onda >= 4 and semente % 4 == 0:
		g["nucleos"] = 1
	return g


## Soma o prêmio e guarda. Devolve true se o nível do robô subiu.
static func ganhar(g: Dictionary) -> bool:
	var antes := nivel()
	xp += int(g.get("xp", 0))
	sucata += int(g.get("sucata", 0))
	nucleos += int(g.get("nucleos", 0))
	chips += int(g.get("chips", 0))
	guardar()
	return nivel() > antes


## "+54 de experiência · +4 sucata · +1 núcleo" (os avisos).
static func texto_premio(g: Dictionary) -> String:
	var partes := ["+%d de experiência" % int(g.get("xp", 0)), "+%d sucata" % int(g.get("sucata", 0))]
	if int(g.get("nucleos", 0)) > 0:
		partes.append("+%d %s" % [int(g["nucleos"]), "núcleo" if int(g["nucleos"]) == 1 else "núcleos"])
	if int(g.get("chips", 0)) > 0:
		partes.append("+%d %s" % [int(g["chips"]), "chip" if int(g["chips"]) == 1 else "chips"])
	return " · ".join(partes)


## Enche os dois lançadores (na oficina e ao pegar uma caixa de munição).
static func repor_granadas() -> void:
	granadas = granadas_max()
	misseis = misseis_max()
static var tudo := false  # testes e fotos: a mira assistida vale (os testes antigos contam com ela)

## O que se fabrica na oficina da base com o que a Fundição dá. A ordem é a da lista na tela.
## Desde 2026-11-24 (doc §158, revisão do game designer com a curva lenta da §154), uma coisa nova por nível, do 1
## ao 9; o usuário trocou a rajada (7) com o canhão (8). Antes: duplo 1, granadas, canhão e mira 2, precisão e
## escudo 3, rajada e vida 4, mísseis 5.
const RECEITAS := {
	"duplo": {"titulo": "Tiro duplo", "efeito": "Um tiro por aperto em cada braço: R2 o direito, L2 o esquerdo. Os dois juntos atiram ao mesmo tempo. Menos preciso que a pistola.", "nivel": 1, "sucata": 10, "nucleos": 0, "chips": 0},
	"mira": {"titulo": "Mira assistida", "efeito": "Mirando, o tiro trava na máquina mais perto da mira.", "nivel": 2, "sucata": 15, "nucleos": 0, "chips": 0},
	"escudo": {"titulo": "Escudo de energia", "efeito": "Absorve um acerto, e mais um a cada melhoria (até três); quebrado, recarrega em 20 segundos.", "nivel": 3, "sucata": 30, "nucleos": 2, "chips": 0},
	"granadas": {"titulo": "Lança-granadas", "efeito": "No ombro direito. Segure R1 (G) para ver o arco e solte. Três granadas; repõe na oficina e nas caixas da Fundição.", "nivel": 4, "sucata": 25, "nucleos": 0, "chips": 0},
	"vida": {"titulo": "Vida extra", "efeito": "O robô aguenta um acerto a mais antes de desligar.", "nivel": 5, "sucata": 40, "nucleos": 3, "chips": 0},
	"precisao": {"titulo": "Precisão", "efeito": "Mirando, zoom forte e um tiro que vale três. Lento para recarregar.", "nivel": 6, "sucata": 45, "nucleos": 1, "chips": 0},
	"rajada": {"titulo": "Rajada", "efeito": "Metralhadora: segurando o gatilho, muitos tiros fracos. Esquenta: a curva ao lado da mira enche e, cheia, a rajada para até esfriar.", "nivel": 7, "sucata": 50, "nucleos": 2, "chips": 0},
	"canhao": {"titulo": "Canhão", "efeito": "Segure para carregar e solte: um tiro forte, que estoura em volta.", "nivel": 8, "sucata": 55, "nucleos": 2, "chips": 0},
	"misseis": {"titulo": "Lança-mísseis", "efeito": "No ombro esquerdo. Segure o gatilho para travar até quatro máquinas à frente e solte: um míssil segue cada uma. Oito mísseis.", "nivel": 9, "sucata": 70, "nucleos": 3, "chips": 1},
}
const ESCUDO_RECARGA := 20.0
const ESCUDO_CARGAS := 3  # o máximo de acertos que o escudo engole (no último degrau); veja escudo_cargas()


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
	if nome == "escudo":
		degraus["escudo"] = 0  # a chave marca o escudo novo, de 1 acerto (veja carregar)
	CartaoPeca.avisar(nome)
	if nome == "granadas" or nome == "misseis":
		repor_granadas()
	guardar()
	return true


## Quantos acertos desligam o robô.
static func golpes_pane() -> int:
	return Ajustes.PANE_GOLPES + (1 if tem("vida") else 0) + (1 if Melhorias.tem("couraca") else 0)



## A experiência que o nível `n` pede, desde o zero: cada nível pede 400 a mais que o anterior (400, 800,
## 1.200...), então o nível 2 vem com 400, o 3 com 1.200, o 12 com 26.400 e o 15 com 42.000 (doc §148 e §154; antes o
## passo era 500 e os conjuntos acabavam no 12).
static func xp_do_nivel(n: int) -> int:
	return PASSO_NIVEL / 2 * n * (n - 1)


static func nivel() -> int:
	var n := 1
	while xp >= xp_do_nivel(n + 1):
		n += 1
	return n


## [quanto já tem neste nível, quanto o nível pede]
static func barra() -> Vector2i:
	var n := nivel()
	return Vector2i(xp - xp_do_nivel(n), xp_do_nivel(n + 1) - xp_do_nivel(n))


## A experiência de uma luta (a Fundição e as máquinas soltas) passa pelo fôlego: rende cheio enquanto ele dura e um
## quarto depois. Gasta o fôlego e devolve o prêmio com a experiência que vale.
static func pelo_folego(g: Dictionary) -> Dictionary:
	var bruto := int(g.get("xp", 0))
	var cheio := mini(bruto, int(folego))
	var r := g.duplicate()
	r["xp"] = cheio + roundi((bruto - cheio) * FOLEGO_FORA)
	folego = maxf(0.0, folego - bruto)
	return r


static func carregar() -> void:
	var d: Dictionary = Guardado.progresso("arsenal")
	# o save de antes da curva nova começa a experiência do zero (pedido do usuário, 2026-11-23)
	xp = int(d.get("xp", 0)) if int(d.get("versao", 1)) >= XP_VERSAO else 0
	descobertas = (d.get("descobertas", {}) as Dictionary).duplicate()
	folego = float(d.get("folego", FOLEGO_MAX))
	sucata = int(d.get("sucata", 0))
	nucleos = int(d.get("nucleos", 0))
	chips = int(d.get("chips", 0))
	recorde = int(d.get("recorde", 0))
	fabricados = (d.get("fabricados", []) as Array).duplicate()
	degraus = (d.get("degraus", {}) as Dictionary).duplicate()
	# o escudo fabricado antes dos degraus já segurava três acertos: continua assim
	if fabricados.has("escudo") and not degraus.has("escudo"):
		degraus["escudo"] = degraus_de("escudo")
	_cache.clear()
	modo = String(d.get("modo", "pistola"))
	if not MODOS.has(modo) or not tem_arma(modo):
		modo = "pistola"
	granadas = granadas_max()


static func guardar() -> void:
	if Guardado.ativo:
		Guardado.por_progresso("arsenal", {"xp": xp, "sucata": sucata, "nucleos": nucleos, "chips": chips,
			"recorde": recorde, "fabricados": fabricados, "modo": modo, "degraus": degraus, "versao": XP_VERSAO,
			"descobertas": descobertas, "folego": folego})


static func zerar() -> void:
	xp = 0
	descobertas = {}
	folego = FOLEGO_MAX
	sucata = 0
	nucleos = 0
	chips = 0
	recorde = 0
	fabricados = []
	degraus = {}
	_cache.clear()
	modo = "pistola"
	granadas = 0
	misseis = 0
