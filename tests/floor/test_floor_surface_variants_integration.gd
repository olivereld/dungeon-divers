extends SceneTree

const _DungeonFloorGenScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const _PartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const _RoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _ArchProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _PolicyScript = preload("res://src/dungeon_generator/profiles/profile_floor_variant_policy.gd")
const _ArchStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _StyleResolverScript = preload("res://src/presentation/architecture/architectural_style_config_resolver.gd")

func _init() -> void:
	print("--- Running test_floor_surface_variants_integration ---")
	var floor_gen = _DungeonFloorGenScript.new()
	var partition = _PartitionScript.new()
	var style_resolver = _StyleResolverScript.new()

	var cells: Array[Vector2i] = []
	for x in range(10):
		for y in range(10):
			cells.append(Vector2i(x, y))

	var prof = _ArchProfileScript.new(
		_ArchStyleScript.FloorStyle.CATACOMB_DIRT,
		_ArchStyleScript.WallStyle.DARK_STONE
	)
	prof.floor_variants = _PolicyScript.new(
		true,
		&"catacomb_dirt",
		70.0,
		[
			{ "style": &"ruined_stone", "weight": 30.0 }
		]
	)

	var r_geom = _RoomGeomScript.new(1, Rect2i(0, 0, 10, 10), cells, [], [], prof)
	partition.rooms_geometry[1] = r_geom

	var res = floor_gen.generate_floor_for_partition(partition, style_resolver, null, 1337)
	assert(res != null, "Result cannot be null")
	assert(res.clusters.size() == 1, "Must generate 1 cluster")
	assert(res.clusters[0].mesh != null, "Cluster mesh must be built")
	assert(res.clusters[0].descriptors.size() > 0, "Descriptors must be generated")

	print("  [OK] Floor generation integrates cell-level surface variants into unified cluster mesh")
	print("[PASS] test_floor_surface_variants_integration passed!")
	quit(0)
