extends SceneTree

const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _ArchitecturalStyleConfigResolverScript = preload("res://src/presentation/architecture/architectural_style_config_resolver.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _DungeonMeshGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_mesh_generator.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

func _init() -> void:
	print("--- Running test_catacomb_room_presentation ---")

	var resolver := _PresentationProfileResolverScript.new()
	var profile = resolver.resolve(_DungeonArchetypeScript.Type.MAUSOLEUM, _RoomPurposeScript.Type.CATACOMB)

	assert(profile != null, "Profile must not be null")
	assert(profile.floor_style == _ArchitecturalStyleScript.FloorStyle.CATACOMB_DIRT, "CATACOMB room must resolve to CATACOMB_DIRT floor style, got %d" % profile.floor_style)
	print("  [OK] CATACOMB room purpose in Mausoleum resolved to FloorStyle.CATACOMB_DIRT")

	var config_resolver := _ArchitecturalStyleConfigResolverScript.new()
	var floor_cfg = config_resolver.resolve_floor_config(profile)

	assert(floor_cfg != null, "Floor config must not be null")
	assert(floor_cfg.pattern == _FloorTileConfigScript.PatternType.CATACOMB_DIRT, "FloorTileConfig pattern must be CATACOMB_DIRT, got %d" % floor_cfg.pattern)
	print("  [OK] ArchitecturalStyleConfigResolver translated FloorStyle.CATACOMB_DIRT to PatternType.CATACOMB_DIRT")

	# Test generating 4x4 room with CATACOMB_DIRT
	var grid := _CellGridScript.new(4, 4)
	for x in range(4):
		for y in range(4):
			grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.FLOOR)

	var facade := _DungeonMeshGeneratorScript.new()
	var res = facade.generate_floors(grid, floor_cfg, 1337)

	assert(res != null and res.clusters.size() > 0, "Floor generation must produce clusters")
	var cluster = res.clusters[0]
	assert(cluster.mesh != null, "Cluster mesh must not be null")

	var surface_names: Array[String] = []
	for s in range(cluster.mesh.get_surface_count()):
		surface_names.append(cluster.mesh.surface_get_name(s))

	print("  [OK] Catacomb room generated surfaces: %s" % str(surface_names))
	assert(surface_names.has("FloorDirt"), "Catacomb room floor must have FloorDirt 3D relief mesh")

	print("[PASS] test_catacomb_room_presentation completed successfully!")
	quit(0)
