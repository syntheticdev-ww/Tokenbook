extends SceneTree

var scene: Control
var checks := 0
var failures := 0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1;printerr("FAIL: ",message)
func _initialize() -> void: run.call_deferred()
func capture(name: String) -> Image:
 await process_frame
 await RenderingServer.frame_post_draw
 var rendered := root.get_texture().get_image()
 rendered.save_png(OS.get_environment("TOKENBOOK_CAPTURE_DIR").path_join(name+".png"))
 return rendered
func run() -> void:
 scene=load("res://main.tscn").instantiate()
 scene.character_test=true
 root.add_child(scene)
 await process_frame
 var state: Dictionary=scene.store.snapshot()
 var controller=scene.character
 var window_id:=root.get_window_id()
 scene.set_expanded(false)
 scene.set_process(false)
 scene.pet_clock=0
 scene.pet.set_clock(0)
 var anchor:=root.position
 check(scene.pet!=null and scene.farm==null,"collapsed view contains only the pet, no farm renderer")
 check(root.borderless and root.transparent and root.transparent_bg and root.always_on_top,"pet requests a transparent borderless floating native window")
 check(not root.mouse_passthrough_polygon.is_empty(),"native window has the current character silhouette hit region")
 check(not scene.pet._has_point(Vector2(1,1)),"transparent corner is not an interactive pet point")
 var texture_bytes:=0
 for frame in scene.pet.frames:
  texture_bytes+=int(frame.texture.get_width()*frame.texture.get_height()*4)
 check(texture_bytes<4*1024*1024,"cropped pet animation textures occupy less than four MiB before GPU overhead")
 var idle:=await capture("pet-idle")
 var clear:=0
 for y in range(0,idle.get_height(),4):
  for x in range(0,idle.get_width(),4):
   if idle.get_pixel(x,y).a<.01:clear+=1
 check(float(clear)/(idle.get_width()/4*idle.get_height()/4)>.65,"rendered pet canvas is mostly fully transparent, not a colored rectangle")
 var states:={}
 for t in [0.0,5.1,5.3,5.6,5.96,6.16,6.36,6.56,6.76,10.9,11.7]:
  scene.pet.set_clock(t)
  states[scene.pet.frame_index]=true
  check(root.mouse_passthrough_polygon.size()>=3,"every displayed pose retains a clickable native silhouette")
 scene.pet.set_clock(6.36)
 var digging:=await capture("pet-digging")
 check(idle.get_data()!=digging.get_data() and states.size()>=9,"idle, lowering, bare-hand digging and recovery display distinct complete poses")
 check(scene.store.snapshot().plots==state.plots and scene.store.snapshot().inventory==state.inventory,"companion animation does not create farm jobs or rewards")
 # Exercise the same press/release handlers used by native pet clicks.
 var press:=InputEventMouseButton.new()
 press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
 scene.header_input(press)
 var release:=InputEventMouseButton.new()
 release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
 scene._input(release)
 await process_frame
 # finish_drag opens through call_deferred; a process_frame signal can
 # resume before that frame's deferred queue has rebuilt the farm.
 await process_frame
 check(scene.expanded and root.content_scale_size==scene.Layout.EXPANDED,"releasing a pet click opens the landscape farm")
 check(root.mouse_passthrough_polygon.is_empty() and not root.unfocusable,"game restores rectangular input and keyboard focus")
 check(not root.always_on_top,"expanded farm is a normal window rather than an always-on-top obstruction")
 check(root.get_window_id()==window_id and scene.character==controller,"mode switch retains the same process, window and character")
 if scene.farm==null:
  scene.shutdown(1);return
 check(scene.farm.size==Vector2(scene.Layout.EXPANDED),"farm picture fills the entire landscape canvas")
 await capture("landscape-farm")
 scene.show_page("bag")
 check(scene.page_values.has("capacity"),"inventory remains accessible in the in-game overlay")
 await capture("landscape-bag")
 var escape:=InputEventKey.new()
 escape.keycode=KEY_ESCAPE;escape.pressed=true
 scene._input(escape)
 check(scene.expanded and scene.page=="farm","Escape closes an overlay before leaving the game")
 scene._input(escape)
 check(not scene.expanded and scene.pet!=null,"Escape from farm returns to the pet")
 scene.header_input(press)
 var motion:=InputEventMouseMotion.new()
 motion.position=Vector2(30,20)
 scene._input(motion)
 check(scene.drag_moved,"forwarded motion detects a drag even when the global pointer does not move")
 scene._input(release)
 await process_frame
 check(not scene.expanded,"releasing a drag does not also open the game")
 anchor=root.position
 for i in range(20):
  scene.set_expanded(true);scene.set_expanded(false)
  await process_frame
 check(root.position==anchor,"repeated switches preserve the pet desktop position")
 scene.set_process(true)
 scene.hide_game()
 var stopped_clock:float=scene.pet_clock
 await create_timer(.2).timeout
 check(scene.game_hidden and scene.pet_clock==stopped_clock,"hidden pet suspends its animation")
 scene.show_game()
 await create_timer(.15).timeout
 check(scene.is_game_visible() and scene.pet_clock>stopped_clock,"tray restoration resumes the existing pet")
 print("Desktop pet native checks: ",checks,", failures: ",failures,"; cropped RGBA MiB: ",texture_bytes/1048576.0)
 scene.shutdown(0 if failures==0 else 1)
