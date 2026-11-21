class_name PontosIlha
extends RefCounted
## As coisas para achar ou para começar na ilha, num lugar só. O pedido do usuário, em 2026-11-21: no mesmo
## lugar bonito pode haver mais de uma, mas nunca uma em cima da outra.
## O `Main` anota tudo uns quadros depois de montar o vale (`Main._anotar_pontos`): peças, memórias, balizas das
## rotas, tocas dos procurados, acampamentos, os robôs para achar, os robozinhos, o receptor do mastro e o ninho.
## O balcão do farol (o fim do jogo) fica de fora: o radiador duplo mora ali, e os dois não acontecem juntos.
## Quem escolhe o lugar sozinho (as sementes da horta) espera `pronto` e pergunta `livre`. `perto_demais` lista
## os pares a menos de `LONGE` m.

const LONGE := 50.0  # m entre duas coisas, no espaço (a gruta embaixo e o morro em cima contam a distância de verdade)

static var pontos := {}  # "tipo:id" -> Vector3
static var pronto := false


static func zerar() -> void:
	pontos.clear()
	pronto = false


static func anotar(chave: String, p: Vector3) -> void:
	if p.is_finite():
		pontos[chave] = p


## `p` fica a pelo menos `longe` m de tudo o que está anotado (menos a chave `menos`, a própria coisa)?
static func livre(p: Vector3, longe := LONGE, menos := "") -> bool:
	for k: String in pontos:
		if k != menos and (pontos[k] as Vector3).distance_to(p) < longe:
			return false
	return true


## Os pares mais perto que `longe`: [[chave, chave, metros], ...] (testes e sondas).
static func perto_demais(longe := LONGE) -> Array:
	var r: Array = []
	var chaves := pontos.keys()
	for i in chaves.size():
		for j in range(i + 1, chaves.size()):
			var d := (pontos[chaves[i]] as Vector3).distance_to(pontos[chaves[j]])
			if d < longe:
				r.append([chaves[i], chaves[j], d])
	return r
