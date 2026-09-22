extends SceneTree

# Separate sustained-walk inspection. Unlike lifecycle_farm_preview, this
# fixture has no scheduled stop. No save, bridge or game simulation is opened.
const Frames = preload("whole_body_frames.gd")
const Reference = preload("rigged_farm_preview.gd")
const Rules = preload("res://farm_rules.gd")
var frames := Frames.new()
var farm: Control
var zooms: Array[Control] = []
var elapsed := 0.0
var playback_paused := false
var slow := false
var capture_dir := ""
var frame_index := -8
var capturing := false
var status := Label.new()
var capture_cycles := 12

func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 var art_manifest := "res://assets/art/gardener-v17/frames/cycle.json"
 if "--art" in args:
  var at := args.find("--art")
  if at+1>=args.size(): quit(2); return
  art_manifest=args[at+1].path_join("cycle.json")
 if "--cycles" in args:
  var at := args.find("--cycles")
  if at+1>=args.size() or not args[at+1].is_valid_int(): quit(2); return
  capture_cycles=clampi(int(args[at+1]),1,60)
 if "--capture" in args:
  var at := args.find("--capture")
  if at+1>=args.size(): quit(2); return
  capture_dir=args[at+1]
  if not capture_dir.is_absolute_path() or DirAccess.dir_exists_absolute(capture_dir):
   printerr("Capture requires a new absolute directory")
   quit(2); return
  DirAccess.make_dir_recursive_absolute(capture_dir.path_join("frames"))
 var loaded := frames.load_manifest(art_manifest)
 if not loaded: printerr(frames.error); quit(1); return
 build.call_deferred()

func label(parent: Node,value: String,at: Vector2,point_size := 18) -> void:
 var item := Label.new()
 item.text=value
 item.position=at
 item.add_theme_font_size_override("font_size",point_size)
 item.add_theme_color_override("font_color",Color("3e5945"))
 parent.add_child(item)

func build() -> void:
 Engine.max_fps=60
 root.title="Tokenbook · 连续步态内部检查"
 root.transparent=false
 root.transparent_bg=false
 root.borderless=false
 root.always_on_top=false
 root.unfocusable=false
 root.content_scale_size=Vector2i(1190,820)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.size=Vector2i(1190,820)
 var input := Reference.InputRelay.new()
 root.add_child(input)
 input.key_pressed.connect(on_key)
 var ui := Control.new()
 var theme := Theme.new()
 theme.default_font=preload("res://assets/fonts/NotoSansSC.ttf")
 ui.theme=theme
 root.add_child(ui)
 var bg := ColorRect.new()
 bg.color=Color("eeeadd")
 bg.size=Vector2(1190,820)
 ui.add_child(bg)
 label(ui,"TOKENBOOK / 连续整身原画检查",Vector2(24,18),23)
 label(ui,"固定位置检查素材循环；不是贴地位移验收。候选尚未替换正式角色。",Vector2(24,53),15)
 farm=Reference.CandidateFarm.new()
 farm.refined_animation=true
 farm.externally_driven=true
 farm.render_scale=2
 farm.size=Vector2(768,684)
 farm.position=Vector2(24,83)
 farm.packet=frames.sample(0)
 ui.add_child(farm)
 farm.set_state(Rules.initial(1000))
 for i in range(2):
  label(ui,"完整新原画 · 5 倍" if i==0 else "现有步态 · 5 倍",Vector2(836,109+i*295))
  var zoom := Reference.PoseZoom.new()
  zoom.original=i==1
  zoom.position=Vector2(836,148+i*295)
  zoom.size=Vector2(320,230)
  ui.add_child(zoom)
  zooms.append(zoom)
 status.position=Vector2(836,707)
 status.add_theme_color_override("font_color",Color("3e5945"))
 ui.add_child(status)
 label(ui,"Space 暂停 · S 慢放 · ←/→ 逐帧 · R 重播 · Esc 关闭",Vector2(24,785),15)
 if not capture_dir.is_empty(): RenderingServer.frame_post_draw.connect(after_draw)
 update_scene()

func _process(delta: float) -> bool:
 if farm==null: return false
 if not capture_dir.is_empty(): elapsed=maxf(0,frame_index/60.0)
 elif not playback_paused: elapsed+=minf(delta,.1)*(1.0/3 if slow else 1.0)
 update_scene()
 return false

func update_scene() -> void:
 var packet := frames.sample(elapsed)
 farm.packet=packet
 farm.animation_time=elapsed
 farm.motion.clock=elapsed
 farm.queue_redraw()
 for zoom in zooms:
  zoom.packet=packet
  zoom.animation_time=elapsed
  zoom.queue_redraw()
 status.text="连续行走 / %s\n第 %d 帧 · 第 %d 圈" % ["慢放" if slow else "正常速度",packet.drawing+1,int(elapsed/Frames.PERIOD)+1]

func on_key(event: InputEventKey) -> void:
 if not event.pressed or event.echo or not capture_dir.is_empty(): return
 match event.keycode:
  KEY_ESCAPE: quit()
  KEY_SPACE: playback_paused=not playback_paused
  KEY_S: slow=not slow
  KEY_R: elapsed=0; playback_paused=false
  KEY_RIGHT: playback_paused=true; elapsed=frames.step_time(elapsed,1)
  KEY_LEFT: playback_paused=true; elapsed=frames.step_time(elapsed,-1)

func after_draw() -> void:
 if capturing: return
 capturing=true
 if frame_index>=0:
  var result := root.get_texture().get_image().save_png(capture_dir.path_join("frames/%04d.png" % frame_index))
  if result!=OK: printerr("Capture failed: ",result); quit(1); return
 frame_index+=1
 if frame_index>=capture_cycles*63:
  RenderingServer.frame_post_draw.disconnect(after_draw)
  print("Continuous full-body capture: ",capture_cycles," cycles, ",frame_index," frames at 60 Hz; ",capture_dir)
  quit()
 capturing=false
