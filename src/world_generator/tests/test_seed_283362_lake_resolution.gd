extends SceneTree

const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Running test_seed_283362_lake_resolution ---")
	var profile = _TaigaWorldProfile.new()
	profile.width = 256
	profile.height = 256
	profile.hydrology_enabled = true

	var result = _WorldPipeline.generate(283362, profile)
	assert(result != null and result.hydrology != null)

	var hydro = result.hydrology
	print("  Seed 283362 generated %d rivers and %d lakes" % [hydro.rivers.size(), hydro.lakes.size()])

	for lk in hydro.lakes:
		print("    Lake %d: %d cells, water_h=%.2f, spillway_pos=%s" % [
			lk.id, lk.cells.size(), lk.water_height, str(lk.spillway_pos)
		])

	assert(not hydro.lakes.is_empty(), "Seed 283362 must form a lake in the central convergence basin!")

	# Verify that no river has excessive self-intersections or infinite looping
	for r in hydro.rivers:
		var visited_cells: Dictionary = {}
		var duplicates: int = 0
		for p in r.cells:
			if visited_cells.has(p):
				duplicates += 1
			visited_cells[p] = true
		assert(duplicates <= 2, "River %d has %d looping duplicate cells (must not be a spaghetti knot)" % [r.id, duplicates])

	print("test_seed_283362_lake_resolution: PASSED")
	quit(0)
