shader_type spatial;
render_mode cull_disabled, skip_vertex_transform;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Os pássaros do céu (AvesCeu, 2026-11-22): um MultiMesh por bando e o voo inteiro aqui, sem custo de processador.
// O nó do bando fica no meio dele (o processador só o arrasta devagar); cada pássaro tem no INSTANCE_CUSTOM a fase,
// a velocidade, o raio e a altura das voltas dele, e na origem da instância o seu canto no bando (no V, o lugar
// na fila). O rumo sai do próprio caminho (dois pontos à frente), e o pássaro inclina nas curvas.
// modo 0: andorinhas (voltas rápidas e tortas) / 1: gavião (voltas largas, plana) / 2: gaivotas (voltas com
// deriva) / 3: o bando em V (cada um no seu lugar da fila; o bando inteiro anda no `rumo`)
uniform int modo = 0;
uniform float bate = 8.0;  // batidas por segundo
uniform float amp = 0.7;  // rad
uniform float diedro = 0.08;  // a asa um pouco acima da linha do corpo, planando
uniform float plana = 0.5;  // 0: quase sempre batendo; 1: quase sempre planando
uniform float ombro = 0.01;  // x do ombro, em volta do qual a asa bate
uniform float brilho_borda = 0.25;
instance uniform vec3 rumo = vec3(0.0, 0.0, -1.0);
// o tempo do voo vem de AvesCeu (o mesmo do processador: as fotos sabem onde cada um está; e o TIME volta a zero a cada hora)
global uniform float tempo_bichos;

vec2 girar(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

vec3 caminho(vec4 d, vec3 o, float t) {
	if (modo == 0) {
		float a1 = d.y * (0.55 + 0.18 * sin(d.x * 3.1));
		float a2 = d.y * (0.47 + 0.18 * cos(d.x * 2.3));
		float a3 = d.y * 0.33;
		return o + vec3(d.z * sin(a1 * t + d.x), d.w * sin(a3 * t + d.x * 1.7), d.z * sin(a2 * t + d.x * 2.3 + 1.0));
	} else if (modo == 1) {
		float r = d.z * (1.0 + 0.25 * sin(t * 0.05 + d.x));
		return o + vec3(r * cos(d.y * t + d.x), d.w * sin(t * 0.11 + d.x), r * sin(d.y * t + d.x));
	} else if (modo == 2) {
		return o + vec3(d.z * cos(d.y * t + d.x) + 0.5 * d.z * sin(0.23 * t + d.x * 2.0), d.w * sin(0.31 * t + d.x * 1.3),
			d.z * sin(d.y * t + d.x) + 0.5 * d.z * cos(0.19 * t + d.x * 1.7));
	}
	vec3 f = normalize(rumo);
	vec3 lado = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
	return lado * (o.x + 0.4 * sin(t * 0.37 + d.x * 2.0)) + vec3(0.0, o.y + 0.35 * sin(t * 1.1 + d.x), 0.0) - f * o.z;
}

void vertex() {
	vec4 d = INSTANCE_CUSTOM;
	vec3 o = MODEL_MATRIX[3].xyz - NODE_POSITION_WORLD;
	float esc = length(MODEL_MATRIX[0].xyz);
	float t = tempo_bichos;
	vec3 p0 = caminho(d, o, t);
	vec3 frente;
	float roll = 0.0;
	if (modo == 3) {
		frente = normalize(rumo);
	} else {
		vec3 p1 = caminho(d, o, t + 0.15);
		vec3 p2 = caminho(d, o, t + 0.3);
		vec3 v0 = (p1 - p0) / 0.15;
		vec3 v1 = (p2 - p1) / 0.15;
		vec2 h0 = normalize(v0.xz + vec2(1e-5));
		vec2 h1 = normalize(v1.xz + vec2(1e-5));
		float giro = (h0.x * h1.y - h0.y * h1.x) / 0.15;
		roll = clamp(atan(-length(v0) * giro / 9.8), -1.0, 1.0);
		frente = normalize(v0 + vec3(0.0, 0.0, 1e-5));
		frente.y = clamp(frente.y, -0.45, 0.45);
		frente = normalize(frente);
	}
	vec3 lado = normalize(cross(frente, vec3(0.0, 1.0, 0.0)));
	vec3 cima = cross(lado, frente);
	float cr = cos(roll);
	float sr = sin(roll);
	vec3 lado2 = lado * cr + cima * sr;
	vec3 cima2 = cima * cr - lado * sr;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	if (COLOR.a > 0.0) {
		float rajada = smoothstep(plana - 0.15, plana + 0.15, 0.5 + 0.5 * sin(t * 0.8 + d.x * 4.0));
		float th = (diedro + amp * sin(t * bate * 6.2832 + d.x * 7.0) * rajada) * (1.0 + 0.5 * COLOR.a);
		float s = sign(v.x);
		vec2 q = girar(vec2(abs(v.x) - ombro, v.y), th);
		v.x = s * (ombro + q.x);
		v.y = q.y;
		vec2 qn = girar(vec2(s * n.x, n.y), th);
		n.x = s * qn.x;
		n.y = qn.y;
	}
	vec3 w = NODE_POSITION_WORLD + p0 + esc * (lado2 * v.x + cima2 * v.y - frente * v.z);
	vec3 wn = lado2 * n.x + cima2 * n.y - frente * n.z;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.1;
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * borda * brilho_borda;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
