extends SceneTree

## Arte do atalho da Steam em docs/steam/: `godot --path . -s tools/arte_steam.gd`.
## As fotos de base saem de `-- --vale-captura --capa --hora 6.5` (docs/steam/fotos/).

const PASTA := "res://docs/steam/"
const LARANJA := Color(1.0, 0.62, 0.25)

var _texturas: Array[Texture2D] = []


class Tela extends Control:
	var desenho: Callable
	func _draw() -> void:
		desenho.call(self)


func _initialize() -> void:
	var pairando := Image.load_from_file(ProjectSettings.globalize_path(PASTA + "fotos/pairando.png"))
	var largo := Image.load_from_file(ProjectSettings.globalize_path(PASTA + "fotos/largo.png"))
	# capa em pé: o robô pairando de frente, com a serra atrás
	await _peca("capa", Vector2i(600, 900), false, func(t: Tela) -> void:
		_foto(t, pairando, Rect2(808, 0, 919, 1378))
		_sombra(t, 0.52, 1.0, 0.86)
		_titulo(t, Vector2(300, 760), 78, 19, true))
	# capa deitada: o robô à esquerda, o título à direita
	await _peca("larga", Vector2i(920, 430), false, func(t: Tela) -> void:
		_foto(t, largo, Rect2(0, 150, 2560, 1196))
		_sombra(t, 0.45, 1.0, 0.8)
		_titulo(t, Vector2(650, 345), 64, 15, true))
	# fundo da página do jogo: sem letras
	await _peca("fundo", Vector2i(1920, 620), false, func(t: Tela) -> void:
		_foto(t, largo, Rect2(0, 200, 2560, 827)))
	# ícone: só o robô
	await _peca("icone", Vector2i(256, 256), false, func(t: Tela) -> void:
		_foto(t, largo, Rect2(40, 270, 820, 820)))
	# o nome sozinho, com fundo transparente
	await _peca("logo", Vector2i(1280, 720), true, func(t: Tela) -> void:
		_titulo(t, Vector2(640, 380), 190, 44, true))
	quit()


func _peca(nome: String, tam: Vector2i, vazado: bool, desenho: Callable) -> void:
	var v := SubViewport.new()
	v.size = tam
	v.transparent_bg = vazado
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var t := Tela.new()
	t.desenho = desenho
	t.size = tam
	v.add_child(t)
	root.add_child(v)
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := v.get_texture().get_image()
	if not vazado:
		img.convert(Image.FORMAT_RGB8)
	img.save_png(PASTA + nome + ".png")
	v.queue_free()
	print("ARTE ", nome, " ", tam)


func _foto(t: Tela, img: Image, corte: Rect2) -> void:
	var parte := img.get_region(Rect2i(corte))
	parte.resize(int(t.size.x), int(t.size.y), Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(parte)
	_texturas.append(tex)  # o desenho só usa a textura no fim do quadro
	t.draw_texture(tex, Vector2.ZERO)


## Escurece de `de` a `ate` (frações da altura), para o título se ler em cima da mata.
func _sombra(t: Tela, de: float, ate: float, forca: float) -> void:
	var y0 := int(de * t.size.y)
	var y1 := int(ate * t.size.y)
	for y in range(y0, y1):  # uma linha por vez: faixas sobrepostas deixavam listras
		var k := float(y - y0) / float(y1 - y0 - 1)
		t.draw_rect(Rect2(0, y, t.size.x, 1), Color(0.03, 0.04, 0.09, forca * smoothstep(0.0, 1.0, k)))


## O nome centrado em `onde` (linha de base do nome grande).
func _titulo(t: Tela, onde: Vector2, grande: int, pequeno: int, traco: bool) -> void:
	var f := ThemeDB.fallback_font
	var nome := "FAÍSCA 2"
	var w := _largura(f, nome, grande, grande * 0.06)
	_espacado(t, f, Vector2(onde.x - w * 0.5, onde.y), nome, grande, grande * 0.06, Color(1, 1, 1, 0.97))
	var y := onde.y + grande * 0.22
	if traco:
		t.draw_rect(Rect2(onde.x - w * 0.5, y, w, maxf(2.0, grande * 0.035)), LARANJA)
	var sub := "EM BUSCA DO SOSSEGO"
	var esp := (w - _largura(f, sub, pequeno, 0.0)) / float(sub.length() - 1)
	_espacado(t, f, Vector2(onde.x - w * 0.5, y + grande * 0.12 + pequeno), sub, pequeno, esp, Color(1, 1, 1, 0.85))


func _largura(f: Font, texto: String, tam: int, esp: float) -> float:
	var w := 0.0
	for i in texto.length():
		w += f.get_string_size(texto[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	return w + esp * float(texto.length() - 1)


func _espacado(t: Tela, f: Font, onde: Vector2, texto: String, tam: int, esp: float, cor: Color) -> void:
	var x := onde.x
	for i in texto.length():
		t.draw_string(f, Vector2(x, onde.y), texto[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
		x += f.get_string_size(texto[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + esp
