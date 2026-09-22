extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func run() -> void:
 var previous := preload("whole_body_frames.gd").new()
 var ponytail := preload("whole_body_frames.gd").new()
 check(previous.load_manifest("res://assets/art/gardener-v16/frames/cycle.json"),"previous cycle is retained for comparison")
 check(ponytail.load_manifest("res://assets/art/gardener-v17/frames/cycle.json"),"ponytail cycle loads as complete character frames")
 if previous.error.is_empty() and ponytail.error.is_empty():
  for i in range(63):
   var a: Dictionary = previous.sample(i/60.0)
   var b: Dictionary = ponytail.sample(i/60.0)
   check(a.drawing==b.drawing and a.destination==b.destination and a.offset==b.offset,"removing a bun does not rescale, reposition or retime the character at sample %d" % i)
 print("Hairstyle animation regression checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
