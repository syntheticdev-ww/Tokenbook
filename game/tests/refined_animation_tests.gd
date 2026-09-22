extends RefCounted

static func run(t: SceneTree) -> void:
	var Walk = load("res://walk_art.gd")
	var view = load("res://farm_view.gd").new()
	if view.get("refined_animation") == null:
		t.check(false, "the game must consume the refined whole-body walk, not only the standalone preview")
		view.free()
		return
	view.refined_animation = true
	var Rules = load("res://farm_rules.gd")
	view.set_state(Rules.command(Rules.initial(1000), {"type":"plant", "plot":0, "crop":"welcome"}).state)
	var seen := {}
	var valid := true
	for i in range(230):
		view.motion.advance(1.0 / 60)
		var pose: Dictionary = view.visual_pose()
		var sprite: Dictionary = view.actor_sprite()
		if pose.kind == "walk" and not pose.back:
			seen[sprite.drawing] = true
			var expected: String = Walk.REPAIRED_ATLAS if sprite.drawing == Walk.REPAIRED_DRAWING else Walk.ATLAS
			if sprite.drawing in Walk.ORIGINAL_DRAWINGS: expected = Walk.ORIGINAL_ATLAS
			if sprite.drawing in Walk.GESTURE_REPAIR_DRAWINGS: expected = Walk.GESTURE_REPAIR_ATLAS
			valid = valid and pose.frame == sprite.drawing and sprite.texture == expected
	t.check(valid and seen.size() == Walk.PHASES.size() and seen.keys().all(func(id): return id >= 0 and id < Walk.BELTS.size()), "actual farm playback consumes every drawing, including the selected whole-frame repair")
	view.motion.advance(12)
	t.check(view.visual_pose().kind == "idle" and view.actor_sprite().texture == "gardener-work-v4", "refinement preserves work completion and the existing idle artwork")
	view.free()
	registration(t)
	source_palette(t)
	source_head_volume(t)
	compact_camera(t)

static func source_head_volume(t: SceneTree) -> void:
	var Walk = load("res://walk_art.gd")
	var Art = load("res://pixel_art.gd")
	var centers: Array[Vector2] = []
	var torsos: Array[Vector2] = []
	var enough_pixels := true
	for phase in Walk.PHASES:
		var frame: Dictionary = Walk.frame_at(phase)
		var pixels: Image = Art.texture(frame.texture).get_image()
		var sum := Vector2.ZERO
		var count := 0
		var torso := Vector2.ZERO
		var torso_count := 0
		# Whole head/hair silhouette, not just the registered eye. Detects an
		# outline swelling sideways even when eye and waist landmarks agree.
		for y in range(int(frame.source.position.y),mini(pixels.get_height(),ceili(frame.source.end.y))):
			for x in range(int(frame.source.position.x),mini(pixels.get_width(),ceili(frame.source.end.x))):
				var p: Vector2 = Vector2(x,y)-frame.source.position
				var c := pixels.get_pixel(x,y)
				if c.a < 0.5 or minf(c.r,c.b)-c.g > 0.23: continue
				if p.y < frame.belt.y-32:
					sum += p
					count += 1
				if p.y > frame.belt.y-45 and p.y < frame.belt.y and p.x > frame.belt.x-28 and p.x < frame.belt.x+24 and c.g > c.r*1.06 and c.g > c.b*1.04:
					torso += p
					torso_count += 1
		enough_pixels = enough_pixels and count > 100
		centers.append((sum/maxi(count,1)-frame.anchor)*Walk.SOURCE_SCALE)
		enough_pixels = enough_pixels and torso_count > 100
		torsos.append((torso/maxi(torso_count,1)-frame.anchor)*Walk.SOURCE_SCALE)
	var worst := 0.0
	var worst_torso := 0.0
	for i in range(centers.size()):
		worst = maxf(worst,centers[i].distance_to(centers[(i+1)%centers.size()]))
		worst_torso = maxf(worst_torso,torsos[i].distance_to(torsos[(i+1)%torsos.size()]))
	t.check(enough_pixels and worst < 0.34, "whole-head silhouette avoids half-pixel lateral pops across adjacent drawings and loop seam")
	t.check(enough_pixels and worst_torso < 0.35, "head registration does not introduce larger torso jumps")
	print("Source head silhouette: worst adjacent centroid jump=",worst," world px")
	print("Source torso: worst adjacent centroid jump=",worst_torso," world px")

static func compact_camera(t: SceneTree) -> void:
	var view = load("res://farm_view.gd").new()
	view.refined_animation = true
	view.compact = true
	view._camera_ready = true
	var worst := 0.0
	# Hold the world/pose fixed: only the camera moves. This isolates camera
	# quantization from atlas changes and from the character's own travel.
	for dpi in [1.0,2.0]:
		view.pixel_ratio = dpi
		var previous := Vector2.ZERO
		for i in range(60):
			view._camera = Vector2(40,50)+Vector2(0.03,0.04)*i
			var actual: Vector2 = view.world_to_view(Vector2(150,160))
			if i > 0: worst = maxf(worst,(actual-previous+Vector2(0.03,0.04)).length())
			previous = actual
	t.check(worst < 0.0001, "compact camera preserves continuous subpixel screen travel for a held character pose")
	print("Compact camera unexpected step: ",worst," world px")
	view.free()

static func source_palette(t: SceneTree) -> void:
	var Walk = load("res://walk_art.gd")
	var Art = load("res://pixel_art.gd")
	var colors: Array[Vector3] = []
	var eyes: Array[Vector2] = []
	var belts: Array[Vector2] = []
	var enough_pixels := true
	for phase in Walk.PHASES:
		var frame: Dictionary = Walk.frame_at(phase)
		var pixels: Image = Art.texture(frame.texture).get_image()
		var source_scale: float = frame.destination.size.x/frame.source.size.x
		var belt: Vector2 = frame.belt
		# The same face region in world units, independent of atlas resolution.
		var face := Rect2(frame.source.position+belt+Vector2(-2.89,-10.604)/source_scale,Vector2(5.14,5.33)/source_scale)
		var sum := Vector3.ZERO
		var count := 0
		var eye := Vector2.ZERO
		var eye_count := 0
		var eye_roi := Rect2(frame.source.position+belt+Vector2(-1.478,-9.704)/source_scale,Vector2(2.121,2.185)/source_scale)
		for y in range(int(face.position.y),ceili(face.end.y)):
			for x in range(int(face.position.x),ceili(face.end.x)):
				var c := pixels.get_pixel(x,y)
				if c.r > 0.89 and c.g > 0.62 and c.b > 0.28 and c.r-c.g > 0.035 and c.g-c.b > 0.10:
					sum += Vector3(c.r,c.g,c.b)
					count += 1
				if eye_roi.has_point(Vector2(x,y)) and c.r > 0.12 and c.r < 0.68 and c.g < 0.30 and c.b < 0.28 and c.r > c.g*1.4:
					eye += Vector2(x,y)
					eye_count += 1
		enough_pixels = enough_pixels and count >= 80
		colors.append(sum/maxi(count,1))
		var anchor: Vector2 = frame.get("anchor",belt)
		# Eye center is sampled from pixels; belt is a manually calibrated source
		# landmark. Its bound detects registration compensation, not art redraws.
		eyes.append((eye/maxi(eye_count,1)-frame.source.position-anchor)*source_scale)
		belts.append((belt-anchor)*source_scale)
		enough_pixels = enough_pixels and eye_count >= 10
	var worst := 0.0
	var worst_eye := 0.0
	var worst_belt := 0.0
	for i in range(colors.size()):
		worst = maxf(worst,colors[i].distance_to(colors[(i+1)%colors.size()])*255.0)
		worst_eye = maxf(worst_eye,eyes[i].distance_to(eyes[(i+1)%eyes.size()]))
		worst_belt = maxf(worst_belt,belts[i].distance_to(belts[(i+1)%belts.size()]))
	t.check(enough_pixels and worst < 8.0, "source face palette stays consistent across every drawing and the loop seam")
	t.check(enough_pixels and worst_eye < 0.24 and worst_belt < 0.24, "sampled eye and calibrated waist both stay within a subpixel registration budget")
	print("Source face palette: worst adjacent RGB distance=",worst," / 255")
	print("Registration jumps: sampled eye=",worst_eye," calibrated waist=",worst_belt," world px")

static func registration(t: SceneTree) -> void:
	var Walk = load("res://walk_art.gd")
	var Raster = load("res://sprite_raster.gd")
	var canvas := Node2D.new()
	t.root.add_child(canvas)
	var worst_cut := 0.0
	var worst_travel := 0.0
	for zoom in [1.0, 2.0, 4.8]:
		for facing in [-1.0, 1.0]:
			for i in range(Walk.PHASES.size()):
				var a: float = Walk.PHASES[i]
				var b: float = Walk.PHASES[i + 1] if i + 1 < Walk.PHASES.size() else 16.0
				var anchors: Array[Vector2] = []
				for phase in [(a+b)/2.0-0.00001, (a+b)/2.0+0.00001]:
					var frame: Dictionary = Walk.frame_at(phase)
					var buckle: Vector2 = frame.belt
					var scale_value: float = frame.destination.size.x/frame.source.size.x
					var transform := Transform2D(0, Vector2(facing, 1) * zoom, 0, Vector2(150.23, 234.71))
					var rendered: Transform2D = Raster.sprite_transform(canvas, frame, transform)
					anchors.append(rendered * (frame.destination.position + frame.get("anchor",buckle) * scale_value))
				worst_cut = maxf(worst_cut, anchors[0].distance_to(anchors[1]))
			var held: Dictionary = Walk.frame_at(0.0)
			for i in range(30):
				var transform := Transform2D(0, Vector2(facing, 1) * zoom, 0, Vector2(150.0+i*0.037, 234.7+i*0.013))
				var rendered: Transform2D = Raster.sprite_transform(canvas, held, transform)
				worst_travel = maxf(worst_travel, rendered.origin.distance_to(transform.origin))
	t.check(worst_cut < 0.001, "switching atlas cells does not teleport the whole-body anchor (including cycle wrap and mirroring)")
	t.check(worst_travel < 0.00001, "fractional travel is continuous instead of rounded to physical-pixel steps")
	print("Whole-body registration: worst cut=", worst_cut, " px, travel quantization=", worst_travel, " px")
	canvas.free()
