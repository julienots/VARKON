extends TestCase
## UI integration smoke test: instantiates the real main scene and walks every screen, tab
## and popup, plays a full battle through the view and opens the results screen.
## Any GDScript runtime error is caught by tools/run_tests.sh.

var main: Node


func _tree() -> SceneTree:
	return Engine.get_main_loop()


func _frames(n := 2) -> void:
	for i in n:
		await _tree().process_frame


func _setup_rich_profile() -> void:
	fresh()
	Game.state.profile.level = 12
	for r in DB.resources.keys():
		Game.state.resources[r] = 99999
	for bd in Game.base.buildings_of("fortress"):
		bd.level = 6
	for i in range(1, 9):
		for ch in range(1, 4):
			Game.state.campaign.stars["c%dm%d" % [ch, i]] = 2
	Game.set_flag("lab_repaired")
	for bd in Game.base.buildings_of("laboratory"):
		bd.level = 3
	for cid in ["brulecrane", "ferrailleur", "ombre_lame", "alpha_sauvage", "gardien_blizzard"]:
		Game.collection.add_copies(cid, 3)
	for iid in ["w_brise_fer", "r_coeur_fourneau", "h_masque_mille", "b_wings", "a_frost", "t_mech_frame"]:
		Game.inventory.add_item(iid)
	Game.state.chests = {"chest_wood": 2, "chest_royal": 1}
	Game.state.cosmetics.append("emote_roar")


func test_walk_all_screens() -> void:
	_setup_rich_profile()
	main = load("res://scenes/main.tscn").instantiate()
	_tree().root.add_child(main)
	await _frames(3)
	var screens := {
		"menu": [], "combat": ["campaign", "raid", "defense", "survival", "challenges", "training", "bosses", "online"],
		"collection": ["cards", "deck", "synergies"], "king": ["equipment", "appearance", "abilities", "mutations", "loadouts", "cosmetics", "stats"],
		"base": [], "lab": ["design", "mutation", "experiment", "research", "recycle", "relics"], "chests": [],
		"shop": [], "pass": [], "missions": ["daily", "weekly", "achievements"], "inventory": [], "events": [],
		"settings": ["graphics", "audio", "controls", "access", "gameplay", "notifs", "account"], "legal": [],
	}
	for sname in screens.keys():
		Router.goto(sname)
		await _frames(2)
		check(Router.current_name == sname, "opened " + sname)
		var scr: Control = Router.current
		for t in screens[sname]:
			if scr.has_method("_select"):
				scr._select(t)
			elif scr.has_method("_set_tab"):
				scr._set_tab(t)
			await _frames(1)
		if scr.has_method("_set_section"):
			for sec in scr.SECTIONS:
				scr._set_section(sec)
				await _frames(1)
	Router.goto("legal", {"doc": "terms"})
	await _frames(1)
	Router.back()
	await _frames(1)
	main.queue_free()
	await _frames(2)


func test_popups_and_actions() -> void:
	_setup_rich_profile()
	main = load("res://scenes/main.tscn").instantiate()
	_tree().root.add_child(main)
	await _frames(3)
	# Collection: card detail + upgrade path
	Router.goto("collection")
	await _frames(1)
	Router.current._card_detail("pillard")
	await _frames(1)
	check(Router.popup_open != null, "card detail popup")
	Router.close_popup()
	Router.current._card_detail("abomination_royale")
	Router.close_popup()
	# King: item preview & equip, appearance cycling, loadouts
	Router.goto("king")
	await _frames(1)
	var k: Control = Router.current
	k.slot_open = "right_arm"
	k._refresh()
	var uid: String = Game.inventory.items_for_slot("right_arm")[0]
	k._show_item(uid)
	await _frames(1)
	Router.close_popup()
	k._cycle("horns", 1)
	k._cycle("paint", 1)
	k._set_tab("loadouts")
	Game.king.save_loadout(0, "Test")
	k._refresh()
	# Combat: mission popup
	Router.goto("combat")
	await _frames(1)
	Router.current._mission_popup(DB.missions.c1m1)
	await _frames(1)
	Router.close_popup()
	# Chests: odds and open
	Router.goto("chests")
	await _frames(1)
	Router.current._odds("chest_royal")
	Router.close_popup()
	await Router.current._open("chest_wood")
	check(Game.chests.count("chest_wood") == 1, "chest opened from UI")
	Router.close_popup()
	# Shop: preview & buy (confirmation disabled for the test)
	Settings.values.confirm_spend = false
	Router.goto("shop")
	await _frames(1)
	Router.current._preview("w_fendoir_royal")
	await _frames(1)
	Router.close_popup()
	var g0 := Game.res("gold")
	Router.current._buy(DB.shop_offers.o_chest_wood)
	check(Game.res("gold") < g0, "bought from UI")
	Router.close_popup()
	# Base: panel, build menu, zones, move flow
	Router.goto("base")
	await _frames(2)
	var b: Control = Router.current
	var fort: Dictionary = Game.base.buildings_of("fortress")[0]
	b.selected_uid = fort.uid
	b._show_panel(fort.uid)
	var lab_bd: Dictionary = Game.base.buildings_of("laboratory")[0]
	b._show_panel(lab_bd.uid)
	b._open_build_menu()
	Router.close_popup()
	b._open_zones()
	Router.close_popup()
	b._start_build("watchtower")
	b.place_pos = Vector2i(13, 17)
	b._update_ghost()
	b._confirm_place()
	check(Game.base.buildings_of("watchtower").size() == 2, "built from UI")
	b._start_move(fort.uid)
	b._cancel_place()
	b._collect_all()
	# Lab: craft & research
	Router.goto("lab")
	await _frames(1)
	Game.lab.start_craft("rc_w_machoire_acier")
	Router.current._refresh()
	Router.current._set_tab("research")
	Router.current._set_tab("relics")
	# Pass & missions claims
	Game.season.add_xp(500)
	Router.goto("pass")
	await _frames(2)
	Router.goto("missions")
	await _frames(1)
	# Top bar notifications
	var tb := TopBar.new()
	main.ui_root.add_child(tb)
	await _frames(1)
	tb._show_notifications()
	Router.close_popup()
	main.queue_free()
	await _frames(2)


func test_full_battle_through_view() -> void:
	_setup_rich_profile()
	main = load("res://scenes/main.tscn").instantiate()
	_tree().root.add_child(main)
	await _frames(2)
	for mode in ["duel", "boss", "raid", "defense"]:
		var cfg: Dictionary = Game.campaign.free_config(mode, "normal")
		if mode == "boss":
			cfg.boss = "boss_reine"
			cfg.boss_level = 3
		cfg.autoplay = true
		cfg.autoplay_difficulty = "expert"
		Router.start_battle(cfg)
		await _frames(2)
		var bs: Control = Router.current
		check(bs.sim != null and bs.view != null, "battle screen built (%s)" % mode)
		bs._cast("active")
		bs._pause()
		Router.close_popup()
		bs.sim.paused = false
		var guard := 0
		while not bs.sim.finished and guard < 2500:
			bs.view._process(0.3)
			bs._process(0.3)
			guard += 1
		check(bs.sim.finished, "battle %s finished through the view" % mode)
		Game.last_battle_result = {"cfg": bs.cfg, "result": bs.sim.result(), "report": Game.campaign.report(bs.cfg, bs.sim.result())}
		Router.goto("results")
		await _frames(1)
		check(Router.current_name == "results", "results shown")
	main.queue_free()
	await _frames(2)
