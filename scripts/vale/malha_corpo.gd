class_name MalhaCorpo
extends RefCounted
## Colisão fiel de um robô parado (2026-11-18): a própria malha do corpo, na pose em que ele está, vira a
## forma de colisão. O que se vê é o que barra e o que sustenta. Serve para quem não se mexe (os gigantes que
## dormem, os robôs velhos da Fundição, o Faísca caído); os que andam continuam com as formas simples deles.


## Os triângulos do corpo de um robô no mundo, na pose de agora: cada vértice das peças presas ao esqueleto
## é levado pelos ossos que o puxam (a conta que a placa de vídeo faz), e os extras, pelo osso de encaixe.
## Só a primeira superfície de cada peça: a segunda é a casca do contorno.
static func faces(raiz: Node3D, esq: Skeleton3D) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for peca: PackedVector3Array in por_peca(raiz, esq):
		tris.append_array(peca)
	return tris


## A versão simples, para robô pequeno caído que não precisa de detalhe: um casco convexo por peça do corpo
## (no máximo 64 pontos cada). Bem mais leve que a malha inteira.
static func cascos(raiz: Node3D, esq: Skeleton3D) -> Array[CollisionShape3D]:
	var lista: Array[CollisionShape3D] = []
	for peca: PackedVector3Array in por_peca(raiz, esq):
		if peca.size() < 12:
			continue
		var pts := PackedVector3Array()
		var salto := maxi(1, peca.size() / 64)
		var k := 0
		while k < peca.size():
			pts.append(peca[k])
			k += salto
		var f := ConvexPolygonShape3D.new()
		f.points = pts
		var cs := CollisionShape3D.new()
		cs.shape = f
		lista.append(cs)
	return lista


## Os triângulos de cada peça do corpo, no mundo (uma lista por peça).
static func por_peca(raiz: Node3D, esq: Skeleton3D) -> Array[PackedVector3Array]:
	var pecas: Array[PackedVector3Array] = []
	for no in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0 or not mi.visible:
			continue
		var arr := mi.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var mundo := PackedVector3Array()
		mundo.resize(vs.size())
		if esq != null and mi.skin != null and arr[Mesh.ARRAY_BONES] != null:
			var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var por_v := ossos.size() / vs.size()
			var mats: Array[Transform3D] = []
			for b in mi.skin.get_bind_count():
				var osso := mi.skin.get_bind_bone(b)
				if osso < 0:
					osso = esq.find_bone(mi.skin.get_bind_name(b))
				mats.append(esq.global_transform * esq.get_bone_global_pose(maxi(osso, 0)) * mi.skin.get_bind_pose(b))
			for k in vs.size():
				var soma := Vector3.ZERO
				var peso := 0.0
				for w in por_v:
					var pw := pesos[k * por_v + w]
					if pw > 0.0:
						soma += (mats[ossos[k * por_v + w]] * vs[k]) * pw
						peso += pw
				mundo[k] = soma / peso if peso > 0.0 else esq.global_transform * vs[k]
		else:
			# peça de encaixe: vai com o osso do BoneAttachment3D em que está pendurada
			var xf := mi.transform
			var pai := mi.get_parent()
			while pai != null and not (pai is BoneAttachment3D) and pai != esq and pai is Node3D:
				xf = (pai as Node3D).transform * xf
				pai = pai.get_parent()
			if esq != null and pai is BoneAttachment3D:
				xf = esq.global_transform * esq.get_bone_global_pose((pai as BoneAttachment3D).bone_idx) * xf
			else:
				xf = mi.global_transform
			for k in vs.size():
				mundo[k] = xf * vs[k]
		var tris := PackedVector3Array()
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			for i in idx as PackedInt32Array:
				tris.append(mundo[i])
		else:
			tris.append_array(mundo)
		pecas.append(tris)
	return pecas


## A forma de colisão pronta, a partir dos triângulos (vale dos dois lados das chapas).
static func forma(tris: PackedVector3Array) -> CollisionShape3D:
	var f := ConcavePolygonShape3D.new()
	f.backface_collision = true
	f.set_faces(tris)
	var cs := CollisionShape3D.new()
	cs.shape = f
	return cs
