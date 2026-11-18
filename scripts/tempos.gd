class_name Tempos
extends RefCounted

## Quanto cada passo da montagem do mundo leva (`--tempos` imprime). Serve para saber o que vale guardar.

static var _t := 0
static var ligado := false


static func marca(nome: String) -> void:
	var agora := Time.get_ticks_msec()
	if ligado and _t > 0:
		print("TEMPO %-28s %5d ms" % [nome, agora - _t])
	_t = agora
