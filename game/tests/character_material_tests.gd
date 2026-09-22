extends SceneTree

# Verify the actual source colors and the requested facial features.
# One grid and phase cover face and body. Visual review decides aesthetics.
const NATIVE_GRID := Vector2(160,188)
const BASE := Vector2(80,94)
# Keep the uniform sampling phase across face and body at both densities.
const SAMPLE := Vector2(.25,.25)
var captures:Array[Image]=[]

func _initialize() -> void: run.call_deferred()
func run() -> void:
 var passed:=true
 for density in [1,2]:
  if not await check_density(density):passed=false
 var mismatches:=0
 for y in range(captures[0].get_height()):
  for x in range(captures[0].get_width()):
   if captures[0].get_pixel(x,y)!=captures[1].get_pixel(x*2,y*2):mismatches+=1
 print("1x uses unchanged native cells: ",mismatches," mismatches")
 if mismatches>0:passed=false
 quit(0 if passed else 1)

func check_density(density: int,phase:=Vector2.ZERO) -> bool:
 var canvas:=Vector2i(BASE)*density
 root.size=canvas
 root.content_scale_size=canvas
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.transparent_bg=false
 var background:=Color("ece6d9")
 RenderingServer.set_default_clear_color(background)
 var card:=Control.new()
 card.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var material:=ShaderMaterial.new()
 material.shader=load("res://character_material.gdshader")
 var grid:=NATIVE_GRID
 var sample:=SAMPLE
 material.set_shader_parameter("grid_size",grid)
 material.set_shader_parameter("sample_offset",sample)
 material.set_shader_parameter("refined_face_sampling",false)
 material.set_shader_parameter("display_sampling_step",2.0/density)
 material.set_shader_parameter("display_sampling_offset",phase if density==1 else Vector2.ZERO)
 card.material=material
 var source:=Image.load_from_file("res://assets/art/gardener-v57/idle.png")
 var texture:=ImageTexture.create_from_image(source)
 card.draw.connect(func():card.draw_texture_rect(texture,Rect2(Vector2.ZERO,Vector2(canvas)),false))
 root.add_child(card)
 await process_frame
 RenderingServer.force_draw(false)
 var rendered:=root.get_texture().get_image()
 captures.append(rendered)
 var output:=OS.get_environment("TOKENBOOK_CAPTURE_DIR")
 if output.is_absolute_path():rendered.save_png(output.path_join("material-card.png" if density==2 else "material-card-1x.png"))
 var recolored:=0
 var edge_errors:=0
 var nonuniform:=0
 var cells:Dictionary={}
 # Check actual 1x/Retina canvas sizes. Every displayed pixel retains one
 # original source color, including the face, without a separate face phase.
 for y in range(canvas.y):
  for x in range(canvas.x):
   # Integer arithmetic is an independent oracle for the pixel-center cell.
   var cell:=Vector2i(x,y)*(2/density)+(Vector2i(phase) if density==1 else Vector2i.ZERO)
   var value:=rendered.get_pixel(x,y)
   if cells.has(cell) and cells[cell]!=value:nonuniform+=1
   cells[cell]=value
   var p:=Vector2i((Vector2(cell)+sample)/grid*Vector2(source.get_size()))
   var expected:=source.get_pixelv(p)
   if expected.a>=.5:
    if color_diff(expected,value)>1.0/255:recolored+=1
   elif color_diff(background,value)>1.0/255:edge_errors+=1
 var mouth:=[]
 var teeth:=[]
 var eyes:=[{"highlight":0,"pupil":0},{"highlight":0,"pupil":0}]
 for cell:Vector2i in cells:
  var point:=(Vector2(cell)+Vector2(.5,.5))/grid*BASE
  var value:Color=cells[cell]
  var chroma:=maxf(value.r,maxf(value.g,value.b))-minf(value.r,minf(value.g,value.b))
  # Facial regions follow the selected portrait's new canvas coordinates.
  if Rect2(31.5,22.9,5,2).has_point(point):
   if value.r>.30 and value.g<.52 and value.b<.48 and value.r-value.g>.12 and value.r-value.b>.08:mouth.append(cell)
   if value.r>.8 and value.g>.8 and value.b>.7 and chroma<.2:teeth.append(cell)
  for i in range(2):
   var eye:=Rect2(28,17,5.5,5) if i==0 else Rect2(34,17,5.5,5)
   if eye.has_point(point):
    if value.r>.75 and value.g>.70 and value.b>.65 and chroma<.18:eyes[i].highlight+=1
    if value.r<.6 and value.g<.4 and value.b<.25:eyes[i].pupil+=1
 var visible_eyes:bool=eyes[0].highlight>0 and eyes[0].pupil>0 and eyes[1].highlight>0 and eyes[1].pupil>0
 var passed:=nonuniform==0 and recolored==0 and edge_errors==0 and mouth.size()>=1 and teeth.is_empty() and visible_eyes
 var result:={"display_density":density,"downsample_phase":[phase.x,phase.y],"art_grid":[grid.x,grid.y],"physical_canvas":[canvas.x,canvas.y],"cell_screen_pixels":canvas.x/grid.x,"uniform_grid_errors":nonuniform,"original_rgb_errors":recolored,"transparent_edge_errors":edge_errors,"lip_cells":mouth.size(),"tooth_cells":teeth.size(),"eyes":eyes,"face_sampling_override":false,"passed":passed}
 print("Material render: ",JSON.stringify(result))
 if output.is_absolute_path():
  var f:=FileAccess.open(output.path_join("material-check-%dx.json"%density),FileAccess.WRITE)
  f.store_string(JSON.stringify(result,"  "));f.close()
 if not passed:printerr("Material rendering check failed")
 card.free()
 return passed

func color_diff(a:Color,b:Color) -> float:
 return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
