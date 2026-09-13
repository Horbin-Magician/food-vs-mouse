shader_type canvas_item;

uniform float remaining_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec2 card_size = vec2(110.0, 60.0);

void fragment() {
	// Reveal from the top; preserve the button's outer selection border.
	vec2 half_size = card_size * 0.5 - vec2(1.0);
	vec2 q = abs(UV * card_size - card_size * 0.5) - half_size + vec2(9.0);
	float edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 9.0;
	float rounded_mask = 1.0 - smoothstep(-0.5, 0.5, edge);
	COLOR.a *= rounded_mask * step(1.0 - remaining_ratio, UV.y);
}
