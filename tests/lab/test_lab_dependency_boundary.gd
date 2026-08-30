extends SceneTree

func _init() -> void:
	print("--- Running test_lab_dependency_boundary ---")
	var core_dir := "res://src/dungeon_generator/core"
	var violations: Array[String] = []

	var files_to_scan: Array[String] = _get_all_gd_files(core_dir)
	print("Scanning %d core files for forbidden dependencies into debug/lab/..." % files_to_scan.size())

	for file_path in files_to_scan:
		var f := FileAccess.open(file_path, FileAccess.READ)
		if f == null:
			continue
		var content := f.get_as_text()
		f.close()

		if content.find("debug/lab") != -1 or content.find("dungeon_level_lab") != -1 or content.find("DungeonLab") != -1:
			violations.append("Forbidden reference found in: %s" % file_path)

	if not violations.is_empty():
		for v in violations:
			printerr("VIOLATION: ", v)
		assert(false, "FAIL: Core files must have ZERO dependencies into debug/lab/")

	print("PASS: test_lab_dependency_boundary passed with 0 violations!")
	quit(0)

func _get_all_gd_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := dir_path + "/" + file_name
			if dir.current_is_dir():
				result.append_array(_get_all_gd_files(full_path))
			elif file_name.ends_with(".gd"):
				result.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
