shader_type spatial;
render_mode diffuse_burley;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float macro = fbm(wpos.xz * 0.012);
	float mid = fbm(wpos.xz * 0.09);
	float fine = vnoise(wpos.xz * 1.7) * 0.6 + vnoise(wpos.xz * 4.3) * 0.4;
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	// variação de grande escala (manchas de capim seco e verde escuro)
	vec3 c = base * (0.78 + 0.45 * macro);
	vec3 dry = vec3(0.42, 0.38, 0.17);
	float is_grass = smoothstep(2.6, 4.0, wpos.y) * (1.0 - smoothstep(0.25, 0.5, slope));
	c = mix(c, c * 0.55 + dry * 0.45, is_grass * smoothstep(0.55, 0.8, mid) * 0.7);
	// trilhas de terra
	float dirt = smoothstep(0.66, 0.74, fbm(wpos.xz * 0.035 + 7.0)) * is_grass;
	c = mix(c, vec3(0.36, 0.27, 0.17), dirt * 0.6);
	// textura fina (folhas de capim / grãos)
	c *= 0.86 + 0.28 * fine;
	// areia: ondulações e areia molhada perto da água
	float sand = 1.0 - smoothstep(2.4, 3.2, wpos.y);
	float ripple = sin(wpos.x * 0.9 + sin(wpos.z * 0.3) * 2.0 + mid * 6.0) * 0.5 + 0.5;
	c = mix(c, c * (0.93 + 0.1 * ripple), sand);
	// rocha estriada nas encostas
	vec3 rock = vec3(0.42, 0.39, 0.35) * (0.8 + 0.3 * vnoise(vec2(wpos.y * 1.5, wpos.x * 0.1 + wpos.z * 0.1)));
	c = mix(c, rock, smoothstep(0.38, 0.6, slope));
	float wet = 1.0 - smoothstep(0.2, 1.4, wpos.y);
	c *= mix(1.0, 0.7, wet * step(-2.0, wpos.y));
	float foam_line = 1.0 - smoothstep(0.0, 0.55, abs(wpos.y - 0.15 - 0.25 * sin(TIME * 1.3 + wpos.x * 0.05 + wpos.z * 0.04)));
	float foam_n = vnoise(wpos.xz * 1.3 + vec2(TIME * 0.4, 0.0));
	c = mix(c, vec3(0.92, 0.95, 0.95), foam_line * smoothstep(0.35, 0.7, foam_n) * 0.85);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.35, wet);
	SPECULAR = 0.2;
}
