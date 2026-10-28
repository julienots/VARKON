extends Node
## Headless test runner:  godot --headless --path . res://tests/test_runner.tscn
## Runs every tests/test_*.gd (TestCase subclasses) and exits with code 0/1.

func _ready() -> void:
	SaveSys.enabled = false
	SaveSys.save_path = "user://test_save.json"
	await get_tree().process_frame
	var files: Array = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd" and f != "test_case.gd":
			files.append(f)
	files.sort()
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			filter = a.substr(7)
	var total := 0
	var failed: Array = []
	var t0 := Time.get_ticks_msec()
	for f in files:
		var script: Script = load("res://tests/" + f)
		var tc = script.new()
		for m in script.get_script_method_list():
			var mname: String = m.name
			if not mname.begins_with("test_"):
				continue
			if filter != "" and not (f + ":" + mname).contains(filter):
				continue
			total += 1
			tc.current = f + ":" + mname
			tc.failures.clear()
			var t1 := Time.get_ticks_msec()
			var r = tc.call(mname)
			if r is Object and r.has_signal("completed"):
				await r
			var dt := Time.get_ticks_msec() - t1
			if tc.failures.is_empty():
				print("  PASS  %s (%d ms)" % [tc.current, dt])
			else:
				for x in tc.failures:
					print("  FAIL  " + x)
				failed.append(tc.current)
	print("\n%d tests, %d failed, %.1fs" % [total, failed.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	SaveSys.wipe()
	get_tree().quit(1 if failed.size() > 0 or total == 0 else 0)
