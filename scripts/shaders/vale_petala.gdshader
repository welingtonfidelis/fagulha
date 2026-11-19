shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// Pétala solta no ar (PetalasAr): a malha e a textura do pacote, girando em torno de um eixo próprio de cada
// pétala enquanto o emissor a leva. Pega a luz do vale e clareia um pouco contra o sol.
uniform sampler2D tex : source_color, filter_linear_mipmap;

void vertex() {
	float id = float(INSTANCE_ID);
	vec3 eixo = normalize(vec3(sin(id * 1.7), 0.6 + 0.4 * cos(id * 2.3), cos(id * 1.1)));
	float ang = TIME * (1.1 + fract(id * 0.37) * 1.6) + id;
	float s = sin(ang);
	float c = cos(ang);
	// giro de Rodrigues em torno do eixo
	VERTEX = VERTEX * c + cross(eixo, VERTEX) * s + eixo * dot(eixo, VERTEX) * (1.0 - c);
	NORMAL = NORMAL * c + cross(eixo, NORMAL) * s + eixo * dot(eixo, NORMAL) * (1.0 - c);
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.4) {
		discard;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = t.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = t.rgb * 0.18;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * clamp(-dot(NORMAL, LIGHT), 0.0, 1.0) * 0.5;
}
