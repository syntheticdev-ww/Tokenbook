extends SceneTree

# Offline geometric pose reference for the artist/image tool, never game art.
const Gait = preload("gait.gd")
var viewport: SubViewport
var output := ""
var ticks := 0

class Guides extends Node2D:
 const Motion = preload("gait.gd")
 func projected(p: Vector3) -> Vector2:
  return Vector2((p.x-p.z)*.78,-p.y+(p.x+p.z)*.25)*210
 func limb(joints: Dictionary,side: String,part: String,color: Color,width: float) -> void:
  var points := ["shoulder","elbow","wrist"] if part=="arm" else ["hip","knee","ankle"]
  for i in range(2):
   draw_line(projected(joints[side+"_"+points[i]]),projected(joints[side+"_"+points[i+1]]),color,width,true)
  for joint in points: draw_circle(projected(joints[side+"_"+joint]),width*.5,color)
  if part=="leg":
   draw_line(projected(joints[side+"_ankle"]),projected(joints[side+"_toe"]),Color("785333"),24,true)
 func _draw() -> void:
  draw_rect(Rect2(0,0,1536,1024),Color("ff00ff"))
  for i in range(8):
   draw_set_transform(Vector2((i%4)*384+192,int(i/4)*512+443))
   var joints: Dictionary = Motion.sample(.5+i/8.0).joints
   # Far limbs are blue, near limbs orange: unambiguous opposite swing.
   limb(joints,"left","arm",Color("668aac"),23)
   limb(joints,"left","leg",Color("668aac"),26)
   limb(joints,"right","leg",Color("f0b57c"),27)
   var torso := PackedVector2Array([
    projected(joints.left_shoulder),projected(joints.right_shoulder),
    projected(joints.right_hip+Vector3(.02,-.01,0)),projected(joints.left_hip+Vector3(-.02,-.01,0))])
   draw_colored_polygon(torso,Color("428e83"))
   var hip: Vector2 = projected(joints.pelvis)
   draw_rect(Rect2(hip+Vector2(-26,-6),Vector2(52,29)),Color("c7ad79"))
   limb(joints,"right","arm",Color("f0b57c"),24)
   var head: Vector2 = projected(joints.head+Vector3(0,.045,0))
   draw_circle(head,49,Color("9d623e"))
   draw_circle(head+Vector2(-8,8),35,Color("efc18b"))
   draw_circle(head+Vector2(-23,7),3,Color("48362b"))
   draw_circle(head+Vector2(-2,9),3,Color("48362b"))
  draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 if args.size()!=1 or not args[0].is_absolute_path() or FileAccess.file_exists(args[0]):
  printerr("Supply one new absolute PNG output path")
  quit(2); return
 output=args[0]
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 build.call_deferred()

func build() -> void:
 root.title="Tokenbook · 离屏姿态参考制作"
 root.size=Vector2i(384,160)
 viewport=SubViewport.new()
 viewport.size=Vector2i(1536,1024)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 viewport.add_child(Guides.new())
 RenderingServer.frame_post_draw.connect(capture)

func capture() -> void:
 ticks+=1
 if ticks<3: return
 RenderingServer.frame_post_draw.disconnect(capture)
 var image := viewport.get_texture().get_image()
 var result := image.save_png(output)
 print("Pose guide: ",output," / ",image.get_size())
 quit(0 if result==OK else 1)
