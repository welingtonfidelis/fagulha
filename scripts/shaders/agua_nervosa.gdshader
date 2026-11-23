shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// A água nervosa em cima de um cardume de sardinhas (PeixesRaso, 2026-11-22): anelzinhos que abrem e somem,
// espalhados num disco que esfuma na beira. Do alto é isso que se vê de um cardume rente à superfície.
uniform float raio = 7.0;
uniform float forca = 0.75;

float h1(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * raio;
	float d = length(p) / raio;
	float borda = 1.0 - smoothstep(0.45, 1.0, d);
	float soma = 0.0;
	for (int camada = 0; camada < 2; camada++) {
		float cel = camada == 0 ? 0.9 : 1.37;
		vec2 g = p / cel + float(camada) * 7.3;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = h1(id + float(camada) * 3.1);
		float t = fract(TIME * (0.55 + h * 0.7) + h * 5.0);
		vec2 off = (vec2(h1(id * 1.7), h1(id * 2.3)) - 0.5) * 0.4;
		float r = length(f - off);
		float anel = smoothstep(0.05, 0.0, abs(r - t * 0.42)) * (1.0 - t) * step(0.4, h);
		float ponto = smoothstep(0.06, 0.0, r) * step(0.85, h) * (0.5 + 0.5 * sin(TIME * 9.0 + h * 30.0));
		soma += anel + ponto;
	}
	ALBEDO = vec3(0.86, 0.92, 0.94);
	ALPHA = clamp(soma, 0.0, 1.0) * borda * forca;
}
