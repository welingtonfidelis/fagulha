// Estilo do vale (técnica de luz em faixas): funções comuns.

// Troca por distância, peça a peça (árvores, plantas e pedras em MultiMesh). As distâncias vêm no dado de
// cada peça (INSTANCE_CUSTOM: x = some até aqui, y = surge a partir daqui; zero desliga, e fora de MultiMesh
// é sempre zero). O modelo de perto some aos poucos até x; o de longe aparece na mesma faixa até y. A
// distância é da peça até a câmera do jogo (também na passada de sombra), e a transição é em pontilhado:
// as duas tramas são o avesso uma da outra, então onde uma peça some a outra aparece.
// Devolve (quanto aparece de 0 a 1, 1 se a trama é a do avesso).
const float FAIXA_TROCA = 34.0;
// A qualidade do desenho encurta todas as distâncias de troca (1 na alta; Qualidade.aplicar).
global uniform float troca_fator;
// Teste de luz e cor (2026-11-18, branch visual-luz-e-cor): 1 liga o visual novo, 0 mostra o de antes
// (`-- --visual-antigo`). Capim mais amarelo no sol, luz que atravessa as folhas, faixa de luz mais macia.
global uniform float estilo_novo;

vec2 presenca(vec4 dado, vec3 origem, vec3 cam) {
	float d = distance(origem, cam);
	float p = 1.0;
	float some = dado.x * troca_fator;
	float surge = dado.y * troca_fator;
	if (dado.x > 0.0) {
		p *= 1.0 - smoothstep(some - FAIXA_TROCA, some, d);
	}
	if (dado.y > 0.0) {
		p *= smoothstep(surge - FAIXA_TROCA, surge, d);
	}
	return vec2(p, dado.y > 0.0 && d < surge ? 1.0 : 0.0);
}

bool fora_da_trama(vec2 pr, vec2 px) {
	if (pr.x >= 1.0) {
		return false;
	}
	float t = fract(52.9829189 * fract(dot(floor(px), vec2(0.06711056, 0.00583715))));
	if (pr.y > 0.5) {
		t = 1.0 - t;
	}
	return pr.x <= t;
}

// Luz em duas faixas: sombra e luz com transição curta, mais um realce no lado bem voltado ao sol.
vec3 luz_faixas(vec3 n, vec3 l, vec3 cor_luz, float aten) {
	float nl = dot(n, l);
	float faixa = smoothstep(-0.02, mix(0.07, 0.2, estilo_novo), nl);
	float realce = smoothstep(0.62, 0.70, nl) * mix(0.16, 0.24, estilo_novo);
	return cor_luz * aten * (faixa * 0.86 + realce);
}

// Cor do capim num ponto do mundo (o chão e as folhas de capim usam a mesma, para casarem).
vec3 cor_capim(sampler2D r, vec2 p) {
	float a = texture(r, p * 0.011).r;
	float b = texture(r, p * 0.043 + vec2(0.31)).r;
	vec3 c = mix(vec3(0.085, 0.21, 0.065), vec3(0.17, 0.30, 0.075), smoothstep(0.3, 0.7, a));
	c = mix(c, vec3(0.30, 0.33, 0.11), smoothstep(0.62, 0.8, b) * 0.5);  // manchas secas
	c = mix(c, vec3(0.05, 0.15, 0.075), smoothstep(0.66, 0.82, 1.0 - a) * 0.5);  // manchas fundas
	// visual novo: verde-amarelado e mais vivo (a sombra azulada vem da luz ambiente)
	c = mix(c, c * vec3(1.14, 1.12, 0.6) + vec3(0.008, 0.016, 0.0), estilo_novo);
	return c;
}

// O campo de capim visto de longe, pintado no chão: as mesmas cores das folhas (da raiz à ponta) em
// tufos miúdos e moitas largas, e a rajada de vento passando por cima, igual à que balança o capim.
vec3 capim_de_longe(sampler2D r, vec2 p, float tempo) {
	vec3 base = cor_capim(r, p);
	vec2 q = vec2(p.x * 0.8 + p.y * 0.6, p.y * 0.8 - p.x * 0.6);
	float n = texture(r, q * vec2(1.1, 0.5)).r * 0.5 + texture(r, q.yx * 0.19 + vec2(0.7, 0.2)).r * 0.5;
	n = smoothstep(0.34, 0.66, n);
	vec3 c = mix(base * vec3(0.60, 0.63, 0.63), base * vec3(0.99, 1.03, 1.03) + vec3(0.006, 0.010, 0.0), n);
	float fase = dot(p, vec2(0.085, 0.05)) - tempo * 1.25;
	float rajada = smoothstep(0.2, 1.0, sin(fase) * 0.5 + 0.5 + 0.25 * sin(fase * 2.7 + p.x * 0.2));
	return c + vec3(0.022, 0.028, 0.004) * rajada * 0.5;
}

// Pedra das encostas e dos paredões, pintada: cinza claro em manchas largas e macias que escorrem
// na altura da parede, sem linha dura. O volume vem da luz em faixas sobre formas grandes e lisas.
vec3 cor_rocha(sampler2D r, vec3 p, vec3 n) {
	vec2 pl = vec2(p.x * 0.8 + p.z * 0.6, p.z * 0.8 - p.x * 0.6);
	// pinceladas compridas de cima para baixo, e manchas redondas por cima
	float a = texture(r, vec2(pl.x * 0.045 + pl.y * 0.03, p.y * 0.012 + pl.y * 0.02)).r;
	float b = texture(r, vec2(pl.x * 0.021, p.y * 0.021) + vec2(pl.y * 0.017, 0.4)).r;
	float fino = texture(r, vec2(pl.x * 0.16 + pl.y * 0.1, p.y * 0.05)).r;
	vec3 c = mix(vec3(0.17, 0.172, 0.18), vec3(0.27, 0.266, 0.258), smoothstep(0.28, 0.72, a * 0.6 + b * 0.4));
	c = mix(c, vec3(0.305, 0.30, 0.285), smoothstep(0.62, 0.8, b) * 0.6);  // lavado claro
	c *= mix(0.9, 1.04, fino);
	// camadas quase apagadas, só para a parede não ficar chapada de perto
	float e = p.y * 0.3 + b * 2.0;
	c *= mix(0.9, 1.0, smoothstep(0.0, 0.25, fract(e)));
	// as faces viradas para baixo e as fendas escurecem
	c *= mix(0.7, 1.05, smoothstep(-0.5, 0.6, n.y));
	return c;
}
