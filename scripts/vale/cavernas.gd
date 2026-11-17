class_name Cavernas
extends RefCounted
## O chão do vale antes de qualquer peça de rocha cavar nele. A única caverna do vale é o Sumidouro
## (scripts/vale/sumidouro.gd); as seis grutas pequenas que eram sorteadas pelo mapa saíram em
## 2026-11-16: apareciam por fora como um retângulo de chão refeito, com lajes de pedra na beira e a
## boca virando um buraco no campo (a do Platô das Flores foi a última a dar defeito).
## `cavar` roda antes de o chão ser montado e guarda a grade original.

static var _orig := PackedFloat32Array()


## O chão de antes de cavar, em qualquer ponto (a mesma conta de Vale._fora).
static func chao_antes(x: float, z: float) -> float:
	var fx := clampf((x + Vale.F_META) / Vale.F_PASSO, 0.0, Vale.F_N - 1.001)
	var fz := clampf((z + Vale.F_META) / Vale.F_PASSO, 0.0, Vale.F_N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var i := iz * Vale.F_N + ix
	return lerpf(lerpf(_orig[i], _orig[i + 1], fx - ix), lerpf(_orig[i + Vale.F_N], _orig[i + Vale.F_N + 1], fx - ix), fz - iz)


## Dentro da área cavada de uma peça de rocha (com folga): ali não nasce árvore nem rocha de paredão.
static func dentro(x: float, z: float, folga := 4.0) -> bool:
	return RochaMalha.dentro(x, z, folga)


static func cavar(v: Vale) -> void:
	Sumidouro.existe = false
	_orig = v._fora_h.duplicate()
	RochaMalha.preparar(v)
