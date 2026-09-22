shader_type canvas_item;
render_mode unshaded;

varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}

// Spatial coverage of ONE physical display pixel, not a blend of poses.
// Key each nearest sample before averaging so magenta cannot bleed into hair
// or skin. Flat pixel-art clusters stay flat; only moving edges gain coverage.
vec4 keyed_sample(sampler2D source_texture, vec2 at) {
	vec4 sample_color = texture(source_texture, at);
	if (min(sample_color.r, sample_color.b) - sample_color.g > 0.23 && sample_color.r > 0.35 && sample_color.b > 0.35) {
		return vec4(0.0);
	}
	return vec4(sample_color.rgb * sample_color.a, sample_color.a);
}

void fragment() {
	vec2 footprint_x = dFdx(UV);
	vec2 footprint_y = dFdy(UV);
	vec4 covered = vec4(0.0);
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			vec2 offset = (vec2(float(x), float(y)) + vec2(0.5)) / 4.0 - vec2(0.5);
			covered += keyed_sample(TEXTURE, UV + offset.x * footprint_x + offset.y * footprint_y);
		}
	}
	covered /= 16.0;
	COLOR = vec4(covered.rgb / max(covered.a, 0.00001), covered.a) * vertex_tint;
}
