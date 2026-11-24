shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// As quedas d'água do jogo (QuedaDagua, doc §164), em desenho: o meio da água mais fundo, as beiras e a curva da
// beirada mais claras, riscas descendo depressa em faixas de cor, o pé virando espuma e calombos descendo (o contorno
// mexe). A mesma malha, com `casca`, é a espuma branca rasgada por fora da água. UV.x atravessa a fita, UV.y é o
// comprimento (em 8 m) e a cor do vértice (r) diz de 0 a 1 quanto da fita já passou.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float correnteza = 3.2;  // m/s que as riscas descem (bem mais devagar que a água de verdade: mais rápido, piscava)
uniform float espuma_pe = 1.0;  // quanto o pé da fita vira espuma
uniform float rasa = 0.0;  // 1 na água deitada em cima do degrau: mais espuma e corrente mais lenta
uniform float corte = 1.0;  // 1 recorta a beirada da fita aberta; 0 na queda fechada (tubo)
uniform float bolo = 0.0;  // calombos descendo com a água: o contorno da queda mexe e não fica uma linha lisa
uniform float casca = 0.0;  // 1 na casca de espuma em volta da queda: branca, furada pelo ruído, mais cheia embaixo e nas beiradas
uniform vec3 fundo : source_color = vec3(0.15, 0.42, 0.62);
uniform vec3 meio : source_color = vec3(0.33, 0.64, 0.82);
uniform vec3 claro : source_color = vec3(0.63, 0.85, 0.94);
uniform vec3 espuma : source_color = vec3(0.95, 0.98, 1.0);

varying float prog;

void vertex() {
	prog = COLOR.r;
	float onda = sin(UV.y * 5.0 - TIME * 1.6 + UV.x * 2.5) * 0.6 + sin(UV.y * 9.0 - TIME * 2.4) * 0.4;
	// as contas de tempo vão em metros: L é o comprimento da fita até aqui, `desce` o quanto a água já andou
	float L = UV.y * 8.0;
	float desce = TIME * correnteza;
	float calombo = textureLod(ruido, vec2(UV.x * 0.55 + 0.13, (L - desce * 0.8) * 0.0625), 0.0).r
		+ textureLod(ruido, vec2(UV.x * 1.3 + 0.61, (L - desce) * 0.09), 0.0).r * 0.5 - 0.75;
	VERTEX += NORMAL * (onda * 0.09 + calombo * bolo * (0.35 + prog)) * smoothstep(0.03, 0.3, prog) * (1.0 - rasa);
}

void fragment() {
	float L = UV.y * 8.0;
	float desce = TIME * correnteza * mix(1.0, 0.4, rasa);
	vec2 uv = UV;
	uv.x += (texture(ruido, vec2(uv.x * 1.1 + 0.3, (L - desce * 0.5) * 0.0375)).r - 0.5) * 0.08;
	// riscas largas e compridas, descendo: o ruído é lido num mip mais alto (sem o miúdo, que piscava) e esticado
	float n = textureLod(ruido, vec2(uv.x * 0.8, (L - desce) * 0.02), 1.6).r * 0.75
		+ textureLod(ruido, vec2(uv.x * 1.7 + 0.4, (L - desce * 1.15) * 0.045), 1.6).r * 0.25;
	n = smoothstep(0.3, 0.75, n);
	// o meio é mais fundo; as beiras e a curva da beirada, mais claras
	float no_meio = 1.0 - abs(UV.x - 0.5) * 2.0;
	float tom = mix(0.8, 0.12, smoothstep(0.1, 0.8, no_meio)) + n * 0.6;
	tom += (1.0 - smoothstep(0.0, 0.1, prog)) * 0.45 * (1.0 - rasa);
	float q = floor(clamp(tom, 0.0, 0.999) * 3.0);
	vec3 c = q < 0.5 ? fundo : (q < 1.5 ? meio : claro);
	// riscas brancas finas, as que mais correm
	float risca = smoothstep(0.78, 0.86, textureLod(ruido, vec2(uv.x * 1.3 + 0.7, (L - desce * 1.2) * 0.012), 1.2).r);
	c = mix(c, espuma, risca);
	// o pé em espuma, e a água rasa do degrau mais branca
	float pe = smoothstep(0.84, 1.0, prog) * espuma_pe;
	c = mix(c, espuma, clamp(pe * (0.6 + n) + rasa * smoothstep(0.55, 0.8, n) * 0.8, 0.0, 1.0));
	float lado = min(UV.x, 1.0 - UV.x);
	ALPHA = step(0.03 * corte, lado + (n - 0.5) * 0.06 * corte);
	if (casca > 0.5) {
		// a espuma corre mais depressa que a água de dentro e se rasga em tufos; cobre pouco perto da beirada de
		// cima e quase tudo no pé, e mais nas beiradas da queda (de lado é o que se vê)
		float nf = textureLod(ruido, vec2(UV.x * 1.1 + 0.17, (L - desce * 1.25) * 0.02), 1.6).r * 0.7
			+ textureLod(ruido, vec2(UV.x * 2.4 + 0.53, (L - desce * 1.4) * 0.05), 1.2).r * 0.3;
		float beira = smoothstep(0.22, 0.0, lado);
		float quanto = mix(0.04, 0.36, smoothstep(0.08, 1.0, prog)) + beira * 0.3 + smoothstep(0.86, 1.0, prog) * 0.3;
		float tufo = nf - (1.0 - quanto) * 0.82;
		ALPHA = step(0.0, tufo);
		c = mix(mix(claro, espuma, 0.55), espuma, smoothstep(0.0, 0.1, tufo));
	}
	ALBEDO = c;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.25;
	EMISSION = c * 0.16;
}
