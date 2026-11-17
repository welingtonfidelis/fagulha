class_name Oficina
extends Node3D
## A oficina da base (doc §65): o cilindro onde as peças são instaladas. Perto da boca aparece o convite
## (quadrado / E); o robô entra andando, os braços da máquina descem sobre ele e abre a tela: o robô de um
## lado, a lista das peças do outro, com a prévia da peça escolhida no corpo. Cada instalação gasta energia
## da base, que recarrega com o tempo de jogo; quando volta a dar para instalar, um aviso chama o jogador.

signal instalou(nome: String)

enum Fase { FORA, ENTRANDO, ABERTA, INSTALANDO, SAINDO }
const PERTO := 2.7  # m da boca para o convite aparecer
const FUNDO := 2.3  # m para dentro da boca onde o robô para
const T_ENTRAR := 1.5
const T_INSTALAR := 1.9
const T_SAIR := 1.3
const TINTA := Color(0.93, 0.94, 0.9)
const APAGADO := Color(0.62, 0.68, 0.66)
const LARANJA := Color(1.0, 0.62, 0.3)
const AGUA := Color(0.35, 0.95, 0.85)
# de que lado cada peça aparece melhor: de costas ou de frente
const DE_COSTAS := ["radiador", "asas", "amortecedores", "celulas", "bocais"]

var armadura: Armadura
var camera: CameraVoo
var hud: Hud
var sons: Sons
var drone: DroneColega
var fase := Fase.FORA
var perto := false
var entradas := 0  # testes
var recargas := 0
var _t := 0.0
var _de := Vector3.ZERO
var _para := Vector3.ZERO
var _cam: Camera3D
var _luz: OmniLight3D
var _bracos: Array[Dictionary] = []
var _desce := 0.0  # 0 braços recolhidos no teto, 1 em volta do robô
var _instalando := ""
var _escolhida := ""
var _tinha_energia := true
var _guardar_t := 0.0
var _tela: CanvasLayer
var _lista: VBoxContainer
var _barra: ProgressBar
var _energia_txt: Label
var _titulo: Label
var _efeito: Label
var _estado: Label
var _botoes := {}


func _ready() -> void:
	var t := BaseVale.cilindro_t
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.1
	add_child(_cam)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.86, 0.66)
	_luz.light_energy = 0.0
	_luz.omni_range = 7.0
	_luz.position = t * Vector3(BaseVale.MEIO_CIL - FUNDO + 0.9, 0.9, 0.0)
	add_child(_luz)
	_montar_bracos()
	_montar_tela()
	_tinha_energia = Melhorias.energia >= Melhorias.CUSTO


## Onde o robô fica dentro do cilindro (no mundo): em cima do estrado.
func _parada() -> Vector3:
	return BaseVale.cilindro_t * Vector3(BaseVale.MEIO_CIL - FUNDO, -(BaseVale.R_CIL - 0.2) + 0.51, 0.0)


func _eixo() -> Vector3:
	return BaseVale.cilindro_t.basis.x.normalized()


# ------------------------------------------------------------------ braços da máquina

## Três braços de dois segmentos presos no teto do tubo. Cada quadro, a ponta vai do ponto recolhido ao
## ponto de trabalho e o cotovelo sai da conta dos dois comprimentos.
func _montar_bracos() -> void:
	var escuro := _mat(Color(0.2, 0.23, 0.26))
	var x0 := BaseVale.MEIO_CIL - FUNDO
	var teto := BaseVale.R_CIL - 0.3
	for dados in [[Vector3(x0 + 0.1, teto, 0.95), Vector3(x0, -0.8, 0.5)], [Vector3(x0 + 0.1, teto, -0.95), Vector3(x0, -0.8, -0.5)],
			[Vector3(x0 - 1.0, teto, 0.0), Vector3(x0 - 0.42, -0.7, 0.0)]]:
		var b := {"base": dados[0], "alvo": dados[1], "nos": []}
		b["dobra"] = (Vector3(dados[0].x, 0, dados[0].z) - Vector3(x0, 0, 0)).normalized()
		b["recolhido"] = dados[0] + Vector3(-0.7, -0.22, 0.0)
		for i in 2:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.11 - i * 0.035, 1.0, 0.11 - i * 0.035)
			mi.mesh = bm
			mi.material_override = escuro
			add_child(mi)
			(b["nos"] as Array).append(mi)
		for i in 3:
			var junta := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.1 - i * 0.015
			sm.height = sm.radius * 2.0
			junta.mesh = sm
			junta.material_override = _mat(LARANJA) if i < 2 else _mat_luz(AGUA, 0.0)
			add_child(junta)
			(b["nos"] as Array).append(junta)
		var faisca := OmniLight3D.new()
		faisca.light_color = AGUA
		faisca.light_energy = 0.0
		faisca.omni_range = 2.2
		add_child(faisca)
		(b["nos"] as Array).append(faisca)
		_bracos.append(b)
	_por_bracos(0.0, 0.0)


func _mat(cor: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/shaders/vale_solido.gdshader")
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("brilho_borda", 0.18)
	return m


func _mat_luz(cor: Color, forca: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = forca
	return m


func _segmento(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var comp := maxf(d.length(), 0.01)
	var y := d / comp
	var x := y.cross(Vector3(0.31, 0.2, 0.93)).normalized()
	mi.global_transform = Transform3D(Basis(x, y * comp, x.cross(y)), (a + b) * 0.5)


func _por_bracos(f: float, trabalho: float) -> void:
	var t := BaseVale.cilindro_t
	var l1 := 1.75
	var l2 := 1.75
	for i in _bracos.size():
		var b := _bracos[i]
		var base: Vector3 = b["base"]
		var ponta: Vector3 = (b["recolhido"] as Vector3).lerp(b["alvo"], smoothstep(0.0, 1.0, f))
		if trabalho > 0.0:
			var fase_b := _t * 9.0 + i * 2.1
			ponta += Vector3(sin(fase_b) * 0.09, sin(fase_b * 1.7) * 0.16, cos(fase_b * 1.3) * 0.09) * trabalho
		# cotovelo: no plano que tem a base, a ponta e o lado de dobrar
		var d := ponta - base
		var dist := clampf(d.length(), 0.05, l1 + l2 - 0.02)
		var ao_longo := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
		var alto := sqrt(maxf(0.0, l1 * l1 - ao_longo * ao_longo))
		var dn := d.normalized()
		var lado: Vector3 = (b["dobra"] as Vector3 + Vector3(0, 0.6, 0))
		lado = (lado - dn * lado.dot(dn)).normalized()
		var cotovelo := base + dn * ao_longo + lado * alto
		var nos: Array = b["nos"]
		_segmento(nos[0], t * base, t * cotovelo)
		_segmento(nos[1], t * cotovelo, t * ponta)
		(nos[2] as Node3D).global_position = t * base
		(nos[3] as Node3D).global_position = t * cotovelo
		(nos[4] as Node3D).global_position = t * ponta
		var brilho := trabalho * (0.5 + 0.5 * sin(_t * 31.0 + i * 1.9))
		((nos[4] as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = 0.6 * f + 6.0 * brilho
		(nos[5] as OmniLight3D).global_position = t * ponta
		(nos[5] as OmniLight3D).light_energy = 2.4 * brilho


# ------------------------------------------------------------------ a tela

func _caixa(cor: Color, raio: int, margem: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	sb.set_content_margin_all(margem)
	return sb


func _texto(t: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


func _montar_tela() -> void:
	_tela = CanvasLayer.new()
	_tela.layer = 6
	_tela.visible = false
	add_child(_tela)
	var cartao := PanelContainer.new()
	cartao.add_theme_stylebox_override("panel", _caixa(Color(0.05, 0.09, 0.1, 0.9), 18, 22))
	cartao.anchor_left = 1.0
	cartao.anchor_right = 1.0
	cartao.anchor_top = 0.0
	cartao.anchor_bottom = 1.0
	cartao.offset_left = -560.0
	cartao.offset_right = -28.0
	cartao.offset_top = 28.0
	cartao.offset_bottom = -28.0
	_tela.add_child(cartao)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	cartao.add_child(col)
	col.add_child(_texto("Oficina", 26, TINTA))
	_energia_txt = _texto("Instale as peças que achar pela ilha e fabrique com o que a Fundição dá.", 14, APAGADO)
	_energia_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_energia_txt)
	_barra = ProgressBar.new()
	_barra.max_value = 100.0
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(0, 14)
	_barra.add_theme_stylebox_override("background", _caixa(Color(0.12, 0.18, 0.19), 7, 0))
	_barra.add_theme_stylebox_override("fill", _caixa(AGUA, 7, 0))
	_barra.visible = false  # a energia da base saiu: instala quando quiser
	col.add_child(_barra)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 4)
	col.add_child(_lista)
	var vao := Control.new()
	vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(vao)
	_titulo = _texto("", 24, LARANJA)
	col.add_child(_titulo)
	_efeito = _texto("", 18, TINTA)
	_efeito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_efeito)
	_estado = _texto("", 17, AGUA)
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_estado)
	col.add_child(_texto("X / Enter: instalar ou fabricar   ·   O / Esc: sair", 15, APAGADO))


func _botao_lista(nome: String, texto: String, cor: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 35)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 17)
	b.text = texto
	b.add_theme_color_override("font_color", cor)
	b.add_theme_color_override("font_hover_color", cor)
	b.add_theme_color_override("font_focus_color", Color(0.05, 0.09, 0.09))
	b.add_theme_stylebox_override("normal", _caixa(Color(0.12, 0.18, 0.19), 10, 10))
	b.add_theme_stylebox_override("hover", _caixa(Color(0.17, 0.26, 0.27), 10, 10))
	b.add_theme_stylebox_override("pressed", _caixa(LARANJA.darkened(0.2), 10, 10))
	b.add_theme_stylebox_override("focus", _caixa(LARANJA, 10, 10))
	b.pressed.connect(func() -> void: instalar(nome))
	b.focus_entered.connect(func() -> void: _escolher(nome))
	b.mouse_entered.connect(b.grab_focus)
	b.set_meta("nome", nome)
	_lista.add_child(b)
	_botoes[nome] = b
	return b


## A lista: primeiro as peças achadas na ilha (instaladas com a energia da base), depois o que se fabrica
## com os materiais da Fundição (o Arsenal).
func _refazer_lista() -> void:
	for f in _lista.get_children():
		f.queue_free()
	_botoes.clear()
	var primeiro: Button = null
	for nome: String in Melhorias.NOMES:
		var b: Button
		if Melhorias.instaladas.has(nome):
			b = _botao_lista(nome, "✓  " + Melhorias.TITULOS[nome], AGUA)
		elif Melhorias.achadas.has(nome):
			b = _botao_lista(nome, "●  " + Melhorias.TITULOS[nome] + "   —   pronta para instalar", LARANJA)
			if primeiro == null or not Melhorias.achadas.has(String(primeiro.get_meta("nome"))):
				primeiro = b
		else:
			b = _botao_lista(nome, "?  peça ainda não encontrada", APAGADO)
		if primeiro == null:
			primeiro = b
	var bx := Arsenal.barra()
	var titulo := _texto("Fabricar   ·   nível %d (%d de %d)   ·   sucata %d   ·   núcleos %d   ·   chips %d" % [Arsenal.nivel(), bx.x, bx.y, Arsenal.sucata, Arsenal.nucleos, Arsenal.chips], 14, AGUA)
	_lista.add_child(titulo)
	for nome: String in Arsenal.RECEITAS:
		var r: Dictionary = Arsenal.RECEITAS[nome]
		if Arsenal.fabricados.has(nome):
			_botao_lista(nome, "✓  " + String(r["titulo"]), AGUA)
		elif Arsenal.falta(nome) == "":
			_botao_lista(nome, "●  " + String(r["titulo"]) + "   —   fabricar", LARANJA)
		else:
			_botao_lista(nome, "○  " + String(r["titulo"]) + "   —   " + Arsenal.custo(nome), APAGADO)
	if _escolhida != "" and _botoes.has(_escolhida):
		primeiro = _botoes[_escolhida]
	if primeiro:
		primeiro.grab_focus.call_deferred()


## A peça em foco aparece no corpo do robô (se ele já achou ou já tem), virado para o lado em que ela se vê.
func _escolher(nome: String) -> void:
	_escolhida = nome
	if Arsenal.RECEITAS.has(nome):
		var rc: Dictionary = Arsenal.RECEITAS[nome]
		_titulo.text = rc["titulo"]
		_efeito.text = rc["efeito"]
		if Arsenal.fabricados.has(nome):
			_estado.text = "Já fabricado."
		elif Arsenal.falta(nome) == "":
			_estado.text = "Fabricar gasta " + Arsenal.custo(nome).replace("nível %d · " % int(rc["nivel"]), "") + "."
		else:
			_estado.text = "Custa " + Arsenal.custo(nome) + " (" + Arsenal.falta(nome) + "). Os materiais vêm da Fundição."
		var previa_de := {"mira": "mira", "vida": "vida", "escudo": "escudo", "misseis": "lanca_misseis", "granadas": "lanca_granadas", "rajada": "arma_rajada", "canhao": "arma_canhao", "precisao": "arma_precisao", "duplo": "arma_duplo"}
		armadura.visual.vestir_melhorias([previa_de[nome]] if previa_de.has(nome) else [])
		armadura.visual.previa = true
		_virar("antena")
		return
	var conhece := Melhorias.achadas.has(nome) or Melhorias.instaladas.has(nome)
	if conhece:
		_titulo.text = Melhorias.TITULOS[nome]
		_efeito.text = String(Melhorias.EFEITOS[nome]).capitalize().left(1) + String(Melhorias.EFEITOS[nome]).substr(1)
	else:
		_titulo.text = "Peça não encontrada"
		_efeito.text = "Está em algum lugar da ilha."
	if Melhorias.instaladas.has(nome):
		_estado.text = "Já instalada."
	elif Melhorias.achadas.has(nome):
		_estado.text = "Pronta para instalar."
	else:
		_estado.text = ""
	armadura.visual.vestir_melhorias([nome] if Melhorias.achadas.has(nome) else [])
	armadura.visual.previa = true
	_virar(nome)


func _virar(nome: String) -> void:
	var e := _eixo()
	var frente := atan2(-e.x, -e.z)  # de frente para a boca
	armadura.visual.yaw_forcado = frente + (PI * 0.82 if nome in DE_COSTAS else -0.35)


func _relogio(seg: float) -> String:
	var s := int(ceil(seg))
	return "%d:%02d" % [s / 60, s % 60]


# ------------------------------------------------------------------ o passo a passo

func entrar() -> void:
	if fase != Fase.FORA or armadura.em_pane:
		return
	fase = Fase.ENTRANDO
	entradas += 1
	Arsenal.repor_granadas()
	_t = 0.0
	_de = armadura.global_position
	_para = _parada()
	armadura.travado = true
	armadura.velocity = Vector3.ZERO
	armadura.postura = 0
	if hud:
		hud.dica = ""
		hud.visible = false
	var t := BaseVale.cilindro_t
	_cam.global_position = t * Vector3(BaseVale.MEIO_CIL + 0.7, -0.75, 0.75)
	_cam.look_at(_para + Vector3(0, 0.66, 0) - t.basis.z.normalized() * 0.85)
	_cam.make_current()
	if sons:
		sons._toque("religar", -8.0)


func instalar(nome: String) -> void:
	if fase != Fase.ABERTA:
		return
	if Arsenal.RECEITAS.has(nome):
		if Arsenal.fabricados.has(nome):
			return
		if Arsenal.falta(nome) != "":
			_estado.text = "Ainda não dá: " + Arsenal.falta(nome) + " (" + Arsenal.custo(nome) + ")."
			return
		fase = Fase.INSTALANDO
		_instalando = nome
		_t = 0.0
		_estado.text = "Fabricando…"
		if sons:
			sons._toque("religar", -6.0)
		return
	if not Melhorias.achadas.has(nome):
		return
	fase = Fase.INSTALANDO
	_instalando = nome
	_t = 0.0
	_estado.text = "Instalando…"
	if sons:
		sons._toque("religar", -6.0)


func sair() -> void:
	if fase != Fase.ABERTA:
		return
	fase = Fase.SAINDO
	_t = 0.0
	_tela.visible = false
	armadura.visual.previa = false
	armadura.visual.vestir_melhorias()
	_de = armadura.global_position
	# sai pela rampa até o chão, 2,5 m à frente da boca
	_para = BaseVale.cilindro_t * Vector3(BaseVale.MEIO_CIL + 2.5, -(BaseVale.R_CIL + 0.18) + 0.05, 0.0)
	var e := _eixo()
	armadura.visual.yaw_forcado = atan2(-e.x, -e.z)


func _input(event: InputEvent) -> void:
	if fase == Fase.ABERTA and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sair()


func _physics_process(delta: float) -> void:
	_t += delta
	_recarregar(delta)
	if armadura == null:
		return
	match fase:
		Fase.FORA:
			var b := BaseVale.boca_cilindro
			var p := armadura.global_position
			# chegando à base, no chão: munição e vida de volta
			var na_base := Vector2(p.x - b.x, p.z - b.z).length() < 16.0 and armadura.estado == Armadura.Estado.CHAO and not armadura.em_pane
			if na_base and (Arsenal.granadas < Arsenal.granadas_max() or Arsenal.misseis < Arsenal.misseis_max() or armadura.avaria > 0 or float(armadura.get("_dano_frac")) > 0.01):
				Arsenal.repor_granadas()
				armadura.avaria = 0
				armadura.set("_dano_frac", 0.0)
				armadura.escudo_t = 0.0
				recargas += 1
				if hud:
					hud.avisar("Base", "munição e vida recarregadas")
				if sons:
					sons._toque("marcar", -6.0, 0.0)
			perto = Vector2(p.x - b.x, p.z - b.z).length() < PERTO and p.y < b.y and p.y > b.y - 4.0 \
				and armadura.estado == Armadura.Estado.CHAO and not armadura.em_pane and not armadura.escaneando
			if hud:
				var novo := "Quadrado / E:  entrar na oficina" if perto else ""
				if hud.dica != novo and (perto or hud.dica.begins_with("Quadrado / E:  entrar")):
					hud.dica = novo
			if perto and Input.is_action_just_pressed("agir"):
				entrar()
		Fase.ENTRANDO:
			var f := clampf(_t / T_ENTRAR, 0.0, 1.0)
			var e := _eixo()
			armadura.global_position = _de.lerp(_para, smoothstep(0.0, 1.0, f))
			armadura.velocity = -e * (2.6 if f < 0.9 else 0.0)
			armadura.visual.yaw_forcado = atan2(e.x, e.z)
			_luz.light_energy = 1.3 * f
			_desce = clampf((_t - T_ENTRAR * 0.6) / 0.9, 0.0, 1.0)
			_por_bracos(_desce, 0.0)
			if _t >= T_ENTRAR + 0.6:
				_abrir()
		Fase.ABERTA:
			armadura.velocity = Vector3.ZERO
			_desce = minf(1.0, _desce + delta * 2.0)
			_por_bracos(_desce, 0.0)
			pass
		Fase.INSTALANDO:
			_por_bracos(1.0, sin(clampf(_t / T_INSTALAR, 0.0, 1.0) * PI))
			if _t >= T_INSTALAR:
				var nome := _instalando
				_instalando = ""
				fase = Fase.ABERTA
				if Arsenal.RECEITAS.has(nome):
					if Arsenal.fabricar(nome):
						armadura.visual.escudos_vistos = armadura.escudos_gastos
						if sons:
							sons._toque("fabricou", -3.0, 0.0)
						instalou.emit(nome)
					_refazer_lista()
					_escolher(nome)
					_estado.text = "Fabricado!"
					return
				if Melhorias.instalar(nome):
					_tinha_energia = Melhorias.energia >= Melhorias.CUSTO
					if sons:
						sons._toque("marcar", -4.0, 0.0)
					if drone:
						drone.falar()
					instalou.emit(nome)
				_refazer_lista()
				_escolher(nome)
				_estado.text = "Instalado!"
		Fase.SAINDO:
			var f := clampf(_t / T_SAIR, 0.0, 1.0)
			_desce = maxf(0.0, _desce - delta * 2.4)
			_por_bracos(_desce, 0.0)
			armadura.global_position = _de.lerp(_para, smoothstep(0.0, 1.0, f))
			armadura.velocity = _eixo() * (2.6 if f < 0.9 else 0.0)
			_luz.light_energy = 1.3 * (1.0 - f)
			if f >= 1.0:
				_fechar()


func _abrir() -> void:
	fase = Fase.ABERTA
	_escolhida = ""
	_tela.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refazer_lista()


func _fechar() -> void:
	fase = Fase.FORA
	armadura.velocity = Vector3.ZERO
	armadura.visual.yaw_forcado = NAN
	armadura.travado = false
	armadura.teleportar(armadura.global_position, Armadura.Estado.CHAO)
	if camera:
		var e := _eixo()
		camera.yaw = atan2(-e.x, -e.z)
		camera.pitch = -0.1
		camera.cam.make_current()
	if hud:
		hud.visible = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A energia da base saiu (pedido do usuário): não há mais espera entre instalações.
func _recarregar(_delta: float) -> void:
	pass
