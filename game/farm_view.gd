extends Control

signal plot_selected(id: int)
signal house_selected
signal water_selected
signal cat_petted

const Rules = preload("res://farm_rules.gd")
const Geometry = preload("res://farm_geometry.gd")
const Art = preload("res://pixel_art.gd")
const Motion = preload("res://farm_motion.gd")
var motion := Motion.new()
var externally_driven := false
var pixel_ratio := 2.0
var selected_plot := -1
var compact := false
var render_scale := 1
var _state: Dictionary = {}
var _clock := 0.0
var _camera := Vector2.ZERO
var _camera_ready := false
var _hovered := -1
var _pet_until := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    material = Art.key_material()
    clip_contents = true
    mouse_exited.connect(func():
        _hovered = -1
        queue_redraw())

func set_state(value: Dictionary) -> void:
    _state = value.duplicate(true)
    motion.receive(value)
    queue_redraw()

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    if not externally_driven:
        motion.advance(delta)
    _clock = motion.clock
    if compact:
        var target := _camera_target()
        _camera = _camera.lerp(target, 1.0 - exp(-delta * 7.0)) if _camera_ready else target
        _camera_ready = true
    # No second frame limiter: the old 20 Hz timer discarded the remainder and
    # became 15 Hz under the 30 FPS window cap. Motion redraws each engine frame.
    queue_redraw()

func actor_position() -> Vector2:
    return motion.position()

func actor_draw_position() -> Vector2:
    return actor_position().snapped(Vector2.ONE / (pixel_ratio * (1 if compact else render_scale)))

func visual_pose() -> Dictionary:
    return motion.pose()

func actor_sprite() -> Dictionary:
    var pose := visual_pose()
    return Art.animated_frame(pose.frame, pose.kind, pose.back)

func _camera_target() -> Vector2:
    var origin := actor_position() + Vector2(0, -20) - size / 2.0
    return origin.clamp(Vector2.ZERO, Geometry.WORLD - size)

func view_offset() -> Vector2:
    if not compact:
        return ((size - Geometry.WORLD * render_scale) / 2.0).floor()
    return -(_camera if _camera_ready else _camera_target()).snapped(Vector2.ONE / pixel_ratio)

func world_to_view(point: Vector2) -> Vector2:
    return point * (1 if compact else render_scale) + view_offset()

func _gui_input(event: InputEvent) -> void:
    if compact:
        return
    if event is InputEventMouseMotion:
        var point: Vector2 = (event.position - view_offset()) / render_scale
        _hovered = Geometry.plot_at(point)
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hovered >= 0 or Geometry.HOUSE.has_point(point) or point.distance_to(Geometry.CAT) < 15 else Control.CURSOR_ARROW
        queue_redraw()
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var point: Vector2 = (event.position - view_offset()) / render_scale
        var id := Geometry.plot_at(point)
        if id >= 0:
            selected_plot = id
            plot_selected.emit(id)
        elif point.distance_to(Geometry.CAT + Vector2(0, -6)) < 15:
            _pet_until = _clock + 2.0
            cat_petted.emit()
        elif Geometry.WATER.has_point(point):
            water_selected.emit()
        elif Geometry.HOUSE.has_point(point):
            house_selected.emit()
        queue_redraw()

func _draw() -> void:
    draw_set_transform(view_offset(), 0, Vector2.ONE * (1 if compact else render_scale))
    draw_texture_rect(Art.texture("farm-background-cohesive-v2"), Rect2(Vector2.ZERO, Geometry.WORLD), false)
    _draw_river_light()
    _draw_paths()
    if not _state.is_empty():
        for id in range(8):
            _draw_plot(id)
    for item in scene_sprites():
        draw_set_transform(view_offset(), 0, Vector2.ONE * (1 if compact else render_scale))
        if item.kind == "actor":
            _draw_actor()
        elif item.kind == "cat":
            _draw_cat()
        else:
            var region := Art.source_rect("farm-atlas", item.cell)
            var texture_size := Art.texture("farm-atlas").get_size()
            var uv := PackedVector2Array([region.position, region.position + Vector2(region.size.x, 0), region.end, region.position + Vector2(0, region.size.y)])
            for index in range(uv.size()):
                uv[index] /= texture_size
            draw_polygon(crop_quad(item.point), PackedColorArray([Color.WHITE]), uv, Art.texture("farm-atlas"))

func crop_quad(point: Vector2) -> PackedVector2Array:
    # Shear only the leaves; keep the planted edge and depth-sort point fixed.
    var breeze := (sin(motion.clock * 1.35 + point.x * 0.018) + sin(motion.clock * 0.63 + point.y * 0.02) * 0.3) * 0.38
    return PackedVector2Array([point + Vector2(-11 + breeze, -20), point + Vector2(11 + breeze, -20), point + Vector2(11, 3), point + Vector2(-11, 3)])

func _draw_river_light() -> void:
    # Small restrained glints stay in the open water, never over the bridge,
    # grass or UI. No full-screen shimmer, bloom or decorative particle rain.
    var water_points := [Vector2(95, 108), Vector2(81, 118), Vector2(63, 130), Vector2(117, 112)]
    for index in range(water_points.size()):
        var phase := motion.clock * 0.72 + index * 1.7
        var glint := maxf(0, sin(phase))
        var point: Vector2 = water_points[index] + Vector2(sin(phase * 0.7) * 0.8, 0)
        draw_rect(Rect2(point.snapped(Vector2.ONE / pixel_ratio), Vector2(1.5 + glint, 0.5)), Color(0.82, 0.94, 0.83, glint * 0.38))

func scene_sprites() -> Array[Dictionary]:
    var result: Array[Dictionary] = [{"kind": "cat", "point": Geometry.CAT}, {"kind": "actor", "point": actor_position()}]
    if not _state.is_empty():
        for id in range(8):
            var plot: Dictionary = _state.plots[id]
            if not plot.unlocked or plot.crop.is_empty():
                continue
            var status := Rules.plot_status(_state, id)
            var cell := Vector2i(Rules.CROPS[plot.crop].atlas, status.stage)
            for row in range(3):
                for col in range(3):
                    result.append({"kind": "crop", "plot": id, "cell": cell, "point": Geometry.crop_point(id, col, row).round()})
    result.sort_custom(func(a: Dictionary, b: Dictionary):
        return a.point.x < b.point.x if is_equal_approx(a.point.y, b.point.y) else a.point.y < b.point.y)
    return result

func _draw_paths() -> void:
    # Reuse the approved scene's actual dirt-path pixels, not a flat UI-colored
    # stroke. Small mapped sections keep their grain at the game's pixel scale.
    var texture := Art.texture("farm-background")
    var texture_size := texture.get_size()
    for path in Geometry.paths():
        var distance := path[0].distance_to(path[1])
        var normal := (path[1] - path[0]).normalized().orthogonal() * 3.5
        var sections := maxi(1, ceili(distance / 12.0))
        for i in range(sections):
            var start := path[0].lerp(path[1], float(i) / sections)
            var finish := path[0].lerp(path[1], float(i + 1) / sections)
            var polygon := PackedVector2Array([start - normal, start + normal, finish + normal, finish - normal])
            var top := 548.0 + (i % 4) * 14.0
            var uv := PackedVector2Array([Vector2(572, top), Vector2(602, top), Vector2(602, top + 36), Vector2(572, top + 36)])
            for index in range(uv.size()):
                uv[index] /= texture_size
            draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, texture)

func _draw_cat() -> void:
    var cat_frame := 1 if fmod(_clock + 1.2, 6.3) < 0.18 or _clock < _pet_until else 0
    draw_rect(Rect2(Geometry.CAT + Vector2(-4, -1), Vector2(8, 2)), Color(0.19, 0.25, 0.17, 0.18))
    Art.sprite(self, "farm-atlas", Vector2i(cat_frame, 3), Rect2(Geometry.CAT + Vector2(-10, -16.25), Vector2(21, 21)))
    if _clock < _pet_until:
        var heart := Geometry.CAT + Vector2(-2, -23 - floor((_pet_until - _clock) * 2))
        draw_rect(Rect2(heart, Vector2(5, 3)), Color("ee9c7a"))
        draw_rect(Rect2(heart + Vector2(1, 3), Vector2(3, 2)), Color("ee9c7a"))

func _draw_plot(id: int) -> void:
    var plot: Dictionary = _state.plots[id]
    var polygon := Geometry.plot_polygon(id)
    Art.sprite(self, "terrain-isometric-atlas", Vector2i(0 if plot.unlocked else 1, 0), Rect2(Geometry.plot_center(id) - Vector2(53, 50), Vector2(106, 106)), Vector2i(2, 1))
    var status := Rules.plot_status(_state, id)
    if status.phase == "mature":
        var marker := polygon[1] + Vector2(-4, 4)
        draw_circle(marker, 3.5, Color("fff0ab"))
        draw_line(marker + Vector2(-1.5, 0), marker + Vector2(-0.2, 1.5), Color("587044"), 1)
        draw_line(marker + Vector2(-0.2, 1.5), marker + Vector2(2, -1.5), Color("587044"), 1)
    if id == selected_plot or id == _hovered:
        polygon.append(polygon[0])
        draw_polyline(polygon, Color("fff0b6") if id == selected_plot else Color("dfe6ac"), 1.5)

func _draw_actor() -> void:
    var scale_factor := 1 if compact else render_scale
    var point := actor_draw_position()
    var pose := visual_pose()
    # Sun direction belongs to the world, not the character's facing direction.
    draw_set_transform(view_offset() + point * scale_factor, 0, Vector2.ONE * scale_factor)
    draw_colored_polygon(PackedVector2Array([Vector2(-4, -1), Vector2(2, -2), Vector2(10, 2), Vector2(11, 4), Vector2(6, 5), Vector2(-3, 1)]), Color(0.24, 0.30, 0.21, 0.17))
    draw_colored_polygon(PackedVector2Array([Vector2(-4,-0.5),Vector2(-2,-1.5),Vector2(2,-1.5),Vector2(4,-0.5),Vector2(3,1),Vector2(-3,1)]), Color(0.22, 0.25, 0.16, 0.21))
    draw_rect(Rect2(-2, -0.5, 4, 1), Color(0.19, 0.25, 0.17, 0.18))
    draw_set_transform(view_offset() + point * scale_factor, 0, Vector2(-1 if pose.right else 1, 1) * scale_factor)
    var sprite := actor_sprite()
    var destination: Rect2 = sprite.destination
    # Do not scale the whole pixel figure to fake breathing: that makes her
    # texture crawl and feet resize against the stationary environment.
    draw_texture_rect_region(Art.texture(sprite.texture), destination, sprite.source)
    if pose.pour:
        for i in range(6):
            var progress := fmod(_clock * 1.05 + i / 6.0, 1.0)
            var drop: Vector2 = (sprite.spout + Vector2(-6 * progress, 19 * progress * progress)).snapped(Vector2.ONE / pixel_ratio)
            draw_rect(Rect2(drop, Vector2(0.5, 1)), Color(0.82, 0.94, 0.95, 0.82))
