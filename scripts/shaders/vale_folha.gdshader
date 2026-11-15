shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Copas: três tons por altura da face (fundo, meio, topo), manchas de pincel e vento.
uniform vec3 fundo : source_color = vec3(0.045, 0.15, 0.08);
uniform vec3 meio : source_color = vec3(0.13, 0.30, 0.09);
uniform vec3 topo : source_color = vec3(0.33, 0.47, 0.12);
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float onda = sin(TIME * 1.1 + w.x * 0.11 + w.z * 0.07) + 0.5 * sin(TIME * 2.3 + w.x * 0.37 + w.y * 0.3);
	float alto = clamp(VERTEX.y * 0.12, 0.0, 1.0);
	VERTEX.x += onda * 0.07 * alto;
	VERTEX.z += onda * 0.04 * alto;
	wpos = w;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float r = texture(ruido, wpos.xz * 0.09 + vec2(wpos.y * 0.11)).r;
	float t = wnrm.y * 0.5 + 0.5 + (r - 0.5) * 0.45;
	vec3 c = mix(fundo, meio, smoothstep(0.30, 0.42, t));
	c = mix(c, topo, smoothstep(0.66, 0.76, t));
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = topo * borda * 0.22;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
