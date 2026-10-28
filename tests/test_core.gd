extends TestCase
## Economy, save, collection, King, base, lab, chests, shop, pass, missions, campaign.


func test_data_loaded() -> void:
	check(DB.load_errors.is_empty(), "data errors: %s" % str(DB.load_errors))
	check(DB.cards.size() >= 70, "at least 70 playable cards, got %d" % DB.cards.size())
	check(DB.mission_list.size() >= 40, "at least 40 campaign missions")
	check(DB.buildings.size() >= 10, "at least 10 buildings")
	for c in DB.card_list:
		check(int(c.stats.hp) > 0 and int(c.stats.dmg) >= 0, "card stats valid " + c.id)
		for a in c.abilities:
			check(BattleSim.KNOWN_ABILITIES.has(a.type), "ability implemented: %s (%s)" % [a.type, c.id])
	for rc in DB.recipes.values():
		check(DB.items.has(rc.item), "recipe item exists " + rc.id)


func test_spend_never_negative() -> void:
	fresh()
	var g0 := Game.res("gold")
	check(not Game.spend({"gold": g0 + 1}), "cannot overspend")
	eq(Game.res("gold"), g0, "gold unchanged after failed spend")
	check(not Game.spend({"gold": 10, "crystals": 999999}), "multi-resource atomic failure")
	eq(Game.res("gold"), g0, "gold untouched by atomic failure")
	check(Game.spend({"gold": 10}), "valid spend")
	eq(Game.res("gold"), g0 - 10, "gold decreased")


func test_claim_once() -> void:
	fresh()
	check(Game.claim_once("x"), "first claim ok")
	check(not Game.claim_once("x"), "second claim refused")


func test_save_roundtrip_and_tamper() -> void:
	fresh()
	SaveSys.enabled = true
	SaveSys.save_path = "user://test_save.json"
	SaveSys.wipe()
	Game.state.resources.gold = 4242
	Game.save_now()
	Game.state.resources.gold = 1
	Game.save_now()  # creates backup with 4242
	var data = SaveSys.read()
	check(data != null, "save readable")
	eq(int(data.resources.gold), 1, "latest value restored")
	# Tamper main file: loader must fall back to the backup.
	var f := FileAccess.open(SaveSys.save_path, FileAccess.READ)
	var txt := f.get_as_text()
	f = null
	var env = JSON.parse_string(txt)
	env.body = str(env.body).replace("\"gold\":1", "\"gold\":999999")
	f = FileAccess.open(SaveSys.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f = null
	var data2 = SaveSys.read()
	eq(SaveSys.last_load_source, "backup", "tampered main rejected")
	eq(int(data2.resources.gold), 4242, "backup restored")
	SaveSys.wipe()
	SaveSys.enabled = false


func test_migration_v1() -> void:
	var old := {"version": 1, "king": {"appearance": {}}}
	var m := SaveSys.migrate(old)
	eq(int(m.version), SaveSys.CURRENT_VERSION, "migrated to current")
	check(m.has("claims") and m.king.has("loadouts"), "v2 fields added")


func test_validation_repairs_state() -> void:
	fresh()
	Game.state.resources.gold = -50
	Game.state.cards["not_a_card"] = {"level": 3, "copies": 1}
	Game.state.deck.append("not_a_card")
	Game._validate_state()
	eq(Game.res("gold"), 0, "negative clamped")
	check(not Game.state.cards.has("not_a_card"), "unknown card dropped")
	check(not "not_a_card" in Game.state.deck, "deck cleaned")


func test_card_upgrade() -> void:
	fresh()
	var cid := "pillard"
	Game.state.resources.gold = 100000
	Game.state.resources.fragments = 0
	var cost: Dictionary = Game.collection.upgrade_cost(cid)
	Game.collection.add_copies(cid, int(cost.copies))
	var hp1: int = Game.collection.stats_at(cid, 1).hp
	check(Game.collection.upgrade(cid), "upgrade succeeds")
	eq(Game.collection.level_of(cid), 2, "level 2")
	check(Game.collection.stats_at(cid, 2).hp > hp1, "stats increased")
	eq(Game.stat("card_upgraded"), 1, "tracked")
	# Missing copies paid with fragments
	var cost2: Dictionary = Game.collection.upgrade_cost(cid)
	Game.state.resources.fragments = int(cost2.fragments)
	check(cost2.missing > 0, "copies missing")
	check(Game.collection.upgrade(cid), "upgrade with fragments")
	eq(Game.res("fragments"), 0, "fragments consumed")
	# Card hall caps level
	Game.state.cards[cid].level = Game.collection.max_level()
	Game.collection.add_copies(cid, 999)
	check(not Game.collection.can_upgrade(cid).ok, "capped by card hall")


func test_deck_rules() -> void:
	fresh()
	check(Game.collection.deck_complete(), "start deck complete")
	eq(Game.collection.toggle_in_deck("venin"), "ERR_DECK_FULL", "deck full")
	check(not Game.collection.set_deck(["pillard", "pillard", "frondeur", "pyrogobelin", "givregriffes", "croquefer", "boulon", "venin"]), "duplicates refused")
	check(Game.collection.swap_in_deck("boulon", "venin"), "swap ok")
	var syn := Collection.active_synergies(["pyrogobelin", "brulecrane", "danseflammes", "venin"])
	check(syn.size() == 1 and syn[0].family == "fire", "fire synergy active")


func test_king_equipment_and_stats() -> void:
	fresh()
	var before: Dictionary = Game.king.current_stats()
	var uid := Game.inventory.add_item("w_brise_fer")
	var preview: Dictionary = Game.king.preview_with(uid)
	eq(Game.king.equip(uid), "", "equip weapon")
	var after: Dictionary = Game.king.current_stats()
	eq(after.dmg, preview.dmg, "preview matches equip")
	check(after.dmg > before.dmg, "damage increased")
	check(after.hit > before.hit, "heavy weapon slower")
	eq(after.weapon, "hammer", "weapon category")
	# Locked slot
	var sp := Game.inventory.add_item("r_coeur_fourneau")
	eq(Game.king.equip(sp), "ERR_SLOT_LOCKED", "special slot locked at start")
	# Caps
	for i in 20:
		Game.state.items["cap%d" % i] = {"id": "le_runner", "level": 1}
	var eq_all := {"legs": "cap0", "back": Game.inventory.add_item("b_wings"), "feet": Game.inventory.add_item("f_hooves")}
	var st := Game.king.compute_stats(eq_all, [], false)
	check(st.speed_pct <= float(DB.king.caps.speed_pct), "speed capped")
	# Cannot recycle/remove equipped
	check(not Game.inventory.remove_item(uid), "equipped item protected")


func test_king_loadouts() -> void:
	fresh()
	var uid := Game.inventory.add_item("w_crocs_noirs")
	Game.king.equip(uid)
	Game.king.set_appearance("skin", 3)
	check(Game.king.save_loadout(0, "Rapide"), "save loadout")
	Game.king.unequip("right_arm")
	Game.king.set_appearance("skin", 1)
	var skipped: Array = Game.king.apply_loadout(0)
	check(skipped.is_empty(), "nothing skipped")
	eq(Game.king.equipped("right_arm"), uid, "weapon restored")
	eq(int(Game.state.king.appearance.skin), 3, "appearance restored")
	check(not Game.king.save_loadout(99, "x"), "slot limit enforced")


func test_appearance_locks() -> void:
	fresh()
	check(not Game.king.set_appearance("horns", 3), "advanced horns locked at level 1")
	Game.state.profile.level = 10
	check(Game.king.set_appearance("horns", 3), "unlocked at level 10")


func test_lab_locked_then_unlocked() -> void:
	fresh()
	check(not Game.lab.is_unlocked(), "lab locked at start")
	eq(Game.lab.repair(), "ERR_CONDITIONS", "cannot repair early")
	eq(Game.king.unlock_mutation("m_arms"), "ERR_LAB_LOCKED", "mutation needs lab")
	for bd in Game.base.buildings_of("fortress"):
		bd.level = 4
	for i in range(1, 9):
		Game.state.campaign.stars["c1m%d" % i] = 1
		Game.state.campaign.stars["c2m%d" % i] = 1
	Game.state.resources.gold = 5000
	Game.state.resources.components = 500
	eq(Game.lab.repair(), "", "repair ok")
	check(Game.lab.is_unlocked(), "lab unlocked")
	eq(Game.lab.lab_level(), 1, "lab level 1")


func test_crafting_consumes_once() -> void:
	fresh()
	_unlock_lab()
	Game.state.resources.gold = 10000
	Game.state.resources.components = 1000
	var comp_before := Game.res("components")
	eq(Game.lab.start_craft("rc_w_machoire_acier"), "", "craft started")
	eq(Game.res("components"), comp_before - 120, "components consumed at start")
	var n_before := Game.inventory.count_item_id("w_machoire_acier")
	Game.time_offset += 100000
	var got: Array = Game.lab.process_timers()
	eq(got.size(), 1, "delivered once")
	Game.lab.process_timers()
	eq(Game.inventory.count_item_id("w_machoire_acier"), n_before + 1, "not duplicated")
	eq(Game.stat("item_crafted"), 1, "tracked")
	# Cancel refunds fully
	Game.time_offset = 0
	eq(Game.lab.start_craft("rc_h_gear_helm"), "", "second craft")
	if Game.state.lab.craft_queue.is_empty():
		return
	var job: String = Game.state.lab.craft_queue[0].job
	var g_before := Game.res("gold")
	check(Game.lab.cancel_craft(job), "cancel ok")
	eq(Game.res("gold"), g_before + 1500, "refund")


func _unlock_lab() -> void:
	for bd in Game.base.buildings_of("fortress"):
		bd.level = 4
	for i in range(1, 9):
		Game.state.campaign.stars["c2m%d" % i] = 1
	Game.set_flag("lab_repaired")
	for bd in Game.base.buildings_of("laboratory"):
		bd.level = 3


func test_mutations() -> void:
	fresh()
	_unlock_lab()
	Game.state.resources.mutant_essence = 1000
	eq(Game.king.unlock_mutation("m_scales"), "", "mutation unlocked")
	var st: Dictionary = Game.king.current_stats()
	check(st.armor >= float(DB.king.base.armor) + 10, "armor bonus applied")
	eq(Game.king.unlock_mutation("m_ancestral"), "ERR_RESOURCES", "needs Larme ancestrale")


func test_recycle_and_relics() -> void:
	fresh()
	_unlock_lab()
	var uid := Game.inventory.add_item("w_bone_axe")
	var comp := Game.res("components")
	eq(Game.lab.recycle(uid), "", "recycled")
	check(Game.res("components") > comp, "materials gained")
	check(not Game.state.items.has(uid), "item removed")
	var eq_uid: String = Game.king.equipped("right_arm")
	eq(Game.lab.recycle(eq_uid), "ERR_EQUIPPED", "equipped protected")
	var relic := Game.inventory.add_item("r_coeur_fourneau")
	Game.state.resources.ancestral = 100
	Game.state.resources.gold = 100000
	eq(Game.lab.upgrade_relic(relic), "", "relic upgraded")
	eq(Game.lab.relic_level(relic), 1, "relic level 1")


func test_base_placement() -> void:
	fresh()
	var fort: Dictionary = Game.base.buildings_of("fortress")[0]
	eq(Game.base.check_placement("watchtower", int(fort.x), int(fort.y), 0), "ERR_OVERLAP", "overlap refused")
	eq(Game.base.check_placement("watchtower", 0, 0, 0), "ERR_ZONE_LOCKED", "locked zone refused")
	eq(Game.base.check_placement("watchtower", 30, 30, 0), "ERR_OUT_OF_BOUNDS", "out of bounds refused")
	Game.state.resources.gold = 5000
	eq(Game.base.build("watchtower", 17, 17, 0), "ERR_OVERLAP", "card hall occupies 17,17")
	eq(Game.base.build("watchtower", 13, 17, 0), "", "valid build")
	var tw: Dictionary = Game.base.buildings_of("watchtower")[-1]
	eq(Game.base.move(tw.uid, 10, 11, 0), "", "move ok")
	eq(Game.base.move(tw.uid, int(fort.x) + 1, int(fort.y) + 1, 0), "ERR_OVERLAP", "move onto fortress refused")
	eq(int(tw.x), 10, "position unchanged after refused move")


func test_base_upgrade_timers_and_production() -> void:
	fresh()
	Game.state.resources.gold = 100000
	var fort: Dictionary = Game.base.buildings_of("fortress")[0]
	eq(Game.base.start_upgrade(fort.uid), "ERR_PLAYER_LEVEL", "fortress needs player level")
	Game.state.profile.level = 5
	eq(Game.base.start_upgrade(fort.uid), "", "upgrade started")
	eq(int(fort.level), 1, "not instant")
	Game.time_offset += 100000
	Game.base.process_timers()
	eq(int(fort.level), 2, "upgrade completed")
	var mine: Dictionary = Game.base.buildings_of("gold_mine")[0]
	mine.last_collect = Game.now() - 3600 * 1000
	var cap: int = Game.base.capacity(mine)
	eq(Game.base.pending(mine), cap, "production capped")
	var g0 := Game.res("gold")
	eq(Game.base.collect(mine.uid), cap, "collected")
	eq(Game.res("gold"), g0 + cap, "gold added")
	eq(Game.base.collect(mine.uid), 0, "nothing left")
	mine.last_collect = Game.now() + 5000
	eq(Game.base.pending(mine), 0, "clock rollback produces nothing")


func test_zones() -> void:
	fresh()
	eq(Game.base.unlock_zone("industrial"), "ERR_FORTRESS_LEVEL", "needs fortress 2")
	Game.base.buildings_of("fortress")[0].level = 2
	Game.state.resources.gold = 10000
	eq(Game.base.unlock_zone("industrial"), "", "zone unlocked")
	eq(Game.base.check_placement("workshop", 19, 9, 0), "", "industrial placement")
	eq(Game.base.check_placement("workshop", 9, 11, 0), "ERR_WRONG_ZONE", "workshop must be in industrial zone")


func test_chest_odds_match_rolls() -> void:
	fresh()
	Game.state.profile.level = 20
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var odds: Array = Game.chests.effective_odds("chest_royal")
	var expected: Dictionary = odds[0].odds
	var counts := {}
	var n := 0
	for i in 1500:
		var r: Dictionary = Game.chests.roll("chest_royal", rng)
		for cid in r.get("cards", {}).keys():
			var rar: String = DB.cards[cid].rarity
			counts[rar] = int(counts.get(rar, 0)) + int(r.cards[cid])
			n += int(r.cards[cid])
	for rar in expected.keys():
		var observed := float(counts.get(rar, 0)) / n
		check(absf(observed - float(expected[rar])) < 0.02, "rarity %s observed %.3f expected %.3f" % [rar, observed, expected[rar]])


func test_chest_open_consumes() -> void:
	fresh()
	Game.state.chests = {"chest_wood": 1}
	var e: Array = Game.chests.open("chest_wood")
	check(not e.is_empty(), "rewards granted")
	eq(Game.chests.count("chest_wood"), 0, "chest consumed")
	check(Game.chests.open("chest_wood").is_empty(), "cannot open missing chest")


func test_shop() -> void:
	fresh()
	Game.state.resources.gold = 1000
	var e: Array = Game.shop.buy("o_chest_wood")
	check(not e.is_empty(), "bought chest")
	eq(Game.res("gold"), 750, "price paid")
	check(Game.shop.buy("o_cr_small").is_empty(), "real money never simulated")
	eq(Game.shop.availability(DB.shop_offers.o_cr_small), "ERR_IAP_UNAVAILABLE", "IAP unavailable")
	Game.state.resources.crystals = 1000
	check(not Game.shop.buy("o_emote_cross").is_empty(), "cosmetic bought")
	check(Game.shop.buy("o_emote_cross").is_empty(), "limit respected")
	check(not Game.shop.claim_free_daily().is_empty(), "free daily")
	check(Game.shop.claim_free_daily().is_empty(), "free daily once per day")
	var d: Array = Game.shop.daily_offers()
	check(d.size() >= 4, "daily offers generated")
	eq(Game.shop.daily_offers()[0].id, d[0].id, "daily offers deterministic")


func test_pass() -> void:
	fresh()
	Game.time_offset = Game.season.start_time() + 86400 - Time.get_unix_time_from_system()
	Game.season.add_xp(250)
	eq(Game.season.tier(), 2, "tier 2")
	eq(Game.season.can_claim(3, "free"), "ERR_TIER_LOCKED", "tier 3 locked")
	check(not Game.season.claim(1, "free").is_empty(), "free claimed")
	check(Game.season.claim(1, "free").is_empty(), "no double claim")
	eq(Game.season.can_claim(1, "premium"), "ERR_PREMIUM_REQUIRED", "premium required")
	Game.state.resources.crystals = 1000
	eq(Game.season.buy_premium(), "", "premium bought with crystals")
	var e: Array = Game.season.claim(1, "premium")
	check(not e.is_empty(), "premium claimed")
	# Pass weapon is a real equippable item
	check(Game.inventory.owns_item_id("w_epee_parade"), "pass weapon in inventory")
	Game.time_offset = 0


func test_missions_and_achievements() -> void:
	fresh()
	Game.state.missions.daily = [{"id": "d_win3", "progress": 0, "claimed": false}]
	check(Game.missions.claim("daily", "d_win3").is_empty(), "cannot claim unfinished")
	for i in 3:
		Game.track("battle_won", 1)
	check(not Game.missions.claim("daily", "d_win3").is_empty(), "claim finished")
	check(Game.missions.claim("daily", "d_win3").is_empty(), "no double claim")
	check(not Game.missions.claim_achievement("a_first_win").is_empty(), "achievement")
	check(Game.missions.claim_achievement("a_first_win").is_empty(), "achievement once")


func test_campaign_report_once() -> void:
	fresh()
	var cfg: Dictionary = Game.campaign.mission_config("c1m1")
	cfg.battle_id = "t1"
	var g0 := Game.res("gold")
	var r: Dictionary = Game.campaign.report(cfg, {"won": true, "stars": 3})
	check(Game.res("gold") > g0, "gold rewarded")
	eq(Game.campaign.stars("c1m1"), 3, "stars saved")
	check(Game.campaign.is_available("c1m2"), "next mission unlocked")
	var g1 := Game.res("gold")
	var r2: Dictionary = Game.campaign.report(cfg, {"won": true, "stars": 3})
	check(r2.get("duplicate", false), "duplicate report refused")
	eq(Game.res("gold"), g1, "no double reward")
	check(not Game.campaign.is_available("c1m3"), "c1m3 still locked")


func test_level_up() -> void:
	fresh()
	var c0 := Game.res("crystals")
	Game.add_xp(Game.xp_for_next())
	eq(Game.level(), 2, "level up")
	check(Game.res("crystals") > c0, "level reward")
