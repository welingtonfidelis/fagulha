shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// As lajes da cachoeira nova (CachoeiraAlta): a mesma pedra dos paredões em volta (cor_rocha), com veios deitados
// bem de leve para ler como pedra empilhada, o capim por cima de cada laje e musgo escorrendo pelas faces de lado
// (pedra que vive molhada).
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = cor_rocha(ruido, wpos, wnrm);
	vec2 pl = vec2(wpos.x * 0.8 + wpos.z * 0.6, wpos.z * 0.8 - wpos.x * 0.6);
	float a = texture(ruido, vec2(pl.x * 0.05, wpos.y * 0.03 + pl.y * 0.02)).r;
	// veios deitados, tortos pelo ruído
	float e = wpos.y * 0.85 + (a - 0.5) * 1.4;
	c *= mix(0.86, 1.0, smoothstep(0.0, 0.16, fract(e)));
	// musgo escorrendo pelas faces de lado: manchas compridas de cima para baixo, verde-escuro
	float m = texture(ruido, vec2(pl.x * 0.09 + pl.y * 0.06, wpos.y * 0.035)).r * 0.7
		+ texture(ruido, vec2(pl.x * 0.31, wpos.y * 0.09) + vec2(0.3, 0.7)).r * 0.3;
	float de_lado = 1.0 - smoothstep(0.55, 0.85, abs(wnrm.y));
	float musgo = smoothstep(0.5, 0.56, m) * de_lado;
	vec3 verde = cor_capim(ruido, wpos.xz) * vec3(0.52, 0.6, 0.42);
	c = mix(c, verde, musgo * 0.9);
	// o capim cobre o topo de cada laje, com a beira bem marcada (mais generoso que nos paredões)
	float r = texture(ruido, wpos.xz * 0.08).r;
	vec3 mato = cor_capim(ruido, wpos.xz) * 0.92;
	c = mix(c, mato, smoothstep(0.8, 0.86, wnrm.y + (r - 0.5) * 0.14));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
