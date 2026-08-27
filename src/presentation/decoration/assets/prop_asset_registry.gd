class_name PropAssetRegistry
extends RefCounted

## Registro data-driven desacoplado de definiciones de assets (PropAssetDefinition).
## Mapea de forma transparente prop_id -> PropAssetDefinition sin instanciar nodos ni acoplarse al spawner.
## 100% Data-Driven: se alimenta íntegramente de props.json a través de ProfileLoader.

const _PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

var _definitions: Dictionary = {} # StringName -> PropAssetDefinition

func _init() -> void:
	var loader := _ProfileLoaderScript.new()
	loader.populate_prop_asset_registry(self)

func register_definition(def: _PropAssetDefinitionScript) -> void:
	if def != null and def.id != &"":
		_definitions[def.id] = def

func has_definition(prop_id: StringName) -> bool:
	return _definitions.has(prop_id)

func get_definition(prop_id: StringName) -> _PropAssetDefinitionScript:
	return _definitions.get(prop_id, null) as _PropAssetDefinitionScript

func get_all_definition_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for k in _definitions.keys():
		result.append(k)
	return result

func get_definitions_count() -> int:
	return _definitions.size()

func clear() -> void:
	_definitions.clear()

