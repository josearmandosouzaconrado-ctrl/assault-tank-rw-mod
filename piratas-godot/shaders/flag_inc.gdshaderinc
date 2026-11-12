// Bandeiras das nações desenhadas proceduralmente. uv.x = mastro -> ponta, uv.y = cima -> baixo.
float fl_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

vec3 flag_pattern(int t, vec2 uv) {
	vec2 q = vec2((uv.x - 0.5) * 1.5, uv.y - 0.5);
	vec2 d1 = vec2(0.832, 0.555);
	vec2 d2 = vec2(0.832, -0.555);
	float sal = min(abs(q.x * d1.y - q.y * d1.x), abs(q.x * d2.y - q.y * d2.x));
	vec3 white = vec3(0.95, 0.94, 0.9);
	vec3 red = vec3(0.78, 0.07, 0.1);
	if (t == 0) { // Grã-Bretanha (União de 1707)
		vec3 c = vec3(0.02, 0.13, 0.42);
		if (sal < 0.085) c = white;
		if (abs(q.x) < 0.11 || abs(q.y) < 0.11) c = white;
		if (abs(q.x) < 0.065 || abs(q.y) < 0.065) c = red;
		return c;
	} else if (t == 1) { // Espanha (Cruz de Borgonha)
		float rag = 0.012 * sin(length(q) * 60.0);
		return sal < 0.06 + rag ? vec3(0.72, 0.06, 0.07) : white;
	} else if (t == 2) { // França (pavilhão real branco com lírios)
		vec3 c = white;
		vec2 f[3] = vec2[3](vec2(-0.2, -0.12), vec2(0.2, -0.12), vec2(0.0, 0.16));
		for (int i = 0; i < 3; i++) {
			vec2 p = q - f[i];
			float lily = min(length(p * vec2(1.6, 0.8)) - 0.05, min(length(p - vec2(-0.05, 0.02)) - 0.03, length(p - vec2(0.05, 0.02)) - 0.03));
			if (lily < 0.0) c = vec3(0.85, 0.66, 0.18);
		}
		return c;
	} else if (t == 3) { // Holanda
		if (uv.y < 0.333) return vec3(0.72, 0.1, 0.12);
		if (uv.y < 0.666) return white;
		return vec3(0.06, 0.2, 0.55);
	} else if (t == 4) { // Portugal
		vec3 c = white;
		vec2 s = q - vec2(0.0, 0.04);
		if (abs(s.x) < 0.17 && abs(s.y) < 0.2 && length(s - vec2(0.0, 0.05)) < 0.27) c = red;
		if (abs(s.x) < 0.12 && abs(s.y) < 0.15 && length(s - vec2(0.0, 0.03)) < 0.2) c = white;
		for (int i = 0; i < 5; i++) {
			vec2 o = vec2(0.0, 0.0);
			if (i == 1) o = vec2(-0.065, 0.0);
			if (i == 2) o = vec2(0.065, 0.0);
			if (i == 3) o = vec2(0.0, -0.07);
			if (i == 4) o = vec2(0.0, 0.07);
			if (length(s - o) < 0.026) c = vec3(0.08, 0.2, 0.6);
		}
		if (abs(q.x) < 0.12 && q.y < -0.18 && q.y > -0.3) c = vec3(0.88, 0.7, 0.2);
		return c;
	}
	if (t == 6) { // Reino do jogador: coroa dourada sobre carmesim, com borda dourada
		vec3 gold = vec3(0.92, 0.72, 0.2);
		vec3 c = vec3(0.42, 0.04, 0.16);
		if (uv.x < 0.04 || uv.x > 0.96 || uv.y < 0.06 || uv.y > 0.94) c = gold;
		vec2 k = q - vec2(0.0, 0.02);
		float band = step(abs(k.x), 0.2) * step(0.08, k.y) * step(k.y, 0.16);
		float body = step(abs(k.x), 0.2) * step(-0.06, k.y) * step(k.y, 0.12);
		float spikes = 0.0;
		for (int i = -1; i <= 1; i++) {
			vec2 sp = k - vec2(float(i) * 0.15, -0.06);
			if (sp.y < 0.0 && sp.y > -0.17 + abs(sp.x) * 1.9) spikes = 1.0;
			if (length(k - vec2(float(i) * 0.15, -0.25 + abs(float(i)) * 0.04)) < 0.035) spikes = 1.0;
		}
		if (band + body + spikes > 0.0) c = gold;
		if (length(k - vec2(0.0, 0.03)) < 0.035) c = vec3(0.7, 0.05, 0.1);
		return c;
	}
	// Piratas: caveira e ossos cruzados
	vec3 c = vec3(0.03);
	vec2 s = q - vec2(0.0, -0.06);
	float skull = length(s * vec2(1.0, 1.1)) - 0.17;
	float jaw = max(abs(s.x) - 0.1, abs(s.y - 0.17) - 0.07);
	float bones = min(fl_seg(q, vec2(-0.32, 0.12), vec2(0.32, 0.4)), fl_seg(q, vec2(-0.32, 0.4), vec2(0.32, 0.12))) - 0.035;
	bones = min(bones, min(min(length(q - vec2(-0.34, 0.1)), length(q - vec2(0.34, 0.1))), min(length(q - vec2(-0.34, 0.42)), length(q - vec2(0.34, 0.42)))) - 0.05);
	if (min(min(skull, jaw), bones) < 0.0) c = white;
	if (length(s - vec2(-0.065, -0.01)) < 0.05 || length(s - vec2(0.065, -0.01)) < 0.05) c = vec3(0.03);
	if (abs(s.x) < 0.02 && abs(s.y - 0.08) < 0.03) c = vec3(0.03);
	return c;
}
