class_name BotAI
extends RefCounted
## Tactical-score bot. Every think tick it scores (card, position) pairs from what is visible
## on the battlefield (BattleSim.perceive) and its own hand/energy. It never reads the
## opponent's hand, deck or energy. Difficulty changes reaction time, noise, counter-play,
## synergy use, energy reserve and hero ability usage — never unit statistics.

const PARAMS := {
	"easy":   {"think": 2.2, "noise": 0.45, "counter_w": 0.4, "synergy": false, "reserve": 0.0, "threshold": 0.9, "hero_min_targets": 1, "hero_chance": 0.5, "cooldown_exploit": false},
	"normal": {"think": 1.2, "noise": 0.18, "counter_w": 1.0, "synergy": false, "reserve": 1.0, "threshold": 1.1, "hero_min_targets": 2, "hero_chance": 0.85, "cooldown_exploit": false},
	"expert": {"think": 0.6, "noise": 0.05, "counter_w": 1.3, "synergy": true, "reserve": 2.0, "threshold": 1.25, "hero_min_targets": 2, "hero_chance": 1.0, "cooldown_exploit": true},
}

var sim: BattleSim
var team := 1
var difficulty := "normal"
var p: Dictionary
var rng := RandomNumberGenerator.new()
var think_t := 1.5
var full_energy_t := 0.0
var history: Array = []          # [{card, pos, time}]
var decisions := 0
var plays := 0
var hero_casts := 0
var enemy_casts := {}            # observed enemy hero casts: slot -> time
var enemy_hero_seen_down := false
var last_reason := ""


func _init(s: BattleSim, t: int, diff: String) -> void:
	sim = s
	team = t
	difficulty = diff if PARAMS.has(diff) else "normal"
	p = PARAMS[difficulty]
	rng.seed = int(sim.cfg.get("seed", 1)) * 31 + t
	think_t = p.think


func fwd() -> float:
	## Direction toward the opponent along x.
	return -1.0 if team == 1 else 1.0


func update(dt: float) -> void:
	# Observe public events (casts are visible animations on the field).
	for ev in sim.events:
		if ev.t == "cast" and int(ev.get("team", -1)) == 1 - team:
			enemy_casts[str(ev.slot)] = sim.time
		if ev.t == "hero_down" and int(ev.team) == 1 - team:
			enemy_hero_seen_down = true
		if ev.t == "hero_respawn" and int(ev.team) == 1 - team:
			enemy_hero_seen_down = false
	var view := sim.perceive(team)
	if view.my_energy >= sim.energy_max - 0.05:
		full_energy_t += dt
	else:
		full_energy_t = 0.0
	think_t -= dt
	if think_t > 0:
		return
	think_t = p.think * rng.randf_range(0.8, 1.2)
	decisions += 1
	_think_cards(view)
	_think_hero(view)


# ------------------------------------------------------------------ perception helpers
func _enemies(view: Dictionary) -> Array:
	var out: Array = []
	for e in view.visible:
		if e.team != team and e.kind in ["unit", "hero", "boss", "decoy"]:
			out.append(e)
	return out


func _allies(view: Dictionary) -> Array:
	var out: Array = []
	for e in view.visible:
		if e.team == team and e.kind in ["unit", "hero"]:
			out.append(e)
	return out


func _my_structures(view: Dictionary) -> Array:
	var out: Array = []
	for e in view.visible:
		if e.team == team and e.kind == "structure":
			out.append(e)
	return out


func _on_my_half(e: BattleEnt) -> bool:
	return e.pos.x > BattleSim.MID - 3.0 if team == 1 else e.pos.x < BattleSim.MID + 3.0


## Threat clusters on our half: [{center, units, power, flying, swarm, tank, ranged}]
func _threats(view: Dictionary) -> Array:
	var raw: Array = []
	for e in _enemies(view):
		if _on_my_half(e) or e.kind == "boss":
			raw.append(e)
	var clusters: Array = []
	for e in raw:
		var placed := false
		for c in clusters:
			if c.center.distance_to(e.pos) < 3.5:
				c.units.append(e)
				c.center = (c.center * (c.units.size() - 1) + e.pos) / c.units.size()
				placed = true
				break
		if not placed:
			clusters.append({"center": e.pos, "units": [e]})
	for c in clusters:
		var power := 0.0
		var flying := 0
		var low_hp := 0
		var tank := 0
		var ranged := 0
		var min_struct_d := 99.0
		for u in c.units:
			power += (u.dmg / maxf(0.3, u.hit)) * 0.5 + u.hp * 0.02
			if u.flying:
				flying += 1
			if u.max_hp < 450:
				low_hp += 1
			if u.max_hp > 1500 or u.kind == "boss":
				tank += 1
			if u.proj > 0:
				ranged += 1
		for s in _my_structures(view):
			min_struct_d = minf(min_struct_d, s.pos.distance_to(c.center))
		c.power = power * (1.0 + maxf(0.0, 10.0 - min_struct_d) * 0.15)
		c.flying = flying
		c.swarm = low_hp >= 3
		c.tank = tank
		c.ranged = ranged
	return clusters


# ------------------------------------------------------------------ cards
func _card_profile(cid: String) -> Dictionary:
	var d: Dictionary = DB.cards[cid]
	var st: Dictionary = d.stats
	var types: Array = []
	for a in d.abilities:
		types.append(a.type)
	return {
		"cost": float(d.cost), "dps": float(st.dmg) * int(st.count) / maxf(0.3, float(st.hit)), "hp": float(st.hp) * int(st.count),
		"air": bool(st.air) or bool(st.flying), "flying": bool(st.flying), "splash": "splash" in types or "periodic_zone" in types or "alchemy_cycle" in types,
		"structures_only": st.targets == "structures", "ranged": float(st.range) > 2.0, "tank": d.role == "tank",
		"support": d.role in ["support", "caster"] or "aura_buff" in types or "heal_ally" in types or "shield_allies" in types,
		"family": d.family, "role": d.role, "anti_tank": "execute" in types or "armor_pierce" in types or "bonus_vs_slowed" in types or d.role == "assassin",
	}


func _think_cards(view: Dictionary) -> void:
	var hand: Array = view.my_hand
	if hand.is_empty() or sim.no_cards[team]:
		return
	var threats := _threats(view)
	var allies := _allies(view)
	var energy: float = view.my_energy
	var best_score := -INF
	var best_play := {}
	var zone: Rect2 = view.zone
	for i in hand.size():
		var cid: String = hand[i]
		var prof := _card_profile(cid)
		if prof.cost > energy:
			continue
		for pos in _positions(view, prof, threats, allies, zone):
			var s := _score(prof, cid, pos, threats, allies, energy)
			s *= 1.0 + rng.randf_range(-p.noise, p.noise)
			s *= _repeat_penalty(cid, pos)
			if s > best_score:
				best_score = s
				best_play = {"i": i, "pos": pos, "cid": cid}
	if best_play.is_empty():
		return
	var forced := full_energy_t > 3.0
	var thr: float = p.threshold
	if best_score >= thr or forced:
		if sim.play_card(team, best_play.i, best_play.pos):
			plays += 1
			history.append({"card": best_play.cid, "pos": best_play.pos, "time": sim.time})
			if history.size() > 12:
				history.pop_front()
			last_reason = "forced" if forced and best_score < thr else "score %.2f" % best_score


func _positions(view: Dictionary, prof: Dictionary, threats: Array, allies: Array, zone: Rect2) -> Array:
	var out: Array = []
	var front_x := zone.position.x + 1.0 if team == 1 else zone.end.x - 1.0
	var back_x := zone.end.x - 2.0 if team == 1 else zone.position.x + 2.0
	# Defensive spots: in front of each threat (melee) or behind it (ranged).
	for c in threats:
		var off := 1.2 if not prof.ranged else 4.0
		var px: float = c.center.x + (off if team == 1 else -off)  # between threat and our base
		out.append(_clamp_zone(Vector2(px, c.center.y), zone))
	# Offensive lanes
	for lane in [4.0, BattleSim.W - 4.0, BattleSim.W / 2.0]:
		out.append(_clamp_zone(Vector2(back_x if prof.tank else front_x, lane), zone))
	# Support behind the most advanced ally
	if prof.support and not allies.is_empty():
		var lead: BattleEnt = allies[0]
		for a in allies:
			if (a.pos.x - lead.pos.x) * fwd() > 0:
				lead = a
		out.append(_clamp_zone(lead.pos - Vector2(fwd() * 1.5, 0), zone))
	return out


func _clamp_zone(v: Vector2, zone: Rect2) -> Vector2:
	return Vector2(clampf(v.x, zone.position.x + 0.2, zone.end.x - 0.2), clampf(v.y, zone.position.y + 0.2, zone.end.y - 0.2))


func _score(prof: Dictionary, cid: String, pos: Vector2, threats: Array, allies: Array, energy: float) -> float:
	var s := 0.0
	var cw: float = p.counter_w
	# --- Defense
	var nearest_threat: Dictionary = {}
	var nd := INF
	for c in threats:
		var d: float = c.center.distance_to(pos)
		if d < nd:
			nd = d
			nearest_threat = c
	if not nearest_threat.is_empty() and nd < 6.0:
		var t := nearest_threat
		var dv := clampf(t.power / 60.0, 0.3, 3.0)
		if prof.structures_only:
			dv *= 0.1
		var counter := 1.0
		if t.flying > 0:
			counter *= 1.6 if prof.air else 0.25
		if t.swarm and prof.splash:
			counter *= 1.7
		if t.tank > 0 and (prof.anti_tank or prof.dps > 120):
			counter *= 1.5
		if t.ranged > 0 and (prof.role == "assassin" or prof.flying):
			counter *= 1.3
		s += dv * (1.0 + (counter - 1.0) * cw) * (1.0 - nd / 8.0)
	# --- Offense
	var threat_power := 0.0
	for c in threats:
		threat_power += c.power
	if threat_power < 20.0:
		var reserve: float = p.reserve
		if energy - prof.cost >= reserve or energy >= sim.energy_max - 0.5:
			var o := 0.7
			if prof.tank and _is_back(pos):
				o += 0.5  # tanks start a push from the back
			if prof.structures_only and not _is_back(pos):
				o += 0.3
			if p.cooldown_exploit and _enemy_hero_vulnerable():
				o += 0.4
			s += o
	# --- Support / synergy
	if prof.support:
		var near := 0
		for a in allies:
			if a.pos.distance_to(pos) < 3.5:
				near += 1
		s += 0.25 * near
	if p.synergy:
		for a in allies:
			if a.family == prof.family and a.pos.distance_to(pos) < 4.0:
				s += 0.2
		if sim.synergy_bonus[team].has(prof.family):
			s += 0.15
	# --- Efficiency: prefer cheaper answers
	s *= 1.0 + (5.0 - prof.cost) * 0.04
	return s


func _is_back(pos: Vector2) -> bool:
	return pos.x > BattleSim.L - 6.0 if team == 1 else pos.x < 6.0


func _enemy_hero_vulnerable() -> bool:
	if enemy_hero_seen_down:
		return true
	var last := float(enemy_casts.get("active", -99.0))
	return sim.time - last < 6.0


func _repeat_penalty(cid: String, pos: Vector2) -> float:
	var n := 0
	for h in history:
		if h.card == cid and h.pos.distance_to(pos) < 1.0 and sim.time - float(h.time) < 10.0:
			n += 1
	return pow(0.6, n)


# ------------------------------------------------------------------ hero
func _think_hero(view: Dictionary) -> void:
	var h: BattleEnt = view.my_hero
	if h == null or not h.alive:
		return
	var enemies := _enemies(view)
	var threats := _threats(view)
	# Movement: defend the most dangerous threat, else escort the push, else guard.
	var dest := Vector2.ZERO
	var has_dest := false
	var biggest: Dictionary = {}
	for c in threats:
		if biggest.is_empty() or c.power > biggest.power:
			biggest = c
	if not biggest.is_empty() and biggest.power > 15.0:
		dest = biggest.center
		has_dest = true
	else:
		var allies := _allies(view)
		var lead: BattleEnt = null
		for a in allies:
			if a.kind == "unit" and (lead == null or (a.pos.x - lead.pos.x) * fwd() > 0):
				lead = a
		if lead and difficulty != "easy":
			dest = lead.pos - Vector2(fwd() * 1.8, 0)
			has_dest = true
		elif view.my_throne:
			dest = view.my_throne.pos + Vector2(fwd() * 3.0, 0)
			has_dest = h.pos.distance_to(dest) > 2.0
	if has_dest and h.target == null or (has_dest and h.pos.distance_to(dest) > 5.0):
		sim.hero_move(team, dest)
	# Abilities
	var near := 0
	for e in enemies:
		if e.pos.distance_to(h.pos) < 3.0:
			near += 1
	if rng.randf() > p.hero_chance:
		return
	if near >= int(p.hero_min_targets) and sim.hero_can_cast(team, "active") == "":
		if sim.hero_cast(team, "active"):
			hero_casts += 1
	if (h.hp_frac() < 0.45 and near > 0 or near >= 3) and sim.hero_can_cast(team, "defensive") == "":
		if sim.hero_cast(team, "defensive"):
			hero_casts += 1
	if near >= 2 and sim.hero_can_cast(team, "ultimate") == "":
		if sim.hero_cast(team, "ultimate"):
			hero_casts += 1
