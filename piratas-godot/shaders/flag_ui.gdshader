shader_type canvas_item;
#include "res://shaders/flag_inc.gdshaderinc"

uniform int flag_type = 0;

void fragment() {
	vec2 uv = UV;
	uv.y += sin(uv.x * 6.0 + TIME * 3.0) * 0.015 * uv.x;
	vec3 c = flag_pattern(flag_type, clamp(uv, 0.0, 1.0));
	float shade = 0.9 + 0.1 * sin(uv.x * 6.0 + TIME * 3.0);
	COLOR = vec4(c * shade, 1.0);
}
