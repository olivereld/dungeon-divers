class_name DungeonPOIGenerator
extends RefCounted

## Generador y validador de POIs de mazmorra basado en macro-rejilla.
## Realiza la distribución determinista sin generar chunks intermedios,
## validando topografía, pendiente, hidrología y footprint ambiental mediante un WorldContext/Query.

const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")

var macro_cell_size: int = 256
var margin: int = 32
var min_distance_between_pois: float = 120.0
var max_valid_slope: float = 25.0
var footprint_radius: int = 6

func _init(p_macro_cell_size: int = 256, p_margin: int = 32, p_min_dist: float = 120.0) -> void:
	macro_cell_size = p_macro_cell_size
	margin = p_margin
	min_distance_between_pois = p_min_dist

## Genera deterministamente la propuesta de candidato para una macro-celda sin consultar el mundo todavía.
func generate_candidate_for_macro_cell(master_seed: int, macro_coord: Vector2i, candidate_idx: int = 0) -> Dictionary:
	var seed_poi: int = WorldSeedSystem.derive_seed(master_seed, WorldSeedSystem.DOMAIN_POI, (macro_coord.x * 73856093) ^ (macro_coord.y * 19349663) ^ candidate_idx)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_poi
	
	var usable_width: int = maxi(1, macro_cell_size - (margin * 2))
	var offset_x: int = margin + (rng.randi() % usable_width)
	var offset_z: int = margin + (rng.randi() % usable_width)
	
	var world_x: int = macro_coord.x * macro_cell_size + offset_x
	var world_z: int = macro_coord.y * macro_cell_size + offset_z
	
	return {
		"world_x": world_x,
		"world_z": world_z,
		"candidate_index": candidate_idx,
		"rng_seed": seed_poi
	}

## Evalúa el candidato contra el contrato de consulta del mundo (world_query)
## y retorna una instancia de DungeonPOI si es válido, o null si se descarta.
func evaluate_and_create_poi(master_seed: int, macro_coord: Vector2i, world_query: Object, candidate_idx: int = 0) -> RefCounted:
	var cand: Dictionary = generate_candidate_for_macro_cell(master_seed, macro_coord, candidate_idx)
	var wx: int = cand["world_x"]
	var wz: int = cand["world_z"]

	var elevation: float = 0.0
	if world_query.has_method("get_elevation"):
		elevation = world_query.get_elevation(wx, wz)

	# 1. Validación de Huella y Criterios Físicos:
	# El modelo 3D requiere una base firme de al menos 6m ancho x 8m fondo (con escaleras).
	# Validamos un área de radio rx=3 y rz=4 celdas paso a paso (sin saltos) verificando:
	# a) Ausencia de agua.
	# b) Pendiente suave (< max_valid_slope).
	# c) Estabilidad de terraza: ninguna celda bajo la estructura puede caer por un acantilado o terraza distinta.
	var check_rx: int = 3
	var check_rz: int = 4
	for dx in range(-check_rx, check_rx + 1):
		for dz in range(-check_rz, check_rz + 1):
			var sample_x: int = wx + dx
			var sample_z: int = wz + dz
			
			if world_query.has_method("is_water") and world_query.is_water(sample_x, sample_z):
				return null
			
			if world_query.has_method("get_slope"):
				var slope: float = world_query.get_slope(sample_x, sample_z)
				if slope > max_valid_slope:
					return null

			if world_query.has_method("get_elevation"):
				var s_elev: float = world_query.get_elevation(sample_x, sample_z)
				if absf(s_elev - elevation) > 0.25:
					return null
		
	# 2. Resolución de Arquetipo según entorno (bioma / elevación)
	var biome: StringName = &"plains"
	if world_query.has_method("get_biome"):
		biome = world_query.get_biome(wx, wz)
	var archetype_id: StringName = _resolve_archetype(biome, elevation)
	
	# 3. Orientación basada en geometría/normal del terreno
	var orientation_deg: float = _resolve_orientation(wx, wz, world_query)
	
	# 4. Construcción de Identidad Canónica
	var identity: RefCounted = _DungeonIdentityScript.create(master_seed, macro_coord, candidate_idx)
	
	# 5. Configuración de dimensiones y tiers
	var tier: int = 1 + int(abs(macro_coord.x) + abs(macro_coord.y)) % 4
	var total_floors: int = 2 + (identity.dungeon_seed % 3)
	
	var world_pos := Vector3(float(wx), elevation, float(wz))
	var rot_basis := Basis(Vector3.UP, deg_to_rad(orientation_deg))
	var entrance_xf := Transform3D(rot_basis, world_pos)
	
	var env_influence_radius: int = 48
	var bounds_w: int = env_influence_radius * 2
	var bounds_rect := Rect2i(wx - env_influence_radius, wz - env_influence_radius, bounds_w, bounds_w)
	
	var poi = _DungeonPOIScript.new(
		identity,
		world_pos,
		entrance_xf,
		archetype_id,
		tier,
		total_floors,
		orientation_deg,
		bounds_rect
	)
	
	return poi

## Busca deterministamente entre múltiples candidatos de la macro-celda hasta encontrar
## uno que se sitúe sobre una meseta estable y uniforme.
func find_valid_poi_for_macro_cell(master_seed: int, macro_coord: Vector2i, world_query: Object, max_candidates: int = 16) -> RefCounted:
	for idx in range(max_candidates):
		var poi = evaluate_and_create_poi(master_seed, macro_coord, world_query, idx)
		if poi != null:
			return poi
	return null

func _resolve_archetype(biome: StringName, elevation: float) -> StringName:
	var b_str: String = String(biome).to_lower()
	if elevation > 60.0 or b_str == "mountain" or b_str == "mountains":
		return &"fortress"
	elif b_str == "forest" or b_str == "dense_forest":
		return &"ruins"
	elif b_str == "swamp" or b_str == "marsh":
		return &"crypt"
	elif b_str == "desert" or b_str == "arid":
		return &"necropolis"
	elif b_str == "taiga":
		return &"necropolis"
	else:
		return &"catacombs"

## Resuelve la orientación óptima para que la fachada y puerta de la cripta miren siempre
## hacia terreno abierto, despejado y transitable, dando la espalda a montañas o paredes de roca.
func _resolve_orientation(wx: int, wz: int, world_query: Object) -> float:
	if not world_query.has_method("get_elevation"):
		return 0.0

	var elevation: float = world_query.get_elevation(wx, wz)
	var candidate_dirs: Array[Vector2] = [
		Vector2(0, 1),   # Sur (+Z)
		Vector2(1, 0),   # Este (+X)
		Vector2(0, -1),  # Norte (-Z)
		Vector2(-1, 0),  # Oeste (-X)
		Vector2(0.7071, 0.7071),
		Vector2(0.7071, -0.7071),
		Vector2(-0.7071, 0.7071),
		Vector2(-0.7071, -0.7071)
	]

	var best_score: float = -999999.0
	var best_dir: Vector2 = Vector2(0, 1)

	for dir in candidate_dirs:
		var score: float = 0.0

		# 1. Evaluar espacio libre frontal (donde mira la puerta)
		for dist in [4.0, 7.0, 10.0]:
			var sx: int = int(round(float(wx) + dir.x * dist))
			var sz: int = int(round(float(wz) + dir.y * dist))

			if world_query.has_method("is_water") and world_query.is_water(sx, sz):
				score -= 80.0

			var h: float = world_query.get_elevation(sx, sz)
			var diff: float = h - elevation
			if diff > 0.4:
				# Montaña, pared o acantilado tapando la puerta: penalizar fuertemente
				score -= diff * 35.0
			elif diff <= 0.2 and diff >= -1.0:
				# Suelo despejado y transitable a nivel o leve pendiente: premiar
				score += 20.0
			elif diff < -2.0:
				# Precipicio abrupto justo al salir: penalizar
				score -= 25.0

		# 2. Evaluar respaldo trasero (pared o montaña detrás del mausoleo es ideal arquitectónicamente)
		var back_dir: Vector2 = -dir
		for dist in [4.0, 7.0]:
			var bx: int = int(round(float(wx) + back_dir.x * dist))
			var bz: int = int(round(float(wz) + back_dir.y * dist))
			var bh: float = world_query.get_elevation(bx, bz)
			var b_diff: float = bh - elevation
			if b_diff > 0.5:
				score += minf(b_diff * 15.0, 30.0)

		if score > best_score:
			best_score = score
			best_dir = dir

	var angle_rad: float = atan2(best_dir.x, best_dir.y)
	return rad_to_deg(angle_rad)
