shader_type spatial;
render_mode cull_back;

// Teste visual: rocha em projeção triplanar nas paredes e grama/chão de mata no plano,
// misturados pela inclinação. COLOR.r = chão de mata, COLOR.g = molhado (perto do rio e da cachoeira).
uniform sampler2D rocha_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocha_nrm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocha_rug : filter_linear_mipmap, repeat_enable;
uniform sampler2D grama_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grama_nrm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grama_rug : filter_linear_mipmap, repeat_enable;
uniform sampler2D chao_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D chao_nrm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D chao_rug : filter_linear_mipmap, repeat_enable;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform float escala_rocha = 0.055;
uniform float escala_rocha2 = 0.011;
uniform float escala_chao = 0.2;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_cor(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy).rgb * w.x + texture(t, p.xz).rgb * w.y + texture(t, p.xy).rgb * w.z;
}

// normal triplanar com mistura "whiteout"; devolve a normal no mundo
vec3 tri_nrm(sampler2D t, vec3 p, vec3 n, vec3 w) {
	vec3 tx = texture(t, p.zy).rgb * 2.0 - 1.0;
	vec3 ty = texture(t, p.xz).rgb * 2.0 - 1.0;
	vec3 tz = texture(t, p.xy).rgb * 2.0 - 1.0;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

vec3 plano_nrm(sampler2D t, vec2 uv, vec3 n) {
	vec3 ty = texture(t, uv).rgb * 2.0 - 1.0;
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	return normalize(ty.xzy);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	// rocha em duas escalas (quebra a repetição de longe)
	vec3 pr = wpos * escala_rocha;
	vec3 rc = tri_cor(rocha_cor, pr, w) * mix(vec3(1.0), tri_cor(rocha_cor, wpos * escala_rocha2, w) * 1.3, 0.2);
	// a rocha do Poly Haven é avermelhada: puxa para cinza esverdeado, como as pedras
	rc = mix(rc, vec3(dot(rc, vec3(0.3, 0.59, 0.11))), 0.6) * vec3(0.92, 0.98, 0.9);
	vec3 rn = tri_nrm(rocha_nrm, pr, n, w);
	float rr = texture(rocha_rug, pr.zy).r * w.x + texture(rocha_rug, pr.xz).r * w.y + texture(rocha_rug, pr.xy).r * w.z;
	// chão
	vec2 pc = wpos.xz * escala_chao;
	float rq = texture(ruido, wpos.xz * 0.013).r;
	float rq2 = texture(ruido, wpos.xz * 0.07).r;
	vec3 gc = texture(grama_cor, pc).rgb;
	vec3 cc = texture(chao_cor, pc * 1.4).rgb;
	vec3 gn = plano_nrm(grama_nrm, pc, n);
	vec3 cn = plano_nrm(chao_nrm, pc * 1.4, n);
	float gr = texture(grama_rug, pc).r;
	float cr = texture(chao_rug, pc * 1.4).r;
	float mata = clamp(COLOR.r + (rq2 - 0.5) * 0.6, 0.0, 1.0);
	vec3 base_cor = mix(gc * vec3(0.62, 0.95, 0.5), cc * vec3(0.85, 0.95, 0.75), mata);
	vec3 base_n = normalize(mix(gn, cn, mata));
	float base_r = mix(gr, cr, mata);
	// inclinação decide rocha ou chão; musgo sobe um pouco nas saliências
	float plano = smoothstep(0.66, 0.82, n.y + (rq - 0.5) * 0.22);
	vec3 cor = mix(rc, base_cor, plano);
	float musgo = smoothstep(0.35, 0.65, n.y) * (1.0 - plano) * smoothstep(0.45, 0.7, rq2);
	musgo = max(musgo, (1.0 - plano) * smoothstep(0.55, 0.8, texture(ruido, wpos.xz * 0.03 + vec2(wpos.y * 0.02)).r) * 0.7);
	cor = mix(cor, gc * vec3(0.55, 0.75, 0.45), musgo * 0.65);
	// molhado: escurece e brilha
	float molhado = COLOR.g;
	cor *= mix(1.0, 0.62, molhado);
	cor *= 0.88 + 0.24 * rq;
	ALBEDO = cor;
	vec3 nw = normalize(mix(rn, base_n, plano));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = mix(mix(rr, base_r, plano), 0.25, molhado * 0.8);
	SPECULAR = 0.4;
}
