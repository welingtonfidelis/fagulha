shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Chão do vale: a cor do capim (a mesma das folhas de capim), trilha de terra (COLOR.r),
// margem molhada (COLOR.g), areia (COLOR.b) e pedra nas encostas.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
// O recorte de dentro do cilindro de melhorias (rascunho, doc §138): o terreno que sobe dentro do tubo some.
// `recorte_para_local` leva do mundo ao lugar do tubo (X no eixo); `recorte_meio` é (meio comprimento, raio).
uniform float recorte_ativo = 0.0;
uniform mat4 recorte_para_local;
uniform vec2 recorte_meio = vec2(0.0);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (recorte_ativo > 0.5) {
		vec3 l = (recorte_para_local * vec4(wpos, 1.0)).xyz;
		if (abs(l.x) < recorte_meio.x && length(l.yz) < recorte_meio.y) {
			discard;
		}
	}
	float r = texture(ruido, wpos.xz * 0.08).r;
	vec3 c = cor_capim(ruido, wpos.xz) * 0.92;
	// longe da câmera, onde as touceiras já não existem, o chão é pintado como capim
	float longe = smoothstep(38.0, 84.0, distance(wpos, CAMERA_POSITION_WORLD));
	if (longe > 0.001) {
		c = mix(c, capim_de_longe(ruido, wpos.xz, TIME), longe);
	}
	vec3 terra = mix(vec3(0.20, 0.145, 0.09), vec3(0.27, 0.21, 0.13), r);
	c = mix(c, terra, smoothstep(0.35, 0.6, COLOR.r + (r - 0.5) * 0.3));
	c = mix(c, vec3(0.20, 0.17, 0.12), COLOR.g * 0.8);
	// areia da praia (COLOR.b), mais clara e seca longe da água
	vec3 areia = mix(vec3(0.29, 0.24, 0.145), vec3(0.36, 0.30, 0.19), r);
	c = mix(c, areia, smoothstep(0.3, 0.75, COLOR.b + (r - 0.5) * 0.25));
	// campo florido (1 - COLOR.a): manchas de cor no chão, para o platô aparecer de longe e do alto
	float flor = 1.0 - COLOR.a;
	if (flor > 0.01) {
		float p1 = texture(ruido, wpos.xz * 0.22).r;
		float p2 = texture(ruido, wpos.zx * 0.31 + vec2(0.31, 0.17)).r;
		float mancha = texture(ruido, wpos.xz * 0.012).r;
		vec3 cf = mancha < 0.42 ? vec3(0.80, 0.08, 0.22) : (mancha < 0.52 ? vec3(0.92, 0.55, 0.02) : (mancha < 0.62 ? vec3(0.28, 0.11, 0.78) : vec3(0.90, 0.88, 0.74)));
		vec3 cf2 = mancha > 0.5 ? vec3(0.92, 0.55, 0.02) : vec3(0.90, 0.88, 0.74);
		c = mix(c, cf, smoothstep(0.55, 0.62, p1) * flor * 0.85);
		c = mix(c, cf2, smoothstep(0.60, 0.66, p2) * flor * 0.75);
	}
	vec3 pedra = cor_rocha(ruido, wpos, wnrm);
	// tufos de mato nos degraus: a pedra não começa numa linha reta
	float borda = wnrm.y + (r - 0.5) * 0.22 + (texture(ruido, wpos.xz * 0.31).r - 0.5) * 0.12;
	c = mix(c, pedra, smoothstep(0.80, 0.68, borda));
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.4, COLOR.g);
	SPECULAR = 0.1;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
