class_name Locais
extends Node
## Lugares com nome (Platô da Chegada, Queda do Véu...). Quando a armadura entra no raio de um lugar,
## emite `chegou` (o HUD mostra o nome). Sair tem folga de 15% no raio para não piscar na borda.

signal chegou(nome: String, primeira_vez: bool)

var armadura: Armadura
var lista: Array[Dictionary] = []  # {nome: String, pos: Vector3, raio: float, visto: bool}
var atual := ""  # nome do lugar onde a armadura está agora, ou ""


func adicionar(nome: String, pos: Vector3, raio: float) -> void:
	lista.append({"nome": nome, "pos": pos, "raio": raio, "visto": false})


## Cadastra os lugares do cânion de teste (scripts/teste_visual/canion.gd).
func do_canion(c: Canion) -> void:
	adicionar("Platô da Chegada", c.spawn, 45.0)
	adicionar("Queda do Véu", (c.lip + c.poco) * 0.5, 55.0)
	var p: Vector4 = c.pilares[1]
	adicionar("Vale dos Pilares", Vector3(p.x, 40.0, p.y), 80.0)
	adicionar("Ponte de Pedra", Vector3(c.centro_x(Canion.Z_PONTE), Canion.ALTO - 9.0, Canion.Z_PONTE), 60.0)


func descobertos() -> int:
	var n := 0
	for it in lista:
		if it["visto"]:
			n += 1
	return n


func total() -> int:
	return lista.size()


func _physics_process(_delta: float) -> void:
	if armadura == null:
		return
	var p := armadura.global_position
	# lugar mais próximo que contém a armadura
	var melhor := -1
	var melhor_d := INF
	for i in lista.size():
		var it := lista[i]
		var pos: Vector3 = it["pos"]
		var d := p.distance_to(pos)
		if d <= float(it["raio"]) and d < melhor_d:
			melhor = i
			melhor_d = d
	if melhor >= 0:
		var achado := lista[melhor]
		var nome: String = achado["nome"]
		if nome != atual:
			atual = nome
			var primeira: bool = not achado["visto"]
			achado["visto"] = true
			chegou.emit(nome, primeira)
		return
	# fora de todos os raios: continua no lugar atual até sair da folga de 15%
	if atual == "":
		return
	for it in lista:
		if it["nome"] == atual:
			var pos: Vector3 = it["pos"]
			if p.distance_to(pos) <= float(it["raio"]) * 1.15:
				return
	atual = ""
