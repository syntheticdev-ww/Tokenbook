extends SceneTree

# Deterministic import only: key the generated sheet, crop empty padding and
# register intact drawings by their soles. The source artwork is preserved.
func _initialize() -> void:
 var base := "res://assets/art/desktop-pet-v1/"
 var sheet := Image.load_from_file(ProjectSettings.globalize_path(base+"source.png"))
 if sheet == null: quit(1); return
 var cell := Vector2i(sheet.get_width()/4,sheet.get_height()/3)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base+"frames"))
 var frames := []
 for i in range(12):
  var rect := Rect2i(Vector2i(i%4*cell.x,i/4*cell.y),cell)
  var frame := sheet.get_region(rect)
  frame.convert(Image.FORMAT_RGBA8)
  for y in range(cell.y):
   for x in range(cell.x):
    var c := frame.get_pixel(x,y)
    if minf(c.r,c.b)-c.g>.23 and c.r>.35 and c.b>.35:
     frame.set_pixel(x,y,Color.TRANSPARENT)
  var bounds := frame.get_used_rect()
  # Bottom 8px captures both soles; use their bounding center, not the
  # changing ponytail/arms or the entire silhouette center.
  var left := cell.x
  var right := 0
  for y in range(bounds.end.y-8,bounds.end.y):
   for x in range(cell.x):
    if frame.get_pixel(x,y).a>.5:
     left=mini(left,x);right=maxi(right,x)
  var anchor := Vector2((left+right)*.5,bounds.end.y)-Vector2(bounds.position)
  var cropped := frame.get_region(bounds)
  var file := "frames/%02d.png"%i
  if cropped.save_png(base+file)!=OK: quit(1);return
  var mask := BitMap.new()
  mask.create_from_image_alpha(cropped,.5)
  var polygons := mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,cropped.get_size()),2.0)
  var polygon := PackedVector2Array()
  var max_area := 0.0
  for candidate in polygons:
   var area := 0.0
   for j in candidate.size(): area+=candidate[j].cross(candidate[(j+1)%candidate.size()])
   if absf(area)>max_area: polygon=candidate;max_area=absf(area)
  var points := []
  for p in polygon: points.append([p.x,p.y])
  frames.append({"file":file,"anchor":[anchor.x,anchor.y],"polygon":points})
 var output := FileAccess.open(base+"animation.json",FileAccess.WRITE)
 output.store_string(JSON.stringify({"version":1,"scale":.57,"frames":frames},"  "))
 output.close()
 print("Pet import: ",frames.size()," complete keyed frames, soles and hit polygons")
 quit()
