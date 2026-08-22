extends SceneTree

const FixtureSpawnerScript = preload("res://src/presentation/fixtures/fixture_spawner.gd")
const FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const FixtureAnchorScript = preload("res://src/presentation/fixtures/fixture_anchor.gd")
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

	var style := FixtureStyleScript.new(
		&"gothic_test_torch",
		FixtureStyleScript.Type.TORCH,
		1.0,
		Vector3.ZERO,
		0,
		true,
		Color(1.0, 0.6, 0.2),
		1.4,
		6.5
	)

	var directive := FixtureDirectiveScript.new(
		&"gothic_test_torch",
		0,
		FixtureAnchorScript.Type.WALL,
		Vector2i(5, 5),
		0,
		Vector3(10.0, 1.2, 10.0),
		0.0,
		1.0,
		style
	)

	var biome := BiomeProfileScript.new()
	var res = spawner.spawn_fixtures([directive], staging, biome, 2.0)

	assert(res.spawned_fixtures.size() == 1, "FAIL: Must spawn 1 fixture")
	var node: Node3D = res.spawned_fixtures[0]
	assert(node != null, "FAIL: Spawned node cannot be null")
	assert(node.has_meta("fixture_directive"), "FAIL: Metadata fixture_directive missing")
	assert(node.has_meta("room_id"), "FAIL: Metadata room_id missing")

	# Verificar componentes del fixture procedural
	var bracket = node.get_node_or_null("IronBracket")
	var flame = node.get_node_or_null("StylizedFlame")
	var light = node.get_node_or_null("TorchLight")

	assert(bracket != null and bracket is MeshInstance3D, "FAIL: IronBracket mesh missing")
	assert(flame != null and flame is MeshInstance3D, "FAIL: StylizedFlame mesh missing")
	assert(light != null and light is OmniLight3D, "FAIL: TorchLight OmniLight3D missing")

	staging.queue_free()
	print("  [OK] Procedural torch materialization, meshes and OmniLight3D verified.")
	print("[PASS] test_fixture_spawner completed successfully!")
	quit(0)
