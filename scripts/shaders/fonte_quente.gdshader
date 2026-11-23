shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

// A água de uma fonte quente (área B). Refeita em 2026-11-22, a partir da revisão do game designer: antes era um
// disco opaco com um anel laranja na borda, e a grade de 4 m do chão cortava a beira em serrote.
// - A água é transparente pela espessura: a profundidade da tela dá quanto de água há embaixo de cada ponto.
//   No raso ela quase some e mostra o fundo de mineral claro; no fundo fica azul. A beira segue o chão, sem
//   polígono (a crosta de sínter da FontesQuentes cobre a emenda).
// - A cor vem da distância ao centro (o furo fundo, o azul, o turquesa e o raso), sem laranja dentro da água.
//   `tom`: 0 o Olho Azul, vivo de cartão-postal (escolha do usuário); 1 azul leitoso; 2 verde-esmeralda; 3
//   turquesa leitoso (os degraus do monte).
// - `bolhas`: bolhas que sobem no meio e abrem anéis na superfície; o centro sobe devagar em ondas.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform sampler2D tela_prof : hint_depth_texture, filter_nearest;
uniform vec2 centro = vec2(0.0);
uniform float raio = 6.0;
uniform float tom = 0.0;
uniform float bolhas = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// as bolhas: em cada célula de 1,1 m, de tempos em tempos, um anel que abre e some
float anel_bolhas(vec2 p, float t, out vec2 dir) {
	vec2 cel = floor(p / 1.1);
	float soma = 0.0;
	dir = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cel + vec2(float(i), float(j));
			float h1 = hash(c);
			float h2 = hash(c + 17.3);
			float per = 1.6 + 3.2 * h1;
			float f = fract(t / per + h2);
			vec2 onde = (c + vec2(0.2 + 0.6 * hash(c + 3.1), 0.2 + 0.6 * hash(c + 9.7))) * 1.1;
			vec2 rel = p - onde;
			float d = length(rel);
			float r = f * (0.25 + 0.35 * h1);
			float a = (1.0 - f) * (1.0 - f) * step(0.35, hash(c + floor(t / per + h2) * 7.7));
			float aro = smoothstep(0.05, 0.0, abs(d - r)) * a;
			soma += aro;
			dir += normalize(rel + 1e-4) * aro;
		}
	}
	return soma;
}

void fragment() {
	// quanto de água há embaixo deste ponto (na vertical)
	float dz = texture(tela_prof, SCREEN_UV).r;
	vec4 vista = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	vista.xyz /= vista.w;
	vec3 chao = (INV_VIEW_MATRIX * vec4(vista.xyz, 1.0)).xyz;
	float esp = max(0.0, wpos.y - chao.y);

	vec2 rel = wpos.xz - centro;
	float n = texture(ruido, wpos.xz * (0.6 / raio) + vec2(0.13, 0.71)).r;
	float ang = atan(rel.y, rel.x);
	float d = length(rel) / raio + (n - 0.5) * 0.14 + sin(ang * 7.0 + n * 4.0) * 0.012;

	vec3 fundo, azul, turquesa, raso;
	if (tom < 0.5) {  // o Olho Azul
		fundo = vec3(0.0, 0.035, 0.2);
		azul = vec3(0.005, 0.13, 0.42);
		turquesa = vec3(0.02, 0.33, 0.40);
		raso = vec3(0.22, 0.36, 0.22);
	} else if (tom < 1.5) {  // azul leitoso
		fundo = vec3(0.03, 0.10, 0.22);
		azul = vec3(0.10, 0.25, 0.40);
		turquesa = vec3(0.17, 0.36, 0.40);
		raso = vec3(0.30, 0.37, 0.30);
	} else if (tom < 2.5) {  // verde-esmeralda
		fundo = vec3(0.0, 0.07, 0.08);
		azul = vec3(0.02, 0.19, 0.18);
		turquesa = vec3(0.06, 0.30, 0.20);
		raso = vec3(0.24, 0.31, 0.13);
	} else {  // turquesa leitoso dos degraus
		fundo = vec3(0.06, 0.20, 0.27);
		azul = vec3(0.12, 0.30, 0.38);
		turquesa = vec3(0.20, 0.40, 0.40);
		raso = vec3(0.32, 0.40, 0.33);
	}
	vec3 c = mix(fundo, azul, smoothstep(0.02, 0.30, d));
	c = mix(c, turquesa, smoothstep(0.40, 0.66, d));
	c = mix(c, raso, smoothstep(0.76, 0.95, d));
	// no raso, a água pega a cor do fundo claro (a transparência faz o resto)
	c = mix(raso, c, smoothstep(0.05, 0.9, esp));

	// a superfície: o tremido da água quente, o centro que sobe em ondas largas e as bolhas
	float r1 = texture(ruido, wpos.xz * 0.45 + vec2(TIME * 0.03, 0.0)).r;
	float r2 = texture(ruido, wpos.zx * 0.45 - vec2(0.0, TIME * 0.025)).r;
	vec2 inc = vec2(r1 - 0.5, r2 - 0.5) * 0.25;
	float dc = length(rel);
	// (fraco e torto pelo ruído: forte e redondo, do alto parecia um alvo)
	float sobe = sin(dc * 3.0 + (r1 - 0.5) * 5.0 - TIME * 1.6) * exp(-dc / (raio * 0.2)) * 0.04;
	inc += normalize(rel + 1e-4) * sobe * bolhas;
	if (bolhas > 0.0) {
		vec2 dir;
		float aro = anel_bolhas(wpos.xz, TIME, dir) * bolhas * (1.0 - smoothstep(raio * 0.25, raio * 0.5, dc));
		inc += dir * 0.6;
		c = mix(c, raso + vec3(0.18), clamp(aro, 0.0, 1.0) * 0.35);
	}
	NORMAL_MAP = vec3(0.5 + inc.x, 0.5 + inc.y, 1.0);
	ALBEDO = c;
	ROUGHNESS = 0.08;
	SPECULAR = 0.45;
	// a beira some no chão e o raso deixa ver o fundo
	ALPHA = smoothstep(0.0, 0.18, esp) * mix(0.5, 0.96, smoothstep(0.15, 1.3, esp));
}
