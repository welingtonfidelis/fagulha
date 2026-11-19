shader_type sky;

// O céu do vale: o mesmo degradê e o mesmo sol do céu pronto do Godot, mas com as nuvens num teto
// plano bem alto. Antes a textura das nuvens era enrolada no céu como um mapa-múndi e tudo se juntava
// no ponto bem acima da cabeça.
uniform vec3 topo : source_color = vec3(0.14, 0.30, 0.58);
uniform vec3 horizonte : source_color = vec3(0.62, 0.78, 0.90);
uniform vec3 chao : source_color = vec3(0.30, 0.42, 0.40);
uniform float curva = 0.12;
uniform float sol_abertura = 20.0;  // graus do clarão em volta do sol
uniform sampler2D nuvens : repeat_enable, filter_linear_mipmap;
uniform vec4 cor_nuvens : source_color = vec4(1.0);
uniform float nuvem_de = 0.55;  // quanto do ruído vira nuvem: abaixo disso é céu limpo
uniform float nuvem_ate = 0.66;
uniform float escala = 0.11;
uniform vec2 vento = vec2(0.0016, 0.0007);
uniform float volume = 0.0;  // visual novo: nuvens de borda firme, com a barriga lilás
uniform vec3 cor_barriga : source_color = vec3(0.70, 0.70, 0.95);

void sky() {
	float ang = acos(clamp(EYEDIR.y, -1.0, 1.0));
	vec3 cor;
	if (EYEDIR.y >= 0.0) {
		float c = 1.0 - ang / (PI * 0.5);
		cor = mix(horizonte, topo, clamp(1.0 - pow(1.0 - c, 1.0 / curva), 0.0, 1.0));
		if (LIGHT0_ENABLED) {
			float a_sol = acos(clamp(dot(LIGHT0_DIRECTION, EYEDIR), -1.0, 1.0));
			float fim = radians(sol_abertura);
			vec3 luz = LIGHT0_COLOR * LIGHT0_ENERGY;
			if (a_sol < LIGHT0_SIZE) {
				cor = luz;
			} else if (a_sol < fim) {
				float c2 = (a_sol - LIGHT0_SIZE) / (fim - LIGHT0_SIZE);
				cor = mix(luz, cor, clamp(1.0 - pow(1.0 - c2, 1.0 / 0.15), 0.0, 1.0));
			}
		}
		// nuvens: o olhar fura um teto plano; perto do horizonte elas somem na bruma
		vec2 uv = EYEDIR.xz / (EYEDIR.y + 0.16) * escala + TIME * vento;
		float n = texture(nuvens, uv).r * 0.72 + texture(nuvens, uv * 2.7 + 0.37).r * 0.28;
		float nuvem = smoothstep(nuvem_de, nuvem_ate, n) * 0.95 * smoothstep(0.015, 0.16, EYEDIR.y);
		if (volume > 0.0) {
			// a nuvem tapa o céu (em vez de somar luz) e tem a parte de baixo mais escura e lilás: a "espessura"
			// vem de comparar o ruído com o de um ponto um pouco mais para o lado do sol
			vec2 para_sol = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION.xz + vec2(0.001)) * 0.02 : vec2(0.02, 0.0);
			float n2 = texture(nuvens, uv + para_sol).r * 0.72 + texture(nuvens, (uv + para_sol) * 2.7 + 0.37).r * 0.28;
			float luz_n = smoothstep(-0.03, 0.05, n2 - n);
			vec3 cn = mix(cor_barriga * cor_nuvens.rgb, vec3(1.0, 0.99, 0.97) * cor_nuvens.rgb, luz_n * 0.75 + 0.25);
			cor = mix(cor, cn, nuvem * cor_nuvens.a);
		} else {
			cor += vec3(1.0, 0.98, 0.95) * cor_nuvens.rgb * nuvem * cor_nuvens.a;
		}
	} else {
		float c = (ang - PI * 0.5) / (PI * 0.5);
		cor = mix(horizonte, chao, clamp(1.0 - pow(1.0 - c, 1.0 / 0.02), 0.0, 1.0));
	}
	COLOR = cor;
}
