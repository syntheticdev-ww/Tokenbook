extends RefCounted

# Pure rules. Simulation time is independent of rendering and scene animation.
const CROPS := {
	"welcome": {"name": "初春萝卜", "seconds": 180, "water": 2, "yield": 3, "price": 0, "sell": 4, "atlas": 0},
	"radish": {"name": "萝卜", "seconds": 3600, "water": 2, "yield": 5, "price": 2, "sell": 4, "atlas": 0},
	"wheat": {"name": "小麦", "seconds": 14400, "water": 4, "yield": 6, "price": 4, "sell": 7, "atlas": 1},
	"potato": {"name": "土豆", "seconds": 28800, "water": 6, "yield": 8, "price": 6, "sell": 10, "atlas": 2},
}
const CAPACITY := 120
const WATER_CAP := 60
const LABOR_SECONDS := 12
const QUEUE_LIMIT := 5

static func initial(now: int, legacy: Dictionary = {}) -> Dictionary:
	var harvested := int(legacy.get("harvests", 0))
	var old_crop := int(legacy.get("planted_at", 0))
	var state := {
		"version": 1, "sim": now, "wall": now, "coins": 40, "water": 40, "wisdom": 1 if harvested > 0 else 0,
		"research": 0, "harvests": harvested, "tutorial_started": old_crop > 0 or harvested > 0,
		"tutorial_done": harvested > 0, "learned": [], "plots": [], "work": {}, "queue": [],
		"queue_block": "", "actor_plot": -1, "notice": "点一块田，种下一点期待。",
		"settings": {"music": true, "volume": 0.15},
		"inventory": {"seed_welcome": 0 if old_crop > 0 or harvested > 0 else 1, "seed_radish": 6, "seed_wheat": 3, "seed_potato": 3, "radish": harvested, "wheat": 0, "potato": 0}
	}
	for i in range(8):
		state.plots.append({"unlocked": i < 4, "crop": "", "planted": 0, "duration": 0})
	if old_crop > 0:
		state.plots[0] = {"unlocked": true, "crop": "welcome", "planted": now - clampi(now - old_crop, 0, 180), "duration": 180}
	return state

static func stored_count(state: Dictionary) -> int:
	return int(state.inventory.radish) + int(state.inventory.wheat) + int(state.inventory.potato)

static func clear_cost(state: Dictionary) -> int:
	var opened := 0
	for plot in state.plots:
		if plot.unlocked:
			opened += 1
	return 20 + maxi(0, opened - 4) * 10

static func plot_status(state: Dictionary, id: int) -> Dictionary:
	if id < 0 or id >= state.plots.size():
		return {"phase": "invalid", "remaining": 0, "progress": 0.0, "stage": 0}
	var plot: Dictionary = state.plots[id]
	if not plot.unlocked:
		return {"phase": "wild", "remaining": 0, "progress": 0.0, "stage": 0}
	if plot.crop.is_empty():
		return {"phase": "empty", "remaining": 0, "progress": 0.0, "stage": 0}
	var elapsed := maxi(0, int(state.sim) - int(plot.planted))
	var remaining := maxi(0, int(plot.duration) - elapsed)
	var progress := clampf(float(elapsed) / maxi(1, int(plot.duration)), 0, 1)
	return {"phase": "mature" if remaining == 0 else "growing", "remaining": remaining, "progress": progress, "stage": 2 if remaining == 0 else (1 if progress >= 0.33 else 0)}

static func pending(state: Dictionary, id: int) -> bool:
	if not state.work.is_empty() and int(state.work.get("plot", -1)) == id:
		return true
	for job in state.queue:
		if int(job.get("plot", -1)) == id:
			return true
	return false

static func _validate_job(state: Dictionary, job: Dictionary) -> String:
	var kind: String = job.get("type", "")
	if kind == "water":
		return "水桶已经满了。" if state.water >= WATER_CAP else ""
	var id := int(job.get("plot", -1))
	if id < 0 or id >= state.plots.size():
		return "请先选择一块田。"
	var plot: Dictionary = state.plots[id]
	if kind == "clear":
		if plot.unlocked:
			return "这块田已经开垦好了。"
		if not state.learned.has("F01"):
			return "先收获初春萝卜，再到主书学会木铲耕作。"
		return "开垦需要 %d 金币。" % clear_cost(state) if state.coins < clear_cost(state) else ""
	if not plot.unlocked:
		return "这块地还没有开垦。"
	if kind == "plant":
		var crop: String = job.get("crop", "")
		if not CROPS.has(crop):
			return "没有这种种子。"
		if not plot.crop.is_empty():
			return "田里已经有作物了。"
		if crop == "welcome" and state.tutorial_started:
			return "初春种子已经种下过了。"
		if int(state.inventory.get("seed_" + crop, 0)) < 1:
			return "种子不够，可以到屋旁买一些。"
		if state.water < CROPS[crop].water:
			return "水不够了，点屋旁水桶取水。"
	elif kind == "harvest":
		if plot_status(state, id).phase != "mature":
			return "还没有成熟，不着急。"
		if stored_count(state) + int(CROPS[plot.crop].yield) > CAPACITY:
			return "仓库放不下整块田的收成；先在背包出售一些。"
	else:
		return "未知劳动。"
	return ""

static func command(previous: Dictionary, request: Dictionary) -> Dictionary:
	var state := previous.duplicate(true)
	var kind: String = request.get("type", "")
	var error := ""
	var message := ""
	if kind in ["plant", "harvest", "clear", "water"]:
		var job := request.duplicate(true)
		if kind != "water":
			var raw: Variant = request.get("plot", -1)
			if not (raw is int or raw is float) or float(raw) != int(raw):
				return {"ok": false, "message": "地块编号无效。", "state": previous.duplicate(true)}
		if state.queue.size() >= QUEUE_LIMIT and not (kind == "water" and state.work.is_empty()):
			error = "已经安排了五件事，先让她慢慢做。"
		elif kind != "water" and pending(state, int(job.get("plot", -1))):
			error = "这块田已经安排好了。"
		elif kind == "water" and (state.work.get("type") == "water" or state.queue.any(func(item): return item.type == "water")):
			error = "已经安排取水了。"
		else:
			error = _validate_job(state, job)
		if error.is_empty():
			# A refill is a recovery action: finish current labor, then refill before
			# queued planting. It must never wait behind the work needing its water.
			if kind == "water":
				state.queue.push_front(job)
			else:
				state.queue.append(job)
			_start_next(state, int(state.sim))
			message = "已安排，按顺序慢慢来。" if not state.queue.is_empty() else "她这就过去。"
	elif kind in ["buy", "sell"]:
		var crop: String = request.get("crop", "")
		var raw_amount: Variant = request.get("amount", 0)
		var amount := int(raw_amount) if raw_amount is int or raw_amount is float else 0
		if not crop in ["radish", "wheat", "potato"] or amount <= 0 or amount > 999 or float(raw_amount) != amount:
			error = "物品或数量无效。"
		elif kind == "buy":
			var cost := amount * int(CROPS[crop].price)
			if state.coins < cost:
				error = "金币不够，卖一点收成就好。"
			else:
				state.coins -= cost
				state.inventory["seed_" + crop] += amount
				message = "收好了 %d 粒%s种子。" % [amount, CROPS[crop].name]
		else:
			if state.inventory[crop] < amount:
				error = "背包里的数量不够。"
			else:
				state.inventory[crop] -= amount
				state.coins += amount * int(CROPS[crop].sell)
				message = "卖出收成，获得 %d 金币。" % (amount * int(CROPS[crop].sell))
	elif kind == "learn":
		if request.get("skill", "") != "F01":
			error = "这一页还没有发现。"
		elif state.learned.has("F01"):
			error = "已经学会了。"
		elif not state.tutorial_done:
			error = "先收获第一株初春萝卜，会找到木铲与手册。"
		elif state.wisdom < 1:
			error = "还需要 1 点智慧。"
		else:
			state.wisdom -= 1
			state.learned.append("F01")
			message = "学会木铲耕作了，喜欢哪块地就去开垦。"
	elif kind == "cancel_queue":
		state.queue.clear()
		state.queue_block = ""
		message = "未开始的安排已取消，当前劳动会做完。"
	elif kind == "settings":
		if request.has("music") and request.music is bool:
			state.settings.music = request.music
		if request.has("volume") and (request.volume is int or request.volume is float):
			state.settings.volume = clampf(float(request.volume), 0.0, 0.5)
		message = "设置已保存。"
	else:
		error = "暂不支持这个操作。"
	if not error.is_empty():
		return {"ok": false, "message": error, "state": previous.duplicate(true)}
	state.notice = message
	return {"ok": true, "message": message, "state": state}

static func _start_next(state: Dictionary, at: int) -> void:
	if not state.work.is_empty() or state.queue.is_empty():
		return
	var job: Dictionary = state.queue[0]
	var error := _validate_job(state, job)
	state.queue_block = error
	if not error.is_empty():
		return
	job = state.queue.pop_front().duplicate(true)
	if job.type == "plant":
		state.inventory["seed_" + job.crop] -= 1
		state.water -= int(CROPS[job.crop].water)
		if job.crop == "welcome":
			state.tutorial_started = true
	elif job.type == "clear":
		state.coins -= clear_cost(state)
	job.start = at
	job.finish = at + LABOR_SECONDS
	job.from_plot = state.actor_plot
	state.work = job

static func _complete(state: Dictionary) -> void:
	var job: Dictionary = state.work
	var id := int(job.get("plot", -1))
	if job.type == "plant":
		state.plots[id] = {"unlocked": true, "crop": job.crop, "planted": job.finish, "duration": CROPS[job.crop].seconds}
		state.notice = "%s种好了，小苗会自己长大。" % CROPS[job.crop].name
	elif job.type == "harvest":
		var crop: String = state.plots[id].crop
		var produce := "radish" if crop == "welcome" else crop
		# Capacity is checked again at completion; preserve the crop on failure.
		if stored_count(state) + int(CROPS[crop].yield) <= CAPACITY:
			state.inventory[produce] += int(CROPS[crop].yield)
			state.harvests += 1
			state.plots[id] = {"unlocked": true, "crop": "", "planted": 0, "duration": 0}
			state.notice = "收下 %d 份%s。" % [CROPS[crop].yield, CROPS[crop].name]
			if crop == "welcome" and not state.tutorial_done:
				state.tutorial_done = true
				state.wisdom += 1
				state.coins += 30
				state.notice = "第一份收获！木铲与手册已放进主书，获得 1 点智慧。"
		else:
			state.notice = "仓库满了，成熟的作物仍留在田里。"
	elif job.type == "clear":
		state.plots[id].unlocked = true
		state.notice = "又多了一小块可以种的田。"
	elif job.type == "water":
		state.water = WATER_CAP
		state.notice = "水桶装满了，可以慢慢用。"
	state.actor_plot = id
	state.work = {}

static func advance(previous: Dictionary, wall_now: int, monotonic_elapsed: int = -1) -> Dictionary:
	var state := previous.duplicate(true)
	var elapsed := maxi(0, wall_now - int(state.wall)) if monotonic_elapsed < 0 else maxi(0, monotonic_elapsed)
	var end := int(state.sim) + mini(elapsed, 86400)
	_start_next(state, int(state.sim))
	while not state.work.is_empty() and int(state.work.finish) <= end:
		state.sim = int(state.work.finish)
		_complete(state)
		_start_next(state, int(state.sim))
	state.sim = end
	state.wall = maxi(wall_now, int(state.wall))
	var research := int(state.research) + mini(elapsed, 604800)
	state.wisdom += research / 86400
	state.research = research % 86400
	return state
