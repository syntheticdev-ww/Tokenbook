extends SceneTree

# Compare the actual layered Farm against the old single draw-list at identical
# sampling. This isolates depth/transform/clip/redraw changes from antialiasing.
const Art = preload("res://pixel_art.gd")
const Walk = preload("res://walk_art.gd")
const Rules = preload("res://farm_rules.gd")
const Geometry = preload("res://farm_geometry.gd")

class FixtureFarm extends "res://farm_view.gd":
	var at := Vector2.ZERO
	var phase := 0.0
	var test_pose := {"kind":"walk", "frame":0, "back":false, "right":false, "pour":false}
	func actor_position() -> Vector2: return at
	func actor_draw_position() -> Vector2: return at
	func view_offset() -> Vector2:
		# The oracle is a sequential DRAW LIST, not the historical camera policy.
		# Use the same continuous camera in both paths to isolate layer correctness.
		if compact: return -(_camera if _camera_ready else _camera_target())
		return super.view_offset()
	func visual_pose() -> Dictionary: return test_pose
	func actor_sprite() -> Dictionary:
		if test_pose.kind == "walk": return Walk.frame_at(phase,test_pose.back)
		if test_pose.kind == "settle": return Walk.settle_frame(.6,test_pose.back)
		return Art.animated_frame(test_pose.frame,test_pose.kind,test_pose.back)
	func _draw_actor() -> void:
		# Sequential oracle paints the SAME whole figure/material. Only
		# scene draw-list ordering differs, not the character artwork.
		var saved := refined_animation
		refined_animation = true
		_paint_actor(self)
		refined_animation = saved

func _initialize() -> void:
	root.hide()
	call_deferred("run")

func run() -> void:
	Walk.warm_cache()
	Engine.max_fps = 60
	var dpi := 2 if "--retina" in OS.get_cmdline_user_args() else 1
	var farms: Array[FixtureFarm] = []
	var views: Array[SubViewport] = []
	var state := Rules.initial(1000)
	for i in range(8):
		state.plots[i] = {"unlocked":true,"crop":"radish","planted":1,"duration":180}
	for i in range(2):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(384,342)*dpi
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.canvas_transform = Transform2D(0,Vector2.ONE*dpi,0,Vector2.ZERO)
		views.append(viewport)
		var farm := FixtureFarm.new()
		farm.refined_animation = i == 1
		farm.externally_driven = true
		farm.size = Vector2(384,342)
		viewport.add_child(farm)
		if i == 1: farm._actor_layer.material = Art.key_material()
		farm.set_state(state)
		farms.append(farm)
	var failures := 0
	var scenarios := 0
	for compact_mode in [false,true]:
		for point in [Geometry.CAT+Vector2(0,-1),Geometry.CAT+Vector2(0,1),Geometry.plot_center(0)+Vector2(0,4),Geometry.plot_center(4)+Vector2(0,-4),Geometry.HOME]:
			for kind in ["walk","rear","settle","rear-settle","idle","work"]:
				for farm in farms:
					farm.compact = compact_mode
					farm.size = Vector2(220,127) if compact_mode else Vector2(384,342)
					farm.at = point
					farm.phase = fmod(scenarios*1.37,16.0)
					farm.test_pose = {"kind":"walk" if kind == "rear" else ("settle" if kind == "rear-settle" else kind),"frame":4 if kind == "work" else 0,"back":kind in ["rear","rear-settle"],"right":scenarios%2 == 0,"pour":kind == "work"}
					farm.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var a := views[0].get_texture().get_image()
				var b := views[1].get_texture().get_image()
				if a.get_data() != b.get_data():
					failures += 1
					printerr("Farm layer mismatch: ",kind," / at=",point," / compact=",compact_mode)
				scenarios += 1
	print("Farm layer GPU comparison: ",scenarios," scenarios, dpi=",dpi,", mismatches=",failures)
	for viewport in views: viewport.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
