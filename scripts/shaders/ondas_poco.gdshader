shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// As ondas no pé das quedas d'água (QuedaDagua.ondas): uma tinta azul-clara perto de onde a água bate (no poço da
// cachoeira, o fundo não aparece mais como cascalho), anéis claros saindo dali, tortos pelo ruído e sumindo ao longe,
// e espuma boiando perto do pé.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float raio = 20.0;
uniform vec3 cor : source_color = vec3(0.9, 0.96, 1.0);
uniform vec3 azul : source_color = vec3(0.30, 0.62, 0.82);
uniform vec2 poco_centro = vec2(0.0);  // o meio do poço, visto daqui (o disco fica no pé das quedas)
uniform float poco_raio = 0.0;  // > 0: o poço inteiro fica um pouco mais azul (o da cachoeira)

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float d = length(lpos.xz);
	float ang = atan(lpos.z, lpos.x);
	float n = texture(ruido, vec2(ang * 0.35 + 0.5, d * 0.05 - TIME * 0.04)).r;
	float onda = fract(d * 0.22 - TIME * 0.45 + n * 0.5);
	float linha = smoothstep(0.0, 0.08, onda) * (1.0 - smoothstep(0.12, 0.26, onda));
	linha *= smoothstep(0.25, 0.55, n + 0.15);
	float some = 1.0 - smoothstep(raio * 0.35, raio, d);
	float perto = 1.0 - smoothstep(3.0, 8.0, d);
	float boia = texture(ruido, lpos.xz * 0.16 + vec2(TIME * 0.03, 0.0)).r;
	float espuma = perto * smoothstep(0.4, 0.55, boia);
	float tinta = (1.0 - smoothstep(raio * 0.45, raio * 1.05, d)) * 0.55;
	// o poço inteiro um pouco mais azul, sumindo antes da beira rasa
	float no_poco = poco_raio > 0.0 ? 1.0 - smoothstep(poco_raio * 0.75, poco_raio * 1.2, length(lpos.xz - poco_centro)) : 0.0;
	tinta = max(tinta, no_poco * 0.4);
	float branco = clamp(linha * some * 0.85 + espuma, 0.0, 1.0);
	ALBEDO = mix(azul, cor, branco);
	ALPHA = clamp(tinta + branco * 0.9, 0.0, 1.0);
}
