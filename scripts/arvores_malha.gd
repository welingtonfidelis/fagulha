class_name ArvoresMalha
extends RefCounted
## Árvores de bloco da etapa 1 (tronco + cones ou copa redonda), com cor por vértice.
## Triângulos em sentido horário vistos de fora (a frente na Godot) e normais calculadas à mão.

static func _lin(r: int, g: int, b: int) -> Color:
	return Color8(r, g, b).srgb_to_linear()


static func conifera() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tronco := _lin(70, 50, 36)
	var folha := _lin(36, 62, 42)
	_cilindro(st, 0.0, 3.6, 0.38, 0.3, 6, tronco)
	_cone(st, 2.4, 7.5, 3.6, 7, folha)
	_cone(st, 6.0, 6.2, 2.8, 7, folha.lightened(0.04))
	_cone(st, 9.4, 5.2, 1.8, 7, folha.lightened(0.08))
	return st.commit()


static func folhosa() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tronco := _lin(78, 58, 40)
	var folha := _lin(58, 88, 36)
	_cilindro(st, 0.0, 5.5, 0.42, 0.32, 6, tronco)
	_esfera(st, Vector3(0, 8.3, 0), Vector3(4.4, 3.5, 4.4), 8, 5, folha)
	_esfera(st, Vector3(1.9, 9.6, 0.9), Vector3(2.8, 2.3, 2.8), 7, 4, folha.lightened(0.06))
	_esfera(st, Vector3(-1.6, 9.2, -1.2), Vector3(2.6, 2.1, 2.6), 7, 4, folha.darkened(0.05))
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, cor: Color) -> void:
	st.set_color(cor)
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


static func _cone(st: SurfaceTool, y0: float, altura: float, raio: float, lados: int, cor: Color) -> void:
	var topo := Vector3(0, y0 + altura, 0)
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		var p0 := Vector3(cos(a0) * raio, y0, sin(a0) * raio)
		var p1 := Vector3(cos(a1) * raio, y0, sin(a1) * raio)
		var n0 := Vector3(cos(a0) * altura, raio, sin(a0) * altura).normalized()
		var n1 := Vector3(cos(a1) * altura, raio, sin(a1) * altura).normalized()
		var nt := (n0 + n1).normalized()
		_tri(st, p0, p1, topo, n0, n1, nt, cor)
		# fundo do cone (visto de baixo)
		_tri(st, Vector3(0, y0, 0), p1, p0, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, cor.darkened(0.3))


static func _cilindro(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, lados: int, cor: Color) -> void:
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := d0 * r0 + Vector3(0, y0, 0)
		var b1 := d1 * r0 + Vector3(0, y0, 0)
		var t0 := d0 * r1 + Vector3(0, y1, 0)
		var t1 := d1 * r1 + Vector3(0, y1, 0)
		_tri(st, t0, b0, b1, d0, d0, d1, cor)
		_tri(st, t0, b1, t1, d0, d1, d1, cor)


static func _esfera(st: SurfaceTool, centro: Vector3, raio: Vector3, lados: int, aneis: int, cor: Color) -> void:
	for j in aneis:
		var f0 := PI * j / aneis
		var f1 := PI * (j + 1) / aneis
		for i in lados:
			var t0 := TAU * i / lados
			var t1 := TAU * (i + 1) / lados
			var u := [Vector3(sin(f0) * cos(t0), cos(f0), sin(f0) * sin(t0)),
				Vector3(sin(f0) * cos(t1), cos(f0), sin(f0) * sin(t1)),
				Vector3(sin(f1) * cos(t0), cos(f1), sin(f1) * sin(t0)),
				Vector3(sin(f1) * cos(t1), cos(f1), sin(f1) * sin(t1))]
			var p: Array[Vector3] = []
			for v in u:
				p.append(centro + Vector3(v.x * raio.x, v.y * raio.y, v.z * raio.z))
			# A em cima e à direita, B em cima à esquerda, C embaixo à direita, D embaixo à esquerda
			var face := ((p[0] + p[1] + p[2] + p[3]) * 0.25 - centro).normalized()
			var c := cor.darkened(0.04 * ((i * 7 + j * 3) % 3))
			if j < aneis - 1:  # no polo de baixo C e D coincidem
				_tri(st, p[0], p[2], p[3], face, face, face, c)
			if j > 0:  # no polo de cima A e B coincidem
				_tri(st, p[0], p[3], p[1], face, face, face, c)
