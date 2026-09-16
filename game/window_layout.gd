extends RefCounted

const COMPACT := Vector2i(240, 210)
const EXPANDED := Vector2i(420, 520)

func clamp_position(point: Vector2i, dimensions: Vector2i, usable: Rect2i) -> Vector2i:
	var last := usable.position + (usable.size - dimensions).max(Vector2i.ZERO)
	return Vector2i(clampi(point.x, usable.position.x, last.x), clampi(point.y, usable.position.y, last.y))

func expanded_position(compact_position: Vector2i, usable: Rect2i) -> Vector2i:
	return clamp_position(compact_position + COMPACT - EXPANDED, EXPANDED, usable)
