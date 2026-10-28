class_name LabSystem
extends RefCounted
## Laboratory: unlock conditions, repair mission, crafting queue, research, recycling, relics.

const MAX_CRAFT_QUEUE := 3

var g


func _init(game) -> void:
	g = game


func l() -> Dictionary:
	return g.state.lab


# ------------------------------------------------------------------ unlock
## Each condition with its current status: [{text, ok}]
func unlock_status() -> Array:
	var out: Array = []
	for c in DB.lab.get("unlock", []):
		out.append({"text": str(c.text), "ok": g.check_condition(c), "cond": c})
	return out


func is_unlocked() -> bool:
	for s in unlock_status():
		if not s.ok:
			return false
	return true


func can_repair() -> String:
	if g.flag("lab_repaired"):
		return "ERR_ALREADY_DONE"
	for s in unlock_status():
		if s.cond.get("type", "") != "flag" and not s.ok:
			return "ERR_CONDITIONS"
	if not g.can_afford(DB.lab.repair_cost):
		return "ERR_RESOURCES"
	return ""


func repair() -> String:
	var err := can_repair()
	if err != "":
		return err
	if not g.spend(DB.lab.repair_cost, "lab_repair"):
		return "ERR_RESOURCES"
	g.set_flag("lab_repaired")
	for bd in g.base.buildings_of("laboratory"):
		bd.level = maxi(1, int(bd.level))
	g.track("lab_repaired", 1)
	g.save_now()
	EventBus.lab_changed.emit()
	EventBus.base_changed.emit()
	return ""


func lab_level() -> int:
	return g.base.building_level("laboratory") if is_unlocked() else 0


func room_available(room_id: String) -> bool:
	for r in DB.lab.rooms:
		if r.id == room_id:
			return lab_level() >= int(r.lab_level)
	return false


# ------------------------------------------------------------------ research
func research_level(rid: String) -> int:
	return int(l().research.get(rid, 0))


func research_bonus(key: String) -> int:
	var n := 0
	for rid in l().research.keys():
		var r: Dictionary = DB.research.get(rid, {})
		n += int(r.get("per_level", {}).get(key, 0)) * research_level(rid)
	return n


func research_bonus_f(key: String) -> float:
	var n := 0.0
	for rid in l().research.keys():
		var r: Dictionary = DB.research.get(rid, {})
		n += float(r.get("per_level", {}).get(key, 0)) * research_level(rid)
	return n


func research_cost(rid: String) -> Dictionary:
	var r: Dictionary = DB.research[rid]
	var lvl := research_level(rid)
	var out := {}
	for k in r.cost.keys():
		out[k] = int(round(float(r.cost[k]) * pow(1.8, lvl)))
	return out


func can_research(rid: String) -> String:
	if not room_available("research"):
		return "ERR_ROOM_LOCKED"
	if not l().research_job.is_empty():
		return "ERR_BUSY"
	var r: Dictionary = DB.research[rid]
	if research_level(rid) >= int(r.max):
		return "ERR_MAX_LEVEL"
	var hall: int = g.base.building_level("research_hall")
	if research_level(rid) + 1 > maxi(1, hall):
		return "ERR_RESEARCH_HALL"
	if not g.can_afford(research_cost(rid)):
		return "ERR_RESOURCES"
	return ""


func start_research(rid: String) -> String:
	var err := can_research(rid)
	if err != "":
		return err
	if not g.spend(research_cost(rid), "research"):
		return "ERR_RESOURCES"
	var t := float(DB.research[rid].time) * pow(1.5, research_level(rid))
	l().research_job = {"id": rid, "end": g.now() + t}
	g.save_now()
	EventBus.lab_changed.emit()
	return ""


# ------------------------------------------------------------------ crafting
func recipe_requirements_met(rc: Dictionary) -> String:
	var station: String = rc.station
	if station == "lab" and not room_available("design"):
		return "ERR_LAB_LOCKED"
	for k in rc.get("requires", {}).keys():
		var v = rc.requires[k]
		if k == "research":
			if research_level(str(v)) <= 0:
				return "ERR_RESEARCH_REQUIRED"
		elif g.base.building_level(k) < int(v):
			return "ERR_BUILDING_LEVEL"
	return ""


func craft_time(rc: Dictionary) -> float:
	var pct := research_bonus_f("craft_time_pct")
	return maxf(5.0, float(rc.time) * (1.0 + pct / 100.0))


func can_craft(rid: String) -> String:
	var rc: Dictionary = DB.recipes.get(rid, {})
	if rc.is_empty():
		return "?"
	var req := recipe_requirements_met(rc)
	if req != "":
		return req
	if l().craft_queue.size() >= MAX_CRAFT_QUEUE:
		return "ERR_QUEUE_FULL"
	if not g.can_afford(rc.cost):
		return "ERR_RESOURCES"
	return ""


## Materials are consumed when crafting starts (crafting cannot fail).
func start_craft(rid: String) -> String:
	var err := can_craft(rid)
	if err != "":
		return err
	var rc: Dictionary = DB.recipes[rid]
	if not g.spend(rc.cost, "craft"):
		return "ERR_RESOURCES"
	var job_id := "craft_%d_%d" % [int(g.now() * 1000), g.rng.randi() % 100000]
	l().craft_queue.append({"job": job_id, "recipe": rid, "end": g.now() + craft_time(rc)})
	g.save_now()
	EventBus.lab_changed.emit()
	return ""


func cancel_craft(job_id: String) -> bool:
	## Refunds the full cost of a job that has not finished.
	for j in l().craft_queue:
		if j.job == job_id and g.now() < float(j.end):
			l().craft_queue.erase(j)
			var rc: Dictionary = DB.recipes[j.recipe]
			for k in rc.cost.keys():
				if DB.resources.has(k):
					g.add_resource(k, int(rc.cost[k]))
				else:
					g.state.materials[k] = int(g.state.materials.get(k, 0)) + int(rc.cost[k])
			g.save_now()
			EventBus.lab_changed.emit()
			return true
	return false


func speedup_cost(job: Dictionary) -> int:
	return int(ceil(maxf(0.0, float(job.end) - g.now()) / 60.0)) + 1


func speedup_craft(job_id: String) -> String:
	for j in l().craft_queue:
		if j.job == job_id:
			if not g.spend({"crystals": speedup_cost(j)}, "speedup"):
				return "ERR_RESOURCES"
			j.end = g.now() - 1.0
			process_timers()
			return ""
	return "?"


## Delivers finished crafts and research exactly once. Returns delivered item ids.
func process_timers() -> Array:
	var delivered: Array = []
	var still: Array = []
	for j in l().craft_queue:
		if g.now() >= float(j.end):
			if g.claim_once(str(j.job)):
				var rc: Dictionary = DB.recipes[j.recipe]
				g.inventory.add_item(str(rc.item))
				delivered.append(str(rc.item))
				g.track("item_crafted", 1)
		else:
			still.append(j)
	l().craft_queue = still
	var job: Dictionary = l().research_job
	if not job.is_empty() and g.now() >= float(job.end):
		l().research[job.id] = research_level(str(job.id)) + 1
		l().research_job = {}
		g.track("research_completed", 1)
		EventBus.notify(g.tr("TOAST_RESEARCH_DONE") % DB.txt(DB.research[job.id]), "success")
	var research_finished: bool = not job.is_empty() and l().research_job.is_empty()
	if not delivered.is_empty() or research_finished:
		g.save_now()
		EventBus.lab_changed.emit()
		EventBus.inventory_changed.emit()
	return delivered


# ------------------------------------------------------------------ recycling
func recycle_value(uid: String) -> Dictionary:
	var d: Dictionary = g.inventory.item_def(uid)
	return DB.lab.recycle.get(d.get("rarity", "common"), {}).duplicate()


func recycle(uid: String) -> String:
	if not room_available("recycle"):
		return "ERR_ROOM_LOCKED"
	if not g.state.items.has(uid):
		return "ERR_NOT_OWNED"
	if g.king.is_equipped_anywhere(uid):
		return "ERR_EQUIPPED"
	var value := recycle_value(uid)
	if not g.inventory.remove_item(uid):
		return "ERR_EQUIPPED"
	l().relic_levels.erase(uid)
	g.grant(value, "recycle")
	g.track("item_recycled", 1)
	g.save_now()
	return ""


# ------------------------------------------------------------------ relics
func is_relic(uid: String) -> bool:
	var d: Dictionary = g.inventory.item_def(uid)
	return d.get("slot", "") == "special" or str(d.get("category", "")).begins_with("relic") or d.get("id", "") in ["b_moteur_gobelin", "l_griffe_traqueur"]


func relic_level(uid: String) -> int:
	return int(l().relic_levels.get(uid, 0))


func relic_upgrade_cost(uid: String) -> Dictionary:
	var cfg: Dictionary = DB.lab.relic_upgrade
	var out := {}
	for k in cfg.cost_per_level.keys():
		out[k] = int(cfg.cost_per_level[k]) * (relic_level(uid) + 1)
	return out


func upgrade_relic(uid: String) -> String:
	if not room_available("relics"):
		return "ERR_ROOM_LOCKED"
	if not is_relic(uid):
		return "ERR_NOT_RELIC"
	if relic_level(uid) >= int(DB.lab.relic_upgrade.max_level):
		return "ERR_MAX_LEVEL"
	if not g.spend(relic_upgrade_cost(uid), "relic"):
		return "ERR_RESOURCES"
	l().relic_levels[uid] = relic_level(uid) + 1
	g.track("king_upgraded", 1)
	g.save_now()
	EventBus.king_changed.emit()
	return ""
