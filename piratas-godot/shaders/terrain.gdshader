shader_type spatial;
render_mode diffuse_burley;
// Terreno com texturas reais (CC0 da ambientCG e da demo do Godot): capim, areia e rocha.
// Areia perto da água, rocha nas encostas (projeção lateral), capim no resto; a cor do vértice dá a variação regional.

uniform sampler2D grama_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grama_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D areia_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D areia_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocha_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rocha_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnorm);
	float slope = 1.0 - clamp(n.y, 0.0, 1.0);
	float big = vnoise(wpos.xz * 0.02) * 0.6 + vnoise(wpos.xz * 0.006) * 0.4;
	// duas escalas da mesma textura para esconder a repetição
	vec2 uv_g = wpos.xz / 7.0;
	vec3 grass = mix(texture(grama_cor, uv_g).rgb, texture(grama_cor, wpos.xz / 29.0 + 0.37).rgb, 0.35);
	vec3 gn = texture(grama_normal, uv_g).rgb * 2.0 - 1.0;
	vec2 uv_s = wpos.xz / 5.0;
	vec3 sand = texture(areia_cor, uv_s).rgb * vec3(1.05, 1.0, 0.92);
	vec3 sn = texture(areia_normal, uv_s).rgb * 2.0 - 1.0;
	// rocha com projeção nos dois planos verticais
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 rock = texture(rocha_cor, wpos.zy / 9.0).rgb * bw.x + texture(rocha_cor, wpos.xz / 9.0).rgb * bw.y + texture(rocha_cor, wpos.xy / 9.0).rgb * bw.z;
	vec3 rn = texture(rocha_normal, wpos.xy / 9.0).rgb * 2.0 - 1.0;
	// pesos
	float edge = vnoise(wpos.xz * 0.15) * 0.8;
	float w_sand = 1.0 - smoothstep(2.0, 3.4, wpos.y + edge);
	float w_rock = smoothstep(0.32, 0.55, slope + big * 0.08);
	float w_grass = (1.0 - w_sand) * (1.0 - w_rock);
	w_sand *= (1.0 - w_rock);
	// tom regional: mata mais escura, campos mais secos (cor do vértice)
	vec3 tint = clamp(COLOR.rgb / max(dot(COLOR.rgb, vec3(0.333)), 0.05), 0.6, 1.5);
	// capim tropical: a textura original é de grama seca
	grass *= vec3(0.62, 0.86, 0.5) * mix(vec3(1.0), tint, 0.35) * (0.8 + 0.35 * big);
	vec3 c = grass * w_grass + sand * w_sand + rock * w_rock;
	// areia molhada e espuma
	float wet = 1.0 - smoothstep(0.2, 1.4, wpos.y);
	c *= mix(1.0, 0.68, wet * step(-2.0, wpos.y));
	float foam_line = 1.0 - smoothstep(0.0, 0.55, abs(wpos.y - 0.15 - 0.25 * sin(TIME * 1.3 + wpos.x * 0.05 + wpos.z * 0.04)));
	float foam_n = vnoise(wpos.xz * 1.3 + vec2(TIME * 0.4, 0.0));
	c = mix(c, vec3(0.92, 0.95, 0.95), foam_line * smoothstep(0.35, 0.7, foam_n) * 0.85);
	ALBEDO = c;
	// relevo fino das texturas (aproximação no espaço do mundo)
	vec3 dn = gn * w_grass + sn * w_sand + rn * w_rock;
	vec3 nw = normalize(n + vec3(dn.x, 0.0, -dn.y) * 0.6);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = mix(0.95, 0.35, wet);
	SPECULAR = 0.2;
}
