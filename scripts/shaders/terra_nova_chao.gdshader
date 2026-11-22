shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"
#include "res://scripts/shaders/terra_nova_cor.gdshaderinc"

// Chão da terra nova (TerraNova): o mesmo chão do vale (vale_chao), mas o relevo vem de uma textura de alturas
// e cada bloco é uma grade plana que o vértice levanta. Assim os blocos de perto e de longe (com menos pontos)
// usam a mesma malha, e a borda de cada bloco desce numa saia que esconde as frestas entre níveis.
// A cobertura vem de outra textura: r = o código (0 campo, 1 mata, 2 mata fechada, 3 flores, 4 areia, 5 neve,
// 6 pedra, 7 campina alpina, 8 cascalho, 9 duna, 10 sínter, 11 esteira laranja, 12 brejo), g = quanto o lugar é
// boreal (os pés da montanha).
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform sampler2D alturas : filter_nearest;
uniform sampler2D alturas_longe : filter_nearest;  // nos blocos de longe: a beira dos rios mais funda, para a água aparecer
uniform sampler2D cobertura : filter_nearest;
uniform vec2 origem = vec2(-3900.0, -3900.0);
uniform float passo = 4.0;
uniform ivec2 tamanho = ivec2(1151, 1101);
uniform float saia = 10.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 tinta;  // como o COLOR do vale_chao: r terra, g margem, b areia, a 1 - flores
varying vec4 extra;  // r neve, g boreal, b cascalho, a campina alpina
varying float pedra_f;
varying vec3 fonte;  // as fontes quentes: r sínter (mineral branco), g esteira laranja, b brejo

float alt(ivec2 c) {
	return texelFetch(alturas, clamp(c, ivec2(0), tamanho - ivec2(1)), 0).r;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ivec2 c = ivec2(round((w.xz - origem) / passo));
	// UV2.x marca a saia; UV2.y é quantas células cada quadrado do bloco pula (1 perto, 2 a 10 longe)
	float h = UV2.y > 1.5 ? texelFetch(alturas_longe, clamp(c, ivec2(0), tamanho - ivec2(1)), 0).r : alt(c);
	// o fundo do mar daqui fica um pouco abaixo do fundo do Vale (-14,05), para os dois não piscarem juntos
	VERTEX.y = h - UV2.x * saia - 0.5 * smoothstep(-12.5, -14.0, h);
	NORMAL = normalize(vec3(alt(c - ivec2(1, 0)) - alt(c + ivec2(1, 0)), 2.0 * passo, alt(c - ivec2(0, 1)) - alt(c + ivec2(0, 1))));
	wpos = vec3(w.x, VERTEX.y, w.z);
	wnrm = NORMAL;
	// a cobertura é a média dos 9 pontos em volta: as bordas (neve, pedra, cascalho) saem suaves, sem degraus
	vec4 ti;
	vec4 ex;
	float pf;
	vec3 fo;
	tn_cobertura(cobertura, tamanho, c, h, ti, ex, pf, fo);
	tinta = ti;
	extra = ex;
	pedra_f = pf;
	fonte = fo;
}

void fragment() {
	vec3 face = normalize(cross(dFdy(wpos), dFdx(wpos)));
	face *= sign(face.y + 1e-4);
	float neve;
	vec3 c = tn_cor(ruido, wpos, wnrm, face, tinta, extra, pedra_f, fonte, CAMERA_POSITION_WORLD, TIME, neve);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.7, neve);
	SPECULAR = mix(0.1, 0.25, neve);
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
