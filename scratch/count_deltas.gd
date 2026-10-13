extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	var profile = _AutumnForestWorldProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 3)
	var world_seed = 12345
	var shared_hydrology = _WorldPipelineScript.generate_regional_hydrology(world_seed, profile)

	var chunk_world = _ChunkWorldScript.new()
	chunk_world.render_distance = 3
	root.add_child(chunk_world)
	chunk_world.initialize(world_seed, profile, config, shared_hydrology, 3)
	chunk_world.load_initial_area(Vector2i.ZERO, 3)

	var nav_grid = chunk_world.navigation_grid

	print("--- CHECKING HEIGHT DIFF VS ELEVATION DIFF FOR WALKABLE NEIGHBORS ---")
	var count_diff_h_same_el := 0
	for cy in range(-16, 32):
		for cx in range(-16, 32):
			var c1 := Vector2i(cx, cy)
			if not nav_grid.has_cell(c1) or not nav_grid.is_walkable(c1):
				continue
			var h1: float = nav_grid.get_height(c1)
			var el1: int = nav_grid.get_elevation_level(c1)

			for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
				var c2: Vector2i = c1 + dir
				if not nav_grid.has_cell(c2) or not nav_grid.is_walkable(c2):
					continue
				var h2: float = nav_grid.get_height(c2)
				var el2: int = nav_grid.get_elevation_level(c2)

				if absf(h1 - h2) > 0.1 and el1 == el2:
					print("WALKABLE DIFF HEIGHT BUT SAME ELEVATION: %s (h=%.1f, el=%d) vs %s (h=%.1f, el=%d)" % [
						str(c1), h1, el1, str(c2), h2, el2
					])
					count_diff_h_same_el += 1

	print("Total pairs with diff height but same elevation: ", count_diff_h_same_el)
	quit(0)
