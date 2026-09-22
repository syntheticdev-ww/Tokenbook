extends SceneTree

var checks := 0
var failures := 0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void:
 root.hide()
 run.call_deferred()

func changed(a: Image,b: Image,rect: Rect2i) -> int:
 var count := 0
 for y in range(rect.position.y*2,rect.end.y*2):
  for x in range(rect.position.x*2,rect.end.x*2):
   if a.get_pixel(x,y)!=b.get_pixel(x,y): count+=1
 return count

func visible_change(a: Image,b: Image,rect: Rect2i) -> int:
 # Judge the actual 384px farm, not any one-byte change in a Retina image.
 var count := 0
 for y in range(rect.position.y,rect.end.y):
  for x in range(rect.position.x,rect.end.x):
   var delta := Vector3.ZERO
   for dy in range(2):
    for dx in range(2):
     var p := a.get_pixel(x*2+dx,y*2+dy)
     var q := b.get_pixel(x*2+dx,y*2+dy)
     delta+=Vector3(p.r-q.r,p.g-q.g,p.b-q.b)*.25
   if maxf(absf(delta.x),maxf(absf(delta.y),absf(delta.z)))>.06: count+=1
 return count

func run() -> void:
 if not FileAccess.file_exists("res://farm_environment.gd"):
  check(false,"farm needs a world-space living environment, not only a static background")
  finish(); return
 var output := OS.get_environment("TOKENBOOK_CAPTURE_DIR")
 if not output.is_absolute_path() or FileAccess.file_exists(output.path_join("environment-0.png")):
  printerr("Environment audit requires a fresh absolute TOKENBOOK_CAPTURE_DIR")
  quit(2); return
 var viewport := SubViewport.new()
 viewport.size=Vector2i(768,684)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 viewport.canvas_transform=Transform2D(0,Vector2(2,2),0,Vector2.ZERO)
 var art := preload("res://farm_character_art.gd").new()
 check(art.load_art(),"environment test uses the current full-body character")
 var actor := preload("res://farm_character.gd").new()
 actor.art=art
 var farm: Control=load("res://farm_view.gd").new()
 farm.character=actor
 farm.refined_animation=true
 farm.ambient_enabled=true
 farm.externally_driven=true
 farm.size=Vector2(384,342)
 viewport.add_child(farm)
 farm.set_process(false)
 farm.set_state(preload("res://farm_rules.gd").initial(1000))
 var snapshots: Array[Image]=[]
 for time in [0.0,1.8,4.3,0.0]:
  farm.motion.clock=time
  farm.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  snapshots.append(viewport.get_texture().get_image())
  check(snapshots[-1].save_png(output.path_join("environment-%d.png"%(snapshots.size()-1)))==OK,"save native environment audit frame")
 var a := snapshots[0]
 var b := snapshots[1]
 var regions := {
  "water":Rect2i(76,104,58,21),
  "leaves":Rect2i(1,63,34,56),
  "grass":Rect2i(1,180,29,45),
  "smoke":Rect2i(303,15,23,28)
 }
 for name in regions:
  var pixels := changed(a,b,regions[name])
  print("Environment ",name,": ",pixels," changed physical pixels")
  check(pixels>20,"actual "+name+" region changes while the character stands still")
  var visible := visible_change(a,b,regions[name])
  print("Environment ",name,": ",visible," visibly changed logical pixels")
  check(visible>({"water":100,"leaves":150,"grass":90,"smoke":25}[name]),name+" has readable motion at the normal window size, not only numerical pixel changes")
 for rect in [Rect2i(266,61,28,17),Rect2i(87,86,40,12),Rect2i(122,178,17,7),Rect2i(215,102,23,40)]:
  check(changed(a,b,rect)==0,"roof, stone bridge, field and character stay geometrically and chromatically stable")
 check(a.get_data()==snapshots[3].get_data(),"same world time reproduces identical pixels without an independent shader clock")
 # The smoke ROI also contains a moving tree. Compare air on/off at the
 # SAME time so tree motion cannot falsely certify an invisible smoke layer.
 farm._environment_layer._air.hide()
 farm.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 var no_air := viewport.get_texture().get_image()
 var smoke_pixels := visible_change(a,no_air,Rect2i(300,7,29,39))
 print("Smoke-only visible pixels: ",smoke_pixels)
 check(smoke_pixels>40,"chimney smoke itself is visible above the background, independently of the tree behind it")
 check(actor.position()==Vector2(228,138) and actor.kind=="idle","environment animation never advances or modifies the character")
 viewport.queue_free()
 await process_frame
 finish()

func finish() -> void:
 print("Environment native visual checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
