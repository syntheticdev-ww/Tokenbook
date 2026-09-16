extends RefCounted

const LegacyStore = preload("res://save_store.gd")
const Rules = preload("res://farm_rules.gd")
var legacy := LegacyStore.new()
var db: Object
var ready := false
var last_error := ""
var _state: Dictionary = {}

func open_store(path: String, now: int = -1) -> bool:
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	var existed := FileAccess.file_exists(path)
	if not legacy.open_store(path):
		return _failed(legacy.last_error)
	db = legacy.db
	if not db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='farm_state'"):
		return _failed("无法读取存档结构，原档保留。")
	if db.query_result.is_empty():
		# VACUUM INTO includes committed WAL data; never copy a live .db file.
		var backup := path + ".pre-farm-v1.sqlite"
		if existed and not FileAccess.file_exists(backup) and not db.query_with_bindings("VACUUM INTO ?", [backup]):
			return _failed("升级前备份失败，原存档没有升级。")
		var state := Rules.initial(now, legacy.snapshot())
		if not db.query("BEGIN IMMEDIATE"):
			return _failed("存档忙碌，稍后再试。")
		for sql in ["CREATE TABLE farm_state (id INTEGER PRIMARY KEY CHECK(id=1), data TEXT NOT NULL)", "CREATE TABLE farm_commands (id TEXT PRIMARY KEY, payload TEXT NOT NULL, result TEXT NOT NULL)"]:
			if not db.query(sql):
				return _rollback("升级失败，原进度与备份均保留。")
		if not db.query_with_bindings("INSERT INTO farm_state VALUES (1,?)", [JSON.stringify(state)]) or not db.query("COMMIT"):
			return _rollback("升级失败，原进度与备份均保留。")
	if not db.query("SELECT data FROM farm_state WHERE id=1") or db.query_result.is_empty():
		return _failed("农场存档缺失，已停止写入。")
	var loaded: Variant = JSON.parse_string(db.query_result[0].data)
	if not _valid_state(loaded):
		return _failed("农场存档版本或内容异常，已停止写入；请保留原文件。")
	_state = loaded
	ready = true
	return tick(now)

func _valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1:
		return false
	for key in ["sim", "wall", "coins", "water", "wisdom", "research", "harvests", "tutorial_started", "tutorial_done", "learned", "plots", "work", "queue", "queue_block", "actor_plot", "notice", "settings", "inventory"]:
		if not value.has(key):
			return false
	for key in ["sim", "wall", "coins", "water", "wisdom", "research", "harvests"]:
		if not _whole(value[key]):
			return false
	if value.water > Rules.WATER_CAP or value.research >= 86400 or not _whole(value.actor_plot, -1, 7):
		return false
	if not value.tutorial_started is bool or not value.tutorial_done is bool or (value.tutorial_done and not value.tutorial_started):
		return false
	if not value.notice is String or not value.queue_block is String or not value.learned is Array:
		return false
	if value.learned.size() > 1 or (not value.learned.is_empty() and value.learned[0] != "F01"):
		return false
	if not value.settings is Dictionary or not value.settings.get("music") is bool:
		return false
	var volume: Variant = value.settings.get("volume")
	if not _number(volume) or volume < 0 or volume > 0.5:
		return false
	if not value.plots is Array or value.plots.size() != 8 or not value.inventory is Dictionary or not value.queue is Array or value.queue.size() > Rules.QUEUE_LIMIT or not value.work is Dictionary:
		return false
	for key in ["seed_welcome", "seed_radish", "seed_wheat", "seed_potato", "radish", "wheat", "potato"]:
		if not _whole(value.inventory.get(key)):
			return false
	for plot in value.plots:
		if not plot is Dictionary or not plot.has_all(["unlocked", "crop", "planted", "duration"]):
			return false
		if not plot.unlocked is bool or not plot.crop is String or not _whole(plot.planted) or not _whole(plot.duration):
			return false
		if plot.crop.is_empty():
			if plot.planted != 0 or plot.duration != 0:
				return false
		elif not Rules.CROPS.has(plot.crop) or not plot.unlocked or plot.planted > value.sim or plot.duration != Rules.CROPS[plot.crop].seconds:
			return false
	var targets := []
	if not value.work.is_empty():
		if not _valid_job(value.work, true, value):
			return false
		targets.append(value.work.get("plot", -1))
	for job in value.queue:
		if not _valid_job(job, false, value) or targets.has(job.get("plot", -1)):
			return false
		targets.append(job.get("plot", -1))
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _whole(value: Variant, minimum: int = 0, maximum: int = 9000000000000) -> bool:
	return _number(value) and value >= minimum and value <= maximum and float(value) == floor(float(value))

func _valid_job(job: Variant, running: bool, state: Dictionary) -> bool:
	if not job is Dictionary or not job.get("type") in ["plant", "harvest", "clear", "water"]:
		return false
	if job.type == "water":
		if job.has("plot"):
			return false
	else:
		if not _whole(job.get("plot"), 0, 7):
			return false
		var plot: Dictionary = state.plots[int(job.plot)]
		if job.type == "clear":
			if plot.unlocked or not state.learned.has("F01"):
				return false
		elif not plot.unlocked:
			return false
		elif job.type == "plant":
			if not job.get("crop") is String or not Rules.CROPS.has(job.crop) or not plot.crop.is_empty():
				return false
		elif Rules.plot_status(state, int(job.plot)).phase != "mature":
			return false
	if running:
		if not _whole(job.get("start")) or not _whole(job.get("finish")) or not _whole(job.get("from_plot"), -1, 7):
			return false
		if job.start > state.sim or job.finish <= state.sim or job.finish - job.start != Rules.LABOR_SECONDS:
			return false
	return true

func snapshot() -> Dictionary:
	return _state.duplicate(true) if ready else {}

func tick(now: int, elapsed: int = -1) -> bool:
	if not ready:
		return false
	var next := Rules.advance(_state, now, elapsed)
	if next == _state:
		return true
	if not db.query_with_bindings("UPDATE farm_state SET data=? WHERE id=1", [JSON.stringify(next)]):
		return _failed("保存失败，游戏已暂停写入；请保留存档。")
	_state = next
	return true

func apply(id: String, request: Dictionary) -> Dictionary:
	if not ready or id.is_empty() or id.length() > 200:
		return {"ok": false, "message": "存档未就绪。"}
	var keys := request.keys()
	keys.sort()
	var canonical := {}
	for key in keys:
		canonical[key] = request[key]
	var payload := JSON.stringify(canonical)
	if not db.query("BEGIN IMMEDIATE"):
		return {"ok": false, "message": "存档忙碌，请稍后重试。"}
	if not db.query_with_bindings("SELECT payload,result FROM farm_commands WHERE id=?", [id]):
		return _write_failed()
	if not db.query_result.is_empty():
		var previous: Dictionary = db.query_result[0]
		db.query("ROLLBACK")
		return JSON.parse_string(previous.result) if previous.payload == payload else {"ok": false, "message": "重复命令的参数不同。"}
	var result := Rules.command(_state, request)
	var public_result := {"ok": result.ok, "message": result.message}
	if not db.query_with_bindings("UPDATE farm_state SET data=? WHERE id=1", [JSON.stringify(result.state)]):
		return _write_failed()
	if not db.query_with_bindings("INSERT INTO farm_commands VALUES (?,?,?)", [id, payload, JSON.stringify(public_result)]) or not db.query("COMMIT"):
		return _write_failed()
	_state = result.state
	return public_result

func _write_failed() -> Dictionary:
	_rollback("保存失败，本次操作没有生效。")
	return {"ok": false, "message": last_error}

func _rollback(message: String) -> bool:
	db.query("ROLLBACK")
	return _failed(message)

func _failed(message: String) -> bool:
	ready = false
	last_error = message
	return false

func save_window(point: Vector2i) -> bool:
	return legacy.save_window(point)

func window_position() -> Variant:
	return legacy.window_position()

func close_store() -> void:
	ready = false
	legacy.close_store()
	db = null
