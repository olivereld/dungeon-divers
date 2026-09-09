class_name VegetationStage
extends WorldStage

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var veg_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_VEGETATION)
	context.result.vegetation.clear()

	# Spatial Hash Grid for O(N) tree spacing checks
	var bucket_size := maxf(profile.min_tree_spacing, 0.5)
	var min_spacing_sq := profile.min_tree_spacing * profile.min_tree_spacing
	var tree_spatial_grid: Dictionary = {}  # Vector2i -> Array[Vector2]

	# Spawn clearance to prevent vegetation on the player spawn point
	var spawn_pos_2d := Vector2(context.result.spawn_position.x, context.result.spawn_position.z)
	var spawn_clearance_sq: float = 3.5 * 3.5

	for y in range(profile.height):
		for x in range(profile.width):
			var cell := context.result.get_cell(Vector2i(x, y))

			# Hash deterministic sub-seed for cell
			var cell_hash := int(("%d:%d:%d" % [veg_seed, x, y]).hash()) & 0x7FFFFFFF
			var rng := RandomNumberGenerator.new()
			rng.seed = cell_hash

			var jitter_x := (rng.randf() - 0.5) * 0.7 * profile.cell_size
			var jitter_z := (rng.randf() - 0.5) * 0.7 * profile.cell_size
			var world_x := float(x) * profile.cell_size + jitter_x
			var world_z := float(y) * profile.cell_size + jitter_z
			var world_y := cell.height
			var pos_3d := Vector3(world_x, world_y, world_z)
			var pos_2d := Vector2(world_x, world_z)

			# Ensure spawn location has a clear radius
			if pos_2d.distance_squared_to(spawn_pos_2d) < spawn_clearance_sq:
				continue

			# 1. Conifer Placement (Forest areas, walkable gentle/flat terrain)
			if cell.forest_density > 0.05 and cell.is_walkable and cell.slope_category <= NavigationStage.SlopeCategory.GENTLE:
				var spawn_chance := cell.forest_density * profile.tree_density
				if rng.randf() < spawn_chance:
					var bx := int(floor(pos_2d.x / bucket_size))
					var by := int(floor(pos_2d.y / bucket_size))
					var too_close := false

					for dy in range(-1, 2):
						for dx in range(-1, 2):
							var bkey := Vector2i(bx + dx, by + dy)
							if tree_spatial_grid.has(bkey):
								for prev_pos in tree_spatial_grid[bkey]:
									if pos_2d.distance_squared_to(prev_pos) < min_spacing_sq:
										too_close = true
										break
							if too_close:
								break
						if too_close:
							break

					if not too_close:
						var rot_y := rng.randf_range(0.0, TAU)
						var sc := rng.randf_range(0.8, 1.3)
						context.result.vegetation.append(
							WorldVegetationItem.new(WorldVegetationItem.Type.CONIFER, pos_3d, rot_y, sc)
						)
						var insert_key := Vector2i(bx, by)
						if not tree_spatial_grid.has(insert_key):
							tree_spatial_grid[insert_key] = []
						tree_spatial_grid[insert_key].append(pos_2d)
						continue

			# 2. Shrub Placement (Clearings, forest borders, and gentle slopes)
			if cell.slope_category <= NavigationStage.SlopeCategory.GENTLE and cell.clearing_density > 0.15:
				if rng.randf() < profile.shrub_density * cell.clearing_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.5, 0.9)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.SHRUB, pos_3d, rot_y, sc)
					)
					continue

			# 3. Rock Placement (Favored on steeper slopes or rocky patches)
			if (cell.slope_category in [NavigationStage.SlopeCategory.STEEP, NavigationStage.SlopeCategory.CLIFF] or (cell.slope_category == NavigationStage.SlopeCategory.GENTLE and cell.slope > 15.0)) and cell.slope < 50.0:
				if rng.randf() < profile.rock_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.6, 1.4)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.ROCK, pos_3d, rot_y, sc)
					)
