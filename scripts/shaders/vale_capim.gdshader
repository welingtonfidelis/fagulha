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
// A altura da touceira, para saber o que é raiz e o que é ponta (0,42 na feita por código; 0,5 no tufo do pacote).
uniform float altura = 0.42;

varying vec3 raiz;
varying float alt;
varying float rajada;
varying float funde;

void vertex() {
	raiz = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	alt = clamp(VERTEX.y / altura, 0.0, 1.0);
	float fase = dot(raiz.xz, vec2(0.085, 0.05)) - TIME * 1.25;
	rajada = smoothstep(0.2, 1.0, sin(fase) * 0.5 + 0.5 + 0.25 * sin(fase * 2.7 + raiz.x * 0.2));
	float bal = (0.06 + 0.22 * rajada) * alt * alt + 0.03 * sin(TIME * 3.1 + raiz.x * 1.7 + raiz.z * 1.3) * alt;
	VERTEX.x += bal;
	VERTEX.z += bal * 0.55;
	VERTEX.y -= bal * bal * 0.5;
	mat4 inv = inverse(MODEL_MATRIX);
	// o robô abre o capim: perto dele as folhas deitam para fora e baixam
	vec3 dr = raiz - robo_capim.xyz;
	float longe_r = length(dr.xz);
	float abre = (1.0 - smoothstep(0.3, 1.25, longe_r)) * (1.0 - smoothstep(0.4, 1.6, abs(dr.y))) * robo_capim.w;
	if (abre > 0.001) {
		vec2 fora = longe_r > 0.01 ? dr.xz / longe_r : vec2(1.0, 0.0);
		vec3 fora_l = (inv * vec4(fora.x, 0.0, fora.y, 0.0)).xyz;
		VERTEX.xz += fora_l.xz * abre * alt * 0.34;
		VERTEX.y *= 1.0 - 0.6 * abre * alt;
	}
	// e baixa em volta da câmera, quando ela está rente ao chão: as folhas do primeiro plano tapavam o robô,
	// os bichos e a mira (relatório do jogador tester, 2026-11-19)
	vec3 dcam = raiz - MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
	float perto_cam = (1.0 - smoothstep(0.9, 2.3, length(dcam.xz))) * (1.0 - smoothstep(1.2, 2.4, abs(dcam.y)));
	VERTEX.y *= 1.0 - 0.8 * perto_cam;
	NORMAL = normalize((inv * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
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
	// visual novo: a raiz mais funda e fria, a ponta clara e quente (folha larga, pintada)
	c = mix(c, mix(base * vec3(0.4, 0.55, 0.7), base * vec3(1.08, 1.06, 0.8) + vec3(0.015, 0.02, 0.0), alt * alt * (3.0 - 2.0 * alt)), estilo_novo);
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
