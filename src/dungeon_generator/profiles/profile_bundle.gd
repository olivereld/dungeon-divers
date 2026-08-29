class_name ProfileBundle
extends RefCounted

## Contenedor integral e inmutable del conjunto completo de perfiles de un arquetipo:
## Arquetipo + Todas sus salas deserializadas + AssetRegistry.

const _ProfileArchetypeScript = preload("res://src/dungeon_generator/profiles/profile_archetype.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")
const _AssetRegistryScript = preload("res://src/dungeon_generator/profiles/asset_registry.gd")
const _RoomTemplateRegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")

var archetype: _ProfileArchetypeScript = null
var rooms: Dictionary = {} # StringName (purpose_id) -> ProfileRoom
var assets: _AssetRegistryScript = null
var template_registry: _RoomTemplateRegistryScript = null

func _init(
	p_arch: _ProfileArchetypeScript = null,
	p_rooms: Dictionary = {},
	p_assets: _AssetRegistryScript = null,
	p_templates: _RoomTemplateRegistryScript = null
) -> void:
	archetype = p_arch
	rooms = p_rooms
	assets = p_assets if p_assets != null else _AssetRegistryScript.new()
	template_registry = p_templates if p_templates != null else _RoomTemplateRegistryScript.new()

func get_room(purpose_id: StringName) -> _ProfileRoomScript:
	return rooms.get(purpose_id, null)

func has_room(purpose_id: StringName) -> bool:
	return rooms.has(purpose_id)

func get_distribution_weight(purpose_id: StringName) -> float:
	if archetype != null:
		return archetype.get_distribution_weight(purpose_id)
	return 0.0

func get_contextual_weight(purpose_id: StringName) -> float:
	if archetype != null:
		return archetype.get_contextual_weight(purpose_id)
	return 1.0
