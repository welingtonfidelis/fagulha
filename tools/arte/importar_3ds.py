# Lê um .3ds (o formato antigo do 3D Studio) no Blender, que desde a 4.2 não traz mais esse leitor. Pega a malha,
# as UVs e os materiais (cor difusa e a textura difusa, se o arquivo estiver na pasta); as animações ficam de fora.
# Os vértices do .3ds já vêm na posição do mundo, então os objetos saem com a origem no zero.
#
#   import importar_3ds
#   objs = importar_3ds.importar("/caminho/arquivo.3ds")
import os
import struct

import bpy


def _texto(dados, i):
    fim = dados.index(b"\0", i)
    return dados[i:fim].decode("latin-1"), fim + 1


def _pedacos(dados, i, fim):
    # cada pedaço: id (2 bytes), tamanho com o cabeçalho (4 bytes), conteúdo
    while i + 6 <= fim:
        cid, tam = struct.unpack_from("<HI", dados, i)
        if tam < 6 or i + tam > fim:
            break
        yield cid, i + 6, i + tam
        i += tam


def _achar_arquivo(pasta, nome):
    alvo = os.path.basename(nome.replace("\\", "/")).lower()
    for raiz, _, arquivos in os.walk(pasta):
        for a in arquivos:
            if a.lower() == alvo:
                return os.path.join(raiz, a)
    return None


def _material(nome, cor, textura, pasta):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in cor]
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    arquivo = _achar_arquivo(pasta, textura) if textura else None
    if arquivo:
        img = m.node_tree.nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(arquivo, check_existing=True)
        m.node_tree.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
    elif textura:
        print("importar_3ds: a textura %s do material %s não está na pasta" % (textura, nome))
    return m


def importar(caminho, colecao=None):
    with open(caminho, "rb") as f:
        dados = f.read()
    pasta = os.path.dirname(os.path.abspath(caminho))
    colecao = colecao or bpy.context.scene.collection
    mats = {}
    objs = []

    def ler_material(i, fim):
        nome, cor, textura = "material", (0.8, 0.8, 0.8), None
        for cid, a, b in _pedacos(dados, i, fim):
            if cid == 0xA000:
                nome, _ = _texto(dados, a)
            elif cid == 0xA020:
                for c2, a2, _ in _pedacos(dados, a, b):
                    if c2 in (0x0011, 0x0012):
                        cor = tuple(x / 255.0 for x in dados[a2:a2 + 3])
                        break
                    if c2 in (0x0010, 0x0013):
                        cor = struct.unpack_from("<3f", dados, a2)
                        break
            elif cid == 0xA200:
                for c2, a2, _ in _pedacos(dados, a, b):
                    if c2 == 0xA300:
                        textura, _ = _texto(dados, a2)
        mats[nome] = _material(nome, cor, textura, pasta)

    def ler_malha(nome, i, fim):
        verts, faces, uvs, grupos = [], [], [], []
        for cid, a, b in _pedacos(dados, i, fim):
            if cid == 0x4110:
                n = struct.unpack_from("<H", dados, a)[0]
                v = struct.unpack_from("<%df" % (3 * n), dados, a + 2)
                verts = [v[k:k + 3] for k in range(0, 3 * n, 3)]
            elif cid == 0x4120:
                n = struct.unpack_from("<H", dados, a)[0]
                f = struct.unpack_from("<%dH" % (4 * n), dados, a + 2)
                faces = [f[k:k + 3] for k in range(0, 4 * n, 4)]
                for c2, a2, _ in _pedacos(dados, a + 2 + 8 * n, b):
                    if c2 == 0x4130:
                        mnome, j = _texto(dados, a2)
                        m = struct.unpack_from("<H", dados, j)[0]
                        grupos.append((mnome, struct.unpack_from("<%dH" % m, dados, j + 2)))
            elif cid == 0x4140:
                n = struct.unpack_from("<H", dados, a)[0]
                u = struct.unpack_from("<%df" % (2 * n), dados, a + 2)
                uvs = [u[k:k + 2] for k in range(0, 2 * n, 2)]
        if not verts or not faces:
            return
        me = bpy.data.meshes.new(nome)
        me.from_pydata(verts, [], faces)
        if len(uvs) == len(verts):
            camada = me.uv_layers.new(name="UVMap")
            for laco in me.loops:
                camada.data[laco.index].uv = uvs[laco.vertex_index]
        indice = {}
        for mnome, lista in grupos:
            if mnome not in indice and mnome in mats:
                indice[mnome] = len(me.materials)
                me.materials.append(mats[mnome])
            for fi in lista:
                if fi < len(me.polygons) and mnome in indice:
                    me.polygons[fi].material_index = indice[mnome]
        me.validate()
        ob = bpy.data.objects.new(nome, me)
        colecao.objects.link(ob)
        objs.append(ob)

    def percorrer(i, fim):
        for cid, a, b in _pedacos(dados, i, fim):
            if cid in (0x4D4D, 0x3D3D):
                percorrer(a, b)
            elif cid == 0xAFFF:
                ler_material(a, b)
            elif cid == 0x4000:
                nome, j = _texto(dados, a)
                for c2, a2, b2 in _pedacos(dados, j, b):
                    if c2 == 0x4100:
                        ler_malha(nome, a2, b2)

    percorrer(0, len(dados))
    return objs
