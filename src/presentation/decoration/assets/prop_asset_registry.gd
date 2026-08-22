class_name PropAssetRegistry
extends RefCounted

## Registro data-driven desacoplado de definiciones de assets (PropAssetDefinition).
## Mapea de forma transparente prop_id -> PropAssetDefinition sin instanciar nodos ni acoplarse al spawner.

const _PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")

var _definitions: Dictionary = {} # StringName -> PropAssetDefinition

func _init() -> void:
	_register_default_definitions()

func register_definition(def: _PropAssetDefinitionScript) -> void:
	if def != null and def.id != &"":
		_definitions[def.id] = def

func has_definition(prop_id: StringName) -> bool:
	return _definitions.has(prop_id)

func get_definition(prop_id: StringName) -> _PropAssetDefinitionScript:
	return _definitions.get(prop_id, null) as _PropAssetDefinitionScript

func _register_default_definitions() -> void:
	# 1. Crypt / Mausoleum Props
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"sarcophagus_stone_closed", &"sarcophagus_prop", {"style": 0, "is_open": false}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"sarcophagus_stone_open", &"sarcophagus_prop", {"style": 0, "is_open": true}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"sarcophagus_wood_closed", &"sarcophagus_prop", {"style": 1, "is_open": false}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"sarcophagus_wood_open", &"sarcophagus_prop", {"style": 1, "is_open": true}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"tombstone_classic_wall", &"tombstone_prop", {"style": 0}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"tombstone_cross_corner", &"tombstone_prop", {"style": 1}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"stone_altar_center", &"altar_prop", {"style": 1}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"church_pew_wall", &"bench_prop", {"style": 0}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"stone_orior_floor", &"bench_prop", {"style": 1}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"crypt_rubble_corner", &"rubble_prop", {}
	))

	# 2. Temple Props
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"temple_altar_center", &"altar_prop", {"style": 2}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"temple_pew_floor", &"bench_prop", {"style": 0}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"temple_pew_wall", &"bench_prop", {"style": 0}
	))

	# 3. Fortress Props
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"fortress_table_center", &"table_prop", {"style": 0}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"fortress_bench_wall", &"bench_prop", {"style": 3}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"fortress_bookshelf_wall", &"bookshelf_prop", {"style": 0}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"fortress_chest_corner", &"chest_prop", {"is_open": false}
	))

	# 4. Mine Props
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"mine_crate_corner", &"crate_prop", {}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"mine_rubble_floor", &"rubble_prop", {}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"mine_barrel_wall", &"barrel_prop", {}
	))
