class_name RoomPreviewRequest
extends RefCounted

## Petición inmutable para generar la previsualización aislada de una habitación.
## Encapsula arquetipo, propósito, semilla y dimensiones sin acoplarse a la UI.

const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

var archetype: int = _DungeonArchetypeScript.Type.MAUSOLEUM
var purpose: int = _RoomPurposeScript.Type.TOMB
var seed: int = 12345
var room_size: Vector2i = Vector2i(10, 8)
var tile_size: float = 2.0
var has_door: bool = true
var has_stairs: bool = false

func _init(
	p_archetype: int = _DungeonArchetypeScript.Type.MAUSOLEUM,
	p_purpose: int = _RoomPurposeScript.Type.TOMB,
	p_seed: int = 12345,
	p_size: Vector2i = Vector2i(10, 8),
	p_tile_size: float = 2.0,
	p_door: bool = true,
	p_stairs: bool = false
) -> void:
	archetype = p_archetype
	purpose = p_purpose
	seed = p_seed
	room_size = p_size
	tile_size = p_tile_size
	has_door = p_door
	has_stairs = p_stairs

func is_valid() -> bool:
	if room_size.x < 4 or room_size.y < 4:
		return false
	return is_purpose_valid_for_archetype(archetype, purpose)

static func is_purpose_valid_for_archetype(arch: int, purp: int) -> bool:
	var valid_purposes = get_valid_purposes_for_archetype(arch)
	return valid_purposes.has(purp)

static func get_valid_purposes_for_archetype(arch: int) -> Array[int]:
	match arch:
		_DungeonArchetypeScript.Type.MAUSOLEUM:
			return [
				_RoomPurposeScript.Type.TOMB,
				_RoomPurposeScript.Type.SACRISTY,
				_RoomPurposeScript.Type.CRYPT,
				_RoomPurposeScript.Type.CATACOMB,
				_RoomPurposeScript.Type.ROYAL_TOMB,
				_RoomPurposeScript.Type.GENERIC
			]
		_DungeonArchetypeScript.Type.FORTRESS:
			return [
				_RoomPurposeScript.Type.BARRACKS,
				_RoomPurposeScript.Type.ARMORY,
				_RoomPurposeScript.Type.THRONE_ROOM,
				_RoomPurposeScript.Type.GUARD_ROOM,
				_RoomPurposeScript.Type.PRISON_CELLS,
				_RoomPurposeScript.Type.GENERIC
			]
		_DungeonArchetypeScript.Type.TEMPLE:
			return [
				_RoomPurposeScript.Type.SHRINE,
				_RoomPurposeScript.Type.SANCTUM,
				_RoomPurposeScript.Type.ALTAR_ROOM,
				_RoomPurposeScript.Type.LIBRARY,
				_RoomPurposeScript.Type.MEDITATION_ROOM,
				_RoomPurposeScript.Type.GENERIC
			]
		_DungeonArchetypeScript.Type.MINE:
			return [
				_RoomPurposeScript.Type.EXCAVATION,
				_RoomPurposeScript.Type.MINE_STORAGE,
				_RoomPurposeScript.Type.FORGE,
				_RoomPurposeScript.Type.ORE_CHAMBER,
				_RoomPurposeScript.Type.WORKSHOP,
				_RoomPurposeScript.Type.GENERIC
			]
		_:
			return [_RoomPurposeScript.Type.GENERIC]
