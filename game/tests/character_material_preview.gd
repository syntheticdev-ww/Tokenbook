extends SceneTree

# A separate frozen real-game preview: never mix a static material change with
# the existing walking/departure clips. Uses main's isolated-save guard.
const SOURCE := "res://assets/art/gardener-v57/idle.png"
const PROVENANCE := "res://assets/art/gardener-v57/provenance.json"
const PREVIOUS := "res://assets/art/gardener-v56/idle.png"
const PREVIOUS_PROVENANCE := "res://assets/art/gardener-v56/provenance.json"
const MATERIAL := preload("res://character_material.gdshader")
const BACKGROUND := "res://assets/art/farm-background-landscape-v3.png"
const PREVIOUS_BACKGROUND := "res://assets/art/farm-background-landscape-v3.png"
const BASE_GRID := Vector2(80,94)
const PREVIOUS_BASE_GRID := Vector2(80,94)
const ART_GRID := Vector2(160,188)
const PREVIOUS_ART_GRID := Vector2(160,188)
const SAMPLE := Vector2(.25,.25)
const PREVIOUS_SAMPLE := Vector2(.25,.25)
const FACE_SAMPLE := Vector2(.2,.8)
const PREVIOUS_FACE_SAMPLE := Vector2(.2,.8)
const FACE_CELLS := Rect2i(28,16,13,12)
var scene: Control
var original: Dictionary
var refined: Dictionary
var grid_material: ShaderMaterial
var output: String

func _initialize() -> void: run.call_deferred()

func run() -> void:
 output=OS.get_environment("TOKENBOOK_CAPTURE_DIR")
 if not output.is_absolute_path():
  printerr("Material preview requires TOKENBOOK_CAPTURE_DIR")
  quit(2);return
 DirAccess.make_dir_recursive_absolute(output)
 var source:=Image.load_from_file(SOURCE)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PROVENANCE))
 if source==null or FileAccess.get_sha256(SOURCE)!=data.sha256:
  printerr("Character material source does not match its provenance")
  quit(2);return
 scene=load("res://main.tscn").instantiate()
 scene.character_test=true
 root.add_child(scene)
 root.title="词元之书 · 人物素材预览"
 await process_frame
 if not scene.store.ready or scene.character==null:
  scene.shutdown(2);return
 scene.set_process(false)
 scene.farm.set_process(false)
 scene.farm.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for child in scene.get_children():
  if child is Timer:child.stop()
 # Keep only Close interactive so navigation cannot replace the frozen scene
 # or switch to another artwork. This does not alter any main-game controls.
 for button: Button in scene.find_children("*","Button",true,false):
  button.disabled=button.text!="×"
  if button.text=="×":
   for connection in button.pressed.get_connections():button.pressed.disconnect(connection.callable)
   button.pressed.connect(func():scene.shutdown(0))
 for connection in root.close_requested.get_connections():root.close_requested.disconnect(connection.callable)
 root.close_requested.connect(func():scene.shutdown(0))
 scene.resources.text="林间小院 · 人物素材预览"
 scene.status.text="站立素材 · 动作保持不变"
 scene.action_button.text="静态预览"
 var art=scene.character.art
 var registration: Dictionary=data.static_registration
 var anchor:=Vector2(registration.anchor[0],registration.anchor[1])
 var ratio:=Vector2(root.size)/Vector2(root.content_scale_size)
 var zoom: Vector2=scene.farm.view_scale()*ratio
 # Match the selected portrait canvas's aspect ratio while keeping the
 # character's on-screen height. Retina still displays native cells 1:1.
 var previous_step:=maxi(1,roundi(ratio.y))
 var previous_grid:=PREVIOUS_ART_GRID if previous_step>=2 else PREVIOUS_BASE_GRID
 var grid:=ART_GRID
 var step:=1
 var canvas_pixels:=BASE_GRID*previous_step
 var previous_canvas_pixels:=PREVIOUS_BASE_GRID*previous_step
 var sample:=SAMPLE
 var face_sampling:=false
 var foot: Vector2=(scene.farm.global_position+scene.farm.world_to_view(scene.character.position()))*ratio
 var template: Dictionary=art.packet("idle",0,0)
 var previous_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PREVIOUS_PROVENANCE))
 var previous_source:=Image.load_from_file(PREVIOUS)
 var previous_anchor:=Vector2(previous_data.static_registration.anchor[0],previous_data.static_registration.anchor[1])
 original=registered_packet(template,previous_source,PREVIOUS,previous_anchor,previous_canvas_pixels,zoom,foot)
 refined=registered_packet(template,source,SOURCE,anchor,canvas_pixels,zoom,foot)
 var corner: Vector2=refined.screen_corner
 grid_material=ShaderMaterial.new()
 grid_material.shader=MATERIAL
 grid_material.set_shader_parameter("grid_size",previous_grid)
 grid_material.set_shader_parameter("sample_offset",PREVIOUS_SAMPLE if previous_step>=2 else Vector2(.5,.5))
 grid_material.set_shader_parameter("face_sample_offset",PREVIOUS_FACE_SAMPLE)
 grid_material.set_shader_parameter("refined_face_sampling",false)
 scene.farm._actor_layer.material=grid_material
 scene.farm._environment_layer.pixel_grid_density=0.0
 var environment=scene.farm._environment_layer
 var new_background:Texture2D=environment.landscape_texture
 environment.landscape_texture=load(PREVIOUS_BACKGROUND)
 environment.crisp_pixel_motion=true
 art.transition[0]=original
 scene.farm.queue_redraw()
 await capture("before",foot)
 grid_material.set_shader_parameter("grid_size",grid)
 grid_material.set_shader_parameter("sample_offset",sample)
 grid_material.set_shader_parameter("display_sampling_step",2.0/previous_step)
 grid_material.set_shader_parameter("display_sampling_offset",Vector2.ZERO)
 grid_material.set_shader_parameter("face_sample_offset",FACE_SAMPLE)
 grid_material.set_shader_parameter("refined_face_sampling",face_sampling)
 art.transition[0]=refined
 scene.farm.queue_redraw()
 await capture("character-only",foot)
 environment.pixel_grid_density=0.0
 environment.landscape_texture=new_background
 environment.crisp_pixel_motion=true
 scene.farm.queue_redraw()
 await capture("after",foot)
 var final_image:=Image.load_from_file(output.path_join("after-scene.png"))
 var before_image:=Image.load_from_file(output.path_join("before-scene.png"))
 var character_image:=Image.load_from_file(output.path_join("character-only-scene.png"))
 var avatar_zone:=Rect2i(Vector2i(foot)-Vector2i(160,205),Vector2i(320,270))
 var outside_changes:=0
 for y in range(final_image.get_height()):
  for x in range(final_image.get_width()):
   if not avatar_zone.has_point(Vector2i(x,y)) and character_image.get_pixel(x,y)!=before_image.get_pixel(x,y):outside_changes+=1
 var color_errors:=0
 var checked:=0
 for y in range(int(canvas_pixels.y)):
  for x in range(int(canvas_pixels.x)):
   var cell:=Vector2(x,y)*(2.0/previous_step)
   var source_point:=Vector2i((cell+sample)/grid*Vector2(source.get_size()))
   var expected:=source.get_pixel(source_point.x,source_point.y)
   if expected.a<.5:continue
   var screen_point:=Vector2i(corner.round())+Vector2i(x,y)
   var actual:=final_image.get_pixel(screen_point.x,screen_point.y)
   checked+=1
   if absf(actual.r-expected.r)>1.0/255 or absf(actual.g-expected.g)>1.0/255 or absf(actual.b-expected.b)>1.0/255:color_errors+=1
 var comparison:=Image.create(660,270,false,Image.FORMAT_RGBA8)
 comparison.fill(Color("f1eedf"))
 comparison.blit_rect(Image.load_from_file(output.path_join("before-context.png")),Rect2i(0,0,320,270),Vector2i.ZERO)
 comparison.blit_rect(Image.load_from_file(output.path_join("after-context.png")),Rect2i(0,0,320,270),Vector2i(340,0))
 comparison.save_png(output.path_join("comparison.png"))
 var background_check := check_background(final_image,ratio,step)
 var result:={"source_sha256":FileAccess.get_sha256(SOURCE),"grid_cells":[grid.x,grid.y],"cell_screen_pixels":canvas_pixels.y/grid.y,"canvas_pixels":[canvas_pixels.x,canvas_pixels.y],"body_pixels":float(registration.source_bounds[3])/source.get_height()*canvas_pixels.y,"body_logical_pixels":float(registration.source_bounds[3])/source.get_height()*BASE_GRID.y,"height_ratio_to_previous":(float(registration.source_bounds[3])/source.get_height()*BASE_GRID.y)/(float(previous_data.static_registration.source_bounds[3])/previous_source.get_height()*PREVIOUS_BASE_GRID.y),"sample_offset":[sample.x,sample.y],"physical_top_left":[corner.x,corner.y],"real_scene_checked_colors":checked,"real_scene_color_errors":color_errors,"motion_kind":scene.character.kind,"motion_distance":scene.character.travelled,"scope":"static material preview only"}
 result.merge(background_check)
 result["face_sample_offset"]=[FACE_SAMPLE.x,FACE_SAMPLE.y]
 result["face_grid_region"]=[FACE_CELLS.position.x,FACE_CELLS.position.y,FACE_CELLS.size.x,FACE_CELLS.size.y]
 result["changed_pixels_outside_character_area"]=outside_changes
 result["face_sampling_override"]=face_sampling
 result["background_grid_density"]=ratio.y
 result["window_physical_size"]=[root.size.x,root.size.y]
 result["background_asset"]=BACKGROUND
 result["display_sampling_step"]=2.0/previous_step
 result["display_sampling_offset"]=[0,0]
 result["background_crisp_motion"]=environment.crisp_pixel_motion
 var file:=FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  "));file.close()
 print("Static material preview: ",JSON.stringify(result))
 if "--capture" in OS.get_cmdline_user_args():
  var passed: bool = color_errors==0 and background_check.background_grid_errors==0 and background_check.background_source_color_errors==0 and outside_changes==0 and absf(result.height_ratio_to_previous-1.0)<.02 and scene.character.kind=="idle" and scene.character.travelled==0
  if not passed:printerr("Real FarmView did not preserve the registered material pixels")
  scene.shutdown(0 if passed else 1)

func registered_packet(template: Dictionary,image: Image,path: String,anchor: Vector2,pixels: Vector2,zoom: Vector2,foot: Vector2) -> Dictionary:
 var packet:=template.duplicate()
 var scale:=pixels/Vector2(image.get_size())/zoom
 packet.file=path
 packet.texture=ImageTexture.create_from_image(image)
 packet.source=Rect2(Vector2.ZERO,Vector2(image.get_size()))
 packet.destination=Rect2(-anchor*scale,pixels/zoom)
 var corner: Vector2=foot+packet.destination.position*zoom
 packet.destination.position+=(corner.round()-corner)/zoom
 packet.screen_corner=corner.round()
 packet.native_pixels=false
 packet.pixel_style=false
 return packet

func check_background(rendered: Image,ratio: Vector2,step: int) -> Dictionary:
 var source := Image.load_from_file(ProjectSettings.globalize_path(BACKGROUND))
 var errors := 0
 var nonuniform := 0
 var checked := 0
 # Architecture and open meadow: no wind blend, sprites, smoke or HUD.
 # Check original source colors as well as every physical pixel in the cell.
 for area in [Rect2(265,68,20,12),Rect2(312,185,12,12)]:
  var start: Vector2i=Vector2i((scene.farm.world_to_view(area.position)*ratio).ceil())
  var end: Vector2i=Vector2i((scene.farm.world_to_view(area.end)*ratio).floor())
  start=Vector2i((Vector2(start)/step).ceil())*step
  for y in range(start.y,end.y-step+1,step):
   for x in range(start.x,end.x-step+1,step):
    var logical:=(Vector2(x,y)+Vector2(.5,.5))/ratio
    var world: Vector2=(logical-scene.farm.view_offset())/scene.farm.view_scale()
    var uv: Vector2=(world+Vector2(78,0))/Vector2(512,342)
    var sample:=Vector2i(uv*Vector2(source.get_size()))
    var expected:=source.get_pixel(sample.x,sample.y)
    var screen:=Vector2i(x,y)
    var first:=rendered.get_pixel(screen.x,screen.y)
    for yy in range(step):
     for xx in range(step):
      var actual:=rendered.get_pixel(screen.x+xx,screen.y+yy)
      checked+=1
      if actual!=first:nonuniform+=1
      if absf(actual.r-expected.r)>1.0/255 or absf(actual.g-expected.g)>1.0/255 or absf(actual.b-expected.b)>1.0/255:errors+=1
 return {"background_checked_pixels":checked,"background_grid_errors":nonuniform,"background_source_color_errors":errors}

func capture(label: String,foot: Vector2) -> void:
 # FarmView queues its actor layer from its own draw callback. Wait through
 # the deferred child redraw before inspecting the final material/geometry.
 for frame in range(3):
  await process_frame
  RenderingServer.force_draw(false)
 var image:=root.get_texture().get_image()
 image.save_png(output.path_join(label+"-scene.png"))
 image.get_region(Rect2i(Vector2i(foot)-Vector2i(160,205),Vector2i(320,270))).save_png(output.path_join(label+"-context.png"))
