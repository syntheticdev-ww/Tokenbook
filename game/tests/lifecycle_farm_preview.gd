extends SceneTree

# Interactive integration fixture, not a new game mode. Uses the real farm
# renderer/depth order but never opens a save or starts simulation work.
const Reference = preload("rigged_farm_preview.gd")
const Frames = preload("pixel_character_frames.gd")
const Motion = preload("res://character_motion.gd")
const Rules = preload("res://farm_rules.gd")
const EVENTS := [0.0,1.0,2.2,3.4]
const WALKWAY_LIMIT := 50.0
var frames := Frames.new()
var motion := Motion.new()
var farm: Control
var zooms: Array[Control] = []
var status := Label.new()
var rear := false
var slow := false
var playback_paused := false
var demo := false
var continuous := false
var lifecycle_requested := false
var demo_clock := 0.0
var demo_event := 0
var visual_clock := 0.0
var capture_dir := ""
var capture_frame := -8
var capture_clock := 0.0
var capturing := false

func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 rear="--back" in args
 lifecycle_requested="--lifecycle" in args
 if "--capture" in args:
  var at := args.find("--capture")
  if at+1>=args.size(): quit(2); return
  capture_dir=args[at+1]
  if not capture_dir.is_absolute_path() or DirAccess.dir_exists_absolute(capture_dir):
   printerr("Capture needs a new absolute output directory")
   quit(2)
   return
  DirAccess.make_dir_recursive_absolute(capture_dir.path_join("frames"))
 build.call_deferred()

func configure_motion() -> void:
 motion=Motion.new()
 motion.configure(frames.stride(rear),frames.metadata)

func build() -> void:
 Engine.max_fps=60
 root.title="Tokenbook · 像素人物动作检查（不读取存档）"
 root.transparent=false
 root.transparent_bg=false
 root.borderless=false
 root.always_on_top=false
 root.unfocusable=false
 root.unresizable=false
 root.content_scale_size=Vector2i(1190,820)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.size=Vector2i(1190,820) if not capture_dir.is_empty() else Vector2i(1600,1102)
 root.move_to_center()
 var input := Reference.InputRelay.new()
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
 add_label(ui,"TOKENBOOK  /  完整像素人物 · 连续步态与起停",Vector2(24,18),23)
 add_label(ui,"默认连续原地步态，Enter 手动收步；R 单独检查起停。摆臂原画仍在细修，不读取存档。",Vector2(24,53),15)
 configure_motion()
 farm=Reference.CandidateFarm.new()
 farm.refined_animation=true
 farm.externally_driven=true
 farm.render_scale=2
 farm.size=Vector2(768,684)
 farm.position=Vector2(24,83)
 farm.packet=frames.pose_packet("stop",36,rear)
 ui.add_child(farm)
 var state := Rules.initial(1000)
 for i in range(4): state.plots[i]={"unlocked":true,"crop":"radish","planted":1,"duration":180}
 farm.set_state(state)
 for i in range(2):
  add_label(ui,"当前方向 · 放大检查" if i==0 else "另一方向 · 同步检查",Vector2(836,109+i*259),18)
  var zoom := Reference.PoseZoom.new()
  zoom.position=Vector2(836,145+i*259)
  zoom.size=Vector2(320,230)
  ui.add_child(zoom)
  zooms.append(zoom)
 for i in range(2):
  var button := Button.new()
  button.text="起走  W" if i==0 else "收步  Enter"
  button.position=Vector2(836+i*165,650)
  button.size=Vector2(155,40)
  button.focus_mode=Control.FOCUS_NONE
  button.disabled=not capture_dir.is_empty()
  ui.add_child(button)
  button.pressed.connect(begin_walk if i==0 else stop_walk)
 status.position=Vector2(836,703)
 status.add_theme_color_override("font_color",Color("3e5945"))
 ui.add_child(status)
 add_label(ui,"W 起走 · Enter 收步 · C 连续步态 · R 起停示范 · 空格 暂停 · S 慢放 · B 切换方向 · Esc 关闭",Vector2(24,785),14)
 if not capture_dir.is_empty(): RenderingServer.frame_post_draw.connect(after_draw)
 if lifecycle_requested: start_demo()
 else: start_loop()
 update_scene()

func add_label(parent: Node,text: String,at: Vector2,font_size: int) -> void:
 var label := Label.new()
 label.text=text
 label.position=at
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color("3e5945"))
 parent.add_child(label)

func start_demo() -> void:
 configure_motion()
 continuous=false
 demo=true
 demo_clock=0
 demo_event=0
 playback_paused=false
 advance_scene(0)

func start_loop() -> void:
 configure_motion()
 continuous=true
 demo=false
 demo_clock=0
 visual_clock=0
 playback_paused=false
 motion.begin()

func begin_walk() -> void:
 if not capture_dir.is_empty(): return
 if not continuous and motion.position.length()>=WALKWAY_LIMIT: return
 demo=false
 playback_paused=false
 motion.begin()

func stop_walk() -> void:
 if not capture_dir.is_empty(): return
 demo=false
 motion.request_stop()

func advance_scene(delta: float) -> void:
 visual_clock+=delta
 if demo:
  var target := minf(6,demo_clock+delta)
  while demo_event<EVENTS.size() and EVENTS[demo_event]<=target+1e-9:
   motion.advance(maxf(0,EVENTS[demo_event]-demo_clock))
   demo_clock=EVENTS[demo_event]
   if demo_event%2==0: motion.begin()
   else: motion.request_stop()
   demo_event+=1
  motion.advance(maxf(0,target-demo_clock))
  demo_clock=target
  if demo_clock>=6: demo=false
 else: motion.advance(delta)
 # Keep this straight-line art test on the existing upper walkway. This is
 # not a claim that arbitrary click-to-move or turning is implemented.
 if not continuous and motion.position.length()>=WALKWAY_LIMIT: motion.request_stop()

func _process(delta: float) -> bool:
 if farm==null: return false
 if not capture_dir.is_empty():
  if capture_frame>=0:
   var target := capture_frame/60.0
   advance_scene(maxf(0,target-capture_clock))
   capture_clock=target
 elif not playback_paused: advance_scene(minf(delta,.1)*(1.0/3 if slow else 1))
 update_scene()
 return false

func update_scene() -> void:
 var pose := motion.snapshot()
 var packet := frames.pose_packet(pose.clip,pose.frame,rear)
 # Continuous inspection deliberately fixes the root. It evaluates pose
 # cadence, not world-space ground contact; the separate lifecycle demo moves.
 packet.merge({"kind":pose.kind,"progress":pose.progress,"offset":Vector2.ZERO if continuous else motion.position},true)
 farm.packet=packet
 farm.motion.clock=visual_clock
 farm.animation_time=visual_clock
 farm.queue_redraw()
 for i in range(zooms.size()):
  zooms[i].packet=frames.pose_packet(pose.clip,pose.frame,rear if i==0 else not rear)
  zooms[i].queue_redraw()
 var mode_text := "连续原地步态 · 无定时停步" if continuous else ("起停示范：两次起走与停下" if demo else ("已到步道边界，R 重播" if motion.position.length()>=WALKWAY_LIMIT else "按 W 起走，Enter 收步"))
 status.text="%s / %s / %s\n%s" % ["背向" if rear else "正向","慢放" if slow else "正常速度",{"idle":"站定","depart":"起步","walk":"行走","settle":"收步"}[pose.kind],mode_text]

func on_key(event: InputEventKey) -> void:
 if not event.pressed or event.echo or not capture_dir.is_empty(): return
 match event.keycode:
  KEY_ESCAPE: quit()
  KEY_W: begin_walk()
  KEY_ENTER: stop_walk()
  KEY_SPACE: playback_paused=not playback_paused
  KEY_S: slow=not slow
  KEY_B: rear=not rear; configure_motion(); demo=false; playback_paused=false
  KEY_R: start_demo()
  KEY_C: start_loop()

func after_draw() -> void:
 if capturing: return
 capturing=true
 if capture_frame>=0:
  if root.get_texture().get_image().save_png(capture_dir.path_join("frames/%04d.png" % capture_frame))!=OK:
   printerr("Failed to save lifecycle farm frame"); quit(1); return
 capture_frame+=1
 var capture_length := 360 if lifecycle_requested else 786
 if capture_frame>=capture_length:
  RenderingServer.frame_post_draw.disconnect(after_draw)
  print("Pixel motion capture: ",capture_length," frames at 60 Hz; mode=", "lifecycle" if lifecycle_requested else "continuous", "; no save opened; ",capture_dir)
  quit()
 capturing=false
