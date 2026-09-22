extends "character.gd"

const PaintedMesh = preload("painted_mesh.gd")
static var painted_mesh: ArrayMesh
static var painted_material: ShaderMaterial

func _init() -> void:
 super._init()
 if painted_mesh==null:
  painted_mesh=PaintedMesh.new().build(rest,ids)
  var paint_image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/character-paint-v1.png"))
  paint_image.generate_mipmaps()
  painted_material=ShaderMaterial.new()
  var shader := Shader.new()
  shader.code="""shader_type spatial;
render_mode unshaded;
uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_disable;
varying float bare_arm;
void vertex() { bare_arm = 1.0-step(0.05,COLOR.r); }
vec3 arm_paint(vec3 colour, vec3 skin) {
 float warm_skin = step(0.3,colour.g)*step(colour.g*1.05,colour.r)*step(colour.r,colour.g*1.65)*step(colour.g,colour.b*2.4);
 return mix(skin,mix(skin,colour,0.4),warm_skin);
}
void fragment() {
 vec4 front = textureLod(paint, UV, 2.0);
 vec4 rear = textureLod(paint, UV2, 2.0);
 vec3 skin = textureLod(paint, vec2(451.0/1562.0,314.0/1007.0),2.0).rgb;
 vec3 fallback = mix(COLOR.rgb,skin,bare_arm);
 vec3 a = mix(fallback, front.rgb, smoothstep(0.72,0.98,front.a));
 vec3 b = mix(fallback, rear.rgb, smoothstep(0.72,0.98,rear.a));
 a=mix(a,arm_paint(a,skin),bare_arm);
 b=mix(b,arm_paint(b,skin),bare_arm);
 ALBEDO = mix(b,a,COLOR.a);
}
"""
  painted_material.shader=shader
  painted_material.set_shader_parameter("paint",ImageTexture.create_from_image(paint_image))
  var outline := ShaderMaterial.new()
  var outline_shader := Shader.new()
  outline_shader.code="""shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 ink : source_color = vec4(0.29,0.19,0.12,1.0);
void vertex() { VERTEX += NORMAL*0.01; }
void fragment() { ALBEDO = ink.rgb; }
"""
  outline.shader=outline_shader
  painted_material.next_pass=outline
 body.mesh=painted_mesh
 body.material_override=painted_material
 # This is one fixed model proportion, not a per-frame stretch. Forward travel
 # remains +Z, so the exported ground stride is unchanged by the X adjustment.
 scale.x=1.18
 # Facial features and buttons are now painted on the single skinned surface,
 # not separately installed shapes hovering over the face/clothes.
 for child in skeleton.get_children():
  if child is BoneAttachment3D: child.free()
