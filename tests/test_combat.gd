extends TestCase
## Combat simulation, abilities, bosses and bots (headless, deterministic seeds).


func _cfg(mode := "duel", diff := "normal", seed_v := 42) -> Dictionary:
	fresh()
	var deck := ["pillard", "frondeur", "pyrogobelin", "givregriffes", "croquefer", "boulon", "medecin_guerre", "aile_griffe"]
	return {
		"mode": mode, "seed": seed_v, "modifiers": {},
		"player": Game.campaign.player_side(),
		"enemy": Game.campaign.enemy_side(deck, 2, diff, true, seed_v),
	}


func _run(sim: BattleSim, max_seconds := 400.0) -> void:
	var steps := int(max_seconds / BattleSim.DT)
	for i in steps:
		sim.step()
		sim.pop_events()
		if sim.finished:
			return


func _empty_sim() -> BattleSim:
	var c := _cfg("duel")
	c.player.hero = null
	c.enemy.hero = null
	c.enemy.deck = []
	var sim := BattleSim.new(c)
	return sim


func test_bot_vs_bot_all_difficulties_finish() -> void:
	for diff in ["easy", "normal", "expert"]:
		var c := _cfg("duel", diff, 1000 + diff.length())
		c.autoplay = true
		c.autoplay_difficulty = "normal"
		var sim := BattleSim.new(c)
		_run(sim)
		check(sim.finished, "%s match finished (t=%.0f)" % [diff, sim.time])
		var bot: BotAI = sim.bots[1]
		check(bot.plays >= 5, "%s bot played cards (%d)" % [diff, bot.plays])
		check(bot.hero_casts >= 1, "%s bot used hero abilities (%d)" % [diff, bot.hero_casts])
		check(sim.bots[0].plays >= 5, "autoplay side played")


func test_expert_beats_easy_more_often() -> void:
	var wins := 0
	var games := 6
	for i in games:
		var c := _cfg("duel", "easy", 500 + i)
		c.autoplay = true
		c.autoplay_difficulty = "expert"
		var sim := BattleSim.new(c)
		_run(sim)
		if sim.outcome == "win":
			wins += 1
	check(wins >= games / 2, "expert (player side) beat easy bot %d/%d" % [wins, games])


func test_bot_not_stuck_and_varies() -> void:
	var c := _cfg("duel", "normal", 77)
	var sim := BattleSim.new(c)
	var played := {}
	for i in int(90.0 / BattleSim.DT):
		sim.step()
		sim.pop_events()
	var bot: BotAI = sim.bots[1]
	for h in bot.history:
		played[h.card] = true
	check(bot.plays >= 6, "bot keeps playing (%d)" % bot.plays)
	check(played.size() >= 3, "bot uses varied cards (%d)" % played.size())
	check(sim.energy[1] < sim.energy_max or bot.full_energy_t < 4.0, "bot does not sit on full energy")


func test_bot_perception_hides_stealth() -> void:
	var sim := _empty_sim()
	var u := sim.spawn_unit(0, "traqueur_nocturne", Vector2(10, 9), 1)
	u.stealth_t = 5.0
	var view := sim.perceive(1)
	check(not u in view.visible, "stealthed unit hidden from bot")
	check(not view.has("enemy_hand") and not view.has("enemy_energy"), "no hidden info exposed")
	sim.spawn_unit(1, "eclaireur_vents", Vector2(11, 9), 1)
	check(u in sim.perceive(1).visible, "revealed by scout")


func test_card_play_rules() -> void:
	var sim := _empty_sim()
	sim.energy[0] = 0
	eq(sim.can_play(0, 0, Vector2(5, 9)), "ERR_ENERGY", "needs energy")
	sim.energy[0] = 10
	eq(sim.can_play(0, 0, Vector2(25, 9)), "ERR_ZONE", "own half only")
	var first: String = sim.hands[0][0]
	check(sim.play_card(0, 0, Vector2(5, 9)), "card played")
	check(sim.energy[0] < 10, "energy spent")
	check(first in sim.queues[0], "card cycled to queue")
	eq(sim.hands[0].size(), 4, "hand refilled")


func test_burn_and_poison() -> void:
	var sim := _empty_sim()
	var a := sim.spawn_unit(0, "brulecrane", Vector2(15, 9), 1)
	var b := sim.spawn_unit(1, "croquefer", Vector2(15.8, 9), 1)
	for i in 40:
		sim.step()
	check(b.has_status("burn") or b.hp < b.max_hp, "burn applied")
	var v := sim.spawn_unit(0, "venin", Vector2(15, 12), 1)
	var c := sim.spawn_unit(1, "croquefer", Vector2(15.8, 12), 1)
	for i in 80:
		sim.step()
	check(c.has_status("poison") and int(c.statuses.poison.stacks) >= 2, "poison stacks")


func test_slow_and_briseglace_bonus() -> void:
	var sim := _empty_sim()
	var t := sim.spawn_unit(1, "croquefer", Vector2(16, 9), 1)
	t.deploy_t = 0
	var before := sim.eff_speed(t)
	sim.apply_status(t, "slow", 35, 2.0)
	check(sim.eff_speed(t) < before, "slow reduces speed")
	var bg := sim.spawn_unit(0, "briseglace", Vector2(15, 9), 1)
	var hp0 := t.hp
	sim._on_hit(bg, t, 100.0, {})
	var dmg_slowed := hp0 - t.hp
	t.statuses.clear()
	var hp1 := t.hp
	sim._on_hit(bg, t, 100.0, {})
	check(dmg_slowed > (hp1 - t.hp) * 1.5, "bonus vs slowed")


func test_splash_hits_multiple() -> void:
	var sim := _empty_sim()
	var bm := sim.spawn_unit(0, "bombardier_magma", Vector2(10, 9), 1)
	var targets: Array = []
	for i in 3:
		targets.append(sim.spawn_unit(1, "pillard", Vector2(14.5, 8.6 + i * 0.4), 1))
	sim._on_hit(bm, targets[0], 100.0, {})
	check(targets[1].hp < targets[1].max_hp and targets[2].hp < targets[2].max_hp, "splash damage")


func test_heal_and_shield() -> void:
	var sim := _empty_sim()
	var m := sim.spawn_unit(0, "medecin_guerre", Vector2(8, 9), 1)
	var hurt := sim.spawn_unit(0, "croquefer", Vector2(9, 9), 1)
	hurt.hp = hurt.max_hp * 0.5
	var hp0 := hurt.hp
	for i in 60:
		sim.step()
	check(hurt.hp > hp0, "healed")
	var sp := sim.spawn_unit(0, "sentinelle_polaire", Vector2(5, 5), 1)
	var ally := sim.spawn_unit(0, "frondeur", Vector2(5.5, 5), 1)
	for i in 30:
		sim.step()
	check(ally.shield > 0, "shield given")


func test_summon_and_turret() -> void:
	var sim := _empty_sim()
	sim.spawn_unit(0, "alpha_sauvage", Vector2(6, 9), 3)
	sim.spawn_unit(0, "ferrailleur", Vector2(6, 12), 3)
	var n0 := sim.ents.size()
	for i in 60:
		sim.step()
	var wolves := 0
	for e in sim.ents:
		if e.def_id == "loup_gobelin":
			wolves += 1
	eq(wolves, 2, "alpha summoned 2 wolves")
	for i in int(13.0 / BattleSim.DT):
		sim.step()
	var turrets := 0
	for e in sim.ents:
		if e.kind == "turret":
			turrets += 1
	check(turrets >= 1, "turret built")


func test_walls_block_but_bondisseur_jumps() -> void:
	var c := _cfg("raid")
	c.layout = "raid_1"
	c.player.hero = null
	c.enemy.deck = []
	c.enemy.hero = null
	var sim := BattleSim.new(c)
	var walker := sim.spawn_unit(0, "croquefer", Vector2(19, 9.5), 1)
	var jumper := sim.spawn_unit(0, "bondisseur", Vector2(19, 6.5), 1)
	for i in int(6.0 / BattleSim.DT):
		sim.step()
	check(walker.pos.x < 22.0, "wall stops ground unit (x=%.1f)" % walker.pos.x)
	check(walker.target != null and walker.target.kind == "wall" or walker.pos.x < 22.0, "unit attacks wall")
	check(jumper.pos.x > 22.0 or not jumper.alive, "bondisseur passes walls (x=%.1f)" % jumper.pos.x)


func test_teleport_and_stealth_targeting() -> void:
	var sim := _empty_sim()
	var o := sim.spawn_unit(0, "ombre_lame", Vector2(10, 9), 1)
	var far := sim.spawn_unit(1, "frondeur", Vector2(15.5, 9), 1)
	far.deploy_t = 0
	o.deploy_t = 0
	var start := o.pos
	for i in 40:
		sim.step()
	check(o.pos.distance_to(start) > 3.0, "teleported toward target")
	var t := sim.spawn_unit(1, "traqueur_nocturne", Vector2(20, 9), 1)
	t.stealth_t = 3.0
	var looker := sim.spawn_unit(0, "frondeur", Vector2(15, 9), 1)
	check(not sim.can_target(looker, t), "stealthed not targetable")


func test_hero_abilities() -> void:
	var c := _cfg("duel")
	c.enemy.deck = []
	c.enemy.hero = null
	var sim := BattleSim.new(c)
	var h: BattleEnt = sim.heroes[0]
	check(h != null, "hero spawned")
	h.deploy_t = 0
	var e1 := sim.spawn_unit(1, "croquefer", h.pos + Vector2(1.2, 0), 1)
	e1.deploy_t = 5
	var hp0 := e1.hp
	check(sim.hero_cast(0, "active"), "tyrant strike cast")
	eq(sim.hero_can_cast(0, "active"), "ERR_COOLDOWN", "cooldown applied")
	for i in 10:
		sim.step()
	check(e1.hp < hp0, "tyrant strike damaged")
	check(sim.hero_cast(0, "defensive"), "iron skin")
	check(h.shield > 0, "shield applied")
	eq(sim.hero_can_cast(0, "ultimate"), "ERR_CHARGING", "ultimate needs charge")
	sim.hero_charge[0] = 100
	check(sim.hero_cast(0, "ultimate"), "ultimate cast")
	check(h.has_status("fury"), "mutant fury active")
	e1.alive = false
	sim.hero_move(0, Vector2(8, 3))
	var closest := 99.0
	for i in 120:
		sim.step()
		closest = minf(closest, h.pos.distance_to(Vector2(8, 3)))
	check(closest < 0.5, "hero follows move order (%.2f)" % closest)


func test_protect_king() -> void:
	var c := _cfg("duel")
	c.enemy.deck = []
	c.enemy.hero = null
	var sim := BattleSim.new(c)
	var h: BattleEnt = sim.heroes[0]
	var g := sim.spawn_unit(0, "garde_trone", h.pos + Vector2(0.5, 0.5), 1)
	g.deploy_t = 0
	sim.step()
	var ghp := g.hp
	sim._damage(null, h, 400.0, "attack")
	check(g.hp < ghp, "guard absorbed part of the damage")


func test_boss_phases_and_telegraph() -> void:
	var c := _cfg("boss")
	c.boss = "boss_colosse"
	c.boss_level = 1
	c.autoplay = true
	var sim := BattleSim.new(c)
	check(sim.boss != null, "boss spawned")
	var telegraphs := 0
	var broken := false
	var phases := 0
	for i in int(240.0 / BattleSim.DT):
		sim.step()
		for ev in sim.pop_events():
			if ev.t == "telegraph":
				telegraphs += 1
			if ev.t == "armor_broken":
				broken = true
			if ev.t == "phase" and ev.id == sim.boss.id:
				phases += 1
		if sim.finished:
			break
	check(sim.finished, "boss fight ends")
	check(telegraphs > 0, "boss telegraphs attacks")
	check(broken or sim.boss.data.armor_layer < float(DB.bosses.boss_colosse.armor_layer), "armor plates damaged")


func test_all_bosses_run() -> void:
	for bid in DB.bosses.keys():
		var c := _cfg("boss", "normal", hash(bid))
		c.boss = bid
		c.autoplay = true
		var sim := BattleSim.new(c)
		_run(sim, 120.0)
		check(sim.time > 1.0, "boss %s simulated" % bid)
		check(sim.boss.data.phase >= 0, "boss phase valid " + bid)


func test_defense_waves() -> void:
	var c := _cfg("defense")
	c.waves = [{"delay": 2.0, "units": ["pillard", "pillard"]}, {"delay": 5.0, "units": ["croquefer"]}]
	c.autoplay = true
	var sim := BattleSim.new(c)
	_run(sim, 200.0)
	check(sim.finished, "defense finished")
	check(sim.wave_index == 2, "both waves spawned")


func test_survival_counts_waves() -> void:
	var c := _cfg("survival")
	c.autoplay = true
	c.autoplay_difficulty = "expert"
	var sim := BattleSim.new(c)
	_run(sim, 200.0)
	check(sim.wave_index >= 3, "survival waves escalate (%d)" % sim.wave_index)


func test_every_card_spawns_and_fights() -> void:
	for cid in DB.cards.keys():
		var sim := _empty_sim()
		var u := sim.spawn_unit(0, cid, Vector2(13, 9), 1)
		var foe := sim.spawn_unit(1, "croquefer", Vector2(18, 9), 3)
		for i in int(15.0 / BattleSim.DT):
			sim.step()
			sim.pop_events()
		var acted: bool = foe.hp < foe.max_hp or not foe.alive or u.damage_dealt > 0 or sim.thrones[1].hp < sim.thrones[1].max_hp
		check(acted, "card %s deals damage" % cid)


func test_synergy_applies() -> void:
	var c := _cfg("duel")
	c.player.synergies = Collection.active_synergies(["pyrogobelin", "brulecrane", "danseflammes"])
	c.enemy.deck = []
	var sim := BattleSim.new(c)
	var u := sim.spawn_unit(0, "pyrogobelin", Vector2(5, 9), 1)
	check(u.dmg_pct >= 12.0, "fire synergy damage bonus")


func test_time_limit_resolution() -> void:
	var sim := _empty_sim()
	sim.duration = 2.0
	for s in sim.ents:
		if s.team == 1 and s.sub == "tower":
			s.hp = 0
			sim._kill(s, null)
			break
	_run(sim, 5.0)
	eq(sim.outcome, "win", "more structures destroyed wins at time limit")
