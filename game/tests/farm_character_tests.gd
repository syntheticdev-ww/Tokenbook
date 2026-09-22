extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func run() -> void:
 if not FileAccess.file_exists("res://farm_character.gd"):
  check(false,"new whole-body character needs finite real farm movement, not an in-place preview")
 else:
  var Controller = load("res://farm_character.gd")
  var c = Controller.new()
  var geometry = load("res://farm_geometry.gd")
  check(c.kind=="idle" and c.position()==Vector2(228,138),"new character stands at the actual farmhouse")
  c.advance(30)
  check(c.kind=="idle" and c.position()==Vector2(228,138),"no automatic movement or scheduled preview stop")
  check(not c.walk_to_plot(7),"unimplemented rear/other routes are rejected explicitly")
  check(c.walk_to_plot(0) and not c.walk_to_plot(0),"first field starts one finite journey; repeated clicks do not restart it")
  var states := {}
  var previous: Vector2 = c.position()
  var no_jump := true
  var on_path := true
  var phases := {}
  for i in range(900):
   c.advance(1.0/60)
   states[c.kind]=true
   var p: Vector2 = c.position()
   no_jump=no_jump and p.distance_to(previous)<.5
   on_path=on_path and geometry.plot_at(p)==-1 and absf(p.y-(252-p.x*.5))<.01
   if c.kind=="walk": phases[roundi(c.walk_phase()*100)]=true
   previous=p
  check(states.has("depart") and states.has("walk") and states.has("settle") and states.has("idle"),"finite journey includes start, walk, settle and idle")
  check(no_jump and on_path,"world movement remains continuous on the actual lane, outside planted beds")
  check(phases.size()>50,"gait advances with travel instead of a static transported sprite")
  check(c.position().is_equal_approx(Vector2(156,174)) and c.kind=="idle","automatic arrival lands exactly at the first plot's work point")
  var end: Vector2 = c.position()
  c.advance(30)
  check(c.position()==end and c.kind=="idle","arrival remains stopped until another user action")
  check(c.reset_home() and c.position()==Vector2(228,138),"explicit reset returns to the farmhouse")
  c.walk_to_plot(0)
  c.advance(.07)
  var before: Vector2 = c.position()
  c.request_stop()
  c.advance(2)
  check(c.kind=="idle" and c.position().x<=before.x and c.position().distance_to(before)<1,"cancelling the opening step brakes gently without a reverse hop or extra stride")
  c.walk_to_plot(0)
  c.advance(1.2)
  before=c.position()
  c.request_stop()
  check(c.position()==before and not c.reset_home(),"stop request never teleports; reset is disabled while moving")
  c.advance(3)
  check(c.kind=="idle" and c.position().x>156 and c.position().x<228,"mid-route stop settles before the destination")
  check(c.walk_to_plot(0),"a stopped character can resume toward the same destination")
  c.advance(30)
  check(c.position().is_equal_approx(Vector2(156,174)),"resume finishes at the target without overshoot")
  before=c.position()
  c.advance(NAN);c.advance(-1)
  check(c.position()==before,"invalid elapsed time cannot corrupt position")
 print("Farm character motion checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
