class_name ArchetypeProfileFactory
extends RefCounted

## Fábrica canónica de perfiles de arquetipos de mazmorra.

const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DungeonArchetypeProfileScript = preload("res://src/dungeon_generator/config/dungeon_archetype_profile.gd")

static func get_profile(p_archetype: _DungeonArchetypeScript.Type) -> _DungeonArchetypeProfileScript:
	var p := _DungeonArchetypeProfileScript.new()
	p.archetype = p_archetype

	match p_archetype:
		_DungeonArchetypeScript.Type.MAUSOLEUM:
			p.purpose_weights = {
				int(_RoomPurposeScript.Type.CRYPT): 4.0,
				int(_RoomPurposeScript.Type.TOMB): 3.0,
				int(_RoomPurposeScript.Type.CATACOMB): 3.0,
				int(_RoomPurposeScript.Type.SACRISTY): 1.5,
				int(_RoomPurposeScript.Type.HALL): 1.0
			}
			p.gameplay_purpose_map = {
				"START": [int(_RoomPurposeScript.Type.ENTRANCE), int(_RoomPurposeScript.Type.SACRISTY)],
				"BOSS": [int(_RoomPurposeScript.Type.ROYAL_TOMB), int(_RoomPurposeScript.Type.SANCTUM)],
				"TREASURE": [int(_RoomPurposeScript.Type.TOMB), int(_RoomPurposeScript.Type.SACRISTY)],
				"COMBAT": [int(_RoomPurposeScript.Type.CRYPT), int(_RoomPurposeScript.Type.CATACOMB)],
				"EXPLORE": [int(_RoomPurposeScript.Type.CATACOMB), int(_RoomPurposeScript.Type.HALL), int(_RoomPurposeScript.Type.CHAMBER)]
			}
		_DungeonArchetypeScript.Type.FORTRESS:
			p.purpose_weights = {
				int(_RoomPurposeScript.Type.ARMORY): 3.5,
				int(_RoomPurposeScript.Type.BARRACKS): 3.0,
				int(_RoomPurposeScript.Type.GUARD_ROOM): 3.5,
				int(_RoomPurposeScript.Type.PRISON_CELLS): 1.5,
				int(_RoomPurposeScript.Type.STORAGE): 2.0
			}
			p.gameplay_purpose_map = {
				"START": [int(_RoomPurposeScript.Type.ENTRANCE), int(_RoomPurposeScript.Type.GUARD_ROOM)],
				"BOSS": [int(_RoomPurposeScript.Type.THRONE_ROOM)],
				"TREASURE": [int(_RoomPurposeScript.Type.ARMORY), int(_RoomPurposeScript.Type.STORAGE)],
				"COMBAT": [int(_RoomPurposeScript.Type.BARRACKS), int(_RoomPurposeScript.Type.GUARD_ROOM), int(_RoomPurposeScript.Type.ARMORY)],
				"EXPLORE": [int(_RoomPurposeScript.Type.HALL), int(_RoomPurposeScript.Type.STORAGE), int(_RoomPurposeScript.Type.PRISON_CELLS)]
			}
		_DungeonArchetypeScript.Type.TEMPLE:
			p.purpose_weights = {
				int(_RoomPurposeScript.Type.SHRINE): 4.0,
				int(_RoomPurposeScript.Type.ALTAR_ROOM): 3.0,
				int(_RoomPurposeScript.Type.LIBRARY): 2.5,
				int(_RoomPurposeScript.Type.MEDITATION_ROOM): 2.0
			}
			p.gameplay_purpose_map = {
				"START": [int(_RoomPurposeScript.Type.ENTRANCE), int(_RoomPurposeScript.Type.MEDITATION_ROOM)],
				"BOSS": [int(_RoomPurposeScript.Type.SANCTUM), int(_RoomPurposeScript.Type.ALTAR_ROOM)],
				"TREASURE": [int(_RoomPurposeScript.Type.LIBRARY), int(_RoomPurposeScript.Type.SHRINE)],
				"COMBAT": [int(_RoomPurposeScript.Type.SHRINE), int(_RoomPurposeScript.Type.ALTAR_ROOM)],
				"EXPLORE": [int(_RoomPurposeScript.Type.MEDITATION_ROOM), int(_RoomPurposeScript.Type.HALL), int(_RoomPurposeScript.Type.CHAMBER)]
			}
		_DungeonArchetypeScript.Type.MINE:
			p.purpose_weights = {
				int(_RoomPurposeScript.Type.EXCAVATION): 4.0,
				int(_RoomPurposeScript.Type.ORE_CHAMBER): 3.0,
				int(_RoomPurposeScript.Type.FORGE): 2.0,
				int(_RoomPurposeScript.Type.WORKSHOP): 2.0,
				int(_RoomPurposeScript.Type.MINE_STORAGE): 2.5
			}
			p.gameplay_purpose_map = {
				"START": [int(_RoomPurposeScript.Type.ENTRANCE)],
				"BOSS": [int(_RoomPurposeScript.Type.FORGE), int(_RoomPurposeScript.Type.ORE_CHAMBER)],
				"TREASURE": [int(_RoomPurposeScript.Type.MINE_STORAGE), int(_RoomPurposeScript.Type.ORE_CHAMBER)],
				"COMBAT": [int(_RoomPurposeScript.Type.EXCAVATION), int(_RoomPurposeScript.Type.WORKSHOP)],
				"EXPLORE": [int(_RoomPurposeScript.Type.EXCAVATION), int(_RoomPurposeScript.Type.MINE_STORAGE), int(_RoomPurposeScript.Type.CHAMBER)]
			}
		_: # GENERIC
			p.purpose_weights = {
				int(_RoomPurposeScript.Type.CHAMBER): 4.0,
				int(_RoomPurposeScript.Type.HALL): 3.0,
				int(_RoomPurposeScript.Type.STORAGE): 2.0
			}
			p.gameplay_purpose_map = {
				"START": [int(_RoomPurposeScript.Type.ENTRANCE)],
				"BOSS": [int(_RoomPurposeScript.Type.CHAMBER)],
				"TREASURE": [int(_RoomPurposeScript.Type.STORAGE)],
				"COMBAT": [int(_RoomPurposeScript.Type.CHAMBER)],
				"EXPLORE": [int(_RoomPurposeScript.Type.HALL), int(_RoomPurposeScript.Type.CHAMBER)]
			}

	return p
