extends SceneTree

const _ResolverScript = preload("res://src/floor_tile_generator/variants/floor_variant_resolver.gd")
const _PolicyScript = preload("res://src/dungeon_generator/profiles/profile_floor_variant_policy.gd")
const _ArchStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

func _init() -> void:
	print("--- Running test_floor_variant_determinism ---")
	var resolver = _ResolverScript.new()
	var policy = _PolicyScript.new(
		true,
		&"catacomb_dirt",
		80.0,
		[
			{ "style": &"ruined_stone", "weight": 20.0 }
		]
	)

	var run1: Array[int] = []
	var run2: Array[int] = []

	for x in range(10):
		for y in range(10):
			run1.append(resolver.resolve_cell_floor_style(Vector2i(x, y), 54321, policy, _ArchStyleScript.FloorStyle.CATACOMB_DIRT))

	for x in range(10):
		for y in range(10):
			run2.append(resolver.resolve_cell_floor_style(Vector2i(x, y), 54321, policy, _ArchStyleScript.FloorStyle.CATACOMB_DIRT))

	assert(run1 == run2, "Determinism failed across independent runs")

	var ruined_count: int = 0
	for st in run1:
		if st == _ArchStyleScript.FloorStyle.RUINED_STONE:
			ruined_count += 1

	assert(ruined_count > 5 and ruined_count < 35, "Ruined variant distribution out of expected bounds: %d/100" % ruined_count)
	print("  [OK] Floor variant resolution is 100% deterministic and follows weights")
	print("[PASS] test_floor_variant_determinism passed!")
	quit(0)
