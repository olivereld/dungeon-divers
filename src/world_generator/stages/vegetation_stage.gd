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
			# Skip outer boundary to prevent entities from sitting right on the mesh perimeter
			if x <= 0 or x >= profile.width - 1 or y <= 0 or y >= profile.height - 1:
				continue

			# 1. Filtro rápido de autoridad hidrológica: descartar celdas en agua y en orillas/talud
			var hydro = context.result.hydrology
			if hydro != null:
				if hydro.has_method("is_vegetation_excluded") and hydro.is_vegetation_excluded(Vector2i(x, y)):
					continue
				elif hydro.has_method("is_water") and hydro.is_water(Vector2i(x, y)):
					continue

			var cell := context.result.get_cell(Vector2i(x, y))

			# Hash deterministic sub-seed for cell
			var cell_hash := int(("%d:%d:%d" % [veg_seed, x, y]).hash()) & 0x7FFFFFFF
			var rng := RandomNumberGenerator.new()
			rng.seed = cell_hash

			var jitter_x := (rng.randf() - 0.5) * 0.7
			var jitter_z := (rng.randf() - 0.5) * 0.7
			var world_x := float(x) + jitter_x
			var world_z := float(y) + jitter_z

			# Sample exact triangulated surface height and slope matching TerrainMeshBuilder (fixed 1.0 spacing)
			var surface := _sample_surface(context.result, world_x, world_z, 1.0)
			var world_y: float = surface["height"]
			var local_slope: float = surface["slope"]

			var pos_3d := Vector3(world_x, world_y, world_z)
			var pos_2d := Vector2(world_x, world_z)

			# Ensure spawn location has a clear radius
			if pos_2d.distance_squared_to(spawn_pos_2d) < spawn_clearance_sq:
				continue

			# 2. Filtro geométrico continuo preciso contra cuerpos de agua y orillas
			var bank_clearance: float = profile.vegetation_bank_clearance if "vegetation_bank_clearance" in profile else 1.5
			if hydro != null and hydro.has_method("is_position_excluded") and hydro.is_position_excluded(pos_2d, bank_clearance):
				continue

			# 1. Conifer Placement (Forest areas, walkable gentle/flat terrain, avoid steep local faces)
			if cell.forest_density > 0.05 and cell.is_walkable and cell.slope_category <= NavigationStage.SlopeCategory.GENTLE and local_slope <= 22.0:
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
			if cell.slope_category <= NavigationStage.SlopeCategory.GENTLE and cell.clearing_density > 0.15 and local_slope <= 25.0:
				if rng.randf() < profile.shrub_density * cell.clearing_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.5, 0.9)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.SHRUB, pos_3d, rot_y, sc)
					)
					continue

			# 3. Rock Placement (Favored on steeper slopes or rocky patches)
			if (cell.slope_category in [NavigationStage.SlopeCategory.STEEP, NavigationStage.SlopeCategory.CLIFF] or (cell.slope_category == NavigationStage.SlopeCategory.GENTLE and cell.slope > 15.0) or local_slope > 20.0) and local_slope < 55.0:
				if rng.randf() < profile.rock_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.6, 1.4)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.ROCK, pos_3d, rot_y, sc)
					)

	# End of execute

## Samples exact elevation and slope on the stepped terrain mesh matching TerrainMeshBuilder.
func _sample_surface(result: WorldResult, world_x: float, world_z: float, cell_size: float) -> Dictionary:
	var gx: int = int(floor(world_x / cell_size))
	var gz: int = int(floor(world_z / cell_size))
	var cell := result.get_cell(Vector2i(gx, gz))
	if cell != null:
		return {"height": cell.height, "slope": cell.slope}
	return {"height": 0.0, "slope": 0.0}
