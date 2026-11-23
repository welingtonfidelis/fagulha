shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Uma poça de lama quente (2026-11-22, ideia do game designer): lama cinza e mole. De tempos em tempos uma
// bolha incha devagar como um domo e estoura, deixando um anel que se desfaz. Malha em disco com bastante
// ponto (FontesQuentes._lama); `raio` é o raio da poça.
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float raio = 2.5;

varying vec3 wpos;
varying float domo;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// a altura da lama num ponto (local, em metros): os domos que incham e o anel do estouro
float lama(vec2 p, float t, out float d_out) {
	float h = 0.0;
	d_out = 0.0;
	vec2 cel = floor(p / 0.9);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cel + vec2(float(i), float(j));
			float per = 3.0 + 4.0 * hash(c);
			float f = fract(t / per + hash(c + 5.1));
			float ativo = step(0.45, hash(c + floor(t / per + hash(c + 5.1)) * 3.3));
			vec2 onde = (c + vec2(0.25 + 0.5 * hash(c + 1.7), 0.25 + 0.5 * hash(c + 8.3))) * 0.9;
			float d = length(p - onde);
			float tam = 0.22 + 0.2 * hash(c + 2.9);
			// incha até 0,7 do ciclo, estoura e o anel abre
			float incha = smoothstep(0.0, 0.7, f) * step(f, 0.7);
			float dm = incha * 0.11 * tam / 0.3 * max(0.0, 1.0 - (d / tam) * (d / tam));
			float aro = step(0.7, f) * (1.0 - smoothstep(0.7, 1.0, f)) * 0.025 * smoothstep(0.06, 0.0, abs(d - tam * (0.6 + (f - 0.7) * 3.0)));
			h += (dm + aro) * ativo;
			d_out = max(d_out, dm * ativo * 9.0);
		}
	}
	return h;
}

void vertex() {
	float borda = 1.0 - smoothstep(raio * 0.7, raio * 0.95, length(VERTEX.xz));
	float d;
	float d2;
	float h0 = lama(VERTEX.xz, TIME, d);
	float hx = lama(VERTEX.xz + vec2(0.035, 0.0), TIME, d2);
	float hz = lama(VERTEX.xz + vec2(0.0, 0.035), TIME, d2);
	VERTEX.y += h0 * borda;
	// a normal pela inclinação da lama (os domos são suaves; a malha só dá a do disco plano)
	NORMAL = normalize(vec3(-(hx - h0) * borda / 0.035, 1.0, -(hz - h0) * borda / 0.035));
	domo = d * borda;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = texture(ruido, wpos.xz * 0.6).r;
	float r2 = texture(ruido, wpos.zx * 1.9 + vec2(0.4, 0.1)).r;
	vec3 c = mix(vec3(0.075, 0.07, 0.062), vec3(0.10, 0.093, 0.08), r);
	// a pele do domo fica mais clara e lisa (esticada)
	c = mix(c, vec3(0.13, 0.12, 0.105), clamp(domo, 0.0, 1.0) * 0.6);
	// na beira, a lama seca e clareia
	float dc = length(wpos.xz - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
	float seca = smoothstep(raio * 0.72, raio * 0.98, dc + (r2 - 0.5) * 0.4);
	c = mix(c, vec3(0.14, 0.13, 0.115), seca);
	ALBEDO = c;
	ROUGHNESS = mix(0.22, 0.85, seca);
	SPECULAR = mix(0.5, 0.1, seca);
}
