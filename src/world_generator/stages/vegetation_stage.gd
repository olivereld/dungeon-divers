class_name VegetationStage
extends WorldStage

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var veg_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_VEGETATION)
	context.result.vegetation.clear()

	# Spatial Hash Grid for O(N) tree spacing checks
	var core_bounds: Rect2i = context.get_core_bounds() if context.has_method("get_core_bounds") else Rect2i(0, 0, profile.width, profile.height)
	var is_chunk: bool = context.has_method("is_chunk_context") and context.is_chunk_context()

	var bucket_size := maxf(profile.min_tree_spacing, 0.5)
	var min_spacing_sq := profile.min_tree_spacing * profile.min_tree_spacing

	# Halo de evaluación para que los árboles en las costuras compitan deterministamente
	var halo: int = int(ceil(profile.min_tree_spacing)) + 1
	var eval_bounds: Rect2i = core_bounds.grow(halo) if is_chunk else core_bounds

	# Spawn clearance to prevent vegetation on the player spawn point
	var spawn_pos_2d := Vector2(context.result.spawn_position.x, context.result.spawn_position.z)
	var spawn_clearance_sq: float = 3.5 * 3.5

	var tree_candidates: Array[Dictionary] = []
	var hydro = context.result.hydrology

	for y in range(eval_bounds.position.y, eval_bounds.end.y):
		for x in range(eval_bounds.position.x, eval_bounds.end.x):
			var cell_pos := Vector2i(x, y)
			var in_core := core_bounds.has_point(cell_pos)

			# En modo Lab (mundo cerrado), omitir el perímetro exterior
			if not is_chunk:
				if x <= 0 or x >= profile.width - 1 or y <= 0 or y >= profile.height - 1:
					continue

			# 1. Filtro rápido de autoridad hidrológica
			if hydro != null:
				if hydro.has_method("is_vegetation_excluded") and hydro.is_vegetation_excluded(cell_pos):
					continue
				elif hydro.has_method("is_water") and hydro.is_water(cell_pos):
					continue

			var cell := context.result.get_cell(cell_pos)
			if cell == null:
				continue

			# Hash deterministic sub-seed for cell
			var cell_hash := int(("%d:%d:%d" % [veg_seed, x, y]).hash()) & 0x7FFFFFFF
			var rng := RandomNumberGenerator.new()
			rng.seed = cell_hash

			var jitter_x := (rng.randf() - 0.5) * 0.7
			var jitter_z := (rng.randf() - 0.5) * 0.7
			var world_x := float(x) + jitter_x
			var world_z := float(y) + jitter_z

			# Sample exact triangulated surface height and slope matching TerrainMeshBuilder
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

			# 1. Conifer Candidates (recolectados en eval_bounds para thinning determinista)
			if cell.forest_density > 0.05 and cell.is_walkable and cell.slope_category <= NavigationStage.SlopeCategory.GENTLE and local_slope <= 22.0:
				var spawn_chance := cell.forest_density * profile.tree_density
				if rng.randf() < spawn_chance:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.8, 1.3)
					var priority := rng.randf()
					tree_candidates.append({
						"pos_2d": pos_2d,
						"pos_3d": pos_3d,
						"rot_y": rot_y,
						"scale": sc,
						"priority": priority,
						"cell_pos": cell_pos
					})

			var pos_in_core := core_bounds.has_point(Vector2i(floori(pos_2d.x), floori(pos_2d.y)))

			# 2. Shrub Placement (solo dentro del core del chunk o mundo)
			if pos_in_core and cell.slope_category <= NavigationStage.SlopeCategory.GENTLE and cell.clearing_density > 0.15 and local_slope <= 25.0:
				if rng.randf() < profile.shrub_density * cell.clearing_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.5, 0.9)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.SHRUB, pos_3d, rot_y, sc)
					)

			# 3. Rock Placement (solo dentro del core del chunk o mundo)
			if pos_in_core and ((cell.slope_category in [NavigationStage.SlopeCategory.STEEP, NavigationStage.SlopeCategory.CLIFF] or (cell.slope_category == NavigationStage.SlopeCategory.GENTLE and cell.slope > 15.0) or local_slope > 20.0) and local_slope < 55.0):
				if rng.randf() < profile.rock_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.6, 1.4)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.ROCK, pos_3d, rot_y, sc)
					)

	# -------------------------------------------------------------------------
	# RESOLUCIÓN POISSON DETERMINISTA (Orden-Independiente / Luby's Thinning)
	# -------------------------------------------------------------------------
	# Indexar candidatos en spatial grid para búsqueda espacial rápida O(N)
	var spatial_grid: Dictionary = {}
	for i in range(tree_candidates.size()):
		var c: Dictionary = tree_candidates[i]
		var p: Vector2 = c["pos_2d"]
		var bk := Vector2i(int(floor(p.x / bucket_size)), int(floor(p.y / bucket_size)))
		if not spatial_grid.has(bk):
			spatial_grid[bk] = []
		spatial_grid[bk].append(i)

	# Poda determinista por prioridad intrínseca
	for i in range(tree_candidates.size()):
		var cand: Dictionary = tree_candidates[i]
		var p: Vector2 = cand["pos_2d"]

		# Solo nos interesa añadir los árboles cuyo centro caiga estrictamente dentro de core_bounds
		var in_core: bool = core_bounds.has_point(Vector2i(int(floor(p.x)), int(floor(p.y))))
		if not in_core:
			continue

		var my_prio: float = cand["priority"]
		var suppressed := false

		var bk_x := int(floor(p.x / bucket_size))
		var bk_y := int(floor(p.y / bucket_size))

		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nbk := Vector2i(bk_x + dx, bk_y + dy)
				if not spatial_grid.has(nbk):
					continue
				for other_idx in spatial_grid[nbk]:
					if other_idx == i:
						continue
					var other: Dictionary = tree_candidates[other_idx]
					var other_pos: Vector2 = other["pos_2d"]
					if p.distance_squared_to(other_pos) < min_spacing_sq:
						# En caso de conflicto de proximidad, gana el candidato de mayor prioridad determinista
						var other_prio: float = other["priority"]
						if other_prio > my_prio or (is_equal_approx(other_prio, my_prio) and other_idx < i):
							suppressed = true
							break
				if suppressed:
					break
			if suppressed:
				break

		if not suppressed:
			context.result.vegetation.append(
				WorldVegetationItem.new(WorldVegetationItem.Type.CONIFER, cand["pos_3d"], cand["rot_y"], cand["scale"])
			)

## Samples exact elevation and slope angle on the triangulated mesh quad matching TerrainMeshBuilder.
func _sample_surface(result: WorldResult, world_x: float, world_z: float, cell_size: float) -> Dictionary:
	var grid_x: float = world_x / cell_size
	var grid_z: float = world_z / cell_size

	var x0: int = int(floor(grid_x))
	var z0: int = int(floor(grid_z))
	var x1: int = x0 + 1
	var z1: int = z0 + 1

	var u: float = clampf(grid_x - float(x0), 0.0, 1.0)
	var v: float = clampf(grid_z - float(z0), 0.0, 1.0)

	var c00 := result.get_cell(Vector2i(x0, z0))
	var c10 := result.get_cell(Vector2i(x1, z0))
	var c01 := result.get_cell(Vector2i(x0, z1))
	var c11 := result.get_cell(Vector2i(x1, z1))

	var h00: float = c00.height if c00 != null else 0.0
	var h10: float = c10.height if c10 != null else h00
	var h01: float = c01.height if c01 != null else h00
	var h11: float = c11.height if c11 != null else (h10 if h10 != 0.0 else h00)

	var height: float = 0.0
	var slope_deg: float = 0.0

	# Triangle plane interpolation matching TerrainMeshBuilder indices:
	# Quad triangles:
	# T1: (x0, z0) -> (x1, z0) -> (x0, z1) when u + v <= 1.0
	# T2: (x1, z0) -> (x1, z1) -> (x0, z1) when u + v > 1.0
	if u + v <= 1.0:
		height = h00 + u * (h10 - h00) + v * (h01 - h00)
		var dh_dx: float = (h10 - h00) / cell_size
		var dh_dz: float = (h01 - h00) / cell_size
		slope_deg = rad_to_deg(atan(sqrt(dh_dx * dh_dx + dh_dz * dh_dz)))
	else:
		height = h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)
		var dh_dx: float = (h11 - h01) / cell_size
		var dh_dz: float = (h11 - h10) / cell_size
		slope_deg = rad_to_deg(atan(sqrt(dh_dx * dh_dx + dh_dz * dh_dz)))

	return {"height": height, "slope": slope_deg}
