class_name AssetRegistry
extends RefCounted

## Autoridad única de consulta y catálogo de Asset IDs en runtime.
## Contiene todos los props, fixtures y perfiles de materiales registrados.

const _AssetPropEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_prop_entry.gd")
const _AssetFixtureEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_fixture_entry.gd")
const _AssetMaterialEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_material_entry.gd")

var props: Dictionary = {} # StringName -> AssetPropEntry
var fixtures: Dictionary = {} # StringName -> AssetFixtureEntry
var materials: Dictionary = {} # StringName -> AssetMaterialEntry

func register_prop(entry: _AssetPropEntryScript) -> void:
	if entry != null and entry.id != &"":
		props[entry.id] = entry

func register_fixture(entry: _AssetFixtureEntryScript) -> void:
	if entry != null and entry.id != &"":
		fixtures[entry.id] = entry

func register_material(entry: _AssetMaterialEntryScript) -> void:
	if entry != null and entry.id != &"":
		materials[entry.id] = entry

func get_prop(p_id: StringName) -> _AssetPropEntryScript:
	return props.get(p_id, null)

func get_fixture(p_id: StringName) -> _AssetFixtureEntryScript:
	return fixtures.get(p_id, null)

func get_material(p_id: StringName) -> _AssetMaterialEntryScript:
	return materials.get(p_id, null)

func has_prop(p_id: StringName) -> bool:
	return props.has(p_id)

func has_fixture(p_id: StringName) -> bool:
	return fixtures.has(p_id)

func has_material(p_id: StringName) -> bool:
	return materials.has(p_id)

func get_props_by_tag(tag: StringName) -> Array[_AssetPropEntryScript]:
	var result: Array[_AssetPropEntryScript] = []
	for p in props.values():
		if p.has_tag(tag):
			result.append(p)
	return result

func get_fixtures_by_tag(tag: StringName) -> Array[_AssetFixtureEntryScript]:
	var result: Array[_AssetFixtureEntryScript] = []
	for f in fixtures.values():
		if f.has_tag(tag):
			result.append(f)
	return result
