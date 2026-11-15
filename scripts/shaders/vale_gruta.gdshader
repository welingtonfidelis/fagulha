shader_type spatial;
render_mode cull_back;
#include "res://scripts/shaders/vale_comum.gdshaderinc"

// A rocha do Sumidouro. A cor do vértice diz onde a peça está: r = perto do chão de fora (ali é capim,
// como o terreno em volta), g = fundura (lá dentro a luz do céu não chega, sobram os cristais e o poço).
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float fundo_fixo = -1.0;  // estalactites e pedras soltas: fundura fixa, sem cor de vértice

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float capim = fundo_fixo >= 0.0 ? 0.0 : COLOR.r;
	float fundo = fundo_fixo >= 0.0 ? fundo_fixo : COLOR.g;
	float r = texture(ruido, wpos.xz * 0.05).r;
	vec3 pedra = cor_rocha(ruido, wpos, wnrm);
	// lá dentro a pedra é mais escura e úmida, com veios mais claros
	float veio = smoothstep(0.55, 0.75, texture(ruido, wpos.xy * 0.03 + wpos.z * 0.02).r);
	vec3 dentro = pedra * mix(vec3(0.62, 0.66, 0.74), vec3(0.85, 0.9, 0.95), veio);
	pedra = mix(pedra, dentro, fundo);
	float grama = capim * smoothstep(0.62, 0.74, wnrm.y + (r - 0.5) * 0.12);
	ALBEDO = mix(pedra, cor_capim(ruido, wpos.xz), grama);
	ROUGHNESS = mix(0.95, 0.7, fundo);
	SPECULAR = 0.1;
	AO = mix(1.0, 0.12, fundo);
	AO_LIGHT_AFFECT = 0.0;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
