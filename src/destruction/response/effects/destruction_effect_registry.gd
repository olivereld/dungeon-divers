class_name DestructionEffectRegistry
extends RefCounted

## Registro de efectos declarativos para respuestas a la destrucción.
## Carga y valida el catálogo effects.json.

var _effects: Dictionary = {}
var _catalog_path: String = "res://resources/dungeon_profiles/assets/effects.json"

func _init(catalog_path: String = "") -> void:
	if catalog_path != "":
		_catalog_path = catalog_path
	load_catalog()

func load_catalog() -> void:
	if not ResourceLoader.exists(_catalog_path) and not FileAccess.file_exists(_catalog_path):
		return
	var file := FileAccess.open(_catalog_path, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and parsed.has("effects"):
			_effects = parsed["effects"]

func has_effect(effect_id: String) -> bool:
	return _effects.has(effect_id)

func get_effect_config(effect_id: String) -> Dictionary:
	return _effects.get(effect_id, {})

func get_all_effect_ids() -> Array:
	return _effects.keys()
