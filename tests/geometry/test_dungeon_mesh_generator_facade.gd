extends SceneTree

const DungeonMeshGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_mesh_generator.gd")
const CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_mesh_generator_facade ---")
	print("==================================================================")

	var facade = DungeonMeshGeneratorScript.new()
	var grid = CellGridScript.new(3, 3, CellGridScript.CellType.FLOOR)
	for x in range(3):
		grid.set_cell(Vector2i(x, 0), CellGridScript.CellType.WALL)

	# 1. Walls
	var walls_res = facade.generate_walls(grid)
	assert(walls_res != null and not walls_res.generated_meshes.is_empty(), "FAIL: Walls generation")

	# 2. Floors
	var floor_res = facade.generate_floors(grid)
	assert(floor_res != null and not floor_res.clusters.is_empty(), "FAIL: Floor generation")

	# 3. Arch
	var arch_gm = facade.generate_arch()
	assert(arch_gm != null and arch_gm.mesh != null, "FAIL: Arch generation")

	# 4. Door Leaf
	var leaf_gm = facade.generate_door_leaf()
	assert(leaf_gm != null and leaf_gm.mesh != null, "FAIL: Door leaf generation")

	# 5. Door Portal Assembly
	var portal_asset = facade.generate_door_portal(null, null, false, false)
	assert(portal_asset != null and portal_asset.has_slot(&"arch") and portal_asset.has_slot(&"leaf"), "FAIL: Portal assembly")

	# 6. Stairs
	var stairs_gm = facade.generate_stairs()
	assert(stairs_gm != null and stairs_gm.mesh != null, "FAIL: Stairs generation")

	# 7. Torch Fixture
	var torch_asset = facade.generate_torch_fixture()
	assert(torch_asset != null and torch_asset.has_slot(&"bracket") and torch_asset.has_slot(&"flame"), "FAIL: Torch fixture generation")

	print("  [OK] Facade successfully orchestrated: Walls, Floors, Arch, DoorLeaf, PortalAssembly, Stairs, TorchFixture")
	print("[PASS] test_dungeon_mesh_generator_facade completed successfully.")
	quit(0)
