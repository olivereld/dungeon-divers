class_name DungeonGeometryGenerator
extends RefCounted

## Fachada central unificada de alto nivel para la generación procedural de geometría 3D (Fase M5 & Hardening).
## Orquesta BoundaryExtractor -> ComponentExtractor -> WallSectionExtractor -> WallVariantResolver -> WallGeometryBuilder -> WallCollisionBuilder -> BrickDecorator -> MaterialResolver.

const _BoundaryExtractorScript = preload("res://src/geometry_generator/extraction/boundary_extractor.gd")
const _ComponentExtractorScript = preload("res://src/geometry_generator/extraction/component_extractor.gd")
const _WallSectionExtractorScript = preload("res://src/geometry_generator/extraction/wall_section_extractor.gd")
const _WallVariantResolverScript = preload("res://src/geometry_generator/variants/wall_variant_resolver.gd")
const _WallGeometryBuilderScript = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const _WallCollisionBuilderScript = preload("res://src/geometry_generator/collision/wall_collision_builder.gd")
const _BrickDecoratorScript = preload("res://src/geometry_generator/decoration/brick_decorator.gd")
const _MaterialResolverScript = preload("res://src/geometry_generator/decoration/material_resolver.gd")

const _GeometryResultScript = preload("res://src/geometry_generator/data/geometry_result.gd")
const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")
const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")

const _SolidRegionExtractorScript = preload("res://src/geometry_generator/extraction/solid_region_extractor.gd")
const _SolidGeometryBuilderScript = preload("res://src/geometry_generator/geometry/solid_geometry_builder.gd")

var _boundary_extractor := _BoundaryExtractorScript.new()
var _component_extractor := _ComponentExtractorScript.new()
var _section_extractor := _WallSectionExtractorScript.new()
var _variant_resolver := _WallVariantResolverScript.new()
var _geometry_builder := _WallGeometryBuilderScript.new()
var _collision_builder := _WallCollisionBuilderScript.new()
var _decorator := _BrickDecoratorScript.new()
var _material_resolver := _MaterialResolverScript.new()
var _solid_extractor := _SolidRegionExtractorScript.new()
var _solid_builder := _SolidGeometryBuilderScript.new()

## Genera los clusters de geometría de muros particionados en WallSections para un CellGrid.
func generate_wall_clusters(
	grid: CellGrid,
	opening_manifest: WallOpeningManifest = null,
	wall_config: WallGeometryConfig = null,
	col_config: CollisionConfig = null,
	dec_config: DecorationConfig = null,
	material_preset: int = 0
) -> GeometryResult:
	var result := _GeometryResultScript.new()
	if grid == null:
		result.add_diagnostic("NULL_GRID", "FATAL", "Grid provided is null")
		return result

	if wall_config == null:
		wall_config = _WallGeometryConfigScript.new()
	if col_config == null:
		col_config = _CollisionConfigScript.new()
	if dec_config == null:
		dec_config = _DecorationConfigScript.new()

	# 0. Masa Sólida Volumétrica (SolidRegions)
	var solid_regions = _solid_extractor.extract_regions(grid, opening_manifest)
	for region in solid_regions:
		var solid_mesh: _GeneratedMeshScript = _solid_builder.build_region_mesh(region, wall_config)
		if solid_mesh.mesh != null:
			_material_resolver.resolve_materials_for_mesh(solid_mesh, material_preset)
			_collision_builder.build_collision_for_solid_region(region, wall_config, col_config, solid_mesh)
			result.generated_meshes.append(solid_mesh)

	# 1. Extracción Topológica
	var graph = _boundary_extractor.extract_graph(grid, opening_manifest)
	if graph.get_edge_count() == 0:
		return result

	# 2. Descomposición en Componentes Conexas
	var components: Array = _component_extractor.extract_components(graph)

	# 3. Generación de malla por WallComponent (geometría unificada por componente)
	for comp in components:
		var g_mesh: _GeneratedMeshScript = _geometry_builder.build_component_mesh(comp, wall_config)
		if g_mesh.mesh == null:
			continue

		_material_resolver.resolve_materials_for_mesh(g_mesh, material_preset)
		_collision_builder.build_collision_for_component(comp, wall_config, col_config, g_mesh)

		result.generated_meshes.append(g_mesh)

	return result

## Genera los clusters de geometría de muros respetando las secciones y estilos arquitectónicos de cada sala.
func generate_wall_clusters_for_partition(
	grid: CellGrid,
	partition, # PresentationGeometryPartition
	config_resolver = null, # ArchitecturalStyleConfigResolver
	opening_manifest: WallOpeningManifest = null,
	wall_config: WallGeometryConfig = null,
	col_config: CollisionConfig = null,
	base_dec_config: DecorationConfig = null,
	material_preset: int = 0,
	master_seed: int = 1337
) -> GeometryResult:
	var result := _GeometryResultScript.new()
	if grid == null:
		result.add_diagnostic("NULL_GRID", "FATAL", "Grid provided is null")
		return result

	if wall_config == null:
		wall_config = _WallGeometryConfigScript.new()
	if col_config == null:
		col_config = _CollisionConfigScript.new()
	if base_dec_config == null:
		base_dec_config = _DecorationConfigScript.new()

	# 0. Masa Sólida Volumétrica (SolidRegions)
	var solid_regions = _solid_extractor.extract_regions(grid, opening_manifest)
	for region in solid_regions:
		var solid_mesh: _GeneratedMeshScript = _solid_builder.build_region_mesh(region, wall_config)
		if solid_mesh.mesh != null:
			_material_resolver.resolve_materials_for_mesh(solid_mesh, material_preset)
			_collision_builder.build_collision_for_solid_region(region, wall_config, col_config, solid_mesh)
			result.generated_meshes.append(solid_mesh)

	# 1. Extracción Topológica
	var graph = _boundary_extractor.extract_graph(grid, opening_manifest)
	if graph.get_edge_count() == 0:
		return result

	# 2. Descomposición en Componentes Conexas
	var components: Array = _component_extractor.extract_components(graph)

	# 3. Generación de malla por WallComponent (geometría unificada por componente)
	for comp in components:
		var g_mesh: _GeneratedMeshScript = _geometry_builder.build_component_mesh(comp, wall_config)
		if g_mesh.mesh == null:
			continue

		_material_resolver.resolve_materials_for_mesh(g_mesh, material_preset)
		_collision_builder.build_collision_for_component(comp, wall_config, col_config, g_mesh)

		result.generated_meshes.append(g_mesh)

	return result

func _resolve_section_room_id(sec: _WallSectionScript, partition) -> int:
	if partition == null or sec == null:
		return -1

	for pt in sec.points:
		var r_id: int = partition.get_room_id_at(pt)
		if r_id != -1:
			return r_id
		for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n_id: int = partition.get_room_id_at(pt + offset)
			if n_id != -1:
				return n_id

	if "rooms_geometry" in partition:
		for r_id in partition.rooms_geometry:
			var r_geom = partition.rooms_geometry[r_id]
			if r_geom != null and "rect" in r_geom:
				var expanded_rect: Rect2i = r_geom.rect.grow(1)
				for pt in sec.points:
					if expanded_rect.has_point(pt):
						return r_id

	return -1

func _get_room_profile(r_id: int, partition):
	if partition == null or r_id == -1:
		return null
	var r_geom = partition.get_room_geometry(r_id)
	if r_geom != null:
		return r_geom.profile
	return null

## Genera y añade directamente los nodos 3D (MeshInstance3D + StaticBody3D) a un nodo padre.
func generate_and_attach_wall_nodes(
	grid: CellGrid,
	parent_node: Node3D,
	opening_manifest: WallOpeningManifest = null,
	wall_config: WallGeometryConfig = null,
	col_config: CollisionConfig = null,
	dec_config: DecorationConfig = null,
	material_preset: int = 0
) -> Array[MeshInstance3D]:
	var created_nodes: Array[MeshInstance3D] = []

	if wall_config == null:
		wall_config = _WallGeometryConfigScript.new()
	if col_config == null:
		col_config = _CollisionConfigScript.new()
	if dec_config == null:
		dec_config = _DecorationConfigScript.new()

	var res := generate_wall_clusters(grid, opening_manifest, wall_config, col_config, dec_config, material_preset)

	for g_mesh in res.generated_meshes:
		var inst: MeshInstance3D = g_mesh.to_mesh_instance("WallSection")
		if col_config.mode != _CollisionConfigScript.CollisionMode.NONE:
			var static_body := g_mesh.create_collision_body()
			inst.add_child(static_body)

		if parent_node != null:
			parent_node.add_child(inst)
		created_nodes.append(inst)

	return created_nodes
