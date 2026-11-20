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
uniform float sujeira = 0.0;  // móveis velhos: a cor desbota para o sépia, manchas de umidade e pó por cima
uniform sampler2D luz : source_color, filter_linear_mipmap, repeat_enable, hint_default_black;
uniform float luz_forca = 0.0;  // quanto a textura de luz acende (telas, olho do drone)
uniform vec3 aceso : source_color = vec3(0.0);  // cor acesa na peça toda (lâmpadas)
uniform float borda = 0.14;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
global uniform sampler2D fer_chapa : source_color, filter_linear_mipmap, repeat_enable;
global uniform sampler2D fer_grossa : source_color, filter_linear_mipmap, repeat_enable;

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
	if (sujeira > 0.0) {
		// desbotado: perde parte da cor e puxa para um amarelado velho
		float cinza = dot(c, vec3(0.3, 0.59, 0.11));
		c = mix(c, vec3(cinza) * vec3(1.05, 0.97, 0.84), 0.3 * sujeira);
		// manchas de umidade e encardido do tamanho de um móvel (o ruído das paredes é largo demais: um sofá
		// inteiro caía dentro ou fora de uma mancha só), mais embaixo
		float s1 = texture(ruido, pl * 0.55 + vec2(0.61, 0.29)).r;
		float s2 = texture(ruido, pl * 1.6 + vec2(0.23, 0.83)).r;
		float mancha = smoothstep(0.45, 0.78, s1 * 0.65 + s2 * 0.35 + (1.0 - n.y) * 0.06 + (r1 - 0.5) * 0.2);
		c = mix(c, c * vec3(0.62, 0.55, 0.46), mancha * 0.75 * sujeira);
		// grão miúdo de sujeira em tudo
		float grao = texture(ruido, pl * 1.7 + vec2(0.5, 0.2)).r;
		c *= 1.0 - (grao - 0.5) * 0.22 * sujeira;
		// pó nas faces de cima
		float po = smoothstep(0.55, 0.95, n.y) * (0.45 + 0.55 * r2);
		c = mix(c, vec3(0.5, 0.46, 0.39), po * 0.35 * sujeira);
		c *= 1.0 - 0.12 * sujeira;
	}
	if (ferrugem > 0.0) {
		// a ferrugem vem de duas texturas (Poly Haven, CC0), projetadas pelo mundo para emendar de uma peça
		// para a outra: a grossa dá a cor e o grão; a de chapa pintada dá as pintas, que esfarelam a borda
		// das manchas e salpicam o resto. O ruído só decide onde enferruja mais (embaixo e nas quinas).
		vec3 grossa = texture(fer_grossa, pl * 0.17).rgb;
		vec3 chapa = texture(fer_chapa, pl * 0.12).rgb;
		float pinta = smoothstep(0.06, 0.3, chapa.r - chapa.b);
		float zona = r1 * 0.78 + r2 * 0.22 + (1.0 - n.y) * 0.05;
		float lim = 0.74 - ferrugem * 0.3;
		float m = smoothstep(lim - 0.1, lim + 0.08, zona + (pinta - 0.45) * 0.24);
		m = max(m, pinta * ferrugem * 0.55);
		c = mix(c, grossa * 1.25, m * min(1.0, ferrugem * 1.3));
		c *= 1.0 - 0.18 * ferrugem * (1.0 - m);  // o que não enferrujou perdeu o brilho
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
