shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

// Fita da cachoeira, em desenho: riscas de água descendo, cortadas em degraus de cor (do azul da água ao
// branco da espuma), com as bordas recortadas em dentes e a fita balançando de leve. UV.x atravessa, UV.y
// desce (0 no topo). A ideia dos degraus veio de um tutorial de cachoeira (waterfall_tu); o código é daqui.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float velocidade = 1.4;
uniform float degraus = 4.0;
uniform vec3 fundo : source_color = vec3(0.13, 0.40, 0.50);
uniform vec3 meio : source_color = vec3(0.40, 0.66, 0.74);
uniform vec3 espuma : source_color = vec3(0.94, 0.97, 0.98);

void vertex() {
	// a fita ondula para fora da pedra, mais embaixo do que em cima (o topo fica preso na beira)
	float onda = sin(UV.y * 9.0 - TIME * 3.2 + UV.x * 2.0) * 0.6 + sin(UV.y * 17.0 - TIME * 5.1) * 0.4;
	VERTEX += NORMAL * onda * 0.16 * smoothstep(0.03, 0.4, UV.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * velocidade;
	// um ruído largo entorta as riscas de lado, para a água não descer em linha de régua
	uv.x += (texture(ruido, vec2(uv.x * 1.2 + 0.2, uv.y * 0.5 - t * 0.18)).r - 0.5) * 0.06;
	// riscas compridas: o ruído é esticado na altura e desce depressa
	float n = texture(ruido, vec2(uv.x * 4.2, uv.y * 0.16 - t * 0.3)).r * 0.6
		+ texture(ruido, vec2(uv.x * 9.5 + 0.37, uv.y * 0.38 - t * 0.55)).r * 0.4;
	n = smoothstep(0.28, 0.72, n);
	// no pé a queda vira espuma
	n = clamp(n + smoothstep(0.78, 1.0, uv.y) * 0.6, 0.0, 1.0);
	// degraus de cor
	float q = clamp(floor(n * degraus) / (degraus - 1.0), 0.0, 1.0);
	vec3 c = mix(fundo, meio, smoothstep(0.0, 0.5, q));
	c = mix(c, espuma, smoothstep(0.5, 1.0, q));
	// bordas em dentes: a risca clara avança, a escura recua
	float lado = min(uv.x, 1.0 - uv.x);
	float corte = step(0.05, lado + (n - 0.5) * 0.07);  // as bordas ficam coladas na pedra, o recorte é pequeno
	float topo = step(0.012, UV.y + (n - 0.5) * 0.02);
	ALBEDO = c;
	ALPHA = corte * topo * mix(0.86, 1.0, q);
	ROUGHNESS = 0.3;
	EMISSION = c * 0.14;
}
