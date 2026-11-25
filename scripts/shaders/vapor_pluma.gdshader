shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// A coluna de vapor do gêiser (VaporFonte.pluma, doc §168). As fumaças do Kenney são cinzentas e bem ralas:
// aqui a textura dá só o recorte (o alfa) e a cor é branca, com a densidade que a coluna precisa para se ver
// de longe. Virada para a câmera como as partículas (o mesmo que BILLBOARD_PARTICLES, com o giro de cada uma).

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 cor : source_color = vec3(0.96, 0.97, 0.99);
uniform float densidade = 1.6;

void vertex() {
	mat4 mundo = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mundo = mundo * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mundo;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	ALBEDO = cor * COLOR.rgb;
	ALPHA = clamp(texture(tex, UV).a * COLOR.a * densidade, 0.0, 1.0);
}
