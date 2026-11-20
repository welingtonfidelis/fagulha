class_name RoboAntigo
extends Node3D
## Os robôs que se acham no vale e passam a ficar guardados nos cilindros da base (2026-11-19).
##  - **o anterior** (`robo_v1.glb`, o robô de peças de antes): desligado, sentado no chão dentro do
##    Observatório, olhando para cima. Era o lugar de que ele gostava.
##  - **o mergulhador** (`robo_v3.glb`): no fundo da lagoa da Represa, ao pé da parede, segurando a comporta.
##    A água sai dali com força: só o nado rápido **com as barbatanas** vence a correnteza.
## Chegando perto e apertando o botão de agir, aparece a lembrança do robô e o drone o leva para a base.
## Cada um tem o cilindro dele; o terceiro cilindro guarda o robô novo quando outro está em uso. Perto de um
## cilindro com robô, "trocar de robô" veste aquele. Muda só o visual (o anterior atira pelos jatos das mãos).
## Quem cria passa `armadura`, `hud`, `memorias`, `pecas` e `cilindros`.

const V1 := "res://assets/vale/robo_v1.glb"
const V2 := "res://assets/vale/robo_v2.glb"
const V3 := "res://assets/vale/robo_v3.glb"
## [chave no save, modelo, lembrança]
const ROBOS := [["robo_antigo", V1, "robo_antigo"], ["robo_mergulhador", V3, "robo_mergulhador"]]
const PERTO := 3.0
const PERTO_CILINDRO := 1.9
const VAGA := 0  # o cilindro do robô anterior (o do mergulhador é o 1 e o do robô novo, o 2)
const VAGA_NOVO := 2
# a correnteza da comporta
const CORRENTE := 11.6  # m/s: entre o nado rápido sem as barbatanas (10,1) e com elas (13)
const CORRENTE_CHEIA := 15.0  # até essa distância ela vale inteira
const CORRENTE_RAIO := 24.0  # e some até aqui

var armadura: Armadura
var hud: Hud
var memorias: Memorias
var pecas: PecasMundo
var cilindros: CilindrosBase
var achados: Array[bool] = [false, false]
var em_uso := 0  # 0 o robô novo, 1 o anterior, 2 o mergulhador
var trocas := 0  # testes
var estatuas: Array[Node3D] = [null, null]  # cada robô no lugar dele, enquanto não foi achado
var guardados: Array[Node3D] = [null, null, null]  # o robô dentro de cada cilindro
var comporta := Vector3.INF  # no mundo: de onde a correnteza sai
var _dica_minha := ""
var _nadando_t := 0.0  # há quanto tempo o robô nada sem parar (quem cai do ar em cima da comporta ainda não conta)

# o robô anterior, pelos nomes de antes (os testes e as fotos usam)
var achado: bool:
	get:
		return achados[0]
var estatua: Node3D:
	get:
		return estatuas[0]
var guardado_no: Node3D:
	get:
		return guardados[0]


func _ready() -> void:
	if Guardado.ativo:
		for k in ROBOS.size():
			achados[k] = bool(Guardado.progresso(ROBOS[k][0]))
		em_uso = int(Guardado.progresso("robo_em_uso"))
		if em_uso > 0 and not achados[em_uso - 1]:
			em_uso = 0
	for i in 5:
		await get_tree().physics_frame
	if em_uso > 0:
		armadura.trocar_modelo(ROBOS[em_uso - 1][1])
	if not achados[0]:
		_por_no_observatorio()
	_por_na_represa()
	_por_guardados()


func _pose(cena: Node3D, pose: Dictionary, desce := 0.0) -> void:
	for nome: String in pose:
		var no := cena.find_child(nome, true, false) as Node3D
		if no:
			var g: Vector3 = pose[nome]
			no.rotation = Vector3(deg_to_rad(g.x), deg_to_rad(g.y), deg_to_rad(g.z))
	var raiz := cena.find_child("raiz", true, false) as Node3D
	if raiz:
		raiz.position.y -= desce


## O robô anterior sentado no chão, dentro do Observatório, ao lado do pedestal do telescópio: virado para a
## fenda (ao norte), de cabeça erguida para o céu que se vê por ela.
func _por_no_observatorio() -> void:
	var ob := MarcosOeste.OBSERVATORIO
	var piso: float = pecas.mapa._fora(ob.x, ob.y) + 0.2  # o tampo do piso de concreto da cúpula
	var lugar := Vector3(ob.x + MarcosOeste.CUPULA * 0.38, piso, ob.y + MarcosOeste.CUPULA * 0.42)
	var e := Node3D.new()
	e.position = lugar
	add_child(e)
	estatuas[0] = e
	var cena := (load(V1) as PackedScene).instantiate() as Node3D
	e.add_child(cena)
	var para := Vector2(ob.x - lugar.x, (ob.y - MarcosOeste.CUPULA) - lugar.z)
	cena.rotation.y = atan2(para.x, para.y)
	_apagar(cena)
	_pose(cena, {"quadrilE": Vector3(-88, 0, 10), "quadrilD": Vector3(-88, 0, -10), "joelhoE": Vector3(8, 0, 0), "joelhoD": Vector3(8, 0, 0),
		"tronco": Vector3(-10, 0, 0), "cabeca": Vector3(-34, 0, 0), "ombroE": Vector3(24, 0, 12), "ombroD": Vector3(24, 0, -12),
		"cotoveloE": Vector3(-14, 0, 0), "cotoveloD": Vector3(-14, 0, 0)}, 0.40)


## A comporta do fundo da Represa, com a correnteza, e o mergulhador segurando a roda dela (se ainda está lá).
func _por_na_represa() -> void:
	var v := pecas.mapa
	# o ponto mais fundo ao pé da parede, do lado da lagoa
	var x := 0.0
	var z := 0.0
	var fundo := INF
	for dz: float in [-30.0, -22.0, -14.0, -6.0, 6.0, 14.0, 22.0, 30.0]:
		for dx: float in [7.0, 10.0, 14.0, 18.0]:
			var cx2 := MarcosLeste.represa_x(dz) - dx
			var cz2 := MarcosLeste.REPRESA.y + dz
			var f: float = v._fora(cx2, cz2)
			if f < fundo:
				fundo = f
				x = cx2
				z = cz2
	if Vale.REPRESA_NIVEL - fundo < 3.0:
		return  # raso demais ali (mapas de teste)
	comporta = Vector3(x + 2.2, fundo + 1.0, z)
	# a moldura da comporta e a roda, encostadas na parede
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.2, 0.14)
	mat.roughness = 0.9
	for dados: Array in [[Vector3(2.6, 1.3, -1.5), Vector3(0.5, 2.6, 0.5)], [Vector3(2.6, 1.3, 1.5), Vector3(0.5, 2.6, 0.5)], [Vector3(2.6, 2.8, 0.0), Vector3(0.6, 0.5, 3.6)]]:
		var mi := MeshInstance3D.new()
		var cx := BoxMesh.new()
		cx.size = dados[1]
		mi.mesh = cx
		mi.material_override = mat
		mi.position = Vector3(x, fundo, z) + (dados[0] as Vector3)
		add_child(mi)
	var roda := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.26
	toro.outer_radius = 0.34
	roda.mesh = toro
	roda.material_override = mat
	roda.position = Vector3(x + 0.55, fundo + 0.95, z)
	roda.rotation.z = PI * 0.5
	add_child(roda)
	# bolhas saindo da comporta para dentro da lagoa: é a correnteza que se vê
	var bolhas := CPUParticles3D.new()
	bolhas.amount = 70
	bolhas.lifetime = 2.6
	bolhas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bolhas.emission_box_extents = Vector3(0.3, 1.0, 1.4)
	bolhas.direction = Vector3(-1, 0.12, 0)
	bolhas.spread = 16.0
	bolhas.initial_velocity_min = 5.0
	bolhas.initial_velocity_max = 8.5
	bolhas.gravity = Vector3(0, 0.6, 0)
	bolhas.scale_amount_min = 0.5
	bolhas.scale_amount_max = 1.3
	var bola := SphereMesh.new()
	bola.radius = 0.07
	bola.height = 0.14
	bola.radial_segments = 6
	bola.rings = 3
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mb.albedo_color = Color(0.85, 0.97, 1.0, 0.55)
	bola.material = mb
	bolhas.mesh = bola
	bolhas.position = comporta
	add_child(bolhas)
	if achados[1]:
		return
	var e := Node3D.new()
	e.position = Vector3(x, fundo, z)
	add_child(e)
	estatuas[1] = e
	var cena := (load(V3) as PackedScene).instantiate() as Node3D
	e.add_child(cena)
	cena.rotation.y = -PI * 0.5  # de frente para a parede (para o leste), com as mãos na roda
	_apagar(cena)
	_pose(cena, {"ombroE": Vector3(-62, 0, -6), "ombroD": Vector3(-62, 0, 6), "cotoveloE": Vector3(-20, 0, 0), "cotoveloD": Vector3(-20, 0, 0),
		"tronco": Vector3(10, 0, 0), "cabeca": Vector3(8, 0, 0), "quadrilE": Vector3(-14, 0, 6), "quadrilD": Vector3(12, 0, -6),
		"joelhoE": Vector3(22, 0, 0), "joelhoD": Vector3(10, 0, 0), "dedosE": Vector3(100, 0, 0), "dedosD": Vector3(100, 0, 0)})


## Os robôs dentro dos cilindros: cada achado no dele, e o robô novo no terceiro quando outro está em uso.
func _por_guardados() -> void:
	if cilindros == null:
		return
	for k in guardados.size():
		if guardados[k] and is_instance_valid(guardados[k]):
			guardados[k].queue_free()
		guardados[k] = null
		if k >= cilindros.cilindros.size():
			continue
		var modelo := ""
		if k < ROBOS.size():
			if achados[k] and em_uso != k + 1:
				modelo = ROBOS[k][1]
		elif em_uso != 0:
			modelo = V2
		if modelo == "":
			continue
		var no := Node3D.new()
		no.position.y = 0.14
		cilindros.cilindros[k].add_child(no)
		var cena := (load(modelo) as PackedScene).instantiate() as Node3D
		no.add_child(cena)
		_apagar(cena)
		guardados[k] = no


## Apaga tudo o que brilha num modelo: as chamas somem e as peças com luz própria ficam escuras.
func _apagar(cena: Node) -> void:
	var escuro := StandardMaterial3D.new()
	escuro.albedo_color = Color(0.05, 0.06, 0.07)
	escuro.roughness = 0.5
	for mi: MeshInstance3D in cena.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).to_lower().begins_with("chama"):
			mi.visible = false
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat == null:
				continue
			var nome := String(mat.resource_name).to_lower()
			if nome == "chama":
				mi.visible = false
			elif nome in ["calor", "olhos", "viseira", "lamina"] or (mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled):
				mi.set_surface_override_material(s, escuro)


## O jogador acordou o robô `k`: a lembrança aparece e ele vai para a base.
func achar_robo(k: int) -> void:
	if k < 0 or k >= ROBOS.size() or achados[k]:
		return
	achados[k] = true
	if Guardado.ativo:
		Guardado.por_progresso(ROBOS[k][0], true)
	if estatuas[k] and is_instance_valid(estatuas[k]):
		estatuas[k].queue_free()
	estatuas[k] = null
	_por_guardados()
	if hud:
		hud.dica = ""
		hud.avisar("Robô levado para a base", "o drone o guardou num cilindro; lá dá para trocar")
	if memorias:
		memorias.abrir(ROBOS[k][2])


func achar() -> void:
	achar_robo(0)


## Passa a usar o robô `n` (0 o novo, 1 o anterior, 2 o mergulhador), se ele já foi achado.
func usar(n: int) -> void:
	if n == em_uso or n < 0 or n > ROBOS.size() or (n > 0 and not achados[n - 1]):
		return
	em_uso = n
	trocas += 1
	if Guardado.ativo:
		Guardado.por_progresso("robo_em_uso", em_uso)
	armadura.trocar_modelo(V2 if n == 0 else ROBOS[n - 1][1])
	_por_guardados()
	if hud:
		hud.avisar("Robô trocado", "o outro fica guardado no cilindro")


## Troca entre o robô novo e o anterior (o jeito de antes de haver mais de um achado).
func trocar() -> void:
	usar(1 if em_uso != 1 else 0)


## A correnteza da comporta: empurra para longe dela quem está na água ali perto.
func _correnteza(delta: float) -> void:
	if not comporta.is_finite() or armadura.estado != Armadura.Estado.NADO:
		return
	var de := armadura.global_position + Vector3(0, 0.6, 0) - comporta
	var d := de.length()
	if d > CORRENTE_RAIO or d < 0.3:
		return
	var forca := CORRENTE * (1.0 - smoothstep(CORRENTE_CHEIA, CORRENTE_RAIO, d))
	var fora := de / d
	fora.y = maxf(fora.y, -0.1)  # não enterra o robô no fundo
	fora = fora.normalized()
	armadura.global_position += fora * forca * delta
	# quem chega embalado (um mergulho do alto) é freado: ali dentro só se avança no braço
	var entrando := -armadura.velocity.dot(fora)
	if entrando > Ajustes.NADO_RAPIDO + 1.0:
		armadura.velocity += fora * (entrando - Ajustes.NADO_RAPIDO - 1.0)


func _physics_process(delta: float) -> void:
	if armadura and not get_tree().paused:
		_nadando_t = _nadando_t + delta if armadura.estado == Armadura.Estado.NADO else 0.0
		_correnteza(delta)


func _process(_delta: float) -> void:
	if armadura == null or get_tree().paused:
		return
	var convite := ""
	var alvo := -1
	var p := armadura.global_position
	var livre: bool = not armadura.em_pane and not armadura.travado
	if livre:
		for k in ROBOS.size():
			# o mergulhador só se alcança nadando contra a correnteza (cair do ar em cima dele não vale)
			var chegou: bool = armadura.estado == Armadura.Estado.CHAO if k == 0 else (armadura.estado == Armadura.Estado.NADO and _nadando_t > 1.5)
			if estatuas[k] and p.distance_to(estatuas[k].global_position) < PERTO and chegou:
				convite = "{agir}  acordar o robô"
				alvo = k
		if alvo < 0 and cilindros and armadura.estado == Armadura.Estado.CHAO:
			for k in guardados.size():
				if guardados[k] and k < cilindros.cilindros.size() and p.distance_to(cilindros.cilindros[k].global_position) < PERTO_CILINDRO:
					convite = "{agir}  trocar de robô"
					alvo = 10 + k
	if hud:
		if convite != "":
			hud.dica = convite
			_dica_minha = convite
		elif _dica_minha != "" and hud.dica == _dica_minha:
			hud.dica = ""
			_dica_minha = ""
	if convite != "" and Input.is_action_just_pressed("agir"):
		if alvo >= 10:
			usar(alvo - 10 + 1 if alvo - 10 < ROBOS.size() else 0)
		else:
			achar_robo(alvo)
