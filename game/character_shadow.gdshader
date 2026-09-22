shader_type canvas_item;
render_mode unshaded;

uniform bool contact_only = false;
varying float height_above_ground;

void vertex() {
 height_above_ground = -VERTEX.y;
 if (contact_only) {
  // Keep each sole's own outline, just below the intact boot drawing.
  VERTEX.y += 0.45;
 } else {
  // The sun is upper-left in this farm. Facing only mirrors the figure,
  // never the world-space light direction (the renderer supplies it below).
  VERTEX.y = height_above_ground * 0.24;
 }
}

void fragment() {
 vec2 fx = dFdx(UV)*(contact_only ? 1.0 : 1.8);
 vec2 fy = dFdy(UV)*(contact_only ? 1.0 : 1.8);
 float alpha = 0.0;
 for (int y=0; y<4; y++) {
  for (int x=0; x<4; x++) {
   vec2 tap = (vec2(float(x),float(y))+0.5)/4.0-0.5;
   vec4 sample_color = texture(TEXTURE,UV+tap.x*fx+tap.y*fy);
   bool key = min(sample_color.r,sample_color.b)-sample_color.g>0.23 && sample_color.r>0.35 && sample_color.b>0.35;
   alpha += key ? 0.0 : sample_color.a;
  }
 }
 alpha /= 16.0;
 float strength = contact_only ? (1.0-smoothstep(0.0,2.5,height_above_ground))*0.42 : mix(0.28,0.16,smoothstep(0.0,34.0,height_above_ground));
 COLOR = vec4(0.18,0.23,0.12,alpha*strength);
}
