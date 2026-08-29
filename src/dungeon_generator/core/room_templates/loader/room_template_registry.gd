class_name RoomTemplateRegistry
extends RefCounted

## Registro y catálogo en memoria de RoomTemplates.
## Permite indexar, consultar y autodescubrir plantillas desde el sistema de archivos.

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _LoaderScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_loader.gd")

var _templates_by_id: Dictionary = {} # StringName -> RoomTemplate
var _loader: _LoaderScript = null

func _init(p_loader: _LoaderScript = null) -> void:
	_loader = p_loader if p_loader != null else _LoaderScript.new()

func register_template(template: _RoomTemplateScript) -> void:
	if template != null and not template.id.is_empty():
		_templates_by_id[template.id] = template

func get_template(id: StringName) -> _RoomTemplateScript:
	return _templates_by_id.get(id, null)

func has_template(id: StringName) -> bool:
	return _templates_by_id.has(id)

func list_template_ids() -> Array[StringName]:
	var list: Array[StringName] = []
	for k in _templates_by_id.keys():
		list.append(k)
	return list

func get_all_templates() -> Array[_RoomTemplateScript]:
	var list: Array[_RoomTemplateScript] = []
	for t in _templates_by_id.values():
		list.append(t)
	return list

func clear() -> void:
	_templates_by_id.clear()

func discover_templates_in_directory(dir_path: String) -> int:
	var loaded_count: int = 0
	var dir = DirAccess.open(dir_path)
	if dir == null:
		push_warning("[RoomTemplateRegistry] Cannot open directory: %s" % dir_path)
		return 0

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_path = dir_path.path_join(file_name)
			loaded_count += discover_templates_in_directory(sub_path)
		elif file_name.ends_with(".json"):
			var full_path = dir_path.path_join(file_name)
			var template = _loader.load_from_file(full_path)
			if template != null:
				register_template(template)
				loaded_count += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	return loaded_count
