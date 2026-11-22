class_name Guardado
extends RefCounted
## O que o jogo guarda entre uma partida e outra, num arquivo só (user://fagulha.json): os ajustes
## (qualidade, sensibilidade, eixo, vibração) e o progresso (lugares já visitados, hora do dia, peças e
## melhorias). Nos testes e nas fotos (`ativo` falso) nada é lido nem gravado, para o resultado não
## depender da última partida.
## O jogo se chamava "Faísca 2" até 2026-11-21. A pasta do save vem do nome do jogo, então o nome novo começa
## com a pasta vazia, num jogo novo; o save antigo (`faisca2.json`) ficou na pasta do nome antigo. Não é
## trazido: o usuário ia começar um jogo novo de qualquer forma.

const ARQUIVO := "user://fagulha.json"
const PADRAO := {
	"ajustes": {"qualidade": 1, "sensibilidade": 2, "inverter_y": false, "vibra": true},
	"progresso": {"lugares": [], "hora": 9.5, "pecas": [], "melhorias": [], "energia_base": 100.0, "escaneados": [], "arsenal": {}, "memorias": [], "lembrancas": [], "simulacao_vista": false, "dicas": [], "farol_aceso": false, "posicao": [], "robo_antigo": false, "robo_mergulhador": false, "robo_em_uso": 0, "acoes": {}, "achados": {}, "prologo_visto": false, "despertar_visto": false, "rotas": {}, "rastro": "", "acampamentos": [], "acampamentos_horas": {}, "procurados": [], "pedidos": {}, "radio": false, "horta": {}, "album": {}, "raposa": {}, "recordes": []},
}

static var ativo := true
static var dados := {}
static var gravacoes := 0
static var sem_progresso := false  # na simulação (o tutorial) só se grava que ela foi vista
static var apagado := false  # o progresso foi apagado nesta partida: nada mais dele é gravado até reabrir o jogo


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
	if apagado or (sem_progresso and nome != "simulacao_vista"):
		return
	(dados["progresso"] as Dictionary)[nome] = valor
	if gravar:
		salvar()


## Apaga o progresso (os ajustes ficam).
static func recomecar_progresso() -> void:
	if dados.is_empty():
		carregar()
	dados["progresso"] = (PADRAO["progresso"] as Dictionary).duplicate(true)
	# o que está na memória do jogo (peças, armas, lugares, memórias) seria regravado em seguida: a partir
	# daqui o progresso desta partida não vai mais para o arquivo
	apagado = true
	salvar()
