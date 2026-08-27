class_name PropAssetRegistry
extends RefCounted

## Registro data-driven desacoplado de definiciones de assets (PropAssetDefinition).
## Mapea de forma transparente prop_id -> PropAssetDefinition sin instanciar nodos ni acoplarse al spawner.

const _PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")
const _PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

var _definitions: Dictionary = {} # StringName -> PropAssetDefinition

func _init() -> void:
	_register_default_definitions()
	var loader := _ProfileLoaderScript.new()
	loader.populate_prop_asset_registry(self)

func register_definition(def: _PropAssetDefinitionScript) -> void:
	if def != null and def.id != &"":
		_definitions[def.id] = def

func has_definition(prop_id: StringName) -> bool:
	return _definitions.has(prop_id)

func get_definition(prop_id: StringName) -> _PropAssetDefinitionScript:
	return _definitions.get(prop_id, null) as _PropAssetDefinitionScript

func _register_default_definitions() -> void:
	# 1. Crypt / Mausoleum Props
	register_definition(_PropAssetDefinitionScript.new(
		&"pillar_stone",
		_PropAssetSourceScript.SourceType.PACKED_SCENE,
		&"",
		{},
		null,
		Vector3.ONE,
		0.0,
		"res://assets/scenes/props/pillar_stone.tscn"
	))
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
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"crypt_urn_banded_floor", &"urn_prop", {"style": 0, "scale": 1.0, "has_lid": true}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"crypt_urn_relic_floor", &"urn_prop", {"style": 1, "scale": 1.0, "has_lid": true}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"crypt_urn_canopic_surface", &"urn_prop", {"style": 3, "scale": 0.65, "has_lid": true}
	))

	# 2. Temple Props
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"temple_altar_center", &"altar_prop", {"style": 2}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"temple_urn_pedestal_floor", &"urn_prop", {"style": 2, "scale": 1.0, "has_lid": true}
	))
	register_definition(_PropAssetDefinitionScript.create_procedural_definition(
		&"temple_urn_canopic_surface", &"urn_prop", {"style": 3, "scale": 0.65, "has_lid": true}
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
