extends SceneTree

# Offline calibration only. Runtime reads these anchors, never scans source
# pixels or recomputes registration while opening the game window.
const Metrics = preload("whole_body_metrics.gd")
var master: Dictionary
func record(path: String) -> Dictionary:
 var image := Image.load_from_file(ProjectSettings.globalize_path(path))
 assert(image!=null and image.get_size()==Vector2i(1254,1254))
 var measured := Metrics.inspect(image)
 var correction: Vector2 = (measured.eyes-master.eyes)*.5+(measured.waist-master.waist)*.5
 var anchor := Vector2(600,1120)+correction
 return {"file":path,"anchor":[anchor.x,anchor.y],"sha256":FileAccess.get_sha256(path)}
func _initialize() -> void:
 master=Metrics.inspect(Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/gardener-v17/frames/front-00.png")))
 var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v17/frames/cycle.json"))
 var walk := []
 for frame in source.frames:
  var entry := record("res://assets/art/gardener-v17/frames/"+frame.file)
  entry.phase=frame.phase
  walk.append(entry)
 var transition := []
 for name in ["idle","depart-01","depart-02"]:
  transition.append(record("res://assets/art/gardener-v18/frames/"+name+".png"))
 transition.append(record("res://assets/art/gardener-v17/frames/front-04a.png"))
 var output := "res://assets/art/gardener-v18/character.json"
 assert(not FileAccess.file_exists(output),"Do not overwrite an earlier art calibration")
 var file := FileAccess.open(output,FileAccess.WRITE)
 file.store_string(JSON.stringify({"version":1,"production_eligible":false,"scale":33.0/977.0,"walk":walk,"transition":transition},"  "))
 file.close()
 print("Calibrated runtime character manifest: 19 walk and 4 transition poses")
 quit()
