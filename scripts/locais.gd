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
