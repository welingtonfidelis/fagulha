shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Chão do vale: a cor do capim (a mesma das folhas de capim), trilha de terra (COLOR.r),
// margem molhada (COLOR.g) e pedra nas encostas.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float r = texture(ruido, wpos.xz * 0.08).r;
	vec3 c = cor_capim(ruido, wpos.xz) * 0.92;
	vec3 terra = mix(vec3(0.20, 0.145, 0.09), vec3(0.27, 0.21, 0.13), r);
	c = mix(c, terra, smoothstep(0.35, 0.6, COLOR.r + (r - 0.5) * 0.3));
	c = mix(c, vec3(0.20, 0.17, 0.12), COLOR.g * 0.8);
	vec3 pedra = mix(vec3(0.30, 0.31, 0.34), vec3(0.40, 0.40, 0.42), smoothstep(0.4, 0.6, r));
	c = mix(c, pedra, smoothstep(0.80, 0.68, wnrm.y + (r - 0.5) * 0.15));
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.4, COLOR.g);
	SPECULAR = 0.1;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
