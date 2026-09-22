extends SceneTree

class FixtureFarm extends "res://farm_view.gd":
 var show_person := true
 var show_body := true
 var facing_right := false
 var frame_override := {}
 func actor_position() -> Vector2: return Vector2(192,156)
 func visual_pose() -> Dictionary:
  var pose := super.visual_pose()
  pose.right=facing_right
  return pose
 func actor_sprite() -> Dictionary:
  return super.actor_sprite() if frame_override.is_empty() else frame_override
 func _paint_actor(canvas: CanvasItem) -> void:
  if show_person and show_body: super._paint_actor(canvas)
 func _paint_actor_shadow(canvas: CanvasItem) -> void:
  if show_person: super._paint_actor_shadow(canvas)

var failures := 0
var checks := 0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void:
 root.hide()
 run.call_deferred()
func run() -> void:
 var output := OS.get_environment("TOKENBOOK_CAPTURE_DIR")
 if not output.is_absolute_path(): quit(2);return
 var viewport := SubViewport.new()
 viewport.size=Vector2i(768,684)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 viewport.canvas_transform=Transform2D(0,Vector2(2,2),0,Vector2.ZERO)
 var farm := FixtureFarm.new()
 var art := preload("res://farm_character_art.gd").new()
 check(art.load_art(),"load the unchanged whole character")
 var actor := preload("res://farm_character.gd").new()
 actor.art=art
 farm.character=actor
 farm.refined_animation=true
 farm.externally_driven=true
 farm.size=Vector2(384,342)
 viewport.add_child(farm)
 farm.set_process(false)
 farm.set_state(preload("res://farm_rules.gd").initial(1000))
 var frames: Array[Image]=[]
 for visible in [false,true]:
  farm.show_person=visible
  farm.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  frames.append(viewport.get_texture().get_image())
 var footprint := Rect2i(199,158,13,10)
 var shaded := 0
 for y in range(footprint.position.y*2,footprint.end.y*2):
  for x in range(footprint.position.x*2,footprint.end.x*2):
   var a := frames[0].get_pixel(x,y)
   var b := frames[1].get_pixel(x,y)
   if a.get_luminance()-b.get_luminance()>.025: shaded+=1
 print("Readable projected character shadow pixels: ",shaded)
 check(shaded>65,"figure casts a readable body-shaped shadow onto the sunlit path, not only a fixed foot blob")
 check(frames[1].save_png(output.path_join("grounding.png"))==OK,"save normal farm grounding evidence")
 farm.show_body=false
 farm._shadow_layers[0].hide()
 var shadow_frames: Array[Image]=[]
 for phase in [0.0,4.5,8.0,12.5]:
  farm.frame_override=art.packet("walk",phase,0)
  farm.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  var shadow_image := viewport.get_texture().get_image()
  shadow_frames.append(shadow_image)
  # Isolate sole contact: neither the body nor the cast shadow can falsely
  # pass this check with their own dark pixels.
  var contact := 0
  for y in range(308,318):
   for x in range(367,403):
    if frames[0].get_pixel(x,y).get_luminance()-shadow_image.get_pixel(x,y).get_luminance()>.018: contact+=1
  check(contact>12,"shadow remains connected to the walking soles at phase "+str(phase))
 check(shadow_frames[0].get_data()!=shadow_frames[2].get_data(),"shadow follows opposite stepping poses instead of retaining a fixed silhouette")
 # Turning the sprite must never reverse the world's sunlight.
 farm._shadow_layers[0].show()
 farm.facing_right=true
 farm.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 var mirrored := viewport.get_texture().get_image()
 var right_mass := 0.0
 var left_mass := 0.0
 for y in range(318,333):
  for x in range(346,427):
   var shade := maxf(0,frames[0].get_pixel(x,y).get_luminance()-mirrored.get_pixel(x,y).get_luminance())
   if x>=384: right_mass+=shade
   else: left_mass+=shade
 check(right_mass>left_mass*2,"world light direction stays fixed when the character turns")
 viewport.queue_free()
 await process_frame
 print("Grounding visual checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
