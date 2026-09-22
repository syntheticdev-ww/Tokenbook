extends RefCounted

static func run(t: SceneTree) -> void:
	var Walk = load("res://walk_art.gd")
	# The art contract is a complete authored person at one uniform scale.
	# This catches the rejected separately sized/rotated puppet-arm path.
	var complete_walk := true
	var complete_landing := true
	for back in [false,true]:
		for phase in range(32):
			var frame: Dictionary = Walk.frame_at(phase*.5,back)
			complete_walk = complete_walk and not frame.has("arms") and not frame.has("body_slices")
		for progress in [0.0,.5,1.0]:
			var frame: Dictionary = Walk.settle_frame(progress,back)
			complete_landing = complete_landing and not frame.has("arms") and not frame.has("body_slices")
	t.check(complete_walk,"walking preserves a complete shoulder-arm-torso drawing without independently scaled limbs")
	t.check(complete_landing,"landing preserves the same whole-body drawing contract as walking")
	var Farm = load("res://farm_view.gd")
	var Rules = load("res://farm_rules.gd")
	var view = Farm.new()
	view.refined_animation = true
	var state: Dictionary = Rules.initial(1000)
	state.work = {"type":"plant","from_plot":0,"plot":-1,"start":1000,"finish":1012}
	view.set_state(state)
	var rear := {}
	for i in range(180):
		view.motion.advance(1.0/60)
		var pose: Dictionary = view.visual_pose()
		var sprite: Dictionary = view.actor_sprite()
		if pose.kind == "walk" and pose.back:
			rear[sprite.get("drawing",-1)] = true
	t.check(rear.size() >= 12 and not rear.has(-1),"back-facing farm playback uses the new registered gait instead of the early eight-frame sheet")
	view.motion.elapsed = view.motion.travel_time+.12
	t.check(view.actor_sprite().get("settling",false),"arrival uses a closing-foot drawing before switching to standing or work")
	view.free()
	pixel_registration(t)
	settle_registration(t)

static func settle_registration(t: SceneTree) -> void:
	var Walk = load("res://walk_art.gd")
	var Art = load("res://pixel_art.gd")
	var bounds_ok := true
	var palette_jump := 0.0
	var previous_skin := Vector3.ZERO
	for back in [false,true]:
		for progress in [0.0,.5,1.0]:
			var frame: Dictionary = Walk.settle_frame(progress,back)
			var pixels: Image = Art.texture(frame.texture).get_image()
			var top := INF
			var bottom := -INF
			var skin := Vector3.ZERO
			var count := 0
			for y in range(int(frame.source.position.y),mini(pixels.get_height(),ceili(frame.source.end.y))):
				for x in range(int(frame.source.position.x),mini(pixels.get_width(),ceili(frame.source.end.x))):
					var c := pixels.get_pixel(x,y)
					if c.a < .5 or minf(c.r,c.b)-c.g > .23: continue
					var p: Vector2 = frame.destination.position+(Vector2(x,y)-frame.source.position)*frame.destination.size/frame.source.size
					top = minf(top,p.y)
					bottom = maxf(bottom,p.y)
					if not back and Rect2(-3.5,-29,6,7).has_point(p) and c.r > .89 and c.g > .62 and c.b > .28 and c.r-c.g > .035 and c.g-c.b > .10:
						skin += Vector3(c.r,c.g,c.b)
						count += 1
			bounds_ok = bounds_ok and top > -33.5 and top < -32.5 and absf(bottom) < .1
			if not back:
				var mean := skin/maxi(count,1)*255
				if progress > 0: palette_jump = maxf(palette_jump,mean.distance_to(previous_skin))
				previous_skin = mean
	t.check(bounds_ok,"all closing-foot poses retain standing height and a grounded sole without an extra crouch")
	t.check(palette_jump < 8,"front closing-foot poses keep the same face palette rather than flashing skin tones")

static func pixel_registration(t: SceneTree) -> void:
	var Walk = load("res://walk_art.gd")
	var Art = load("res://pixel_art.gd")
	var heads: Array[Vector2] = []
	var torsos: Array[Vector2] = []
	var worst_sole := 0.0
	for phase in Walk.BACK_PHASES:
		var frame: Dictionary = Walk.frame_at(phase,true)
		var pixels: Image = Art.texture(frame.texture).get_image()
		var top := INF
		var bottom := -INF
		var points := []
		for y in range(int(frame.source.position.y),mini(pixels.get_height(),ceili(frame.source.end.y))):
			for x in range(int(frame.source.position.x),mini(pixels.get_width(),ceili(frame.source.end.x))):
				var c := pixels.get_pixel(x,y)
				if c.a < .5 or minf(c.r,c.b)-c.g > .23: continue
				var p: Vector2 = Vector2(x,y)-frame.source.position
				points.append([p,c])
				top = minf(top,p.y)
				bottom = maxf(bottom,p.y)
		var head := Vector2.ZERO
		var head_count := 0
		var torso := Vector2.ZERO
		var torso_count := 0
		for point in points:
			var p: Vector2 = point[0]
			var c: Color = point[1]
			if p.y < top+112:
				head += p
				head_count += 1
			if p.y >= top+112 and p.y < top+145 and c.g > c.r*1.06 and c.g > c.b*1.04:
				torso += p
				torso_count += 1
		heads.append((head/maxi(head_count,1)-frame.anchor)*Walk.BACK_SCALE)
		torsos.append((torso/maxi(torso_count,1)-frame.anchor)*Walk.BACK_SCALE)
		worst_sole = maxf(worst_sole,absf(frame.destination.position.y+bottom*Walk.BACK_SCALE))
	var head_jump := 0.0
	var torso_jump := 0.0
	for i in range(heads.size()):
		head_jump = maxf(head_jump,heads[i].distance_to(heads[(i+1)%heads.size()]))
		torso_jump = maxf(torso_jump,torsos[i].distance_to(torsos[(i+1)%torsos.size()]))
	# Match the front's sub-.35 world-pixel landmark budget for BOTH regions;
	# pinning the head alone is not acceptable if the shirt absorbs the error.
	t.check(head_jump < .35 and torso_jump < .35,"sampled rear head and shirt remain registered across the complete cycle")
	t.check(worst_sole < 1.0,"rear steps retain contact with the ground instead of jumping or floating")
	print("Rear registration: head=",head_jump," shirt=",torso_jump," sole=",worst_sole)
