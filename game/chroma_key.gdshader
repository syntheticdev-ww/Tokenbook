shader_type canvas_item;
render_mode unshaded;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
// Non-destructive key; original generated PNGs are retained.
void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	if (min(sampled.r, sampled.b) - sampled.g > 0.23 && sampled.r > 0.35 && sampled.b > 0.35) {
		discard;
	}
	COLOR = sampled * vertex_tint;
}
