class_name TestCase
extends RefCounted
## Minimal assertion base for headless tests (see tests/test_runner.gd).

var failures: Array = []
var current := ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a, b, msg: String) -> void:
	if a != b:
		failures.append("%s: %s (got %s, expected %s)" % [current, msg, str(a), str(b)])


## Fresh profile without touching the player's real save.
func fresh() -> void:
	SaveSys.enabled = false
	Game.time_offset = 0.0
	Game.new_profile()
	Game.missions.refresh_rotations()
	Game.rng.seed = 12345
