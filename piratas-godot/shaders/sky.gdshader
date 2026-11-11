shader_type sky;

uniform vec3 day_top : source_color = vec3(0.16, 0.38, 0.72);
uniform vec3 day_horizon : source_color = vec3(0.62, 0.78, 0.9);
uniform vec3 sunset_horizon : source_color = vec3(1.0, 0.55, 0.24);
uniform vec3 night_top : source_color = vec3(0.012, 0.025, 0.06);
uniform vec3 night_horizon : source_color = vec3(0.07, 0.1, 0.18);
uniform vec3 storm_tint : source_color = vec3(0.35, 0.38, 0.42);
uniform float storm = 0.0;
uniform float cloud_cover = 0.42;
uniform vec2 cloud_offset = vec2(0.0);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 moon_dir = vec3(0.3, 0.5, -0.8);
uniform vec3 sun_dir = vec3(0.3, 0.5, 0.2);

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void sky() {
	vec3 dir = EYEDIR;
	vec3 sd = normalize(sun_dir);
	float sh = sd.y;
	float day = smoothstep(-0.18, 0.28, sh);
	float sunset = clamp(1.0 - abs(sh - 0.02) * 4.0, 0.0, 1.0);
	float up = clamp(dir.y, 0.0, 1.0);
	float to_sun = max(dot(dir, sd), 0.0);
	float sun_side = pow(max(dot(normalize(dir.xz + 0.0001), normalize(sd.xz + 0.0001)), 0.0), 2.0);

	vec3 top = mix(night_top, day_top, day);
	vec3 hor = mix(night_horizon, day_horizon, day);
	hor = mix(hor, sunset_horizon, sunset * (0.45 + 0.55 * sun_side));
	vec3 c = mix(hor, top, pow(up, 0.45));
	c = mix(c, storm_tint * (0.25 + 0.75 * day), storm * 0.8);
	// halo do sol
	c += mix(vec3(1.0, 0.6, 0.3), vec3(1.0, 0.95, 0.85), day) * (pow(to_sun, 8.0) * 0.35 + pow(to_sun, 120.0) * 1.2) * (1.0 - storm * 0.8) * smoothstep(-0.25, 0.0, sh);
	// disco do sol
	float disc = smoothstep(0.9993, 0.9997, to_sun);
	c += vec3(18.0, 14.0, 9.0) * disc * smoothstep(-0.05, 0.02, sh) * (1.0 - storm);
	// lua e estrelas
	float night = 1.0 - day;
	float md = dot(dir, normalize(moon_dir));
	c += vec3(0.9, 0.92, 1.0) * smoothstep(0.9994, 0.9997, md) * night * 2.0;
	c += vec3(0.3, 0.35, 0.5) * pow(max(md, 0.0), 60.0) * night * 0.3;
	if (dir.y > 0.0) {
		vec3 sp = floor(dir * 420.0);
		float st = step(0.9975, hash3(sp));
		c += vec3(st) * night * up * (1.0 - storm) * 1.5;
	}
	// nuvens (só no céu visível, não no reflexo)
	if (!AT_CUBEMAP_PASS && dir.y > 0.005) {
		vec2 uv = dir.xz / (dir.y + 0.12) * 0.28 + cloud_offset;
		float n = texture(cloud_noise, uv).r * 0.65 + texture(cloud_noise, uv * 2.7 + 0.3).r * 0.35;
		float cov = mix(cloud_cover, 0.95, storm);
		float dens = smoothstep(1.0 - cov, 1.0 - cov + 0.28, n);
		dens *= smoothstep(0.005, 0.12, dir.y);
		vec3 lit = mix(vec3(1.0, 0.62, 0.38), vec3(1.0, 0.98, 0.95), clamp(sh * 3.0, 0.0, 1.0));
		vec3 cc = mix(vec3(0.25, 0.27, 0.32), lit, 0.55 + 0.45 * (1.0 - n));
		cc *= (0.15 + 0.85 * day);
		cc += lit * pow(to_sun, 10.0) * 0.8 * (1.0 - dens * 0.5) * day;
		cc = mix(cc, storm_tint * 0.6 * (0.3 + 0.7 * day), storm);
		c = mix(c, cc, dens * 0.92);
	}
	if (dir.y < 0.0) {
		c = mix(hor, hor * 0.4, clamp(-dir.y * 4.0, 0.0, 1.0));
	}
	COLOR = c;
}
