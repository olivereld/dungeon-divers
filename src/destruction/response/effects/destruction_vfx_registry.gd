class_name DestructionVFXRegistry
extends RefCounted

## Registro de efectos visuales (VFX) que carga el catálogo declarativo vfx.json
## y mantiene una caché de escenas compiladas (PackedScene).

var _catalog: Dictionary = {}
var _cache: Dictionary = {} # effect_id -> PackedScene
var _catalog_path: String = "res://resources/dungeon_profiles/assets/vfx.json"

func _init(catalog_path: String = "") -> void:
	if catalog_path != "":
		_catalog_path = catalog_path
	load_catalog()

func load_catalog() -> void:
	_catalog.clear()
	_cache.clear()
	if not ResourceLoader.exists(_catalog_path) and not FileAccess.file_exists(_catalog_path):
		return
	var file := FileAccess.open(_catalog_path, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and parsed.has("effects"):
			_catalog = parsed["effects"]

func has_effect(effect_id: String) -> bool:
	return _catalog.has(effect_id)

func get_scene_path(effect_id: String) -> String:
	if _catalog.has(effect_id):
		return str(_catalog[effect_id].get("scene", ""))
	return ""

func get_scene(effect_id: String) -> PackedScene:
	if not has_effect(effect_id):
		return null
	if _cache.has(effect_id):
		return _cache[effect_id]

	var scene_path := get_scene_path(effect_id)
	if scene_path != "" and (ResourceLoader.exists(scene_path) or FileAccess.file_exists(scene_path)):
		var scn = load(scene_path) as PackedScene
		if scn != null:
			_cache[effect_id] = scn
			return scn
	return null

func get_all_effect_ids() -> Array:
	return _catalog.keys()
