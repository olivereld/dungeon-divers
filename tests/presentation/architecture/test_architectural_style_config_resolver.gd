extends SceneTree

const ArchitecturalStyleConfigResolverScript = preload("res://src/presentation/architecture/architectural_style_config_resolver.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_architectural_style_config_resolver ---")
	print("==================================================================")

	var resolver := ArchitecturalStyleConfigResolverScript.new()

	# 1. Test Floor Config Resolution
	var base_floor := FloorTileConfigScript.new()
	base_floor.pattern = FloorTileConfigScript.PatternType.STYLIZED_STONE

	var prof_maus := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
		ArchitecturalStyleScript.WallStyle.DARK_STONE
	)
	var resolved_floor_maus = resolver.resolve_floor_config(prof_maus, base_floor)
	assert(resolved_floor_maus != base_floor, "FAIL: Base floor config must be cloned, not mutated in-place")
	assert(resolved_floor_maus.pattern == FloorTileConfigScript.PatternType.RUINED_TILES, "FAIL: RUINED_STONE must map to RUINED_TILES")

	var prof_fort := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.COBBLESTONE,
		ArchitecturalStyleScript.WallStyle.FORTRESS_STONE
	)
	var resolved_floor_fort = resolver.resolve_floor_config(prof_fort, base_floor)
	assert(resolved_floor_fort.pattern == FloorTileConfigScript.PatternType.COBBLESTONE, "FAIL: COBBLESTONE must map to COBBLESTONE")

	var prof_temple := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.TEMPLE_TILES,
		ArchitecturalStyleScript.WallStyle.TEMPLE_STONE
	)
	var resolved_floor_temple = resolver.resolve_floor_config(prof_temple, base_floor)
	assert(resolved_floor_temple.pattern == FloorTileConfigScript.PatternType.SMOOTH_SLABS, "FAIL: TEMPLE_TILES must map to SMOOTH_SLABS")

	# 2. Test Wall Decoration Config Resolution
	var base_dec := DecorationConfigScript.new()
	var resolved_dec_fort = resolver.resolve_wall_decoration_config(prof_fort, base_dec)
	assert(resolved_dec_fort.style == DecorationConfigScript.DecorationStyle.FULL_MASONRY)
	assert(resolved_dec_fort.brick_density >= 0.70)

	var resolved_dec_maus = resolver.resolve_wall_decoration_config(prof_maus, base_dec)
	assert(resolved_dec_maus.style == DecorationConfigScript.DecorationStyle.STYLIZED_CLUSTERS)
	assert(resolved_dec_maus.brick_density == 0.50)

	# 3. Test Wall Geometry Config Resolution
	var base_wall := WallGeometryConfigScript.new()
	var resolved_wall = resolver.resolve_wall_geometry_config(prof_maus, base_wall)
	assert(resolved_wall != base_wall, "FAIL: Wall config must be cloned")

	print("  [OK] FloorTileConfig resolution verified.")
	print("  [OK] DecorationConfig resolution verified.")
	print("  [OK] WallGeometryConfig resolution verified.")
	print("[PASS] test_architectural_style_config_resolver completed successfully.")
	quit(0)
