shader_type spatial;
render_mode cull_disabled;

// Touceiras de grama com vento. A cor vem dos vértices (pé escuro, ponta clara) e da instância.
varying float altura_folha;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = VERTEX.y;
	float onda = sin(TIME * 1.6 + w.x * 0.21 + w.z * 0.17) * 0.6 + sin(TIME * 3.3 + w.x * 0.9) * 0.25;
	VERTEX.x += onda * 0.16 * h * h;
	VERTEX.z += onda * 0.08 * h * h;
	altura_folha = h;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
	BACKLIGHT = COLOR.rgb * 0.6;
	AO = mix(0.45, 1.0, clamp(altura_folha * 1.4, 0.0, 1.0));
	AO_LIGHT_AFFECT = 0.5;
}
