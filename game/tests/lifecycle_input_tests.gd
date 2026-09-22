extends "lifecycle_farm_preview.gd"

var checks := 0
var failures := 0
var checking := false
func _initialize() -> void:
 super._initialize()
 verify.call_deferred()
func _process(delta: float) -> bool:
 return false if checking else super._process(delta)
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func key(code: Key) -> void:
 var event := InputEventKey.new()
 event.keycode=code
 event.pressed=true
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 event=InputEventKey.new()
 event.keycode=code
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func verify() -> void:
 checking=true
 check(not demo,"default preview inspects sustained walking rather than scheduling two automatic stops")
 advance_scene(12)
 check(motion.snapshot().kind=="walk","default inspection is still walking after more than ten complete cycles")
 key(KEY_ENTER)
 motion.advance(2)
 check(motion.snapshot().kind=="idle","continuous inspection still honors an explicit manual stop")
 key(KEY_W)
 advance_scene(12)
 check(motion.snapshot().kind=="walk","manual restart remains continuous rather than triggering the short walkway guard")
 configure_motion()
 demo=false
 key(KEY_W)
 check(motion.snapshot().kind=="depart","native W input starts the departure clip")
 super._process(.1)
 key(KEY_SPACE)
 var held := motion.position
 super._process(.1)
 check(playback_paused and motion.position==held,"pause freezes the actual lifecycle clock")
 key(KEY_SPACE)
 key(KEY_ENTER)
 motion.advance(1)
 check(motion.snapshot().kind=="idle","stop requested during departure completes a planted-foot closing")
 var previous := rear
 key(KEY_B)
 check(rear!=previous and motion.position==Vector2.ZERO and motion.snapshot().kind=="idle","direction preview resets explicitly to its standing pose")
 key(KEY_R)
 advance_scene(6)
 check(motion.snapshot().kind=="idle" and motion.position.length()>5,"complete demo actually executes two starts and closes without resetting between them")
 key(KEY_C)
 advance_scene(12)
 update_scene()
 check(continuous and not demo and motion.snapshot().kind=="walk" and farm.packet.offset==Vector2.ZERO,"C separates sustained pose inspection from world-travel start/stop testing")
 key(KEY_ENTER)
 motion.advance(2)
 capture_dir="capture-input-guard"
 begin_walk()
 check(motion.snapshot().kind=="idle","clicking start must not change deterministic export playback")
 configure_motion()
 motion.begin()
 stop_walk()
 motion.advance(1)
 check(motion.snapshot().kind=="walk","clicking stop must not change deterministic export playback")
 start_loop()
 capture_clock=0
 capture_frame=60
 super._process(0)
 var first_capture_position := motion.position
 super._process(1)
 check(motion.position.is_equal_approx(first_capture_position),"rendering one export timestamp twice does not advance the character twice")
 capture_frame=120
 super._process(0)
 check(motion.position.distance_to(first_capture_position+frames.stride(rear)/Motion.WALK_SECONDS)<.0001,"continuous capture advances by timestamp delta, not absolute timestamp")
 capture_dir=""
 print("Lifecycle input checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
