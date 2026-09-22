extends RefCounted

static func run(t: SceneTree, directory: String) -> void:
	if not ResourceLoader.exists("res://farm_rules.gd") or not ResourceLoader.exists("res://farm_store.gd") or not ResourceLoader.exists("res://farm_geometry.gd"):
		t.check(false, "playable multi-plot farm, transactions and walkable geometry are not implemented")
		return
	var rules = load("res://farm_rules.gd")
	var state: Dictionary = rules.initial(1000)
	t.check(state.plots.size() == 8 and state.plots[0].unlocked and not state.plots[4].unlocked, "a new farm has four usable plots and four to reclaim")
	var invalid: Dictionary = rules.command(state, {"type": "plant", "plot": -1, "crop": "welcome"})
	t.check(not invalid.ok and invalid.state == state, "out-of-range plot cannot consume resources")
	var dry := state.duplicate(true)
	dry.water = 0
	t.check(not rules.command(dry, {"type": "plant", "plot": 0, "crop": "welcome"}).ok, "dry planting is rejected before consuming the seed")
	t.check(dry.inventory.seed_welcome == 1, "failed planting does not mutate its input")
	var planted: Dictionary = rules.command(state, {"type": "plant", "plot": 0, "crop": "welcome"})
	t.check(planted.ok and planted.state.inventory.seed_welcome == 0 and planted.state.water == 38, "starting planting atomically reserves seed and water")
	t.check(state.inventory.seed_welcome == 1, "successful command leaves previous snapshot unchanged")
	state = planted.state
	var queued: Dictionary = rules.command(state, {"type": "plant", "plot": 1, "crop": "radish"})
	t.check(queued.ok and queued.state.queue.size() == 1 and queued.state.inventory.seed_radish == 6, "queued labor waits without prematurely consuming seeds")
	t.check(not rules.command(queued.state, {"type": "plant", "plot": 1, "crop": "radish"}).ok, "same plot cannot be queued twice")
	state = rules.advance(state, 1012)
	t.check(state.plots[0].crop == "welcome" and state.plots[0].planted == 1012, "planting appears only after the character completes labor")
	t.check(rules.plot_status(state, 0).phase == "growing", "freshly planted crop is growing")
	state = rules.advance(state, 1191)
	t.check(not rules.command(state, {"type": "harvest", "plot": 0}).ok, "harvest cannot start one second before maturity")
	state = rules.advance(state, 1192)
	t.check(rules.plot_status(state, 0).phase == "mature", "three-minute tutorial crop matures at the exact boundary")
	var harvested: Dictionary = rules.command(state, {"type": "harvest", "plot": 0})
	t.check(harvested.ok and harvested.state.inventory.radish == 0, "harvest reward waits for completed labor")
	state = rules.advance(harvested.state, 1204)
	t.check(state.inventory.radish == 3 and state.wisdom == 1 and state.tutorial_done and state.plots[0].crop.is_empty(), "tutorial harvest grants produce and learning reward once")
	var learned: Dictionary = rules.command(state, {"type": "learn", "skill": "F01"})
	t.check(learned.ok and learned.state.wisdom == 0 and learned.state.learned.has("F01"), "learning consumes exactly one earned point")
	t.check(not rules.command(learned.state, {"type": "learn", "skill": "F01"}).ok, "already learned page cannot be charged again")
	var clearing: Dictionary = rules.command(learned.state, {"type": "clear", "plot": 4})
	t.check(clearing.ok and not clearing.state.plots[4].unlocked, "reclamation is labor, not an instant UI toggle")
	state = rules.advance(clearing.state, 1216)
	t.check(state.plots[4].unlocked, "completed reclamation opens only its target plot")
	var sold: Dictionary = rules.command(state, {"type": "sell", "crop": "radish", "amount": 3})
	t.check(sold.ok and sold.state.inventory.radish == 0 and sold.state.coins == state.coins + 12, "selling moves actual produce into coins")
	t.check(not rules.command(sold.state, {"type": "sell", "crop": "radish", "amount": -3}).ok, "negative sale cannot mint produce")
	t.check(not rules.command(state, {"type": "buy", "crop": "made_up", "amount": 5}).ok, "unknown seeds are rejected")
	var thirsty: Dictionary = rules.initial(1000)
	thirsty.water = 8
	for job in [{"type": "plant", "plot": 0, "crop": "radish"}, {"type": "plant", "plot": 1, "crop": "wheat"}, {"type": "plant", "plot": 2, "crop": "potato"}]:
		thirsty = rules.command(thirsty, job).state
	thirsty = rules.advance(thirsty, 1024)
	t.check(thirsty.work.is_empty() and not thirsty.queue_block.is_empty(), "resource-short work waits without charging its seed")
	thirsty = rules.command(thirsty, {"type": "water"}).state
	t.check(thirsty.work.get("type") == "water", "refill can run before the blocked work that needs its water")
	thirsty = rules.advance(thirsty, 1048)
	t.check(thirsty.plots[2].crop == "potato" and thirsty.queue.is_empty() and thirsty.water == 54, "refill resumes the preserved planting queue")
	var full := state.duplicate(true)
	full.inventory.radish = 120
	full.plots[0] = {"unlocked": true, "crop": "radish", "planted": 1, "duration": 1}
	t.check(not rules.command(full, {"type": "harvest", "plot": 0}).ok and full.plots[0].crop == "radish", "full storage preserves the complete ripe crop")
	var origin: Dictionary = rules.command(rules.initial(1000), {"type": "plant", "plot": 0, "crop": "welcome"}).state
	origin = rules.command(origin, {"type": "plant", "plot": 1, "crop": "radish"}).state
	var stepped := origin.duplicate(true)
	for second in range(1001, 1401):
		stepped = rules.advance(stepped, second)
	t.check(stepped == rules.advance(origin, 1400), "online and offline advance produce identical states including queued work")
	var rollback: Dictionary = rules.advance(origin, 900)
	t.check(rollback.sim == 1000 and rollback.wall == 1000, "wall clock rollback never reverses simulation")
	var capped: Dictionary = rules.advance(rules.initial(1000), 1000 + 9 * 86400)
	t.check(capped.sim == 1000 + 86400 and capped.wisdom == 7, "ordinary catch-up caps at 24h and research at seven days")
	t.check(rules.advance(capped, 1000 + 9 * 86400) == capped, "discarded offline time cannot be claimed on the next tick")
	var protected: Dictionary = rules.initial(1000, {"seeds": 0, "planted_at": 950, "harvests": 2})
	t.check(protected.plots[0].crop == "welcome" and protected.inventory.radish == 2 and rules.plot_status(protected, 0).remaining == 130, "legacy crop age and previous harvests survive migration")
	var geometry = load("res://farm_geometry.gd")
	var view = load("res://farm_view.gd").new()
	t.check(view.has_method("set_state") and view.has_signal("plot_selected"), "the farm renders live snapshots and exposes plot selection")
	view.free()
	for id in range(8):
		t.check(geometry.plot_at(geometry.plot_center(id)) == id and geometry.plot_at(geometry.work_point(id)) == -1, "plot %d is hit-testable while worker stands outside" % id)
	var path: PackedVector2Array = geometry.route(geometry.work_point(0), geometry.work_point(7))
	var safe := true
	for index in range(1, path.size()):
		for sample in range(21):
			if geometry.plot_at(path[index - 1].lerp(path[index], sample / 20.0)) >= 0:
				safe = false
	t.check(safe, "cross-farm walking route never crosses a planted plot")
	# Hand-checked points from the diagonal layout, not derived by its projection.
	var diagonal_centers := [Vector2(132, 186), Vector2(180, 210), Vector2(228, 234), Vector2(276, 258), Vector2(84, 210), Vector2(132, 234), Vector2(180, 258), Vector2(228, 282)]
	for id in range(8):
		t.check(geometry.plot_at(diagonal_centers[id]) == id, "diagonal field %d keeps its saved plot identity when clicked" % id)
	t.check(geometry.plot_at(Vector2(163, 170)) == -1, "a diamond bounding-box corner is a path, not clickable farmland")
	t.check(geometry.plot_at(Vector2(124.992301940918, 165.503845214844)) == -1, "the upper-left path cannot be misclassified as distant field seven by a polygon ray degeneracy")
	var all_paths_safe := true
	for from_id in range(-1, 8):
		for to_id in range(-1, 8):
			var route: PackedVector2Array = geometry.route(geometry.work_point(from_id), geometry.work_point(to_id))
			for index in range(1, route.size()):
				for sample in range(101):
					if geometry.plot_at(route[index - 1].lerp(route[index], sample / 100.0)) >= 0:
						all_paths_safe = false
	t.check(all_paths_safe, "all 81 house and diagonal work-point routes stay outside crops")
	t.check(geometry.HOUSE.has_point(geometry.HOME), "the path home reaches the farmhouse porch instead of ending on the lawn")
	var stationary: PackedVector2Array = geometry.route(geometry.HOME, geometry.HOME)
	var stayed_home := true
	for point in stationary:
		if not point.is_equal_approx(geometry.HOME):
			stayed_home = false
	t.check(stayed_home, "repeated work at home does not take an unnecessary walk out and back")
	var depth_view = load("res://farm_view.gd").new()
	var layered: Dictionary = rules.initial(1000)
	for id in [0, 5, 7]:
		layered.plots[id] = {"unlocked": true, "crop": "radish", "planted": 1000, "duration": 3600}
	depth_view.set_state(layered)
	if not depth_view.has_method("scene_sprites"):
		t.check(false, "oblique scene must interleave plants, cat and gardener by their ground depth")
	else:
		var sprites: Array = depth_view.scene_sprites()
		var depth_ordered := true
		var roots_in_beds := true
		for index in range(sprites.size()):
			if index > 0 and sprites[index - 1].point.y > sprites[index].point.y:
				depth_ordered = false
			if sprites[index].kind == "crop" and geometry.plot_at(sprites[index].point) != sprites[index].plot:
				roots_in_beds = false
		t.check(sprites.size() == 29 and depth_ordered, "27 plants, cat and gardener draw back to front by their feet")
		t.check(roots_in_beds, "projected plant roots remain within their own diamond field")
	depth_view.free()
	# Catch portrait-sized replacements and bad frame pivots using real pixels,
	# not just the padded dimensions of a sprite's atlas cell.
	var art = load("res://pixel_art.gd")
	var registered_view = load("res://farm_view.gd").new()
	if not registered_view.has_method("actor_sprite"):
		t.check(false, "the rendered gardener must select registered front and rear atlas frames")
	else:
		var uphill: Dictionary = rules.initial(1000)
		uphill.work = {"type": "water", "plot": -1, "from_plot": 0, "start": 1000, "finish": 1012}
		registered_view.set_state(uphill)
		registered_view.motion.advance(0.5)
		var rear: Dictionary = registered_view.actor_sprite()
		var downhill: Dictionary = rules.command(rules.initial(1000), {"type": "plant", "plot": 0, "crop": "welcome"}).state
		registered_view.set_state(downhill)
		registered_view.motion.advance(0.5)
		var front: Dictionary = registered_view.actor_sprite()
		t.check(rear.source.position.y > front.source.position.y + front.source.size.y, "the whole-sprite renderer selects the rear cycle when walking away")
	registered_view.free()
	if not art.has_method("animated_frame"):
		t.check(false, "gameplay gardener needs size-calibrated, ground-registered animation frames")
	else:
		var scales_by_sheet := {}
		var standing_heights: Array[float] = []
		var front_heads: Array[float] = []
		var rear_heads: Array[float] = []
		var pose_heights := {}
		for index in range(36):
			var kind := "idle" if index < 4 else ("walk" if index < 20 else "work")
			var frame := index if index < 4 else ((index - 4) % 8 if index < 20 else index - 20)
			var descriptor: Dictionary = art.animated_frame(frame, kind, index >= 12 and index < 20)
			var source: Rect2 = descriptor.source
			var destination: Rect2 = descriptor.destination
			var pixels: Image = art.texture(descriptor.texture).get_image()
			var top := source.size.y
			var bottom := -1.0
			for y in range(int(source.size.y)):
				for x in range(int(source.size.x)):
					var color := pixels.get_pixel(int(source.position.x) + x, int(source.position.y) + y)
					if color.a < 0.5 or (minf(color.r, color.b) - color.g > 0.23 and color.r > 0.35 and color.b > 0.35):
						continue
					top = minf(top, y)
					bottom = maxf(bottom, y + 1)
			var visible_height := (bottom - top) * destination.size.y / source.size.y
			pose_heights["%s:%d:%s" % [kind, frame, "back" if index >= 12 and index < 20 else "front"]] = visible_height
			var sole_y := destination.position.y + bottom * destination.size.y / source.size.y
			if kind == "walk":
				var head_sum := 0.0
				var head_count := 0
				for y in range(int(top), int(top + (bottom - top) * 0.25)):
					for x in range(int(source.size.x)):
						var color := pixels.get_pixel(int(source.position.x) + x, int(source.position.y) + y)
						if color.a < 0.5 or (minf(color.r, color.b) - color.g > 0.23 and color.r > 0.35 and color.b > 0.35): continue
						head_sum += x
						head_count += 1
				var head_x := destination.position.x + head_sum / maxf(1, head_count) * destination.size.x / source.size.x
				if index < 12: front_heads.append(head_x)
				else: rear_heads.append(head_x)
			t.check(visible_height >= 22 and visible_height <= 35, "gardener frame %d fits the farmhouse and crop scale (%.1f world pixels)" % [frame, visible_height])
			t.check(absf(sole_y) <= 1, "gardener frame %d feet meet the ground plane, not floating (%.2f)" % [frame, sole_y])
			if kind != "work": standing_heights.append(visible_height)
			if not scales_by_sheet.has(descriptor.texture):
				scales_by_sheet[descriptor.texture] = destination.size / source.size
			else:
				t.check((destination.size / source.size).is_equal_approx(scales_by_sheet[descriptor.texture]), "bending/walking frame %d is not independently stretched to fit" % frame)
		t.check(standing_heights.max() - standing_heights.min() < 3, "front, rear and idle keep a consistent standing height rather than changing scale between sheets")
		t.check(absf(pose_heights["walk:1:front"] - pose_heights["idle:0:front"]) < 0.5, "front standing-to-walking registration does not shrink the entire figure at departure")
		t.check(absf(pose_heights["walk:5:back"] - pose_heights["idle:3:front"]) < 0.5, "rear standing-to-walking registration matches the closest whole-body passing pose")
		t.check(front_heads.max() - front_heads.min() < 0.9 and rear_heads.max() - rear_heads.min() < 0.9, "walking does not swing the whole skull sideways as the planted foot changes")
		t.check(art.animated_frame(0, "work") == art.animated_frame(0, "idle") and art.animated_frame(15, "work") == art.animated_frame(0, "idle"), "neutral action boundaries reuse the exact same idle drawing and pivot")
		var keeps_posture := true
		for from_id in range(-1, 8):
			var gathering = load("res://farm_motion.gd").new()
			var gather_state: Dictionary = rules.initial(1000)
			gather_state.work = {"type": "harvest", "from_plot": from_id, "plot": 0, "start": 1000, "finish": 1012}
			gathering.receive(gather_state)
			var previous_height: float = pose_heights["idle:0:front"]
			for sample in range(1450):
				gathering.advance(1.0 / 120)
				var pose: Dictionary = gathering.pose()
				# Idle direction is encoded by its frame; only the legacy walk
				# atlas has a separate back-facing row.
				var height: float = pose_heights["%s:%d:%s" % [pose.kind, pose.frame, "back" if pose.kind == "walk" and pose.back else "front"]]
				if absf(height - previous_height) > 4: keeps_posture = false
				previous_height = height
		t.check(keeps_posture, "gathering rises through intermediate poses instead of jumping seven world pixels out of its crouch")
	var store = load("res://farm_store.gd").new()
	for change in [{"work": {"type": "water"}}, {"queue": [42]}, {"settings": []}, {"coins": "40"}, {"learned": 1}, {"water": -1}, {"research": 86400}, {"actor_plot": 8}]:
		var broken: Dictionary = rules.initial(1000)
		broken.merge(change, true)
		t.check(not store._valid_state(broken), "malformed nested or scalar save is rejected: %s" % change.keys()[0])
	var db_path := directory.path_join("farm.db")
	t.check(store.open_store(db_path, 1000), "farm opens a real transactional save")
	if store.ready:
		var first: Dictionary = store.apply("same-id", {"type": "plant", "plot": 0, "crop": "welcome"})
		t.check(first.ok and store.apply("same-id", {"type": "plant", "plot": 0, "crop": "welcome"}).ok, "command replay returns the original outcome")
		t.check(store.snapshot().inventory.seed_welcome == 0, "replayed planting consumes seed once")
		t.check(not store.apply("same-id", {"type": "plant", "plot": 1, "crop": "welcome"}).ok, "same id with different parameters is rejected")
		store.close_store()
		store = load("res://farm_store.gd").new()
		t.check(store.open_store(db_path, 1192), "farm reopens and catches up after exit")
		t.check(rules.plot_status(store.snapshot(), 0).phase == "mature", "reopened save shows the actual matured crop")
		t.check(store.apply("same-id", {"type": "plant", "plot": 0, "crop": "welcome"}).ok and store.snapshot().inventory.seed_welcome == 0, "deduplication persists across restart")
		store.close_store()
	# Upgrade an actual legacy SQLite save, including committed WAL contents.
	var legacy = load("res://save_store.gd").new()
	var migration_path := directory.path_join("legacy-to-farm.db")
	t.check(legacy.open_store(migration_path) and legacy.apply("old-seed", "plant", 950).ok, "prepare a real legacy planted crop")
	legacy.close_store()
	store = load("res://farm_store.gd").new()
	t.check(store.open_store(migration_path, 1000), "legacy save upgrades to a playable farm")
	if store.ready:
		t.check(rules.plot_status(store.snapshot(), 0).remaining == 130, "SQLite migration preserves the old crop age")
	store.close_store()
	var backup_path := migration_path + ".pre-farm-v1.sqlite"
	t.check(FileAccess.file_exists(backup_path), "migration creates a consistent pre-upgrade backup")
	t.check(legacy.open_store(backup_path) and legacy.snapshot().planted_at == 950, "pre-upgrade backup is readable with the original progress")
	legacy.close_store()
	# Malformed nested state must stop before catch-up and leave the row unchanged.
	store = load("res://farm_store.gd").new()
	t.check(store.open_store(directory.path_join("malformed-farm.db"), 1000), "prepare isolated malformed-save regression")
	var malformed: Dictionary = rules.initial(1000)
	malformed.work = {"type": "water"}
	var serialized := JSON.stringify(malformed)
	store.db.query_with_bindings("UPDATE farm_state SET data=? WHERE id=1", [serialized])
	store.close_store()
	t.check(not store.open_store(directory.path_join("malformed-farm.db"), 1010) and not store.ready, "malformed work fails closed without running simulation")
	store.db.query("SELECT data FROM farm_state WHERE id=1")
	t.check(store.db.query_result[0].data == serialized, "rejected malformed state is not replaced with a new game")
	store.close_store()
