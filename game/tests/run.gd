extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Catches a missing implementation without mistaking a parser crash for a test.
	if not ResourceLoader.exists("res://window_layout.gd") or not ResourceLoader.exists("res://save_store.gd"):
		check(false, "window placement and persistent planting are not implemented")
		finish()
		return
	var layout = load("res://window_layout.gd").new()
	check(layout.expanded_position(Vector2i(1100, 600), Rect2i(0, 0, 1440, 900)) == Vector2i(180, 70), "200x210 pet expands to 1120x740 while preserving bottom-right anchor")
	check(layout.expanded_position(Vector2i(12, 12), Rect2i(0, 0, 1440, 900)) == Vector2i(0, 0), "expand near edge stays on screen")
	check(layout.clamp_position(Vector2i(1900, -100), Vector2i(240, 210), Rect2i(0, 25, 1440, 875)) == Vector2i(1200, 25), "disconnected monitor and menu bar are handled")
	check(layout.clamp_position(Vector2i(-900, 300), Vector2i(420, 520), Rect2i(-1440, 0, 1440, 900)) == Vector2i(-900, 300), "negative monitor coordinates are valid")
	var store_script = load("res://save_store.gd")
	var root := OS.get_environment("TOKENBOOK_TEST_DIR")
	check(not root.is_empty(), "tests require isolated temporary data directory")
	if root.is_empty():
		finish()
		return
	var db_path := root.path_join("planting.db")
	var store = store_script.new()
	check(store.open_store(db_path), "SQLite native extension opens a real database")
	if not store.ready:
		finish()
		return
	check(store.snapshot()["seeds"] == 1, "new save has a seed")
	check(store.apply("plant-1", "plant", 1000)["ok"], "plant consumes seed")
	check(store.snapshot()["seeds"] == 0 and store.snapshot()["planted_at"] == 1000, "seed and planting timestamp commit together")
	check(store.apply("plant-1", "plant", 1000)["ok"], "retry returns original success")
	check(not store.apply("plant-1", "harvest", 1200)["ok"], "same id with different command rejected")
	check(not store.apply("harvest-early", "harvest", 1179)["ok"], "early harvest does not grant produce")
	check(not store.apply("harvest-backwards", "harvest", 999)["ok"], "clock rollback never matures crop")
	check(store.apply("harvest-1", "harvest", 1180)["ok"], "mature crop is harvestable at exact boundary")
	check(store.apply("harvest-1", "harvest", 1180)["ok"], "harvest replay succeeds without another reward")
	check(store.snapshot()["harvests"] == 1 and store.snapshot()["seeds"] == 1, "harvest and replacement seed awarded exactly once")
	check(store.save_window(Vector2i(250, 300)), "window position persists")
	store.close_store()
	store = store_script.new()
	check(store.open_store(db_path), "save reopens after shutdown")
	check(store.snapshot()["harvests"] == 1 and store.window_position() == Vector2i(250, 300), "restart restores inventory and window position")
	check(store.apply("harvest-1", "harvest", 1180)["ok"] and store.snapshot()["harvests"] == 1, "deduplication survives process restart")
	store.close_store()
	var bad_path := root.path_join("broken.db")
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("not a SQLite database")
	file.close()
	store = store_script.new()
	check(not store.open_store(bad_path), "corrupt save fails closed")
	check(FileAccess.get_file_as_string(bad_path) == "not a SQLite database", "corrupt save is not overwritten with a new world")
	store.close_store()
	load("res://tests/farm_tests.gd").run(self, root)
	load("res://tests/motion_tests.gd").run(self)
	load("res://tests/gait_tests.gd").run(self)
	load("res://tests/refined_animation_tests.gd").run(self)
	load("res://tests/gesture_tests.gd").run(self)
	finish()

func finish() -> void:
	print("Tokenbook checks: %d, failures: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
