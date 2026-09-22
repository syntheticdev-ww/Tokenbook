extends SceneTree

# Offline asset preparation only. CoreGraphics round-trips premultiplied
# edges; restore the exact straight-alpha upper-body bytes using Godot's
# PNG decoder before hashing the new assets. Never touch earlier art.
func _initialize() -> void:
 var version := ""
 for argument in OS.get_cmdline_user_args():
  if argument in ["--walk-v22","--walk-v23","--walk-v24"]: version="gardener-"+argument.trim_prefix("--walk-")
 if not version.is_empty():
  var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/"+version+"/candidates.json"))
  for row in rows:
   assert(row.file.begins_with("res://assets/art/"+version+"/frames/"))
   var parent := Image.load_from_file(ProjectSettings.globalize_path(row.parent_file))
   var frame := Image.load_from_file(ProjectSettings.globalize_path(row.file))
   var height := 768 if row.mode=="legs" else 480
   frame.blit_rect(parent,Rect2i(0,0,1254,height),Vector2i.ZERO)
   if row.mode!="legs":
    frame.blit_rect(parent,Rect2i(0,480,475,70),Vector2i(0,480))
    frame.blit_rect(parent,Rect2i(746,480,508,70),Vector2i(746,480))
   assert(frame.save_png(ProjectSettings.globalize_path(row.file))==OK)
  print("Restored exact protected RGBA in ",rows.size()," ",version," cels")
  quit(); return
 var path := "res://assets/art/gardener-v20/character.json"
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 for i in range(1,4):
  var row: Dictionary=manifest.departure[i]
  assert(row.file=="res://assets/art/gardener-v20/frames/depart-%02d.png"%i)
  var original := Image.load_from_file(ProjectSettings.globalize_path(manifest.transition[i].file))
  var image := Image.load_from_file(ProjectSettings.globalize_path(row.file))
  assert(original.get_size()==Vector2i(1254,1254) and image.get_size()==original.get_size())
  image.blit_rect(original,Rect2i(0,0,1254,768),Vector2i.ZERO)
  assert(image.save_png(ProjectSettings.globalize_path(row.file))==OK)
  row.sha256=FileAccess.get_sha256(row.file)
 var file := FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  ")); file.close()
 print("Restored exact original upper-body RGBA, including translucent edges, in three new departure sprites")
 quit()
