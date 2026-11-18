class_name RodaArmas
extends CanvasLayer
## A roda de armas (doc §67): segurando L1 (ou R) o jogo fica em câmera lenta e abre uma roda com os modos
## de tiro; o analógico direito (ou o mouse) aponta um gomo, e soltando o botão a arma troca. As teclas de
## 1 a 6 trocam direto. Só os modos já fabricados podem ser escolhidos.

const LARANJA := Color(1.0, 0.62, 0.3)
const TINTA := Color(0.93, 0.94, 0.9)
const LENTO := 0.2
const SEGURAR := 0.22  # s segurando o L1 para abrir a roda (menos que isso é um toque)
const FUNDO := Color(0.04, 0.065, 0.07, 0.9)
const APAGADO := Color(0.3, 0.37, 0.36)

static var aberta := false

var armadura: Armadura
var hud: Hud
var escolha := ""
var trocas := 0  # testes
var _tela: Control
var _fonte: Font
var _mouse := Vector2.ZERO
var _antes := false
var _seg := -1.0
var _fita_t := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela = Control.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	_fonte = ThemeDB.fallback_font
	aberta = false


func _exit_tree() -> void:
	if aberta:
		_fechar(false)


func _abrir() -> void:
	aberta = true
	escolha = Arsenal.modo
	_mouse = Vector2.ZERO
	Engine.time_scale = LENTO
	CameraVoo.travada = true
	Som.toque3d(self, "roda_abre", armadura.global_position, -6.0)


func _fechar(aplica: bool) -> void:
	aberta = false
	Engine.time_scale = 1.0
	CameraVoo.travada = false
	if aplica:
		trocar(escolha)
	_tela.queue_redraw()


## Passa para a próxima arma fabricada, na ordem da roda, e mostra a faixa.
func proxima() -> void:
	var i := Arsenal.ORDEM.find(Arsenal.modo)
	for k in range(1, Arsenal.ORDEM.size() + 1):
		var nome: String = Arsenal.ORDEM[(i + k) % Arsenal.ORDEM.size()]
		if Arsenal.tem_arma(nome):
			if nome != Arsenal.modo:
				trocar(nome, false)
			break
	_fita_t = 2.0
	_tela.queue_redraw()


func trocar(nome: String, avisa := true) -> void:
	if not Arsenal.MODOS.has(nome) or not Arsenal.tem_arma(nome) or nome == Arsenal.modo:
		return
	Arsenal.modo = nome
	trocas += 1
	if armadura:
		Som.toque3d(self, "roda_troca", armadura.global_position, -5.0)
	if armadura and armadura.visual:
		armadura.visual.vestir_melhorias()
	Arsenal.guardar()
	if hud and avisa:
		hud.avisar(Arsenal.MODOS[nome]["titulo"], Arsenal.MODOS[nome]["resumo"])


func _unhandled_input(event: InputEvent) -> void:
	if aberta and event is InputEventMouseMotion:
		_mouse = (_mouse + (event as InputEventMouseMotion).relative).limit_length(140.0)
	if event is InputEventKey and event.pressed and not event.echo and not get_tree().paused:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_6:
			trocar(Arsenal.ORDEM[k - KEY_1])


func _process(_delta: float) -> void:
	if armadura == null:
		return
	var pode := not get_tree().paused and not armadura.em_pane and not armadura.travado and not armadura.escaneando
	# um toque no L1 passa para a próxima arma (uma faixa discreta mostra qual, por 2 s); segurando além
	# de SEGURAR, abre a roda. O toque não exige apontar nada: serve para os pequenos.
	var apertado := Input.is_action_pressed("roda")
	_fita_t = maxf(0.0, _fita_t - _delta / maxf(Engine.time_scale, 0.05))
	if aberta:
		if not pode or not apertado:
			_fechar(pode)
	elif pode and apertado:
		if not _antes:
			_seg = 0.0
		elif _seg >= 0.0:
			_seg += _delta / maxf(Engine.time_scale, 0.05)
			if _seg >= SEGURAR:
				_seg = -1.0
				_abrir()
	elif _antes and not apertado and _seg >= 0.0 and pode:
		_seg = -1.0
		proxima()
	_antes = apertado
	if _fita_t > 0.0 or aberta:
		_tela.queue_redraw()
	if not aberta:
		return
	var dir := Input.get_vector("olhar_esquerda", "olhar_direita", "olhar_cima", "olhar_baixo")
	if dir.length() < 0.35 and _mouse.length() > 40.0:
		dir = _mouse.normalized()
	if dir.length() >= 0.35:
		# o gomo de cima é o primeiro; seguem no sentido do relógio
		var ang := wrapf(atan2(dir.x, -dir.y), 0.0, TAU)
		var i := int(round(ang / (TAU / Arsenal.ORDEM.size()))) % Arsenal.ORDEM.size()
		if Arsenal.tem_arma(Arsenal.ORDEM[i]):
			escolha = Arsenal.ORDEM[i]
	_tela.queue_redraw()


func _desenhar() -> void:
	var tam := _tela.size
	if not aberta:
		_desenhar_fita(tam)
		return
	var c := tam * 0.5
	_tela.draw_rect(Rect2(Vector2.ZERO, tam), Color(0, 0, 0, 0.3))
	_tela.draw_circle(c, 252.0, FUNDO)
	var n := Arsenal.ORDEM.size()
	for i in n:
		var nome: String = Arsenal.ORDEM[i]
		var tem := Arsenal.tem_arma(nome)
		var meio := -PI * 0.5 + i * TAU / n
		var a0 := meio - PI / n + 0.025
		var a1 := meio + PI / n - 0.025
		var pts := PackedVector2Array()
		for k in 15:
			pts.append(c + Vector2.from_angle(lerpf(a0, a1, k / 14.0)) * 244.0)
		for k in 15:
			pts.append(c + Vector2.from_angle(lerpf(a1, a0, k / 14.0)) * 102.0)
		var sel := nome == escolha
		_tela.draw_colored_polygon(pts, Color(0.16, 0.13, 0.09) if sel else Color(0.1, 0.15, 0.16))
		if sel:
			pts.append(pts[0])
			_tela.draw_polyline(pts, LARANJA, 1.6, true)
		var p := c + Vector2.from_angle(meio) * 174.0
		var cor := LARANJA if sel else (TINTA if tem else APAGADO)
		Icones.desenhar(_tela, nome if tem else "cadeado", p + Vector2(0, -12.0), 1.7, cor, 1.7)
		var titulo: String = Arsenal.MODOS[nome]["titulo"]
		var w := _fonte.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_tela.draw_string(_fonte, p + Vector2(-w * 0.5, 34.0), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cor)
	_tela.draw_circle(c, 94.0, Color(0.055, 0.085, 0.09))
	_tela.draw_arc(c, 94.0, 0.0, TAU, 64, LARANJA, 1.5, true)
	var m: Dictionary = Arsenal.MODOS[escolha]
	var t1: String = m["titulo"]
	var wt := _fonte.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
	_tela.draw_string(_fonte, c + Vector2(-wt * 0.5, -4.0), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, LARANJA)
	_tela.draw_multiline_string(_fonte, c + Vector2(-76.0, 18.0), String(m["resumo"]), HORIZONTAL_ALIGNMENT_CENTER, 152.0, 13, 3, Color(0.56, 0.64, 0.62))


## A faixa do toque no L1: as armas fabricadas em linha, embaixo, com a atual em laranja. Some sozinha.
func _desenhar_fita(tam: Vector2) -> void:
	if _fita_t <= 0.0:
		return
	var alfa := clampf(_fita_t * 2.5, 0.0, 1.0)
	var nomes := []
	for nome: String in Arsenal.ORDEM:
		if Arsenal.tem_arma(nome):
			nomes.append(nome)
	var passo := 92.0
	var larg := nomes.size() * passo
	var x0 := tam.x * 0.5 - larg * 0.5
	var y := tam.y - 190.0
	_tela.draw_rect(Rect2(x0 - 10.0, y, larg + 20.0, 70.0), Color(FUNDO, 0.82 * alfa))
	for i in nomes.size():
		var nome: String = nomes[i]
		var sel := nome == Arsenal.modo
		var cx := x0 + (i + 0.5) * passo
		var cor := Color(LARANJA, alfa) if sel else Color(0.78, 0.81, 0.78, alfa)
		if sel:
			_tela.draw_rect(Rect2(cx - passo * 0.5 + 4.0, y + 4.0, passo - 8.0, 62.0), Color(LARANJA, alfa), false, 1.5)
		Icones.desenhar(_tela, nome, Vector2(cx, y + 26.0), 1.3, cor, 1.6)
		var titulo: String = Arsenal.MODOS[nome]["titulo"]
		var w := _fonte.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_tela.draw_string(_fonte, Vector2(cx - w * 0.5, y + 60.0), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cor)
