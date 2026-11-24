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
	vec3 pedra = cor_rocha(ruido, wpos, wnrm);
	// lá dentro a pedra é mais escura e úmida, com veios mais claros
	float veio = smoothstep(0.55, 0.75, texture(ruido, wpos.xy * 0.03 + wpos.z * 0.02).r);
	vec3 dentro = pedra * mix(vec3(0.62, 0.66, 0.74), vec3(0.85, 0.9, 0.95), veio);
	pedra = mix(pedra, dentro, fundo);
	// o capim do alto com a mesma conta do chão do vale (vale_chao): o tom, o capim pintado de longe e a pedra
	// na mesma inclinação. Com outra regra, o alto da peça aparecia em manchas claras no meio do capim (doc §163)
	vec3 mato = cor_capim(ruido, wpos.xz) * 0.92;
	float longe = smoothstep(38.0, 84.0, distance(wpos, CAMERA_POSITION_WORLD));
	if (longe > 0.001) {
		mato = mix(mato, capim_de_longe(ruido, wpos.xz, TIME), longe);
	}
	float rc = texture(ruido, wpos.xz * 0.08).r;
	float borda = wnrm.y + (rc - 0.5) * 0.22 + (texture(ruido, wpos.xz * 0.31).r - 0.5) * 0.12;
	float grama = capim * (1.0 - smoothstep(0.80, 0.68, borda));
	ALBEDO = mix(pedra, mato, grama);
	ROUGHNESS = mix(0.95, 0.7, fundo);
	SPECULAR = 0.1;
	AO = mix(1.0, 0.12, fundo);
	AO_LIGHT_AFFECT = 0.0;
}

void light() {
	DIFFUSE_LIGHT += luz_faixas(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION);
}
