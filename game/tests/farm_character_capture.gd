extends SceneTree

# Deterministic visual audit of the real main scene, not a separate farm
# renderer. Fixed-time captures complement, not replace, live FPS checks.
var scene: Control
var records := []

func _initialize() -> void: call_deferred("run")

func run() -> void:
 var output := OS.get_environment("TOKENBOOK_CAPTURE_DIR").path_join("route-contact.png")
 if not output.is_absolute_path() or FileAccess.file_exists(output):
  printerr("Capture requires a new output file in TOKENBOOK_CAPTURE_DIR")
  quit(2); return
 scene=load("res://main.tscn").instantiate()
 scene.character_test=true
 root.add_child(scene)
 await process_frame
 var args := OS.get_cmdline_user_args()
 if args.size()==2 and args[0]=="--manifest":
  if not scene.character.art.load_art(args[1]):
   printerr(scene.character.art.error)
   scene.shutdown(1); return
 scene.set_process(false)
 for child in scene.get_children():
  if child is Timer: child.stop()
 # 60 samples across a six second route; do not scale the source actor.
 var sheet := Image.create(1600,960,false,Image.FORMAT_RGBA8)
 sheet.fill(Color("f7f0dd"))
 var passing := Image.create(640,160,false,Image.FORMAT_RGBA8)
 passing.fill(Color("f7f0dd"))
 var captured := {}
 var startup := Image.create(1600,640,false,Image.FORMAT_RGBA8)
 startup.fill(Color("f7f0dd"))
 var startup_records := []
 var stopping := Image.create(1600,320,false,Image.FORMAT_RGBA8)
 stopping.fill(Color("f7f0dd"))
 var stopping_records := []
 var stop_frame := -1
 var passing_names := ["front-10.png","front-10a.png","front-10b.png","front-11.png"]
 for frame in range(360):
  if frame==18: scene.begin_character_walk()
  if frame>0: scene._process(1.0/60)
  scene.farm.queue_redraw()
  # Queue the next draw outside the current post-draw callback. Otherwise
  # an unchanged idle frame can leave this audit waiting for a render forever.
  await process_frame
  await RenderingServer.frame_post_draw
  var name: String = scene.farm.actor_sprite().file.get_file()
  var passing_index := passing_names.find(name)
  var capture_passing: bool = scene.character.kind=="walk" and passing_index>=0 and not captured.has(name)
  var capture_startup := frame>=18 and frame<98 and frame%2==0
  if stop_frame<0 and scene.character.kind=="settle": stop_frame=frame
  var capture_stopping := stop_frame>=0 and frame-stop_frame<40 and (frame-stop_frame)%2==0
  if stop_frame>=0 and frame-stop_frame<40:
   stopping_records.append({"frame":frame-stop_frame,"kind":scene.character.kind,"file":scene.farm.actor_sprite().file,"distance":scene.character.travelled,"velocity":scene.character.velocity})
  if frame>=18 and frame<98:
   startup_records.append({"frame":frame-18,"kind":scene.character.kind,"file":scene.farm.actor_sprite().file,"distance":scene.character.travelled,"phase":scene.character.walk_phase()})
  if frame%6==0 or capture_passing or capture_startup or capture_stopping:
   var rendered := root.get_texture().get_image()
   var scale := Vector2(rendered.get_size())/Vector2(root.content_scale_size)
   var foot: Vector2=(scene.farm.global_position+scene.farm.world_to_view(scene.character.position()))*scale
   var rect := Rect2i(Vector2i(foot.floor())-Vector2i(80,112),Vector2i(160,160))
   if capture_startup:
    var sample := (frame-18)/2
    # Fixed world crop: following the actor masks a first-step-in-place bug.
    var home: Vector2=(scene.farm.global_position+scene.farm.world_to_view(Vector2(228,138)))*scale
    var start_rect := Rect2i(Vector2i(home.floor())-Vector2i(80,112),Vector2i(160,160))
    startup.blit_rect(rendered,start_rect,Vector2i(sample%10*160,sample/10*160))
   if capture_stopping:
    var sample := (frame-stop_frame)/2
    var end: Vector2=(scene.farm.global_position+scene.farm.world_to_view(Vector2(156,174)))*scale
    var stop_rect := Rect2i(Vector2i(end.floor())-Vector2i(80,112),Vector2i(160,160))
    stopping.blit_rect(rendered,stop_rect,Vector2i(sample%10*160,sample/10*160))
   if capture_passing:
    passing.blit_rect(rendered,rect,Vector2i(passing_index*160,0))
    captured[name]=true
   if frame%6==0:
    var sample := frame/6
    sheet.blit_rect(rendered,rect,Vector2i(sample%10*160,sample/10*160))
    records.append({"frame":frame,"kind":scene.character.kind,"phase":scene.character.walk_phase(),"distance":scene.character.travelled,"position":[scene.character.position().x,scene.character.position().y],"file":scene.farm.actor_sprite().file})
 var error := sheet.save_png(output)
 if captured.size()!=4: printerr("Missing authored passing pose in real renderer")
 var passing_error := passing.save_png(output.get_base_dir().path_join("passing-contact.png"))
 var startup_error := startup.save_png(output.get_base_dir().path_join("startup-contact.png"))
 var stopping_error := stopping.save_png(output.get_base_dir().path_join("stopping-contact.png"))
 var stopping_record := FileAccess.open(output.get_base_dir().path_join("stopping-frames.json"),FileAccess.WRITE)
 stopping_record.store_string(JSON.stringify({"fixed_fps":60,"contact_interval":2,"samples":stopping_records},"  "))
 stopping_record.close()
 var startup_record := FileAccess.open(output.get_base_dir().path_join("startup-frames.json"),FileAccess.WRITE)
 startup_record.store_string(JSON.stringify({"fixed_fps":60,"contact_interval":2,"samples":startup_records},"  "))
 startup_record.close()
 var record := FileAccess.open(output.get_basename()+".json",FileAccess.WRITE)
 record.store_string(JSON.stringify({"fixed_fps":60,"sample_interval":6,"columns":10,"note":"Real main scene at native 2x display scale; camera crops rounded to physical pixels for contact only.","samples":records},"  "))
 record.close()
 print("Real-main route capture: ",records.size()," samples, arrived=",scene.character.arrived(),", idle=",scene.character.kind=="idle",", image error=",error)
 scene.shutdown(0 if error==OK and passing_error==OK and startup_error==OK and stopping_error==OK and stopping_records.size()==40 and captured.size()==4 and scene.character.arrived() and scene.character.kind=="idle" else 1)
