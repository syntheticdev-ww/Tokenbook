extends SceneTree

# Read-only landmark report for selecting authored in-betweens.
const Metrics = preload("whole_body_metrics.gd")
func _initialize() -> void:
 var base: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v20/character.json"))
 var candidates_path := "res://assets/art/gardener-v21/candidates.json"
 if "--candidates" in OS.get_cmdline_user_args():
  base.walk=JSON.parse_string(FileAccess.get_file_as_string(candidates_path))
 var rows := []
 for row in base.walk:
  var image := Image.load_from_file(ProjectSettings.globalize_path(row.file))
  var m := Metrics.inspect(image)
  var hand := Metrics.near_hand(image)
  rows.append({"file":row.file,"phase":row.phase,"eyes":[m.eyes.x,m.eyes.y],"waist":[m.waist.x,m.waist.y],"hand":[hand.x,hand.y],"face":[m.face.x,m.face.y,m.face.z]})
 var name := "candidate-landmarks" if "--candidates" in OS.get_cmdline_user_args() else "landmarks"
 var file := FileAccess.open("res://../artifacts/walk-v21/"+name+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(rows,"  "))
 print("Measured ",rows.size()," original poses")
 quit()
