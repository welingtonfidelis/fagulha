class_name Guardado
extends RefCounted
## O que o jogo guarda entre uma partida e outra, num arquivo só (user://faisca2.json): os ajustes
## (qualidade, sensibilidade, eixo, vibração) e o progresso (lugares já visitados, hora do dia, peças e
## melhorias). Nos testes e nas fotos (`ativo` falso) nada é lido nem gravado, para o resultado não
## depender da última partida.

const ARQUIVO := "user://faisca2.json"
const PADRAO := {
	"ajustes": {"qualidade": 1, "sensibilidade": 2, "inverter_y": false, "vibra": true},
	"progresso": {"lugares": [], "hora": 9.5, "pecas": [], "melhorias": [], "energia_base": 100.0, "escaneados": [], "arsenal": {}},
}

static var ativo := true
static var dados := {}
static var gravacoes := 0


static func carregar() -> void:
	dados = PADRAO.duplicate(true)
	if not ativo or not FileAccess.file_exists(ARQUIVO):
		return
	var lido = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if not (lido is Dictionary):
		return
	for parte: String in PADRAO:
		if lido.get(parte) is Dictionary:
			for chave: String in (lido[parte] as Dictionary):
				(dados[parte] as Dictionary)[chave] = lido[parte][chave]


static func salvar() -> void:
	if not ativo:
		return
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dados, "\t"))
		gravacoes += 1


static func ajuste(nome: String):
	if dados.is_empty():
		carregar()
	return (dados["ajustes"] as Dictionary).get(nome, (PADRAO["ajustes"] as Dictionary)[nome])


static func por_ajuste(nome: String, valor) -> void:
	if dados.is_empty():
		carregar()
	(dados["ajustes"] as Dictionary)[nome] = valor
	salvar()


static func progresso(nome: String):
	if dados.is_empty():
		carregar()
	return (dados["progresso"] as Dictionary).get(nome, (PADRAO["progresso"] as Dictionary)[nome])


static func por_progresso(nome: String, valor, gravar := true) -> void:
	if dados.is_empty():
		carregar()
	(dados["progresso"] as Dictionary)[nome] = valor
	if gravar:
		salvar()


## Apaga o progresso (os ajustes ficam).
static func recomecar_progresso() -> void:
	if dados.is_empty():
		carregar()
	dados["progresso"] = (PADRAO["progresso"] as Dictionary).duplicate(true)
	salvar()
