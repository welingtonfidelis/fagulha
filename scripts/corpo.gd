class_name Corpo
extends RefCounted
## O corpo do robô em peças (doc §143 e §146, ideia do usuário): cabeça, tronco, braço D e E, perna D e E de 15
## conjuntos, cada lado à parte, só visuais (as juntas ficam nos mesmos lugares, então nada muda na mecânica nem nas animações). As peças de cada
## conjunto estão em assets/vale/corpo/<chave>.glb, feitas por tools/vale/robo_pecas.py: o esqueleto inteiro do
## robo_v2 (juntas vazias) com as peças do conjunto presas nas juntas. `ArmaduraVisual.vestir_corpo` passa cada
## peça para a junta de mesmo nome do robô do jogo e esconde a de fábrica. Os conjuntos abrem por nível.

## As seis partes (2026-11-23, §146: braço e perna de cada lado à parte, como as vagas do gerador). D e E são do
## robô: de frente, o braço D fica à esquerda de quem olha.
const PARTES := ["cabeca", "tronco", "bracoD", "bracoE", "pernaD", "pernaE"]
const NOMES_PARTE := {"cabeca": "Cabeça", "tronco": "Tronco", "bracoD": "Braço D", "bracoE": "Braço E", "pernaD": "Perna D", "pernaE": "Perna E"}
## As juntas de cada parte, como no gerador (`_peca_de` em robo_pecas.py). O rabo vem com o tronco.
const JUNTAS := {
	"cabeca": ["cabeca", "olhoE", "olhoD"],
	"tronco": ["tronco", "raiz"],
	"bracoD": ["ombroD", "cotoveloD", "luvaD", "punhoD", "dedosD", "bocaD"],
	"bracoE": ["ombroE", "cotoveloE", "luvaE", "punhoE", "dedosE", "bocaE"],
	"pernaD": ["quadrilD", "joelhoD", "tornozeloD"],
	"pernaE": ["quadrilE", "joelhoE", "tornozeloE"],
}
## O save de antes de 2026-11-23 tinha os dois lados juntos: "bracos" e "pernas" viram os dois lados.
const ANTIGAS := {"bracos": ["bracoD", "bracoE"], "pernas": ["pernaD", "pernaE"]}
## Peças do robô que nenhum conjunto troca (o pescoço, a cintura e o jato dos pés).
const FIXAS := ["pescoco", "cintura", "lamina", "brasa_pe", "chama_pe"]
## [chave, nome, nome curto (no cartão), nível que abre]: um por nível, do 2 ao 12 (doc §148; antes eram dois por
## nível até o 7). Nível 0 é de robô achado: abre ao acordar aquele robô (ACHADOS), não por nível.
const CONJUNTOS := [
	["gato", "Gato", "Gato", 1], ["cachorro", "Cachorro", "Cachorro", 1],
	["urso", "Urso", "Urso", 2], ["enfermeira", "Enfermeira", "Enfermeira", 3],
	["besouro", "Besouro", "Besouro", 4], ["marinheiro", "Marinheiro", "Marinheiro", 5],
	["caldeira", "Caldeira", "Caldeira", 6], ["lucano", "Lucano", "Lucano", 7],
	["majestade", "Majestade", "Majestade", 8], ["sabre", "Dente-de-sabre", "Sabre", 9],
	["samurai", "Samurai", "Samurai", 10], ["solar", "Solar", "Solar", 11],
	["cavaleiro", "Cavaleiro", "Cavaleiro", 12],
	["antigo", "Antigo", "Antigo", 0], ["mergulhador", "Mergulhador", "Mergulhador", 0],
]
## Os conjuntos dos robôs achados (2026-11-23): o robô de cada um (o índice em RoboAntigo.ROBOS), a figura do
## lugar onde ele está (o cartão fechado mostra) e o lugar escrito.
const ACHADOS := {
	"antigo": {"robo": 0, "icone": "lua", "lugar": "no Observatório"},
	"mergulhador": {"robo": 1, "icone": "barbatanas", "lugar": "no fundo da Represa"},
}
## A cor de cada conjunto (o material da primeira cor de `cores()` em tools/vale/robo_pecas.py): com o tronco de um
## conjunto, os detalhes da mochila, as abas das costas e as peças das melhorias vão nela, no lugar do azul
## (pedido do usuário, 2026-11-23: tronco besouro, mochila e asas verdes).
const COR := {"besouro": "detalhe_besouro", "gato": "detalhe_gato", "urso": "placa_urso", "cachorro": "detalhe_cachorro",
	"caldeira": "placa_caldeira", "majestade": "placa_majestade", "lucano": "placa_lucano", "cavaleiro": "placa_cavaleiro",
	"enfermeira": "placa_enfermeira", "samurai": "placa_samurai", "marinheiro": "placa_marinheiro", "sabre": "placa_sabre",
	"solar": "placa_solar", "mergulhador": "placa_mergulhador", "antigo": "placa_antigo"}
## Os conjuntos com rabo (o rabo vem no tronco; o jogo balança parado e estica correndo e voando).
const COM_RABO := ["gato", "cachorro", "sabre"]

static var vestido := {"cabeca": "", "tronco": "", "bracoD": "", "bracoE": "", "pernaD": "", "pernaE": ""}
static var tudo := false  # testes e fotos: todos os conjuntos abertos
## Os conjuntos abertos que o jogador já viu na aba Corpo (doc §148): enquanto houver um aberto sem ver, a bússola, a
## boca do cilindro e a oficina avisam. Os do nível 1 vêm de saída e não contam como novos.
static var vistos := {}
static var resgatados := {}  # chave -> true: os robôs achados já acordados (RoboAntigo põe)
static var _cenas := {}
static var _retratos := {}
static var _minis := {}


static func _dados(chave: String) -> Array:
	for c: Array in CONJUNTOS:
		if c[0] == chave:
			return c
	return []


static func existe(chave: String) -> bool:
	return not _dados(chave).is_empty()


static func nome(chave: String) -> String:
	return "Original" if chave == "" else String(_dados(chave)[1]) if existe(chave) else chave


static func curto(chave: String) -> String:
	return "Original" if chave == "" else String(_dados(chave)[2]) if existe(chave) else chave


static func nivel(chave: String) -> int:
	return 1 if chave == "" or not existe(chave) else int(_dados(chave)[3])


static func aberto(chave: String) -> bool:
	if ACHADOS.has(chave):
		return tudo or bool(resgatados.get(chave, false))
	return chave == "" or tudo or Arsenal.nivel() >= nivel(chave)


## Os conjuntos abertos e ainda não vistos na aba Corpo, do mais novo para o mais velho.
static func novos() -> Array:
	var lista: Array = []
	for c: Array in CONJUNTOS:
		var k := String(c[0])
		if (int(c[3]) > 1 or ACHADOS.has(k)) and not vistos.has(k) and aberto(k) and not tudo:
			lista.push_front(k)
	return lista


## Viu o conjunto na aba Corpo: deixa de ser novo (guarda).
static func ver(chave: String) -> void:
	if chave == "" or vistos.has(chave) or not existe(chave):
		return
	vistos[chave] = true
	if Guardado.ativo:
		Guardado.por_progresso("corpo_vistos", vistos)


## Os conjuntos que abrem no nível `n` (para o cartão do nível).
static func do_nivel(n: int) -> Array:
	var lista: Array = []
	for c: Array in CONJUNTOS:
		if int(c[3]) == n and not ACHADOS.has(c[0]):
			lista.append(c[0])
	return lista


## O conjunto abre acordando um robô achado (e não por nível)?
static func de_achado(chave: String) -> bool:
	return ACHADOS.has(chave)


## O conjunto do robô achado `k` (índice em RoboAntigo.ROBOS), ou "".
static func do_robo(k: int) -> String:
	for chave: String in ACHADOS:
		if int(ACHADOS[chave]["robo"]) == k:
			return chave
	return ""


## O arquivo das peças do conjunto (carregado uma vez).
static func cena(chave: String) -> PackedScene:
	if chave == "" or not existe(chave):
		return null
	if not _cenas.has(chave):
		var caminho := "res://assets/vale/corpo/%s.glb" % chave
		_cenas[chave] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _cenas[chave]


## O retrato do conjunto (cabeça e ombros, fundo transparente) para a tela do cilindro.
static func retrato(chave: String) -> Texture2D:
	var k := chave if chave != "" else "atual"
	if not _retratos.has(k):
		var caminho := "res://assets/vale/corpo/retratos/%s.png" % k
		_retratos[k] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _retratos[k]


## A ordem das setas na aba Corpo: o de fábrica ("") e os conjuntos, os dos robôs achados no fim.
static func ordem() -> Array:
	var o: Array = [""]
	for c: Array in CONJUNTOS:
		o.append(c[0])
	return o


## A miniatura de uma peça sozinha (`parte` de PARTES), feita pelo robo_pecas.py (MINIATURAS=).
static func miniatura(chave: String, parte: String) -> Texture2D:
	var k := "%s_%s" % [chave if chave != "" else "atual", parte]
	if not _minis.has(k):
		var caminho := "res://assets/vale/corpo/pecas/%s.png" % k
		_minis[k] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _minis[k]


## A que parte do corpo pertence uma malha do robô (pela junta onde ela está presa), ou "" se nenhuma.
static func parte_de(no: Node) -> String:
	var pai := no.get_parent()
	if pai == null:
		return ""
	var n := String(no.name)
	for f: String in FIXAS:
		if n.begins_with(f):
			return ""
	var p := String(pai.name)
	for parte: String in PARTES:
		if (JUNTAS[parte] as Array).has(p):
			return parte
	return ""


static func carregar() -> void:
	zerar()
	if not Guardado.ativo:
		return
	var v = Guardado.progresso("corpo_vistos")
	vistos = (v as Dictionary).duplicate() if v is Dictionary else {}
	var d = Guardado.progresso("corpo")
	if d is Dictionary:
		var g := (d as Dictionary).duplicate()
		for velha: String in ANTIGAS:
			if g.has(velha):
				for p: String in ANTIGAS[velha]:
					if not g.has(p):
						g[p] = g[velha]
		for parte: String in PARTES:
			var chave := String(g.get(parte, ""))
			vestido[parte] = chave if existe(chave) else ""


static func guardar() -> void:
	if Guardado.ativo:
		Guardado.por_progresso("corpo", vestido.duplicate())


static func zerar() -> void:
	vistos = {}
	for parte: String in PARTES:
		vestido[parte] = ""
