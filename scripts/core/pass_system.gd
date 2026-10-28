class_name PassSystem
extends RefCounted
## Season pass with a free and a premium track. The season calendar is local (device clock):
## there is no server, so the UI labels it as a local season.

var g


func _init(game) -> void:
	g = game


func p() -> Dictionary:
	return g.state.pass


func cfg() -> Dictionary:
	return DB.season


func _date_to_unix(s: String) -> float:
	return Time.get_unix_time_from_datetime_string(s + "T00:00:00")


func start_time() -> float:
	return _date_to_unix(str(cfg().get("start", "2026-01-01")))


func end_time() -> float:
	return _date_to_unix(str(cfg().get("end", "2099-01-01")))


func is_active() -> bool:
	return g.now() >= start_time() and g.now() < end_time()


func seconds_left() -> float:
	return maxf(0.0, end_time() - g.now())


func ensure_season() -> void:
	if str(p().get("season", "")) != str(cfg().get("season_id", "")):
		g.state.pass = {"season": cfg().season_id, "xp": 0, "premium": false, "claimed_free": [], "claimed_premium": []}
		g.mark_dirty()


func xp() -> int:
	return int(p().xp)


func tier() -> int:
	var t := int(floor(xp() / float(cfg().xp_per_tier)))
	return mini(t, cfg().tiers.size())


func add_xp(amount: int) -> void:
	ensure_season()
	if not is_active() or amount <= 0:
		return
	var max_xp: int = int(cfg().xp_per_tier) * cfg().tiers.size()
	p().xp = mini(max_xp, xp() + amount)
	g.mark_dirty()
	EventBus.pass_changed.emit()


func is_claimed(t: int, track: String) -> bool:
	return t in p()["claimed_" + track]


func can_claim(t: int, track: String) -> String:
	if t < 1 or t > cfg().tiers.size():
		return "?"
	if t > tier():
		return "ERR_TIER_LOCKED"
	if track == "premium" and not p().premium:
		return "ERR_PREMIUM_REQUIRED"
	if is_claimed(t, track):
		return "ERR_ALREADY_CLAIMED"
	return ""


func claim(t: int, track: String) -> Array:
	if can_claim(t, track) != "":
		return []
	if not g.claim_once("pass_%s_%s_%d" % [cfg().season_id, track, t]):
		return []
	p()["claimed_" + track].append(t)
	var reward: Dictionary = cfg().tiers[t - 1][track]
	var entries: Array = g.grant(reward, "pass")
	g.save_now()
	EventBus.pass_changed.emit()
	return entries


func claim_all() -> Array:
	var all: Array = []
	for t in range(1, tier() + 1):
		for track in ["free", "premium"]:
			if can_claim(t, track) == "":
				all.append_array(claim(t, track))
	return all


func claimable_count() -> int:
	var n := 0
	for t in range(1, tier() + 1):
		for track in ["free", "premium"]:
			if can_claim(t, track) == "":
				n += 1
	return n


func buy_premium() -> String:
	ensure_season()
	if p().premium:
		return "ERR_ALREADY_OWNED"
	if not is_active():
		return "ERR_SEASON_ENDED"
	if not g.spend(cfg().premium_price, "pass"):
		return "ERR_RESOURCES"
	p().premium = true
	g.save_now()
	EventBus.pass_changed.emit()
	return ""
