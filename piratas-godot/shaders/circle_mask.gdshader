shader_type canvas_item;
// Recorta o desenho do minimapa num círculo.
uniform vec2 center = vec2(94.0);
uniform float radius = 92.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	if (distance(lp, center) > radius) {
		discard;
	}
}
