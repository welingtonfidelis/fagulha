class_name Hud
extends Control
## Mira com a barra de calor em arco, velocidade e altura no canto, aviso de superaquecimento e
## o medidor de desempenho (F3 ou Create/Share).

const TEMPO_ENTRAR := 0.4  # alfa do nome lugar sobe em 0,4 s
const TEMPO_FICAR := 2.5
const TEMPO_SAIR := 0.8

var alvo: Armadura
var locais: Locais  # null no modo de teste: o HUD funciona sem ele
var tiro: Tiro  # para desenhar o colchete na máquina travada
var medidor := false
var _rotulo_medidor: Label
var _fonte: Font
var _nome_lugar := ""
var _sub_lugar := ""  # "lugar descoberto · N de M" na primeira visita
var _tempo_lugar := -1.0  # segundos desde a chegada; -1 quando não há aviso


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = ThemeDB.fallback_font
	_rotulo_medidor = Label.new()
	_rotulo_medidor.position = Vector2(16, 12)
	_rotulo_medidor.add_theme_font_size_override("font_size", 15)
	_rotulo_medidor.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	_rotulo_medidor.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_rotulo_medidor.add_theme_constant_override("outline_size", 4)
	_rotulo_medidor.visible = false
	add_child(_rotulo_medidor)


## Liga o HUD aos lugares com nome: mostra o aviso quando a armadura chega a um deles.
func ligar_locais(l: Locais) -> void:
	locais = l
	l.chegou.connect(_ao_chegar)


## Aviso curto no mesmo lugar do nome dos lugares (ex.: sinal fraco no mar).
func avisar(titulo: String, sub := "") -> void:
	_nome_lugar = titulo
	_sub_lugar = sub
	_tempo_lugar = 0.0


func _ao_chegar(nome: String, primeira_vez: bool) -> void:
	_nome_lugar = nome
	_sub_lugar = ""
	if primeira_vez and locais:
		_sub_lugar = "lugar descoberto · %d de %d" % [locais.descobertos(), locais.total()]
	_tempo_lugar = 0.0


func _process(delta: float) -> void:
	if _tempo_lugar >= 0.0:
		_tempo_lugar += delta
		if _tempo_lugar >= TEMPO_ENTRAR + TEMPO_FICAR + TEMPO_SAIR:
			_tempo_lugar = -1.0
	if Input.is_action_just_pressed("medidor"):
		medidor = not medidor
	_rotulo_medidor.visible = medidor
	if medidor and alvo:
		var fps := Performance.get_monitor(Performance.TIME_FPS)
		var ms := 1000.0 / maxf(1.0, fps)
		var cpu := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var fis := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var tri := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var p := alvo.global_position
		_rotulo_medidor.text = "%d fps · %.1f ms por quadro · processo %.1f ms · física %.1f ms\nchamadas de desenho %d · triângulos %.2f M\nestado: %s · calor %d%% · %.1f m/s\nposição %d, %d, %d · %d m acima do chão" % [
			fps, ms, cpu, fis, dc, tri / 1.0e6, alvo.nome_estado(), alvo.calor, alvo.velocity.length(),
			p.x, p.y, p.z, alvo.altura_do_chao()]
		if CicloDia.atual:
			_rotulo_medidor.text += "\n%s · %02d:%02d · chuva %d%%" % [CicloDia.atual.nome_momento(), int(CicloDia.atual.hora), int(fmod(CicloDia.atual.hora, 1.0) * 60.0), CicloDia.atual.chuva * 100.0]
	queue_redraw()


## Bússola no topo: 120° de horizonte em volta da câmera (norte = -Z, leste = +X).
func _desenhar_bussola() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var frente := -cam.global_basis.z
	frente.y = 0.0
	if frente.length() < 0.001:
		return
	# rumo da câmera em radianos: norte = 0, leste = +90°
	var rumo := atan2(frente.x, -frente.z)
	var cx := size.x * 0.5
	var y0 := 34.0
	var meia := deg_to_rad(60.0)
	var escala := 260.0 / meia  # pixels por radiano (faixa de 520 px)
	# faixa escura atrás da bússola, para ler em céu claro
	draw_rect(Rect2(cx - 260.0, y0 - 20.0, 520.0, 48.0), Color(0, 0, 0, 0.28))
	var letras := ["N", "L", "S", "O"]
	for k in range(24):
		var graus := k * 15
		var off := wrapf(deg_to_rad(float(graus)) - rumo, -PI, PI)
		if absf(off) > meia:
			continue
		# some suavemente nas pontas (últimos 15°)
		var f := smoothstep(0.0, 1.0, clampf((meia - absf(off)) / deg_to_rad(15.0), 0.0, 1.0))
		var x := cx + off * escala
		var comp := 10.0 if graus % 45 == 0 else 5.0
		draw_line(Vector2(x, y0 + 4.0), Vector2(x, y0 + 4.0 + comp), Color(1, 1, 1, 0.8 * f), 1.5, true)
		if graus % 90 == 0:
			var letra: String = letras[int(float(graus) / 90.0)]
			var cor := Color(1, 1, 1, (1.0 if letra == "N" else 0.8) * f)
			var w := _fonte.get_string_size(letra, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(_fonte, Vector2(x - w * 0.5, y0 - 4.0), letra, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cor)
	# marca fixa: para onde a câmera olha (embaixo da faixa, apontando para cima)
	var tri := PackedVector2Array([Vector2(cx, y0 + 16.0), Vector2(cx - 6.0, y0 + 25.0), Vector2(cx + 6.0, y0 + 25.0)])
	draw_colored_polygon(tri, Color(1, 1, 1, 0.9))
	# marcador do mundo na faixa, preso nas pontas quando está fora dos 120°
	if alvo and alvo.tem_marcador:
		var d := alvo.marcador - alvo.global_position
		d.y = 0.0
		if d.length() > 0.01:
			var rumo_m := atan2(d.x, -d.z)
			var off_m := clampf(wrapf(rumo_m - rumo, -PI, PI), -meia, meia)
			var xm := cx + off_m * escala
			# 12 px abaixo da linha das letras, para não cobrir N, L, S, O
			var yl := y0 + 12.0
			var losango := PackedVector2Array([Vector2(xm, yl - 8.0), Vector2(xm + 6.0, yl), Vector2(xm, yl + 8.0), Vector2(xm - 6.0, yl)])
			draw_colored_polygon(losango, Color(0.55, 0.95, 1.0))


## Nome do lugar no terço de cima: entra, fica e sai (alfa), com sombra leve para ler em céu claro.
func _desenhar_lugar() -> void:
	if _tempo_lugar < 0.0:
		return
	var t := _tempo_lugar
	var fim_fica := TEMPO_ENTRAR + TEMPO_FICAR
	var a := 1.0
	if t < TEMPO_ENTRAR:
		a = t / TEMPO_ENTRAR
	elif t > fim_fica:
		a = clampf(1.0 - (t - fim_fica) / TEMPO_SAIR, 0.0, 1.0)
	var cx := size.x * 0.5
	var y := size.y * 0.22
	var w := _fonte.get_string_size(_nome_lugar, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(_fonte, Vector2(cx - w * 0.5 + 1.0, y + 1.0), _nome_lugar, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.5 * a))
	draw_string(_fonte, Vector2(cx - w * 0.5, y), _nome_lugar, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, a))
	draw_line(Vector2(cx - w * 0.5, y + 10.0), Vector2(cx + w * 0.5, y + 10.0), Color(1, 1, 1, 0.8 * a), 1.0, true)
	if _sub_lugar != "":
		var ws := _fonte.get_string_size(_sub_lugar, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(_fonte, Vector2(cx - ws * 0.5 + 1.0, y + 31.0), _sub_lugar, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.5 * a))
		draw_string(_fonte, Vector2(cx - ws * 0.5, y + 30.0), _sub_lugar, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85 * a))


var _dano_visto := 0.0


func _draw() -> void:
	_desenhar_bussola()
	_desenhar_lugar()
	if alvo == null:
		return
	var c := size * 0.5
	# marcador no mundo (losango com a distância)
	var cam := get_viewport().get_camera_3d()
	if alvo.tem_marcador and cam:
		var pm := alvo.marcador + Vector3(0, 2.0, 0)
		var dist_m := alvo.global_position.distance_to(alvo.marcador)
		var tela := cam.unproject_position(pm)
		if cam.is_position_behind(pm):
			tela = Vector2(clampf(size.x - tela.x, 20.0, size.x - 20.0), size.y - 40.0)
		tela = tela.clamp(Vector2(20, 20), size - Vector2(20, 20))
		var cor_m := Color(0.55, 0.95, 1.0, 0.95)
		var pts := PackedVector2Array([tela + Vector2(0, -9), tela + Vector2(7, 0), tela + Vector2(0, 9), tela + Vector2(-7, 0), tela + Vector2(0, -9)])
		draw_polyline(pts, cor_m, 2.0, true)
		var txt_m := "%d m" % roundi(dist_m)
		var wm := _fonte.get_string_size(txt_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(_fonte, tela + Vector2(-wm * 0.5, 26), txt_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cor_m)
	# mira
	if alvo.mirando_agora():
		var cm := Color(1, 1, 1, 0.9)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * 7.0, c + d * 16.0, cm, 2.0, true)
		# máquina travada: quatro cantos em volta dela
		if tiro and tiro.travado and is_instance_valid(tiro.travado) and cam:
			var pt: Vector3 = tiro.travado.call("ponto_de_trava")
			if pt.is_finite() and not cam.is_position_behind(pt):
				var t2 := cam.unproject_position(pt)
				var lado := clampf(900.0 / maxf(4.0, cam.global_position.distance_to(pt)), 16.0, 60.0)
				var cor_t := Color(1.0, 0.62, 0.2, 0.95)
				for sx: float in [-1.0, 1.0]:
					for sy: float in [-1.0, 1.0]:
						var canto := t2 + Vector2(sx, sy) * lado
						draw_line(canto, canto - Vector2(sx * lado * 0.45, 0), cor_t, 2.5, true)
						draw_line(canto, canto - Vector2(0, sy * lado * 0.45), cor_t, 2.5, true)
		var txt_d := "%d m" % roundi(alvo.global_position.distance_to(alvo.alvo_mira)) if alvo.alvo_mira_ok else "—"
		draw_string(_fonte, c + Vector2(14, 30), txt_d, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.75))
		if alvo.estado == Armadura.Estado.PAIRAR:
			draw_string(_fonte, c + Vector2(-26, 52), "pairando", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55))
	else:
		draw_circle(c, 2.5, Color(1, 1, 1, 0.85))
		draw_arc(c, 9.0, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 1.5, true)
	# marcas de dano: três traços à esquerda da mira. Cada acerto de máquina apaga um (vira laranja); o
	# terceiro desliga o robô. Só aparecem quando há dano, e somem um instante depois de ele sarar.
	var dano := float(alvo.avaria) + float(alvo.get("_dano_frac"))
	_dano_visto = move_toward(_dano_visto, 1.0 if dano > 0.01 else 0.0, get_process_delta_time() * (4.0 if dano > 0.01 else 0.7))
	if _dano_visto > 0.01:
		var pisca_d := fmod(Time.get_ticks_msec() * 0.001, 0.5) < 0.25
		for k in Ajustes.PANE_GOLPES:
			var ang := deg_to_rad(180.0 + (k - (Ajustes.PANE_GOLPES - 1) * 0.5) * 30.0)
			var perdido := clampf(dano - k, 0.0, 1.0)  # este traço: 0 inteiro, 1 perdido
			var cor_d := Color(0.45, 0.95, 0.85).lerp(Color(1.0, 0.45, 0.15), perdido)
			if perdido >= 1.0:
				cor_d = Color(1.0, 0.2, 0.12, 0.9) if (pisca_d or dano < Ajustes.PANE_GOLPES - 1) else Color(0.5, 0.1, 0.06, 0.9)
			var de_p := c + Vector2(cos(ang), -sin(ang)) * 40.0
			var ate_p := c + Vector2(cos(ang), -sin(ang)) * 52.0
			draw_line(de_p, ate_p, Color(0, 0, 0, 0.4 * _dano_visto), 8.0, true)
			draw_line(de_p, ate_p, Color(cor_d, cor_d.a * _dano_visto), 5.0, true)
	# barra de calor: arco à direita da mira, enche de baixo para cima
	var raio := 46.0
	var a0 := deg_to_rad(62.0)
	var a1 := deg_to_rad(-62.0)
	draw_arc(c, raio, a0, a1, 40, Color(0, 0, 0, 0.35), 7.0, true)
	var q := alvo.calor / 100.0
	var cor := Color(0.45, 0.85, 0.45).lerp(Color(1.0, 0.62, 0.15), smoothstep(0.35, 0.7, q))
	cor = cor.lerp(Color(1.0, 0.18, 0.12), smoothstep(0.8, 0.98, q))
	var pisca := fmod(Time.get_ticks_msec() * 0.001, 0.4) < 0.2
	if alvo.superaquecido:
		cor = Color(1.0, 0.15, 0.1) if pisca else Color(0.5, 0.08, 0.05)
	if q > 0.005:
		draw_arc(c, raio, a0, lerpf(a0, a1, q), 40, cor, 5.0, true)
	draw_string(_fonte, c + Vector2(raio + 10.0, 5.0), "%d%%" % roundi(alvo.calor), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(cor, 0.9))
	if alvo.superaquecido:
		var txt := "MOTOR SUPERAQUECIDO"
		var w := _fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(_fonte, c + Vector2(-w * 0.5, -70.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.25, 0.15, 1.0 if pisca else 0.6))
	elif alvo.na_agua and alvo.calor > 1.0:
		var txt2 := "esfriando na água"
		var w2 := _fonte.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(_fonte, c + Vector2(-w2 * 0.5, -66.0), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.9, 1.0, 0.9))
	# velocidade e altura
	var v := alvo.velocity.length() * 3.6
	var base := Vector2(28.0, size.y - 34.0)
	draw_string(_fonte, base, "%d km/h" % roundi(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.9))
	draw_string(_fonte, base + Vector2(0, 22), "%d m de altitude · %d m do chão" % [roundi(alvo.global_position.y), roundi(maxf(0.0, alvo.altura_do_chao()))], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.65))
