class_name Collection
extends RefCounted
## Card ownership, upgrades, deck building and synergies.

var g


func _init(game) -> void:
	g = game


func cfg() -> Dictionary:
	return DB.cards_json.get("upgrade", {})


func owns(cid: String) -> bool:
	return g.state.cards.has(cid)


func level_of(cid: String) -> int:
	if not owns(cid):
		return 1
	return int(g.state.cards[cid].level)


func copies_of(cid: String) -> int:
	if not owns(cid):
		return 0
	return int(g.state.cards[cid].copies)


func max_level() -> int:
	# Card hall level caps card levels (hall + 2).
	return mini(int(cfg().max_level), g.base.building_level("card_hall") + 2)


## Adds copies; unlocks the card when new. Returns display entries.
func add_copies(cid: String, n: int) -> Array:
	if not DB.cards.has(cid) or n <= 0:
		return []
	var entries: Array = []
	if not owns(cid):
		g.state.cards[cid] = {"level": 1, "copies": n - 1}
		entries.append({"type": "card_new", "id": cid, "amount": 1})
		if n > 1:
			entries.append({"type": "card", "id": cid, "amount": n - 1})
		g.track("card_unlocked", 1)
		if DB.cards[cid].rarity == "legendary":
			g.track("legendary_card_owned", 1)
		check_family_completion(DB.cards[cid].family)
	else:
		g.state.cards[cid].copies = copies_of(cid) + n
		entries.append({"type": "card", "id": cid, "amount": n})
	g.mark_dirty()
	EventBus.collection_changed.emit()
	return entries


func check_family_completion(fam: String) -> void:
	for c in DB.card_list:
		if c.family == fam and not owns(c.id):
			return
	g.missions.set_max("family_complete_" + fam, 1)


## Cost of the next upgrade: {copies, fragments_if_missing, gold, fragments_per_copy}
func upgrade_cost(cid: String) -> Dictionary:
	var c: Dictionary = DB.cards[cid]
	var lvl := level_of(cid)
	var u := cfg()
	if lvl >= int(u.max_level):
		return {}
	var div := int(u.copies_div[c.rarity])
	var copies_needed := int(ceil(float(u.copies[lvl]) / div))
	var gold := int(round(float(u.gold[lvl]) * float(u.gold_mult[c.rarity])))
	var have := copies_of(cid)
	var missing := maxi(0, copies_needed - have)
	var fpc := int(u.fragments_per_copy[c.rarity])
	return {"copies": copies_needed, "missing": missing, "fragments": missing * fpc, "gold": gold, "fragments_per_copy": fpc}


func can_upgrade(cid: String) -> Dictionary:
	if not owns(cid):
		return {"ok": false, "reason": "ERR_NOT_OWNED"}
	var cost := upgrade_cost(cid)
	if cost.is_empty():
		return {"ok": false, "reason": "ERR_MAX_LEVEL"}
	if level_of(cid) >= max_level():
		return {"ok": false, "reason": "ERR_CARD_HALL"}
	if g.res("gold") < cost.gold:
		return {"ok": false, "reason": "ERR_GOLD"}
	if g.res("fragments") < cost.fragments:
		return {"ok": false, "reason": "ERR_FRAGMENTS"}
	return {"ok": true, "reason": ""}


func upgrade(cid: String) -> bool:
	var chk := can_upgrade(cid)
	if not chk.ok:
		return false
	var cost := upgrade_cost(cid)
	var spend := {"gold": cost.gold}
	if cost.fragments > 0:
		spend["fragments"] = cost.fragments
	if not g.spend(spend):
		return false
	var used_copies := mini(copies_of(cid), int(cost.copies))
	g.state.cards[cid].copies = copies_of(cid) - used_copies
	g.state.cards[cid].level = level_of(cid) + 1
	g.track("card_upgraded", 1)
	g.save_now()
	EventBus.collection_changed.emit()
	return true


## Level-scaled stats for a card (before battle modifiers).
func stats_at(cid: String, lvl: int) -> Dictionary:
	var d: Dictionary = DB.unit_def(cid)
	var s: Dictionary = d.get("stats", {}).duplicate()
	var mult := 1.0 + float(cfg().get("stat_per_level", 0.1)) * (lvl - 1)
	s.hp = int(round(float(s.hp) * mult))
	s.dmg = int(round(float(s.dmg) * mult))
	return s


# ------------------------------------------------------------------ deck
func deck() -> Array:
	return g.state.deck


func set_deck(cards: Array) -> bool:
	var size := int(DB.battle_cfg().get("deck_size", 8))
	if cards.size() != size:
		return false
	var seen := {}
	for c in cards:
		if not owns(c) or seen.has(c):
			return false
		seen[c] = true
	g.state.deck = cards.duplicate()
	g.mark_dirty()
	EventBus.collection_changed.emit()
	return true


func toggle_in_deck(cid: String) -> String:
	## Returns "" on success or an error key.
	var d: Array = g.state.deck
	var size := int(DB.battle_cfg().get("deck_size", 8))
	if cid in d:
		if d.size() <= 1:
			return "ERR_DECK_MIN"
		d.erase(cid)
	else:
		if not owns(cid):
			return "ERR_NOT_OWNED"
		if d.size() >= size:
			return "ERR_DECK_FULL"
		d.append(cid)
	g.mark_dirty()
	EventBus.collection_changed.emit()
	return ""


func swap_in_deck(out_cid: String, in_cid: String) -> bool:
	var d: Array = g.state.deck
	var idx := d.find(out_cid)
	if idx < 0 or in_cid in d or not owns(in_cid):
		return false
	d[idx] = in_cid
	g.mark_dirty()
	EventBus.collection_changed.emit()
	return true


func deck_complete() -> bool:
	return g.state.deck.size() == int(DB.battle_cfg().get("deck_size", 8))


static func family_counts(card_ids: Array) -> Dictionary:
	var counts := {}
	for cid in card_ids:
		var d: Dictionary = DB.cards.get(cid, {})
		if d.is_empty():
			continue
		counts[d.family] = int(counts.get(d.family, 0)) + 1
	return counts


## Active synergies for a deck: Array of synergy dicts.
static func active_synergies(card_ids: Array) -> Array:
	var counts := family_counts(card_ids)
	var out: Array = []
	for fam in DB.synergies.keys():
		var s: Dictionary = DB.synergies[fam]
		if int(counts.get(fam, 0)) >= int(s.need):
			out.append(s)
	return out


func average_cost(card_ids: Array) -> float:
	if card_ids.is_empty():
		return 0.0
	var t := 0.0
	for cid in card_ids:
		t += float(DB.cards[cid].cost)
	return t / card_ids.size()
