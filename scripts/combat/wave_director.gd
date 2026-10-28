class_name WaveDirector
extends RefCounted
## Bot that drives defense/survival waves: chooses the attack lane from what it can see
## (weakest defended lane / damaged structures). Difficulty controls how well it reads the field.

const LANES := [4.0, 9.0, 14.0]

var sim: BattleSim
var difficulty := "normal"
var rng := RandomNumberGenerator.new()
var last_lane := -1.0


func _init(s: BattleSim, diff: String) -> void:
	sim = s
	difficulty = diff
	rng.seed = int(sim.cfg.get("seed", 1)) + 77


func choose_lane(_wave: Dictionary) -> float:
	if difficulty == "easy" and rng.randf() < 0.6:
		last_lane = LANES[rng.randi() % LANES.size()]
		return last_lane
	var view := sim.perceive(1)
	var best_lane: float = LANES[0]
	var best := -INF
	for lane in LANES:
		var score := 0.0
		for e in view.visible:
			if e.team != 0:
				continue
			if absf(e.pos.y - lane) > 3.0:
				continue
			match e.kind:
				"structure":
					score += 3.0 * (1.0 - e.hp_frac()) - 1.0
				"wall":
					score -= 0.6
				"unit", "hero":
					score -= 0.4 + e.dmg / maxf(0.3, e.hit) / 150.0
				"turret":
					score -= 0.8
		if difficulty == "expert" and lane == last_lane:
			score -= 0.5  # vary the attack to stretch the defense
		score += rng.randf_range(-0.6, 0.6) * (1.0 if difficulty == "normal" else 0.3)
		if score > best:
			best = score
			best_lane = lane
	last_lane = best_lane
	return best_lane
