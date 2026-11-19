extends SceneTree
## Bateria da simulação (o tutorial): monta o mundo vazio, passa pelas oito lições do básico e pelas
## estações de combate e de voo, e confere que todas fecham. Com janela, tira uma foto de cada lição em tools/capturas/simulacao/.
## Uso: godot --headless --path . -s tools/teste_simulacao.gd -- --teste-vale --basico
## (os dois argumentos fazem o jogo não ler nem gravar o save)

var m: Node
var a: Armadura
var tutor: Tutor
var falhas := 0
var pontos := 0


func _initialize() -> void:
	_rodar()


func _ok(cond: bool, texto: String) -> void:
	pontos += 1
	if not cond:
		falhas += 1
	print("  %s  %s" % ["ok    " if cond else "FALHOU", texto])


func _esperar(seg: float) -> void:
	for i in roundi(seg * 60.0):
		await physics_frame


func _foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tools/capturas/simulacao")
	root.get_texture().get_image().save_png("res://tools/capturas/simulacao/%s.png" % nome)


## Espera a lição `chave` fechar (até `seg` segundos).
func _fechou(chave: String, seg: float, mirar := false) -> bool:
	for i in roundi(seg * 60.0):
		if tutor.chave() != chave:
			return true
		if mirar:
			# a câmera aponta para o aro da vez (com janela, o mouse de quem está no Mac mexe nela)
			var aros: Array = tutor.get("_aros")
			var atual: int = tutor.get("_aro_atual")
			if atual < aros.size() and is_instance_valid(aros[atual]):
				var d: Vector3 = (aros[atual] as Node3D).position - a.global_position
				m.camera.yaw = atan2(-d.x, -d.z)
		await physics_frame
	return tutor.chave() != chave


## Leva o robô para dentro do círculo de uma sequência do treino livre.
func _pisar(nome: String) -> void:
	await _esperar(0.3)
	for posto: Node3D in tutor.get("_postos"):
		if String(posto.get_meta("seq")) == nome:
			a.teleportar(posto.position + Vector3(0, 0.4, 0), Armadura.Estado.CHAO)
	await _esperar(0.5)


func _rodar() -> void:
	Main.pedido = "sim"
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	while m.get("pausa") == null:
		await process_frame
	for c in m.get_children():
		if c.get_script() and String(c.get_script().resource_path).ends_with("testes_vale.gd"):
			c.queue_free()
	a = m.armadura
	tutor = m.find_children("*", "Tutor", true, false)[0]
	await _esperar(1.0)
	_ok(m.ilha is SimMapa and Main.simulacao and not Main.mundo_montado and m.pausa.na_simulacao and m.pecas == null,
		"a simulação monta um mundo vazio, sem o vale (mapa %s)" % m.ilha.get_script().get_global_name())
	_ok(a.estado == Armadura.Estado.CHAO and a.is_on_floor() and absf(a.global_position.y) < 0.6, "o robô nasce de pé no chão (altura %.2f)" % a.global_position.y)
	await _foto("s1_olhar")
	# olhar
	for i in 90:
		m.camera.yaw += 0.04
		await physics_frame
	_ok(await _fechou("olhar", 2.0), "olhar: girar a câmera fecha a lição")
	await _esperar(1.2)
	await _foto("s2_andar")
	# andar até o aro
	Input.action_press("frente")
	_ok(await _fechou("andar", 12.0, true), "andar: chegar ao aro fecha a lição")
	Input.action_release("frente")
	await _esperar(1.2)
	await _foto("s3_correr")
	# correr: andando o aro não vale
	Input.action_press("frente")
	Input.action_press("correr")
	_ok(await _fechou("correr", 12.0, true), "correr: passar pelo aro correndo fecha a lição")
	Input.action_release("frente")
	Input.action_release("correr")
	await _esperar(1.4)
	await _foto("s4_pular")
	# pular e pular de novo no ar
	Input.action_press("pular")
	await _esperar(0.08)
	Input.action_release("pular")
	await _esperar(0.25)
	Input.action_press("pular")
	await _esperar(0.08)
	Input.action_release("pular")
	_ok(await _fechou("pular", 5.0), "pular: pulo e pulo duplo fecham a lição ao pousar")
	await _esperar(1.2)
	await _foto("s5_decolar")
	# decolar: segurar o pulo
	Input.action_press("pular")
	_ok(await _fechou("decolar", 5.0), "decolar: segurar o pulo liga o voo (%s)" % a.nome_estado())
	Input.action_release("pular")
	await _esperar(1.2)
	await _foto("s6_voar")
	# voar pelos aros: leva o robô a cada aro (pilotar de verdade fica para o teste na mão)
	var passou := true
	for k in 3:
		var aros: Array = tutor.get("_aros")
		var atual: int = tutor.get("_aro_atual")
		if atual >= aros.size():
			break
		a.global_position = (aros[atual] as Node3D).position
		await _esperar(0.2)
	passou = await _fechou("voar", 3.0)
	_ok(passou, "voar: passar pelos três aros fecha a lição")
	await _esperar(1.2)
	await _foto("s7_calor")
	a.calor = 50.0
	_ok(await _fechou("calor", 3.0), "calor: o motor a 45% fecha a lição")
	await _esperar(1.2)
	await _foto("s8_pousar")
	# pousar: um toque corta os jatos
	if a.estado == Armadura.Estado.VOO:
		Input.action_press("voar")
		await _esperar(0.08)
		Input.action_release("voar")
	_ok(await _fechou("pousar", 12.0), "pousar: tocar o chão fecha a lição (%s)" % a.nome_estado())
	await _esperar(1.2)
	_ok(tutor.acabou and tutor.feitas == Tutor.LICOES.size(), "as %d lições fecharam (%d)" % [Tutor.LICOES.size(), tutor.feitas])
	await _foto("s9_livre")
	# treino livre: três círculos, e o robô equipado só aqui
	var postos: Array = tutor.get("_postos")
	_ok(tutor.seq == "" and postos.size() == 3 and tutor.equipado and Melhorias.tem("asas") and Arsenal.tem_arma("rajada") and Guardado.sem_progresso,
		"treino livre: %d círculos, robô com todas as peças e armas (%s), save fechado para o progresso (%s)" % [postos.size(), tutor.equipado, Guardado.sem_progresso])
	# combate: pisar no círculo começa a sequência
	await _pisar("combate")
	_ok(tutor.seq == "combate" and tutor.chave() == "mirar", "pisar no círculo do combate começa a sequência (%s, %s)" % [tutor.seq, tutor.chave()])
	Input.action_press("mirar")
	_ok(await _fechou("mirar", 4.0), "mirar: segurar a mira fecha a lição")
	await _esperar(1.2)
	await _foto("s11_alvos")
	# atirar: aponta para cada alvo e atira até desligar
	var desligou := 0
	for al: AlvoTreino in tutor.alvos:
		for tentativa in 40:
			if al.desligada:
				break
			var olho: Vector3 = m.camera.cam.global_position
			var d: Vector3 = al.global_position - olho
			m.camera.yaw = atan2(-d.x, -d.z)
			m.camera.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			await _esperar(0.12)
			Input.action_press("atirar")
			await _esperar(0.06)
			Input.action_release("atirar")
			await _esperar(0.25)
		if al.desligamentos > 0:
			desligou += 1
	_ok(desligou == 3 and await _fechou("atirar", 3.0), "atirar: os três alvos desligam com tiros de verdade (%d de 3)" % desligou)
	Input.action_release("mirar")
	await _esperar(1.2)
	Input.action_press("roda")
	await _esperar(0.08)
	Input.action_release("roda")
	_ok(await _fechou("arma", 3.0), "arma: um toque troca de arma (%s)" % Arsenal.modo)
	await _esperar(1.2)
	Input.action_press("granada")
	await _esperar(0.5)
	Input.action_release("granada")
	_ok(await _fechou("granada", 4.0), "granada: segurar e soltar joga uma (%d)" % m.tiro.granadas_jogadas)
	await _esperar(1.2)
	Input.action_press("espada")
	await _esperar(0.08)
	Input.action_release("espada")
	_ok(await _fechou("espada", 3.0), "espada: o golpe fecha a lição")
	await _esperar(1.2)
	Input.action_press("soltar")
	await _esperar(0.08)
	Input.action_release("soltar")
	_ok(await _fechou("esquiva", 3.0), "esquiva: a esquiva fecha a lição e volta ao treino livre (%s)" % tutor.seq)
	await _esperar(1.4)
	# voo: decolar de verdade; as outras manobras entram pelo estado do robô
	await _pisar("voo")
	_ok(tutor.seq == "voo" and tutor.chave() == "decolar", "pisar no círculo do voo começa a sequência (%s)" % tutor.chave())
	Input.action_press("pular")
	var decolou: bool = await _fechou("decolar", 5.0)
	Input.action_release("pular")
	await _esperar(1.2)
	Input.action_press("pairar")
	await _esperar(0.08)
	Input.action_release("pairar")
	var pairou: bool = await _fechou("pairar", 4.0)
	await _foto("s12_voo")
	_ok(decolou and pairou, "voo: decolar e parar no ar com os botões de verdade (%s, %s; %s)" % [decolou, pairou, a.nome_estado()])
	await _esperar(1.2)
	# a arrancada é refeita pelo robô a cada passo da física: o teste a põe logo antes de o tutor olhar
	var arrancou := false
	for i in 400:
		await process_frame
		a.estado = Armadura.Estado.VOO
		a.arrancada = true
		if tutor.chave() != "arrancada":
			arrancou = true
			break
	await _esperar(1.2)
	a.manobras += 1
	var manobrou: bool = await _fechou("manobra", 1.0)
	await _esperar(1.2)
	a.estado = Armadura.Estado.PLANAR
	var planou: bool = await _fechou("planar", 1.0)
	await _esperar(1.2)
	a.golpe_chao.emit(a.global_position)
	var mergulhou: bool = await _fechou("mergulho", 1.0)
	_ok(arrancou and manobrou and planou and mergulhou, "voo: arrancada, manobra, planar e mergulho fecham pelas condições (%s, %s, %s, %s)" % [arrancou, manobrou, planou, mergulhou])
	a.teleportar(a.global_position * Vector3(1, 0, 1) + Vector3(0, 0.4, 0), Armadura.Estado.CHAO)
	await _esperar(1.6)
	_ok(tutor.seq == "", "depois do voo, de volta ao treino livre")
	_ok(Guardado.gravacoes == 0, "nada foi gravado no save durante o treino (%d gravações)" % Guardado.gravacoes)
	# longe do começo ainda há chão
	a.teleportar(Vector3(5200.0, 30.0, -3100.0), Armadura.Estado.AR)
	await _esperar(4.0)
	_ok(a.is_on_floor() and absf(a.global_position.y) < 0.6, "a 6 km do começo ainda há chão (altura %.2f, %s)" % [a.global_position.y, a.nome_estado()])
	# a câmera no mergulho com impacto: olha de cima enquanto o robô desce, e volta depois da batida
	m.camera.pitch = -0.1
	a.teleportar(Vector3(a.global_position.x, 45.0, a.global_position.z), Armadura.Estado.AR)
	await _esperar(0.2)
	Input.action_press("golpe")
	await _esperar(0.08)
	Input.action_release("golpe")
	await _esperar(0.35)
	var de_cima: bool = a.mergulhando and m.camera.pitch_visto < -0.75 and m.camera.global_position.y > a.global_position.y + 1.0
	var visto_descendo: float = m.camera.pitch_visto
	await _esperar(3.2)
	_ok(de_cima and a.is_on_floor() and absf(m.camera.pitch_visto - m.camera.pitch) < 0.02 and absf(m.camera.pitch + 0.1) < 0.001,
		"mergulho com impacto: a câmera olha de cima na descida (%.2f rad) e volta ao ângulo do jogador depois (%.2f)" % [visto_descendo, m.camera.pitch_visto])
	# a pausa da simulação
	m.pausa._abrir()
	await _esperar(0.3)
	await _foto("s10_pausa")
	m.pausa._continuar()
	await _esperar(0.3)
	print("")
	print("SIMULAÇÃO OK (%d pontos)" % pontos if falhas == 0 else "SIMULAÇÃO FALHOU: %d de %d" % [falhas, pontos])
	quit(1 if falhas > 0 else 0)
