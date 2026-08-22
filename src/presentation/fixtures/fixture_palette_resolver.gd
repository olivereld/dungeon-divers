class_name FixturePaletteResolver
extends RefCounted

## Resolvedor puro de paletas de fixtures a partir de perfiles arquitectónicos.
## 100% puro: no genera nodos 3D ni mallas.

const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureCollisionModeScript = preload("res://src/presentation/fixtures/fixture_collision_mode.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

## Devuelve una FixturePalette configurada según el perfil arquitectónico provisto.
func resolve_palette(profile: _ArchitecturalPresentationProfileScript) -> _FixturePaletteScript:
	if profile == null:
		return _create_default_palette()

	var fixtures_list: Array = []
	var palette_id: StringName = &"generic_palette"
	var wall_spacing: int = 3
	var wall_prob: float = 0.65
	var floor_spacing: int = 4
	var floor_prob: float = 0.30

	match profile.wall_style:
		_ArchitecturalStyleScript.WallStyle.DARK_STONE:
			# Criptas / Mausoleos: Antorchas góticas, faroles de pared/colgantes, braseros de pie, candelabros y cúmulos de velas
			palette_id = &"gothic_crypt_palette"
			fixtures_list.append(_FixtureStyleScript.new(
				&"gothic_crypt_torch",
				_FixtureStyleScript.Type.TORCH,
				_FixturePlacementModeScript.Mode.WALL,
				1.0,
				Vector3(0.0, 2.0, 0.0),
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.62, 0.25, 1.0),
				1.4,
				6.5
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"gothic_crypt_wall_lantern",
				_FixtureStyleScript.Type.LANTERN,
				_FixturePlacementModeScript.Mode.WALL,
				1.0,
				Vector3(0.0, 2.0, 0.0),
				true,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(0.82, 0.38, 0.96, 1.0),
				2.4,
				8.0
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"gothic_crypt_hanging_lantern",
				_FixtureStyleScript.Type.LANTERN,
				_FixturePlacementModeScript.Mode.HANGING,
				1.0,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(0.82, 0.38, 0.96, 1.0),
				2.5,
				8.5
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"gothic_crypt_brazier",
				_FixtureStyleScript.Type.BRAZIER,
				_FixturePlacementModeScript.Mode.FLOOR,
				1.0,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.STATIC_BODY,
				true,
				Color(1.0, 0.45, 0.15, 1.0),
				2.0,
				8.0
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"gothic_crypt_candle_holder",
				_FixtureStyleScript.Type.CANDLE_HOLDER,
				_FixturePlacementModeScript.Mode.SURFACE,
				1.0,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(0.376, 0.161, 0.671, 1.0),
				0.8,
				3.2
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"gothic_crypt_candle_cluster",
				_FixtureStyleScript.Type.CANDLE_CLUSTER,
				_FixturePlacementModeScript.Mode.FLOOR,
				1.0,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(0.376, 0.161, 0.671, 1.0),
				0.6,
				2.2
			))
			wall_spacing = 3
			wall_prob = 0.70
			floor_spacing = 4
			floor_prob = 0.35

		_ArchitecturalStyleScript.WallStyle.TEMPLE_STONE:
			# Templos / Santuarios: Antorcha ceremonial, faroles, braseros sagrados y cúmulos de velas
			palette_id = &"ceremonial_temple_palette"
			fixtures_list.append(_FixtureStyleScript.new(
				&"ceremonial_temple_torch",
				_FixtureStyleScript.Type.TORCH,
				_FixturePlacementModeScript.Mode.WALL,
				1.05,
				Vector3(0.0, 2.0, 0.0),
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.78, 0.35, 1.0),
				1.6,
				7.5
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"ceremonial_temple_hanging_lantern",
				_FixtureStyleScript.Type.LANTERN,
				_FixturePlacementModeScript.Mode.HANGING,
				1.05,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.82, 0.40, 1.0),
				2.4,
				8.5
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"ceremonial_temple_brazier",
				_FixtureStyleScript.Type.BRAZIER,
				_FixturePlacementModeScript.Mode.FLOOR,
				1.1,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.STATIC_BODY,
				true,
				Color(1.0, 0.60, 0.20, 1.0),
				2.2,
				9.0
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"ceremonial_temple_candle_holder",
				_FixtureStyleScript.Type.CANDLE_HOLDER,
				_FixturePlacementModeScript.Mode.SURFACE,
				1.0,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.85, 0.45, 1.0),
				1.0,
				5.0
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"ceremonial_temple_candle_cluster",
				_FixtureStyleScript.Type.CANDLE_CLUSTER,
				_FixturePlacementModeScript.Mode.FLOOR,
				1.0,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.85, 0.45, 1.0),
				1.3,
				5.5
			))
			wall_spacing = 4
			wall_prob = 0.60
			floor_spacing = 5
			floor_prob = 0.30

		_ArchitecturalStyleScript.WallStyle.FORTRESS_STONE:
			# Fortalezas: Antorchas militares de hierro, faroles de pared y braseros
			palette_id = &"fortress_iron_palette"
			fixtures_list.append(_FixtureStyleScript.new(
				&"fortress_iron_torch",
				_FixtureStyleScript.Type.TORCH,
				_FixturePlacementModeScript.Mode.WALL,
				1.0,
				Vector3(0.0, 2.0, 0.0),
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.55, 0.20, 1.0),
				1.3,
				6.0
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"fortress_iron_wall_lantern",
				_FixtureStyleScript.Type.LANTERN,
				_FixturePlacementModeScript.Mode.WALL,
				1.0,
				Vector3(0.0, 2.0, 0.0),
				true,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.65, 0.25, 1.0),
				2.3,
				8.0
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"fortress_iron_brazier",
				_FixtureStyleScript.Type.BRAZIER,
				_FixturePlacementModeScript.Mode.FLOOR,
				1.0,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.STATIC_BODY,
				true,
				Color(1.0, 0.50, 0.18, 1.0),
				1.8,
				7.0
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"fortress_iron_candle_holder",
				_FixtureStyleScript.Type.CANDLE_HOLDER,
				_FixturePlacementModeScript.Mode.SURFACE,
				0.9,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.70, 0.30, 1.0),
				0.8,
				4.0
			))
			wall_spacing = 3
			wall_prob = 0.75
			floor_spacing = 5
			floor_prob = 0.25

		_ArchitecturalStyleScript.WallStyle.MINE_ROCK:
			# Minas: Antorchas utilitarias, faroles colgantes y candeleros
			palette_id = &"mine_shaft_palette"
			fixtures_list.append(_FixtureStyleScript.new(
				&"mine_shaft_torch",
				_FixtureStyleScript.Type.TORCH,
				_FixturePlacementModeScript.Mode.WALL,
				0.95,
				Vector3(0.0, 2.0, 0.0),
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.50, 0.18, 1.0),
				1.2,
				5.5
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"mine_shaft_hanging_lantern",
				_FixtureStyleScript.Type.LANTERN,
				_FixturePlacementModeScript.Mode.HANGING,
				0.95,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.58, 0.22, 1.0),
				2.2,
				8.0
			))
			fixtures_list.append(_FixtureStyleScript.new(
				&"mine_shaft_candle_holder",
				_FixtureStyleScript.Type.CANDLE_HOLDER,
				_FixturePlacementModeScript.Mode.SURFACE,
				0.9,
				Vector3.ZERO,
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				Color(1.0, 0.65, 0.25, 1.0),
				0.8,
				4.0
			))
			wall_spacing = 3
			wall_prob = 0.50
			floor_spacing = 6
			floor_prob = 0.20

		_:
			return _create_default_palette()

	return _FixturePaletteScript.new(palette_id, fixtures_list, wall_spacing, wall_prob, floor_spacing, floor_prob)

func _create_default_palette() -> _FixturePaletteScript:
	var default_torch = _FixtureStyleScript.new(
		&"standard_wall_torch",
		_FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL,
		1.0,
		Vector3(0.0, 1.2, 0.0),
		false,
		_FixtureCollisionModeScript.Mode.NONE,
		true,
		Color(1.0, 0.65, 0.28, 1.0),
		1.2,
		6.0
	)
	var default_brazier = _FixtureStyleScript.new(
		&"standard_brazier",
		_FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0,
		Vector3.ZERO,
		false,
		_FixtureCollisionModeScript.Mode.STATIC_BODY,
		true,
		Color(1.0, 0.55, 0.20, 1.0),
		1.8,
		7.0
	)
	var default_candle = _FixtureStyleScript.new(
		&"standard_candle_holder",
		_FixtureStyleScript.Type.CANDLE_HOLDER,
		_FixturePlacementModeScript.Mode.SURFACE,
		1.0,
		Vector3.ZERO,
		false,
		_FixtureCollisionModeScript.Mode.NONE,
		true,
		Color(1.0, 0.75, 0.35, 1.0),
		0.9,
		4.5
	)
	var default_hanging = _FixtureStyleScript.new(
		&"standard_hanging_lantern",
		_FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING,
		1.0,
		Vector3.ZERO,
		false,
		_FixtureCollisionModeScript.Mode.NONE,
		true,
		Color(1.0, 0.70, 0.30, 1.0),
		1.4,
		6.5
	)
	return _FixturePaletteScript.new(
		&"default_palette",
		[default_torch, default_brazier, default_candle, default_hanging],
		3, 0.6, 4, 0.3
	)
