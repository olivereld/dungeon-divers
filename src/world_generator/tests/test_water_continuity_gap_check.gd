extends SceneTree

const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")

const _WaterTopologyBuilder = preload("res://src/world_generator/presentation/water/water_topology_builder.gd")

func _init() -> void:
	print("--- Running test_water_continuity_gap_check ---")
	var profile = _TaigaWorldProfile.new()
	profile.width = 128
	profile.height = 128
	profile.hydrology_enabled = true

	for s in [12345, 283362, 777, 999]:
		var result = _WorldPipeline.generate(s, profile)
		var hydro = result.hydrology
		print("Seed %d: %d rivers, %d lakes" % [s, hydro.rivers.size(), hydro.lakes.size()])
		for r in hydro.rivers:
			var end_p: Vector2i = r.cells[-1]
			print("  River %d: %d cells, end=%s, down_r=%d, dest_type=%d, is_outflow=%s" % [
				r.id, r.cells.size(), str(end_p), r.downstream_river, r.destination_type, r.is_outflow
			])
			# If river is terminated (not at map edge), verify there are no other water bodies within distance <= 1.5
			var is_edge: bool = (end_p.x <= 1 or end_p.x >= profile.width - 2 or end_p.y <= 1 or end_p.y >= profile.height - 2)
			if r.downstream_river == -1 and not is_edge and r.destination_type != 3:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var p := end_p + Vector2i(dx, dy)
						if hydro.is_lake(p):
							assert(false, "River %d terminated at %s adjacent to lake at %s!" % [r.id, str(end_p), str(p)])
						elif hydro.is_river(p):
							var other_id = hydro.water_cells[p].get("river_index", -1)
							if other_id != r.id and other_id != -1:
								assert(false, "River %d terminated at %s adjacent to river %d at %s!" % [r.id, str(end_p), other_id, str(p)])

		# Validate WaterRegions continuity
		var regions = _WaterTopologyBuilder.build_regions(result, profile)
		print("  -> Built %d unified WaterRegions" % [regions.size()])
		assert(regions.size() > 0, "Must extract at least one valid water region")

	print("ALL WATER CONTINUITY GAP CHECKS PASSED!")
	quit(0)
