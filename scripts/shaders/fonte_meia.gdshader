shader_type spatial;
render_mode cull_back, depth_draw_never;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// A "meia branca" dos pinheiros secos da bacia das fontes quentes (2026-11-22, ideia do game designer): a água
// quente subiu, o mineral grudou na base dos troncos e a mata secou. É uma camada por cima (material_overlay)
// das árvores q_seca da bacia: pinta de branco-mineral até ~1 m acima do pé de cada árvore, com a linha de cima
// torta e um fio mais escuro, e descarta o resto. Segue o mesmo sumiço pela distância das árvores.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float alto = 0.95;

varying vec3 wpos;
varying float pe;
varying vec2 pres;

void vertex() {
	VERTEX += NORMAL * 0.012;  // um fio para fora do tronco, para não brigar com ele na profundidade
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pe = MODEL_MATRIX[3].y + 0.15;
	pres = presenca(INSTANCE_CUSTOM, MODEL_MATRIX[3].xyz, MAIN_CAM_INV_VIEW_MATRIX[3].xyz);
	if (pres.x <= 0.0) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	if (fora_da_trama(pres, FRAGCOORD.xy)) {
		discard;
	}
	float r = texture(ruido, wpos.xz * 1.7 + vec2(wpos.y * 0.2)).r;
	float linha = pe + alto + (r - 0.5) * 0.3;
	float acima = wpos.y - linha;
	if (acima > 0.03) {
		discard;
	}
	vec3 c = mix(vec3(0.15, 0.148, 0.14), vec3(0.18, 0.175, 0.165), smoothstep(0.3, 0.7, r));
	// o fio da marca d'água, mais escuro e ferrugem, no alto da meia
	c = mix(c, vec3(0.09, 0.06, 0.035), smoothstep(-0.07, 0.0, acima));
	// embaixo, rente ao chão, um pouco de laranja
	c = mix(vec3(0.11, 0.06, 0.025), c, smoothstep(pe + 0.02, pe + 0.25, wpos.y));
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
