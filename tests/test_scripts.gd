extends TestCase
## Every script in the project must compile (catches errors in screens not covered elsewhere).


func _collect(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(path + "/" + f)
	for d in dir.get_directories():
		_collect(path + "/" + d, out)


func test_all_scripts_compile() -> void:
	var files: Array = []
	_collect("res://scripts", files)
	check(files.size() > 20, "found scripts")
	for f in files:
		var s = load(f)
		check(s != null and s is Script and (s as Script).can_instantiate(), "compiles: " + f)


func test_all_screens_registered() -> void:
	for k in Router.SCREENS.keys():
		check(ResourceLoader.exists(Router.SCREENS[k]), "screen exists: " + k)
