extends RefCounted

# Visual lifecycle only: consumes measured sprite travel, never game rules,
# rewards or save state. Kept independent of the offline art-production rig.
const WALK_SECONDS := 1.05
const START_SECONDS := .5
const STOP_SECONDS := .6
var position := Vector2.ZERO
var stride := Vector2.ZERO
var _start_curve: Array = []
var _stop_curve: Array = []
var _kind := "idle"
var _origin := Vector2.ZERO
var _time := 0.0
var _cycle := 0.0
var _stop_cycle := INF
var _other_foot := false

func configure(stride_vector: Vector2, metadata: Dictionary) -> void:
 stride=stride_vector
 _start_curve=metadata.start_advance_cycles.duplicate()
 _stop_curve=metadata.stop_advance_cycles.duplicate()

func begin() -> bool:
 if _kind!="idle": return false
 _origin=position
 _kind="depart"
 _time=0
 _cycle=0
 _stop_cycle=INF
 _other_foot=false
 return true

func request_stop() -> void:
 if not is_inf(_stop_cycle): return
 if _kind=="depart": _stop_cycle=0
 elif _kind=="walk": _stop_cycle=(floorf(_cycle*2+1e-7)+1)*.5

func advance(delta: float) -> void:
 if not is_finite(delta) or delta<=0: return
 var remaining := delta
 while remaining>1e-10 and _kind!="idle":
  if _kind=="walk":
   var take := remaining if is_inf(_stop_cycle) else minf(remaining,maxf(0,(_stop_cycle-_cycle)*WALK_SECONDS))
   _cycle+=take/WALK_SECONDS
   remaining-=take
   position=_origin+stride*_cycle
   if not is_inf(_stop_cycle) and _cycle>=_stop_cycle-1e-8:
    _cycle=_stop_cycle
    position=_origin+stride*_cycle
    _origin=position
    _kind="settle"
    _time=0
    _other_foot=posmod(roundi(_cycle*2),2)==1
   else: return
  else:
   var duration := START_SECONDS if _kind=="depart" else STOP_SECONDS
   var take := minf(remaining,duration-_time)
   _time+=take
   remaining-=take
   var curve := _start_curve if _kind=="depart" else _stop_curve
   position=_origin+stride*curve_at(curve,_time/duration)
   if _time>=duration-1e-8:
    _time=duration
    position=_origin+stride*float(curve[-1])
    _origin=position
    if _kind=="depart":
     _kind="walk"
     _time=0
    else: _kind="idle"

func snapshot() -> Dictionary:
 var clip := "walk"
 var progress := 0.0
 var frame := 0
 if _kind=="walk": frame=posmod(roundi(_cycle*63),63)
 elif _kind=="depart":
  clip="start"
  progress=clampf(_time/START_SECONDS,0,1)
  frame=clampi(roundi(progress*30),0,30)
 else:
  clip="stop_half" if _other_foot else "stop"
  progress=1.0 if _kind=="idle" else clampf(_time/STOP_SECONDS,0,1)
  frame=clampi(roundi(progress*36),0,36)
 return {"kind":_kind,"clip":clip,"frame":frame,"progress":progress}

static func curve_at(values: Array, progress: float) -> float:
 var index := clampf(progress,0,1)*(values.size()-1)
 var a := mini(floori(index),values.size()-1)
 var b := mini(a+1,values.size()-1)
 return lerpf(values[a],values[b],index-a)
