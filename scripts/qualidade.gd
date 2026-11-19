class_name Qualidade
extends RefCounted
## Os três níveis de qualidade do desenho (ajuste da pausa). O que mais pesa no jogo é o capim, a
## suavização de serrilhado sobre ele e as sombras do sol (medido em 2026-11-17, doc §63): cada nível mexe
## nesses três. O capim tem duas densidades: perto do robô, cheio; dali até 95 m, só uma parte das
## touceiras, maiores. `capim_perto` é até onde vai o cheio.
## Desde 2026-11-19 os níveis mexem também na sombra de contato (SSAO: desligada, leve, cheia; custa de 3 a
## 5 ms na mata) e no desfoque do fundo (só na alta; 1,3 ms), que antes valiam iguais nos três.

const NOMES := ["baixa", "média", "alta"]
const NIVEIS := [
	{"troca": 0.6, "capim_perto": 16.0, "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "faixas": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "sombra": 130.0, "ssao": 0, "desfoque": false},
	{"troca": 0.8, "capim_perto": 34.0, "msaa": Viewport.MSAA_2X, "fxaa": false, "faixas": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "sombra": 220.0, "ssao": 1, "desfoque": false},
	{"troca": 1.0, "capim_perto": 60.0, "msaa": Viewport.MSAA_4X, "fxaa": false, "faixas": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "sombra": 380.0, "ssao": 2, "desfoque": true},
]
const PARTE_LONGE := 0.3  # fração das touceiras que fica até 95 m
const ESCALA_LONGE := 1.45  # e quanto elas crescem, para o campo não rarear à vista
const CAPIM_ATE := 88.0  # onde a última touceira some (o shader encolhe até lá)
const RAIO_BLOCO := 23.0  # meio bloco de capim na diagonal

static var nivel := 1


static func capim_perto() -> float:
	return float(NIVEIS[nivel]["capim_perto"])


## Aplica o nível no que já existe na cena. `raiz` é qualquer nó dentro da árvore.
static func aplicar(raiz: Node, novo: int) -> void:
	nivel = clampi(novo, 0, NIVEIS.size() - 1)
	if raiz == null or not raiz.is_inside_tree():
		return
	var n: Dictionary = NIVEIS[nivel]
	var vp := raiz.get_viewport()
	vp.msaa_3d = n["msaa"]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if n["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	for sol: DirectionalLight3D in raiz.get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		if sol.shadow_enabled:
			sol.directional_shadow_mode = n["faixas"]
			sol.directional_shadow_max_distance = n["sombra"]
	for we: WorldEnvironment in raiz.get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if we.environment:
			we.environment.ssao_enabled = int(n["ssao"]) > 0
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if int(n["ssao"]) < 2 else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
	for cam: Camera3D in raiz.get_tree().root.find_children("*", "Camera3D", true, false):
		var lente := cam.attributes as CameraAttributesPractical
		if lente:
			lente.dof_blur_far_enabled = bool(n["desfoque"])
	RenderingServer.global_shader_parameter_set("troca_fator", float(n["troca"]))
	for bloco: Node in raiz.get_tree().get_nodes_in_group("por_distancia"):
		preparar_bloco(bloco as MultiMeshInstance3D)
	for mmi: Node in raiz.get_tree().get_nodes_in_group("capim_perto"):
		preparar_capim_perto(mmi as MultiMeshInstance3D)
	for mat: Variant in _mats_capim:
		(mat as ShaderMaterial).set_shader_parameter("perto_ate", capim_perto())


static var _mats_capim: Array = []


## O material do capim precisa saber até onde vai o capim cheio.
static func registrar_material(mat: ShaderMaterial) -> void:
	if not _mats_capim.has(mat):
		_mats_capim.append(mat)
	mat.set_shader_parameter("perto_ate", capim_perto())
	mat.set_shader_parameter("some_ate", CAPIM_ATE)


## Um bloco de capim cheio: some inteiro quando nenhuma touceira dele pode aparecer.
static func preparar_capim_perto(mmi: MultiMeshInstance3D) -> void:
	if mmi == null:
		return
	mmi.visibility_range_end = capim_perto() + RAIO_BLOCO
	mmi.visibility_range_end_margin = 4.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Um bloco de árvores, plantas ou pedras que troca por distância (Clareira._multi): o bloco inteiro só é
## desenhado enquanto alguma peça dele pode aparecer. As distâncias encolhem com a qualidade.
static func preparar_bloco(mmi: MultiMeshInstance3D) -> void:
	if mmi == null or not mmi.has_meta("troca"):
		return
	var t: Vector3 = mmi.get_meta("troca")  # (surge a partir de, some até, raio do bloco)
	var f := float(NIVEIS[nivel]["troca"])
	mmi.visibility_range_begin = maxf(0.0, t.x * f - 34.0 - t.z) if t.x > 0.0 else 0.0
	mmi.visibility_range_begin_margin = 6.0 if mmi.visibility_range_begin > 0.0 else 0.0
	mmi.visibility_range_end = t.y * f + t.z if t.y > 0.0 else 0.0
	mmi.visibility_range_end_margin = 6.0 if t.y > 0.0 else 0.0
