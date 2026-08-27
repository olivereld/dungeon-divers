class_name PresentationProfileResolver
extends RefCounted

## Resolvedor canónico y puro de perfiles de presentación arquitectónica.
## Mapea deterministamente (DungeonArchetype, RoomPurpose) -> ArchitecturalPresentationProfile.
## 100% puro: no depende de nodos de escena, mallas 3D ni RenderingServer.

const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")

func resolve(archetype: int, purpose: int, room_profile = null) -> _ArchitecturalPresentationProfileScript:
	if room_profile is _ProfileRoomScript and room_profile.architecture != null:
		return resolve_from_room_profile(room_profile, archetype, purpose)

	match archetype:
		_DungeonArchetypeScript.Type.MAUSOLEUM:
			return _resolve_mausoleum(purpose)
		_DungeonArchetypeScript.Type.FORTRESS:
			return _resolve_fortress(purpose)
		_DungeonArchetypeScript.Type.TEMPLE:
			return _resolve_temple(purpose)
		_DungeonArchetypeScript.Type.MINE:
			return _resolve_mine(purpose)
		_:
			return _resolve_generic(purpose)

func resolve_from_room_profile(
	p_room_profile: _ProfileRoomScript,
	fallback_archetype: int = 0,
	fallback_purpose: int = 0
) -> _ArchitecturalPresentationProfileScript:
	if p_room_profile == null or p_room_profile.architecture == null:
		return resolve(fallback_archetype, fallback_purpose)

	var arch = p_room_profile.architecture
	var fallback_prof: _ArchitecturalPresentationProfileScript = null
	match fallback_archetype:
		_DungeonArchetypeScript.Type.MAUSOLEUM:
			fallback_prof = _resolve_mausoleum(fallback_purpose)
		_DungeonArchetypeScript.Type.FORTRESS:
			fallback_prof = _resolve_fortress(fallback_purpose)
		_DungeonArchetypeScript.Type.TEMPLE:
			fallback_prof = _resolve_temple(fallback_purpose)
		_DungeonArchetypeScript.Type.MINE:
			fallback_prof = _resolve_mine(fallback_purpose)
		_:
			fallback_prof = _resolve_generic(fallback_purpose)

	var floor_st = _ArchitecturalStyleScript.floor_from_name(str(arch.floor), fallback_prof.floor_style)
	var wall_st = _ArchitecturalStyleScript.wall_from_name(str(arch.walls), fallback_prof.wall_style)
	var door_st = _ArchitecturalStyleScript.door_from_name(str(arch.door), fallback_prof.door_style)
	var stairs_st = _ArchitecturalStyleScript.stairs_from_name(str(arch.stairs), fallback_prof.stairs_style)

	return _ArchitecturalPresentationProfileScript.new(
		floor_st,
		wall_st,
		door_st,
		stairs_st,
		fallback_prof.fixture_style,
		fallback_prof.decoration_palette
	)

func _resolve_mausoleum(purpose: int) -> _ArchitecturalPresentationProfileScript:
	match purpose:
		_RoomPurposeScript.Type.ROYAL_TOMB, _RoomPurposeScript.Type.SANCTUM:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.SMOOTH_SLABS,
				_ArchitecturalStyleScript.WallStyle.DARK_STONE,
				_ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.BRAZIER,
				_ArchitecturalStyleScript.DecorationPalette.CRYPT
			)
		_RoomPurposeScript.Type.SACRISTY:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.SMOOTH_SLABS,
				_ArchitecturalStyleScript.WallStyle.DARK_STONE,
				_ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.CANDLE_CLUSTER,
				_ArchitecturalStyleScript.DecorationPalette.CRYPT
			)
		_RoomPurposeScript.Type.TOMB:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.CATACOMB_DIRT,
				_ArchitecturalStyleScript.WallStyle.DARK_STONE,
				_ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.TORCH,
				_ArchitecturalStyleScript.DecorationPalette.CRYPT
			)
		_RoomPurposeScript.Type.MORTUARY, _RoomPurposeScript.Type.CRYPT:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
				_ArchitecturalStyleScript.WallStyle.DARK_STONE,
				_ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.BRAZIER,
				_ArchitecturalStyleScript.DecorationPalette.CRYPT
			)
		_RoomPurposeScript.Type.CATACOMB:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.CATACOMB_DIRT,
				_ArchitecturalStyleScript.WallStyle.DARK_STONE,
				_ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.TORCH,
				_ArchitecturalStyleScript.DecorationPalette.CRYPT
			)
		_: # ANTECHAMBER, ENTRANCE, etc.
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.SMOOTH_SLABS,
				_ArchitecturalStyleScript.WallStyle.DARK_STONE,
				_ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.LANTERN,
				_ArchitecturalStyleScript.DecorationPalette.CRYPT
			)

func _resolve_fortress(purpose: int) -> _ArchitecturalPresentationProfileScript:
	match purpose:
		_RoomPurposeScript.Type.THRONE_ROOM:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.SMOOTH_SLABS,
				_ArchitecturalStyleScript.WallStyle.FORTRESS_STONE,
				_ArchitecturalStyleScript.DoorStyle.ASSEMBLED_CLOSED,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.BRAZIER,
				_ArchitecturalStyleScript.DecorationPalette.ARMORY
			)
		_RoomPurposeScript.Type.ARMORY, _RoomPurposeScript.Type.GUARD_ROOM:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.COBBLESTONE,
				_ArchitecturalStyleScript.WallStyle.FORTRESS_STONE,
				_ArchitecturalStyleScript.DoorStyle.HEAVY_IRON,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.TORCH,
				_ArchitecturalStyleScript.DecorationPalette.ARMORY
			)
		_RoomPurposeScript.Type.BARRACKS, _RoomPurposeScript.Type.STORAGE:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.COBBLESTONE,
				_ArchitecturalStyleScript.WallStyle.FORTRESS_STONE,
				_ArchitecturalStyleScript.DoorStyle.WOOD_LEAF,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.LANTERN,
				_ArchitecturalStyleScript.DecorationPalette.BARRACKS
			)
		_:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.COBBLESTONE,
				_ArchitecturalStyleScript.WallStyle.FORTRESS_STONE,
				_ArchitecturalStyleScript.DoorStyle.WOOD_LEAF,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.TORCH,
				_ArchitecturalStyleScript.DecorationPalette.GENERIC
			)

func _resolve_temple(purpose: int) -> _ArchitecturalPresentationProfileScript:
	match purpose:
		_RoomPurposeScript.Type.SANCTUM, _RoomPurposeScript.Type.ALTAR_ROOM:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES,
				_ArchitecturalStyleScript.WallStyle.TEMPLE_STONE,
				_ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.CANDLE_CLUSTER,
				_ArchitecturalStyleScript.DecorationPalette.SANCTUM
			)
		_RoomPurposeScript.Type.LIBRARY, _RoomPurposeScript.Type.MEDITATION_ROOM:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES,
				_ArchitecturalStyleScript.WallStyle.TEMPLE_STONE,
				_ArchitecturalStyleScript.DoorStyle.WOOD_LEAF,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.CANDLE_HOLDER,
				_ArchitecturalStyleScript.DecorationPalette.LIBRARY
			)
		_:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES,
				_ArchitecturalStyleScript.WallStyle.TEMPLE_STONE,
				_ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
				_ArchitecturalStyleScript.StairsStyle.STONE,
				_ArchitecturalStyleScript.FixtureStyle.CANDLE_HOLDER,
				_ArchitecturalStyleScript.DecorationPalette.SANCTUM
			)

func _resolve_mine(purpose: int) -> _ArchitecturalPresentationProfileScript:
	match purpose:
		_RoomPurposeScript.Type.FORGE, _RoomPurposeScript.Type.WORKSHOP:
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.COBBLESTONE,
				_ArchitecturalStyleScript.WallStyle.MINE_ROCK,
				_ArchitecturalStyleScript.DoorStyle.MINE_FRAME,
				_ArchitecturalStyleScript.StairsStyle.WOOD,
				_ArchitecturalStyleScript.FixtureStyle.BRAZIER,
				_ArchitecturalStyleScript.DecorationPalette.MINE
			)
		_: # EXCAVATION, MINE_STORAGE, ORE_CHAMBER
			return _ArchitecturalPresentationProfileScript.new(
				_ArchitecturalStyleScript.FloorStyle.MINE_ROCK,
				_ArchitecturalStyleScript.WallStyle.MINE_ROCK,
				_ArchitecturalStyleScript.DoorStyle.MINE_FRAME,
				_ArchitecturalStyleScript.StairsStyle.WOOD,
				_ArchitecturalStyleScript.FixtureStyle.LANTERN,
				_ArchitecturalStyleScript.DecorationPalette.MINE
			)

func _resolve_generic(purpose: int) -> _ArchitecturalPresentationProfileScript:
	return _ArchitecturalPresentationProfileScript.new(
		_ArchitecturalStyleScript.FloorStyle.GENERIC_STONE,
		_ArchitecturalStyleScript.WallStyle.GENERIC_STONE,
		_ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
		_ArchitecturalStyleScript.StairsStyle.STONE,
		_ArchitecturalStyleScript.FixtureStyle.TORCH,
		_ArchitecturalStyleScript.DecorationPalette.GENERIC
	)
