shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"
#include "res://scripts/shaders/terra_nova_cor.gdshaderinc"

// A Boca do Degelo (BocaDegelo). A cor do vértice diz onde a peça está: r = perto do chão de fora (ali a pele
// refaz a encosta e tem a mesma cor do chão da terra nova), g = fundura. Na beira da boca ainda é pedra; dali
// para dentro é gelo: azul fundo, cheio de covinhas (as "conchas" que o degelo cava, de borda clara), com faixas
// finas de poeira dos invernos e o piso de geada e seixos. A luz do dia atravessa o gelo (`dia`, do Ciclo): forte
// perto da boca, mais fraca no fundo, quase nada de noite (aí quem acende são os cristais).
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform sampler2D cobertura : filter_nearest;
uniform vec2 origem = vec2(-3900.0, -3900.0);
uniform float passo = 4.0;
uniform ivec2 tamanho = ivec2(1151, 1101);
uniform vec2 base_xz = vec2(0.0);  // a nascente
uniform vec2 rumo = vec2(0.0, -1.0);  // da nascente para dentro da montanha
uniform float dia = 1.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 tinta;
varying vec4 extra;
varying float pedra_f;
varying vec3 fonte;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ivec2 c = ivec2(round((wpos.xz - origem) / passo));
	vec4 ti;
	vec4 ex;
	float pf;
	vec3 fo;
	tn_cobertura(cobertura, tamanho, c, wpos.y, ti, ex, pf, fo);
	tinta = ti;
	extra = ex;
	pedra_f = pf;
	fonte = fo;
}

vec3 _h3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// As covinhas: x = distância ao meio da mais perto, y = à segunda (as bordas são onde as duas empatam).
vec2 conchas(vec3 p, out vec3 meio) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	meio = i;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = _h3(i + g);
				vec3 r = g + o - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					meio = i + g + o;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(sqrt(d1), sqrt(d2));
}

// O ruído nas três direções (as paredes ficavam borradas, esticadas numa direção só).
float tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(ruido, p.yz).r * w.x + texture(ruido, p.xz).r * w.y + texture(ruido, p.xy).r * w.z;
}

void fragment() {
	float a = dot(wpos.xz - base_xz, rumo);  // quanto já entrou na montanha
	float r = tri(wpos * 0.05, wnrm);
	// a beira da boca é pedra (a cor da encosta); o gelo começa uns metros para dentro, de borda torta
	float pedra = max(COLOR.r, 1.0 - smoothstep(3.0, 9.0, a + (r - 0.5) * 7.0));
	vec3 face = normalize(cross(dFdy(wpos), dFdx(wpos)));
	face *= sign(face.y + 1e-4);
	float neve = 0.0;
	vec3 chao = pedra > 0.001 ? tn_cor(ruido, wpos, wnrm, face, tinta, extra, pedra_f, fonte, CAMERA_POSITION_WORLD, TIME, neve) : vec3(0.0);
	float piso = smoothstep(0.55, 0.85, wnrm.y);
	// as covinhas, de uns 1,2 m e tortas (a grade delas é entortada pelo ruído, senão vira mosaico); de longe
	// elas somem (senão piscam)
	const float ESC = 0.8;
	vec3 torto = vec3(tri(wpos * 0.07, wnrm), tri(wpos * 0.07 + 3.1, wnrm), tri(wpos * 0.07 + 6.3, wnrm)) - 0.5;
	vec3 q = wpos * ESC + torto * 1.4;
	vec3 meio;
	vec2 f = conchas(q, meio);
	float perto = 1.0 - smoothstep(0.3, 0.8, length(fwidth(q)));
	float borda = (1.0 - smoothstep(0.03, 0.3, f.y - f.x)) * perto;
	float covo = smoothstep(0.05, 0.8, f.x);  // 0 no fundo da covinha, 1 perto da borda
	// a normal da covinha pende para o meio dela (o fundo fica na sombra, a borda pega a luz)
	vec3 para_meio = (meio - q) / ESC;
	vec3 tang = para_meio - wnrm * dot(para_meio, wnrm);
	float relevo = perto * (1.0 - piso) * (1.0 - pedra);
	vec3 n = normalize(wnrm + tang * 0.8 * relevo);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// as cores do gelo: o fundo das covinhas é safira, a volta é azul-claro e a borda quase branca
	float camada = 0.5 + 0.5 * sin(wpos.y * 1.1 + tri(wpos * 0.018, wnrm) * 9.0);
	vec3 gelo = mix(vec3(0.04, 0.17, 0.38), vec3(0.11, 0.38, 0.62), (0.3 + 0.45 * covo) * (0.7 + 0.3 * camada));
	gelo = mix(gelo, vec3(0.03, 0.10, 0.24), smoothstep(0.55, 0.8, tri(wpos * 0.03 + 7.0, wnrm)) * 0.5);
	gelo = mix(gelo, vec3(0.55, 0.80, 0.92), borda * 0.2);
	// faixas finas de poeira, uma por inverno, quase deitadas
	float faixa = smoothstep(0.94, 0.99, 0.5 + 0.5 * sin(wpos.y * 0.85 + tri(wpos * 0.012, wnrm) * 2.5));
	gelo = mix(gelo, vec3(0.14, 0.17, 0.21), faixa * 0.45 * (1.0 - piso));
	// o piso: geada com seixos escuros
	vec3 geada = mix(vec3(0.44, 0.54, 0.63), vec3(0.62, 0.71, 0.79), tri(wpos * 0.3, wnrm));
	geada = mix(geada, vec3(0.20, 0.22, 0.26), smoothstep(0.58, 0.72, tri(wpos * 0.21, wnrm)) * 0.7);
	gelo = mix(gelo, geada, piso * 0.9);
	float g = 1.0 - pedra;
	ALBEDO = mix(chao, gelo, g);
	ROUGHNESS = mix(mix(0.95, 0.7, neve), mix(0.12 + 0.2 * (1.0 - borda), 0.65, piso), g);
	SPECULAR = mix(mix(0.1, 0.25, neve), 0.6, g);
	// a luz que atravessa o gelo: forte perto da boca, mais fraca no fundo; nas bordas e nas camadas claras
	// mais, no piso quase nada
	float passa = mix(0.85, 0.38, smoothstep(8.0, 70.0, a)) * (0.14 + 0.86 * smoothstep(0.3, 0.95, dia));
	vec3 brilho = vec3(0.05, 0.25, 0.52) * (0.6 + 0.4 * covo) + vec3(0.25, 0.45, 0.55) * borda * 0.3;
	EMISSION = brilho * (0.6 + 0.4 * camada) * (1.0 - faixa * 0.7) * (1.0 - piso * 0.75) * passa * g * smoothstep(0.08, 0.25, COLOR.g);
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
