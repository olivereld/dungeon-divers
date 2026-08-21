extends SceneTree

const GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_geometry_contracts ---")
	print("==================================================================")

	var asset = GeneratedAssetScript.new()
	asset.asset_id = &"door_portal_test"

	var g_arch = GeneratedMeshScript.new()
	g_arch.component_id = 1
	g_arch.bounds = AABB(Vector3(-1.0, 0.0, -0.2), Vector3(2.0, 4.0, 0.4))
	asset.add_mesh(&"arch", g_arch)

	var g_leaf = GeneratedMeshScript.new()
	g_leaf.component_id = 2
	g_leaf.bounds = AABB(Vector3(-0.5, 0.0, -0.06), Vector3(1.0, 2.5, 0.12))
	asset.add_mesh(&"leaf", g_leaf)

	assert(asset.has_slot(&"arch"), "FAIL: Asset must have arch slot")
	assert(asset.has_slot(&"leaf"), "FAIL: Asset must have leaf slot")
	assert(asset.get_mesh(&"arch") == g_arch, "FAIL: Arch slot mismatch")
	assert(asset.bounds.size.x >= 2.0, "FAIL: Combined bounds must encompass arch")

	var node = asset.to_node3d()
	assert(node != null, "FAIL: Asset must instantiate to Node3D")
	node.free()

	print("[PASS] test_geometry_contracts completed successfully.")
	quit(0)
