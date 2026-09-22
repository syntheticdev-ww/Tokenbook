extends SceneTree

var checks := 0
var failures := 0
const Controller = preload("res://farm_character.gd")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var art := preload("res://farm_character_art.gd").new()
 check(art.load_art(),"load real full-body character")
 var c := Controller.new()
 c.art=art; c.walk_to_plot(0)
 c.advance(.12)
 check(c.kind=="depart" and c.travelled>.25,"first stepping drawing already travels forward instead of stepping in place")
 c.advance(.13)
 check(c.travelled>1.2,"weight transfer advances the body before the first walking loop")
 var minimum_join_speed := INF
 while c.kind=="depart":
  c.advance(1.0/120)
  if c.kind=="walk": minimum_join_speed=c.velocity
 check(minimum_join_speed>10,"departure enters walking without resetting speed to zero")
 var settled_from := -1.0
 var stop_poses := {}
 var before_stop_speed := 0.0
 for i in range(600):
  var before_kind := c.kind
  var before := c.velocity
  c.advance(1.0/60)
  if c.kind=="settle":
   if settled_from<0: settled_from=c.travelled; before_stop_speed=before
   stop_poses[c.sprite().file]=true
   check(c.velocity<=before+.001,"closing step never accelerates again")
  if before_kind=="walk" and c.kind=="settle":
   check(c.velocity>5 and before_stop_speed>5,"last landing begins while the body is still moving")
  if c.kind=="idle": break
 check(c.travelled-settled_from>1.5,"closing step advances into the destination, not a stationary leg shuffle")
 check(stop_poses.size()>=4,"stop plays landing, transfer and closing poses before idle")
 check(c.position().is_equal_approx(Vector2(156,174)) and c.velocity==0,"closing step ends exactly at the work point with zero velocity")
 for seconds in [.01,.08,.16,.30,.33,.7,1.2,3.8]:
  c=Controller.new(); c.art=art; c.walk_to_plot(0); c.advance(seconds)
  var before := c.travelled
  var sprite: Dictionary=c.sprite()
  c.request_stop()
  check(c.travelled==before and c.sprite().file==sprite.file,"stop request changes neither position nor current drawing immediately")
  var previous := before
  var continuous := true
  for i in range(180):
   c.advance(1.0/60)
   continuous=continuous and c.travelled>=previous and c.travelled-previous<.5
   previous=c.travelled
  check(continuous and c.kind=="idle" and c.velocity==0,"interrupted first/regular step lands without a reverse hop, teleport or frozen velocity")
  if seconds<.32:
   check(c.travelled-before<3.0,"early cancellation brakes a small step, not an extra full walking cycle")
  if not c.arrived():
   check(c.walk_to_plot(0),"can resume after a partly completed first/last step")
  c.advance(20)
  check(c.position().is_equal_approx(Vector2(156,174)) and c.kind=="idle","resumed route still finishes exactly outside the bed")
 var at_60 := Controller.new()
 at_60.walk_to_plot(0)
 for i in range(150): at_60.advance(1.0/60)
 for rate in [30,120,144]:
  c=Controller.new(); c.walk_to_plot(0)
  for i in range(roundi(rate*2.5)): c.advance(1.0/rate)
  check(absf(c.travelled-at_60.travelled)<.001,"lifecycle movement stays time-based across rendering rates")
 c=Controller.new()
 var fastest := 0.0
 for i in range(22):
  if not c.walk_to_plot(0): break
  c.advance(.25)
  fastest=maxf(fastest,c.velocity)
  c.request_stop(); c.advance(1)
 check(fastest<25,"repeated short starts near the destination must not turn into a sprint")
 print("Character root motion checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
