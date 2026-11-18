class_name Icones
extends RefCounted
## Ícones de traço fino das telas (roda de armas, oficina, HUD): cada um é um conjunto de linhas numa caixa
## de -16 a 16, desenhadas com `draw_polyline` na cor pedida. Sem figuras cheias nem cores próprias.

const TRACOS := {
	"pistola": [[-14, -4, 12, -4, 12, 3, -6, 3, -9, 11, -14, 11, -14, -4]],
	"rajada": [[-14, -7, 14, -7], [-14, 0, 14, 0], [-14, 7, 14, 7], [-14, -9, -14, 9]],
	"canhao": [[-14, -6, 6, -6, 6, 6, -14, 6, -14, -6], [6, -9, 14, -9, 14, 9, 6, 9]],
	"precisao": [[9.0, 0.0, 7.8, 4.5, 4.5, 7.8, 0.0, 9.0, -4.5, 7.8, -7.8, 4.5, -9.0, 0.0, -7.8, -4.5, -4.5, -7.8, -0.0, -9.0, 4.5, -7.8, 7.8, -4.5, 9.0, -0.0], [-15, 0, -4, 0], [4, 0, 15, 0], [0, -15, 0, -4], [0, 4, 0, 15]],
	"duplo": [[-15, -11, 1, -11, 1, -6, -9, -6, -11, -1, -15, -1, -15, -11], [-1, 1, 15, 1, 15, 6, 5, 6, 3, 11, -1, 11, -1, 1]],
	"misseis": [[-10, 10, -10, 4, 6, -12, 12, -12, 12, -6, -4, 10, -10, 10], [-10, 10, -14, 14], [-4, 10, -4, 14], [-10, 4, -14, 4]],
	"granadas": [[-8, 4, -6, -3, 0, -6, 6, -3, 8, 4, 5, 10, -5, 10, -8, 4], [-3, -6, -3, -11, 4, -11, 4, -6]],
	"cadeado": [[-8, -1, 8, -1, 8, 11, -8, 11, -8, -1], [-5, -1, -5, -7, -2, -11, 2, -11, 5, -7, 5, -1]],
	"mira": [[-10, 0, -3, 0], [3, 0, 10, 0], [0, -10, 0, -3], [0, 3, 0, 10], [-12, -6, -12, -12, -6, -12], [12, 6, 12, 12, 6, 12]],
	"escudo": [[0, -12, 10, -8, 10, 1, 6, 8, 0, 12, -6, 8, -10, 1, -10, -8, 0, -12]],
	"vida": [[-11, -3, -4, -3, -4, -10, 4, -10, 4, -3, 11, -3, 11, 4, 4, 4, 4, 11, -4, 11, -4, 4, -11, 4, -11, -3]],
	"peca": [[-10, -10, 10, -10, 10, 10, -10, 10, -10, -10], [-10, -2, 10, -2]],
	"antena": [[0, 12, 0, -6], [-7, -6, 0, -12, 7, -6], [-6, 12, 6, 12]],
	"radiador": [[-9, -10, -9, 10], [-3, -10, -3, 10], [3, -10, 3, 10], [9, -10, 9, 10]],
	"radiador2": [[-12, -10, -12, 10], [-7, -10, -7, 10], [-2, -10, -2, 10], [2, -10, 2, 10], [7, -10, 7, 10], [12, -10, 12, 10]],
	"bocais": [[-8, -10, 8, -10, 12, 2, -12, 2, -8, -10], [-5, 6, 0, 13, 5, 6]],
	"asas": [[0, -4, -14, -9, -14, 3, 0, 6, 14, 3, 14, -9, 0, -4]],
	"barbatanas": [[-8, 10, -8, -8, 4, 0, 8, 10, -8, 10]],
	"amortecedores": [[0, -12, 0, -8, -6, -5, 6, -1, -6, 3, 6, 7, 0, 10, 0, 13]],
	"farol": [[-8, -8, 8, -8, 8, 8, -8, 8, -8, -8], [12, -8, 16, -10], [12, 0, 17, 0], [12, 8, 16, 10]],
	"celulas": [[-11, -8, -5, -8, -5, 8, -11, 8, -11, -8], [-3, -8, 3, -8, 3, 8, -3, 8, -3, -8], [5, -8, 11, -8, 11, 8, 5, 8, 5, -8]],
	"scanner": [[-12, -6, 12, -6, 12, 8, -12, 8, -12, -6], [-4, 1, 0, -3, 4, 1, 0, 5, -4, 1], [-8, -6, -5, -10, 5, -10, 8, -6]],
}


static func desenhar(c: CanvasItem, nome: String, centro: Vector2, escala := 1.0, cor := Color.WHITE, traco := 1.6) -> void:
	for linha: Array in TRACOS.get(nome, TRACOS["peca"]):
		var pts := PackedVector2Array()
		for i in range(0, linha.size(), 2):
			pts.append(centro + Vector2(float(linha[i]), float(linha[i + 1])) * escala)
		c.draw_polyline(pts, cor, traco, true)


## Um controle que só desenha um ícone (para pôr dentro de botões e listas).
static func no(nome: String, tamanho := 40.0, cor := Color.WHITE) -> Control:
	var ctl := Control.new()
	ctl.custom_minimum_size = Vector2(tamanho, tamanho)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.set_meta("icone", nome)
	ctl.set_meta("cor", cor)
	ctl.draw.connect(func() -> void:
		desenhar(ctl, String(ctl.get_meta("icone")), ctl.size * 0.5, ctl.size.y / 40.0, ctl.get_meta("cor")))
	return ctl
