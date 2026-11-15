shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Flor do platô: o caule é verde fixo; a pétala usa a cor da instância (o MultiMesh a manda em COLOR).
// UV2.x marca a pétala (1) ou o caule (0); UV.y é a altura do vértice (0 na raiz, 1 no topo).
// O balanço do vento segue a mesma fórmula do capim (vale_capim.gdshader), para as flores acompanharem.

varying vec3 raiz;
varying float alt;
varying float rajada;
varying float petala;
varying vec3 cor;

void vertex() {
	raiz = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	alt = clamp(UV.y, 0.0, 1.0);
	petala = UV2.x;
	cor = COLOR.rgb;
	float fase = dot(raiz.xz, vec2(0.085, 0.05)) - TIME * 1.25;
	rajada = smoothstep(0.2, 1.0, sin(fase) * 0.5 + 0.5 + 0.25 * sin(fase * 2.7 + raiz.x * 0.2));
	float bal = (0.06 + 0.22 * rajada) * alt * alt + 0.03 * sin(TIME * 3.1 + raiz.x * 1.7 + raiz.z * 1.3) * alt;
	VERTEX.x += bal;
	VERTEX.z += bal * 0.55;
	VERTEX.y -= bal * bal * 0.5;
	NORMAL = normalize((inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	vec3 verde = vec3(0.13, 0.30, 0.08) * mix(0.80, 1.16, alt);
	vec3 base = mix(verde, cor, petala);
	base += vec3(0.02, 0.025, 0.01) * rajada * alt;  // a rajada clareia a ponta
	ALBEDO = base;
	EMISSION = cor * 0.3 * petala;  // um brilho próprio na pétala, para ela não sumir na sombra
	ROUGHNESS = 0.85;
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
