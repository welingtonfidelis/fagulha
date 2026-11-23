shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// A crosta de mineral das fontes quentes (2026-11-22): a beira de sínter de cada poça, o cone do gêiser e a
// borda das poças de lama (FontesQuentes). A cor vem da cor do vértice (rgb) e o quanto está molhado do alfa:
// molhado fica mais escuro e liso. Por cima, manchas e rachaduras de crosta seca.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float rachas = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float molhado = COLOR.a;
	float r = texture(ruido, wpos.xz * 0.9 + vec2(wpos.y * 0.3)).r;
	float r2 = texture(ruido, wpos.zx * 2.7 + vec2(0.31, 0.77)).r;
	c *= 0.86 + 0.28 * smoothstep(0.3, 0.7, r);
	// as rachaduras da crosta seca: linhas finas e escuras onde o ruído passa pelo meio
	float racha = smoothstep(0.035, 0.0, abs(r2 - 0.5)) * rachas * (1.0 - molhado);
	c *= 1.0 - racha * 0.45;
	c *= mix(1.0, 0.62, molhado);
	ALBEDO = c;
	ROUGHNESS = mix(0.92, 0.25, molhado);
	SPECULAR = mix(0.1, 0.4, molhado);
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
	// o brilho do molhado (o light() próprio não soma o reflexo sozinho; o seco não brilha)
	float liso = smoothstep(0.75, 0.3, ROUGHNESS);
	vec3 h = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * pow(max(dot(NORMAL, h), 0.0), 70.0) * SPECULAR_AMOUNT * 0.5 * liso;
}
