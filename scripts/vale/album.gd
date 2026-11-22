class_name Album
extends CanvasLayer
## O álbum da ilha (1.1, doc §136): a câmera do robô tira fotos e cada coisa fotografada ganha uma página.
## Tira foto com o triângulo (agir) em dois jeitos de olhar: no scanner (primeira pessoa, com o zoom do R2 e L2)
## e apreciando a vista (a tela limpa). A foto sai sem nada da tela por cima.
## O que conta numa foto: os bichos, os amigos e as máquinas que aparecem no quadro (sem morro na frente), a cena
## rara que estiver acontecendo (a revoada, as folhas, a estrela cadente; e as do clima: arco-íris, aurora,
## raio e neblina) e o lugar com nome que estiver no meio da foto. Cada página guarda a foto mais nova. Foto sem
## nada de página vai para as soltas (as oito últimas).
## As páginas ficam no caderno (botão Álbum). As fotos ficam em user://album/.
## Quem cria passa `armadura`, `camera`, `scanner`, `hud` e `mapa`.

const PASTA := "user://album/"
const PASTA_TESTE := "user://album_teste/"  # sem o guardado (testes e fotos), para não misturar com o álbum de verdade
const LARG := 640
const ALT := 360
const SOLTAS := 8
const GRUPOS := [
	["BICHOS", [["cervo", "Cervo"], ["coelho", "Coelho"], ["raposa", "Raposa"], ["lobo", "Lobo"], ["passaros", "Pássaros"],
		["peixes", "Peixes"], ["lagopode", "Lagópode"], ["marmota", "Marmota"], ["pato", "Pato-arlequim"], ["corvo", "Corvo"]]],
	["AMIGOS", [["drone", "Drone colega"], ["robozinho", "Robozinho"], ["faisca", "Faísca"]]],
	["MÁQUINAS", [["maquina", "Máquina"], ["vigia", "Vigia"], ["sentinela", "Sentinela"], ["espadachim", "Espadachim"],
		["couraca", "Couraça"], ["batedor", "Batedor"], ["artilheiro", "Artilheiro"]]],
	["PROCURADOS", [["capataz", "Capataz"], ["guardiao", "Guardião"], ["canhoneiro", "Canhoneiro"]]],
	["CENAS RARAS", [["revoada", "Revoada"], ["folhas", "Folhas ao vento"], ["estrela", "Estrela cadente"], ["arco_iris", "Arco-íris"],
		["aurora", "Aurora"], ["raio", "Raio na tempestade"], ["neblina", "Neblina"]]],
]

static var paginas := {}  # id -> {"foto": caminho, "hora": float}
static var soltas: Array = []  # caminhos das fotos sem página, da mais nova para a mais velha
static var cenas_agora := {}  # id -> [até quando (ms), onde (Vector3.INF = em qualquer direção)]
static var _texturas := {}
static var fotos_bichos := 0  # fotos com algum bicho no quadro, nesta partida (os pedidos do drone contam)
const BICHOS := ["cervo", "coelho", "raposa", "lobo", "passaros", "peixes", "lagopode", "marmota", "pato", "corvo"]

var armadura: Armadura
var camera: CameraVoo
var scanner: Scanner
var hud: Hud
var mapa: Vale
var fotos := 0  # testes
var ultima_lista: Array = []  # testes: as páginas da última foto

var _flash: ColorRect
var _aviso: Control
var _aviso_texto := ""
var _aviso_sub := ""
var _t_aviso := 0.0
var _tirando := false


func _ready() -> void:
	layer = 6
	carregar()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_aviso = Control.new()
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.draw.connect(_desenhar_aviso)
	add_child(_aviso)


static func carregar() -> void:
	if not Guardado.ativo:
		return
	var g: Dictionary = Guardado.progresso("album")
	paginas = (g.get("paginas", {}) as Dictionary).duplicate(true)
	soltas = (g.get("soltas", []) as Array).duplicate()


static func _guardar() -> void:
	if Guardado.ativo:
		Guardado.por_progresso("album", {"paginas": paginas, "soltas": soltas})


## Uma cena rara começou: por `segundos` ela conta numa foto. `onde` (um ponto ou um nó que anda) faz ela só
## contar com ele no quadro; sem ele, conta para qualquer lado.
static func marcar_cena(id: String, segundos: float, onde: Variant = Vector3.INF) -> void:
	cenas_agora[id] = [Time.get_ticks_msec() + int(segundos * 1000.0), onde]


static func lugares() -> Array:
	var l: Array = [["lugar_base", "A base"]]
	for m: Array in Marcos.lugares:
		var nome := String(m[0])
		l.append(["lugar_" + nome.to_lower().replace(" ", "_"), nome])
	return l


## Todas as páginas, em grupos: [[título, [[id, nome], ...]], ...].
static func entradas() -> Array:
	var g: Array = GRUPOS.duplicate(true)
	g.append(["LUGARES", lugares()])
	return g


static func total() -> int:
	var n := 0
	for grupo: Array in entradas():
		n += (grupo[1] as Array).size()
	return n


static func textura(caminho: String) -> Texture2D:
	if caminho == "":
		return null
	if _texturas.has(caminho):
		return _texturas[caminho]
	var img := Image.load_from_file(caminho) if FileAccess.file_exists(caminho) else null
	if img == null:
		return null
	var t := ImageTexture.create_from_image(img)
	_texturas[caminho] = t
	return t


# ---------------------------------------------------------------- tirar a foto

func _physics_process(delta: float) -> void:
	_t_aviso = maxf(0.0, _t_aviso - delta)
	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 3.0)
	_aviso.queue_redraw()
	if armadura == null or _tirando:
		return
	if (armadura.escaneando or armadura.contemplando) and Input.is_action_just_pressed("agir"):
		tirar()


func tirar() -> void:
	_tirando = true
	var achados := no_quadro()
	ultima_lista = achados
	var scanner_vis := scanner != null and scanner.visible
	if scanner:
		scanner.visible = false
	var hud_vis := hud != null and hud.visible
	if hud:
		hud.visible = false
	_aviso.visible = false
	_flash.color.a = 0.0
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if scanner and scanner.ligado:
		scanner.visible = scanner_vis
	if hud and hud_vis:
		hud.visible = true
	_aviso.visible = true
	_recortar(img)
	var pasta := PASTA if Guardado.ativo else PASTA_TESTE
	DirAccess.make_dir_recursive_absolute(pasta)
	var novas: Array = []
	if achados.is_empty():
		var nome := pasta + "solta_%d_%d.jpg" % [int(Time.get_unix_time_from_system()), fotos]
		img.save_jpg(nome, 0.88)
		soltas.push_front(nome)
		while soltas.size() > SOLTAS:
			DirAccess.remove_absolute(String(soltas.pop_back()))
	else:
		for id: String in achados:
			var caminho := pasta + id + ".jpg"
			img.save_jpg(caminho, 0.88)
			_texturas.erase(caminho)
			if not paginas.has(id):
				novas.append(id)
			paginas[id] = {"foto": caminho, "hora": snappedf(CicloDia.atual.hora if CicloDia.atual else 12.0, 0.1)}
	_guardar()
	fotos += 1
	for id: String in achados:
		if BICHOS.has(id):
			fotos_bichos += 1
			break
	_flash.color.a = 0.85
	var som := AudioStreamPlayer.new()
	som.stream = Som.stream("foto")
	som.volume_db = -6.0
	add_child(som)
	som.play()
	som.finished.connect(som.queue_free)
	if not novas.is_empty():
		_aviso_texto = "Página nova no álbum"
		_aviso_sub = ", ".join(PackedStringArray(novas.map(nome_de)))
	elif not achados.is_empty():
		_aviso_texto = "Foto nova no álbum"
		_aviso_sub = ", ".join(PackedStringArray(achados.map(nome_de)))
	else:
		_aviso_texto = "Foto guardada"
		_aviso_sub = "nas fotos soltas do álbum"
	_t_aviso = 3.0
	_tirando = false


## Corta no meio para 16:9 e reduz para 640 x 360.
func _recortar(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var alvo_h := int(w * 9.0 / 16.0)
	if alvo_h < h:
		var r := img.get_region(Rect2i(0, (h - alvo_h) / 2, w, alvo_h))
		img.copy_from(r)
	elif alvo_h > h:
		var alvo_w := int(h * 16.0 / 9.0)
		var r2 := img.get_region(Rect2i((w - alvo_w) / 2, 0, alvo_w, h))
		img.copy_from(r2)
	img.resize(LARG, ALT, Image.INTERPOLATE_LANCZOS)


static func nome_de(id) -> String:
	for grupo: Array in entradas():
		for e: Array in grupo[1]:
			if String(e[0]) == String(id):
				return String(e[1])
	return String(id)


# ---------------------------------------------------------------- o que está no quadro

func no_quadro() -> Array:
	var cam := camera.cam
	var tela := get_viewport().get_visible_rect().size
	var achados: Array = []
	var olho := cam.global_position
	var longe := 80.0 * 70.0 / maxf(cam.fov, 8.0)  # com zoom (fov menor) vale mais longe
	if scanner:
		for c: Array in scanner._candidatos():
			var p: Vector3 = c[1]
			if not _na_tela(cam, p, tela, 0.05) or olho.distance_to(p) > longe or _tapado(olho, p):
				continue
			var id := pagina_de(c[0])
			if id != "" and not achados.has(id):
				achados.append(id)
	var agora := Time.get_ticks_msec()
	for id: String in cenas_agora:
		var c: Array = cenas_agora[id]
		if int(c[0]) < agora or achados.has(id):
			continue
		var onde: Variant = c[1]
		if onde is Node3D:
			if not is_instance_valid(onde) or not _na_tela(cam, (onde as Node3D).global_position, tela, 0.0):
				continue
		elif onde is Vector3 and (onde as Vector3).is_finite() and not _na_tela(cam, onde, tela, 0.0):
			continue
		achados.append(id)
	var lugar := _lugar_no_meio(cam, tela)
	if lugar != "":
		achados.append(lugar)
	return achados


func _na_tela(cam: Camera3D, p: Vector3, tela: Vector2, margem: float) -> bool:
	if cam.is_position_behind(p):
		return false
	var s := cam.unproject_position(p)
	return s.x > tela.x * margem and s.x < tela.x * (1.0 - margem) and s.y > tela.y * margem and s.y < tela.y * (1.0 - margem)


func _tapado(olho: Vector3, p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(olho, p, 1)
	q.exclude = [armadura.get_rid()]
	var bate := armadura.get_world_3d().direct_space_state.intersect_ray(q)
	return not bate.is_empty() and olho.distance_to(bate["position"]) < olho.distance_to(p) - 1.2


static func pagina_de(o) -> String:
	if o is String:
		return "faisca"
	if o is BichoFicha:
		return (o as BichoFicha).especie
	if o is Raposa:
		return "raposa"
	if o is Lobo:
		return "lobo"
	if o is Cervo:
		return "cervo"
	if o is Coelho:
		return "coelho"
	if o is Passaros:
		return "passaros"
	if o is Peixes:
		return "peixes"
	if o is DroneColega:
		return "drone"
	if o is Node3D and (o as Node3D).has_meta("robozinho"):
		return "robozinho"
	if o is Mecha:
		var modelo := String((o as Mecha).ficha.get("modelo", ""))
		return modelo if InimigoVisual.NOMES.has(modelo) else "sentinela"
	if o is Vigia:
		return "vigia"
	if o is MaquinaPequena:
		return "maquina"
	return ""


## O lugar com nome mais perto do meio da tela (perto o bastante para ser o assunto da foto).
func _lugar_no_meio(cam: Camera3D, tela: Vector2) -> String:
	var olho := cam.global_position
	var meio := tela * 0.5
	var melhor := ""
	var melhor_d := tela.length() * 0.3
	var lista: Array = []
	if Melhorias.base.is_finite():
		lista.append(["lugar_base", Vector2(Melhorias.base.x, Melhorias.base.z), 30.0])
	for m: Array in Marcos.lugares:
		lista.append(["lugar_" + String(m[0]).to_lower().replace(" ", "_"), m[1], float(m[2])])
	for l: Array in lista:
		var c: Vector2 = l[1]
		var raio: float = l[2]
		if Vector2(olho.x - c.x, olho.z - c.y).length() > raio * 2.5 + 80.0:
			continue
		var y := mapa.altura(c.x, c.y) + 4.0 if mapa else olho.y
		var p := Vector3(c.x, y, c.y)
		if not _na_tela(cam, p, tela, 0.1):
			continue
		var d := cam.unproject_position(p).distance_to(meio)
		if d < melhor_d:
			melhor_d = d
			melhor = String(l[0])
	return melhor


# ---------------------------------------------------------------- o aviso embaixo

func _desenhar_aviso() -> void:
	if _t_aviso <= 0.0:
		return
	var a := clampf(_t_aviso / 0.5, 0.0, 1.0)
	var tela := _aviso.get_viewport_rect().size
	var fonte := ThemeDB.fallback_font
	var y := tela.y - 120.0
	var largura := maxf(fonte.get_string_size(_aviso_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, fonte.get_string_size(_aviso_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x) + 90.0
	var x := (tela.x - largura) * 0.5
	_aviso.draw_rect(Rect2(x, y - 34.0, largura, 70.0), Color(0.03, 0.06, 0.07, 0.75 * a))
	Icones.desenhar(_aviso, "foto", Vector2(x + 34.0, y + 1.0), 1.25, Color(1.0, 0.82, 0.5, a), 2.2)
	_aviso.draw_string(fonte, Vector2(x + 66.0, y - 4.0), _aviso_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.95, 0.9, a))
	_aviso.draw_string(fonte, Vector2(x + 66.0, y + 22.0), _aviso_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.78, 0.76, a))
