shader_type spatial;
render_mode cull_back;

// Estilo pintado e sério: rocha em camadas (estratos) de ardósia fria, musgo nas saliências,
// capim escuro em cima. Serve para o chão (usa_cor = true: COLOR.r mata, COLOR.g molhado) e para
// as pedras soltas (usa_cor = false), que assim casam com o paredão.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform bool usa_cor = true;
uniform vec3 rocha_escura : source_color = vec3(0.105, 0.115, 0.135);
uniform vec3 rocha_media : source_color = vec3(0.20, 0.205, 0.22);
uniform vec3 rocha_clara : source_color = vec3(0.36, 0.33, 0.30);
uniform vec3 capim_escuro : source_color = vec3(0.055, 0.115, 0.05);
uniform vec3 capim_claro : source_color = vec3(0.16, 0.24, 0.075);
uniform vec3 chao_mata : source_color = vec3(0.075, 0.085, 0.05);
uniform vec3 musgo : source_color = vec3(0.07, 0.14, 0.06);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	float r1 = texture(ruido, wpos.xz * 0.011).r;
	float r2 = texture(ruido, wpos.xz * 0.06 + vec2(wpos.y * 0.013)).r;
	float r3 = texture(ruido, vec2(wpos.x + wpos.z, wpos.y) * 0.035).r;
	// estratos: faixas horizontais onduladas, com larguras variadas
	float s = wpos.y * 0.085 + (r1 - 0.5) * 2.2 + (r3 - 0.5) * 0.5;
	float faixa = fract(s);
	float id = fract(sin(floor(s) * 12.9898) * 43758.5453);
	vec3 rocha = mix(rocha_escura, rocha_media, smoothstep(0.25, 0.75, id));
	rocha = mix(rocha, rocha_clara, smoothstep(0.82, 0.97, id) * 0.8);
	rocha *= 1.0 - 0.45 * smoothstep(0.86, 1.0, faixa);  // sombra da junta entre camadas
	rocha *= 0.86 + 0.28 * r2;  // pincelada
	// trincas verticais
	float trinca = smoothstep(0.71, 0.74, texture(ruido, vec2(wpos.x * 0.09 + wpos.z * 0.07, wpos.y * 0.012)).r);
	rocha *= 1.0 - 0.35 * trinca;
	// chão
	float mata = usa_cor ? COLOR.r : 0.5;
	float molhado = usa_cor ? COLOR.g : 0.0;
	vec3 capim = mix(capim_escuro, capim_claro, smoothstep(0.3, 0.75, r2) * 0.8 + (r1 - 0.5) * 0.3);
	vec3 base = mix(capim, chao_mata, clamp(mata * 0.8 + (r2 - 0.5) * 0.5, 0.0, 1.0));
	float plano = smoothstep(0.62, 0.8, n.y + (r2 - 0.5) * 0.25);
	vec3 cor = mix(rocha, base, plano);
	// musgo escorrendo das saliências e manchas na parede
	float m = smoothstep(0.25, 0.6, n.y) * (1.0 - plano);
	m = max(m, (1.0 - plano) * smoothstep(0.6, 0.78, r1 * 0.6 + r3 * 0.5) * 0.75);
	cor = mix(cor, musgo * (0.8 + 0.5 * r2), m);
	cor *= mix(1.0, 0.55, molhado);
	ALBEDO = cor;
	ROUGHNESS = mix(0.93, 0.3, molhado * 0.8);
	SPECULAR = 0.25;
}
