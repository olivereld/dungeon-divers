extends SceneTree

func _init() -> void:
	print("--- Running test_procedural_dungeon_walls ---")
	var factory := PlaceholderFactory.new()
	var default_biome := BiomeProfile.new() # Sin escenas empaquetadas -> modo 100% procedural

	var lib: MeshLibrary = factory.create_placeholder_library(default_biome, 2.0)
	assert(lib != null, "MeshLibrary must be created")

	var wall_mesh: Mesh = lib.get_item_mesh(default_biome.wall_index)
	var corner_mesh: Mesh = lib.get_item_mesh(default_biome.wall_corner_index)
	var corner_small_mesh: Mesh = lib.get_item_mesh(default_biome.wall_corner_small_index)

	assert(wall_mesh != null, "Wall procedural mesh must exist in MeshLibrary")
	assert(corner_mesh != null, "WallCorner procedural mesh must exist in MeshLibrary")
	assert(corner_small_mesh != null, "WallCornerSmall procedural mesh must exist in MeshLibrary")

	print("  [OK] Procedural Wall Mesh Surfaces: %d (AABB: %s)" % [wall_mesh.get_surface_count(), str(wall_mesh.get_aabb())])
	print("  [OK] Procedural Corner Mesh Surfaces: %d (AABB: %s)" % [corner_mesh.get_surface_count(), str(corner_mesh.get_aabb())])

	assert(wall_mesh.get_surface_count() == 3, "Wall mesh should contain Trims, WallPanel, and Bricks surfaces")
	assert(corner_mesh.get_surface_count() == 3, "Corner mesh should contain Trims, WallPanel, and Bricks surfaces")

	# Verificar que los materiales PBR están asignados a las superficies
	for s in range(3):
		var mat_wall: Material = wall_mesh.surface_get_material(s)
		var mat_corner: Material = corner_mesh.surface_get_material(s)
		assert(mat_wall != null, "Wall surface %d must have material assigned" % s)
		assert(mat_corner != null, "Corner surface %d must have material assigned" % s)

	print("  [OK] Materials properly attached to all procedural surfaces.")
	print("\n>>> PROCEDURAL DUNGEON WALLS INTEGRATION TEST PASSED! <<<\n")
	quit(0)
