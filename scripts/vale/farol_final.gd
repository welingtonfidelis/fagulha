class_name FarolFinal
extends Node3D
## O fim do jogo: com as dez memórias lidas, o robô acende o Farol Apagado. Não há luta nem contagem: chegar
## ao balcão, um botão, uma última página e os créditos. Daí em diante o farol gira (forte à noite, fraco de
## dia) e o jogo continua. O estado vai para o save ("farol_aceso").
## Quem cria passa `armadura`, `hud`, `memorias` e `dicas` (pode ser null).

const PERTO := 16.0  # metros da lente em que o convite aparece
const TITULO := "O Farol"
const TEXTO := "Foi a última luz que eles apagaram. Não por tristeza: era para a ilha dormir.\n\nVocê andou por tudo o que deixaram, ouviu o que guardaram e não quebrou nada.\n\nPode acender. A ilha já tem quem cuide dela."
const CREDITOS := "Faísca 2 · Em Busca do Sossego\n\nObrigado por passear."

var armadura: Armadura
var hud: Hud
var memorias: Memorias
var dicas: Dicas
var aceso := false
var acendimentos := 0  # testes

var _lente := Vector3.INF
var _gira: Node3D
var _luz: SpotLight3D
var _cones: Array[MeshInstance3D] = []
var _mat_miolo: StandardMaterial3D
var _mat_feixe: StandardMaterial3D
var _globo: OmniLight3D
var _camada: CanvasLayer
var _rotulo: Label
var _pagina := 0  # 0 fechada, 1 o texto, 2 os créditos
var _fecha_em := 0.0
var _avisou := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sem_pausa")
	if MarcosLeste.farol_topo.is_finite():
		_lente = MarcosLeste.farol_topo + Vector3(0, 3.0, 0)
	_montar_luz()
	_montar_tela()
	if Guardado.ativo and bool(Guardado.progresso("farol_aceso")):
		_ligar()


## A pausa não abre por cima da última página.
func ocupada() -> bool:
	return _pagina > 0


func pronto() -> bool:
	return memorias != null and memorias.lidas.size() >= Memorias.ORDEM.size()


func _montar_luz() -> void:
	if not _lente.is_finite():
		return
	_gira = Node3D.new()
	_gira.position = _lente
	_gira.visible = false
	add_child(_gira)
	_globo = OmniLight3D.new()
	_globo.light_color = Color(1.0, 0.86, 0.55)
	_globo.omni_range = 26.0
	_gira.add_child(_globo)
	_luz = SpotLight3D.new()
	_luz.light_color = Color(1.0, 0.9, 0.62)
	_luz.spot_range = 420.0
	_luz.spot_angle = 9.0
	_luz.rotation.x = deg_to_rad(-4.0)
	_gira.add_child(_luz)
	# o feixe que se vê de longe: um cone comprido de luz, dos dois lados
	_mat_feixe = StandardMaterial3D.new()
	_mat_feixe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_feixe.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_feixe.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_feixe.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_feixe.albedo_color = Color(1.0, 0.88, 0.55, 0.12)
	for lado: float in [1.0, -1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.6
		cone.bottom_radius = 13.0
		cone.height = 380.0
		cone.radial_segments = 14
		cone.cap_top = false
		cone.cap_bottom = false
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = _mat_feixe
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.x = PI * 0.5 * lado
		mi.position.z = -190.0 * lado
		_gira.add_child(mi)
		_cones.append(mi)
	var miolo := MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = 1.5
	bola.height = 3.0
	miolo.mesh = bola
	_mat_miolo = StandardMaterial3D.new()
	_mat_miolo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_miolo.albedo_color = Color(1.0, 0.92, 0.7)
	miolo.material_override = _mat_miolo
	_gira.add_child(miolo)


func _montar_tela() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 12
	_camada.visible = false
	add_child(_camada)
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.05, 0.06, 0.86)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_camada.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	_rotulo = Label.new()
	_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo.custom_minimum_size = Vector2(760, 0)
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.add_theme_font_size_override("font_size", 24)
	_rotulo.add_theme_color_override("font_color", Color(0.93, 0.96, 0.95))
	_rotulo.add_theme_constant_override("line_spacing", 10)
	centro.add_child(_rotulo)


func _ligar() -> void:
	aceso = true
	if _gira:
		_gira.visible = true


## Acende o farol e mostra a última página.
func acender() -> void:
	if aceso:
		return
	acendimentos += 1
	_ligar()
	if Guardado.ativo:
		Guardado.por_progresso("farol_aceso", true)
	if hud:
		hud.dica = ""
		hud.destino_final = Vector3.INF
	Som.toque3d(self, "religar", _lente, 0.0, 30.0, 400.0)
	_pagina = 1
	_rotulo.text = TITULO.to_upper() + "\n\n" + TEXTO
	_camada.visible = true
	_fecha_em = 1.2
	get_tree().paused = true


func _process(delta: float) -> void:
	if _pagina > 0:
		_fecha_em -= delta
		if _fecha_em <= 0.0 and (Input.is_action_just_pressed("pular") or Input.is_action_just_pressed("soltar") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_accept")):
			if _pagina == 1:
				_pagina = 2
				_rotulo.text = CREDITOS
				_fecha_em = 1.0
			else:
				_pagina = 0
				_camada.visible = false
				get_tree().paused = false
		return
	if get_tree().paused:
		return
	if aceso and _gira:
		_gira.rotation.y += delta * 0.55
		# De dia não há feixe nenhum: o cone é uma malha colorida, não luz de verdade, e ao sol ficava forte
		# demais para um dia real (aviso do usuário, pelo farol da Ilha Cafuné). De dia a lente só brilha de
		# leve; o feixe nasce no fim da tarde e some no amanhecer.
		var hora := CicloDia.atual.hora if CicloDia.atual else 12.0
		var noite := clampf(1.0 - smoothstep(5.0, 6.2, hora) + smoothstep(18.3, 19.6, hora), 0.0, 1.0)
		_mat_feixe.albedo_color.a = 0.085 * noite
		for cone in _cones:
			cone.visible = noite > 0.01
		_mat_miolo.albedo_color = Color(0.62, 0.6, 0.52).lerp(Color(1.0, 0.92, 0.7), noite)
		_luz.light_energy = 9.0 * noite
		_globo.light_energy = lerpf(0.3, 5.0, noite)
		return
	if armadura == null or not _lente.is_finite() or not pronto():
		return
	# com as dez memórias: a bússola aponta o farol e o drone avisa
	if hud:
		hud.destino_final = _lente
	if not _avisou:
		_avisou = true
		if dicas:
			dicas.pedir("farol")
	var perto := armadura.global_position.distance_to(_lente) < PERTO and not armadura.em_pane and not armadura.travado
	if hud:
		if perto:
			hud.dica = "{agir}  acender o Farol"
		elif hud.dica.begins_with("{agir}  acender"):
			hud.dica = ""
	if perto and Input.is_action_just_pressed("agir"):
		acender()
