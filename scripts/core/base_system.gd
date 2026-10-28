class_name BaseSystem
extends RefCounted
## Fortress buildings: placement on a grid, timed upgrades, production, zones, lab repair.

const MAX_BUILDERS := 2
const MAX_UPGRADE_SECONDS := 4 * 3600

var g


func _init(game) -> void:
	g = game


func b() -> Dictionary:
	return g.state.base


func init_default() -> void:
	g.state.base = {"buildings": [], "zones": ["center"], "next_uid": 1}
	for s in DB.buildings_json.get("start", []):
		_add_building(str(s.id), int(s.x), int(s.y), 0, int(s.level))


func validate() -> void:
	if not b().has("buildings") or not b().has("zones"):
		init_default()
		return
	var keep: Array = []
	for bd in b().buildings:
		if DB.buildings.has(str(bd.get("id", ""))):
			bd.level = clampi(int(bd.level), 0, int(DB.buildings[bd.id].max_level))
			bd.upgrade_end = float(bd.get("upgrade_end", 0))
			keep.append(bd)
	b().buildings = keep


func _add_building(id: String, x: int, y: int, rot: int, level: int) -> Dictionary:
	var bd := {"uid": "b%d" % int(b().next_uid), "id": id, "level": level, "x": x, "y": y, "rot": rot,
		"upgrade_end": 0.0, "last_collect": g.now()}
	b().next_uid = int(b().next_uid) + 1
	b().buildings.append(bd)
	return bd


# ------------------------------------------------------------------ queries
func get_building(uid: String) -> Dictionary:
	for bd in b().buildings:
		if bd.uid == uid:
			return bd
	return {}


func buildings_of(id: String) -> Array:
	var out: Array = []
	for bd in b().buildings:
		if bd.id == id:
			out.append(bd)
	return out


## Highest level of a building type (0 if absent).
func building_level(id: String) -> int:
	var lvl := 0
	for bd in buildings_of(id):
		lvl = maxi(lvl, int(bd.level))
	return lvl


func zone_unlocked(zid: String) -> bool:
	return zid in b().zones


func zone_bonus(key: String) -> int:
	var n := 0
	for zid in b().zones:
		n += int(DB.zones.get(zid, {}).get("bonus", {}).get(key, 0))
	return n


func max_count(id: String) -> int:
	var d: Dictionary = DB.buildings[id]
	if d.get("unique", false):
		return 1
	var n := int(d.get("max_count", 1))
	if id == "gold_mine":
		n += zone_bonus("gold_mine_max")
	return n


func size_of(bd: Dictionary) -> Vector2i:
	var s: Array = DB.buildings[bd.id].size
	if int(bd.get("rot", 0)) % 2 == 1:
		return Vector2i(int(s[1]), int(s[0]))
	return Vector2i(int(s[0]), int(s[1]))


func _cell_zone(c: Vector2i) -> String:
	for zid in b().zones:
		var r: Array = DB.zones[zid].rect
		if c.x >= int(r[0]) and c.x < int(r[0]) + int(r[2]) and c.y >= int(r[1]) and c.y < int(r[1]) + int(r[3]):
			return zid
	return ""


## Validates a footprint. Returns "" if valid or an error key.
func check_placement(id: String, x: int, y: int, rot: int, ignore_uid: String = "") -> String:
	var d: Dictionary = DB.buildings[id]
	var s: Array = d.size
	var w := int(s[1]) if rot % 2 == 1 else int(s[0])
	var h := int(s[0]) if rot % 2 == 1 else int(s[1])
	var grid: Dictionary = DB.buildings_json.grid
	if x < 0 or y < 0 or x + w > int(grid.width) or y + h > int(grid.height):
		return "ERR_OUT_OF_BOUNDS"
	for cx in range(x, x + w):
		for cy in range(y, y + h):
			var z := _cell_zone(Vector2i(cx, cy))
			if z == "":
				return "ERR_ZONE_LOCKED"
			if d.zone != "center" and z != d.zone:
				return "ERR_WRONG_ZONE"
	var rect := Rect2i(x, y, w, h)
	for o in b().buildings:
		if o.uid == ignore_uid:
			continue
		var os := size_of(o)
		if rect.intersects(Rect2i(int(o.x), int(o.y), os.x, os.y)):
			return "ERR_OVERLAP"
	return ""


# ------------------------------------------------------------------ construction
func build_cost(id: String) -> Dictionary:
	return DB.buildings[id].base_cost.duplicate()


func can_build(id: String) -> String:
	var d: Dictionary = DB.buildings[id]
	if d.get("locked_ruin", false):
		return "ERR_RUIN"
	if buildings_of(id).size() >= max_count(id):
		return "ERR_MAX_COUNT"
	if building_level("fortress") < int(d.get("req", {}).get("fortress", 1)):
		return "ERR_FORTRESS_LEVEL"
	if d.zone != "center" and not zone_unlocked(d.zone):
		return "ERR_ZONE_LOCKED"
	if not g.can_afford(build_cost(id)):
		return "ERR_RESOURCES"
	return ""


func build(id: String, x: int, y: int, rot: int = 0) -> String:
	var err := can_build(id)
	if err != "":
		return err
	err = check_placement(id, x, y, rot)
	if err != "":
		return err
	if not g.spend(build_cost(id), "build"):
		return "ERR_RESOURCES"
	_add_building(id, x, y, rot, 1)
	g.track("building_built", 1)
	g.save_now()
	EventBus.base_changed.emit()
	return ""


func move(uid: String, x: int, y: int, rot: int) -> String:
	var bd := get_building(uid)
	if bd.is_empty():
		return "?"
	var err := check_placement(bd.id, x, y, rot, uid)
	if err != "":
		return err
	bd.x = x
	bd.y = y
	bd.rot = rot
	g.mark_dirty()
	EventBus.base_changed.emit()
	return ""


func upgrade_cost(bd: Dictionary) -> Dictionary:
	var d: Dictionary = DB.buildings[bd.id]
	var lvl := int(bd.level)
	var out := {}
	for k in d.base_cost.keys():
		out[k] = int(round(float(d.base_cost[k]) * pow(float(d.cost_growth), lvl)))
	return out


func upgrade_time(bd: Dictionary) -> float:
	var d: Dictionary = DB.buildings[bd.id]
	return minf(MAX_UPGRADE_SECONDS, float(d.base_time) * pow(int(bd.level) + 1, 1.6))


func active_builders() -> int:
	var n := 0
	for bd in b().buildings:
		if float(bd.upgrade_end) > 0.0:
			n += 1
	return n


func can_upgrade(bd: Dictionary) -> String:
	var d: Dictionary = DB.buildings[bd.id]
	if float(bd.upgrade_end) > 0.0:
		return "ERR_UPGRADING"
	if int(bd.level) >= int(d.max_level):
		return "ERR_MAX_LEVEL"
	if bd.id == "laboratory" and int(bd.level) == 0:
		return "ERR_RUIN"
	if bd.id == "fortress":
		if g.level() < int(bd.level) * 2:
			return "ERR_PLAYER_LEVEL"
	elif int(bd.level) + 1 > building_level("fortress"):
		return "ERR_FORTRESS_LEVEL"
	if active_builders() >= MAX_BUILDERS:
		return "ERR_BUILDERS"
	if not g.can_afford(upgrade_cost(bd)):
		return "ERR_RESOURCES"
	return ""


func start_upgrade(uid: String) -> String:
	var bd := get_building(uid)
	if bd.is_empty():
		return "?"
	var err := can_upgrade(bd)
	if err != "":
		return err
	if not g.spend(upgrade_cost(bd), "upgrade"):
		return "ERR_RESOURCES"
	_collect_one(bd)  # bank production before the level changes
	bd.upgrade_end = g.now() + upgrade_time(bd)
	g.save_now()
	EventBus.base_changed.emit()
	return ""


func remaining(bd: Dictionary) -> float:
	if float(bd.upgrade_end) <= 0.0:
		return 0.0
	return maxf(0.0, float(bd.upgrade_end) - g.now())


func speedup_cost(bd: Dictionary) -> int:
	var r := remaining(bd)
	if r <= 0.0:
		return 0
	return int(ceil(r / 120.0)) + 1


func speedup(uid: String) -> String:
	var bd := get_building(uid)
	if bd.is_empty() or float(bd.upgrade_end) <= 0.0:
		return "?"
	var c := speedup_cost(bd)
	if not g.spend({"crystals": c}, "speedup"):
		return "ERR_RESOURCES"
	bd.upgrade_end = g.now() - 1.0
	process_timers()
	return ""


## Completes finished upgrades. Call regularly (screens do it on open and every second).
func process_timers() -> Array:
	var done: Array = []
	for bd in b().buildings:
		if float(bd.upgrade_end) > 0.0 and g.now() >= float(bd.upgrade_end):
			bd.upgrade_end = 0.0
			bd.level = int(bd.level) + 1
			bd.last_collect = g.now()
			done.append(bd)
			g.track("building_upgraded", 1)
			if bd.id == "fortress":
				g.missions.set_max("fortress_level", int(bd.level))
	if not done.is_empty():
		g.save_now()
		EventBus.base_changed.emit()
	return done


# ------------------------------------------------------------------ production
func production_of(bd: Dictionary) -> Dictionary:
	return DB.buildings[bd.id].get("production", {})


func capacity(bd: Dictionary) -> int:
	var p := production_of(bd)
	if p.is_empty():
		return 0
	if p.has("cap_base"):
		var per := int(DB.buildings.treasury.get("effect", {}).get("mine_cap_per_level", 300))
		return int(p.cap_base) + per * building_level("treasury")
	return int(p.get("cap_per_level", 0)) * int(bd.level)


func rate_per_hour(bd: Dictionary) -> float:
	var p := production_of(bd)
	if p.is_empty() or int(bd.level) <= 0:
		return 0.0
	return float(p.per_hour) * int(bd.level)


func pending(bd: Dictionary) -> int:
	var elapsed: float = g.now() - float(bd.get("last_collect", g.now()))
	if elapsed <= 0.0:
		return 0  # clock moved backwards: produce nothing
	return mini(capacity(bd), int(floor(rate_per_hour(bd) * elapsed / 3600.0)))


func _collect_one(bd: Dictionary) -> int:
	var p := production_of(bd)
	if p.is_empty():
		return 0
	var n := pending(bd)
	if n > 0:
		g.add_resource(str(p.resource), n)
	bd.last_collect = g.now()
	return n


func collect(uid: String) -> int:
	var bd := get_building(uid)
	if bd.is_empty():
		return 0
	var n := _collect_one(bd)
	if n > 0:
		g.track("resources_collected", 1)
		g.save_now()
		EventBus.base_changed.emit()
	return n


func collect_all() -> Dictionary:
	var totals := {}
	for bd in b().buildings:
		var p := production_of(bd)
		if p.is_empty():
			continue
		var n := _collect_one(bd)
		if n > 0:
			totals[p.resource] = int(totals.get(p.resource, 0)) + n
	if not totals.is_empty():
		g.track("resources_collected", 1)
		g.save_now()
		EventBus.base_changed.emit()
	return totals


# ------------------------------------------------------------------ zones
func zone_status(zid: String) -> String:
	if zone_unlocked(zid):
		return "unlocked"
	var z: Dictionary = DB.zones[zid]
	var req: Dictionary = z.get("req", {})
	if building_level("fortress") < int(req.get("fortress", 1)):
		return "ERR_FORTRESS_LEVEL"
	if req.has("building") and building_level(str(req.building)) <= 0:
		return "ERR_REQ_BUILDING"
	if not g.can_afford(z.cost):
		return "ERR_RESOURCES"
	return ""


func unlock_zone(zid: String) -> String:
	var st := zone_status(zid)
	if st != "":
		return st
	if not g.spend(DB.zones[zid].cost, "zone"):
		return "ERR_RESOURCES"
	b().zones.append(zid)
	g.track("zone_unlocked", 1)
	g.save_now()
	EventBus.base_changed.emit()
	return ""


# ------------------------------------------------------------------ battle effects
func battle_bonuses() -> Dictionary:
	var out := {}
	out.card_stat_pct = float(DB.buildings.barracks.effect.card_stat_pct) * building_level("barracks")
	out.tower_pct = float(DB.buildings.watchtower.effect.tower_pct) * maxi(0, building_level("watchtower") - 1)
	var walls := buildings_of("wall")
	var wall_lvl := 0.0
	for w in walls:
		wall_lvl += float(w.level)
	out.wall_segments = int(ceil(walls.size() / 2.0))
	var we: Dictionary = DB.buildings.wall.effect
	out.wall_hp = 0 if walls.is_empty() else int(float(we.wall_hp) * (1.0 + float(we.wall_hp_pct) / 100.0 * (wall_lvl / walls.size() - 1.0)))
	var traps := buildings_of("trap")
	out.traps = traps.size()
	var te: Dictionary = DB.buildings.trap.effect
	out.trap_dmg = int(float(te.trap_dmg) * (1.0 + float(te.trap_dmg_pct) / 100.0 * (building_level("trap") - 1)))
	out.raid_reward_pct = float(DB.buildings.raid_portal.effect.raid_reward_pct) * building_level("raid_portal")
	return out


func raids_unlocked() -> bool:
	return building_level("raid_portal") > 0
