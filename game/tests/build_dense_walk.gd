extends SceneTree

# Register finalized intact authored images without altering their pixels or
# the previous manifests. Pixel protection is an offline Swift build step.
const Metrics = preload("whole_body_metrics.gd")
func _initialize() -> void:
 var base: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v20/character.json"))
 var candidates: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v21/candidates.json"))
 var master := Metrics.inspect(Image.load_from_file(ProjectSettings.globalize_path(base.walk[0].file)))
 for row in candidates:
  var image := Image.load_from_file(ProjectSettings.globalize_path(row.file))
  assert(image!=null and image.get_size()==Vector2i(1254,1254))
  var m := Metrics.inspect(image)
  var anchor: Vector2=Vector2(600,1120)+(m.eyes-master.eyes)*.5+(m.waist-master.waist)*.5
  base.walk.append({"file":row.file,"anchor":[anchor.x,anchor.y],"sha256":FileAccess.get_sha256(row.file),"phase":row.phase})
 base.walk.sort_custom(func(a: Dictionary,b: Dictionary):return a.phase<b.phase)
 # Equal exposure gives the three previously missing passing drawings time
 # to appear. The controller derives its unchanged join drawing from art.
 for i in base.walk.size():
  base.walk[i].source_phase=base.walk[i].phase
  base.walk[i].phase=float(i)*16/base.walk.size()
 var file := FileAccess.open("res://assets/art/gardener-v21/character.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(base,"  "))
 print("Registered ",base.walk.size()," intact walking poses; existing sources/departure untouched")
 quit()
