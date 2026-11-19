shader_type sky;

// O céu da simulação: não é céu. Um escuro fechado, da cor do chão no horizonte (o chão some nele, sem
// borda), com um brilho fino na linha do horizonte e uma grade de cúpula bem apagada, como uma sala sem
// paredes "dentro da cabeça do robô".
uniform vec3 fundo : source_color = vec3(0.035, 0.07, 0.085);
uniform vec3 alto : source_color = vec3(0.012, 0.028, 0.05);
uniform vec3 linha : source_color = vec3(0.25, 0.9, 0.8);

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 c = mix(fundo, alto, smoothstep(0.0, 0.55, h));
	c += linha * 0.20 * exp(-abs(h) * 34.0);
	// meridianos e paralelos da cúpula, finos e fracos, sumindo perto do horizonte e do zênite
	float lon = atan(d.x, d.z) / (PI / 12.0);
	float lat = asin(clamp(h, -1.0, 1.0)) / (PI / 18.0);
	float gl = smoothstep(0.035, 0.0, abs(fract(lon - 0.5) - 0.5) * cos(asin(clamp(h, -1.0, 1.0))));
	float gp = smoothstep(0.03, 0.0, abs(fract(lat - 0.5) - 0.5));
	float g = max(gl, gp) * smoothstep(0.03, 0.2, h) * (1.0 - smoothstep(0.75, 0.98, h));
	c += linha * g * 0.045;
	if (h < 0.0) {
		c = fundo;
	}
	COLOR = c;
}
