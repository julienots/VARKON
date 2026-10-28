class_name BattleSim
extends RefCounted
## Deterministic, render-independent combat simulation (fixed 20 Hz step).
## Team 0 = player (left side), team 1 = enemy (right side).
## The 3D view (BattleView) only reads entities and consumes `events`.

const DT := 0.05
const L := 32.0
const W := 18.0
const MID := 16.0
const SIGHT := 6.5
const KNOWN_ABILITIES := ["on_hit_burn", "on_hit_poison", "on_hit_slow", "on_hit_armor_shred", "splash", "bonus_vs_slowed",
	"bonus_vs_structures", "bonus_vs_isolated", "execute", "periodic_zone", "aura_buff", "heal_ally", "repair", "build_turret",
	"teleport_strike", "disable_structure", "stealth", "stealth_aura", "decoy", "charge", "knockback_on_hit", "jump_walls",
	"thorns", "lifesteal", "root_on_hit", "reveal", "shield_allies", "damage_reduction_aura", "protect_king", "underdog_aura",
	"cleanse_aura", "energy_boost", "summon", "phase_change", "death_explosion", "rune_trap", "trap_layer", "rift",
	"stacking_on_kill", "energy_steal", "enrage", "alchemy_cycle", "armor_pierce"]

var cfg: Dictionary
var mode := "duel"
var rng := RandomNumberGenerator.new()
var ents: Array[BattleEnt] = []
var by_id := {}
var next_id := 1
var time := 0.0
var duration := 180.0
var overtime := 0.0
var finished := false
var outcome := ""                # "win", "loss", "draw"
var events: Array = []
var pending: Array = []          # delayed hits / telegraphed effects
var paused := false

var energy := [5.0, 5.0]
var energy_max := 10.0
var energy_regen := 2.8
var energy_rate_mult := [1.0, 1.0]
var hands := [[], []]
var queues := [[], []]
var deck_levels := [{}, {}]
var sides := [{}, {}]
var synergy_bonus := [{}, {}]    # family -> bonus dict
var family_bonus := [{}, {}]     # from hero relics: family -> {dmg_pct, hp_pct}
var heroes := [null, null]
var hero_respawn_t := [0.0, 0.0]
var hero_cd := [{}, {}]
var hero_charge := [0.0, 0.0]
var hero_flags := [{}, {}]
var structures_lost := [0, 0]
var structures_total := [0, 0]
var thrones := [null, null]
var bots: Array = [null, null]
var waves: Array = []
var wave_index := 0
var wave_timer := 0.0
var waves_cleared := 0
var endless := false
var wave_director: WaveDirector
var boss: BattleEnt
var stats := {"units_deployed": 0, "abilities_used": 0, "damage_dealt": 0.0, "cards_played": [0, 0]}
var no_cards := [false, false]


func _init(config: Dictionary) -> void:
	cfg = config
	mode = str(cfg.get("mode", "duel"))
	rng.seed = int(cfg.get("seed", 1))
	var bc: Dictionary = DB.battle_cfg()
	duration = float(bc.get("duration", 180))
	energy_max = float(bc.get("energy_max", 10))
	energy_regen = float(bc.get("energy_regen", 2.8))
	var start_e := float(bc.get("energy_start", 5))
	var mods: Dictionary = cfg.get("modifiers", {})
	sides = [cfg.get("player", {}), cfg.get("enemy", {})]
	for t in 2:
		energy[t] = minf(energy_max, start_e + float(sides[t].get("energy_bonus", 0.0)))
		if mods.has("energy_rate"):
			energy_rate_mult[t] = float(mods.energy_rate)
		_setup_synergies(t)
		_setup_deck(t)
	no_cards[0] = mods.get("no_cards", false)
	match mode:
		"raid":
			duration = 150.0
			_place_structures(0, false)
			_place_raid(1, str(cfg.get("layout", "raid_1")))
		"defense", "survival":
			duration = 600.0 if mode == "survival" else 420.0
			_place_structures(0, true)
			_place_defenses(0)
			waves = cfg.get("waves", [])
			endless = mode == "survival" or cfg.get("endless", false)
			wave_timer = 3.0
			wave_director = WaveDirector.new(self, str(sides[1].get("difficulty", "normal")))
		"boss":
			duration = 240.0
			_place_structures(0, true)
			_spawn_boss(str(cfg.get("boss", "boss_colosse")), int(cfg.get("boss_level", 1)))
		"training":
			duration = 150.0
			_place_structures(0, true)
			if cfg.get("training_bot", false):
				_place_structures(1, true)
			else:
				for i in 3:
					var d := _new_ent(1, "dummy")
					d.def_id = "dummy"
					d.pos = Vector2(22 + i * 2.5, 4.5 + i * 4.5)
					var dd: Dictionary = DB.campaign_json.structures.dummy
					d.max_hp = float(dd.hp)
					d.hp = d.max_hp
					d.radius = float(dd.radius)
					d.regen_pct = 2.0
					_add(d)
			energy_rate_mult[0] *= 2.0
		_:
			_place_structures(0, true)
			_place_structures(1, true)
			if mods.get("enemy_double_hp", false):
				for e in ents:
					if e.team == 1 and e.kind == "structure":
						e.max_hp *= 2.0
						e.hp = e.max_hp
	if mods.get("no_hero", false):
		sides[0]["hero"] = null
	for t in 2:
		if sides[t].get("hero") != null and not (mode in ["defense", "survival", "boss"] and t == 1):
			_spawn_hero(t)
	var has_bot: bool = (mode in ["duel", "challenge", "raid"]) or (mode == "training" and cfg.get("training_bot", false))
	if has_bot and not sides[1].get("deck", []).is_empty():
		bots[1] = BotAI.new(self, 1, str(sides[1].get("difficulty", "normal")))
	if cfg.get("autoplay", false):
		bots[0] = BotAI.new(self, 0, str(cfg.get("autoplay_difficulty", "normal")))


# ------------------------------------------------------------------ setup
func _setup_synergies(t: int) -> void:
	for s in sides[t].get("synergies", []):
		synergy_bonus[t][s.family] = s.bonus
	var hero = sides[t].get("hero")
	if hero != null:
		for e in hero.stats.get("effects", []):
			match str(e.type):
				"family_dmg":
					var fb: Dictionary = family_bonus[t].get(e.family, {})
					fb["dmg_pct"] = float(fb.get("dmg_pct", 0)) + float(e.pct)
					family_bonus[t][e.family] = fb
				"family_hp":
					var fb2: Dictionary = family_bonus[t].get(e.family, {})
					fb2["hp_pct"] = float(fb2.get("hp_pct", 0)) + float(e.pct)
					family_bonus[t][e.family] = fb2


func _setup_deck(t: int) -> void:
	var deck: Array = sides[t].get("deck", []).duplicate(true)
	for e in deck:
		deck_levels[t][e.id] = int(e.level)
	var ids: Array = []
	for e in deck:
		ids.append(e.id)
	# deterministic shuffle
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var hs := int(DB.battle_cfg().get("hand_size", 4))
	hands[t] = ids.slice(0, mini(hs, ids.size()))
	queues[t] = ids.slice(mini(hs, ids.size()))


func _new_ent(team: int, kind: String) -> BattleEnt:
	var e := BattleEnt.new()
	e.id = next_id
	next_id += 1
	e.team = team
	e.kind = kind
	return e


func _add(e: BattleEnt) -> BattleEnt:
	e.prev_pos = e.pos
	ents.append(e)
	by_id[e.id] = e
	events.append({"t": "spawn", "id": e.id})
	return e


func side_x(team: int, x: float) -> float:
	return x if team == 0 else L - x


func _structure(team: int, sub: String, p: Vector2) -> BattleEnt:
	var sd: Dictionary = DB.campaign_json.structures[sub]
	var e := _new_ent(team, "structure")
	e.sub = sub
	e.def_id = sub
	e.pos = p
	var hp_m := 1.0 + float(sides[team].get("structure_hp_pct", 0.0)) / 100.0
	var dmg_m := 1.0 + float(sides[team].get("structure_dmg_pct", 0.0)) / 100.0
	e.max_hp = float(sd.hp) * hp_m
	e.hp = e.max_hp
	e.dmg = float(sd.dmg) * dmg_m
	e.hit = float(sd.hit)
	e.reach = float(sd.range)
	e.radius = float(sd.radius)
	e.proj = float(sd.proj)
	e.can_hit_air = true
	e.armor = 20.0
	e.speed = 0.0
	structures_total[team] += 1
	if sub == "throne":
		thrones[team] = e
	return _add(e)


func _place_structures(team: int, with_towers: bool) -> void:
	_structure(team, "throne", Vector2(side_x(team, 2.6), W / 2))
	if with_towers:
		_structure(team, "tower", Vector2(side_x(team, 6.5), 4.0))
		_structure(team, "tower", Vector2(side_x(team, 6.5), W - 4.0))


func _wall(team: int, p: Vector2, hp: float) -> void:
	var e := _new_ent(team, "wall")
	e.def_id = "wall"
	e.pos = p
	e.max_hp = hp
	e.hp = hp
	e.radius = float(DB.campaign_json.structures.wall.radius)
	e.armor = 30.0
	e.speed = 0.0
	_add(e)


func _trap(team: int, p: Vector2, dmg: float, root := 0.0) -> void:
	var e := _new_ent(team, "trap")
	e.def_id = "trap"
	e.pos = p
	e.dmg = dmg
	e.radius = float(DB.campaign_json.structures.trap.radius)
	e.hp = 1
	e.max_hp = 1
	e.data = {"root": root}
	_add(e)


func _place_raid(team: int, layout_id: String) -> void:
	var lay: Dictionary = DB.campaign_json.raid_layouts.get(layout_id, DB.campaign_json.raid_layouts.raid_1)
	_structure(team, "throne", Vector2(29.5, W / 2))
	for p in lay.towers + lay.get("extra_towers", []):
		_structure(team, "tower", Vector2(float(p[0]), float(p[1])))
	var lvl_m := 1.0 + float(sides[team].get("structure_hp_pct", 0.0)) / 100.0
	for p in lay.walls:
		_wall(team, Vector2(float(p[0]), float(p[1]) + 0.5), float(DB.campaign_json.structures.wall.hp) * lvl_m)
	for p in lay.traps:
		_trap(team, Vector2(float(p[0]), float(p[1]) + 0.5), float(DB.campaign_json.structures.trap.dmg) * lvl_m)


func _place_defenses(team: int) -> void:
	var d: Dictionary = sides[team].get("defense", {})
	var segs := int(d.get("walls", 0))
	var hp := float(d.get("wall_hp", 900))
	# Wall segments protect the two tower lanes first, then the center.
	var lanes := [4.0, W - 4.0, W / 2]
	for i in segs:
		var lane: float = lanes[i % 3]
		var row := i / 3
		for k in 3:
			_wall(team, Vector2(10.0 + row * 1.2, lane - 1.1 + k * 1.1), hp)
	var traps := int(d.get("traps", 0))
	for i in traps:
		_trap(team, Vector2(12.0, [4.0, W - 4.0, W / 2, 6.5][i % 4]), float(d.get("trap_dmg", 220)))


func _spawn_boss(boss_id: String, lvl: int) -> void:
	var bd: Dictionary = DB.bosses[boss_id]
	var e := _new_ent(1, "boss")
	e.def_id = boss_id
	e.name = str(bd.name)
	var m := 1.0 + 0.08 * (lvl - 1)
	e.max_hp = float(bd.hp) * m
	e.hp = e.max_hp
	e.dmg = float(bd.dmg) * m
	e.hit = float(bd.hit)
	e.speed = float(bd.speed)
	e.radius = float(bd.radius)
	e.armor = float(bd.armor)
	e.reach = float(bd.get("range", 1.2)) + e.radius * 0.5
	e.proj = float(bd.get("proj", 0))
	e.can_hit_air = true
	e.pos = Vector2(28.0, W / 2)
	e.data = {"phases": bd.phases, "phase": 0, "armor_layer": float(bd.get("armor_layer", 0)) * m,
		"base_armor": float(bd.armor), "atk_cd": {}, "lvl_m": m, "speed_base": float(bd.speed)}
	if float(bd.get("armor_layer", 0)) > 0:
		e.armor = float(bd.armor)
	boss = e
	_add(e)


func _spawn_hero(t: int) -> void:
	var h: Dictionary = sides[t].hero
	var st: Dictionary = h.stats
	var e := _new_ent(t, "hero")
	e.def_id = "king"
	e.name = str(h.get("name", "King"))
	e.max_hp = float(st.hp)
	var syn_royal: Dictionary = synergy_bonus[t].get("royal", {})
	if syn_royal.has("king_hp_pct"):
		e.max_hp *= 1.0 + float(syn_royal.king_hp_pct) / 100.0
	e.hp = e.max_hp
	e.dmg = float(st.dmg)
	e.hit = float(st.hit)
	e.reach = float(st.range)
	e.speed = float(st.speed)
	e.armor = float(st.armor)
	e.proj = float(st.get("proj", 0))
	e.resist = float(st.get("resist", 0))
	e.ap = float(st.get("ability_power_pct", 0))
	e.radius = 0.55
	e.can_hit_air = e.proj > 0 or e.reach >= 1.5
	e.family = "royal"
	e.data = {"effects": st.get("effects", []), "abilities": h.abilities, "splash": float(st.get("splash", 0)), "cdr": float(st.get("cdr_pct", 0)),
		"last_stand_used": false}
	for ef in e.data.effects:
		if ef.type == "regen":
			e.regen_pct += float(ef.pct)
		if ef.type == "hero_lifesteal":
			e.lifesteal += float(ef.pct)
		if ef.type == "thorns":
			e.abilities.append({"type": "thorns", "pct": ef.pct})
	if h.abilities.get("passive", "") == "tyrant_blood":
		e.lifesteal += float(DB.abilities.tyrant_blood.pct)
	var home: Vector2 = thrones[t].pos if thrones[t] else Vector2(side_x(t, 2.0), W / 2)
	e.pos = home + Vector2(2.2 if t == 0 else -2.2, 0)
	heroes[t] = e
	_add(e)


# ------------------------------------------------------------------ units
func spawn_unit(t: int, uid: String, p: Vector2, lvl: int, from_card := true) -> BattleEnt:
	var d: Dictionary = DB.unit_def(uid)
	if d.is_empty():
		return null
	var st: Dictionary = d.stats
	var e := _new_ent(t, "unit")
	e.def_id = uid
	e.name = str(d.name)
	e.family = str(d.family)
	e.role = str(d.role)
	e.level = lvl
	var lm := 1.0 + float(DB.cards_json.upgrade.stat_per_level) * (lvl - 1)
	var cm := 1.0 + float(sides[t].get("card_stat_pct", 0.0)) / 100.0
	var syn: Dictionary = synergy_bonus[t].get(e.family, {})
	var fb: Dictionary = family_bonus[t].get(e.family, {})
	if e.family == "air" and synergy_bonus[t].has("air"):
		syn = synergy_bonus[t].air
	e.max_hp = float(st.hp) * lm * cm * (1.0 + (float(syn.get("hp_pct", 0)) + float(fb.get("hp_pct", 0))) / 100.0)
	e.hp = e.max_hp
	e.dmg = float(st.dmg) * lm * cm
	e.dmg_pct = float(syn.get("damage_pct", 0)) + float(fb.get("dmg_pct", 0))
	e.hit = float(st.hit)
	e.reach = float(st.range)
	e.speed = float(st.speed)
	e.speed_pct = float(syn.get("speed_pct", 0))
	e.as_pct = float(syn.get("atk_speed_pct", 0))
	e.radius = float(st.radius)
	e.proj = float(st.proj)
	e.flying = bool(st.flying)
	e.can_hit_air = bool(st.air) or e.flying
	e.targets = str(st.targets)
	e.armor = float(st.armor) + float(syn.get("armor", 0))
	e.regen_pct = float(syn.get("regen_pct", 0))
	e.ap = float(syn.get("ability_power_pct", 0))
	e.heal_pct = float(syn.get("heal_pct", 0))
	e.slow_dur_pct = float(syn.get("slow_dur_pct", 0))
	e.poison_pct = float(syn.get("poison_pct", 0))
	e.abilities = d.get("abilities", []).duplicate(true)
	e.pos = clamp_pos(p)
	e.deploy_t = 0.8 if from_card else 0.3
	if float(d.get("life", 0)) > 0:
		e.life = float(d.life)
	for a in e.abilities:
		match str(a.type):
			"lifesteal":
				e.lifesteal += float(a.pct)
			"stealth":
				e.stealth_t = float(a.dur)
				e.timers["stealth"] = float(a.cooldown)
			"summon":
				e.timers["summon"] = 0.9 if a.get("on_deploy", false) else float(a.cooldown)
			"rift":
				_spawn_rift(e, a)
	_add(e)
	return e


func clamp_pos(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.5, L - 0.5), clampf(p.y, 0.5, W - 0.5))


func deploy_zone(t: int) -> Rect2:
	if mode == "raid" and t == 0:
		return Rect2(0.5, 0.5, 13.0, W - 1.0)
	if t == 0:
		return Rect2(0.5, 0.5, MID - 1.0, W - 1.0)
	return Rect2(MID + 0.5, 0.5, MID - 1.0, W - 1.0)


func can_play(t: int, hand_index: int, p: Vector2) -> String:
	if finished:
		return "ERR_FINISHED"
	if no_cards[t]:
		return "ERR_NO_CARDS"
	if hand_index < 0 or hand_index >= hands[t].size():
		return "ERR_CARD"
	var cid: String = hands[t][hand_index]
	if energy[t] < float(DB.cards[cid].cost):
		return "ERR_ENERGY"
	if not deploy_zone(t).has_point(p):
		return "ERR_ZONE"
	return ""


func play_card(t: int, hand_index: int, p: Vector2) -> bool:
	if can_play(t, hand_index, p) != "":
		return false
	var cid: String = hands[t][hand_index]
	var d: Dictionary = DB.cards[cid]
	energy[t] -= float(d.cost)
	var n := int(d.stats.count)
	for i in n:
		var off := Vector2.ZERO
		if n > 1:
			off = Vector2(cos(i * TAU / n), sin(i * TAU / n)) * 0.55
		spawn_unit(t, cid, p + off, int(deck_levels[t].get(cid, 1)))
	if t == 0:
		stats.units_deployed += n
	stats.cards_played[t] += 1
	# cycle: played card goes to the back of the queue
	hands[t].remove_at(hand_index)
	queues[t].append(cid)
	if not queues[t].is_empty():
		hands[t].insert(hand_index, queues[t].pop_front())
	events.append({"t": "deploy", "team": t, "card": cid, "pos": p})
	return true


func next_card(t: int) -> String:
	return queues[t][0] if not queues[t].is_empty() else ""


# ------------------------------------------------------------------ main loop
func step() -> void:
	if finished or paused:
		return
	time += DT
	for e in ents:
		e.prev_pos = e.pos
	_energy_tick()
	_aura_pass()
	_status_tick()
	_resolve_pending()
	for i in range(ents.size()):
		var e: BattleEnt = ents[i]
		if not e.alive:
			continue
		if e.life > 0:
			e.life -= DT
			if e.life <= 0:
				_kill(e, null)
				continue
		if e.deploy_t > 0:
			e.deploy_t -= DT
			continue
		match e.kind:
			"unit", "hero", "boss":
				_unit_tick(e)
			"structure", "turret":
				if e.disabled_t > 0:
					e.disabled_t -= DT
				else:
					_static_attack_tick(e)
			"trap", "rune":
				_trap_tick(e)
			"rift":
				_rift_tick(e)
			"dummy":
				pass
	_hero_tick()
	if boss and boss.alive:
		_boss_tick(boss)
	if wave_director:
		_waves_tick()
	for b in bots:
		if b:
			b.update(DT)
	_cleanup()
	_check_end()


func _energy_tick() -> void:
	var ot := 2.0 if time > duration - 60.0 and mode in ["duel", "challenge"] else 1.0
	for t in 2:
		var boost := 0.0
		for e in ents:
			if e.alive and e.team == t and e.kind == "unit" and e.has_ability("energy_boost"):
				boost += float(e.ability("energy_boost").pct)
		energy[t] = minf(energy_max, energy[t] + DT / energy_regen * energy_rate_mult[t] * ot * (1.0 + boost / 100.0))


func _aura_pass() -> void:
	var counts := [0, 0]
	for e in ents:
		e.a_dmg = 0.0
		e.a_as = 0.0
		e.a_armor = 0.0
		e.a_speed = 0.0
		e.a_ap = 0.0
		e.a_dr = 0.0
		e.a_cleanse = 0.0
		e.protector = null
		if e.alive and e.kind in ["unit", "hero"]:
			counts[e.team] += 1
	for src in ents:
		if not src.alive or src.deploy_t > 0:
			continue
		for a in src.abilities:
			match str(a.type):
				"aura_buff", "damage_reduction_aura", "protect_king", "underdog_aura", "cleanse_aura":
					_apply_aura(src, a, counts)
		if src.kind == "hero":
			if src.data.abilities.get("passive", "") == "royal_presence":
				_apply_aura(src, {"type": "aura_buff", "stat": "armor", "flat": DB.abilities.royal_presence.armor, "radius": DB.abilities.royal_presence.radius}, counts)
			for ef in src.data.effects:
				if ef.type == "ally_aura":
					_apply_aura(src, {"type": "aura_buff", "stat": ef.stat, "pct": ef.pct, "radius": ef.radius}, counts)


func _apply_aura(src: BattleEnt, a: Dictionary, counts: Array) -> void:
	var r := float(a.get("radius", 4.0))
	var amp := 1.0 + (src.ap + src.a_ap) / 100.0
	for e in ents:
		if not e.alive or e.team != src.team or not e.kind in ["unit", "hero"]:
			continue
		if e.pos.distance_to(src.pos) > r:
			continue
		match str(a.type):
			"aura_buff":
				if a.has("family") and e.family != a.family:
					continue
				if a.get("filter", "") == "synergy" and not synergy_bonus[src.team].has(e.family):
					continue
				var pct := float(a.get("pct", 0)) * (amp if e != src else 1.0)
				match str(a.stat):
					"damage": e.a_dmg += pct
					"attack_speed": e.a_as += pct
					"speed": e.a_speed += pct
					"ability_power":
						if e != src:
							e.a_ap += pct
					"armor": e.a_armor += float(a.get("flat", 0))
			"damage_reduction_aura":
				e.a_dr = maxf(e.a_dr, float(a.pct))
			"protect_king":
				if e.kind == "hero" and e.protector == null:
					e.protector = src
			"underdog_aura":
				if counts[src.team] < counts[1 - src.team]:
					e.a_dmg += float(a.pct)
			"cleanse_aura":
				e.a_cleanse = maxf(e.a_cleanse, float(a.pct))


func _status_tick() -> void:
	for e in ents:
		if not e.alive:
			continue
		if e.regen_pct > 0 and e.hp < e.max_hp:
			e.hp = minf(e.max_hp, e.hp + e.max_hp * e.regen_pct / 100.0 * DT)
		if e.stealth_t > 0:
			e.stealth_t -= DT
		if e.shield_t > 0:
			e.shield_t -= DT
			if e.shield_t <= 0:
				e.shield = 0.0
		var rm: Array = []
		for k in e.statuses.keys():
			var s: Dictionary = e.statuses[k]
			s.t = float(s.t) - DT
			if k == "burn":
				_damage(by_id.get(int(s.get("src", 0))), e, float(s.v) * DT, "dot")
			elif k == "poison":
				_damage(by_id.get(int(s.get("src", 0))), e, float(s.v) * float(s.get("stacks", 1)) * DT, "dot")
			if float(s.t) <= 0:
				rm.append(k)
		for k in rm:
			e.statuses.erase(k)
			if k == "fury":
				events.append({"t": "fury_end", "id": e.id})


func apply_status(e: BattleEnt, key: String, v: float, dur: float, src: BattleEnt = null) -> void:
	if not e.alive or e.is_static() and key in ["slow", "root", "stun", "timewarp"]:
		return
	if e.kind == "boss" and key in ["stun", "root"] and dur > 1.0:
		dur = 1.0
	if src and src.team != e.team:
		dur *= 1.0 - e.a_cleanse / 100.0
		if key == "slow" and src.slow_dur_pct > 0:
			dur *= 1.0 + src.slow_dur_pct / 100.0
	if key == "poison":
		var cur: Dictionary = e.statuses.get("poison", {})
		var stacks := mini(3, int(cur.get("stacks", 0)) + 1)
		e.statuses["poison"] = {"v": v, "t": dur, "stacks": stacks, "src": src.id if src else 0}
	else:
		var old: Dictionary = e.statuses.get(key, {})
		if old.is_empty() or float(old.v) <= v or float(old.t) < dur:
			e.statuses[key] = {"v": maxf(v, float(old.get("v", 0))), "t": maxf(dur, float(old.get("t", 0))), "src": src.id if src else 0}
	events.append({"t": "status", "id": e.id, "status": key})


func _resolve_pending() -> void:
	var keep: Array = []
	for p in pending:
		if time < float(p.at):
			keep.append(p)
			continue
		match str(p.kind):
			"hit":
				var src: BattleEnt = by_id.get(int(p.src))
				var tgt: BattleEnt = by_id.get(int(p.tgt))
				if tgt and tgt.alive:
					_on_hit(src, tgt, float(p.amount), p.get("opts", {}))
			"aoe":
				_aoe(p)
	pending = keep


func _aoe(p: Dictionary) -> void:
	var src: BattleEnt = by_id.get(int(p.get("src", 0)))
	var team := int(p.team)
	var c: Vector2 = p.pos
	events.append({"t": "explosion", "pos": c, "radius": float(p.radius), "color": p.get("color", "#ff7030")})
	for e in ents.duplicate():
		if not e.alive or e.team == team or not e.targetable():
			continue
		var hit_it := false
		if p.get("shape", "circle") == "line":
			var a: Vector2 = p.from
			var b: Vector2 = p.to
			var closest := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
			hit_it = closest.distance_to(e.pos) <= float(p.width) * 0.5 + e.radius
		else:
			hit_it = e.pos.distance_to(c) <= float(p.radius) + e.radius
		if hit_it:
			_damage(src, e, float(p.dmg), "ability")
			if p.has("force") and not e.is_static():
				knockback(e, c, float(p.force))
			if p.has("stun"):
				apply_status(e, "stun", 1.0, float(p.stun), src)
	if src and src.kind == "boss" and p.get("exhaust", false):
		src.statuses["exhausted"] = {"v": 50.0, "t": 2.5}
		events.append({"t": "exhausted", "id": src.id})


# ------------------------------------------------------------------ targeting
func is_visible_to(e: BattleEnt, viewer_team: int, viewer_pos := Vector2(-999, -999)) -> bool:
	if e.team == viewer_team:
		return true
	if e.kind in ["trap", "rune"]:
		return revealed(e, viewer_team)
	if e.stealth_t > 0:
		if viewer_pos.x > -900 and viewer_pos.distance_to(e.pos) < 1.3:
			return true
		return revealed(e, viewer_team)
	return true


func revealed(e: BattleEnt, by_team: int) -> bool:
	for r in ents:
		if not r.alive or r.team != by_team:
			continue
		var rad := 0.0
		if r.has_ability("reveal"):
			rad = float(r.ability("reveal").radius)
		if r.kind == "hero":
			for ef in r.data.effects:
				if ef.type == "reveal":
					rad = maxf(rad, float(ef.radius))
		if rad > 0 and r.pos.distance_to(e.pos) <= rad:
			return true
	return false


func can_target(a: BattleEnt, b: BattleEnt) -> bool:
	if not b.targetable() or b.team == a.team:
		return false
	if b.flying and not a.can_hit_air:
		return false
	if a.targets == "structures" and not b.kind in ["structure", "wall", "turret"]:
		return false
	if b.kind == "wall" and a.targets != "structures" and a.kind != "boss":
		return false  # walls are only attacked when they block the way
	if not is_visible_to(b, a.team, a.pos):
		return false
	return true


func _find_target(e: BattleEnt) -> BattleEnt:
	var best: BattleEnt = null
	var best_d := INF
	var sight := maxf(SIGHT, e.reach + 1.0)
	# Decoys taunt nearby enemies
	for o in ents:
		if o.alive and o.kind == "decoy" and o.team != e.team and o.pos.distance_to(e.pos) < 5.0 and can_target(e, o):
			return o
	for o in ents:
		if not can_target(e, o) or o.kind == "wall":
			continue
		var d := e.pos.distance_to(o.pos) - o.radius
		if e.targets != "structures" and d > sight and not o.kind in ["structure", "boss", "dummy"]:
			continue
		if e.kind == "hero" and d > sight:
			continue  # the King only engages what is near; the player moves him
		# Prefer units over buildings when they are in sight
		var bias := 0.0 if not o.kind in ["structure", "turret"] else 2.5
		if e.targets == "structures":
			bias = 0.0
		if d + bias < best_d:
			best_d = d + bias
			best = o
	return best


# ------------------------------------------------------------------ unit behaviour
func eff_speed(e: BattleEnt) -> float:
	var s := e.speed * (1.0 + (e.speed_pct + e.a_speed) / 100.0)
	s *= 1.0 - e.status_v("slow") / 100.0
	s *= 1.0 - e.status_v("timewarp") / 100.0
	if e.has_status("fury"):
		s *= 1.0 + float(e.statuses.fury.get("speed", 0)) / 100.0
	if e.kind == "unit" and e.has_ability("phase_change") and e.phase_triggered:
		s *= 1.0 + float(e.ability("phase_change").speed_pct) / 100.0
	return maxf(0.0, s)


func eff_hit(e: BattleEnt) -> float:
	var asp := e.as_pct + e.a_as + e.status_v("buff_as")
	if e.kind == "unit" and e.has_ability("phase_change") and e.phase_triggered:
		asp += float(e.ability("phase_change").atk_pct)
	var h := e.hit / (1.0 + asp / 100.0)
	h *= 1.0 + e.status_v("timewarp") / 100.0
	return maxf(0.2, h)


func _unit_tick(e: BattleEnt) -> void:
	_abilities_tick(e)
	if not e.alive:
		return
	if e.has_status("stun") or e.has_status("exhausted"):
		return
	e.cooldown -= DT
	# Hero move orders override auto-targeting until reached.
	if e.kind == "hero" and e.order_pos != null:
		var op: Vector2 = e.order_pos
		if e.pos.distance_to(op) < 0.35:
			e.order_pos = null
		else:
			_move_towards(e, op, 0.0)
			return
	e.retarget_t -= DT
	if e.target == null or not e.target.alive or e.retarget_t <= 0 or not can_target(e, e.target) and e.target.kind != "wall":
		e.target = _find_target(e)
		e.retarget_t = 0.5
	if e.target == null:
		if e.kind == "hero" or (e.team == 0 and mode in ["defense", "survival", "boss"]):
			return
		# Nothing to fight: walk toward the enemy side.
		_move_towards(e, Vector2(side_x(e.team, L - 3.0), e.pos.y), 0.0)
		return
	var t := e.target
	var d := e.pos.distance_to(t.pos) - e.radius - t.radius
	if d <= e.reach:
		e.facing = (t.pos - e.pos).normalized()
		if e.cooldown <= 0:
			_attack(e, t)
			e.cooldown = eff_hit(e)
	else:
		if e.has_status("root"):
			return
		_move_towards(e, t.pos, e.reach + e.radius + t.radius - 0.05)


func _move_towards(e: BattleEnt, dest: Vector2, stop_dist: float) -> void:
	if e.has_status("root") or e.has_status("stun"):
		return
	var to := dest - e.pos
	var dist := to.length()
	if dist <= stop_dist + 0.01:
		return
	var dir := to / dist
	var sp := eff_speed(e) * DT
	var step_v := dir * minf(sp, dist - stop_dist)
	# Separation from allies (ground only)
	if not e.flying:
		var push := Vector2.ZERO
		for o in ents:
			if o == e or not o.alive or o.flying or o.team != e.team or not o.kind in ["unit", "hero", "boss"]:
				continue
			var dv := e.pos - o.pos
			var dl := dv.length()
			var md := e.radius + o.radius
			if dl < md and dl > 0.001:
				push += dv / dl * (md - dl)
		step_v += push * 0.5
	var np := clamp_pos(e.pos + step_v)
	# Walls block ground units (except jumpers): attack the wall instead.
	if not e.flying and not e.has_ability("jump_walls"):
		for w in ents:
			if w.alive and w.kind == "wall" and w.team != e.team and np.distance_to(w.pos) < w.radius + e.radius:
				e.target = w
				e.retarget_t = 1.5
				return
	e.moved += e.pos.distance_to(np)
	e.facing = dir
	e.pos = np


func _static_attack_tick(e: BattleEnt) -> void:
	e.cooldown -= DT
	if e.cooldown > 0:
		return
	var best: BattleEnt = null
	var bd := INF
	for o in ents:
		if not can_target(e, o) or o.kind in ["wall", "structure"]:
			continue
		var d := e.pos.distance_to(o.pos) - o.radius
		if d <= e.reach and d < bd:
			bd = d
			best = o
	if best:
		e.facing = (best.pos - e.pos).normalized()
		_attack(e, best)
		e.cooldown = eff_hit(e)


func _attack(e: BattleEnt, t: BattleEnt) -> void:
	var amount := e.dmg
	var opts := {"attack": true}
	e.hits_done += 1
	if e.stealth_t > 0 and e.kind == "unit":
		e.stealth_t = minf(e.stealth_t, 0.3)  # attacking reveals the unit shortly after
	if e.kind == "hero":
		for ef in e.data.effects:
			if ef.type == "heavy_every" and e.hits_done % int(ef.n) == 0:
				amount *= float(ef.mult)
				opts["stun"] = float(ef.stun)
				opts["heavy"] = true
			if ef.type == "hero_root_every" and e.hits_done % int(ef.n) == 0:
				opts["root"] = float(ef.dur)
	if e.has_ability("charge"):
		var ch := e.ability("charge")
		if e.moved >= float(ch.min_dist):
			amount *= float(ch.mult)
			opts["force"] = float(ch.force)
			events.append({"t": "text", "pos": e.pos, "text": "CHARGE!"})
	e.moved = 0.0
	if e.proj > 0:
		var travel := e.pos.distance_to(t.pos) / e.proj
		pending.append({"kind": "hit", "at": time + travel, "src": e.id, "tgt": t.id, "amount": amount, "opts": opts})
		events.append({"t": "attack", "id": e.id, "target": t.id, "proj": true, "travel": travel})
	else:
		events.append({"t": "attack", "id": e.id, "target": t.id, "proj": false})
		_on_hit(e, t, amount, opts)


## Applies an attack hit with all on-hit abilities.
func _on_hit(src: BattleEnt, t: BattleEnt, amount: float, opts: Dictionary) -> void:
	if src == null or not src.alive:
		_damage(src, t, amount, "attack")
		return
	var mult := 1.0
	var pierce := 0.0
	for a in src.abilities:
		match str(a.type):
			"bonus_vs_slowed":
				if t.has_status("slow") or t.has_status("timewarp") or t.has_status("root"):
					mult *= float(a.mult)
			"bonus_vs_structures":
				if t.is_structure():
					mult *= float(a.mult)
			"bonus_vs_isolated":
				if _is_isolated(t, float(a.radius)):
					mult *= float(a.mult)
			"execute":
				if t.hp_frac() < float(a.threshold) and not t.is_structure():
					mult *= float(a.mult)
			"armor_pierce":
				pierce = float(a.pct)
			"enrage":
				mult *= 1.0 + float(a.max_pct) / 100.0 * (1.0 - src.hp_frac())
	if src.kind == "hero":
		for ef in src.data.effects:
			match str(ef.type):
				"bonus_vs_isolated":
					if _is_isolated(t, 2.5):
						mult *= float(ef.mult)
				"bonus_vs_structures":
					if t.is_structure():
						mult *= float(ef.mult)
	var stack_kill: Dictionary = src.ability("stacking_on_kill")
	if not stack_kill.is_empty():
		mult *= 1.0 + float(stack_kill.pct) * src.kills / 100.0
	var dealt := _damage(src, t, amount * mult, "attack", pierce)
	_on_hit_effects(src, t, dealt, opts)
	# Splash
	var splash_r := 0.0
	var splash_pct := 0.0
	var sp: Dictionary = src.ability("splash")
	if not sp.is_empty():
		splash_r = float(sp.radius)
		splash_pct = float(sp.pct)
	if src.kind == "hero":
		if float(src.data.get("splash", 0)) > 0:
			splash_r = maxf(splash_r, float(src.data.splash))
			splash_pct = maxf(splash_pct, 0.5)
		for ef in src.data.effects:
			if ef.type == "hero_splash":
				splash_r = maxf(splash_r, float(ef.radius))
				splash_pct = maxf(splash_pct, float(ef.pct))
	var alch: Dictionary = src.ability("alchemy_cycle")
	if not alch.is_empty():
		splash_r = maxf(splash_r, float(alch.radius))
		splash_pct = maxf(splash_pct, 0.5)
	if splash_r > 0:
		for o in ents.duplicate():
			if o == t or not o.alive or o.team == src.team or not o.targetable():
				continue
			if o.flying and not src.can_hit_air:
				continue
			if o.pos.distance_to(t.pos) <= splash_r + o.radius:
				var d2 := _damage(src, o, amount * mult * splash_pct, "attack", pierce)
				_on_hit_effects(src, o, d2, {})
		events.append({"t": "splash", "pos": t.pos, "radius": splash_r, "family": src.family})


func _on_hit_effects(src: BattleEnt, t: BattleEnt, dealt: float, opts: Dictionary) -> void:
	if not t.alive and not t.is_structure():
		pass
	var amp := 1.0 + (src.ap + src.a_ap) / 100.0
	for a in src.abilities:
		match str(a.type):
			"on_hit_burn":
				var m := float(a.get("structure_mult", 1.0)) if t.is_structure() else 1.0
				apply_status(t, "burn", float(a.dps) * amp * m, float(a.dur), src)
			"on_hit_poison":
				apply_status(t, "poison", float(a.dps) * amp * (1.0 + src.poison_pct / 100.0), float(a.dur), src)
			"on_hit_slow":
				apply_status(t, "slow", float(a.pct), float(a.dur), src)
			"on_hit_armor_shred":
				apply_status(t, "shred", float(a.amount), float(a.dur), src)
			"knockback_on_hit":
				knockback(t, src.pos, float(a.force))
			"root_on_hit":
				if float(src.timers.get("root", 0.0)) <= 0.0:
					apply_status(t, "root", float(a.dur), float(a.dur), src)
					src.timers["root"] = float(a.cooldown)
			"disable_structure":
				if t.is_structure() and float(src.timers.get("disable", 0.0)) <= 0.0:
					t.disabled_t = float(a.dur)
					src.timers["disable"] = float(a.cooldown)
					events.append({"t": "disabled", "id": t.id, "dur": float(a.dur)})
			"energy_steal":
				if t.is_structure():
					var stolen := minf(float(a.amount), energy[t.team])
					energy[t.team] -= stolen
					energy[src.team] = minf(energy_max, energy[src.team] + stolen)
			"alchemy_cycle":
				var n := src.hits_done % 3
				if n == 1:
					apply_status(t, "poison", 15.0 * amp, 3.0, src)
				elif n == 2:
					apply_status(t, "slow", 30.0, 2.0, src)
				else:
					apply_status(t, "shred", 15.0, 3.0, src)
	if opts.has("force"):
		knockback(t, src.pos, float(opts.force))
	if opts.has("stun"):
		apply_status(t, "stun", float(opts.stun), float(opts.stun), src)
	if opts.has("root"):
		apply_status(t, "root", float(opts.root), float(opts.root), src)
	if src.kind == "hero":
		for ef in src.data.effects:
			if ef.type == "hero_on_hit":
				if ef.effect == "burn":
					apply_status(t, "burn", float(ef.dps) * amp, float(ef.dur), src)
				elif ef.effect == "slow":
					apply_status(t, "slow", float(ef.pct), float(ef.dur), src)


func _is_isolated(t: BattleEnt, r: float) -> bool:
	for o in ents:
		if o != t and o.alive and o.team == t.team and o.kind in ["unit", "hero"] and o.pos.distance_to(t.pos) <= r:
			return false
	return true


func knockback(t: BattleEnt, from: Vector2, force: float) -> void:
	if t.is_static() or t.kind == "boss" or not t.alive:
		return
	var dir := (t.pos - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(1 if t.team == 1 else -1, 0)
	t.pos = clamp_pos(t.pos + dir * force)
	events.append({"t": "knockback", "id": t.id})


## Core damage function. Returns damage actually applied to HP+shield.
func _damage(src: BattleEnt, t: BattleEnt, amount: float, kind: String, pierce := 0.0) -> float:
	if t == null or not t.alive or amount <= 0 or t.kind in ["trap", "rune", "rift"]:
		return 0.0
	var a := amount
	if src:
		var dm := 1.0 + (src.dmg_pct + src.a_dmg + src.status_v("buff_dmg")) / 100.0
		if src.has_status("fury"):
			dm += float(src.statuses.fury.get("dmg", 0)) / 100.0
		if src.kind == "unit" and src.has_ability("phase_change") and src.phase_triggered:
			dm += float(src.ability("phase_change").damage_pct) / 100.0
		if src.kind == "boss":
			dm *= float(_boss_phase(src).get("dmg_mult", 1.0))
		a *= dm
	# Garde du trône redirects part of the hero's damage
	if t.kind == "hero" and t.protector and t.protector.alive and t.protector != src:
		var pct := float(t.protector.ability("protect_king").get("pct", 40)) / 100.0
		var redirected := a * pct
		a -= redirected
		_damage(src, t.protector, redirected, kind)
	var armor := maxf(0.0, t.armor + t.a_armor + t.status_v("buff_armor") - t.status_v("shred")) * (1.0 - pierce / 100.0)
	if kind != "dot":
		a *= 100.0 / (100.0 + armor)
	if kind in ["dot", "ability"] and t.resist != 0:
		a *= 1.0 - clampf(t.resist, -50, 80) / 100.0
	a *= 1.0 - t.a_dr / 100.0
	if t.has_status("exhausted"):
		a *= 1.5
	# Boss armor plates absorb damage first
	if t.kind == "boss" and float(t.data.get("armor_layer", 0)) > 0:
		var layer := float(t.data.armor_layer)
		var absorbed := minf(layer, a)
		t.data.armor_layer = layer - absorbed
		a -= absorbed
		if float(t.data.armor_layer) <= 0:
			t.armor = 0.0
			t.statuses["exhausted"] = {"v": 50, "t": 4.0}
			t.statuses["stun"] = {"v": 1, "t": 4.0}
			events.append({"t": "armor_broken", "id": t.id})
		events.append({"t": "hit", "id": t.id, "amount": absorbed, "kind": "armor"})
	if t.shield > 0 and a > 0:
		var s := minf(t.shield, a)
		t.shield -= s
		a -= s
	var dealt := minf(t.hp, a)
	t.hp -= a
	if src:
		src.damage_dealt += dealt
		t.last_attacker = src.id
		if src.team == 0:
			stats.damage_dealt += dealt
		if src.lifesteal > 0 and kind == "attack":
			src.hp = minf(src.max_hp, src.hp + dealt * src.lifesteal / 100.0)
		if src.has_status("fury"):
			src.hp = minf(src.max_hp, src.hp + dealt * float(src.statuses.fury.get("lifesteal", 0)) / 100.0)
		if src.kind == "hero":
			hero_charge[src.team] = minf(100.0, hero_charge[src.team] + dealt * float(DB.battle_cfg().get("ultimate_charge_per_dmg", 0.02)))
		# Thorns reflect melee damage
		if kind == "attack" and src.proj <= 0 and src.alive and t.has_ability("thorns"):
			_damage(null, src, dealt * float(t.ability("thorns").pct) / 100.0, "reflect")
	if amount > 0:
		events.append({"t": "hit", "id": t.id, "amount": a, "kind": kind})
	if t.kind == "hero" and t.alive:
		for ef in t.data.effects:
			if ef.type == "last_stand_explosion" and not t.data.last_stand_used and t.hp > 0 and t.hp_frac() < float(ef.threshold):
				t.data.last_stand_used = true
				pending.append({"kind": "aoe", "at": time, "team": t.team, "pos": t.pos, "radius": float(ef.radius), "dmg": float(ef.dmg), "src": t.id, "color": "#ff3d6e"})
	if t.kind == "unit" and t.has_ability("phase_change") and not t.phase_triggered and t.hp_frac() < float(t.ability("phase_change").threshold):
		t.phase_triggered = true
		events.append({"t": "phase", "id": t.id})
	if t.hp <= 0:
		_kill(t, src)
	return dealt


func heal(t: BattleEnt, amount: float, src: BattleEnt = null) -> void:
	if not t.alive or t.hp >= t.max_hp:
		return
	var a := minf(amount, t.max_hp - t.hp)
	t.hp += a
	events.append({"t": "heal", "id": t.id, "amount": a, "src": src.id if src else 0})


func give_shield(t: BattleEnt, amount: float, dur: float) -> void:
	t.shield = maxf(t.shield, amount)
	t.shield_t = maxf(t.shield_t, dur)
	events.append({"t": "shield", "id": t.id})


func _kill(e: BattleEnt, killer: BattleEnt) -> void:
	if not e.alive:
		return
	e.alive = false
	e.hp = 0
	events.append({"t": "die", "id": e.id})
	if killer and killer.alive:
		killer.kills += 1
	if e.has_ability("death_explosion"):
		var a := e.ability("death_explosion")
		pending.append({"kind": "aoe", "at": time, "team": e.team, "pos": e.pos, "radius": float(a.radius), "dmg": float(a.dmg) * (1.0 + 0.1 * (e.level - 1)), "src": 0, "color": "#ff9030"})
	if e.kind == "structure":
		structures_lost[e.team] += 1
		events.append({"t": "structure_destroyed", "id": e.id, "team": e.team, "sub": e.sub})
	if e.kind == "hero":
		hero_respawn_t[e.team] = float(DB.battle_cfg().get("hero_respawn", 12.0))
		events.append({"t": "hero_down", "team": e.team})


func _cleanup() -> void:
	var keep: Array[BattleEnt] = []
	for e in ents:
		if e.alive:
			keep.append(e)
		else:
			by_id.erase(e.id)
			if e.target:
				e.target = null
	ents = keep


# ------------------------------------------------------------------ abilities
func _tick_timer(e: BattleEnt, key: String) -> bool:
	var v := float(e.timers.get(key, 0.0)) - DT
	e.timers[key] = v
	return v <= 0.0


func _abilities_tick(e: BattleEnt) -> void:
	if e.has_status("stun"):
		return
	var amp := 1.0 + (e.ap + e.a_ap) / 100.0
	if e.timers.has("root"):
		e.timers.root = float(e.timers.root) - DT
	if e.timers.has("disable"):
		e.timers.disable = float(e.timers.disable) - DT
	for a in e.abilities:
		match str(a.type):
			"periodic_zone":
				if _tick_timer(e, "zone"):
					e.timers.zone = float(a.interval)
					_zone_effect(e, a, amp)
			"heal_ally":
				if _tick_timer(e, "heal"):
					e.timers.heal = float(a.interval)
					var best: BattleEnt = null
					for o in ents:
						if o.alive and o.team == e.team and o.kind in ["unit", "hero"] and o.hp < o.max_hp and o.pos.distance_to(e.pos) <= float(a.range):
							if best == null or o.hp_frac() < best.hp_frac():
								best = o
					if best:
						heal(best, float(a.amount) * amp * (1.0 + e.heal_pct / 100.0), e)
			"repair":
				if _tick_timer(e, "repair"):
					e.timers.repair = float(a.interval)
					var best2: BattleEnt = null
					for o in ents:
						if not o.alive or o.team != e.team or o.hp >= o.max_hp or o.pos.distance_to(e.pos) > float(a.range):
							continue
						var ok: bool = o.is_structure() or (a.filter == "mech_or_structure" and o.family == "mech" and o.kind == "unit")
						if ok and (best2 == null or o.hp_frac() < best2.hp_frac()):
							best2 = o
					if best2:
						heal(best2, float(a.amount) * amp * (1.0 + e.heal_pct / 100.0), e)
			"build_turret":
				if _tick_timer(e, "turret"):
					e.timers.turret = float(a.cooldown)
					var tu := _new_ent(e.team, "turret")
					tu.def_id = "turret"
					tu.pos = clamp_pos(e.pos + Vector2(-0.9 if e.team == 0 else 0.9, 0.6))
					tu.max_hp = float(a.hp) * (1.0 + 0.1 * (e.level - 1))
					tu.hp = tu.max_hp
					tu.dmg = float(a.dmg) * (1.0 + 0.1 * (e.level - 1)) * amp
					tu.hit = float(a.hit)
					tu.reach = float(a.range)
					tu.proj = 14.0
					tu.radius = 0.4
					tu.can_hit_air = true
					tu.life = float(a.life)
					tu.family = "mech"
					_add(tu)
			"teleport_strike":
				if float(e.timers.get("tp", 0.0)) > 0:
					e.timers.tp = float(e.timers.tp) - DT
				elif e.target and e.target.alive and not e.target.is_structure():
					var d := e.pos.distance_to(e.target.pos)
					if d > e.reach + 1.5 and d <= float(a.range):
						var from := e.pos
						e.pos = clamp_pos(e.target.pos - (e.target.pos - e.pos).normalized() * (e.target.radius + e.radius))
						e.prev_pos = e.pos
						events.append({"t": "teleport", "id": e.id, "from": from, "to": e.pos})
						_on_hit(e, e.target, e.dmg * float(a.mult), {})
						e.timers.tp = float(a.cooldown)
			"stealth":
				if _tick_timer(e, "stealth"):
					e.timers.stealth = float(a.cooldown)
					e.stealth_t = float(a.dur)
					events.append({"t": "stealth", "id": e.id})
			"stealth_aura":
				if _tick_timer(e, "stealth_aura"):
					e.timers.stealth_aura = float(a.cooldown)
					for o in ents:
						if o.alive and o.team == e.team and o.kind == "unit" and o.pos.distance_to(e.pos) <= float(a.radius):
							o.stealth_t = maxf(o.stealth_t, float(a.dur))
							events.append({"t": "stealth", "id": o.id})
			"decoy":
				if _tick_timer(e, "decoy"):
					e.timers.decoy = float(a.cooldown)
					var dc := _new_ent(e.team, "decoy")
					dc.def_id = e.def_id
					dc.name = e.name
					dc.family = e.family
					dc.pos = clamp_pos(e.pos + Vector2(1.2 if e.team == 0 else -1.2, rng.randf_range(-1, 1)))
					dc.max_hp = float(a.hp) * amp
					dc.hp = dc.max_hp
					dc.radius = e.radius
					dc.life = float(a.life)
					dc.speed = 0
					_add(dc)
			"shield_allies":
				if _tick_timer(e, "shield"):
					e.timers.shield = float(a.cooldown)
					for o in ents:
						if not o.alive or o.team != e.team or not o.kind in ["unit", "hero"] or o.pos.distance_to(e.pos) > float(a.radius):
							continue
						if a.get("filter", "") == "flying" and not o.flying:
							continue
						give_shield(o, float(a.amount) * amp * (1.0 + e.heal_pct / 100.0), 6.0)
			"summon":
				if _tick_timer(e, "summon"):
					e.timers.summon = float(a.cooldown)
					for i in int(a.count):
						var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
						spawn_unit(e.team, str(a.unit), e.pos + off, e.level, false)
					events.append({"t": "summon", "id": e.id})
			"rune_trap", "trap_layer":
				if _tick_timer(e, "rune"):
					e.timers.rune = float(a.cooldown)
					var r := _new_ent(e.team, "rune" if a.type == "rune_trap" else "trap")
					r.def_id = a.type
					var fwd := Vector2(1 if e.team == 0 else -1, 0)
					r.pos = clamp_pos(e.pos + fwd * 2.0 + Vector2(0, rng.randf_range(-1.5, 1.5)))
					r.dmg = float(a.get("dmg", 100)) * amp
					r.radius = float(a.get("radius", 1.2))
					r.life = 20.0
					r.hp = 1
					r.max_hp = 1
					r.data = {"root": float(a.get("root", 0.0))}
					_add(r)
	if e.kind == "unit" and e.regen_pct <= 0 and e.has_ability("phase_change") and e.phase_triggered:
		pass


func _zone_effect(e: BattleEnt, a: Dictionary, amp: float) -> void:
	var r := float(a.radius)
	var eff := str(a.effect)
	var c := e.pos
	if e.target and e.target.alive and e.pos.distance_to(e.target.pos) < e.reach + 2.0:
		c = e.target.pos if eff != "poison" else e.pos
	var color := {"slow": "#7fd8ff", "damage_slow": "#bfe8ff", "poison": "#7bdc3a", "poison_slow": "#9be06a", "timewarp": "#4aa3ff"}.get(eff, "#ffffff")
	events.append({"t": "zone", "pos": c, "radius": r, "color": color, "id": e.id})
	for o in ents.duplicate():
		if not o.alive or o.team == e.team or not o.targetable() or o.pos.distance_to(c) > r + o.radius:
			continue
		match eff:
			"slow":
				apply_status(o, "slow", float(a.amount), float(a.dur), e)
			"damage_slow":
				_damage(e, o, float(a.amount) * amp, "ability")
				apply_status(o, "slow", float(a.get("pct", 40)), float(a.dur), e)
			"poison":
				apply_status(o, "poison", float(a.amount) * amp * (1.0 + e.poison_pct / 100.0), float(a.dur), e)
			"poison_slow":
				apply_status(o, "poison", float(a.amount) * amp * (1.0 + e.poison_pct / 100.0), float(a.dur), e)
				apply_status(o, "slow", float(a.get("pct", 15)), float(a.dur), e)
			"timewarp":
				apply_status(o, "timewarp", float(a.amount), float(a.dur), e)


func _spawn_rift(owner: BattleEnt, a: Dictionary) -> void:
	var r := _new_ent(owner.team, "rift")
	r.def_id = "rift"
	r.pos = owner.pos
	r.radius = float(a.radius)
	r.life = float(a.life)
	r.hp = 1
	r.max_hp = 1
	var fwd := Vector2(1 if owner.team == 0 else -1, 0)
	r.data = {"exit": clamp_pos(owner.pos + fwd * float(a.distance))}
	_add(r)


func _trap_tick(e: BattleEnt) -> void:
	for o in ents.duplicate():
		if not o.alive or o.team == e.team or o.flying or not o.kind in ["unit", "hero", "boss"]:
			continue
		if o.pos.distance_to(e.pos) <= e.radius + o.radius:
			events.append({"t": "explosion", "pos": e.pos, "radius": e.radius + 0.6, "color": "#c0a080" if e.kind == "trap" else "#58a6ff"})
			for v in ents.duplicate():
				if v.alive and v.team != e.team and not v.flying and v.targetable() and v.pos.distance_to(e.pos) <= e.radius + 0.8 + v.radius:
					_damage(null, v, e.dmg, "ability")
					if float(e.data.get("root", 0)) > 0:
						apply_status(v, "root", float(e.data.root), float(e.data.root))
			e.alive = false
			events.append({"t": "die", "id": e.id})
			return


func _rift_tick(e: BattleEnt) -> void:
	for o in ents:
		if o.alive and o.team == e.team and o.kind == "unit" and not o.flying and not e.used_by.has(o.id) and o.pos.distance_to(e.pos) <= e.radius:
			e.used_by[o.id] = true
			var from := o.pos
			o.pos = e.data.exit
			o.prev_pos = o.pos
			events.append({"t": "teleport", "id": o.id, "from": from, "to": o.pos})


# ------------------------------------------------------------------ hero
func _hero_tick() -> void:
	for t in 2:
		var cds: Dictionary = hero_cd[t]
		for k in cds.keys():
			cds[k] = maxf(0.0, float(cds[k]) - DT)
		if heroes[t] == null:
			continue
		var h: BattleEnt = heroes[t]
		if not h.alive:
			hero_respawn_t[t] -= DT
			if hero_respawn_t[t] <= 0 and (thrones[t] == null or thrones[t].alive) and not finished:
				_spawn_hero(t)
				events.append({"t": "hero_respawn", "team": t})
			continue
		hero_charge[t] = minf(100.0, hero_charge[t] + DT * float(DB.battle_cfg().get("ultimate_charge_per_sec", 1.0)))


func hero_ability_id(t: int, slot: String) -> String:
	var h = sides[t].get("hero")
	if h == null:
		return ""
	return str(h.abilities.get(slot, ""))


func hero_cooldown_total(t: int, slot: String) -> float:
	var aid := hero_ability_id(t, slot)
	var a: Dictionary = DB.abilities.get(aid, {})
	var cd := float(a.get("cooldown", 10))
	var h: BattleEnt = heroes[t]
	var cdr := 0.0
	if h:
		cdr = float(h.data.get("cdr", 0))
		for ef in h.data.effects:
			if ef.type == "cdr_ability" and ef.ability == aid:
				cdr += float(ef.pct)
	return cd * (1.0 - minf(60.0, cdr) / 100.0)


## Returns "" when the ability can be cast now, else a reason key.
func hero_can_cast(t: int, slot: String) -> String:
	var h: BattleEnt = heroes[t]
	if h == null or not h.alive or finished:
		return "ERR_HERO_DOWN"
	if h.has_status("stun"):
		return "ERR_STUNNED"
	var aid := hero_ability_id(t, slot)
	if aid == "":
		return "?"
	if slot == "ultimate":
		return "" if hero_charge[t] >= 100.0 else "ERR_CHARGING"
	if float(hero_cd[t].get(slot, 0.0)) > 0:
		return "ERR_COOLDOWN"
	if DB.abilities[aid].get("requires", "") == "mech_module" and not sides[t].hero.stats.get("mech_module", false):
		return "REQ_MECH_MODULE"
	return ""


func hero_cast(t: int, slot: String) -> bool:
	if hero_can_cast(t, slot) != "":
		return false
	var h: BattleEnt = heroes[t]
	var aid := hero_ability_id(t, slot)
	var a: Dictionary = DB.abilities[aid]
	var amp := 1.0 + h.ap / 100.0
	match aid:
		"tyrant_strike":
			pending.append({"kind": "aoe", "at": time + 0.25, "team": t, "pos": h.pos, "radius": float(a.radius), "dmg": h.dmg * float(a.power) * amp, "src": h.id, "force": float(a.force), "color": "#ffd23f"})
		"axe_throw":
			var best: BattleEnt = null
			var bd := INF
			for o in ents:
				if can_target(h, o) and o.kind != "wall":
					var d := o.pos.distance_to(h.pos)
					if d <= float(a.range) and d < bd:
						bd = d
						best = o
			if best == null:
				return false
			pending.append({"kind": "hit", "at": time + bd / 14.0, "src": h.id, "tgt": best.id, "amount": h.dmg * float(a.power) * amp, "opts": {}})
			events.append({"t": "attack", "id": h.id, "target": best.id, "proj": true, "travel": bd / 14.0, "axe": true})
		"overcharge":
			for o in ents:
				if o.alive and o.team == t and (o == h or o.family == "mech" or o.kind == "turret") and o.pos.distance_to(h.pos) <= float(a.radius):
					apply_status(o, "buff_as", float(a.pct) * amp, float(a.dur))
		"iron_skin":
			give_shield(h, h.max_hp * float(a.pct) / 100.0 * amp, float(a.dur))
		"royal_roar":
			for o in ents:
				if o.alive and o.team == t and o.kind in ["unit", "hero"] and o.pos.distance_to(h.pos) <= float(a.radius):
					apply_status(o, "buff_dmg", float(a.pct) * amp, float(a.dur))
					apply_status(o, "buff_armor", float(a.armor), float(a.dur))
		"mutant_fury":
			h.statuses["fury"] = {"v": 1, "t": float(a.dur), "dmg": float(a.dmg_pct) * amp, "speed": float(a.speed_pct), "lifesteal": float(a.lifesteal)}
		"raider_call":
			var lvl := maxi(1, int(Game.level() / 2.0)) if t == 0 else 2
			for i in 4:
				spawn_unit(t, "pillard_mini", h.pos + Vector2(cos(i * 1.57), sin(i * 1.57)) * 1.2, lvl, false)
			spawn_unit(t, "chef_pillard", h.pos + Vector2(1.0 if t == 0 else -1.0, 0), lvl, false)
		_:
			return false
	if slot == "ultimate":
		hero_charge[t] = 0.0
	else:
		hero_cd[t][slot] = hero_cooldown_total(t, slot)
	events.append({"t": "cast", "id": h.id, "ability": aid, "team": t, "slot": slot})
	if t == 0:
		stats.abilities_used += 1
	return true


func hero_move(t: int, p: Vector2) -> void:
	var h: BattleEnt = heroes[t]
	if h and h.alive:
		h.order_pos = clamp_pos(p)
		h.target = null


# ------------------------------------------------------------------ boss
func _boss_phase(b: BattleEnt) -> Dictionary:
	var phases: Array = b.data.get("phases", [])
	if phases.is_empty():
		return {}
	return phases[clampi(int(b.data.phase), 0, phases.size() - 1)]


func _boss_tick(b: BattleEnt) -> void:
	var phases: Array = b.data.phases
	var idx := int(b.data.phase)
	while idx + 1 < phases.size() and b.hp_frac() <= float(phases[idx + 1].threshold):
		idx += 1
		b.data.phase = idx
		b.speed = float(b.data.speed_base) * float(phases[idx].get("speed_mult", 1.0))
		events.append({"t": "phase", "id": b.id, "phase": idx})
	# Charge resolution: the boss lands at the end of its telegraphed dash.
	if b.data.has("dash_at") and time >= float(b.data.dash_at):
		b.pos = b.data.dash_to
		b.prev_pos = b.pos
		b.data.erase("dash_at")
	if b.has_status("stun") or b.has_status("exhausted"):
		return
	var ph: Dictionary = phases[idx]
	var cds: Dictionary = b.data.atk_cd
	for k in cds.keys():
		cds[k] = float(cds[k]) - DT
	if b.data.has("casting") and time < float(b.data.casting):
		return
	for i in ph.attacks.size():
		var atk: Dictionary = ph.attacks[i]
		var key := "%d_%d" % [idx, i]
		if not cds.has(key):
			cds[key] = 3.0 + i * 2.0
		if float(cds[key]) > 0:
			continue
		if _boss_attack(b, atk):
			cds[key] = float(atk.cooldown)
			b.data.casting = time + float(atk.get("telegraph", 0.8))
			return


func _player_cluster_near(b: BattleEnt, max_r: float) -> Vector2:
	var best := Vector2(-1, -1)
	var best_n := 0
	for o in ents:
		if not o.alive or o.team == b.team or not o.targetable() or o.pos.distance_to(b.pos) > max_r:
			continue
		var n := 0
		for o2 in ents:
			if o2.alive and o2.team == o.team and o2.targetable() and o2.pos.distance_to(o.pos) < 2.5:
				n += 1 + (2 if o2.kind == "hero" else 0)
		if n > best_n:
			best_n = n
			best = o.pos
	return best


func _boss_attack(b: BattleEnt, atk: Dictionary) -> bool:
	var m := float(b.data.lvl_m) * float(_boss_phase(b).get("dmg_mult", 1.0))
	var tel := float(atk.get("telegraph", 1.0))
	match str(atk.type):
		"slam", "tyrant_strike":
			var c := _player_cluster_near(b, 3.5 if atk.type == "slam" else 2.5)
			if c.x < 0:
				return false
			if atk.type == "tyrant_strike":
				c = b.pos
			_telegraph(b, c, float(atk.radius), tel, float(atk.dmg) * m, {"force": 1.5, "exhaust": atk.type == "slam"})
		"shockwave":
			var near := _player_cluster_near(b, float(atk.radius))
			if near.x < 0:
				return false
			_telegraph(b, b.pos, float(atk.radius), tel, float(atk.dmg) * m, {"exhaust": true})
		"fire_rain":
			var targets_p: Array = []
			for o in ents:
				if o.alive and o.team != b.team and o.targetable() and not o.kind in ["wall"]:
					targets_p.append(o.pos)
			if targets_p.is_empty():
				return false
			for i in int(atk.count):
				var p: Vector2 = targets_p[rng.randi() % targets_p.size()] + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
				_telegraph(b, p, float(atk.radius), tel, float(atk.dmg) * m, {"color": "#ff5a1f"})
		"summon":
			for i in int(atk.count):
				spawn_unit(b.team, str(atk.unit), b.pos + Vector2(rng.randf_range(-2, 0), rng.randf_range(-2, 2)), maxi(1, int(b.data.lvl_m * 3)), false)
			events.append({"t": "summon", "id": b.id})
		"royal_roar":
			for o in ents:
				if o.alive and o.team == b.team and o.pos.distance_to(b.pos) <= float(atk.radius):
					apply_status(o, "buff_dmg", float(atk.pct), 6.0)
			events.append({"t": "cast", "id": b.id, "ability": "royal_roar", "team": b.team, "slot": "boss"})
		"charge":
			var tgt := _player_cluster_near(b, float(atk.dist) + 2.0)
			if tgt.x < 0:
				return false
			var dir := (tgt - b.pos).normalized()
			var to := clamp_pos(b.pos + dir * float(atk.dist))
			events.append({"t": "telegraph", "shape": "line", "from": b.pos, "to": to, "width": float(atk.width), "delay": tel, "id": b.id})
			pending.append({"kind": "aoe", "at": time + tel, "team": b.team, "shape": "line", "from": b.pos, "to": to, "width": float(atk.width), "pos": to,
				"radius": float(atk.width), "dmg": float(atk.dmg) * m, "src": b.id, "exhaust": true, "color": "#d03fd9"})
			b.data["dash_to"] = to
			b.data["dash_at"] = time + tel
		"devour":
			var prey: BattleEnt = null
			for o in ents:
				if o.alive and o.team != b.team and o.kind == "unit" and o.pos.distance_to(b.pos) <= float(atk.range) + b.radius:
					if prey == null or o.hp > prey.hp:
						prey = o
			if prey == null:
				return false
			events.append({"t": "telegraph", "shape": "circle", "pos": prey.pos, "radius": 0.9, "delay": tel, "id": b.id})
			pending.append({"kind": "aoe", "at": time + tel, "team": b.team, "pos": prey.pos, "radius": 0.9, "dmg": 99999.0, "src": b.id, "color": "#d03fd9"})
			heal(b, b.max_hp * float(atk.heal_pct) / 100.0, b)
		_:
			return false
	return true


func _telegraph(b: BattleEnt, c: Vector2, r: float, delay: float, dmg: float, extra: Dictionary) -> void:
	events.append({"t": "telegraph", "shape": "circle", "pos": c, "radius": r, "delay": delay, "id": b.id})
	var p := {"kind": "aoe", "at": time + delay, "team": b.team, "pos": c, "radius": r, "dmg": dmg, "src": b.id, "color": extra.get("color", "#ff3030")}
	p.merge(extra)
	pending.append(p)


# ------------------------------------------------------------------ waves
func _waves_tick() -> void:
	var enemies_alive := 0
	for e in ents:
		if e.alive and e.team == 1 and e.kind in ["unit", "boss"]:
			enemies_alive += 1
	wave_timer -= DT
	var more := wave_index < waves.size() or endless
	if more and (wave_timer <= 0 or (enemies_alive == 0 and wave_index > 0 and wave_timer > 3.0)):
		var wave := _make_wave(wave_index)
		var lane := wave_director.choose_lane(wave)
		var i := 0
		for uid in wave.units:
			var lvl := int(sides[1].get("deck", [{"level": 1}])[0].get("level", 1)) if not sides[1].get("deck", []).is_empty() else 1
			lvl += int(wave_index / 3) if endless else 0
			var p := Vector2(L - 1.0 - (i % 3) * 0.9, clampf(lane + (i / 3 - 1) * 1.1 + rng.randf_range(-0.4, 0.4), 1, W - 1))
			spawn_unit(1, str(uid), p, mini(lvl, 12), false)
			i += 1
		wave_index += 1
		events.append({"t": "wave", "n": wave_index, "lane": lane})
		wave_timer = float(wave.get("next_delay", 14.0))
	if wave_index > 0 and enemies_alive == 0:
		waves_cleared = wave_index


func _make_wave(idx: int) -> Dictionary:
	if idx < waves.size():
		var w: Dictionary = waves[idx].duplicate()
		w["next_delay"] = float(waves[idx + 1].delay) if idx + 1 < waves.size() else 999.0
		return w
	# Endless survival: escalating random waves from the enemy deck
	var deck: Array = sides[1].get("deck", [])
	var units: Array = []
	for i in 2 + idx:
		units.append(deck[rng.randi() % deck.size()].id if not deck.is_empty() else "pillard_mini")
	return {"units": units, "next_delay": maxf(9.0, 16.0 - idx * 0.4)}


# ------------------------------------------------------------------ end conditions
func _check_end() -> void:
	match mode:
		"defense":
			if thrones[0] and not thrones[0].alive:
				_finish("loss")
			elif wave_index >= waves.size() and waves_cleared >= waves.size():
				_finish("win")
			elif time >= duration:
				_finish("loss")
		"survival":
			if thrones[0] and not thrones[0].alive or time >= duration:
				_finish("win" if waves_cleared >= 5 else "loss")
		"boss":
			if boss and not boss.alive:
				_finish("win")
			elif thrones[0] and not thrones[0].alive or time >= duration:
				_finish("loss")
		"raid":
			if thrones[1] and not thrones[1].alive:
				_finish("win")
			elif time >= duration:
				_finish("loss")
		"training":
			if time >= duration or thrones[1] and not thrones[1].alive:
				_finish("win")
			elif thrones[0] and not thrones[0].alive:
				_finish("loss")
		_:
			if thrones[1] and not thrones[1].alive:
				_finish("win")
			elif thrones[0] and not thrones[0].alive:
				_finish("loss")
			elif time >= duration:
				if structures_lost[1] > structures_lost[0]:
					_finish("win")
				elif structures_lost[0] > structures_lost[1]:
					_finish("loss")
				else:
					var a := _structure_hp_frac(1)
					var b := _structure_hp_frac(0)
					_finish("win" if a < b - 0.01 else ("loss" if b < a - 0.01 else "draw"))


func _structure_hp_frac(t: int) -> float:
	var hp := 0.0
	var mx := 0.0
	for e in ents:
		if e.team == t and e.kind == "structure":
			hp += e.hp
			mx += e.max_hp
	return hp / maxf(1.0, mx)


func _finish(o: String) -> void:
	if finished:
		return
	finished = true
	outcome = o
	events.append({"t": "end", "outcome": o})


func time_left() -> float:
	return maxf(0.0, duration - time)


func stars() -> int:
	if outcome != "win":
		return 0
	var s := 1
	match mode:
		"raid":
			if time_left() >= 60.0:
				s += 1
			var towers_left := 0
			for e in ents:
				if e.team == 1 and e.kind == "structure" and e.sub == "tower":
					towers_left += 1
			if towers_left == 0:
				s += 1
		"defense", "boss", "survival":
			if thrones[0] and thrones[0].hp_frac() >= 0.5:
				s += 1
			if structures_lost[0] == 0:
				s += 1
		_:
			if thrones[0] and thrones[0].hp_frac() >= 0.5:
				s += 1
			if structures_lost[1] >= structures_total[1]:
				s += 1
	return s


func result() -> Dictionary:
	return {
		"won": outcome == "win",
		"draw": outcome == "draw",
		"outcome": outcome,
		"stars": stars(),
		"mode": mode,
		"time": time,
		"units_deployed": stats.units_deployed,
		"abilities_used": stats.abilities_used,
		"damage_dealt": int(stats.damage_dealt),
		"structures_destroyed": structures_lost[1],
		"structures_lost": structures_lost[0],
		"waves_cleared": waves_cleared,
		"cards_played": stats.cards_played.duplicate(),
	}


func pop_events() -> Array:
	var e := events
	events = []
	return e


# ------------------------------------------------------------------ public perception (for bots)
## Only information that is visible on the battlefield: no hands, decks or energy of the opponent.
func perceive(team: int) -> Dictionary:
	var visible: Array = []
	for e in ents:
		if e.alive and is_visible_to(e, team):
			visible.append(e)
	return {"time": time, "time_left": time_left(), "visible": visible, "my_energy": energy[team], "my_hand": hands[team].duplicate(),
		"my_hero": heroes[team], "zone": deploy_zone(team), "enemy_throne": thrones[1 - team], "my_throne": thrones[team]}
