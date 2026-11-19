class_name TextoBotoes
extends Control
## Uma linha de texto com imagens de botão no meio (ver `Botoes`), para pôr em telas feitas de nós.
## `forcar`: -1 segue o aparelho em uso; 0 mostra sempre o teclado; 1 mostra sempre o controle.

var texto := "":
	set(v):
		texto = v
		_medir()
var tamanho := 16:
	set(v):
		tamanho = v
		_medir()
var cor := Color(1, 1, 1)
var forcar := -1
var _trocas := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medir()


func _medir() -> void:
	var fonte := ThemeDB.fallback_font
	custom_minimum_size = Vector2(Botoes.largura(texto, fonte, tamanho, forcar), tamanho * 1.9)
	queue_redraw()


func _process(_delta: float) -> void:
	if forcar < 0 and _trocas != Botoes.trocas:
		_trocas = Botoes.trocas
		_medir()


func _draw() -> void:
	Botoes.desenhar(self, ThemeDB.fallback_font, Vector2(0, size.y * 0.5 + tamanho * 0.36), texto, tamanho, cor, forcar)
