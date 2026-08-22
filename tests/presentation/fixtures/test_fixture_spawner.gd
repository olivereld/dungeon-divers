extends SceneTree

const FixtureSpawnerScript = preload("res://src/presentation/fixtures/fixture_spawner.gd")
const FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")
const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const BiomeProfileScript = preload("res://src/dungeon_generator/config/biome_profile.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_fixture_spawner ---")
	print("==================================================================")

	var spawner := FixtureSpawnerScript.new()
	var staging := Node3D.new()
	root.add_child(staging)
	var biome := BiomeProfileScript.new()

	# 1. Test Torch
	var torch_style := FixtureStyleScript.new(
		&"test_torch",
		FixtureStyleScript.Type.TORCH,
		FixturePlacementModeScript.Mode.WALL,
		1.0,
		Vector3.ZERO,
		false,
		0,
		true
	)
	var torch_dir := FixtureDirectiveScript.new(
		&"test_torch", 0, torch_style,
		FixturePlacementScript.new(FixturePlacementModeScript.Mode.WALL, Vector2i(2, 2), 0, Vector3(4.0, 1.2, 4.0))
	)

	# 2. Test Lantern (Wall Mounted)
	var lantern_style := FixtureStyleScript.new(
		&"test_wall_lantern",
		FixtureStyleScript.Type.LANTERN,
		FixturePlacementModeScript.Mode.WALL,
		1.0,
		Vector3.ZERO,
		true, # is_wall_mounted
		0,
		true
	)
	var lantern_dir := FixtureDirectiveScript.new(
		&"test_wall_lantern", 0, lantern_style,
		FixturePlacementScript.new(FixturePlacementModeScript.Mode.WALL, Vector2i(3, 2), 0, Vector3(6.0, 1.2, 4.0))
	)

	# 3. Test Brazier
	var brazier_style := FixtureStyleScript.new(
		&"test_brazier",
		FixtureStyleScript.Type.BRAZIER,
		FixturePlacementModeScript.Mode.FLOOR,
		1.0,
		Vector3.ZERO,
		false,
		1, # STATIC_BODY
		true
	)
	var brazier_dir := FixtureDirectiveScript.new(
		&"test_brazier", 0, brazier_style,
		FixturePlacementScript.new(FixturePlacementModeScript.Mode.FLOOR, Vector2i(4, 4), -1, Vector3(8.0, 0.0, 8.0))
	)

	# 4. Test Candle Holder
	var candle_style := FixtureStyleScript.new(
		&"test_candle_holder",
		FixtureStyleScript.Type.CANDLE_HOLDER,
		FixturePlacementModeScript.Mode.SURFACE,
		1.0,
		Vector3.ZERO,
		false,
		0,
		true
	)
	var candle_dir := FixtureDirectiveScript.new(
		&"test_candle_holder", 0, candle_style,
		FixturePlacementScript.new(FixturePlacementModeScript.Mode.SURFACE, Vector2i(5, 5), -1, Vector3(10.0, 0.8, 10.0))
	)

	# 5. Test Candle Cluster
	var cluster_style := FixtureStyleScript.new(
		&"test_candle_cluster",
		FixtureStyleScript.Type.CANDLE_CLUSTER,
		FixturePlacementModeScript.Mode.FLOOR,
		1.0,
		Vector3.ZERO,
		false,
		0,
		true
	)
	var cluster_dir := FixtureDirectiveScript.new(
		&"test_candle_cluster", 0, cluster_style,
		FixturePlacementScript.new(FixturePlacementModeScript.Mode.FLOOR, Vector2i(6, 6), -1, Vector3(12.0, 0.0, 12.0))
	)

	var directives = [torch_dir, lantern_dir, brazier_dir, candle_dir, cluster_dir]
	var res = spawner.spawn_fixtures(directives, staging, biome, 2.0)

	assert(res.spawned_fixtures.size() == 5, "FAIL: Must spawn 5 distinct fixture nodes")
	for node in res.spawned_fixtures:
		assert(node != null, "FAIL: Node cannot be null")
		assert(node.has_meta("fixture_directive"), "FAIL: Metadata fixture_directive missing")
		assert(node.get_node_or_null("FixtureLight") != null or node.get_node_or_null("TorchLight") != null, "FAIL: Light node missing")

	staging.queue_free()
	print("  [OK] Torch, Wall Lantern, Brazier, Candle Holder, Candle Cluster materialization verified.")
	print("[PASS] test_fixture_spawner completed successfully!")
	quit(0)
