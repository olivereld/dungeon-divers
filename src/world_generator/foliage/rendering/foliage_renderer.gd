class_name FoliageRenderer
extends RefCounted

## Renderizador de follaje que ensambla los nodos MultiMeshInstance3D para una vista de chunk o mundo.

const _FoliageMultiMeshBuilderScript = preload("res://src/world_generator/foliage/rendering/foliage_multimesh_builder.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")

static var _cached_species_map: Dictionary = {}

static func get_species_cache() -> Dictionary:
	if _cached_species_map.is_empty():
		var reg: RefCounted = _BiomeRegistryScript.get_default()
		for biome_def in reg.get_all_definitions():
			if biome_def != null and biome_def.foliage_profile != null:
				for sp in biome_def.foliage_profile.species:
					if sp != null and "id" in sp:
						_cached_species_map[sp.id] = sp
	return _cached_species_map

static func build_chunk_foliage_node(
	foliage_data: RefCounted,
	species_list: Array = [],
	origin_offset: Vector3 = Vector3.ZERO,
	wind_strength: float = 0.35,
	wind_speed: float = 2.0
) -> Node3D:
	if foliage_data == null or not ("instances_by_species" in foliage_data):
		return null

	var root := Node3D.new()
	root.name = "ChunkFoliage"

	var species_map: Dictionary = {}
	if not species_list.is_empty():
		for sp in species_list:
			if sp != null and "id" in sp:
				species_map[sp.id] = sp
	else:
		species_map = get_species_cache()

	for sp_id in foliage_data.instances_by_species:
		var instances: Array = foliage_data.instances_by_species[sp_id]
		if instances.is_empty():
			continue

		var colors: PackedColorArray = foliage_data.get_colors_for_species(sp_id)
		var sp = species_map.get(sp_id, null)
		if sp == null:
			continue

		var mmi := _FoliageMultiMeshBuilderScript.build_multimesh(
			sp,
			instances,
			colors,
			origin_offset,
			wind_strength,
			wind_speed
		)
		if mmi != null:
			root.add_child(mmi)

	return root
