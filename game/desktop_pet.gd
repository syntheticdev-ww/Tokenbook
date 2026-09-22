extends Control

signal pressed(event: InputEvent)
signal silhouette_changed(polygon: PackedVector2Array)

const BASE := "res://assets/art/desktop-pet-v1/"
var clock := 0.0
var frame_index := -1
var frames := []
var art_scale := .57
var hit_polygon := PackedVector2Array()
var _foot := Vector2.ZERO

func _ready() -> void:
 name="DesktopGardener"
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 material=preload("res://sprite_raster.gd").coverage_material()
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"animation.json"))
 art_scale=float(data.scale)
 for entry in data.frames:
  var polygon := PackedVector2Array()
  for point in entry.polygon: polygon.append(Vector2(point[0],point[1]))
  var source:=Image.load_from_file(ProjectSettings.globalize_path(BASE+entry.file))
  frames.append({"texture":ImageTexture.create_from_image(source),"anchor":Vector2(entry.anchor[0],entry.anchor[1]),"polygon":polygon})
 set_clock(clock)

# Visual companionship only. This loop never creates jobs or awards crops.
static func pose_at(time: float) -> int:
 var t := fposmod(time,12.0)
 if t<5.0: return 0
 if t<5.72: return [1,2,3][mini(2,int((t-5.0)/.24))]
 if t<10.52:
  var cycle := [3,4,5,6,7,8,3,3]
  return cycle[int((t-5.72)/.20)%cycle.size()]
 if t<11.24: return [3,2,1][mini(2,int((t-10.52)/.24))]
 return 0

func set_clock(value: float) -> void:
 clock=value
 if frames.is_empty(): return
 var next := pose_at(clock)
 if next==frame_index: return
 frame_index=next
 _foot=Vector2(size.x*.5,size.y-10)
 var frame: Dictionary=frames[frame_index]
 hit_polygon=PackedVector2Array()
 for p in frame.polygon: hit_polygon.append(_foot+(p-frame.anchor)*art_scale)
 silhouette_changed.emit(hit_polygon)
 queue_redraw()

func _has_point(point: Vector2) -> bool:
 return Geometry2D.is_point_in_polygon(point,hit_polygon)

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  pressed.emit(event)

func _draw() -> void:
 if frame_index<0: return
 var frame: Dictionary=frames[frame_index]
 draw_texture_rect(frame.texture,Rect2(_foot-frame.anchor*art_scale,frame.texture.get_size()*art_scale),false)
