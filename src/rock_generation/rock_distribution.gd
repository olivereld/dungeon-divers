class_name RockDistribution
extends RefCounted

const RockSizeProfile = preload("res://src/rock_generation/rock_size_profile.gd")
const RockInstance = preload("res://src/rock_generation/rock_instance.gd")

## Gestor de distribución espacial determinista y agrupación por clusters para rocas.
## Desacoplado de cualquier módulo exterior mediante Callables de consulta.

## Genera todas las instancias de roca para un área determinada de forma determinista
static func generate_area_rocks(
	bounds: Rect2,
	world_seed: int,
	profiles: Dictionary,
	terrain_query_fn: Callable = Callable()
) -> Array[RockInstance]:
	var instances: Array[RockInstance] = []

	var large_profile: RockSizeProfile = profiles.get(RockSizeProfile.Category.LARGE, RockSizeProfile.create_large())
	var medium_profile: RockSizeProfile = profiles.get(RockSizeProfile.Category.MEDIUM, RockSizeProfile.create_medium())
	var small_profile: RockSizeProfile = profiles.get(RockSizeProfile.Category.SMALL, RockSizeProfile.create_small())

	# Células de cuadrícula para distribución determinista espacial
	# 1. Grandes: células de 16x16 metros
	var large_cell_size: float = 16.0
	var large_rock_centers: Array[Dictionary] = [] # [{pos: Vector3, seed: int}]

	var min_gx_l: int = int(floor(bounds.position.x / large_cell_size))
	var max_gx_l: int = int(ceil(bounds.end.x / large_cell_size))
	var min_gz_l: int = int(floor(bounds.position.y / large_cell_size))
	var max_gz_l: int = int(ceil(bounds.end.y / large_cell_size))

	for gx in range(min_gx_l, max_gx_l):
		for gz in range(min_gz_l, max_gz_l):
			var cell_seed: int = _hash_coords(world_seed, gx, gz, RockSizeProfile.Category.LARGE)
			var spawn_roll: float = _hash_float(cell_seed, 1)

			# Densidad de grandes
			if spawn_roll < large_profile.density:
				var offset_x: float = _hash_float(cell_seed, 2) * large_cell_size
				var offset_z: float = _hash_float(cell_seed, 3) * large_cell_size
				var wx: float = float(gx) * large_cell_size + offset_x
				var wz: float = float(gz) * large_cell_size + offset_z

				if bounds.has_point(Vector2(wx, wz)):
					var sample: Dictionary = _query_terrain(terrain_query_fn, wx, wz, large_profile.max_slope_degrees)
					if sample.valid:
						var inst: RockInstance = RockInstance.create(
							sample.position,
							large_profile,
							cell_seed,
							sample.normal,
							RockSizeProfile.Category.LARGE
						)
						instances.append(inst)
						large_rock_centers.append({
							"pos": sample.position,
							"seed": cell_seed
						})

	# 2. Medianas: células de 8x8 metros
	var medium_cell_size: float = 8.0
	var medium_rock_centers: Array[Dictionary] = []

	var min_gx_m: int = int(floor(bounds.position.x / medium_cell_size))
	var max_gx_m: int = int(ceil(bounds.end.x / medium_cell_size))
	var min_gz_m: int = int(floor(bounds.position.y / medium_cell_size))
	var max_gz_m: int = int(ceil(bounds.end.y / medium_cell_size))

	for gx in range(min_gx_m, max_gx_m):
		for gz in range(min_gz_m, max_gz_m):
			var cell_seed: int = _hash_coords(world_seed, gx, gz, RockSizeProfile.Category.MEDIUM)
			var spawn_roll: float = _hash_float(cell_seed, 10)

			if spawn_roll < medium_profile.density:
				var offset_x: float = _hash_float(cell_seed, 11) * medium_cell_size
				var offset_z: float = _hash_float(cell_seed, 12) * medium_cell_size
				var wx: float = float(gx) * medium_cell_size + offset_x
				var wz: float = float(gz) * medium_cell_size + offset_z

				if bounds.has_point(Vector2(wx, wz)):
					var sample: Dictionary = _query_terrain(terrain_query_fn, wx, wz, medium_profile.max_slope_degrees)
					if sample.valid:
						var inst: RockInstance = RockInstance.create(
							sample.position,
							medium_profile,
							cell_seed,
							sample.normal,
							RockSizeProfile.Category.MEDIUM
						)
						instances.append(inst)
						medium_rock_centers.append({
							"pos": sample.position,
							"seed": cell_seed
						})

	# 3. Clusters generados alrededor de rocas grandes (Sección 18)
	for large_info in large_rock_centers:
		var l_seed: int = large_info.seed
		var cluster_roll: float = _hash_float(l_seed, 50)
		if cluster_roll < large_profile.cluster_probability:
			# Generar 0 a 3 medianas alrededor
			var num_clustered_m: int = int(_hash_float(l_seed, 51) * 3.5)
			for i in range(num_clustered_m):
				var angle: float = _hash_float(l_seed, 60 + i) * TAU
				var dist: float = lerp(2.5, 5.0, _hash_float(l_seed, 70 + i))
				var cx: float = large_info.pos.x + cos(angle) * dist
				var cz: float = large_info.pos.z + sin(angle) * dist

				if bounds.has_point(Vector2(cx, cz)):
					var sample: Dictionary = _query_terrain(terrain_query_fn, cx, cz, medium_profile.max_slope_degrees)
					if sample.valid:
						var c_seed: int = _hash_coords(l_seed, i, 90, RockSizeProfile.Category.MEDIUM)
						var inst: RockInstance = RockInstance.create(
							sample.position,
							medium_profile,
							c_seed,
							sample.normal,
							RockSizeProfile.Category.MEDIUM
						)
						instances.append(inst)
						medium_rock_centers.append({"pos": sample.position, "seed": c_seed})

			# Generar 2 a 8 minúsculas alrededor de la roca grande
			var num_clustered_s: int = 2 + int(_hash_float(l_seed, 52) * 7.0)
			for i in range(num_clustered_s):
				var angle: float = _hash_float(l_seed, 100 + i) * TAU
				var dist: float = lerp(1.5, 4.5, _hash_float(l_seed, 120 + i))
				var cx: float = large_info.pos.x + cos(angle) * dist
				var cz: float = large_info.pos.z + sin(angle) * dist

				if bounds.has_point(Vector2(cx, cz)):
					var sample: Dictionary = _query_terrain(terrain_query_fn, cx, cz, small_profile.max_slope_degrees)
					if sample.valid:
						var c_seed: int = _hash_coords(l_seed, i, 150, RockSizeProfile.Category.SMALL)
						var inst: RockInstance = RockInstance.create(
							sample.position,
							small_profile,
							c_seed,
							sample.normal,
							RockSizeProfile.Category.SMALL
						)
						instances.append(inst)

	# 4. Clusters generados alrededor de rocas medianas (0 a 4 minúsculas)
	for med_info in medium_rock_centers:
		var m_seed: int = med_info.seed
		var cluster_roll: float = _hash_float(m_seed, 200)
		if cluster_roll < medium_profile.cluster_probability:
			var num_clustered_s: int = int(_hash_float(m_seed, 201) * 4.5)
			for i in range(num_clustered_s):
				var angle: float = _hash_float(m_seed, 210 + i) * TAU
				var dist: float = lerp(0.8, 2.5, _hash_float(m_seed, 220 + i))
				var cx: float = med_info.pos.x + cos(angle) * dist
				var cz: float = med_info.pos.z + sin(angle) * dist

				if bounds.has_point(Vector2(cx, cz)):
					var sample: Dictionary = _query_terrain(terrain_query_fn, cx, cz, small_profile.max_slope_degrees)
					if sample.valid:
						var c_seed: int = _hash_coords(m_seed, i, 250, RockSizeProfile.Category.SMALL)
						var inst: RockInstance = RockInstance.create(
							sample.position,
							small_profile,
							c_seed,
							sample.normal,
							RockSizeProfile.Category.SMALL
						)
						instances.append(inst)

	# 5. Minúsculas independientes dispersas (detalle del suelo)
	var small_cell_size: float = 4.0
	var min_gx_s: int = int(floor(bounds.position.x / small_cell_size))
	var max_gx_s: int = int(ceil(bounds.end.x / small_cell_size))
	var min_gz_s: int = int(floor(bounds.position.y / small_cell_size))
	var max_gz_s: int = int(ceil(bounds.end.y / small_cell_size))

	for gx in range(min_gx_s, max_gx_s):
		for gz in range(min_gz_s, max_gz_s):
			var cell_seed: int = _hash_coords(world_seed, gx, gz, RockSizeProfile.Category.SMALL)
			var spawn_roll: float = _hash_float(cell_seed, 301)

			if spawn_roll < small_profile.density * 0.5:
				var offset_x: float = _hash_float(cell_seed, 302) * small_cell_size
				var offset_z: float = _hash_float(cell_seed, 303) * small_cell_size
				var wx: float = float(gx) * small_cell_size + offset_x
				var wz: float = float(gz) * small_cell_size + offset_z

				if bounds.has_point(Vector2(wx, wz)):
					var sample: Dictionary = _query_terrain(terrain_query_fn, wx, wz, small_profile.max_slope_degrees)
					if sample.valid:
						var inst: RockInstance = RockInstance.create(
							sample.position,
							small_profile,
							cell_seed,
							sample.normal,
							RockSizeProfile.Category.SMALL
						)
						instances.append(inst)

	return instances

## Consulta desacoplada del terreno
static func _query_terrain(query_fn: Callable, x: float, z: float, max_slope_deg: float) -> Dictionary:
	if not query_fn.is_valid():
		# Por defecto, plano en Y = 0
		return {
			"valid": true,
			"position": Vector3(x, 0.0, z),
			"normal": Vector3.UP
		}

	var res: Variant = query_fn.call(x, z)
	if res is Dictionary:
		if res.has("is_water") and res["is_water"] == true:
			return {"valid": false}
		if res.has("is_valid") and res["is_valid"] == false:
			return {"valid": false}

		var normal: Vector3 = res.get("normal", Vector3.UP)
		var slope_deg: float = rad_to_deg(acos(clamp(normal.y, -1.0, 1.0)))
		if slope_deg > max_slope_deg:
			return {"valid": false}

		var y: float = res.get("height", 0.0)
		return {
			"valid": true,
			"position": Vector3(x, y, z),
			"normal": normal
		}

	return {"valid": false}

static func _hash_coords(seed_val: int, x: int, z: int, cat: int) -> int:
	var h: int = (seed_val * 73856093) ^ (x * 19349663) ^ (z * 83492791) ^ (cat * 49979687)
	h = (h ^ (h >> 13)) * 1274126177
	return h

static func _hash_float(seed_val: int, salt: int) -> float:
	var h: int = (seed_val * 73856093) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(abs(h) % 100000) / 100000.0
