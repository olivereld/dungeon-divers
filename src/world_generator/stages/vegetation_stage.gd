class_name VegetationStage
extends WorldStage

const _RockConfigScript = preload("res://src/rock_generation/config/rock_config.gd")
const _RockSizeConfigScript = preload("res://src/rock_generation/config/rock_size_config.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var veg_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_VEGETATION)
	context.result.vegetation.clear()

	var biome_reg: RefCounted = _BiomeRegistryScript.get_default()

	# Configuración de rocas desde el contrato RockConfig
	var rock_config = profile.get("rock_config") if profile != null and profile.get("rock_config") != null else _RockConfigScript.create_default_taiga()
	var rock_dist: Dictionary = rock_config.distribution
	var rock_density: float = float(rock_dist.get("density", profile.rock_density if profile != null else 0.15))
	var rock_min_slope: float = float(rock_dist.get("min_slope_degrees", 15.0))
	var rock_max_slope: float = float(rock_dist.get("max_slope_degrees", 55.0))
	var cat_weights: Dictionary = rock_dist.get("category_weights", {"large": 0.20, "medium": 0.45, "small": 0.35})
	var w_large: float = float(cat_weights.get("large", 0.20))
	var w_med: float = float(cat_weights.get("medium", 0.45))
	var w_small: float = float(cat_weights.get("small", 0.35))
	var total_w: float = maxf(0.001, w_large + w_med + w_small)

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

			# Resolver perfiles del bioma de la celda
			var biome_def = biome_reg.get_definition(cell.biome_id) if cell.biome_id != StringName() else null
			var veg_prof = biome_def.vegetation_profile if biome_def != null else null
			var rock_prof = biome_def.rock_profile if biome_def != null else null

			# 1. Conifer Candidates (recolectados en eval_bounds para thinning determinista)
			var cell_tree_density: float = veg_prof.tree_density if veg_prof != null else profile.tree_density
			var cell_max_tree_slope: float = veg_prof.max_tree_slope if veg_prof != null else 22.0
			var cell_tree_sc_min: float = veg_prof.tree_scale_min if veg_prof != null else 0.8
			var cell_tree_sc_max: float = veg_prof.tree_scale_max if veg_prof != null else 1.3

			if cell.forest_density > 0.05 and cell.is_walkable and cell.slope_category <= NavigationStage.SlopeCategory.GENTLE and local_slope <= cell_max_tree_slope:
				var spawn_chance := cell.forest_density * cell_tree_density
				if rng.randf() < spawn_chance:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(cell_tree_sc_min, cell_tree_sc_max)
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
			var cell_shrub_density: float = veg_prof.shrub_density if veg_prof != null else profile.shrub_density
			var cell_max_shrub_slope: float = veg_prof.max_shrub_slope if veg_prof != null else 25.0
			var cell_shrub_sc_min: float = veg_prof.shrub_scale_min if veg_prof != null else 0.5
			var cell_shrub_sc_max: float = veg_prof.shrub_scale_max if veg_prof != null else 0.9

			if pos_in_core and cell.slope_category <= NavigationStage.SlopeCategory.GENTLE and cell.clearing_density > 0.15 and local_slope <= cell_max_shrub_slope:
				if rng.randf() < cell_shrub_density * cell.clearing_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(cell_shrub_sc_min, cell_shrub_sc_max)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.SHRUB, pos_3d, rot_y, sc)
					)

			# 3. Rock Placement (solo dentro del core del chunk o mundo)
			var cell_rock_density: float = rock_prof.rock_density if rock_prof != null else rock_density
			var cell_rock_min_slope: float = rock_prof.min_slope_degrees if rock_prof != null else rock_min_slope
			var cell_rock_max_slope: float = rock_prof.max_slope_degrees if rock_prof != null else rock_max_slope
			var cell_cat_weights: Dictionary = rock_prof.category_weights if rock_prof != null else cat_weights

			var c_w_large: float = float(cell_cat_weights.get("large", w_large))
			var c_w_med: float = float(cell_cat_weights.get("medium", w_med))
			var c_w_small: float = float(cell_cat_weights.get("small", w_small))
			var c_total_w: float = maxf(0.001, c_w_large + c_w_med + c_w_small)

			if pos_in_core and ((cell.slope_category in [NavigationStage.SlopeCategory.STEEP, NavigationStage.SlopeCategory.CLIFF] or (cell.slope_category == NavigationStage.SlopeCategory.GENTLE and cell.slope > cell_rock_min_slope) or local_slope > 20.0) and local_slope < cell_rock_max_slope):
				if rng.randf() < cell_rock_density:
					var size_roll: float = rng.randf() * c_total_w
					var rot_y := rng.randf_range(0.0, TAU)
					var cat_id: int
					var cat_key: String

					if size_roll < c_w_large:
						cat_id = _RockSizeConfigScript.Category.LARGE
						cat_key = "large"
					elif size_roll < c_w_large + c_w_med:
						cat_id = _RockSizeConfigScript.Category.MEDIUM
						cat_key = "medium"
					else:
						cat_id = _RockSizeConfigScript.Category.SMALL
						cat_key = "small"

					var prof = rock_config.get_profile(cat_id)
					var main_scale: float = rng.randf_range(prof.min_scale, prof.max_scale)

					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.ROCK, pos_3d, rot_y, main_scale)
					)

					# Generación de Cluster / Satélites alrededor de rocas maestras según RockConfig
					var stage_cell_size: float = profile.cell_size if profile != null else 1.0
					var cl_info: Dictionary = rock_config.clustering.get(cat_key, {})
					if cl_info.get("enabled", false) and rng.randf() < float(cl_info.get("probability", 0.0)):
						var min_sats: int = int(cl_info.get("min_satellites", 1))
						var max_sats: int = int(cl_info.get("max_satellites", 2))
						var sat_count: int = rng.randi_range(min_sats, max_sats)
						var dist_min_mult: float = float(cl_info.get("min_distance_mult", 0.8))
						var dist_max_mult: float = float(cl_info.get("max_distance_mult", 1.6))
						var sat_profiles: Array = cl_info.get("satellite_profiles", [])

						for s_idx in range(sat_count):
							var sat_angle: float = rng.randf_range(0.0, TAU)
							var sat_dist: float = rng.randf_range(dist_min_mult, dist_max_mult) * main_scale
							var sat_x: float = pos_3d.x + cos(sat_angle) * sat_dist
							var sat_z: float = pos_3d.z + sin(sat_angle) * sat_dist
							var sat_cell := Vector2i(floori(sat_x / stage_cell_size), floori(sat_z / stage_cell_size))
							if core_bounds.has_point(sat_cell):
								var s_surf = _sample_surface(context.result, sat_x, sat_z, stage_cell_size)
								if s_surf.get("slope", 0.0) < cell_rock_max_slope:
									var s_sc: float
									if not sat_profiles.is_empty():
										var sat_p: Dictionary = sat_profiles[s_idx % sat_profiles.size()]
										var sc_min: float = float(sat_p.get("scale_min", 0.20))
										var sc_max: float = float(sat_p.get("scale_max", 0.40))
										s_sc = rng.randf_range(sc_min, sc_max)
									else:
										s_sc = rng.randf_range(0.20, 0.40)
									var s_pos := Vector3(sat_x, s_surf["height"], sat_z)
									context.result.vegetation.append(
										WorldVegetationItem.new(WorldVegetationItem.Type.ROCK, s_pos, rng.randf_range(0.0, TAU), s_sc)
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

## Samples exact elevation and slope on the stepped terrain mesh matching TerrainMeshBuilder.
func _sample_surface(result: WorldResult, world_x: float, world_z: float, cell_size: float) -> Dictionary:
	var gx: int = int(floor(world_x / cell_size))
	var gz: int = int(floor(world_z / cell_size))
	var cell := result.get_cell(Vector2i(gx, gz))
	if cell != null:
		return {"height": cell.height, "slope": cell.slope}
	return {"height": 0.0, "slope": 0.0}
