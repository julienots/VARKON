class_name BattleEnt
extends RefCounted
## One combat entity (unit, hero, structure, boss, turret, decoy, wall, trap, rune, rift).

var id := 0
var team := 0
var kind := "unit"          # unit, hero, structure, turret, decoy, boss, wall, trap, rune, rift, dummy
var sub := ""               # structure subtype: throne / tower ; trap subtype
var def_id := ""
var name := ""
var family := ""
var role := ""
var level := 1
var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var facing := Vector2.RIGHT
var radius := 0.45
var hp := 100.0
var max_hp := 100.0
var armor := 0.0
var dmg := 10.0
var hit := 1.0              # seconds between attacks
var reach := 0.8         # attack range
var speed := 1.5
var proj := 0.0             # projectile speed (0 = melee)
var flying := false
var can_hit_air := false
var targets := "any"        # any / structures
var abilities: Array = []
var timers := {}
var statuses := {}
var target: BattleEnt
var retarget_t := 0.0
var cooldown := 0.0
var alive := true
var life := -1.0            # remaining lifetime for temporary entities
var deploy_t := 0.0         # can't act while deploying
var stealth_t := 0.0
var shield := 0.0
var shield_t := 0.0
var kills := 0
var moved := 0.0            # distance moved since last attack (charge)
var hits_done := 0
var phase_triggered := false
var disabled_t := 0.0
var ap := 0.0               # ability power %
var dmg_pct := 0.0          # permanent damage bonus %
var speed_pct := 0.0
var as_pct := 0.0
var regen_pct := 0.0
var heal_pct := 0.0
var slow_dur_pct := 0.0
var poison_pct := 0.0
var lifesteal := 0.0
var resist := 0.0
var data := {}              # misc (hero abilities, boss phases, rift exits...)
var order_pos = null        # hero move order (Vector2 or null)
var used_by := {}           # rift / trap usage
var last_attacker := 0
var damage_dealt := 0.0

# Aura values recomputed every tick
var a_dmg := 0.0
var a_as := 0.0
var a_armor := 0.0
var a_speed := 0.0
var a_ap := 0.0
var a_dr := 0.0
var a_cleanse := 0.0
var protector: BattleEnt


func is_structure() -> bool:
	return kind == "structure" or kind == "wall" or kind == "turret"


func is_static() -> bool:
	return kind in ["structure", "wall", "turret", "trap", "rune", "rift", "dummy"]


func targetable() -> bool:
	return alive and not kind in ["trap", "rune", "rift"]


func hp_frac() -> float:
	return hp / maxf(1.0, max_hp)


func has_ability(t: String) -> bool:
	for a in abilities:
		if a.type == t:
			return true
	return false


func ability(t: String) -> Dictionary:
	for a in abilities:
		if a.type == t:
			return a
	return {}


func status_v(key: String, field := "v", def := 0.0) -> float:
	if statuses.has(key):
		return float(statuses[key].get(field, def))
	return def


func has_status(key: String) -> bool:
	return statuses.has(key)
