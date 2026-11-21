class_name Procurados
extends Node3D
## Os chefes procurados (1.1, doc §136): três chefes com nome, cada um na sua toca (um tablado de metal entre
## colunas, com dois ou três ajudantes). O quadro de avisos da base mostra o retrato de cada um; vencido, o
## retrato ganha o visto verde. A toca aparece na bússola (uma coroa vermelha) a menos de 600 m.
## Vencer = desligar o chefe. O mergulho com impacto não derruba um chefe de uma vez (só esquenta muito). Com
## o chefe desligado a toca toda dorme para sempre, e ele deixa uma peça (instalada na oficina, como as da ilha).
## Experiência e material vêm na conta da Fundição (pedido do usuário, 2026-11-21): o chefe como um chefe da
## onda 15, cada ajudante como uma máquina da onda 8. Os procurados não voltam (são três, com nome e peça).
## Quem cria passa `mapa`, `armadura` e `hud`.

signal venceu(id: String)

const LISTA := [
	{"id": "capataz", "nome": "Capataz", "pos": Vector2(-820, 760), "peca": "couraca", "escolta": 2},
	{"id": "guardiao", "nome": "Guardião", "pos": Vector2(-1040, -680), "peca": "nucleo", "escolta": 2},
	{"id": "canhoneiro", "nome": "Canhoneiro", "pos": Vector2(-1150, -1080), "peca": "cano", "escolta": 3},
]
const ACORDA := 230.0
const DORME := 290.0
const BUSSOLA := 600.0
const NIVEL_CHEFE := 15  # como na onda 15 da Fundição: pula, esquiva e salta contra quem paira
const NIVEL_ESCOLTA := 8
const RESISTENCIA := 1.6

static var vencidos: Array = []
static var na_bussola: Array = []  # [posição, nome] das tocas com o chefe de pé

var mapa: Vale
var armadura: Armadura
var hud: Hud
var tocas := {}  # id -> {centro, chefe, escolta, no}
var retratos := {}  # id -> ViewportTexture (o quadro da base usa)

var _t := 0.0


func _ready() -> void:
	if Guardado.ativo:
		vencidos = (Guardado.progresso("procurados") as Array).duplicate()
	var k := 0
	for d: Dictionary in LISTA:
		_montar(d, k)
		_retrato(d, k)
		k += 1
	_bussola()


static func dado(id: String) -> Dictionary:
	for d: Dictionary in LISTA:
		if d["id"] == id:
			return d
	return {}


func _chao(p: Vector2, busca: float) -> Vector3:
	for r: float in [0.0, busca * 0.33, busca * 0.66, busca]:
		for a in 8:
			var q: Vector2 = p + Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0)) * r
			if mapa.agua(q.x, q.y) == -INF and mapa.normal_em(q.x, q.y).y > 0.93:
				return Vector3(q.x, mapa.altura(q.x, q.y), q.y)
	return Vector3(p.x, mapa.altura(p.x, p.y), p.y)


# ---------------------------------------------------------------- a toca

func _montar(d: Dictionary, k: int) -> void:
	var id: String = d["id"]
	var c := _chao(d["pos"], 40.0)
	var no := Node3D.new()
	no.name = "Toca_" + id
	add_child(no)
	no.global_position = c
	var toca := {"centro": c, "no": no, "escolta": []}
	tocas[id] = toca
	var vencido := vencidos.has(id)
	# o tablado redondo do chefe e as colunas em volta
	_objeto(no, "Platform_Round1", c + Vector3(0, 0.08, 0), 0.0, 2.2, false)
	for i in 5:
		var a := i * TAU / 5.0 + 0.3 * k
		var p := c + Vector3(cos(a) * 9.5, 0.0, sin(a) * 9.5)
		p.y = mapa.altura(p.x, p.z) - 0.2
		_objeto(no, "Column_Pipes", p, a, 1.0 + 0.12 * (i % 2), true)
	var chefe := Mecha.new()
	chefe.mapa = mapa
	chefe.alvo = armadura
	chefe.casa = c + Vector3(0, 0.45, 0)
	chefe.semente = 950 + k
	chefe.chefe = true
	chefe.modelo_forcado = id
	chefe.onda_nivel = NIVEL_CHEFE
	chefe.resistencia = RESISTENCIA
	chefe.impacto_desliga = false
	add_child(chefe)
	toca["chefe"] = chefe
	chefe.desligou.connect(_vencer.bind(id))
	for i in int(d["escolta"]):
		var a := i * TAU / float(d["escolta"]) + 0.8
		var casa := c + Vector3(cos(a) * 7.0, 0.0, sin(a) * 7.0)
		casa.y = mapa.altura(casa.x, casa.z)
		var mc := Mecha.new()
		mc.mapa = mapa
		mc.alvo = armadura
		mc.casa = casa
		mc.semente = 960 + k * 10 + i
		mc.onda_nivel = NIVEL_ESCOLTA
		add_child(mc)
		(toca["escolta"] as Array).append(mc)
		mc.desligou.connect(_ajudante_caiu.bind(id, mc))
	if vencido:
		for mc: Mecha in _todos(id):
			_dormir.call_deferred(mc, true)


func _todos(id: String) -> Array:
	var l: Array = [tocas[id]["chefe"]]
	l.append_array(tocas[id]["escolta"])
	return l


func _objeto(pai: Node3D, nome: String, pe: Vector3, giro: float, esc: float, colide: bool) -> void:
	var cena: PackedScene = load(BaseVale.PASTA + nome + ".gltf")
	if cena == null:
		return
	var raiz := cena.instantiate() as Node3D
	var caixa := BaseVale._caixa(raiz)
	var no := Node3D.new()
	no.add_child(raiz)
	raiz.position = -Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
	pai.add_child(no)
	no.global_transform = Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * esc), pe)
	BaseVale.vestir(raiz, 0.8, 0.45, mapa._tex)
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var cx := BoxShape3D.new()
	cx.size = caixa.size * esc
	forma.shape = cx
	corpo.add_child(forma)
	pai.add_child(corpo)
	corpo.global_transform = Transform3D(Basis(Vector3.UP, giro), pe + Vector3(0, caixa.size.y * esc * 0.5, 0))
	if not colide:
		corpo.collision_layer = 1


# ---------------------------------------------------------------- o retrato (para o quadro da base)

## Um mundo à parte, só com o chefe, uma luz e uma câmera: tira o retrato uma vez.
func _retrato(d: Dictionary, k: int) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 320)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.74, 0.58)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.ambient_light_energy = 0.6
	amb.environment = env
	vp.add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(-0.7, 0.5, 0)
	sol.light_energy = 1.3
	vp.add_child(sol)
	InimigoVisual.forcar_modelo = String(d["id"])
	var v := InimigoVisual.montar(950 + k, 2.8, mapa._tex, true)
	InimigoVisual.forcar_modelo = ""
	vp.add_child(v)
	var alto: float = v.altura
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.position = Vector3(0.0, alto * 0.62, alto * 2.15)
	cam.look_at(Vector3(0, alto * 0.55, 0))
	v.rotation.y = PI + 0.45  # o modelo olha para -Z: meia volta para ficar de frente (de três quartos) para a câmera
	retratos[d["id"]] = vp.get_texture()
	# o modelo leva alguns quadros para ficar de pé (a pose de parado): só então tira a foto
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE)


# ---------------------------------------------------------------- vencer

func _vencer(id: String) -> void:
	if vencidos.has(id):
		return
	vencidos.append(id)
	if Guardado.ativo:
		Guardado.por_progresso("procurados", vencidos)
	for mc: Mecha in _todos(id):
		_dormir(mc, false)
	var d := dado(id)
	var peca: String = d["peca"]
	Melhorias.achar(peca)
	var c: Vector3 = tocas[id]["centro"]
	var chefe: Mecha = tocas[id]["chefe"]
	Som.toque3d(self, "onda_vencida", c + Vector3(0, 2, 0), 0.0)
	if hud:
		hud.avisar(String(d["nome"]) + " vencido!", "peça nova: " + String(Melhorias.TITULOS[peca]).to_lower() + " · instale na base · o retrato no quadro ganhou o visto")
	# o prêmio de um chefe da Fundição na onda dele (a peça vem por cima)
	if not Espolio.premiar(self, chefe.global_position, Arsenal.premio(true, NIVEL_CHEFE, chefe.semente), armadura, hud):
		EfeitosTiro.aura_nivel(armadura, armadura.altura_corpo())
	_bussola()
	venceu.emit(id)


## Um ajudante desligado rende como uma máquina da Fundição no nível dele (os que dormem com o chefe vencido,
## não).
func _ajudante_caiu(id: String, mc: Mecha) -> void:
	if mc.para_sempre or vencidos.has(id):
		return
	Espolio.premiar(self, mc.global_position, Arsenal.premio(false, NIVEL_ESCOLTA, mc.semente), armadura, hud)


func _dormir(mc: Mecha, ja_estava: bool) -> void:
	if not is_instance_valid(mc):
		return
	mc.para_sempre = true
	if not mc.desligada:
		mc.desligar()
	if ja_estava:
		mc._fumaca.emitting = false
	else:
		get_tree().create_timer(8.0).timeout.connect(func() -> void:
			if is_instance_valid(mc):
				mc._fumaca.emitting = false)


func _bussola() -> void:
	na_bussola.clear()
	for d: Dictionary in LISTA:
		if not vencidos.has(d["id"]) and tocas.has(d["id"]):
			na_bussola.append([tocas[d["id"]]["centro"], d["nome"]])


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.4 or armadura == null:
		return
	_t = 0.0
	var a := armadura.global_position
	for id: String in tocas:
		var c: Vector3 = tocas[id]["centro"]
		var d := Vector2(c.x - a.x, c.z - a.z).length()
		for mc: Mecha in _todos(id):
			if mc.process_mode == Node.PROCESS_MODE_DISABLED and d < ACORDA:
				mc.process_mode = Node.PROCESS_MODE_INHERIT
			elif mc.process_mode != Node.PROCESS_MODE_DISABLED and d > DORME:
				mc.process_mode = Node.PROCESS_MODE_DISABLED
