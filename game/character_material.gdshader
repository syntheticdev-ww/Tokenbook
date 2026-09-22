shader_type canvas_item;
render_mode unshaded;

// Static character material preview only. A fixed source grid preserves the
// drawing; texelFetch avoids averaging neighboring colors or implicit LOD.
uniform vec2 grid_size = vec2(224.0, 208.0);
uniform vec2 sample_offset = vec2(0.5, 0.5);
// A smaller window selects a consistent subset of the native drawing cells.
uniform float display_sampling_step = 1.0;
uniform vec2 display_sampling_offset = vec2(0.0);
// One sampling phase for the whole new drawing, including the face.
// The legacy override only reproduces earlier versions in comparisons.
uniform bool refined_face_sampling = false;
uniform vec2 face_sample_offset = vec2(0.2, 0.8);
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
 vec2 cell = floor(UV * grid_size / display_sampling_step) * display_sampling_step + display_sampling_offset;
 ivec2 extent = textureSize(TEXTURE, 0);
 bool facial_cell = cell.x >= 44.0 && cell.x < 57.0 && cell.y >= 28.0 && cell.y < 39.0;
 vec2 offset = (refined_face_sampling && facial_cell) ? face_sample_offset : sample_offset;
 ivec2 texel = clamp(ivec2((cell + offset) / grid_size * vec2(extent)), ivec2(0), extent - ivec2(1));
 vec4 original = texelFetch(TEXTURE, texel, 0);
 COLOR = vec4(original.rgb, step(0.5, original.a)) * vertex_tint;
}
