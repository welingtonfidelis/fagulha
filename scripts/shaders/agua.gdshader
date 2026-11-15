shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;

// Água do mar e do lago: cor pela profundidade, espuma na beira e ondinhas no reflexo.
uniform vec3 raso : source_color = vec3(0.20, 0.42, 0.44);
uniform vec3 fundo : source_color = vec3(0.03, 0.10, 0.14);
uniform vec2 centro = vec2(0.0);
uniform float raio = 100000.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wpos;

float onda(vec2 p) {
	return sin(p.x * 0.31 + TIME * 1.1) * 0.5 + sin(p.y * 0.23 - TIME * 0.9) * 0.5
		+ sin((p.x + p.y) * 0.71 + TIME * 1.7) * 0.25;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (length(wpos.xz - centro) > raio) {
		discard;
	}
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec4 vista = INV_PROJECTION_MATRIX * ndc;
	vista.xyz /= vista.w;
	float prof = max(0.0, VERTEX.z - vista.z);
	float t = clamp(prof / 9.0, 0.0, 1.0);
	vec3 cor = mix(raso, fundo, t);
	float espuma = 1.0 - smoothstep(0.0, 0.8, prof);
	cor = mix(cor, vec3(0.85, 0.88, 0.86), espuma * 0.6);
	ALBEDO = cor;
	ALPHA = clamp(mix(0.55, 0.97, t) + espuma * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.06;
	SPECULAR = 0.55;
	float e = 0.6;
	float hx = onda(wpos.xz + vec2(e, 0.0)) - onda(wpos.xz - vec2(e, 0.0));
	float hz = onda(wpos.xz + vec2(0.0, e)) - onda(wpos.xz - vec2(0.0, e));
	vec3 n_mundo = normalize(vec3(-hx * 0.08, 1.0, -hz * 0.08));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_mundo, 0.0)).xyz);
}
