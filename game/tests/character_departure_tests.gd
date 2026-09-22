extends SceneTree

var checks := 0
var failures := 0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var art := preload("res://farm_character_art.gd").new()
 check(art.load_art("res://assets/art/gardener-v24/character.json"),"load archived artwork for preservation checks")
 var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v19/character.json"))
 var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/gardener-v24/character.json"))
 var preserved: bool=current.transition==old.transition
 for source in old.walk:
  var found := false
  for row in current.walk:
   if row.file==source.file and row.sha256==source.sha256 and row.anchor==source.anchor: found=true
   elif row.get("replaces_file","")==source.file and row.anchor==source.anchor:
    var before := Image.load_from_file(ProjectSettings.globalize_path(source.file))
    var after := Image.load_from_file(ProjectSettings.globalize_path(row.file))
    found=before.get_region(Rect2i(0,0,1254,768)).get_data()==after.get_region(Rect2i(0,0,1254,768)).get_data()
  preserved=preserved and found
 check(preserved,"original registration and transitions are retained; explicit leg repairs preserve original upper-body pixels")
 for i in range(1,4):
  var original := Image.load_from_file(ProjectSettings.globalize_path(old.transition[i].file))
  var updated: Image=art.departure[i*2].texture.get_image()
  check(original.get_region(Rect2i(0,0,1254,768)).get_data()==updated.get_region(Rect2i(0,0,1254,768)).get_data(),"departure preserves all original head, skin, arms and upper-body pixels")
 check(art.load_art(),"load active character for actual departure and cancellation")
 var c := preload("res://farm_character.gd").new()
 c.art=art
 var joint: Dictionary=art.packet("walk",art.passing_phase,0)
 check(art.packet("depart",4.5,.90).file!=joint.file,"departure does not hold the first walking pose before its actual walking interval")
 c.walk_to_plot(0)
 var held := 0
 var seen := {}
 for i in range(40):
  c.advance(1.0/60)
  var sprite: Dictionary=c.sprite()
  if sprite.file==joint.file: held+=1
  if c.kind=="depart": seen[sprite.file]=true
 check(held<=6,"first walking pose should not stall for more than six display frames across the departure seam")
 check(seen.size()>=7,"departure displays all seven standing and intermediate poses before the shared walking endpoint")
 for seconds in [.01,.08,.10,.16,.18,.24,.25,.30]:
  c=preload("res://farm_character.gd").new(); c.art=art
  c.walk_to_plot(0); c.advance(seconds)
  var before: Dictionary=c.sprite()
  var point := c.position()
  c.request_stop()
  check(c.sprite().file==before.file,"cancelling a partial start reverses its own current drawing without swapping to another clip")
  c.advance(1)
  check(c.kind=="idle" and c.position().x<=point.x and c.position().distance_to(point)<3,"cancelled first step slows to idle without reversing or walking an extra stride")
  check(c.walk_to_plot(0) and c.sprite().file.ends_with("/idle.png"),"restart after cancellation begins cleanly from idle")
 print("Character departure checks: ",checks,", failures: ",failures,"; joined-pose hold: ",held," frames")
 quit(0 if failures==0 else 1)
