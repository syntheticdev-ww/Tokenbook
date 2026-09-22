extends SceneTree

# Read-only, individually labelled engine renders for inspecting pose order.
const Art = preload("res://farm_character_art.gd")
const Raster = preload("res://sprite_raster.gd")
var art := Art.new()
var canvas: Control
var selected := 0

func _initialize() -> void: run.call_deferred()
func draw_pose() -> void:
 Raster.draw_sprite(canvas,art.walk[selected],Transform2D(0,Vector2.ONE*5,0,Vector2(100,202)))

func run() -> void:
 var args := OS.get_cmdline_user_args()
 assert(args.size()==2,"walk_pose_sheet requires manifest and new output PNG")
 assert(not FileAccess.file_exists(args[1]))
 assert(art.load_art(args[0]),art.error)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 root.size=Vector2i(200,224)
 root.content_scale_size=root.size
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var background := ColorRect.new()
 background.color=Color("ece8da"); background.size=Vector2(200,224)
 root.add_child(background)
 canvas=Control.new()
 canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 canvas.material=Raster.coverage_material()
 canvas.draw.connect(draw_pose)
 root.add_child(canvas)
 var label := Label.new()
 label.position=Vector2(12,3)
 label.add_theme_color_override("font_color",Color("405139"))
 root.add_child(label)
 var sheet := Image.create(1200,ceili(art.walk.size()/6.0)*224,false,Image.FORMAT_RGBA8)
 for i in art.walk.size():
  selected=i
  label.text="%02d / %s"%[i,str(data.walk[i].get("source_phase",data.walk[i].phase))]
  canvas.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  sheet.blit_rect(root.get_texture().get_image(),Rect2i(0,0,200,224),Vector2i(i%6*200,i/6*224))
 sheet.save_png(args[1])
 print("Captured ",art.walk.size()," labelled intact poses: ",args[1])
 quit()
