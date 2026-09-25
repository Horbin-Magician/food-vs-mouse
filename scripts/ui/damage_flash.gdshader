shader_type canvas_item;
render_mode unshaded;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	COLOR = vec4(vec3(1.0, 0.94, 0.82), texel.a * strength);
}
