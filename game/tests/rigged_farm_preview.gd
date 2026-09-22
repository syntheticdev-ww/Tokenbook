extends SceneTree

# Read-only visual fixture: no SaveStore, bridge, tasks or production entrypoint.
const Frames = preload("rigged_sprite_frames.gd")
const Rules = preload("res://farm_rules.gd")
const Art = preload("res://pixel_art.gd")
const Walk = preload("res://walk_art.gd")
var frames := Frames.new()
var farm: CandidateFarm
var zooms: Array[PoseZoom] = []
var label_status := Label.new()
var elapsed := 0.0
var playback_paused := false
var slow := false
var rear := false
var capture_dir := ""
var capture_frame := -8
var capturing := false

class InputRelay extends Node:
 signal key_pressed(key: InputEventKey)
 func _unhandled_key_input(event: InputEvent) -> void:
  if event is InputEventKey: key_pressed.emit(event)

class Reference extends RefCounted:
 static func sprite(packet: Dictionary, seconds: float) -> Dictionary:
  if packet.kind=="walk": return Walk.frame_at(fposmod(seconds/1.05,1)*16,packet.back)
  # The old idle atlas is front-only. Keep the direction-matched closing
  # drawing here so this comparison never invents a sudden turn at rest.
  return Walk.settle_frame(packet.progress if packet.kind=="settle" else 1.0,packet.back)

class CandidateFarm extends "res://farm_view.gd":
 var packet := {}
 var candidate := true
 var animation_time := 0.0
 func actor_position() -> Vector2:
  return Vector2(198,167) if packet.is_empty() else (Vector2(198,167) if packet.back else Vector2(220,156))+packet.offset
 func actor_draw_position() -> Vector2: return actor_position()
 func walk_phase() -> float: return fposmod(animation_time/1.05,1)*16
 func visual_pose() -> Dictionary: return packet
 func actor_sprite() -> Dictionary:
  return Reference.sprite(packet,animation_time)
 func _paint_actor(canvas: CanvasItem) -> void:
  if packet.is_empty(): return
  if not candidate:
   super._paint_actor(canvas)
   return
  var factor := 1 if compact else render_scale
  canvas.draw_set_transform(view_offset()+actor_position()*factor,0,Vector2.ONE*factor)
  canvas.draw_colored_polygon(PackedVector2Array([Vector2(-4,-1),Vector2(2,-2),Vector2(10,2),Vector2(11,4),Vector2(6,5),Vector2(-3,1)]),Color(.24,.30,.21,.17))
  canvas.draw_colored_polygon(PackedVector2Array([Vector2(-4,-.5),Vector2(-2,-1.5),Vector2(2,-1.5),Vector2(4,-.5),Vector2(3,1),Vector2(-3,1)]),Color(.22,.25,.16,.21))
  if packet.has("source"): canvas.draw_texture_rect_region(packet.texture,packet.destination,packet.source)
  else: canvas.draw_texture_rect(packet.texture,packet.destination,false)

class PoseZoom extends Control:
 var packet := {}
 var original := false
 var animation_time := 0.0
 func _ready() -> void:
  material=preload("res://sprite_raster.gd").coverage_material()
  texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 func _draw() -> void:
  draw_rect(Rect2(Vector2.ZERO,size),Color("e2e8d4"))
  if packet.is_empty(): return
  draw_set_transform(Vector2(size.x*.5,198),0,Vector2.ONE*5)
  draw_line(Vector2(-17,0),Vector2(17,0),Color("a5b293"),.2)
  if original:
   var sprite := Reference.sprite(packet,animation_time)
   draw_texture_rect_region(Art.texture(sprite.texture),sprite.destination,sprite.source)
  elif packet.has("source"): draw_texture_rect_region(packet.texture,packet.destination,packet.source)
  else: draw_texture_rect(packet.texture,packet.destination,false)
  draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 rear="--back" in args
 if "--capture" in args:
  var at := args.find("--capture")
  if at+1>=args.size(): quit(2); return
  capture_dir=args[at+1]
  if not capture_dir.is_absolute_path() or DirAccess.dir_exists_absolute(capture_dir):
   printerr("Capture needs a new absolute output directory")
   quit(2)
   return
  DirAccess.make_dir_recursive_absolute(capture_dir.path_join("frames"))
 var folder := ProjectSettings.globalize_path("res://../artifacts/surface-gait-v7-sprites")
 if "--sprites" in args:
  var at := args.find("--sprites")
  if at+1>=args.size(): quit(2); return
  folder=args[at+1]
 if not frames.load_folder(folder): quit(1); return
 build.call_deferred()

func build() -> void:
 Engine.max_fps=60
 root.title="Tokenbook · 农场像素角色对照（不读取存档）"
 root.transparent=false
 root.transparent_bg=false
 root.borderless=false
 root.always_on_top=false
 root.unfocusable=false
 root.unresizable=false
 root.content_scale_size=Vector2i(1190,820)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.size=Vector2i(1190,820) if not capture_dir.is_empty() else Vector2i(1785,1230)
 var input := InputRelay.new()
 root.add_child(input)
 input.key_pressed.connect(on_key)
 var ui := Control.new()
 root.add_child(ui)
 var theme := Theme.new()
 var font := FontVariation.new()
 font.base_font=preload("res://assets/fonts/NotoSansSC.ttf")
 font.variation_opentype={0x77676874:400.0}
 theme.default_font=font
 ui.theme=theme
 var bg := ColorRect.new()
 bg.color=Color("eeeadd")
 bg.size=Vector2(1190,820)
 ui.add_child(bg)
 add_label(ui,"TOKENBOOK  /  农场中的二维步态候选",Vector2(24,18),23)
 add_label(ui,"原场景、原比例；只播放导出的二维帧。候选美术未替换正式角色。",Vector2(24,53),15)
 farm=CandidateFarm.new()
 farm.refined_animation=true
 farm.externally_driven=true
 farm.render_scale=2
 farm.size=Vector2(768,684)
 farm.position=Vector2(24,83)
 farm.packet=frames.sample(0,rear)
 ui.add_child(farm)
 var state := Rules.initial(1000)
 for i in range(4): state.plots[i]={"unlocked":true,"crop":"radish","planted":1,"duration":180}
 farm.set_state(state)
 for i in range(2):
  add_label(ui,"本轮候选 · 放大检查" if i==0 else "现有素材 · 同向步态参照",Vector2(836,109+i*295),18)
  var zoom := PoseZoom.new()
  zoom.original=i==1
  zoom.position=Vector2(836,148+i*295)
  zoom.size=Vector2(320,230)
  ui.add_child(zoom)
  zooms.append(zoom)
 label_status.position=Vector2(836,707)
 label_status.add_theme_color_override("font_color",Color("3e5945"))
 ui.add_child(label_status)
 add_label(ui,"空格 暂停  ·  S 慢放  ·  B 前后方向  ·  Tab 切换场景内角色  ·  R 重播  ·  Esc 关闭",Vector2(24,785),15)
 if not capture_dir.is_empty(): RenderingServer.frame_post_draw.connect(after_draw)
 update_scene()

func add_label(parent: Node, value: String, at: Vector2, font_size: int) -> void:
 var label := Label.new()
 label.text=value
 label.position=at
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color("3e5945"))
 parent.add_child(label)

func _process(delta: float) -> bool:
 if farm==null: return false
 if not capture_dir.is_empty(): elapsed=maxf(0,capture_frame/60.0)
 elif not playback_paused: elapsed=minf(4.5,elapsed+minf(delta,.1)*(1.0/3 if slow else 1))
 update_scene()
 return false

func update_scene() -> void:
 var packet := frames.sample(elapsed,rear)
 farm.packet=packet
 farm.animation_time=elapsed
 farm.motion.clock=elapsed
 farm.queue_redraw()
 for zoom in zooms:
  zoom.packet=packet
  zoom.animation_time=elapsed
  zoom.queue_redraw()
 label_status.text="%s / %s\n%s / %s" % ["背向" if rear else "正侧向","候选角色" if farm.candidate else "现有角色","慢放" if slow else "正常速度",{"walk":"行走","settle":"收步","idle":"站定"}[packet.kind]]

func on_key(event: InputEventKey) -> void:
 if not event.pressed or event.echo or not capture_dir.is_empty(): return
 match event.keycode:
  KEY_ESCAPE: quit()
  KEY_SPACE: playback_paused=not playback_paused
  KEY_S: slow=not slow
  KEY_B: rear=not rear; elapsed=0
  KEY_TAB: farm.candidate=not farm.candidate
  KEY_R: elapsed=0; playback_paused=false

func after_draw() -> void:
 if capturing: return
 capturing=true
 if capture_frame>=0:
  root.get_texture().get_image().save_png(capture_dir.path_join("frames/%04d.png" % capture_frame))
 capture_frame+=1
 if capture_frame>=270:
  RenderingServer.frame_post_draw.disconnect(after_draw)
  print("Farm 2D comparison captured: 270 frames; no save opened; ",capture_dir)
  quit()
  return
 capturing=false
