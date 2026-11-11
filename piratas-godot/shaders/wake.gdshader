shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float edge = sin(3.14159 * clamp(UV.y, 0.0, 1.0));
	float n1 = texture(noise, wpos.xz * 0.11 + vec2(TIME * 0.02, 0.0)).r;
	float n2 = texture(noise, wpos.xz * 0.37 - vec2(0.0, TIME * 0.03)).r;
	float foam = smoothstep(0.3, 0.75, n1 * 0.6 + n2 * 0.5 + COLOR.a * 0.25);
	ALBEDO = vec3(0.9, 0.95, 0.95);
	ROUGHNESS = 0.7;
	ALPHA = clamp(COLOR.a * edge * foam * 1.4, 0.0, 1.0);
}
