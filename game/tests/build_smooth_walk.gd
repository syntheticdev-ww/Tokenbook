extends SceneTree

# Offline registration and motion-based exposure. Runtime still draws one
# intact PNG and follows distance; there is no pixel morph or limb transform.
const Metrics = preload("whole_body_metrics.gd")

func boots(image: Image) -> Array[Vector2]:
 var points: Array[Vector2]=[]
 for y in range(880,1135,3):
  for x in range(325,885,3):
   var c := image.get_pixel(x,y)
   if c.a>.9 and c.r>.24 and c.r<.81 and c.g>.12 and c.g<.60 and c.r-c.g>.08 and c.g-c.b>.045:
    points.append(Vector2(x,y))
 assert(points.size()>200,"Boots must be measurable")
 var centers: Array[Vector2]=[Vector2(470,1030),Vector2(740,1030)]
 for iteration in range(10):
  var sums: Array[Vector2]=[Vector2.ZERO,Vector2.ZERO]
  var counts := [0,0]
  for p in points:
   var index := 0 if p.distance_squared_to(centers[0])<p.distance_squared_to(centers[1]) else 1
   sums[index]+=p; counts[index]+=1
  for i in 2:
   if counts[i]>0: centers[i]=sums[i]/counts[i]
 if centers[0].x>centers[1].x: centers.reverse()
 return centers

func _initialize() -> void:
 var fine := "--walk-v23" in OS.get_cmdline_user_args()
 var crossing := "--walk-v24" in OS.get_cmdline_user_args()
 var version := "v24" if crossing else ("v23" if fine else "v22")
 var previous := "v23" if crossing else ("v22" if fine else "v21")
 var base: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-"+previous+"/character.json"))
 var candidates: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-"+version+"/candidates.json"))
 var master := Metrics.inspect(Image.load_from_file(ProjectSettings.globalize_path(base.walk[0].file)))
 # Replace the overshooting arm and the two backward swing poses. Keep
 # originals on disk; corrected cels record their explicit parent/lineage.
 var originals := {}
 for row in base.walk+base.departure: originals[row.file]=row
 if crossing:
  # Duplicate and reversing in-betweens make the leg hang before crossing.
  # Replace the overly extended crossing cels; preserve archived PNGs.
  base.erase("presentation")
  base.walk=base.walk.filter(func(row: Dictionary):return not row.source_phase in [1.5,2.5,3.5,4.75,4.875,4.96875])
 elif not fine: base.walk=base.walk.filter(func(row: Dictionary):return not row.source_phase in [5.5,11.5,12.0])
 var departure_additions := {}
 for row in candidates:
  var image := Image.load_from_file(ProjectSettings.globalize_path(row.file))
  assert(image!=null and image.get_size()==Vector2i(1254,1254))
  var m := Metrics.inspect(image)
  var anchor: Vector2=Vector2(600,1120)+(m.eyes-master.eyes)*.5+(m.waist-master.waist)*.5
  var registered: Dictionary={"file":row.file,"anchor":[anchor.x,anchor.y],"sha256":FileAccess.get_sha256(row.file)}
  if row.mode=="legs" and originals.has(row.parent_file): registered.anchor=originals[row.parent_file].anchor
  if row.has("replaces_file"): registered.replaces_file=row.replaces_file
  if row.get("clip","")=="departure": departure_additions[int(row.between)]=registered
  else:
   registered.source_phase=row.phase
   base.walk.append(registered)
 if fine:
  var departure := []
  for i in base.departure.size():
   departure.append(base.departure[i])
   if departure_additions.has(i): departure.append(departure_additions[i])
  base.departure=departure
  base.presentation="farm-fine-v1"
 base.walk.sort_custom(func(a: Dictionary,b: Dictionary):return a.source_phase<b.source_phase)
 var landmarks := []
 for row in base.walk:
  var image := Image.load_from_file(ProjectSettings.globalize_path(row.file))
  var feet := boots(image)
  var hand := Metrics.near_hand(image)
  assert(hand.is_finite())
  landmarks.append({"feet":feet,"hand":hand})
 var gaps := []
 for i in base.walk.size():
  var a: Dictionary=landmarks[i]
  var b: Dictionary=landmarks[(i+1)%landmarks.size()]
  var distance: float=maxf(a.feet[0].distance_to(b.feet[0]),a.feet[1].distance_to(b.feet[1]))+.35*a.hand.distance_to(b.hand)
  gaps.append({"index":i,"distance":distance,"ticks":1})
 # 63 display intervals keep the existing 1.05 s cadence. Near-identical
 # passing poses take one interval; larger anatomical moves get two.
 # This removes the old slow-passing / abrupt-extension timing imbalance.
 if crossing:
  # Sorted left/right boot centroids exchange identity under occlusion.
  # That is not extra travel: never prolong the authored narrow passing
  # cels for this measurement artifact. Balance the two actual steps so
  # additional drawings cannot make one half of the gait slower.
  for half in range(2):
   var group := gaps.filter(func(gap: Dictionary):return int(base.walk[gap.index].source_phase/8)==half)
   var ordered := group.filter(func(gap: Dictionary):
    var p: float=base.walk[gap.index].source_phase
    return p<4.5 or p>=5.0)
   ordered.sort_custom(func(a: Dictionary,b: Dictionary):return a.distance>b.distance)
   var extra: int=(31 if half==0 else 32)-group.size()
   assert(extra>=0 and extra<=ordered.size())
   for i in range(extra): ordered[i].ticks=2
 else:
  var ordered := gaps.duplicate()
  ordered.sort_custom(func(a: Dictionary,b: Dictionary):return a.distance>b.distance)
  for i in range(63-base.walk.size()): ordered[i].ticks=2
 var tick := 0
 var report := []
 for i in base.walk.size():
  base.walk[i].phase=tick/63.0*16
  base.walk[i].ticks_to_next=gaps[i].ticks
  report.append({"file":base.walk[i].file,"source_phase":base.walk[i].source_phase,"phase":base.walk[i].phase,"ticks_to_next":gaps[i].ticks,"motion":gaps[i].distance,"left_boot":[landmarks[i].feet[0].x,landmarks[i].feet[0].y],"right_boot":[landmarks[i].feet[1].x,landmarks[i].feet[1].y],"hand":[landmarks[i].hand.x,landmarks[i].hand.y]})
  tick+=gaps[i].ticks
 assert(tick==63)
 var output := FileAccess.open("res://assets/art/gardener-"+version+"/character.json",FileAccess.WRITE)
 output.store_string(JSON.stringify(base,"  "))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/walk-"+version))
 var audit := FileAccess.open("res://../artifacts/walk-"+version+"/timing.json",FileAccess.WRITE)
 audit.store_string(JSON.stringify(report,"  "))
 print("Registered ",base.walk.size()," whole-character drawings across 63 weighted display intervals")
 quit()
