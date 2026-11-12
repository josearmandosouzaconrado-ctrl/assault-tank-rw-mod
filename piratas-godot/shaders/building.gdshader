shader_type spatial;
render_mode diffuse_burley, cull_disabled;
// Material único das construções (casas, igreja, píer, forte): a cor do vértice dá a cor e o alfa diz o tipo
// de superfície, desenhado por procedimento a partir do UV em metros (u ao longo, v para cima/descendo).
//   1.0 pintura lisa (molduras, portas)   0.8 reboco caiado   0.6 telha capa-canal   0.4 tábuas de madeira
//   0.2 cantaria de pedra                 0.0 vidro / escuro do interior

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float kind = COLOR.a;
	vec3 base = COLOR.rgb;
	vec2 uv = UV;
	vec3 c = base;
	float rough = 0.9;
	float spec = 0.2;
	vec3 nm = vec3(0.5, 0.5, 1.0);
	if (kind > 0.9) {
		c = base * (0.94 + 0.08 * vnoise(uv * 6.0));
		rough = 0.7;
		spec = 0.3;
	} else if (kind > 0.7) {
		// reboco: manchas suaves, encardido perto do chão e onde escorre a chuva
		float n = vnoise(uv * 1.3) * 0.6 + vnoise(uv * 7.0) * 0.4;
		c = base * (0.9 + 0.14 * n);
		float dirt = smoothstep(1.4, 0.0, uv.y) * 0.35 + vnoise(vec2(wpos.x * 1.7 + wpos.z * 1.3, 0.0)) * 0.08;
		c = mix(c, c * vec3(0.62, 0.58, 0.52), clamp(dirt, 0.0, 1.0));
		// reboco caído mostrando a pedra por baixo
		float peel = smoothstep(0.83, 0.88, vnoise(uv * 0.9 + 3.0) * vnoise(uv * 2.3));
		c = mix(c, vec3(0.55, 0.5, 0.44), peel * 0.7);
		rough = 0.95;
		spec = 0.12;
	} else if (kind > 0.5) {
		// telhas capa-canal: fileiras de telhas curvas, cada uma num tom de barro
		float w = 0.26;
		float col = floor(uv.x / w);
		float fx = fract(uv.x / w);
		float rowh = 0.38;
		float row = floor((uv.y + mod(col, 2.0) * 0.12) / rowh);
		float fy = fract((uv.y + mod(col, 2.0) * 0.12) / rowh);
		float prof = sin(fx * 3.14159);
		float tone = 0.78 + 0.32 * hash(vec2(col, row));
		c = base * tone * (0.55 + 0.45 * prof);
		c *= 0.75 + 0.25 * smoothstep(0.0, 0.25, fy);              // sombra da telha de cima
		c = mix(c, c * vec3(0.6, 0.62, 0.5), vnoise(uv * 1.5) * 0.35); // limo
		nm = normalize(vec3(cos(fx * 3.14159) * 0.6, 0.0, 1.0)) * 0.5 + 0.5;
		rough = 0.8;
		spec = 0.25;
	} else if (kind > 0.3) {
		// tábuas: emendas a cada 0,2 m, veios ao comprido e tom diferente em cada tábua
		float bw = 0.2;
		float b = floor(uv.y / bw);
		float fb = fract(uv.y / bw);
		float seg = floor((uv.x + hash(vec2(b, 1.0)) * 3.0) / 2.6);
		float tone = 0.78 + 0.3 * hash(vec2(b, seg));
		float grain = vnoise(vec2(uv.x * 1.5, uv.y * 40.0)) * 0.5 + vnoise(vec2(uv.x * 0.4, uv.y * 90.0)) * 0.5;
		c = base * tone * (0.82 + 0.25 * grain);
		float seam = 1.0 - smoothstep(0.0, 0.06, min(fb, 1.0 - fb));
		c *= 1.0 - seam * 0.45;
		nm = vec3(0.5, 0.5 + (fb - 0.5) * 0.25 * seam, 1.0);
		rough = 0.85;
		spec = 0.15;
	} else if (kind > 0.1) {
		// cantaria: fiadas de blocos desencontrados com argamassa
		float row = floor(uv.y / 0.55);
		float off = mod(row, 2.0) * 0.55;
		vec2 cell = vec2(floor((uv.x + off) / 1.1), row);
		vec2 f = vec2(fract((uv.x + off) / 1.1), fract(uv.y / 0.55));
		float mortar = 1.0 - smoothstep(0.0, 0.05, min(min(f.x, 1.0 - f.x) * 1.1, min(f.y, 1.0 - f.y) * 0.55));
		c = base * (0.82 + 0.28 * hash(cell)) * (0.9 + 0.15 * vnoise(uv * 3.0));
		c = mix(c, c * 0.55, mortar * 0.8);
		c = mix(c, c * vec3(0.7, 0.75, 0.6), smoothstep(1.5, 0.0, uv.y) * 0.45);
		nm = vec3(0.5, 0.5, 1.0) + vec3(0.0, 0.0, -0.4) * mortar;
		rough = 0.95;
		spec = 0.12;
	} else {
		c = base;
		rough = 0.15;
		spec = 0.6;
	}
	ALBEDO = c;
	// (sem mapa de normais: as malhas não têm tangentes; o relevo vai na cor)
	ROUGHNESS = rough;
	SPECULAR = spec;
}
