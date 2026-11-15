shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Pedra das ruínas: clara e gasta, com escorridos da chuva, e o musgo tomando as faces de cima
// e subindo em manchas pelas paredes.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = wpos;
	vec3 n = wnrm;
	vec2 pl = vec2(p.x * 0.8 + p.z * 0.6, p.z * 0.8 - p.x * 0.6);
	float a = texture(ruido, vec2(pl.x * 0.07, p.y * 0.07 + pl.y * 0.05)).r;
	float b = texture(ruido, pl * 0.23 + vec2(p.y * 0.19)).r;
	vec3 c = mix(vec3(0.17, 0.165, 0.145), vec3(0.265, 0.25, 0.215), a) * mix(0.86, 1.03, b);
	// escorridos escuros nas paredes
	float esc = texture(ruido, vec2(pl.x * 0.4, p.y * 0.022 + pl.y * 0.35)).r;
	c *= mix(1.0, 0.7, smoothstep(0.58, 0.78, esc) * (1.0 - smoothstep(0.4, 0.9, n.y)));
	// cada face com um tom, as viradas para baixo mais escuras (o volume aparece mesmo na sombra)
	float face = fract(sin(dot(floor(n * 6.0 + 0.5), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	c *= mix(0.88, 1.08, face) * mix(0.68, 1.06, n.y * 0.5 + 0.5);
	// musgo: em cima de tudo, e em manchas grandes subindo pelos lados
	vec3 musgo = mix(vec3(0.045, 0.115, 0.04), vec3(0.10, 0.20, 0.05), b);
	float mancha = texture(ruido, vec2(pl.x + pl.y * 0.6, p.y * 1.15 + pl.y * 0.3) * 0.05).r;
	float m = smoothstep(0.5, 0.82, n.y + (b - 0.5) * 0.5) * 0.92;
	m = max(m, smoothstep(0.58, 0.7, mancha + (b - 0.5) * 0.3) * 0.75);
	c = mix(c, musgo, m);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.08;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
