class_name ArchitecturalStyle
extends RefCounted

## Identificadores canónicos de familias de estilo arquitectónico y decorativo.

enum FloorStyle {
	GENERIC_STONE = 0,
	RUINED_STONE = 1,
	COBBLESTONE = 2,
	BRICK = 3,
	SMOOTH_SLABS = 4,
	TEMPLE_TILES = 5,
	MINE_ROCK = 6
}

enum WallStyle {
	GENERIC_STONE = 0,
	DARK_STONE = 1,
	FORTRESS_STONE = 2,
	TEMPLE_STONE = 3,
	MINE_ROCK = 4
}

enum DoorStyle {
	STONE_ARCH = 0,
	WOOD_LEAF = 1,
	ASSEMBLED_CLOSED = 2,
	ASSEMBLED_LOCKED = 3,
	HEAVY_IRON = 4,
	MINE_FRAME = 5
}

enum StairsStyle {
	STONE = 0,
	WOOD = 1
}

enum FixtureStyle {
	TORCH = 0,
	BRAZIER = 1,
	LANTERN = 2,
	CANDLE_HOLDER = 3,
	CANDLE_CLUSTER = 4
}

enum DecorationPalette {
	GENERIC = 0,
	CRYPT = 1,
	ARMORY = 2,
	SANCTUM = 3,
	MINE = 4,
	TREASURY = 5,
	LIBRARY = 6,
	BARRACKS = 7
}

static func floor_to_name(style: FloorStyle) -> String:
	for k in FloorStyle.keys():
		if FloorStyle[k] == style:
			return k
	return "UNKNOWN"

static func wall_to_name(style: WallStyle) -> String:
	for k in WallStyle.keys():
		if WallStyle[k] == style:
			return k
	return "UNKNOWN"

static func door_to_name(style: DoorStyle) -> String:
	for k in DoorStyle.keys():
		if DoorStyle[k] == style:
			return k
	return "UNKNOWN"

static func stairs_to_name(style: StairsStyle) -> String:
	for k in StairsStyle.keys():
		if StairsStyle[k] == style:
			return k
	return "UNKNOWN"

static func fixture_to_name(style: int) -> String:
	for k in FixtureStyle.keys():
		if FixtureStyle[k] == style:
			return k
	return "UNKNOWN"

static func palette_to_name(palette: DecorationPalette) -> String:
	for k in DecorationPalette.keys():
		if DecorationPalette[k] == palette:
			return k
	return "UNKNOWN"
