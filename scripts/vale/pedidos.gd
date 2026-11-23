class_name Pedidos
extends CanvasLayer
## Os pedidos do drone (1.1, doc §136): três tarefas curtas no quadro de avisos da base, só com figura e uma
## conta pequena ("1/3"). Feita, o cartão fica verde e o prêmio vem na hora (experiência e sucata; liberar um
## acampamento dá também um chip). Cinco minutos depois o cartão verde troca por outro pedido, de um tipo
## que não está no quadro. Fora da base, quando um pedido anda, aparece embaixo à direita a figura e a conta,
## por um instante. Os cartões ficam guardados.
## Quem cria passa `quadro`, `armadura`, `hud`, `rotas`, `scanner`, `horta` e `acampamentos`.

const TROCA := 300.0  # s com o cartão verde antes de trocar
const TIPOS := {
	"desligar": {"icone": "maquina", "cor": Color(1.0, 0.42, 0.32), "alvo": [3, 5], "xp": 70, "sucata": 3},
	"rota": {"icone": "aro", "cor": Color(1.0, 0.62, 0.3), "alvo": [1, 1], "xp": 60, "sucata": 2},
	"foto": {"icone": "pata", "cor": Color(0.4, 0.75, 0.35), "alvo": [2, 3], "xp": 50, "sucata": 2},
	"escanear": {"icone": "scanner", "cor": Color(0.2, 0.7, 0.65), "alvo": [2, 3], "xp": 50, "sucata": 2},
	"golpe": {"icone": "impacto", "cor": Color(0.9, 0.6, 0.15), "alvo": [3, 4], "xp": 50, "sucata": 2},
	"semente": {"icone": "semente", "cor": Color(0.35, 0.7, 0.3), "alvo": [1, 1], "xp": 60, "sucata": 2},
	"acampamento": {"icone": "farolete", "cor": Color(0.9, 0.25, 0.2), "alvo": [1, 1], "xp": 120, "sucata": 4, "chips": 1},
}

var quadro: QuadroAvisos
var armadura: Armadura
var hud: Hud
var rotas: Rotas
var scanner: Scanner
var horta: Horta
var acampamentos: Acampamentos
var cartoes: Array = []  # [{tipo, alvo, conta, feito_ha (-1 = falta)}]
var feitos := 0  # pedidos feitos nesta partida (testes)

var _rng := RandomNumberGenerator.new()
var _ultimo := {}  # tipo -> o último valor lido do contador
var _golpes := 0
var _t_guardar := 0.0
var _toque: Control
var _toque_tipo := ""
var _toque_texto := ""
var _toque_t := 0.0


func _ready() -> void:
	layer = 5
	_rng.randomize()
	if Guardado.ativo:
		var g: Dictionary = Guardado.progresso("pedidos")
		for c: Dictionary in g.get("cartoes", []):
			if TIPOS.has(String(c.get("tipo", ""))):
				cartoes.append({"tipo": String(c["tipo"]), "alvo": int(c["alvo"]), "conta": int(c["conta"]), "feito_ha": float(c["feito_ha"])})
	while cartoes.size() < 3:
		cartoes.append(_novo())
	if armadura:
		armadura.golpe_chao.connect(func(_onde: Vector3) -> void: _golpes += 1)
	for tipo: String in TIPOS:
		_ultimo[tipo] = _valor(tipo)
	_toque = Control.new()
	_toque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toque.draw.connect(_desenhar_toque)
	add_child(_toque)
	_mostrar.call_deferred()
	_guardar()


func _guardar() -> void:
	if Guardado.ativo:
		Guardado.por_progresso("pedidos", {"cartoes": cartoes})


## O contador de cada tipo de pedido (só cresce; o pedido soma o quanto andou desde a última leitura).
func _valor(tipo: String) -> int:
	match tipo:
		"desligar":
			return MaquinaPequena.total_desligadas
		"rota":
			return rotas.concluidas if rotas else 0
		"foto":
			return Album.fotos_bichos
		"escanear":
			return scanner.leituras if scanner else 0
		"golpe":
			return _golpes
		"semente":
			return horta.achadas.size() if horta else 0
		"acampamento":
			return Acampamentos.livres.size()
	return 0


## Um tipo ainda serve? (sem scanner não há leitura; sementes e acampamentos acabam)
func _serve(tipo: String) -> bool:
	match tipo:
		"escanear":
			return Melhorias.tem("scanner")
		"semente":
			return horta != null and horta.achadas.size() < Horta.ILHA.size() + Acampamentos.LISTA.size()
		"acampamento":
			return Acampamentos.livres.size() < Acampamentos.LISTA.size()
	return true


func _novo() -> Dictionary:
	var em_uso: Array = []
	for c: Dictionary in cartoes:
		if c.has("tipo"):  # o cartão que está sendo trocado fica vazio (o novo não repete o tipo dele)
			em_uso.append(c["tipo"])
	var livres: Array = []
	for tipo: String in TIPOS:
		if not em_uso.has(tipo) and _serve(tipo):
			livres.append(tipo)
	if livres.is_empty():
		livres = ["desligar"]
	var tipo: String = livres[_rng.randi() % livres.size()]
	var faixa: Array = TIPOS[tipo]["alvo"]
	return {"tipo": tipo, "alvo": _rng.randi_range(int(faixa[0]), int(faixa[1])), "conta": 0, "feito_ha": -1.0}


func _process(delta: float) -> void:
	_toque_t = maxf(0.0, _toque_t - delta)
	if _toque_t > 0.0 or _toque_tipo != "":
		_toque.queue_redraw()
	var mudou := false
	for tipo: String in TIPOS:
		var agora := _valor(tipo)
		var anda := agora - int(_ultimo[tipo])
		_ultimo[tipo] = agora
		if anda <= 0:
			continue
		for i in cartoes.size():
			var c: Dictionary = cartoes[i]
			if c["tipo"] != tipo or float(c["feito_ha"]) >= 0.0:
				continue
			c["conta"] = mini(int(c["alvo"]), int(c["conta"]) + anda)
			mudou = true
			if int(c["conta"]) >= int(c["alvo"]):
				_feito(i)
			else:
				_avisar_toque(tipo, "%d/%d" % [c["conta"], c["alvo"]])
	# o verde fica um tempo no quadro; depois troca
	for i in cartoes.size():
		var c: Dictionary = cartoes[i]
		if float(c["feito_ha"]) >= 0.0:
			c["feito_ha"] = float(c["feito_ha"]) + delta
			if float(c["feito_ha"]) > TROCA:
				cartoes[i] = {}
				cartoes[i] = _novo()
				mudou = true
	_t_guardar += delta
	if mudou:
		_mostrar()
	if mudou or _t_guardar > 30.0:
		_t_guardar = 0.0
		_guardar()


func _feito(i: int) -> void:
	var c: Dictionary = cartoes[i]
	c["feito_ha"] = 0.0
	feitos += 1
	var d: Dictionary = TIPOS[c["tipo"]]
	var nivel_antes := Arsenal.nivel()
	Arsenal.xp += int(d["xp"])
	Arsenal.sucata += int(d["sucata"])
	Arsenal.chips += int(d.get("chips", 0))
	Arsenal.guardar()
	_ultimo["acampamento"] = _valor("acampamento")
	_avisar_toque(String(c["tipo"]), "feito!")
	if hud:
		var premio := "+%d de experiência · +%d sucata" % [d["xp"], d["sucata"]]
		if int(d.get("chips", 0)) > 0:
			premio += " · +1 chip"
		hud.avisar("Pedido do drone feito!", premio)
	if armadura:
		Som.toque3d(self, "fabricou", armadura.global_position + Vector3(0, 1, 0), -6.0)
	if is_instance_valid(Experiencia.atual):
		Experiencia.atual.festejar(nivel_antes)  # a aura, o som e o cartão do nível (doc §148)


func _mostrar() -> void:
	if quadro == null:
		return
	for i in 3:
		if i >= cartoes.size():
			quadro.por_pedido(i, "", Color.WHITE, "", false)
			continue
		var c: Dictionary = cartoes[i]
		var d: Dictionary = TIPOS[c["tipo"]]
		var feito := float(c["feito_ha"]) >= 0.0
		quadro.por_pedido(i, String(d["icone"]), d["cor"], "%d/%d" % [c["conta"], c["alvo"]], feito)


# ---------------------------------------------------------------- o aviso pequeno, embaixo à direita

func _avisar_toque(tipo: String, texto: String) -> void:
	_toque_tipo = tipo
	_toque_texto = texto
	_toque_t = 3.0


func _desenhar_toque() -> void:
	if _toque_t <= 0.0:
		_toque_tipo = ""
		return
	var a := clampf(_toque_t / 0.5, 0.0, 1.0)
	var tela := _toque.get_viewport_rect().size
	var r := Rect2(tela.x - 210.0, tela.y - 190.0, 170.0, 64.0)
	_toque.draw_rect(r, Color(0.03, 0.06, 0.07, 0.72 * a))
	var d: Dictionary = TIPOS[_toque_tipo]
	var cor: Color = (d["cor"] as Color).lightened(0.35)
	cor.a = a
	Icones.desenhar(_toque, String(d["icone"]), r.position + Vector2(34, 32), 1.45, cor, 2.4)
	_toque.draw_string(ThemeDB.fallback_font, r.position + Vector2(66, 42), _toque_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.95, 0.9, a))
