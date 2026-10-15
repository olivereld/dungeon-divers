class_name FoliageRenderer
extends RefCounted

## Renderizador de follaje que ensambla los nodos MultiMeshInstance3D para una vista de chunk o mundo.

const _FoliageMultiMeshBuilderScript = preload("res://src/world_generator/foliage/rendering/foliage_multimesh_builder.gd")
const _FoliageSpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")

static var _cached_species_map: Dictionary = {}

static func create_thorn_vines_species(index: int) -> FoliageSpecies:
	var idx := clampi(index, 1, 4)
	var sp := _FoliageSpeciesScript.new()
	sp.id = StringName("thorn_vines_0%d" % idx)
	sp.display_name = "Thorn Vines 0%d" % idx
	sp.texture_path = "res://assets/texture/foliage/vines/vines_0%d.jpg" % idx
	sp.bark_texture_path = "res://models/nature/dead_tree/dead_tree_01_Arbol.png"
	sp.bark_influence = 0.75
	sp.foliage_type = _FoliageSpeciesScript.FoliageType.GRASS
	sp.scale_category = _FoliageSpeciesScript.ScaleCategory.MEDIUM
	# Paletas de marrón leñoso / corteza seca para alto contraste con el suelo corrupto oscuro
	var brown_palettes = [
		{"bottom": Color(0.42, 0.26, 0.16), "top": Color(0.68, 0.46, 0.30)}, # Marrón siena / raíz leñosa
		{"bottom": Color(0.46, 0.28, 0.18), "top": Color(0.72, 0.50, 0.34)}, # Marrón castaño / zarza cálida
		{"bottom": Color(0.40, 0.24, 0.15), "top": Color(0.64, 0.43, 0.28)}, # Marrón avellana / corteza seca
		{"bottom": Color(0.44, 0.27, 0.17), "top": Color(0.70, 0.48, 0.32)}, # Marrón leonado / enredadera ámbar
	]
	var pal: Dictionary = brown_palettes[idx - 1]
	sp.color_bottom = pal["bottom"]
	sp.color_top = pal["top"]
	sp.quad_cross_count = 3
	sp.scale_min = Vector3(1.2, 0.9, 1.2)
	sp.scale_max = Vector3(1.8, 1.6, 1.8)
	sp.tint_with_grass_color = false
	sp.wind_strength = 0.08
	sp.wind_speed = 0.8
	return sp

static func get_species_cache() -> Dictionary:
	if _cached_species_map.is_empty():
		var reg: RefCounted = _BiomeRegistryScript.get_default()
		for biome_def in reg.get_all_definitions():
			if biome_def != null and biome_def.foliage_profile != null:
				for sp in biome_def.foliage_profile.species:
					if sp != null and "id" in sp:
						_cached_species_map[sp.id] = sp
		for i in range(1, 5):
			var tv = create_thorn_vines_species(i)
			_cached_species_map[tv.id] = tv
	return _cached_species_map

static func build_chunk_foliage_node(
	foliage_data: RefCounted,
	species_list: Array = [],
	origin_offset: Vector3 = Vector3.ZERO,
	wind_strength: float = 0.25,
	wind_speed: float = 1.6
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
