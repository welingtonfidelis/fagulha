shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Árvores e plantas dos pacotes do Quaternius: a cor vem da textura do modelo (folhas em recorte), puxada
// para a paleta do vale por `tinta`, com a mesma luz em faixas, o mesmo vento das copas e a borda clara.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tinta : source_color = vec3(1.0);
uniform float corte = 0.4;  // recorte pelo alfa da textura (0: peça inteira)
uniform float vento = 1.0;  // quanto balança (0: tronco e pedra)
uniform float alto_vento = 0.12;  // a que altura da peça o balanço chega inteiro (1 / metros)
uniform float borda = 0.18;
uniform float clarao = 0.0;  // pisca claro (máquina levando tiro)
uniform float apagado = 0.0;  // escurece (máquina desligada)
uniform float desbotado = 0.0;  // tira a cor e puxa para a ferrugem (os gigantes que dormem)
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec2 pres;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (vento > 0.0) {
		float onda = sin(TIME * 1.1 + w.x * 0.11 + w.z * 0.07) + 0.5 * sin(TIME * 2.3 + w.x * 0.37 + w.y * 0.3);
		float alto = clamp(VERTEX.y * alto_vento, 0.0, 1.0);
		VERTEX.x += onda * 0.07 * alto * vento;
		VERTEX.z += onda * 0.04 * alto * vento;
	}
	wpos = w;
	pres = presenca(INSTANCE_CUSTOM, MODEL_MATRIX[3].xyz, MAIN_CAM_INV_VIEW_MATRIX[3].xyz);
	if (pres.x <= 0.0) {
		VERTEX = vec3(0.0);  // fora da faixa: a peça vira um ponto e não é desenhada
	}
}

void fragment() {
	if (fora_da_trama(pres, FRAGCOORD.xy)) {
		discard;
	}
	vec4 t = texture(tex, UV);
	if (corte > 0.0 && t.a < corte) {
		discard;
	}
	// manchas largas de claro e escuro, como nas copas do vale
	float r = texture(ruido, wpos.xz * 0.05 + vec2(wpos.y * 0.07)).r;
	vec3 c = t.rgb * tinta * (0.82 + 0.36 * smoothstep(0.3, 0.7, r));
	if (corte > 0.0) {
		// visual novo: folhagem mais viva, puxada para o amarelo nas manchas claras
		c = mix(c, c * mix(vec3(0.82, 1.0, 0.95), vec3(1.28, 1.2, 0.72), smoothstep(0.3, 0.7, r)), estilo_novo);
	}
	c *= 1.0 - 0.6 * apagado;
	if (desbotado > 0.0) {
		float cinza = dot(c, vec3(0.3, 0.55, 0.15));
		c = mix(c, mix(vec3(cinza), vec3(0.30, 0.21, 0.15) * (0.6 + cinza * 2.0), 0.55), desbotado);
	}
	ALBEDO = c;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
	float b = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * b * borda + vec3(1.0, 0.9, 0.8) * clarao;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
	// visual novo: a luz atravessa as folhas (só o que tem recorte: copas, plantas, flores)
	if (corte > 0.0) {
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * clamp(-dot(NORMAL, LIGHT), 0.0, 1.0) * vec3(0.5, 0.62, 0.18) * 0.7 * estilo_novo;
	}
}
