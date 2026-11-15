shader_type spatial;
render_mode cull_back;

// Cor por vértice (bioma) com uma variação de ruído em duas escalas.
uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n1 = texture(ruido, wpos.xz * 0.012).r;
	float n2 = texture(ruido, wpos.xz * 0.09).r;
	float n3 = texture(ruido, wpos.xz * 0.6).r;
	float v = 0.80 + 0.25 * n1 + 0.15 * n2 + 0.08 * n3;
	ALBEDO = COLOR.rgb * v;
	ROUGHNESS = 0.95;
	SPECULAR = 0.3;
}
