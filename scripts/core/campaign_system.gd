class_name CampaignSystem
extends RefCounted
## Campaign progression, battle configuration for every mode and battle rewards.

var g


func _init(game) -> void:
	g = game


func stars(mid: String) -> int:
	return int(g.state.campaign.stars.get(mid, 0))


func is_completed(mid: String) -> bool:
	return stars(mid) > 0


func is_available(mid: String) -> bool:
	var mm: Dictionary = DB.missions.get(mid, {})
	if mm.is_empty():
		return false
	var req = mm.get("requires")
	return req == null or is_completed(str(req))


func total_stars() -> int:
	var t := 0
	for k in g.state.campaign.stars.keys():
		t += int(g.state.campaign.stars[k])
	return t


func chapter_completed(ch: int) -> bool:
	return is_completed("c%dm8" % ch)


func current_mission() -> String:
	for mm in DB.mission_list:
		if not is_completed(mm.id):
			return mm.id
	return DB.mission_list[-1].id


# ------------------------------------------------------------------ battle config
func player_side(mods: Dictionary = {}) -> Dictionary:
	var bonuses: Dictionary = g.base.battle_bonuses()
	var deck: Array = []
	for cid in g.state.deck:
		if mods.has("only_families") and not DB.cards[cid].family in mods.only_families:
			continue
		if mods.has("max_cost") and int(DB.cards[cid].cost) > int(mods.max_cost):
			continue
		deck.append({"id": cid, "level": g.collection.level_of(cid)})
	# Fill restricted decks with eligible owned cards so the hand is never empty.
	if deck.size() < 8 and (mods.has("only_families") or mods.has("max_cost")):
		for cid in g.state.cards.keys():
			if deck.size() >= 8:
				break
			var ok: bool = (not mods.has("only_families") or DB.cards[cid].family in mods.only_families) and (not mods.has("max_cost") or int(DB.cards[cid].cost) <= int(mods.max_cost))
			var present := false
			for e in deck:
				if e.id == cid:
					present = true
			if ok and not present:
				deck.append({"id": cid, "level": g.collection.level_of(cid)})
	if mods.get("no_cards", false):
		deck = []
	var hero = null
	if not mods.get("no_hero", false):
		hero = player_hero()
	var ids: Array = []
	for e in deck:
		ids.append(e.id)
	return {
		"deck": deck,
		"hero": hero,
		"synergies": Collection.active_synergies(ids),
		"card_stat_pct": float(bonuses.card_stat_pct),
		"structure_hp_pct": float(bonuses.tower_pct) + 5.0 * g.lab.research_level("fortification"),
		"structure_dmg_pct": float(bonuses.tower_pct),
		"energy_bonus": g.lab.research_bonus_f("start_energy") + (hero.stats.energy if hero else 0.0),
		"defense": {"walls": int(bonuses.wall_segments), "wall_hp": int(bonuses.wall_hp), "traps": int(bonuses.traps), "trap_dmg": int(bonuses.trap_dmg)},
	}


func player_hero() -> Dictionary:
	var st: Dictionary = g.king.current_stats()
	return {
		"name": str(g.state.profile.name),
		"stats": st,
		"abilities": g.state.king.abilities.duplicate(),
		"appearance": g.king.appearance_with_mutations(),
		"visuals": g.king.equipped_visuals(),
		"cosmetic_sel": g.state.king.cosmetic_sel.duplicate(),
	}


static func rival_hero(level: int, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var base: Dictionary = DB.king.base
	var mult := 1.0 + 0.06 * (level - 1)
	var app := {}
	for key in KingSystem.APPEARANCE_KEYS:
		app[key] = rng.randi() % maxi(1, DB.king.appearance[key].size())
	app["mutation_visuals"] = []
	var weapons := ["w_bone_axe", "w_club", "w_pike", "w_brise_fer", "w_fendoir_royal"]
	var wid: String = weapons[mini(weapons.size() - 1, level / 3)]
	var wd: Dictionary = DB.items[wid]
	var style: Dictionary = DB.king.weapon_styles.get(wd.category, DB.king.weapon_styles.none)
	var visuals := {"right_arm": wd.visual.duplicate(), "head": DB.items.h_iron_helm.visual.duplicate(), "torso": DB.items.t_scrap.visual.duplicate()}
	return {
		"name": "Chef rival",
		"stats": {"hp": int(float(base.hp) * 0.85 * mult), "dmg": int(float(base.dmg) * 0.9 * mult), "armor": float(base.armor), "speed": float(base.speed),
			"hit": float(style.hit), "range": float(base.range) * float(style.range), "proj": float(style.get("proj", 0)), "splash": float(style.get("splash", 0)),
			"resist": 0.0, "cdr_pct": 0.0, "ability_power_pct": 0.0, "effects": [], "weapon": wd.category, "mech_module": false, "energy": 0.0},
		"abilities": {"active": "tyrant_strike", "defensive": "iron_skin", "ultimate": "mutant_fury" if level % 2 == 0 else "raider_call", "passive": "royal_presence"},
		"appearance": app,
		"visuals": visuals,
		"cosmetic_sel": {},
	}


func enemy_side(deck_ids: Array, level: int, difficulty: String, with_hero: bool, seed_v: int) -> Dictionary:
	var deck: Array = []
	var card_level := clampi(1 + level / 2, 1, 10)
	for cid in deck_ids:
		if DB.cards.has(cid):
			deck.append({"id": cid, "level": card_level})
	return {
		"deck": deck,
		"hero": rival_hero(level, seed_v) if with_hero else null,
		"synergies": Collection.active_synergies(deck_ids),
		"difficulty": difficulty,
		"card_stat_pct": 0.0,
		"structure_hp_pct": 4.0 * (level - 1),
		"structure_dmg_pct": 3.0 * (level - 1),
		"energy_bonus": 0.0,
	}


func mission_config(mid: String) -> Dictionary:
	var mm: Dictionary = DB.missions[mid]
	var mods: Dictionary = mm.get("modifiers", {})
	var seed_v := hash(mid)
	var cfg := {
		"mode": str(mm.type),
		"mission_id": mid,
		"title": str(mm.name),
		"tip": str(mm.tip) if Settings.get_v("tutorials") else "",
		"seed": seed_v,
		"modifiers": mods,
		"player": player_side(mods),
		"enemy": enemy_side(mm.enemy_deck, int(mm.enemy_level), str(mm.difficulty), bool(mm.enemy_hero), seed_v),
	}
	if mm.has("boss"):
		cfg.boss = mm.boss
		cfg.boss_level = int(mm.enemy_level)
	if mm.has("waves"):
		cfg.waves = mm.waves
	if mm.has("layout"):
		cfg.layout = mm.layout
	return cfg


func free_config(mode: String, difficulty: String) -> Dictionary:
	## Non-campaign modes: quick duel, raid, defense, survival, training.
	var lvl := maxi(1, g.level() + {"easy": -1, "normal": 0, "expert": 2}.get(difficulty, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(g.now())
	var pool: Array = []
	for c in DB.card_list:
		if int(c.unlock_level) <= lvl + 2:
			pool.append(c.id)
	var deck: Array = []
	while deck.size() < 8 and not pool.is_empty():
		var cid: String = pool[rng.randi() % pool.size()]
		pool.erase(cid)
		deck.append(cid)
	var seed_v := rng.randi()
	var cfg := {
		"mode": mode, "title": g.tr("MODE_" + mode.to_upper()), "seed": seed_v, "modifiers": {}, "tip": "",
		"player": player_side(), "enemy": enemy_side(deck, lvl, difficulty, mode == "duel" or (mode == "raid" and difficulty == "expert"), seed_v), "free": true,
	}
	if mode == "raid":
		cfg.layout = "raid_%d" % (1 + rng.randi() % 3)
	if mode == "defense":
		var waves: Array = []
		for w in 5:
			var units: Array = []
			for j in 2 + w:
				units.append(deck[(w * 3 + j) % deck.size()])
			waves.append({"delay": 4.0 if w == 0 else 14.0, "units": units})
		cfg.waves = waves
	if mode == "survival":
		cfg.endless = true
	if mode == "training":
		cfg.enemy.deck = []
		cfg.enemy.hero = null
	return cfg


func event_config(ev: Dictionary) -> Dictionary:
	var mode: String = ev.type
	var cfg := free_config("duel" if mode == "challenge" else mode, str(ev.get("difficulty", "normal")))
	cfg.event_id = ev.id
	cfg.title = DB.txt(ev)
	var mods: Dictionary = ev.get("modifiers", {})
	cfg.modifiers = mods
	cfg.player = player_side(mods)
	if mode == "challenge":
		cfg.mode = "challenge"
	if ev.has("families"):
		var deck: Array = []
		for c in DB.card_list:
			if c.family in ev.families and int(c.unlock_level) <= g.level() + 3:
				deck.append(c.id)
		deck.sort()
		while deck.size() > 8:
			deck.pop_back()
		if deck.size() >= 4:
			cfg.enemy = enemy_side(deck, maxi(1, g.level()), str(ev.get("difficulty", "normal")), mode in ["duel", "challenge"], int(cfg.seed))
			if mode == "defense":
				var waves: Array = []
				for w in 6:
					var units: Array = []
					for j in 2 + w:
						units.append(deck[(w * 2 + j) % deck.size()])
					waves.append({"delay": 4.0 if w == 0 else 13.0, "units": units})
				cfg.waves = waves
	if mode == "boss":
		var ids := DB.bosses.keys()
		cfg.boss = ids[hash(g.week_key()) % ids.size()]
		cfg.boss_level = maxi(1, g.level())
	return cfg


func current_event() -> Dictionary:
	var evs: Array = DB.campaign_json.get("events", [])
	if evs.is_empty():
		return {}
	var wk: String = g.week_key()
	return evs[int(wk.substr(1)) % evs.size()]


func event_completed_this_week(ev_id: String) -> bool:
	return g.state.claims.has("event_%s_%s" % [g.week_key(), ev_id])


# ------------------------------------------------------------------ results
## Applies a battle result once. `result` comes from BattleSim.result().
func report(cfg: Dictionary, result: Dictionary) -> Dictionary:
	var won: bool = result.get("won", false)
	var mode: String = cfg.get("mode", "duel")
	# A battle can only be rewarded once, even if the result screen is reopened.
	if cfg.has("battle_id") and not g.claim_once("battle_" + str(cfg.battle_id)):
		return {"entries": [], "won": won, "stars": 0, "duplicate": true}
	var reward := {}
	var br: Dictionary = DB.player_cfg().battle_rewards
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 0)) ^ int(g.now())
	g.track("battle_played", 1)
	g.track("units_deployed", int(result.get("units_deployed", 0)))
	g.track("king_ability_used", int(result.get("abilities_used", 0)))
	var raid_mult := 1.0
	if mode == "raid":
		raid_mult += float(g.base.battle_bonuses().raid_reward_pct) / 100.0
	if mode == "training":
		return {"entries": [], "won": won, "stars": 0}
	if won:
		reward.gold = int(rng.randi_range(int(br.win_gold[0]), int(br.win_gold[1])) * raid_mult)
		reward.xp = int(br.win_xp)
		reward.pass_xp = int(DB.season.xp_sources.battle_win)
		g.track("battle_won", 1)
		g.state.stats["win_streak"] = g.stat("win_streak") + 1
		g.missions.set_max("best_win_streak", g.stat("win_streak"))
		match mode:
			"raid": g.track("raid_won", 1)
			"defense": g.track("defense_won", 1)
			"boss": g.track("boss_defeated", 1)
			"challenge": g.track("challenge_won", 1)
		if rng.randi_range(1, 100) <= int(br.victory_chest_chance):
			reward.chest = "chest_victory"
	else:
		reward.gold = rng.randi_range(int(br.loss_gold[0]), int(br.loss_gold[1]))
		reward.xp = int(br.loss_xp)
		reward.pass_xp = int(DB.season.xp_sources.battle_loss)
		g.state.stats["win_streak"] = 0
	if mode == "survival":
		var waves := int(result.get("waves_cleared", 0))
		g.state.survival_best = maxi(int(g.state.survival_best), waves)
		g.missions.set_max("survival_best", waves)
		reward.gold = int(reward.gold) + 30 * waves
		reward.war_tokens = 5 * waves
	if mode == "challenge":
		reward.war_tokens = int(reward.get("war_tokens", 0)) + (int(br.war_tokens_challenge) if won else 0)
	var entries: Array = g.grant(reward, "raid" if mode == "raid" else "battle")
	var mid: String = cfg.get("mission_id", "")
	var st := int(result.get("stars", 0)) if won else 0
	if mid != "" and won:
		var mm: Dictionary = DB.missions[mid]
		entries.append_array(g.grant(mm.rewards, "battle"))
		if st > stars(mid):
			g.state.campaign.stars[mid] = st
		if g.claim_once("first_clear_" + mid):
			entries.append_array(g.grant(mm.first_clear, "battle"))
		if st >= 3 and mm.has("three_star_reward") and g.claim_once("three_star_" + mid):
			entries.append_array(g.grant(mm.three_star_reward, "battle"))
		g.missions.set_max("campaign_stars", total_stars())
		if is_completed(DB.mission_list[-1].id):
			g.missions.set_max("campaign_completed", 1)
	var ev_id: String = cfg.get("event_id", "")
	if ev_id != "" and won:
		var key := "event_%s_%s" % [g.week_key(), ev_id]
		for ev in DB.campaign_json.events:
			if ev.id == ev_id and g.claim_once(key):
				entries.append_array(g.grant(ev.reward, "battle"))
	g.save_now()
	return {"entries": entries, "won": won, "stars": st}
