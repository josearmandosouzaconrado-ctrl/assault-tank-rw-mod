shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://shaders/flag_inc.gdshaderinc"

uniform vec3 sail_color : source_color = vec3(0.92, 0.89, 0.8);
uniform vec3 emblem_color : source_color = vec3(0.7, 0.05, 0.05);
uniform int emblem = 0;
uniform float fill = 1.0;      // enfunada pelo vento (pode ser negativa: vento contra)
uniform float furl = 1.0;      // 0 = recolhida, 1 = aberta
uniform float damage = 0.0;    // 0..1 rasgos
uniform float sail_w = 8.0;
uniform float sail_h = 8.0;
uniform float depth = 1.6;
uniform float fore_aft = 0.0;  // vela latina (triangular)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

varying float v_fold;

void vertex() {
	float u = UV.x;
	float v = UV.y;
	float f = max(furl, 0.05);
	VERTEX.y *= f;
	if (fore_aft > 0.5) {
		VERTEX.x *= mix(1.0, 1.0 - v * 0.0, 1.0);
	}
	float flutter = sin(TIME * 7.0 + v * 9.0 + u * 4.0) * 0.12 * (1.0 - clamp(abs(fill), 0.0, 1.0));
	float b = sin(3.14159 * u) * sin(3.14159 * clamp(v * 0.92 + 0.08, 0.0, 1.0));
	VERTEX.z += (fill * depth * b + flutter) * f;
	float dzdu = fill * depth * 3.14159 * cos(3.14159 * u) * sin(3.14159 * v) / sail_w;
	float dzdv = fill * depth * 3.14159 * sin(3.14159 * u) * cos(3.14159 * v) / sail_h;
	NORMAL = normalize(vec3(-dzdu, dzdv, 1.0));
	v_fold = (1.0 - furl) * 0.5 + 0.5 * (1.0 - furl) * sin(v * 60.0);
}

void fragment() {
	float u = UV.x, v = UV.y;
	if (damage > 0.02) {
		float n = vnoise(UV * vec2(sail_w, sail_h) * 0.5) * 0.7 + vnoise(UV * vec2(sail_w, sail_h) * 1.7) * 0.3;
		if (n < damage * 0.55 - 0.02) discard;
	}
	vec3 c = sail_color;
	float seam = smoothstep(0.0, 0.02, abs(fract(u * sail_w / 1.2) - 0.5) - 0.47);
	c *= 0.93 + 0.07 * (1.0 - seam);
	c *= 0.95 + 0.05 * vnoise(UV * 30.0);
	vec2 q = vec2((u - 0.5) * sail_w / sail_h, v - 0.5);
	if (emblem == 1) {
		vec2 d1 = normalize(vec2(1.0, 1.0)), d2 = normalize(vec2(1.0, -1.0));
		float sal = min(abs(q.x * d1.y - q.y * d1.x), abs(q.x * d2.y - q.y * d2.x));
		if (sal < 0.05 + 0.01 * sin(length(q) * 50.0) && length(q) < 0.42) c = emblem_color;
	} else if (emblem == 2) {
		if ((abs(q.x) < 0.045 && abs(q.y) < 0.3) || (abs(q.y + 0.05) < 0.045 && abs(q.x) < 0.22)) c = emblem_color;
	} else if (emblem == 3) {
		vec2 eu = vec2(q.x / 0.62 + 0.5, (q.y + 0.04) / 0.5 + 0.5);
		if (eu.x > 0.0 && eu.x < 1.0 && eu.y > 0.0 && eu.y < 1.0) {
			vec3 fc = flag_pattern(5, eu);
			if (fc.r > 0.5) c = emblem_color;
		}
	}
	// faixas de rizes, cabos de borda (relinga) e manchas de uso
	float reef = 0.0;
	for (int i = 1; i <= 3; i++) {
		reef = max(reef, 1.0 - smoothstep(0.0, 0.006, abs(v - 0.09 * float(i))));
	}
	c *= 1.0 - reef * 0.22;
	float edge = 1.0 - smoothstep(0.0, 0.02, min(min(u, 1.0 - u), min(v, 1.0 - v)));
	c = mix(c, c * 0.65, edge);
	c *= 0.92 + 0.08 * vnoise(UV * vec2(3.0, 5.0) + 7.0);
	c *= 1.0 - v_fold * 0.25;
	// borda inferior mais suja
	c *= mix(1.0, 0.82, smoothstep(0.75, 1.0, v));
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	BACKLIGHT = c * 0.45;
}
