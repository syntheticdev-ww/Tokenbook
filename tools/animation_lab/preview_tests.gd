extends "preview.gd"

var checking := false
var failures := 0
var checks := 0

func _initialize() -> void:
 super._initialize()
 run_checks.call_deferred()

func _process(delta: float) -> bool:
 return false if checking else super._process(delta)

func key(code: Key) -> void:
 var event := InputEventKey.new()
 event.keycode=code
 event.pressed=true
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 event=InputEventKey.new()
 event.keycode=code
 event.pressed=false
 Input.parse_input_event(event)
 Input.flush_buffered_events()

func check(value: bool, message: String) -> void:
 checks+=1
 if not value:
  failures+=1
  printerr("FAIL: ",message)

func run_checks() -> void:
 checking=true
 phase=0
 key(KEY_SPACE)
 check(playback_paused,"native input relay delivers space to pause")
 key(KEY_S)
 check(slow,"native input relay delivers slow playback")
 key(KEY_RIGHT)
 check(is_equal_approx(phase,1/(60.0*Gait.PERIOD)),"paused arrow advances exactly one 60 Hz sample")
 phase=.49
 key(KEY_ENTER)
 check(stop_at==.5,"a stop request queues the next alternating contact")
 playback_paused=false
 slow=false
 super._process(1.0/60)
 var expected := (.49+1/(60.0*Gait.PERIOD)-.5)*Gait.PERIOD/Gait.SETTLE_PERIOD
 check(is_equal_approx(closing,expected) and phase==.5,"queued stop carries frame overshoot into the closing motion")
 key(KEY_RIGHT)
 check(playback_paused and is_equal_approx(closing,expected+1/(60.0*Gait.SETTLE_PERIOD)) and phase==.5,"scrubbing a closing step stays on that transition instead of jumping back to walk")
 key(KEY_P)
 check(views[0].size==Vector2i(160,200),"pixel preview changes sampling resolution without changing pose")
 key(KEY_R)
 check(phase==0 and closing<0 and is_inf(stop_at) and not playback_paused,"replay resets only prototype playback state")
 print("Preview input/timing checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
