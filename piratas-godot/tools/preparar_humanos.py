#!/usr/bin/env python3
"""Prepara os personagens "Universal Base Characters" (Quaternius, CC0) para o celular.

- marca cada vértice do corpo com a parte do corpo (COLOR_0.r = parte / 10: 0 pele, 1 tronco, 2 braço, 3 perna),
  a partir do osso dominante, e guarda a posição de repouso em COLOR_0.gba (o shader recorta as roupas por pixel)
- guarda só as animações usadas no jogo (só no modelo masculino; a mulher usa as mesmas),
  só com rotações (e a translação da bacia), o que reduz muito o arquivo
- tira do .glb as texturas do corpo (gravadas à parte em 1024 px) e reduz as outras.

uso: python3 tools/preparar_humanos.py PASTA_ORIGINAIS assets/humans
"""
import io, json, struct, sys, os
import numpy as np
from PIL import Image

KEEP = ["Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Death01", "Sitting_Idle_Loop", "Idle_Talking_Loop",
        "Punch_Jab", "Sword_Attack", "Sword_Idle", "Sword_Regular_A", "Sword_Regular_B", "Sword_Block", "Hit_Chest",
        "Hit_Knockback", "Dance_Loop", "Consume", "Idle_FoldArms_Loop", "Interact", "Walk_Formal_Loop", "Yes",
        "Idle_Rail_Loop", "Pistol_Idle_Loop", "Pistol_Shoot", "Idle_Lantern_Loop", "Walk_Carry_Loop", "Crouch_Idle_Loop"]
NP = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8, 5122: np.int16, 5120: np.int8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path):
    b = open(path, "rb").read()
    l = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + l])
    bl = struct.unpack("<I", b[20 + l:24 + l])[0]
    return j, b[28 + l:28 + l + bl]


def acc(j, binb, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = NC[a["type"]]
    dt = np.dtype(NP[a["componentType"]])
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0)
    if stride and stride != dt.itemsize * n:
        raw = np.frombuffer(binb, dtype=np.uint8, count=stride * a["count"], offset=off).reshape(a["count"], stride)
        return raw[:, :dt.itemsize * n].copy().view(dt).reshape(a["count"], n)
    return np.frombuffer(binb, dtype=dt, count=a["count"] * n, offset=off).reshape(a["count"], n).copy()


class Out:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accs = []

    def view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        v = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            v["target"] = target
        self.bin += data
        self.views.append(v)
        return len(self.views) - 1

    def acc(self, arr, ctype, typ, target=None, minmax=False, normalized=False):
        arr = np.ascontiguousarray(arr)
        v = self.view(arr.tobytes(), target)
        a = {"bufferView": v, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
        if normalized:
            a["normalized"] = True
        if minmax:
            a["min"] = [float(x) for x in arr.reshape(arr.shape[0], -1).min(0)]
            a["max"] = [float(x) for x in arr.reshape(arr.shape[0], -1).max(0)]
        self.accs.append(a)
        return len(self.accs) - 1


def regions(pos, joints, weights, jnames):
    """Parte do corpo de cada vértice (0 pele, 1 tronco, 2 braço, 3 perna) pelo osso dominante.
    O shader decide os detalhes (colete, punho, joelho, sapato) por pixel com a posição de repouso."""
    dom = joints[np.arange(len(joints)), np.argmax(weights, axis=1)]
    reg = np.zeros(len(pos), np.float32)
    for i, d in enumerate(dom):
        nm = jnames[d]
        if nm.startswith("spine") or nm.startswith("clavicle"):
            reg[i] = 1
        elif nm.startswith("upperarm") or nm.startswith("lowerarm"):
            reg[i] = 2
        elif nm == "pelvis" or nm.startswith("thigh") or nm.startswith("calf") or nm.startswith("foot") or nm.startswith("ball"):
            reg[i] = 3
    return reg


def smooth_normals(pos, nrm):
    """Normais iguais nos vértices duplicados das costuras: a roupa "inflada" não abre buracos."""
    key = np.round(pos / 1e-4).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    acc_n = np.zeros((inv.max() + 1, 3), np.float64)
    np.add.at(acc_n, inv, nrm)
    out = acc_n[inv]
    out /= np.maximum(np.linalg.norm(out, axis=1, keepdims=True), 1e-9)
    return out.astype(np.float32)


def img_bytes(j, binb, idx):
    im = j["images"][idx]
    bv = j["bufferViews"][im["bufferView"]]
    o = bv.get("byteOffset", 0)
    return binb[o:o + bv["byteLength"]]


def process(src, dst_dir, tag, keep_anims):
    j, binb = load(src)
    out = Out()
    jnames = [j["nodes"][k]["name"] for k in j["skins"][0]["joints"]]
    # texturas: corpo à parte; o resto pequeno dentro do .glb
    body_mat = [i for i, m in enumerate(j["materials"]) if "Superhero" in m["name"]][0]
    bm = j["materials"][body_mat]
    def tex_img(t):
        return j["textures"][t["index"]]["source"]
    alb = Image.open(io.BytesIO(img_bytes(j, binb, tex_img(bm["pbrMetallicRoughness"]["baseColorTexture"])))).convert("RGB")
    nrm = Image.open(io.BytesIO(img_bytes(j, binb, tex_img(bm["normalTexture"])))).convert("RGB")
    alb.resize((1024, 1024), Image.LANCZOS).save(os.path.join(dst_dir, "corpo_%s_cor.jpg" % tag), quality=90)
    nrm.resize((1024, 1024), Image.LANCZOS).save(os.path.join(dst_dir, "corpo_%s_normal.png" % tag), optimize=True)
    a = np.asarray(alb.resize((256, 256))).reshape(-1, 3) / 255.0
    # cor média da pele (para o tom de pele no shader)
    print(tag, "cor média", a.mean(0))
    new_images, img_map = [], {}
    for mi, m in enumerate(j["materials"]):
        if mi == body_mat:
            continue
        for key in ["baseColorTexture"]:
            t = m.get("pbrMetallicRoughness", {}).get(key)
            if t:
                s = tex_img(t)
                if s not in img_map:
                    im = Image.open(io.BytesIO(img_bytes(j, binb, s)))
                    im = im.resize((min(256, im.width), min(256, im.height)), Image.LANCZOS)
                    bio = io.BytesIO()
                    im.save(bio, "PNG", optimize=True)
                    img_map[s] = len(new_images)
                    new_images.append({"name": j["images"][s].get("name", "img%d" % s), "mimeType": "image/png",
                                       "bufferView": out.view(bio.getvalue())})
    textures, materials = [], []
    for mi, m in enumerate(j["materials"]):
        nm = {"name": m["name"], "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 0.6}}
        if "alphaMode" in m:
            nm["alphaMode"] = m["alphaMode"]
        if "alphaCutoff" in m:
            nm["alphaCutoff"] = m["alphaCutoff"]
        if m.get("doubleSided"):
            nm["doubleSided"] = True
        t = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if mi != body_mat and t:
            textures.append({"source": img_map[tex_img(t)]})
            nm["pbrMetallicRoughness"]["baseColorTexture"] = {"index": len(textures) - 1}
        materials.append(nm)
    # malhas
    meshes = []
    for m in j["meshes"]:
        prims = []
        for p in m["primitives"]:
            at = p["attributes"]
            pos = acc(j, binb, at["POSITION"]).astype(np.float32)
            jo = acc(j, binb, at["JOINTS_0"])
            we = acc(j, binb, at["WEIGHTS_0"])
            if we.dtype != np.float32:
                we = we.astype(np.float32) / np.iinfo(we.dtype).max
            nrm = acc(j, binb, at["NORMAL"]).astype(np.float32)
            if p.get("material") == body_mat:
                nrm = smooth_normals(pos, nrm)
            na = {"POSITION": out.acc(pos, 5126, "VEC3", 34962, True),
                  "NORMAL": out.acc(nrm, 5126, "VEC3", 34962),
                  "TEXCOORD_0": out.acc(acc(j, binb, at["TEXCOORD_0"]).astype(np.float32), 5126, "VEC2", 34962),
                  "JOINTS_0": out.acc(jo.astype(np.uint16), 5123, "VEC4", 34962),
                  "WEIGHTS_0": out.acc(we.astype(np.float32), 5126, "VEC4", 34962)}
            if p.get("material") == body_mat:
                reg = regions(pos, jo, we, jnames)
                col = np.zeros((len(pos), 4), np.float32)
                col[:, 0] = reg / 10.0
                col[:, 1] = (pos[:, 0] + 1.0) * 0.5   # posição de repouso (espaço do modelo, frente = +Z)
                col[:, 2] = pos[:, 1] * 0.5
                col[:, 3] = pos[:, 2] + 0.5
                na["COLOR_0"] = out.acc(col, 5126, "VEC4", 34962)
                print(tag, "regiões", np.bincount(reg.astype(int)))
            idx = acc(j, binb, p["indices"]).astype(np.uint16 if len(pos) < 65535 else np.uint32).reshape(-1)
            prims.append({"attributes": na, "indices": out.acc(idx.reshape(-1, 1), 5123 if idx.dtype == np.uint16 else 5125, "SCALAR", 34963),
                          "material": p.get("material", 0)})
        meshes.append({"name": m["name"], "primitives": prims})
    # pele (skin)
    sk = j["skins"][0]
    skins = [{"name": sk.get("name", "Armature"), "joints": sk["joints"],
              "inverseBindMatrices": out.acc(acc(j, binb, sk["inverseBindMatrices"]).astype(np.float32), 5126, "MAT4")}]
    # animações
    anims, seen = [], set()
    if keep_anims:
        for an in j["animations"]:
            if an["name"] not in KEEP or an["name"] in seen:
                continue
            seen.add(an["name"])
            samplers, channels, cache = [], [], {}
            for ch in an["channels"]:
                tgt = ch["target"]
                path = tgt["path"]
                nname = j["nodes"][tgt["node"]]["name"]
                if path == "scale" or (path == "translation" and nname != "pelvis"):
                    continue
                s = an["samplers"][ch["sampler"]]
                inp = acc(j, binb, s["input"]).astype(np.float32)
                outp = acc(j, binb, s["output"]).astype(np.float32)
                if path == "rotation" and np.allclose(outp, outp[0], atol=1e-4):
                    inp, outp = inp[:1], outp[:1]
                key = s["input"] if len(inp) > 1 else -1
                if key not in cache:
                    cache[key] = out.acc(inp, 5126, "SCALAR", None, True)
                samplers.append({"input": cache[key], "output": out.acc(outp, 5126, "VEC4" if path == "rotation" else "VEC3"),
                                 "interpolation": s.get("interpolation", "LINEAR")})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": tgt["node"], "path": path}})
            anims.append({"name": an["name"], "samplers": samplers, "channels": channels})
        print(tag, "animações", len(anims), sorted(seen))
    nodes = []
    for n in j["nodes"]:
        nn = {k: v for k, v in n.items() if k in ("name", "children", "translation", "rotation", "scale", "mesh", "skin")}
        nodes.append(nn)
    g = {"asset": {"version": "2.0", "generator": "preparar_humanos.py"}, "scene": 0, "scenes": j["scenes"], "nodes": nodes,
         "meshes": meshes, "skins": skins, "materials": materials, "accessors": out.accs, "bufferViews": out.views,
         "buffers": [{"byteLength": len(out.bin)}]}
    if textures:
        g["textures"] = textures
        g["images"] = new_images
        g["samplers"] = [{}]
        for t in textures:
            t["sampler"] = 0
    if anims:
        g["animations"] = anims
    js = json.dumps(g, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    while len(out.bin) % 4:
        out.bin.append(0)
    total = 12 + 8 + len(js) + 8 + len(out.bin)
    with open(os.path.join(dst_dir, "humano_%s.glb" % tag), "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(out.bin), 0x004E4942) + bytes(out.bin))
    print(tag, "->", total // 1024, "KB")


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    process(os.path.join(src, "human_male.glb"), dst, "m", True)
    process(os.path.join(src, "human_female.glb"), dst, "f", False)
