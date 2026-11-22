// O chão da terra nova sem o relevo, para quem precisa da mesma cor: a cobertura de um ponto da grade (no
// vértice) e a cor do chão (no fragmento). Usado pelo chão (terra_nova_chao) e pela pele das peças de rocha que
// refazem o chão por cima de uma caverna (boca_degelo). Precisa de vale_comum incluído antes.

int tn_codigo(sampler2D cob, ivec2 tam, ivec2 c) {
	return int(round(texelFetch(cob, clamp(c, ivec2(0), tam - ivec2(1)), 0).r * 255.0));
}

// ti: como o COLOR do vale_chao (r terra, g margem, b areia, a 1 - flores); ex: r neve, g boreal, b cascalho,
// a campina alpina; pf: pedra; fo: as fontes quentes (r sínter, g esteira laranja, b brejo)
void tn_cobertura(sampler2D cob, ivec2 tam, ivec2 c, float h, out vec4 ti, out vec4 ex, out float pf, out vec3 fo) {
	// a cobertura é a média dos 9 pontos em volta: as bordas (neve, pedra, cascalho) saem suaves, sem degraus
	vec4 e = vec4(0.0);
	vec4 t = vec4(0.0);
	float pd = 0.0;
	vec3 ft = vec3(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			int cod = tn_codigo(cob, tam, c + ivec2(i, j));
			ft += vec3(cod == 10 ? 1.0 : 0.0, cod == 11 ? 1.0 : 0.0, cod == 12 ? 1.0 : 0.0);
			e += vec4(cod == 5 ? 1.0 : 0.0, 0.0, cod == 8 ? 1.0 : 0.0, cod == 7 ? 1.0 : 0.0);
			t += vec4(cod == 2 ? 0.3 : 0.0, 0.0, cod == 4 ? 1.0 : (cod == 9 ? 0.62 : 0.0), cod == 3 ? 0.0 : 1.0);
			pd += cod == 6 ? 1.0 : 0.0;
		}
	}
	e /= 9.0;
	t /= 9.0;
	float areia = max(t.b, 1.0 - smoothstep(1.5, 4.5, h));
	ti = vec4(t.r, 0.0, areia, t.a);
	ex = vec4(e.r, texelFetch(cob, clamp(c, ivec2(0), tam - ivec2(1)), 0).g, e.b, e.a);
	pf = pd / 9.0;
	fo = ft / 9.0;
}

// A cor do chão num ponto. `face` é a normal do triângulo (dFdx/dFdy no fragmento, virada para cima); `neve`
// sai com quanto o ponto é neve (para a aspereza).
vec3 tn_cor(sampler2D ruido, vec3 wpos, vec3 wnrm, vec3 face, vec4 ti, vec4 ex, float pf, vec3 fo, vec3 cam, float tempo, out float neve) {
	float r = texture(ruido, wpos.xz * 0.08).r;
	vec3 c = cor_capim(ruido, wpos.xz) * 0.92;
	float longe = smoothstep(38.0, 84.0, distance(wpos, cam));
	if (longe > 0.001) {
		c = mix(c, capim_de_longe(ruido, wpos.xz, tempo), longe);
	}
	// os pés da montanha: capim mais frio e escuro, e o chão do pinheiral bem fechado
	float boreal = ex.g;
	c = mix(c, c * vec3(0.64, 0.78, 0.74) + vec3(0.0, 0.006, 0.01), boreal * 0.85);
	c = mix(c, vec3(0.06, 0.11, 0.08) * (0.85 + 0.3 * r), boreal * smoothstep(0.2, 0.3, ti.r) * 0.6);
	vec3 terra = mix(vec3(0.20, 0.145, 0.09), vec3(0.27, 0.21, 0.13), r);
	c = mix(c, terra, smoothstep(0.35, 0.6, ti.r + (r - 0.5) * 0.3) * (1.0 - boreal));
	vec3 areia = mix(vec3(0.29, 0.24, 0.145), vec3(0.36, 0.30, 0.19), r);
	c = mix(c, areia, smoothstep(0.3, 0.75, ti.b + (r - 0.5) * 0.25));
	// campina alpina: capim baixo, seco e acinzentado, com tufos
	float p3 = texture(ruido, wpos.xz * 0.19).r;
	vec3 alpina = mix(vec3(0.11, 0.13, 0.07), vec3(0.17, 0.18, 0.10), p3);
	c = mix(c, alpina, smoothstep(0.2, 0.7, ex.a + (r - 0.5) * 0.3));
	// cascalho claro do leito dos rios de degelo
	float p4 = texture(ruido, wpos.xz * 0.37).r;
	vec3 cascalho = mix(vec3(0.15, 0.16, 0.17), vec3(0.24, 0.245, 0.25), p4);
	c = mix(c, cascalho, smoothstep(0.25, 0.7, ex.b + (r - 0.5) * 0.35));
	// as fontes quentes: o brejo encharcado, escuro e oliva; a sínter, mineral branco-creme com veios; e a
	// esteira laranja de bactéria rente à água quente
	if (fo.r + fo.g + fo.b > 0.001) {
		float p5 = texture(ruido, wpos.xz * 0.27).r;
		// (a luz daqui é forte e quente e a tela satura: albedo 0,2 já sai creme quase branco e 0,1 de vermelho
		// já é laranja vivo, então tudo bem mais escuro e mais azulado que o real)
		vec3 brejo = mix(vec3(0.05, 0.062, 0.028), vec3(0.085, 0.09, 0.036), p5);
		float musgo_v = texture(ruido, wpos.zx * 0.09 + vec2(0.41, 0.07)).r;
		brejo = mix(brejo, vec3(0.095, 0.052, 0.03), smoothstep(0.6, 0.72, musgo_v) * 0.8);  // musgo avermelhado
		brejo = mix(brejo, vec3(0.03, 0.04, 0.034), smoothstep(0.62, 0.7, texture(ruido, wpos.xz * 0.05).r) * 0.6);
		c = mix(c, brejo, smoothstep(0.2, 0.7, fo.b + (r - 0.5) * 0.3));
		vec3 sinter = mix(vec3(0.11, 0.115, 0.118), vec3(0.145, 0.148, 0.15), p5);
		sinter = mix(sinter, vec3(0.13, 0.095, 0.06), smoothstep(0.55, 0.75, texture(ruido, wpos.xz * 0.11).r) * 0.55);
		c = mix(c, sinter, smoothstep(0.25, 0.65, fo.r + (r - 0.5) * 0.25));
		// laranja rente à água e marrom-ferrugem para fora, em faixas tortas
		vec3 esteira = mix(vec3(0.07, 0.042, 0.022), vec3(0.085, 0.052, 0.026), p5);
		esteira = mix(esteira, mix(vec3(0.10, 0.036, 0.01), vec3(0.12, 0.048, 0.012), p5), smoothstep(0.45, 0.85, fo.g + (r - 0.5) * 0.35));
		c = mix(c, esteira, smoothstep(0.25, 0.6, fo.g + (p5 - 0.5) * 0.3));
	}
	float flor = 1.0 - ti.a;
	if (flor > 0.01) {
		float p1 = texture(ruido, wpos.xz * 0.22).r;
		float p2 = texture(ruido, wpos.zx * 0.31 + vec2(0.31, 0.17)).r;
		float mancha = texture(ruido, wpos.xz * 0.012).r;
		// nas campinas da montanha: lupinos (roxo e rosa), arnica (amarelo) e branco
		vec3 cf = mancha < 0.45 ? vec3(0.42, 0.18, 0.78) : (mancha < 0.55 ? vec3(0.86, 0.32, 0.55) : (mancha < 0.64 ? vec3(0.92, 0.62, 0.05) : vec3(0.90, 0.88, 0.80)));
		vec3 cf2 = mancha > 0.5 ? vec3(0.92, 0.62, 0.05) : vec3(0.90, 0.88, 0.80);
		c = mix(c, cf, smoothstep(0.55, 0.62, p1) * flor * 0.85);
		c = mix(c, cf2, smoothstep(0.60, 0.66, p2) * flor * 0.75);
	}
	// a inclinação de cada triângulo (a normal suave enganava nas paredes altas: a neve da beira de cima
	// escorria pela parede em listras)
	float ny = min(wnrm.y, face.y + 0.06);
	// a pedra da montanha: granito escuro e frio. Com a cor da pedra do vale, a luz forte e quente do sol a
	// deixava bege, quase branca, e a neve sumia nela (o azul a mais compensa o sol amarelo)
	float montanha = smoothstep(8.0, 40.0, wpos.y) * smoothstep(0.1, 0.5, ex.g);
	vec3 pedra = cor_rocha(ruido, wpos, vec3(wnrm.x, ny, wnrm.z)) * mix(vec3(1.0), vec3(0.29, 0.325, 0.42), montanha);
	float borda = ny + (r - 0.5) * 0.22 + (texture(ruido, wpos.xz * 0.31).r - 0.5) * 0.12;
	c = mix(c, pedra, max(smoothstep(0.80, 0.68, borda), smoothstep(0.3, 0.8, pf + (r - 0.5) * 0.4)));
	// neve: acima da linha dela fica em todo chão que não é parede; mais alto, gruda até nas encostas fortes
	float alto = smoothstep(400.0, 500.0, wpos.y + (r - 0.5) * 70.0);
	float lim = mix(0.6, 0.36, smoothstep(470.0, 760.0, wpos.y));
	neve = max(ex.r, alto) * smoothstep(lim - 0.1, lim + 0.1, ny + (r - 0.5) * 0.3 + (p3 - 0.5) * 0.18);
	vec3 cor_neve = mix(vec3(0.50, 0.53, 0.59), vec3(0.58, 0.60, 0.65), smoothstep(0.3, 0.7, p4));
	c = mix(c, cor_neve, neve);
	return c;
}
