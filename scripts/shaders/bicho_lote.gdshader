shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Bichos em lote (MultiMesh) feitos por FormasBicho (2026-11-22): a cor vem do vértice; o alfa do vértice diz o
// quanto a peça mexe. Na luz em faixas do vale, com a borda clara contra a luz, como vale_solido.
// modo 0: peixe raso (a cauda balança; INSTANCE_CUSTOM: fase, batidas por segundo, amplitude em metros)
// modo 1: bicho de terra visto de longe (o pescoço e a cabeça descem para pastar e sobem para olhar; fase em x)
// modo 2: borboleta (as asas batem largo; a tinta da asa no rgb do INSTANCE_CUSTOM, a fase no a)
// modo 3: libélula (as asas vibram curto; a tinta do corpo no rgb, a fase no a)
uniform int modo = 0;
uniform vec3 pescoco = vec3(0.0);  // modo 1: em volta de que ponto a cabeça gira
uniform float pasto = 1.0;  // modo 1: quanto a cabeça desce (negativo: sobe, como a foca que olha)
uniform float longe = 1600.0;  // modo 1: além disso (da câmera) o bicho some, que nem um ponto cintilando ele vira
uniform float brilho_borda = 0.3;

varying vec3 tinta;
varying float viva;  // asa de borboleta: brilha um pouco para a cor aparecer no meio do capim

vec2 girar(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void vertex() {
	vec4 d = INSTANCE_CUSTOM;
	float a = COLOR.a;
	tinta = vec3(1.0);
	viva = 0.0;
	if (modo == 0) {
		VERTEX.x += sin(TIME * d.y * 6.2832 + d.x - VERTEX.z * 7.0) * d.z * a * a;
	} else if (modo == 1) {
		if (distance(MODEL_MATRIX[3].xyz, CAMERA_POSITION_WORLD) > longe) {
			VERTEX = vec3(0.0);
		} else if (a > 0.0) {
			float ciclo = sin(TIME * 0.21 + d.x * 6.2832) + 0.35 * sin(TIME * 0.53 + d.x * 3.0);
			float g = -smoothstep(-0.2, 0.5, ciclo) * pasto * a;
			vec2 q = girar(vec2(VERTEX.y - pescoco.y, VERTEX.z - pescoco.z), g);
			VERTEX.y = pescoco.y + q.x;
			VERTEX.z = pescoco.z + q.y;
			vec2 qn = girar(NORMAL.yz, g);
			NORMAL.yz = qn;
		}
	} else {
		if (a > 0.0) {
			float ang = modo == 2 ? 0.3 + 0.95 * sin(TIME * 11.0 + d.a * 6.2832) : 0.06 + 0.32 * sin(TIME * 38.0 + d.a * 6.2832);
			float s = sign(VERTEX.x);
			vec2 p = girar(vec2(abs(VERTEX.x), VERTEX.y), ang);
			VERTEX.x = s * p.x;
			VERTEX.y = p.y;
			vec2 n = girar(vec2(NORMAL.x * s, NORMAL.y), ang);
			NORMAL.x = s * n.x;
			NORMAL.y = n.y;
		}
		if ((modo == 2) == (a > 0.0)) {
			tinta = d.rgb;
			viva = modo == 2 ? 1.0 : 0.0;
		}
	}
}

void fragment() {
	vec3 c = COLOR.rgb * tinta;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * (borda * brilho_borda + viva * 0.3);
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
