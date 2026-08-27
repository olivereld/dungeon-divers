class_name DungeonFloorGenerator
extends RefCounted

## Fachada central de datos puros para la generación de superficies y baldosas de suelo (Fases M1, M2, M7, V1, V2).
## Orquesta: FloorRegionExtractor -> FloorNoiseField -> FloorTilePattern -> FloorSurfaceMeshBuilder -> FloorCollisionBuilder.
## 0 creación de nodos 3D (responsabilidad delegada a DungeonFloorSpawner).

const _FloorRegionExtractorScript = preload("res://src/floor_tile_generator/extraction/floor_region_extractor.gd")
const _FloorTilePatternScript = preload("res://src/floor_tile_generator/patterns/floor_tile_pattern.gd")
const _FloorNoiseFieldScript = preload("res://src/floor_tile_generator/patterns/floor_noise_field.gd")
const _FloorSurfaceMeshBuilderScript = preload("res://src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd")
const _FloorCollisionBuilderScript = preload("res://src/floor_tile_generator/collision/floor_collision_builder.gd")
const _FloorSurfaceClusterScript = preload("res://src/floor_tile_generator/data/floor_surface_cluster.gd")
const _FloorSurfaceResultScript = preload("res://src/floor_tile_generator/data/floor_surface_result.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _FloorVariantResolverScript = preload("res://src/floor_tile_generator/variants/floor_variant_resolver.gd")
const _ArchPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _SeedDerivationScript = preload("res://src/dungeon_generator/core/seed_derivation.gd")

var _region_extractor := _FloorRegionExtractorScript.new()
var _pattern_gen := _FloorTilePatternScript.new()
var _mesh_builder := _FloorSurfaceMeshBuilderScript.new()
var _collision_builder := _FloorCollisionBuilderScript.new()
var _variant_resolver := _FloorVariantResolverScript.new()

## Genera la superficie de suelo respetando los estilos arquitectónicos individuales de cada sala y corredores
func generate_floor_for_partition(
	partition,
	config_resolver = null,
	base_config = null,
	master_seed: int = 1337
):
	var result = _FloorSurfaceResultScript.new()
	if partition == null:
		result.add_diagnostic("NULL_PARTITION", "FATAL", "Partition provided to DungeonFloorGenerator is null")
		return result

	if base_config == null:
		base_config = _FloorTileConfigScript.new()

	var cluster_id: int = 0

	# 1. Generar clusters de suelo para cada habitación según su perfil
	for r_geom in partition.get_rooms():
		if r_geom == null or r_geom.floor_cells.is_empty():
			continue

		var room_cfg = base_config
		if config_resolver != null and r_geom.profile != null:
			room_cfg = config_resolver.resolve_floor_config(r_geom.profile, base_config)

		var room_seed: int = _SeedDerivationScript.derive_seed(master_seed, "presentation_floor", r_geom.room_id)
		var noise_field = _FloorNoiseFieldScript.new(room_seed, room_cfg.noise_frequency)

		var cluster = _FloorSurfaceClusterScript.new(cluster_id)
		cluster.cells = r_geom.floor_cells

		# Resolver variantes de suelo declarativas por celda
		var floor_policy = null
		if r_geom.profile != null:
			if "floor_variants" in r_geom.profile and r_geom.profile.floor_variants != null:
				floor_policy = r_geom.profile.floor_variants
			elif "architecture" in r_geom.profile and r_geom.profile.architecture != null and "floor_variants" in r_geom.profile.architecture:
				floor_policy = r_geom.profile.architecture.floor_variants

		var base_floor_style: int = r_geom.profile.floor_style if (r_geom.profile != null and "floor_style" in r_geom.profile) else 0
		var style_config_cache: Dictionary = {}
		style_config_cache[base_floor_style] = room_cfg

		for cell_pos in r_geom.floor_cells:
			var cell_cfg = room_cfg
			if floor_policy != null and floor_policy.enabled and not floor_policy.variants.is_empty():
				var cell_style: int = _variant_resolver.resolve_cell_floor_style(
					cell_pos, room_seed, floor_policy, base_floor_style
				)
				if style_config_cache.has(cell_style):
					cell_cfg = style_config_cache[cell_style]
				elif config_resolver != null and r_geom.profile != null:
					var proxy_prof := _ArchPresentationProfileScript.new(
						cell_style,
						r_geom.profile.wall_style,
						r_geom.profile.door_style,
						r_geom.profile.stairs_style,
						r_geom.profile.fixture_style,
						r_geom.profile.decoration_palette
					)
					cell_cfg = config_resolver.resolve_floor_config(proxy_prof, base_config)
					style_config_cache[cell_style] = cell_cfg

			var descs: Array = _pattern_gen.generate_descriptors_for_cell(
				cell_pos, cell_cfg, room_seed, noise_field
			)
			cluster.descriptors.append_array(descs)

		cluster.mesh = _mesh_builder.build_cluster_mesh(cluster, room_cfg)
		if cluster.mesh != null:
			cluster.aabb = cluster.mesh.get_aabb()

		_collision_builder.build_collision_for_cluster(cluster, cluster.cells, room_cfg)

		result.clusters.append(cluster)
		result.total_tiles_generated += r_geom.floor_cells.size()
		result.total_descriptors_count += cluster.descriptors.size()
		cluster_id += 1

	# 2. Generar cluster de suelo para corredores (usando base_config / estilo dominante)
	if not partition.corridor_floor_cells.is_empty():
		var corridor_seed: int = _SeedDerivationScript.derive_seed(master_seed, "presentation_floor", 9999)
		var noise_field = _FloorNoiseFieldScript.new(corridor_seed, base_config.noise_frequency)

		var cluster = _FloorSurfaceClusterScript.new(cluster_id)
		cluster.cells = partition.corridor_floor_cells

		for cell_pos in partition.corridor_floor_cells:
			var descs: Array = _pattern_gen.generate_descriptors_for_cell(
				cell_pos, base_config, corridor_seed, noise_field
			)
			cluster.descriptors.append_array(descs)

		cluster.mesh = _mesh_builder.build_cluster_mesh(cluster, base_config)
		if cluster.mesh != null:
			cluster.aabb = cluster.mesh.get_aabb()

		_collision_builder.build_collision_for_cluster(cluster, cluster.cells, base_config)

		result.clusters.append(cluster)
		result.total_tiles_generated += partition.corridor_floor_cells.size()
		result.total_descriptors_count += cluster.descriptors.size()
		cluster_id += 1

	result.total_regions_count = cluster_id
	return result

## Genera la superficie completa de suelo en modo de datos puros (FloorSurfaceResult)
func generate_floor_surface(
	grid,
	config = null,
	seed_val: int = 1337
):
	var result = _FloorSurfaceResultScript.new()
	if grid == null:
		result.add_diagnostic("NULL_GRID", "FATAL", "Grid provided to DungeonFloorGenerator is null")
		return result

	if config == null:
		config = _FloorTileConfigScript.new()

	# M1: Extracción de superficies conexas
	var regions: Array = _region_extractor.extract_regions(grid)
	result.total_regions_count = regions.size()

	if regions.is_empty():
		return result

	# V2: Inicializar campo continuo de ruido espacial para toda la mazmorra
	var noise_field = _FloorNoiseFieldScript.new(seed_val, config.noise_frequency)

	# M2, M3, V1: Generación de clusters y descriptores con layouts estocásticos
	var cluster_id: int = 0
	for region in regions:
		var cluster = _FloorSurfaceClusterScript.new(cluster_id)
		cluster.cells = region

		for cell in region:
			var cell_pos: Vector2i = cell if cell is Vector2i else Vector2i(cell.x, cell.y)
			var descs: Array = _pattern_gen.generate_descriptors_for_cell(
				cell_pos, config, seed_val, noise_field
			)
			cluster.descriptors.append_array(descs)

		# M4: Construcción de malla ArrayMesh
		cluster.mesh = _mesh_builder.build_cluster_mesh(cluster, config)
		if cluster.mesh != null:
			cluster.aabb = cluster.mesh.get_aabb()

		# M5: Construcción de colisiones físicas
		_collision_builder.build_collision_for_cluster(cluster, cluster.cells, config)

		result.clusters.append(cluster)
		result.total_tiles_generated += region.size()
		result.total_descriptors_count += cluster.descriptors.size()
		cluster_id += 1

	return result
