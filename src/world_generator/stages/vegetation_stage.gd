class_name VegetationStage
extends WorldStage

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var veg_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_VEGETATION)
	context.result.vegetation.clear()

	var placed_tree_positions: Array[Vector2] = []

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

			# 1. Conifer Placement (Forest areas, low/moderate slopes)
			if cell.forest_density > 0.1 and cell.slope < 30.0:
				var spawn_chance := cell.forest_density * profile.tree_density
				if rng.randf() < spawn_chance:
					# Spacing check
					var too_close := false
					for prev_pos in placed_tree_positions:
						if pos_2d.distance_to(prev_pos) < profile.min_tree_spacing:
							too_close = true
							break
					if not too_close:
						var rot_y := rng.randf_range(0.0, TAU)
						var sc := rng.randf_range(0.8, 1.3)
						context.result.vegetation.append(
							WorldVegetationItem.new(WorldVegetationItem.Type.CONIFER, pos_3d, rot_y, sc)
						)
						placed_tree_positions.append(pos_2d)
						continue

			# 2. Shrub Placement (Clearings and forest borders)
			if cell.slope < 25.0 and cell.clearing_density > 0.2:
				if rng.randf() < profile.shrub_density * cell.clearing_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.5, 0.9)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.SHRUB, pos_3d, rot_y, sc)
					)
					continue

			# 3. Rock Placement (Favored on steeper slopes or rocky patches)
			if cell.slope > 15.0 and cell.slope < 45.0:
				if rng.randf() < profile.rock_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.6, 1.4)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.ROCK, pos_3d, rot_y, sc)
					)
