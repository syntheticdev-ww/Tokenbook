extends SceneTree

# Offline authoring measurements only. No per-frame resizing in the game.
func _initialize() -> void:
	for entry in [["gardener-walk-v4", 4], ["gardener-work-v4", 5]]:
		var pixels := Image.load_from_file("res://assets/art/" + entry[0] + ".png")
		var inset_y := 30.0 if entry[1] == 4 else 25.0
		var cell := Vector2(pixels.get_width() / 4.0, 350 if entry[1] == 4 else 310)
		print(entry[0], " cell=", cell)
		for frame in range(4 * entry[1]):
			var origin := Vector2(frame % 4, frame / 4) * cell + Vector2(0, inset_y)
			var top := cell.y
			var bottom := 0.0
			var points := PackedVector2Array()
			for y in range(ceili(origin.y), floori(origin.y + cell.y)):
				for x in range(ceili(origin.x), floori(origin.x + cell.x)):
					var c := pixels.get_pixel(x, y)
					if c.a < 0.5 or (minf(c.r, c.b) - c.g > 0.23 and c.r > 0.35 and c.b > 0.35): continue
					var p := Vector2(x, y) - origin
					top = minf(top, p.y)
					bottom = maxf(bottom, p.y + 1)
					points.append(p)
			var left := cell.x
			var right := 0.0
			for p in points:
				if p.y > bottom - cell.y * 0.16:
					left = minf(left, p.x)
					right = maxf(right, p.x + 1)
			var head_total := 0.0
			var head_count := 0
			for p in points:
				if p.y < top + (bottom - top) * 0.25:
					head_total += p.x
					head_count += 1
			print("frame %02d pivot=(%.3f,%.3f) height=%.3f head_x=%.3f" % [frame, (left + right) / 2 / cell.x * 30, bottom / cell.x * 30, (bottom - top) / cell.x * 30, head_total / maxf(1, head_count) / cell.x * 30])
	quit()
