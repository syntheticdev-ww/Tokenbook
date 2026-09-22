extends RefCounted

# Runtime-only adapter: read authored PNGs + offline registration, then select
# one intact cached image. Never scan landmarks or reconstruct body parts.
var error := ""
var walk: Array[Dictionary] = []
var transition: Array[Dictionary] = []
var departure: Array[Dictionary] = []
var passing_phase := 4.5
var _cache := {}
var _scale := 33.0/977.0
var _pixel_style := false
var _native_pixels := false
var _canvas := Vector2i(1254,1254)
const DEFAULT_MANIFEST := "res://assets/art/gardener-v24/character.json"

func fail(message: String) -> bool:
 error=message
 passing_phase=4.5
 _pixel_style=false
 _native_pixels=false
 _canvas=Vector2i(1254,1254)
 _scale=33.0/977.0
 walk.clear(); transition.clear(); departure.clear(); _cache.clear()
 return false

func load_art(path := DEFAULT_MANIFEST) -> bool:
 fail("")
 if not FileAccess.file_exists(path): return fail("Missing character manifest: "+path)
 var data = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or (data.get("version")!=1 and data.get("version")!=2) or not data.get("walk") is Array or not data.get("transition") is Array:
  return fail("Invalid character manifest")
 if data.version==2:
  var canvas=data.get("canvas")
  if not canvas is Array or canvas.size()!=2 or canvas[0]!=112 or canvas[1]!=112 or data.get("sampling")!="nearest":return fail("Invalid native pixel canvas")
  var density=float(data.get("scale",0))
  if not is_finite(density) or density<.3 or density>.4:return fail("Invalid native pixel scale")
  _canvas=Vector2i(112,112);_scale=density;_native_pixels=true
 if data.walk.is_empty() or data.transition.size()<2 or not is_equal_approx(float(data.get("scale",0)),_scale):
  return fail("Invalid character scale or clips")
 var presentation = data.get("presentation","")
 if not presentation in ["","farm-fine-v1"]: return fail("Unknown character presentation")
 _pixel_style=presentation=="farm-fine-v1"
 var previous := -1.0
 for row in data.walk:
  if not row is Dictionary or not (row.get("phase") is float or row.get("phase") is int): return fail("Invalid walk phase")
  var phase := float(row.phase)
  if not is_finite(phase) or phase<0 or phase>=16 or phase<=previous: return fail("Unordered walk phases")
  var frame := read_frame(row)
  if frame.is_empty(): return fail(error)
  frame.phase=phase
  walk.append(frame); previous=phase
 if walk[0].phase!=0: return fail("Walk cycle must start at phase zero")
 for row in data.transition:
  var frame := read_frame(row)
  if frame.is_empty(): return fail(error)
  transition.append(frame)
 var departure_rows = data.get("departure",data.transition)
 if not departure_rows is Array or departure_rows.size()<2: return fail("Invalid departure clip")
 for row in departure_rows:
  var frame := read_frame(row)
  if frame.is_empty(): return fail(error)
  departure.append(frame)
 var joint: String = departure[-1].file
 var found_joint := false
 for frame in walk:
  if frame.file==joint:
   passing_phase=frame.phase
   found_joint=true
   break
 if not found_joint: return fail("Departure endpoint missing from walk cycle")
 return true

func read_frame(row: Variant) -> Dictionary:
 if not row is Dictionary or not row.get("file") is String or not row.get("anchor") is Array or row.anchor.size()!=2:
  error="Invalid character frame"; return {}
 var path: String = row.file
 if not path.begins_with("res://assets/art/") or "/../" in path or not path.ends_with(".png"):
  error="Character frames must be project art PNGs"; return {}
 for coordinate in row.anchor:
  if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or absf(float(coordinate))>2508:
   error="Invalid whole-character anchor"; return {}
 if not _cache.has(path):
  var image := Image.load_from_file(ProjectSettings.globalize_path(path))
  if image==null or image.get_size()!=_canvas: error="Missing or invalid character PNG: "+path; return {}
  _cache[path]=ImageTexture.create_from_image(image)
 return {"file":path,"texture":_cache[path],"source":Rect2(Vector2.ZERO,Vector2(_canvas)),
  "pixel_style":_pixel_style,"pixel_pitch":.25,"native_pixels":_native_pixels,
  "destination":Rect2(-Vector2(float(row.anchor[0]),float(row.anchor[1]))*_scale,Vector2(_canvas)*_scale)}

func packet(kind: String,phase: float,progress: float) -> Dictionary:
 assert(not walk.is_empty() and not transition.is_empty(),"Load character before drawing")
 # The joint belongs to walking. Do not show it early and then hold it a
 # second time when the regular walking cycle begins. Cancellation
 # reverses the very same clip, never jumps to an unrelated stop drawing.
 if kind=="depart" or kind=="cancel_depart":
  return departure[clampi(floori(clampf(progress,0,1)*(departure.size()-1)),0,departure.size()-1)]
 # Closing uses the extra near-overlap pose, avoiding the old backwards
 # heel kick between the planted passing leg and the relaxed stance.
 if kind=="settle":
  return departure[clampi(roundi(clampf(progress,0,1)*(departure.size()-1)),0,departure.size()-1)]
 if kind!="walk": return transition[clampi(roundi(clampf(progress,0,1)*(transition.size()-1)),0,transition.size()-1)]
 var closest := INF
 var selected_direction := -INF
 var selected := 0
 var wrapped := fposmod(phase,16)
 for i in walk.size():
  var direction := fposmod(walk[i].phase-wrapped+8,16)-8
  var distance := absf(direction)
  # Quantized authored timing often lands exactly on a midpoint at 60 Hz.
  # Resolve that tie forward around the cycle, including its wrap. Floating
  # point roundoff must not turn a two-sample exposure into a three-sample hold.
  if distance<closest-1e-7 or (absf(distance-closest)<=1e-7 and direction>selected_direction):
   closest=distance; selected=i; selected_direction=direction
 # Return only draw fields, so the shared passing endpoint is identical.
 var result: Dictionary = walk[selected].duplicate()
 result.erase("phase")
 return result
