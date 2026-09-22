extends Node2D

const Art = preload("res://pixel_art.gd")
const WORLD := Vector2(384,342)
const LANDSCAPE := "farm-background-landscape-v3"
var clock := 0.0
var extend_edges := false
var pixel_grid_density := 0.0 # Zero follows the window's physical pixel ratio.
var landscape_texture: Texture2D
var crisp_pixel_motion := true
var _air: Node2D

func _ready() -> void:
 name="LivingFarmBackground"
 show_behind_parent=true
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var background_material := ShaderMaterial.new()
 background_material.shader=preload("res://farm_environment.gdshader")
 material=background_material
 if extend_edges:
  landscape_texture=Art.texture(LANDSCAPE)
 _air=Node2D.new()
 _air.name="ChimneyAndMeadowAir"
 _air.draw.connect(_draw_air)
 add_child(_air)

func sync(time: float,offset: Vector2,zoom: Vector2) -> void:
 clock=time
 position=offset
 scale=zoom
 material.set_shader_parameter("world_time",time)
 material.set_shader_parameter("crisp_pixel_motion",extend_edges and crisp_pixel_motion)
 # Preserve source detail on Retina: align to physical pixels, without the
 # second, coarser logical-pixel reduction. Geometry stays in world units.
 var window := get_window()
 var density := pixel_grid_density
 if density<=0:
  density=maxf(1.0,float(window.size.y)/maxi(1,window.content_scale_size.y))
 material.set_shader_parameter("pixel_grid_zoom",zoom*density if extend_edges else Vector2.ZERO)
 material.set_shader_parameter("pixel_grid_offset",offset*density)
 queue_redraw()
 _air.queue_redraw()

func _draw() -> void:
 # The wider painting keeps its registered world rect. The parent camera
 # projects the same world coordinates as paths, actors and click targets.
 material.set_shader_parameter("world_origin",Vector2(-78,0) if extend_edges else Vector2.ZERO)
 material.set_shader_parameter("world_size",Vector2(512,342) if extend_edges else WORLD)
 if extend_edges:
  draw_texture_rect(landscape_texture,Rect2(-78,0,512,342),false)
 else:
  draw_texture_rect(Art.texture("farm-background-cohesive-v2"),Rect2(Vector2.ZERO,WORLD),false)

func _draw_air() -> void:
 # Expanding reflections provide readable motion in open water at 384px.
 for i in range(2):
  var age := fposmod(clock*.22+i*.5,1.0)
  var center := Vector2(105,111) if i==0 else Vector2(79,118)
  var radius := 1.0+age*6.0
  var arc := PackedVector2Array()
  for j in range(19):
   var angle := j/18.0*TAU
   arc.append(center+Vector2(cos(angle)*radius,sin(angle)*radius*.30))
  _air.draw_polyline(arc,Color(.82,.93,.83,sin(age*PI)*.36),.65,true)
 # A few translucent, widening puffs from the existing chimney, carried by
 # the same slow breeze. No particle emitters, allocation or random popping.
 for i in range(8):
  var age := fposmod(clock*.16+i/8.0,1.0)
  var opacity := sin(age*PI)*.68*smoothstep(0,.12,age)
  var chimney := Vector2(304,44) if extend_edges else Vector2(324,43)
  var point := chimney+Vector2(-age*15+sin(clock*.65+i*.9)*age*1.5,-age*34)
  var radius := 1.0+age*4.5
  _air.draw_circle(point,radius,Color(.90,.91,.85,opacity*.22))
  _air.draw_circle(point+Vector2(-radius*.18,0),radius*.72,Color(.94,.94,.88,opacity*.65))
  _air.draw_circle(point+Vector2(radius*.30,-radius*.08),radius*.47,Color(.96,.95,.89,opacity*.30))
 # Small daylight butterflies stay beside flowers, not over the beds/UI.
 for i in range(2):
  var cycle := fposmod(clock+i*6.7,17.0)
  var opacity := smoothstep(0,1,cycle)*(1-smoothstep(7,9,cycle))
  if opacity<=0: continue
  var center := Vector2(181,139) if i==0 else Vector2(49,290)
  var point := center+Vector2(sin(clock*.51+i*2)*7,cos(clock*.73+i)*2.6)
  var wing := .45+absf(sin(clock*11.0+i))*.95
  var color := Color(.98,.85,.48,opacity*.84) if i==0 else Color(.98,.95,.79,opacity*.80)
  _air.draw_colored_polygon(PackedVector2Array([point,point+Vector2(-wing,-1.0),point+Vector2(-wing*.8,1.0),point+Vector2(0,.5)]),color)
  _air.draw_colored_polygon(PackedVector2Array([point,point+Vector2(wing,-.8),point+Vector2(wing*.8,1.1),point+Vector2(0,.5)]),color)
  _air.draw_line(point+Vector2(0,-.5),point+Vector2(0,1),Color(.34,.32,.18,opacity*.8),.45)
