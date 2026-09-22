extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func run() -> void:
 if not FileAccess.file_exists("res://tests/whole_body_frames.gd"):
  check(false,"the candidate needs continuous full-cycle playback independent of the two-stop demo")
 else:
  var frames = load("res://tests/whole_body_frames.gd").new()
  check(frames.load_front(),"all selected whole-body source drawings load without an exported surface rig")
  if frames.error.is_empty():
   for seconds in [0.0,1.0,3.4,6.0,12.0,60.0]:
    var packet: Dictionary = frames.sample(seconds)
    check(packet.kind=="walk" and packet.source.size==packet.texture.get_size(),"continuous inspection never inserts a scheduled stop or detached limb at "+str(seconds))
   var start: Dictionary = frames.sample(0)
   var wrapped: Dictionary = frames.sample(10.5)
   check(start.texture==wrapped.texture and start.destination.is_equal_approx(wrapped.destination),"ten complete cycles return to the same registered pose without timing drift")
   var poses := {}
   for i in range(63): poses[frames.sample(i/60.0).drawing]=true
   check(poses.size()==16,"a full cycle actually plays every selected drawing rather than repeating a static arm pose")
   var sources := {}
   for name in frames.SELECTED:
    sources[FileAccess.get_sha256("res://assets/art/gardener-v14/"+name+".png")]=true
   check(sources.size()==16 and not sources.has(""),"the selected sequence has sixteen distinct source images, not duplicated files with different indices")
 print("Whole-body continuous checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
