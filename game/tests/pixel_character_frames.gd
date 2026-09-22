extends RefCounted

# Art-direction integration candidate. Reuses intact authored pixel drawings;
# never bends a source painting or independently moves/scales body parts.
# The lifecycle runs at 60 Hz; that is NOT 60 newly authored poses per second.
const Art = preload("res://pixel_art.gd")
const Walk = preload("res://walk_art.gd")
const Motion = preload("res://character_motion.gd")
const FarmMotion = preload("res://farm_motion.gd")
var metadata := {"start_advance_cycles":[],"stop_advance_cycles":[]}

func _init() -> void:
 Walk.warm_cache()
 # Preserve the tested lifecycle's distances and endpoint velocities without
 # depending on the rejected surface character or its exported PNG folder.
 for i in range(31):
  var t := i/30.0
  metadata.start_advance_cycles.append(.19*(-2*t*t*t+3*t*t)+(t*t*t-t*t)*Motion.START_SECONDS/Motion.WALK_SECONDS)
 for i in range(37):
  var t := i/36.0
  metadata.stop_advance_cycles.append(.31*(-2*t*t*t+3*t*t)+(t*t*t-2*t*t+t)*Motion.STOP_SECONDS/Motion.WALK_SECONDS)

func stride(rear: bool) -> Vector2:
 return Vector2(1,-.5).normalized()*FarmMotion.STRIDE_DISTANCE*(1 if rear else -1)

func pose_packet(clip: String, index: int, rear := false) -> Dictionary:
 var sprite: Dictionary
 var kind := "walk"
 var progress := 0.0
 if clip=="walk":
  sprite=Walk.frame_at(posmod(index,63)/63.0*16,rear)
 elif clip=="start":
  progress=clampi(index,0,30)/30.0
  kind="depart"
  if progress<.5: sprite=Walk.settle_frame(1-progress*2,rear)
  else: sprite=Walk.frame_at(lerpf(14,16,(progress-.5)*2),rear)
 else:
  progress=clampi(index,0,36)/36.0
  kind="idle" if progress>=1 else "settle"
  var contact := 8.0 if clip=="stop_half" else 0.0
  if progress<.5: sprite=Walk.frame_at(contact+progress*6,rear)
  else: sprite=Walk.settle_frame((progress-.5)*2,rear)
 return {"texture":Art.texture(sprite.texture),"art_source":sprite.texture,"source":sprite.source,
  "destination":sprite.destination,"drawing":sprite.drawing,"frame":index,"offset":Vector2.ZERO,
  "kind":kind,"progress":progress,"back":rear,"right":false,"pour":false,"settle_progress":progress}
