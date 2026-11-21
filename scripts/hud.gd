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
## Uma frase do drone colega, com imagens de botão (`{acao}`), por `dura` segundos.
func aconselhar(texto: String, dura := 10.0) -> void:
	conselho = texto
	_conselho_t = dura


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


static var marcas := 0  # quantos marcadores a bússola mostra agora (memórias perto, peças da antena, o marcador do jogador); a vibração avisa quando surge um
static var limpa := false  # apreciando a vista (a câmera avisa): a tela some


func _process(delta: float) -> void:
	# apreciando a vista, a tela fica limpa
	modulate.a = move_toward(modulate.a, 0.0 if limpa else 1.0, delta * 2.5)
	if _conselho_t > 0.0:
		_conselho_t -= delta
		if _conselho_t <= 0.0:
			conselho = ""
	resumo_t = maxf(0.0, resumo_t - delta)
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
	if cam == null or simples:
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
	draw_rect(Rect2(cx - 260.0, y0 - 20.0, 520.0, 48.0), Color(0, 0.03, 0.05, 0.46))
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
	# a base: uma casinha, sempre (some quando o robô já está nela)
	if alvo and Melhorias.base.is_finite():
		var db := Melhorias.base - alvo.global_position
		db.y = 0.0
		var off_b := wrapf(atan2(db.x, -db.z) - rumo, -PI, PI)
		if db.length() > 14.0 and absf(off_b) > meia:
			_seta_da_ponta(cx, y0, signf(off_b), Color(1.0, 0.82, 0.5))
		elif db.length() > 14.0:
			var xb := cx + off_b * escala
			var yb := y0 + 13.0
			var cor_b := Color(1.0, 0.82, 0.5)
			draw_colored_polygon(PackedVector2Array([Vector2(xb, yb - 9.0), Vector2(xb + 8.5, yb - 1.0), Vector2(xb - 8.5, yb - 1.0)]), cor_b)
			draw_rect(Rect2(xb - 5.5, yb - 1.0, 11.0, 8.0), cor_b)
			draw_rect(Rect2(xb - 1.5, yb + 2.0, 3.0, 5.0), Color(0, 0, 0, 0.55))
	# a Fundição: uma engrenagem, só depois da primeira visita (antes era uma caveira sempre à vista, que
	# puxava o jogador novo para a luta); some quando o robô já está nela
	if alvo and Fundicao.montada and _fundicao_vista():
		var df := Vector3(Fundicao.CENTRO.x, 0, Fundicao.CENTRO.y) - alvo.global_position
		df.y = 0.0
		var off_f := wrapf(atan2(df.x, -df.z) - rumo, -PI, PI)
		var cor_f := Color(0.84, 0.86, 0.9)
		if df.length() > Fundicao.RAIO and absf(off_f) > meia:
			_seta_da_ponta(cx, y0 + 12.0, signf(off_f), cor_f)
		elif df.length() > Fundicao.RAIO:
			var cf := Vector2(cx + off_f * escala, y0 + 12.0)
			for k in 8:
				var ang := k * TAU / 8.0
				draw_line(cf + Vector2(cos(ang), sin(ang)) * 5.0, cf + Vector2(cos(ang), sin(ang)) * 9.5, cor_f, 3.4)
			draw_circle(cf, 6.6, cor_f)
			draw_circle(cf, 2.6, Color(0.08, 0.1, 0.12))
	if alvo and destino_final.is_finite():
		var dd := destino_final - alvo.global_position
		dd.y = 0.0
		var off_d := wrapf(atan2(dd.x, -dd.z) - rumo, -PI, PI)
		var sol_c := Color(1.0, 0.8, 0.35)
		if absf(off_d) > meia:
			_seta_da_ponta(cx, y0 + 12.0, signf(off_d), sol_c)
		else:
			var ps := Vector2(cx + off_d * escala, y0 + 12.0)
			for k in 8:
				var ang := k * TAU / 8.0
				draw_line(ps + Vector2(cos(ang), sin(ang)) * 7.0, ps + Vector2(cos(ang), sin(ang)) * 11.0, sol_c, 2.0)
			draw_circle(ps, 5.0, sol_c)
	# as memórias ainda não lidas a menos de 300 m: um losango âmbar (como a antena faz com as peças)
	var conta_marcas := 0
	if alvo and memorias:
		for chave: String in memorias.onde:
			if memorias.lidas.has(chave):
				continue
			var dm: Vector3 = memorias.onde[chave] - alvo.global_position
			dm.y = 0.0
			if dm.length() > 300.0 or dm.length() < 6.0:
				continue
			conta_marcas += 1
			var off_m2 := wrapf(atan2(dm.x, -dm.z) - rumo, -PI, PI)
			var ambar := Color(1.0, 0.72, 0.25)
			if absf(off_m2) > meia:
				_seta_da_ponta(cx, y0 + 12.0, signf(off_m2), ambar)
			else:
				var pm := Vector2(cx + off_m2 * escala, y0 + 12.0)
				draw_colored_polygon(PackedVector2Array([pm + Vector2(0, -8), pm + Vector2(5.5, 0), pm + Vector2(0, 8), pm + Vector2(-5.5, 0)]), ambar)
				draw_colored_polygon(PackedVector2Array([pm + Vector2(0, -3.5), pm + Vector2(2.4, 0), pm + Vector2(0, 3.5), pm + Vector2(-2.4, 0)]), Color(1, 0.95, 0.8))
	# a antena de busca: um triângulo verde para cada peça que estiver por perto
	if alvo:
		conta_marcas += Melhorias.sinais.size() + (1 if alvo.tem_marcador else 0)
		marcas = conta_marcas
		for sinal in Melhorias.sinais:
			var da := sinal - alvo.global_position
			da.y = 0.0
			if da.length() > 4.0:
				var xa := cx + clampf(wrapf(atan2(da.x, -da.z) - rumo, -PI, PI), -meia, meia) * escala
				var ya := y0 + 12.0
				var pulso := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
				draw_colored_polygon(PackedVector2Array([Vector2(xa, ya + 8.0), Vector2(xa - 7.0, ya - 6.0), Vector2(xa + 7.0, ya - 6.0)]), Color(0.3, 1.0, 0.8, pulso))


## Nome do lugar no terço de cima: entra, fica e sai (alfa), com sombra leve para ler em céu claro.
## O jogador já esteve na Fundição? (o lugar "A Fundição" consta como visitado)
func _fundicao_vista() -> bool:
	if locais == null:
		return false
	for it in locais.lista:
		if it["nome"] == "A Fundição":
			return bool(it.get("visto", false))
	return false


## Fora dos 120° da faixa, o lugar vira uma setinha na ponta do lado em que está (antes o ícone inteiro ficava
## preso na ponta e parecia que o lugar estava sempre ali).
func _seta_da_ponta(cx: float, y: float, lado: float, cor: Color) -> void:
	var x := cx + lado * 252.0
	draw_colored_polygon(PackedVector2Array([Vector2(x + lado * 6.0, y + 4.0), Vector2(x - lado * 3.0, y - 2.0), Vector2(x - lado * 3.0, y + 10.0)]), Color(cor, 0.9))


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
var _mira_vista := 0.0
var _calor_visto := 0.0
var _frio_visto := 0.0
var _missil_visto := 0.0
var _rajada_vista := 0.0
var _missil_fica := 0.0  # segundos que o contador de mísseis ainda fica depois de um disparo
var _misseis_antes := -1
var _granada_vista := 0.0
var _voo_visto := 0.0
var _arma_vista := 0.0
var _arma_antes := ""


var destino_final := Vector3.INF  # o Farol, quando as dez memórias foram lidas (FarolFinal): um sol âmbar na bússola
var memorias: Memorias  # para a bússola mostrar as memórias não lidas por perto
var conselho := ""  # a dica do drone colega (Dicas), acima do convite de botão
var _conselho_t := 0.0
var simples := false  # na simulação: sem bússola nem nome de lugar
var dica := ""  # convite de botão embaixo, no meio (ex.: entrar na oficina)
var placar := ""  # a Fundição: a onda e quantos robôs faltam (canto de baixo, à esquerda)
var placar2 := ""  # nível e materiais


func _desenhar_placar() -> void:
	if placar == "":
		return
	# sem caixa: no alto à esquerda, o número da onda em letras espaçadas e um tracinho por robô que falta
	var p := Vector2(34.0, 52.0)
	draw_string(_fonte, p, placar.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.92))
	draw_rect(Rect2(p.x, p.y + 8.0, 34.0, 2.0), Color(1.0, 0.62, 0.3, 0.9))
	for i in placar_total:
		var x := p.x + i * 9.0
		draw_rect(Rect2(x, p.y + 20.0, 5.0, 12.0), Color(1, 1, 1, 0.9 if i < placar_restam else 0.2))
	if placar2 != "":
		draw_string(_fonte, p + Vector2(0, 34.0 if placar_total == 0 else 54.0), placar2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.35, 0.95, 0.85, 0.9))


var placar_restam := 0
var placar_total := 0


var tiro_no: Node  # o Tiro (para a carga do canhão)
var resumo_t := 0.0  # tempo que o cartão de fim de rodada ainda fica na tela
var _resumo_titulo := ""
var _resumo_linhas: Array = []
var _resumo_recorde := false
const RESUMO_DURA := 9.0


## O cartão de fim de rodada da Fundição: fica uns segundos no meio da tela, sem parar o jogo.
func mostrar_resumo(titulo: String, linhas: Array, recorde: bool) -> void:
	_resumo_titulo = titulo
	_resumo_linhas = linhas
	_resumo_recorde = recorde
	resumo_t = RESUMO_DURA


func _desenhar_resumo() -> void:
	if resumo_t <= 0.0:
		return
	# no estilo dos menus: painel escuro de canto reto, título, um fio, e linhas de rótulo e valor
	var alfa := clampf(minf(resumo_t, RESUMO_DURA - resumo_t) * 3.0, 0.0, 1.0)
	# letras maiores desde 2026-11-20 (revisão dos menus): título 27, linhas 20
	var larg := 640.0
	var alt := 100.0 + _resumo_linhas.size() * 36.0
	var p := Vector2(size.x * 0.5 - larg * 0.5, size.y * 0.5 - alt * 0.5 - 70.0)
	draw_rect(Rect2(p, Vector2(larg, alt)), Color(0.045, 0.075, 0.08, 0.93 * alfa))
	draw_rect(Rect2(p, Vector2(larg, alt)), Color(0.2, 0.3, 0.31, alfa), false, 1.0)
	draw_string(_fonte, p + Vector2(30.0, 48.0), _resumo_titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(0.93, 0.94, 0.9, alfa))
	draw_rect(Rect2(p.x + 30.0, p.y + 64.0, larg - 60.0, 1.0), Color(0.2, 0.3, 0.31, alfa))
	for i in _resumo_linhas.size():
		var par: Array = _resumo_linhas[i]
		var y := p.y + 100.0 + i * 36.0
		draw_string(_fonte, Vector2(p.x + 30.0, y), String(par[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.62, 0.68, 0.66, alfa))
		var valor := String(par[1])
		var cor := Color(0.93, 0.94, 0.9, alfa)
		if i == 1 and _resumo_recorde:
			cor = Color(1.0, 0.62, 0.3, alfa)
		var w := _fonte.get_string_size(valor, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(_fonte, Vector2(p.x + larg - 30.0 - w, y), valor, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, cor)


var chefe_nome := ""  # o minichefe da Fundição em campo
var chefe_vida := -1.0  # 0 a 1; negativo: sem barra


## A barra do minichefe, no alto, debaixo da bússola: o nome e quanto falta para ele desligar.
func _desenhar_chefe() -> void:
	if chefe_vida < 0.0:
		return
	var larg := 460.0
	var p := Vector2(size.x * 0.5 - larg * 0.5, 104.0)
	var w := _fonte.get_string_size(chefe_nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(_fonte, Vector2(size.x * 0.5 - w * 0.5, p.y - 8.0), chefe_nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.95))
	draw_rect(Rect2(p.x - 3.0, p.y - 3.0, larg + 6.0, 20.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(p.x, p.y, larg * clampf(chefe_vida, 0.0, 1.0), 14.0), Color(1.0, 0.32, 0.22))
	for k in range(1, 4):
		draw_rect(Rect2(p.x + larg * k / 4.0 - 1.0, p.y, 2.0, 14.0), Color(0, 0, 0, 0.5))



## A arma em uso e as granadas, no canto de baixo à direita (só quando há mais que a pistola de fábrica).
var perigo := -1.0  # a Fundição: 0 a 1 do tempo parado lá dentro até a horda (negativo: sem contagem)
var _golpe_n_visto := 0
var _golpe_t := 0.0
var _golpe_dir := Vector3.ZERO
var _golpe_escudo := false


## O tempo até a horda, por figura (para quem não lê): seis barras vermelhas embaixo da bússola, iguais às
## lâmpadas sobre a porta, que acendem uma a uma; a próxima pisca.
func _desenhar_perigo() -> void:
	if perigo < 0.0 or simples:
		return
	var n := 6
	var w := 22.0
	var h := 9.0
	var vao := 7.0
	var x0 := size.x * 0.5 - (n * w + (n - 1) * vao) * 0.5
	var y := 74.0
	var cheias := perigo * n
	var pisca := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.014)
	for i in n:
		var r := Rect2(x0 + i * (w + vao), y, w, h)
		draw_rect(r.grow(2.0), Color(0, 0, 0, 0.5))
		var f := 1.0 if i < floori(cheias) else (pisca if i == floori(cheias) else 0.0)
		draw_rect(r, Color(0.25, 0.08, 0.06, 0.85).lerp(Color(1.0, 0.3, 0.2, 1.0), f))


## De que lado veio o último acerto: um arco com uma ponta em volta do meio da tela, virado para o atacante
## (a frente da câmera fica em cima). Vermelho; branco quando o escudo engoliu (azul sumia na bolha do escudo).
## Some em 1,3 s.
func _desenhar_golpe() -> void:
	if alvo == null:
		return
	if alvo.golpe_n != _golpe_n_visto:
		_golpe_n_visto = alvo.golpe_n
		_golpe_t = 1.3
		_golpe_dir = -alvo.golpe_de
		_golpe_escudo = alvo.golpe_no_escudo
	_golpe_t = maxf(0.0, _golpe_t - get_process_delta_time())
	var cam := get_viewport().get_camera_3d()
	var plano := Vector3(_golpe_dir.x, 0, _golpe_dir.z)
	if _golpe_t <= 0.0 or cam == null or plano.length() < 0.01:
		return
	var frente := -cam.global_basis.z
	frente = Vector3(frente.x, 0, frente.z).normalized()
	var direita := Vector3(-frente.z, 0, frente.x)
	plano = plano.normalized()
	var a := -PI * 0.5 + atan2(plano.dot(direita), plano.dot(frente))
	var c := size * 0.5
	var raio := minf(size.x, size.y) * 0.2
	var al := clampf(_golpe_t / 0.5, 0.0, 1.0)
	var cor := Color(1.0, 1.0, 1.0) if _golpe_escudo else Color(1.0, 0.3, 0.2)
	var fora := Vector2(cos(a), sin(a))
	var lado := Vector2(-fora.y, fora.x)
	draw_arc(c, raio, a - 0.4, a + 0.4, 18, Color(0, 0, 0, 0.45 * al), 15.0, true)
	draw_arc(c, raio, a - 0.38, a + 0.38, 18, Color(cor, 0.9 * al), 10.0, true)
	# a ponta, para fora, no meio do arco
	var tri := PackedVector2Array([c + fora * (raio + 26.0), c + fora * (raio - 2.0) + lado * 15.0, c + fora * (raio - 2.0) - lado * 15.0])
	draw_colored_polygon(PackedVector2Array([c + fora * (raio + 29.0), c + fora * (raio - 4.0) + lado * 18.0, c + fora * (raio - 4.0) - lado * 18.0]), Color(0, 0, 0, 0.45 * al))
	draw_colored_polygon(tri, Color(cor, 0.95 * al))


func _desenhar_arma() -> void:
	if alvo == null:
		return
	if Arsenal.modo == "pistola" and Arsenal.granadas_max() == 0 and Arsenal.fabricados.is_empty():
		return
	# só o nome da arma, à direita embaixo, por uns segundos depois de trocar (a munição fica ao lado da
	# curva do calor)
	if Arsenal.modo != _arma_antes:
		_arma_antes = Arsenal.modo
		_arma_vista = 3.0
	_arma_vista = maxf(_arma_vista - get_process_delta_time(), 0.0)
	var aa := clampf(_arma_vista, 0.0, 1.0)
	if aa > 0.01:
		var titulo: String = Arsenal.MODOS[Arsenal.modo]["titulo"]
		var w := _fonte.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		Icones.desenhar(self, Arsenal.modo, Vector2(size.x - w - 62.0, size.y - 46.0), 0.9, Color(1, 1, 1, 0.9 * aa), 1.5)
		draw_string(_fonte, Vector2(size.x - w - 34.0, size.y - 40.0), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.92 * aa))
	# os mísseis travando: um losango numerado em cada máquina travada
	var cam3 := get_viewport().get_camera_3d()
	if tiro_no and cam3:
		var k := 0
		for t in tiro_no.get("travas"):
			k += 1
			if not is_instance_valid(t):
				continue
			var pt: Vector3 = t.call("ponto_de_trava")
			if not pt.is_finite() or cam3.is_position_behind(pt):
				continue
			var q := cam3.unproject_position(pt)
			var l := clampf(700.0 / maxf(4.0, cam3.global_position.distance_to(pt)), 14.0, 44.0)
			var cor_m := Color(1.0, 0.3, 0.25, 0.95)
			draw_polyline(PackedVector2Array([q + Vector2(0, -l), q + Vector2(l, 0), q + Vector2(0, l), q + Vector2(-l, 0), q + Vector2(0, -l)]), cor_m, 2.5, true)
			draw_string(_fonte, q + Vector2(l + 4.0, 5.0), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cor_m)
	# o canhão carregando: um anel em volta da mira
	if tiro_no and float(tiro_no.get("carga")) > 0.0:
		var cg := float(tiro_no.get("carga"))
		draw_arc(size * 0.5, 22.0, -PI * 0.5, -PI * 0.5 + TAU * cg, 40, Color(1.0, 0.62, 0.3, 0.95) if cg < 1.0 else Color(1, 1, 1), 4.0, true)


func _desenhar_conselho() -> void:
	if conselho == "":
		return
	# some e aparece devagar; uma barra da cor do drone à esquerda diz de quem é a frase
	var a := clampf(_conselho_t / 0.6, 0.0, 1.0)
	var w := Botoes.largura(conselho, _fonte, 19)
	var p := Vector2(size.x * 0.5 - w * 0.5, size.y - 176.0)
	draw_rect(Rect2(p.x - 22.0, p.y - 30.0, w + 44.0, 46.0), Color(0.02, 0.06, 0.07, 0.62 * a))
	draw_rect(Rect2(p.x - 22.0, p.y - 30.0, 4.0, 46.0), Color(0.35, 0.95, 0.85, 0.9 * a))
	Botoes.desenhar(self, _fonte, p, conselho, 19, Color(0.93, 0.96, 0.95, a))


func _desenhar_dica() -> void:
	# o convite de sentar (perto de um sofá, poltrona ou banco) vem do robô e só aparece sem outro convite
	var d := dica
	if d == "" and alvo and alvo.convite_assento != "":
		d = alvo.convite_assento
	if d == "":
		return
	# `{acao}` no texto vira a imagem do botão no aparelho em uso (Botoes)
	var w := Botoes.largura(d, _fonte, 20)
	var p := Vector2(size.x * 0.5 - w * 0.5, size.y - 120.0)
	draw_rect(Rect2(p.x - 18.0, p.y - 30.0, w + 36.0, 46.0), Color(0, 0, 0, 0.45))
	Botoes.desenhar(self, _fonte, p, d, 20, Color(1, 1, 1, 0.95))


func _draw() -> void:
	_desenhar_bussola()
	_desenhar_lugar()
	_desenhar_conselho()
	_desenhar_dica()
	_desenhar_placar()
	_desenhar_arma()
	_desenhar_chefe()
	_desenhar_perigo()
	_desenhar_golpe()
	_desenhar_resumo()
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
	# Tela limpa (referência do usuário, 2026-11-17): a mira só aparece com a arma em uso; o calor do motor
	# é uma barra curta embaixo, no centro, que surge quando ele aquece; nada fica fixo no meio da tela.
	var dt := get_process_delta_time()
	var usando: bool = alvo.mirando_agora() or alvo.atirando > 0.0 or alvo.atirando_e > 0.0 or alvo.estado == Armadura.Estado.PAIRAR
	if tiro_no:
		usando = usando or float(tiro_no.get("carga")) > 0.0 or not (tiro_no.get("travas") as Array).is_empty() or (tiro_no.get("arco") as PackedVector3Array).size() > 0
	_mira_vista = move_toward(_mira_vista, 1.0 if usando else 0.0, dt * (8.0 if usando else 1.6))
	if _mira_vista > 0.01:
		var am := _mira_vista
		if alvo.mirando_agora():
			var cm := Color(1, 1, 1, 0.9 * am)
			# contorno escuro por baixo: a mira branca sumia sobre o capim claro
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + d * 6.0, c + d * 17.0, Color(0, 0, 0, 0.55 * am), 5.0, true)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(c + d * 7.0, c + d * 16.0, cm, 2.0, true)
			var txt_d := "%d m" % roundi(alvo.global_position.distance_to(alvo.alvo_mira)) if alvo.alvo_mira_ok else ""
			# a distância fica embaixo da mira (ao lado ficam os arcos da munição)
			var wd := _fonte.get_string_size(txt_d, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string_outline(_fonte, c + Vector2(-wd * 0.5, 36), txt_d, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.6 * am))
			draw_string(_fonte, c + Vector2(-wd * 0.5, 36), txt_d, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85 * am))
		else:
			draw_arc(c, 11.0, 0.0, TAU, 32, Color(0, 0, 0, 0.45 * am), 4.5, true)
			draw_circle(c, 3.2, Color(0, 0, 0, 0.5 * am))
			draw_circle(c, 2.0, Color(1, 1, 1, 0.9 * am))
			draw_arc(c, 11.0, 0.0, TAU, 32, Color(1, 1, 1, 0.7 * am), 1.5, true)
	# A munição fica ao lado da mira, em arco (pedido do usuário, 2026-11-18; antes eram marcas embaixo, perto
	# do calor): os mísseis à direita, com os mísseis escolhidos e mirando; as granadas à esquerda, enquanto
	# se segura o botão da granada. Um traço curvo por unidade: cheio o que resta, apagado o que foi gasto.
	# os mísseis: com eles escolhidos, aparece mirando, segurando o gatilho (mesmo sem alvo travado) e por uns
	# dois segundos depois de cada disparo. Antes só aparecia mirando ou com um alvo já travado, e quem
	# atirava sem mirar e sem máquina por perto nunca via o contador.
	if Arsenal.misseis != _misseis_antes:
		if _misseis_antes >= 0:
			_missil_fica = 2.2
		_misseis_antes = Arsenal.misseis
	_missil_fica = maxf(0.0, _missil_fica - dt)
	var gatilho_missil: bool = tiro_no != null and (bool(tiro_no.get("_segurando_missil")) or not (tiro_no.get("travas") as Array).is_empty())
	var quer_missil: bool = Arsenal.modo == "misseis" and (alvo.mirando_agora() or gatilho_missil or _missil_fica > 0.0)
	var quer_granada: bool = Arsenal.granadas_max() > 0 and (Input.is_action_pressed("granada") or (tiro_no != null and (tiro_no.get("arco") as PackedVector3Array).size() > 0))
	_missil_visto = move_toward(_missil_visto, 1.0 if quer_missil else 0.0, dt * (9.0 if quer_missil else 3.0))
	_granada_vista = move_toward(_granada_vista, 1.0 if quer_granada else 0.0, dt * (9.0 if quer_granada else 3.0))
	for lado_m: Array in [[_missil_visto, Arsenal.misseis, Arsenal.misseis_max(), 0.0], [_granada_vista, Arsenal.granadas, Arsenal.granadas_max(), PI]]:
		var vis: float = lado_m[0]
		var total: int = lado_m[2]
		if vis < 0.01 or total <= 0:
			continue
		var raio_m := 40.0
		var abre_m := deg_to_rad(minf(100.0, 14.0 * total))  # o arco inteiro
		var passo_m := abre_m / total
		for i_m in total:
			# de baixo para cima; os gastos somem a partir de cima
			var a0 := float(lado_m[3]) + abre_m * 0.5 - (i_m + 1) * passo_m + deg_to_rad(1.6)
			var a1 := float(lado_m[3]) + abre_m * 0.5 - i_m * passo_m - deg_to_rad(1.6)
			var tem: bool = i_m < int(lado_m[1])
			draw_arc(c, raio_m, a0, a1, 6, Color(0, 0, 0, 0.45 * vis), 7.0, true)  # sombra, para ler sobre o capim claro
			draw_arc(c, raio_m, a0, a1, 6, Color(1, 1, 1, (0.95 if tem else 0.3) * vis), 4.0 if tem else 2.5, true)
		var num := str(int(lado_m[1]))
		var wn := _fonte.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var onde_n := c + Vector2(cos(float(lado_m[3])), 0.0) * (raio_m + 16.0) + Vector2(-wn * 0.5, 5.0)
		draw_string(_fonte, onde_n, num, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, (0.75 if int(lado_m[1]) > 0 else 0.45) * vis))
	# a rajada esquentando: uma curva à direita da mira, como a do motor (pedido do usuário, 2026-11-20). Enche
	# de baixo para cima; cheia, pisca em vermelho e a rajada para até esfriar
	var q_r := float(tiro_no.get("calor_rajada")) if tiro_no else 0.0
	var quente_r: bool = tiro_no != null and bool(tiro_no.get("rajada_quente"))
	var quer_r: bool = Arsenal.modo == "rajada" and (q_r > 0.02 or quente_r)
	_rajada_vista = move_toward(_rajada_vista, 1.0 if quer_r else 0.0, dt * (8.0 if quer_r else 2.0))
	if _rajada_vista > 0.01:
		var ar := _rajada_vista
		var raio_r := 46.0  # um pouco por fora das contas de munição (raio 40)
		var abre_r := deg_to_rad(40.0)
		var cor_r := Color(0.4, 0.9, 0.95).lerp(Color(1.0, 0.62, 0.15), smoothstep(0.45, 0.75, q_r))
		cor_r = cor_r.lerp(Color(1.0, 0.18, 0.12), smoothstep(0.82, 0.98, q_r))
		if quente_r:
			cor_r = Color(1.0, 0.15, 0.1) if fmod(Time.get_ticks_msec() * 0.001, 0.4) < 0.2 else Color(0.5, 0.08, 0.05)
		draw_arc(c, raio_r, -abre_r, abre_r, 24, Color(0, 0, 0, 0.55 * ar), 10.0, true)  # o trilho escuro
		if q_r > 0.01:
			draw_arc(c, raio_r, abre_r - 2.0 * abre_r * q_r, abre_r, 24, Color(cor_r, 0.95 * ar), 5.5, true)
		var a_fim := -abre_r - deg_to_rad(2.0)
		draw_line(c + Vector2.from_angle(a_fim) * (raio_r - 7.0), c + Vector2.from_angle(a_fim) * (raio_r + 7.0), Color(1.0, 0.25, 0.18, (0.9 if q_r > 0.8 else 0.45) * ar), 3.0, true)
	# máquina travada pela mira assistida: quatro cantos em volta dela
	if alvo.mirando_agora() and tiro and tiro.travado and is_instance_valid(tiro.travado) and cam:
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
	# embaixo, no centro, em três arcos de mesmo centro: a vida por cima, o calor no meio, o escudo por
	# baixo. Cada um só aparece quando tem o que dizer. (Sem texto de superaquecido: o arco vermelho
	# piscando e o robô travado já dizem.)
	var raio := 300.0
	var centro := Vector2(size.x * 0.5, size.y - 84.0 - raio)
	var meio := PI * 0.5  # o ponto de baixo do círculo
	var abre := deg_to_rad(15.0)
	var q := alvo.calor / 100.0
	var pisca := fmod(Time.get_ticks_msec() * 0.001, 0.4) < 0.2
	# "resfriado": a água, a chuva ou uma cachoeira está tirando calor (ou acabou de zerar). O arco aparece
	# mesmo vazio, em azul claro, com a palavra embaixo.
	var esfriando: bool = alvo.resfriado > 0.0 or (alvo.na_agua and alvo.em_voo()) or (alvo.chuva > 0.3 and alvo.em_voo())
	_frio_visto = move_toward(_frio_visto, 1.0 if esfriando else 0.0, dt * (5.0 if esfriando else 1.2))
	_calor_visto = move_toward(_calor_visto, 1.0 if (q > 0.06 or alvo.superaquecido or esfriando) else 0.0, dt * (5.0 if (q > 0.06 or esfriando) else 0.9))
	if _calor_visto > 0.01:
		var ac := _calor_visto
		var cor := Color(0.4, 0.9, 0.95).lerp(Color(1.0, 0.62, 0.15), smoothstep(0.45, 0.75, q))
		cor = cor.lerp(Color(1.0, 0.18, 0.12), smoothstep(0.82, 0.98, q))
		if alvo.superaquecido:
			cor = Color(1.0, 0.15, 0.1) if pisca else Color(0.5, 0.08, 0.05)
		draw_arc(centro, raio, meio - abre, meio + abre, 40, Color(0, 0, 0, 0.55 * ac), 8.0, true)  # trilho largo e escuro: o arco sumia sobre o capim
		if _frio_visto > 0.01:
			# o trilho inteiro em azul claro, por baixo do calor que ainda houver
			draw_arc(centro, raio, meio - abre, meio + abre, 40, Color(0.55, 0.88, 1.0, 0.55 * _frio_visto * ac), 4.0, true)
		# enche do meio para as pontas
		if q > 0.01:
			draw_arc(centro, raio, meio - abre * q, meio + abre * q, 40, Color(cor, 0.95 * ac), 4.0, true)
		for sx: float in [-1.0, 1.0]:
			var am := meio + sx * (abre + deg_to_rad(1.2))
			draw_line(centro + Vector2.from_angle(am) * (raio - 7.0), centro + Vector2.from_angle(am) * (raio + 7.0), Color(1.0, 0.25, 0.18, (0.9 if q > 0.8 else 0.45) * ac), 3.0, true)
	if _frio_visto > 0.01:
		var txt2 := "resfriado"
		var w2 := _fonte.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(_fonte, Vector2(size.x * 0.5 - w2 * 0.5, size.y - 54.0), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.9, 1.0, 0.85 * _frio_visto))
	# a vida: um pedaço de arco por acerto que o robô aguenta, acompanhando a curva por cima dela. Só
	# aparece com dano, e some depois de sarar
	var dano := float(alvo.avaria) + float(alvo.get("_dano_frac"))
	_dano_visto = move_toward(_dano_visto, 1.0 if dano > 0.01 else 0.0, dt * (4.0 if dano > 0.01 else 0.7))
	if _dano_visto > 0.01:
		var total := Arsenal.golpes_pane()
		var passo := deg_to_rad(6.2)
		var vao := deg_to_rad(1.0)
		for k in total:
			var perdido := clampf(dano - k, 0.0, 1.0)
			var cor_d := Color(0.45, 0.95, 0.85).lerp(Color(1.0, 0.45, 0.15), perdido)
			if perdido >= 1.0:
				cor_d = Color(1.0, 0.2, 0.12, 0.9) if (pisca or dano < total - 1) else Color(0.5, 0.1, 0.06, 0.9)
			# da esquerda para a direita (o ângulo cresce para a esquerda na parte de baixo do círculo)
			var a_ini := meio + (total * 0.5 - k) * passo
			draw_arc(centro, raio - 13.0, a_ini - passo + vao, a_ini, 8, Color(cor_d, cor_d.a * _dano_visto), 5.0, true)
	# o escudo de energia: um arco fino por baixo. Gasto em parte, três pedaços (os que restam acesos);
	# quebrado, enche enquanto recarrega
	if Arsenal.tem("escudo") and alvo.escudo_t > 0.0:
		var pronto := 1.0 - clampf(alvo.escudo_t / Arsenal.ESCUDO_RECARGA, 0.0, 1.0)
		draw_arc(centro, raio + 9.0, meio - abre, meio + abre, 30, Color(0, 0, 0, 0.3), 2.0, true)
		draw_arc(centro, raio + 9.0, meio + abre - abre * 2.0 * pronto, meio + abre, 30, Color(0.35, 0.95, 0.85, 0.85), 2.0, true)
	elif Arsenal.tem("escudo") and alvo.escudo_cargas < Arsenal.ESCUDO_CARGAS:
		var n_e := Arsenal.ESCUDO_CARGAS
		var passo_e := abre * 2.0 / n_e
		for k_e in n_e:
			var a_e := meio + abre - (k_e + 1) * passo_e
			var cheio_e: bool = k_e < alvo.escudo_cargas
			draw_arc(centro, raio + 9.0, a_e + deg_to_rad(0.6), a_e + passo_e - deg_to_rad(0.6), 8, Color(0.35, 0.95, 0.85, 0.85) if cheio_e else Color(0, 0, 0, 0.3), 3.0 if cheio_e else 2.0, true)
	# velocidade e altura: só enquanto voa (no chão a tela fica limpa)
	var voando: bool = alvo.em_voo() or alvo.estado == Armadura.Estado.PAIRAR
	_voo_visto = move_toward(_voo_visto, 1.0 if voando else 0.0, dt * (4.0 if voando else 1.2))
	if _voo_visto > 0.01:
		var v := alvo.velocity.length() * 3.6
		var base := Vector2(28.0, size.y - 34.0)
		var txt_h := "%d m do chão" % roundi(maxf(0.0, alvo.altura_do_chao()))
		draw_string_outline(_fonte, base, "%d km/h" % roundi(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.6 * _voo_visto))
		draw_string(_fonte, base, "%d km/h" % roundi(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.95 * _voo_visto))
		draw_string_outline(_fonte, base + Vector2(0, 19), txt_h, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.6 * _voo_visto))
		draw_string(_fonte, base + Vector2(0, 19), txt_h, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85 * _voo_visto))
