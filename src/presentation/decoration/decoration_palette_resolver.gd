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
const _PropPaletteScript = preload("res://src/presentation/props/prop_palette.gd")
const _PropPaletteEntryScript = preload("res://src/presentation/props/prop_palette_entry.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")
const _DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")

## Resuelve la paleta de decoración completa (fixtures + props) para una sala.
func resolve_palette(
	archetype: int,
	room_purpose: int,
	profile: _ArchitecturalPresentationProfileScript = null
) -> _DecorationPaletteScript:
	var fix_palette: _FixturePaletteScript = null
	var prop_palette: _PropPaletteScript = null

	match archetype:
		_DungeonArchetypeScript.Type.MAUSOLEUM:
			fix_palette = _resolve_mausoleum_fixture_palette(room_purpose)
			prop_palette = _resolve_mausoleum_prop_palette(room_purpose)
		_DungeonArchetypeScript.Type.TEMPLE:
			fix_palette = _resolve_temple_fixture_palette(room_purpose)
			prop_palette = _resolve_temple_prop_palette(room_purpose)
		_DungeonArchetypeScript.Type.FORTRESS:
			fix_palette = _resolve_fortress_fixture_palette(room_purpose)
			prop_palette = _resolve_fortress_prop_palette(room_purpose)
		_DungeonArchetypeScript.Type.MINE:
			fix_palette = _resolve_mine_fixture_palette(room_purpose)
			prop_palette = _resolve_mine_prop_palette(room_purpose)
		_:
			fix_palette = _resolve_mausoleum_fixture_palette(room_purpose)
			prop_palette = _resolve_mausoleum_prop_palette(room_purpose)

	return _DecorationPaletteScript.new(
		&"dec_palette_%s_%s" % [str(archetype), str(room_purpose)],
		fix_palette,
		prop_palette
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
		1.0, Vector3(0.0, 2.0, 0.0), false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(1.0, 0.62, 0.25, 1.0), 1.4, 6.5
	)
	var wall_lantern = _FixtureStyleScript.new(
		&"gothic_crypt_wall_lantern",
		_FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.WALL,
		1.0, Vector3(0.0, 2.0, 0.0), true, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(0.376, 0.161, 0.671, 1.0), 1.5, 7.0
	)
	var hanging_lantern = _FixtureStyleScript.new(
		&"gothic_crypt_hanging_lantern",
		_FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING,
		1.0, Vector3.ZERO, false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(0.376, 0.161, 0.671, 1.0), 1.6, 7.5
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
		true, Color(0.376, 0.161, 0.671, 1.0), 0.8, 3.2
	)
	var candle_cluster = _FixtureStyleScript.new(
		&"gothic_crypt_candle_cluster",
		_FixtureStyleScript.Type.CANDLE_CLUSTER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0, Vector3.ZERO, false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(0.376, 0.161, 0.671, 1.0), 0.6, 2.2
	)
	# Lámpara colgante reactivada con soporte de cadena volumétrica
	match room_purpose:
		_RoomPurposeScript.Type.TOMB, _RoomPurposeScript.Type.ROYAL_TOMB, _RoomPurposeScript.Type.SANCTUM:
			entries.append(_FixturePaletteEntryScript.new(torch, 25.0))
			entries.append(_FixturePaletteEntryScript.new(wall_lantern, 75.0))
			entries.append(_FixturePaletteEntryScript.new(hanging_lantern, 45.0))
			entries.append(_FixturePaletteEntryScript.new(brazier, 70.0))
			entries.append(_FixturePaletteEntryScript.new(candle_cluster, 80.0))
			entries.append(_FixturePaletteEntryScript.new(candle_holder, 90.0))
			return _FixturePaletteScript.new(&"crypt_tomb_palette", entries, 3, 0.75, 4, 0.40)

		_RoomPurposeScript.Type.ENTRANCE, _RoomPurposeScript.Type.HALL, _RoomPurposeScript.Type.CHAMBER:
			entries.append(_FixturePaletteEntryScript.new(torch, 80.0))
			entries.append(_FixturePaletteEntryScript.new(wall_lantern, 20.0))
			entries.append(_FixturePaletteEntryScript.new(hanging_lantern, 25.0))
			entries.append(_FixturePaletteEntryScript.new(brazier, 35.0))
			entries.append(_FixturePaletteEntryScript.new(candle_cluster, 65.0))
			entries.append(_FixturePaletteEntryScript.new(candle_holder, 70.0))
			return _FixturePaletteScript.new(&"crypt_entrance_palette", entries, 3, 0.65, 5, 0.25)

		_RoomPurposeScript.Type.SACRISTY, _RoomPurposeScript.Type.CATACOMB:
			entries.append(_FixturePaletteEntryScript.new(torch, 15.0))
			entries.append(_FixturePaletteEntryScript.new(wall_lantern, 85.0))
			entries.append(_FixturePaletteEntryScript.new(hanging_lantern, 35.0))
			entries.append(_FixturePaletteEntryScript.new(brazier, 90.0))
			entries.append(_FixturePaletteEntryScript.new(candle_cluster, 95.0))
			entries.append(_FixturePaletteEntryScript.new(candle_holder, 95.0))
			return _FixturePaletteScript.new(&"crypt_sacristy_palette", entries, 3, 0.85, 3, 0.45)

		_: # CRYPT y genéricos
			entries.append(_FixturePaletteEntryScript.new(torch, 65.0))
			entries.append(_FixturePaletteEntryScript.new(wall_lantern, 35.0))
			entries.append(_FixturePaletteEntryScript.new(hanging_lantern, 30.0))
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
		_FixturePlacementModeScript.Mode.WALL, 1.05, Vector3(0.0, 2.0, 0.0), false, 0,
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
		_FixturePlacementModeScript.Mode.WALL, 1.0, Vector3(0.0, 2.0, 0.0), false, 0,
		true, Color(1.0, 0.55, 0.20, 1.0), 1.3, 6.0
	)
	var wall_lantern = _FixtureStyleScript.new(
		&"fortress_iron_wall_lantern", _FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.WALL, 1.0, Vector3(0.0, 2.0, 0.0), true, 0,
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
		_FixturePlacementModeScript.Mode.WALL, 0.95, Vector3(0.0, 2.0, 0.0), false, 0,
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

# ==============================================================================
# PROP PALETTES (FASE 5 & 6)
# ==============================================================================

func _resolve_mausoleum_prop_palette(room_purpose: int) -> _PropPaletteScript:
	var entries: Array[_PropPaletteEntryScript] = []

	var sarc_closed = _PropStyleScript.new(
		&"sarcophagus_stone_closed", _PropStyleScript.Type.SARCOPHAGUS,
		_PropPlacementModeScript.Mode.CENTER, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"sarcophagus_prop", {"style": 0, "is_open": false},
		_DecorationRoleScript.Role.FOCAL,
		[_DecorationTagScript.BURIAL, _DecorationTagScript.FOCAL, _DecorationTagScript.FURNITURE]
	)
	var sarc_open = _PropStyleScript.new(
		&"sarcophagus_stone_open", _PropStyleScript.Type.SARCOPHAGUS,
		_PropPlacementModeScript.Mode.FLOOR, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"sarcophagus_prop", {"style": 0, "is_open": true},
		_DecorationRoleScript.Role.FOCAL,
		[_DecorationTagScript.BURIAL, _DecorationTagScript.FOCAL, _DecorationTagScript.FURNITURE]
	)
	var tombstone_wall = _PropStyleScript.new(
		&"tombstone_classic_wall", _PropStyleScript.Type.TOMBSTONE,
		_PropPlacementModeScript.Mode.WALL, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"tombstone_prop", {"style": 0},
		_DecorationRoleScript.Role.SUPPORT,
		[_DecorationTagScript.BURIAL, _DecorationTagScript.WALL_DECOR]
	)
	var tombstone_corner = _PropStyleScript.new(
		&"tombstone_cross_corner", _PropStyleScript.Type.TOMBSTONE,
		_PropPlacementModeScript.Mode.CORNER, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"tombstone_prop", {"style": 1},
		_DecorationRoleScript.Role.SUPPORT,
		[_DecorationTagScript.BURIAL, _DecorationTagScript.CORNER_DECOR]
	)
	var altar = _PropStyleScript.new(
		&"stone_altar_center", _PropStyleScript.Type.ALTAR,
		_PropPlacementModeScript.Mode.CENTER, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"altar_prop", {"style": 1},
		_DecorationRoleScript.Role.FOCAL,
		[_DecorationTagScript.CEREMONIAL, _DecorationTagScript.FOCAL, _DecorationTagScript.FURNITURE]
	)
	var bench_pew = _PropStyleScript.new(
		&"church_pew_wall", _PropStyleScript.Type.BENCH,
		_PropPlacementModeScript.Mode.WALL, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"bench_prop", {"style": 0},
		_DecorationRoleScript.Role.SUPPORT,
		[_DecorationTagScript.SEATING, _DecorationTagScript.WALL_DECOR, _DecorationTagScript.FURNITURE]
	)
	var bench_stone = _PropStyleScript.new(
		&"stone_orior_floor", _PropStyleScript.Type.BENCH,
		_PropPlacementModeScript.Mode.FLOOR, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"bench_prop", {"style": 1},
		_DecorationRoleScript.Role.SUPPORT,
		[_DecorationTagScript.SEATING, _DecorationTagScript.FURNITURE]
	)
	var rubble_corner = _PropStyleScript.new(
		&"crypt_rubble_corner", _PropStyleScript.Type.RUBBLE,
		_PropPlacementModeScript.Mode.CORNER, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"rubble_prop", {},
		_DecorationRoleScript.Role.AMBIENT,
		[_DecorationTagScript.DEBRIS, _DecorationTagScript.CORNER_DECOR]
	)
	var urn_banded_floor = _PropStyleScript.new(
		&"crypt_urn_banded_floor", _PropStyleScript.Type.URN,
		_PropPlacementModeScript.Mode.FLOOR, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"urn_prop", {"style": 0, "scale": 1.0, "has_lid": true},
		_DecorationRoleScript.Role.SUPPORT,
		[_DecorationTagScript.BURIAL, _DecorationTagScript.DETAIL]
	)
	var urn_relic_floor = _PropStyleScript.new(
		&"crypt_urn_relic_floor", _PropStyleScript.Type.URN,
		_PropPlacementModeScript.Mode.FLOOR, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"urn_prop", {"style": 1, "scale": 1.0, "has_lid": true},
		_DecorationRoleScript.Role.SUPPORT,
		[_DecorationTagScript.BURIAL, _DecorationTagScript.DETAIL]
	)
	var urn_pedestal_floor = _PropStyleScript.new(
		&"temple_urn_pedestal_floor", _PropStyleScript.Type.URN,
		_PropPlacementModeScript.Mode.FLOOR, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"urn_prop", {"style": 2, "scale": 1.0, "has_lid": true},
		_DecorationRoleScript.Role.SUPPORT,
		[_DecorationTagScript.BURIAL, _DecorationTagScript.DETAIL]
	)
	var urn_canopic_surface = _PropStyleScript.new(
		&"crypt_urn_canopic_surface", _PropStyleScript.Type.URN,
		_PropPlacementModeScript.Mode.CORNER, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"urn_prop", {"style": 3, "scale": 0.65, "has_lid": true},
		_DecorationRoleScript.Role.AMBIENT,
		[_DecorationTagScript.BURIAL, _DecorationTagScript.DETAIL]
	)

	match room_purpose:
		_RoomPurposeScript.Type.TOMB:
			entries.append(_PropPaletteEntryScript.new(sarc_closed, 80.0))
			entries.append(_PropPaletteEntryScript.new(sarc_open, 30.0))
			entries.append(_PropPaletteEntryScript.new(tombstone_wall, 60.0))
			entries.append(_PropPaletteEntryScript.new(tombstone_corner, 40.0))
			entries.append(_PropPaletteEntryScript.new(urn_banded_floor, 55.0))
			entries.append(_PropPaletteEntryScript.new(urn_relic_floor, 50.0))
			entries.append(_PropPaletteEntryScript.new(urn_canopic_surface, 35.0))
			entries.append(_PropPaletteEntryScript.new(rubble_corner, 40.0))
			var pal := _PropPaletteScript.new(&"crypt_props_tomb", entries)
			pal.density = 0.38
			pal.max_props_per_room = 10
			return pal

		_RoomPurposeScript.Type.ROYAL_TOMB, _RoomPurposeScript.Type.SANCTUM:
			entries.append(_PropPaletteEntryScript.new(sarc_closed, 90.0))
			entries.append(_PropPaletteEntryScript.new(sarc_open, 20.0))
			entries.append(_PropPaletteEntryScript.new(altar, 75.0))
			entries.append(_PropPaletteEntryScript.new(tombstone_corner, 60.0))
			entries.append(_PropPaletteEntryScript.new(urn_pedestal_floor, 65.0))
			entries.append(_PropPaletteEntryScript.new(urn_relic_floor, 50.0))
			entries.append(_PropPaletteEntryScript.new(urn_canopic_surface, 40.0))
			entries.append(_PropPaletteEntryScript.new(bench_stone, 40.0))
			entries.append(_PropPaletteEntryScript.new(bench_pew, 50.0))
			var pal := _PropPaletteScript.new(&"crypt_props_royal_tomb", entries)
			pal.density = 0.42
			pal.max_props_per_room = 12
			return pal

		_RoomPurposeScript.Type.MORTUARY:
			entries.append(_PropPaletteEntryScript.new(altar, 80.0))
			entries.append(_PropPaletteEntryScript.new(sarc_open, 60.0))
			entries.append(_PropPaletteEntryScript.new(tombstone_wall, 50.0))
			entries.append(_PropPaletteEntryScript.new(urn_relic_floor, 60.0))
			entries.append(_PropPaletteEntryScript.new(urn_canopic_surface, 45.0))
			entries.append(_PropPaletteEntryScript.new(rubble_corner, 60.0))
			var pal := _PropPaletteScript.new(&"crypt_props_mortuary", entries)
			pal.density = 0.40
			pal.max_props_per_room = 10
			return pal

		_RoomPurposeScript.Type.SACRISTY, _RoomPurposeScript.Type.ALTAR_ROOM:
			entries.append(_PropPaletteEntryScript.new(altar, 90.0))
			entries.append(_PropPaletteEntryScript.new(bench_pew, 70.0))
			entries.append(_PropPaletteEntryScript.new(bench_stone, 40.0))
			entries.append(_PropPaletteEntryScript.new(urn_canopic_surface, 60.0))
			entries.append(_PropPaletteEntryScript.new(urn_pedestal_floor, 45.0))
			entries.append(_PropPaletteEntryScript.new(tombstone_corner, 20.0))
			entries.append(_PropPaletteEntryScript.new(rubble_corner, 20.0))
			var pal := _PropPaletteScript.new(&"crypt_props_sacristy", entries)
			pal.density = 0.35
			pal.max_props_per_room = 8
			return pal

		_RoomPurposeScript.Type.CRYPT, _RoomPurposeScript.Type.CATACOMB:
			entries.append(_PropPaletteEntryScript.new(sarc_open, 70.0))
			entries.append(_PropPaletteEntryScript.new(sarc_closed, 50.0))
			entries.append(_PropPaletteEntryScript.new(tombstone_wall, 40.0))
			entries.append(_PropPaletteEntryScript.new(urn_banded_floor, 75.0))
			entries.append(_PropPaletteEntryScript.new(urn_relic_floor, 65.0))
			entries.append(_PropPaletteEntryScript.new(urn_canopic_surface, 40.0))
			entries.append(_PropPaletteEntryScript.new(rubble_corner, 60.0))
			var pal := _PropPaletteScript.new(&"crypt_props_crypt", entries)
			pal.density = 0.38
			pal.max_props_per_room = 10
			return pal

		_: # ANTECHAMBER, ENTRANCE, HALL, etc.
			entries.append(_PropPaletteEntryScript.new(bench_pew, 70.0))
			entries.append(_PropPaletteEntryScript.new(bench_stone, 50.0))
			entries.append(_PropPaletteEntryScript.new(urn_banded_floor, 40.0))
			entries.append(_PropPaletteEntryScript.new(tombstone_wall, 30.0))
			entries.append(_PropPaletteEntryScript.new(rubble_corner, 40.0))
			var pal := _PropPaletteScript.new(&"crypt_props_antechamber", entries)
			pal.density = 0.30
			pal.max_props_per_room = 7
			return pal

func _resolve_temple_prop_palette(room_purpose: int) -> _PropPaletteScript:
	var entries: Array[_PropPaletteEntryScript] = []
	var altar = _PropStyleScript.new(
		&"temple_altar_center", _PropStyleScript.Type.ALTAR,
		_PropPlacementModeScript.Mode.CENTER, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"altar_prop", {"style": 2},
		_DecorationRoleScript.Role.FOCAL
	)
	var bench_pew = _PropStyleScript.new(
		&"temple_pew_floor", _PropStyleScript.Type.BENCH,
		_PropPlacementModeScript.Mode.FLOOR, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"bench_prop", {"style": 0},
		_DecorationRoleScript.Role.SUPPORT
	)
	var bench_wall = _PropStyleScript.new(
		&"temple_pew_wall", _PropStyleScript.Type.BENCH,
		_PropPlacementModeScript.Mode.WALL, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"bench_prop", {"style": 0},
		_DecorationRoleScript.Role.SUPPORT
	)
	var urn_pedestal_floor = _PropStyleScript.new(
		&"temple_urn_pedestal_floor", _PropStyleScript.Type.URN,
		_PropPlacementModeScript.Mode.FLOOR, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"urn_prop", {"style": 2, "scale": 1.0, "has_lid": true},
		_DecorationRoleScript.Role.SUPPORT
	)
	var urn_canopic_surface = _PropStyleScript.new(
		&"temple_urn_canopic_surface", _PropStyleScript.Type.URN,
		_PropPlacementModeScript.Mode.CORNER, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"urn_prop", {"style": 3, "scale": 0.65, "has_lid": true},
		_DecorationRoleScript.Role.AMBIENT
	)

	entries.append(_PropPaletteEntryScript.new(altar, 80.0))
	entries.append(_PropPaletteEntryScript.new(bench_pew, 60.0))
	entries.append(_PropPaletteEntryScript.new(bench_wall, 40.0))
	entries.append(_PropPaletteEntryScript.new(urn_pedestal_floor, 55.0))
	entries.append(_PropPaletteEntryScript.new(urn_canopic_surface, 45.0))

	var palette := _PropPaletteScript.new(&"temple_props", entries)
	palette.density = 0.32
	palette.max_props_per_room = 6
	return palette

func _resolve_fortress_prop_palette(room_purpose: int) -> _PropPaletteScript:
	var entries: Array[_PropPaletteEntryScript] = []
	var table = _PropStyleScript.new(
		&"fortress_table_center", _PropStyleScript.Type.TABLE,
		_PropPlacementModeScript.Mode.CENTER, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"table_prop", {"style": 0},
		_DecorationRoleScript.Role.FOCAL
	)
	var bench = _PropStyleScript.new(
		&"fortress_bench_wall", _PropStyleScript.Type.BENCH,
		_PropPlacementModeScript.Mode.WALL, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(2, 1)), &"bench_prop", {"style": 3},
		_DecorationRoleScript.Role.SUPPORT
	)
	var shelf = _PropStyleScript.new(
		&"fortress_bookshelf_wall", _PropStyleScript.Type.BOOKSHELF,
		_PropPlacementModeScript.Mode.WALL, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"bookshelf_prop", {"style": 0},
		_DecorationRoleScript.Role.SUPPORT
	)
	var chest = _PropStyleScript.new(
		&"fortress_chest_corner", _PropStyleScript.Type.CHEST,
		_PropPlacementModeScript.Mode.CORNER, _PropCollisionModeScript.Mode.INTERACTIVE,
		_PropFootprintScript.new(Vector2i(1, 1)), &"chest_prop", {"is_open": false},
		_DecorationRoleScript.Role.FUNCTIONAL
	)

	entries.append(_PropPaletteEntryScript.new(table, 60.0))
	entries.append(_PropPaletteEntryScript.new(bench, 50.0))
	entries.append(_PropPaletteEntryScript.new(shelf, 40.0))
	entries.append(_PropPaletteEntryScript.new(chest, 35.0))

	var palette := _PropPaletteScript.new(&"fortress_props", entries)
	palette.density = 0.30
	palette.max_props_per_room = 5
	return palette

func _resolve_mine_prop_palette(room_purpose: int) -> _PropPaletteScript:
	var entries: Array[_PropPaletteEntryScript] = []
	var crate = _PropStyleScript.new(
		&"mine_crate_corner", _PropStyleScript.Type.CRATE,
		_PropPlacementModeScript.Mode.CORNER, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"crate_prop", {},
		_DecorationRoleScript.Role.AMBIENT
	)
	var rubble = _PropStyleScript.new(
		&"mine_rubble_floor", _PropStyleScript.Type.RUBBLE,
		_PropPlacementModeScript.Mode.FLOOR, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"rubble_prop", {},
		_DecorationRoleScript.Role.AMBIENT
	)
	var barrel = _PropStyleScript.new(
		&"mine_barrel_wall", _PropStyleScript.Type.BARREL,
		_PropPlacementModeScript.Mode.WALL, _PropCollisionModeScript.Mode.BLOCKING,
		_PropFootprintScript.new(Vector2i(1, 1)), &"barrel_prop", {},
		_DecorationRoleScript.Role.AMBIENT
	)

	entries.append(_PropPaletteEntryScript.new(crate, 60.0))
	entries.append(_PropPaletteEntryScript.new(rubble, 70.0))
	entries.append(_PropPaletteEntryScript.new(barrel, 50.0))

	var palette := _PropPaletteScript.new(&"mine_props", entries)
	palette.density = 0.25
	palette.max_props_per_room = 4
	return palette
