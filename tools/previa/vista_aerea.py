# Vista aérea de prévia (rascunho de planejamento, não é código do jogo).
# blender -b -P vista_aerea.py -- <mapa.npz> <saida.png> <largura> <altura> <cam_r> <cam_c> <cam_alt> <alvo_r> <alvo_c> <alvo_z> [cycles]
import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
NPZ, OUT = argv[0], argv[1]
RW, RH = int(argv[2]), int(argv[3])
CAM_R, CAM_C, CAM_ALT = float(argv[4]), float(argv[5]), float(argv[6])
ALV_R, ALV_C, ALV_Z = float(argv[7]), float(argv[8]), float(argv[9])
CYCLES = len(argv) > 10 and argv[10] == "cycles"

d = np.load(NPZ)
h, W, lake, river, forest, col = d["h"], d["W"], d["lake"], d["river"], d["forest"], d["col"]
DX0 = float(d["dx"])
N0 = h.shape[0]
F = 2
N = N0 * F
DX = DX0 / F
SIZE = N0 * DX0


def up(a):
    a = a.astype(np.float32)
    xs = np.linspace(0, N0 - 1, N)
    i0 = np.floor(xs).astype(int)
    i1 = np.minimum(i0 + 1, N0 - 1)
    t = (xs - i0).astype(np.float32)
    ex = (slice(None),) + (None,) * (a.ndim - 1)
    a = a[i0] * (1 - t)[ex] + a[i1] * t[ex]
    ex2 = (None, slice(None)) + (None,) * (a.ndim - 2)
    a = a[:, i0] * (1 - t)[ex2] + a[:, i1] * t[ex2]
    return a


hu = up(h)
Wu = up(W)
lk = up(lake.astype(float)) > 0.5
rv = up(river.astype(float)) > 0.3
fo = up(forest.astype(float))
cu = up(col)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)
scene = bpy.context.scene

HAZE = (0.60, 0.68, 0.76)


def fog_material(name, build):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = build(nt)
    cam = nt.nodes.new("ShaderNodeCameraData")
    mth = nt.nodes.new("ShaderNodeMath")
    mth.operation = "MULTIPLY"
    mth.inputs[1].default_value = -1.0 / 16000.0
    nt.links.new(cam.outputs["View Distance"], mth.inputs[0])
    ex = nt.nodes.new("ShaderNodeMath")
    ex.operation = "EXPONENT"
    nt.links.new(mth.outputs[0], ex.inputs[0])
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(ex.outputs[0], inv.inputs[1])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = HAZE + (1.0,)
    em.inputs["Strength"].default_value = 1.0
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(inv.outputs[0], mix.inputs[0])
    nt.links.new(bsdf.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def grid_mesh(name, z, extra=None):
    ys, xs = np.meshgrid(np.arange(N), np.arange(N), indexing="ij")
    verts = np.stack([xs * DX, (N - 1 - ys) * DX, z], -1).reshape(-1, 3).astype(np.float32)
    idx = np.arange(N * N).reshape(N, N)
    a, b = idx[:-1, :-1].ravel(), idx[:-1, 1:].ravel()
    c, e = idx[1:, 1:].ravel(), idx[1:, :-1].ravel()
    loops = np.stack([a, e, c, b], -1).ravel()
    nq = a.size
    me = bpy.data.meshes.new(name)
    me.vertices.add(N * N)
    me.vertices.foreach_set("co", verts.ravel())
    me.loops.add(nq * 4)
    me.loops.foreach_set("vertex_index", loops.astype(np.int32))
    me.polygons.add(nq)
    me.polygons.foreach_set("loop_start", np.arange(0, nq * 4, 4, dtype=np.int32))
    me.update(calc_edges=True)
    try:
        me.shade_smooth()
    except Exception:
        me.polygons.foreach_set("use_smooth", np.ones(nq, dtype=bool))
    if extra:
        extra(me)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


# terreno
def terr_attrs(me):
    ca = me.color_attributes.new("cor", "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([cu.reshape(-1, 3) ** 2.2, np.ones((N * N, 1), np.float32)], 1)
    ca.data.foreach_set("color", rgba.ravel())
    ys, xs = np.meshgrid(np.arange(N), np.arange(N), indexing="ij")
    cx, cy = CAM_C * F, CAM_R * F
    dist = np.hypot(xs - cx, ys - cy) * DX
    falloff = np.clip(1.4 - dist / 5000.0, 0.15, 1.0)
    base = np.clip(fo, 0, 1) * 0.010 * falloff
    conif = (hu > 520).astype(np.float32)
    for nome, v in (("dens_c", base * conif), ("dens_d", base * (1 - conif))):
        at = me.attributes.new(nome, "FLOAT", "POINT")
        at.data.foreach_set("value", v.ravel().astype(np.float32))


def terr_bsdf(nt):
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "cor"
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    p.inputs["Roughness"].default_value = 0.95
    nt.links.new(at.outputs["Color"], p.inputs["Base Color"])
    return p


terr = grid_mesh("terreno", hu, terr_attrs)
terr.data.materials.append(fog_material("m_terreno", terr_bsdf))

# água (lagos e rios); fora d'água a malha fica escondida embaixo do chão
wz = np.where(lk, Wu, np.where(rv, hu + 2.6, hu - 6.0))
agua = grid_mesh("agua", wz)


def agua_bsdf(nt):
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    p.inputs["Base Color"].default_value = (0.03, 0.07, 0.08, 1)
    p.inputs["Roughness"].default_value = 0.04
    return p


mat_agua = fog_material("m_agua", agua_bsdf)
agua.data.materials.append(mat_agua)
bpy.ops.mesh.primitive_plane_add(size=SIZE * 4, location=(SIZE / 2, SIZE / 2, 0.0))
bpy.context.active_object.data.materials.append(mat_agua)


# árvores
def tree_obj(name, kind, color):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.45, radius2=0.35, depth=4.0,
                          matrix=__import__("mathutils").Matrix.Translation((0, 0, 2.0)))
    if kind == "c":
        for k, (r, z, hh) in enumerate(((4.2, 7.5, 9.0), (3.2, 12.0, 8.0), (2.0, 16.0, 6.0))):
            bmesh.ops.create_cone(bm, cap_ends=True, segments=7, radius1=r, radius2=0.0, depth=hh,
                                  matrix=__import__("mathutils").Matrix.Translation((0, 0, z)))
    else:
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=5.2,
                                   matrix=__import__("mathutils").Matrix.Translation((0, 0, 9.0)))
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=3.6,
                                   matrix=__import__("mathutils").Matrix.Translation((2.6, 1.0, 11.0)))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)

    def bs(nt):
        info = nt.nodes.new("ShaderNodeObjectInfo")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = tuple(c * 0.75 for c in color) + (1,)
        ramp.color_ramp.elements[1].color = tuple(min(1, c * 1.35) for c in color) + (1,)
        nt.links.new(info.outputs["Random"], ramp.inputs["Fac"])
        p = nt.nodes.new("ShaderNodeBsdfPrincipled")
        p.inputs["Roughness"].default_value = 0.9
        nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
        return p

    me.materials.append(fog_material("m_" + name, bs))
    return ob


arv_c = tree_obj("pinheiro", "c", (0.030, 0.060, 0.040))
arv_d = tree_obj("folhosa", "d", (0.055, 0.095, 0.030))

ng = bpy.data.node_groups.new("mata", "GeometryNodeTree")
ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
gi = ng.nodes.new("NodeGroupInput")
go = ng.nodes.new("NodeGroupOutput")
join = ng.nodes.new("GeometryNodeJoinGeometry")
ng.links.new(gi.outputs[0], join.inputs[0])
for i, (attr, obj) in enumerate((("dens_c", arv_c), ("dens_d", arv_d))):
    na = ng.nodes.new("GeometryNodeInputNamedAttribute")
    na.data_type = "FLOAT"
    na.inputs["Name"].default_value = attr
    dist = ng.nodes.new("GeometryNodeDistributePointsOnFaces")
    dist.distribute_method = "RANDOM"
    ng.links.new(gi.outputs[0], dist.inputs["Mesh"])
    ng.links.new(na.outputs[0], dist.inputs["Density"])
    dist.inputs["Seed"].default_value = 3 + i
    oi = ng.nodes.new("GeometryNodeObjectInfo")
    oi.inputs["Object"].default_value = obj
    inst = ng.nodes.new("GeometryNodeInstanceOnPoints")
    rnd = ng.nodes.new("FunctionNodeRandomValue")
    rnd.data_type = "FLOAT"
    for sk in rnd.inputs:
        if sk.type == "VALUE" and sk.name == "Min":
            sk.default_value = 0.65
        if sk.type == "VALUE" and sk.name == "Max":
            sk.default_value = 1.35
    rnd_out = [sk for sk in rnd.outputs if sk.type == "VALUE"][0]
    ng.links.new(dist.outputs["Points"], inst.inputs["Points"])
    ng.links.new(oi.outputs["Geometry"], inst.inputs["Instance"])
    ng.links.new(rnd_out, inst.inputs["Scale"])
    ng.links.new(inst.outputs[0], join.inputs[0])
ng.links.new(join.outputs[0], go.inputs[0])
mod = terr.modifiers.new("mata", "NODES")
mod.node_group = ng

# luz e céu
sun_d = bpy.data.lights.new("sol", "SUN")
sun_d.energy = 3.2
sun_d.color = (1.0, 0.93, 0.82)
sun_d.angle = math.radians(1.0)
sun = bpy.data.objects.new("sol", sun_d)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(69), 0, math.radians(-60))
world = scene.world or bpy.data.worlds.new("mundo")
scene.world = world
world.use_nodes = True
wn = world.node_tree
wn.nodes.clear()
wo = wn.nodes.new("ShaderNodeOutputWorld")
bg = wn.nodes.new("ShaderNodeBackground")
grad = wn.nodes.new("ShaderNodeTexCoord")
sep = wn.nodes.new("ShaderNodeSeparateXYZ")
ramp = wn.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = HAZE + (1,)
ramp.color_ramp.elements[1].position = 0.35
ramp.color_ramp.elements[1].color = (0.25, 0.42, 0.66, 1)
wn.links.new(grad.outputs["Generated"], sep.inputs[0])
wn.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
wn.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 1.0
wn.links.new(bg.outputs[0], wo.inputs[0])

# câmera
cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 22
cam_d.clip_start = 1.0
cam_d.clip_end = 30000
cam = bpy.data.objects.new("cam", cam_d)
scene.collection.objects.link(cam)
scene.camera = cam


def world_xy(r, c):
    return c * DX0, (N0 - r) * DX0


cx, cy = world_xy(CAM_R, CAM_C)
gz = float(hu[int(CAM_R * F), int(CAM_C * F)])
cam.location = (cx, cy, gz + CAM_ALT)
tx, ty = world_xy(ALV_R, ALV_C)
dirv = Vector((tx, ty, ALV_Z)) - cam.location
cam.rotation_euler = dirv.to_track_quat("-Z", "Y").to_euler()
print("cam chão", gz, "local", tuple(cam.location))

scene.render.resolution_x = RW
scene.render.resolution_y = RH
scene.render.film_transparent = False
try:
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
except Exception:
    pass
if CYCLES:
    scene.render.engine = "CYCLES"
    scene.cycles.device = "GPU"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "METAL"
    prefs.get_devices()
    for dv in prefs.devices:
        dv.use = True
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
else:
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 32
        scene.eevee.use_shadows = True
        scene.eevee.use_raytracing = True
    except Exception as e:
        print("eevee", e)
import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "marcos_bloco.py")).read())
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
if ROTULOS:
    import blf
    import imbuf
    from bpy_extras.object_utils import world_to_camera_view
    ib = imbuf.load(OUT)
    fb = blf.load("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
    fr = blf.load("/System/Library/Fonts/Supplemental/Arial.ttf")
    with blf.bind_imbuf(fb, ib), blf.bind_imbuf(fr, ib):
        for nome, p, dist in ROTULOS:
            uv = world_to_camera_view(scene, cam, Vector(p))
            px, py = uv.x * RW, uv.y * RH
            print("rotulo", nome, round(px), round(py))
            for f, txt, size, dy in ((fb, nome, 22, 28), (fr, ("%.1f km" % (dist / 1000)).replace(".", ","), 17, 8)):
                blf.size(f, size)
                w, _ = blf.dimensions(f, txt)
                x0 = min(max(px - w / 2, 10), RW - w - 10)
                blf.color(f, 0, 0, 0, 0.7)
                blf.position(f, x0 + 1.5, py + dy - 1.5, 0)
                blf.draw_buffer(f, txt)
                blf.color(f, 1, 1, 0.96, 1)
                blf.position(f, x0, py + dy, 0)
                blf.draw_buffer(f, txt)
    imbuf.write(ib, filepath=OUT)
print("ok", OUT)
