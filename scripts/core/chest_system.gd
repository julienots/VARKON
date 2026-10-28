class_name ChestSystem
extends RefCounted
## Chests: data-driven loot tables. The probabilities shown to the player are computed by
## `effective_odds()` from the exact same tables and fallback rules used by `roll()`.

var g


func _init(game) -> void:
	g = game


func count(chest_id: String) -> int:
	return int(g.state.chests.get(chest_id, 0))


func total_count() -> int:
	var n := 0
	for k in g.state.chests.keys():
		n += int(g.state.chests[k])
	return n


## Cards that can drop for the current player, grouped by rarity.
func card_pool() -> Dictionary:
	var pool := {}
	for c in DB.card_list:
		if int(c.unlock_level) <= g.level() + 1:
			if not pool.has(c.rarity):
				pool[c.rarity] = []
			pool[c.rarity].append(c.id)
	return pool


func item_pool() -> Dictionary:
	var pool := {}
	for it in DB.item_list:
		if "chest" in it.get("sources", []):
			if not pool.has(it.rarity):
				pool[it.rarity] = []
			pool[it.rarity].append(it.id)
	return pool


## When a rarity has no eligible entry, the drop falls back to the closest lower rarity.
func _resolve_rarity(r: String, pool: Dictionary) -> String:
	var idx := DB.rarity_rank(r)
	while idx >= 0:
		var rr: String = DB.RARITY_ORDER[idx]
		if pool.has(rr) and not pool[rr].is_empty():
			return rr
		idx -= 1
	idx = DB.rarity_rank(r) + 1
	while idx < DB.RARITY_ORDER.size():
		var rr2: String = DB.RARITY_ORDER[idx]
		if pool.has(rr2) and not pool[rr2].is_empty():
			return rr2
		idx += 1
	return ""


func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights.keys():
		total += float(weights[k])
	var x := rng.randf() * total
	for k in weights.keys():
		x -= float(weights[k])
		if x < 0.0:
			return k
	return weights.keys()[-1]


## Effective probability (0..1) per rarity for each roll, after fallback.
func effective_odds(chest_id: String) -> Array:
	var ch: Dictionary = DB.chests[chest_id]
	var out: Array = []
	for r in ch.rolls:
		if r.type in ["card", "item"]:
			var pool := card_pool() if r.type == "card" else item_pool()
			var total := 0.0
			for k in r.weights.keys():
				total += float(r.weights[k])
			var odds := {}
			for k in r.weights.keys():
				var rr := _resolve_rarity(k, pool)
				if rr != "":
					odds[rr] = float(odds.get(rr, 0.0)) + float(r.weights[k]) / total
			out.append({"type": r.type, "count": int(r.count), "odds": odds})
		else:
			out.append({"type": r.type, "id": r.get("id", ""), "chance": float(r.chance) / 100.0, "amount": r.get("amount", [1, 1])})
	return out


## Pure roll (no state change). Returns a reward dictionary for Game.grant().
func roll(chest_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var ch: Dictionary = DB.chests[chest_id]
	var reward := {}
	reward.gold = rng.randi_range(int(ch.gold[0]), int(ch.gold[1]))
	for k in ch.get("resources", {}).keys():
		var rg: Array = ch.resources[k]
		var n := rng.randi_range(int(rg[0]), int(rg[1]))
		if n > 0:
			reward[k] = int(reward.get(k, 0)) + n
	var cards := {}
	var items: Array = []
	for r in ch.rolls:
		match str(r.type):
			"card":
				var pool := card_pool()
				for i in int(r.count):
					var rr := _resolve_rarity(_weighted(r.weights, rng), pool)
					if rr == "":
						continue
					var list: Array = pool[rr]
					var cid: String = list[rng.randi() % list.size()]
					cards[cid] = int(cards.get(cid, 0)) + 1
			"item":
				var ipool := item_pool()
				for i in int(r.count):
					var rr2 := _resolve_rarity(_weighted(r.weights, rng), ipool)
					if rr2 == "":
						continue
					var ilist: Array = ipool[rr2]
					items.append(ilist[rng.randi() % ilist.size()])
			"material":
				if rng.randf() * 100.0 < float(r.chance):
					reward.material = str(r.id)
			"resource":
				if rng.randf() * 100.0 < float(r.chance):
					var am: Array = r.amount
					reward[str(r.id)] = int(reward.get(str(r.id), 0)) + rng.randi_range(int(am[0]), int(am[1]))
	if not cards.is_empty():
		reward.cards = cards
	if not items.is_empty():
		reward.items = items
	return reward


## Opens one owned chest: consumes it, grants contents, saves. Returns granted entries.
func open(chest_id: String) -> Array:
	if count(chest_id) <= 0 or not DB.chests.has(chest_id):
		return []
	g.state.chests[chest_id] = count(chest_id) - 1
	var reward := roll(chest_id, g.rng)
	var entries: Array = g.grant(reward, "chest")
	g.track("chest_opened", 1)
	g.save_now()
	return entries
