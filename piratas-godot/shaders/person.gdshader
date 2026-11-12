shader_type spatial;
// Corpo dos personagens: pele com textura real e roupas da época recortadas por pixel.
// COLOR.gba = posição de repouso na T-pose (gravada por tools/preparar_humanos.py; espaço do modelo,
// frente = +Z): as roupas são recortadas por essas medidas, com bordas limpas.
// O tronco vira casaca/camisa com a frente do colete aberta e a gravata; o braço vira manga e punho
// (ou pele, com a manga arregaçada); a perna vira calção, meia e sapato. A roupa "incha" um pouco
// por cima do corpo e esconde os músculos do modelo.

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec3 skin_mul = vec3(1.0);
// cor (rgb) e se é pano (a = 1) ou pele à mostra (a = 0)
uniform vec4 c_torso : source_color = vec4(0.5, 0.1, 0.1, 1.0);
uniform vec4 c_front : source_color = vec4(0.6, 0.5, 0.3, 1.0);
uniform vec4 c_neck : source_color = vec4(0.95, 0.94, 0.9, 1.0);
uniform vec4 c_arm : source_color = vec4(0.5, 0.1, 0.1, 1.0);
uniform vec4 c_fore : source_color = vec4(0.5, 0.1, 0.1, 1.0);
uniform vec4 c_breeches : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec4 c_stock : source_color = vec4(0.9, 0.9, 0.85, 1.0);
uniform vec4 c_shoe : source_color = vec4(0.08, 0.06, 0.05, 1.0);
// folga da roupa (m): tronco, braço, calção
uniform vec3 loose = vec3(0.014, 0.014, 0.01);
// medidas na T-pose: ombro (x), cotovelo (x), punho (x), cintura (y) | joelho, tornozelo, pescoço, cabeça (y)
uniform vec4 m1 = vec4(0.2, 0.463, 0.69, 0.99);
uniform vec4 m2 = vec4(0.47, 0.115, 1.49, 1.57);

varying vec3 rp;

// 0 pele, 1 tronco, 2 frente do colete, 3 pescoço (gravata ou pele), 4 braço, 5 antebraço, 6 calção, 7 meia, 8 sapato
int zone(vec3 r) {
	float ax = abs(r.x);
	if (ax > m1.z) { return 0; }
	if (ax > m1.x && r.y > m1.w) { return ax < m1.y ? 4 : 5; }
	if (r.y > m2.w) { return 0; }
	if (r.y > m2.z && ax < 0.11) { return 3; }
	if (r.y < m1.w) {
		if (r.y > m2.x) { return 6; }
		return r.y > m2.y ? 7 : 8;
	}
	float open_w = 0.045 + max(0.0, m2.z - 0.09 - r.y) * 0.16;
	if (r.z > 0.0 && ax < open_w) { return 2; }
	return 1;
}

vec4 zone_color(int z) {
	if (z == 1) { return c_torso; }
	if (z == 2) { return c_front; }
	if (z == 3) { return c_neck; }
	if (z == 4) { return c_arm; }
	if (z == 5) { return c_fore; }
	if (z == 6) { return c_breeches; }
	if (z == 7) { return c_stock; }
	if (z == 8) { return c_shoe; }
	return vec4(0.0);
}

void vertex() {
	rp = vec3(COLOR.g * 2.0 - 1.0, COLOR.b * 2.0, COLOR.a - 0.5);
	int z = zone(rp);
	float inf = 0.0;
	if (z <= 2) { inf = loose.x; }
	else if (z == 3) { inf = 0.008; }
	else if (z <= 5) { inf = loose.y; }
	else if (z == 6) { inf = loose.z; }
	else if (z == 7) { inf = 0.003; }
	else { inf = 0.008; }
	VERTEX += NORMAL * inf * zone_color(z).a;
}

void fragment() {
	int z = zone(rp);
	vec4 c = zone_color(z);
	vec3 tex = texture(tex_albedo, UV).rgb;
	vec3 nm = texture(tex_normal, UV).rgb;
	if (c.a > 0.5) {
		// tecido: só um pouco da forma do corpo (dobras), sem músculos marcados
		float shade = mix(0.9, 1.04, clamp(tex.g * 1.6, 0.0, 1.0));
		ALBEDO = c.rgb * shade;
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nm, 0.12);
		bool shoe = z == 8;
		ROUGHNESS = shoe ? 0.4 : 0.88;
		SPECULAR = shoe ? 0.5 : 0.2;
	} else {
		ALBEDO = tex * skin_mul;
		// o rosto mantém o detalhe; no corpo o relevo dos músculos fica bem mais suave
		NORMAL_MAP = rp.y > m2.w ? nm : mix(vec3(0.5, 0.5, 1.0), nm, 0.35);
		ROUGHNESS = 0.58;
		SPECULAR = 0.4;
	}
}
