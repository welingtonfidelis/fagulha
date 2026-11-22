shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;

// Rio e córrego do cânion, em estilo pintado: cor em 3 faixas suaves de profundidade,
// refração discreta (no máximo ~45%), espuma da beira com borda recortada e
// riscas de espuma longas e esparsas seguindo a correnteza.
uniform vec3 raso : source_color = vec3(0.16, 0.42, 0.38);
uniform vec3 fundo : source_color = vec3(0.02, 0.07, 0.08);
uniform vec3 cor_espuma : source_color = vec3(0.92, 0.95, 0.94);
uniform vec2 fluxo = vec2(0.0, 1.0);
uniform float velocidade = 0.6;
// nas fitas dos rios a correnteza segue o curso (o UV da fita: x de margem a margem, y ao longo, rio abaixo);
// sem isso ela ia sempre para o mesmo lado do mapa e, em alguns trechos, a água parecia subir o rio
uniform bool pela_fita = false;
uniform float largura = 28.0;
uniform float uv_metros = 22.0;
uniform float forca_refracao = 0.06;
uniform float escala = 0.035;
uniform float prof_max = 9.0;
uniform float prof_espuma = 0.45;
// quedas d'água feitas na própria fita (os rios de degelo da terra nova): a parte em pé vira água branca
uniform float espuma_queda = 0.0;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying vec3 wpos;

// profundidade (m) do que está atrás da água, nesta posição da tela
// (a matriz inversa e a altura da água vêm do fragment, pois o built-in não existe fora dele)
float profundidade_em(vec2 uv, mat4 inv_proj, float z_agua) {
	float d = texture(depth_tex, uv).r;
	vec4 vista = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	vista.xyz /= vista.w;
	return z_agua - vista.z;
}

// declive do ruído em p: aproximação da derivada por diferenças centrais
vec2 declive(vec2 p) {
	float e = 0.02;
	float a = texture(ruido, p + vec2(e, 0.0)).r - texture(ruido, p - vec2(e, 0.0)).r;
	float b = texture(ruido, p + vec2(0.0, e)).r - texture(ruido, p - vec2(0.0, e)).r;
	return vec2(a, b);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 fn = pela_fita ? vec2(0.0, 1.0) : normalize(fluxo);
	vec2 pe = vec2(-fn.y, fn.x);
	vec2 p = pela_fita ? vec2((UV.x - 0.5) * largura, UV.y * uv_metros) : wpos.xz;
	float t = TIME * velocidade;

	// normal das ondas: duas camadas de ruído, escalas e velocidades diferentes
	// (o desenho anda para +fn: por isso o tempo entra com sinal de menos)
	vec2 g = declive(p * escala - fn * t * 0.08)
		+ declive(p * escala * 1.9 + vec2(0.31, 0.17) - fn * t * 0.14) * 0.6;
	vec3 n_mundo = normalize(vec3(-g.x * 0.6, 1.0, -g.y * 0.6));
	vec3 n_vista = normalize((VIEW_MATRIX * vec4(n_mundo, 0.0)).xyz);
	NORMAL = n_vista;

	// profundidade da água e refração: a tela deslocada só vale onde cai atrás da água
	float prof0 = max(0.0, profundidade_em(SCREEN_UV, INV_PROJECTION_MATRIX, VERTEX.z));
	vec2 desloc = n_vista.xy * forca_refracao;
	vec2 uv_ref = SCREEN_UV + desloc;
	if (profundidade_em(uv_ref, INV_PROJECTION_MATRIX, VERTEX.z) < 0.05) {
		uv_ref = SCREEN_UV;
	}
	vec3 atras = texture(screen_tex, uv_ref).rgb;

	// profundidade suave: 0 em 0 m, fundo dominante a partir de ~2,5 m
	float k = smoothstep(0.0, 2.5, prof0);
	// três faixas de cor, com transição suave dentro de cada faixa (sem degrau duro)
	float b = k * 3.0;
	float faixa = (floor(b) + smoothstep(0.3, 0.7, fract(b))) / 3.0;
	vec3 cor_agua = mix(raso, fundo, faixa);

	// refração no máximo ~45% e escurecida, sumindo conforme a água fica funda
	float w_ref = 0.45 * (1.0 - k);
	vec3 atras_tinta = atras * vec3(0.55, 0.8, 0.7) * mix(1.0, 0.5, faixa);
	vec3 corpo = mix(cor_agua, atras_tinta, w_ref);

	// espuma na beira: borda recortada e limpa, quebrada por ruído
	float beira = 1.0 - smoothstep(0.0, prof_espuma, prof0);
	float quebra = texture(ruido, p * escala * 0.9 - fn * t * 0.05).r;
	float espuma_borda = smoothstep(0.5, 0.56, beira + (quebra - 0.5) * 0.35);

	// riscas de espuma: esticadas no sentido da correnteza (longas e finas),
	// limiar alto para poucas riscas, aparecendo e sumindo devagar
	float ao_longo = dot(p, fn);
	float ao_traves = dot(p, pe);
	float n_risca = texture(ruido, vec2(ao_traves * 0.25, (ao_longo - TIME * velocidade * 2.0) * 0.02)).r;
	float riscas = smoothstep(0.8, 0.86, n_risca);
	float presenca = smoothstep(0.45, 0.7, texture(ruido, p * 0.012 - fn * t * 0.02 + vec2(0.5, 0.2)).r);
	riscas *= presenca * (1.0 - espuma_borda) * 0.85;

	// brilho pequeno e definido nas faces de onda voltadas para a luz
	float brilho = 0.0;  // o brilho por face de onda virava um pontilhado branco; saiu (revisão do líder)

	float espuma = clamp(espuma_borda * 0.7 + riscas * 0.6, 0.0, 1.0);
	ALBEDO = mix(corpo + brilho, cor_espuma, espuma * 0.85);

	// alfa: quase transparente na beira, opaco no fundo; fresnel deixa mais opaco em ângulo raso
	float cos_v = clamp(dot(n_vista, normalize(VIEW)), 0.0, 1.0);
	float fres = 0.04 + 0.96 * pow(1.0 - cos_v, 5.0);
	float base = mix(0.1, 0.95, smoothstep(0.0, 1.5, prof0));
	ALPHA = clamp(base + fres * (1.0 - base) * 0.7 + espuma * 0.4, 0.0, 1.0);

	if (espuma_queda > 0.0) {
		vec3 face = normalize(cross(dFdy(wpos), dFdx(wpos)));
		float em_pe = (1.0 - smoothstep(0.45, 0.85, abs(face.y))) * espuma_queda;
		// fios de água caindo depressa (pela altura, que é o que muda na parte em pé)
		float fio = texture(ruido, vec2(ao_traves * 0.35, (wpos.y + TIME * 9.0) * 0.035)).r;
		float fio2 = texture(ruido, vec2(ao_traves * 0.9 + 0.37, (wpos.y + TIME * 13.0) * 0.08)).r;
		vec3 branca = mix(vec3(0.42, 0.62, 0.64), cor_espuma, smoothstep(0.35, 0.62, fio * 0.7 + fio2 * 0.5));
		ALBEDO = mix(ALBEDO, branca, em_pe);
		ALPHA = mix(ALPHA, 0.9, em_pe);
	}
	ROUGHNESS = 0.05;
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
