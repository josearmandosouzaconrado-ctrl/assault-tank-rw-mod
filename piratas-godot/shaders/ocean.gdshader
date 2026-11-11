shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// As mesmas 5 ondas existem em ocean.gd (para a flutuação dos navios).
uniform float wave_time = 0.0;
uniform float sea_state = 1.0;
uniform vec2 wind_dir = vec2(1.0, 0.3);
uniform sampler2D shallow_map : filter_linear, repeat_disable;
uniform float world_half = 8200.0;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 deep_color : source_color = vec3(0.008, 0.085, 0.15);
uniform vec3 shallow_color : source_color = vec3(0.03, 0.52, 0.52);
uniform vec3 scatter_color : source_color = vec3(0.0, 0.42, 0.38);
uniform float light_level = 1.0;
uniform vec2 cam_xz = vec2(0.0);
// navios próximos para a esteira: a = (x, z, rumo, velocidade), b = (comprimento, boca, 0, 0)
uniform vec4 ship_a[8];
uniform vec4 ship_b[8];
uniform int ship_count = 0;

varying vec3 wpos;
varying float wave_h;
varying float fade;

const float CHOP = 1.15;

void wave(vec2 p, vec2 dir, float L, float A, inout vec3 disp, inout vec2 grad) {
	float k = 6.28318 / L;
	float w = sqrt(9.8 * k) * 0.8;
	vec2 d = normalize(dir);
	float f = k * dot(d, p) - w * wave_time;
	float c = cos(f);
	disp.x += CHOP * A * d.x * c;
	disp.z += CHOP * A * d.y * c;
	disp.y += A * sin(f);
	grad += A * k * d * c;
}

vec2 rot(vec2 v, float a) { return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a)); }

void waves(vec2 p, float big, float small, out vec3 disp, out vec2 grad) {
	disp = vec3(0.0);
	grad = vec2(0.0);
	vec2 wd = normalize(wind_dir);
	wave(p, wd, 64.0, 0.80 * big, disp, grad);
	wave(p, rot(wd, 0.6), 33.0, 0.44 * big, disp, grad);
	wave(p, rot(wd, -0.7), 19.0, 0.25 * big, disp, grad);
	wave(p, rot(wd, 1.3), 10.5, 0.12 * small, disp, grad);
	wave(p, rot(wd, -1.6), 6.0, 0.06 * small, disp, grad);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world.xz - cam_xz);
	// mesmas distâncias de Ocean.BIG_FADE / SMALL_FADE (CPU)
	fade = 1.0 - smoothstep(190.0, 250.0, dist);
	float small = 1.0 - smoothstep(60.0, 90.0, dist);
	vec3 disp;
	vec2 grad;
	waves(world.xz, sea_state * fade, sea_state * small, disp, grad);
	VERTEX += disp;
	wave_h = disp.y;
	wpos = world + disp;
}

void fragment() {
	float dist = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	float nf = 1.0 - smoothstep(600.0, 3500.0, dist);
	float nsmall = 1.0 - smoothstep(150.0, 700.0, dist) * 0.85;
	vec3 disp;
	vec2 grad;
	waves(wpos.xz, sea_state * max(nf, 0.15), sea_state * nsmall, disp, grad);
	vec3 n = normalize(vec3(-grad.x, 1.0, -grad.y));
	// ondulações finas
	vec2 uv1 = wpos.xz * 0.045 + vec2(wave_time * 0.018, wave_time * 0.011);
	vec2 uv2 = wpos.xz * 0.011 - vec2(wave_time * 0.008, -wave_time * 0.013);
	vec3 d1 = texture(detail_normal, uv1).xzy * 2.0 - 1.0;
	vec3 d2 = texture(detail_normal, uv2).xzy * 2.0 - 1.0;
	float detail = mix(0.26, 0.06, smoothstep(30.0, 900.0, dist)) * (0.6 + 0.4 * sea_state);
	n = normalize(n + vec3(d1.x + d2.x, 0.0, d1.z + d2.z) * detail);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	vec2 suv = wpos.xz / (world_half * 2.0) + 0.5;
	float shallow = texture(shallow_map, suv).r;
	vec3 col = mix(deep_color, shallow_color, shallow * 0.92);
	// luz atravessando as cristas (subsuperfície)
	float crest = smoothstep(-0.3, 1.5 * sea_state, wave_h);
	vec3 view_w = normalize(CAMERA_POSITION_WORLD - wpos);
	float grazing = 1.0 - clamp(view_w.y, 0.0, 1.0);
	vec3 sss = scatter_color * crest * (0.35 + 0.65 * grazing) * light_level;
	// espuma nas cristas e na água rasa
	float fnz = texture(foam_noise, wpos.xz * 0.06 + vec2(wave_time * 0.02, 0.0)).r;
	float crest_foam = smoothstep(1.05 * sea_state + 0.3, 1.7 * sea_state + 0.3, wave_h + fnz * 0.7) * fade;
	float shore_foam = smoothstep(0.86, 0.98, shallow + fnz * 0.08) * smoothstep(0.5, 0.75, fnz) * 0.55;
	// esteira e espuma do casco
	float wake = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= ship_count) break;
		vec4 a = ship_a[i];
		vec4 b = ship_b[i];
		vec2 dd = wpos.xz - a.xy;
		float L = b.x;
		float B = b.y;
		float reach = L * 1.2 + 25.0;
		if (dot(dd, dd) > reach * reach) continue;
		vec2 f = vec2(-sin(a.z), -cos(a.z));
		vec2 r = vec2(-f.y, f.x);
		float lz = dot(dd, f);
		float lx = dot(dd, r);
		float spd = clamp(a.w / 9.0, 0.0, 1.2);
		float e = length(vec2(lx / (B * 0.56), lz / (L * 0.5)));
		float ring = smoothstep(0.88, 1.0, e) * (1.0 - smoothstep(1.0, 1.25 + 0.45 * spd, e));
		ring *= (0.3 + 0.7 * spd) * (0.55 + 0.45 * clamp(lz / (L * 0.5), 0.0, 1.0));
		wake = max(wake, ring);
	}
	float wn = texture(foam_noise, wpos.xz * 0.13 + vec2(0.0, wave_time * 0.03)).r;
	float wn2 = texture(foam_noise, wpos.xz * 0.45 - vec2(wave_time * 0.02, 0.0)).r;
	float wake_foam = wake * smoothstep(0.35, 0.8, wn * 0.6 + wn2 * 0.5 + wake * 0.2);
	float foam = clamp(crest_foam + shore_foam * 0.8 + wake_foam, 0.0, 1.0);
	ALBEDO = mix(col, vec3(0.85, 0.9, 0.9), foam);
	EMISSION = sss * (1.0 - foam) + col * vec3(0.5, 0.8, 1.2) * 0.6 * (1.0 - light_level);
	ROUGHNESS = mix(0.04, 0.7, foam);
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
