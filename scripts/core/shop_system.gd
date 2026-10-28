class_name ShopSystem
extends RefCounted
## Shop with virtual currencies. Real-money products are NOT configured in this build:
## they are displayed as unavailable and can never be "bought".

var g


func _init(game) -> void:
	g = game


func cfg() -> Dictionary:
	return DB.economy.get("shop", {})


func purchased(offer_id: String) -> int:
	return int(g.state.shop.purchased.get(offer_id, 0))


## Deterministic daily selection based on the local date.
func daily_offers() -> Array:
	var day: String = g.day_key()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("varkon-shop-" + day)
	var pool: Array = cfg().get("daily_pool", []).duplicate(true)
	var out: Array = []
	var n := mini(int(cfg().get("daily_count", 6)), pool.size())
	for i in n:
		var idx := rng.randi() % pool.size()
		var o: Dictionary = pool[idx]
		pool.remove_at(idx)
		var offer := {"id": "daily_%s_%d" % [day, i], "kind": o.kind, "price": o.price, "limit": 1, "daily": true}
		match str(o.kind):
			"card_copies":
				var cands: Array = []
				for cid in g.state.cards.keys():
					if DB.cards[cid].rarity == o.rarity:
						cands.append(cid)
				if cands.is_empty():
					for c in DB.card_list:
						if c.rarity == o.rarity and int(c.unlock_level) <= g.level() + 1:
							cands.append(c.id)
				if cands.is_empty():
					continue
				cands.sort()
				offer.ref = cands[rng.randi() % cands.size()]
				offer.amount = int(o.amount)
			"resource":
				offer.ref = o.id
				offer.amount = int(o.amount)
			"chest":
				offer.ref = o.id
			"item_random":
				var items: Array = []
				for it in DB.item_list:
					if it.rarity == o.rarity and ("chest" in it.sources or "shop" in it.sources):
						items.append(it.id)
				if items.is_empty():
					continue
				items.sort()
				offer.kind = "item"
				offer.ref = items[rng.randi() % items.size()]
		out.append(offer)
	return out


func find_offer(offer_id: String) -> Dictionary:
	if DB.shop_offers.has(offer_id):
		return DB.shop_offers[offer_id]
	for o in daily_offers():
		if o.id == offer_id:
			return o
	return {}


func is_real_money(offer: Dictionary) -> bool:
	return offer.get("kind", "") == "iap"


func availability(offer: Dictionary) -> String:
	## "" when purchasable, else an error key.
	if is_real_money(offer):
		return "ERR_IAP_UNAVAILABLE"
	if offer.has("limit") and purchased(offer.id) >= int(offer.limit):
		return "ERR_SOLD_OUT"
	match str(offer.kind):
		"cosmetic":
			if g.inventory.has_cosmetic(str(offer.ref)):
				return "ERR_ALREADY_OWNED"
		"item":
			var d: Dictionary = DB.items.get(str(offer.ref), {})
			if d.get("cosmetic", false) and g.inventory.owns_item_id(str(offer.ref)):
				return "ERR_ALREADY_OWNED"
	if not g.can_afford(offer.price):
		return "ERR_RESOURCES"
	return ""


func reward_of(offer: Dictionary) -> Dictionary:
	match str(offer.kind):
		"chest":
			return {"chest": offer.ref}
		"item":
			return {"item": offer.ref}
		"cosmetic":
			return {"cosmetic": offer.ref}
		"material":
			return {"material": offer.ref}
		"resource":
			return {str(offer.ref): int(offer.amount)}
		"card_copies":
			return {"cards": {str(offer.ref): int(offer.amount)}}
	return {}


func buy(offer_id: String) -> Array:
	## Returns granted entries, or [] on failure (nothing spent).
	var offer := find_offer(offer_id)
	if offer.is_empty() or availability(offer) != "":
		return []
	if not g.spend(offer.price, "shop"):
		return []
	g.state.shop.purchased[offer_id] = purchased(offer_id) + 1
	var entries: Array = g.grant(reward_of(offer), "shop")
	g.track("shop_purchase", 1)
	g.save_now()
	return entries


func free_daily_available() -> bool:
	return not g.state.claims.has("free_daily_" + g.day_key())


func claim_free_daily() -> Array:
	if not g.claim_once("free_daily_" + g.day_key()):
		return []
	var f: Dictionary = cfg().get("free_daily", {})
	var entries: Array = g.grant(f, "shop")
	g.save_now()
	return entries
