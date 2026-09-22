extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures.append(message)
  printerr("FAIL: ",message)

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 if not FileAccess.file_exists("res://gait.gd"):
  check(false,"the new gait must drive fixed-length limbs, opposite arms and planted feet")
  finish()
  return
 var gait = load("res://gait.gd")
 if not gait.has_method("depart"):
  check(false,"departure must connect a held standing pose to walking without a pose cut")
 else:
  var stand: Dictionary = gait.standing()
  var start: Dictionary = gait.depart(0)
  var end: Dictionary = gait.depart(1)
  var walk: Dictionary = gait.sample(0)
  var seam_error := 0.0
  for key in stand.joints:
   seam_error=maxf(seam_error,start.joints[key].distance_to(stand.joints[key]))
   seam_error=maxf(seam_error,end.joints[key].distance_to(walk.joints[key]))
  check(seam_error<.00001,"departure uses the exact standing and walking endpoint drawings")
  var support_slide := 0.0
  var reverse_travel := false
  var previous_z := 0.0
  for i in range(61):
   var pose: Dictionary = gait.depart(i/60.0)
   support_slide=maxf(support_slide,absf((pose.feet[1].ground+pose.root).z))
   reverse_travel=reverse_travel or pose.root.z<previous_z-.00001
   previous_z=pose.root.z
  check(support_slide<.00001 and not reverse_travel,"departure pushes off a planted trailing foot without backing up")
  var initial_speed: float = gait.depart(.001).root.z/.0005
  var final_speed: float = (end.root.z-gait.depart(.999).root.z)/.0005
  check(initial_speed<.001 and absf(final_speed-.52/1.05)<.002,"departure accelerates from rest into the existing walking speed")
 var a: Dictionary = gait.sample(0.0)
 var b: Dictionary = gait.sample(.5)
 check(a.joints.left_ankle.z > a.joints.right_ankle.z and b.joints.left_ankle.z < b.joints.right_ankle.z,"the second contact exchanges the actual leading leg")
 check(a.joints.left_wrist.z < a.joints.left_shoulder.z and b.joints.left_wrist.z > b.joints.left_shoulder.z,"the left arm passes behind and in front of its own shoulder")
 check(a.joints.right_wrist.z > a.joints.right_shoulder.z and b.joints.right_wrist.z < b.joints.right_shoulder.z,"the right arm counter-swings instead of following the left arm")
 var length_error := 0.0
 var slide := 0.0
 var penetration := 0.0
 var double_flight := false
 var sole_anchor_error := 0.0
 var max_step := 0.0
 for i in range(601):
  var cycle := i/120.0
  var p: Dictionary = gait.sample(cycle)
  var q: Dictionary = gait.sample(cycle+1.0/120)
  double_flight = double_flight or (not p.feet[0].contact and not p.feet[1].contact)
  for side in ["left","right"]:
   for pair in [["hip","knee",.35],["knee","ankle",.34],["shoulder","elbow",.21],["elbow","wrist",.19]]:
    var from: Vector3 = p.joints[side+"_"+pair[0]]
    var to: Vector3 = p.joints[side+"_"+pair[1]]
    length_error = maxf(length_error,absf(from.distance_to(to)-pair[2]))
  for leg in range(2):
   var f: Dictionary = p.feet[leg]
   var g: Dictionary = q.feet[leg]
   if f.contact and g.contact and f.step == g.step:
    slide = maxf(slide,(f.ground+p.root).distance_to(g.ground+q.root))
   penetration = minf(penetration,f.lift)
   if f.contact:
    var side := "left" if leg==0 else "right"
    var local_contact := Vector3(0,-gait.FOOT_HEIGHT,gait.TOE if f.pitch>=0 else -gait.HEEL)
    var contact: Vector3 = p.joints[side+"_ankle"]+Basis(Vector3.RIGHT,f.pitch)*local_contact
    var expected: Vector3 = f.ground+Vector3(0,0,local_contact.z)
    sole_anchor_error=maxf(sole_anchor_error,contact.distance_to(expected))
  for key in p.joints:
   max_step = maxf(max_step,p.joints[key].distance_to(q.joints[key]))
 check(length_error < .00005,"arm and leg lengths do not shrink, stretch or detach through a cycle")
 check(slide < .00001,"support feet keep a fixed world-ground anchor")
 check(sole_anchor_error<.00001,"the rotated sole heel/toe stays on its ground contact, not just its control point")
 check(not double_flight and penetration > -.00001,"walk keeps ground support and never drives a foot under the floor")
 check(max_step < .04,"all joints have bounded per-frame travel including cycle boundaries")
 var seam := 0.0
 for key in a.joints:
  seam = maxf(seam,a.joints[key].distance_to(gait.sample(1.0).joints[key]))
 check(seam < .00001,"loop joins the same whole-body pose without a cut")
 var settle_jump := 0.0
 var lead_slide := 0.0
 var final: Dictionary
 for start in [0.0,.5,2.0,2.5]:
  var initial: Dictionary = gait.sample(start)
  for i in range(61):
   var p: Dictionary = gait.settle(start,i/60.0)
   if i == 0:
    for key in initial.joints: settle_jump=maxf(settle_jump,p.joints[key].distance_to(initial.joints[key]))
   var lead := 0 if int(round(start*2))%2 == 0 else 1
   lead_slide=maxf(lead_slide,(p.feet[lead].ground+p.root).distance_to(initial.feet[lead].ground+initial.root))
   final=p
  check(absf(final.joints.left_ankle.z-final.joints.right_ankle.z)<.001,"closing step finishes with feet beside each other")
 check(settle_jump < .00001 and lead_slide < .00001,"closing step starts from the real walk pose and preserves its supporting foot")
 var closing_velocity: Vector3 = (gait.settle(0,.001).root-gait.settle(0,0).root)/.0006
 check(absf(closing_velocity.z-gait.STRIDE/gait.PERIOD)<.001,"closing step preserves incoming travel speed instead of braking for one frame")
 print("Motion metrics: bone length error=",length_error," m; stance slide=",slide," m; max 120Hz joint delta=",max_step," m; settle seam=",settle_jump)
 if not FileAccess.file_exists("res://character.gd"):
  check(false,"preview character must consume the tested gait through a real unified skin")
 else:
  var actor = load("res://character.gd").new()
  root.add_child(actor)
  var error := 0.0
  for cycle in [0.0,.17,.39,.5,.77,.99,1.0]:
   var pose: Dictionary = gait.sample(cycle)
   actor.apply_pose(pose)
   for key in pose.joints:
    var actual: Vector3 = actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(key)).origin
    error=maxf(error,actual.distance_to(pose.joints[key]))
  check(error<.00001,"rendered skeleton consumes every tested joint without additional offsets or per-limb scaling")
  var arrays: Array = actor.body.mesh.surface_get_arrays(0)
  var weight_error := 0.0
  var blended := 0
  var glued_arm_vertices := 0
  var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
  var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
  for i in range(0,weights.size(),4):
   weight_error=maxf(weight_error,absf(weights[i]+weights[i+1]+weights[i+2]+weights[i+3]-1))
   if weights[i+1]>.02: blended+=1
   var arm_weight := 0.0
   var hip_weight := 0.0
   for j in range(4):
    var bone_name: String = actor.skeleton.get_bone_name(bones[i+j])
    if bone_name.ends_with("elbow") or bone_name.ends_with("wrist"): arm_weight+=weights[i+j]
    if bone_name=="pelvis" or bone_name.ends_with("hip"): hip_weight+=weights[i+j]
   if arm_weight>.02 and hip_weight>.02: glued_arm_vertices+=1
  check(glued_arm_vertices==0,"rest skin does not glue forearms/hands to the shorts or thighs")
  # ArrayMesh stores each influence as UNORM16; allow one quantization unit
  # per channel, but still reject missing/unnormalized weights.
  check(arrays[Mesh.ARRAY_VERTEX].size()>1000 and weight_error<4.0/65535 and blended>100,"one continuous skin includes blended joints and normalized bone weights")
  print("Skin metrics: joint target error=",error," m; blended vertices=",blended," weight error=",weight_error," glued arm vertices=",glued_arm_vertices)
  actor.free()
 var args := OS.get_cmdline_user_args()
 if args.size()==1: verify_export(args[0])
 finish()

func verify_export(folder: String) -> void:
 var metadata = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("capture.json")))
 check(metadata is Dictionary and metadata.get("transparent",false) and metadata.get("fps",0)==60,"export declares transparent 60 FPS frames")
 for view in ["front","side","back"]:
  var unique := {}
  var valid := true
  var cropped := false
  var width := 0
  for i in range(100):
   var name := "walk-%03d.png" % i if i<63 else "stop-%03d.png" % (i-63)
   var path := folder.path_join(view).path_join(name)
   if not FileAccess.file_exists(path):
    valid=false
    continue
   var frame := Image.load_from_file(path)
   valid=valid and frame.get_size()==Vector2i(128,160) and frame.get_pixel(0,0).a==0
   var used := frame.get_used_rect()
   cropped=cropped or used.position.x<=0 or used.position.y<=0 or used.end.x>=128 or used.end.y>=160
   width=maxi(width,used.size.x)
   if i<63: unique[FileAccess.get_sha256(path)]=true
  check(valid and not cropped and width>20,"%s export contains every correctly sized transparent, unclipped walking/stopping frame" % view)
  check(unique.size()==63,"%s cycle has 63 distinct rendered frames, with no duplicated loop endpoint" % view)
  print("Export ",view,": ",unique.size()," unique walk frames; clipped=",cropped)

func finish() -> void:
 print("Motion lab checks: ",checks,", failures: ",failures.size())
 quit(0 if failures.is_empty() else 1)
