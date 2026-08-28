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
	MINE_ROCK = 6,
	CATACOMB_DIRT = 7
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

static func palette_to_name(palette: int) -> String:
	for k in DecorationPalette.keys():
		if DecorationPalette[k] == palette:
			return k
	return "UNKNOWN"

static func floor_from_name(name_str: String, default_style: FloorStyle = FloorStyle.GENERIC_STONE) -> FloorStyle:
	match name_str.to_lower():
		"catacomb_dirt":
			return FloorStyle.CATACOMB_DIRT
		"ruined_stone", "ruined_tiles":
			return FloorStyle.RUINED_STONE
		"smooth_slabs":
			return FloorStyle.SMOOTH_SLABS
		"cobblestone":
			return FloorStyle.COBBLESTONE
		"brick":
			return FloorStyle.BRICK
		"temple_tiles":
			return FloorStyle.TEMPLE_TILES
		"mine_rock":
			return FloorStyle.MINE_ROCK
		"generic_stone":
			return FloorStyle.GENERIC_STONE
		_:
			return default_style

static func wall_from_name(name_str: String, default_style: WallStyle = WallStyle.GENERIC_STONE) -> WallStyle:
	match name_str.to_lower():
		"dark_stone":
			return WallStyle.DARK_STONE
		"fortress_stone":
			return WallStyle.FORTRESS_STONE
		"ancient_temple", "temple_stone":
			return WallStyle.TEMPLE_STONE
		"rough_rock", "mine_rock":
			return WallStyle.MINE_ROCK
		"generic_stone":
			return WallStyle.GENERIC_STONE
		_:
			return default_style

static func door_from_name(name_str: String, default_style: DoorStyle = DoorStyle.STONE_ARCH) -> DoorStyle:
	match name_str.to_lower():
		"stone_arch":
			return DoorStyle.STONE_ARCH
		"iron_gate", "heavy_iron":
			return DoorStyle.HEAVY_IRON
		"wood_beam", "wood_leaf", "wood":
			return DoorStyle.WOOD_LEAF
		"mine_frame":
			return DoorStyle.MINE_FRAME
		"assembled_closed":
			return DoorStyle.ASSEMBLED_CLOSED
		"assembled_locked":
			return DoorStyle.ASSEMBLED_LOCKED
		_:
			return default_style

static func stairs_from_name(name_str: String, default_style: StairsStyle = StairsStyle.STONE) -> StairsStyle:
	match name_str.to_lower():
		"stone":
			return StairsStyle.STONE
		"wood":
			return StairsStyle.WOOD
		_:
			return default_style

static func fixture_from_name(name_str: String, default_style: int = 0) -> int:
	match name_str.to_lower():
		"torch", "wall_torch":
			return FixtureStyle.TORCH
		"brazier":
			return FixtureStyle.BRAZIER
		"lantern", "wall_lantern", "hanging_lantern":
			return FixtureStyle.LANTERN
		"candle_holder":
			return FixtureStyle.CANDLE_HOLDER
		"candle_cluster":
			return FixtureStyle.CANDLE_CLUSTER
		_:
			return default_style

static func palette_from_name(name_str: String, default_palette: int = 0) -> int:
	match name_str.to_lower():
		"crypt", "mausoleum", "necropolis":
			return DecorationPalette.CRYPT
		"armory", "fortress":
			return DecorationPalette.ARMORY
		"sanctum", "temple":
			return DecorationPalette.SANCTUM
		"mine":
			return DecorationPalette.MINE
		"treasury":
			return DecorationPalette.TREASURY
		"library":
			return DecorationPalette.LIBRARY
		"barracks":
			return DecorationPalette.BARRACKS
		_:
			return default_palette
