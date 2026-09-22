extends SceneTree

const Art = preload("res://farm_character_art.gd")
const Raster = preload("res://sprite_raster.gd")
var old := Art.new()
var updated := Art.new()
var canvases: Array[Control]=[]
var phase := 0.0
var output := "res://../artifacts/walk-v21/"

func _initialize() -> void: run.call_deferred()
func render_side(canvas: Control,i: int) -> void:
 var art: RefCounted=old if i==0 else updated
 Raster.draw_sprite(canvas,art.packet("walk",phase+art.passing_phase,0),Transform2D(0,Vector2.ONE*4,0,Vector2(120+i*240,184)))

func run() -> void:
 var args := OS.get_cmdline_user_args()
 var before := "res://assets/art/gardener-v20/character.json"
 var after := "res://assets/art/gardener-v21/character.json"
 if args.size()==3:
  before=args[0]; after=args[1]; output=args[2].trim_suffix("/")+"/"
 assert(old.load_art(before))
 assert(updated.load_art(after))
 root.size=Vector2i(480,210)
 root.content_scale_size=Vector2i(480,210)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var background := ColorRect.new()
 background.color=Color("ece8da")
 background.size=Vector2(480,210)
 root.add_child(background)
 for i in range(2):
  var canvas := Control.new()
  canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  canvas.material=Raster.coverage_material()
  canvas.draw.connect(func():render_side(canvas,i))
  root.add_child(canvas); canvases.append(canvas)
 var font: Font=load("res://assets/fonts/NotoSansSC.ttf")
 for i in range(2):
  var label := Label.new()
  label.text="之前 · %d 帧"%old.walk.size() if i==0 else "调整后 · %d 帧"%updated.walk.size()
  label.position=Vector2(52+i*240,10)
  label.add_theme_font_override("font",font)
  label.add_theme_color_override("font_color",Color("405139"))
  root.add_child(label)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output+"frames"))
 var sheet := Image.create(1440,840,false,Image.FORMAT_RGBA8)
 for frame in range(63):
  phase=frame/63.0*16
  for canvas in canvases: canvas.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  var image := root.get_texture().get_image()
  # Root pixels are deliberately fixed for repeatable A/B analysis.
  image.save_png(output+"frames/%03d.png"%frame)
  if frame%6==0:
   var cell := frame/6
   sheet.blit_rect(image,Rect2i(0,0,480,210),Vector2i(cell%3*480,cell/3*210))
 sheet.save_png(output+"comparison-contact.png")
 print("Dense walk visual: 63 fixed-time paired captures, unchanged stride and period")
 quit()
