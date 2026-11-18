shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Capim: a cor vem do chão onde a touceira nasce, mais clara na ponta. O vento passa em ondas
// largas que atravessam o campo. A luz usa a normal para cima, como se fosse o próprio chão.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
// Duas densidades: as touceiras marcadas (INSTANCE_CUSTOM.x = 1) só existem perto da câmera; encolhem até
// sumir entre 70% e 100% de `perto_ate`. As outras ficam até o fim do capim.
uniform float perto_ate = 34.0;
// Todas as touceiras encolhem até o chão e tomam a cor dele perto de `some_ate` (a borda do capim é uma
// roda macia em volta da câmera, não o quadrado do bloco). Os tufos de longe (`nasce_ate` > 0) fazem o
// contrário perto da câmera: só crescem onde o capim de verdade acaba.
uniform float some_ate = 88.0;
uniform float nasce_de = 0.0;
uniform float nasce_ate = 0.0;
// O verso da folha fica na sombra (0 = não: nos tufos de longe o verso só escurece um pouco).
uniform float verso = 1.0;

varying vec3 raiz;
varying float alt;
varying float rajada;
varying float funde;

void vertex() {
	raiz = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	alt = clamp(VERTEX.y / 0.42, 0.0, 1.0);
	float fase = dot(raiz.xz, vec2(0.085, 0.05)) - TIME * 1.25;
	rajada = smoothstep(0.2, 1.0, sin(fase) * 0.5 + 0.5 + 0.25 * sin(fase * 2.7 + raiz.x * 0.2));
	float bal = (0.06 + 0.22 * rajada) * alt * alt + 0.03 * sin(TIME * 3.1 + raiz.x * 1.7 + raiz.z * 1.3) * alt;
	VERTEX.x += bal;
	VERTEX.z += bal * 0.55;
	VERTEX.y -= bal * bal * 0.5;
	NORMAL = normalize((inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float d = distance(raiz, MAIN_CAM_INV_VIEW_MATRIX[3].xyz);
	if (INSTANCE_CUSTOM.x > 0.5) {
		VERTEX *= 1.0 - smoothstep(perto_ate * 0.7, perto_ate, d);
	}
	funde = smoothstep(some_ate * 0.6, some_ate * 0.95, d);
	VERTEX *= 1.0 - smoothstep(some_ate * 0.8, some_ate, d);
	if (nasce_ate > 0.0) {
		float n = smoothstep(nasce_de, nasce_ate, d);
		VERTEX *= n;
		funde = max(funde, 1.0 - n);
	}
}

void fragment() {
	vec3 base = cor_capim(ruido, raiz.xz);
	vec3 c = mix(base * 0.80, base * 1.16 + vec3(0.012, 0.016, 0.0), alt);
	c += vec3(0.022, 0.028, 0.004) * rajada * alt;  // a rajada clareia a ponta
	if (funde > 0.001) {
		c = mix(c, capim_de_longe(ruido, raiz.xz, TIME), funde);
	}
	if (!FRONT_FACING && verso < 0.5) {
		NORMAL = -NORMAL;
		c *= 0.86;
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
