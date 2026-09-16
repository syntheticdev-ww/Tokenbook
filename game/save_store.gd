extends RefCounted

const GROW_SECONDS := 180
var db: Object
var ready := false
var last_error := ""

func open_store(file_path: String) -> bool:
	if not ClassDB.class_exists("SQLite"):
		last_error = "SQLite 扩展未加载，请先运行开发环境准备命令。"
		return false
	db = ClassDB.instantiate("SQLite")
	db.path = file_path
	db.verbosity_level = 0
	if not db.open_db():
		return _failed("无法打开存档，原文件未替换。")
	if not db.query("PRAGMA quick_check") or db.query_result[0].values()[0] != "ok":
		return _failed("存档检查失败，已停止写入；请保留原文件。")
	if not db.query("PRAGMA user_version") or int(db.query_result[0].values()[0]) > 1:
		return _failed("存档版本较新，当前试玩版不会覆盖它。")
	for sql in [
		"PRAGMA journal_mode=WAL", "PRAGMA synchronous=FULL", "PRAGMA foreign_keys=ON",
		"BEGIN IMMEDIATE",
		"CREATE TABLE IF NOT EXISTS world (id INTEGER PRIMARY KEY CHECK(id=1), seeds INTEGER NOT NULL CHECK(seeds>=0), planted_at INTEGER NOT NULL, harvests INTEGER NOT NULL CHECK(harvests>=0))",
		"INSERT OR IGNORE INTO world VALUES (1,1,0,0)",
		"CREATE TABLE IF NOT EXISTS commands (id TEXT PRIMARY KEY, action TEXT NOT NULL, result TEXT NOT NULL)",
		"CREATE TABLE IF NOT EXISTS window_state (id INTEGER PRIMARY KEY CHECK(id=1), x INTEGER NOT NULL, y INTEGER NOT NULL)",
		"PRAGMA user_version=1", "COMMIT"
	]:
		if not db.query(sql):
			db.query("ROLLBACK")
			return _failed("初始化存档失败，已停止写入。")
	ready = true
	return true

func _failed(message: String) -> bool:
	last_error = message
	ready = false
	return false

func snapshot() -> Dictionary:
	if not ready or not db.query("SELECT seeds,planted_at,harvests FROM world WHERE id=1"):
		_failed("读取存档失败，已停止写入。")
		return {}
	return db.query_result[0].duplicate(true)

func apply(command_id: String, action: String, now: int) -> Dictionary:
	if not ready or command_id.is_empty() or now <= 0:
		return {"ok": false, "message": "存档未就绪或命令无效。"}
	if not db.query("BEGIN IMMEDIATE"):
		return {"ok": false, "message": "存档忙碌，请稍后重试。"}
	if not db.query_with_bindings("SELECT action,result FROM commands WHERE id=?", [command_id]):
		return _rollback()
	if not db.query_result.is_empty():
		var previous: Dictionary = db.query_result[0]
		db.query("ROLLBACK")
		if previous.action != action:
			return {"ok": false, "message": "重复命令的内容不同。"}
		return JSON.parse_string(previous.result)
	var state := snapshot()
	if state.is_empty():
		return _rollback()
	var result := {"ok": false, "message": "未知操作。"}
	var sql := ""
	var bindings: Array = []
	if action == "plant":
		if state.planted_at == 0 and state.seeds > 0:
			sql = "UPDATE world SET seeds=seeds-1,planted_at=? WHERE id=1"
			bindings = [now]
			result = {"ok": true, "message": "种好了。去忙吧，小苗会慢慢长大。"}
		else:
			result.message = "田里已经有小苗了。"
	elif action == "harvest":
		if state.planted_at > 0 and now - int(state.planted_at) >= GROW_SECONDS:
			sql = "UPDATE world SET harvests=harvests+1,seeds=seeds+1,planted_at=0 WHERE id=1"
			result = {"ok": true, "message": "收获一份萝卜，也留下一粒种子。"}
		else:
			result.message = "还没成熟，不着急。"
	if not sql.is_empty() and not db.query_with_bindings(sql, bindings):
		return _rollback()
	if not db.query_with_bindings("INSERT INTO commands VALUES (?,?,?)", [command_id, action, JSON.stringify(result)]):
		return _rollback()
	if not db.query("COMMIT"):
		return _rollback()
	return result

func _rollback() -> Dictionary:
	db.query("ROLLBACK")
	return {"ok": false, "message": "保存失败，本次操作未完成。"}

func save_window(point: Vector2i) -> bool:
	return ready and db.query_with_bindings("INSERT INTO window_state VALUES (1,?,?) ON CONFLICT(id) DO UPDATE SET x=excluded.x,y=excluded.y", [point.x, point.y])

func window_position() -> Variant:
	if ready and db.query("SELECT x,y FROM window_state WHERE id=1") and not db.query_result.is_empty():
		return Vector2i(db.query_result[0].x, db.query_result[0].y)
	return null

func close_store() -> void:
	ready = false
	if db != null:
		db.close_db()
		db = null
