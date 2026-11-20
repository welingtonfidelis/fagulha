class_name Melhorias
extends RefCounted
## As melhorias do robô (doc §64). Ele começa básico; cada peça achada na ilha e instalada no cilindro
## da base alarga uma coisa. Aqui ficam o que foi achado, o que está instalado e os números que mudam.
## Nenhuma melhoria mexe em arma.

const NOMES := ["antena", "radiador", "radiador2", "bocais", "asas", "barbatanas", "amortecedores", "farol", "celulas", "scanner"]
const CUSTO := 100.0  # energia da base que uma instalação gasta: a carga inteira
const RECARGA := 100.0 / 300.0  # energia por segundo: a base recarrega em 5 minutos de jogo
const TITULOS := {
	"antena": "Antena de busca", "radiador": "Radiador de aletas", "radiador2": "Radiador duplo", "bocais": "Bocais largos",
	"asas": "Asas de planar", "barbatanas": "Barbatanas", "amortecedores": "Molas",
	"farol": "Luz do peito", "celulas": "Células de reserva", "scanner": "Scanner", "mira": "Mira assistida",
}
const EFEITOS := {
	"antena": "a bússola mostra peças que estiverem por perto",
	"radiador": "voa mais tempo: uns 100 segundos",
	"radiador2": "voa três vezes mais tempo que o básico",
	"bocais": "arrancada mais rápida",
	"asas": "no voo, segure L3 ou X para trocar o jato pelo planador",
	"barbatanas": "nado rápido mais veloz",
	"amortecedores": "pula mais alto e pousa sem tranco",
	"farol": "luz para a noite (seta para cima / L)",
	"celulas": "esfria mais depressa no chão",
	"scanner": "identifica bichos e máquinas (seta para a direita / T)",
	"mira": "mirando, o tiro trava na máquina mais perto da mira",
}

static var tudo := false  # testes, fotos e modos antigos: tudo instalado
static var achadas: Array = []  # com o robô, ainda não instaladas
static var instaladas: Array = []
static var energia := 100.0  # da base, 0 a 100: cada instalação gasta CUSTO e ela recarrega com o tempo
static var escaneados: Array = []  # nomes do que o scanner já registrou
static var sinais: Array[Vector3] = []  # no mundo: as peças que a antena capta agora (só as de perto)
static var base := Vector3.INF  # no mundo: a base, que a bússola mostra sempre (a casinha)


static func tem(nome: String) -> bool:
	return tudo or instaladas.has(nome)


static func carregar() -> void:
	achadas = (Guardado.progresso("pecas") as Array).duplicate()
	instaladas = (Guardado.progresso("melhorias") as Array).duplicate()
	energia = float(Guardado.progresso("energia_base"))
	escaneados = (Guardado.progresso("escaneados") as Array).duplicate()


static func guardar() -> void:
	if Guardado.ativo:
		Guardado.por_progresso("pecas", achadas, false)
		Guardado.por_progresso("energia_base", energia, false)
		Guardado.por_progresso("escaneados", escaneados, false)
		Guardado.por_progresso("melhorias", instaladas)


static func achar(nome: String) -> void:
	if not achadas.has(nome) and not instaladas.has(nome):
		achadas.append(nome)
		guardar()


## Instala uma peça que o robô carrega. Devolve se instalou. (A energia da base, que fazia esperar entre
## uma instalação e outra, saiu a pedido do usuário: instala quando quiser.)
static func instalar(nome: String) -> bool:
	if not achadas.has(nome):
		return false
	achadas.erase(nome)
	if not instaladas.has(nome):
		instaladas.append(nome)
		CartaoPeca.avisar(nome)
	guardar()
	return true


## Segundos que faltam para a base ter energia para uma instalação.
static func espera() -> float:
	return maxf(0.0, (CUSTO - energia) / RECARGA)


## Instala tudo o que o robô carrega; devolve os nomes instalados.
static func instalar_achadas() -> Array:
	var novas := achadas.duplicate()
	for nome in novas:
		if not instaladas.has(nome):
			instaladas.append(nome)
			CartaoPeca.avisar(nome)
	achadas.clear()
	if not novas.is_empty():
		guardar()
	return novas


static func vestidas() -> Array:
	return NOMES.duplicate() if tudo else instaladas.duplicate()


# --- os números que as peças mudam (o básico vem primeiro) ---

## Calor por segundo no voo reto: básico enche em ~60 s; com o radiador, em ~3 min.
## São dois radiadores (decisão do usuário, 2026-11-18): o de aletas, achado no meio do caminho, leva a
## ~100 s; o duplo, num dos lugares mais distantes, aos 3 minutos. O duplo vale sozinho, sem o primeiro.
static func calor_voo() -> float:
	if tem("radiador2"):
		return Ajustes.CALOR_VOO
	return 1.0 if tem("radiador") else 1.65


static func calor_pairar() -> float:
	if tem("radiador2"):
		return Ajustes.CALOR_PAIRAR
	return 1.5 if tem("radiador") else 2.4


static func voo_alvo() -> float:
	return Ajustes.VOO_ALVO + (1.5 if tem("bocais") else 0.0)


static func arrancada_alvo() -> float:
	return Ajustes.ARRANCADA_ALVO if tem("bocais") else 22.0


## Planando com as asas: o ar freia menos, o nariz só cai mais devagar e a curva fecha mais.
static func arrasto_planar() -> float:
	return Ajustes.ARRASTO * (0.45 if tem("asas") else 1.0)


static func estol() -> float:
	return 8.0 if tem("asas") else Ajustes.ESTOL


static func giro_planar() -> float:
	return 1.35 if tem("asas") else 1.0


static func nado_rapido() -> bool:
	return tem("barbatanas")


## Multiplica a velocidade do pulo: 25% a mais de altura.
static func pulo() -> float:
	return 1.118 if tem("amortecedores") else 1.0


## Multiplica o tempo parado depois de um pouso forte ou leve.
static func tranco() -> float:
	return 0.5 if tem("amortecedores") else 1.0


static func esfria_chao() -> float:
	return 30.0 if tem("celulas") else 15.0
