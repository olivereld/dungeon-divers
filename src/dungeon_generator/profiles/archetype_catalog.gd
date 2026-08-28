class_name ArchetypeCatalog
extends RefCounted

## Catálogo centralizado y autoridad de descubrimiento de arquetipos de mazmorra.
## Lee el manifiesto archetypes.json como fuente canónica de verdad y provee resolución de rutas e IDs.

var _base_path: String = ""
var _entries: Dictionary = {} # StringName -> String (full path)

func _init(base_path: String = "res://resources/dungeon_profiles/archetypes/") -> void:
	_base_path = base_path if base_path.ends_with("/") else base_path + "/"
	reload()

## Recarga el catálogo desde archetypes.json con descubrimiento automático de respaldo.
func reload() -> void:
	_entries.clear()
	var manifest_path = _base_path + "archetypes.json"
	if FileAccess.file_exists(manifest_path):
		var file = FileAccess.open(manifest_path, FileAccess.READ)
		if file != null:
			var json_str = file.get_as_text()
			file.close()
			var json = JSON.parse_string(json_str)
			if json is Dictionary and json.has("archetypes") and json["archetypes"] is Array:
				for item in json["archetypes"]:
					if item is Dictionary and item.has("id") and item.has("file"):
						_entries[StringName(item["id"])] = _base_path + str(item["file"])

	# Descubrimiento dinámico para cualquier archivo JSON no listado
	var dir = DirAccess.open(_base_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != "archetypes.json":
				var id = StringName(file_name.get_basename())
				if not _entries.has(id):
					_entries[id] = _base_path + file_name
			file_name = dir.get_next()
		dir.list_dir_end()

func get_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for k in _entries.keys():
		result.append(k)
	return result

func has_archetype(id: StringName) -> bool:
	return _entries.has(id)

func get_profile_path(id: StringName) -> String:
	return _entries.get(id, "")
