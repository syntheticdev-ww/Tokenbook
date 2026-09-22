shader_type canvas_item;
render_mode unshaded;

// An explicit world clock keeps UI rebuilds and deterministic replays in sync.
// This material belongs only to the background, never to actors or farmland.
uniform float world_time = 0.0;
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_size = vec2(384.0,342.0);
uniform vec2 pixel_grid_zoom = vec2(0.0);
uniform vec2 pixel_grid_offset = vec2(0.0);
uniform bool crisp_pixel_motion = false;

float crown(vec2 p, vec4 area) {
 float distance_from_center = length((p-area.xy)/area.zw);
 float edge = 1.0-smoothstep(0.68,1.0,distance_from_center);
 float anchored = clamp((area.y+area.w-p.y)/(area.w*1.65),0.0,1.0);
 return edge*anchored;
}

vec4 covered_sample(sampler2D source_texture, vec2 texel, vec2 uv) {
 // Smooth subpixel movement without nearest-neighbour one-pixel jumps.
 // Unaffected architecture returns its original nearest sample unchanged.
 vec2 pixel = uv/texel-0.5;
 vec2 cell = floor(pixel);
 vec2 blend = fract(pixel);
 vec2 origin = (cell+0.5)*texel;
 vec4 top = mix(texture(source_texture,origin),texture(source_texture,origin+vec2(texel.x,0.0)),blend.x);
 vec4 bottom = mix(texture(source_texture,origin+vec2(0.0,texel.y)),texture(source_texture,origin+texel),blend.x);
 return mix(top,bottom,blend.y);
}

void fragment() {
 vec2 uv = UV;
 if (pixel_grid_zoom.x > 0.0 && pixel_grid_zoom.y > 0.0) {
  // The caller supplies physical-pixel density in the landscape view.
  vec2 screen = (uv*world_size+world_origin)*pixel_grid_zoom+pixel_grid_offset;
  vec2 world = (floor(screen)+vec2(0.5)-pixel_grid_offset)/pixel_grid_zoom;
  uv = (world-world_origin)/world_size;
 }
 vec2 p = uv*world_size+world_origin;
 vec4 base = texture(TEXTURE,uv);
 float foliage_color = smoothstep(0.015,0.08,base.g-base.b)*smoothstep(-0.025,0.035,base.g-base.r);
 float trees = max(crown(p,vec4(12.0,96.0,38.0,56.0)),crown(p,vec4(54.0,105.0,24.0,23.0)));
 trees = max(trees,crown(p,vec4(190.0,94.0,26.0,25.0)));
 trees = max(trees,crown(p,vec4(295.0,20.0,42.0,26.0)));
 trees = max(trees,crown(p,vec4(359.0,26.0,31.0,32.0)));
 trees = max(trees,crown(p,vec4(381.0,137.0,19.0,32.0)));
 float grass = max(crown(p,vec4(12.0,201.0,20.0,27.0)),crown(p,vec4(24.0,280.0,25.0,23.0)));
 grass = max(grass,crown(p,vec4(58.0,325.0,24.0,19.0)));
 grass = max(grass,crown(p,vec4(361.0,204.0,24.0,28.0)));
 grass = max(grass,crown(p,vec4(369.0,277.0,20.0,32.0)));
 grass = max(grass,crown(p,vec4(283.0,331.0,33.0,15.0)));
 // Leave all house walls/roof/tool silhouettes rigid, including green trim.
 if (p.x>210.0 && p.x<376.0 && p.y>38.0 && p.y<169.0) { trees=0.0; grass=0.0; }
 // Coherent branches, not only isolated green pixels sliding inside them.
 // Crown masks anchor trunks and keep buildings outside the wind pass.
 float foliage_weight = mix(0.35,1.0,foliage_color);
 float vegetation = max(trees,grass)*foliage_weight;
 float river_area = (1.0-smoothstep(0.75,1.0,length((p-vec2(98.0,118.0))/vec2(79.0,23.0))))*smoothstep(101.0,105.0,p.y);
 float water = river_area*smoothstep(0.03,0.11,base.b-base.r)*smoothstep(-0.08,0.02,base.b-base.g);
 float wind = sin(world_time*1.25+p.x*0.043)+0.32*sin(world_time*0.71+p.y*0.065);
 vec2 offset = vec2(wind*(trees*1.65+grass*1.45)*foliage_weight,0.24*grass*foliage_weight*sin(world_time*1.4+p.x*0.1));
 offset += water*vec2(0.95*sin(p.y*0.87-world_time*1.65),0.22*sin(p.x*0.36+world_time*1.2));
 float amount = max(vegetation,water);
 if (amount>0.001) {
  float influence = smoothstep(0.0,0.18,amount);
  if (crisp_pixel_motion) {
   // Move the sampling position rather than blending neighboring colors.
   // Each leaf/grass pixel keeps one authored color, even while it sways.
   ivec2 extent = textureSize(TEXTURE,0);
   vec2 displaced_uv = uv+offset*influence/world_size;
   ivec2 texel = clamp(ivec2(floor(displaced_uv*vec2(extent))),ivec2(0),extent-ivec2(1));
   base = texelFetch(TEXTURE,texel,0);
  } else {
   vec4 moving = covered_sample(TEXTURE,TEXTURE_PIXEL_SIZE,uv+offset/world_size);
   base = mix(base,moving,influence);
  }
  float ripple = pow(max(0.0,sin(p.y*2.4+p.x*0.18-world_time*1.4)),10.0);
  base.rgb += water*ripple*vec3(0.065,0.085,0.080);
 }
 COLOR=base;
}
