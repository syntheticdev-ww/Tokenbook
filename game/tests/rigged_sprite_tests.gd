extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
 checks+=1
 if not value:
  failures+=1
  printerr("FAIL: ",message)

func run() -> void:
 if not FileAccess.file_exists("res://tests/rigged_sprite_frames.gd"):
  check(false,"farm preview needs a 2D-only player for exported, ground-registered frames")
 else:
  var frames = load("res://tests/rigged_sprite_frames.gd").new()
  var args := OS.get_cmdline_user_args()
  var folder: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../artifacts/surface-gait-v7-sprites")
  var loaded: bool = frames.load_folder(folder)
  check(loaded,"load all exported frames and registration metadata without opening a game save")
  if loaded:
   if frames.metadata.has("start_frames"):
    check(frames.has_method("pose_packet"),"the 2D player must expose the exported departure and alternate closing clips")
    if frames.has_method("pose_packet"):
     for back in [false,true]:
      var start: Dictionary = frames.pose_packet("start",0,back)
      var start_end: Dictionary = frames.pose_packet("start",30,back)
      var walk_start: Dictionary = frames.pose_packet("walk",0,back)
      var alternate: Dictionary = frames.pose_packet("stop_half",36,back)
      check(start.texture.get_image().get_data()==alternate.texture.get_image().get_data(),"either leading foot can stop and restart on the same standing pixels")
      check(start_end.texture.get_image().get_data()==walk_start.texture.get_image().get_data() and start_end.destination==walk_start.destination,"departure-to-walk preserves both pixels and ground registration")
   for rear in [false,true]:
    var first: Dictionary = frames.sample(0,rear)
    var opposite: Dictionary = frames.sample(.525,rear)
    var seam: Dictionary = frames.sample(1.05,rear)
    var before: Dictionary = frames.sample(3.15-.0001,rear)
    var closing: Dictionary = frames.sample(3.15,rear)
    var standing: Dictionary = frames.sample(3.75,rear)
    var hold: Dictionary = frames.sample(5,rear)
    check(first.frame!=opposite.frame,"half cycle really exchanges the rendered drawing")
    check(first.frame==seam.frame and first.texture==seam.texture,"cycle wrap reuses the exact whole-body drawing")
    check(before.offset.distance_to(closing.offset)<.01,"2D closing starts at the same ground position as walking")
    check(standing.offset.is_equal_approx(hold.offset) and standing.texture==hold.texture,"completed closing holds still instead of cycling feet")
    check(absf(absf(seam.offset.y/seam.offset.x)-.5)<.002,"exported walking direction matches the farm's 2:1 ground projection")
    var height: float = first.visible_height
    check(height>=28 and height<=34,"candidate fits the existing farm's character height")
   check(frames.sample(.1,false).offset.x<0 and frames.sample(.1,true).offset.x>0,"front/rear routes travel in their actual facing directions")
   var reference = load("res://tests/rigged_farm_preview.gd").CandidateFarm.new()
   reference.packet=frames.sample(4,true)
   reference.animation_time=4
   var held: Dictionary = reference.actor_sprite()
   var expected: Dictionary = load("res://walk_art.gd").settle_frame(1,true)
   check(held.texture==expected.texture and held.source==expected.source,"rear comparison holds its closing drawing instead of switching to a front-facing idle")
   reference.free()
 print("2D farm player checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
