class_name RodaArmas
extends CanvasLayer
## A roda de armas (doc §67): segurando L1 (ou R) o jogo fica em câmera lenta e abre uma roda com os modos
## de tiro; o analógico direito (ou o mouse) aponta um gomo, e soltando o botão a arma troca. As teclas de
## 1 a 6 trocam direto. Só os modos já fabricados podem ser escolhidos.

const LARANJA := Color(1.0, 0.62, 0.3)
const TINTA := Color(0.93, 0.94, 0.9)
const LENTO := 0.2

static var aberta := false

var armadura: Armadura
var hud: Hud
var escolha := ""
var trocas := 0  # testes
var _tela: Control
var _fonte: Font
var _mouse := Vector2.ZERO
var _antes := false


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


func trocar(nome: String) -> void:
	if not Arsenal.MODOS.has(nome) or not Arsenal.tem_arma(nome) or nome == Arsenal.modo:
		return
	Arsenal.modo = nome
	trocas += 1
	if armadura:
		Som.toque3d(self, "roda_troca", armadura.global_position, -5.0)
	if armadura and armadura.visual:
		armadura.visual.vestir_melhorias()
	Arsenal.guardar()
	if hud:
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
	# abre na passagem de solto para apertado (comparando com o quadro anterior: o "acabou de apertar" do
	# motor pode cair num quadro em que este nó não olha)
	var apertado := Input.is_action_pressed("roda")
	if aberta and (not pode or not apertado):
		_fechar(pode)
	elif not aberta and pode and apertado and not _antes:
		_abrir()
	_antes = apertado
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
	if not aberta:
		return
	var tam := _tela.size
	var c := tam * 0.5
	_tela.draw_rect(Rect2(Vector2.ZERO, tam), Color(0, 0, 0, 0.28))
	_tela.draw_circle(c, 232.0, Color(0.03, 0.06, 0.07, 0.8))
	var n := Arsenal.ORDEM.size()
	for i in n:
		var nome: String = Arsenal.ORDEM[i]
		var tem := Arsenal.tem_arma(nome)
		var meio := -PI * 0.5 + i * TAU / n
		var a0 := meio - PI / n + 0.03
		var a1 := meio + PI / n - 0.03
		var pts := PackedVector2Array()
		for k in 13:
			pts.append(c + Vector2.from_angle(lerpf(a0, a1, k / 12.0)) * 222.0)
		for k in 13:
			pts.append(c + Vector2.from_angle(lerpf(a1, a0, k / 12.0)) * 96.0)
		var sel := nome == escolha
		_tela.draw_colored_polygon(pts, LARANJA if sel else (Color(0.12, 0.19, 0.2) if tem else Color(0.08, 0.12, 0.13)))
		var p := c + Vector2.from_angle(meio) * 160.0
		var titulo: String = Arsenal.MODOS[nome]["titulo"]
		var cor := Color(0.05, 0.08, 0.08) if sel else (TINTA if tem else Color(0.4, 0.46, 0.46))
		var w := _fonte.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		_tela.draw_string(_fonte, p + Vector2(-w * 0.5, 2.0), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, cor)
		var sub := "%d" % (i + 1) if tem else "não fabricado"
		var w2 := _fonte.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_tela.draw_string(_fonte, p + Vector2(-w2 * 0.5, 22.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, cor * Color(1, 1, 1, 0.75))
	_tela.draw_circle(c, 88.0, Color(0.05, 0.09, 0.1))
	_tela.draw_arc(c, 88.0, 0.0, TAU, 48, LARANJA, 3.0, true)
	var m: Dictionary = Arsenal.MODOS[escolha]
	var t1: String = m["titulo"]
	var wt := _fonte.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	_tela.draw_string(_fonte, c + Vector2(-wt * 0.5, -6.0), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, LARANJA)
	_tela.draw_multiline_string(_fonte, c + Vector2(-74.0, 16.0), String(m["resumo"]), HORIZONTAL_ALIGNMENT_CENTER, 148.0, 13, 3, TINTA)
