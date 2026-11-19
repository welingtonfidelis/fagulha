class_name Tutor
extends Control
## As lições da simulação: uma de cada vez, no alto da tela, com a imagem do botão (Botoes) e uma frase curta.
## A lição só passa quando o jogador faz o que ela pede. Quem cria passa `armadura`, `camera` e `mapa`.
## O trecho obrigatório é a sequência "basico" (olhar, andar, correr, pular, decolar, voar, o calor e pousar).
## Depois vem o treino livre: três círculos no chão (básico, voo, combate); entrar num deles começa aquela
## sequência. No treino livre o robô tem todas as peças e armas, só dentro da simulação.

const TINTA := Color(0.93, 0.96, 0.95)
const APAGADO := Color(0.62, 0.7, 0.69)
const AGUA := Color(0.35, 0.95, 0.85)
const LARANJA := Color(1.0, 0.62, 0.3)
# cada lição: [chave, os botões (texto com imagens), a frase]
const SEQUENCIAS := {
	"basico": [
		["olhar", "{olhar}", "Olhe em volta"],
		["andar", "{mover}", "Ande até o aro"],
		["correr", "{correr}  +  {mover}", "Corra até o aro"],
		["pular", "{pular}   {pular}", "Pule, e pule de novo no ar"],
		["decolar", "segure  {pular}", "Segure para decolar"],
		["voar", "{mover}  {olhar}", "Voe por dentro dos três aros"],
		["calor", "", "O motor esquenta voando. Olhe o arco em volta da mira"],
		["pousar", "{pular}", "Um toque desliga os jatos. Pouse para esfriar"],
	],
	"voo": [
		["decolar", "segure  {pular}", "Decole"],
		["pairar", "{pairar}", "Voando, pare no ar"],
		["arrancada", "{correr}", "Voando, dê uma arrancada"],
		["manobra", "{soltar}", "Voando, gire para o lado"],
		["planar", "segure  {voar}", "Voando, segure para abrir as asas"],
		["mergulho", "{golpe}", "Do alto, mergulhe até o chão"],
	],
	"combate": [
		["mirar", "{mirar}", "Segure para mirar"],
		["atirar", "{mirar}  +  {atirar}", "Acerte os três alvos"],
		["arma", "{roda}", "Um toque troca de arma"],
		["granada", "segure e solte  {granada}", "Jogue uma granada"],
		["espada", "{espada}", "No chão, a espada"],
		["esquiva", "{soltar}", "No chão, esquive"],
	],
}
const LICOES: Array = SEQUENCIAS["basico"]
# os círculos do treino livre: [sequência, o nome escrito, a imagem]
const POSTOS := [["basico", "BÁSICO", "x"], ["voo", "VOO", "l3"], ["combate", "COMBATE", "r2"]]

var armadura: Armadura
var camera: CameraVoo
var mapa: SimMapa
var tiro: Tiro
var seq := "basico"  # a sequência em curso ("" no treino livre)
var licao := 0
var feitas := 0  # lições concluídas (testes)
var acabou := false  # o trecho obrigatório já foi feito (agora ou numa visita anterior)
var livre_de_cara := false  # quem cria: começar no treino livre (voltou à simulação pela pausa)
var equipado := false
var alvos: Array[AlvoTreino] = []

var _fonte: Font
var _t := 0.0  # tempo na lição
var _ok_t := -1.0  # a lição acabou de passar: mostra o "feito" por um instante
var _yaw0 := 0.0
var _giro := 0.0
var _pulos := 0
var _estado_ant := -1
var _aros: Array[Node3D] = []
var _aro_atual := 0
var _trocas := -1
var _voou := false
var _postos: Array[Node3D] = []
var _dentro := ""  # o círculo em que o robô está pisando (para não recomeçar sem sair)
var _conta0 := 0
var _modo0 := ""
var _mergulhou := false


func _ready() -> void:
	_fonte = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # para sumir quando a pausa abre
	armadura.golpe_chao.connect(func(_onde: Vector3) -> void: _mergulhou = true)
	if livre_de_cara:
		acabou = true
		_livre()
	else:
		_comecar()


func chave() -> String:
	return "" if seq == "" else String((SEQUENCIAS[seq] as Array)[licao][0])


## Na simulação o robô tem tudo, para treinar: as peças, as armas e a munição. Nada disso vai para o save.
func equipar() -> void:
	if equipado:
		return
	equipado = true
	Melhorias.tudo = true
	Arsenal.tudo = true
	Arsenal.fabricados = ["rajada", "canhao", "precisao", "duplo", "granadas", "misseis", "escudo", "mira"]
	Arsenal.repor_granadas()
	if armadura.visual:
		armadura.visual.vestir_melhorias()


## Treino livre: os três círculos em volta do robô.
func _livre() -> void:
	seq = ""
	licao = 0
	_limpar_aros()
	_limpar_alvos()
	equipar()
	for p in _postos:
		p.queue_free()
	_postos = []
	var yaw := camera.yaw if camera else 0.0
	var k := 0
	for posto: Array in POSTOS:
		var ang := yaw + deg_to_rad([-42.0, 0.0, 42.0][k])
		var no := Node3D.new()
		no.position = armadura.global_position * Vector3(1, 0, 1) + Vector3(-sin(ang), 0, -cos(ang)) * 13.0
		no.set_meta("seq", posto[0])
		var disco := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 2.4
		cil.bottom_radius = 2.4
		cil.height = 0.08
		disco.mesh = cil
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(LARANJA.r, LARANJA.g, LARANJA.b, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disco.material_override = mat
		disco.position.y = 0.05
		no.add_child(disco)
		var figura := Sprite3D.new()
		figura.texture = Botoes.textura(posto[2])
		figura.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		figura.pixel_size = 0.014
		figura.position.y = 3.3
		figura.shaded = false
		no.add_child(figura)
		var nome := Label3D.new()
		nome.text = posto[1]
		nome.font_size = 96
		nome.pixel_size = 0.008
		nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nome.modulate = TINTA
		nome.outline_size = 28
		nome.outline_modulate = Color(0.03, 0.07, 0.08)
		nome.position.y = 1.9
		no.add_child(nome)
		mapa.add_child(no)
		_postos.append(no)
		k += 1
	_dentro = "?"  # só vale depois de o robô estar fora de todos


func _iniciar(nome: String) -> void:
	for p in _postos:
		p.queue_free()
	_postos = []
	seq = nome
	licao = 0
	_comecar()


func _limpar_alvos() -> void:
	for al in alvos:
		if is_instance_valid(al):
			al.queue_free()
	alvos = []


func _por_alvos() -> void:
	_limpar_alvos()
	var yaw := camera.yaw if camera else 0.0
	var frente := Vector3(-sin(yaw), 0, -cos(yaw))
	var lado := Vector3(-frente.z, 0, frente.x)
	for k in 3:
		var al := AlvoTreino.new()
		al.position = armadura.global_position * Vector3(1, 0, 1) + frente * (24.0 + k * 4.0) + lado * (k - 1) * 9.0 + Vector3(0, 2.6 + k * 1.2, 0)
		mapa.add_child(al)
		alvos.append(al)


func _comecar() -> void:
	_t = 0.0
	_pulos = 0
	_giro = 0.0
	_voou = false
	_yaw0 = camera.yaw if camera else 0.0
	_limpar_aros()
	match chave():
		"andar":
			_por_aros([8.0], 0.0)
		"correr":
			_por_aros([26.0], 0.0)
		"voar":
			_por_aros([45.0, 100.0, 160.0], 9.0)
		"atirar":
			_por_alvos()
		"arma":
			_modo0 = Arsenal.modo
		"granada":
			Arsenal.repor_granadas()
			_conta0 = tiro.granadas_jogadas if tiro else 0
		"espada":
			_conta0 = tiro.golpes_espada if tiro else 0
		"manobra":
			_conta0 = armadura.manobras
		"mergulho":
			_mergulhou = false


func _limpar_aros() -> void:
	for a in _aros:
		if is_instance_valid(a):
			a.queue_free()
	_aros = []
	_aro_atual = 0


## Aros de luz à frente da câmera: `dists` em metros, a `alt` metros do chão (0: de pé no chão).
func _por_aros(dists: Array, alt: float) -> void:
	var frente := Vector3(-sin(camera.yaw), 0, -cos(camera.yaw)) if camera else Vector3.FORWARD
	var k := 0
	for d: float in dists:
		var aro := MeshInstance3D.new()
		var toro := TorusMesh.new()
		var raio := 1.6 if alt <= 0.0 else 5.0
		toro.inner_radius = raio * 0.86
		toro.outer_radius = raio
		toro.rings = 48
		aro.mesh = toro
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = LARANJA if k == 0 else AGUA
		aro.material_override = mat
		aro.set_meta("raio", raio)
		# um pouco de lado a cada aro, para o jogador ter de virar
		var desvio: float = 0.0 if alt <= 0.0 else [0.0, 14.0, -10.0][k % 3]
		var lado := Vector3(-frente.z, 0, frente.x) * desvio
		aro.position = armadura.global_position * Vector3(1, 0, 1) + frente * d + lado + Vector3(0, raio * 0.9 if alt <= 0.0 else alt + k * 4.0, 0)
		aro.look_at_from_position(aro.position, aro.position + frente, Vector3.UP)
		aro.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		mapa.add_child(aro)
		_aros.append(aro)
		k += 1


## O robô passou por dentro do aro da vez?
func _passou_aro() -> bool:
	if _aro_atual >= _aros.size():
		return true
	var aro := _aros[_aro_atual]
	var p := armadura.global_position + Vector3(0, armadura.altura_corpo() * 0.5, 0)
	if p.distance_to(aro.position) < float(aro.get_meta("raio")) + 0.6:
		aro.queue_free()
		_aro_atual += 1
		if _aro_atual < _aros.size():
			((_aros[_aro_atual] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = LARANJA
		return _aro_atual >= _aros.size()
	return false


func _process(delta: float) -> void:
	visible = not get_tree().paused
	if not visible:
		return
	queue_redraw()
	if armadura == null:
		return
	if seq == "":
		_ver_postos()
		return
	if _ok_t >= 0.0:
		_ok_t += delta
		if _ok_t >= 0.9:
			_ok_t = -1.0
			licao += 1
			if licao >= (SEQUENCIAS[seq] as Array).size():
				acabou = true
				_livre()
			else:
				_comecar()
		return
	_t += delta
	var e := armadura.estado
	var no_ar: bool = e in [Armadura.Estado.VOO, Armadura.Estado.PLANAR, Armadura.Estado.PAIRAR]
	var feito := false
	match chave():
		"olhar":
			_giro += absf(wrapf(camera.yaw - _yaw0, -PI, PI))
			_yaw0 = camera.yaw
			feito = _giro > 2.2
		"andar":
			feito = _passou_aro()
		"correr":
			# só vale passar pelo aro correndo (andando, o aro espera)
			if Vector2(armadura.velocity.x, armadura.velocity.z).length() > Ajustes.ANDAR * Armadura.vel_chao * 1.5:
				feito = _passou_aro()
		"pular":
			if e == Armadura.Estado.AR and _estado_ant == Armadura.Estado.CHAO:
				_pulos = 1
			if _pulos >= 1 and e == Armadura.Estado.AR and Input.is_action_just_pressed("pular") and _estado_ant == Armadura.Estado.AR:
				_pulos = 2
			feito = _pulos >= 2 and e == Armadura.Estado.CHAO
		"decolar":
			feito = e == Armadura.Estado.VOO
		"voar":
			feito = _passou_aro()
		"calor":
			feito = armadura.calor >= 45.0 or _t > 14.0
		"pousar":
			feito = e == Armadura.Estado.CHAO and armadura.is_on_floor() and _t > 0.5
		"pairar":
			feito = e == Armadura.Estado.PAIRAR and _t > 0.4
		"arrancada":
			feito = e == Armadura.Estado.VOO and armadura.arrancada
		"manobra":
			feito = armadura.manobras > _conta0
		"planar":
			feito = e == Armadura.Estado.PLANAR
		"mergulho":
			feito = _mergulhou
		"mirar":
			feito = armadura.mirando and _t > 0.8
		"atirar":
			var desligados := 0
			for al in alvos:
				if is_instance_valid(al) and al.desligamentos > 0:
					desligados += 1
			feito = not alvos.is_empty() and desligados >= alvos.size()
		"arma":
			feito = Arsenal.modo != _modo0
		"granada":
			feito = tiro != null and tiro.granadas_jogadas > _conta0
		"espada":
			feito = tiro != null and tiro.golpes_espada > _conta0
		"esquiva":
			feito = armadura.esquivando > 0.0 and not no_ar
	_estado_ant = e
	if feito:
		feitas += 1
		_ok_t = 0.0


## No treino livre: pisar num círculo começa a sequência dele.
func _ver_postos() -> void:
	var p := armadura.global_position * Vector3(1, 0, 1)
	var em := ""
	for posto in _postos:
		if p.distance_to(posto.position) < 2.4 and armadura.global_position.y < 2.5:
			em = String(posto.get_meta("seq"))
	if _dentro == "?":
		_dentro = em
		return
	if em != "" and em != _dentro:
		_iniciar(em)
		return
	_dentro = em


func _draw() -> void:
	var meio := size.x * 0.5
	var y := 86.0
	# o cartão: grande, para quem ainda não lê achar o botão de longe
	var larg := 760.0
	draw_rect(Rect2(meio - larg * 0.5, y - 50.0, larg, 168.0), Color(0.03, 0.06, 0.07, 0.74))
	draw_rect(Rect2(meio - larg * 0.5, y - 50.0, larg, 3.0), Color(AGUA.r, AGUA.g, AGUA.b, 0.7))
	if seq == "":
		var linha1 := "Treino livre: entre num círculo"
		var w1 := _fonte.get_string_size(linha1, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(_fonte, Vector2(meio - w1 * 0.5, y + 18.0), linha1, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TINTA)
		var fim := "Acordar e ir para a ilha:  {menu}"
		var wf := Botoes.largura(fim, _fonte, 22)
		Botoes.desenhar(self, _fonte, Vector2(meio - wf * 0.5, y + 78.0), fim, 22, APAGADO)
		return
	var licoes: Array = SEQUENCIAS[seq]
	# as bolinhas das lições
	var n := licoes.size()
	for k in n:
		var cx := meio - (n - 1) * 11.0 + k * 22.0
		var cor := AGUA if k < licao else (LARANJA if k == licao else Color(1, 1, 1, 0.25))
		draw_circle(Vector2(cx, y - 28.0), 6.0 if k == licao else 4.5, cor)
	var botoes := String(licoes[licao][1])
	var frase := String(licoes[licao][2])
	if _ok_t >= 0.0:
		botoes = ""
		frase = "Isso!"
	if botoes != "":
		var wb := Botoes.largura(botoes, _fonte, 44)
		Botoes.desenhar(self, _fonte, Vector2(meio - wb * 0.5, y + 38.0), botoes, 44, TINTA)
	var tam := 24 if botoes != "" else 26
	var wt := _fonte.get_string_size(frase, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_string(_fonte, Vector2(meio - wt * 0.5, y + (96.0 if botoes != "" else 50.0)), frase, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, AGUA if _ok_t >= 0.0 else TINTA)
