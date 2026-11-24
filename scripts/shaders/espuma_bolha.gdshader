shader_type spatial;
render_mode unshaded, cull_back;

// As bolhas de espuma da cachoeira nova: cada uma cresce, sobe um pouco e murcha, sem parar, cada qual no seu
// tempo (INSTANCE_CUSTOM.x a fase, .y a pressa). Branco em cima, azul-claro embaixo, como nuvenzinhas.
uniform vec3 branco : source_color = vec3(0.97, 0.99, 1.0);
uniform vec3 sombra : source_color = vec3(0.70, 0.84, 0.93);

varying float luz;

void vertex() {
	float ciclo = fract(TIME * (0.55 + INSTANCE_CUSTOM.y * 0.5) + INSTANCE_CUSTOM.x);
	float s = 0.35 + 0.75 * sin(ciclo * 3.14159);
	VERTEX *= s;
	VERTEX.y += ciclo * 0.7;
	luz = dot(NORMAL, normalize(vec3(0.3, 1.0, 0.2)));
}

void fragment() {
	ALBEDO = mix(sombra, branco, smoothstep(-0.15, 0.45, luz));
}
