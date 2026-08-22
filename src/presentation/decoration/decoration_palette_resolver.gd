class_name DecorationPaletteResolver
extends RefCounted

## Resolvedor puro de paletas de decoración a partir de arquetipos, propósito de sala y perfil arquitectónico.
## 100% puro: no crea nodos ni mallas 3D.

const _DecorationPaletteScript = preload("res://src/presentation/decoration/decoration_palette.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureCollisionModeScript = preload("res://src/presentation/fixtures/fixture_collision_mode.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")

## Resuelve la paleta de decoración completa (fixtures + props) para una sala.
func resolve_palette(
	archetype: int,
	room_purpose: int,
	profile: _ArchitecturalPresentationProfileScript
) -> _DecorationPaletteScript:
	var fix_palette: _FixturePaletteScript = null

	match archetype:
		_DungeonArchetypeScript.Type.MAUSOLEUM:
			fix_palette = _resolve_mausoleum_fixture_palette(room_purpose)
		_DungeonArchetypeScript.Type.TEMPLE:
			fix_palette = _resolve_temple_fixture_palette(room_purpose)
		_DungeonArchetypeScript.Type.FORTRESS:
			fix_palette = _resolve_fortress_fixture_palette(room_purpose)
		_DungeonArchetypeScript.Type.MINE:
			fix_palette = _resolve_mine_fixture_palette(room_purpose)
		_:
			fix_palette = _resolve_mausoleum_fixture_palette(room_purpose)

	return _DecorationPaletteScript.new(
		&"dec_palette_%s_%s" % [str(archetype), str(room_purpose)],
		fix_palette,
		null
	)

# ==============================================================================
# MAUSOLEUM / CRYPT PALETTES
# ==============================================================================
func _resolve_mausoleum_fixture_palette(room_purpose: int) -> _FixturePaletteScript:
	var entries: Array[_FixturePaletteEntryScript] = []

	var torch = _FixtureStyleScript.new(
		&"gothic_crypt_torch",
		_FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL,
		1.0, Vector3(0.0, 1.2, 0.0), false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(1.0, 0.62, 0.25, 1.0), 1.4, 6.5
	)
	var wall_lantern = _FixtureStyleScript.new(
		&"gothic_crypt_wall_lantern",
		_FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.WALL,
		1.0, Vector3(0.0, 1.3, 0.0), true, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(1.0, 0.70, 0.30, 1.0), 1.5, 7.0
	)
	var hanging_lantern = _FixtureStyleScript.new(
		&"gothic_crypt_hanging_lantern",
		_FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING,
		1.0, Vector3.ZERO, false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(1.0, 0.72, 0.32, 1.0), 1.6, 7.5
	)
	var brazier = _FixtureStyleScript.new(
		&"gothic_crypt_brazier",
		_FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0, Vector3.ZERO, false, _FixtureCollisionModeScript.Mode.STATIC_BODY,
		true, Color(1.0, 0.45, 0.15, 1.0), 2.0, 8.0
	)
	var candle_holder = _FixtureStyleScript.new(
		&"gothic_crypt_candle_holder",
		_FixtureStyleScript.Type.CANDLE_HOLDER,
		_FixturePlacementModeScript.Mode.SURFACE,
		1.0, Vector3.ZERO, false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(1.0, 0.80, 0.40, 1.0), 0.9, 4.5
	)
	var candle_cluster = _FixtureStyleScript.new(
		&"gothic_crypt_candle_cluster",
		_FixtureStyleScript.Type.CANDLE_CLUSTER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0, Vector3.ZERO, false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(1.0, 0.75, 0.35, 1.0), 1.1, 5.0
	)

	match room_purpose:
		_RoomPurposeScript.Type.TOMB, _RoomPurposeScript.Type.ROYAL_TOMB:
			entries.append(_FixturePaletteEntryScript.new(torch, 25.0))
			entries.append(_FixturePaletteEntryScript.new(wall_lantern, 75.0))
			entries.append(_FixturePaletteEntryScript.new(hanging_lantern, 50.0))
			entries.append(_FixturePaletteEntryScript.new(brazier, 70.0))
			entries.append(_FixturePaletteEntryScript.new(candle_cluster, 80.0))
			entries.append(_FixturePaletteEntryScript.new(candle_holder, 90.0))
			return _FixturePaletteScript.new(&"crypt_tomb_palette", entries, 3, 0.75, 4, 0.40)

		_RoomPurposeScript.Type.ENTRANCE, _RoomPurposeScript.Type.HALL, _RoomPurposeScript.Type.CHAMBER:
			entries.append(_FixturePaletteEntryScript.new(torch, 80.0))
			entries.append(_FixturePaletteEntryScript.new(wall_lantern, 20.0))
			entries.append(_FixturePaletteEntryScript.new(hanging_lantern, 30.0))
			entries.append(_FixturePaletteEntryScript.new(brazier, 35.0))
			entries.append(_FixturePaletteEntryScript.new(candle_cluster, 65.0))
			entries.append(_FixturePaletteEntryScript.new(candle_holder, 70.0))
			return _FixturePaletteScript.new(&"crypt_entrance_palette", entries, 3, 0.65, 5, 0.25)

		_RoomPurposeScript.Type.SACRISTY, _RoomPurposeScript.Type.CATACOMB:
			entries.append(_FixturePaletteEntryScript.new(torch, 15.0))
			entries.append(_FixturePaletteEntryScript.new(wall_lantern, 85.0))
			entries.append(_FixturePaletteEntryScript.new(hanging_lantern, 70.0))
			entries.append(_FixturePaletteEntryScript.new(brazier, 90.0))
			entries.append(_FixturePaletteEntryScript.new(candle_cluster, 95.0))
			entries.append(_FixturePaletteEntryScript.new(candle_holder, 95.0))
			return _FixturePaletteScript.new(&"crypt_sacristy_palette", entries, 3, 0.85, 3, 0.45)

		_: # CRYPT y genéricos
			entries.append(_FixturePaletteEntryScript.new(torch, 65.0))
			entries.append(_FixturePaletteEntryScript.new(wall_lantern, 35.0))
			entries.append(_FixturePaletteEntryScript.new(hanging_lantern, 40.0))
			entries.append(_FixturePaletteEntryScript.new(brazier, 50.0))
			entries.append(_FixturePaletteEntryScript.new(candle_cluster, 60.0))
			entries.append(_FixturePaletteEntryScript.new(candle_holder, 80.0))
			return _FixturePaletteScript.new(&"crypt_generic_palette", entries, 3, 0.65, 4, 0.30)

# ==============================================================================
# TEMPLE PALETTES
# ==============================================================================
func _resolve_temple_fixture_palette(room_purpose: int) -> _FixturePaletteScript:
	var entries: Array[_FixturePaletteEntryScript] = []
	var torch = _FixtureStyleScript.new(
		&"ceremonial_temple_torch", _FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL, 1.05, Vector3(0.0, 1.3, 0.0), false, 0,
		true, Color(1.0, 0.78, 0.35, 1.0), 1.6, 7.5
	)
	var hanging = _FixtureStyleScript.new(
		&"ceremonial_temple_hanging_lantern", _FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING, 1.05, Vector3.ZERO, false, 0,
		true, Color(1.0, 0.82, 0.40, 1.0), 1.7, 8.0
	)
	var brazier = _FixtureStyleScript.new(
		&"ceremonial_temple_brazier", _FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR, 1.1, Vector3.ZERO, false, 1,
		true, Color(1.0, 0.60, 0.20, 1.0), 2.2, 9.0
	)
	var candle_holder = _FixtureStyleScript.new(
		&"ceremonial_temple_candle_holder", _FixtureStyleScript.Type.CANDLE_HOLDER,
		_FixturePlacementModeScript.Mode.SURFACE, 1.0, Vector3.ZERO, false, 0,
		true, Color(1.0, 0.85, 0.45, 1.0), 1.0, 5.0
	)
	var candle_cluster = _FixtureStyleScript.new(
		&"ceremonial_temple_candle_cluster", _FixtureStyleScript.Type.CANDLE_CLUSTER,
		_FixturePlacementModeScript.Mode.FLOOR, 1.0, Vector3.ZERO, false, 0,
		true, Color(1.0, 0.85, 0.45, 1.0), 1.3, 5.5
	)

	entries.append(_FixturePaletteEntryScript.new(torch, 50.0))
	entries.append(_FixturePaletteEntryScript.new(hanging, 60.0))
	entries.append(_FixturePaletteEntryScript.new(brazier, 80.0))
	entries.append(_FixturePaletteEntryScript.new(candle_holder, 90.0))
	entries.append(_FixturePaletteEntryScript.new(candle_cluster, 70.0))
	return _FixturePaletteScript.new(&"temple_palette", entries, 4, 0.60, 5, 0.30)

# ==============================================================================
# FORTRESS PALETTES
# ==============================================================================
func _resolve_fortress_fixture_palette(room_purpose: int) -> _FixturePaletteScript:
	var entries: Array[_FixturePaletteEntryScript] = []
	var torch = _FixtureStyleScript.new(
		&"fortress_iron_torch", _FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL, 1.0, Vector3(0.0, 1.2, 0.0), false, 0,
		true, Color(1.0, 0.55, 0.20, 1.0), 1.3, 6.0
	)
	var wall_lantern = _FixtureStyleScript.new(
		&"fortress_iron_wall_lantern", _FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.WALL, 1.0, Vector3(0.0, 1.25, 0.0), true, 0,
		true, Color(1.0, 0.65, 0.25, 1.0), 1.4, 6.5
	)
	var brazier = _FixtureStyleScript.new(
		&"fortress_iron_brazier", _FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR, 1.0, Vector3.ZERO, false, 1,
		true, Color(1.0, 0.50, 0.18, 1.0), 1.8, 7.0
	)
	var candle_holder = _FixtureStyleScript.new(
		&"fortress_iron_candle_holder", _FixtureStyleScript.Type.CANDLE_HOLDER,
		_FixturePlacementModeScript.Mode.SURFACE, 0.9, Vector3.ZERO, false, 0,
		true, Color(1.0, 0.70, 0.30, 1.0), 0.8, 4.0
	)

	entries.append(_FixturePaletteEntryScript.new(torch, 70.0))
	entries.append(_FixturePaletteEntryScript.new(wall_lantern, 30.0))
	entries.append(_FixturePaletteEntryScript.new(brazier, 50.0))
	entries.append(_FixturePaletteEntryScript.new(candle_holder, 60.0))
	return _FixturePaletteScript.new(&"fortress_palette", entries, 3, 0.75, 5, 0.25)

# ==============================================================================
# MINE PALETTES
# ==============================================================================
func _resolve_mine_fixture_palette(room_purpose: int) -> _FixturePaletteScript:
	var entries: Array[_FixturePaletteEntryScript] = []
	var torch = _FixtureStyleScript.new(
		&"mine_shaft_torch", _FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL, 0.95, Vector3(0.0, 1.1, 0.0), false, 0,
		true, Color(1.0, 0.50, 0.18, 1.0), 1.2, 5.5
	)
	var hanging = _FixtureStyleScript.new(
		&"mine_shaft_hanging_lantern", _FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING, 0.95, Vector3.ZERO, false, 0,
		true, Color(1.0, 0.58, 0.22, 1.0), 1.3, 6.0
	)
	var candle_holder = _FixtureStyleScript.new(
		&"mine_shaft_candle_holder", _FixtureStyleScript.Type.CANDLE_HOLDER,
		_FixturePlacementModeScript.Mode.SURFACE, 0.9, Vector3.ZERO, false, 0,
		true, Color(1.0, 0.65, 0.25, 1.0), 0.8, 4.0
	)

	entries.append(_FixturePaletteEntryScript.new(torch, 60.0))
	entries.append(_FixturePaletteEntryScript.new(hanging, 40.0))
	entries.append(_FixturePaletteEntryScript.new(candle_holder, 50.0))
	return _FixturePaletteScript.new(&"mine_palette", entries, 3, 0.50, 6, 0.20)
