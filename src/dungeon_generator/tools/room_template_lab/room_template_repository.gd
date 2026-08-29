class_name RoomTemplateRepository
extends RefCounted

## Capa pura de I/O, serialización y gestión de archivos para RoomTemplates en disco.

const _LoaderScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_loader.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _DefValidatorScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_definition_validator.gd")

var _loader := _LoaderScript.new()
var _validator := _DefValidatorScript.new()

func list_templates(base_dir: String = "res://resources/dungeon_profiles/room_templates") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var files := _collect_json_files_recursive(base_dir)

	for f_path in files:
		var file = FileAccess.open(f_path, FileAccess.READ)
		if file != null:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data = json.get_data()
				if data is Dictionary and data.has("id"):
					result.append({
						"id": StringName(str(data["id"])),
						"display_name": str(data.get("display_name", data["id"])),
						"path": f_path,
						"category": f_path.get_base_dir().get_file(),
						"filename": f_path.get_file()
					})
	return result

func load_template_by_id(target_id: StringName, base_dir: String = "res://resources/dungeon_profiles/room_templates") -> _RoomTemplateScript:
	var items = list_templates(base_dir)
	for it in items:
		if it["id"] == target_id:
			return _loader.load_from_file(it["path"])
	return null

func save_template_to_json(template: _RoomTemplateScript, target_path: String) -> bool:
	if template == null or target_path.is_empty():
		return false
	var dict = template_to_dictionary(template)
	var val_res = _validator.validate_definition(dict)
	if not val_res.is_valid:
		push_warning("[RoomTemplateRepository] Saving template with validation warnings: %s" % str(val_res.errors))

	var file = FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		push_error("[RoomTemplateRepository] Failed to open file for write: %s" % target_path)
		return false

	var json_str = JSON.stringify(dict, "    ")
	file.store_string(json_str)
	file.close()
	return true

func template_to_dictionary(tpl: _RoomTemplateScript) -> Dictionary:
	if tpl == null:
		return {}

	var dict: Dictionary = {
		"id": str(tpl.id),
		"display_name": tpl.display_name,
		"tags": _to_string_array(tpl.tags)
	}

	if tpl.geometry != null:
		dict["geometry"] = {
			"shape": { "allowed": _to_string_array(tpl.geometry.allowed_shapes) },
			"width": { "min": tpl.geometry.min_width, "max": tpl.geometry.max_width },
			"depth": { "min": tpl.geometry.min_depth, "max": tpl.geometry.max_depth },
			"area": { "min": tpl.geometry.min_area, "max": tpl.geometry.max_area },
			"aspect_ratio": { "min": tpl.geometry.min_aspect_ratio, "max": tpl.geometry.max_aspect_ratio }
		}

	if tpl.entrances != null:
		dict["entrances"] = {
			"min": tpl.entrances.min_count,
			"max": tpl.entrances.max_count,
			"allowed_sides": _to_string_array(tpl.entrances.allowed_sides),
			"allow_corner": tpl.entrances.allow_corner,
			"min_spacing": tpl.entrances.min_spacing
		}

	if tpl.symmetry != null:
		dict["symmetry"] = {
			"required": tpl.symmetry.required,
			"axis": str(tpl.symmetry.axis)
		}

	if tpl.anchors is Dictionary and not tpl.anchors.is_empty():
		var a_dict: Dictionary = {}
		for a_id in tpl.anchors:
			var ad = tpl.anchors[a_id]
			if ad != null:
				a_dict[str(a_id)] = {
					"required": ad.required,
					"location": str(ad.location_hint)
				}
		dict["anchors"] = a_dict

	if tpl.clearances != null:
		dict["clearances"] = {
			"entrance": tpl.clearances.entrance,
			"focal": tpl.clearances.focal,
			"circulation": tpl.clearances.circulation,
			"walls": tpl.clearances.walls
		}

	if not tpl.allowed_purposes.is_empty() or not tpl.preferred_purposes.is_empty():
		dict["purposes"] = {
			"allowed": _to_string_array(tpl.allowed_purposes),
			"preferred": _to_string_array(tpl.preferred_purposes)
		}

	return dict

func clone_template(source_tpl: _RoomTemplateScript, new_id: StringName, new_display_name: String) -> _RoomTemplateScript:
	if source_tpl == null:
		return null
	var dict = template_to_dictionary(source_tpl)
	dict["id"] = str(new_id)
	dict["display_name"] = new_display_name
	return _loader.parse_template_dictionary(dict)

func _collect_json_files_recursive(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			result.append_array(_collect_json_files_recursive(dir_path.path_join(file_name)))
		elif file_name.ends_with(".json"):
			result.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _to_string_array(arr: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for a in arr:
		out.append(str(a))
	return out
