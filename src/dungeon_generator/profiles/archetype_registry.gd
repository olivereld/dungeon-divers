class_name ArchetypeRegistry
extends RefCounted

## Registro dinámico y descubridor de archivos de arquetipos en el sistema de archivos.
## Permite descubrir, indexar y resolver arquetipos sin listas fijas ni enums hardcodeados.

var _archetype_files: Dictionary = {} # StringName (id) -> String (filepath)

func _init(dir_path: String = "res://resources/dungeon_profiles/archetypes/") -> void:
	if not dir_path.is_empty():
		discover_archetypes(dir_path)

## Descubre todos los archivos .json dentro del directorio y los indexa por su ID
func discover_archetypes(dir_path: String = "res://resources/dungeon_profiles/archetypes/") -> Dictionary:
	_archetype_files.clear()
	var clean_path = dir_path if dir_path.ends_with("/") else dir_path + "/"
	var dir = DirAccess.open(clean_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var raw_id = file_name.get_basename()
				var full_path = clean_path + file_name
				_archetype_files[StringName(raw_id)] = full_path
			file_name = dir.get_next()
		dir.list_dir_end()
	return _archetype_files

func has_archetype(id: StringName) -> bool:
	return _archetype_files.has(id)

func get_filepath(id: StringName) -> String:
	return _archetype_files.get(id, "")

func get_available_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for k in _archetype_files.keys():
		result.append(k)
	return result
