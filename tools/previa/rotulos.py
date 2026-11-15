import blf, imbuf, sys
p = sys.argv[sys.argv.index("--") + 1]
ib = imbuf.load(p)
W, H = ib.size
M, G, TOP = 512, 24, 70
fb = blf.load("/System/Library/Fonts/Supplemental/Arial Bold.ttf")
fr = blf.load("/System/Library/Fonts/Supplemental/Arial.ttf")
def txt(f, x, y_top, s, size, c):
    blf.size(f, size); blf.color(f, *c, 1.0); blf.position(f, x, H - y_top, 0); blf.draw_buffer(f, s)
nomes = [("A · Colinas e mata", "altitude até ~700 m · 11 lagos · 44% de mata"),
         ("B · Vales e serras", "altitude até ~1.600 m · 8 lagos · 44% de mata"),
         ("C · Alpino", "altitude até ~2.400 m · 6 lagos · 23% de mata")]
with blf.bind_imbuf(fb, ib), blf.bind_imbuf(fr, ib):
    for i, (t, sub) in enumerate(nomes):
        x = G + i * (M + G)
        txt(fb, x, 36, t, 26, (0.95, 0.95, 0.92))
        txt(fr, x, 60, sub, 16, (0.70, 0.72, 0.72))
        txt(fr, x + 138, TOP + M + 37, "2 km   (cada mapa: 8 × 8 km)", 16, (0.75, 0.77, 0.77))
    txt(fr, G, H - 10, "verde-escuro = mata · amarelado = campo · cinza = rocha · branco = neve · azul = lagos, rios e mar", 16, (0.6, 0.62, 0.62))
imbuf.write(ib, filepath=p)
print("rotulos ok", W, H)
