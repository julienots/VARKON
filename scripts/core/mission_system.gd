class_name MissionSystem
extends RefCounted
## Daily / weekly missions (rotated by local date) and permanent achievements.

var g


func _init(game) -> void:
	g = game


func m() -> Dictionary:
	return g.state.missions


func _pick(pool: Array, n: int, seed_key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("varkon-missions-" + seed_key)
	var p := pool.duplicate()
	var out: Array = []
	for i in mini(n, p.size()):
		var idx := rng.randi() % p.size()
		out.append({"id": p[idx].id, "progress": 0, "claimed": false})
		p.remove_at(idx)
	return out


func refresh_rotations() -> void:
	var dk: String = g.day_key()
	if str(m().get("daily_key", "")) != dk:
		m().daily_key = dk
		m().daily = _pick(DB.missions_json.daily, int(DB.missions_json.get("daily_count", 3)), dk)
		g.mark_dirty()
	var wk: String = g.week_key()
	if str(m().get("weekly_key", "")) != wk:
		m().weekly_key = wk
		m().weekly = _pick(DB.missions_json.weekly, int(DB.missions_json.get("weekly_count", 3)), wk)
		g.mark_dirty()


func def_of(kind: String, id: String) -> Dictionary:
	for d in DB.missions_json[kind]:
		if d.id == id:
			return d
	return {}


func on_stat(stat: String, amount: int) -> void:
	if not m().has("daily"):
		return
	var changed := false
	for kind in ["daily", "weekly"]:
		for e in m()[kind]:
			var d := def_of(kind, e.id)
			if d.get("stat", "") == stat and not e.claimed:
				e.progress = mini(int(d.target), int(e.progress) + amount)
				changed = true
	if changed:
		EventBus.missions_changed.emit()


## For "max" style stats (best streak, fortress level...): keeps the maximum.
func set_max(stat: String, value: int) -> void:
	if value > g.stat(stat):
		g.state.stats[stat] = value
		g.mark_dirty()
		EventBus.missions_changed.emit()


func claim(kind: String, id: String) -> Array:
	for e in m()[kind]:
		if e.id == id and not e.claimed:
			var d := def_of(kind, id)
			if int(e.progress) < int(d.target):
				return []
			var key := "%s_%s_%s" % [kind, m()[kind + "_key"], id]
			if not g.claim_once(key):
				return []
			e.claimed = true
			var reward: Dictionary = d.reward.duplicate()
			reward["pass_xp"] = int(DB.season.xp_sources.get(kind + "_mission", 0))
			var entries: Array = g.grant(reward, "mission")
			g.save_now()
			EventBus.missions_changed.emit()
			return entries
	return []


# ------------------------------------------------------------------ achievements
func achievement_progress(a: Dictionary) -> int:
	return mini(int(a.target), g.stat(str(a.stat)))


func achievement_claimed(id: String) -> bool:
	return bool(g.state.achievements.get(id, {}).get("claimed", false))


func claim_achievement(id: String) -> Array:
	for a in DB.missions_json.achievements:
		if a.id == id:
			if achievement_claimed(id) or achievement_progress(a) < int(a.target):
				return []
			if not g.claim_once("ach_" + id):
				return []
			g.state.achievements[id] = {"claimed": true, "t": int(g.now())}
			var entries: Array = g.grant(a.reward, "achievement")
			g.save_now()
			EventBus.missions_changed.emit()
			return entries
	return []


func claimable_count() -> int:
	var n := 0
	for kind in ["daily", "weekly"]:
		for e in m().get(kind, []):
			if not e.claimed and int(e.progress) >= int(def_of(kind, e.id).get("target", 1)):
				n += 1
	for a in DB.missions_json.achievements:
		if not achievement_claimed(a.id) and achievement_progress(a) >= int(a.target):
			n += 1
	return n
