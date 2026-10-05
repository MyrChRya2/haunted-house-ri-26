shader_type canvas_item;

uniform float radius : hint_range(0.0, 2048.0) = 0.0;
uniform float softness : hint_range(0.0, 256.0) = 14.0;
uniform vec2 rect_size = vec2(2048.0, 2048.0);

void fragment() {
	vec2 local = (UV - vec2(0.5)) * rect_size;
	float d = length(local);
	float a;
	if (radius <= 0.001) {
		a = 1.0;
	} else {
		float outer = radius;
		float inner = max(radius - softness, 0.0);
		a = smoothstep(inner, outer, d);
	}
	COLOR = vec4(0.0, 0.0, 0.0, a);
}