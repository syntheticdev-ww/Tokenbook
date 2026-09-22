extends SceneTree

# GPU regression for continuous travel of the entire silhouette. A held image
# is allowed to change edge coverage: demanding identical pixels rewarded the
# v8 quantization bug. Check head, torso and legs separately, not just the waist.
const Walk = preload("res://walk_art.gd")
const Art = preload("res://pixel_art.gd")
const Raster = preload("res://sprite_raster.gd")
var origin := Vector2(150,235)
var zoom := 1.0
var facing := 1.0
var dpi := 1
var phase := 0.0
var legacy := false
var kind := "walk"
var back := false

class Painter extends Node2D:
	var host
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		material = Art.key_material() if host.legacy else Raster.coverage_material()
	func _draw() -> void:
		var frame := Walk.frame_at(host.phase,host.back) if host.kind == "walk" else (Walk.settle_frame(.6,host.back) if host.kind == "settle" else Art.animated_frame(int(host.phase),host.kind,host.back))
		var transform := Transform2D(0,Vector2(host.facing,1)*host.zoom,0,host.origin)
		if host.legacy:
			# Reproduce the rejected quad snap for a failing negative control.
			var canvas := get_viewport_transform() * get_global_transform()
			var corner: Vector2 = canvas * (transform * frame.destination.position)
			transform.origin += canvas.affine_inverse().basis_xform(corner.round()-corner)
		Raster.draw_sprite(self,frame,transform)

func _initialize() -> void:
	root.hide()
	call_deferred("run")

func centers(pixels: Image) -> Array[float]:
	var values: Array[float] = []
	for band in [Vector2(-34,-22),Vector2(-22,-13),Vector2(-13,2)]:
		var mass := 0.0
		var weighted_x := 0.0
		var top := maxi(0, floori((origin.y+band.x*zoom)*dpi))
		var bottom := mini(pixels.get_height(), ceili((origin.y+band.y*zoom)*dpi))
		var left := maxi(0, floori((origin.x-18*zoom-3)*dpi))
		var right := mini(pixels.get_width(), ceili((origin.x+18*zoom+3)*dpi))
		for y in range(top,bottom):
			for x in range(left,right):
				var alpha := pixels.get_pixel(x,y).a
				mass += alpha
				weighted_x += (x+0.5)*alpha
		assert(mass > 1.0, "each anatomical band must contain rendered character pixels")
		values.append(weighted_x/maxf(mass,0.001))
	return values

func run() -> void:
	legacy = "--legacy" in OS.get_cmdline_user_args()
	facing = -1.0 if "--mirror" in OS.get_cmdline_user_args() else 1.0
	dpi = 2 if "--retina" in OS.get_cmdline_user_args() else 1
	Walk.warm_cache()
	Engine.max_fps = 60
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,280)*dpi
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.canvas_transform = Transform2D(0,Vector2.ONE*dpi,0,Vector2.ZERO)
	var painter := Painter.new()
	painter.host = self
	viewport.add_child(painter)
	var failures := 0
	var camera = load("res://farm_view.gd").new()
	camera.compact = true
	camera.refined_animation = true
	camera._camera_ready = true
	camera.pixel_ratio = dpi
	print("GPU silhouette travel / dpi=",dpi," / mirror=",facing < 0," / rejected snap=",legacy)
	for scale_value in [1.0,2.0,4.8]:
		zoom = scale_value
		var worst_error := [0.0,0.0,0.0]
		for sample in [["walk",0.0,false],["walk",8.0,false],["walk",4.0,true],["settle",0.0,false],["settle",0.0,true],["idle",0.0,false],["work",4.0,false]]:
			kind = sample[0]
			phase = sample[1]
			back = sample[2]
			var reference: Array[float] = []
			for i in range(21):
				var travel := i*0.1
				camera._camera = Vector2(40-travel/dpi,50)
				origin = camera.world_to_view(Vector2(190,285))
				painter.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var measured := centers(viewport.get_texture().get_image())
				if i == 0:
					reference = measured
				else:
					for band in range(3):
						worst_error[band] = maxf(worst_error[band], absf(measured[band]-reference[band]-travel))
		print("zoom=",zoom," / head, torso, legs maximum travel error (physical pixels): ",worst_error)
		if worst_error.any(func(value): return value > 0.23): failures += 1
		kind = "walk"
		back = false
		phase = 8.0
		var reference_y := 0.0
		var vertical_error := 0.0
		for i in range(21):
			var travel := i*0.1
			camera._camera = Vector2(40,50-travel/dpi)
			origin = camera.world_to_view(Vector2(190,285))
			painter.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels := viewport.get_texture().get_image()
			var mass := 0.0
			var weighted_y := 0.0
			for y in range(floori((origin.y-36*zoom)*dpi),ceili((origin.y+3*zoom)*dpi)):
				for x in range(floori((origin.x-18*zoom)*dpi),ceili((origin.x+18*zoom)*dpi)):
					var alpha := pixels.get_pixel(x,y).a
					mass += alpha
					weighted_y += (y+0.5)*alpha
			assert(mass > 1.0)
			var center := weighted_y/maxf(mass,0.001)
			if i == 0: reference_y = center
			else: vertical_error = maxf(vertical_error,absf(center-reference_y-travel))
		print("zoom=",zoom," / vertical travel error (physical pixels): ",vertical_error)
		if vertical_error > 0.23: failures += 1
	camera.free()
	viewport.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
