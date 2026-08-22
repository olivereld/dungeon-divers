extends SceneTree

const FixtureAnchorScript = preload("res://src/presentation/fixtures/fixture_anchor.gd")
const FixtureCollisionModeScript = preload("res://src/presentation/fixtures/fixture_collision_mode.gd")
const FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_fixture_contracts ---")
	print("==================================================================")

	# 1. Validar FixtureAnchor
	assert(FixtureAnchorScript.Type.WALL == 0)
	assert(FixtureAnchorScript.Type.FLOOR == 1)
	assert(FixtureAnchorScript.Type.CEILING == 2)
	print("  [OK] FixtureAnchor enum validated.")

	# 2. Validar FixtureCollisionMode
	assert(FixtureCollisionModeScript.Mode.NONE == 0)
	assert(FixtureCollisionModeScript.Mode.STATIC_BODY == 1)
	assert(FixtureCollisionModeScript.Mode.TRIGGER_AREA == 2)
	print("  [OK] FixtureCollisionMode enum validated.")

	# 3. Validar FixtureStyle
	var style = FixtureStyleScript.new(
		&"gothic_wall_torch",
		FixtureStyleScript.Type.TORCH,
		1.0,
		Vector3(0, 1.2, 0),
		FixtureCollisionModeScript.Mode.NONE,
		true,
		Color(1.0, 0.6, 0.2),
		1.5,
		7.0
	)
	assert(style.id == &"gothic_wall_torch")
	assert(style.fixture_type == FixtureStyleScript.Type.TORCH)
	assert(style.has_light == true)
	print("  [OK] FixtureStyle resource validated.")

	# 4. Validar FixtureDirective
	var directive = FixtureDirectiveScript.new(
		&"gothic_wall_torch",
		0,
		FixtureAnchorScript.Type.WALL,
		Vector2i(4, 2),
		0,
		Vector3(8.0, 1.2, 4.0),
		0.0,
		1.0,
		style
	)
	assert(directive.fixture_id == &"gothic_wall_torch")
	assert(directive.room_id == 0)
	assert(directive.anchor == FixtureAnchorScript.Type.WALL)
	assert(directive.cell == Vector2i(4, 2))
	assert(directive.style == style)
	print("  [OK] FixtureDirective contract validated.")

	print("[PASS] test_fixture_contracts completed successfully!")
	quit(0)
