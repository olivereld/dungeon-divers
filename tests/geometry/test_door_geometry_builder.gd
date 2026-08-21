extends SceneTree

const DoorGeometryBuilderScript = preload("res://src/geometry_generator/geometry/door_geometry_builder.gd")
const DoorGeometryConfigScript = preload("res://src/geometry_generator/config/door_geometry_config.gd")
const ArchGeometryConfigScript = preload("res://src/geometry_generator/config/arch_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_door_geometry_builder ---")
	print("==================================================================")

	var builder = DoorGeometryBuilderScript.new()
	var door_cfg = DoorGeometryConfigScript.new()
	door_cfg.door_width = 1.06
	door_cfg.door_height = 2.49
	door_cfg.door_thickness = 0.12

	# 1. Test Door Leaf Mesh
	var g_leaf = builder.build_door_leaf_mesh(door_cfg)
	assert(g_leaf != null and g_leaf.mesh != null, "FAIL: Door leaf mesh must not be null")
	assert(g_leaf.mesh.get_surface_count() >= 2, "FAIL: Leaf must have Wood and Iron surfaces")
	assert(g_leaf.collision_shapes.size() >= 1, "FAIL: Leaf must have collision shape")

	# 2. Test Portal Assembly (Arch + Leaf Composition)
	var arch_cfg = ArchGeometryConfigScript.new()
	var portal_asset = builder.build_portal_assembly(arch_cfg, door_cfg, false, false)
	assert(portal_asset != null, "FAIL: Portal assembly must not be null")
	assert(portal_asset.has_slot(&"arch"), "FAIL: Portal must have arch slot")
	assert(portal_asset.has_slot(&"leaf"), "FAIL: Portal must have leaf slot")

	var portal_node = portal_asset.to_node3d("TestPortal")
	assert(portal_node.get_child_count() >= 2, "FAIL: Portal node must contain children")
	portal_node.free()

	print("  [OK] Door Leaf Surfaces: %d | Collision Shapes: %d" % [
		g_leaf.mesh.get_surface_count(),
		g_leaf.collision_shapes.size()
	])
	print("  [OK] Portal Assembly Slots: arch, leaf")

	print("[PASS] test_door_geometry_builder completed successfully.")
	quit(0)
