extends RefCounted

static var _textures: Dictionary = {}
const WALK_ANCHORS := [
	Vector2(15.25,36.685), Vector2(15.0,36.133), Vector2(13.25,36.685), Vector2(12.75,36.685),
	Vector2(15.125,35.028), Vector2(14.375,35.028), Vector2(12.75,35.138), Vector2(12.875,34.586),
	Vector2(15.25,36.243), Vector2(15.0,36.685), Vector2(14.25,36.685), Vector2(13.125,36.685),
	Vector2(15.375,34.475), Vector2(14.875,34.586), Vector2(13.25,34.917), Vector2(12.75,35.249),
]
const WORK_ANCHORS := [
	Vector2(14.830,36.087), Vector2(13.749,36.087), Vector2(12.111,36.087), Vector2(12.019,36.087),
	Vector2(16.375,36.457), Vector2(16.591,36.457), Vector2(12.297,36.334), Vector2(11.895,36.334),
	Vector2(14.830,36.457), Vector2(15.973,36.457), Vector2(14.212,36.457), Vector2(13.440,36.457),
	Vector2(15.819,35.839), Vector2(16.344,35.839), Vector2(14.027,35.839), Vector2(12.945,35.839),
	Vector2(14.830,36.704), Vector2(14.181,36.581), Vector2(12.049,36.704), Vector2(11.771,36.581),
]

static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://assets/art/" + name + ".png")
	return _textures[name]

static func key_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://chroma_key.gdshader")
	return result

static func source_rect(name: String, cell: Vector2i, grid := Vector2i(4, 4)) -> Rect2:
	var dimensions := texture(name).get_size() / Vector2(grid)
	return Rect2(Vector2(cell) * dimensions, dimensions)

static func sprite(canvas: CanvasItem, name: String, cell: Vector2i, destination: Rect2, grid := Vector2i(4, 4)) -> void:
	canvas.draw_texture_rect_region(texture(name), destination, source_rect(name, cell, grid))

static func animated_frame(frame: int, kind: String, back := false) -> Dictionary:
	# Calibrated sheet interiors exclude the generator's uneven outer margins.
	# One scale per sheet, never stretch an individual bent pose. Neutral work
	# poses reuse the exact idle drawing, so putting a tool away cannot resize her.
	var walking := kind == "walk"
	var name := "gardener-walk-v4" if walking else "gardener-work-v4"
	var anchors := WALK_ANCHORS if walking else WORK_ANCHORS
	var index := frame + (8 if back else 0) if walking else (16 + frame if kind == "idle" else frame)
	if not walking and index in [0, 8, 15]:
		index = 16
	var cell := Vector2(texture(name).get_width() / 4.0, 350 if walking else 310)
	var source := Rect2(Vector2(index % 4, int(index / 4)) * cell + Vector2(0, 30 if walking else 25), cell)
	# Sheet densities differ: a fixed scale per sheet makes the whole walk
	# figure match idle/work, without stretching individual poses or limbs.
	var scale := 1.0 if walking else 0.95
	var destination := Rect2(-anchors[index] * scale, cell * (30.0 / cell.x) * scale)
	return {
		"texture": name,
		"source": source,
		"destination": destination,
		"spout": (Vector2(3.8, 27.2) - anchors[index]) * scale if not walking and index in [4, 5] else Vector2.ZERO,
	}

static func icon(cell: Vector2i) -> TextureRect:
	var node := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture("farm-atlas")
	atlas.region = source_rect("farm-atlas", cell)
	node.texture = atlas
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.material = key_material()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
