shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// O miolo do jato do gêiser (GeiserFonte, 2026-11-22): um tubo que se abre para cima, com espuma branca que sobe
// depressa e se desfaz nas beiradas e no alto. A malha vai de y = 0 a 1; `altura` estica (metros) e `forca`
// (0 a 1) apaga. As gotas e o vapor em volta são partículas.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float altura = 6.0;
uniform float forca = 1.0;

varying vec3 lpos;
varying float yy;

void vertex() {
	yy = VERTEX.y;
	VERTEX.y *= altura;
	VERTEX.xz *= mix(0.55, 1.0, clamp(altura / 6.0, 0.0, 1.0));
	// balança um pouco, mais no alto
	VERTEX.x += sin(VERTEX.y * 1.7 + TIME * 7.0) * 0.05 * yy;
	VERTEX.z += cos(VERTEX.y * 1.3 + TIME * 6.1) * 0.05 * yy;
	lpos = VERTEX;
}

void fragment() {
	float a = atan(lpos.z, lpos.x) / 6.28318;
	float n = texture(ruido, vec2(a * 2.0 + TIME * 0.03, lpos.y * 0.22 - TIME * 1.9)).r;
	float n2 = texture(ruido, vec2(a * 5.0 + 0.3, lpos.y * 0.6 - TIME * 3.3)).r;
	float espuma = smoothstep(0.3, 0.7, n * 0.55 + n2 * 0.55);
	// as bordas do tubo (de lado para a câmera) ficam mais ralas: dá o volume sem parecer um cano
	float frente = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.8);
	float topo = 1.0 - smoothstep(0.6, 1.0, yy);
	float pe = smoothstep(0.0, 0.06, yy);
	ALBEDO = mix(vec3(0.62, 0.7, 0.74), vec3(0.95, 0.97, 0.98), espuma);
	ROUGHNESS = 0.5;
	SPECULAR = 0.3;
	ALPHA = clamp((0.25 + 0.75 * espuma) * frente * topo * pe * forca, 0.0, 0.92);
}
