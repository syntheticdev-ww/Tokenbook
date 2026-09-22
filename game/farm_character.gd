extends RefCounted

# Opt-in front-route integration. Visual movement owns no farm rewards/save.
const Geometry = preload("res://farm_geometry.gd")
const PERIOD := 1.05
const NOMINAL_STRIDE := 19.5
const DEPART := .32
const ACCELERATE := .12
const SETTLE := .42
const PASS_PHASE := 4.5
var kind := "idle"
var elapsed := 0.0
var velocity := 0.0
var travelled := 0.0
var stop_requested := false
var art: RefCounted
var _path := Geometry.route(Geometry.HOME,Geometry.work_point(0))
var _length := Geometry.HOME.distance_to(Geometry.work_point(0))
var _origin := 0.0
var _start := 0.0
var _depart_distance := 0.0
var _walk_end := 0.0
var _finish := 0.0
var _stride := NOMINAL_STRIDE
var _settle_from := 1.0
var _cancel_departure := false
var _settle_start := 0.0
var _settle_velocity := 0.0
var _settle_duration := SETTLE

func position() -> Vector2:
 return Geometry.along(_path,travelled/_length)

func busy() -> bool: return kind!="idle"
func arrived() -> bool: return travelled>=_length-.001

func walk_to_plot(id: int) -> bool:
 if id!=0 or busy() or arrived(): return false
 _start=travelled
 _finish=_length
 # Reserve distance for the actual opening and closing steps. The middle
 # keeps its authored cadence and complete cycles, landing at the shared
 # passing drawing. Its phase can change when the clip gets denser.
 var ramps := (DEPART-ACCELERATE*.5+SETTLE*.5)/PERIOD
 # A short resumed route still gets a shortened cycle, not a zero-cycle
 # plan which would squeeze the remaining distance into a fast launch.
 var cycles := maxi(1,roundi((_length-travelled)/NOMINAL_STRIDE-ramps))
 _stride=(_length-travelled)/(cycles+ramps)
 _depart_distance=_stride/PERIOD*(DEPART-ACCELERATE*.5)
 _origin=_start+_depart_distance
 _walk_end=_finish-_stride/PERIOD*SETTLE*.5
 kind="depart"; elapsed=0; velocity=0; stop_requested=false
 _cancel_departure=false
 return true

func reset_home() -> bool:
 if busy(): return false
 travelled=0; _origin=0; elapsed=0; velocity=0; stop_requested=false
 return true

func request_stop() -> void:
 if stop_requested or kind=="idle" or kind=="settle": return
 stop_requested=true
 if kind=="depart":
  var progress := transition_progress()
  _begin_settle(progress,lerpf(.10,.28,progress),true)
 else:
  # Stop on the next authored passing pose; never freeze a wide mid-step.
  var cycle := floorf((travelled-_origin)/_stride+1e-7)+1
  _walk_end=minf(_walk_end,_origin+cycle*_stride)

func advance(delta: float) -> void:
 if not is_finite(delta) or delta<=0: return
 var remaining := delta
 while remaining>1e-8 and busy():
  var dt := minf(remaining,1.0/120)
  remaining-=dt
  _step(dt)

func _step(delta: float) -> void:
 if delta<=1e-8 or not busy(): return
 var speed := _stride/PERIOD
 if kind=="depart":
  var used := minf(delta,DEPART-elapsed)
  elapsed+=used
  var u := clampf(elapsed/ACCELERATE,0,1)
  # Integral of smoothstep velocity: first-pose movement starts immediately,
  # with continuous velocity/acceleration at both ends, not a second launch.
  var ramp_distance := ACCELERATE*(u*u*u-.5*u*u*u*u)
  travelled=_start+speed*(ramp_distance+maxf(0,elapsed-ACCELERATE))
  velocity=speed*smoothstep(0,1,u)
  if elapsed>=DEPART-1e-8:
   travelled=_origin; velocity=speed; kind="walk"; elapsed=0
   if _walk_end-travelled<1e-8: _begin_settle(1,SETTLE,false)
  _step(delta-used)
 elif kind=="walk":
  var used := minf(delta,maxf(0,_walk_end-travelled)/speed)
  travelled+=speed*used
  velocity=speed
  if _walk_end-travelled<1e-8:
   travelled=_walk_end
   _begin_settle(1,SETTLE,false)
  _step(delta-used)
 else:
  var used := minf(delta,_settle_duration-elapsed)
  elapsed+=used
  var u := clampf(elapsed/_settle_duration,0,1)
  travelled=lerpf(_settle_start,_finish,2*u-2*u*u*u+u*u*u*u)
  velocity=_settle_velocity*(1-smoothstep(0,1,u))
  if elapsed>=_settle_duration-1e-8:
   travelled=_finish; velocity=0; kind="idle"; elapsed=0

func _begin_settle(progress: float,duration: float,partial_start: bool) -> void:
 _settle_from=progress
 _cancel_departure=partial_start
 _settle_duration=duration
 _settle_start=travelled
 _settle_velocity=velocity
 _finish=minf(_length,travelled+velocity*duration*.5)
 kind="settle"; elapsed=0

func walk_phase() -> float:
 var join_phase: float=art.passing_phase if art!=null else PASS_PHASE
 return fposmod(join_phase+(travelled-_origin)/_stride*16,16)

func transition_progress() -> float:
 if kind=="depart": return clampf(elapsed/DEPART,0,1)
 if kind=="settle": return _settle_from*(1-clampf(elapsed/_settle_duration,0,1))
 return 0.0

func pose() -> Dictionary:
 return {"kind":kind,"back":false,"right":false,"pour":false,"breath":1.0}

func sprite() -> Dictionary:
 return art.packet("cancel_depart" if kind=="settle" and _cancel_departure else kind,walk_phase(),transition_progress())
