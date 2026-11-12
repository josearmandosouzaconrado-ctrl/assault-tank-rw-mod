#!/usr/bin/env python3
"""Gera os dados do mapa do Caribe a partir do Natural Earth (domínio público).

Saídas (em ../data):
  caribe_sdf.bin   — distância com sinal até a costa, em metros (int16, N×N), positiva em terra
  caribe_label.bin — índice da massa de terra de cada pixel (uint16, N×N, 0 = mar)
  caribe_info.json — massas de terra (nome, centro, raio, área) e parâmetros da projeção
  caribe_mapa.png  — imagem do mapa (cores) para o mapa e o minimapa
  caribe_raso.png  — mapa de águas rasas (turquesa) para o oceano

Uso: python3 gerar_mapa.py ne_10m_land.geojson ne_10m_minor_islands.geojson
"""
import json, math, sys, os, gzip
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from shapely.geometry import shape, Polygon, MultiPolygon, box
from shapely import affinity

HALF = 12000.0           # meia largura do mundo (m)
N = 1536                 # resolução da grade
LON0, LAT0 = -78.5, 19.5
SPAN = 36.0              # graus (lat) cobertos pelo quadrado
K = 2 * HALF / SPAN      # metros por grau
COSL = math.cos(math.radians(LAT0))
PX = 2 * HALF / N        # metros por pixel

def proj(lon, lat):
    return ((lon - LON0) * COSL * K, -(lat - LAT0) * K)

KNOWN = {
    "Cuba": (-79.5, 21.8), "Hispaniola": (-71.0, 19.0), "Jamaica": (-77.3, 18.1), "Porto Rico": (-66.5, 18.2),
    "América": (-88.0, 15.5), "América do Norte": (-82.0, 30.5), "Andros": (-78.0, 24.4),
    "Nova Providência": (-77.35, 25.05), "Grande Bahama": (-78.5, 26.6), "Ábaco": (-77.2, 26.4),
    "Eleuthera": (-76.2, 25.1), "Tortuga": (-72.8, 20.05), "Martinica": (-61.0, 14.65), "Guadalupe": (-61.55, 16.2),
    "Barbados": (-59.55, 13.15), "Santa Lúcia": (-60.97, 13.9), "Antígua": (-61.8, 17.07), "Sint Eustatius": (-62.97, 17.49),
    "Curaçao": (-68.95, 12.17), "Aruba": (-69.97, 12.52), "Granada": (-61.67, 12.12), "Trinidad": (-61.3, 10.45),
    "Grande Caimã": (-81.25, 19.32), "Ilha de Pinos": (-82.8, 21.7), "Cozumel": (-86.9, 20.4), "Dominica": (-61.37, 15.41),
    "São Vicente": (-61.2, 13.25), "Margarita": (-63.9, 11.0), "São Cristóvão": (-62.75, 17.3), "Ilhas Virgens": (-64.7, 18.35),
    "Inágua": (-73.4, 21.1), "Caicos": (-71.9, 21.8), "Exuma": (-76.1, 23.6), "Bonaire": (-68.25, 12.15), "Tobago": (-60.7, 11.25),
}

def load(paths):
    polys = []
    clip = box(LON0 - SPAN / 2 / COSL - 1, LAT0 - SPAN / 2 - 1, LON0 + SPAN / 2 / COSL + 1, LAT0 + SPAN / 2 + 1)
    for p in paths:
        gj = json.load(open(p))
        for f in gj["features"]:
            g = shape(f["geometry"])
            if not g.intersects(clip):
                continue
            g = g.intersection(clip)
            for part in (g.geoms if hasattr(g, "geoms") else [g]):
                if isinstance(part, Polygon) and part.area > 0:
                    polys.append(part)
    return polys

def to_world(poly):
    ext = [proj(x, y) for x, y in poly.exterior.coords]
    return Polygon(ext)

def main():
    polys = [to_world(p) for p in load(sys.argv[1:])]
    out = []
    for p in polys:
        minx, miny, maxx, maxy = p.bounds
        ext = max(maxx - minx, maxy - miny)
        if ext < 900.0:
            f = min(max((900.0 / max(ext, 1.0)) ** 0.6, 1.0), 2.6)
            p = affinity.scale(p, f, f, origin="centroid")
        if p.area < 30 * 30:
            continue
        out.append(p)
    img = Image.new("L", (N, N), 0)
    dr = ImageDraw.Draw(img)
    def to_px(x, z):
        return ((x + HALF) / PX, (z + HALF) / PX)
    for p in out:
        dr.polygon([to_px(x, z) for x, z in p.exterior.coords], fill=255)
    land = np.array(img) > 127
    d_in = ndimage.distance_transform_edt(land) * PX
    d_out = ndimage.distance_transform_edt(~land) * PX
    sd = np.where(land, d_in - PX * 0.5, -(d_out - PX * 0.5))
    sd = np.clip(sd, -2000, 30000).astype(np.int16)
    here = os.path.dirname(os.path.abspath(__file__))
    data = os.path.join(here, "..", "data")
    os.makedirs(data, exist_ok=True)
    with open(os.path.join(data, "caribe_sdf.bin"), "wb") as fh:
        fh.write(gzip.compress(sd.astype("<i2").tobytes(), 9))
    lab, n = ndimage.label(land, structure=np.ones((3, 3)))
    with open(os.path.join(data, "caribe_label.bin"), "wb") as fh:
        fh.write(gzip.compress(lab.astype("<u2").tobytes(), 9))
    known = {name: proj(*ll) for name, ll in KNOWN.items()}
    info = {"half": HALF, "n": N, "lon0": LON0, "lat0": LAT0, "k": K, "cos": COSL, "lands": []}
    rng = np.random.default_rng(7)
    a_names = ["Ilha", "Cayo", "Isla", "Île", "Ilhéu", "Key"]
    b_names = ["das Tartarugas", "do Caveira", "Serpiente", "aux Perles", "do Náufrago", "Sombria", "de los Muertos",
               "das Gaivotas", "Esmeralda", "do Corsário", "Perdida", "dos Coqueiros", "da Lua", "Vermelha", "do Bucaneiro", "Rasa"]
    objs = ndimage.find_objects(lab)
    for i, sl in enumerate(objs, start=1):
        mask = lab[sl] == i
        area = float(mask.sum()) * PX * PX
        zz, xx = np.nonzero(mask)
        cz = (zz.mean() + sl[0].start + 0.5) * PX - HALF
        cx = (xx.mean() + sl[1].start + 0.5) * PX - HALF
        name = None
        for nm, (kx, kz) in known.items():
            px = int((kx + HALF) / PX); pz = int((kz + HALF) / PX)
            if 0 <= px < N and 0 <= pz < N and lab[pz, px] == i:
                name = nm
                break
        if name is None:
            # o ponto conhecido pode cair um pouco fora: usa o mais próximo dentro de 3 px
            for nm, (kx, kz) in known.items():
                px = int((kx + HALF) / PX); pz = int((kz + HALF) / PX)
                win = lab[max(pz - 3, 0):pz + 4, max(px - 3, 0):px + 4]
                if (win == i).any():
                    name = nm
                    break
        if name is None:
            name = "%s %s" % (a_names[rng.integers(len(a_names))], b_names[rng.integers(len(b_names))])
        info["lands"].append({"id": i, "name": name, "x": round(cx, 1), "z": round(cz, 1),
                              "r": round(math.sqrt(area / math.pi), 1), "area": round(area),
                              "x0": round(sl[1].start * PX - HALF), "x1": round(sl[1].stop * PX - HALF),
                              "z0": round(sl[0].start * PX - HALF), "z1": round(sl[0].stop * PX - HALF)})
    json.dump(info, open(os.path.join(data, "caribe_info.json"), "w"), ensure_ascii=False, indent=1)
    # imagens do mapa e das águas rasas (512 px)
    M = 512
    small = sd[::N // M, ::N // M].astype(np.float32)
    shallow = np.clip(1.0 + np.minimum(small, 0) / 160.0, 0, 1)
    shallow[small >= 0] = 1.0
    Image.fromarray((shallow * 255).astype(np.uint8)).save(os.path.join(data, "caribe_raso.png"))
    sea = np.array([20, 69, 97], np.float32)
    shal = np.array([51, 158, 168], np.float32)
    rgb = sea[None, None, :] * (1 - shallow[..., None]) + shal[None, None, :] * shallow[..., None]
    t = np.clip(small / 2500.0, 0, 1)[..., None]
    sand = np.array([219, 199, 140], np.float32)
    green = np.array([108, 140, 72], np.float32)
    hill = np.array([110, 96, 70], np.float32)
    landc = np.where(small[..., None] < 60, sand, green * (1 - t) + hill * t)
    rgb = np.where((small >= 0)[..., None], landc, rgb)
    Image.fromarray(rgb.astype(np.uint8)).save(os.path.join(data, "caribe_mapa.png"))
    print("terras:", len(info["lands"]), "maiores:", sorted([(l["area"], l["name"]) for l in info["lands"]])[-12:])

if __name__ == "__main__":
    main()
