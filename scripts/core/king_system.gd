class_name KingSystem
extends RefCounted
## The player's unique King Gobelin: appearance, equipment, abilities, mutations, loadouts, stats.

const APPEARANCE_KEYS := ["face_shape", "ears", "nose", "jaw", "teeth", "tusks", "eyes", "eye_color", "skin", "scars",
	"paint", "paint_color", "horns", "crest", "hair", "hair_color", "height", "bulk", "muscle", "expression", "voice"]
const STAT_KEYS := ["hp", "dmg", "armor", "speed_pct", "atk_speed_pct", "range", "energy", "resist", "cdr_pct", "ability_power_pct", "dmg_pct"]

var g


func _init(game) -> void:
	g = game


func k() -> Dictionary:
	return g.state.king


func init_default() -> void:
	var app := {}
	for key in APPEARANCE_KEYS:
		app[key] = 0
	app.height = 2
	app.bulk = 2
	app.skin = 0
	app.tusks = 1
	app.hair = 1
	g.state.king = {
		"appearance": app,
		"equipment": {},
		"abilities": {"active": "tyrant_strike", "defensive": "iron_skin", "ultimate": "mutant_fury", "passive": "royal_presence"},
		"cosmetic_sel": {"emote_1": "emote_laugh", "emote_2": "emote_smash", "victory": "victory_jump", "entry": "", "defeat": ""},
		"mutations_owned": [],
		"mutations_active": [],
		"loadouts": [],
		"active_loadout": -1,
	}
	# Equip starter items
	for uid in g.state.items.keys():
		var d: Dictionary = DB.items[g.state.items[uid].id]
		if not k().equipment.has(d.slot) and slot_unlocked(d.slot):
			k().equipment[d.slot] = uid


func validate() -> void:
	var defaults_needed: bool = not g.state.has("king") or typeof(g.state.king) != TYPE_DICTIONARY or not k().has("appearance")
	if defaults_needed:
		init_default()
		return
	for key in APPEARANCE_KEYS:
		var opts: Array = DB.king.appearance.get(key, [0])
		k().appearance[key] = clampi(int(k().appearance.get(key, 0)), 0, opts.size() - 1)
	for slot in k().equipment.keys():
		var uid: String = k().equipment[slot]
		if not g.state.items.has(uid) or DB.items[g.state.items[uid].id].slot != slot:
			k().equipment.erase(slot)
	for key in ["mutations_owned", "mutations_active", "loadouts"]:
		if not k().has(key):
			k()[key] = []
	if not k().has("cosmetic_sel"):
		k().cosmetic_sel = {"emote_1": "emote_laugh", "emote_2": "emote_smash", "victory": "victory_jump", "entry": "", "defeat": ""}
	for slot in ["active", "defensive", "ultimate", "passive"]:
		var aid: String = str(k().abilities.get(slot, ""))
		if not DB.abilities.has(aid):
			k().abilities[slot] = {"active": "tyrant_strike", "defensive": "iron_skin", "ultimate": "mutant_fury", "passive": "royal_presence"}[slot]


# ------------------------------------------------------------------ appearance
func appearance_options(key: String) -> Array:
	return DB.king.appearance.get(key, [])


func appearance_locked(key: String, index: int) -> String:
	## Returns "" if allowed, else a reason.
	if key == "paint" and DB.king.get("item_paints", {}).has(str(index)):
		if not DB.king.item_paints[str(index)] in unlocked_paints():
			return g.tr("REQ_MASK_ITEM")
	var locks: Dictionary = DB.king.get("appearance_locks", {})
	if locks.has(key):
		var l: Dictionary = locks[key]
		if index >= int(l.index) and g.level() < int(l.player_level):
			return g.tr("COND_PLAYER_LEVEL") % int(l.player_level)
	return ""


func set_appearance(key: String, index: int) -> bool:
	var opts := appearance_options(key)
	if index < 0 or index >= opts.size():
		return false
	if appearance_locked(key, index) != "":
		return false
	k().appearance[key] = index
	g.mark_dirty()
	EventBus.king_changed.emit()
	return true


func unlocked_paints() -> Array:
	## Extra paint variants granted by items like the Masque des Mille Visages.
	var out: Array = []
	for uid in g.state.items.keys():
		for e in DB.items[g.state.items[uid].id].get("effects", []):
			if e.type == "unlock_paints":
				out.append_array(e.paints)
	return out


# ------------------------------------------------------------------ equipment
func slot_unlocked(slot: String) -> bool:
	var s: Dictionary = DB.slots_by_id.get(slot, {})
	if s.is_empty():
		return false
	return g.check_condition(s.get("unlock"))


func equipped(slot: String) -> String:
	return str(k().equipment.get(slot, ""))


func equipped_def(slot: String) -> Dictionary:
	var uid := equipped(slot)
	if uid == "" or not g.state.items.has(uid):
		return {}
	return DB.items[g.state.items[uid].id]


func is_equipped_anywhere(uid: String) -> bool:
	if uid in k().equipment.values():
		return true
	for lo in k().loadouts:
		if lo is Dictionary and uid in lo.get("equipment", {}).values():
			return true
	return false


func equip(uid: String) -> String:
	## Returns "" on success or an error key.
	if not g.state.items.has(uid):
		return "ERR_NOT_OWNED"
	var d: Dictionary = DB.items[g.state.items[uid].id]
	if not slot_unlocked(d.slot):
		return "ERR_SLOT_LOCKED"
	if equipped(d.slot) == uid:
		return ""
	k().equipment[d.slot] = uid
	if not d.get("cosmetic", false):
		g.track("king_upgraded", 1)
	g.mark_dirty()
	EventBus.king_changed.emit()
	return ""


func unequip(slot: String) -> void:
	k().equipment.erase(slot)
	g.mark_dirty()
	EventBus.king_changed.emit()


func has_mech_module(equipment: Dictionary = {}) -> bool:
	var eq: Dictionary = equipment if not equipment.is_empty() else k().equipment
	for slot in eq.keys():
		var uid: String = eq[slot]
		if not g.state.items.has(uid):
			continue
		var d: Dictionary = DB.items[g.state.items[uid].id]
		if d.category == "mech":
			return true
		for e in d.get("effects", []):
			if e.type == "mech_module":
				return true
	return false


# ------------------------------------------------------------------ abilities
func ability_available(aid: String) -> String:
	## "" if usable, else reason text.
	var a: Dictionary = DB.abilities.get(aid, {})
	if a.is_empty():
		return "?"
	if a.get("unlock") != null and not g.check_condition(a.unlock):
		return g.condition_text(a.unlock)
	if a.get("requires", "") == "mech_module" and not has_mech_module():
		return g.tr("REQ_MECH_MODULE")
	return ""


func set_ability(slot: String, aid: String) -> bool:
	var a: Dictionary = DB.abilities.get(aid, {})
	if a.is_empty() or a.slot != slot or ability_available(aid) != "":
		return false
	k().abilities[slot] = aid
	g.mark_dirty()
	EventBus.king_changed.emit()
	return true


func abilities_for_slot(slot: String) -> Array:
	var out: Array = []
	for a in DB.king.abilities:
		if a.slot == slot:
			out.append(a)
	return out


# ------------------------------------------------------------------ mutations
func mutation_slots() -> int:
	var n := int(DB.lab.get("mutation_slots", 2))
	n += g.lab.research_bonus("mutation_slots")
	n += g.base.zone_bonus("mutation_slots")
	return n


func unlock_mutation(mid: String) -> String:
	var m: Dictionary = DB.mutations.get(mid, {})
	if m.is_empty():
		return "?"
	if mid in k().mutations_owned:
		return "ERR_ALREADY_OWNED"
	if not g.lab.is_unlocked():
		return "ERR_LAB_LOCKED"
	if not g.spend(m.cost, "mutation"):
		return "ERR_RESOURCES"
	k().mutations_owned.append(mid)
	g.track("mutation_unlocked", 1)
	g.track("king_upgraded", 1)
	if k().mutations_active.size() < mutation_slots():
		k().mutations_active.append(mid)
	g.save_now()
	EventBus.king_changed.emit()
	return ""


func toggle_mutation(mid: String) -> String:
	if not mid in k().mutations_owned:
		return "ERR_NOT_OWNED"
	if mid in k().mutations_active:
		k().mutations_active.erase(mid)
	else:
		if k().mutations_active.size() >= mutation_slots():
			return "ERR_MUTATION_SLOTS"
		k().mutations_active.append(mid)
	g.mark_dirty()
	EventBus.king_changed.emit()
	return ""


# ------------------------------------------------------------------ loadouts
func loadout_slots() -> int:
	var n := 1
	for row in DB.player_cfg().get("loadout_slots", []):
		if g.level() >= int(row.level):
			n = int(row.slots)
	n += g.lab.research_bonus("loadout_slots")
	n += g.base.zone_bonus("loadout_slots")
	return n


func save_loadout(index: int, lname: String) -> bool:
	if index < 0 or index >= loadout_slots():
		return false
	while k().loadouts.size() <= index:
		k().loadouts.append(null)
	k().loadouts[index] = {
		"name": lname,
		"equipment": k().equipment.duplicate(),
		"abilities": k().abilities.duplicate(),
		"appearance": k().appearance.duplicate(),
		"mutations_active": k().mutations_active.duplicate(),
		"cosmetic_sel": k().cosmetic_sel.duplicate(),
	}
	k().active_loadout = index
	g.save_now()
	EventBus.king_changed.emit()
	return true


func apply_loadout(index: int) -> Array:
	## Applies a saved loadout; returns list of skipped (no longer owned/compatible) entries.
	var skipped: Array = []
	if index < 0 or index >= k().loadouts.size() or k().loadouts[index] == null:
		return ["?"]
	var lo: Dictionary = k().loadouts[index]
	var eq := {}
	for slot in lo.equipment.keys():
		var uid: String = lo.equipment[slot]
		if g.state.items.has(uid) and slot_unlocked(slot) and DB.items[g.state.items[uid].id].slot == slot:
			eq[slot] = uid
		else:
			skipped.append(slot)
	k().equipment = eq
	for slot in lo.abilities.keys():
		if ability_available(lo.abilities[slot]) == "":
			k().abilities[slot] = lo.abilities[slot]
		else:
			skipped.append(lo.abilities[slot])
	k().appearance = lo.appearance.duplicate()
	var muts: Array = []
	for m in lo.get("mutations_active", []):
		if m in k().mutations_owned and muts.size() < mutation_slots():
			muts.append(m)
	k().mutations_active = muts
	if lo.has("cosmetic_sel"):
		k().cosmetic_sel = lo.cosmetic_sel.duplicate()
	k().active_loadout = index
	g.mark_dirty()
	EventBus.king_changed.emit()
	return skipped


func delete_loadout(index: int) -> void:
	if index >= 0 and index < k().loadouts.size():
		k().loadouts[index] = null
		g.mark_dirty()
		EventBus.king_changed.emit()


# ------------------------------------------------------------------ stats
func relic_mult(uid: String) -> float:
	var lvl := int(g.state.lab.relic_levels.get(uid, 0))
	return 1.0 + lvl * float(DB.lab.get("relic_upgrade", {}).get("bonus_pct_per_level", 10)) / 100.0


## Computes final stats for an equipment set (defaults to current). Values are capped.
func compute_stats(equipment: Dictionary = {}, mutations: Array = [], use_current := true) -> Dictionary:
	var eq: Dictionary = equipment if (not use_current or not equipment.is_empty()) else k().equipment
	var muts: Array = mutations if (not use_current or not mutations.is_empty()) else k().mutations_active
	var base: Dictionary = DB.king.base
	var per: Dictionary = DB.king.per_level
	var caps: Dictionary = DB.king.caps
	var lvl_mult_hp: float = 1.0 + float(per.hp) * (g.level() - 1)
	var lvl_mult_dmg: float = 1.0 + float(per.dmg) * (g.level() - 1)
	var sum := {}
	for key in STAT_KEYS:
		sum[key] = 0.0
	var effects: Array = []
	var weapon_cat := "none"
	for slot in eq.keys():
		var uid: String = eq[slot]
		if not g.state.items.has(uid):
			continue
		var d: Dictionary = DB.items[g.state.items[uid].id]
		var ilvl := int(g.state.items[uid].get("level", 1))
		var imult := 1.0 + 0.05 * (ilvl - 1)
		for s in d.get("stats", {}).keys():
			if sum.has(s):
				sum[s] += float(d.stats[s]) * (imult if float(d.stats[s]) > 0 else 1.0)
		var rm := relic_mult(uid)
		for e in d.get("effects", []):
			var e2: Dictionary = e.duplicate()
			e2["source"] = d.id
			if rm > 1.0:
				for f in ["pct", "dmg"]:
					if e2.has(f):
						e2[f] = float(e2[f]) * rm
				if e2.has("mult"):
					e2["mult"] = 1.0 + (float(e2.mult) - 1.0) * rm
			effects.append(e2)
		if slot == "right_arm":
			weapon_cat = d.category
	for mid in muts:
		var m: Dictionary = DB.mutations.get(mid, {})
		for s in m.get("stats", {}).keys():
			if sum.has(s):
				sum[s] += float(m.stats[s])
		for e in m.get("effects", []):
			effects.append(e)
	var all_pct := 0.0
	for e in effects:
		if e.type == "all_stats":
			all_pct += float(e.pct)
	var style: Dictionary = DB.king.weapon_styles.get(weapon_cat, DB.king.weapon_styles.none)
	var out := {}
	var all_m := 1.0 + all_pct / 100.0
	out.hp = int(round((float(base.hp) * lvl_mult_hp + sum.hp) * all_m))
	out.dmg = int(round((float(base.dmg) * lvl_mult_dmg + sum.dmg) * (1.0 + sum.dmg_pct / 100.0) * all_m))
	out.armor = minf(float(caps.armor), (float(base.armor) + sum.armor) * all_m)
	var speed_pct := minf(float(caps.speed_pct), sum.speed_pct + all_pct)
	out.speed = float(base.speed) * (1.0 + speed_pct / 100.0)
	var atk_pct := minf(float(caps.atk_speed_pct), sum.atk_speed_pct + all_pct)
	if weapon_cat == "mech" and k().abilities.get("passive", "") == "mech_instinct":
		atk_pct = minf(float(caps.atk_speed_pct), atk_pct + float(DB.abilities.mech_instinct.pct))
	out.hit = float(style.hit) / (1.0 + atk_pct / 100.0)
	out.range = float(base.range) * float(style.range) + minf(float(caps.range), sum.range)
	out.proj = float(style.get("proj", 0))
	out.splash = float(style.get("splash", 0))
	out.energy = minf(float(caps.energy), sum.energy)
	out.resist = clampf(sum.resist, -50.0, float(caps.resist))
	out.cdr_pct = minf(float(caps.cdr_pct), sum.cdr_pct)
	out.ability_power_pct = minf(float(caps.ability_power_pct), sum.ability_power_pct)
	out.speed_pct = speed_pct
	out.atk_speed_pct = atk_pct
	out.effects = effects
	out.weapon = weapon_cat
	out.mech_module = has_mech_module(eq)
	out.power = int(out.hp / 10.0 + out.dmg * 2.0 / out.hit + out.armor * 5)
	return out


## Stats if `uid` were equipped instead of the current item in its slot (for comparison UI).
func preview_with(uid: String) -> Dictionary:
	var eq: Dictionary = k().equipment.duplicate()
	var d: Dictionary = DB.items[g.state.items[uid].id]
	eq[d.slot] = uid
	return compute_stats(eq, k().mutations_active.duplicate(), false)


func current_stats() -> Dictionary:
	return compute_stats()


func appearance_with_mutations() -> Dictionary:
	var a: Dictionary = k().appearance.duplicate()
	var vis: Array = []
	for mid in k().mutations_active:
		vis.append(DB.mutations[mid].visual)
	a["mutation_visuals"] = vis
	return a


## Item visuals currently equipped: slot -> visual dict (with item id)
func equipped_visuals(equipment: Dictionary = {}) -> Dictionary:
	var eq: Dictionary = equipment if not equipment.is_empty() else k().equipment
	var out := {}
	for slot in eq.keys():
		var uid: String = eq[slot]
		if g.state.items.has(uid):
			var d: Dictionary = DB.items[g.state.items[uid].id]
			var v: Dictionary = d.visual.duplicate()
			v["item"] = d.id
			v["rarity"] = d.rarity
			out[slot] = v
	return out
