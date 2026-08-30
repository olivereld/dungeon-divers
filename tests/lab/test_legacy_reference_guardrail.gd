extends SceneTree

const FORBIDDEN_TOKENS = [
	"res://scenes/dungeon/dungeon_level.tscn",
	"res://scenes/dungeon/dungeon_level_controller.gd",
	"DungeonLevelController"
]

const SCAN_DIRS = [
	"res://src",
	"res://scenes",
	"res://tests"
]

func _init() -> void:
	print("--- Running test_legacy_reference_guardrail ---")
	var violations: Array[String] = []

	# 1. Scan project.godot
	_scan_file("res://project.godot", violations)

	# 2. Scan directories
	for d in SCAN_DIRS:
		_scan_dir_recursive(d, violations)

	if violations.is_empty():
		print("PASS: test_legacy_reference_guardrail passed! 0 legacy references found in codebase.")
		quit(0)
	else:
		printerr("FAIL: Found %d legacy references in active codebase:" % violations.size())
		for v in violations:
			printerr("  - ", v)
		quit(1)

func _scan_dir_recursive(dir_path: String, violations: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = dir_path + "/" + file_name
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_dir_recursive(full_path, violations)
		elif not dir.current_is_dir():
			if file_name.ends_with(".gd") or file_name.ends_with(".tscn") or file_name.ends_with(".tres"):
				# Exclude the guardrail test itself
				if not full_path.ends_with("test_legacy_reference_guardrail.gd"):
					_scan_file(full_path, violations)
		file_name = dir.get_next()
	dir.list_dir_end()

func _scan_file(file_path: String, violations: Array[String]) -> void:
	# If the file itself is the legacy scene or controller (prior to removal in task 6), skip inspecting its self-declaration
	if file_path == "res://scenes/dungeon/dungeon_level.tscn" or file_path == "res://scenes/dungeon/dungeon_level_controller.gd":
		return

	var f = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return
	var content = f.get_as_text()
	f.close()

	for token in FORBIDDEN_TOKENS:
		if content.find(token) != -1:
			violations.append("%s contains forbidden token '%s'" % [file_path, token])
