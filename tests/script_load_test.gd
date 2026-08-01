extends SceneTree

## Loads every script and every scene in the project, which makes the engine
## report anything that does not compile.
##
##   godot --headless --path . --script tests/script_load_test.gd 2>&1 \
##       | grep -q "Failed to load script" && echo BROKEN
##
## The grep is the actual check. A running Godot cannot tell a broken script
## from a good one — ResourceLoader.load() returns a resource either way and
## GDScript.reload() returns OK either way — so the only reliable signal is the
## error the engine prints while loading.
##
## It exists because a parse error can hide from everything else: a `const`
## built from another class enum loads fine headless and only blows up when the
## editor compiles the script, which is what happens on F5.

const SCAN_DIRS: Array[String] = ["res://engine", "res://content", "res://tests"]
const SKIP_DIRS: Array[String] = ["res://.godot"]

var failures: PackedStringArray = []
var script_count: int = 0
var scene_count: int = 0


func _initialize() -> void:
	for directory in SCAN_DIRS:
		_scan(directory)

	for failure in failures:
		print("  FAIL: %s" % failure)
	print("\nSCAN COMPLETE: %d scripts, %d scenes" % [script_count, scene_count])
	quit(1 if not failures.is_empty() else 0)


func _scan(directory: String) -> void:
	if SKIP_DIRS.has(directory):
		return
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := directory.path_join(entry)
		if dir.current_is_dir():
			_scan(path)
		elif entry.ends_with(".gd"):
			_check_script(path)
		elif entry.ends_with(".tscn"):
			_check_scene(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _check_script(path: String) -> void:
	script_count += 1
	# Default cache mode on purpose: reloading a running script from disk with
	# CACHE_MODE_IGNORE crashes the engine.
	var script: Resource = ResourceLoader.load(path, "Script")
	if script == null:
		failures.append("script did not compile: %s" % path)


func _check_scene(path: String) -> void:
	scene_count += 1
	var scene: PackedScene = ResourceLoader.load(path, "PackedScene")
	if scene == null:
		failures.append("scene did not load: %s" % path)
		return
	var instance := scene.instantiate()
	if instance == null:
		failures.append("scene did not instantiate: %s" % path)
		return
	instance.free()
