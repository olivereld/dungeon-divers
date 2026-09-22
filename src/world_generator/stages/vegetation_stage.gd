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

	var scoped_lakes: Array = []
	var scoped_rivers: Variant = null
	if hydro != null and hydro.spatial_index != null:
		var clearance_val: float = profile.vegetation_bank_clearance if "vegetation_bank_clearance" in profile else 1.5
		var margin_val: int = clampi(int(ceil(12.0 + clearance_val)), 1, 20)
		var veg_query_bounds: Rect2i = eval_bounds.grow(margin_val)
		var raw_lakes: Array = hydro.spatial_index.query_lakes(veg_query_bounds)
		var raw_segs: Array = hydro.spatial_index.query_river_segments(veg_query_bounds)

		var eval_min_x := float(eval_bounds.position.x)
		var eval_max_x := float(eval_bounds.end.x)
		var eval_min_y := float(eval_bounds.position.y)
		var eval_max_y := float(eval_bounds.end.y)

		var filtered_lakes: Array = []
		var lake_margin: float = 0.707 + clearance_val
		for lake in raw_lakes:
			var min_pos: Vector2i = lake.get("min_pos", Vector2i.ZERO)
			var max_pos: Vector2i = lake.get("max_pos", Vector2i.ZERO)
			if float(max_pos.x + 1) + lake_margin < eval_min_x or float(min_pos.x) - lake_margin > eval_max_x or \
			   float(max_pos.y + 1) + lake_margin < eval_min_y or float(min_pos.y) - lake_margin > eval_max_y:
				continue
			filtered_lakes.append(lake)
		scoped_lakes = filtered_lakes

		var prep_rivers := PackedFloat32Array()
		for seg in raw_segs:
			var margin: float = float(seg.get("max_seg_half_w", 1.0)) + clearance_val
			var s_min_x: float = float(seg.get("min_gx", minf(seg["p0_grid"].x, seg["p1_grid"].x))) - margin
			var s_max_x: float = float(seg.get("max_gx", maxf(seg["p0_grid"].x, seg["p1_grid"].x))) + margin
			var s_min_y: float = float(seg.get("min_gy", minf(seg["p0_grid"].y, seg["p1_grid"].y))) - margin
			var s_max_y: float = float(seg.get("max_gy", maxf(seg["p0_grid"].y, seg["p1_grid"].y))) + margin
			if s_max_x < eval_min_x or s_min_x > eval_max_x or s_max_y < eval_min_y or s_min_y > eval_max_y:
				continue
			prep_rivers.append(s_min_x)
			prep_rivers.append(s_max_x)
			prep_rivers.append(s_min_y)
			prep_rivers.append(s_max_y)
			prep_rivers.append(float(seg.get("p0_gx", seg["p0_grid"].x)))
			prep_rivers.append(float(seg.get("p0_gy", seg["p0_grid"].y)))
			prep_rivers.append(float(seg.get("v_gx", seg["v_grid"].x)))
			prep_rivers.append(float(seg.get("v_gy", seg["v_grid"].y)))
			prep_rivers.append(float(seg.get("inv_l_sq_grid", 1.0 / seg["l_sq_grid"] if seg["l_sq_grid"] > 0.00001 else 0.0)))
			prep_rivers.append(float(seg.get("half_w0", seg["w0"] * 0.5)))
			prep_rivers.append(float(seg.get("half_delta_w", (seg["w1"] - seg["w0"]) * 0.5)))
		scoped_rivers = prep_rivers

	var has_nearby_water: bool = (not scoped_lakes.is_empty() or (scoped_rivers != null and not scoped_rivers.is_empty())) if (hydro != null and hydro.spatial_index != null) else true

	var is_profiling: bool = (context.telemetry != null)
	var t_start := Time.get_ticks_usec() if is_profiling else 0

	var t_cell_iter_us: int = 0
	var t_sampling_us: int = 0
	var t_exclusion_us: int = 0
	var t_excl_cell_us: int = 0
	var t_excl_geom_us: int = 0
	var t_candidate_us: int = 0
	var t_poisson_us: int = 0
	var t_placement_us: int = 0

	for y in range(eval_bounds.position.y, eval_bounds.end.y):
		for x in range(eval_bounds.position.x, eval_bounds.end.x):
			var t_c0 := Time.get_ticks_usec() if is_profiling else 0

			var cell_pos := Vector2i(x, y)
			var in_core := core_bounds.has_point(cell_pos)

			# En modo Lab (mundo cerrado), omitir el perímetro exterior
			if not is_chunk:
				if x <= 0 or x >= profile.width - 1 or y <= 0 or y >= profile.height - 1:
					if is_profiling:
						t_cell_iter_us += (Time.get_ticks_usec() - t_c0)
					continue

			# 1. Filtro rápido de autoridad hidrológica
			if hydro != null:
				var t_ex0 := Time.get_ticks_usec() if is_profiling else 0
				var excl: bool = false
				if hydro.is_vegetation_excluded(cell_pos):
					excl = true
				elif hydro.is_water(cell_pos):
					excl = true
				if is_profiling:
					var dt := Time.get_ticks_usec() - t_ex0
					t_excl_cell_us += dt
					t_exclusion_us += dt
				if excl:
					if is_profiling:
						t_cell_iter_us += (Time.get_ticks_usec() - t_c0)
					continue

			var cell := context.result.get_cell(cell_pos)
			if cell == null:
				if is_profiling:
					t_cell_iter_us += (Time.get_ticks_usec() - t_c0)
				continue

			# Hash deterministic sub-seed for cell
			var cell_hash := int(("%d:%d:%d" % [veg_seed, x, y]).hash()) & 0x7FFFFFFF
			var rng := RandomNumberGenerator.new()
			rng.seed = cell_hash

			var jitter_x := (rng.randf() - 0.5) * 0.7
			var jitter_z := (rng.randf() - 0.5) * 0.7
			var world_x := float(x) + jitter_x
			var world_z := float(y) + jitter_z

			if is_profiling:
				t_cell_iter_us += (Time.get_ticks_usec() - t_c0)

			# Sample exact triangulated surface height and slope matching TerrainMeshBuilder
			var t_s0 := Time.get_ticks_usec() if is_profiling else 0
			var surface := _sample_surface(context.result, world_x, world_z, 1.0)
			if is_profiling:
				t_sampling_us += (Time.get_ticks_usec() - t_s0)

			var world_y: float = surface["height"]
			var local_slope: float = surface["slope"]

			var pos_3d := Vector3(world_x, world_y, world_z)
			var pos_2d := Vector2(world_x, world_z)

			# Ensure spawn location has a clear radius
			if pos_2d.distance_squared_to(spawn_pos_2d) < spawn_clearance_sq:
				continue

			# 2. Filtro geométrico continuo preciso contra cuerpos de agua y orillas
			var t_ex1 := Time.get_ticks_usec() if is_profiling else 0
			var bank_clearance: float = profile.vegetation_bank_clearance if "vegetation_bank_clearance" in profile else 1.5
			var pos_excl: bool = false
			if has_nearby_water and hydro != null and hydro.is_position_excluded(pos_2d, bank_clearance, scoped_lakes, scoped_rivers):
				pos_excl = true
			if is_profiling:
				var dt1 := Time.get_ticks_usec() - t_ex1
				t_excl_geom_us += dt1
				t_exclusion_us += dt1
			if pos_excl:
				continue

			var t_cand0 := Time.get_ticks_usec() if is_profiling else 0
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

			if is_profiling:
				t_candidate_us += (Time.get_ticks_usec() - t_cand0)

	# -------------------------------------------------------------------------
	# RESOLUCIÓN POISSON DETERMINISTA (Orden-Independiente / Luby's Thinning)
	# -------------------------------------------------------------------------
	var t_p0 := Time.get_ticks_usec() if is_profiling else 0
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
	var canopy_bounds: Rect2i = core_bounds.grow(4) if is_chunk else core_bounds
	if "canopy_trees" in context.result and context.result.canopy_trees != null:
		context.result.canopy_trees.clear()

	var t_pl0 := Time.get_ticks_usec() if is_profiling else 0

	for i in range(tree_candidates.size()):
		var cand: Dictionary = tree_candidates[i]
		var p: Vector2 = cand["pos_2d"]
		var cand_cell := Vector2i(int(floor(p.x)), int(floor(p.y)))

		# Evaluar árboles que caen dentro del área de influencia de copa sobre este chunk
		var in_canopy: bool = canopy_bounds.has_point(cand_cell)
		if not in_canopy:
			continue

		var in_core: bool = core_bounds.has_point(cand_cell)
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
			var item := WorldVegetationItem.new(WorldVegetationItem.Type.CONIFER, cand["pos_3d"], cand["rot_y"], cand["scale"])
			if "canopy_trees" in context.result and context.result.canopy_trees != null:
				context.result.canopy_trees.append(item)
			if in_core:
				context.result.vegetation.append(item)

	if is_profiling:
		t_poisson_us += (Time.get_ticks_usec() - t_p0)
		t_placement_us += (Time.get_ticks_usec() - t_pl0)

	if is_profiling:
		var t_end := Time.get_ticks_usec()
		var total_ms := float(t_end - t_start) / 1000.0
		context.telemetry["veg_cell_iteration_ms"] = float(t_cell_iter_us) / 1000.0
		context.telemetry["veg_surface_sampling_ms"] = float(t_sampling_us) / 1000.0
		context.telemetry["veg_exclusion_queries_ms"] = float(t_exclusion_us) / 1000.0
		context.telemetry["vegetation_exclusion_ms"] = float(t_exclusion_us) / 1000.0
		context.telemetry["veg_cell_exclusion_ms"] = float(t_excl_cell_us) / 1000.0
		context.telemetry["veg_geom_exclusion_ms"] = float(t_excl_geom_us) / 1000.0
		context.telemetry["veg_candidate_collection_ms"] = float(t_candidate_us) / 1000.0
		context.telemetry["veg_poisson_thinning_ms"] = float(t_poisson_us) / 1000.0
		context.telemetry["veg_final_placement_ms"] = float(t_placement_us) / 1000.0
		context.telemetry["veg_total_ms"] = total_ms

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
