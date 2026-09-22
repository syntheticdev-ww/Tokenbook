extends RefCounted

const Art = preload("res://pixel_art.gd")
const COVERAGE = preload("res://sprite_coverage.gdshader")
const PIXEL = preload("res://character_pixel.gdshader")
const AUTHORED = preload("res://sprite_nearest.gdshader")

# Registration must remain continuous, including when differently padded
# drawings switch. Screen-rounding the quad corner moves the whole body.
static func draw_sprite(item: CanvasItem, sprite: Dictionary, local_transform: Transform2D) -> void:
	# One draw preserves the artist's shoulder/arm/torso silhouette. No body
	# strips or independently scaled limb overlays are used by this renderer.
	configure_material(item,sprite)
	item.draw_set_transform_matrix(sprite_transform(item, sprite, local_transform))
	var texture: Texture2D = sprite.texture if sprite.texture is Texture2D else Art.texture(sprite.texture)
	item.draw_texture_rect_region(texture, sprite.destination, sprite.source)

static func sprite_transform(_item: CanvasItem, _sprite: Dictionary, local_transform: Transform2D) -> Transform2D:
	return local_transform

static func coverage_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = COVERAGE
	return result

static func configure_material(item: CanvasItem,sprite: Dictionary) -> void:
	# Shadow materials sample the original silhouette and remain separate.
	if not item.material is ShaderMaterial: return
	var material: ShaderMaterial=item.material
	if material.shader!=COVERAGE and material.shader!=PIXEL and material.shader!=AUTHORED: return
	var pixel: bool=sprite.get("pixel_style",false)
	var shader: Shader=AUTHORED if sprite.get("native_pixels",false) else (PIXEL if pixel else COVERAGE)
	if material.shader!=shader: material.shader=shader
	if pixel:
		var density: Vector2=sprite.source.size/sprite.destination.size
		material.set_shader_parameter("source_anchor",sprite.source.position-sprite.destination.position*density)
		material.set_shader_parameter("source_step",density*float(sprite.get("pixel_pitch",.5)))
