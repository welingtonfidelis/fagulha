// Estilo do vale (técnica de luz em faixas): funções comuns.

// Troca por distância, peça a peça (árvores, plantas e pedras em MultiMesh). As distâncias vêm no dado de
// cada peça (INSTANCE_CUSTOM: x = some até aqui, y = surge a partir daqui; zero desliga, e fora de MultiMesh
// é sempre zero). O modelo de perto some aos poucos até x; o de longe aparece na mesma faixa até y. A
// distância é da peça até a câmera do jogo (também na passada de sombra), e a transição é em pontilhado:
// as duas tramas são o avesso uma da outra, então onde uma peça some a outra aparece.
// Devolve (quanto aparece de 0 a 1, 1 se a trama é a do avesso).
const float FAIXA_TROCA = 34.0;

vec2 presenca(vec4 dado, vec3 origem, vec3 cam) {
	float d = distance(origem, cam);
	float p = 1.0;
	if (dado.x > 0.0) {
		p *= 1.0 - smoothstep(dado.x - FAIXA_TROCA, dado.x, d);
	}
	if (dado.y > 0.0) {
		p *= smoothstep(dado.y - FAIXA_TROCA, dado.y, d);
	}
	return vec2(p, dado.y > 0.0 && d < dado.y ? 1.0 : 0.0);
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
	float faixa = smoothstep(-0.02, 0.07, nl);
	float realce = smoothstep(0.62, 0.70, nl) * 0.16;
	return cor_luz * aten * (faixa * 0.86 + realce);
}

// Cor do capim num ponto do mundo (o chão e as folhas de capim usam a mesma, para casarem).
vec3 cor_capim(sampler2D r, vec2 p) {
	float a = texture(r, p * 0.011).r;
	float b = texture(r, p * 0.043 + vec2(0.31)).r;
	vec3 c = mix(vec3(0.085, 0.21, 0.065), vec3(0.17, 0.30, 0.075), smoothstep(0.3, 0.7, a));
	c = mix(c, vec3(0.30, 0.33, 0.11), smoothstep(0.62, 0.8, b) * 0.5);  // manchas secas
	c = mix(c, vec3(0.05, 0.15, 0.075), smoothstep(0.66, 0.82, 1.0 - a) * 0.5);  // manchas fundas
	return c;
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
