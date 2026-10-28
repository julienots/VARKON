extends Node
## Owns the persistent player state and wires every gameplay system together.
## Systems live in scripts/core and receive this node as `g`.

var state: Dictionary = {}
var time_offset := 0.0          # used by tests to simulate elapsed time
var rng := RandomNumberGenerator.new()
var _dirty := false
var loaded_from := ""

var inventory: Inventory
var collection: Collection
var king: KingSystem
var base: BaseSystem
var lab: LabSystem
var chests: ChestSystem
var shop: ShopSystem
var season: PassSystem
var missions: MissionSystem
var campaign: CampaignSystem

## Parameters passed to the battle scene (set by CampaignSystem / menus).
var pending_battle: Dictionary = {}
var last_battle_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	inventory = Inventory.new(self)
	collection = Collection.new(self)
	king = KingSystem.new(self)
	base = BaseSystem.new(self)
	lab = LabSystem.new(self)
	chests = ChestSystem.new(self)
	shop = ShopSystem.new(self)
	season = PassSystem.new(self)
	missions = MissionSystem.new(self)
	campaign = CampaignSystem.new(self)
	load_or_create()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not state.is_empty():
			save_now()


func _process(_delta: float) -> void:
	if _dirty:
		save_now()


# ------------------------------------------------------------------ lifecycle
func load_or_create() -> void:
	var data = SaveSys.read()
	loaded_from = SaveSys.last_load_source
	if data == null:
		new_profile()
	else:
		state = data
		_validate_state()
	missions.refresh_rotations()
	save_now()


func new_profile() -> void:
	var p := DB.player_cfg()
	state = {
		"version": SaveSys.CURRENT_VERSION,
		"profile": {"name": "King", "level": 1, "xp": 0, "created": int(now()), "avatar": 0},
		"resources": p.get("start_resources", {}).duplicate(true),
		"cards": {},
		"deck": [],
		"items": {},
		"next_uid": 1,
		"cosmetics": [],
		"materials": {},
		"chests": {},
		"king": {},
		"base": {},
		"lab": {"research": {}, "research_job": {}, "craft_queue": [], "relic_levels": {}},
		"campaign": {"stars": {}},
		"pass": {"season": DB.season.get("season_id", "s1"), "xp": 0, "premium": false, "claimed_free": [], "claimed_premium": []},
		"missions": {},
		"achievements": {},
		"stats": {},
		"shop": {"purchased": {}, "day_key": "", "free_claimed_day": ""},
		"flags": {},
		"claims": {},
		"survival_best": 0,
	}
	for cid in p.get("start_cards", []):
		state.cards[cid] = {"level": 1, "copies": 0}
	state.deck = p.get("start_deck", []).duplicate()
	for iid in p.get("start_items", []):
		inventory.add_item(iid, false)
	for cos in p.get("start_cosmetics", []):
		state.cosmetics.append(cos)
	king.init_default()
	base.init_default()
	state.chests["chest_wood"] = 1


## Repairs a loaded state: fills missing keys, drops unknown ids, clamps numbers.
func _validate_state() -> void:
	var fresh_backup := state.duplicate(true)
	new_profile()
	var defaults := state
	state = fresh_backup
	for k in defaults.keys():
		if not state.has(k) or typeof(state[k]) != typeof(defaults[k]):
			state[k] = defaults[k]
	for r in DB.resources.keys():
		state.resources[r] = maxi(0, int(state.resources.get(r, 0)))
	for cid in state.cards.keys():
		if not DB.cards.has(cid):
			state.cards.erase(cid)
		else:
			var c: Dictionary = state.cards[cid]
			c["level"] = clampi(int(c.get("level", 1)), 1, int(DB.cards_json.upgrade.max_level))
			c["copies"] = maxi(0, int(c.get("copies", 0)))
	var valid_deck: Array = []
	for cid in state.deck:
		if state.cards.has(cid) and not cid in valid_deck:
			valid_deck.append(cid)
	state.deck = valid_deck
	for uid in state.items.keys():
		if not DB.items.has(str(state.items[uid].get("id", ""))):
			state.items.erase(uid)
	state.next_uid = maxi(int(state.next_uid), 1)
	state.profile.level = maxi(1, int(state.profile.level))
	state.profile.xp = maxi(0, int(state.profile.xp))
	king.validate()
	base.validate()


func mark_dirty() -> void:
	_dirty = true


func save_now() -> void:
	_dirty = false
	SaveSys.write(state)


func reset_profile() -> void:
	SaveSys.wipe()
	new_profile()
	missions.refresh_rotations()
	save_now()
	EventBus.profile_changed.emit()
	EventBus.resources_changed.emit()


# ------------------------------------------------------------------ time
func now() -> float:
	return Time.get_unix_time_from_system() + time_offset


func day_key() -> String:
	var d := Time.get_date_dict_from_unix_time(int(now() + Time.get_time_zone_from_system().bias * 60))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func week_key() -> String:
	var days := int(floor((now() + Time.get_time_zone_from_system().bias * 60) / 86400.0))
	return "W%d" % int(floor((days + 3) / 7.0))  # weeks start on Monday


# ------------------------------------------------------------------ resources
func res(id: String) -> int:
	return int(state.resources.get(id, 0))


func can_afford(cost: Dictionary) -> bool:
	for k in cost.keys():
		var need := int(cost[k])
		if DB.resources.has(k):
			if res(k) < need:
				return false
		elif DB.materials.has(k):
			if int(state.materials.get(k, 0)) < need:
				return false
		else:
			return false
	return true


## Atomically spends a cost; returns false (and spends nothing) if unaffordable.
func spend(cost: Dictionary, reason: String = "") -> bool:
	if not can_afford(cost):
		return false
	for k in cost.keys():
		var n := int(cost[k])
		if n < 0:
			return false
	for k in cost.keys():
		if DB.resources.has(k):
			state.resources[k] = res(k) - int(cost[k])
		else:
			state.materials[k] = int(state.materials.get(k, 0)) - int(cost[k])
	if reason != "":
		track("spent_" + reason, 1)
	EventBus.resources_changed.emit()
	mark_dirty()
	return true


func add_resource(id: String, amount: int) -> void:
	if amount <= 0:
		return
	state.resources[id] = res(id) + amount
	EventBus.resources_changed.emit()
	mark_dirty()


func missing_for(cost: Dictionary) -> Dictionary:
	var m := {}
	for k in cost.keys():
		var have: int = res(k) if DB.resources.has(k) else int(state.materials.get(k, 0))
		if have < int(cost[k]):
			m[k] = int(cost[k]) - have
	return m


## Grants a reward dictionary. Supported keys: any resource id, xp, pass_xp, chest, card,
## cards {id:n}, item, items [...], material, cosmetic. Returns display entries.
func grant(reward: Dictionary, source: String = "") -> Array:
	var entries: Array = []
	for k in reward.keys():
		var v = reward[k]
		if DB.resources.has(k):
			var amt := int(v)
			if k == "gold" and source in ["battle", "raid"]:
				amt = int(round(amt * (1.0 + battle_gold_bonus())))
			add_resource(k, amt)
			entries.append({"type": "resource", "id": k, "amount": amt})
		elif k == "xp":
			add_xp(int(v))
			entries.append({"type": "xp", "amount": int(v)})
		elif k == "pass_xp":
			season.add_xp(int(v))
			entries.append({"type": "pass_xp", "amount": int(v)})
		elif k == "chest":
			var cid := str(v)
			state.chests[cid] = int(state.chests.get(cid, 0)) + 1
			entries.append({"type": "chest", "id": cid, "amount": 1})
		elif k == "card":
			entries.append_array(collection.add_copies(str(v), 1))
		elif k == "cards":
			for cid in v.keys():
				entries.append_array(collection.add_copies(cid, int(v[cid])))
		elif k == "item":
			var uid := inventory.add_item(str(v))
			entries.append({"type": "item", "id": str(v), "uid": uid})
		elif k == "items":
			for iid in v:
				var uid2 := inventory.add_item(str(iid))
				entries.append({"type": "item", "id": str(iid), "uid": uid2})
		elif k == "material":
			state.materials[str(v)] = int(state.materials.get(str(v), 0)) + 1
			entries.append({"type": "material", "id": str(v), "amount": 1})
		elif k == "cosmetic":
			if not str(v) in state.cosmetics:
				state.cosmetics.append(str(v))
			entries.append({"type": "cosmetic", "id": str(v)})
	mark_dirty()
	EventBus.inventory_changed.emit()
	if not entries.is_empty():
		EventBus.rewards_granted.emit(entries)
	return entries


## Idempotency guard: returns true only the first time a key is claimed.
func claim_once(key: String) -> bool:
	if state.claims.has(key):
		return false
	state.claims[key] = int(now())
	mark_dirty()
	return true


func battle_gold_bonus() -> float:
	var b := 0.0
	b += 0.05 * lab.research_level("economy")
	b += 0.02 * base.building_level("trophy_hall")
	return b


# ------------------------------------------------------------------ profile
func level() -> int:
	return int(state.profile.level)


func xp_curve() -> Array:
	return DB.player_cfg().get("xp_curve", [0, 100])


func xp_for_next() -> int:
	var curve := xp_curve()
	var l := level()
	if l < curve.size():
		return int(curve[l])
	return int(curve[-1]) + (l - curve.size() + 1) * 4000


func xp_for_current() -> int:
	var curve := xp_curve()
	var l := level() - 1
	if l < curve.size():
		return int(curve[l])
	return int(curve[-1]) + (l - curve.size() + 1) * 4000


func add_xp(amount: int) -> void:
	state.profile.xp = int(state.profile.xp) + amount
	while int(state.profile.xp) >= xp_for_next():
		state.profile.level = level() + 1
		var rw: Dictionary = DB.player_cfg().get("level_rewards", {})
		for k in rw.keys():
			add_resource(k, int(rw[k]))
		EventBus.level_up.emit(level())
		EventBus.notify(tr("TOAST_LEVEL_UP") % level(), "level")
		missions.set_max("player_level", level())
	EventBus.profile_changed.emit()
	mark_dirty()


func stat(key: String) -> int:
	return int(state.stats.get(key, 0))


## Records a gameplay event: updates counters, missions, achievements.
func track(stat_key: String, amount: int = 1) -> void:
	state.stats[stat_key] = stat(stat_key) + amount
	missions.on_stat(stat_key, amount)
	EventBus.stat_tracked.emit(stat_key, amount)
	mark_dirty()


func flag(key: String) -> bool:
	return bool(state.flags.get(key, false))


func set_flag(key: String, value: bool = true) -> void:
	state.flags[key] = value
	mark_dirty()


## Generic unlock condition: null / [type, value] / {type:..., ...}
func check_condition(cond) -> bool:
	if cond == null:
		return true
	if cond is Array and cond.size() >= 2:
		match str(cond[0]):
			"player_level":
				return level() >= int(cond[1])
			"campaign":
				return campaign.is_completed(str(cond[1]))
			"fortress":
				return base.building_level("fortress") >= int(cond[1])
	if cond is Dictionary:
		match str(cond.get("type", "")):
			"building_level":
				return base.building_level(str(cond.building)) >= int(cond.level)
			"campaign":
				return campaign.is_completed(str(cond.mission))
			"flag":
				return flag(str(cond.flag))
			"player_level":
				return level() >= int(cond.level)
	return false


func condition_text(cond) -> String:
	if cond == null:
		return ""
	if cond is Array:
		match str(cond[0]):
			"player_level":
				return tr("COND_PLAYER_LEVEL") % int(cond[1])
			"campaign":
				var m: Dictionary = DB.missions.get(str(cond[1]), {})
				return tr("COND_CAMPAIGN") % [str(cond[1]).to_upper(), str(m.get("name", ""))]
			"fortress":
				return tr("COND_FORTRESS") % int(cond[1])
	if cond is Dictionary and cond.has("text"):
		return str(cond.text)
	return str(cond)
