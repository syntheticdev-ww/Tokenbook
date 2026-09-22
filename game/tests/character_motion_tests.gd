extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)

func create_motion():
 var motion = load("res://character_motion.gd").new()
 motion.configure(Vector2(-10,5),{"start_advance_cycles":[0,.05,.19],"stop_advance_cycles":[0,.2,.31]})
 return motion

func run() -> void:
 if not FileAccess.file_exists("res://character_motion.gd"):
  check(false,"interactive character needs a continuous departure/walk/contact-stop lifecycle")
 else:
  var motion = create_motion()
  check(motion.snapshot().kind=="idle","new character holds a standing drawing until asked to walk")
  motion.begin()
  check(motion.snapshot().clip=="start" and motion.position==Vector2.ZERO,"starting selects departure without teleporting")
  motion.advance(.5)
  check(motion.snapshot().clip=="walk" and motion.snapshot().frame==0 and motion.position.distance_to(Vector2(-1.9,.95))<.00001,"departure advances by its measured distance and enters walk phase zero")
  motion.advance(.3)
  motion.request_stop()
  motion.advance(.22499)
  var before: Vector2 = motion.position
  check(motion.snapshot().kind=="walk","stop request waits for the next planted-foot contact")
  motion.advance(.00001)
  check(motion.snapshot().clip=="stop_half" and motion.position.distance_to(before)<.001,"half-cycle stop uses the other leading foot without moving the ground anchor")
  motion.advance(.6)
  check(motion.snapshot().kind=="idle" and motion.position.distance_to(Vector2(-10,5))<.0001,"closing reaches its registered endpoint and then holds still")
  motion.advance(5)
  check(motion.position.distance_to(Vector2(-10,5))<.0001,"idle does not loop or accumulate residual travel")
  motion.begin()
  check(motion.position.distance_to(Vector2(-10,5))<.0001,"repeated departure begins at the previous stop, not the original spawn")
  motion.advance(1.2)
  motion.request_stop()
  motion.advance(.35)
  check(motion.snapshot().clip=="stop","full-cycle stop selects the original leading foot")
  var a = create_motion()
  var b = create_motion()
  a.begin(); b.begin(); a.request_stop(); b.request_stop()
  a.advance(2)
  for i in range(120): b.advance(1.0/60)
  check(a.position.distance_to(b.position)<.0001 and a.snapshot()==b.snapshot(),"large frame deltas preserve time across departure, closing and idle")
  var c = create_motion()
  c.begin(); c.advance(.7); c.request_stop(); c.advance(.1)
  var held: Vector2 = c.position
  check(not c.begin() and c.position==held,"holding the start key cannot reset an ongoing stride")
  c.request_stop(); c.advance(.225)
  check(c.snapshot().clip=="stop_half","repeated stop requests do not postpone the pending planted-foot contact")
  var unchanged: Dictionary = c.snapshot()
  c.advance(-1)
  check(c.snapshot()==unchanged,"negative delta cannot rewind character state")
 print("Character lifecycle checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
