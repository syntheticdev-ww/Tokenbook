extends RefCounted

# Offline art inspection only. Every packet draws one intact raster frame;
# playback never stretches or composites separate body parts.
const PERIOD := 1.05
const SCALE := 33.0/977.0
const SELECTED := preload("whole_body_selection.gd").FRONT
const Metrics = preload("whole_body_metrics.gd")
var error := ""
var textures: Array[Texture2D] = []
var corrections: Array[Vector2] = []
var measurements: Array[Dictionary] = []
var phases: Array[float] = []

func load_front() -> bool:
 var paths: Array[String] = []
 var points: Array[float] = []
 for i in SELECTED.size():
  paths.append("res://assets/art/gardener-v14/"+SELECTED[i]+".png")
  points.append(float(i))
 return _load(paths,points)

func fail(reason: String) -> bool:
 textures.clear(); corrections.clear(); measurements.clear(); phases.clear()
 error=reason
 return false

func load_manifest(path: String) -> bool:
 fail("")
 if not FileAccess.file_exists(path): return fail("Missing art manifest: "+path)
 var data = JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data is Dictionary or not data.get("frames") is Array:
  return fail("Invalid art manifest")
 if not is_equal_approx(float(data.get("period_seconds",0)),PERIOD) or data.get("phase_units")!=16:
  return fail("Unexpected cycle timing")
 var paths: Array[String] = []
 var points: Array[float] = []
 for record in data.frames:
  if not record is Dictionary or not record.get("file") is String:
   return fail("Invalid frame record")
  var name: String = record.file
  if name!=name.get_file() or not name.ends_with(".png"):
   return fail("Frame paths must be PNG basenames")
  if not record.get("phase") is float and not record.get("phase") is int:
   return fail("Missing frame phase")
  var point := float(record.phase)
  if not is_finite(point) or point<0 or point>=16 or (not points.is_empty() and point<=points[-1]):
   return fail("Frame phases must increase strictly within one cycle")
  paths.append(path.get_base_dir().path_join(name)); points.append(point)
 if points.is_empty() or points[0]!=0: return fail("A cycle needs phase zero")
 return _load(paths,points)

func _load(paths: Array[String],points: Array[float]) -> bool:
 textures.clear()
 corrections.clear()
 measurements.clear()
 error=""
 phases.assign(points)
 for name in paths:
  var path := ProjectSettings.globalize_path(name)
  var source := Image.load_from_file(path)
  if source==null or source.is_empty():
   return fail("Missing complete drawing: "+name)
  if source.get_size()!=Vector2i(1254,1254): return fail("Unexpected source canvas: "+name)
  var measured := Metrics.inspect(source)
  measurements.append(measured)
  textures.append(ImageTexture.create_from_image(source))
  var master: Dictionary = measurements[0]
  # Only one rigid translation of the COMPLETE person. A common scale keeps
  # head, arm and body volumes intact. Measurement is never run per frame.
  corrections.append((measured.eyes-master.eyes)*.5+(measured.waist-master.waist)*.5)
 return true

func step_time(seconds: float,direction: int) -> float:
 var index: int = sample(seconds).drawing
 return phases[posmod(index+signi(direction),phases.size())]/16.0*PERIOD

func sample(seconds: float) -> Dictionary:
 assert(not textures.is_empty() and textures.size()==phases.size(),"Load complete art before playback")
 var phase := fposmod(seconds/PERIOD,1.0)
 var drawing := 0
 var nearest := INF
 for i in phases.size():
  var difference := absf(phase*16-phases[i])
  difference=minf(difference,16-difference)
  if difference<nearest: nearest=difference; drawing=i
 var source := Rect2(Vector2.ZERO,textures[drawing].get_size())
 var anchor := Vector2(600,1120)+corrections[drawing]
 return {"texture":textures[drawing],"source":source,
  "destination":Rect2(-anchor*SCALE,source.size*SCALE),"drawing":drawing,
  "kind":"walk","progress":phase,"back":false,"right":false,
  "pour":false,"offset":Vector2.ZERO,"settle_progress":0.0}
