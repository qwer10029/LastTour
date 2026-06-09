shader_type canvas_item;
render_mode blend_mix;

uniform float max_alpha : hint_range(0.0, 1.0) = 0.76;

void fragment() {
	float t = UV.y;
	float alpha = max_alpha * t * t;
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
