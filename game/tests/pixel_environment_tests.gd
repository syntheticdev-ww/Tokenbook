extends SceneTree

var scene:Control
var ratio:Vector2
var checks:=0
var failures:=0
const FOLIAGE := {"leaves":Rect2(37,83,12,12),"grass":Rect2(350,194,12,14)}

func _initialize() -> void: run.call_deferred()
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)

func run() -> void:
 scene=load("res://main.tscn").instantiate()
 scene.character_test=true
 root.add_child(scene)
 await process_frame
 if not scene.store.ready or scene.character==null:scene.shutdown(2);return
 scene.set_process(false)
 scene.farm.set_process(false)
 for child in scene.get_children():
  if child is Timer:child.stop()
 ratio=Vector2(root.size)/Vector2(root.content_scale_size)
 var environment=scene.farm._environment_layer
 environment._air.hide() # Isolate texture colors from smoke/butterflies.
 var source:Image=environment.landscape_texture.get_image()
 var palettes:Dictionary={}
 for name in FOLIAGE:palettes[name]=source_palette(source,FOLIAGE[name])
 var images:Array[Image]=[]
 var output:=OS.get_environment("TOKENBOOK_CAPTURE_DIR")
 for time in [0.0,1.8,4.3,0.0]:
  images.append(await snapshot(time))
  images[-1].save_png(output.path_join("pixel-landscape-%d.png"%(images.size()-1)))
 var report:Dictionary={}
 for name in FOLIAGE:
  var area:=screen_rect(FOLIAGE[name])
  var motion:=changed(images[0],images[1],area)
  var errors:=0
  for image in images:errors+=palette_errors(image,area,palettes[name])
  report[name]={"moving_pixels":motion,"mixed_color_pixels":errors}
  check(motion>20,name+" still visibly moves in the landscape renderer")
  check(errors==0,name+" retains authored texture colors throughout motion")
 for area in [Rect2(265,68,20,12),Rect2(150,58,24,14)]:
  check(changed(images[0],images[1],screen_rect(area))==0,"roof and distant architecture remain still")
 check(images[0].get_data()==images[3].get_data(),"repeating world time reproduces identical pixels")
 check(scene.character.kind=="idle" and scene.character.travelled==0,"background motion does not move the character")
 # A negative control proves these palette checks detect the old blur.
 environment.crisp_pixel_motion=false
 var softened:=await snapshot(1.8)
 var softened_errors:=0
 for name in FOLIAGE:softened_errors+=palette_errors(softened,screen_rect(FOLIAGE[name]),palettes[name])
 check(softened_errors>20,"palette audit detects interpolated foliage colors")
 report["negative_control_mixed_pixels"]=softened_errors
 report["checks"]=checks
 report["failures"]=failures
 var f:=FileAccess.open(output.path_join("pixel-landscape-verification.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "));f.close()
 print("Crisp landscape checks: ",JSON.stringify(report))
 scene.shutdown(0 if failures==0 else 1)

func snapshot(time:float) -> Image:
 scene.farm.motion.clock=time
 scene.farm.queue_redraw()
 for frame in range(3):
  await process_frame
  RenderingServer.force_draw(false)
 return root.get_texture().get_image()

func screen_rect(area:Rect2) -> Rect2i:
 var start:=Vector2i((scene.farm.world_to_view(area.position)*ratio).ceil())
 var end:=Vector2i((scene.farm.world_to_view(area.end)*ratio).floor())
 return Rect2i(start,end-start)

func color_key(color:Color) -> int:
 return (roundi(color.r*255)<<16)|(roundi(color.g*255)<<8)|roundi(color.b*255)

func source_palette(source:Image,area:Rect2) -> Dictionary:
 # Include the entire local wind displacement range, not an expected warp.
 var expanded:=area.grow(5)
 var start:=Vector2i(((expanded.position+Vector2(78,0))/Vector2(512,342)*Vector2(source.get_size())).floor())
 var end:=Vector2i(((expanded.end+Vector2(78,0))/Vector2(512,342)*Vector2(source.get_size())).ceil())
 var colors:Dictionary={}
 for y in range(start.y,end.y):
  for x in range(start.x,end.x):colors[color_key(source.get_pixel(x,y))]=true
 return colors

func palette_errors(image:Image,area:Rect2i,colors:Dictionary) -> int:
 var errors:=0
 for y in range(area.position.y,area.end.y):
  for x in range(area.position.x,area.end.x):
   if not colors.has(color_key(image.get_pixel(x,y))):errors+=1
 return errors

func changed(a:Image,b:Image,area:Rect2i) -> int:
 var count:=0
 for y in range(area.position.y,area.end.y):
  for x in range(area.position.x,area.end.x):
   if a.get_pixel(x,y)!=b.get_pixel(x,y):count+=1
 return count
