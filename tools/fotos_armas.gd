extends SceneTree
# Fotos de cada arma do robô em 3 vistas (frente, lado, topo), de perto, sem mexer no jogo.
# Uso: godot --path . -s tools/fotos_armas.gd -- <pasta>/
var m: Node
var a: Armadura
var pasta := "tools/capturas/armas/"
var cam: Camera3D
var fundo: MeshInstance3D
var espada := false

# arma -> [peça visual ou "", junta alvo, deslocamento local do alvo, distância, lado (+1 direita do robô, -1 esquerda)]
const ARMAS := {
	"basico": ["", "punhoD", Vector3(0, 0, 0), 0.4, 1.0],
	"espada": ["", "punhoD", Vector3(0, 0, 0), 1.3, 1.0],
	"mira": ["mira", "", Vector3(0, 0, 0), 0.4, 1.0],
	"rajada": ["arma_rajada", "", Vector3(0, -0.03, 0), 0.6, 1.0],
	"canhao": ["arma_canhao", "", Vector3(0, -0.02, 0), 0.55, 1.0],
	"precisao": ["arma_precisao", "", Vector3(0, -0.06, 0), 0.9, 1.0],
	"duplo": ["arma_duplo", "", Vector3(0, 0, 0), 0.55, 1.0],
	"escudo": ["escudo", "", Vector3(0, 0, 0), 0.7, -1.0],
	"vida": ["vida", "", Vector3(0, 0, 0), 1.1, 1.0],
	"misseis": ["lanca_misseis", "", Vector3(0, 0, 0), 0.7, -1.0, true],
	"granadas": ["lanca_granadas", "", Vector3(0, 0, 0), 0.7, 1.0, true],
}


func _initialize() -> void:
	_rodar()


func _esp(n: int) -> void:
	for i in n:
		if espada:
			a.espada_t = float(Arsenal.ESPADA["tempo"]) * 0.5
		await physics_frame


func _foto(nome: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta + nome + ".png")
	print("foto ", nome)


func _esconder(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			c.visible = false
		elif c is Control and c.get_parent() == root:
			c.visible = false


func _rodar() -> void:
	for x in OS.get_cmdline_user_args():
		if not x.begins_with("--"):
			pasta = x
	DirAccess.make_dir_recursive_absolute(pasta)
	Main.abertura_vista = true
	InteriorCilindro.ativo = true
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	while m.get("pausa") == null or not (m.get("pausa") as Node).is_inside_tree():
		await process_frame
	for c in m.get_children():
		if c.get_script() and String(c.get_script().resource_path).ends_with("testes_vale.gd"):
			c.queue_free()
	if m.pausa.visible:
		m.pausa.call("_continuar")
	paused = false
	await _esp(30)
	m.ciclo.hora = 10.0
	m.ciclo.parado = true
	a = m.armadura
	if m.memorias:
		m.memorias.fechar()
	a.recomecar()
	await _esp(20)
	var b := BaseVale.boca_cilindro
	var of_eixo: Vector3 = m.oficina._eixo()
	var p := b + of_eixo * 40.0
	a.teleportar(Vector3(p.x, m.ilha.altura(p.x, p.z) + 0.4, p.z), Armadura.Estado.CHAO)
	await _esp(60)
	_esconder(m)
	cam = Camera3D.new()
	cam.fov = 28.0
	root.add_child(cam)
	cam.current = true
	for n in root.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (n as WorldEnvironment).environment
		if env:
			env.glow_enabled = false
	fundo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(6, 6)
	fundo.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.55, 0.62, 0.7)
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fundo.material_override = fm
	root.add_child(fundo)
	for arma in ARMAS:
		var d: Array = ARMAS[arma]
		espada = arma == "espada"
		a.visual.yaw_forcado = 0.0
		a.visual.vestir_melhorias([d[0]] if d[0] != "" else [])
		a.visual.previa = true
		await _esp(90 if espada else 30)
		var v: ArmaduraVisual = a.visual
		for vista in ["frente", "lado", "topo"]:
			var cfg := _alvo(arma, d)
			for rep in 2:
				cfg = _alvo(arma, d)
				var alvo: Vector3 = cfg[0]
				var bas: Basis = cfg[1]
				var dist: float = d[3]
				var frente := -bas.z
				var dir_lado := bas.x * float(d[4])
				var pos := alvo
				var up := Vector3.UP
				match vista:
					"frente":
						pos = alvo + frente * dist * (-1.0 if d.size() > 5 else 1.0) + Vector3.UP * 0.03
					"lado":
						pos = alvo + (dir_lado * dist if arma != "espada" else (-frente * 0.7 + dir_lado * 0.7).normalized() * dist)
					"topo":
						pos = alvo + Vector3.UP * dist + frente * 0.001
						up = frente
				cam.global_position = pos
				cam.look_at(alvo, up)
				(fundo.material_override as StandardMaterial3D).albedo_color = Color(0.12, 0.14, 0.2) if arma == "espada" else Color(0.55, 0.62, 0.7)
				fundo.global_position = alvo + (alvo - pos).normalized() * (3.0 if arma == "espada" and vista == "frente" else (0.7 if arma == "espada" else 0.3))
				fundo.look_at(pos, up)
				await _esp(8)
			await _foto(arma + "_" + vista)
	quit()


func _alvo(arma: String, d: Array) -> Array:
	var v: ArmaduraVisual = a.visual
	var bas: Basis = v.global_transform.basis.orthonormalized()
	var alvo: Vector3
	if arma == "espada" and v._lamina_no:
		alvo = v._lamina_no.global_position
	elif d[1] != "":
		alvo = (v.j[d[1]] as Node3D).global_position + bas * d[2]
	else:
		var soma := Vector3.ZERO
		var qtd := 0
		for n in v.pecas[d[0]]:
			if n is Node3D and not n is Light3D:
				soma += (n as Node3D).global_position
				qtd += 1
				if arma == "duplo":
					break  # o cano da direita
		alvo = soma / maxf(1.0, qtd) + bas * d[2]
	return [alvo, bas]
