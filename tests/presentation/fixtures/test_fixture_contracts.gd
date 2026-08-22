extends SceneTree

const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const FixtureCollisionModeScript = preload("res://src/presentation/fixtures/fixture_collision_mode.gd")
const FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")
const FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_fixture_contracts ---")
	print("==================================================================")

	# 1. Validar FixturePlacementMode
	assert(FixturePlacementModeScript.Mode.WALL == 0)
	assert(FixturePlacementModeScript.Mode.FLOOR == 1)
	assert(FixturePlacementModeScript.Mode.SURFACE == 2)
	assert(FixturePlacementModeScript.Mode.HANGING == 3)
	assert(FixturePlacementModeScript.mode_to_name(0) == "WALL")
	assert(FixturePlacementModeScript.mode_to_name(1) == "FLOOR")
	assert(FixturePlacementModeScript.mode_to_name(2) == "SURFACE")
	assert(FixturePlacementModeScript.mode_to_name(3) == "HANGING")
	print("  [OK] FixturePlacementMode enum and names validated.")

	# 2. Validar FixtureCollisionMode
	assert(FixtureCollisionModeScript.Mode.NONE == 0)
	assert(FixtureCollisionModeScript.Mode.STATIC_BODY == 1)
	assert(FixtureCollisionModeScript.Mode.TRIGGER_AREA == 2)
	print("  [OK] FixtureCollisionMode enum validated.")

	# 3. Validar FixturePlacement
	var placement = FixturePlacementScript.new(
		FixturePlacementModeScript.Mode.WALL,
		Vector2i(4, 2),
		0,
		Vector3(8.0, 1.2, 4.0),
		0.0,
		Vector3(0.0, 0.0, 1.0)
	)
	assert(placement.mode == FixturePlacementModeScript.Mode.WALL)
	assert(placement.cell == Vector2i(4, 2))
	assert(placement.wall_side == 0)
	assert(placement.position == Vector3(8.0, 1.2, 4.0))
	print("  [OK] FixturePlacement validated.")

	# 4. Validar FixtureStyle
	var style = FixtureStyleScript.new(
		&"gothic_wall_torch",
		FixtureStyleScript.Type.TORCH,
		FixturePlacementModeScript.Mode.WALL,
		1.0,
		Vector3(0, 1.2, 0),
		false,
		FixtureCollisionModeScript.Mode.NONE,
		true,
		Color(1.0, 0.6, 0.2),
		1.5,
		7.0
	)
	assert(style.id == &"gothic_wall_torch")
	assert(style.fixture_type == FixtureStyleScript.Type.TORCH)
	assert(style.placement_mode == FixturePlacementModeScript.Mode.WALL)
	assert(style.has_light == true)
	print("  [OK] FixtureStyle resource validated.")

	# 5. Validar FixtureDirective
	var directive = FixtureDirectiveScript.new(
		&"gothic_wall_torch",
		0,
		style,
		placement,
		1.0
	)
	assert(directive.fixture_id == &"gothic_wall_torch")
	assert(directive.room_id == 0)
	assert(directive.placement == placement)
	assert(directive.cell == Vector2i(4, 2))
	assert(directive.world_position == Vector3(8.0, 1.2, 4.0))
	assert(directive.style == style)
	print("  [OK] FixtureDirective contract and delegation validated.")

	# 6. Validar FixturePalette
	var palette = FixturePaletteScript.new(&"test_palette", [style])
	assert(palette.fixtures.size() == 1)
	var wall_fixtures = palette.get_fixtures_by_placement(FixturePlacementModeScript.Mode.WALL)
	assert(wall_fixtures.size() == 1)
	assert(wall_fixtures[0] == style)
	print("  [OK] FixturePalette list and query validated.")

	print("[PASS] test_fixture_contracts completed successfully!")
	quit(0)
