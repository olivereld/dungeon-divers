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

	print("--- SEARCHING FOR CLIFFS WITH WATER NEARBY ---")
	# Search in range [-16, 32] x [-16, 32]
	for cy in range(-16, 32):
		for cx in range(-16, 32):
			var c := Vector2i(cx, cy)
			if not nav_grid.has_cell(c):
				continue
			var el: int = nav_grid.get_elevation_level(c)
			var h: float = nav_grid.get_height(c)
			var w: bool = nav_grid.is_walkable(c)

			# Check if there is an unwalkable (water) cell nearby AND a neighbor with different elevation
			var has_water := false
			var diff_elevation := false
			var diff_val := 0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var nc := c + Vector2i(dx, dy)
					if nav_grid.has_cell(nc):
						if not nav_grid.is_walkable(nc):
							has_water = true
						var nel: int = nav_grid.get_elevation_level(nc)
						if nel != el:
							diff_elevation = true
							diff_val = nel - el

			if w and has_water and diff_elevation:
				print("Candidate at cell (%d, %d): el=%d, h=%.1f, delta_neighbor=%d" % [cx, cy, el, h, diff_val])

	quit(0)
