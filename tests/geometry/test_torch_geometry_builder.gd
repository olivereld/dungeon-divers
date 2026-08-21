extends SceneTree

const TorchGeometryBuilderScript = preload("res://src/geometry_generator/fixtures/torch_geometry_builder.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_torch_geometry_builder ---")
	print("==================================================================")

	var builder = TorchGeometryBuilderScript.new()
	var fixture_asset = builder.build_torch_fixture(0.42, 1.0)
	assert(fixture_asset != null, "FAIL: Fixture asset must not be null")
	assert(fixture_asset.has_slot(&"bracket"), "FAIL: Fixture must have bracket slot")
	assert(fixture_asset.has_slot(&"flame"), "FAIL: Fixture must have flame slot")

	var g_bracket = fixture_asset.get_mesh(&"bracket")
	var g_flame = fixture_asset.get_mesh(&"flame")
	assert(g_bracket != null and g_bracket.mesh != null, "FAIL: Bracket mesh must not be null")
	assert(g_flame != null and g_flame.mesh != null, "FAIL: Flame mesh must not be null")

	var fixture_node = fixture_asset.to_node3d("Torch")
	assert(fixture_node.get_child_count() == 2, "FAIL: Fixture Node3D must contain bracket and flame meshes")
	fixture_node.free()

	print("  [OK] Torch fixture slots: bracket, flame")
	print("[PASS] test_torch_geometry_builder completed successfully.")
	quit(0)
