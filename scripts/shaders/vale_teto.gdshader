shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// O chão refeito por cima das cavernas: capim como o do terreno, e pedra só onde é bem inclinado.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float r = texture(ruido, wpos.xz * 0.05).r;
	vec3 c = mix(cor_rocha(ruido, wpos, wnrm), cor_capim(ruido, wpos.xz), smoothstep(0.62, 0.74, wnrm.y + (r - 0.5) * 0.12));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
