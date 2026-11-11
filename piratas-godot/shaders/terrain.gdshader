shader_type spatial;
render_mode diffuse_burley;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(wpos.xz * 0.15) * 0.6 + vnoise(wpos.xz * 0.9) * 0.4;
	vec3 c = COLOR.rgb * (0.82 + 0.3 * n);
	// areia molhada e espuma na linha d'água
	float wet = 1.0 - smoothstep(0.2, 1.4, wpos.y);
	c *= mix(1.0, 0.72, wet * step(-2.0, wpos.y));
	float foam_line = 1.0 - smoothstep(0.0, 0.55, abs(wpos.y - 0.15 - 0.25 * sin(TIME * 1.3 + wpos.x * 0.05 + wpos.z * 0.04)));
	float foam_n = vnoise(wpos.xz * 1.3 + vec2(TIME * 0.4, 0.0));
	c = mix(c, vec3(0.92, 0.95, 0.95), foam_line * smoothstep(0.35, 0.7, foam_n) * 0.85);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.35, wet);
	SPECULAR = 0.2;
}
