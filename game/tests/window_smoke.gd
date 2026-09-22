extends SceneTree

var failures: Array[String] = []
var rendered_positions: Array[Vector2] = []
var motion_sample = null
var rendered_poses := {}

func sample_motion() -> void:
	if is_instance_valid(motion_sample):
		rendered_positions.append(motion_sample.actor_position())
		if motion_sample.visual_pose().kind == "walk":
			var sprite: Dictionary = motion_sample.actor_sprite()
			rendered_poses[sprite.texture + str(sprite.source)] = true

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not ResourceLoader.exists("res://main.tscn"):
		check(false, "native companion scene is not implemented")
		quit(1)
		return
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.store.ready, "window loads persistent state")
	check(scene.pet != null and scene.farm == null, "native game starts as a standalone desktop pet")
	var window_id := root.get_window_id()
	check(scene.music != null and scene.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "original ambient track is configured for continuous looping")
	scene.toggle_music()
	check(not scene.store.snapshot().settings.music and scene.music.stream_paused, "mute immediately pauses music and saves the preference")
	scene.toggle_music()
	check(scene.store.snapshot().settings.music and not scene.music.stream_paused, "music resumes without restarting the game")
	var before := root.position
	var compact_size := root.size
	scene.set_expanded(true)
	await process_frame
	check(root.get_window_id() == window_id, "expand uses the same native window")
	check(root.size.x > compact_size.x and root.size.y > compact_size.y, "expand changes native size")
	check(not root.always_on_top and scene.farm.refined_animation, "landscape game enables refined rendering with normal window focus")
	if not scene.has_method("issue"):
		check(false, "native UI has no playable plot action flow")
		scene.shutdown(1)
		return
	# Exercise actual scene hit-testing and the action button, not a copied rule.
	var geometry = load("res://farm_geometry.gd")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var diagonal_centers := [Vector2(132, 186), Vector2(180, 210), Vector2(228, 234), Vector2(276, 258), Vector2(84, 210), Vector2(132, 234), Vector2(180, 258), Vector2(228, 282)]
	var viewport := Rect2(Vector2.ZERO, scene.farm.size)
	var action_area := Rect2(Vector2(scene.Layout.EXPANDED) - Vector2(306,98), Vector2(286,78))
	var nav_area := Rect2(20,scene.Layout.EXPANDED.y-86,336,68)
	for id in range(8):
		var polygon := PackedVector2Array()
		for corner in geometry.plot_polygon(id):
			var point: Vector2 = scene.farm.world_to_view(corner)
			check(viewport.has_point(point), "closer framing keeps every corner of field %d visible" % id)
			polygon.append(point)
		for hud in [action_area,nav_area]:
			var hud_polygon := PackedVector2Array([hud.position,Vector2(hud.end.x,hud.position.y),hud.end,Vector2(hud.position.x,hud.end.y)])
			check(Geometry2D.intersect_polygons(polygon,hud_polygon).is_empty(), "field %d is not covered by the bottom controls" % id)
		click.position = scene.farm.world_to_view(diagonal_centers[id])
		scene.farm._gui_input(click)
		check(scene.selected_plot == id, "native diagonal field %d selects its own existing save entry" % id)
	for corner in [geometry.HOUSE.position,geometry.HOUSE.end]:
		check(viewport.has_point(scene.farm.world_to_view(corner)), "closer framing keeps the full cottage visible")
	click.position = scene.farm.world_to_view(geometry.plot_center(0))
	scene.farm._gui_input(click)
	check(scene.selected_plot == 0, "clicking the drawn plot selects that plot")
	scene.action_button.pressed.emit()
	check(scene.store.snapshot().work.get("type") == "plant", "native planting button starts actual saved labor")
	var labor_start := int(scene.store.snapshot().sim)
	motion_sample = scene.farm
	scene.farm.draw.connect(sample_motion)
	await create_timer(0.65).timeout
	scene.farm.draw.disconnect(sample_motion)
	check(rendered_positions.size() >= 24, "active walking is actually drawn at least 24 times in 0.65s, not the old 12-15 Hz cadence")
	check(rendered_poses.size() >= 4, "native walking plays authored whole-character poses, not a static picture")
	check(Engine.max_fps == 60, "active animation respects the requested sixty FPS ceiling")
	print("Native walking samples in 0.65s: ", rendered_positions.size(), "; authored poses: ", rendered_poses.size(), "; refresh cap: ", Engine.max_fps)
	var moved_smoothly := true
	for i in range(1, rendered_positions.size()):
		if rendered_positions[i].distance_to(rendered_positions[i - 1]) > 2.0:
			moved_smoothly = false
	check(moved_smoothly, "actual native frame-to-frame walking has no multi-pixel simulation-tick jumps")
	var live_motion = scene.farm.motion
	check(absf(live_motion.elapsed - 0.65) < 0.18, "persistent motion is advanced only once per frame by the scene, not again by the view")
	var motion_before: Vector2 = live_motion.position()
	scene.set_expanded(false)
	scene.set_expanded(true)
	check(scene.farm.motion == live_motion and scene.farm.actor_position() == motion_before, "expanding/rebuilding the UI retains the exact in-flight motion object and fraction")
	motion_sample = null
	var away_start: float = live_motion.elapsed
	scene.show_page("bag")
	await create_timer(0.25).timeout
	scene.show_page("farm")
	check(scene.farm.motion == live_motion and live_motion.elapsed - away_start > 0.2 and live_motion.elapsed - away_start < 0.5, "motion continues once at real time while browsing another game page")
	print("Motion frames over 0.65s: ", rendered_positions.size())
	await create_timer(7.6).timeout
	check(geometry.plot_at(scene.farm.actor_position()) == -1, "animated gardener performs labor from the path outside the field")
	await capture("working")
	await create_timer(4.5).timeout
	check(scene.store.snapshot().plots[0].crop == "welcome", "real window timer completes twelve-second planting without a test clock jump")
	check(int(scene.store.snapshot().sim) - labor_start in [12, 13, 14], "live simulation advances at real time rather than double ticking")
	var now := int(scene.store.snapshot().wall)
	scene.store.tick(now + 192)
	scene.refresh()
	check(scene.action_button.text.contains("收获") and not scene.action_button.disabled, "UI exposes harvest after simulation matures the crop")
	scene._toast_until = 0
	scene.refresh()
	await capture("mature")
	scene.action_button.pressed.emit()
	scene.store.tick(now + 204)
	scene.refresh()
	check(scene.store.snapshot().inventory.radish == 3, "harvest button awards real inventory after labor")
	scene.show_page("book")
	await capture("book")
	scene.show_page("bag")
	await capture("bag")
	scene.show_page("home")
	await capture("home")
	scene.show_page("farm")
	await capture("expanded")
	for i in 100:
		scene.set_expanded(false)
		scene.set_expanded(true)
	scene.set_expanded(false)
	await process_frame
	check(root.position == before and root.size == compact_size, "100 expand cycles have no anchor drift")
	check(root.get_window_id() == window_id, "100 cycles never recreate the window")
	await capture("compact")
	scene.set_expanded(true)
	scene.issue({"type": "water"})
	await create_timer(0.8).timeout
	check(scene.farm.visual_pose().get("back", false), "native homeward walking visibly selects the rear-facing animation")
	await capture("walking-away")
	scene.set_expanded(false)
	scene.hide_game()
	await process_frame
	check(not scene.is_game_visible(), "hide hides the native window")
	scene.show_game()
	await process_frame
	check(scene.is_game_visible(), "restore shows the existing window")
	print("Native window smoke: ", "PASS" if failures.is_empty() else "FAIL", "; windowId=", window_id, "; compact physical size=", compact_size)
	scene.shutdown(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	var target := OS.get_environment("TOKENBOOK_CAPTURE_DIR")
	if not target.is_empty():
		# Explicitly render the fixture, as the character smoke test does.
		# Waiting for a spontaneous draw can stall after native window changes.
		await process_frame
		RenderingServer.force_draw(false)
		check(root.get_texture().get_image().save_png(target.path_join(label + ".png")) == OK, "screenshot is saved: " + label)
