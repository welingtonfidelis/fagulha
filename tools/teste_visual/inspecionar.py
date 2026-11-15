# Lista objetos, triângulos e materiais de cada glTF baixado (rascunho do teste visual).
import bpy, sys, os, glob
base = sys.argv[sys.argv.index("--") + 1]
for g in sorted(glob.glob(os.path.join(base, "*", "*.gltf"))):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=g)
    tris = 0
    mats = set()
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            me = ob.data
            tris += sum(len(p.vertices) - 2 for p in me.polygons)
            for m in me.materials:
                if m:
                    mats.add("%s(%s)" % (m.name, getattr(m, "surface_render_method", "")))
    dims = [ob.dimensions for ob in bpy.context.scene.objects if ob.type == "MESH"]
    print("MODELO", os.path.basename(g), "tris", tris, "objs", len(dims), "mats", ",".join(sorted(mats))[:150])
