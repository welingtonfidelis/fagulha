class_name Corpo
extends RefCounted
## O corpo do robô em peças (doc §143, ideia do usuário): cabeça, tronco, braços e pernas de 13 conjuntos, só
## visuais (as juntas ficam nos mesmos lugares, então nada muda na mecânica nem nas animações). As peças de cada
## conjunto estão em assets/vale/corpo/<chave>.glb, feitas por tools/vale/robo_pecas.py: o esqueleto inteiro do
## robo_v2 (juntas vazias) com as peças do conjunto presas nas juntas. `ArmaduraVisual.vestir_corpo` passa cada
## peça para a junta de mesmo nome do robô do jogo e esconde a de fábrica. Os conjuntos abrem por nível.

const PARTES := ["cabeca", "tronco", "bracos", "pernas"]
const NOMES_PARTE := {"cabeca": "Cabeça", "tronco": "Tronco", "bracos": "Braços", "pernas": "Pernas"}
## As juntas de cada parte, como no gerador (`_peca_de` em robo_pecas.py). O rabo vem com o tronco.
const JUNTAS := {
	"cabeca": ["cabeca", "olhoE", "olhoD"],
	"tronco": ["tronco", "raiz"],
	"bracos": ["ombroE", "cotoveloE", "luvaE", "punhoE", "dedosE", "bocaE", "ombroD", "cotoveloD", "luvaD", "punhoD", "dedosD", "bocaD"],
	"pernas": ["quadrilE", "joelhoE", "tornozeloE", "quadrilD", "joelhoD", "tornozeloD"],
}
## Peças do robô que nenhum conjunto troca (o pescoço, a cintura e o jato dos pés).
const FIXAS := ["pescoco", "cintura", "lamina", "brasa_pe", "chama_pe"]
## [chave, nome, nome curto (no cartão), nível que abre]: dois por nível, até o 7 (as armas vão até o 5)
const CONJUNTOS := [
	["gato", "Gato", "Gato", 1], ["cachorro", "Cachorro", "Cachorro", 1],
	["urso", "Urso", "Urso", 2], ["enfermeira", "Enfermeira", "Enfermeira", 2],
	["besouro", "Besouro", "Besouro", 3], ["marinheiro", "Marinheiro", "Marinheiro", 3],
	["caldeira", "Caldeira", "Caldeira", 4], ["lucano", "Lucano", "Lucano", 4],
	["majestade", "Majestade", "Majestade", 5], ["sabre", "Dente-de-sabre", "Sabre", 5],
	["samurai", "Samurai", "Samurai", 6], ["solar", "Solar", "Solar", 6],
	["cavaleiro", "Cavaleiro", "Cavaleiro", 7],
]
## Os conjuntos com rabo (o rabo vem no tronco; o jogo balança parado e estica correndo e voando).
const COM_RABO := ["gato", "cachorro", "sabre"]

static var vestido := {"cabeca": "", "tronco": "", "bracos": "", "pernas": ""}
static var tudo := false  # testes e fotos: todos os conjuntos abertos
static var _cenas := {}
static var _retratos := {}


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
	return chave == "" or tudo or Arsenal.nivel() >= nivel(chave)


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
	var d = Guardado.progresso("corpo")
	if d is Dictionary:
		for parte: String in PARTES:
			var chave := String((d as Dictionary).get(parte, ""))
			vestido[parte] = chave if existe(chave) else ""


static func guardar() -> void:
	if Guardado.ativo:
		Guardado.por_progresso("corpo", vestido.duplicate())


static func zerar() -> void:
	for parte: String in PARTES:
		vestido[parte] = ""
