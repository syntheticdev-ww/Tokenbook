extends SceneTree

var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)

func run() -> void:
 if not FileAccess.file_exists("res://lifecycle_export.gd"):
  check(false,"the character export needs departure and both leading-leg closing clips")
 else:
  var exporter = load("res://lifecycle_export.gd")
  var gait = load("res://gait.gd")
  var samples := [exporter.pose_at(137),exporter.pose_at(167),exporter.pose_at(100),exporter.pose_at(136)]
  var expected := [gait.standing(),gait.sample(0),gait.sample(.5),gait.standing()]
  for i in range(samples.size()):
   var seam := 0.0
   for key in samples[i].joints: seam=maxf(seam,samples[i].joints[key].distance_to(expected[i].joints[key]))
   check(seam<.00001,"departure/alternate closing exports preserve their exact whole-body endpoint")
  var args := OS.get_cmdline_user_args()
  if not args.is_empty():
   var folder: String = args[0]
   var data = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("capture.json")))
   check(data is Dictionary and data.get("start_advance_cycles",[]).size()==31 and data.get("alternate_closing_frames",0)==37,"export includes actual 60 Hz transition registration")
   for view in ["front","back"]:
    var valid := true
    for i in range(168):
     var path := folder.path_join(view).path_join(exporter.filename_at(i))
     if not FileAccess.file_exists(path): valid=false; continue
     var frame := Image.load_from_file(path)
     var box := frame.get_used_rect()
     valid=valid and frame.get_size()==Vector2i(256,320) and box.position.x>0 and box.position.y>0 and box.end.x<256 and box.end.y<320
    check(valid,"every "+view+" lifecycle frame is exported at fixed size without clipping")
    var base: String = folder.path_join(view)
    check(FileAccess.get_sha256(base.path_join("start-030.png"))==FileAccess.get_sha256(base.path_join("walk-000.png")),view+" departure ends on the exact walking pixels")
    check(FileAccess.get_sha256(base.path_join("start-000.png"))==FileAccess.get_sha256(base.path_join("stop-036.png")) and FileAccess.get_sha256(base.path_join("start-000.png"))==FileAccess.get_sha256(base.path_join("stop_half-036.png")),view+" either closing foot reaches the identical held standing drawing")
 print("Lifecycle export checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
