shader_type canvas_item;
render_mode unshaded;

// A character-space pixel grid, anchored at the feet. All poses share the
// same texel size and palette, instead of shrinking illustration gradients
// into a smooth, differently coloured miniature on every frame.
uniform vec2 source_anchor = vec2(600.0, 1120.0);
uniform vec2 source_step = vec2(14.8030303);
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }

const vec3 PALETTE[36] = vec3[36](
 vec3(48,54,43), vec3(75,64,48), vec3(102,80,56),
 vec3(117,85,55), vec3(146,99,52), vec3(177,123,62),
 vec3(206,155,81), vec3(225,181,109), vec3(239,212,153),
 vec3(163,117,81), vec3(193,144,100), vec3(222,176,132),
 vec3(239,208,156), vec3(243,223,183), vec3(213,158,112),
 vec3(41,77,69), vec3(61,103,85), vec3(89,133,106),
 vec3(123,160,130), vec3(164,183,145),
 vec3(91,87,66), vec3(121,112,87), vec3(157,138,99),
 vec3(182,164,124), vec3(213,198,155),
 vec3(77,64,49), vec3(107,80,55), vec3(146,105,71),
 vec3(180,134,85), vec3(204,170,118),
 vec3(47,85,88), vec3(69,121,118), vec3(104,161,155),
 vec3(141,181,163), vec3(245,235,202), vec3(54,43,35)
);

vec4 clear_key(sampler2D tex, vec2 at) {
 vec4 c = texture(tex, at);
 if (min(c.r,c.b)-c.g > 0.23 && c.r > 0.35 && c.b > 0.35) return vec4(0.0);
 return vec4(c.rgb*c.a,c.a);
}

void fragment() {
 vec2 source = UV / TEXTURE_PIXEL_SIZE;
 vec2 cell = floor((source-source_anchor)/source_step);
 vec2 center = source_anchor+(cell+vec2(0.5))*source_step;
 vec4 covered = vec4(0.0);
 // Spatial integration within one art pixel prevents a single noisy source
 // speck from changing its colour; never blends neighbouring animation cels.
 for (int y=0; y<5; y++) {
  for (int x=0; x<5; x++) {
   vec2 offset=(vec2(float(x),float(y))+vec2(0.5))/5.0-vec2(0.5);
   covered+=clear_key(TEXTURE,(center+offset*source_step)*TEXTURE_PIXEL_SIZE);
  }
 }
 covered/=25.0;
 vec3 color=covered.rgb/max(covered.a,0.00001);
 float best=1000.0;
 vec3 chosen=PALETTE[0]/255.0;
 for (int i=0; i<36; i++) {
  vec3 candidate=PALETTE[i]/255.0;
  vec3 delta=color-candidate;
  float distance=dot(delta*delta,vec3(1.0,1.35,0.85));
  if (distance<best) { best=distance; chosen=candidate; }
 }
 COLOR=vec4(chosen,step(0.45,covered.a))*vertex_tint;
}
