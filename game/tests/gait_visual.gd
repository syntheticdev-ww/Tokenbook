extends SceneTree

# Render-only fixture using current motion and whole-sprite rendering.
# Never opens a save. The former cutout-rig comparison is no longer current.
const Art = preload("res://pixel_art.gd")
const Motion = preload("res://farm_motion.gd")
const Rules = preload("res://farm_rules.gd")

class ContactSheet extends Control:
	func _ready() -> void:
		material = Art.key_material()
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1120, 830), Color("dde0b9"))
		for row in range(2):
			_label(Vector2(20, 28 + row * 200), "Whole authored walk / " + ("rear" if row == 1 else "front"))
			for frame in range(8):
				var pose := {"kind": "walk", "frame": frame, "right": false, "back": row == 1}
				_draw_pose(pose, Vector2(70 + frame * 140, 170 + row * 200), 3.5)
				_label(Vector2(46 + frame * 140, 192 + row * 200), "pose %d" % frame)
		for row in range(2):
			_label(Vector2(20, 425 + row * 200), "Real route transition / " + ("homeward" if row == 1 else "to field"))
			var sample := _motion(row == 1)
			var times := [0.0, 0.09, 0.15, 0.24, sample.travel_time - 0.01, sample.travel_time + 0.06, sample.travel_time + 0.16, sample.travel_time + 0.26]
			for i in range(times.size()):
				var motion := _motion(row == 1)
				motion.advance(times[i])
				var pose: Dictionary = motion.pose()
				_draw_pose(pose, Vector2(70 + i * 140, 570 + row * 200), 3.5)
				_label(Vector2(32 + i * 140, 594 + row * 200), "%.2fs %s" % [times[i], pose.phase])
	func _motion(back: bool) -> RefCounted:
		var state := Rules.initial(1000)
		state.work = {"type": "water" if back else "plant", "from_plot": 0 if back else -1, "plot": -1 if back else 0, "start": 1000, "finish": 1012}
		var motion := Motion.new()
		motion.receive(state)
		return motion
	func _draw_pose(pose: Dictionary, origin: Vector2, zoom: float) -> void:
		var frame := Art.animated_frame(pose.frame, pose.kind, pose.back)
		draw_set_transform(origin, 0, Vector2(-zoom if pose.right else zoom, zoom))
		draw_line(Vector2(-12, 0), Vector2(12, 0), Color("9da782"), 0.2)
		draw_texture_rect_region(Art.texture(frame.texture), frame.destination, frame.source)
		draw_set_transform(Vector2.ZERO)
	func _label(point: Vector2, label: String) -> void:
		draw_string(ThemeDB.fallback_font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("374433"))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.max_fps = 60
	root.title = "Tokenbook — whole-character motion audit (no save)"
	root.transparent = false
	root.always_on_top = false
	root.size = Vector2i(1120, 830)
	root.position = Vector2i(70, 60)
	root.add_child(ContactSheet.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("TOKENBOOK_CAPTURE_DIR")
	if not output.is_empty():
		root.get_texture().get_image().save_png(output.path_join("whole-character-motion.png"))
	print("Whole-character motion contact sheet captured; no save opened.")
	quit()
