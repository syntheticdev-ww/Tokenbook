extends SceneTree

const Gait = preload("gait.gd")
const Character = preload("character.gd")
const WALK_FRAMES := 189
const CLOSE_FRAMES := 36
const HOLD_FRAMES := 45
class InputRelay extends Node:
 signal key_pressed(event: InputEventKey)
 func _unhandled_key_input(event: InputEvent) -> void:
  if event is InputEventKey: key_pressed.emit(event)

var actors: Array[Node3D] = []
var floors: Array[Node3D] = []
var views: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var shadows: Array[Node3D] = []
var phase := 0.0
var playback_paused := false
var slow := false
var pixel_preview := false
var stop_at := INF
var closing := -1.0
var status := Label.new()
var capture_dir := ""
var sprite_export := false
var capture_frame := -8
var capturing := false
var frame_times: Array[float] = []
var elapsed := 0.0

func _initialize() -> void:
 Engine.max_fps=60
 root.title="Tokenbook · 骨架步态小样（非最终美术）"
 root.size=Vector2i(1080,680)
 var args := OS.get_cmdline_user_args()
 if args.size()==2 and args[0] in ["--capture","--sprites"]:
  capture_dir=args[1]
  sprite_export=args[0]=="--sprites"
  if not capture_dir.is_absolute_path() or DirAccess.dir_exists_absolute(capture_dir):
   printerr("Capture requires a new absolute output directory; existing outputs are never overwritten.")
   quit(2)
   return
  DirAccess.make_dir_recursive_absolute(capture_dir if sprite_export else capture_dir.path_join("frames"))
 elif args.size()>0:
  printerr("Usage: preview.gd [-- --capture NEW_ABSOLUTE_DIR | -- --sprites NEW_ABSOLUTE_DIR]")
  quit(2)
  return
 if capture_dir.is_empty():
  root.content_scale_size=Vector2i(1080,680)
  root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
  root.size=Vector2i(1620,1020)
 build.call_deferred()

func build() -> void:
 var input := InputRelay.new()
 root.add_child(input)
 input.key_pressed.connect(_input)
 var ui := Control.new()
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.add_child(ui)
 var theme := Theme.new()
 var font_file := FontFile.new()
 # Reuse the repository's licensed font bytes without importing/copying assets
 # into the isolated project or relying on protected macOS system font paths.
 font_file.data=FileAccess.get_file_as_bytes(ProjectSettings.globalize_path("res://../../game/assets/fonts/NotoSansSC.ttf"))
 var font := FontVariation.new()
 font.base_font=font_file
 font.variation_opentype={0x77676874:400.0}
 theme.default_font=font
 theme.default_font_size=15
 ui.theme=theme
 var bg := ColorRect.new()
 bg.color=Color("eeeadd")
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.add_child(bg)
 label(ui,"TOKENBOOK  /  MOTION STUDY",Vector2(34,22),19,Color("42644f"))
 label(ui,"只看动作：统一骨架 · 连续蒙皮 · 60 FPS",Vector2(34,55),24,Color("2c4336"))
 label(ui,"简化角色用于检查步态，不代表最终像素美术；原游戏未替换。",Vector2(34,94),15,Color("6c776a"))
 var names := {"front":"正侧面","side":"侧面","back":"背面"}
 var camera_positions := preview_camera_positions()
 for i in range(camera_positions.size()):
  var x := 34+i*348 if camera_positions.size()==3 else 118+i*524
  var card := Panel.new()
  var style := StyleBoxFlat.new()
  style.bg_color=Color("e0e5d5")
  style.set_corner_radius_all(10)
  card.add_theme_stylebox_override("panel",style)
  card.position=Vector2(x,139)
  card.size=Vector2(320,440)
  ui.add_child(card)
  label(ui,"%02d  %s" % [i+1,names[preview_view_names()[i]]],Vector2(x+16,153),17,Color("42644f"))
  var viewport := SubViewport.new()
  viewport.size=sprite_size() if sprite_export else Vector2i(320,400)
  viewport.msaa_3d=Viewport.MSAA_4X
  viewport.own_world_3d=true
  viewport.transparent_bg=true
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(viewport)
  views.append(viewport)
  var display := TextureRect.new()
  display.texture=viewport.get_texture()
  display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  display.position=Vector2(x,180)
  display.size=Vector2(320,400)
  ui.add_child(display)
  var stage := Node3D.new()
  viewport.add_child(stage)
  var camera := Camera3D.new()
  camera.projection=Camera3D.PROJECTION_ORTHOGONAL
  camera.size=2.05
  camera.position=camera_positions[i]
  stage.add_child(camera)
  camera.look_at(Vector3(0,.77,0))
  cameras.append(camera)
  var actor := create_character()
  stage.add_child(actor)
  if actor.has_method("set_camera"): actor.set_camera(camera)
  actors.append(actor)
  var floor_node := Node3D.new()
  stage.add_child(floor_node)
  floors.append(floor_node)
  for z in range(-14,15):
   for x_index in range(-4,5):
    var tile := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size=Vector2(.254,.254)
    tile.mesh=plane
    tile.position=Vector3(x_index*.26,-.015,z*.26)
    tile.material_override=material(Color("cbd7bf") if posmod(x_index+z,2)==0 else Color("d4dec9"))
    floor_node.add_child(tile)
  var shadow := MeshInstance3D.new()
  var disk := CylinderMesh.new()
  disk.top_radius=.22
  disk.bottom_radius=.22
  disk.height=.001
  shadow.mesh=disk
  shadow.scale=Vector3(1,1,.65)
  shadow.material_override=material(Color(.24,.33,.24,.18))
  shadow.position.y=-.011
  stage.add_child(shadow)
  shadows.append(shadow)
  if sprite_export:
   floor_node.hide()
   shadow.hide()
 ui.add_child(status)
 status.position=Vector2(34,594)
 status.add_theme_color_override("font_color",Color("42644f"))
 label(ui,"空格 暂停   ·   S 慢放   ·   Enter 收步   ·   R 重播   ·   P 像素采样   ·   ← / → 单帧   ·   Esc 关闭",Vector2(34,635),14,Color("63715f"))
 render_pose(Gait.sample(0))
 if not capture_dir.is_empty(): RenderingServer.frame_post_draw.connect(capture_after_draw)

func label(parent: Node, value: String, at: Vector2, size: int, color: Color) -> void:
 var node := Label.new()
 node.text=value
 node.position=at
 node.add_theme_font_size_override("font_size",size)
 node.add_theme_color_override("font_color",color)
 parent.add_child(node)

func create_character() -> Node3D:
 return Character.new()

func preview_camera_positions() -> Array[Vector3]:
 return [Vector3(3,2.1,5),Vector3(6,1.7,0),Vector3(-3,2.1,-5)]

func preview_view_names() -> Array[String]: return ["front","side","back"]

func sprite_size() -> Vector2i: return Vector2i(128,160)

func material(color: Color) -> StandardMaterial3D:
 var result := StandardMaterial3D.new()
 result.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 result.albedo_color=color
 if color.a<1: result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 return result

func _process(delta: float) -> bool:
 if actors.is_empty(): return false
 elapsed+=delta
 if not capture_dir.is_empty():
  if capture_frame<0: render_pose(Gait.sample(0))
  elif sprite_export:
   if capture_frame<63: render_pose(Gait.sample(capture_frame/63.0))
   else:
    closing=minf(1.0,(capture_frame-63)/float(CLOSE_FRAMES))
    render_pose(Gait.settle(1.0,closing))
  elif capture_frame<WALK_FRAMES:
   render_pose(Gait.sample(capture_frame/(60.0*Gait.PERIOD)))
  else:
   phase=3.0
   closing=minf(1.0,(capture_frame-WALK_FRAMES)/float(CLOSE_FRAMES))
   render_pose(Gait.settle(phase,closing))
  return false
 if elapsed>2 and frame_times.size()<1800: frame_times.append(delta*1000)
 if not playback_paused:
  var step := minf(delta,.1)*(1.0/3 if slow else 1.0)
  if closing>=0: closing=minf(1,closing+step/Gait.SETTLE_PERIOD)
  else:
   phase+=step/Gait.PERIOD
   if phase>=stop_at:
    closing=(phase-stop_at)*Gait.PERIOD/Gait.SETTLE_PERIOD
    phase=stop_at
 render_pose(Gait.settle(phase,closing) if closing>=0 else Gait.sample(phase))
 return false

func render_pose(pose: Dictionary) -> void:
 for actor in actors: actor.apply_pose(pose)
 for floor_node in floors: floor_node.position.z=-fposmod(pose.root.z,.52)
 status.text="%s  |  %s  |  步态相位 %02d / 63" % ["暂停" if playback_paused else ("站定" if closing==1 else ("收步" if closing>=0 else "行走")),"1/3 速度" if slow else "正常速度",int(fposmod(pose.cycle,1)*63)+1]

func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 # The export clock must not be changed by accidental keyboard events.
 if not capture_dir.is_empty(): return
 match event.keycode:
  KEY_ESCAPE:
   report_performance()
   quit()
  KEY_SPACE: playback_paused=not playback_paused
  KEY_S: slow=not slow
  KEY_P:
   pixel_preview=not pixel_preview
   for viewport in views: viewport.size=Vector2i(160,200) if pixel_preview else Vector2i(320,400)
  KEY_ENTER:
   if closing<0: stop_at=(floorf(phase*2)+1)*.5
  KEY_R:
   phase=0
   closing=-1
   stop_at=INF
   playback_paused=false
  KEY_LEFT,KEY_RIGHT:
   playback_paused=true
   var direction := -1.0 if event.keycode==KEY_LEFT else 1.0
   if closing>=0: closing=clampf(closing+direction/(60*Gait.SETTLE_PERIOD),0,1)
   else:
    stop_at=INF
    phase+=direction/(60*Gait.PERIOD)

func capture_after_draw() -> void:
 if capturing: return
 capturing=true
 if capture_frame>=0:
  if sprite_export:
   for i in range(views.size()):
    var folder := capture_dir.path_join(preview_view_names()[i])
    DirAccess.make_dir_recursive_absolute(folder)
    var name := "walk-%03d.png" % capture_frame if capture_frame<63 else "stop-%03d.png" % (capture_frame-63)
    views[i].get_texture().get_image().save_png(folder.path_join(name))
  else:
   root.get_texture().get_image().save_png(capture_dir.path_join("frames/%04d.png" % capture_frame))
  if not sprite_export and capture_frame<63:
   for i in range(views.size()):
    var folder := capture_dir.path_join(preview_view_names()[i])
    DirAccess.make_dir_recursive_absolute(folder)
    views[i].get_texture().get_image().save_png(folder.path_join("%03d.png" % capture_frame))
 capture_frame+=1
 if capture_frame>=(100 if sprite_export else WALK_FRAMES+CLOSE_FRAMES+HOLD_FRAMES):
  var file := FileAccess.open(capture_dir.path_join("capture.json"),FileAccess.WRITE)
  var actual_size := root.get_texture().get_image().get_size()
  var data := {"purpose":"motion/art candidate, not installed in game","fps":60,"frames":capture_frame,"cycle_frames":63,"walk_frames":WALK_FRAMES,"closing_frames":CLOSE_FRAMES,"size":[actual_size.x,actual_size.y],"three_views":views.size()==3,"views":preview_view_names()}
  if sprite_export:
   data["size"]=[sprite_size().x,sprite_size().y]
   data["walk_frames"]=63
   data["closing_frames"]=37
   data["transparent"]=true
   data["loop_endpoint_duplicate"]=false
   data["anchors"]={}
   data["stride_pixels"]={}
   data["stop_advance_cycles"]=[]
   for i in range(37): data.stop_advance_cycles.append(Gait.settle(0,i/36.0).root.z/Gait.STRIDE)
   for i in range(cameras.size()):
    var anchor := cameras[i].unproject_position(Vector3.ZERO)
    data.anchors[preview_view_names()[i]]=[anchor.x,anchor.y]
    var stride := cameras[i].unproject_position(Vector3(0,0,Gait.STRIDE))-anchor
    data.stride_pixels[preview_view_names()[i]]=[stride.x,stride.y]
  file.store_string(JSON.stringify(data,"  "))
  print("Motion capture complete: ",capture_dir," (",capture_frame," frames)")
  RenderingServer.frame_post_draw.disconnect(capture_after_draw)
  quit()
  return
 capturing=false

func report_performance() -> void:
 if frame_times.is_empty(): return
 frame_times.sort()
 print("Live render timings (PNG export excluded): median=",frame_times[frame_times.size()/2],"ms; p95=",frame_times[int(frame_times.size()*.95)],"ms; samples=",frame_times.size())
