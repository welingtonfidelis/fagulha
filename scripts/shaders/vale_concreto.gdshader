shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Concreto velho (represa, cais, pilares, farol): cinza claro com as juntas das fôrmas, manchas escuras
// escorridas de cima para baixo, ferrugem em alguns pontos e limo escuro (não capim) nas faces de cima.
uniform vec3 cor : source_color = vec3(0.46, 0.45, 0.42);
uniform float limo = 0.5;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// ao longo da parede: a coordenada horizontal que corre junto da face
	float u = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
	float parede = 1.0 - smoothstep(0.5, 0.8, abs(wnrm.y));
	float r = texture(ruido, vec2(u, wpos.y) * 0.06).r;
	float fino = texture(ruido, vec2(u, wpos.y) * 0.31).r;
	vec3 c = cor * (0.86 + 0.26 * smoothstep(0.3, 0.7, r)) * (0.94 + 0.12 * fino);
	// juntas das fôrmas: uma linha a cada 2,4 m de altura e a cada 4,8 m ao longo
	float jh = abs(fract(wpos.y / 2.4) - 0.5);
	float jv = abs(fract((u + floor(wpos.y / 2.4) * 2.4) / 4.8) - 0.5);
	float junta = max(smoothstep(0.47, 0.495, jh), smoothstep(0.485, 0.498, jv)) * parede;
	c *= 1.0 - junta * 0.35;
	// escorridos: riscos escuros compridos na vertical, mais fortes embaixo das juntas
	float risco = texture(ruido, vec2(u * 0.55, wpos.y * 0.035)).r;
	float escorre = smoothstep(0.52, 0.78, risco) * parede;
	c = mix(c, c * vec3(0.52, 0.5, 0.47), escorre * 0.75);
	// ferrugem que desce de alguns pontos
	float fer = smoothstep(0.7, 0.86, texture(ruido, vec2(u * 0.23 + 0.4, wpos.y * 0.02 + 0.7)).r) * parede;
	c = mix(c, vec3(0.34, 0.19, 0.10), fer * 0.6);
	// limo: verde escuro e sujo, em manchas, só no que olha para cima
	float lm = smoothstep(0.55, 0.85, wnrm.y + (r - 0.5) * 0.6) * limo * smoothstep(0.35, 0.6, texture(ruido, wpos.xz * 0.045).r);
	c = mix(c, vec3(0.16, 0.2, 0.11), lm * 0.8);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
