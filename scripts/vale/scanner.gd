class_name Scanner
extends CanvasLayer
## O scanner (melhoria, doc §65): seta para a direita / T. A tela sai da terceira pessoa e vai para os
## olhos do robô, como o visor de uma câmera, com um círculo no meio. Mantendo o círculo em cima de um
## bicho ou de uma máquina, a leitura enche; completa, aparece a ficha: nos bichos, o jeito deles; nas
## máquinas, o equipamento, a forma de ataque e quantos tiros aguentam. R2 aproxima e L2 afasta; soltando,
## o zoom fica onde está.

const ALCANCE := 170.0  # m
const TEMPO := 1.7  # s com o círculo em cima para ler
const RAIO := 110.0  # px do círculo
const FOLGA := 1.25  # o alvo conta dentro de RAIO * FOLGA
const AGUA := Color(0.35, 0.95, 0.85)
const TINTA := Color(0.93, 0.94, 0.9)

var armadura: Armadura
var camera: CameraVoo
var hud: Hud
var sons: Sons
var mapa: Vale
var ligado := false
var leituras := 0  # fichas completadas (testes)
var alvo_atual = null  # um nó, ou "faisca"
var progresso := 0.0
var ficha := {}
var _tela: Control
var _fonte: Font
var _t := 0.0


func _ready() -> void:
	layer = 4
	_tela = Control.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	_fonte = ThemeDB.fallback_font
	visible = false


func ligar() -> void:
	if ligado or not Melhorias.tem("scanner") or armadura.estado != Armadura.Estado.CHAO or armadura.em_pane or armadura.travado:
		return
	ligado = true
	visible = true
	armadura.escaneando = true
	armadura.visual.visible = false
	camera.primeira = true
	camera.zoom = 0.0
	alvo_atual = null
	progresso = 0.0
	ficha = {}
	if hud:
		hud.visible = false
	if sons:
		sons._toque("marcar", -8.0, 0.0)


func desligar() -> void:
	if not ligado:
		return
	ligado = false
	visible = false
	armadura.escaneando = false
	armadura.visual.visible = true
	camera.primeira = false
	if hud:
		hud.visible = true


func _physics_process(delta: float) -> void:
	_t += delta
	if armadura == null:
		return
	if Input.is_action_just_pressed("scanner"):
		if ligado:
			desligar()
		else:
			ligar()
	if not ligado:
		return
	if armadura.estado != Armadura.Estado.CHAO or armadura.em_pane or armadura.travado:
		desligar()
		return
	# R2 aproxima, L2 afasta; soltando, o zoom fica onde está
	camera.zoom = clampf(camera.zoom + (Input.get_action_strength("atirar") - Input.get_action_strength("mirar")) * delta * 0.9, 0.0, 1.0)
	var achado = _no_circulo()
	if achado == null:
		progresso = maxf(0.0, progresso - delta * 1.5)
		if progresso <= 0.0:
			alvo_atual = null
	elif typeof(achado) != typeof(alvo_atual) or achado != alvo_atual:
		alvo_atual = achado
		progresso = 0.0
		ficha = {}
	elif progresso < 1.0:
		progresso = minf(1.0, progresso + delta / TEMPO)
		if progresso >= 1.0:
			ficha = _ficha(alvo_atual)
			leituras += 1
			var nome := String(ficha["nome"])
			ficha["novo"] = not Melhorias.escaneados.has(nome)
			if ficha["novo"]:
				Melhorias.escaneados.append(nome)
				Melhorias.guardar()
			if sons:
				sons._toque("marcar", -4.0, 0.0)
	_tela.queue_redraw()


## O que dá para ler: bichos, máquinas, o drone colega e o Faísca caído. Devolve [objeto, ponto no mundo].
func _candidatos() -> Array:
	var lista := []
	for grupo in ["bichos", "maquinas", "amigos"]:
		for no in get_tree().get_nodes_in_group(grupo):
			if no is Node3D and (no as Node3D).is_visible_in_tree():
				var alto := 0.5
				if no is Vigia:
					alto = (no as Vigia).altura_m * 0.6
				elif no is Cervo:
					alto = 0.9
				lista.append([no, (no as Node3D).global_position + Vector3(0, alto, 0)])
	if BaseVale.faisca_em.is_finite():
		lista.append(["faisca", BaseVale.faisca_em + Vector3(0, 0.45, 0)])
	return lista


## O candidato mais perto do meio da tela, dentro do círculo, no alcance e sem morro na frente.
func _no_circulo():
	var cam := camera.cam
	var meio := get_viewport().get_visible_rect().size * 0.5
	var melhor = null
	var melhor_d := RAIO * FOLGA
	var olho := cam.global_position
	for c in _candidatos():
		var p: Vector3 = c[1]
		if cam.is_position_behind(p) or olho.distance_to(p) > ALCANCE:
			continue
		var d := cam.unproject_position(p).distance_to(meio)
		if d >= melhor_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(olho, p, 1)
		q.exclude = [armadura.get_rid()]
		var bate := armadura.get_world_3d().direct_space_state.intersect_ray(q)
		if not bate.is_empty() and olho.distance_to(bate["position"]) < olho.distance_to(p) - 1.2:
			continue
		melhor_d = d
		melhor = c[0]
	return melhor


func _ficha(o) -> Dictionary:
	if o is String:
		return {"nome": "Faísca", "tipo": "robô antigo · desligado",
			"linhas": ["Parou aqui há muito tempo.", "O musgo e as plantas tomaram conta.", "Mesma família do nosso robô."]}
	if o is MaquinaPacote:
		var mp := o as MaquinaPacote
		return {"nome": MaquinaPacote.TITULOS[mp.tipo], "tipo": "máquina · minichefe" if mp.chefe else "máquina · hostil", "linhas": _linhas_maquina(mp)}
	if o is Mecha:
		var m := o as Mecha
		return {"nome": String(m.ficha.get("nome", "Mecha")), "tipo": ("máquina chefe · hostil" if m.chefe else "máquina · hostil"), "linhas": _linhas_maquina(m)}
	if o is Vigia:
		return {"nome": "Vigia", "tipo": "máquina · hostil", "linhas": _linhas_maquina(o as Vigia)}
	if o is MaquinaPequena:
		return {"nome": "Máquina", "tipo": "máquina · hostil", "linhas": ["Desliga com o calor dos tiros e religa depois."]}
	if o is DroneColega:
		return {"nome": "Drone colega", "tipo": "máquina · amigo",
			"linhas": ["Mora no posto da base.", "Busca o robô quando ele desliga.", "Ninguém atira nele."]}
	if o is Cervo:
		return {"nome": "Cervo", "tipo": "bicho · manso", "linhas": ["Pasta nas clareiras.", "Foge de quem chega correndo.", "Com o robô sentado, chega perto."]}
	if o is Coelho:
		return {"nome": "Coelho", "tipo": "bicho · manso", "linhas": ["Vive no capim alto.", "Corre para longe com barulho.", "Com o robô sentado, fica curioso."]}
	if o is Passaros:
		return {"nome": "Pássaros", "tipo": "bicho · bando", "linhas": ["Voam em bando sobre a mata.", "Levantam voo quando o robô passa."]}
	if o is Peixes:
		return {"nome": "Peixes", "tipo": "bicho · cardume", "linhas": ["Nadam na água funda.", "Fogem do robô quando ele mergulha."]}
	return {"nome": "Desconhecido", "tipo": "sem registro", "linhas": []}


## Equipamento, ataque e vida de uma mecha, lidos do que ela carrega de verdade.
func _linhas_maquina(v: Vigia) -> Array:
	var linhas := []
	var ataque := ""
	if v.corpo_a_corpo:
		ataque = "chega junto e corta em arco"
	else:
		match v.tipo_tiro:
			"missil": ataque = "mísseis lentos que perseguem (dá para fugir)"
			"pesado": ataque = "canhão da luva, de braço estendido"
			_: ataque = "tiros da luva, de braço estendido"
		if v.rajada > 1:
			ataque += " · %d por vez" % v.rajada
	var equip := "cano na luva"
	if v.corpo_a_corpo:
		equip = "lâmina de luz no pulso"
	elif v.tipo_tiro == "missil":
		equip = "mísseis nos ombros"
	elif v.tipo_tiro == "pesado":
		equip = "canhão na luva"
	linhas.append("Equipamento: " + equip)
	linhas.append("Ataque: " + ataque)
	linhas.append("Distância de ataque: %d m · enxerga a %d m" % [int(v.dist_tiro), int(Vigia.VER)])
	var tiros := int(ceil(100.0 / maxf(1.0, v.calor_por_tiro())))
	linhas.append("Vida: desliga com %d tiros" % tiros + (" (desligada agora)" if v.desligada else ""))
	return linhas


func _desenhar() -> void:
	var tam := _tela.size
	var c := tam * 0.5
	# moldura de visor: faixas escuras em cima e embaixo, e os quatro cantos
	_tela.draw_rect(Rect2(0, 0, tam.x, 54.0), Color(0, 0, 0, 0.55))
	_tela.draw_rect(Rect2(0, tam.y - 54.0, tam.x, 54.0), Color(0, 0, 0, 0.55))
	var m := 90.0
	var braco := 46.0
	for canto in [Vector2(m, m), Vector2(tam.x - m, m), Vector2(m, tam.y - m), Vector2(tam.x - m, tam.y - m)]:
		var sx := 1.0 if canto.x < c.x else -1.0
		var sy := 1.0 if canto.y < c.y else -1.0
		_tela.draw_line(canto, canto + Vector2(braco * sx, 0), Color(1, 1, 1, 0.8), 3.0)
		_tela.draw_line(canto, canto + Vector2(0, braco * sy), Color(1, 1, 1, 0.8), 3.0)
	_tela.draw_string(_fonte, Vector2(m, 36.0), "SCANNER", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, AGUA)
	var vezes := tan(deg_to_rad(29.0)) / tan(deg_to_rad(camera.cam.fov * 0.5))
	_tela.draw_string(_fonte, Vector2(tam.x - m - 70.0, 36.0), "%.1f×" % vezes, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TINTA)
	_tela.draw_string(_fonte, Vector2(m, tam.y - 20.0), "R2 aproxima · L2 afasta (botões do mouse)   ·   seta para a direita / T: sair",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.75))
	# o círculo do meio: branco procurando, verde-água com algo dentro, e o arco da leitura
	var tem_alvo := alvo_atual != null
	var cor := AGUA if tem_alvo else Color(1, 1, 1, 0.85)
	_tela.draw_arc(c, RAIO, 0.0, TAU, 64, cor, 2.0, true)
	for k in 4:
		var d := Vector2.RIGHT.rotated(k * PI * 0.5)
		_tela.draw_line(c + d * (RAIO - 9.0), c + d * (RAIO + 9.0), cor, 2.0, true)
	_tela.draw_circle(c, 2.0, cor)
	if progresso > 0.0:
		_tela.draw_arc(c, RAIO + 8.0, -PI * 0.5, -PI * 0.5 + TAU * progresso, 64, AGUA, 5.0, true)
	if tem_alvo and progresso < 1.0:
		var txt := "lendo… mantenha no círculo"
		var w := _fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_tela.draw_string(_fonte, Vector2(c.x - w * 0.5, c.y + RAIO + 34.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AGUA)
	# a ficha, à direita do círculo
	if progresso >= 1.0 and not ficha.is_empty():
		var linhas: Array = ficha["linhas"]
		var larg := 430.0
		var alt := 96.0 + linhas.size() * 27.0
		var p := Vector2(minf(c.x + RAIO + 46.0, tam.x - larg - m), c.y - alt * 0.5)
		_tela.draw_rect(Rect2(p, Vector2(larg, alt)), Color(0.04, 0.08, 0.09, 0.86))
		_tela.draw_rect(Rect2(p, Vector2(5.0, alt)), AGUA)
		_tela.draw_line(c + Vector2(RAIO + 8.0, 0), Vector2(p.x, c.y), AGUA, 2.0, true)
		_tela.draw_string(_fonte, p + Vector2(22.0, 40.0), String(ficha["nome"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, TINTA)
		_tela.draw_string(_fonte, p + Vector2(22.0, 66.0), String(ficha["tipo"]) + ("   ·   novo registro" if ficha.get("novo", false) else ""),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AGUA)
		for i in linhas.size():
			_tela.draw_string(_fonte, p + Vector2(22.0, 100.0 + i * 27.0), String(linhas[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))
