shader_type canvas_item;

uniform bool unaffordable = false;

void fragment() {
	if (unaffordable) {
		float gray = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		COLOR.rgb = vec3(gray * 0.70);
	}
}
