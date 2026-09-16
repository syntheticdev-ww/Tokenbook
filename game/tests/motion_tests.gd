extends RefCounted

static func run(t: SceneTree) -> void:
	if not ResourceLoader.exists("res://farm_motion.gd"):
		t.check(false, "continuous distance-driven gardener motion is not implemented")
		return
	var Motion = load("res://farm_motion.gd")
	var Geometry = load("res://farm_geometry.gd")
	var Rules = load("res://farm_rules.gd")
	var state: Dictionary = Rules.command(Rules.initial(1000), {"type": "plant", "plot": 0, "crop": "welcome"}).state
	var departure = Motion.new()
	departure.receive(state)
	var departure_point: Vector2 = departure.position()
	t.check(departure.pose().phase == "depart", "a new route starts with a brief whole-body turn before walking")
	departure.advance(0.05)
	t.check(departure.position() == departure_point, "the first turn holds the feet in place instead of sliding an idle figure")
	var landing = Motion.new()
	landing.receive(state)
	landing.advance(landing.travel_time - 0.01)
	t.check(landing.pose().kind == "walk" and landing.pose().frame == 1, "each route closes the last stride near the standing pose before work, not on an arbitrary wide step")
	var fps30 = Motion.new()
	var fps60 = Motion.new()
	fps30.receive(state)
	fps60.receive(state)
	for i in range(60): fps30.advance(1.0 / 30)
	for i in range(120): fps60.advance(1.0 / 60)
	t.check(fps30.position().distance_to(fps60.position()) < 0.001 and fps30.pose() == fps60.pose(), "walk timing and poses are unchanged between 30 and 60 refreshes per second")
	var motion = Motion.new()
	motion.receive(state)
	motion.advance(0.4)
	var before: Vector2 = motion.position()
	var pose_before: Dictionary = motion.pose()
	motion.receive(state)
	t.check(motion.position().is_equal_approx(before) and motion.pose() == pose_before, "UI-only refresh never rewinds subsecond position or resets the gait")
	motion.advance(0.8)
	before = motion.position()
	state.sim = 1001
	motion.receive(state)
	t.check(motion.position().is_equal_approx(before), "integer simulation ticks preserve the already rendered fraction")
	t.check(motion.position().distance_to(Vector2(156, 174)) > 0, "a walker has not teleported to the field")
	motion.advance(10.8)
	t.check(motion.position().is_equal_approx(Vector2(156, 174)) and motion.pose().kind == "idle", "visual work settles at the target by the unchanged twelve-second deadline")
	t.check(state.inventory.seed_welcome == 0 and state.plots[0].crop.is_empty(), "animation cannot complete labor or grant gameplay rewards")
	var late = Motion.new()
	var late_state: Dictionary = Rules.command(Rules.initial(1000), {"type": "plant", "plot": 0, "crop": "welcome"}).state
	late.receive(late_state)
	late.advance(0.1)
	before = late.position()
	late_state.sim = 1001
	late.receive(late_state)
	t.check(late.position().distance_to(before) < 0.01, "starting just before the next simulation tick cannot jump 28 pixels forward")
	late.advance(0.016)
	t.check(late.position().distance_to(before) < 1, "normal tick-boundary motion remains continuous on the next frame")
	late.advance(11)
	t.check(not late.busy(), "late-in-tick visual work also settles before the authoritative job completion")
	late.receive(late_state, true)
	t.check(not late.busy(), "restoring a settled job does not extend its already aligned visual ending")
	var restored = Motion.new()
	var restore_state: Dictionary = Rules.command(Rules.initial(1000), {"type": "plant", "plot": 0, "crop": "welcome"}).state
	restored.receive(restore_state)
	restored.advance(0.9)
	before = restored.position()
	restored.receive(restore_state, true)
	t.check(restored.position().is_equal_approx(before), "a quick hide and restore cannot rewind to the current integer tick")
	restore_state.sim = 1006
	restored.receive(restore_state, true)
	t.check(restored.elapsed >= 6 and restored.position().is_equal_approx(Vector2(156, 174)), "restore catches up an older visual clock to the current saved job")
	var safe := true
	var smooth := true
	var starts_gently := true
	var lands_neutrally := true
	var motion_frames := {}
	for from_id in range(-1, 8):
		for to_id in range(-1, 8):
			var fixture: Dictionary = Rules.initial(1000)
			fixture.actor_plot = from_id
			fixture.work = {"type": "plant", "plot": to_id, "from_plot": from_id, "start": 1000, "finish": 1012}
			var walker = Motion.new()
			walker.receive(fixture)
			if from_id != to_id:
				var end_walk = Motion.new()
				end_walk.receive(fixture)
				end_walk.advance(end_walk.travel_time - 0.01)
				var landing_pose: Dictionary = end_walk.pose()
				lands_neutrally = lands_neutrally and landing_pose.kind == "walk" and landing_pose.frame == (5 if landing_pose.back else 1)
			var previous: Vector2 = walker.position()
			var first_step := 0.0
			var cruise_step := 0.0
			for i in range(720):
				walker.advance(1.0 / 60.0)
				var point: Vector2 = walker.position()
				var step := point.distance_to(previous)
				if i == 0: first_step = step
				if i == 30: cruise_step = step
				if Geometry.plot_at(point) >= 0:
					if safe: printerr("Route contact: ", from_id, " -> ", to_id, " frame=", i, " point=(%.12f,%.12f)" % [point.x, point.y], " plot=", Geometry.plot_at(point), " grid=", Geometry.unproject(point), " polygon=", Geometry.plot_polygon(Geometry.plot_at(point)))
					safe = false
				if step > 1.8: smooth = false
				var pose: Dictionary = walker.pose()
				if pose.kind == "walk": motion_frames[pose.frame] = true
				previous = point
			if from_id != to_id and first_step >= cruise_step: starts_gently = false
			if not previous.is_equal_approx(Geometry.work_point(to_id)): safe = false
	t.check(safe, "all 81 smoothed routes remain outside the eight crop polygons and reach their saved target")
	t.check(smooth and starts_gently, "every 60 Hz walk starts gently with bounded frame-to-frame motion")
	t.check(motion_frames.size() == 8, "walking uses all eight stride phases instead of alternating two poses")
	t.check(lands_neutrally, "all nonstationary routes finish a whole walk cycle at the close-foot pose")
	var stationary = Motion.new()
	var refill: Dictionary = Rules.command(Rules.initial(1000), {"type": "water"}).state
	stationary.receive(refill)
	stationary.advance(1)
	t.check(stationary.pose().kind != "walk" and stationary.position() == Vector2(228, 138), "work at the current location never runs in place")
	# Face the actual ground direction, not a mirrored front portrait on every leg.
	var returning = Motion.new()
	var homeward: Dictionary = Rules.initial(1000)
	homeward.work = {"type": "water", "plot": -1, "from_plot": 0, "start": 1000, "finish": 1012}
	returning.receive(homeward)
	returning.advance(0.5)
	t.check(returning.pose().get("back", false), "walking uphill toward the house uses the back of the gardener, not her face")
	var tending = Motion.new()
	tending.receive(restore_state)
	tending.advance(0.9)
	t.check(not tending.pose().get("back", false), "tending crops faces the viewer-side of the diagonal field")
	var watering = Motion.new()
	watering.receive(Rules.command(Rules.initial(1000), {"type": "plant", "plot": 0, "crop": "welcome"}).state)
	watering.advance(8)
	t.check(watering.pose().get("phase", "") == "hold" and watering.pose().pour, "watering sustains a poured pose instead of repeatedly raising and lowering the can")
	watering.advance(3.4)
	t.check(watering.pose().get("phase", "") == "recover" and not watering.pose().pour, "labor puts away the tool before returning to idle")
	watering.advance(0.7)
	t.check(watering.pose().kind == "idle" and not watering.pose().pour, "the final neutral pose has no leftover tool or water")
	var wind_view = load("res://farm_view.gd").new()
	if not wind_view.has_method("crop_quad"):
		t.check(false, "crop wind must be rooted to the existing crop point")
	else:
		var root_point := Vector2(132, 186)
		wind_view.motion.advance(0.7)
		var quad: PackedVector2Array = wind_view.crop_quad(root_point)
		t.check(quad[2] == Vector2(143, 189) and quad[3] == Vector2(121, 189), "wind never moves the crop's root edge off its planted point")
		var tip := quad[0]
		wind_view.motion.advance(1)
		quad = wind_view.crop_quad(root_point)
		t.check(not quad[0].is_equal_approx(tip) and absf(quad[0].x - 121) <= 0.6, "wind only makes a restrained subpixel leaf movement")
	wind_view.free()
	var idle = Motion.new()
	idle.receive(Rules.initial(1000))
	var closed := 0
	for i in range(600):
		idle.advance(1.0 / 60.0)
		if idle.pose().frame == 1: closed += 1
	t.check(closed > 0 and closed < 45, "idle blinks are brief occasional gestures, not a half-second metronome")
	var view = load("res://farm_view.gd").new()
	if not view.has_method("visual_pose"):
		t.check(false, "rendered farm must consume continuous motion instead of its old wall-clock interpolator")
	else:
		view.set_state(state)
		view.motion.advance(0.5)
		before = view.actor_position()
		view.set_state(state)
		t.check(view.actor_position() == before and view.visual_pose().kind == "walk", "the farm renderer retains live subsecond motion across refresh")
	view.free()
