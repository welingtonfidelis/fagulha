// Estilo do vale (técnica de luz em faixas): funções comuns.

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
