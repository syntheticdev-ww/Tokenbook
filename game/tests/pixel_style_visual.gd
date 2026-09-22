extends SceneTree

# Engine-only style proof at native size and enlarged pixels, using the same
# full-body PNGs. The farm background is untouched. No source image edits.
const Art = preload("res://farm_character_art.gd")
const Raster = preload("res://sprite_raster.gd")
var art := Art.new()
var canvases: Array[Control]=[]

func _initialize() -> void: run.call_deferred()
func paint(canvas: Control,index: int) -> void:
 var sprite := art.packet("idle",0,0).duplicate()
 sprite.pixel_style=index>0
 sprite.pixel_pitch=.25 if index==1 else .3333333333
 Raster.draw_sprite(canvas,sprite,Transform2D(0,Vector2.ONE*2,0,Vector2(160+index*320,220)))
 Raster.draw_sprite(canvas,sprite,Transform2D(0,Vector2.ONE*6,0,Vector2(160+index*320,510)))

func run() -> void:
 assert(art.load_art("res://assets/art/gardener-v22/character.json"))
 root.size=Vector2i(960,540);root.content_scale_size=root.size
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 var background := Control.new()
 var texture := load("res://assets/art/farm-background-landscape-v1.png")
 background.draw.connect(func():
  for i in range(3): background.draw_texture_rect_region(texture,Rect2(i*320,0,320,540),Rect2(735,80,320,540)))
 root.add_child(background)
 for i in range(3):
  var canvas := Control.new()
  canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  canvas.material=Raster.coverage_material()
  canvas.draw.connect(func():paint(canvas,i))
  canvases.append(canvas);root.add_child(canvas)
  var label := Label.new()
  label.text=["CURRENT","FINE / 132 PIXELS","MEDIUM / 99 PIXELS"][i]
  label.position=Vector2(16+i*320,15)
  root.add_child(label)
 await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/walk-v23"))
 root.get_texture().get_image().save_png("res://../artifacts/walk-v23/style-proof.png")
 quit()
