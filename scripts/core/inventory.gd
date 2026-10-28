class_name Inventory
extends RefCounted
## Equipment instances (uid -> {id, level}), cosmetics, materials and chests.

var g


func _init(game) -> void:
	g = game


func add_item(item_id: String, notify := true) -> String:
	if not DB.items.has(item_id):
		push_error("Unknown item " + item_id)
		return ""
	var uid := "i%d" % int(g.state.next_uid)
	g.state.next_uid = int(g.state.next_uid) + 1
	g.state.items[uid] = {"id": item_id, "level": 1, "t": int(g.now())}
	g.mark_dirty()
	if notify:
		EventBus.inventory_changed.emit()
		if DB.items[item_id].get("slot", "") == "special" or DB.items[item_id].get("category", "").begins_with("relic"):
			g.track("relic_obtained", 1)
	return uid


func remove_item(uid: String) -> bool:
	if not g.state.items.has(uid):
		return false
	if g.king.is_equipped_anywhere(uid):
		return false
	g.state.items.erase(uid)
	g.mark_dirty()
	EventBus.inventory_changed.emit()
	return true


func item_def(uid: String) -> Dictionary:
	if not g.state.items.has(uid):
		return {}
	return DB.items.get(str(g.state.items[uid].id), {})


func owns_item_id(item_id: String) -> bool:
	for uid in g.state.items.keys():
		if g.state.items[uid].id == item_id:
			return true
	return false


func count_item_id(item_id: String) -> int:
	var n := 0
	for uid in g.state.items.keys():
		if g.state.items[uid].id == item_id:
			n += 1
	return n


func items_for_slot(slot: String) -> Array:
	var out: Array = []
	for uid in g.state.items.keys():
		var d: Dictionary = DB.items.get(str(g.state.items[uid].id), {})
		if d.get("slot", "") == slot:
			out.append(uid)
	out.sort_custom(func(a, b): return DB.rarity_rank(item_def(a).rarity) > DB.rarity_rank(item_def(b).rarity))
	return out


func has_cosmetic(cid: String) -> bool:
	return cid in g.state.cosmetics


func material_count(mid: String) -> int:
	return int(g.state.materials.get(mid, 0))


## Unified list for the inventory screen. Each entry: {kind, id, uid?, rarity, name, count, equipped}
func all_entries() -> Array:
	var out: Array = []
	for uid in g.state.items.keys():
		var d: Dictionary = item_def(uid)
		out.append({"kind": "item", "id": d.id, "uid": uid, "rarity": d.rarity, "name": DB.txt(d), "count": 1,
			"slot": d.slot, "category": d.category, "cosmetic": d.get("cosmetic", false), "equipped": g.king.is_equipped_anywhere(uid),
			"level": int(g.state.items[uid].get("level", 1))})
	for cid in g.state.cards.keys():
		var c: Dictionary = DB.cards[cid]
		out.append({"kind": "card", "id": cid, "rarity": c.rarity, "name": DB.txt(c), "count": int(g.state.cards[cid].copies),
			"family": c.family, "level": int(g.state.cards[cid].level), "equipped": cid in g.state.deck})
	for cos in g.state.cosmetics:
		var cd: Dictionary = DB.cosmetics.get(cos, {})
		if cd.is_empty():
			continue
		out.append({"kind": "cosmetic", "id": cos, "rarity": cd.rarity, "name": DB.txt(cd), "count": 1, "category": cd.kind, "equipped": false})
	for mid in g.state.materials.keys():
		if int(g.state.materials[mid]) <= 0:
			continue
		var md: Dictionary = DB.materials.get(mid, {})
		out.append({"kind": "material", "id": mid, "rarity": md.get("rarity", "common"), "name": DB.txt(md), "count": int(g.state.materials[mid]), "equipped": false})
	for chid in g.state.chests.keys():
		if int(g.state.chests[chid]) <= 0:
			continue
		var chd: Dictionary = DB.chests.get(chid, {})
		out.append({"kind": "chest", "id": chid, "rarity": chd.get("rarity", "common"), "name": DB.txt(chd), "count": int(g.state.chests[chid]), "equipped": false})
	for r in DB.resources.keys():
		out.append({"kind": "resource", "id": r, "rarity": "common", "name": DB.resource_name(r), "count": g.res(r), "equipped": false})
	return out
