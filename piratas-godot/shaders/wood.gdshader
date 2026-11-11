shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform float plank = 3.2;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y * plank);
	float off = hash(vec2(row, 3.0)) * 7.0;
	float along = uv.x * 0.25 + off;
	float joint = smoothstep(0.0, 0.015, abs(fract(along) - 0.5) - 0.485);
	float line = smoothstep(0.0, 0.06, fract(uv.y * plank)) * smoothstep(1.0, 0.94, fract(uv.y * plank));
	float tone = 0.86 + 0.14 * hash(vec2(row, floor(along)));
	float grain = 0.95 + 0.05 * sin(uv.x * 9.0 + sin(uv.y * 40.0 + uv.x) * 2.0);
	vec3 c = COLOR.rgb * tone * grain * mix(0.55, 1.0, line) * mix(1.0, 0.7, joint * COLOR.a);
	ALBEDO = c;
	ROUGHNESS = 0.78;
	SPECULAR = 0.25;
}
