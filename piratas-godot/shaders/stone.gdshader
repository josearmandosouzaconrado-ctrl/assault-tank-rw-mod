shader_type spatial;
render_mode diffuse_burley, cull_disabled;
// Alvenaria de pedra calcária: fiadas de blocos desencontrados, argamassa e manchas de tempo.
// UV.x = metros ao longo do muro, UV.y = altura em metros.

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y / 0.62);
	float off = mod(row, 2.0) * 0.6;
	vec2 cell = vec2(floor((uv.x + off) / 1.2), row);
	vec2 f = vec2(fract((uv.x + off) / 1.2), fract(uv.y / 0.62));
	float mortar = 1.0 - smoothstep(0.0, 0.05, min(min(f.x, 1.0 - f.x) * 1.2, min(f.y, 1.0 - f.y) * 0.62));
	float tone = 0.85 + 0.25 * hash(cell);
	vec3 c = COLOR.rgb * tone * (0.9 + 0.15 * vnoise(uv * 3.0));
	c = mix(c, c * 0.55, mortar * 0.8);
	// escorrido escuro de chuva e limo perto da base
	float streak = vnoise(vec2(uv.x * 2.0, 0.0)) * smoothstep(3.0, 0.0, uv.y);
	c *= 1.0 - streak * 0.25;
	c = mix(c, c * vec3(0.7, 0.75, 0.6), smoothstep(1.2, 0.0, uv.y) * 0.5);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
