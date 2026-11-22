shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

// A água de uma fonte quente (terra nova, área B, 2026-11-21): no meio, o furo fundo e azul-escuro; para fora,
// azul, turquesa, um verde-amarelado raso e, rente à beira, o laranja das bactérias que vivem na água quente.
// A cor vem da distância ao centro da poça (`centro`, `raio`), torta pelo ruído para não sair um alvo de tiro.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec2 centro = vec2(0.0);
uniform float raio = 6.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 rel = wpos.xz - centro;
	float n = texture(ruido, wpos.xz * (0.6 / raio) + vec2(0.13, 0.71)).r;
	float ang = atan(rel.y, rel.x);
	float d = length(rel) / raio + (n - 0.5) * 0.16 + sin(ang * 7.0 + n * 4.0) * 0.015;
	vec3 fundo = vec3(0.01, 0.04, 0.17);
	vec3 azul = vec3(0.02, 0.14, 0.34);
	vec3 turquesa = vec3(0.05, 0.28, 0.32);
	vec3 raso = vec3(0.17, 0.25, 0.10);
	vec3 laranja = vec3(0.30, 0.12, 0.03);
	vec3 c = mix(fundo, azul, smoothstep(0.02, 0.32, d));
	c = mix(c, turquesa, smoothstep(0.38, 0.62, d));
	c = mix(c, raso, smoothstep(0.74, 0.88, d));
	c = mix(c, laranja, smoothstep(0.9, 1.0, d));
	ALBEDO = c;
	// a superfície quase parada, com um tremido leve de água quente
	float r1 = texture(ruido, wpos.xz * 0.45 + vec2(TIME * 0.03, 0.0)).r;
	float r2 = texture(ruido, wpos.zx * 0.45 - vec2(0.0, TIME * 0.025)).r;
	NORMAL_MAP = vec3(0.5 + (r1 - 0.5) * 0.25, 0.5 + (r2 - 0.5) * 0.25, 1.0);
	ROUGHNESS = 0.18;
	SPECULAR = 0.3;
}
