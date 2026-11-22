class_name Botoes
extends RefCounted
## As imagens dos botões (Input Prompts do Kenney, CC0, em assets/ui/botoes/) e o texto que as mistura com
## palavras. Num texto, `{acao}` vira a imagem do botão daquela ação no aparelho que o jogador está usando
## (controle ou teclado e mouse), e `{@nome}` vira uma imagem certa, pelo nome do arquivo (`{@l3}`, `{@k_w}`).
## Quem desenha chama `desenhar` de dentro do `_draw`; para pôr numa tela de nós, há o `TextoBotoes`.

const PASTA := "res://assets/ui/botoes/"
# ação -> [imagens no controle, imagens no teclado e mouse]
const ACOES := {
	"mover": [["al"], ["k_w", "k_a", "k_s", "k_d"]],
	"olhar": [["ar"], ["m"]],
	"pular": [["x"], ["k_espaco"]],
	"correr": [["al"], ["k_shift"]],  # no controle, o analógico até o fim (o L3 ficou sem ação)
	"voar": [["x"], ["k_shift"]],
	"pairar": [["l2"], ["k_f"]],
	"golpe": [["tri"], ["k_v"]],
	"sentar": [["esq"], ["k_ctrl"]],
	"espada": [["quad"], ["k_x"]],
	"soltar": [["o"], ["k_c"]],
	"mirar": [["l2"], ["m_dir"]],
	"atirar": [["r2"], ["m_esq"]],
	"marcar": [["baixo"], ["k_q"]],
	"roda": [["l1"], ["k_r"]],
	"granada": [["r1"], ["k_g"]],
	"luz": [["cima"], ["k_l"]],
	"agir": [["tri"], ["k_e"]],
	"scanner": [["dir"], ["k_t"]],
	"menu": [["options"], ["k_esc"]],
	"caderno": [["create"], ["k_m"]],
	"medidor": [["l1", "r1"], ["k_f3"]],
}

static var controle := false  # o último aparelho usado foi o controle
static var trocas := 0  # quantas vezes o aparelho mudou (quem desenha confere para redesenhar)
static var _tex := {}
static var _olhou := false


## Chamado com cada evento de entrada: guarda qual aparelho o jogador está usando.
static func observar(ev: InputEvent) -> void:
	var novo := controle
	if ev is InputEventJoypadButton:
		novo = true
	elif ev is InputEventJoypadMotion:
		if absf((ev as InputEventJoypadMotion).axis_value) < 0.5:
			return
		novo = true
	elif ev is InputEventKey or ev is InputEventMouseButton:
		novo = false
	elif ev is InputEventMouseMotion:
		if (ev as InputEventMouseMotion).relative.length() < 6.0:
			return
		novo = false
	else:
		return
	if novo != controle or not _olhou:
		_olhou = true
		controle = novo
		trocas += 1


## Antes do primeiro toque: havendo controle ligado, as imagens são as dele.
static func comecar() -> void:
	if not _olhou:
		controle = not Input.get_connected_joypads().is_empty()


static func textura(nome: String) -> Texture2D:
	if not _tex.has(nome):
		var caminho := PASTA + nome + ".png"
		_tex[nome] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _tex[nome]


## Quebra o texto em pedaços: String para as palavras, Texture2D para as imagens.
static func pedacos(texto: String, forcar := -1) -> Array:
	var no_controle := controle if forcar < 0 else forcar == 1
	var saida: Array = []
	var resto := texto
	while true:
		var a := resto.find("{")
		var b := resto.find("}", a)
		if a < 0 or b < 0:
			break
		if a > 0:
			saida.append(resto.substr(0, a))
		var chave := resto.substr(a + 1, b - a - 1)
		var nomes: Array = []
		if chave.begins_with("@"):
			nomes = [chave.substr(1)]
		elif ACOES.has(chave):
			nomes = ACOES[chave][0 if no_controle else 1]
		for n: String in nomes:
			var t := textura(n)
			if t:
				saida.append(t)
			else:
				saida.append(n)
		resto = resto.substr(b + 1)
	if resto != "":
		saida.append(resto)
	return saida


static func _lado(tamanho: int) -> float:
	return tamanho * 1.7


static func largura(texto: String, fonte: Font, tamanho: int, forcar := -1) -> float:
	var w := 0.0
	for p in pedacos(texto, forcar):
		if p is Texture2D:
			w += _lado(tamanho) + 2.0
		else:
			w += fonte.get_string_size(String(p), HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	return w


## Desenha o texto com as imagens a partir de `pos` (a linha de base do texto, como no `draw_string`).
static func desenhar(tela: CanvasItem, fonte: Font, pos: Vector2, texto: String, tamanho: int, cor: Color, forcar := -1) -> void:
	var x := pos.x
	var lado := _lado(tamanho)
	for p in pedacos(texto, forcar):
		if p is Texture2D:
			tela.draw_texture_rect(p, Rect2(x, pos.y - tamanho * 0.36 - lado * 0.5, lado, lado), false, Color(1, 1, 1, cor.a))
			x += lado + 2.0
		else:
			tela.draw_string(fonte, Vector2(x, pos.y), String(p), HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
			x += fonte.get_string_size(String(p), HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
