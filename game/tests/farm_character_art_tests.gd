extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not FileAccess.file_exists("res://farm_character_art.gd"):
  check(false,"the real game needs a whole-character art adapter for new idle, transition and walk poses")
 else:
  var art = load("res://farm_character_art.gd").new()
  check(art.load_art("res://assets/art/gardener-v24/character.json"),"archived v24 remains available with its original protected drawings")
  if art.error.is_empty():
   var idle: Dictionary = art.packet("idle",4.5,0)
   var start: Dictionary = art.packet("depart",4.5,0)
   var passing: Dictionary = art.packet("depart",4.5,1)
   var walk: Dictionary = art.packet("walk",art.passing_phase,0)
   var landing: Dictionary = art.packet("settle",4.5,1)
   var end: Dictionary = art.packet("settle",4.5,0)
   check(idle.file.ends_with("/idle.png") and idle.texture==start.texture and end.texture==idle.texture,"start/stop share the authored stationary endpoint")
   check(passing.texture==walk.texture and passing.destination==walk.destination and landing==passing,"transition joins the exact same registered passing drawing without a seam")
   var visible := {}
   for i in range(63):
    var packet: Dictionary = art.packet("walk",fposmod(art.passing_phase+i/63.0*16,16),0)
    visible[packet.file]=true
   check(visible.size()==48,"real-game adapter visits all forty-eight authored walk drawings at sixty Hz")
   var held := 0
   var longest := 0
   var previous := ""
   for i in range(126):
    var frame: Dictionary=art.packet("walk",art.passing_phase+i/63.0*16,0)
    held=held+1 if frame.file==previous else 1
    previous=frame.file
    longest=maxi(longest,held)
   check(longest<=2,"steady walking never holds a pose longer than two 60 Hz samples")
   check(art.packet("depart",4.5,.34).file.ends_with("depart-01.png") and art.packet("depart",4.5,.67).file.ends_with("depart-02.png"),"weight-shift keyframes are displayed rather than skipped")
   check(art.packet("idle",0,0).texture==idle.texture,"textures are cached instead of rebuilt on each 60 Hz sample")
   var reference: Image = passing.texture.get_image()
   var fixed_head := reference.get_region(Rect2i(0,0,1254,480)).get_data()
   for frame in art.transition.slice(0,3):
    var source: Image = frame.texture.get_image()
    check(source.get_region(Rect2i(0,0,1254,480)).get_data()==fixed_head,"new transition preserves exact original head pixels and face color: "+frame.file.get_file())
    check(frame.destination.position.distance_to(passing.destination.position)<.05,"transition registration stays within .05 world pixel of its walking endpoint")
   var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v24/character.json"))
   var hashes_match := true
   for frame in manifest.walk+manifest.transition+manifest.get("departure",[]):
    hashes_match=hashes_match and FileAccess.get_sha256(frame.file)==frame.sha256
   check(hashes_match,"runtime art matches every calibrated source hash; original walk assets remain unchanged")
   var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v20/character.json"))
   var protected_heads := true
   for frame in manifest.walk:
    if not frame.file.contains("gardener-v21"): continue
    var parent: Dictionary=original.walk[0]
    for candidate in original.walk:
     if candidate.phase<=frame.source_phase: parent=candidate
    var before := Image.load_from_file(ProjectSettings.globalize_path(parent.file))
    var after := Image.load_from_file(ProjectSettings.globalize_path(frame.file))
    protected_heads=protected_heads and before.get_region(Rect2i(0,0,1254,480)).get_data()==after.get_region(Rect2i(0,0,1254,480)).get_data()
   check(protected_heads,"all added poses preserve the original registered head and face pixels")
   var additions: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v22/candidates.json"))
   additions.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v23/candidates.json")))
   additions.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v24/candidates.json")))
   var protected_pixels := true
   for row in additions:
    var parent := Image.load_from_file(ProjectSettings.globalize_path(row.parent_file))
    var frame := Image.load_from_file(ProjectSettings.globalize_path(row.file))
    var height := 768 if row.mode=="legs" else 480
    var same_pixels := parent.get_region(Rect2i(0,0,1254,height)).get_data()==frame.get_region(Rect2i(0,0,1254,height)).get_data()
    if not same_pixels: printerr("Protected pixel mismatch: ",row.file)
    protected_pixels=protected_pixels and same_pixels
   check(protected_pixels,"targeted in-betweens preserve their original head or complete upper-body pixels")
   var ticks := 0
   var bounded := true
   var half_ticks := [0,0]
   var passing_ticks := 0
   for row in manifest.walk:
    ticks+=row.ticks_to_next
    half_ticks[int(row.source_phase/8)]+=row.ticks_to_next
    if row.source_phase>=4.5 and row.source_phase<5.0: passing_ticks+=row.ticks_to_next
    bounded=bounded and (row.ticks_to_next==1 or row.ticks_to_next==2)
   check(ticks==63 and bounded,"motion-weighted timing retains the 1.05-second cycle and bounded pose exposure")
   check(absi(half_ticks[0]-half_ticks[1])<=1,"left and right steps differ by at most one display interval")
   check(passing_ticks<=8,"occlusion in-betweens do not prolong crossing beyond eight display intervals")
   var hands := {}
   for row in manifest.walk:
    if row.source_phase in [5.0,5.5,6.0]:
     hands[row.source_phase]=preload("whole_body_metrics.gd").near_hand(Image.load_from_file(ProjectSettings.globalize_path(row.file))).x
   check(hands[5.0]>hands[5.5] and hands[5.5]>hands[6.0],"repaired returning hand stays between endpoints without overshooting then reversing")
   var original_colors := true
   for frame in art.walk+art.transition+art.departure:
    original_colors=original_colors and not frame.pixel_style
   check(original_colors,"idle, departure and walking retain source colors without palette or pixelization filters")
   var old_style = load("res://farm_character_art.gd").new()
   check(old_style.load_art("res://assets/art/gardener-v22/character.json") and not old_style.packet("idle",0,0).pixel_style,"archived art retains its original rendering for honest visual comparison")
   check(not art.load_art("res://missing-character.json") and art.walk.is_empty() and art.transition.is_empty() and art.departure.is_empty(),"failed loading cannot silently keep a stale character")
 check_native_pixels()
 print("Farm character art checks: ",checks,", failures: ",failures)
 quit(0 if failures==0 else 1)

func check_native_pixels()->void:
 var art=load("res://farm_character_art.gd").new()
 check(art.load_art("res://assets/art/gardener-v25/character.json"),"archived v25 pixel material remains inspectable")
 if not art.error.is_empty():return
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v25/character.json"))
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v24/character.json"))
 var idle:Dictionary=art.packet("idle",0,0)
 var master:Image=idle.texture.get_image()
 check(master.get_size()==Vector2i(112,112),"actual idle asset is native pixel-sized, not the old full-size illustration")
 var consistent:=true;var binary_alpha:=true;var hashes:=true;var same_head:=true
 for frame in art.walk+art.transition+art.departure:
  var image:Image=frame.texture.get_image()
  consistent=consistent and frame.native_pixels and not frame.pixel_style and image.get_size()==Vector2i(112,112)
  same_head=same_head and image.get_region(Rect2i(0,0,112,43)).get_data()==master.get_region(Rect2i(0,0,112,43)).get_data()
  for y in image.get_height():
   for x in image.get_width():
    var a:=image.get_pixel(x,y).a
    binary_alpha=binary_alpha and (a==0 or a==1)
 for row in manifest.walk+manifest.departure+manifest.transition:hashes=hashes and FileAccess.get_sha256(row.file)==row.sha256
 check(consistent,"every archived v25 pose uses native pixels with no palette or blur presentation")
 check(binary_alpha,"authored outlines contain no translucent gradient or colored halo")
 check(same_head,"eyes, face and head pixels remain identical across walking and departure")
 check(hashes,"all native pixel cels match their source manifest hashes")
 var timing:bool=manifest.walk.size()==old.walk.size()
 for i in mini(manifest.walk.size(),old.walk.size()):
  timing=timing and manifest.walk[i].phase==old.walk[i].phase and manifest.walk[i].ticks_to_next==old.walk[i].ticks_to_next
 check(timing,"restyling preserves the repaired 48-pose gait timeline")
 var visible:={};var held:=0;var longest:=0;var previous:=""
 for i in range(126):
  var frame:Dictionary=art.packet("walk",art.passing_phase+i/63.0*16,0)
  visible[frame.file]=true
  held=held+1 if previous==frame.file else 1
  longest=maxi(longest,held);previous=frame.file
 check(visible.size()==48 and longest<=2,"all pixel cels remain visible without introducing extra pose holds")
 check(art.packet("depart",0,0)==idle and art.packet("settle",0,0)==idle,"pixel idle is the shared beginning and ending drawing")
 check(art.packet("depart",0,1)==art.packet("walk",art.passing_phase,0),"departure and walking join the identical pixel drawing and anchor")
 check(art.packet("depart",0,.34).file==art.departure[2].file and art.packet("depart",0,.67).file==art.departure[4].file,"native transition retains the intermediate weight shifts")
 var min_height:=INF;var max_height:=0.0
 for frame in art.walk+art.departure:
  var height:float=frame.texture.get_image().get_used_rect().size.y*manifest.scale
  min_height=minf(min_height,height);max_height=maxf(max_height,height)
 check(min_height>29 and max_height<34,"new pixel figure retains its existing in-game scale")
