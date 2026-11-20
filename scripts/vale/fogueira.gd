class_name Fogueira
extends Node3D
## A fogueira da base (2026-11-20): só acende de noite e sem chuva. De dia, ou chovendo, é lenha e carvão
## apagados. Acesa: brasa, uma chama pequena que treme, os pontos de luz do `LuzesNoite` e uma luz quente
## em volta. Quem monta é o `BaseLar._fogueira`.

const CHUVA_APAGA := 0.12

var brasa: MeshInstance3D
var mat_fria: Material
var mat_acesa: Material
var luz: OmniLight3D
var acesa := false  # testes e fotos
var forca := 0.0  # 0 apagada, 1 acesa (suave)
var _chamas: Array[MeshInstance3D] = []
var _t := 0.0


func _ready() -> void:
	var tex: Texture2D = load("res://assets/fx/kenney/flame_04.png") if ResourceLoader.exists("res://assets/fx/kenney/flame_04.png") else null
	for k in 2:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
		m.albedo_texture = tex
		m.albedo_color = [Color(1.0, 0.5, 0.14), Color(1.0, 0.8, 0.35)][k]
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 1.1) if k == 0 else Vector2(0.5, 0.7)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, 0.62 if k == 0 else 0.5, 0)
		mi.visible = false
		add_child(mi)
		_chamas.append(mi)


func _process(delta: float) -> void:
	_t += delta
	var chuva := CicloDia.atual.chuva if CicloDia.atual else 0.0
	var seco := chuva < CHUVA_APAGA
	acesa = ArmaduraVisual.noite > 0.25 and seco
	LuzesNoite.ligadas["fogueira"] = seco
	forca = move_toward(forca, 1.0 if acesa else 0.0, delta * 0.7)
	var treme := 0.86 + 0.14 * sin(_t * 9.0) * sin(_t * 5.3 + 1.0)
	if luz:
		luz.light_energy = 1.6 * forca * treme
		luz.visible = forca > 0.01
	if brasa:
		brasa.material_override = mat_acesa if forca > 0.3 else mat_fria
	for k in _chamas.size():
		var c := _chamas[k]
		c.visible = forca > 0.02
		var s := forca * (0.9 + 0.12 * sin(_t * (7.0 + k * 3.0) + k))
		c.scale = Vector3(s, s * (1.0 + 0.1 * sin(_t * 11.0 + k * 2.0)), s)
		(c.material_override as StandardMaterial3D).albedo_color.a = forca
