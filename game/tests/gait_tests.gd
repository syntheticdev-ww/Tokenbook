extends RefCounted

static func run(t: SceneTree) -> void:
	# Verify whole-frame cohesion; visual naturalness still requires playback QA.
	var view = load("res://farm_view.gd").new()
	var Rules = load("res://farm_rules.gd")
	view.set_state(Rules.command(Rules.initial(1000), {"type": "plant", "plot": 0, "crop": "welcome"}).state)
	view.motion.advance(0.5)
	var fragmented: bool = view.has_method("actor_parts") and view.actor_parts().size() > 1
	t.check(not fragmented, "walking uses a complete authored sprite, not independently deformed body parts")
	var observed := {}
	var coherent := true
	var previous: Vector2 = view.actor_position()
	for i in range(720):
		view.motion.advance(1.0 / 60)
		var pose: Dictionary = view.visual_pose()
		var sprite: Dictionary = view.actor_sprite()
		if pose.kind == "walk": observed[pose.frame] = true
		coherent = coherent and sprite.destination.size.x > 0 and sprite.destination.size.y > 0
		coherent = coherent and previous.distance_to(view.actor_position()) < 1.8
		previous = view.actor_position()
	t.check(coherent and observed.size() >= 4, "whole-frame walking advances with bounded movement and retains the complete figure through work and idle")
	t.check(view.visual_pose().kind == "idle", "the original labor deadline still returns to a whole idle drawing")
	view.free()
