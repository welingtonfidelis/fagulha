shader_type spatial;
render_mode cull_disabled;

// Copas pintadas: escuro azulado embaixo, verde-oliva em cima, manchas de pincel e a borda acesa
// contra a luz. Balança devagar com o vento.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec3 sombra : source_color = vec3(0.022, 0.06, 0.05);
uniform vec3 meio : source_color = vec3(0.06, 0.15, 0.055);
uniform vec3 luz : source_color = vec3(0.22, 0.30, 0.085);
uniform float vento = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float onda = sin(TIME * 0.9 + w.x * 0.07 + w.z * 0.05) + 0.5 * sin(TIME * 2.1 + w.x * 0.31 + w.y * 0.2);
	float alto = clamp(VERTEX.y * 0.06, 0.0, 1.0);
	VERTEX.x += onda * 0.12 * vento * alto;
	VERTEX.z += onda * 0.07 * vento * alto;
	wpos = w;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	float r = texture(ruido, wpos.xz * 0.045 + vec2(wpos.y * 0.05)).r;
	float r2 = texture(ruido, wpos.xz * 0.19 + vec2(wpos.y * 0.21)).r;
	float t = clamp(n.y * 0.5 + 0.5 + (r - 0.5) * 0.5, 0.0, 1.0);
	vec3 cor = mix(sombra, meio, smoothstep(0.15, 0.55, t));
	cor = mix(cor, luz, smoothstep(0.62, 0.95, t) * (0.6 + 0.4 * r2));
	cor *= 0.85 + 0.3 * smoothstep(0.4, 0.6, r2);  // tufos
	// manchas largas da mata: umas áreas puxam para o oliva, outras para o azul-petróleo
	float larga = texture(ruido, wpos.xz * 0.0014).r;
	float larga2 = texture(ruido, wpos.zx * 0.0031 + vec2(0.37)).r;
	cor = mix(cor, cor * vec3(1.35, 1.12, 0.55), smoothstep(0.55, 0.8, larga) * 0.6);
	cor = mix(cor, cor * vec3(0.55, 0.95, 1.15), smoothstep(0.58, 0.82, larga2) * 0.6);
	ALBEDO = cor;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = luz * 0.5;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
