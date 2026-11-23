# Mede, em cada conjunto do corpo, onde termina o antebraço no eixo do punho (z do gerador), para a boca do punho e a
# arma que sai dela ficarem rentes à ponta de cada luva (2026-11-23). Raios de baixo para cima numa grade do tamanho
# da boca do punho; vale o mais baixo (a placa fica toda por fora). Imprime o dicionário para `PUNHO_FIM` em
# scripts/melhorias_visual.gd.
# Uso: blender -b --factory-startup -P tools/vale/medir_punhos.py -- /tmp/x.png
import os
import sys

from mathutils import Vector
from mathutils.bvhtree import BVHTree

P = os.path.join(os.path.dirname(os.path.abspath(__file__)), "robo_pecas.py")
g = {"__name__": "medir", "__file__": P}
exec(compile(open(P, encoding="utf-8").read(), P, "exec"), g)  # noqa: S102 (os conjuntos, sem as folhas)
bpy, J = g["bpy"], g["J"]


def fim(x0):
    obs = [o for o in g["FEITAS"] if o.parent == J["luvaD"] and o.type == "MESH" and not o.hide_render]
    dg = bpy.context.evaluated_depsgraph_get()
    zs = []
    for dx in (-0.04, -0.02, 0.0, 0.02, 0.04):
        for dy in (-0.045, -0.022, 0.0, 0.022, 0.045):
            o0 = Vector((x0 + dx, -0.012 + dy, 0.15))
            for ob in obs:
                bvh = BVHTree.FromObject(ob.evaluated_get(dg), dg)
                mi = ob.matrix_world.inverted()
                hit = bvh.ray_cast(mi @ o0, (mi.to_3x3() @ Vector((0, 0, 1))).normalized(), 1.0)
                if hit[0] is not None:
                    z = (ob.matrix_world @ hit[0]).z
                    if z < 0.5:
                        zs.append(z)
    return min(zs) if zs else 0.345


linhas = []
for chave in g["CONJUNTOS"]:
    g["montar"](g["inteiro"](g["CONJUNTOS"][chave]))
    g["repouso"]()
    linhas.append('"%s": %.4f' % (chave, fim(-0.265)))
print("PUNHO_FIM := {" + ", ".join(linhas) + "}")
sys.stdout.flush()
os._exit(0)
