shader_type spatial;
render_mode cull_disabled;

// Plantas de folha larga e flores de destaque, no estilo pintado e sério. A cor vem dos vértices.
// Na flor, a ponta é marcada com alfa 0 nos vértices e recebe a cor pela instância (INSTANCE_CUSTOM.r:
// 0 laranja queimado, 1 violeta apagado). Balança devagar com o vento, mais na ponta.

uniform vec3 laranja : source_color = vec3(0.55, 0.26, 0.11);
uniform vec3 violeta : source_color = vec3(0.34, 0.25, 0.38);

varying vec3 cor_vertice;
varying float e_ponta;
varying float tom_flor;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = VERTEX.y;
	float onda = sin(TIME * 1.1 + w.x * 0.19 + w.z * 0.15) * 0.6 + sin(TIME * 2.7 + w.x * 0.7) * 0.2;
	VERTEX.x += onda * 0.09 * h * h;
	VERTEX.z += onda * 0.05 * h * h;
	cor_vertice = COLOR.rgb;
	e_ponta = 1.0 - step(0.5, COLOR.a);
	tom_flor = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec3 cor = cor_vertice;
	if (e_ponta > 0.5) {
		cor = mix(laranja, violeta, tom_flor);
	}
	ALBEDO = cor;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	BACKLIGHT = cor * 0.35;
}
