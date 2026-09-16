extends Control

const Layout = preload("res://window_layout.gd")
const Store = preload("res://farm_store.gd")
const Rules = preload("res://farm_rules.gd")
const Farm = preload("res://farm_view.gd")
const Art = preload("res://pixel_art.gd")
var farm_motion := preload("res://farm_motion.gd").new()
var store := Store.new()
var layout := Layout.new()
var expanded := false
var compact_anchor := Vector2i.ZERO
var dpi := 1.0
var tray_id := -1
var farm: Control
var status: Label
var detail: Label
var resources: Label
var action_button: Button
var crop_choice: OptionButton
var selected_plot := 0
var selected_crop := "welcome"
var page := "farm"
var body: Control
var hint: Label
var hint_background: Panel
var page_values: Dictionary = {}
var drag_start := Vector2i.ZERO
var drag_window := Vector2i.ZERO
var dragging := false
var drag_moved := false
var font := FontVariation.new()
var instance_lock: Object
var native_window: Object
var game_hidden := false
var _last_tick := 0
var _last_fingerprint := ""
var _toast := ""
var _toast_until := 0
var music_button: Button
var music: AudioStreamPlayer
var music_tween: Tween
var _quitting := false

func _ready() -> void:
    get_tree().auto_accept_quit = false
    get_window().close_requested.connect(shutdown)
    get_window().transparent_bg = true
    get_window().always_on_top = true
    get_window().unfocusable = true
    Engine.max_fps = 24
    font.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
    font.variation_opentype = {0x77676874: 400.0}
    if ClassDB.class_exists("TokenbookNativeWindow"):
        native_window = ClassDB.instantiate("TokenbookNativeWindow")
    var data_dir := OS.get_environment("TOKENBOOK_DATA_DIR")
    if data_dir.is_empty():
        data_dir = OS.get_user_data_dir()
    DirAccess.make_dir_recursive_absolute(data_dir)
    if ClassDB.class_exists("SQLite"):
        instance_lock = ClassDB.instantiate("SQLite")
        instance_lock.path = data_dir.path_join("instance.lock.db")
        instance_lock.verbosity_level = 0
        if not instance_lock.open_db() or not instance_lock.query("BEGIN EXCLUSIVE"):
            printerr("Tokenbook is already running. Use its menu-bar leaf to restore it.")
            get_tree().quit(2)
            return
    store.open_store(data_dir.path_join("world.db"))
    _last_tick = Time.get_ticks_msec()
    dpi = maxf(1.0, DisplayServer.screen_get_max_scale())
    var usable := usable_rect()
    var saved: Variant = store.window_position()
    compact_anchor = saved if saved != null else usable.end - Layout.COMPACT - Vector2i(24, 48)
    compact_anchor = layout.clamp_position(compact_anchor, Layout.COMPACT, usable)
    if DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
        tray_id = DisplayServer.create_status_indicator(load("res://tray.svg"), "词元之书 · 点击显示 / 隐藏", _tray_clicked)
    apply_layout()
    var timer := Timer.new()
    timer.wait_time = 1.0
    timer.timeout.connect(_tick)
    add_child(timer)
    timer.start()
    start_music()
    refresh()

func usable_rect() -> Rect2i:
    var rect := DisplayServer.screen_get_usable_rect(get_window().current_screen)
    return Rect2i(Vector2i(Vector2(rect.position) / dpi), Vector2i(Vector2(rect.size) / dpi))

func set_expanded(value: bool) -> void:
    expanded = value
    get_window().unfocusable = not expanded
    apply_layout()
    refresh()

func _process(delta: float) -> void:
    farm_motion.advance(delta)
    # Active movement/actions get a smooth presentation; rest/hidden stay cheap.
    var active := not game_hidden and is_instance_valid(farm) and farm.is_visible_in_tree() and farm_motion.busy()
    Engine.max_fps = 60 if active else (12 if game_hidden else 24)

func apply_layout() -> void:
    var dimensions: Vector2i = Layout.EXPANDED if expanded else Layout.COMPACT
    var point := layout.expanded_position(compact_anchor, usable_rect()) if expanded else layout.clamp_position(compact_anchor, dimensions, usable_rect())
    get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    get_window().content_scale_size = dimensions
    get_window().size = Vector2i(Vector2(dimensions) * dpi)
    get_window().position = Vector2i(Vector2(point) * dpi)
    if native_window != null:
        native_window.command(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), 0)
    build_ui(dimensions)

func box(color: String, radius: int = 8) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(color)
    style.set_corner_radius_all(radius)
    style.set_border_width_all(1)
    style.border_color = Color("c8b899")
    return style

func place(node: Control, rect: Rect2, parent: Node = null) -> void:
    var target := self if parent == null else parent
    target.add_child(node)
    node.position = rect.position
    node.size = rect.size

func label(text: String, rect: Rect2, font_size: int = 13, color: String = "657054", parent: Node = null) -> Label:
    var node := Label.new()
    node.text = text
    node.add_theme_font_override("font", font)
    node.add_theme_font_size_override("font_size", font_size)
    node.add_theme_color_override("font_color", Color(color))
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    place(node, rect, parent)
    return node

func button(text: String, rect: Rect2, callback: Callable, primary: bool = false, parent: Node = null) -> Button:
    var node := Button.new()
    node.text = text
    node.add_theme_font_override("font", font)
    node.add_theme_font_size_override("font_size", 13)
    node.add_theme_color_override("font_color", Color("fff8df" if primary else "586648"))
    node.add_theme_color_override("font_hover_color", Color("fff8df" if primary else "405a35"))
    node.add_theme_color_override("font_disabled_color", Color("8b917f"))
    node.add_theme_stylebox_override("normal", box("687f51" if primary else "efe8d5", 6))
    node.add_theme_stylebox_override("hover", box("7f9762" if primary else "e4e6c9", 6))
    node.add_theme_stylebox_override("pressed", box("8a9f6c", 6))
    node.add_theme_stylebox_override("disabled", box("e5e3d3", 6))
    node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    node.pressed.connect(callback)
    place(node, rect, parent)
    return node

func clear_children(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func build_ui(dimensions: Vector2i) -> void:
    for child in get_children():
        if child is Control:
            remove_child(child)
            child.queue_free()
    status = null
    detail = null
    action_button = null
    crop_choice = null
    hint = null
    hint_background = null
    resources = null
    page_values.clear()
    var w := dimensions.x
    var background := Panel.new()
    background.add_theme_stylebox_override("panel", box("f7f0dd", 10))
    place(background, Rect2(1, 1, w - 2, dimensions.y - 2))
    var handle := Control.new()
    handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
    handle.gui_input.connect(header_input)
    place(handle, Rect2(7, 4, w - 105, 28))
    label("词元之书", Rect2(15, 6, 108, 22), 15, "536044")
    music_button = button("♪", Rect2(w - 93, 6, 23, 23), toggle_music)
    music_button.tooltip_text = "背景音乐 · 静音 / 恢复"
    button("−" if expanded else "+", Rect2(w - 63, 6, 23, 23), func(): set_expanded(not expanded)).tooltip_text = "收起陪伴" if expanded else "展开游戏"
    button("×", Rect2(w - 33, 6, 23, 23), shutdown).tooltip_text = "保存并退出"
    if expanded:
        resources = label("", Rect2(16, 33, w - 32, 21), 12, "7c765e")
    body = Control.new()
    place(body, Rect2(0, 55 if expanded else 35, w, 426 if expanded else 127))
    build_page()
    if expanded:
        for index in range(4):
            var keys := ["farm", "bag", "book", "home"]
            var titles := ["农场", "背包", "主书", "小屋"]
            button(titles[index], Rect2(12 + index * 101, 486, 93, 27), func(): show_page(keys[index]), page == keys[index])
        hint_background = Panel.new()
        hint_background.add_theme_stylebox_override("panel", box("f7f0dd", 5))
        hint_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
        place(hint_background, Rect2(20, 63, 380, 44))
        hint = label("", Rect2(29, 65, 362, 40), 12, "536044")
        hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    else:
        status = label("", Rect2(14, 165, w - 28, 20), 12)
        label("本地农场 · 点击小院展开", Rect2(14, 187, w - 28, 16), 10, "91886e")

func build_page() -> void:
    clear_children(body)
    page_values.clear()
    action_button = null
    crop_choice = null
    detail = null
    if not expanded or page == "farm":
        farm = Farm.new()
        farm.motion = farm_motion
        farm.externally_driven = true
        farm.pixel_ratio = dpi
        farm.compact = not expanded
        farm.selected_plot = selected_plot if expanded else -1
        place(farm, Rect2(10, 0, 400 if expanded else 220, 342 if expanded else 127), body)
        farm.plot_selected.connect(select_plot)
        farm.house_selected.connect(func(): show_page("home"))
        farm.water_selected.connect(func(): issue({"type": "water"}))
        farm.cat_petted.connect(func(): toast("小猫眯起眼睛，陪你晒了一会儿太阳。"))
        farm.gui_input.connect(func(event: InputEvent):
            if not expanded and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
                set_expanded(true))
        if expanded:
            status = label("", Rect2(16, 348, 390, 22), 14, "536044", body)
            detail = label("", Rect2(16, 373, 390, 19), 11, "8a8068", body)
            action_button = button("播种", Rect2(14, 396, 253, 29), perform_action, true, body)
            crop_choice = OptionButton.new()
            crop_choice.add_theme_font_override("font", font)
            crop_choice.add_theme_font_size_override("font_size", 12)
            crop_choice.add_theme_stylebox_override("normal", box("efe8d5", 6))
            crop_choice.add_theme_color_override("font_color", Color("586648"))
            for text in ["初春 · 3分钟", "萝卜 · 1小时", "小麦 · 4小时", "土豆 · 8小时"]:
                crop_choice.add_item(text)
            crop_choice.select(["welcome", "radish", "wheat", "potato"].find(selected_crop))
            crop_choice.item_selected.connect(func(index: int):
                selected_crop = ["welcome", "radish", "wheat", "potato"][index]
                refresh())
            place(crop_choice, Rect2(274, 396, 131, 29), body)
        return
    farm = null
    var paper := Panel.new()
    paper.add_theme_stylebox_override("panel", box("faf5e7", 8))
    place(paper, Rect2(12, 2, 396, 418), body)
    if not store.ready:
        label("存档暂不可用", Rect2(28, 22, 330, 25), 19, "8b5c43", body)
        var error := label(store.last_error, Rect2(28, 62, 360, 180), 14, "8b5c43", body)
        error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        return
    if page == "bag":
        build_bag()
    elif page == "book":
        build_book()
    else:
        build_home()

func build_bag() -> void:
    label("随身小仓库", Rect2(28, 18, 320, 28), 21, "586044", body)
    page_values["capacity"] = label("", Rect2(28, 53, 350, 20), 12, "918168", body)
    var state := store.snapshot()
    var crops := ["radish", "wheat", "potato"]
    for i in range(3):
        var crop: String = crops[i]
        var info: Dictionary = Rules.CROPS[crop]
        place(Art.icon(Vector2i(info.atlas, 2)), Rect2(29, 88 + i * 83, 57, 61), body)
        label(info.name, Rect2(102, 92 + i * 83, 110, 21), 16, "586044", body)
        label("收成 %d  ·  种子 %d" % [state.inventory[crop], state.inventory["seed_" + crop]], Rect2(102, 119 + i * 83, 182, 20), 12, "918168", body)
        var amount := int(state.inventory[crop])
        var sell := button("出售全部", Rect2(289, 101 + i * 83, 94, 30), func(): issue({"type": "sell", "crop": crop, "amount": amount}), false, body)
        sell.disabled = amount == 0
        label("%d 金币 / 份" % info.sell, Rect2(293, 135 + i * 83, 100, 18), 10, "918168", body)
    label("成熟的作物会一直留在田里。\n只在你点击出售时交易，没有自动卖出。", Rect2(28, 354, 360, 48), 12, "918168", body)

func build_book() -> void:
    label("词元之书", Rect2(28, 18, 300, 30), 23, "586044", body)
    label("把每一次小小的收获，变成会的事情。", Rect2(28, 54, 360, 24), 12, "918168", body)
    var state := store.snapshot()
    label("木铲耕作", Rect2(30, 102, 280, 27), 19, "586044", body)
    label("开垦新的田地，最多扩展到八块。", Rect2(30, 135, 350, 22), 13, "7b7c61", body)
    var learned: bool = state.learned.has("F01")
    var learn := button("已经学会" if learned else "收录并学习 · 1 智慧", Rect2(29, 171, 350, 36), func(): issue({"type": "learn", "skill": "F01"}), not learned, body)
    learn.disabled = learned or not state.tutorial_done or state.wisdom < 1
    label("木铲与手册已收好。" if state.tutorial_done else "第一株初春萝卜收获后，会发现木铲和手册。", Rect2(30, 214, 350, 24), 11, "918168", body)
    page_values["research"] = label("", Rect2(30, 258, 350, 22), 14, "586044", body)
    var progress := ProgressBar.new()
    progress.show_percentage = false
    progress.add_theme_stylebox_override("background", box("e6dfcb", 3))
    progress.add_theme_stylebox_override("fill", box("a5b87c", 3))
    place(progress, Rect2(30, 289, 348, 7), body)
    page_values["research_progress"] = progress
    label("每满 24 小时自然获得 1 点智慧，不用领取。", Rect2(30, 302, 350, 22), 11, "918168", body)
    label("Codex · 尚未连接", Rect2(30, 350, 330, 22), 13, "7b7c61", body)
    label("不影响单机游玩；不会显示模拟 Token。", Rect2(30, 376, 340, 20), 11, "918168", body)

func build_home() -> void:
    label("屋檐下", Rect2(28, 16, 290, 30), 22, "586044", body)
    label("种子、水和一点轻轻的音乐。", Rect2(28, 49, 350, 22), 12, "918168", body)
    var crops := ["radish", "wheat", "potato"]
    for i in range(3):
        var crop: String = crops[i]
        var info: Dictionary = Rules.CROPS[crop]
        place(Art.icon(Vector2i(info.atlas, 0)), Rect2(28, 79 + i * 48, 38, 41), body)
        label(info.name + "种子 × 5", Rect2(75, 88 + i * 48, 190, 22), 14, "657054", body)
        button("%d 金币" % (info.price * 5), Rect2(286, 84 + i * 48, 96, 30), func(): issue({"type": "buy", "crop": crop, "amount": 5}), false, body)
    button("到水源装满水桶 · 免费", Rect2(28, 231, 354, 32), func(): issue({"type": "water"}), true, body)
    label("音乐", Rect2(28, 279, 50, 22), 13, "657054", body)
    var slider := HSlider.new()
    slider.min_value = 0
    slider.max_value = 0.5
    slider.step = 0.01
    slider.value = store.snapshot().settings.volume
    slider.value_changed.connect(func(value: float):
        if music != null:
            music.volume_db = linear_to_db(maxf(value, 0.0001)))
    slider.drag_ended.connect(func(_changed: bool): issue({"type": "settings", "volume": slider.value}, false))
    place(slider, Rect2(85, 281, 292, 19), body)
    button("取消未开始的安排", Rect2(28, 316, 354, 29), func(): issue({"type": "cancel_queue"}), false, body)
    var hide := button("隐藏到菜单栏", Rect2(28, 356, 169, 29), hide_game, false, body)
    hide.disabled = tray_id < 0 or native_window == null
    button("收起陪伴", Rect2(209, 356, 173, 29), func(): set_expanded(false), false, body)
    label("农场可玩版 0.1 · 本地自动保存", Rect2(28, 393, 350, 19), 10, "918168", body)

func show_page(value: String) -> void:
    _toast_until = 0
    page = value
    if not expanded:
        set_expanded(true)
    else:
        build_ui(Layout.EXPANDED)
    refresh()

func select_plot(id: int) -> void:
    selected_plot = id
    refresh()

func clock_text(seconds: int) -> String:
    if seconds >= 3600:
        return "%d小时%02d分" % [seconds / 3600, (seconds % 3600) / 60]
    return "%d:%02d" % [seconds / 60, seconds % 60]

func _tick() -> void:
    var ticks := Time.get_ticks_msec()
    var elapsed := maxi(0, (ticks - _last_tick) / 1000)
    if elapsed > 0:
        _last_tick += elapsed * 1000
        var previous_notice: String = store.snapshot().get("notice", "")
        store.tick(int(Time.get_unix_time_from_system()), elapsed)
        var next_notice: String = store.snapshot().get("notice", "")
        if next_notice != previous_notice:
            _toast = next_notice
            _toast_until = Time.get_ticks_msec() + 4200
    refresh()

func refresh() -> void:
    if game_hidden:
        return
    if is_instance_valid(hint):
        hint.visible = Time.get_ticks_msec() < _toast_until or not store.ready
        hint_background.visible = hint.visible
        hint.text = _toast if store.ready else store.last_error
    if not store.ready:
        if is_instance_valid(status):
            status.text = "存档暂不可用 · 已停止写入"
        if is_instance_valid(detail):
            detail.text = store.last_error
        if is_instance_valid(action_button):
            action_button.disabled = true
        return
    var state := store.snapshot()
    farm_motion.receive(state)
    var fingerprint := JSON.stringify([state.inventory, state.coins, state.learned, state.tutorial_done])
    if expanded and page != "farm" and fingerprint != _last_fingerprint:
        build_page()
    _last_fingerprint = fingerprint
    if is_instance_valid(resources):
        resources.text = "%d 金币     %d / %d 水     %d 智慧" % [state.coins, state.water, Rules.WATER_CAP, state.wisdom]
    if is_instance_valid(farm):
        farm.set_state(state)
    if is_instance_valid(music_button):
        music_button.text = "♪" if state.settings.music else "静"
    if not expanded:
        var mature := 0
        for id in range(8):
            if Rules.plot_status(state, id).phase == "mature":
                mature += 1
        status.text = "%d 块田可以收获了" % mature if mature > 0 else ("她正慢慢照料小院" if not state.work.is_empty() else "小院安静，作物慢慢长大")
        return
    if page == "bag":
        page_values.capacity.text = "收成 %d / %d 格 · 种子单独收好" % [Rules.stored_count(state), Rules.CAPACITY]
    elif page == "book":
        page_values.research.text = "自然研究 · 距下一点 %s" % clock_text(86400 - int(state.research))
        page_values.research_progress.value = float(state.research) / 864.0
    elif page == "farm":
        update_farm_controls(state)

func update_farm_controls(state: Dictionary) -> void:
    var plot: Dictionary = state.plots[selected_plot]
    var data := Rules.plot_status(state, selected_plot)
    var title: String = "待开垦" if data.phase == "wild" else ("空着的小田" if data.phase == "empty" else Rules.CROPS[plot.crop].name)
    status.text = "第 %d 块田 · %s" % [selected_plot + 1, title]
    if not state.work.is_empty():
        var names := {"plant": "播种", "harvest": "收获", "clear": "开垦", "water": "取水"}
        detail.text = "正在%s · 还需 %d 秒%s" % [names.get(state.work.type, "劳动"), maxi(0, int(state.work.finish) - int(state.sim)), " · 后面还有 %d 项" % state.queue.size() if not state.queue.is_empty() else ""]
    elif not state.queue_block.is_empty():
        detail.text = "安排暂停 · " + state.queue_block
    else:
        detail.text = "成熟后一直保留，不需要守着。" if data.phase == "growing" else "点田地安排劳动，也可以摸摸屋旁的小猫。"
    if state.tutorial_started and selected_crop == "welcome":
        selected_crop = "radish"
        crop_choice.select(1)
    crop_choice.set_item_disabled(0, state.tutorial_started)
    crop_choice.disabled = data.phase != "empty"
    action_button.disabled = Rules.pending(state, selected_plot)
    if action_button.disabled:
        action_button.text = "已经安排 · 慢慢来"
    elif data.phase == "wild":
        action_button.text = "开垦这块田 · %d 金币" % Rules.clear_cost(state)
    elif data.phase == "empty":
        action_button.text = "播种%s · 种子 %d" % [Rules.CROPS[selected_crop].name, state.inventory["seed_" + selected_crop]]
    elif data.phase == "mature":
        action_button.text = "收获这块田 · %d 份" % Rules.CROPS[plot.crop].yield
    else:
        action_button.text = "小苗成长中 · " + clock_text(int(data.remaining))
        action_button.disabled = true

func perform_action() -> void:
    if not store.ready:
        return
    var state := store.snapshot()
    var data := Rules.plot_status(state, selected_plot)
    if data.phase == "empty":
        issue({"type": "plant", "plot": selected_plot, "crop": selected_crop})
    elif data.phase == "mature":
        issue({"type": "harvest", "plot": selected_plot})
    elif data.phase == "wild":
        issue({"type": "clear", "plot": selected_plot})

func issue(request: Dictionary, show_toast: bool = true) -> Dictionary:
    var result := store.apply(Crypto.new().generate_random_bytes(16).hex_encode(), request)
    if show_toast:
        toast(result.message)
    if request.type == "settings":
        update_music()
    if expanded and page != "farm":
        build_page()
    refresh()
    return result

func toast(message: String) -> void:
    _toast = message
    _toast_until = Time.get_ticks_msec() + 4200
    refresh()

func start_music() -> void:
    var path := "res://assets/audio/morning.wav"
    if ResourceLoader.exists(path):
        music = AudioStreamPlayer.new()
        music.stream = load(path)
        music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        music.stream.loop_begin = 0
        music.stream.loop_end = int(music.stream.get_length() * music.stream.mix_rate)
        music.volume_db = -60
        add_child(music)
        music.play()
        update_music()

func update_music() -> void:
    if music == null or not store.ready:
        return
    var settings: Dictionary = store.snapshot().settings
    music.stream_paused = not settings.music
    var target := linear_to_db(maxf(0.0001, float(settings.volume)))
    if music_tween != null:
        music_tween.kill()
    music_tween = create_tween()
    music_tween.tween_property(music, "volume_db", target, 0.6)

func toggle_music() -> void:
    if store.ready:
        issue({"type": "settings", "music": not store.snapshot().settings.music}, false)

func header_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        dragging = true
        drag_moved = false
        drag_start = DisplayServer.mouse_get_position()
        drag_window = get_window().position

func _input(event: InputEvent) -> void:
    if dragging and event is InputEventMouseMotion:
        var delta := DisplayServer.mouse_get_position() - drag_start
        if delta.length() > 5 * dpi:
            drag_moved = true
        if drag_moved:
            get_window().position = drag_window + delta
    if dragging and event is InputEventMouseButton and not event.pressed:
        dragging = false
        var logical := Vector2i(Vector2(get_window().position) / dpi)
        compact_anchor = logical + (Layout.EXPANDED - Layout.COMPACT if expanded else Vector2i.ZERO)
        compact_anchor = layout.clamp_position(compact_anchor, Layout.COMPACT, usable_rect())
        store.save_window(compact_anchor)
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and expanded:
        if page != "farm":
            show_page("farm")
        else:
            set_expanded(false)

func hide_game() -> void:
    if tray_id >= 0 and native_window != null:
        native_window.command(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), 1)
        game_hidden = not is_game_visible()
        if is_instance_valid(farm):
            farm.visible = not game_hidden
        RenderingServer.set_render_loop_enabled(not game_hidden)

func show_game() -> void:
    if store.ready:
        farm_motion.receive(store.snapshot(), true)
    if native_window != null:
        native_window.command(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), 2)
        game_hidden = not is_game_visible()
        if is_instance_valid(farm):
            farm.visible = not game_hidden
        RenderingServer.set_render_loop_enabled(not game_hidden)
    refresh()

func is_game_visible() -> bool:
    return native_window != null and native_window.command(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), 3)

func _tray_clicked(_button: int, _position: Vector2i) -> void:
    if is_game_visible():
        hide_game()
    else:
        show_game()

func shutdown(exit_code: int = 0) -> void:
    if _quitting:
        return
    _quitting = true
    if music_tween != null:
        music_tween.kill()
    if music != null:
        music.stop()
        music.stream = null
    store.save_window(compact_anchor)
    store.close_store()
    if instance_lock != null:
        instance_lock.close_db()
        instance_lock = null
    if tray_id >= 0:
        DisplayServer.delete_status_indicator(tray_id)
    # Let the audio mixing thread release its playback reference before teardown.
    await get_tree().create_timer(0.05).timeout
    get_tree().quit(exit_code)
