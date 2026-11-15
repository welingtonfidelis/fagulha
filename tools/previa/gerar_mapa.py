# Prévia do mundo procedural (só rascunho de planejamento, não é código do jogo).
# Roda com o Python do Blender (tem numpy e OpenImageIO):
#   /Applications/Blender.app/Contents/Resources/5.3/python/bin/python3.13 gerar_mapa.py <saida_dir> [N]
import heapq, math, os, sys, time
import numpy as np

OUT = sys.argv[1]
N = int(sys.argv[2]) if len(sys.argv) > 2 else 512
SIZE_KM = 8.0
DX = SIZE_KM * 1000.0 / N  # metros por pixel

VARIANTES = {
    "colinas": dict(seed=11, base=140, hill=150, mount=1100, mbias=-0.25, kdt=0.0035, it=20, lakes=11,
                    treeline=1000, snow=1400, forest=0.45, nome="Colinas e mata"),
    "vales": dict(seed=7, base=170, hill=130, mount=2300, mbias=0.0, kdt=0.0045, it=24, lakes=8,
                  treeline=900, snow=1150, forest=0.60, nome="Vales e serras"),
    "alpino": dict(seed=23, base=220, hill=120, mount=2500, mbias=0.12, kdt=0.0050, it=26, lakes=6,
                   treeline=850, snow=1050, forest=0.75, nome="Alpino"),
}


def make_perm(seed):
    p = np.random.default_rng(seed).permutation(256)
    return np.concatenate([p, p]).astype(np.int64)


def gnoise(x, y, perm):
    xi = np.floor(x).astype(np.int64)
    yi = np.floor(y).astype(np.int64)
    xf = x - xi
    yf = y - yi
    xi &= 255
    yi &= 255

    def g(h, dx, dy):
        a = h.astype(np.float64) * (2 * np.pi / 256.0)
        return np.cos(a) * dx + np.sin(a) * dy

    n00 = g(perm[perm[xi] + yi], xf, yf)
    n10 = g(perm[perm[xi + 1] + yi], xf - 1, yf)
    n01 = g(perm[perm[xi] + yi + 1], xf, yf - 1)
    n11 = g(perm[perm[xi + 1] + yi + 1], xf - 1, yf - 1)
    u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
    v = yf * yf * yf * (yf * (yf * 6 - 15) + 10)
    a = n00 + u * (n10 - n00)
    b = n01 + u * (n11 - n01)
    return (a + v * (b - a)) * 1.41


def fbm(x, y, perm, octaves, gain=0.5):
    s, amp, f, tot = 0.0, 1.0, 1.0, 0.0
    for o in range(octaves):
        s = s + amp * gnoise(x * f + o * 17.31, y * f - o * 9.73, perm)
        tot += amp
        amp *= gain
        f *= 2.03
    return s / tot


def ridged(x, y, perm, octaves):
    s, amp, f, w, tot = 0.0, 1.0, 1.0, 1.0, 0.0
    for o in range(octaves):
        n = 1.0 - np.abs(gnoise(x * f + o * 31.7, y * f + o * 5.1, perm))
        n = n * n * w
        w = np.clip(n * 1.8, 0, 1)
        s = s + amp * n
        tot += amp
        amp *= 0.5
        f *= 2.07
    return s / tot


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


DIRS = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def fill(h, eps):
    """Priority-flood: enche depressões. eps>0 garante descida até a borda."""
    n = h.shape[0]
    flat = h.ravel().tolist()
    out = flat[:]
    closed = bytearray(n * n)
    pq = []
    for i in range(n):
        for j in (i, (n - 1) * n + i, i * n, i * n + n - 1):
            if not closed[j]:
                closed[j] = 1
                heapq.heappush(pq, (flat[j], j))
    pop, push = heapq.heappop, heapq.heappush
    while pq:
        z, i = pop(pq)
        r, c = divmod(i, n)
        for dr, dc in DIRS:
            rr, cc = r + dr, c + dc
            if 0 <= rr < n and 0 <= cc < n:
                j = rr * n + cc
                if not closed[j]:
                    closed[j] = 1
                    nz = flat[j]
                    if nz <= z + eps:
                        nz = z + eps
                    out[j] = nz
                    push(pq, (nz, j))
    return np.array(out).reshape(h.shape)


def receivers(F):
    n = F.shape[0]
    idx = np.arange(n * n).reshape(n, n)
    pad = np.pad(F, 1, constant_values=np.inf)
    best = np.zeros_like(F)
    rcv = idx.copy()
    dist = np.full(F.shape, DX)
    for dr, dc in DIRS:
        nb = pad[1 + dr:1 + dr + n, 1 + dc:1 + dc + n]
        d = math.hypot(dr, dc) * DX
        s = (F - nb) / d
        m = s > best
        best = np.where(m, s, best)
        rcv = np.where(m, idx + dr * n + dc, rcv)
        dist = np.where(m, d, dist)
    outlet = F <= 0.0
    outlet[0, :] = outlet[-1, :] = outlet[:, 0] = outlet[:, -1] = True
    rcv = np.where(outlet, idx, rcv)
    return rcv.ravel(), dist.ravel(), best


def accumulate(F, rcv):
    order = np.argsort(F.ravel())[::-1].tolist()
    A = [DX * DX] * F.size
    rl = rcv.tolist()
    for i in order:
        r = rl[i]
        if r != i:
            A[r] += A[i]
    return np.array(A)


def laplacian(h):
    p = np.pad(h, 1, mode="edge")
    return p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:] - 4 * h


def blur(a, k=2):
    for _ in range(k):
        p = np.pad(a, 1, mode="edge")
        a = (p[:-2, :-2] + p[:-2, 1:-1] + p[:-2, 2:] + p[1:-1, :-2] + p[1:-1, 1:-1] + p[1:-1, 2:]
             + p[2:, :-2] + p[2:, 1:-1] + p[2:, 2:]) / 9.0
    return a


def gerar(chave, P):
    t0 = time.time()
    perm = make_perm(P["seed"])
    perm2 = make_perm(P["seed"] + 101)
    lin = (np.arange(N) + 0.5) * (SIZE_KM / N)
    X, Y = np.meshgrid(lin, lin)
    wx = fbm(X * 0.35, Y * 0.35, perm2, 3) * 1.3
    wy = fbm(X * 0.35 + 5.2, Y * 0.35 + 1.3, perm2, 3) * 1.3
    Xw, Yw = X + wx, Y + wy
    cont = fbm(Xw * 0.2, Yw * 0.2, perm, 3)
    mmask = smoothstep(-0.35, 0.35, cont + P["mbias"])
    hills = fbm(Xw * 0.7, Yw * 0.7, perm2, 5) * P["hill"]
    rd = ridged(Xw * 0.30, Yw * 0.30, perm, 7)
    mount = (rd ** 1.6) * P["mount"] * mmask
    h = P["base"] + hills + mount
    # ilha: o mar cerca o mundo (borda natural)
    cx, cy = (X - SIZE_KM / 2) / (SIZE_KM / 2), (Y - SIZE_KM / 2) / (SIZE_KM / 2)
    r = np.sqrt(cx * cx + cy * cy) + fbm(X * 0.35, Y * 0.35, perm2, 5) * 0.32
    h = h * (1 - smoothstep(0.55, 0.97, r)) - 180 * smoothstep(0.90, 1.10, r) + 25 * (1 - smoothstep(0.80, 1.0, r))

    # erosão: lei do fluxo (implícita) + difusão das encostas
    rdet = ridged(Xw * 2.2, Yw * 2.2, perm2, 4)
    for it in range(P["it"]):
        if it == P["it"] - 5:
            h = h + np.where(h > 0, (rdet - 0.35) * 110 * mmask * smoothstep(150, 700, h), 0)
        F = fill(h, 0.01)
        rcv, dist, _ = receivers(F)
        A = accumulate(F, rcv)
        fac = (P["kdt"] * np.sqrt(A) / dist).tolist()
        hl = F.ravel().tolist()
        rl = rcv.tolist()
        for i in np.argsort(F.ravel()).tolist():
            rr = rl[i]
            if rr != i and hl[i] > 0:
                f = fac[i]
                hl[i] = (hl[i] + f * hl[rr]) / (1 + f)
        h = np.array(hl).reshape(h.shape)
        land = h > 0
        h = h + np.where(land, 0.035 * laplacian(h), 0)

    # lagos: bacias cavadas no fundo dos vales; o nível sai do transbordo
    F = fill(h, 0.01)
    rcv, dist, slope = receivers(F)
    A = accumulate(F, rcv).reshape(h.shape)
    rng = np.random.default_rng(P["seed"] + 5)
    cand = np.argwhere((A > 2.5e5) & (slope < 0.10) & (h > 30) & (h < 800))
    rng.shuffle(cand)
    sites = []
    for (rr, cc) in cand:
        p = np.array([rr, cc]) * DX
        if all(np.hypot(*(p - q)) > 1300 for q in sites):
            if min(rr, cc, N - 1 - rr, N - 1 - cc) * DX > 900:
                sites.append(p)
        if len(sites) >= P["lakes"]:
            break
    Ym, Xm = np.meshgrid(np.arange(N) * DX, np.arange(N) * DX, indexing="ij")
    for (py, px) in sites:
        R = rng.uniform(110, 280)
        ang = rng.uniform(0, np.pi)
        dx_, dy_ = Xm - px, Ym - py
        u = (dx_ * np.cos(ang) + dy_ * np.sin(ang)) / (R * 1.6)
        v = (-dx_ * np.sin(ang) + dy_ * np.cos(ang)) / R
        d = np.sqrt(u * u + v * v)
        h = h - rng.uniform(14, 30) * (1 - smoothstep(0.35, 1.0, d))
    W = fill(h, 0.0)
    depth = W - h
    lake = (depth > 0.6) & (h > -1)

    F = fill(h, 0.01)
    rcv, dist, _ = receivers(F)
    A = accumulate(F, rcv).reshape(h.shape)
    river = (A > 1.6e6) & ~lake & (h > 0)
    big = A > 1.2e7
    river_wide = river | (big & (np.roll(river, 1, 0) | np.roll(river, 1, 1)))
    h = np.where(river_wide, h - 3.0, h)

    # vegetação e biomas
    gy, gx = np.gradient(h, DX)
    sl = np.degrees(np.arctan(np.hypot(gx, gy)))
    sea = h < 0
    water = sea | lake
    moist = blur(np.log1p(A / (DX * DX)) / 10.0, 3) + 0.9 * blur(river_wide.astype(float) + lake, 6)
    patch = fbm(X * 1.6, Y * 1.6, perm2, 4)
    nz = fbm(X * 2.5, Y * 2.5, perm, 3)
    tl = P["treeline"] + nz * 90
    dens = moist * 1.6 + patch * 1.1 - np.clip(h / tl, 0, 2) * 0.55 + P["forest"]
    col = np.zeros(h.shape + (3,))
    C = lambda *v: np.array(v) / 255.0
    grass = C(146, 156, 92)
    meadow = C(170, 160, 104)
    forest_low = C(52, 82, 46)
    forest_conif = C(40, 66, 52)
    rock = C(120, 116, 108)
    snow = C(236, 238, 242)
    sand = C(196, 182, 140)
    alpine = C(140, 138, 96)
    col[:] = grass
    col[dens < 0.35] = meadow
    fmask = dens > 0.62
    col[fmask & (h < 520)] = forest_low
    col[fmask & (h >= 520)] = forest_conif
    col[h > tl] = alpine
    col[(sl > 40) | (h > tl + 220)] = rock
    col[(h > P["snow"] + nz * 70) & (sl < 42)] = snow
    col[(h >= 0) & (h < 7) & (blur(sea.astype(float), 3) > 0.02)] = sand
    forest = fmask & (h < tl) & (sl <= 40) & ~water
    # relevo sombreado
    nx_, ny_, nz_ = -gx * 1.5, -gy * 1.5, np.ones_like(h)
    nl = np.sqrt(nx_ ** 2 + ny_ ** 2 + 1)
    az, alt = math.radians(315), math.radians(38)
    L = np.array([math.cos(alt) * math.sin(az), -math.cos(alt) * math.cos(az), math.sin(alt)])
    shade = np.clip((nx_ * L[0] + ny_ * L[1] + nz_ * L[2]) / nl, 0, 1)
    img = col * (0.30 + 0.85 * shade)[..., None]
    img *= (0.92 + 0.10 * np.clip(h / 1500, 0, 1))[..., None]
    # textura de copas na mata
    tex = gnoise(X * 60, Y * 60, perm) * 0.06
    img = np.where(forest[..., None], img * (0.95 + tex)[..., None], img)
    deep = np.clip(-h / 120, 0, 1)[..., None]
    seacol = C(70, 112, 128) * (1 - deep) + C(28, 52, 72) * deep
    img = np.where(sea[..., None], seacol, img)
    ld = np.clip(depth / 25, 0, 1)[..., None]
    lakecol = C(76, 120, 128) * (1 - ld) + C(36, 66, 82) * ld
    img = np.where(lake[..., None], lakecol, img)
    img = np.where((river_wide & ~sea)[..., None], C(70, 118, 132), img)
    img = np.clip(img, 0, 1)
    np.savez_compressed(os.path.join(OUT, f"{chave}.npz"), h=h.astype(np.float32), W=W.astype(np.float32),
                        lake=lake, sea=sea, river=river_wide, forest=forest, col=col.astype(np.float32),
                        dens=dens.astype(np.float32), dx=DX)
    print(chave, f"{time.time() - t0:.1f}s", "alt max", int(h.max()), "lagos", len(sites),
          f"mata {forest.mean() * 100:.0f}%", flush=True)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    import OpenImageIO as oiio
    imgs = {}
    for k, P in VARIANTES.items():
        if len(sys.argv) > 3 and k not in sys.argv[3].split(","):
            continue
        imgs[k] = gerar(k, P)
        b = oiio.ImageBuf(oiio.ImageSpec(N, N, 3, oiio.FLOAT))
        b.set_pixels(oiio.ROI(), imgs[k].astype(np.float32))
        b.write(os.path.join(OUT, f"{k}.png"), "uint8")
