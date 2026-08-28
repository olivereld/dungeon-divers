class_name RoomPreviewRequest
extends RefCounted

## Petición inmutable para generar la previsualización aislada de una habitación.
## Encapsula arquetipo, propósito, semilla y dimensiones sin acoplarse a la UI.

const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

var archetype: StringName = &"necropolis"
var purpose: StringName = &"tomb"
var seed: int = 12345
var room_size: Vector2i = Vector2i(10, 8)
var tile_size: float = 2.0
var has_door: bool = true
var has_stairs: bool = false

func _init(
	p_archetype: Variant = &"necropolis",
	p_purpose: Variant = &"tomb",
	p_seed: int = 12345,
	p_size: Vector2i = Vector2i(10, 8),
	p_tile_size: float = 2.0,
	p_door: bool = true,
	p_stairs: bool = false
) -> void:
	archetype = _DungeonArchetypeScript.resolve_id(p_archetype)
	purpose = _RoomPurposeScript.resolve_id(p_purpose)
	seed = p_seed
	room_size = p_size
	tile_size = p_tile_size
	has_door = p_door
	has_stairs = p_stairs

func is_valid() -> bool:
	if room_size.x < 4 or room_size.y < 4:
		return false
	return is_purpose_valid_for_archetype(archetype, purpose)

static func is_purpose_valid_for_archetype(arch: Variant, purp: Variant) -> bool:
	var purp_id: StringName = _RoomPurposeScript.resolve_id(purp)
	var valid_purposes = get_valid_purposes_for_archetype(arch)
	return valid_purposes.has(purp_id) or valid_purposes.is_empty()

static func get_valid_purposes_for_archetype(arch: Variant) -> Array[StringName]:
	var arch_id: StringName = _DungeonArchetypeScript.resolve_id(arch)
	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_full_archetype_bundle(str(arch_id))
	var result: Array[StringName] = []
	if bundle != null and bundle.archetype != null:
		for p_str in bundle.archetype.purpose_weights.keys():
			result.append(_RoomPurposeScript.resolve_id(p_str))
	if result.is_empty():
		result = [&"generic", &"entrance", &"hall", &"chamber"]
	return result
