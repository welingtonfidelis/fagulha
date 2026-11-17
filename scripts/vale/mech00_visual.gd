class_name Mech00Visual
extends MechVisual
## Mech modular (Mech_00, de jimmys7777): um esqueleto, oito lugares de corpo com seis conjuntos cada, extras
## presos em ossos de encaixe e uma paleta de cor. `montar` sorteia tudo a partir de uma semente (a mesma
## semente dá sempre o mesmo robô) e guarda em `ficha` o que saiu, para o comportamento ler.
## As animações vêm de assets/vale/mech00/mech00_anim.fbx e respondem pelos mesmos nomes de MechVisual.

## Os FBX do pacote entram direto (a Godot importa). Cada arquivo guarda o esqueleto numa orientação; só o
## das animações bate com elas, então ele é a base e as peças dos outros dois são penduradas nele (as peças
## se prendem aos ossos pelo nome).
const CORPOS := ["res://assets/vale/mech00/mech00_corpo.fbx", "res://assets/vale/mech00/mech00_corpo_a.fbx"]
const ANIM := "res://assets/vale/mech00/mech00_anim.fbx"
const EXTRA := "res://assets/vale/mech00/extras/%s.fbx"
const PALETA := "res://assets/vale/mech00/paletas/SimplePalette%04d.png"
const PALETAS := 47
const ALTURA_MODELO := 4.14

## Arma pedida para o próximo `montar` ("" sorteia como sempre): "corpo" (espada ou martelo), "bala" (fuzil
## de um tiro), "pesado" (braço-canhão) ou "missil" (um míssil nas costas). A Fundição usa para graduar as ondas.
static var forcar := ""
const CONJUNTOS := ["Base_S", "Base_M", "Base_L", "Base(A)_S", "Base(A)_M", "Base(A)_L"]
const LUGARES := ["Arm", "Forearm_L", "Forearm_R", "Leg", "Pelvis", "Shoulder", "Thigh", "Torso"]
## nomes de MechVisual -> animação do pacote
const NOMES := {"Idle": "Mech_Idle", "Walk": "Mech_Walk", "Run": "Mech_Run", "Death": "Mech_Die", "HitRecieve_1": "Mech_GetHit",
	"Jump": "Mech_Jump_Mid", "Crouch": "Mech_Crouch"}
const LACOS_00 := ["Mech_Idle", "Mech_Walk", "Mech_Run", "Mech_CrouchWalk", "Mech_Jump_Mid", "Mech_WalkLeft", "Mech_WalkRight"]

## O que o sorteio deu: {arma: "tiro" | "corpo" | "costas", mao: nome, costas: nome, armaduras: n, porte: -1 a 1, paleta: n}
var ficha := {}
var esqueleto: Skeleton3D

static var _pecas: Dictionary = {}  # nome da peça -> [Mesh, Skin]
static var _extras: Dictionary = {}  # nome do extra -> [[Mesh, Transform3D], ...]
static var _lacos_prontos := false


static func montar(semente: int, alt: float, ruido: Texture2D) -> Mech00Visual:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente * 9973 + 101
	var v := Mech00Visual.new()
	v.altura = alt
	if _pecas.is_empty():
		for arq: String in CORPOS:
			var cena := (load(arq) as PackedScene).instantiate()
			for n in cena.find_children("*", "MeshInstance3D", true, false):
				var mi0 := n as MeshInstance3D
				if mi0.mesh:
					_pecas[String(mi0.name).replace(".", "_")] = [mi0.mesh, mi0.skin]
			cena.free()
	var raiz := (load(ANIM) as PackedScene).instantiate() as Node3D
	for n in raiz.find_children("arp_dummy*", "", true, false):
		n.free()
	raiz.scale = Vector3.ONE * alt / ALTURA_MODELO
	raiz.rotation.y = PI
	v.add_child(raiz)
	v.esqueleto = raiz.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	# cor: uma paleta para o robô inteiro, com a luz em faixas do vale; o contorno é a casca preta do modelo
	var paleta := rng.randi_range(0, PALETAS - 1)
	v.mat = ShaderMaterial.new()
	v.mat.shader = load("res://scripts/shaders/vale_tex.gdshader")
	v.mat.set_shader_parameter("tex", load(PALETA % paleta))
	v.mat.set_shader_parameter("tinta", Color(0.85, 0.85, 0.85))
	v.mat.set_shader_parameter("corte", 0.0)
	v.mat.set_shader_parameter("vento", 0.0)
	v.mat.set_shader_parameter("borda", 0.25)
	v.mat.set_shader_parameter("ruido", ruido)
	var contorno := StandardMaterial3D.new()
	contorno.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	contorno.albedo_color = Color(0.03, 0.03, 0.04)
	# corpo: um conjunto por lugar; os dois antebraços saem do mesmo conjunto
	var escolha := {}
	var soma_porte := 0.0
	for lugar: String in LUGARES:
		var c: String = CONJUNTOS[rng.randi_range(0, CONJUNTOS.size() - 1)]
		if lugar == "Forearm_R":
			c = escolha["Forearm_L"]
		escolha[lugar] = c
		soma_porte += {"S": -1.0, "M": 0.0, "L": 1.0}[c.right(1)]
	# braço-canhão no lugar de um antebraço e da mão (só existe nos conjuntos da base)
	var canhao := ""
	var quer_canhao := rng.randf() < 0.3
	if forcar == "pesado":
		quer_canhao = true
	elif forcar != "":
		quer_canhao = false
	if quer_canhao:
		canhao = "R" if rng.randf() < 0.7 else "L"
		escolha["LimbGun_" + canhao] = "Base_" + String(escolha["Forearm_L"]).right(1)
	for nome: String in _pecas:
		var mostra := nome.begins_with("Core_")
		for lugar: String in escolha:
			if nome == String(escolha[lugar]) + "_" + lugar:
				mostra = true
		if canhao != "" and (nome == "Core_Palm_" + canhao or nome.ends_with("_Forearm_" + canhao)):
			mostra = false
		if not mostra:
			continue
		var mi := MeshInstance3D.new()
		mi.name = nome
		mi.mesh = _pecas[nome][0]
		mi.skin = _pecas[nome][1]
		v.esqueleto.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.set_surface_override_material(0, v.mat)
		if mi.mesh.get_surface_count() > 1:
			mi.set_surface_override_material(1, contorno)
	# extras, cada um no osso de encaixe do tamanho da peça onde vai
	var t := func(lugar: String) -> String: return String(escolha[lugar]).right(1)
	var arma := "tiro"
	var mao := ""
	var costas := ""
	var sorte := rng.randf()
	if forcar == "corpo":
		sorte = 0.0
	elif forcar != "":
		sorte = 1.0
	var braco := "R"  # o braço que ataca
	if canhao != "":
		mao = "canhão"
		braco = canhao
		v.boca = BoneAttachment3D.new()
		v.esqueleto.add_child(v.boca)
		(v.boca as BoneAttachment3D).bone_name = "hand." + canhao.to_lower()
	elif sorte < 0.35:
		arma = "corpo"
		mao = "Core_Sword" if rng.randf() < 0.5 else "Core_Hammer"
		v._prender(mao, "Hand_Attachment.R", contorno)
	else:
		mao = ["Attach_Gun_00", "Attach_Gun_01", "Attach_Gun_02"][rng.randi_range(0, 2)]
		if forcar == "bala" or forcar == "missil":
			mao = "Attach_Gun_00"  # o fuzil de um tiro, a arma de mão mais branda
		v.boca = v._prender(mao, "Forearm_%s_Attachment.R" % t.call("Forearm_R"), contorno)
	var quer_costas := rng.randf() < 0.55
	if forcar == "missil":
		quer_costas = true
	elif forcar != "":
		quer_costas = false  # sem nada nas costas: a arma pedida é a que vale
	if quer_costas:
		costas = ["Attach_Back_1Gun", "Attach_Back_2Gun", "Attach_Back_Missiles_00", "Attach_Back_Missiles_01", "Attach_Back_JetPack_00"][rng.randi_range(0, 4)]
		if forcar == "missil":
			costas = "Attach_Back_Missiles_01"  # um míssil por vez
		var nas_costas := v._prender(costas, "Back_%s_Attachment" % t.call("Torso"), contorno)
		if forcar == "missil":
			arma = "costas"
			v.boca = nas_costas
		elif arma == "tiro" and costas != "Attach_Back_JetPack_00" and rng.randf() < 0.5:
			arma = "costas"
			v.boca = nas_costas
	var armaduras := 0
	for lado: String in ["L", "R"]:
		if rng.randf() < 0.4:
			v._prender("Attach_Armour_0%d" % rng.randi_range(0, 2), "Shoulder_%s_Attachment.%s" % [t.call("Shoulder"), lado], contorno)
			armaduras += 1
		if rng.randf() < 0.25:
			v._prender("Attach_Module_0%d" % rng.randi_range(0, 2), "Thigh_%s_Attachment.%s" % [t.call("Thigh"), lado], contorno)
	v.ficha = {"arma": arma, "mao": mao, "costas": costas, "armaduras": armaduras, "porte": soma_porte / LUGARES.size(), "paleta": paleta, "lado": braco}
	# animações: o tocador do próprio arquivo
	v.anim = raiz.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if not _lacos_prontos:
		_lacos_prontos = true
		# a animação de cair arrasta o corpo uns 4,5 m para trás pelo osso de trajeto; sem essa trilha ele cai
		# onde está (senão parava no ar sobre o rio, ou fora do lugar no terreno)
		var cair := v.anim.get_animation("Mech_Die")
		for ti in range(cair.get_track_count() - 1, -1, -1):
			if String(cair.track_get_path(ti)).ends_with(":c_traj"):
				cair.remove_track(ti)
		for an: String in LACOS_00:
			if v.anim.has_animation(an):
				v.anim.get_animation(an).loop_mode = Animation.LOOP_LINEAR
	v.cabeca = BoneAttachment3D.new()
	v.esqueleto.add_child(v.cabeca)
	v.cabeca.bone_name = "head.x"
	v.luz = OmniLight3D.new()
	v.luz.light_color = Color(1.0, 0.16, 0.08)
	v.luz.omni_range = alt * 0.8
	v.luz.omni_attenuation = 2.0
	v.luz.light_energy = 0.0
	v.luz.shadow_enabled = false
	v.cabeca.add_child(v.luz)
	v.tocar("Idle")
	return v


func _prender(nome: String, osso: String, contorno: Material) -> BoneAttachment3D:
	if not _extras.has(nome):
		var lista := []
		if ResourceLoader.exists(EXTRA % nome):
			var cena := (load(EXTRA % nome) as PackedScene).instantiate() as Node3D
			for n in cena.find_children("*", "MeshInstance3D", true, false):
				var m0 := n as MeshInstance3D
				if m0.mesh == null:
					continue
				var t := m0.transform
				var pai := m0.get_parent()
				while pai != null and pai != cena and pai is Node3D:
					t = (pai as Node3D).transform * t
					pai = pai.get_parent()
				lista.append([m0.mesh, t])
			cena.free()
		_extras[nome] = lista
	if (_extras[nome] as Array).is_empty() or esqueleto.find_bone(osso) < 0:
		push_warning("mech00: sem o extra %s ou o osso %s" % [nome, osso])
		return null
	var preso := BoneAttachment3D.new()
	esqueleto.add_child(preso)
	preso.bone_name = osso
	for par: Array in _extras[nome]:
		var mi := MeshInstance3D.new()
		mi.mesh = par[0]
		mi.transform = par[1]
		mi.set_surface_override_material(0, mat)
		if mi.mesh.get_surface_count() > 1:
			mi.set_surface_override_material(1, contorno)
		preso.add_child(mi)
	return preso


func tempo_do_tiro() -> float:
	return {"corpo": 0.58, "costas": 0.4}.get(ficha.get("arma", "tiro"), 0.45)


func tocar(nome: String, vel := 1.0, mistura := 0.2) -> void:
	var real: String = NOMES.get(nome, nome)
	if nome == "Shoot":
		# o ataque depende do que ele carrega: golpe com a arma de mão (três jeitos), tiro de ombro, ou tiro com
		# o braço que tem a arma
		match String(ficha.get("arma", "tiro")):
			"corpo":
				real = "Mech_Attack%d_R" % (1 + randi() % 3) if (atual != nome or not anim.is_playing()) else String(anim.current_animation)
			"costas":
				real = "Mech_ShoulderShoot1"
			_:
				real = "Mech_Shoot_" + String(ficha.get("lado", "R"))
		if atual == nome and not anim.is_playing():
			atual = ""  # acabou: o próximo ataque começa do início
	if anim == null or not anim.has_animation(real):
		return
	if atual != nome:
		atual = nome
		anim.play(real, mistura, vel)
	else:
		anim.speed_scale = vel
