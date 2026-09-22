extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func run() -> void:
 var folder := "res://assets/art/gardener-v16/frames"
 var args := OS.get_cmdline_user_args()
 if args.size()==2 and args[0]=="--art": folder=args[1]
 var frames := preload("whole_body_frames.gd").new()
 if not frames.has_method("load_manifest"):
  check(false,"authored occlusion in-betweens need phase-aware playback without replacing the old preview")
 else:
  check(frames.load_manifest(folder.path_join("cycle.json")),"the complete corrected art cycle loads")
  if frames.error.is_empty():
   var actual: Dictionary = frames.sample((10.0+1.0/3)/16*1.05)
   var reference := Image.load_from_file(ProjectSettings.globalize_path(folder.path_join("front-10a.png")))
   check(actual.texture.get_image().get_data()==reference.get_data(),"the inserted occlusion pose is actually drawn at its authored phase")
   var displayed := {}
   for i in range(63): displayed[frames.sample(i/60.0).drawing]=true
   check(displayed.size()==frames.textures.size(),"60 Hz playback does not silently skip the added key drawings")
   check(frames.sample(1.05*20).texture==frames.sample(0).texture,"the loop seam remains exact after twenty cycles")
   check(frames.sample(90).kind=="walk","continuous art review never schedules an unwanted stop")
   if not frames.has_method("step_time"):
    check(false,"manual review must visit inserted drawings instead of stepping over them")
   else:
    var at := 0.0
    for i in frames.phases.size():
     check(frames.sample(at).drawing==i,"manual stepping visits authored drawing %d" % i)
     at=frames.step_time(at,1)
    check(frames.sample(at).drawing==0,"manual stepping wraps to the first drawing")
    check(frames.sample(frames.step_time(0,-1)).drawing==frames.phases.size()-1,"backward stepping wraps to the final drawing")
   check(not frames.load_manifest("res://missing-tokenbook-cycle.json") and frames.textures.is_empty(),"a failed load cannot retain stale pictures from the preceding cycle")
 print("Phase-aware whole-body checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
