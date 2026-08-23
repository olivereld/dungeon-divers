extends SceneTree

const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _DungeonMeshGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_mesh_generator.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _MeshGalleryCatalogScript = preload("res://src/presentation/showcase/mesh_gallery_catalog.gd")
const _MeshGalleryRendererScript = preload("res://src/presentation/showcase/mesh_gallery_renderer.gd")

func _init() -> void:
	print("--- Running test_catacomb_dirt_floor ---")

	# 1. Test direct generation of Catacomb Dirt Floor
	var cfg := _FloorTileConfigScript.new()
	cfg.pattern = _FloorTileConfigScript.PatternType.CATACOMB_DIRT
	cfg.material_preset = 2 # DARK_CRYPT
	cfg.tile_size = 2.0
	cfg.seed = 42

	var grid := _CellGridScript.new(3, 3)
	for x in range(3):
		for y in range(3):
			grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.FLOOR)

	var facade := _DungeonMeshGeneratorScript.new()
	var res = facade.generate_floors(grid, cfg, 42)

	assert(res != null, "Floor result must not be null")
	assert(res.clusters.size() > 0, "Must generate at least 1 cluster")

	var cluster = res.clusters[0]
	assert(cluster.mesh != null, "Cluster mesh must be built")
	assert(cluster.mesh.get_surface_count() >= 2, "Must contain at least 2 surfaces (FloorSlabs and FloorDirt)")

	var surface_names: Array[String] = []
	for s in range(cluster.mesh.get_surface_count()):
		surface_names.append(cluster.mesh.surface_get_name(s))

	print("  [OK] Generated surfaces: %s" % str(surface_names))
	assert(surface_names.has("FloorDirt"), "Must contain FloorDirt surface with 3D terrain relief")
	assert(surface_names.has("FloorSlabs"), "Must contain FloorSlabs surface for embedded stones/pebbles")

	# 2. Test Mesh Gallery Integration
	var catalog := _MeshGalleryCatalogScript.new()
	var entry_dark = catalog.get_entry(&"floor_catacomb_dirt_dark")
	assert(entry_dark != null, "Must register floor_catacomb_dirt_dark in catalog")

	var entry_warm = catalog.get_entry(&"floor_catacomb_dirt_warm")
	assert(entry_warm != null, "Must register floor_catacomb_dirt_warm in catalog")

	var entry_single = catalog.get_entry(&"floor_catacomb_dirt_single")
	assert(entry_single != null, "Must register floor_catacomb_dirt_single in catalog")

	var renderer := _MeshGalleryRendererScript.new()
	var rendered_node = renderer.render_entry(entry_dark, 42)
	assert(rendered_node != null, "Rendered gallery node must not be null")
	assert(rendered_node.get_child_count() > 0, "Rendered gallery node must contain clusters container")
	print("  [OK] Gallery rendered node successfully with %d children" % rendered_node.get_child_count())
	rendered_node.free()

	print("[PASS] test_catacomb_dirt_floor completed successfully!")
	quit(0)
