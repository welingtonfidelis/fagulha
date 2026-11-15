shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

// Fita da cachoeira: espuma descendo rápido, bordas soltas. UV.x atravessa, UV.y desce (0 no topo).
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float velocidade = 1.4;

void fragment() {
	vec2 uv = UV;
	float n1 = texture(ruido, vec2(uv.x * 1.6, uv.y * 2.2 - TIME * velocidade)).r;
	float n2 = texture(ruido, vec2(uv.x * 4.0 + 0.37, uv.y * 6.0 - TIME * velocidade * 1.9)).r;
	float n3 = texture(ruido, vec2(uv.x * 9.0 + 0.11, uv.y * 14.0 - TIME * velocidade * 3.1)).r;
	float espuma = smoothstep(0.32, 0.78, n1 * 0.55 + n2 * 0.35 + n3 * 0.25);
	float borda = smoothstep(0.0, 0.22, uv.x + (n2 - 0.5) * 0.15) * smoothstep(1.0, 0.78, uv.x + (n1 - 0.5) * 0.15);
	float topo = smoothstep(0.0, 0.025, uv.y);
	ALBEDO = mix(vec3(0.42, 0.55, 0.58), vec3(0.93, 0.96, 0.98), espuma);
	ALPHA = clamp(borda * topo * (0.35 + 0.65 * espuma) * (0.75 + 0.25 * uv.y), 0.0, 1.0);
	ROUGHNESS = 0.35;
	EMISSION = ALBEDO * 0.08;
}
