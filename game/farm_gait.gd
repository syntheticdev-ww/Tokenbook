extends RefCounted

# REJECTED EXPERIMENT: no runtime caller. Retained only as reversible history;
# the game uses farm_motion.gd plus complete frames in pixel_art.gd instead.
# Projected 2D gait. A cycle is TWO steps, not one repeated leading leg.
# Landings are sampled on the route at the start of a step and remain fixed
# in world space, including through a curve and during acceleration.
const Geometry = preload("res://farm_geometry.gd")
const STRIDE := 18.0
const STANCE := 0.60
const TRACK := 1.25
const SETTLE_SECONDS := 0.20
# Measured sole centers in the existing idle drawing. Arrival must end here,
# not merely reduce airborne height while leaving a foot behind the body.
const IDLE_SOLES := [Vector2(-3.522, -1.408), Vector2(2.289, -0.117)]

static func sample(path: PackedVector2Array, length: float, distance: float) -> Dictionary:
	var root := Geometry.along(path, distance / maxf(length, 0.001))
	var feet: Array[Dictionary] = []
	for leg in range(2):
		var offset := STRIDE * STANCE * 0.5 + leg * STRIDE * 0.5
		var step := floori((distance + offset) / STRIDE)
		var start := step * STRIDE - offset
		var phase := (distance - start) / STRIDE
		var contact := phase < STANCE
		var ground := _landing(path, length, start, leg)
		var lift := 0.0
		var swing := 0.0
		if not contact:
			var takeoff := maxf(0, start + STRIDE * STANCE)
			swing = clampf((distance - takeoff) / (start + STRIDE - takeoff), 0, 1)
			var next := _landing(path, length, start + STRIDE, leg)
			ground = ground.lerp(next, smoothstep(0.0, 1.0, swing))
			# Clear toe-off, bent-knee passing, then an eased landing. No hop:
			# the opposite foot stays grounded throughout this swing.
			lift = sin(PI * swing) * 2.2 * smoothstep(0.0, 3.0, length - distance)
		feet.append({"position": ground - root - Vector2(0, lift), "ground": ground,
			"contact": contact, "lift": lift, "swing": swing, "step": step, "phase": phase})
	var cycle := fposmod(distance / STRIDE + STANCE * 0.5, 1.0)
	return {"feet": feet, "cycle": cycle,
		"body": Vector2(sin(cycle * TAU) * 0.12, cos((cycle - 0.10) * TAU * 2.0) * 0.28)}

static func settle(gait: Dictionary, elapsed: float) -> Dictionary:
	var result := gait.duplicate(true)
	var progress := clampf(elapsed / SETTLE_SECONDS, 0, 1)
	var distances := [gait.feet[0].position.distance_to(IDLE_SOLES[0]), gait.feet[1].position.distance_to(IDLE_SOLES[1])]
	var first := 0 if distances[0] >= distances[1] else 1
	var split := clampf(distances[first] / maxf(0.001, distances[0] + distances[1]), 0.3, 0.7)
	for leg in range(2):
		var fraction := clampf(progress / split if leg == first else (progress - split) / (1.0 - split), 0, 1)
		var foot: Dictionary = result.feet[leg]
		foot.position = gait.feet[leg].position.lerp(IDLE_SOLES[leg], smoothstep(0.0, 1.0, fraction))
		foot.lift = sin(PI * fraction) * minf(0.85, distances[leg] * 0.18)
		foot.position.y -= foot.lift
		foot.swing = fraction
		foot.contact = fraction >= 1.0 or (fraction <= 0 and gait.feet[leg].contact)
		var root: Vector2 = gait.feet[leg].ground - gait.feet[leg].position - Vector2(0, gait.feet[leg].lift)
		foot.ground = root + foot.position + Vector2(0, foot.lift)
	result.body = gait.body * (1.0 - smoothstep(0.0, 1.0, progress))
	result.settle = progress
	return result

static func _landing(path: PackedVector2Array, length: float, start: float, leg: int) -> Vector2:
	# Begin with both feet under the body, not a teleported first contact.
	var at := clampf(start + STRIDE * STANCE * 0.5, 0, length) if start > 0 else 0.0
	var point := Geometry.along(path, at / maxf(length, 0.001))
	var ahead := Geometry.along(path, minf(length, at + 0.5) / maxf(length, 0.001))
	var behind := Geometry.along(path, maxf(0, at - 0.5) / maxf(length, 0.001))
	var side := (ahead - behind).normalized().orthogonal()
	return point + side * TRACK * (-1 if leg == 0 else 1)
