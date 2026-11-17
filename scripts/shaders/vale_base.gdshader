shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Peças da base (kits de ficção do Quaternius, o cilindro e o Faísca caído): a cor vem da textura do
// modelo (ou só de `tinta`), com a luz em faixas do vale. Por cima, o tempo: `ferrugem` mancha de laranja
// queimado em placas largas, e `musgo` cobre as faces viradas para cima e escorre um pouco pelas paredes.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec3 tinta : source_color = vec3(1.0);
uniform float corte = 0.0;  // recorte pelo alfa da textura (0: peça inteira)
uniform float ferrugem = 0.0;
uniform float musgo = 0.0;
uniform sampler2D luz : source_color, filter_linear_mipmap, repeat_enable, hint_default_black;
uniform float luz_forca = 0.0;  // quanto a textura de luz acende (telas, olho do drone)
uniform vec3 aceso : source_color = vec3(0.0);  // cor acesa na peça toda (lâmpadas)
uniform float borda = 0.14;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (corte > 0.0 && t.a < corte) {
		discard;
	}
	vec3 n = wnrm;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
		n = -n;
	}
	vec3 c = t.rgb * tinta;
	// manchas no espaço: cada face lê o ruído pelo plano em que ela está mais deitada (sem riscos)
	vec3 an = abs(n);
	vec2 pl = an.y > 0.6 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	float r1 = texture(ruido, pl * 0.05 + vec2(0.37, 0.11)).r;
	float r2 = texture(ruido, pl * 0.21 + vec2(0.13, 0.71)).r;
	float tempo = 0.0;
	if (ferrugem > 0.0) {
		// placas largas de ferrugem, mais fortes embaixo das peças e nas quinas viradas para baixo
		float m = smoothstep(0.66 - ferrugem * 0.3, 0.8 - ferrugem * 0.22, r1 * 0.78 + r2 * 0.22 + (1.0 - n.y) * 0.05);
		vec3 fer = mix(vec3(0.085, 0.03, 0.012), vec3(0.24, 0.085, 0.022), smoothstep(0.3, 0.7, r2));
		c = mix(c, fer, m * min(1.0, ferrugem * 1.25));
		c *= 1.0 - 0.25 * ferrugem * (1.0 - m);  // o que não enferrujou perdeu o brilho
		tempo = m;
	}
	if (musgo > 0.0) {
		float cima = smoothstep(0.75 - musgo * 0.85, 0.95 - musgo * 0.55, n.y + (r1 - 0.5) * 0.9 + (r2 - 0.5) * 0.3);
		c = mix(c, cor_capim(ruido, wpos.xz) * 0.62, cima * min(1.0, musgo * 1.3));
		tempo = max(tempo, cima);
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
	float b = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * b * borda + texture(luz, UV).rgb * luz_forca * (1.0 - tempo) + aceso;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
