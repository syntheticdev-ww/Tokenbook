extends RefCounted

# Visual-only state: simulation remains the sole authority for costs/rewards.
const Geometry = preload("res://farm_geometry.gd")
const Rules = preload("res://farm_rules.gd")
const DEPART_SECONDS := 0.18
const ARRIVE_SECONDS := 0.30
const STRIDE_DISTANCE := 19.5
var clock := 0.0
var elapsed := 0.0
var travel_time := 0.0
var length := 0.0
var _finish_elapsed := float(Rules.LABOR_SECONDS)
var _job: Dictionary = {}
var _key := ""
var _path := PackedVector2Array([Geometry.HOME])
var _facing_right := false
var _facing_back := false
var _walk_cycles := 1

func receive(state: Dictionary, resync := false) -> void:
	var job: Dictionary = state.get("work", {})
	var key := "" if job.is_empty() else "%s:%s:%s:%s" % [job.start, job.type, job.from_plot, job.get("plot", -1)]
	if key == _key:
		if not job.is_empty():
			var observed := maxf(0, float(state.sim) - float(job.start))
			if resync:
				# The scene also advances while hidden; restoring can catch up
				# after suspension, but must not discard a visible subsecond step.
				elapsed = maxf(elapsed, observed)
			# Commands may start anywhere in the app-wide integer tick. Keep
			# the continuous travel clock; only align the ending to the actual
			# remaining simulation time. Normal refresh must never teleport.
			_finish_elapsed = minf(_finish_elapsed, elapsed + maxf(0, Rules.LABOR_SECONDS - observed))
		else:
			_path = PackedVector2Array([Geometry.work_point(int(state.get("actor_plot", -1)))])
		return
	_key = key
	_job = job.duplicate(true)
	_finish_elapsed = Rules.LABOR_SECONDS
	elapsed = maxf(0, float(state.sim) - float(job.start)) if not job.is_empty() else 0.0
	if job.is_empty():
		_path = PackedVector2Array([Geometry.work_point(int(state.get("actor_plot", -1)))])
		length = 0
		travel_time = 0
		return
	_path = _round_route(Geometry.route(Geometry.work_point(int(job.from_plot)), Geometry.work_point(int(job.get("plot", -1)))))
	length = 0
	for i in range(1, _path.size()):
		length += _path[i - 1].distance_to(_path[i])
	travel_time = minf(Rules.LABOR_SECONDS * 0.65, length / 27.0 + 0.32 + DEPART_SECONDS) if length > 0.01 else 0.0
	# End a complete authored cycle near the standing pose. A small adjustment
	# of stride length avoids cutting off a wide step at an arbitrary endpoint.
	_walk_cycles = maxi(1, roundi(length / STRIDE_DISTANCE))
	_update_facing()

func advance(delta: float) -> void:
	clock += maxf(delta, 0)
	if not _job.is_empty():
		elapsed += maxf(delta, 0)
		_update_facing()

func busy() -> bool:
	return not _job.is_empty() and elapsed < _finish_elapsed

func distance() -> float:
	if travel_time <= 0 or elapsed >= travel_time:
		return length
	var moving_time := maxf(0, elapsed - DEPART_SECONDS)
	var duration := travel_time - DEPART_SECONDS
	# Integrate a trapezoidal velocity profile: ease only departure/arrival,
	# retaining a steady middle pace instead of easing at every frame/tick.
	var ramp := minf(0.22, duration * 0.2)
	var area := duration - ramp
	if moving_time < ramp:
		return length * moving_time * moving_time / (2 * ramp * area)
	if moving_time > duration - ramp:
		var remaining := duration - moving_time
		return length * (1 - remaining * remaining / (2 * ramp * area))
	return length * (moving_time - ramp * 0.5) / area

func position() -> Vector2:
	return Geometry.along(_path, distance() / length) if length > 0.01 else _path[-1]

func pose() -> Dictionary:
	if busy() and elapsed < travel_time:
		if elapsed < DEPART_SECONDS:
			if elapsed < 0.06 or not (_facing_back or _facing_right):
				return _pose("idle", 0, "depart")
			return _pose("idle", 3 if _facing_back and elapsed >= 0.12 else 2, "depart", _facing_right)
		# Front phase 1 / rear phase 5 are the authored close-foot poses that
		# match their standing profiles. Rear art has a half-cycle phase offset.
		var frame := ((5 if _facing_back else 1) + roundi(distance() / length * _walk_cycles * 8)) % 8
		return _pose("walk", frame, "walk", _facing_right, _facing_back)
	var local := elapsed - travel_time
	if busy() and local < ARRIVE_SECONDS:
		# Keep the incoming orientation for landing, then pass through the
		# authored profile before facing the crops. No mesh deformation/ghosting.
		if travel_time > 0 and local < 0.10:
			return _pose("idle", 3 if _facing_back else 0, "arrive", _facing_right)
		if travel_time > 0 and local < 0.20 and (_facing_back or _facing_right):
			return _pose("idle", 2, "arrive", _facing_right)
		return _pose("idle", 0, "arrive")
	if busy():
		var watering: bool = _job.type in ["plant", "water"]
		var remaining := _finish_elapsed - elapsed
		if remaining < 0.85:
			var recovery := [6, 7, 0] if watering else [11, 10, 13, 14, 15]
			return _pose("work", recovery[mini(recovery.size() - 1, int((0.85 - remaining) / 0.85 * recovery.size()))], "recover")
		var action_time := local - ARRIVE_SECONDS
		if action_time < 0.95:
			var preparation := [0, 1, 2, 3, 4] if watering else [8, 9, 10, 11, 12]
			return _pose("work", preparation[clampi(int(action_time / 0.95 * 5), 0, 4)], "prepare")
		var hold_frame := (4 if int((action_time - 0.95) / 0.65) % 2 == 0 else 5) if watering else (11 if int((action_time - 0.95) / 0.7) % 2 == 0 else 12)
		var result := _pose("work", hold_frame, "hold")
		result.pour = watering and _job.type == "plant"
		return result
	# Brief irregular-looking blink schedule; never alternate at half-second rate.
	var phase := fmod(clock, 8.7)
	var blink := (phase > 3.1 and phase < 3.24) or (phase > 7.0 and phase < 7.13)
	return _pose("idle", 1 if blink else 0, "idle")

static func _pose(kind: String, frame: int, phase: String, right := false, back := false) -> Dictionary:
	return {"kind": kind, "frame": frame, "phase": phase, "right": right, "back": back, "breath": 1.0, "pour": false}

func _update_facing() -> void:
	if length <= 0.01 or elapsed >= travel_time:
		return
	var d := distance()
	var direction := Geometry.along(_path, minf(length, d + 1.5) / length) - Geometry.along(_path, maxf(0, d - 1.5) / length)
	if absf(direction.x) > 0.05:
		_facing_right = direction.x > 0
	if absf(direction.y) > 0.05:
		_facing_back = direction.y < 0

static func _round_route(route: PackedVector2Array) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for point in route:
		if clean.is_empty() or not clean[-1].is_equal_approx(point):
			clean.append(point)
	if clean.size() < 3:
		return clean
	var result := PackedVector2Array([clean[0]])
	for i in range(1, clean.size() - 1):
		var corner := clean[i]
		var radius := minf(3.0, minf(corner.distance_to(clean[i - 1]), corner.distance_to(clean[i + 1])) * 0.25)
		var entry := corner.move_toward(clean[i - 1], radius)
		var leave := corner.move_toward(clean[i + 1], radius)
		result.append(entry)
		for step in range(1, 7):
			var fraction := step / 6.0
			result.append(entry.lerp(corner, fraction).lerp(corner.lerp(leave, fraction), fraction))
	result.append(clean[-1])
	return result
