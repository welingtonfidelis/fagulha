# Bloco inserido no vista_aerea.py antes do render quando MARCOS=1 (rascunho, não é código do jogo).
import os
import random

import mathutils

MARCOS = os.environ.get("MARCOS") == "1"
ROTULOS = []
if MARCOS:
    Mt = mathutils.Matrix.Translation
    cam_xy = Vector((cam.location.x, cam.location.y))
    fwd = Vector((dirv.x, dirv.y)).normalized()
    right = Vector((fwd.y, -fwd.x))

    def ponto(a_deg, dist):
        a = math.radians(a_deg)
        p = cam_xy + dist * (math.cos(a) * fwd + math.sin(a) * right)
        c = int(np.clip(p.x / DX, 0, N - 1))
        r = int(np.clip(N - 1 - p.y / DX, 0, N - 1))
        return p.x, p.y, float(hu[r, c])

    def cor(rgb, rough=0.9):
        def b(nt):
            p = nt.nodes.new("ShaderNodeBsdfPrincipled")
            p.inputs["Base Color"].default_value = tuple(rgb) + (1,)
            p.inputs["Roughness"].default_value = rough
            return p
        return b

    def objeto(nome, bm, mat):
        me = bpy.data.meshes.new(nome)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(nome, me)
        scene.collection.objects.link(ob)
        me.materials.append(mat)
        return ob

    def volume(nome, rgb, dens, emis=0.0):
        m = bpy.data.materials.new(nome)
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        v = nt.nodes.new("ShaderNodeVolumePrincipled")
        v.inputs["Color"].default_value = tuple(rgb) + (1,)
        v.inputs["Density"].default_value = dens
        if not emis:
            tc = nt.nodes.new("ShaderNodeTexCoord")
            nz = nt.nodes.new("ShaderNodeTexNoise")
            nz.inputs["Scale"].default_value = 0.012
            nz.inputs["Detail"].default_value = 6.0
            nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
            mul = nt.nodes.new("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            mul.inputs[1].default_value = dens * 2.2
            sub = nt.nodes.new("ShaderNodeMath")
            sub.operation = "SUBTRACT"
            sub.inputs[1].default_value = 0.35
            nt.links.new(nz.outputs["Fac"], sub.inputs[0])
            nt.links.new(sub.outputs[0], mul.inputs[0])
            nt.links.new(mul.outputs[0], v.inputs["Density"])
        if emis:
            v.inputs["Emission Strength"].default_value = emis
            v.inputs["Emission Color"].default_value = tuple(rgb) + (1,)
        nt.links.new(v.outputs[0], out.inputs["Volume"])
        return m

    rnd = random.Random(4)

    # 1. árvore colossal
    x, y, z = ponto(24, 1400)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=14, radius2=6, depth=130, matrix=Mt((x, y, z + 60)))
    objeto("tronco_colossal", bm, fog_material("m_tronco", cor((0.10, 0.07, 0.05))))
    bm = bmesh.new()
    for ox, oy, oz, r in ((0, 0, 130, 62), (48, 18, 116, 42), (-46, -14, 118, 40), (10, -40, 138, 38), (-14, 42, 136, 36), (0, 0, 150, 40)):
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r,
                                   matrix=Mt((x + ox, y + oy, z + oz)) @ mathutils.Matrix.Diagonal((1, 1, 0.45, 1)))
    objeto("copa_colossal", bm, fog_material("m_copa", cor((0.025, 0.06, 0.03))))
    ROTULOS.append(("Árvore colossal", (x, y, z + 172), 1400))

    # 2. torre em ruínas (topo quebrado)
    x, y, z = ponto(-22, 1350)
    pedra = fog_material("m_pedra", cor((0.33, 0.31, 0.28)))
    for ox, oy, alt, raio in ((0, 0, 175, 16), (55, 30, 95, 10)):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=False, segments=14, radius1=raio, radius2=raio * 0.8, depth=alt,
                              matrix=Mt((x + ox, y + oy, z + alt / 2 - 12)))
        for v in bm.verts:
            if v.co.z > z + alt * 0.4:
                v.co.z -= rnd.uniform(0, alt * 0.28)
        objeto("torre", bm, pedra)
    ROTULOS.append(("Torre em ruínas", (x, y, z + 185), 1350))

    # 4. coluna de fumaça
    x, y, z = ponto(24, 4600)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=30, radius2=230, depth=1150,
                          matrix=Mt((x, y, z + 575)) @ mathutils.Matrix.Rotation(math.radians(9), 4, "X"))
    objeto("fumaca", bm, volume("m_fumaca", (0.42, 0.42, 0.43), 0.0055))
    ROTULOS.append(("Fumaça no vale", (x + 60, y, z + 1200), 4600))

    # 5. feixe de luz atrás da serra
    x, y, z = ponto(-9, 6600)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=9, radius2=9, depth=2000, matrix=Mt((x, y, z + 1000)))
    m = bpy.data.materials.new("m_feixe")
    m.use_nodes = True
    em = m.node_tree.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.70, 0.90, 1.0, 1)
    em.inputs["Strength"].default_value = 30.0
    for nd in list(m.node_tree.nodes):
        if nd.type == "BSDF_PRINCIPLED":
            m.node_tree.nodes.remove(nd)
    outn = [nd for nd in m.node_tree.nodes if nd.type == "OUTPUT_MATERIAL"][0]
    m.node_tree.links.new(em.outputs[0], outn.inputs["Surface"])
    objeto("feixe", bm, m)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=55, radius2=55, depth=2000, matrix=Mt((x, y, z + 1000)))
    objeto("halo", bm, volume("m_halo", (0.70, 0.90, 1.0), 0.0004, emis=0.5))
    ROTULOS.append(("Sinal de luz", (x, y, z + 2040), 6600))

    try:
        scene.eevee.volumetric_start = 1.0
        scene.eevee.volumetric_end = 14000.0
        scene.eevee.volumetric_tile_size = "4"
        scene.eevee.volumetric_samples = 96
    except Exception as e:
        print("vol", e)
