shader_type spatial;
render_mode unshaded;

// O chão da simulação: uma grade de luz sobre o escuro, sem fim. As linhas saem da posição no mundo (a malha
// acompanha o robô), com uma linha mais forte a cada dez, e apagam com a distância.
uniform vec3 fundo : source_color = vec3(0.035, 0.07, 0.085);
uniform vec3 linha : source_color = vec3(0.25, 0.9, 0.8);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grade(vec2 p, float passo, float grossura) {
	vec2 g = abs(fract(p / passo - 0.5) - 0.5) / fwidth(p / passo);
	return 1.0 - clamp(min(g.x, g.y) - grossura, 0.0, 1.0);
}

void fragment() {
	float d = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	float fina = grade(wpos.xz, 4.0, 0.0) * (1.0 - smoothstep(60.0, 220.0, d));
	float grossa = grade(wpos.xz, 40.0, 0.6) * (1.0 - smoothstep(400.0, 1400.0, d));
	float l = max(fina * 0.45, grossa);
	ALBEDO = mix(fundo, linha, l);
}
