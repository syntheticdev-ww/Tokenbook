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
 if not FileAccess.file_exists("res://sprite_surface.gd"):
  check(false,"a continuous painted surface must preserve the illustrated silhouette while following the gait")
 else:
  var implementation = load("res://sprite_surface.gd")
  if implementation==null or not implementation.can_instantiate():
   check(false,"painted surface compiles before running deformation checks")
   quit(1)
   return
  var actor = implementation.new()
  root.add_child(actor)
  var camera := Camera3D.new()
  root.add_child(camera)
  camera.position=Vector3(3,2.604,5)
  camera.look_at(Vector3(0,.77,0))
  actor.set_camera(camera)
  var first: PackedVector3Array = actor.vertices_for(Gait.sample(0))
  var opposite: PackedVector3Array = actor.vertices_for(Gait.sample(.5))
  check(first.size()>1000 and first.size()==opposite.size(),"all phases deform the same connected source grid")
  check(actor.uvs.size()==first.size(),"every deformed vertex retains its source-art UV")
  var bad := 0
  for point in opposite:
   if not point.is_finite(): bad+=1
  check(bad==0,"the opposing step has no invalid surface positions")
  var pose_a := Gait.sample(.1)
  var pose_b := Gait.sample(.2)
  var sole := Vector2(337,949)
  var grounded_a: Vector3 = actor.source_to_world(sole,pose_a)+pose_a.root
  var grounded_b: Vector3 = actor.source_to_world(sole,pose_b)+pose_b.root
  check(grounded_a.distance_to(grounded_b)<.00001,"the support-foot drawing stays at the same world contact while the root advances")
  var eye_a := Vector2(404,221)
  var eye_b := Vector2(480,221)
  var span_a: float = actor.source_to_world(eye_a,pose_a).distance_to(actor.source_to_world(eye_b,pose_a))
  var span_b: float = actor.source_to_world(eye_a,pose_b).distance_to(actor.source_to_world(eye_b,pose_b))
  check(absf(span_a-span_b)<.00001,"the face keeps one fixed illustrated proportion throughout the walk")
  var edge_a: Vector3 = actor.source_to_world(Vector2(337,829.99),Gait.sample(.7))
  var edge_b: Vector3 = actor.source_to_world(Vector2(337,830.01),Gait.sample(.7))
  check(edge_a.distance_to(edge_b)<.00025,"ankle paint crosses the binding boundary continuously instead of shearing")
  var covered := {}
  for i in range(0,actor.indices.size(),6): covered[actor.sources[actor.indices[i]]]=true
  var lost := false
  for y in range(16,970):
   for x in range(205,715):
    if actor.paint.get_pixel(x,y).a<.6: continue
    var cell := Vector2(205+floori((x-205)/6.0)*6,16+floori((y-16)/6.0)*6)
    if not covered.has(cell): lost=true; break
   if lost: break
  check(not lost,"the source grid covers every visible pixel including thin hair strands")
  var bag_a := Vector2(550,525)
  var bag_b := Vector2(570,545)
  check(actor.pigment(bag_a).a>.6 and actor.pigment(bag_b).a>.6,"pouch registration probes must lie on actual opaque artwork")
  actor.rear=true
  check(actor.pigment(bag_a).a>.6 and actor.pigment(bag_b).a>.6,"the same probes also cover the painted rear pouch")
  actor.rear=false
  var bag_min := INF
  var bag_max := 0.0
  for i in range(63):
   var pose := Gait.sample(i/63.0)
   var length: float = actor.source_to_world(bag_a,pose).distance_to(actor.source_to_world(bag_b,pose))
   bag_min=minf(bag_min,length)
   bag_max=maxf(bag_max,length)
  check(bag_max-bag_min<.0001,"the utility pouch stays rigid on the pelvis rather than stretching with a nearby forearm")
  var pinned_skin := false
  for p in [Vector2(609,490),Vector2(615,490),Vector2(620,500)]:
   for entry in actor.bind_source(p):
    if entry.kind=="pouch" and entry.weight>.001: pinned_skin=true
  check(not pinned_skin,"the pouch mask must not pin adjacent forearm skin to the pelvis")
  actor.rear=true
  var rear_pinned := false
  for p in [Vector2(578,481),Vector2(577,484)]:
   for entry in actor.bind_source(p):
    if entry.kind=="pouch" and entry.weight>.001: rear_pinned=true
  check(not rear_pinned,"the narrower rear pouch must not capture the rear forearm outline")
  actor.free()
  camera.free()
 print("Painted-surface checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)
