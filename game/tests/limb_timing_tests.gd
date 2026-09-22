extends SceneTree

# Source-art diagnostic for the late passing interval, not a runtime phase
# approximation. The old arm in-betweens left the swinging boot behind.
const Metrics = preload("whole_body_metrics.gd")
var checks := 0
var failures := 0

func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)

func swing_boot(image: Image) -> Vector2:
 var center := Vector2.ZERO
 var count := 0
 # Brown toe/shaft of the near, airborne boot. The planted far boot lies
 # below this region. Keep one fixed ROI for both endpoints and candidates.
 for y in range(875,1035):
  for x in range(620,885):
   var c := image.get_pixel(x,y)
   if c.a>.9 and c.r>.30 and c.r<.80 and c.g>.16 and c.g<.57 and c.b<.37 and c.r-c.g>.08:
    center+=Vector2(x,y); count+=1
 assert(count>1000,"Swing boot must remain visible in the diagnostic region")
 return center/count

func _initialize() -> void: run.call_deferred()

func run() -> void:
 # These source-coordinate measurements protect the archived anatomical
 # reference used to author the native pixel poses, not the smaller canvas.
 var path: String = "res://assets/art/gardener-v24/character.json"
 var args := OS.get_cmdline_user_args()
 if args.size()==2 and args[0]=="--manifest": path=args[1]
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
 var selected := {}
 for row in manifest.walk:
  var name: String=row.get("replaces_file",row.file).get_file().get_basename()
  if name in ["front-10","front-10a","front-10b","front-11"]:
   var image := Image.load_from_file(ProjectSettings.globalize_path(row.file))
   selected[name]={"hand":Metrics.near_hand(image),"boot":swing_boot(image)}
   if name in ["front-10a","front-10b"]:
    var original := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/gardener-v17/frames/"+name+".png"))
    check(image.get_region(Rect2i(0,0,1254,768)).get_data()==original.get_region(Rect2i(0,0,1254,768)).get_data(),"leg correction preserves head, face palette, torso and arm pixels: "+name)
 var first: Dictionary=selected["front-10"]
 var last: Dictionary=selected["front-11"]
 for name in ["front-10a","front-10b"]:
  var pose: Dictionary=selected[name]
  var hand_fraction: float=(pose.hand.x-first.hand.x)/(last.hand.x-first.hand.x)
  var boot_fraction: float=(pose.boot.x-first.boot.x)/(last.boot.x-first.boot.x)
  print(name," arm progress=",hand_fraction,"; swing boot progress=",boot_fraction,"; boot=",pose.boot)
  check(absf(hand_fraction-boot_fraction)<.20,"swinging foot should progress with the returning arm, not wait at the old leg pose: "+name)
  check(boot_fraction>0 and boot_fraction<1,"new boot pose lies between actual stride endpoints: "+name)
 print("Limb timing checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
