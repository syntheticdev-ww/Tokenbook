extends SceneTree
func _initialize() -> void:
 var report: Dictionary={}
 for version in ["v56","v57"]:
  var path: String="res://assets/art/gardener-"+version+"/idle.png"
  var image:=Image.load_from_file(ProjectSettings.globalize_path(path))
  var low:=image.get_size()
  var high:=Vector2i.ZERO
  for y in image.get_height():
   for x in image.get_width():
    if image.get_pixel(x,y).a<.5:continue
    low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
  var foot_min:=image.get_width()
  var foot_max:=0
  for y in range(high.y-20,high.y+1):
   for x in image.get_width():
    if image.get_pixel(x,y).a>=.5:foot_min=mini(foot_min,x);foot_max=maxi(foot_max,x)
  report[version]={"size":[image.get_width(),image.get_height()],"bounds":[low.x,low.y,high.x-low.x+1,high.y-low.y+1],"foot_span":[foot_min,foot_max],"sha256":FileAccess.get_sha256(path)}
 var f:=FileAccess.open("res://../artifacts/character-reference-v57/source-metrics.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit()
