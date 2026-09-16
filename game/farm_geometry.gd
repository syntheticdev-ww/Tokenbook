extends RefCounted

const WORLD := Vector2(384, 342)
# One grid coordinate system drives terrain, crop roots, picking and paths.
# Stable id = row * 4 + column: visual rotation never reorders the saved plots.
const ORIGIN := Vector2(132, 186)
const AXIS_U := Vector2(48, 24)
const AXIS_V := Vector2(-48, 24)
const HALF_BED := 0.4
const HOME := Vector2(228, 138)
const HOME_LANE := Vector2(0, -0.5)
const CAT := Vector2(280, 166)
const HOUSE := Rect2(210, 36, 166, 124)
const WATER := Rect2(312, 129, 23, 28)

static func project(grid: Vector2) -> Vector2:
	return ORIGIN + AXIS_U * grid.x + AXIS_V * grid.y

static func unproject(point: Vector2) -> Vector2:
	var local := point - ORIGIN
	return Vector2((local.x / 48.0 + local.y / 24.0) / 2.0, (local.y / 24.0 - local.x / 48.0) / 2.0)

static func plot_polygon(id: int) -> PackedVector2Array:
	var grid := Vector2(id % 4, id / 4)
	var points := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		points.append(project(grid + corner * HALF_BED))
	return points

static func plot_at(point: Vector2) -> int:
	# The inverse of the shared diamond projection is an axis-aligned grid.
	# Avoid a polygon-ray degeneracy that occasionally classified a far-away
	# point on the upper path as field seven (even outside its bounding box).
	var grid := unproject(point)
	for id in range(8):
		if absf(grid.x - id % 4) <= HALF_BED and absf(grid.y - int(id / 4)) <= HALF_BED:
			return id
	return -1

static func plot_center(id: int) -> Vector2:
	return project(Vector2(id % 4, id / 4))

static func crop_point(id: int, column: int, row: int) -> Vector2:
	return project(Vector2(id % 4, id / 4) + Vector2(column - 1, row - 1) * 0.23)

static func work_point(id: int) -> Vector2:
	return HOME if id < 0 else project(Vector2(id % 4, id / 4 - 0.5))

static func paths() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for row in range(3):
		result.append(PackedVector2Array([project(Vector2(-0.5, row - 0.5)), project(Vector2(3.5, row - 0.5))]))
	for column in range(5):
		result.append(PackedVector2Array([project(Vector2(column - 0.5, -0.5)), project(Vector2(column - 0.5, 1.5))]))
	result.append(PackedVector2Array([HOME, project(HOME_LANE)]))
	return result

static func route(start: Vector2, target: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array([start])
	if start.is_equal_approx(target):
		return path
	var from_home := start.is_equal_approx(HOME)
	var to_home := target.is_equal_approx(HOME)
	var from_grid := HOME_LANE if from_home else unproject(start)
	var to_grid := HOME_LANE if to_home else unproject(target)
	if from_home:
		path.append(project(from_grid))
	# Follow row gutters and the left perimeter, never the old screen-space
	# horizontal spine or a direct diagonal through the beds.
	if not is_equal_approx(from_grid.y, to_grid.y):
		path.append(project(Vector2(-0.5, from_grid.y)))
		path.append(project(Vector2(-0.5, to_grid.y)))
	path.append(project(to_grid))
	if to_home:
		path.append(HOME)
	return path

static func along(path: PackedVector2Array, fraction: float) -> Vector2:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var remaining := total * clampf(fraction, 0, 1)
	for i in range(1, path.size()):
		var distance := path[i - 1].distance_to(path[i])
		if remaining <= distance:
			return path[i - 1].lerp(path[i], remaining / maxf(distance, 0.001))
		remaining -= distance
	return path[path.size() - 1]
