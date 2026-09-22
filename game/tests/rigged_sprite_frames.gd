extends RefCounted

# Experimental preview only. Consumes PNGs/JSON, not a skeleton or game save.
const PERIOD := 1.05
const STOP_START := 3.15
const STOP_SECONDS := .6
var metadata := {}
var textures := {}
var fit := 1.0
var heights := {}
var error := ""

func load_folder(folder: String) -> bool:
 if not folder.is_absolute_path(): return fail("Sprite folder must be an absolute path")
 var path := folder.path_join("capture.json")
 if not FileAccess.file_exists(path): return fail("Sprite capture metadata is missing")
 var decoded = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not decoded is Dictionary: return fail("Sprite metadata is not an object")
 metadata=decoded
 var dimensions = metadata.get("size",[])
 if not dimensions is Array or dimensions.size()!=2: return fail("Missing sprite dimensions in metadata")
 if not ((dimensions[0]==128.0 and dimensions[1]==160.0) or (dimensions[0]==256.0 and dimensions[1]==320.0)):
  return fail("Unsupported sprite dimensions in metadata")
 var frame_size := Vector2i(dimensions[0],dimensions[1])
 for key in ["anchors","stride_pixels","stop_advance_cycles"]:
  if not metadata.has(key): return fail("Missing sprite registration: "+key)
 if metadata.get("cycle_frames",0)!=63 or metadata.get("closing_frames",0)!=37 or metadata.stop_advance_cycles.size()!=37:
  return fail("Expected one 63-frame cycle and a 37-frame closing step")
 var clips := {"walk":63,"stop":37}
 if metadata.has("start_frames"):
  if metadata.start_frames!=31 or metadata.get("alternate_closing_frames",0)!=37 or metadata.get("start_seconds",0)!=.5 or metadata.get("start_advance_cycles",[]).size()!=31:
   return fail("Incomplete 60 Hz departure/alternate-stop registration")
  clips.merge({"start":31,"stop_half":37})
 var largest := 0.0
 for view in ["front","back"]:
  if not metadata.anchors.has(view) or not metadata.stride_pixels.has(view): return fail("Missing direction: "+view)
  textures[view]={}
  heights[view]=0.0
  for kind in clips:
   textures[view][kind]=[]
   for i in range(clips[kind]):
    path=folder.path_join(view).path_join("%s-%03d.png" % [kind,i])
    if not FileAccess.file_exists(path): return fail("Missing sprite: "+path)
    var frame := Image.load_from_file(path)
    if frame.is_empty() or frame.get_size()!=frame_size: return fail("Invalid sprite dimensions: "+path)
    var height := frame.get_used_rect().size.y
    if height<10: return fail("Empty character frame: "+path)
    heights[view]=maxf(heights[view],height)
    largest=maxf(largest,height)
    textures[view][kind].append(ImageTexture.create_from_image(frame))
 fit=32.0/largest
 return true

func fail(message: String) -> bool:
 error=message
 printerr(message)
 return false

func pose_packet(clip: String, index: int, rear := false) -> Dictionary:
 var view := "back" if rear else "front"
 var sequence: Array = textures[view][clip]
 var frame := clampi(index,0,sequence.size()-1)
 var texture: Texture2D = sequence[frame]
 var anchor := Vector2(metadata.anchors[view][0],metadata.anchors[view][1])
 var progress := frame/float(sequence.size()-1)
 var kind := "walk" if clip=="walk" else ("depart" if clip=="start" else ("idle" if frame==36 else "settle"))
 return {"texture":texture,"frame":frame,"offset":Vector2.ZERO,
  "destination":Rect2(-anchor*fit,texture.get_size()*fit),"visible_height":heights[view]*fit,
  "kind":kind,"progress":progress,"back":rear,"right":false,"pour":false,"settle_progress":progress}

func sample(seconds: float, rear := false) -> Dictionary:
 var view := "back" if rear else "front"
 var t := maxf(0,seconds)
 var walking := t<STOP_START
 var progress := clampf((t-STOP_START)/STOP_SECONDS,0,1)
 var frame := posmod(roundi(t*60),63) if walking else clampi(roundi(progress*36),0,36)
 var cycles := t/PERIOD
 if not walking:
  var index := progress*36
  var a := mini(floori(index),36)
  var b := mini(a+1,36)
  cycles=3+lerpf(metadata.stop_advance_cycles[a],metadata.stop_advance_cycles[b],index-a)
 var stride := Vector2(metadata.stride_pixels[view][0],metadata.stride_pixels[view][1])
 var packet := pose_packet("walk" if walking else "stop",frame,rear)
 packet.merge({"offset":stride*cycles*fit,"kind":"walk" if walking else ("settle" if progress<1 else "idle"),"progress":progress,"settle_progress":progress},true)
 return packet
