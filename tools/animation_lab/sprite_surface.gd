extends Node3D

# Asset-production surface, not a runtime game renderer. One connected painted
# grid follows the existing gait; pixels/UVs are never regenerated per pose.
const Gait = preload("gait.gd")
const SCALE := .00165
const HEAD_SCALE := .00205
const STEP := 6
var paint := Image.load_from_file(ProjectSettings.globalize_path("res://assets/character-paint-v1.png"))
var mesh := ArrayMesh.new()
var body := MeshInstance3D.new()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()
var sources: Array[Vector2] = []
var bindings: Array = []
var controls: Array[Dictionary] = []
var right := Vector3.RIGHT
var up := Vector3.UP
var normal := Vector3.BACK
var rear := false
var ready_surface := false

func _init() -> void:
 body.mesh=mesh
 body.custom_aabb=AABB(Vector3(-1,-.2,-1),Vector3(2,2.2,2))
 add_child(body)
 var shader := Shader.new()
 shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D paint : source_color, filter_linear, repeat_disable;
void fragment() {
 vec4 pigment=texture(paint,UV);
 ALBEDO=pigment.rgb;
 ALPHA=pigment.a;
 ALPHA_SCISSOR_THRESHOLD=0.6;
}
"""
 var material := ShaderMaterial.new()
 material.shader=shader
 material.set_shader_parameter("paint",ImageTexture.create_from_image(paint))
 body.material_override=material

func set_camera(camera: Camera3D) -> void:
 right=camera.global_basis.x.normalized()
 up=camera.global_basis.y.normalized()
 normal=camera.global_basis.z.normalized()
 rear=camera.position.z<0
 controls=[
  control(Vector2(459,524),Vector2(459,357),"pelvis","chest",85),
  control(Vector2(459,357),Vector2(459,296),"chest","neck",36),
  control(Vector2(351,341),Vector2(303,471),"left_shoulder","left_elbow",34),
  control(Vector2(303,471),Vector2(239,587),"left_elbow","left_wrist",25),
  control(Vector2(567,341),Vector2(615,471),"right_shoulder","right_elbow",34),
  control(Vector2(615,471),Vector2(679,587),"right_elbow","right_wrist",25),
  control(Vector2(403,524),Vector2(363,710),"left_hip","left_knee",45),
  control(Vector2(363,710),Vector2(337,910),"left_knee","left_ankle",29),
  control(Vector2(515,524),Vector2(549,710),"right_hip","right_knee",45),
  control(Vector2(549,710),Vector2(581,910),"right_knee","right_ankle",29)]
 build_grid()
 ready_surface=true
 apply_pose(Gait.standing())

func control(a: Vector2,b: Vector2,from: String,to: String,radius: float) -> Dictionary:
 return {"a":a,"b":b,"from":from,"to":to,"radius":radius}

func paint_point(source: Vector2) -> Vector2:
 return source+Vector2(641 if rear else 0,0)

func pigment(source: Vector2) -> Color:
 var point := Vector2i(paint_point(source))
 return paint.get_pixelv(point.clamp(Vector2i.ZERO,paint.get_size()-Vector2i.ONE))

func build_grid() -> void:
 sources.clear()
 bindings.clear()
 uvs.clear()
 indices.clear()
 var used := {}
 for y in range(16,970,STEP):
  for x in range(205,715,STEP):
   var corners := [Vector2(x,y),Vector2(x+STEP,y),Vector2(x,y+STEP),Vector2(x+STEP,y+STEP)]
   # Keep the complete connected panel. Sampling only corners/centre to cull
   # cells deleted narrow painted strands between samples and dotted the edge.
   var cell: Array[int] = []
   for point in corners:
    if not used.has(point):
     used[point]=sources.size()
     sources.append(point)
     bindings.append(bind_source(point))
     uvs.append(paint_point(point)/Vector2(paint.get_size()))
    cell.append(used[point])
   for index in [cell[0],cell[2],cell[1],cell[1],cell[2],cell[3]]: indices.append(index)

func bind_source(p: Vector2) -> Array:
 # Masks are smooth spatial fields, including transparent edge vertices.
 # Classifying individual vertices by paint colour pulled dark/light strands
 # toward different bones, while a hard ankle cutoff made a visible seam.
 var head_weight := maxf(1-smoothstep(294,334,p.y),smoothstep(548,578,p.x)*(1-smoothstep(352,386,p.y)))
 var foot_weight := smoothstep(790,860,p.y)
 var pouch_weight := pouch_mask(p)
 if head_weight>=1: return [{"kind":"head","weight":1.0,"p":p}]
 if foot_weight>=1: return [{"kind":"foot","weight":1.0,"p":p,"leg":0 if p.x<459 else 1}]
 if pouch_weight>=1: return [{"kind":"pouch","weight":1.0,"p":p}]
 var candidates: Array[Dictionary] = []
 for i in range(controls.size()):
  var c := controls[i]
  var ab: Vector2 = c.b-c.a
  var t: float = (p-c.a).dot(ab)/ab.length_squared()
  var distance: float = p.distance_to(c.a+ab*clampf(t,0,1))-c.radius
  var axis := Vector2(ab.x,-ab.y).normalized()
  var local := Vector2(p.x-c.a.x,-(p.y-c.a.y))
  candidates.append({"kind":"body","control":i,"t":t,"across":local.dot(Vector2(-axis.y,axis.x)),"distance":distance})
 candidates.sort_custom(func(a: Dictionary,b: Dictionary): return a.distance<b.distance)
 var selected: Array = candidates.slice(0,4)
 var total := 0.0
 for entry in selected:
  entry.weight=exp(-(entry.distance-selected[0].distance)/9)
  total+=entry.weight
 for entry in selected: entry.weight=entry.weight/total*(1-head_weight)*(1-foot_weight)*(1-pouch_weight)
 if head_weight>0: selected.append({"kind":"head","weight":head_weight,"p":p})
 if foot_weight>0: selected.append({"kind":"foot","weight":foot_weight,"p":p,"leg":0 if p.x<459 else 1})
 if pouch_weight>0: selected.append({"kind":"pouch","weight":pouch_weight,"p":p})
 return selected

func pouch_mask(p: Vector2) -> float:
 # The old rectangular mask also contained forearm skin. Follow the painted
 # accessory silhouette instead, with a soft spatial seam into the shorts.
 # Do not classify by pixel colour: that splits antialiased edge vertices.
 var outline := PackedVector2Array([Vector2(518,490),Vector2(576,482),Vector2(591,511),Vector2(595,553),Vector2(561,577),Vector2(533,565)])
 # The back drawing is narrower here; reusing the front silhouette catches
 # its forearm edge even though the main body landmarks are shared.
 if rear:
  outline=PackedVector2Array([Vector2(517,494),Vector2(558,490),Vector2(570,514),Vector2(580,560),Vector2(557,580),Vector2(534,568)])
 var distance := INF
 for i in range(outline.size()):
  var a := outline[i]
  var b := outline[(i+1)%outline.size()]
  distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)))
 if Geometry2D.is_point_in_polygon(p,outline): distance=-distance
 return 1-smoothstep(-4,6,distance)

func transforms_for(pose: Dictionary) -> Array:
 var result: Array = []
 for c in controls:
  var a: Vector3 = pose.joints[c.from]
  var along: Vector3 = pose.joints[c.to]-a
  # All painted widths belong to the character's physical XY plane, not a
  # camera-facing billboard unrelated to the +Z-forward walk direction.
  var across := Vector3(-along.y,along.x,0).normalized()*SCALE
  result.append({"a":a,"along":along,"across":across})
 return result

func bound_point(binding: Array,pose: Dictionary,transforms: Array) -> Vector3:
 var point := Vector3.ZERO
 var facing := Vector3.FORWARD if rear else Vector3.BACK
 for entry in binding:
  var value: Vector3
  if entry.kind=="head":
   # Enlarge about the painted neck landmark, so restoring the compact head
   # proportion cannot detach the head from the neck or move the pivot.
   value=pose.joints.head+Vector3.UP*(220-294)*SCALE+Vector3.RIGHT*(entry.p.x-459)*HEAD_SCALE+Vector3.UP*(294-entry.p.y)*HEAD_SCALE+facing*.12
  elif entry.kind=="foot":
   var foot: Dictionary = pose.feet[entry.leg]
   var source_x := 337 if entry.leg==0 else 581
   value=foot.ground+Vector3.UP*foot.lift+Vector3.RIGHT*(entry.p.x-source_x)*SCALE+Vector3.UP*(949-entry.p.y)*SCALE
  elif entry.kind=="pouch":
   var local := Vector3((entry.p.x-459)*SCALE,(524-entry.p.y)*SCALE,0)+facing*.055
   value=pose.joints.pelvis+Basis(Vector3.UP,pose.hip_yaw)*local
  else:
   var chart: Dictionary = transforms[entry.control]
   value=chart.a+chart.along*entry.t+chart.across*entry.across
  point+=value*entry.weight
 return point

func source_to_world(source: Vector2,pose: Dictionary) -> Vector3:
 return bound_point(bind_source(source),pose,transforms_for(pose))

func vertices_for(pose: Dictionary) -> PackedVector3Array:
 var result := PackedVector3Array()
 result.resize(bindings.size())
 var transforms := transforms_for(pose)
 for i in range(bindings.size()): result[i]=bound_point(bindings[i],pose,transforms)
 return result

func apply_pose(pose: Dictionary) -> void:
 if not ready_surface: return
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices_for(pose)
 arrays[Mesh.ARRAY_TEX_UV]=uvs
 arrays[Mesh.ARRAY_INDEX]=indices
 mesh.clear_surfaces()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
