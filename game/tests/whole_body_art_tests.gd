extends SceneTree

# Inspect source pixels, not generation prompts. A higher render FPS cannot
# satisfy these tests if authored silhouettes/palette still jump.
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)

const Metrics = preload("whole_body_metrics.gd")

func run() -> void:
 var metrics := []
 var missing := []
 var folder := ""
 var args := OS.get_cmdline_user_args()
 if args.size()==2 and args[0]=="--art": folder=args[1]
 var names: Array[String] = []
 if not folder.is_empty() and FileAccess.file_exists(folder.path_join("cycle.json")):
  var manifest = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("cycle.json")))
  for record in manifest.frames: names.append(record.file)
 else:
  for i in range(16): names.append("front-%02d.png" % i)
 for i in names.size():
  var path: String = folder.path_join(names[i]) if not folder.is_empty() else "res://assets/art/gardener-v14/"+preload("whole_body_selection.gd").FRONT[i]+".png"
  if not FileAccess.file_exists(path): missing.append(i); continue
  var source := Image.load_from_file(ProjectSettings.globalize_path(path))
  var info := Metrics.inspect(source)
  info.hand=Metrics.near_hand(source)
  metrics.append(info)
  print(names[i],": ",info)
  check(info.size==Vector2i(1254,1254),"candidate %02d uses the same source canvas for landmark calibration" % i)
  check(info.clear,"candidate %02d has actual alpha, not a painted background" % i)
  check(info.samples[1]>100 and info.samples[2]>100 and info.samples[3]>100,"candidate %02d retains readable eye, face and belt landmarks" % i)
 check(missing.is_empty(),"complete front cycle; missing drawings: "+str(missing))
 if missing.is_empty():
  var worst_skin := 0.0
  var worst_head := 0.0
  var worst_waist := 0.0
  var worst_floor := 0.0
  var worst_hand := 0.0
  var worst_pair := ""
  # Match the renderer's fixed calibration. A hairstyle edit changes the
  # silhouette height, not the body's scale or the world-space hand motion.
  var scale: float = preload("whole_body_frames.gd").SCALE
  for i in range(metrics.size()):
   var a: Dictionary = metrics[i]
   var b: Dictionary = metrics[(i+1)%metrics.size()]
   var correction: Vector2 = (b.eyes-a.eyes)*.5+(b.waist-a.waist)*.5
   worst_skin=maxf(worst_skin,a.face.distance_to(b.face))
   worst_head=maxf(worst_head,(b.head-a.head-correction).length()*scale)
   worst_waist=maxf(worst_waist,(b.waist-a.waist-correction).length()*scale)
   worst_floor=maxf(worst_floor,absf(a.bottom-metrics[0].bottom)*scale)
   var hand_jump: float = (b.hand-a.hand-correction).length()*scale
   if hand_jump>worst_hand: worst_hand=hand_jump;worst_pair=names[i]+" -> "+names[(i+1)%names.size()]
  print("Cycle source continuity: skin=",worst_skin," head=",worst_head," waist=",worst_waist," floor=",worst_floor," hand=",worst_hand)
  print("Largest hand transition: ",worst_pair)
  check(worst_skin<8,"adjacent skin palette must not flash when the drawing changes")
  check(worst_head<.35 and worst_waist<.35,"whole-drawing alignment can keep both head and waist stable")
  check(worst_floor<1,"stance silhouettes stay near the common ground line")
  check(worst_hand<2.0,"authored hand positions progress through an arc rather than snapping between front and back")
 print("Whole-body candidate checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
