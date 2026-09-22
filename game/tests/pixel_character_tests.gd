extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)

func same_drawing(a: Dictionary, b: Dictionary) -> bool:
 return a.texture==b.texture and a.source==b.source and a.destination.is_equal_approx(b.destination)

func run() -> void:
 if not FileAccess.file_exists("res://tests/pixel_character_frames.gd"):
  check(false,"the default motion preview needs the original intact pixel character, not the deformed surface export")
 else:
  var frames = load("res://tests/pixel_character_frames.gd").new()
  for rear in [false,true]:
   var standing: Dictionary = frames.pose_packet("stop",36,rear)
   check(same_drawing(standing,frames.pose_packet("start",0,rear)),"departure starts from exactly the held standing drawing")
   check(same_drawing(frames.pose_packet("start",30,rear),frames.pose_packet("walk",0,rear)),"departure ends on the first walking drawing without an appearance swap")
   check(same_drawing(frames.pose_packet("stop",0,rear),frames.pose_packet("walk",0,rear)),"closing begins on the current contact drawing")
   check(same_drawing(standing,frames.pose_packet("stop_half",36,rear)),"both leading feet close to the same standing drawing")
   var cycle_sources := {}
   var intact := true
   for clip in {"walk":63,"start":31,"stop":37,"stop_half":37}:
    var count: int = {"walk":63,"start":31,"stop":37,"stop_half":37}[clip]
    for i in range(count):
     var packet: Dictionary = frames.pose_packet(clip,i,rear)
     var source: Rect2 = packet.source
     var destination: Rect2 = packet.destination
     intact = intact and source.has_area() and Rect2(Vector2.ZERO,packet.texture.get_size()).encloses(source)
     intact = intact and is_equal_approx(destination.size.x/source.size.x,destination.size.y/source.size.y)
     intact = intact and packet.back==rear and packet.art_source.begins_with("gardener-v")
     if clip=="walk": cycle_sources[str(source)]=true
   check(intact,"all clips keep complete original atlas cells at uniform scale without body deformation")
   check(cycle_sources.size()>=14,"walking retains the authored alternate-leg cycle instead of sliding one static drawing")
  var motion = load("res://character_motion.gd").new()
  motion.configure(frames.stride(false),frames.metadata)
  motion.begin()
  motion.advance(.5)
  check(motion.position.distance_to(frames.stride(false)*.19)<.0001,"pixel preview retains the continuous startup travel")
  motion.request_stop()
  motion.advance(2)
  check(motion.snapshot().kind=="idle","pixel preview supports the existing contact-stop lifecycle without exported surface PNGs")
 print("Pixel character checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
