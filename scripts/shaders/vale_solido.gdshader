shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Peças lisas (robô, troncos, pedras, bichos): uma cor, luz em faixas, borda clara contra a luz.
// Com `musgo` > 0, o lado de cima ganha a cor do capim (pedras).
uniform vec3 cor : source_color = vec3(0.5);
uniform float musgo = 0.0;
uniform float brilho_borda = 0.35;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec2 pres;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	pres = presenca(INSTANCE_CUSTOM, MODEL_MATRIX[3].xyz, MAIN_CAM_INV_VIEW_MATRIX[3].xyz);
	if (pres.x <= 0.0) {
		VERTEX = vec3(0.0);  // fora da faixa: a peça vira um ponto e não é desenhada
	}
}

void fragment() {
	if (fora_da_trama(pres, FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = cor;
	float r = texture(ruido, wpos.xz * 0.07 + vec2(wpos.y * 0.05)).r;
	c *= 0.9 + 0.2 * smoothstep(0.35, 0.65, r);
	if (musgo > 0.0) {
		float m = smoothstep(0.45, 0.75, wnrm.y + (r - 0.5) * 0.5) * musgo;
		c = mix(c, cor_capim(ruido, wpos.xz) * 0.8, m);
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * borda * brilho_borda;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
