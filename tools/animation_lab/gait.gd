extends RefCounted

# One cycle is two alternating steps. All positions are metres, independent
# of display FPS and camera direction. +Z is forward; no texture/frame switching.
const STRIDE := .52
const PERIOD := 1.05
const SETTLE_PERIOD := .6
const DEPART_PERIOD := .5
const STANCE := .62
const THIGH := .35
const SHIN := .34
const UPPER_ARM := .21
const FOREARM := .19
const FOOT_HEIGHT := .06
const TOE := .105
const HEEL := .05

static func sample(cycles: float) -> Dictionary:
 var feet: Array[Dictionary] = []
 for leg in range(2):
  var at := cycles+leg*.5
  var phase := fposmod(at,1.0)
  var ground := Vector3((-.105 if leg == 0 else .105),0,0)
  var lift := 0.0
  var pitch := 0.0
  if phase < STANCE:
   ground.z = STRIDE*(STANCE*.5-phase)
   pitch = -.08*(1-smoothstep(0,.11,phase))+.19*smoothstep(.46,STANCE,phase)
  else:
   var t := (phase-STANCE)/(1-STANCE)
   var half := STRIDE*STANCE*.5
   # Match support velocity at both ends: no toe-off or landing speed cut.
   var tangent := -STRIDE*(1-STANCE)
   ground.z = hermite(-half,half,tangent,tangent,t)
   lift = .048*pow(sin(PI*t),2)
   pitch = lerpf(.19,-.08,smoothstep(0,1,t))
  feet.append({"ground":ground,"lift":lift,"pitch":pitch,
   "contact":phase<STANCE,"step":floori(at),"phase":phase})
 return compose(cycles,feet,Vector3(0,0,cycles*STRIDE),1.0)

static func settle(start_cycle: float, progress: float) -> Dictionary:
 # The preview schedules stopping at the next double-support contact, then
 # carries the body over that planted foot while the trailing foot closes.
 var start := sample(start_cycle)
 var t := clampf(progress,0,1)
 var ease := smoothstep(0,1,t)
 var lead := 0 if posmod(roundi(start_cycle*2),2)==0 else 1
 var feet: Array[Dictionary] = []
 # Preserve incoming root velocity at the first closing frame; smoothstep
 # alone would brake instantly before accelerating again into the stop.
 var advance := hermite(0,start.feet[lead].ground.z,STRIDE/PERIOD*SETTLE_PERIOD,0,t)
 for leg in range(2):
  var foot: Dictionary = start.feet[leg].duplicate(true)
  if leg != lead:
   foot.ground.z = lerpf(foot.ground.z,start.feet[lead].ground.z,ease)
   foot.lift = .038*pow(sin(PI*t),2)
   foot.contact = t == 0 or t == 1
  foot.ground.z -= advance
  foot.pitch *= 1-ease
  feet.append(foot)
 return compose(start_cycle,feet,start.root+Vector3(0,0,advance),1-ease)

static func standing() -> Dictionary:
 return settle(0,1)

static func depart(progress: float) -> Dictionary:
 # First place the leading foot, then enter phase zero at the normal pace.
 # The trailing foot stays planted throughout; reversing a stop clip would
 # move the root backwards and cannot serve as a forward departure.
 var t := clampf(progress,0,1)
 var target := sample(0)
 var distance: float = -target.feet[1].ground.z
 var advance := hermite(0,distance,0,STRIDE/PERIOD*DEPART_PERIOD,t)
 var ease := smoothstep(0,1,t)
 var feet: Array[Dictionary] = []
 for leg in range(2):
  var foot: Dictionary = target.feet[leg].duplicate(true)
  var final_z: float = foot.ground.z+distance
  foot.ground.z=hermite(0,final_z,0,0,t)-advance if leg==0 else -advance
  foot.lift=.035*pow(sin(PI*t),2) if leg==0 else 0.0
  foot.pitch*=ease
  foot.contact=leg==1 or t==0 or t==1
  feet.append(foot)
 return compose(0,feet,Vector3(0,0,advance),ease)

static func compose(cycles: float, feet: Array[Dictionary], root: Vector3, amount: float) -> Dictionary:
 var angle := fposmod(cycles,1.0)*TAU
 var sway := -.009*sin(angle)*amount
 var bob := -.012*cos(angle*2)*amount
 var pelvis := Vector3(sway,.735+bob,0)
 var hip_yaw := .035*cos(angle)*amount
 var chest_yaw := -.045*cos(angle)*amount
 var hip_basis := Basis(Vector3.UP,hip_yaw)
 var chest_basis := Basis(Vector3.UP,chest_yaw)
 var chest := Vector3(sway*.75,1.025+bob*.72,-.006)
 var joints := {"pelvis":pelvis,"chest":chest,
  "neck":Vector3(sway*.6,1.16+bob*.5,0),
  "head":Vector3(sway*.35,1.30+bob*.4,0)}
 for leg in range(2):
  var side := -1.0 if leg==0 else 1.0
  var name := "left" if leg==0 else "right"
  var hip := pelvis+hip_basis*Vector3(side*.095,0,0)
  var foot := feet[leg]
  var pitch: float = foot.pitch
  var ankle: Vector3 = foot.ground
  # Roll around the actual heel/toe: the contact point, not only the ankle,
  # remains fixed. The boot sole never sinks below the floor.
  ankle.y = FOOT_HEIGHT*cos(pitch)+maxf(TOE*sin(pitch),-HEEL*sin(pitch))+foot.lift
  ankle.z += TOE*(1-cos(pitch)) if pitch>=0 else HEEL*(cos(pitch)-1)
  ankle.z += FOOT_HEIGHT*sin(pitch)
  joints[name+"_hip"] = hip
  joints[name+"_knee"] = two_bone(hip,ankle,THIGH,SHIN,Vector3.FORWARD*-1)
  joints[name+"_ankle"] = ankle
  joints[name+"_toe"] = ankle+Basis(Vector3.RIGHT,pitch)*Vector3(0,-FOOT_HEIGHT,TOE)
  var shoulder := chest+chest_basis*Vector3(side*.19,.04,0)
  # Left foot starts forward; left arm starts behind. Soft elbow bend and
  # a small delayed forearm arc avoid stiff straight-arm marching.
  var swing := .29*cos(angle+leg*PI)*amount
  var lower_swing := swing-.10+.035*sin(angle+leg*PI-.18)*amount
  var upper_direction := Vector3(side*.11,-cos(swing),-sin(swing)).normalized()
  var lower_direction := Vector3(side*.055,-cos(lower_swing),-sin(lower_swing)).normalized()
  var elbow := shoulder+chest_basis*upper_direction*UPPER_ARM
  var wrist := elbow+chest_basis*lower_direction*FOREARM
  joints[name+"_shoulder"] = shoulder
  joints[name+"_elbow"] = elbow
  joints[name+"_wrist"] = wrist
 return {"root":root,"joints":joints,"feet":feet,"hip_yaw":hip_yaw,"chest_yaw":chest_yaw,"cycle":cycles,"amount":amount}

static func two_bone(start: Vector3, end: Vector3, upper: float, lower: float, pole: Vector3) -> Vector3:
 var direction := (end-start).normalized()
 var distance := clampf(start.distance_to(end),.00001,upper+lower-.000001)
 var along := (upper*upper-lower*lower+distance*distance)/(2*distance)
 var height := sqrt(maxf(0,upper*upper-along*along))
 var bend := (pole-direction*pole.dot(direction)).normalized()
 return start+direction*along+bend*height

static func hermite(a: float, b: float, ta: float, tb: float, t: float) -> float:
 return (2*t*t*t-3*t*t+1)*a+(t*t*t-2*t*t+t)*ta+(-2*t*t*t+3*t*t)*b+(t*t*t-t*t)*tb
