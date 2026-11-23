// O chão em volta das fontes quentes (2026-11-22, a partir da revisão do game designer). Antes a cor vinha só da
// cobertura de 4 m do gerador: um laranja largo, liso e de um tom, em anéis iguais em volta de cada poça. Aqui,
// para cada poça, por fora da crosta de sínter (FontesQuentes):
// - as faixas pelo calor, a partir da beira de verdade (`fq_contorno`): um fio creme-amarelo molhado, o laranja
//   estreito das bactérias, ferrugem, marrom-oliva e a sínter cinza-branca rachada, que se desfaz no chão;
// - o canal de escoamento: a poça transborda pelo lado mais baixo (`fq_saida`) num leque de dedos laranja e
//   marrom morro abaixo, com uma lâmina d'água que brilha;
// - dentro da água, o fundo claro de mineral (a água é transparente no raso).
// Usado só pelo chão da terra nova (terra_nova_chao), depois do tn_cor.
uniform int fq_n = 0;
uniform vec4 fq_pocas[16];  // x, z, raio, onde acaba a crosta (além do contorno)
uniform vec4 fq_saida[16];  // direção da saída (x, z), comprimento do canal, nível da água
uniform vec3 fq_bacia = vec3(0.0, 0.0, -1.0);  // centro (x, z) e raio da bacia
uniform sampler2D fq_contorno : filter_linear, repeat_enable;  // linha k: o raio da beira em 64 ângulos
uniform vec4 fq_lamas[2];  // as poças de lama: x, z, raio (0 = nenhuma)

const float FQ_TAU = 6.28318530718;

vec3 fq_cor(sampler2D ruido, vec3 wpos, vec3 c, out float molhado) {
	molhado = 0.0;
	if (fq_n == 0 || distance(wpos.xz, fq_bacia.xy) > fq_bacia.z) {
		return c;
	}
	float n1 = texture(ruido, wpos.xz * 0.23).r;
	float n2 = texture(ruido, wpos.zx * 0.071 + vec2(0.3, 0.6)).r;
	float n3 = texture(ruido, wpos.xz * 0.9 + vec2(0.17, 0.4)).r;
	float fundo = 0.0;  // dentro d'água de alguma poça (os degraus ficam colados: a faixa de uma não pinta o fundo da outra)
	for (int k = 0; k < fq_n; k++) {
		vec4 p = fq_pocas[k];
		vec4 sa = fq_saida[k];
		vec2 rel = wpos.xz - p.xy;
		float d = length(rel);
		float s = clamp(sqrt(p.z / 24.0), 0.45, 1.0);
		if (d > p.z + 34.0 * s + sa.z) {
			continue;
		}
		float ang = atan(rel.y, rel.x);
		float rc = texture(fq_contorno, vec2(ang / FQ_TAU, (float(k) + 0.5) / 16.0)).r;
		// dentro d'água: o fundo de mineral claro
		if (d < rc) {
			fundo = max(fundo, smoothstep(rc, rc - 0.6, d));
			continue;
		}
		// as faixas pelo calor, contadas da ponta de fora da crosta, tortas pelo ruído
		float e = d - rc - p.w + (n1 - 0.5) * 1.1 * s + (n2 - 0.5) * 1.6 * s;
		float w0 = 0.45 * s;  // fio creme molhado
		float w1 = w0 + 3.0 * s;  // laranja
		float w2 = w1 + 2.4 * s;  // ferrugem
		float w3 = w2 + 3.2 * s;  // marrom-oliva
		float w4 = w3 + 7.0 * s;  // sínter
		float w5 = w4 + 5.0;  // some no chão
		if (e < w5) {
			// raios finos na esteira (a bactéria cresce em fios, para fora)
			float fios = 0.5 + 0.5 * sin(ang * (60.0 + 40.0 * s) + n2 * 9.0);
			vec3 creme = vec3(0.19, 0.16, 0.075);
			vec3 laranja = mix(vec3(0.115, 0.045, 0.011), vec3(0.13, 0.06, 0.014), fios * n3);
			vec3 ferrugem = mix(vec3(0.075, 0.036, 0.018), vec3(0.085, 0.045, 0.022), n3);
			vec3 oliva = mix(vec3(0.052, 0.048, 0.028), vec3(0.06, 0.055, 0.03), n1);
			vec3 sinter = mix(vec3(0.12, 0.12, 0.115), vec3(0.15, 0.148, 0.14), n3);
			float racha = smoothstep(0.03, 0.0, abs(texture(ruido, wpos.xz * 0.55).r - 0.5));
			sinter *= 1.0 - racha * 0.4;
			vec3 f = creme;
			float e_beira = d - rc - p.w + (n3 - 0.5) * 0.35 * s + (fios - 0.5) * 0.25;
			f = mix(f, laranja, smoothstep(w0 - 0.15, w0 + 0.25, e_beira));
			f = mix(f, ferrugem, smoothstep(w1 - 0.6 * s, w1 + 0.6 * s, e));
			f = mix(f, oliva, smoothstep(w2 - 0.8 * s, w2 + 0.8 * s, e));
			f = mix(f, sinter, smoothstep(w3 - 1.2 * s, w3 + 1.2 * s, e));
			c = mix(f, c, smoothstep(w4, w5, e));
			// molhado na faixa da beira e no laranja, sem o ruído (senão o sol acende manchas soltas)
			float e0 = d - rc - p.w;
			molhado = max(molhado, 0.75 * (1.0 - smoothstep(0.0, w1 + 0.5, e0)));
		}
		// o canal de escoamento: um leque de dedos morro abaixo, a partir do lado de saída
		if (sa.z > 0.0) {
			vec2 o = sa.xy;
			float rs = texture(fq_contorno, vec2(atan(o.y, o.x) / FQ_TAU, (float(k) + 0.5) / 16.0)).r + p.w * 0.5;
			vec2 q = wpos.xz - (p.xy + o * rs);
			float ao_longo = dot(q, o);
			float lado = dot(q, vec2(-o.y, o.x));
			if (ao_longo > -0.5 && ao_longo < sa.z) {
				float u = ao_longo / sa.z;
				float largo = (0.7 + 0.16 * p.z) * (0.35 + 1.3 * u);
				float torto = lado + (n2 - 0.5) * 1.6 * s + sin(ao_longo * 0.13) * 0.5 * s;
				// uma faixa molhada que se abre morro abaixo, com a beira torta e riscos ao longo da descida
				float bn = (n1 - 0.5) * 0.6 * largo;
				float dentro = smoothstep(largo + bn, largo * 0.45 + bn, abs(torto));
				float riscos = texture(ruido, vec2(torto * 0.35 / s + float(k) * 0.37, ao_longo * 0.02)).r;
				float meio = smoothstep(largo * 0.25, 0.0, abs(torto)) * (1.0 - u);
				float m = dentro * (1.0 - smoothstep(0.55, 1.0, u)) * smoothstep(-0.5, 0.3, ao_longo);
				vec3 cc = mix(mix(vec3(0.17, 0.13, 0.05), vec3(0.12, 0.05, 0.012), smoothstep(0.0, 0.25, u)), vec3(0.07, 0.042, 0.022), smoothstep(0.3, 0.85, u));
				cc *= mix(0.72, 1.12, riscos);
				c = mix(c, cc, m * 0.9);
				molhado = max(molhado, meio * 0.9 + m * 0.35 * (1.0 - u));
			}
		}
	}
	c = mix(c, mix(vec3(0.15, 0.14, 0.10), vec3(0.19, 0.175, 0.12), n3), fundo);
	// em volta das poças de lama: respingos de lama seca, cinza, que se desfazem no capim
	for (int k = 0; k < 2; k++) {
		vec4 l = fq_lamas[k];
		if (l.z <= 0.0) {
			continue;
		}
		float dl = distance(wpos.xz, l.xy) - l.z + (n1 - 0.5) * 1.8 + (n3 - 0.5) * 0.8;
		float m = 1.0 - smoothstep(0.4, 3.2, dl);
		c = mix(c, mix(vec3(0.085, 0.08, 0.07), vec3(0.11, 0.104, 0.09), n2), m);
	}
	molhado *= 1.0 - fundo;
	return c;
}
