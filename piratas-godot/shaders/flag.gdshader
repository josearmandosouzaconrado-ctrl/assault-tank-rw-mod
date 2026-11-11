shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://shaders/flag_inc.gdshaderinc"

uniform int flag_type = 0;
uniform float wind = 1.0;

void vertex() {
	float u = UV.x;
	float w = sin(u * 7.0 - TIME * 9.0 + UV.y * 1.5) * 0.18 + sin(u * 13.0 - TIME * 15.0) * 0.05;
	VERTEX.z += w * u * wind * 1.4;
	VERTEX.y -= u * u * 0.25 * (1.2 - wind);
	NORMAL = normalize(vec3(0.0, 0.0, 1.0) + vec3(-cos(u * 7.0 - TIME * 9.0) * 0.8 * u, 0.0, 0.0));
}

void fragment() {
	vec3 c = flag_pattern(flag_type, UV);
	ALBEDO = c * 0.85;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
