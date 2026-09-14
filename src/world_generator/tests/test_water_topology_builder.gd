extends SceneTree

const _WaterCellScript = preload("res://src/world_generator/presentation/water/water_cell.gd")
const _WaterRegionScript = preload("res://src/world_generator/presentation/water/water_region.gd")
const _WaterTopologyBuilderScript = preload("res://src/world_generator/presentation/water/water_topology_builder.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Running test_water_topology_builder ---")

	# 1. Test unitario de WaterCell y WaterRegion
	var cell1 = _WaterCellScript.new(Vector2i(5, 5), 10.0, 9.0, 1.0, Vector2(1.0, 0.0), _WaterCellScript.Type.RIVER)
	assert(cell1.position == Vector2i(5, 5))
	assert(cell1.is_river() == true)
	assert(cell1.is_lake() == false)

	var reg = _WaterRegionScript.new(0)
	reg.add_cell(cell1)
	assert(reg.has_cell(Vector2i(5, 5)))
	assert(reg.get_cell(Vector2i(5, 5)) == cell1)
	assert(reg.cell_count() == 1)
	assert(reg.has_rivers == true)

	# 2. Test sobre mundo generado completo
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	var result = _WorldPipelineScript.generate(12345, profile)
	assert(result != null and result.hydrology != null)

	var regions: Array = _WaterTopologyBuilderScript.build_regions(result, profile)
	print("  Extracted %d WaterRegions from world 12345" % regions.size())

	if result.hydrology.water_cells.size() > 0:
		assert(not regions.is_empty(), "Must produce at least one WaterRegion when water_cells exist")
		var total_cells_in_regions: int = 0
		for r in regions:
			assert(r.cell_count() > 0, "Region must not be empty")
			total_cells_in_regions += r.cell_count()
			for c in r.get_cells():
				assert(c.region_id == r.id, "Cell region_id must match region id")
				assert(is_finite(c.water_height), "Water height must be finite")
				assert(is_finite(c.bed_height), "Bed height must be finite")
				assert(c.depth >= 0.0, "Depth must be non-negative")

		print("  Total cells in regions: %d (Hydro water_cells: %d)" % [total_cells_in_regions, result.hydrology.water_cells.size()])

	print("test_water_topology_builder: PASSED")
	quit(0)
