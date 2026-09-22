shader_type canvas_item;
render_mode unshaded;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}

// Authored low-resolution RGBA sprites: preserve each texel and its color.
// CanvasItem owns nearest sampling. No palette, pixelation or blur pass.
void fragment() {
	COLOR = texture(TEXTURE, UV) * vertex_tint;
}
