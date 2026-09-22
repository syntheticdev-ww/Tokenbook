extends SceneTree

const Gait = preload("gait.gd")
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
 checks+=1
 if not value:
  failures+=1
  printerr("FAIL: ",message)

func run() -> void:
 if not FileAccess.file_exists("res://painted_character.gd"):
  check(false,"the art candidate must retain the continuous skeleton and safe skin binding")
 else:
  var actor = load("res://painted_character.gd").new()
  root.add_child(actor)
  check(actor.skeleton.get_bone_count()==18 and actor.body.mesh!=null,"art candidate initializes the complete base rig before binding paint")
  if actor.skeleton.get_bone_count()!=18 or actor.body.mesh==null:
   actor.free()
   quit(1)
   return
  var joint_error := 0.0
  for i in range(127):
   var pose: Dictionary = Gait.sample(i/63.0)
   actor.apply_pose(pose)
   for name in pose.joints:
    var actual: Vector3 = actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(name)).origin
    joint_error=maxf(joint_error,actual.distance_to(pose.joints[name]))
  check(joint_error<.00001,"art refinement keeps every tested body joint on the existing smooth gait")
  var arrays: Array = actor.body.mesh.surface_get_arrays(0)
  var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
  var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
  var arm_bridges := 0
  var bad_weights := 0
  for i in range(0,bones.size(),4):
   var arm := 0.0
   var hip := 0.0
   var total := 0.0
   for j in range(4):
    var name: String = actor.skeleton.get_bone_name(bones[i+j])
    if name.ends_with("elbow") or name.ends_with("wrist"): arm+=weights[i+j]
    if name=="pelvis" or name.ends_with("hip"): hip+=weights[i+j]
    total+=weights[i+j]
   if arm>.02 and hip>.02: arm_bridges+=1
   if absf(total-1)>4.0/65535: bad_weights+=1
  check(arm_bridges==0,"detail pass never glues the hands back onto the waist")
  check(bad_weights==0,"detail pass has normalized skin weights throughout the surface")
  var builder = load("res://painted_mesh.gd").new()
  builder.build(actor.rest,actor.ids)
  var paint := Image.load_from_file("res://assets/character-paint-v1.png")
  var bow_uv: Vector2 = builder.paint_point(Vector3(.087,1.43,-.165),"head",false)
  var bow := paint.get_pixelv(Vector2i(bow_uv))
  check(bow.g>bow.r*1.1,"the physical teal bow samples ribbon paint, not adjacent brown hair")
  var boot_uv: Vector2 = builder.paint_point(Vector3(-.105,.15,.025),"left_ankle",false)
  var boot := paint.get_pixelv(Vector2i(boot_uv))
  check(boot.r>boot.g*1.25 and boot.g<.65,"upper leather boot samples leather, not the cream sock above it")
  check(builder.has_method("taper_distance"),"hair-lock surface supports a continuous taper instead of a constant-radius lump")
  if builder.has_method("taper_distance"):
   var lock := {"a":Vector3.ZERO,"b":Vector3(0,1,0),"radius_a":.06,"radius_b":.015}
   check(absf(builder.taper_distance(Vector3(.03,.5,0),lock)+.0075)<.00001,"hair-lock width interpolates continuously along its length")
   check(builder.taper_distance(Vector3(.025,1,0),lock)>.009,"the small tip does not inherit the thick root radius")
  print("Paint landmarks: bow=",bow," boot=",boot)
  print("Refined skin: joint error=",joint_error,"; arm bridges=",arm_bridges)
  actor.free()
 print("Art candidate checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
