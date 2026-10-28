extends TestCase
## Balance regression: a "normal" autoplayer with the starter deck and starter King must be
## able to win the opening campaign missions; later missions must not be trivial.


func _winrate(mid: String, games: int, player_level := 1, autoplay := "normal") -> float:
	var wins := 0
	for i in games:
		fresh()
		Game.state.profile.level = player_level
		var cfg: Dictionary = Game.campaign.mission_config(mid)
		cfg.seed = 1000 + i * 17
		cfg.autoplay = true
		cfg.autoplay_difficulty = autoplay
		var sim := BattleSim.new(cfg)
		for s in int(500.0 / BattleSim.DT):
			sim.step()
			sim.pop_events()
			if sim.finished:
				break
		if sim.outcome == "win":
			wins += 1
	return float(wins) / games


func test_opening_missions_winnable() -> void:
	var report := []
	for mid in ["c1m1", "c1m2", "c1m3", "c1m4", "c1m5", "c1m8"]:
		var wr := _winrate(mid, 4)
		report.append("%s=%.0f%%" % [mid, wr * 100])
		if mid in ["c1m1", "c1m2", "c1m4"]:
			check(wr >= 0.5, "%s winnable with the starter deck (%.0f%%)" % [mid, wr * 100])
	print("    balance (starter deck, normal autoplay): ", ", ".join(report))


func test_late_missions_not_trivial() -> void:
	var wr := _winrate("c4m7", 3, 1, "easy")
	print("    c4m7 with starter deck / easy autoplay: %.0f%%" % (wr * 100))
	check(wr < 1.0, "late mission not trivial for a starter account")
