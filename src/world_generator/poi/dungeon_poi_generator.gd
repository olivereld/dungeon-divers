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
	
	# 1. Validación de Huella y Criterios Físicos (no agua, pendiente suave en toda la huella)
	for dx in range(-footprint_radius, footprint_radius + 1, 3):
		for dz in range(-footprint_radius, footprint_radius + 1, 3):
			var sample_x: int = wx + dx
			var sample_z: int = wz + dz
			
			if world_query.has_method("is_water") and world_query.is_water(sample_x, sample_z):
				return null
			
			if world_query.has_method("get_slope"):
				var slope: float = world_query.get_slope(sample_x, sample_z)
				if slope > max_valid_slope:
					return null

	var elevation: float = 0.0
	if world_query.has_method("get_elevation"):
		elevation = world_query.get_elevation(wx, wz)
		
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
	
	var bounds_w: int = footprint_radius * 2 + 4
	var bounds_rect := Rect2i(wx - footprint_radius - 2, wz - footprint_radius - 2, bounds_w, bounds_w)
	
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
	else:
		return &"catacombs"

func _resolve_orientation(wx: int, wz: int, world_query: Object) -> float:
	if not world_query.has_method("get_elevation"):
		return 0.0
	
	# Evaluamos diferencias cardinales de elevación para orientar la entrada apuntando cuesta abajo
	var h_n: float = world_query.get_elevation(wx, wz - 2)
	var h_s: float = world_query.get_elevation(wx, wz + 2)
	var h_w: float = world_query.get_elevation(wx - 2, wz)
	var h_e: float = world_query.get_elevation(wx + 2, wz)
	
	var grad_x: float = h_e - h_w
	var grad_z: float = h_s - h_n
	
	if abs(grad_x) < 0.01 and abs(grad_z) < 0.01:
		return 0.0
		
	# Apuntar hacia donde desciende la pendiente (-grad)
	var angle_rad: float = atan2(-grad_x, -grad_z)
	return rad_to_deg(angle_rad)
