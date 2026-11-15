shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Rochas dos paredões: a mesma pedra do chão (cor_rocha), com musgo e capim nas faces de cima.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = cor_rocha(ruido, wpos, wnrm);
	float r = texture(ruido, wpos.xz * 0.08).r;
	// o capim cobre o topo de cada massa, com a beira bem marcada
	vec3 mato = cor_capim(ruido, wpos.xz) * 0.92;
	c = mix(c, mato, smoothstep(0.9, 0.94, wnrm.y + (r - 0.5) * 0.1));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
