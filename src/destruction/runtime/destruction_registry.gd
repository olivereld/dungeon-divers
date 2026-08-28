class_name DestructionRegistry
extends RefCounted

## Registro canónico de definiciones de destrucción para props y fixtures.
## 100% data-driven: poblado automáticamente desde destruction.json via ProfileLoader.

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

var _definitions: Dictionary = {}

func _init(autoload: bool = true) -> void:
	if autoload:
		var loader := _ProfileLoaderScript.new()
		loader.populate_destruction_registry(self)

func register_definition(def: _DestructibleDefScript) -> void:
	if def != null and def.id != &"":
		_definitions[def.id] = def

func get_definition(id: StringName) -> _DestructibleDefScript:
	return _definitions.get(id, null)

func has_definition(id: StringName) -> bool:
	return _definitions.has(id)

func clear() -> void:
	_definitions.clear()

func get_all_definitions() -> Array:
	return _definitions.values()

func size() -> int:
	return _definitions.size()
