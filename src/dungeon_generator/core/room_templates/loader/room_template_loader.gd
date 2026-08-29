class_name RoomTemplateLoader
extends RefCounted

## Cargador determinista de archivos JSON a instancias tipadas de RoomTemplate.

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntrancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")
const _SymmetryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_symmetry_policy.gd")
const _AnchorDefScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_anchor_def.gd")
const _ClearancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_clearance_policy.gd")
const _DefValidatorScript = preload("res://src/dungeon_generator/core/room_templates/validation/room_template_definition_validator.gd")

var _def_validator := _DefValidatorScript.new()

func load_from_file(file_path: String) -> _RoomTemplateScript:
	if not FileAccess.file_exists(file_path):
		push_warning("[RoomTemplateLoader] File not found: %s" % file_path)
		return null

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("[RoomTemplateLoader] Failed to open: %s" % file_path)
		return null

	var json_str = file.get_as_text()
	return load_from_json_string(json_str)

func load_from_json_string(json_str: String) -> _RoomTemplateScript:
	var json = JSON.new()
	var error = json.parse(json_str)
	if error != OK:
		push_warning("[RoomTemplateLoader] JSON parse error: %s" % json.get_error_message())
		return null

	var data = json.get_data()
	if not (data is Dictionary):
		return null

	return parse_template_dictionary(data)

func parse_template_dictionary(dict: Dictionary) -> _RoomTemplateScript:
	var val_res = _def_validator.validate_definition(dict)
	if not val_res.is_valid:
		push_warning("[RoomTemplateLoader] Invalid template definition: %s" % str(val_res.errors))
		return null

	return _RoomTemplateScript.from_dictionary(dict)
